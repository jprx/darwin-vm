#!/usr/bin/env python3
import mmap
import argparse
import ctypes
from ctypes import Structure, c_int32, c_uint32, c_uint64, c_char

#################
# configuration #
#################

PATCHOUTS = {
  b'*': [
    # put your custom patches here
  ],

  b'com.apple.kernel': [
    # xnu/bsd/vm/vm_unix.c in shared_region_check_np
    b'vm: shared_region: %p [%d(%s)] check_np(0x%llx) vm_shared_region_start_address() returned 0x%x',
    b'shared_region: %p [%d(%s)] check_np(0x%llx) vm_shared_region_start_address() returned 0x%x',
  ],

  b'com.apple.driver.AppleSEPCredentialManager': [
    # ACMKernelUtils::waitForSEPEndpoint
    # You could also silence this by removing the arm-io/sep node from the
    # dtree, but that *will* break pre-SPTM macOS systems that need
    # arm-io/sep/iop-sep-nub/InvalidateHmac. Instead, we just patch it out.
    b'%s: %s: timed out waiting for AppleSEPManager (timeoutMs=%llu).',
  ],

  b'com.apple.security.sandbox': [
    # log_kernel_report_summary
    # this removes the "System Policy: bash(4) allow process-exec* /bin/ls" messages
    b'%s: %s(%d) \x00%s\n%s\x00%s',
  ]
}

IS_DRY_RUN = False

###############
# macho stuff #
###############

LC_SEGMENT_64=0x19
LC_FILESET_ENTRY=0x80000035

class MachHeader64(Structure):
  _fields_ = [
    ("magic",       c_uint32),
    ("cputype",     c_int32),
    ("cpusubtype",  c_int32),
    ("filetype",    c_uint32),
    ("ncmds",       c_uint32),
    ("sizeofcmds",  c_uint32),
    ("flags",       c_uint32),
    ("reserved",    c_uint32),
  ]

class LoadCommand(Structure):
  _fields_ = [
    ("cmd",      c_uint32),
    ("cmdsize",  c_uint32),
  ]

class FilesetEntry(Structure):
  _fields_ = [
    ("cmd",       c_uint32),
    ("cmdsize",   c_uint32),
    ("vmaddr",    c_uint64),
    ("fileoff",   c_uint64),
    ("entry_id",  c_uint32),
    ("reserved",  c_uint32),
  ]

class SegmentCommand(Structure):
  _fields_ = [
    ("cmd",       c_uint32),
    ("cmdsize",   c_uint32),
    ("segname",   16 * c_char),
    ("vmaddr",    c_uint64),
    ("vmsize",    c_uint64),
    ("fileoff",   c_uint64),
    ("filesize",  c_uint64),
    ("maxprot",   c_int32),
    ("initprot",  c_int32),
    ("nsects",    c_uint32),
    ("flags",     c_uint32),
  ]

class SectionCommand(Structure):
  _fields_ = [
    ("sectname",   16 * c_char),
    ("segname",    16 * c_char),
    ("addr",       c_uint64),
    ("size",       c_uint64),
    ("offset",     c_uint32),
    ("align",      c_uint32),
    ("reloff",     c_uint32),
    ("nreloc",     c_uint32),
    ("flags",      c_uint32),
    ("reserved1",  c_uint32),
    ("reserved2",  c_uint32),
    ("reserved3",  c_uint32),
  ]

def find_fileset_entry(macho, name) -> FilesetEntry | None:
  header = MachHeader64.from_buffer_copy(macho)

  if str == type(name):
    name = name.encode('utf8')

  cursor = ctypes.sizeof(header)
  for _ in range(header.ncmds):
    lc = LoadCommand.from_buffer_copy(macho, cursor)

    if LC_FILESET_ENTRY == lc.cmd:
      fse = FilesetEntry.from_buffer_copy(macho, cursor)
      fse_name_start = cursor + ctypes.sizeof(fse)
      fse_name_end = macho.find(b'\x00', fse_name_start+1)
      fse_name = macho[fse_name_start:fse_name_end]
      if name == fse_name: return fse

    cursor += lc.cmdsize

  return None

def __find_segment_offset(macho, segname) -> int | None:
  header = MachHeader64.from_buffer_copy(macho)

  cursor = ctypes.sizeof(header)
  for _ in range(header.ncmds):
    lc = LoadCommand.from_buffer_copy(macho, cursor)
    if LC_SEGMENT_64 == lc.cmd:
      seg = SegmentCommand.from_buffer_copy(macho, cursor)
      if seg.segname == segname: return cursor
    cursor += lc.cmdsize

  return None

def find_segment(macho, segname) -> SegmentCommand | None:
  seg_offset = __find_segment_offset(macho, segname)
  if seg_offset is None: return None
  return SegmentCommand.from_buffer_copy(macho, seg_offset)

def find_section(macho, segname, sectname) -> SectionCommand | None:
  seg_offset = __find_segment_offset(macho, segname)
  if seg_offset is None: return None
  seg = SegmentCommand.from_buffer_copy(macho, seg_offset)

  cursor = seg_offset + ctypes.sizeof(seg)
  for _ in range(seg.nsects):
    sect = SectionCommand.from_buffer_copy(macho, cursor)
    if sect.sectname == sectname: return sect
    cursor += ctypes.sizeof(sect)

  return None

###############
# patch logic #
###############

def do_patch(macho, patchout, start, end):
  global IS_DRY_RUN
  pos=start-1
  while -1 != (pos := macho.find(patchout, pos+1, end)):
    print(hex(pos), patchout)

    if not IS_DRY_RUN: macho[pos:pos+len(patchout)] = b'\x00' * len(patchout)

def patch_kext(macho, kextname, patchouts):
  fse_lc = find_fileset_entry(macho, kextname)

  if fse_lc is None:
    print(f"warning: couldn't find kext {kextname}")
    return

  fse = macho[fse_lc.fileoff:]

  # some strings will be in __TEXT,__cstring; others may be in __TEXT,__os_log.
  # to keep it simple, we just scan all of __TEXT for each kext
  text_seg = find_segment(fse, b"__TEXT")

  if text_seg is None:
    print(f"warning: couldn't find __TEXT for {kextname}")
    return

  for patchout in patchouts:
    do_patch(macho, patchout, text_seg.fileoff, text_seg.fileoff + text_seg.filesize)

def patch_anywhere(macho, patchouts):
  for patchout in patchouts:
    do_patch(macho, patchout, 0, len(macho))

def main():
  global IS_DRY_RUN

  p = argparse.ArgumentParser(prog='silence_logs')
  p.add_argument('bootkc', type=argparse.FileType('rb+',0))
  p.add_argument('-n', '--dry-run', action='store_true')
  args = p.parse_args()

  macho = mmap.mmap(args.bootkc.fileno(), 0)

  IS_DRY_RUN = args.dry_run

  for kext,patchouts in PATCHOUTS.items():
    if b'*' == kext: patch_anywhere(macho, patchouts)
    else: patch_kext(macho, kext, patchouts)

if "__main__" == __name__:
  main()

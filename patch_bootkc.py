#!/usr/bin/env python3
"""
Silences known-unconditional debug kprintf()s in a release bootkc that spam
the console on every process launch / every few seconds, without affecting
kernel behavior. This VM never has a real SEP or a real dyld shared cache, so
these particular log lines are always benign noise here.

Technique: each target is a printf-style format string embedded in the
kernelcache's string table. We truncate it in place by overwriting its first
byte with a NUL terminator, turning "shared_region: ... returned 0x%x\n" into
"" (an empty, no-argument format string). This changes zero instructions and
zero code paths - printf-family functions never touch the vararg list when
the format has no '%' directives - so it can't affect program correctness in
any way. If Apple changes the wording (or drops the message) in a future
build, the string just won't be found and we skip it with a warning rather
than failing the build.
"""
import argparse

# Each entry is matched literally and, if present exactly once, truncated.
NOISY_STRINGS = [
    # AppleCredentialManager/ ACMTRM has its own retry-loop log line
    # ("waitForSEPEndpoint: timed out...") that's silenced by removing the
    # 'sep' device tree node instead (see dt_fixup.py) - that stops the
    # subsystem from ever probing SEP in the first place, which is cleaner
    # than patching this string. This one, on the other hand, has no such
    # device-tree lever: it's printed unconditionally on every check_np()
    # syscall (i.e. on every single process launch), regardless of any
    # boot-arg or sysctl, because there's no real dyld shared region in this
    # ramdisk environment.
    b"shared_region: %p [%d(%s)] check_np(0x%llx) vm_shared_region_start_address() returned 0x%x\n",
]

def patch(data: bytes) -> bytes:
    data = bytearray(data)
    for needle in NOISY_STRINGS:
        count = data.count(needle)
        if count == 0:
            print(f"warning: pattern not found, skipping: {needle!r}")
            continue
        if count > 1:
            print(f"warning: pattern found {count} times (expected 1), skipping to be safe: {needle!r}")
            continue
        offset = data.find(needle)
        data[offset] = 0
        print(f"patched 1 string at offset {hex(offset)}: {needle!r}")
    return bytes(data)

def main():
    p = argparse.ArgumentParser(prog='patch_bootkc')
    p.add_argument('bootkc', type=argparse.FileType('rb', 0))
    p.add_argument('out', type=argparse.FileType('wb', 0))
    args = p.parse_args()

    data = args.bootkc.read()
    patched = patch(data)
    assert len(patched) == len(data), "patch must not change file size"
    args.out.write(patched)

if __name__ == "__main__":
    main()

# Running darwin-vm on Linux

This document covers how to run darwin-vm's firmware-preparation pipeline
(`get_files.sh` / `fix_perms.sh`) on a Linux host, without a Mac. This isn't
part of upstream darwin-vm (which assumes macOS for the firmware-prep step,
since it shells out to `hdiutil`/`ditto`/`codesign`); everything here layers
on top of it and doesn't change the macOS path at all.

See [LINUX.zh-CN.md](LINUX.zh-CN.md) for the Chinese version of this doc.

## Extra host dependencies

Besides what the main README already lists (`jq`, `wget`), you'll also need:

- **ipsw** (github.com/blacktop/ipsw). `go install .../ipsw@latest` fails
  because its go.mod has `replace` directives; build from a clone instead:
  ```
  git clone https://github.com/blacktop/ipsw.git
  cd ipsw && go build -o ipsw ./cmd/ipsw
  sudo cp ipsw /usr/local/bin/
  ```
- **ldid** (github.com/ProcursusTeam/ldid). Stands in for macOS's
  `codesign` for ad-hoc signing; its `-S`/`-h` output is textually
  compatible with `codesign -s -` / `codesign -d -vvv`.
  ```
  sudo apt-get install -y libplist-dev
  git clone https://github.com/ProcursusTeam/ldid.git
  cd ldid && make
  sudo cp ldid /usr/local/bin/
  ```
- **linux-apfs-rw** kernel module (github.com/linux-apfs/linux-apfs-rw).
  `firmware/ramdisk.dmg` turns out to be a raw APFS container (no UDIF/HFS+
  wrapper), so it's mounted directly using this out-of-tree, experimental
  read-write APFS driver. Build it against your running kernel's headers:
  ```
  sudo apt-get install -y linux-headers-$(uname -r)
  git clone https://github.com/linux-apfs/linux-apfs-rw.git
  cd linux-apfs-rw && make
  sudo modprobe libcrc32c
  sudo insmod apfs.ko
  ```
  `insmod` doesn't persist across reboots — re-run it after every reboot (or
  set up `depmod`/`modules-load.d` yourself).

## What changed to make this work

- **`dmgutil.sh`** (new) centralizes DMG mount/unmount and directory-copy
  logic used by `get_files.sh` and `fix_perms.sh`. On macOS it's a thin
  wrapper over `hdiutil`/`ditto` — unchanged behavior. On Linux it mounts via
  the `apfs` kernel module and copies with `cp -a --remove-destination` (the
  `--remove-destination` matters: the Linux apfs driver's experimental write
  support doesn't implement `O_TRUNC`, so overwriting an existing file has to
  unlink-then-recreate rather than truncate-in-place, or `cp` fails with
  "Operation not supported").
- **`get_files.sh` / `fix_perms.sh`** now `source dmgutil.sh` and no longer
  bail out with "this isn't a Mac" on Linux — the ramdisk-patching and
  permission-fixing steps run the same way on both platforms, just through
  `dmgutil.sh`'s cross-platform helpers. `codesign` is swapped for
  `ldid -Cadhoc -S` / `ldid -h` on Linux.
- `chown root:wheel` becomes `chown 0:0` on Linux — same uid/gid pair, since
  macOS's `wheel` group is gid 0, same as Linux's `root` group. XNU only
  checks the numeric ids.

None of this touches the macOS code path: every new branch is gated behind
`[[ "$(uname)" == "Darwin" ]]`, so pulling this code onto a Mac is safe — it
runs the exact same `hdiutil`/`ditto`/`codesign` commands as before.

## Boot-noise patches

Two log lines print constantly in this VM because it doesn't emulate a SEP
(Secure Enclave Processor) or provide a real dyld shared cache. Neither
affects correctness — commands still run and return correct output — but
the first is a genuine infinite retry loop and the second reprints on every
single process launch, so both were silenced. These patches apply to iOS
*and* macOS guests (both share the same XNU code paths) and are host-OS
agnostic — they're equally worth carrying over if you build firmware on an
actual Mac.

1. **`ACMTRM: waitForSEPEndpoint: timed out waiting for AppleSEPManager`**
   (repeats every ~5s forever). `AppleCredentialManager` believes a SEP
   exists (per the device tree) and retries forever. Neither the
   `trm_enabled=0` boot-arg nor a `sepfw-load-at-boot=0` device-tree property
   stopped it — what does work is removing the `sep` node from the device
   tree entirely, in `dt_fixup.py`:
   ```python
   d['arm-io'].remove_child('sep')
   ```
   so the driver never finds a SEP nub to probe in the first place.
   (`run.sh`'s `BOOT_ARGS` also still sets `trm_enabled=0 hidrm_enabled=0` as
   a harmless belt-and-braces measure, kept even though it wasn't sufficient
   on its own.)

2. **`shared_region: %p [%d(%s)] check_np(...) vm_shared_region_start_address()
   returned 0x1`** — printed unconditionally (no boot-arg or sysctl we could
   find gates it) on every `check_np()` syscall, i.e. on every single process
   launch. `patch_bootkc.py` (new, wired into `get_files.sh`'s `main()` right
   after `bootkc` is downloaded) truncates this printf's format string in
   place by overwriting its first byte with a NUL. That's a 1-byte data
   patch and zero instruction changes: printf-family functions never read
   their vararg list when the format string has no `%` directives, so this
   can't change behavior beyond suppressing the print. Verified against both
   an iOS (`iPhone17,3`) and a macOS (`Mac16,10`) `bootkc` — the string
   exists exactly once, byte-identical, in both.

Both patches run automatically as part of `get_files.sh`; there's no manual
step, and no risk of forgetting them on a re-run.

## Tested host configuration

The main README's compatibility table is about which *guest* devices/OS
versions boot. The Linux-hosting path above was additionally verified on
this host:

| | |
|---|---|
| CPU | AMD Ryzen 9 9950X (16 cores / 32 threads) |
| Motherboard | ASUS ROG Crosshair X870E Hero |
| GPU | NVIDIA GeForce RTX 2080 Ti |
| Memory | 64 GB |
| Architecture | x86_64 |
| OS | Ubuntu 24.04 LTS, kernel 7.0.0-30-generic |

None of this is a hard requirement — the pipeline is single-threaded CPU
work plus a software-emulated qemu VM, so far more modest Linux hardware
should work fine. It's listed here only as the known-good reference
configuration this was actually tested on.

# Changelog

## 2026-08-29 — Linux host support + boot-noise fixes

Adds a Linux-hosted path through the firmware-prep pipeline (`get_files.sh` /
`fix_perms.sh`), which upstream only supports on macOS, plus two kernel-side
patches that silence harmless-but-noisy console spam on any host. See
[LINUX.md](LINUX.md) / [LINUX.zh-CN.md](LINUX.zh-CN.md) for full details and
rationale.

### Added
- `dmgutil.sh` — shared cross-platform helpers (`dmg_attach`, `dmg_detach`,
  `copy_tree`) for mounting/unmounting `ramdisk.dmg` and copying directory
  trees into it. macOS still goes through `hdiutil`/`ditto`; Linux goes
  through the `linux-apfs-rw` kernel module and `cp -a --remove-destination`.
- `patch_bootkc.py` — truncates a known-unconditional, always-noisy
  `shared_region: ... check_np(...)` printf format string in `bootkc` by
  overwriting its first byte with a NUL. Zero instruction changes; verified
  byte-identical on both an iOS and a macOS `bootkc`. Wired into
  `get_files.sh`'s `main()`, so it runs automatically on every fetch.
- `LINUX.md` / `LINUX.zh-CN.md` — setup guide for the Linux host path
  (ipsw/ldid/linux-apfs-rw build instructions), an explanation of both
  boot-noise patches, and the host hardware this was verified on.
- `.gitignore` — excludes generated/downloaded output (`firmware/`,
  `firmware-*/`, `ipsw_db/`, `sysroot/`, `sysroot.tar.gz`, `mnt/`,
  `qemu-sptm/build/`).

### Changed
- `get_files.sh` — sources `dmgutil.sh`; `ensure_installed` checks for
  `ldid` on Linux; `patch_ramdisk` no longer exits early on non-Darwin
  hosts and uses `dmg_attach`/`dmg_detach`/`copy_tree` plus
  `ldid -Cadhoc -S` / `ldid -h` in place of `codesign` on Linux; new
  `patch_bootkc` step runs right after `bootkc` is downloaded.
- `fix_perms.sh` — sources `dmgutil.sh`, uses `dmg_attach`/`dmg_detach`, and
  chowns to `0:0` instead of `root:wheel` on Linux (same uid/gid pair).
- `dt_fixup.py` — removes the `sep` device-tree node and sets
  `sepfw-load-at-boot=0`, stopping `AppleCredentialManager`'s infinite
  `ACMTRM: waitForSEPEndpoint: timed out waiting for AppleSEPManager` retry
  loop (this VM never emulates a SEP). Applies to iOS and macOS guests
  equally, independent of host OS.
- `run.sh` — added `trm_enabled=0 hidrm_enabled=0` to `BOOT_ARGS` as a
  secondary, harmless mitigation for the same SEP-retry noise (kept even
  though the device-tree fix above is what actually stops it).

All host-OS-specific behavior is gated behind `[[ "$(uname)" == "Darwin" ]]`
checks, so none of the above changes anything about the macOS code path.

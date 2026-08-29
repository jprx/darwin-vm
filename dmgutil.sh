#!/bin/bash
# Shared helpers for mounting/ unmounting firmware/ramdisk.dmg (an Apple APFS
# container image), used by get_files.sh and fix_perms.sh.
#
# On macOS this just wraps hdiutil. On Linux there's no hdiutil, so we use the
# linux-apfs-rw kernel module instead: https://github.com/linux-apfs/linux-apfs-rw
#
#   git clone https://github.com/linux-apfs/linux-apfs-rw.git
#   cd linux-apfs-rw && make
#   sudo modprobe libcrc32c
#   sudo insmod apfs.ko
#
# This module's write support is experimental, which is fine for our purposes
# (we're building a disposable VM disk image, not a system you rely on).

# Mounts $1 (ramdisk.dmg) read-write at mountpoint $2.
# $3 selects whether on-disk ownership is honored:
#   on  - present real on-disk uid/gid (used by fix_perms.sh to inspect/ fix them)
#   off - present the invoking user as the owner of everything, so unprivileged
#         mv/mkdir/cp can freely restructure the filesystem (used by get_files.sh)
dmg_attach() {
    local dmg="$1" mountpoint="$2" owners="$3"

    if [[ "$(uname)" == "Darwin" ]]; then
        hdiutil attach -owners "${owners}" -mountpoint "${mountpoint}" "${dmg}"
        return $?
    fi

    if ! grep -q '^apfs ' /proc/modules; then
        echo "error: the 'apfs' kernel module isn't loaded." 1>&2
        echo "  get it from https://github.com/linux-apfs/linux-apfs-rw" 1>&2
        echo "  build with 'make', then 'sudo modprobe libcrc32c && sudo insmod apfs.ko'" 1>&2
        return 1
    fi

    local opts="loop,readwrite"
    [[ "${owners}" == "off" ]] && opts+=",uid=$(id -u),gid=$(id -g)"
    sudo mount -t apfs -o "${opts}" "${dmg}" "${mountpoint}"
}

dmg_detach() {
    local mountpoint="$1"

    if [[ "$(uname)" == "Darwin" ]]; then
        hdiutil detach "${mountpoint}"
        return $?
    fi

    sudo umount "${mountpoint}"
}

# Recursively copies the *contents* of directory $1 into (possibly existing)
# directory $2, merging with anything already there (macOS's ditto does this;
# cp -a needs a trailing "/." on the source to get the same behavior).
copy_tree() {
    local src="$1" dst="$2"

    if [[ "$(uname)" == "Darwin" ]]; then
        ditto "${src}" "${dst}"
        return $?
    fi

    mkdir -p "${dst}"
    # --remove-destination: the Linux apfs driver's experimental write support
    # doesn't implement O_TRUNC (opening an existing file for overwrite), so
    # we have to unlink-then-create instead of truncate-in-place.
    cp -a --remove-destination "${src}/." "${dst}/"
}

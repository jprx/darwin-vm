#!/bin/bash
set -euo pipefail

FIRMWARE_DIR="firmware"
QEMU="qemu-sptm/build/qemu-system-aarch64"
BOOT_ARGS="rd=md0 serial=3 -v -noprogress wdt=-1 wlan-olyhal-abort trm_enabled=0 hidrm_enabled=0"

fix_tty() {
    stty sane
}

boot_qemu() {
    args=(
        -M darwin
        -bootkc   "${FIRMWARE_DIR}/bootkc"
        -dtree    "${FIRMWARE_DIR}/dtree"
        -tc       "${FIRMWARE_DIR}/ramdisk.tc"
        -ramdisk  "${FIRMWARE_DIR}/ramdisk.dmg"
        -args     "${BOOT_ARGS}"
        -nographic
        -serial mon:stdio
        -m 8G
    )

    if [[ -f "${FIRMWARE_DIR}/sptm" ]]; then
        args+=(
            -sptm     "${FIRMWARE_DIR}/sptm"
            -txm      "${FIRMWARE_DIR}/txm"
        )
    fi

    "${QEMU}" "${args[@]}"
}

main() {
    trap 'fix_tty' EXIT
    boot_qemu
}

main "$@"

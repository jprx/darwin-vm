#!/bin/bash
set -euo pipefail

FIRMWARE_DIR="firmware"
QEMU="qemu-sptm/build/qemu-system-aarch64"
BOOT_ARGS="rd=md0 serial=3 -v -noprogress wdt=-1 wlan-olyhal-abort"
ENABLE_QEMUPORTS=0

fix_tty() {
    if [[ -t 0 ]]; then
        stty sane
    fi
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

    if [[ "${ENABLE_QEMUPORTS}" = 1 ]]; then
        args+=(
            # qemuport0:
            -chardev "socket,id=s0,host=localhost,server=on,wait=off,port=2100"
            -serial chardev:s0

            # Uncomment the following to enable more ports if you need them:
            # # qemuport1:
            # -chardev "socket,id=s1,host=localhost,server=on,wait=off,port=2101"
            # -serial chardev:s1

            # # qemuport2:
            # -chardev "socket,id=s2,host=localhost,server=on,wait=off,port=2102"
            # -serial chardev:s2

            # # qemuport3:
            # -chardev "socket,id=s3,host=localhost,server=on,wait=off,port=2103"
            # -serial chardev:s3
        )
    fi

    "${QEMU}" "${args[@]}"
}

main() {
    trap 'fix_tty' EXIT

    while getopts "hp" opt; do
        case "${opt}" in
            p)
                ENABLE_QEMUPORTS=1
                ;;
            *)
                echo "usage: ${0} [-p] [-h]"
                exit 0
                ;;
        esac
    done

    boot_qemu
}

main "$@"

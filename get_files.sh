#!/bin/bash
set -euo pipefail

# Default device: iPhone 16 on iOS 27.0 beta 8
# I picked iPhone 16 as the default instead of iPhone 17, as it doesn't have MTE and therefore runs faster.
# (note that iPhone 16's device name is confusingly "iPhone17,3")
: "${DEVNAME:=iPhone17,3}"
: "${URL:=https://updates.cdn-apple.com/2026SpringSeed/2d03d580-843b-4b2a-b09d-976b31c10744/iPhone17,3_27.0_24A5430a_Restore.ipsw}"

IPSW_BIN="ipsw_db"

IOS_SYSROOT_TARFILE="ios_sysroot.tar.gz"

ADT_FIXUP="./dt_fixup.py"
NVRAM_BIN="nvram.bin"
BUILD_TC="./build_tc.py"

FW_DIR="firmware"

SHELL_LAUNCHD_PLIST="launchdaemons/com.jprx.bash.plist"

warn() {
    echo "warning: $*" 1>&2
}

die() {
    echo "error: $*" 1>&2
    exit 1
}

ensure_installed() {
    if [[ ! -x $(command -v "jq") ]]; then
        die "missing jq command (brew install jq)"
    fi

    if [[ ! -x $(command -v "ipsw") ]]; then
        die "missing ipsw command (brew install ipsw)"
    fi
}

setup_dirs() {
    mkdir -p "${FW_DIR}"
}

identify_device() {
    local dev_info

    dev_info=$(ipsw device-info -j -d "${DEVNAME}")
    BOARD_NAME=$(printf '%s' "${dev_info}" | jq -r '.[] | .boards | to_entries[] | select(.key | contains("DEV") | not) | .key // empty' | tr '[:upper:]' '[:lower:]')
    KERNEL_EXT=$(printf '%s' "${dev_info}" | jq -r '.[] | .boards | to_entries[] | select(.key | contains("DEV")) | .value | .kc_type // empty')
    CHIP_NAME=$(printf '%s' "${dev_info}" | jq -r '.[] | .boards | to_entries[] | select(.key | contains("DEV")) | .value | .platform // empty')
    SYS_SDK=$(printf '%s' "${dev_info}" | jq -r '.[] | .sdk // empty')

    if [[ -z "${BOARD_NAME}" || -z "${KERNEL_EXT}" || -z "${CHIP_NAME}" || -z "${SYS_SDK}" ]]; then
        die "identify_device failed"
    fi

    echo "${DEVNAME}" > "${FW_DIR}/info"
    echo "${URL}" >> "${FW_DIR}/info"

    echo "${DEVNAME}"
    echo "board name: ${BOARD_NAME}"
    echo "kernel ext: ${KERNEL_EXT}"
    echo "chip name:  ${CHIP_NAME}"
    echo "os sdk:     ${SYS_SDK}"
    echo ""
}

check_for_file() {
    remote_files=$(ipsw info --remote "${URL}" --list)
    printf "%s\n" "${remote_files}" | grep -q "${1}"
}

download_pattern() {
    ipsw extract --remote "${URL}" --output "${IPSW_BIN}" --flat --pattern "${1}" -j | jq -r '.[0] // empty'
}

unwrap_img4() {
    ipsw img4 im4p extract "${1}" -o "${FW_DIR}/${2}" 1>&2
}

get_file() {
    local pattern="${1}" outname="${2}"
    local downloaded_file

    downloaded_file=$(download_pattern "${pattern}")

    if [[ ! -f "${downloaded_file}" ]]; then
        die "file matching ${pattern} doesn't exist in remote IPSW"
    fi

    unwrap_img4 "${downloaded_file}" "${outname}"
}

patch_dtree() {
    local dtree

    dtree="${FW_DIR}/dtree"

    if [[ ! -f "${dtree}" ]]; then
        die "No device tree (${dtree})"
    fi

    "${ADT_FIXUP}" -nvram "${NVRAM_BIN}" "${dtree}" "${dtree}_patch"
    mv "${dtree}_patch" "${dtree}"
}

get_firmware() {
    get_file "kernelcache.release.${KERNEL_EXT}" "bootkc"

    # not all chips have SPTM
    if check_for_file "sptm.${CHIP_NAME}.release"; then
        get_file "sptm.${CHIP_NAME}.release" "sptm"
        get_file "txm.${SYS_SDK}.release" "txm"
    else
        if [[ -f "${FW_DIR}/sptm" || -f "${FW_DIR}/txm" ]]; then
            die "sptm/ txm bins present in ./firmware, but ${CHIP_NAME} doesn't have SPTM for this release. Delete firmware/sptm and firmware/txm to continue"
        fi
    fi

    get_file "DeviceTree.${BOARD_NAME}" "dtree"
}

get_ramdisk() {
    local ramdisk_im4p
    ramdisk_im4p=$(ipsw extract --remote "${URL}" --output "${IPSW_BIN}" --flat -j --dmg rdisk | jq -r '.[0] // empty')

    if [[ ! -f "${ramdisk_im4p}" || -z "${ramdisk_im4p}" ]]; then
        die "failed to get ramdisk"
    fi

    # Confirm the thing we got is a .dmg, and not a .aea
    # At the time of writing, ramdisks are not encrypted, so we don't need to deal with aeas
    if [[ "${ramdisk_im4p}" != *.dmg ]]; then
        die "ramdisk (${ramdisk_im4p}) is not a dmg"
    fi

    unwrap_img4 "${ramdisk_im4p}" "ramdisk.dmg"

    # If you want to get the trustcache directly from the IPSW instead of
    # generating it manually, you could do that like this:
    # ramdisk_name=$(basename "${ramdisk_im4p}")
    # trustcache_name="${ramdisk_name/dmg/dmg.trustcache}"
    # get_file "${trustcache_name}" "ramdisk.tc"
}

patch_ramdisk() {
    local ramdisk
    ramdisk="${FW_DIR}/ramdisk.dmg"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo "This isn't a Mac, so we can't patch the ramdisk- stopping here"
        exit 0
    fi

    echo "Patching ${ramdisk}"

    livemount="$(mktemp -d)"

    if [[ -z "${livemount}" || ! -d "${livemount}" ]]; then
        die "something's wrong with the livemount, stopping here"
    fi

    # mount with -owners off to perform complicated FS ops without root, later
    # we can chown everything to root.
    if ! hdiutil attach -owners off -mountpoint "${livemount}" "${ramdisk}"; then
        rmdir "${livemount}"
        die "mount failed"
    fi

    echo "mounted ${ramdisk} on ${livemount}"
    trap 'hdiutil detach ${livemount}; rmdir ${livemount}' EXIT

    if [[ -d "${livemount}/System/Library/LaunchDaemons.old" ]]; then
        echo "already patched"
        return
    fi

    mv "${livemount}/System/Library/LaunchDaemons" "${livemount}/System/Library/LaunchDaemons.old"
    mkdir "${livemount}/System/Library/LaunchDaemons"

    case "${SYS_SDK}" in
        'iphoneos')
            cp "${SHELL_LAUNCHD_PLIST}" "${livemount}/System/Library/LaunchDaemons"

            if [[ ! -f "${IOS_SYSROOT_TARFILE}" ]]; then
                echo "couldn't find the iOS sysroot"
                exit 1
            fi

            echo "extracting iOS sysroot..."
            tar xf "${IOS_SYSROOT_TARFILE}" --directory "${livemount}" --strip-components 1
            echo "signing binaries..."
            find "${livemount}/bin" -type f -exec codesign -s - {} \;
            ;;
        'macosx')
            cp "${SHELL_LAUNCHD_PLIST}" "${livemount}/System/Library/LaunchDaemons"
            ;;
        *)
            die "unknown SDK (${SYS_SDK})"
            ;;
    esac

    echo "building trustcache..."
    find "${livemount}" -type f -exec codesign -d -vvv {} \; 2>&1 | grep -i cdhash= | cut -d= -f2- > "${FW_DIR}/all_hashes"
    "${BUILD_TC}" "${FW_DIR}/all_hashes" "${FW_DIR}/ramdisk.tc"
}

main() {
    ensure_installed
    setup_dirs
    identify_device
    get_firmware
    get_ramdisk
    patch_dtree
    patch_ramdisk
    echo "done!"
}

main "$@"

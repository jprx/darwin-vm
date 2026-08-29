#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/dmgutil.sh"

fixup_perms() {
    local ramdisk="${1}"
    livemount="$(mktemp -d)"

    if [[ -z "${livemount}" || ! -d "${livemount}" ]]; then
        echo "something's wrong with the livemount, stopping here"
        exit 1
    fi

    if ! dmg_attach "${ramdisk}" "${livemount}" on; then
        echo "mount failed"
        rmdir "${livemount}"
        exit 1
    fi

    echo "mounted ${ramdisk} on ${livemount}"
    trap 'dmg_detach "${livemount}"; rmdir "${livemount}"' EXIT

    # root:wheel on macOS and root:root (0:0) on Linux are the same uid/gid
    # pair (0/0); XNU only cares about the numeric ids.
    local owner_group="root:wheel"
    [[ "$(uname)" != "Darwin" ]] && owner_group="0:0"

    echo "This will run: sudo chown -R ${owner_group} ${livemount}/bin ${livemount}/System ${livemount}/libexec"
    read -r -p "Are you sure? (y/n) " response
    echo "${response}"

    case "${response}" in
        [Yy])
            sudo chown -R "${owner_group}" "${livemount}/bin" "${livemount}/System"

            if [[ -d "${livemount}/libexec" ]]; then
                sudo chown -R "${owner_group}" "${livemount}/libexec"
            fi
            echo "done!"
            ;;
        *)
            echo "skipping permission fixes"
            ;;
    esac
}

main() {
    if [[ -z "${1:-}" ]]; then
        echo "usage: fix_perms.sh [ramdisk.dmg]"
        exit 1
    fi

    fixup_perms "${1}"
}

main "$@"

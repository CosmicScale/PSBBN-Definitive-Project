#!/usr/bin/env bash
# Platform strategy. Linux and Windows (WSL) keep the kernel device-mapper
# path. Darwin has no device-mapper, so slices live in a normal directory.

platform_mapper_dir() {
    if [[ "$(uname -s)" == Darwin ]]; then
        # Fixed /tmp path keyed by the invoking user: a shim that runs under
        # real sudo (TMPDIR stripped, UID 0) must see the same slices.
        local dir="${PSBBN_MAPPER_DIR:-/tmp/psbbn-mapper-${SUDO_UID:-$UID}}"
        /bin/mkdir -p "$dir"
        printf '%s\n' "$dir"
        return 0
    fi
    printf '%s\n' /dev/mapper
}

platform_mapper_prefix() {
    local cut="$1"
    local dir
    dir=$(platform_mapper_dir)
    if [[ "$(uname -s)" == Darwin ]]; then
        printf '%s/%s-\n' "$dir" "$cut"
    else
        printf '/dev/mapper/%s-\n' "$cut"
    fi
}

_psbbn_platform=${BASH_SOURCE[0]%/*}
# shellcheck disable=SC1091
. "${_psbbn_platform}/darwin/lib.sh"

# Password prompt stays on the terminal when the caller has redirected the log.
# Then the command runs with sudo -n so a later redirect cannot ask again.
# PSBBN_SUDO replaces /usr/bin/sudo in tests; it is called without -n/-v.
platform_elevate() {
    local arg node disk part status released=""
    local -a disks=()
    if [[ "$(uname -s)" != Darwin ]]; then
        command sudo "$@"
        return $?
    fi
    # Check every disk-looking argument, including if=/of= forms and the
    # installer's concatenated ${DEVICE}3 (/dev/disk43 means /dev/disk4s3).
    # The rewrite is for the check only; the command receives its arguments
    # unchanged.
    for arg in "$@"; do
        case "$arg" in
            *=/dev/*) arg=${arg#*=} ;;
        esac
        node=$(psbbn_rewrite_device "$arg")
        psbbn_is_real_disk "$node" || continue
        if psbbn_disk_internal "$node"; then
            printf '%s\n' "Refusing internal disk $node" >&2
            return 2
        fi
        if psbbn_is_partition_node "$node"; then
            # A partition opens fine while its siblings are mounted; only
            # Disk Arbitration's automount of the drive is in the way.
            psbbn_evict_automounts "$node"
            continue
        fi
        disk=$(psbbn_whole_disk "$node")
        if [[ ${#disks[@]} -eq 0 || " ${disks[*]} " != *" $disk "* ]]; then
            disks+=("$disk")
        fi
    done
    if [[ -z "${PSBBN_SUDO:-}" ]] && ! /usr/bin/sudo -n true 2>/dev/null; then
        printf '%s\n' "Administrator password is required to write the PS2 drive." >/dev/tty
        /usr/bin/sudo -v </dev/tty >/dev/tty 2>/dev/tty || return $?
    fi
    # macOS refuses a whole-disk open while any volume of the drive is
    # mounted, the installer's own OPL mount included. Linux allows it. The
    # drive's mounts are released for the duration and restored afterwards.
    if [[ ${#disks[@]} -gt 0 ]]; then
        for disk in "${disks[@]}"; do
            if ! part=$(psbbn_release_disk "$disk" </dev/null); then
                [[ -n "$released" ]] && psbbn_restore_disk "$released" </dev/null
                return 1
            fi
            released+="$part"
        done
    fi
    if [[ -n "${PSBBN_SUDO:-}" ]]; then
        "$PSBBN_SUDO" "$@"
    else
        /usr/bin/sudo -n "$@"
    fi
    status=$?
    if [[ -n "$released" ]]; then
        psbbn_restore_disk "$released" </dev/null || return 1
    fi
    return $status
}

#!/usr/bin/env bash
# Platform strategy. Linux and Windows (WSL) keep the kernel device-mapper
# path. Darwin has no device-mapper, so slices live in a normal directory.

platform_mapper_dir() {
    if [[ "$(uname -s)" == Darwin ]]; then
        local dir="${PSBBN_MAPPER_DIR:-${TMPDIR:-/tmp}/psbbn-mapper-${UID}}"
        mkdir -p "$dir"
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
platform_elevate() {
    local arg
    if [[ "$(uname -s)" != Darwin ]]; then
        command sudo "$@"
        return $?
    fi
    for arg in "$@"; do
        if psbbn_is_real_disk "$arg" && psbbn_disk_internal "$arg"; then
            printf '%s\n' "Refusing internal disk $arg" >&2
            return 2
        fi
    done
    if ! /usr/bin/sudo -n true 2>/dev/null; then
        printf '%s\n' "Administrator password is required to write the PS2 drive." >/dev/tty
        /usr/bin/sudo -v </dev/tty >/dev/tty 2>/dev/tty || return $?
    fi
    /usr/bin/sudo -n "$@"
}

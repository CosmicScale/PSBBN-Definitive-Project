#!/bin/bash
# Front door for ./PSBBN-Definitive-Patch.sh on macOS.
# The preamble execs this file under bash 3.2. Re-exec Homebrew bash 5
# before any bash-4 syntax. Intel Homebrew lives in /usr/local.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)

bash5=""
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [[ -x "$candidate" ]]; then
        bash5="$candidate"
        break
    fi
done
if [[ -z "$bash5" ]]; then
    echo "Homebrew bash 5 is required. brew install bash" >&2
    exit 1
fi

if [[ -z "${PSBBN_DARWIN_INNER:-}" && "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    export PSBBN_DARWIN_INNER=1
    export PSBBN_DARWIN_ENTERED=1
    exec "$bash5" "$0" "$@"
fi

# shellcheck disable=SC1091
. "$here/lib.sh"

export PSBBN_DARWIN_ENTERED=1
export PSBBN_DARWIN_INNER=1

orig_path="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
path="$here/bin"
if command -v brew >/dev/null 2>&1; then
    icu=$(brew --prefix icu4c 2>/dev/null || true)
    pkg="$here/pkgconfig"
    if [[ -n "${icu:-}" && -d "$icu/lib/pkgconfig" ]]; then
        pkg="$pkg:$icu/lib/pkgconfig"
    fi
    export PKG_CONFIG_PATH="${pkg}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

    for formula in coreutils grep gnu-sed gawk findutils; do
        prefix=$(brew --prefix "$formula" 2>/dev/null || true)
        if [[ -n "${prefix:-}" && -d "$prefix/libexec/gnubin" ]]; then
            path="$path:$prefix/libexec/gnubin"
        fi
    done
    e2=$(brew --prefix e2fsprogs 2>/dev/null || true)
    if [[ -n "${e2:-}" && -d "$e2/sbin" ]]; then
        path="$path:$e2/sbin"
    fi
fi
path="$path:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$orig_path"
export PATH="$path"
# macOS creates AppleDouble files on copies. The PS2 partitions must not get them.
export COPYFILE_DISABLE=1

overlay="${TMPDIR:-/tmp}/psbbn-overlay-${UID}"
build_overlay "$repo" "$overlay"
cd "$overlay"
# exec keeps this pid. da-veto refuses Disk Arbitration mounts of the
# selected drive for as long as this process lives.
export PSBBN_SESSION_PID=$$
exec "$bash5" "$overlay/PSBBN-Definitive-Patch.sh" "$@"

#!/usr/bin/env bash
# Shared by enter.sh and the darwin shims. Bash 3.2 safe except build_overlay,
# which enter.sh runs only after re-execing Homebrew bash 5.

psbbn_rewrite_device() {
    local p="$1"
    # ${DEVICE}2 and ${DEVICE}3 append one digit: /dev/disk6 + 3 = /dev/disk63.
    # A real whole disk such as /dev/disk12 also ends in a digit. If that node
    # exists, it is the disk, not a concatenated partition.
    if [[ "$p" =~ ^(/dev/r?disk)([0-9]+)([23])$ ]]; then
        if [[ -e "$p" ]]; then
            printf '%s\n' "$p"
            return 0
        fi
        printf '%s%ss%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        return 0
    fi
    printf '%s\n' "$p"
}

psbbn_is_real_disk() {
    case "$1" in
        /dev/disk*|/dev/rdisk*) return 0 ;;
        *) return 1 ;;
    esac
}

# Return 0 when the node is internal or cannot be identified.
# External disks return 1. Linux never calls this.
psbbn_disk_internal() {
    local node="$1"
    case "$node" in
        /dev/disk0|/dev/disk0s*|/dev/rdisk0|/dev/rdisk0s*) return 0 ;;
    esac
    local diskutil="${PSBBN_DISKUTIL:-diskutil}"
    local py="/opt/homebrew/bin/python3"
    [[ -x "$py" ]] || py="/usr/bin/python3"
    "$py" - "$diskutil" "$node" << 'PY'
import plistlib, subprocess, sys
diskutil, node = sys.argv[1], sys.argv[2]
ident = node[5:] if node.startswith("/dev/") else node
try:
    info = plistlib.loads(subprocess.check_output([diskutil, "info", "-plist", ident]))
except Exception:
    sys.exit(0)
if "Internal" not in info or info.get("Internal"):
    sys.exit(0)
sys.exit(1)
PY
}

psbbn_disk_bytes() {
    local node="$1"
    local diskutil="${PSBBN_DISKUTIL:-diskutil}"
    local py="/opt/homebrew/bin/python3"
    [[ -x "$py" ]] || py="/usr/bin/python3"
    "$py" - "$diskutil" "$node" << 'PY'
import plistlib, subprocess, sys
diskutil, node = sys.argv[1], sys.argv[2]
ident = node[5:] if node.startswith("/dev/") else node
info = plistlib.loads(subprocess.check_output([diskutil, "info", "-plist", ident]))
size = int(info.get("TotalSize") or info.get("Size") or 0)
sys.stdout.write(str(size))
PY
}

psbbn_gnu_sed() {
    if [[ -n "${PSBBN_REAL_SED:-}" ]]; then
        printf '%s\n' "$PSBBN_REAL_SED"
        return 0
    fi
    if [[ -x /opt/homebrew/opt/gnu-sed/libexec/gnubin/sed ]]; then
        printf '%s\n' /opt/homebrew/opt/gnu-sed/libexec/gnubin/sed
        return 0
    fi
    if [[ -x /usr/local/opt/gnu-sed/libexec/gnubin/sed ]]; then
        printf '%s\n' /usr/local/opt/gnu-sed/libexec/gnubin/sed
        return 0
    fi
    printf '%s\n' /usr/bin/sed
}

# File-level symlinks so `rm` inside the overlay does not delete the repo.
# build_overlay REPO DEST
build_overlay() {
    local repo="$1" dest="$2" rel dir
    rm -rf "$dest"
    mkdir -p "$dest"
    (
        cd "$repo" || exit 1
        find . -print0
    ) | while IFS= read -r -d '' rel; do
        case "$rel" in
            ./.git|./.git/*) continue ;;
            ./scripts/venv|./scripts/venv/*) continue ;;
        esac
        if [[ -d "$repo/$rel" && ! -L "$repo/$rel" ]]; then
            mkdir -p "$dest/$rel"
        elif [[ -e "$repo/$rel" || -L "$repo/$rel" ]]; then
            dir=$(dirname "$dest/$rel")
            mkdir -p "$dir"
            ln -s "$repo/$rel" "$dest/$rel"
        fi
    done
    ln -s "$repo/.git" "$dest/.git"
    if [[ -d "$repo/scripts/venv" ]]; then
        ln -s "$repo/scripts/venv" "$dest/scripts/venv"
    fi
    psbbn_link_helpers "$repo" "$dest"
}

psbbn_link_helpers() {
    local repo="$1" dest="$2" arch name src base
    arch=$(/usr/bin/uname -m)
    if [[ "$arch" == arm64 ]]; then
        base="$repo/scripts/helper/darwin-arm64"
    elif [[ "$arch" == x86_64 ]]; then
        base="$repo/scripts/helper/darwin-x86_64"
    else
        return 0
    fi
    [[ -d "$base" ]] || return 0
    local names=(
        "cue2pops"
        "HDL Dump.elf"
        "mkfs.exfat"
        "PFS Fuse.elf"
        "PFS Shell.elf"
        "PS2 APA Header Checksum Fixer.elf"
        "PSU Extractor.elf"
        "sqlite"
    )
    for name in "${names[@]}"; do
        src="$base/$name"
        [[ -e "$src" ]] || continue
        for slot in "$dest/scripts/helper/$name" "$dest/scripts/helper/aarch64/$name"; do
            rm -f "$slot"
            ln -s "$src" "$slot"
        done
    done
}

#!/usr/bin/env bash
# Shared by enter.sh and the darwin shims. Bash 3.2 safe except build_overlay,
# which enter.sh runs only after re-execing Homebrew bash 5.
#
# macOS 27 panicked twice when installer writes went through FUSE-T or a
# disk image. Nothing here mounts ext2, FAT or PFS. A "mounted" partition is
# an ordinary directory; unmount writes the directory back with debugfs,
# mtools or pfsshell and then copies the slice onto the PS2 drive with dd.

_psbbn_darwin_dir=${BASH_SOURCE[0]%/*}
[[ "$_psbbn_darwin_dir" == "${BASH_SOURCE[0]}" ]] && _psbbn_darwin_dir=.
_psbbn_darwin_dir=$(cd "$_psbbn_darwin_dir" && pwd)

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

# /dev/rdisk4s2 -> /dev/disk4
psbbn_whole_disk() {
    local node="$1"
    if [[ "$node" =~ ^/dev/r?(disk[0-9]+) ]]; then
        printf '/dev/%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    printf '%s\n' "$node"
}

psbbn_is_partition_node() {
    [[ "$1" =~ ^/dev/r?disk[0-9]+s[0-9]+$ ]]
}

psbbn_python() {
    local py="/opt/homebrew/bin/python3"
    [[ -x "$py" ]] || py="/usr/local/bin/python3"
    [[ -x "$py" ]] || py="/usr/bin/python3"
    printf '%s\n' "$py"
}

psbbn_diskutil_plist() {
    local node="$1" field="$2"
    local diskutil="${PSBBN_DISKUTIL:-diskutil}"
    "$(psbbn_python)" - "$diskutil" "$node" "$field" << 'PY'
import plistlib, subprocess, sys
diskutil, node, field = sys.argv[1:4]
ident = node[5:] if node.startswith("/dev/") else node
if ident.startswith("rdisk"):
    ident = ident[1:]
try:
    info = plistlib.loads(subprocess.check_output([diskutil, "info", "-plist", ident], stderr=subprocess.DEVNULL))
except Exception:
    raise SystemExit(1)
value = info.get(field)
if value is None:
    raise SystemExit(0)
if isinstance(value, bool):
    sys.stdout.write("true" if value else "false")
else:
    sys.stdout.write(str(value))
PY
}

# Return 0 when the node is internal or cannot be identified.
# External disks return 1. Linux never calls this.
psbbn_disk_internal() {
    local node="$1" internal
    case "$node" in
        /dev/disk0|/dev/disk0s*|/dev/rdisk0|/dev/rdisk0s*) return 0 ;;
    esac
    internal=$(psbbn_diskutil_plist "$node" Internal) || return 0
    [[ "$internal" == false ]] && return 1
    return 0
}

psbbn_disk_bytes() {
    local node="$1" size
    size=$(psbbn_diskutil_plist "$node" TotalSize)
    [[ -n "$size" ]] || size=$(psbbn_diskutil_plist "$node" Size)
    printf '%s\n' "${size:-0}"
}

# exfat, msdos, or empty for anything macOS does not recognise (ext2, PFS).
psbbn_diskutil_fstype() {
    psbbn_diskutil_plist "$1" FilesystemType | tr 'A-Z' 'a-z'
}

psbbn_diskutil_mountpoint() {
    psbbn_diskutil_plist "$1" MountPoint
}

# Before a whole-disk write: refuse internal disks, evict the drive's
# /Volumes automounts. The installer's own mounts are platform_elevate's job.
psbbn_quiesce_disk() {
    local whole
    whole=$(psbbn_whole_disk "$1")
    psbbn_is_real_disk "$whole" || return 0
    psbbn_disk_internal "$whole" && return 0
    psbbn_evict_automounts "$whole"
}

# ext2, vfat, or empty. Used to decide how a slice file is staged.
psbbn_slice_kind() {
    "$(psbbn_python)" - "$1" << 'PY'
import sys
path = sys.argv[1]
try:
    with open(path, "rb") as fh:
        data = fh.read(4096)
except OSError:
    sys.stdout.write("empty")
    raise SystemExit(0)
if len(data) >= 1082 and data[1080:1082] == b"\x53\xef":
    sys.stdout.write("ext2")
elif len(data) >= 512 and data[510:512] == b"\x55\xaa" and data[:1] in (b"\xeb", b"\xe9"):
    sys.stdout.write("vfat")
else:
    sys.stdout.write("empty")
PY
}

# Copy a 512-byte sector window. seek_sec is where the window starts in dest.
psbbn_dd_window() {
    local mode="$1" src="$2" dst="$3" skip_sec="$4" count_sec="$5" seek_sec="$6"
    local dd="${PSBBN_DD:-/bin/dd}"
    local -a args
    if (( skip_sec % 2048 == 0 && count_sec % 2048 == 0 && seek_sec % 2048 == 0 && count_sec > 0 )); then
        args=(if="$src" of="$dst" bs=1048576 skip=$((skip_sec / 2048)) count=$((count_sec / 2048)) seek=$((seek_sec / 2048)) conv=notrunc)
    else
        args=(if="$src" of="$dst" bs=512 skip="$skip_sec" count="$count_sec" seek="$seek_sec" conv=notrunc)
    fi
    if [[ "$mode" == elevate ]]; then
        if psbbn_is_real_disk "$dst" && ! psbbn_is_partition_node "$dst"; then
            psbbn_quiesce_disk "$dst"
        fi
        platform_elevate "$dd" "${args[@]}"
    else
        "$dd" "${args[@]}"
    fi
}

# Read the APA slice off its backing device into the slice file.
# Internal disks are refused. Regular files are copied without sudo.
psbbn_copy_range() {
    local device="$1" start="$2" sectors="$3" dest="$4" raw
    if psbbn_is_real_disk "$device"; then
        if psbbn_disk_internal "$device"; then
            printf '%s\n' "mount: refusing internal disk $device" >&2
            return 2
        fi
        raw="$device"
        case "$device" in
            /dev/disk*) raw="/dev/r${device#/dev/}" ;;
        esac
        if ! declare -F platform_elevate >/dev/null 2>&1; then
            printf '%s\n' "mount: cannot read $device" >&2
            return 1
        fi
        psbbn_dd_window elevate "$raw" "$dest" "$start" "$sectors" 0
        return $?
    fi
    if [[ ! -f "$device" ]]; then
        printf '%s\n' "mount: backing device not found: $device" >&2
        return 1
    fi
    psbbn_dd_window direct "$device" "$dest" "$start" "$sectors" 0
}

# Write the slice file back onto the same window. conv=notrunc is mandatory.
psbbn_writeback_range() {
    local device="$1" start="$2" sectors="$3" src="$4" raw
    if psbbn_is_real_disk "$device"; then
        if psbbn_disk_internal "$device"; then
            printf '%s\n' "umount: refusing internal disk $device" >&2
            return 2
        fi
        raw="$device"
        case "$device" in
            /dev/disk*) raw="/dev/r${device#/dev/}" ;;
        esac
        if ! declare -F platform_elevate >/dev/null 2>&1; then
            printf '%s\n' "umount: cannot write $device" >&2
            return 1
        fi
        psbbn_dd_window elevate "$src" "$raw" 0 "$sectors" "$start"
        return $?
    fi
    if [[ ! -f "$device" ]]; then
        printf '%s\n' "umount: backing device not found: $device" >&2
        return 1
    fi
    psbbn_dd_window direct "$src" "$device" 0 "$sectors" "$start"
}

psbbn_mke2fs_bin() {
    local candidate
    for candidate in \
        /opt/homebrew/opt/e2fsprogs/sbin/mke2fs \
        /usr/local/opt/e2fsprogs/sbin/mke2fs
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

psbbn_debugfs_bin() {
    local candidate
    if [[ -n "${PSBBN_DEBUGFS:-}" && -x "${PSBBN_DEBUGFS}" ]]; then
        printf '%s\n' "${PSBBN_DEBUGFS}"
        return 0
    fi
    for candidate in \
        /opt/homebrew/opt/e2fsprogs/sbin/debugfs \
        /usr/local/opt/e2fsprogs/sbin/debugfs
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf '%s\n' "debugfs is not installed (brew install e2fsprogs)" >&2
    return 1
}

psbbn_mcopy_bin() {
    local candidate
    if [[ -n "${PSBBN_MCOPY:-}" && -x "${PSBBN_MCOPY}" ]]; then
        printf '%s\n' "${PSBBN_MCOPY}"
        return 0
    fi
    for candidate in /opt/homebrew/bin/mcopy /usr/local/bin/mcopy; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf '%s\n' "mcopy is not installed (brew install mtools)" >&2
    return 1
}

psbbn_pfsshell_bin() {
    local arch base
    if [[ -n "${PSBBN_PFSSHELL:-}" && -x "${PSBBN_PFSSHELL}" ]]; then
        printf '%s\n' "${PSBBN_PFSSHELL}"
        return 0
    fi
    arch=$(/usr/bin/uname -m)
    if [[ "$arch" == arm64 ]]; then
        base="$_psbbn_darwin_dir/../../helper/darwin-arm64/pfsshell"
    else
        base="$_psbbn_darwin_dir/../../helper/darwin-x86_64/pfsshell"
    fi
    if [[ -x "$base" ]]; then
        printf '%s\n' "$base"
        return 0
    fi
    printf '%s\n' "pfsshell is not installed" >&2
    return 1
}

# Same ext2 the installer uses when it formats a Linux partition itself.
# -F is required because the slice is a file, and a tty would otherwise prompt.
psbbn_format_ext2_file() {
    local path="$1" mke2fs
    mke2fs=$(psbbn_mke2fs_bin) || {
        printf '%s\n' "mke2fs: e2fsprogs is not installed" >&2
        return 127
    }
    "$mke2fs" -F -q -t ext2 -b 4096 -I 128 \
        -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode \
        "$path"
}

# Linux swap v1. The signature sits at the end of the first 4096-byte page.
psbbn_format_swap_file() {
    local path="$1"
    "$(psbbn_python)" - "$path" << 'PY'
import struct, sys
path = sys.argv[1]
size = __import__("os").path.getsize(path)
page = 4096
if size < page or size % page:
    sys.stderr.write("swap: size must be a multiple of 4096\n")
    raise SystemExit(1)
pages = size // page
hdr = bytearray(page)
struct.pack_into("<I", hdr, 1024, 1)          # version
struct.pack_into("<I", hdr, 1028, pages - 1)  # last_page
hdr[page - 10:page] = b"SWAPSPACE2"
with open(path, "r+b") as fh:
    fh.seek(0)
    fh.write(hdr)
PY
}

# Linux PFS Shell formats EXT2 and EXT2SWAP inside mkpart. Upstream pfsshell
# only creates the APA partition, so the following mount has no filesystem.
psbbn_format_mkpart_ranges() {
    local device="$1" commands="$2" listing="$3" line name fstype start sectors tmp
    while IFS= read -r line; do
        [[ "$line" == mkpart\ * ]] || continue
        name=$(printf '%s\n' "$line" | awk '{print $2}')
        fstype=$(printf '%s\n' "$line" | awk '{print $4}')
        case "$fstype" in
            EXT2|EXT2SWAP) ;;
            *) continue ;;
        esac
        if printf '%s\n' "$commands" | grep -F "${name}: partition already exists." >/dev/null; then
            continue
        fi
        start=""
        sectors=""
        # shellcheck disable=SC1091
        eval "$( "$(psbbn_python)" - "$listing" "$name" << 'PY'
import sys
listing, want = sys.argv[1], sys.argv[2]
for chunk in listing.split(";"):
    chunk = chunk.strip()
    if not chunk:
        continue
    part = chunk.split(",")[0]
    if not part.endswith("-" + want):
        continue
    bits = chunk.split(",")[4].split()
    sys.stdout.write("sectors=%s\nstart=%s\n" % (bits[1], bits[4]))
    break
PY
)"
        if [[ -z "$start" || -z "$sectors" ]]; then
            printf '%s\n' "mkpart: $name was not created on $device" >&2
            return 1
        fi
        tmp=$(mktemp)
        "$(psbbn_python)" - "$tmp" "$((sectors * 512))" << 'PY'
import os, sys
fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR, 0o644)
os.ftruncate(fd, int(sys.argv[2]))
os.close(fd)
PY
        if [[ "$fstype" == EXT2 ]]; then
            psbbn_format_ext2_file "$tmp" >/dev/null || return $?
        else
            psbbn_format_swap_file "$tmp" || return $?
        fi
        psbbn_writeback_range "$device" "$start" "$sectors" "$tmp" || return $?
        rm -f "${tmp:?}"
    done <<< "$commands"
}

# State shared by mount, umount, findmnt, tar and pfs-fuse. The base is a
# fixed /tmp path keyed by the invoking user, so a shim that ends up under
# real sudo (TMPDIR stripped, UID 0) still finds the same records.
psbbn_mount_state_dir() {
    local dir="${PSBBN_MOUNT_STATE:-/tmp/psbbn-mounts-${SUDO_UID:-$UID}}"
    dir="${dir%/}"
    /bin/mkdir -p "$dir"
    printf '%s\n' "$dir"
}

psbbn_mount_key() {
    "$(psbbn_python)" -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.argv[1].encode()).hexdigest())' "$1"
}

# psbbn_stage_save MOUNT SLICE_OR_DEVICE KIND [PARTITION]
psbbn_stage_save() {
    local mnt="$1" slice="$2" kind="$3" part="${4:-}" state key
    state=$(psbbn_mount_state_dir)
    key=$(psbbn_mount_key "$mnt")
    printf '%s\n' "$slice" > "$state/$key"
    printf '%s\n' "$kind" > "$state/$key.kind"
    printf '%s\n' "$mnt" > "$state/$key.mount"
    printf '%s\n' "${PSBBN_SESSION_PID:-}" > "$state/$key.session"
    if [[ -n "$part" ]]; then
        printf '%s\n' "$part" > "$state/$key.part"
    fi
}

psbbn_stage_forget() {
    local mnt="$1" state key suffix
    state=$(psbbn_mount_state_dir)
    key=$(psbbn_mount_key "$mnt")
    for suffix in "" .kind .mount .part .manifest .session; do
        rm -f "${state:?}/${key:?}${suffix}"
    done
}

psbbn_stage_paths() {
    local state f
    state=$(psbbn_mount_state_dir)
    for f in "$state"/*.mount; do
        [[ -f "$f" ]] || continue
        cat "$f"
    done
}

# kind <tab> mount <tab> slice-or-device, one staged partition per line.
psbbn_stage_table() {
    local state f key
    state=$(psbbn_mount_state_dir)
    for f in "$state"/*.mount; do
        [[ -f "$f" ]] || continue
        key=${f%.mount}
        key=${key##*/}
        [[ -f "$state/$key" && -f "$state/$key.kind" ]] || continue
        printf '%s\t%s\t%s\n' "$(cat "$state/$key.kind")" "$(cat "$f")" "$(cat "$state/$key")"
    done
}

psbbn_manifest_path() {
    local state key
    state=$(psbbn_mount_state_dir)
    key=$(psbbn_mount_key "$1")
    printf '%s/%s.manifest\n' "$state" "$key"
}

# Snapshot the staged directory. Unmount only writes back what changed.
psbbn_manifest_write() {
    "$(psbbn_python)" "$_psbbn_darwin_dir/manifest.py" write "$1" "$(psbbn_manifest_path "$1")"
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
# Real files the installer created in an earlier run (downloaded patch
# archives, logs, gamepath.cfg) are kept; only the links are rebuilt.
# build_overlay REPO DEST
build_overlay() {
    local repo="$1" dest="$2" rel dir
    mkdir -p "${dest:?}"
    find "${dest:?}" -type l -delete 2>/dev/null || true
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
            [[ -e "$dest/$rel" ]] && continue
            dir=$(dirname "$dest/$rel")
            mkdir -p "$dir"
            ln -s "$repo/$rel" "$dest/$rel"
        fi
    done
    [[ -e "$dest/.git" ]] || ln -s "$repo/.git" "$dest/.git"
    if [[ -d "$repo/scripts/venv" && ! -e "$dest/scripts/venv" ]]; then
        ln -s "$repo/scripts/venv" "$dest/scripts/venv"
    fi
    psbbn_link_helpers "$repo" "$dest"
}

psbbn_link_helpers() {
    local repo="$1" dest="$2" arch name src base slot
    repo=$(cd "$repo" && pwd)
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
        if [[ "$name" == "PFS Fuse.elf" ]]; then
            src="$repo/scripts/platform/darwin/bin/pfs-fuse"
        else
            src="$base/$name"
        fi
        [[ -e "$src" ]] || continue
        for slot in "$dest/scripts/helper/$name" "$dest/scripts/helper/aarch64/$name"; do
            rm -f "${slot:?}"
            ln -s "$src" "$slot"
        done
    done
}

# Canonical directory path. diskutil reports mount points with symlinks
# resolved (/private/var/...), the installer asks with $TMPDIR (/var/...).
psbbn_realpath() {
    local p="$1"
    if [[ -d "$p" ]]; then
        (cd "$p" 2>/dev/null && pwd -P) && return 0
    fi
    printf '%s\n' "${p%/}"
}

# Disk Arbitration re-probes the drive after every whole-disk write closes
# and mounts its volumes under /Volumes again. Such a mount makes the next
# whole-disk open fail with EBUSY, and for a few seconds after it appears
# macOS will not even unmount it. da-veto is a Disk Arbitration approval
# client that refuses every mount of the selected drive while the installer
# session (PSBBN_SESSION_PID, exported by enter.sh) is alive. The installer's
# own mounts announce themselves with an allow file the client checks.
psbbn_veto_bin() {
    if [[ -n "${PSBBN_DA_VETO:-}" ]]; then
        printf '%s\n' "$PSBBN_DA_VETO"
    elif [[ "$(/usr/bin/uname -m)" == arm64 ]]; then
        printf '%s\n' "$_psbbn_darwin_dir/../../helper/darwin-arm64/da-veto"
    else
        printf '%s\n' "$_psbbn_darwin_dir/../../helper/darwin-x86_64/da-veto"
    fi
}

# psbbn_veto_allow_file NODE -> allow file for NODE's disk; nothing for a non-disk
psbbn_veto_allow_file() {
    local whole
    whole=$(psbbn_whole_disk "$(psbbn_rewrite_device "$1")")
    psbbn_is_real_disk "$whole" || return 0
    printf '%s/allow-%s\n' "$(psbbn_mount_state_dir)" "${whole#/dev/}"
}

# Start the approval client for NODE's disk, once per session. It runs as
# the user; code running under sudo relies on the user side having started it.
psbbn_veto_start() {
    local whole ident state pidfile pid bin i
    [[ -n "${PSBBN_SESSION_PID:-}" && "$EUID" -ne 0 ]] || return 0
    whole=$(psbbn_whole_disk "$(psbbn_rewrite_device "$1")")
    psbbn_is_real_disk "$whole" || return 0
    psbbn_disk_internal "$whole" && return 0
    ident=${whole#/dev/}
    state=$(psbbn_mount_state_dir)
    pidfile="$state/veto-$ident.pid"
    if [[ -s "$pidfile" ]]; then
        pid=$(<"$pidfile")
        # The pid may have been reused by an unrelated process since the last run.
        if [[ "$(ps -o command= -p "$pid" 2>/dev/null)" == *"da-veto $ident "* ]]; then
            return 0
        fi
        rm -f "$pidfile"
    fi
    bin=$(psbbn_veto_bin)
    [[ -x "$bin" ]] || return 0
    "$bin" "$ident" "$state/allow-$ident" "$PSBBN_SESSION_PID" \
        > "$state/veto-$ident.out" 2>> "$state/veto-$ident.log" < /dev/null &
    pid=$!
    disown "$pid" 2>/dev/null || true
    printf '%s\n' "$pid" > "$pidfile"
    for i in 1 2 3 4 5 6 7 8 9 10; do
        grep -q '^ready' "$state/veto-$ident.out" 2>/dev/null && return 0
        sleep 0.2
    done
    printf '%s\n' "warning: da-veto did not report ready for $ident" >&2
    return 0
}

# Mount a real exFAT/FAT partition (the OPL volume) on the path the
# installer asked for; root is not needed unless another user mounted it.
# "diskutil mount -mountPoint X" on an already-mounted volume answers 0 and
# leaves it where it was, so the exit status is never trusted: the mount
# point is read back, a stray /Volumes mount is evicted, and the request is
# retried until the volume sits on the requested path.
psbbn_diskutil_mount() {
    local node="$1" mnt="$2" allow status
    psbbn_veto_start "$node"
    allow=$(psbbn_veto_allow_file "$node")
    [[ -n "$allow" ]] && : > "$allow"
    psbbn_diskutil_mount_attempts "$node" "$mnt"
    status=$?
    [[ -n "$allow" ]] && rm -f "$allow"
    return $status
}

psbbn_diskutil_mount_attempts() {
    local node="$1" mnt="$2" want current attempt last=""
    local diskutil="${PSBBN_DISKUTIL:-diskutil}"
    local settle="${PSBBN_DA_SETTLE:-1}"
    mkdir -p "$mnt" || return 1
    want=$(psbbn_realpath "$mnt")
    for attempt in 1 2 3 4 5 6; do
        current=$(psbbn_diskutil_mountpoint "$node")
        if [[ -n "$current" ]]; then
            if [[ "$(psbbn_realpath "$current")" == "$want" ]]; then
                return 0
            fi
            if ! psbbn_diskutil_unmount "$current" >/dev/null 2>&1; then
                last="could not unmount $node from $current"
                sleep "$settle"
                continue
            fi
        fi
        if ! last=$("$diskutil" mount -mountPoint "$mnt" "$node" 2>&1); then
            if declare -F platform_elevate >/dev/null 2>&1; then
                last=$(platform_elevate "$diskutil" mount -mountPoint "$mnt" "$node" 2>&1) || true
            fi
        fi
        current=$(psbbn_diskutil_mountpoint "$node")
        if [[ -n "$current" && "$(psbbn_realpath "$current")" == "$want" ]]; then
            return 0
        fi
        sleep "$settle"
    done
    printf '%s\n' "mount: diskutil could not mount $node on $mnt (it is on ${current:-nothing})${last:+: $last}" >&2
    return 1
}

psbbn_diskutil_unmount() {
    local target="$1"
    local diskutil="${PSBBN_DISKUTIL:-diskutil}"
    if "$diskutil" unmount "$target" >/dev/null 2>&1; then
        return 0
    fi
    if declare -F platform_elevate >/dev/null 2>&1; then
        platform_elevate "$diskutil" unmount "$target" >/dev/null 2>&1 && return 0
    fi
    "${PSBBN_REAL_UMOUNT:-/sbin/umount}" "$target"
}

psbbn_is_mounted() {
    local target="${1%/}"
    /sbin/mount 2>/dev/null | grep -F " on $target (" >/dev/null
}

# macOS tags new files with com.apple.provenance, inherited from the
# directory tree the installer runs in. On exFAT and FAT that attribute
# becomes a "._name" AppleDouble file beside every entry. Linux never
# writes those, and the PS2 has no use for them, so they go before the
# volume is handed back. Only real macOS mounts of the PS2 drive qualify.
psbbn_strip_appledouble() {
    local target
    target=$(psbbn_realpath "${1%/}")
    /sbin/mount 2>/dev/null | grep -E -q "^/dev/disk[0-9]+s[0-9]+ on ${target} \\(" || return 0
    "${PSBBN_DOT_CLEAN:-/usr/sbin/dot_clean}" -m "$target" 2>/dev/null || true
}

# The kernel mount table. PSBBN_MOUNT_TABLE points at a fixture in tests.
psbbn_mount_table() {
    if [[ -n "${PSBBN_MOUNT_TABLE:-}" ]]; then
        cat "$PSBBN_MOUNT_TABLE"
    else
        /sbin/mount
    fi
}

# Unmount Disk Arbitration's /Volumes mounts of the drive. hdl_dump and
# pfsshell open the whole disk read-write, toc included, and macOS refuses
# that with EBUSY while any volume of the disk is mounted. Mounts the
# installer made itself live outside /Volumes and are left alone.
psbbn_evict_automounts() {
    local whole ident line dev mp
    whole=$(psbbn_whole_disk "$(psbbn_rewrite_device "$1")")
    psbbn_is_real_disk "$whole" || return 0
    psbbn_veto_start "$whole"
    ident=${whole#/dev/}
    while IFS= read -r line; do
        dev=${line%% on *}
        [[ "$dev" =~ ^/dev/${ident}s[0-9]+$ ]] || continue
        mp=${line#* on }
        mp=${mp% (*}
        [[ "$mp" == /Volumes/* ]] || continue
        psbbn_diskutil_unmount "$mp" >/dev/null 2>&1 && continue
        # A volume macOS mounted a moment ago stays busy for a little while.
        sleep "${PSBBN_DA_SETTLE:-1}"
        psbbn_diskutil_unmount "$mp" >/dev/null 2>&1 \
            || printf '%s\n' "warning: could not unmount $mp" >&2
    done < <(psbbn_mount_table 2>/dev/null)
    return 0
}

# Run hdl_dump against the PS2 drive. Between the eviction and the open,
# Disk Arbitration can still land a mount it already had in flight, so an
# EBUSY open (nothing done yet) is evicted again and retried.
# psbbn_hdl_dump BINARY ARGS...
psbbn_hdl_dump() {
    local bin="$1" arg attempt errf status
    shift
    errf=$(mktemp)
    for attempt in 1 2 3 4 5 6; do
        for arg in "$@"; do
            psbbn_evict_automounts "$arg"
        done
        "$bin" "$@" 2> "$errf"
        status=$?
        if [[ "$status" -eq 0 ]] || ! grep -q 'Resource busy' "$errf"; then
            break
        fi
        sleep "${PSBBN_DA_SETTLE:-1}"
    done
    cat "$errf" >&2
    rm -f "${errf:?}"
    return "$status"
}

# pfsshell prints "<device>: Resource busy" and stops when macOS refuses
# the open. Nothing has been written at that point.
psbbn_pfs_open_busy() {
    printf '%s\n' "$2" | grep -F -q "$1: Resource busy"
}

# macOS refuses a whole-disk open while any volume of the drive is mounted,
# the installer's own OPL mount at scripts/OPL included. Linux allows it,
# and Game-Installer lists partitions while OPL is mounted. So the
# installer's mounts of the drive are taken down for the duration of the
# operation and put back on the same path afterwards.
# Prints one "node<TAB>mountpoint" line per mount it released.
psbbn_release_disk() {
    local whole ident line dev mp attempt released=""
    whole=$(psbbn_whole_disk "$(psbbn_rewrite_device "$1")")
    psbbn_is_real_disk "$whole" || return 0
    psbbn_evict_automounts "$whole"
    ident=${whole#/dev/}
    while IFS= read -r line; do
        dev=${line%% on *}
        [[ "$dev" =~ ^/dev/${ident}s[0-9]+$ ]] || continue
        mp=${line#* on }
        mp=${mp% (*}
        [[ "$mp" == /Volumes/* ]] && continue
        for attempt in 1 2 3 4 5; do
            psbbn_diskutil_unmount "$mp" >/dev/null 2>&1
            [[ -z "$(psbbn_diskutil_mountpoint "$dev")" ]] && break
            sleep "${PSBBN_DA_SETTLE:-1}"
        done
        if [[ -n "$(psbbn_diskutil_mountpoint "$dev")" ]]; then
            # Never forced: a busy mount means the installer still holds it.
            printf '%s\n' "could not release $dev from $mp, it is still in use" >&2
            [[ -n "$released" ]] && psbbn_restore_disk "$released"
            return 1
        fi
        released+="$dev"$'\t'"$mp"$'\n'
    done < <(psbbn_mount_table 2>/dev/null)
    printf '%s' "$released"
    return 0
}

# Takes the lines psbbn_release_disk printed. Fails if any mount does not
# come back where it was, so the caller stops instead of letting the
# installer write into a plain directory.
psbbn_restore_disk() {
    local dev mp rc=0
    while IFS=$'\t' read -r dev mp; do
        [[ -n "$dev" ]] || continue
        if ! psbbn_diskutil_mount "$dev" "$mp"; then
            printf '%s\n' "mount: could not put $dev back on $mp" >&2
            rc=1
        fi
    done <<< "$1"
    return $rc
}

# psbbn_with_disk_released DISK CMD ARGS...   (CMD keeps the caller's stdin)
psbbn_with_disk_released() {
    local disk="$1" released status
    shift
    released=$(psbbn_release_disk "$disk" </dev/null) || return 1
    "$@"
    status=$?
    if [[ -n "$released" ]]; then
        psbbn_restore_disk "$released" </dev/null || return 1
    fi
    return $status
}

# A real partition node that macOS cannot read (the ext2 recovery partition
# after APA-Jail) is staged like an APA slice: the whole partition is the
# window. The slice starts fresh on every mount and is removed on unmount.
psbbn_node_slice() {
    local node="$1" bytes sectors dir slice
    bytes=$(psbbn_disk_bytes "$node")
    sectors=$((bytes / 512))
    if (( sectors <= 0 )); then
        printf '%s\n' "mount: cannot size $node" >&2
        return 1
    fi
    dir=$(platform_mapper_dir)
    slice="$dir/$(basename "$node")"
    rm -f "${slice:?}" "${slice:?}.meta"
    "$(psbbn_python)" - "$slice" "$((sectors * 512))" << 'PY'
import os, sys
fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR | os.O_TRUNC, 0o644)
os.ftruncate(fd, int(sys.argv[2]))
os.close(fd)
PY
    printf 'device=%s\nstart=0\nsectors=%s\nnode=1\n' "$node" "$sectors" > "$slice.meta"
    printf '%s\n' "$slice"
}

# debugfs rdump tries to chown as root and warns. The bytes are still there.
psbbn_ext2_export() {
    local image="$1" dest="$2" debugfs out rc
    debugfs=$(psbbn_debugfs_bin) || return 1
    mkdir -p "$dest"
    rc=0
    out=$(COPYFILE_DISABLE=1 "$debugfs" -R "rdump / \"$dest\"" "$image" 2>&1) || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        printf '%s\n' "$out" >&2
        return "$rc"
    fi
}

# Run a debugfs script. Hard links into a full directory are retried after
# expand_dir, existing directories are not re-created, and the image must
# pass e2fsck afterwards. Only real failures are reported.
psbbn_debugfs_apply() {
    local script="$1" image="$2"
    "$(psbbn_python)" "$_psbbn_darwin_dir/debugfs_apply.py" "$image" "$script"
}

# e2fsck gate. Bitmap-free zombie inodes are cleared; anything else fails.
psbbn_ext2_check() {
    "$(psbbn_python)" "$_psbbn_darwin_dir/debugfs_apply.py" --check "$1"
}

# Write the staged directory back into the ext2 image.
# With a manifest only entries that changed since the snapshot are touched:
# new and modified files are written, files the installer removed are
# unlinked. Inodes that never existed on the host (device nodes, the second
# casing of a name APFS folded) are left alone.
# psbbn_ext2_import DIR IMAGE [MANIFEST]
psbbn_ext2_import() {
    local src="$1" image="$2" manifest="${3:-}" script
    script=$(mktemp)
    "$(psbbn_python)" - "$src" "$script" "$manifest" "$_psbbn_darwin_dir" << 'PY'
import os, stat, sys
root, script_path, manifest_path, libdir = sys.argv[1:5]
sys.dont_write_bytecode = True
sys.path.insert(0, libdir)
import manifest as mf

old = mf.load(manifest_path)

def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'

lines = []
first = {}
nlinks = {}
seen = set()
for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
    dirnames[:] = sorted(d for d in dirnames if not mf.skip(d))
    rel = os.path.relpath(dirpath, root)
    rel = "" if rel == "." else rel.replace(os.sep, "/")
    for dirname in dirnames:
        dest = (rel + "/" + dirname) if rel else dirname
        seen.add(dest)
        if dest not in old:
            lines.append("mkdir %s" % quote("/" + dest))
    for filename in sorted(filenames):
        if mf.skip(filename):
            continue
        full = os.path.join(dirpath, filename)
        info = os.lstat(full)
        dest = (rel + "/" + filename) if rel else filename
        seen.add(dest)
        current = mf.entry(full, info)
        quoted = quote("/" + dest)
        key = None
        if stat.S_ISREG(info.st_mode) and info.st_nlink > 1:
            key = (info.st_dev, info.st_ino)
            first.setdefault(key, "/" + dest)
        if old.get(dest) == current:
            continue
        if key is not None:
            # Only inodes this pass writes or links get their count set. An
            # unchanged file keeps the count the image already has; the host
            # count can differ where APFS folded two casings into one name.
            nlinks[key] = info.st_nlink
        if stat.S_ISLNK(info.st_mode):
            lines.append("rm %s" % quoted)
            lines.append("symlink %s %s" % (quoted, quote(os.readlink(full))))
            lines.append("set_inode_field %s uid 0" % quoted)
            lines.append("set_inode_field %s gid 0" % quoted)
            continue
        if not stat.S_ISREG(info.st_mode):
            sys.stderr.write("ext2: unsupported file %s\n" % full)
            raise SystemExit(1)
        if key is not None and first[key] != "/" + dest:
            lines.append("rm %s" % quoted)
            lines.append("ln %s %s" % (quote(first[key]), quoted))
            continue
        lines.append("rm %s" % quoted)
        lines.append("write %s %s" % (quote(full), quoted))
        lines.append("set_inode_field %s mode 0%o" % (quoted, stat.S_IFREG | (info.st_mode & 0o7777)))
        lines.append("set_inode_field %s uid 0" % quoted)
        lines.append("set_inode_field %s gid 0" % quoted)
        lines.append("set_inode_field %s mtime %d" % (quoted, int(info.st_mtime)))
for key, count in nlinks.items():
    if count > 1:
        lines.append("set_inode_field %s links_count %d" % (quote(first[key]), count))
gone_dirs = []
for rel, ent in old.items():
    if rel in seen:
        continue
    if ent[0] in ("f", "l"):
        lines.append("rm %s" % quote("/" + rel))
    elif ent[0] == "d":
        gone_dirs.append(rel)
for rel in sorted(gone_dirs, key=len, reverse=True):
    lines.append("rmdir %s" % quote("/" + rel))
with open(script_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
PY
    local rc=$?
    if [[ "$rc" -eq 0 ]]; then
        psbbn_debugfs_apply "$script" "$image"
        rc=$?
    fi
    rm -f "${script:?}"
    return "$rc"
}

psbbn_tar_needs_image() {
    local dest="${1%/}" kind mnt slice
    while IFS=$'\t' read -r kind mnt slice; do
        [[ "$kind" == ext2 ]] || continue
        mnt=${mnt%/}
        if [[ "$mnt" == "$dest" || "$mnt" == "$dest"/* ]]; then
            return 0
        fi
    done < <(psbbn_stage_table)
    return 1
}

# After an extract the ext2 images already hold their members; snapshot the
# host copies so unmount does not upload them a second time. PFS members
# only reached the host directory, so those snapshots must stay as they were.
psbbn_tar_refresh_manifests() {
    local dest="${1%/}" kind mnt slice
    while IFS=$'\t' read -r kind mnt slice; do
        [[ "$kind" == ext2 ]] || continue
        mnt=${mnt%/}
        if [[ "$mnt" == "$dest" || "$mnt" == "$dest"/* ]]; then
            psbbn_manifest_write "$mnt" || return 1
        fi
    done < <(psbbn_stage_table)
    return 0
}

# Ext2 members are applied to the image. APFS cannot store device nodes or
# both casings of one name, and the patch archive contains both.
psbbn_tar_extract() {
    local archive="$1" dest="$2" table
    table=$(mktemp)
    psbbn_stage_table > "$table"
    "$(psbbn_python)" - "$archive" "$dest" "$table" "$_psbbn_darwin_dir" << 'PY'
import os, shutil, stat, subprocess, sys, tarfile, tempfile

archive, dest, table_path, libdir = sys.argv[1:5]
dest = os.path.abspath(dest)
mounts = []
with open(table_path, encoding="utf-8") as fh:
    for line in fh:
        kind, mnt, image = line.rstrip("\n").split("\t")
        mounts.append((kind, os.path.abspath(mnt), image))
mounts.sort(key=lambda row: len(row[1]), reverse=True)

def clean(name):
    while name.startswith("./"):
        name = name[2:]
    return name.strip("/")

def classify(name):
    full = dest if not name else os.path.normpath(os.path.join(dest, name))
    for kind, mnt, image in mounts:
        if full == mnt or full.startswith(mnt + os.sep):
            rel = os.path.relpath(full, mnt)
            if rel == ".":
                rel = ""
            return kind, image, rel.replace(os.sep, "/")
    return "plain", None, name

def q(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'

def ipath(rel):
    rel = rel.strip("/")
    return "/" + rel if rel else "/"

ext2 = {}
made = set()
links_count = {}
payloads = tempfile.mkdtemp(prefix="psbbn-tar-")
seq = 0

def cmds_for(image):
    return ext2.setdefault(image, [])

def ensure_dir(image, rel):
    if not rel:
        return
    acc = []
    for part in rel.split("/"):
        acc.append(part)
        path = "/".join(acc)
        key = (image, path)
        if key in made:
            continue
        made.add(key)
        cmds_for(image).append("mkdir %s" % q("/" + path))

def meta(image, name, mode, uid, gid, mtime):
    cmds = cmds_for(image)
    cmds.append("set_inode_field %s mode 0%o" % (q(name), mode))
    cmds.append("set_inode_field %s uid %d" % (q(name), uid))
    cmds.append("set_inode_field %s gid %d" % (q(name), gid))
    cmds.append("set_inode_field %s mtime %d" % (q(name), int(mtime)))

def host_member(name, member, tf):
    path = os.path.join(dest, name) if name else dest
    if member.isdir():
        os.makedirs(path, exist_ok=True)
        return
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    if member.issym():
        if os.path.lexists(path):
            os.unlink(path)
        os.symlink(member.linkname, path)
        return
    if member.islnk():
        target_name = clean(member.linkname)
        if classify(target_name)[0] == "plain" and "/" not in target_name:
            target_name = clean(os.path.join(os.path.dirname(name), member.linkname))
        target = os.path.join(dest, target_name)
        if os.path.lexists(path):
            os.unlink(path)
        os.link(target, path)
        return
    if member.isreg():
        src = tf.extractfile(member)
        with open(path, "wb") as out:
            if src is not None:
                shutil.copyfileobj(src, out)
        os.chmod(path, member.mode & 0o777)
        return
    sys.stderr.write("tar: cannot create %s on this filesystem\n" % member.name)
    raise SystemExit(1)

def ext2_member(image, rel, member, tf):
    global seq
    perm = member.mode & 0o7777
    if member.isdir():
        ensure_dir(image, os.path.dirname(rel))
        ensure_dir(image, rel)
        meta(image, ipath(rel), stat.S_IFDIR | (perm & 0o777), member.uid, member.gid, member.mtime)
        return
    ensure_dir(image, os.path.dirname(rel))
    path = ipath(rel)
    if member.issym():
        cmds_for(image).append("rm %s" % q(path))
        cmds_for(image).append("symlink %s %s" % (q(path), q(member.linkname)))
        meta(image, path, stat.S_IFLNK | 0o777, member.uid, member.gid, member.mtime)
        return
    if member.islnk():
        target = clean(member.linkname)
        kind, target_image, target_rel = classify(target)
        if kind != "ext2":
            target = clean(os.path.join(os.path.dirname(clean(member.name)), member.linkname))
            kind, target_image, target_rel = classify(target)
        if kind != "ext2" or target_image != image:
            sys.stderr.write("tar: hard link target is not in this ext2 image: %s\n" % member.name)
            raise SystemExit(1)
        cmds_for(image).append("rm %s" % q(path))
        cmds_for(image).append("ln %s %s" % (q(ipath(target_rel)), q(path)))
        key = (image, ipath(target_rel))
        links_count[key] = links_count.get(key, 1) + 1
        return
    if member.isreg():
        seq += 1
        host = os.path.join(payloads, str(seq))
        src = tf.extractfile(member)
        with open(host, "wb") as out:
            if src is not None:
                shutil.copyfileobj(src, out)
        cmds_for(image).append("rm %s" % q(path))
        cmds_for(image).append("write %s %s" % (q(host), q(path)))
        meta(image, path, stat.S_IFREG | (perm & 0o777), member.uid, member.gid, member.mtime)
        return
    if member.ischr() or member.isblk() or member.isfifo():
        parent = os.path.dirname(rel)
        base = os.path.basename(rel)
        cmds = cmds_for(image)
        cmds.append("cd %s" % q(ipath(parent)))
        cmds.append("rm %s" % q(base))
        if member.ischr():
            cmds.append("mknod %s c %d %d" % (q(base), member.devmajor, member.devminor))
            special = stat.S_IFCHR
        elif member.isblk():
            cmds.append("mknod %s b %d %d" % (q(base), member.devmajor, member.devminor))
            special = stat.S_IFBLK
        else:
            cmds.append("mknod %s p" % q(base))
            special = stat.S_IFIFO
        meta(image, base, special | (perm & 0o777), member.uid, member.gid, member.mtime)
        cmds.append("cd /")
        return
    sys.stderr.write("tar: unsupported member %s\n" % member.name)
    raise SystemExit(1)

def apply_debugfs(image, lines):
    script = tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8")
    script.write("\n".join(lines) + "\n")
    script.close()
    proc = subprocess.run([sys.executable, os.path.join(libdir, "debugfs_apply.py"), image, script.name])
    os.unlink(script.name)
    if proc.returncode != 0:
        raise SystemExit(1)

def extract():
    try:
        tf = tarfile.open(archive, "r:*")
    except tarfile.TarError as exc:
        sys.stderr.write("tar: %s\n" % exc)
        raise SystemExit(1)
    links = []
    with tf:
        for member in tf:
            name = clean(member.name)
            if not name:
                continue
            kind, image, rel = classify(name)
            if kind == "ext2" and member.islnk():
                links.append((name, image, rel, member))
                continue
            if kind == "ext2":
                ext2_member(image, rel, member, tf)
                if member.ischr() or member.isblk() or member.isfifo():
                    continue
                try:
                    host_member(name, member, tf)
                except OSError:
                    pass
            else:
                host_member(name, member, tf)
        for name, image, rel, member in links:
            ext2_member(image, rel, member, tf)
            try:
                host_member(name, member, tf)
            except OSError:
                pass
    for (image, path), count in links_count.items():
        cmds_for(image).append("set_inode_field %s links_count %d" % (q(path), count))
    for image, lines in ext2.items():
        apply_debugfs(image, lines)

try:
    extract()
finally:
    # The payload copies are large; never leave them behind on failure.
    shutil.rmtree(payloads, ignore_errors=True)
PY
    local rc=$?
    rm -f "${table:?}"
    return "$rc"
}

psbbn_vfat_export() {
    local image="$1" dest="$2" tool
    tool=$(psbbn_mcopy_bin) || return 1
    mkdir -p "$dest"
    COPYFILE_DISABLE=1 "$tool" -i "$image" -s -n ::/ "$dest"
}

psbbn_vfat_import() {
    local src="$1" image="$2" bytes sectors tool child base
    bytes=$(wc -c < "$image")
    sectors=$((bytes / 512))
    if (( sectors < 65536 )); then
        printf '%s\n' "vfat: $image is too small for FAT32" >&2
        return 1
    fi
    /sbin/newfs_msdos -F 32 -s "$sectors" "$image" >/dev/null || return 1
    tool=$(psbbn_mcopy_bin) || return 1
    for child in "$src"/* "$src"/.[!.]*; do
        [[ -e "$child" ]] || continue
        base=$(basename "$child")
        case "$base" in
            .DS_Store|._*) continue ;;
        esac
        COPYFILE_DISABLE=1 "$tool" -i "$image" -s -o "$child" ::/ || return 1
    done
}

# Run a pfsshell script. A real disk needs root. pfsshell exits 0 even when
# a command failed; its "(!) Exit code" lines are the error channel.
# psbbn_pfs_run DEVICE SCRIPT [tolerant]
psbbn_pfs_run() {
    local device="$1" script="$2" tolerant="${3:-}" bin out rc attempt
    bin=$(psbbn_pfsshell_bin) || return 1
    for attempt in 1 2 3 4 5 6; do
        rc=0
        if psbbn_is_real_disk "$device"; then
            # pfsshell takes the drive on stdin, so platform_elevate cannot
            # see it; release the drive's mounts here.
            out=$(printf '%s\n' "$script" | psbbn_with_disk_released "$device" platform_elevate "$bin" 2>&1) || rc=$?
        else
            out=$(printf '%s\n' "$script" | "$bin" 2>&1) || rc=$?
        fi
        psbbn_pfs_open_busy "$device" "$out" || break
        sleep "${PSBBN_DA_SETTLE:-1}"
    done
    if [[ "$rc" -ne 0 ]] || printf '%s\n' "$out" | grep -q -e 'unknown command' -e 'Unable to parse' -F -e "$device: "; then
        printf '%s\n' "$out" >&2
        return 1
    fi
    if [[ -z "$tolerant" ]] && printf '%s\n' "$out" | grep -q '(!) Exit code'; then
        printf '%s\n' "$out" | grep -B1 '(!) Exit code' >&2
        return 1
    fi
    printf '%s\n' "$out"
}

# Copy a PFS partition into the staged directory with pfsshell get.
# Only pfsshell runs as root; the files it fetched are handed back to the
# user so the installer can edit and replace them without sudo.
psbbn_pfs_export() {
    local device="$1" partition="$2" dest="$3" elevate=""
    mkdir -p "$dest"
    if psbbn_is_real_disk "$device"; then
        platform_elevate /usr/bin/true || return $?
        elevate="${PSBBN_SUDO:-/usr/bin/sudo}"
    fi
    psbbn_with_disk_released "$device" env PSBBN_PFS_ELEVATE="$elevate" PSBBN_DARWIN_LIB="$_psbbn_darwin_dir/lib.sh" PSBBN_BASH="$BASH" \
        "$(psbbn_python)" - "$device" "$partition" "$dest" "$(psbbn_pfsshell_bin)" << 'PY'
import os, re, subprocess, sys, time
device, partition, dest, pfsshell = sys.argv[1:5]
prefix = []
if os.environ.get("PSBBN_PFS_ELEVATE"):
    prefix = [os.environ["PSBBN_PFS_ELEVATE"], "-n"]
open_failed = re.compile(r"^>?\s*" + re.escape(device) + r": (.*)$", re.M)

def evict():
    subprocess.run([os.environ.get("PSBBN_BASH", "/bin/bash"), "-c",
                    '. "$1"; psbbn_evict_automounts "$2"', "_",
                    os.environ["PSBBN_DARWIN_LIB"], device], check=False)
row = re.compile(r"^[d-][rwxsStT-]{9}\s+\d+\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+(.*\S)\s*$")

def arg(text):
    if any(ch in text for ch in "\"'\r\n"):
        sys.stderr.write("pfs: unsupported name %r\n" % text)
        raise SystemExit(1)
    if any(ch.isspace() for ch in text):
        return '"' + text + '"'
    return text

def run(lines):
    for attempt in range(6):
        proc = subprocess.run(prefix + [pfsshell], input="\n".join(lines) + "\n",
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        failed = open_failed.search(proc.stdout)
        if failed and failed.group(1).strip() == "Resource busy":
            evict()
            time.sleep(float(os.environ.get("PSBBN_DA_SETTLE", "1")))
            continue
        break
    if proc.returncode != 0 or failed or "(!) Exit code" in proc.stdout or "unknown command" in proc.stdout or "Unable to parse" in proc.stdout:
        sys.stderr.write(proc.stdout)
        raise SystemExit(1)
    return proc.stdout

def entries(parts):
    cmds = ["device " + device, "mount " + partition]
    for part in parts:
        cmds.append("cd " + arg(part))
    cmds.extend(["ls -l", "umount", "exit"])
    found = []
    for line in run(cmds).splitlines():
        match = row.match(line.strip())
        if not match:
            continue
        name = match.group(1)
        if name in ("./", "../", ".", ".."):
            continue
        found.append((name.endswith("/"), name.rstrip("/")))
    return found

def walk(parts):
    local = dest if not parts else os.path.join(dest, *parts)
    os.makedirs(local, exist_ok=True)
    files = []
    dirs = []
    for isdir, name in entries(parts):
        if isdir:
            dirs.append(name)
        else:
            files.append(name)
    if files:
        cmds = ["device " + device, "mount " + partition]
        for part in parts:
            cmds.append("cd " + arg(part))
        cmds.append("lcd " + arg(local))
        for name in files:
            cmds.append("get " + arg(name))
        cmds.extend(["umount", "exit"])
        run(cmds)
    for name in dirs:
        walk(parts + [name])

walk([])
PY
    local rc=$?
    if [[ "$rc" -eq 0 && -n "$elevate" ]]; then
        platform_elevate /usr/sbin/chown -R "$(id -u):$(id -g)" "$dest" || rc=$?
    fi
    return "$rc"
}

# Write the staged directory back into the PFS partition.
# pfsshell put overwrites, mkdir on an existing directory fails, so the
# manifest decides which directories are new. Files the installer removed
# are deleted; directories it removed are dropped when empty.
# psbbn_pfs_import DIR DEVICE PARTITION [MANIFEST]
psbbn_pfs_import() {
    local src="$1" device="$2" partition="$3" manifest="${4:-}" script rmscript
    script=$(mktemp)
    rmscript=$(mktemp)
    "$(psbbn_python)" - "$src" "$device" "$partition" "$script" "$rmscript" "$manifest" "$_psbbn_darwin_dir" << 'PY'
import os, sys
src, device, partition, path, rmpath, manifest_path, libdir = sys.argv[1:8]
sys.dont_write_bytecode = True
sys.path.insert(0, libdir)
import manifest as mf

old = mf.load(manifest_path)

def arg(text):
    if any(ch in text for ch in "\"'\r\n"):
        sys.stderr.write("pfs: unsupported name %r\n" % text)
        raise SystemExit(1)
    if any(ch.isspace() for ch in text):
        return '"' + text + '"'
    return text

cmds = ["device " + arg(device), "mount " + arg(partition), "lcd " + arg(src)]
seen = set()

def walk(local, rel):
    names = sorted(n for n in os.listdir(local) if not mf.skip(n))
    for name in names:
        full = os.path.join(local, name)
        dest = (rel + "/" + name) if rel else name
        seen.add(dest)
        if os.path.islink(full):
            sys.stderr.write("pfs: symlink is not supported: %s\n" % full)
            raise SystemExit(1)
        if os.path.isdir(full):
            if dest not in old:
                cmds.append("mkdir " + arg(name))
            cmds.append("cd " + arg(name))
            cmds.append("lcd " + arg(full))
            walk(full, dest)
            cmds.append("cd ..")
            cmds.append("lcd " + arg(local))
        elif os.path.isfile(full):
            if old.get(dest) != mf.entry(full):
                cmds.append("put " + arg(name))
        else:
            sys.stderr.write("pfs: unsupported file %s\n" % full)
            raise SystemExit(1)

walk(src, "")

def descend(parts):
    return ["cd " + arg(part) for part in parts]

gone_files = {}
gone_dirs = []
for rel, ent in old.items():
    if rel in seen:
        continue
    parts = rel.split("/")
    if ent[0] == "f":
        gone_files.setdefault(tuple(parts[:-1]), []).append(parts[-1])
    elif ent[0] == "d":
        gone_dirs.append(parts)
for parent, names in gone_files.items():
    cmds.extend(descend(parent))
    for name in names:
        cmds.append("rm " + arg(name))
    cmds.extend(["cd .."] * len(parent))
cmds.extend(["umount", "exit"])
with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(cmds) + "\n")

rm = []
if gone_dirs:
    rm = ["device " + arg(device), "mount " + arg(partition)]
    for parts in sorted(gone_dirs, key=len, reverse=True):
        rm.extend(descend(parts[:-1]))
        rm.append("rmdir " + arg(parts[-1]))
        rm.extend(["cd .."] * (len(parts) - 1))
    rm.extend(["umount", "exit"])
with open(rmpath, "w", encoding="utf-8") as fh:
    fh.write("\n".join(rm) + ("\n" if rm else ""))
PY
    local rc=$?
    if [[ "$rc" -eq 0 ]]; then
        psbbn_pfs_run "$device" "$(cat "$script")" >/dev/null || rc=$?
    fi
    if [[ "$rc" -eq 0 && -s "$rmscript" ]]; then
        psbbn_pfs_run "$device" "$(cat "$rmscript")" tolerant >/dev/null || rc=$?
    fi
    rm -f "${script:?}" "${rmscript:?}"
    return "$rc"
}

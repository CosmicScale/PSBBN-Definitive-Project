#!/opt/homebrew/bin/bash
# The Linux side of the macOS port, in Docker: what the project's Linux
# helpers write, and how a Linux kernel and PS2 Linux's own /bin/mkhome see
# what the macOS side writes. Needs Docker and PS2Linux.tar.gz (the archive
# Extras downloads for PS2 Linux).
#
#   tests/e2e-docker.sh PS2Linux.tar.gz
#
# On a drive the size of the one in the report on the pull request
# (PSBBN_DRIVE_SECTORS) with old bytes where the partitions go, for each
# home partition size (PSBBN_HOME_SIZES, MB; empty for none):
#   linux   the project's Linux PFS Shell.elf makes __linux.3 and __linux.10
#   mac     the macOS PFS Shell.elf makes them, as Extras does; the drive
#           must be the linux one byte for byte, apart from the times
#   before  the macOS side at git revision PSBBN_BEFORE, if set; shown, not
#           counted
# The container maps __linux.10 the way the PS2 kernel does
# (fs/partitions/ps2.c), runs e2fsck on it, runs /bin/mkhome, copies files
# in and reads the kernel log.
# Then PS2 Linux's root partition, installed the way Extras does on each
# system: tar zxpf into __linux.3 as root on Linux, the same command through
# the shims on macOS. Every path must match: mode (setuid bits included),
# owner, links, contents and time. PSBBN_DOCKER_KEEP=DIR keeps the
# listings.
# It also builds genvmc the way Game-Installer does on Linux and compares
# its cards with the macOS genvmc's.
# Not in the container: the PS2's own 2.4 kernel, and macOS itself (the
# other e2e tests run the macOS side natively).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
repo=$(cd "$root/../../.." && pwd)
tarball="${1:?PS2Linux.tar.gz}"
tarball=$(cd "$(dirname "$tarball")" && pwd)/$(basename "$tarball")
sectors="${PSBBN_DRIVE_SECTORS:-$((0x1bf244b0))}"
sizes="${PSBBN_HOME_SIZES-1024 2048 5120}"
image=psbbn-linux-check
fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
stamp() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

docker info > /dev/null 2>&1 || { echo "Docker is not running." >&2; exit 2; }
stamp "docker build $image"
docker build -q --platform linux/amd64 -t "$image" "$root/tests/docker" > /dev/null || exit 1

# Docker Desktop shares /private; /tmp is a link to it.
work=$(cd "$(mktemp -d /tmp/psbbn-docker.XXXXXX)" && pwd -P)
before=""
if [[ -n "${PSBBN_BEFORE:-}" ]]; then
    before="$work/before-tree"
    git -C "$repo" worktree add --detach "$before" "$PSBBN_BEFORE" > /dev/null 2>&1 \
        || { echo "git worktree $PSBBN_BEFORE failed" >&2; exit 1; }
fi
cleanup() {
    [[ -n "$before" ]] && git -C "$repo" worktree remove --force "$before" > /dev/null 2>&1
    # PSBBN_DOCKER_KEEP=DIR keeps the listings of the root partitions there.
    [[ -n "${PSBBN_DOCKER_KEEP:-}" ]] && mkdir -p "$PSBBN_DOCKER_KEEP" && cp "$work"/*-root.txt "$PSBBN_DOCKER_KEEP"/ 2> /dev/null
    rm -rf "${work:?}"
}
trap cleanup EXIT

run() {
    local stdin=()
    [[ "$1" == format ]] && stdin=(-i)
    docker run --rm --privileged --platform linux/amd64 "${stdin[@]}" \
        -v "$work:/work" -v "$repo/scripts/helper:/helper:ro" -v "$tarball:/ps2linux.tar.gz:ro" \
        "$image" "$@"
}

# A sparse drive with old bytes from 2 GiB, past the partitions initialize
# makes, to 1 GiB past the largest home partition. It is written once; each
# drive is an APFS clone of it, so every drive starts with the same bytes.
# (dd reading from a pipe counts each short read as a block on macOS and
# wrote a few MiB of them.)
old_drive() {
    local largest=0 size
    for size in $sizes; do
        (( size > largest )) && largest=$size
    done
    python3 -I - "$work/old-drive.img" "$sectors" "$((2048 + largest + 1024))" << 'PY'
import os, sys
path, sectors, mib = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o644)
os.ftruncate(fd, sectors * 512)
os.lseek(fd, 2048 << 20, os.SEEK_SET)
chunk = b"\xa5" * (16 << 20)
for _ in range(mib // 16):
    os.write(fd, chunk)
os.close(fd)
PY
}

new_drive() {
    rm -f "$work/drive.img"
    cp -c "$work/old-drive.img" "$work/drive.img"
}

# PS2 Linux's partitions, the way Extras makes them on a HOSDMenu drive.
commands() {
    printf 'device %s\ninitialize yes\nmkpart __linux.3 2048M EXT2\nmkpart __linux.10 %sM EXT2\nexit\n' "$1" "$2"
}

mac_format() {
    local tree="$1" size="$2"
    (
        export PATH="$tree/scripts/platform/darwin/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export PSBBN_MOUNT_STATE="$work/state" PSBBN_MAPPER_DIR="$work/maps" PSBBN_DM_STATE="$work/dm" COPYFILE_DISABLE=1
        commands "$work/drive.img" "$size" | "$tree/scripts/helper/darwin-arm64/PFS Shell.elf"
    ) > "$work/format.out" 2>&1
}

# The key=value lines of one check, in KEY.
declare -A KEY
check() {
    local line
    run home /work/drive.img /ps2linux.tar.gz > "$work/home.out" 2>&1
    KEY=()
    # A check that stopped early leaves keys out; set -u would stop here.
    for line in pieces blocks sectors fsck_new root mkhome_rc home_ps2 fstab_entry kernel_errors kernel_first fsck_used error; do
        KEY[$line]=""
    done
    while IFS= read -r line; do
        [[ "$line" =~ ^([a-z0-9_]+)=(.*)$ ]] && KEY[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    done < "$work/home.out"
}

summary() {
    printf '    %s pieces=%s blocks=%s e2fsck=%s root=[%s] /home/ps2=%s kernel ext2 errors=%s e2fsck after copy=%s%s\n' \
        "$1" "${KEY[pieces]}" "${KEY[blocks]}" "${KEY[fsck_new]}" "${KEY[root]% }" "${KEY[home_ps2]}" "${KEY[kernel_errors]}" "${KEY[fsck_used]}" \
        "${KEY[kernel_first]:+ first: ${KEY[kernel_first]}}${KEY[error]:+ error: ${KEY[error]}}"
}

# format_diff MAC LINUX: the sectors of the __linux.N partitions that differ
# on the two drives, APA headers included, apart from the times each run
# writes: the creation time in each APA header (and its checksum), the
# write time in each ext2 superblock and the times of the root folder's
# inode. The PFS partitions initialize makes keep times of their own.
format_diff() {
    python3 -I - "$1" "$2" "$("$repo/scripts/helper/darwin-arm64/hdl_dump" toc "$2" --dm 2>/dev/null)" << 'PY'
import struct, sys
mac, linux, dm = sys.argv[1:4]
# toc --dm maps a main partition from 4 MiB in and a sub-partition from
# 1 MiB in; the APA header is at the start of each.
ranges = []
for line in dm.split(";"):
    if "-__linux." not in line.split(",")[0]:
        continue
    for n, piece in enumerate(line.split(",")[4:]):
        bits = piece.split()
        if len(bits) == 5:
            start, count = int(bits[4]), int(bits[1])
            ranges.append((start - (2048 if n else 8192), start + count))
def allowed(x, y, at):
    if x[4:8] == b"APA\0" and y[4:8] == b"APA\0":
        return all(i < 4 or 80 <= i < 88 for i in at)
    if x[56:58] == b"\x53\xef" and y[56:58] == b"\x53\xef" and all(44 <= i < 52 for i in at):
        return True
    for slot in range(0, 512, 128):
        if all(slot + 8 <= i < slot + 20 for i in at) and struct.unpack_from("<H", x, slot)[0] & 0xF000 == 0x4000:
            return True
    return False
bad, chunk = [], 32768
with open(mac, "rb") as a, open(linux, "rb") as b:
    for lo, hi in ranges:
        for sector in range(lo, hi, chunk):
            n = min(chunk, hi - sector)
            a.seek(sector * 512)
            b.seek(sector * 512)
            x, y = a.read(n * 512), b.read(n * 512)
            if x == y:
                continue
            for i in range(0, len(x), 512):
                u, v = x[i:i + 512], y[i:i + 512]
                if u != v:
                    at = [j for j in range(512) if u[j] != v[j]]
                    if not allowed(u, v, at):
                        bad.append("sector %d bytes %d-%d" % (sector + i // 512, at[0], at[-1]))
print("%d %s" % (len(bad) if ranges else -1, "; ".join(bad[:3]) or ("%d ranges" % len(ranges))))
PY
}

stamp "old bytes on a ${sectors}-sector drive"
old_drive

for size in $sizes; do
    stamp "linux PFS Shell.elf: ${size} MB home"
    new_drive
    commands /work/drive.img "$size" | run format > "$work/format.out" 2>&1
    rm -f "$work/linux-format.img"
    cp -c "$work/drive.img" "$work/linux-format.img"
    if grep -q '^format_rc=0$' "$work/format.out"; then
        check
        summary linux
        linux_blocks=${KEY[blocks]:-}
        [[ "${KEY[fsck_new]}" == 0 && "${KEY[home_ps2]}" == yes && "${KEY[kernel_errors]}" == 0 && "${KEY[fsck_used]}" == 0 ]] \
            && ok "linux-reference-home ($size MB)" || bad "linux-reference-home ($size MB) $(tail -n 3 "$work/home.out")"
    else
        linux_blocks=""
        bad "linux-reference-home ($size MB) PFS Shell.elf: $(tail -n 3 "$work/format.out")"
    fi

    if [[ -n "$before" ]]; then
        stamp "before ($PSBBN_BEFORE): ${size} MB home"
        new_drive
        if mac_format "$before" "$size"; then
            read -r differ first <<< "$(format_diff "$work/drive.img" "$work/linux-format.img")"
            echo "    before: $differ sectors differ from linux${first:+, first: $first}"
            check
            summary before
        else
            echo "    before: PFS Shell failed $(tail -n 2 "$work/format.out")"
        fi
    fi

    stamp "mac PFS Shell: ${size} MB home"
    new_drive
    if mac_format "$repo" "$size"; then
        read -r differ first <<< "$(format_diff "$work/drive.img" "$work/linux-format.img")"
        [[ "$differ" == 0 ]] && ok "mac-format-matches-linux ($size MB)" || bad "mac-format-matches-linux ($size MB) $differ sectors differ, first: $first"
        check
        summary mac
        [[ "${KEY[fsck_new]}" == 0 && "${KEY[root]}" == ". .. " ]] \
            && ok "mac-home-as-the-ps2-maps-it ($size MB)" || bad "mac-home-as-the-ps2-maps-it ($size MB) $(tail -n 3 "$work/home.out")"
        [[ "${KEY[home_ps2]}" == yes && "${KEY[fstab_entry]}" == yes ]] \
            && ok "mac-home-mkhome-fills-it ($size MB)" || bad "mac-home-mkhome-fills-it ($size MB) $(tail -n 3 "$work/home.out")"
        [[ "${KEY[kernel_errors]}" == 0 && "${KEY[fsck_used]}" == 0 ]] \
            && ok "mac-home-takes-files ($size MB)" || bad "mac-home-takes-files ($size MB) ${KEY[kernel_first]}"
        [[ -n "$linux_blocks" && "${KEY[blocks]}" == "$linux_blocks" ]] \
            && ok "mac-home-size-matches-linux ($size MB, ${KEY[blocks]} blocks)" || bad "mac-home-size-matches-linux mac=${KEY[blocks]} linux=$linux_blocks"
    else
        bad "mac-home ($size MB) PFS Shell: $(tail -n 3 "$work/format.out")"
    fi
done
rm -f "$work/drive.img" "$work/linux-format.img"

# PS2 Linux's root partition, as Extras installs it: __linux.3 made, mapped
# and mounted, then sudo tar zxpf of the archive into it. On macOS the same
# commands go through the shims of TREE.
mac_root() {
    local tree="$1" shims="$1/scripts/platform/darwin/bin" mnt="$work/storage/__linux.3" map=drive.img-__linux.3
    (
        # Each step is checked: set -e does nothing in a function called
        # from an if.
        export PATH="$shims:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export PSBBN_MOUNT_STATE="$work/state" PSBBN_MAPPER_DIR="$work/maps" PSBBN_DM_STATE="$work/dm" COPYFILE_DISABLE=1
        printf 'device %s\ninitialize yes\nmkpart __linux.3 2048M EXT2\nexit\n' "$work/drive.img" \
            | "$tree/scripts/helper/darwin-arm64/PFS Shell.elf" || exit
        "$tree/scripts/helper/darwin-arm64/hdl_dump" toc "$work/drive.img" --dm | tr ';' '\n' | grep -- "^$map," \
            | "$shims/dmsetup" create --concise || exit
        mkdir -p "$mnt" || exit
        "$shims/mount" "$PSBBN_MAPPER_DIR/$map" "$mnt" || exit
        "$shims/sudo" tar zxpf "$tarball" -C "$mnt" || exit
        "$shims/umount" "$mnt" || exit
        "$shims/dmsetup" remove "$map"
    ) > "$work/root.out" 2>&1
}

# root_diff A B [ARCHIVE]: how many paths differ, and in what, with a few
# of each. With ARCHIVE, a mode or time that differs from B's but is the
# archive's own is listed as "mode_b_only" or "time_b_only", not counted.
# The Linux PFS Shell.elf makes the root folder setgid (2744), and the
# folders tar makes 0700 under it keep the bit the kernel gave them; GNU
# tar leaves var/run with the time of the extract.
root_diff() {
    python3 -I - "$1" "$2" "${3:-}" << 'PY'
import sys, tarfile
def load(path):
    rows = {}
    with open(path, "rb") as fh:
        for line in fh:
            name, meta, what, mtime = line.rstrip(b"\n").split(b"\t")
            mode, owner, links = meta.split(b" ")
            rows[name] = {"mode": mode, "owner": owner, "links": links, "contents": what, "time": mtime}
    return rows
a, b = load(sys.argv[1]), load(sys.argv[2])
archive = {}
if sys.argv[3]:
    with tarfile.open(sys.argv[3], "r|*") as tf:
        for member in tf:
            if not member.issym() and not member.islnk():
                name = member.name
                while name.startswith("./"):
                    name = name[2:]
                archive[name.strip("/").encode("utf-8", "surrogateescape") or b"."] = {
                    "mode": b"%04o" % (member.mode & 0o7777), "time": b"%d" % int(member.mtime)}
kinds = {}
for name in sorted(set(a) | set(b)):
    if name not in a or name not in b:
        kinds.setdefault("missing", []).append((name, b"only in " + (b"A" if name in a else b"B")))
        continue
    for field in ("mode", "owner", "links", "contents", "time"):
        if a[name][field] != b[name][field]:
            kind = field
            if field in ("mode", "time") and archive.get(name, {}).get(field) == a[name][field]:
                kind = field + "_b_only"
            kinds.setdefault(kind, []).append((name, a[name][field] + b" vs " + b[name][field]))
names = set()
for field, rows in kinds.items():
    if not field.endswith("_b_only"):
        names.update(n for n, _ in rows)
print("differ=%d" % len(names))
print("kinds=%s" % ", ".join("%s %d" % (k, len(v)) for k, v in sorted(kinds.items())))
for field, rows in sorted(kinds.items()):
    print("example_%s=%s" % (field, "; ".join("%s %s" % (n.decode("latin-1"), d.decode("latin-1")) for n, d in rows[:3])))
PY
}

declare -A ROOT
root_check() {
    local line out="$1"
    shift
    run root /work/drive.img "/work/$out" "$@" > "$work/root-check.out" 2>&1
    ROOT=([tar_rc]="" [fsck_root]="" [root_paths]="" [root_special]="" [error]="")
    while IFS= read -r line; do
        [[ "$line" =~ ^([a-z_]+)=(.*)$ ]] && ROOT[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    done < "$work/root-check.out"
}

root_summary() {
    printf '    %s paths=%s setuid/setgid/sticky=%s e2fsck=%s%s%s\n' "$1" "${ROOT[root_paths]}" "${ROOT[root_special]}" "${ROOT[fsck_root]}" \
        "${ROOT[tar_rc]:+ tar=${ROOT[tar_rc]}}" "${ROOT[error]:+ error: ${ROOT[error]}}"
}

# root_compare A B LABEL [ARCHIVE]: prints the differences; fails when a
# path differs.
root_compare() {
    local out
    out=$(root_diff "$work/$1" "$work/$2" "${4:-}")
    printf '      vs %s: %s paths differ (%s)\n' "$3" "$(sed -n 's/^differ=//p' <<< "$out")" "$(sed -n 's/^kinds=//p' <<< "$out")"
    sed -n 's/^example_\([a-z_]*\)=\(.*\)/        \1: \2/p' <<< "$out"
    return "$(sed -n 's/^differ=//p' <<< "$out" | awk '{ print ($1 > 0) }')"
}

# The archive's own owner numbers are the ones PS2 Linux's /etc/passwd and
# /etc/group give names to. tar as root, the way Extras runs it on Linux,
# goes by the names in the archive and takes the numbers this Linux gives
# them, so that run is shown, not counted.
stamp "linux PFS Shell.elf + tar zxpf --numeric-owner as root: PS2 Linux's root partition"
new_drive
printf 'device /work/drive.img\ninitialize yes\nmkpart __linux.3 2048M EXT2\nexit\n' | run format > "$work/format.out" 2>&1
root_check archive-root.txt /ps2linux.tar.gz --numeric-owner
root_summary "linux --numeric-owner"
[[ "${ROOT[tar_rc]}" == 0 && "${ROOT[fsck_root]}" == 0 && "${ROOT[root_special]:-0}" -gt 0 ]] \
    && ok "linux-reference-root (${ROOT[root_paths]} paths)" || bad "linux-reference-root $(tail -n 3 "$work/root-check.out")"

stamp "linux PFS Shell.elf + tar zxpf as root, as Extras runs it on Linux"
new_drive
printf 'device /work/drive.img\ninitialize yes\nmkpart __linux.3 2048M EXT2\nexit\n' | run format > "$work/format.out" 2>&1
root_check linux-root.txt /ps2linux.tar.gz
root_summary "linux"
root_compare linux-root.txt archive-root.txt "the archive's numbers"

for tree in ${before:+before} mac; do
    if [[ "$tree" == before ]]; then
        stamp "before ($PSBBN_BEFORE): PS2 Linux's root partition through the shims"
        dir="$before"
    else
        stamp "mac shims: PS2 Linux's root partition"
        dir="$repo"
    fi
    new_drive
    t0=$(date +%s)
    if ! mac_root "$dir"; then
        if [[ "$tree" == before ]]; then
            echo "    before: the extract failed: $(tail -n 3 "$work/root.out")"
        else
            bad "$tree-root extract: $(tail -n 3 "$work/root.out")"
        fi
        continue
    fi
    root_check "$tree-root.txt"
    root_summary "$tree ($(( $(date +%s) - t0 ))s)"
    differ=0
    root_compare "$tree-root.txt" archive-root.txt "linux --numeric-owner" "$tarball" || differ=1
    [[ "$tree" == before ]] && continue
    [[ "${ROOT[fsck_root]}" == 0 ]] && ok mac-root-as-the-ps2-maps-it || bad "mac-root-as-the-ps2-maps-it $(tail -n 3 "$work/root-check.out")"
    [[ "$differ" == 0 && -n "${ROOT[root_paths]}" ]] \
        && ok "mac-root-matches-linux (${ROOT[root_paths]} paths, ${ROOT[root_special]} setuid/setgid/sticky)" || bad mac-root-matches-linux
done
rm -f "$work/drive.img"

stamp "genvmc: the macOS build against Game-Installer's Linux build"
mkdir -p "$work/vmc"
"$repo/scripts/helper/darwin-arm64/genvmc" 8 "$work/vmc/mac-8.bin" > /dev/null
"$repo/scripts/helper/darwin-arm64/genvmc" 32 "$work/vmc/mac-32.bin" > /dev/null
run vmc /work/vmc > "$work/vmc.out" 2>&1
grep -q '^vmc_8=same$' "$work/vmc.out" && grep -q '^vmc_32=same$' "$work/vmc.out" \
    && ok "vmc-cards-match-linux-build (8 and 32 MB)" || bad "vmc-cards-match-linux-build $(tr '\n' ' ' < "$work/vmc.out")"
printf '    the Linux build with glibc fortify (-O2 -D_FORTIFY_SOURCE=2): rc=%s %s\n' \
    "$(sed -n 's/^linux_fortify_rc=//p' "$work/vmc.out")" "$(sed -n 's/^linux_fortify_says=//p' "$work/vmc.out")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

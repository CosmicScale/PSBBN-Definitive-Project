#!/opt/homebrew/bin/bash
# Rehearsal of partitions above the APA size cap against a file image.
# No real disk and no sudo. APA splits such a partition into a main
# partition and sub-partitions, and hdl_dump toc --dm maps it as several
# linear extents with the sub-partition headers in the gaps between them.
# On an 8 GiB image a 1536 MiB partition is a 1 GiB main plus one 512 MiB
# sub-partition: the same layout as a large music partition on a real
# drive, where the pieces are 2 GiB.
#
# Runs the real PFS Shell wrapper (mkpart formats ext2 across every extent),
# the whole toc --dm line through the dmsetup shim the way Media-Installer
# pipes it, mkfs.vfat on the music slice, mount, write, unmount, and a fresh
# map that reads everything back.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
bin="$root/bin"
repo=$(cd "$root/../../.." && pwd)
helper="$repo/scripts/helper/darwin-arm64"
fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
stamp() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

export PATH="$bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
work=$(mktemp -d /tmp/psbbn-extents.XXXXXX)
export PSBBN_MOUNT_STATE="$work/state"
export PSBBN_MAPPER_DIR="$work/maps"
export PSBBN_DM_STATE="$work/dm"
export COPYFILE_DISABLE=1
img="$work/disk.img"
hdl="$helper/hdl_dump"
fsck=/opt/homebrew/opt/e2fsprogs/sbin/e2fsck
dumpe2fs=/opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs
cut=$(basename "$img")
mapper="$PSBBN_MAPPER_DIR/$cut-"

# Extents of a partition from toc --dm, "start:count ...".
extents_of() {
    "$hdl" toc "$img" --dm | tr ';' '\n' | grep "^$cut-$1," | tr ',' '\n' | tail -n +5 \
        | awk 'NF == 5 { printf "%s%s:%s", sep, $5, $2; sep = " " }'
}
# The partition as the filesystem sees it: its extents back to back.
assemble() {
    local extent
    for extent in $1; do
        dd if="$img" bs=512 skip="${extent%%:*}" count="${extent#*:}" 2>/dev/null
    done
}
# Every region the slice holds data for is on the drive at its extent. The
# slice's holes are never written, so the drive keeps its old bytes there.
data_matches() {
    python3 - "$img" "$1" "$2" << 'PY'
import errno, os, sys
img, extents, path = sys.argv[1], sys.argv[2].split(), sys.argv[3]
fd = os.open(path, os.O_RDONLY)
end = os.fstat(fd).st_size
regions, off = [], 0
while off < end:
    try:
        a = os.lseek(fd, off, os.SEEK_DATA)
    except OSError as exc:
        if exc.errno == errno.ENXIO:
            break
        raise
    b = os.lseek(fd, a, os.SEEK_HOLE)
    regions.append((a, b))
    off = b
os.close(fd)
spans, pos = [], 0
for ext in extents:
    start, count = (int(x) * 512 for x in ext.split(":"))
    spans.append((pos, pos + count, start))
    pos += count
with open(path, "rb") as sl, open(img, "rb") as dr:
    for a, b in regions:
        for lo, hi, dev in spans:
            x, y = max(a, lo), min(b, hi)
            while x < y:
                n = min(y - x, 8 << 20)
                sl.seek(x)
                dr.seek(dev + x - lo)
                if sl.read(n) != dr.read(n):
                    sys.exit(1)
                x += n
print(sum(b - a for a, b in regions) // 1048576)
PY
}
# The 4 MiB in front of every extent: the APA header and reserved area of
# the main partition, the header of each sub-partition.
headers_sum() {
    local extent
    for extent in $1; do
        dd if="$img" bs=512 skip=$((${extent%%:*} - 8192)) count=8192 2>/dev/null
    done | md5 -q
}

stamp "image at $img"
/usr/sbin/mkfile -n 8g "$img"
# A used drive: random bytes where the partitions will go. Nothing that
# skips a slice's holes may rely on that space reading as zero.
dd if=/dev/urandom of="$img" bs=1048576 seek=2048 count=4096 conv=notrunc status=none 2>/dev/null

stamp "PFS Shell: initialize + mkpart above the cap (ext2 formatted by the wrapper)"
printf 'device %s\ninitialize yes\nmkpart __linux.5 1536M EXT2\nmkpart __linux.8 1536M EXT2\nmkpart __contents 128M PFS\nexit\n' "$img" \
    | "$helper/PFS Shell.elf" > "$work/pfsshell.out" 2>&1 || { bad "pfsshell $(tail -5 "$work/pfsshell.out")"; exit 1; }
ext5=$(extents_of __linux.5)
ext8=$(extents_of __linux.8)
n5=$(wc -w <<<"$ext5" | tr -d ' ')
n8=$(wc -w <<<"$ext8" | tr -d ' ')
[[ "$n5" -ge 2 && "$n8" -ge 2 ]] && ok "partitions-span-extents ($n5 and $n8)" || { bad "partitions-span-extents $ext5 / $ext8"; exit 1; }
headers5=$(headers_sum "$ext5")
headers8=$(headers_sum "$ext8")

# mkpart formats the whole partition, not just the main piece.
assemble "$ext5" > "$work/l5.img"
blocks=$("$dumpe2fs" -h "$work/l5.img" 2>/dev/null | awk -F: '/^Block count/ { gsub(/ /, "", $2); print $2 }')
total=0
for extent in $ext5; do total=$((total + ${extent#*:})); done
if [[ "$((blocks * 4096))" -eq "$((total * 512))" ]] && "$fsck" -fn "$work/l5.img" >/dev/null 2>&1; then
    ok mkpart-ext2-spans-extents
else
    bad "mkpart-ext2-spans-extents blocks=$blocks sectors=$total"
fi
rm -f "$work/l5.img"

stamp "dmsetup: the whole toc --dm line in one call, like Media-Installer"
"$hdl" toc "$img" --dm | "$bin/dmsetup" create --concise 2>"$work/dm.err" || bad "dmsetup create $(cat "$work/dm.err")"
[[ -f "${mapper}__linux.5" && -f "${mapper}__linux.8" && -f "${mapper}__contents" ]] && ok dmsetup-maps-all || bad "dmsetup-maps-all $(ls "$PSBBN_MAPPER_DIR")"

stamp "ext2: mount, write, unmount"
head -c 5000000 /dev/urandom > "$work/payload.bin"
mnt5="$work/storage/__linux.5"
mkdir -p "$mnt5"
if "$bin/mount" "${mapper}__linux.5" "$mnt5" 2>"$work/m5.err"; then
    mkdir -p "$mnt5/deep/dir"
    cp "$work/payload.bin" "$mnt5/deep/dir/payload.bin"
    "$bin/umount" "$mnt5" 2>"$work/u5.err" || bad "umount ext2 $(cat "$work/u5.err")"
else
    bad "mount ext2 $(cat "$work/m5.err")"
fi

stamp "FAT32 music partition: mkfs.vfat, mount, write, unmount"
"$bin/mkfs.vfat" -F 32 "${mapper}__linux.8" >/dev/null 2>"$work/vf.err" || bad "mkfs.vfat $(cat "$work/vf.err")"
mnt8="$work/storage/__linux.8"
mkdir -p "$mnt8"
if "$bin/mount" "${mapper}__linux.8" "$mnt8" 2>"$work/m8.err"; then
    mkdir -p "$mnt8/MusicCh/contents/album"
    cp "$work/payload.bin" "$mnt8/MusicCh/contents/album/track01.pcm"
    "$bin/umount" "$mnt8" 2>"$work/u8.err" || bad "umount vfat $(cat "$work/u8.err")"
else
    bad "mount vfat $(cat "$work/m8.err")"
fi

stamp "the drive after writeback"
if [[ "$(headers_sum "$ext5")" == "$headers5" && "$(headers_sum "$ext8")" == "$headers8" ]]; then
    ok sub-partition-headers-untouched
else
    bad sub-partition-headers-untouched
fi
"$hdl" toc "$img" > "$work/toc.txt" 2>&1 && grep -q '__linux.8' "$work/toc.txt" && ! grep -qi broken "$work/toc.txt" \
    && ok toc-still-clean || bad "toc-still-clean $(cat "$work/toc.txt")"
if mib=$(data_matches "$ext5" "${mapper}__linux.5"); then ok "ext2-data-on-drive ($mib MiB written)"; else bad ext2-data-on-drive; fi
if mib=$(data_matches "$ext8" "${mapper}__linux.8"); then ok "vfat-data-on-drive ($mib MiB written)"; else bad vfat-data-on-drive; fi
assemble "$ext5" > "$work/l5.img"
"$fsck" -fn "$work/l5.img" > "$work/fsck5.out" 2>&1 && ok ext2-fsck-on-drive || bad "ext2-fsck-on-drive $(tail -5 "$work/fsck5.out")"
rm -f "$work/l5.img"
assemble "$ext8" > "$work/l8.img"
/sbin/fsck_msdos -n "$work/l8.img" > "$work/fsck8.out" 2>&1 && ok vfat-fsck-on-drive || bad "vfat-fsck-on-drive $(tail -5 "$work/fsck8.out")"
rm -f "$work/l8.img"

stamp "fresh maps read every extent back"
for p in __linux.5 __linux.8 __contents; do
    "$bin/dmsetup" remove "$cut-$p" 2>/dev/null || true
done
"$hdl" toc "$img" --dm | "$bin/dmsetup" create --concise 2>"$work/dm.err" || bad "dmsetup re-create $(cat "$work/dm.err")"
rm -rf "$mnt5" "$mnt8"
mkdir -p "$mnt5" "$mnt8"
if "$bin/mount" "${mapper}__linux.5" "$mnt5" 2>"$work/m5.err" && cmp -s "$work/payload.bin" "$mnt5/deep/dir/payload.bin"; then
    ok ext2-reads-back
else
    bad "ext2-reads-back $(cat "$work/m5.err")"
fi
if "$bin/mount" "${mapper}__linux.8" "$mnt8" 2>"$work/m8.err" && cmp -s "$work/payload.bin" "$mnt8/MusicCh/contents/album/track01.pcm"; then
    ok vfat-reads-back
else
    bad "vfat-reads-back $(cat "$work/m8.err")"
fi
"$bin/umount" "$mnt5" >/dev/null 2>&1 || bad "umount ext2 after re-read"
"$bin/umount" "$mnt8" >/dev/null 2>&1 || bad "umount vfat after re-read"

printf '\n%d passed, %d failed  (work dir %s)\n' "$pass" "$fail" "$work"
if [[ "$fail" -eq 0 ]]; then
    rm -rf "$work"
    exit 0
fi
exit 1

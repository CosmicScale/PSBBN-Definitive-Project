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
# dd that adds up what reaches the drive image.
written="$work/written"
cat > "$work/dd" << EOF
#!/bin/bash
bs=0; count=0; of=""
for a in "\$@"; do
    case "\$a" in bs=*) bs=\${a#bs=} ;; count=*) count=\${a#count=} ;; of=*) of=\${a#of=} ;; esac
done
[[ "\$of" == "$img" ]] && echo \$((bs * count)) >> "$written"
exec /bin/dd "\$@"
EOF
chmod +x "$work/dd"
export PSBBN_DD="$work/dd"
mib_written() { awk '{ s += $1 } END { printf "%d", s / 1048576 }' "$written" 2>/dev/null; }

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
    : > "$written"
    "$bin/umount" "$mnt5" 2>"$work/u5.err" || bad "umount ext2 $(cat "$work/u5.err")"
    # The slice was read off the drive: only the changed chunks go back.
    (( $(mib_written) < 64 )) && ok "ext2-writes-changed-chunks ($(mib_written) MiB of 1536)" || bad "ext2-writes-changed-chunks $(mib_written) MiB"
else
    bad "mount ext2 $(cat "$work/m5.err")"
fi

stamp "FAT32 music partition: wipefs, mkfs.vfat, mount, write, unmount (Media-Installer's reset)"
"$bin/wipefs" -a "${mapper}__linux.8" 2>"$work/wf.err" || bad "wipefs $(cat "$work/wf.err")"
"$bin/mkfs.vfat" -F 32 "${mapper}__linux.8" >/dev/null 2>"$work/vf.err" || bad "mkfs.vfat $(cat "$work/vf.err")"
mnt8="$work/storage/__linux.8"
mkdir -p "$mnt8"
if "$bin/mount" "${mapper}__linux.8" "$mnt8" 2>"$work/m8.err"; then
    mkdir -p "$mnt8/MusicCh/contents/album"
    cp "$work/payload.bin" "$mnt8/MusicCh/contents/album/track01.pcm"
    : > "$written"
    "$bin/umount" "$mnt8" 2>"$work/u8.err" || bad "umount vfat $(cat "$work/u8.err")"
    # A fresh format: only what mkfs and the copy wrote goes to the drive.
    (( $(mib_written) < 64 )) && ok "vfat-fresh-writes-data-only ($(mib_written) MiB of 1536)" || bad "vfat-fresh-writes-data-only $(mib_written) MiB"
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
if mib=$(data_matches "$ext5" "${mapper}__linux.5"); then ok "ext2-data-on-drive ($mib MiB compared)"; else bad ext2-data-on-drive; fi
if mib=$(data_matches "$ext8" "${mapper}__linux.8"); then ok "vfat-data-on-drive ($mib MiB compared)"; else bad vfat-data-on-drive; fi
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
stamp "df on staged partitions answers for the partition, not the Mac"
avail_kb() { "$bin/df" --output=avail "$1" 2>"$work/df.err" | tail -n 1 | tr -d ' '; }
# Free space before and after 8 MB is staged: it must drop by about 8 MB.
df_drop_ok() {
    local before="$1" after="$2"
    [[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ ]] && (( before - after >= 7700 && before - after <= 8100 ))
}
e2_free=$("$dumpe2fs" -h "${mapper}__linux.5" 2>/dev/null | awk -F: '/^Free blocks/ { f = $2 } /^Reserved block count/ { r = $2 } END { print (f - r) * 4 }')
before=$(avail_kb "$mnt5")
head -c 8000000 /dev/urandom > "$mnt5/deep/more.bin"
after=$(avail_kb "$mnt5/deep")
[[ "$before" == "$e2_free" ]] && df_drop_ok "$before" "$after" && ok "df-ext2 ($before KiB, $after after 8 MB)" || bad "df-ext2 before=$before expected=$e2_free after=$after $(cat "$work/df.err")"
rm -f "$mnt5/deep/more.bin"
vf_free=$(mdir -i "${mapper}__linux.8" ::/ 2>/dev/null | awk '/bytes free/ { gsub(/[^0-9]/, ""); printf "%d", ($0 + 1023) / 1024 }')
before=$(avail_kb "$mnt8")
[[ "$before" == "$vf_free" ]] && ok "df-vfat ($before KiB)" || bad "df-vfat before=$before expected=$vf_free $(cat "$work/df.err")"
mntc="$work/storage/__contents"
mkdir -p "$mntc"
if "$bin/pfs-fuse" -o allow_other --partition=__contents "$img" "$mntc" 2>"$work/pfs.err"; then
    pfs_free=$(printf 'device %s\nmount __contents\ndf\numount\nexit\n' "$img" | "$helper/pfsshell" 2>/dev/null \
        | awk '$1 == "__contents" { v = $4; sub(/MiB$/, "", v); print v * 1024 }')
    before=$(avail_kb "$mntc")
    head -c 8000000 /dev/urandom > "$mntc/movie.pss"
    after=$(avail_kb "$mntc")
    [[ "$before" == "$pfs_free" ]] && df_drop_ok "$before" "$after" && ok "df-pfs ($before KiB, $after after 8 MB)" || bad "df-pfs before=$before expected=$pfs_free after=$after $(cat "$work/df.err")"
    rm -f "$mntc/movie.pss"
    "$bin/umount" "$mntc" 2>"$work/uc.err" || bad "umount pfs $(cat "$work/uc.err")"
else
    bad "pfs-fuse $(cat "$work/pfs.err")"
fi
# Anything else is the real df.
[[ "$("$bin/df" -k "$work" | awk '{ print $1, $NF }')" == "$(/bin/df -k "$work" | awk '{ print $1, $NF }')" ]] && ok df-passes-through || bad df-passes-through

"$bin/umount" "$mnt5" >/dev/null 2>&1 || bad "umount ext2 after re-read"

stamp "add one album to the music partition that was read back"
head -c 8000000 /dev/urandom > "$work/album2.bin"
mkdir -p "$mnt8/MusicCh/contents/album2"
cp "$work/album2.bin" "$mnt8/MusicCh/contents/album2/track01.pcm"
: > "$written"
"$bin/umount" "$mnt8" 2>"$work/u8.err" || bad "umount vfat after re-read $(cat "$work/u8.err")"
(( $(mib_written) < 64 )) && ok "vfat-add-album-writes-album ($(mib_written) MiB of 1536)" || bad "vfat-add-album-writes-album $(mib_written) MiB"
data_matches "$ext8" "${mapper}__linux.8" >/dev/null && ok vfat-add-album-on-drive || bad vfat-add-album-on-drive
assemble "$ext8" > "$work/l8.img"
/sbin/fsck_msdos -n "$work/l8.img" > "$work/fsck8.out" 2>&1 && ok vfat-add-album-fsck || bad "vfat-add-album-fsck $(tail -5 "$work/fsck8.out")"
mtype -i "$work/l8.img" ::/MusicCh/contents/album2/track01.pcm 2>/dev/null | cmp -s - "$work/album2.bin" \
    && mtype -i "$work/l8.img" ::/MusicCh/contents/album/track01.pcm 2>/dev/null | cmp -s - "$work/payload.bin" \
    && ok vfat-both-albums-on-drive || bad vfat-both-albums-on-drive
rm -f "$work/l8.img"

printf '\n%d passed, %d failed  (work dir %s)\n' "$pass" "$fail" "$work"
if [[ "$fail" -eq 0 ]]; then
    rm -rf "$work"
    exit 0
fi
exit 1

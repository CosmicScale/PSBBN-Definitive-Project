#!/opt/homebrew/bin/bash
# End-to-end rehearsal of the install path against a file image.
# No real disk and no sudo. Exercises the same shims the installer uses:
# PFS Shell (mkpart + ext2 format), dmsetup, mount, tar, pfs-fuse, umount.
#
#   tests/e2e-image.sh PATCH.tar.gz [LANGPACK.tar.gz]
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
bin="$root/bin"
repo=$(cd "$root/../../.." && pwd)
patch="${1:?patch tarball}"
lang="${2:-}"
fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
stamp() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

export PATH="$bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
work=$(mktemp -d /tmp/psbbn-e2e.XXXXXX)
export PSBBN_MOUNT_STATE="$work/state"
export PSBBN_MAPPER_DIR="$work/maps"
export PSBBN_DM_STATE="$work/dm"
export COPYFILE_DISABLE=1
storage="$work/storage"
img="$work/disk.img"
dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
fsck=/opt/homebrew/opt/e2fsprogs/sbin/e2fsck
pfsshell="$repo/scripts/helper/darwin-arm64/pfsshell"
pfs_shell_wrapper="$repo/scripts/helper/darwin-arm64/PFS Shell.elf"
hdl="$repo/scripts/helper/darwin-arm64/hdl_dump"
. "$root/../load.sh"

stamp "image at $img"
# Sparse. APA caps a partition at a fraction of the disk, so the image must
# be large enough for 512 MiB partitions; 40 GiB costs no real space.
/usr/sbin/mkfile -n 40g "$img"

stamp "PFS Shell: initialize + mkpart (ext2 formatted by the wrapper)"
printf 'device %s\ninitialize yes\nmkpart __linux.1 512M EXT2\nmkpart __linux.2 128M EXT2SWAP\nmkpart __linux.4 512M EXT2\nmkpart __linux.5 512M EXT2\nmkpart __linux.7 256M EXT2\nmkpart __linux.8 512M EXT2\nmkpart __contents 128M PFS\nexit\n' "$img" \
    | "$pfs_shell_wrapper" > "$work/pfsshell.out" 2>&1 || { bad "pfsshell init $(tail -5 "$work/pfsshell.out")"; exit 1; }
"$hdl" toc "$img" > "$work/toc.txt" 2>&1 || { bad "hdl_dump toc"; exit 1; }
grep -q '__linux.1' "$work/toc.txt" && ok toc-has-linux1 || bad toc-has-linux1

stamp "dmsetup: publish slices"
cut=$(basename "$img")
"$hdl" toc "$img" --dm | tr ';' '\n' | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
        "$cut-__mbr,"*|"$cut-__net,"*) continue ;;
    esac
    printf '%s\n' "$line" | "$bin/dmsetup" create --concise || exit 1
done || { bad dmsetup; exit 1; }
mapper="$PSBBN_MAPPER_DIR/$cut-"
for p in __linux.1 __linux.2 __linux.4 __linux.5 __linux.7 __linux.8; do
    [[ -f "${mapper}${p}" && -f "${mapper}${p}.meta" ]] || bad "slice-missing $p"
done
ok dmsetup-slices

stamp "mount ext2 slices"
mkdir -p "$storage"
for p in __linux.1 __linux.4 __linux.5 __linux.7; do
    mkdir -p "$storage/$p"
    "$bin/mount" "${mapper}${p}" "$storage/$p" > "$work/mount-$p.out" 2>&1 || bad "mount $p: $(cat "$work/mount-$p.out")"
done
ok mount-ext2
stamp "mkfs.vfat + mount __linux.8"
"$bin/mkfs.vfat" -F 32 "${mapper}__linux.8" >/dev/null 2>&1 || bad mkfs-vfat
mkdir -p "$storage/__linux.8"
"$bin/mount" "${mapper}__linux.8" "$storage/__linux.8" >/dev/null 2>&1 || bad mount-vfat
stamp "pfs-fuse: stage PFS partitions"
for p in __contents __system __sysconf __common; do
    mkdir -p "$storage/$p/"
    "$bin/pfs-fuse" -o allow_other --partition="$p" "$img" "$storage/$p/" > "$work/pfs-$p.out" 2>&1 || bad "pfs-fuse $p: $(cat "$work/pfs-$p.out")"
done
ok pfs-stage
mkdir -p "$storage/__linux.8/MusicCh/contents" "$storage/__common/Your Saves"

stamp "tar: extract the real patch (silent for a few minutes)"
t0=$(date +%s)
if "$bin/tar" zxpf "$patch" -C "$storage/" > "$work/tar.out" 2>&1; then
    ok "tar-patch ($(( $(date +%s) - t0 ))s)"
else
    bad "tar-patch: $(head -20 "$work/tar.out")"
fi
if [[ -n "$lang" ]]; then
    if "$bin/tar" zxpf "$lang" -C "$storage/" > "$work/tar-lang.out" 2>&1; then
        ok tar-lang
    else
        bad "tar-lang: $(head -20 "$work/tar-lang.out")"
    fi
fi

stamp "e2fsck right after the extract"
for p in __linux.1 __linux.4 __linux.5 __linux.7; do
    if "$fsck" -fn "${mapper}${p}" >/dev/null 2>&1; then ok "e2fsck-after-tar $p"; else bad "e2fsck-after-tar $p: $("$fsck" -fn "${mapper}${p}" 2>&1 | grep -v '^Pass' | head -5)"; fi
done

stamp "installer-style edits"
cp -f "$repo/scripts/assets/kernel/vmlinux" "$storage/__system/p2lboot/vmlinux" || bad cp-vmlinux
mkdir -p "$storage/__sysconf/osdmenu"
printf 'boot_auto = $PSBBN\nosd_language = eng\n' > "$storage/__sysconf/osdmenu/OSDMBR.CNF"
cp -f "$repo/scripts/assets/kernel/x.tm2" "$storage/__linux.4/bn/data/tex/btn_r.tm2" || bad cp-tm2
deleted="etc/issue"
[[ -f "$storage/__linux.1/$deleted" ]] || deleted=$(cd "$storage/__linux.1/etc" && ls | head -1 | sed 's|^|etc/|')
rm -f "$storage/__linux.1/$deleted"
printf 'added-on-mac\n' > "$storage/__linux.1/etc/psbbn-mac-test"
sysconf="$storage/__linux.4/bn/script/utility/sysconf.xml"
if [[ -f "$sysconf" ]]; then
    sed -i 's|<item value=|<item value=|' "$sysconf"
    printf '<!-- e2e -->\n' >> "$sysconf"
fi

stamp "umount everything (ext2 diff import, vfat rebuild, pfs put)"
t0=$(date +%s)
for p in __contents __system __sysconf __common __linux.8 __linux.7 __linux.5 __linux.4 __linux.1; do
    t1=$(date +%s)
    if "$bin/umount" "$storage/$p" > "$work/umount-$p.out" 2>&1; then
        ok "umount $p ($(( $(date +%s) - t1 ))s)"
    else
        bad "umount $p: $(head -20 "$work/umount-$p.out")"
    fi
done
stamp "umount total $(( $(date +%s) - t0 ))s"
[[ -z "$(ls -A "$PSBBN_MOUNT_STATE" 2>/dev/null)" ]] && ok state-clean || bad "state-clean $(ls "$PSBBN_MOUNT_STATE")"

stamp "verify ext2 images"
for p in __linux.1 __linux.4 __linux.5 __linux.7; do
    out=$("$fsck" -fn "${mapper}${p}" 2>&1)
    rc=$?
    if [[ "$rc" -eq 0 ]]; then ok "e2fsck $p: $(tail -1 <<<"$out")"; else bad "e2fsck $p rc=$rc: $(grep -v '^Pass' <<<"$out" | head -8)"; fi
done
l1="${mapper}__linux.1"
"$dbg" -R 'stat dev/null' "$l1" 2>/dev/null | grep -q 'character special' && ok dev-null-node || bad dev-null-node
"$dbg" -R 'stat dev/hda' "$l1" 2>/dev/null | grep -q 'block special' && ok dev-hda-node || bad dev-hda-node
upper=$("$dbg" -R 'ls -l usr/share/terminfo/P' "$l1" 2>/dev/null | wc -l)
lower=$("$dbg" -R 'ls -l usr/share/terminfo/p' "$l1" 2>/dev/null | wc -l)
(( upper > 2 && lower > 2 )) && ok "terminfo-both-casings (P=$upper p=$lower)" || bad "terminfo-both-casings P=$upper p=$lower"
"$dbg" -R 'stat usr/share/terminfo/x/xterm-r6' "$l1" 2>/dev/null | grep -q 'Inode:' && ok hardlink-xterm-r6 || bad hardlink-xterm-r6
links=$("$dbg" -R 'stat sbin/e2fsck' "$l1" 2>/dev/null | sed -n 's/.*Links: *\([0-9]*\).*/\1/p')
(( links >= 3 )) && ok "links-count-e2fsck=$links" || bad "links-count-e2fsck=$links"
"$dbg" -R "stat $deleted" "$l1" 2>&1 | grep -q 'File not found' && ok "deleted-propagated ($deleted)" || bad "deleted-propagated ($deleted)"
[[ "$("$dbg" -R 'cat etc/psbbn-mac-test' "$l1" 2>/dev/null)" == added-on-mac ]] && ok added-file || bad added-file
owner=$("$dbg" -R 'stat bin/sh' "$l1" 2>/dev/null | grep -o 'User: *[0-9]*' | tr -dc 0-9)
[[ "$owner" == 0 ]] && ok root-owned-bin-sh || bad "root-owned-bin-sh uid=$owner"
if [[ -f "$sysconf" ]]; then
    "$dbg" -R 'cat bn/script/utility/sysconf.xml' "${mapper}__linux.4" 2>/dev/null | grep -q 'e2e' && ok sysconf-updated || bad sysconf-updated
fi
tarcount=$(/opt/homebrew/bin/python3 -c 'import tarfile,sys; t=tarfile.open(sys.argv[1]); print(sum(1 for m in t if m.name.lstrip("./").startswith("__linux.1/") and (m.isreg() or m.isdir() or m.issym() or m.ischr() or m.isblk() or m.isfifo())))' "$patch")
used=$(/opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs -h "$l1" 2>/dev/null | awk -F: '/^Inode count/{ic=$2} /^Free inodes/{fi=$2} END{print ic-fi}')
printf 'inodes: tar members=%s image used=%s\n' "$tarcount" "$used"
(( used >= tarcount - 5 )) && ok inode-count-matches || bad "inode-count tar=$tarcount used=$used"

stamp "verify slices landed in the image"
device=""; start=""; sectors=""
. "${l1}.meta"
back="$work/back.bin"
dd if="$img" of="$back" bs=512 skip="$start" count="$sectors" status=none 2>/dev/null
cmp -s "$back" "$l1" && ok slice-written-back || bad slice-written-back
"$fsck" -fn "$back" >/dev/null 2>&1 && ok e2fsck-on-disk-window || bad e2fsck-on-disk-window

stamp "verify PFS"
pfsback="$work/pfsback"; mkdir -p "$pfsback"
printf 'device %s\nmount __system\ncd p2lboot\nlcd %s\nget vmlinux\numount\nexit\n' "$img" "$pfsback" | "$pfsshell" > "$work/pfsget.out" 2>&1
printf 'device %s\nmount __sysconf\ncd osdmenu\nlcd %s\nget OSDMBR.CNF\numount\nexit\n' "$img" "$pfsback" | "$pfsshell" >> "$work/pfsget.out" 2>&1
cmp -s "$pfsback/vmlinux" "$repo/scripts/assets/kernel/vmlinux" && ok pfs-vmlinux || bad "pfs-vmlinux $(tail -3 "$work/pfsget.out")"
grep -q 'osd_language = eng' "$pfsback/OSDMBR.CNF" 2>/dev/null && ok pfs-osdmbr || bad pfs-osdmbr
printf 'device %s\nmount __common\nls\numount\nexit\n' "$img" | "$pfsshell" 2>/dev/null | grep -q 'Your Saves' && ok pfs-your-saves || bad pfs-your-saves
sysfiles=$(printf 'device %s\nmount __system\nls -l\numount\nexit\n' "$img" | "$pfsshell" 2>/dev/null | grep -c '^[-d]')
(( sysfiles >= 6 )) && ok "pfs-system-populated ($sysfiles entries)" || bad "pfs-system-populated $sysfiles"

stamp "update-mode rehearsal: re-stage PFS and ext2 from the image, edit, unmount"
storage2="$work/storage2"; mkdir -p "$storage2/__system" "$storage2/__linux.4"
"$bin/pfs-fuse" -o allow_other --partition=__system "$img" "$storage2/__system/" > "$work/pfs2.out" 2>&1 && ok pfs-restage || bad "pfs-restage $(cat "$work/pfs2.out")"
[[ -f "$storage2/__system/p2lboot/vmlinux" ]] && ok pfs-restage-has-vmlinux || bad pfs-restage-has-vmlinux
printf 'second\n' > "$storage2/__system/osdmenu/version.txt"
rm -f "$storage2/__system/bnversion.dat"
t1=$(date +%s)
"$bin/umount" "$storage2/__system" > "$work/umount2.out" 2>&1 && ok "pfs-restage-umount ($(( $(date +%s) - t1 ))s)" || bad "pfs-restage-umount $(cat "$work/umount2.out")"
out=$(printf 'device %s\nmount __system\nls\numount\nexit\n' "$img" | "$pfsshell" 2>/dev/null)
printf 'device %s\nmount __system\ncd osdmenu\nlcd %s\nget version.txt\numount\nexit\n' "$img" "$pfsback" | "$pfsshell" >/dev/null 2>&1
[[ "$(cat "$pfsback/version.txt" 2>/dev/null)" == second ]] && ok pfs-restage-put || bad pfs-restage-put
grep -q 'bnversion.dat' <<<"$out" && bad pfs-restage-rm || ok pfs-restage-rm
t1=$(date +%s)
"$bin/mount" "${mapper}__linux.4" "$storage2/__linux.4" > "$work/mount2.out" 2>&1 && ok "ext2-restage ($(( $(date +%s) - t1 ))s)" || bad "ext2-restage $(cat "$work/mount2.out")"
# The full root filesystem: rdump meets device nodes (EPERM as a user) and
# the N/n terminfo pair APFS folds together. Nothing changed, so the import
# must be empty and the image must stay clean.
mkdir -p "$storage2/__linux.1"
t1=$(date +%s)
if "$bin/mount" "${mapper}__linux.1" "$storage2/__linux.1" > "$work/mount3.out" 2>&1; then
    ok "ext2-restage-root ($(( $(date +%s) - t1 ))s, $(find "$storage2/__linux.1" | wc -l | tr -d ' ') host entries)"
    rec=$(mktemp)
    cat > "$work/debugfs-record" << EOF
#!/bin/bash
if [[ "\$1" == -w && "\$2" == -f && "\$3" == /dev/stdin ]]; then
    tee -a "$rec" | exec $dbg "\$@"
fi
exec $dbg "\$@"
EOF
    chmod +x "$work/debugfs-record"
    t1=$(date +%s)
    if PSBBN_DEBUGFS="$work/debugfs-record" "$bin/umount" "$storage2/__linux.1" > "$work/umount4.out" 2>&1; then
        if [[ ! -s "$rec" ]] || ! grep -qE '^(write|rm|ln|symlink|mkdir|rmdir) ' "$rec"; then
            ok "ext2-restage-root-umount-empty ($(( $(date +%s) - t1 ))s)"
        else
            bad "ext2-restage-root-umount-empty: $(grep -cE '^(write|rm|ln|symlink|mkdir|rmdir) ' "$rec") commands, e.g. $(grep -E '^(write|rm|ln|symlink|mkdir|rmdir) ' "$rec" | head -3)"
        fi
        "$fsck" -fn "$l1" >/dev/null 2>&1 && ok e2fsck-after-root-restage || bad "e2fsck-after-root-restage $("$fsck" -fn "$l1" 2>&1 | grep -v '^Pass' | head -4)"
    else
        bad "ext2-restage-root-umount $(head -5 "$work/umount4.out")"
    fi
else
    bad "ext2-restage-root $(head -5 "$work/mount3.out")"
fi
printf 'again\n' > "$storage2/__linux.4/psbbn-second.txt"
t1=$(date +%s)
"$bin/umount" "$storage2/__linux.4" > "$work/umount3.out" 2>&1 && ok "ext2-restage-umount ($(( $(date +%s) - t1 ))s)" || bad "ext2-restage-umount $(cat "$work/umount3.out")"
[[ "$("$dbg" -R 'cat psbbn-second.txt' "${mapper}__linux.4" 2>/dev/null)" == again ]] && ok ext2-restage-import || bad ext2-restage-import
"$fsck" -fn "${mapper}__linux.4" >/dev/null 2>&1 && ok e2fsck-after-restage || bad e2fsck-after-restage

printf '\n%d passed, %d failed  (work dir %s)\n' "$pass" "$fail" "$work"
[[ "$fail" -eq 0 ]]

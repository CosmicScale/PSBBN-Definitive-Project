#!/opt/homebrew/bin/bash
# Rehearsal of HOSDMenu-Installer's install against a file image.
# No real disk and no sudo. Sends HOSDMenu-Installer's own sequence through
# the same sudo shim, PFS Shell wrapper, PFS Fuse shim and dd shim:
# initialize, PFS mounts of __system __common __sysconf, the files it copies,
# BOOTSTRAP (two dd writes into the first sectors of the drive), clean_up
# (unmount every PFS mount), APA-Jail's magic number and the checksum fix.
#
# BOOTSTRAP writes into the APA header of sector 0 before the PFS mounts are
# unmounted, which leaves the header checksum stale until apa_checksum_fix.
# Linux's PFS Fuse has written the files by then. On macOS unmount is where
# the files go to the drive, and pfsshell will not open a drive whose
# header checksum is wrong.
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
work=$(mktemp -d /tmp/psbbn-hosdmenu.XXXXXX)
export PSBBN_MOUNT_STATE="$work/state"
export PSBBN_MAPPER_DIR="$work/maps"
export PSBBN_DM_STATE="$work/dm"
export COPYFILE_DISABLE=1
printf '#!/bin/bash\nexec "$@"\n' > "$work/run-sudo"
chmod +x "$work/run-sudo"
export PSBBN_SUDO="$work/run-sudo"
img="$work/disk.img"
log="$work/log"
: > "$log"
STORAGE_DIR="$work/storage"
ASSETS_DIR="$repo/scripts/assets"
# The overlay reaches the shims through the helper names.
mkdir -p "$work/helper"
ln -s "$bin/pfs-fuse" "$work/helper/PFS Fuse.elf"
PFS_FUSE="$work/helper/PFS Fuse.elf"
PFS_SHELL="$helper/PFS Shell.elf"
HDL_DUMP="$helper/HDL Dump.elf"
APA_FIXER="$helper/PS2 APA Header Checksum Fixer.elf"
pfsshell="$helper/pfsshell"
APA_PARTITIONS=("__system" "__common" "__sysconf")
extras="$work/extras"
mkdir -p "$extras"
for f in OSDSYS_A.XLF FNTOSD ICOIMAGE JISUCS SKBIMAGE SNDIMAGE TEXIMAGE; do
    head -c 65536 /dev/urandom > "$extras/$f"
done

# pfsshell can spin on a drive it does not understand; never wait forever.
pfs_ls() {
    printf 'device %s\nmount %s\n%sls\numount\nexit\n' "$img" "$1" "${2:+cd $2
}" | timeout 60 "$pfsshell" 2>/dev/null
}

stamp "image at $img"
/usr/sbin/mkfile -n 40g "$img"

stamp "initialize (PFS_COMMANDS)"
echo -e "device ${img}\ninitialize yes\nexit" | "$bin/sudo" "$PFS_SHELL" >> "$log" 2>&1
"$HDL_DUMP" toc "$img" 2>>"$log" | grep -q '__common' && ok initialize || { bad "initialize $(tail -n 3 "$log")"; exit 1; }

stamp "mount_pfs and the files HOSDMenu-Installer copies"
for PARTITION_NAME in "${APA_PARTITIONS[@]}"; do
    MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
    "$bin/sudo" mkdir -p "$MOUNT_POINT"
    "$bin/sudo" "${PFS_FUSE}" -o allow_other --partition="$PARTITION_NAME" "${img}" "$MOUNT_POINT" >> "$log" 2>&1 \
        || bad "mount $PARTITION_NAME $(tail -n 2 "$log")"
done
mkdir -p "${STORAGE_DIR}/__common/Your Saves"
mkdir -p "${STORAGE_DIR}/__system"/{osdmenu,osd100}
mkdir -p "${STORAGE_DIR}/__sysconf/osdmenu/"
cp "${ASSETS_DIR}/osdmenu/hosdmenu.elf" "${STORAGE_DIR}/__system/osdmenu/"
cp "${extras}"/{OSDSYS_A.XLF,FNTOSD,ICOIMAGE,JISUCS,SKBIMAGE,SNDIMAGE,TEXIMAGE} "${STORAGE_DIR}/__system/osd100/"
printf 'boot_auto = $HOSDSYS\nprefer_bbn = 0\n' > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"

stamp "BOOTSTRAP while the PFS partitions are still mounted"
BOOTSTRAP_SIZE=$(wc -c < "${ASSETS_DIR}/osdmenu/OSDMBR.XLF" | tr -d ' ')
BOOTSTRAP_SIZE_LBA_HEX_BE=$(printf "%04X" $((BOOTSTRAP_SIZE / 512)) | tac -rs .. | tr -d '\n')
echo "00200000${BOOTSTRAP_SIZE_LBA_HEX_BE}0000" | xxd -r -p > "$work/apa_header_boot.bin"
# The installer omits conv=notrunc here: a disk node cannot be truncated.
# The image can, so it is added.
"$bin/sudo" dd if="$work/apa_header_boot.bin" of="$img" bs=1 seek=304 conv=notrunc >> "$log" 2>&1
"$bin/sudo" dd if="${ASSETS_DIR}/osdmenu/OSDMBR.XLF" of="$img" bs=1M count=1 seek=4 conv=notrunc >> "$log" 2>&1

stamp "clean_up: unmount every PFS mount"
umount_rc=0
while IFS= read -r line; do
    case "$line" in
        "$STORAGE_DIR/"*)
            "$bin/sudo" umount "$line" >> "$log" 2>&1 || { umount_rc=1; bad "umount $line $(grep -B1 'Exit code' "$log" | tail -n 2 | tr '\n' ' ')"; }
            ;;
    esac
done < <("$bin/findmnt" -nr -o TARGET)
[[ "$umount_rc" -eq 0 ]] && ok clean-up-unmounts-after-bootstrap
[[ -z "$("$bin/findmnt" -nr -o TARGET | grep "^${STORAGE_DIR}/")" ]] && ok no-mounts-left || bad "mounts left: $("$bin/findmnt" -nr -o TARGET | grep "^${STORAGE_DIR}/" | tr '\n' ' ')"

stamp "APA-Jail magic number and the checksum fix"
echo 4150414A2D413200 | xxd -r -p > "$work/apajail_magic_number.bin"
"$bin/sudo" dd if="$work/apajail_magic_number.bin" of="$img" bs=8 count=1 seek=28 conv=notrunc >> "$log" 2>&1
"$bin/sudo" dd if="$img" of="$work/apa_header_full.bin" bs=512 count=2 >> "$log" 2>&1
"$APA_FIXER" "$work/apa_header_full.bin" | sed -n 8p | awk '{print $6}' | xxd -r -p > "$work/apa_header_checksum.bin"
"$bin/sudo" dd if="$work/apa_header_checksum.bin" of="$img" conv=notrunc >> "$log" 2>&1
"$bin/sudo" "$HDL_DUMP" toc "$img" > "$work/toc.txt" 2>>"$log" && grep -q '__sysconf' "$work/toc.txt" && ok toc-after-checksum-fix || bad "toc-after-checksum-fix $(tail -n 2 "$log")"

stamp "what the PS2 will find"
pfs_ls __system osdmenu | grep -q 'hosdmenu.elf' && ok system-has-hosdmenu || bad system-has-hosdmenu
listing=$(pfs_ls __system osd100)
missing=""
for f in OSDSYS_A.XLF FNTOSD ICOIMAGE JISUCS SKBIMAGE SNDIMAGE TEXIMAGE; do
    grep -q "$f" <<< "$listing" || missing+=" $f"
done
[[ -z "$missing" ]] && ok system-has-hdd-osd || bad "system-has-hdd-osd missing:$missing"
pfs_ls __common | grep -q 'Your Saves' && ok common-has-your-saves || bad common-has-your-saves
mkdir -p "$work/got"
printf 'device %s\nmount __sysconf\ncd osdmenu\nlcd %s\nget OSDMBR.CNF\numount\nexit\n' "$img" "$work/got" | timeout 60 "$pfsshell" >/dev/null 2>&1
printf 'boot_auto = $HOSDSYS\nprefer_bbn = 0\n' | cmp -s - "$work/got/OSDMBR.CNF" && ok sysconf-has-osdmbr-cnf || bad sysconf-has-osdmbr-cnf
# The writes back must not have undone BOOTSTRAP.
cmp -s <(dd if="$img" bs=1 skip=304 count=8 2>/dev/null) "$work/apa_header_boot.bin" && ok bootstrap-fields-kept || bad bootstrap-fields-kept
cmp -s <(dd if="$img" bs=1048576 skip=4 count=1 2>/dev/null | head -c "$BOOTSTRAP_SIZE") "${ASSETS_DIR}/osdmenu/OSDMBR.XLF" && ok bootstrap-image-kept || bad bootstrap-image-kept

grep -q 'Exit code is' "$log" && bad "pfsshell error: $(grep -B1 'Exit code is' "$log" | head -2 | tr '\n' ' ')" || ok no-pfsshell-errors

printf '\n%d passed, %d failed  (work dir %s)\n' "$pass" "$fail" "$work"
if [[ "$fail" -eq 0 ]]; then
    rm -rf "$work"
    exit 0
fi
exit 1

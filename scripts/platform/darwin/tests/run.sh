#!/opt/homebrew/bin/bash
# Behavior tests for the darwin shims. No real disk is opened.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
bin="$root/bin"
fail=0
pass=0

ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }

export PATH="$bin:/opt/homebrew/bin:/usr/bin:/bin"

machine=$(PSBBN_UNAME=/usr/bin/uname "$bin/uname" -m)
real=$(/usr/bin/uname -m)
if [[ "$real" == arm64 && "$machine" == aarch64 ]]; then ok uname-arm64; else bad "uname-arm64 got $machine"; fi
if [[ "$("$bin/uname" -s)" == Darwin ]]; then ok uname-s; else bad uname-s; fi

stub=$(mktemp -d)
cat > "$stub/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == -m ]]; then echo x86_64; else echo Darwin; fi
EOF
chmod +x "$stub/uname"
if [[ "$(PSBBN_UNAME="$stub/uname" "$bin/uname" -m)" == x86_64 ]]; then ok uname-x86; else bad uname-x86; fi

. "$root/lib.sh"
got=$(psbbn_rewrite_device /dev/disk63)
[[ "$got" == /dev/disk6s3 ]] && ok rewrite-disk63 || bad "rewrite-disk63 $got"
got=$(psbbn_rewrite_device /dev/rdisk62)
[[ "$got" == /dev/rdisk6s2 ]] && ok rewrite-rdisk62 || bad "rewrite-rdisk62 $got"
got=$(psbbn_rewrite_device /dev/disk6)
[[ "$got" == /dev/disk6 ]] && ok rewrite-disk6 || bad "rewrite-disk6 $got"
got=$(psbbn_rewrite_device /dev/disk6s1)
[[ "$got" == /dev/disk6s1 ]] && ok rewrite-disk6s1 || bad "rewrite-disk6s1 $got"
got=$(psbbn_rewrite_device /dev/sda3)
[[ "$got" == /dev/sda3 ]] && ok rewrite-sda3 || bad "rewrite-sda3 $got"
got=$(psbbn_rewrite_device /dev/disk10)
[[ "$got" == /dev/disk10 ]] && ok rewrite-disk10 || bad "rewrite-disk10 $got"
got=$(psbbn_rewrite_device /dev/disk103)
[[ "$got" == /dev/disk10s3 ]] && ok rewrite-disk103 || bad "rewrite-disk103 $got"

got=$(printf '%s\n' /dev/disk6s3 | "$bin/sed" 's/[0-9]*$//')
[[ "$got" == /dev/disk6 ]] && ok sed-disk || bad "sed-disk $got"
got=$(printf '%s\n' /dev/sda3 | "$bin/sed" 's/[0-9]*$//')
[[ "$got" == /dev/sda ]] && ok sed-sda || bad "sed-sda $got"

fix=$(mktemp -d)
python3 - "$fix" << 'PY'
import plistlib, sys
d = sys.argv[1]
def dump(path, obj):
    with open(path, "wb") as f:
        plistlib.dump(obj, f)
dump(f"{d}/list.plist", {
    "WholeDisks": ["disk4", "disk6"],
    "AllDisksAndPartitions": [
        {"DeviceIdentifier": "disk4", "Partitions": [
            {"DeviceIdentifier": "disk4s3", "Content": "Windows_NTFS"}]},
        {"DeviceIdentifier": "disk6", "Partitions": [
            {"DeviceIdentifier": "disk6s1", "Content": "Windows_NTFS"}]},
    ],
})
dump(f"{d}/disk4s3.plist", {
    "FilesystemType": "exfat", "VolumeName": "OPL", "DeviceNode": "/dev/disk4s3",
    "Content": "Windows_NTFS",
})
dump(f"{d}/disk6s1.plist", {
    "FilesystemType": "exfat", "VolumeName": "SD_Card", "DeviceNode": "/dev/disk6s1",
    "Content": "Windows_NTFS",
})
PY
cat > "$fix/diskutil" << EOF
#!/bin/bash
if [[ "\$1" == list ]]; then cat "$fix/list.plist"; exit 0; fi
if [[ "\$1" == info ]]; then cat "$fix/\$3.plist"; exit 0; fi
exit 1
EOF
chmod +x "$fix/diskutil"
line=$(PSBBN_DISKUTIL="$fix/diskutil" "$bin/blkid" -t TYPE=exfat | grep OPL || true)
dev=$(printf '%s\n' "$line" | awk -F: '{print $1}' | "$bin/sed" 's/[0-9]*$//')
if [[ "$dev" == /dev/disk4 ]]; then ok blkid-opl; else bad "blkid-opl line=$line dev=$dev"; fi
if printf '%s\n' "$line" | grep -q 'TYPE="exfat"'; then ok blkid-type; else bad blkid-type; fi
if PSBBN_DISKUTIL="$fix/diskutil" "$bin/blkid" -t TYPE=exfat | grep -q SD_Card; then
    ok blkid-lists-sd
else
    bad blkid-lists-sd
fi
selected=$(PSBBN_DISKUTIL="$fix/diskutil" "$bin/blkid" -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | "$bin/sed" 's/[0-9]*$//')
if [[ "$selected" == /dev/disk4 ]]; then ok blkid-not-sd; else bad "blkid-not-sd $selected"; fi

marker=$(mktemp)
cat > "$stub/real-sudo" << EOF
#!/bin/bash
echo CALLED >> "$marker"
printf '%s\n' "\$PATH"
EOF
chmod +x "$stub/real-sudo"
out=$(PATH="$bin:$stub" PSBBN_REAL_SUDO="$stub/real-sudo" "$bin/sudo" blkid --psbbn-shim-ok)
if [[ ! -s "$marker" ]]; then ok sudo-shim; else bad sudo-shim; fi
set +e
PATH="$bin:$stub" PSBBN_REAL_SUDO="$stub/real-sudo" "$bin/sudo" modprobe exfat >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -ne 0 && ! -s "$marker" ]]; then ok sudo-missing; else bad "sudo-missing rc=$rc"; fi
: > "$marker"
out=$(PATH="$bin:$stub" PSBBN_REAL_SUDO="$stub/real-sudo" "$bin/sudo" /bin/echo hi)
if grep -q "$bin" <<< "$out" && grep -q CALLED "$marker"; then ok sudo-path; else bad "sudo-path out=$out"; fi

if "$bin/ldconfig" -p | grep -q libfuse.so.2; then bad ldconfig-empty; else ok ldconfig-empty; fi
touch "$stub/libfuse"
if PSBBN_FUSE_LIB="$stub/libfuse" "$bin/ldconfig" -p | grep -q "$stub/libfuse"; then ok ldconfig-real; else bad ldconfig-real; fi

if [[ -x "$bin/lvm" ]]; then ok lvm-exists; else bad lvm-exists; fi
set +e
"$bin/lvm" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] && ok lvm-fails || bad lvm-fails

cat > "$stub/diskutil-mount" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$stub/diskutil-mount"
mount_out=$(PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount.exfat-fuse" -o uid=1,gid=1 /dev/disk43 /tmp/mnt)
if grep -q /dev/disk4s3 <<< "$mount_out"; then ok exfat-rewrite; else bad "exfat-rewrite $mount_out"; fi

state=$(mktemp -d)
printf '%s\n' 'disk4-__linux.1,,,rw,0 100 linear /dev/disk4 2048' | PSBBN_DM_STATE="$state" "$bin/dmsetup" create --concise
if PSBBN_DM_STATE="$state" "$bin/dmsetup" ls | grep -q 'disk4-__linux.1'; then ok dm-create; else bad dm-create; fi
PSBBN_DM_STATE="$state" "$bin/dmsetup" remove -f disk4-__linux.1
if PSBBN_DM_STATE="$state" "$bin/dmsetup" ls | grep -q 'disk4-__linux.1'; then bad dm-remove-f; else ok dm-remove-f; fi

img=$(mktemp)
dd if=/dev/zero of="$img" bs=1048576 count=80 status=none 2>/dev/null || dd if=/dev/zero of="$img" bs=1048576 count=80 >/dev/null
printf '%s\n' ',10MiB,17' ',32MiB,17' ',,07' | "$bin/sfdisk" "$img"
python3 - "$img" << 'PY'
import struct, sys
b = open(sys.argv[1], "rb").read(512)
assert b[510] == 0x55 and b[511] == 0xAA
assert b[450] == 0x17, b[450]
assert b[466] == 0x17, b[466]
assert b[482] == 0x07, b[482]
start, count = struct.unpack_from("<II", b, 454)
assert start == 2048, start
assert count == 10 * 2048, count
print("mbr-ok")
PY
[[ $? -eq 0 ]] && ok sfdisk || bad sfdisk
set +e
"$bin/sfdisk" /dev/disk6 </dev/null >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] && ok sfdisk-refuse || bad sfdisk-refuse

"$bin/partprobe" "$img" && ok partprobe || bad partprobe
sectors=$("$bin/blockdev" --getsz "$img")
[[ "$sectors" == 163840 ]] && ok blockdev || bad "blockdev $sectors"
set +e
"$bin/mke2fs" /dev/disk6 >/dev/null 2>&1
rc=$?
"$bin/mkfs.vfat" /dev/disk6 >/dev/null 2>&1
rc2=$?
set -e
[[ "$rc" -ne 0 && "$rc2" -ne 0 ]] && ok mkfs-refuse || bad mkfs-refuse

cat > "$stub/mount" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$stub/mount"
mout=$(PSBBN_REAL_MOUNT="$stub/mount" "$bin/mount" -o uid=1 /dev/disk63 /tmp/opl)
if grep -q /dev/disk6s3 <<< "$mout"; then ok mount-rewrite; else bad "mount-rewrite $mout"; fi

printf '%s\n' '/dev/disk4s3 on /tmp/psbbn-storage/__system (exfat, local)' > "$stub/mounts"
found=$(PSBBN_MOUNT_FILE="$stub/mounts" "$bin/findmnt" -nr -o TARGET)
[[ "$found" == /tmp/psbbn-storage/__system ]] && ok findmnt || bad "findmnt $found"

set +e
refuse=$("$root/../../helper/darwin-arm64/mkfs.exfat" -c 32K -L OPL /dev/disk63 2>&1)
rc=$?
set -e
[[ "$rc" -eq 2 && "$refuse" == *"/dev/disk6s3"* ]] && ok mkfs-exfat-refuse || bad "mkfs-exfat-refuse rc=$rc $refuse"
stub_newfs=$(mktemp)
cat > "$stub_newfs" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$stub_newfs"
recorded=$(PSBBN_ALLOW_DISK_FORMAT=1 PSBBN_NEWFS_EXFAT="$stub_newfs" "$root/../../helper/darwin-arm64/mkfs.exfat" -c 32K -L OPL /dev/disk63)
if grep -q -- '-R' <<< "$recorded" && grep -q -- '-b' <<< "$recorded" && grep -q 32768 <<< "$recorded" && grep -q /dev/disk6s3 <<< "$recorded"; then
    ok mkfs-exfat-args
else
    bad "mkfs-exfat-args $recorded"
fi

python3 - "$fix" << 'PY'
import plistlib, sys
d = sys.argv[1]
def dump(path, obj):
    with open(path, "wb") as f:
        plistlib.dump(obj, f)
dump(f"{d}/ls-list.plist", {
    "AllDisksAndPartitions": [{
        "DeviceIdentifier": "disk4",
        "Size": 80 * 1024 ** 3,
        "Partitions": [{
            "DeviceIdentifier": "disk4s3",
            "Size": 40 * 1024 ** 3,
            "VolumeName": "OPL",
            "MountPoint": "/Volumes/OPL",
            "Content": "Windows_NTFS",
        }],
    }, {
        "DeviceIdentifier": "disk6",
        "Size": 120 * 1024 ** 3,
        "Partitions": [{
            "DeviceIdentifier": "disk6s1",
            "Size": 120 * 1024 ** 3,
            "VolumeName": "SD_Card",
            "MountPoint": "/Volumes/SD_Card",
        }],
    }],
})
dump(f"{d}/disk4.plist", {"MediaName": "PS2 Drive", "IOKitSerialNumber": "ABC"})
dump(f"{d}/disk6.plist", {"MediaName": "Micro SD/M2", "IOKitSerialNumber": "SD"})
PY
cat > "$fix/lsblk-diskutil" << EOF
#!/bin/bash
if [[ "\$1" == list ]]; then cat "$fix/ls-list.plist"; exit 0; fi
if [[ "\$1" == info ]]; then cat "$fix/\${3}.plist"; exit 0; fi
exit 1
EOF
chmod +x "$fix/lsblk-diskutil"
model=$(PSBBN_DISKUTIL="$fix/lsblk-diskutil" "$bin/lsblk" -ndo MODEL /dev/disk4)
[[ "$model" == "PS2 Drive" ]] && ok lsblk-one-disk || bad "lsblk-one-disk $model"
points=$(PSBBN_DISKUTIL="$fix/lsblk-diskutil" "$bin/lsblk" -ln -o MOUNTPOINT /dev/disk4)
if printf '%s\n' "$points" | grep -qx /Volumes/OPL && ! printf '%s\n' "$points" | grep -q SD_Card; then
    ok lsblk-mount
else
    bad "lsblk-mount $points"
fi

repo=$(mktemp -d)
mkdir -p "$repo/scripts/assets/lang" "$repo/scripts/helper/aarch64" "$repo/scripts/helper/darwin-arm64"
echo keep-me > "$repo/scripts/assets/lang/sample.txt"
echo elf > "$repo/scripts/helper/aarch64/cue2pops"
echo macho > "$repo/scripts/helper/darwin-arm64/cue2pops"
overlay=$(mktemp -d)
# shellcheck disable=SC1091
. "$root/lib.sh"
build_overlay "$repo" "$overlay"
rm "$overlay/scripts/assets/lang/sample.txt"
if [[ -f "$repo/scripts/assets/lang/sample.txt" ]]; then ok overlay-rm; else bad overlay-rm; fi
if [[ "$(cat "$overlay/scripts/helper/aarch64/cue2pops")" == macho ]]; then ok overlay-helper; else bad overlay-helper; fi

for tool in uname sudo blkid ldconfig lvm dmsetup sfdisk partprobe blockdev wipefs mount umount findmnt mkfs.vfat mke2fs timeout unrar-free mount.exfat-fuse lsblk sed; do
    if [[ -x "$bin/$tool" ]]; then ok "exec-$tool"; else bad "exec-$tool"; fi
done

rm -rf "$stub" "$fix" "$state" "$img" "$repo" "$overlay" "$marker"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

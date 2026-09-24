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

# --- rsync follows the overlay's symlinks --------------------------------
rs=$(mktemp -d)
printf 'payload\n' > "$rs/real.elf"
mkdir -p "$rs/src" "$rs/dst"
ln -s "$rs/real.elf" "$rs/src/app.elf"
out=$("$bin/rsync" -t "$rs/src/app.elf" "$rs/dst/" 2>&1)
if [[ -f "$rs/dst/app.elf" && ! -L "$rs/dst/app.elf" && "$(cat "$rs/dst/app.elf")" == payload ]] && ! grep -q skipping <<<"$out"; then
    ok rsync-follows-symlinks
else
    bad "rsync-follows-symlinks $out"
fi
"$bin/rsync" --psbbn-shim-ok && ok rsync-shim-ok || bad rsync-shim-ok
rm -rf "$rs"

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

python3 - "$fix" << 'PY2'
import plistlib, sys
d = sys.argv[1]
with open(f"{d}/disk4s3-ext.plist", "wb") as f:
    plistlib.dump({"Internal": False, "FilesystemType": "exfat", "MountPoint": "", "Size": 1 << 30, "TotalSize": 1 << 30}, f)
with open(f"{d}/disk5s2-blank.plist", "wb") as f:
    plistlib.dump({"Internal": False, "Size": 16 * 1024 * 1024, "TotalSize": 16 * 1024 * 1024, "MountPoint": ""}, f)
with open(f"{d}/disk5-ext.plist", "wb") as f:
    plistlib.dump({"Internal": False, "Size": 160041885696, "TotalSize": 160041885696}, f)
PY2
diskutil_rec=$(mktemp)
cat > "$stub/diskutil-mount" << EOF
#!/bin/bash
# Stateful diskutil. Like the real one: "mount -mountPoint X" on a volume
# that is already mounted answers 0 and leaves it where it is; mount points
# are reported with symlinks resolved; unmount clears the mount.
printf '%s\n' "\$*" >> "$diskutil_rec"
statef="$stub/da-state"
case "\$1" in
    info)
        case "\$3" in
            disk4s3)
                python3 - "$fix/disk4s3-ext.plist" "\$(cat "\$statef" 2>/dev/null)" << 'PY3'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    d = plistlib.load(f)
d["MountPoint"] = sys.argv[2]
sys.stdout.buffer.write(plistlib.dumps(d))
PY3
                exit 0 ;;
            disk5s2) cat "$fix/disk5s2-blank.plist"; exit 0 ;;
            disk5|disk4) cat "$fix/disk5-ext.plist"; exit 0 ;;
        esac
        exit 1 ;;
    mount)
        if [[ ! -s "\$statef" && ! -e "$stub/da-nomount" ]]; then
            if [[ -e "$stub/da-race" ]]; then
                # Disk Arbitration landed its own mount first.
                rm -f "$stub/da-race"
                printf '%s\n' /Volumes/OPL > "\$statef"
            elif [[ "\$2" == -mountPoint ]]; then
                python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "\$3" > "\$statef"
            else
                printf '%s\n' /Volumes/OPL > "\$statef"
            fi
        fi
        echo "Volume OPL on \${!#} mounted"
        exit 0 ;;
    unmount|unmountDisk)
        [[ -e "$stub/da-stuck" ]] || : > "\$statef"
        exit 0 ;;
esac
exit 1
EOF
chmod +x "$stub/diskutil-mount"
exfat_mnt=$(mktemp -d)
if PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount.exfat-fuse" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" \
    && grep -q "mount -mountPoint $exfat_mnt /dev/disk4s3" "$diskutil_rec"; then
    ok exfat-rewrite
else
    bad "exfat-rewrite $(cat "$diskutil_rec")"
fi
: > "$diskutil_rec"
: > "$stub/da-state"
if PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" \
    && grep -q "mount -mountPoint $exfat_mnt /dev/disk4s3" "$diskutil_rec"; then
    ok mount-exfat-node
else
    bad "mount-exfat-node $(cat "$diskutil_rec")"
fi
: > "$diskutil_rec"
if PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_MOUNT_STATE="$stub/nostate" "$bin/umount" -l "$exfat_mnt" \
    && grep -q "unmount $exfat_mnt" "$diskutil_rec"; then
    ok umount-diskutil
else
    bad "umount-diskutil $(cat "$diskutil_rec")"
fi

# --- AppleDouble sidecars are removed from a real OPL mount before unmount
ad_dir=$(mktemp -d)
touch "$ad_dir/version.txt" "$ad_dir/._version.txt"
mkdir "$ad_dir/APPS"; touch "$ad_dir/._APPS" "$ad_dir/APPS/._x" "$ad_dir/APPS/x"
cat > "$stub/dot_clean" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$diskutil_rec"
exec /usr/sbin/dot_clean "\$@"
EOF
chmod +x "$stub/dot_clean"
# not a mount point of a disk partition: left alone
: > "$diskutil_rec"
/opt/homebrew/bin/bash -c '. "$1"; psbbn_strip_appledouble "$2"' _ "$root/../load.sh" "$ad_dir"
if [[ -e "$ad_dir/._version.txt" && ! -s "$diskutil_rec" ]]; then ok appledouble-only-real-mounts; else bad "appledouble-only-real-mounts $(ls -a "$ad_dir") $(cat "$diskutil_rec")"; fi
# the real thing: run dot_clean on the tree directly to prove -m removes only the sidecars
/usr/sbin/dot_clean -m "$ad_dir"
if [[ ! -e "$ad_dir/._version.txt" && ! -e "$ad_dir/._APPS" && ! -e "$ad_dir/APPS/._x" && -e "$ad_dir/version.txt" && -e "$ad_dir/APPS/x" ]]; then
    ok appledouble-dot-clean
else
    bad "appledouble-dot-clean $(ls -aR "$ad_dir")"
fi
rm -rf "${ad_dir:?}"

# --- the OPL volume is never trusted to be where diskutil says "mounted" ---
# Disk Arbitration already holds it under /Volumes: evict, then mount.
printf '%s\n' /Volumes/OPL > "$stub/da-state"
: > "$diskutil_rec"
if PSBBN_DA_SETTLE=0 PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" \
    && grep -q "^unmount /Volumes/OPL$" "$diskutil_rec" \
    && [[ "$(cat "$stub/da-state")" == "$(cd "$exfat_mnt" && pwd -P)" ]]; then
    ok mount-evicts-volumes
else
    bad "mount-evicts-volumes state=$(cat "$stub/da-state") $(cat "$diskutil_rec")"
fi
# Disk Arbitration lands its mount between the check and the request;
# diskutil then says "mounted" with status 0 and leaves it under /Volumes.
: > "$stub/da-state"
touch "$stub/da-race"
: > "$diskutil_rec"
if PSBBN_DA_SETTLE=0 PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" \
    && grep -q "^unmount /Volumes/OPL$" "$diskutil_rec" \
    && [[ "$(cat "$stub/da-state")" == "$(cd "$exfat_mnt" && pwd -P)" ]]; then
    ok mount-wins-da-race
else
    bad "mount-wins-da-race state=$(cat "$stub/da-state") $(cat "$diskutil_rec")"
fi
# The volume cannot be moved: mount must fail rather than report a mount
# that is not there (the installer would write into the local folder).
printf '%s\n' /Volumes/OPL > "$stub/da-state"
touch "$stub/da-stuck"
: > "$diskutil_rec"
set +e
err=$(PSBBN_DA_SETTLE=0 PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" 2>&1)
rc=$?
set -e
if [[ "$rc" -ne 0 ]] && grep -q "could not mount" <<< "$err"; then
    ok mount-refuses-wrong-place
else
    bad "mount-refuses-wrong-place rc=$rc $err"
fi
rm -f "$stub/da-stuck"
: > "$stub/da-state"
# A mount point reached through a symlink ($TMPDIR is /var/..., diskutil
# reports /private/var/...) is recognised as the same place: no eviction,
# and a second mount call is a no-op.
ln -s "$exfat_mnt" "$stub/opl-link"
: > "$diskutil_rec"
if PSBBN_DA_SETTLE=0 PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$stub/opl-link" \
    && ! grep -q "^unmount" "$diskutil_rec" \
    && PSBBN_DA_SETTLE=0 PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/mount" -o uid=1,gid=1 /dev/disk43 "$exfat_mnt" \
    && ! grep -q "^unmount" "$diskutil_rec" \
    && [[ "$(cat "$stub/da-state")" == "$(cd "$exfat_mnt" && pwd -P)" ]]; then
    ok mount-symlinked-path
else
    bad "mount-symlinked-path state=$(cat "$stub/da-state") $(cat "$diskutil_rec")"
fi
: > "$stub/da-state"

# --- Disk Arbitration automounts are evicted before whole-disk opens ------
# Only /Volumes mounts of the target disk go; the installer's own mount
# and other disks stay.
cat > "$stub/mount-table" << EOF
/dev/disk0s1 on / (apfs, sealed, local, read-only, journaled)
/dev/disk4s3 on /Volumes/OPL (exfat, local, nodev, nosuid, noowners, noatime, fskit)
/dev/disk7s1 on $exfat_mnt (exfat, local, nodev, nosuid, noowners, noatime, fskit, mounted by u)
/dev/disk6s1 on /Volumes/SD Card (exfat, local, nodev, nosuid, noowners)
/dev/disk5s1 on /Volumes/PS2 (exfat, local, nodev, nosuid, noowners)
EOF
cat > "$stub/mount-table-opl" << EOF
/dev/disk0s1 on / (apfs, sealed, local, read-only, journaled)
/dev/disk4s3 on $(cd "$exfat_mnt" && pwd -P) (exfat, local, nodev, nosuid, noowners, noatime, fskit, mounted by u)
EOF
cat > "$stub/run-sudo" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$stub/run-sudo.rec"
exec "\$@"
EOF
chmod +x "$stub/run-sudo"
: > "$diskutil_rec"
PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" /opt/homebrew/bin/bash -c '. "$1"; psbbn_evict_automounts /dev/disk43' _ "$root/../load.sh"
if [[ "$(grep -c '^unmount' "$diskutil_rec")" -eq 1 ]] && grep -q '^unmount /Volumes/OPL$' "$diskutil_rec"; then
    ok evict-automounts
else
    bad "evict-automounts $(cat "$diskutil_rec")"
fi
: > "$diskutil_rec"
: > "$marker"
PSBBN_SUDO="$stub/real-sudo" PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" \
    /opt/homebrew/bin/bash -c '. "$1"; platform_elevate /x/hdl_dump toc /dev/disk4' _ "$root/../load.sh" >/dev/null
if grep -q '^unmount /Volumes/OPL$' "$diskutil_rec" && grep -q CALLED "$marker"; then
    ok elevate-evicts-automounts
else
    bad "elevate-evicts-automounts $(cat "$diskutil_rec") marker=$(cat "$marker")"
fi
: > "$marker"

# --- da-veto: started once per session, allow file around own mounts ------
veto_rec=$(mktemp)
cat > "$stub/da-veto" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$veto_rec"
echo "ready \$1"
for i in \$(seq 1 100); do
    kill -0 "\$3" 2>/dev/null || exit 0
    sleep 0.2
done
EOF
chmod +x "$stub/da-veto"
cat > "$stub/diskutil-allow" << EOF
#!/bin/bash
if [[ "\$1" == mount ]]; then
    if [[ -e "$stub/vstate/allow-disk4" ]]; then echo allow=yes; else echo allow=no; fi >> "$veto_rec.mount"
fi
exec "$stub/diskutil-mount" "\$@"
EOF
chmod +x "$stub/diskutil-allow"
veto_env=(PSBBN_SESSION_PID=$$ PSBBN_DA_VETO="$stub/da-veto" PSBBN_MOUNT_STATE="$stub/vstate" \
    PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_DA_SETTLE=0)
env "${veto_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_evict_automounts /dev/disk4' _ "$root/../load.sh" 2>/dev/null
veto_pid=$(cat "$stub/vstate/veto-disk4.pid" 2>/dev/null)
if [[ "$(cat "$veto_rec")" == "disk4 $stub/vstate/allow-disk4 $$" ]] && [[ -n "$veto_pid" ]] && kill -0 "$veto_pid" 2>/dev/null; then
    ok veto-starts-on-evict
else
    bad "veto-starts-on-evict rec=$(cat "$veto_rec") pid=$veto_pid"
fi
env "${veto_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_evict_automounts /dev/disk4; psbbn_veto_start /dev/rdisk4s3' _ "$root/../load.sh" 2>/dev/null
[[ "$(wc -l < "$veto_rec" | tr -d ' ')" == 1 ]] && ok veto-starts-once || bad "veto-starts-once $(cat "$veto_rec")"
: > "$stub/da-state"
veto_mnt=$(mktemp -d)
env "${veto_env[@]}" PSBBN_DISKUTIL="$stub/diskutil-allow" /opt/homebrew/bin/bash -c '. "$1"; psbbn_diskutil_mount /dev/disk4s3 "$2"' _ "$root/../load.sh" "$veto_mnt" >/dev/null 2>&1
if grep -q '^allow=yes$' "$veto_rec.mount" && [[ ! -e "$stub/vstate/allow-disk4" ]] \
    && [[ "$(cat "$stub/da-state")" == "$(cd "$veto_mnt" && pwd -P)" ]]; then
    ok veto-allow-file-during-own-mount
else
    bad "veto-allow-file-during-own-mount $(cat "$veto_rec.mount" 2>/dev/null) allow-left=$([[ -e "$stub/vstate/allow-disk4" ]] && echo yes || echo no)"
fi
: > "$stub/da-state"
env "${veto_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_veto_start /dev/disk0' _ "$root/../load.sh" 2>/dev/null
[[ "$(wc -l < "$veto_rec" | tr -d ' ')" == 1 ]] && ok veto-skips-internal-disk || bad "veto-skips-internal-disk $(cat "$veto_rec")"
env "${veto_env[@]}" PSBBN_MOUNT_STATE="$stub/vstate2" /opt/homebrew/bin/bash -c '. "$1"; psbbn_veto_start /dev/disk4' _ "$root/../load.sh" 2>/dev/null
[[ "$(wc -l < "$veto_rec" | tr -d ' ')" == 2 && -s "$stub/vstate2/veto-disk4.pid" ]] && ok veto-per-state-dir || bad "veto-per-state-dir $(cat "$veto_rec")"
env PSBBN_DA_VETO="$stub/da-veto" PSBBN_MOUNT_STATE="$stub/vstate3" PSBBN_DISKUTIL="$stub/diskutil-mount" \
    /opt/homebrew/bin/bash -c 'unset PSBBN_SESSION_PID; . "$1"; psbbn_veto_start /dev/disk4' _ "$root/../load.sh" 2>/dev/null
[[ "$(wc -l < "$veto_rec" | tr -d ' ')" == 2 && ! -e "$stub/vstate3/veto-disk4.pid" ]] && ok veto-needs-session || bad "veto-needs-session $(cat "$veto_rec")"
# A pidfile left by an earlier run may now name an unrelated live process.
mkdir -p "$stub/vstate4"
printf '%s\n' "$$" > "$stub/vstate4/veto-disk4.pid"
env "${veto_env[@]}" PSBBN_MOUNT_STATE="$stub/vstate4" /opt/homebrew/bin/bash -c '. "$1"; psbbn_veto_start /dev/disk4' _ "$root/../load.sh" 2>/dev/null
if [[ "$(wc -l < "$veto_rec" | tr -d ' ')" == 3 && -s "$stub/vstate4/veto-disk4.pid" && "$(cat "$stub/vstate4/veto-disk4.pid")" != "$$" ]]; then
    ok veto-ignores-reused-pid
else
    bad "veto-ignores-reused-pid $(cat "$veto_rec") pidfile=$(cat "$stub/vstate4/veto-disk4.pid" 2>/dev/null)"
fi
for f in "$stub/vstate/veto-disk4.pid" "$stub/vstate2/veto-disk4.pid" "$stub/vstate4/veto-disk4.pid"; do
    [[ -s "$f" ]] && kill "$(cat "$f")" 2>/dev/null
done
rm -f "$veto_rec" "$veto_rec.mount"
rm -rf "$veto_mnt"

# --- partprobe: a disk that never exposes its slices is a failure -------
set +e
out=$(PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_PARTPROBE_TRIES=2 "$bin/partprobe" /dev/disk5 2>&1)
status=$?
[[ "$status" -eq 1 && "$out" == *"did not expose"* ]] && ok partprobe-timeout-fails || bad "partprobe-timeout-fails status=$status $out"
out=$("$bin/partprobe" /dev/disk0 2>&1)
status=$?
[[ "$status" -eq 2 && "$out" == *"internal"* ]] && ok partprobe-refuses-internal || bad "partprobe-refuses-internal status=$status $out"
set -e

# --- HDL Dump.elf and PFS Shell.elf wrappers retry an EBUSY open ----------
# A fake helper tree: the wrappers find load.sh two levels up and their
# binaries next to themselves.
tree=$(mktemp -d)
mkdir -p "$tree/scripts/helper/fake"
ln -s "$root/.." "$tree/scripts/platform"
cp "$root/../../helper/darwin-arm64/HDL Dump.elf" "$tree/scripts/helper/fake/HDL Dump.elf"
cp "$root/../../helper/darwin-arm64/PFS Shell.elf" "$tree/scripts/helper/fake/PFS Shell.elf"
cat > "$tree/scripts/helper/fake/hdl_dump" << EOF
#!/bin/bash
n=\$(cat "$tree/hdl-calls" 2>/dev/null || echo 0)
n=\$((n + 1))
echo "\$n" > "$tree/hdl-calls"
if [[ "\$n" -le 2 && ! -e "$tree/hdl-otherfail" ]]; then
    echo "00000010 (16): Resource busy" >&2
    exit 1
fi
if [[ -e "$tree/hdl-otherfail" ]]; then
    echo "apa: bad header" >&2
    exit 1
fi
echo "type   start     #parts size name"
echo "0x0001 00000000.:  1   128MB __mbr"
EOF
cat > "$tree/scripts/helper/fake/pfsshell" << EOF
#!/bin/bash
n=\$(cat "$tree/pfs-calls" 2>/dev/null || echo 0)
n=\$((n + 1))
echo "\$n" > "$tree/pfs-calls"
cat >/dev/null
echo "pfsshell for POSIX systems"
if [[ "\$n" -le 1 ]]; then
    echo "> /dev/disk4: Resource busy"
    exit 0
fi
echo "> hdd0: 149GiB"
EOF
chmod +x "$tree/scripts/helper/fake/hdl_dump" "$tree/scripts/helper/fake/pfsshell"
: > "$diskutil_rec"
set +e
out=$(PSBBN_DA_SETTLE=0 PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" "$tree/scripts/helper/fake/HDL Dump.elf" toc /dev/disk4 2>"$tree/hdl-err")
rc=$?
set -e
if [[ "$rc" -eq 0 && "$(cat "$tree/hdl-calls")" == 3 ]] && grep -q '^type' <<< "$out" && [[ "$(grep -c '^unmount /Volumes/OPL$' "$diskutil_rec")" -eq 3 ]] && [[ ! -s "$tree/hdl-err" ]]; then
    ok hdl-dump-retries-busy
else
    bad "hdl-dump-retries-busy rc=$rc calls=$(cat "$tree/hdl-calls") out=$out err=$(cat "$tree/hdl-err") diskutil=$(cat "$diskutil_rec")"
fi
rm -f "$tree/hdl-calls"
touch "$tree/hdl-otherfail"
set +e
out=$(PSBBN_DA_SETTLE=0 PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" "$tree/scripts/helper/fake/HDL Dump.elf" toc /dev/disk4 2>"$tree/hdl-err")
rc=$?
set -e
if [[ "$rc" -eq 1 && "$(cat "$tree/hdl-calls")" == 1 ]] && grep -q 'bad header' "$tree/hdl-err"; then
    ok hdl-dump-no-retry-other-error
else
    bad "hdl-dump-no-retry-other-error rc=$rc calls=$(cat "$tree/hdl-calls") err=$(cat "$tree/hdl-err")"
fi
: > "$diskutil_rec"
set +e
out=$(printf 'device /dev/disk4\nls\nexit\n' | PSBBN_DA_SETTLE=0 PSBBN_MOUNT_TABLE="$stub/mount-table" PSBBN_DISKUTIL="$stub/diskutil-mount" "$tree/scripts/helper/fake/PFS Shell.elf" 2>&1)
rc=$?
set -e
if [[ "$rc" -eq 0 && "$(cat "$tree/pfs-calls")" == 2 ]] && grep -q '149GiB' <<< "$out" && grep -q '^unmount /Volumes/OPL$' "$diskutil_rec"; then
    ok pfs-shell-retries-busy
else
    bad "pfs-shell-retries-busy rc=$rc calls=$(cat "$tree/pfs-calls") out=$out diskutil=$(cat "$diskutil_rec")"
fi

# --- the installer's own OPL mount is released around a whole-disk open and
# put back on the same path afterwards -------------------------------------
want=$(cd "$exfat_mnt" && pwd -P)
printf '%s\n' "$want" > "$stub/da-state"
: > "$diskutil_rec"; : > "$stub/run-sudo.rec"
out=$(PSBBN_DA_SETTLE=0 PSBBN_SUDO="$stub/run-sudo" PSBBN_MOUNT_TABLE="$stub/mount-table-opl" PSBBN_DISKUTIL="$stub/diskutil-mount" \
    /opt/homebrew/bin/bash -c '. "$1"; platform_elevate /bin/echo toc /dev/disk4' _ "$root/../load.sh")
rc=$?
if [[ "$rc" -eq 0 && "$out" == "toc /dev/disk4" && "$(cat "$stub/da-state")" == "$want" ]] \
    && [[ "$(grep -n "^unmount $want$" "$diskutil_rec" | head -1 | cut -d: -f1)" -lt "$(grep -n "^mount -mountPoint $want /dev/disk4s3$" "$diskutil_rec" | head -1 | cut -d: -f1)" ]]; then
    ok elevate-releases-installer-mount
else
    bad "elevate-releases-installer-mount rc=$rc out=$out state=$(cat "$stub/da-state") $(cat "$diskutil_rec")"
fi
# a partition node argument leaves the installer's mount alone
: > "$diskutil_rec"
PSBBN_DA_SETTLE=0 PSBBN_SUDO="$stub/run-sudo" PSBBN_MOUNT_TABLE="$stub/mount-table-opl" PSBBN_DISKUTIL="$stub/diskutil-mount" \
    /opt/homebrew/bin/bash -c '. "$1"; platform_elevate /bin/echo /dev/disk43' _ "$root/../load.sh" >/dev/null
if ! grep -q '^unmount' "$diskutil_rec" && [[ "$(cat "$stub/da-state")" == "$want" ]]; then
    ok elevate-skips-partition-node
else
    bad "elevate-skips-partition-node $(cat "$diskutil_rec")"
fi
# the command ran but the mount does not come back: that is a failure
touch "$stub/da-nomount"
: > "$stub/run-sudo.rec"
set +e
err=$(PSBBN_DA_SETTLE=0 PSBBN_SUDO="$stub/run-sudo" PSBBN_MOUNT_TABLE="$stub/mount-table-opl" PSBBN_DISKUTIL="$stub/diskutil-mount" \
    /opt/homebrew/bin/bash -c '. "$1"; platform_elevate /bin/echo toc /dev/disk4' _ "$root/../load.sh" 2>&1 >/dev/null)
rc=$?
set -e
rm -f "$stub/da-nomount"
if [[ "$rc" -ne 0 ]] && grep -q 'could not put /dev/disk4s3 back' <<< "$err" && grep -q '^/bin/echo toc /dev/disk4$' "$stub/run-sudo.rec"; then
    ok elevate-restore-failure-is-fatal
else
    bad "elevate-restore-failure-is-fatal rc=$rc err=$err"
fi
# PFS Shell gets the drive on stdin; the sudo shim releases it anyway
printf '%s\n' "$want" > "$stub/da-state"
echo 1 > "$tree/pfs-calls"
: > "$diskutil_rec"
set +e
out=$(printf 'device /dev/disk4\nls\nexit\n' | PSBBN_DA_SETTLE=0 PSBBN_SUDO="$stub/run-sudo" PSBBN_MOUNT_TABLE="$stub/mount-table-opl" PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/sudo" "$tree/scripts/helper/fake/PFS Shell.elf" 2>&1)
rc=$?
set -e
if [[ "$rc" -eq 0 ]] && grep -q '149GiB' <<< "$out" && grep -q "^unmount $want$" "$diskutil_rec" && grep -q "^mount -mountPoint $want /dev/disk4s3$" "$diskutil_rec" && [[ "$(cat "$stub/da-state")" == "$want" ]]; then
    ok sudo-pfs-shell-releases-opl
else
    bad "sudo-pfs-shell-releases-opl rc=$rc out=$out state=$(cat "$stub/da-state") $(cat "$diskutil_rec")"
fi
: > "$stub/da-state"
rm -rf "${tree:?}"

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
"$bin/sfdisk" /dev/disk0 </dev/null >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] && ok sfdisk-refuse || bad sfdisk-refuse

"$bin/partprobe" "$img" && ok partprobe || bad partprobe
sectors=$("$bin/blockdev" --getsz "$img")
[[ "$sectors" == 163840 ]] && ok blockdev || bad "blockdev $sectors"

python3 - "$fix" << 'PY'
import plistlib, sys
d = sys.argv[1]
def dump(path, obj):
    with open(path, "wb") as fh:
        plistlib.dump(obj, fh)
dump(f"{d}/ext.plist", {"Internal": False, "Size": 160041885696, "TotalSize": 160041885696})
dump(f"{d}/int.plist", {"Internal": True, "Size": 1000, "TotalSize": 1000})
PY
cat > "$fix/diskutil-kind" << EOF
#!/bin/bash
if [[ "\$1" == info && "\$3" == disk5 ]]; then cat "$fix/ext.plist"; exit 0; fi
if [[ "\$1" == info && "\$3" == disk0 ]]; then cat "$fix/int.plist"; exit 0; fi
exit 1
EOF
chmod +x "$fix/diskutil-kind"
if PSBBN_DISKUTIL="$fix/diskutil-kind" "$bin/wipefs" -a /dev/disk5; then
    ok wipefs-external
else
    bad wipefs-external
fi
set +e
PSBBN_DISKUTIL="$fix/diskutil-kind" "$bin/wipefs" -a /dev/disk0 >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] && ok wipefs-internal || bad "wipefs-internal $rc"
sectors=$(PSBBN_DISKUTIL="$fix/diskutil-kind" "$bin/blockdev" --getsz /dev/disk5)
[[ "$sectors" == 312581808 ]] && ok blockdev-disk5 || bad "blockdev-disk5 $sectors"
set +e
PSBBN_DISKUTIL="$fix/diskutil-kind" "$bin/mke2fs" /dev/disk0 >/dev/null 2>&1
rc=$?
PSBBN_DISKUTIL="$fix/diskutil-kind" "$bin/mkfs.vfat" /dev/disk0 >/dev/null 2>&1
rc2=$?
set -e
[[ "$rc" -ne 0 && "$rc2" -ne 0 ]] && ok mkfs-refuse || bad mkfs-refuse

cat > "$stub/mount" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$stub/mount"
# A partition node never reaches /sbin/mount (see mount-exfat-node below);
# anything else is passed through with its arguments intact.
mout=$(PSBBN_REAL_MOUNT="$stub/mount" "$bin/mount" -t nfs host:/export /tmp/opl)
if grep -q 'host:/export' <<< "$mout" && grep -q -- '-t' <<< "$mout"; then ok mount-passthrough; else bad "mount-passthrough $mout"; fi
set +e
PSBBN_REAL_MOUNT="$stub/mount" "$bin/mount" /dev/disk0 /tmp/opl >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] && ok mount-refuses-whole-disk || bad "mount-refuses-whole-disk rc=$rc"

printf '%s\n' '/dev/disk4s3 on /tmp/psbbn-storage/__system (exfat, local)' > "$stub/mounts"
found=$(PSBBN_MOUNT_FILE="$stub/mounts" "$bin/findmnt" -nr -o TARGET)
[[ "$found" == /tmp/psbbn-storage/__system ]] && ok findmnt || bad "findmnt $found"

set +e
refuse=$("$root/../../helper/darwin-arm64/mkfs.exfat" -c 32K -L OPL /dev/disk03 2>&1)
rc=$?
set -e
[[ "$rc" -eq 2 && "$refuse" == *"internal"* ]] && ok mkfs-exfat-refuse-internal || bad "mkfs-exfat-refuse-internal rc=$rc $refuse"
set +e
refuse=$(PSBBN_DISKUTIL="$stub/diskutil-mount" "$root/../../helper/darwin-arm64/mkfs.exfat" -c 32K -L OPL /dev/disk5 2>&1)
rc=$?
set -e
[[ "$rc" -eq 2 && "$refuse" == *"whole disk"* ]] && ok mkfs-exfat-refuse-whole || bad "mkfs-exfat-refuse-whole rc=$rc $refuse"
stub_newfs=$(mktemp)
cat > "$stub_newfs" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$stub_newfs"
recorded=$(PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_NEWFS_EXFAT="$stub_newfs" "$root/../../helper/darwin-arm64/mkfs.exfat" -c 32K -L OPL /dev/disk43)
if grep -q -- '-R' <<< "$recorded" && grep -q -- '-b' <<< "$recorded" && grep -q 32768 <<< "$recorded" && grep -q /dev/disk4s3 <<< "$recorded"; then
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
. "$root/lib.sh"
build_overlay "$repo" "$overlay"
rm "$overlay/scripts/assets/lang/sample.txt"
if [[ -f "$repo/scripts/assets/lang/sample.txt" ]]; then ok overlay-rm; else bad overlay-rm; fi
if [[ "$(cat "$overlay/scripts/helper/aarch64/cue2pops")" == macho ]]; then ok overlay-helper; else bad overlay-helper; fi

for tool in uname sudo blkid ldconfig lvm dmsetup sfdisk partprobe blockdev wipefs mount umount findmnt mkfs.vfat mke2fs timeout unrar-free mount.exfat-fuse lsblk sed; do
    if [[ -x "$bin/$tool" ]]; then ok "exec-$tool"; else bad "exec-$tool"; fi
done

rm -rf "$stub" "$fix" "$state" "$img" "$repo" "$overlay" "$marker"
linux_uname=$(mktemp -d)
cat > "$linux_uname/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == -s ]]; then echo Linux; else /usr/bin/uname "$@"; fi
EOF
chmod +x "$linux_uname/uname"
linux_prefix=$(PATH="$linux_uname:$PATH" /opt/homebrew/bin/bash -c '. "'"$root/../load.sh"'"; platform_mapper_prefix disk5')
[[ "$linux_prefix" == /dev/mapper/disk5- ]] && ok linux-mapper || bad "linux-mapper $linux_prefix"
darwin_prefix=$(/opt/homebrew/bin/bash -c 'export PSBBN_MAPPER_DIR="'"$stub"'/maps"; . "'"$root/../load.sh"'"; platform_mapper_prefix disk5')
[[ "$darwin_prefix" == "$stub/maps/disk5-" ]] && ok darwin-mapper || bad "darwin-mapper $darwin_prefix"

slice=$(mktemp)
dd if=/dev/zero of="$slice" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$slice" bs=1048576 count=8 >/dev/null
slice_state=$(mktemp -d)
printf '%s\n' "slice-__linux.1,,,rw,0 8192 linear $slice 2048" | PSBBN_DM_STATE="$slice_state" PSBBN_MAPPER_DIR="$stub/maps" "$bin/dmsetup" create --concise
if PSBBN_MAPPER_DIR="$stub/maps" "$bin/mke2fs" -t ext2 -b 4096 -I 128 "$stub/maps/slice-__linux.1"; then
    magic=$(python3 -c 'import os,struct,sys; p=sys.argv[1]; f=open(p,"rb"); f.seek(1024+56); print("%s %s" % (hex(struct.unpack("<H", f.read(2))[0]), os.path.getsize(p)))' "$stub/maps/slice-__linux.1")
    [[ "$magic" == "0xef53 4194304" ]] && ok slice-ext2 || bad "slice-ext2 $magic"
else
    bad slice-ext2-mke2fs
fi

# The slice file starts empty. mount reads the formatted window off the
# backing image and shows it as a directory. It must not start fuse2fs.
copy_fs=$(mktemp)
dd if=/dev/zero of="$copy_fs" bs=512 count=16384 status=none 2>/dev/null || dd if=/dev/zero of="$copy_fs" bs=512 count=16384 >/dev/null
/opt/homebrew/opt/e2fsprogs/sbin/mke2fs -t ext2 -b 4096 -I 128 -F "$copy_fs" >/dev/null
printf 'copied-marker\n' > "$stub/marker.txt"
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R "write $stub/marker.txt marker.txt" "$copy_fs" >/dev/null
copy_img=$(mktemp)
dd if=/dev/zero of="$copy_img" bs=512 count=$((2048 + 16384)) status=none 2>/dev/null || dd if=/dev/zero of="$copy_img" bs=512 count=$((2048 + 16384)) >/dev/null
dd if="$copy_fs" of="$copy_img" bs=512 seek=2048 conv=notrunc status=none 2>/dev/null || dd if="$copy_fs" of="$copy_img" bs=512 seek=2048 conv=notrunc >/dev/null
copy_state=$(mktemp -d)
copy_maps=$(mktemp -d)
printf '%s\n' "copy-__linux.1,,,rw,0 16384 linear $copy_img 2048" | PSBBN_DM_STATE="$copy_state" PSBBN_MAPPER_DIR="$copy_maps" "$bin/dmsetup" create --concise
copy_slice="$copy_maps/copy-__linux.1"
copy_fuse_flag=$(mktemp)
rm -f "$copy_fuse_flag"
cat > "$stub/fuse2fs" << EOF
#!/bin/bash
touch "$copy_fuse_flag"
exit 99
EOF
chmod +x "$stub/fuse2fs"
copy_mnt=$(mktemp -d)
if PSBBN_FUSE_BACKEND=nfs PSBBN_FUSE2FS="$stub/fuse2fs" PSBBN_MOUNT_STATE="$copy_state/mounts" "$bin/mount" "$copy_slice" "$copy_mnt"; then
    if cmp -s "$copy_slice" "$copy_fs" && [[ "$(cat "$copy_mnt/marker.txt" 2>/dev/null)" == "copied-marker" ]]; then
        ok slice-mount-copies
    else
        bad "slice-mount-copies marker=$(cat "$copy_mnt/marker.txt" 2>/dev/null)"
    fi
    if [[ ! -e "$copy_fuse_flag" ]]; then
        ok mount-not-nfs
        ok mount-backend-refuses-nfs
    else
        bad mount-not-nfs
        bad mount-backend-refuses-nfs
    fi
else
    bad slice-mount-copies
    bad mount-not-nfs
    bad mount-backend-refuses-nfs
fi

vfat_file=$(mktemp)
dd if=/dev/zero of="$vfat_file" bs=1048576 count=64 status=none 2>/dev/null || dd if=/dev/zero of="$vfat_file" bs=1048576 count=64 >/dev/null
if "$bin/mkfs.vfat" -F 32 "$vfat_file"; then
    vfat_kind=$(psbbn_slice_kind "$vfat_file")
    [[ "$vfat_kind" == vfat ]] && ok mkfs-vfat-file || bad "mkfs-vfat-file $vfat_kind"
else
    bad mkfs-vfat-file
fi

vfat_poison=$(mktemp)
dd if=/dev/zero of="$vfat_poison" bs=512 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$vfat_poison" bs=512 count=8 >/dev/null
printf 'POISONPOISON\n' > "$vfat_poison"
printf 'device=%s\nstart=0\nsectors=131072\n' "$vfat_poison" > "$vfat_file.meta"
vfat_record=$(mktemp)
vfat_state=$(mktemp -d)
cat > "$stub/image-tool" << EOF
#!/bin/bash
printf '%s\n' "\$@" >> "$vfat_record"
if [[ "\$1" == image && "\$2" == attach ]]; then
    cat << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>system-entities</key><array><dict>
<key>dev-entry</key><string>disk9</string>
</dict></array></dict></plist>
PLIST
    exit 0
fi
exit 0
EOF
chmod +x "$stub/image-tool"
vfat_mnt=$(mktemp -d)
vfat_fuse_flag=$(mktemp)
rm -f "$vfat_fuse_flag"
cat > "$stub/fuse2fs-should-not-run" << EOF
#!/bin/bash
touch "$vfat_fuse_flag"
exit 99
EOF
chmod +x "$stub/fuse2fs-should-not-run"
if PSBBN_FUSE2FS="$stub/fuse2fs-should-not-run" PSBBN_IMAGE_TOOL="$stub/image-tool" PSBBN_MOUNT_STATE="$vfat_state" "$bin/mount" "$vfat_file" "$vfat_mnt"; then
    printf 'song\n' > "$vfat_mnt/song.txt"
    vfat_kind=$(psbbn_slice_kind "$vfat_file")
    if [[ "$vfat_kind" == vfat ]] && [[ ! -f "$vfat_fuse_flag" ]] && [[ ! -s "$vfat_record" ]]; then
        ok slice-mount-vfat
    else
        bad "slice-mount-vfat kind=$vfat_kind record=$(cat "$vfat_record" 2>/dev/null)"
    fi
else
    bad slice-mount-vfat
fi
if PSBBN_REAL_UMOUNT=/usr/bin/true PSBBN_IMAGE_TOOL="$stub/image-tool" PSBBN_MOUNT_STATE="$vfat_state" "$bin/umount" "$vfat_mnt"; then
    poison=$(dd if="$vfat_poison" bs=1 count=1 2>/dev/null)
    vfat_back=$(mktemp)
    mcopy -i "$vfat_file" ::song.txt "$vfat_back" 2>/dev/null
    if [[ ! -s "$vfat_record" ]] && [[ "$poison" == $'\xeb' ]] && [[ "$(cat "$vfat_back" 2>/dev/null)" == "song" ]]; then
        ok slice-umount-vfat
    else
        bad "slice-umount-vfat poison=$(printf %q "$poison") song=$(cat "$vfat_back" 2>/dev/null) record=$(cat "$vfat_record" 2>/dev/null)"
    fi
else
    bad slice-umount-vfat
fi

blank=$(mktemp)
dd if=/dev/zero of="$blank" bs=512 count=1 status=none 2>/dev/null || dd if=/dev/zero of="$blank" bs=512 count=1 >/dev/null
printf 'device=/dev/disk0\nstart=0\nsectors=1\n' > "$blank.meta"
dd_flag=$(mktemp)
rm -f "$dd_flag"
cat > "$stub/dd-flag" << EOF
#!/bin/bash
touch "$dd_flag"
exit 99
EOF
chmod +x "$stub/dd-flag"
blank_mnt=$(mktemp -d)
set +e
PSBBN_DD="$stub/dd-flag" "$bin/mount" "$blank" "$blank_mnt" >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -eq 2 && ! -e "$dd_flag" ]]; then
    ok mount-refuse-internal
else
    bad "mount-refuse-internal rc=$rc"
fi

int_slice=$(mktemp)
dd if=/dev/zero of="$int_slice" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$int_slice" bs=1048576 count=8 >/dev/null
/opt/homebrew/opt/e2fsprogs/sbin/mke2fs -t ext2 -b 4096 -I 128 -F "$int_slice" >/dev/null
printf 'device=/dev/disk0\nstart=0\nsectors=16384\n' > "$int_slice.meta"
int_mnt=$(mktemp -d)
int_state=$(mktemp -d)
if PSBBN_FUSE2FS="$stub/fuse2fs" PSBBN_DD="$stub/dd-flag" PSBBN_MOUNT_STATE="$int_state" "$bin/mount" "$int_slice" "$int_mnt"; then
    set +e
    PSBBN_REAL_UMOUNT=/usr/bin/true PSBBN_DD="$stub/dd-flag" PSBBN_MOUNT_STATE="$int_state" "$bin/umount" "$int_mnt" >/dev/null 2>&1
    rc=$?
    set -e
    if [[ "$rc" -eq 2 && ! -e "$dd_flag" ]]; then
        ok umount-refuse-internal
    else
        bad "umount-refuse-internal rc=$rc"
    fi
else
    bad umount-refuse-internal-mount
fi

# macOS 27 panics when installer writes go through FUSE-T or a disk image.
# mount keeps the files in a normal directory. umount writes that directory
# into the slice. fuse2fs must not run.
stage_fuse_flag=$(mktemp)
rm -f "$stage_fuse_flag"
cat > "$stub/stage-fuse" << EOF
#!/bin/bash
touch "$stage_fuse_flag"
printf '%s\n' "\$@" > "$stub/stage-fuse-args"
exit 99
EOF
chmod +x "$stub/stage-fuse"
stage_fs=$(mktemp)
dd if=/dev/zero of="$stage_fs" bs=512 count=16384 status=none 2>/dev/null || dd if=/dev/zero of="$stage_fs" bs=512 count=16384 >/dev/null
/opt/homebrew/opt/e2fsprogs/sbin/mke2fs -t ext2 -b 4096 -I 128 -F "$stage_fs" >/dev/null
stage_img=$(mktemp)
dd if=/dev/zero of="$stage_img" bs=512 count=$((2048 + 16384)) status=none 2>/dev/null || dd if=/dev/zero of="$stage_img" bs=512 count=$((2048 + 16384)) >/dev/null
dd if="$stage_fs" of="$stage_img" bs=512 seek=2048 conv=notrunc status=none 2>/dev/null || dd if="$stage_fs" of="$stage_img" bs=512 seek=2048 conv=notrunc >/dev/null
stage_dm=$(mktemp -d)
stage_maps=$(mktemp -d)
printf '%s\n' "stage-__linux.1,,,rw,0 16384 linear $stage_img 2048" | PSBBN_DM_STATE="$stage_dm" PSBBN_MAPPER_DIR="$stage_maps" "$bin/dmsetup" create --concise
stage_slice="$stage_maps/stage-__linux.1"
stage_mnt=$(mktemp -d)
stage_state=$(mktemp -d)
if PSBBN_FUSE2FS="$stub/stage-fuse" PSBBN_MOUNT_STATE="$stage_state" "$bin/mount" "$stage_slice" "$stage_mnt"; then
    if [[ ! -e "$stage_fuse_flag" ]]; then
        ok stage-no-fuse
    else
        bad "stage-no-fuse args=$(cat "$stub/stage-fuse-args" 2>/dev/null)"
    fi
    COPYFILE_DISABLE=1 /bin/bash -c 'mkdir -p "$1/sub"; echo live-proof > "$1/proof.txt"; echo nested > "$1/sub/nested.txt"; ln -s proof.txt "$1/sub/link.txt"' _ "$stage_mnt"
    if PSBBN_MOUNT_STATE="$stage_state" "$bin/umount" "$stage_mnt"; then
        dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
        got=$("$dbg" -R 'cat proof.txt' "$stage_slice" 2>/dev/null || true)
        nested=$("$dbg" -R 'cat sub/nested.txt' "$stage_slice" 2>/dev/null || true)
        link=$("$dbg" -R 'stat sub/link.txt' "$stage_slice" 2>/dev/null || true)
        stage_back=$(mktemp)
        dd if="$stage_img" of="$stage_back" bs=512 skip=2048 count=16384 status=none 2>/dev/null || dd if="$stage_img" of="$stage_back" bs=512 skip=2048 count=16384 >/dev/null
        got2=$("$dbg" -R 'cat proof.txt' "$stage_back" 2>/dev/null || true)
        if [[ "$got" == *live-proof* && "$nested" == *nested* && "$got2" == *live-proof* && "$link" == *'Fast link dest: "proof.txt"'* ]]; then
            ok stage-ext2-roundtrip
        else
            bad "stage-ext2-roundtrip slice=$(printf %q "$got") nested=$(printf %q "$nested") image=$(printf %q "$got2") link=$(printf %q "$link")"
        fi
    else
        bad stage-ext2-umount
    fi
else
    bad stage-no-fuse
    bad stage-ext2-roundtrip
fi

ext2_file=$(mktemp)
dd if=/dev/zero of="$ext2_file" bs=1048576 count=16 status=none 2>/dev/null || dd if=/dev/zero of="$ext2_file" bs=1048576 count=16 >/dev/null
if psbbn_format_ext2_file "$ext2_file" >/dev/null; then
    ext2_info=$(python3 -c 'import struct,sys; f=open(sys.argv[1],"rb"); f.seek(1024); sb=f.read(128); magic,inode=struct.unpack_from("<H", sb, 56)[0], struct.unpack_from("<H", sb, 88)[0]; print("%s %s" % (hex(magic), inode))' "$ext2_file")
    [[ "$ext2_info" == "0xef53 128" ]] && ok format-ext2 || bad "format-ext2 $ext2_info"
else
    bad format-ext2
fi
swap_file=$(mktemp)
dd if=/dev/zero of="$swap_file" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$swap_file" bs=1048576 count=8 >/dev/null
if psbbn_format_swap_file "$swap_file"; then
    swap_sig=$(python3 -c 'import struct,sys; f=open(sys.argv[1],"rb"); f.seek(1024); ver=struct.unpack("<I", f.read(4))[0]; f.seek(4086); print("%s %s" % (ver, f.read(10)))' "$swap_file")
    [[ "$swap_sig" == "1 b'SWAPSPACE2'" ]] && ok format-swap || bad "format-swap $swap_sig"
else
    bad format-swap
fi

pass_dir=$(mktemp -d)
echo hi > "$pass_dir/hi.txt"
/usr/bin/tar -cf "$pass_dir/a.tar" -C "$pass_dir" hi.txt
pass_rec=$(mktemp)
cat > "$stub/real-tar" << EOF
#!/bin/bash
printf '%s\n' "\$@" > "$pass_rec"
exit 99
EOF
chmod +x "$stub/real-tar"
set +e
PSBBN_REAL_TAR="$stub/real-tar" PSBBN_MOUNT_STATE="$pass_dir/nomounts" "$bin/tar" zxpf "$pass_dir/a.tar" -C "$pass_dir/out"
pass_rc=$?
set -e
if [[ "$pass_rc" -eq 99 ]] && grep -q "$pass_dir/a.tar" "$pass_rec"; then
    ok tar-passthrough
else
    bad "tar-passthrough rc=$pass_rc rec=$(cat "$pass_rec" 2>/dev/null)"
fi

tar_slice=$(mktemp)
dd if=/dev/zero of="$tar_slice" bs=1048576 count=16 status=none 2>/dev/null || dd if=/dev/zero of="$tar_slice" bs=1048576 count=16 >/dev/null
if ! psbbn_format_ext2_file "$tar_slice" >/dev/null; then
    bad tar-ext2-format
else
    printf 'device=%s\nstart=0\nsectors=32768\n' "$tar_slice" > "$tar_slice.meta"
    tar_storage=$(mktemp -d)
    mkdir -p "$tar_storage/__linux.1"
    tar_state=$(mktemp -d)
    tar_archive=$(mktemp)
    python3 - "$tar_archive" << 'PY'
import io, sys, tarfile
archive = sys.argv[1]
def add_file(tf, name, data, mode, mtime):
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mode = mode
    info.uid = 0
    info.gid = 0
    info.mtime = mtime
    info.type = tarfile.REGTYPE
    tf.addfile(info, io.BytesIO(data))
def add_dir(tf, name):
    info = tarfile.TarInfo(name)
    info.type = tarfile.DIRTYPE
    info.mode = 0o755
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info)
def add_link(tf, name, target):
    info = tarfile.TarInfo(name)
    info.type = tarfile.SYMTYPE
    info.linkname = target
    info.mode = 0o777
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info)
with tarfile.open(archive, "w:gz") as tf:
    add_dir(tf, "__linux.1")
    add_dir(tf, "__linux.1/sub")
    add_file(tf, "__linux.1/sub/proof.txt", b"mac-proof\n", 0o640, 1700000000)
    add_file(tf, "__linux.1/sub/my file.txt", b"space-ok\n", 0o644, 1700000000)
    add_link(tf, "__linux.1/sub/link.txt", "proof.txt")
    info = tarfile.TarInfo("__linux.1/sub/proof-link.txt")
    info.type = tarfile.LNKTYPE
    info.linkname = "__linux.1/sub/proof.txt"
    info.mode = 0o640
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info)
    add_file(tf, "notes.txt", b"local-note\n", 0o644, 1700000000)
PY
    dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
    if ! PSBBN_MOUNT_STATE="$tar_state" "$bin/mount" "$tar_slice" "$tar_storage/__linux.1" >/tmp/psbbn-tar-mount.out 2>&1; then
        bad "tar-ext2-direct mount $(cat /tmp/psbbn-tar-mount.out 2>/dev/null)"
    else
        set +e
        PSBBN_MOUNT_STATE="$tar_state" "$bin/tar" zxpf "$tar_archive" -C "$tar_storage" >/tmp/psbbn-tar-test.out 2>&1
        tar_rc=$?
        set -e
        if [[ "$tar_rc" -eq 0 ]]; then
            PSBBN_MOUNT_STATE="$tar_state" "$bin/umount" "$tar_storage/__linux.1" >/tmp/psbbn-tar-umount.out 2>&1 || tar_rc=$?
        fi
        proof=$("$dbg" -R 'cat sub/proof.txt' "$tar_slice" 2>/dev/null || true)
        hard=$("$dbg" -R 'cat sub/proof-link.txt' "$tar_slice" 2>/dev/null || true)
        spaced=$("$dbg" -R 'cat "sub/my file.txt"' "$tar_slice" 2>/dev/null || true)
        proof_stat=$("$dbg" -R 'stat sub/proof.txt' "$tar_slice" 2>/dev/null || true)
        link_stat=$("$dbg" -R 'stat sub/link.txt' "$tar_slice" 2>/dev/null || true)
        owned=$(python3 -c 'import re,sys; t=sys.stdin.read(); m=re.search(r"User:\s+(\d+)\s+Group:\s+(\d+)", t); sys.stdout.write("yes" if m and m.group(1)=="0" and m.group(2)=="0" and ("Mode:  0640" in t or "Mode: 0640" in t) else "no "+t)' <<<"$proof_stat")
        if [[ "$tar_rc" -eq 0 && "$proof" == *mac-proof* && "$hard" == *mac-proof* && "$spaced" == *space-ok* && "$owned" == yes && "$link_stat" == *'Fast link dest: "proof.txt"'* && "$(cat "$tar_storage/notes.txt" 2>/dev/null)" == "local-note" ]]; then
            ok tar-ext2-direct
        else
            bad "tar-ext2-direct rc=$tar_rc proof=$(printf %q "$proof") hard=$(printf %q "$hard") spaced=$(printf %q "$spaced") owned=$(printf %q "$owned") link=$(printf %q "$link_stat") notes=$(printf %q "$(cat "$tar_storage/notes.txt" 2>/dev/null)") out=$(printf %q "$(cat /tmp/psbbn-tar-test.out /tmp/psbbn-tar-umount.out 2>/dev/null)")"
        fi
    fi

    direct_slice=$(mktemp)
    dd if=/dev/zero of="$direct_slice" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$direct_slice" bs=1048576 count=8 >/dev/null
    psbbn_format_ext2_file "$direct_slice" >/dev/null
    printf 'device=%s\nstart=0\nsectors=16384\n' "$direct_slice" > "$direct_slice.meta"
    direct_mnt=$(mktemp -d)
    direct_state=$(mktemp -d)
    direct_archive=$(mktemp)
    python3 - "$direct_archive" << 'PY'
import io, sys, tarfile
info = tarfile.TarInfo("boot.txt")
data = b"linux3\n"
info.size = len(data)
info.mode = 0o644
info.uid = 0
info.gid = 0
info.mtime = 1700000000
with tarfile.open(sys.argv[1], "w:gz") as tf:
    tf.addfile(info, io.BytesIO(data))
PY
    direct_rc=0
    PSBBN_MOUNT_STATE="$direct_state" "$bin/mount" "$direct_slice" "$direct_mnt" >/tmp/psbbn-tar-direct.out 2>&1 || direct_rc=$?
    if [[ "$direct_rc" -eq 0 ]]; then
        PSBBN_MOUNT_STATE="$direct_state" "$bin/tar" zxpf "$direct_archive" -C "$direct_mnt" >>/tmp/psbbn-tar-direct.out 2>&1 || direct_rc=$?
    fi
    if [[ "$direct_rc" -eq 0 ]]; then
        PSBBN_MOUNT_STATE="$direct_state" "$bin/umount" "$direct_mnt" >>/tmp/psbbn-tar-direct.out 2>&1 || direct_rc=$?
    fi
    boot=$("$dbg" -R 'cat boot.txt' "$direct_slice" 2>/dev/null || true)
    if [[ "$direct_rc" -eq 0 && "$boot" == *linux3* ]]; then
        ok tar-ext2-one-mount
    else
        bad "tar-ext2-one-mount rc=$direct_rc boot=$(printf %q "$boot") out=$(printf %q "$(cat /tmp/psbbn-tar-direct.out 2>/dev/null)")"
    fi
fi

# The patch stores device nodes and both casings of terminfo names in ext2.
# APFS cannot. The image must keep them, including after a later file is
# added through the directory and the partition is unmounted.
node_slice=$(mktemp)
dd if=/dev/zero of="$node_slice" bs=1048576 count=16 status=none 2>/dev/null || dd if=/dev/zero of="$node_slice" bs=1048576 count=16 >/dev/null
psbbn_format_ext2_file "$node_slice" >/dev/null
printf 'device=%s\nstart=0\nsectors=32768\n' "$node_slice" > "$node_slice.meta"
node_storage=$(mktemp -d)
mkdir -p "$node_storage/__linux.1"
node_state=$(mktemp -d)
node_archive=$(mktemp)
python3 - "$node_archive" << 'PY'
import io, sys, tarfile
archive = sys.argv[1]
def add_dir(tf, name):
    info = tarfile.TarInfo(name)
    info.type = tarfile.DIRTYPE
    info.mode = 0o755
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info)
def add_special(tf, name, kind, mode, major, minor):
    info = tarfile.TarInfo(name)
    info.type = kind
    info.mode = mode
    info.devmajor = major
    info.devminor = minor
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info)
with tarfile.open(archive, "w:gz") as tf:
    add_dir(tf, "__linux.1")
    add_dir(tf, "__linux.1/dev")
    add_special(tf, "__linux.1/dev/null", tarfile.CHRTYPE, 0o666, 1, 3)
    add_special(tf, "__linux.1/dev/sda", tarfile.BLKTYPE, 0o660, 8, 0)
    add_special(tf, "__linux.1/dev/initctl", tarfile.FIFOTYPE, 0o600, 0, 0)
    add_dir(tf, "__linux.1/usr")
    add_dir(tf, "__linux.1/usr/share")
    add_dir(tf, "__linux.1/usr/share/terminfo")
    add_dir(tf, "__linux.1/usr/share/terminfo/P")
    add_dir(tf, "__linux.1/usr/share/terminfo/p")
    info = tarfile.TarInfo("__linux.1/usr/share/terminfo/P/P4")
    data = b"UPPER\n"
    info.size = len(data)
    info.mode = 0o644
    info.uid = 0
    info.gid = 0
    info.mtime = 1700000000
    tf.addfile(info, io.BytesIO(data))
    link = tarfile.TarInfo("__linux.1/usr/share/terminfo/p/prism4")
    link.type = tarfile.LNKTYPE
    link.linkname = "__linux.1/usr/share/terminfo/P/P4"
    link.mode = 0o644
    link.uid = 0
    link.gid = 0
    link.mtime = 1700000000
    tf.addfile(link)
    add_dir(tf, "__linux.1/bin")
    sh = tarfile.TarInfo("__linux.1/bin/sh")
    sh.type = tarfile.SYMTYPE
    sh.linkname = "bash"
    sh.mode = 0o777
    sh.uid = 0
    sh.gid = 0
    sh.mtime = 1700000000
    tf.addfile(sh)
PY
node_rc=0
PSBBN_MOUNT_STATE="$node_state" "$bin/mount" "$node_slice" "$node_storage/__linux.1" >/tmp/psbbn-node-mount.out 2>&1 || node_rc=$?
if [[ "$node_rc" -eq 0 ]]; then
    PSBBN_MOUNT_STATE="$node_state" "$bin/tar" zxpf "$node_archive" -C "$node_storage" >/tmp/psbbn-node-tar.out 2>&1 || node_rc=$?
fi
node_dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
null_stat=$("$node_dbg" -R 'stat dev/null' "$node_slice" 2>/dev/null || true)
sda_stat=$("$node_dbg" -R 'stat dev/sda' "$node_slice" 2>/dev/null || true)
fifo_stat=$("$node_dbg" -R 'stat dev/initctl' "$node_slice" 2>/dev/null || true)
upper=$("$node_dbg" -R 'cat usr/share/terminfo/P/P4' "$node_slice" 2>/dev/null || true)
lower=$("$node_dbg" -R 'cat usr/share/terminfo/p/prism4' "$node_slice" 2>/dev/null || true)
sh_stat=$("$node_dbg" -R 'stat bin/sh' "$node_slice" 2>/dev/null || true)
printf 'kept\n' > "$node_storage/__linux.1/note.txt"
if [[ "$node_rc" -eq 0 ]]; then
    PSBBN_MOUNT_STATE="$node_state" "$bin/umount" "$node_storage/__linux.1" >/tmp/psbbn-node-umount.out 2>&1 || node_rc=$?
fi
null_after=$("$node_dbg" -R 'stat dev/null' "$node_slice" 2>/dev/null || true)
note=$("$node_dbg" -R 'cat note.txt' "$node_slice" 2>/dev/null || true)
if [[ "$node_rc" -eq 0 \
    && "$null_stat" == *"character special"* && "$null_stat" == *"01:03"* \
    && "$sda_stat" == *"block special"* && "$sda_stat" == *"08:00"* \
    && "$fifo_stat" == *"FIFO"* \
    && "$upper" == *"UPPER"* && "$lower" == *"UPPER"* \
    && "$sh_stat" == *'Fast link dest: "bash"'* \
    && "$null_after" == *"character special"* && "$note" == *"kept"* ]]; then
    ok tar-ext2-devices
else
    bad "tar-ext2-devices rc=$node_rc null=$(printf %q "$null_stat") sda=$(printf %q "$sda_stat") fifo=$(printf %q "$fifo_stat") upper=$(printf %q "$upper") lower=$(printf %q "$lower") sh=$(printf %q "$sh_stat") after=$(printf %q "$null_after") note=$(printf %q "$note") tar=$(printf %q "$(cat /tmp/psbbn-node-tar.out 2>/dev/null)") umount=$(printf %q "$(cat /tmp/psbbn-node-umount.out 2>/dev/null)")"
fi

pfs_img="$stub/pfs.img"
/usr/sbin/mkfile -n 512m "$pfs_img"
pfs_bin="$root/../../helper/darwin-arm64/pfsshell"
printf 'device %s\ninitialize yes\nmkpart __system 128M PFS\nmkpart __contents 128M PFS\nexit\n' "$pfs_img" | "$pfs_bin" >/tmp/psbbn-pfs-init.out 2>&1 || true
pfs_mnt=$(mktemp -d)
pfs_state=$(mktemp -d)
pfs_fuse_flag=$(mktemp)
rm -f "$pfs_fuse_flag"
cat > "$stub/pfs-real" << EOF
#!/bin/bash
touch "$pfs_fuse_flag"
exit 99
EOF
chmod +x "$stub/pfs-real"
if PSBBN_PFS_FUSE="$stub/pfs-real" PSBBN_MOUNT_STATE="$pfs_state" \
    "$bin/pfs-fuse" -o allow_other --partition=__system "$pfs_img" "$pfs_mnt/"; then
    pfs_key=$(psbbn_mount_key "$pfs_mnt")
    printf 'pfs-proof\n' > "$pfs_mnt/hello.txt"
    mkdir -p "$pfs_mnt/sub"
    printf 'nested\n' > "$pfs_mnt/sub/inside.txt"
    printf 'space name\n' > "$pfs_mnt/my file.txt"
    if [[ ! -e "$pfs_fuse_flag" ]] && [[ "$(cat "$pfs_state/$pfs_key.kind" 2>/dev/null)" == pfs ]] \
        && [[ "$(cat "$pfs_state/$pfs_key.part" 2>/dev/null)" == __system ]] \
        && PSBBN_MOUNT_STATE="$pfs_state" "$bin/umount" "$pfs_mnt" >/tmp/psbbn-pfs-umount.out 2>&1; then
        pfs_back=$(mktemp -d)
        printf 'device %s\nmount __system\nlcd %s\nget hello.txt\nget "my file.txt"\ncd sub\nlcd %s\nget inside.txt\numount\nexit\n' \
            "$pfs_img" "$pfs_back" "$pfs_back" | "$pfs_bin" >/tmp/psbbn-pfs-get.out 2>&1
        if [[ "$(cat "$pfs_back/hello.txt" 2>/dev/null)" == "pfs-proof" ]] \
            && [[ "$(cat "$pfs_back/inside.txt" 2>/dev/null)" == "nested" ]] \
            && [[ "$(cat "$pfs_back/my file.txt" 2>/dev/null)" == "space name" ]]; then
            ok pfs-userspace-roundtrip
        else
            bad "pfs-userspace-roundtrip $(find "$pfs_back" -type f -print -exec cat {} \; 2>/dev/null) $(cat /tmp/psbbn-pfs-get.out 2>/dev/null)"
        fi
    else
        bad "pfs-userspace-roundtrip flag=$([[ -e $pfs_fuse_flag ]] && echo set) kind=$(cat "$pfs_state/$pfs_key.kind" 2>/dev/null) umount=$(cat /tmp/psbbn-pfs-umount.out 2>/dev/null)"
    fi
else
    bad "pfs-userspace-roundtrip mount $(cat /tmp/psbbn-pfs-init.out 2>/dev/null)"
fi
pfs_link_tree=$(mktemp -d)
mkdir -p "$pfs_link_tree/scripts/helper/aarch64"
ln -s "$bin/pfs-fuse" "$pfs_link_tree/scripts/helper/aarch64/PFS Fuse.elf"
pfs_mnt2=$(mktemp -d)
pfs_state2=$(mktemp -d)
rm -f "$pfs_fuse_flag"
if PSBBN_PFS_FUSE="$stub/pfs-real" PSBBN_MOUNT_STATE="$pfs_state2" \
    "$pfs_link_tree/scripts/helper/aarch64/PFS Fuse.elf" -o allow_other --partition=__contents "$pfs_img" "$pfs_mnt2/" >/tmp/psbbn-pfs-link.out 2>&1; then
    pfs_key2=$(psbbn_mount_key "$pfs_mnt2")
    if [[ ! -e "$pfs_fuse_flag" ]] && [[ "$(cat "$pfs_state2/$pfs_key2.part" 2>/dev/null)" == __contents ]]; then
        ok pfs-via-helper-symlink
    else
        bad "pfs-via-helper-symlink part=$(cat "$pfs_state2/$pfs_key2.part" 2>/dev/null)"
    fi
    PSBBN_MOUNT_STATE="$pfs_state2" "$bin/umount" "$pfs_mnt2" >/dev/null 2>&1 || true
else
    bad "pfs-via-helper-symlink rc=$? out=$(cat /tmp/psbbn-pfs-link.out 2>/dev/null)"
fi
pfs_bad=$(mktemp)
printf 'x\n' > "$pfs_bad"
pfs_bad_mnt=$(mktemp -d)
set +e
PSBBN_MOUNT_STATE="$pfs_state" "$bin/pfs-fuse" -o allow_other --partition=__system "$pfs_bad" "$pfs_bad_mnt" >/tmp/psbbn-pfs-fail.out 2>&1
pfs_fail_rc=$?
set -e
if [[ "$pfs_fail_rc" -ne 0 ]] && grep -q 'did not mount' /tmp/psbbn-pfs-fail.out; then
    ok pfs-mount-fails-closed
else
    bad "pfs-mount-fails-closed rc=$pfs_fail_rc out=$(cat /tmp/psbbn-pfs-fail.out 2>/dev/null)"
fi

link_dest=$(mktemp -d)
mkdir -p "$link_dest/scripts/helper/aarch64"
psbbn_link_helpers "$root/../../.." "$link_dest"
link_got=$(readlink "$link_dest/scripts/helper/PFS Fuse.elf")
if [[ "$link_got" == "$root/bin/pfs-fuse" ]]; then
    ok pfs-wrapper-link
else
    bad "pfs-wrapper-link $link_got"
fi


# The fixtures below outlive the rm -rf of $stub/$fix above.
fix2=$(mktemp -d)
python3 - "$fix2" << 'PY2'
import plistlib, sys
d = sys.argv[1]
def dump(name, obj):
    with open(f"{d}/{name}.plist", "wb") as f:
        plistlib.dump(obj, f)
dump("disk4s3", {"Internal": False, "FilesystemType": "exfat", "MountPoint": "", "Size": 1 << 30, "TotalSize": 1 << 30})
dump("disk5s2", {"Internal": False, "Size": 16 * 1024 * 1024, "TotalSize": 16 * 1024 * 1024, "MountPoint": ""})
dump("disk5", {"Internal": False, "Size": 160041885696, "TotalSize": 160041885696})
dump("disk0", {"Internal": True, "Size": 1000, "TotalSize": 1000})
PY2
diskutil_rec=$(mktemp)
cat > "$fix2/diskutil" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$diskutil_rec"
case "\$1" in
    info) [[ -f "$fix2/\$3.plist" ]] && { cat "$fix2/\$3.plist"; exit 0; }; exit 1 ;;
    mount|unmount|unmountDisk) exit 0 ;;
esac
exit 1
EOF
chmod +x "$fix2/diskutil"
stub="$fix2"
marker=$(mktemp)
cat > "$stub/real-sudo" << EOF
#!/bin/bash
echo CALLED >> "$marker"
exit 0
EOF
chmod +x "$stub/real-sudo"
cp "$fix2/diskutil" "$stub/diskutil-mount"

# --- the elevate guard sees if=/of= arguments too ---------------------------
: > "$diskutil_rec"
set +e
guard_out=$(PSBBN_SUDO="$stub/real-sudo" PSBBN_DISKUTIL="$fix2/diskutil" "$bin/dd" if=/dev/zero of=/dev/disk0 bs=1 count=1 2>&1)
guard_rc=$?
set -e
if [[ "$guard_rc" -eq 2 && "$guard_out" == *internal* && ! -s "$marker" ]] && ! grep -q unmountDisk "$diskutil_rec"; then
    ok dd-refuses-internal
else
    bad "dd-refuses-internal rc=$guard_rc out=$guard_out diskutil=$(cat "$diskutil_rec")"
fi
set +e
guard_out=$(PSBBN_SUDO="$stub/real-sudo" PSBBN_DISKUTIL="$fix2/diskutil" /opt/homebrew/bin/bash -c '. "$1"; platform_elevate /bin/dd of=/dev/disk0 if=/dev/zero' _ "$root/../load.sh" 2>&1)
guard_rc=$?
set -e
[[ "$guard_rc" -eq 2 && ! -s "$marker" ]] && ok elevate-guard-of-arg || bad "elevate-guard-of-arg rc=$guard_rc"
set +e
guard_out=$(printf 'device /dev/disk0\ninitialize yes\nexit\n' | PSBBN_DISKUTIL="$fix2/diskutil" "$root/../../helper/darwin-arm64/PFS Shell.elf" 2>&1)
guard_rc=$?
set -e
[[ "$guard_rc" -eq 2 && "$guard_out" == *internal* ]] && ok pfsshell-refuses-internal || bad "pfsshell-refuses-internal rc=$guard_rc out=$guard_out"

# --- APA-Jail: sudo "$MKFS_EXFAT" -c 32K -L OPL ${DEVICE}3 through the real-sudo path
exfat_tree=$(mktemp -d)
mkdir -p "$exfat_tree/scripts/helper/aarch64"
ln -s "$root/../../helper/darwin-arm64/mkfs.exfat" "$exfat_tree/scripts/helper/aarch64/mkfs.exfat"
exfat_rec=$(mktemp)
cat > "$stub/elevate-exfat" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$exfat_rec"
exit 0
EOF
chmod +x "$stub/elevate-exfat"
set +e
exfat_err=$(PATH="$bin:/usr/bin:/bin" PSBBN_SUDO="$stub/elevate-exfat" PSBBN_DISKUTIL="$fix2/diskutil" "$bin/sudo" "$exfat_tree/scripts/helper/aarch64/mkfs.exfat" -c 32K -L OPL /dev/disk43 2>&1)
exfat_rc=$?
set -e
if [[ "$exfat_rc" -eq 0 && "$exfat_err" != *Refusing* ]] && grep -q 'mkfs.exfat -c 32K -L OPL /dev/disk43' "$exfat_rec"; then
    ok sudo-mkfs-exfat-device3
else
    bad "sudo-mkfs-exfat-device3 rc=$exfat_rc err=$exfat_err rec=$(cat "$exfat_rec")"
fi
set +e
exfat_err=$(PATH="$bin:/usr/bin:/bin" PSBBN_SUDO="$stub/elevate-exfat" PSBBN_DISKUTIL="$fix2/diskutil" "$bin/sudo" "$exfat_tree/scripts/helper/aarch64/mkfs.exfat" -c 32K -L OPL /dev/disk03 2>&1)
exfat_rc=$?
set -e
[[ "$exfat_rc" -eq 2 && "$exfat_err" == *internal* ]] && ok sudo-mkfs-exfat-internal || bad "sudo-mkfs-exfat-internal rc=$exfat_rc err=$exfat_err"

# --- sfdisk keeps the APA header that shares sector 0 ---------------------
apa_img=$(mktemp)
dd if=/dev/zero of="$apa_img" bs=1048576 count=80 status=none 2>/dev/null || dd if=/dev/zero of="$apa_img" bs=1048576 count=80 >/dev/null
python3 - "$apa_img" << 'PY2'
import sys
p = sys.argv[1]
with open(p, "r+b") as f:
    f.seek(0); f.write(bytes(range(1, 17)))              # checksum + "APA" area
    f.seek(224); f.write(b"APAJ-A2\0")                   # apajail signature
    f.seek(304); f.write(b"\x20\x00\x00\x00\x08\x00\x00\x00")  # bootstrap fields
    f.seek(439); f.write(b"\xa5")
PY2
printf '%s\n' ',10MiB,17' ',32MiB,17' ',,07' | "$bin/sfdisk" "$apa_img"
python3 - "$apa_img" << 'PY2'
import struct, sys
b = open(sys.argv[1], "rb").read(512)
assert b[0:16] == bytes(range(1, 17)), b[0:16]
assert b[224:232] == b"APAJ-A2\0", b[224:232]
assert b[304:312] == b"\x20\x00\x00\x00\x08\x00\x00\x00"
assert b[439] == 0xa5
assert b[444:446] == b"\0\0"
assert b[510:512] == b"\x55\xaa"
e0 = b[446:462]
assert e0[0] == 0 and e0[4] == 0x17
assert e0[1:4] == bytes((32, 33, 0)), e0[1:4]          # CHS of LBA 2048 at 255/63
assert struct.unpack_from("<II", e0, 8) == (2048, 10 * 2048)
e2 = b[478:494]
assert e2[4] == 0x07
start, count = struct.unpack_from("<II", e2, 8)
assert start == 2048 + 42 * 2048 and start + count == 80 * 2048, (start, count)
# 80 MiB fits inside CHS range, so the end CHS is a real value, not FE FF FF
print("apa-mbr-ok")
PY2
[[ $? -eq 0 ]] && ok sfdisk-preserves-apa || bad sfdisk-preserves-apa

# --- a record whose slice was deleted must not block later runs -----------
stale_state=$(mktemp -d)
stale_mnt=$(mktemp -d)
stale_key=$(psbbn_mount_key "$stale_mnt")
printf '%s\n' "$stale_state/no-such-slice" > "$stale_state/$stale_key"
printf 'ext2\n' > "$stale_state/$stale_key.kind"
printf '%s\n' "$stale_mnt" > "$stale_state/$stale_key.mount"
stale_err=$(PSBBN_MOUNT_STATE="$stale_state" "$bin/umount" "$stale_mnt" 2>&1)
stale_rc=$?
if [[ "$stale_rc" -eq 0 && ! -f "$stale_state/$stale_key" && "$stale_err" == *stale* ]]; then
    ok umount-stale-record
else
    bad "umount-stale-record rc=$stale_rc err=$stale_err"
fi
if [[ -z "$(PSBBN_MOUNT_STATE="$stale_state" "$bin/findmnt" -nr -o TARGET | grep -F "$stale_mnt")" ]]; then
    ok findmnt-after-stale
else
    bad findmnt-after-stale
fi
# The same record from the running session means the slice vanished under
# a live stage: the changes in the folder are lost, so umount must fail.
printf '%s\n' "$stale_state/no-such-slice" > "$stale_state/$stale_key"
printf 'ext2\n' > "$stale_state/$stale_key.kind"
printf '%s\n' "$stale_mnt" > "$stale_state/$stale_key.mount"
printf '4242\n' > "$stale_state/$stale_key.session"
set +e
stale_err=$(PSBBN_SESSION_PID=4242 PSBBN_MOUNT_STATE="$stale_state" "$bin/umount" "$stale_mnt" 2>&1)
stale_rc=$?
set -e
if [[ "$stale_rc" -eq 1 && -f "$stale_state/$stale_key" && "$stale_err" == *"vanished during this run"* ]]; then
    ok umount-vanished-slice-same-session-fails
else
    bad "umount-vanished-slice-same-session-fails rc=$stale_rc err=$stale_err"
fi
set +e
stale_err=$(PSBBN_SESSION_PID=1 PSBBN_MOUNT_STATE="$stale_state" "$bin/umount" "$stale_mnt" 2>&1)
stale_rc=$?
set -e
[[ "$stale_rc" -eq 0 && ! -f "$stale_state/$stale_key" ]] && ok umount-stale-record-other-session || bad "umount-stale-record-other-session rc=$stale_rc err=$stale_err"

# --- sudo runs a shim reached through the helper symlink as the user -------
sym_tree=$(mktemp -d)
mkdir -p "$sym_tree/scripts/helper/aarch64"
ln -s "$bin/pfs-fuse" "$sym_tree/scripts/helper/aarch64/PFS Fuse.elf"
: > "$marker"
if PATH="$bin:/usr/bin:/bin" PSBBN_REAL_SUDO="$stub/real-sudo" "$bin/sudo" "$sym_tree/scripts/helper/aarch64/PFS Fuse.elf" --psbbn-shim-ok && [[ ! -s "$marker" ]]; then
    ok sudo-symlinked-shim
else
    bad sudo-symlinked-shim
fi

# --- dd elevates reads of a disk node and quiesces whole-disk writes -------
elev_rec=$(mktemp)
cat > "$stub/elevate-record" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$elev_rec"
exit 0
EOF
chmod +x "$stub/elevate-record"
: > "$diskutil_rec"
PSBBN_SUDO="$stub/elevate-record" PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/dd" if=/dev/disk5 of="$stub/hdr.bin" bs=512 count=2
if grep -q '^/bin/dd if=/dev/disk5 of=' "$elev_rec"; then ok dd-elevates-read; else bad "dd-elevates-read $(cat "$elev_rec")"; fi
: > "$elev_rec"; : > "$diskutil_rec"
# Disk Arbitration has a volume of the drive under /Volumes: it is evicted,
# the whole disk is never unmounted wholesale (that would drop the
# installer's own OPL mount without putting it back).
printf '%s\n' '/dev/disk5s1 on /Volumes/PS2 (exfat, local, nodev, nosuid, noowners)' > "$elev_rec.table"
PSBBN_SUDO="$stub/elevate-record" PSBBN_MOUNT_TABLE="$elev_rec.table" PSBBN_DISKUTIL="$stub/diskutil-mount" "$bin/dd" if="$stub/hdr.bin" of=/dev/disk5 conv=notrunc
if grep -q '^/bin/dd if=.* of=/dev/disk5 conv=notrunc' "$elev_rec" && grep -q '^unmount /Volumes/PS2$' "$diskutil_rec" && ! grep -q unmountDisk "$diskutil_rec"; then
    ok dd-quiesces-whole-disk
else
    bad "dd-quiesces-whole-disk elev=$(cat "$elev_rec") diskutil=$(cat "$diskutil_rec")"
fi
: > "$elev_rec"
PSBBN_SUDO="$stub/elevate-record" "$bin/dd" if=/dev/zero of="$stub/plain.bin" bs=512 count=1 2>/dev/null
[[ ! -s "$elev_rec" && -s "$stub/plain.bin" ]] && ok dd-plain-no-sudo || bad dd-plain-no-sudo

# --- a real ext2 partition node is staged like a slice --------------------
node_back=$(mktemp)
dd if=/dev/zero of="$node_back" bs=1048576 count=16 status=none 2>/dev/null || dd if=/dev/zero of="$node_back" bs=1048576 count=16 >/dev/null
psbbn_format_ext2_file "$node_back" >/dev/null
printf 'recovery-marker\n' > "$stub/rec.txt"
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R "write $stub/rec.txt marker.txt" "$node_back" >/dev/null 2>&1
cat > "$stub/fake-dd" << EOF
#!/bin/bash
args=()
for a in "\$@"; do
    a=\${a//\/dev\/rdisk5s2/$node_back}
    args+=("\$a")
done
exec /bin/dd "\${args[@]}"
EOF
chmod +x "$stub/fake-dd"
cat > "$stub/elevate-exec" << 'EOF'
#!/bin/bash
exec "$@"
EOF
chmod +x "$stub/elevate-exec"
node_mnt=$(mktemp -d)
node_state=$(mktemp -d)
node_maps=$(mktemp -d)
if PSBBN_SUDO="$stub/elevate-exec" PSBBN_DD="$stub/fake-dd" PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_MOUNT_STATE="$node_state" PSBBN_MAPPER_DIR="$node_maps" \
    "$bin/mount" /dev/disk52 "$node_mnt" > "$stub/node-mount.out" 2>&1; then
    if [[ "$(cat "$node_mnt/marker.txt" 2>/dev/null)" == recovery-marker && -f "$node_maps/disk5s2.meta" ]] && grep -q 'node=1' "$node_maps/disk5s2.meta"; then
        ok mount-partition-node
    else
        bad "mount-partition-node marker=$(cat "$node_mnt/marker.txt" 2>/dev/null) meta=$(cat "$node_maps/disk5s2.meta" 2>/dev/null)"
    fi
    printf 'apa-index\n' > "$node_mnt/apa_index.xz"
    if PSBBN_SUDO="$stub/elevate-exec" PSBBN_DD="$stub/fake-dd" PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_MOUNT_STATE="$node_state" PSBBN_MAPPER_DIR="$node_maps" \
        "$bin/umount" -l "$node_mnt" > "$stub/node-umount.out" 2>&1; then
        back=$(/opt/homebrew/opt/e2fsprogs/sbin/debugfs -R 'cat apa_index.xz' "$node_back" 2>/dev/null)
        if [[ "$back" == apa-index && ! -e "$node_maps/disk5s2" && ! -e "$node_maps/disk5s2.meta" ]]; then
            ok umount-partition-node
        else
            bad "umount-partition-node back=$back leftovers=$(ls "$node_maps")"
        fi
    else
        bad "umount-partition-node $(cat "$stub/node-umount.out")"
    fi
else
    bad "mount-partition-node $(cat "$stub/node-mount.out")"
    bad umount-partition-node
fi

# --- unmount writes back only what changed since the snapshot -------------
dbg_rec=$(mktemp)
cat > "$stub/debugfs-record" << EOF
#!/bin/bash
# debugfs_apply feeds the script on stdin; keep a copy, then run the real tool.
if [[ "\$1" == -w && "\$2" == -f && "\$3" == /dev/stdin ]]; then
    tee -a "$dbg_rec" | exec /opt/homebrew/opt/e2fsprogs/sbin/debugfs "\$@"
fi
exec /opt/homebrew/opt/e2fsprogs/sbin/debugfs "\$@"
EOF
chmod +x "$stub/debugfs-record"
man_slice=$(mktemp)
dd if=/dev/zero of="$man_slice" bs=1048576 count=16 status=none 2>/dev/null || dd if=/dev/zero of="$man_slice" bs=1048576 count=16 >/dev/null
psbbn_format_ext2_file "$man_slice" >/dev/null
printf 'keep\n' > "$stub/keep.txt"
printf 'gone\n' > "$stub/gone.txt"
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R "mkdir olddir" "$man_slice" >/dev/null 2>&1
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R "write $stub/keep.txt keep.txt" "$man_slice" >/dev/null 2>&1
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R "write $stub/gone.txt olddir/gone.txt" "$man_slice" >/dev/null 2>&1
printf 'device=%s\nstart=0\nsectors=32768\n' "$man_slice" > "$man_slice.meta"
man_mnt=$(mktemp -d)
man_state=$(mktemp -d)
PSBBN_MOUNT_STATE="$man_state" "$bin/mount" "$man_slice" "$man_mnt" >/dev/null 2>&1 || bad manifest-mount
[[ -f "$man_state/$(psbbn_mount_key "$man_mnt").manifest" ]] && ok manifest-written || bad manifest-written
rm -rf "$man_mnt/olddir"
printf 'new\n' > "$man_mnt/new.txt"
: > "$dbg_rec"
if PSBBN_DEBUGFS="$stub/debugfs-record" PSBBN_MOUNT_STATE="$man_state" "$bin/umount" "$man_mnt" >/dev/null 2>&1; then
    if ! grep -q 'write .*keep.txt' "$dbg_rec" && grep -q 'write .*"/new.txt"' "$dbg_rec" && grep -q 'rm "/olddir/gone.txt"' "$dbg_rec" && grep -q 'rmdir "/olddir"' "$dbg_rec"; then
        ok manifest-diff-only
    else
        bad "manifest-diff-only script=$(cat "$dbg_rec")"
    fi
    dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
    if [[ "$("$dbg" -R 'cat keep.txt' "$man_slice" 2>/dev/null)" == keep && "$("$dbg" -R 'cat new.txt' "$man_slice" 2>/dev/null)" == new ]] \
        && "$dbg" -R 'stat olddir' "$man_slice" 2>&1 | grep -q 'File not found' \
        && /opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$man_slice" >/dev/null 2>&1; then
        ok manifest-image-state
    else
        bad "manifest-image-state $("$dbg" -R 'ls' "$man_slice" 2>/dev/null)"
    fi
else
    bad manifest-diff-only
    bad manifest-image-state
fi

# --- hard links into full directories (the terminfo failure) --------------
ln_slice=$(mktemp)
dd if=/dev/zero of="$ln_slice" bs=1048576 count=32 status=none 2>/dev/null || dd if=/dev/zero of="$ln_slice" bs=1048576 count=32 >/dev/null
psbbn_format_ext2_file "$ln_slice" >/dev/null
printf 'device=%s\nstart=0\nsectors=65536\n' "$ln_slice" > "$ln_slice.meta"
ln_storage=$(mktemp -d)
mkdir -p "$ln_storage/__linux.1"
ln_state=$(mktemp -d)
ln_archive=$(mktemp)
python3 - "$ln_archive" << 'PY2'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz") as tf:
    for name in ("__linux.1", "__linux.1/usr", "__linux.1/usr/share", "__linux.1/usr/share/terminfo", "__linux.1/usr/share/terminfo/x"):
        info = tarfile.TarInfo(name); info.type = tarfile.DIRTYPE; info.mode = 0o755; info.mtime = 1700000000
        tf.addfile(info)
    base = tarfile.TarInfo("__linux.1/usr/share/terminfo/x/xterm-old")
    data = b"terminfo\n"; base.size = len(data); base.mode = 0o644; base.mtime = 1700000000
    tf.addfile(base, io.BytesIO(data))
    for i in range(400):
        link = tarfile.TarInfo("__linux.1/usr/share/terminfo/x/xterm-alias-with-a-long-name-%03d" % i)
        link.type = tarfile.LNKTYPE; link.linkname = "__linux.1/usr/share/terminfo/x/xterm-old"; link.mode = 0o644; link.mtime = 1700000000
        tf.addfile(link)
PY2
ln_rc=0
PSBBN_MOUNT_STATE="$ln_state" "$bin/mount" "$ln_slice" "$ln_storage/__linux.1" >/dev/null 2>&1 || ln_rc=$?
[[ "$ln_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$ln_state" "$bin/tar" zxpf "$ln_archive" -C "$ln_storage" > "$stub/ln-tar.out" 2>&1 || ln_rc=$?; }
[[ "$ln_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$ln_state" "$bin/umount" "$ln_storage/__linux.1" > "$stub/ln-umount.out" 2>&1 || ln_rc=$?; }
dbg=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
ln_names=$("$dbg" -R 'ls usr/share/terminfo/x' "$ln_slice" 2>/dev/null | tr -s ' ' '\n' | grep -c xterm-alias)
ln_count=$("$dbg" -R 'stat usr/share/terminfo/x/xterm-old' "$ln_slice" 2>/dev/null | sed -n 's/.*Links: *\([0-9]*\).*/\1/p')
if [[ "$ln_rc" -eq 0 && "$ln_names" == 400 && "$ln_count" == 401 ]] && /opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$ln_slice" >/dev/null 2>&1; then
    ok tar-hardlinks-full-dir
else
    bad "tar-hardlinks-full-dir rc=$ln_rc names=$ln_names links=$ln_count out=$(cat "$stub/ln-tar.out" "$stub/ln-umount.out" 2>/dev/null | head -5)"
fi

# --- a real debugfs failure is reported briefly, not as a transcript ------
err_slice=$(mktemp)
dd if=/dev/zero of="$err_slice" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$err_slice" bs=1048576 count=8 >/dev/null
psbbn_format_ext2_file "$err_slice" >/dev/null
err_script=$(mktemp)
{ for i in $(seq 1 50); do echo "mkdir \"/d$i\""; done; echo 'write "/nonexistent/host/file" "/x"'; } > "$err_script"
set +e
err_out=$(psbbn_debugfs_apply "$err_script" "$err_slice" 2>&1)
err_rc=$?
set -e
if [[ "$err_rc" -ne 0 && "$(wc -l <<<"$err_out")" -lt 8 && "$err_out" == *nonexistent* ]]; then
    ok debugfs-apply-brief-errors
else
    bad "debugfs-apply-brief-errors rc=$err_rc lines=$(wc -l <<<"$err_out")"
fi

# --- mkdir on an existing directory must not leave a zombie inode ---------
zb_img=$(mktemp)
dd if=/dev/zero of="$zb_img" bs=1048576 count=8 status=none 2>/dev/null || dd if=/dev/zero of="$zb_img" bs=1048576 count=8 >/dev/null
psbbn_format_ext2_file "$zb_img" >/dev/null
zb_script=$(mktemp)
printf 'mkdir "/bn"\nmkdir "/bn/data"\n' > "$zb_script"
psbbn_debugfs_apply "$zb_script" "$zb_img" || bad zombie-first-apply
printf 'mkdir "/bn"\nmkdir "/bn/data"\nmkdir "/bn/new"\n' > "$zb_script"
if psbbn_debugfs_apply "$zb_script" "$zb_img" && /opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$zb_img" >/dev/null 2>&1 \
    && /opt/homebrew/opt/e2fsprogs/sbin/debugfs -R 'stat /bn/new' "$zb_img" 2>/dev/null | grep -q 'Inode:'; then
    ok mkdir-existing-no-zombie
else
    bad "mkdir-existing-no-zombie $(/opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$zb_img" 2>&1 | grep -v '^Pass' | head -4)"
fi
# a zombie planted with raw debugfs is cleared by the gate
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R 'symlink /bn/link target' "$zb_img" >/dev/null 2>&1
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R 'symlink /bn/link target' "$zb_img" >/dev/null 2>&1
set +e
/opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$zb_img" >/dev/null 2>&1
dirty_rc=$?
set -e
if [[ "$dirty_rc" -ne 0 ]] && psbbn_ext2_check "$zb_img" && /opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$zb_img" >/dev/null 2>&1; then
    ok ext2-check-clears-zombie
else
    bad "ext2-check-clears-zombie dirty_rc=$dirty_rc"
fi
# real damage is not papered over
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -w -R 'sif /bn links_count 9' "$zb_img" >/dev/null 2>&1
set +e
psbbn_ext2_check "$zb_img" >/dev/null 2>&1
gate_rc=$?
set -e
[[ "$gate_rc" -ne 0 ]] && ok ext2-check-fails-on-damage || bad ext2-check-fails-on-damage

# --- PFS re-stage: existing directories, changed files, removals ----------
pfs2_mnt=$(mktemp -d)
pfs2_state=$(mktemp -d)
if PSBBN_MOUNT_STATE="$pfs2_state" "$bin/pfs-fuse" -o allow_other --partition=__system "$pfs_img" "$pfs2_mnt/" > "$stub/pfs2-mount.out" 2>&1 \
    && [[ "$(cat "$pfs2_mnt/sub/inside.txt" 2>/dev/null)" == nested ]]; then
    printf 'changed\n' > "$pfs2_mnt/sub/inside.txt"
    printf 'fresh\n' > "$pfs2_mnt/sub/fresh.txt"
    rm -f "$pfs2_mnt/hello.txt"
    if PSBBN_MOUNT_STATE="$pfs2_state" "$bin/umount" "$pfs2_mnt" > "$stub/pfs2-umount.out" 2>&1; then
        pfs2_back=$(mktemp -d)
        listing=$(printf 'device %s\nmount __system\nls\ncd sub\nlcd %s\nget inside.txt\nget fresh.txt\numount\nexit\n' "$pfs_img" "$pfs2_back" | "$pfs_bin" 2>/dev/null)
        if [[ "$(cat "$pfs2_back/inside.txt" 2>/dev/null)" == changed && "$(cat "$pfs2_back/fresh.txt" 2>/dev/null)" == fresh ]] && ! grep -q 'hello.txt' <<<"$listing"; then
            ok pfs-restage-diff
        else
            bad "pfs-restage-diff inside=$(cat "$pfs2_back/inside.txt" 2>/dev/null) listing=$listing"
        fi
    else
        bad "pfs-restage-diff umount: $(cat "$stub/pfs2-umount.out")"
    fi
else
    bad "pfs-restage-diff mount: $(cat "$stub/pfs2-mount.out")"
fi

# --- overlay rebuilds keep files the installer created ------------------
ov_repo=$(mktemp -d)
mkdir -p "$ov_repo/scripts/assets" "$ov_repo/scripts/helper/darwin-arm64" "$ov_repo/scripts/helper/aarch64"
echo a > "$ov_repo/scripts/assets/a.txt"
echo b > "$ov_repo/scripts/assets/b.txt"
ov_dest=$(mktemp -d)
build_overlay "$ov_repo" "$ov_dest"
mkdir -p "$ov_dest/logs"
echo log > "$ov_dest/logs/setup.log"
echo dl > "$ov_dest/scripts/assets/patch.tar.gz"
rm "$ov_repo/scripts/assets/b.txt"
build_overlay "$ov_repo" "$ov_dest"
if [[ "$(cat "$ov_dest/logs/setup.log")" == log && "$(cat "$ov_dest/scripts/assets/patch.tar.gz")" == dl && -L "$ov_dest/scripts/assets/a.txt" && ! -e "$ov_dest/scripts/assets/b.txt" ]]; then
    ok overlay-keeps-downloads
else
    bad "overlay-keeps-downloads $(ls -la "$ov_dest/scripts/assets" "$ov_dest/logs")"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

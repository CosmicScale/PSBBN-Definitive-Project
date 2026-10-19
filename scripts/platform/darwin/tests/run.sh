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

# --- check-deps: Homebrew packages behind the shims -----------------------
cd_stub=$(mktemp -d)
mkdir -p "$cd_stub/opt/present"
cat > "$cd_stub/brew" << EOF
#!/bin/bash
# brew --prefix NAME...: one path per name; "gone" points nowhere.
shift
for f in "\$@"; do
    if [[ "\$f" == gone ]]; then echo "$cd_stub/opt/gone"; else echo "$cd_stub/opt/present"; fi
done
EOF
chmod +x "$cd_stub/brew"
status=0
out=$(PSBBN_BREW="$cd_stub/brew" /bin/bash "$root/check-deps.sh" 2>&1) || status=$?
n=$(grep -c -v -E '^\s*(#|$)' "$root/formulae.txt")
[[ "$status" -eq 0 && "$(grep -c '^\[✓\]' <<<"$out")" -eq "$n" ]] && ok check-deps-all-present || bad "check-deps-all-present status=$status $(head -n 2 <<<"$out")"
printf 'gone\n' > "$cd_stub/formulae.txt"; cp "$root/check-deps.sh" "$cd_stub/check-deps.sh"
status=0
out=$(PSBBN_BREW="$cd_stub/brew" /bin/bash "$cd_stub/check-deps.sh" 2>&1) || status=$?
[[ "$status" -eq 1 && "$out" == *"Missing Homebrew package: gone"* ]] && ok check-deps-reports-missing || bad "check-deps-reports-missing status=$status $out"
rm -rf "$cd_stub"

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
# pfsshell prints its banner and prompts on stderr, and a device it cannot
# open with perror, then exits 1.
echo "pfsshell for POSIX systems" >&2
if [[ "\$n" -le 1 ]]; then
    echo "> /dev/disk4: Resource busy" >&2
    exit 1
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
# scripts/assets is linked whole on purpose (the downloads, and the
# changelog the front door deletes), so the sample lives one level up.
mkdir -p "$repo/scripts/assets/lang" "$repo/scripts/helper/aarch64" "$repo/scripts/helper/darwin-arm64"
echo keep-me > "$repo/scripts/sample.txt"
echo elf > "$repo/scripts/helper/aarch64/cue2pops"
echo macho > "$repo/scripts/helper/darwin-arm64/cue2pops"
echo macho > "$repo/scripts/helper/darwin-arm64/pops2cue"
overlay=$(mktemp -d)
. "$root/lib.sh"
build_overlay "$repo" "$overlay"
rm "$overlay/scripts/sample.txt"
if [[ -f "$repo/scripts/sample.txt" ]]; then ok overlay-rm; else bad overlay-rm; fi
if [[ "$(cat "$overlay/scripts/helper/aarch64/cue2pops")" == macho ]]; then ok overlay-helper; else bad overlay-helper; fi
# No Linux pops2cue is shipped yet; the overlay still has both names for it.
if [[ "$(cat "$overlay/scripts/helper/pops2cue" 2>/dev/null)" == macho && "$(cat "$overlay/scripts/helper/aarch64/pops2cue" 2>/dev/null)" == macho ]]; then
    ok overlay-helper-pops2cue
else
    bad overlay-helper-pops2cue
fi

for tool in uname sudo blkid ldconfig lvm dmsetup sfdisk partprobe blockdev wipefs mount umount findmnt df mkfs.vfat mke2fs timeout mount.exfat-fuse lsblk sed convert; do
    if [[ -x "$bin/$tool" ]]; then ok "exec-$tool"; else bad "exec-$tool"; fi
done

zipdir=$(mktemp -d)
mkdir -p "$zipdir/src/sub" "$zipdir/out"
printf 'a\n' > "$zipdir/src/a.txt"
printf 'b\n' > "$zipdir/src/sub/b.txt"
xattr -w com.apple.TextEncoding 'utf-8;134217984' "$zipdir/src/a.txt"
status=0
# enter.sh exports COPYFILE_DISABLE=1 for the whole run; no AppleDouble entries may reach the zip.
(cd "$zipdir/src" && COPYFILE_DISABLE=1 bsdtar -acf "$zipdir/art.zip" *) >/dev/null 2>&1 || status=$?
if [[ "$status" -eq 0 ]] \
    && python3 -c 'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); n = z.namelist(); sys.exit(0 if z.testzip() is None and "sub/b.txt" in n and not [x for x in n if "._" in x] else 1)' "$zipdir/art.zip" \
    && bsdtar -xf "$zipdir/art.zip" -C "$zipdir/out" \
    && [[ "$(cat "$zipdir/out/sub/b.txt")" == b ]]; then
    ok bsdtar-zip-roundtrip
else
    bad "bsdtar-zip-roundtrip status=$status"
fi
rm -rf "$zipdir"

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

# PS2 Linux's sudo, userhelper and Xwrapper are setuid root and its /tmp is
# sticky, as are PSBBN's su and bn_asap. Without those bits sudo, halt and
# startx stop with "must be setuid root". A reinstall over a partition an
# extract without them wrote must put them back.
suid_archive=$(mktemp)
suid_plain=$(mktemp)
python3 - "$suid_archive" "$suid_plain" << 'PY'
import io, sys, tarfile
rows = [
    ("d", "__linux.3", 0o755, 0, 0),
    ("d", "__linux.3/tmp", 0o1777, 0, 0),
    ("d", "__linux.3/usr", 0o755, 0, 0),
    ("d", "__linux.3/usr/doc", 0o2755, 0, 15),
    ("d", "__linux.3/usr/bin", 0o755, 0, 0),
    ("f", "__linux.3/usr/bin/sudo", 0o4111, 0, 0),
    ("f", "__linux.3/usr/bin/man", 0o2755, 0, 15),
    ("f", "__linux.3/usr/bin/procmail", 0o6755, 0, 12),
    ("f", "__linux.3/usr/bin/emacs", 0o1755, 0, 0),
    ("f", "__linux.3/usr/bin/sperl5.00503", 0o4711, 0, 0),
    ("h", "__linux.3/usr/bin/suidperl", 0o4711, 0, 0),
]
def write(path, keep):
    with tarfile.open(path, "w:gz") as tf:
        for kind, name, mode, uid, gid in rows:
            info = tarfile.TarInfo(name)
            info.mode = mode & keep
            info.uid, info.gid, info.mtime = uid, gid, 1700000000
            data = None
            if kind == "d":
                info.type = tarfile.DIRTYPE
            elif kind == "h":
                info.type = tarfile.LNKTYPE
                info.linkname = "__linux.3/usr/bin/sperl5.00503"
            else:
                data = name.encode() + b"\n"
                info.size = len(data)
            tf.addfile(info, io.BytesIO(data) if data else None)
write(sys.argv[1], 0o7777)
write(sys.argv[2], 0o777)
PY
# suid_modes SLICE -> "path mode uid:gid ..." for every path above
suid_modes() {
    local p out
    for p in tmp usr/doc usr/bin/sudo usr/bin/man usr/bin/procmail usr/bin/emacs usr/bin/suidperl; do
        out=$("$node_dbg" -R "stat $p" "$1" 2>/dev/null)
        [[ "$out" =~ Mode:\ +0*([0-7]+) ]] && printf '%s %s' "$p" "${BASH_REMATCH[1]}"
        [[ "$out" =~ User:\ +([0-9]+)\ +Group:\ +([0-9]+) ]] && printf ' %s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        printf ' '
    done
}
# suid_extract SLICE ARCHIVE...: one mount, extract and unmount per archive
suid_extract() {
    local slice="$1" archive storage state rc=0
    shift
    for archive in "$@"; do
        storage=$(mktemp -d)
        state=$(mktemp -d)
        mkdir -p "$storage/__linux.3"
        PSBBN_MOUNT_STATE="$state" "$bin/mount" "$slice" "$storage/__linux.3" >>/tmp/psbbn-suid.out 2>&1 || rc=$?
        [[ "$rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$state" "$bin/tar" zxpf "$archive" -C "$storage" >>/tmp/psbbn-suid.out 2>&1 || rc=$?; }
        [[ "$rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$state" "$bin/umount" "$storage/__linux.3" >>/tmp/psbbn-suid.out 2>&1 || rc=$?; }
        rm -rf "$storage" "$state"
    done
    return "$rc"
}
suid_want="tmp 1777 0:0 usr/doc 2755 0:15 usr/bin/sudo 4111 0:0 usr/bin/man 2755 0:15 usr/bin/procmail 6755 0:12 usr/bin/emacs 1755 0:0 usr/bin/suidperl 4711 0:0 "
for suid_case in fresh reinstall; do
    suid_slice=$(mktemp)
    dd if=/dev/zero of="$suid_slice" bs=1048576 count=16 status=none
    psbbn_format_ext2_file "$suid_slice" >/dev/null
    printf 'device=%s\nstart=0\nsectors=32768\n' "$suid_slice" > "$suid_slice.meta"
    : > /tmp/psbbn-suid.out
    suid_rc=0
    if [[ "$suid_case" == fresh ]]; then
        suid_extract "$suid_slice" "$suid_archive" || suid_rc=$?
    else
        suid_extract "$suid_slice" "$suid_plain" "$suid_archive" || suid_rc=$?
    fi
    suid_got=$(suid_modes "$suid_slice")
    if [[ "$suid_rc" -eq 0 && "$suid_got" == "$suid_want" ]]; then
        ok "tar-ext2-keeps-special-bits ($suid_case)"
    else
        bad "tar-ext2-keeps-special-bits ($suid_case) rc=$suid_rc got=[$suid_got] want=[$suid_want] $(tail -n 3 /tmp/psbbn-suid.out)"
    fi
    rm -f "$suid_slice" "$suid_slice.meta"
done
rm -f "$suid_archive" "$suid_plain" /tmp/psbbn-suid.out

# debugfs takes a bare number for a time as a date when it can: 1733062763
# became 2005-09-08 and 938706242 2037-12-18. Times from the archive and
# from files written through the mounted folder must arrive as they are.
# PS2Linux.tar.gz starts with its top folder under an empty name; GNU tar
# gives its mode and time to the folder it extracts into, the partition.
time_slice=$(mktemp)
dd if=/dev/zero of="$time_slice" bs=1048576 count=16 status=none
psbbn_format_ext2_file "$time_slice" >/dev/null
printf 'device=%s\nstart=0\nsectors=32768\n' "$time_slice" > "$time_slice.meta"
time_storage=$(mktemp -d)
time_state=$(mktemp -d)
mkdir -p "$time_storage/__linux.3"
time_archive=$(mktemp)
python3 - "$time_archive" << 'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz") as tf:
    for kind, name, mtime in [
        ("d", "", 1733060310),
        ("d", "etc", 1733060769),
        ("f", "etc/killall", 938706242),
        ("f", "etc/bash_profile", 1733062763),
        ("l", "etc/K60atd", 1733060769),
    ]:
        info = tarfile.TarInfo(name)
        info.mtime, info.uid, info.gid = mtime, 0, 0
        data = None
        if kind == "d":
            info.type, info.mode = tarfile.DIRTYPE, 0o750 if not name else 0o755
        elif kind == "l":
            info.type, info.mode, info.linkname = tarfile.SYMTYPE, 0o777, "killall"
        else:
            data = b"x\n"
            info.size, info.mode = len(data), 0o644
        tf.addfile(info, io.BytesIO(data) if data else None)
PY
time_rc=0
PSBBN_MOUNT_STATE="$time_state" "$bin/mount" "$time_slice" "$time_storage/__linux.3" >/tmp/psbbn-time.out 2>&1 || time_rc=$?
[[ "$time_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$time_state" "$bin/tar" zxpf "$time_archive" -C "$time_storage/__linux.3" >>/tmp/psbbn-time.out 2>&1 || time_rc=$?; }
printf 'new\n' > "$time_storage/__linux.3/etc/written"
python3 -c 'import os, sys; os.utime(sys.argv[1], (1733062923, 1733062923))' "$time_storage/__linux.3/etc/written"
[[ "$time_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$time_state" "$bin/umount" "$time_storage/__linux.3" >>/tmp/psbbn-time.out 2>&1 || time_rc=$?; }
time_got=""
for p in / etc etc/killall etc/bash_profile etc/K60atd etc/written; do
    out=$("$node_dbg" -R "stat $p" "$time_slice" 2>/dev/null)
    [[ "$out" =~ mtime:\ 0x([0-9a-f]+) ]] && time_got+="$p $((16#${BASH_REMATCH[1]})) "
done
[[ "$("$node_dbg" -R "stat /" "$time_slice" 2>/dev/null)" =~ Mode:\ +0*([0-7]+) ]] && time_got+="/ mode ${BASH_REMATCH[1]}"
time_want="/ 1733060310 etc 1733060769 etc/killall 938706242 etc/bash_profile 1733062763 etc/K60atd 1733060769 etc/written 1733062923 / mode 750"
if [[ "$time_rc" -eq 0 && "$time_got" == "$time_want" ]]; then
    ok tar-ext2-keeps-times
else
    bad "tar-ext2-keeps-times rc=$time_rc got=[$time_got] want=[$time_want] $(tail -n 3 /tmp/psbbn-time.out)"
fi
rm -rf "$time_slice" "$time_slice.meta" "$time_storage" "$time_state" "$time_archive" /tmp/psbbn-time.out

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

# --- a dd to the drive writes the session's PFS stages first ---------------
# HOSDMenu-Installer's BOOTSTRAP writes sector 0 with its PFS partitions
# still staged, and leaves the APA header checksum stale until it fixes it
# later: pfsshell then refuses the drive (-19). The stage goes to the drive
# before the dd, and its unmount, with nothing new, leaves pfsshell alone.
sync=$(mktemp -d)
cp -c "$pfs_img" "$sync/img"
mkdir -p "$sync/mnt" "$sync/state" "$sync/back"
sync_env=(PSBBN_SESSION_PID=$$ PSBBN_MOUNT_STATE="$sync/state")
sync_rc=0
env "${sync_env[@]}" "$bin/pfs-fuse" -o allow_other --partition=__contents "$sync/img" "$sync/mnt/" > "$sync/out" 2>&1 || sync_rc=$?
printf 'synced\n' > "$sync/mnt/early.txt"
env "${sync_env[@]}" "$bin/dd" if=/dev/zero of="$sync/img" bs=1 count=0 conv=notrunc >> "$sync/out" 2>&1 || sync_rc=$?
printf 'device %s\nmount __contents\nlcd %s\nget early.txt\numount\nexit\n' "$sync/img" "$sync/back" | "$pfs_bin" >/dev/null 2>&1 || true
if [[ "$sync_rc" -eq 0 && "$(cat "$sync/back/early.txt" 2>/dev/null)" == synced ]]; then
    ok dd-writes-pfs-stage-first
else
    bad "dd-writes-pfs-stage-first rc=$sync_rc got=[$(cat "$sync/back/early.txt" 2>/dev/null)] $(tail -n 3 "$sync/out")"
fi
# The stale checksum, as BOOTSTRAP leaves it: a byte of the header changes.
printf 'X' | /bin/dd of="$sync/img" bs=1 seek=304 conv=notrunc 2>/dev/null
stale=$(printf 'device %s\nmount __contents\numount\nexit\n' "$sync/img" | "$pfs_bin" 2>&1 || true)
sync_rc=0
env "${sync_env[@]}" "$bin/umount" "$sync/mnt" >> "$sync/out" 2>&1 || sync_rc=$?
if [[ "$stale" == *"-19"* && "$sync_rc" -eq 0 ]] \
    && [[ -z "$(env "${sync_env[@]}" "$bin/findmnt" -nr -o TARGET | grep -F "$sync/mnt")" ]]; then
    ok pfs-umount-unchanged-skips-pfsshell
else
    bad "pfs-umount-unchanged-skips-pfsshell rc=$sync_rc stale=[$(tail -n 2 <<< "$stale")] $(tail -n 3 "$sync/out")"
fi
rm -rf "$sync"

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

# --- APA partitions above the size cap span several extents -----------------
ext_dir=$(mktemp -d)
ext_dm="$ext_dir/dm"
ext_maps="$ext_dir/maps"
ext_state="$ext_dir/state"
ext_dev="$ext_dir/drive.img"
# hdl_dump toc --dm prints every map on one line, separated by ';'.
printf 'cut-a,,,rw,0 16 linear %s 2048;cut-b,,,rw,0 16 linear %s 4096;' "$ext_dev" "$ext_dev" \
    | PSBBN_DM_STATE="$ext_dm" PSBBN_MAPPER_DIR="$ext_maps" "$bin/dmsetup" create --concise || true
ext_ls=$(PSBBN_DM_STATE="$ext_dm" "$bin/dmsetup" ls)
if grep -qx cut-a <<<"$ext_ls" && grep -qx cut-b <<<"$ext_ls" && [[ -f "$ext_maps/cut-a" && -f "$ext_maps/cut-b" ]]; then
    ok dm-concise-semicolons
else
    bad "dm-concise-semicolons ls=$ext_ls"
fi
rm -rf "${ext_dm:?}" "${ext_maps:?}"

# 96 MiB of random bytes stands in for the drive. The partition is two
# 20 MiB extents with a 2 MiB gap (the sub-partition header) between them.
dd if=/dev/urandom of="$ext_dev" bs=1048576 count=96 status=none 2>/dev/null
ext_line="cut-__linux.8,,,rw,0 40960 linear $ext_dev 4096,40960 40960 linear $ext_dev 49152"
gap_sum() {
    {
        dd if="$ext_dev" bs=512 skip=0 count=4096 2>/dev/null
        dd if="$ext_dev" bs=512 skip=45056 count=4096 2>/dev/null
        dd if="$ext_dev" bs=512 skip=90112 2>/dev/null
    } | /sbin/md5 -q
}
extents_of_drive() {
    dd if="$ext_dev" bs=512 skip=4096 count=40960 2>/dev/null
    dd if="$ext_dev" bs=512 skip=49152 count=40960 2>/dev/null
}
gap_before=$(gap_sum)
printf '%s\n' "$ext_line" | PSBBN_DM_STATE="$ext_dm" PSBBN_MAPPER_DIR="$ext_maps" "$bin/dmsetup" create --concise || true
ext_slice="$ext_maps/cut-__linux.8"
ext_meta=$(cat "$ext_slice.meta" 2>/dev/null) || true
if [[ "$(wc -c < "$ext_slice" 2>/dev/null | tr -d ' ')" == $((81920 * 512)) ]] && grep -qx 'sectors=81920' <<<"$ext_meta" \
    && grep -qx "extents='4096:40960 49152:40960'" <<<"$ext_meta" && ! grep -q '^start=' <<<"$ext_meta"; then
    ok dm-multi-extent-meta
else
    bad "dm-multi-extent-meta meta=$ext_meta"
fi

ext_status=0
printf 'cut-gap,,,rw,0 16 linear %s 2048,32 16 linear %s 4096\n' "$ext_dev" "$ext_dev" \
    | PSBBN_DM_STATE="$ext_dm" PSBBN_MAPPER_DIR="$ext_maps" "$bin/dmsetup" create --concise 2>/dev/null || ext_status=$?
if [[ "$ext_status" -ne 0 ]] && ! PSBBN_DM_STATE="$ext_dm" "$bin/dmsetup" ls | grep -qx cut-gap; then
    ok dm-rejects-hole-in-map
else
    bad "dm-rejects-hole-in-map status=$ext_status"
fi

# Format, mount, write, unmount: both extents land on the drive, the gap
# does not change, and a fresh map reads the same file back.
ext_mnt="$ext_dir/mnt"
ext_ok=1
"$bin/mkfs.vfat" -F 32 "$ext_slice" >/dev/null 2>&1 || ext_ok=0
head -c 3000000 /dev/urandom > "$ext_dir/song.pcm"
if [[ "$ext_ok" -eq 1 ]] && PSBBN_MOUNT_STATE="$ext_state" "$bin/mount" "$ext_slice" "$ext_mnt"; then
    mkdir -p "$ext_mnt/MusicCh/contents/album"
    cp "$ext_dir/song.pcm" "$ext_mnt/MusicCh/contents/album/track01.pcm"
    PSBBN_MOUNT_STATE="$ext_state" "$bin/umount" "$ext_mnt" || ext_ok=0
else
    ext_ok=0
fi
# The slice's holes are not written, so the drive keeps its random bytes
# there; the filesystem on the drive must still check clean.
extents_of_drive > "$ext_dir/drive-copy.img"
if [[ "$ext_ok" -eq 1 && "$(gap_sum)" == "$gap_before" ]] && /sbin/fsck_msdos -n "$ext_dir/drive-copy.img" >/dev/null 2>&1; then
    ok slice-multi-extent-writeback
else
    bad "slice-multi-extent-writeback ok=$ext_ok gap=$([[ "$(gap_sum)" == "$gap_before" ]] && echo same || echo changed)"
fi
PSBBN_DM_STATE="$ext_dm" PSBBN_MAPPER_DIR="$ext_maps" "$bin/dmsetup" remove cut-__linux.8 || true
printf '%s\n' "$ext_line" | PSBBN_DM_STATE="$ext_dm" PSBBN_MAPPER_DIR="$ext_maps" "$bin/dmsetup" create --concise || true
rm -rf "${ext_mnt:?}"
if PSBBN_MOUNT_STATE="$ext_state" "$bin/mount" "$ext_slice" "$ext_mnt" \
    && cmp -s "$ext_dir/song.pcm" "$ext_mnt/MusicCh/contents/album/track01.pcm" \
    && /sbin/fsck_msdos -n "$ext_slice" >/dev/null 2>&1; then
    ok slice-multi-extent-read
else
    bad "slice-multi-extent-read $(ls -R "$ext_mnt" 2>&1 | head -5)"
fi
PSBBN_MOUNT_STATE="$ext_state" "$bin/umount" "$ext_mnt" >/dev/null 2>&1 || true

# On a real disk every extent goes through one elevated call, so the
# drive's mounts are released and restored once.
ext_rec=$(mktemp)
cat > "$stub/elevate-count" << EOF
#!/bin/bash
printf 'CALL %s\n' "\$1" >> "$ext_rec"
exit 0
EOF
chmod +x "$stub/elevate-count"
ext_small=$(mktemp)
dd if=/dev/zero of="$ext_small" bs=512 count=24 2>/dev/null
ext_status=0
PSBBN_SUDO="$stub/elevate-count" PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_MOUNT_TABLE=/dev/null /opt/homebrew/bin/bash -c \
    '. "$1"; psbbn_writeback_range /dev/disk5 "2048:8 4096:8 8192:8" "$2"' _ "$root/../load.sh" "$ext_small" || ext_status=$?
if [[ "$ext_status" -eq 0 && "$(grep -c '^CALL' "$ext_rec")" -eq 1 ]] && grep -qx 'CALL /bin/sh' "$ext_rec"; then
    ok slice-extents-one-elevation
else
    bad "slice-extents-one-elevation status=$ext_status rec=$(cat "$ext_rec")"
fi
# The extents must cover the slice exactly; anything else is refused.
ext_status=0
ext_err=$(PSBBN_SUDO="$stub/elevate-count" PSBBN_DISKUTIL="$stub/diskutil-mount" PSBBN_MOUNT_TABLE=/dev/null /opt/homebrew/bin/bash -c \
    '. "$1"; psbbn_writeback_range /dev/disk5 "2048:8 4096:8" "$2"' _ "$root/../load.sh" "$ext_small" 2>&1) || ext_status=$?
[[ "$ext_status" -ne 0 && "$ext_err" == *"extents cover"* ]] && ok slice-extents-must-match-size || bad "slice-extents-must-match-size status=$ext_status err=$ext_err"
rm -rf "${ext_dir:?}" "$ext_rec" "$ext_small"

# --- a fresh slice writes only what was written into it ---------------------
# The drive is random bytes, as a used drive would be. A fresh slice is
# formatted, filled and unmounted; only its data regions may reach the
# drive, and the filesystem there must still check clean.
hs_dir=$(mktemp -d)
hs_dev="$hs_dir/drive.img"
hs_bytes="$hs_dir/bytes"
dd if=/dev/urandom of="$hs_dev" bs=1048576 count=96 status=none 2>/dev/null
cat > "$stub/dd-count" << EOF
#!/bin/bash
# The real dd. Adds up the bytes of every write onto the drive image.
bs=0; count=0; of=""
for a in "\$@"; do
    case "\$a" in bs=*) bs=\${a#bs=} ;; count=*) count=\${a#count=} ;; of=*) of=\${a#of=} ;; esac
done
[[ "\$of" == "$hs_dev" ]] && echo \$((bs * count)) >> "$hs_bytes"
exec /bin/dd "\$@"
EOF
chmod +x "$stub/dd-count"
hs_env=(PSBBN_DM_STATE="$hs_dir/dm" PSBBN_MAPPER_DIR="$hs_dir/maps" PSBBN_MOUNT_STATE="$hs_dir/state" PSBBN_DD="$stub/dd-count")
hs_slice="$hs_dir/maps/hs-p"
hs_map() {
    env "${hs_env[@]}" "$bin/dmsetup" remove hs-p >/dev/null 2>&1 || true
    printf 'hs-p,,,rw,0 40960 linear %s 4096,40960 40960 linear %s 49152\n' "$hs_dev" "$hs_dev" \
        | env "${hs_env[@]}" "$bin/dmsetup" create --concise || true
}
hs_drive() {
    dd if="$hs_dev" bs=512 skip=4096 count=40960 2>/dev/null
    dd if="$hs_dev" bs=512 skip=49152 count=40960 2>/dev/null
}
hs_written() { awk '{ s += $1 } END { print s + 0 }' "$hs_bytes" 2>/dev/null; }
head -c 1000000 /dev/urandom > "$hs_dir/song.pcm"
hs_slice_bytes=$((81920 * 512))

for hs_kind in vfat ext2; do
    hs_map
    : > "$hs_bytes"
    hs_ok=1
    if [[ "$hs_kind" == vfat ]]; then
        "$bin/mkfs.vfat" -F 32 "$hs_slice" >/dev/null 2>&1 || hs_ok=0
    else
        env "${hs_env[@]}" "$bin/mke2fs" -t ext2 -b 4096 -I 128 \
            -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode \
            "$hs_slice" >/dev/null 2>&1 || hs_ok=0
    fi
    rm -rf "${hs_dir:?}/mnt"
    if [[ "$hs_ok" -eq 1 ]] && env "${hs_env[@]}" "$bin/mount" "$hs_slice" "$hs_dir/mnt"; then
        mkdir -p "$hs_dir/mnt/album"
        cp "$hs_dir/song.pcm" "$hs_dir/mnt/album/track01.pcm"
        env "${hs_env[@]}" "$bin/umount" "$hs_dir/mnt" || hs_ok=0
    else
        hs_ok=0
    fi
    hs_w=$(hs_written)
    hs_drive > "$hs_dir/check.img"
    if [[ "$hs_kind" == vfat ]]; then
        /sbin/fsck_msdos -n "$hs_dir/check.img" >/dev/null 2>&1 || hs_ok=0
    else
        /opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$hs_dir/check.img" >/dev/null 2>&1 || hs_ok=0
    fi
    if [[ "$hs_ok" -eq 1 && "$hs_w" -gt 0 && "$hs_w" -lt $((hs_slice_bytes / 4)) ]]; then
        ok "slice-fresh-$hs_kind-skips-holes ($((hs_w / 1048576)) of $((hs_slice_bytes / 1048576)) MiB)"
    else
        bad "slice-fresh-$hs_kind-skips-holes ok=$hs_ok written=$hs_w"
    fi
done

# A slice read off the drive is hashed per MiB; unmount writes only the
# chunks that changed, and afterwards the drive matches the slice exactly.
: > "$hs_slice.sums"
hs_map
[[ ! -e "$hs_slice.sums" ]] && ok dm-create-drops-old-sums || bad dm-create-drops-old-sums
: > "$hs_bytes"
rm -rf "${hs_dir:?}/mnt"
hs_ok=1
if env "${hs_env[@]}" "$bin/mount" "$hs_slice" "$hs_dir/mnt" && cmp -s "$hs_dir/song.pcm" "$hs_dir/mnt/album/track01.pcm" && [[ -s "$hs_slice.sums" ]]; then
    head -c 600000 /dev/urandom > "$hs_dir/mnt/album/track02.pcm"
    env "${hs_env[@]}" "$bin/umount" "$hs_dir/mnt" || hs_ok=0
else
    hs_ok=0
fi
hs_w=$(hs_written)
if [[ "$hs_ok" -eq 1 && "$hs_w" -gt 0 && "$hs_w" -lt $((hs_slice_bytes / 4)) ]] && cmp -s <(hs_drive) "$hs_slice"; then
    ok "slice-read-writes-changed-chunks ($((hs_w / 1048576)) of $((hs_slice_bytes / 1048576)) MiB)"
else
    bad "slice-read-writes-changed-chunks ok=$hs_ok written=$hs_w of $hs_slice_bytes"
fi
# Mounted again in the same run and left alone: nothing to write.
: > "$hs_bytes"
rm -rf "${hs_dir:?}/mnt"
hs_ok=1
if env "${hs_env[@]}" "$bin/mount" "$hs_slice" "$hs_dir/mnt"; then
    env "${hs_env[@]}" "$bin/umount" "$hs_dir/mnt" || hs_ok=0
else
    hs_ok=0
fi
hs_w=$(hs_written)
[[ "$hs_ok" -eq 1 && "$hs_w" -eq 0 ]] && cmp -s <(hs_drive) "$hs_slice" && ok slice-unchanged-writes-nothing || bad "slice-unchanged-writes-nothing ok=$hs_ok written=$hs_w"
# A hash file that does not match the slice is ignored: everything goes.
printf 'junk\n' > "$hs_slice.sums"
: > "$hs_bytes"
rm -rf "${hs_dir:?}/mnt"
hs_ok=1
if env "${hs_env[@]}" "$bin/mount" "$hs_slice" "$hs_dir/mnt"; then
    printf 'junk\n' > "$hs_slice.sums"
    env "${hs_env[@]}" "$bin/umount" "$hs_dir/mnt" || hs_ok=0
else
    hs_ok=0
fi
hs_w=$(hs_written)
[[ "$hs_ok" -eq 1 && "$hs_w" -eq "$hs_slice_bytes" ]] && ok slice-bad-sums-writes-all || bad "slice-bad-sums-writes-all ok=$hs_ok written=$hs_w"
rm -rf "${hs_dir:?}"

# --- FAT unmount changes only what the installer changed --------------------
# The music partition already holds albums. The installer keeps one, edits
# one, deletes one and a whole folder, and adds a folder. The volume is not
# re-created: its serial number survives and the untouched file keeps its
# clusters.
vi_dir=$(mktemp -d)
vi_img="$vi_dir/slice"
vi_env=(PSBBN_MOUNT_STATE="$vi_dir/state")
vi_ok=1
dd if=/dev/zero of="$vi_img" bs=1048576 count=64 status=none 2>/dev/null
printf 'device=%s\nsectors=131072\nextents=0:131072\n' "$vi_dir/drive" > "$vi_img.meta"
dd if=/dev/zero of="$vi_dir/drive" bs=1048576 count=64 status=none 2>/dev/null
/sbin/newfs_msdos -F 32 -s 131072 "$vi_img" >/dev/null 2>&1 || vi_ok=0
head -c 300000 /dev/urandom > "$vi_dir/keep.pcm"
printf 'old\n' > "$vi_dir/edit.txt"
printf 'bye\n' > "$vi_dir/gone.txt"
mmd -i "$vi_img" ::/MusicCh ::/MusicCh/contents ::/MusicCh/contents/keep ::/MusicCh/contents/old 2>/dev/null || vi_ok=0
mcopy -i "$vi_img" "$vi_dir/keep.pcm" ::/MusicCh/contents/keep/track01.pcm 2>/dev/null || vi_ok=0
mcopy -i "$vi_img" "$vi_dir/edit.txt" ::/MusicCh/edit.txt 2>/dev/null || vi_ok=0
mcopy -i "$vi_img" "$vi_dir/gone.txt" ::/MusicCh/gone.txt 2>/dev/null || vi_ok=0
mcopy -i "$vi_img" "$vi_dir/gone.txt" ::/MusicCh/contents/old/track01.pcm 2>/dev/null || vi_ok=0
vi_serial() { dd if="$vi_img" bs=1 skip=67 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n'; }
vi_serial_before=$(vi_serial)
vi_cluster_before=$(mshowfat -i "$vi_img" ::/MusicCh/contents/keep/track01.pcm 2>/dev/null) || true
if [[ "$vi_ok" -eq 1 ]] && env "${vi_env[@]}" "$bin/mount" "$vi_img" "$vi_dir/mnt"; then
    printf 'new\n' > "$vi_dir/mnt/MusicCh/edit.txt"
    rm -f "$vi_dir/mnt/MusicCh/gone.txt"
    rm -rf "$vi_dir/mnt/MusicCh/contents/old"
    mkdir -p "$vi_dir/mnt/MusicCh/contents/new album"
    printf 'fresh\n' > "$vi_dir/mnt/MusicCh/contents/new album/track01.pcm"
    env "${vi_env[@]}" "$bin/umount" "$vi_dir/mnt" || vi_ok=0
else
    vi_ok=0
fi
vi_listing=$(mdir -i "$vi_img" -/ -b ::/ 2>/dev/null) || true
vi_cluster_after=$(mshowfat -i "$vi_img" ::/MusicCh/contents/keep/track01.pcm 2>/dev/null) || true
vi_keep=$(mtype -i "$vi_img" ::/MusicCh/contents/keep/track01.pcm 2>/dev/null | /sbin/md5 -q) || true
vi_edit=$(mtype -i "$vi_img" ::/MusicCh/edit.txt 2>/dev/null) || true
vi_fresh=$(mtype -i "$vi_img" "::/MusicCh/contents/new album/track01.pcm" 2>/dev/null) || true
if [[ "$vi_ok" -eq 1 && "$(vi_serial)" == "$vi_serial_before" && -n "$vi_cluster_before" && "$vi_cluster_after" == "$vi_cluster_before" \
    && "$vi_keep" == "$(/sbin/md5 -q "$vi_dir/keep.pcm")" && "$vi_edit" == new && "$vi_fresh" == fresh \
    && "$vi_listing" != *gone.txt* && "$vi_listing" != *contents/old* ]] && /sbin/fsck_msdos -n "$vi_img" >/dev/null 2>&1; then
    ok slice-umount-vfat-incremental
else
    bad "slice-umount-vfat-incremental ok=$vi_ok serial=$vi_serial_before/$(vi_serial) cluster=$vi_cluster_before/$vi_cluster_after edit=$vi_edit fresh=$vi_fresh"
fi
rm -rf "${vi_dir:?}"

# mtools reads DOS paths as patterns. Names with [ ] must only ever select
# themselves: removing File[1].txt must not touch File1.txt.
vg_dir=$(mktemp -d)
vg_img="$vg_dir/slice"
vg_env=(PSBBN_MOUNT_STATE="$vg_dir/state")
vg_ok=1
dd if=/dev/zero of="$vg_img" bs=1048576 count=64 status=none 2>/dev/null
printf 'device=%s\nsectors=131072\nextents=0:131072\n' "$vg_dir/drive" > "$vg_img.meta"
dd if=/dev/zero of="$vg_dir/drive" bs=1048576 count=64 status=none 2>/dev/null
/sbin/newfs_msdos -F 32 -s 131072 "$vg_img" >/dev/null 2>&1 || vg_ok=0
printf 'plain\n' > "$vg_dir/plain"
printf 'bracket\n' > "$vg_dir/bracket"
mmd -i "$vg_img" ::/Dir1 '::/Dir[1]' '::/Album [USA]' ::/Old 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/plain" ::/File1.txt 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/bracket" '::/File[1].txt' 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/plain" ::/Dir1/keep.txt 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/bracket" '::/Dir\[1\]/gone.txt' 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/plain" ::/Old/track.pcm 2>/dev/null || vg_ok=0
mcopy -i "$vg_img" "$vg_dir/plain" ::/Old/._track.pcm 2>/dev/null || vg_ok=0
if [[ "$vg_ok" -eq 1 ]] && env "${vg_env[@]}" "$bin/mount" "$vg_img" "$vg_dir/mnt"; then
    rm -f "$vg_dir/mnt/File[1].txt"
    rm -rf "$vg_dir/mnt/Dir[1]" "$vg_dir/mnt/Old"
    printf 'new\n' > "$vg_dir/mnt/Album [USA]/track01.pcm"
    mkdir -p "$vg_dir/mnt/New Album/sub"
    printf 'deep\n' > "$vg_dir/mnt/New Album/sub/track01.pcm"
    env "${vg_env[@]}" "$bin/umount" "$vg_dir/mnt" || vg_ok=0
else
    vg_ok=0
fi
vg_list=$(mdir -i "$vg_img" -/ -b ::/ 2>/dev/null | sort | tr '\n' ' ') || true
vg_want='::/Album [USA]/ ::/Album [USA]/track01.pcm ::/Dir1/ ::/Dir1/keep.txt ::/File1.txt ::/New Album/ ::/New Album/sub/ ::/New Album/sub/track01.pcm '
vg_plain=$(mtype -i "$vg_img" ::/File1.txt 2>/dev/null) || true
if [[ "$vg_ok" -eq 1 && "$vg_list" == "$vg_want" && "$vg_plain" == plain ]] && /sbin/fsck_msdos -n "$vg_img" >/dev/null 2>&1; then
    ok slice-umount-vfat-literal-names
else
    bad "slice-umount-vfat-literal-names ok=$vg_ok list=[$vg_list] File1=$vg_plain"
fi

# An unmount that fails part way can be retried once the cause is gone.
vg_ok=1
printf 'bye\n' > "$vg_dir/bye"
mcopy -i "$vg_img" "$vg_dir/bye" ::/bye.txt 2>/dev/null || vg_ok=0
rm -rf "${vg_dir:?}/mnt"
if [[ "$vg_ok" -eq 1 ]] && env "${vg_env[@]}" "$bin/mount" "$vg_img" "$vg_dir/mnt"; then
    rm -f "$vg_dir/mnt/bye.txt"
    # FAT cannot store ':' in a name; mcopy refuses it after mdel ran.
    printf 'x\n' > "$vg_dir/mnt/bad:name.txt"
    vg_status=0
    env "${vg_env[@]}" "$bin/umount" "$vg_dir/mnt" 2>/dev/null || vg_status=$?
    rm -f "$vg_dir/mnt/bad:name.txt"
    printf 'ok\n' > "$vg_dir/mnt/good.txt"
    vg_status2=0
    env "${vg_env[@]}" "$bin/umount" "$vg_dir/mnt" 2>"$vg_dir/retry.err" || vg_status2=$?
else
    vg_ok=0
fi
vg_list=$(mdir -i "$vg_img" -/ -b ::/ 2>/dev/null | tr '\n' ' ') || true
if [[ "$vg_ok" -eq 1 && "$vg_status" -ne 0 && "$vg_status2" -eq 0 && "$vg_list" != *bye.txt* && "$vg_list" == *good.txt* ]]; then
    ok slice-umount-vfat-retry
else
    bad "slice-umount-vfat-retry ok=$vg_ok first=${vg_status:-} retry=${vg_status2:-} err=$(cat "$vg_dir/retry.err" 2>/dev/null) list=[$vg_list]"
fi
rm -rf "${vg_dir:?}"

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

# --- what the installers download and the folders the user chose ---------
# The overlay is in TMPDIR, which macOS empties on restart. The downloads in
# scripts/assets and the games and media folders kept in gamepath.cfg and
# media.cfg go to the project, where Linux keeps them.
ov_repo=$(mktemp -d)
mkdir -p "$ov_repo/scripts/assets/lang" "$ov_repo/scripts/helper/darwin-arm64" "$ov_repo/scripts/helper/aarch64"
echo a > "$ov_repo/scripts/assets/a.txt"
echo b > "$ov_repo/scripts/assets/b.txt"
ov_dest=$(mktemp -d)
build_overlay "$ov_repo" "$ov_dest"
mkdir -p "$ov_dest/scripts/assets/POPS-binaries-main"
echo dl > "$ov_dest/scripts/assets/PS2Linux.tar.gz"
echo elf > "$ov_dest/scripts/assets/POPS-binaries-main/POPS.ELF"
# Game-Installer's and Media-Installer's own checks and writes.
cfg_before=no
[[ -f "$ov_dest/scripts/gamepath.cfg" && -s "$ov_dest/scripts/gamepath.cfg" ]] && cfg_before=yes
echo /Volumes/Games > "$ov_dest/scripts/gamepath.cfg"
echo /Volumes/Media > "$ov_dest/scripts/media.cfg"
rm "$ov_repo/scripts/assets/b.txt"
# A restart empties TMPDIR.
rm -rf "$ov_dest"
mkdir -p "$ov_dest"
build_overlay "$ov_repo" "$ov_dest"
if [[ "$cfg_before" == no && "$(cat "$ov_repo/scripts/assets/PS2Linux.tar.gz" 2>/dev/null)" == dl \
    && "$(cat "$ov_dest/scripts/assets/PS2Linux.tar.gz" 2>/dev/null)" == dl \
    && "$(cat "$ov_dest/scripts/assets/POPS-binaries-main/POPS.ELF" 2>/dev/null)" == elf \
    && "$(cat "$ov_dest/scripts/assets/a.txt" 2>/dev/null)" == a && ! -e "$ov_dest/scripts/assets/b.txt" ]]; then
    ok overlay-downloads-in-project
else
    bad "overlay-downloads-in-project cfg_before=$cfg_before $(ls -laR "$ov_repo/scripts/assets" "$ov_dest/scripts/assets" 2>&1 | head -30)"
fi
if [[ "$(cat "$ov_repo/scripts/gamepath.cfg" 2>/dev/null)" == /Volumes/Games && "$(cat "$ov_repo/scripts/media.cfg" 2>/dev/null)" == /Volumes/Media \
    && "$(cat "$ov_dest/scripts/gamepath.cfg" 2>/dev/null)" == /Volumes/Games && "$(cat "$ov_dest/scripts/media.cfg" 2>/dev/null)" == /Volumes/Media ]]; then
    ok overlay-chosen-folders-in-project
else
    bad "overlay-chosen-folders-in-project $(ls -la "$ov_repo/scripts" "$ov_dest/scripts" 2>&1)"
fi
rm -rf "$ov_repo" "$ov_dest"

# An overlay from before this version kept its downloads and gamepath.cfg
# in TMPDIR. They move to the project; a file the project has is kept.
ov_repo=$(mktemp -d)
mkdir -p "$ov_repo/scripts/assets/lang" "$ov_repo/scripts/helper/darwin-arm64" "$ov_repo/scripts/helper/aarch64"
echo tracked > "$ov_repo/scripts/assets/a.txt"
echo project > "$ov_repo/scripts/assets/old.tar.gz"
ov_dest=$(mktemp -d)
mkdir -p "$ov_dest/scripts/assets/extras/sub" "$ov_dest/scripts/assets/lang"
ln -s "$ov_repo/scripts/assets/a.txt" "$ov_dest/scripts/assets/a.txt"
echo dl > "$ov_dest/scripts/assets/PS2Linux.tar.gz"
echo x > "$ov_dest/scripts/assets/extras/sub/x.bin"
echo overlay > "$ov_dest/scripts/assets/old.tar.gz"
echo /Volumes/Games > "$ov_dest/scripts/gamepath.cfg"
status=0
out=$( (set -euo pipefail; build_overlay "$ov_repo" "$ov_dest") 2>&1) || status=$?
if [[ "$status" -eq 0 && -L "$ov_dest/scripts/assets" && "$(cat "$ov_repo/scripts/assets/PS2Linux.tar.gz" 2>/dev/null)" == dl \
    && "$(cat "$ov_repo/scripts/assets/extras/sub/x.bin" 2>/dev/null)" == x && "$(cat "$ov_repo/scripts/assets/old.tar.gz")" == project \
    && "$(cat "$ov_repo/scripts/assets/a.txt")" == tracked && "$(cat "$ov_repo/scripts/gamepath.cfg" 2>/dev/null)" == /Volumes/Games \
    && -L "$ov_dest/scripts/gamepath.cfg" ]]; then
    ok overlay-moves-old-downloads
else
    bad "overlay-moves-old-downloads status=$status out=[$out] $(ls -laR "$ov_repo/scripts" 2>&1 | head -30)"
fi
rm -rf "$ov_repo" "$ov_dest"

# --- the folders the user fills are the project's own folders ------------
# The installers find games and media with find -type f, which skips symlinks.
ov_repo=$(mktemp -d)
mkdir -p "$ov_repo/scripts/helper/darwin-arm64" "$ov_repo/scripts/helper/aarch64" \
    "$ov_repo/games/DVD" "$ov_repo/games/POPS" "$ov_repo/media/music" "$ov_repo/icons/art"
echo iso > "$ov_repo/games/DVD/Game.iso"
echo mp3 > "$ov_repo/media/music/track.mp3"
echo png > "$ov_repo/icons/art/APP.png"
ov_dest=$(mktemp -d)
status=0
build_overlay "$ov_repo" "$ov_dest" 2>/dev/null || status=$?
# Game-Installer's and Media-Installer's own detection expressions.
games=$(find "$ov_dest/games/DVD/" -maxdepth 1 -type f ! -path '*/.*' -iname "*.iso" 2>/dev/null) || true
music=$(find "$ov_dest/media/music/" -type f ! -name ".*" \( -iname "*.mp3" -o -iname "*.flac" \) 2>/dev/null) || true
art=$(find "$ov_dest/icons/art" -maxdepth 1 -type f 2>/dev/null) || true
if [[ "$status" -eq 0 && "$games" == */Game.iso && "$music" == */track.mp3 && "$art" == */APP.png ]]; then
    ok overlay-user-dirs-found-by-find
else
    bad "overlay-user-dirs-found-by-find status=$status games=[$games] music=[$music] art=[$art]"
fi
echo vcd > "$ov_dest/games/POPS/New.VCD" 2>/dev/null || true
if [[ "$(cat "$ov_repo/games/POPS/New.VCD" 2>/dev/null)" == vcd ]]; then
    ok overlay-user-dirs-write-to-project
else
    bad overlay-user-dirs-write-to-project
fi
rm -rf "$ov_dest"

# An overlay from an older version has games/ as a folder of symlinks.
ov_dest=$(mktemp -d)
mkdir -p "$ov_dest/games/DVD"
ln -s "$ov_repo/games/DVD/Game.iso" "$ov_dest/games/DVD/Game.iso"
status=0
build_overlay "$ov_repo" "$ov_dest" 2>/dev/null || status=$?
if [[ "$status" -eq 0 && -L "$ov_dest/games" && "$(cat "$ov_dest/games/DVD/Game.iso" 2>/dev/null)" == iso ]]; then
    ok overlay-replaces-old-user-dir
else
    bad "overlay-replaces-old-user-dir status=$status $(ls -la "$ov_dest/games" 2>&1)"
fi
rm -rf "$ov_dest"

# Files someone copied into that old folder are never deleted. enter.sh
# runs build_overlay under set -euo pipefail; the message must still print.
ov_dest=$(mktemp -d)
mkdir -p "$ov_dest/games/DVD"
echo copy > "$ov_dest/games/DVD/Copy.iso"
for n in 1 2 3 4 5 6 7 8; do echo copy > "$ov_dest/games/DVD/More$n.iso"; done
status=0
out=$( (set -euo pipefail; build_overlay "$ov_repo" "$ov_dest") 2>&1) || status=$?
if [[ "$status" -ne 0 && "$(cat "$ov_dest/games/DVD/Copy.iso" 2>/dev/null)" == copy \
    && "$out" == *"$ov_dest/games holds 9 file(s)"* && "$out" == *"They belong in $ov_repo/games."* ]]; then
    ok overlay-keeps-files-in-old-user-dir
else
    bad "overlay-keeps-files-in-old-user-dir status=$status out=[$out]"
fi
rm -rf "$ov_dest"

# Game-Installer also cached art in the old icons/ folder. One stop names
# every folder, so the user does not clear one and hit the next.
ov_dest=$(mktemp -d)
mkdir -p "$ov_dest/games/DVD" "$ov_dest/icons/art"
echo copy > "$ov_dest/games/DVD/Copy.iso"
echo art > "$ov_dest/icons/art/SLUS_000.01.png"
status=0
out=$( (set -euo pipefail; build_overlay "$ov_repo" "$ov_dest") 2>&1) || status=$?
if [[ "$status" -ne 0 && "$out" == *"$ov_dest/games holds 1 file(s)"* && "$out" == *"$ov_dest/icons holds 1 file(s)"* ]]; then
    ok overlay-names-every-old-user-dir
else
    bad "overlay-names-every-old-user-dir status=$status out=[$out]"
fi
rm -rf "$ov_repo" "$ov_dest"

# --- first launch: Setup.sh installs the packages after enter.sh started ---
# brew --prefix NAME prints where NAME goes even before it is installed.
fl=$(mktemp -d)
mkdir -p "$fl/repo/scripts/platform" "$fl/fakebin" "$fl/brew/opt" "$fl/tmp"
cp -R "$root" "$fl/repo/scripts/platform/"
cp "$root/../load.sh" "$fl/repo/scripts/platform/"
cat > "$fl/fakebin/brew" << EOF
#!/bin/bash
[[ "\$1" == --prefix ]] || exit 1
shift
[[ \$# -eq 0 ]] && { echo "$fl/brew"; exit 0; }
for f; do echo "$fl/brew/opt/\$f"; done
EOF
chmod +x "$fl/fakebin/brew"
# The front door's place: Setup.sh installs the packages, then it looks for them.
cat > "$fl/repo/PSBBN-Definitive-Patch.sh" << EOF
#!/bin/bash
mkdir -p "$fl/brew/opt/icu4c/lib/pkgconfig" "$fl/brew/opt/coreutils/libexec/gnubin" "$fl/brew/opt/e2fsprogs/sbin"
printf 'Name: icu-i18n\nDescription: test\nVersion: 78\n' > "$fl/brew/opt/icu4c/lib/pkgconfig/icu-i18n.pc"
printf '#!/bin/sh\n' > "$fl/brew/opt/coreutils/libexec/gnubin/psbbn-gnu-tool"
printf '#!/bin/sh\n' > "$fl/brew/opt/e2fsprogs/sbin/psbbn-e2-tool"
chmod +x "$fl/brew/opt/coreutils/libexec/gnubin/psbbn-gnu-tool" "$fl/brew/opt/e2fsprogs/sbin/psbbn-e2-tool"
pkg-config --exists icu-i18n && echo icu-found || echo icu-missing
command -v psbbn-gnu-tool >/dev/null && echo gnubin-found || echo gnubin-missing
command -v psbbn-e2-tool >/dev/null && echo e2fsprogs-found || echo e2fsprogs-missing
EOF
chmod +x "$fl/repo/PSBBN-Definitive-Patch.sh"
out=$(PATH="$fl/fakebin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin" TMPDIR="$fl/tmp" PKG_CONFIG_PATH="" \
    PSBBN_MOUNT_STATE="$fl/state" PSBBN_MAPPER_DIR="$fl/maps" PSBBN_DM_STATE="$fl/dm" PSBBN_STORAGE_DIR="$fl/storage" \
    "$fl/repo/scripts/platform/darwin/enter.sh" 2>&1 < /dev/null) || true
if [[ "$out" == *icu-found* && "$out" == *gnubin-found* && "$out" == *e2fsprogs-found* ]]; then
    ok enter-finds-packages-installed-later
else
    bad "enter-finds-packages-installed-later [$out]"
fi
rm -rf "$fl"

# The front door runs grep before Setup.sh (the WSL check). GNU grep only
# appears once Setup.sh ran, and get_latest_file needs grep -P. This runs the
# front door's own Setup block.
fd=$(mktemp -d)
mkdir -p "$fd/gnubin" "$fd/scripts"
block=$(awk '/^if ! check_dep; then$/ { f = 1 } f { print } f && /^fi$/ { exit }' "$root/../../../PSBBN-Definitive-Patch.sh")
cat > "$fd/scripts/Setup.sh" << EOF
#!/bin/bash
printf '#!/bin/sh\necho gnu-grep\n' > "$fd/gnubin/grep"
chmod +x "$fd/gnubin/grep"
EOF
chmod +x "$fd/scripts/Setup.sh"
out=$(PATH="$fd/gnubin:/usr/bin:/bin" TOOLKIT_PATH="$fd" BLOCK="$block" /opt/homebrew/bin/bash -c '
    calls=0
    check_dep() { calls=$((calls + 1)); [[ $calls -gt 1 ]]; }
    error_msg() { echo "error_msg $*"; exit 1; }
    grep -q x <<< x
    eval "$BLOCK"
    grep -oP x <<< x 2>/dev/null || echo bsd-grep' 2>&1) || true
if [[ -n "$block" && "$out" == gnu-grep ]]; then
    ok front-door-forgets-command-paths-after-setup
else
    bad "front-door-forgets-command-paths-after-setup [$out]"
fi
rm -rf "$fd"

# On macOS the maps live in platform_mapper_dir, not /dev/mapper. A literal
# /dev/mapper in an installer is a path that does not exist there.
hard=$(grep -n '/dev/mapper' "$root/../../"*.sh "$root/../../../PSBBN-Definitive-Patch.sh") || true
if [[ -z "$hard" ]]; then
    ok installers-ask-platform-for-mapper-dir
else
    bad "installers-ask-platform-for-mapper-dir $hard"
fi

# --- pops2cue gives back the BIN+CUE that cue2pops made the VCD from -------
pc=$(mktemp -d)
helper="$root/../../helper/darwin-arm64"
mkdir -p "$pc/out"
python3 -c 'import os, sys; open(sys.argv[1], "wb").write(os.urandom(2352 * 600))' "$pc/Game.bin"
printf 'FILE "Game.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n  TRACK 02 AUDIO\n    INDEX 00 00:02:00\n    INDEX 01 00:04:00\n  TRACK 03 AUDIO\n    INDEX 00 00:05:10\n    INDEX 01 00:07:10\n' > "$pc/Game.cue"
# cue2pops opens the BIN relative to the current folder.
(cd "$pc" && "$helper/cue2pops" Game.cue Game.VCD < /dev/null > /dev/null 2>&1) || true
cp "$pc/Game.VCD" "$pc/out/" 2>/dev/null || true
status=0
"$helper/pops2cue" "$pc/out/Game.VCD" > "$pc/pops2cue.out" 2>&1 || status=$?
cue_in=$(sed 's/^ *//' "$pc/Game.cue")
cue_out=$(sed 's/^ *//' "$pc/out/Game.cue" 2>/dev/null) || true
if [[ "$status" -eq 0 && "$cue_out" == "$cue_in" ]] && cmp -s "$pc/Game.bin" "$pc/out/Game.bin"; then
    ok pops2cue-roundtrip
else
    bad "pops2cue-roundtrip status=$status cue=[$cue_out] $(tail -n 3 "$pc/pops2cue.out" 2>/dev/null)"
fi
rm -rf "$pc"

# --- tar reads the archive once, front to back ------------------------------
# A second read of a member seeks back in the compressed stream, and gzip
# can only do that by decompressing again from the start: PS2Linux.tar.gz
# took over an hour that way. A pipe allows no way back, so an extract fed
# through one proves the single pass.
once=$(mktemp -d)
dd if=/dev/zero of="$once/slice" bs=1048576 count=32 status=none 2>/dev/null
psbbn_format_ext2_file "$once/slice" >/dev/null
printf 'device=%s\nstart=0\nsectors=65536\n' "$once/slice" > "$once/slice.meta"
mkdir -p "$once/storage/__linux.3" "$once/state" "$once/src/etc"
# Random 1 MiB members: larger than any read buffer, so a second read of a
# member has to seek back in the stream itself.
for i in 1 2 3 4 5 6; do head -c 1048576 /dev/urandom > "$once/src/etc/blob$i"; done
/usr/bin/tar -czf "$once/archive.tar.gz" -C "$once/src" etc
once_rc=0
PSBBN_MOUNT_STATE="$once/state" "$bin/mount" "$once/slice" "$once/storage/__linux.3" > "$once/out" 2>&1 || once_rc=$?
if [[ "$once_rc" -eq 0 ]]; then
    mkfifo "$once/pipe"
    cat "$once/archive.tar.gz" > "$once/pipe" &
    PSBBN_MOUNT_STATE="$once/state" "$bin/tar" zxpf "$once/pipe" -C "$once/storage/__linux.3" >> "$once/out" 2>&1 || once_rc=$?
    wait
fi
"$dbg" -R 'dump /etc/blob6 '"$once/image-blob6" "$once/slice" >/dev/null 2>&1 || true
if [[ "$once_rc" -eq 0 ]] && cmp -s "$once/src/etc/blob6" "$once/image-blob6" \
    && cmp -s "$once/src/etc/blob1" "$once/storage/__linux.3/etc/blob1" \
    && cmp -s "$once/src/etc/blob6" "$once/storage/__linux.3/etc/blob6"; then
    ok tar-reads-archive-once
else
    bad "tar-reads-archive-once rc=$once_rc host=$(ls "$once/storage/__linux.3/etc" 2>/dev/null | tr '\n' ' ') $(tail -n 3 "$once/out")"
fi
PSBBN_MOUNT_STATE="$once/state" "$bin/umount" "$once/storage/__linux.3" >/dev/null 2>&1 || true
rm -rf "$once"

# gzip allows a file of several members back to back (pigz, or pieces
# compressed apart and joined); GNU tar on Linux reads them as one stream.
# One cut falls inside a file, the other on a tar header: ustar puts etc/ at
# 0 and each 512 KiB blob's header 512 + 524288 bytes after the last.
for cut in 700000 525312; do
    multi=$(mktemp -d)
    dd if=/dev/zero of="$multi/slice" bs=1048576 count=16 status=none 2>/dev/null
    psbbn_format_ext2_file "$multi/slice" >/dev/null
    printf 'device=%s\nstart=0\nsectors=32768\n' "$multi/slice" > "$multi/slice.meta"
    mkdir -p "$multi/storage/__linux.3" "$multi/state" "$multi/src/etc"
    for i in 1 2 3 4; do head -c 524288 /dev/urandom > "$multi/src/etc/blob$i"; done
    python3 - "$multi/src" "$multi/archive.tar" << 'PY'
import os, sys, tarfile
src, archive = sys.argv[1:3]
with tarfile.open(archive, "w", format=tarfile.USTAR_FORMAT) as tf:
    tf.add(os.path.join(src, "etc"), "etc", recursive=False)
    for i in range(1, 5):
        tf.add(os.path.join(src, "etc", "blob%d" % i), "etc/blob%d" % i)
PY
    head -c "$cut" "$multi/archive.tar" | gzip -c > "$multi/archive.tar.gz"
    tail -c +"$((cut + 1))" "$multi/archive.tar" | gzip -c >> "$multi/archive.tar.gz"
    multi_rc=0
    PSBBN_MOUNT_STATE="$multi/state" "$bin/mount" "$multi/slice" "$multi/storage/__linux.3" > "$multi/out" 2>&1 || multi_rc=$?
    if [[ "$multi_rc" -eq 0 ]]; then
        mkfifo "$multi/pipe"
        cat "$multi/archive.tar.gz" > "$multi/pipe" &
        PSBBN_MOUNT_STATE="$multi/state" timeout 60 "$bin/tar" zxpf "$multi/pipe" -C "$multi/storage/__linux.3" >> "$multi/out" 2>&1 || multi_rc=$?
        # A reader that hung leaves cat blocked on the pipe.
        kill %% 2>/dev/null || true
        wait 2>/dev/null || true
    fi
    "$dbg" -R 'dump /etc/blob4 '"$multi/image-blob4" "$multi/slice" >/dev/null 2>&1 || true
    if [[ "$multi_rc" -eq 0 ]] && cmp -s "$multi/src/etc/blob4" "$multi/image-blob4" \
        && cmp -s "$multi/src/etc/blob4" "$multi/storage/__linux.3/etc/blob4"; then
        ok "tar-reads-multi-member-gzip-$cut"
    else
        bad "tar-reads-multi-member-gzip-$cut rc=$multi_rc host=$(ls "$multi/storage/__linux.3/etc" 2>/dev/null | tr '\n' ' ') $(tail -n 3 "$multi/out")"
    fi
    PSBBN_MOUNT_STATE="$multi/state" "$bin/umount" "$multi/storage/__linux.3" >/dev/null 2>&1 || true
    rm -rf "$multi"
done

# PS2Linux.tar.gz names some files in Latin-1. The bytes are not UTF-8, so
# APFS cannot hold them, but ext2 can and the PS2 expects them as they are.
latin=$(mktemp -d)
dd if=/dev/zero of="$latin/slice" bs=1048576 count=16 status=none 2>/dev/null
psbbn_format_ext2_file "$latin/slice" >/dev/null
printf 'device=%s\nstart=0\nsectors=32768\n' "$latin/slice" > "$latin/slice.meta"
mkdir -p "$latin/storage/__linux.3" "$latin/state"
python3 - "$latin/archive.tar.gz" << 'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz", format=tarfile.GNU_FORMAT,
                  encoding="utf-8", errors="surrogateescape") as tf:
    for name, data in (("doc/caf\udce9.txt", b"latin-1 name\n"), ("doc/plain.txt", b"plain\n")):
        info = tarfile.TarInfo(name)
        info.size, info.mode, info.mtime = len(data), 0o644, 1700000000
        tf.addfile(info, io.BytesIO(data))
PY
latin_rc=0
PSBBN_MOUNT_STATE="$latin/state" "$bin/mount" "$latin/slice" "$latin/storage/__linux.3" > "$latin/out" 2>&1 || latin_rc=$?
[[ "$latin_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$latin/state" "$bin/tar" zxpf "$latin/archive.tar.gz" -C "$latin/storage/__linux.3" >> "$latin/out" 2>&1 || latin_rc=$?; }
[[ "$latin_rc" -eq 0 ]] && { PSBBN_MOUNT_STATE="$latin/state" "$bin/umount" "$latin/storage/__linux.3" >> "$latin/out" 2>&1 || latin_rc=$?; }
latin_got=$(LC_ALL=C "$dbg" -R "$(printf 'cat /doc/caf\351.txt')" "$latin/slice" 2>/dev/null || true)
latin_fsck=0
/opt/homebrew/opt/e2fsprogs/sbin/e2fsck -fn "$latin/slice" >/dev/null 2>&1 || latin_fsck=$?
if [[ "$latin_rc" -eq 0 && "$latin_got" == "latin-1 name" && "$latin_fsck" -eq 0 ]]; then
    ok tar-ext2-keeps-latin1-names
else
    bad "tar-ext2-keeps-latin1-names rc=$latin_rc got=[$latin_got] fsck=$latin_fsck $(tail -n 4 "$latin/out")"
fi
rm -rf "$latin"

# --- a stage whose folder was deleted writes nothing back -------------------
# HOSDMenu-, Media-Installer and Extras delete STORAGE_DIR when they start,
# before their own clean_up unmounts what an earlier, failed option left.
# A missing folder must not read as "every file was deleted".
gone=$(mktemp -d)
dd if=/dev/zero of="$gone/slice" bs=1048576 count=16 status=none 2>/dev/null
psbbn_format_ext2_file "$gone/slice" >/dev/null
printf 'keep me\n' > "$gone/keep.txt"
"$dbg" -w -R "write $gone/keep.txt keep.txt" "$gone/slice" >/dev/null 2>&1
printf 'device=%s\nstart=0\nsectors=32768\n' "$gone/slice" > "$gone/slice.meta"
mkdir -p "$gone/storage/__linux.4" "$gone/state"
gone_rc=0
PSBBN_MOUNT_STATE="$gone/state" "$bin/mount" "$gone/slice" "$gone/storage/__linux.4" > "$gone/out" 2>&1 || gone_rc=$?
rm -rf "$gone/storage"
gone_err=$(PSBBN_MOUNT_STATE="$gone/state" "$bin/umount" "$gone/storage/__linux.4" 2>&1) || gone_rc=$?
gone_keep=$("$dbg" -R 'cat keep.txt' "$gone/slice" 2>/dev/null || true)
if [[ "$gone_rc" -eq 0 && "$gone_keep" == "keep me" && "$gone_err" == *"nothing"* ]] \
    && [[ -z "$(PSBBN_MOUNT_STATE="$gone/state" "$bin/findmnt" -nr -o TARGET | grep -F "$gone/storage")" ]]; then
    ok umount-gone-folder-writes-nothing
else
    bad "umount-gone-folder-writes-nothing rc=$gone_rc keep=[$gone_keep] err=[$gone_err]"
fi
# The PFS stage of SammyCola's repeat install: pfsshell is never started.
mkdir -p "$gone/pfs-state"
gone_key=$(psbbn_mount_key "$gone/storage/__common")
printf '%s\n' "$gone/no-such-drive" > "$gone/pfs-state/$gone_key"
printf 'pfs\n' > "$gone/pfs-state/$gone_key.kind"
printf '%s\n' "$gone/storage/__common" > "$gone/pfs-state/$gone_key.mount"
printf '__common\n' > "$gone/pfs-state/$gone_key.part"
gone_rc=0
gone_err=$(PSBBN_PFSSHELL=/usr/bin/false PSBBN_MOUNT_STATE="$gone/pfs-state" "$bin/umount" "$gone/storage/__common" 2>&1) || gone_rc=$?
if [[ "$gone_rc" -eq 0 && ! -f "$gone/pfs-state/$gone_key" && "$gone_err" != *Traceback* ]]; then
    ok umount-gone-pfs-folder
else
    bad "umount-gone-pfs-folder rc=$gone_rc err=[$gone_err]"
fi
rm -rf "$gone"

# --- a slice still mounted is written back before dmsetup drops it ---------
# Linux has the files on the drive the moment they are copied; here they go
# at unmount. When clean_up's unmount loop stops early it still removes
# every map, and the stages left behind lost their slices ("slice ...
# vanished during this run").
busy=$(mktemp -d)
mkdir -p "$busy/maps" "$busy/dm" "$busy/state" "$busy/storage/__linux.1"
dd if=/dev/zero of="$busy/drive" bs=1048576 count=16 status=none 2>/dev/null
psbbn_format_ext2_file "$busy/drive" >/dev/null
busy_env=(PSBBN_MAPPER_DIR="$busy/maps" PSBBN_DM_STATE="$busy/dm" PSBBN_MOUNT_STATE="$busy/state")
busy_create() {
    printf '%s\n' "drive-__linux.1,,,rw,0 32768 linear $busy/drive 0" | env "${busy_env[@]}" "$bin/dmsetup" create --concise
}
busy_rc=0
busy_create || busy_rc=$?
env "${busy_env[@]}" "$bin/mount" "$busy/maps/drive-__linux.1" "$busy/storage/__linux.1" > "$busy/out" 2>&1 || busy_rc=$?
printf 'staged\n' > "$busy/storage/__linux.1/added.txt"
env "${busy_env[@]}" "$bin/dmsetup" remove -f drive-__linux.1 >> "$busy/out" 2>&1 || busy_rc=$?
busy_got=$("$dbg" -R 'cat added.txt' "$busy/drive" 2>/dev/null || true)
if [[ "$busy_rc" -eq 0 && "$busy_got" == staged && ! -e "$busy/maps/drive-__linux.1" ]] \
    && [[ -z "$(env "${busy_env[@]}" "$bin/findmnt" -nr -o TARGET | grep -F "$busy/storage")" ]]; then
    ok dmsetup-remove-writes-back-mounted-slice
else
    bad "dmsetup-remove-writes-back-mounted-slice rc=$busy_rc got=[$busy_got] $(tail -n 3 "$busy/out")"
fi
# Media-Installer maps the drive again with a stage still up: the new map
# must not start from an empty slice under it.
busy_rc=0
busy_create || busy_rc=$?
env "${busy_env[@]}" "$bin/mount" "$busy/maps/drive-__linux.1" "$busy/storage/__linux.1" > "$busy/out" 2>&1 || busy_rc=$?
printf 'second\n' > "$busy/storage/__linux.1/second.txt"
busy_create >> "$busy/out" 2>&1 || busy_rc=$?
busy_got=$("$dbg" -R 'cat second.txt' "$busy/drive" 2>/dev/null || true)
if [[ "$busy_rc" -eq 0 && "$busy_got" == second ]] \
    && [[ -z "$(env "${busy_env[@]}" "$bin/findmnt" -nr -o TARGET | grep -F "$busy/storage")" ]]; then
    ok dmsetup-create-writes-back-mounted-slice
else
    bad "dmsetup-create-writes-back-mounted-slice rc=$busy_rc got=[$busy_got] $(tail -n 3 "$busy/out")"
fi
# The write-back fails: plain remove leaves everything as it was (Linux:
# device busy). -f drops the stage, so the next run is not stuck on it, and
# still fails busy, as Linux does with the mount up: clean_up stops before
# it deletes STORAGE_DIR, the only copy of what was not written.
env "${busy_env[@]}" "$bin/mount" "$busy/maps/drive-__linux.1" "$busy/storage/__linux.1" > "$busy/out" 2>&1 || true
printf 'lost\n' > "$busy/storage/__linux.1/lost.txt"
mv "$busy/drive" "$busy/drive.away"
busy_rc=0
env "${busy_env[@]}" "$bin/dmsetup" remove drive-__linux.1 > "$busy/out" 2>&1 || busy_rc=$?
if [[ "$busy_rc" -ne 0 && -e "$busy/maps/drive-__linux.1" && -n "$(env "${busy_env[@]}" "$bin/findmnt" -nr -o TARGET | grep -F "$busy/storage")" ]]; then
    ok dmsetup-remove-busy-keeps-stage
else
    bad "dmsetup-remove-busy-keeps-stage rc=$busy_rc $(cat "$busy/out")"
fi
busy_rc=0
busy_err=$(env "${busy_env[@]}" "$bin/dmsetup" remove -f drive-__linux.1 2>&1) || busy_rc=$?
busy_again=0
env "${busy_env[@]}" "$bin/dmsetup" remove -f drive-__linux.1 >/dev/null 2>&1 || busy_again=$?
if [[ "$busy_rc" -ne 0 && "$busy_err" == *"not written back"* && "$busy_err" == *busy* \
    && -f "$busy/storage/__linux.1/lost.txt" && "$busy_again" -eq 0 && ! -e "$busy/maps/drive-__linux.1" ]] \
    && [[ -z "$(env "${busy_env[@]}" "$bin/findmnt" -nr -o TARGET | grep -F "$busy/storage")" ]]; then
    ok dmsetup-remove-force-drops-stage
else
    bad "dmsetup-remove-force-drops-stage rc=$busy_rc again=$busy_again err=[$busy_err]"
fi
rm -rf "$busy"

# --- a whole-disk dd that macOS refused as busy is tried again -------------
# "dd: /dev/rdisk4: Resource busy": Disk Arbitration landed a mount between
# the eviction and the open. Nothing was written; the open is retried.
ebusy=$(mktemp -d)
cat > "$ebusy/dd" << EOF
#!/bin/bash
n=\$(cat "$ebusy/calls" 2>/dev/null || echo 0)
echo \$((n + 1)) > "$ebusy/calls"
if [[ \$n -lt 2 ]]; then echo "dd: /dev/rdisk5: Resource busy" >&2; exit 1; fi
exit 0
EOF
printf '#!/bin/bash\nexec "$@"\n' > "$ebusy/sudo"
python3 - "$ebusy/diskutil" << 'PY'
import plistlib, sys
info = plistlib.dumps({"Internal": False, "Size": 1 << 30, "TotalSize": 1 << 30}).decode()
open(sys.argv[1], "w").write('#!/bin/bash\nif [[ "$1" == info ]]; then cat << \'EOF\'\n' + info + 'EOF\nexit 0; fi\nexit 1\n')
PY
chmod +x "$ebusy/dd" "$ebusy/sudo" "$ebusy/diskutil"
: > "$ebusy/table"
head -c 4096 /dev/urandom > "$ebusy/src"
ebusy_rc=0
ebusy_err=$(PSBBN_DD="$ebusy/dd" PSBBN_SUDO="$ebusy/sudo" PSBBN_DISKUTIL="$ebusy/diskutil" PSBBN_MOUNT_TABLE="$ebusy/table" PSBBN_DA_SETTLE=0 \
    /opt/homebrew/bin/bash -c '. "$1"; psbbn_dd_ranges elevate "$2" /dev/rdisk5 "0:0:8"' _ "$root/../load.sh" "$ebusy/src" 2>&1) || ebusy_rc=$?
if [[ "$ebusy_rc" -eq 0 && "$(cat "$ebusy/calls")" -eq 3 ]]; then
    ok dd-ranges-retries-busy-open
else
    bad "dd-ranges-retries-busy-open rc=$ebusy_rc calls=$(cat "$ebusy/calls" 2>/dev/null) err=[$ebusy_err]"
fi
# Any other failure is not retried.
cat > "$ebusy/dd" << EOF
#!/bin/bash
n=\$(cat "$ebusy/calls" 2>/dev/null || echo 0)
echo \$((n + 1)) > "$ebusy/calls"
echo "dd: /dev/rdisk5: Input/output error" >&2
exit 1
EOF
echo 5 > "$ebusy/calls"
ebusy_rc=0
PSBBN_DD="$ebusy/dd" PSBBN_SUDO="$ebusy/sudo" PSBBN_DISKUTIL="$ebusy/diskutil" PSBBN_MOUNT_TABLE="$ebusy/table" PSBBN_DA_SETTLE=0 \
    /opt/homebrew/bin/bash -c '. "$1"; psbbn_dd_ranges elevate "$2" /dev/rdisk5 "0:0:8"' _ "$root/../load.sh" "$ebusy/src" >/dev/null 2>&1 || ebusy_rc=$?
if [[ "$ebusy_rc" -ne 0 && "$(cat "$ebusy/calls")" -eq 6 ]]; then
    ok dd-ranges-no-retry-other-errors
else
    bad "dd-ranges-no-retry-other-errors rc=$ebusy_rc calls=$(cat "$ebusy/calls" 2>/dev/null)"
fi
rm -rf "$ebusy"

# --- the PSBBN databases are SQLite 2 ---------------------------------------
# music.db, photo.db and movie.db on the drive are SQLite 2.1 files and the
# Linux helper is SQLite 2.8.17. SQLite 3 cannot read them ("file is not a
# database") and writes files PSBBN cannot read. This is Media-Installer's
# round trip: dump, add a row before COMMIT, load into a new file.
sq=$(mktemp -d)
sqlite2="$root/../../helper/darwin-arm64/sqlite"
sq_ver=$("$sqlite2" -version 2>&1 || true)
sq_err=$("$sqlite2" "$root/../../assets/music/music.db" .dump 2>&1 > "$sq/dump.sql") || true
awk '/^COMMIT;/ { print "INSERT INTO SCEI_Jukebox (trackno, songname) VALUES(1, '"'"'Rehearsal'"'"');" } { print }' "$sq/dump.sql" > "$sq/rebuilt.sql"
sq_load=$("$sqlite2" "$sq/new.db" < "$sq/rebuilt.sql" 2>&1) || true
sq_head=$(head -c 47 "$sq/new.db" 2>/dev/null || true)
sq_row=$("$sqlite2" "$sq/new.db" 'SELECT songname FROM SCEI_Jukebox WHERE trackno = 1;' 2>&1 || true)
if [[ "$sq_ver" == 2.8.17 && -z "$sq_err" && -z "$sq_load" && "$(head -n 1 "$sq/dump.sql")" == "BEGIN TRANSACTION;" \
    && "$sq_head" == "** This file contains an SQLite 2.1 database **" && "$sq_row" == Rehearsal ]]; then
    ok sqlite-is-sqlite2
else
    bad "sqlite-is-sqlite2 version=[$sq_ver] dump=[$sq_err] load=[$sq_load] head=[$sq_head] row=[$sq_row]"
fi
rm -rf "$sq"

# --- with or without sudo, the session runs as the user ---------------------
# State the shims keep in /tmp is the invoking user's. dmsetup's was one
# folder for everybody.
dm_dir=$(env -u PSBBN_DM_STATE /opt/homebrew/bin/bash -c '. "$1"; psbbn_dm_state_dir' _ "$root/lib.sh" 2>&1) || true
[[ "$dm_dir" == "/tmp/psbbn-dm-$UID" ]] && ok dm-state-per-user || bad "dm-state-per-user [$dm_dir]"
dm_dir=$(env -u PSBBN_DM_STATE SUDO_UID=4321 /opt/homebrew/bin/bash -c '. "$1"; psbbn_dm_state_dir' _ "$root/lib.sh" 2>&1) || true
[[ "$dm_dir" == "/tmp/psbbn-dm-4321" ]] && ok dm-state-follows-sudo-uid || bad "dm-state-follows-sudo-uid [$dm_dir]"
paths=$(env -u PSBBN_MOUNT_STATE -u PSBBN_MAPPER_DIR -u PSBBN_DM_STATE PSBBN_REPO=/some/repo \
    /opt/homebrew/bin/bash -c '. "$1"; psbbn_user_paths 4321' _ "$root/lib.sh" 2>&1) || true
want=$(printf '%s\n' /tmp/psbbn-mounts-4321 /tmp/psbbn-mapper-4321 /tmp/psbbn-dm-4321 /tmp/psbbn-storage-4321 /some/repo)
[[ "$paths" == "$want" ]] && ok user-paths || bad "user-paths [$paths]"
# The project reached through a link: find does not walk a link it is given.
up=$(mktemp -d)
mkdir -p "$up/real"
ln -s "$up/real" "$up/link"
paths=$(PSBBN_REPO="$up/link" /opt/homebrew/bin/bash -c '. "$1"; psbbn_user_paths 4321' _ "$root/lib.sh" 2>&1 | tail -n 1) || true
[[ "$paths" == "$(cd -P "$up/real" && pwd -P)" ]] && ok user-paths-project-behind-link || bad "user-paths-project-behind-link [$paths]"
rm -rf "$up"

# A run under sudo left these owned by root; the user's next run could not
# write its own state. What root owns is handed back, nothing else. The
# test's own files stand in for root's (PSBBN_CLAIM_FROM). The recorder
# notes the folder chown ran in and its arguments.
claim=$(mktemp -d)
claim_p=$(cd -P "$claim" && pwd -P)
mkdir -p "$claim/state/sub" "$claim/other"
: > "$claim/state/sub/rec"
# Another name of a file anywhere else: chown would change that file too.
: > "$claim/state/sub/linked"
ln "$claim/state/sub/linked" "$claim/other/elsewhere"
printf '#!/bin/bash\nprintf "%%s|%%s\\n" "$(pwd -P)" "$*" >> "%s/chown.rec"\n' "$claim" > "$claim/chown"
printf '#!/bin/bash\nexec "$@"\n' > "$claim/run-sudo"
chmod +x "$claim/chown" "$claim/run-sudo"
claim_env=(PSBBN_SUDO="$claim/run-sudo" PSBBN_CHOWN="$claim/chown" PSBBN_CLAIM_FROM="$(id -u)")
env "${claim_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_claim_paths 4321 20 "$2" "$3/missing"' _ "$root/../load.sh" "$claim/state" "$claim" 2>/dev/null || true
claim_got=$(sort "$claim/chown.rec" 2>/dev/null | tr '\n' ' ') || true
claim_want=$(printf '%s\n' "$claim_p/state|-h -- 4321:20 ." "$claim_p/state|-h -- 4321:20 sub" "$claim_p/state/sub|-h -- 4321:20 rec" | sort | tr '\n' ' ')
if [[ "$claim_got" == "$claim_want" ]]; then
    ok claim-hands-back-roots-files
else
    bad "claim-hands-back-roots-files [$(cat "$claim/chown.rec" 2>/dev/null)]"
fi
: > "$claim/chown.rec"
env "${claim_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_claim_paths "$(id -u)" "$(id -g)" "$2"' _ "$root/../load.sh" "$claim/state" || true
[[ ! -s "$claim/chown.rec" ]] && ok claim-leaves-own-paths || bad "claim-leaves-own-paths [$(cat "$claim/chown.rec" 2>/dev/null)]"
# Anyone can make /tmp/psbbn-dm-UID first. A link there, or a folder others
# can write, is left alone.
ln -s "$claim/state" "$claim/planted-link"
mkdir -p "$claim/open"
: > "$claim/open/x"
chmod 777 "$claim/open"
: > "$claim/chown.rec"
claim_err=$(env "${claim_env[@]}" /opt/homebrew/bin/bash -c '. "$1"; psbbn_claim_paths 4321 20 "$2" "$3"' _ "$root/../load.sh" "$claim/planted-link" "$claim/open" 2>&1) || true
if [[ ! -s "$claim/chown.rec" && "$claim_err" == *planted-link* && "$claim_err" == *open* ]]; then
    ok claim-skips-unsafe-folders
else
    bad "claim-skips-unsafe-folders chown=[$(cat "$claim/chown.rec" 2>/dev/null)] err=[$claim_err]"
fi
# A session that is root itself (sudo su): nothing is handed to root.
: > "$claim/chown.rec"
PSBBN_SUDO="$claim/run-sudo" PSBBN_CHOWN="$claim/chown" /opt/homebrew/bin/bash -c '. "$1"; psbbn_claim_paths 0 0 "$2"' _ "$root/../load.sh" "$claim/state" 2>/dev/null || true
[[ ! -s "$claim/chown.rec" ]] && ok claim-nothing-for-root || bad "claim-nothing-for-root [$(cat "$claim/chown.rec" 2>/dev/null)]"
rm -rf "$claim"

# The sudo ticket is kept fresh while the session lives, then left alone.
# macOS keeps it 5 minutes; a game copy takes longer, and the next password
# prompt landed under a spinner.
ka=$(mktemp -d)
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s/sudo.rec"\n' "$ka" > "$ka/sudo"
chmod +x "$ka/sudo"
sleep 1 &
ka_pid=$!
PSBBN_SUDO_BIN="$ka/sudo" PSBBN_SUDO_REFRESH=0.1 /opt/homebrew/bin/bash -c '. "$1"; psbbn_sudo_keepalive "$2"' _ "$root/lib.sh" "$ka_pid" &
ka_loop=$!
wait "$ka_pid" || true
ka_done=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$ka_loop" 2>/dev/null || { ka_done=1; break; }
    sleep 0.2
done
kill "$ka_loop" 2>/dev/null || true
ka_calls=$(grep -c '^-n -v$' "$ka/sudo.rec" 2>/dev/null || echo 0)
if [[ "$ka_done" -eq 1 && "$ka_calls" -ge 3 ]]; then
    ok sudo-keepalive-while-session-lives
else
    bad "sudo-keepalive-while-session-lives done=$ka_done calls=$ka_calls"
fi
rm -rf "$ka"

# sudo ./PSBBN-Definitive-Patch.sh: enter.sh hands the state back and runs
# the session as the user who typed sudo.
rs=$(mktemp -d)
mkdir -p "$rs/repo/scripts/platform" "$rs/state" "$rs/tmp"
cp -R "$root" "$rs/repo/scripts/platform/"
cp "$root/../load.sh" "$rs/repo/scripts/platform/"
printf '#!/bin/bash\nprintf "uid=%%s euid=%%s\\n" "$(id -u)" "${PSBBN_EUID:-unset}"\n' > "$rs/repo/PSBBN-Definitive-Patch.sh"
chmod +x "$rs/repo/PSBBN-Definitive-Patch.sh"
cat > "$rs/sudo" << EOF
#!/bin/bash
# Stands in for /usr/bin/sudo. Records the drop to the user, then runs the rest.
printf '%s\n' "\$*" >> "$rs/sudo.rec"
[[ "\$1" == -n ]] && exit 0
while [[ "\$1" == -* ]]; do
    case "\$1" in -u|-g) shift 2 ;; *) shift ;; esac
done
exec env -u PSBBN_EUID "\$@"
EOF
printf '#!/bin/bash\nprintf "%%s|%%s\\n" "$(pwd -P)" "$*" >> "%s/chown.rec"\n' "$rs" > "$rs/chown"
chmod +x "$rs/sudo" "$rs/chown"
rs_out=$(PSBBN_EUID=0 SUDO_UID=4321 SUDO_GID=20 SUDO_USER=nobody PSBBN_SUDO_BIN="$rs/sudo" PSBBN_CHOWN="$rs/chown" \
    PSBBN_CLAIM_FROM="$(id -u)" \
    PSBBN_MOUNT_STATE="$rs/state" PSBBN_MAPPER_DIR="$rs/maps" PSBBN_DM_STATE="$rs/dm" PSBBN_STORAGE_DIR="$rs/storage" \
    TMPDIR="$rs/tmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin" \
    "$rs/repo/scripts/platform/darwin/enter.sh" 2>&1 < /dev/null) || true
if grep -q -- "-u #4321" "$rs/sudo.rec" 2>/dev/null && [[ "$rs_out" == *"euid=unset"* ]] \
    && grep -qxF -- "$(cd -P "$rs/state" && pwd -P)|-h -- 4321:20 ." "$rs/chown.rec" 2>/dev/null; then
    ok enter-under-sudo-runs-as-user
else
    bad "enter-under-sudo-runs-as-user out=[$rs_out] sudo=[$(cat "$rs/sudo.rec" 2>/dev/null)] chown=[$(cat "$rs/chown.rec" 2>/dev/null)]"
fi
rm -rf "$rs"

# --- what the installer writes into the project reaches the project --------
ovr=$(mktemp -d)
mkdir -p "$ovr/repo/scripts/assets/lang" "$ovr/repo/games/DVD"
printf 'changes\n' > "$ovr/repo/scripts/assets/lang/changelog_main_eng.txt"
printf 'KEY=value\n' > "$ovr/repo/scripts/assets/lang/eng.txt"
printf '#!/bin/bash\n' > "$ovr/repo/PSBBN-Definitive-Patch.sh"
# An overlay from before this version, with its own logs folder.
mkdir -p "$ovr/dest/logs"
printf 'old run\n' > "$ovr/dest/logs/game-installer.log"
ovr_rc=0
(set -euo pipefail; build_overlay "$ovr/repo" "$ovr/dest") > "$ovr/out" 2>&1 || ovr_rc=$?
# Logs go to the project's logs folder, as on Linux.
if [[ "$ovr_rc" -eq 0 && -L "$ovr/dest/logs" && "$(cat "$ovr/repo/logs/game-installer.log" 2>/dev/null)" == "old run" ]]; then
    printf 'new run\n' >> "$ovr/dest/logs/setup.log"
    [[ -f "$ovr/repo/logs/setup.log" ]] && ok overlay-logs-in-project || bad "overlay-logs-in-project no setup.log in repo"
else
    bad "overlay-logs-in-project rc=$ovr_rc $(cat "$ovr/out")"
fi
# The front door shows the changelog once and deletes it. Linux deletes the
# project's file; deleting the overlay's link only showed it every launch.
rm "$ovr/dest/scripts/assets/lang/changelog_main_eng.txt" 2>/dev/null || true
if [[ ! -e "$ovr/repo/scripts/assets/lang/changelog_main_eng.txt" && -f "$ovr/repo/scripts/assets/lang/eng.txt" ]]; then
    (set -euo pipefail; build_overlay "$ovr/repo" "$ovr/dest") > "$ovr/out" 2>&1 || true
    [[ ! -e "$ovr/dest/scripts/assets/lang/changelog_main_eng.txt" && -f "$ovr/dest/scripts/assets/lang/eng.txt" ]] \
        && ok overlay-changelog-shown-once || bad "overlay-changelog-shown-once came back after rebuild"
else
    bad "overlay-changelog-shown-once repo file still there"
fi
rm -rf "$ovr"

# The update runs in the overlay, whose .git is a link to the project's.
# Git took the overlay for the work tree: HEAD moved to the new commit and
# the project's files stayed as they were, so every later launch ran the
# old scripts while git reported them up to date. This is the front door's
# own git_update, under the environment enter.sh exports.
gu=$(mktemp -d)
gitq() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
gitq init -q "$gu/upstream"
printf 'v1\n' > "$gu/upstream/a.txt"
gitq -C "$gu/upstream" add a.txt
gitq -C "$gu/upstream" commit -qm one
git clone -q "$gu/upstream" "$gu/repo" 2>/dev/null
printf 'v2\n' > "$gu/upstream/a.txt"
gitq -C "$gu/upstream" commit -qam two
mkdir -p "$gu/overlay"
ln -s "$gu/repo/a.txt" "$gu/overlay/a.txt"
ln -s "$gu/repo/.git" "$gu/overlay/.git"
gu_fn=$(awk '/^git_update\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$root/../../../PSBBN-Definitive-Patch.sh")
gu_env=$(/opt/homebrew/bin/bash -c '. "$1"; psbbn_git_env "$2"' _ "$root/lib.sh" "$gu/repo" 2>/dev/null) || true
(
    cd "$gu/overlay" || exit 1
    eval "$gu_env"
    LOG_FILE="$gu/log" wsl=false GU_FN="$gu_fn" /opt/homebrew/bin/bash -c '
        declare -A UI_TEXT
        error_msg() { echo "error_msg $*"; exit 1; }
        eval "$GU_FN"
        git_update' < /dev/null > "$gu/out" 2>&1
) || true
if [[ -n "$gu_fn" && "$(cat "$gu/repo/a.txt")" == v2 && -z "$(git -C "$gu/repo" status --porcelain)" && "$(cat "$gu/overlay/a.txt")" == v2 ]]; then
    ok update-from-overlay-updates-project
else
    bad "update-from-overlay-updates-project repo=$(cat "$gu/repo/a.txt") status=[$(git -C "$gu/repo" status --porcelain)] env=[$gu_env] $(tail -n 3 "$gu/out")"
fi
rm -rf "$gu"

# The installers show where to put games, music and photos. On macOS that
# was the overlay in /tmp, not the project folder the user fills.
dp=$(mktemp -d)
for inst in Game-Installer Media-Installer; do
    fn=$(awk '/^get_display_path\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$root/../../$inst.sh")
    case "$inst" in
        Game-Installer) want="$dp/repo/games" ;;
        *) want="$dp/repo/media/" ;;
    esac
    got=$(PSBBN_REPO="$dp/repo" PSBBN_OVERLAY="$dp/overlay" FN="$fn" GAMES_PATH="$dp/overlay/games" MEDIA_DIR="$dp/overlay/media" \
        /opt/homebrew/bin/bash -c '. "$1"; eval "$FN"; get_display_path; printf "%s" "$display_path"' _ "$root/../load.sh" 2>&1) || true
    [[ -n "$fn" && "$got" == "$want" ]] && ok "display-path-is-project-$inst" || bad "display-path-is-project-$inst [$got]"
done
# A folder the user chose elsewhere is shown as it is.
fn=$(awk '/^get_display_path\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$root/../../Game-Installer.sh")
got=$(PSBBN_REPO="$dp/repo" PSBBN_OVERLAY="$dp/overlay" FN="$fn" GAMES_PATH=/Volumes/Games \
    /opt/homebrew/bin/bash -c '. "$1"; eval "$FN"; get_display_path; printf "%s" "$display_path"' _ "$root/../load.sh" 2>&1) || true
[[ "$got" == /Volumes/Games ]] && ok display-path-keeps-chosen-folder || bad "display-path-keeps-chosen-folder [$got]"
# The installers take their folder from pwd, under enter.sh. macOS TMPDIR
# ends in a slash.
mkdir -p "$dp/full/repo/scripts/platform" "$dp/full/tmp" "$dp/full/fakebin"
cp -R "$root" "$dp/full/repo/scripts/platform/"
cp "$root/../load.sh" "$dp/full/repo/scripts/platform/"
printf '#!/bin/bash\nexit 1\n' > "$dp/full/fakebin/brew"
cat > "$dp/full/repo/PSBBN-Definitive-Patch.sh" << EOF
#!/bin/bash
. "$dp/full/repo/scripts/platform/load.sh"
TOOLKIT_PATH="\$(pwd)"
platform_display_path "\$TOOLKIT_PATH/games"
EOF
chmod +x "$dp/full/fakebin/brew" "$dp/full/repo/PSBBN-Definitive-Patch.sh"
got=$(PATH="$dp/full/fakebin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin" TMPDIR="$dp/full/tmp/" \
    PSBBN_MOUNT_STATE="$dp/full/state" PSBBN_MAPPER_DIR="$dp/full/maps" PSBBN_DM_STATE="$dp/full/dm" PSBBN_STORAGE_DIR="$dp/full/storage" \
    "$dp/full/repo/scripts/platform/darwin/enter.sh" 2>&1 < /dev/null | tail -n 1) || true
[[ "$got" == "$dp/full/repo/games" ]] && ok display-path-under-macos-tmpdir || bad "display-path-under-macos-tmpdir [$got]"
rm -rf "$dp"

# --- Game-Installer cleans up from a folder that stays ----------------------
# It finishes inside icons/art/tmp, and clean_up deletes that folder. Every
# command after that starts in a deleted folder; the macOS shims are bash
# scripts, and bash says so ("shell-init: error retrieving current
# directory") once per command, across the whole screen.
gc=$(mktemp -d)
mkdir -p "$gc/kit/icons/art/tmp" "$gc/kit/icons/ico/tmp" "$gc/kit/scripts/tmp" "$gc/kit/games/APPS" "$gc/bin"
printf '#!/bin/bash\nexec "$@"\n' > "$gc/bin/sudo"
printf '#!/bin/bash\nexit 0\n' > "$gc/bin/findmnt"
chmod +x "$gc/bin/sudo" "$gc/bin/findmnt"
gc_fn=$(awk '/^clean_up\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$root/../../Game-Installer.sh")
gc_err=$(cd "$gc/kit/icons/art/tmp" && TOOLKIT_PATH="$gc/kit" FN="$gc_fn" PATH="$gc/bin:/usr/bin:/bin" /opt/homebrew/bin/bash -c '
    ICONS_DIR="$TOOLKIT_PATH/icons" ARTWORK_DIR="$TOOLKIT_PATH/icons/art" SCRIPTS_DIR="$TOOLKIT_PATH/scripts"
    GAMES_PATH="$TOOLKIT_PATH/games" OPL="$TOOLKIT_PATH/scripts/OPL" STORAGE_DIR="$TOOLKIT_PATH/storage" LOG_FILE=/dev/null
    declare -A UI_TEXT
    unmount_apa() { sudo true; }
    error_msg() { echo "error_msg $*"; }
    eval "$FN"
    clean_up' 2>&1) || true
if [[ -n "$gc_fn" && ! -d "$gc/kit/icons/art/tmp" && "$gc_err" != *getcwd* && "$gc_err" != *shell-init* ]]; then
    ok game-installer-cleans-up-from-a-folder-that-stays
else
    bad "game-installer-cleans-up-from-a-folder-that-stays [$(head -n 2 <<< "$gc_err")]"
fi
rm -rf "$gc"

# --- convert without ImageMagick 7's deprecation warning --------------------
# Homebrew's ImageMagick is 7: every convert, and every magick convert,
# prints "WARNING: The convert command is deprecated in IMv7" and a blank
# line, through Game-Installer's progress bar. Plain magick would parse the
# options its own way, so the command stays convert and only the warning goes.
cv=$(mktemp -d)
cat > "$cv/magick" << 'EOF'
#!/bin/bash
printf '%s\n' "$*" > "${0%/*}/args"
printf 'WARNING: The convert command is deprecated in IMv7, use "magick" instead of "convert" or "magick convert"\n\n' >&2
printf 'real error\n' >&2
printf 'image-bytes'
exit 3
EOF
chmod +x "$cv/magick"
cv_rc=0
cv_out=$(PATH="$bin:$cv:/usr/bin:/bin" "$bin/convert" in.png -resize 64x64 out.png 2> "$cv/err") || cv_rc=$?
if [[ "$cv_rc" -eq 3 && "$cv_out" == image-bytes && "$(cat "$cv/args")" == "convert in.png -resize 64x64 out.png" && "$(cat "$cv/err")" == "real error" ]]; then
    ok convert-drops-im7-deprecation-warning
else
    bad "convert-drops-im7-deprecation-warning rc=$cv_rc out=[$cv_out] args=[$(cat "$cv/args" 2>/dev/null)] err=[$(cat "$cv/err")]"
fi
if command -v /opt/homebrew/bin/magick >/dev/null 2>&1; then
    /opt/homebrew/bin/magick -size 8x8 xc:red "$cv/red.png"
    cv_err=$(PATH="$bin:/opt/homebrew/bin:/usr/bin:/bin" "$bin/convert" "$cv/red.png" -resize 4x4 "$cv/small.png" 2>&1) || true
    [[ -z "$cv_err" && "$(/opt/homebrew/bin/magick identify -format '%wx%h' "$cv/small.png" 2>/dev/null)" == 4x4 ]] \
        && ok convert-real-imagemagick-quiet || bad "convert-real-imagemagick-quiet [$cv_err]"
fi
rm -rf "$cv"

# --- the project's own helpers are not held by Gatekeeper -------------------
# A copy of the project that macOS marked as downloaded made Gatekeeper
# stop every bundled helper ("PSU Extractor.elf" Not Opened) halfway
# through an install. Only the helpers that ship with the project are
# cleared; nothing outside that folder is touched.
gk=$(mktemp -d)
mkdir -p "$gk/repo/scripts/helper/darwin-arm64" "$gk/repo/games"
printf '#!/bin/sh\n' > "$gk/repo/scripts/helper/darwin-arm64/PSU Extractor.elf"
printf 'iso\n' > "$gk/repo/games/game.iso"
for f in "$gk/repo/scripts/helper/darwin-arm64/PSU Extractor.elf" "$gk/repo/games/game.iso"; do
    xattr -w com.apple.quarantine '0081;6700f000;Safari;' "$f"
done
/opt/homebrew/bin/bash -c '. "$1"; psbbn_unquarantine_helpers "$2"' _ "$root/lib.sh" "$gk/repo" > /dev/null 2>&1 || true
if ! xattr -p com.apple.quarantine "$gk/repo/scripts/helper/darwin-arm64/PSU Extractor.elf" >/dev/null 2>&1 \
    && xattr -p com.apple.quarantine "$gk/repo/games/game.iso" >/dev/null 2>&1; then
    ok helpers-unquarantined
else
    bad "helpers-unquarantined $(xattr -l "$gk/repo/scripts/helper/darwin-arm64/PSU Extractor.elf" 2>&1 | head -1)"
fi
rm -rf "$gk"

# --- VMCs for PS2 games -----------------------------------------------------
# Game-Installer compiles helper/genvmc.c with gcc when helper/genvmc is
# missing. genvmc.c copies the 29-byte magic string into the 28-byte magic
# field; Apple clang's fortified strcpy stops that with a trap ("Trace/BPT
# trap: 5") and every VMC is left empty. The overlay links a macOS build,
# over the copy an earlier run compiled, and it must write the same card
# the Linux build does (gcc without optimization, so no fortify).
gv=$(mktemp -d)
mkdir -p "$gv/scripts/helper/aarch64"
printf 'compiled by an earlier run\n' > "$gv/scripts/helper/genvmc"
chmod +x "$gv/scripts/helper/genvmc"
psbbn_link_helpers "$root/../../.." "$gv"
gv_bin="$gv/scripts/helper/genvmc"
gv_want="$(cd "$root/../.." && pwd)/helper/darwin-arm64/genvmc"
if [[ -L "$gv_bin" && "$(readlink "$gv_bin")" == "$gv_want" ]]; then
    ok genvmc-linked-over-compiled
else
    bad "genvmc-linked-over-compiled $(ls -l "$gv_bin" 2>&1)"
fi
gv_rc=0
"$gv_bin" 8 "$gv/SLUS_200.90_0.bin" > "$gv/out" 2>&1 || gv_rc=$?
gv_size=$(wc -c < "$gv/SLUS_200.90_0.bin" 2>/dev/null | tr -d ' ')
gv_magic=$(head -c 40 "$gv/SLUS_200.90_0.bin" 2>/dev/null | LC_ALL=C tr -d '\0')
if [[ "$gv_rc" -eq 0 && "$gv_size" == 8388608 && "$gv_magic" == "Sony PS2 Memory Card Format 1.2.0.0" ]]; then
    ok genvmc-writes-card
else
    bad "genvmc-writes-card rc=$gv_rc size=$gv_size magic=[$gv_magic] $(tail -n 2 "$gv/out")"
fi
# The cards carry the time they were made; both builds run in one second.
if cc -std=gnu99 -D_FORTIFY_SOURCE=0 -o "$gv/genvmc-linux" "$root/../../helper/genvmc.c" 2>"$gv/cc.err"; then
    gv_same=1
    for gv_mb in 8 32; do
        for _ in 1 2 3; do
            gv_t0=$(date +%s)
            "$gv_bin" "$gv_mb" "$gv/mac.bin" >/dev/null 2>&1 || true
            "$gv/genvmc-linux" "$gv_mb" "$gv/linux.bin" >/dev/null 2>&1 || true
            [[ "$(date +%s)" == "$gv_t0" ]] && break
        done
        cmp -s "$gv/mac.bin" "$gv/linux.bin" || gv_same=0
    done
    [[ "$gv_same" -eq 1 ]] && ok genvmc-card-matches-linux-build || bad genvmc-card-matches-linux-build
else
    bad "genvmc-card-matches-linux-build cc: $(head -n 2 "$gv/cc.err")"
fi
# Game-Installer makes a game's card only when there is no file for it, and
# the trapping genvmc left an empty one on the OPL partition for each game.
# Those are made again; a card that holds saves is left alone.
gv_fn=$(awk '/^CREATE_PS2_VMC\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$root/../../Game-Installer.sh")
mkdir -p "$gv/OPL/VMC" "$gv/OPL/CFG" "$gv/OPL/nhddl"
: > "$gv/OPL/VMC/SLUS_200.90_0.bin"
printf 'saves\n' > "$gv/OPL/VMC/SCUS_971.05_0.bin"
printf '%s\n' 'TimeSplitters|SLUS_200.90|Eidos Interactive|CD|TimeSplitters (USA) (v2.00).zso|' \
    'Fantavision|SCUS_971.05|Sony Computer Entertainment|DVD|Fantavision.zso|' > "$gv/ps2.list"
(
    cd "$gv" || exit 1
    HELPER_DIR="$gv/scripts/helper" ASSETS_DIR="$root/../../assets" TOOLKIT_PATH="$gv" OPL="$gv/OPL" \
        LOG_FILE="$gv/vmc.log" PS2_LIST="$gv/ps2.list" FN="$gv_fn" /opt/homebrew/bin/bash -c '
        declare -A UI_TEXT
        SPLASH() { :; }
        show_progress() { :; }
        error_msg() { echo "error_msg $*"; }
        eval "$FN"
        CREATE_PS2_VMC' > "$gv/vmc.out" 2>&1
) || true
gv_redo=$(wc -c < "$gv/OPL/VMC/SLUS_200.90_0.bin" | tr -d ' ')
if [[ -n "$gv_fn" && "$gv_redo" == 8388608 && "$(cat "$gv/OPL/VMC/SCUS_971.05_0.bin")" == saves ]]; then
    ok game-installer-remakes-empty-vmc
else
    bad "game-installer-remakes-empty-vmc size=$gv_redo $(head -n 2 "$gv/vmc.out")"
fi
rm -rf "$gv"

# --- mkpart EXT2 as the PS2 kernel reads it ---------------------------------
# fs/partitions/ps2.c maps a __linux.N partition as its main partition from
# 4 MiB in, then each sub-partition from 4 KiB in; the PFS Shell formats in
# that layout. hdl_dump toc --dm starts a sub-partition 1 MiB in, so a
# filesystem written along those extents had every block past the main
# partition 2040 sectors away from where the PS2 reads it ("Allocating
# block in system zone"). On a 16 GiB drive APA caps a partition at 1 GiB,
# so 1536M is a main partition and one sub-partition.
kl=$(mktemp -d)
kl_img="$kl/drive.img"
/usr/sbin/mkfile -n 16g "$kl_img"
kl_rc=0
printf 'device %s\ninitialize yes\nmkpart __linux.10 1536M EXT2\nmkpart __linux.2 128M EXT2SWAP\nexit\n' "$kl_img" \
    | "$root/../../helper/darwin-arm64/PFS Shell.elf" > "$kl/out" 2>&1 || kl_rc=$?
# kl_view NAME OUT: NAME as the PS2 kernel maps it; prints the number of pieces.
kl_view() {
    "$root/../../helper/darwin-arm64/hdl_dump" toc "$kl_img" --dm | tr ';' '\n' | grep -- "-$1," | python3 -I -c '
import sys
line, img, out = sys.stdin.read().strip(), sys.argv[1], sys.argv[2]
pieces = [p.split() for p in line.split(",")[4:] if len(p.split()) == 5]
with open(img, "rb") as disk, open(out, "wb") as dst:
    for n, bits in enumerate(pieces):
        start, count = int(bits[4]), int(bits[1])
        if n:
            start, count = start - 2040, count + 2040
        disk.seek(start * 512)
        dst.write(disk.read(count * 512))
print(len(pieces))' "$kl_img" "$2"
}
kl_e2=/opt/homebrew/opt/e2fsprogs/sbin
kl_pieces=$(kl_view __linux.10 "$kl/home.img")
kl_blocks=$("$kl_e2/dumpe2fs" -h "$kl/home.img" 2>/dev/null | awk -F: '/^Block count/ { gsub(/ /, "", $2); print $2 }')
# 1536 MiB less the 4 MiB in front of the main partition and the 4 KiB in
# front of the sub-partition, in whole 4 KiB blocks.
if [[ "$kl_rc" -eq 0 && "$kl_pieces" == 2 && "$kl_blocks" == $(((1536 * 2048 - 8192 - 8) / 8)) ]] \
    && "$kl_e2/e2fsck" -fn "$kl/home.img" > "$kl/fsck.out" 2>&1; then
    ok mkpart-ext2-kernel-layout
else
    bad "mkpart-ext2-kernel-layout rc=$kl_rc pieces=$kl_pieces blocks=$kl_blocks $(tail -n 3 "$kl/out") $(grep -m 3 -E 'differences|Bad|bad|corrupt' "$kl/fsck.out")"
fi
"$root/../../helper/darwin-arm64/hdl_dump" toc "$kl_img" > "$kl/toc" 2>&1
grep -q '__linux.10$' "$kl/toc" && ! grep -qi broken "$kl/toc" \
    && ok mkpart-ext2-keeps-apa-headers || bad "mkpart-ext2-keeps-apa-headers $(cat "$kl/toc")"
# PS2 Linux's /bin/mkhome copies the ps2 user's home onto the new /home
# only when ls finds nothing there; the PFS Shell leaves no lost+found, and
# the root folder belongs to root.
kl_root=$("$kl_e2/debugfs" -R "ls -p /" "$kl/home.img" 2>/dev/null | awk -F/ 'NF > 5 { print $6 ":" $4 ":" $5 }' | sort | tr '\n' ' ')
[[ "$kl_root" == ".:0:0 ..:0:0 " ]] && ok mkpart-ext2-empty-root-owned-by-root || bad "mkpart-ext2-empty-root-owned-by-root [$kl_root]"
# Linux swap v1: version 1 at byte 1024, SWAPSPACE2 at the end of the first page.
kl_view __linux.2 "$kl/swap.img" > /dev/null
kl_swap=$(python3 -I -c 'import struct,sys; f=open(sys.argv[1],"rb"); f.seek(1024); ver=struct.unpack("<I", f.read(4))[0]; f.seek(4086); print("%s %s" % (ver, f.read(10)))' "$kl/swap.img")
[[ "$kl_swap" == "1 b'SWAPSPACE2'" ]] && ok mkpart-ext2swap || bad "mkpart-ext2swap $kl_swap"
rm -rf "$kl"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

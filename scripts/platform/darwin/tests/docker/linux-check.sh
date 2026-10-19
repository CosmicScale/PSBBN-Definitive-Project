#!/bin/bash
# Runs in the psbbn-linux-check container (linux/amd64, privileged), for
# tests/e2e-docker.sh. Prints key=value lines.
#
#   linux-check.sh format IMAGE         the Linux PFS Shell.elf runs stdin on IMAGE
#   linux-check.sh home IMAGE TARBALL   __linux.10 the way the PS2 kernel maps it,
#                                       with PS2 Linux's /bin/mkhome from TARBALL
#   linux-check.sh vmc DIR              genvmc as Game-Installer builds it on Linux,
#                                       against DIR/mac-8.bin and DIR/mac-32.bin
#   linux-check.sh root IMAGE OUT [TARBALL [OPTION]]
#                                       __linux.3 the way the PS2 kernel maps it;
#                                       with TARBALL, tar zxpf it in as root first,
#                                       as Extras does on Linux (OPTION, such as
#                                       --numeric-owner, goes to tar). Lists every
#                                       path in OUT.
#
# /helper is the project's scripts/helper folder.
set -u
helper=/helper

format() {
    "$helper/PFS Shell.elf" > /tmp/pfsshell.out 2>&1
    echo "format_rc=$?"
}

# ps2_map LOOP PART NAME: PART on LOOP as /dev/mapper/NAME, the way the PS2
# kernel reads it.
ps2_map() {
    local loop="$1" part="$2" name="$3" line table
    line=$("$helper/HDL Dump.elf" toc "$loop" --dm | tr ';' '\n' | grep -- "-$part,")
    # fs/partitions/ps2.c maps the main partition from 4 MiB in and each
    # sub-partition from 4 KiB in; toc --dm starts a sub-partition 1 MiB in.
    # A sub-partition starts with its APA header, magic "APA\0" at byte 4.
    table=$(python3 -I - "$line" "$loop" << 'PY'
import sys
line, loop = sys.argv[1], sys.argv[2]
out, logical = [], 0
with open(loop, "rb") as disk:
    for n, part in enumerate(line.split(",")[4:]):
        bits = part.split()
        if len(bits) != 5:
            continue
        start, count = int(bits[4]), int(bits[1])
        if n:
            head = start - 2048
            disk.seek(head * 512 + 4)
            if disk.read(4) != b"APA\0":
                sys.exit("no APA header at sector %d" % head)
            start, count = head + 8, count + 2040
        out.append("%d %d linear %s %d" % (logical, count, loop, start))
        logical += count
print("\n".join(out))
PY
) || { echo "error=table"; return 1; }
    echo "pieces=$(wc -l <<< "$table" | tr -d ' ')"
    printf '%s\n' "$table" | dmsetup create --noudevsync "$name" || { echo "error=dmsetup"; return 1; }
    dmsetup mknodes
}

home() {
    local img="$1" tarball="$2" loop dev name="psbbn-hda10-$$" root=/tmp/ps2root
    local base rc n errors
    loop=$(losetup -f --show "$img") || { echo "error=losetup"; return 1; }
    # shellcheck disable=SC2064
    trap "umount $root/home $root/proc 2>/dev/null; dmsetup remove --noudevsync $name 2>/dev/null; losetup -d $loop" EXIT
    ps2_map "$loop" __linux.10 "$name" || return 1
    dev="/dev/mapper/$name"
    echo "blocks=$(dumpe2fs -h "$dev" 2>/dev/null | awk -F: '/^Block count/ { gsub(/ /, "", $2); print $2 }')"
    echo "sectors=$(blockdev --getsz "$dev")"
    rc=0
    e2fsck -fn "$dev" > /tmp/fsck-new.out 2>&1 || rc=$?
    echo "fsck_new=$rc"
    echo "root=$(debugfs -R 'ls -p /' "$dev" 2>/dev/null | awk -F/ 'NF > 5 { printf "%s ", $6 }')"

    # PS2 Linux's root as far as /bin/mkhome needs it: the tarball's
    # mkhome, fstab and home, busybox for its commands, and the partition
    # as /dev/hda10.
    rm -rf "$root"
    mkdir -p "$root/bin" "$root/dev" "$root/proc" "$root/tmp"
    tar -xzf "$tarball" -C "$root" bin/mkhome etc/fstab home 2>/dev/null
    cp /bin/busybox "$root/bin/busybox"
    for n in sh grep mkdir cp mount umount ls rm echo cat; do
        ln -s busybox "$root/bin/$n"
    done
    mknod "$root/dev/hda10" b "$((0x$(stat -L -c '%t' "$dev")))" "$((0x$(stat -L -c '%T' "$dev")))"
    mount -t proc proc "$root/proc"
    base=$(dmesg | wc -l)
    rc=0
    chroot "$root" /bin/sh /bin/mkhome > /tmp/mkhome.out 2>&1 || rc=$?
    echo "mkhome_rc=$rc"
    if [[ -f "$root/home/ps2/.bashrc" ]]; then echo "home_ps2=yes"; else echo "home_ps2=no"; fi
    if grep -q '^/dev/hda10' "$root/etc/fstab"; then echo "fstab_entry=yes"; else echo "fstab_entry=no"; fi
    if ! grep -q " $root/home " /proc/mounts; then
        echo "error=mkhome did not mount /dev/hda10"
        return 1
    fi
    # Copying files in, as the report did. Each new top-level folder goes
    # to another block group, so the copy reaches every group, including
    # the ones in the sub-partitions.
    for n in $(seq 1 64); do
        mkdir "$root/home/copy$n" && head -c 1048576 /dev/urandom > "$root/home/copy$n/file.bin"
    done
    sync
    umount "$root/home"
    # The kernel names the map dm-MINOR; without udev nothing links that name.
    n="dm-$(dmsetup info -c --noheadings -o minor "$name" | tr -d ' ')"
    errors=$(dmesg | tail -n +"$((base + 1))" | grep -E "EXT[234]-fs (\($n\): error|error \(device $n\))")
    echo "kernel_errors=$(grep -c . <<< "$errors")"
    [[ -n "$errors" ]] && echo "kernel_first=$(head -n 1 <<< "$errors" | sed -E 's/^\[[^]]*\] //')"
    rc=0
    e2fsck -fn "$dev" > /tmp/fsck-used.out 2>&1 || rc=$?
    echo "fsck_used=$rc"
}

vmc() {
    local dir="$1" mb rc
    # Game-Installer on Linux: gcc -std=gnu99, no optimization.
    gcc -std=gnu99 -o /tmp/genvmc "$helper/genvmc.c" || { echo "error=gcc"; return 1; }
    for mb in 8 32; do
        /tmp/genvmc "$mb" "$dir/linux-$mb.bin" > /dev/null
        # The cards differ only in the time they were made, kept in the two
        # entries of the root folder.
        python3 -I - "$dir/mac-$mb.bin" "$dir/linux-$mb.bin" "$mb" << 'PY'
import struct, sys
def card(path):
    data = bytearray(open(path, "rb").read())
    alloc, rootdir = struct.unpack_from("<II", data, 52)[0], struct.unpack_from("<I", data, 60)[0]
    root = (alloc + rootdir) * struct.unpack_from("<I", data, 340)[0]
    for entry in (root, root + 512):
        data[entry + 8:entry + 16] = bytes(8)
        data[entry + 24:entry + 32] = bytes(8)
    return bytes(data)
mac, linux = card(sys.argv[1]), card(sys.argv[2])
print("vmc_%s=%s" % (sys.argv[3], "same" if mac == linux else "different"))
PY
    done
    # The same source built with glibc's fortify stops the same way the
    # macOS build did.
    gcc -std=gnu99 -O2 -D_FORTIFY_SOURCE=2 -o /tmp/genvmc-fortify "$helper/genvmc.c" 2>/dev/null
    rc=0
    /tmp/genvmc-fortify 8 /tmp/fortify.bin > /tmp/fortify.out 2>&1 || rc=$?
    echo "linux_fortify_rc=$rc"
    echo "linux_fortify_says=$(grep -m 1 -o 'buffer overflow detected' /tmp/fortify.out)"
}

root() {
    local img="$1" out="$2" tarball="${3:-}" option="${4:-}" loop dev name="psbbn-hda3-$$" mnt=/tmp/ps2-hda3 rc
    loop=$(losetup -f --show "$img") || { echo "error=losetup"; return 1; }
    # shellcheck disable=SC2064
    trap "umount $mnt 2>/dev/null; dmsetup remove --noudevsync $name 2>/dev/null; losetup -d $loop" EXIT
    ps2_map "$loop" __linux.3 "$name" || return 1
    dev="/dev/mapper/$name"
    mkdir -p "$mnt"
    if [[ -n "$tarball" ]]; then
        mount -t ext2 "$dev" "$mnt" || { echo "error=mount"; return 1; }
        rc=0
        tar ${option:+"$option"} -zxpf "$tarball" -C "$mnt" > /tmp/tar.out 2>&1 || rc=$?
        echo "tar_rc=$rc"
        umount "$mnt"
    fi
    rc=0
    e2fsck -fn "$dev" > /tmp/fsck-root.out 2>&1 || rc=$?
    echo "fsck_root=$rc"
    mount -t ext2 -o ro "$dev" "$mnt" || { echo "error=mount"; return 1; }
    # One line per path, the root folder too: mode, owner and links, then
    # the size and MD5 of a file, the target of a link or the numbers of a
    # device, then the modification time. Names are the bytes on the disk.
    python3 -I - "$mnt" "$out" << 'PY'
import hashlib, os, stat, sys
top, out = os.fsencode(sys.argv[1]), sys.argv[2]
rows = []
def row(full):
    info = os.lstat(full)
    mode = info.st_mode
    if stat.S_ISREG(mode):
        md5 = hashlib.md5()
        with open(full, "rb") as fh:
            for block in iter(lambda: fh.read(1 << 20), b""):
                md5.update(block)
        what = b"f %d %s" % (info.st_size, md5.hexdigest().encode())
    elif stat.S_ISDIR(mode):
        what = b"d"
    elif stat.S_ISLNK(mode):
        what = b"l " + os.readlink(full)
    elif stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
        what = b"%s %d:%d" % (b"c" if stat.S_ISCHR(mode) else b"b", os.major(info.st_rdev), os.minor(info.st_rdev))
    elif stat.S_ISFIFO(mode):
        what = b"p"
    else:
        what = b"?"
    rel = os.path.relpath(full, top)
    rows.append(b"%s\t%04o %d:%d %d\t%s\t%d" % (rel, stat.S_IMODE(mode), info.st_uid, info.st_gid, info.st_nlink, what, int(info.st_mtime)))
row(top)
for dirpath, dirnames, filenames in os.walk(top):
    for name in dirnames + filenames:
        row(os.path.join(dirpath, name))
with open(out, "wb") as fh:
    fh.write(b"\n".join(sorted(rows)) + b"\n")
special = sum(1 for r in rows if int(r.split(b"\t")[1].split()[0], 8) & 0o7000)
print("root_paths=%d" % len(rows))
print("root_special=%d" % special)
PY
    umount "$mnt"
}

case "${1:-}" in
    format) format ;;
    home) home "$2" "$3" ;;
    vmc) vmc "$2" ;;
    root) root "$2" "$3" "${4:-}" "${5:-}" ;;
    *) sed -n '2,18p' "$0" >&2; exit 2 ;;
esac

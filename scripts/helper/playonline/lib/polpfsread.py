#!/usr/bin/env python3
#
# PlayOnline installer for the PSBBN Definitive Project
# Copyright (C) 2026 PrettyOpenLobby
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""List and extract files from the PFS partitions of a PS2 HDD image.

Given a PCSX2 `DEV9hdd.raw`, a raw dump or a block device, walks the APA
table, mounts each PFS partition with polfill's reader and walks its directory
tree. Read-only: the image is never written.

    python3 -m playonline.lib.polpfsread IMAGE                    # list every tree
    python3 -m playonline.lib.polpfsread IMAGE --only __common
    python3 -m playonline.lib.polpfsread IMAGE --extract OUTDIR   # write the files out
    python3 -m playonline.lib.polpfsread IMAGE --grep sqkeylist   # matching paths only
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
import struct                                              # noqa: E402

from . import polfill                                             # noqa: E402
from .polnetdump import partitions, sub_partitions          # noqa: E402
from .polpfs import PFS_SUPER_MAGIC                         # noqa: E402

SECTOR = 512
FIO_S_IFDIR = 0x1000


def superblock(f, lba):
    """Return the partition's PFS superblock fields, or None if it has none.

    The superblock is at sector 8192 of the partition. Layout (ps2sdk
    superWrite.c, see also polpfs.py):
        0 magic 'PFS\\0' | 4 version | 8 modver | 12 pfsFsckStat
        16 zone_size | 20 num_subs | 24 log blockinfo | 32 root blockinfo
        blockinfo = u32 number (zones) | u16 subpart | u16 count
    """
    f.seek((lba + 8192) * SECTOR)
    sb = f.read(SECTOR)
    if len(sb) < 40:
        return None
    magic, ver, _modver, fsck, zone_size, nsubs = struct.unpack_from("<6I", sb, 0)
    if magic != PFS_SUPER_MAGIC:
        return None
    root_number, root_sub, _root_count = struct.unpack_from("<IHH", sb, 32)
    return dict(zone_size=zone_size, nsubs=nsubs, fsck=fsck, version=ver,
                root=(root_number, root_sub))


def mount(f, lba, sectors, subs=None):
    """Return (Partition, root inode) for the PFS volume at `lba`, or (None, None).

    The zone size and the root inode's (zone, sub-partition) are taken from
    the superblock. They cannot be derived from the partition length: on a
    volume extended with APA sub-partitions the root can sit in a sub.

    If the superblock is unreadable, each legal zone size is tried with
    pfsFormat's arithmetic for the root, which holds only for a volume
    without subs. A wrong zone size can land on a block that passes the inode
    checksum, so in both paths the root must also read back as a directory
    whose first two entries are "." and "..".
    """
    sb = superblock(f, lba)
    if sb:
        try:
            part = polfill.Partition(f, lba, sectors,
                                     zone_size=sb["zone_size"], subs=subs)
            ino = polfill.read_inode(part, sb["root"][0], sb["root"][1])
            if ino["ok"] and ino["mode"] & FIO_S_IFDIR:
                names = [e[0] for e in list(polfill.read_dir(part, ino))[:2]]
                if names[:2] == [b".", b".."]:
                    return part, ino
        except Exception:
            pass

    for zone in (2048, 4096, 8192, 16384, 32768):
        try:
            part = polfill.Partition(f, lba, sectors, zone_size=zone, subs=subs)
            ino = polfill.read_inode(part, part.root)
            if not (ino["ok"] and ino["mode"] & FIO_S_IFDIR):
                continue
            names = [e[0] for e in list(polfill.read_dir(part, ino))[:2]]
        except Exception:
            continue
        if names[:2] == [b".", b".."]:
            return part, ino
    return None, None


def walk(part, ino, path="/", depth=0, out=None, bad=None):
    """Depth-first walk appending (path, inode) for each file to `out`.

    A drive can carry a dentry whose inode block is garbage (a US Viewer
    partition has one at `/file.txt`). An inode that fails its magic or
    checksum is appended to `bad` and skipped, and the walk continues.
    """
    for name, inode, sub, flags in polfill.read_dir_full(part, ino):
        if name in (b".", b".."):
            continue
        p = path + name.decode("ascii", "replace")
        try:
            child = polfill.read_inode(part, inode, sub)
        except Exception as exc:
            if bad is not None:
                bad.append((p, str(exc)))
            continue
        if not child["ok"] or child["magic"] != polfill.PFS_SEGD_MAGIC:
            if bad is not None:
                bad.append((p, "bad inode at zone %d sub %d" % (inode, sub)))
            continue
        if child["mode"] & FIO_S_IFDIR:
            if depth < 24:
                walk(part, child, p + "/", depth + 1, out, bad)
        else:
            out.append((p, child))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image")
    ap.add_argument("--only", help="just this partition")
    ap.add_argument("--grep", help="only paths containing this substring")
    ap.add_argument("--extract", metavar="OUTDIR")
    args = ap.parse_args()

    # os.path.getsize() reports 0 for a block device (/dev/sdX). Seeking
    # to the end gives the size of both a device and a regular file.
    f = open(args.image, "rb")
    f.seek(0, os.SEEK_END)
    size = f.tell()
    f.seek(0)
    with f:
        parts = [p for p in partitions(f, size) if p[3] and p[2] != 0x0001]
        subs = sub_partitions(f, size)
        for start, length, ptype, name in parts:
            if args.only and name != args.only:
                continue
            part, root = mount(f, start, length, subs.get(start))
            if not part:
                print("%s: not a mountable PFS partition" % name)
                continue
            files, bad = [], []
            walk(part, root, out=files, bad=bad)
            shown = [(p, i) for p, i in files if not args.grep or args.grep in p]
            print("\n=== %s  (zone %d, %d files, showing %d) ==="
                  % (name, part.zone_size, len(files), len(shown)))
            for p, why in bad:
                print("  !! skipped %s (%s)" % (p, why))
            for p, ino in sorted(shown):
                print("  %10d  %s" % (ino["size"], p))
                if args.extract:
                    dst = os.path.join(args.extract, name, p.lstrip("/").replace("/", os.sep))
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    with open(dst, "wb") as g:
                        g.write(polfill.read_content(part, ino))
    return 0


if __name__ == "__main__":
    sys.exit(main())

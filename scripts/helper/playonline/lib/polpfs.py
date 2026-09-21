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
"""Create PFS filesystems inside the APA partitions written by polhdd.py.

A port of `pfsFormat` from ps2sdk `iop/hdd/libpfs/src/superWrite.c` and the
helpers it calls: `pfsFormatSub`, `pfsJournalResetThis`,
`pfsFillSelfAndParentDentries`, `pfsInodeFill`, `pfsInodeCheckSum`,
`pfsGetBitmapSize{Sectors,Blocks}`.

On-disc structures, all little-endian, all offsets relative to the partition:

    superblock        sector 8192, backup 8193 (1 sector each, 32 bytes used)
        u32 magic 'PFS\0' | u32 version 3 | u32 modver | u32 pfsFsckStat
        u32 zone_size | u32 num_subs | blockinfo log | blockinfo root
    blockinfo         u32 number (in zones) | u16 subpart | u16 count
    inode/meta        1024 bytes ("pfsMetaSize"), checksum = sum of u32 1..255
    journal           1024 bytes at log.number<<scale, magic 'PFSL'
    bitmap            512-byte sectors, 1 bit per zone, 1 = allocated

Layout arithmetic, as pfsFormat computes it:

    scale       = log2(zone_size / 512)
    log.number  = bitmapSizeBlocks + (0x2000 >> scale) + 1
    log.count   = max(0x20000 / zone_size, 1)
    root.number = log.number + log.count,  root.count = 1
    root's dentry block sits at root.number + 1

The main partition's bitmap is offset by +0x2000 sectors so it lands just after
the superblock; sub-partitions keep it at sector 1<<scale.

Usage:
    python3 -m playonline.lib.polpfs --image P             # print what would be done
    python3 -m playonline.lib.polpfs --image P --write     # format every PFS partition in polhdd's plan
    python3 -m playonline.lib.polpfs --image P --verify    # re-read and check them
"""
import argparse
import os
import struct

from .polhdd import APA_TYPE_PFS, SECTOR, plan

PFS_SUPER_MAGIC = 0x50465300        # 'PFS\0'
PFS_JOURNAL_MAGIC = 0x5046534C      # 'PFSL'
PFS_SEGD_MAGIC = 0x53454744         # 'SEGD'
PFS_FORMAT_VERSION = 3
PFS_INODE_MAX_BLOCKS = 114
META = 1024                         # pfsMetaSize
BLOCK_SECTORS = 2                   # 1 << pfsBlockSize, pfsBlockSize == 1
ZONE_SIZE = 8192                    # must be a power of two in [2 KiB, 128 KiB]

FIO_S_IFDIR = 0x1000
ROOT_MODE = 0x11FF                  # FIO_S_IFDIR | 0777, as pfsFormat passes
MODVER = 0x0201                     # the console logs "pfs: version 0201 driver start"

CREATED = (0, 0, 0, 0, 29, 3, 2002)  # unused, sec, min, hour, day, month, year


def ps2time(t=CREATED):
    return struct.pack("<6BH", *t)


def get_scale(zone_size):
    scale = 0
    while (512 << scale) != zone_size:
        scale += 1
    return scale


def bitmap_size_sectors(scale, part_sectors):
    """pfsGetBitmapSizeSectors. The `+ w` rounding is the driver's own and is
    kept as is, so the layout matches what the driver computes."""
    zones = part_sectors // (1 << scale)
    w = zones & 7
    zones = zones // 8 + w
    w = zones & 511
    return zones // 512 + w


def bitmap_size_blocks(scale, part_sectors):
    a = bitmap_size_sectors(scale, part_sectors)
    return a // (1 << scale) + (1 if a % (1 << scale) else 0)


def blockinfo(number, subpart=0, count=0):
    return struct.pack("<IHH", number, subpart, count)


def inode_checksum(buf):
    return sum(struct.unpack("<256I", buf)[1:]) & 0xFFFFFFFF


def build_root_inode(root_number):
    """pfsInodeFill(mode=0x11FF) plus the data[1] fixup pfsFormat applies.

    uid and gid are 0 here, as pfsFormat writes them; polfill rewrites the
    root inode with 0xFFFF when it populates the partition."""
    b = bytearray(META)
    struct.pack_into("<I", b, 0x004, PFS_SEGD_MAGIC)
    b[0x008:0x010] = blockinfo(root_number, 0, 1)       # inode_block
    b[0x018:0x020] = blockinfo(root_number, 0, 1)       # last_segment
    b[0x028:0x030] = blockinfo(root_number, 0, 1)       # data[0]
    b[0x030:0x038] = blockinfo(root_number + 1, 0, 1)   # data[1] -> dentry block
    off = 0x028 + PFS_INODE_MAX_BLOCKS * 8              # end of data[] == 952
    struct.pack_into("<HHHH", b, off, ROOT_MODE, 0xA0, 0, 0)   # mode, attr, uid, gid
    b[off + 8:off + 16] = ps2time()                     # atime
    b[off + 16:off + 24] = ps2time()                    # ctime
    b[off + 24:off + 32] = ps2time()                    # mtime
    struct.pack_into("<Q", b, off + 32, 512)            # size = sizeof(dentry)
    struct.pack_into("<IIII", b, off + 40, 2, 2, 1, 0)  # blocks, data, segdesg, subpart
    struct.pack_into("<I", b, 0x000, inode_checksum(bytes(b)))
    return bytes(b)


def build_root_dentries(root_number):
    """pfsFillSelfAndParentDentries: '.' (aLen 12) then '..' (aLen 500)."""
    b = bytearray(META)
    struct.pack_into("<IBBH", b, 0, root_number, 0, 1, 12 | FIO_S_IFDIR)
    b[8:9] = b"."
    struct.pack_into("<IBBH", b, 12, root_number, 0, 2, 500 | FIO_S_IFDIR)
    b[20:22] = b".."
    return bytes(b)


def build_journal():
    b = bytearray(META)
    struct.pack_into("<I", b, 0, PFS_JOURNAL_MAGIC)
    return bytes(b)


def build_bitmap_first(reserved):
    """512-byte bitmap sector with zones 0..reserved-1 marked allocated."""
    words = [0] * 128
    for j in range(reserved):
        words[j >> 5] |= 1 << (j & 31)
    return struct.pack("<128I", *words)


def format_partition(f, part_lba, part_sectors, zone_size=ZONE_SIZE, dry=False):
    scale = get_scale(zone_size)
    bm_sectors = bitmap_size_sectors(scale, part_sectors)
    bm_blocks = bitmap_size_blocks(scale, part_sectors)

    log_number = bm_blocks + (0x2000 >> scale) + 1
    log_count = max(0x20000 // zone_size, 1)
    root_number = log_number + log_count

    sb = bytearray(SECTOR)
    struct.pack_into("<IIIIII", sb, 0, PFS_SUPER_MAGIC, PFS_FORMAT_VERSION,
                     MODVER, 0, zone_size, 0)
    sb[24:32] = blockinfo(log_number, 0, log_count)
    sb[32:40] = blockinfo(root_number, 0, 1)

    # pfsFormatSub(sub=0): reserved covers the pre-superblock area, the journal,
    # root inode + dentry block, and the bitmap itself.
    reserved = (0x2000 >> scale) + log_count + 3 + bm_blocks
    bm_start = (1 << scale) + (0x2000 if reserved >= 2 else 0)

    writes = [
        (log_number << scale, build_journal()),                    # journal
        ((root_number + 1) << scale, build_root_dentries(root_number)),
        (root_number << scale, build_root_inode(root_number)),
        (bm_start, build_bitmap_first(reserved)),
        (8193, bytes(sb)),                                         # backup super
        (8192, bytes(sb)),                                         # super
    ]
    for i in range(1, bm_sectors):                                 # rest of bitmap
        writes.append((bm_start + i, b"\0" * SECTOR))

    if not dry:
        for sec, blob in writes:
            assert sec + len(blob) // SECTOR <= part_sectors, "write past partition end"
            f.seek((part_lba + sec) * SECTOR)
            f.write(blob)
    return dict(scale=scale, log_number=log_number, log_count=log_count,
                root_number=root_number, bm_start=bm_start,
                bm_sectors=bm_sectors, reserved=reserved, writes=len(writes))


def verify(f, part_lba, part_sectors, zone_size=ZONE_SIZE, fresh=True):
    """Re-read a formatted partition and apply every check pfsMountSuperBlock
    makes, plus the root inode checksum and its '.'/'..' entries.

    Returns a list of failures; empty means the console's driver should mount it.

    `fresh` (the default) says nothing has been written since
    `format_partition`. It enables the last check, that the first zone past
    the reserved area is still free. The first file allocated takes that
    zone, so pass `fresh=False` for a populated partition; every other check
    still applies.
    """
    bad = []
    scale = get_scale(zone_size)
    f.seek((part_lba + 8192) * SECTOR)
    sb = f.read(SECTOR)
    magic, ver, _modver, fsck, zs, nsubs = struct.unpack_from("<6I", sb, 0)
    ln, _ls, lc = struct.unpack_from("<IHH", sb, 24)
    rn, _rs, rc = struct.unpack_from("<IHH", sb, 32)

    if magic != PFS_SUPER_MAGIC:
        bad.append("superblock magic %08x" % magic)
    if ver > PFS_FORMAT_VERSION:
        bad.append("version %d > %d" % (ver, PFS_FORMAT_VERSION))
    if zs & (zs - 1) or not (2048 <= zs <= 128 * 1024):
        bad.append("zone size %d fails pfsCheckZoneSize" % zs)
    if nsubs != 0:
        bad.append("num_subs %d but no sub-partitions exist" % nsubs)
    if fsck:
        bad.append("pfsFsckStat %08x" % fsck)

    f.seek((part_lba + 8193) * SECTOR)
    if f.read(SECTOR) != sb:
        bad.append("superblock backup differs from primary")

    f.seek((part_lba + (ln << scale)) * SECTOR)
    jmagic, jnum = struct.unpack_from("<IH", f.read(META), 0)
    if jmagic != PFS_JOURNAL_MAGIC:
        bad.append("journal magic %08x" % jmagic)
    if jnum != 0:
        bad.append("journal has %d pending entries" % jnum)

    f.seek((part_lba + (rn << scale)) * SECTOR)
    ino = f.read(META)
    cs, im = struct.unpack_from("<2I", ino, 0)
    if im != PFS_SEGD_MAGIC:
        bad.append("root inode magic %08x" % im)
    if cs != inode_checksum(ino):
        bad.append("root inode checksum")
    off = 0x028 + PFS_INODE_MAX_BLOCKS * 8
    mode, attr = struct.unpack_from("<2H", ino, off)
    if mode != ROOT_MODE:
        bad.append("root mode %04x" % mode)
    if (mode & 0xF000) != FIO_S_IFDIR:
        bad.append("root is not a directory")
    if attr != 0xA0:
        bad.append("root attr %02x" % attr)

    f.seek((part_lba + ((rn + 1) << scale)) * SECTOR)
    d = f.read(META)
    i0, _s0, p0, a0 = struct.unpack_from("<IBBH", d, 0)
    i1, _s1, p1, a1 = struct.unpack_from("<IBBH", d, 12)
    if (i0, p0, a0 & 0xFFF, d[8:9]) != (rn, 1, 12, b"."):
        bad.append("'.' dentry malformed")
    if (i1, p1, a1 & 0xFFF, d[20:22]) != (rn, 2, 500, b".."):
        bad.append("'..' dentry malformed")

    reserved = (0x2000 >> scale) + lc + 3 + bitmap_size_blocks(scale, part_sectors)
    bm_start = (1 << scale) + (0x2000 if reserved >= 2 else 0)
    f.seek((part_lba + bm_start) * SECTOR)
    words = struct.unpack("<128I", f.read(SECTOR))
    for j in (0, rn, rn + 1, ln, reserved - 1):
        if not (words[j >> 5] >> (j & 31)) & 1:
            bad.append("bitmap: zone %d not marked allocated" % j)
    if fresh and (words[reserved >> 5] >> (reserved & 31)) & 1:
        bad.append("bitmap: zone %d marked allocated past reserved" % reserved)
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--image", required=True)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verify", action="store_true", help="re-read and check")
    args = ap.parse_args()

    if args.verify:
        total = os.path.getsize(args.image) // SECTOR
        ok = True
        with open(args.image, "rb") as f:
            for start, length, _t, ident in [p for p in plan(total) if p[2] == APA_TYPE_PFS]:
                bad = verify(f, start, length)
                print("  %-32s %s" % (ident, "OK" if not bad else "; ".join(bad)))
                ok = ok and not bad
        print("\n  %s" % ("all partitions pass the driver's mount checks" if ok
                          else "failures listed above"))
        return

    total = os.path.getsize(args.image) // SECTOR
    parts = [p for p in plan(total) if p[2] == APA_TYPE_PFS]
    mode = "r+b" if args.write else "rb"
    with open(args.image, mode) as f:
        for start, length, _t, ident in parts:
            info = format_partition(f, start, length, dry=not args.write)
            print("  %-32s LBA %-9d %4d MiB  log=%d+%d root=%d bitmap=%d+%d res=%d"
                  % (ident, start, length * SECTOR // (1024 * 1024),
                     info["log_number"], info["log_count"], info["root_number"],
                     info["bm_start"], info["bm_sectors"], info["reserved"]))
        if args.write:
            f.flush()
            os.fsync(f.fileno())
    print("\n  %s %d partitions" % ("formatted" if args.write else "would format",
                                    len(parts)))


if __name__ == "__main__":
    main()

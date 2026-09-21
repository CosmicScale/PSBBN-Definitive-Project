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
"""Populate the PFS partitions created by polpfs.py from the extracted install tree.

Writes files and directories directly, in the layout the PS2's pfs driver
expects. Semantics follow ps2sdk `iop/hdd/libpfs` (dir.c, block.c, bitmap.c):

* An inode occupies one whole zone. `data[0]` is the inode's own zone; file
  content starts at `data[1]` (`pfsBlockInitPos` begins at segment 1 whenever
  `size != 0`).
* `data[]` holds up to `PFS_INODE_MAX_BLOCKS` = 114 runs of
  `{u32 number; u16 subpart; u16 count}`, each a run of consecutive zones.
  This writer allocates one contiguous run per object, so one entry suffices.
* `number_data` counts used `data[]` entries (including `data[0]`);
  `number_blocks` counts zones (inode plus content).
* A directory's content is a sequence of independent 512-byte chunks of
  `{u32 inode; u8 sub; u8 pLen; u16 aLen; char path[]}` records. The low 12
  bits of `aLen` are the record's allocated length, the top bits carry
  `mode & FIO_S_IFMT`. A record needs `(pLen + 11) & 0x1FC` bytes and the
  last record in a chunk absorbs the remainder ('.' gets aLen 12 and '..'
  gets 500 in a fresh directory).
* uid and gid are 0xFFFF on every inode, including the root. libpfs.h notes
  that software may ignore an entry whose uid/gid are not 0xFFFF, and the
  console's pfs driver returns ENOENT for every lookup in a root left at the
  0/0 that `pfsFormat` writes.

The extracted trees named in LAYOUT are expected beside this module, under
`netfs/` and `install/`.

Usage:
    python3 -m playonline.lib.polfill --image P             # plan only, report zone usage
    python3 -m playonline.lib.polfill --image P --write
    python3 -m playonline.lib.polfill --image P --verify
"""
import argparse
import os
import struct

from .polhdd import APA_TYPE_PFS, SECTOR, plan
from .polpfs import (FIO_S_IFDIR, META, PFS_INODE_MAX_BLOCKS, PFS_SEGD_MAGIC,
                    ZONE_SIZE, bitmap_size_blocks, bitmap_size_sectors,
                    blockinfo, get_scale, inode_checksum, ps2time)

FIO_S_IFREG = 0x2000
DIR_MODE = FIO_S_IFDIR | 0x1FF
FILE_MODE = FIO_S_IFREG | 0x1FF
PFS_UID = 0xFFFF
PFS_GID = 0xFFFF
DENTRY_CHUNK = 512

# Partition id -> [(source tree, destination subdirectory)]. The POLVIEWER
# partition is not a straight copy: the Viewer opens pfs2:/V/polapp.pex.enc,
# pfs2:/ps2drv/kbd/... and pfs2:/pub/all/..., so its sources are remapped.
LAYOUT = {
    # The `.pex.enc` loader mounts `hdd0:__net,<ATA-derived password>` and
    # stats `pfs0:/etc/access_flag`; see polhdd.PASSWORDS. Only existence is
    # checked, so the flag is a zero-byte file.
    "__net": [("netfs", "")],
    "PP.SLPS-20200.0003.JANHOUROU": [("install/Warashi", "")],
    "PP.SLPS-20200.0002.TETRAMASTER": [("install/TetraMaster", "")],
    # The US disc (SCUS-97269) carries POL/ and TetraMaster/ under its own
    # product code (Janhourou ships on the JP disc only). Extract them with
    # `polinstall --disc <us disc root> --out DIR` and fill with
    # `polrealfill --src DIR/<tree>`, which takes the source tree directly.
    # polrealfill accepts only the partition names that are keys here.
    "PP.SCUS-97269.0002.TETRAMASTER": [("install/TetraMaster", "")],
    # POL/install/PS2 is the partition root: besides data/ default/ export/
    # res/ it holds the loose files `SLPS-20200` (the HDD boot ELF that
    # login.pex opens as `pfs2:/SLPS-20200`), dnasload.elf, ioprp.img and
    # patch.ver.
    "PP.SCUS-97269.1000.POLVIEWER": [("install/POL/install/PS2", "")],
    "PP.SLPS-20200.1000.POLVIEWER": [
        ("install/POL/install/PS2", ""),
        ("install/POL/Data/PS2", "V"),
        ("install/POL/ps2drv", "ps2drv"),
    ],
}


def dentry_need(name):
    """Bytes a record occupies: (pLen + 11) & 0x1FC == align4(8 + pLen)."""
    return (len(name) + 11) & 0x1FC


def pack_dentries(entries):
    """entries = [(name_bytes, inode_zone, mode)] -> list of 512-byte chunks."""
    chunks, cur = [], []
    used = 0
    for ent in entries:
        need = dentry_need(ent[0])
        if used + need > DENTRY_CHUNK:
            chunks.append(cur)
            cur, used = [], 0
        cur.append((used, ent, need))
        used += need
    if cur:
        chunks.append(cur)

    out = []
    for recs in chunks:
        b = bytearray(DENTRY_CHUNK)
        for i, (off, (name, zone, mode), need) in enumerate(recs):
            alen = need if i + 1 < len(recs) else DENTRY_CHUNK - off
            struct.pack_into("<IBBH", b, off, zone, 0, len(name),
                             alen | (mode & 0xF000))
            b[off + 8:off + 8 + len(name)] = name
        out.append(bytes(b))
    return out


class Partition(object):
    """A formatted PFS partition, opened for population."""

    def __init__(self, f, lba, sectors, zone_size=ZONE_SIZE, subs=None):
        self.f, self.lba, self.sectors = f, lba, sectors
        # {sub index: start LBA}; 0 is the main partition itself. Only the
        # read path uses it: this module writes single-partition volumes.
        self.subs = dict(subs or {})
        self.subs[0] = lba
        self.zone_size = zone_size
        self.scale = get_scale(zone_size)
        self.zones = sectors // (1 << self.scale)
        self.bm_sectors = bitmap_size_sectors(self.scale, sectors)
        bm_blocks = bitmap_size_blocks(self.scale, sectors)
        self.log_number = bm_blocks + (0x2000 >> self.scale) + 1
        self.log_count = max(0x20000 // zone_size, 1)
        self.root = self.log_number + self.log_count
        self.reserved = (0x2000 >> self.scale) + self.log_count + 3 + bm_blocks
        self.bm_start = (1 << self.scale) + (0x2000 if self.reserved >= 2 else 0)
        self.next_zone = self.reserved
        self.bitmap = bytearray(self.bm_sectors * SECTOR)
        for z in range(self.reserved):
            self.bitmap[z >> 3] |= 1 << (z & 7)

    def zone_sector(self, zone, sub=0):
        """Absolute sector of a zone. `sub` picks the APA sub-partition it is
        numbered against; zones in different subs share the same numbers."""
        base = self.subs.get(sub)
        if base is None:
            raise ValueError("no sub-partition %d (have %s)"
                             % (sub, sorted(self.subs)))
        return base + (zone << self.scale)

    def alloc(self, n):
        z = self.next_zone
        if z + n > self.zones:
            raise RuntimeError("partition full: need %d zones, %d left"
                               % (n, self.zones - z))
        for k in range(z, z + n):
            self.bitmap[k >> 3] |= 1 << (k & 7)
        self.next_zone = z + n
        return z

    def write_zones(self, zone, data):
        self.f.seek((self.lba + (zone << self.scale)) * SECTOR)
        self.f.write(data)

    def write_inode(self, zone, mode, size, content=None, uid=PFS_UID, gid=PFS_GID):
        """content = (first_zone, count) or None for an empty object."""
        b = bytearray(META)
        struct.pack_into("<I", b, 0x004, PFS_SEGD_MAGIC)
        b[0x008:0x010] = blockinfo(zone, 0, 1)          # inode_block
        b[0x018:0x020] = blockinfo(zone, 0, 1)          # last_segment
        b[0x028:0x030] = blockinfo(zone, 0, 1)          # data[0] = self
        ndata, nblocks = 1, 1
        if content:
            first, count = content
            assert count <= 0xFFFF and ndata < PFS_INODE_MAX_BLOCKS
            b[0x030:0x038] = blockinfo(first, 0, count)  # data[1] = content
            ndata, nblocks = 2, 1 + count
        off = 0x028 + PFS_INODE_MAX_BLOCKS * 8
        attr = 0xA0 if (mode & 0xF000) == FIO_S_IFDIR else 0
        struct.pack_into("<HHHH", b, off, mode, attr, uid, gid)
        b[off + 8:off + 16] = ps2time()
        b[off + 16:off + 24] = ps2time()
        b[off + 24:off + 32] = ps2time()
        struct.pack_into("<Q", b, off + 32, size)
        struct.pack_into("<IIII", b, off + 40, nblocks, ndata, 1, 0)
        struct.pack_into("<I", b, 0x000, inode_checksum(bytes(b)))
        self.write_zones(zone, bytes(b))

    def flush_bitmap(self):
        self.f.seek((self.lba + self.bm_start) * SECTOR)
        self.f.write(bytes(self.bitmap))


def add_tree(part, src, inode_zone, parent_zone, stats, write=True, extra=None):
    """Recursively write `src` as the directory living at `inode_zone`.

    `extra` mounts further source directories inside this one, as
    `{name: (source directory, nested extra or None)}`. A partition directory
    is not always one directory on the host: Square Enix's installer builds
    the Viewer's `ps2drv` from the disc's `POL/ps2drv/modules` with
    `POL/ps2drv/data/kbd` inside it as `kbd`, and the Viewer powers the
    console off if it cannot open `pfs2:/ps2drv/kbd/kcd000.dat`.

    Mounted names are sorted in with the real ones, so dentry order does not
    depend on where a directory's contents came from.
    """
    extra = extra or {}
    entries = [(b".", inode_zone, DIR_MODE), (b"..", parent_zone, DIR_MODE)]
    children = []
    mounts = []
    with os.scandir(src) as it:
        present = {e.name: e for e in it}
    clash = sorted(set(present) & set(extra))
    if clash:
        raise ValueError("%s: %s is both in the tree and mounted into it"
                         % (src, ", ".join(clash)))
    for name in sorted(set(present) | set(extra)):
        zone = part.alloc(1)
        if name in present:
            e = present[name]
            entries.append((name.encode("ascii"), zone,
                            DIR_MODE if e.is_dir() else FILE_MODE))
            children.append((e, zone))
        else:
            sub_src, sub_extra = extra[name]
            entries.append((name.encode("ascii"), zone, DIR_MODE))
            mounts.append((sub_src, sub_extra, zone))

    chunks = pack_dentries(entries)
    nz = (len(chunks) * DENTRY_CHUNK + part.zone_size - 1) // part.zone_size
    run = part.alloc(nz)
    if write:
        blob = b"".join(chunks)
        blob += b"\0" * (nz * part.zone_size - len(blob))
        part.write_zones(run, blob)
        part.write_inode(inode_zone, DIR_MODE, len(chunks) * DENTRY_CHUNK, (run, nz))
    stats["dirs"] += 1

    for e, zone in children:
        if e.is_dir():
            add_tree(part, e.path, zone, inode_zone, stats, write)
        else:
            size = e.stat().st_size
            if size:
                n = (size + part.zone_size - 1) // part.zone_size
                run = part.alloc(n)
                if write:
                    with open(e.path, "rb") as fh:
                        data = fh.read()
                    part.write_zones(run, data + b"\0" * (n * part.zone_size - size))
                    part.write_inode(zone, FILE_MODE, size, (run, n))
            elif write:
                part.write_inode(zone, FILE_MODE, 0, None)
            stats["files"] += 1
            stats["bytes"] += size

    for sub_src, sub_extra, zone in mounts:
        add_tree(part, sub_src, zone, inode_zone, stats, write, sub_extra)


def read_inode(part, zone, sub=0):
    part.f.seek(part.zone_sector(zone, sub) * SECTOR)
    b = part.f.read(META)
    magic, = struct.unpack_from("<I", b, 0x004)
    csum, = struct.unpack_from("<I", b, 0x000)
    off = 0x028 + PFS_INODE_MAX_BLOCKS * 8
    mode, attr, uid, gid = struct.unpack_from("<4H", b, off)
    size, = struct.unpack_from("<Q", b, off + 32)
    nblocks, ndata = struct.unpack_from("<2I", b, off + 40)
    # data[] holds at most PFS_INODE_MAX_BLOCKS entries and ends where mode
    # begins, so ndata is clamped: a garbage inode can report any value. An
    # inode needing more runs continues in a further segment descriptor. That
    # chain is not followed, so such a file would read short; runs are
    # extents, and a 1 GB file typically needs about ten.
    runs, runs_full = [], []
    for i in range(1, min(ndata, PFS_INODE_MAX_BLOCKS)):   # data[0] is the inode
        n, sub, cnt = struct.unpack_from("<IHH", b, 0x028 + i * 8)
        runs.append((n, cnt))                     # without sub, for sub-0 callers
        runs_full.append((n, sub, cnt))
    return dict(magic=magic, ok=csum == inode_checksum(b), mode=mode, attr=attr,
                uid=uid, gid=gid, size=size, nblocks=nblocks, runs=runs,
                runs_full=runs_full)


def read_content(part, ino):
    out = bytearray()
    for number, sub, count in ino["runs_full"]:
        part.f.seek(part.zone_sector(number, sub) * SECTOR)
        out += part.f.read(count * part.zone_size)
        if len(out) >= ino["size"]:
            break
    return bytes(out[:ino["size"]])


def read_dir_full(part, ino):
    """Walk the 512-byte dentry chunks, stepping by aLen as the driver does.

    Returns (name, inode zone, sub, mode bits). A zone number is only
    meaningful together with the sub-partition it is numbered against.
    """
    data = read_content(part, ino)
    out = []
    for base in range(0, len(data), DENTRY_CHUNK):
        off = 0
        end = min(DENTRY_CHUNK, len(data) - base)
        while off + 8 <= end:
            inode, sub, plen, alen = struct.unpack_from("<IBBH", data, base + off)
            step = alen & 0xFFF
            if step == 0:
                break
            if plen:
                name = data[base + off + 8:base + off + 8 + plen]
                out.append((name, inode, sub, alen & 0xF000))
            off += step
    return out


def read_dir(part, ino):
    """`read_dir_full` without the sub index, for single-partition callers."""
    return [(name, inode, mode) for name, inode, _sub, mode in read_dir_full(part, ino)]


def verify_tree(part, zone, src, errs, counts, path="/", ignore=(), sub=0):
    """Compare the directory at `zone` with the host directories in `src`.

    `ignore` lists names that come from a different source root (the
    POLVIEWER remaps), so they are not reported as extra. `sub` is the APA
    sub-partition `zone` is numbered against: a volume pfsshell spread over a
    main partition and its subs puts inodes in any of them, and each dentry
    says which."""
    ino = read_inode(part, zone, sub)
    if not ino["ok"] or ino["magic"] != PFS_SEGD_MAGIC:
        errs.append("%s: bad inode" % path)
        return
    have = {n: (z, s, m) for n, z, s, m in read_dir_full(part, ino)
            if n not in (b".", b"..") and n not in ignore}
    want = {}
    for s in src:
        with os.scandir(s) as it:
            for e in it:
                want[e.name.encode("ascii")] = e
    for name in set(want) | set(have):
        # names are raw bytes on disc; a stale dentry can hold anything
        shown = name.decode("ascii", "backslashreplace")
        if name not in have:
            errs.append("%s%s: missing on disc" % (path, shown))
            continue
        if name not in want:
            errs.append("%s%s: extra on disc" % (path, shown))
            continue
        e = want[name]
        czone, csub, cmode = have[name]
        if e.is_dir() != ((cmode & 0xF000) == FIO_S_IFDIR):
            errs.append("%s%s: type mismatch" % (path, name.decode()))
            continue
        if e.is_dir():
            verify_tree(part, czone, [e.path], errs, counts,
                        path + name.decode() + "/", sub=csub)
        else:
            cino = read_inode(part, czone, csub)
            with open(e.path, "rb") as fh:
                want_bytes = fh.read()
            if not cino["ok"]:
                errs.append("%s%s: inode checksum" % (path, name.decode()))
            elif cino["size"] != len(want_bytes):
                errs.append("%s%s: size %d != %d" % (path, name.decode(),
                                                     cino["size"], len(want_bytes)))
            elif read_content(part, cino) != want_bytes:
                errs.append("%s%s: content mismatch" % (path, name.decode()))
            counts["files"] += 1
    counts["dirs"] += 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--image", required=True)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verify", action="store_true",
                    help="walk the on-disc tree and byte-compare every file")
    ap.add_argument("--only", action="append", metavar="PARTID",
                    help="restrict to these partition ids (repeatable)")
    args = ap.parse_args()

    layout = LAYOUT if not args.only else {k: v for k, v in LAYOUT.items()
                                           if k in args.only}
    if args.only and not layout:
        raise SystemExit("--only matched nothing; have %s" % list(LAYOUT))

    if args.verify:
        here = os.path.dirname(os.path.abspath(__file__))
        total = os.path.getsize(args.image) // SECTOR
        parts = {p[3]: p for p in plan(total) if p[2] == APA_TYPE_PFS}
        allok = True
        with open(args.image, "rb") as f:
            for ident, sources in layout.items():
                part = Partition(f, parts[ident][0], parts[ident][1])
                errs, counts = [], {"files": 0, "dirs": 0}
                roots = [os.path.join(here, s) for s, d in sources if not d]
                ino = read_inode(part, part.root)
                have = {n: (z, m) for n, z, m in read_dir(part, ino)
                        if n not in (b".", b"..")}
                for s, d in sources:
                    if d:
                        if d.encode() not in have:
                            errs.append("/%s: missing" % d)
                        else:
                            verify_tree(part, have[d.encode()][0],
                                        [os.path.join(here, s)], errs, counts,
                                        "/%s/" % d)
                if roots:
                    remapped = tuple(d.encode() for _s, d in sources if d)
                    verify_tree(part, part.root, roots, errs, counts,
                                ignore=remapped)
                print("  %-32s %5d files %4d dirs  %s"
                      % (ident, counts["files"], counts["dirs"],
                         "OK" if not errs else "%d errors" % len(errs)))
                for e in errs[:8]:
                    print("      %s" % e)
                allok = allok and not errs
        print("\n  %s" % ("every file round-trips byte-exact" if allok else "failures"))
        return

    here = os.path.dirname(os.path.abspath(__file__))
    total = os.path.getsize(args.image) // SECTOR
    parts = {p[3]: p for p in plan(total) if p[2] == APA_TYPE_PFS}

    with open(args.image, "r+b" if args.write else "rb") as f:
        for ident, sources in layout.items():
            _s, length, _t, _i = parts[ident]
            part = Partition(f, parts[ident][0], length)
            stats = {"files": 0, "dirs": 0, "bytes": 0}

            # The root inode already exists from the format; give it fresh
            # content zones sized for the real entry count.
            entries = [(b".", part.root, DIR_MODE), (b"..", part.root, DIR_MODE)]
            tops = []
            for src, dest in sources:
                src = os.path.join(here, src)
                if dest:
                    zone = part.alloc(1)
                    entries.append((dest.encode("ascii"), zone, DIR_MODE))
                    tops.append((src, zone))
                else:
                    with os.scandir(src) as it:
                        for e in sorted(it, key=lambda e: e.name):
                            zone = part.alloc(1)
                            entries.append((e.name.encode("ascii"), zone,
                                            DIR_MODE if e.is_dir() else FILE_MODE))
                            tops.append((e, zone))

            chunks = pack_dentries(entries)
            nz = (len(chunks) * DENTRY_CHUNK + part.zone_size - 1) // part.zone_size
            run = part.alloc(nz)
            if args.write:
                blob = b"".join(chunks)
                blob += b"\0" * (nz * part.zone_size - len(blob))
                part.write_zones(run, blob)
                part.write_inode(part.root, DIR_MODE,
                                 len(chunks) * DENTRY_CHUNK, (run, nz))

            for item, zone in tops:
                if isinstance(item, str):                 # a remapped subdirectory
                    add_tree(part, item, zone, part.root, stats, args.write)
                elif item.is_dir():
                    add_tree(part, item.path, zone, part.root, stats, args.write)
                else:
                    size = item.stat().st_size
                    n = (size + part.zone_size - 1) // part.zone_size
                    r = part.alloc(n) if size else None
                    if args.write:
                        with open(item.path, "rb") as fh:
                            data = fh.read()
                        if size:
                            part.write_zones(r, data + b"\0" * (n * part.zone_size - size))
                        part.write_inode(zone, FILE_MODE, size, (r, n) if size else None)
                    stats["files"] += 1
                    stats["bytes"] += size

            if args.write:
                part.flush_bitmap()
            print("  %-32s %5d files %4d dirs  %8.1f MiB  zones %d/%d (%.0f%% full)"
                  % (ident, stats["files"], stats["dirs"], stats["bytes"] / 1048576.0,
                     part.next_zone, part.zones, 100.0 * part.next_zone / part.zones))
        if args.write:
            f.flush()
            os.fsync(f.fileno())
    print("\n  %s" % ("written" if args.write else "plan only (use --write)"))


if __name__ == "__main__":
    main()

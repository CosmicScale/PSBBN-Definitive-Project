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
"""Format and populate an empty PFS partition found in a drive's existing APA table.

`polpfs` and `polfill` take every partition's LBA from `polhdd.plan()`, a
whole-drive layout for blank test images. On a drive that already carries
partitions (a PSBBN install) those offsets land on top of the existing
`__net`, `__system`, `__sysconf` and `__common`, so they must never be used
there. This module finds the partition by name in the on-disk APA chain
instead (it must exist already, see polapaadd), refuses one that already has
a PFS superblock unless `--refill` is given, runs `polpfs.format_partition()`
and reuses polfill's population code against the real LBA and length.

`--src` names the directory whose contents become the partition root.

    python3 -m playonline.lib.polrealfill IMAGE --list
    python3 -m playonline.lib.polrealfill IMAGE --partition PP.SLPS-20200.1000.POLVIEWER --src DIR          # plan only
    python3 -m playonline.lib.polrealfill IMAGE --partition PP.SLPS-20200.1000.POLVIEWER --src DIR --write
    python3 -m playonline.lib.polrealfill IMAGE --partition PP.SLPS-20200.1000.POLVIEWER --src DIR --verify
"""
import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from . import polfill                                                    # noqa: E402
from . import polpfs                                                     # noqa: E402
from .polhdd import APA_TYPE_PFS                                   # noqa: E402
from .polnetdump import partitions                                 # noqa: E402
from .polpfs import PFS_SUPER_MAGIC, ZONE_SIZE                      # noqa: E402

SECTOR = 512


def device_size(path):
    """Size in bytes of a file or block device.

    Seeks to the end, because os.path.getsize() reports 0 for a raw block
    device on Linux."""
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        return f.tell()


def find_partition(f, size, name):
    for start, length, ptype, ident in partitions(f, size):
        if ident == name:
            return start, length, ptype
    return None


def read_superblock_magic(f, lba):
    f.seek((lba + 8192) * SECTOR)
    magic, = struct.unpack_from("<I", f.read(4), 0)
    return magic


def nest(sources):
    """Split `sources` into top-level pairs and the ones mounted inside them.

    A destination may name a path rather than a single directory, because a
    partition directory is not always one directory in the staged tree. The
    Viewer's `ps2drv` is the disc's `ps2drv/modules`, with the disc's
    `ps2drv/data/kbd` inside it as `kbd`, so its layout reads

        ("POL/ps2drv/modules", "ps2drv"), ("POL/ps2drv/data/kbd", "ps2drv/kbd")

    Returns (top-level sources, {top-level dest: extra for polfill.add_tree}).
    Raises ValueError for a nested destination whose top-level directory no
    source supplies.
    """
    tops = [(src, dest) for src, dest in sources if "/" not in dest]
    named = {dest for _src, dest in tops if dest}
    extra = {}
    for src, dest in sources:
        if "/" not in dest:
            continue
        top, rest = dest.split("/", 1)
        if top not in named:
            raise ValueError("%r is mounted inside %r, which nothing supplies"
                             % (dest, top))
        if "/" in rest:
            raise ValueError("%r mounts more than one level deep; nothing "
                             "supplies the directories in between" % dest)
        extra.setdefault(top, {})[rest] = (src, {})
    return tops, extra


def populate(f, lba, length, sources, write):
    """Fill the formatted partition at `lba`, as polfill.main() does for a planned one."""
    part = polfill.Partition(f, lba, length, zone_size=ZONE_SIZE)
    stats = {"files": 0, "dirs": 0, "bytes": 0}
    sources, mounted = nest(sources)

    entries = [(b".", part.root, polfill.DIR_MODE), (b"..", part.root, polfill.DIR_MODE)]
    tops = []
    for src, dest in sources:
        src = os.path.join(HERE, src)
        if dest:
            zone = part.alloc(1)
            entries.append((dest.encode("ascii"), zone, polfill.DIR_MODE))
            tops.append((src, zone, mounted.get(dest)))
        else:
            with os.scandir(src) as it:
                for e in sorted(it, key=lambda e: e.name):
                    zone = part.alloc(1)
                    entries.append((e.name.encode("ascii"), zone,
                                    polfill.DIR_MODE if e.is_dir() else polfill.FILE_MODE))
                    tops.append((e, zone, None))

    chunks = polfill.pack_dentries(entries)
    nz = (len(chunks) * polfill.DENTRY_CHUNK + part.zone_size - 1) // part.zone_size
    run = part.alloc(nz)
    if write:
        blob = b"".join(chunks)
        blob += b"\0" * (nz * part.zone_size - len(blob))
        part.write_zones(run, blob)
        part.write_inode(part.root, polfill.DIR_MODE,
                         len(chunks) * polfill.DENTRY_CHUNK, (run, nz))

    for item, zone, extra in tops:
        if isinstance(item, str):
            polfill.add_tree(part, item, zone, part.root, stats, write, extra)
        elif item.is_dir():
            polfill.add_tree(part, item.path, zone, part.root, stats, write, extra)
        else:
            size = item.stat().st_size
            n = (size + part.zone_size - 1) // part.zone_size
            r = part.alloc(n) if size else None
            if write:
                with open(item.path, "rb") as fh:
                    data = fh.read()
                if size:
                    part.write_zones(r, data + b"\0" * (n * part.zone_size - size))
                part.write_inode(zone, polfill.FILE_MODE, size, (r, n) if size else None)
            stats["files"] += 1
            stats["bytes"] += size

    if write:
        part.flush_bitmap()
    return part, stats


def verify_format(f, lba, length):
    """Check a fresh format with polpfs.verify().

    Valid only before any content is added: the bitmap check asserts that the
    first zone past the reserved area is still free."""
    bad = polpfs.verify(f, lba, length, zone_size=ZONE_SIZE)
    if bad:
        print("  format verification failed:")
        for b in bad:
            print("      %s" % b)
        return False
    print("  format verified: superblock/journal/root all pass the driver's mount checks")
    return True


def superblock_ok(f, lba):
    """Minimal structural check for a filled volume, where polpfs.verify()'s
    bitmap test no longer applies."""
    magic = read_superblock_magic(f, lba)
    if magic != PFS_SUPER_MAGIC:
        return False, "superblock magic %08x" % magic
    return True, None


def _verify_mounts(part, zone, sub, dest, extra, errs, counts):
    """Check the directories `nest` mounted inside `dest` against their own
    source roots, which `verify_tree` was told to ignore."""
    if not extra:
        return
    ino = polfill.read_inode(part, zone, sub)
    have = {n: (z, s, m) for n, z, s, m in polfill.read_dir_full(part, ino)
            if n not in (b".", b"..")}
    for name in sorted(extra):
        src, _deeper = extra[name]
        key = name.encode()
        if key not in have:
            errs.append("/%s/%s: missing" % (dest, name))
            continue
        polfill.verify_tree(part, have[key][0], [os.path.join(HERE, src)],
                            errs, counts, "/%s/%s/" % (dest, name),
                            sub=have[key][1])


def verify(f, lba, length, sources, subs=None):
    """Compare the volume at `lba` with `sources`, whoever wrote it.

    The geometry is read from the superblock by `polpfsread.mount` (zone size
    and the root's zone and sub), so the check also covers volumes written by
    pfsshell. Its `mkpart` splits anything past the drive's main-partition
    ceiling into a main partition plus APA sub-partitions, a layout this
    module's writer does not produce. `subs` maps sub index to start LBA;
    when it is None the APA chain is walked for it.
    """
    ok, err = superblock_ok(f, lba)
    if not ok:
        print("  superblock check failed: %s" % err)
        return False

    from . import polpfsread
    from .polnetdump import sub_partitions
    if subs is None:
        f.seek(0, os.SEEK_END)
        subs = sub_partitions(f, f.tell()).get(lba)
    part, ino = polpfsread.mount(f, lba, length, subs)
    if part is None:
        print("  the superblock is there, but no root directory reads back "
              "from where it points")
        return False
    sb = polpfsread.superblock(f, lba)
    root_zone, root_sub = sb["root"] if sb else (part.root, 0)
    if subs:
        print("  volume spans the main partition and %d sub-partition(s), "
              "zone size %d" % (len(subs), part.zone_size))

    sources, mounted = nest(sources)
    have = {n: (z, s, m) for n, z, s, m in polfill.read_dir_full(part, ino)
            if n not in (b".", b"..")}
    errs, counts = [], {"files": 0, "dirs": 0}
    roots = [os.path.join(HERE, s) for s, d in sources if not d]
    for s, d in sources:
        if d:
            if d.encode() not in have:
                errs.append("/%s: missing" % d)
            else:
                # A mounted name comes from another source root, so it is not
                # 'extra' here; it is checked against its own root below.
                extra = mounted.get(d) or {}
                dz, ds, _dm = have[d.encode()]
                polfill.verify_tree(part, dz,
                                    [os.path.join(HERE, s)], errs, counts, "/%s/" % d,
                                    ignore=tuple(n.encode() for n in extra), sub=ds)
                _verify_mounts(part, dz, ds, d, extra, errs, counts)
    if roots:
        remapped = tuple(d.encode() for _s, d in sources if d)
        polfill.verify_tree(part, root_zone, roots, errs, counts, ignore=remapped,
                            sub=root_sub)

    print("  %d files, %d dirs checked" % (counts["files"], counts["dirs"]))
    if errs:
        print("  %d error(s):" % len(errs))
        for e in errs[:20]:
            print("      %s" % e)
        return False
    print("  every file round-trips byte-exact")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image", help="device path or .img file")
    ap.add_argument("--list", action="store_true", help="list real on-disk partitions")
    ap.add_argument("--partition", metavar="PARTID",
                    help="the partition to fill, by name")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--src", metavar="DIR",
                    help="fill from this directory as the partition root; "
                         "required with --partition")
    ap.add_argument("--refill", action="store_true",
                    help="allow re-formatting a partition that already has a PFS "
                         "superblock (its old contents are discarded)")
    a = ap.parse_args()

    size = device_size(a.image)

    if a.list or not a.partition:
        with open(a.image, "rb") as f:
            for start, length, ptype, ident in partitions(f, size):
                kind = "PFS" if ptype == APA_TYPE_PFS else "0x%04x" % ptype
                print("  LBA %9d  %6d MiB  %-4s  %s"
                      % (start, length * SECTOR // (1024 * 1024), kind, ident or "(free)"))
        return

    if not a.src:
        sys.exit("--partition needs --src DIR")
    if not os.path.isdir(a.src):
        sys.exit("--src %s is not a directory" % a.src)
    sources = [(os.path.abspath(a.src), "")]

    mode = "r+b" if a.write else "rb"
    with open(a.image, mode) as f:
        hit = find_partition(f, size, a.partition)
        if hit is None:
            sys.exit("no partition named %s on this drive; run polapaadd.py first"
                     % a.partition)
        lba, length, ptype = hit
        if ptype != APA_TYPE_PFS:
            sys.exit("%s has APA type 0x%04x and PFS is 0x%04x; wrong partition?"
                     % (a.partition, ptype, APA_TYPE_PFS))
        print("found %s: LBA %d, %d MiB" % (a.partition, lba, length * SECTOR // (1024 * 1024)))

        if a.verify:
            ok = verify(f, lba, length, sources)
            sys.exit(0 if ok else 1)

        magic = read_superblock_magic(f, lba)
        if magic == PFS_SUPER_MAGIC and not a.refill:
            sys.exit("refusing: %s already has a valid PFS superblock; "
                     "pass --refill to re-format it (old contents are lost)."
                     % a.partition)
        if magic == PFS_SUPER_MAGIC:
            print("--refill: re-formatting an existing PFS volume")

        print("formatting (zone_size=%d)..." % ZONE_SIZE)
        info = polpfs.format_partition(f, lba, length, zone_size=ZONE_SIZE, dry=not a.write)
        print("  root_number=%d log=%d+%d bm_start=%d reserved=%d"
              % (info["root_number"], info["log_number"], info["log_count"],
                 info["bm_start"], info["reserved"]))

        if a.write:
            f.flush()
            os.fsync(f.fileno())
            if not verify_format(f, lba, length):
                sys.exit("refusing to populate on top of a bad format")

        print("populating from %s..." % ", ".join(s for s, _d in sources))
        part, stats = populate(f, lba, length, sources, a.write)
        print("  %d files, %d dirs, %.2f MiB, zones %d/%d (%.0f%% full)"
              % (stats["files"], stats["dirs"], stats["bytes"] / 1048576.0,
                 part.next_zone, part.zones, 100.0 * part.next_zone / part.zones))

        if a.write:
            f.flush()
            os.fsync(f.fileno())

    if not a.write:
        print("\n  (plan only; pass --write to commit, then --verify to check)")
    else:
        print("\n  wrote %s; run with --verify to confirm the round trip" % a.partition)


if __name__ == "__main__":
    main()

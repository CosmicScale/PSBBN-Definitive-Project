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
"""Make a small throwaway image to test the write path against.

This is a test harness and plays no part in installing anything. It lets the
format, fill and attribute-area code run end to end without going near a
real drive.

It writes an APA table with `__mbr`, optionally the system partitions, one
game partition, and free space. A real drive carries more (`__net`,
`__system`, `__sysconf`, `__common`), and on a PSBBN drive the table belongs
to the toolkit. This is the smallest table the filesystem code accepts, in a
file of a few hundred MiB.

    python3 -m playonline.testimage OUT.img --partition PP.SCUS-97269.0002.TETRAMASTER
    python3 -m playonline.testimage OUT.img --system --partition NAME --write
"""
import argparse
import os
import sys

from .lib import polhdd

SECTOR = 512
MIB = 2048                      # sectors


# The system partitions of a PSBBN or HOSDMenu drive that matter here. `__net`
# is not among them; netpart.py adds it.
PSBBN_PARTS = [("__system", 256), ("__sysconf", 512), ("__common", 1024)]


def plan(partition, part_mib, total_mib, system=False):
    """[(start, length, type, id)] for the test drive's whole table."""
    parts = [(0, polhdd.MIN_PART, polhdd.APA_TYPE_MBR, "__mbr")]
    pos = polhdd.MIN_PART
    wanted = list(PSBBN_PARTS) if system else []
    if partition:
        wanted.append((partition, part_mib))
    for name, mib in wanted:
        n = mib * MIB
        if n & (n - 1):
            raise ValueError("%d MiB is not a power of two" % mib)
        pad = (-pos) % n
        for fs, fl in polhdd.buddy_free(pos, pos + pad):
            parts.append((fs, fl, polhdd.APA_TYPE_FREE, polhdd.EMPTY_ID))
        pos += pad
        parts.append((pos, n, polhdd.APA_TYPE_PFS, name))
        pos += n
    for fs, fl in polhdd.buddy_free(pos, total_mib * MIB):
        parts.append((fs, fl, polhdd.APA_TYPE_FREE, polhdd.EMPTY_ID))
    return parts


def create(path, partition, part_mib=128, total_mib=512, write=False,
           system=False):
    total_sectors = total_mib * MIB
    parts = plan(partition, part_mib, total_mib, system)
    if not write:
        return parts, total_sectors
    # Create the file at full length first: the table's last header sits near
    # the end, and a short file would read back as a truncated chain.
    with open(path, "wb") as f:
        f.truncate(total_sectors * SECTOR)
    polhdd.write_table(path, parts, total_sectors, dry_run=False)
    # The Viewer mounts __system and __common at startup, before its own
    # partition. If they are unformatted it stops with
    # `pfs: error: invalid magic/version` and a "no HDD" message, so the
    # system partitions made here are given an empty filesystem.
    if system:
        from .lib import polpfs
        with open(path, "r+b") as f:
            for start, length, ptype, ident in parts:
                if ident in [name for name, _mib in PSBBN_PARTS]:
                    polpfs.format_partition(f, start, length)
    return parts, total_sectors


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("out")
    ap.add_argument("--partition", default="",
                    help="a game partition to create as well as the system ones")
    ap.add_argument("--system", action="store_true",
                    help="also create __system, __sysconf and __common, as a "
                         "PSBBN or HOSDMenu drive has; netpart.py adds __net")
    ap.add_argument("--size", type=int, default=128, metavar="MIB",
                    help="the game partition, a power of two (default 128)")
    ap.add_argument("--total", type=int, default=512, metavar="MIB")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    if os.path.exists(args.out) and args.write:
        sys.exit("%s exists; delete it first" % args.out)
    parts, total = create(args.out, args.partition, args.size, args.total,
                          args.write, args.system)
    for start, length, ptype, ident in parts:
        kind = {polhdd.APA_TYPE_FREE: "free", polhdd.APA_TYPE_MBR: "mbr",
                polhdd.APA_TYPE_PFS: "PFS"}.get(ptype, "0x%04x" % ptype)
        print("  LBA %9d  %6d MiB  %-4s %s" % (start, length // MIB, kind, ident))
    print("%s %d partition(s), %d MiB total"
          % ("wrote" if args.write else "would write", len(parts), total // MIB))


if __name__ == "__main__":
    main()

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
"""Read a PS2 APA partition table, without ever writing to it.

Partition tables are written by `lib/polhdd` and `lib/polapaadd` or, on a
PSBBN drive, by the toolkit's pfsshell and hdl_dump. This module serves the
parts of the installer that only inspect a drive (is PlayOnline installed,
how much space is free, where does a partition start), so they carry no risk
of writing.

The header layout follows ps2sdk `iop/hdd/libapa`:

    0x000 u32 checksum     sum of u32 words 1..255
    0x004 u32 magic        'APA\0'
    0x008 u32 next         LBA of the next header, 0 on the last
    0x00C u32 prev         LBA of the previous; on the MBR, the last
                           partition, because the list is circular
                           (hdl_dump's apa_check rejects a table where it
                           is not)
    0x010 char id[32]
    0x030 char rpwd[8]     read password
    0x038 char fpwd[8]     format password
    0x040 u32 start
    0x044 u32 length       sectors
    0x048 u16 type         0 = free, 1 = MBR, 0x100 = PFS
    0x04A u16 flags        1 = sub-partition

Every length is a power of two of at least 128 MiB and every start is a
multiple of its own length. Free space is not implicit: it is held by real
headers of type 0.

    python3 -m playonline.apa DRIVE_OR_IMAGE
"""
import struct

SECTOR = 512
APA_MAGIC = 0x00415041
TYPE_FREE = 0x0000
TYPE_MBR = 0x0001
TYPE_PFS = 0x0100


class Partition(object):
    __slots__ = ("lba", "sectors", "ident", "type", "flags", "next", "prev")

    def __init__(self, lba, sectors, ident, type_, flags, next_, prev):
        self.lba = lba
        self.sectors = sectors
        self.ident = ident
        self.type = type_
        self.flags = flags
        self.next = next_
        self.prev = prev

    @property
    def mib(self):
        return self.sectors // 2048

    @property
    def is_free(self):
        return self.type == TYPE_FREE

    @property
    def is_sub(self):
        return bool(self.flags & 1)

    def __repr__(self):
        return "<%s lba=%d %d MiB type=0x%04x>" % (
            self.ident or "(free)", self.lba, self.mib, self.type)


def _header(f, lba):
    f.seek(lba * SECTOR)
    h = f.read(1024)
    if len(h) < 1024 or struct.unpack_from("<I", h, 4)[0] != APA_MAGIC:
        raise ValueError("no APA header at LBA %d" % lba)
    return h


def partitions(path):
    """Walk the chain from the MBR. Returns [Partition], table order.

    Stops on a repeated LBA, so a corrupt chain cannot loop forever.
    """
    out = []
    seen = set()
    with open(path, "rb") as f:
        lba = 0
        while True:
            if lba in seen:
                break
            seen.add(lba)
            h = _header(f, lba)
            start, length = struct.unpack_from("<II", h, 0x40)
            type_, flags = struct.unpack_from("<HH", h, 0x48)
            nxt, prev = struct.unpack_from("<I", h, 8)[0], struct.unpack_from("<I", h, 0x0C)[0]
            ident = h[0x10:0x30].split(b"\0")[0].decode("latin-1")
            out.append(Partition(start, length, ident, type_, flags, nxt, prev))
            if nxt == 0:
                break
            lba = nxt
    return out


def find_partition(path, name):
    """(lba, sectors) of `name`. Raises KeyError if it is not there."""
    for p in partitions(path):
        if p.ident == name:
            return p.lba, p.sectors
    raise KeyError(name)


def free_entries(path):
    """The free (type 0) entries, largest first.

    A new partition has to fit inside one entry: an entry is split at its
    own power-of-two boundaries, so fragments that add up to enough space may
    still not hold the partition. On a PSBBN drive the split is done by
    pfsshell's `mkpart`; on an image, by `polapaadd`.
    """
    free = [p for p in partitions(path) if p.is_free and not p.is_sub]
    free.sort(key=lambda p: p.sectors, reverse=True)
    return free


def installed_titles(path, prefix="PP."):
    """Game partitions already on the drive, by name."""
    return [p for p in partitions(path)
            if p.ident.startswith(prefix) and not p.is_sub]


def describe(path):
    lines = []
    for p in partitions(path):
        kind = {TYPE_FREE: "free", TYPE_MBR: "mbr", TYPE_PFS: "PFS"}.get(p.type, "0x%04x" % p.type)
        lines.append("  LBA %9d  %6d MiB  %-4s %s%s"
                     % (p.lba, p.mib, kind, p.ident, "  (sub)" if p.is_sub else ""))
    return "\n".join(lines)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -m playonline.apa DRIVE_OR_IMAGE")
    print(describe(sys.argv[1]))

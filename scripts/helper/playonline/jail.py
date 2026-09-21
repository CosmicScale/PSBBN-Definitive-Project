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
r"""Find the edge of the APA region, so nothing is carved past it.

PSBBN Definitive does not give the whole disk to the PlayStation 2. Its
APA-Jail step (by Berion) writes a PC MBR at the front of the disk:

    partition 1   type 0x17   the APA region, where the PS2's partitions live
    partition 2   type 0x17   RECOVERY, 32 MiB, ext2: holds the APA index
                              backup and the spare GPT
    partition 3   type 0x07   exFAT, labelled OPL: the user's games

and writes `APAJ-A2\0` at byte 224 of the first sector.

The APA chain does not know about the MBR. It describes free space by the
disk's geometry, so on a jailed drive its free space can extend past the end
of the APA region, across RECOVERY and the exFAT partition. Creating a
partition there would succeed and overwrite the user's data. Every partition
this installer creates is therefore checked against the MBR first. Where
there is no MBR (a plain image or an unjailed drive) the whole device is
available and the check passes.

    python3 -m playonline.jail DEVICE_OR_IMAGE
"""
import struct

SECTOR = 512
MBR_SIG = 0xAA55
JAIL_MAGIC = b"APAJ-A2\x00"
JAIL_MAGIC_OFFSET = 224            # PSBBN writes it with dd bs=8 seek=28
TYPE_APA = 0x17                    # the type APA-Jail gives the PS2 region
TYPE_EXFAT = 0x07


class Entry(object):
    __slots__ = ("index", "type", "start", "sectors")

    def __init__(self, index, type_, start, sectors):
        self.index = index
        self.type = type_
        self.start = start
        self.sectors = sectors

    @property
    def end(self):
        return self.start + self.sectors

    @property
    def mib(self):
        return self.sectors // 2048

    def __repr__(self):
        return "<mbr%d type=0x%02x %d..%d (%d MiB)>" % (
            self.index, self.type, self.start, self.end, self.mib)


def read_mbr(path):
    """The four primary partitions, or None if this is not an MBR disk.

    The 0x55AA signature is required: on a drive with no MBR, offset 0x1BE
    lies inside the APA header and would be misread as a partition table.
    """
    with open(path, "rb") as f:
        sector = f.read(SECTOR)
    if len(sector) < SECTOR:
        return None
    if struct.unpack_from("<H", sector, 0x1FE)[0] != MBR_SIG:
        return None
    out = []
    for i in range(4):
        off = 0x1BE + i * 16
        type_ = sector[off + 4]
        start, count = struct.unpack_from("<II", sector, off + 8)
        if type_ and count:
            out.append(Entry(i + 1, type_, start, count))
    return out


def is_jailed(path):
    """True if APA-Jail's signature is on the drive."""
    with open(path, "rb") as f:
        f.seek(JAIL_MAGIC_OFFSET)
        return f.read(len(JAIL_MAGIC)) == JAIL_MAGIC


def apa_region(path):
    """(start, sectors) the PS2 is allowed to use, or None for the whole disk.

    The first type-0x17 entry is the APA region. RECOVERY is type 0x17 too,
    and APA-Jail always places it second.
    """
    parts = read_mbr(path)
    if not parts:
        return None
    for p in parts:
        if p.type == TYPE_APA:
            return p.start, p.sectors
    return None


def other_regions(path):
    """Every MBR entry other than the APA region: the data to protect."""
    parts = read_mbr(path) or []
    apa = apa_region(path)
    if not apa:
        return []
    return [p for p in parts if (p.start, p.sectors) != apa]


def check(path, lba, sectors):
    """(ok, message) for putting a partition at `lba` for `sectors`.

    Anything is allowed on a device without an MBR. On a jailed drive the
    partition must lie inside the APA region.
    """
    region = apa_region(path)
    if region is None:
        return True, "no MBR: the whole device is APA"
    start, count = region
    end = start + count
    if lba < start:
        return False, ("LBA %d is before the APA region (starts at %d)"
                       % (lba, start))
    if lba + sectors > end:
        overlap = []
        for p in other_regions(path):
            if lba < p.end and p.start < lba + sectors:
                overlap.append("mbr%d type 0x%02x%s"
                               % (p.index, p.type,
                                  " (exFAT - the games)" if p.type == TYPE_EXFAT else ""))
        return False, ("would end at LBA %d, past the APA region's end at %d%s"
                       % (lba + sectors, end,
                          "; it would land in " + ", ".join(overlap) if overlap else ""))
    return True, ("inside the APA region, %d MiB to spare"
                  % ((end - (lba + sectors)) // 2048))


def describe(path):
    lines = []
    parts = read_mbr(path)
    if not parts:
        lines.append("  no MBR: the whole device is the PS2's")
        return "\n".join(lines)
    lines.append("  APA-Jail signature: %s" % ("present" if is_jailed(path) else "ABSENT"))
    for p in parts:
        what = {TYPE_APA: "APA / PS2", TYPE_EXFAT: "exFAT - games"}.get(p.type, "?")
        lines.append("  mbr%d  type 0x%02x  LBA %-12d %7d MiB  %s"
                     % (p.index, p.type, p.start, p.mib, what))
    region = apa_region(path)
    if region:
        lines.append("  the PS2 may use LBA %d .. %d only"
                     % (region[0], region[0] + region[1]))
    return "\n".join(lines)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -m playonline.jail DEVICE_OR_IMAGE")
    print(describe(sys.argv[1]))

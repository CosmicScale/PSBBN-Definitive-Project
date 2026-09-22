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
"""Read back the sector the console writes while it boots, and say what it says.

Once the Viewer has been entered it owns the screen, and a console that stops
needs a power cycle, which clears IOP RAM. The disk is the only medium that
survives, so a diagnostic loader records its progress in one 512-byte sector.
`loader-src/poltrace.h` defines the record and the rules that keep the write
safe; this is the other end of it.

The sector is the first one of `/trace.bin` in the Viewer partition. The
installer writes that file, blank but for its magic, and reads it back on
every later run. The magic is the safety catch: the loader reads the sector
before its first write and refuses unless the magic is already there, so a
wrong location costs one harmless read and nothing else.

Nothing here needs the console to have written anything. A blank record reads
as "the console has not reached the trace yet", which is itself the answer
when a title returns to the browser having drawn nothing.

    python3 -m playonline.poltrace /dev/sdX --partition PP.SCUS-97269.1000.POLVIEWER
"""

import argparse
import os
import struct
import sys

from .lib import polfill, polnetdump, polpfspatch, polpfsread

PATH = "/trace.bin"
SECTOR = 512
SIZE = 512

MAGIC0 = 0x544C4F50                      # "POLT"
MAGIC1 = 0x45434152                      # "RACE"
VER = 0x00020000

NORD = 20                                # atad exports 19 functions
NREG = 16                                # libraries whose names are kept
NEV = 15                                 # ring of most recent events

# Offsets, from the struct in poltrace.h. Kept as names rather than a single
# format string so a field that moves there fails loudly here.
O_SEQ = 0x00C
O_NCALL = 0x010
O_NREG = 0x060
O_NEVENT = 0x064
O_LAST_LBA = 0x068
O_LAST_NSEC_DIR = 0x06C
O_WRITES_OK = 0x070
O_WRITES_ERR = 0x074
O_STATE = 0x078
O_TRACE_LBA = 0x07C
O_REG = 0x080
O_EV = 0x140
O_TAIL = 0x1F4
O_BOOTS = 0x1F8
O_ARM_TRIES = 0x1FC

STATE_BITS = [
    (0x0001, "CHECKED", "the magic read happened"),
    (0x0002, "ARMED", "magic was there, writing allowed"),
    (0x0004, "ATAD", "an atad registered and was patched"),
    (0x0008, "HOOKED", "the loadcore trampoline is in"),
    (0x0010, "NOMAGIC", "read worked, magic absent, write refused"),
    (0x0020, "READERR", "the probe read itself failed"),
    (0x0040, "HEARTBEAT", "reserved"),
    (0x0080, "HBSTOP", "reserved"),
]

EVENTS = {
    1: ("HOOK", "trace sector at LBA %(a)d"),
    2: ("REG", "module registered, version 0x%(b)04X"),
    3: ("ARM", "arming: read result %(a)d, state 0x%(b)04X"),
    4: ("IO", "ata call, ordinal %(ord)d, %(nsec)d sector(s), LBA %(b)d"),
    5: ("IOERR", "ata call failed, ordinal %(a)d, result %(b)d"),
    6: ("FAKE", "answered ordinal %(a)d ourselves, call %(b)d"),
    7: ("TICK", "reserved"),
    8: ("HBSTOP", "a second dev9/atad: name 0x%(a)08X, reason 0x%(b)04X"),
    9: ("STAGE", "reserved"),
}


def blank():
    """The 512 bytes the installer writes, which is what arms the channel."""
    blk = bytearray(SIZE)
    struct.pack_into("<III", blk, 0, MAGIC0, MAGIC1, VER)
    struct.pack_into("<I", blk, O_TAIL, MAGIC1)
    return bytes(blk)


def is_trace(blk):
    if len(blk) < SIZE:
        return False
    m0, m1 = struct.unpack_from("<II", blk, 0)
    return m0 == MAGIC0 and m1 == MAGIC1


def written(blk):
    """True when a console has recorded anything in it."""
    if not is_trace(blk):
        return False
    seq, = struct.unpack_from("<I", blk, O_SEQ)
    nevent, = struct.unpack_from("<I", blk, O_NEVENT)
    boots, = struct.unpack_from("<I", blk, O_BOOTS)
    return bool(seq or nevent or boots)


def _u32(blk, off):
    return struct.unpack_from("<I", blk, off)[0]


def decode(blk):
    """[str] describing the record, in the order a reader wants it."""
    if not is_trace(blk):
        return ["no trace record here (magic absent). The installer writes "
                "%s when it installs the Viewer; a drive from an earlier "
                "version will not have it." % PATH]

    out = []
    state = _u32(blk, O_STATE)
    boots = _u32(blk, O_BOOTS)
    seq = _u32(blk, O_SEQ)
    nevent = _u32(blk, O_NEVENT)

    if not written(blk):
        out.append("the record is blank: the console has not written to it.")
        out.append("Either the loader has no trace build on it, or the boot "
                   "stopped before the trace could arm.")
        return out

    out.append("boots seen by the check module : %d" % boots)
    out.append("flushes                        : %d (seq), %d ok, %d failed"
               % (seq, _u32(blk, O_WRITES_OK), _u32(blk, O_WRITES_ERR)))
    out.append("events recorded                : %d" % nevent)
    out.append("trace sector the build was given: LBA %d"
               % _u32(blk, O_TRACE_LBA))
    out.append("arming reads spent             : %d" % _u32(blk, O_ARM_TRIES))

    names = [n for bit, n, _why in STATE_BITS if state & bit]
    out.append("state 0x%04X                    : %s"
               % (state, ", ".join(names) if names else "nothing set"))
    for bit, name, why in STATE_BITS:
        if state & bit:
            out.append("    %-10s %s" % (name, why))

    calls = [(i, _u32(blk, O_NCALL + 4 * i)) for i in range(NORD)]
    busy = [(i, n) for i, n in calls if n]
    if busy:
        out.append("ata calls by ordinal           : "
                   + ", ".join("%d=%d" % (i, n) for i, n in busy))
    last = _u32(blk, O_LAST_NSEC_DIR)
    out.append("last ata read/write            : LBA %d, %d sector(s), %s"
               % (_u32(blk, O_LAST_LBA), last >> 8,
                  "write" if last & 0xFF else "read"))

    nreg = _u32(blk, O_NREG)
    out.append("modules registered             : %d" % nreg)
    for i in range(min(nreg, NREG)):
        raw = blk[O_REG + 12 * i:O_REG + 12 * i + 8]
        ver = _u32(blk, O_REG + 12 * i + 8)
        name = raw.split(b"\x00")[0].decode("latin-1").strip()
        if name:
            out.append("    %-8s version 0x%04X" % (name, ver))

    out.append("events, oldest first:")
    shown = min(nevent, NEV)
    for i in range(shown):
        code = _u32(blk, O_EV + 12 * i)
        a = _u32(blk, O_EV + 12 * i + 4)
        b = _u32(blk, O_EV + 12 * i + 8)
        if code == 0 and a == 0 and b == 0:
            continue
        name, fmt = EVENTS.get(code, ("EV%d" % code, "a=%(a)d b=%(b)d"))
        try:
            detail = fmt % {"a": a, "b": b,
                            "ord": (a >> 24) & 0xFF, "nsec": a & 0xFFFFFF}
        except (KeyError, ValueError, TypeError):
            detail = "a=%d b=%d" % (a, b)
        out.append("    %-7s %s" % (name, detail))
    if nevent > NEV:
        out.append("    (the ring keeps the most recent %d of %d)"
                   % (NEV, nevent))
    return out


def locate(f, size, partition, path=PATH):
    """(lba, ino) for `path` in `partition`, or (None, why).

    The absolute sector is the partition's own LBA plus the file's first zone,
    which is how polpfspatch reaches a file's bytes.
    """
    hit = [p for p in polnetdump.partitions(f, size) if p[3] == partition]
    if not hit:
        return None, "no partition named %s" % partition
    part, root = polpfsread.mount(f, hit[0][0], hit[0][1])
    if part is None:
        return None, "%s did not mount" % partition
    try:
        _zone, ino = polpfspatch.find(part, root, path)
    except (SystemExit, KeyError, ValueError, IOError, OSError):
        return None, "%s has no %s" % (partition, path)
    if not ino["runs"]:
        return None, "%s%s has no blocks" % (partition, path)
    number = ino["runs"][0][0]
    return part.lba + (number << part.scale), None


def read(drive, partition, path=PATH):
    """(block, lba, why). block is None when it could not be read."""
    with open(drive, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        lba, why = locate(f, size, partition, path)
        if lba is None:
            return None, None, why
        f.seek(lba * SECTOR)
        return f.read(SIZE), lba, None


def report(drive, partition, path=PATH):
    """[str] for the installer's report file. Never raises."""
    try:
        blk, lba, why = read(drive, partition, path)
    except (IOError, OSError, ValueError) as e:
        return ["could not read the trace: %s" % e]
    if blk is None:
        return ["no trace available: %s" % why]
    return ["trace sector: LBA %d" % lba] + decode(blk)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--partition", required=True)
    ap.add_argument("--path", default=PATH)
    ap.add_argument("--blank", metavar="OUT",
                    help="write the blank record to a file instead of "
                         "reading a drive, for staging into a partition")
    args = ap.parse_args()

    if args.blank:
        with open(args.blank, "wb") as f:
            f.write(blank())
        print("wrote %d B to %s" % (SIZE, args.blank))
        return 0

    for line in report(args.drive, args.partition, args.path):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

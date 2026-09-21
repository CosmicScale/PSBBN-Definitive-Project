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
"""Find the PlayOnline key record in the `__net` partition of a PS2 HDD image.

The Viewer's `.pex.enc` modules are decrypted with a key derived partly from
4 bytes that Square Enix's installer provisions into a raw record inside the
`__net` partition. This walks the APA table of a PCSX2 `DEV9hdd.raw` or a raw
drive dump, finds that record and prints it. Read-only. The APA walkers
`partitions()` and `sub_partitions()` are also used by other modules.

    python3 -m playonline.lib.polnetdump DEV9hdd.raw          # list partitions, find the record
    python3 -m playonline.lib.polnetdump DEV9hdd.raw --extract net.bin.gz

The record is 20 bytes, [4 provisioned bytes][8-byte console identity]
[8 zeros], base64-encoded into a 512-byte sector, with a sibling record one
sector later. The installer writes it at `__net` + 0x201800
(route.RECORD_OFFSET). This tool does not assume the offset and finds the
record by shape, a run of 384 or more base64 characters.
"""
import argparse
import gzip
import os
import re
import struct
import sys

SECTOR = 512
APA_MAGIC = 0x00415041                      # 'APA\0'
HEADER = 1024
B64_RUN = re.compile(rb"[A-Za-z0-9+/=]{384,}")


def partitions(fh, size):
    """Walk the APA chain from sector 0. Yields (start_lba, length_lba, type, name)."""
    seen, lba = set(), 0
    while True:
        if lba in seen or (lba + 2) * SECTOR > size:
            break
        seen.add(lba)
        fh.seek(lba * SECTOR)
        hdr = fh.read(HEADER)
        if len(hdr) < HEADER:
            break
        if struct.unpack_from("<I", hdr, 0x004)[0] != APA_MAGIC:
            raise SystemExit("no APA header at LBA %d; is this a PS2 HDD image?" % lba)
        nxt = struct.unpack_from("<I", hdr, 0x008)[0]
        start, length = struct.unpack_from("<II", hdr, 0x040)
        ptype = struct.unpack_from("<H", hdr, 0x048)[0]
        name = hdr[0x010:0x030].split(b"\0")[0].decode("ascii", "replace")
        yield start, length, ptype, name
        if not nxt:
            break
        lba = nxt


def sub_partitions(fh, size):
    """Map each main partition's start LBA to its `{sub index: start LBA}`.

    A PFS volume bigger than its main APA partition is extended with APA
    sub-partitions: ordinary chain entries with an empty id, the parent's LBA
    at +0x58 and a 1-based sub index at +0x5C. Every PFS blockinfo and every
    dentry carries that index, and a zone number is relative to the sub it
    names. The index does not follow chain order, so it is read from the
    header.
    """
    subs, seen, lba = {}, set(), 0
    while lba not in seen and (lba + 2) * SECTOR <= size:
        seen.add(lba)
        fh.seek(lba * SECTOR)
        hdr = fh.read(HEADER)
        if len(hdr) < HEADER:
            break
        if struct.unpack_from("<I", hdr, 0x004)[0] != APA_MAGIC:
            break
        nxt = struct.unpack_from("<I", hdr, 0x008)[0]
        start = struct.unpack_from("<I", hdr, 0x040)[0]
        main, number = struct.unpack_from("<2I", hdr, 0x058)
        if main and not hdr[0x010:0x030].split(b"\0")[0]:
            subs.setdefault(main, {})[number] = start
        if not nxt:
            break
        lba = nxt
    return subs


def find_blobs(data):
    """Every run of 384 or more base64 characters, as (offset, bytes)."""
    return [(m.start(), m.group()) for m in B64_RUN.finditer(data)]


def decode_record(b64):
    import base64
    raw = b64[:512].rstrip(b"\0")
    pad = len(raw) % 4
    if pad:
        raw = raw[:len(raw) - pad]
    try:
        return base64.b64decode(raw, validate=True)
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image", help="PCSX2 DEV9hdd.raw, or a raw drive dump")
    ap.add_argument("--partition", default="__net")
    ap.add_argument("--extract", metavar="OUT",
                    help="write the partition out (.gz compresses it to almost "
                         "nothing; it is mostly zeros)")
    ap.add_argument("--max-mib", type=int, default=8,
                    help="how much of the partition to scan/extract (default 8; "
                         "the record lives in the first few MiB)")
    args = ap.parse_args()

    size = os.path.getsize(args.image)
    with open(args.image, "rb") as fh:
        parts = list(partitions(fh, size))
        print("APA table: %d partitions" % len(parts))
        target = None
        for start, length, ptype, name in parts:
            if name:
                print("  LBA %9d  %7d MiB  type 0x%04x  %s"
                      % (start, length * SECTOR // (1 << 20), ptype, name))
            if name == args.partition:
                target = (start, length)
        if not target:
            raise SystemExit("no %s partition in this image" % args.partition)

        start, length = target
        n = min(length * SECTOR, args.max_mib << 20)
        fh.seek(start * SECTOR)
        data = fh.read(n)

    print("\n%s: LBA %d, scanning first %d MiB" % (args.partition, start, n >> 20))
    blobs = find_blobs(data)
    if not blobs:
        print("  no base64 blob found: this install has not been provisioned,"
              "\n  or the record lives past %d MiB (try --max-mib)" % (n >> 20))
    for off, b in blobs:
        print("  offset 0x%08x  %d chars" % (off, len(b)))
        print("    %s" % b[:64].decode())
        rec = decode_record(b)
        if rec:
            print("    decodes to %s" % rec[:20].hex(" "))
            print("    provisioned bytes: %s" % rec[:4].hex(" "))
    if args.extract:
        out = args.extract
        opener = gzip.open if out.endswith(".gz") else open
        with opener(out, "wb") as f:
            f.write(data)
        print("\nwrote %s (%d bytes on disk)" % (out, os.path.getsize(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

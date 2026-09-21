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
"""Read `POL/INSTALL.DAT`, the install container some PlayOnline discs carry.

Vana'diel Collection 2008 and Dirge of Cerberus do not carry the `_/N/M.K`
install archive that `polinstall` reads. They carry `POL/INSTALL.DAT` with a
`POL/INSTALL.INF` index instead.

`INSTALL.INF` is a bare sequence of records with no header and no count:

    u32  orig_size        decompressed size
    u32  stored_size      bytes in INSTALL.DAT
    u32  checksum         unsigned sum of the stored bytes
    char path[]           NUL terminated, '/' separated,
                          e.g. "POL/Data/PS2/chat.pex"

`INSTALL.DAT` is the payloads in index order, each padded up to a 2048-byte
boundary. Summing `align(stored_size, 2048)` over every record gives the
exact length of INSTALL.DAT on both discs, and `check_layout` confirms that
before anything is read.

`orig_size == stored_size` means the payload is stored raw. Otherwise it is
LZSS, the same codec the `_/N/M.K` archive uses, so `polinstall`'s
decompressor is reused.

The checksum covers the payload as it sits in INSTALL.DAT, before any
decompression, so it shows the payload was read from the right offset and is
intact. It says nothing about the decompression; for a compressed record the
only further check is the decompressed length against `orig_size`.

    python3 -m playonline.installdat DISC --list
    python3 -m playonline.installdat DISC --verify
    python3 -m playonline.installdat DISC --out DIR [--filter POL/Data/]
"""
import argparse
import os
import struct
import sys

from . import discs
from .lib import polinstall

ALIGN = 2048


class Record(object):
    __slots__ = ("orig", "stored", "checksum", "path", "offset")

    def __init__(self, orig, stored, checksum, path, offset):
        self.orig = orig
        self.stored = stored
        self.checksum = checksum
        self.path = path
        self.offset = offset

    @property
    def compressed(self):
        return self.orig != self.stored

    def __repr__(self):
        return "<%s %d B%s>" % (self.path, self.orig,
                                " lzss" if self.compressed else "")


def _pol_dir(image):
    root = {n.upper(): (l, s) for n, l, s, _d in discs.read_root(image)}
    if "POL" not in root:
        raise discs.NotADisc("no POL directory")
    lba, size = root["POL"]
    sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
    return {n.upper(): (l, s)
            for n, l, s, _d in discs._dir_records(image.read_sector(lba, sectors))}


def _read_file(image, lba, size):
    sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
    return image.read_sector(lba, sectors)[:size]


def index(image):
    """[Record] from POL/INSTALL.INF, with each payload's offset resolved."""
    pol = _pol_dir(image)
    if "INSTALL.INF" not in pol:
        raise discs.NotADisc("no POL/INSTALL.INF")
    blob = _read_file(image, *pol["INSTALL.INF"])
    out = []
    pos = offset = 0
    while pos + 12 <= len(blob):
        orig, stored, checksum = struct.unpack_from("<III", blob, pos)
        pos += 12
        end = blob.find(b"\0", pos)
        if end < 0:
            break
        path = blob[pos:end].decode("latin-1")
        pos = end + 1
        out.append(Record(orig, stored, checksum, path, offset))
        offset += (stored + ALIGN - 1) // ALIGN * ALIGN
    return out


def dat_extent(image):
    """(lba, size) of POL/INSTALL.DAT."""
    pol = _pol_dir(image)
    if "INSTALL.DAT" not in pol:
        raise discs.NotADisc("no POL/INSTALL.DAT")
    return pol["INSTALL.DAT"]


def check_layout(image, records=None):
    """Confirm the records account for INSTALL.DAT exactly.

    Every payload offset depends on the 2048-byte alignment, so this is
    checked before anything is extracted.
    """
    records = records if records is not None else index(image)
    _, size = dat_extent(image)
    want = sum((r.stored + ALIGN - 1) // ALIGN * ALIGN for r in records)
    return want == size, want, size


def payload(image, rec, dat_lba):
    """The stored bytes of one record."""
    first = rec.offset // discs.USER_DATA
    skip = rec.offset - first * discs.USER_DATA
    need = skip + rec.stored
    sectors = (need + discs.USER_DATA - 1) // discs.USER_DATA
    return image.read_sector(dat_lba + first, sectors)[skip:skip + rec.stored]


def extract(image, rec, dat_lba):
    """One record's file, decompressed if need be and checksum verified."""
    raw = payload(image, rec, dat_lba)
    if len(raw) != rec.stored:
        raise ValueError("%s: short read, %d of %d" % (rec.path, len(raw), rec.stored))
    got = sum(raw)
    if got != rec.checksum:
        raise ValueError("%s: checksum %d, index says %d" % (rec.path, got, rec.checksum))
    data = raw if not rec.compressed else polinstall.lzss_decompress(raw, rec.orig)
    if len(data) != rec.orig:
        raise ValueError("%s: decompressed to %d, index says %d"
                         % (rec.path, len(data), rec.orig))
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("disc")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--verify", action="store_true",
                    help="extract every record in memory and check it")
    ap.add_argument("--out", metavar="DIR")
    ap.add_argument("--filter", default="", metavar="PREFIX")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    image = discs.Image(args.disc)
    records = index(image)
    ok, want, size = check_layout(image, records)
    print("%d records; INSTALL.DAT %d B, records account for %d B: %s"
          % (len(records), size, want, "exact" if ok else "mismatch"))
    if not ok:
        sys.exit("refusing to read a container whose layout does not add up")

    chosen = [r for r in records if r.path.startswith(args.filter)]
    if args.limit:
        chosen = chosen[:args.limit]

    if args.list:
        for r in chosen:
            print("  %10d %10d %-6s %s"
                  % (r.orig, r.stored, "lzss" if r.compressed else "raw", r.path))
        return

    if not (args.verify or args.out):
        print("nothing to do: pass --list, --verify or --out")
        return

    dat_lba, _ = dat_extent(image)
    good = bad = 0
    for r in chosen:
        try:
            data = extract(image, r, dat_lba)
        except (ValueError, IOError) as e:
            print("  FAIL %s" % e)
            bad += 1
            continue
        good += 1
        if args.out:
            dst = os.path.join(args.out, r.path.replace("/", os.sep))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(data)
    print("%d file(s) verified, %d failed" % (good, bad))
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()

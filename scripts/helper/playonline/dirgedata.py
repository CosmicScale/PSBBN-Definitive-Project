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
r"""Read Dirge of Cerberus's own install container off its disc.

Dirge is not in the PlayOnline install container. Its tree is packed into
`/E419C51B/KEL.DAT` (1.27 GB), a run of independent zlib streams addressed by
2048-byte sector, and indexed by the root file `FILELIST.BIN`.

FILELIST.BIN is `[u32 name_table_off][u32 chunk_off][u32 count]`, `count`
8-byte records, then a table of `(decompressed, compressed, offset)` triples
naming zlib chunks that concatenate to NUL-separated text rows of the form
`id_sector:decompressed:stored:path` (all hex). Two properties of those rows
matter to a reader:

* A row whose stored size equals its decompressed size is held raw and must
  not be inflated. About a sixth of the disc is stored that way.
* Most rows carry a single space as their path. Their names come from the
  disc's own `file.txt`, `<hash>:<size>:<relpath>`, where the hash is
  base64(MD5) under PlayOnline's substituted alphabet, so a row is named by
  hashing its content. One hash can name many paths, and the content is
  written to every one of them.

Square Enix's installed partition holds more files than the disc's manifest
declares. The extra ones are written by their installer or delivered by the
patch service afterwards (`memown.pol`, `memown.dbg`, `polkey_beta.dat`, a
newer `file.txt` and `filelist.bin`, two hash-named download blobs and
`bin_patched/kel.pex`). This reader installs what the disc carries and
synthesises `config.sys`, the one root file the title needs and the disc
does not name, from the disc's `config.hdd`.

    python3 -m playonline.dirgedata DISC --list
    python3 -m playonline.dirgedata DISC --out DIR
"""
import argparse
import base64
import hashlib
import os
import struct
import sys
import zlib

from . import discs

KEL = "E419C51B/KEL.DAT"
FILELIST = "FILELIST.BIN"

# base64(MD5) under PlayOnline's alphabet, the same hash FFXI's manifest
# uses. This repeats ffxidata.sehash so that each reader stands alone.
_STD = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
_POL = "TSG8IncW3HFKokOg79qzeCmZs2yBYEQVAUxR5rbwi4P@jMDLtpvad0f_J1hlN6uX"
_TAB = str.maketrans(_STD, _POL)


def polhash(data):
    return base64.b64encode(hashlib.md5(data).digest()).decode().rstrip("=").translate(_TAB)


def has_kel(image):
    """True when the disc carries FILELIST.BIN and E419C51B/KEL.DAT."""
    return (discs.locate(image, FILELIST) is not None
            and discs.locate(image, KEL) is not None)


def decode_filelist(blob):
    """FILELIST.BIN -> [(id_sector, decompressed, stored, path)], declared count."""
    name_off, chunk_off, count = struct.unpack_from("<III", blob, 0)
    ntbl = (chunk_off - name_off) // 4
    trips = struct.unpack_from("<%dI" % ntbl, blob, name_off)
    text = b""
    for i in range(0, ntbl - 2, 3):
        _dsz, csz, off = trips[i], trips[i + 1], trips[i + 2]
        raw = blob[chunk_off + off:chunk_off + off + csz]
        out = None
        for wbits in (15, -15, 47):
            try:
                out = zlib.decompress(raw, wbits)
                break
            except zlib.error:
                continue
        if out is None:
            raise ValueError("FILELIST.BIN chunk %d does not inflate" % (i // 3))
        text += out
    rows = []
    for line in text.split(b"\0"):
        line = line.strip()
        if not line:
            continue
        parts = line.decode("latin-1").split(":")
        if len(parts) < 4:
            continue
        rows.append((int(parts[0], 16), int(parts[1], 16), int(parts[2], 16),
                     ":".join(parts[3:])))
    return rows, count


class Reader(object):
    """The manifest, the inventory and the container, opened once."""

    def __init__(self, image):
        self.image = image
        blob = discs.read_path(image, FILELIST)
        if blob is None:
            raise discs.NotADisc("no %s in the disc root" % FILELIST)
        self.rows, self.count = decode_filelist(blob)
        kel = discs.locate(image, KEL)
        if kel is None:
            raise discs.NotADisc("no %s on this disc" % KEL)
        self.kel_lba, self.kel_size = kel
        self.inventory = None

    def content(self, idsec, dec, stored):
        off = idsec * discs.USER_DATA
        first = self.kel_lba + off // discs.USER_DATA
        skip = off % discs.USER_DATA
        sectors = (skip + stored + discs.USER_DATA - 1) // discs.USER_DATA
        raw = self.image.read_sector(first, sectors)[skip:skip + stored]
        if stored == dec:
            return raw
        out = zlib.decompress(raw)
        if len(out) != dec:
            raise ValueError("row at sector %x inflates to %d, manifest says %d"
                             % (idsec, len(out), dec))
        return out

    def _load_inventory(self):
        inv = {}
        for idsec, dec, stored, path in self.rows:
            if path.strip() == "file.txt":
                for line in self.content(idsec, dec, stored).decode("latin-1").splitlines():
                    p = line.strip().split(":", 2)
                    if len(p) == 3 and p[1].isdigit():
                        inv.setdefault(p[0], []).append((int(p[1]), p[2]))
                break
        self.inventory = inv
        return inv

    def names_for(self, data):
        """Every path the inventory gives this content, by hash and size."""
        if self.inventory is None:
            self._load_inventory()
        return [q for sz, q in self.inventory.get(polhash(data), []) if sz == len(data)]

    def tree(self):
        """Yield (path, bytes) for every file the disc carries, resolving names.

        `config.sys` is synthesised at the end from the disc's `config.hdd`
        when the inventory names one, else from the 33 bytes Square Enix's
        installed partition holds (`TITLE=Kerberos`, `BOOT=/bin/kel.pex`).
        `filelist.bin` is the disc's FILELIST.BIN, which the title reads as
        its own index.
        """
        seen_config_hdd = None
        unresolved = 0
        for idsec, dec, stored, path in self.rows:
            data = self.content(idsec, dec, stored)
            p = path.strip()
            targets = [p] if p else self.names_for(data)
            if not targets:
                unresolved += 1
                continue
            for q in targets:
                if q == "config.hdd":
                    seen_config_hdd = data
                yield q, data
        self.unresolved = unresolved
        yield "filelist.bin", discs.read_path(self.image, FILELIST)
        if seen_config_hdd is not None:
            cfg = seen_config_hdd.replace(b"\r\n", b"\n")
        else:
            cfg = b"TITLE=Kerberos\nBOOT=/bin/kel.pex\n"
        yield "config.sys", cfg


def tree(image):
    r = Reader(image)
    for item in r.tree():
        yield item


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("disc")
    ap.add_argument("--list", action="store_true", help="the named rows only")
    ap.add_argument("--out", help="extract the whole tree here")
    args = ap.parse_args()
    d = discs.identify(args.disc)
    image = discs.Image(d.path)
    r = Reader(image)
    print("%d rows, %d named, manifest declares %d" % (
        len(r.rows), sum(1 for x in r.rows if x[3].strip()), r.count))
    if args.list:
        for idsec, dec, stored, path in r.rows:
            if path.strip():
                print("  %-40s %9d %s" % (path.strip(), dec, "raw" if dec == stored else "zlib"))
        return 0
    if args.out:
        from . import safepath
        n = total = 0
        for path, data in r.tree():
            safepath.write(args.out, path, data)
            n += 1
            total += len(data)
        print("wrote %d files, %.2f GiB, %d rows unresolved" % (n, total / 2 ** 30, r.unresolved))
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
"""Tell the Viewer which titles are installed: `pub/all/install.inf`.

The Viewer decides whether a title is installed from its own registry,
`/pub/all/install.inf` on the Viewer partition. A title with no record there
is reported as not installed, however complete its partition is. The disc's
default copy lists what the PlayOnline disc itself installs (Tetra Master,
and Janhourou on the Japanese discs); Square Enix's installers append a
record as each other title is installed, and this module does the same.

The format, as found on Square Enix's installed drives:

    0x000   u16 little-endian per content id: the record's offset / 8, or 0
    0x7d0   u32 0x00000100, constant
    0x810   records, appended in install order:
              8 bytes   the title's key (what its partition password is
                        generated from; zero for Janhourou)
              name      the partition name, NUL-terminated, padded with
                        NULs to a multiple of 8

The content ids and keys are Square Enix's (1 FFXI, 2 Tetra Master,
3 Janhourou, 4 FMO, 10 Dirge). The name is whatever partition the title is
actually in, which is how a US Viewer launches the Japan-only titles from
their Japanese partitions. Starting from the Japanese default and adding
FFXI, FMO and Dirge reproduces Square Enix's own file byte for byte.

    python3 -m playonline.installinf DRIVE            # what it would add
    python3 -m playonline.installinf DRIVE --write
"""
import argparse
import os
import struct
import sys

from . import apa, retitle, titles
from .lib import polfill, polhdd, polnetdump, polpfsread

PATH = ("pub", "all", "install.inf")
RECORDS_OFF = 0x810
INDEX_SLOTS = 64

#: title family -> Square Enix's content id.
CONTENT_ID = {"ffxi": 1, "tetramaster": 2, "janhourou": 3, "fmo": 4, "dirge": 10}


def content_id(title):
    return CONTENT_ID.get(title.key.rsplit("-", 1)[0])


def parse(blob):
    """{content id: (key int, partition name)} from an install.inf."""
    out = {}
    for cid in range(INDEX_SLOTS):
        unit, = struct.unpack_from("<H", blob, cid * 2)
        if not unit:
            continue
        off = unit * 8
        if off < RECORDS_OFF or off + 9 > len(blob):
            continue
        key, = struct.unpack_from("<Q", blob, off)
        name = blob[off + 8:].split(b"\0")[0].decode("latin-1")
        out[cid] = (key, name)
    return out


def add(blob, cid, key, name):
    """`blob` with a record for `cid` appended. Unchanged if it has one."""
    if struct.unpack_from("<H", blob, cid * 2)[0]:
        return blob
    # Records end where the file does, rounded up: Square Enix's own files
    # stop at the last name's 8-byte boundary.
    end = max(RECORDS_OFF, (len(blob) + 7) & ~7)
    raw = name.encode("latin-1") + b"\0"
    raw += b"\0" * (-len(raw) % 8)
    out = bytearray(blob.ljust(end, b"\0"))
    struct.pack_into("<H", out, cid * 2, end // 8)
    out += struct.pack("<Q", key) + raw
    return bytes(out)


def _viewer(image):
    for p in apa.installed_titles(image):
        if p.ident.endswith(".POLVIEWER"):
            return p
    return None


def register(image, write=False):
    """[lines] describing what was, or would be, registered."""
    viewer = _viewer(image)
    if viewer is None:
        return ["no PlayOnline Viewer partition on this drive"]
    known = {t.partition: t for t in titles.TITLES.values()}
    with open(image, "r+b" if write else "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        part, root = polpfsread.mount(f, viewer.lba, viewer.sectors,
                                      polnetdump.sub_partitions(f, size).get(viewer.lba))
        if part is None:
            return ["%s did not mount" % viewer.ident]
        found = retitle._find(part, root, PATH)
        if found is None:
            return ["%s has no /pub/all/install.inf" % viewer.ident]
        zone, sub, ino = found
        old = polfill.read_content(part, ino)
        have = parse(old)
        new, lines = old, []
        for p in apa.installed_titles(image):
            t = known.get(p.ident)
            cid = content_id(t) if t else None
            if cid is None:
                continue
            if cid in have:
                lines.append("%-32s id %2d  already registered%s" % (
                    p.ident, cid,
                    "" if have[cid][1] == p.ident
                    else " as %s, left alone" % have[cid][1]))
                continue
            key = polhdd.INSTALL_KEYS.get(cid, 0)
            new = add(new, cid, key, p.ident)
            lines.append("%-32s id %2d  %s" % (
                p.ident, cid, "registered" if write else "would be registered"))
        if new != old and write:
            retitle._replace(part, zone, sub, ino, new)
            again = polfill.read_inode(part, zone, sub)
            if polfill.read_content(part, again) != new or not again["ok"]:
                raise SystemExit("install.inf: readback after the write does not match")
            f.flush()
            os.fsync(f.fileno())
            lines.append("install.inf %d -> %d B, read back identical" % (len(old), len(new)))
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    for line in register(args.drive, args.write):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

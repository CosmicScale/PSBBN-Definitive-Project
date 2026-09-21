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
"""Read the `_/N/M.K` install archive straight out of a disc image.

`lib/polinstall` parses this container from a disc that has been extracted
to a directory. This module walks the archive inside the image instead and
hands the same bytes to the same parser (`scan_volume`, `payload_bytes`), so
the user never has to unpack an ISO.

`_/<d>/<maj>.<min>` are volumes: a bare concatenation of records with no
index. A file larger than 0x80000 bytes is split into chunks that may
continue into the next volume, so the walk follows the disc's own ordering
and regroups chunks by path afterwards. Directories are sorted by
(length, name) and volumes numerically, so that 2.10 comes after 2.9.

    python3 -m playonline.archive DISC --list
    python3 -m playonline.archive DISC --out DIR [--filter PREFIX]
"""
import argparse
import os
import sys

from . import discs
from .lib import polinstall

CHUNK = 0x80000


def _is_volume_name(name):
    """True for a volume file, in either of the two spellings seen.

    The Japanese PlayOnline disc names its volumes `<maj>.<min>` (0.0, 1.10)
    and the US one `<nnn>.DAT` (100.DAT, 229.DAT). They share directories
    with the IOP modules (.ERX, .EPX, .CNF), which are not volumes, so the
    name is the only thing that tells them apart.
    """
    stem, _, ext = name.partition(".")
    return stem.isdigit() and (ext.isdigit() or ext.upper() == "DAT")


def _vol_key(name):
    """Sort volumes numerically, so 2.10 does not come before 2.9.

    A file split across a volume boundary continues in the next volume, so
    a wrong order corrupts the largest files.
    """
    stem, _, ext = name.partition(".")
    return (int(stem) if stem.isdigit() else 99,
            int(ext) if ext.isdigit() else 0)


def volumes(image):
    """[(name, lba, size)] for each non-empty volume, in disc order."""
    root = {n.upper(): (l, s) for n, l, s, _d in discs.read_root(image)}
    if "_" not in root:
        raise discs.NotADisc("no `_` install archive in the disc root")
    lba, size = root["_"]
    sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
    subdirs = [(n, l, s) for n, l, s, is_dir
               in discs._dir_records(image.read_sector(lba, sectors))
               if is_dir and n not in (".", "..", "")]
    out = []
    for name, dlba, dsize in sorted(subdirs, key=lambda t: (len(t[0]), t[0])):
        dsectors = (dsize + discs.USER_DATA - 1) // discs.USER_DATA
        # Skip the IOP modules (TCP001.ERX and the like): they are not
        # record containers.
        files = [(n, l, s) for n, l, s, is_dir
                 in discs._dir_records(image.read_sector(dlba, dsectors))
                 if not is_dir and s and _is_volume_name(n)]
        for fn, flba, fsize in sorted(files, key=lambda t: _vol_key(t[0])):
            out.append(("%s/%s" % (name, fn), flba, fsize))
    return out


def records(image):
    """Yield (volume, chunk_idx, orig, stored, path, payload) in disc order."""
    for vol, lba, size in volumes(image):
        sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
        blob = image.read_sector(lba, sectors)[:size]
        for off, idx, orig, stored, path in polinstall.scan_volume(blob):
            yield (vol, idx, orig, stored, path,
                   blob[off + polinstall.HDR:off + polinstall.HDR + stored])


def tree(image, prefix=""):
    """Yield (path, bytes) for every complete file, chunks regrouped.

    A chunked file is emitted once its last chunk has been seen. The pieces
    are not adjacent and may be in different volumes, so this is a generator
    over the whole archive rather than a lookup.
    """
    pending = {}
    for vol, idx, orig, stored, path, payload in records(image):
        if prefix and not path.startswith(prefix):
            continue
        data = polinstall.payload_bytes(orig, stored, payload)
        if idx == 0:
            yield path, data
            continue
        parts = pending.setdefault(path, {})
        parts[idx] = data
        # The last chunk is the short one: any chunk below the full size ends
        # the file. Emit once every index from 1 to that one is present.
        short = [i for i, d in parts.items() if len(d) < CHUNK]
        if short:
            last = max(short)
            if all(i in parts for i in range(1, last + 1)):
                yield path, b"".join(parts[i] for i in range(1, last + 1))
                del pending[path]
    for path, parts in pending.items():
        yield path, b"".join(parts[i] for i in sorted(parts))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("disc")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--volumes", action="store_true")
    ap.add_argument("--out", metavar="DIR")
    ap.add_argument("--filter", default="", metavar="PREFIX")
    args = ap.parse_args()

    image = discs.Image(args.disc)
    if args.volumes:
        vols = volumes(image)
        for name, lba, size in vols:
            print("  %-10s lba=%-8d %d B" % (name, lba, size))
        print("%d volume(s)" % len(vols))
        return

    n = total = 0
    for path, data in tree(image, args.filter):
        n += 1
        total += len(data)
        if args.list:
            print("  %10d  %s" % (len(data), path))
        if args.out:
            dst = os.path.join(args.out, path.replace("/", os.sep))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(data)
    print("%d file(s), %.1f MiB" % (n, total / 1048576.0))


if __name__ == "__main__":
    main()

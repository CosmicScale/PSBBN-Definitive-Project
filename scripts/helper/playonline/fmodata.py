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
r"""Read Front Mission Online's install image off its disc.

The disc (SLPM-65981) carries the PlayOnline install container, but the game
itself is one root file, `/DVDIMAGE.DAT`. It is not a filesystem and has no
offset table:

    0x000000  the browser entry's boot block, as text
    0x000800  icon.sys
    0x001000  the icon (slot 2 of the installed attribute area; slot 3
              points at the same bytes)
    ...       a few small files (M0/, res/, version/, hddata/), each on a
              2048-byte boundary
    ...       the manifest: `<hash>:<size>:<path>` rows, NUL terminated,
              which the installer writes to the partition as `file.txt`
    ...       the A*/B* trees, stored raw in manifest order, each file
              padded to 2048 bytes

The browser slots, the manifest and every file match Square Enix's installed
partition. The manifest hash is base64(MD5) under PlayOnline's substituted
alphabet, the same one FFXI's and Dirge of Cerberus's manifests use.

Offsets cannot be computed from the sizes alone: the small files sit before
the manifest although their rows come last, and the image holds a run of
unlisted data between two listed files. The reader therefore walks in
manifest order and checks each file against its hash. Where a file is not at
the expected offset it searches forward on 2048-byte boundaries, then the
head of the image. A file that is found nowhere is an error.

The disc's `/MIDAS.PEX` is the title's boot module in the disc form. It is
staged as `midas.pex.enc` so the module step treats it like every other title
module. `config.sys` is the disc's `TITLE=` line plus `BOOT=/midas.pex`,
which is what the installed partition holds.

    python3 -m playonline.fmodata DISC --check
    python3 -m playonline.fmodata DISC --out DIR
"""
import argparse
import re
import struct
import sys

from . import discs
from .dirgedata import polhash

IMAGE = "DVDIMAGE.DAT"
MODULE = "MIDAS.PEX"
CONFIG = "CONFIG.SYS"

ALIGN = 0x800
ICON_SYS_OFF = 0x800
ICON_OFF = 0x1000
HEAD_SCAN = 8 * 1024 * 1024        # the manifest starts well inside this
RESYNC = 64 * 1024 * 1024          # how far ahead an unlisted run may push a file

_ROW = re.compile(rb"^[0-9A-Za-z_@]{22}:\d+:[\x20-\x7e]+\r?\n")


def icon_length(data):
    """How long the PS2 icon at the start of `data` is, from its own fields.

    Nothing in the image says where the icon ends, and what follows it
    is not padding, so the length comes out of the format: a 20-byte
    header, `vertices * (shapes * 8 + 16)` bytes of geometry, the
    animation header and its frames, then the texture, which is either
    128x128 16-bit pixels or, when bit 3 of the type is set, a length
    and that many RLE bytes. The result matches the size of slot 2 in
    Square Enix's installed attribute area.
    """
    magic, shapes, tex, _f, vertices = struct.unpack_from("<IIIfI", data, 0)
    if magic != 0x00010000:
        raise ValueError("no PS2 icon here (magic %08x)" % magic)
    off = 20 + vertices * (shapes * 8 + 16)
    anim_magic, _len, _speed, _play, frames = struct.unpack_from("<IIfII", data, off)
    if anim_magic != 1:
        raise ValueError("icon animation header not where the geometry ends")
    off += 20
    for _i in range(frames):
        _shape, keys = struct.unpack_from("<II", data, off)
        off += 8 + keys * 8
    if tex & 8:
        size, = struct.unpack_from("<I", data, off)
        off += 4 + size
    else:
        off += 128 * 128 * 2
    return off


def has_image(image):
    """True when the disc carries /DVDIMAGE.DAT and /MIDAS.PEX."""
    return (discs.locate(image, IMAGE) is not None
            and discs.locate(image, MODULE) is not None)


def _align(n):
    return (n + ALIGN - 1) & ~(ALIGN - 1)


class Reader(object):
    """DVDIMAGE.DAT, opened once: its head, its manifest, and where files are."""

    def __init__(self, image):
        self.image = image
        loc = discs.locate(image, IMAGE)
        if loc is None:
            raise discs.NotADisc("no %s in the disc root" % IMAGE)
        self.lba, self.size = loc
        self.manifest_off = self._find_manifest()
        text = self._cstring(self.manifest_off)
        self.manifest = text
        self.rows = []
        for line in text.decode("latin-1").splitlines():
            p = line.split(":", 2)
            if len(p) == 3 and p[1].isdigit():
                self.rows.append((p[0], int(p[1]), p[2]))
        if not self.rows:
            raise ValueError("%s: the manifest has no rows" % IMAGE)
        self.manifest_end = self.manifest_off + len(text)

    # ---- raw access ------------------------------------------------------
    def read(self, off, n):
        if off < 0 or off + n > self.size:
            raise ValueError("read of %d B at %#x runs outside %s" % (n, off, IMAGE))
        if not n:
            return b""
        first = self.lba + off // discs.USER_DATA
        skip = off % discs.USER_DATA
        sectors = (skip + n + discs.USER_DATA - 1) // discs.USER_DATA
        return self.image.read_sector(first, sectors)[skip:skip + n]

    def _cstring(self, off, chunk=1 << 20):
        out = b""
        while off < self.size:
            part = self.read(off, min(chunk, self.size - off))
            nul = part.find(b"\0")
            if nul >= 0:
                return out + part[:nul]
            out += part
            off += len(part)
        return out

    def _find_manifest(self):
        for off in range(ICON_OFF, min(HEAD_SCAN, self.size), ALIGN):
            if _ROW.match(self.read(off, 128)):
                return off
        raise ValueError("%s: no manifest found in its first %d MiB"
                         % (IMAGE, HEAD_SCAN >> 20))

    # ---- the browser entry ----------------------------------------------
    def browser_pieces(self):
        """(boot block, icon.sys, icon), as the installed area's slots hold them."""
        boot = self._cstring(0)
        icon_sys = self._cstring(ICON_SYS_OFF)
        span = self.read(ICON_OFF, self.manifest_off - ICON_OFF)
        icon = span[:icon_length(span)]
        return boot, icon_sys, icon

    # ---- locating files --------------------------------------------------
    def _matches(self, off, size, want):
        if off < 0 or off + size > self.size:
            return False
        return polhash(self.read(off, size)) == want

    def _head_offsets(self):
        """{path: offset} for the rows stored before the manifest."""
        if getattr(self, "_head", None) is None:
            self.locate_all()
        return self._head

    def locate_all(self):
        """[(path, offset or None for an empty file, size)] for every row.

        Raises ValueError naming the first file that is nowhere in the image.
        """
        if getattr(self, "_located", None) is not None:
            return self._located
        self._head = {}
        out = []
        # The run starts at the first boundary after the manifest where the
        # first non-empty row's bytes hash right.
        off = _align(self.manifest_end)
        pending_start = True
        for want, size, path in self.rows:
            if not size:
                out.append((path, None, 0))
                continue
            found = None
            if self._matches(off, size, want):
                found = off
            else:
                limit = min(self.size, off + RESYNC)
                cand = off + ALIGN
                while cand + size <= limit:
                    if self._matches(cand, size, want):
                        found = cand
                        break
                    cand += ALIGN
            if found is None and not pending_start:
                # Not ahead, so it is one of the few files stored before the
                # manifest, or between the manifest and the run.
                for lo, hi in ((ICON_OFF, self.manifest_off),
                               (_align(self.manifest_end), self._run_start)):
                    cand = lo
                    while cand + size <= hi:
                        if self._matches(cand, size, want):
                            found = cand
                            break
                        cand += ALIGN
                    if found is not None:
                        break
                if found is not None:
                    self._head[path] = found
                    out.append((path, found, size))
                    continue
            if found is None:
                raise ValueError("%s: %s (%d B) is nowhere in the image; its "
                                 "manifest hash matches no aligned offset"
                                 % (IMAGE, path, size))
            if pending_start:
                self._run_start = found
                pending_start = False
            out.append((path, found, size))
            off = _align(found + size)
        self._located = out
        return out

    # ---- the tree --------------------------------------------------------
    def tree(self):
        """Yield (path, bytes) for everything the installed partition holds."""
        for path, off, size in self.locate_all():
            yield path, (self.read(off, size) if size else b"")
        yield "file.txt", self.manifest
        cfg = discs.read_path(self.image, CONFIG) or b""
        title = b""
        for line in cfg.replace(b"\r\n", b"\n").split(b"\n"):
            if line.startswith(b"TITLE="):
                title = line + b"\n"
                break
        yield "config.sys", title + b"BOOT=/midas.pex\n"
        module = discs.read_path(self.image, MODULE)
        if module is None:
            raise discs.NotADisc("no %s in the disc root" % MODULE)
        yield "midas.pex.enc", module


def tree(image):
    for item in Reader(image).tree():
        yield item


def browser_pieces(image):
    return Reader(image).browser_pieces()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("disc")
    ap.add_argument("--check", action="store_true",
                    help="locate and hash every file, write nothing")
    ap.add_argument("--out", help="extract the whole tree here")
    args = ap.parse_args()
    d = discs.identify(args.disc)
    r = Reader(discs.Image(d.path))
    located = r.locate_all()
    total = sum(size for _p, _o, size in located)
    print("%s: manifest at %#x, %d rows, %.1f MiB, run starts at %#x, "
          "%d file(s) stored before the manifest"
          % (IMAGE, r.manifest_off, len(located), total / 1048576.0,
             r._run_start, len(r._head)))
    boot, icon_sys, icon = r.browser_pieces()
    print("browser entry: boot %d B, icon.sys %d B, icon %d B"
          % (len(boot), len(icon_sys), len(icon)))
    if args.out:
        from . import safepath
        n = 0
        for path, data in r.tree():
            safepath.write(args.out, path, data)
            n += 1
        print("wrote %d files into %s" % (n, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
"""Find the browser entries Square Enix already built, on the user's disc.

Every supported disc ships a complete `PS2ICON3D` area for each title, and
Square Enix's installer copies it to partition + 0x1000. The only field it
changes is VER: `VER = 0.00` on the Collection disc is `VER = 1.00` on an
installed drive.

Where the areas are depends on the container:

  install-dat   `POL/Data/PS2/viewer.pex`, `tetra.pex`, `jhr.pex`. Despite
                the `.pex` extension these are attribute areas. They are in
                the install container, so they appear in a staged tree.
  archive       Only in the disc's A..Z directories, which are outside the
                `_` install archive: `/J/2.6`, `/J/2.4` and `/A/0.6` on the
                JP disc, `/K/K18.DAT` and `/K/K16.DAT` on the US one.

They are therefore found by their magic and not by name, which works for
both containers and both regions and cannot mistake a module for an area.

    python3 -m playonline.prebuilt DISC_OR_STAGED_DIR
"""
import os

from . import attrarea, discs, installdat


def _iso_files(image):
    """(path, lba, size) for every file on the disc, recursively."""
    def walk(lba, size, path="/"):
        sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
        for name, l, s, is_dir in discs._dir_records(image.read_sector(lba, sectors)):
            if name in (".", ".."):
                continue
            if is_dir:
                for item in walk(l, s, path + name + "/"):
                    yield item
            else:
                yield path + name, l, s

    root = [(l, s) for n, l, s, d in discs.read_root(image) if n == "."]
    if not root:
        return
    for item in walk(root[0][0], root[0][1]):
        yield item


# An area is a few tens of KB. The bounds keep the scan away from large
# payloads without needing to know any names.
MIN_AREA = 0x200
MAX_AREA = 512 * 1024


def on_disc(disc):
    """[(where, area bytes)] for every prebuilt area on this disc."""
    image = discs.Image(disc.path)
    out = []
    if disc.format == discs.INSTALL_DAT:
        dat_lba, _size = installdat.dat_extent(image)
        for rec in installdat.index(image):
            if not (MIN_AREA <= rec.orig <= MAX_AREA):
                continue
            data = installdat.extract(image, rec, dat_lba)
            if attrarea.is_area(data):
                out.append((rec.path, data))
        # The ISO tree is scanned below as well: Vana'diel Collection 2008
        # keeps FFXI's entry outside the install container, as the root file
        # ICON.DAT (206,848 B, title0 FINAL FANTASY XI).
    # Front Mission Online keeps its entry as three loose pieces at the
    # head of DVDIMAGE.DAT. They are assembled the way FMO's installed area
    # is laid out: icon at 0x800, slot 3 pointing at slot 2.
    if getattr(disc, "fmo_image", False):
        from . import fmodata
        boot, icon_sys, icon = fmodata.browser_pieces(image)
        out.append((fmodata.IMAGE, attrarea.build_area(
            boot, icon_sys, icon, icon_off=0x800)))
    for path, lba, size in _iso_files(image):
        if not (MIN_AREA <= size <= MAX_AREA):
            continue
        if not attrarea.is_area(image.read_sector(lba)[:16]):
            continue
        sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
        out.append((path, image.read_sector(lba, sectors)[:size]))
    return out


def in_tree(src_dir):
    """[(where, area bytes)] for prebuilt areas already in a staged tree.

    Only an install-dat disc puts them there. Checking the tree first avoids
    re-reading the disc.
    """
    out = []
    for dirpath, _dirs, files in os.walk(src_dir):
        for name in files:
            path = os.path.join(dirpath, name)
            try:
                size = os.path.getsize(path)
            except OSError:
                continue
            if not (MIN_AREA <= size <= MAX_AREA):
                continue
            with open(path, "rb") as f:
                head = f.read(16)
            if not attrarea.is_area(head):
                continue
            with open(path, "rb") as f:
                out.append((os.path.relpath(path, src_dir).replace(os.sep, "/"),
                            f.read()))
    return out


def for_title(title, areas):
    """The area matching `title`, or None.

    Matched on the entry's `title0` line, trimmed, because Square Enix pads
    it with spaces on some discs. `title.aliases` carries the spellings one
    title has across regions: the JP Janhourou partition
    reads title0=雀鳳楼 and the JP Viewer reads PlayOnlineViewer where the US
    one reads PlayOnline.
    """
    for where, area in areas:
        got = attrarea.title0_of(area)
        if got and got.strip() in title.aliases:
            return where, area
    return None, None


def find(title, src_dir=None, disc=None):
    """The prebuilt area for `title`, preferring a staged tree over the disc."""
    if src_dir:
        where, area = for_title(title, in_tree(src_dir))
        if area:
            return where, area
    if disc:
        where, area = for_title(title, on_disc(disc))
        if area:
            return where, area
    return None, None


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -m playonline.prebuilt DISC_OR_STAGED_DIR")
    target = sys.argv[1]
    if os.path.isdir(target):
        found = in_tree(target)
    else:
        found = on_disc(discs.identify(target))
    for where, area in found:
        print("  %-36s %7d B  title0=%s"
              % (where, len(area), attrarea.title0_of(area)))
    print("%d prebuilt attribute area(s)" % len(found))

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
"""Put one title's files on disk, ready to be written into a partition.

Staging is the step between a disc and a drive. `discs.identify` reports
which install container a disc uses, and `stage` calls the matching reader
and extracts one title's tree into a staging directory. A title staged from
any disc that carries it produces the same tree layout. Nothing here touches
a drive.

Staging is a separate step, rather than streaming from disc to partition,
because a title can be assembled from more than one source, the plaintext and
transcrypt routes both rewrite files before they are written, and a staged
tree can be checked against the disc again without reading the drive.

    python3 -m playonline.stage DISC --title viewer-us --out DIR
    python3 -m playonline.stage DISC --list
"""
import argparse
import os
import sys

from . import archive, discs, ffxidata, installdat, safepath, titles


def sources(disc):
    """Every title this disc can stage."""
    return [t for t in disc.supplies() if t.stageable]


def container_for(disc, title):
    """Which container `title` comes out of on `disc`.

    A disc can hold more than one container: Vana'diel Collection 2008 has
    the PlayOnline install container and FFXI's own DATA/ beside it. The
    title names its container; None means the disc's install container.
    """
    want = title.container_on(disc.format)
    if want and want not in disc.containers:
        raise ValueError("%s needs the %s container and %s has none"
                         % (title.key, want, os.path.basename(disc.path)))
    return want


def _iter_tree(image, fmt, prefix):
    """Yield (path, bytes) for `prefix` out of whichever container it is."""
    if fmt == discs.FFXI_DATA:
        for path, data in ffxidata.tree(image):
            yield path, data
        # The partition's root files, which the DATA container does not
        # carry. An installed FFXI partition holds these four beside
        # image/ and res/: the disc's HDD.SYS becomes config.sys
        # (TITLE, BOOT, KEY), POLKEY.DAT is the key it names, and the two
        # DATA/ files are the manifest and the build.
        for src, dest in (("HDD.SYS", "config.sys"), ("POLKEY.DAT", "polkey.dat"),
                          ("DATA/PATCH.VER", "patch.ver"), ("DATA/FILE.TXT", "file.txt")):
            data = discs.read_path(image, src)
            if data is None:
                raise ValueError("this disc has no %s, which FFXI's partition "
                                 "root needs as %s" % (src, dest))
            yield dest, data
    elif fmt == discs.DIRGE_KEL:
        from . import dirgedata
        for path, data in dirgedata.tree(image):
            yield path, data
    elif fmt == discs.FMO_IMAGE:
        from . import fmodata
        for path, data in fmodata.tree(image):
            yield path, data
    elif fmt == discs.ARCHIVE:
        for path, data in archive.tree(image, prefix):
            yield path, data
    elif fmt == discs.INSTALL_DAT:
        records = installdat.index(image)
        ok, want, size = installdat.check_layout(image, records)
        if not ok:
            raise ValueError("INSTALL.DAT layout does not add up: records "
                             "account for %d B, the file is %d" % (want, size))
        dat_lba, _ = installdat.dat_extent(image)
        for rec in records:
            if prefix and not rec.path.startswith(prefix):
                continue
            yield rec.path, installdat.extract(image, rec, dat_lba)
    else:
        raise ValueError("this disc carries no install container this "
                         "installer can read")


def read_one(disc, path):
    """One named file out of the PlayOnline install container.

    This does not go through `container_for`: callers want an icon or a
    version file, and both live in the install container whatever else the
    disc carries.
    """
    image = discs.Image(disc.path)
    if disc.format == discs.ARCHIVE:
        for got, data in archive.tree(image, path):
            if got == path:
                return data
        return None
    if disc.format == discs.INSTALL_DAT:
        dat_lba, _ = installdat.dat_extent(image)
        for rec in installdat.index(image):
            if rec.path == path:
                return installdat.extract(image, rec, dat_lba)
        return None
    raise ValueError("no readable install container")


# Where a title records its build. The titles keep `patch.ver` at the root of
# their own tree; the Viewer keeps it under `install/PS2/` (it has no
# `POL/patch.ver`) and also carries a human-readable build in
# `Data/PS2/version.dat`.
VERSION_FILES = ("patch.ver", "install/PS2/patch.ver")
BUILD_FILE = "Data/PS2/version.dat"


def version_of(disc, title):
    """(patch.ver, version.dat) for this title on this disc. Either may be None.

    The same title ships at different builds on different discs:

        Viewer          1.11.00m on the US PlayOnline Viewer disc
                        1.14.03  on the Dirge of Cerberus disc
                        1.18.03b on Vana'diel Collection 2008
        Tetra Master    20031021_0 on the Viewer disc
                        20040908_0 on the Collection

    When more than one disc can supply a title, the choice is made on these
    values. Collection 2008 carries the newest build of everything it holds.
    """
    if not title.tree:
        return None, None
    ver = build = None
    for rel in VERSION_FILES:
        data = read_one(disc, title.tree + rel)
        if data:
            ver = data.decode("latin-1").strip()
            break
    data = read_one(disc, title.tree + BUILD_FILE)
    if data:
        build = data.decode("latin-1").strip()
    return ver, build


def stage(disc, title, out_dir, write=True):
    """Extract `title` from `disc` into `out_dir`. Returns (files, bytes).

    Paths keep the prefix the container gives them, so a staged Viewer tree
    starts at `POL/`. The partition's layout is decided later; keeping the
    disc's naming here lets a staged tree be compared with the disc directly.
    """
    if not title.stageable:
        raise ValueError("%s has no tree this project can read; its files "
                         "come from somewhere else" % title.key)
    image = discs.Image(disc.path)
    # Count distinct paths: a container can supply the same path twice.
    # FFXI's MISC containers are layered and the later copy is the one kept.
    seen = {}
    for path, data in _iter_tree(image, container_for(disc, title), title.tree):
        seen[path] = len(data)
        if write:
            safepath.write(out_dir, path, data)
    n = len(seen)
    total = sum(seen.values())
    if not n:
        raise ValueError("%s: nothing under %r on this disc"
                         % (title.key, title.tree))
    return n, total


def verify(disc, title, out_dir):
    """Re-read the disc and compare it with what is staged.

    This catches a half-written staging directory.
    """
    image = discs.Image(disc.path)
    same = differ = missing = 0
    for path, data in _iter_tree(image, container_for(disc, title), title.tree):
        dst = safepath.safe_join(out_dir, path)
        if not os.path.exists(dst):
            missing += 1
            continue
        with open(dst, "rb") as f:
            same += 1 if f.read() == data else 0
        if os.path.getsize(dst) != len(data):
            differ += 1
    return same, differ, missing


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("disc")
    ap.add_argument("--title", help="a title key; see `playonline titles`")
    ap.add_argument("--out", metavar="DIR")
    ap.add_argument("--list", action="store_true",
                    help="what this disc can stage, and nothing else")
    ap.add_argument("--verify", action="store_true",
                    help="compare an existing staging directory with the disc")
    args = ap.parse_args()

    try:
        d = discs.identify(args.disc)
    except discs.NotADisc as e:
        sys.exit(str(e))

    name = titles.DISCS[d.key]["name"] if d.known else "unrecognised"
    print("%s  %s  (%s)" % (d.code, name, d.format or "no install container"))

    stageable = sources(d)
    if args.list or not args.title:
        for t in stageable:
            try:
                ver, build = version_of(d, t)
            except (ValueError, IOError) as e:
                ver, build = "unreadable", str(e)[:20]
            print("  %-16s %-14s %-11s %-9s -> %s  [%s]"
                  % (t.key, t.tree, ver or "-", build or "-",
                     t.partition, t.status))
        if not stageable:
            print("  nothing this installer can stage from this disc")
        if not args.title:
            return

    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    title = titles.TITLES[args.title]
    if title not in stageable:
        sys.exit("%s does not come from this disc (%s supplies: %s)"
                 % (title.key, d.code,
                    ", ".join(t.key for t in stageable) or "nothing"))
    if not args.out:
        sys.exit("--title needs --out DIR")

    if args.verify:
        same, differ, missing = verify(d, title, args.out)
        print("%d identical, %d differ, %d missing" % (same, differ, missing))
        sys.exit(1 if (differ or missing) else 0)

    n, total = stage(d, title, args.out)
    print("staged %d file(s), %.1f MiB into %s" % (n, total / 1048576.0, args.out))


if __name__ == "__main__":
    main()

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
"""Identify a disc the user supplied, and say what it can install.

The disc is identified from its contents; the file name is ignored. Every PS2
disc carries `SYSTEM.CNF` in its root, and its `BOOT2` line names the boot
executable, whose name is the product code:

    BOOT2 = cdrom0:\\SLPS_202.00;1      ->  SLPS-20200

That code is matched against `titles.DISCS`. A disc that is not in the table
is reported as unrecognised, because the partition names it would need are
Square Enix's choices and cannot be derived.

`.iso`/`.img` hold 2048-byte sectors and are read directly. A `.bin` from a
bin/cue rip holds 2352-byte raw sectors, with the 2048 bytes of user data at
an offset that depends on the track mode, so the mode is read from the sector
header. `.zip` and `.7z` are refused, and a `.chd` until chd.py has extracted it, with a message that says how to
convert them.

    python3 -m playonline.discs IMAGE_OR_FOLDER ...
"""
import argparse
import os
import struct
import sys

from . import titles

SYNC = b"\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00"
PVD_SECTOR = 16
USER_DATA = 2048


class NotADisc(ValueError):
    pass


class Image(object):
    """A disc image, addressed by logical sector whatever its sector size."""

    def __init__(self, path):
        self.path = path
        ext = os.path.splitext(path)[1].lower()
        if ext == ".chd":
            raise NotADisc("%s is a CHD. Extract it first: python3 -m "
                           "playonline.chd FOLDER (the menu step does this)" % path)
        if ext in (".zip", ".7z"):
            raise NotADisc("%s is an archive. Extract the disc image from it "
                           "first." % path)
        size = os.path.getsize(path)
        if size < (PVD_SECTOR + 1) * 2352:
            raise NotADisc("%s is too small to be a disc image" % path)
        with open(path, "rb") as f:
            head = f.read(16)
        if head.startswith(SYNC):
            # Raw 2352. Byte 15 is the mode: 1 puts user data at +16,
            # 2 (form 1) adds an 8-byte subheader, so +24.
            self.sector_size = 2352
            self.offset = 16 if head[15] == 1 else 24
        else:
            self.sector_size = USER_DATA
            self.offset = 0

    def read_sector(self, lba, count=1):
        with open(self.path, "rb") as f:
            out = []
            for i in range(count):
                f.seek((lba + i) * self.sector_size + self.offset)
                out.append(f.read(USER_DATA))
            return b"".join(out)


def _dir_records(block):
    """Walk one directory extent, yielding (name, lba, length, is_dir).

    The directory flag is bit 1 of the file flags at offset 25. Callers must
    honour it: the `_` install archive mixes files and directories, and a
    file's extent parsed as directory records yields garbage names and LBAs.
    """
    i = 0
    while i < len(block):
        ln = block[i]
        if ln == 0:
            # Records do not straddle a sector; skip to the next one.
            i = (i // USER_DATA + 1) * USER_DATA
            if i >= len(block):
                return
            continue
        rec = block[i:i + ln]
        if len(rec) < 33:
            return
        lba = struct.unpack_from("<I", rec, 2)[0]
        size = struct.unpack_from("<I", rec, 10)[0]
        name_len = rec[32]
        raw = rec[33:33 + name_len]
        # ISO9660 names the self and parent entries with a single 0x00 or
        # 0x01 byte. Naming them "." and ".." lets a walker skip them instead
        # of descending into the same extent forever.
        if raw == b"\x00":
            name = "."
        elif raw == b"\x01":
            name = ".."
        else:
            name = raw.decode("latin-1").split(";")[0]
        is_dir = bool(rec[25] & 0x02)
        yield name, lba, size, is_dir
        i += ln


def read_root(image):
    """[(name, lba, size, is_dir)] for the root directory of an ISO9660 image."""
    pvd = image.read_sector(PVD_SECTOR)
    if pvd[1:6] != b"CD001":
        raise NotADisc("%s has no ISO9660 volume descriptor" % image.path)
    root = pvd[156:190]
    lba = struct.unpack_from("<I", root, 2)[0]
    size = struct.unpack_from("<I", root, 10)[0]
    sectors = (size + USER_DATA - 1) // USER_DATA
    return list(_dir_records(image.read_sector(lba, sectors)))


def locate(image, path):
    """(lba, size) of one file in the ISO9660 tree, by `/`-separated path, or None.

    Case-insensitive, like the disc's own names. Separate from `read_path`
    for the containers that are too big to read whole (Dirge of Cerberus's
    KEL.DAT is over 1 GB) and are read by sector instead.
    """
    parts = [p for p in path.replace("\\", "/").split("/") if p]
    pvd = image.read_sector(PVD_SECTOR)
    if pvd[1:6] != b"CD001":
        raise NotADisc("%s has no ISO9660 volume descriptor" % image.path)
    lba = struct.unpack_from("<I", pvd, 158)[0]
    size = struct.unpack_from("<I", pvd, 166)[0]
    for i, want in enumerate(parts):
        sectors = (size + USER_DATA - 1) // USER_DATA
        for name, l, s, is_dir in _dir_records(image.read_sector(lba, sectors)):
            if name.upper() != want.upper():
                continue
            if i == len(parts) - 1:
                return None if is_dir else (l, s)
            if not is_dir:
                return None
            lba, size = l, s
            break
        else:
            return None
    return None


def read_path(image, path):
    """The bytes of one file in the ISO9660 tree, or None. See `locate`.

    Used for the few files a title needs that live outside every install
    container, such as FFXI's HDD.SYS, POLKEY.DAT and CONFIGU.SYS, and
    Dirge's FILELIST.BIN.
    """
    hit = locate(image, path)
    if hit is None:
        return None
    lba, size = hit
    n = (size + USER_DATA - 1) // USER_DATA
    return image.read_sector(lba, n)[:size]


def product_code(image):
    """The disc's product code, from SYSTEM.CNF's BOOT2 line.

    `SLPS_202.00` becomes `SLPS-20200`: the underscore becomes a dash and the
    dot goes, which is the spelling the partition names use.
    """
    for name, lba, size, _is_dir in read_root(image):
        if name.upper() != "SYSTEM.CNF":
            continue
        sectors = (size + USER_DATA - 1) // USER_DATA
        text = image.read_sector(lba, sectors)[:size].decode("latin-1")
        for line in text.replace("\r", "\n").split("\n"):
            if not line.upper().startswith("BOOT2"):
                continue
            boot = line.split("=", 1)[1].strip()
            boot = boot.split("\\")[-1].split("/")[-1].split(";")[0]
            return boot.replace("_", "-").replace(".", "").upper(), boot
    raise NotADisc("%s has no SYSTEM.CNF in its root" % image.path)


# The two install containers found on PlayOnline discs. They are unrelated
# formats with separate readers.
#
#   install-archive   the `_/N/M.K` namespace beside A..Z, read by
#                     lib/polinstall.py. On the JP PlayOnline disc and the US
#                     PlayOnline Viewer disc.
#   install-dat       POL/INSTALL.DAT indexed by POL/INSTALL.INF, read by
#                     installdat.py. On Vana'diel Collection 2008 and on the
#                     Dirge of Cerberus disc, which is also a PlayOnline
#                     install disc.
# The container names are defined in titles.py, because the container a title
# comes out of is a property of the title. They are re-exported here for
# callers that hold a Disc.
ARCHIVE = titles.ARCHIVE
INSTALL_DAT = titles.INSTALL_DAT
FFXI_DATA = titles.FFXI_DATA
DIRGE_KEL = titles.DIRGE_KEL
FMO_IMAGE = titles.FMO_IMAGE


def install_format(image):
    """Which form of the PlayOnline install container this disc has, or None.

    This is the container the Viewer, Tetra Master and Janhourou come out of.
    A disc can carry another container beside it (Vana'diel Collection 2008
    has both INSTALL_DAT and FFXI's DATA/); `Disc.containers` lists them all.
    """
    root = {n.upper(): (l, s) for n, l, s, _d in read_root(image)}
    if "_" in root:
        return ARCHIVE
    if "POL" in root:
        lba, size = root["POL"]
        sectors = (size + USER_DATA - 1) // USER_DATA
        names = {n.upper() for n, _l, _s, _d in _dir_records(image.read_sector(lba, sectors))}
        if "INSTALL.DAT" in names:
            return INSTALL_DAT
    return None


def has_ffxi_data(image):
    """True when the disc carries FFXI's own DATA/ container.

    Identified by FILE.TXT and STABLE.DAT inside it, because `DATA` alone is
    too common a directory name.
    """
    root = {n.upper(): (l, s) for n, l, s, _d in read_root(image)}
    if "DATA" not in root:
        return False
    lba, size = root["DATA"]
    sectors = (size + USER_DATA - 1) // USER_DATA
    names = {n.upper() for n, _l, _s, _d in _dir_records(image.read_sector(lba, sectors))}
    return "FILE.TXT" in names and "STABLE.DAT" in names


def has_dirge_kel(image):
    """True when the disc carries Dirge's KEL container and its index."""
    return (locate(image, "FILELIST.BIN") is not None
            and locate(image, "E419C51B/KEL.DAT") is not None)


def has_fmo_image(image):
    """True when the disc carries Front Mission Online's install image."""
    return (locate(image, "DVDIMAGE.DAT") is not None
            and locate(image, "MIDAS.PEX") is not None)


class Disc(object):
    def __init__(self, path, code, boot, key=None, fmt=None, ffxi=False,
                 dirge=False, fmo=False):
        self.path = path
        self.code = code            # SLPS-20200
        self.boot = boot            # SLPS_202.00, as it appears on the disc
        self.key = key              # a key in titles.DISCS, or None
        self.format = fmt           # ARCHIVE, INSTALL_DAT or None
        self.ffxi_data = ffxi       # FFXI's own DATA/ is here as well
        self.dirge_kel = dirge      # Dirge's KEL.DAT and FILELIST.BIN are here
        self.fmo_image = fmo        # FMO's DVDIMAGE.DAT and MIDAS.PEX are here

    @property
    def containers(self):
        """Every container this disc carries that something here can read."""
        out = [self.format] if self.format else []
        if self.ffxi_data:
            out.append(FFXI_DATA)
        if self.dirge_kel:
            out.append(DIRGE_KEL)
        if self.fmo_image:
            out.append(FMO_IMAGE)
        return out

    @property
    def readable(self):
        """True when the disc has a PlayOnline install container."""
        return self.format in (ARCHIVE, INSTALL_DAT)

    @property
    def known(self):
        return self.key is not None

    def supplies(self):
        return titles.for_disc(self.key) if self.known else []

    def __repr__(self):
        return "<Disc %s %s>" % (self.code, self.key or "unrecognised")


def identify(path):
    """Identify one disc image. Raises NotADisc if it cannot be read."""
    image = Image(path)
    code, boot = product_code(image)
    key = None
    for k, d in titles.DISCS.items():
        if d["product"] == code:
            key = k
            break
    return Disc(path, code, boot, key, install_format(image),
                has_ffxi_data(image), has_dirge_kel(image),
                has_fmo_image(image))


IMAGE_EXTS = (".iso", ".img", ".bin", ".chd", ".zip", ".7z")


def images_in(folder):
    """The disc image files in `folder`, sorted.

    A CHD that has been extracted (see chd.py) has a `.iso` or `.bin` of the
    same name beside it, and is passed over in favour of that image.
    """
    names = sorted(os.listdir(folder))
    have = {n.lower() for n in names}
    out = []
    for name in names:
        stem, ext = os.path.splitext(name)
        if ext.lower() not in IMAGE_EXTS:
            continue
        if ext.lower() == ".chd" and (stem.lower() + ".iso" in have
                                      or stem.lower() + ".bin" in have):
            continue
        out.append(os.path.join(folder, name))
    return out


def scan(paths):
    """Identify each path, collecting failures instead of raising."""
    found, failed = [], []
    for p in paths:
        try:
            found.append(identify(p))
        except (NotADisc, IOError, OSError) as e:
            failed.append((p, str(e)))
    return found, failed


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("images", nargs="+", help="disc images, or a folder of them")
    args = ap.parse_args()

    paths = []
    for p in args.images:
        if os.path.isdir(p):
            paths += images_in(p)
        else:
            paths.append(p)

    found, failed = scan(paths)
    for d in found:
        name = titles.DISCS[d.key]["name"] if d.known else "not a disc this installer knows"
        print("%-12s %-13s %s" % (d.code, d.boot, name))
        print("%-12s %-13s %s" % ("", os.path.basename(d.path)[:13],
                                  ", ".join("%s (%s)" % (t.key, t.status)
                                            for t in d.supplies()) or "-"))
        print("%-12s %-13s format: %s%s"
              % ("", "", d.format or "no install container found",
                 "" if d.readable else "  [not readable by this installer yet]"))
    for p, why in failed:
        print("%-12s %s" % ("skipped", why))
    print()
    print("%d disc(s) identified, %d unreadable" % (len(found), len(failed)))
    known = [d for d in found if d.known]
    covered = set()
    for d in known:
        covered.update(t.key for t in d.supplies())
    missing = [k for k in titles.TITLES if k not in covered]
    if missing:
        print("no disc supplies: %s" % ", ".join(sorted(missing)))


if __name__ == "__main__":
    main()

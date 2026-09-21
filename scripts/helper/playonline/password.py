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
"""Give a title's partition the password its own module will mount with.

A PlayOnline title mounts its own partition with a password:

    sprintf(buf, "%s,%s", "hdd0:PP.SCUS-97269.0002.TETRAMASTER", password)
    mount("pfs1:", buf, 0, 0, 0)

The APA header must hold the matching 8 bytes or the console's driver
refuses the mount. A partition made by `pfsshell mkpart` has zeros there.

The header carries two fields, `rpwd` (0x030) and `fpwd` (0x038). The mount
checks `fpwd`, which is `apa_password(partition id, password)`: one DES
block, so only the first 8 bytes of the id are hashed. `rpwd` holds a
different value on Square Enix's POLVIEWER and FMO headers, derived from a
secret that is not known, but it is not needed: the Viewer does not check
`rpwd`, and Square Enix ships JANHOUROU with zero there too. A browser entry does not exercise any of this, because the
browser reads the attribute area; the password is only tested when the
title mounts.

Title passwords are generated from the 64-bit key Square Enix ships per
content id in `install.inf` (see `polhdd.build_pw`). The Viewer's own
password, `zbaa.nbu`, is not in that table and is confirmed against Square
Enix's US and Japanese headers. Not every title generates one: Dirge's
module tries up to four candidates from a table. A title whose password is
unknown keeps whatever its header already has.

    python3 -m playonline.password DRIVE --title viewer-us
    python3 -m playonline.password DRIVE --title viewer-us --write
"""
import argparse
import os
import struct
import sys

from . import apa, titles
from .lib.polhdd import SECTOR, apa_password, checksum

RPWD_OFF = 0x030
FPWD_OFF = 0x038


def for_title(title):
    """The password `title`'s module mounts with, or None if it has none."""
    return titles.password_of(title)


def plan(image, title):
    """(lba, header bytes, current rpwd, current fpwd, wanted fpwd)."""
    try:
        lba, _sectors = apa.find_partition(image, title.partition)
    except KeyError:
        raise SystemExit("%s: %s is not on this drive"
                         % (image, title.partition))
    with open(image, "rb") as f:
        f.seek(lba * SECTOR)
        raw = bytearray(f.read(1024))
    cur_r = bytes(raw[RPWD_OFF:RPWD_OFF + 8])
    cur_f = bytes(raw[FPWD_OFF:FPWD_OFF + 8])
    pw = for_title(title)
    want_f = apa_password(title.partition, pw.encode("latin-1")) if pw else bytes(8)
    return lba, raw, cur_r, cur_f, want_f


def apply(image, title, write=False):
    lba, raw, cur_r, cur_f, want_f = plan(image, title)
    pw = for_title(title)
    print("%s at LBA %d" % (title.partition, lba))
    if not pw:
        print("  no password is known for this title; leaving the fields as "
              "they are (rpwd=%s fpwd=%s)" % (cur_r.hex(), cur_f.hex()))
        return True
    print("  password %r -> fpwd %s" % (pw, want_f.hex()))
    print("  current  rpwd=%s fpwd=%s" % (cur_r.hex(), cur_f.hex()))
    if cur_f == want_f:
        print("  fpwd is already correct")
        return True
    if not write:
        print("  (plan only; pass --write to set it)")
        return True

    # rpwd is left as it is: a drive that carries Square Enix's own value
    # keeps it, and a new partition already has zeros there.
    raw[FPWD_OFF:FPWD_OFF + 8] = want_f
    struct.pack_into("<I", raw, 0x000, 0)
    struct.pack_into("<I", raw, 0x000, checksum(bytes(raw)))
    with open(image, "r+b") as f:
        f.seek(lba * SECTOR)
        f.write(bytes(raw))
        f.flush()
        os.fsync(f.fileno())
    print("  wrote fpwd and recomputed the header checksum")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--title", required=True)
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    apply(args.drive, titles.TITLES[args.title], write=args.write)
    return 0


if __name__ == "__main__":
    sys.exit(main())

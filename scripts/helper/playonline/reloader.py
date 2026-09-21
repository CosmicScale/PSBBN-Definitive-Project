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
"""Bring the loader on an installed Viewer partition up to date, in place.

The Viewer boots through `dnasload.elf`, which is this package's loader with
the Viewer's gated boot executable inside it. A later version of the package
can change either the loader or a gate table. The installer leaves an
existing partition alone, so without this module such a fix would reach only
drives installed afterwards.

Only that one file is replaced. The new loader is written over the file's
existing extent: no allocation and no directory change, only the file's
bytes and its inode's size and checksum. Nothing is written if the file
already matches.

    python3 -m playonline.reloader DRIVE --partition PP.SCUS-97269.1000.POLVIEWER \
        --loader STAGED/POL/install/PS2/dnasload.elf [--write]
"""
import argparse
import hashlib
import os
import sys

from .lib import polfill, polnetdump, polpfspatch, polpfsread

PATH = "/dnasload.elf"


def refresh(drive, partition, loader_path, write=False):
    """(changed, text). Raises SystemExit with a reason when it cannot."""
    with open(loader_path, "rb") as f:
        data = f.read()
    with open(drive, "r+b" if write else "rb") as f:
        # os.path.getsize returns 0 for a block device, so seek to the end.
        f.seek(0, os.SEEK_END)
        size = f.tell()
        hit = [p for p in polnetdump.partitions(f, size) if p[3] == partition]
        if not hit:
            raise SystemExit("%s: no partition named %s" % (drive, partition))
        lba, length = hit[0][0], hit[0][1]
        part, root = polpfsread.mount(f, lba, length)
        if part is None:
            raise SystemExit("%s did not mount" % partition)
        zone, ino = polpfspatch.find(part, root, PATH)
        before = polfill.read_content(part, ino)
        if before == data:
            return False, "%s%s is already current (sha256 %s)" % (
                partition, PATH, hashlib.sha256(data).hexdigest()[:16])
        # A rebuilt loader can differ in size by a few hundred bytes. It
        # still goes in place as long as it fits the zones the file already
        # has; the size in the inode is updated with it.
        room = sum(cnt for _n, cnt in ino["runs"]) * part.zone_size
        if len(data) > room:
            raise SystemExit(
                "%s%s has %d B allocated and the new loader is %d B; it does "
                "not fit in place. Reinstall the Viewer partition."
                % (partition, PATH, room, len(data)))
        text = "%s%s: sha256 %s -> %s" % (
            partition, PATH, hashlib.sha256(before).hexdigest()[:16],
            hashlib.sha256(data).hexdigest()[:16])
        if not write:
            return True, text + "  (plan only)"
        polpfspatch.patch(part, zone, ino, data, True)
        f.flush()
        os.fsync(f.fileno())
        ino2 = polfill.read_inode(part, zone)
        after = polfill.read_content(part, ino2)
        if after != data or not ino2["ok"]:
            raise SystemExit("%s%s: readback after the write does not match"
                             % (partition, PATH))
        return True, text + "  (written, read back identical)"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--partition", required=True)
    ap.add_argument("--loader", required=True,
                    help="the filled dnasload.elf from `route prepare`")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    _changed, text = refresh(args.drive, args.partition, args.loader, args.write)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())

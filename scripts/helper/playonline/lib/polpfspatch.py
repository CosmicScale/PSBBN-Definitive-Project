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
"""Replace one file's contents inside an existing PFS partition, in place.

Overwrites a file that is already on the drive, reusing the zones it
occupies, so the replacement must fit in the zones already allocated. No
zones are allocated and no directory entry is touched, which keeps the change
safe on a filesystem this package did not create: only the bytes inside the
file's zones and the inode's size and checksum change. The inode keeps its
full run list when the new file is shorter; the driver reads `size` bytes
along the runs and the trailing zones go unused.

Only the main partition is addressed, so a file whose inode or data sits in a
sub-partition is not supported. No backup is taken: copy the image first.
Without --write nothing is written.

    python3 -m playonline.lib.polpfspatch IMAGE __system /osd100/hosdsys.elf new.elf
    python3 -m playonline.lib.polpfspatch IMAGE __system /osd100/hosdsys.elf new.elf --write

Afterwards, check that every partition still mounts:

    python3 -m playonline.lib.polpfsread IMAGE
"""
import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from . import polfill                                                  # noqa: E402
from .polnetdump import partitions                               # noqa: E402
from .polpfsread import mount, walk                              # noqa: E402

SECTOR = 512
META = 1024


def find(part, root_ino, path):
    """Walk `path` (e.g. /osd100/hosdsys.elf) and return its inode zone."""
    parts = [p for p in path.strip("/").split("/") if p]
    ino, zone = root_ino, None
    for i, want in enumerate(parts):
        hit = None
        for name, inode, flags in polfill.read_dir(part, ino):
            if name.decode("ascii", "replace") == want:
                hit = (inode, flags)
                break
        if hit is None:
            raise SystemExit("not found: %s (at %r)" % (path, want))
        zone = hit[0]
        ino = polfill.read_inode(part, zone)
        if i < len(parts) - 1 and not (ino["mode"] & 0x1000):
            raise SystemExit("%s is not a directory" % want)
    return zone, ino


def patch(part, zone, ino, data, write):
    cap = sum(cnt for _, cnt in ino["runs"]) * part.zone_size
    print("  file size %d -> %d, allocated %d bytes in %d run(s)"
          % (ino["size"], len(data), cap, len(ino["runs"])))
    if len(data) > cap:
        raise SystemExit("replacement is larger than the allocated zones")
    if not write:
        print("  (dry run -- pass --write to commit)")
        return

    # 1. The content, following the existing run list.
    off = 0
    for number, count in ino["runs"]:
        if off >= len(data):
            break
        n = min(count * part.zone_size, len(data) - off)
        part.f.seek((part.lba + (number << part.scale)) * SECTOR)
        part.f.write(data[off:off + n])
        off += n

    # 2. The inode's size field, then its checksum (sum of u32 words 1..255).
    pos = (part.lba + (zone << part.scale)) * SECTOR
    part.f.seek(pos)
    b = bytearray(part.f.read(META))
    field = 0x028 + polfill.PFS_INODE_MAX_BLOCKS * 8 + 32
    struct.pack_into("<Q", b, field, len(data))
    struct.pack_into("<I", b, 0, polfill.inode_checksum(b))
    part.f.seek(pos)
    part.f.write(bytes(b))
    part.f.flush()
    print("  written, inode size and checksum updated")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image")
    ap.add_argument("partition")
    ap.add_argument("path")
    ap.add_argument("source")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    data = open(a.source, "rb").read()
    mode = "r+b" if a.write else "rb"
    with open(a.image, mode) as f:
        size = os.path.getsize(a.image)
        hit = [p for p in partitions(f, size) if p[3] == a.partition]
        if not hit:
            raise SystemExit("no partition named %s" % a.partition)
        lba, length = hit[0][0], hit[0][1]
        part, root = mount(f, lba, length)
        if part is None:
            raise SystemExit("%s did not mount" % a.partition)
        zone, ino = find(part, root, a.path)
        print("%s%s  inode zone %d" % (a.partition, a.path, zone))
        before = polfill.read_content(part, ino)
        import hashlib
        print("  current sha256 %s" % hashlib.sha256(before).hexdigest()[:16])
        print("  new     sha256 %s" % hashlib.sha256(data).hexdigest()[:16])
        patch(part, zone, ino, data, a.write)
        if a.write:
            ino2 = polfill.read_inode(part, zone)
            after = polfill.read_content(part, ino2)
            ok = after == data and ino2["ok"]
            print("  readback: %d bytes, inode checksum %s, content %s"
                  % (len(after), "OK" if ino2["ok"] else "BAD",
                     "MATCHES" if after == data else "MISMATCH"))
            return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
r"""Take Square Enix's public keys from the user's own disc.

Every container this installer handles is signed with Square Enix's RSA
public keys, and those keys are embedded in the disc's boot executable
(`SLPS_202.00`, `SCUS_972.69`, `SLUS_217.04` and so on). They are read from
the user's disc at run time, so none of them ship with this package.

The table's address differs between builds, so it is found by searching.
Each slot is self-describing:

    +0x00   8   DES key, in the clear
    +0x08   8   DES IV, in the clear
    +0x10 184   ciphertext: u32 length at +4, then DER SubjectPublicKeyInfo

A run of consecutive slots that all decrypt to a plausible DER length
identifies the table. On the JP disc the search finds the file offset that
`polenc.KEYSTORE_VA` (0x001F54F0) maps to. The keystores on the JP PlayOnline
disc, the US PlayOnline Viewer disc and Vana'diel Collection 2008 are
identical (the same 100 populated slots), so any of those discs supplies the
same keys.

    python3 -m playonline.keys DISC_OR_ELF
"""
import os
import struct
import sys
import tempfile

from .lib import polenc

try:
    from Crypto.Cipher import DES
except ImportError:                                  # pragma: no cover
    DES = None

STRIDE = polenc.SLOT_STRIDE
COUNT = polenc.SLOT_COUNT
MIN_RUN = 6                     # consecutive good slots that identify the table


class NoKeystore(Exception):
    pass


def _slot_ok(buf, off):
    if off + STRIDE > len(buf):
        return False
    e = buf[off:off + STRIDE]
    try:
        pt = DES.new(e[0:8], DES.MODE_CBC, e[8:16]).decrypt(e[16:STRIDE])
    except Exception:                                # noqa: BLE001
        return False
    length, = struct.unpack(">I", pt[4:8])
    # A populated slot holds a DER SEQUENCE in long form. Empty slots exist
    # too; the table is identified by a run of valid ones.
    return 0 < length < 177 and pt[8:10] == b"\x30\x81"


def find_keystore(elf_path):
    """File offset of the keystore table in this boot executable."""
    if DES is None:
        raise NoKeystore("pycryptodome is required to read the keystore")
    with open(elf_path, "rb") as f:
        buf = f.read()
    limit = len(buf) - STRIDE * MIN_RUN
    off = 0
    while off < limit:
        if _slot_ok(buf, off) and _slot_ok(buf, off + STRIDE):
            if all(_slot_ok(buf, off + i * STRIDE) for i in range(MIN_RUN)):
                return off
            off += STRIDE
            continue
        off += 4
    raise NoKeystore("%s: no keystore table found" % elf_path)


def boot_elf(disc):
    """Extract a disc's boot executable to a temp file and return the path.

    A real file is needed because the crypto modules open it by path.
    """
    from . import discs
    image = discs.Image(disc.path) if hasattr(disc, "path") else discs.Image(disc)
    code, boot = discs.product_code(image)
    for name, lba, size, is_dir in discs.read_root(image):
        if is_dir or name.upper() != boot.upper():
            continue
        data = image.read_sector(lba, (size + discs.USER_DATA - 1) // discs.USER_DATA)[:size]
        fd, path = tempfile.mkstemp(prefix="playonline-boot-", suffix="-" + boot)
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        return path
    raise NoKeystore("%s: no boot executable %s in the disc root"
                     % (getattr(disc, "path", disc), boot))


def use_disc(elf_path):
    """Point the crypto modules in `lib` at this executable's keystore.

    Replaces `polenc.keystore` with a reader bound to this executable's table
    offset, and sets `polenc.ELF` and `polenc.KEYSTORE_VA` to match.

    Returns (path, file offset, virtual address) for reporting.
    """
    off = find_keystore(elf_path)
    # polenc's ELF reader maps the file offset back to a virtual address.
    va = polenc.Image(elf_path).va(off)

    def keystore(elf=None, _path=elf_path, _off=off):
        """polenc.keystore, reading the table found in this executable."""
        with open(_path, "rb") as f:
            buf = f.read()
        for slot in range(COUNT):
            e = buf[_off + slot * STRIDE:_off + (slot + 1) * STRIDE]
            if len(e) < STRIDE:
                return
            pt = DES.new(e[0:8], DES.MODE_CBC, e[8:16]).decrypt(e[16:STRIDE])
            length, = struct.unpack(">I", pt[4:8])
            yield slot, (pt[8:8 + length] if 0 < length < 177 else None)

    polenc.ELF = elf_path
    if va is not None:
        polenc.KEYSTORE_VA = va
    polenc.keystore = keystore
    return elf_path, off, va


def populated(elf_path):
    """{slot: der} for every populated slot, using this executable."""
    use_disc(elf_path)
    return {slot: der for slot, der in polenc.keystore(elf_path) if der}


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -m playonline.keys DISC_OR_BOOT_ELF")
    target = sys.argv[1]
    path = target
    made = False
    if not target.lower().endswith((".elf", ".00", ".69", ".04")):
        try:
            path = boot_elf(target)
            made = True
        except Exception:                            # noqa: BLE001
            path = target
    try:
        elf, off, va = use_disc(path)
        keys = {s: d for s, d in polenc.keystore(elf) if d}
        print("keystore at file 0x%06x (VA 0x%08x)" % (off, va))
        print("%d populated slots of %d" % (len(keys), COUNT))
    finally:
        if made and os.path.exists(path):
            os.unlink(path)


if __name__ == "__main__":
    main()

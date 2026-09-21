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
"""Decrypt an installed PlayOnline `.pex.enc` module or boot container.

An installed container is keyed to the drive it was installed on. Its layout
is the universal (disc) layout without the first 128-byte header block.

    HDD ID [0x50:0x60]          -> record key     (polrecord.derive_key)
    __net record                -> `four`         (polrecord.decode)
    HDD ID [0x40:0x48] + [0x50:0x60] + four
                                -> K1             (polkey.derive_k1)
    3DES(K1, file[768:896])     -> K2             (polkey.derive_k2)
    3DES(K2, file[1408:])       -> bulk plaintext, tag c5c6a93441e1acb0
    RSA block at file[512:640]  -> a static 32-byte key
    3DES(static key, payload)   -> the module, usually a PEX container

    python3 -m playonline.lib.poldecrypt FILE.pex.enc --hddid HDDID --record RECORD
    python3 -m playonline.lib.poldecrypt FILE.pex.enc --hddid HDDID --image DRIVE
"""
import argparse
import os
import struct
import sys

from . import pexcodec
from . import polenc
from . import polkey
from . import polrecord

BULK_OFF = 1408                 # universal 1536, minus the extra header block
SLOT6_OFF, SLOT_K1_OFF = 512, 768
SIZES_OFF, SESSION_OFF = 896, 1024
BULK_TAG = b"c5c6a93441e1acb0"
SLOT6_TAG = b"e6c71666d785d576"
MODULE_TAG = b"6ee4f8ee8d64aa59"

# The block at +512 supplies the static 32-byte 3DES key for the last stage.
# A `.pex` module signs it with keystore slot 6, the Viewer's boot container
# with slot 10 and a tag of its own. The rest of the layout is the same: sizes
# at +896 (slot 3), session at +1024 (slot 11), payload digest at +640
# (slot 28).
STATIC_KEY_BLOCKS = ((6, SLOT6_TAG), (10, b"2879f6e2370182be"))
RECORD_OFF = 0x00201800         # within __net, outside its file system


def material(hddid, record):
    """(ata24, four) from a drive's HDD ID block and its own __net record."""
    w1, w2 = hddid[0x40:0x48], hddid[0x50:0x60]
    key = polrecord.derive_key(w2)
    pt = polrecord.decode(record, key)
    if pt[12:20] != bytes(8):
        raise SystemExit("record did not decode (expected 8 zero bytes at [12:20]); "
                         "is this record from the same drive as the HDD ID?")
    return w1 + w2, pt[:4]


def decrypt(blob, ata24, four, keys=None):
    keys = keys or {s: polenc.parse_spki(d) for s, d in polenc.keystore() if d}
    sizes = polenc.unpad_pkcs1(polenc.rsa_public(blob[SIZES_OFF:SIZES_OFF + 128], keys[3]))
    if sizes is None or not sizes.endswith(b"bdbf6d4db9be0aa0"):
        raise ValueError("sizes block failed: not an installed container?")
    padded, true = struct.unpack("<II", sizes[:8])
    extra = sizes[8:-16]

    k1 = polkey.derive_k1(ata24, four)
    k2 = polkey.derive_k2(polenc.des3(k1, blob[SLOT_K1_OFF:SLOT_K1_OFF + 128]), ata24, four)
    n = (len(blob) - BULK_OFF) & ~7
    bulk = polenc.des3(k2, blob[BULK_OFF:BULK_OFF + n])
    if bulk[extra[2] + padded:extra[2] + padded + 16] != BULK_TAG:
        raise ValueError("bulk tag failed: wrong drive material for this file")

    static = None
    for slot, tag in STATIC_KEY_BLOCKS:
        d = polenc.unpad_pkcs1(polenc.rsa_public(blob[SLOT6_OFF:SLOT6_OFF + 128], keys[slot]))
        if d is not None and d.endswith(tag):
            static = d
            break
    if static is None:
        raise ValueError("static-key block at +%d verified under no known slot %s"
                         % (SLOT6_OFF, [s for s, _ in STATIC_KEY_BLOCKS]))
    out = polenc.des3(static[:32], bulk[extra[2]:extra[2] + padded])
    mod = out[extra[1]:extra[1] + true]
    # The trailing tag names the kind of payload: `.pex` modules carry
    # MODULE_TAG and the Viewer's boot executable carries another value. Every
    # tag is 16 lowercase hex characters, so the shape is checked and the
    # value is returned to the caller.
    tag = out[extra[1] + true:extra[1] + true + 16]
    if len(tag) != 16 or not all(c in b"0123456789abcdef" for c in tag):
        raise ValueError("module tag failed (not a hex tag): %r" % tag)
    return mod, tag


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--hddid", required=True, help="the drive's 512-byte HDD ID")
    ap.add_argument("--record", help="512 bytes from __net+0x201800")
    ap.add_argument("--image", help="take the record straight from a drive image")
    ap.add_argument("--net-lba", type=int, default=262144)
    ap.add_argument("-o", "--out", default=".")
    ap.add_argument("--raw", action="store_true", help="keep the PEX container")
    args = ap.parse_args()

    hddid = open(args.hddid, "rb").read()
    if args.record:
        record = open(args.record, "rb").read()[:512]
    elif args.image:
        with open(args.image, "rb") as f:
            f.seek(args.net_lba * 512 + RECORD_OFF)
            record = f.read(512)
    else:
        raise SystemExit("need --record or --image")

    ata24, four = material(hddid, record)
    print("ata24 = %s\nfour  = %s\n" % (ata24.hex(), four.hex()))
    keys = {s: polenc.parse_spki(d) for s, d in polenc.keystore() if d}

    os.makedirs(args.out, exist_ok=True)
    for p in args.files:
        name = os.path.basename(p)
        try:
            mod, tag = decrypt(open(p, "rb").read(), ata24, four, keys)
        except Exception as e:
            print("  %-28s FAILED: %s" % (name, e))
            continue
        note = "" if tag == MODULE_TAG else "  [tag %s]" % tag.decode()
        dst = os.path.join(args.out, name[:-4] if name.endswith(".enc") else name + ".dec")
        if not args.raw and pexcodec.is_pex(mod):
            code = pexcodec.decompress(mod)
            open(dst, "wb").write(code)
            print("  %-28s -> %s  (%d bytes, PEX %d -> %d)"
                  % (name, os.path.basename(dst), len(code), len(mod), len(code)) + note)
        else:
            open(dst, "wb").write(mod)
            print("  %-28s -> %s  (%d bytes)%s"
                  % (name, os.path.basename(dst), len(mod), note))
    return 0


if __name__ == "__main__":
    sys.exit(main())

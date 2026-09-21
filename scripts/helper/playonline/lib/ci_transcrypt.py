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
"""Convert a universal boot container into an installed one, offline.

Square Enix's installer performs this step on the console after it copies the
disc. This module performs it on the PC.

What changes
------------
Every RSA-signed block is copied unchanged, because nothing here can sign. Per
section, the transform drops the two universal-only blocks (slot 15, the shipped
bulk key; slot 20, a SHA-1 over the universal ciphertext that re-encryption
would invalidate anyway), inserts one console-bound block, and re-keys the bulk:

    universal section                 installed section
      +0    slot 15   (bulk key)   -> dropped
      +128  slot 10   (static)     -> +0
      +256  slot 20   (sha-1)      -> dropped
      +384  slot 28   (digest)     -> +128
                                      +256  the K1 block   (new, minted here)
      +512  slot 3    (sizes)      -> +384
      +640  slot 11   (session)    -> +512
      +768  slot 4                 -> +640
      +896  3DES block (slot tab)  -> +768
     +1024  bulk                   -> +896  re-encrypted under the drive's K2

Slot 28 is a digest that is byte-identical between the two forms of the same
build, which shows it covers the plaintext and not the ciphertext, so re-keying
the bulk does not invalidate it.

The section table (slot 2) already carries both forms' sizes, so it is copied
too: `+4` is the universal sizes, `+4+4*count` the installed bulk lengths. An
installed section is `installed_bulk[j] + 896` bytes.

The key material
----------------
    ata24 = hddid[0x40:0x48] + hddid[0x50:0x60]
    k1    = polkey.derive_k1(ata24, four)
    k2    = polkey.derive_k2(des3(k1, K1block), ata24, four)
    bulk  = des3_enc(k2, plaintext)

`four` comes from the drive's `__net` record, and this installer writes both, so
it is free to choose; it only has to agree in the two places. `K1block` is
likewise free (nothing verifies it; the bulk tag catches a wrong key), so it is
generated deterministically from the drive material and the section index to
make a rebuild reproducible.

The bulk plaintext is not copied verbatim: the two forms index `extra`
differently, so the payload moves.

    universal:  filler[extra[0]] payload[padded] 45ddf2896e7a3778  -> align8
    installed:  filler[extra[2]] payload[padded] c5c6a93441e1acb0  -> align8

The `padded` payload itself is identical.

    python3 -m playonline.lib.ci_transcrypt UNIVERSAL --hddid ID.bin -o OUT [--record REC.bin]
    python3 -m playonline.lib.ci_transcrypt --check INSTALLED --hddid ID.bin

`--check` re-reads the result with the installed-form reader and verifies every
section's bulk tag and module tag.
"""
import argparse
import hashlib
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from . import ci_universal                                        # noqa: E402
from . import polenc                                              # noqa: E402
from . import polkey                                              # noqa: E402
from . import polrecord                                           # noqa: E402

FILE_HDR = ci_universal.FILE_HDR
INST_HDR = ci_universal.INST_HDR
INST_BULK_TAG = ci_universal.INST_BULK_TAG
MODULE_TAG = ci_universal.MODULE_TAG

# section-relative offsets, installed form
I_STATIC, I_DIGEST, I_K1, I_SIZES, I_SESSION, I_SLOT4, I_B128 = (
    0, 128, 256, 384, 512, 640, 768)

DEFAULT_FOUR = bytes.fromhex("0001776c")


# Sys1_driver keeps only bytes 64..71 and 80..95 of the ATA IDENTIFY reply, so
# the 24 bytes the key schedule sees are exactly these two slices.
PCSX2_ATA24 = bytes.fromhex("0000000100001a01") + bytes(16)


def ata_material(hddid=None, pcsx2=False):
    """The 24 bytes the key schedule sees, and the record's own key.

    The choice must match the target. A container built for the other case
    verifies here and fails to decrypt on the target.

    * hddid (the default): the 24 bytes are `[0x40:0x48]` and `[0x50:0x60]` of
      the HDD ID block the console is served. PCSX2 serves the `.hddid` beside
      the image, and a console serves the one the loader holds.
    * pcsx2: for an emulator that has no `.hddid` and answers IDENTIFY with
      zeros. The record key is then `derive_key(zeros)`, which is
      `polrecord.PCSX2_KEY`.
    """
    if pcsx2:
        return PCSX2_ATA24, polrecord.PCSX2_KEY
    return (hddid[0x40:0x48] + hddid[0x50:0x60],
            polrecord.derive_key(hddid[0x50:0x60]))


def material(hddid, four, pcsx2=False):
    """(ata24, k1) for a drive. `four` is the value minted into its record."""
    ata24, _ = ata_material(hddid, pcsx2)
    return ata24, polkey.derive_k1(ata24, four)


def default_identity(hddid):
    """The 8-byte record identity used when none is given, derived from the HDD ID."""
    return hashlib.sha256(b"playonline-record-identity"
                          + hddid[0x40:0x60]).digest()[:8]


def _k1block(ata24, four, j):
    """128 free bytes. Nothing verifies them, so make them reproducible."""
    seed = hashlib.sha256(ata24 + four + b"k1block" + struct.pack("<I", j)).digest()
    out = b""
    while len(out) < 128:
        out += hashlib.sha256(seed + struct.pack("<I", len(out))).digest()
    return out[:128]


def transcrypt(blob, hddid, four, keys=None, pcsx2=False):
    """Universal container bytes -> installed container bytes."""
    keys = keys or ci_universal._keys()
    if not ci_universal.is_universal(blob, keys):
        raise ValueError("input is not a universal container")
    ata24, k1 = material(hddid, four, pcsx2)
    usz, isz = ci_universal.section_sizes(blob, keys)
    out = bytearray(blob[:FILE_HDR])
    for j, (off, size) in enumerate(ci_universal.sections(blob, keys)):
        sec = blob[off:off + size]
        padded, true, extra = ci_universal.sizes(sec, keys)
        ubulk = ci_universal.bulk(sec, keys)
        pay = ubulk[extra[0]:extra[0] + padded]

        want = ((extra[2] + padded + 16 + 7) // 8) * 8
        if want != isz[j]:
            raise ValueError("section %d: computed installed bulk %d but the "
                             "table says %d" % (j, want, isz[j]))
        # filler is not checked by anything; reuse the universal plaintext's so
        # a rebuild is byte-stable and the bytes look like what SE ships
        head = ubulk[:extra[2]]
        plain = bytearray(head + pay + INST_BULK_TAG)
        plain += ubulk[len(plain):isz[j]] if len(ubulk) >= isz[j] else b"\0" * (isz[j] - len(plain))
        plain = bytes(plain[:isz[j]])
        if len(plain) != isz[j]:
            raise ValueError("section %d: plaintext %d != %d" % (j, len(plain), isz[j]))

        b128 = _k1block(ata24, four, j)
        k2 = polkey.derive_k2(b128, ata24, four)
        U = ci_universal
        out += (sec[U.U_STATIC:U.U_STATIC + 128] +
                sec[U.U_DIGEST:U.U_DIGEST + 128] +
                polenc.des3_enc(k1, b128) +
                sec[U.U_SIZES:U.U_SIZES + 128] +
                sec[U.U_SESSION:U.U_SESSION + 128] +
                sec[U.U_SLOT4:U.U_SLOT4 + 128] +
                sec[U.U_B128:U.U_B128 + 128] +
                polenc.des3_enc(k2, plain))
    return bytes(out)


def installed_sections(blob, keys=None):
    """[(offset, size)] for an installed container."""
    keys = keys or ci_universal._keys()
    _, isz = ci_universal.section_sizes(blob, keys)
    out, off = [], FILE_HDR
    for s in isz:
        out.append((off, s + INST_HDR))
        off += s + INST_HDR
    return out


def check(blob, hddid, four, keys=None, pcsx2=False):
    """Read an installed container back. [(label, ok, detail)]."""
    keys = keys or ci_universal._keys()
    out = []
    ata24, k1 = material(hddid, four, pcsx2)
    try:
        secs = installed_sections(blob, keys)
    except Exception as e:
        return [("section table", False, str(e))]
    total = FILE_HDR + sum(s for _, s in secs)
    out.append(("length", total == len(blob), "computed %d, file %d" % (total, len(blob))))
    for j, (off, size) in enumerate(secs):
        sec = blob[off:off + size]
        try:
            d = polenc.unpad_pkcs1(polenc.rsa_public(sec[I_SIZES:I_SIZES + 128], keys[3]))
            if d is None or not d.endswith(b"bdbf6d4db9be0aa0"):
                raise ValueError("sizes block failed")
            padded, true = struct.unpack("<II", d[:8])
            extra = d[8:-16]
            b128 = polenc.des3(k1, sec[I_K1:I_K1 + 128])
            k2 = polkey.derive_k2(b128, ata24, four)
            bulk = polenc.des3(k2, sec[INST_HDR:])
            at = extra[2] + padded
            ok = bulk[at:at + 16] == INST_BULK_TAG
            out.append(("section %d bulk tag" % j, ok,
                        "at %d: %r" % (at, bulk[at:at + 16])))
            if not ok:
                continue
            key = None
            for slot, tag in ci_universal.STATIC_SLOTS:
                d = polenc.unpad_pkcs1(
                    polenc.rsa_public(sec[I_STATIC:I_STATIC + 128], keys[slot]))
                if d is not None and d.endswith(tag):
                    key = d[:32]
                    break
            if key is None:
                raise ValueError("static-key block signed by no known slot")
            mod = polenc.des3(key, bulk[extra[2]:extra[2] + padded])
            tag = mod[extra[1] + true:extra[1] + true + 16]
            kind = {MODULE_TAG: "boot exe",
                    ci_universal.PEX_MODULE_TAG: ".pex"}.get(tag, "?")
            out.append(("section %d module" % j, ci_universal.is_kind_tag(tag),
                        "%d bytes, tag %r (%s), head %s"
                        % (true, tag, kind, mod[extra[1]:extra[1] + 4].hex())))
        except Exception as e:
            out.append(("section %d" % j, False, str(e)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("container", nargs="?")
    ap.add_argument("--check", metavar="INSTALLED")
    ap.add_argument("--hddid", required=True)
    ap.add_argument("--four", default=DEFAULT_FOUR.hex(),
                    help="4 hex bytes; must match the drive's __net record")
    ap.add_argument("-o", "--out")
    ap.add_argument("--record", metavar="OUT", help="also mint the matching __net record")
    ap.add_argument("--pcsx2", action="store_true",
                    help="build for the emulator's zeroed IDENTIFY instead of the .hddid")
    ap.add_argument("--identity", metavar="HEX",
                    help="8-byte console identity for the minted record; "
                         "derived from the HDD ID when absent")
    args = ap.parse_args()

    hddid = open(args.hddid, "rb").read()
    four = bytes.fromhex(args.four)
    keys = ci_universal._keys()
    ok = True

    if args.check:
        blob = open(args.check, "rb").read()
        for label, good, detail in check(blob, hddid, four, keys, args.pcsx2):
            print("  [%s] %-26s %s" % ("ok" if good else "FAIL", label, detail))
            ok = ok and good
        return 0 if ok else 1

    blob = open(args.container, "rb").read()
    built = transcrypt(blob, hddid, four, keys, args.pcsx2)
    print("universal %d -> installed %d bytes" % (len(blob), len(built)))
    for label, good, detail in check(built, hddid, four, keys, args.pcsx2):
        print("  [%s] %-26s %s" % ("ok" if good else "FAIL", label, detail))
        ok = ok and good
    if args.out and ok:
        open(args.out, "wb").write(built)
        print("wrote %s" % args.out)
    elif args.out:
        print("not written: the self-check failed")
    if args.record:
        _, key = ata_material(hddid, args.pcsx2)
        identity = (bytes.fromhex(args.identity) if args.identity
                    else default_identity(hddid))
        rec = polrecord.encode(polrecord.mint(four, identity), key)
        open(args.record, "wb").write(rec)
        print("wrote %s (512 bytes, four=%s); it goes at __net + 0x201800"
              % (args.record, four.hex()))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

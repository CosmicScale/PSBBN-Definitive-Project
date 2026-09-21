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
r"""Patch the payload of an installed PlayOnline container, in place.

`poldecrypt` opens an installed container and this module writes one back.
The sizes block at +896 and the static-key block at +512 are RSA-signed, so
they are reused as they are and the payload must keep its exact length. Only
the 3DES bulk is recomputed, from keys the drive material yields.

The Viewer's installed boot file holds three containers one after another.
The third is the boot executable, stored as an uncompressed ELF, so words in
it can be set by virtual address through the ELF's own program headers.

The signed SHA-1 of the payload at +640 cannot be reissued. After an edit it
no longer matches, and the write is refused without `--force`. A loader that
verifies that digest rejects the edited container.

Every write is checked first: the rebuilt container is decrypted again and
compared with the intended payload, and every byte outside the bulk must be
unchanged.

    python3 -m playonline.lib.polencpatch FILE --hddid HDDID --record RECORD --list
    python3 -m playonline.lib.polencpatch FILE --hddid HDDID --record RECORD \
        --container 2 -o boot.elf
    python3 -m playonline.lib.polencpatch FILE --hddid HDDID --record RECORD \
        --container 2 --set 0x00821d60=0x03e00008 -o FILE.new --force
"""
import argparse
import os
import struct
import sys

from . import pexcodec
from . import poldecrypt as P
from . import polenc
from . import polkey

TAIL = b"bdbf6d4db9be0aa0"          # the sizes block's own tag


def find_containers(blob, keys):
    """Every offset in `blob` where a sizes block verifies.

    Container bases are 8-aligned and otherwise irregular, so every 8-byte
    step is tried.
    """
    out = []
    for base in range(0, max(0, len(blob) - P.SIZES_OFF - 128), 8):
        try:
            d = polenc.unpad_pkcs1(polenc.rsa_public(
                blob[base + P.SIZES_OFF:base + P.SIZES_OFF + 128], keys[3]))
        except Exception:
            continue
        if d and d.endswith(TAIL):
            padded, true = struct.unpack("<II", d[:8])
            out.append((base, padded, true, d[8:-16]))
    return out


class Container:
    """One container, opened far enough to put a payload back."""

    def __init__(self, blob, base, ata24, four, keys):
        self.blob, self.base, self.keys = blob, base, keys
        b = blob[base:]
        sizes = polenc.unpad_pkcs1(polenc.rsa_public(
            b[P.SIZES_OFF:P.SIZES_OFF + 128], keys[3]))
        if not sizes or not sizes.endswith(TAIL):
            raise SystemExit("no container at 0x%x" % base)
        self.padded, self.true = struct.unpack("<II", sizes[:8])
        self.extra = sizes[8:-16]
        k1 = polkey.derive_k1(ata24, four)
        self.k2 = polkey.derive_k2(
            polenc.des3(k1, b[P.SLOT_K1_OFF:P.SLOT_K1_OFF + 128]), ata24, four)
        self.n = (len(b) - P.BULK_OFF) & ~7
        self.bulk = polenc.des3(self.k2, b[P.BULK_OFF:P.BULK_OFF + self.n])
        self.static = None
        for slot, tag in P.STATIC_KEY_BLOCKS:
            d = polenc.unpad_pkcs1(polenc.rsa_public(
                b[P.SLOT6_OFF:P.SLOT6_OFF + 128], keys[slot]))
            if d is not None and d.endswith(tag):
                self.static = d
                break
        if self.static is None:
            raise SystemExit("static-key block verified under no known slot")
        self.inner = self.bulk[self.extra[2]:self.extra[2] + self.padded]
        self.out = polenc.des3(self.static[:32], self.inner)
        self.payload = self.out[self.extra[1]:self.extra[1] + self.true]

    def digest_block(self):
        """The RSA-signed SHA-1 of the inner ciphertext, at +640 (slot 28).

        Changing any payload byte changes the inner ciphertext and so its
        SHA-1, and the block cannot be reissued. A loader that checks it
        rejects an edited container.
        """
        d = polenc.unpad_pkcs1(polenc.rsa_public(
            self.blob[self.base + 640:self.base + 768], self.keys[28]))
        return d[:20] if d else None

    def rebuild(self, payload):
        """The container with `payload` in place of the old one. Same length."""
        if len(payload) != self.true:
            raise SystemExit("payload is %d bytes, must be exactly %d: every "
                             "length field is RSA-signed and cannot be reissued"
                             % (len(payload), self.true))
        out = bytearray(self.out)
        out[self.extra[1]:self.extra[1] + self.true] = payload
        inner = polenc.des3_enc(self.static[:32], bytes(out))
        # des3 works whole blocks; keep any sub-block tail exactly as it was
        inner += self.inner[len(inner):]
        bulk = bytearray(self.bulk)
        bulk[self.extra[2]:self.extra[2] + self.padded] = inner
        enc = polenc.des3_enc(self.k2, bytes(bulk))
        blob = bytearray(self.blob)
        at = self.base + P.BULK_OFF
        blob[at:at + len(enc)] = enc
        return bytes(blob)


def elf_fileoff(elf, va):
    """vaddr -> file offset via the ELF's own program headers."""
    n = struct.unpack_from("<H", elf, 0x2C)[0]
    off = struct.unpack_from("<I", elf, 0x1C)[0]
    for i in range(n):
        typ, o, base, _pa, fsz, _msz = struct.unpack_from("<IIIIII", elf, off + i * 32)
        if typ == 1 and base <= va < base + fsz:
            return o + (va - base)
    raise SystemExit("0x%08x is in no LOAD segment" % va)


def material(args):
    hddid = open(args.hddid, "rb").read()
    if args.record:
        record = open(args.record, "rb").read()[:512]
    elif args.image:
        with open(args.image, "rb") as f:
            f.seek(args.net_lba * 512 + P.RECORD_OFF)
            record = f.read(512)
    else:
        raise SystemExit("need --record or --image")
    return P.material(hddid, record)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("file")
    ap.add_argument("--hddid", required=True, help="the drive's 512-byte HDD ID")
    ap.add_argument("--record", help="512 bytes from __net+0x201800")
    ap.add_argument("--image", help="take the record from a drive image instead")
    ap.add_argument("--net-lba", type=int, default=262144)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--container", type=int, default=0,
                    help="index into --list order (default 0)")
    ap.add_argument("--content", help="replacement payload, same length")
    ap.add_argument("--set", action="append", default=[], metavar="VA=WORD",
                    help="patch one 32-bit word by title vaddr (ELF payloads)")
    ap.add_argument("-o", "--out")
    ap.add_argument("--force", action="store_true",
                    help="write even though the signed +640 digest will mismatch")
    ap.add_argument("--selftest", action="store_true",
                    help="rebuild unmodified and require byte-identity")
    args = ap.parse_args()

    blob = open(args.file, "rb").read()
    keys = {s: polenc.parse_spki(d) for s, d in polenc.keystore() if d}
    found = find_containers(blob, keys)
    if not found:
        raise SystemExit("no containers found in %s" % args.file)

    if args.list:
        ata24, four = material(args)
        for i, (base, padded, true, _x) in enumerate(found):
            mod, tag = P.decrypt(blob[base:], ata24, four, keys)
            kind = ("raw ELF" if mod[:4] == b"\x7fELF"
                    else "PEX/LZSS" if pexcodec.is_pex(mod) else "opaque")
            print("  [%d] 0x%06x  %9d bytes  tag %s  %s"
                  % (i, base, true, tag.decode(), kind))
        return

    if not 0 <= args.container < len(found):
        raise SystemExit("--container must be 0..%d" % (len(found) - 1))
    base = found[args.container][0]
    ata24, four = material(args)
    c = Container(blob, base, ata24, four, keys)
    print("container %d at 0x%06x: %d bytes%s"
          % (args.container, base, c.true,
             ", raw ELF" if c.payload[:4] == b"\x7fELF" else ""))

    if args.selftest:
        rebuilt = c.rebuild(c.payload)
        ok = rebuilt == blob
        print("no-op rebuild byte-identical:", ok)
        raise SystemExit(0 if ok else 1)

    if not args.content and not args.set:
        if not args.out:
            raise SystemExit("nothing to do: give -o to extract, or a patch")
        open(args.out, "wb").write(c.payload)
        print("wrote %s (%d bytes)" % (args.out, len(c.payload)))
        return

    payload = bytearray(open(args.content, "rb").read() if args.content else c.payload)
    for s in args.set:
        va, word = s.split("=", 1)
        va, word = int(va, 0), int(word, 0) & 0xFFFFFFFF
        off = elf_fileoff(bytes(payload), va)
        before = struct.unpack_from("<I", payload, off)[0]
        struct.pack_into("<I", payload, off, word)
        print("    0x%08x (file+0x%x): %08x -> %08x" % (va, off, before, word))

    rebuilt = c.rebuild(bytes(payload))

    # Verify before writing: re-open the rebuilt container and compare, and
    # require that nothing outside the bulk moved.
    check = Container(rebuilt, base, ata24, four, keys)
    if check.payload != bytes(payload):
        raise SystemExit("verify failed: rebuilt container does not decrypt back")
    lo, hi = base + P.BULK_OFF, base + P.BULK_OFF + c.n
    if rebuilt[:lo] != blob[:lo] or rebuilt[hi:] != blob[hi:]:
        raise SystemExit("verify failed: bytes outside the bulk changed")
    print("verified: re-decrypts to the patched payload, nothing else moved")

    signed = c.digest_block()
    if signed is not None:
        import hashlib
        now = hashlib.sha1(check.inner).digest()
        if now != signed:
            print("\nwarning: the signed SHA-1 at +640 no longer matches.")
            print("      signed: %s" % signed.hex())
            print("      actual: %s" % now.hex())
            print("    A loader that verifies it will refuse this container.")
            if not args.force:
                raise SystemExit("refusing to write; pass --force if the loader "
                                 "does not verify the digest")

    if args.out:
        open(args.out, "wb").write(rebuilt)
        print("wrote %s (%d bytes, same size as input: %s)"
              % (args.out, len(rebuilt), len(rebuilt) == len(blob)))


if __name__ == "__main__":
    sys.exit(main() or 0)

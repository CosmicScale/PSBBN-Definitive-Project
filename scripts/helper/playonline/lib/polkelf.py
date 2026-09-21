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
r"""Decrypt a PS2 KELF (MagicGate-signed executable) and repack it as a pre-decrypted KELF that PCSX2 will run.

The PS2 boots signed executables (KELFs) and PCSX2 has no MagicGate keys, so it
prints

    [MG] ERROR - Make sure the file is already decrypted!!!

and gives up. That matters for `PP.<product>.1000.POLVIEWER/dnasload.elf`,
which is what HDD-OSD launches when PlayOnline is picked.

PCSX2 runs a KELF whose bit table and body are stored in the clear. `--patch`
writes that form at the original size, which is what `polpfspatch.py` needs,
since it reuses a file's existing zones and cannot grow one.

Format and algorithm are a port of kelftool (xfwcfw, GPL-3.0) `src/kelf.cpp`,
read as source:

    header      32 bytes  UserDefined[16], ContentSize u32, HeaderSize u16,
                          SystemType u8, ApplicationType u8, Flags u16,
                          BitCount u16, MGZones u32
    +32          8 bytes  header signature
    +40         16 bytes  Kbit    (encrypted with the KEK)
    +56         16 bytes  Kc      (encrypted with the KEK)
    +72   HeaderSize-88   bit table (EDE2-CBC under Kbit, IV = content-table IV)
                 8 bytes  bit-table signature
                 8 bytes  root signature
    HeaderSize            content: BlockCount blocks, each Size bytes; blocks
                          flagged ENCRYPTED are EDE2-CBC under Kc with the
                          content IV reset per block

The KEK is derived from the header itself: `header[0:8] xor header[8:16]`, xored
into the Kbit/Kc IVs and encrypted under the two master keys. Every signature is
verified before anything is written, so a wrong keyfile is rejected.

Keys
----
The MagicGate keys are not distributed with this package. Supply them in a
kelftool-style `PS2KEYS.dat` (`NAME=HEX` per line). Search order: `--keys`,
`$PS2KEYS`, then `~/PS2KEYS.dat`.
Needed: MG_SIG_MASTER_KEY, MG_SIG_HASH_KEY, MG_KBIT_MASTER_KEY, MG_KBIT_IV,
MG_KC_MASTER_KEY, MG_KC_IV, MG_ROOTSIG_MASTER_KEY, MG_ROOTSIG_HASH_KEY,
MG_CONTENT_TABLE_IV, MG_CONTENT_IV.

    python polkelf.py dnasload.elf --info
    python polkelf.py dnasload.elf -o dnasload.plain      # the bare ELF
    python polkelf.py dnasload.elf --patch dnasload.dec   # same size, PCSX2-runnable
"""
import argparse
import os
import struct
import sys

from Crypto.Cipher import DES

NULL_IV = bytes(8)
KEY_NAMES = ("MG_SIG_MASTER_KEY", "MG_SIG_HASH_KEY", "MG_KBIT_MASTER_KEY",
             "MG_KBIT_IV", "MG_KC_MASTER_KEY", "MG_KC_IV",
             "MG_ROOTSIG_MASTER_KEY", "MG_ROOTSIG_HASH_KEY",
             "MG_CONTENT_TABLE_IV", "MG_CONTENT_IV")

BIT_BLOCK_ENCRYPTED = 1
BIT_BLOCK_SIGNED = 2


def load_keys(path=None):
    for p in [path, os.environ.get("PS2KEYS"),
              os.path.expanduser("~/PS2KEYS.dat")]:
        if p and os.path.isfile(p):
            ks = {}
            with open(p) as f:
                for line in f:
                    line = line.split("#")[0].strip()
                    if "=" in line:
                        k, v = line.split("=", 1)
                        ks[k.strip()] = bytes.fromhex(v.strip())
            missing = [n for n in KEY_NAMES if n not in ks]
            if missing:
                raise SystemExit("%s is missing %s" % (p, ", ".join(missing)))
            return ks
    raise SystemExit("no PS2KEYS.dat found -- pass --keys, or set $PS2KEYS")


# --- DES primitives ---------------------------------------------------------
# kelftool calls OpenSSL's DES_cbc_encrypt (1 key), DES_ede2_cbc_encrypt (2) and
# DES_ede3_cbc_encrypt (3).  EDE2 is EDE3 with K3 = K1.  pycryptodome refuses a
# 3DES key that degenerates to single DES (K1 == K2), which is legal here, so
# the EDE is built by hand out of single-DES ECB rather than via DES3.

def _ecb(key):
    return DES.new(key, DES.MODE_ECB)


def _block(keys, data, encrypt):
    """One EDE block operation with 1, 2 or 3 keys, matching OpenSSL."""
    if len(keys) == 1:
        k = _ecb(keys[0])
        return k.encrypt(data) if encrypt else k.decrypt(data)
    k1, k2 = _ecb(keys[0]), _ecb(keys[1])
    k3 = _ecb(keys[2]) if len(keys) == 3 else k1
    if encrypt:                                   # C = E_k3(D_k2(E_k1(P)))
        return k3.encrypt(k2.decrypt(k1.encrypt(data)))
    return k1.decrypt(k2.encrypt(k3.decrypt(data)))


def _split(key, count):
    return [key[i * 8:i * 8 + 8] for i in range(count)]


def cbc_encrypt(data, key, count, iv):
    keys, out, prev = _split(key, count), bytearray(), iv
    for off in range(0, len(data), 8):
        blk = bytes(a ^ b for a, b in zip(data[off:off + 8].ljust(8, b"\0"), prev))
        prev = _block(keys, blk, True)
        out += prev
    return bytes(out)


def cbc_decrypt(data, key, count, iv):
    keys, out, prev = _split(key, count), bytearray(), iv
    for off in range(0, len(data), 8):
        ct = data[off:off + 8]
        if len(ct) < 8:                            # OpenSSL leaves a short tail
            out += ct                              # alone; mirror that
            break
        out += bytes(a ^ b for a, b in zip(_block(keys, ct, False), prev))
        prev = ct
    return bytes(out)


def _xor(a, b):
    return bytes(x ^ y for x, y in zip(a, b))


# --- KELF -------------------------------------------------------------------
class Kelf:
    def __init__(self, blob, ks):
        self.ks, self.blob = ks, blob
        self.header = blob[:32]
        (self.content_size, self.header_size, self.system_type,
         self.app_type, self.flags, self.bit_count,
         self.mg_zones) = struct.unpack_from("<IHBBHHI", blob, 16)
        if self.flags & 1 or self.flags & 0xF0000 or self.bit_count != 0:
            raise SystemExit("unsupported KELF: flags=0x%X bitcount=%d"
                             % (self.flags, self.bit_count))

    def header_signature(self):
        enc = cbc_encrypt(self.header, self.ks["MG_SIG_MASTER_KEY"], 1, NULL_IV)
        s = cbc_decrypt(enc[-8:], self.ks["MG_SIG_HASH_KEY"], 1, NULL_IV)
        return cbc_encrypt(s, self.ks["MG_SIG_MASTER_KEY"], 1, NULL_IV)

    def kek(self):
        hd = _xor(self.header[:8], self.header[8:16])
        a = cbc_encrypt(_xor(self.ks["MG_KBIT_IV"], hd),
                        self.ks["MG_KBIT_MASTER_KEY"], 2, NULL_IV)
        b = cbc_encrypt(_xor(self.ks["MG_KC_IV"], hd),
                        self.ks["MG_KC_MASTER_KEY"], 2, NULL_IV)
        return a + b

    def bit_table_signature(self, kbit, kc, table):
        h = kbit[:8]
        if kbit[:8] != kbit[8:16]:
            h = _xor(kbit[8:16], h)
        h = _xor(kc[:8], h)
        if kc[:8] != kc[8:16]:
            h = _xor(kc[8:16], h)
        for i in range(self.block_count * 2 + 1):
            h = _xor(table[i * 8:i * 8 + 8], h)
        key = self.ks["MG_SIG_MASTER_KEY"] + self.ks["MG_SIG_HASH_KEY"]
        return cbc_encrypt(h, key, 2, NULL_IV)

    def root_signature(self, hsig, bsig):
        sigs = hsig + bsig
        for size, flags, sig in self.blocks:
            if flags & BIT_BLOCK_SIGNED:
                sigs += sig
        enc = cbc_encrypt(sigs, self.ks["MG_ROOTSIG_MASTER_KEY"], 1, NULL_IV)
        return cbc_decrypt(enc[-8:], self.ks["MG_ROOTSIG_HASH_KEY"], 2, NULL_IV)

    def parse(self, verify=True):
        b = self.blob
        hsig = b[32:40]
        if verify and hsig != self.header_signature():
            raise SystemExit("header signature mismatch -- wrong keys?")
        kek = self.kek()
        kbit, kc = bytearray(b[40:56]), bytearray(b[56:72])
        for buf in (kbit, kc):
            buf[0:8] = cbc_decrypt(bytes(buf[0:8]), kek, 2, NULL_IV)
            buf[8:16] = cbc_decrypt(bytes(buf[8:16]), kek, 2, NULL_IV)
        self.kbit, self.kc = bytes(kbit), bytes(kc)

        n = self.header_size - 72 - 16
        self.table_len = n
        table = cbc_decrypt(b[72:72 + n], self.kbit, 2,
                            self.ks["MG_CONTENT_TABLE_IV"])
        self.table = table
        self.block_count = table[4]
        self.blocks = [struct.unpack_from("<II8s", table, 8 + i * 16)
                       for i in range(self.block_count)]
        if verify:
            bsig = b[72 + n:80 + n]
            if bsig != self.bit_table_signature(self.kbit, self.kc, table):
                raise SystemExit("bit-table signature mismatch")
            if b[80 + n:88 + n] != self.root_signature(hsig, bsig):
                raise SystemExit("root signature mismatch")
        return self

    def content(self):
        """Decrypted content, block by block; the IV resets for every block."""
        out, off = bytearray(), self.header_size
        keycount = self.flags >> 4 & 3
        for size, flags, _sig in self.blocks:
            blk = self.blob[off:off + size]
            if flags & BIT_BLOCK_ENCRYPTED:
                blk = cbc_decrypt(blk, self.kc, keycount,
                                  self.ks["MG_CONTENT_IV"])
            out += blk
            off += size
        return bytes(out)


# --- building (signing) a new KELF ------------------------------------------
# Port of kelftool's Kelf::LoadContent + Kelf::SaveKelf (xfwcfw, GPL-3.0).
# Real hardware runs these: HDD-OSD/BB Navigator only launches a partition's
# BOOT2 if it is a properly signed KELF, and `--patch`'s plaintext-body trick is
# PCSX2-only. The header fields are copied from a template KELF (use the stock
# `dnasload.elf`, so SystemType/ApplicationType/Flags/MGZones are exactly what
# the console already accepts from this partition).

def _bit_table_sig(ks, kbit, kc, table, block_count):
    h = kbit[:8]
    if kbit[:8] != kbit[8:16]:
        h = _xor(kbit[8:16], h)
    h = _xor(kc[:8], h)
    if kc[:8] != kc[8:16]:
        h = _xor(kc[8:16], h)
    for i in range(block_count * 2 + 1):
        h = _xor(table[i * 8:i * 8 + 8], h)
    key = ks["MG_SIG_MASTER_KEY"] + ks["MG_SIG_HASH_KEY"]
    return cbc_encrypt(h, key, 2, NULL_IV)


def _header_sig(ks, header):
    enc = cbc_encrypt(header, ks["MG_SIG_MASTER_KEY"], 1, NULL_IV)
    s = cbc_decrypt(enc[-8:], ks["MG_SIG_HASH_KEY"], 1, NULL_IV)
    return cbc_encrypt(s, ks["MG_SIG_MASTER_KEY"], 1, NULL_IV)


def build_kelf(content, template, ks):
    """Sign+encrypt `content` as a KELF, borrowing `template`'s header fields."""
    if len(content) <= 0x20:
        raise SystemExit("content must be larger than 32 bytes")
    hdr = bytearray(template[:32])
    _cs, _hs, _st, _at, flags, _bc, _mz = struct.unpack_from("<IHBBHHI", hdr, 16)
    keycount = flags >> 4 & 3
    if keycount not in (1, 2, 3):
        raise SystemExit("template flags 0x%X give keycount %d" % (flags, keycount))
    block_count = 2
    header_size = 32 + 8 + 16 + 16 + (block_count * 2 + 1) * 8 + 8 + 8   # = 128
    struct.pack_into("<I", hdr, 16, len(content))
    struct.pack_into("<H", hdr, 20, header_size)
    struct.pack_into("<H", hdr, 26, 0)                       # BitCount
    hdr = bytes(hdr)

    kbit = b"\xAA" * 16
    kc = b"\xBB" * 16

    # block 0: the first 32 bytes, signed then encrypted; block 1: the rest, plain
    sig0 = bytes(8)
    for j in range(0, 0x20, 8):
        sig0 = _xor(content[j:j + 8], sig0)
    sig0 = cbc_encrypt(sig0, ks["MG_SIG_MASTER_KEY"] + ks["MG_SIG_HASH_KEY"], 2, NULL_IV)
    enc0 = cbc_encrypt(content[:0x20], kc, keycount, ks["MG_CONTENT_IV"])
    out_content = enc0 + content[0x20:]

    table = bytearray(struct.pack("<II", header_size, block_count))
    table += struct.pack("<II", 0x20, BIT_BLOCK_SIGNED | BIT_BLOCK_ENCRYPTED) + sig0
    table += struct.pack("<II", len(content) - 0x20, 0) + bytes(8)
    table = bytes(table)

    hsig = _header_sig(ks, hdr)
    bsig = _bit_table_sig(ks, kbit, kc, table, block_count)
    sigs = hsig + bsig + sig0                                # only SIGNED blocks
    enc = cbc_encrypt(sigs, ks["MG_ROOTSIG_MASTER_KEY"], 1, NULL_IV)
    rootsig = cbc_decrypt(enc[-8:], ks["MG_ROOTSIG_HASH_KEY"], 2, NULL_IV)

    kek = _xor(hdr[:8], hdr[8:16])
    a = cbc_encrypt(_xor(ks["MG_KBIT_IV"], kek), ks["MG_KBIT_MASTER_KEY"], 2, NULL_IV)
    b = cbc_encrypt(_xor(ks["MG_KC_IV"], kek), ks["MG_KC_MASTER_KEY"], 2, NULL_IV)
    kek = a + b
    kbit_enc = cbc_encrypt(kbit[:8], kek, 2, NULL_IV) + cbc_encrypt(kbit[8:], kek, 2, NULL_IV)
    kc_enc = cbc_encrypt(kc[:8], kek, 2, NULL_IV) + cbc_encrypt(kc[8:], kek, 2, NULL_IV)
    table_enc = cbc_encrypt(table, kbit, 2, ks["MG_CONTENT_TABLE_IV"])

    return hdr + hsig + kbit_enc + kc_enc + table_enc + bsig + rootsig + out_content


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("kelf")
    ap.add_argument("--keys")
    ap.add_argument("-o", "--out", help="write the bare decrypted content here")
    ap.add_argument("--patch", metavar="OUT",
                    help="write a same-size KELF with a plaintext body, which "
                         "is what PCSX2 will run")
    ap.add_argument("--content", metavar="FILE",
                    help="use this as the content instead of the decrypted "
                         "original (same length) -- lets you patch the payload "
                         "and repack it as a runnable KELF")
    ap.add_argument("--info", action="store_true")
    ap.add_argument("--no-verify", action="store_true",
                    help="skip signature checks (diagnostics only)")
    ap.add_argument("--encrypt", metavar="ELF",
                    help="sign this file as a new KELF, using the positional "
                         "KELF only as a header template (real hardware runs "
                         "the result); write it with -o")
    args = ap.parse_args()

    ks = load_keys(args.keys)
    blob = open(args.kelf, "rb").read()

    if args.encrypt:
        if not args.out:
            raise SystemExit("--encrypt needs -o OUT")
        content = open(args.encrypt, "rb").read()
        out = build_kelf(content, blob, ks)
        open(args.out, "wb").write(out)
        print("signed %s (%d B content) -> %s (%d B), template %s"
              % (os.path.basename(args.encrypt), len(content),
                 args.out, len(out), os.path.basename(args.kelf)))
        # self-test: the verifier here applies every check the console makes
        k = Kelf(out, ks).parse(verify=True)
        if k.content() != content:
            raise SystemExit("selftest failed: content does not round-trip")
        print("  selftest: header/bit-table/root signatures verify, "
              "content round-trips byte-exact")
        return 0
    k = Kelf(blob, ks).parse(verify=not args.no_verify)

    print("%s  %d bytes" % (os.path.basename(args.kelf), len(blob)))
    print("  ContentSize %d  HeaderSize %d  flags 0x%X  keycount %d  zones 0x%X"
          % (k.content_size, k.header_size, k.flags, k.flags >> 4 & 3, k.mg_zones))
    print("  Kbit %s  Kc %s" % (k.kbit.hex(), k.kc.hex()))
    print("  %d content blocks" % k.block_count)
    if args.info:
        for i, (size, flags, sig) in enumerate(k.blocks):
            print("    %3d  %8d  flags %d%s%s  sig %s"
                  % (i, size, flags,
                     " ENC" if flags & BIT_BLOCK_ENCRYPTED else "",
                     " SIGNED" if flags & BIT_BLOCK_SIGNED else "", sig.hex()))

    content = k.content()
    print("  content %d bytes, starts %s (%s)"
          % (len(content), content[:4].hex(" "),
             "ELF" if content[:4] == b"\x7fELF" else "not an ELF"))
    if args.content:
        repl = open(args.content, "rb").read()
        if len(repl) != len(content):
            raise SystemExit("--content is %d bytes, need exactly %d"
                             % (len(repl), len(content)))
        diff = sum(1 for a, b in zip(repl, content) if a != b)
        content = repl
        print("  content replaced from %s (%d bytes differ)"
              % (os.path.basename(args.content), diff))

    if args.out:
        open(args.out, "wb").write(content)
        print("  wrote %s (%d bytes)" % (args.out, len(content)))
    if args.patch:
        # PCSX2 parses the bit table without decrypting it, so the table is
        # written back decrypted with ENCRYPTED cleared on every block.
        tbl = bytearray(k.table)
        for i in range(k.block_count):
            off = 8 + i * 16 + 4
            flags = struct.unpack_from("<I", tbl, off)[0]
            struct.pack_into("<I", tbl, off, flags & ~BIT_BLOCK_ENCRYPTED)
        out = (blob[:72] + bytes(tbl)
               + blob[72 + k.table_len:k.header_size] + content)
        if len(out) != len(blob):
            print("  NOTE: %d vs original %d -- polpfspatch.py cannot grow a file"
                  % (len(out), len(blob)))
        open(args.patch, "wb").write(out)
        print("  wrote %s (%d bytes; plaintext bit table, ENCRYPTED cleared, "
              "plaintext body)" % (args.patch, len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

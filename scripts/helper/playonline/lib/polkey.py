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
"""Offline model of the `.pex.enc` bulk-key derivation (0x001b3758 / 0x001b33f0).

The console derives two keys from the container plus 28 bytes of console-local
material, both through the same engine:

    0x001b3758(out)        -> K1, which decrypts the container's slot-28 block
    0x001b33f0(block, out) -> K2, the bulk key for the payload

Neither is a cipher of its own. Each builds a 168-byte working buffer out of the
24 ATA IDENTIFY bytes (0x001b1c50), the 4 bytes read back from the __net
partition (0x001b2840), four 8-byte constants from the ELF and, for K2, the
128-byte slot-28 plaintext, then hands it to `0x001b32c8`. That is a tiny
interpreter: an 8-byte program in the ELF is walked as a linked list
(`i = prog[0]; do { round(i); i = prog[i] } while (i)`) and each step is one
DES-CBC pass over the whole 168 bytes, keyed either from a round-key array or
from the ATA bytes themselves.

The block cipher is plain single DES, the same primitive `0x001b1028` uses to
deobfuscate this module's path strings with the literal key `EP395gbq`.

`--selftest` checks `derive_k1` against a known answer:

    python3 -m playonline.lib.polkey --selftest

Usage as a library: `derive_k1(ata24, four)` and `derive_k2(block128, ata24,
four)`.
"""
import argparse
import os
import struct
import sys

from Crypto.Cipher import DES

HERE = os.path.dirname(os.path.abspath(__file__))
from .mips import Image                                    # noqa: E402

# The disc boot executable the constants are read from. route.use_keys() sets
# it from the user's disc; $PLAYONLINE_DISC_ELF names one for a command line.
ELF = os.environ.get("PLAYONLINE_DISC_ELF") or None


def default_elf():
    if not ELF:
        raise SystemExit("polkey: no boot executable. Pass --elf, or set "
                         "PLAYONLINE_DISC_ELF to SLPS_202.00 or SLUS_217.04 "
                         "from a PlayOnline disc.")
    return ELF

# --- per-build addresses -----------------------------------------------------
# The engine is the same program in every build; only the addresses move. The
# US sites were located by matching instruction words against the JP build
# (unique hit each, 14..16 of 17 words exact):
#
#     engine   0x001b32c8 -> 0x00204c20      K1 fn   0x001b3758 -> 0x002050b0
#     ATA_DEC  0x001b332c -> 0x00204c84      K2 fn   0x001b33f0 -> 0x00204d48
#     ENC      0x001b3344 -> 0x00204c9c
#     ATA_ENC  0x001b336c -> 0x00204cc4
#     DEC      0x001b3384 -> 0x00204cdc
#
# Code and data moved by different deltas (0x51958 vs 0x41cc0), so deriving a
# constant's address from the code delta lands outside the mapped image. The
# constant addresses below were read from the US functions' own lui/addiu pairs
# at the same instruction offsets as the JP ones (+68 in K1, +72 in K2).
#
# The constant blocks are byte-identical between the two builds, both key sets
# and both programs. Only the addresses differ between builds.
BUILDS = {
    "SLPS_202.00": dict(                       # JP PlayOnline Viewer disc
        k1_consts=0x00205FD8, k2_consts=0x00205FB0, jump_table=0x00205F90,
        engine=0x001B32C8, ata_dec=0x001B332C, enc=0x001B3344,
        ata_enc=0x001B336C, dec=0x001B3384),
    "SLUS_217.04": dict(                       # US Vana'diel Collection 2008
        k1_consts=0x00247C98, k2_consts=0x00247C70, jump_table=0x00247C50,
        engine=0x00204C20, ata_dec=0x00204C84, enc=0x00204C9C,
        ata_enc=0x00204CC4, dec=0x00204CDC),
}

# Module-level fallback (the JP build). `derive_k1`, `derive_k2` and `engine`
# resolve the addresses from the image they are given, via `build_for()`.
BUILD = BUILDS["SLPS_202.00"]

# --- the two constant sets ---------------------------------------------------
# Each is (final key, final IV, round-key-gen key, round-key-gen IV, program).
K1_CONSTS = BUILD["k1_consts"]
K2_CONSTS = BUILD["k2_consts"]

JUMP_TABLE = BUILD["jump_table"]   # 8 entries, read by the engine


def use_build(name):
    """Point the module at one of BUILDS. Returns the chosen dict."""
    global BUILD, K1_CONSTS, K2_CONSTS, JUMP_TABLE
    if name not in BUILDS:
        raise SystemExit("unknown build %r; have %s" % (name, sorted(BUILDS)))
    BUILD = BUILDS[name]
    K1_CONSTS = BUILD["k1_consts"]
    K2_CONSTS = BUILD["k2_consts"]
    JUMP_TABLE = BUILD["jump_table"]
    return BUILD




def build_for(img):
    """-> the BUILDS entry that matches `img`, detected and cached.

    The addresses are a property of the image, so they are resolved from the
    image. The result is cached on the image object.
    """
    hit = getattr(img, "_polkey_build", None)
    if hit is None:
        name = detect_build(img)
        if name is None:
            raise SystemExit(
                "polkey: this executable matches no known build; its "
                "addresses have to be added to BUILDS.")
        hit = BUILDS[name]
        try:
            img._polkey_build = hit
        except AttributeError:
            pass                  # an Image with __slots__ simply re-detects
    return hit


def detect_build(img):
    """-> the build whose jump table is present and self-consistent in `img`.

    Self-verifying: every one of the 8 entries must be one of that build's four
    handler addresses. A wrong guess fails on the first entry.
    """
    for name, b in BUILDS.items():
        handlers = {b["ata_dec"], b["enc"], b["ata_enc"], b["dec"]}
        try:
            tbl = [img.word(b["jump_table"] + 4 * i) for i in range(8)]
        except Exception:
            continue
        if all(w in handlers for w in tbl):
            return name
    return None
BLOCK = 8
NBLOCKS = 21                   # t0 = 21 at every 0x001b32c8 round -> 168 bytes
WSIZE = NBLOCKS * BLOCK


def _read(img, va, n):
    out = bytearray()
    for i in range(0, n, 4):
        out += struct.pack("<I", img.word(va + i))
    return bytes(out[:n])


def constants(img, base):
    blob = _read(img, base, 40)
    return [blob[i:i + 8] for i in range(0, 40, 8)]


# --- DES-CBC, i.e. 0x001b6d98 (encrypt) and 0x001b7d48 (decrypt) -------------
def cbc_enc(src, key, iv):
    return DES.new(key, DES.MODE_CBC, iv).encrypt(src)


def cbc_dec(src, key, iv):
    return DES.new(key, DES.MODE_CBC, iv).decrypt(src)


# --- 0x001b32c8 --------------------------------------------------------------
def engine(img, w, rk, ata, prog, final_key, final_iv):
    """Run the program over the 168-byte buffer `w` and return it.

    The jump table at 0x00205f90 has three distinct handlers:

      0x001b332c (index 0)  CBC-decrypt with key ata[16:24], iv ata[8:16],
                            then *fall through* into the index-1 handler
      0x001b3344 (1,2,3)    CBC-encrypt with key rk[i*16+8:], iv rk[i*16:]
      0x001b336c (index 5)  CBC-encrypt with key ata[8:16], iv ata[0:8],
                            then *fall through* into the index-4 handler
      0x001b3384 (4,6,7)    CBC-decrypt with key rk[i*16+8:], iv rk[i*16:]

    Indices 0 and 5 fall through into the next handler, which is why the
    table has duplicate entries.
    """
    b = build_for(img)
    table = [img.word(b["jump_table"] + 4 * i) for i in range(8)]
    ENC, DEC = b["enc"], b["dec"]
    ATA_DEC, ATA_ENC = b["ata_dec"], b["ata_enc"]

    i = prog[0]
    while True:
        if i >= 8:                                         # skips the round but
            if i == 0:                                     # still runs the test
                break
            i = prog[i]
            continue
        h = table[i]
        if h == ATA_DEC:
            w = cbc_dec(w, ata[16:24], ata[8:16])
            h = ENC                                        # falls through
        elif h == ATA_ENC:
            w = cbc_enc(w, ata[8:16], ata[0:8])
            h = DEC                                        # falls through
        if h == ENC:
            w = cbc_enc(w, rk[i * 16 + 8:i * 16 + 16], rk[i * 16:i * 16 + 8])
        elif h == DEC:
            w = cbc_dec(w, rk[i * 16 + 8:i * 16 + 16], rk[i * 16:i * 16 + 8])
        else:
            raise SystemExit("unknown handler 0x%08x for index %d" % (h, i))
        if i == 0:
            break
        i = prog[i]
    return cbc_enc(w, final_key, final_iv)


# --- the two working-buffer layouts ------------------------------------------
def _w_k2(block128, ata24, four):
    """0x001b33f0's buffer: the 128-byte block with the console material
    stitched in at sp+112 (W[32]), sp+148 (W[68]) and sp+212 (W[132])."""
    ata32 = ata24 + bytes(8)
    w = bytearray(WSIZE)
    w[0:32] = block128[0:32]
    w[32:36] = four
    w[36:68] = block128[32:64]
    w[68:100] = ata32
    w[100:132] = block128[64:96]
    w[132:136] = four
    w[136:168] = block128[96:128]
    return bytes(w)


def _w_k1(ata24, four):
    """0x001b3758's buffer. No container input, just the 32-byte ATA block (A)
    and the 4 bytes (F), interleaved byte by byte by the copy run at
    0x001b3848..0x001b3a0c. Transcribed store by store, sp-relative offsets
    converted to W indices (W starts at sp+80)."""
    A = ata24 + bytes(8)
    F = four
    w = bytearray(WSIZE)

    def put(off, data):                                    # off is sp-relative
        w[off - 80:off - 80 + len(data)] = data

    put(80, F[0:2])                     # sh   F[0..1]
    put(82, A[0:4])                     # swl/swr A[0..3]
    put(86, F[2:4])                     # sh   F[2..3]
    put(88, A[4:8])                     # sw   A[4..7]
    put(92, F[3:4])                     # sb   F[3]
    put(93, A[8:12])
    put(97, F[2:3])
    put(98, A[12:16])
    put(102, F[1:2])
    put(103, A[16:20])
    put(107, F[0:1])
    put(108, A[20:24])
    put(112, F[0:4])                    # sw   F[0..3]
    put(116, A[24:28])
    put(120, F[2:4])                    # sh   F[2..3]
    put(122, A[28:32])
    put(126, A[0:8])                    # sdl/sdr
    put(134, A[8:16])
    put(142, A[16:24])
    put(150, A[24:32])
    put(158, F[0:4])
    # That covers W[0..81].  From 0x001b3958 the rest of the buffer is filled by
    # copying pieces of what was just built; sources are all in W[0..81], so
    # there is no aliasing with the destinations.
    w[82:114] = bytes(w[40:72])         # sp+120..151 -> sp+162..193
    w[114:122] = bytes(w[72:80])        # sp+152..159 -> sp+194..201
    w[122:154] = bytes(w[0:32])         # sp+80..111  -> sp+202..233
    w[154:162] = bytes(w[32:40])        # sp+112..119 -> sp+234..241
    w[162:166] = A[8:12]                # lwl/lwr 264 -> swl/swr 242
    w[166:168] = A[12:14]               # lh 268      -> sh 246
    return bytes(w)


def derive_k1(ata24, four, img=None):
    img = img or Image(default_elf())
    c = constants(img, build_for(img)["k1_consts"])
    w = _w_k1(ata24, four)
    rk = cbc_enc(w[:128], c[2], c[3])
    out = engine(img, w, rk, ata24 + bytes(8), c[4], c[0], c[1])
    return out[136:168]


def derive_k2(block128, ata24, four, img=None):
    img = img or Image(default_elf())
    c = constants(img, build_for(img)["k2_consts"])
    w = _w_k2(block128, ata24, four)
    rk = cbc_enc(block128, c[2], c[3])
    out = engine(img, w, rk, ata24 + bytes(8), c[4], c[0], c[1])
    return out[136:168]


# --- known answers, captured from a running PCSX2 session --------------------
CAPTURES = [
    dict(name="pcsx2 material",
         ata24=bytes.fromhex("0000000100001a01") + bytes(16),
         four=bytes.fromhex("6cfd1b78"),
         k1=bytes.fromhex("5020d8f77e5473c9c2f69b4e1f3a81e0"
                          "87bb1068cdd367415075dc300e1dbf7b"),
         k2=bytes.fromhex("ccf6e26672e700ecacc93970c1959c66"
                          "0590598dcf65a1dd9197d54e57f7bb1d")),
    dict(name="forced zero material",
         ata24=bytes(24), four=bytes(4), k1=None,
         k2=bytes.fromhex("d04043faa7e6bb180261f733910ec59f"
                          "c3c3d49db4a6f06ad4576bcb5cfea074")),
]


def selftest(elf=None):
    img = Image(elf or default_elf())
    ok = True
    for cap in CAPTURES:
        if cap["k1"] is None:
            continue
        got = derive_k1(cap["ata24"], cap["four"], img)
        good = got == cap["k1"]
        ok &= good
        print("  K1 %-22s %s" % (cap["name"], "MATCH" if good else "no"))
        if not good:
            print("      want %s" % cap["k1"].hex())
            print("      got  %s" % got.hex())
    print("  note: only K1 has a known answer here; derive_k2 is not covered "
          "by this selftest.")
    return 0 if ok else 1


def checkbuilds():
    """Verify every build's jump table against its own handler addresses, and
    that the constant blocks agree with the JP reference. Self-verifying: a
    wrong address fails on the first table entry."""
    ref = None
    ok = True
    for name in BUILDS:
        path = os.path.join(os.path.dirname(ELF) if ELF else HERE, name)
        if not os.path.exists(path):
            print("  %-14s executable not found, skipped" % name)
            continue
        img = Image(path)
        b = BUILDS[name]
        handlers = {b["ata_dec"], b["enc"], b["ata_enc"], b["dec"]}
        tbl = [img.word(b["jump_table"] + 4 * i) for i in range(8)]
        good = all(w in handlers for w in tbl)
        use_build(name)
        blob = b"".join(constants(img, K1_CONSTS) + constants(img, K2_CONSTS))
        if ref is None:
            ref, refname = blob, name
            same = "(reference)"
        else:
            same = "identical to %s" % refname if blob == ref else "differs"
        print("  %-14s jump table %-4s   constants %s"
              % (name, "OK" if good else "BAD", same))
        ok &= good
    use_build("SLPS_202.00")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--consts", action="store_true", help="dump the ELF constants")
    ap.add_argument("--elf", metavar="PATH",
                    help="read constants from this executable instead of the "
                         "JP disc's; the build is auto-detected")
    ap.add_argument("--check-builds", action="store_true",
                    help="verify every known build's addresses against its own "
                         "executable")
    args = ap.parse_args()
    if args.check_builds:
        return checkbuilds()
    path = args.elf or default_elf()
    img = Image(path)
    if args.elf:
        name = detect_build(img)
        if name is None:
            raise SystemExit("%s: no known build's jump table is present; its "
                             "addresses have to be added to BUILDS" % path)
        use_build(name)
        print("build: %s" % name)
    if args.consts:
        for name, base in (("K1 0x001b3758", K1_CONSTS), ("K2 0x001b33f0", K2_CONSTS)):
            c = constants(img, base)
            print("%s @ 0x%08x" % (name, base))
            for lbl, v in zip(("final key", "final iv ", "rkgen key", "rkgen iv ",
                               "program  "), c):
                print("   %s %s" % (lbl, v.hex(" ")))
            print("   order    %s" % _order(c[4]))
    if args.selftest:
        return selftest(path)
    return 0


def _order(prog):
    i, seq = prog[0], []
    while i < 8:
        seq.append(i)
        if i == 0:
            break
        i = prog[i]
    return ",".join(str(x) for x in seq)


if __name__ == "__main__":
    sys.exit(main())

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
"""Offline model of the `__net` record's key schedule (Sys1_driver, IOP side).

The 4 bytes the bulk key needs are the first 4 of a 20-byte record stored in the
`__net` partition. The record is encrypted with a key derived on the IOP by
Sys1_driver's fno-459 handler:

    0x00000d94(cmd, buf+4)      the ATA IDENTIFY call
    0x000002dc(buf+4)           sanitise: erase everything except bytes 64..71
                                and 80..95 of the reply
    0x0000034c(buf+196)         write the two 8-char APA passwords (a fixed
                                byte chain, identical on every console)
    0x00000940(buf+212, buf+84) derive a 32-byte key from bytes 84..99
    0x00000684(buf+132, 7, buf+212, 32)  turn that key into a 7-entry program

Key and program are functions of the 16 bytes at reply[84..99] alone. Those
bytes are zero under PCSX2 and differ on real hardware, so a record written on
one console does not decrypt on another.

`--selftest` checks the model against a key, program and decode captured
under PCSX2:

    python3 -m playonline.lib.polrecord --selftest
    python3 -m playonline.lib.polrecord --src16 HEX32
"""
import argparse
import struct
import sys

M32 = 0xFFFFFFFF

# Known answer: PCSX2 reports 16 zero bytes at reply[84..99], and Sys1_driver
# turns them into this key and this program.
PCSX2_SRC16 = bytes(16)
PCSX2_KEY = bytes.fromhex("c59d81df39b90820b154885f72c44fe8"
                          "49ab2aff2892e86d5c2411407d19d732")
PCSX2_PROG = [1, 3, 5, 6, 2, 0, 4]


def rotl32(v, n):
    n &= 31
    return ((v << n) | (v >> (32 - n))) & M32 if n else v & M32


def derive_key(src16):
    """0x00000940: 32 bytes from a fixed chain mixed with reply[84..99].

    The second step is `B = rotl(loc[j] + B, B)`: the sum is rotated by B.
    """
    dst = [0xBBF033B8]
    for _ in range(7):
        dst.append((dst[-1] + 0x985B8CEF) & M32)
    loc = list(struct.unpack("<4I", src16))
    i0 = j = a = b = 0
    for _ in range(8):
        a = rotl32((dst[i0] + a + b) & M32, 3)
        b = (b + a) & M32
        b = rotl32((loc[j] + b) & M32, b)
        dst[i0] = a
        loc[j] = b
        i0 = 0 if i0 == 7 else i0 + 1
        j = 0 if j == 3 else j + 1
    return struct.pack("<8I", *dst)


def derive_program(key, n=7):
    """0x00000684: the linked-list permutation the EE side walks.

    Built as `prog[prev] = r; prev = r`, so the chain is followed as
    `i = prog[0]; do { round(i); i = prog[i] } while (i)`, the shape
    0x001b32c8 consumes. Zero terminates the chain and is skipped, and
    duplicates are rejected.
    """
    prog = [0] * n
    prev = cnt = 0
    for i in range(len(key)):
        if cnt >= n - 1:
            break
        r = key[i] % n
        if r and r not in prog:
            prog[prev] = r
            prev = r
            cnt += 1
    return prog


# --- the EE side: 0x001b2280 ----------------------------------------------
# A selector, run once per element of the program's chain.  `s3` starts at the
# index of the chain's terminating zero and walks the chain backwards
# (repeatedly finding the predecessor), so the passes run in reverse chain
# order.  `s3` picks one of six DES cascades from the table at 0x00205f70,
# each taking its keys from fixed 8-byte slots of the 32-byte key (call sites
# 0x001b2380..0x001b2440).  Entries are ((key slots), IV slot or None):
CASCADES = {
    1: ((0, 1, 3), 2),      # 0x001b7728  3-key CBC
    2: ((0, 3), 1),         # 0x001b79c8  2-key CBC
    3: ((0, 2, 1), None),   # 0x001b7268  3-key ECB
    4: ((0, 3), None),      # 0x001b73f0  2-key ECB
    5: ((0,), 1),           # 0x001b6eb0  1-key CBC
    6: ((0,), None),        # 0x001b6d08  1-key ECB, plain DES; 0x001b1028 uses
}                           # the same call to deobfuscate the module's strings


# When 0x001b1e20 rejects the program, 0x001b2280 skips the table entirely and
# runs one 3-key CBC pass with a different key layout (0x001b22d4).
FALLBACK = ((0, 1, 2), 3)


def valid_program(prog, n=7):
    """0x001b1e20: every entry < n, and the chain from prog[0] takes exactly
    n-1 steps and terminates at 0.  Most random keys fail this."""
    v = prog[0]
    if v >= n:
        return False
    if v == 0:
        return False
    steps = 1
    while steps < n:
        v = prog[v]
        if v >= n:
            return False
        if v == 0:
            break
        steps += 1
    return steps == n - 1 and v == 0


def pass_order(prog):
    """The `s3` values, in the order 0x001b2280 dispatches them.

    s3 starts at the index of the chain's terminating zero and then walks the
    chain backwards, so the passes run in reverse chain order.  Returns None
    when the program is invalid, meaning the fallback cascade is used instead.
    """
    if not valid_program(prog):
        return None
    a = 1
    while prog[a]:
        a += 1
    s3, order = a, []
    while s3:
        order.append(s3)
        if s3 == prog[0]:
            break
        s3 = prog.index(s3)
    return order


def decode(record, key32, nbytes=None):
    """Decrypt a record, optionally only its first `nbytes`.

    Every pass is an ECB or CBC decrypt, where output block i depends only on
    input blocks <= i.  The first N bytes of the plaintext (a multiple of 8)
    can therefore be produced from the first N bytes of the record alone.
    """
    return _decode(record if nbytes is None else record[:nbytes], key32)


def _decode(record, key32):
    """Decrypt a `__net` record with the key Sys1_driver derived.

    The two-key cascade is `D(k1) E(k2) D(k1)`, ordinary two-key 3DES. The
    three-key cascade is `D(k3) E(k2) D(k1)` with k1..k3 in call-site order,
    so the last key is applied first. Both are confirmed against a known
    input/output pair.
    """
    from Crypto.Cipher import DES

    slot = [key32[i:i + 8] for i in (0, 8, 16, 24)]
    ciph = [DES.new(s, DES.MODE_ECB) for s in slot]
    order = pass_order(derive_program(key32))
    steps = [CASCADES[s] for s in order] if order else [FALLBACK]
    buf = record
    for idx, iv_slot in steps:
        c = [ciph[i] for i in idx]
        # ECB is per-block, so each DES layer runs over the whole buffer in
        # one library call.
        if len(c) == 1:
            p = c[0].decrypt(buf)
        elif len(c) == 2:
            p = c[0].decrypt(c[1].encrypt(c[0].decrypt(buf)))
        else:
            p = c[0].decrypt(c[1].encrypt(c[2].decrypt(buf)))
        if iv_slot is not None:
            prev = slot[iv_slot] + buf[:-8]          # IV then the ciphertext
            p = bytes(x ^ y for x, y in zip(p, prev))
        buf = p
    return buf


def encode(plain, key32):
    """The inverse of `decode`: encrypt a plaintext into a `__net` record.

    A drive built by this package has no record, and an installed boot
    container's key is `polkey.derive_k1(ata24, four)` with `four` read from
    the record. The installer writes both, so `four` can be any value as long
    as the two agree.

    Every decode pass is `CASCADE_DEC` then, for the CBC ones, an XOR against
    `slot[iv] || ciphertext[:-8]`. Inverting a pass is therefore

        ECB:  c = CASCADE_ENC(p)
        CBC:  c_i = CASCADE_ENC(p_i XOR c_{i-1}),  c_-1 = slot[iv]

    and the passes run in the opposite order. `CASCADE_DEC` is
    `D[idx0] . E[idx1] . D[idx-1]`, so `CASCADE_ENC` is `E[idx-1] . D[idx1] . E[idx0]`.
    """
    from Crypto.Cipher import DES

    slot = [key32[i:i + 8] for i in (0, 8, 16, 24)]
    ciph = [DES.new(s, DES.MODE_ECB) for s in slot]
    order = pass_order(derive_program(key32))
    steps = [CASCADES[s] for s in order] if order else [FALLBACK]

    def cascade_enc(block, idx):
        c = [ciph[i] for i in idx]
        if len(c) == 1:
            return c[0].encrypt(block)
        if len(c) == 2:
            return c[0].encrypt(c[1].decrypt(c[0].encrypt(block)))
        return c[2].encrypt(c[1].decrypt(c[0].encrypt(block)))

    buf = plain
    for idx, iv_slot in reversed(steps):
        if iv_slot is None:
            buf = cascade_enc(buf, idx)
        else:
            prev = slot[iv_slot]
            out = bytearray()
            for i in range(0, len(buf) - 7, 8):
                blk = bytes(x ^ y for x, y in zip(buf[i:i + 8], prev))
                prev = cascade_enc(blk, idx)
                out += prev
            buf = bytes(out)
    return buf


def mint(four, identity=b"\0" * 8, size=512, filler=b"\0"):
    """A record plaintext carrying `four`, in the shape the console expects.

    Layout: `four` at [:4], an 8-byte console identity at [4:12], and zero at
    [12:20], which readers use to recognise a good decrypt. Nothing past [20]
    is known to be checked, so it is filler.
    """
    if len(four) != 4:
        raise ValueError("four must be 4 bytes")
    if len(identity) != 8:
        raise ValueError("identity must be 8 bytes")
    body = bytes(four) + bytes(identity) + bytes(8)
    return body + filler * (size - len(body))


def chain(prog):
    """The chain's visiting order, for display."""
    i, seq = prog[0], []
    while i and i not in seq:
        seq.append(i)
        i = prog[i]
    return seq + [0]


def selftest():
    key = derive_key(PCSX2_SRC16)
    prog = derive_program(key)
    ok = True
    for label, got, want in (("key ", key.hex(), PCSX2_KEY.hex()),
                             ("prog", prog, PCSX2_PROG)):
        good = got == want
        ok &= good
        print("  %s %s" % (label, "MATCH" if good else "no"))
        if not good:
            print("      want %s" % (want,))
            print("      got  %s" % (got,))
    print("  order %s   passes %s"
          % (",".join(str(x) for x in chain(prog)),
             ",".join(str(x) for x in pass_order(prog))))
    # The console's own decode of an all-zero record under that key.
    want = bytes.fromhex("6cfd1b782734f63abe194ee857cc1eba"
                         "2ed5404e3ec381256ad6c495b2e8dded")
    got = decode(bytes(512), key)[:32]
    good = got == want
    ok &= good
    print("  decode %s" % ("MATCH" if good else "no"))
    if not good:
        print("      want %s\n      got  %s" % (want.hex(), got.hex()))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--src16", help="32 hex digits: reply[84..99]")
    args = ap.parse_args()
    if args.src16:
        key = derive_key(bytes.fromhex(args.src16))
        prog = derive_program(key)
        print("key  %s" % key.hex())
        print("prog %s   order %s" % (prog, ",".join(str(x) for x in chain(prog))))
    if args.selftest:
        return selftest()
    return 0


if __name__ == "__main__":
    sys.exit(main())

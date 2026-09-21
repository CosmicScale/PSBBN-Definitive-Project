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
"""PEX container codec: the PlayOnline module compression, both directions.

A drive in plaintext mode holds the decompressed module (`MWo3` header), which
is `decompress()` of the PEX container that a universal `.pex.enc` unwraps to.

Header, 16 bytes, then an LZSS bitstream:

    +0x00  'PEX\\0'
    +0x04  u32 plaintext length
    +0x08  8 bytes, zero
    +0x10  bitstream

Bits are read LSB first, and a multi-bit field is assembled LSB first as
well: bit `i` of a field comes from bit `(pos & 7)` of byte `pos >> 3`, with
`pos` counting up. A 12-bit field is therefore neither big-endian nor a
conventional MSB-first LZSS field.

Tokens: a 0 flag bit is followed by an 8-bit literal. A 1 flag bit is
followed by a 12-bit window index and a 4-bit length, and copies
`length + 2` bytes (2 to 17). The window is the 4096 bytes before the write
cursor, and the output is treated as if it were preceded by 4096 zero bytes,
so the effective back-distance is `0x1000 - index`. Copies may overlap.

    python3 -m playonline.lib.pexcodec FILE [FILE...]   # decompress to FILE.out
    python3 -m playonline.lib.pexcodec -t FILE          # print as UTF-16LE text
"""
import struct
import sys

MAGIC = b"PEX\0"
HEADER = 0x10
WINDOW = 0x1000
MIN_MATCH = 2


def is_pex(data):
    return len(data) >= HEADER and data[:4] == MAGIC


def plaintext_len(data):
    """The u32 plaintext length at +4, which pex_size (0x03804350) reads."""
    return struct.unpack_from("<I", data, 4)[0]


class _Bits:
    """Bit reader (0x03804300): LSB-first within the byte and within the value."""

    __slots__ = ("src", "pos")

    def __init__(self, src):
        self.src = src
        self.pos = 0

    def get(self, n):
        r = 0
        src, pos = self.src, self.pos
        for i in range(n):
            r |= ((src[pos >> 3] >> (pos & 7)) & 1) << i
            pos += 1
        self.pos = pos
        return r


def decompress(data):
    """PEX -> plaintext bytes. Raises ValueError if `data` is not a PEX file."""
    if not is_pex(data):
        raise ValueError("not a PEX container")
    want = plaintext_len(data)
    bits = _Bits(data[HEADER:])
    out = bytearray(WINDOW)                 # the zero window
    end = want + WINDOW
    while len(out) < end:
        if bits.get(1) == 0:
            out.append(bits.get(8))
        else:
            off = bits.get(12)
            n = bits.get(4) + MIN_MATCH
            p = len(out) - WINDOW
            for _ in range(n):
                out.append(out[off + p])
                p += 1
    return bytes(out[WINDOW:end])           # without the zero window


#: Longest run a single match token can encode: getbits(4) + MIN_MATCH.
MAX_MATCH = 15 + MIN_MATCH
#: How far back a match may reach. `off` is 12 bits and the source index is
#: `off + emitted`, so distance = WINDOW - off, i.e. 1..WINDOW.
MAX_DIST = WINDOW
#: Hash-chain cap. Long chains buy very little on files this size.
_CHAIN = 64


def compress(payload, match=True):
    """Produce a PEX the Viewer accepts.

    A literal costs 9 bits and a match costs 17 (1 + 12 + 4) for up to
    MAX_MATCH bytes, so a run of 3 or more repeated bytes pays for itself.
    Matching is greedy over a 3-byte hash chain, which is not optimal but
    gives output close in size to Square Enix's.

    `match=False` emits a literals-only stream, for tests.
    """
    bits = bytearray()
    acc = [0, 0]                            # [value, nbits]

    def put(v, n):
        for i in range(n):
            if acc[1] == 8:
                bits.append(acc[0]); acc[0] = 0; acc[1] = 0
            acc[0] |= ((v >> i) & 1) << acc[1]
            acc[1] += 1

    n = len(payload)
    chains = {}                             # 3-byte key -> [positions, newest last]
    p = 0
    while p < n:
        best_len, best_dist = 0, 0
        key = bytes(payload[p:p + 3])
        if match and len(key) == 3:
            cands = chains.get(key)
            if cands:
                # Newest first: nearer matches are no cheaper here (the offset
                # is a fixed 12 bits) but they keep the chain scan short.
                for cand in reversed(cands[-_CHAIN:]):
                    dist = p - cand
                    if dist > MAX_DIST:
                        break
                    ln = 0
                    limit = min(MAX_MATCH, n - p)
                    # Overlapping copies are legal: the decoder advances its
                    # read cursor with the write cursor, and comparing inside
                    # `payload` models that exactly.
                    while ln < limit and payload[cand + ln] == payload[p + ln]:
                        ln += 1
                    if ln > best_len:
                        best_len, best_dist = ln, dist
                        if ln == MAX_MATCH:
                            break
        if best_len >= 3:
            put(1, 1)
            put(WINDOW - best_dist, 12)
            put(best_len - MIN_MATCH, 4)
            step = best_len
        else:
            put(0, 1)
            put(payload[p], 8)
            step = 1
        # Register every position, including those covered by a match.
        for i in range(p, p + step):
            k = bytes(payload[i:i + 3])
            if len(k) == 3:
                chains.setdefault(k, []).append(i)
        p += step
    if acc[1]:
        bits.append(acc[0])
    return MAGIC + struct.pack("<I", len(payload)) + b"\0" * 8 + bytes(bits)


def _main(argv):
    args = [a for a in argv if not a.startswith("-")]
    as_text = "-t" in argv or "--text" in argv
    if not args:
        print(__doc__.strip().splitlines()[0])
        return 2
    for path in args:
        raw = open(path, "rb").read()
        if not is_pex(raw):
            print(f"{path}: not a PEX container ({raw[:4]!r})")
            continue
        out = decompress(raw)
        ok = len(out) == plaintext_len(raw)
        print(f"{path}\n  {len(raw)}B -> {len(out)}B "
              f"(declared {plaintext_len(raw)}, {'ok' if ok else 'mismatch'}) "
              f"ratio {len(out) / max(1, len(raw)):.2f}x")
        if as_text:
            sys.stdout.write(out.decode("utf-16-le", "replace"))
        else:
            with open(path + ".out", "wb") as f:
                f.write(out)
            print(f"  wrote {path}.out")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))

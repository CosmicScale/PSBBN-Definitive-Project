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
"""Build the US `dnasload` KELF's runtime patcher.

The `dnasload` stub decompresses its payload from 0x00100500 to 0x00200000 and
calls FlushCache before entering it:

    0x001001b0  jal 0x001001f8   decompressor
    0x001001b8  jal 0x001001e0   FlushCache (this call is redirected)
    0x001001cc  jalr ra, at      enter the payload

The redirected `jal` lands in 17 unused words at 0x001004b8, which store the
patch words into the decompressed payload and then jump to FlushCache, so the
stores happen before the cache flush. The gap ends at the compressed blob at
0x00100500. A patch set that needs more room would have to use a table
walker, with its (address, value) pairs placed after the compressed blob.
File offset to VA is +0xFFD80. The JP stub differs and needs its own constants.

Named patches, applied to the decompressed payload:

    console-binding  0x0020b938  the comparison against the MechaCon id,
                                 stubbed to `jr ra; li v0,1` (1 means match)
    record           0x0020b6a8  the verdict on the __net record, stubbed the
                                 same way. It is a policy gate; the key bytes
                                 are read separately on the IOP side.
    digest-check     0x002038a4  the RSA-signed SHA-1 of a container's payload
                                 at +640. Needed only for an edited container:
                                 the digest covers the padded payload, so a
                                 re-encrypted container still matches.
    booterror-hang   0x00201314  `b .`, so a failure parks where it would
                                 otherwise power off. Diagnostic only.

    python3 -m playonline.lib.ci_usdnaspatch --base US-DNASLOAD.kelf --out OUT.kelf \\
        --named console-binding --named record --named digest-check
"""
import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

BASE = None
HOOK_FILEOFF = 0x438            # VA 0x001001b8, the FlushCache jal
GAP_FILEOFF = 0x738             # VA 0x001004b8
GAP_WORDS = 17                  # 68 bytes, bounded by the blob at 0x00100500
FLUSHCACHE = 0x001001E0
V2F = 0xFFD80                   # VA = file + this

JR_RA = 0x03E00008
LI_V0_1 = 0x24020001
SPIN = 0x1000FFFF

NAMED = {
    # (address, word) pairs, applied to the decompressed payload
    "console-binding": [(0x0020B938, JR_RA), (0x0020B93C, LI_V0_1)],
    "record":          [(0x0020B6A8, JR_RA), (0x0020B6AC, LI_V0_1)],
    "digest-check":    [(0x002038A4, 0x00000000)],
    "booterror-hang":  [(0x00201314, SPIN)],
}


def _jal(target):
    return 0x0C000000 | ((target >> 2) & 0x03FFFFFF)


def assemble(patches):
    """Straight-line stores, grouped by lui page so one base serves several.

    The displacement of `sw` is signed, so an address at or above `xxxx8000`
    is reached from a page base of `hi+1` with a negative offset
    (0x0020b938 is lui 0x0021, offset -18120).
    """
    words = []
    cur_base = None
    cur_val = None
    for addr, val in patches:
        page = (addr + 0x8000) >> 16          # round to the nearest lui page
        off = addr - (page << 16)
        assert -0x8000 <= off < 0x8000
        if page != cur_base:
            words.append(0x3C030000 | page)                 # lui v1, page
            cur_base = page
            cur_val = None
        if val == 0:
            words.append(0xAC600000 | (off & 0xFFFF))       # sw zero, off(v1)
            continue
        if val != cur_val:
            words.append(0x3C020000 | (val >> 16))          # lui v0, hi
            if val & 0xFFFF:
                words.append(0x34420000 | (val & 0xFFFF))   # ori v0, v0, lo
            cur_val = val
        words.append(0xAC620000 | (off & 0xFFFF))           # sw v0, off(v1)
    words.append(0x08000000 | ((FLUSHCACHE >> 2) & 0x03FFFFFF))  # j FlushCache
    words.append(0x00000000)                                  # delay slot
    return words


def build(named, base=BASE):
    data = bytearray(open(base, "rb").read())
    patches = []
    for n in named:
        if n not in NAMED:
            raise SystemExit("unknown patch %r (have %s)" % (n, ", ".join(NAMED)))
        patches += NAMED[n]
    # Sort by page and then by value: identical values share one lui/ori pair,
    # which keeps the patcher inside 17 words.
    patches.sort(key=lambda p: ((p[0] + 0x8000) >> 16, p[1], p[0]))
    words = assemble(patches)
    if len(words) > GAP_WORDS:
        raise SystemExit("patcher needs %d words, the gap holds %d -- switch to "
                         "the table walker described in the docstring"
                         % (len(words), GAP_WORDS))
    struct.pack_into("<I", data, HOOK_FILEOFF, _jal(GAP_FILEOFF + V2F))
    for i, w in enumerate(words):
        struct.pack_into("<I", data, GAP_FILEOFF + i * 4, w)
    return bytes(data), words


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--named", action="append", default=[],
                    help="one of: %s" % ", ".join(NAMED))
    args = ap.parse_args()
    if not args.named:
        raise SystemExit("pass at least one --named")
    data, words = build(args.named, args.base)
    print("patcher (%d/%d words) at VA 0x001004b8:" % (len(words), GAP_WORDS))
    for i, w in enumerate(words):
        print("    %#010x  %08x" % (0x001004B8 + i * 4, w))
    old = open(args.base, "rb").read()
    if len(data) != len(old):
        raise SystemExit("length changed -- polpfspatch needs the same size")
    open(args.out, "wb").write(data)
    print("wrote %s (%d bytes, same length as the base)" % (args.out, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

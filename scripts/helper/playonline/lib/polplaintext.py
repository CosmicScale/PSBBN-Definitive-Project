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
"""Enable the PS2 PlayOnline Viewer's built-in plaintext module mode.

The Viewer carries a development switch that makes every loader stage open
plaintext `.pex` modules instead of the drive-keyed `.pex.enc`. The flag word
at boot ELF file offset 0x110c is copied to the global at 0x00823d84; when it
is set the loader skips both the ".enc" suffix and the decrypt call at
0x00202638, and sets bit 3 of the flags that pol.pex and polapp.pex read. The
console-ID binding check (0x00215738) is only reached through the decrypt
entry, so it is never run in this mode and needs no patch of its own.

Two words are patched:

  1. file 0x110c: 0x00000000 -> 0x00000021, which sets the flag. The word is
     the delay slot of the stub's `j 0x00800000` and is executed, so it must
     be a harmless non-zero instruction: `addu zero, zero, zero`.
  2. va 0x008004d0 (1.13.01f; 0x008004e8 in 1.18.15f):
     `beq v1,zero,<gate+0x10>` -> nop, so the loader ignores the boot source.
     Booting from `hdd0:` sets the boot-source word to 0, which otherwise
     forces the encrypted path. The branch is patched and the variable left
     alone because polapp reads flags bits 0..1 at 0x00a00074 for device
     selection.

Any build whose words at these sites differ is refused.

    python3 -m playonline.lib.polplaintext IN.elf --out OUT.elf
    python3 -m playonline.lib.polplaintext IN.elf --check      # report only
    python3 -m playonline.lib.polplaintext OUT.elf --revert --out ORIG.elf
"""
import argparse
import os
import shutil
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from .mips import disasm                                        # noqa: E402

# Flag word of the decrypted HDD boot ELF, as a file offset.
FLAG_OFF = 0x110C                  # va 0x0010010c
FLAG_ORIG = 0x00000000
FLAG_NEW = 0x00000021              # addu zero, zero, zero

GATE_ORIG = 0x10600003             # beq v1, zero, <gate+0x10>
GATE_NEW = 0x00000000              # nop

# Side effect of setting the flag: `bne v0,zero` at 0x00800064 is taken and
# the block at 0x0080006c..0x00800084 is skipped. That block stubs the boot
# ELF's own printf (0x001f0688) to `jr ra; v0 = 0`, so a retail boot disables
# debug logging and plaintext mode leaves it on. This is harmless. The
# --stub-printf option writes the same stub into the file.
PRINTF_ORIG = (0x27BDFF70, 0x3C0C0023)     # addiu sp,sp,-144 / lui t4,0x23
PRINTF_STUB = (0x03E00008, 0x0000102D)     # jr ra / daddu v0, zero, zero

# Per-build offsets. The loader stub at 0x00800000 was recompiled between
# 1.13.01f and 1.18.15f: the gate moved +0x18, `lw v0` became `lw a0` at
# 0x0080004c, and printf moved +0x40. The flag word at file 0x110c, the flag
# global 0x00823d84, the boot-source word 0x00823d8c and the decrypt entry
# 0x00202638 are the same in both, so one patch shape covers both builds.
# A build is selected only when every context word matches; an unknown build
# matches none and is refused.
BUILDS = (
    dict(
        name="1.13.01f (2004-era HDD install)",
        gate_va=0x008004D0,
        printf_va=0x001F0688,
        context=[
            (0x00100108, 0x08200000, "j 0x00800000 (the flag word is its delay slot)"),
            (0x0080004C, 0x8C62010C, "lw v0, 268(v1)  -- reads the flag word"),
            (0x008004CC, 0x8EA33D8C, "lw v1, 15756(s5) -- boot-source word"),
            (0x008004D8, 0x8C623D84, "lw v0, 15748(v1) -- the flag global"),
            (0x00800564, 0x1640000F, "bne s2, zero -- skips the decrypt call"),
            (0x00800578, 0x0C08098E, "jal 0x00202638 -- the decrypt entry"),
        ],
    ),
    dict(
        name="1.18.15f (20120610_A)",
        gate_va=0x008004E8,
        printf_va=0x001F06C8,
        context=[
            (0x00100108, 0x08200000, "j 0x00800000 (the flag word is its delay slot)"),
            (0x0080004C, 0x8C64010C, "lw a0, 268(v1)  -- reads the flag word"),
            (0x008004E4, 0x8EA33D8C, "lw v1, 15756(s5) -- boot-source word"),
            (0x008004F0, 0x8C623D84, "lw v0, 15748(v1) -- the flag global"),
            (0x0080057C, 0x1640000F, "bne s2, zero -- skips the decrypt call"),
            (0x00800590, 0x0C08098E, "jal 0x00202638 -- the decrypt entry"),
        ],
    ),
)


def seg_map(b):
    e_phoff, = struct.unpack_from("<I", b, 28)
    e_phentsize, e_phnum = struct.unpack_from("<HH", b, 42)
    segs = []
    for i in range(e_phnum):
        p_type, p_off, p_vaddr, _, p_filesz, _, _, _ = struct.unpack_from(
            "<IIIIIIII", b, e_phoff + i * e_phentsize)
        if p_type == 1 and p_filesz:
            segs.append((p_vaddr, p_off, p_filesz))
    return segs


def off_of(segs, va):
    for v, o, sz in segs:
        if v <= va < v + sz:
            return o + (va - v)
    return None


def word_at(b, off):
    return struct.unpack_from("<I", b, off)[0]


def show(b, off, va, label):
    w = word_at(b, off)
    txt, _ = disasm(w, va)
    print("    0x%08x (file 0x%06x)  %08x  %-30s %s" % (va, off, w, txt, label))


def identify(b, segs):
    """Return the BUILDS entry whose every context word matches, else None."""
    for build in BUILDS:
        for va, expect, _ in build["context"]:
            o = off_of(segs, va)
            if o is None or word_at(b, o) != expect:
                break
        else:
            return build
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("--out")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="apply even if the fingerprint does not match")
    ap.add_argument("--stub-printf", action="store_true",
                    help="also bake in the printf stub retail applies at "
                         "startup (plaintext mode otherwise leaves logging on)")
    a = ap.parse_args()

    with open(a.elf, "rb") as f:
        b = bytearray(f.read())

    if b[:4] != b"\x7fELF":
        sys.exit("not an ELF: pass the decrypted boot ELF (section 2 of the "
                 "boot container)")

    segs = seg_map(b)
    build = identify(b, segs)
    if build is None:
        # Report against the newest build so the output shows what differed.
        build = BUILDS[-1]
        matched = False
    else:
        matched = True
    GATE_VA, PRINTF_VA = build["gate_va"], build["printf_va"]
    CONTEXT = build["context"]
    gate_off = off_of(segs, GATE_VA)
    if gate_off is None:
        sys.exit("va 0x%08x is not in any loadable segment" % GATE_VA)
    print("  build: %s" % (build["name"] if matched else
                           "unrecognised (closest report: %s)" % build["name"]))

    want_flag = FLAG_NEW if a.revert else FLAG_ORIG
    want_gate = GATE_NEW if a.revert else GATE_ORIG
    new_flag = FLAG_ORIG if a.revert else FLAG_NEW
    new_gate = GATE_ORIG if a.revert else GATE_NEW

    print("=" * 72)
    print("current state")
    print("=" * 72)
    show(b, FLAG_OFF, 0x0010010C, "plaintext flag word")
    show(b, gate_off, GATE_VA, "boot-source gate")
    print()
    print("  context:")
    ok = True
    for va, expect, label in CONTEXT:
        o = off_of(segs, va)
        got = word_at(b, o) if o is not None else None
        good = got == expect
        ok &= good
        print("    %s 0x%08x  %08x  %s" %
              ("OK  " if good else "BAD ", va, got if got is not None else 0, label))

    ok &= matched
    fp = (word_at(b, FLAG_OFF) == want_flag and word_at(b, gate_off) == want_gate)
    print()
    print("  fingerprint: %s" % ("MATCH" if (fp and ok) else "MISMATCH"))
    if a.check:
        return
    if not (fp and ok) and not a.force:
        sys.exit("refusing to patch: this is not the build these offsets were "
                 "derived from (use --force only if you know why)")

    if not a.out:
        sys.exit("--out is required (this tool never patches in place)")
    if os.path.exists(a.out):
        sys.exit("refusing to overwrite an existing %s" % a.out)

    struct.pack_into("<I", b, FLAG_OFF, new_flag)
    struct.pack_into("<I", b, gate_off, new_gate)

    p_off = off_of(segs, PRINTF_VA)
    if a.stub_printf and not a.revert:
        cur = (word_at(b, p_off), word_at(b, p_off + 4))
        if cur != PRINTF_ORIG and not a.force:
            sys.exit("printf prologue at 0x%08x does not match this build" % PRINTF_VA)
        struct.pack_into("<I", b, p_off, PRINTF_STUB[0])
        struct.pack_into("<I", b, p_off + 4, PRINTF_STUB[1])
    if a.revert and (word_at(b, p_off), word_at(b, p_off + 4)) == PRINTF_STUB:
        struct.pack_into("<I", b, p_off, PRINTF_ORIG[0])
        struct.pack_into("<I", b, p_off + 4, PRINTF_ORIG[1])

    with open(a.out, "wb") as f:
        f.write(b)

    print()
    print("=" * 72)
    print("wrote %s (%d bytes)" % (a.out, len(b)))
    print("=" * 72)
    nb = bytearray(open(a.out, "rb").read())
    show(nb, FLAG_OFF, 0x0010010C, "plaintext flag word")
    show(nb, gate_off, GATE_VA, "boot-source gate")
    show(nb, p_off, PRINTF_VA, "printf (stubbed = logging off)")
    print()
    print("  mode: %s" % ("encrypted (reverted)" if a.revert else "plaintext"))
    print("  debug logging: %s" %
          ("off (stub baked in)" if a.stub_printf and not a.revert
           else "on -- retail stubs it at startup; plaintext mode does not"))


if __name__ == "__main__":
    main()

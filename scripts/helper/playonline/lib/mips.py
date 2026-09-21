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
"""Minimal MIPS32/R5900 disassembler and address cross-reference finder.

Enough to read Metrowerks-compiled PS2 code: loads and stores, ALU, branches,
jumps, and the lui/addiu (or lui/ori) pairs that build 32-bit constants.
"""
import struct

REG = ["zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
       "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
       "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
       "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"]

SPECIAL = {
    0x00: "sll", 0x02: "srl", 0x03: "sra", 0x04: "sllv", 0x06: "srlv", 0x07: "srav",
    0x08: "jr", 0x09: "jalr", 0x0C: "syscall", 0x0D: "break", 0x0F: "sync",
    0x10: "mfhi", 0x11: "mthi", 0x12: "mflo", 0x13: "mtlo",
    0x18: "mult", 0x19: "multu", 0x1A: "div", 0x1B: "divu",
    0x20: "add", 0x21: "addu", 0x22: "sub", 0x23: "subu",
    0x24: "and", 0x25: "or", 0x26: "xor", 0x27: "nor",
    0x2A: "slt", 0x2B: "sltu",
    0x0A: "movz", 0x0B: "movn",
    0x2D: "daddu", 0x2F: "dsubu",
    0x38: "dsll", 0x3A: "dsrl", 0x3B: "dsra", 0x3C: "dsll32", 0x3E: "dsrl32", 0x3F: "dsra32",
}

OPC = {
    0x02: "j", 0x03: "jal", 0x04: "beq", 0x05: "bne", 0x06: "blez", 0x07: "bgtz",
    0x08: "addi", 0x09: "addiu", 0x0A: "slti", 0x0B: "sltiu",
    0x0C: "andi", 0x0D: "ori", 0x0E: "xori", 0x0F: "lui",
    0x14: "beql", 0x15: "bnel", 0x16: "blezl", 0x17: "bgtzl",
    0x19: "daddiu",
    0x20: "lb", 0x21: "lh", 0x22: "lwl", 0x23: "lw", 0x24: "lbu", 0x25: "lhu",
    0x26: "lwr", 0x27: "lwu",
    0x28: "sb", 0x29: "sh", 0x2A: "swl", 0x2B: "sw", 0x2E: "swr",
    0x37: "ld", 0x3F: "sd",
    # Unaligned 64-bit access: Metrowerks emits ldl/ldr and sdl/sdr pairs to
    # copy 8-byte constants into unaligned stack slots.
    0x1A: "ldl", 0x1B: "ldr", 0x2C: "sdl", 0x2D: "sdr",
    0x1E: "lq", 0x1F: "sq",
    0x31: "lwc1", 0x39: "swc1", 0x36: "lqc1", 0x3E: "sqc1",
}

REGIMM = {0x00: "bltz", 0x01: "bgez", 0x10: "bltzal", 0x11: "bgezal",
          0x02: "bltzl", 0x03: "bgezl"}


def s16(v):
    return v - 0x10000 if v & 0x8000 else v


def disasm(word, pc):
    op = word >> 26
    rs = (word >> 21) & 31
    rt = (word >> 16) & 31
    rd = (word >> 11) & 31
    sa = (word >> 6) & 31
    fn = word & 63
    imm = word & 0xFFFF
    if word == 0:
        return "nop", None
    if op == 0:
        m = SPECIAL.get(fn)
        if not m:
            return f".word 0x{word:08x}", None
        if m in ("sll", "srl", "sra", "dsll", "dsrl", "dsra", "dsll32", "dsrl32", "dsra32"):
            return f"{m} {REG[rd]}, {REG[rt]}, {sa}", None
        if m in ("jr",):
            return f"jr {REG[rs]}", None
        if m in ("jalr",):
            return f"jalr {REG[rd]}, {REG[rs]}", None
        if m in ("mfhi", "mflo"):
            return f"{m} {REG[rd]}", None
        if m in ("mthi", "mtlo"):
            return f"{m} {REG[rs]}", None
        if m in ("mult", "multu", "div", "divu"):
            return f"{m} {REG[rs]}, {REG[rt]}", None
        if m in ("sllv", "srlv", "srav", "dsllv", "dsrlv", "dsrav"):
            # Variable shifts are `rd = rt <op> rs`: the value shifted is rt and
            # the count is rs, the opposite operand order to every other
            # SPECIAL, so they cannot use the generic form below.
            return f"{m} {REG[rd]}, {REG[rt]}, {REG[rs]}", None
        return f"{m} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
    if op == 0x1C:                       # MMI
        # MMI1 (fn 0x28) sa 0x18 is `paddub rd, rs, rt`. Metrowerks emits it
        # with rt=zero as a 128-bit register move. Enough of MMI is decoded to
        # follow those moves.
        if fn == 0x28 and sa == 0x18:
            if rt == 0:
                return f"move {REG[rd]}, {REG[rs]}", None
            return f"paddub {REG[rd]}, {REG[rs]}, {REG[rt]}", None
        if fn == 0x28:
            return f"mmi1.{sa:02x} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
        if fn == 0x29:
            return f"mmi3.{sa:02x} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
        if fn == 0x08:
            return f"mmi0.{sa:02x} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
        if fn == 0x09:
            return f"mmi2.{sa:02x} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
        return f"mmi.{fn:02x} {REG[rd]}, {REG[rs]}, {REG[rt]}", None
    if op == 1:
        m = REGIMM.get(rt, f"regimm{rt}")
        tgt = pc + 4 + (s16(imm) << 2)
        return f"{m} {REG[rs]}, 0x{tgt:08x}", tgt
    m = OPC.get(op)
    if not m:
        if op == 0x11:
            return f"cop1 0x{word & 0x3FFFFFF:07x}", None
        return f".word 0x{word:08x}", None
    if m in ("j", "jal"):
        tgt = (pc + 4 & 0xF0000000) | ((word & 0x3FFFFFF) << 2)
        return f"{m} 0x{tgt:08x}", tgt
    if m in ("beq", "bne", "beql", "bnel"):
        tgt = pc + 4 + (s16(imm) << 2)
        return f"{m} {REG[rs]}, {REG[rt]}, 0x{tgt:08x}", tgt
    if m in ("blez", "bgtz", "blezl", "bgtzl"):
        tgt = pc + 4 + (s16(imm) << 2)
        return f"{m} {REG[rs]}, 0x{tgt:08x}", tgt
    if m == "lui":
        return f"lui {REG[rt]}, 0x{imm:04x}", None
    if op in (0x08, 0x09, 0x0A, 0x0B, 0x19):
        return f"{m} {REG[rt]}, {REG[rs]}, {s16(imm)}", None
    if op in (0x0C, 0x0D, 0x0E):
        return f"{m} {REG[rt]}, {REG[rs]}, 0x{imm:04x}", None
    return f"{m} {REG[rt]}, {s16(imm)}({REG[rs]})", None


class Image:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.b = f.read()
        b = self.b
        e_phoff, = struct.unpack_from("<I", b, 28)
        e_phentsize, e_phnum = struct.unpack_from("<HH", b, 42)
        self.segs = []
        for i in range(e_phnum):
            p_type, p_offset, p_vaddr, _, p_filesz, _, _, _ = \
                struct.unpack_from("<IIIIIIII", b, e_phoff + i * e_phentsize)
            if p_type == 1 and p_filesz:
                self.segs.append((p_vaddr, p_offset, p_filesz))

    def off(self, va):
        for v, o, sz in self.segs:
            if v <= va < v + sz:
                return o + (va - v)
        return None

    def va(self, off):
        for v, o, sz in self.segs:
            if o <= off < o + sz:
                return v + (off - o)
        return None

    def word(self, va):
        o = self.off(va)
        return struct.unpack_from("<I", self.b, o)[0] if o is not None else None

    def cstr(self, va, maxlen=200):
        o = self.off(va)
        if o is None:
            return None
        e = self.b.find(b"\0", o, o + maxlen)
        return self.b[o:e if e > 0 else o + maxlen]

    def iter_code(self):
        """Yield (va, word) over every 4-aligned word in loadable segments."""
        for v, o, sz in self.segs:
            for i in range(0, sz - 3, 4):
                yield v + i, struct.unpack_from("<I", self.b, o + i)[0]

    def find_refs(self, target):
        """Find lui+{addiu,ori,lw,sw,lbu,...} pairs that materialise `target`.

        Metrowerks emits `lui r, %hi(x)` then an immediate op with %lo(x),
        usually adjacent but sometimes separated, so a short window after
        each lui is scanned.
        """
        hits = []
        hi_want = (target >> 16) & 0xFFFF
        lo = target & 0xFFFF
        # `ori` takes %lo unsigned, so its %hi is exact. Every other partner op
        # (addiu/daddiu/lw/sw/...) sign-extends %lo, so when %lo >= 0x8000 the
        # assembler emits %hi plus one to cancel the borrow.
        hi_signed = (hi_want + (1 if lo >= 0x8000 else 0)) & 0xFFFF
        for v, o, sz in self.segs:
            words = struct.unpack_from(f"<{sz//4}I", self.b, o)
            for i, w in enumerate(words):
                if (w >> 26) != 0x0F:
                    continue
                imm = w & 0xFFFF
                rt = (w >> 16) & 31
                if imm != hi_want and imm != hi_signed:
                    continue
                allow_ori = (imm == hi_want)
                allow_signed = (imm == hi_signed)
                for j in range(i + 1, min(i + 24, len(words))):
                    w2 = words[j]
                    op2 = w2 >> 26
                    rs2 = (w2 >> 21) & 31
                    if op2 == 0x0F and ((w2 >> 16) & 31) == rt:
                        break  # register reloaded
                    if rs2 != rt:
                        continue
                    imm2 = w2 & 0xFFFF
                    if imm2 != lo:
                        continue
                    if op2 == 0x0D and allow_ori:                 # ori, %lo unsigned
                        hits.append((v + i * 4, v + j * 4, imm2))
                        break
                    if op2 in (0x09, 0x19) and allow_signed:      # addiu / daddiu
                        hits.append((v + i * 4, v + j * 4, imm2))
                        break
                    if allow_signed and op2 in OPC and OPC[op2] in (
                            "lb", "lh", "lw", "lbu", "lhu", "lwu", "sb", "sh", "sw",
                            "ld", "sd"):
                        hits.append((v + i * 4, v + j * 4, imm2))
                        break
        return hits

    def dump(self, start, count, mark=()):
        out = []
        for k in range(count):
            va = start + k * 4
            w = self.word(va)
            if w is None:
                break
            t, _ = disasm(w, va)
            flag = " <<<" if va in mark else ""
            out.append(f"  0x{va:08x}  {w:08x}  {t}{flag}")
        return "\n".join(out)


def find_func_start(img, va, limit=600):
    """Walk back to a plausible prologue (addiu sp,sp,-N) or after a jr ra."""
    best = None
    for k in range(1, limit):
        a = va - k * 4
        w = img.word(a)
        if w is None:
            break
        # addiu sp, sp, -N
        if (w >> 26) == 0x09 and ((w >> 21) & 31) == 29 and ((w >> 16) & 31) == 29 \
                and s16(w & 0xFFFF) < 0:
            best = a
            break
        # daddiu sp, sp, -N
        if (w >> 26) == 0x19 and ((w >> 21) & 31) == 29 and ((w >> 16) & 31) == 29 \
                and s16(w & 0xFFFF) < 0:
            best = a
            break
    return best

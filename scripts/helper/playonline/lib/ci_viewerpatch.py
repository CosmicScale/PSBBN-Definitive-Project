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
"""Re-apply the Viewer-side gate patches to a drive's boot container.

An in-Viewer update replaces the boot container
(`PP.<product>.1000.POLVIEWER/<product>`) and with it every patch that lets the
Viewer run on a drive this installer built. `dnasload.elf` is not shipped by the
patch service, so the loader's own bypasses survive an update; the ones in the
boot container do not, and this re-applies them. The addresses differ per build,
so the build on the drive is detected by probing the expected original word at
each site, then the matching set is applied. An unrecognised build is reported,
and `--derive` finds the sites in it from its own instruction shapes so a new
table can be written.

The gates fall into two groups. The `.pex.enc` header decrypt opens with two:
the record check (must return 1, else -102) and the binding check (must return
positive, else -101); both are the Viewer's own copies of routines dnasload also
carries, and both must be patched. The DNAS group is separate: the poll
functions each test `state == 5`, and a dead handshake leaves state 6
(S_COM_ERROR, substatus -598, which maps to POL-1556). Every poll reaches the
same verdict function, so all polls are forced rather than trying to identify
which one runs in a given build.

    python ci_viewerpatch.py --image IMAGE.img --write
    python ci_viewerpatch.py --container FILE.bin -o OUT          # a loose file
    python ci_viewerpatch.py --elf BOOT.ELF                       # report only
    python ci_viewerpatch.py --derive BOOT.ELF                    # a new build
    python ci_viewerpatch.py --selftest                           # the tables

Editing the container breaks its slot-28 payload digest, so `polencpatch
--force` is implied. That is only safe because the loader's digest check is
NOPed (`0x002038a4` in the US dnasload, via `ci_usdnaspatch.py`). On a drive
whose `dnasload.elf` lacks that patch, an edited container fails to load.

How the sites are found (`--derive` reads these shapes, consulting no table):

  the polls       the 5/8/-6 ladder, six words no other code here matches:
                      lw    v1, 0(rX)        the DNAS status word
                      addiu v0, zero, 5
                      beq   v1, v0, +3       the site
                      addiu v0, zero, 8
                      bne   v1, v0, X
                      addiu v0, v1, -6
                  Cross-checked by string reference: each poll carries one
                  reference to the `sceDNAS1GetStatus() ERROR %d` string, as a
                  raw addiu immediate holding the low half of its address. That
                  immediate sits in the delay slot of the printf `jal`, so a
                  register tracker walks past it; this scans for the raw
                  immediate instead. The two methods must agree on the count.

  the verdict     the only place holding `addiu v0,zero,-1559` beside the
                  `lui a0,0x8000` / `ori a0,a0,0x000c` mask. Its function opens
                  `lui v0,HI / lw v0,LO(v0) / bltz v0,END`, the pair that gets
                  stubbed. Cross-checked as the call target of the `jal` each
                  poll makes on the state==5 path.

  binding, record both open with the same prologue, unique here:
                      lui   v0, HI
                      addiu sp, sp, -N
                      lw    v1, LO(v0)       a global "initialised" gate
                      addiu a0, zero, 1
                      sd    ra, N-16(sp)
                      beq   v1, a0, +3       gate == 1: carry on
                      sd    s0, N-32(sp)
                      beq   zero, zero, END
                      addiu v0, zero, -8     gate != 1: return -8
                  The binding routine goes on to run a 16-byte memcmp whose
                  result feeds a `bne v0,zero` (`jal memcmp` with `addiu
                  a2,zero,16` in the delay slot); the record routine does not.
                  That memcmp is the only thing telling the two apart. The pair
                  count is read rather than assumed: 1.05.00d carries two
                  complete copies of both routines.

Each table below was read from a decrypted boot ELF of that build:

  20031006_0   US PlayOnline disc install
  20051004_3   the last US build that ships the boot container
  1.13.01f     JP SLPS-20200
  1.05.00d     JP PlayOnline Viewer disc, POL/install/PS2/SLPS-20200 section 2,
               opened with ci_universal.py using SE's public keys (no drive)
  1.14.03      JP Dirge of Cerberus disc, same path and method

`--selftest` checks what can be checked without shipping any of Square Enix's
bytes: the shape of every row, and that no two tables can match one ELF.
"""
import argparse
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
# The directory that holds the `playonline` package, so that sibling tools
# can be run as modules of it.
PACKAGE_ROOT = os.path.dirname(os.path.dirname(HERE))


def _tool(name, *argv, **kw):
    """Run a sibling lib/ tool as `python -m playonline.lib.NAME`."""
    env = dict(os.environ)
    env["PYTHONPATH"] = PACKAGE_ROOT + os.pathsep + env.get("PYTHONPATH", "")
    return subprocess.run([sys.executable, "-m", "playonline.lib." + name]
                          + list(argv), env=env, cwd=PACKAGE_ROOT, **kw)
NOP = 0x00000000
JR_RA = 0x03E00008
LI_V0_1 = 0x24020001
V0_ZERO = 0x0000102D
BEQ_ALWAYS = 0x10000003

# Per build: {label: [(addr, expected_original, new_word, what), ...]}.
# Detection requires every expected_original to match.
BUILDS = {
    "20031006_0 (US disc)": [
        (0x001B13F8, 0x1440000A, NOP,        "viewer binding: mismatch branch"),
        (0x001B10E8, 0x3C020020, JR_RA,      "viewer record check: stub"),
        (0x001B10EC, 0x27BDFFC0, LI_V0_1,    "  -> return 1"),
        (0x0080D238, 0x3C020083, JR_RA,      "DNAS verdict: stub"),
        (0x0080D23C, 0x8C424A24, V0_ZERO,    "  -> return 0"),
        (0x0080DE90, 0x10620003, BEQ_ALWAYS, "DNAS poll 1: state==5 forced"),
        (0x0080E1C0, 0x10620003, BEQ_ALWAYS, "DNAS poll 2: state==5 forced"),
        (0x0080E808, 0x10620003, BEQ_ALWAYS, "DNAS poll 3: state==5 forced"),
        (0x0080EE20, 0x10620003, BEQ_ALWAYS, "DNAS poll 4: state==5 forced"),
    ],
    "20051004_3 (last US build that ships the boot container)": [
        (0x002157B8, 0x1440000A, NOP,        "viewer binding: mismatch branch"),
        (0x002154A8, 0x3C020024, JR_RA,      "viewer record check: stub"),
        (0x002154AC, 0x27BDFFC0, LI_V0_1,    "  -> return 1"),
        # Same routine, word and address as the two JP builds below: the
        # online certification in front of an update check compares the stored
        # record against the console and drive id. Without this row a console
        # whose ids differ from the stored record fails with POL-1562.
        (0x0020CC6C, 0x14400014, NOP,        "install binding: mismatch branch"),
        (0x00821D50, 0x3C020086, JR_RA,      "DNAS verdict: stub"),
        (0x00821D54, 0x8C42012C, V0_ZERO,    "  -> return 0"),
        (0x008229A8, 0x10620003, BEQ_ALWAYS, "DNAS poll 1: state==5 forced"),
        (0x00822CD8, 0x10620003, BEQ_ALWAYS, "DNAS poll 2: state==5 forced"),
        (0x00823320, 0x10620003, BEQ_ALWAYS, "DNAS poll 3: state==5 forced"),
        (0x00823938, 0x10620003, BEQ_ALWAYS, "DNAS poll 4: state==5 forced"),
    ],
    # JP 1.13.01f, SLPS-20200. Read from that build's decrypted boot ELF by the
    # shapes in the help text above, and cross-checked against the US build
    # above: the 0x1d8000 segment sites are at identical addresses, and every
    # 0x800000 segment site is exactly +0x10.
    #
    # All four DNAS polls reach the verdict, so all four are patched.
    #
    # The install binding is a different function from the viewer binding one
    # row up, hence the different branch displacement. The same word sits at
    # the same address in 20051004_3 and in 1.14.03.
    "1.13.01f (JP, SLPS-20200)": [
        (0x002157B8, 0x1440000A, NOP,        "viewer binding: mismatch branch"),
        (0x002154A8, 0x3C020024, JR_RA,      "viewer record check: stub [RECORD]"),
        (0x002154AC, 0x27BDFFC0, LI_V0_1,    "  -> return 1 [RECORD]"),
        (0x0020CC6C, 0x14400014, NOP,        "install binding: mismatch branch"),
        (0x00821D60, 0x3C020086, JR_RA,      "DNAS verdict: stub"),
        (0x00821D64, 0x8C420034, V0_ZERO,    "  -> return 0"),
        (0x008229B8, 0x10620003, BEQ_ALWAYS, "DNAS poll 1: state==5 forced"),
        (0x00822CE8, 0x10620003, BEQ_ALWAYS, "DNAS poll 2: state==5 forced"),
        (0x00823330, 0x10620003, BEQ_ALWAYS, "DNAS poll 3: state==5 forced"),
        (0x00823948, 0x10620003, BEQ_ALWAYS, "DNAS poll 4: state==5 forced"),
    ],
    # JP 1.05.00d, the Japanese PlayOnline Viewer disc, and the oldest Viewer
    # on any supported disc. Read from that disc's POL/install/PS2/SLPS-20200,
    # opened with ci_universal.py using SE's public keys.
    #
    # It differs from later Viewers in two ways:
    #
    #   Three DNAS polls where later builds have four. The ladder scan finds
    #   three, and the `sceDNAS1GetStatus() ERROR %d` string is referenced from
    #   exactly three sites, at the same relative offsets (+0x7c, +0x7c, +0x12c)
    #   as the first three polls of every later build. The fourth poll (+0x6c)
    #   is absent.
    #
    #   Two complete copies of the binding and record routines, at 0x001b2e00
    #   and 0x001bab20. The 236 words from each copy's record prologue through
    #   its binding branch differ in 24 places, all of them global offsets or
    #   `jal` targets: the same library linked twice. Which copy the boot path
    #   calls is not known, so both are patched; patching an unused routine
    #   costs nothing.
    #
    # There is no install-binding row: the routine does not exist in this
    # build.
    "1.05.00d (JP, the PlayOnline Viewer disc)": [
        (0x001B3110, 0x1440000A, NOP,        "viewer binding A: mismatch branch"),
        (0x001B2E00, 0x3C020020, JR_RA,      "viewer record check A: stub [RECORD]"),
        (0x001B2E04, 0x27BDFFC0, LI_V0_1,    "  -> return 1 [RECORD]"),
        (0x001BAE30, 0x1440000A, NOP,        "viewer binding B: mismatch branch"),
        (0x001BAB20, 0x3C020020, JR_RA,      "viewer record check B: stub [RECORD]"),
        (0x001BAB24, 0x27BDFFC0, LI_V0_1,    "  -> return 1 [RECORD]"),
        (0x0080B8C8, 0x3C020081, JR_RA,      "DNAS verdict: stub"),
        (0x0080B8CC, 0x8C42F914, V0_ZERO,    "  -> return 0"),
        (0x0080C510, 0x10620003, BEQ_ALWAYS, "DNAS poll 1: state==5 forced"),
        (0x0080C840, 0x10620003, BEQ_ALWAYS, "DNAS poll 2: state==5 forced"),
        (0x0080CE88, 0x10620003, BEQ_ALWAYS, "DNAS poll 3: state==5 forced"),
    ],
    # JP 1.14.03, the Dirge of Cerberus disc, the newest Japanese Viewer on a
    # supported disc. Read the same way.
    #
    # Its binding and record sites land at the same addresses as 20051004_3 and
    # 1.13.01f, with the same words; the verdict and the four polls are what
    # separate the three. 1.14.03's verdict sits at +0x18 from 1.13.01f's and
    # +0x28 from 20051004_3's, and each of its polls at the same offset from the
    # corresponding one. No build matches more than one table.
    #
    # The install-binding row is the same address, word and routine as in
    # 1.13.01f. It serves the Japanese install route and is precautionary.
    "1.14.03 (JP, the Dirge of Cerberus disc)": [
        (0x002157B8, 0x1440000A, NOP,        "viewer binding: mismatch branch"),
        (0x002154A8, 0x3C020024, JR_RA,      "viewer record check: stub [RECORD]"),
        (0x002154AC, 0x27BDFFC0, LI_V0_1,    "  -> return 1 [RECORD]"),
        (0x0020CC6C, 0x14400014, NOP,        "install binding: mismatch branch"),
        (0x00821D78, 0x3C020086, JR_RA,      "DNAS verdict: stub"),
        (0x00821D7C, 0x8C42012C, V0_ZERO,    "  -> return 0"),
        (0x008229D0, 0x10620003, BEQ_ALWAYS, "DNAS poll 1: state==5 forced"),
        (0x00822D00, 0x10620003, BEQ_ALWAYS, "DNAS poll 2: state==5 forced"),
        (0x00823348, 0x10620003, BEQ_ALWAYS, "DNAS poll 3: state==5 forced"),
        (0x00823960, 0x10620003, BEQ_ALWAYS, "DNAS poll 4: state==5 forced"),
    ],
}

PARTITION = "PP.SCUS-97269.1000.POLVIEWER"
FILE_IN_PART = "/SCUS-97269"

DNAS_ERROR_STRING = b"sceDNAS1GetStatus() ERROR %d"

ORIGINAL, PATCHED, FOREIGN = "original", "patched", "foreign"

CONST_NAMES = {NOP: "NOP", JR_RA: "JR_RA", LI_V0_1: "LI_V0_1",
               V0_ZERO: "V0_ZERO", BEQ_ALWAYS: "BEQ_ALWAYS"}


def _elf_of(container, hddid, record, out):
    """Decrypt container 2 (the boot ELF) out of an installed container."""
    _tool("polencpatch", os.path.abspath(container),
          "--hddid", os.path.abspath(hddid), "--record", os.path.abspath(record),
          "--container", "2", "-o", os.path.abspath(out),
          check=True, capture_output=True)
    return out


# --------------------------------------------------------------------------
# reading a build's sites out of an ELF
# --------------------------------------------------------------------------

def site_states(img, patches):
    """[(addr, current, expected, new, what, state)] for one build's table.

    `state` is ORIGINAL, PATCHED or FOREIGN. FOREIGN means the word is neither
    the expected original nor the patch, so either this is not that build or the
    table is wrong about it.
    """
    out = []
    for addr, orig, new, what in patches:
        cur = img.word(addr)
        if cur == orig:
            state = ORIGINAL
        elif cur == new:
            state = PATCHED
        else:
            state = FOREIGN
        out.append((addr, cur, orig, new, what, state))
    return out


def tally(states):
    """(n_original, n_patched, n_foreign)."""
    return tuple(sum(1 for s in states if s[5] == kind)
                 for kind in (ORIGINAL, PATCHED, FOREIGN))


def detect(elf_path):
    """(label, patches) for the build this ELF is, or (None, report).

    A build matches only when every site holds either its expected original or
    its patch. An already-patched container still matches, so re-running is
    safe; a site holding neither disqualifies the build outright, so a near-miss
    table is not reported as a hit.

    `report` maps each label to (n_original, n_patched, n_foreign) so the
    caller prints what was read rather than a bare score.
    """
    from .mips import Image
    img = Image(elf_path)
    report, matched = {}, []
    for label, patches in BUILDS.items():
        counts = tally(site_states(img, patches))
        report[label] = counts
        if counts[2] == 0:
            matched.append(label)
    if len(matched) == 1:
        return matched[0], BUILDS[matched[0]]
    return None, report


def _print_report(report):
    print("unrecognised build -- per-build site words "
          "(original/patched/neither):")
    for label, (o, p, f) in report.items():
        print("   %-60s %d/%d/%d of %d" % (label, o, p, f, len(BUILDS[label])))
    if sum(1 for _o, _p, f in report.values() if f == 0) > 1:
        print("\nMore than one table matches, which is a table bug rather than "
              "a drive\nproblem: two builds cannot both be right. Run "
              "--selftest.")


# --------------------------------------------------------------------------
# deriving the sites in a build that has no table
# --------------------------------------------------------------------------

def _segment_words(img):
    for base, off, size in img.segs:
        yield base, struct.unpack_from("<%dI" % (size // 4), img.b, off)


def find_polls(img):
    """Every DNAS `state == 5` branch: the `beq v1,v0` of the 5/8/-6 ladder."""
    hits = []
    for base, ws in _segment_words(img):
        for i in range(len(ws) - 5):
            if ws[i + 1] != 0x24020005 or ws[i + 3] != 0x24020008 \
                    or ws[i + 5] != 0x2462FFFA:
                continue
            lw = ws[i]                                   # lw v1, 0(rX)
            if (lw >> 26) != 0x23 or ((lw >> 16) & 31) != 3 or (lw & 0xFFFF):
                continue
            beq, bne = ws[i + 2], ws[i + 4]              # beq v1,v0 / bne v1,v0
            if (beq >> 26) != 4 or ((beq >> 21) & 31) != 3 or ((beq >> 16) & 31) != 2:
                continue
            if (bne >> 26) != 5 or ((bne >> 21) & 31) != 3 or ((bne >> 16) & 31) != 2:
                continue
            hits.append(base + (i + 2) * 4)
    return hits


def find_dnas_string_refs(img):
    """(string VA, [addiu addresses]) for `sceDNAS1GetStatus() ERROR %d`.

    The printf's argument is built `lui rX,%hi` then `addiu rX,rX,%lo`, and the
    addiu sits in the `jal`'s delay slot, so this scans for the raw immediate
    rather than tracking the register.
    """
    off = img.b.find(DNAS_ERROR_STRING)
    if off < 0:
        return None, []
    va = img.va(off)
    if va is None:
        return None, []
    lo = va & 0xFFFF
    out = []
    for base, ws in _segment_words(img):
        for i, w in enumerate(ws):
            if (w >> 26) != 0x09 or (w & 0xFFFF) != lo:          # addiu rX,rY,lo
                continue
            if ((w >> 21) & 31) != ((w >> 16) & 31):             # rY == rX
                continue
            out.append(base + i * 4)
    return va, out


def find_verdict(img):
    """[(start, anchor)] for the DNAS verdict leaf.

    `start` is the `lui v0,HI` that gets stubbed, `start + 4` its `lw`. `start`
    is None when the opener is not there, which is what an already-patched
    verdict looks like.
    """
    found = []
    for base, ws in _segment_words(img):
        for i in range(2, len(ws) - 3):
            if ws[i] != 0x2402F9E9 or ws[i + 1] != 0x3C048000 \
                    or ws[i + 2] != 0x3484000C:
                continue                                  # li v0,-1559 / the mask
            start = None
            for k in range(i, max(1, i - 64), -1):
                a, b, c = ws[k], ws[k + 1], ws[k + 2]
                if (a >> 26) != 0x0F or ((a >> 16) & 31) != 2:
                    continue                              # lui v0, HI
                if (b >> 26) != 0x23 or ((b >> 21) & 31) != 2 \
                        or ((b >> 16) & 31) != 2:
                    continue                              # lw v0, LO(v0)
                if (c >> 26) != 1 or ((c >> 21) & 31) != 2 or ((c >> 16) & 31) != 0:
                    continue                              # bltz v0, END
                start = base + k * 4
                break
            found.append((start, base + i * 4))
    return found


def find_gate_prologues(img):
    """Every `gate != 1 -> return -8` function opener, in address order."""
    out = []
    for base, ws in _segment_words(img):
        for i in range(len(ws) - 9):
            if (ws[i] >> 26) != 0x0F or ((ws[i] >> 16) & 31) != 2:
                continue                                  # lui v0, HI
            sp = ws[i + 1]                                # addiu sp, sp, -N
            if (sp >> 26) != 0x09 or ((sp >> 21) & 31) != 29 \
                    or ((sp >> 16) & 31) != 29:
                continue
            lw = ws[i + 2]                                # lw v1, LO(v0)
            if (lw >> 26) != 0x23 or ((lw >> 21) & 31) != 2 \
                    or ((lw >> 16) & 31) != 3:
                continue
            if ws[i + 3] != 0x24040001:                   # addiu a0, zero, 1
                continue
            if 0x2402FFF8 not in (ws[i + 7], ws[i + 8]):  # addiu v0, zero, -8
                continue
            out.append(base + i * 4)
    return out


def find_binding_branch(img, start, span=160):
    """Inside one function: `jal memcmp` / `addiu a2,zero,16` / `bne v0,zero`.

    The binding routine has exactly one; the record routine has none. That is
    the only thing telling the two apart, since they share a prologue.
    """
    hits = []
    for k in range(span):
        va = start + k * 4
        w = img.word(va)
        if w is None:
            break
        if (w >> 26) != 3 or img.word(va + 4) != 0x24060010:
            continue
        nxt = img.word(va + 8)
        if nxt is None:
            continue
        if (nxt >> 26) == 5 and ((nxt >> 21) & 31) == 2 and ((nxt >> 16) & 31) == 0:
            hits.append(va + 8)
    return hits


def _letters(n):
    """Row-label suffixes: nothing for a single copy, ` A`, ` B`, ... for more."""
    return [""] if n == 1 else [" %s" % chr(ord("A") + i) for i in range(n)]


def derive(elf_path):
    """Find every site in a decrypted boot ELF without consulting a table.

    Returns (rows, notes). `rows` is a BUILDS-shaped list ready to paste;
    `notes` records anything the caller should check before trusting it.
    """
    from .mips import Image
    img = Image(elf_path)
    rows, notes = [], []

    prologues = find_gate_prologues(img)
    pairs = [(p, find_binding_branch(img, p)) for p in prologues]
    bindings = [(p, b[0]) for p, b in pairs if len(b) == 1]
    records = [p for p, b in pairs if not b]
    for p, b in pairs:
        if len(b) > 1:
            notes.append("prologue %#010x runs %d 16-byte compares; open it "
                         "and pick the binding one by hand" % (p, len(b)))
    if len(bindings) != len(records):
        notes.append("%d binding routine(s) against %d record routine(s): they "
                     "come in pairs, so open both sets before trusting this"
                     % (len(bindings), len(records)))
    suffix = _letters(max(1, len(bindings)))
    for i, (_start, branch) in enumerate(bindings):
        rows.append((branch, img.word(branch), NOP,
                     "viewer binding%s: mismatch branch" % suffix[i]))
    rsuffix = _letters(max(1, len(records)))
    for i, start in enumerate(records):
        rows.append((start, img.word(start), JR_RA,
                     "viewer record check%s: stub [RECORD]" % rsuffix[i]))
        rows.append((start + 4, img.word(start + 4), LI_V0_1,
                     "  -> return 1 [RECORD]"))

    verdicts = find_verdict(img)
    if len(verdicts) != 1:
        notes.append("%d DNAS verdict candidate(s), and there should be exactly "
                     "one" % len(verdicts))
    for start, anchor in verdicts:
        if start is None:
            notes.append("verdict body at %#010x but no opener above it: that "
                         "is what an already-patched verdict looks like"
                         % anchor)
            continue
        rows.append((start, img.word(start), JR_RA, "DNAS verdict: stub"))
        rows.append((start + 4, img.word(start + 4), V0_ZERO, "  -> return 0"))

    polls = find_polls(img)
    strva, refs = find_dnas_string_refs(img)
    if strva is None:
        notes.append("no `%s` string in this ELF, so the polls have only one "
                     "witness" % DNAS_ERROR_STRING.decode())
    elif len(refs) != len(polls):
        notes.append("%d poll ladder(s) against %d reference(s) to the DNAS "
                     "error string: the two methods disagree, so neither is "
                     "proven" % (len(polls), len(refs)))
    for i, va in enumerate(polls):
        rows.append((va, img.word(va), BEQ_ALWAYS,
                     "DNAS poll %d: state==5 forced" % (i + 1)))

    # The verdict is also the call target of each poll's state==5 path, which
    # is a third way to the same address. Complain when it does not hold.
    if verdicts and verdicts[0][0] is not None:
        want = verdicts[0][0]
        for i, va in enumerate(polls):
            jal = img.word(va + 0x14)
            if jal is None or (jal >> 26) != 3:
                continue
            tgt = ((va + 0x18) & 0xF0000000) | ((jal & 0x3FFFFFF) << 2)
            if tgt != want:
                notes.append("poll %d calls %#010x on the state==5 path rather "
                             "than the verdict at %#010x" % (i + 1, tgt, want))
    return sorted(rows, key=lambda r: r[0]), notes


def print_derivation(elf_path):
    from .mips import Image, disasm
    img = Image(elf_path)
    rows, notes = derive(elf_path)
    strva, refs = find_dnas_string_refs(img)
    print("segments: %s" % ", ".join("%#010x +%#x" % (v, sz)
                                     for v, _o, sz in img.segs))
    if strva is not None:
        print("DNAS error string at %#010x, referenced from %s"
              % (strva, ", ".join("%#010x" % r for r in refs)))
    print("%d site(s) found\n" % len(rows))
    for addr, word, new, what in rows:
        text, _ = disasm(word, addr)
        print("        (0x%08X, 0x%08X, %-11s %-38s  # %s"
              % (addr, word, CONST_NAMES.get(new, "0x%08X" % new) + ",",
                 '"%s"),' % what, text))
    print()
    if notes:
        print("Read these before using the table:")
        for n in notes:
            print("  ! %s" % n)
    else:
        print("Every cross-check agreed: the poll ladder and the DNAS string "
              "references\nfound the same count, and each poll calls the "
              "verdict found here.")
    print("\nThis is the Viewer-side set. Some builds also carry a second copy "
          "of the\nbinding compare in the installer path (`install binding`, "
          "0x0020cc6c in\n1.13.01f and 1.14.03), which has a different prologue "
          "and is not found\nhere. Locate it by hand in a build that has it.")
    print("\nBefore using these rows, disassemble each function and confirm "
          "the site is\nthe instruction described.")
    return 0


# --------------------------------------------------------------------------
# the self-test: everything checkable without Square Enix's bytes
# --------------------------------------------------------------------------

def selftest():
    """[] when the tables are self-consistent, else a list of complaints.

    This cannot prove an address is right; only an ELF of that build can, and
    none of those is shipped here. What it does catch is a word copied from the
    row above and a table that overlaps another.
    """
    bad = []

    for label, patches in BUILDS.items():
        seen = set()
        for addr, orig, new, what in patches:
            if addr in seen:
                bad.append("%s: %#010x listed twice" % (label, addr))
            seen.add(addr)
            if orig == new:
                bad.append("%s: %#010x patches to its own original word"
                           % (label, addr))
            if addr & 3:
                bad.append("%s: %#010x is not 4-aligned" % (label, addr))

            # Each row kind has a shape, and the shape is checkable.
            if "mismatch branch" in what:
                if (orig >> 26) != 5 or ((orig >> 21) & 31) != 2 \
                        or ((orig >> 16) & 31) != 0:
                    bad.append("%s: %#010x is a mismatch-branch row, so its "
                               "original must be `bne v0,zero,X`, and 0x%08X "
                               "is not" % (label, addr, orig))
                if new != NOP:
                    bad.append("%s: %#010x should be NOPed" % (label, addr))
            elif "stub" in what:
                if (orig >> 26) != 0x0F or ((orig >> 16) & 31) != 2:
                    bad.append("%s: %#010x stubs a function, so its original "
                               "must be `lui v0,HI`, and 0x%08X is not"
                               % (label, addr, orig))
                if new != JR_RA:
                    bad.append("%s: %#010x should become `jr ra`"
                               % (label, addr))
            elif "return 1" in what:
                if (orig >> 26) != 0x09 or new != LI_V0_1:
                    bad.append("%s: %#010x is the delay slot of a record stub, "
                               "so it should hold this build's `addiu sp,sp,-N` "
                               "and become `li v0,1`" % (label, addr))
            elif "return 0" in what:
                if (orig >> 26) != 0x23 or new != V0_ZERO:
                    bad.append("%s: %#010x is the delay slot of the verdict "
                               "stub, so it should hold `lw v0,LO(v0)` and "
                               "become `v0 = 0`" % (label, addr))
            elif "state==5" in what:
                if (orig >> 26) != 4 or ((orig >> 21) & 31) != 3 \
                        or ((orig >> 16) & 31) != 2:
                    bad.append("%s: %#010x is a poll row, so its original must "
                               "be `beq v1,v0,X`, and 0x%08X is not"
                               % (label, addr, orig))
                if (new & 0xFFFF) != (orig & 0xFFFF) or (new >> 16) != 0x1000:
                    bad.append("%s: %#010x must branch to where it branched "
                               "before, as `beq zero,zero` with the same "
                               "displacement" % (label, addr))
            else:
                bad.append("%s: %#010x has an unrecognised row label %r"
                           % (label, addr, what))

        # A stub and its delay slot have to be adjacent and in that order. A
        # transposed pair would overwrite the wrong instruction.
        for i in range(len(patches) - 1):
            if "stub" in patches[i][3] and patches[i + 1][0] != patches[i][0] + 4:
                bad.append("%s: the stub at %#010x is not followed by its "
                           "delay slot" % (label, patches[i][0]))

        kinds = [w for _a, _o, _n, w in patches]
        polls = sum(1 for k in kinds if "state==5" in k)
        if polls not in (3, 4):
            bad.append("%s: %d DNAS poll(s); known builds have 3 or 4"
                       % (label, polls))
        if sum(1 for k in kinds if "DNAS verdict" in k) != 1:
            bad.append("%s: expected exactly one DNAS verdict stub" % label)
        if not [k for k in kinds if "record check" in k]:
            bad.append("%s: no record check row" % label)
        binds = sum(1 for k in kinds if "viewer binding" in k)
        recs = sum(1 for k in kinds if "record check" in k)
        if binds != recs:
            bad.append("%s: %d viewer binding row(s) against %d record stub(s); "
                       "the two routines come in pairs" % (label, binds, recs))

    # No table may be a subset of another. A subset can never be ruled out:
    # every ELF that satisfies the larger table satisfies the smaller one too,
    # so `detect` would see two matches and have to guess, and the wrong words
    # would go into a container.
    #
    # Tables that share some addresses with the same words are fine and expected:
    # three builds put the binding and record checks at the same addresses. What
    # separates those is the addresses they do not share, which is a property of
    # the ELFs rather than the tables, so it is checked by `--selftest ELF...`
    # and not here.
    rowsets = {label: {(a, o, n) for a, o, n, _w in rows}
               for label, rows in BUILDS.items()}
    labels = list(BUILDS)
    for i, a in enumerate(labels):
        for b in labels[i + 1:]:
            if rowsets[a] <= rowsets[b] or rowsets[b] <= rowsets[a]:
                bad.append("%s and %s: one table's rows are a subset of the "
                           "other's, so an ELF matching the larger would match "
                           "both" % (a, b))
    return bad


def selftest_against(paths):
    """[(path, label_or_None, detail)], one per ELF; each must match one table.

    This is the half of the self-test that needs Square Enix's bytes, so it is
    opt-in and takes the ELFs from the caller. It proves what the table-only
    checks cannot: that the tables tell the builds apart on the files they were
    derived from.
    """
    from .mips import Image
    out = []
    for path in paths:
        try:
            img = Image(path)
        except (IOError, OSError, ValueError) as e:
            out.append((path, None, "unreadable: %s" % e))
            continue
        hits = []
        for label, patches in BUILDS.items():
            o, p, f = tally(site_states(img, patches))
            if f == 0:
                hits.append((label, o, p))
        if len(hits) == 1:
            label, o, p = hits[0]
            out.append((path, label, "%d original, %d already patched" % (o, p)))
        elif not hits:
            out.append((path, None, "matches no table"))
        else:
            out.append((path, None, "matches %d tables: %s"
                        % (len(hits), ", ".join(h[0] for h in hits))))
    return out


def run_selftest(elfs=()):
    for label, patches in BUILDS.items():
        kinds = [w for _a, _o, _n, w in patches]
        print("  %-60s %2d sites, %d poll(s)"
              % (label, len(patches), sum(1 for k in kinds if "state==5" in k)))
    print()
    bad = selftest()
    for b in bad:
        print("  FAIL %s" % b)
    if not bad:
        print("  ok   every row has the shape its label claims")
        print("  ok   no table's rows are a subset of another's")
    if elfs:
        print()
        for path, label, detail in selftest_against(elfs):
            print("  %s %-34s %s"
                  % ("ok  " if label else "FAIL", os.path.basename(path),
                     "%s (%s)" % (label, detail) if label else detail))
            if label is None:
                bad.append("%s: %s" % (path, detail))
    else:
        print("\nNo ELF given, so the tables were not tried against any build. "
              "Pass the\ndecrypted boot ELFs as arguments to check that each "
              "one matches exactly\none table.")
    print()
    if bad:
        print("%d problem(s)" % len(bad))
        return 1
    print("%d build tables, all consistent." % len(BUILDS))
    return 0


def report_elf(path, genuine_record=False):
    from .mips import Image
    label, patches = detect(path)
    if label is None:
        _print_report(patches)
        print("\n    python ci_viewerpatch.py --derive %s\n"
              "finds the sites in it from its own instruction shapes, with no "
              "table." % path)
        return 2
    img = Image(path)
    states = site_states(img, patches)
    print("detected build: %s\n" % label)
    todo = []
    for addr, cur, orig, new, what, state in states:
        print("   %#010x  is %08x  original %08x  patch %08x  %-8s %s"
              % (addr, cur, orig, new, state, what))
        if genuine_record and "[RECORD]" in what:
            continue
        if cur != new:
            todo.append((addr, new, what))
    # `detect` only returns a build when no site holds a foreign word, so the
    # third figure is always 0 here. It is printed for completeness.
    n_orig, n_patched, n_foreign = tally(states)
    print("\n%d site(s) hold the expected original word, %d are already "
          "patched, %d\nhold neither." % (n_orig, n_patched, n_foreign))
    print("%d word(s) still to apply:" % len(todo))
    for addr, new, what in todo:
        print("   --set 0x%08X=0x%08X   # %s" % (addr, new, what))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--image", help="drive image; extracts and writes back")
    ap.add_argument("--container", help="a loose installed container instead")
    ap.add_argument("--elf", help="a decrypted boot ELF -- report only, never writes. "
                                  "Use this to verify a build's sites when you have no "
                                  "drive material (hddid/record) to decrypt with.")
    ap.add_argument("--derive", metavar="ELF",
                    help="find the sites in a decrypted boot ELF from its own "
                         "instruction shapes, consulting no table, and print a "
                         "BUILDS row set. Use on a build that has no table.")
    ap.add_argument("--selftest", action="store_true",
                    help="check the build tables against themselves; needs no "
                         "ELF and no drive material. Name decrypted boot ELFs "
                         "as extra arguments and each must match exactly one "
                         "table.")
    ap.add_argument("elfs", nargs="*", metavar="ELF",
                    help="with --selftest, decrypted boot ELFs to try the "
                         "tables against")
    ap.add_argument("--hddid", help="the drive's 512-byte HDD ID; needed "
                                    "with --image or --container")
    ap.add_argument("--record", help="the drive's 512-byte __net record; "
                                     "needed with --image or --container")
    ap.add_argument("--partition", default=PARTITION)
    ap.add_argument("--file", default=FILE_IN_PART,
                    help="the boot container's path inside the partition "
                         "(default %(default)s; on a Japanese install it is "
                         "/SLPS-20200)")
    ap.add_argument("--genuine-record", action="store_true",
                    help="skip the [RECORD] rows. A drive installed by Square "
                         "Enix's own installer has a real __net record and "
                         "passes the record check unaided; the stub is only "
                         "needed on a drive this package built, which carries "
                         "a minted record.")
    ap.add_argument("-o", "--out")
    ap.add_argument("--write", action="store_true", help="write back into the image")
    args = ap.parse_args()

    if args.selftest:
        return run_selftest(args.elfs)
    if args.elfs:
        raise SystemExit("extra arguments %r: ELF paths are only taken with "
                         "--selftest (use --elf for one report)" % args.elfs)
    if args.derive:
        return print_derivation(args.derive)
    if args.elf:
        return report_elf(args.elf, args.genuine_record)

    if not args.hddid or not args.record:
        raise SystemExit("--hddid and --record are needed to open a container")
    tmp = tempfile.mkdtemp(prefix="ci_viewerpatch_")
    if args.image:
        _tool("polpfsread", os.path.abspath(args.image),
              "--only", args.partition, "--grep", args.file,
              "--extract", tmp, check=True, capture_output=True)
        container = os.path.join(tmp, args.partition, args.file.lstrip("/"))
    else:
        container = args.container
    if not container or not os.path.exists(container):
        raise SystemExit("no container found (checked %r)" % container)
    print("container: %s (%d bytes)" % (container, os.path.getsize(container)))

    elf = _elf_of(container, args.hddid, args.record, os.path.join(tmp, "boot.elf"))
    label, patches = detect(elf)
    if label is None:
        _print_report(patches)
        print("\nRe-derive the sites without leaving this tool:\n"
              "    python ci_viewerpatch.py --derive %s\n"
              "It scans for shapes rather than carrying addresses across: the "
              "DNAS polls\nby their 5/8/-6 ladder and by the raw addiu "
              "immediate holding the low half\nof the "
              "'sceDNAS1GetStatus() ERROR %%d' address (which sits in the jal's\n"
              "delay slot), the verdict by its `li v0,-1559` beside the "
              "lui a0,0x8000 /\nori 0x000c mask, and binding and record by "
              "their shared\n'gate != 1 -> return -8' prologue." % elf)
        return 2
    print("detected build: %s\n" % label)

    out = args.out or os.path.join(tmp, "patched.bin")
    cmd = [os.path.abspath(container),
           "--hddid", os.path.abspath(args.hddid),
           "--record", os.path.abspath(args.record), "--container", "2",
           "-o", os.path.abspath(out), "--force"]
    for addr, _orig, new, what in patches:
        if args.genuine_record and "[RECORD]" in what:
            print("   %#010x   skipped (--genuine-record)   %s" % (addr, what))
            continue
        cmd += ["--set", "0x%08X=0x%08X" % (addr, new)]
        print("   %#010x = %08x   %s" % (addr, new, what))
    _tool("polencpatch", *cmd, check=True, capture_output=True)
    print("\nwrote %s" % out)

    if args.image and args.write:
        r = _tool("polpfspatch", os.path.abspath(args.image),
                  args.partition, FILE_IN_PART, os.path.abspath(out), "--write",
                  capture_output=True, text=True)
        sys.stdout.write(r.stdout[-400:])
        if r.returncode:
            sys.stdout.write(r.stderr[-400:])
            return 1
    elif args.image:
        print("(dry run -- pass --write to put it back in the image)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

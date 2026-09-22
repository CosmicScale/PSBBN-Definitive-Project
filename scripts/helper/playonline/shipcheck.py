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
"""Check that the files the PlayOnline installer adds hold nothing of Sony's or Square Enix's.

Everything proprietary the installer needs comes from the user at run time:
their discs, their console's BIOS, their MagicGate keys. None of it may be
committed. The checks:

  every added file is text          a stray .ico, .pex or disc dump is binary
  no Sony or Square Enix markers    strings that begin their data files and
                                    should not begin a source file
  no key material                   long hex or base64 runs that could be a
                                    key, a digest table or a dumped block

By default it runs over the files the installer adds to the toolkit:

    python3 -m playonline.shipcheck            # the whole added tree
    python3 -m playonline.shipcheck PATH ...
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

# What the PlayOnline installer adds to the toolkit.
ADDED = [
    "scripts/helper/playonline",
    "scripts/assets/playonline",
    "scripts/PlayOnline-Installer.sh",
]

# The signed loader, built from loader-src. It is checked instead of being
# exempted: its install header must be present, at the current version and
# empty (no boot ELF, IOP image or HDD ID inside), and it must carry none of
# the other markers. The ELF marker and the HDD ID magic are expected in it:
# the loader is an executable, and its shim searches its own image for that
# magic to find the slot it serves. The default block behind the magic in the
# shim is generated, and the install header's block stays empty until an install
# writes one.
LOADER_BINARY = "polbbnexec.kelf"
# The same loader, unsigned, for the emulator image tool: PCSX2 has no
# MagicGate keys and can only run the plain ELF. It gets the same checks.
#
# A KELF opens only on its own MagicGate zone, so the same payload is signed
# once per console region and shipped as polbbnexec-<region>.kelf. The content
# of every one of them is byte-identical to polbbnexec.elf; only the 32-byte
# header, which the signing template lends, differs.
LOADER_BINARIES = (LOADER_BINARY, "polbbnexec.elf",
                   "polbbnexec-us.kelf", "polbbnexec-jp.kelf")

# `out` holds loader-src/build.sh's build products and is listed in
# .gitignore.
SKIP_DIRS = {"__pycache__", ".git", "out"}
SKIP_NAMES = {".gitignore"}

# Strings found in Sony's or Square Enix's own data. Source code has to name
# these structures (PS2ICON3D, for example), so a marker counts only at the
# start of a text file, or anywhere inside the loader binary.
MARKERS = [
    (b"Sony Computer Entertainment Inc.", "an HDD ID block"),
    (b"PS2ICON3D", "an attribute area"),
    (b"\x7fELF", "an executable"),
    (b"PEX\x00", "a PlayOnline module"),
    (b"PFS\x00", "a filesystem image"),
]

# 64+ hex characters, or 60+ base64 characters, on one line.
HEX_RUN = re.compile(r"[0-9a-fA-F]{64,}")
B64_RUN = re.compile(r"[A-Za-z0-9+/@_]{60,}={0,2}")

def is_alphabet(run):
    """True when `run` is an encoding alphabet and so is not key material.

    A 64-character alphabet uses each character once. A key, a digest or a
    dumped block of that length repeats characters, so alphabets need no
    per-line exceptions.
    """
    return len(run) == 64 and len(set(run)) == 64


def added_files(paths=None):
    for rel in (paths or ADDED):
        full = os.path.join(ROOT, rel)
        if os.path.isfile(full):
            yield full
            continue
        for dirpath, dirs, names in os.walk(full):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for name in sorted(names):
                if name not in SKIP_NAMES:
                    yield os.path.join(dirpath, name)


# The only kinds of file the installer adds. The suffix check catches data the
# content checks cannot, such as an `info.sys`, which is plain text with no
# NUL bytes and no long runs.
SOURCE_SUFFIXES = (".py", ".sh", ".md", ".txt", ".yml", ".yaml",
                   ".c", ".h", ".S")


def check_loader(blob):
    """[(problem, detail)] for the shipped loader binary."""
    out = []
    try:
        from . import loader
        info = loader.read(blob)
    except Exception as e:
        return [("loader", "not the loader this code knows: %s" % e)]
    if info["version"] != loader.VERSION:
        out.append(("loader", "install header version %d, this code ships %d"
                    % (info["version"], loader.VERSION)))
    if info["elf_len"] or info["ioprp_len"]:
        out.append(("loader", "the payload slots are not empty: a filled "
                    "loader carries somebody's disc"))
    if info["has_hddid"]:
        out.append(("loader", "the install header carries an HDD ID block; "
                    "the shipped loader is filled at install time only"))
    for marker, what in MARKERS:
        if marker in (b"\x7fELF", b"Sony Computer Entertainment Inc."):
            continue
        if marker in blob:
            out.append(("content", "carries %s" % what))
    return out


def check_file(path):
    """[(problem, detail)] for one file."""
    out = []
    name = os.path.basename(path)
    if name in LOADER_BINARIES:
        with open(path, "rb") as f:
            return check_loader(f.read())
    if not name.endswith(SOURCE_SUFFIXES):
        out.append(("not source", "this tree holds %s only"
                    % ", ".join(SOURCE_SUFFIXES)))

    with open(path, "rb") as f:
        blob = f.read()

    if b"\x00" in blob:
        out.append(("binary", "contains NUL bytes"))
        return out                      # the rest assumes text

    try:
        text = blob.decode("utf-8")
    except UnicodeDecodeError as e:
        out.append(("binary", "not UTF-8: %s" % e))
        return out

    for marker, what in MARKERS:
        if blob.startswith(marker):
            out.append(("content", "starts like %s" % what))

    for number, line in enumerate(text.splitlines(), 1):
        hit = HEX_RUN.search(line) or B64_RUN.search(line)
        if hit and not is_alphabet(hit.group(0)):
            out.append(("key material",
                        "line %d: a %d-character run" % (number, len(hit.group(0)))))
    return out


def main():
    paths = sys.argv[1:] or None
    files = list(added_files(paths))
    problems = 0
    for path in files:
        for kind, detail in check_file(path):
            problems += 1
            print("  %-13s %s: %s" % (kind, os.path.relpath(path, ROOT), detail))
    print("%d file(s) checked, %d problem(s)" % (len(files), problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

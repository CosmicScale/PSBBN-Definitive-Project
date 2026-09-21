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
"""Extract the CHD disc images in a folder, so the installer can read them.

A CHD is a compressed disc image. The readers in this package work on plain
images, so each `NAME.chd` is extracted once with MAME's `chdman`, to
`NAME.iso` for a DVD or `NAME.bin` and `NAME.cue` for a CD, beside the
original. A CHD that already has a `NAME.iso` or `NAME.bin` beside it is
left alone, so a second run costs nothing. The CHD itself is never changed.

    python3 -m playonline.chd FOLDER            # extract what needs it
    python3 -m playonline.chd FOLDER --list     # say what would be done

Exit status 3 means a CHD needs extracting and `chdman` is not installed
(it is in the `mame-tools` package on Debian, Fedora and Arch).
"""
import argparse
import os
import shutil
import subprocess
import sys

NEED_CHDMAN = 3


def pending(folder):
    """[(chd path, stem)] for each CHD with no extracted image beside it."""
    out = []
    for name in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(name)
        if ext.lower() != ".chd":
            continue
        base = os.path.join(folder, stem)
        if any(os.path.isfile(base + e) for e in (".iso", ".ISO", ".bin", ".BIN")):
            continue
        out.append((os.path.join(folder, name), base))
    return out


def is_dvd(chdman, path):
    """True when `chdman info` reports DVD metadata."""
    info = subprocess.run([chdman, "info", "-i", path], stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT)
    return b"'DVD" in info.stdout


def extract(chdman, path, base):
    """Extract one CHD. Returns the image path, or raises RuntimeError."""
    if is_dvd(chdman, path):
        jobs = [(["extractdvd", "-i", path, "-o", base + ".iso"], [base + ".iso"])]
    else:
        jobs = []
    # A DVD stored as a CD-type CHD, or a chdman too old to know extractdvd,
    # is handled by the CD route, which yields a .bin of 2352-byte sectors.
    jobs.append((["extractcd", "-i", path, "-o", base + ".cue", "-ob", base + ".bin"],
                 [base + ".bin", base + ".cue"]))
    last = ""
    for args, outputs in jobs:
        run = subprocess.run([chdman] + args, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT)
        if run.returncode == 0 and os.path.isfile(outputs[0]):
            return outputs[0]
        last = run.stdout.decode("utf-8", "replace").strip().splitlines()[-1:] or [""]
        last = last[0]
        for leftover in outputs:            # never leave a partial image behind
            if os.path.isfile(leftover):
                os.remove(leftover)
    raise RuntimeError("chdman could not extract %s: %s" % (os.path.basename(path), last))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("folder")
    ap.add_argument("--list", action="store_true", help="report only")
    args = ap.parse_args()
    todo = pending(args.folder)
    if not todo:
        return 0
    if args.list:
        for path, _base in todo:
            print(os.path.basename(path))
        return 0
    chdman = shutil.which("chdman")
    if not chdman:
        print("chdman is not installed", file=sys.stderr)
        return NEED_CHDMAN
    failed = 0
    for path, base in todo:
        need = os.path.getsize(path) * 3
        free = shutil.disk_usage(args.folder).free
        if free < need:
            print("%s: not enough free space beside it to extract"
                  % os.path.basename(path), file=sys.stderr)
            failed += 1
            continue
        print("%s ..." % os.path.basename(path), flush=True)
        try:
            print("  extracted %s" % os.path.basename(extract(chdman, path, base)))
        except RuntimeError as e:
            print("  %s" % e, file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

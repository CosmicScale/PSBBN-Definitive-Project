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
"""Make `__net` what PlayOnline needs: present, and openable by the Viewer.

A PSBBN install already has a `__net` partition: pfsshell's `initialize`
creates it, formatted, with both password fields zero. The Viewer cannot open
it in that state (see `set_passwords`), so an existing `__net` gets its
passwords set and is otherwise left alone, and a missing one is created.

Two things live in `__net`:

  /etc/access_flag...  zero-byte files Square Enix's installer creates (one
                       to four of them, depending on the Viewer version).
                       `fill` writes all four. They are not known to be
                       required: the Viewer starts without them.
  + 0x201800           the 20-byte per-drive record, outside the filesystem.
                       It is required, because every module on the drive is
                       keyed through it. Minting it belongs to the
                       module-preparation route in use (see route.py).

The partition's APA passwords are fixed: the console derives them from
constants, so they are the same on every drive. `polhdd.PASSWORDS` holds
them, and the result matches the header of a drive Square Enix's installer
made.

This is the only place the installer writes the partition table. Game
partitions are created by pfsshell, but pfsshell does not give `__net` the
right passwords, so `__net` goes through lib/polapaadd.py, which splits a free
run, keeps the APA list circular, and refuses to write without a backup file.

    python3 -m playonline.netpart DRIVE                 # what it would do
    python3 -m playonline.netpart DRIVE --write --backup PRE.json
    python3 -m playonline.netpart DRIVE --verify
"""
import argparse
import os
import subprocess
import sys
import tempfile

from . import apa, jail
from .lib import polhdd, polpfs, polrealfill

NAME = "__net"
SIZE_MIB = 128
RECORD_OFFSET = 0x201800        # inside __net, outside its filesystem

# The flag files in /etc, all zero bytes. Which of them a drive carries
# varies with the Viewer version that installed it:
#
#   1.18.03b USA        access_flag, access_flag2, access_flag25, bnexe
#   1.09.03d JPN        the same four
#   1.18.15f JPN        access_flag2 only
#
# `fill` writes all four, a superset of every case. None of them is known to
# be required: the Viewer runs with an empty `__net` filesystem, and the
# names appear in none of the Viewer's executables or modules. `verify`
# therefore reports what it finds and does not fail when they are absent.
FLAGS = ("access_flag", "access_flag2", "access_flag25", "bnexe")

HELPER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def present(image):
    """(lba, sectors) if __net is there, else None."""
    try:
        return apa.find_partition(image, NAME)
    except (KeyError, IOError, OSError, ValueError):
        return None


def add_partition(image, write=False, backup=None):
    """Carve __net out of free space, through polapaadd.

    Driven as a subprocess so that polapaadd's own safeguards apply: the
    mandatory backup, the aligned-fit search and the circular relink.
    """
    base = [sys.executable, "-m", "playonline.lib.polapaadd", image,
            "--add", NAME, "--size", str(SIZE_MIB)]

    # Always plan first. The plan names the LBA it would use, and on an
    # APA-Jail drive that LBA has to be checked against the PC partition
    # table before anything is written, because the APA free space can
    # overlap the exFAT partition that holds the user's games.
    env = dict(os.environ, PYTHONPATH=HELPER)
    proc = subprocess.run(base, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          cwd=HELPER, env=env)
    out = proc.stdout.decode("latin-1", "replace")
    if proc.returncode:
        return proc.returncode, out

    lba = None
    for line in out.splitlines():
        if line.startswith("plan: add ") and " at LBA " in line:
            try:
                lba = int(line.rsplit(" at LBA ", 1)[1].strip())
            except ValueError:
                lba = None
    if lba is None:
        return 1, out + "\ncould not read the planned LBA out of the plan"

    ok, why = jail.check(image, lba, SIZE_MIB * 2048)
    out += "\n  APA-Jail check: %s - %s\n" % ("ok" if ok else "REFUSED", why)
    if not ok:
        return 1, out

    if not write:
        return 0, out
    if not backup:
        raise ValueError("writing the partition table requires a backup path")
    proc = subprocess.run(base + ["--write", "--backup", backup], cwd=HELPER, env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc.returncode, out + proc.stdout.decode("latin-1", "replace")


def fill(image, write=False):
    """Format __net and write the access flags into it."""
    found = present(image)
    if not found:
        raise SystemExit("%s: no %s partition; add it first" % (image, NAME))
    lba, sectors = found
    tmp = tempfile.mkdtemp(prefix="playonline-net-")
    etc = os.path.join(tmp, "etc")
    os.makedirs(etc)
    for name in FLAGS:
        open(os.path.join(etc, name), "wb").close()
    try:
        with open(image, "r+b" if write else "rb") as f:
            formatted, _why = polrealfill.superblock_ok(f, lba)
            if write:
                if not formatted:
                    polpfs.format_partition(f, lba, sectors)
                _part, stats = polrealfill.populate(f, lba, sectors,
                                                    [(tmp, "")], True)
            else:
                _part, stats = polrealfill.populate(f, lba, sectors,
                                                    [(tmp, "")], False)
        return stats
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)


def verify(image):
    """[(check, ok, detail)] for __net's passwords and contents."""
    out = []
    found = present(image)
    if not found:
        return [("__net present", False, "absent")]
    lba, sectors = found
    out.append(("__net present", True, "LBA %d, %d MiB" % (lba, sectors // 2048)))

    with open(image, "rb") as f:
        f.seek(lba * 512)
        head = f.read(1024)
        f.seek(lba * 512 + RECORD_OFFSET)
        record = f.read(512)
    want_r = polhdd.apa_password(NAME, polhdd.PASSWORDS[NAME][1])
    want_f = polhdd.apa_password(NAME, polhdd.PASSWORDS[NAME][0])
    ok = head[0x30:0x38] == want_r and head[0x38:0x40] == want_f
    out.append(("__net passwords", ok,
                "as every console derives them" if ok
                else "rpwd=%s fpwd=%s" % (head[0x30:0x38].hex(),
                                          head[0x38:0x40].hex())))

    # Unlike the access flags, the record at +0x201800 is required. Every
    # `.pex.enc` on the drive is keyed through it: the record and the HDD ID
    # together yield the bulk key, and an all-zero record cannot decode (see
    # lib/polrecord.py), so no module could be read at run time.
    #
    # Whether the record decodes can only be checked with the HDD ID it was
    # minted for, which is not on the drive, so this checks only that a
    # record is there.
    out.append(("__net record", any(record),
                "present at +0x%06x" % RECORD_OFFSET if any(record)
                else "all zero - mint one with `route prepare` and write it "
                     "with `route record DRIVE --record ... --write`"))

    from .lib import polpfsread
    try:
        with open(image, "rb") as f:
            part, ino = polpfsread.mount(f, lba, sectors)
            if part is None:
                out.append(("__net filesystem", False,
                            "does not mount as PFS"))
                return out
            names = set()
            items, bad = [], []
            polpfsread.walk(part, ino, "/", 0, items, bad)
            for item in items:
                names.add(item[0] if isinstance(item, tuple) else item)
        have = [n for n in FLAGS if "/etc/" + n in names]
        # Reported, never failed on. See the note beside FLAGS: a drive with
        # none of them works, so their absence is not an error.
        out.append(("__net access flags", None,
                    "%d of %d: %s" % (len(have), len(FLAGS), ", ".join(have))
                    if have else "none (not required)"))
    except Exception as e:                      # noqa: BLE001 - report the failure
        out.append(("__net filesystem", False, "%s: %s" % (type(e).__name__, e)))
    return out


def set_passwords(image, write=False):
    """Give an existing `__net` the passwords every console derives.

    Returns (changed, text). pfsshell's `initialize` creates `__net` with both
    password fields zero. The Viewer opens `__net` with the fixed password,
    the driver compares it with the header, and zero does not match, so the
    open fails. On a console this shows up as `DNAS error -401` (POL-1536)
    at the update check.

    Only the two fields and the header checksum change. The filesystem and
    the record are left as they are.
    """
    import struct
    found = present(image)
    if not found:
        raise SystemExit("%s: no %s partition" % (image, NAME))
    lba, _sectors = found
    want_r = polhdd.apa_password(NAME, polhdd.PASSWORDS[NAME][1])
    want_f = polhdd.apa_password(NAME, polhdd.PASSWORDS[NAME][0])
    with open(image, "rb") as f:
        f.seek(lba * 512)
        head = bytearray(f.read(1024))
    cur_r, cur_f = bytes(head[0x30:0x38]), bytes(head[0x38:0x40])
    if cur_r == want_r and cur_f == want_f:
        return False, "%s passwords are already the ones a console derives" % NAME
    text = ("%s passwords: rpwd %s -> %s, fpwd %s -> %s"
            % (NAME, cur_r.hex(), want_r.hex(), cur_f.hex(), want_f.hex()))
    if not write:
        return True, text + "  (plan only)"
    head[0x30:0x38] = want_r
    head[0x38:0x40] = want_f
    struct.pack_into("<I", head, 0, 0)
    struct.pack_into("<I", head, 0, polhdd.checksum(bytes(head)))
    with open(image, "r+b") as f:
        f.seek(lba * 512)
        f.write(bytes(head))
        f.flush()
        os.fsync(f.fileno())
    return True, text + "  (written, header checksum recomputed)"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--backup", help="where to save the table before writing")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    if args.verify:
        bad = 0
        for name, ok, detail in verify(args.image):
            # Three states, as in selftest: None is reported but not counted,
            # for findings that are informative and not requirements.
            print("  %s %-24s %s"
                  % ({True: "ok  ", False: "FAIL", None: "info"}[ok],
                     name, detail))
            bad += 1 if ok is False else 0
        sys.exit(1 if bad else 0)

    found = present(args.image)
    if found:
        print("%s already has %s at LBA %d" % (args.image, NAME, found[0]))
        _changed, text = set_passwords(args.image, args.write)
        print("  " + text)
        with open(args.image, "rb") as f:
            formatted, _why = polrealfill.superblock_ok(f, found[0])
        if formatted:
            # The PSBBN install made this filesystem, and the access flags
            # are not known to be needed, so its contents are left alone.
            print("  its filesystem is left as it is")
            return
    else:
        rc, out = add_partition(args.image, args.write, args.backup)
        print(out.rstrip())
        if rc:
            sys.exit(rc)
        if not args.write:
            return

    stats = fill(args.image, args.write)
    print("%s %d file(s), %d dir(s) into %s"
          % ("wrote" if args.write else "would write",
             stats["files"], stats["dirs"], NAME))
    if not args.write:
        print("(plan only -- pass --write --backup PRE.json)")


if __name__ == "__main__":
    main()

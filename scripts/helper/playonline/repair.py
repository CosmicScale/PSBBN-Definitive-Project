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
"""Put the Viewer's gate patches back after it has updated itself.

The Viewer updates over PlayOnline's own patch channel. The console
transcrypts what it downloads, so the new files are keyed to the drive
without any help. The exception is the boot container: the patch service
ships `/SCUS-97269` up to build `20051004_3`, so an install made from an
older disc has its boot container replaced on the first update, and the
console-binding and record patches this installer applied are lost. The
drive then stops booting with no error that points at the update.
`dnasload.elf` is never shipped by the patch service, so the loader's own
patches survive. An install from Vana'diel Collection 2008 (Viewer 1.18.03b,
which is build `20051004_3`) is never affected.

The repair is `ci_viewerpatch`: it decrypts the container off the drive,
identifies the build by probing the expected original word at every patch
site, and applies the matching set. A site that is already patched counts as
a match, so running this on a healthy drive is safe. This module supplies
the two inputs `ci_viewerpatch` cannot find itself: the title's partition,
and the 512-byte record the container is decrypted with, which is stored
0x201800 into `__net`, outside any filesystem.

    python3 -m playonline.repair DRIVE --title viewer-us --hddid FILE --derive-elf ELF
    python3 -m playonline.repair DRIVE --title viewer-us --hddid FILE --derive-elf ELF --write
"""
import argparse
import os
import sys
import tempfile

from . import apa, titles
from .route import RECORD_OFFSET, _run, use_keys

RECORD_LEN = 512


def read_record(image):
    """The 512-byte per-drive record, read back out of `__net`.

    `route record` writes it there at install time. An all-zero read means
    the record was never written, and is reported as an error.
    """
    try:
        lba, sectors = apa.find_partition(image, "__net")
    except KeyError:
        raise SystemExit("%s: no __net partition, so this drive was never "
                         "given a record" % image)
    if RECORD_OFFSET + RECORD_LEN > sectors * 512:
        raise SystemExit("__net is too small to hold a record")
    with open(image, "rb") as f:
        f.seek(lba * 512 + RECORD_OFFSET)
        data = f.read(RECORD_LEN)
    if len(data) != RECORD_LEN or not any(data):
        raise SystemExit("__net + 0x%x is empty: this install has no record, "
                         "so it was not keyed by this installer"
                         % RECORD_OFFSET)
    return data


def repair(image, title, hddid, derive_elf, disc=None, write=False,
           genuine_record=False):
    """Re-apply the gate patches to `title`'s boot container on `image`.

    `derive_elf` is needed for the same reason `route prepare` needs it: the
    container is decrypted with Square Enix's own keystore, which is read out
    of a disc boot executable rather than carried here.
    """
    use_keys(disc, derive_elf)
    if not title.boot or title.boot == "NOBOOT":
        raise SystemExit("%s has no boot container to repair" % title.key)
    try:
        apa.find_partition(image, title.partition)
    except KeyError:
        raise SystemExit("%s: %s is not on this drive"
                         % (image, title.partition))
    product = title.partition.split(".")[1]
    record = read_record(image)

    from .lib import ci_viewerpatch
    tmp = tempfile.mkdtemp(prefix="polrepair-")
    try:
        rec = os.path.join(tmp, "net-record.bin")
        with open(rec, "wb") as f:
            f.write(record)
        argv = ["ci_viewerpatch", "--image", image,
                "--partition", title.partition,
                "--file", "/" + product,
                "--hddid", hddid, "--record", rec]
        if genuine_record:
            argv.append("--genuine-record")
        if write:
            argv.append("--write")
        _run(ci_viewerpatch, argv)
    finally:
        for n in os.listdir(tmp):
            os.unlink(os.path.join(tmp, n))
        os.rmdir(tmp)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive", help="device path or drive image")
    ap.add_argument("--title", default="viewer-us",
                    help="which title's boot container (default viewer-us)")
    ap.add_argument("--hddid", required=True,
                    help="the HDD ID this install was keyed to, the same file "
                         "the install was made with")
    ap.add_argument("--derive-elf", required=True,
                    help="a disc boot executable the keystore is read from, "
                         "the same one the install was made with "
                         "(python3 -m playonline.route derive-elf)")
    ap.add_argument("--disc", help="the disc it was installed from, if its "
                                   "keystore should be used instead")
    ap.add_argument("--genuine-record", action="store_true",
                    help="the drive carries Square Enix's own record rather "
                         "than a minted one, so the record check passes "
                         "unaided and its patch is not applied")
    ap.add_argument("--write", action="store_true",
                    help="write the repaired container back")
    args = ap.parse_args()

    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    if not os.path.isfile(args.hddid):
        sys.exit("no such HDD ID file: %s" % args.hddid)
    repair(args.drive, titles.TITLES[args.title], args.hddid,
           args.derive_elf, disc=args.disc, write=args.write,
           genuine_record=args.genuine_record)
    if not args.write:
        print("nothing written; pass --write to apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())

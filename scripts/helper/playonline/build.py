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
"""Write a staged title into a partition that already exists.

It does three things to a partition and nothing to the partition table:

    format    PFS, with lib/polpfs
    fill      the staged tree, with lib/polrealfill
    identify  the attribute area, so the browser shows a title instead of
              "Corrupted Data"

Creating the partition is left to pfsshell's `mkpart`, which the PSBBN
scripts already use.
This module refuses to run against a partition that does not exist.

Everything is a dry run unless `--write` is passed. `--verify` re-reads what
was written and compares it with the staged tree.

    python3 -m playonline.build IMAGE --title tetramaster-us --src DIR
    python3 -m playonline.build IMAGE --title tetramaster-us --src DIR --write
    python3 -m playonline.build IMAGE --title tetramaster-us --src DIR --verify
"""
import argparse
import os
import shutil
import sys
import tempfile

from . import apa, attrarea, discs, jail, prebuilt, titles
from .lib import polfill, polnetdump, polpfs, polrealfill

SECTOR = 512


def _icon_for(title, src_dir):
    """(icon bytes, where it came from) for this title's browser entry.

    Only the Viewer's icon ships as a plain file on the disc
    (`playonline.ico`, identical to the one on Square Enix's installed
    partition). For any other title this returns (None, None) and the caller
    has to supply an icon, because a partition with no attribute area reads
    as "Corrupted Data" in the browser.
    """
    if title.icon:
        path = os.path.join(src_dir, title.icon.replace("/", os.sep))
        if os.path.exists(path):
            with open(path, "rb") as f:
                return f.read(), title.icon
    return None, None


def attribute_area(title, icon, encoding=None):
    """The bytes of this title's browser entry."""
    boot = attrarea.build_boot_block(
        title.product if title.boot != "NOBOOT" else "",
        boot2=title.boot)
    icon_sys = attrarea.build_icon_sys(title.title0, title.title1,
                                       encoding=encoding or title.encoding)
    return attrarea.build_area(boot, icon_sys, icon)


def disc_boot_name(product):
    """`SLPM-66271` -> `SLPM_662.71`, the spelling a disc's boot file uses."""
    letters, digits = product.split("-", 1)
    return "%s_%s.%s" % (letters, digits[:3], digits[3:])


# Where Square Enix's Dirge of Cerberus area puts its two icons: slot 2 at
# 0x800 and slot 3 at 0x13200. The second offset is not derivable from the
# first (see attrarea.build_area).
CRLF = chr(13) + chr(10)
DISC_ICON_OFF = 0x800
DISC_COPY_OFF = 0x13200


def disc_boot_area(title, src_dir, ver="1.01"):
    """A browser entry for a title HDD-OSD launches from its disc.

    The disc's install/ directory carries the pieces Square Enix's installer
    assembles: `icon.sys`, `kel_hdd.ico` and `kel_hdd2.ico`. The boot block
    points at the disc, as Square Enix's does. The Viewer launches the title
    from the drive by its own means and never reads this block.
    """
    parts = {}
    for name in ("icon.sys", "kel_hdd.ico", "kel_hdd2.ico"):
        path = os.path.join(src_dir, "install", name)
        if not os.path.exists(path):
            return None, "no install/%s in the staged tree" % name
        with open(path, "rb") as f:
            parts[name] = f.read()
    # No line break after the last key, as in Square Enix's block. The gaps
    # carry their tool's 0x43218765 fill pattern, phased so that it reads
    # 65 87 21 43 from the start of the first gap.
    text = ("BOOT2 = cdrom0:" + chr(92) + "%s;1" + CRLF + "VER = %s" + CRLF
            + "VMODE = NTSC" + CRLF + "HDDUNITPOWER = NICHDD")
    text = text % (disc_boot_name(title.product), ver)
    boot = text.encode("ascii")
    pat = bytes((0x65, 0x87, 0x21, 0x43))
    base = (attrarea.SLOT_BOOT + len(boot)) % 4
    fill = pat[-base:] + pat[:-base] if base else pat
    area = attrarea.build_area(boot, parts["icon.sys"],
                               parts["kel_hdd.ico"], parts["kel_hdd2.ico"],
                               icon_off=DISC_ICON_OFF, copy_off=DISC_COPY_OFF,
                               fill=fill)
    return area, "install/icon.sys + kel_hdd.ico + kel_hdd2.ico"


def fill(image, title, src_dir, write=False, force=False):
    """Format and populate the title's partition. Returns (lba, stats)."""
    try:
        lba, sectors = apa.find_partition(image, title.partition)
    except KeyError:
        raise SystemExit(
            "%s: no partition named %s.\nCreate it first - on a PSBBN drive "
            "that is pfsshell's `mkpart %s %dM PFS`."
            % (image, title.partition, title.partition, title.need_mib))

    # The title table is the allow-list of partition names this writer will
    # touch.
    if title.key not in titles.TITLES:
        raise SystemExit("%s is not a title this installer knows" % title.key)

    # The partition exists, but it may extend past the end of the APA region.
    # Formatting it would then write over whatever is really there.
    ok, why = jail.check(image, lba, sectors)
    if not ok:
        raise SystemExit("%s: refusing to write - %s" % (title.partition, why))

    # pfsshell splits anything past the drive's main-partition ceiling into
    # a main partition plus APA sub-partitions, with one volume spanning them
    # all. This writer lays out single partitions only. pfsshell puts the
    # files on a split one (see pfsput.py) and --populated finishes the job.
    with open(image, "rb") as f:
        f.seek(0, os.SEEK_END)
        subs = polnetdump.sub_partitions(f, f.tell()).get(lba)
    if subs:
        raise SystemExit(
            "%s spans %d sub-partition(s), which this writer does not lay "
            "out. Put the files with pfsshell (python3 -m playonline.pfsput) "
            "and run again with --populated." % (title.partition, len(subs)))

    sources = sources_for(title, src_dir)
    extras_tmp = tempfile.mkdtemp(prefix="playonline-extras-")
    extras = make_extras(title, src_dir, extras_tmp)
    if extras:
        sources.append((extras_tmp, ""))
    need = sum(_tree_bytes(d) for d, _dest in sources)
    have = sectors * SECTOR
    if need > have:
        raise SystemExit("%s holds %d MiB, the staged tree is %.1f MiB"
                         % (title.partition, sectors // 2048, need / 1048576.0))

    mode = "r+b" if write else "rb"
    with open(image, mode) as f:
        formatted, _why = polrealfill.superblock_ok(f, lba)
        if formatted and not force:
            raise SystemExit("%s is already formatted; pass --force to "
                             "overwrite what is on it" % title.partition)
        if write:
            polpfs.format_partition(f, lba, sectors)
        try:
            _part, stats = polrealfill.populate(f, lba, sectors, sources, write)
        finally:
            shutil.rmtree(extras_tmp, ignore_errors=True)
    return lba, stats, extras


def make_extras(title, src_dir, tmp):
    """Build the entries Square Enix's installer creates instead of copying.

    The root of an installed Viewer partition has three things the disc's
    tree does not supply:

        installed            a zero-byte marker
        pub/all/install.inf  a copy of the disc's default/pub/all/install.inf
        usr/all/             where the Viewer writes its own settings

    Without `install.inf` the Viewer stops with error POL-1155. `usr/all` is
    created empty to match an installed drive.
    """
    # Only the Viewer partition has these. Square Enix's partitions for the
    # other titles carry no `installed` marker and no `usr/all`.
    if not title.layout or title.boot == "NOBOOT" or title.tree != "POL/":
        return None
    made = []
    open(os.path.join(tmp, "installed"), "wb").close()
    made.append("installed")

    default_inf = os.path.join(src_dir, "POL", "install", "PS2", "default",
                               "pub", "all", "install.inf")
    if os.path.exists(default_inf):
        dst = os.path.join(tmp, "pub", "all")
        os.makedirs(dst)
        with open(default_inf, "rb") as a, open(os.path.join(dst, "install.inf"), "wb") as b:
            b.write(a.read())
        made.append("pub/all/install.inf")
    os.makedirs(os.path.join(tmp, "usr", "all"))
    made.append("usr/all/")
    return made


def sources_for(title, src_dir):
    """[(absolute path, destination)] for populate, from the title's layout.

    A staged tree is not a flat image of the partition. The Viewer's
    partition root, for example, is `POL/install/PS2`, while `POL/Data/PS2`
    goes to `V` and `POL/ps2drv` to `ps2drv`. The title's layout table holds
    that mapping.
    """
    out = []
    for sub, dest in title.layout:
        path = os.path.join(src_dir, sub.replace("/", os.sep))
        if not os.path.isdir(path):
            raise SystemExit(
                "%s: staged tree has no %s.\n"
                "Stage it with `python3 -m playonline.stage DISC "
                "--title %s --out %s` first."
                % (src_dir, sub, title.key, src_dir))
        out.append((path, dest))
    return out


def _tree_bytes(src_dir):
    total = 0
    for dp, _dn, fns in os.walk(src_dir):
        for fn in fns:
            total += os.path.getsize(os.path.join(dp, fn))
    return total


def main():
    # Some titles are named in Japanese and a Windows console may not be able
    # to show them. Printing a name must never abort a build.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image", help="a drive image, or a device the caller owns")
    ap.add_argument("--title", required=True)
    ap.add_argument("--src", help="a staging directory from playonline.stage")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="overwrite a partition that is already formatted")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--populated", action="store_true",
                    help="the files are already on the partition (pfsshell put "
                         "them, see playonline.pfsput); write the header "
                         "password and the browser entry only")
    ap.add_argument("--icon", metavar="FILE",
                    help="build the browser entry around this icon instead "
                         "of using Square Enix's prebuilt one")
    ap.add_argument("--disc", metavar="IMAGE",
                    help="the disc, if the prebuilt browser entry is not in "
                         "the staged tree (it never is on an archive disc)")
    ap.add_argument("--ver", default="1.00",
                    help="the VER field Square Enix's installer sets "
                         "(default 1.00)")
    ap.add_argument("--original-titles", action="store_true",
                    help="keep Square Enix's browser title where this "
                         "project has an English name for it")
    ap.add_argument("--no-attr", action="store_true",
                    help="skip the attribute area (the browser will show "
                         "Corrupted Data)")
    args = ap.parse_args()

    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    title = titles.TITLES[args.title]

    try:
        lba, sectors = apa.find_partition(args.image, title.partition)
    except KeyError:
        sys.exit("%s: no partition named %s" % (args.image, title.partition))
    except (IOError, OSError, ValueError) as e:
        sys.exit("%s: %s" % (args.image, e))
    print("%s at LBA %d, %d MiB" % (title.partition, lba, sectors // 2048))

    if args.verify:
        if not args.src:
            sys.exit("--verify needs --src")
        # The installer-created entries have to be in the comparison too, or
        # they are reported as "extra on disc".
        sources = sources_for(title, args.src)
        tmp = tempfile.mkdtemp(prefix="playonline-extras-")
        try:
            if make_extras(title, args.src, tmp):
                sources.append((tmp, ""))
            with open(args.image, "rb") as f:
                ok = polrealfill.verify(f, lba, sectors, sources)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        area = attrarea.read_area(args.image, lba)
        print("attribute area: %s"
              % ("%d B" % len(area) if area else "absent - the browser will "
                 "show Corrupted Data"))
        if area:
            s = attrarea.slots(area)
            print("  %s" % s[1][2].decode(title.encoding, "replace")
                  .split("\r\n")[1])
        sys.exit(0 if ok else 1)

    if not args.src:
        sys.exit("--src is required unless --verify")

    if args.populated:
        # pfsshell put the files (see pfsput.py); what is left is the header
        # and the browser entry, which pfsshell does not write.
        try:
            lba, _sectors = apa.find_partition(args.image, title.partition)
        except KeyError:
            sys.exit("%s: no partition named %s" % (args.image, title.partition))
        formatted, why = polrealfill.superblock_ok(open(args.image, "rb"), lba)
        if not formatted:
            sys.exit("%s: --populated, but no PFS volume is on it (%s)"
                     % (title.partition, why))
        print("  files already on it (pfsshell), not touched")
    else:
        lba, stats, extras = fill(args.image, title, args.src, args.write, args.force)
        print("%s %d file(s), %d dir(s), %.1f MiB"
              % ("wrote" if args.write else "would write",
                 stats["files"], stats["dirs"], stats["bytes"] / 1048576.0))
        if extras:
            print("  plus what the installer creates: %s" % ", ".join(extras))

    # `pfsshell mkpart` leaves the header's password fields zero, and a title
    # mounts its own partition by name and password, so without this the
    # title starts and then stops at the mount. Only `fpwd` is set; see
    # password.py for why `rpwd` is not needed.
    from . import password
    password.apply(args.image, title, write=args.write)

    if args.no_attr:
        print("attribute area skipped")
        return

    # A title the browser launches from its disc carries no prebuilt entry;
    # its pieces are in the staged tree and the block points at the disc.
    if title.boot == "DISC" and not args.icon:
        area, where = disc_boot_area(title, args.src, args.ver if args.ver != "1.00" else "1.01")
        if area is None:
            print("no browser entry for %s: %s" % (title.key, where))
            return
        from . import drive
        print("attribute area: %d B, assembled from %s" % (len(area), where))
        print("  %s" % drive.write_area(args.image, lba, area, write=args.write))
        return

    # Square Enix ships the finished browser entry on the disc, so prefer
    # theirs and change only what their installer changes. Building one is
    # the fallback.
    if not args.icon:
        disc = None
        if args.disc:
            try:
                disc = discs.identify(args.disc)
            except discs.NotADisc as e:
                print("  (%s)" % e)
        where, area = prebuilt.find(title, args.src, disc)
        if area:
            area = attrarea.set_ver(area, args.ver)
            renamed = ""
            if title.title0_en and not args.original_titles:
                area = attrarea.set_title(area, title.title0_en,
                                          encoding=title.encoding)
                renamed = ", renamed %s -> %s" % (title.title0, title.title0_en)
            print("attribute area: %d B, Square Enix's own, from %s "
                  "(VER = %s)%s" % (len(area), where, args.ver, renamed))
            from . import drive
            print("  %s" % drive.write_area(args.image, lba, area,
                                            write=args.write))
            return

    if args.icon:
        with open(args.icon, "rb") as f:
            icon, where = f.read(), args.icon
    else:
        icon, where = _icon_for(title, args.src)
    if not icon:
        print("no icon for %s: its browser icon is not on any disc read here."
              % title.key)
        print("  Pass --icon FILE, or the partition will read as Corrupted "
              "Data in the browser.")
        return

    area = attribute_area(title, icon)
    from . import drive
    print("attribute area: %d B, icon from %s" % (len(area), where))
    print("  %s" % drive.write_area(args.image, lba, area, write=args.write))


if __name__ == "__main__":
    main()

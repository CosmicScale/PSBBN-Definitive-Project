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
"""Command line for the PlayOnline step.

    python3 -m playonline status                  routes and title status
    python3 -m playonline titles                  the installable table
    python3 -m playonline discs PATH ...          identify disc images
    python3 -m playonline sources PATH ...        the best disc for each title
    python3 -m playonline size --src DIR --title KEY [--drive DRIVE]
    python3 -m playonline inspect DRIVE           what is on a drive already
    python3 -m playonline preflight DRIVE         both partition tables, free space
    python3 -m playonline plan DRIVE --disc ...   what an install would do
    python3 -m playonline attrarea ...            build or check an attribute area

None of these verbs writes to a drive. Installing is the shell step,
scripts/PlayOnline-Installer.sh, which drives stage, route, build and netpart
in that order. The module route it uses is decided per Viewer build (see
prepare.py).
"""
import argparse
import os
import sys

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from playonline import __version__, apa, attrarea, prepare, titles  # noqa: E402


def _open_failed(path, err):
    """Say why a drive would not open, including the two usual reasons.

    An image locked by an emulator and a real read failure otherwise look
    identical.
    """
    msg = "%s: %s" % (path, err)
    if isinstance(err, PermissionError):
        msg += ("\n  An emulator holding this image open takes it exclusively;"
                "\n  close it first. A raw device instead needs sudo.")
    return msg


def cmd_status(args):
    print("PlayOnline installer %s" % __version__)
    print()
    print("Module preparation routes:")
    print(prepare.describe())
    print()
    print("Titles:")
    tested = titles.by_status("tested")
    installs = titles.by_status("installs")
    unsupported = titles.by_status("unsupported")
    print("  %d tested, %d installs, %d unsupported"
          % (len(tested), len(installs), len(unsupported)))
    for t in tested:
        print(("    tested:  %s  %s" % (t.key, t.note)).rstrip())


def cmd_titles(args):
    if args.plain:
        # Machine-readable, for the shell step to drive. One title per line:
        # key|partition|need_mib|tree|status
        for t in sorted(titles.TITLES.values(), key=lambda t: t.key):
            print("%s|%s|%d|%s|%s" % (t.key, t.partition, t.need_mib,
                                      t.tree or "", t.status))
        return
    print(titles.summary())
    print()
    for key in sorted(titles.DISCS):
        d = titles.DISCS[key]
        print("%-14s %-12s %s" % (key, d["product"], d["name"]))
        print("%-14s supplies: %s" % ("", ", ".join(d["supplies"])))
        if d.get("note"):
            print("%-14s note: %s" % ("", d["note"]))


def cmd_discs(args):
    from . import discs as discmod, stage
    import os
    paths = []
    for p in args.paths:
        if os.path.isdir(p):
            paths += discmod.images_in(p)
        else:
            paths.append(p)
    found, failed = discmod.scan(paths)
    for d in found:
        supplies = ",".join(t.key for t in stage.sources(d))
        # A disc can carry more than one container, so list them all.
        carries = "+".join(d.containers)
        if args.plain:
            print("%s|%s|%s|%s|%s" % (d.path, d.code, d.key or "",
                                      carries, supplies))
        else:
            name = titles.DISCS[d.key]["name"] if d.known else "unrecognised"
            print("%-12s %-34s %s" % (d.code, name[:34], carries or "-"))
            print("%-12s supplies: %s" % ("", supplies or "nothing"))
    if not args.plain:
        for path, why in failed:
            print("skipped      %s" % why)


def cmd_sources(args):
    """Pick the best disc for each title the user has, and say why.

    When two discs supply the same title, the one with the newer build wins
    (a later Vana'diel Collection carries a newer Viewer than the standalone
    Viewer disc, for example). Builds are date-stamped (`20070802_2`), so a
    plain string comparison orders them correctly.
    """
    from . import discs as discmod, stage
    import os
    paths = []
    for p in args.paths:
        if os.path.isdir(p):
            paths += discmod.images_in(p)
        else:
            paths.append(p)
    found, _failed = discmod.scan(paths)
    allowed = None
    if getattr(args, "region", None):
        allowed = set(titles.LAUNCHES["viewer-" + args.region])

    best = {}
    for d in found:
        for t in stage.sources(d):
            if allowed is not None and t.key not in allowed:
                continue
            try:
                ver, build = stage.version_of(d, t)
            except (ValueError, IOError, OSError):
                ver, build = None, None
            key = ver or ""
            if t.key not in best or key > best[t.key][1]:
                best[t.key] = (d, key, build)

    for tkey in sorted(best):
        d, ver, build = best[tkey]
        t = titles.TITLES[tkey]
        if args.plain:
            print("%s|%s|%s|%d|%s|%s|%s"
                  % (tkey, d.path, t.partition, t.need_mib, t.status,
                     ver or "", build or ""))
        else:
            print("  %-16s %-30s %-11s %-9s %s"
                  % (tkey, t.partition, ver or "-", build or "-",
                     os.path.basename(d.path)))
    if not best and not args.plain:
        print("  no disc supplies a title this installer can add")


def _tail_room(drive):
    """The largest partition, in MiB, that fits after the last one. 0 if none.

    Free space on an APA drive is not only the type-0 entries. The span
    between the end of the last partition and the end of the APA region has
    no entry at all, and it is where `mkpart` puts a new partition when no
    free entry holds it. On a fresh PSBBN install that is nearly all of the
    free space.

    A partition starts on a multiple of its own size, so the room is what is
    left after rounding the start up. pfsshell may split the request into a
    main partition and sub-partitions, which need less alignment than this
    assumes, so the estimate is conservative. On a drive with a PC partition
    table the limit is the end of the APA region, because the exFAT partition
    that holds the user's games lies beyond it.
    """
    import os
    from . import apa, jail
    parts = apa.partitions(drive)
    if not parts:
        return 0
    last_end = max(p.lba + p.sectors for p in parts)
    region = jail.apa_region(drive)
    if region:
        end = region[0] + region[1]
    else:
        with open(drive, "rb") as f:
            f.seek(0, os.SEEK_END)
            end = f.tell() // 512
    best = 0
    size = titles.GRANULE_MIB
    while size <= titles.MAX_MIB:
        sectors = size * 2048
        start = (last_end + sectors - 1) // sectors * sectors
        if start + sectors <= end:
            best = size
        size *= 2
    return best


def cmd_size(args):
    """What size partition this staged title needs."""
    import os
    from . import apa, jail
    total = 0
    for dirpath, _dirs, files in os.walk(args.src):
        for name in files:
            total += os.path.getsize(os.path.join(dirpath, name))
    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    t = titles.TITLES[args.title]

    free = []
    if args.drive:
        try:
            for p in apa.free_entries(args.drive):
                ok, _why = jail.check(args.drive, p.lba, p.sectors)
                if ok:
                    free.append(p.mib)
            tail = _tail_room(args.drive)
            if tail:
                free.append(tail)
        except (IOError, OSError, ValueError) as e:
            sys.exit(_open_failed(args.drive, e))

    size, why = titles.choose_size(total, free, prefer=t.se_mib)
    if args.plain:
        print(size if size else "")
        return
    print("%s: %.1f MiB staged" % (t.key, total / 1048576.0))
    if free:
        print("free entries inside the APA region: %s"
              % ", ".join("%d" % m for m in sorted(free, reverse=True)[:8]))
    if size is None:
        sys.exit("no partition can be made: %s" % why)
    print("partition: %d MiB (%s)" % (size, why))


def cmd_inspect(args):
    try:
        print(apa.describe(args.drive))
    except (IOError, OSError, ValueError) as e:
        sys.exit(_open_failed(args.drive, e))
    print()
    found = apa.installed_titles(args.drive)
    known = {t.partition: t for t in titles.TITLES.values()}
    if not found:
        print("no PP.* game partitions")
    for p in found:
        t = known.get(p.ident)
        if t:
            print("  %s  %s, %d MiB, route status %s"
                  % (p.ident, t.key, p.mib, t.status))
        else:
            print("  %s  not a title this installer knows" % p.ident)
        area = attrarea.read_area(args.drive, p.lba)
        if area is None:
            print("      no attribute area: the browser will show Corrupted Data")
        else:
            print("      attribute area %d B" % len(area))
    free = apa.free_entries(args.drive)
    if free:
        print()
        print("free entries: %s" % ", ".join("%d MiB" % p.mib for p in free[:8]))


def cmd_preflight(args):
    """Read-only summary of a drive before an install."""
    from . import jail, netpart
    print("DRIVE %s" % args.drive)
    print()
    print("PC partition table:")
    try:
        print(jail.describe(args.drive))
    except (IOError, OSError) as e:
        sys.exit(_open_failed(args.drive, e))
    print()
    print("PS2 partition table:")
    try:
        print(apa.describe(args.drive))
    except (IOError, OSError, ValueError) as e:
        sys.exit(_open_failed(args.drive, e))
    print()

    found = apa.installed_titles(args.drive)
    known = {t.partition: t for t in titles.TITLES.values()}
    print("PlayOnline partitions already there: %s"
          % (", ".join(p.ident for p in found) if found else "none"))
    net = netpart.present(args.drive)
    print("__net: %s" % ("LBA %d, %d MiB" % (net[0], net[1] // 2048) if net
                         else "absent - the installer would create it"))
    print()

    free = apa.free_entries(args.drive)
    region = jail.apa_region(args.drive)
    usable = []
    for p in free:
        ok, _why = jail.check(args.drive, p.lba, p.sectors)
        usable.append((p, ok))
    print("free APA entries: %d" % len(free))
    for p, ok in usable[:12]:
        print("   LBA %-12d %6d MiB  %s"
              % (p.lba, p.mib, "usable" if ok else "outside the APA region - will not be touched"))
    if region:
        inside = sum(p.mib for p, ok in usable if ok)
        print("   %d MiB of free space inside the APA region" % inside)
    print()
    print("Nothing was written. This command only reads.")


def cmd_plan(args):
    if args.disc:
        unknown = [d for d in args.disc if d not in titles.DISCS]
        if unknown:
            sys.exit("unknown disc key(s): %s\nknown: %s"
                     % (", ".join(unknown), ", ".join(sorted(titles.DISCS))))
        wanted = []
        for d in args.disc:
            wanted += titles.for_disc(d)
    else:
        wanted = list(titles.TITLES.values())

    print("route: %s" % args.route)
    b = prepare.BACKENDS[args.route]
    print("  %s" % b["status"])
    if b["needs_hddid"]:
        print("  this route keys the modules to a minted HDD ID; on a generic")
        print("  drive the loader's shim must serve that same ID back.")
    print()

    try:
        existing = {p.ident for p in apa.installed_titles(args.drive)}
        free = apa.free_entries(args.drive)
    except (IOError, OSError, ValueError) as e:
        sys.exit(_open_failed(args.drive, e))

    budget = [p.mib for p in free]
    for t in wanted:
        if t.partition in existing:
            print("  %-16s already on the drive as %s" % (t.key, t.partition))
            continue
        fits = [i for i, mib in enumerate(budget) if mib >= t.need_mib]
        where = ("free entry of %d MiB" % budget[fits[0]]) if fits else None
        if fits:
            budget.pop(fits[0])
        print("  %-16s %-32s %5d MiB  %-8s %s"
              % (t.key, t.partition, t.need_mib, t.status,
                 where or "no free entry is large enough - pfsshell mkpart must carve one"))
    print()
    print("nothing was written: plan only")


def cmd_attrarea(args):
    sys.argv = ["playonline.attrarea"] + args.rest
    attrarea.main()


def main():
    ap = argparse.ArgumentParser(prog="playonline",
                                 description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd")

    sub.add_parser("status").set_defaults(func=cmd_status)
    p = sub.add_parser("titles")
    p.add_argument("--plain", action="store_true",
                   help="key|partition|need_mib|tree|status, for scripts")
    p.set_defaults(func=cmd_titles)

    p = sub.add_parser("discs")
    p.add_argument("paths", nargs="+")
    p.add_argument("--plain", action="store_true",
                   help="path|code|disc-key|format|titles, for scripts")
    p.set_defaults(func=cmd_discs)

    p = sub.add_parser("sources")
    p.add_argument("paths", nargs="+")
    p.add_argument("--region", choices=("us", "jp"),
                   help="only the titles that region's Viewer launches")
    p.add_argument("--plain", action="store_true",
                   help="key|disc|partition|need_mib|status|patch.ver|build")
    p.set_defaults(func=cmd_sources)

    p = sub.add_parser("size")
    p.add_argument("--src", required=True, help="a staging directory")
    p.add_argument("--title", required=True)
    p.add_argument("--drive", help="size against what is actually free there")
    p.add_argument("--plain", action="store_true", help="just the number")
    p.set_defaults(func=cmd_size)

    p = sub.add_parser("inspect")
    p.add_argument("drive")
    p.set_defaults(func=cmd_inspect)

    p = sub.add_parser("preflight")
    p.add_argument("drive")
    p.set_defaults(func=cmd_preflight)

    p = sub.add_parser("plan")
    p.add_argument("drive")
    p.add_argument("--disc", action="append", metavar="KEY",
                   help="a disc the user has, by key (see `titles`)")
    p.add_argument("--route", default=prepare.DEFAULT, choices=sorted(prepare.BACKENDS))
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("attrarea")
    p.add_argument("rest", nargs=argparse.REMAINDER)
    p.set_defaults(func=cmd_attrarea)

    args = ap.parse_args()
    if not getattr(args, "func", None):
        ap.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()

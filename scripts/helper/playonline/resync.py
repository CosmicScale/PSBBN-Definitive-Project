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
"""Bring an installed title up to what the current package installs.

The installer leaves a partition that is already on the drive alone, which
protects a user's saves but also keeps any file a later version of this
package would install differently. This module compares a freshly staged and
prepared tree with the partition, file by file, through the reader that
follows sub-partitions, and writes the pfsshell commands that close the gap:
`mkdir` for a missing directory, and `rm` then `put` for a file that is
missing or differs. It never removes anything the staged tree does not have,
because those files are the title's own: saves, settings, and whatever an
in-Viewer update brought.

    python3 -m playonline.resync DRIVE --title ffxi-us --src STAGED --out cmds
    sudo pfsshell < cmds

An empty command list (exit status 3, nothing written to `--out`) means the
partition already matches.
"""
import argparse
import os
import sys

from . import apa, build, pfsput, titles
from .lib import polfill, polnetdump, polpfsread, polrealfill

FIO_S_IFDIR = 0x1000


def staged_view(title, src_dir):
    """({partition path tuple: host file}, {directory tuples}) for the tree."""
    sources = build.sources_for(title, src_dir)
    tops, mounted = polrealfill.nest(sources)
    files, dirs = {}, set()

    def walk(host, at):
        with os.scandir(host) as it:
            for e in it:
                if e.is_dir():
                    dirs.add(at + (e.name,))
                    walk(e.path, at + (e.name,))
                elif e.is_file():
                    files[at + (e.name,)] = e.path

    for src, dest in tops:
        at = (dest,) if dest else ()
        if dest:
            dirs.add(at)
        walk(src, at)
        for name, (extra_src, _deeper) in (mounted.get(dest) or {}).items():
            dirs.add(at + (name,))
            walk(extra_src, at + (name,))
    return files, dirs


def drive_view(f, size, lba, sectors):
    """(part, {path tuple: inode}, {directory tuples}) for the partition."""
    subs = polnetdump.sub_partitions(f, size).get(lba)
    part, root = polpfsread.mount(f, lba, sectors, subs)
    if part is None:
        raise SystemExit("the partition did not mount")
    files, dirs = {}, set()

    def walk(ino, at, depth=0):
        for name, inode, sub, _flags in polfill.read_dir_full(part, ino):
            if name in (b".", b".."):
                continue
            child = polfill.read_inode(part, inode, sub)
            if not child["ok"]:
                continue
            here = at + (name.decode("latin-1"),)
            if child["mode"] & FIO_S_IFDIR:
                dirs.add(here)
                if depth < 24:
                    walk(child, here, depth + 1)
            else:
                files[here] = child

    walk(root, ())
    return part, files, dirs


def plan(image, title, src_dir):
    """(commands, report lines). Commands are empty when nothing differs."""
    want_files, want_dirs = staged_view(title, src_dir)
    lba, sectors = apa.find_partition(image, title.partition)
    with open(image, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        part, have_files, have_dirs = drive_view(f, size, lba, sectors)
        changed = []
        for path in sorted(want_files):
            host = want_files[path]
            ino = have_files.get(path)
            if ino is None:
                changed.append((path, "missing"))
                continue
            if ino["size"] != os.path.getsize(host):
                changed.append((path, "size %d -> %d" % (ino["size"], os.path.getsize(host))))
                continue
            with open(host, "rb") as h:
                if polfill.read_content(part, ino) != h.read():
                    changed.append((path, "content"))
    new_dirs = sorted(d for d in want_dirs if d not in have_dirs)
    report = ["%d file(s) and %d dir(s) staged, %d file(s) on the partition"
              % (len(want_files), len(want_dirs), len(have_files))]
    for d in new_dirs:
        report.append("  mkdir /%s" % "/".join(d))
    for path, why in changed:
        report.append("  put   /%s  (%s)" % ("/".join(path), why))
    if not new_dirs and not changed:
        return [], report + ["  nothing differs"]

    out = ["device %s" % image, "mount %s" % title.partition]
    for d in new_dirs:                       # sorted, so a parent comes first
        out.append("cd /%s" % "/".join(d[:-1]) if len(d) > 1 else "cd /")
        out.append("mkdir %s" % pfsput.quote(d[-1]))
    for path, why in changed:
        out.append("cd /%s" % "/".join(path[:-1]) if len(path) > 1 else "cd /")
        out.append("lcd %s" % pfsput.quote(pfsput.host_path(os.path.dirname(want_files[path]))))
        if why != "missing":
            out.append("rm %s" % pfsput.quote(path[-1]))
        out.append("put %s" % pfsput.quote(os.path.basename(want_files[path])))
    out += ["umount", "exit"]
    return out, report


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--title", required=True)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", help="write the pfsshell commands here")
    args = ap.parse_args()
    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    cmds, report = plan(args.drive, titles.TITLES[args.title], args.src)
    for line in report:
        print(line)
    if not cmds:
        return 3
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(cmds) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

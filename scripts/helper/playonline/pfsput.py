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
"""Write the pfsshell commands that put one staged title onto its partition.

Files go onto the drive through pfsshell because of the partition's shape.
`mkpart` caps a main partition at the drive's ceiling (a 32nd of the APA
area, rounded down to a power of two: 2 GiB on the 128 GiB area PSBBN leaves
the console) and lays the rest out as APA sub-partitions. An 8192 MiB FFXI
partition is a 2 GiB main plus three 2 GiB subs, with one PFS volume across
all four, which is also how Square Enix's installer shapes it. This
package's own writer (`polrealfill`) handles single partitions only, so
pfsshell is the one path that covers both cases.

Each `(staged subtree, partition directory)` pair of the title's layout
becomes `mkdir`/`cd`, then one `lcd` per host directory with a `put` per
file. Nested mounts (the Viewer's `ps2drv/kbd`) and the entries the
installer creates rather than copies (`installed`, `pub/all/install.inf`,
`usr/all`) come from the same functions the writer uses, so both paths
produce the same tree.

    python3 -m playonline.pfsput /dev/sdX --title viewer-us --src DIR --extras DIR > cmds
    sudo pfsshell < cmds
    python3 -m playonline.build /dev/sdX --title viewer-us --src DIR --populated --write
    python3 -m playonline.build /dev/sdX --title viewer-us --src DIR --verify

`--extras` is a directory this module fills with the created entries. It
must still exist when pfsshell runs, so the caller owns it.
"""
import argparse
import os
import sys

from . import build, titles
from .lib import polrealfill


def quote(name):
    """A pfsshell argument. Its reader honours single and double quotes."""
    if "'" in name and '"' in name:
        raise ValueError("%r holds both kinds of quote; pfsshell cannot be "
                         "told that name" % name)
    if "'" in name:
        return '"%s"' % name
    if any(c in name for c in " \t\"") or not name:
        return "'%s'" % name
    return name


def host_path(path):
    """The path pfsshell's `lcd` gets: absolute, forward slashes."""
    return os.path.abspath(path).replace(os.sep, "/")


def emit_tree(out, host_dir, extra=None, stats=None):
    """Commands that reproduce `host_dir` in pfsshell's current directory.

    `extra` maps a name to a source directory mounted at that name inside
    this one, the shape `polrealfill.nest` returns.
    """
    with os.scandir(host_dir) as it:
        entries = sorted(it, key=lambda e: e.name)
    files = [e for e in entries if e.is_file()]
    dirs = [e for e in entries if e.is_dir()]
    if files:
        out.append("lcd %s" % quote(host_path(host_dir)))
        for e in files:
            out.append("put %s" % quote(e.name))
    for e in dirs:
        out.append("mkdir %s" % quote(e.name))
        out.append("cd %s" % quote(e.name))
        emit_tree(out, e.path, None, stats)
        out.append("cd ..")
    for name in sorted(extra or {}):
        src, _deeper = extra[name]
        out.append("mkdir %s" % quote(name))
        out.append("cd %s" % quote(name))
        emit_tree(out, src, None, stats)
        out.append("cd ..")
    if stats is not None:
        stats["files"] += len(files)
        stats["dirs"] += len(dirs) + len(extra or {})
        stats["bytes"] += sum(e.stat().st_size for e in files)


def commands(device, title, src_dir, extras_dir):
    """The whole pfsshell session for `title`, and what it will write."""
    sources = build.sources_for(title, src_dir)
    extras = build.make_extras(title, src_dir, extras_dir)
    if extras:
        sources.append((extras_dir, ""))
    tops, mounted = polrealfill.nest(sources)
    out = ["device %s" % device, "mount %s" % title.partition]
    stats = {"files": 0, "dirs": 0, "bytes": 0}
    for src, dest in tops:
        if dest:
            out.append("mkdir %s" % quote(dest))
            out.append("cd %s" % quote(dest))
            emit_tree(out, src, mounted.get(dest), stats)
            out.append("cd ..")
            stats["dirs"] += 1
        else:
            emit_tree(out, src, None, stats)
    out += ["umount", "exit"]
    return out, stats, extras


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("device", help="what pfsshell's `device` command gets")
    ap.add_argument("--title", required=True)
    ap.add_argument("--src", required=True, help="a staging directory from playonline.stage")
    ap.add_argument("--extras", required=True,
                    help="an existing, empty directory for the entries the "
                         "installer creates; keep it until pfsshell has run")
    ap.add_argument("--out", help="write the commands here instead of stdout")
    args = ap.parse_args()

    if args.title not in titles.TITLES:
        sys.exit("unknown title %r" % args.title)
    if not os.path.isdir(args.extras):
        sys.exit("--extras %s is not a directory" % args.extras)
    try:
        out, stats, extras = commands(args.device, titles.TITLES[args.title],
                                      args.src, args.extras)
    except ValueError as e:
        sys.exit(str(e))
    text = "\n".join(out) + "\n"
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    sys.stderr.write("%d command(s): %d file(s), %d dir(s), %.1f MiB%s\n"
                     % (len(out), stats["files"], stats["dirs"],
                        stats["bytes"] / 1048576.0,
                        (", plus " + ", ".join(extras)) if extras else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())

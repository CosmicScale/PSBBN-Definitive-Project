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
"""Where a file out of a disc container is allowed to land.

Square Enix's containers do not all hold plain relative paths. FFXI's MISC
records use `../../` deliberately: those entries leave `image/ffxi/` so that
`res/` lands at the root of the partition, where `config.sys` and `info.sys`
belong. Refusing `..` would drop them, and joining them unchecked could
write outside the output directory. The rule is therefore containment:
resolve the path against the output root and require the result to stay
under it.
"""
import os


def safe_join(root, path):
    """`root` joined with `path`, or ValueError if that leaves `root`."""
    root = os.path.abspath(root)
    dst = os.path.abspath(os.path.join(root, path.replace("/", os.sep)))
    if dst != root and not dst.startswith(root + os.sep):
        raise ValueError("%s would be written outside %s" % (path, root))
    return dst


def write(root, path, blob):
    """Write `blob` at `path` under `root`, making the directories."""
    dst = safe_join(root, path)
    parent = os.path.dirname(dst)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(dst, "wb") as f:
        f.write(blob)
    return dst

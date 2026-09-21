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
"""Writes inside a partition the toolkit has already created.

This package does not bring its own partition editor to a PSBBN drive. The
toolkit already carries pfsshell, hdl_dump and pfs-fuse, runs them under
sudo against the whole device, and owns the APA-Jail layout that lets its
exFAT region coexist. A second writer with its own view of the partition
table would put the drive at risk. The work is divided as follows:

    partition table, format, file copy   the toolkit's pfsshell / hdl_dump
    attribute area, container, modules   this package, at byte offsets inside
                                         a partition that already exists

Title partitions are created only by pfsshell's `mkpart NAME SIZE PFS`. The
one exception is `__net`, which netpart.py creates when it is missing.

Nothing here writes unless `write=True` is passed explicitly.
"""
import os

SECTOR = 512


def backup_path(path, lba):
    """Where to save what a write is about to replace.

    For an image, beside the file. For a device that would mean a file in
    /dev, which is lost on reboot, so the backup goes in
    `PLAYONLINE_BACKUP_DIR` or the working directory instead.
    """
    name = "%s.attr-%d.bak" % (os.path.basename(path), lba)
    if os.path.isfile(path):
        return "%s.attr-%d.bak" % (path, lba)
    return os.path.join(os.environ.get("PLAYONLINE_BACKUP_DIR", os.getcwd()), name)


def write_area(path, lba, area, write=False, backup=True):
    """Put an attribute area at partition + 0x1000.

    A plain sector write inside a partition that already exists. The APA
    header at + 0x0000 is outside the range touched, and the write refuses
    to reach the PFS superblock at + 0x400000.
    """
    from . import attrarea
    if len(area) > 0x400000 - attrarea.ATTR_OFF:
        raise ValueError("area would reach the PFS superblock")
    if len(area) % SECTOR:
        raise ValueError("area is not a whole number of sectors")
    off = lba * SECTOR + attrarea.ATTR_OFF
    if not write:
        return "would write %d B at LBA %d + 0x%x" % (len(area), lba, attrarea.ATTR_OFF)
    saved = None
    # PLAYONLINE_NO_ATTR_BACKUP is for a drive built from nothing, which has
    # no earlier entry worth keeping.
    if backup and not os.environ.get("PLAYONLINE_NO_ATTR_BACKUP"):
        with open(path, "rb") as f:
            f.seek(off)
            old = f.read(len(area))
        saved = backup_path(path, lba)
        with open(saved, "wb") as f:
            f.write(old)
    with open(path, "r+b") as f:
        f.seek(off)
        f.write(area)
    return "wrote %d B at LBA %d%s" % (len(area), lba,
                                       "; previous saved to %s" % saved if saved else "")

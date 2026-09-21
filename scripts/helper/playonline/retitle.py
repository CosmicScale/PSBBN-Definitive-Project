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
"""Show the Japan-only titles under English names on an English install.

Janhourou, Dirge of Cerberus and Front Mission Online were released only in
Japan, and the US Viewer launches all three. Their names are shown from two
places, neither of which the game itself reads:

    the browser entry   `icon.sys` in the partition's attribute area:
                        `title0`, `title1` and the three `uninstallmes`
                        lines. Shown by HDD-OSD and the Sony browser.
    `/res/info.sys`     `title`, `genre` and `note`. Shown by PSBBN's game
                        list.

On a drive installed for the US Viewer both are rewritten in place on
whichever of those partitions exist. A Japanese install is left unchanged.

The browser entry keeps its exact size. The English text is shorter than the
UTF-8 Japanese, and the difference is made up with trailing spaces on the
last line changed (Square Enix's own entries carry trailing spaces too), so
no slot or offset moves. `info.sys` is rewritten inside the zones it already
has, with the inode's size and checksum updated, through a reader that
follows sub-partitions because `/res` can sit in any of them.

`info.sys` is also a row in each title's `file.txt`. Its hash there is left
alone: nothing checks it at launch, and changing the manifest would make the
patch client see a difference from the server's copy.

    python3 -m playonline.retitle DRIVE            # what it would change
    python3 -m playonline.retitle DRIVE --write
"""
import argparse
import os
import re
import struct
import sys

from . import apa, attrarea, drive, titles
from .lib import polfill, polnetdump, polpfsread

INFO_PATH = ("res", "info.sys")

#: title key -> the English text for each place a name is shown.
ENGLISH = {
    # JongHoLow is the English name the PrettyOpenLobby community server uses
    # for the title; `--original-titles` keeps Square Enix's.
    "janhourou-jp": {
        "icon": {"title0": "JongHoLow"},
        "info": {"title": "JongHoLow",
                 "genre": "Mahjong",
                 "note": "Network mahjong with chat, as if you were all "
                         "sitting around the same table."},
    },
    "dirge-jp": {
        "icon": {"title0": "Dirge of Cerberus",
                 "title1": "-FFVII-",
                 "uninstallmes0": "Multiplayer character data stays on",
                 "uninstallmes1": "the server, but to play again you",
                 "uninstallmes2": "will need to install once more."},
        "info": {"title": "Dirge of Cerberus -FFVII-",
                 "genre": "Gun Action RPG"},
    },
    "fmo-jp": {
        "icon": {"title0": "FRONT MISSION",
                 "title1": "ONLINE",
                 "uninstallmes0": "Delete FRONT MISSION ONLINE?",
                 "uninstallmes1": "Saved data will be lost, but your",
                 "uninstallmes2": "character data will not be."},
        "info": {"title": "FRONT MISSION ONLINE",
                 "genre": "Tactical Role-Playing Action"},
    },
}

_FIELD = re.compile(r"^([A-Za-z0-9_]+)(\s*=\s*)(.*?)(\r?)$")


def set_fields(text, fields):
    """(new text, [keys changed], last key changed). Line endings are kept."""
    out, changed, last = [], [], None
    for line in text.split("\n"):
        m = _FIELD.match(line)
        if m and m.group(1) in fields and m.group(3).rstrip() != fields[m.group(1)].rstrip():
            line = "%s%s%s%s" % (m.group(1), m.group(2), fields[m.group(1)], m.group(4))
            changed.append(m.group(1))
            last = m.group(1)
        out.append(line)
    return "\n".join(out), changed, last


def _pad_line(text, key, n):
    """`text` with `n` spaces added to the end of `key`'s value."""
    out = []
    for line in text.split("\n"):
        m = _FIELD.match(line)
        if m and m.group(1) == key and n:
            line = "%s%s%s%s%s" % (m.group(1), m.group(2), m.group(3), " " * n, m.group(4))
            n = 0
        out.append(line)
    return "\n".join(out)


def area_in_english(area, fields, encoding="utf-8"):
    """(new area, [keys changed]). The area keeps its size and layout."""
    s = attrarea.slots(area)
    old = s[1][2]
    text = old.decode(encoding)
    new_text, changed, last = set_fields(text, fields)
    if not changed:
        return area, []
    new = new_text.encode(encoding)
    if len(new) < len(old):
        new = _pad_line(new_text, last, len(old) - len(new)).encode(encoding)
    if len(new) == len(old):
        patched = bytearray(area)
        patched[s[1][0]:s[1][0] + len(new)] = new
        return bytes(patched), changed
    # The new text is longer than the old (no entry in ENGLISH is): rebuild
    # the area instead of patching it in place.
    same_icon = (s[2][0], s[2][1]) == (s[3][0], s[3][1])
    return attrarea.build_area(s[0][2], new, s[2][2],
                               None if same_icon else s[3][2],
                               icon_off=s[2][0],
                               copy_off=None if same_icon else s[3][0]), changed


# ---- /res/info.sys, in place, sub-partitions followed ----------------------
def _find(part, root, names):
    """(zone, sub, inode) of a path given as a tuple of names, or None."""
    ino, zone, sub = root, None, 0
    for want in names:
        hit = None
        for name, inode, isub, _flags in polfill.read_dir_full(part, ino):
            if name.decode("ascii", "replace") == want:
                hit = (inode, isub)
                break
        if hit is None:
            return None
        zone, sub = hit
        ino = polfill.read_inode(part, zone, sub)
        if not ino["ok"]:
            return None
    return zone, sub, ino


def _replace(part, zone, sub, ino, data):
    """Rewrite a file inside the zones it already has."""
    cap = sum(cnt for _n, _s, cnt in ino["runs_full"]) * part.zone_size
    if len(data) > cap:
        raise ValueError("%d B does not fit the %d B the file has" % (len(data), cap))
    off = 0
    for number, rsub, count in ino["runs_full"]:
        room = count * part.zone_size
        chunk = data[off:off + room]
        # Rewrite the whole run, zero-filled past the new end, so none of
        # the longer Japanese text remains after the file's new size.
        part.f.seek(part.zone_sector(number, rsub) * 512)
        part.f.write(chunk + b"\0" * (room - len(chunk)))
        off += room
    pos = part.zone_sector(zone, sub) * 512
    part.f.seek(pos)
    b = bytearray(part.f.read(1024))
    field = 0x028 + polfill.PFS_INODE_MAX_BLOCKS * 8 + 32
    struct.pack_into("<Q", b, field, len(data))
    struct.pack_into("<I", b, 0, polfill.inode_checksum(b))
    part.f.seek(pos)
    part.f.write(bytes(b))
    part.f.flush()


def info_in_english(f, size, lba, sectors, fields, write):
    """Text describing what happened to this partition's /res/info.sys."""
    subs = polnetdump.sub_partitions(f, size).get(lba)
    part, root = polpfsread.mount(f, lba, sectors, subs)
    if part is None:
        return "info.sys: the partition did not mount"
    found = _find(part, root, INFO_PATH)
    if found is None:
        return "info.sys: none on this partition"
    zone, sub, ino = found
    old = polfill.read_content(part, ino)
    try:
        text = old.decode("utf-8")
    except UnicodeDecodeError:
        return "info.sys: not UTF-8, left alone"
    new_text, changed, _last = set_fields(text, fields)
    if not changed:
        return "info.sys: already English"
    new = new_text.encode("utf-8")
    if not write:
        return "info.sys: would set %s" % ", ".join(changed)
    _replace(part, zone, sub, ino, new)
    again = polfill.read_inode(part, zone, sub)
    if polfill.read_content(part, again) != new or not again["ok"]:
        raise SystemExit("info.sys: readback after the write does not match")
    return "info.sys: set %s (%d -> %d B, read back identical)" % (
        ", ".join(changed), len(old), len(new))


def retitle(image, write=False):
    """[(partition, [lines])] for every title here that has English names."""
    by_partition = {t.partition: t for t in titles.TITLES.values()
                    if t.key in ENGLISH}
    report = []
    for p in apa.installed_titles(image):
        t = by_partition.get(p.ident)
        if t is None:
            continue
        lines = []
        area = attrarea.read_area(image, p.lba)
        if area is None:
            lines.append("browser entry: none")
        else:
            new, changed = area_in_english(area, ENGLISH[t.key]["icon"])
            if not changed:
                lines.append("browser entry: already English")
            elif not write:
                lines.append("browser entry: would set %s" % ", ".join(changed))
            else:
                drive.write_area(image, p.lba, new, write=True, backup=False)
                lines.append("browser entry: set %s" % ", ".join(changed))
        with open(image, "r+b" if write else "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            lines.append(info_in_english(f, size, p.lba, p.sectors,
                                         ENGLISH[t.key]["info"], write))
            if write:
                f.flush()
                os.fsync(f.fileno())
        report.append((p.ident, lines))
    return report


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drive")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    report = retitle(args.drive, args.write)
    if not report:
        print("no Japan-only title on this drive")
    for ident, lines in report:
        print(ident)
        for line in lines:
            print("  " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

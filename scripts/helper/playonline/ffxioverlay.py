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
r"""Reconcile FFXI's menu overlay with what its own boot module asks for.

Vana'diel Collection 2008 pairs a boot module from 2004 (`FFXI_POL.ENC`)
with data from 2007. The module's init looks up a loaded resource of type 52
(a key-layout table) with id `key4` and quits when there is none; the Viewer
then reports `An error occurred. %s terminated.` The base menu file
`ROM/0/1.DAT` still carries `key3` and `key4`, but the menu overlay
`ROM/121/46.DAT` is loaded after it and supplies the effective set, and the
2007 overlay no longer has either entry. The 2004-era overlay has both, with
`key4` after `ncol`. The patch service that once reconciled the pair is
retired, so the title cannot start as shipped.

This module copies the missing entries byte for byte from the disc's own
`ROM/0/1.DAT` into the overlay after `ncol`, and changes nothing else in it.
It then rewrites the overlay's line in the partition's `file.txt` so Check
Files compares against what is installed. An overlay that already has the
entries is left alone.

Container format, as the boot module's parser reads it. Each entry is a
16-byte header followed by its data, 16-byte aligned:

    +0  id        4 bytes
    +4  u32       bits 0..6 = type, bits 7..25 = length in 16-byte units,
                  header included. The top bit of the type byte is the low
                  bit of the length and is not a flag: key4 reads 0xB4
                  because its length is an odd number of units.
    +8  8 bytes   zero

Type 1 opens a container, type 0 (`end`) closes it, and the parser stops when
the depth returns to zero.

    python3 -m playonline.ffxioverlay STAGED_DIR [--keep]
"""
import argparse
import os
import struct
import sys

from . import ffxidata

FFXI_ROOT = "image/ffxi"
#: File ids the boot module loads, and the paths the 2008 tables give them.
#: The tables are consulted first; these are the fallback.
BASE_ID, BASE_PATH = 1, "ROM/0/1.DAT"
OVERLAY_ID, OVERLAY_PATH = 78, "ROM/121/46.DAT"

TYPE_KEYLAYOUT = 52
#: Entries the 2004 module looks up in the effective menu set: `key4` always
#: (init fails without it), `key3` only when its mode byte is 1, the Japanese
#: mode. Both are restored from the same base file.
REQUIRED = ((TYPE_KEYLAYOUT, b"key4"), (TYPE_KEYLAYOUT, b"key3"))
#: Insert after this entry when it exists. The 2004 overlay's order is
#: ..., ncol, key4, ps2b, ...
ANCHOR = (TYPE_KEYLAYOUT, b"ncol")

#: Directories Square Enix's installed partition has and the disc does not
#: ship. FFXI writes its first-run data under them ("restoring files").
RUNTIME_DIRS = ("SYS", "TEMP", "USER")


class BadContainer(ValueError):
    pass


def entries(data):
    """[(offset, type, id, length)] for every entry, in file order."""
    out = []
    off = depth = 0
    while off + 16 <= len(data):
        word = struct.unpack_from("<I", data, off + 4)[0]
        kind = word & 0x7F
        length = ((word >> 7) & 0x7FFFF) * 16 or 16
        if off + length > len(data):
            raise BadContainer("entry at 0x%x runs past the end of the file" % off)
        out.append((off, kind, bytes(data[off:off + 4]), length))
        if kind == 1:
            depth += 1
        elif kind == 0:
            depth -= 1
            if depth <= 0:
                break
        off += length
    if not out or out[0][1] != 1 or out[-1][1] != 0:
        raise BadContainer("not a menu container: no opening entry or no `end`")
    return out


def _find(ents, kind, ident):
    for ent in ents:
        if ent[1] == kind and ent[2] == ident:
            return ent
    return None


def reconcile_bytes(base, overlay, required=REQUIRED, anchor=ANCHOR):
    """(new overlay, [ids added], [ids the base cannot supply]).

    The overlay comes back unchanged (the same object) when nothing is added.
    """
    base_ents = entries(base)
    over_ents = entries(overlay)
    blobs, added, missing = [], [], []
    # Walk the base in file order so the result is deterministic.
    wanted = [r for r in required if _find(over_ents, *r) is None]
    for ent in base_ents:
        if (ent[1], ent[2]) in wanted:
            blobs.append(bytes(base[ent[0]:ent[0] + ent[3]]))
            added.append(ent[2])
    for kind, ident in wanted:
        if ident not in added:
            missing.append(ident)
    if not blobs:
        return overlay, added, missing
    at = _find(over_ents, *anchor)
    cut = at[0] + at[3] if at else over_ents[-1][0]
    out = overlay[:cut] + b"".join(blobs) + overlay[cut:]
    entries(out)                      # must still parse to its `end`
    return out, added, missing


def _table_path(root, file_id, fallback):
    """The ROM path the install's own tables give `file_id`."""
    try:
        with open(os.path.join(root, "VTABLE.DAT"), "rb") as f:
            vtab = f.read()
        with open(os.path.join(root, "FTABLE.DAT"), "rb") as f:
            ftab = f.read()
        if file_id < len(vtab) and vtab[file_id] == 1:
            slot = struct.unpack_from("<H", ftab, file_id * 2)[0]
            return "ROM/%d/%d.DAT" % (slot >> 7, slot & 0x7F)
    except (OSError, struct.error):
        pass
    return fallback


def _rewrite_manifest(src_dir, rel_path, data, write):
    """Point file.txt's line for `rel_path` at the bytes now installed."""
    path = os.path.join(src_dir, "file.txt")
    if not os.path.isfile(path):
        return False
    with open(path, "rb") as f:
        text = f.read().decode("latin-1")
    suffix = ":" + rel_path
    lines = text.split("\n")
    hit = False
    for i, line in enumerate(lines):
        body = line.rstrip("\r")
        if body.endswith(suffix) and body.count(":") >= 2:
            tail = line[len(body):]
            lines[i] = "%s:%d:%s%s" % (ffxidata.sehash(data), len(data), rel_path, tail)
            hit = True
            break
    if hit and write:
        with open(path, "wb") as f:
            f.write("\n".join(lines).encode("latin-1"))
    return hit


def reconcile(src_dir, write=True):
    """Reconcile a staged FFXI tree in place. Returns a report dict."""
    root = os.path.join(src_dir, *FFXI_ROOT.split("/"))
    base_rel = _table_path(root, BASE_ID, BASE_PATH)
    over_rel = _table_path(root, OVERLAY_ID, OVERLAY_PATH)
    base_path = os.path.join(root, *base_rel.split("/"))
    over_path = os.path.join(root, *over_rel.split("/"))
    report = {"overlay": "%s/%s" % (FFXI_ROOT, over_rel), "added": [],
              "missing": [], "manifest": False, "dirs": [], "changed": False}
    for need in (base_path, over_path):
        if not os.path.isfile(need):
            raise SystemExit("ffxi overlay: %s is not in the staged tree" % need)
    with open(base_path, "rb") as f:
        base = f.read()
    with open(over_path, "rb") as f:
        overlay = f.read()
    new, added, missing = reconcile_bytes(base, overlay)
    report["added"] = [i.decode("latin-1") for i in added]
    report["missing"] = [i.decode("latin-1") for i in missing]
    if new is not overlay:
        report["changed"] = True
        report["before"], report["after"] = len(overlay), len(new)
        if write:
            with open(over_path, "wb") as f:
                f.write(new)
        report["manifest"] = _rewrite_manifest(src_dir, report["overlay"], new, write)
    for name in RUNTIME_DIRS:
        path = os.path.join(root, name)
        if not os.path.isdir(path):
            report["dirs"].append(name)
            if write:
                os.makedirs(path, exist_ok=True)
    return report


def describe(report):
    lines = []
    if report["changed"]:
        lines.append("overlay:   %s reconciled: added %s (%d -> %d B)"
                     % (report["overlay"], ", ".join(report["added"]),
                        report["before"], report["after"]))
        lines.append("           file.txt line %s"
                     % ("rewritten" if report["manifest"] else
                        "not found - Check Files will flag the overlay"))
    else:
        lines.append("overlay:   %s already carries what the boot module asks for"
                     % report["overlay"])
    if "key4" in report["missing"]:
        lines.append("           warning: key4 is in neither the overlay nor the "
                     "base menu file; this title will end in the Viewer's "
                     "terminated dialog")
    if report["dirs"]:
        lines.append("dirs:      created %s under %s"
                     % (", ".join(report["dirs"]), FFXI_ROOT))
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src", help="a staging directory from playonline.stage")
    ap.add_argument("--keep", action="store_true", help="report only")
    args = ap.parse_args()
    for line in describe(reconcile(args.src, write=not args.keep)):
        print(line)


if __name__ == "__main__":
    sys.exit(main())

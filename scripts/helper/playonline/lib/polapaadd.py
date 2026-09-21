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
"""Add a PFS partition to an existing PS2 APA partition chain.

Finds aligned free space on a drive that already carries other partitions,
splits it, and inserts the new partition. Existing header bodies are kept
byte for byte; only the `next`/`prev` links and checksums are rewritten.
Sub-partitions (flags 1, `main` = parent LBA) are relinked and never rebuilt.

APA rules applied (ps2sdk `iop/hdd/libapa`):
  * a length is a power of two, at least 128 MiB and at most 1 GiB (the
    console's driver reports `max 0x00200000` sectors at boot)
  * a partition starts on a multiple of its own length
  * free space is explicit: real headers of type 0, buddy-allocated

`--oversize` lifts only the 1 GiB cap. Square Enix never exceed 1 GiB in one
header (a large title is a 1 GiB main plus sub-partitions). Larger single
partitions are outside what the console's driver documents.

The APA journal is not updated; the partition is created while nothing else
has the drive open.

    python3 -m playonline.lib.polapaadd IMG --list
    python3 -m playonline.lib.polapaadd IMG --add PP.SLPS-20200.1000.POLVIEWER --size 1024
    python3 -m playonline.lib.polapaadd IMG --add ... --size 1024 --write --backup pre.json
"""
import argparse
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from .polhdd import (APA_MAGIC, APA_TYPE_FREE, APA_TYPE_PFS, EMPTY_ID, HEADER,
                    MAX_PART, MIB, MIN_PART, SECTOR, build_header, buddy_free,
                    checksum)


def read_chain(f, partial_ok=False):
    """Walk the APA chain from LBA 0. Returns ([dict] in chain order, truncated).

    A partial image dump can end before its chain does. With `partial_ok`
    (used for listing) that returns what was read; otherwise it is an error,
    because a write needs the whole chain.
    """
    out = []
    lba = 0
    seen = set()
    while True:
        if lba in seen:
            raise SystemExit("APA chain loops at LBA %d" % lba)
        seen.add(lba)
        f.seek(lba * SECTOR)
        raw = f.read(HEADER)
        if len(raw) < HEADER:
            if partial_ok:
                return out, True
            raise SystemExit(
                "short read at LBA %d: the image is truncated (%d MiB). "
                "Listing works (--list); adding a partition does not."
                % (lba, os.path.getsize(f.name) // MIB))
        magic, nxt, prev = struct.unpack_from("<III", raw, 0x004)
        if magic != APA_MAGIC:
            raise SystemExit("no APA magic at LBA %d; not a PS2 drive?" % lba)
        start, length = struct.unpack_from("<II", raw, 0x040)
        ptype, flags = struct.unpack_from("<HH", raw, 0x048)
        main = struct.unpack_from("<I", raw, 0x058)[0]
        ident = raw[0x010:0x030].split(b"\0")[0].decode("latin1")
        out.append({"lba": lba, "raw": bytearray(raw), "start": start,
                    "length": length, "type": ptype, "flags": flags,
                    "main": main, "id": ident, "next": nxt, "prev": prev})
        if not nxt:
            return out, False
        lba = nxt


def describe(p):
    kind = ("MBR" if p["type"] == 1 else
            "free" if p["type"] == APA_TYPE_FREE else
            "sub of %d" % p["main"] if p["flags"] & 1 else "PFS")
    return "  LBA %9d  %6d MiB  type 0x%04x  %-34s %s" % (
        p["start"], p["length"] * SECTOR // MIB, p["type"],
        p["id"] or "", kind)


def free_runs(chain):
    """Contiguous runs of free partitions: [(start, end_exclusive, [idx])]."""
    runs = []
    cur = []
    for i, p in enumerate(chain):
        if p["type"] == APA_TYPE_FREE:
            if cur and chain[cur[-1]]["start"] + chain[cur[-1]]["length"] != p["start"]:
                runs.append(cur)
                cur = []
            cur.append(i)
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    return [(chain[r[0]]["start"],
             chain[r[-1]]["start"] + chain[r[-1]]["length"], r) for r in runs]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--add", metavar="PARTID")
    ap.add_argument("--size", type=int, metavar="MIB",
                    help="partition size in MiB (power of two, 128..1024)")
    ap.add_argument("--oversize", action="store_true",
                    help="permit a length above the driver's documented 1 GiB "
                         "max")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--backup", metavar="JSON",
                    help="write the pre-change headers here (required for --write)")
    a = ap.parse_args()

    listing = a.list or not a.add
    with open(a.image, "rb") as f:
        chain, truncated = read_chain(f, partial_ok=listing)

    if listing:
        print("=" * 78)
        print("%s  (%d headers)%s"
              % (a.image, len(chain),
                 "  (truncated image: the chain runs past EOF)"
                 if truncated else ""))
        print("=" * 78)
        for p in chain:
            print(describe(p))
        tot = sum(p["length"] for p in chain if p["type"] == APA_TYPE_FREE)
        print("\n  free: %d MiB across %d partitions"
              % (tot * SECTOR // MIB,
                 sum(1 for p in chain if p["type"] == APA_TYPE_FREE)))
        for s, e, _ in free_runs(chain):
            print("    run LBA %9d .. %9d  (%d MiB)"
                  % (s, e, (e - s) * SECTOR // MIB))
        return

    if not a.size:
        sys.exit("--add needs --size MIB")
    n = a.size * MIB // SECTOR
    if n & (n - 1):
        sys.exit("--size must be a power of two (got %d MiB)" % a.size)
    if n < MIN_PART:
        sys.exit("--size must be >= %d MiB" % (MIN_PART * SECTOR // MIB))
    if n > MAX_PART and not a.oversize:
        sys.exit("--size must be <= %d MiB (the console's own cap); pass "
                 "--oversize to lift the cap"
                 % (MAX_PART * SECTOR // MIB))
    if n > MAX_PART:
        print("  --oversize: %d MiB is above the driver's documented max of "
              "%d MiB" % (a.size, MAX_PART * SECTOR // MIB))
    if any(p["id"] == a.add for p in chain):
        sys.exit("a partition named %s already exists" % a.add)

    # First aligned fit in a free run.
    place = None
    for s, e, idxs in free_runs(chain):
        start = (s + n - 1) // n * n
        if start + n <= e:
            place = (start, s, e, idxs)
            break
    if place is None:
        sys.exit("no free run can hold an aligned %d MiB partition" % a.size)
    start, run_s, run_e, idxs = place

    rebuilt = []
    for fs, fl in buddy_free(run_s, start):
        rebuilt.append({"start": fs, "length": fl, "type": APA_TYPE_FREE,
                        "id": EMPTY_ID, "raw": None})
    rebuilt.append({"start": start, "length": n, "type": APA_TYPE_PFS,
                    "id": a.add, "raw": None})
    for fs, fl in buddy_free(start + n, run_e):
        rebuilt.append({"start": fs, "length": fl, "type": APA_TYPE_FREE,
                        "id": EMPTY_ID, "raw": None})

    new_chain = chain[:idxs[0]] + rebuilt + chain[idxs[-1] + 1:]

    print("=" * 78)
    print("plan: add %s, %d MiB at LBA %d" % (a.add, a.size, start))
    print("=" * 78)
    print("  free run  LBA %d .. %d (%d MiB) becomes:"
          % (run_s, run_e, (run_e - run_s) * SECTOR // MIB))
    for p in rebuilt:
        print("      LBA %9d  %6d MiB  %s"
              % (p["start"], p["length"] * SECTOR // MIB,
                 p["id"] or "(free)"))
    print("  headers: %d -> %d" % (len(chain), len(new_chain)))

    covered = sum(p["length"] for p in new_chain if not (p.get("flags", 0) & 1))
    print("  coverage check: %d sectors" % covered)

    if not a.write:
        print("\n  (plan only; pass --write --backup PRE.json)")
        return
    if not a.backup:
        sys.exit("--write requires --backup JSON")
    if os.path.exists(a.backup):
        sys.exit("refusing to overwrite an existing %s" % a.backup)

    with open(a.backup, "w") as bf:
        json.dump([dict({k: v for k, v in p.items() if k != "raw"},
                        raw=p["raw"].hex()) for p in chain], bf, indent=1)
    print("\n  backup -> %s" % a.backup)

    # Relink and write.
    for i, p in enumerate(new_chain):
        nxt = new_chain[i + 1]["start"] if i + 1 < len(new_chain) else 0
        # The list is circular: __mbr.prev points at the last partition, as on
        # Sony-formatted drives. hdl_dump's apa_check requires it.
        prev = new_chain[i - 1]["start"] if i else new_chain[-1]["start"]
        if p["raw"] is None:
            raw = bytearray(build_header(p["start"], p["length"], p["type"],
                                         p["id"], nxt, prev))
        else:
            raw = bytearray(p["raw"])
            struct.pack_into("<II", raw, 0x008, nxt, prev)
            struct.pack_into("<I", raw, 0x000, 0)
            struct.pack_into("<I", raw, 0x000, checksum(bytes(raw)))
        p["out"] = bytes(raw)

    with open(a.image, "r+b") as f:
        for p in new_chain:
            f.seek(p["start"] * SECTOR)
            f.write(p["out"])
    print("  wrote %d headers to %s" % (len(new_chain), a.image))
    print()
    print("  next: format the partition (polpfs) and populate it (polfill)")


if __name__ == "__main__":
    main()

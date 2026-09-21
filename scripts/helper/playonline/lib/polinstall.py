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
"""Read the PS2 disc install archive (`_/N/M.K`) and extract its file tree.

The SLPS-20200 disc has two namespaces:

  A..Z / <maj>.<min>   the Viewer's own files, in plaintext, named by
                       `_/CDFILE.TXT`. Most slots are 0-byte padding.
  _ / <d> / <maj>.<min>  the install archives, which login.pex copies to the HDD
                       partitions (PP.SLPS-20200.{1000.POLVIEWER,0002.TETRAMASTER,
                       0003.JANHOUROU}). This is the only place the game trees
                       `Warashi/...` (Janhourou) and `TetraMaster/...` exist.

The US disc (SCUS-97269) uses the same archive layout.

Container format
----------------
A volume is a bare concatenation of records, no index, no volume header:

    struct record {
        u32  chunk_idx;      // 0 = whole file; otherwise 1-based chunk number
        u32  orig_size;      // decompressed size of this chunk
        u32  stored_size;    // bytes on disc for this chunk
        char path[];         // NUL-terminated, '/'-separated
        u8   pad[];          // zero fill to 0x100
        u8   payload[stored_size];
    };

The next record starts at `offset + 0x100 + stored_size`, rounded up to a
multiple of 4. Files larger than 0x80000 are split into 0x80000-byte chunks
(the last is short) and the chunks may spill into the following volume, so a
full extract must walk every volume in order and regroup by path.

  orig_size == stored_size  ->  payload is stored raw (already-compressed or
                                encrypted data: every `*.pex.enc`, `*.wd`, ...)
  orig_size >  stored_size  ->  payload is LZSS (below)

LZSS
----
LSB-first bitstream, 256-byte zero-initialised sliding window:

    flag 0 -> literal: next 8 bits are the byte
    flag 1 -> match  : next 12 bits, low 8 = negated distance, high 4 = len-2
                       dist = (256 - low8) & 0xFF, with 0 meaning 256
                       len  = high4 + 2                     (so 2..17)

Usage
-----
  python3 -m playonline.lib.polinstall --disc DISC --list      # manifest of every record
  python3 -m playonline.lib.polinstall --disc DISC --out install
  python3 -m playonline.lib.polinstall --disc DISC --out install --filter Warashi/
"""
import argparse
import os
import struct
import sys

HDR = 0x100          # header block size, path lives at +12
CHUNK = 0x80000      # split size for large files
DISC = None          # the extracted disc root, set by --disc


def lzss_decompress(data, want):
    """Decode the 256-byte-window LZSS described above. `want` = orig_size."""
    d = bytes(data) + b"\0\0\0\0"          # pad so the refill never runs dry
    n = len(d)
    buf = bytearray(256)                   # 256 zeros = the initial window
    acc = 0
    nb = 0
    p = 0
    target = want + 256
    while len(buf) < target:
        if nb < 13:
            while nb <= 24 and p < n:
                acc |= d[p] << nb
                p += 1
                nb += 8
            if nb < 13:
                break
        if acc & 1:
            acc >>= 1
            v = acc & 0xFFF
            acc >>= 12
            nb -= 13
            dist = (256 - (v & 0xFF)) & 0xFF or 256
            ln = (v >> 8) + 2
            src = len(buf) - dist
            if dist >= ln:
                buf += buf[src:src + ln]
            else:                          # overlapping copy, byte at a time
                for k in range(ln):
                    buf.append(buf[src + k])
        else:
            acc >>= 1
            buf.append(acc & 0xFF)
            acc >>= 8
            nb -= 9
    return bytes(buf[256:target])


def _header_at(b, o):
    """Parse a record header at `o`, or None if it isn't one.

    The zero fill between the path's NUL and +0x100 makes the test reliable:
    a compressed payload is very unlikely to contain a printable path
    followed by a zero run of about 230 bytes.
    """
    n = len(b)
    if o < 0 or o + HDR > n:
        return None
    idx, orig, stored = struct.unpack_from("<III", b, o)
    e = b.find(b"\0", o + 12, o + HDR)
    if (e > o + 12 and stored and orig >= stored and o + HDR + stored <= n
            and all(32 <= c < 127 for c in b[o + 12:e])
            and not any(b[e:o + HDR])):
        return idx, orig, stored, b[o + 12:e].decode()
    return None


def scan_volume(b):
    """Yield (offset, chunk_idx, orig, stored, path) for every record in a volume.

    Records are 4-byte aligned: the next one starts at
    `align4(offset + 0x100 + stored_size)`, so up to 3 pad bytes sit between them.
    If a header fails to parse, the scan moves forward on the 4-byte grid to a
    candidate that also chains to a valid successor, and stops if none is found.
    """
    n = len(b)
    o = 0
    while o + HDR <= n:
        h = _header_at(b, o)
        if h is None:
            o += 4
            while o + HDR <= n:
                h = _header_at(b, o)
                # require a valid successor, so payload bytes cannot pass as a header
                if h is not None:
                    nxt = (o + HDR + h[2] + 3) & ~3
                    if nxt >= n or _header_at(b, nxt) is not None:
                        break
                h = None
                o += 4
            if h is None:
                return
        idx, orig, stored, path = h
        yield o, idx, orig, stored, path
        o = (o + HDR + stored + 3) & ~3


def _vol_key(fn):
    """Sort key for `<maj>.<min>` volume names (2.10 must not sort before 2.9)."""
    try:
        maj, minr = fn.split(".")
        return (int(maj), int(minr))
    except ValueError:
        return (99, 99)


def volumes(disc=None):
    """Yield (name, path) for each non-empty `_/<d>/<maj>.<min>` in disc order.

    Chunk order depends on this: a file split at a volume boundary continues in
    the next volume, so the walk must follow the disc's own ordering.
    """
    disc = disc or DISC
    root = os.path.join(disc, "_")
    for d in sorted(os.listdir(root), key=lambda x: (len(x), x)):
        dp = os.path.join(root, d)
        if not os.path.isdir(dp):
            continue
        for fn in sorted(os.listdir(dp), key=_vol_key):
            fp = os.path.join(dp, fn)
            if os.path.isfile(fp) and os.path.getsize(fp):
                yield "%s/%s" % (d, fn), fp


def records(disc=None):
    """Yield (volume, offset, idx, orig, stored, path, payload) across all volumes."""
    disc = disc or DISC
    for vol, fp in volumes(disc):
        with open(fp, "rb") as f:
            b = f.read()
        for o, idx, orig, stored, path in scan_volume(b):
            yield vol, o, idx, orig, stored, path, b[o + HDR:o + HDR + stored]


def payload_bytes(orig, stored, payload):
    return payload if orig == stored else lzss_decompress(payload, orig)


def cmd_list(args):
    total_stored = total_orig = 0
    rows = 0
    for vol, o, idx, orig, stored, path, _ in records():
        if not path.startswith(args.filter):
            continue
        print("%-8s @0x%08x idx=%-3d %10d %10d  %s"
              % (vol, o, idx, orig, stored, path))
        total_stored += stored
        total_orig += orig
        rows += 1
    print("\n%d records  stored %d B  original %d B" % (rows, total_stored, total_orig))


def cmd_extract(args):
    chunks = {}
    order = []
    for vol, o, idx, orig, stored, path, pay in records():
        if not path.startswith(args.filter):
            continue
        if path not in chunks:
            chunks[path] = []
            order.append(path)
        chunks[path].append((idx, vol, o, orig, stored, pay))

    files = written = 0
    for path in order:
        parts = sorted(chunks[path], key=lambda c: c[0])
        seen = [c[0] for c in parts]
        if len(set(seen)) != len(seen):
            print("  WARN duplicate chunk index for %s: %s" % (path, seen))
        expect = list(range(1, len(parts) + 1)) if len(parts) > 1 else [0]
        if seen != expect:
            print("  WARN %s: chunk indices %s, expected %s" % (path, seen, expect))
        blob = b"".join(payload_bytes(o_, s_, p_) for _, _, _, o_, s_, p_ in parts)
        dst = os.path.join(args.out, *path.split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(blob)
        files += 1
        written += len(blob)
        if args.verbose:
            print("  %10d  %s" % (len(blob), path))
    print("wrote %d files, %d bytes -> %s" % (files, written, args.out))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--list", action="store_true", help="print a record manifest")
    ap.add_argument("--out", help="extract the reassembled tree into this directory")
    ap.add_argument("--filter", default="", help="only paths with this prefix")
    ap.add_argument("-v", "--verbose", action="store_true")
    # The US disc (SCUS-97269) has the same `_/<d>/<maj>.<min>` archive
    # layout as the JP one; point --disc at either extracted root.
    ap.add_argument("--disc", required=True, help="extracted disc root")
    args = ap.parse_args()
    globals()["DISC"] = args.disc
    if args.list:
        return cmd_list(args)
    if args.out:
        return cmd_extract(args)
    ap.print_help()


if __name__ == "__main__":
    sys.exit(main() or 0)

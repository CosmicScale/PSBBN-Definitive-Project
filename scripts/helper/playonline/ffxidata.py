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
r"""Read Final Fantasy XI's own data containers (ROM*.DAT, MISC*.DAT).

Final Fantasy XI is not in the PlayOnline install container. The disc carries
it in `DATA/` as five `ROM*.DAT` blobs, five `MISC*.DAT` blobs and a set of
tables. Every format below is verified against Square Enix's own manifest
hashes.

Manifest: `DATA/FILE.TXT` lists every installed file as `hash:size:path` and
ends with a `::` line. The hash is MD5 in base64 with a permuted alphabet
(`SE_B64` below in place of the standard one). The other titles use the same
manifest format, so `sehash` verifies any of them.

MISC*.DAT: a bare sequence of records with no index, payload stored raw:

    u32  total      the whole record, header included
    char path[256]  NUL terminated, NUL padded
    u8   payload[total - 260]

The five containers layer: a path that appears in more than one takes the
later container's copy, and a path can also repeat inside one container.
Paths are relative to `image/ffxi/`. A few `res/` records in `MISC.DAT` begin
with `../../`, which cancels that prefix and places the file at the root of
the partition (`info.sys` and the jacket images). Those files are not in the
manifest.

ROM*.DAT: `ROM{N}.DAT` holds the files of `image/ffxi/ROM{N}/`, sized by
`STABLE{N}.DAT`, a flat `u32` array indexed by

    slot = dir * 128 + num        ->  image/ffxi/ROM{N}/{dir}/{num}.DAT

A zero size means no file in that slot. Some sized slots are absent from the
manifest. The payloads are LZSS, one independent stream per file, packed end
to end:

    flag byte, MSB first, 1 = literal, 0 = match
    match: two bytes, distance = ((b0 & 0x0F) << 8) | b1, length = (b0 >> 4) + 3

Each stream ends with a `0x0000` terminator, and any further zero bytes are
padding. This is a different LZSS from the one the PlayOnline install archive
uses, which has a 256-byte window and its own bit order.

    python3 -m playonline.ffxidata DISC --tables
    python3 -m playonline.ffxidata DISC --verify
    python3 -m playonline.ffxidata DISC --out DIR

A run without `--limit`, `--group` or `--skip-misc` walks all ten containers
and fails if any manifest file was not produced. With any of those options
the run is a sample and reports itself as one.
"""
import argparse
import base64
import hashlib
import struct
import sys

from . import discs, safepath

STD_B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
SE_B64 = "TSG8IncW3HFKokOg79qzeCmZs2yBYEQVAUxR5rbwi4P@jMDLtpvad0f_J1hlN6uX"
_TO_SE = str.maketrans(STD_B64, SE_B64)

MISC_HEADER = 260               # u32 total + 256-byte path
SLOTS_PER_DIR = 128

# Every MISC container on the disc, in the order Square Enix applies them.
# The order matters: a later container supersedes an earlier one, and only
# the last copy of a superseded file matches the manifest.
MISC_CONTAINERS = ["MISC.DAT"] + ["MISC%d.DAT" % n for n in range(2, 6)]
ROM_GROUPS = (1, 2, 3, 4, 5)


class ShortContainer(Exception):
    """A container ended before the tables said it would."""


def sehash(data):
    """Square Enix's manifest hash: MD5, base64, permuted alphabet."""
    return base64.b64encode(hashlib.md5(data).digest()).decode().rstrip("=").translate(_TO_SE)


def _data_dir(image):
    root = {n.upper(): (l, s) for n, l, s, _d in discs.read_root(image)}
    if "DATA" not in root:
        raise discs.NotADisc("no DATA directory")
    lba, size = root["DATA"]
    sectors = (size + discs.USER_DATA - 1) // discs.USER_DATA
    return {n.upper(): (l, s)
            for n, l, s, _d in discs._dir_records(image.read_sector(lba, sectors))}


def _read(image, entry, sectors=None):
    lba, size = entry
    want = sectors or (size + discs.USER_DATA - 1) // discs.USER_DATA
    blob = image.read_sector(lba, want)
    return blob[:size] if sectors is None else blob


def manifest(image):
    """{path: (hash, size)} from DATA/FILE.TXT."""
    files = _data_dir(image)
    if "FILE.TXT" not in files:
        raise discs.NotADisc("no DATA/FILE.TXT")
    text = _read(image, files["FILE.TXT"]).decode("latin-1")
    out = {}
    for line in text.replace("\r", "\n").split("\n"):
        if not line or line == "::":
            continue
        h, size, path = line.split(":", 2)
        out[path] = (h, int(size))
    return out


def misc_records(image, name="MISC.DAT", limit=0):
    """Yield (path, payload) from a MISC*.DAT. Payloads are stored raw."""
    files = _data_dir(image)
    if name.upper() not in files:
        return
    lba, size = files[name.upper()]
    pos = 0
    n = 0
    while pos + MISC_HEADER < size:
        head = image.read_sector(lba + pos // discs.USER_DATA, 1)
        skew = pos % discs.USER_DATA
        if skew + MISC_HEADER > discs.USER_DATA:
            head = image.read_sector(lba + pos // discs.USER_DATA, 2)
        total, = struct.unpack_from("<I", head, skew)
        if not total or pos + total > size:
            return
        path = head[skew + 4:skew + MISC_HEADER].split(b"\0")[0].decode("latin-1")
        first = (pos + MISC_HEADER) // discs.USER_DATA
        inner = (pos + MISC_HEADER) - first * discs.USER_DATA
        want = total - MISC_HEADER
        blob = image.read_sector(lba + first,
                                 (inner + want + discs.USER_DATA - 1) // discs.USER_DATA)
        yield path, blob[inner:inner + want]
        pos += total
        n += 1
        if limit and n >= limit:
            return


def lzss(src, start, want):
    """Decompress one stream. Returns (bytes, offset just past the stream)."""
    out = bytearray()
    i = start
    n = len(src)
    while len(out) < want and i < n:
        flags = src[i]
        i += 1
        for bit in range(8):
            if len(out) >= want or i >= n:
                break
            if (flags >> (7 - bit)) & 1:
                out.append(src[i])
                i += 1
            else:
                if i + 1 >= n:
                    return bytes(out), i
                b0, b1 = src[i], src[i + 1]
                i += 2
                dist = ((b0 & 0x0F) << 8) | b1
                length = (b0 >> 4) + 3
                start_at = len(out) - dist
                for k in range(length):
                    if len(out) >= want:
                        break
                    out.append(out[start_at + k] if 0 <= start_at + k < len(out) else 0)
    return bytes(out), i


def rom_sizes(image, group=1):
    """The STABLE table for a ROM group: [size] indexed by dir*128 + num."""
    files = _data_dir(image)
    name = "STABLE.DAT" if group == 1 else "STABLE%d.DAT" % group
    if name not in files:
        return []
    blob = _read(image, files[name])
    return list(struct.unpack("<%dI" % (len(blob) // 4), blob))


def table_files(image):
    """Yield (path, bytes) for the tables that are installed as plain files.

    `FTABLE` and `VTABLE` are in no container: they are copied out of `DATA/`
    as they stand. Group 1's pair lands at the root of `image/ffxi/`, each
    later group's pair inside its own ROM directory. `STABLE` and `CTABLE`
    are not installed.
    """
    files = _data_dir(image)
    for group in ROM_GROUPS:
        for stem in ("FTABLE", "VTABLE"):
            name = "%s.DAT" % stem if group == 1 else "%s%d.DAT" % (stem, group)
            if name not in files:
                continue
            dest = ("image/ffxi/%s" % name if group == 1
                    else "image/ffxi/ROM%d/%s" % (group, name))
            yield dest, _read(image, files[name])


def rom_path(group, slot):
    tag = "ROM" if group == 1 else "ROM%d" % group
    return "image/ffxi/%s/%d/%d.DAT" % (tag, slot // SLOTS_PER_DIR,
                                        slot % SLOTS_PER_DIR)


class _Window(object):
    """A forward-only sliding view over one container on the disc.

    The streams are packed end to end with no index, so a ROM group has to be
    walked from the front, and the largest container is over 1 GiB. This
    reads a chunk at a time and refills whenever the caller asks for a span
    the buffer does not already hold.
    """

    def __init__(self, image, entry, chunk_mib=32):
        self.image = image
        self.lba, self.size = entry
        self.chunk = chunk_mib * 1024 * 1024
        self.base = 0
        self.buf = b""

    def span(self, off, want):
        """(buffer, index of `off`), holding `want` bytes from `off`."""
        want = min(want, self.size - off)
        if not (self.base <= off and off + want <= self.base + len(self.buf)):
            self._fill(off, want)
        return self.buf, off - self.base

    def _fill(self, off, want):
        sector = off // discs.USER_DATA
        self.base = sector * discs.USER_DATA
        take = min(max(self.chunk, (off - self.base) + want),
                   self.size - self.base)
        sectors = (take + discs.USER_DATA - 1) // discs.USER_DATA
        self.buf = self.image.read_sector(self.lba + sector, sectors)[:take]


def rom_files(image, group=1, chunk_mib=32, limit=0):
    """Yield (path, bytes) for a ROM group, in slot order.

    Raises ShortContainer if the blob runs out before the STABLE table says
    it should.
    """
    files = _data_dir(image)
    name = "ROM.DAT" if group == 1 else "ROM%d.DAT" % group
    if name not in files:
        return
    sizes = rom_sizes(image, group)
    win = _Window(image, files[name], chunk_mib)
    off = 0
    made = 0
    for slot, size in enumerate(sizes):
        if not size:
            continue
        if off + 4 >= win.size:
            raise ShortContainer(
                "%s ended at %d of %d bytes, with %s still to come"
                % (name, off, win.size, rom_path(group, slot)))
        # LZSS adds one flag byte per eight output tokens and never more, so
        # a stream cannot exceed its decompressed size by more than an eighth.
        # The slack covers the terminator and the flag byte of a final group.
        buf, i = win.span(off, size + size // 8 + 64)
        blob, end = lzss(buf, i, size)
        if len(blob) < size:
            raise ShortContainer(
                "%s: %s decompressed to %d bytes, not the %d STABLE gives"
                % (name, rom_path(group, slot), len(blob), size))
        yield rom_path(group, slot), blob
        made += 1
        if limit and made >= limit:
            return
        # The 0x0000 terminator, then any zero padding before the next stream.
        off = win.base + end + 2
        while off < win.size:
            buf, i = win.span(off, min(4096, win.size - off))
            run = 0
            while i + run < len(buf) and buf[i + run] == 0:
                run += 1
            off += run
            if i + run < len(buf):
                break


def tree(image, chunk_mib=32):
    """Yield (path, bytes) for the whole installed FFXI tree, in SE's order.

    Paths are the ones the partition uses: `image/ffxi/...`, with the
    `../../res/` entries left for the writer to resolve to the partition root.

    A path can appear more than once, because the MISC containers layer and
    the last copy is the right one. A caller that writes as it goes gets the
    correct result; a caller that counts should count distinct paths.
    """
    for path, blob in table_files(image):
        yield path, blob
    for name in MISC_CONTAINERS:
        for path, blob in misc_records(image, name):
            yield "image/ffxi/" + path, blob
    for group in ROM_GROUPS:
        if not rom_sizes(image, group):
            continue
        for path, blob in rom_files(image, group, chunk_mib):
            yield path, blob


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("disc")
    ap.add_argument("--tables", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--out", metavar="DIR")
    ap.add_argument("--group", type=int, choices=ROM_GROUPS,
                    help="just this ROM group; the default is all five")
    ap.add_argument("--skip-misc", action="store_true")
    ap.add_argument("--limit", type=int, default=0,
                    help="stop after this many files per container "
                         "(sampling)")
    ap.add_argument("--chunk-mib", type=int, default=32,
                    help="how much of a container to hold at once")
    args = ap.parse_args()

    image = discs.Image(args.disc)
    man = manifest(image)
    print("%d files in DATA/FILE.TXT" % len(man))

    if args.tables:
        for g in ROM_GROUPS:
            sizes = rom_sizes(image, g)
            if not sizes:
                continue
            print("  ROM group %d: %d slots, %d sized, %.1f MiB"
                  % (g, len(sizes), sum(1 for s in sizes if s),
                     sum(sizes) / 1048576.0))
        return 0

    if not (args.verify or args.out):
        print("nothing to do: pass --tables, --verify or --out")
        return 0

    # path -> did its hash match. A later MISC container supersedes an earlier
    # one, so the last verdict for a path is the one that counts.
    verdict = {}
    absent = 0
    written = 0

    # Paths a later container put right. The per-container lines count each
    # copy as it is read, so an early container can report a hash failure for
    # a file a later one corrects. The summary names those files.
    superseded = set()

    def take(full, blob):
        if full not in man:
            return None
        good = sehash(blob) == man[full][0]
        if good and verdict.get(full) is False:
            superseded.add(full)
        verdict[full] = good
        return good

    def report(label, ok, wrong, unlisted, nbytes):
        print("  %-12s %6d ok  %4d wrong  %4d not in the manifest  %8.1f MiB"
              % (label, ok, wrong, unlisted, nbytes / 1048576.0))

    ok = wrong = unlisted = nbytes = 0
    for path, blob in table_files(image):
        got = take(path, blob)
        ok += got is True
        wrong += got is False
        unlisted += got is None
        nbytes += len(blob)
        if args.out:
            safepath.write(args.out, path, blob)
            written += 1
    absent += unlisted
    report("tables", ok, wrong, unlisted, nbytes)

    if not args.skip_misc:
        for name in MISC_CONTAINERS:
            ok = wrong = unlisted = nbytes = 0
            for path, blob in misc_records(image, name, limit=args.limit):
                full = "image/ffxi/" + path
                got = take(full, blob)
                ok += got is True
                wrong += got is False
                unlisted += got is None
                nbytes += len(blob)
                if args.out:
                    safepath.write(args.out, full, blob)
                    written += 1
            absent += unlisted
            report(name, ok, wrong, unlisted, nbytes)

    for g in ([args.group] if args.group else ROM_GROUPS):
        if not rom_sizes(image, g):
            continue
        ok = wrong = unlisted = nbytes = 0
        for path, blob in rom_files(image, g, args.chunk_mib, args.limit):
            got = take(path, blob)
            ok += got is True
            wrong += got is False
            unlisted += got is None
            nbytes += len(blob)
            if args.out:
                safepath.write(args.out, path, blob)
                written += 1
        absent += unlisted
        report("ROM group %d" % g, ok, wrong, unlisted, nbytes)

    bad = sorted(k for k, good in verdict.items() if not good)
    for k in bad[:5]:
        print("  mismatch %s" % k)
    if superseded:
        print()
        print("%d file(s) were corrected by a later MISC container, so a "
              "hash failure above is expected:" % len(superseded))
        for k in sorted(superseded)[:5]:
            print("  %s" % k)
    missing = len(man) - len(verdict)
    print()
    print("%d of %d manifest files produced, %d wrong, %d not in the manifest"
          % (len(verdict), len(man), len(bad), absent))
    if args.out:
        print("%d files written to %s" % (written, args.out))

    sampled = bool(args.limit or args.group or args.skip_misc)
    if sampled:
        print("this run was a sample, so the count above is not coverage")
        return 1 if bad else 0
    if missing:
        print("%d manifest files were never produced" % missing)
    return 1 if (bad or missing) else 0


if __name__ == "__main__":
    sys.exit(main())

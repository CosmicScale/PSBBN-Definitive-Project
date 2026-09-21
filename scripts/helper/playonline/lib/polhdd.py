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
"""Build a PS2 APA partition table on PCSX2's virtual HDD.

Writes only the APA partition table for a blank image; the PFS file systems
inside the partitions are made by polpfs and filled by polfill.

Format reference: ps2sdk `iop/hdd/libapa` (libapa.h, apa.c) and `iop/hdd/apa`
(hdd_fio.c).  A partition header is 1024 bytes at the partition's first sector:

    0x000 u32 checksum      sum of u32 words 1..255, word 0 excluded
    0x004 u32 magic         'APA\0' = 0x00415041
    0x008 u32 next          LBA of the next header, 0 on the last
    0x00C u32 prev          LBA of the previous header; on the MBR it is the last
                            partition's start (the list is circular, and
                            hdl_dump checks it)
    0x010 char id[32]
    0x030 char rpwd[8]      read password  ("" = none, checked by apaPassCmp)
    0x038 char fpwd[8]      format password
    0x040 u32 start         this partition's LBA
    0x044 u32 length        in sectors
    0x048 u16 type          0=free 1=MBR 0x100=PFS
    0x04A u16 flags         1 = sub-partition
    0x04C u32 nsub
    0x050 ps2time created   u8 unused,sec,min,hour,day,month + u16 year
    0x058 u32 main          for subs, the main partition's LBA
    0x05C u32 number        sub index
    0x060 u32 modver
    0x064 u32 pad1[7]
    0x080 char pad2[128]
    0x100 mbr:  char magic[32]; u32 version; u32 nsector;
                ps2time created; u32 osdStart; u32 osdSize; char pad3[200]
    0x200 sub_t subs[64]    (u32 start, u32 length) x64
    0x400 end

APA stands for Aligned Partition Allocation: every length is a power of two
(at least 128 MiB) and every start is a multiple of its own length.  Free space
is explicit: it is covered by real headers of type 0, so the tail of the drive
is filled with buddy-allocated free partitions.

Usage:
    python3 -m playonline.lib.polhdd --image P            # print the layout, touch nothing
    python3 -m playonline.lib.polhdd --image P --write    # write the table
"""
import argparse
import os
import struct

SECTOR = 512
MIB = 1024 * 1024
MIN_PART = 128 * MIB // SECTOR          # 262144 sectors, the APA granule
# Largest partition the apa driver allows. It scales with the drive size:
# 0x200000 sectors (1 GiB) is the value for a 40 GiB drive.
MAX_PART = 0x200000
HEADER = 1024

APA_MAGIC = 0x00415041
APA_MBR_MAGIC = b"Sony Computer Entertainment Inc."
APA_MBR_VERSION = 2

# A free partition carries the id "__empty", as ps2sdk libapa and Sony's own
# drives write it. An enumerator that treats an empty id as the end of the
# list (wLaunchELF's browser does) would otherwise hide every partition after
# the first free one.
EMPTY_ID = "__empty"

APA_TYPE_FREE = 0x0000
APA_TYPE_MBR = 0x0001
APA_TYPE_PFS = 0x0100

# modver is the version of the apa driver that wrote the header; it is
# informational and not validated on read. 0x0201 is the value polpfs.py
# uses for the pfs driver.
MODVER = 0x0201

# The Viewer's partition set: `__common` is referenced by polapp.pex and
# login.pex, the three PP.* names come from the boot ELF (0x001fc880) and from
# install.inf's 40-byte name slots at 0x818/0x840.
# The system partition sizes are Sony's, as found on formatted drives:
# __net 128, __system 256, __sysconf 512, __common 1024 MiB at LBA 262144 /
# 524288 / 1048576 / 2097152. They are kept so that a `__system` copied
# sector for sector from another drive fits, and each start already lands on
# a multiple of its length.
SYSTEM_PARTS = [
    ("__net", 128 * MIB),
    ("__system", 256 * MIB),
    ("__sysconf", 512 * MIB),
    ("__common", 1024 * MIB),
]

# Partition passwords for `__net`. The Viewer's `.pex.enc` loader (0x001b2e00)
# mounts `hdd0:__net,<A>` at 0x001b1318 and stats `pfs0:/etc/access_flag`;
# the bulk-key read (0x001b2508) mounts `hdd0:__net,,<B>` at 0x001b1400.
# hdd_fio.c's fioGetInput parses `id, fpwd, rpwd, size, type`, so A is the
# format password and B the read password. Neither is stored verbatim, see
# apa_password(). apaOpen tries fpwd first and falls back to rpwd for a
# read-only open, so both can be set.
#
# A and B are Sony's fixed values, identical on every console. They match the
# `__net` header of a drive that Square Enix's installer set up.
PASSWORDS = {"__net": (b"Qfk5j1EZ", b"iBJ9F9Yq")}      # (fpwd, rpwd)

# Game partitions carry password fields too, copied here from partitions
# Square Enix's installer created. The stored bytes are DES with the password
# as key over the id as plaintext, so for a fixed id they are constants and
# the plaintext passwords are not needed. Header offset 0x030 = rpwd,
# 0x038 = fpwd. JANHOUROU has neither.
RAW_PASSWORDS = {                                     # id: (rpwd, fpwd)
    "PP.SLPS-20200.0002.TETRAMASTER": (bytes.fromhex("31db4ac6a1543836"),
                                       bytes.fromhex("a69693823ae29bf6")),
    "PP.SLPS-20200.1000.POLVIEWER":   (bytes.fromhex("8ec8b0b32df5bed5"),
                                       bytes.fromhex("30e5643bdae41c39")),
}


def apa_password(part_id, password):
    """The 8 bytes an APA header must hold for `hdd0:<id>,<password>` to open.

    ps2sdk `iop/hdd/libapa/src/password.c`: `fioGetInput` runs the supplied
    password through `apaEncryptPassword(id, ...)` before `apaOpen` compares
    it with the header field. That function is DES-ECB with the password as
    the key and the first 8 bytes of the partition id as the plaintext. Its
    DES loads both operands as two little-endian u32s and treats the pair as
    `(hi << 32) | lo` with DES bit 1 as the MSB, so every 8-byte operand is
    byte-reversed relative to memory. A header holding the plaintext password
    makes the driver return -EACCES.
    """
    from Crypto.Cipher import DES                      # only needed with a password
    idb = part_id.encode("ascii").ljust(8, b"\0")[:8]
    pwd = password.ljust(8, b"\0")[:8]
    return DES.new(pwd[::-1], DES.MODE_ECB).encrypt(idb[::-1])[::-1]
# Sizes allow for PFS overhead: every file and directory takes a whole 8 KiB
# zone for its inode, and file data is rounded up to a zone.  Space needed:
# POL 243 MiB, Warashi 41 MiB, TetraMaster 21 MiB.  Ordered so each start
# lands on a multiple of its own length.
GAME_PARTS = [
    ("PP.SLPS-20200.0003.JANHOUROU", 128 * MIB),      # install/Warashi/     41 MiB
    ("PP.SLPS-20200.0002.TETRAMASTER", 128 * MIB),    # install/TetraMaster/ 21 MiB
    ("PP.SLPS-20200.1000.POLVIEWER", 512 * MIB),      # install/POL/        243 MiB
]

# Fixed timestamp (the disc's build date), so runs are reproducible.
CREATED = (0, 0, 0, 0, 29, 3, 2002)     # unused, sec, min, hour, day, month, year


#: The password keys Square Enix ships in `install.inf`, one per content id,
#: stored there as 8 little-endian bytes. Janhourou's is zero, so that
#: partition has no password.
INSTALL_KEYS = {
    1:  0x00A7272F216479E8,     # FFXI       -> NARINARI
    2:  0x0101A1EB55C4B747,     # Tetra      -> ftmsimo
    3:  0,                      # Janhourou  -> none
    4:  0x01090BE88581F686,     # FMO        -> huskys
    10: 0x0054161CAE1026E8,     # Dirge      -> 7m9pPQ;K
}


def build_pw(key):
    """The 64-bit `install.inf` key -> the partition password it stands for.

    A title mounts its own partition with `hdd0:<id>,<password>` and builds
    the password from the key at run time (`TMaster.pex` 0x0028ee80). The
    key's low nibble is the password length. The rest of the key (key // 16)
    is written in base 94, most significant digit first, each digit rendered
    as `chr(digit + 33)`, ASCII '!' through '~'.

    `apa_password` turns the result into the header's fpwd. It says nothing
    about rpwd, which on Square Enix's POLVIEWER and FMO headers comes from a
    different, unknown password. Not every title generates its password this
    way: Dirge's module tries up to four candidates from a table (0x003c2cc0).
    """
    v = key // 16
    out = [0] * 8
    for i in range(7, -1, -1):
        out[i] = (v % 94) + 33
        v //= 94
    return bytes(out)[:key & 0xF]


def selftest_build_pw():
    """Regenerate every known password from its key.

    The last check ties the generator to the fpwd in the Tetra Master header
    that Square Enix's installer wrote.
    """
    want = {
        1:  b"NARINARI",
        2:  b"ftmsimo",
        4:  b"huskys",
        10: b"7m9pPQ;K",
    }
    for cid, expect in sorted(want.items()):
        got = build_pw(INSTALL_KEYS[cid])
        assert got == expect, (cid, got, expect)
    assert build_pw(INSTALL_KEYS[3]) == b"", "a zero key means no password"
    # The fpwd Square Enix's installer wrote for the JP Tetra Master partition.
    assert apa_password("PP.SLPS-20200.0002.TETRAMASTER", b"ftmsimo") == \
        bytes.fromhex("a69693823ae29bf6"), "Square Enix's JP Tetra Master header"
    return True


def ps2time(t=CREATED):
    return struct.pack("<6BH", *t)


def checksum(hdr):
    words = struct.unpack("<256I", hdr)
    return sum(words[1:]) & 0xFFFFFFFF


def build_header(start, length, ptype, ident, nxt, prev, is_mbr=False, nsector=0):
    h = bytearray(HEADER)
    struct.pack_into("<I", h, 0x004, APA_MAGIC)
    struct.pack_into("<I", h, 0x008, nxt)
    struct.pack_into("<I", h, 0x00C, prev)
    h[0x010:0x010 + len(ident)] = ident.encode("ascii")
    pwds = PASSWORDS.get(ident)
    if pwds:
        fpwd, rpwd = pwds
        h[0x030:0x038] = apa_password(ident, rpwd)
        h[0x038:0x040] = apa_password(ident, fpwd)
    raw = RAW_PASSWORDS.get(ident)
    if raw:
        h[0x030:0x038], h[0x038:0x040] = raw

    struct.pack_into("<I", h, 0x040, start)
    struct.pack_into("<I", h, 0x044, length)
    struct.pack_into("<H", h, 0x048, ptype)
    struct.pack_into("<H", h, 0x04A, 0)          # flags: not a sub-partition
    struct.pack_into("<I", h, 0x04C, 0)          # nsub
    h[0x050:0x058] = ps2time()
    struct.pack_into("<I", h, 0x060, MODVER)
    if is_mbr:
        h[0x100:0x100 + len(APA_MBR_MAGIC)] = APA_MBR_MAGIC
        struct.pack_into("<I", h, 0x120, APA_MBR_VERSION)
        struct.pack_into("<I", h, 0x124, nsector)
        h[0x128:0x130] = ps2time()
        struct.pack_into("<I", h, 0x130, 0)      # osdStart: no HDD-OSD
        struct.pack_into("<I", h, 0x134, 0)      # osdSize
    struct.pack_into("<I", h, 0x000, checksum(bytes(h)))
    return bytes(h)


def buddy_free(start, end):
    """Cover [start, end) with legal free partitions: each a power-of-two number
    of sectors, at least MIN_PART, starting on a multiple of its own length."""
    out = []
    pos = start
    while end - pos >= MIN_PART:
        size = MIN_PART
        while size * 2 <= min(end - pos, MAX_PART) and pos % (size * 2) == 0:
            size *= 2
        out.append((pos, size))
        pos += size
    return out


def plan(total_sectors):
    """Return [(start, length, type, id)] covering the whole drive, in order."""
    parts = [(0, MIN_PART, APA_TYPE_MBR, "__mbr")]
    pos = MIN_PART
    for name, size in SYSTEM_PARTS + GAME_PARTS:
        n = size // SECTOR
        assert n & (n - 1) == 0, "%s: length must be a power of two" % name
        pad = (-pos) % n                         # align start to its own length
        for fs, fl in buddy_free(pos, pos + pad):
            parts.append((fs, fl, APA_TYPE_FREE, EMPTY_ID))
        pos += pad
        parts.append((pos, n, APA_TYPE_PFS, name))
        pos += n
    for fs, fl in buddy_free(pos, total_sectors):
        parts.append((fs, fl, APA_TYPE_FREE, EMPTY_ID))
    return parts


def write_table(path, parts, total_sectors, dry_run=True):
    starts = [p[0] for p in parts]
    blobs = []
    for i, (start, length, ptype, ident) in enumerate(parts):
        nxt = starts[i + 1] if i + 1 < len(parts) else 0
        prev = starts[i - 1] if i > 0 else starts[-1]   # circular: __mbr.prev = last
        blobs.append((start, build_header(start, length, ptype, ident, nxt, prev,
                                          is_mbr=(i == 0), nsector=total_sectors)))
    if dry_run:
        return len(blobs)
    with open(path, "r+b") as f:
        for start, blob in blobs:
            f.seek(start * SECTOR)
            f.write(blob)
        f.flush()
        os.fsync(f.fileno())
    return len(blobs)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--image", required=True)
    ap.add_argument("--write", action="store_true", help="actually write (default: dry run)")
    args = ap.parse_args()

    total = os.path.getsize(args.image) // SECTOR
    parts = plan(total)
    named = [p for p in parts if p[3]]
    free = [p for p in parts if not p[3]]
    for start, length, ptype, ident in named:
        print("  %-32s LBA %9d  %6d MiB  type 0x%04x"
              % (ident or "(free)", start, length * SECTOR // MIB, ptype))
    print("  %d free partitions covering the tail" % len(free))
    covered = sum(p[1] for p in parts)
    print("\n  %d partitions, %d of %d sectors covered (%s)"
          % (len(parts), covered, total, "exact" if covered <= total else "overrun"))
    assert covered <= total, "layout exceeds the drive"

    n = write_table(args.image, parts, total, dry_run=not args.write)
    print("  %s %d headers %s %s" % ("wrote" if args.write else "would write",
                                     n, "to" if args.write else "to", args.image))


if __name__ == "__main__":
    main()

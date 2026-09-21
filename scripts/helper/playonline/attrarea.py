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
"""Build a PS2 APA attribute area from scratch.

An HDD browser (Sony's HDD-OSD, PSBBN, OSDMenu) never looks at a partition's
filesystem. It reads the attribute area 4 KiB into the partition, and shows
"Corrupted Data" when that area is zeroed. A newly created partition has no
attribute area, so this module builds one from material the disc carries.

Layout, as found on Square Enix's installed USA and JPN Viewer partitions,
which agree:

    partition + 0x0000   APA header (1024 B), untouched here
    partition + 0x1000   attribute area:
        0x0000  "PS2ICON3D", NUL padded to 0x10
        0x0010  four {u32 offset, u32 size}, offsets relative to 0x1000
        0x0030  zero to 0x200
        0x0200  slot 0: the boot block, SYSTEM.CNF grammar, CRLF lines
        0x0400  slot 1: icon.sys as PS2X text
        0x0600  slot 2: the 3D icon, a .ico file
                slot 3: the copy icon. The Viewer partitions point slot 3 at
                the same offset and size as slot 2, so one icon serves both.
        tail    zero to the next 512 boundary
    partition + 0x400000 the PFS superblock (sector 8192)

The space between the slots is zero. The Viewer's icon is
`POL/Data/PS2/system/image/playonline.ico` in the disc's install archive,
which is identical to slot 2 on an installed drive, so the icon comes from the
user's own disc and no Sony or Square Enix material ships with this package.

    python3 -m playonline.attrarea --build --boot BOOT.txt --icon-sys ICON.txt \
        --icon playonline.ico --out area.bin
    python3 -m playonline.attrarea --show DRIVE --part PP.SCUS-97269.1000.POLVIEWER
    python3 -m playonline.attrarea --verify area.bin --against DRIVE \
        --part PP.SCUS-97269.1000.POLVIEWER
"""
import argparse
import struct
import sys

MAGIC = b"PS2ICON3D"
ATTR_OFF = 0x1000                 # attribute area, relative to the partition
SECTOR = 512

SLOT_BOOT = 0x200                 # where Square Enix puts each slot. Fixed so
SLOT_ICON_SYS = 0x400             # a rebuilt area matches their layout.
SLOT_ICON = 0x600

# The Viewer partition's boot block. `product` is the title container the
# loader is pointed at. Square Enix's USA installer writes `ver` 1.00 and the
# Japanese one 1.01; nothing is known to read it.
BOOT_TEMPLATE = (
    "BOOT2 = pfs:/dnasload.elf\r\n"
    "DNASBOOT2 = pfs:/{product}\r\n"
    "VER = {ver}\r\n"
    "VMODE = NTSC\r\n"
    "HDDUNITPOWER = NICHDD\r\n"
)

# The 3D icon's lighting and background, as in Square Enix's icon.sys for the
# Viewer. The USA and JPN values are identical.
ICON_SYS_LOOK = (
    "bgcola=64\r\n"
    "bgcol0=0,0,0\r\n"
    "bgcol1=64,64,64\r\n"
    "bgcol2=0,0,0\r\n"
    "bgcol3=64,64,64\r\n"
    "lightdir0=1.0,-1.0,1.0\r\n"
    "lightdir1=-1.0,1.0,-1.0\r\n"
    "lightdir2=0.0,0.0,0.0\r\n"
    "lightcolamb=54,54,54\r\n"
    "lightcol0=54,54,54\r\n"
    "lightcol1=16,16,16\r\n"
    "lightcol2=0,0,0\r\n"
)

# The same block in the spelling FFXI, FMO and Dirge use.
ICON_SYS_LOOK_SPACED = "".join(
    line.replace("=", " = ", 1) for line in ICON_SYS_LOOK.splitlines(True))


def build_boot_block(product, ver="1.00", boot2="pfs:/dnasload.elf"):
    """The slot 0 text for a title whose container is `product`.

    On the POLVIEWER partition BOOT2 is the loader and DNASBOOT2 is the
    container. A title that the Viewer launches carries "BOOT2 = NOBOOT"
    instead, which stops the browser trying to run it.
    """
    if boot2 == "NOBOOT":
        text = "BOOT2 = NOBOOT\r\nVER = %s\r\nVMODE = NTSC\r\nHDDUNITPOWER = NICHDD\r\n" % ver
    else:
        text = BOOT_TEMPLATE.format(product=product, ver=ver)
    return text.encode("ascii")


def build_icon_sys(title0, title1="", uninstall=(), encoding="ascii", spaced=False):
    """The slot 1 text.

    `title0`/`title1` are the browser's two lines. `uninstall` is up to three
    lines shown before the browser deletes the partition.

    `encoding` is UTF-8 for the Japanese titles: Square Enix's installed
    partitions store UTF-8 there, where Shift-JIS might be expected.

    `spaced` picks between the two spellings in use. The PlayOnline
    partitions write `title0=X`; FFXI, Front Mission Online and Dirge of
    Cerberus write `title0 = X`. Both read back the same way, but reproducing
    a given partition byte for byte needs the right one.
    """
    eq = " = " if spaced else "="
    out = ["PS2X", "title0%s%s" % (eq, title0), "title1%s%s" % (eq, title1)]
    body = "\r\n".join(out) + "\r\n" + (ICON_SYS_LOOK_SPACED if spaced else ICON_SYS_LOOK)
    for i, line in enumerate(uninstall[:3]):
        body += "uninstallmes%d%s%s\r\n" % (i, eq, line)
    return body.encode(encoding)


def icon_sys_from_fields(fields, encoding="utf-8", spaced=False):
    """Re-emit a PS2X block from parsed (key, value) pairs, in order.

    Used to reproduce a PlayOnline partition exactly. The look block differs
    per title (FFXI uses bgcola 96 where PlayOnline uses 64), so an exact
    copy has to carry the original values through instead of a template.

    This assumes one separator spelling for the whole block, which holds for
    the PlayOnline partitions. It does not hold generally: FFXI writes
    `title0 = X` and `uninstallmes0 =X` in the same file and pads the block
    with trailing NULs, so reproducing such a block needs its raw lines.
    """
    eq = " = " if spaced else "="
    body = "PS2X\r\n" + "".join("%s%s%s\r\n" % (k, eq, v) for k, v in fields)
    return body.encode(encoding)


def build_area(boot, icon_sys, icon, copy_icon=None, icon_off=SLOT_ICON,
               copy_off=None, fill=b"\x00"):
    """Assemble the four slots into the bytes that go at partition + 0x1000.

    `icon_off` is where slot 2 starts: 0x600 on the PlayOnline partitions,
    0x800 on FFXI, Front Mission Online and Dirge of Cerberus.

    `copy_icon` is slot 3. Left None, slot 3 points at the same offset and
    size as slot 2, as on the Viewer and Front Mission Online partitions.
    FFXI and Dirge of Cerberus carry a second icon; pass it here with
    `copy_off`. The offset is explicit because the original placement is not
    derivable: Dirge's second icon starts at 0x13200 where the first one ends
    at 0x12BB0.

    Sizes are checked against the slot offsets, so a boot block or icon.sys
    that is too long raises ValueError instead of overlapping the next slot.
    """
    if len(boot) > SLOT_ICON_SYS - SLOT_BOOT:
        raise ValueError("boot block is %d B, the slot holds %d"
                         % (len(boot), SLOT_ICON_SYS - SLOT_BOOT))
    if len(icon_sys) > icon_off - SLOT_ICON_SYS:
        raise ValueError("icon.sys is %d B, the slot holds %d"
                         % (len(icon_sys), icon_off - SLOT_ICON_SYS))
    if not icon:
        raise ValueError("no icon: the browser shows Corrupted Data without one")

    end = icon_off + len(icon)
    if copy_icon:
        if copy_off is None:
            copy_off = (end + SECTOR - 1) & ~(SECTOR - 1)
        if copy_off < end:
            raise ValueError("the copy icon would overlap the icon")
        end = copy_off + len(copy_icon)
    else:
        copy_off = icon_off

    # `fill` is what goes between and after the slots. The PlayOnline areas
    # are zero-filled, which is the default. Dirge's is filled with a
    # repeating 0x43218765, so the pattern depends on the tool that wrote the
    # area and is a parameter. The header block (the first 0x200 bytes) is
    # zero-padded in every case; only the gaps from 0x200 on carry the fill.
    total = (end + SECTOR - 1) & ~(SECTOR - 1)
    area = bytearray((fill * (total // len(fill) + 1))[:total])
    area[0:SLOT_BOOT] = b"\x00" * SLOT_BOOT
    area[0:len(MAGIC)] = MAGIC
    struct.pack_into("<II", area, 0x10, SLOT_BOOT, len(boot))
    struct.pack_into("<II", area, 0x18, SLOT_ICON_SYS, len(icon_sys))
    struct.pack_into("<II", area, 0x20, icon_off, len(icon))
    struct.pack_into("<II", area, 0x28, copy_off, len(copy_icon or icon))
    area[SLOT_BOOT:SLOT_BOOT + len(boot)] = boot
    area[SLOT_ICON_SYS:SLOT_ICON_SYS + len(icon_sys)] = icon_sys
    area[icon_off:icon_off + len(icon)] = icon
    if copy_icon:
        area[copy_off:copy_off + len(copy_icon)] = copy_icon
    return bytes(area)


def is_area(blob):
    """True if these bytes begin an attribute area.

    Checks only the magic, so it accepts a 16-byte header read off a disc as
    well as a whole area.
    """
    return blob.startswith(MAGIC)


def title0_of(area):
    """The browser's first line, for matching an area to a title."""
    try:
        text = slots(area)[1][2].decode("utf-8", "replace")
    except (ValueError, IndexError):
        return None
    for line in text.split("\r\n"):
        if line.startswith("title0"):
            return line.split("=", 1)[1].strip()
    return None


def set_ver(area, ver):
    """Return `area` with slot 0's VER set to `ver`.

    Square Enix's installer copies the prebuilt area off the disc and changes
    only this field: `VER = 0.00` on the disc becomes `VER = 1.00` on an
    installed USA drive and 1.01 on a JPN one.
    """
    s = slots(area)
    boot = s[0][2].decode("latin-1")
    out = []
    for line in boot.split("\r\n"):
        if line.startswith("VER"):
            line = "VER = %s" % ver
        out.append(line)
    new_boot = "\r\n".join(out).encode("latin-1")
    if len(new_boot) != len(s[0][2]):
        # Lengths differ, so the area is rebuilt with a new slot table.
        same_icon = (s[2][0], s[2][1]) == (s[3][0], s[3][1])
        return build_area(new_boot, s[1][2], s[2][2],
                          None if same_icon else s[3][2],
                          icon_off=s[2][0],
                          copy_off=None if same_icon else s[3][0])
    patched = bytearray(area)
    patched[s[0][0]:s[0][0] + len(new_boot)] = new_boot
    return bytes(patched)


def set_title(area, title0, title1=None, encoding="utf-8"):
    """Return `area` with the browser's title lines replaced.

    Only the browser reads these lines, so a title can be renamed here
    without changing anything the game itself loads. The area is patched in
    place when the new text has the old length and rebuilt otherwise.
    """
    s = slots(area)
    for enc in (encoding, "utf-8", "latin-1"):
        try:
            text = s[1][2].decode(enc)
            break
        except UnicodeDecodeError:
            continue
    out = []
    for line in text.split("\r\n"):
        if line.startswith("title0="):
            line = "title0=%s" % title0
        elif title1 is not None and line.startswith("title1="):
            line = "title1=%s" % title1
        out.append(line)
    new = "\r\n".join(out).encode(encoding)
    if len(new) == len(s[1][2]):
        patched = bytearray(area)
        patched[s[1][0]:s[1][0] + len(new)] = new
        return bytes(patched)
    same_icon = (s[2][0], s[2][1]) == (s[3][0], s[3][1])
    return build_area(s[0][2], new, s[2][2],
                      None if same_icon else s[3][2],
                      icon_off=s[2][0],
                      copy_off=None if same_icon else s[3][0])


def slots(area):
    """[(offset, size, bytes)] for the four slots of an existing area."""
    if not area.startswith(MAGIC):
        raise ValueError("not an attribute area: magic is %r" % area[:16])
    out = []
    for i in range(4):
        off, size = struct.unpack_from("<II", area, 0x10 + i * 8)
        out.append((off, size, area[off:off + size] if size else b""))
    return out


def read_area(path, lba):
    """Read an area off a drive or image, sized from its own slot table."""
    with open(path, "rb") as f:
        f.seek(lba * SECTOR + ATTR_OFF)
        head = f.read(0x200)
        if not head.startswith(MAGIC):
            return None
        end = 0
        for i in range(4):
            off, size = struct.unpack_from("<II", head, 0x10 + i * 8)
            if size and off + size > end:
                end = off + size
        end = (end + SECTOR - 1) & ~(SECTOR - 1)
        f.seek(lba * SECTOR + ATTR_OFF)
        return f.read(end)


def describe(area):
    lines = ["area: %d B" % len(area)]
    for i, (off, size, blob) in enumerate(slots(area)):
        if not size:
            lines.append("  slot %d empty" % i)
            continue
        printable = sum(1 for c in blob[:40] if 32 <= c < 127) > 30
        head = blob[:48].decode("latin-1").replace("\r\n", " | ") if printable else "<binary>"
        lines.append("  slot %d off=0x%04x size=%-6d %s" % (i, off, size, head))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--boot", help="slot 0 text file, or use --product")
    ap.add_argument("--product", help="container name, e.g. SCUS-97269")
    ap.add_argument("--ver", default="1.00")
    ap.add_argument("--noboot", action="store_true",
                    help="write BOOT2 = NOBOOT (a title the Viewer launches)")
    ap.add_argument("--icon-sys", help="slot 1 text file, or use --title0")
    ap.add_argument("--title0")
    ap.add_argument("--title1", default="")
    ap.add_argument("--encoding", default="ascii",
                    help="icon.sys encoding: ascii, or utf-8 for a JP title")
    ap.add_argument("--icon", help="the .ico from the disc install tree")
    ap.add_argument("--out")
    ap.add_argument("--show", metavar="DRIVE")
    ap.add_argument("--part")
    ap.add_argument("--lba", type=int)
    ap.add_argument("--verify", metavar="AREA")
    ap.add_argument("--against", metavar="DRIVE")
    args = ap.parse_args()

    if args.show or args.against:
        path = args.show or args.against
        lba = args.lba
        if lba is None:
            if not args.part:
                sys.exit("--show needs --part NAME or --lba N")
            from . import apa
            lba = apa.find_partition(path, args.part)[0]
        area = read_area(path, lba)
        if area is None:
            sys.exit("%s: no attribute area at LBA %d (a zeroed one reads as "
                     "Corrupted Data in the browser)" % (path, lba))
        if args.show:
            print(describe(area))
            return
        built = open(args.verify, "rb").read()
        if built == area:
            print("identical: %d B" % len(built))
            return
        print("different: built %d B, on-drive %d B" % (len(built), len(area)))
        for i, ((o1, s1, b1), (o2, s2, b2)) in enumerate(zip(slots(built), slots(area))):
            if (o1, s1, b1) != (o2, s2, b2):
                print("  slot %d differs: built off=0x%x size=%d, drive off=0x%x size=%d"
                      % (i, o1, s1, o2, s2))
        sys.exit(1)

    if args.build:
        if args.boot:
            boot = open(args.boot, "rb").read()
        elif args.product or args.noboot:
            boot = build_boot_block(args.product or "", args.ver,
                                    "NOBOOT" if args.noboot else "pfs:/dnasload.elf")
        else:
            sys.exit("--build needs --boot FILE or --product NAME or --noboot")
        if args.icon_sys:
            icon_sys = open(args.icon_sys, "rb").read()
        elif args.title0:
            icon_sys = build_icon_sys(args.title0, args.title1, encoding=args.encoding)
        else:
            sys.exit("--build needs --icon-sys FILE or --title0 TEXT")
        if not args.icon:
            sys.exit("--build needs --icon FILE (from the disc install tree)")
        area = build_area(boot, icon_sys, open(args.icon, "rb").read())
        if args.out:
            with open(args.out, "wb") as f:
                f.write(area)
            print("wrote %s, %d B" % (args.out, len(area)))
        else:
            print(describe(area))
        return

    ap.print_help()


if __name__ == "__main__":
    main()

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
"""Fill in the boot loader this package writes as `dnasload.elf`.

On a drive without a Sony HDD ID the Viewer powers the console off (see
hddid.py), and the shim that serves an ID, `atadpatch.irx`, must be resident
on the IOP before the Viewer's drivers register. Square Enix's `dnasload` has
no room for it: the IOP reboot image in the boot container cannot grow,
because each section's length is carried in an RSA block. This package
therefore boots its own loader, which reboots the IOP from a supplied image,
installs the shim with the install's HDD ID, and enters the Viewer's boot ELF
(section 2 of the boot container) directly.

The loader ships compiled and signed. Only the first 32 content bytes of the
KELF are signed and encrypted; the rest is one unsigned block, so an install
fills it in place and needs neither a ps2sdk toolchain nor console keys. The
install's choices live in one struct, located by its magic:

    magic[16]      POLBBNFORKHDR1
    version        u32
    elf_capacity   u32     size of the reserved slot
    elf_len        u32     0 means the loader has not been filled
    ioprp_capacity u32
    ioprp_len      u32
    handover_addr  u32     one word written to low memory before ExecPS2,
    handover_value u32     as stock dnasload does; address 0 writes nothing
    argv0[192]     argv[0] the Viewer is entered with
    hddid[512]     the block the shim serves
    elf[capacity]
    ioprp[capacity]

The loader refuses to hand over if the ELF, the reboot image or the HDD ID is
missing.

    python3 -m playonline.loader LOADER.kelf --show
    python3 -m playonline.loader LOADER.kelf --elf BOOT.elf --ioprp IOPRP.img \\
        --hddid DRIVE.hddid --argv0 'hdd0:PP.X:pfs:/Y' -o dnasload.elf
"""
import argparse
import os
import struct
import sys

# The name is historical; it is compiled into the shipped loader.
MAGIC = b"POLBBNFORKHDR1"

# The signed loader this package ships, built by loader-src/build.sh.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "..", ".."))
SHIPPED = os.path.join(ROOT, "scripts", "assets", "playonline", "polbbnexec.kelf")

# Offsets within the struct, from its magic. They must match the C definition
# in polbbnexec.c; --show prints what the loader itself would read.
O_VERSION = 16
O_ELF_CAP = 20
O_ELF_LEN = 24
O_IOPRP_CAP = 28
O_IOPRP_LEN = 32
O_HANDOVER_ADDR = 36
O_HANDOVER_VALUE = 40
O_ARGV0 = 44
ARGV0_MAX = 192
O_HDDID = 236
HDDID_LEN = 512

# Where the two payload slots start, by header version.
#
# The IOP reboot image is handed to SifIopRebootBuffer, which DMAs it from the
# slot's address, and the EE DMAC ignores the low four address bits. The
# struct is 64-byte aligned and both slots are aligned to 64 bytes, at +768
# and +768+capacity.
VERSION = 3
SLOTS_BY_VERSION = {3: 768}

SCE_MAGIC = b"Sony Computer Entertainment Inc."


class NotFilled(ValueError):
    pass


def locate(blob):
    """Return the offset of the install header.

    The magic occurs once in a loader this package ships, so more than one
    hit is an error.
    """
    hits = []
    i = blob.find(MAGIC)
    while i >= 0:
        hits.append(i)
        i = blob.find(MAGIC, i + 1)
    if not hits:
        raise NotFilled("no %s header in this file - is it the loader KELF?"
                        % MAGIC.decode())
    if len(hits) > 1:
        raise NotFilled("%d install headers at %s - refusing to guess"
                        % (len(hits), ", ".join(str(h) for h in hits)))
    return hits[0]


def _u32(blob, off):
    return struct.unpack_from("<I", blob, off)[0]


def read(blob):
    """Return the install header's fields as a dict."""
    h = locate(blob)
    version = _u32(blob, h + O_VERSION)
    if version not in SLOTS_BY_VERSION:
        raise NotFilled("install header version %d; this code knows %s"
                        % (version, ", ".join(str(v) for v in sorted(SLOTS_BY_VERSION))))
    slots = SLOTS_BY_VERSION[version]
    cap_elf = _u32(blob, h + O_ELF_CAP)
    cap_ioprp = _u32(blob, h + O_IOPRP_CAP)
    end = h + slots + cap_elf + cap_ioprp
    if end > len(blob):
        raise NotFilled("the header says %d bytes of slots and the file ends "
                        "%d bytes short" % (cap_elf + cap_ioprp, end - len(blob)))
    hddid = blob[h + O_HDDID:h + O_HDDID + HDDID_LEN]
    return {
        "offset": h,
        "version": version,
        "elf_capacity": cap_elf,
        "elf_len": _u32(blob, h + O_ELF_LEN),
        "ioprp_capacity": cap_ioprp,
        "ioprp_len": _u32(blob, h + O_IOPRP_LEN),
        "handover_addr": _u32(blob, h + O_HANDOVER_ADDR),
        "handover_value": _u32(blob, h + O_HANDOVER_VALUE),
        "argv0": blob[h + O_ARGV0:h + O_ARGV0 + ARGV0_MAX].split(b"\0")[0].decode("latin-1"),
        "hddid": hddid,
        "has_hddid": hddid.startswith(SCE_MAGIC),
        "elf_at": h + slots,
        "ioprp_at": h + slots + cap_elf,
    }


def _check_unsigned_region(blob, h):
    """Refuse to patch inside the signed region of the KELF.

    HeaderSize is a u16 at +20 and the content starts there. The first
    content block, 32 bytes, is the only signed and encrypted one in a loader
    this package ships; no signature covers anything after it.
    """
    if len(blob) < 32:
        raise NotFilled("too short to be a KELF")
    header_size = struct.unpack_from("<H", blob, 20)[0]
    first_unsigned = header_size + 32
    if h < first_unsigned:
        raise NotFilled("the install header is at %d, inside the signed region "
                        "that ends at %d" % (h, first_unsigned))


def fill(blob, boot_elf=None, ioprp=None, hddid=None, argv0=None):
    """Write an install's choices into the loader and return the new bytes.

    The file length never changes, so the signatures over the header and the
    bit table stay correct.
    """
    info = read(blob)
    h = info["offset"]
    _check_unsigned_region(blob, h)
    out = bytearray(blob)

    if boot_elf is not None:
        if not boot_elf.startswith(b"\x7fELF"):
            raise NotFilled("the boot ELF does not start \\x7fELF - section 2 "
                            "of the boot container is the one that does")
        if len(boot_elf) > info["elf_capacity"]:
            raise NotFilled("the boot ELF is %d bytes and the slot holds %d"
                            % (len(boot_elf), info["elf_capacity"]))
        out[info["elf_at"]:info["elf_at"] + len(boot_elf)] = boot_elf
        struct.pack_into("<I", out, h + O_ELF_LEN, len(boot_elf))

    if ioprp is not None:
        if not ioprp.startswith(b"RESET"):
            raise NotFilled("the IOP reboot image does not start RESET - "
                            "section 1 of the boot container is the one that does")
        if len(ioprp) > info["ioprp_capacity"]:
            raise NotFilled("the IOPRP is %d bytes and the slot holds %d"
                            % (len(ioprp), info["ioprp_capacity"]))
        out[info["ioprp_at"]:info["ioprp_at"] + len(ioprp)] = ioprp
        struct.pack_into("<I", out, h + O_IOPRP_LEN, len(ioprp))

    if hddid is not None:
        if len(hddid) != HDDID_LEN:
            raise NotFilled("an HDD ID block is %d bytes, got %d"
                            % (HDDID_LEN, len(hddid)))
        if not hddid.startswith(SCE_MAGIC):
            raise NotFilled("that block does not start %r" % SCE_MAGIC)
        out[h + O_HDDID:h + O_HDDID + HDDID_LEN] = hddid

    if argv0 is not None:
        raw = argv0.encode("latin-1")
        if len(raw) >= ARGV0_MAX:
            raise NotFilled("argv[0] is %d bytes and the field holds %d "
                            "including its terminator" % (len(raw), ARGV0_MAX))
        out[h + O_ARGV0:h + O_ARGV0 + ARGV0_MAX] = raw + b"\0" * (ARGV0_MAX - len(raw))

    if len(out) != len(blob):
        raise AssertionError("the patch changed the file length")
    return bytes(out)


def gate_patch(boot_elf):
    """Apply the Viewer's gate patches to a bare boot ELF.

    The patches are normally applied to the installed container. The loader
    enters the ELF directly, so they are applied here first; the checks are
    inside the Viewer and run however it was loaded.

    The patch tables come from `ci_viewerpatch`. Its `detect` also matches a
    site that is already patched, so every write is guarded: a word is
    written only where the current word is the expected original, a site
    already holding the new word counts as done, and any other value refuses
    the whole file.

    Returns (build label, patched bytes, [lines]).
    """
    import struct as _struct
    import tempfile
    from .lib import ci_viewerpatch
    from .lib.mips import Image

    with tempfile.NamedTemporaryFile(suffix=".elf", delete=False) as tf:
        tf.write(boot_elf)
        tmp = tf.name
    try:
        label, patches = ci_viewerpatch.detect(tmp)
        if label is None:
            raise NotFilled("this boot ELF matches no known build: %s"
                            % ", ".join("%s %d" % kv for kv in sorted(patches.items())))
        img = Image(tmp)
        out = bytearray(boot_elf)
        lines, done, written, wrong = [], 0, 0, []
        for addr, orig, new, what in patches:
            off = img.off(addr)
            cur = _struct.unpack_from("<I", out, off)[0]
            if cur == new:
                done += 1
                continue
            if cur != orig:
                wrong.append("0x%08x holds 0x%08x, expected 0x%08x (%s)"
                             % (addr, cur, orig, what))
                continue
            _struct.pack_into("<I", out, off, new)
            written += 1
        if wrong:
            raise NotFilled("refusing to patch %s: %d site(s) hold neither the "
                            "original nor the patch:\n  %s"
                            % (label, len(wrong), "\n  ".join(wrong)))
        lines.append("  build       %s" % label)
        lines.append("  gates       %d written, %d already patched, %d total"
                     % (written, done, len(patches)))
        return label, bytes(out), lines
    finally:
        os.unlink(tmp)


def argv0_for(title, boot_file):
    """Return the argv[0] Square Enix's loader builds for its child.

    The form is `%s:%s:pfs:/%s`, as seen on a genuine drive. The Viewer reads
    its own partition name out of it.
    """
    return "hdd0:%s:pfs:/%s" % (title.partition, boot_file)


def carve(container):
    """Return (IOP reboot image, Viewer boot ELF) from a universal boot container.

    The container has three sections: one is a romdir archive beginning
    `RESET` and one is an ELF. They are selected by content rather than by
    index, so a container holding anything else is refused here.

    A universal container carries its own bulk key, so no drive, console or
    HDD ID is needed. `ci_universal` does the reading.
    """
    from .lib import ci_universal
    blob = container if isinstance(container, (bytes, bytearray)) else _read(container)
    if not ci_universal.is_universal(blob):
        raise NotFilled("that container is in the installed form. Carve the "
                        "staged tree's container before `route prepare` "
                        "converts it, or carve one off a disc.")
    ioprp = boot = None
    found = []
    for off, size in ci_universal.sections(blob):
        mod, _tag = ci_universal.module(blob[off:off + size])
        found.append("%d bytes, head %s" % (len(mod), mod[:4].hex()))
        if mod.startswith(b"RESET") and ioprp is None:
            ioprp = mod
        elif mod.startswith(b"\x7fELF") and boot is None:
            boot = mod
    if ioprp is None or boot is None:
        raise NotFilled("this container holds no %s: %s"
                        % (" and no ".join(
                            [w for w, v in (("IOP reboot image", ioprp),
                                            ("boot ELF", boot)) if v is None]),
                           "; ".join(found)))
    return ioprp, boot


def stage(container, hddid, loader_kelf, argv0, out, disc=None, derive_elf=None):
    """Write the `dnasload.elf` this install will boot from.

    The inputs are the disc's boot container and the HDD ID minted for this
    install. Nothing is compiled or signed.

    Returns lines describing what was staged, for the caller to print.
    """
    # Reading a container needs Square Enix's public keys, which come from a
    # disc boot executable, as in every other step of an install.
    from . import route
    route.use_keys(disc, derive_elf)

    ioprp, boot = carve(container)
    label, boot, lines = gate_patch(boot)
    blob = fill(_read(loader_kelf) if not isinstance(loader_kelf, (bytes, bytearray))
                else loader_kelf,
                boot_elf=boot, ioprp=ioprp,
                hddid=_read(hddid) if not isinstance(hddid, (bytes, bytearray)) else hddid,
                argv0=argv0)
    with open(out, "wb") as f:
        f.write(blob)
    return ["  loader      %s (%d bytes)" % (os.path.basename(out), len(blob))] \
        + lines + describe(read(blob)).split("\n")[2:]


def describe(info):
    lines = ["  header at   %d" % info["offset"],
             "  version     %d" % info["version"],
             "  boot ELF    %d of %d bytes" % (info["elf_len"], info["elf_capacity"]),
             "  IOPRP       %d of %d bytes" % (info["ioprp_len"], info["ioprp_capacity"]),
             "  argv[0]     %s" % (info["argv0"] or "(empty)"),
             "  handover    [0x%08x] = 0x%08x" % (info["handover_addr"],
                                                  info["handover_value"])
             if info["handover_addr"] else "  handover    nothing written",
             "  HDD ID      %s" % ("present" if info["has_hddid"] else "not written")]
    missing = []
    if not info["elf_len"]:
        missing.append("boot ELF")
    if not info["ioprp_len"]:
        missing.append("IOPRP")
    if not info["has_hddid"]:
        missing.append("HDD ID")
    if missing:
        lines.append("  [!] this loader would refuse to boot: no %s"
                     % ", ".join(missing))
    return "\n".join(lines)


def _read(path):
    with open(path, "rb") as f:
        return f.read()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("loader", help="the signed loader KELF this package ships")
    ap.add_argument("--show", action="store_true",
                    help="print what the loader would read out of itself")
    ap.add_argument("--elf", help="the Viewer's boot ELF (boot container section 2)")
    ap.add_argument("--ioprp", help="the IOP reboot image (boot container section 1)")
    ap.add_argument("--hddid", help="the 512-byte block the shim must serve")
    ap.add_argument("--argv0", help="what the Viewer is entered with")
    ap.add_argument("--container", metavar="FILE",
                    help="a universal boot container to take the boot ELF and "
                         "the IOP reboot image out of, instead of --elf/--ioprp")
    ap.add_argument("--derive-elf", help="a disc boot executable to read Square "
                                         "Enix's keys out of, as `route` wants")
    ap.add_argument("--disc", help="a disc image to take the keystore from instead")
    ap.add_argument("-o", "--out", help="write the filled loader here")
    args = ap.parse_args()

    if args.container:
        if not (args.hddid and args.argv0 and args.out):
            print("--container needs --hddid, --argv0 and -o", file=sys.stderr)
            return 1
        from . import discs
        for line in stage(args.container, args.hddid, args.loader,
                          args.argv0, args.out,
                          disc=discs.identify(args.disc) if args.disc else None,
                          derive_elf=args.derive_elf):
            print(line)
        return 0

    blob = _read(args.loader)
    if args.show or not (args.elf or args.ioprp or args.hddid or args.argv0):
        print("%s  %d bytes" % (os.path.basename(args.loader), len(blob)))
        print(describe(read(blob)))
        return 0

    out = fill(blob,
               boot_elf=_read(args.elf) if args.elf else None,
               ioprp=_read(args.ioprp) if args.ioprp else None,
               hddid=_read(args.hddid) if args.hddid else None,
               argv0=args.argv0)
    if not args.out:
        print("nothing written: pass -o to save the filled loader", file=sys.stderr)
        print(describe(read(out)))
        return 1
    with open(args.out, "wb") as f:
        f.write(out)
    print("wrote %s (%d bytes)" % (args.out, len(out)))
    print(describe(read(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

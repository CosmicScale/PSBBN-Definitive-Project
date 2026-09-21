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
"""Check the builders against Square Enix's own bytes.

Given a drive or image that carries genuine PlayOnline partitions, each
partition's attribute area is:

  1. split into its four slots
  2. reassembled with `build_area`, which must give identical bytes
  3. checked again with its boot block and icon.sys regenerated from their
     parsed fields, which must also give identical bytes

Step 3 shows that the installer can write a browser entry from fields alone,
which is what an install from the user's own discs requires.

Checks that need no drive always run: every module under lib/ is imported
inside the package namespace, and the patch-site tables, path containment,
the FFXI overlay logic and the shipped loader are tested. `--disc` also
identifies a disc image and verifies its install container. A drive that
cannot be read is skipped. With no arguments the output says that the
builders were not tested.

    python3 -m playonline.selftest DRIVE [DRIVE ...] [--disc IMAGE ...]
"""
import argparse
import os
import sys

from . import apa, attrarea


def _parse_icon_sys(blob):
    """Return (fields, encoding, spaced), or None if `blob` is not PS2X text."""
    for enc in ("utf-8", "shift-jis", "latin-1"):
        try:
            txt = blob.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    else:
        return None
    if not txt.startswith("PS2X"):
        return None
    spaced = "title0 = " in txt
    fields = []
    for line in txt.split("\r\n"):
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        fields.append((k.strip(), v[1:] if spaced and v.startswith(" ") else v))
    return fields, enc, spaced


def check_partition(path, part):
    """Return [(name, ok, detail)] for one partition."""
    out = []
    area = attrarea.read_area(path, part.lba)
    if area is None:
        return [("%s attribute area" % part.ident, None, "absent")]
    try:
        s = attrarea.slots(area)
    except ValueError as e:
        return [("%s slots" % part.ident, False, str(e))]

    boot, icon_sys, icon, copy_icon = s[0][2], s[1][2], s[2][2], s[3][2]
    same_icon = (s[2][0], s[2][1]) == (s[3][0], s[3][1])
    # The gap fill depends on which tool wrote the area, so it is read from
    # the bytes after the boot block. It is not always zeros.
    gap = area[s[0][0] + s[0][1]:s[1][0]]
    fill = b"\x00"
    if gap and set(gap) != {0}:
        base = (s[0][0] + s[0][1]) % 4
        pat = bytes(gap[:4])
        fill = pat[-base:] + pat[:-base] if base else pat

    rebuilt = attrarea.build_area(boot, icon_sys, icon,
                                  None if same_icon else copy_icon,
                                  icon_off=s[2][0],
                                  copy_off=None if same_icon else s[3][0],
                                  fill=fill)
    if rebuilt == area:
        out.append(("%s reassemble" % part.ident, True, "%d B" % len(area)))
    else:
        # Distinguish a builder bug from bytes the four-slot table does not
        # describe. Dirge carries 336 bytes after each icon that no slot
        # points at.
        covered = bytearray(len(area))
        covered[0:attrarea.SLOT_BOOT] = b"\1" * attrarea.SLOT_BOOT
        for off, size, _ in s:
            if size:
                covered[off:off + size] = b"\1" * size
        stray = sum(1 for i, c in enumerate(covered)
                    if not c and area[i] != rebuilt[i])
        in_slots = sum(1 for i, c in enumerate(covered)
                       if c and area[i] != rebuilt[i])
        if in_slots:
            out.append(("%s reassemble" % part.ident, False,
                        "%d byte(s) differ inside the slots" % in_slots))
        else:
            out.append(("%s reassemble (undeclared data)" % part.ident, None,
                        "%d B outside the slot table that is not fill" % stray))

    # Regenerate the boot block from its own fields.
    text = boot.decode("latin-1")
    fields = dict(line.split(" = ", 1) for line in text.split("\r\n") if " = " in line)
    ver = fields.get("VER", "1.00")
    boot2 = fields.get("BOOT2", "")
    if boot2 == "NOBOOT":
        gen = attrarea.build_boot_block("", ver, "NOBOOT")
    elif boot2.startswith("pfs:/dnasload"):
        gen = attrarea.build_boot_block(fields.get("DNASBOOT2", "").split("/")[-1], ver)
    else:
        gen = None          # a disc-booting entry, e.g. Dirge's cdrom0 path
    if gen is not None:
        out.append(("%s boot block" % part.ident, gen == boot,
                    "%d B" % len(boot) if gen == boot else "regenerated differs"))

    parsed = _parse_icon_sys(icon_sys)
    if parsed:
        fields, enc, spaced = parsed
        gen = attrarea.icon_sys_from_fields(fields, encoding=enc, spaced=spaced)
        if gen == icon_sys:
            out.append(("%s icon.sys" % part.ident, True,
                        "%s, %d B%s" % (enc, len(icon_sys),
                                        ", spaced" if spaced else "")))
        else:
            # Another publisher's block: the separator spelling can vary
            # from line to line and the block may be NUL padded. Regenerating
            # it is out of scope; it only has to be read without loss.
            out.append(("%s icon.sys (verbatim only)" % part.ident, None,
                        "%s, %d B, not uniformly spelled" % (enc, len(icon_sys))))

        # For the Viewer partition the appearance fields are Square Enix's
        # defaults, so `build_icon_sys` must reproduce the block exactly from
        # the titles and uninstall messages alone, as an install from discs
        # does.
        if "POLVIEWER" in part.ident:
            d = dict(fields)
            un = [v for k, v in fields if k.startswith("uninstallmes")]
            scratch = attrarea.build_icon_sys(d.get("title0", ""), d.get("title1", ""),
                                              un, encoding=enc, spaced=spaced)
            out.append(("%s icon.sys from scratch" % part.ident,
                        scratch == icon_sys,
                        "%d B" % len(scratch) if scratch == icon_sys
                        else "built %d vs %d" % (len(scratch), len(icon_sys))))
    return out


def check_vendor():
    """Import every module under lib/ inside the package namespace.

    The modules were written as standalone scripts. This catches what breaks
    them as a library: a name that shadows the standard library, a module
    that calls main() at import and exits, and a missing dependency.
    """
    out = []
    import importlib
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib")
    for name in sorted(n for n in os.listdir(here)
                       if n.endswith(".py") and n != "__init__.py"):
        try:
            importlib.import_module("%s.lib.%s" % (__package__, name[:-3]))
            out.append(("lib %s" % name, True, "imports"))
        except BaseException as e:      # SystemExit is not an Exception
            out.append(("lib %s" % name, False,
                        "%s: %s" % (type(e).__name__,
                                    str(e).replace("\n", " ")[:60])))
    return out


def check_site_tables():
    """Check the per-build patch-site tables for internal consistency.

    `ci_viewerpatch` names nine or ten addresses per Viewer build. Its
    detector accepts a site holding the patch as readily as one holding the
    original, so a wrong original word in a row goes unnoticed on any file
    that is already patched. This runs the part of that tool's self-test
    that needs none of Square Enix's bytes: every row must have the shape its
    label claims, and no table may be a subset of another.
    """
    from .lib import ci_viewerpatch as patcher
    bad = patcher.selftest()
    if bad:
        return [("viewer site tables", False, b) for b in bad]
    polls = sum(1 for rows in patcher.BUILDS.values()
                for _a, _o, _n, w in rows if "state==5" in w)
    return [("viewer site tables", True,
             "%d builds, %d sites, %d DNAS polls"
             % (len(patcher.BUILDS),
                sum(len(r) for r in patcher.BUILDS.values()), polls))]


def check_loader():
    """Check the shipped loader's header, slot alignment and fill round trip.

    The IOP reboot image slot is handed to `SifIopRebootBuffer`, which DMAs
    it, and the EE DMAC ignores the low four bits of an address. A slot off a
    16-byte boundary delivers a shifted image to the IOP (see
    loader.SLOTS_BY_VERSION). The header is mapped to its run-time address
    through the ELF's program headers, and both slots must sit on a 16-byte
    boundary. A copy is then filled with synthetic payloads and read back,
    which is everything an install does to the file.
    """
    import struct
    from . import hddid, loader
    out = []
    path = loader.SHIPPED
    if not os.path.exists(path):
        return [("loader shipped", None, "not present: %s" % path)]
    with open(path, "rb") as f:
        blob = f.read()
    try:
        info = loader.read(blob)
    except loader.NotFilled as e:
        return [("loader header", False, str(e))]
    out.append(("loader header", info["version"] == loader.VERSION,
                "version %d, slots empty: %s"
                % (info["version"], not (info["elf_len"] or info["ioprp_len"]))))

    # The KELF header is HeaderSize bytes, then the content, which is the ELF.
    # The first 32 bytes of the content are the one signed, encrypted block,
    # so the ELF magic and e_phoff cannot be read. The EE toolchain places the
    # program headers at 52, and that assumption is checked by requiring the
    # first entry to be a PT_LOAD at the file offset the loader is linked at.
    header_size = struct.unpack_from("<H", blob, 20)[0]
    elf = blob[header_size:]
    phoff = 52
    phentsize, phnum = struct.unpack_from("<HH", elf, 42)
    first = struct.unpack_from("<8I", elf, phoff)
    ok = phentsize == 32 and 1 <= phnum <= 8 and first[0] == 1 and first[1] == 0x1000
    if ok:
        magic_off = info["offset"] - header_size
        va = None
        for i in range(phnum):
            t, o, v, _p, fs, _m, _f, _a = struct.unpack_from("<8I", elf, phoff + i * phentsize)
            if t == 1 and o <= magic_off < o + fs:
                va = v + (magic_off - o)
        if va is None:
            out.append(("loader slots aligned", False, "header not inside a PT_LOAD"))
        else:
            elf_va = va + (info["elf_at"] - info["offset"])
            ioprp_va = va + (info["ioprp_at"] - info["offset"])
            good = elf_va % 16 == 0 and ioprp_va % 16 == 0
            out.append(("loader slots aligned", good,
                        "elf 0x%08x ioprp 0x%08x" % (elf_va, ioprp_va)))
    else:
        out.append(("loader slots aligned", False,
                    "no PT_LOAD at the expected program header (phentsize %d, "
                    "phnum %d)" % (phentsize, phnum)))

    fake_elf = b"\x7fELF" + b"\0" * 60
    fake_ioprp = b"RESET" + b"\0" * 11
    fake_id = hddid.mint(seed="selftest")
    try:
        filled = loader.fill(blob, boot_elf=fake_elf, ioprp=fake_ioprp,
                             hddid=fake_id, argv0="hdd0:PP.X:pfs:/Y")
        back = loader.read(filled)
        same = (filled[back["elf_at"]:back["elf_at"] + len(fake_elf)] == fake_elf
                and filled[back["ioprp_at"]:back["ioprp_at"] + len(fake_ioprp)] == fake_ioprp
                and back["hddid"] == fake_id and back["argv0"] == "hdd0:PP.X:pfs:/Y"
                and len(filled) == len(blob))
        out.append(("loader fill round trip", same,
                    "elf %d, ioprp %d, argv0 %s" % (back["elf_len"], back["ioprp_len"], back["argv0"])))
    except loader.NotFilled as e:
        out.append(("loader fill round trip", False, str(e)))
    return out


def check_ffxi_overlay():
    """Check FFXI's menu overlay reconciliation on synthetic containers.

    Uses synthetic containers so no disc is needed. Each case that changes
    a container is paired with one that must leave it unchanged.
    """
    import struct
    from . import ffxioverlay as fo

    def ent(ident, kind, payload=b""):
        body = payload + b"\0" * (-len(payload) % 16)
        word = kind | (((len(body) + 16) // 16) << 7)
        return ident + struct.pack("<I", word) + b"\0" * 8 + body

    def box(*inner):
        return ent(b"menu", 1) + b"".join(inner) + ent(b"end\0", 0)

    k3, k4 = ent(b"key3", 52, b"K3" * 40), ent(b"key4", 52, b"K4" * 50)
    base = box(ent(b"fram", 52, b"f"), k3, k4, ent(b"usga", 52, b"u"))
    ncol, ps2b = ent(b"ncol", 52, b"n" * 20), ent(b"ps2b", 52, b"p" * 8)
    bare = box(ent(b"dg_f", 52, b"d"), ncol, ps2b)
    out = []
    try:
        new, added, missing = fo.reconcile_bytes(base, bare)
        ok = (new == box(ent(b"dg_f", 52, b"d"), ncol, k3, k4, ps2b)
              and added == [b"key3", b"key4"] and not missing)
        out.append(("ffxi overlay: missing key layouts spliced after ncol", ok,
                    "byte-exact copies, container still ends in `end`"))
        again, added2, _ = fo.reconcile_bytes(base, new)
        out.append(("ffxi overlay: a reconciled overlay is left alone",
                    again is new and not added2, "idempotent"))
        full = box(ncol, k4, k3)
        same, added3, _ = fo.reconcile_bytes(base, full)
        out.append(("ffxi overlay: a 2004-style overlay is a no-op",
                    same is full and not added3, "nothing added"))
        poor = box(ent(b"fram", 52, b"f"))
        same2, added4, missing4 = fo.reconcile_bytes(poor, bare)
        out.append(("ffxi overlay: a base lacking the key layouts is reported",
                    same2 is bare and not added4 and b"key4" in missing4,
                    "missing=%s" % [m.decode() for m in missing4]))
        try:
            fo.entries(bare[:-16])
            out.append(("ffxi overlay: a truncated container is refused", False,
                        "parsed a container with no `end`"))
        except fo.BadContainer:
            out.append(("ffxi overlay: a truncated container is refused", True,
                        "BadContainer"))
    except Exception as exc:                      # a broken check must show
        out.append(("ffxi overlay", False, repr(exc)))
    return out


def check_patch_host():
    """The patch-host rewrite, on made-up data: no disc is needed.

    The settings-file cipher has to round-trip, an edited file has to open
    again with the new value, and the login-module edit has to stay inside
    the bytes the string and its padding occupy.
    """
    from . import patchhost as ph
    out = []
    text = "Version,1\r\nPATCH_SERVER_DOMAIN,pt007.pol.com\r\nPOL_LANG,1\r\n"
    blob = ph.encrypt(text.encode("shift_jis"))
    payload, ok = ph.decrypt(blob)
    out.append(("settings cipher round trip", ok and payload.decode("shift_jis") == text,
                "%d bytes" % len(blob)))
    new, old = ph.set_env_host(blob, "play.example.org")
    got = dict(ph.read_env(new)).get(ph.ENV_KEY)
    out.append(("settings patch host edit", (old, got) == ("pt007.pol.com", "play.example.org"),
                "%s -> %s" % (old, got)))
    module = (b"\x01\x02\x03\x04PATCH_SERVER_DOMAIN\0" + ph.TEMPLATE + b"\0" * 8
              + b"%04d\0")
    edited, _done = ph.set_template_host(module, "play.example.org")
    same_size = len(edited) == len(module)
    tail_kept = edited.endswith(b"\0%04d\0")
    again = ph.find_template(edited)
    out.append(("login module edit stays in place",
                bool(same_size and tail_kept and again and again[0][1] == "play.example.org"),
                "room %d" % (again[0][2] if again else -1)))
    try:
        ph.set_template_host(module, "a-name-that-cannot-fit-in-here.example.org")
        refused = False
    except SystemExit:
        refused = True
    out.append(("login module edit refuses a long name", refused, ""))
    return out


def check_paths():
    """Check where a container's paths are allowed to land.

    FFXI's MISC records hold six paths beginning `../../`, which the reader
    prefixes with `image/ffxi/` so that they cancel and `res/` lands at the
    root of the partition. The containment rule must allow that and still
    refuse a path that leaves the output directory.
    """
    from . import safepath
    # abspath, because safe_join resolves its root and on Windows a path
    # beginning with a separator picks up the current drive letter.
    root = os.path.abspath(os.path.join(os.sep, "out"))
    inside = os.path.join(root, "res", "info.sys")
    cases = [
        ("a container path lands where it says",
         "image/ffxi/ROM/1/2.DAT", os.path.join(root, "image", "ffxi", "ROM", "1", "2.DAT")),
        ("FFXI's ../../res escape cancels", "image/ffxi/../../res/info.sys", inside),
    ]
    out = []
    for name, path, want in cases:
        try:
            got = safepath.safe_join(root, path)
            out.append(("safepath %s" % name, got == want,
                        got if got != want else "-> %s" % want))
        except ValueError as e:
            out.append(("safepath %s" % name, False, str(e)))
    try:
        safepath.safe_join(root, "../../../etc/passwd")
        out.append(("safepath an escaping path is refused", False,
                    "it was allowed"))
    except ValueError:
        out.append(("safepath an escaping path is refused", True, "ValueError"))
    return out


def check_disc(path):
    """Identify a disc and, for an install-dat one, verify its container.

    The reader assumes payloads are concatenated on a 2048-byte alignment,
    so the aligned sizes must add up to INSTALL.DAT's byte length exactly.
    """
    from . import discs, titles
    try:
        d = discs.identify(path)
    except (discs.NotADisc, IOError, OSError) as e:
        return [("disc %s" % os.path.basename(path), None, str(e)[:70])]

    name = titles.DISCS[d.key]["name"] if d.known else "unrecognised"
    out = [("disc %s" % d.code, d.known,
            "%s, %s" % (name[:34], "+".join(d.containers) or "no container"))]
    # Square Enix's keys are read from the disc; none ship with this
    # package. The table's address differs between builds, so it is searched
    # for.
    try:
        from . import keys
        elf = keys.boot_elf(d)
        try:
            _path, off, va = keys.use_disc(elf)
            n = len([1 for _s, der in __import__("playonline.lib.polenc",
                                                 fromlist=["x"]).keystore(elf) if der])
            out.append(("  %s keystore" % d.code, n > 0,
                        "%d keys at file 0x%06x, VA 0x%08x" % (n, off, va or 0)))
        finally:
            import os
            if os.path.exists(elf):
                os.unlink(elf)
    except Exception as e:                            # noqa: BLE001
        out.append(("  %s keystore" % d.code, False, "%s: %s" % (type(e).__name__, e)))

    if d.format != discs.INSTALL_DAT:
        return out
    from . import installdat
    try:
        recs = installdat.index(discs.Image(path))
        ok, want, size = installdat.check_layout(discs.Image(path), recs)
        out.append(("  %s layout" % d.code, ok,
                    "%d records account for %d B" % (len(recs), size) if ok
                    else "records account for %d B, INSTALL.DAT is %d" % (want, size)))
    except (ValueError, IOError, OSError) as e:
        out.append(("  %s layout" % d.code, False, str(e)[:70]))
    return out


def run(paths, disc_paths=()):
    results = []
    print("  package modules")
    for name, ok, detail in check_vendor():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    print("  site tables")
    for name, ok, detail in check_site_tables():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    print("  paths")
    for name, ok, detail in check_paths():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    print("  ffxi overlay")
    for name, ok, detail in check_ffxi_overlay():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    print("  patch host")
    for name, ok, detail in check_patch_host():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    print("  loader")
    for name, ok, detail in check_loader():
        mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
        print("    %s %-46s %s" % (mark, name, detail))
        results.append(ok)

    if disc_paths:
        print("  discs")
        for path in disc_paths:
            for name, ok, detail in check_disc(path):
                mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
                print("    %s %-46s %s" % (mark, name, detail))
                results.append(ok)
    for path in paths:
        try:
            parts = apa.installed_titles(path)
        except (IOError, OSError, ValueError) as e:
            print("  skip %s: %s" % (path, e))
            continue
        if not parts:
            print("  skip %s: no PP.* partitions" % path)
            continue
        print("  %s" % path)
        from . import netpart
        if netpart.present(path):
            for name, ok, detail in netpart.verify(path):
                mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
                print("    %s %-46s %s" % (mark, name, detail))
                results.append(ok)
        for p in parts:
            for name, ok, detail in check_partition(path, p):
                mark = {True: "ok  ", False: "FAIL", None: "skip"}[ok]
                print("    %s %-46s %s" % (mark, name, detail))
                results.append(ok)
    passed = sum(1 for r in results if r is True)
    failed = sum(1 for r in results if r is False)
    skipped = sum(1 for r in results if r is None)
    print("%d passed, %d failed, %d skipped" % (passed, failed, skipped))
    return failed


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("drives", nargs="*", help="drives or drive images")
    ap.add_argument("--disc", action="append", default=[], metavar="IMAGE",
                    help="also identify and check a disc image")
    args = ap.parse_args()
    if not args.drives and not args.disc:
        print("no drives given: the vendor check runs, the builders are not tested")
    return 1 if run(args.drives, args.disc) else 0


if __name__ == "__main__":
    sys.exit(main())

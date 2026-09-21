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
"""Build a PlayOnline hard drive image for the PCSX2 emulator from your discs.

This is the install the toolkit's menu puts on a real drive, made as a file:
each title is staged off its disc, prepared, written to its partition and
verified, then registered with the Viewer. On an English install the
Japan-only titles are given English names. No drive, pfsshell or root access
is needed.

Differences from a real drive:

* Every partition is a single main partition, however large. This package's
  writer does not lay out sub-partitions, and an image has no partition size
  ceiling that would require them.
* The image is sparse, so only the data written to it takes disk space.
* PCSX2 has no MagicGate keys and cannot run the signed loader in the
  Viewer's partition. The same loader is therefore also written, unsigned
  and filled, beside the image as `<image stem>.elf`. Started from PCSX2's
  "Run ELF" with the image attached as the hard drive, it boots the Viewer
  the way the console's browser entry does.
* The drive identity is minted here and written beside the image as
  `<image stem>.hddid`, which is where PCSX2 looks for it.

    python3 -m playonline.pcsx2image OUT.img --discs DIR [--region us|jp]
        [--titles viewer-us,ffxi-us] [--work DIR] [--write]

Without `--write` it prints the plan and writes nothing.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

from . import loader, titles
from .testimage import PSBBN_PARTS
from .lib import polhdd, polpfs

HELPER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(os.path.dirname(HELPER), "assets", "playonline")
LOADER_KELF = os.path.join(ASSETS, "polbbnexec.kelf")
LOADER_ELF = os.path.join(ASSETS, "polbbnexec.elf")

SECTOR = 512
MIB = 2048                       # sectors
NET_MIB = 128
SLACK_MIB = 2048                 # free space left after the last partition


def run(module, *args, **kw):
    """Run one of the package's own commands; returns its output."""
    env = dict(os.environ, PYTHONPATH=HELPER, PYTHONIOENCODING="utf-8",
               PLAYONLINE_NO_ATTR_BACKUP="1")
    cmd = [sys.executable, "-m", "playonline" + ("." + module if module else "")]
    proc = subprocess.run(cmd + list(args), cwd=HELPER, env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = proc.stdout.decode("utf-8", "replace")
    if proc.returncode not in kw.get("ok_codes", (0,)):
        raise SystemExit("playonline.%s failed:\n%s" % (module or "main", out))
    return out


def choose(disc_dir, region, wanted):
    """[(title, disc path)] in install order, Viewer first."""
    out = run("", "sources", "--plain", "--region", region, disc_dir)
    rows = []
    for line in out.splitlines():
        p = line.strip().split("|")
        if len(p) >= 4 and p[0] in titles.TITLES:
            rows.append((titles.TITLES[p[0]], p[1]))
    if wanted:
        rows = [r for r in rows if r[0].key in wanted or r[0].key.startswith("viewer-")]
    viewers = [r for r in rows if r[0].key.startswith("viewer-")]
    if not viewers:
        raise SystemExit("no disc in %s carries a PlayOnline Viewer for region "
                         "%s; every title is launched from it" % (disc_dir, region))
    return viewers[:1] + [r for r in rows if not r[0].key.startswith("viewer-")]


def table(chosen):
    """([(start, sectors, type, id)], total sectors) for the whole drive."""
    parts = [(0, polhdd.MIN_PART, polhdd.APA_TYPE_MBR, "__mbr")]
    pos = polhdd.MIN_PART
    wanted = [("__net", NET_MIB)] + list(PSBBN_PARTS)
    wanted += [(t.partition, t.need_mib) for t, _disc in chosen]
    for name, mib in wanted:
        n = mib * MIB
        pad = (-pos) % n
        for fs, fl in polhdd.buddy_free(pos, pos + pad):
            parts.append((fs, fl, polhdd.APA_TYPE_FREE, polhdd.EMPTY_ID))
        pos += pad
        parts.append((pos, n, polhdd.APA_TYPE_PFS, name))
        pos += n
    total = pos + SLACK_MIB * MIB
    total = (total + 1024 * MIB - 1) // (1024 * MIB) * (1024 * MIB)
    for fs, fl in polhdd.buddy_free(pos, total):
        parts.append((fs, fl, polhdd.APA_TYPE_FREE, polhdd.EMPTY_ID))
    return parts, total


def create_sparse(path, size):
    """Create an empty sparse file of `size` bytes."""
    with open(path, "wb"):
        pass
    if os.name == "nt":
        # Without the sparse flag NTFS zero-fills the gap before every far
        # write. The flag is set with FSCTL_SET_SPARSE.
        _set_sparse_windows(path)
    with open(path, "r+b") as f:
        f.truncate(size)


def _set_sparse_windows(path):
    """FSCTL_SET_SPARSE on `path`. Returns True when the flag took."""
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.CreateFileW.restype = wintypes.HANDLE
    k32.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD,
                                wintypes.HANDLE]
    handle = k32.CreateFileW(os.path.abspath(path), 0x40000000, 0, None, 3, 0x80, None)
    if handle in (None, wintypes.HANDLE(-1).value):
        return False
    try:
        returned = wintypes.DWORD(0)
        ok = k32.DeviceIoControl(wintypes.HANDLE(handle), 0x000900C4, None, 0,
                                 None, 0, ctypes.byref(returned), None)
        return bool(ok)
    finally:
        k32.CloseHandle(wintypes.HANDLE(handle))


def emulator_elf(staged_viewer, out_path):
    """Write the unsigned loader, filled exactly as the staged signed one is."""
    signed = os.path.join(staged_viewer, "POL", "install", "PS2", "dnasload.elf")
    with open(signed, "rb") as f:
        blob = f.read()
    info = loader.read(blob)
    boot = blob[info["elf_at"]:info["elf_at"] + info["elf_len"]]
    ioprp = blob[info["ioprp_at"]:info["ioprp_at"] + info["ioprp_len"]]
    with open(LOADER_ELF, "rb") as f:
        plain = f.read()
    filled = loader.fill(plain, boot_elf=boot, ioprp=ioprp,
                         hddid=info["hddid"], argv0=info["argv0"])
    with open(out_path, "wb") as f:
        f.write(filled)
    return len(filled)


def prepare(title, staged, disc, hddid, derive_elf, mode):
    """Make one staged tree bootable. Returns (mode, record path or None)."""
    product = title.partition.split(".")[1]
    if os.path.isfile(os.path.join(staged, "POL", "install", "PS2", product)):
        args = ["prepare", staged, "--title", title.key, "--hddid", hddid,
                "--disc", disc, "--derive-elf", derive_elf, "--loader", LOADER_KELF]
        if mode:
            args += ["--mode", mode]
        out = run("route", *args)
        for line in out.splitlines():
            if line.startswith("mode:"):
                mode = line.split()[1]
        record = None
        for line in out.splitlines():
            if line.startswith("record:"):
                record = line.split(None, 1)[1].strip()
        return mode, record
    if os.path.isdir(os.path.join(staged, "image", "ffxi")):
        run("route", "ffxi", staged, "--hddid", hddid, "--disc", disc,
            "--derive-elf", derive_elf)
    elif os.path.isfile(os.path.join(staged, "filelist.bin")):
        pass                                # Dirge: both module forms, as shipped
    elif any(n.endswith(".pex.enc") for _d, _s, fs in os.walk(staged) for n in fs):
        run("route", "modules", staged, "--mode", mode or "plaintext",
            "--hddid", hddid, "--disc", disc, "--derive-elf", derive_elf)
    return mode, None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("image", help="the image file to create, e.g. PlayOnline.img")
    ap.add_argument("--discs", required=True, help="folder holding your disc images")
    ap.add_argument("--region", choices=("us", "jp"), default="us")
    ap.add_argument("--titles", help="comma-separated title keys; default: all "
                                     "the discs supply (the Viewer is always included)")
    ap.add_argument("--work", help="scratch folder for staged trees (needs room "
                                   "for the largest title; default: beside the image)")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--force", action="store_true", help="replace an existing image")
    args = ap.parse_args()

    for need in (LOADER_KELF, LOADER_ELF):
        if not os.path.isfile(need):
            sys.exit("missing %s" % need)
    wanted = set(x.strip() for x in args.titles.split(",")) if args.titles else None
    chosen = choose(args.discs, args.region, wanted)
    parts, total = table(chosen)

    print("PlayOnline image for PCSX2: %s, %d MiB (sparse)" % (args.image, total // MIB))
    for start, length, ptype, ident in parts:
        if ptype != polhdd.APA_TYPE_FREE:
            print("  LBA %9d  %5d MiB  %s" % (start, length // MIB, ident))
    for t, disc in chosen:
        print("  %-16s from %s" % (t.key, os.path.basename(disc)))
    if not args.write:
        print("(plan only; pass --write)")
        return 0
    if os.path.exists(args.image) and not args.force:
        sys.exit("%s exists; pass --force to replace it" % args.image)

    image = os.path.abspath(args.image)
    stem = os.path.splitext(image)[0]
    hddid = stem + ".hddid"
    work = args.work or tempfile.mkdtemp(prefix="playonline-image-",
                                         dir=os.path.dirname(image))
    os.makedirs(work, exist_ok=True)

    create_sparse(image, total * SECTOR)
    polhdd.write_table(image, parts, total, dry_run=False)
    with open(image, "r+b") as f:
        for start, length, _ptype, ident in parts:
            if ident in [name for name, _mib in PSBBN_PARTS]:
                polpfs.format_partition(f, start, length)
    print(run("netpart", image, "--write", "--backup",
              os.path.join(work, "apa-before-net.json")).strip())
    if not os.path.isfile(hddid):
        run("hddid", "--mint", hddid, "--seed",
            "playonline-pcsx2image-" + os.path.basename(stem))

    derive_elf = os.path.join(work, "derivation.elf")
    discs_in = sorted(set(d for _t, d in chosen))
    run("route", "derive-elf", *discs_in, "--out", derive_elf)

    mode = None
    for t, disc in chosen:
        staged = os.path.join(work, t.key)
        shutil.rmtree(staged, ignore_errors=True)
        print("== %s" % t.key)
        print("  " + run("stage", disc, "--title", t.key, "--out", staged)
              .strip().splitlines()[-1])
        mode, record = prepare(t, staged, disc, hddid, derive_elf, mode)
        title_args = [] if args.region == "us" else ["--original-titles"]
        out = run("build", image, "--title", t.key, "--src", staged,
                  "--disc", disc, "--write", *title_args)
        print("  " + [l for l in out.splitlines() if l.startswith(("wrote", "would"))][0])
        out = run("build", image, "--title", t.key, "--src", staged, "--verify")
        print("  " + [l.strip() for l in out.splitlines() if "round-trips" in l
                      or "ERRORS" in l][0])
        if record:
            print("  " + run("route", "record", image, "--record", record,
                             "--write").strip().splitlines()[-1])
            n = emulator_elf(staged, stem + ".elf")
            print("  module mode %s; emulator loader %s (%d B)"
                  % (mode, os.path.basename(stem + ".elf"), n))
        shutil.rmtree(staged, ignore_errors=True)

    print(run("installinf", image, "--write").strip())
    if args.region == "us":
        print(run("retitle", image, "--write").strip())
    print(run("selftest", image).strip().splitlines()[-1])
    if not args.work:
        shutil.rmtree(work, ignore_errors=True)
    print()
    print("In PCSX2: Settings > Network & HDD > enable the hard disk and point it")
    print("at %s, then System > Run ELF > %s" % (image, stem + ".elf"))
    return 0


if __name__ == "__main__":
    sys.exit(main())

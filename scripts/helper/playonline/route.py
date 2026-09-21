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
r"""Make a staged tree bootable: the container, and the record that keys it.

A tree staged from a disc holds the boot container and every `.pex.enc`
module in the universal form, the one discs and the patch server carry. A
universal container includes its own bulk key (the RSA block at
`file[512:640]`, keystore slot 15), so it can be read without any drive
material. A drive boots either the installed form, re-encrypted under a key
bound to one HDD ID, or decompressed plaintext modules. This module converts
the staged tree before the partition is written, so nothing on the drive is
edited in place.

`prepare` fills the package's own loader (loader.py) with the Viewer's boot
ELF and IOP reboot image and writes it as `dnasload.elf`. Modules become
plaintext where the Viewer build has Square Enix's plaintext switch and are
transcrypted otherwise. With `--se-dnasload` Square Enix's loader is kept and
patched instead, which needs the user's console keys.

Transcrypting has two outputs, and they must agree:

  the installed container   replaces the staged one
  the `__net` record        written at `__net` + 0x201800, outside any
                            filesystem, holding the value the container's
                            key was derived with

Every `.pex.enc` is converted along with the boot container, because the
Viewer loads them all through the same path. The HDD ID used here must be the
block the console is later served (see hddid.py): a mismatch is not detected
at conversion time, and the modules then decrypt to noise.

The key derivation reads Square Enix's constants out of a disc boot
executable, passed as `--derive-elf`. `polkey` has a `BUILDS` table for
`SLPS_202.00` and `SLUS_217.04` and detects which one it was given. The
constants are identical in both builds; only their addresses differ.

    python3 -m playonline.route derive-elf DISC.iso [DISC.iso ...]
    python3 -m playonline.route prepare STAGED --title viewer-us \
        --hddid DRIVE.hddid --derive-elf BOOT.elf
    python3 -m playonline.route modules STAGED --derive-elf BOOT.elf
    python3 -m playonline.route ffxi STAGED --hddid DRIVE.hddid \
        --disc FFXI.iso --derive-elf BOOT.elf
    python3 -m playonline.route record DRIVE --record RECORD.bin --write
"""
import argparse
import os
import shutil
import sys

from . import discs, keys, titles

RECORD_OFFSET = 0x201800        # inside __net, outside its filesystem


def _set_derive_elf(path):
    """Point the key derivation at a boot executable.

    Only the path is set: polkey resolves the constants' addresses from the
    image itself.
    """
    from .lib import polkey
    polkey.ELF = path
    return path


def container_path(src_dir, title):
    """Where the boot container sits in a staged tree."""
    return os.path.join(src_dir, "POL", "install", "PS2", title.product)


def use_keys(disc=None, derive_elf=None):
    """Point the crypto under lib/ at a disc's keystore and a build's constants.

    The keys for reading a container come from the disc supplied; the
    derivation constants come from an executable polkey has a table for.
    Every entry point that reads or transcrypts a container calls this first,
    including those for titles that have modules but no boot container.
    """
    if not derive_elf:
        from .lib import polkey
        raise SystemExit(
            "--derive-elf is required: the key derivation reads Square "
            "Enix's constants out of a disc boot executable. polkey "
            "understands %s. See the notes at the top of route.py."
            % ", ".join(sorted(polkey.BUILDS)))
    # The disc's boot executable carries Square Enix's public keys on the
    # PlayOnline discs and on Vana'diel Collection 2008. The Dirge of
    # Cerberus disc's does not, so a title staged from it takes the keys
    # from the derivation executable.
    used = None
    if disc is not None:
        try:
            keys.use_disc(keys.boot_elf(disc))
            used = disc.path
        except keys.NoKeystore:
            used = None
    if used is None:
        keys.use_disc(derive_elf)
    _set_derive_elf(derive_elf)
    # Some of the tools under lib/ run each other as subprocesses, which
    # start with the default path. They read this environment variable.
    os.environ["PLAYONLINE_DISC_ELF"] = os.path.abspath(derive_elf)
    return derive_elf


def derivation_disc(paths):
    """Return the first disc among `paths` whose boot executable polkey has a table for.

    This lets the installer find the `--derive-elf` executable among the
    user's discs instead of asking for it. Other discs are skipped.
    Directories are not walked.
    """
    from .lib import polkey
    for path in paths:
        if not os.path.isfile(path):
            continue
        try:
            disc = discs.identify(path)
        except (discs.NotADisc, IOError, OSError):
            continue
        if disc.boot in polkey.BUILDS:
            return disc
    return None


def _run(mod, argv, hint=""):
    """Run a lib/ tool's `main` as though from the command line.

    The tools report failure in two ways: some paths raise SystemExit and
    others return a code. Both are checked. `ci_viewerpatch`, for example,
    returns 2 for a build it has no site table for, having patched nothing.
    """
    saved = sys.argv
    try:
        sys.argv = argv
        code = mod.main()
    except SystemExit as e:
        code = e.code
    finally:
        sys.argv = saved
    if code:
        raise SystemExit("%s failed (%s)%s" % (argv[0], code,
                                               ". " + hint if hint else ""))


def prepare(src_dir, title, hddid, disc=None, derive_elf=None, four=None,
            write=True, pcsx2=False):
    """Convert the staged container to installed form and mint its record.

    Returns (installed path, record path). With `write=False` nothing in the
    staged tree is replaced, so the conversion can be checked first.

    `pcsx2` must match what `convert_modules` is given. The flag selects the
    key material: an emulator answers the drive identify with zeros, so a
    container keyed to a minted HDD ID cannot be read there, and one keyed
    for the emulator cannot be read on a console.
    """
    container = container_path(src_dir, title)
    if not os.path.exists(container):
        raise SystemExit(
            "%s: no boot container for %s.\nOnly the Viewer partition has "
            "one. A title without one still carries modules keyed to the "
            "drive: convert those with `route modules`."
            % (src_dir, title.key))
    use_keys(disc, derive_elf)

    out = container + ".installed"
    # The record is written beside the staged tree. Everything inside the
    # tree goes into the partition, and the record belongs in __net.
    record = os.path.join(os.path.dirname(os.path.abspath(src_dir.rstrip("/\\"))),
                          "%s-net-record.bin" % title.key)
    argv = ["ci_transcrypt", container, "--hddid", hddid, "-o", out,
            "--record", record]
    if four:
        argv += ["--four", four]
    if pcsx2:
        argv += ["--pcsx2"]
    from .lib import ci_transcrypt
    _run(ci_transcrypt, argv)

    if not os.path.exists(out):
        raise SystemExit("ci_transcrypt wrote no container")

    # The Viewer has its own copies of the binding and record checks and of
    # the DNAS gates inside that container, so they are patched as well. All
    # four DNAS polls have to be patched.
    patched = out + ".patched"
    from .lib import ci_viewerpatch
    _run(ci_viewerpatch,
         ["ci_viewerpatch", "--container", out, "--hddid", hddid,
          "--record", record, "-o", patched],
         "If it could not identify the build, that build has no site table "
         "yet, and the gates inside the container are untouched.")
    if not os.path.exists(patched):
        raise SystemExit("ci_viewerpatch wrote no container")
    os.replace(patched, out)

    if write:
        shutil.move(out, container)
        out = container
    return out, record


def modules(src_dir):
    """Return every `.pex.enc` in a staged tree, in a stable order."""
    out = []
    for dirpath, dirs, names in os.walk(src_dir):
        dirs.sort()
        for name in sorted(names):
            if name.endswith(".pex.enc"):
                out.append(os.path.join(dirpath, name))
    return out


def convert_modules(src_dir, hddid, four=None, pcsx2=False, write=True,
                    drop_plaintext=True):
    """Convert every `.pex.enc` in the staged tree to installed form.

    Every module ships in the universal form and the Viewer loads them
    through the same path as the boot container, so each one is re-encrypted
    under the drive's key with `ci_transcrypt`. This applies to titles
    without a boot container too: the JP PlayOnline disc has six modules
    under `POL/Data/PS2/`, plus `TetraMaster/TMaster.pex.enc` and
    `Warashi/JanHouRou.pex.enc`. The `modules` command covers those.

    `drop_plaintext` removes the `.pex` beside each converted module, as
    Square Enix's installer does: the disc carries both forms and an installed
    drive holds only `chat.pex.enc`. The disc's `.pex` is a PEX container and
    is not the decompressed module (head `MWo3`) that plaintext mode opens.

    Returns [(path, universal size, installed size)].
    """
    from .lib import ci_transcrypt
    done = []
    for path in modules(src_dir):
        out = path + ".installed"
        argv = ["ci_transcrypt", path, "--hddid", hddid, "-o", out]
        if four:
            argv += ["--four", four]
        if pcsx2:
            argv += ["--pcsx2"]
        before = os.path.getsize(path)
        _run(ci_transcrypt, argv,
             "The module was %s." % os.path.basename(path))
        if not os.path.exists(out):
            raise SystemExit("ci_transcrypt wrote nothing for %s" % path)
        after = os.path.getsize(out)
        if write:
            os.replace(out, path)
            if drop_plaintext:
                plain = path[:-len(".enc")]
                if os.path.exists(plain):
                    os.remove(plain)
        else:
            os.remove(out)
        done.append((path, before, after))
    return done


DNASLOAD = "dnasload.elf"
GATES = ("console-binding", "record", "digest-check")


def patch_loader(src_dir, keys_file=None, write=True):
    """Open the disc's dnasload and patch its gates (the `--se-dnasload` route).

    Every disc ships `dnasload` as a KELF, so it is first opened and repacked
    pre-decrypted. That is MagicGate and needs `PS2KEYS.dat` from the user's
    own console.

    Three gates are then patched: the console-binding check, the `__net`
    record verdict and the digest check. The digest check is patched because
    `prepare` edits the boot container; the digest covers the payload, so a
    container that was only re-encrypted would still match.

    The patch is 17 words in a gap at 0x001004b8 plus one redirected `jal`.
    The patched loader differs from the original in 45 bytes and keeps its
    length.
    """
    loader = os.path.join(src_dir, "POL", "install", "PS2", DNASLOAD)
    if not os.path.exists(loader):
        raise SystemExit("%s: no %s in the staged tree" % (src_dir, DNASLOAD))

    predec = loader + ".predec"
    argv = ["polkelf", loader, "--patch", predec]
    if keys_file:
        argv += ["--keys", keys_file]
    from .lib import polkelf, ci_usdnaspatch
    _run(polkelf, argv,
         "It needs PS2KEYS.dat from your own console; pass --keys or set "
         "$PS2KEYS.")
    if not os.path.exists(predec):
        raise SystemExit("polkelf wrote no pre-decrypted loader")

    patched = loader + ".patched"
    _run(ci_usdnaspatch,
         ["ci_usdnaspatch", "--base", predec, "--out", patched]
         + sum([["--named", g] for g in GATES], []))
    if not os.path.exists(patched):
        raise SystemExit("ci_usdnaspatch wrote no loader")

    os.unlink(predec)
    if write:
        os.replace(patched, loader)
        return loader
    return patched


def write_record(image, record, write=False):
    """Write the record into `__net` at +0x201800, outside any filesystem."""
    from . import apa
    data = record if isinstance(record, (bytes, bytearray)) else open(record, "rb").read()
    try:
        lba, sectors = apa.find_partition(image, "__net")
    except KeyError:
        raise SystemExit("%s: no __net partition; create it first "
                         "(python3 -m playonline.netpart)" % image)
    if RECORD_OFFSET + len(data) > sectors * 512:
        raise SystemExit("__net is too small for the record")
    off = lba * 512 + RECORD_OFFSET
    if not write:
        return "would write %d B at __net + 0x%x (LBA %d)" % (len(data), RECORD_OFFSET, lba)
    with open(image, "r+b") as f:
        f.seek(off)
        f.write(data)
    return "wrote %d B at __net + 0x%x (LBA %d)" % (len(data), RECORD_OFFSET, lba)


# ---- the loader route --------------------------------------------------------
#
# Everything above converts the tree for Square Enix's boot chain, in which
# their `dnasload` opens the installed container. That chain has no room for
# the HDD ID shim a generic drive needs, and opening `dnasload` takes the
# user's console keys. The default route therefore boots the package's own
# loader (loader.py, loader-src/): the Viewer's boot ELF and IOP reboot image
# go into the signed loader, which reboots the IOP, installs the shim and
# enters the ELF. It is written as `dnasload.elf`, so the browser entry does
# not change.
#
# Because the boot ELF is patched here, the partition can hold plaintext
# modules, which is the mode this project targets: modules are not keyed per
# drive, so one translation or update serves every drive. The switch is
# Square Enix's own (polplaintext.py) and is present in every build from the
# 1.13 era on. The two 2003-era discs lack it; their modules are transcrypted
# and still boot through this loader.

PLAINTEXT = "plaintext"
TRANSCRYPT = "transcrypt"
MODES = (PLAINTEXT, TRANSCRYPT)

from .loader import SHIPPED as LOADER_KELF


def _read(path):
    with open(path, "rb") as f:
        return f.read()


def loader_path(path=None):
    """Return the path of the signed loader this package ships, or exit."""
    p = path or LOADER_KELF
    if not os.path.exists(p):
        raise SystemExit("%s: the loader is missing. It is built from "
                         "playonline/loader-src and ships with the toolkit." % p)
    return p


def plaintext_build(boot):
    """Return the plaintext-switch table entry for this boot ELF, or None.

    The switch is in every build from the 1.13 era on: Vana'diel Collection
    2008's Viewer (1.18.03b), the Dirge of Cerberus disc's (1.14.03) and the
    1.13.01f and 1.18.15f drive builds share the reader, the gate and the
    globals. The two 2003-era discs (US 1.11.00m, JP 1.05.00d) have a
    different loader stub without the switch's sites, so a tree from those
    falls back to transcrypt.
    """
    from .lib import polplaintext
    return polplaintext.identify(boot, polplaintext.seg_map(boot))


def set_plaintext(boot):
    """Set the plaintext flag and NOP the boot-source gate. Returns (label, bytes).

    Each write is guarded: a word is written only where the original is, a
    site already holding the patch is left alone, and any other value refuses
    the whole file.
    """
    import struct as _struct
    from .lib import polplaintext as pp
    segs = pp.seg_map(boot)
    build = pp.identify(boot, segs)
    if build is None:
        raise SystemExit("this boot ELF has no plaintext switch this code knows")
    out = bytearray(boot)
    sites = ((pp.FLAG_OFF, pp.FLAG_ORIG, pp.FLAG_NEW, "plaintext flag word"),
             (pp.off_of(segs, build["gate_va"]), pp.GATE_ORIG, pp.GATE_NEW,
              "boot-source gate"))
    for off, orig, new, what in sites:
        cur = _struct.unpack_from("<I", out, off)[0]
        if cur == new:
            continue
        if cur != orig:
            raise SystemExit("refusing to set plaintext mode: the %s holds "
                             "0x%08x, expected 0x%08x" % (what, cur, orig))
        _struct.pack_into("<I", out, off, new)
    return build["name"], bytes(out)


def modules_to_plaintext(src_dir, write=True):
    """Beside every universal `.pex.enc`, write the module plaintext mode opens.

    That module is the decompressed one, head `MWo3`. The `.pex` the disc
    ships is a PEX container and is not usable: the decompressed `chat.pex`
    is 392,192 bytes where the disc's `chat.pex` is 148,080.

    The `.pex.enc` is kept. Plaintext mode does not open it, but the Viewer's
    `file.txt` names it, and a drive that updates in this mode carries both
    forms.

    Returns [(path written, container size, module size)].
    """
    from .lib import ci_universal, pexcodec
    done = []
    for path in modules(src_dir):
        blob = _read(path)
        if not ci_universal.is_universal(blob):
            raise SystemExit("%s is not in the universal form. Stage the tree "
                             "from the disc again; a tree converted once "
                             "cannot be converted again." % path)
        secs = ci_universal.sections(blob)
        if len(secs) != 1:
            raise SystemExit("%s: %d sections, a module container has one"
                             % (path, len(secs)))
        off, size = secs[0]
        mod, _tag = ci_universal.module(blob[off:off + size])
        if not pexcodec.is_pex(mod):
            raise SystemExit("%s: the module is not a PEX container (head %s)"
                             % (path, mod[:4].hex()))
        plain = pexcodec.decompress(mod)
        want = pexcodec.plaintext_len(mod)
        if len(plain) != want:
            raise SystemExit("%s: decompressed to %d bytes, the container says %d"
                             % (path, len(plain), want))
        out = path[:-len(".enc")]
        if write:
            with open(out, "wb") as f:
                f.write(plain)
        done.append((out, len(blob), len(plain)))
    return done


def mint_record(hddid_path, four=None, identity=None):
    """Return the 512-byte `__net` record for this HDD ID.

    The plaintext route needs no record to boot, but the in-Viewer updater
    keys what it downloads through the record, so one is always written.
    `four` is arbitrary; it only has to agree between the record and anything
    transcrypted against it. The identity is derived from the HDD ID; nothing
    is known to read it.
    """
    from .lib import ci_transcrypt, polrecord
    hddid = _read(hddid_path)
    four = four or ci_transcrypt.DEFAULT_FOUR
    if identity is None:
        identity = ci_transcrypt.default_identity(hddid)
    _ata24, key = ci_transcrypt.ata_material(hddid, False)
    return polrecord.encode(polrecord.mint(four, identity), key)


FFXI_PROG = "image/ffxi/prog/ps2"
# The name Square Enix's installer gives each root container in the
# partition's program directory. CONFIGU.SYS lists the containers; JP and US
# drives both carry these names.
FFXI_INSTALLED = {"FFXI_POL.ENC": "ffxi_pol.pex.enc", "DANCER.ENC": "dancer.enc"}


def ffxi_enc_names(disc):
    """Return the boot-side containers the disc's CONFIGU.SYS says to install.

    On Vana'diel Collection 2008 the line is
    `ENC=\\FFXI_POL.ENC;1,\\DANCER.ENC;1`. The manifest in DATA/FILE.TXT
    tracks neither file, and the title does not start without both.
    """
    image = discs.Image(disc.path)
    cfg = discs.read_path(image, "CONFIGU.SYS")
    if cfg is None:
        raise SystemExit("%s: no CONFIGU.SYS in the disc root" % disc.path)
    for line in cfg.decode("latin-1").splitlines():
        if line.startswith("ENC="):
            names = [n.strip().lstrip("\\").split(";")[0]
                     for n in line[4:].split(",") if n.strip()]
            return names
    raise SystemExit("%s: CONFIGU.SYS names no ENC= containers" % disc.path)


def ffxi_containers(src_dir, disc, hddid, derive_elf=None, four=None,
                    pcsx2=False, write=True):
    """Key FFXI's boot-side containers to this install and put them in the tree.

    FFXI's loader does not read the Viewer's plaintext switch: it opens
    `ffxi_pol.pex.enc` and then `../prog/ps2/dancer.enc` keyed to the drive,
    whatever mode the Viewer runs in. Both are therefore transcrypted on
    every route, against the HDD ID and record `four` the drive is given. The
    decompressed boot module is also written beside its `.pex.enc`.

    Returns [(installed path, universal size, installed size)].
    """
    from .lib import ci_transcrypt, ci_universal, pexcodec
    use_keys(disc, derive_elf)
    keys = ci_universal._keys()
    hddid_blob = _read(hddid)
    four = four or ci_transcrypt.DEFAULT_FOUR
    image = discs.Image(disc.path)
    done = []
    for name in ffxi_enc_names(disc):
        installed_name = FFXI_INSTALLED.get(name)
        if installed_name is None:
            raise SystemExit("CONFIGU.SYS names %s and this code does not know "
                             "what Square Enix's installer calls it" % name)
        universal = discs.read_path(image, name)
        if universal is None:
            raise SystemExit("%s: CONFIGU.SYS names %s and the disc root has none"
                             % (disc.path, name))
        installed = ci_transcrypt.transcrypt(universal, hddid_blob, four, keys, pcsx2)
        for label, good, detail in ci_transcrypt.check(installed, hddid_blob, four,
                                                       keys, pcsx2):
            if not good:
                raise SystemExit("%s: %s failed its self-check: %s"
                                 % (name, label, detail))
        dest = os.path.join(src_dir, *FFXI_PROG.split("/"), installed_name)
        if write:
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(installed)
            if installed_name.endswith(".pex.enc"):
                off, size = ci_universal.sections(universal, keys)[0]
                mod, _tag = ci_universal.module(universal[off:off + size], keys)
                with open(dest[:-len(".enc")], "wb") as f:
                    f.write(pexcodec.decompress(mod))
        done.append((dest, len(universal), len(installed)))
    return done


def record_path_for(src_dir, title):
    """Return the record's path, beside the staged tree (it belongs in __net)."""
    return os.path.join(os.path.dirname(os.path.abspath(src_dir.rstrip("/\\"))),
                        "%s-net-record.bin" % title.key)


def prepare_loader(src_dir, title, hddid, disc=None, derive_elf=None, mode=None,
                   kelf=None, write=True):
    """Make a staged Viewer tree boot through the package's own loader.

    Chooses plaintext when the build has the switch and transcrypt when it
    does not, unless `mode` forces one. Returns a dict for `main` to print.
    """
    from . import loader
    from .lib import ci_universal
    container = container_path(src_dir, title)
    if not os.path.exists(container):
        raise SystemExit("%s: no boot container for %s; only the Viewer has one"
                         % (src_dir, title.key))
    use_keys(disc, derive_elf)
    blob = _read(container)
    if not ci_universal.is_universal(blob):
        raise SystemExit("%s is already in the installed form; stage the tree "
                         "from the disc again" % container)
    ioprp, boot = loader.carve(blob)
    build = plaintext_build(boot)
    if mode is None:
        mode = PLAINTEXT if build else TRANSCRYPT
    if mode not in MODES:
        raise SystemExit("unknown mode %r; one of %s" % (mode, ", ".join(MODES)))
    if mode == PLAINTEXT and build is None:
        raise SystemExit("this Viewer build has no plaintext switch. Use "
                         "--mode transcrypt, or install the Viewer from "
                         "Vana'diel Collection 2008 or the Dirge of Cerberus disc.")
    result = {"mode": mode, "build": None, "modules": [], "record": None}
    if mode == PLAINTEXT:
        result["build"], boot = set_plaintext(boot)
        result["modules"] = modules_to_plaintext(src_dir, write=write)
        record = record_path_for(src_dir, title)
        if write:
            with open(record, "wb") as f:
                f.write(mint_record(hddid))
    else:
        _out, record = prepare(src_dir, title, hddid, disc, derive_elf, write=write)
        result["modules"] = convert_modules(src_dir, hddid, write=write)
    result["record"] = record
    # Name this install's patch host in the Viewer's settings and login
    # module, so that the console cannot ask Square Enix's patch servers for
    # an update. $POL_PATCH_HOST chooses the host, and `none` turns it off.
    from . import patchhost
    host = patchhost.host_from_env()
    result["patch_host"] = (patchhost.apply(src_dir, host, write=write)
                            if host else ["unchanged (POL_PATCH_HOST=none)"])
    label, boot, lines = loader.gate_patch(boot)
    result["gates"] = [label] + [l.strip() for l in lines]
    filled = loader.fill(_read(loader_path(kelf)), boot_elf=boot, ioprp=ioprp,
                         hddid=_read(hddid),
                         argv0=loader.argv0_for(title, title.product))
    dst = os.path.join(src_dir, "POL", "install", "PS2", DNASLOAD)
    if write:
        with open(dst, "wb") as f:
            f.write(filled)
    result["loader"] = dst
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("prepare", help="make a staged Viewer tree bootable")
    p.add_argument("src", help="a staging directory from playonline.stage")
    p.add_argument("--title", required=True)
    p.add_argument("--hddid", required=True,
                   help="the HDD ID this install is keyed to "
                        "(python3 -m playonline.hddid --mint)")
    p.add_argument("--disc", help="the disc the tree came from, for its keys")
    p.add_argument("--derive-elf", required=True,
                   help="a disc boot executable polkey has a table for; see "
                        "the notes at the top of route.py")
    p.add_argument("--four", help="the 4 bytes tying container and record")
    p.add_argument("--keep", action="store_true",
                   help="leave the staged container alone and write beside it")
    p.add_argument("--mode", choices=MODES,
                   help="plaintext modules or transcrypted ones. Unset, the "
                        "build decides: plaintext where it has the switch")
    p.add_argument("--loader", metavar="KELF",
                   help="the signed loader to fill; the package's own by default")
    p.add_argument("--se-dnasload", action="store_true",
                   help="the alternative route: keep Square Enix's dnasload and patch "
                        "it, which needs PS2KEYS.dat and ships no HDD ID shim")
    p.add_argument("--keys", metavar="PS2KEYS.dat",
                   help="MagicGate keys from your own console, needed only "
                        "with --se-dnasload; $PS2KEYS is used if unset")
    p.add_argument("--no-loader", action="store_true",
                   help="with --se-dnasload, skip the dnasload gates")
    p.add_argument("--no-modules", action="store_true",
                   help="with --se-dnasload, convert the boot container only")
    p.add_argument("--pcsx2", action="store_true",
                   help="the target is an emulator, whose IDENTIFY is zeroed")
    p.add_argument("--keep-plaintext", action="store_true",
                   help="with --se-dnasload, leave the disc's .pex beside "
                        "each module")

    p = sub.add_parser("modules", help="convert a staged tree that has no "
                                       "boot container")
    p.add_argument("src", help="a staging directory from playonline.stage")
    p.add_argument("--mode", choices=MODES, default=PLAINTEXT,
                   help="must match the Viewer partition on the same drive: "
                        "a plaintext Viewer opens plaintext title modules and "
                        "a transcrypt one opens transcrypted ones")
    p.add_argument("--hddid",
                   help="the HDD ID this install is keyed to "
                        "(python3 -m playonline.hddid --mint); transcrypt only")
    p.add_argument("--disc", help="the disc the tree came from, for its keys")
    p.add_argument("--derive-elf", required=True,
                   help="a disc boot executable polkey has a table for; see "
                        "the notes at the top of route.py")
    p.add_argument("--four", help="the 4 bytes tying container and record")
    p.add_argument("--keep", action="store_true",
                   help="leave the staged modules alone and write beside them")
    p.add_argument("--pcsx2", action="store_true",
                   help="the target is an emulator, whose IDENTIFY is zeroed")
    p.add_argument("--keep-plaintext", action="store_true",
                   help="transcrypt only: leave the disc's .pex beside each "
                        "module")

    p = sub.add_parser("ffxi", help="key FFXI's boot-side containers into a "
                                    "staged FFXI tree")
    p.add_argument("src", help="a staging directory from playonline.stage")
    p.add_argument("--hddid", required=True)
    p.add_argument("--disc", required=True, help="the FFXI disc")
    p.add_argument("--derive-elf", required=True)
    p.add_argument("--four", help="the 4 bytes of the drive's __net record")
    p.add_argument("--pcsx2", action="store_true")
    p.add_argument("--keep", action="store_true", help="report only")

    p = sub.add_parser("derive-elf", help="pick the disc the constants can be "
                                          "read out of")
    p.add_argument("discs", nargs="+", metavar="DISC",
                   help="disc images to look through")
    p.add_argument("--out", metavar="FILE",
                   help="put the boot executable here rather than in a "
                        "temporary file")

    p = sub.add_parser("record", help="write a minted record into __net")
    p.add_argument("image")
    p.add_argument("--record", required=True)
    p.add_argument("--write", action="store_true")

    args = ap.parse_args()
    if args.cmd == "prepare" and not args.se_dnasload:
        if args.title not in titles.TITLES:
            sys.exit("unknown title %r" % args.title)
        disc = discs.identify(args.disc) if args.disc else None
        r = prepare_loader(args.src, titles.TITLES[args.title], args.hddid,
                           disc, args.derive_elf, mode=args.mode,
                           kelf=args.loader, write=not args.keep)
        print("mode:      %s" % r["mode"])
        if r["build"]:
            print("build:     %s" % r["build"])
        print("modules:   %d converted to %s" % (len(r["modules"]), r["mode"]))
        for path, before, after in r["modules"]:
            print("  %-24s %9d -> %9d" % (os.path.basename(path), before, after))
        for line in r["patch_host"]:
            print("patch:     %s" % line)
        print("gates:     %s" % r["gates"][0])
        for line in r["gates"][1:]:
            print("  %s" % line)
        print("loader:    %s" % r["loader"])
        print("record:    %s" % r["record"])
        print("The record must reach __net on the target drive:")
        print("  python3 -m playonline.route record DRIVE --record %s --write" % r["record"])
    elif args.cmd == "prepare":
        if args.title not in titles.TITLES:
            sys.exit("unknown title %r" % args.title)
        disc = discs.identify(args.disc) if args.disc else None
        out, record = prepare(args.src, titles.TITLES[args.title], args.hddid,
                              disc, args.derive_elf, args.four,
                              write=not args.keep, pcsx2=args.pcsx2)
        print("container: %s" % out)
        print("record:    %s" % record)
        if args.no_modules:
            print("modules:   skipped - the Viewer will stop at the first one")
        else:
            done = convert_modules(args.src, args.hddid, args.four,
                                   args.pcsx2, write=not args.keep,
                                   drop_plaintext=not args.keep_plaintext)
            print("modules:   %d converted" % len(done))
            for path, before, after in done:
                print("  %-24s %9d -> %9d"
                      % (os.path.basename(path), before, after))
        if args.no_loader:
            print("loader:    skipped - the Viewer will not start without it")
        else:
            print("loader:    %s" % patch_loader(args.src, args.keys))
        print("The record must reach __net on the target drive:")
        print("  python3 -m playonline.route record DRIVE --record %s --write" % record)
    elif args.cmd == "modules":
        disc = discs.identify(args.disc) if args.disc else None
        use_keys(disc, args.derive_elf)
        if args.mode == PLAINTEXT:
            done = modules_to_plaintext(args.src, write=not args.keep)
        else:
            if not args.hddid:
                sys.exit("--mode transcrypt needs --hddid")
            done = convert_modules(args.src, args.hddid, args.four, args.pcsx2,
                                   write=not args.keep,
                                   drop_plaintext=not args.keep_plaintext)
        print("modules:   %d converted to %s" % (len(done), args.mode))
        for path, before, after in done:
            print("  %-24s %9d -> %9d"
                  % (os.path.basename(path), before, after))
        if not done:
            print("  nothing to convert: this tree has no .pex.enc")
    elif args.cmd == "ffxi":
        disc = discs.identify(args.disc)
        four = bytes.fromhex(args.four) if args.four else None
        done = ffxi_containers(args.src, disc, args.hddid, args.derive_elf, four,
                               args.pcsx2, write=not args.keep)
        print("ffxi:      %d container(s) keyed" % len(done))
        for path, before, after in done:
            print("  %-24s %9d -> %9d" % (os.path.basename(path), before, after))
        # The disc pairs a 2004 boot module with 2007 data. Without this step
        # the title ends in the Viewer's terminated dialog (see ffxioverlay.py).
        from . import ffxioverlay
        for line in ffxioverlay.describe(
                ffxioverlay.reconcile(args.src, write=not args.keep)):
            print(line)
    elif args.cmd == "derive-elf":
        disc = derivation_disc(args.discs)
        if disc is None:
            from .lib import polkey
            sys.exit("none of those discs carries a boot executable the key "
                     "derivation has a table for (%s)"
                     % ", ".join(sorted(polkey.BUILDS)))
        path = keys.boot_elf(disc)
        if args.out:
            shutil.move(path, args.out)
            path = args.out
        print(path)
    elif args.cmd == "record":
        print(write_record(args.image, args.record, args.write))
    else:
        ap.print_help()


if __name__ == "__main__":
    main()

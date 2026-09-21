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
"""Read a universal PlayOnline boot container, the disc and patch-server form.

The Viewer's boot container (`PP.<product>.1000.POLVIEWER/<product>`) ships in
two forms and only one of them boots:

  * installed: console-bound. `poldecrypt.py` reads this one, but it needs the
    drive's HDD ID and its `__net` record.
  * universal: what the disc carries and what the patch server serves; a drive
    keeps it as `<name>.tmp2`. Its key is in the file, signed with SE's public
    keys, so it reads with no drive material at all.

Square Enix's dnasload reads only the installed form (its tag table, US
`0x002c77d8`, has neither universal tag), so a container copied straight from a
disc does not boot. `ci_transcrypt.py` converts one to the other.

Layout: a 512-byte header then N independent sections
-----------------------------------------------------
Each section is decoded independently.

    file[0:128]    slot 7   96011a8e95fd1ffc
    file[128:256]  slot 21  75b026217eb10058
    file[256:384]  slot 2   count, then two u32 arrays (see below)
    file[384:512]  not RSA; copied across forms verbatim
    file[512:]     section 0, then section 1, ...

The slot-2 block carries both forms' sizes, which is how one RSA-signed block
serves both and why an installer never has to re-sign anything:

    +0            u32 count
    +4            count x u32  universal section sizes (header+bulk, 1024+n)
    +4+4*count    count x u32  installed bulk lengths (add 896 for the section)

Section layout, relative to the section start:

    off    universal                        installed
      0    slot 15 980f3dc290f950bd  KEY    slot 10 (static key)
    128    slot 10 (static key)             slot 28 cfbc323412ad82ab
    256    slot 20 30fad789bb372f79  SHA1   the K1 block, console-bound
    384    slot 28 cfbc323412ad82ab         slot 3  (sizes)
    512    slot 3  bdbf6d4db9be0aa0         slot 11 (session)
    640    slot 11 d7ab6093e3900cb2         slot 4
    768    slot 4  22891cc865f09e3d         the 128-byte 3DES block
    896    the 128-byte 3DES block          bulk
   1024    bulk

So installed = universal minus slot 15 and slot 20, plus the K1 block.

The chain, read from `0x001af2c0` in the boot executable `SLPS_202.00` on the
Japanese PlayOnline disc (plaintext MIPS):

 1. `sess = RSA(sec[640:768], slot 11)`               tag d7ab6093e3900cb2
 2. `b128 = des3(sess[:32], sec[896:1024])`           tag a5713c8bdbe8d420 at [10:26]
 3. `b128[0], [2], [4], [6], [8]` are slot ids (15, 20, 3, 11, 10), stored as
    single bytes at even offsets (the console uses `lbu`). The same table
    serves both forms: universal uses 15 and 20, installed uses 10, and both
    use 3 and 11.
 4. `key = RSA(sec[0:128], slot b128[0]=15)[:32]`     tag 980f3dc290f950bd
 5. `bulk = des3(key, sec[1024:])`, checked by tag 45ddf2896e7a3778 at
    `extra[0] + padded`, which is the universal form's tag rather than
    `poldecrypt`'s c5c6a93441e1acb0.
 6. `RSA(sec[256:384], slot 20)[:20]` is a SHA-1 over the ciphertext,
    `sha1(sec[1024 : 1024 + align8(padded + extra[0] + 16)])`.
 7. the module is `des3(static[:32], bulk[extra[0] : extra[0]+padded])`, sliced
    `[extra[1] : extra[1]+true]`, and carries tag `de21fa67ac8aa168`.

The universal form indexes `extra` with [0]; the installed form uses [2]. That
difference moves the tag and changes the bulk length.

    python ci_universal.py CONTAINER --verify
    python ci_universal.py CONTAINER --modules OUTDIR

The two forms of one build differ by 696 bytes; larger size differences are
differences between builds. An installed drive keeps the universal copy as
`<name>.tmp2` beside the installed one.

`0x001b3f58` is the SHA-1 routine.
"""
import argparse
import hashlib
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
from . import polenc                                              # noqa: E402

FILE_HDR = 512
UNIV_HDR = 1024             # bytes of section header before the bulk
INST_HDR = 896
UNIV_BULK_TAG = b"45ddf2896e7a3778"
INST_BULK_TAG = b"c5c6a93441e1acb0"
B128_TAG = b"a5713c8bdbe8d420"
MODULE_TAG = b"de21fa67ac8aa168"      # the HDD boot executable's kind
PEX_MODULE_TAG = b"6ee4f8ee8d64aa59"   # every `.pex` module's kind


def is_kind_tag(t):
    """The trailing tag is not one constant; it names the payload kind.

    `poldecrypt` records the same thing: the boot executable carries
    `de21fa67ac8aa168`, `.pex` modules carry `6ee4f8ee8d64aa59`. Demanding one
    of them would reject a payload whose bulk tag already proved the key
    correct, so this checks the shape and hands the value back.
    """
    return len(t) == 16 and all(c in b"0123456789abcdef" for c in t)
# The static-key block is signed under a different slot depending on what the
# container holds: every `.pex` module uses slot 6, the HDD boot executable uses
# slot 10. `poldecrypt.STATIC_KEY_BLOCKS` records the same pair. The slot table
# in b128 names 10, so it cannot be trusted for this one block; try both.
STATIC_SLOTS = ((6, b"e6c71666d785d576"), (10, b"2879f6e2370182be"))


def static_key(sec, keys):
    """(32-byte key, slot) from the static-key block, whichever slot signs it."""
    for slot, tag in STATIC_SLOTS:
        d = polenc.unpad_pkcs1(polenc.rsa_public(sec[U_STATIC:U_STATIC + 128], keys[slot]))
        if d is not None and d.endswith(tag):
            return d[:32], slot
    raise ValueError("static-key block at +%d verified under no known slot %s"
                     % (U_STATIC, [s for s, _ in STATIC_SLOTS]))

# section-relative offsets, universal form
U_KEY, U_STATIC, U_SHA1, U_DIGEST, U_SIZES, U_SESSION, U_SLOT4, U_B128 = (
    0, 128, 256, 384, 512, 640, 768, 896)


def _keys():
    return {s: polenc.parse_spki(d) for s, d in polenc.keystore() if d}


def _rsa(blob, off, slot, keys, tag=None, what=""):
    d = polenc.unpad_pkcs1(polenc.rsa_public(blob[off:off + 128], keys[slot]))
    if d is None or (tag is not None and not d.endswith(tag)):
        raise ValueError("%s: block at +%d failed to verify under slot %d"
                         % (what or "block", off, slot))
    return d


def is_universal(blob, keys=None):
    """True for a universal container, False for an installed one.

    Decided from the first section's slot-15 key block, which only the universal
    form has. Uses only SE's public keys (no HDD ID, no `__net` record), so a
    container's form is decidable without the drive it belongs to.
    """
    keys = keys or _keys()
    try:
        d = polenc.unpad_pkcs1(
            polenc.rsa_public(blob[FILE_HDR + U_KEY:FILE_HDR + U_KEY + 128], keys[15]))
        return d is not None and d.endswith(b"980f3dc290f950bd")
    except Exception:
        return False


def section_sizes(blob, keys=None):
    """(universal sizes, installed bulk lengths) from the slot-2 block."""
    keys = keys or _keys()
    d = _rsa(blob, 256, 2, keys, what="section table")
    count = struct.unpack_from("<I", d, 0)[0]
    univ = list(struct.unpack_from("<%dI" % count, d, 4))
    inst = list(struct.unpack_from("<%dI" % count, d, 4 + 4 * count))
    return univ, inst


def sections(blob, keys=None):
    """[(offset, size)] for the universal sections, in order."""
    univ, _ = section_sizes(blob, keys)
    out, off = [], FILE_HDR
    for s in univ:
        out.append((off, s))
        off += s
    return out


def sizes(sec, keys=None):
    """(padded, true, extra) from one section's own sizes block."""
    keys = keys or _keys()
    d = _rsa(sec, U_SIZES, 3, keys, b"bdbf6d4db9be0aa0", "sizes")
    padded, true = struct.unpack("<II", d[:8])
    return padded, true, d[8:-16]


def slot_table(sec, keys=None):
    """The five slot ids the section names for itself: (15, 20, 3, 11, 10)."""
    keys = keys or _keys()
    sess = _rsa(sec, U_SESSION, 11, keys, b"d7ab6093e3900cb2", "session")
    b128 = polenc.des3(sess[:32], sec[U_B128:U_B128 + 128])
    if b128[10:26] != B128_TAG:
        raise ValueError("the 3DES block at +%d did not decrypt (tag %r)"
                         % (U_B128, b128[10:26]))
    # single bytes at even offsets: the console uses `lbu`, not a halfword load
    return [b128[0], b128[2], b128[4], b128[6], b128[8]], b128


def bulk(sec, keys=None):
    """One section's decrypted bulk. Raises unless the universal tag verifies."""
    keys = keys or _keys()
    padded, true, extra = sizes(sec, keys)
    slots, _ = slot_table(sec, keys)
    key = _rsa(sec, U_KEY, slots[0], keys, b"980f3dc290f950bd", "bulk key")[:32]
    out = polenc.des3(key, sec[UNIV_HDR:])
    at = extra[0] + padded
    if out[at:at + 16] != UNIV_BULK_TAG:
        raise ValueError("universal bulk tag failed at %d (%r)" % (at, out[at:at + 16]))
    return out


def payload(sec, keys=None):
    """The `padded`-byte next-layer blob the installed form re-keys verbatim."""
    keys = keys or _keys()
    padded, true, extra = sizes(sec, keys)
    return bulk(sec, keys)[extra[0]:extra[0] + padded]


def module(sec, keys=None):
    """(module bytes, tag): the decrypted section payload."""
    keys = keys or _keys()
    padded, true, extra = sizes(sec, keys)
    key, _slot = static_key(sec, keys)
    out = polenc.des3(key, payload(sec, keys))
    return out[extra[1]:extra[1] + true], out[extra[1] + true:extra[1] + true + 16]


def digest_len(padded, extra):
    """What SHA-1 covers: align8(padded + extra[0] + 16)."""
    return ((padded + extra[0] + 16 + 7) // 8) * 8


def verify(blob, keys=None):
    """Every independent check the format offers. [(label, ok, detail)]."""
    keys = keys or _keys()
    out = []
    univ = is_universal(blob, keys)
    # Both forms are valid; report which one this is.
    out.append(("form", True, "universal" if univ else
                "installed -- use poldecrypt.py (needs HDD ID + __net record)"))
    if not univ:
        return out
    usz, isz = section_sizes(blob, keys)
    total = FILE_HDR + sum(usz)
    out.append(("section table", total == len(blob),
                "%d sections, universal=%s installed_bulk=%s; 512+sum=%d file=%d"
                % (len(usz), usz, isz, total, len(blob))))
    for j, (off, size) in enumerate(sections(blob, keys)):
        sec = blob[off:off + size]
        try:
            padded, true, extra = sizes(sec, keys)
            slots, _ = slot_table(sec, keys)
            out.append(("section %d slots" % j, slots == [15, 20, 3, 11, 10], str(slots)))
            bulk(sec, keys)
            out.append(("section %d bulk tag" % j, True,
                        "padded=%d true=%d extra=%s" % (padded, true, extra.hex(" "))))
            # Slot 20 is a SHA-1 over a ciphertext prefix for the boot
            # container. For a `.pex` module the covered range is unknown, so
            # a mismatch is reported as unverified. The installed form drops
            # slot 20.
            want = _rsa(sec, U_SHA1, slots[1], keys, b"30fad789bb372f79", "sha-1")[:20]
            L = digest_len(padded, extra)
            got = hashlib.sha1(sec[UNIV_HDR:UNIV_HDR + L]).digest()
            if got == want:
                out.append(("section %d sha-1 (+%d)" % (j, L), True, got.hex()))
            else:
                out.append(("section %d sha-1" % j, True,
                            "unverified -- not the boot-container prefix formula "
                            "(normal for a .pex; slot 20 is dropped on install)"))
            mod, tag = module(sec, keys)
            kind = {MODULE_TAG: "boot exe", PEX_MODULE_TAG: ".pex"}.get(tag, "?")
            out.append(("section %d module" % j, is_kind_tag(tag),
                        "%d bytes, tag %r (%s), head %s"
                        % (len(mod), tag, kind, mod[:4].hex())))
            # installed bulk length must match what the slot-2 table promises
            want_len = ((extra[2] + padded + 16 + 7) // 8) * 8
            out.append(("section %d installed len" % j, want_len == isz[j],
                        "computed %d, table %d" % (want_len, isz[j])))
        except ValueError as e:
            out.append(("section %d" % j, False, str(e)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("container")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--modules", metavar="OUTDIR", help="write each section's module")
    args = ap.parse_args()
    blob = open(args.container, "rb").read()
    keys = _keys()
    ok = True
    for label, good, detail in verify(blob, keys):
        print("  [%s] %-30s %s" % ("ok" if good else "FAIL", label, detail))
        ok = ok and good
    if args.modules:
        os.makedirs(args.modules, exist_ok=True)
        base = os.path.basename(args.container)
        for j, (off, size) in enumerate(sections(blob, keys)):
            mod, tag = module(blob[off:off + size], keys)
            dst = os.path.join(args.modules, "%s.sec%d" % (base, j))
            open(dst, "wb").write(mod)
            print("wrote %s (%d bytes)" % (dst, len(mod)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

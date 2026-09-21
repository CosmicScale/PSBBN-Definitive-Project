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
"""PS2 `*.pex.enc` module crypto: the keystore and the RSA header.

Describes the loader in the JP Viewer disc's boot executable, `SLPS_202.00`.
The bulk key derivation is in `polkey.py`.

The boot executable is the user's own and is not part of this package.
`keys.use_disc()` points this module at one, and `$PLAYONLINE_DISC_ELF` names
one for a tool that is run on its own.

Loader pipeline (`0x001025f0 loadModule`)
-----------------------------------------
Build `host0:POL/Data/PS2/{polapp,polmovie}.pex` and try to open it (the dev
path); on failure truncate at the last '.', append ".enc", reopen from HDD, then:

    0x001951a0  decrypt(buf, len, &outLen)     gated on a dev flag at 0x001e3c48
      0x001aa7e0  headerDecrypt   RSA-1024, verified below
      0x001aaa78 -> 0x001aaaa8  bulkDecrypt
    check magic "PEX", copy buf+16.. to high memory,
    origSize = u32 at PEX header +4
    0x00102850  decompress(dst=buf, src=relocated, origSize)

So `.pex.enc` decrypts to a `PEX` container and decompresses to a module
identical to the plain `polapp.pex` in the disc's A..Z tree.

Keystore
--------
`0x001b0c78(keyId, out, &len)` indexes a table embedded in the ELF at 0x001F54F0,
stride 200 bytes, 120 slots:

    +0x00   8   DES key   (in the clear)
    +0x08   8   DES IV    (in the clear)
    +0x10 184   DES-CBC ciphertext = 23 blocks x 8

`0x001b6eb0` is plain CBC over an 8-byte block cipher (key schedule 0x001b6b20 ->
0x001b6808, block decrypt 0x001b6be8 -> 0x001b54c8, encrypt 0x001b41b0). The
cipher is DES: 100 of the 120 slots decrypt to a well-formed X.509
SubjectPublicKeyInfo (OID 1.2.840.113549.1.1.1, 1024-bit modulus, e=65537).
Decrypted slot layout: `[4:8]` big-endian = DER length (the ELF asserts < 177),
`[8:8+len]` = the DER key. The DES key and IV sit in the clear beside the
ciphertext, so this layer is obfuscation only.

RSA header
----------
Two 128-byte RSA-1024 blocks, each PKCS#1 v1.5 type 1 (`00 01 FF..FF 00 || D`),
raised to the public exponent, so it is signature verification and only the
public keys, all in the keystore, are needed:

    file[1024:1152]  slot 3   -> D = u32 v1 | u32 v2 | 3 bytes | tag
                                 tag = "bdbf6d4db9be0aa0"
    file[1152:1280]  slot 11  -> D = 32 bytes of session key material | tag
                                 tag = "d7ab6093e3900cb2"

The four ASCII-hex tags live at 0x00205d30 / d48 / d60 / d78 (24-byte stride):
d7ab6093e3900cb2, a5713c8bdbe8d420, bdbf6d4db9be0aa0, c5c6a93441e1acb0.
Each decoded block ends in its tag, which is how a decode is checked.

Bulk cipher: 3DES-EDE3-CBC
--------------------------
`0x001b8920(k32, len, src, dst)` splits its 32-byte first argument into four
8-byte fields and hands them to `0x001b7ee0` as three DES key schedules plus a
CBC IV, i.e. 3DES-EDE3-CBC, `key = k32[0:24]`, `iv = k32[24:32]`, over `len/8`
blocks. Header block H1 (below) decrypts this way.

File layout (`0x001aaaa8`, with `s5 = file + 640`)
--------------------------------------------------
    file[ 896:1024]  H2   3DES, key from 0x001b3758   -> the bulk key
    file[1024:1152]  RSA sizes block,   key id H1[4]  -> tag bdbf6d4db9be0aa0
    file[1152:1280]  RSA session block, key id 11     -> tag d7ab6093e3900cb2
    file[1408:1536]  H1   3DES, key = the session key -> tag a5713c8bdbe8d420
    file[1536:    ]  bulk 3DES-EDE3-CBC, key from H2

H1 is a fixed 128-byte record, identical in all eight shipped modules:
`0f 06 14 1c 03 1a 0b 0e 0a 04` then the tag. `H1[3] = 28` is the key id used to
verify the payload signature; `H1[4] = 3` is the key id for the sizes block.

The sizes block decodes to `u32 v1 | u32 v2 | 3 bytes | tag`, where v1 is the
padded payload length and v2 the true one. `D[10]` is the payload's offset past
file+1536, so the payload occupies

    file[1536 + D[10] : 1536 + D[10] + v1]

immediately followed by the 16-byte tag `c5c6a93441e1acb0`, the self-check that
proves a correct bulk decrypt. The same region, `(file + 1536 + D[10], v1)`, is
what `0x001b3f58` SHA-1s afterwards for the signature check.

D[10] is a 0..255 pre-payload pad (6..156 across the eight shipped modules), so
the payload start is not block-aligned even though v1 always is. There are
34..171 slack bytes after the tag. D[10] cannot be derived from the file length:
it is a real field and the tag does not sit flush at EOF.

Bulk key (`0x001b33f0`)
-----------------------
The 32-byte bulk key is unwrapped from H2, the block at file[896:1024].
`0x001b3758` builds a constant 32-byte key K2, and
`H2 = 3DES-EDE3-CBC(K2, file[896:1024])`. `0x001b33f0` assembles a 168-byte
struct from slices of H2, runs the 8-round DES-CBC scramble at `0x001b32c8`
over it, and returns bytes 136..168 as the bulk key. `polkey.py` implements
the derivation.

Usage
-----
  python3 -m playonline.lib.polenc --keys             # dump the 120-slot keystore
  python3 -m playonline.lib.polenc --header FILE.enc  # decode + verify a module header
  python3 -m playonline.lib.polenc --layout FILE.enc  # full header layout + payload extent
  python3 -m playonline.lib.polenc --bulk FILE.enc --key <64 hex chars>
                                          # decrypt the payload with a known
                                          # bulk key and check the final tag
"""
import argparse
import os
import struct
import sys

from Crypto.Cipher import DES          # pip install pycryptodome

from .mips import Image

ELF = os.environ.get("PLAYONLINE_DISC_ELF") or None
KEYSTORE_VA = 0x001F54F0
SLOT_STRIDE = 200
SLOT_COUNT = 120
HDR_BLOCKS = ((1024, 3, b"bdbf6d4db9be0aa0"),      # sizes block
              (1152, 11, b"d7ab6093e3900cb2"))     # session-key block

H1_OFF = 1408                                       # 3DES, key = session key
H1_TAG = b"a5713c8bdbe8d420"
BULK_OFF = 1536                                     # 3DES, key from H2
PAYLOAD_TAG = b"c5c6a93441e1acb0"


def des3(k32, data):
    """0x001b8920 -> 0x001b7ee0: k32 = three DES keys then a CBC IV.

    Built from three raw DES cores rather than `DES3` because pycryptodome
    refuses keys where k1 == k2 or k2 == k3 ("degenerates to single DES") and
    the PS2 has no such guard, so a candidate bulk key must be testable whatever
    its bytes are. `0x001b7090` is the EDE core: D_k1(E_k2(D_k3(c))), then the
    result is XORed with the previous ciphertext block, i.e. plain CBC decrypt.
    """
    d1 = DES.new(k32[0:8], DES.MODE_ECB)
    d2 = DES.new(k32[8:16], DES.MODE_ECB)
    d3 = DES.new(k32[16:24], DES.MODE_ECB)
    prev = k32[24:32]
    out = bytearray()
    for i in range(0, len(data) - 7, 8):
        blk = data[i:i + 8]
        dec = d1.decrypt(d2.encrypt(d3.decrypt(blk)))
        out += bytes(a ^ b for a, b in zip(dec, prev))
        prev = blk
    return bytes(out)


def des3_enc(k32, data):
    """The exact inverse of `des3`, so a decrypted payload can be put back.

    Every other block in a `.pex.enc` container is RSA-signed under keys not
    available here (the sizes block, the static-key block), so a modified module
    can only be written back if the edit is exactly the same length and those
    blocks are left untouched. Under that constraint the bulk is the only thing
    that has to be recomputed, and it is 3DES-CBC with keys the drive itself
    yields.

    `des3` computes `D_k1(E_k2(D_k3(c))) ^ prev` with `prev` the previous
    ciphertext block; inverting gives `E_k3(D_k2(E_k1(p ^ prev)))` with `prev`
    the block just produced. polencpatch's `--selftest` round-trips the pair.
    """
    d1 = DES.new(k32[0:8], DES.MODE_ECB)
    d2 = DES.new(k32[8:16], DES.MODE_ECB)
    d3 = DES.new(k32[16:24], DES.MODE_ECB)
    prev = k32[24:32]
    out = bytearray()
    for i in range(0, len(data) - 7, 8):
        blk = bytes(a ^ b for a, b in zip(data[i:i + 8], prev))
        enc = d3.encrypt(d2.decrypt(d1.encrypt(blk)))
        out += enc
        prev = enc
    return bytes(out)


MIN_RUN = 6                     # consecutive valid slots that identify the table


def _slot_ok(buf, off):
    """True if a keystore slot starts here.

    A populated slot decrypts to a DER SEQUENCE in long form. Empty slots
    exist, so a run of valid ones identifies the table.
    """
    if off < 0 or off + SLOT_STRIDE > len(buf):
        return False
    e = buf[off:off + SLOT_STRIDE]
    try:
        pt = DES.new(e[0:8], DES.MODE_CBC, e[8:16]).decrypt(e[16:SLOT_STRIDE])
    except Exception:                                       # noqa: BLE001
        return False
    length, = struct.unpack(">I", pt[4:8])
    return 0 < length < 177 and pt[8] == 0x30 and pt[9] == 0x81


def keystore_offset(img):
    """File offset of the keystore table in `img`.

    KEYSTORE_VA is where it sits in the JP PlayOnline disc's SLPS_202.00 and
    nowhere else. Every other build puts it somewhere of its own, so the address
    is a hint that is checked before it is used, and the table is found by its
    own shape when the hint is wrong.
    """
    b = img.b
    try:
        hint = img.off(KEYSTORE_VA)
    except Exception:                                       # noqa: BLE001
        hint = None
    if hint is not None and all(_slot_ok(b, hint + i * SLOT_STRIDE)
                                for i in range(MIN_RUN)):
        return hint
    limit = len(b) - SLOT_STRIDE * MIN_RUN
    off = 0
    while off < limit:
        if _slot_ok(b, off) and _slot_ok(b, off + SLOT_STRIDE):
            if all(_slot_ok(b, off + i * SLOT_STRIDE) for i in range(MIN_RUN)):
                return off
            off += SLOT_STRIDE
            continue
        off += 4
    raise ValueError("no keystore table in this executable")


def keystore(elf=None):
    """Yield (slot, der) for every populated keystore slot. None where invalid.

    `elf` defaults to `polenc.ELF`, read when the function is called.
    """
    path = elf or ELF
    if not path:
        raise ValueError("no boot executable: call keys.use_disc() or set "
                         "PLAYONLINE_DISC_ELF")
    img = Image(path)
    o = keystore_offset(img)
    b = img.b
    for slot in range(SLOT_COUNT):
        e = b[o + slot * SLOT_STRIDE: o + (slot + 1) * SLOT_STRIDE]
        pt = DES.new(e[0:8], DES.MODE_CBC, e[8:16]).decrypt(e[16:SLOT_STRIDE])
        n = struct.unpack(">I", pt[4:8])[0]
        yield slot, (pt[8:8 + n] if 0 < n < 177 else None)


def parse_spki(der):
    """Pull (modulus, exponent) out of an RSA SubjectPublicKeyInfo."""
    i = der.find(b"\x02\x81\x81\x00")          # INTEGER, 129 bytes, leading zero
    if i < 0:
        return None
    mod = int.from_bytes(der[i + 4:i + 4 + 128], "big")
    j = i + 4 + 128
    if der[j] != 0x02:
        return None
    return mod, int.from_bytes(der[j + 2:j + 2 + der[j + 1]], "big")


def rsa_public(block, key):
    mod, exp = key
    return pow(int.from_bytes(block, "big"), exp, mod).to_bytes(128, "big")


def unpad_pkcs1(m):
    """00 01 FF..FF 00 || D  ->  D, or None if the padding is not type 1."""
    if len(m) < 11 or m[0] != 0x00 or m[1] != 0x01:
        return None
    i = m.find(b"\x00", 2)
    return m[i + 1:] if i > 2 else None


def read_header(path, elf=ELF):
    """Decode a .pex.enc header. Returns a dict; raises if a tag fails."""
    keys = {s: parse_spki(d) for s, d in keystore(elf) if d}
    with open(path, "rb") as f:
        blob = f.read()
    out = {"file": os.path.basename(path), "size": len(blob)}
    for off, slot, tag in HDR_BLOCKS:
        d = unpad_pkcs1(rsa_public(blob[off:off + 128], keys[slot]))
        if d is None or not d.endswith(tag):
            raise ValueError("%s: block at %d (slot %d) failed to verify" % (path, off, slot))
        body = d[:-len(tag)]
        if off == 1024:
            out["v1"], out["v2"] = struct.unpack("<II", body[:8])
            out["extra"] = body[8:]
        else:
            out["session_key"] = body
    return out


def read_layout(path, elf=ELF):
    """Full header decode: RSA blocks, H1, and the payload extent.

    Mirrors `0x001aaaa8` step for step.  Raises if any of the three tags fail.
    """
    h = read_header(path, elf)
    with open(path, "rb") as f:
        blob = f.read()

    h1 = des3(h["session_key"], blob[H1_OFF:H1_OFF + 128])
    if h1[10:26] != H1_TAG:
        raise ValueError("%s: H1 failed to verify" % path)

    h["h1"] = h1
    h["sig_key_id"] = h1[3]                 # sp[656], for the payload signature
    h["size_key_id"] = h1[4]                # sp[660], for the sizes block
    if h["size_key_id"] != HDR_BLOCKS[0][1]:
        raise ValueError("%s: sizes-block key id %d, expected %d"
                         % (path, h["size_key_id"], HDR_BLOCKS[0][1]))

    # D[10] is the payload's offset past file+1536; the tag follows the payload,
    # so this is also len(file) - 1552 - v1.
    h["payload_off"] = BULK_OFF + h["extra"][2]      # D[10]; extra = D[8:11]
    h["payload_len"] = h["v1"]              # padded; v2 is the true length
    if h["payload_off"] + h["v1"] + 16 > len(blob):
        raise ValueError("%s: payload extent runs past EOF" % path)
    return h


def bulk_decrypt(path, key32, elf=ELF):
    """Decrypt file[1536:] with a candidate bulk key and check the final tag.

    Returns (payload, ok). `ok` is the loader's own tag check.
    """
    h = read_layout(path, elf)
    with open(path, "rb") as f:
        blob = f.read()
    n = (len(blob) - BULK_OFF) & ~7
    plain = des3(key32, blob[BULK_OFF:BULK_OFF + n])
    off = h["payload_off"] - BULK_OFF
    end = off + h["payload_len"]
    return plain[off:off + h["v2"]], plain[end:end + 16] == PAYLOAD_TAG


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--keys", action="store_true", help="dump the keystore")
    ap.add_argument("--header", nargs="+", help="decode .pex.enc headers")
    ap.add_argument("--layout", nargs="+", help="full header layout")
    ap.add_argument("--bulk", help="decrypt a payload with --key")
    ap.add_argument("--key", help="64 hex chars: 3 DES keys then the CBC IV")
    args = ap.parse_args()

    if args.keys:
        ok = 0
        for slot, der in keystore():
            k = parse_spki(der) if der else None
            if k:
                ok += 1
                print("slot %3d  der=%3d  e=%-6d n=%s..." % (slot, len(der), k[1], hex(k[0])[2:34]))
            else:
                print("slot %3d  (no valid key)" % slot)
        print("\n%d/%d slots hold RSA-1024 public keys" % (ok, SLOT_COUNT))

    for p in args.header or []:
        h = read_header(p)
        print("%-22s size=%-9d v1=%-9d v2=%-9d v1-v2=%d"
              % (h["file"], h["size"], h["v1"], h["v2"], h["v1"] - h["v2"]))
        print("    session key: %s" % h["session_key"].hex(" "))
        print("    extra      : %s" % h["extra"].hex(" "))
        print("    both PKCS#1 tags verified")

    for p in args.layout or []:
        h = read_layout(p)
        print("%s  (%d bytes)" % (h["file"], h["size"]))
        print("    H1        : %s + tag   [verified]" % h["h1"][:10].hex(" "))
        print("    key ids   : sizes=%d  signature=%d" % (h["size_key_id"], h["sig_key_id"]))
        print("    session   : %s" % h["session_key"].hex(" "))
        print("    payload   : file[%d:%d]  (padded %d, true %d)"
              % (h["payload_off"], h["payload_off"] + h["payload_len"],
                 h["v1"], h["v2"]))
        print("    tag at    : file[%d:%d]  after bulk decrypt"
              % (h["payload_off"] + h["payload_len"],
                 h["payload_off"] + h["payload_len"] + 16))

    if args.bulk:
        if not args.key:
            ap.error("--bulk needs --key")
        payload, ok = bulk_decrypt(args.bulk, bytes.fromhex(args.key))
        print("tag %s   first 8 bytes: %s"
              % ("OK" if ok else "MISMATCH", payload[:8].hex(" ")))


if __name__ == "__main__":
    main()

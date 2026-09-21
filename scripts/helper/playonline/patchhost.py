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
"""Point a staged Viewer's patch requests at a chosen host.

Square Enix's PlayOnline patch servers still answer, and the update they
serve to a PS2 is the end-of-service patch, which disables the Viewer. A
console reaches them only when its DNS resolves the `pol.com` names publicly.
This module removes that possibility for the patch servers by naming a
different host in the two places the Viewer takes its patch server from:

  * `PATCH_SERVER_DOMAIN` in `data/utf/env.dat`, the Viewer's own patch host
  * the template `pc%03d%s.pol.com` in the login module, the patch host of
    each title (the port, 53000 plus the title number, already selects the
    title, so one host can serve them all)

Every other host name is left alone. The other services are found through
DNS as before, and Square Enix no longer runs them.

env.dat is a text file of `KEY,value` lines (Shift-JIS, CRLF) under the
PlayOnline data-file cipher:

    [ plaintext, zero-padded to a multiple of 8 ][ u32 length, u32 checksum ]

Each 8-byte block at offset `pos` is enciphered with a 64-bit word from a
32-row table derived from an 8-byte key (`T[0] = munge(key)`,
`T[n] = T[n-1] * 5`). The checksum is the sum of bytes 0 and 4 of every
plaintext block, and the Viewer rejects a file whose checksum does not match
or whose size is not a multiple of 8.

The template is edited only in a plain (decompressed) login module, which is
what a plaintext-mode drive runs. The replacement must fit the bytes the
string and its padding occupy.

An installed Viewer can also be edited in place. Both files are replaced
inside the zones they already occupy.

    python3 -m playonline.patchhost STAGED_VIEWER_TREE --show
    python3 -m playonline.patchhost STAGED_VIEWER_TREE --host play.example.org
    sudo python3 -m playonline.patchhost --drive /dev/sdX --title viewer-us --show
    sudo python3 -m playonline.patchhost --drive /dev/sdX --title viewer-us --write
"""
import argparse
import os
import re
import struct
import sys

M32 = 0xFFFFFFFF
M64 = (1 << 64) - 1
MAGIC = 0xA1652347
KEY_ENV = bytes.fromhex("fd31425364758697")

#: The host a Viewer installed by this package asks for updates. It can be
#: changed with $POL_PATCH_HOST; the value `none` leaves the disc's names.
DEFAULT_HOST = "play.openlobby.fyi"

ENV_DAT = os.path.join("POL", "install", "PS2", "data", "utf", "env.dat")
ENV_KEY = "PATCH_SERVER_DOMAIN"
LOGIN_MODULE = os.path.join("POL", "Data", "PS2", "login.pex")
TEMPLATE = b"pc%03d%s.pol.com"

_HOST_OK = re.compile(r"^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+"
                      r"[A-Za-z]{2,63}$")


def host_from_env(environ=None):
    """The host to use, or None when the rewrite is turned off."""
    value = (environ if environ is not None else os.environ).get("POL_PATCH_HOST")
    if not value:
        return DEFAULT_HOST
    if value.lower() == "none":
        return None
    return value


def check_host(host):
    if not _HOST_OK.match(host):
        raise SystemExit("%r is not a usable host name" % host)
    return host


# ---- the data-file cipher ---------------------------------------------------

def _rotl32(v, n):
    v &= M32
    return ((v << n) | (v >> (32 - n))) & M32


def _schedule(key8):
    """(32 table words, 32 per-row byte deltas) for an 8-byte key."""
    k = int.from_bytes(key8, "little")
    hi, lo = (k >> 32) & M32, k & M32
    seed = ((_rotl32(lo, 8) << 32) | _rotl32(hi, 16)) & M64
    t = bytearray(seed.to_bytes(8, "little"))
    t[0] = (t[0] + 69) & 0xFF
    for i in range(1, 8):
        b = t[i - 1]
        x = (b + t[i] + 212) & M32
        x ^= (b << 2) & M32
        t[i] = (x ^ 0x45) & 0xFF
    words, deltas = [], []
    v = int.from_bytes(t, "little")
    for _ in range(32):
        words.append(v)
        deltas.append((8 * 0x78 - sum(v.to_bytes(8, "little"))) & 0xFF)
        v = (v * 5) & M64
    return words, deltas


def _position_word(pos):
    p = pos & M32
    return ((p | (p << 10) | (p << 20) | (p << 30)) + MAGIC) & M64


def decrypt(data, key8=KEY_ENV):
    """Return (payload, checksum_ok)."""
    if len(data) & 7 or len(data) < 16:
        raise ValueError("length %d is not a usable multiple of 8" % len(data))
    words, deltas = _schedule(key8)
    buf = bytearray(data)
    cksum = 0
    blocks = len(buf) // 8
    for n in range(blocks):
        pos, row = n * 8, n & 31
        prev = (n ^ 0x45) & 0xFF
        blk = bytearray(8)
        for j in range(8):
            c = buf[pos + j]
            blk[j] = ((prev ^ c) + deltas[row]) & 0xFF
            prev = c
        x = int.from_bytes(blk, "little")
        y = ((x - words[row]) & M64) ^ _position_word(pos) ^ words[row]
        y = ((y << 32) | (y >> 32)) & M64
        buf[pos:pos + 8] = y.to_bytes(8, "little")
        if n < blocks - 1:
            cksum = (cksum + buf[pos] + buf[pos + 4]) & M32
    length, want = struct.unpack_from("<II", buf, len(buf) - 8)
    return bytes(buf[:length]), cksum == want


def encrypt(payload, key8=KEY_ENV):
    """The inverse of `decrypt`: pad, append the trailer, encipher."""
    words, deltas = _schedule(key8)
    body = bytearray(payload)
    body += b"\0" * (-len(body) % 8)
    cksum = 0
    for n in range(len(body) // 8):
        cksum = (cksum + body[n * 8] + body[n * 8 + 4]) & M32
    buf = body + struct.pack("<II", len(payload), cksum)
    for n in range(len(buf) // 8):
        pos, row = n * 8, n & 31
        y = int.from_bytes(buf[pos:pos + 8], "little")
        r = ((y << 32) | (y >> 32)) & M64
        x = (((r ^ words[row]) ^ _position_word(pos)) + words[row]) & M64
        blk = x.to_bytes(8, "little")
        prev = (n ^ 0x45) & 0xFF
        for j in range(8):
            c = (prev ^ ((blk[j] - deltas[row]) & 0xFF)) & 0xFF
            buf[pos + j] = c
            prev = c
    return bytes(buf)


# ---- env.dat ----------------------------------------------------------------

def read_env(data):
    """[(key, value)] from an enciphered env.dat, or exit if it does not open."""
    payload, ok = decrypt(data)
    if not ok:
        raise SystemExit("env.dat did not decrypt (checksum mismatch)")
    if encrypt(payload) != data:
        raise SystemExit("env.dat does not round-trip; refusing to edit it")
    pairs = []
    for line in payload.decode("shift_jis").split("\r\n"):
        if line:
            key, _, value = line.partition(",")
            pairs.append((key, value))
    return pairs


def write_env(pairs):
    payload = "".join("%s,%s\r\n" % kv for kv in pairs).encode("shift_jis")
    out = encrypt(payload)
    back, ok = decrypt(out)
    if not ok or back != payload:
        raise SystemExit("the rebuilt env.dat does not verify")
    return out


def set_env_host(data, host):
    """(new file bytes, old value). The key is appended when it is absent."""
    pairs = read_env(data)
    old = None
    for i, (key, value) in enumerate(pairs):
        if key == ENV_KEY:
            old = value
            pairs[i] = (key, host)
    if old is None:
        pairs.append((ENV_KEY, host))
    return write_env(pairs), old


# ---- the title template -----------------------------------------------------

def find_template(data):
    """[(offset, current string, room)] for each title patch-host string.

    Finds the disc's template and also a host name an earlier run wrote in
    its place, which is recognised by the string that precedes it in every
    build, `PATCH_SERVER_DOMAIN`.
    """
    out = []
    anchor = data.find(ENV_KEY.encode("ascii") + b"\0")
    at = data.find(TEMPLATE + b"\0")
    if at < 0 and anchor >= 0:
        at = anchor + len(ENV_KEY) + 1
        while at < len(data) and data[at] == 0:
            at += 1
        if at - anchor > 64:
            at = -1
    if at < 0:
        return out
    end = data.index(b"\0", at)
    z = end
    while z < len(data) and data[z] == 0:
        z += 1
    # The last NUL of the run terminates the string; the rest is padding.
    out.append((at, data[at:end].decode("latin-1"), z - at - 1))
    return out


def set_template_host(data, host):
    """(new module bytes, [(offset, old string)]). Exits when it cannot fit."""
    sites = find_template(data)
    if not sites:
        raise SystemExit("the title patch-host template was not found in the "
                         "login module")
    raw = host.encode("ascii")
    buf = bytearray(data)
    done = []
    for at, old, room in sites:
        if len(raw) > room:
            raise SystemExit("%r is %d characters and the login module has "
                             "room for %d" % (host, len(raw), room))
        buf[at:at + room] = raw + b"\0" * (room - len(raw))
        done.append((at, old))
    return bytes(buf), done


# ---- a staged tree ----------------------------------------------------------

def show(src_dir):
    lines = []
    env = os.path.join(src_dir, ENV_DAT)
    if os.path.isfile(env):
        with open(env, "rb") as f:
            pairs = dict(read_env(f.read()))
        lines.append("env.dat    %s = %s" % (ENV_KEY, pairs.get(ENV_KEY, "(absent)")))
    else:
        lines.append("env.dat    not in this tree")
    mod = os.path.join(src_dir, LOGIN_MODULE)
    if os.path.isfile(mod):
        with open(mod, "rb") as f:
            for at, cur, room in find_template(f.read()):
                lines.append("login.pex  0x%06x %s (room %d)" % (at, cur, room))
    else:
        lines.append("login.pex  no plain module in this tree")
    return lines


def apply(src_dir, host, write=True):
    """Rewrite both places in a staged Viewer tree. Returns report lines.

    A tree with no plain login module (a transcrypt-mode drive) gets the
    env.dat edit only, and the report says so.
    """
    check_host(host)
    lines = []
    env = os.path.join(src_dir, ENV_DAT)
    if not os.path.isfile(env):
        raise SystemExit("%s: no %s" % (src_dir, ENV_DAT))
    with open(env, "rb") as f:
        new_env, old = set_env_host(f.read(), host)
    lines.append("Viewer patch host: %s -> %s" % (old or "(absent)", host))

    # Both edits are worked out before either file is written, so a host
    # that does not fit the module leaves the tree as it was.
    mod = os.path.join(src_dir, LOGIN_MODULE)
    new_mod = None
    if os.path.isfile(mod):
        with open(mod, "rb") as f:
            new_mod, done = set_template_host(f.read(), host)
        for _at, was in done:
            lines.append("title patch host:  %s -> %s" % (was, host))
    else:
        lines.append("title patch host:  unchanged; this tree has no plain "
                     "login module")
    if write:
        with open(env, "wb") as f:
            f.write(new_env)
        if new_mod is not None:
            with open(mod, "wb") as f:
                f.write(new_mod)
    return lines


# ---- an installed Viewer ----------------------------------------------------

DRIVE_ENV = "/data/utf/env.dat"
DRIVE_LOGIN = "/V/login.pex"


def apply_to_drive(drive, partition, host, write=False):
    """Rewrite both places in a Viewer partition on a drive. Returns lines.

    With `host` None the current values are reported and nothing changes.
    Nothing is written unless both edits fit the zones the files already have.
    """
    from .lib import polfill, polnetdump, polpfspatch, polpfsread
    if host:
        check_host(host)
    lines = []
    with open(drive, "r+b" if (write and host) else "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        hit = [p for p in polnetdump.partitions(f, size) if p[3] == partition]
        if not hit:
            raise SystemExit("%s: no partition named %s" % (drive, partition))
        part, root = polpfsread.mount(f, hit[0][0], hit[0][1])
        if part is None:
            raise SystemExit("%s did not mount" % partition)

        plan = []
        zone, ino = polpfspatch.find(part, root, DRIVE_ENV)
        data = polfill.read_content(part, ino)
        if host:
            new, old = set_env_host(data, host)
            lines.append("Viewer patch host: %s -> %s" % (old or "(absent)", host))
            plan.append((DRIVE_ENV, zone, ino, data, new))
        else:
            lines.append("env.dat    %s = %s"
                         % (ENV_KEY, dict(read_env(data)).get(ENV_KEY, "(absent)")))
        try:
            zone, ino = polpfspatch.find(part, root, DRIVE_LOGIN)
        except SystemExit:
            zone = None
            lines.append("title patch host:  unchanged; this drive has no plain "
                         "login module")
        if zone is not None:
            data = polfill.read_content(part, ino)
            if host:
                new, done = set_template_host(data, host)
                for _at, was in done:
                    lines.append("title patch host:  %s -> %s" % (was, host))
                plan.append((DRIVE_LOGIN, zone, ino, data, new))
            else:
                for at, cur, room in find_template(data):
                    lines.append("login.pex  0x%06x %s (room %d)" % (at, cur, room))

        for path, _zone, ino, _old, new in plan:
            room = sum(cnt for _n, cnt in ino["runs"]) * part.zone_size
            if len(new) > room:
                raise SystemExit("%s: %d B allocated, %d B needed; it does not "
                                 "fit in place" % (path, room, len(new)))
        if not (write and host):
            if host:
                lines.append("(plan only; pass --write)")
            return lines
        if all(new == old for _p, _z, _i, old, new in plan):
            return ["the installed Viewer already names %s as its patch host" % host]
        for path, zone, ino, old, new in plan:
            if new == old:
                continue
            polpfspatch.patch(part, zone, ino, new, True)
            f.flush()
            os.fsync(f.fileno())
            after = polfill.read_content(part, polfill.read_inode(part, zone))
            if after != new:
                raise SystemExit("%s: readback after the write does not match" % path)
        lines.append("written, read back identical")
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src", nargs="?", help="a staged Viewer tree")
    ap.add_argument("--drive", help="edit an installed Viewer on this drive or image")
    ap.add_argument("--title", default="viewer-us",
                    help="with --drive, which Viewer (default %(default)s)")
    ap.add_argument("--write", action="store_true", help="with --drive, write")
    ap.add_argument("--host", help="the host to name (default $POL_PATCH_HOST, "
                                   "then %s)" % DEFAULT_HOST)
    ap.add_argument("--show", action="store_true", help="print the current values")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.drive:
        from . import titles
        if args.title not in titles.TITLES:
            sys.exit("unknown title %r" % args.title)
        host = None if args.show else (args.host or host_from_env())
        if host is None and not args.show:
            print("POL_PATCH_HOST=none: nothing to do")
            return 0
        for line in apply_to_drive(args.drive, titles.TITLES[args.title].partition,
                                   host, write=args.write):
            print(line)
        return 0
    if not args.src:
        ap.error("give a staged tree, or --drive")
    if args.show:
        for line in show(args.src):
            print(line)
        return 0
    host = args.host or host_from_env()
    if host is None:
        print("POL_PATCH_HOST=none: nothing to do")
        return 0
    for line in apply(args.src, host, write=not args.dry_run):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

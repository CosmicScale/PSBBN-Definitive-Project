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
"""Show how far pfsshell has got through a command list.

pfsshell prints its `> ` prompt once for every command it takes off stdin
and nothing else that is regular. This module reads pfsshell's output on
stdin, counts the prompts against the number of commands the caller says
were sent, and redraws one progress line on the terminal. A large title is
tens of thousands of files and would otherwise install in silence.

    sudo pfsshell < cmds 2>&1 | python3 -m playonline.pfsprogress 41234 --log FILE

The output is not passed through, because it is about a megabyte of prompts
for a big title. With `--log FILE`, only the pieces that look like an error
are appended there. The count is a guide only; `build --verify` is the
check.
"""
import sys

WIDTH = 40


def draw(out, done, total):
    done = min(done, total)
    frac = done / float(total) if total else 1.0
    fill = int(frac * WIDTH)
    out.write("\r  [%s%s] %3d%%  %d/%d" % ("#" * fill, "." * (WIDTH - fill),
                                          int(frac * 100), done, total))
    out.flush()


def main():
    try:
        total = int(sys.argv[1])
    except (IndexError, ValueError):
        sys.exit("usage: pfsprogress COMMAND_COUNT [--log FILE] < pfsshell-output")
    log = None
    if "--log" in sys.argv[2:]:
        log = open(sys.argv[sys.argv.index("--log") + 1], "ab")
    try:
        out = open("/dev/tty", "w")
    except OSError:
        out = sys.stderr
    done, shown, carry = 0, -1, b""
    stream = sys.stdin.buffer
    while True:
        chunk = stream.read1(65536) if hasattr(stream, "read1") else stream.read(4096)
        if not chunk:
            break
        data = carry + chunk
        done += data.count(b"> ")
        if log is not None:
            for piece in data.replace(b"> ", b"\n").split(b"\n"):
                low = piece.lower()
                if b"(!)" in piece or b"error" in low or b"fail" in low:
                    log.write(b"pfsshell: " + piece.strip()[:300] + b"\n")
        # A prompt split across two reads is counted on the next one.
        carry = data[-1:] if data.endswith(b">") else b""
        step = done * 200 // total if total else 200
        if step != shown:
            draw(out, done, total)
            shown = step
    draw(out, total, total)
    out.write("\n")
    out.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())

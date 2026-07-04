#!/usr/bin/env python3

"""
TXT to icon.sys form the PSBBN Definitive Project
Copyright (C) 2024-2026 CosmicScale

<https://github.com/CosmicScale/PSBBN-Definitive-Project>

SPDX-License-Identifier: GPL-3.0-or-later

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

import sys
import os
import unicodedata

# Mapping for unsupported or problematic characters
REPLACEMENTS = {
    "'": "’",
    "-": "ー",
    # Subscript numbers
    "₀": "０",
    "₁": "１",
    "₂": "２",
    "₃": "３",
    "₄": "４",
    "₅": "５",
    "₆": "６",
    "₇": "７",
    "₈": "８",
    "₉": "９",
}

def ascii_to_fullwidth(text):
    result = []
    for c in text:
        # Replace mapped characters
        if c in REPLACEMENTS:
            c = REPLACEMENTS[c]
        # Decompose accented characters to base (e.g., é → e)
        c = unicodedata.normalize('NFD', c)[0]

        code = ord(c)
        if 0x21 <= code <= 0x7E:
            fullwidth_char = chr(code + 0xFEE0)
        elif c == ' ':
            fullwidth_char = '\u3000'
        else:
            fullwidth_char = c
        result.append(fullwidth_char)
    return ''.join(result)

def sanitize_for_shift_jis(text):
    return ''.join(c for c in text if can_encode_shift_jis(c))

def can_encode_shift_jis(char):
    try:
        char.encode("shift_jis")
        return True
    except UnicodeEncodeError:
        return False

def update_icon_sys(path, title0, title1):
    if len(title0) > 16 or len(title1) > 16:
        print("[!] Error: Both title0 and title1 must be 16 characters or fewer.")
        sys.exit(1)

    try:
        with open(path, "rb") as f:
            data = bytearray(f.read())

        title_block_offset = 0xC0
        title_block_length = 68

        # Convert to full-width, replace unsupported, and sanitize
        title0_fw = sanitize_for_shift_jis(ascii_to_fullwidth(title0))
        title1_fw = sanitize_for_shift_jis(ascii_to_fullwidth(title1))

        title0_encoded = title0_fw.encode("shift_jis")
        title1_encoded = title1_fw.encode("shift_jis")

        split_offset = len(title0_encoded)
        if split_offset > 68:
            print("[!] Error: title0 too long after encoding.")
            sys.exit(1)

        title_combined = title0_encoded + title1_encoded
        title_block = title_combined[:title_block_length].ljust(title_block_length, b'\x00')

        # Set split offset at byte 0x06
        data[0x06] = split_offset

        data[title_block_offset:title_block_offset + title_block_length] = title_block

        with open("icon.sys", "wb") as f:
            f.write(data)

        # print(f"[✓] Updated icon.sys with dynamic split offset ({split_offset:#04x}): {path}")

    except Exception as e:
        print(f"[!] Failed to update icon.sys: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 txt_to_icon_sys.py path/to/icon.sys title0 title1")
        sys.exit(1)

    _, icon_path, title0, title1 = sys.argv
    if not os.path.isfile(icon_path):
        print(f"[!] File not found: {icon_path}")
        sys.exit(1)

    update_icon_sys(icon_path, title0, title1)

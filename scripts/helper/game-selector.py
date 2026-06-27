#!/usr/bin/env python3
#
# Game Selector for the PSBBN Definitive Project
# Copyright (C) 2024-2026 CosmicScale
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Interactive game selector with multiselect and progress bar using Textual.

Scans a games directory (containing CD/, DVD/, POPS/ subfolders), extracts
game IDs and titles, presents an interactive TUI for selection, and writes
the chosen games to an output file in pipe-delimited format.
"""

import sys
import argparse
import os
import re
import math
import lz4.block
import unicodedata
from pathlib import Path
from struct import unpack
from collections import defaultdict

from textual.app import App, ComposeResult
from textual.widgets import SelectionList, ProgressBar, Button, Header, Footer, Static, Input
from textual.containers import Horizontal, VerticalScroll
from textual import on


# ── ISO / ZSO / VCD helpers (from list-builder.py) ──────────────────────

ZISO_MAGIC = 0x4F53495A
SECTOR_SIZE = 2048
_PATTERN_1 = [b'\x01', b'\x0D']
_PATTERN_2 = [b'\x3B', b'\x31']


def _read_zso_header(fin):
    data = fin.read(24)
    return unpack('IIQIbbxx', data)


def _lz4_decompress(compressed, block_size):
    while True:
        try:
            return lz4.block.decompress(compressed, uncompressed_size=block_size)
        except lz4.block.LZ4BlockError:
            compressed = compressed[:-1]


def _decompress_zso_sector(fin, index_buf, block_size, align, sector, num_sectors=1):
    start_byte = sector * SECTOR_SIZE
    end_byte = (sector + num_sectors) * SECTOR_SIZE
    decompressed = bytearray()
    total_blocks = len(index_buf) - 1
    block_start_num = start_byte // block_size
    block_end_num = (end_byte + block_size - 1) // block_size

    for block in range(block_start_num, min(block_end_num, total_blocks)):
        index = index_buf[block]
        plain = index & 0x80000000
        index &= 0x7FFFFFFF
        read_pos = index << align
        next_index = index_buf[block + 1] & 0x7FFFFFFF
        read_size = (next_index - index) << align
        fin.seek(read_pos)
        data = fin.read(read_size)
        dec_data = data if plain else _lz4_decompress(data, block_size)
        block_start = block * block_size
        block_end = block_start + len(dec_data)
        lo = max(start_byte - block_start, 0)
        hi = min(end_byte - block_start, len(dec_data))
        decompressed.extend(dec_data[lo:hi])
    return decompressed


def _read_iso_sector(fin, sector, num_sectors=1):
    fin.seek(sector * SECTOR_SIZE)
    return fin.read(num_sectors * SECTOR_SIZE)


def _parse_dir_entries(data):
    entries = []
    offset = 0
    while offset < len(data):
        length = data[offset]
        if length == 0:
            offset = (offset // SECTOR_SIZE + 1) * SECTOR_SIZE
            continue
        record = data[offset:offset + length]
        lba = int.from_bytes(record[2:6], "little")
        size = int.from_bytes(record[10:14], "little")
        name = record[33:33 + record[32]].decode("utf-8", errors="ignore")
        entries.append((name, lba, size))
        offset += length
    return entries


def _extract_game_id_from_disc(fin, sector_reader):
    pvd = sector_reader(16, 1)
    root_record = pvd[156:190]
    root_lba = int.from_bytes(root_record[2:6], "little")
    root_size = int.from_bytes(root_record[10:14], "little")
    nsect = (root_size + SECTOR_SIZE - 1) // SECTOR_SIZE
    root_data = sector_reader(root_lba, nsect)

    for name, lba, size in _parse_dir_entries(root_data):
        if name.upper().startswith("SYSTEM.CNF"):
            nsect = (size + SECTOR_SIZE - 1) // SECTOR_SIZE
            text = sector_reader(lba, nsect).decode("utf-8", errors="ignore")
            for line in text.splitlines():
                if line.strip().upper().startswith("BOOT2"):
                    return line.split("\\")[-1].split(";")[0].upper()
    return None


def _clean_name_from_filename(name, game_id):
    base = os.path.splitext(name)[0]
    if base.upper().startswith(game_id):
        stripped = base[len(game_id):].lstrip('_. ')
        return stripped if stripped else base
    return base


def _make_partition_label(game_id, title, suffix):
    tid = re.sub(r'_(...)\.', r'-\1', game_id).replace('.', '')
    title = title.replace('²', '2').replace('³', '3')
    ascii_ = unicodedata.normalize('NFKD', title).encode('ascii', 'ignore').decode()
    ascii_ = re.sub(r'[^A-Z0-9]', '_', ascii_.upper())
    ascii_ = re.sub(r'^_+|_+$', '', ascii_)
    ascii_ = re.sub(r'_+', '_', ascii_)
    label = f"PP.{tid}.{suffix}.{ascii_}"[:32].rstrip('_')
    return label


# ── Game scanning ───────────────────────────────────────────────────────

def _load_titles_db(csv_path):
    db = {}
    if os.path.isfile(csv_path):
        with open(csv_path) as f:
            for line in f:
                parts = line.strip().split('|')
                if len(parts) == 4:
                    db[parts[0]] = (parts[1], parts[2], parts[3])
    return db


class GameEntry:
    __slots__ = ('title', 'game_id', 'publisher', 'disc_type',
                 'filename', 'jpn_title', 'partition_label', 'file_path')

    def __init__(self, title, game_id, publisher, disc_type,
                 filename, jpn_title, partition_label, file_path):
        self.title = title
        self.game_id = game_id
        self.publisher = publisher
        self.disc_type = disc_type
        self.filename = filename
        self.jpn_title = jpn_title
        self.partition_label = partition_label
        self.file_path = file_path

    @property
    def display_name(self):
        parts = [f"[{self.disc_type}]", self.title]
        if self.game_id:
            parts.append(f"({self.game_id})")
        if self.publisher:
            parts.append(f"· {self.publisher}")
        if self.file_path:
            try:
                size = self.file_path.stat().st_size
                parts.append(f"· {size / 1_000_000_000:.2f} GB")
            except OSError:
                pass
        return " ".join(parts)

    @property
    def pipe_line(self):
        return (f"{self.title}|{self.game_id}|{self.publisher}|"
                f"{self.disc_type}|{self.filename}|"
                f"{self.jpn_title}|{self.partition_label}")

    @property
    def size_gb(self):
        try:
            return self.file_path.stat().st_size / 1_000_000_000 if self.file_path else 0.0
        except OSError:
            return 0.0


def _extract_id_from_image(file_path, image):
    """Try to extract a Game ID from a single image file. Returns ('', image) on failure."""
    ext = image.lower()
    game_id = ""

    # ── from filename if it already looks like a Game ID ──
    name_no_ext = os.path.splitext(image)[0]
    if len(name_no_ext) >= 11 and name_no_ext[4] == '_' and name_no_ext[8] == '.':
        game_id = name_no_ext[:11].upper()

    # ── ISO via SYSTEM.CNF ──
    if ext.endswith('.iso') and not game_id:
        try:
            with open(file_path, "rb") as fin:
                reader = lambda s, n=1: _read_iso_sector(fin, s, n)
                game_id = _extract_game_id_from_disc(fin, reader) or ""
        except Exception:
            game_id = ""

    # ── ZSO via SYSTEM.CNF ──
    if ext.endswith('.zso') and not game_id:
        try:
            with open(file_path, "rb") as fin:
                magic, hdr_sz, total, blk_sz, ver, align = _read_zso_header(fin)
                if magic == ZISO_MAGIC:
                    nblk = total // blk_sz
                    idx = [unpack('I', fin.read(4))[0] for _ in range(nblk + 1)]
                    reader = lambda s, n=1: _decompress_zso_sector(fin, idx, blk_sz, align, s, n)
                    game_id = _extract_game_id_from_disc(fin, reader) or ""
        except Exception:
            game_id = ""

    # ── VCD via cdrom: in header ──
    if ext.endswith('.vcd') and not game_id:
        try:
            with open(file_path, "rb") as f:
                for raw in f:
                    line = raw.strip()
                    low = line.lower()
                    if b'cdrom:' in low and b'boot' in low:
                        seg = line[low.find(b'cdrom:') + 6:].split(b';', 1)[0]
                        g = seg.split(b'\\')[-1].decode('utf-8', errors='ignore').upper()
                        if len(g) == 11:
                            if g.startswith("SLUSP"):
                                g = "SLUS" + g[5:]
                            if g[4] != '_' or g[8] != '.':
                                cleaned = g.replace('_', '').replace('.', '').replace('-', '')
                                g = cleaned[:4] + '_' + cleaned[4:7] + '.' + cleaned[7:]
                            game_id = g
                        break
        except Exception:
            game_id = ""

    # ── fallback binary scan for ISO / VCD ──
    if (len(game_id) < 11 or len(game_id) > 12) and (ext.endswith('.iso') or ext.endswith('.vcd')):
        try:
            with open(file_path, "rb") as f:
                data = f.read()
            idx = 0
            game_id = ""
            for byte in data:
                if len(game_id) < 4:
                    if idx == 2:
                        game_id += chr(byte)
                    elif byte == _PATTERN_1[idx][0]:
                        idx += 1
                    else:
                        game_id = ""
                        idx = 0
                elif len(game_id) == 4:
                    idx = 0
                    if byte in (0x5F, 0x2D):
                        game_id += '_'
                    else:
                        game_id = ""
                elif len(game_id) < 8:
                    game_id += chr(byte)
                elif len(game_id) == 8:
                    if byte == 0x2E:
                        game_id += '.'
                    else:
                        game_id = ""
                elif len(game_id) < 11:
                    game_id += chr(byte)
                elif len(game_id) == 11:
                    if byte == _PATTERN_2[idx][0]:
                        idx += 1
                        if idx == 2:
                            if game_id == "CDDA_END.DA":
                                game_id = ""
                                idx = 0
                                continue
                            break
                    else:
                        game_id = ""
                        idx = 0
        except Exception:
            game_id = ""

    # ── generate from filename as last resort ──
    if not game_id:
        base = re.sub(r'[^A-Z0-9]', '', os.path.splitext(image)[0].upper())
        base = base[:9].ljust(9, '0')
        game_id = (base[:4] + '_' + base[4:7] + '.' + base[7:])[:11]

    return game_id.upper()


def scan_games(games_dir, titles_db_ps2, titles_db_ps1):
    """Scan CD/, DVD/, POPS/ directories and return a list of GameEntry objects."""
    base = Path(games_dir)
    targets = [
        ("CD",   ['.iso', '.zso'],         "CD",   titles_db_ps2),
        ("DVD",  ['.iso', '.zso'],         "DVD",  titles_db_ps2),
        ("POPS", ['.vcd', '.VCD'],         "POPS", titles_db_ps1),
    ]

    game_id_counts = defaultdict(int)
    raw = []  # list of dicts, 1st pass

    for folder, exts, disc_type, db in targets:
        p = base / folder
        if not p.is_dir():
            continue

        for image in sorted(os.listdir(str(p))):
            if image.startswith('.') or not any(image.lower().endswith(e) for e in exts):
                continue

            file_path = p / image
            game_id = _extract_id_from_image(str(file_path), image)

            entry = db.get(game_id)
            if entry:
                game_name, publisher, jpn_title = entry
                if not game_name:
                    game_name = os.path.splitext(image)[0]
                    publisher = ""
                    jpn_title = ""
            else:
                game_name = _clean_name_from_filename(image, game_id)
                publisher = ""
                jpn_title = ""

            game_id_counts[game_id] += 1
            raw.append(dict(game_id=game_id, game_name=game_name,
                            publisher=publisher, disc_type=disc_type,
                            filename=image, jpn_title=jpn_title,
                            file_path=file_path))

    # 2nd pass: build final GameEntry list with partition labels
    game_id_index = defaultdict(int)
    games = []
    for r in raw:
        gid = r["game_id"]
        game_id_index[gid] += 1
        suffix = f"{game_id_index[gid]:02d}"

        if game_id_counts[gid] > 1:
            display_name = _clean_name_from_filename(r["filename"], gid)
        else:
            display_name = r["game_name"]

        label = _make_partition_label(gid, r["game_name"], suffix)

        games.append(GameEntry(
            title=display_name,
            game_id=gid,
            publisher=r["publisher"],
            disc_type=r["disc_type"],
            filename=r["filename"],
            jpn_title=r["jpn_title"],
            partition_label=label,
            file_path=r["file_path"],
        ))

    return games


# ── Textual TUI ─────────────────────────────────────────────────────────

class GameSelector(App[None]):
    BINDINGS = [
        ("up", "list_up", ""),
        ("down", "list_down", ""),
        ("shift+up", "list_sel_up", ""),
        ("shift+down", "list_sel_down", ""),
        ("space", "list_toggle", ""),
        ("ctrl+a", "select_all", "All"),
        ("ctrl+shift+a", "deselect_all", "Clear"),
        ("ctrl+enter", "confirm", "Confirm"),
        ("escape", "cancel", "Cancel"),
    ]

    CSS = """
    Screen {
        background: #0f1117;
        padding: 0 1;
    }
    Header {
        background: #161820;
        color: #868d9e;
        text-style: bold;
    }
    Footer {
        background: #161820;
        color: #868d9e;
    }
    #toolbar {
        height: 3;
        background: #1a1c25;
        padding: 0 1;
    }
    #search {
        width: 1fr;
        height: 3;
        background: #1e2030;
        border: tall #2a2d3e;
        color: #e2e4eb;
    }
    #search:focus {
        background: #282a36;
        border: tall #50fa7b;
    }
    Button {
        background: #1e2030;
        border: none;
        text-style: bold;
    }
    Button:hover {
        background: #282a36;
    }
    #toolbar Button, #buttons Button {
        height: 3;
    }
    #select_all, #deselect_all {
        width: 12;
        margin: 0 0 0 1;
    }
    #select_all {
        color: #50fa7b;
    }
    #deselect_all {
        color: #ff5555;
    }
    #type_info {
        height: 1;
        text-align: center;
        color: #c0c4d0;
        text-style: bold;
    }
    #list_container {
        height: 1fr;
    }
    #game_list {
        height: auto;
        background: #161820;
        border: none;
        text-style: bold;
    }
    #bar_info {
        height: 1;
        text-align: center;
        color: #c0c4d0;
        text-style: bold;
    }
    #buttons {
        height: 3;
    }
    #confirm, #cancel {
        width: 1fr;
    }
    #confirm {
        color: #50fa7b;
    }
    #cancel {
        color: #ff5555;
    }
    """

    def __init__(self, games, output_file=None, disk_total_gb=0.0):
        super().__init__()
        self.games = games
        self.output_file = output_file
        self.disk_total_gb = disk_total_gb or 0.0
        self.selected_indices: set[int] = set()
        self._focus_idx = 0
        self._dt_width = 5  # [PS2] or [PS1]
        self._id_width = max(len(g.game_id) for g in games) if games else 11
        self._visible_ps2 = len(games)
        self._visible_ps1 = 0

    def compose(self):
        yield Header()
        with Horizontal(id="toolbar"):
            yield Input(placeholder="Filter by name or ID...", id="search")
            yield Button("All", id="select_all", variant="primary")
            yield Button("Clear", id="deselect_all")
        yield Static("", id="type_info")
        with VerticalScroll(id="list_container"):
            yield SelectionList[int](id="game_list")
        yield Static("", id="bar_info")
        with Horizontal(id="buttons"):
            yield Button("Confirm", id="confirm", variant="primary")
            yield Button("Cancel", id="cancel")
        yield Footer()

    def on_mount(self):
        self._rebuild_lists()
        self._update_progress()

    @staticmethod
    def _fmt_game_line(g, dt_width, id_width):
        prefix = "PS1" if g.disc_type == "POPS" else "PS2"
        dt = f"[{prefix}]".ljust(dt_width)
        sz = f"{g.size_gb:>6.2f} GB"
        id_ = f"({g.game_id})".ljust(id_width + 2)
        return f"[bold]{dt} \u2502 {sz} \u2502 {id_} \u2502 {g.title}[/]"

    def _list_focused(self) -> bool:
        lst = self.query_one("#game_list", SelectionList)
        if lst.has_focus:
            return True
        for child in lst.children:
            if child.has_focus:
                return True
        return False

    def _scroll_to_focus(self):
        self.query_one("#list_container", VerticalScroll).scroll_to(
            y=self._focus_idx, animate=False
        )

    def action_list_up(self):
        if self._focus_idx > 0:
            self._focus_idx -= 1
            self._scroll_to_focus()

    def action_list_down(self):
        if self._focus_idx < len(self.games) - 1:
            self._focus_idx += 1
            self._scroll_to_focus()

    def action_list_sel_up(self):
        if not self._list_focused() or self._focus_idx < 1:
            return
        self.selected_indices.add(self._focus_idx - 1)
        self._focus_idx -= 1
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()
        self._scroll_to_focus()

    def action_list_sel_down(self):
        if not self._list_focused() or self._focus_idx >= len(self.games) - 1:
            return
        self.selected_indices.add(self._focus_idx + 1)
        self._focus_idx += 1
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()
        self._scroll_to_focus()

    def action_list_toggle(self):
        if not self._list_focused():
            return
        if self._focus_idx in self.selected_indices:
            self.selected_indices.discard(self._focus_idx)
        else:
            self.selected_indices.add(self._focus_idx)
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()
        self._scroll_to_focus()

    def action_select_all(self):
        self.selected_indices = set(range(len(self.games)))
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()

    def action_deselect_all(self):
        self.selected_indices.clear()
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()

    def action_confirm(self):
        chosen = [self.games[i] for i in self.selected_indices]
        if self.output_file:
            with open(self.output_file, "w") as f:
                for g in chosen:
                    f.write(g.pipe_line + "\n")
        else:
            for g in chosen:
                print(g.pipe_line)
        self.exit()

    def action_cancel(self):
        sys.exit(2)

    def _rebuild_lists(self, query: str = ""):
        q = query.strip().lower()
        saved = set(self.selected_indices)
        lst = self.query_one("#game_list", SelectionList)

        self._visible_ps2 = sum(
            1 for i, g in enumerate(self.games) if g.disc_type in ("CD", "DVD")
            and (not q or q in g.title.lower() or q in g.game_id.lower())
        )
        self._visible_ps1 = sum(
            1 for i, g in enumerate(self.games) if g.disc_type == "POPS"
            and (not q or q in g.title.lower() or q in g.game_id.lower())
        )

        self._update_type_info()

        with self.prevent(SelectionList.SelectedChanged):
            lst.clear_options()

            for dt in ("CD", "DVD", "POPS"):
                type_games = [(i, g) for i, g in enumerate(self.games) if g.disc_type == dt]

                filtered = [(i, g) for i, g in type_games
                            if not q or q in g.title.lower() or q in g.game_id.lower()]

                for idx, g in filtered:
                    label = self._fmt_game_line(g, self._dt_width, self._id_width)
                    lst.add_option((label, idx, idx in saved))

    @on(Input.Changed, "#search")
    def on_search(self, event: Input.Changed):
        self._rebuild_lists(event.value)
        self._refresh_ui()

    @on(SelectionList.SelectedChanged)
    def on_selection_changed(self):
        self.selected_indices.clear()
        lst = self.query_one("#game_list", SelectionList)
        self.selected_indices.update(i for i in lst.selected if i >= 0)
        if self.selected_indices:
            self._focus_idx = min(self.selected_indices)
        self._refresh_ui()

    def _refresh_ui(self):
        self._update_type_info()
        self._update_progress()

    def _update_type_info(self):
        sel = len(self.selected_indices)
        total = len(self.games)
        gb = sum(self.games[i].size_gb for i in self.selected_indices)
        self.query_one("#type_info", Static).update(
            f"[#8be9fd]PS2 ({self._visible_ps2})[/]  │  "
            f"[#ffb86c]PS1 ({self._visible_ps1})[/]"
            f"  │  {sel} / {total} games selected  ·  {gb:.2f} GB"
        )

    def _update_progress(self):
        sel_gb = sum(self.games[i].size_gb for i in self.selected_indices)
        sel_gb = min(sel_gb, self.disk_total_gb) if self.disk_total_gb > 0 else sel_gb
        total_gb = self.disk_total_gb
        dsk_pct = (sel_gb / total_gb * 100) if total_gb > 0 else 0
        game_pct = int(len(self.selected_indices) / len(self.games) * 100) if self.games else 0

        prefix = f"{sel_gb:.2f} GB / {total_gb:.2f} GB ({dsk_pct:.1f}%)  |  {game_pct}% "
        bar_w = max(10, self.size.width - len(prefix) - 5) if hasattr(self, 'size') else 20
        filled = min(int(dsk_pct / 100 * bar_w), bar_w)
        bar = "\u2588" * filled + "\u2591" * (bar_w - filled)

        if dsk_pct < 50:
            color = "#50fa7b"
        elif dsk_pct < 80:
            color = "#ffb86c"
        else:
            color = "#ff5555"

        self.query_one("#bar_info", Static).update(
            f"{prefix}[{color}]{bar}[/]"
        )

    @on(Button.Pressed, "#select_all")
    def on_select_all(self):
        self.selected_indices = {i for i, _ in enumerate(self.games)}
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()

    @on(Button.Pressed, "#deselect_all")
    def on_deselect_all(self):
        self.selected_indices.clear()
        self._rebuild_lists(self.query_one("#search", Input).value)
        self._refresh_ui()

    @on(Button.Pressed, "#confirm")
    def on_confirm(self):
        chosen = [self.games[i] for i in self.selected_indices]
        if self.output_file:
            with open(self.output_file, "w") as f:
                for g in chosen:
                    f.write(g.pipe_line + "\n")
        else:
            for g in chosen:
                print(g.pipe_line)
        self.exit()

    @on(Button.Pressed, "#cancel")
    def on_cancel(self):
        sys.exit(2)

    @on(Button.Pressed, "#cancel")
    def on_cancel(self):
        sys.exit(2)


# ── Entry point ─────────────────────────────────────────────────────────

def _load_games_from_lists(list_files):
    """Load GameEntry objects from pipe-delimited list files (PS1_LIST / PS2_LIST format)."""
    games = []
    for lf in list_files:
        try:
            with open(lf) as f:
                for line in f:
                    parts = line.strip().split("|")
                    if len(parts) >= 7:
                        title, game_id, publisher, disc_type, filename, jpn_title, label = parts[:7]
                        games.append(GameEntry(
                            title=title, game_id=game_id, publisher=publisher,
                            disc_type=disc_type, filename=filename,
                            jpn_title=jpn_title, partition_label=label,
                            file_path=None,
                        ))
        except OSError:
            pass
    return games


def main():
    parser = argparse.ArgumentParser(
        description="Scan games folder and interactively select which to install."
    )
    parser.add_argument(
        "--games-dir",
        help="Path to the games folder containing CD/, DVD/, POPS/ subdirectories"
    )
    parser.add_argument(
        "--from-list", action="append", dest="from_lists", default=[],
        help="Read games from a pipe-delimited list file (can be repeated)"
    )
    parser.add_argument(
        "--output",
        help="Write selected games (pipe-delimited) to this file"
    )
    parser.add_argument(
        "--disk-total-gb", type=float, default=0.0,
        help="Total capacity of the target disk in GB (for progress bar)"
    )
    args = parser.parse_args()

    if not args.games_dir and not args.from_lists:
        parser.error("Provide either --games-dir or --from-list (or both).")

    games = []

    if args.from_lists:
        games.extend(_load_games_from_lists(args.from_lists))
        print(f"Loaded {len(games)} game(s) from list files.", file=sys.stderr)

    if args.games_dir:
        script_dir = Path(__file__).resolve().parent
        titles_ps2 = _load_titles_db(str(script_dir / "TitlesDB_PS2.csv"))
        titles_ps1 = _load_titles_db(str(script_dir / "TitlesDB_PS1.csv"))
        scanned = scan_games(args.games_dir, titles_ps2, titles_ps1)
        # Union with dedup by game_id (will only trigger if both --from-list and --games-dir given)
        seen = {g.game_id for g in games}
        for g in scanned:
            if g.game_id not in seen:
                seen.add(g.game_id)
                games.append(g)

    if not games:
        print("No games found.", file=sys.stderr)
        sys.exit(0)

    if not sys.stdout.isatty() or not sys.stdin.isatty():
        print("ERROR: Terminal is not fully interactive (stdout TTY:", sys.stdout.isatty(), "stdin TTY:", sys.stdin.isatty(), ")", file=sys.stderr)
        print("ERROR: Terminal is not fully interactive. Cannot open the game selector.", file=sys.stdout)
        sys.exit(1)

    try:
        app = GameSelector(games, args.output, args.disk_total_gb)
        app.run()
    except Exception as exc:
        print(f"ERROR: Game selector failed: {exc}", file=sys.stderr)
        print(f"ERROR: Game selector failed: {exc}", file=sys.stdout)
        sys.exit(1)


if __name__ == "__main__":
    main()

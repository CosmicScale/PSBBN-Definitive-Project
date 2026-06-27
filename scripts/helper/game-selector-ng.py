#!/usr/bin/env python3
#
# Game Selector NG - Alternative GUI using tkinter
# Copyright (C) 2024-2026 CosmicScale
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Alternative game selector with tkinter GUI.

Same functionality as game-selector.py (Textual TUI), using the
same game-scanning engine imported from that module.
Requires no external dependencies beyond Python stdlib + lz4.
"""

import importlib.util
import sys
import argparse
from pathlib import Path
import tkinter as tk
from tkinter import ttk

# ── Import engine from sibling game-selector.py ──────────────────────────
_ENGINE_PATH = Path(__file__).resolve().parent / "game-selector.py"
_SPEC = importlib.util.spec_from_file_location("_gs_engine", _ENGINE_PATH)
_ENGINE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_ENGINE)

GameEntry = _ENGINE.GameEntry
scan_games = _ENGINE.scan_games
_load_titles_db = _ENGINE._load_titles_db
_load_games_from_lists = _ENGINE._load_games_from_lists


# ── tkinter GUI ──────────────────────────────────────────────────────────

class GameSelectorNG:
    def __init__(self, games, output_file=None, disk_total_gb=0.0):
        self.games = games
        self.output_file = output_file
        self.disk_total_gb = disk_total_gb or 0.0
        self.selected_indices: set[int] = set()
        self._mapping: list[int] = []
        self._rebuilding = False
        self._visible_ps2 = 0
        self._visible_ps1 = 0

        self._dt_width = 5
        self._id_width = max(len(g.game_id) for g in games) if games else 11

        self.root = tk.Tk()
        self.root.title("Game Selector NG")
        self.root.configure(bg="#0f1117")
        self.root.minsize(640, 300)
        self.root.after(10, self._maximize)

        self._setup_styles()
        self._build_ui()
        self._rebuild_list()
        self._update_info()

    def _maximize(self):
        try:
            self.root.state("zoomed")
        except tk.TclError:
            w = self.root.winfo_screenwidth()
            h = self.root.winfo_screenheight()
            self.root.geometry(f"{w}x{h}+0+0")

    # ── helpers ──────────────────────────────────────────────────────

    def _fmt_game_line(self, g):
        prefix = "PS1" if g.disc_type == "POPS" else "PS2"
        dt = f"[{prefix}]".ljust(self._dt_width)
        sz = f"{g.size_gb:>6.2f} GB"
        id_ = f"({g.game_id})".ljust(self._id_width + 2)
        return f"{dt} \u2502 {sz} \u2502 {id_} \u2502 {g.title}"

    # ── styles ───────────────────────────────────────────────────────

    def _setup_styles(self):
        style = ttk.Style()
        style.theme_use("clam")

        style.configure(".", background="#0f1117", foreground="#e2e4eb")
        style.configure("TFrame", background="#0f1117")
        style.configure("TLabel", background="#0f1117", foreground="#c0c4d0")
        style.configure(
            "TEntry",
            fieldbackground="#1e2030",
            foreground="#e2e4eb",
            insertcolor="#e2e4eb",
            borderwidth=0,
        )
        style.map("TEntry", fieldbackground=[("focus", "#282a36")])
        for name, fg in [("Green.TButton", "#50fa7b"), ("Red.TButton", "#ff5555"),
                         ("Success.TButton", "#50fa7b"), ("Danger.TButton", "#ff5555")]:
            style.configure(
                name,
                background="#1a1c25",
                foreground=fg,
                borderwidth=0,
                focuscolor="none",
            )
            style.map(name, background=[("active", "#282a36")])
        style.configure(
            "green.Horizontal.TProgressbar",
            troughcolor="#1a1c25", background="#50fa7b", borderwidth=0,
        )
        style.configure(
            "yellow.Horizontal.TProgressbar",
            troughcolor="#1a1c25", background="#ffb86c", borderwidth=0,
        )
        style.configure(
            "red.Horizontal.TProgressbar",
            troughcolor="#1a1c25", background="#ff5555", borderwidth=0,
        )

    # ── UI construction ──────────────────────────────────────────────

    def _build_ui(self):
        # header
        header = tk.Label(
            self.root, text="Game Selector NG",
            bg="#161820", fg="#868d9e", anchor="w", padx=10, pady=4,
        )
        header.pack(fill=tk.X)

        # search toolbar
        search_frame = tk.Frame(self.root, bg="#1a1c25")
        search_frame.pack(fill=tk.X)

        self.search_var = tk.StringVar()
        search_entry = ttk.Entry(
            search_frame, textvariable=self.search_var, style="TEntry"
        )
        search_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(8, 4), pady=4)

        ttk.Button(
            search_frame, text="All", style="Green.TButton",
            command=self._on_select_all,
        ).pack(side=tk.LEFT, padx=1, pady=4)

        ttk.Button(
            search_frame, text="Clear", style="Red.TButton",
            command=self._on_deselect_all,
        ).pack(side=tk.LEFT, padx=(1, 8), pady=4)

        self.search_var.trace_add("write", self._on_search)

        # type / selection info
        self.info_var = tk.StringVar()
        tk.Label(
            self.root, textvariable=self.info_var,
            bg="#0f1117", fg="#c0c4d0", anchor="center", pady=2,
        ).pack(fill=tk.X)

        # game list
        list_frame = tk.Frame(self.root, bg="#161820")
        list_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=(0, 4))

        self.listbox = tk.Listbox(
            list_frame,
            selectmode=tk.EXTENDED,
            font=("Courier", 10),
            bg="#161820", fg="#c0c4d0",
            selectbackground="#282a36", selectforeground="#e2e4eb",
            relief=tk.FLAT, borderwidth=0, highlightthickness=0,
            activestyle="underline",
        )
        self.listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.listbox.bind("<<ListboxSelect>>", self._on_select)

        scrollbar = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.listbox.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.listbox.configure(yscrollcommand=scrollbar.set)

        # progress
        progress_frame = tk.Frame(self.root, bg="#0f1117")
        progress_frame.pack(fill=tk.X, padx=8, pady=(0, 4))

        self.progress_text = tk.StringVar()
        tk.Label(
            progress_frame, textvariable=self.progress_text,
            bg="#0f1117", fg="#c0c4d0", anchor="w",
        ).pack(side=tk.LEFT)

        self.progress_bar = ttk.Progressbar(
            progress_frame, mode="determinate",
        )
        self.progress_bar.pack(side=tk.RIGHT, fill=tk.X, expand=True, padx=(8, 0))

        # bottom buttons
        btn_frame = tk.Frame(self.root, bg="#0f1117")
        btn_frame.pack(fill=tk.X, padx=8, pady=(0, 8))

        ttk.Button(
            btn_frame, text="Confirm", style="Success.TButton",
            command=self._on_confirm,
        ).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))

        ttk.Button(
            btn_frame, text="Cancel", style="Danger.TButton",
            command=self._on_cancel,
        ).pack(side=tk.RIGHT, fill=tk.X, expand=True, padx=(4, 0))

        # key bindings
        self.root.bind("<Control-f>", lambda e: search_entry.focus_set())
        self.root.bind("<Control-a>", lambda e: self._on_select_all())
        self.root.bind("<Control-Shift-a>", lambda e: self._on_deselect_all())
        self.root.bind("<Control-Shift-A>", lambda e: self._on_deselect_all())
        self.root.bind("<Escape>", lambda e: self._on_cancel())
        self.root.bind("<Return>", lambda e: self._on_confirm())

    # ── list management ──────────────────────────────────────────────

    def _rebuild_list(self, query=""):
        self._rebuilding = True
        q = query.strip().lower()
        self._mapping.clear()
        self.listbox.delete(0, tk.END)

        self._visible_ps2 = 0
        self._visible_ps1 = 0

        for i, g in enumerate(self.games):
            if q and q not in g.title.lower() and q not in g.game_id.lower():
                continue
            if g.disc_type in ("CD", "DVD"):
                self._visible_ps2 += 1
            else:
                self._visible_ps1 += 1
            self._mapping.append(i)
            self.listbox.insert(tk.END, self._fmt_game_line(g))

        self.listbox.selection_clear(0, tk.END)
        for disp_idx, game_idx in enumerate(self._mapping):
            if game_idx in self.selected_indices:
                self.listbox.selection_set(disp_idx)

        self._rebuilding = False
        self._update_info()

    # ── event handlers ───────────────────────────────────────────────

    def _on_search(self, *_):
        self._rebuild_list(self.search_var.get())

    def _on_select(self, event=None):
        if self._rebuilding:
            return
        selected: set[int] = set()
        for disp_idx in self.listbox.curselection():
            if disp_idx < len(self._mapping):
                selected.add(self._mapping[disp_idx])
        self.selected_indices = selected
        self._update_info()

    def _on_select_all(self):
        self.selected_indices = set(range(len(self.games)))
        self._rebuild_list(self.search_var.get())

    def _on_deselect_all(self):
        self.selected_indices.clear()
        self._rebuild_list(self.search_var.get())

    def _on_confirm(self):
        chosen = [self.games[i] for i in sorted(self.selected_indices)]
        if self.output_file:
            with open(self.output_file, "w") as f:
                for g in chosen:
                    f.write(g.pipe_line + "\n")
        else:
            for g in chosen:
                print(g.pipe_line)
        self.root.quit()

    def _on_cancel(self):
        sys.exit(2)

    # ── info / progress ──────────────────────────────────────────────

    def _update_info(self):
        sel = len(self.selected_indices)
        total = len(self.games)
        gb = sum(self.games[i].size_gb for i in self.selected_indices)

        self.info_var.set(
            f"PS2 ({self._visible_ps2})  \u2502  PS1 ({self._visible_ps1})"
            f"  \u2502  {sel} / {total} games selected  \u00b7  {gb:.2f} GB"
        )
        self._update_progress()

    def _update_progress(self):
        sel_gb = sum(self.games[i].size_gb for i in self.selected_indices)
        sel_gb = min(sel_gb, self.disk_total_gb) if self.disk_total_gb > 0 else sel_gb
        total_gb = self.disk_total_gb
        dsk_pct = (sel_gb / total_gb * 100) if total_gb > 0 else 0
        game_pct = int(len(self.selected_indices) / len(self.games) * 100) if self.games else 0

        if dsk_pct < 50:
            bar_style = "green.Horizontal.TProgressbar"
        elif dsk_pct < 80:
            bar_style = "yellow.Horizontal.TProgressbar"
        else:
            bar_style = "red.Horizontal.TProgressbar"

        text = f"{sel_gb:.2f} GB / {total_gb:.2f} GB ({dsk_pct:.1f}%)  |  {game_pct}%"
        self.progress_text.set(text)
        self.progress_bar["value"] = dsk_pct
        self.progress_bar.configure(style=bar_style)

    def run(self):
        self.root.mainloop()


# ── CLI ──────────────────────────────────────────────────────────────────

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
        seen = {g.game_id for g in games}
        for g in scanned:
            if g.game_id not in seen:
                seen.add(g.game_id)
                games.append(g)

    if not games:
        print("No games found.", file=sys.stderr)
        sys.exit(0)

    if not sys.stdout.isatty() or not sys.stdin.isatty():
        print("ERROR: Terminal is not fully interactive.", file=sys.stderr)
        sys.exit(1)

    try:
        app = GameSelectorNG(games, args.output, args.disk_total_gb)
        app.run()
    except Exception as exc:
        print(f"ERROR: Game selector failed: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
#
# Game Selector for the PSBBN Definitive Project
# Copyright (C) 2024-2026 CosmicScale
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Interactive game selector with multiselect and progress bar using Textual."""

import sys
import argparse
from pathlib import Path

from textual.app import App, ComposeResult
from textual.widgets import SelectionList, ProgressBar, Button, Header, Footer, Static
from textual.containers import Horizontal
from textual import on


class GameSelector(App[None]):
    """Interactive game selector using Textual TUI.

    Provides a multiselect list with checkboxes and a live progress bar
    that updates as games are selected. Selected games are written to output file.
    The progress bar shows the total size of selected games vs the disk capacity.
    """

    CSS = """
    ProgressBar {
        height: 1;
        margin: 1;
    }
    ProgressBar.green .progress--bar { background: green; }
    ProgressBar.blue .progress--bar { background: blue; }
    ProgressBar.yellow .progress--bar { background: yellow; }
    ProgressBar.red .progress--bar { background: red; }
    SelectionList {
        height: 1fr;
    }
    #status {
        padding: 0 1;
    }
    #progress_label {
        padding: 0 1;
        text-align: center;
    }
    """

    def __init__(
        self,
        list_files: list[str],
        output_file: str | None = None,
        disk_total_gb: float = 0.0,
        games_dir: str = "games",
    ) -> None:
        super().__init__()
        self.list_files = list_files
        self.games: list[tuple[str, str]] = []
        self.game_sizes_gb: list[float] = []
        self.output_file = output_file
        self.disk_total_gb = disk_total_gb
        self.games_dir = Path(games_dir)
        self._load_games()

    def _get_file_path(self, file_name: str) -> Path | None:
        """Find the full path to a game file in CD/, DVD/, or POPS/ subdirectories."""
        for subdir in ["CD", "DVD", "POPS"]:
            path = self.games_dir / subdir / file_name
            if path.exists():
                return path
        return None

    def _load_games(self) -> None:
        """Load games from pipe-delimited list files and cache file sizes."""
        for list_file in self.list_files:
            path = Path(list_file)
            if not path.is_file():
                continue
            try:
                for line in path.read_text(encoding="utf-8").splitlines():
                    line = line.strip()
                    if not line:
                        continue
                    parts = line.split("|")
                    if len(parts) >= 5:
                        title = parts[0]
                        game_id = parts[1]
                        game_type = parts[3]
                        file_name = parts[4]
                        display = f"[{game_type}] {title} ({game_id})"
                        self.games.append((display, line))

                        file_path = self._get_file_path(file_name)
                        if file_path and file_path.exists():
                            size_gb = file_path.stat().st_size / 1e9
                        else:
                            size_gb = 0.0
                        self.game_sizes_gb.append(size_gb)
                    elif parts:
                        display = line
                        self.games.append((display, line))
                        self.game_sizes_gb.append(0.0)
            except (OSError, UnicodeDecodeError) as e:
                print(f"Warning: Could not read {list_file}: {e}", file=sys.stderr)

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(f"Total: {len(self.games)} games", id="status")
        game_options: list[tuple[str, int]] = [
            (display, idx) for idx, (display, _) in enumerate(self.games)
        ]
        yield SelectionList[int](*game_options, id="game_list")
        yield ProgressBar(total=self.disk_total_gb, id="progress")
        yield Static("", id="progress_label")
        with Horizontal():
            yield Button("Confirmar", id="confirm", variant="primary")
            yield Button("Cancelar", id="cancel")
        yield Footer()

    def _get_progress_color_class(self, percentage: float) -> str:
        """Return CSS class name based on danger percentage thresholds."""
        if percentage < 25:
            return "green"
        elif percentage < 50:
            return "blue"
        elif percentage < 60:
            return "yellow"
        else:
            return "red"

    @on(SelectionList.SelectedChanged)
    def on_selection_changed(self) -> None:
        """Update progress bar and label when selection changes."""
        progress_bar = self.query_one("#progress", ProgressBar)
        selection_list = self.query_one("#game_list", SelectionList)
        selected_indices = list(selection_list.selected)

        selected_gb = sum(self.game_sizes_gb[idx] for idx in selected_indices)
        selected_gb = min(selected_gb, self.disk_total_gb)

        progress_bar.update(progress=selected_gb, total=self.disk_total_gb)

        percentage = (selected_gb / self.disk_total_gb * 100) if self.disk_total_gb > 0 else 0
        color_class = self._get_progress_color_class(percentage)
        progress_bar.remove_class("green", "blue", "yellow", "red")
        progress_bar.add_class(color_class)

        label = self.query_one("#progress_label", Static)
        label.update(
            f"Selected: {selected_gb:.2f} GB / Total: {self.disk_total_gb:.2f} GB ({percentage:.1f}%)"
        )

        self.selected_indices = selected_indices

    @on(Button.Pressed, "#confirm")
    def on_confirm(self) -> None:
        """Write selected games to output file and exit."""
        selection_list = self.query_one("#game_list", SelectionList)
        selected_lines = [self.games[idx][1] for idx in selection_list.selected]
        if self.output_file:
            with open(self.output_file, "w") as f:
                for line in selected_lines:
                    f.write(line + "\n")
        else:
            for line in selected_lines:
                print(line)
        self.exit()

    @on(Button.Pressed, "#cancel")
    def on_cancel(self) -> None:
        """Exit without writing anything."""
        self.exit()


def main() -> None:
    """Parse arguments and run the Game Selector app."""
    parser = argparse.ArgumentParser(description="Interactive game selector with multiselect")
    parser.add_argument("list_files", nargs="+", help="Game list files (pipe-delimited)")
    parser.add_argument("--output", dest="output_file", help="Output file for selected games")
    parser.add_argument(
        "--disk-total-gb",
        type=float,
        required=True,
        help="Total capacity of the target installation disk in GB",
    )
    parser.add_argument(
        "--games-dir",
        type=str,
        default="games",
        help="Base directory for game files (default: games)",
    )
    args = parser.parse_args()
    app = GameSelector(
        args.list_files,
        args.output_file,
        disk_total_gb=args.disk_total_gb,
        games_dir=args.games_dir,
    )
    app.run()


if __name__ == "__main__":
    main()

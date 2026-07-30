#!/usr/bin/env python3

"""
Game Selector form the PSBBN Definitive Project
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

import argparse
from pathlib import Path
from wcwidth import wcswidth
from rich.text import Text
from textual.app import App, ComposeResult
from textual.widgets import SelectionList, Button, Static
from textual.widgets._selection_list import Selection
from textual.containers import Horizontal, Vertical, Container, ScrollableContainer
from textual.message import Message

# ---------------- LANGUAGE LOADING ----------------

def load_language(lang: str) -> dict[str, str]:
    lang_file = Path(f"./scripts/assets/lang/{lang}.txt")

    if not lang_file.is_file():
        raise FileNotFoundError(f"Language file not found: {lang_file}")

    strings = {}

    for line in lang_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()

        if not line or "=" not in line:
            continue

        key, value = line.split("=", 1)
        strings[key.strip()] = value.strip()

    return strings

def fit_text(text: str, width: int) -> str:
    available = width - 1

    if wcswidth(text) > available:
        while wcswidth(text + "...") > available - 1:
            text = text[:-1]

        text = text.rstrip()
        text += "..."

    padding = max(0, available - wcswidth(text))

    return text + (" " * (padding + 1))

# ---------------- DATA LOADING ----------------

def parse(data, lang):
    ps1, ps2 = [], []
    apps, launchers, smb = [], [], []

    for line in data.splitlines():
        parts = line.split("|")

        fallback_title = parts[0]
        title_id = parts[1].strip()
        media = parts[3].strip()

        using_jpn_title = (
            lang == "jpn"
            and len(parts) > 5
            and parts[5].strip()
        )

        title = parts[5].strip() if using_jpn_title else fallback_title

        display_title = f"{fit_text(title, 87)}{title_id}"

        item = (display_title, line)

        if media == "INC":
            launchers.append(item)
        elif media == "APP":
            apps.append(item)
        elif media in ("DVD", "CD"):
            ps2.append(item)
        elif media in ("POPS", "__.POPS"):
            ps1.append(item)
        elif media == "SMB":
            smb.append(item)

    return ps1, ps2, apps, launchers, smb

def load_exclusions(path):
    excluded = set()
    section_order = []

    if not path:
        return excluded, section_order

    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if line.startswith("#SECTION_ORDER="):
                    section_order = (
                        line.replace("#SECTION_ORDER=", "")
                        .split(",")
                    )
                elif line:
                    excluded.add(line)

    except FileNotFoundError:
        pass

    return excluded, section_order


class ClickableStatic(Static):
    can_focus = True

    class Clicked(Message):
        def __init__(self, widget: "ClickableStatic") -> None:
            super().__init__()
            self.widget = widget

    def on_click(self) -> None:
        self.post_message(self.Clicked(self))

def load_data(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read().strip()
    
# ---------------- UI ----------------

class GameSelector(App):

    CSS = """
    Screen {
        layout: vertical;
        background: $background;
        color: $text;
    }

    #title_bar {
        width: 100%;
        text-align: center;
        text-style: bold;
        background: $panel;
        color: $text;
        padding: 0 1;
        margin-bottom: 1;
    }

    SelectionList {
        height: auto;
        min-height: 1;
        padding: 0;
        margin: 0;
    }

    SelectionList .option-list--option-highlighted {
        background: transparent;
    }

    #header {
        height: auto;
        max-height: 10;
        padding: 0 1;
        align: center middle;
        text-align: center;
    }

    #header Horizontal {
        height: 1;
        width: 100%;
    }

    #header Horizontal Static:first-child {
        width: auto;
    }

    #selected_count {
        width: 1fr;
        text-align: right;
    }

    #header Static {
        height: auto;
    }

    #buttons {
        height: auto;
        padding: 0;
        align: center middle;
    }

    #list_frame {
        height: 1fr;
        border: round $panel;
        padding: 0;
    }

    .section {
        width: 100%;
        height: auto;
        margin: 0;
        padding: 0;
    }

    .section_header {
        width: 100%;
        height: 3;
        min-height: 3;
        padding: 0;
        margin: 0;
        align: left middle;
    }

    .title {
        width: 1fr;
        padding: 0 1;
        text-style: bold;
        color: $text;
    }

    .move_btn {
        width: 3;
        height: 1;
        min-width: 3;
        min-height: 1;
        content-align: center middle;
        padding: 0;
    }

    #title_counts {
        width: 100%;
        height: 1;
    }

    #title_counts Static:first-child {
        width: auto;
    }

    #selected_count {
        width: 1fr;
        text-align: right;
    }

    """

    def __init__(
        self,
        games_file,
        exclude_file=None,
        max_games=None,
        lang: str = "eng",
    ):
        super().__init__()

        self.games_file = games_file
        self.exclude_file = exclude_file
        self.max_games = max_games
        self.lang = lang.lower()
        self.lang_strings = load_language(self.lang)

        (
            self.excluded_games,
            self.section_order,
        ) = load_exclusions(exclude_file)

    # ---------------- TRANSLATION ----------------

    def tr(self, key: str) -> str:
        return self.lang_strings.get(key, key)

    def compose(self) -> ComposeResult:
        with Vertical(id="header"):
            yield Static(
                self.tr("GAME_SELECTOR_1"),
                id="title_bar",
            )

            yield Static(
                f"{self.tr('GAME_SELECTOR_2')}\n"
                f"{self.tr('GAME_SELECTOR_3')}\n"
                f"{self.tr('GAME_SELECTOR_4')}"
                "\n",
            )

            with Horizontal(id="title_counts"):
                self.file_count = Static(
                    "",
                )
                yield self.file_count

                self.selected_count = Static(
                    "",
                    id="selected_count",
                )
                yield self.selected_count

        self.sections_container = ScrollableContainer(
            id="list_frame"
        )
        yield self.sections_container

        with Horizontal(id="buttons"):
            yield Button(
                self.tr("GAME_SELECTOR_12"),
                id="confirm",
                variant="primary",
            )

    # ---------------- INIT ----------------

    def on_mount(self):
        raw = load_data(self.games_file)

        line_count = len(raw.splitlines())

        self.file_count.update(
            f"{self.tr('GAME_SELECTOR_5')} {line_count}"
        )

        (
            self.ps1,
            self.ps2,
            self.apps,
            self.launchers,
            self.smb,
        ) = parse(raw, self.lang)

        self.section_widgets = {}

        sections = {
            "ps2": (f"🎮 {self.tr('GAME_SELECTOR_7')}", self.ps2),
            "ps1": (f"🎮 {self.tr('GAME_SELECTOR_8')}", self.ps1),
            "smb": (f"🔗 {self.tr('GAME_SELECTOR_9')}", self.smb),
            "launchers": (f"🚀 {self.tr('GAME_SELECTOR_10')}", self.launchers),
            "apps": (f"🔧 {self.tr('GAME_SELECTOR_11')}", self.apps),
        }

        # Use saved order if available
        if self.section_order:
            section_ids = list(self.section_order)

            # Add any new sections that were not present in the saved order
            for section_id in sections:
                if section_id not in section_ids:
                    section_ids.append(section_id)

        else:
            section_ids = list(sections.keys())


        for section_id in section_ids:
            if section_id not in sections:
                continue

            title, items = sections[section_id]

            if not items:
                continue

            self.create_section(
                section_id,
                title,
                items,
                locked=(section_id == "launchers"),
            )

        self.enforce_initial_max_games()

        self.call_after_refresh(self.update_selected_count)

    # ---------------- SECTIONS ----------------

    def create_section(
        self,
        section_id,
        title,
        items,
        locked=False,
    ):
        selection_list = SelectionList[str]()

        for game_title, raw in items:
            selection_list.add_option(
                Selection(
                    Text(game_title),
                    raw,
                    initial_state=(
                        True
                        if locked
                        else raw not in self.excluded_games
                    ),
                )
            )

        if locked:
            selection_list.disabled = True

        header_children = [
            Static(
                title,
                classes="title",
            )
        ]

        if not locked:
            header_children.append(
                ClickableStatic(
                    "☑",
                    id=f"select_{section_id}",
                    classes="move_btn",
                )
            )

        header_children.extend(
            [
                ClickableStatic(
                    "▲",
                    id=f"up_{section_id}",
                    classes="move_btn",
                ),
                ClickableStatic(
                    "▼",
                    id=f"down_{section_id}",
                    classes="move_btn",
                ),
            ]
        )

        header = Horizontal(
            *header_children,
            classes="section_header",
        )

        section = Container(
            header,
            selection_list,
            classes="section",
        )

        self.section_widgets[section_id] = section

        self.sections_container.mount(section)

        if not locked:
            self.call_after_refresh(
                self.update_select_button,
                section_id,
            )

    # ---------------- SELECTION COUNTS ----------------

    def get_total_selected_count(self):
        total = 0

        for section in self.sections_container.children:
            for child in section.children:
                if isinstance(child, SelectionList):
                    total += len(child.selected)

        return total
    
    def get_selected_status_icon(self):
        selected = self.get_total_selected_count()

        if self.max_games is not None and selected >= self.max_games:
            return "🔴"
        elif selected > 500:
            return "🟡"
        return "🟢"
    
    def update_selected_count(self):
        icon = self.get_selected_status_icon()
        selected = self.get_total_selected_count()

        if self.max_games is None:
            self.selected_count.update(
                f"{icon} {self.tr('GAME_SELECTOR_6')} {selected}"
            )
        else:
            self.selected_count.update(
                f"{icon} {self.tr('GAME_SELECTOR_6')} {selected}/{self.max_games}"
            )

    def enforce_initial_max_games(self):
        if self.max_games is None:
            return

        total_selected = self.get_total_selected_count()

        if total_selected <= self.max_games:
            return

        remaining_to_remove = (
            total_selected - self.max_games
        )

        sections = list(
            self.sections_container.children
        )

        for section in reversed(sections):

            if section == self.section_widgets.get(
                "launchers"
            ):
                continue

            selection_list = next(
                (
                    child
                    for child in section.children
                    if isinstance(
                        child,
                        SelectionList,
                    )
                ),
                None,
            )

            if selection_list is None:
                continue

            selected_values = list(
                selection_list.selected
            )

            for value in reversed(selected_values):

                if remaining_to_remove <= 0:
                    return

                selection_list.deselect(value)
                remaining_to_remove -= 1

    def can_select_more(self):
        if self.max_games is None:
            return True

        return (
            self.get_total_selected_count()
            < self.max_games
        )    

    # ---------------- SELECT ALL / TOGGLE SECTION ----------------

    def toggle_section_selection(self, section_id):
        section = self.section_widgets[section_id]

        selection_list = None

        for child in section.children:
            if isinstance(child, SelectionList):
                selection_list = child
                break

        if selection_list is None:
            return

        has_selected = bool(selection_list.selected)

        if has_selected:
            selection_list.deselect_all()
        else:
            for option in selection_list.options:

                if option.value in selection_list.selected:
                    continue

                if not self.can_select_more():
                    break

                selection_list.select(option.value)

        self.update_select_button(section_id)
        self.update_selected_count()

    def update_select_button(self, section_id):
        section = self.section_widgets[section_id]

        for child in section.children:
            if isinstance(child, SelectionList):

                button = self.query_one(
                    f"#select_{section_id}",
                    ClickableStatic,
                )

                button.update(
                    "☐"
                    if child.selected
                    else "☑"
                )

    # ---------------- SECTION REORDERING ----------------

    def move_section(self, section_id: str, direction: int):
        section = self.section_widgets[section_id]

        children = list(self.sections_container.children)

        current = children.index(section)
        target = current + direction

        if not (0 <= target < len(children)):
            return

        target_widget = children[target]

        if direction < 0:
            self.sections_container.move_child(
                section,
                before=target_widget,
            )
        else:
            self.sections_container.move_child(
                section,
                after=target_widget,
            )

    # ---------------- EXPORT ----------------

    def export(self):
        selected = []
        excluded = []

        for section in self.sections_container.children:
            for child in section.children:
                if not isinstance(child, SelectionList):
                    continue

                selected_set = set(child.selected)

                for option in child.options:
                    value = option.value

                    if value in selected_set:
                        selected.append(value)
                    else:
                        excluded.append(value)

        section_order = []

        for section in self.sections_container.children:
            for section_id, widget in self.section_widgets.items():
                if widget == section:
                    section_order.append(section_id)

        output_file = Path(self.games_file).parent / "selected.list"

        with open(
            output_file,
            "w",
            encoding="utf-8",
        ) as f:
            if selected:
                f.write("\n".join(selected) + "\n")

        if self.exclude_file:
            with open(
                self.exclude_file,
                "w",
                encoding="utf-8",
            ) as f:
                f.write(
                    "#SECTION_ORDER="
                    + ",".join(section_order)
                    + "\n"
                )

                if excluded:
                    f.write("\n")
                    f.write("\n".join(excluded))

        self.exit()

    # ---------------- EVENTS ----------------

    def on_button_pressed(self, event: Button.Pressed):
        if event.button.id == "confirm":
            self.export()

        self.set_focus(None)


    def on_clickable_static_clicked(
        self,
        event: ClickableStatic.Clicked,
    ):
        widget_id = event.widget.id

        if widget_id.startswith("select_"):
            self.toggle_section_selection(
                widget_id[7:]
            )

        elif widget_id.startswith("up_"):
            self.move_section(
                widget_id[3:],
                -1,
            )

        elif widget_id.startswith("down_"):
            self.move_section(
                widget_id[5:],
                1,
            )

        self.set_focus(None)

    def on_selection_list_selection_toggled(
        self,
        event: SelectionList.SelectionToggled,
    ):
        if self.max_games is not None:

            if (
                event.selection.value
                in event.selection_list.selected
            ):
                if (
                    self.get_total_selected_count()
                    > self.max_games
                ):
                    event.selection_list.deselect(
                        event.selection.value
                    )
                    return

        for section_id, section in self.section_widgets.items():
            if event.selection_list in section.children:
                self.update_select_button(section_id)
                self.update_selected_count()
                break

# ---------------- COMMAND LINE ENTRY ----------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="PSBBN Game Collection selector"
    )

    parser.add_argument(
        "file",
        help="Input game list file",
    )

    parser.add_argument(
        "--exclude-file",
        help="File containing games that should start unchecked",
    )

    parser.add_argument(
    "--max-games",
    type=int,
    help=(
        "Maximum number of checked items "
        "allowed across all sections"
    ),
    )

    parser.add_argument("--lang", default="eng")

    args = parser.parse_args()

    GameSelector(
        games_file=args.file,
        exclude_file=args.exclude_file,
        max_games=args.max_games,
        lang=args.lang,
    ).run()
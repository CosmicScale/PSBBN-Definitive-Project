#!/usr/bin/env python3

"""
List Sorter form the PSBBN Definitive Project
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
import unicodedata
import re
from natsort import natsorted

# Function to normalize text by removing diacritical marks and converting to ASCII
def normalize_text(text):
    return ''.join(c for c in unicodedata.normalize('NFD', text) if unicodedata.category(c) != 'Mn')

# Main function to sort the games list
def sort_games_list(games_list_path):

    # Read the games list into a list of lines
    with open(games_list_path, 'r') as file:
        lines = file.readlines()

    def sort_key(line):
        fields = line.strip().split('|')
        first_field = fields[0].strip()
        game_id = fields[1].strip() if len(fields) > 1 else ""

        # Clean the raw title *before* doing overrides
        key = first_field.lower()

        # Apply early overrides BEFORE removing parentheses
        early_overrides = {
            "metal gear solid 3: snake eater": "metal gear solid 3a",
            "metal gear solid 3: subsistence (disc 1) (subsistence)": "metal gear solid 3a",
            "metal gear solid 3: subsistence (disc 1) (subsistence) (shokai seisanban)": "metal gear solid 3a",
            "metal gear solid 3: subsistence (disc 2) (persistence)": "metal gear solid 3b",
            "metal gear solid 3: subsistence (disc 2) (persistence) (shokai seisanban)": "metal gear solid 3b",
            "metal gear solid 3: subsistence (disc 3) (existence)": "metal gear solid 3c",
            "metal gear solid 3: subsistence (disc 3) (existence) (shokai seisanban)": "metal gear solid 3c",
            "metal gear solid 3: subsistence (disc 3) (existence) (limited edition)": "metal gear solid 3c",
        }
        if key in early_overrides:
            key = early_overrides[key]

        # Remove anything in parentheses (e.g., (Demo))
        if '(' in key:
            key = key.split('(')[0].strip()

        # Remove leading "the "
        if key.startswith("the "):
            key = key[4:].strip()

        # Apply override if found after cleaning
        overrides = {
            "jak and daxter: the precursor legacy": "jak",
            "ratchet: deadlocked": "ratchet & clank",
            "ratchet: gladiator": "ratchet & clank",
            "secret agent clank": "ratchet & clank",
            "sly cooper and the thievius raccoonus": "sly",
            "document of metal gear solid 2": "metal gear solid 2",
            "forbidden siren": "siren",
            "forbidden siren 2": "siren 2",
            "we love katamari": "katamari damacy 2",
            "final fantasy x international": "final fantasy 10",
            "final fantasy x international": "final fantasy 10",
            "final fantasy x-2 international + last mission": "final fantasy 10b",
            "final fantasy x-2": "final fantasy 10b",
            "crash bandicoot: warped": "crash bandicoot 3",
            "crash twinsanity": "crash bandicoot 5",
            "crash of the titans": "crash bandicoot 6",
            "crash: mind over mutant": "crash bandicoot 7",
            "crash bandicoot: bakusou! nitro kart": "crash nitro kart",
            "crash bandicoot: gatchanko world": "crash tag team racing",
            "zone of the enders: the 2nd runner": "zone of the enders 2",
            "timesplitters: future perfect": "timesplitters 3",
            "timesplitter: jikuu no shinryakusha": "timesplitters 2",
            "burnout revenge": "burnout 4",
            "burnout dominator": "burnout 5",
            "grand theft auto iii": "grand theft auto 3",
            "grand theft auto: vice city": "grand theft auto 4",
            "grand theft auto: san andreas": "grand theft auto 5",
            "grand theft auto: liberty city stories": "grand theft auto 6",
            "grand theft auto: vice city stories": "grand theft auto 7",
            "silent hill origins": "silent hill 5",
            "silent hill: shattered memories": "silent hill 6",
            "ultimate spider-man": "spider-man 2b",
            "spider-man: friend or foe": "spider-man 4",
            "spider-man: web of shadows: amazing allies edition": "spider-man 5",
            "ssx tricky": "ssx 2",
            "ssx on tour": "ssx 4",
            "amplitude": "frequency 2",
            "amplitude: p.o.d.": "frequency 2",
            "ddrmax2: dance dance revolution": "dance dance revolution",
            "ddrmax2: dance dance revolution 7th mix": "dance dance revolution",
            "ddrmax: dance dance revolution": "dance dance revolution",
            "ddrmax: dance dance revolution 6th mix": "dance dance revolution",
            "nba street vol. 2": "nba street 2",
            "nba street v3": "nba street 3",
            "dragon ball z: budokai": "dragon ball z",
            "dragon ball z: budokai 2": "dragon ball z 2",
            "dragon ball z 2v": "dragon ball z 2",
            "dragon ball z: budokai 3": "dragon ball z 3",
            "dragon ball z: budokai 3: collector's edition": "dragon ball z 3",
            "dragon ball z: sagas": "dragon ball z 4",
            "dragon ball z: budokai tenkaichi": "dragon ball z 5",
            "dragon ball z: sparking!": "dragon ball z 5",
            "super dragon ball z": "dragon ball z 6",
            "dragon ball z: budokai tenkaichi 2": "dragon ball z 7",
            "dragon ball z: sparking! neo": "dragon ball z 7",
            "dragon ball z: budokai tenkaichi 3": "dragon ball z 8",
            "dragon ball z: sparking! meteor": "dragon ball z 9",
            "dragon ball z: infinite world": "dragon ball z 9b",
            "tomb raiders": "tomb raider",
            "tomb raider: the last revelation": "tomb raider 4",
            "tomb raider: la révélation finale": "tomb raider 4",
            "tomb raider chronicles": "tomb raider 5",
            "tomb raider chronicles: la leggenda di lara croft": "tomb raider 5",
            "tomb raider: sur les traces de lara croft": "tomb raider 5",
            "tomb raider: die chronik": "tomb raider 5",
            "lara croft tomb raider: the angel of darkness": "tomb raider 6",
            "lara croft tomb raider: utsukushiki toubousha": "tomb raider 6",
            "lara croft tomb raider: legend": "tomb raider 7",
            "lara croft tomb raider: anniversary": "tomb raider 8",
            "tomb raider: underworld": "tomb raider 9",
            "super robot taisen impact": "super robot taisen 1",
            "super robot taisen impact (genteiban)": "super robot taisen 1",
            "dai-2-ji super robot taisen alpha": "super robot taisen 2",
            "dai-2-ji super robot taisen alpha (genteiban)": "super robot taisen 2",
            "super robot taisen: scramble commander": "super robot taisen 3",
            "super robot taisen mx": "super robot taisen 4",
            "dai-3-ji super robot taisen alpha: shuuen no ginga e": "super robot taisen 5",
            "super robot taisen og: original generations": "super robot taisen 6",
            "super robot taisen: scramble commander the 2nd": "super robot taisen 7",
            "super robot taisen og gaiden": "super robot taisen 8",
            "super robot taisen z": "super robot taisen 9",
            "super robot taisen z: special disc": "super robot taisen 10",
            "air combat": "ace combat 1",
            "wipeout xl": "wipeout 2",
            "wipeout 2097": "wipeout 2",
            "wip3out": "wipeout 3",
            "tekken tag tournament": "tekken"

        }

        is_override = key in overrides
        key = overrides.get(key, key)

        # Truncate to prefix group if needed
        truncate_prefixes = [
            'king of fighters',
            'scooby-doo',
            'shining force',
            'time crisis',
            '.hack',
            'fullmetal alchemist',
            'shin megami tensei',
            'tony hawk',
            'yu-gi-oh',
            'dance dance revolution',
            'spyro'
        ]

        lower_key = key.lower()
        for prefix in truncate_prefixes:
            if lower_key.startswith(prefix):
                key = prefix
                break

        # Remove any subtitle after colon
        if ':' in key:
            key = key.split(':')[0].strip()

        normalized = normalize_text(key)

        # Replace Roman numerals with digits (whole words only)
        roman_map = {
            r'(?<![\w-])I(?![\w-])': '1',
            r'(?<![\w-])II(?![\w-])': '2',
            r'(?<![\w-])III(?![\w-])': '3',
            r'(?<![\w-])IV(?![\w-])': '4',
            r'(?<![\w-])V(?![\w-])': '5',
            r'(?<![\w-])VI(?![\w-])': '6',
            r'(?<![\w-])VII(?![\w-])': '7',
            r'(?<![\w-])VIII(?![\w-])': '8',
            r'(?<![\w-])IX(?![\w-])': '9',
            r'(?<![\w-])X(?![\w-])': '10',
            r'(?<![\w-])XI(?![\w-])': '11',
            r'(?<![\w-])XII(?![\w-])': '12',
            r'(?<![\w-])XIII(?![\w-])': '13',
            r'(?<![\w-])XIV(?![\w-])': '14',
            r'(?<![\w-])XV(?![\w-])': '15',
            r'(?<![\w-])XVI(?![\w-])': '16',
            r'(?<![\w-])XVII(?![\w-])': '17',
            r'(?<![\w-])XVIII(?![\w-])': '18',
            r'(?<![\w-])XIX(?![\w-])': '19',
            r'(?<![\w-])XX(?![\w-])': '20',
        }

        for roman_pattern, digit in roman_map.items():
            normalized = re.sub(roman_pattern, digit, normalized, flags=re.IGNORECASE)

        # Remove punctuation
        normalized = ''.join(c for c in normalized if c.isalnum() or c.isspace())

        result = normalized.lower()
        # print(f"{repr(first_field)} → {repr(result)}, game_id={repr(game_id)}")
        return (result, game_id.lower())


    # Sort and write the list back
    sorted_lines = natsorted(lines, key=sort_key)
    with open(games_list_path, 'w') as file:
        file.writelines(sorted_lines)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: sort-list-ps2.py <path_to_ps2.list>")
        sys.exit(1)
    sort_games_list(sys.argv[1])

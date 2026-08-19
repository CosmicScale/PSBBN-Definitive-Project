#!/usr/bin/env python3

"""
Art Downloader form the PSBBN Definitive Project
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
import csv
import urllib.request
from urllib.parse import urlparse
from pathlib import Path
from html.parser import HTMLParser

CSV_FILE_PATH = './scripts/assets/database/ArtDB.csv'
OUTPUT_DIR = './icons/art/tmp'

IGNORED_IMAGES = [
    "https://assets-prd.ignimgs.com/2025/04/03/switch2-doodle-1743697401557.png",
    "https://assets-prd.ignimgs.com/avatars/4ec71177e4b0ca04b5aab1c8/Nix_-_IGN_-_202x-1691124964030.png",
    "https://media.ign.com/boards/images/icons2/supers_ghostrider.gif",
    "https://assets-prd.ignimgs.com/avatars/54580a4b06017ecee2c408bc/20210304_001650-1657323628824.jpg",
    "https://assets-prd.ignimgs.com/avatars/4ec80936e4b0ca04b5c015bc/Fran00048-1603147509320.jpg",
    "https://assets1.ignimgs.com/kraken/ign30-logo-alt.png",
    "https://assets1.ignimgs.com/kraken/ign30-logo.png",
    "https://assets1.ignimgs.com/kraken/PlayablesGameScopeLogo.png",
    "https://assets1.ignimgs.com/kraken/PlayablesTriviaLogo.png"
]

SEARCH_DOMAINS = [
    "https://assets-prd.ignimgs.com",
    "https://media.ign.com",
    "https://ps2media.ign.com",
    "https://ps3media.ign.com",
    "https://media.gamestats.com",
    "https://assets1.ignimgs.com",
]


def find_url_for_game_id(game_id: str) -> str | None:
    """Search CSV for the given game ID and return full IGN URL."""
    try:
        with open(CSV_FILE_PATH, newline="", encoding="utf-8") as csvfile:
            reader = csv.reader(csvfile, delimiter="|")
            for row in reader:
                if len(row) >= 2 and row[0] == game_id:
                    return f"https://www.ign.com/games/{row[1]}"
    except FileNotFoundError:
        print(f"CSV file not found: {CSV_FILE_PATH}")
        sys.exit(1)
    return None


class ImgParser(HTMLParser):
    """HTML parser that finds the first image for a given domain."""
    def __init__(self, domain):
        super().__init__()
        self.domain = domain
        self.found_img = None

    def handle_starttag(self, tag, attrs):
        if tag == "img" and not self.found_img:
            attrs = dict(attrs)
            src = attrs.get("src")
            if src and src.startswith(self.domain):
                clean_src = src.split("?")[0]
                if clean_src not in IGNORED_IMAGES:
                    self.found_img = clean_src


def fetch_page(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0"}
    )
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def download_image(url: str, destination: Path):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0"}
    )
    with urllib.request.urlopen(req) as resp, open(destination, "wb") as f:
        f.write(resp.read())


def main():
    if len(sys.argv) < 2:
        print("Usage: python art_downloader.py <gameid>")
        sys.exit(1)

    game_id = sys.argv[1]
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

    url = find_url_for_game_id(game_id)
    if not url:
        print(f'Game ID "{game_id}" not found in ArtDB.csv')
        sys.exit(1)

    print(f"Navigating to: {url}")
    try:
        html = fetch_page(url)
    except Exception as e:
        print(f"Failed to fetch the page: {e}")
        sys.exit(1)

    img_url = None
    for i, domain in enumerate(SEARCH_DOMAINS):
        parser = ImgParser(domain)
        parser.feed(html)
        if parser.found_img:
            img_url = parser.found_img
            break
        else:
            if i < len(SEARCH_DOMAINS) - 1:
                next_domain = SEARCH_DOMAINS[i + 1]
                print(f"No image found on {domain.replace('https://', '')}. Checking {next_domain.replace('https://', '')}...")

    if img_url:
        file_extension = Path(urlparse(img_url).path).suffix
        file_name = Path(OUTPUT_DIR) / f"{game_id}{file_extension}"

        print(f"Downloading image from: {img_url}")
        try:
            download_image(img_url, file_name)
            print(f"Saved as: {file_name}")
            sys.exit(0)
        except Exception as e:
            print(f"Error downloading image: {e}")
            sys.exit(1)
    else:
        print("No image found on any source.")
        sys.exit(1)


if __name__ == "__main__":
    main()

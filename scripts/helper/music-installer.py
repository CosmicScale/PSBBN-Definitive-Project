#!/usr/bin/env python3

"""
Music Installer form the PSBBN Definitive Project
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

import os
import sys
import csv
import re
import datetime
import subprocess
import logging
import shutil
import unicodedata
from io import StringIO
from collections import defaultdict
from mutagen import File
from mutagen.easyid3 import EasyID3
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from tqdm import tqdm
from collections import defaultdict

MUSIC_DIR = "media/music"
SQL_PATH = "scripts/tmp/music_dump.sql"
MUSIC_DATA_TXT = "scripts/tmp/music_data.txt"
MUSIC_FAV_TXT = "scripts/tmp/music_fav.txt"
MUSIC_METADATA_TXT = "scripts/tmp/music_metadata.txt"
CONVERTED_DIR = "scripts/storage/__linux.8/MusicCh/contents"
SUPPORTED_EXTENSIONS = ('.mp3', '.m4a', '.flac', '.ogg')
OUTPUT_PATH = "scripts/tmp/music_reconstructed.sql"
BITRATE_FILE = "scripts/assets/music/bitrate"
LOG_PATH = "logs/media.log"

if len(sys.argv) > 1:
    MUSIC_DIR = sys.argv[1]

# SQL headers and footer
header_music = """BEGIN TRANSACTION;
CREATE TABLE SCEI_Jukebox (    version         INT2 DEFAULT 1,     url             VARCHAR,     trackno         INTEGER,     discid          CHAR(8),     language        INT2 DEFAULT 0,     albumname       VARCHAR DEFAULT 'Unknown title',     albumname2      VARCHAR DEFAULT 'Unknown title',     songname        VARCHAR DEFAULT 'Unknown title',     songname2       VARCHAR DEFAULT 'Unknown title',     artistname      VARCHAR DEFAULT 'Unknown Artist',     artistname2     VARCHAR DEFAULT 'Unknown Artist',     length          TIME,     datasize        INTEGER,     playtimes       INTEGER DEFAULT 0,     checkouttimes   INTEGER DEFAULT 0,     importdate      TIMESTAMP,     lastplaydate    TIMESTAMP,     genre           VARCHAR,     format          INT2,     usagerule       VARCHAR,     album_no        INTEGER   );
"""

header_fav = """CREATE TABLE SCEI_Jukebox_pd (    version         INT2 DEFAULT 1,    pdtype          INT2,     contenturi      VARCHAR,     usageruleuri    VARCHAR,     mgid            CHAR(32),     fileno          INTEGER,     hashid          CHAR(16),     contentid       CHAR(40)   );
CREATE TABLE SCEI_Jukebox_favorite_color ( 	  version         INT2 DEFAULT 1, 	  url             VARCHAR, 	  favorite        INT2, 	  entrydate       TIMESTAMP 	  );
"""

footer = """COMMIT;
"""

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format='[%(levelname)s] %(message)s'
)

# Extract data from original SQL file and convert to plain text:
def extract_music_data():
    insert_pattern = re.compile(r"INSERT INTO (\w+) VALUES\s*\((.+)\);", re.IGNORECASE | re.DOTALL)

    first_jukebox_written_to_fav = False
    jukebox_rows = []
    favorite_rows = []
    footers = {}

    with open(SQL_PATH, "rb") as f:
        for line in f:
            decoded_line = line.decode("utf-8", errors="replace")
            match = insert_pattern.search(decoded_line.strip())
            if match:
                table = match.group(1)
                values_str = match.group(2)
                try:
                    reader = csv.reader(StringIO(values_str), delimiter=",", quotechar="'", escapechar="\\")
                    values = next(reader)
                    clean_values = []
                    for v in values:
                        if v.upper() == "NULL":
                            clean_values.append("NULL")
                        elif "�" in v:
                            clean_values.append("")  # Clear unreadable fields
                        else:
                            clean_values.append(v.replace("''", "'"))

                    if table == "SCEI_Jukebox":
                        if not first_jukebox_written_to_fav:
                            favorite_rows.append(clean_values)
                            first_jukebox_written_to_fav = True
                        else:
                            url = clean_values[1]
                            if not url.endswith(".pcm"):
                                # It's a footer row
                                album_sort_key = re.sub(r'^the\s+', '', clean_values[5], flags=re.IGNORECASE).lower()
                                footers[album_sort_key] = "|".join(clean_values)
                                jukebox_rows.append(clean_values)  # <- add footer to MUSIC_DATA_TXT
                            else:
                                jukebox_rows.append(clean_values)

                    elif table == "SCEI_Jukebox_favorite_color":
                        favorite_rows.append(clean_values)

                except Exception as e:
                    error_message = f"Error: Skipping problematic row: {values_str}\nReason: {e}\n"
                    with open(LOG_PATH, "a", encoding="utf-8") as log_file:
                        log_file.write(error_message)
                        print(error_message, file=sys.stderr)
                    sys.exit(1)

    # Write main music data
    with open(MUSIC_DATA_TXT, "w", encoding="utf-8") as out:
        for row in jukebox_rows:
            out.write("|".join(row) + "\n")

    # Write favorite data
    with open(MUSIC_FAV_TXT, "w", encoding="utf-8") as fav_out:
        for row in favorite_rows:
            fav_out.write("|".join(row) + "\n")
    
    return footers

# Convert music files and extract meta data:
def sanitize_folder_name(name, disc=None, total_discs=None):
    # Lowercase, remove spaces, strip unsupported characters
    base = re.sub(r'[^a-z0-9]', '', name.lower().replace(' ', ''))

    # Multi-disc handling: shorten to 7 chars, append disc number
    if disc and (disc > 1 or (disc == 1 and total_discs and int(total_discs) > 1)):
        return base[:7] + str(disc)
    else:
        return base[:8]
    
def normalize_name(name):
    # Replace characters outside Latin-1 with their base equivalents if possible
    return unicodedata.normalize('NFKD', name).encode('latin-1', 'ignore').decode('latin-1')
    
def parse_disc_number(raw):
    if not raw:
        return (1, 1)
    parts = raw.split('/')
    try:
        disc = int(parts[0])
    except:
        disc = 1
    total = 1
    if len(parts) > 1:
        try:
            total = int(parts[1])
        except:
            total = 1
    return (disc, total)

def clean_track_number(raw):
    return raw.split('/')[0].strip() if raw else ''

def format_seconds(seconds):
    try:
        seconds = int(round(seconds))
        return f"{seconds // 3600:02}:{(seconds % 3600) // 60:02}:{seconds % 60:02}"
    except Exception:
        return "00:00:00"

def extract_metadata(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    audio = File(filepath)
    if not audio:
        return None

    metadata = {
        'path': os.path.abspath(filepath),
        'album': '',
        'discnumber': '',
        'tracknumber': '',
        'title': '',
        'artist': '',
        'album_artist': '',
        'length': round(audio.info.length, 2) if audio.info else 0
    }

    try:
        if ext == '.mp3':
            try:
                audio = EasyID3(filepath)
                metadata['album'] = audio.get('album', [''])[0]
                metadata['discnumber'] = audio.get('discnumber', [''])[0]
                metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
                metadata['title'] = audio.get('title', [''])[0]
                metadata['artist'] = audio.get('artist', [''])[0]
                metadata['album_artist'] = audio.get('albumartist', [metadata['artist']])[0]
            except:
                id3 = audio.tags
                if id3:
                    metadata['album'] = str(id3.get('TALB', ''))
                    metadata['discnumber'] = str(id3.get('TPOS', ''))
                    metadata['tracknumber'] = str(id3.get('TRCK', ''))
                    metadata['title'] = str(id3.get('TIT2', ''))
                    metadata['artist'] = str(id3.get('TPE1', ''))
                    metadata['album_artist'] = str(id3.get('TPE2', metadata['artist']))
        elif ext == '.m4a' and isinstance(audio, MP4):
            metadata['album'] = audio.tags.get('\xa9alb', [''])[0]
            disk_info = audio.tags.get('disk', [(0, 0)])  # tuple (disc_number, total_discs)
            if disk_info and disk_info[0][0] > 0:
                total = disk_info[0][1]
                metadata['discnumber'] = f"{disk_info[0][0]}/{total}" if total else str(disk_info[0][0])
            metadata['tracknumber'] = str(audio.tags.get('trkn', [(0,)])[0][0])
            metadata['title'] = audio.tags.get('\xa9nam', [''])[0]
            metadata['artist'] = audio.tags.get('\xa9ART', [''])[0]
            metadata['album_artist'] = audio.tags.get('aART', [metadata['artist']])[0]
        elif ext == '.flac' and isinstance(audio, FLAC):
            metadata['album'] = audio.get('album', [''])[0]
            disc = audio.get('discnumber', [''])[0]
            total = audio.get('totaldiscs', [''])[0]
            if disc:
                metadata['discnumber'] = f"{disc}/{total}" if total else disc
            metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
            metadata['title'] = audio.get('title', [''])[0]
            metadata['artist'] = audio.get('artist', [''])[0]
            metadata['album_artist'] = audio.get('albumartist', [metadata['artist']])[0]
        elif ext == '.ogg':
            metadata['album'] = audio.get('album', [''])[0]
            disc = audio.get('discnumber', [''])[0]
            total = audio.get('totaldiscs', [''])[0]
            if disc:
                metadata['discnumber'] = f"{disc}/{total}" if total else disc
            metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
            metadata['title'] = audio.get('title', [''])[0]
            metadata['artist'] = audio.get('artist', [''])[0]
            metadata['album_artist'] = audio.get('albumartist', [metadata['artist']])[0]
    except:
        return None

    return metadata if metadata['album'] else None

def convert_to_pcm(input_path, OUTPUT_PATH):
    if os.path.exists(OUTPUT_PATH):
        return  # Skip if already converted

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    try:
        subprocess.run([
            'ffmpeg', '-y', '-i', input_path,
            '-af', 'dynaudnorm',
            '-f', 's16le', '-acodec', 'pcm_s16le',
            '-ar', '44100', '-ac', '2', OUTPUT_PATH
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except subprocess.CalledProcessError as e:
        err_output = e.stderr.decode(errors='ignore') if e.stderr else "No stderr captured"
        logging.error(f"ffmpeg failed on {input_path}: {err_output}")
        return False
    return True

def load_music_data_txt():
    entries = []
    footers = {}  # album_sort_key -> footer line
    if os.path.isfile(MUSIC_DATA_TXT):
        with open(MUSIC_DATA_TXT, 'r', encoding='utf-8') as f:
            for line in f:
                parts = line.strip().split('|')
                url = parts[1]
                if not url.endswith(".pcm"):
                    # Footer row
                    album_sort_key = re.sub(r'^the\s+', '', parts[5], flags=re.IGNORECASE).lower()
                    footers[album_sort_key] = line.strip()
                else:
                    album_for_db = parts[5]
                    tracknumber = parts[2]
                    artist = parts[10]
                    folder = os.path.basename(os.path.dirname(parts[1]))
                    sort_key = re.sub(r'^the\s+', '', album_for_db, flags=re.IGNORECASE).lower()
                    try:
                        track_num_int = int(tracknumber)
                    except:
                        track_num_int = 0

                    entries.append({
                        'album_sort_key': sort_key,
                        'album': album_for_db,
                        'album_for_db': album_for_db,
                        'artist': artist,
                        'album_artist': artist,
                        'track_num': track_num_int,
                        'line': line.strip(),
                        'length': 0,
                        'size': 0,
                        'folder': folder,
                        'out_folder': os.path.join(CONVERTED_DIR, folder)
                    })
    return entries, footers

def music_installer(existing_footers):
    metadata_entries, footers_from_txt = load_music_data_txt()
    footers = {**existing_footers, **footers_from_txt}

    all_files = [
        os.path.join(root, file)
        for root, _, files in os.walk(MUSIC_DIR)
        for file in files
        if file.lower().endswith(SUPPORTED_EXTENSIONS) and not file.startswith('.')
    ]

    skipped_files = []

    for filepath in tqdm(all_files, desc="Converting files", unit="file"):
        meta = extract_metadata(filepath)
        if not meta or not meta['album']:
            reason = "Failed to extract metadata"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        disc, total_discs = parse_disc_number(meta.get('discnumber', ''))
        album_folder = sanitize_folder_name(meta.get('album', ''), disc=disc, total_discs=total_discs)

        # Skip if album_folder is empty
        if not album_folder:
            reason = "Album name contains no supported characters"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        # Normalize album, artist, and title
        meta['album'] = normalize_name(meta['album'])
        meta['artist'] = normalize_name(meta['artist'])
        meta['title'] = normalize_name(meta['title'])

        # Append disc to album title for DB
        if disc and (disc > 1 or (disc == 1 and total_discs and int(total_discs) > 1)):
            album_for_db = f"{meta['album']} (Disc {disc})"
        else:
            album_for_db = meta['album']

        track_num = clean_track_number(meta['tracknumber'])
        if not track_num.isdigit():
            reason = f"Missing or invalid track number: '{meta['tracknumber']}'"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        if not meta['artist']:
            meta['artist'] = "Unknown Artist"
        if not meta['title']:
            meta['title'] = f"Track {int(track_num)}"

        padded = f"{int(track_num):02}"
        out_folder = os.path.join(CONVERTED_DIR, album_folder)
        os.makedirs(out_folder, exist_ok=True)
        out_file = f"track{padded}.pcm"
        out_path = os.path.join(out_folder, out_file)

        if os.path.exists(out_path):
            reason = "File already installed"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        if not convert_to_pcm(filepath, out_path):
            reason = "FFmpeg conversion failed"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        # Copy bitrate file if exists
        bitrate_dest = os.path.join(out_folder, 'bitrate')
        if os.path.isfile(BITRATE_FILE) and not os.path.isfile(bitrate_dest):
            shutil.copy(BITRATE_FILE, bitrate_dest)

        pcm_size = os.path.getsize(out_path)
        creation_time = datetime.datetime.fromtimestamp(os.path.getctime(out_path)).strftime("%Y-%m-%d %H:%M:%S")
        rel_path = os.path.join(album_folder, out_file)

        line = (
            f"1|/opt2/MusicCh/contents/{rel_path}|{track_num}|NULL|0|"
            f"{album_for_db}||{meta['title']}||{meta['artist']}||"
            f"{format_seconds(meta['length'])}|{pcm_size}|0|0|{creation_time}|"
            "NULL|NULL|0|/opt0/bn/openmg/ripping.tur|NULL"
        )

        metadata_entries.append({
            'album_sort_key': re.sub(r'^the\s+', '', meta['album'], flags=re.IGNORECASE).lower(),
            'album': meta['album'],
            'album_for_db': album_for_db,
            'artist': meta['artist'],
            'album_artist': meta['album_artist'],
            'track_num': int(track_num),
            'line': line,
            'length': meta['length'],
            'size': pcm_size,
            'folder': album_folder,
            'out_folder': out_folder
        })

    # Group by album_sort_key and disc
    grouped = defaultdict(lambda: defaultdict(list))
    for entry in metadata_entries:
        disc_match = re.search(r'\(Disc (\d+)\)', entry['album_for_db'])
        disc_num = int(disc_match.group(1)) if disc_match else 1
        grouped[entry['album_sort_key']][disc_num].append(entry)

    # Flatten albums by album_for_db for sorting
    albums_for_sorting = []
    for album_sort_key, discs in grouped.items():
        for disc_num, tracks in discs.items():
            albums_for_sorting.append({
                'album_for_db': tracks[0]['album_for_db'],
                'album_sort_key': album_sort_key,
                'disc_num': disc_num,
                'tracks': tracks
            })

    # Sort reverse alphabetical by album_for_db
    albums_for_sorting.sort(key=lambda x: x['album_for_db'], reverse=True)

    # Write to MUSIC_METADATA_TXT
    os.makedirs(CONVERTED_DIR, exist_ok=True)
    with open(MUSIC_METADATA_TXT, 'w', encoding='utf-8') as f:
        album_index = 1
        for album in albums_for_sorting:
            tracks = album['tracks']
            tracks.sort(key=lambda t: t['track_num'])  # sort tracks by track number

            # Write track lines
            for entry in tracks:
                f.write(entry['line'] + '\n')

             # Write footer per disc
            album_sort_key = re.sub(r'^the\s+', '', tracks[0]['album'].lower(), flags=re.IGNORECASE).lower()

            if album_sort_key in footers:
                parts = footers[album_sort_key].split("|")
                parts[-1] = str(album_index)  # always replace last field
                f.write("|".join(parts) + "\n")
            else:
                # Generate new footer using album_artist
                album_for_db = tracks[0]['album_for_db']
                album_artist = tracks[0].get('album_artist') or tracks[0]['artist']
                folder = os.path.join("/opt2/MusicCh/contents", tracks[0]['folder'])
                total_tracks = len(tracks)
                out_folder = tracks[0]['out_folder']
                ctime_epoch = os.path.getctime(out_folder) if os.path.exists(out_folder) else datetime.datetime.now().timestamp()
                ctime_short = datetime.datetime.fromtimestamp(ctime_epoch).strftime("%Y%m%d")
                ctime_long = datetime.datetime.fromtimestamp(ctime_epoch).strftime("%Y-%m-%d %H:%M:%S")

                total_length = sum(entry['length'] for entry in tracks)
                total_size = sum(entry['size'] for entry in tracks)

                footer_line = (
                    f"1|{folder}|{total_tracks}|{ctime_short}|0|{album_for_db}||Unknown title|Unknown title|{album_artist}||"
                    f"{format_seconds(total_length)}|{total_size}|0|0|{ctime_long}|NULL|NULL|-1|NULL|{album_index}"
                )
                f.write(footer_line + '\n')

            album_index += 1

    if skipped_files:
        print("\nSkipped files:")
        grouped = defaultdict(list)
        for fpath, reason in skipped_files:
            rel_path = os.path.relpath(fpath, MUSIC_DIR)
            grouped[reason].append(rel_path)

        for reason, paths in grouped.items():
            print(f"\nReason: {reason}")
            for p in paths:
                print(f"- {p}")
    else:
        print("\nNo files were skipped.")

# Create new database file:
def format_values(line):
    timestamp_pattern = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
    number_pattern = re.compile(r"^-?\d+(\.\d+)?$")

    line = line.replace('%', '％')  # Replace percent sign with fullwidth
    line = line.strip()
    if not line:
        return None
    values = [v.replace("'", "''") if v != "NULL" else "NULL" for v in line.split("|")]
    quoted_values = []
    for v in values:
        if v == "NULL":
            quoted_values.append("NULL")
        elif number_pattern.match(v):
            quoted_values.append(v)
        elif v.count(':') == 2 and len(v) == 8:
            quoted_values.append(f"'{v}'")
        elif timestamp_pattern.match(v):
            quoted_values.append(f"'{v}'")
        else:
            quoted_values.append(f"'{v}'")
    return "(" + ",".join(quoted_values) + ")"

def create_db():
    with open(OUTPUT_PATH, "w", encoding="utf-8") as out:
        out.write(header_music)

        fav_lines = []
        if os.path.exists(MUSIC_FAV_TXT):
            with open(MUSIC_FAV_TXT, "r", encoding="utf-8") as f:
                fav_lines = f.readlines()

        if fav_lines:
            first_values = format_values(fav_lines[0])
        else:
            default_first_line = "1|0|NULL|NULL|0|Favorite1||Unknown title|Unknown title|Unknown Artist|Unknown Artist|NULL|NULL|0|0|2023-06-06 12:50:31|NULL|NULL|-2|NULL|NULL"
            first_values = format_values(default_first_line)

        if first_values:
            out.write(f"INSERT INTO SCEI_Jukebox VALUES{first_values};\n")

        # Write lines from music_data.txt
        with open(MUSIC_METADATA_TXT, "r", encoding="utf-8") as f:
            for line in f:
                values = format_values(line)
                if values:
                    out.write(f"INSERT INTO SCEI_Jukebox VALUES{values};\n")

        # Header for favorite_color section
        out.write(header_fav)

        # Remaining lines as SCEI_Jukebox_favorite_color
        for line in fav_lines[1:]:
            values = format_values(line)
            if values:
                out.write(f"INSERT INTO SCEI_Jukebox_favorite_color VALUES{values};\n")

        out.write(footer)

if __name__ == "__main__":
    if os.path.exists(SQL_PATH):
        existing_footers = extract_music_data()
    else:
        existing_footers = {}
        error_message = f"No existing database to convert.\n"
        with open(LOG_PATH, "a", encoding="utf-8") as log_file:
            log_file.write(error_message)
        print(error_message, file=sys.stderr)
    
    music_installer(existing_footers)
    create_db()
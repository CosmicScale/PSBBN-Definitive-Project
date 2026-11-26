#!/usr/bin/env python3

"""
List Builder form the PSBBN Definitive Project
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
import os.path
import re
import lz4.block
import unicodedata
from struct import unpack
from collections import defaultdict
from tqdm import tqdm

log_dir = os.path.join(os.getcwd(), "logs")

total = 0
count = 0

ZISO_MAGIC = 0x4F53495A
SECTOR_SIZE = 2048
CD_SECTOR_SIZE = 2352
MODE2_USER_DATA_OFFSET = 16

pattern_1 = [b'\x01', b'\x0D']
pattern_2 = [b'\x3B', b'\x31']

def hide_cursor():
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()

def show_cursor():
    sys.stdout.write("\033[?25h")
    sys.stdout.flush()

def debug_log(message):
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(message + "\n")

# Function to count game files in the given folder
def count_files(folder, extensions):
    global total
    for image in os.listdir(game_path + folder):
        if image.startswith('.'):
            continue
        if any(image.lower().endswith(ext) for ext in extensions):
            total += 1

def read_zso_header(fin):
    data = fin.read(24)
    magic, header_size, total_bytes, block_size, ver, align = unpack('IIQIbbxx', data)
    return magic, header_size, total_bytes, block_size, ver, align

def lz4_decompress(compressed, block_size):
    while True:
        try:
            return lz4.block.decompress(compressed, uncompressed_size=block_size)
        except lz4.block.LZ4BlockError:
            compressed = compressed[:-1]

def build_index(fin, total_bytes, block_size, align):
    total_blocks = total_bytes // block_size
    index_buf = [unpack('I', fin.read(4))[0] for _ in range(total_blocks + 1)]
    return index_buf, total_blocks

def decompress_zso_sector(fin, index_buf, block_size, align, sector, num_sectors=1):
    # Decompress one or more 2048-byte ISO9660 sectors from a ZSO file efficiently.
    start_byte = sector * SECTOR_SIZE
    end_byte = (sector + num_sectors) * SECTOR_SIZE
    decompressed = bytearray()

    # Determine which blocks intersect the requested byte range
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
        dec_data = data if plain else lz4_decompress(data, block_size)

        block_start_byte = block * block_size
        block_end_byte = block_start_byte + len(dec_data)

        # Only extract the overlapping part
        start = max(start_byte - block_start_byte, 0)
        end = min(end_byte - block_start_byte, len(dec_data))
        decompressed.extend(dec_data[start:end])

    return decompressed

def read_iso_sector(fin, sector, num_sectors=1):
    # Read one or more raw 2048-byte ISO9660 sectors from an ISO file.
    fin.seek(sector * SECTOR_SIZE)
    return fin.read(num_sectors * SECTOR_SIZE)

def read_bin_sector(fin, sector, num_sectors=1):
    fin.seek(sector * CD_SECTOR_SIZE)
    raw = fin.read(num_sectors * CD_SECTOR_SIZE)

    data = bytearray()

    for i in range(num_sectors):
        sector_data = raw[
            i * CD_SECTOR_SIZE:
            (i + 1) * CD_SECTOR_SIZE
        ]

        user_data_offset = 24
        user_data_size = 2048

        user_data = sector_data[
            user_data_offset:
            user_data_offset + user_data_size
        ]

        data.extend(user_data)

    return bytes(data)

def parse_dir_entries(data):
    # Parse ISO9660 directory entries from a block of data
    entries = []
    offset = 0
    while offset < len(data):
        length = data[offset]
        if length == 0:
            offset = (offset // SECTOR_SIZE + 1) * SECTOR_SIZE  # next sector boundary
            continue
        record = data[offset:offset+length]
        lba = int.from_bytes(record[2:6], "little")
        size = int.from_bytes(record[10:14], "little")
        name_len = record[32]
        name = record[33:33+name_len].decode("utf-8", errors="ignore")
        entries.append((name, lba, size))
        offset += length
    return entries

def extract_game_id_from_disc(sector_reader):
    # Common logic to extract Game ID from SYSTEM.CNF (ISO, ZSO, or PS1 BIN).
    # Step 1: Read PVD
    pvd = sector_reader(16, 1)

    # Root dir record is at offset 0x9C inside PVD
    root_dir_record = pvd[156:156+34]
    root_lba = int.from_bytes(root_dir_record[2:6], "little")
    root_size = int.from_bytes(root_dir_record[10:14], "little")
    debug_log(f"PVD signature: {pvd[1:6]}")
    debug_log(f"root_lba={root_lba}")
    debug_log(f"root_size={root_size}")

    # Step 2: Read root directory
    num_sectors = (root_size + SECTOR_SIZE - 1) // SECTOR_SIZE
    root_data = sector_reader(root_lba, num_sectors)

    debug_log(f"ROOT DATA length={len(root_data)}")
    debug_log(f"ROOT DATA first 64 bytes={root_data[:64]!r}")

    # Step 3: Parse entries
    entries = parse_dir_entries(root_data)
    debug_log(f"ROOT ENTRIES: {entries}")
    
    for name, lba, size in entries:
        if name.upper().startswith("SYSTEM.CNF"):
            num_sectors = (size + SECTOR_SIZE - 1) // SECTOR_SIZE
            system_cnf = sector_reader(lba, num_sectors)
            cnf_text = system_cnf.decode("utf-8", errors="ignore")

            for line in cnf_text.splitlines():
                if line.strip().upper().startswith(("BOOT2", "BOOT")):
                    boot_value = line.split("=", 1)[-1].strip()

                    # Remove CDROM:/CDROM0: prefix
                    boot_value = re.sub(r"^CDROM(?:0)?:", "", boot_value, flags=re.IGNORECASE)

                    # Remove path separators if present
                    boot_value = boot_value.replace("\\", "/")

                    # Take the final component
                    boot_value = boot_value.split("/")[-1]

                    # Remove ISO version suffix
                    boot_value = boot_value.split(";", 1)[0]

                    return boot_value
    return None

def normalize_game_id(game_id):
    if not game_id:
        return ""

    game_id = game_id.upper()

    # If it starts with SLUSP, remove the trailing P.
    if game_id.startswith("SLUSP"):
        game_id = "SLUS" + game_id[5:]

    # Remove any existing separators.
    cleaned = game_id.replace("_", "").replace(".", "").replace("-", "")

    # Special rule for IDs beginning with LSP.
    if cleaned.startswith("LSP"):
        return cleaned[:8] + "." + cleaned[8:]

    # Rebuild with underscore at index 4 and dot at index 8.
    game_id = cleaned[:4] + "_" + cleaned[4:7] + "." + cleaned[7:]

    return game_id

def clean_name_from_filename(name, game_id):
    base_name = os.path.splitext(name)[0]

    if base_name.upper().startswith(game_id):
        stripped = base_name[len(game_id):].lstrip('_. ')
        return stripped if stripped else base_name
    else:
        return base_name

def make_partition_label(game_id, title, suffix):
    # Format game id correctly for partition name
    title_id = re.sub(r'_(...)\.', r'-\1', game_id)
    title_id = title_id.replace('.', '')

    # Replace special superscripts first
    title = title.replace('²', '2').replace('³', '3')

    # Transliterate to ASCII
    title_ascii = unicodedata.normalize('NFKD', title).encode('ascii', 'ignore').decode()

    # Uppercase
    title_ascii = title_ascii.upper()

    # Replace non A-Z0-9 with underscores
    sanitized = re.sub(r'[^A-Z0-9]', '_', title_ascii)

    # Clean up underscores
    sanitized = re.sub(r'^_+', '', sanitized)      # leading
    sanitized = re.sub(r'_+$', '', sanitized)      # trailing
    sanitized = re.sub(r'_+', '_', sanitized)      # multiple → single

    # Build label
    partition_label = f"PP.{title_id}.{suffix}.{sanitized}"

    # Cut to 32 chars and remove trailing underscore
    partition_label = partition_label[:32].rstrip('_')

    return partition_label

# Function to process game files in the given folder
def process_files(all_targets):
    global total, count

    game_names = {}
    if os.path.isfile(gameid_file_path):
        with open(gameid_file_path, 'r') as gameid_file:
            for line in gameid_file:
                parts = line.strip().split('|')  # Split title ID and game name
                if len(parts) == 4:
                    game_names[parts[0]] = (parts[1], parts[2], parts[3])

    # Prepare a list to hold all game list entries
    game_list_entries = []
    game_id_counts = defaultdict(int)
    temp_entries = []

    images = all_targets

    pbar = tqdm(
        images,
        unit="game",
        position=0,
        bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}"
    )

    file_bar = tqdm(total=0, position=1, bar_format="{desc}")

    for folder, image in pbar:

        file_bar.set_description_str(f"Processing: {image}")

        game_id = ""
        game_image = image

        file_path = os.path.join(game_path, folder, image)
        debug_log("")
        debug_log("=" * 80)
        debug_log(f"FILE: {file_path}")

        # ISO
        if image.lower().endswith('.iso') and not game_id:
            debug_log("ISO extraction: ATTEMPTING")

            with open(file_path, "rb") as fin:
                def iso_reader(sector, num_sectors=1):
                    return read_iso_sector(fin, sector, num_sectors)
                game_id = extract_game_id_from_disc(iso_reader) or ""

            if game_id:
                debug_log(f"ISO extraction: SUCCESS -> {game_id}")
            else:
                debug_log("ISO extraction: FAILED")

        # ZSO
        if image.lower().endswith('.zso') and not game_id:
            debug_log("ZSO extraction: ATTEMPTING")

            with open(file_path, "rb") as fin:
                magic, header_size, total_bytes, block_size, ver, align = read_zso_header(fin)
                if magic == ZISO_MAGIC:
                    total_blocks = total_bytes // block_size
                    index_buf = [unpack('I', fin.read(4))[0] for _ in range(total_blocks + 1)]

                    def zso_reader(sector, num_sectors=1):
                        return decompress_zso_sector(fin, index_buf, block_size, align, sector, num_sectors)

                    game_id = extract_game_id_from_disc(zso_reader) or ""

            if game_id:
                debug_log(f"ZSO extraction: SUCCESS -> {game_id}")
            else:
                debug_log("ZSO extraction: FAILED")

        # BIN (PS1 MODE2/2352)
        if image.lower().endswith('.bin') and not game_id:
            debug_log("BIN MODE2/2352 extraction: ATTEMPTING")

            with open(file_path, "rb") as fin:
                def bin_reader(sector, num_sectors=1):
                    return read_bin_sector(
                        fin,
                        sector,
                        num_sectors
                    )

                game_id = extract_game_id_from_disc(bin_reader) or ""

            if game_id:
                debug_log(f"BIN MODE2/2352 extraction: SUCCESS -> {game_id}")
            else:
                debug_log("BIN MODE2/2352 extraction: FAILED")

        # VCD
        if image.lower().endswith('.vcd') and not game_id:
            debug_log("VCD extraction: ATTEMPTING")

            with open(os.path.join(game_path, folder, image), "rb") as file:
                for raw_line in file:
                    line = raw_line.strip()
                    line_lower = line.lower()
                    if b'cdrom:' in line_lower and b'boot' in line_lower:

                        idx = line_lower.find(b'cdrom:') + len(b'cdrom:')
                        segment = line[idx:].split(b';', 1)[0]

                        raw_bytes = segment.split(b'\\')[-1]
                        game_id = raw_bytes.decode('utf-8', errors='ignore').upper()

                        break

            if game_id:
                debug_log(f"VCD extraction: SUCCESS -> {game_id}")
            else:
                debug_log("VCD extraction: FAILED")
            
        # Fallback for ISO, VCD, and BIN
        if (len(game_id) < 11 or len(game_id) > 12) and (image.lower().endswith('.iso') or image.lower().endswith('.vcd') or image.lower().endswith('.bin')):
            debug_log("Raw fallback scan: ATTEMPTING")

            with open(file_path, "rb") as f:
                data_to_scan = f.read()  # Scan the entire file

            index = 0
            game_id = ""
            for byte in data_to_scan:
                if len(game_id) < 4:
                    if index == 2:
                        game_id += chr(byte)
                    elif byte == pattern_1[index][0]:
                        index += 1
                    else:
                        game_id = ""
                        index = 0
                elif len(game_id) == 4:
                    index = 0
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
                    if byte == pattern_2[index][0]:
                        index += 1
                        if index == 2:
                            # Check for "CDDA_END.DA"
                            if game_id == "CDDA_END.DA":
                                # Reset and continue scanning
                                game_id = ""
                                index = 0
                                continue
                            else:
                                # If not CDDA_END.DA, handle normally (e.g., match found)
                                break
                    else:
                        game_id = ""
                        index = 0

            if game_id:
                debug_log(f"Raw fallback scan: SUCCESS -> {game_id}")
            else:
                debug_log("Raw fallback scan: FAILED")

        game_id = normalize_game_id(game_id)
        debug_log(f"Game ID after normalization: {game_id}")

        valid_id = (
            (
                len(game_id) == 11
                and game_id[4] == "_"
                and game_id[8] == "."
            )
            or
            (
                len(game_id) == 12
                and game_id.startswith("LSP")
                and game_id[8] == "."
            )
        )

        # If Game ID is not valid, generate one from filename
        if not valid_id:
            # Extract Game ID from filename if it meets the condition
            file_name_without_ext = os.path.splitext(image)[0]
            if len(file_name_without_ext) >= 11 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.':
                game_id = file_name_without_ext[:11].upper()
                debug_log(f"Filename extraction: SUCCESS -> {game_id}")
            else:
                debug_log("Filename extraction: NOT USED")

                # Remove spaces from filename and convert to uppercase
                base_name = os.path.splitext(image)[0]  # Strip the file extension
                game_id = re.sub(r'[^A-Z0-9]', '', base_name.upper())  # Keep only A-Z and 0-9

                # Trim the game_id to 9 characters or pad with zeros
                game_id = game_id[:9].ljust(9, '0')

                # Insert the underscore at position 5 and the full stop at position 9
                game_id = game_id[:4] + '_' + game_id[4:7] + '.' + game_id[7:]

                # Ensure the game_id is exactly 11 characters long
                game_id = game_id[:11]

                debug_log(f"Filename-generated ID: {game_id}")

        # Determine game name and publisher
        entry = game_names.get(game_id)
        if entry:
            game_name, publisher, jpn_title = entry
            if not game_name:
                game_name = os.path.splitext(image)[0]
                publisher = ""
                jpn_title = ""
        else:
            game_name = clean_name_from_filename(image, game_id)
            publisher = ""
            jpn_title = ""

        # 1st pass (store + count only)
        game_type = folder.lstrip("/")

        if games_list_path.endswith("ember.list"):
            game_type = "EMBER"

        if image.lower().endswith(".bin"):
            game_image = os.path.basename(os.path.normpath(folder))
        else:
            game_image = image

        game_id_counts[game_id] += 1

        temp_entries.append({
            "game_id": game_id,
            "game_name": game_name,
            "publisher": publisher,
            "game_type": game_type,
            "game_image": game_image,
            "jpn_title": jpn_title
        })

        count += 1
    
    pbar.update(1)

    # 2nd pass (build final entries)
    game_id_index = defaultdict(int)

    for entry in temp_entries:
        game_id = entry["game_id"]

        game_id_index[game_id] += 1
        suffix = f"{game_id_index[game_id]:02d}"

        # Apply duplicate rule
        if game_id_counts[game_id] > 1:
            display_name = clean_name_from_filename(entry["game_image"], game_id)
        else:
            display_name = entry["game_name"]

        partition_label = make_partition_label(
            game_id,
            entry["game_name"],
            suffix
        )

        game_list_entries.append(
            f"{display_name}|{game_id}|{entry['publisher']}|{entry['game_type']}|{entry['game_image']}|{entry['jpn_title']}|{partition_label}"
        )

    if game_list_entries:
        with open(games_list_path, "a") as output:
            for entry in game_list_entries:
                output.write(f"{entry}\n")

def process_ember_targets():
    # Find Track 01 BIN files in: <game_path>/Ember/games/<game folder>/

    all_targets = []

    games_root = os.path.join(game_path, "Ember", "games")

    if not os.path.isdir(games_root):
        print(f'{games_root} not found')
        sys.exit(1)

    for game_folder in sorted(os.listdir(games_root)):
        if game_folder.startswith('.'):
            continue

        full_folder_path = os.path.join(games_root, game_folder)

        if not os.path.isdir(full_folder_path):
            continue

        # Find the alphabetically first CUE file.
        cue_files = sorted(
            filename
            for filename in os.listdir(full_folder_path)
            if filename.lower().endswith(".cue")
        )

        if not cue_files:
            debug_log(f"No CUE file found in {full_folder_path}")
            continue

        cue_file = cue_files[0]
        cue_path = os.path.join(full_folder_path, cue_file)

        # Find the BIN referenced by TRACK 01.
        track01_bin = None

        try:
            with open(
                cue_path,
                "r",
                encoding="utf-8",
                errors="ignore"
            ) as cue:
                lines = cue.readlines()

            for i, line in enumerate(lines):
                stripped = line.strip()

                # Look for TRACK 01.
                if re.match(
                    r'^TRACK\s+01\b',
                    stripped,
                    re.IGNORECASE
                ):
                    # Find the FILE declaration immediately preceding TRACK 01.
                    for previous_line in reversed(lines[:i]):
                        previous_line = previous_line.strip()

                        match = re.match(
                            r'^FILE\s+"([^"]+)"',
                            previous_line,
                            re.IGNORECASE
                        )

                        if not match:
                            match = re.match(
                                r'^FILE\s+(\S+)',
                                previous_line,
                                re.IGNORECASE
                            )

                        if match:
                            track01_bin = match.group(1)
                            break

                    break

        except OSError as e:
            print(f'Could not read CUE file {cue_path}: {e}')
            continue

        if not track01_bin:
            print(f'No Track 01 BIN found in {cue_path}')
            continue

        # Handle Windows-style paths in CUE files.
        track01_bin = track01_bin.replace("\\", os.sep)

        bin_path = os.path.normpath(
            os.path.join(
                full_folder_path,
                track01_bin
            )
        )

        if not os.path.isfile(bin_path):
            print(f'Track 01 BIN not found: {bin_path}')
            continue

        # process_files() expects paths relative to game_path.
        relative_folder = os.path.relpath(
            full_folder_path,
            game_path
        )

        relative_image = os.path.relpath(
            bin_path,
            full_folder_path
        )

        all_targets.append(
            (relative_folder, relative_image)
        )

    return all_targets

def main(arg1, arg2):
    if arg1 and arg2:
        global game_path
        global games_list_path
        global gameid_file_path
        game_path = arg1
        games_list_path = arg2
        global log_path
        
        os.makedirs(log_dir, exist_ok=True)

        list_name = os.path.splitext(
            os.path.basename(games_list_path)
        )[0]

        log_path = os.path.join(
            log_dir,
            f"{list_name}-id.log"
        )
        
        with open(log_path, "w", encoding="utf-8") as log:
            log.write("Game ID extraction debug log\n")
            log.write("=" * 80 + "\n")

        # Set correct TitlesDB path based on output list name
        if games_list_path.endswith("ps2.list"):
            gameid_file_path = "./scripts/assets/database/TitlesDB_PS2.csv"
            folders_to_scan = [('/DVD', ['.iso', '.zso']), ('/CD', ['.iso', '.zso'])]
        elif games_list_path.endswith("pfs-pops.list"):
            gameid_file_path = "./scripts/assets/database/TitlesDB_PS1.csv"
            folders_to_scan = [('/__.POPS', ['.vcd', '.VCD'])]
        elif games_list_path.endswith("ember.list"):
            gameid_file_path = "./scripts/assets/database/TitlesDB_PS1.csv"
            folders_to_scan = []
        else:
            print("Error: Output list must end with either 'ps2.list', 'ember.list', or `pfs-pops.list`.")
            sys.exit(1)

        # Remove any existing game list file
        if os.path.isfile(games_list_path):
            os.remove(games_list_path)

        # Build list of files to process
        if games_list_path.endswith("ember.list"):
            all_targets = process_ember_targets()

        else:
            all_targets = []

            for folder, extensions in folders_to_scan:
                full_path = os.path.join(game_path, folder.strip("/"))

                if not os.path.isdir(full_path):
                    print(f'{folder} not found at {game_path}')
                    sys.exit(1)

                for image in os.listdir(full_path):
                    if image.startswith('.'):
                        continue
                    if any(image.lower().endswith(ext) for ext in extensions):
                        all_targets.append((folder.strip("/"), image))

        process_files(all_targets)

if __name__ == "__main__":
    if len(sys.argv) == 3:
        hide_cursor()
        main(sys.argv[1], sys.argv[2])
        show_cursor()
    else:
        print("Usage: build-list.py <game_path> <output_list_path>")

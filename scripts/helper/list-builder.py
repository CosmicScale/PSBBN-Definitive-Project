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
import math
import re
import lz4.block
from struct import unpack

done = "Error: No games found."
total = 0
count = 0

ZISO_MAGIC = 0x4F53495A
SECTOR_SIZE = 2048

pattern_1 = [b'\x01', b'\x0D']
pattern_2 = [b'\x3B', b'\x31']

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

def extract_game_id_from_disc(fin, sector_reader):
    # Common logic to extract Game ID from SYSTEM.CNF (ISO or ZSO).
    # Step 1: Read PVD (sector 16)
    pvd = sector_reader(16, 1)

    # Root dir record is at offset 0x9C inside PVD
    root_dir_record = pvd[156:156+34]
    root_lba = int.from_bytes(root_dir_record[2:6], "little")
    root_size = int.from_bytes(root_dir_record[10:14], "little")

    # Step 2: Read root directory
    num_sectors = (root_size + SECTOR_SIZE - 1) // SECTOR_SIZE
    root_data = sector_reader(root_lba, num_sectors)

    # Step 3: Parse entries
    entries = parse_dir_entries(root_data)
    for name, lba, size in entries:
        if name.upper().startswith("SYSTEM.CNF"):
            num_sectors = (size + SECTOR_SIZE - 1) // SECTOR_SIZE
            system_cnf = sector_reader(lba, num_sectors)
            cnf_text = system_cnf.decode("utf-8", errors="ignore")

            for line in cnf_text.splitlines():
                if line.strip().upper().startswith("BOOT2"):
                    return line.split("\\")[-1].split(";")[0].upper()
    return None

# Function to process game files in the given folder
def process_files(folder, extensions):
    global total, count, done

    game_names = {}
    if os.path.isfile(gameid_file_path):
        with open(gameid_file_path, 'r') as gameid_file:
            for line in gameid_file:
                parts = line.strip().split('|')  # Split title ID and game name
                if len(parts) == 3:
                    game_names[parts[0]] = (parts[1], parts[2])

    # Prepare a list to hold all game list entries
    game_list_entries = []

    for image in os.listdir(game_path + folder):
        if image.startswith('.'):
            continue  # skip hidden files
        if not any(image.lower().endswith(ext) for ext in extensions):
            continue  # skip files that are not in the extension list
        print('Processing', image)
        string = ""
        original_image = image

        file_path = os.path.join(game_path + folder, image)

        # Extract Game ID from filename if it meets the condition
        file_name_without_ext = os.path.splitext(image)[0]
        if len(file_name_without_ext) >= 11 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.':
            string = file_name_without_ext[:11].upper()
            print(f"Filename meets condition. Game ID set directly from filename: {string}")

        # ISO
        if image.lower().endswith('.iso') and not string:
            with open(file_path, "rb") as fin:
                def iso_reader(sector, num_sectors=1):
                    return read_iso_sector(fin, sector, num_sectors)
                string = extract_game_id_from_disc(fin, iso_reader) or ""

        # ZSO
        if image.lower().endswith('.zso') and not string:
            with open(file_path, "rb") as fin:
                magic, header_size, total_bytes, block_size, ver, align = read_zso_header(fin)
                if magic != ZISO_MAGIC:
                    print(f"Skipping invalid ZSO: {image}")
                else:
                    total_blocks = total_bytes // block_size
                    index_buf = [unpack('I', fin.read(4))[0] for _ in range(total_blocks + 1)]

                    def zso_reader(sector, num_sectors=1):
                        return decompress_zso_sector(fin, index_buf, block_size, align, sector, num_sectors)

                    string = extract_game_id_from_disc(fin, zso_reader) or ""

        # VCD
        if image.lower().endswith('.vcd') and not string:
            with open(game_path + folder + "/" + image, "rb") as file:
                for raw_line in file:
                    line = raw_line.strip()
                    line_lower = line.lower()
                    if b'cdrom:' in line_lower and b'boot' in line_lower:

                        idx = line_lower.find(b'cdrom:') + len(b'cdrom:')
                        segment = line[idx:].split(b';', 1)[0]

                        raw_bytes = segment.split(b'\\')[-1]
                        string = raw_bytes.decode('utf-8', errors='ignore').upper()

                        if len(string) == 11 and string[4] != '_':
                            string = string[:4] + '_' + string[5:]
                        break
        
        # Fallback for ISO and VCD
        if (len(string) < 11 or len(string) > 12) and (image.lower().endswith('.iso') or image.lower().endswith('.vcd')):
            with open(file_path, "rb") as f:
                data_to_scan = f.read()  # Scan the entire file

            index = 0
            string = ""
            for byte in data_to_scan:
                if len(string) < 4:
                    if index == 2:
                        string += chr(byte)
                    elif byte == pattern_1[index][0]:
                        index += 1
                    else:
                        string = ""
                        index = 0
                elif len(string) == 4:
                    index = 0
                    if byte in (0x5F, 0x2D):
                        string += '_'
                    else:
                        string = ""
                elif len(string) < 8:
                    string += chr(byte)
                elif len(string) == 8:
                    if byte == 0x2E:
                        string += '.'
                    else:
                        string = ""
                elif len(string) < 11:
                    string += chr(byte)
                elif len(string) == 11:
                    if byte == pattern_2[index][0]:
                        index += 1
                        if index == 2:
                            # Check for "CDDA_END.DA"
                            if string == "CDDA_END.DA":
                                # Reset and continue scanning
                                string = ""
                                index = 0
                                continue
                            else:
                                # If not CDDA_END.DA, handle normally (e.g., match found)
                                break
                    else:
                        string = ""
                        index = 0

        # If no Game ID is found, generate one from filename
        if not string:
            # Remove spaces from filename and convert to uppercase
            base_name = os.path.splitext(image)[0]  # Strip the file extension
            string = re.sub(r'[^A-Z0-9]', '', base_name.upper())  # Keep only A-Z and 0-9

            # Trim the string to 9 characters or pad with zeros
            string = string[:9].ljust(9, '0')

            # Insert the underscore at position 5 and the full stop at position 9
            string = string[:4] + '_' + string[4:7] + '.' + string[7:]

            # Ensure the string is exactly 11 characters long
            string = string[:11]

            print(f'No Game ID found. Generating Game ID based on filename: {string}')

        string = string.upper()

        # Determine game name and publisher
        entry = game_names.get(string)
        if entry:
            game_name, publisher = entry
            if not game_name:
                game_name = os.path.splitext(image)[0]
                publisher = ""
        else:
            base_name = os.path.splitext(image)[0]
            # If filename begins with the Game ID, strip it off
            if base_name.upper().startswith(string):
                # also strip optional separators like '_' or '.'
                stripped = base_name[len(string):].lstrip('_. ')
                game_name = stripped if stripped else base_name
            else:
                game_name = base_name
            publisher = ""
            
        print(f"Game ID '{string}' -> Game='{game_name}', Publisher='{publisher}'")

        # Add to game list entries
        folder_image = f"{folder.replace('/', '', 1)}|{original_image}"
        game_list_entries.append(f"{game_name}|{string}|{publisher}|{folder_image}")

        count += 1
        print(math.floor((count * 100) / total), '% complete')

    if game_list_entries:
        with open(games_list_path, "a") as output:
            for entry in game_list_entries:
                output.write(f"{entry}\n")

    done = "Done!"

def main(arg1, arg2):
    if arg1 and arg2:
        global game_path
        global games_list_path
        global gameid_file_path
        game_path = arg1
        games_list_path = arg2

        # Set correct TitlesDB path based on output list name
        if games_list_path.endswith("ps2.list"):
            gameid_file_path = "./scripts/helper/TitlesDB_PS2_English.csv"
            folders_to_scan = [('/DVD', ['.iso', '.zso']), ('/CD', ['.iso', '.zso'])]
        elif games_list_path.endswith("ps1.list"):
            gameid_file_path = "./scripts/helper/TitlesDB_PS1_English.csv"
            folders_to_scan = [('/POPS', ['.vcd', '.VCD'])]
        else:
            print("Error: Output list must end with either 'ps2.list' or 'ps1.list'.")
            sys.exit(1)

        # Remove any existing game list file
        if os.path.isfile(games_list_path):
            os.remove(games_list_path)

        # Count files
        for folder, extensions in folders_to_scan:
            if os.path.isdir(game_path + folder):
                count_files(folder, extensions)
            else:
                print(f'{folder} not found at ' + game_path)
                sys.exit(1)

        if total == 0:
            if games_list_path.endswith("ps2.list"):
                print("No PS2 games found in the CD or DVD folder.")
            elif games_list_path.endswith("ps1.list"):
                print("No PS1 games found in the POPS folder.")
            sys.exit(0)

        # Process files
        for folder, extensions in folders_to_scan:
            if os.path.isdir(game_path + folder):
                process_files(folder, extensions)

        print(done)

if __name__ == "__main__":
    if len(sys.argv) == 3:
        main(sys.argv[1], sys.argv[2])
    else:
        print("Usage: build-list.py <game_path> <output_list_path>")

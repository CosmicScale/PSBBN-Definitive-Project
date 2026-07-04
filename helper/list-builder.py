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
import subprocess
import math
import re
import shlex

done = "Error: No games found."
total = 0
count = 0
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
            continue  # Skip hidden files
        if any(image.lower().endswith(ext) for ext in extensions):
            print('Processing', image)
            index = 0
            string = ""

            original_image = image  # Store the original filename (e.g., `.zso` or `.iso`)
            converted_iso = False


            # Check the filename condition for all files
            file_name_without_ext = os.path.splitext(image)[0]
            if len(file_name_without_ext) >= 9 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.':
                # Filename meets the condition, directly set the game ID
                string = file_name_without_ext[:11].upper()
                print(f"Filename meets condition. Game ID set directly from filename: {string}")

            # If the file has a .zso extension and no ID was set, convert to .iso
            if image.lower().endswith('.zso') and not string:
                zso_path = os.path.join(game_path + folder, image)
                iso_path = os.path.join(game_path + folder, os.path.splitext(image)[0] + '.iso')

                command = (
                    f'echo "Converting {image} from .zso to .iso..." && '
                    f"python3 ./helper/ziso.py -c 0 {shlex.quote(zso_path)} {shlex.quote(iso_path)}"
                )

                try:
                    subprocess.run(command, shell=True, check=True, executable='/bin/bash')
                    # Update image to the new .iso path for processing
                    image = os.path.basename(iso_path)
                    converted_iso = True  # Mark the .iso file as being converted from .zso
                except subprocess.CalledProcessError:
                    print(f"Error: Conversion of {image} failed. Deleting {iso_path}.")
                    if os.path.exists(iso_path):
                        os.remove(iso_path)
                    sys.exit(1)  # Exit script on failure

            # Extract the game ID from the file content if not set by the filename
            if not string:  # Only process if the game ID is not set from the filename
                with open(game_path + folder + "/" + image, "rb") as file:
                    max_bytes_to_read = 5 * 1024 * 1024  # Read max 5 MB of file to find ID
                    bytes_read = 0
        
                    while (byte := file.read(1)) and bytes_read < max_bytes_to_read:
                        bytes_read += 1

                        if len(string) < 4:
                            if index == 2:
                                string += byte.decode('utf-8', errors='ignore')
                            elif byte == pattern_1[index]:
                                index += 1
                            else:
                                string = ""
                                index = 0
                        elif len(string) == 4:
                            index = 0
                            if byte == b'\x5F':
                                string += byte.decode('utf-8', errors='ignore')
                            else:
                                string = ""
                        elif len(string) < 8:
                            string += byte.decode('utf-8', errors='ignore')
                        elif len(string) == 8:
                            if byte == b'\x2E':
                                string += byte.decode('utf-8', errors='ignore')
                            else:
                                string = ""
                        elif len(string) < 11:
                            string += byte.decode('utf-8', errors='ignore')
                        elif len(string) == 11:
                            if byte == pattern_2[index]:
                                index += 1
                                if index == 2:
                                    break
                            else:
                                string = ""
                                index = 0

            if not string:
                with open(game_path + folder + "/" + image, "rb") as file:
                    data = file.read()

                patterns = [
                    b"BOOT=cdrom:\\",
                    b"BOOT2=cdrom0:\\",
                    b"BOOT = cdrom:\\",
                    b"BOOT2 = cdrom0:\\",
                ]

                for search_bytes in patterns:
                    pos = data.find(search_bytes)
                    if pos != -1:
                        start = pos + len(search_bytes)
                        raw_bytes = data[start:start+12]

                        # Trim at semicolon if found
                        end = raw_bytes.find(b';')
                        if end != -1:
                            raw_bytes = raw_bytes[:end]

                        string = raw_bytes.decode('utf-8', errors='ignore')
                        # Fix the 5th character if the string is 11 characters long
                        if len(string) == 11 and string[4] != '_':
                            string = string[:4] + '_' + string[5:]
                        break

            # If no Game ID is found, generate one from filename
            if len(string) < 11 or len(string) > 12:
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


            # Rename the original `.zso` file to begin with the `gameid`
            if converted_iso:
                new_filename = f"{string}.{original_image}"
                new_zso_path = os.path.join(game_path + folder, new_filename)
                os.rename(zso_path, new_zso_path)
                print(f"Renamed {original_image} to {new_filename}")
                original_image = new_filename  # Update the original image reference

            # Determine game name and publisher
            entry = game_names.get(string)
            if entry:
                # If we found a match in the CSV
                game_name = entry[0] if entry[0] else None  # If game name is empty, set to None
                publisher = entry[1] if len(entry) > 1 and entry[1] else ""
                if not game_name:  # If game name is None (i.e., found in CSV but empty)
                    print(f"Game ID '{string}' found in CSV, but title is missing. Using filename logic.")
                    file_name_without_ext = os.path.splitext(image)[0]
                    if len(file_name_without_ext) >= 12 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.' and file_name_without_ext[11] == '.':
                        game_name = file_name_without_ext[12:]  # Fallback to part after the game ID
                    else:
                        game_name = file_name_without_ext  # Use the filename as-is
                    publisher = ""  # Publisher will remain empty in this case
                print(f"Match found: ID='{string}' -> Game='{game_name}', Publisher='{publisher}'")
            else:
                # If no match found in CSV, use filename logic for game name
                print(f"No match found for ID '{string}'")
                file_name_without_ext = os.path.splitext(image)[0]
                if len(file_name_without_ext) >= 12 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.' and file_name_without_ext[11] == '.':
                    game_name = file_name_without_ext[12:]
                else:
                    game_name = file_name_without_ext
                publisher = ""
                print(f"Default game name from filename: '{game_name}'")

            # Format entry with game name, game ID, publisher, and updated original image info
            folder_image = f"{folder.replace('/', '', 1)}|{original_image}"
            game_list_entry = f"{game_name}|{string}|{publisher}|{folder_image}"
            game_list_entries.append(game_list_entry)

            # If the file was converted from .zso to .iso, delete the .iso file
            if converted_iso:
                os.remove(game_path + folder + "/" + image)
                print(f"Deleted the temporary ISO file: {image}")

            count += 1
            print(math.floor((count * 100) / total), '% complete')

    # Write all entries to the list file
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
            gameid_file_path = "./helper/TitlesDB_PS2_English.csv"
            folders_to_scan = [('/DVD', ['.iso', '.zso']), ('/CD', ['.iso', '.zso'])]
        elif games_list_path.endswith("ps1.list"):
            gameid_file_path = "./helper/TitlesDB_PS1_English.csv"
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

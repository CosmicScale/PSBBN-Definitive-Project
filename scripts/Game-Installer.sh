#!/usr/bin/env bash
#
# Game Installer form the PSBBN Definitive Project
# Copyright (C) 2024-2026 CosmicScale
#
# <https://github.com/CosmicScale/PSBBN-Definitive-Project>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

[[ -t 0 && -t 1 ]] || exit 1

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

term_width=110

version_check="4.0.0"

# Set paths
TOOLKIT_PATH="$(pwd)"
ICONS_DIR="${TOOLKIT_PATH}/icons"
ARTWORK_DIR="${ICONS_DIR}/art"
VMC_ICON_DIR="${ICONS_DIR}/ico/vmc"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
. "${SCRIPTS_DIR}/platform/load.sh"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
POPS_DIR="${SCRIPTS_DIR}/tmp/POPS"
NEUTRINO_DIR="${ASSETS_DIR}/neutrino"
DATABASE_DIR="${ASSETS_DIR}/database"
LOGS_DIR="${TOOLKIT_PATH}/logs"
LOG_FILE="${LOGS_DIR}/game-installer.log"
MISSING_ART="${LOGS_DIR}/missing-art.log"
MISSING_APP_ART="${LOGS_DIR}/missing-app-art.log"
MISSING_ICON="${LOGS_DIR}/missing-icon.log"
MISSING_VMC="${LOGS_DIR}/missing-vmc.log"
GAMES_PATH="${TOOLKIT_PATH}/games"
CONFIG_FILE="${SCRIPTS_DIR}/gamepath.cfg"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
# macOS writes AppleDouble files when this path is under /var. /tmp does not.
if [[ "$(uname -s)" == Darwin ]]; then
    STORAGE_DIR="/tmp/psbbn-storage-${UID}"
fi
OPL="${SCRIPTS_DIR}/OPL"
PFS_POPS_LIST="${SCRIPTS_DIR}/tmp/pfs-pops.list"
EMBER_LIST="${SCRIPTS_DIR}/tmp/ember.list"
PS1_LIST="${SCRIPTS_DIR}/tmp/ps1.list"
PS1_JPN_LIST="${SCRIPTS_DIR}/tmp/ps1-jpn.list"
PS2_LIST="${SCRIPTS_DIR}/tmp/ps2.list"
PS2_JPN_LIST="${SCRIPTS_DIR}/tmp/ps2-jpn.list"
EXT_POPS_LIST="${SCRIPTS_DIR}/tmp/ext-pops.list"
POPS_JPN_LIST="${SCRIPTS_DIR}/tmp/pops-jpn.list"
TMP_LIST="${SCRIPTS_DIR}/tmp/tmp.list"
ALL_TITLES="${SCRIPTS_DIR}/tmp/titles.list"
SELECTED_LIST="${SCRIPTS_DIR}/tmp/selected.list"
APPS_LIST="${SCRIPTS_DIR}/tmp/app.list"
PS1_DATABASE="${ASSETS_DIR}/database/TitlesDB_PS1.csv"
OSDMENU_CNF="${SCRIPTS_DIR}/tmp/OSDMENU.CNF"
OSDMBR_CNF="${SCRIPTS_DIR}/tmp/OSDMBR.CNF"
OPLMS='https://oplmanager.com/API/V6/OplManagerService.asmx'

arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    POPS2CUE="${HELPER_DIR}/pops2cue"
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/sqlite"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    POPS2CUE="${HELPER_DIR}/aarch64/pops2cue"
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/aarch64/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/aarch64/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/aarch64/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/aarch64/sqlite"
fi

LINUX_PARTITIONS=("__linux.7" )

LANG_FILE="$1"
shift  # remove language
 
if [[ -n "$1" ]] && [[ "$1" == /* ]]; then
    path_arg="$1"
fi

declare -A UI_TEXT

if [[ -f "${LANG_DIR}/$LANG_FILE.txt" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        UI_TEXT["$key"]="$value"
    done < "${LANG_DIR}/$LANG_FILE.txt"
else
    echo "[X] Error: Language file not found."
    sleep 3
    exit 1
fi

text_width() {
    python3 -c '
from wcwidth import wcswidth
import sys
print(wcswidth(sys.argv[1]))
' "$1"
}

center_title() {
    local text=" $1 "

    local text_len
    text_len=$(text_width "$text")

    local total_padding=$(( term_width - text_len ))

    # Prevent negative padding
    (( total_padding < 0 )) && total_padding=0

    local left_padding=$(( total_padding / 2 ))
    local right_padding=$(( total_padding - left_padding ))

    printf '%*s' "$left_padding" '' | tr ' ' '='
    printf '%s' "$text"
    printf '%*s\n' "$right_padding" '' | tr ' ' '='
}

center_text() {
    local input="$1"

    local display_width
    display_width=$(text_width "$input")

    local padding=$(( (term_width - display_width) / 2 ))

    (( padding < 0 )) && padding=0

    text=$(printf "%*s%s" "$padding" "" "$input")
}

if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")

    if [ "$size" -gt 4194304 ]; then
        : > "$LOG_FILE"
    fi
fi

center_menu() {
    local longest=0

    for key in "${MENU_KEYS[@]}"; do
        local text="${UI_TEXT[$key]}"
        local width=$(text_width "$text")

        (( width > longest )) && longest=$width
    done

    padding=$(( (term_width - longest) / 2 ))
}

prevent_sleep_start() {
    if command -v xdotool >/dev/null; then
        (
            while true; do
                xdotool key shift >/dev/null 2>&1
                sleep 50
            done
        ) &
        SLEEP_PID=$!

    elif command -v dbus-send >/dev/null; then
        if dbus-send --session --dest=org.freedesktop.ScreenSaver \
            --type=method_call --print-reply \
            /ScreenSaver org.freedesktop.DBus.Introspectable.Introspect \
            >/dev/null 2>&1; then

            (
                while true; do
                    dbus-send --session \
                        --dest=org.freedesktop.ScreenSaver \
                        --type=method_call \
                        /ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity \
                        >/dev/null 2>&1
                    sleep 50
                done
            ) &
            SLEEP_PID=$!

        elif dbus-send --session --dest=org.kde.screensaver \
            --type=method_call --print-reply \
            /ScreenSaver org.freedesktop.DBus.Introspectable.Introspect \
            >/dev/null 2>&1; then

            (
                while true; do
                    dbus-send --session \
                        --dest=org.kde.screensaver \
                        --type=method_call \
                        /ScreenSaver org.kde.screensaver.simulateUserActivity \
                        >/dev/null 2>&1
                    sleep 50
                done
            ) &
            SLEEP_PID=$!
        fi
    fi
}

prevent_sleep_stop() {
    if [[ -n "$SLEEP_PID" ]]; then
        kill "$SLEEP_PID" 2>/dev/null
        wait "$SLEEP_PID" 2>/dev/null
        unset SLEEP_PID
    fi
}

error_msg() {
    type=$1
    error_1="$2"
    error_2="$3"
    error_3="$4"
    error_4="$5"
    error_5="$6"

    echo;echo
    if [ "$type" = "Error" ]; then
        echo "[X] $error_1"
    else
        echo "[!] $error_1"
    fi
    echo
    [ -n "$error_2" ] && echo "$error_2"
    [ -n "$error_3" ] && echo "$error_3"
    [ -n "$error_4" ] && echo "$error_4"
    [ -n "$error_5" ] && echo "$error_5"
    echo
    if [ "$type" = "Error" ]; then
        echo "${UI_TEXT[ERROR_TROUBLE]}"
        echo "${UI_TEXT[TROUBLE_URL]}"
        echo
        read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
        echo
        exit 1;
    else
        read -n 1 -s -r -p "${UI_TEXT[CONTINUE]}" </dev/tty
        echo
    fi
}

clean_up() {
    # The installer can be inside one of the folders removed below.
    cd "${TOOLKIT_PATH}"
    failure=0

    # Remove unwanted directories inside $ICONS_DIR except 'art' and 'ico'
    for item in "$ICONS_DIR"/*; do
        if [ -d "$item" ] && [[ $(basename "$item") != art && $(basename "$item") != ico ]]; then
            sudo rm -rf "$item"
        fi
    done

    # Remove all directories inside ${GAMES_PATH}/APPS
    find "${GAMES_PATH}/APPS/" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
        sudo rm -rf -- "$dir"
    done

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1

    # Remove listed files
    sudo rm -rf "${ARTWORK_DIR}/tmp" "${ICONS_DIR}/ico/tmp" "${SCRIPTS_DIR}/tmp" 2>>"$LOG_FILE" \
        || { echo "[X] Error: Failed to remove tmp files." >> "${LOG_FILE}"; failure=1; }

    unmount_apa

    if [ -d "${STORAGE_DIR}" ]; then
        submounts=$(
            findmnt -nr -o TARGET \
            | sed 's/\\x20/ /g' \
            | grep "^${STORAGE_DIR}/" \
            | sort -r
        )

        if [ -z "$submounts" ]; then
            echo "Deleting ${STORAGE_DIR}..." >> "$LOG_FILE"
            sudo rm -rf "${STORAGE_DIR}" || { echo "[X] Error: Failed to delete ${STORAGE_DIR}" >> "$LOG_FILE"; failure=1; }
            echo "Deleted ${STORAGE_DIR}." >> "$LOG_FILE"
        else
            echo "[X] Error: Some mounts remain under ${STORAGE_DIR}, not deleting." >> "$LOG_FILE"
            failure=1
        fi
    else
        echo "Directory ${STORAGE_DIR} does not exist." >> "$LOG_FILE"
    fi

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo "[X] Error: Cleanup error(s) occurred. Aborting." >> "$LOG_FILE"
        error_msg "Error" "${UI_TEXT[ERROR_CLEANUP]}"
    fi

}

exit_script() {
    prevent_sleep_stop
    
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${LOGS_DIR}/ps2-id.log" "${LOGS_DIR}/ember-id.log" "${LOGS_DIR}/pfs-pops-id.log" "${path_arg}" > /dev/null 2>&1
    fi
}

show_progress() {
    local current=$1
    local total=$2
    local width=96

    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    local bar=""

    (( filled > 0 )) && \
        bar=$(printf '█%.0s' $(seq 1 "$filled"))

    (( empty > 0 )) && \
        bar+=$(printf '░%.0s' $(seq 1 "$empty"))

    printf "\r%3d%%|%s| %d/%d" \
        "$percent" "$bar" "$current" "$total"
}

download_files() {
    # Check if dep.zip exists
    if [[ -f "${ASSETS_DIR}/dep.zip" && ! -f "${ASSETS_DIR}/dep.zip.st" ]]; then
        echo "dep.zip found in ${ASSETS_DIR}. Extracting..." >> "${LOG_FILE}"
        bsdtar -xf "${ASSETS_DIR}/dep.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
    else
        echo "Downloading..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[DOWNLOAD_LATEST_FILE_2]} dep.zip"
        wget --quiet --timeout=10 --tries=3 -O "${ASSETS_DIR}/dep.zip" https://archive.org/download/psbbn-definitive-project-dependencies/dep.zip
        echo
        if [[ -s "${ASSETS_DIR}/dep.zip" ]]; then
            bsdtar -xf "${ASSETS_DIR}/dep.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        else
            rm "${ASSETS_DIR}/dep.zip"
            echo "[X] Warning: Download failed for PS1 BIOS." >> "${LOG_FILE}" 2>&1
            error_msg "Warning" "${UI_TEXT[ERROR_LATEST_FILE_1]} PS1 BIOS." "${UI_TEXT[GET_LATEST_FILE_3]}"
        fi
    fi
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to unmount $DEVICE" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_UNMOUNT_1]} $DEVICE"
    fi
}

MOUNT_OPL() {
    echo "Mounting OPL partition..." >> "${LOG_FILE}" 2>&1
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${OPL}"
    }

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        echo "[X] Error: Failed to mount ${DEVICE}3" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_MOUNT_2]} ${DEVICE}3"
    fi

    # Create necessary folders if they don't exist
    mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,POPS,nhddl,Ember/games} 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create OPL folders." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_OPL_FOLDER]}"
    }
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_HDL_TOC]}"
    fi
}

CHECK_PARTITIONS() {

    # only grab the partition name column from lines that begin with 0x0100 or 0x0001
    mapfile -t names < <(grep -E '^0x0[01][0-9A-Fa-f]{2}' "${hdl_output}" | awk '{print $NF}')

    has_all() {
        local targets=("$@")
        for t in "${targets[@]}"; do
            local found=false
            for n in "${names[@]}"; do
                if [[ "$n" == "$t" ]]; then
                    found=true
                    break
                fi
            done
            # If any required partition is missing, return failure immediately
            $found || return 1
        done
        return 0  # all partitions found
        }

    psbbn_parts=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.8 __linux.9 __contents)
    hosd_parts=(__system __sysconf __common)

    # Check for __.POPS regardless of OS detection
    if has_all "__.POPS"; then
        PFS_PARTITIONS=("__common" "__system" "__sysconf" "__.POPS" )
        POPS_PRESENT=1

    else
        POPS_PRESENT=0
        PFS_PARTITIONS=("__common" "__system" "__sysconf" )
    fi

    if has_all "${psbbn_parts[@]}"; then
        echo "PSBBN Detected" >> "${LOG_FILE}"
        OS="PSBBN"
    elif has_all "${hosd_parts[@]}"; then
        echo "HOSDMenu Detected" >> "${LOG_FILE}"
        OS="HOSD"
    else
        echo "[X] Error: Failed to detect PSBBN or HOSDMenu on ${DEVICE}."
        error_msg "Error" "${UI_TEXT[ERROR_OS_CHECK_1]}"
    fi

}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    echo "[X] Error: PFS Shell returned an error." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_PFS_COMMANDS]}"
fi
}

process_psu_files() {
    local target_dir="$1"

    psu_count=$(find "$target_dir" -maxdepth 1 -type f -iname "*.psu" | wc -l)
    if [ "$psu_count" -gt 0 ]; then
        SPLASH
        echo "Processing PSU files in: $target_dir..." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_PSU_1]} $target_dir..."

        i="0"
        for file in "$target_dir"/*.psu "$target_dir"/*.PSU; do
            [ -e "$file" ] || continue  # Skip if no PSU files exist

            echo "Extracting $file..." >> "${LOG_FILE}"
            "${PSU_EXTRACT}" "$file" -f >> "${LOG_FILE}" 2>&1
            i=$((i + 1))
            show_progress "$i" "$psu_count"
        done
    fi
}

CREATE_PS1_VMC() {
    local games_dir="${OPL}/Ember/games"
    local folder file extension
    local -a cue_files
    declare -A disc_groups
    declare -A vmc_groups_by_id
    declare -A processed_disc_groups
    declare -A removed_folders
    current_group=""

    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating VMCs for PS1 games..." >> "${LOG_FILE}"
    echo -n "${UI_TEXT[CREATE_PS1_VMC]}"

    # First pass: Group file names by base title
    exec 3< "${EMBER_LIST}"
    while IFS='|' read -r title game_id publisher disc_type folder_name jpn_title partition_label <&3; do
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"  # Remove trailing space
        disc_groups["$base_title"]+="$title|$folder_name"$'\n'
    done
    exec 3<&-

    exec 3< "${ASSETS_DIR}/database/ps1_vmc_groups.list"
    while IFS= read -r line <&3; do
        line="${line%%$'\r'}"  # Remove trailing carriage return (CR)
        [[ -z "$line" ]] && continue

        if [[ "$line" == GP_* ]]; then
            current_group="$line"
        elif [[ $line =~ ^[A-Z]{4}_[0-9]{3}\.[0-9]{2} ]]; then
            game_id="${line%%|*}"
            vmc_groups_by_id["$game_id"]="$current_group"
        fi
    done
    exec 3<&-

    # Process multi-disc games
    exec 3< "$EMBER_LIST"
    while IFS='|' read -r title game_id publisher disc_type folder_name jpn_title partition_label <&3; do
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"

        # Process each multi-disc group only once
        [[ ${processed_disc_groups[$base_title]+yes} ]] && continue
        processed_disc_groups["$base_title"]=1

        # Split the group into individual entries
        entries=()
        mapfile -t entries <<< "${disc_groups[$base_title]}"

        ((${#entries[@]} > 1)) || continue

        # Identify the entry with the lowest disc number
        first_entry=""
        lowest_disc=""

        for entry in "${entries[@]}"; do
            entry_title="${entry%%|*}"

            if [[ "$entry_title" =~ \(Disc[[:space:]]*([0-9]+)\) ]]; then
                disc_number="${BASH_REMATCH[1]}"

                if [[ -z "$lowest_disc" ]] || (( disc_number < lowest_disc )); then
                    lowest_disc="$disc_number"
                    first_entry="$entry"
                fi
            fi
        done

        # Skip if no valid disc number was found
        [[ -n "$first_entry" ]] || continue

        first_folder="${first_entry##*|}"
        first_path="${OPL}/Ember/games/${first_folder}"

        [[ -d "$first_path" ]] || continue

        # First pass: collect every disc's CUE filename
        disc_list=()

        for ((i = 0; i < ${#entries[@]}; i++)); do
            disc_entry="${entries[i]}"
            disc_folder="${disc_entry##*|}"
            disc_path="${OPL}/Ember/games/${disc_folder}"

            cue_file=""

            if [[ -d "$disc_path" ]]; then
                for file in "$disc_path"/*; do
                    [[ -f "$file" ]] || continue

                    extension="${file##*.}"
                    if [[ "${extension,,}" == "cue" ]]; then
                        cue_file="${file##*/}"
                        break
                    fi
                done
            fi

            if [[ -n "$cue_file" ]]; then
                disc_list+=("$cue_file")
            else
                echo "WARNING: No CUE file found for '$disc_folder'" \
                    >> "${LOG_FILE}"
            fi
        done

        # Second pass: move BIN and CUE files from discs 2+
        for ((i = 1; i < ${#entries[@]}; i++)); do
            disc_entry="${entries[i]}"
            disc_folder="${disc_entry##*|}"
            disc_path="${OPL}/Ember/games/${disc_folder}"

            [[ -d "$disc_path" ]] || continue

            moved_any=0

            for file in "$disc_path"/*; do
                [[ -f "$file" ]] || continue

                extension="${file##*.}"

                case "${extension,,}" in
                    bin|cue)
                        if mv "$file" "$first_path/" 2>/dev/null; then
                            moved_any=1
                            mv "${GAMES_PATH}/Ember/${disc_folder}/${file##*/}" "${GAMES_PATH}/Ember/${first_folder}/" >/dev/null 2>&1
                        else
                            echo "ERROR: Failed to move file: $file" >> "${LOG_FILE}"
                        fi
                        ;;
                esac
            done

            # Check whether any BIN or CUE files remain
            remaining=0

            for file in "$disc_path"/*; do
                [[ -f "$file" ]] || continue

                extension="${file##*.}"
                case "${extension,,}" in
                    bin|cue)
                        remaining=1
                        break
                        ;;
                esac
            done

            # Remove the folder and its EMBER_LIST entry if all
            # BIN/CUE files were moved successfully
            if ((moved_any && !remaining)); then
                removed_folders["$disc_folder"]=1
                rmdir "$disc_path" 2>/dev/null
                rmdir "${GAMES_PATH}/Ember/${disc_folder}" 2>/dev/null
            fi
        done
    done
    exec 3<&-

    # Remove successfully consolidated disc entries from EMBER_LIST
    if ((${#removed_folders[@]} > 0)); then
        temp_list="${EMBER_LIST}.tmp.$$"

        while IFS= read -r line || [[ -n "$line" ]]; do
            IFS='|' read -r title game_id publisher disc_type folder_name jpn_title partition_label \
                <<< "$line"

            if [[ -n "${removed_folders[$folder_name]+yes}" ]]; then
                continue
            fi

            printf '%s\n' "$line"
        done < "$EMBER_LIST" > "$temp_list"

        if mv "$temp_list" "$EMBER_LIST"; then
            :
        else
            echo "ERROR: Failed to update $EMBER_LIST" >> "${LOG_FILE}"
            rm -f "$temp_list"
        fi
    fi

    for folder in "$games_dir"/*/; do
        [[ -d "$folder" ]] || continue

        cue_files=()

        # Find all CUE files in this folder
        for file in "$folder"/*; do
            [[ -f "$file" ]] || continue

            extension="${file##*.}"
            [[ "${extension,,}" == "cue" ]] || continue

            cue_files+=("${file##*/}")
        done

        # Only create DISCS.TXT when there is more than one CUE
        ((${#cue_files[@]} > 1)) || continue

        # Sort filenames alphabetically
        mapfile -t cue_files < <(
            printf '%s\n' "${cue_files[@]}" | LC_ALL=C sort
        )

        # Write the list
        printf '%s\n' "${cue_files[@]}" > "${folder}DISCS.TXT"
    done

    exec 3< "$EMBER_LIST"
    while IFS='|' read -r title game_id publisher disc_type folder_name jpn_title partition_label <&3; do
    # Check if game ID exists in VMC group mapping and make group VMC if necessary
        if [[ -n "${vmc_groups_by_id[$game_id]}" ]]; then
            VMC_GROUP_FOLDER="${vmc_groups_by_id[$game_id]}"
            mkdir -p "${OPL}/Ember/games/${VMC_GROUP_FOLDER}"
            printf "%s" "${vmc_groups_by_id[$game_id]}" > "${OPL}/Ember/games/$folder_name/SharedMC.txt"
        fi
    done
    exec 3<&-
    echo
}

CREATE_PS2_VMC() {

    declare -A vmc_groups_by_id
    declare -A vmc_sizes_by_group
    current_group=""
    current_size="8"
    i="0"

    SPLASH
    echo "Creating VMCs for PS2 games..." >> "${LOG_FILE}"
    echo "${UI_TEXT[CREATE_PS2_VMC]}"

    # Compile genvmc if not already compiled
    if [[ ! -x "${HELPER_DIR}/genvmc" ]]; then
        echo >> "${LOG_FILE}"
        echo "Compiling genvmc..." >> "${LOG_FILE}"
        if ! gcc -std=gnu99 -o "${HELPER_DIR}/genvmc" "${HELPER_DIR}/genvmc.c" >> "${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to compile genvmc." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE_PS2_VMC]}"
        fi
    fi

    # Parse ps2_vmc_groups.list
    exec 3< "${ASSETS_DIR}/database/ps2_vmc_groups.list"
    while IFS= read -r line <&3; do
        line="${line%%$'\r'}"
        [[ -z "$line" ]] && continue

        if [[ "$line" == XEBP_* ]]; then
            current_group="${line%%|*}"
            size_field="${line#*|}"
            if [[ "$size_field" != "$current_group" ]]; then
                current_size="$size_field"
            else
                current_size="8"
            fi
            vmc_sizes_by_group["$current_group"]="$current_size"
        elif [[ $line =~ ^[A-Z]{4}_[0-9]{3}\.[0-9]{2} ]]; then
            vmc_groups_by_id["$line"]="$current_group"
        fi
    done
    exec 3<&-

    # Track which VMC .bin files have been created
    declare -A created_vmcs

    # Process each PS2 game
    exec 3< "${PS2_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do

        # Determine VMC name and size
        if [[ -n "${vmc_groups_by_id[$game_id]}" ]]; then
            group_name="${vmc_groups_by_id[$game_id]}"
            vmc_size="${vmc_sizes_by_group[$group_name]}"
            vmc_name="${group_name}_0"
        else
            vmc_name="${game_id}_0"
            vmc_size="8"
        fi

        vmc_file="${vmc_name}.bin"

        # Create VMC .bin if it doesn't already exist
        # An empty one is what a genvmc that failed left behind.
        if [[ ! -s "${OPL}/VMC/${vmc_file}" && ! -s "${OPL}/VMC/${vmc_name%_0}.bin" ]] && [[ -z "${created_vmcs[$vmc_name]}" ]]; then

            # Check available space (in KB)
            available_kb=$(df -Pk "${OPL}" | awk 'NR==2 {print $4}')
            echo >> "${LOG_FILE}"
            echo "Available space for VMCs: $available_kb" >> "${LOG_FILE}"

            if (( available_kb < 40960 )); then
                echo "[!] Warning: Not enough free space to create all VMCs." >> "${LOG_FILE}"
                error_msg "Warning" "${UI_TEXT[WARN_CREATE_PS2_VMC]}"
                return 1
            fi

            "${HELPER_DIR}/genvmc" "$vmc_size" "${OPL}/VMC/${vmc_file}" >> "${LOG_FILE}" 2>&1
            created_vmcs["$vmc_name"]=1
        fi

        # Write OPL CFG entry
        cfg_file="${OPL}/CFG/${game_id}.cfg"
        if [[ -f "$cfg_file" ]] && grep -q '^\$VMC_0=' "$cfg_file"; then
            : # VMC already configured
        else
            printf '$VMC_0=%s\n' "${vmc_name}" >> "$cfg_file"
        fi

        # Write NHDDL YAML for Neutrino
        iso_name="${file_name%.*}"
        yaml_file="${OPL}/nhddl/${iso_name}.yaml"
        if [[ ! -f "$yaml_file" ]]; then
            printf 'mc0: /VMC/%s\n' "${vmc_file}" > "$yaml_file"
        elif ! grep -q '^mc0:' "$yaml_file"; then
            printf 'mc0: /VMC/%s\n' "${vmc_file}" >> "$yaml_file"
        fi

        i=$((i + 1))
        show_progress "$i" "$ps2_count"
    done
    exec 3<&-
}

WIDESCREEN_CHEATS() {
    i="0"
    SPLASH
    echo "Applying widescreen cheats..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_88]}"
    exec 3< "${PS2_LIST}"
        while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
            cht_file="${OPL}/CHT/${game_id}.cht"

            if [[ -f "$cht_file" ]]; then
                echo "CHT file for $game_id already exists. Skipping download." >> "${LOG_FILE}"
            else
                echo "CHT file not found locally for $game_id. Attempting to download from https://github.com/PS2-Widescreen/OPL-Widescreen-Cheats..." >> "${LOG_FILE}"
                wget --quiet --timeout=10 --tries=3 --output-document="$cht_file" \
                "https://raw.githubusercontent.com/PS2-Widescreen/OPL-Widescreen-Cheats/main/CHT/${game_id}.cht"

                if [[ -s "$cht_file" ]]; then
                    echo "[✓] Successfully downloaded widescreen cheat for $game_id" >> "${LOG_FILE}"

                    cfg_file="${OPL}/CFG/${game_id}.cfg"

                    if [[ -f "$cfg_file" ]]; then
                        if ! grep -q '^\$CheatsSource=1$' "$cfg_file" ||
                        ! grep -q '^\$EnableCheat=1$' "$cfg_file"; then

                            sed -i \
                                -e '/^\$CheatsSource=/d' \
                                -e '/^\$EnableCheat=/d' \
                                "$cfg_file"

                            cat >> "$cfg_file" <<'EOL'
$CheatsSource=1
$EnableCheat=1
EOL

                        fi

                    else
                    cat > "$cfg_file" <<'EOL'
$CheatsSource=1
$EnableCheat=1
EOL

                    fi
                else
                    # If wget fails
                    [[ -f "$cht_file" ]] && rm -f "$cht_file"
                fi
                i=$((i + 1))
                show_progress "$i" "$ps2_count"
            fi
        done
    exec 3<&-   
}

DISABLE_PS2_VMC() {
    # Remove VMC entries from all CFG files
    for cfg_file in "${OPL}/CFG/"*.cfg; do
        if grep -q '^\$VMC_0' "$cfg_file" 2>/dev/null; then
            tmp="${cfg_file}.tmp"
            sed '/^\$VMC_0/d' "$cfg_file" > "$tmp" && mv "$tmp" "$cfg_file"
        fi
    done

    # Remove mc0 entries from all NHDDL YAML files
    for yaml_file in "${OPL}/nhddl/"*.yaml; do
        if grep -q '^mc0:' "$yaml_file" 2>/dev/null; then
            tmp="${yaml_file}.tmp"
            sed '/^mc0:/d' "$yaml_file" > "$tmp" && mv "$tmp" "$yaml_file"
        fi
    done
}

INSTALL_SIZE() {
    local size_mb="$1"
if (( size_mb >= 1024 * 1024 )); then
    # 1 TiB or larger
    install_size=$(awk "BEGIN {printf \"%.2f TB\", $size_mb / 1024 / 1024}")
elif (( size_mb >= 1024 )); then
    # 1 GiB or larger
    install_size=$(awk "BEGIN {printf \"%.2f GB\", $size_mb / 1024}")
else
    # Less than 1 GiB
    install_size="${size_mb} MB"
fi
}

OPL_SIZE_CKECK() {

    if [ "$INSTALL_TYPE" = "sync" ]; then
        opl_size=$(df -m --output=size "${OPL}" | tail -n 1 | awk '{$1=$1};1')
        available_mb=$((opl_size - 128))
        needed_mb=$(find "${GAMES_PATH}/CD/" "${GAMES_PATH}/DVD/" "${GAMES_PATH}/POPS/" -type f ! -path '*/.*' \( -iname '*.iso' -o -iname '*.zso' \) -printf '%s\n' | awk '{s+=$1} END {print int((s + 1048575) / 1048576)}')

    elif [ "$INSTALL_TYPE" = "copy" ]; then
        opl_freespace=$(df -m "${OPL}/" | awk 'NR==2 {print $4}')
        available_mb=$((opl_freespace - 128))
        cd_size=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        dvd_size=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        ember_size=$(rsync -rL --progress --ignore-existing --dry-run --out-format="%l" --exclude='*/.*' --include='*/' --include='*/*.[cC][uU][eE]' --include='*/*.[bB][iI][nN]' --exclude='*' "${GAMES_PATH}/Ember/" "${OPL}/Ember/games/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        needed_mb=$((cd_size + dvd_size + ember_size))
    fi

    if (( available_mb < needed_mb )); then
        INSTALL_SIZE $needed_mb
        NEEDED="$install_size"
        INSTALL_SIZE $available_mb
        AVAILABLE="$install_size"
        echo "[X] Error: Total size of games ${NEEDED}, exceeds available space: ${AVAILABLE}" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_OPL_SIZE_CKECK_1]}" "${UI_TEXT[GAME_INSTALLER_34]} ${NEEDED}" "${UI_TEXT[ERROR_OPL_SIZE_CKECK_2]} ${AVAILABLE}" " " "${UI_TEXT[ERROR_OPL_SIZE_CKECK_3]}"
    fi
}

# Function to find available space
APA_SIZE_CHECK() {
    HDL_TOC

    # Extract the "used" value, remove "MB" and any commas
    used=$(cat "$hdl_output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')

    if [[ ! "$used" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid used-space value extracted from HDL output" >> "${LOG_FILE}"
        printf 'used=<%q>\n' "$used" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS2_LINUX_4]}"
    fi

    # Calculate available space (APA_SIZE - used)
    available=$((APA_SIZE - used))
    pp_max=$(((available / 8) - 1))
}

md5_check() {
    local FILE="$1"
    local TARGET_MD5="$2"
    delete_app="no"

    # Check if file exists
    if [[ -f "$FILE" ]]; then
        # Get md5 checksum
        FILE_MD5=$(md5sum "$FILE" | awk '{print $1}')

        # Compare and delete if matches
        if [[ "$FILE_MD5" == "$TARGET_MD5" ]]; then
            echo "Deleted $FILE (MD5 matched)" >> "${LOG_FILE}"
            delete_app="yes"
        else
            echo "MD5 does not match, file not deleted." >> "${LOG_FILE}"
        fi
    else
        echo "File not found: $FILE" >> "${LOG_FILE}"
    fi
}

app_success_check() {
    local name="$1"
    if [ $exit_code -ne 0 ]; then
        echo "[X] Error: Failed to update $name" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_APP_SUCCESS_CHECK]} $name"
    else
        echo | tee -a "${LOG_FILE}"
        echo "[✓] Successfully updated: $name." >> "${LOG_FILE}"
        echo "[✓] ${UI_TEXT[APP_SUCCESS_CHECK]} $name."
    fi
}

ps2_rsync_check() {
    local type="$1"

    # Check if PS2 sync/update failed
    if [ $cd_status -ne 0 ] || [ $dvd_status -ne 0 ]; then
        echo "[X] Error: Failed to $INSTALL_TYPE PS2 games." >> "${LOG_FILE}"
        if [ "$INSTALL_TYPE" = "sync" ]; then
            error_msg "Error" "${UI_TEXT[ERROR_PS2_RSYNC_CHECK_1]}"
        else
            error_msg "Error" "${UI_TEXT[ERROR_PS2_RSYNC_CHECK_2]}"
        fi
    else
        echo | tee -a "${LOG_FILE}"
        echo "[✓] PS2 games successfully $type." >> "${LOG_FILE}"
        if [ "$INSTALL_TYPE" = "sync" ]; then
            echo "[✓] ${UI_TEXT[PS2_RSYNC_CHECK_1]}"
        else
            echo "[✓] ${UI_TEXT[PS2_RSYNC_CHECK_2]}"
        fi
    fi
}

update_apps() {
    local name="$1"
    local source="$2"
    local destination="$3"
    local options="$4"

    echo | tee -a "${LOG_FILE}"
    echo "$name: Checking for updates..." >> "${LOG_FILE}"
    echo "$name: ${UI_TEXT[UPDATE_APPS_1]}"


    local needs_update=false

    if [[ "$name" == "OPL" ]]; then
        mkdir -p "${STORAGE_DIR}/__system/launcher"
        if [ -f "$source" ] && [ -f "$destination" ]; then
            local src_hash
            local dst_hash
            src_hash=$(md5sum "$source" | awk '{print $1}')
            dst_hash=$(md5sum "$destination" | awk '{print $1}')

            if [ "$src_hash" != "$dst_hash" ]; then
                needs_update=true
            fi
        else
            needs_update=true
        fi
    elif [[ "$name" == "Neutrino"  ]]; then
        if [[ -f "${OPL}/neutrino/version.txt" ]]; then
            current_ver=$(<"${OPL}/neutrino/version.txt")
            current_ver="${current_ver//v/}"  # Remove 'v' from current version
        fi
        latest_ver=$(<"${NEUTRINO_DIR}/version.txt")
        latest_ver="${latest_ver//v/}"  # Remove 'v' from latest version
        if [[ -n "$current_ver" ]]; then
            echo "Current version is: $current_ver" >> "${LOG_FILE}"
            echo "${UI_TEXT[UPDATE_APPS_2]} $current_ver"
        fi

        # Compare versions
        if [[ "$(echo -e "$current_ver\n$latest_ver" | sort -V | tail -n 1)" != "$current_ver" ]]; then
            needs_update=true
            rm -rf "${OPL}/neutrino"
        fi
    else
        local output
        output=$(rsync $options --dry-run "$source" "$destination")
        if [[ -n "$output" ]]; then
            needs_update=true
        fi
    fi

    if [ "$needs_update" = true ]; then
        echo | tee -a "${LOG_FILE}"
        echo "$name: updating..." >> "${LOG_FILE}"
        echo "$name: ${UI_TEXT[UPDATE_APPS_3]}"
        rsync $options "$source" "$destination" >>"${LOG_FILE}" 2>&1
        exit_code=${PIPESTATUS[0]}
        app_success_check "$name"
    else
        echo | tee -a "${LOG_FILE}"
        echo "$name: Already up-to-date." >> "${LOG_FILE}"
        echo "$name: ${UI_TEXT[UPDATE_APPS_4]}"
    fi
}

validate_title_cfg() {
    local cfg="$1"

    [[ -f "$cfg" ]] || return 1

    local title= title_short= boot=

    while IFS='=' read -r key value; do
        key=${key//$'\r'/}
        value=${value//$'\r'/}

        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        case "$key" in
            title) title="$value" ;;
            Title) title_short="$value" ;;
            boot)  boot="$value" ;;
        esac
    done < "$cfg"

    [[ -n "$title" && -n "$title_short" && -n "$boot" ]]
}

install_elf() {

    local dir=$1

    # Move all SB.* and XX.* ELF files to POPS
    find "${dir}/APPS" -maxdepth 1 -type f \( -iname 'SB.*.elf' -o -iname 'XX.*.elf' \) -exec mv -t "${OPL}/POPS/" {} +

    # Relocate ELF files that lack a title.cfg, in non-SAS compliant folders, or are renamed POPSTARTER.ELF files
    find "${dir}/APPS" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' dir; do
        base=$(basename "$dir")

        # Find .elf files directly inside the folder
        mapfile -t elfs < <(find "$dir" -maxdepth 1 -type f -iname '*.elf')

        if (( ${#elfs[@]} > 0 )); then

            for elf_path in "${elfs[@]}"; do
                elf=$(basename "$elf_path")

                # SB.* -> move ELF to POPS and delete folder
                if [[ "$elf" == SB.* ]]; then
                    echo "Moving $elf as it begins with SB." >> "${LOG_FILE}"
                    mv "$elf_path" "${OPL}/POPS/"
                    rm -rf "$dir"
                    break

                # XX.* -> delete folder containing the ELF
                elif [[ "$elf" == XX.* ]]; then
                    echo "Deleting $elf as it begins with XX." >> "${LOG_FILE}"
                    rm -rf "$dir"
                    break
                fi
            done

            # Skip to next folder if SB.* or XX.* caused the folder to be deleted
            [[ ! -d "$dir" ]] && continue

            # Non-XXX_ folders: move ELF and delete folder
            # XXX_ folders: only do so if title.cfg is not valid
            if [[ ! "$base" =~ ^(APP_|SYS_|EMU_|GME_|DST_|DBG_|PS1_|RTE_|DEM_) ]] || ! validate_title_cfg "$dir/title.cfg"; then
                echo "Moving $elf as Non-XXX_ folder or title.cfg is valid." >> "${LOG_FILE}"
                mv "${elfs[@]}" "${OPL}/APPS/"
                rm -rf "$dir"
            fi

        fi
    done

    # Check if any ELF files exist in the source directory

    elf_count=$(find "${dir}/APPS/" -maxdepth 1 -type f -iname "*.elf" | wc -l)

    if [ "$elf_count" -eq 0 ]; then
        echo "No ELF files to install in: ${dir}/APPS" >> "${LOG_FILE}"
    else
        SPLASH
        echo "Processing ELF files in: ${dir}/APPS/..." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_ELF]} ${dir}/APPS/"
        i="0"
        for file in "${dir}/APPS/"*.elf "${dir}/APPS/"*.ELF; do
            local title=""
            local type=""
            local title_id=""
            local developer=""

            [ -e "$file" ] || continue  # Skip if no ELF files exist
            # Extract filename without path and extension
            elf=$(basename "$file")
            elf_no_ext="${elf%.*}"

            echo "Installing ${dir}/APPS/$elf..." >> "${LOG_FILE}"

            app_name="${elf_no_ext%%(*}" # Remove anything after an open bracket '('
            app_name="${app_name%%[Vv][0-9]*}" # Remove versioning (e.g., v12 or V12)

            # Remove "compressed" and "uncompressed"
            app_name=$(echo "$app_name" | sed -E 's/^([uU][nN])?[cC][oO][mM][pP][rR][eE][sS][sS][eE][dD][[:space:]]*//')
            app_name=$(echo "$app_name" | sed -E 's/([uU][nN])?[cC][oO][mM][pP][rR][eE][sS][sS][eE][dD].*//')
            
            # Remove "packed"
            app_name=$(echo "$app_name" | sed -E 's/^[pP][aA][cC][kK][eE][dD][[:space:]]*//')
            app_name=$(echo "$app_name" | sed -E 's/[pP][aA][cC][kK][eE][dD].*//')

            # Remove "pkd"
            app_name=$(echo "$app_name" | sed -E 's/^[pP][kK][dD][[:space:]]*//')
            app_name=$(echo "$app_name" | sed -E 's/[pP][kK][dD].*//')

            app_name=$(echo "$app_name" | sed 's/\.*$//') # Trim trailing full stops

            AppDB_check=$(printf '%s' "$app_name" | sed 's/[^[:alnum:]]//g' | tr '[:lower:]' '[:upper:]')

            case "$AppDB_check" in
            UOPNPS2LD*|UOPL*)
                AppDB_check="UOPNPS2LD"
                ;;
            WOPNPS2LD*|WOPL*)
                AppDB_check="WOPNPS2LD"
                ;;
            OPL08CHILDPROOF*)
                AppDB_check="OPL08CHILDPROOF"
                ;;
            OPLRA*)
                AppDB_check="OPLRA"
                ;;
            OPL*|OPNPS2LD*)
                AppDB_check="OPNPS2LD"
                ;;
            SM64*|SUPERMARIO64*)
                AppDB_check="SM64"
                ;;
            PS2PSXE*)
                AppDB_check="PS2PSXE"
                ;;
            MECHAPWN*)
                AppDB_check="MECHAPWN"
                ;;
            WLER3Z*)
                AppDB_check="WLER3Z"
                ;;
            LAUNCHELF*|WLAUNCH*|WLE*|BOOT*)
                AppDB_check="WLAUNCHELF"
                ;;
            FREEMCBOOT*|FMC*|FMCBD*)
                AppDB_check="FMCBD"
                ;;
            GSM*)
                AppDB_check="GSM"
                ;;
            ESRGUI*)
                AppDB_check="ESRGUI"
                ;;
            ESRLAUNCHER*)
                AppDB_check="ESRLAUNCHER"
                ;;
            ESR*)
                AppDB_check="ESR"
                ;;
            *)
                AppDB_check="$AppDB_check"
                ;;
            esac

            # Check $ASSETS_DIR/database/AppDB.csv for match in first column to $AppDB_check, set $title based on second column from file if found.
            IFS='|' read -r title type title_id developer < <(
                awk -F'|' -v key="$AppDB_check" \
                    '$1 == key {print $2 "|" $3 "|" $4 "|" $5; exit}' \
                    "${ASSETS_DIR}/database/AppDB.csv"
            )

            if [[ -z "$title" ]]; then
                # If no title found, set $title with the remaining code
                app_name="${app_name//[_-]/ }"  # Replace underscores and hyphens with spaces
                app_name="${app_name%"${app_name##*[![:space:]]}"}" # Trim trailing spaces again
                app_name=$(echo "$app_name" | sed 's/\.*$//') # Trim trailing full stops again
                app_name_before=$(echo "$app_name") # Save the string
                app_name=$(echo "$app_name" | sed -E 's/([a-z])([A-Z])/\1 \2/g; s/Play Station/PlayStation/g') # Add a space before capital letters when preceded by a lowercase letter excpet for PlayStation"
                app_name=$(echo "$app_name" | sed -E 's/[Pp][Ll][Aa][Yy][Ss][Tt][Aa][Tt][Ii][Oo][Nn]/PlayStation/g') # capitalise P and S in PlayStation

                # Check if spaces were added by comparing before and after
                if [[ "$app_name" != "$app_name_before" ]]; then
                    space_added=true
                else
                    space_added=false
                fi

                # Process for title case and exceptions
                input_str="$app_name"

                # List of terms to ensure spaces before and after
                terms=("3d" "3D" "ps2" "PS2" "ps1" "PS1")
    
                # Loop over the terms
                for term in "${terms[@]}"; do
                    input_str="${input_str//${term}/ ${term}}"  # Ensure space before the term
                    input_str="${input_str//${term}/${term} }"  # Ensure space after the term
                done

                # Special case for "hdd" and "HDD" - add spaces only if the string is longer than 5 characters
                if [[ ${#input_str} -gt 5 ]]; then
                    input_str="${input_str//hdd/ hdd }"
                    input_str="${input_str//HDD/ HDD }"
                fi

                # Check if the string contains any lowercase letters
                if ! echo "$input_str" | grep -q '[a-z]'; then
                    input_str="${input_str,,}"  # Convert the entire string to lowercase
                fi

                # Words that should normally remain lowercase in title case
                lowercase_list="a an and as at but by for if in nor of on or the to up via yet"

                # Define words to exclude from uppercase conversion (only consonant-only words)
                exclude_list="by cry cyst crypt dry fly fry glyph gym gypsy hymn lynx my myth myrrh ply pry rhythm shy sky spy sly sty sync tryst why wry fun boy not yet"

                result=""

                # Now process each word
                for word in $input_str; do
                    # Keep minor title-case words lowercase, unless they're the first word
                    if [[ -n "$result" ]] && echo "$lowercase_list" | grep -wi -q "$word"; then
                        result+=" ${word,,}"
                    # Handle words 3 characters or shorter, but only if no space was added by sed
                    elif [[ ${#word} -le 3 ]] && ! $space_added && ! echo "$exclude_list" | grep -wi -q "$word"; then
                        result+=" ${word^^}"  # Convert to uppercase
                    # Handle consonant-only words (only if not in exclusion list)
                    elif [[ "$word" =~ ^[b-df-hj-np-tv-z0-9]+$ ]] && ! echo "$exclude_list" | grep -w -q "$word"; then
                        result+=" ${word^^}"  # Uppercase if the word is consonant-only and not in the exclusion list
                    else
                        result+=" ${word^}"  # Capitalize first letter for all other words
                    fi

                title="${result# }"
                done

                # Remove leading space and ensure no double spaces are left
                result="${result#"${result%%[![:space:]]*}"}"  # Remove leading spaces
                title=$(echo "$result" | sed 's/  / /g')  # Replace double spaces with single spaces
                title_id="APP_$(echo "$title" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | cut -c1-8)"  # Uppercase, remove non-alphanumeric characters, limit to 12 chars
                type="APP"
                developer=""
            fi

            # Create the new folder in the destination directory
            elf_dir="${dir}/APPS/${type}_$(echo "${elf%.*}" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9')"
            mkdir -p "${elf_dir}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create directory $elf_dir."

            if [[ $dir == $GAMES_PATH ]]; then
                cp "${dir}/APPS/$elf" "${elf_dir}" 2>>"${LOG_FILE}" || {
                    echo "[X] Error: Failed to copy: $elf > $elf_dir." >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_COPY]}: $elf > $elf_dir."
                }
            elif [[ $dir == $OPL ]]; then
                mv "${dir}/APPS/$elf" "${elf_dir}" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to move: $elf > $elf_dir." >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_MOVE]}: $elf > $elf_dir."
                }
            fi

            cat > "${elf_dir}/title.cfg" <<EOL
title=[$type] $title
boot=$elf
Title=$title
CfgVersion=8
Developer=$developer
Genre=Homebrew
Title_ID=$title_id
Players=
Aspect=
Scan=
Vmode=
Rating=
EOL
            i=$((i + 1))
            show_progress "$i" "$elf_count"
        done
    fi
}

organise_bin(){
    local dir=$1
    SPLASH

    echo "Organising BIN/CUE files..." >> "${LOG_FILE}"

    while IFS= read -r -d '' cue; do

        # Directory name = cue filename without extension
        game_dir="${dir}/$(basename "${cue%.[cC][uU][eE]}")"

        bin_count=0
        missing=0
        bin_list=()

        # Read all FILE entries from the cue
        while IFS= read -r binfile; do
            ((bin_count++))

            bin_path="$(dirname "$cue")/$binfile"

            if [[ -f "$bin_path" ]]; then
                bin_list+=("$bin_path")
            else
                echo "Missing BIN referenced by $(basename "$cue"): $binfile" >> "${LOG_FILE}"
                missing=1
            fi
        done < <(
            sed -n 's/^[[:space:]]*FILE "\(.*\)" .*/\1/pI' "$cue"
        )

        if (( missing )); then
            echo "Skipping $(basename "$cue") because one or more referenced BIN files are missing." >> "${LOG_FILE}"
            continue
        fi

        if (( bin_count == 0 )); then
            echo "Skipping $(basename "$cue") because no BIN references could be read from the CUE file." >> "${LOG_FILE}"
            continue
        fi

        # Create destination directory
        mkdir -p "${game_dir}"

        echo "Organising $(basename "$cue") into $(basename "$game_dir")/" >> "${LOG_FILE}"

        # Move cue
        mv -f "$cue" "${game_dir}/"

        # Move all referenced BINs
        for bin in "${bin_list[@]}"; do
            mv -f "$bin" "${game_dir}/"
        done

    done < <(
        find "${dir}/" \
            -maxdepth 1 \
            -type f \
            ! -path '*/.*' \
            -iname "*.cue" \
            -print0
    )
}

uncompress_zso() {
    if [[ "$INSTALL_TYPE" == "sync" ]]; then
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD")
    else
    # Remove duplicate ZSO files from OPL if the same game exists in GAMES_PATH
        for dir in CD DVD; do
            find "${OPL}/${dir}/" -type f ! -path '*/.*' -iname '*.zso' -print0 |
            while IFS= read -r -d '' opl_file; do
                base_name="${opl_file##*/}"
                base_name="${base_name%.*}"

                if find "${GAMES_PATH}/${dir}/" -maxdepth 1 -type f \
                    -iname "${base_name}.zso" | grep -q .; then
                    echo "[!] Removing duplicate ZSO from OPL directory: $opl_file" >> "${LOG_FILE}"
                    rm -f -- "$opl_file"
                fi
            done
        done
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" "${OPL}/CD" "${OPL}/DVD")
    fi

    if find "${search_dirs[@]}/" -type f ! -path '*/.*' -iname "*.zso" | grep -q .; then
        SPLASH
        echo "${UI_TEXT[UNCOMPRESS_ZSO]}"
        # Convert ZSO to ISO
        while IFS= read -r -d '' zso_file; do
            iso_file="${zso_file%.*}.iso"

            echo "Converting $zso_file -> $iso_file" >> "${LOG_FILE}"

            python3 -u "${HELPER_DIR}/ziso.py" -c 0 "$zso_file" "$iso_file" | tee -a "${LOG_FILE}"
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                rm -f "$iso_file"
                echo "[X] Error: Failed to uncompress $zso_file" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_UNCOMPRESS_ZSO]} $zso_file"
            fi

            rm -f "$zso_file"
            echo
        done < <(find "${search_dirs[@]}/" -type f ! -path '*/.*' -iname "*.zso" -print0)
    fi
}

compress_zso() {
    SPLASH
    if [[ "$INSTALL_TYPE" == "sync" ]]; then
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD")
    else
        # Remove duplicate ISO files from OPL if the same game exists in GAMES_PATH
        for dir in CD DVD; do
            find "${OPL}/${dir}/" -type f ! -path '*/.*' -iname '*.iso' -print0 |
            while IFS= read -r -d '' opl_file; do
                base_name="${opl_file##*/}"
                base_name="${base_name%.*}"

                if find "${GAMES_PATH}/${dir}/" -maxdepth 1 -type f \
                    -iname "${base_name}.iso" | grep -q .; then
                    echo "[!] Removing duplicate ISO from OPL directory: $opl_file" >> "${LOG_FILE}"
                    rm -f -- "$opl_file"
                fi
            done
        done
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" "${OPL}/CD" "${OPL}/DVD")
    fi

    echo "${UI_TEXT[COMPRESS_ZSO]}"
    # Convert ZSO to ISO
    while IFS= read -r -d '' iso_file; do
        zso_file="${iso_file%.*}.zso"

        echo "Converting: $iso_file -> $zso_file" >> "${LOG_FILE}"

        python3 -u "${HELPER_DIR}/ziso.py" -c 1 "$iso_file" "$zso_file" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            rm -f "$zso_file"
            echo "[X] Error: Failed to compress $iso_file" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_COMPRESS_ISO]} $iso_file"
        fi
        rm -f "$iso_file"
        echo
    done < <(find "${search_dirs[@]}/" -type f ! -path '*/.*' -iname "*.iso" -print0)
}

convert_bin(){
    SPLASH
    if find "${GAMES_PATH}/CD/" -maxdepth 1 -type f ! -path '*/.*' \( -iname "*.cue" \) | grep -q .; then
        # Loop over all .cue files in the folder
        echo "Converting BIN/CUE files to ISO..." >> "${LOG_FILE}"
        echo "${UI_TEXT[CONVERT_BIN_1]}"
        while IFS= read -r -d '' cue; do
            base="${cue%.[cC][uU][eE]}"        # Full path minus .cue
            iso="${base}.iso"

            if [[ -f "${base}.bin" ]]; then
                bin="${base}.bin"
            elif [[ -f "${base}.BIN" ]]; then
                bin="${base}.BIN"
            else
                echo "[!] Skipping. Missing BIN file for '$(basename "$cue")'" >> "${LOG_FILE}"
                error_msg "Warning" "${UI_TEXT[CONVERT_BIN_2]} '$(basename "$cue")'"
                continue
            fi

            if [[ -f "$iso" ]] || [[ -f "${OPL}/CD/$(basename "${cue%.*}").iso" ]]; then
                echo "Skipping. ISO already exists: '$(basename "$cue")'" >> "${LOG_FILE}"
                echo "${UI_TEXT[CONVERT_BIN_3]} '$(basename "$cue")'"
                continue
            fi

            echo "Converting '$(basename "$cue")'..." >> "${LOG_FILE}"
            echo "${UI_TEXT[CONVERTING]} '$(basename "$cue")'..."

            # Run bchunk (creates ${base}01.iso)
            bchunk "$bin" "$cue" "$base"
            echo

            # Rename output file (remove the 01)
            if [[ -f "${base}01.iso" ]]; then
                mv -f "${base}01.iso" "$iso"
            fi
        done < <(find "${GAMES_PATH}/CD/" -maxdepth 1 -type f ! -path '*/.*' -iname "*.cue" -print0)
    else
        echo "No PS2 .cue files to convert in ${GAMES_PATH}/CD." >> "${LOG_FILE}"
    fi
}

remove_vcd() {
    local dir=$1
    local dir2=$2

    # Remove all VCD files that have matching BIN/CUE files
    find "${dir}" -maxdepth 1 -type f -iname '*.vcd' -print0 |
    while IFS= read -r -d '' vcd; do
        base="${vcd%.*}"
        cue=$(find "${dir2}" -maxdepth 1 -type f \
            -iname "$(basename "$base").cue" -print -quit)

        [[ -n "$cue" ]] || continue

        valid=true

        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*FILE[[:space:]]+ ]] || continue

            entry="${line#FILE}"
            entry="${entry#file}"
            entry="${entry#"${entry%%[![:space:]]*}"}"

            if [[ "$entry" =~ ^\"([^\"]+)\"[[:space:]]+ ]]; then
                bin="${BASH_REMATCH[1]}"
            elif [[ "$entry" =~ ^([^[:space:]]+)[[:space:]]+ ]]; then
                bin="${BASH_REMATCH[1]}"
            else
                valid=false
                break
            fi

            [[ -f "$(dirname "$cue")/$bin" ]] || {
                valid=false
                break
            }
        done < "$cue"

        [[ "$valid" == true ]] && rm -- "$vcd"
    done
}

move_vcd() {
    local dir=$1
    local ember_dir=$2
    
    # Loop over all .VCD, .BIN, and .CUE files in the folder
    while IFS= read -r -d '' file; do
        mv "${file}" "${ember_dir}"
    done < <(find "${dir}" -maxdepth 1 -type f ! -path '*/.*' ! -iname "bios.bin" \( -iname "*.vcd" -o -iname "*.bin" -o -iname "*.cue" \) -print0)
}

convert_vcd(){
    local dir=$1
    SPLASH
    # Check if any .VCD files exist
    vcd_count=$(find "${dir}" -maxdepth 1 -type f ! -path '*/.*' -iname "*.vcd" | wc -l)
    if [ "$vcd_count" -gt 0 ]; then
        # Loop over all .VCD files in the folder
        i="0"
        echo "Converting VCD files to BIN/CUE..." >> "${LOG_FILE}"
        echo "${UI_TEXT[CONVERT_VCD_1]}"
        show_progress "$i" "$vcd_count"
        while IFS= read -r -d '' vcd; do
            if "${POPS2CUE}" "${vcd}" >> "${LOG_FILE}" 2>&1; then
                rm "${vcd}"
            else
                echo "Warning: Failed to convert $vcd to BIN/CUE" >> "${LOG_FILE}"
            fi

            i=$((i + 1))
            show_progress "$i" "$vcd_count"
        done < <(find "${dir}" -maxdepth 1 -type f ! -path '*/.*' -iname "*.vcd" -print0)
    fi
}

create_info_sys() {
    local title="$1"
    local title_id="$2"
    local publisher="$3"
    local content_type="255"

    title_id="${title_id//_/-}"
    title_id="${title_id//./}"

    if [ "$title_id" = "SCPN-60160" ]; then
        content_type="0"
    fi

    cat > "$info_sys_filename" <<EOL
title = $title
title_id = $title_id
title_sub_id = 0
release_date = 
developer_id = 
publisher_id = $publisher
note = 
content_web = 
image_topviewflag = 0
image_type = 0
image_count = 1
image_viewsec = 600
copyright_viewflag = 0
copyright_imgcount = 0
genre = 
parental_lock = 1
effective_date = 0
expire_date = 0
violence_flag = 0
content_type = $content_type
content_subtype = 0
EOL
    if [ -s "$info_sys_filename" ]; then
        echo "Created: $info_sys_filename" >> "${LOG_FILE}"
    else
        echo "[X] Error: Failed to create $info_sys_filename" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $info_sys_filename"
    fi
}

create_icon_sys() {
    local title="$1"
    local publisher="$2"
    cat > "$icon_sys_filename" <<EOL
PS2X
title0=$title
title1=$publisher
bgcola=58
bgcol0=0,3,43
bgcol1=0,0,10
bgcol2=1,0,9
bgcol3=0,1,19
lightdir0=1.0,-1.0,1.0
lightdir1=-1.0,1.0,-1.0
lightdir2=0.0,0.0,0.0
lightcolamb=64,64,64
lightcol0=64,64,64
lightcol1=16,16,16
lightcol2=0,0,0
uninstallmes0=
uninstallmes1=
uninstallmes2=
EOL
    if [ -s "$icon_sys_filename" ]; then
        echo "Created: $icon_sys_filename" >> "${LOG_FILE}"
    else
        echo "[X] Error: Failed to create $icon_sys_filename" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $icon_sys_filename"
    fi
}

create_system_cnf() {
    local file_name="$1"
    local title_id="$2"
    local arg="$3"

    {
        echo "BOOT2 = PATINFO"
        echo "HDDUNITPOWER = NICHDD"
        echo "path = $file_name"
        if [ -n "$arg" ]; then
            echo "arg = $arg"
        fi
        echo "titleid = $title_id"
    } > "$system_cnf"

    if [ -s "$system_cnf" ]; then
        echo "Created: $system_cnf" >> "${LOG_FILE}"
    else
        echo "[X] Error: Failed to create $system_cnf" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $system_cnf"
    fi
}

create_cfg() {
    i="0"
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating CFG files for OPL..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_87]}"
    echo "Starting Lang: $lang" >> "${LOG_FILE}"

    exec 3< "${ALL_TITLES}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
        if [[ $disc_type == "DVD" || $disc_type == "CD" || $disc_type == "EMBER" ]]; then
            cfg_file="${OPL}/CFG/${game_id}.cfg"

            echo "Processing: $game_id" >> "${LOG_FILE}"
            echo "Lang: $lang" >> "${LOG_FILE}"
            if [[ ! -f "$cfg_file" ]] || ! grep -q '^Title=' "$cfg_file"; then
                if [[ "$lang" == "jpn" && -n "$jpn_title" ]]; then
                    title="$jpn_title"
                fi

                printf 'Title=%s\n' "$title" >> "$cfg_file"
            fi

            echo "Checking $cfg_file" >> "$LOG_FILE"
            stat -c '%n | %y' "$cfg_file" >> "$LOG_FILE"

            if grep -q '^Description=' "$cfg_file" &&
                grep -q '^Developer=' "$cfg_file" &&
                grep -q '^Genre=' "$cfg_file" &&
                grep -q '^Players=' "$cfg_file" &&
                grep -q '^Rating=' "$cfg_file" &&
                grep -q '^Release=' "$cfg_file" &&
                grep -q '^Vmode=' "$cfg_file" &&
                grep -q '^Scan=' "$cfg_file" &&
                grep -q '^Aspect=' "$cfg_file"; then

                echo "All required entries found in CFG file for $game_id" >> "${LOG_FILE}"
                i=$((i + 1))
                show_progress "$i" "$collection_count"
                echo "SKIPPING CFG: $cfg_file" >> "$LOG_FILE"
                continue
            else
                echo "One or more required entries are missing in CFG file for $game_id" >> "${LOG_FILE}"
            fi

            if [[ $disc_type == "DVD" || $disc_type == "CD" ]]; then
                xml_file="${DATABASE_DIR}/PS2DB.xml"
            else
                xml_file="${DATABASE_DIR}/PS1DB.xml"
            fi

            if [[ "$game_id" == LSP* ]]; then
                id_lookup="${game_id//./}"
                id_lookup="${id_lookup:0:3}-${id_lookup:3}"
            else
                id_lookup="${game_id/_/-}"
                id_lookup="${id_lookup//./}"
            fi

            game_data=$(awk -v id="$id_lookup" '
                /<game serial=/ {
                    found = ($0 ~ "serial=\"" id "\"")
                }

                found {
                    print
                }

                found && /<\/game>/ {
                    exit
                }
            ' "$xml_file")

            developer=$(echo "$game_data" | sed -n 's/.*<Developer>\(.*\)<\/Developer>.*/\1/p')
            genre=$(echo "$game_data" | sed -n 's/.*<Genre>\(.*\)<\/Genre>.*/\1/p')
            players=$(echo "$game_data" | sed -n 's/.*<Players>\(.*\)<\/Players>.*/\1/p')
            scan=$(echo "$game_data" | sed -n 's/.*<Scan>\(.*\)<\/Scan>.*/\1/p')
            aspect=$(echo "$game_data" | sed -n 's/.*<Aspect>\(.*\)<\/Aspect>.*/\1/p')
            vmode=$(echo "$game_data" | sed -n 's/.*<Vmode>\(.*\)<\/Vmode>.*/\1/p')
            rating=$(echo "$game_data" | sed -n 's/.*<Rating>\(.*\)<\/Rating>.*/\1/p')

            for lang_pair in en:eng fr:fre de:ger es:spa it:ita pt:por; do
                xml_lang="${lang_pair%%:*}"
                suffix="${lang_pair##*:}"

                description_var="description_$suffix"
                release_var="release_$suffix"

                IFS='|' read -r "$description_var" "$release_var" < <(
                    echo "$game_data" | awk -v lang="$xml_lang" '
                        $0 ~ "<Localization lang=\"" lang "\">" { found=1; next }
                        found && /<\/Localization>/ { exit }

                        found && /<Description>/ {
                            sub(/.*<Description>/, "")
                            sub(/<\/Description>.*/, "")
                            description=$0
                        }

                        found && /<Release>/ {
                            sub(/.*<Release>/, "")
                            sub(/<\/Release>.*/, "")
                            release=$0
                        }

                        END { printf "%s|%s\n", description, release }
                    '
                )
            done

            description_var="description_$lang"
            release_var="release_$lang"

            description="${!description_var}"
            release="${!release_var}"

            [[ -z "$description" ]] && description="$description_eng"
            [[ -z "$release" ]] && release="$release_eng"

            if ! grep -q '^Description=' "$cfg_file" && [[ -n "$description" ]]; then
                printf 'Description=%s\n' "$description" >> "$cfg_file"
            fi

            if ! grep -q '^Release=' "$cfg_file" && [[ -n "$release" ]]; then
                printf 'Release=%s\n' "$release" >> "$cfg_file"
            fi

            if ! grep -q '^Developer=' "$cfg_file" && [[ -n "$developer" ]]; then
                printf 'Developer=%s\n' "$developer" >> "$cfg_file"
            fi

            if ! grep -q '^Genre=' "$cfg_file" && [[ -n "$genre" ]]; then
                printf 'Genre=%s\n' "$genre" >> "$cfg_file"
            fi

            if ! grep -q '^Players=' "$cfg_file" && [[ -n "$players" ]]; then
                printf 'Players=%s\n' "$players" >> "$cfg_file"
            fi

            if ! grep -q '^Rating=' "$cfg_file" && [[ -n "$rating" ]]; then
                printf 'Rating=rating/%s\n' "$rating" >> "$cfg_file"
            fi

            if ! grep -q '^Vmode=' "$cfg_file" && [[ -n "$vmode" ]]; then
                printf 'Vmode=%s\n' "$vmode" >> "$cfg_file"
            fi

            if ! grep -q '^Scan=' "$cfg_file" && [[ -n "$scan" ]]; then
                printf 'Scan=scan/%s\n' "$scan" >> "$cfg_file"
            fi

            if ! grep -q '^Aspect=' "$cfg_file" && [[ -n "$aspect" ]]; then
                printf 'Aspect=%s\n' "$aspect" >> "$cfg_file"
            fi

            i=$((i + 1))
            show_progress "$i" "$collection_count"
        fi
    done
    exec 3<&-
}

get_display_path() {
    if [[ "$GAMES_PATH" =~ ^/mnt/([a-zA-Z])(/.*)?$ ]]; then
        drive="${BASH_REMATCH[1]}"
        rest="${BASH_REMATCH[2]}"

        # If the rest is empty, default to empty string
        [[ -z "$rest" ]] && rest=""

        # Convert to Windows format
        display_path="${drive^^}:$(echo "$rest" | sed 's#/#\\#g')"
    else
        # For Linux paths, display_path is the same as GAMES_PATH
        display_path="$GAMES_PATH"
    fi
    # macOS runs the installer from a temporary copy; show the project's folder.
    if [[ "$(uname -s)" == Darwin ]]; then
        display_path=$(platform_display_path "$display_path")
    fi
}

mapper_probe() {
    DEVICE_CUT=$(basename "${DEVICE}")

    # 1) Remove existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v p="^${DEVICE_CUT}-" '$1 ~ p {print $1}')
    for map in $existing_maps; do
        sudo dmsetup remove -f "$map" || error_msg "Error" "Failed to remove $map, might be in use"
    done

    # 2) Build keep list
    keep_partitions=( "${LINUX_PARTITIONS[@]}" "${PFS_PARTITIONS[@]}" )

    # 3) Get HDL Dump --dm output, split semicolons into lines
    dm_output=$(sudo "${HDL_DUMP}" toc "${DEVICE}" --dm | tr ';' '\n')

    # 4) Create each kept partition individually
    while IFS= read -r line; do
        for part in "${keep_partitions[@]}"; do
            if [[ "$line" == "${DEVICE_CUT}-${part},"* ]]; then
                echo "$line" | sudo dmsetup create --concise
                break
            fi
        done
    done <<< "$dm_output"

    # 5) Export base mapper path
     MAPPER="$(platform_mapper_prefix "$DEVICE_CUT")"
}

mount_cfs() {
  for PARTITION_NAME in "${LINUX_PARTITIONS[@]}"; do
    MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
    if [ -e "${MAPPER}${PARTITION_NAME}" ]; then
        [ -d "${MOUNT_PATH}" ] || mkdir -p "${MOUNT_PATH}"
        if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to mount $PARTITION_NAME" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_MOUNT_2]} $PARTITION_NAME"
        fi
    else
        echo "[X] Error: Partition not found on disk: ${PARTITION_NAME}" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_MOUNT_3]} ${PARTITION_NAME}"
    fi
  done
}

mount_pfs() {
    for PARTITION_NAME in "${PFS_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        mkdir -p "$MOUNT_POINT"
        if ! sudo "${PFS_FUSE}" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to mount $PARTITION_NAME" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_MOUNT_2]} $PARTITION_NAME"
        fi
    done
}

unmount_apa(){
# Unmount if mounted
    # Get all mounts under STORAGE_DIR
    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: $line" >> "$LOG_FILE"
                sudo umount "$line" || {
                    echo "[X] Error: Failed to unmount $line" >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_UNMOUNT_1]} $line"
                }
                ;;
        esac
    done

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        echo "Removing existing mapper $map_name..." >> "$LOG_FILE"
        if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
            echo "[X] Error: Failed to delete mapper $map_name." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_UNMOUNT_2]} $map_name."
        fi
    done
}

sort_jpn(){
    local GAME_LIST=$1
    local JPN_LIST=$2

    python3 <<EOF
import re
import csv
from icu import Collator, Locale
import pykakasi

jp_re = re.compile(r'^[\u3040-\u309F\u30A0-\u30FF\u31F0-\u31FF\u4E00-\u9FFF]')

# Read GAME_LIST
with open("${GAME_LIST}", encoding="utf-8", newline='') as f:
    rows = list(csv.reader(f, delimiter='|'))

jpn_rows = []
non_jpn_rows = []

for row in rows:
    if len(row) >= 6 and jp_re.match(row[5]):
        jpn_rows.append(row)
    else:
        non_jpn_rows.append(row)

# Write back non-JPN rows to GAME_LIST
with open("${GAME_LIST}", "w", encoding="utf-8", newline='') as f:
    csv.writer(f, delimiter='|', lineterminator='\n').writerows(non_jpn_rows)

# Sort JPN rows if not empty
if jpn_rows:
    collator = Collator.createInstance(Locale("ja_JP"))
    kks = pykakasi.kakasi()

    def normalize_for_sort(s):
        result = kks.convert(s)
        hira = "".join(r['hira'] for r in result)
        return hira

    jpn_rows.sort(key=lambda r: collator.getSortKey(normalize_for_sort(r[5])))

    # Write sorted JPN_LIST
    with open("${JPN_LIST}", "w", encoding="utf-8", newline='') as f:
        csv.writer(f, delimiter='|', lineterminator='\n').writerows(jpn_rows)
EOF
}

normalize_roman_numerals() {
    local s=$1
    s=${s//Ⅰ/I}
    s=${s//Ⅱ/II}
    s=${s//Ⅲ/III}
    s=${s//Ⅳ/IV}
    s=${s//Ⅴ/V}
    s=${s//Ⅵ/VI}
    s=${s//Ⅶ/VII}
    s=${s//Ⅷ/VIII}
    s=${s//Ⅸ/IX}
    s=${s//Ⅹ/X}
    s=${s//Ⅺ/XI}
    s=${s//Ⅻ/XII}
    printf '%s' "$s"
}

make_partition_label() {
    local game_id="$1"
    local tag="$2"
    local title="$3"

    partition_label=$(python3 - "$game_id" "$title" "$tag" <<'PY'
import re
import unicodedata
import sys

game_id, title, tag = sys.argv[1], sys.argv[2], sys.argv[3]

# Format game id
game_id = re.sub(r'_(...)\.', r'-\1', game_id)
game_id = game_id.replace('.', '')

# Superscripts
title = title.replace('²', '2').replace('³', '3')

# Unicode normalization (NFKD) + ASCII fold
title_ascii = unicodedata.normalize('NFKD', title)
title_ascii = title_ascii.encode('ascii', 'ignore').decode()

# Uppercase
title_ascii = title_ascii.upper()

# Replace non A-Z0-9 with underscores
sanitized = re.sub(r'[^A-Z0-9]', '_', title_ascii)

# Clean underscores
sanitized = re.sub(r'^_+', '', sanitized)
sanitized = re.sub(r'_+$', '', sanitized)
sanitized = re.sub(r'_+', '_', sanitized)

# Build label
partition_label = f"PP.{game_id}.{tag}.{sanitized}"

# Truncate to 32 chars and strip trailing underscore
partition_label = partition_label[:32].rstrip('_')

print(partition_label)
PY
)

    export partition_label
}

# Remove line breaks so Bash can match XML tags.
flatten_xml() {
    REPLY=${1//$'\n'/}
    REPLY=${REPLY//$'\r'/}
}

opl_manager_id() {
    if [[ -s "${ASSETS_DIR}/OPL/user_id" ]] &&
    user_id=$(<"${ASSETS_DIR}/OPL/user_id") &&
    [[ "$user_id" =~ ^.{13}$ ]]; then
        echo "Valid user_id: $user_id" >> "${LOG_FILE}"
    else
        echo "Requesting API user ID..." >> "${LOG_FILE}"

        status_xml=$(curl -fsS "$OPLMS" \
            -H 'Content-Type: text/xml; charset=utf-8' \
            -H 'SOAPAction: "http://oplmanager.no-ip.info/ServiceStatus"' \
            -H 'User-Agent: OPL-Manager/24' \
            --data '<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:op="http://oplmanager.no-ip.info/">
        <soap:Body>
            <op:ServiceStatus>
            <op:userID>NEW</op:userID>
            <op:versionid>37</op:versionid>
            </op:ServiceStatus>
        </soap:Body>
        </soap:Envelope>')

        flatten_xml "$status_xml"
        status_xml=$REPLY

        if [[ $status_xml =~ \<ServiceStatusResult\>.*\<userID\>([^\<]+)\</userID\> ]]; then
            user_id=${BASH_REMATCH[1]}
            echo "API user ID retrieved: $user_id" >> "${LOG_FILE}"
            echo "$user_id" > "${ASSETS_DIR}/OPL/user_id"
        else
            echo "ERROR: Could not extract the API user ID." >> "${LOG_FILE}"
            return 1
        fi

        if [[ -z $user_id || $user_id == NEW ]]; then
            echo "ERROR: The API did not return a valid user ID." >> "${LOG_FILE}"
            return 1
        fi
    fi
}

opl_game_art() {
    local LIST="$1"

    exec 3< "${LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do

        if [[ "$LIST" == *"ps2.list" ]]; then
            game_type="PS2"
        elif [[ "$LIST" == *"ember.list" ]]; then
            game_type="POPS"
        fi

        if [[ -s "${OPL}/ART/${game_id}_BG.png" &&
              -s "${OPL}/ART/${game_id}_COV2.png" &&
              -s "${OPL}/ART/${game_id}_COV.png" &&
              -s "${OPL}/ART/${game_id}_ICO.png" &&
              -s "${OPL}/ART/${game_id}_LAB.png" &&
              -s "${OPL}/ART/${game_id}_LGO.png" &&
              -s "${OPL}/ART/${game_id}_SCR.png" &&
              -s "${OPL}/ART/${game_id}_SCR2.png" ]] &&
           [[ $(identify -format '%wx%h' "${OPL}/ART/${game_id}_ICO.png" 2>/dev/null) == "128x128" ]]; then
            i=$((i + 1))
            show_progress "$i" "$ART_TOTAL"
            continue
        fi

        local category url filename category_xml number limit
        local -a urls

        echo "Requesting artwork for $game_id..." >> "${LOG_FILE}"

        art_xml=$(curl -fsS "$OPLMS" \
            -H 'Content-Type: text/xml; charset=utf-8' \
            -H 'SOAPAction: "http://oplmanager.no-ip.info/ArtSearchSingle"' \
            -H 'User-Agent: OPL-Manager/24' \
            --data "<?xml version=\"1.0\" encoding=\"utf-8\"?>
        <soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:op=\"http://oplmanager.no-ip.info/\">
        <soap:Body>
            <op:ArtSearchSingle>
            <op:type>$game_type</op:type>
            <op:userID>$user_id</op:userID>
            <op:gameId>$game_id</op:gameId>
            </op:ArtSearchSingle>
        </soap:Body>
        </soap:Envelope>")

        flatten_xml "$art_xml"
        art_xml=$REPLY

        if [[ $art_xml != *'<ArtSearchSingleResult>'* ]]; then
            echo "Warning: No artwork found for $game_id" >> "${LOG_FILE}"
            i=$((i + 1))
            show_progress "$i" "$ART_TOTAL"
            return 1
        fi

        downloaded=0

        for category in COV COV2 ICO LGO LAB SCR BG; do
            urls=()
            limit=1

            if [[ $category == SCR || $category == BG ]]; then
                if [[ $category == SCR ]]; then
                    limit=2
                fi

                if [[ $art_xml =~ \<${category}\>(.*)\</${category}\> ]]; then
                    category_xml=${BASH_REMATCH[1]}

                    while [[ $category_xml =~ \<string\>([^<]+)\</string\> ]]; do
                        urls+=("${BASH_REMATCH[1]}")
                        category_xml=${category_xml#*"</string>"}
                    done
                fi
            elif [[ $art_xml =~ \<${category}\>([^<]+)\</${category}\> ]]; then
                urls+=("${BASH_REMATCH[1]}")
            fi

            number=0

            for url in "${urls[@]}"; do
                [[ $url == http://* || $url == https://* ]] || continue

                filename=${url##*/}
                filename=${filename%%\?*}

                if [[ $category == SCR ]]; then
                    if (( number == 0 )); then
                        filename=$(printf '%s_SCR.%s' \
                            "$game_id" "${filename##*.}")
                    else
                        filename=$(printf '%s_SCR2.%s' \
                            "$game_id" "${filename##*.}")
                    fi
                else
                    filename="${game_id}_${category}.${filename##*.}"
                fi

                if [[ $category == ICO ]]; then
                    if [[ -s "${OPL}/ART/$filename" ]] &&
                       [[ $(identify -format '%wx%h' "${OPL}/ART/$filename" 2>/dev/null) == "128x128" ]]; then
                        echo "ICO already exists at 128x128: $filename" >> "${LOG_FILE}"
                        break
                    fi
                elif [[ -s "${OPL}/ART/$filename" ]]; then
                    echo "Artwork already exists: $filename" >> "${LOG_FILE}"
                    if [[ $category == SCR ]]; then
                        number=$((number + 1))
                        (( number >= limit )) && break
                        continue
                    else
                        break
                    fi
                fi

                if curl -fsS --retry 2 --retry-delay 1 \
                    "$url" -o "${OPL}/ART/$filename"; then
                    echo "Downloaded: $filename" >> "${LOG_FILE}"
                else
                    printf 'Warning: Download failed %s\n' "$url" >> "${LOG_FILE}"
                    rm -f "${OPL}/ART/$filename"
                fi

                number=$((number + 1))
                (( number >= limit )) && break
            done
        done
        i=$((i + 1))
        show_progress "$i" "$ART_TOTAL"
    done
    exec 3<&-
}

create_app_assets() {
    local i="0"

    SPLASH
    echo "Creating assets for apps..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_41]}"

    exec 3< "$SELECTED_LIST"
        while IFS='|' read -r title title_id publisher category file_name title_short pp_name <&3; do
            if [[ $category =~ ^(SYS|EMU|GME|DST|DBG|PS1|RTE|DEM|APP)$ ]]; then

                elf=$(basename "$file_name")
                folder_name=$(basename "$(dirname "$file_name")")
                dir="${OPL}/APPS/${folder_name}"

                mkdir -p "${SCRIPTS_DIR}/tmp/${pp_name}" || {
                    echo "[X] Error: Failed to create folder: $pp_name" >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE_FOLDER]} $pp_name"
                }

                if [ -f "$dir/list.icn" ]; then
                    echo "Processing $pp_name..." >> "${LOG_FILE}"
                    cp "$dir/list.icn" "${SCRIPTS_DIR}/tmp/${pp_name}/list.ico" 2>>"${LOG_FILE}" || {
                        echo "[X] Error: Failed to convert: $dir/list.icn." 2>>"${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CONVERT]} $dir/list.icn."
                    }
                    echo "Converted list.icn: ${SCRIPTS_DIR}/tmp/${pp_name}/list.ico" >> "${LOG_FILE}"
                    [ -f "$dir/del.icn" ] && mv "$dir/del.icn" "${SCRIPTS_DIR}/tmp/${pp_name}/del.ico" && echo "Converted del.icn: ${SCRIPTS_DIR}/tmp/${pp_name}/del.ico" >> "${LOG_FILE}"
                else
                    ico_file="${ICONS_DIR}/ico/${title_id}_LST.ico"
                    ico_del="${ICONS_DIR}/ico/${title_id}_DEL.ico"

                    if [[ -f "$ico_file" ]]; then
                        echo "Using existing local icon: $ico_file" >> "${LOG_FILE}"
                    else
                        echo "Icon not found locally for $title_id. Attempting to download from the HDD-OSD icon database..." >> "${LOG_FILE}"

                        wget --quiet --timeout=10 --tries=3 --output-document="$ico_file" \
                        "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/apps/${title_id}_LST.ico"

                        wget --quiet --timeout=10 --tries=3 --output-document="$ico_del" \
                        "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/apps/${title_id}_DEL.ico"

                        if [[ -s "$ico_file" ]]; then
                            echo "[✓] Successfully downloaded ${title_id}_LST.ico." >> "${LOG_FILE}"
                        else
                            [[ -f "$ico_file" ]] && rm -f "$ico_file"
                            [[ -f "$ico_del" ]] && rm -f "$ico_del"
                            ico_file="${ICONS_DIR}/ico/APP_DEFAULT_LST.ico"
                            ico_del="${ICONS_DIR}/ico/APP_DEFAULT_DEL.ico"
                        fi

                        if [[ -s "$ico_del" ]]; then
                            echo "[✓] Successfully downloaded ${title_id}_DEL.ico." >> "${LOG_FILE}"
                        else
                            [[ -f "$ico_del" ]] && rm -f "$ico_del"
                        fi
                    fi

                    cp "${ico_file}" "${SCRIPTS_DIR}/tmp/${pp_name}/list.ico" 2>>"${LOG_FILE}" || {
                        echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/${pp_name}/list.ico" >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/${pp_name}/list.ico"
                    }
                    echo "Created: ${SCRIPTS_DIR}/tmp/${pp_name}/list.ico" >> "${LOG_FILE}"

                    [ -f "${ico_del}" ] && cp "${ico_del}" "${SCRIPTS_DIR}/tmp/${pp_name}/del.ico" && echo "Created del.icn: ${SCRIPTS_DIR}/tmp/${pp_name}/del.ico" >> "${LOG_FILE}"
                fi

                if [ "$OS" = "PSBBN" ]; then
                    # Generate the info.sys file
                    info_sys_filename="${SCRIPTS_DIR}/tmp/${pp_name}/info.sys"
                    create_info_sys "[${category}] $title" "$title_id" "$publisher"

                    png_file="${ARTWORK_DIR}/${title_id}.png"
                    # Copy the matching PNG file from ART_DIR, or default to APP.png
                    if [ -s "$png_file" ]; then
                        cp "$png_file" "${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png" 2>> "${LOG_FILE}" || {
                            echo "[X] Error: Failed to create ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png" >> "${LOG_FILE}"
                            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png."
                        }
                        echo "Created: ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png"  >> "${LOG_FILE}"
                    else
                        cp "$ARTWORK_DIR/APP.png" "${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png" 2>> "${LOG_FILE}" || {
                        echo "[X] Error: Failed to create ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png" >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png"
                    }
                    echo "Created: ${SCRIPTS_DIR}/tmp/${pp_name}/jkt_001.png using default image."  >> "${LOG_FILE}"
                    fi
                fi

                # Generate the icon.sys file
                icon_sys_filename="${SCRIPTS_DIR}/tmp/${pp_name}/icon.sys"
                if [ ${#title} -gt 48 ]; then
                    title="${title:0:45}..."
                fi

                case "$category" in
                    SYS) category="${UI_TEXT[GAME_INSTALLER_75]}" ;;
                    EMU) category="${UI_TEXT[GAME_INSTALLER_76]}" ;;
                    GME) category="${UI_TEXT[GAME_INSTALLER_77]}" ;;
                    DST) category="${UI_TEXT[GAME_INSTALLER_78]}" ;;
                    DBG) category="${UI_TEXT[GAME_INSTALLER_79]}" ;;
                    PS1) category="${UI_TEXT[GAME_INSTALLER_80]}" ;;
                    RTE) category="${UI_TEXT[GAME_INSTALLER_81]}" ;;
                    DEM) category="${UI_TEXT[GAME_INSTALLER_82]}" ;;
                    *)   category="${UI_TEXT[GAME_INSTALLER_74]}" ;;
                esac

                create_icon_sys "$title" "$category"

                # Generate the system.cnf file
                system_cnf="${SCRIPTS_DIR}/tmp/${pp_name}/system.cnf"
                create_system_cnf "$file_name" "$title_id"

                i=$((i + 1))
                show_progress "$i" "$collection_count"
            fi
        done
    exec 3<&-
}

create_game_assets() {
    if [ "$OS" = "PSBBN" ]; then
        i="0"
        SPLASH
        echo >> "${LOG_FILE}"
        echo "Downloading artwork for the PSBBN Game Collection..." >> "${LOG_FILE}"
        echo "${UI_TEXT[GAME_INSTALLER_46]}"

        # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
        exec 3< "$SELECTED_LIST"
        while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
            if [[ $disc_type == "DVD" || $disc_type == "CD" || $disc_type == "EMBER" || $disc_type == "__.POPS" || $disc_type == "SMB" || $disc_type == "BDM" ]]; then
                if [[ $game_id == "POPSTARTER" ]]; then
                    i=$((i + 1))
                    show_progress "$i" "$collection_count"
                    continue
                fi
                # Check if the artwork file already exists
                png_file="${ARTWORK_DIR}/${game_id}.png"
                if [[ -f "$png_file" ]]; then
                    echo "Artwork for $game_id already exists. Skipping download." >> "${LOG_FILE}"
                else
                    # Attempt to download artwork using wget
                    echo "Artwork not found locally. Attempting to download from the PSBBN art database..." >> "${LOG_FILE}"
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
                    "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/art/${game_id}.png"
                    if [[ -s "$png_file" ]]; then
                        echo "[✓] Successfully downloaded artwork for $game_id" >> "${LOG_FILE}"
                    else
                        # If wget fails, run the art downloader
                        [[ -f "$png_file" ]] && rm -f "$png_file"
                        echo "Trying IGN for $game_id" >> "${LOG_FILE}"
                        "${HELPER_DIR}/art_downloader.py" "$game_id" 2>&1 >> "${LOG_FILE}"
                    fi
                fi
                i=$((i + 1))
                show_progress "$i" "$collection_count"
            fi
        done
        exec 3<&-

        # Define input directory
        input_dir="${ARTWORK_DIR}/tmp"

        # Check if the directory contains any files
        if compgen -G "${input_dir}/*" > /dev/null; then
            echo >> "${LOG_FILE}"
            echo "Converting artwork..." >> "${LOG_FILE}"
            for file in "${input_dir}"/*; do
                # Extract the base filename without the path or extension
                base_name=$(basename "${file%.*}")

                # Define output filename with .png extension
                output="${ARTWORK_DIR}/tmp/${base_name}.png"

                # Get image dimensions using identify
                dimensions=$(identify -format "%w %h" "$file")
                width=$(echo "$dimensions" | cut -d' ' -f1)
                height=$(echo "$dimensions" | cut -d' ' -f2)

                # Check if width >= 256 and height >= width
                if [[ $width -ge 256 && $height -ge $width ]]; then
                    # Determine whether the image is square
                    if [[ $width -eq $height ]]; then
                        # Square: Resize without cropping
                        echo "Resizing square image $file" >> "${LOG_FILE}"
                        convert "$file" -resize 256x256! -depth 8 -alpha off "$output" 2>/dev/null
                    else
                        # Not square: Resize and crop
                        echo "Resizing and cropping $file" >> "${LOG_FILE}"
                        convert "$file" -resize 256x256^ -crop 256x256+0+44 -depth 8 -alpha off "$output" 2>/dev/null
                    fi
                    rm -f "$file"
                else
                    echo "Skipping $file: does not meet size requirements" >> "${LOG_FILE}"
                    rm -f "$file"
                fi
            done
            cp ${ARTWORK_DIR}/tmp/* ${ARTWORK_DIR} >> "${LOG_FILE}" 2>&1
        else
            echo | tee -a "${LOG_FILE}"
            echo "No artwork to convert in ${input_dir}" >> "${LOG_FILE}"
        fi
    fi

    SPLASH
    echo >> "${LOG_FILE}"
    echo "Downloading game icons for the Browser..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_47]}"
    i="0"

    exec 3< "$SELECTED_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
        if [[ $disc_type == "DVD" || $disc_type == "CD" || $disc_type == "EMBER" || $disc_type == "__.POPS" || $disc_type == "SMB" || $disc_type == "BDM" ]]; then
            ico_file="${ICONS_DIR}/ico/$game_id.ico"
            
            if [[ ! -s "$ico_file" ]]; then
                # Attempt to download icon using wget
                echo "Icon not found locally for $game_id. Attempting to download from the HDD-OSD icon database..." >> "${LOG_FILE}"
                wget --quiet --timeout=10 --tries=3 --output-document="$ico_file" \
                "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/ico/${game_id}.ico"
                if [[ -s "$ico_file" ]]; then
                    echo "[✓] Successfully downloaded icon for ${game_id}." >> "${LOG_FILE}"
                else
                    # If wget fails, run the art downloader
                    [[ -f "$ico_file" ]] && rm -f "$ico_file"

                    png_file_cov="${OPL}/ART/${game_id}_COV.png"
                    png_file_cov2="${OPL}/ART/${game_id}_COV2.png"
                    png_file_lab="${OPL}/ART/${game_id}_LAB.png"

                    icon_tmp="${ICONS_DIR}/ico/tmp"

                    if [[ ! -s "$png_file_cov" ]] || [[ ! -s "$png_file_cov2" ]]; then
                        echo "Insufficient assets to create icon for $game_id." >> "${LOG_FILE}"
                        i=$((i + 1))
                        continue
                    fi

                    cp "${png_file_cov}" "${png_file_cov2}" "${icon_tmp}"

                    if [[ ! -s "$png_file_lab" ]]; then
                        if [[ "${game_id:2:1}" == "E" ]]; then
                            if [[ "$disc_type" != "EMBER" && "$disc_type" != "__.POPS" && "$disc_type" != "SMB" ]]; then
                                cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_PAL.png" "${icon_tmp}/${game_id}_LAB.png"
                            else
                                cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_PAL.png" "${icon_tmp}/${game_id}_LAB.png"
                            fi
                        elif [[ "${game_id:2:1}" == "U" || "${game_id:0:1}" == "L" ]]; then
                            if [[ "$disc_type" != "EMBER" && "$disc_type" != "__.POPS" && "$disc_type" != "SMB" ]]; then
                                cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_USA.png" "${icon_tmp}/${game_id}_LAB.png"
                        else
                                cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_USA.png" "${icon_tmp}/${game_id}_LAB.png"
                            fi
                        else
                            if [[ "$disc_type" != "EMBER" && "$disc_type" != "__.POPS" && "$disc_type" != "SMB" ]]; then
                                cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_JPN.png" "${icon_tmp}/${game_id}_LAB.png"
                            else
                                cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_JPN.png" "${icon_tmp}/${game_id}_LAB.png"
                            fi
                        fi
                    else
                        cp "${png_file_lab}" "${icon_tmp}"
                    fi

                    echo "Creating HDD-OSD icon for $game_id..." >> "${LOG_FILE}"
                    if [[ "$disc_type" != "EMBER" && "$disc_type" != "__.POPS" && "$disc_type" != "SMB" ]]; then
                        if [[ "${game_id:2:1}" == "E" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 2 >> "${LOG_FILE}" 2>&1
                        else
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 1 >> "${LOG_FILE}" 2>&1
                        fi
                    else
                        if [[ "${game_id:2:1}" == "U" || "${game_id:0:1}" == "L" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 3 >> "${LOG_FILE}" 2>&1
                        elif [[ "${game_id:2:1}" == "E" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 6 >> "${LOG_FILE}" 2>&1
                        else
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 5 >> "${LOG_FILE}" 2>&1
                        fi
                    fi
                fi
            else
                echo "Icon for $game_id already exists. Skipping download." >> "${LOG_FILE}"
            fi
            i=$((i + 1))
            show_progress "$i" "$collection_count"
        fi
    done
    exec 3<&-
    
    cp "${ICONS_DIR}/ico/tmp/"*.ico "${ICONS_DIR}/ico/" >/dev/null 2>&1

    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating assets for games..."  >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_61]}"
    i="0"

    exec 3< "$SELECTED_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
        if [[ $disc_type == "DVD" || $disc_type == "CD" || $disc_type == "EMBER" || $disc_type == "__.POPS" || $disc_type == "SMB" || $disc_type == "BDM" ]]; then
            echo "Processing $title..." >> "${LOG_FILE}"
            # Create a sub-folder named after the game_id
            game_dir="${SCRIPTS_DIR}/tmp/$partition_label"
            mkdir -p "$game_dir" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to create folder: $dir" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_CREATE_FOLDER]} $dir."
            }
            
            if [[ "$lang" == "jpn" && -z "$jpn_title" ]]; then
                title=${title//"(disc 1)"/"（ディスク１）"}
                title=${title//"(disc 2)"/"（ディスク２）"}
                title=${title//"(disc 3)"/"（ディスク３）"}
                title=${title//"(disc 4)"/"（ディスク４）"}
                title=${title//"(disc 5)"/"（ディスク５）"}
                title=${title//"(disc 6)"/"（ディスク６）"}
                title=${title//"(Taikenban)"/"（体験版）"}
            fi

            if [[ "$disc_type" == "SMB" ]]; then
                ext="[${disc_type}] "
            elif [[ "$disc_type" == "BDM" ]]; then
                ext="[${disc_type}] "
            else
                ext=""
            fi

            if [ "$OS" = "PSBBN" ]; then
                # Generate the info.sys file
                info_sys_filename="$game_dir/info.sys"
                if [[ "$lang" == "jpn" && -n "$jpn_title" ]]; then
                    jpn_title=$(normalize_roman_numerals "$jpn_title")
                    create_info_sys "${ext}${jpn_title}" "$game_id" "$publisher"
                else
                    create_info_sys "${ext}${title}" "$game_id" "$publisher"
                fi
            fi

            # Generate the icon.sys file
            if [[ "$lang" == "jpn" && -n "$jpn_title" ]]; then
                jpn_title=$(normalize_roman_numerals "$jpn_title")
                game_title_icon="$jpn_title"
                bottom_line=""

                case "$game_title_icon" in
                *"（体験版）"*|*"（ディスク１）"*|*"（ディスク２）"*|*"（ディスク３）"*|*"（ディスク４）"*|*"（ディスク５）"*|*"（ディスク６）"*)
                    bottom_line="（${game_title_icon##*（}"
                    game_title_icon="${game_title_icon%（*}"
                    ;;
                esac

                if [[ "$disc_type" == "SMB" || "$disc_type" == "BDM" ]]; then
                    if [ ${#game_title_icon} -gt 10 ]; then
                        game_title_icon="${game_title_icon:0:7}..."
                    fi
                else
                    if [ ${#game_title_icon} -gt 16 ]; then
                        game_title_icon="${game_title_icon:0:13}..."
                    fi
                fi

                if [[ -n "$bottom_line" ]]; then
                    publisher="$bottom_line"
                fi
            else
                game_title_icon="$title"
                if [[ "$disc_type" == "SMB" || "$disc_type" == "BDM" ]]; then
                    if [ ${#game_title_icon} -gt 42 ]; then
                        game_title_icon="${game_title_icon:0:39}..."
                    fi
                else
                    if [ ${#game_title_icon} -gt 48 ]; then
                        game_title_icon="${game_title_icon:0:45}..."
                    fi
                fi
            fi

            icon_sys_filename="$game_dir/icon.sys"
            create_icon_sys "${ext}${game_title_icon}" "$publisher"

            if [ "$OS" = "PSBBN" ]; then
                # Copy the matching .png file and rename it to jkt_001.png
                png_file="${TOOLKIT_PATH}/icons/art/${game_id}.png"
                if [[ -s "$png_file" ]]; then
                    if [[ "$disc_type" == "EMBER" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" || "$disc_type" == "BDM" ]]; then
                        convert "${ASSETS_DIR}/Icon-templates/PS1-Template.png" \( "$png_file" -resize 197x197! \) -geometry +42+27 -composite "${game_dir}/jkt_001.png" 2>/dev/null
                    else
                        cp "$png_file" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || {
                            echo "[X] Error: Failed to create: $game_dir/jkt_001.png" >> "${LOG_FILE}"
                            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/jkt_001.png"
                        }
                    fi
                    echo "Created: $game_dir/jkt_001.png" >> "${LOG_FILE}"
                else
                    echo "$game_id $title" >> "${MISSING_ART}"
                    if [[ "$disc_type" == "EMBER" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" || "$disc_type" == "BDM" ]]; then
                        cp "${TOOLKIT_PATH}/icons/art/ps1.png" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || {
                            echo "[X] Error: Failed to create: $game_dir/jkt_001.png" >> "${LOG_FILE}"
                            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/jkt_001.png"
                        }
                        echo "Created: $game_dir/jkt_001.png using default PS1 image." >> "${LOG_FILE}"
                    else
                        cp "${TOOLKIT_PATH}/icons/art/ps2.png" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || {
                            echo "[X] Error: Failed to create: $game_dir/jkt_001.png" >> "${LOG_FILE}"
                            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/jkt_001.png"
                        }
                        echo "Created: $game_dir/jkt_001.png using default PS2 image." >> "${LOG_FILE}"
                    fi
                fi
            fi

            ico_file="${ICONS_DIR}/ico/$game_id.ico"

            if [[ -f "$ico_file" ]]; then
                cp "${ICONS_DIR}/ico/$game_id.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || {
                    echo "[X] Error: Failed to create: $game_dir/list.ico"  >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/list.ico."
                    }
                echo "Created: $game_dir/list.ico" >> "${LOG_FILE}"
            else
                echo "$game_id $title" >> "${MISSING_ICON}"
                case "$disc_type" in
                DVD)
                    cp "${ICONS_DIR}/ico/dvd.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || {
                        echo "[X] Error: Failed to create: $game_dir/list.ico"  >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/list.ico."
                    }
                    echo "Created: $game_dir/list.ico using default DVD icon." >> "${LOG_FILE}"
                ;;
                CD)
                    cp "${ICONS_DIR}/ico/cd.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" ||{
                        echo "[X] Error: Failed to create: $game_dir/list.ico"  >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/list.ico."
                    }
                    echo "Created: $game_dir/list.ico using default CD icon." >> "${LOG_FILE}"
                ;;
                EMBER|__.POPS|SMB|BDM)
                    cp "${ICONS_DIR}/ico/ps1.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || {
                        echo "[X] Error: Failed to create: $game_dir/list.ico"  >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/list.ico."
                    }
                    echo "Created: $game_dir/list.ico using default PS1 icon." >> "${LOG_FILE}"
                ;;
                esac
            fi

            # Generate the system.cnf files
            if [[ "$disc_type" = "CD" || "$disc_type" = "DVD" ]]; then
                cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/RIPTOPL-RA-UNPAKT.ELF
titleid = $game_id
nohistory = 1
arg = $file_name
arg = $game_id
arg = $disc_type
arg = ata
skip_argv0 = 0
EOL
            elif [ "$disc_type" = "EMBER" ]; then
                    cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = ata:/Ember/ember.elf
titleid = $game_id
nohistory = 1
arg = $file_name
EOL
            elif [ "$disc_type" = "__.POPS" ]; then
                elf_file="${file_name%.*}.ELF"
                cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/POPSTARTER.ELF
titleid = $game_id
nohistory = 1
arg = bbnl:$elf_file
skip_argv0 = 1
EOL
            elif [[ "$disc_type" = "SMB" || "$disc_type" = "BDM" ]]; then
                cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = ata:/POPS/$file_name
titleid = $game_id
nohistory = 1
EOL
            fi

            echo "Created: system.cnf for $game_id" >> "${LOG_FILE}"
            i=$((i + 1))
            show_progress "$i" "$collection_count"
        fi
    done
    exec 3<&-
    sleep 10
}

create_launcher_partitions() {
    i=0

    # Read all lines in reverse order
    mapfile -t reversed_lines < <(tac "$SELECTED_LIST")
    
    # Reverse the lines of the file using tac and process each line
    for line in "${reversed_lines[@]}"; do
        IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <<< "$line"

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
            error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
            break
        fi

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart ${partition_label} 8M PFS\n"
        if [ "$OS" = "PSBBN" ]; then
            COMMANDS+="mount ${partition_label}\n"
            COMMANDS+="cd /\n"

            # Navigate into the sub-directory named after the gameid
            COMMANDS+="lcd '${SCRIPTS_DIR}/tmp/${partition_label}'\n"
            COMMANDS+="mkdir res\n"
            COMMANDS+="cd res\n"
            COMMANDS+="put info.sys\n"
            COMMANDS+="put jkt_001.png\n"

            if [[ "$disc_type" == "__.POPS" || "$disc_type" == "SMB" || $disc_type == "BDM" ]]; then
                COMMANDS+="lcd '${ASSETS_DIR}/POPStarter'\n"
                COMMANDS+="put bg.png\n"
                COMMANDS+="lcd '${ASSETS_DIR}/POPStarter/$lang'\n"
                COMMANDS+="put 1.png\n"
                COMMANDS+="put 2.png\n"
                COMMANDS+="put man.xml\n"
            fi

            COMMANDS+="umount\n"
        fi
        COMMANDS+="exit\n"

        PFS_COMMANDS

        cd "${SCRIPTS_DIR}/tmp/$partition_label" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to change directory: ${SCRIPTS_DIR}/tmp/$partition_label" 2>>"${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CD]} ${SCRIPTS_DIR}/tmp/$partition_label"
        }
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "${partition_label}" >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to modify header: ${partition_label}" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_HEADER]} ${partition_label}"
        }
        echo "Created $partition_label" >> "${LOG_FILE}"
        echo >> "${LOG_FILE}"

        i=$((i + 1))
        show_progress "$i" "$collection_count"
    done
}

SPLASH() {
    clear
    cat << "EOF"
                      _____                        _____          _        _ _ 
                     |  __ \                      |_   _|        | |      | | |          
                     | |  \/ __ _ _ __ ___   ___    | | _ __  ___| |_ __ _| | | ___ _ __ 
                     | | __ / _` | '_ ` _ \ / _ \   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                     | |_\ \ (_| | | | | | |  __/  _| || | | \__ \ || (_| | | |  __/ |   
                      \____/\__,_|_| |_| |_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|   




EOF
}

trap 'echo; exit 130' INT
trap exit_script EXIT

mkdir -p "${LOGS_DIR}" >/dev/null 2>&1

if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
    sudo rm -f "${LOG_FILE}"
    if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
        error_msg "${UI_TEXT[ERROR_LOG]}"
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
echo -n "PSBBN Definitive Project Version: " >> "${LOG_FILE}"
git rev-parse --short HEAD >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

SPLASH

DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

if [[ -z "$DEVICE" ]]; then
    echo "[X] Error: Unable to detect the PS2 drive" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_DETECT_DRIVE_1]}" "${UI_TEXT[ERROR_DETECT_DRIVE_5]}"
fi

echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

clean_up
sudo rm -f "${MISSING_ART}" "${MISSING_APP_ART}" "${MISSING_ICON}" "${MISSING_VMC}" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to remove missing artwork logs." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_REMOVE_LOG]}"
}

mkdir -p "${SCRIPTS_DIR}/tmp" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create folder: ${SCRIPTS_DIR}/tmp" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE_FOLDER]} ${SCRIPTS_DIR}/tmp"
}

# Find all mounted volumes associated with the device
mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

# Iterate through each mounted volume and unmount it
echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
for mount_point in $mounted_volumes; do
    echo "Unmounting $mount_point..." >> "${LOG_FILE}"
    if sudo umount "$mount_point"; then
        echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
    else
        echo "[X] Error: Failed to unmount: $mount_point" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_UNMOUNT_1]} $mount_point"
    fi
done

HDL_TOC
CHECK_PARTITIONS

# If __.POPS partition exists, check if it contains games
if [ "$POPS_PRESENT" = "1" ]; then
    SPLASH
    center_title "${UI_TEXT[MUSIC_INSTALLER_5]}"
    printf '\n  %s\n\n  %s\n\n  %s\n\n' \
        "${UI_TEXT[GAME_INSTALLER_64]}" \
        "${UI_TEXT[GAME_INSTALLER_65]}" \
        "${UI_TEXT[GAME_INSTALLER_66]}"

    printf '%*s\n\n' 110 '' | tr ' ' '='
    while true; do
        read -rp "  ${UI_TEXT[GAME_INSTALLER_69]} (y/n): " confirm
        case "$confirm" in
            [Yy]) break ;;
            [Nn]) exit 1 ;;
            *) echo; echo "  ${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __.POPS\n"
    COMMANDS+="ls -l\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    ps1_games=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" 2>/dev/null)

    if echo "$ps1_games" | grep -qi '\.vcd$'; then
        SPLASH
        echo "Games found in __.POPS" >> "${LOG_FILE}"
        mount_pfs
        echo "PS1 games on __.POPS:" >> "${LOG_FILE}"
        ls -l "${STORAGE_DIR}/__.POPS" >> "${LOG_FILE}"
        echo >> "${LOG_FILE}"
        echo "Creating PS1 games list for __.POPS..." >> "${LOG_FILE}"
        echo "${UI_TEXT[GAME_INSTALLER_37]}"
        python3 -u "${HELPER_DIR}/list-builder.py" "${STORAGE_DIR}" "${PFS_POPS_LIST}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo "[X] Error: Failed to create PS1 games list for __.POPS." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_LIST]}"
        fi

        if [[ ! -s "${PFS_POPS_LIST}" ]] && find "${STORAGE_DIR}/__.POPS" -maxdepth 1 -type f \( -iname "*.VCD" \) | grep -q .; then
            echo "[X] Error: Failed to create Ember games list." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_LIST]}"
        fi

        unmount_apa
        sleep 3
    else
        echo "No games found in __.POPS" >> "${LOG_FILE}"
    fi
fi

MOUNT_OPL

rm -rf "${OPL}/bbnl"

if [ "$OS" = "PSBBN" ]; then
    psbbn_version=$(head -n 1 "${OPL}/version.txt" 2>/dev/null)

    # Compare using sort -V
    if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
        echo "Warning: Your PSBBN Definitive Patch version ($psbbn_version) is older than the required version ($version_check)." >> "${LOG_FILE}"
        echo "${UI_TEXT[ERROR_VERSION_3]} ($psbbn_version)"
        echo "${UI_TEXT[ERROR_VERSION_4]} ($version_check)"

        if (( $(echo "${psbbn_version:-0} < 2.11" | bc -l) )); then
            echo "${UI_TEXT[ERROR_VERSION_5]}"
        else
            echo "${UI_TEXT[ERROR_VERSION_6]}"
        fi
        echo
        read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
        exit 0
    fi
fi

APA_SIZE=$(awk -F' *= *' '$1=="APA_SIZE"{print $2}' "${OPL}/version.txt")

if [[ ! "$APA_SIZE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid APA_SIZE in $OPL/version.txt:" >> "${LOG_FILE}"
    printf 'APA_SIZE=%q\n' "$APA_SIZE" >> "${LOG_FILE}"
    cat "$OPL/version.txt" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_PS2_LINUX_4]}"
fi

lang=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")
ENTER=$(awk -F' *= *' '$1=="ENTER"{print $2}' "${OPL}/version.txt")
echo "Language: $lang" >> "${LOG_FILE}"

if [ -z "$APA_SIZE" ] || [ -z "$lang" ]; then
    echo "[X] Error: Missing required value(s): ${OPL}/version.txt" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_VERSION_7]} ${OPL}/version.txt"
fi

if [[ -n "$path_arg" ]]; then
    if [[ -d "$path_arg" ]]; then
        GAMES_PATH="$path_arg"
    else
        path_arg=""
    fi
elif [[ -f "$CONFIG_FILE" && -s "$CONFIG_FILE" ]]; then
    cfg_path="$(<"$CONFIG_FILE")"
    if [[ -d "$cfg_path" ]]; then
        GAMES_PATH="$cfg_path"
    fi
fi

SPLASH

# Choose game folder
if [[ -z "$path_arg" ]]; then
    get_display_path
    echo "${UI_TEXT[GAME_INSTALLER_26]} ${display_path}:" | tee -a "${LOG_FILE}"
    echo
    echo "📀 PS2 DVD → /DVD (.iso, .zso)"
    echo "💿 PS2 CD → /CD (.bin+.cue, .iso, .zso)"
    echo "💿 PS1 → /Ember (.bin+.cue, .VCD)"
    echo "🎮 POPSTARTER.ELF → /POPS (SB.*.ELF XX.*.ELF)"
    echo "🔧 Homebrew → /APPS (.elf, SAS .psu)"
    echo

    while true; do
        read -rp "${UI_TEXT[GAME_INSTALLER_1]} (y/n): " answer
        case "$answer" in
            [Yy])
                echo
                read -rp "${UI_TEXT[GAME_INSTALLER_2]} " new_path

                # --- Detect & convert Windows path ---
                if [[ "$new_path" =~ ^[A-Za-z]: ]]; then
                    # Convert backslashes to forward slashes
                    win_path=$(echo "$new_path" | sed 's#\\#/#g')

                    # If there's no slash after the colon (C:Games), insert it
                    if [[ "$win_path" =~ ^[A-Za-z]:[^/] ]]; then
                        win_path="${win_path:0:2}/${win_path:2}"
                    fi

                    # Extract drive letter and lowercase it
                    drive=$(echo "$win_path" | cut -d':' -f1 | tr '[:upper:]' '[:lower:]')

                    # Remove the drive and colon safely
                    path_without_drive=$(echo "$win_path" | sed 's#^[A-Za-z]:##')

                    # Build Linux path
                    new_path="/mnt/$drive$path_without_drive"
                fi
                # -----------------------------------

                if [[ -d "$new_path" ]]; then
                    # Remove trailing slash unless it's the root directory
                    new_path="${new_path%/}"
                    [[ "$new_path" == "" ]] && new_path="/"

                    GAMES_PATH="$new_path"
                    echo "$GAMES_PATH" > "$CONFIG_FILE"
                    break
                else
                    echo "${UI_TEXT[GAME_INSTALLER_3]}"
                    echo
                fi
                ;;
            [Nn])
                break
                ;;
            *)
                echo
                echo "${UI_TEXT[CHOICE]} (y/n):"
                ;;
        esac
    done
fi

# Create necessary folders if they don't exist
mkdir -p "${GAMES_PATH}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,POPS,Ember} 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create OPL folders." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_OPL_FOLDER]}"
}

# Check if GAMES_PATH is custom
if [[ "${GAMES_PATH}" != "${TOOLKIT_PATH}/games" ]]; then
    echo "Using custom game path." >> "${LOG_FILE}"
    cp "${TOOLKIT_PATH}/games/APPS/"{APP_WLE-R3Z.psu,SYS_R3CONFIGURATOR.psu} "${GAMES_PATH}/APPS" >> "${LOG_FILE}" 2>&1
else
    echo "Using default game path." >> "${LOG_FILE}"
fi

SPLASH

# Sync or add?
echo "${UI_TEXT[GAME_INSTALLER_4]}"
echo
echo "1) ${UI_TEXT[GAME_INSTALLER_5]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_6]}"
echo "${UI_TEXT[GAME_INSTALLER_7]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_8]}"
echo "${UI_TEXT[GAME_INSTALLER_9]}"
echo
echo "2) ${UI_TEXT[GAME_INSTALLER_10]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_11]}"
echo "${UI_TEXT[GAME_INSTALLER_12]}"
echo

while true; do
    read -rp "${UI_TEXT[CHOICE]} (1/2): " choice
    case "$choice" in
        1) INSTALL_TYPE="sync" DESC1="${UI_TEXT[SYNC]}"; break ;;
        2) INSTALL_TYPE="copy" DESC1="${UI_TEXT[ADD]}"; break ;;
        *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
    esac
done

remove_vcd "${GAMES_PATH}/POPS" "${GAMES_PATH}/POPS"
move_vcd "${GAMES_PATH}/POPS/" "${GAMES_PATH}/Ember/"

if [ "$INSTALL_TYPE" = "sync" ]; then
    find "${OPL}/POPS/" -maxdepth 1 -type f \( -iname '*.vcd' -o -iname '*.bin' -o -iname '*.cue' \) -delete
    find "${OPL}/Ember/" -type f \( -iname '*.vcd' -o -iname '*.bin' -o -iname '*.cue' \) -delete
fi

if [ "$INSTALL_TYPE" = "copy" ]; then
    remove_vcd "${OPL}/POPS" "${GAMES_PATH}/Ember"
    move_vcd "${OPL}/POPS/" "${OPL}/Ember/games/"
    move_vcd "${OPL}/Ember/" "${OPL}/Ember/games/"
fi

get_display_path

if [ "$INSTALL_TYPE" = "sync" ] && \
   ! find "${GAMES_PATH}/Ember/" -type f \( -iname "*.vcd" -o -iname "*.bin" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/CD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" -o -iname "*.bin" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit | grep -q .; then
    echo
    echo "${UI_TEXT[GAME_INSTALLER_13]} ${display_path}"
    echo "${UI_TEXT[GAME_INSTALLER_14]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CONTINUE_PROMPT]} (y/n): " confirm
        case "$confirm" in
            [Yy]) break ;;
            [Nn]) exit 1 ;;
            *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done
fi

SPLASH

# Choose a loader core
echo "${UI_TEXT[GAME_INSTALLER_15]}"
echo
echo "1) ${UI_TEXT[GAME_INSTALLER_16]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_17]}"
echo "${UI_TEXT[GAME_INSTALLER_90]}"
echo "${UI_TEXT[GAME_INSTALLER_91]}"
echo "${UI_TEXT[GAME_INSTALLER_92]}"
echo
echo "2) ${UI_TEXT[GAME_INSTALLER_19]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_20]}"
echo "${UI_TEXT[GAME_INSTALLER_93]}"
echo "${UI_TEXT[GAME_INSTALLER_94]}"
echo "${UI_TEXT[GAME_INSTALLER_95]}"
echo "${UI_TEXT[GAME_INSTALLER_96]}"
echo

while true; do
    read -rp "${UI_TEXT[CHOICE]} (1/2): " choice
    case "$choice" in
        1) LAUNCHER="OPL"; DESC2="Open PS2 Loader (OPL)"; break ;;
        2) LAUNCHER="NEUTRINO"; DESC2="Neutrino"; break ;;
        *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
    esac
done

# Enable RetroAchievements?
SPLASH
echo "${UI_TEXT[GAME_INSTALLER_89]}"
echo
while true; do
    read -rp "${UI_TEXT[CHOICE]} (y/n): " choice
    case "$choice" in
        [Yy]) RA="y"; break ;;
        [Nn]) RA="n"; break ;;
        *)echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
    esac
done

# Compress PS2 ISOs?
if [ "$LAUNCHER" = "OPL" ] && [ "$RA" = "n" ] &&
    {
        { find "${GAMES_PATH}/DVD/" "${GAMES_PATH}/CD/" -maxdepth 1 -type f -iname "*.iso" | grep -q .; } ||
        { [ "$INSTALL_TYPE" = "copy" ] && find "${OPL}/DVD/" "${OPL}/CD/" -maxdepth 1 -type f -iname "*.iso" | grep -q .; }
    }
then
    SPLASH
    echo "${UI_TEXT[GAME_INSTALLER_70]}"
    echo
    echo "${UI_TEXT[GAME_INSTALLER_71]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " choice
        case "$choice" in
            [Yy]) COMPRESS="y"; break ;;
            [Nn]) COMPRESS="n"; break ;;
            *)echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done
fi

# Decompress PS2 games
if { [ "$LAUNCHER" = "NEUTRINO" ] || [ "$RA" = "y" ]; } &&
    {
        { find "${GAMES_PATH}/DVD/" "${GAMES_PATH}/CD/" -maxdepth 1 -type f -iname "*.zso" | grep -q .; } ||
        { [ "$INSTALL_TYPE" = "copy" ] && find "${OPL}/DVD/" "${OPL}/CD/" -maxdepth 1 -type f -iname "*.zso" | grep -q .; }
    }
then
    SPLASH
    echo "${UI_TEXT[WARM_CONVERT_ZSO_1]}"

    if [ "$LAUNCHER" = "NEUTRINO" ]; then
        echo "${UI_TEXT[WARM_CONVERT_ZSO_2]}"
    fi

    if [ "$RA" = "y" ]; then
        echo "${UI_TEXT[WARM_CONVERT_ZSO_5]}"
    fi

    echo
    echo "${UI_TEXT[WARM_CONVERT_ZSO_3]}"
    echo
    echo "${UI_TEXT[WARM_CONVERT_ZSO_4]}"

    if [ "$LAUNCHER" = "NEUTRINO" ]; then
        echo "${UI_TEXT[WARM_CONVERT_ZSO_6]}"
    fi

    if [ "$RA" = "y" ]; then
        echo "${UI_TEXT[WARM_CONVERT_ZSO_7]}"
    fi

    echo

    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " choice
        case "$choice" in
            [Yy]) UNCOMPRESS="y"; break ;;
            [Nn]) UNCOMPRESS="n"; break ;;
            *)echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done
fi

if { find "${GAMES_PATH}/CD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" -o -iname "*.bin" \) | grep -q .; } ||
   { find "${GAMES_PATH}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; } ||
   { [ "$INSTALL_TYPE" = "copy" ] && find "${OPL}/CD/" "${OPL}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; }
then
    # Ask about PS2 widescreen hacks and VMCs if PS2 games exist
    SPLASH
    echo "${UI_TEXT[GAME_INSTALLER_83]}"
    echo
    echo "${UI_TEXT[GAME_INSTALLER_84]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " choice
        case "$choice" in
            [Yy]) WIDE="y"; break ;;
            [Nn]) WIDE="n"; break ;;
            *)echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done

    SPLASH
    echo "${UI_TEXT[GAME_INSTALLER_24]}"
    echo
    echo "${UI_TEXT[GAME_INSTALLER_25]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " PS2_VMC
        case "$PS2_VMC" in
            [Yy]) PS2_VMC="y"; break ;;
            [Nn]) PS2_VMC="n"; break ;;
            *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done
fi

# HDTV Fix for PS1 games?
if { find "${GAMES_PATH}/Ember/" -type f -iname "*.bin" -print -quit | grep -q . ||
     find "${GAMES_PATH}/Ember/" -maxdepth 1 -type f -iname "*.vcd" -print -quit | grep -q .; } ||
   { [ "$INSTALL_TYPE" = "copy" ] &&
     { find "${OPL}/Ember/" -type f -iname "*.bin" -print -quit | grep -q . ||
       find "${OPL}/Ember/" -maxdepth 1 -type f -iname "*.vcd" -print -quit | grep -q .; }; }; then
    if [[ -f "${OPL}/Ember/settings.txt" ]]; then
        sed -i '/^display:/d' "${OPL}/Ember/settings.txt"
    fi
    SPLASH
    echo "${UI_TEXT[GAME_INSTALLER_22]}"
    echo
    echo "${UI_TEXT[GAME_INSTALLER_23]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " HDTVFIX
        case "$HDTVFIX" in
            [Yy])
                break
                ;;
            [Nn])
                echo "display: 240" >> "${OPL}/Ember/settings.txt"
                break
                ;;
            *)
                echo
                echo "${UI_TEXT[MENU_INVALID]}"
                ;;
        esac
    done
fi

SPLASH

echo "PS2 Drive Detected: $DEVICE" >> "${LOG_FILE}"
echo "Linux Games Folder: $GAMES_PATH" >> "${LOG_FILE}"
echo "Games Folder: $display_path" >> "${LOG_FILE}"
echo "• ${UI_TEXT[GAME_INSTALLER_26]} $display_path"

echo "Install Type: $DESC1" >> "${LOG_FILE}"
echo "• ${UI_TEXT[GAME_INSTALLER_27]} $DESC1"

echo "Loader Core: $DESC2" >> "${LOG_FILE}"
echo "• ${UI_TEXT[GAME_INSTALLER_28]} $DESC2"

if [ "$RA" = "y" ]; then
    echo "Enable RetroAchievements: Yes" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_97]} ${UI_TEXT[YES]}"
elif [ "$RA" = "n" ]; then
    echo "Enable RetroAchievements: No" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_97]} ${UI_TEXT[NO]}"
fi

if [ "$COMPRESS" = "y" ]; then
    echo "Compress PS2 Games: Yes" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_72]} ${UI_TEXT[YES]}"
elif [ "$COMPRESS" = "n" ]; then
    echo "Compress PS2 Games: No" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_72]} ${UI_TEXT[NO]}"
fi

if [ "$UNCOMPRESS" = "y" ]; then
    echo "Uncompress PS2 Games: Yes" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_72]} ${UI_TEXT[YES]}"
elif [ "$UNCOMPRESS" = "n" ]; then
    echo "Uncompress PS2 Games: No" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_72]} ${UI_TEXT[NO]}"
fi

if [ "$PS2_VMC" = "y" ]; then
    echo "PS2 VMCs: Yes" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_30]} ${UI_TEXT[YES]}"
elif [ "$PS2_VMC" = "n" ]; then
    echo "PS2 VMCs: No" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_30]} ${UI_TEXT[NO]}"
fi

if [ "$WIDE" = "y" ]; then
    echo "Widescreen Hacks: Yes" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_85]} ${UI_TEXT[YES]}"
elif [ "$WIDE" = "n" ]; then
    echo "Widescreen Hacks: No" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_85]} ${UI_TEXT[NO]}"
fi

if [ -n "$HDTVFIX" ]; then
    case "$HDTVFIX" in
        [Yy]) HDTVFIX="${UI_TEXT[YES]}" ;;
        [Nn]) HDTVFIX="${UI_TEXT[NO]}" ;;
    esac
    echo "HDTV fix for PS1 Games: $HDTVFIX" >> "${LOG_FILE}"
    echo "• ${UI_TEXT[GAME_INSTALLER_29]} $HDTVFIX"
fi

echo
read -n 1 -s -r -p "${UI_TEXT[CONTINUE]}"
echo
prevent_sleep_start

################################### Prepare Game Files ###################################

# Remove VCD files if they already have a matching bin/cue
for vcd in "${GAMES_PATH}"/POPS/*.VCD "${GAMES_PATH}"/POPS/*.vcd; do
    base="${vcd%.*}"

    if [[ -f "$base.cue" && -f "$base.bin" ]] || \
       [[ -f "$base.CUE" && -f "$base.BIN" ]] || \
       [[ -f "$base.cue" && -f "$base.BIN" ]] || \
       [[ -f "$base.CUE" && -f "$base.bin" ]]; then
        rm -- "$vcd"
    fi
done

# Move remaining VCD/BIN/CUE files to Ember folder
find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" -o -iname "*.cue" \) -exec mv -n {} "${GAMES_PATH}/Ember/games" \;

# Delete all folders that do not contain VMCs (SLOT0.VMC or SLOT1.VMC)
find "${OPL}/POPS/" -mindepth 1 -maxdepth 1 -type d \
    ! -exec test -f '{}/SLOT0.VMC' \; \
    ! -exec test -f '{}/SLOT1.VMC' \; \
    -exec rm -rf {} \;

# Delete unecessary files from remaning folders
find "${OPL}/POPS/" -mindepth 2 -type f ! -name "SLOT0.VMC" ! -name "SLOT1.VMC" -delete

# Rename existing POPS VMCs
find "${OPL}/POPS/" -mindepth 2 -type f \( -name "SLOT0.VMC" -o -name "SLOT1.VMC" \) \
    -exec bash -c 'for f; do
        [[ "${f##*/}" == "SLOT0.VMC" ]] && mv "$f" "${f%/*}/MC1.vmc"
        [[ "${f##*/}" == "SLOT1.VMC" ]] && mv "$f" "${f%/*}/MC2.vmc"
    done' _ {} +

# Move existing POPS VMCs to Ember folder
find "${OPL}/POPS/" -mindepth 1 -maxdepth 1 -type d \-exec mv -n {} "${OPL}/Ember/games/" \;

# Move and convert VCD files for use with Ember
convert_vcd "${GAMES_PATH}/Ember/"

if [ "$INSTALL_TYPE" = "copy" ]; then
    convert_vcd "${OPL}/Ember/games/"
else
    find "${OPL}/Ember/games/" -maxdepth 1 -type f -iname "*.vcd" -delete
fi

SPLASH

echo  >> "${LOG_FILE}"
echo "Contents of ${OPL}/Ember/games:" >> "${LOG_FILE}"
find "${OPL}/Ember/games/" -type f \( -iname '*.bin' -o -iname '*.cue' \) -printf '%P\n' >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"

echo "Local Ember folder contents:" >> "${LOG_FILE}"
find "${GAMES_PATH}/Ember/" -type f \( -iname '*.bin' -o -iname '*.cue' \) -printf '%P\n' >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"

if [ "$INSTALL_TYPE" = "sync" ]; then
    organise_bin "${GAMES_PATH}/Ember"
    ps1_update=$(rsync -rL --dry-run --delete --ignore-existing --itemize-changes --exclude='*/.*' --include='*/' --include='*/*.[cC][uU][eE]' --include='*/*.[bB][iI][nN]' --exclude='*' "${GAMES_PATH}/Ember/" "${OPL}/Ember/games/")

elif [ "$INSTALL_TYPE" = "copy" ]; then
    organise_bin "${GAMES_PATH}/Ember"
    organise_bin "${OPL}/Ember/games"
    ps1_update=$(rsync -rL --dry-run --ignore-existing --itemize-changes --exclude='*/.*' --include='*/' --include='*/*.[cC][uU][eE]' --include='*/*.[bB][iI][nN]' --exclude='*' "${GAMES_PATH}/Ember/" "${OPL}/Ember/games/")
fi

convert_bin

if [[ "$UNCOMPRESS" = "y" ]]; then
    uncompress_zso
fi

if [[ "$COMPRESS" = "y" ]]; then
    compress_zso
fi

echo  >> "${LOG_FILE}"
echo "Local CD folder contents:" >> "${LOG_FILE}"
ls -l "${GAMES_PATH}/CD/" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
echo "Local DVD folder contents:" >> "${LOG_FILE}"
ls -l "${GAMES_PATH}/DVD/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "PS2 CD folder contents:" >> "${LOG_FILE}"
ls -l "${OPL}/CD/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "PS2 DVD folder contents:" >> "${LOG_FILE}"
ls -l "${OPL}/DVD/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}" 

if [ "$INSTALL_TYPE" = "sync" ]; then
    cd=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/")
    dvd=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    cd=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/")
    dvd=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/")
fi

OPL_SIZE_CKECK
SPLASH
INSTALL_SIZE $needed_mb
echo "Total size of games to be installed: $install_size" >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_34]} $install_size"
INSTALL_SIZE $available_mb
echo "Available space: $install_size" >> "${LOG_FILE}"
echo "${UI_TEXT[AVAILABLE_SPACE]} $install_size"
echo | tee -a "${LOG_FILE}"

################################### Synchronize & Copy PS1 Games ###################################

if [ -n "$ps1_update" ]; then
    if [ "$INSTALL_TYPE" = "sync" ]; then
        rsync -rL --progress --delete --ignore-existing --exclude='*/.*' --include='*/' --include='*/*.[cC][uU][eE]' --include='*/*.[bB][iI][nN]' --exclude='*' "${GAMES_PATH}/Ember/" "${OPL}/Ember/games/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo echo "[X] Error: Failed to sync PS1 games." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_SYNC]}"
        fi
    else
        rsync -rL --progress --ignore-existing --exclude='*/.*' --include='*/' --include='*/*.[cC][uU][eE]' --include='*/*.[bB][iI][nN]' --exclude='*' "${GAMES_PATH}/Ember/" "${OPL}/Ember/games/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo "[X] Error: Failed to copy PS1 games." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_COPY]}"
        fi
    fi
else
    SPLASH
    echo "PS1 games are already up-to-date." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_36]}"
    echo
fi

################################### Synchronize & Copy PS2 Games ###################################

if [ -n "$cd" ] || [ -n "$dvd" ]; then
    if [ "$INSTALL_TYPE" = "sync" ]; then
        rsync -dL --progress --delete --ignore-existing --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        rsync -dL --progress --delete --ignore-existing --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check synced
    else
        rsync -dL --progress --ignore-existing --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        rsync -dL --progress --ignore-existing --include='[^.]*.iso' --include='[^.]*.ISO' --include='[^.]*.zso' --include='[^.]*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check copied
    fi
else
    SPLASH
    echo "PS2 games are already up-to-date." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_39]}"
fi

################################### Synchronize & Copy External POPStarter Games ###################################

if [ "$INSTALL_TYPE" = "sync" ]; then
    pops_ext=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='SB.*.ELF' --include='XX.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    pops_ext=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='SB.*.ELF' --include='XX.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
fi

# Set flag if any changes
if [ -n "$pops_ext" ]; then
    SPLASH
    if [ "$INSTALL_TYPE" = "sync" ]; then
        echo "Syncing POPStarter ELF files..." >> "${LOG_FILE}"
        rsync -dL --progress --delete --ignore-existing --include='SB.*.ELF' --include='XX.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" >>"${LOG_FILE}" 2>&1 | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo echo "[X] Error: Failed to sync POPStarter ELF files." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_POPS_SYNC]}"
        fi
    else
        echo "Copying POPStarter ELF files..." >> "${LOG_FILE}"
        rsync -dL --progress --ignore-existing --include='SB.*.ELF' --include='XX.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" >>"${LOG_FILE}" 2>&1 | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo "[X] Error: Failed to copy POPStarter ELF files." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_POPS_COPY]}"
        fi
    fi
else
    echo "POPStarter ELF files are already up-to-date." >> "${LOG_FILE}"
fi

################################### Create PS1 Games List, VMCs, and multi-discs ###################################

# Create games list of PS1 games in ${OPL}/Ember/games
if find "${OPL}/Ember/games" -type f -iname "*.bin" | grep -q .; then
    SPLASH
    echo "Creating PS1 games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_37]}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${EMBER_LIST}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "[X] Error: Failed to create Ember PS1 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS1_LIST]}"
    fi
fi

if [[ ! -s "${EMBER_LIST}" ]] && find "${OPL}/Ember/games/" -type f \( -iname "*.bin" \) | grep -q .; then
    echo "[X] Error: Failed to create Ember games list." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_PS1_LIST]}"
fi

if [ -s "${EMBER_LIST}" ]; then
    CREATE_PS1_VMC

    tmp_file=$(mktemp)

    while IFS='|' read -r title game_id publisher disc_type folder_name jpn_title partition_label; do
        # English title: remove disc text and normalize whitespace
        title=$(sed -E \
            -e 's/\(disc .\)//Ig' \
            -e 's/ +/ /g' \
            -e 's/^ +| +$//g' <<< "$title")

        # Japanese title: remove disc text only
        jpn_title=$(sed -E \
            -e 's/（ディスク.）//g' <<< "$jpn_title")

        printf '%s|%s|%s|%s|%s|%s|%s\n' \
            "$title" "$game_id" "$publisher" "$disc_type" "$folder_name" "$jpn_title" "$partition_label"

    done < "$EMBER_LIST" > "$tmp_file" 

    mv "$tmp_file" "$EMBER_LIST"
    cat "${EMBER_LIST}" > "${PS1_LIST}"
fi

if [ -s "${PFS_POPS_LIST}" ]; then
    cat "${PFS_POPS_LIST}" >> "${PS1_LIST}"
fi

ps1_count=$(grep -c '^[^[:space:]]' "${EMBER_LIST}" 2>/dev/null || echo 0)

# Create games list of PS2 games in ${OPL}/CD/" and "${OPL}/DVD"
if find "${OPL}/CD/" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    SPLASH
    echo "Creating PS2 games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_40]}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${PS2_LIST}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "[X] Error: Failed to create PS2 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS2_LIST]}"
    fi
fi

ps2_count=$(grep -c '^[^[:space:]]' "${PS2_LIST}" 2>/dev/null || echo 0)

if [ -s "${PS2_LIST}" ]; then
    # Create PS2 VMCs if enabled
    if [ "$PS2_VMC" = "y" ]; then
        CREATE_PS2_VMC
    else
        DISABLE_PS2_VMC
    fi

    if [ "$WIDE" = "y" ]; then
        WIDESCREEN_CHEATS
    fi
fi

# Sort games list
if [[ "$lang" == "jpn" &&  -s "${PS1_LIST}" ]]; then
    sort_jpn "${PS1_LIST}" "${PS1_JPN_LIST}"
fi

if [ -s "${PS1_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS1_LIST}" || {
        echo "[X] Error: Failed to sort PS1 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS1_SORT]}"
    }
fi

if [ -s "${PS1_JPN_LIST}" ]; then
    cat "${PS1_JPN_LIST}" > "${TMP_LIST}"
    cat "${PS1_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
    cat "${TMP_LIST}" > "${PS1_LIST}"
fi

if [[ "$lang" == "jpn" &&  -s "${PS2_LIST}" ]]; then
    sort_jpn "${PS2_LIST}" "${PS2_JPN_LIST}"
fi

if [ -s "${PS2_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS2_LIST}" || {
        echo "[X] Error: Failed to sort PS2 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS2_SORT]}"
    }
fi

if [ -s "${PS2_JPN_LIST}" ]; then
    cat "${PS2_JPN_LIST}" > "${TMP_LIST}"
    cat "${PS2_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
    cat "${TMP_LIST}" > "${PS2_LIST}"
fi

if [[ ! -s "${PS2_LIST}" ]] && find "${OPL}/CD/" "${OPL}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    echo "[X] Error: Failed to create games list." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_PS2_LIST]}"
fi

# Create games list of PS1 External Games
if files=( "${OPL}/POPS/"*.ELF ); then
    SPLASH
    pops_count=${#files[@]}
    i="0"
    echo "Creating POPS external games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_62]}"
    for file in "${OPL}/POPS/"*.ELF; do
        filename=$(basename "$file")
        game_id=""

        # First 3 chars determine prefix tag
        prefix="${filename:0:3}"

        case "$prefix" in
            "SB.") tag="SMB"; magic="SB" ;;
            "XX.") tag="BDM"; magic="XX" ;;
            *) i=$((i + 1)); show_progress "$i" "$pops_count"; continue ;;
        esac

        # Ignore the first 3 characters and remove extension
        no_prefix="${filename:3}"

        if [[ "$no_prefix" =~ ^([A-Z]{4}_[0-9]{3}\.[0-9]{2}|LSP[0-9]{5}\.[0-9]{3}) ]] &&
            IFS='|' read -r _ title publisher jpn_title < <(
                grep -m1 "^${BASH_REMATCH[1]}|" "$PS1_DATABASE"
            ); then

            game_id="${BASH_REMATCH[1]}"
        else
            if [[ "$no_prefix" =~ ^(LSP[0-9]{5}\.[0-9]{3}|[A-Z]{4}_[0-9]{3}\.[0-9]{2}) ]]; then
                game_id="${BASH_REMATCH[1]}"
                title="${no_prefix#$game_id}"
                title="${title#[._ -]}"
            else
                title="$no_prefix"
            fi

            title="${title%.ELF}"
            region=""

            case "$title" in
                *"(Europe)"*|*"(Europe, Australia)"*)
                    region="Europe"
                    title="${title/(Europe)/}"
                    title="${title/(Europe, Australia)/}"
                    ;;

                *"(Japan)"*|*"(Japan, Asia)"*)
                    region="Japan"
                    title="${title/(Japan)/}"
                    title="${title/(Japan, Asia)/}"
                    ;;

                *"(USA)"*|*"(USA, Europe)"*|*"(USA, Canada)"*)
                    region="USA"
                    title="${title/(USA)/}"
                    title="${title/(USA, Europe)/}"
                    title="${title/(USA, Canada)/}"
                    ;;
            esac

            # remove languages like (En,Fr,De)
            for inner in $(grep -o '([^)]*)' <<< "$title" | tr -d '()'); do
                if [[ "$inner" =~ ^[A-Za-z]{2}(,[A-Za-z]{2})+$ ]]; then
                    title="${title/($inner)/}"
                fi
            done

            # convert separator only
            title="${title// - /: }"

            # normalize whitespace
            title="$(sed 's/  */ /g; s/^ //; s/ $//' <<< "$title")"

            result=$(
            awk -F'|' -v title="$title" -v region="$region" '
            tolower($2) == tolower(title) {
                code = $1
                third = substr(code, 3, 1)
                first = substr(code, 1, 1)

                if (region == "") {
                    print $0
                    exit
                }

                if (region == "USA") {
                    if (third == "U" || first == "L") {
                        print $0
                        exit
                    }
                }
                else if (region == "Europe") {
                    if (third == "E") {
                        print $0
                        exit
                    }
                }
                else if (region == "Japan") {
                    if (third != "U" && third != "E" && first != "L") {
                        print $0
                        exit
                    }
                }
            }
            ' "$PS1_DATABASE"
            )

            if [[ -n "$result" ]]; then
                IFS='|' read -r game_id title publisher jpn_title <<< "$result"
            else
                publisher=""
                jpn_title=""
            fi

            if [[ -z "$game_id" ]]; then
                game_id="POPSTARTER"
            fi
        fi
            make_partition_label "$game_id" "$magic" "$title"
            echo "$title|$game_id|$publisher|$tag|$filename|$jpn_title|$partition_label" >> "${EXT_POPS_LIST}"
            i=$((i + 1))
            show_progress "$i" "$pops_count"
    done
fi

if [ -s "${EXT_POPS_LIST}" ]; then

    # Sort games list
    if [[ "$lang" == "jpn" ]]; then
        sort_jpn "${EXT_POPS_LIST}" "${POPS_JPN_LIST}"
    fi

    if [ -s "${EXT_POPS_LIST}" ]; then
        python3 "${HELPER_DIR}/list-sorter.py" "${EXT_POPS_LIST}" || {
            echo "[X] Error: Failed to sort the POPStarter SMB games list." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_SORT]}"
        }
    fi

    if [ -s "${POPS_JPN_LIST}" ]; then
        cat "${POPS_JPN_LIST}" > "${TMP_LIST}"
        cat "${EXT_POPS_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
        cat "${TMP_LIST}" > "${EXT_POPS_LIST}"
    fi

    echo >> "${LOG_FILE}"
    echo "ext-pops.list:" >> "${LOG_FILE}"
    cat "${EXT_POPS_LIST}" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
else
    echo | tee -a "${LOG_FILE}"
    echo "No POPS external games to process." >> "${LOG_FILE}"
    collection_count="0"
fi

################################### Synchronize & Copy Apps ###################################

SPLASH

# Remove outdated apps
rm -f "${GAMES_PATH}/APPS/"{Launch-Disc.elf,HDD-OSD.elf,PSBBN.ELF,SYS_OSDMENU-CONFIGURATOR.psu}
rm -rf "${OPL}/APPS/APP_WLE-ISR-"
rm -rf "${OPL}/APPS/SYS_OSDMENU-CONFIGURATOR"
rm -rf "${OPL}/APPS/PSBBN"

md5_check "${OPL}/POPS/POPSLOADER.ELF" "a99c9bce7633363ec3973be352da7592"

if [ "$delete_app" = "yes" ]; then
    rm -f "${OPL}/POPS/POPSLOADER.ELF"
fi

md5_check "${GAMES_PATH}/APPS/BOOT.ELF" "20a5b2c1ffb86e742fb5705b5d9d7370"

if [ "$delete_app" = "yes" ]; then
    rm -f "${GAMES_PATH}/APPS/BOOT.ELF"
fi

md5_check "${GAMES_PATH}/APPS/APP_WLE-ISR-XF-MM.psu" "23aa962e31740c6101a1c5b74cd253e3"

if [ "$delete_app" = "yes" ]; then
    rm -f "${GAMES_PATH}/APPS/APP_WLE-ISR-XF-MM.psu"
fi

if [ ! -f "${OPL}/Ember/bios.bin" ]; then
    if [ ! -f "${ASSETS_DIR}/dep/bios.bin" ]; then
        download_files
    fi

    if ! cp "${ASSETS_DIR}/dep/bios.bin" "${OPL}/Ember/bios.bin"; then
        echo "Warning: The PS1 BIOS file is missing."  >> "${LOG_FILE}" 2>&1
        error_msg "Warning" "${UI_TEXT[WARN_PS1_BIOS]}"
    fi
fi

update_apps "Ember" "${ASSETS_DIR}/Ember/ember.elf" "${OPL}/Ember/ember.elf" "-ut --progress"
update_apps "Neutrino" "${NEUTRINO_DIR}/" "${OPL}/neutrino/" "-rut --progress --delete --exclude='.*'"

if [ "$INSTALL_TYPE" = "sync" ]; then
    echo >> "${LOG_FILE}"
    echo "Preparing to sync apps..." >> "${LOG_FILE}"

    cd "${GAMES_PATH}/APPS/" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to change directory: ${GAMES_PATH}/APPS." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CD]} ${GAMES_PATH}/APPS."
    }
    process_psu_files "${GAMES_PATH}/APPS/"

    install_elf "${GAMES_PATH}"

    rsync -rut --progress --delete --prune-empty-dirs --include='*/' --include='*/**' --exclude='.*' --exclude='*Zone.Identifier' --exclude='*' "${GAMES_PATH}/APPS/" "${OPL}/APPS/" >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed sync apps." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_SYC_APPS]}"
    }

elif [ "$INSTALL_TYPE" = "copy" ]; then
    echo >> "${LOG_FILE}"
    echo "Preparing to copy apps..." >> "${LOG_FILE}"
    cd "${OPL}/APPS/" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to change directory: ${OPL}/APPS." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CD]} ${OPL}/APPS."
    }

    process_psu_files "${GAMES_PATH}/APPS/"
    process_psu_files "${OPL}/APPS/"
    cd "${TOOLKIT_PATH}"

    install_elf "${GAMES_PATH}"
    install_elf "${OPL}"

    find "${GAMES_PATH}/APPS/" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} "${OPL}/APPS/" \; || {
        echo "[X] Error: Failed copy apps." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_COPY_APPS]}"
    }
fi

# Create list of homebrew apps
SOURCE_DIR="${OPL}/APPS"

APP_COUNT="0"

for dir in "${SOURCE_DIR}"/*/; do
    [[ -d "$dir" ]] || continue

    if find "$dir" -maxdepth 1 -type f -iname "*.elf" -print -quit | grep -q .; then
        ((APP_COUNT++))
    fi
done

if [ "$APP_COUNT" -gt 0 ]; then
    SPLASH
    echo "Creating application list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_73]}"
    i="0"
    for dir in "${SOURCE_DIR}"/*/; do
        [[ -d "$dir" ]] || continue

        if find "$dir/" -maxdepth 1 -type f -iname "*.elf" | grep -q . \
            && [ -r "$dir/title.cfg" ]; then

            title=""
            title_short=""
            elf=""
            publisher=""
            title_id=""
            folder_name=$(basename "$dir")
            pp_name=$(echo "$folder_name" | sed 's/[^A-Za-z0-9_-]//g' | tr 'a-z' 'A-Z')
            pp_name="PP.${pp_name:0:29}"

            while IFS='=' read -r key value; do
                key=$(echo "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                # Remove non-ASCII and non-printable characters
                value=$(printf '%s' "$value" | tr -d '\000-\011\013-\037\177')

                case "$key" in
                    title) title="$value" ;;
                    boot) elf="$value" ;;
                    Developer) publisher="$value" ;;
                    Title_ID) title_id="$value" ;;
                esac
            done < "$dir/title.cfg"

            if [ -z "$title" ] || [ -z "$elf" ]; then
                continue
            fi

            if [[ -z "$title_id" ]]; then
                title_id="${folder_name//[^A-Za-z0-9_]/}"
                title_id="${title_id:0:12}"
                title_id="${title_id^^}"
            fi

            title="${title#\[*\]}"
            title="${title#"${title%%[![:space:]]*}"}"

            if [[ $folder_name =~ ^(...)\_ ]]; then
                category="${BASH_REMATCH[1]}"
            else
                category="APP"
            fi

            case "$category" in
                SYS|EMU|GME|DST|DBG|PS1|RTE|DEM) ;;
                *) category="APP" ;;
            esac

            cat >> "${APPS_LIST}" <<EOL
$title|$title_id|$publisher|$category|ata:/APPS/$folder_name/$elf||$pp_name
EOL

            i=$((i + 1))
            show_progress "$i" "$APP_COUNT"
        fi
    done
        echo | tee -a "${LOG_FILE}"
else
    echo "No apps to process." >> "${LOG_FILE}"
fi

if [ -s "$APPS_LIST" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${APPS_LIST}" || {
        echo "[X] Error: Failed to sort application list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_APP_SORT]}"
    }
fi

# Sends a list of apps and games synced/copied to the log file
echo "PS1 games on drive:" >> "${LOG_FILE}"
ls -1 "${OPL}/POPS/" >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "PS2 games on drive:" >> "${LOG_FILE}"
ls -1 "${OPL}/CD/" >> "${LOG_FILE}" 2>&1
ls -1 "${OPL}/DVD/" >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "APPS on drive:" >> "${LOG_FILE}"
find "${OPL}/APPS/" -type f -name '*.elf' -printf '%P\n' >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"

APP_COUNT=$(grep -c '^[^[:space:]]' "${APPS_LIST}" 2>/dev/null || echo 0)

################################### OPL Artwork ###################################

if [[ -s "$PS1_LIST" || -s "$PS2_LIST" || -s "$APPS_LIST" ]]; then
    SPLASH
    ART_TOTAL=$((ps1_count + ps2_count + APP_COUNT))
    echo "Downloading artwork for OPL..."  >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_43]}"
    i="0"
    show_progress "$i" "$ART_TOTAL"

    if opl_manager_id; then
        if [ -s "${EMBER_LIST}" ]; then
            opl_game_art "${EMBER_LIST}"
        fi

        if [ -s "${PS2_LIST}" ]; then
            opl_game_art "${PS2_LIST}"
        fi
    else
        echo "Warning: Unable to retrieve the API user ID." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_API]}"
    fi

    if [ -s "${APPS_LIST}" ]; then
        exec 3< "${APPS_LIST}"
        while IFS='|' read -r title title_id publisher disc_type file_name jpn_title partition_label <&3; do
            png_file="${ARTWORK_DIR}/${title_id}.png"
            elf=$(basename "$file_name")

            if [ ! -s "$png_file" ]; then
                echo "Artwork not found locally for $title_id. Attempting to download from the PSBBN art database..." >> "${LOG_FILE}"
                wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
                "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/apps/${title_id}.png"
                    
                if [[ -s "$png_file" ]]; then
                    echo "[✓] Successfully downloaded artwork for $title_id" >> "${LOG_FILE}"
                else
                    rm -f "$png_file"
                    echo "$title_id,$title,$elf" >> "${MISSING_APP_ART}"
                fi
            fi
            
            if [[ -s "$png_file" ]]; then
                cp "$png_file" "${OPL}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || {
                    echo "[X] Error: Failed to create ${OPL}/ART/${elf}_COV.png" >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${OPL}/ART/${elf}_COV.png"
                }
                echo "Created: ${OPL}/ART/${elf}_COV.png"  >> "${LOG_FILE}"
            fi

            i=$((i + 1))
            show_progress "$i" "$ART_TOTAL"
        done
        echo
        exec 3<&-
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No OPL artwork to download." >> "${LOG_FILE}"
fi

################################### Assets for Included Apps ###################################

SPLASH

# Game Launcher
pp_name="PP.LAUNCHER"
system_cnf="${SCRIPTS_DIR}/tmp/$pp_name/system.cnf"
info_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/info.sys"
icon_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/icon.sys"

mkdir -p "${SCRIPTS_DIR}/tmp/$pp_name"

title="Open PS2 Loader: RiptOPL"
title_id="APP_RIPTOPL"
publisher="github.com/NathanNeurotic"
elf="hdd0:__system:pfs:/launcher/RIPTOPL-RA-UNPAKT.ELF"

cp "${ICONS_DIR}/ico/APP_RIPTOPL_LST.ico" "${SCRIPTS_DIR}/tmp/$pp_name/list.ico" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/list.ico" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/list.ico"
}
cp "${ICONS_DIR}/ico/APP_RIPTOPL_DEL.ico" "${SCRIPTS_DIR}/tmp/$pp_name/del.ico" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/del.ico" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/del.ico"
}

cp "${ARTWORK_DIR}/APP_RIPTOPL.png" "${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png"
}

echo "$title|$title_id|$publisher|INC|$elf||$pp_name" >> "${ALL_TITLES}"\

create_system_cnf "$elf" "$title_id"
create_info_sys "[LCH] $title" "$title_id" "$publisher"
create_icon_sys "$title" "Launcher"

if [ "$OS" = "PSBBN" ]; then
    # PSBBN
    title="BB Navigator"
    title_id="SCPN_601.60"
    publisher="Sony Computer Entertainment"
    elf="hdd0:__system:pfs:/p2lboot/osdboot.elf"
    pp_name="PP.SCPN-60160.PSBBN"
    system_cnf="${SCRIPTS_DIR}/tmp/$pp_name/system.cnf"
    info_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/info.sys"
    icon_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/icon.sys"
    
    mkdir -p "${SCRIPTS_DIR}/tmp/$pp_name"

    cp "${ICONS_DIR}/ico/SYS_PSBBN_LST.ico" "${SCRIPTS_DIR}/tmp/$pp_name/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/list.ico"
    }
    cp "${ICONS_DIR}/ico/SYS_PSBBN_DEL.ico" "${SCRIPTS_DIR}/tmp/$pp_name/del.ico" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/del.ico" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/del.ico"
    }

    echo "$title|$title_id|$publisher|INC|$elf||$pp_name" >> "${ALL_TITLES}"

    create_system_cnf "$elf" "$title_id"
    create_info_sys "[LCH] $title" "$title_id" "$publisher"
    create_icon_sys "$title" "Launcher"

    #HOSDMenu
    title="HOSDMenu"
    title_id="SYS_OSDMENU"
    publisher="github.com/pcm720"
    elf=hdd0:__system:pfs:/osdmenu/hosdmenu.elf
    pp_name="PP.HOSDMENU.HIDDEN"
    system_cnf="${SCRIPTS_DIR}/tmp/$pp_name/system.cnf"
    info_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/info.sys"
    icon_sys_filename="${SCRIPTS_DIR}/tmp/$pp_name/icon.sys"

    mkdir -p "${SCRIPTS_DIR}/tmp/$pp_name"

    cp "${ICONS_DIR}/ico/APP_DEFAULT_LST.ico" "${SCRIPTS_DIR}/tmp/$pp_name/list.ico" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/list.ico" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/list.ico"
    }
    cp "${ARTWORK_DIR}/SYS_OSDMENU.png" "${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to create: ${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${SCRIPTS_DIR}/tmp/$pp_name/jkt_001.png"
    }

    echo "$title|$title_id|$publisher|INC|$elf||$pp_name" >> "${ALL_TITLES}"

    create_system_cnf "$elf"
    create_info_sys "[LCH] $title" "$title_id" "$publisher"
    create_icon_sys "$title"
fi

################################### Game Selector ###################################

cat "${PS1_LIST}" "${EXT_POPS_LIST}" "${PS2_LIST}" "${APPS_LIST}" 2>/dev/null >> "${ALL_TITLES}"

if [ -s "${ALL_TITLES}" ]; then
    # Set maximum number of items for the Game Channel
    APA_SIZE_CHECK

    if [ "$OS" = "PSBBN" ]; then
        pp_cap="801"
    else
        pp_cap="800"
    fi

    if [ $pp_max -gt $pp_cap ]; then
        pp_max="$pp_cap"
    fi

    if [ "$pp_max" -lt 4 ]; then
        echo "[X] Error: Insufficient space for launcher partition." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PARTITION_MAX]}"
    fi
    
    cd ${TOOLKIT_PATH}
    python3 "${HELPER_DIR}/game-selector.py" "$ALL_TITLES" --max-games $pp_max --lang "$LANG_FILE" --exclude-file "${OPL}/exclude.list"
fi

if [ -s "$SELECTED_LIST" ]; then
    collection_count=$(grep -c '^[^[:space:]]' "${SELECTED_LIST}")
    echo >> "${LOG_FILE}"
    echo "Title Selected:" >> "${LOG_FILE}"
    cat "$SELECTED_LIST" >> "${LOG_FILE}"
else
    error_msg "Error" "${UI_TEXT[ERROR_GAME_LIST]}"
fi


################################### Creating Assets ###################################

echo >> "${LOG_FILE}"
echo "Preparing to create assets..." >> "${LOG_FILE}"

mkdir -p "${ARTWORK_DIR}/tmp" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ARTWORK_DIR}/tmp." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ARTWORK_DIR}/tmp."
}
mkdir -p "${ICONS_DIR}/ico/tmp" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ICONS_DIR}/ico/tmp/vmc" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/ico/tmp/vmc"
}

# Assets for Apps

if [ -s "$SELECTED_LIST" ] &&
   collection_count=$(awk -F'|' '$4 ~ /^(SYS|EMU|GME|DST|DBG|PS1|RTE|DEM|APP)$/ { c++ } END { print c+0 }' "$SELECTED_LIST") &&
   [ "$collection_count" -gt 0 ]
then
    create_app_assets
else
    echo | tee -a "${LOG_FILE}"
    echo "No apps to process." >> "${LOG_FILE}"
fi

# Assets for Games

if [ -s "$SELECTED_LIST" ] &&
   collection_count=$(awk -F'|' '$4 ~ /^(DVD|CD|EMBER|__.POPS|SMB|BDM)$/ { c++ } END { print c+0 }' "$SELECTED_LIST") &&
   [ "$collection_count" -gt 0 ]
then
    create_game_assets
else
    echo | tee -a "${LOG_FILE}"
    echo "Create Game Assets: No games to process." >> "${LOG_FILE}"
fi

# Copy OPL related files
dirs=(
    "${GAMES_PATH}/ART"
    "${GAMES_PATH}/CFG"
    "${GAMES_PATH}/CHT"
    "${GAMES_PATH}/LNG"
    "${GAMES_PATH}/THM"
    "${GAMES_PATH}/VMC"
)

# Flag to track if any files exist
files_exist=false

# Check each directory and copy files if not empty
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ] && [ -n "$(find "$dir/" -type f ! -name '.*' -print -quit 2>/dev/null)" ]; then
        folder_name=$(basename "$dir")
        dest_dir="${OPL}/$folder_name"
        
        # Copy non-hidden files to the corresponding destination subdirectory
        if [ "$folder_name" == "CFG" ] || [ "$folder_name" == "VMC" ]; then
            echo "Copying OPL $folder_name files..." >> "${LOG_FILE}"
            # Do not overwrite existing config and VMC files
            find "$dir/" -type f ! -name '.*' -exec cp --update=none {} "$dest_dir" \; >> "${LOG_FILE}" 2>&1
        else
            if [ -n "$(find "$dir/" -mindepth 1 ! -name '.*' -print -quit)" ]; then
            echo "Copying OPL $folder_name files..." >> "${LOG_FILE}"
            cp -r "$dir"/* "$dest_dir" >> "${LOG_FILE}" 2>&1
        fi
    fi
        files_exist=true
    fi
done

# Print message based on the check
if ! $files_exist; then
    echo "No OPL files to copy." >> "${LOG_FILE}"
fi

rm -f "${OPL}/CD/games.bin" "${OPL}/DVD/games.bin" &>/dev/null

if [ -s "$ALL_TITLES" ] &&
   collection_count=$(awk -F'|' '$4 ~ /^(DVD|CD|EMBER)$/ { c++ } END { print c+0 }' "$SELECTED_LIST") &&
   [ "$collection_count" -gt 0 ]
then
    create_cfg
else
    echo | tee -a "${LOG_FILE}"
    echo "Create CFG files: No games to process." >> "${LOG_FILE}"
fi

# Enable OPL Loader Core and Compatibility Mode 1 for all ZSO files in RiptOPL game configs
if [[ -f "${PS2_LIST}" ]]; then
    exec 3< "${PS2_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do
        if [[ "$file_name" == *.zso || "$file_name" == *.ZSO ]]; then
            cfg_file="${OPL}/CFG/${game_id}.cfg"
            if [[ -f "$cfg_file" ]] && grep -q '^\$Compatibility=' "$cfg_file"; then
                : # Compatibility modes already configured
            else
                printf '$Compatibility=1\n' >> "$cfg_file"
            fi

            sed -i "/^\$CoreLoader/d" "$cfg_file"
            printf '$CoreLoader=0\n' >> "$cfg_file"
        fi
    done
    exec 3<&-
fi

################################### Modify Config Files ###################################

case "$lang" in
    jpn)
        OPL_LANG="japanese"
        R3CONFIG_LANG="en"
        WLE_LANG="english"
        ;;
    fre)
        OPL_LANG="French"
        R3CONFIG_LANG="fr"
        WLE_LANG="french"
        ;;
    spa)
        OPL_LANG="Spanish"
        R3CONFIG_LANG="es"
        WLE_LANG="spanish"
        ;;
    ger)
        OPL_LANG="German"
        R3CONFIG_LANG="de"
        WLE_LANG="german"
        ;;
    ita)
        OPL_LANG="Italian"
        R3CONFIG_LANG="en"
        WLE_LANG="italian"
        ;;
    por)
        OPL_LANG="Portuguese_BR"
        R3CONFIG_LANG="pt"
        WLE_LANG="brazilian"
        ;;
    hun)
        OPL_LANG="Hungarian"
        R3CONFIG_LANG="en"
        WLE_LANG="hungarian"
       ;;
    rus)
        OPL_LANG="Russian"
        R3CONFIG_LANG="en"
        WLE_LANG="english"
        ;;
    *)
        OPL_LANG="English (internal)"
        R3CONFIG_LANG="en"
        WLE_LANG="english"
        ;;
esac

if [[ "$ENTER" == "O" ]]; then
    OPL_ENTER="0"
    R3CONFIG_ENTER="1"
    WLE_ENTER="0"
else
    OPL_ENTER="1"
    R3CONFIG_ENTER="0"
    WLE_ENTER="1"
fi

if [ "$WIDE" = "y" ]; then
    OPL_WIDE="1"
else
    OPL_WIDE="0"
fi

if [ "$LAUNCHER" = "OPL" ]; then
    CORE="0"
else
    CORE="1"
fi

echo "OPL Language: $OPL_LANG" >> "${LOG_FILE}"
cp "${ASSETS_DIR}/OPL/LNG"/* "${OPL}/LNG" >> "${LOG_FILE}" 2>&1

if [[ ! -f "${OPL}/settings_riptopl.cfg" ]]; then
    cat >> "${OPL}/settings_riptopl.cfg" <<EOL
enable_notifications=1
enable_coverart=1
enable_discart=0
enable_logoart=1
enable_bgart=1
ps2logo=0
apply_gameid=1
enable_rumble=0
cfg_titles_in_lists=1
igr_menu=1
igr_alt_combo=0
language_text=$OPL_LANG
swap_select_btn=$OPL_ENTER
EOL
fi

if [[ -f "${OPL}/settings_riptopl.cfg" ]]; then
    sed -i \
        -e '/^default_device=/d' \
        -e '/^usb_mode=/d' \
        -e '/^app_mode=/d' \
        -e '/^enable_bdm_hdd=/d' \
        -e '/^default_core=/d' \
        -e '/^ra_telemetry=/d' \
        -e '/^ra_badges=/d' \
        -e '/^ra_badge_suffix=/d' \
        -e '/^ra_mode=/d' \
        -e '/^ra_experimental_cards=/d' \
        "${OPL}/settings_riptopl.cfg"
fi

cat >> "${OPL}/settings_riptopl.cfg" <<EOL
default_device=0
usb_mode=2
app_mode=2
enable_bdm_hdd=1
default_core=$CORE
EOL

if [ "$RA" = "y" ]; then
    cat >> "${OPL}/settings_riptopl.cfg" <<EOL
ra_telemetry=1
ra_badges=1
ra_badge_suffix=1
ra_mode=0
ra_experimental_cards=0
EOL
fi

if [[ -f "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.elf" ]]; then
    R3CONFIG_INSTALLED="YES"
    if [[ ! -f "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" ]]; then
        echo "R3CONFIGURATOR Language: $R3CONFIG_LANG" >> "${LOG_FILE}"
        echo "R3CONFIGURATOR Button: $R3CONFIG_ENTER" >> "${LOG_FILE}"
        cat >> "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" <<EOL
default_language = $R3CONFIG_LANG
show_freemcboot = 0
show_freehddboot = 0
show_osdmenu = 0
show_osdmenu_mbr = 1
show_hosdmenu = 1
show_ps2bbl = 0
show_psxbbl = 0
swap_buttons = $R3CONFIG_ENTER
EOL
    fi
fi

if [[ -f "${OPL}/APPS/APP_WLE-R3Z/WLE-R3Z.ELF" ]]; then
    WLE_INSTALLED="YES"
    echo "wLE Language: $WLE_LANG" >> "${LOG_FILE}"
    echo "wLE Button: $WLE_ENTER" >> "${LOG_FILE}"
    if [[ ! -f "${OPL}/APPS/APP_WLE-R3Z/LAUNCHELF.CNF" ]]; then
        cat >> "${OPL}/APPS/APP_WLE-R3Z/LAUNCHELF.CNF" <<EOL
language = $WLE_LANG
GUI_Swap_Keys = $WLE_ENTER
EOL
    fi
fi

echo | tee -a "${LOG_FILE}"
echo "All assets have been sucessfully created." >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
SPLASH
echo "Unmounting OPL partition..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[GAME_INSTALLER_48]}"

UNMOUNT_OPL
sleep 2
echo >> "${LOG_FILE}"
mount_pfs

if [ "$OS" = "PSBBN" ]; then
    mapper_probe
    mount_cfs
fi

SPLASH
rm -f "${STORAGE_DIR}/__system/launcher/"{OPNPS2LD.ELF,nhddl.elf}
update_apps "OPL" "${ASSETS_DIR}/OPL/RIPTOPL-RA-UNPAKT.ELF" "${STORAGE_DIR}/__system/launcher/RIPTOPL-RA-UNPAKT.ELF" "-t --progress"

echo >> "${LOG_FILE}"
if [ "$OS" = "PSBBN" ]; then
    echo "Updating shortcuts in Navigator Menu..." | tee -a "${LOG_FILE}"
    echo -n "${UI_TEXT[GAME_INSTALLER_50]}"

    sudo mkdir -p "${STORAGE_DIR}/__linux.7/bn/sysconf"
    sudo cp "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0" "${SCRIPTS_DIR}/tmp" >> "${LOG_FILE}" 2>&1

    TARGET="${SCRIPTS_DIR}/tmp/shortcut_0"
    TMP_FILE=$(mktemp ${SCRIPTS_DIR}/tmp/shortcut_0.XXXXXX)

    # If TARGET exists, remove lines containing PP.LAUNCHER, PP.POPSLOADER, PP.APP_WLE-ISR-, PP.WLAUNCHELFR, and PP.HOSDMENU
    if [ -f "$TARGET" ]; then
        sudo sed -i '/PP\.LAUNCHER/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.POPSLOADER/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.APP_WLE-ISR-/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.APP_WLE-R3Z/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.HOSDMENU\.HIDDEN/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.SYS_R3CONFIGURATOR/d' "$TARGET" >> "${LOG_FILE}" 2>&1
    fi

    # Count lines in TARGET (0 if doesn't exist)
    if [ -f "$TARGET" ]; then
        LINE_COUNT=$(sudo wc -l "$TARGET" | awk '{print $1}')
    else
        LINE_COUNT=0
    fi

    # If TARGET has less than 4 rows
    if [ "$LINE_COUNT" -lt 4 ]; then
        echo "Open%20PS2%20Loader%3A%20RiptOPL file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.LAUNCHER" > "$TMP_FILE"
    fi

    if [ $((LINE_COUNT + 1)) -lt 4 ] && grep -qE '\|PP\.APP_WLE-R3Z$' "$SELECTED_LIST"; then
        echo "wLaunchELF-R3Z file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.APP_WLE-R3Z" >> "$TMP_FILE"
    fi

    if [ $((LINE_COUNT + 2)) -lt 4 ] && grep -qE '\|PP\.SYS_R3CONFIGURATOR$' "$SELECTED_LIST"; then
        echo "R3CONFIGURATOR file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.SYS_R3CONFIGURATOR" >> "$TMP_FILE"
    fi

    if [ $((LINE_COUNT + 3)) -lt 4 ]; then
        echo "HOSDMenu file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.HOSDMENU.HIDDEN" >> "$TMP_FILE"
    fi

    # Append TMP_FILE to TARGET
    sudo tee -a "$TARGET" < "$TMP_FILE" > /dev/null


    # Replace TARGET with updated version
    sudo cp -f "$TARGET" "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
fi

echo "Updating HOSDMenu app list..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[GAME_INSTALLER_51]}"

cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" "${OSDMENU_CNF}"
sed -i '/^name_OSDSYS_ITEM/d; /^path/d; /^arg_OSDSYS/d;' "$OSDMENU_CNF"

# Ensure the file ends with a newline
[ -n "$(tail -c1 "$OSDMENU_CNF" | tr -d '\n')" ] && echo >> "$OSDMENU_CNF"


{
    echo "name_OSDSYS_ITEM_1 = Open PS2 Loader: RiptOPL"
    echo "path1_OSDSYS_ITEM_1 = hdd0:__system/launcher/RIPTOPL-RA-UNPAKT.ELF"
    echo "arg_OSDSYS_ITEM_1 = -titleid=APP_RIPTOPL"
} >> "$OSDMENU_CNF"


if [ "$OS" = "PSBBN" ]; then
{
        echo "name_OSDSYS_ITEM_2 = BB Navigator"
        echo "path1_OSDSYS_ITEM_2 = hdd0:__system/p2lboot/osdboot.elf"
        echo "arg_OSDSYS_ITEM_2 = -titleid=SCPN-601.60"
} >> "$OSDMENU_CNF"
    item=3
    max_items=198
else
    item=2
    max_items=199
fi

# Read each line from the file in $APPS_LIST
exec 3< "${APPS_LIST}"
while IFS='|' read -r title title_id publisher disc_type file_name jpn_title partition_label <&3; do
  # Skip empty lines
  [ -z "$title" ] && continue

  # Truncate to 79 characters, max supported by OSDMenu
  [ ${#title} -gt 79 ] && title="${title:0:76}..."

  # Stop at 200 items
  [ "$item" -gt "$max_items" ] && break

  {
    echo "name_OSDSYS_ITEM_${item} = ${title}"
    echo "path1_OSDSYS_ITEM_${item} = ${file_name}"
    echo "arg_OSDSYS_ITEM_${item} = -titleid=${title_id}"
  } >> "$OSDMENU_CNF"

  ((item++))
done
exec 3<&-

cp -f "${OSDMENU_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF"
echo | tee -a "${LOG_FILE}"

echo "Updating OSDMenu MBR boot keys..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[GAME_INSTALLER_52]}"

cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}"

# Remove any existing boot_ lines
sed -i '/^boot_square/d' "${OSDMBR_CNF}" 2>> "${LOG_FILE}"

if grep -Fxq 'boot_triangle = ata:/POPS/POPSLOADER.ELF' "$OSDMBR_CNF" && grep -Fxq 'boot_triangle_arg1 = -page=ata' "$OSDMBR_CNF"; then
    sed -i '/^boot_triangle/d' "$OSDMBR_CNF"
fi

if [ "$WLE_INSTALLED" = "YES" ]; then
    sed -i '/^boot_start/d' "$OSDMBR_CNF" 2>>"$LOG_FILE"
fi

if [ "$R3CONFIG_INSTALLED" = "YES" ]; then
    sed -i '/^boot_select/d' "$OSDMBR_CNF" 2>>"$LOG_FILE"
fi

# Ensure the file ends with a new line
[ -n "$(tail -c1 "$OSDMBR_CNF" | tr -d '\n')" ] && echo >> "$OSDMBR_CNF"
{
    echo 'boot_square = hdd0:__system:pfs:launcher/RIPTOPL-RA-UNPAKT.ELF'
    
    if [ "$WLE_INSTALLED" = "YES" ]; then
        echo 'boot_start = ata:/APPS/APP_WLE-R3Z/WLE-R3Z.ELF'
    fi

    if [ "$R3CONFIG_INSTALLED" = "YES" ]; then
        echo 'boot_select = ata:/APPS/SYS_R3CONFIGURATOR/r3configurator.elf'
    fi

} >> "${OSDMBR_CNF}"

cp -f "${OSDMBR_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"

echo | tee -a "${LOG_FILE}"

unmount_apa

################################### Create Launcher Partitions ###################################

# Delete existing PP partitions

HDL_TOC

delete_partition=$(grep -o 'PP\.[^ ]\+' "$hdl_output")

echo >> "${LOG_FILE}"
echo "Existing PP Partitions:" >> "${LOG_FILE}"
echo "$delete_partition" >> "${LOG_FILE}"

if [ -n "$delete_partition" ]; then
    COMMANDS="device ${DEVICE}\n"

    while IFS= read -r partition; do
        COMMANDS+="rmpart ${partition}\n"
    done <<< "$delete_partition"

    COMMANDS+="exit"

    echo | tee -a "${LOG_FILE}"
    echo "Deleting PP partitions..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_31]}"
    PFS_COMMANDS

    HDL_TOC

    delete_partition=$(grep -o 'PP\.[^ ]\+' "$hdl_output")
    
    if [ -n "$delete_partition" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Unable to delete the following partitions:" >> "${LOG_FILE}"
        echo "$delete_partition" >> "${LOG_FILE}"
        echo "[X] Error: Failed to delete existing PP partitions." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_DELETE_PARTITION]}"
    else
        echo "Existing PP partitions sucessfully deleted." >> "${LOG_FILE}"
        echo "${UI_TEXT[GAME_INSTALLER_32]}"
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No PP partitions to delete." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_33]}"
fi

if [ -s "$SELECTED_LIST" ]; then
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating Launcher Partitions..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_56]}"
    collection_count=$(grep -c '^[^[:space:]]' "${SELECTED_LIST}")
    create_launcher_partitions
fi

################################### Submit missing artwork to the PSBBN Art Database ###################################

SPLASH
cp "${MISSING_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_APP_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_ICON}" "${ICONS_DIR}/ico/tmp" >> "${LOG_FILE}" 2>&1

cd "${ICONS_DIR}/ico/tmp/"
rm *.png >/dev/null 2>&1
if ! bsdtar -acf "${ARTWORK_DIR}/tmp/ico.zip" * >/dev/null 2>&1; then
    rm -f "${ARTWORK_DIR}/tmp/ico.zip"
fi

cd "${ARTWORK_DIR}/tmp/" 
if ! bsdtar -acf "${ARTWORK_DIR}/tmp/art.zip" * >/dev/null 2>&1; then
    rm -f "${ARTWORK_DIR}/tmp/art.zip"
fi

if [ -f "${ARTWORK_DIR}/tmp/art.zip" ]; then
    echo "Contributing to the PSBBN art & HDD-OSD databases..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_57]}"

    # Upload the file using transfer.sh
    upload_url=$(curl -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@${ARTWORK_DIR}/tmp/art.zip" https://litterbox.catbox.moe/resources/internals/api.php)

    if [[ "$upload_url" == https://* ]]; then
        echo "[✓] ${UI_TEXT[GAME_INSTALLER_58]} $upload_url" >> "${LOG_FILE}"

        # Send a POST request to Webhook.site with the uploaded file URL
        webhook_url="https://webhook.site/PSBBN"
        curl -X POST -H "Content-Type: application/json" \
            -d "{\"url\": \"$upload_url\"}" \
            "$webhook_url" >/dev/null 2>&1
    else
        echo "Failed to upload the file." >> "${LOG_FILE}"
        echo "[X] ${UI_TEXT[GAME_INSTALLER_59]}"
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No art work or icons to contribute." >> "${LOG_FILE}"
fi

HDL_TOC
echo >> "${LOG_FILE}"
cat "$hdl_output" >> "${LOG_FILE}"
rm -f "$hdl_output"

MENU_KEYS=(
    GAME_INSTALLER_67
    GAME_INSTALLER_68
    BDMASSAULT_URL
)

center_menu

SPLASH
echo "================================== [✓] Game Installer Completed Successfully =================================" >> "${LOG_FILE}"
center_title "[✓] ${UI_TEXT[GAME_INSTALLER_60]}"
echo
center_text "${UI_TEXT[CONTINUE]}"
read -n 1 -s -r -p "$text" </dev/tty
echo

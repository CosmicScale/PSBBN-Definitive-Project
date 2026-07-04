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

export LC_ALL=en_US.UTF-8

version_check="2.10"

# Set paths
TOOLKIT_PATH="$(pwd)"
ICONS_DIR="${TOOLKIT_PATH}/icons"
ARTWORK_DIR="${ICONS_DIR}/art"
VMC_ICON_DIR="${ICONS_DIR}/ico/vmc"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
POPSTARTER="${ASSETS_DIR}/POPStarter/POPSTARTER.ELF"
POPS_DIR="${ICONS_DIR}/POPS"
NEUTRINO_DIR="${ASSETS_DIR}/neutrino"
LOGS_DIR="${TOOLKIT_PATH}/logs"
LOG_FILE="${LOGS_DIR}/game-installer.log"
MISSING_ART="${LOGS_DIR}/missing-art.log"
MISSING_APP_ART="${LOGS_DIR}/missing-app-art.log"
MISSING_ICON="${LOGS_DIR}/missing-icon.log"
MISSING_VMC="${LOGS_DIR}/missing-vmc.log"
GAMES_PATH="${TOOLKIT_PATH}/games"
CONFIG_FILE="${SCRIPTS_DIR}/gamepath.cfg"

OPL="${SCRIPTS_DIR}/OPL"
PS1_LIST="${SCRIPTS_DIR}/tmp/ps1.list"
PS2_LIST="${SCRIPTS_DIR}/tmp/ps2.list"
ALL_GAMES="${SCRIPTS_DIR}/tmp/master.list"

path_arg="$1"

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

clean_up() {
    # Remove unwanted directories inside $ICONS_DIR except 'art' and 'ico'
    for item in "$ICONS_DIR"/*; do
        if [ -d "$item" ] && [[ $(basename "$item") != art && $(basename "$item") != ico ]]; then
            sudo rm -rf "$item"
        fi
    done

    # Remove all directories inside ${GAMES_PATH}/APPS
    find "${GAMES_PATH}/APPS" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
        sudo rm -rf -- "$dir"
    done

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1

    # Remove listed files
    sudo rm -rf "${ARTWORK_DIR}/tmp" "${ICONS_DIR}/ico/tmp" "${SCRIPTS_DIR}/tmp" 2>>"$LOG_FILE" \
        || { echo "Error: Cleanup failed. See ${LOG_FILE} for details."; exit 1; }
}

exit_script() {
    prevent_sleep_stop
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

trap 'echo; exit 130' INT
trap exit_script EXIT

error_msg() {
    type=$1
    error_1="$2"
    error_2="$3"
    error_3="$4"
    error_4="$5"

    echo
    if [ "$type" = "Error" ]; then
        echo "[X] $type: $error_1" | tee -a "${LOG_FILE}"
    else
        echo "[!] $type: $error_1" | tee -a "${LOG_FILE}"
    fi
    echo
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    if [ "$type" = "Error" ]; then
        sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        echo
        exit 1;
    else
        read -n 1 -s -r -p "Press any key to continue..." </dev/tty
        echo
    fi
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        error_msg "Error" "Failed to unmount $DEVICE."
    fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition..." >> "${LOG_FILE}" 2>&1
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${OPL}."

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Error" "Failed to mount OPL partition."
    fi

    # Create necessary folders if they don't exist
    for folder in APPS ART CFG CHT LNG THM VMC CD DVD bbnl; do
        dir="${OPL}/${folder}"
        [[ -d "$dir" ]] || mkdir -p "$dir" || { 
            error_msg "Error" "Failed to create $dir."
        }
    done
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "Error" "Failed to extract list of partitions." " " "APA partition could be broken on ${DEVICE}"
    fi
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "Error" "PFS Shell returned an error. See ${LOG_FILE}"
fi
}

process_psu_files() {
    local target_dir="$1"

    if find "$target_dir" -maxdepth 1 -type f \( -iname "*.psu" \) | grep -q .; then
        echo "Processing PSU files in: $target_dir" | tee -a "${LOG_FILE}"
        
        for file in "$target_dir"/*.psu "$target_dir"/*.PSU; do
            [ -e "$file" ] || continue  # Skip if no PSU files exist

            echo "Extracting $file..."
            "${HELPER_DIR}/PSU Extractor.elf" "$file" >> "${LOG_FILE}" 2>&1
        done
    fi
}

POPS_SIZE_CKECK() {

    # Get total size of VCD files only on PC
    LOCAL_SIZE=0
    while IFS= read -r file; do
        if [[ -f "$POPS_FOLDER/$file" ]]; then
            size=$(du --block-size=1M "$POPS_FOLDER/$file" | cut -f1)
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                error_msg "Error" "Failed to calclate the size of local .VCD files. See ${LOG_FILE}"
            fi
            LOCAL_SIZE=$((LOCAL_SIZE + size))
        fi
    done <<< "$files_only_in_local"

    # Get total size of VCD files on PS2 drive
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __.POPS\n"
    COMMANDS+="ls -l\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    ps1_size=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)
    if echo "$ps1_size" | grep -q "Exit code is"; then
        echo "$ps1_size" >> "${LOG_FILE}"
        error_msg "Error" "PFS Shell returned an error. See ${LOG_FILE}"
    fi
    
    ps1_size=$(echo "$ps1_size" | grep -iE "\.vcd$" | sort)

    # Sum the total size in bytes
    REMOTE_SIZE=$(echo "$ps1_size" | awk '{sum += $2} END {print sum}')

    # Round up to MB and MiB
    remote_mb=$(awk -v size="$REMOTE_SIZE" 'BEGIN {printf "%d", (size + 1000000 - 1) / 1000000}')

    POPS_SIZE=$((remote_mb + LOCAL_SIZE))

    echo | tee -a "${LOG_FILE}"
    echo "Total size of PS1 games: $POPS_SIZE MB" | tee -a "${LOG_FILE}"

    # Get the POPS partition size in MB

    HDL_TOC
    POPS_PARTITION=$(grep '__\.POPS' "$hdl_output" | awk '{print $4}' | grep -oE '[0-9]+')

    echo "Available space: ${POPS_PARTITION} MB"| tee -a "${LOG_FILE}"

    # Check if POPS_SIZE is greater than POPS_PARTITION - 128
    THRESHOLD=$((POPS_PARTITION - 128))

    if [ "$POPS_SIZE" -gt "$THRESHOLD" ]; then
        error_msg "Error" "Total size of PS1 games is ${POPS_SIZE} MB, exceeds available space of ${THRESHOLD} MB." " " "Remove some VCD files from the local POPS folder and try again."
    fi
}

POPS_SYNC() {
    echo | tee -a "${LOG_FILE}"
    echo "Preparing to $INSTALL_TYPE PS1 games..." | tee -a "${LOG_FILE}"

    rm -f "$POPS_FOLDER"/*.[eE][lL][fF] 2>> "${LOG_FILE}"

    # Generate the local file list directly in a variable
    local_files=$( { ls -1 "$POPS_FOLDER" | grep -Ei '\.VCD$' | sort; } 2>> "${LOG_FILE}" )
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        error_msg "Error" "Failed to create list of local .VCD files. See ${LOG_FILE}"
    fi

    # Build the commands for PFS Shell
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __.POPS\n"
    COMMANDS+="ls\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Get the PS1 file list directly from PFS Shell output, filtered and sorted
    ps1_files=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)
    if echo "$ps1_files" | grep -q "Exit code is"; then
        echo "$ps1_files" >> "${LOG_FILE}"
        error_msg "Error" "PFS Shell returned an error. See ${LOG_FILE}"
    fi
    
    ps1_files=$(echo "$ps1_files" | grep -iE "\.vcd$" | sort)
    

    if [ "$INSTALL_TYPE" = "copy" ] && [ -f "${OPL}/ps1.list" ]; then

        # Create an array of POPS files for easy comparison
        mapfile -t pops_array < <(echo "$ps1_files")

        # Initialize a temporary file
        temp_list="${SCRIPTS_DIR}/tmp/ps1.list.tmp"

        # Track whether any POPS file is missing from ps1.list
        missing_from_list=false

        while IFS= read -r line; do
            vcd_file=$(echo "$line" | awk -F '|' '{print $5}')
            if printf '%s\n' "${pops_array[@]}" | grep -Fxq "$vcd_file"; then
                echo "$line" >> "$temp_list"
            fi
        done < "${OPL}/ps1.list"

        # Check if any file in __.POPS is missing from ps1.list
        for pops_file in "${pops_array[@]}"; do
            if ! grep -Fq "|$pops_file" "${OPL}/ps1.list"; then
                missing_from_list=true
                break
            fi
        done

        if $missing_from_list; then
            echo "A file in __.POPS is missing from ps1.list — deleting ps1.list"
            rm -f "${OPL}/ps1.list"
        else
            [ -f "$temp_list" ] && ! cp "$temp_list" "${OPL}/ps1.list" 2>>"${LOG_FILE}" && error_msg "Error" "Failed to copy $temp_list to ${OPL}/ps1.list"
        fi
    fi

    # Compute differences and store them in variables
    files_only_in_local=$(comm -23 <(echo "$local_files") <(echo "$ps1_files"))

    if [ "$INSTALL_TYPE" = "sync" ] || [ ! -f "${OPL}/ps1.list" ]; then
        files_only_in_ps2=$(comm -13 <(echo "$local_files") <(echo "$ps1_files"))
        if [ "$INSTALL_TYPE" != "sync" ] && [ -n "$files_only_in_ps2" ]; then
            error_msg "Warning" "Could not find ps1.list. PS1 games will be synced instead."
        fi
    fi

    cd "$POPS_FOLDER" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to POPS folder."

    # Delete PS1 VCDs
    if [ -n "$files_only_in_ps2" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Deleteing PS1 games:" | tee -a "${LOG_FILE}"
        echo "$files_only_in_ps2" | tee -a "${LOG_FILE}"

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mount __.POPS\n"
        # Add delete commands for files_only_in_ps2
        if [ -n "$files_only_in_ps2" ]; then
            while IFS= read -r file; do
                COMMANDS+="rm \"$file\"\n"
            done <<< "$files_only_in_ps2"
        fi

        COMMANDS+="umount\n"
        COMMANDS+="exit"

        # Execute the combined commands with PFS Shell
        PFS_COMMANDS
    else
        if [ "$INSTALL_TYPE" = "sync" ]; then
            echo | tee -a "${LOG_FILE}"
            echo "No PS1 games to delete." | tee -a "${LOG_FILE}"
        fi
    fi

    # Copy PS1 VCDs
    if [ -z "$files_only_in_local" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "No PS1 games to copy." | tee -a "${LOG_FILE}"
    else
        POPS_SIZE_CKECK
        echo | tee -a "${LOG_FILE}"
        echo "Copying PS1 games:" | tee -a "${LOG_FILE}"
        echo "$files_only_in_local" | tee -a "${LOG_FILE}"

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mount __.POPS\n"
        # Add put commands for files_only_in_local
        if [ -n "$files_only_in_local" ]; then
            while IFS= read -r file; do
                COMMANDS+="put \"$file\"\n"
            done <<< "$files_only_in_local"
        fi

        COMMANDS+="umount\n"
        COMMANDS+="exit"

        # Execute the combined commands with PFS Shell
        echo | tee -a "${LOG_FILE}"
        echo -n "Copying..."
        PFS_COMMANDS
        echo | tee -a "${LOG_FILE}"
        echo "[✓] PS1 games copied successfully." | tee -a "${LOG_FILE}"
    fi
    cd "${TOOLKIT_PATH}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to $TOOLKIT_PATH."
}

VMC_TITLE() {
    local title="$1"

    # Remove colons
    title="${title//:/}"

    local disc_number=""
    if [[ "$title" =~ \(Disc\ [0-9]+\) ]]; then
        disc_number="${BASH_REMATCH[0]}"
        title="${title//$disc_number/}"
        title="${title%" "}"  # Trim trailing space

        # Truncate to 24 chars if disc number present
        if (( ${#title} > 24 )); then
            title="${title:0:24}"
        fi
    else
        # No disc number: truncate to 32 chars max
        if (( ${#title} > 32 )); then
            title="${title:0:32}"
        fi
    fi

    # Split into words for top row
    IFS=' ' read -r -a words <<< "$title"

    # Build top line: add full words without exceeding 16 chars
    local top=""
    local top_len=0
    for word in "${words[@]}"; do
        local add_len=$(( ${#word} + (top_len > 0 ? 1 : 0) ))
        if (( top_len + add_len <= 16 )); then
            top+="${top:+ }$word"
            ((top_len += add_len))
        else
            break
        fi
    done

    # Bottom line is remainder of title after top line
    local bottom="${title:$top_len}"
    bottom="${bottom#" "}"  # Remove leading space

    # If bottom is 1 char and top has more than one word, consider shifting last word
    if (( ${#bottom} == 1 )); then
        IFS=' ' read -r -a top_words <<< "$top"
        if (( ${#top_words[@]} > 1 )); then
            local last_word="${top_words[-1]}"
            local new_top="${top% ${last_word}}"
            local proposed_bottom="${last_word} $bottom"
            if (( ${#proposed_bottom} <= 16 )); then
                top="$new_top"
                bottom="$proposed_bottom"
            fi
        fi
    fi

    if [[ -n "$disc_number" ]]; then
        if (( ${#bottom} > 4 )); then
            truncated_bottom="${bottom:0:4}"
            truncated_bottom="${truncated_bottom%" "}"  # Remove trailing space before ...
            bottom="${truncated_bottom}... ${disc_number}"
        else
            bottom="${bottom:+$bottom }${disc_number}"
        fi
    else
        if (( ${#bottom} > 16 )); then
            bottom="${bottom:0:13}"
            bottom="${bottom%" "}"  # Remove trailing space
            bottom="${bottom}..."
        fi
    fi

    python3 "${HELPER_DIR}/txt_to_icon_sys.py" "${ASSETS_DIR}/POPStarter/icon.sys" "$top" "$bottom"
}

GROUP_VMC() {
    if [ "$VMC_GROUP_FOLDER" = "GP_Konami JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Konami PAL" ] || [ "$VMC_GROUP_FOLDER" = "GP_Konami USA" ]; then
        cp "${VMC_ICON_DIR}/KONAMI.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tomba! USA" ]; then
        cp "${VMC_ICON_DIR}/TOMBA.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tombi! PAL" ]; then
        cp "${VMC_ICON_DIR}/TOMBI.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tomba! JAP" ]; then
        cp "${VMC_ICON_DIR}/TOMBA-JPN.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Square JAP" ] || [ "$VMC_GROUP_FOLDER" = "GP_Square USA" ]; then
        cp "${VMC_ICON_DIR}/SQUARE.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Arc the Lad USA" ] || [ "$VMC_GROUP_FOLDER" = "GP_Arc the Lad JPN" ]; then
        cp "${VMC_ICON_DIR}/ARK-THE-LAD.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Armored Core JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Armored Core USA" ]; then
        cp "${VMC_ICON_DIR}/ARMORED-CORE.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo PAL" ] || [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo USA" ]; then
        cp "${VMC_ICON_DIR}/GRAN-TURISMO.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tekken JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Tekken PAL" ] || [ "$VMC_GROUP_FOLDER" = "GP_Tekken USA" ]; then
        cp "${VMC_ICON_DIR}/TEKKEN.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Monster Rancher" ]; then
        cp "${VMC_ICON_DIR}/MONSTER-RANCHER.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Monster Farm JPN" ]; then
        cp "${VMC_ICON_DIR}/MONSTER-FARM.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_PopoloCrois JPN" ]; then
        cp "${VMC_ICON_DIR}/POPOLOCROIS.ico" ./list.ico
    fi
}

CREATE_VMC() {

    declare -A disc_groups
    declare -A first_disc_folder
    declare -A vmc_groups_by_id
    current_group=""

    echo | tee -a "${LOG_FILE}"
    echo -n "Creating VMCs for PS1 games..." | tee -a "${LOG_FILE}"
    if ! mkdir -p "${POPS_DIR}"; then
        error_msg "Error" "Failed to create VMC folder."
    fi

    # First pass: Group file names by base title
    exec 3< "$PS1_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"  # Remove trailing space
        disc_groups["$base_title"]+="$title|$file_name"$'\n'
    done
    exec 3<&-

    exec 3< "${HELPER_DIR}/vmc_groups.list"
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

    # Second pass: Create folders, DISCS.TXT, and VMCDIR.TXT
    exec 3< "$PS1_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
        folder_name="${file_name%.*}"
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"
        mkdir -p "${POPS_DIR}/$folder_name"
        cd "${POPS_DIR}/$folder_name"
        if ! cp "${ICONS_DIR}/ico/vmc/$game_id.ico" ./list.ico 2>/dev/null; then
            cp "${ICONS_DIR}/ico/vmc/VMC.ico" ./list.ico
            echo "$game_id $title" >> "${MISSING_VMC}"
        fi
        
        VMC_TITLE "$title"

        # Prepare disc list for DISCS.TXT
        IFS=$'\n' read -rd '' -a entries <<< "${disc_groups[$base_title]}"
        if ((${#entries[@]} > 1)); then
            # Determine first disc folder
            first_entry="${entries[0]}"
            first_file_name="${first_entry##*|}"
            first_folder="${first_file_name%.*}"

            # Prepare up to 4 lines for DISCS.TXT
            disc_list=()
            for ((i = 0; i < ${#entries[@]} && i < 4; i++)); do
                disc_list+=("${entries[i]##*|}")
            done

            # Write DISCS.TXT in the first 4 folders only
            for ((i = 0; i < ${#disc_list[@]}; i++)); do
                disc_file_name="${entries[i]##*|}"
                disc_folder="${disc_file_name%.*}"
                mkdir -p "${POPS_DIR}/$disc_folder"
                printf "%s\n" "${disc_list[@]}" > "${POPS_DIR}/$disc_folder/DISCS.TXT"
            done

            # Write VMCDIR.TXT in all folders
            for disc_entry in "${entries[@]}"; do
                disc_file_name="${disc_entry##*|}"
                disc_folder="${disc_file_name%.*}"
                mkdir -p "${POPS_DIR}/$disc_folder"
                printf "%s" "$first_folder" > "${POPS_DIR}/$disc_folder/VMCDIR.TXT"
            done

            # Overwrite VMCDIR.TXT in all discs with the group ID if it exists and create group VMC
            if [[ -n "${vmc_groups_by_id[$game_id]}" ]]; then
                VMC_GROUP_FOLDER="${vmc_groups_by_id[$game_id]}"
                mkdir -p "${POPS_DIR}/$VMC_GROUP_FOLDER"
                cd "${POPS_DIR}/$VMC_GROUP_FOLDER"
                GROUP_VMC
                GP_TITLE="${vmc_groups_by_id[$game_id]#GP_}"
                python3 "${HELPER_DIR}/txt_to_icon_sys.py" "${ASSETS_DIR}/POPStarter/icon.sys" "$GP_TITLE" "VMC Group"
                for disc_entry in "${entries[@]}"; do
                    disc_file_name="${disc_entry##*|}"
                    disc_folder="${disc_file_name%.*}"
                    mkdir -p "${POPS_DIR}/$disc_folder"
                    printf "%s" "${vmc_groups_by_id[$game_id]}" > "${POPS_DIR}/$disc_folder/VMCDIR.TXT"
                done
            fi
        else
            # Check if game ID exists in VMC group mapping and make group VMC if necessary
            if [[ -n "${vmc_groups_by_id[$game_id]}" ]]; then
                VMC_GROUP_FOLDER="${vmc_groups_by_id[$game_id]}"
                mkdir -p "${POPS_DIR}/$VMC_GROUP_FOLDER"
                cd "${POPS_DIR}/$VMC_GROUP_FOLDER"
                GROUP_VMC
                GP_TITLE="${vmc_groups_by_id[$game_id]#GP_}"
                python3 "${HELPER_DIR}/txt_to_icon_sys.py" "${ASSETS_DIR}/POPStarter/icon.sys" "$GP_TITLE" "VMC Group"
                printf "%s" "${vmc_groups_by_id[$game_id]}" > "${POPS_DIR}/$folder_name/VMCDIR.TXT"
            fi
        fi
    done
    cd "${TOOLKIT_PATH}"
    exec 3<&-

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __common\n"

    for dir in "$POPS_DIR"/*/; do
        [ -d "$dir" ] || continue
        VMC_FOLDER="$(basename "$dir")"
        COMMANDS+="cd /\n"
        COMMANDS+="cd POPS\n"
        COMMANDS+="mkdir '${VMC_FOLDER}'\n"
        COMMANDS+="cd '${VMC_FOLDER}'\n"
        COMMANDS+="lcd '${POPS_DIR}/${VMC_FOLDER}'\n"
        COMMANDS+="rm icon.sys\n"
        COMMANDS+="put icon.sys\n"
        COMMANDS+="rm list.ico\n"
        COMMANDS+="put list.ico\n"
        COMMANDS+="rm DISCS.TXT\n"
        COMMANDS+="put DISCS.TXT\n"
        COMMANDS+="rm VMCDIR.TXT\n"
        COMMANDS+="put VMCDIR.TXT\n"
    done
    COMMANDS+="cd /\n"
    COMMANDS+="cd POPS\n"
    COMMANDS+="rm icon.sys\n"
    COMMANDS+="rm list.ico\n"
    COMMANDS+="rm DISCS.TXT\n"
    COMMANDS+="rm VMCDIR.TXT\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
    echo | tee -a "${LOG_FILE}"
}

OPL_SIZE_CKECK() {

    if [ "$INSTALL_TYPE" = "sync" ]; then
        opl_size=$(df -m --output=size "${OPL}" | tail -n 1 | awk '{$1=$1};1')
        available_mb=$((opl_size - 128))
        needed_mb=$(ls -l "${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" | awk '{s+=$5} END {print int((s + 1048575) / 1048576)}')

    elif [ "$INSTALL_TYPE" = "copy" ]; then
        opl_freespace=$(df -m "${OPL}/" | awk 'NR==2 {print $4}')
        available_mb=$((opl_freespace - 128))
        cd_size=$(rsync -rL --ignore-existing --exclude=".*" --dry-run --out-format="%l" "${GAMES_PATH}/CD/" "${OPL}/CD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        dvd_size=$(rsync -rL --ignore-existing --exclude=".*" --dry-run --out-format="%l" "${GAMES_PATH}/DVD/" "${OPL}/DVD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        needed_mb=$((cd_size + dvd_size))
    fi 

    if (( available_mb < needed_mb )); then
        error_msg "Error" "Total size of PS2 games are ${needed_mb} MB, exceeds available space of ${available_mb} MB." " " "Remove some ISO/ZSO files from the local CD/DVD folders and try again."
    fi
}

# Function to find available space
APA_SIZE_CHECK() {
    HDL_TOC

    # Extract the "used" value, remove "MB" and any commas
    used=$(cat "$hdl_output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
    capacity=129960

    # Calculate available space (capacity - used)
    available=$((capacity - used))
    pp_max=$(((available / 8) - 1))
}

app_success_check() {
    local name="$1"
    if [ $exit_code -ne 0 ]; then
        error_msg "Error" "Failed to update $name. See "${LOG_FILE}" for details."
    else
        echo | tee -a "${LOG_FILE}"
        echo "[✓] Successfully updated $name." | tee -a "${LOG_FILE}"
    fi
}

ps2_rsync_check() {
    local type="$1"

    # Check if PS2 sync/update failed
    if [ $cd_status -ne 0 ] || [ $dvd_status -ne 0 ]; then
        error_msg "Error" "Failed to $INSTALL_TYPE PS2 games. See ${LOG_FILE} for details."
    else
        echo | tee -a "${LOG_FILE}"
        echo "[✓] PS2 games successfully $type." | tee -a "${LOG_FILE}"
    fi
}

update_apps() {
    local name="$1"
    local source="$2"
    local destination="$3"
    local options="$4"

    echo | tee -a "${LOG_FILE}"
    echo "Checking for $name updates..." | tee -a "${LOG_FILE}"

    local needs_update=false

    if [[ "$name" == "NHDDL" || "$name" == "OPL" || "$name" == "POPStarter" ]]; then
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
            echo "Current version is $current_ver" | tee -a "${LOG_FILE}"
        fi

        # Compare versions
        if [[ "$(echo -e "$current_ver\n$latest_ver" | sort -V | tail -n 1)" != "$current_ver" ]]; then
            needs_update=true
        fi
    else
        local output
        output=$(rsync $options --dry-run "$source" "$destination")
        if [ $(echo "$output" | wc -l) -ne 1 ]; then
            needs_update=true
        fi
    fi

    if [ "$needs_update" = true ]; then
        echo "Updating $name..." | tee -a "${LOG_FILE}"
        rsync $options "$source" "$destination" >>"${LOG_FILE}" 2>&1
        exit_code=${PIPESTATUS[0]}
        app_success_check "$name"
    else
        echo "$name is already up-to-date." | tee -a "${LOG_FILE}"
    fi
}

install_pops() {
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __common\n"
    COMMANDS+="ls\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    pops_folder=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __common\n"
    COMMANDS+="cd POPS\n"
    COMMANDS+="ls\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    pops_files=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)


    if echo "$pops_folder" | grep -q "POPS/"; then
        mkfolder="NO"
    else
        mkfolder="YES"
    fi

    if echo "$pops_folder" | grep -q "POPS/" && echo "$pops_files" | grep -q "POPS\.ELF" && echo "$pops_files" | grep -q "IOPRP252\.IMG"; then
        echo "POPS-binaries are already installed."| tee -a "${LOG_FILE}"
    else
        echo "Checking for POPS binaries..." | tee -a "${LOG_FILE}"
    
    # Check POPS files exist
        if [[ -f "${ASSETS_DIR}/POPS-binaries-main/POPS.ELF" && -f "${ASSETS_DIR}/POPS-binaries-main/IOPRP252.IMG" ]]; then
            echo | tee -a "${LOG_FILE}"
            echo "Both POPS.ELF and IOPRP252.IMG exist in ${ASSETS_DIR}." | tee -a "${LOG_FILE}"
            echo "Skipping download." | tee -a "${LOG_FILE}"
        else
            echo "One or both files are missing in ${ASSETS_DIR}." | tee -a "${LOG_FILE}"
            # Check if POPS-binaries-main.zip exists
            if [[ -f "${ASSETS_DIR}/POPS-binaries-main.zip" && ! -f "${ASSETS_DIR}/POPS-binaries-main.zip.st" ]]; then
                echo "POPS-binaries-main.zip found in ${ASSETS_DIR}. Extracting..." | tee -a "${LOG_FILE}"
                if ! unzip -o "${ASSETS_DIR}/POPS-binaries-main.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1; then
                    error_msg "Warning" "Failed to extract POPS binaries"
                fi
            else
                echo "Downloading POPS binaries..." | tee -a "${LOG_FILE}"
                if ! axel -a https://archive.org/download/pops-binaries-PS2/POPS-binaries-main.zip -o "${ASSETS_DIR}"; then
                    error_msg "Warning" "Failed to download POPS binaries."
                fi
                if ! unzip -o "${ASSETS_DIR}/POPS-binaries-main.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1; then
                    error_msg "Warning" "Failed to extract POPS binaries"
                fi
            fi
            # Check if both POPS.ELF and IOPRP252.IMG exist after extraction
            if [[ -f "${ASSETS_DIR}/POPS-binaries-main/POPS.ELF" && -f "${ASSETS_DIR}/POPS-binaries-main/IOPRP252.IMG" ]]; then
                echo "[✓] POPS binaries successfully extracted." | tee -a "${LOG_FILE}"
            else
                error_msg "Warning" "One or both files (POPS.ELF, IOPRP252.IMG) are missing after extraction." "Without these files PS1 games will not be playable."
            fi
        fi

        echo "Installing POPS binaries..." | tee -a "${LOG_FILE}"

        # Copy POPS files to __common
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mount __common\n"
        if [[ "$mkfolder" == "YES" ]]; then
            COMMANDS+="mkdir POPS\n"
        fi
        COMMANDS+="cd POPS\n"
        COMMANDS+="lcd '${ASSETS_DIR}/POPS-binaries-main'\n"
        COMMANDS+="put POPS.ELF\n"
        COMMANDS+="put IOPRP252.IMG\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        PFS_COMMANDS

        echo "[✓] POPS-binaries successfully installed." | tee -a "${LOG_FILE}"

    fi
}

install_elf() {

    local dir=$1

    # Check if any ELF files exist in the source directory
    if ! find "${dir}/APPS" -maxdepth 1 -type f \( -iname "*.elf" \) | grep -q .; then
        echo | tee -a "${LOG_FILE}"
        echo "No ELF files to install in: ${dir}/APPS" | tee -a "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Processing ELF files in: ${dir}/APPS/"
        for file in "${dir}/APPS/"*.elf "${dir}/APPS/"*.ELF; do
            [ -e "$file" ] || continue  # Skip if no ELF files exist
            # Extract filename without path and extension
            elf=$(basename "$file")
            elf_no_ext="${elf%.*}"
            echo "Installing ${dir}/APPS/$elf..." | tee -a "${LOG_FILE}"

            app_name="${elf_no_ext%%(*}" # Remove anything after an open bracket '('
            app_name="${app_name%%[Vv][0-9]*}" # Remove versioning (e.g., v12 or V12)
            app_name=$(echo "$app_name" | sed -E 's/[cC][oO][mM][pP][rR][eE][sS][sS][eE][dD].*//') # Remove "compressed"
            app_name=$(echo "$app_name" | sed -E 's/[pP][aA][cC][kK][eE][dD].*//') # Remove "packed"
            app_name=$(echo "$app_name" | sed 's/\.*$//') # Trim trailing full stops

            AppDB_check=$(echo "$app_name" | sed 's/[ _-]//g' | tr 'a-z' 'A-Z')

            # Check $HELPER_DIR/AppDB.csv for match in first column to $AppDB_check, set $title based on second column from file if found. If no match found, set $title with the remaining code
            match=$(awk -F'|' -v key="$AppDB_check" '$1 && index(key, $1) == 1 {print $2; exit}' "$HELPER_DIR/AppDB.csv")

            if [[ -n "$match" ]]; then
                title="$match"
            else
                # Use the processed name if no match is found
                app_name="${app_name//[_-]/ }"  # Replace underscores and hyphens with spaces
                app_name="${app_name%"${app_name##*[![:space:]]}"}" # Trim trailing spaces again
                app_name=$(echo "$app_name" | sed 's/\.*$//') # Trim trailing full stops again
                app_name_before=$(echo "$app_name") # Save the string
                app_name=$(echo "$app_name" | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g') # Add a space before capital letters when preceded by a lowercase letter

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

                result=""
                # Define words to exclude from uppercase conversion (only consonant-only words)
                exclude_list="by cry cyst crypt dry fly fry glyph gym gypsy hymn lynx my myth myrrh ply pry rhythm shy sky spy sly sty sync tryst why wry"

                # Now process each word
                for word in $input_str; do
                    # Handle words 3 characters or shorter, but only if no space was added by sed
                    if [[ ${#word} -le 3 ]] && ! $space_added && ! echo "$exclude_list" | grep -wi -q "$word"; then
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
            fi

            title_id=$(echo "$title" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | cut -c1-11)  # Replace spaces with underscores & capitalize

            # Create the new folder in the destination directory
            elf_dir="${dir}/APPS/$title_id"
            mkdir -p "${elf_dir}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create directory $elf_dir."

            if [[ $dir == $GAMES_PATH ]]; then
                cp "${dir}/APPS/$elf" "${elf_dir}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to copy $elf to $elf_dir."
            elif [[ $dir == $OPL ]]; then
                mv "${dir}/APPS/$elf" "${elf_dir}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to move $elf to $elf_dir."
            fi

            if [[ "$title_id" == "LAUNCHDISC" ]]; then
                publisher="github.com/cosmicscale"
            elif [[ "$title_id" == "HDDOSD" ]]; then
                publisher="Sony Computer Entertainment"
            elif [[ "$title_id" == "BBNAVIGATOR" ]]; then
                publisher="Sony Computer Entertainment"
            elif [[ "$title_id" == "LAUNCHELF" ]]; then
                publisher="israpps.github.io"
                title="wLaunchELF 4.43x_isr-EXFAT-MMCE"
            else
                publisher=""
            fi

            cat > "${elf_dir}/title.cfg" <<EOL
title=$title
boot=$elf
Title=$title
CfgVersion=8
Developer=$publisher
Genre=Homebrew
EOL
        done
    fi
}

activate_python() {
    echo
    msg="Preparing to $INSTALL_TYPE PS2 games"
    spin='|/-\'
    printf "\r[%c] %s" "${spin:0:1}" "$msg"
    SECONDS=0
    while [ $SECONDS -lt 5 ]; do
        for i in {0..3}; do
            printf "\r[%c] %s" "${spin:i:1}" "$msg"
            sleep 0.1
        done
    done
    printf "\r[✓] %s\n" "$msg"

    if [ -n "$IN_NIX_SHELL" ]; then
        echo "Running in Nix environment - packages should be provided by flake." | tee -a "${LOG_FILE}"
        return
    fi

    echo | tee -a "${LOG_FILE}"
    echo "Activating Python virtual environment..." >> "${LOG_FILE}"
    # Try activating the virtual environment twice before failing
    if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
        echo -n "Failed to activate the Python virtual environment. Retrying..." | tee -a "${LOG_FILE}"
        sleep 2
        echo | tee -a "${LOG_FILE}"
    
        if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
            error_msg "Error" "Failed to activate the Python virtual environment."
        fi
    fi
}

convert_zso() {
    if [[ "$LAUNCHER" != "NEUTRINO" ]]; then
        return
    fi

    if [[ "$INSTALL_TYPE" == "sync" ]]; then
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD")
    else
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" "${OPL}/CD" "${OPL}/DVD")
    fi

    # Only run if .zso files exist
    if find "${search_dirs[@]}" -type f -iname "*.zso" | grep -q .; then
        error_msg "Warning" "Games in the compressed ZSO format have been found." "Neutrino does not support compressed ZSO files." " " "ZSO files will be converted to ISO files before proceeding."

        # Convert ZSO to ISO
        while IFS= read -r -d '' zso_file; do
            iso_file="${zso_file%.*}.iso"
            echo "Converting: $zso_file -> $iso_file" | tee -a "${LOG_FILE}"

            python3 -u "${HELPER_DIR}/ziso.py" -c 0 "$zso_file" "$iso_file" | tee -a "${LOG_FILE}"
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                rm -f "$iso_file"
                error_msg "Error" "Failed to uncompress $zso_file"
            fi

            rm -f "$zso_file"
        done < <(find "${search_dirs[@]}" -type f -iname "*.zso" -print0)
    fi
}

PP_NAME() {
# Format game id correctly for partition
    title_id=$(echo "$game_id" | sed -E 's/_(...)\./-\1/;s/\.//')

    # Sanitize title by keeping only uppercase A-Z, 0-9, and underscores, and removing any trailing underscores
    sanitized_title=$(echo "$title" | sed 's/²/2/g; s/³/3/g' | iconv -f UTF-8 -t ASCII//TRANSLIT | tr 'a-z' 'A-Z' | sed 's/[^A-Z0-9]/_/g' | sed 's/^_//; s/_$//; s/__*/_/g')
    PARTITION_LABEL=$(printf "PP.%s.%s" "$title_id" "$sanitized_title" | cut -c 1-32 | sed 's/_$//')
}

create_info_sys() {
    local title="$1"
    local title_id="$2"
    local publisher="$3"
    local content_type="255"

    if [ "$title_id" = "BBNAVIGATOR" ]; then
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
    if [ -f "$info_sys_filename" ]; then
        echo "Created: $info_sys_filename" | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Failed to create $info_sys_filename"
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
    if [ -f "$icon_sys_filename" ]; then
        echo "Created: $icon_sys_filename"  | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Failed to create $icon_sys_filename"
    fi
}

create_bbnl_cfg() {
    local file_name="$1"
    local title_id="$2"
    local arg="$3"

    {
        echo "file_name=$file_name"
        echo "title_id=$title_id"
        echo "launcher=ELF"
        if [ -n "$arg" ]; then
            echo "arg=$arg"
        fi
    } > "$bbnl_cfg"

    if [ -f "$bbnl_cfg" ]; then
        echo "Created: $bbnl_cfg"  | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Failed to create $bbnl_cfg"
    fi
}

APP_ART() {
    png_file="${ARTWORK_DIR}/${title_id}.png"
    # Copy the matching PNG file from ART_DIR, or default to APP.png
    if [ -f "$png_file" ]; then
        cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
        echo "Created: $dir/jkt_001.png"  | tee -a "${LOG_FILE}"
        cp "$png_file" "${GAMES_PATH}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create ${GAMES_PATH}/ART/${elf}_COV.png. See ${LOG_FILE} for details."
        echo "Created: ${GAMES_PATH}/ART/${elf}_COV.png"  | tee -a "${LOG_FILE}"
    else
        echo "Artwork not found locally for $title_id. Attempting to download from the PSBBN art database..." | tee -a "${LOG_FILE}"
        wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
        "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/apps/${title_id}.png"
        
        if [[ -s "$png_file" ]]; then
            echo "[✓] Successfully downloaded artwork for $title_id" | tee -a "${LOG_FILE}"
            cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
            echo "Created: $dir/jkt_001.png"  | tee -a "${LOG_FILE}"
            cp "$png_file" "${GAMES_PATH}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create ${GAMES_PATH}/ART/${elf}_COV.png. See ${LOG_FILE} for details."
            echo "Created: ${GAMES_PATH}/ART/${elf}_COV.png"  | tee -a "${LOG_FILE}"
        else
            rm -f "$png_file"
            cp "$ARTWORK_DIR/APP.png" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
            echo "Created: $dir/jkt_001.png using default image."  | tee -a "${LOG_FILE}"
            echo "$title_id,$title,$elf" >> "${MISSING_APP_ART}"
        fi
    fi
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

mkdir -p "${LOGS_DIR}" >/dev/null 2>&1

if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
    sudo rm -f "${LOG_FILE}"
    if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
        error_msg "Error" "Cannot create log file."
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

clear
clean_up

sudo rm -f "${MISSING_ART}" "${MISSING_APP_ART}" "${MISSING_ICON}" "${MISSING_VMC}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to remove missing artwork files. See ${LOG_FILE} for details."

mkdir -p "${SCRIPTS_DIR}/tmp" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create tmp folder. See ${LOG_FILE} for details."

DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

if [[ -z "$DEVICE" ]]; then
    clear
    error_msg "Error" "Unable to detect the PS2 drive. Please ensure the drive is properly connected." "If this is your first time using the installer, select 'Install PSBBN' from the main menu."
fi

echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

SPLASH

# Find all mounted volumes associated with the device
mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

# Iterate through each mounted volume and unmount it
echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
for mount_point in $mounted_volumes; do
    echo "Unmounting $mount_point..." >> "${LOG_FILE}"
    if sudo umount "$mount_point"; then
        echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
    else
        error_msg "Error" "Failed to unmount $mount_point. Please unmount manually."

    fi
done

HDL_TOC

MOUNT_OPL

psbbn_version=$(head -n 1 "${OPL}/version.txt" 2>/dev/null)

# Compare using sort -V
if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
    echo "Warning: Your PSBBN Definitive Patch version ($psbbn_version) is older than the recommended version ($version_check)."
    echo "It is strongly recommended to update by selecting 'Install PSBBN' from the main menu."
    echo "Proceed with caution."
    echo
    while true; do
        read -rp "Do you want to continue anyway? [Y]es / [N]o: " response
        case "$response" in
            [Yy]* )
                rm -f "${OPL}/conf_apps.cfg" || error_msg "Error" "Failed to delete ${OPL}/conf_apps.cfg."
                break
                ;;
            [Nn]* )
                exit 0
                ;;
            * )
                echo "Please answer Y (yes) or N (no)."
                ;;
        esac
    done
fi

# Check if the Python virtual environment exists
if [ -f "./scripts/venv/bin/activate" ]; then
    echo "The Python virtual environment exists." >> "${LOG_FILE}"
elif [ -n "$IN_NIX_SHELL" ]; then
    echo "Running in Nix environment - The Python dependencies are managed by the flake." >> "${LOG_FILE}"
else
    error_msg "Error" "The Python virtual environment does not exist. Run 01-Setup.sh and try again."
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

if [[ -z "$path_arg" ]]; then
    get_display_path
    echo
    echo "Games folder: $display_path" | tee -a "${LOG_FILE}"
    echo

    while true; do
        read -p "Would you like to change the location of the local games folder? (y/n): " answer
        case "$answer" in
            [Yy])
                echo
                read -p "Enter new path for games folder: " new_path

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
                    echo "Invalid path. Please try again." | tee -a "${LOG_FILE}"
                    echo
                fi
                ;;
            [Nn])
                break
                ;;
            *)
                echo
                echo "Please enter y or n."
                ;;
        esac
    done
fi

# Create necessary folders if they don't exist
for folder in APPS ART CFG CHT LNG THM VMC POPS CD DVD; do
    dir="${GAMES_PATH}/${folder}"
    [[ -d "$dir" ]] || mkdir -p "$dir" || { 
        error_msg "Error" "Failed to create $dir. Make sure you have write permissions to $GAMES_PATH"
    }
done

# Check if GAMES_PATH is custom
if [[ "${GAMES_PATH}" != "${TOOLKIT_PATH}/games" ]]; then
    echo "Using custom game path." >> "${LOG_FILE}"
    cp "${TOOLKIT_PATH}/games/APPS/"{BOOT.ELF,Launch-Disc.elf,HDD-OSD.elf,PSBBN.ELF} "${GAMES_PATH}/APPS" >> "${LOG_FILE}" 2>&1
else
    echo "Using default game path." >> "${LOG_FILE}"
fi

POPS_FOLDER="${GAMES_PATH}/POPS"

SPLASH

echo "Choose an install option:"
echo
echo "  1) Synchronize All Games and Apps:"
echo
echo "     - Installs all games and apps currently found in the games folder on your PC."
echo "     - Deletes any games or apps from the PS2 drive that are not present in the"
echo "       games folder, ensuring the PS2 drive matches the contents of your PC."
echo
echo "     WARNING: Any games and apps that are not in the games folder on your PC will be"
echo "     permanently removed from the PS2 drive during synchronization."
echo
echo "  2) Add Additional Games and Apps:"
echo
echo "     - Installs new games and apps found in the games folder on your PC."
echo "     - Scans for newly added or removed games and apps, then updates the game list"
echo "       in the PSBBN Game Collection and HDD-OSD accordingly."
echo

while true; do
    read -p "Enter 1 or 2: " choice
    case "$choice" in
        1) INSTALL_TYPE="sync" DESC1="Synchronize"; break ;;
        2) INSTALL_TYPE="copy" DESC1="Add Games and Apps"; break ;;
        *) echo; echo "Invalid choice. Please enter 1 or 2." ;;
    esac
done

get_display_path

if [ "$INSTALL_TYPE" = "sync" ] && \
   ! find "${GAMES_PATH}/POPS" -maxdepth 1 -type f -iname "*.vcd" -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/CD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit | grep -q .; then
    echo
    echo "Warning: No games found in the games folder: ${display_path}"
    echo "All games on the PS2 drive will be deleted."
    echo
    while true; do
        read -p "Are you sure you wish to continue? (y/n): " confirm
        case "$confirm" in
            [Yy]) break ;;
            [Nn]) echo "Operation cancelled."; exit 1 ;;
            *) echo; echo "Please enter y or n." ;;
        esac
    done
fi

SPLASH

echo "Please choose a game launcher:"
echo
echo "  1) Open PS2 Loader (OPL)"
echo
echo "     - 100% open-source game and application loader:"
echo "       https://github.com/ps2homebrew/Open-PS2-Loader"
echo
echo "  2) Neutrino"
echo
echo "     - Small, fast, and modular PS2 device emulator:"
echo "       https://github.com/rickgaiser/neutrino"
echo

while true; do
    read -p "Enter 1 or 2: " choice
    case "$choice" in
        1) LAUNCHER="OPL"; DESC2="Open PS2 Loader (OPL)"; break ;;
        2) LAUNCHER="NEUTRINO"; DESC2="Neutrino"; break ;;
        *) echo; echo "Invalid choice. Please enter 1 or 2." ;;
    esac
done

ps1_games_found=false

# Only populate ps1_games if INSTALL_TYPE=copy
if [ "$INSTALL_TYPE" = "copy" ]; then
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __.POPS\n"
    COMMANDS+="ls -l\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    ps1_games=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)
    if echo "$ps1_games" | grep -qi '\.vcd$'; then
        ps1_games_found=true
    fi
fi

# Check conditions for sync or copy
if { [ "$INSTALL_TYPE" = "sync" ] && find "${GAMES_PATH}/POPS" -maxdepth 1 -type f -iname "*.vcd" -print -quit 2>/dev/null | grep -q .; } \
   || { [ "$INSTALL_TYPE" = "copy" ] && { find "${GAMES_PATH}/POPS" -maxdepth 1 -type f -iname "*.vcd" -print -quit 2>/dev/null | grep -q . || [ "$ps1_games_found" = true ]; }; }; then
    
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __common\n"
    COMMANDS+="cd POPS\n"
    COMMANDS+="lcd '${ASSETS_DIR}/POPStarter'\n"

    SPLASH
    echo "Would you like to enable 'HDTVFIX' for PS1 games?"
    echo
    echo "Enable this if your TV cannot display 240p and PS1 games show a blank screen."
    echo
    while true; do
        read -p "Yes or No (y/n): " HDTVFIX
        case "$HDTVFIX" in
            [Yy])
                COMMANDS+="rm CHEATS.TXT\n"
                COMMANDS+="put CHEATS.TXT\n"
                break
                ;;
            [Nn])
                COMMANDS+="rm CHEATS.TXT\n"
                break
                ;;
            *)
                echo
                echo "Please enter y or n."
                ;;
        esac
    done

    COMMANDS+="umount\n"
    COMMANDS+="exit"
    PFS_COMMANDS
fi

SPLASH

echo "PS2 Drive Detected: $DEVICE" >> "${LOG_FILE}"
echo "Linux Games Folder: $GAMES_PATH" >> "${LOG_FILE}"
echo "Games Folder: $display_path" | tee -a "${LOG_FILE}"
echo "Install Type: $DESC1" | tee -a "${LOG_FILE}"
echo "Game Launcher: $DESC2" | tee -a "${LOG_FILE}"
if [ -n "$HDTVFIX" ]; then
    case "$HDTVFIX" in
        [Yy]) HDTVFIX="Yes" ;;
        [Nn]) HDTVFIX="No" ;;
    esac
    echo "HDTV fix for PS1 Games: $HDTVFIX"
fi
echo
read -n 1 -s -r -p "Press any key to continue..."
echo

prevent_sleep_start

# Delete existing BBL partitions

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
    echo "Deleting PP partitions..." | tee -a "${LOG_FILE}"
    PFS_COMMANDS

    HDL_TOC

    delete_partition=$(grep -o 'PP\.[^ ]\+' "$hdl_output")
    
    if [ -n "$delete_partition" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Unable to delete the following partitions:"
        echo $delete_partition 
        error_msg "Error" "Failed to delete existing PP partitions."
    else
        echo "Existing PP partitions sucessfully deleted." | tee -a "${LOG_FILE}"
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No PP partitions to delete." | tee -a "${LOG_FILE}"
fi

update_apps "POPStarter" "${POPSTARTER}" "${OPL}/bbnl/POPSTARTER.ELF" "-ut --progress"
install_pops
update_apps "OPL" "${ASSETS_DIR}/OPL/OPNPS2LD.ELF" "${OPL}/bbnl/OPNPS2LD.ELF" "-ut --progress"
update_apps "NHDDL" "${ASSETS_DIR}/NHDDL/nhddl.elf" "${OPL}/bbnl/nhddl.elf" "-ut --progress"
update_apps "Neutrino" "${NEUTRINO_DIR}/" "${OPL}/neutrino/" "-rut --progress --delete --exclude='.*'"

################################### Synchronize Games & Apps ###################################

if [ "$INSTALL_TYPE" = "sync" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Preparing to sync apps..." | tee -a "${LOG_FILE}"

    cd "${GAMES_PATH}/APPS/" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${GAMES_PATH}/APPS."
    process_psu_files "${GAMES_PATH}/APPS/"

    install_elf "${GAMES_PATH}"

    rsync -rut --progress --delete --exclude='.*' "${GAMES_PATH}/APPS/" "${OPL}/APPS/" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed sync apps. See $LOG_FILE for details."

    find "${OPL}/APPS/" -maxdepth 1 -type f -exec rm -f {} + 2>>"${LOG_FILE}" || error_msg "Error" "Failed to tidy up ${OPL}/APPS/"

    POPS_SYNC
    activate_python
    convert_zso
    OPL_SIZE_CKECK

    cd=$(rsync -rL --progress --ignore-existing --delete --exclude='.*' --dry-run "${GAMES_PATH}/CD/" "${OPL}/CD/")
    dvd=$(rsync -rL --progress --ignore-existing --delete --exclude='.*' --dry-run "${GAMES_PATH}/DVD/" "${OPL}/DVD/")

    # Check if either output contains more than one line
    if [ $(echo "$cd" | wc -l) -ne 1 ] || [ $(echo "$dvd" | wc -l) -ne 1 ]; then
        needs_update=true
    fi

    if [ "$needs_update" = true ]; then
        echo "Total size of PS2 games to be synced: $needed_mb MB" | tee -a "${LOG_FILE}"
        echo "Available space: $available_mb MB" | tee -a "${LOG_FILE}"
        echo | tee -a "${LOG_FILE}"
        echo "Syncing PS2 games..." | tee -a "${LOG_FILE}"
        rsync -rL --progress --ignore-existing --delete --exclude='.*' "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        rsync -rL --progress --ignore-existing --delete --exclude='.*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check Synced
    else
        echo "PS2 games are already up-to-date." | tee -a "${LOG_FILE}"
    fi

################################### Add Games & Apps ###################################

elif [ "$INSTALL_TYPE" = "copy" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Preparing to copy apps..." | tee -a "${LOG_FILE}"

    cd "${OPL}/APPS/" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${OPL}/APPS."
    process_psu_files "${GAMES_PATH}/APPS/"
    process_psu_files "${OPL}/APPS/"

    rm -rf "${OPL}/APPS/PSBBN"
    install_elf "${GAMES_PATH}"
    install_elf "${OPL}"

    find "${GAMES_PATH}/APPS/" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} "${OPL}/APPS/" \; || error_msg "Error" "Failed copy apps. See $LOG_FILE for details."

    POPS_SYNC
    activate_python
    convert_zso
    OPL_SIZE_CKECK

    if (( needed_mb > 0 )); then
        echo "Total size of PS2 games to be copied: $needed_mb MB" | tee -a "${LOG_FILE}"
        echo "Available space: $available_mb MB" | tee -a "${LOG_FILE}"
        echo | tee -a "${LOG_FILE}"
        echo "Copying PS2 games..."
        # Update PS2 CD games
        rsync -rL --progress --ignore-existing --exclude=".*" "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        # Update PS2 DVD games
        rsync -rL --progress --ignore-existing --exclude=".*" "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check copied
    else
        echo "No PS2 games to copy." | tee -a "${LOG_FILE}"
    fi
fi

# Sends a list of apps and games synced/copied to the log file
echo >> "${LOG_FILE}"
echo "APPS on PS2 drive:" >> "${LOG_FILE}"
ls -1 "${OPL}/APPS/" >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "PS1 games on PS2 drive:" >> "${LOG_FILE}"
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount __.POPS\n"
COMMANDS+="ls\n"
COMMANDS+="umount\n"
COMMANDS+="exit"
echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>&1 | grep -i '\.vcd$' >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "PS2 games on PS2 drive:" >> "${LOG_FILE}"
ls -1 "${OPL}/CD/" >> "${LOG_FILE}" 2>&1
ls -1 "${OPL}/DVD/" >> "${LOG_FILE}" 2>&1

# Create games list of PS1 and PS2 games to be installed
if find "${GAMES_PATH}/POPS" -maxdepth 1 -type f \( -iname "*.vcd" \) | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating PS1 games list..." | tee -a "${LOG_FILE}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${GAMES_PATH}" "${PS1_LIST}" | tee -a "${LOG_FILE}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        error_msg "Error" "Failed to create PS1 games list."
    fi
fi

if find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating PS2 games list..." | tee -a "${LOG_FILE}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${PS2_LIST}" | tee -a "${LOG_FILE}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        error_msg "Error" "Failed to create PS2 games list."
    fi
fi

if [[ "$INSTALL_TYPE" = "copy" && -f "${OPL}/ps1.list" ]]; then
    cat "${OPL}/ps1.list" >> "${PS1_LIST}"
    # Remove duplicate lines
    sort -u "${PS1_LIST}" -o "${PS1_LIST}"
fi

if [ -f "${PS1_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS1_LIST}" || error_msg "Error" "Failed to sort PS1 games list."
fi

if [ -f "${PS2_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS2_LIST}" || error_msg "Error" "Failed to sort PS2 games list."
fi

# Deactivate the virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
fi

# Create master list combining PS1 and PS2 games to a single list
if [[ ! -f "${PS1_LIST}" && ! -f "${PS2_LIST}" ]] && find "${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    error_msg "Error" "Failed to create games list."
fi

if [[ -f "${PS1_LIST}" ]] && [[ ! -f "${PS2_LIST}" ]]; then
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ ! -f "${PS1_LIST}" ]] && [[ -f "${PS2_LIST}" ]]; then
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ -f "${PS1_LIST}" ]] && [[ -f "${PS2_LIST}" ]]; then
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
fi

rm -f "${OPL}/ps1.list"

# Check for master.list
if [[ -s "${ALL_GAMES}" ]]; then
    # Count the number of games to be installed
    [ -f "$PS1_LIST" ] && ! cp "${PS1_LIST}" "${OPL}" && error_msg "Error" "Failed to copy $PS1_LIST to ${OPL}"
    count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
    echo | tee -a "${LOG_FILE}"
    echo "Number of games to install: $count" | tee -a "${LOG_FILE}"
    echo
    echo "[✓] Games list successfully created."| tee -a "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    echo "master.list:" >> "${LOG_FILE}"
    cat "${ALL_GAMES}" >> "${LOG_FILE}"
fi

################################### Creating Assets ###################################

echo
echo -n "Preparing to create assets..."
echo | tee -a "${LOG_FILE}"

mkdir -p "${ICONS_DIR}/bbnl" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ICONS_DIR}/bbnl."
mkdir -p "${ICONS_DIR}/SAS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ICONS_DIR}/SAS."
mkdir -p "${ICONS_DIR}/APPS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ICONS_DIR}/APPS."
mkdir -p "${ARTWORK_DIR}/tmp" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ARTWORK_DIR}/tmp."
mkdir -p "${TOOLKIT_PATH}/icons/ico/tmp/vmc" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${TOOLKIT_PATH}/icons/ico/tmp/vmc."
mkdir -p "${TOOLKIT_PATH}/icons/ico/vmc" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${TOOLKIT_PATH}/icons/ico/tmp/vmc."

# Set maximum number of items for the Game Channel (799 + 1 for chosen launcher)
pp_cap="799"

################################### Assets for SAS Apps ###################################

SOURCE_DIR="${OPL}/APPS"

APA_SIZE_CHECK

if [ "$pp_max" -gt "$pp_cap" ]; then
  pp_max="$pp_cap"
fi

echo "Max Partitions: $pp_max" >> "${LOG_FILE}"

SAS_COUNT="0"

for dir in "${SOURCE_DIR}"/*/; do
    [[ -d "$dir" ]] || continue

    # Stop if we've reached the limit
    if [ "$SAS_COUNT" -ge "$pp_max" ]; then
        error_msg "Warning" "Insufficient space to create BBL partitions for remaining SAS apps." " " "The first $pp_max apps will appear in the PSBBN Game Channel." "All apps will appear in OPL."
        break
    fi

    # Check for .elf/.ELF file
    if find "$dir" -maxdepth 1 -type f -iname "*.elf" | grep -q . && \
       [[ -f "$dir/icon.sys" && -f "$dir/title.cfg" ]]; then
        cp -r "$dir" "${ICONS_DIR}/SAS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to copy $dir. See ${LOG_FILE} for details."
        SAS_COUNT=$((SAS_COUNT + 1))
    fi
done

if ! find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "No SAS apps to process." | tee -a "${LOG_FILE}"
else
    echo | tee -a "${LOG_FILE}"
    echo "Creating Assets for SAS Apps:" | tee -a "${LOG_FILE}"
    # Loop through each folder in the 'SAS' directory, sorted in reverse alphabetical order
    while IFS= read -r dir; do
        title_id=$(basename "$dir")
        echo | tee -a "${LOG_FILE}"

        if [ -f "$dir/list.icn" ]; then
            echo "Processing $title_id..." | tee -a "${LOG_FILE}"
            mv "$dir/list.icn" "$dir/list.ico" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to convert $dir/list.icn."
            echo "Converted list.icn: $dir/list.ico" | tee -a "${LOG_FILE}"
            [ -f "$dir/del.icn" ] && mv "$dir/del.icn" "$dir/del.ico" | echo "Converted del.icn: $dir/del.ico" | tee -a "${LOG_FILE}"
        
        else
            echo "list.icn not found in $dir." | tee -a "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/app.ico" "$dir/list.ico" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/list.ico using default icon."
            cp "${ICONS_DIR}/ico/app-del.ico" "$dir/del.ico" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/del.ico using default icon."
        fi

        # Convert the icon.sys file
        icon_sys_filename="$dir/icon.sys"

        python3 "${HELPER_DIR}/icon_sys_to_txt.py" "$icon_sys_filename" >> "${LOG_FILE}" 2>&1
        mv "$dir/icon.txt" "$icon_sys_filename" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to convert $icon_sys_filename"

        echo "Converted icon.sys: $icon_sys_filename"  | tee -a "${LOG_FILE}"

        while IFS='=' read -r key value; do
            key=$(echo "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Remove non-ASCII and non-printable characters
            value=$(printf '%s' "$value" | LC_ALL=C tr -cd '\40-\176')

            case "$key" in
                title) title="$value" ;;
                boot) elf="$value" ;;
                Developer) publisher="$value" ;;
            esac
        done < "$dir/title.cfg"

        # Generate the info.sys file
        info_sys_filename="$dir/info.sys"
        create_info_sys "$title" "$title_id" "$publisher"

        APP_ART

        # Generate the bbnl cfg file
        bbnl_cfg="${ICONS_DIR}/bbnl/$title_id.cfg"
        create_bbnl_cfg "/APPS/$title_id/$elf" "$title_id"

        cp "${ASSETS_DIR}/BBNL"/{boot.kelf,system.cnf} "$dir" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create boot.kelf or system.cnf. See ${LOG_FILE} for details."
        echo "Created: $dir/boot.kelf" | tee -a "${LOG_FILE}"
        echo "Created: $dir/system.cnf" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort)
fi

################################### Assets for ELF Files ###################################

pp_max=$(( pp_max - SAS_COUNT ))

echo "PP Max after SAS: $pp_max" >> "${LOG_FILE}"

APP_COUNT=0

for dir in "${SOURCE_DIR}"/*/; do
    [[ -d "$dir" ]] || continue

    # Stop if we've reached the max
    if [ "$APP_COUNT" -ge "$pp_max" ]; then
        error_msg "Warning" "Insufficient space to create BBL partitions for remaining ELF files." " " "The first $pp_max apps will appear in the PSBBN Game Channel." "All apps will appear in OPL."
        break
    fi

    # Check for .elf/.ELF file
    if find "$dir" -maxdepth 1 -type f -iname "*.elf" | grep -q . && \
       [[ ! -f "$dir/icon.sys" && -f "$dir/title.cfg" ]]; then
        cp -r "$dir" "${ICONS_DIR}/APPS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to copy $dir. See ${LOG_FILE} for details."
        APP_COUNT=$((APP_COUNT + 1))
    fi
done

if ! find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "No ELF files to process." | tee -a "${LOG_FILE}"
else
    echo | tee -a "${LOG_FILE}"
    echo "Creating Assets for ELF files:" | tee -a "${LOG_FILE}"
    # Loop through each folder in the 'APPS' directory, sorted in reverse alphabetical order
    while IFS= read -r dir; do
        title_id=$(basename "$dir")

        while IFS='=' read -r key value; do
            key=$(echo "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Remove non-ASCII and non-printable characters
            value=$(printf '%s' "$value" | LC_ALL=C tr -cd '\40-\176')

            case "$key" in
                title) title="$value" ;;
                boot) elf="$value" ;;
                Developer) publisher="$value" ;;
            esac
        done < "$dir/title.cfg"

        echo | tee -a "${LOG_FILE}"
        info_sys_filename="$dir/info.sys"
        if [[ "$title_id" == "LAUNCHELF" ]]; then
            title="LaunchELF"
        fi
        create_info_sys "$title" "$title_id" "$publisher"

        # Generate the icon.sys file
        icon_sys_filename="$dir/icon.sys"
        create_icon_sys "$title"

        if [[ "$title_id" == "LAUNCHELF" ]]; then
            cp "${ICONS_DIR}/ico/wle.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/list.ico" | tee -a "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/wle-del.ico" "$dir/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/del.ico" | tee -a "${LOG_FILE}"
        elif [[ "$title_id" == "BBNAVIGATOR" ]]; then
            cp "${ICONS_DIR}/ico/psbbn.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/list.ico" | tee -a "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/psbbn-del.ico" "$dir/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/del.ico" | tee -a "${LOG_FILE}"
        elif [[ "$title_id" == "HDDOSD" ]]; then
            cp "${ICONS_DIR}/ico/hdd-osd.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/list.ico" | tee -a "${LOG_FILE}"
        else
            cp "${ICONS_DIR}/ico/app.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/list.ico" | tee -a "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/app-del.ico" "$dir/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
            echo "Created: $dir/del.ico" | tee -a "${LOG_FILE}"
        fi

        if [[ "$title_id" == "BBNAVIGATOR" ]]; then
            cp "${ARTWORK_DIR}/PSBBN.png" "${GAMES_PATH}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create ${GAMES_PATH}/ART/${elf}_COV.png. See ${LOG_FILE} for details."
        else
            APP_ART
        fi

        bbnl_cfg="${ICONS_DIR}/bbnl/$title_id.cfg"
        create_bbnl_cfg "/APPS/$(basename "$dir")/$elf" "$title_id"

        cp "${ASSETS_DIR}/BBNL"/{boot.kelf,system.cnf} "$dir" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create boot.kelf, or system.cnf. See ${LOG_FILE} for details."
        echo "Created: $dir/boot.kelf" | tee -a "${LOG_FILE}"
        echo "Created: $dir/system.cnf" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

################################### Assets for Games ###################################

if [ -f "$ALL_GAMES" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Downloading OPL artwork for games..."  | tee -a "${LOG_FILE}"

    # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
        # Skip downloading if disc_type is "POPS"
        if [[ "$disc_type" == "POPS" ]]; then
            continue
        fi

        png_file_cover="${GAMES_PATH}/ART/${game_id}_COV.png"
        png_file_disc="${GAMES_PATH}/ART/${game_id}_ICO.png"
        if [[ -f "$png_file_cover" ]]; then
            echo "OPL Artwork for $game_id already exists. Skipping download." | tee -a "${LOG_FILE}"
        else
            # Attempt to download artwork using wget
            echo -n "OPL Artwork not found locally for $game_id. Attempting to download from archive.org..." | tee -a "${LOG_FILE}"
            echo | tee -a "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cover" \
            "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_COV.png"
            #wget --quiet --timeout=10 --tries=3 --output-document="$png_file_disc" \
            #"https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_ICO.png"

            missing_files=()

            if [[ ! -s "$png_file_cover" ]]; then
                [[ -f "$png_file_cover" ]] && rm -f "$png_file_cover"
                missing_files+=("cover")
            fi

            if [[ ! -s "$png_file_disc" ]]; then
                [[ -f "$png_file_disc" ]] && rm -f "$png_file_disc"
                missing_files+=("disc")
            fi

            if [[ -f "$png_file_cover" || -f "$png_file_disc" ]]; then
                if [[ ${#missing_files[@]} -eq 0 ]]; then
                    echo "[✓] Successfully downloaded OPL artwork for $game_id" | tee -a "${LOG_FILE}"
                else
                    echo "[✓] Successfully downloaded some OPL artwork for $game_id, but missing: ${missing_files[*]}" | tee -a "${LOG_FILE}"
                fi
            else
                echo "Failed to download OPL artwork for $game_id" | tee -a "${LOG_FILE}"
            fi
        fi
    done
    exec 3<&-
else
    echo | tee -a "${LOG_FILE}"
    echo "No OPL artwork to download." | tee -a "${LOG_FILE}"
fi

GAME_COUNT=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")

pp_max=$(( pp_max - APP_COUNT ))

if [ "$GAME_COUNT" -gt "$pp_max" ]; then
    error_msg "Warning" "Insufficient space to create BBL partitions for remaining games." " " "The first $pp_max games will appear in the PSBBN Game Channel." "All PS2 games will appear in OPL/NHDDL."
    # Overwrite master.list with the first $pp_max lines
    head -n "$pp_max" "$ALL_GAMES" > "${ALL_GAMES}.tmp"
    mv "${ALL_GAMES}.tmp" "$ALL_GAMES" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to updated master.list."
    echo "Updated master.list:" >> "${LOG_FILE}"
    cat "$ALL_GAMES" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
fi

[ -f "$ALL_GAMES" ] && [ ! -s "$ALL_GAMES" ] && rm -f "$ALL_GAMES"

if [ -f "$ALL_GAMES" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Downloading PSBBN artwork for games..."  | tee -a "${LOG_FILE}"

    # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
        # Check if the artwork file already exists
        png_file="${ARTWORK_DIR}/${game_id}.png"
        if [[ -f "$png_file" ]]; then
            echo "Artwork for $game_id already exists. Skipping download." | tee -a "${LOG_FILE}"
        else
            # Attempt to download artwork using wget
            echo -n "Artwork not found locally. Attempting to download from the PSBBN art database..." | tee -a "${LOG_FILE}"
            echo | tee -a "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
            "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/art/${game_id}.png"
            if [[ -s "$png_file" ]]; then
                echo "[✓] Successfully downloaded artwork for $game_id" | tee -a "${LOG_FILE}"
            else
                # If wget fails, run the art downloader
                [[ -f "$png_file" ]] && rm -f "$png_file"
                echo "Trying IGN for $game_id" | tee -a "${LOG_FILE}"
                "${HELPER_DIR}/art_downloader.py" "$game_id" 2>&1 | tee -a "${LOG_FILE}"
            fi
        fi
    done
    exec 3<&-

    # Define input directory
    input_dir="${ARTWORK_DIR}/tmp"

    # Check if the directory contains any files
    if compgen -G "${input_dir}/*" > /dev/null; then
        echo | tee -a "${LOG_FILE}"
        echo "Converting artwork..." | tee -a "${LOG_FILE}"
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
                    echo "Resizing square image $file"
                    convert "$file" -resize 256x256! -depth 8 -alpha off "$output"
                else
                    # Not square: Resize and crop
                    echo "Resizing and cropping $file"
                    convert "$file" -resize 256x256^ -crop 256x256+0+44 -depth 8 -alpha off "$output"
                fi
                rm -f "$file"
            else
                echo "Skipping $file: does not meet size requirements" | tee -a "${LOG_FILE}"
                rm -f "$file"
            fi
        done
    else
        echo | tee -a "${LOG_FILE}"
        echo "No artwork to convert in ${input_dir}" | tee -a "${LOG_FILE}"
    fi

    cp ${ARTWORK_DIR}/tmp/* ${ARTWORK_DIR} >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "Downloading HDD-OSD icons for games:"  | tee -a "${LOG_FILE}"

    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do

        ico_file="${ICONS_DIR}/ico/$game_id.ico"
        
        if [[ ! -s "$ico_file" ]]; then
            # Attempt to download icon using wget
            echo -n "Icon not found locally for $game_id. Attempting to download from the HDD-OSD icon database..." | tee -a "${LOG_FILE}"
            echo | tee -a "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 --output-document="$ico_file" \
            "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/ico/${game_id}.ico"
            if [[ -s "$ico_file" ]]; then
                echo "[✓] Successfully downloaded icon for ${game_id}." | tee -a "${LOG_FILE}"
                echo | tee -a "${LOG_FILE}"
            else
                # If wget fails, run the art downloader
                [[ -f "$ico_file" ]] && rm -f "$ico_file"

                png_file_cov="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_COV.png"
                png_file_cov2="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_COV2.png"
                png_file_lab="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_LAB.png"

                echo -n "Icon not found on database. Downloading icon assets for $game_id..." | tee -a "${LOG_FILE}"

                if [[ -s "${GAMES_PATH}/ART/${game_id}_COV.png" ]]; then
                    cp "${GAMES_PATH}/ART/${game_id}_COV.png" "${png_file_cov}"
                fi

                if [[ "$disc_type" == "POPS" ]]; then
                    wget --quiet --timeout=10 --tries=3 --output-document="${png_file_cov}" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_COV.png"
                fi

                if [[ -s "$png_file_cov" && "$disc_type" != "POPS" ]]; then
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cov2" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_COV2.png"
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_lab" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_LAB.png"
                elif [[ -s "$png_file_cov" && "$disc_type" == "POPS" ]]; then
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cov2" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_COV2.png"
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_lab" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_LAB.png"
                fi

                echo | tee -a "${LOG_FILE}"

                if [[ ! -s "$png_file_lab" ]]; then
                    if [[ "${game_id:2:1}" == "E" ]]; then
                        if [[ "$disc_type" != "POPS" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_PAL.png" "${png_file_lab}"
                        else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_PAL.png" "${png_file_lab}"
                        fi
                    elif [[ "${game_id:2:1}" == "U" || "${game_id:0:1}" == "L" ]]; then
                        if [[ "$disc_type" != "POPS" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_USA.png" "${png_file_lab}"
                    else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_USA.png" "${png_file_lab}"
                        fi
                    else
                        if [[ "$disc_type" != "POPS" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_JPN.png" "${png_file_lab}"
                        else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_JPN.png" "${png_file_lab}"
                        fi
                    fi
                fi

                if [[ -s "$png_file_cov" && -s "$png_file_cov2" && -s "$png_file_lab" ]]; then
                    echo "Creating HDD-OSD icon for $game_id..." | tee -a "${LOG_FILE}"
                    if [[ "$disc_type" != "POPS" ]]; then
                        if [[ "${game_id:2:1}" == "E" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 2
                        else
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 1
                        fi
                    else
                        if [[ "${game_id:2:1}" == "U" || "${game_id:0:1}" == "L" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 3
                        elif [[ "${game_id:2:1}" == "E" ]]; then
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 6
                        else
                            "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 5
                        fi
                    fi
                    echo | tee -a "${LOG_FILE}"
                else
                    echo "Insufficient assets to create icon for $game_id." | tee -a "${LOG_FILE}"
                    echo | tee -a "${LOG_FILE}"
                fi
            fi
        fi
    done
    exec 3<&-

    echo | tee -a "${LOG_FILE}"

    if [ -f "$PS1_LIST" ]; then
        echo "Downloading VMC icons:"  | tee -a "${LOG_FILE}"

        exec 3< "$PS1_LIST"
        while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
                ico_file="${ICONS_DIR}/ico/vmc/$game_id.ico"
        
                if [[ ! -s "$ico_file" ]]; then
                    # Attempt to download icon using wget
                    echo -n "VMC icon not found locally for $game_id. Attempting to download from the HDD-OSD icon database..." | tee -a "${LOG_FILE}"
                    echo | tee -a "${LOG_FILE}"
                    wget --quiet --timeout=10 --tries=3 --output-document="$ico_file" \
                    "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/vmc/${game_id}.ico"
                    if [[ -s "$ico_file" ]]; then
                        echo "[✓] Successfully downloaded VMC icon for ${game_id}." | tee -a "${LOG_FILE}"
                        echo | tee -a "${LOG_FILE}"
                    else
                        # If wget fails, run the art downloader
                        [[ -f "$ico_file" ]] && rm -f "$ico_file"

                        png_file_lgo="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_LGO.png"

                        echo -n "VMC icon not found on database. Downloading icon assets for $game_id..." | tee -a "${LOG_FILE}"

                        wget --quiet --timeout=10 --tries=3 --output-document="${png_file_lgo}" \
                        "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_LGO.png"
                    fi

                    if [[ -s "$png_file_lgo" ]]; then
                        echo| tee -a "${LOG_FILE}"
                        echo -n "Creating VMC icon for $game_id..." | tee -a "${LOG_FILE}"
                        "${HELPER_DIR}/ps2iconmaker.sh" $game_id -t 8
                        echo | tee -a "${LOG_FILE}"
                    elif [[ ! -s "$ico_file" ]] && [[ ! -s "$png_file_lgo" ]]; then
                        echo | tee -a "${LOG_FILE}"
                        echo "Insufficient assets to create VMC icon for $game_id." | tee -a "${LOG_FILE}"
                        echo | tee -a "${LOG_FILE}"
                    fi
                fi
        done
        exec 3<&-
    fi

    cp "${ICONS_DIR}/ico/tmp/"*.ico "${ICONS_DIR}/ico/" >/dev/null 2>&1
    cp "${ICONS_DIR}/ico/tmp/vmc/"*.ico "${ICONS_DIR}/ico/vmc" >/dev/null 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "Creating Assets for Games:"  | tee -a "${LOG_FILE}"

    # Read the file line by line

    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name <&3; do
        echo | tee -a "${LOG_FILE}"
        echo "Processing $title..." 
        title_id=$(echo "$game_id" | sed -E 's/_(...)\./-\1/;s/\.//')
        # Create a sub-folder named after the game_id
        game_dir="$ICONS_DIR/$game_id"
        mkdir -p "$game_dir" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create $dir."

        cp "${ASSETS_DIR}/BBNL"/{boot.kelf,system.cnf} "${game_dir}" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create boot.kelf, or system.cnf. See ${LOG_FILE} for details."
        echo "Created: $game_dir/boot.kelf" | tee -a "${LOG_FILE}"
        echo "Created: $game_dir/system.cnf" | tee -a "${LOG_FILE}"

        # Generate the info.sys file
        info_sys_filename="$game_dir/info.sys"
        create_info_sys "$title" "$title_id" "$publisher"

        if [ ${#title} -gt 48 ]; then
            game_title_icon="${title:0:45}..."
        else
            game_title_icon="$title"
        fi

        # Generate the icon.sys file
        icon_sys_filename="$game_dir/icon.sys"
        create_icon_sys "$game_title_icon" "$publisher"

        # Copy the matching .png file and rename it to jkt_001.png
        png_file="${TOOLKIT_PATH}/icons/art/${game_id}.png"
        if [[ -s "$png_file" ]]; then
            cp "$png_file" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/jkt_001.png. See ${LOG_FILE} for details."
            echo "Created: $game_dir/jkt_001.png"  | tee -a "${LOG_FILE}"
        else
            echo "$game_id $title" >> "${MISSING_ART}"
            if [[ "$disc_type" == "POPS" ]]; then
                cp "${TOOLKIT_PATH}/icons/art/ps1.png" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/jkt_001.png. See ${LOG_FILE} for details."
                echo "Created: $game_dir/jkt_001.png using default PS1 image." | tee -a "${LOG_FILE}"
            else
                cp "${TOOLKIT_PATH}/icons/art/ps2.png" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/jkt_001.png. See ${LOG_FILE} for details."
                echo "Created: $game_dir/jkt_001.png using default PS2 image." | tee -a "${LOG_FILE}"
            fi
        fi

        ico_file="${ICONS_DIR}/ico/$game_id.ico"

        if [[ -f "$ico_file" ]]; then
            cp "${ICONS_DIR}/ico/$game_id.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/list.ico. See ${LOG_FILE} for details."
            echo "Created: $game_dir/list.ico"
        else
            echo "$game_id $title" >> "${MISSING_ICON}"
            case "$disc_type" in
            DVD)
                cp "${ICONS_DIR}/ico/dvd.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/list.ico. See ${LOG_FILE} for details."
                echo "Created: $game_dir/list.ico using default DVD icon." | tee -a "${LOG_FILE}"
            ;;
            CD)
                cp "${ICONS_DIR}/ico/cd.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/list.ico. See ${LOG_FILE} for details."
                echo "Created: $game_dir/list.ico using default CD icon." | tee -a "${LOG_FILE}"
            ;;
            POPS)
                cp "${ICONS_DIR}/ico/ps1.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $game_dir/list.ico. See ${LOG_FILE} for details."
                echo "Created: $game_dir/list.ico using default PS1 icon." | tee -a "${LOG_FILE}"
            ;;
            esac
        fi

        PP_NAME
        # Generate the BBNL cfg file
        # Determine the launcher value for this specific game
        if [[ "$disc_type" == "POPS" ]]; then
            launcher_value="POPS"
        else
            launcher_value="$LAUNCHER"
        fi
        bbnl_label="${PARTITION_LABEL:3}"
        bbnl_cfg="${ICONS_DIR}/bbnl/$bbnl_label.cfg"
        cat > "$bbnl_cfg" <<EOL
file_name=$file_name
title_id=$game_id
disc_type=$disc_type
launcher=$launcher_value
EOL

    echo "Created: $bbnl_cfg"  | tee -a "${LOG_FILE}"

    done
    exec 3<&-

else
    echo | tee -a "${LOG_FILE}"
    echo "No games to process." | tee -a "${LOG_FILE}"
fi

bbnl_cfg="${ICONS_DIR}/bbnl/LAUNCHER.cfg"

echo | tee -a "${LOG_FILE}"
if [ "$LAUNCHER" = "OPL" ]; then
    cp "${ASSETS_DIR}/BBNL"/{boot.kelf,system.cnf} "${ASSETS_DIR}/OPL" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create boot.kelf, or system.cnf for OPL. See ${LOG_FILE} for details."
    create_bbnl_cfg "/bbnl/OPNPS2LD.ELF" "LAUNCHER"
elif [ "$LAUNCHER" = "NEUTRINO" ]; then
    cp "${ASSETS_DIR}/BBNL"/{boot.kelf,system.cnf} "${ASSETS_DIR}/NHDDL" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create boot.kelf, or system.cnf for NHDDL. See ${LOG_FILE} for details."
    create_bbnl_cfg "/bbnl/nhddl.elf" "LAUNCHER" "-mode=ata"
fi

# Copy OPL files
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

echo | tee -a "${LOG_FILE}"
# Check each directory and copy files if not empty
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ] && [ -n "$(find "$dir" -type f ! -name '.*' -print -quit 2>/dev/null)" ]; then
        # Create the subdirectory in the destination path using the directory name
        folder_name=$(basename "$dir")
        dest_dir="${OPL}/$folder_name"
        
        # Copy non-hidden files to the corresponding destination subdirectory
        if [ "$folder_name" == "CFG" ] || [ "$folder_name" == "VMC" ]; then
            echo "Copying OPL $folder_name files..." | tee -a "${LOG_FILE}"
            find "$dir" -type f ! -name '.*' -exec cp --update=none {} "$dest_dir" \; >> "${LOG_FILE}" 2>&1
        else
            if [ -n "$(find "$dir" -mindepth 1 ! -name '.*' -print -quit)" ]; then
            echo "Copying OPL $folder_name files..." | tee -a "${LOG_FILE}"
            cp -r "$dir"/* "$dest_dir" >> "${LOG_FILE}" 2>&1
        fi
    fi
        files_exist=true
    fi
done

# Print message based on the check
if ! $files_exist; then
    echo "No OPL files to copy." | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo "Copying BBNL configs..." | tee -a "${LOG_FILE}"
rm -f "${OPL}"/bbnl/*.cfg >> "${LOG_FILE}" 2>&1
cp "${ICONS_DIR}"/bbnl/*.cfg "${OPL}/bbnl" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to copy BBNL config files. See ${LOG_FILE} for details."

echo | tee -a "${LOG_FILE}"
echo "All assets have been sucessfully created." | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

echo -n "Unmounting OPL partition..." | tee -a "${LOG_FILE}"
UNMOUNT_OPL
echo | tee -a "${LOG_FILE}"

if [ -f "$PS1_LIST" ]; then
    CREATE_VMC
fi

################################### Create BBNL Partitions ###################################

if find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo "Creating BBNL Partitions for SAS Apps:" | tee -a "${LOG_FILE}"

    while IFS= read -r dir; do

        folder_name=$(basename "$dir")
        pp_name="PP.$folder_name"

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            error_msg "Warning" "Insufficient space for another partition."
            break
        fi

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart $pp_name 8M PFS\n"
        COMMANDS+="mount $pp_name\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/SAS/$folder_name'\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="put jkt_001.png\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        PFS_COMMANDS
        cd "${ICONS_DIR}/SAS/$folder_name" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/SAS/$folder_name."
        sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of $pp_name"
        echo "Created $pp_name" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

if find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating BBNL Partitions for ELF files:" | tee -a "${LOG_FILE}"

    while IFS= read -r dir; do

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            error_msg "Warning" "Insufficient space for another partition."
            break
        fi

        folder_name=$(basename "$dir")
        pp_name="PP.$folder_name"

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart $pp_name 8M PFS\n"
        COMMANDS+="mount $pp_name\n"
        if [ "$pp_name" = "PP.DISC" ]; then
            COMMANDS+="lcd '${ASSETS_DIR}/DISC'\n"
            COMMANDS+="put PS1VModeNeg.elf\n"
        fi
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/APPS/$folder_name'\n"
        COMMANDS+="put info.sys\n"
        if [ "$pp_name" != "PP.BBNAVIGATOR" ]; then
            COMMANDS+="put jkt_001.png\n"
        fi
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        PFS_COMMANDS

        if [ "$pp_name" = "PP.LAUNCHDISC" ]; then
            cd "${ASSETS_DIR}/DISC" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ASSETS_DIR}/DISC."
            sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of $pp_name."
        else
            cd "${ICONS_DIR}/APPS/$folder_name" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/APPS/$folder_name."
            sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of $pp_name."
        fi
        echo "Created $pp_name" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

# Create PP.LAUNCHER

APA_SIZE_CHECK

# Check the value of available
if [ "$available" -lt 8 ]; then
    error_msg "Warning" "Insufficient space for another partition."
else

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart PP.LAUNCHER 8M PFS\n"
    COMMANDS+="mount PP.LAUNCHER\n"
    COMMANDS+="mkdir res\n"
    COMMANDS+="cd res\n"

    if [ "$LAUNCHER" = "OPL" ]; then
        cd "${ASSETS_DIR}/OPL"
        COMMANDS+="put info.sys\n"
        COMMANDS+="lcd '${ARTWORK_DIR}'\n"
        COMMANDS+="put OPENPS2LOAD.png\n"
        COMMANDS+="rename OPENPS2LOAD.png jkt_001.png\n"
        COMMANDS+="cd /\n"
    elif [ "$LAUNCHER" = "NEUTRINO" ]; then
        cd "${ASSETS_DIR}/NHDDL"
        COMMANDS+="put info.sys\n"
        COMMANDS+="lcd '${ARTWORK_DIR}'\n"
        COMMANDS+="put NHDDL.png\n"
        COMMANDS+="rename NHDDL.png jkt_001.png\n"
        COMMANDS+="cd /\n"
    fi

    COMMANDS+="umount\n"
    COMMANDS+="exit"

    echo >> "${LOG_FILE}"
    PFS_COMMANDS

    sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" PP.LAUNCHER >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of PP.LAUNCHER."
    echo | tee -a "${LOG_FILE}"
    echo "Created PP.LAUNCHER" | tee -a "${LOG_FILE}"
fi

if [ -f "$ALL_GAMES" ]; then

    # Read all lines in reverse order
    mapfile -t reversed_lines < <(tac "$ALL_GAMES")

    echo | tee -a "${LOG_FILE}"
    echo "Creating BBNL Partitions for Games:" | tee -a "${LOG_FILE}"
    i=0

    # Reverse the lines of the file using tac and process each line
    for line in "${reversed_lines[@]}"; do
        IFS='|' read -r title game_id publisher disc_type file_name <<< "$line"

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            error_msg "Warning" "Insufficient space for another partition."
            break
        fi

        PP_NAME

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart ${PARTITION_LABEL} 8M PFS\n"
        COMMANDS+="mount ${PARTITION_LABEL}\n"
        COMMANDS+="cd /\n"

        # Navigate into the sub-directory named after the gameid
        COMMANDS+="lcd '${ICONS_DIR}/${game_id}'\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="put jkt_001.png\n"

        if [[ "$disc_type" == "POPS" ]]; then
            COMMANDS+="lcd '${ASSETS_DIR}/POPStarter'\n"
            COMMANDS+="put bg.png\n"
            COMMANDS+="lcd '${ASSETS_DIR}/POPStarter/eng'\n"
            COMMANDS+="put 1.png\n"
            COMMANDS+="put 2.png\n"
            COMMANDS+="put man.xml\n"
        fi

        COMMANDS+="umount\n"
        COMMANDS+="exit\n"

        PFS_COMMANDS

        cd "${ICONS_DIR}/$game_id" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/$game_id."
        sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" "${PARTITION_LABEL}" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of ${PARTITION_LABEL}."
        echo "Created $PARTITION_LABEL" | tee -a "${LOG_FILE}"
        echo >> "${LOG_FILE}"

        ((i++))
    done
fi

################################### Submit missing artwork to the PSBBN Art Database ###################################

cp "${MISSING_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_APP_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_ICON}" "${ICONS_DIR}/ico/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_VMC}" "${ICONS_DIR}/ico/tmp/" >> "${LOG_FILE}" 2>&1
cd "${ICONS_DIR}/ico/tmp/"
rm *.png >/dev/null 2>&1
if [ -d "${ICONS_DIR}/ico/tmp/vmc" ] && [ -z "$(ls -A "${ICONS_DIR}/ico/tmp/vmc")" ]; then
    rmdir "${ICONS_DIR}/ico/tmp/vmc"
fi
zip -r "${ARTWORK_DIR}/tmp/ico.zip" * >/dev/null 2>&1
cd "${ARTWORK_DIR}/tmp/" 
zip -r "${ARTWORK_DIR}/tmp/art.zip" * >/dev/null 2>&1

if [ -f "${ARTWORK_DIR}/tmp/art.zip" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Contributing to the PSBBN art & HDD-OSD databases..." | tee -a "${LOG_FILE}"
    # Upload the file using transfer.sh
    upload_url=$(curl -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@${ARTWORK_DIR}/tmp/art.zip" https://litterbox.catbox.moe/resources/internals/api.php)

    if [[ "$upload_url" == https://* ]]; then
        echo "[✓] File uploaded successfully: $upload_url" | tee -a "${LOG_FILE}"

    # Send a POST request to Webhook.site with the uploaded file URL
    webhook_url="https://webhook.site/PSBBN"
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"url\": \"$upload_url\"}" \
        "$webhook_url" >/dev/null 2>&1
    else
        error_msg "Warning" "Failed to upload the file."
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No art work or icons to contribute." | tee -a "${LOG_FILE}"
fi

HDL_TOC
cat "$hdl_output" >> "${LOG_FILE}"
rm -f "$hdl_output"


echo | tee -a "${LOG_FILE}"
echo "Game installer script complete." | tee -a "${LOG_FILE}"
echo
read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
echo
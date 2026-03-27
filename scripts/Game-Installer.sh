#!/usr/bin/env bash
#
# Game Installer form the PSBBN Definitive Project
# Copyright (C) 2024-2026 CosmicScale
#
# <https://github.com/CosmicScale/PSBBN-Definitive-English-Patch>
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

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

version_check="4.0.0"

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
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
PS1_LIST="${SCRIPTS_DIR}/tmp/ps1.list"
PS1_JPN_LIST="${SCRIPTS_DIR}/tmp/ps1-jpn.list"
PS2_LIST="${SCRIPTS_DIR}/tmp/ps2.list"
PS2_JPN_LIST="${SCRIPTS_DIR}/tmp/ps2-jpn.list"
TMP_LIST="${SCRIPTS_DIR}/tmp/tmp.list"
ALL_GAMES="${SCRIPTS_DIR}/tmp/master.list"
ELF_LIST="${SCRIPTS_DIR}/tmp/elf.list"
SAS_LIST="${SCRIPTS_DIR}/tmp/sas.list"
APPS_LIST="${SCRIPTS_DIR}/tmp/app.list"
OSDMENU_CNF="${SCRIPTS_DIR}/tmp/OSDMENU.CNF"
arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    CUE2POPS="${HELPER_DIR}/cue2pops"
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/sqlite"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    CUE2POPS="${HELPER_DIR}/aarch64/cue2pops"
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/aarch64/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/aarch64/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/aarch64/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/aarch64/sqlite"
fi

PFS_PARTITIONS=("__common" "__system" "__sysconf" "__.POPS" )
LINUX_PARTITIONS=("__linux.7" )

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
    failure=0

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
        || { echo "[X] Error: Failed to remove tmp files." >> "${LOG_FILE}"; failure=1; }

    unmount_apa

    if [ -d "${STORAGE_DIR}" ]; then
        submounts=$(findmnt -nr -o TARGET | grep "^${STORAGE_DIR}/")

        if [ -z "$submounts" ]; then
            echo "Deleting ${STORAGE_DIR}..." >> "$LOG_FILE"
            sudo rm -rf "${STORAGE_DIR}" || { echo "[X] Error: Failed to delete ${STORAGE_DIR}" >> "$LOG_FILE"; failure=1; }
            echo "Deleted ${STORAGE_DIR}." >> "$LOG_FILE"
        else
            echo "Some mounts remain under ${STORAGE_DIR}, not deleting." >> "$LOG_FILE"
            failure=1
        fi
    else
        echo "Directory ${STORAGE_DIR} does not exist." >> "$LOG_FILE"
    fi

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        error_msg "Error" "Cleanup error(s) occurred. Aborting."
    fi

}

exit_script() {
    prevent_sleep_stop
    
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

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
        read -n 1 -s -r -p "Press any key to return to the main menu..." </dev/tty
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
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Error" "Failed to mount OPL partition."
    fi

    # Create necessary folders if they don't exist
    for folder in APPS ART CFG CHT LNG THM VMC CD DVD; do
        dir="${OPL}/${folder}"
        [[ -d "$dir" ]] || mkdir -p "$dir" || { 
            error_msg "Error" "Failed to create $dir."
        }
    done
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "Error" "Failed to extract list of partitions." " " "APA partition could be broken on ${DEVICE}"
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
    hosd_parts=(__system __sysconf __.POPS __common)

    if has_all "${psbbn_parts[@]}"; then
        echo "PSBBN Detected" >> "${LOG_FILE}"
        OS="PSBBN"
    elif has_all "${hosd_parts[@]}"; then
        echo "HOSDMenu Detected" >> "${LOG_FILE}"
        OS="HOSD"
    else
        error_msg "Error" "Failed to detect PSBBN or HOSDMenu on ${DEVICE}."
    fi

}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
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
            if [[ "$(basename "$file")" == "APP_WLE-ISR-XF-MM.psu" ]]; then
                "${PSU_EXTRACT}" "$file" >> "${LOG_FILE}" 2>&1
            else
                "${PSU_EXTRACT}" "$file" -f >> "${LOG_FILE}" 2>&1
            fi
        done
    fi
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
        cp "${VMC_ICON_DIR}/GP_KONAMI.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tomba! USA" ]; then
        cp "${VMC_ICON_DIR}/GP_TOMBA.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tombi! PAL" ]; then
        cp "${VMC_ICON_DIR}/GP_TOMBI.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tomba! JAP" ]; then
        cp "${VMC_ICON_DIR}/GP_TOMBA-JPN.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Square JAP" ] || [ "$VMC_GROUP_FOLDER" = "GP_Square USA" ]; then
        cp "${VMC_ICON_DIR}/GP_SQUARE.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Arc the Lad USA" ] || [ "$VMC_GROUP_FOLDER" = "GP_Arc the Lad JPN" ]; then
        cp "${VMC_ICON_DIR}/GP_ARK-THE-LAD.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Armored Core JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Armored Core USA" ]; then
        cp "${VMC_ICON_DIR}/GP_ARMORED-CORE.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo PAL" ] || [ "$VMC_GROUP_FOLDER" = "GP_Gran Turismo USA" ]; then
        cp "${VMC_ICON_DIR}/GP_GRAN-TURISMO.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Tekken JPN" ] || [ "$VMC_GROUP_FOLDER" = "GP_Tekken PAL" ] || [ "$VMC_GROUP_FOLDER" = "GP_Tekken USA" ]; then
        cp "${VMC_ICON_DIR}/GP_TEKKEN.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Monster Rancher" ]; then
        cp "${VMC_ICON_DIR}/GP_MONSTER-RANCHER.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_Monster Farm JPN" ]; then
        cp "${VMC_ICON_DIR}/GP_MONSTER-FARM.ico" ./list.ico
    elif [ "$VMC_GROUP_FOLDER" = "GP_PopoloCrois JPN" ]; then
        cp "${VMC_ICON_DIR}/GP_POPOLOCROIS.ico" ./list.ico
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
    exec 3< "${PS1_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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

    cp -rf "${POPS_DIR}/${VMC_FOLDER}/"* "${STORAGE_DIR}/__common/POPS"
}

CREATE_PS2_VMC() {

    declare -A vmc_groups_by_id
    declare -A vmc_sizes_by_group
    current_group=""
    current_size="8"

    echo | tee -a "${LOG_FILE}"
    echo -n "Creating VMCs for PS2 games..." | tee -a "${LOG_FILE}"

    # Compile genvmc if not already compiled
    if [[ ! -x "${HELPER_DIR}/genvmc" ]]; then
        echo >> "${LOG_FILE}"
        echo "Compiling genvmc..." >> "${LOG_FILE}"
        if ! gcc -std=gnu99 -o "${HELPER_DIR}/genvmc" "${HELPER_DIR}/genvmc.c" >> "${LOG_FILE}" 2>&1; then
            echo " failed to compile genvmc." | tee -a "${LOG_FILE}"
            return 1
        fi
    fi

    # Parse ps2_vmc_groups.list
    exec 3< "${HELPER_DIR}/ps2_vmc_groups.list"
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

    # Create nhddl directory for per-game YAML files
    mkdir -p "${OPL}/nhddl"

    # Process each PS2 game
    exec 3< "${PS2_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do

        # Determine VMC name and size
        if [[ -n "${vmc_groups_by_id[$game_id]}" ]]; then
            vmc_name="${vmc_groups_by_id[$game_id]}"
            vmc_size="${vmc_sizes_by_group[$vmc_name]}"
        else
            vmc_name="$game_id"
            vmc_size="8"
        fi

        vmc_file="${vmc_name}.bin"

        # Create VMC .bin if it doesn't already exist
        if [[ ! -f "${OPL}/VMC/${vmc_file}" ]] && [[ -z "${created_vmcs[$vmc_name]}" ]]; then

            # Check available space (in KB)
            available_kb=$(df -Pk "${OPL}" | awk 'NR==2 {print $4}')
            echo >> "${LOG_FILE}"
            echo "Available space for VMCs: $available_kb" >> "${LOG_FILE}"

            if (( available_kb < 40960 )); then
                echo
                echo "ERROR: Not enough free space to create all VMCs." | tee -a "${LOG_FILE}"
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
            printf '$VMC_0=%s\r\n' "${vmc_name}" >> "$cfg_file"
        fi

        # Write NHDDL YAML for Neutrino
        iso_name="${file_name%.*}"
        yaml_file="${OPL}/nhddl/${iso_name}.yaml"
        if [[ ! -f "$yaml_file" ]]; then
            printf 'mc0: /VMC/%s\n' "${vmc_file}" > "$yaml_file"
        elif ! grep -q '^mc0:' "$yaml_file"; then
            printf 'mc0: /VMC/%s\n' "${vmc_file}" >> "$yaml_file"
        fi

    done
    exec 3<&-

    echo " done." | tee -a "${LOG_FILE}"
}

POPS_SIZE_CKECK() {

    if [ "$INSTALL_TYPE" = "sync" ]; then
        pops_size=$(df -m --output=size "${STORAGE_DIR}/__.POPS" | tail -n 1 | awk '{$1=$1};1')
        available_mb=$((pops_size - 128))
        needed_mb=$(find "${GAMES_PATH}/POPS" -type f -iname '*.vcd' -printf '%s\n' | awk '{s+=$1} END {print int((s + 1048575) / 1048576)}')

    elif [ "$INSTALL_TYPE" = "copy" ]; then
        pops_freespace=$(df -m "${STORAGE_DIR}/__.POPS" | awk 'NR==2 {print $5}')
        available_mb=$((pops_freespace - 128))
        needed_mb=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${STORAGE_DIR}/__.POPS/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
    fi

    if (( available_mb < needed_mb )); then
        error_msg "Error" "Total size of PS1 games are ${needed_mb} MB, exceeds available space of ${available_mb} MB." " " "Remove some VCD files from the local POPS folder and try again."
    fi
}

OPL_SIZE_CKECK() {

    if [ "$INSTALL_TYPE" = "sync" ]; then
        opl_size=$(df -m --output=size "${OPL}" | tail -n 1 | awk '{$1=$1};1')
        available_mb=$((opl_size - 128))
        needed_mb=$(find "${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" -type f \( -iname '*.iso' -o -iname '*.zso' \) -printf '%s\n' | awk '{s+=$1} END {print int((s + 1048575) / 1048576)}')

    elif [ "$INSTALL_TYPE" = "copy" ]; then
        opl_freespace=$(df -m "${OPL}/" | awk 'NR==2 {print $4}')
        available_mb=$((opl_freespace - 128))
        cd_size=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        dvd_size=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
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

    # Calculate available space (APA_SIZE - used)
    available=$((APA_SIZE - used))
    pp_max=$(((available / 8) - 1))
}

app_success_check() {
    local name="$1"
    if [ $exit_code -ne 0 ]; then
        error_msg "Error" "Failed to update $name. See game-installer.log for details."
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

    if [[ "$name" == "NHDDL" || "$name" == "OPL" ]]; then
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
    if [ -d "${STORAGE_DIR}/__common/POPS" ] && [ -f "${STORAGE_DIR}/__common/POPS/POPS.ELF" ] && [ -f "${STORAGE_DIR}/__common/POPS/IOPRP252.IMG" ]; then
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

        mkdir -p "${STORAGE_DIR}/__common/POPS"
        if cp "${ASSETS_DIR}/POPS-binaries-main/"{POPS.ELF,IOPRP252.IMG} "${STORAGE_DIR}/__common/POPS"; then
            echo "[✓] POPS-binaries successfully installed." | tee -a "${LOG_FILE}"
        else
            error_msg "Warning" "One or both files (POPS.ELF, IOPRP252.IMG) are missing" "Without these files PS1 games will not be playable."
        fi
    fi

    if { [ ! -f "${STORAGE_DIR}/__common/POPS/IGR_BG.TM2" ] || [ ! -f "${STORAGE_DIR}/__common/POPS/IGR_YES.TM2" ] || [ ! -f "${STORAGE_DIR}/__common/POPS/IGR_NO.TM2" ]; } && [[ "$LANG" != "JPN" ]]; then
        echo "Copying POPS IRG files..." | tee -a "${LOG_FILE}"
        cp -f "${ASSETS_DIR}/POPStarter/$LANG/"{IGR_BG.TM2,IGR_YES.TM2,IGR_NO.TM2} "${STORAGE_DIR}/__common/POPS"  >> "${LOG_FILE}" 2>&1
    else
        echo "POPS IGR files already exist." | tee -a "${LOG_FILE}"
    fi

    if [ ! -f "${STORAGE_DIR}/__system/launcher/POPSTARTER.ELF" ]; then
        echo "Copying POPSTARTER.ELF..." | tee -a "${LOG_FILE}"
        cp -f "${ASSETS_DIR}/POPStarter/POPSTARTER.ELF" "${STORAGE_DIR}/__system/launcher/POPSTARTER.ELF" || error_msg "Error" "Failed to copy POPSTARTER.ELF."
    else
        echo "POPStarter is already installed." | tee -a "${LOG_FILE}"
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

            cat > "${elf_dir}/title.cfg" <<EOL
title=$title
boot=$elf
Title=$title
CfgVersion=8
Developer=
Genre=Homebrew
EOL
        done
    fi
}

activate_python() {
    echo
    msg="Preparing to $INSTALL_TYPE games..."
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

convert_bin(){
    if find "${GAMES_PATH}/CD/" -maxdepth 1 -type f \( -iname "*.cue" \) | grep -q .; then
        # Loop over all .cue files in the folder
        for cue in "${GAMES_PATH}/CD"/*.[cC][uU][eE]; do
            base="${cue%.[cC][uU][eE]}"        # Full path minus .cue
            iso="${base}.iso"

            if [[ -f "${base}.bin" ]]; then
                bin="${base}.bin"
            elif [[ -f "${base}.BIN" ]]; then
                bin="${base}.BIN"
            else
                echo "[!] Missing BIN file for '$(basename "$cue")', skipping." | tee -a "${LOG_FILE}"
                continue
            fi

            if [[ -f "$iso" ]] || [[ -f "${OPL}/CD/$(basename "${cue%.*}").iso" ]]; then
                echo "ISO already exists for '$(basename "$cue")'. Skipping conversion." | tee -a "${LOG_FILE}"
                continue
            fi

            echo "Converting '$(basename "$cue")'..."

            # Run bchunk (creates ${base}01.iso)
            bchunk "$bin" "$cue" "$base"
            echo

            # Rename output file (remove the 01)
            if [[ -f "${base}01.iso" ]]; then
                mv -f "${base}01.iso" "$iso"
            fi
        done
    else
        echo "No PS2 .cue files to convert in ${GAMES_PATH}/CD." | tee -a "${LOG_FILE}"
    fi
}

convert_vcd(){
    # Check if any .cue files exist
    if find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f -iname "*.cue" | grep -q .; then
        # Loop over all .cue files in the folder
        echo | tee -a "${LOG_FILE}"
        for cue in "${GAMES_PATH}/POPS"/*.[cC][uU][eE]; do
            base="${cue%.[cC][uU][eE]}"        # Full path minus .cue
            vcd="${base}.VCD"
            merged="$(basename "$cue" .cue)"

            if [[ -f "$vcd" ]] || [[ -f "${STORAGE_DIR}/__.POPS/$(basename "${cue%.*}").VCD" ]]; then
                echo "VCD already exists for '$(basename "$cue")'. Skipping conversion." | tee -a "${LOG_FILE}"
                continue
            fi

            # Count all .bin files starting with the same base name
            bin_count=$(find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f -iname "$(basename "$base")*.bin" | wc -l)

            if (( bin_count > 1 )); then
                echo -n "Merging '$(basename "$cue")'..."
                python3 "${HELPER_DIR}/binmerge.py" "$cue" "${SCRIPTS_DIR}/tmp/$merged" >>"${LOG_FILE}" 2>&1
                echo | tee -a "${LOG_FILE}"

                cd "${SCRIPTS_DIR}/tmp"
                echo -n "Converting '$(basename "$cue")' to VCD..."
                "${CUE2POPS}" "${SCRIPTS_DIR}/tmp/$merged.cue" "${GAMES_PATH}/POPS/$merged.VCD" >> "${LOG_FILE}"
                rm "${SCRIPTS_DIR}/tmp/${merged}.cue" "${SCRIPTS_DIR}/tmp/${merged}.bin"
                echo | tee -a "${LOG_FILE}"
            else
                echo "Skipping $(basename "$cue") because it has $bin_count BIN file(s)." >> "${LOG_FILE}"
                cd "${GAMES_PATH}/POPS"
                echo -n "Converting '$(basename "$cue")' to VCD..."
                "${CUE2POPS}" "$cue" "$vcd" >> "${LOG_FILE}" >> "${LOG_FILE}"
                echo | tee -a "${LOG_FILE}"
            fi
        done
    else
        echo "No PS1 .cue files to convert in ${GAMES_PATH}/POPS." | tee -a "${LOG_FILE}"
    fi
    cd "${TOOLKIT_PATH}"
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

    if [ "$title_id" = "SCPN-60160" ]; then
        content_type="0"
    fi

    title_id="${title_id//_/-}"
    title_id="${title_id//[^A-Za-z0-9-]/}"
    title_id="${title_id:0:11}"
    title_id="${title_id%-}"

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

create_system_cnf() {
    local file_name="$1"
    local title_id="$2"
    local arg="$3"

    title_id="${title_id//_/-}"
    title_id="${title_id//[^A-Za-z0-9-]/}"
    title_id="${title_id:0:11}"
    title_id="${title_id%-}"
    title_id="${title_id^^}"

    {
        echo "BOOT2 = PATINFO"
        echo "HDDUNITPOWER = NICHDD"
        echo "path = ata:$file_name"
        if [ -n "$arg" ]; then
            echo "arg = $arg"
        fi
        echo "titleid = $title_id"
    } > "$system_cnf"

    if [ -f "$system_cnf" ]; then
        echo "Created: $system_cnf"  | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Failed to create $system_cnf"
    fi
}

APP_ART() {
    local title_id="${title_id//[^A-Za-z0-9_-]/}"
    local title_id="${title_id:0:12}"
    local title_id="${title_id%-}"
    local title_id="${title_id^^}"

    case "$title_id" in
    OPL*|OPNPS2LD*)
        APP_ID="OPENPS2LOAD"
        ;;
    ULE*|ULAUNCH*)
        APP_ID="APP_ULE"
        ;;
    LAUNCHELF*|WLAUNCH*|WLE*)
        APP_ID="LAUNCHELF"
        ;;
    FREEMCBOOT*|FMC*)
        APP_ID="FREEMCBOOT"
        ;;
    GSM*)
        APP_ID="GSM"
        ;;
    ESR*)
        APP_ID="ESR"
        ;;
    *)
        APP_ID="$title_id"
        ;;
    esac

    png_file="${ARTWORK_DIR}/${APP_ID}.png"
    # Copy the matching PNG file from ART_DIR, or default to APP.png
    if [ -f "$png_file" ]; then
        if [ "$OS" = "PSBBN" ]; then
            cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
            echo "Created: $dir/jkt_001.png"  | tee -a "${LOG_FILE}"
        fi
        cp "$png_file" "${GAMES_PATH}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create ${GAMES_PATH}/ART/${elf}_COV.png. See ${LOG_FILE} for details."
        echo "Created: ${GAMES_PATH}/ART/${elf}_COV.png"  | tee -a "${LOG_FILE}"
    else
        echo "Artwork not found locally for $APP_ID. Attempting to download from the PSBBN art database..." | tee -a "${LOG_FILE}"
        wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
        "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/apps/${APP_ID}.png"
        
        if [[ -s "$png_file" ]]; then
            echo "[✓] Successfully downloaded artwork for $title_id" | tee -a "${LOG_FILE}"
            if [ "$OS" = "PSBBN" ]; then
                cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
                echo "Created: $dir/jkt_001.png"  | tee -a "${LOG_FILE}"
            fi
            cp "$png_file" "${GAMES_PATH}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create ${GAMES_PATH}/ART/${elf}_COV.png. See ${LOG_FILE} for details."
            echo "Created: ${GAMES_PATH}/ART/${elf}_COV.png"  | tee -a "${LOG_FILE}"
        else
            rm -f "$png_file"
            if [ "$OS" = "PSBBN" ]; then
                cp "$ARTWORK_DIR/APP.png" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
                echo "Created: $dir/jkt_001.png using default image."  | tee -a "${LOG_FILE}"
            fi
            echo "$title_id,$APP_ID,$elf" >> "${MISSING_APP_ART}"
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
    MAPPER="/dev/mapper/${DEVICE_CUT}-"
}

mount_cfs() {
  for PARTITION_NAME in "${LINUX_PARTITIONS[@]}"; do
    MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
    if [ -e "${MAPPER}${PARTITION_NAME}" ]; then
        [ -d "${MOUNT_PATH}" ] || mkdir -p "${MOUNT_PATH}"
        if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
            error_msg "Error" "Failed to mount ${PARTITION_NAME} partition."
        fi
    else
        error_msg "Error" "Partition ${PARTITION_NAME} not found on disk."
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
            error_msg "Error" "Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
        fi
    done
}

unmount_apa(){
# Unmount if mounted
    # Get all mounts under STORAGE_DIR
    submounts=$(findmnt -nr -o TARGET | grep "^${STORAGE_DIR}/" | sort -r)

    if [ -n "$submounts" ]; then
        echo "Found mounts under ${STORAGE_DIR}, attempting to unmount..." >> "$LOG_FILE"
        while read -r mnt; do
            [ -z "$mnt" ] && continue
            echo "Unmounting $mnt..." >> "$LOG_FILE"
            sudo umount "$mnt" || error_msg "Error" "Failed to unmount $mnt"
        done <<< "$submounts"
    fi

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        echo "Removing existing mapper $map_name..." >> "$LOG_FILE"
        if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
            error_msg "Error" "Failed to delete mapper $map_name."
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
    csv.writer(f, delimiter='|').writerows(non_jpn_rows)

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
        csv.writer(f, delimiter='|').writerows(jpn_rows)
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

SPLASH

DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

if [[ -z "$DEVICE" ]]; then
    error_msg "Error" "Unable to detect the PS2 drive. Please ensure the drive is properly connected." "You must install PSBBN or HDOSDMenu first before insalling games."
fi

echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

clean_up
sudo rm -f "${MISSING_ART}" "${MISSING_APP_ART}" "${MISSING_ICON}" "${MISSING_VMC}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to remove missing artwork files. See ${LOG_FILE} for details."
mkdir -p "${SCRIPTS_DIR}/tmp" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create tmp folder. See ${LOG_FILE} for details."

HDL_TOC
CHECK_PARTITIONS

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

MOUNT_OPL

rm -rf "${OPL}/bbnl"

if [ "$OS" = "PSBBN" ]; then
    psbbn_version=$(head -n 1 "${OPL}/version.txt" 2>/dev/null)

    # Compare using sort -V
    if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
        echo "Warning: Your PSBBN Definitive Patch version ($psbbn_version) is older than the required version ($version_check)."
        if (( $(echo "${psbbn_version:-0} < 2.11" | bc -l) )); then
            echo "Please select 'Install PSBBN' from the main menu to update."
        else
            echo "Please select 'Update PSBBN Software' from the main menu to update."
        fi
        echo
        read -n 1 -s -r -p "Press any key to return to the main menu..." </dev/tty
        exit 0
    fi
fi

APA_SIZE=$(awk -F' *= *' '$1=="APA_SIZE"{print $2}' "${OPL}/version.txt")
LANG=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")
echo "Language: $LANG" >> "${LOG_FILE}"

if [ -z "$APA_SIZE" ] || [ -z "$LANG" ]; then
    error_msg "Error" "Missing required value(s) in ${OPL}/version.txt"
fi

# Check for existing PS2 VMC .bin files on the drive
PS2_VMC_EXISTS=false
if find "${OPL}/VMC" -maxdepth 1 -name "*.bin" -print -quit 2>/dev/null | grep -q .; then
    PS2_VMC_EXISTS=true
fi

# Check for existing PS2 games on the OPL partition
PS2_GAMES_ON_OPL=false
if find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit 2>/dev/null | grep -q .; then
    PS2_GAMES_ON_OPL=true
fi

UNMOUNT_OPL

# Check if the Python virtual environment exists
if [ -f "./scripts/venv/bin/activate" ]; then
    echo "The Python virtual environment exists." >> "${LOG_FILE}"
elif [ -n "$IN_NIX_SHELL" ]; then
    echo "Running in Nix environment - The Python dependencies are managed by the flake." >> "${LOG_FILE}"
else
    error_msg "Error" "The Python virtual environment does not exist."
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

rm -f "${GAMES_PATH}/APPS/"{HDD-OSD.elf,PSBBN.ELF}

# Check if GAMES_PATH is custom
if [[ "${GAMES_PATH}" != "${TOOLKIT_PATH}/games" ]]; then
    echo "Using custom game path." >> "${LOG_FILE}"
    rm -f "${GAMES_PATH}/APPS/"{Launch-Disc.elf,HDD-OSD.elf,PSBBN.ELF}

    FILE="${GAMES_PATH}/APPS/BOOT.ELF"
    TARGET_MD5="20a5b2c1ffb86e742fb5705b5d9d7370"

    # Check if file exists
    if [[ -f "$FILE" ]]; then
        # Get md5 checksum
        FILE_MD5=$(md5sum "$FILE" | awk '{print $1}')

        # Compare and delete if matches
        if [[ "$FILE_MD5" == "$TARGET_MD5" ]]; then
            rm -f "$FILE"
            echo "Deleted $FILE (MD5 matched)" >> "${LOG_FILE}"
        else
            echo "MD5 does not match, file not deleted." >> "${LOG_FILE}"
        fi
    else
        echo "File not found: $FILE" >> "${LOG_FILE}"
    fi

    cp "${TOOLKIT_PATH}/games/APPS/"{APP_WLE-ISR-XF-MM.psu,SYS_OSDMENU-CONFIGURATOR.psu} "${GAMES_PATH}/APPS" >> "${LOG_FILE}" 2>&1
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
   ! find "${GAMES_PATH}/POPS" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" -o -iname "*.cue" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/CD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" -o -iname "*.bin" -o -iname "*.cue" \) -print -quit | grep -q . && \
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
    ps1_games=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" 2>/dev/null)
    if echo "$ps1_games" | grep -qi '\.vcd$'; then
        ps1_games_found=true
    fi
fi

# Check conditions for sync or copy
if { [ "$INSTALL_TYPE" = "sync" ] && find "${GAMES_PATH}/POPS" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" \) | grep -q .; } \
   || { [ "$INSTALL_TYPE" = "copy" ] && { find "${GAMES_PATH}/POPS" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" \) | grep -q . || [ "$ps1_games_found" = true ]; }; }; then
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

# Ask about PS2 VMCs if PS2 games exist
if find "${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit 2>/dev/null | grep -q . \
   || [[ "$PS2_GAMES_ON_OPL" == "true" ]]; then
    if [[ "$PS2_VMC_EXISTS" == "true" ]]; then
        PS2_VMC="y"
    else
        SPLASH
        echo "Would you like to use Virtual Memory Cards (VMCs) for PS2 games?"
        echo
        echo "Games that share save data will be assigned to the same VMC."
        echo
        while true; do
            read -p "Yes or No (y/n): " PS2_VMC
            case "$PS2_VMC" in
                [Yy]) PS2_VMC="y"; break ;;
                [Nn]) PS2_VMC="n"; break ;;
                *) echo; echo "Please enter y or n." ;;
            esac
        done
    fi
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
if [ "$PS2_VMC" = "y" ]; then
    echo "PS2 VMCs: Yes" | tee -a "${LOG_FILE}"
elif [ "$PS2_VMC" = "n" ]; then
    echo "PS2 VMCs: No" | tee -a "${LOG_FILE}"
fi
echo
read -n 1 -s -r -p "Press any key to continue..."
echo

prevent_sleep_start

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

mount_pfs
update_apps "OPL" "${ASSETS_DIR}/OPL/OPNPS2LD.ELF" "${STORAGE_DIR}/__system/launcher/OPNPS2LD.ELF" "-ut --progress"
update_apps "NHDDL" "${ASSETS_DIR}/NHDDL/nhddl.elf" "${STORAGE_DIR}/__system/launcher/nhddl.elf" "-ut --progress"
install_pops

################################### Synchronize & Copy PS1 Games ###################################

activate_python

# Rename .vcd to .VCD
for file in "${GAMES_PATH}/POPS"/*.vcd; do
    [ -e "$file" ] || continue  # skip if no match
    newfile="${file%.vcd}.VCD"
    mv -v -- "$file" "$newfile" >> "$LOG_FILE" 2>&1 || error_msg "Error" "Failed to rename $file."
done

echo  >> "${LOG_FILE}"
echo "Local POPS folder contents:" >> "${LOG_FILE}"
ls -l "${GAMES_PATH}/POPS/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "PS2 POPS partition contents:" >> "${LOG_FILE}"
ls -l "${STORAGE_DIR}/__.POPS/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

convert_vcd

if [ "$INSTALL_TYPE" = "sync" ]; then
    ps1_update=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${STORAGE_DIR}/__.POPS/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    ps1_update=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${STORAGE_DIR}/__.POPS/")
fi

# Set flag if any changes
if [ -n "$ps1_update" ]; then
    POPS_SIZE_CKECK
    echo | tee -a "${LOG_FILE}"
    echo "Total size of PS1 games to be synced: $needed_mb MB" | tee -a "${LOG_FILE}"
    echo "Available space: $available_mb MB" | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
    if [ "$INSTALL_TYPE" = "sync" ]; then
        rsync -dL --progress --delete --ignore-existing --include='*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${STORAGE_DIR}/__.POPS/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            error_msg "Error" "Failed to sync PS1 games."
        fi
    else
        rsync -dL --progress --ignore-existing --include='*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${STORAGE_DIR}/__.POPS/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            error_msg "Error" "Failed to copy PS1 games."
        fi
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "PS1 games are already up-to-date." | tee -a "${LOG_FILE}"
    sleep 3
fi

# Create games list of PS1 games to be installed
if find "${STORAGE_DIR}/__.POPS/" -maxdepth 1 -type f \( -iname "*.vcd" \) | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating PS1 games list..." | tee -a "${LOG_FILE}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${STORAGE_DIR}" "${PS1_LIST}" | tee -a "${LOG_FILE}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        error_msg "Error" "Failed to create PS1 games list."
    fi
fi

unmount_apa
sleep 2

################################### Synchronize & Copy PS2 Games ###################################

MOUNT_OPL

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

if [[ "$LAUNCHER" = "NEUTRINO" ]]; then
    convert_zso
fi

convert_bin

if [ "$INSTALL_TYPE" = "sync" ]; then
    cd=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/")
    dvd=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    cd=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/")
    dvd=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/")
fi

if [ -n "$cd" ] || [ -n "$dvd" ]; then
    OPL_SIZE_CKECK
    echo | tee -a "${LOG_FILE}"
    echo "Total size of PS2 games to be synced: $needed_mb MB" | tee -a "${LOG_FILE}"
    echo "Available space: $available_mb MB" | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
    if [ "$INSTALL_TYPE" = "sync" ]; then
        rsync -dL --progress --delete --ignore-existing --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        rsync -dL --progress --delete --ignore-existing --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check Synced
    else
        rsync -dL --progress --ignore-existing --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/CD/" "${OPL}/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        cd_status=${PIPESTATUS[0]}
        rsync -dL --progress --ignore-existing --include='*.iso' --include='*.ISO' --include='*.zso' --include='*.ZSO' --exclude='.*' --exclude='*' "${GAMES_PATH}/DVD/" "${OPL}/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        dvd_status=${PIPESTATUS[0]}
        ps2_rsync_check Copied
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "PS2 games are already up-to-date." | tee -a "${LOG_FILE}"
fi

# Create games list of PS2 games to be installed
if find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating PS2 games list..." | tee -a "${LOG_FILE}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${PS2_LIST}" | tee -a "${LOG_FILE}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        error_msg "Error" "Failed to create PS2 games list."
    fi
fi

# Sort games list
if [[ "$LANG" == "jpn" &&  -f "${PS1_LIST}" ]]; then
    sort_jpn "${PS1_LIST}" "$PS1_JPN_LIST"
fi

if [ -s "${PS1_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS1_LIST}" || error_msg "Error" "Failed to sort PS1 games list."
fi

if [ -s "${PS1_JPN_LIST}" ]; then
    cat "${PS1_JPN_LIST}" > "${TMP_LIST}"
    cat "${PS1_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
    cat "${TMP_LIST}" > "${PS1_LIST}"
fi

if [[ "$LANG" == "jpn" &&  -f "${PS2_LIST}" ]]; then
    sort_jpn "${PS2_LIST}" "$PS2_JPN_LIST"
fi

if [ -s "${PS2_LIST}" ]; then
    python3 "${HELPER_DIR}/list-sorter.py" "${PS2_LIST}" || error_msg "Error" "Failed to sort PS2 games list."
fi

if [ -s "${PS2_JPN_LIST}" ]; then
    cat "${PS2_JPN_LIST}" > "${TMP_LIST}"
    cat "${PS2_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
    cat "${TMP_LIST}" > "${PS2_LIST}"
fi

# Deactivate the virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
fi

# Create master list combining PS1 and PS2 games to a single list
if [[ ! -s "${PS1_LIST}" && ! -s "${PS2_LIST}" ]] && find "${GAMES_PATH}/CD" "${GAMES_PATH}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    error_msg "Error" "Failed to create games list."
fi

if [[ -s "${PS1_LIST}" ]] && [[ ! -s "${PS2_LIST}" ]]; then
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ ! -s "${PS1_LIST}" ]] && [[ -s "${PS2_LIST}" ]]; then
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ -s "${PS1_LIST}" ]] && [[ -s "${PS2_LIST}" ]]; then
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
fi

rm -f "${OPL}/ps1.list"

# Check for master.list
if [[ -s "${ALL_GAMES}" ]]; then
    # Count the number of games to be installed
    count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
    echo | tee -a "${LOG_FILE}"
    echo "Number of games to install: $count" | tee -a "${LOG_FILE}"
    echo
    echo "[✓] Games list successfully created."| tee -a "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    echo "master.list:" >> "${LOG_FILE}"
    cat "${ALL_GAMES}" >> "${LOG_FILE}"
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
echo -e "$COMMANDS" | sudo "${PFS_SHELL}" 2>&1 | grep -i '\.vcd$' >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "PS2 games on PS2 drive:" >> "${LOG_FILE}"
ls -1 "${OPL}/CD/" >> "${LOG_FILE}" 2>&1
ls -1 "${OPL}/DVD/" >> "${LOG_FILE}" 2>&1

################################### Synchronize & Copy Apps ###################################

update_apps "Neutrino" "${NEUTRINO_DIR}/" "${OPL}/neutrino/" "-rut --progress --delete --exclude='.*'"

if [ "$INSTALL_TYPE" = "sync" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Preparing to sync apps..." | tee -a "${LOG_FILE}"

    cd "${GAMES_PATH}/APPS/" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${GAMES_PATH}/APPS."
    process_psu_files "${GAMES_PATH}/APPS/"

    install_elf "${GAMES_PATH}"

    rsync -rut --progress --delete --prune-empty-dirs --include='*/' --include='*/**' --exclude='.*' --exclude='*Zone.Identifier' --exclude='*' "${GAMES_PATH}/APPS/" "${OPL}/APPS/" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed sync apps. See $LOG_FILE for details."

elif [ "$INSTALL_TYPE" = "copy" ]; then
    echo "Preparing to copy apps..." | tee -a "${LOG_FILE}"

    cd "${OPL}/APPS/" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${OPL}/APPS."
    process_psu_files "${GAMES_PATH}/APPS/"
    process_psu_files "${OPL}/APPS/"
    cd "${TOOLKIT_PATH}"

    rm -rf "${OPL}/APPS/PSBBN"
    install_elf "${GAMES_PATH}"
    install_elf "${OPL}"

    find "${GAMES_PATH}/APPS/" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} "${OPL}/APPS/" \; || error_msg "Error" "Failed copy apps. See $LOG_FILE for details."
fi

################################### Creating Assets ###################################

echo
echo -n "Preparing to create assets..."
echo | tee -a "${LOG_FILE}"

mkdir -p "${ICONS_DIR}/SAS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ICONS_DIR}/SAS."
mkdir -p "${ICONS_DIR}/APPS" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ICONS_DIR}/APPS."
mkdir -p "${ARTWORK_DIR}/tmp" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${ARTWORK_DIR}/tmp."
mkdir -p "${TOOLKIT_PATH}/icons/ico/tmp/vmc" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${TOOLKIT_PATH}/icons/ico/tmp/vmc."
mkdir -p "${TOOLKIT_PATH}/icons/ico/vmc" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${TOOLKIT_PATH}/icons/ico/tmp/vmc."

# Set maximum number of items for the Game Channel

if [ "$OS" = "PSBBN" ]; then
    pp_cap="798"
else
    pp_cap="799"
fi

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
        error_msg "Warning" "Insufficient space to create PP partitions for remaining SAS apps." " " "The first $pp_max apps will appear in the PSBBN Game Channel." "All apps will appear in OPL."
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

        [ ${#title} -gt 79 ] && title="${title:0:76}..."

        cat >> "${SAS_LIST}" <<EOL
$title,ata:/APPS/$title_id/$elf,$title_id
EOL

        if [ "$title_id" = "APP_WLE-ISR-" ]; then
            LAUNCHELF_INSTALLED="yes"
        fi

        # Generate the system.cnf file
        system_cnf="${dir}/system.cnf"
        create_system_cnf "/APPS/$title_id/$elf" "$title_id"

        # Generate the info.sys file
        info_sys_filename="${dir}/info.sys"
        create_info_sys "$title" "$title_id" "$publisher"

        APP_ART

        if [ "$title_id" = "SYS_OSDMENU-CONFIGURATOR" ]; then
            cp "$ARTWORK_DIR/OSDMENUCONF.png" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/jkt_001.png. See ${LOG_FILE} for details."
        fi

    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort)
    sort -t',' -k1,1 -f "${SAS_LIST}" -o "${SAS_LIST}"
fi

################################### Assets for ELF Files ###################################

pp_max=$(( pp_max - SAS_COUNT ))

echo "PP Max after SAS: $pp_max" >> "${LOG_FILE}"

APP_COUNT=0

for dir in "${SOURCE_DIR}"/*/; do
    [[ -d "$dir" ]] || continue

    # Stop if we've reached the max
    if [ "$APP_COUNT" -ge "$pp_max" ]; then
        error_msg "Warning" "Insufficient space to create PP partitions for remaining ELF files." " " "The first $pp_max apps will appear in the PSBBN Game Channel." "All apps will appear in OPL."
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

        info_sys_filename="$dir/info.sys"
        create_info_sys "$title" "$title_id" "$publisher"

        # Generate the icon.sys file
        icon_sys_filename="$dir/icon.sys"
        create_icon_sys "$title"

        cp "${ICONS_DIR}/ico/app.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
        echo "Created: $dir/list.ico" | tee -a "${LOG_FILE}"
        cp "${ICONS_DIR}/ico/app-del.ico" "$dir/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
        echo "Created: $dir/del.ico" | tee -a "${LOG_FILE}"

        APP_ART
        system_cnf="${dir}/system.cnf"
        create_system_cnf "/APPS/$(basename "$dir")/$elf" "$title_id"

        [ ${#title} -gt 79 ] && title="${title:0:76}..."

        cat >> "${ELF_LIST}" <<EOL
$title,ata:/APPS/$(basename "$dir")/$elf,$(basename "$dir")
EOL
    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
    sort -t',' -k1,1 -f "${ELF_LIST}" -o "${ELF_LIST}"
fi

################################### Assets for Games ###################################

if [ -f "$ALL_GAMES" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Downloading OPL artwork for games..."  | tee -a "${LOG_FILE}"

    # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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
                    echo | tee -a "${LOG_FILE}"
                    echo "[✓] Successfully downloaded OPL artwork for $game_id" | tee -a "${LOG_FILE}"
                else
                    echo | tee -a "${LOG_FILE}"
                    echo "[✓] Successfully downloaded some OPL artwork for $game_id, but missing: ${missing_files[*]}" | tee -a "${LOG_FILE}"
                fi
            else
                echo | tee -a "${LOG_FILE}"
                echo "Failed to download OPL artwork for $game_id" | tee -a "${LOG_FILE}"
            fi
        fi
    done
    exec 3<&-
else
    echo | tee -a "${LOG_FILE}"
    echo "No OPL artwork to download." | tee -a "${LOG_FILE}"
fi

if [ -f "$ALL_GAMES" ]; then
    GAME_COUNT=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
else
    GAME_COUNT="0"
fi

pp_max=$(( pp_max - APP_COUNT ))

if [ "$GAME_COUNT" -gt "$pp_max" ]; then
    error_msg "Warning" "Insufficient space to create PP partitions for remaining games." " " "The first $pp_max games will appear in the PSBBN Game Collection." "All PS2 games will appear in OPL/NHDDL."
    # Overwrite master.list with the first $pp_max lines
    head -n "$pp_max" "$ALL_GAMES" > "${ALL_GAMES}.tmp"
    mv "${ALL_GAMES}.tmp" "$ALL_GAMES" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to updated master.list."
    echo "Updated master.list:" >> "${LOG_FILE}"
    cat "$ALL_GAMES" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
fi

[ -f "$ALL_GAMES" ] && [ ! -s "$ALL_GAMES" ] && rm -f "$ALL_GAMES"

if [ -f "$ALL_GAMES" ]; then
    if [ "$OS" = "PSBBN" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Downloading PSBBN artwork for games..."  | tee -a "${LOG_FILE}"

        # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
        exec 3< "$ALL_GAMES"
        while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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
    fi

    echo | tee -a "${LOG_FILE}"
    echo "Downloading HDD-OSD icons for games:"  | tee -a "${LOG_FILE}"

    exec 3< "$ALL_GAMES"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do

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

    if [ -s "${PS1_LIST}" ]; then
        echo "Downloading VMC icons:"  | tee -a "${LOG_FILE}"

        exec 3< "${PS1_LIST}"
        while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
        echo | tee -a "${LOG_FILE}"
        echo "Processing $title..." 
        # Create a sub-folder named after the game_id
        game_dir="$ICONS_DIR/$game_id"
        mkdir -p "$game_dir" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create $dir."

        if [[ "$LANG" == "jpn" && -z "$jpn_title" ]]; then
            title=${title//"(disc 1)"/"（ディスク１）"}
            title=${title//"(disc 2)"/"（ディスク２）"}
            title=${title//"(disc 3)"/"（ディスク３）"}
            title=${title//"(disc 4)"/"（ディスク４）"}
            title=${title//"(disc 5)"/"（ディスク５）"}
            title=${title//"(disc 6)"/"（ディスク６）"}
            title=${title//"(Taikenban)"/"（体験版）"}
        fi

        if [ "$OS" = "PSBBN" ]; then
            # Generate the info.sys file
            info_sys_filename="$game_dir/info.sys"
            if [[ "$LANG" == "jpn" && -n "$jpn_title" ]]; then
                jpn_title=$(normalize_roman_numerals "$jpn_title")
                create_info_sys "$jpn_title" "$game_id" "$publisher"
            else
                create_info_sys "$title" "$game_id" "$publisher"
            fi
        fi

        # Generate the icon.sys file
        if [[ "$LANG" == "jpn" ]]; then
            jpn_title=$(normalize_roman_numerals "$jpn_title")
            bottom_line=""

            if [[ -n "$jpn_title" ]]; then
                game_title_icon="$jpn_title"
            else
                game_title_icon="$title"
            fi

            case "$game_title_icon" in
            *"（体験版）"*|*"（ディスク１）"*|*"（ディスク２）"*|*"（ディスク３）"*|*"（ディスク４）"*|*"（ディスク５）"*|*"（ディスクク６）"*)
                bottom_line="（${game_title_icon##*（}"
                game_title_icon="${game_title_icon%（*}"
                ;;
            esac

            if [[ -n "$jpn_title" ]]; then
                if [ ${#game_title_icon} -gt 16 ]; then
                    game_title_icon="${game_title_icon:0:13}..."
                fi
            else
                if [ ${#game_title_icon} -gt 48 ]; then
                    game_title_icon="${game_title_icon:0:45}..."
                fi
            fi

            if [[ -n "$bottom_line" ]]; then
                publisher="$bottom_line"
            fi

        else
            game_title_icon="$title"
            if [ ${#game_title_icon} -gt 48 ]; then
                game_title_icon="${game_title_icon:0:45}..."
            fi
        fi

        icon_sys_filename="$game_dir/icon.sys"
        create_icon_sys "$game_title_icon" "$publisher"

        if [ "$OS" = "PSBBN" ]; then
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
        # Generate the system.cnf files
        # Determine the launcher value for this specific game
        if [[ "$disc_type" == "POPS" ]]; then
            launcher_value="POPS"
        else
            launcher_value="$LAUNCHER"
        fi

        if [ "$launcher_value" = "OPL" ]; then
            cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/OPNPS2LD.ELF
titleid = $game_id
nohistory = 1
arg = $file_name
arg = $game_id
arg = $disc_type
arg = bdm
skip_argv0 = 0
EOL
        elif [ "$launcher_value" = "NEUTRINO" ]; then
            cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/nhddl.elf
titleid = $game_id
arg = -mode=ata
arg = -dvd=mass0:/$disc_type/$file_name
arg = -noinit
skip_argv0 = 0
EOL
        elif [ "$launcher_value" = "POPS" ]; then
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
        fi

    echo "Created: system.cnf for $game_id"  | tee -a "${LOG_FILE}"

    done
    exec 3<&-

else
    echo | tee -a "${LOG_FILE}"
    echo "No games to process." | tee -a "${LOG_FILE}"
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

# Create PS2 VMCs if enabled
if [ "$PS2_VMC" = "y" ] && [ -s "${PS2_LIST}" ]; then
    CREATE_PS2_VMC
fi

echo | tee -a "${LOG_FILE}"
echo "All assets have been sucessfully created." | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

echo -n "Unmounting OPL partition..." | tee -a "${LOG_FILE}"
UNMOUNT_OPL
sleep 2
echo | tee -a "${LOG_FILE}"
mount_pfs

if [ "$OS" = "PSBBN" ]; then
    mapper_probe
    mount_cfs
fi

if [ -s "${PS1_LIST}" ]; then
    CREATE_VMC
fi

if [ "$OS" = "PSBBN" ]; then
    echo | tee -a "${LOG_FILE}"
    echo -n "Updating shortcuts in Navigator Menu..." | tee -a "${LOG_FILE}"
    echo >> "${LOG_FILE}"

    sudo mkdir -p "${STORAGE_DIR}/__linux.7/bn/sysconf"
    sudo cp "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0" "${SCRIPTS_DIR}/tmp" >> "${LOG_FILE}" 2>&1

    TARGET="${SCRIPTS_DIR}/tmp/shortcut_0"
    TMP_FILE=$(mktemp ${SCRIPTS_DIR}/tmp/shortcut_0.XXXXXX)

    # If TARGET exists, remove lines containing PP.LAUNCHER and PP.LAUNCHELF
    if [ -f "$TARGET" ]; then
        sudo sed -i '/PP\.LAUNCHER/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.APP_WLE-ISR/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        sudo sed -i '/PP\.HOSDMENU\.HIDDEN/d' "$TARGET" >> "${LOG_FILE}" 2>&1
    fi

    # Count lines in TARGET (0 if doesn't exist)
    if [ -f "$TARGET" ]; then
        LINE_COUNT=$(sudo wc -l "$TARGET" | awk '{print $1}')
    else
        LINE_COUNT=0
    fi

    # If TARGET has less than 4 rows
    if [ "$LINE_COUNT" -lt 4 ]; then
        if [ "$LAUNCHER" = "OPL" ]; then
            echo "Open%20PS2%20Loader file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.LAUNCHER" > "$TMP_FILE"
        elif [ "$LAUNCHER" = "NEUTRINO" ]; then
            echo "NHDDL file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.LAUNCHER" > "$TMP_FILE"
        fi
    fi

    if [ $((LINE_COUNT + 1)) -lt 4 ] && [ "$LAUNCHELF_INSTALLED" = "yes" ]; then
        echo "wLaunchELF_isr file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.APP_WLE-ISR-" >> "$TMP_FILE"
    fi

    if [ $((LINE_COUNT + 2)) -lt 4 ]; then
        echo "HOSDMenu file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.HOSDMENU.HIDDEN" >> "$TMP_FILE"
    fi

    # Append TMP_FILE to TARGET
    sudo tee -a "$TARGET" < "$TMP_FILE" > /dev/null


    # Replace TARGET with updated version
    sudo cp -f "$TARGET" "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo -n "Updating HOSDMenu app list..." | tee -a "${LOG_FILE}"

cat "${ELF_LIST}" > "${APPS_LIST}" 2>> "${LOG_FILE}"
cat "${SAS_LIST}" >> "${APPS_LIST}" 2>> "${LOG_FILE}"

cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" "${OSDMENU_CNF}"
sed -i '/^name_OSDSYS_ITEM/d; /^path/d; /^arg_OSDSYS_ITEM/d;' "$OSDMENU_CNF"

if [ "$LAUNCHER" = "OPL" ]; then
    {
        echo "name_OSDSYS_ITEM_1 = Open PS2 Loader"
        echo "path1_OSDSYS_ITEM_1 = hdd0:__system/launcher/OPNPS2LD.ELF"
        echo "arg_OSDSYS_ITEM_1 = -titleid=OPNPS2LD"
    } >> "$OSDMENU_CNF"
elif [ "$LAUNCHER" = "NEUTRINO" ]; then
    {
        echo "name_OSDSYS_ITEM_1 = NHDDL"
        echo "path1_OSDSYS_ITEM_1 = hdd0:__system/launcher/nhddl.elf"
        echo "arg_OSDSYS_ITEM_1 = -mode=ata"
        echo "arg_OSDSYS_ITEM_1 = -titleid=NHDDL"
    } >> "$OSDMENU_CNF"
fi

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
while IFS=',' read -r title elf title_id; do
  # Skip empty lines
  [ -z "$title" ] && continue

  # Stop at 200 items
  [ "$item" -gt "$max_items" ] && break

  {
    echo "name_OSDSYS_ITEM_${item} = ${title}"
    echo "path1_OSDSYS_ITEM_${item} = ${elf}"
    echo "arg_OSDSYS_${item} = -titleid=${title_id}"
  } >> "$OSDMENU_CNF"

  ((item++))
done < "$APPS_LIST"

cp -f "${OSDMENU_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF"

echo | tee -a "${LOG_FILE}"

unmount_apa

################################### Create Launcher Partitions ###################################

if find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo "Creating Launcher Partitions for SAS Apps:" | tee -a "${LOG_FILE}"

    while IFS= read -r dir; do

        folder_name=$(basename "$dir")
        pp_name="PP.${folder_name:0:29}"

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            error_msg "Warning" "Insufficient space for another partition."
            break
        fi

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart $pp_name 8M PFS\n"
        if [ "$OS" = "PSBBN" ]; then
            COMMANDS+="mount $pp_name\n"
            COMMANDS+="mkdir res\n"
            COMMANDS+="cd res\n"
            COMMANDS+="lcd '${ICONS_DIR}/SAS/$folder_name'\n"
            COMMANDS+="put info.sys\n"
            COMMANDS+="put jkt_001.png\n"
            COMMANDS+="cd /\n"
            COMMANDS+="umount\n"
        fi
        COMMANDS+="exit"

        PFS_COMMANDS
        cd "${ICONS_DIR}/SAS/$folder_name" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/SAS/$folder_name."
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of $pp_name"
        echo "Created $pp_name" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

if find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo | tee -a "${LOG_FILE}"
    echo "Creating Launcher Partitions for ELF files:" | tee -a "${LOG_FILE}"

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
        if [ "$OS" = "PSBBN" ]; then
            COMMANDS+="mount $pp_name\n"
            COMMANDS+="mkdir res\n"
            COMMANDS+="cd res\n"
            COMMANDS+="lcd '${ICONS_DIR}/APPS/$folder_name'\n"
            COMMANDS+="put info.sys\n"
            COMMANDS+="put jkt_001.png\n"
            COMMANDS+="cd /\n"
            COMMANDS+="umount\n"
        fi
        COMMANDS+="exit"

        PFS_COMMANDS

        cd "${ICONS_DIR}/APPS/$folder_name" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/APPS/$folder_name."
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of $pp_name."
        echo "Created $pp_name" | tee -a "${LOG_FILE}"

    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

if [ "$OS" = "PSBBN" ]; then
    # Create PP.SCPN_601.60.PSBBN
    echo | tee -a "${LOG_FILE}"

    APA_SIZE_CHECK

    # Check the value of available
    if [ "$available" -lt 8 ]; then
        error_msg "Warning" "Insufficient space for another partition."
    else
        mkdir -p "${ICONS_DIR}/PSBBN"
        cp "${ICONS_DIR}/ico/psbbn.ico" "${ICONS_DIR}/PSBBN/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
        cp "${ICONS_DIR}/ico/psbbn-del.ico" "${ICONS_DIR}/PSBBN/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."

        cat > "${ICONS_DIR}/PSBBN/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/p2lboot/osdboot.elf
titleid = SCPN-60160
EOL

        info_sys_filename="${ICONS_DIR}/PSBBN/info.sys"
        icon_sys_filename="${ICONS_DIR}/PSBBN/icon.sys"
        title="BB Navigator"
        title_id="SCPN-60160"
        publisher="Sony Computer Entertainment"

        create_info_sys "$title" "$title_id" "$publisher"
        create_icon_sys "$title" "$publisher"
    
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart PP.SCPN_601.60.PSBBN 8M PFS\n"
        COMMANDS+="mount PP.SCPN_601.60.PSBBN\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/PSBBN'\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        echo >> "${LOG_FILE}"
        PFS_COMMANDS

        cd "${ICONS_DIR}/PSBBN"

        sudo "${HDL_DUMP}" modify_header "${DEVICE}" PP.SCPN_601.60.PSBBN >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of PP.SCPN_601.60.PSBBN."
        echo "Created PP.SCPN_601.60.PSBBN" | tee -a "${LOG_FILE}"
    fi

    # Create PP.HOSDMENU.HIDDEN
    APA_SIZE_CHECK

    # Check the value of available
    if [ "$available" -lt 8 ]; then
        error_msg "Warning" "Insufficient space for another partition."
    else
        mkdir -p "${ICONS_DIR}/HOSDMENU"
        cp "${ICONS_DIR}/ico/app.ico" "${ICONS_DIR}/HOSDMENU/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."

        cat > "${ICONS_DIR}/HOSDMENU/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/osdmenu/hosdmenu.elf

EOL

        info_sys_filename="${ICONS_DIR}/HOSDMENU/info.sys"
        icon_sys_filename="${ICONS_DIR}/HOSDMENU/icon.sys"
        title="HOSDMenu"
        title_id="OSDMenu"
        publisher="github.com/pcm720"

        create_info_sys "$title" "$title_id" "$publisher"
        create_icon_sys "$title" " "
    
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart PP.HOSDMENU.HIDDEN 8M PFS\n"
        COMMANDS+="mount PP.HOSDMENU.HIDDEN\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/HOSDMENU'\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="lcd '${ARTWORK_DIR}'\n"
        COMMANDS+="put HOSDMENU.png\n"
        COMMANDS+="rename HOSDMENU.png jkt_001.png\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        echo >> "${LOG_FILE}"
        PFS_COMMANDS

        cd "${ICONS_DIR}/HOSDMENU"

        sudo "${HDL_DUMP}" modify_header "${DEVICE}" PP.HOSDMENU.HIDDEN >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of PP.HOSDMENU.HIDDEN"
        echo "Created PP.HOSDMENU.HIDDEN" | tee -a "${LOG_FILE}"
    fi
fi

# Create PP.LAUNCHER
APA_SIZE_CHECK

# Check the value of available
if [ "$available" -lt 8 ]; then
    error_msg "Warning" "Insufficient space for another partition."
else

    mkdir -p "${ICONS_DIR}/LAUNCHER"

    info_sys_filename="${ICONS_DIR}/LAUNCHER/info.sys"
    icon_sys_filename="${ICONS_DIR}/LAUNCHER/icon.sys"

    if [ "$LAUNCHER" = "OPL" ]; then
        cp "${ICONS_DIR}/ico/opl.ico" "${ICONS_DIR}/LAUNCHER/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
        cp "${ICONS_DIR}/ico/opl-del.ico" "${ICONS_DIR}/LAUNCHER/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
        title="Open PS2 Loader"
        title_id="OPNPS2LD"
        publisher="github.com/ps2homebrew"

        cat > "${ICONS_DIR}/LAUNCHER/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/OPNPS2LD.ELF
titleid = OPNPS2LD
EOL

    elif [ "$LAUNCHER" = "NEUTRINO" ]; then
        cp "${ICONS_DIR}/ico/nhddl.ico" "${ICONS_DIR}/LAUNCHER/list.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/list.ico. See ${LOG_FILE} for details."
        cp "${ICONS_DIR}/ico/nhddl-del.ico" "${ICONS_DIR}/LAUNCHER/del.ico" 2>> "${LOG_FILE}" || error_msg "Error" "Failed to create $dir/del.ico. See ${LOG_FILE} for details."
        title="NHDDL"
        title_id="NHDDL"
        publisher="github.com/pcm720"

        cat > "${ICONS_DIR}/LAUNCHER/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/nhddl.elf
titleid = NHDDL
arg = -mode=ata
EOL

    fi

    create_info_sys "$title" "$title_id" "$publisher"
    create_icon_sys "$title" " "

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart PP.LAUNCHER 8M PFS\n"
    if [ "$OS" = "PSBBN" ]; then
        COMMANDS+="mount PP.LAUNCHER\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/LAUNCHER'\n"
        COMMANDS+="put info.sys\n"
        if [ "$LAUNCHER" = "OPL" ]; then
            COMMANDS+="lcd '${ARTWORK_DIR}'\n"
            COMMANDS+="put OPENPS2LOAD.png\n"
            COMMANDS+="rename OPENPS2LOAD.png jkt_001.png\n"
            COMMANDS+="cd /\n"
        elif [ "$LAUNCHER" = "NEUTRINO" ]; then
            COMMANDS+="lcd '${ARTWORK_DIR}'\n"
            COMMANDS+="put NHDDL.png\n"
            COMMANDS+="rename NHDDL.png jkt_001.png\n"
            COMMANDS+="cd /\n"
        fi
        COMMANDS+="umount\n"
    fi
    COMMANDS+="exit"

    echo >> "${LOG_FILE}"
    PFS_COMMANDS

    cd "${ICONS_DIR}/LAUNCHER"

    sudo "${HDL_DUMP}" modify_header "${DEVICE}" PP.LAUNCHER >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of PP.LAUNCHER."
    echo "Created PP.LAUNCHER" | tee -a "${LOG_FILE}"
fi

if [ -f "$ALL_GAMES" ]; then

    # Read all lines in reverse order
    mapfile -t reversed_lines < <(tac "$ALL_GAMES")

    echo | tee -a "${LOG_FILE}"
    echo "Creating Launcher Partitions for Games:" | tee -a "${LOG_FILE}"
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
        if [ "$OS" = "PSBBN" ]; then
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
                COMMANDS+="lcd '${ASSETS_DIR}/POPStarter/$LANG'\n"
                COMMANDS+="put 1.png\n"
                COMMANDS+="put 2.png\n"
                COMMANDS+="put man.xml\n"
            fi

            COMMANDS+="umount\n"
        fi
        COMMANDS+="exit\n"

        PFS_COMMANDS

        cd "${ICONS_DIR}/$game_id" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to navigate to ${ICONS_DIR}/$game_id."
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "${PARTITION_LABEL}" >> "${LOG_FILE}" 2>&1 || error_msg "Error" "Failed to modify header of ${PARTITION_LABEL}."
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

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
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
POPSTARTER="${ASSETS_DIR}/POPStarter/POPSTARTER.ELF"
POPS_DIR="${ICONS_DIR}/POPS"
POP_FIXES="${ASSETS_DIR}/Hugopocked POPStarter Fixes (2023-08-11)/POPS Game Fixes"
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
PFS_POPS_LIST="${SCRIPTS_DIR}/tmp/pfs-pops.list"
ATA_POPS_LIST="${SCRIPTS_DIR}/tmp/ata-pops.list"
PS1_LIST="${SCRIPTS_DIR}/tmp/ps1.list"
PS1_JPN_LIST="${SCRIPTS_DIR}/tmp/ps1-jpn.list"
PS2_LIST="${SCRIPTS_DIR}/tmp/ps2.list"
PS2_JPN_LIST="${SCRIPTS_DIR}/tmp/ps2-jpn.list"
SMB_POPS_LIST="${SCRIPTS_DIR}/tmp/smb-pops.list"
POPS_JPN_LIST="${SCRIPTS_DIR}/tmp/pops-jpn.list"
TMP_LIST="${SCRIPTS_DIR}/tmp/tmp.list"
ALL_GAMES="${SCRIPTS_DIR}/tmp/master.list"
ELF_LIST="${SCRIPTS_DIR}/tmp/elf.list"
SAS_LIST="${SCRIPTS_DIR}/tmp/sas.list"
APPS_LIST="${SCRIPTS_DIR}/tmp/app.list"
PS1_DATABASE="${ASSETS_DIR}/database/TitlesDB_PS1.csv"
OSDMENU_CNF="${SCRIPTS_DIR}/tmp/OSDMENU.CNF"
OSDMBR_CNF="${SCRIPTS_DIR}/tmp/OSDMBR.CNF"

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
        echo "https://github.com/CosmicScale/PSBBN-Definitive-Project#troubleshooting"
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
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
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
    mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,POPS,nhddl} 2>>"${LOG_FILE}" || {
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

POPS_PATCH_DL() {
    wget -O "$ASSETS_DIR/Hugopocked_POPStarter_Fixes.rar" "$(
        wget -qO- 'https://www.mediafire.com/file/rznkr05pci45w5p/Hugopocked_POPStarter_Fixes_%25282023-08-11%2529.rar/file' \
        | grep -o 'https://download[^"]*Hugopocked+POPStarter+Fixes+%282023-08-11%29.rar' | head -n1)"

    unrar-free x "${ASSETS_DIR}/Hugopocked_POPStarter_Fixes.rar" "$ASSETS_DIR"
}

CREATE_PS1_VMC() {

    declare -A disc_groups
    declare -A first_disc_folder
    declare -A vmc_groups_by_id
    current_group=""
    vmc_count="0"

    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating VMCs for PS1 games and applying Hugopocked POPStarter fixes..." >> "${LOG_FILE}"
    echo "${UI_TEXT[CREATE_PS1_VMC]}"
    if ! mkdir -p "${POPS_DIR}"; then
        echo "[X] Error: Failed to create VMC folder." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE_PS1_VMC]}"
    fi

    # First pass: Group file names by base title
    exec 3< "${ATA_POPS_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"  # Remove trailing space
        disc_groups["$base_title"]+="$title|$file_name"$'\n'
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

    # Second pass: Create folders, DISCS.TXT, and VMCDIR.TXT
    exec 3< "$ATA_POPS_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
        folder_name="${file_name%.*}"
        base_title="${title%%(Disc*}"
        base_title="${base_title%" "}"
        mkdir -p "${POPS_DIR}/$folder_name"
        cd "${POPS_DIR}/$folder_name"

        if [ -d "$ASSETS_DIR/Hugopocked POPStarter Fixes (2023-08-11)" ]; then
            patch_path=""
        
            while IFS= read -r line; do
                if [[ "$line" == /* ]]; then
                    patch_folder="${line#/}"
                    patch_path="$POP_FIXES/$patch_folder"
                elif [[ "$line" == "$game_id" ]]; then
                    echo "Applying patches for $game_id from $patch_folder" >> "${LOG_FILE}"
                    cp -nv "$patch_path"/*.BIN . >> "${LOG_FILE}" 2>&1
                    break
                fi
            done < ${ASSETS_DIR}/database/POP-game-fixes.list
        else
            echo
            echo "[X] Warning: Hugopocked POPStarter Fixes not present." >> "${LOG_FILE}"
        fi

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
                #cd "${POPS_DIR}/$VMC_GROUP_FOLDER"
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
                #cd "${POPS_DIR}/$VMC_GROUP_FOLDER"
                printf "%s" "${vmc_groups_by_id[$game_id]}" > "${POPS_DIR}/$folder_name/VMCDIR.TXT"
            fi
        fi
        vmc_count=$((vmc_count + 1))
        show_progress "$vmc_count" "$ata_pops_count"
    done
    cd "${TOOLKIT_PATH}"
    exec 3<&-

    cp -rf "${POPS_DIR}/${VMC_FOLDER}/"* "${OPL}/POPS"
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
            return 1
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
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do

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
        if [[ ! -f "${OPL}/VMC/${vmc_file}" && ! -f "${OPL}/VMC/${vmc_name%_0}.bin" ]] && [[ -z "${created_vmcs[$vmc_name]}" ]]; then

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

        i=$((i + 1))
        show_progress "$i" "$ps2_count"
    done
    exec 3<&-
}

DISABLE_PS2_VMC() {
    # Remove VMC entries from all CFG files
    for cfg_file in "${OPL}/CFG/"*.cfg; do
        [[ -e "$cfg_file" ]] || continue

        tmp="${cfg_file}.tmp"
        sed '/^\$VMC_0/d' "$cfg_file" > "$tmp" && mv "$tmp" "$cfg_file"
    done

    # Remove mc0 entries from all NHDDL YAML files
    for yaml_file in "${OPL}/nhddl/"*.yaml; do
        [[ -e "$yaml_file" ]] || continue

        tmp="${yaml_file}.tmp"
        sed '/^mc0:/d' "$yaml_file" > "$tmp" && mv "$tmp" "$yaml_file"
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
        pops_size=$(rsync -dL --progress --ignore-existing --dry-run --out-format="%l" --include='[^.]*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/{POPS}/" | awk '{s+=$1} END {printf "%.0f\n", s / (1024*1024)}')
        needed_mb=$((cd_size + dvd_size + pops_size))
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

    if [[ "$name" == "NHDDL" || "$name" == "OPL" || "$name" == "POPStarter" ]]; then
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

install_pops() {
    if [ -d "${OPL}/POPS" ] && [ -f "${OPL}/POPS/POPS_IOX.PAK" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "POPS binaries are already installed." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_POPS_1]}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Checking for POPS binaries..." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_POPS_2]}"
    
    # Check POPS files exist
        if [[ -f "${ASSETS_DIR}/POPS-binaries-main/POPS_IOX.PAK" ]]; then
            echo | tee -a "${LOG_FILE}"
            echo "POPS_IOX.PAK exist in ${ASSETS_DIR}." >> "${LOG_FILE}"
            echo "Skipping download." >> "${LOG_FILE}"
        else
            echo "Checking if ${ASSETS_DIR}/POPS-binaries-main.zip exists..." >> "${LOG_FILE}"
            # Check if POPS-binaries-main.zip exists
            if [[ -f "${ASSETS_DIR}/POPS-binaries-main.zip" && ! -f "${ASSETS_DIR}/POPS-binaries-main.zip.st" ]]; then
                echo | tee -a "${LOG_FILE}"
                echo "POPS-binaries-main.zip found in ${ASSETS_DIR}. Extracting..." >> "${LOG_FILE}"
                if ! unzip -o "${ASSETS_DIR}/POPS-binaries-main.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1; then
                    echo "[!] Warning: Failed to extract POPS binaries." >> "${LOG_FILE}"
                    error_msg "Warning" "${UI_TEXT[WARN_INSTALL_POPS_1]}"
                fi
            else
                echo | tee -a "${LOG_FILE}"
                echo "Downloading POPS binaries..." >> "${LOG_FILE}"
                echo "${UI_TEXT[INSTALL_POPS_3]}"
                if ! axel -a https://archive.org/download/pops-binaries-PS2/POPS-binaries-main.zip -o "${ASSETS_DIR}"; then
                    echo "[!] Warning: Failed to download POPS binaries." >> "${LOG_FILE}"
                    error_msg "Warning" "Failed to download POPS binaries."
                fi
                if ! unzip -o "${ASSETS_DIR}/POPS-binaries-main.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1; then
                    error_msg "Warning" "${UI_TEXT[WARN_INSTALL_POPS_2]}"
                fi
            fi
            # Check if POPS_IOX.PAK exist after extraction
            if [[ -f "${ASSETS_DIR}/POPS-binaries-main/POPS_IOX.PAK" ]]; then
                echo | tee -a "${LOG_FILE}"
                echo "[✓] POPS binaries successfully extracted." >> "${LOG_FILE}"
            else
                echo "[!] Warning: POPS binaries are missing. PS1 games will not be playable." >> "${LOG_FILE}"
                error_msg "Warning" "${UI_TEXT[WARN_INSTALL_POPS_3]}"
            fi
        fi

        echo | tee -a "${LOG_FILE}"
        echo "Installing POPS binaries..." >> "${LOG_FILE}"

        if cp "${ASSETS_DIR}/POPS-binaries-main/POPS_IOX.PAK" "${OPL}/POPS"; then
            echo | tee -a "${LOG_FILE}"
            echo "[✓] POPS binaries successfully installed." >> "${LOG_FILE}"
            echo "[✓] ${UI_TEXT[INSTALL_POPS_4]}"
        else
            echo "[!] Warning: POPS binaries are missing. PS1 games will not be playable." >> "${LOG_FILE}"
            error_msg "Warning" "${UI_TEXT[WARN_INSTALL_POPS_3]}"
        fi
    fi

    if { [ ! -f "${OPL}/POPS/IGR_BG.TM2" ] || [ ! -f "${OPL}/POPS/IGR_YES.TM2" ] || [ ! -f "${OPL}/POPS/IGR_NO.TM2" ]; } && [[ "$lang" != "JPN" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "Copying POPS IRG files..." >> "${LOG_FILE}"
        cp -f "${ASSETS_DIR}/POPStarter/$lang/"{IGR_BG.TM2,IGR_YES.TM2,IGR_NO.TM2} "${OPL}/POPS"  >> "${LOG_FILE}" 2>&1
    else
        echo "POPS IGR files already exist." >> "${LOG_FILE}"
    fi

    if [ ! -f "${OPL}/POPS/POPSTARTER.ELF" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Installing POPStarter..." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_POPS_5]}"
        cp -f "${POPSTARTER}" "${OPL}/POPS/POPSTARTER.ELF" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to copy POPSTARTER.ELF."  >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_INSTALL_POPS]}"
        }
    else
        echo "POPStarter is already installed." >> "${LOG_FILE}"
    fi
}

install_elf() {

    local dir=$1

    # Check if any ELF files exist in the source directory

    elf_count=$(find "${dir}/APPS" -maxdepth 1 -type f -iname "*.elf" | wc -l)

    if [ "$elf_count" -eq 0 ]; then
        echo "No ELF files to install in: ${dir}/APPS" >> "${LOG_FILE}"
    else
        SPLASH
        echo "Processing ELF files in: ${dir}/APPS/..." >> "${LOG_FILE}"
        echo "${UI_TEXT[INSTALL_ELF]}"
        i="0"
        for file in "${dir}/APPS/"*.elf "${dir}/APPS/"*.ELF; do
            [ -e "$file" ] || continue  # Skip if no ELF files exist
            # Extract filename without path and extension
            elf=$(basename "$file")
            elf_no_ext="${elf%.*}"

            echo "Installing ${dir}/APPS/$elf..." >> "${LOG_FILE}"

            app_name="${elf_no_ext%%(*}" # Remove anything after an open bracket '('
            app_name="${app_name%%[Vv][0-9]*}" # Remove versioning (e.g., v12 or V12)
            app_name=$(echo "$app_name" | sed -E 's/[cC][oO][mM][pP][rR][eE][sS][sS][eE][dD].*//') # Remove "compressed"
            app_name=$(echo "$app_name" | sed -E 's/[pP][aA][cC][kK][eE][dD].*//') # Remove "packed"
            app_name=$(echo "$app_name" | sed 's/\.*$//') # Trim trailing full stops

            AppDB_check=$(echo "$app_name" | sed 's/[ _-]//g' | tr 'a-z' 'A-Z')

            # Check $ASSETS_DIR/database/AppDB.csv for match in first column to $AppDB_check, set $title based on second column from file if found. If no match found, set $title with the remaining code
            match=$(awk -F'|' -v key="$AppDB_check" '$1 && index(key, $1) == 1 {print $2; exit}' "${ASSETS_DIR}/database/AppDB.csv")

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
title=$title
boot=$elf
Title=$title
CfgVersion=8
Developer=
Genre=Homebrew
EOL
            i=$((i + 1))
            show_progress "$i" "$elf_count"
        done
    fi
}

convert_zso() {
    if [[ "$INSTALL_TYPE" == "sync" ]]; then
        search_dirs=("${GAMES_PATH}/CD" "${GAMES_PATH}/DVD")
    else
    # Remove duplicate ZSO files from OPL if the same game exists in GAMES_PATH
        for dir in CD DVD; do
            find "${OPL}/${dir}" -type f ! -path '*/.*' -iname '*.zso' -print0 |
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

    # Only run if .zso files exist
    if find "${search_dirs[@]}" -type f ! -path '*/.*' -iname "*.zso" | grep -q .; then
        SPLASH
        printf '\033[1A'
        echo "[!] Warning: Games in the compressed ZSO format have been found. NHDDL does not support compressed ZSO files." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARM_CONVERT_ZSO_1]}" "${UI_TEXT[WARM_CONVERT_ZSO_2]}" " " "${UI_TEXT[WARM_CONVERT_ZSO_3]}"
        SPLASH
        echo "${UI_TEXT[CONVERT_ZSO]}"
        # Convert ZSO to ISO
        while IFS= read -r -d '' zso_file; do
            iso_file="${zso_file%.*}.iso"

            echo "${UI_TEXT[CONVERTING]} $zso_file -> $iso_file" >> "${LOG_FILE}"
            echo "${UI_TEXT[CONVERTING]} $zso_file -> $iso_file"

            python3 -u "${HELPER_DIR}/ziso.py" -c 0 "$zso_file" "$iso_file" | tee -a "${LOG_FILE}"
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                rm -f "$iso_file"
                echo "[X] Error: Failed to uncompress $zso_file" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_CONVERT_ZSO]} $zso_file"
            fi

            rm -f "$zso_file"
        done < <(find "${search_dirs[@]}" -type f ! -path '*/.*' -iname "*.zso" -print0)
    fi
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

convert_vcd(){
    SPLASH
    # Check if any .cue files exist
    cue_count=$(find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f ! -path '*/.*' -iname "*.cue" | wc -l)
    if [ "$cue_count" -gt 0 ]; then
        # Loop over all .cue files in the folder
        i="0"
        echo "Converting BIN/CUE files to VCD..." >> "${LOG_FILE}"
        echo "${UI_TEXT[CONVERT_VCD_1]}"
        show_progress "$i" "$cue_count"
        while IFS= read -r -d '' cue; do
            base="${cue%.[cC][uU][eE]}"        # Full path minus .cue
            vcd="${base}.VCD"
            merged="$(basename "$cue" .cue)"

            if [[ -f "$vcd" ]] || [[ -f "${OPL}/POPS/$(basename "${cue%.*}").VCD" ]]; then
                echo "Skipping. VCD already exists: '$(basename "$cue")'" >> "${LOG_FILE}"
                i=$((i + 1))
                show_progress "$i" "$cue_count"
                continue
            fi

            # Count all .bin files starting with the same base name
            bin_count=$(find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f -iname "$(basename "$base")*.bin" | wc -l)

            if (( bin_count > 1 )); then
                echo "Merging '$(basename "$cue")'..." >> "${LOG_FILE}"
                python3 "${HELPER_DIR}/binmerge.py" "$cue" "${SCRIPTS_DIR}/tmp/$merged" >>"${LOG_FILE}" 2>&1

                cd "${SCRIPTS_DIR}/tmp"
                echo "Converting '$(basename "$cue")' to VCD..." >> "${LOG_FILE}"
                "${CUE2POPS}" "${SCRIPTS_DIR}/tmp/$merged.cue" "${GAMES_PATH}/POPS/$merged.VCD" >> "${LOG_FILE}"
                rm "${SCRIPTS_DIR}/tmp/${merged}.cue" "${SCRIPTS_DIR}/tmp/${merged}.bin"
                i=$((i + 1))
                show_progress "$i" "$cue_count"
            elif (( bin_count == 0 )); then
                echo "Skipping $(basename "$cue") because it has $bin_count BIN file(s)." >> "${LOG_FILE}"
                i=$((i + 1))
                show_progress "$i" "$cue_count"
            else
                echo "No merge required. $(basename "$cue") has $bin_count BIN file(s)." >> "${LOG_FILE}"
                cd "${GAMES_PATH}/POPS"
                echo "Converting '$(basename "$cue")' to VCD..." >> "${LOG_FILE}"
                "${CUE2POPS}" "$cue" "$vcd" >> "${LOG_FILE}" 2>&1
                i=$((i + 1))
                show_progress "$i" "$cue_count"
            fi
        done < <(find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f ! -path '*/.*' -iname "*.cue" -print0)
    else
        echo "No PS1 .cue files to convert in ${GAMES_PATH}/POPS." >> "${LOG_FILE}"
    fi
    cd "${TOOLKIT_PATH}"
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
    if [ -f "$icon_sys_filename" ]; then
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
        echo "Created: $system_cnf" >> "${LOG_FILE}"
    else
        echo "[X] Error: Failed to create $system_cnf" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $system_cnf"
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
    APP_WLE-R3Z)
    APP_ID="$title_id"
        ;;
    LAUNCHELF*|WLAUNCH*|WLE*|BOOT*|APP_WLE*)
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

    if [ "${elf}" = "osdmenu-configurator.elf" ]; then
        APP_ID=OSDMENUCONF
    fi

    png_file="${ARTWORK_DIR}/${APP_ID}.png"
    # Copy the matching PNG file from ART_DIR, or default to APP.png
    if [ -s "$png_file" ] && [ "$OS" = "PSBBN" ]; then
        cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create $dir/jkt_001.png" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/jkt_001.png."
        }
        echo "Created: $dir/jkt_001.png"  >> "${LOG_FILE}"
    elif [ ! -s "$png_file" ]; then
        echo "Artwork not found locally for $APP_ID. Attempting to download from the PSBBN art database..." >> "${LOG_FILE}"
        wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
        "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/apps/${APP_ID}.png"
        
        if [[ -s "$png_file" ]]; then
            echo "[✓] Successfully downloaded artwork for $title_id" >> "${LOG_FILE}"
            if [ "$OS" = "PSBBN" ]; then
                cp "$png_file" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || {
                    echo "[X] Error: Failed to create $dir/jkt_001.png" >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/jkt_001.png"
                }
                echo "Created: $dir/jkt_001.png"  >> "${LOG_FILE}"
            fi
        else
            rm -f "$png_file"
            if [ "$OS" = "PSBBN" ]; then
                cp "$ARTWORK_DIR/APP.png" "$dir/jkt_001.png" 2>> "${LOG_FILE}" || {
                    echo "[X] Error: Failed to create $dir/jkt_001.png" >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/jkt_001.png"
                }
                echo "Created: $dir/jkt_001.png using default image."  >> "${LOG_FILE}"
            fi
            echo "$APP_ID,$title,$elf" >> "${MISSING_APP_ART}"
        fi
    fi

    if [ -s "$png_file" ]; then
        cp "$png_file" "${OPL}/ART/${elf}_COV.png" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create ${OPL}/ART/${elf}_COV.png" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${OPL}/ART/${elf}_COV.png"
        }
        echo "Created: ${OPL}/ART/${elf}_COV.png"  >> "${LOG_FILE}"
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

create_game_assets() {
    local GAME_LIST=$1
    if [ "$OS" = "PSBBN" ]; then
        i="0"
        SPLASH
        echo >> "${LOG_FILE}"
        echo "Downloading artwork for the PSBBN Game Collection..." >> "${LOG_FILE}"
        echo "${UI_TEXT[GAME_INSTALLER_46]}"

        # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
        exec 3< "$GAME_LIST"
        while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
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
                echo -n "Artwork not found locally. Attempting to download from the PSBBN art database..." >> "${LOG_FILE}"
                echo >> "${LOG_FILE}"
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
                        convert "$file" -resize 256x256! -depth 8 -alpha off "$output"
                    else
                        # Not square: Resize and crop
                        echo "Resizing and cropping $file" >> "${LOG_FILE}"
                        convert "$file" -resize 256x256^ -crop 256x256+0+44 -depth 8 -alpha off "$output"
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

    exec 3< "$GAME_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do

        ico_file="${ICONS_DIR}/ico/$game_id.ico"
        
        if [[ ! -s "$ico_file" ]]; then
            # Attempt to download icon using wget
            echo -n "Icon not found locally for $game_id. Attempting to download from the HDD-OSD icon database..." >> "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 --output-document="$ico_file" \
            "https://raw.githubusercontent.com/CosmicScale/HDD-OSD-Icon-Database/main/ico/${game_id}.ico"
            if [[ -s "$ico_file" ]]; then
                echo "[✓] Successfully downloaded icon for ${game_id}." >> "${LOG_FILE}"
            else
                # If wget fails, run the art downloader
                [[ -f "$ico_file" ]] && rm -f "$ico_file"

                png_file_cov="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_COV.png"
                png_file_cov2="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_COV2.png"
                png_file_lab="${TOOLKIT_PATH}/icons/ico/tmp/${game_id}_LAB.png"

                echo -n "Icon not found on database. Downloading icon assets for $game_id..." >> "${LOG_FILE}"

                if [[ -s "${GAMES_PATH}/ART/${game_id}_COV.png" ]]; then
                    cp "${GAMES_PATH}/ART/${game_id}_COV.png" "${png_file_cov}"
                fi

                if [[ "$disc_type" == "POPS" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" ]]; then
                    wget --quiet --timeout=10 --tries=3 --output-document="${png_file_cov}" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_COV.png"
                    if [[ -s "$png_file_cov" ]]; then
                        wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cov2" \
                        "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_COV2.png"
                        wget --quiet --timeout=10 --tries=3 --output-document="$png_file_lab" \
                        "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_LAB.png"
                    fi
                elif [[ -s "$png_file_cov"  ]]; then
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cov2" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_COV2.png"
                    wget --quiet --timeout=10 --tries=3 --output-document="$png_file_lab" \
                    "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS2/${game_id}/${game_id}_LAB.png"
                fi

                if [[ ! -s "$png_file_lab" ]]; then
                    if [[ "${game_id:2:1}" == "E" ]]; then
                        if [[ "$disc_type" != "POPS" || "$disc_type" != "__.POPS" || "$disc_type" != "SMB" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_PAL.png" "${png_file_lab}"
                        else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_PAL.png" "${png_file_lab}"
                        fi
                    elif [[ "${game_id:2:1}" == "U" || "${game_id:0:1}" == "L" ]]; then
                        if [[ "$disc_type" != "POPS" || "$disc_type" != "__.POPS" || "$disc_type" != "SMB" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_USA.png" "${png_file_lab}"
                    else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_USA.png" "${png_file_lab}"
                        fi
                    else
                        if [[ "$disc_type" != "POPS" || "$disc_type" != "__.POPS" || "$disc_type" != "SMB" ]]; then
                            cp "${ASSETS_DIR}/Icon-templates/PS2_LAB_JPN.png" "${png_file_lab}"
                        else
                            cp "${ASSETS_DIR}/Icon-templates/PS1_LAB_JPN.png" "${png_file_lab}"
                        fi
                    fi
                fi

                if [[ -s "$png_file_cov" && -s "$png_file_cov2" && -s "$png_file_lab" ]]; then
                    echo "Creating HDD-OSD icon for $game_id..." >> "${LOG_FILE}"
                    if [[ "$disc_type" != "POPS" || "$disc_type" != "__.POPS" || "$disc_type" != "SMB" ]]; then
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
                else
                    echo "Insufficient assets to create icon for $game_id." >> "${LOG_FILE}"
                fi
            fi
        else
            echo "Icon for $game_id already exists. Skipping download." >> "${LOG_FILE}"
        fi
        i=$((i + 1))
        show_progress "$i" "$collection_count"

    done
    exec 3<&-
    
    cp "${ICONS_DIR}/ico/tmp/"*.ico "${ICONS_DIR}/ico/" >/dev/null 2>&1

    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating assets for games..."  >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_61]}"
    i="0"

    exec 3< "$GAME_LIST"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title partition_label <&3; do

        echo "Processing $title..." >> "${LOG_FILE}"
        # Create a sub-folder named after the game_id
        game_dir="$ICONS_DIR/$partition_label"
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

            if [[ "$disc_type" == "SMB" ]]; then
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
            if [[ "$disc_type" == "SMB" ]]; then
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
                if [[ "$disc_type" == "POPS" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" ]]; then
                    convert "${ASSETS_DIR}/Icon-templates/PS1-Template.png" \( "$png_file" -resize 197x197! \) -geometry +42+27 -composite "${game_dir}/jkt_001.png"
                else
                    cp "$png_file" "${game_dir}/jkt_001.png" 2>> "${LOG_FILE}" || {
                        echo "[X] Error: Failed to create: $game_dir/jkt_001.png" >> "${LOG_FILE}"
                        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/jkt_001.png"
                    }
                fi
                echo "Created: $game_dir/jkt_001.png" >> "${LOG_FILE}"
            else
                echo "$game_id $title" >> "${MISSING_ART}"
                if [[ "$disc_type" == "POPS" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" ]]; then
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
            POPS|__.POPS|SMB)
                cp "${ICONS_DIR}/ico/ps1.ico" "${game_dir}/list.ico" 2>> "${LOG_FILE}" || {
                    echo "[X] Error: Failed to create: $game_dir/list.ico"  >> "${LOG_FILE}"
                    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $game_dir/list.ico."
                }
                echo "Created: $game_dir/list.ico using default PS1 icon." >> "${LOG_FILE}"
            ;;
            esac
        fi

        # Generate the system.cnf files
        # Determine the launcher value for this specific game
        if [[ "$disc_type" == "POPS" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" ]]; then
            launcher_value="$disc_type"
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
        elif [ "$launcher_value" = "__.POPS" ]; then
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
    elif [ "$launcher_value" = "POPS" ]; then
            elf_file="XX.${file_name%.*}.ELF"
            cat > "${game_dir}/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = hdd0:__system:pfs:/launcher/POPSTARTER.ELF
titleid = $game_id
nohistory = 1
arg = bbnl:$elf_file
skip_argv0 = 1
EOL
        elif [ "$launcher_value" = "POPS_EXT" ]; then
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
    done
    exec 3<&-
}

create_game_partitions() {
    local GAME_LIST=$1
    i=0

    # Read all lines in reverse order
    mapfile -t reversed_lines < <(tac "$GAME_LIST")
    
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
            COMMANDS+="lcd '${ICONS_DIR}/${partition_label}'\n"
            COMMANDS+="mkdir res\n"
            COMMANDS+="cd res\n"
            COMMANDS+="put info.sys\n"
            COMMANDS+="put jkt_001.png\n"

            if [[ "$disc_type" == "POPS" || "$disc_type" == "__.POPS" || "$disc_type" == "SMB" ]]; then
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

        cd "${ICONS_DIR}/$partition_label" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to change directory: ${ICONS_DIR}/$partition_label" 2>>"${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CD]} ${ICONS_DIR}/$partition_label"
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
        read -rp "  ${UI_TEXT[CONTINUE_PROMPT]} (y/n): " confirm
        case "$confirm" in
            [Yy]) break ;;
            [Nn]) echo "  ${UI_TEXT[CANCELLED]}"; exit 1 ;;
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

if [[ -z "$path_arg" ]]; then
    get_display_path
    echo "${UI_TEXT[GAME_INSTALLER_26]} ${display_path}:" | tee -a "${LOG_FILE}"
    echo
    echo "📀 PS2 DVD → /DVD (.iso, .zso)"
    echo "💿 PS2 CD → /CD (.bin+.cue, .iso, .zso)"
    echo "💿 PS1 → /POPS (.bin+.cue, .VCD)"
    echo "🎮 POPStarter → /POPS (SB.*.ELF)"
    echo "🛠️ Homebrew → /APPS (.elf, SAS .psu)"
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
for folder in APPS ART CFG CHT THM VMC POPS CD DVD; do
    dir="${GAMES_PATH}/${folder}"
    [[ -d "$dir" ]] || mkdir -p "$dir" || { 
        echo "[X] Error: Failed to create: $dir"
        error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir"
    }
done

# Check if GAMES_PATH is custom
if [[ "${GAMES_PATH}" != "${TOOLKIT_PATH}/games" ]]; then
    echo "Using custom game path." >> "${LOG_FILE}"
    cp "${TOOLKIT_PATH}/games/APPS/"{APP_WLE-R3Z.psu,SYS_R3CONFIGURATOR.psu} "${GAMES_PATH}/APPS" >> "${LOG_FILE}" 2>&1
else
    echo "Using default game path." >> "${LOG_FILE}"
fi

POPS_FOLDER="${GAMES_PATH}/POPS"

SPLASH

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

get_display_path

if [ "$INSTALL_TYPE" = "sync" ] && \
   ! find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" -o -iname "*.cue" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/CD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" -o -iname "*.bin" -o -iname "*.cue" \) -print -quit | grep -q . && \
   ! find "${GAMES_PATH}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) -print -quit | grep -q .; then
    echo
    echo "${UI_TEXT[GAME_INSTALLER_13]} ${display_path}"
    echo "${UI_TEXT[GAME_INSTALLER_14]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CONTINUE_PROMPT]} (y/n): " confirm
        case "$confirm" in
            [Yy]) break ;;
            [Nn]) echo "${UI_TEXT[CANCELLED]}"; exit 1 ;;
            *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
        esac
    done
fi

SPLASH

echo "${UI_TEXT[GAME_INSTALLER_15]}"
echo
echo "1) ${UI_TEXT[GAME_INSTALLER_16]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_17]}"
echo "https://github.com/ps2homebrew/Open-PS2-Loader"
echo
echo "2) ${UI_TEXT[GAME_INSTALLER_19]}"
echo
echo "${UI_TEXT[GAME_INSTALLER_20]}"
echo "https://github.com/pcm720/nhddl"
echo

while true; do
    read -rp "${UI_TEXT[CHOICE]} (1/2): " choice
    case "$choice" in
        1) LAUNCHER="OPL"; DESC2="Open PS2 Loader (OPL)"; break ;;
        2) LAUNCHER="NEUTRINO"; DESC2="NHDDL"; break ;;
        *) echo; echo "${UI_TEXT[MENU_INVALID]}" ;;
    esac
done

if { find "${GAMES_PATH}/POPS/" -maxdepth 1 -type f \( -iname "*.vcd" -o -iname "*.bin" \) | grep -q .; } ||
   { [ "$INSTALL_TYPE" = "copy" ] && find "${OPL}/POPS" -maxdepth 1 -type f -iname "*.vcd" | grep -q .; }
then
    ps1_games_found=true
    SPLASH
    echo "${UI_TEXT[GAME_INSTALLER_22]}"
    echo
    echo "${UI_TEXT[GAME_INSTALLER_23]}"
    echo
    while true; do
        read -rp "${UI_TEXT[CHOICE]} (y/n): " HDTVFIX
        case "$HDTVFIX" in
            [Yy])
                cp "${ASSETS_DIR}/POPStarter/CHEATS.TXT" "${OPL}/POPS"
                break
                ;;
            [Nn])
                rm -f "${OPL}/POPS/CHEATS.TXT"
                break
                ;;
            *)
                echo
                echo "${UI_TEXT[MENU_INVALID]}"
                ;;
        esac
    done
fi

if { find "${GAMES_PATH}/CD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" -o -iname "*.bin" \) | grep -q .; } ||
   { find "${GAMES_PATH}/DVD/" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; } ||
   { [ "$INSTALL_TYPE" = "copy" ] && find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; }
then
    # Ask about PS2 VMCs if PS2 games exist
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

SPLASH

echo "PS2 Drive Detected: $DEVICE" >> "${LOG_FILE}"
echo "Linux Games Folder: $GAMES_PATH" >> "${LOG_FILE}"
echo "Games Folder: $display_path" >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_26]} $display_path"

echo "Install Type: $DESC1" >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_27]} $DESC1"

echo "Game Launcher: $DESC2" >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_28]} $DESC2"

if [ -n "$HDTVFIX" ]; then
    case "$HDTVFIX" in
        [Yy]) HDTVFIX="${UI_TEXT[YES]}" ;;
        [Nn]) HDTVFIX="${UI_TEXT[NO]}" ;;
    esac
    echo "HDTV fix for PS1 Games: $HDTVFIX" >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_29]} $HDTVFIX"
fi
if [ "$PS2_VMC" = "y" ]; then
    echo "PS2 VMCs: Yes" >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_30]} ${UI_TEXT[YES]}"
elif [ "$PS2_VMC" = "n" ]; then
    echo "PS2 VMCs: No" >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_30]} ${UI_TEXT[NO]}"
fi
echo
read -n 1 -s -r -p "${UI_TEXT[CONTINUE]}"
echo
prevent_sleep_start

################################### Prepare Game Files ###################################

SPLASH

install_pops

# Rename .vcd to .VCD
for file in "${GAMES_PATH}/POPS"/*.vcd; do
    [ -e "$file" ] || continue  # skip if no match

    tmpfile="${file%.vcd}.tmp"
    newfile="${file%.vcd}.VCD"

    mv -- "$file" "$tmpfile" &&
    mv -- "$tmpfile" "$newfile" >> "$LOG_FILE" 2>&1 || error_msg "Error" "Failed to rename $file."
done

echo  >> "${LOG_FILE}"
echo "Contents of ${OPL}/POPS:" >> "${LOG_FILE}"
ls -l "${OPL}/POPS/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

convert_vcd

echo "Local POPS folder contents:" >> "${LOG_FILE}"
ls -l "${GAMES_PATH}/POPS/" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

if [ "$INSTALL_TYPE" = "sync" ]; then
    ps1_update=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='[^.]*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    ps1_update=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='[^.]*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
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

if [[ "$LAUNCHER" = "NEUTRINO" ]]; then
    convert_zso
fi

convert_bin

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

# Set flag if any changes
if [ -n "$ps1_update" ]; then
    if [ "$INSTALL_TYPE" = "sync" ]; then
        rsync -dL --progress --delete --ignore-existing --include='[^.]*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo echo "[X] Error: Failed to sync PS1 games." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_SYNC]}"
        fi
    else
        rsync -dL --progress --ignore-existing --include='[^.]*.VCD' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
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

################################### Create Games List ###################################

# Create games list of PS1 games in ${OPL}/POPS
if find "${OPL}/POPS/" -maxdepth 1 -type f \( -iname "*.vcd" \) | grep -q .; then
    SPLASH
    echo "Creating PS1 games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_37]}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${ATA_POPS_LIST}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "[X] Error: Failed to create ATA PS1 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS1_LIST]}"
    fi
fi

if [ -s "${ATA_POPS_LIST}" ]; then
    cat "${ATA_POPS_LIST}" > "${PS1_LIST}"
fi

if [ -s "${PFS_POPS_LIST}" ]; then
    cat "${PFS_POPS_LIST}" >> "${PS1_LIST}"
fi

# Create games list of PS2 games to be installed
if find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    SPLASH
    echo "Creating PS2 games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_40]}"
    python3 -u "${HELPER_DIR}/list-builder.py" "${OPL}" "${PS2_LIST}"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "[X] Error: Failed to create PS2 games list." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_PS2_LIST]}"
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

if [[ ! -s "${PS2_LIST}" ]] && find "${OPL}/CD" "${OPL}/DVD" -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.zso" \) | grep -q .; then
    echo "[X] Error: Failed to create games list." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_GAME_LIST]}"
fi

if [[ ! -s "${PS1_LIST}" ]] && find "${OPL}/POPS" -maxdepth 1 -type f \( -iname "*.VCD" \) | grep -q .; then
    echo "[X] Error: Failed to create games list." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_GAME_LIST]}"
fi

if [[ -s "${PS1_LIST}" ]] && [[ ! -s "${PS2_LIST}" ]]; then
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ ! -s "${PS1_LIST}" ]] && [[ -s "${PS2_LIST}" ]]; then
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
elif [[ -s "${PS1_LIST}" ]] && [[ -s "${PS2_LIST}" ]]; then
    { cat "${PS2_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
    { cat "${PS1_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
fi

ata_pops_count=$(grep -c '^[^[:space:]]' "${ATA_POPS_LIST}")

rm -f "${OPL}/ps1.list"

################################### Synchronize & Copy Apps ###################################

SPLASH

# Remove outdated apps
rm -f "${GAMES_PATH}/APPS/"{Launch-Disc.elf,HDD-OSD.elf,PSBBN.ELF}
rm -rf "${OPL}/APPS/APP_WLE-ISR-"

md5_check "${GAMES_PATH}/APPS/BOOT.ELF" "20a5b2c1ffb86e742fb5705b5d9d7370"

if [ "$delete_app" = "yes" ]; then
    rm -f "${GAMES_PATH}/APPS/BOOT.ELF"
fi

md5_check "${GAMES_PATH}/APPS/APP_WLE-ISR-XF-MM.psu" "23aa962e31740c6101a1c5b74cd253e3"

if [ "$delete_app" = "yes" ]; then
    rm -f "${GAMES_PATH}/APPS/APP_WLE-ISR-XF-MM.psu"
fi

md5_check "${GAMES_PATH}/APPS/SYS_OSDMENU-CONFIGURATOR.psu" "73d9314a819693db1c83ae2de969196b"

if [ "$delete_app" = "yes" ]; then
    rm -f "${GAMES_PATH}/APPS/SYS_OSDMENU-CONFIGURATOR.psu"
fi

md5_check "${OPL}/APPS/SYS_OSDMENU-CONFIGURATOR/osdmenu-configurator.elf" "dca747f59532a1f5e9de0cd6b13c83b6"

if [ "$delete_app" = "yes" ]; then
    rm -rf "${OPL}/APPS/SYS_OSDMENU-CONFIGURATOR"
fi

update_apps "Neutrino" "${NEUTRINO_DIR}/" "${OPL}/neutrino/" "-rut --progress --delete --exclude='.*'"
update_apps "POPSLoader" "${ASSETS_DIR}/POPStarter/POPSLOADER.ELF" "${OPL}/POPS/POPSLOADER.ELF" "-ut --progress"

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

    rm -rf "${OPL}/APPS/PSBBN"
    install_elf "${GAMES_PATH}"
    install_elf "${OPL}"

    find "${GAMES_PATH}/APPS/" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} "${OPL}/APPS/" \; || {
        echo "[X] Error: Failed copy apps." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_COPY_APPS]}"
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
ls -1 "${OPL}/APPS/" >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"

# Check for master.list
if [[ -s "${ALL_GAMES}" ]]; then
    # Count the number of games to be installed
    count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
    echo >> "${LOG_FILE}"
    echo "Number of games to install: $count" >> "${LOG_FILE}"
    echo "[✓] Games list successfully created." >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    echo "master.list:" >> "${LOG_FILE}"
    cat "${ALL_GAMES}" >> "${LOG_FILE}"
fi

################################### Creating Assets ###################################

echo >> "${LOG_FILE}"
echo "Preparing to create assets..." >> "${LOG_FILE}"

mkdir -p "${ICONS_DIR}/SAS" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ICONS_DIR}/SAS." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/SAS."
}
mkdir -p "${ICONS_DIR}/APPS" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ICONS_DIR}/APPS." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/APPS."
}
mkdir -p "${ARTWORK_DIR}/tmp" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ARTWORK_DIR}/tmp." >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ARTWORK_DIR}/tmp."
}
mkdir -p "${ICONS_DIR}/ico/tmp" 2>>"${LOG_FILE}" || {
    echo "[X] Error: Failed to create ${ICONS_DIR}/ico/tmp/vmc" >> "${LOG_FILE}"
    error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/ico/tmp/vmc"
}

# Set maximum number of items for the Game Channel

if [ "$OS" = "PSBBN" ]; then
    pp_cap="797"
else
    pp_cap="798"
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
        echo "[!] Warning: Insufficient space to create launcher partitions for remaining SAS apps." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_SAS_COUNT]}" "${UI_TEXT[WARN_APP_COUNT_2]} $pp_max" " " "${UI_TEXT[WARN_APP_COUNT_3]}"
        break
    fi

    # Check for .elf/.ELF file
    if find "$dir" -maxdepth 1 -type f -iname "*.elf" | grep -q . && \
       [[ -f "$dir/icon.sys" && -f "$dir/title.cfg" ]]; then
        cp -r "$dir" "${ICONS_DIR}/SAS" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to copy $dir" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_COPY]} $dir"
        }
        SAS_COUNT=$((SAS_COUNT + 1))
    fi
done

if ! find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo "No SAS apps to process." >> "${LOG_FILE}"
else
    SPLASH
    echo "Creating assets for SAS apps..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_41]}"
    i="0"
    # Loop through each folder in the 'SAS' directory, sorted in reverse alphabetical order
    while IFS= read -r dir; do
        title_id=$(basename "$dir")

        if [ -f "$dir/list.icn" ]; then
            echo "Processing $title_id..." >> "${LOG_FILE}"
            mv "$dir/list.icn" "$dir/list.ico" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to convert: $dir/list.icn." 2>>"${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_CONVERT]} $dir/list.icn."
            }
            echo "Converted list.icn: $dir/list.ico" >> "${LOG_FILE}"
            [ -f "$dir/del.icn" ] && mv "$dir/del.icn" "$dir/del.ico" | echo "Converted del.icn: $dir/del.ico" >> "${LOG_FILE}"
        
        else
            echo "list.icn not found in $dir." >> "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/app.ico" "$dir/list.ico" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to create: $dir/list.ico" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/list.ico"
            }
            echo "Created: $dir/list.ico using default icon." >> "${LOG_FILE}"
            cp "${ICONS_DIR}/ico/app-del.ico" "$dir/del.ico" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to create:  $dir/del.ico" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/del.ico"
            }
            echo "Created: $dir/del.ico using default icon." >> "${LOG_FILE}"
        fi

        # Convert the icon.sys file
        icon_sys_filename="$dir/icon.sys"

        python3 "${HELPER_DIR}/icon_sys_to_txt.py" "$icon_sys_filename" >> "${LOG_FILE}" 2>&1
        mv "$dir/icon.txt" "$icon_sys_filename" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to convert: $icon_sys_filename" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CONVERT]} $icon_sys_filename"
        }

        echo "Converted icon.sys: $icon_sys_filename"  >> "${LOG_FILE}"

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

        if [ "$title_id" = "APP_WLE-R3Z" ]; then
            LAUNCHELF_INSTALLED="yes"
        fi

        # Generate the system.cnf file
        system_cnf="${dir}/system.cnf"
        create_system_cnf "/APPS/$title_id/$elf" "$title_id"

        # Generate the info.sys file
        info_sys_filename="${dir}/info.sys"
        create_info_sys "$title" "$title_id" "$publisher"

        APP_ART

        i=$((i + 1))
        show_progress "$i" "$SAS_COUNT"
    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort)
    sort -t',' -k1,1 -f "${SAS_LIST}" -o "${SAS_LIST}"
    echo | tee -a "${LOG_FILE}"
fi

################################### Assets for ELF Files ###################################

pp_max=$(( pp_max - SAS_COUNT ))

echo "PP Max after SAS: $pp_max" >> "${LOG_FILE}"

APP_COUNT=0

for dir in "${SOURCE_DIR}"/*/; do
    [[ -d "$dir" ]] || continue

    # Stop if we've reached the max
    if [ "$APP_COUNT" -ge "$pp_max" ]; then
        echo "[!] Warning: Insufficient space to create launcher partitions for remaining ELF files."  >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_APP_COUNT_1]}" "${UI_TEXT[WARN_APP_COUNT_2]} $pp_max" "${UI_TEXT[WARN_APP_COUNT_3]}"
        break
    fi

    # Check for .elf/.ELF file
    if find "$dir" -maxdepth 1 -type f -iname "*.elf" | grep -q . && \
        [[ ! -f "$dir/icon.sys" && -f "$dir/title.cfg" ]]; then

        elf=$(find "$dir" -maxdepth 1 -type f -iname "*.elf" -printf '%f\n' | head -n1)

        if [[ $elf == SB.* ]]; then
            mv "$dir/$elf" "${OPL}/POPS"
            rm -rf "$dir"
        elif [[ $elf == XX.* ]]; then
            rm -rf "$dir"
        else
            cp -r "$dir" "${ICONS_DIR}/APPS" 2>>"${LOG_FILE}" || {
                echo "[X] Error: Failed to copy: $dir" >> "${LOG_FILE}"
                error_msg "Error" "${UI_TEXT[ERROR_COPY]} $dir"
            }
            APP_COUNT=$((APP_COUNT + 1))
        fi
    fi
done

if ! find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    echo "No ELF files to process." >> "${LOG_FILE}"
else
    SPLASH
    echo "Creating assets for ELF apps..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_42]}"
    i="0"
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

        cp "${ICONS_DIR}/ico/app.ico" "$dir/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: $dir/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/list.ico"
        }
        echo "Created: $dir/list.ico" >> "${LOG_FILE}"
        
        cp "${ICONS_DIR}/ico/app-del.ico" "$dir/del.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: $dir/del.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} $dir/del.ico"
        }
        echo "Created: $dir/del.ico" >> "${LOG_FILE}"

        APP_ART
        system_cnf="${dir}/system.cnf"
        create_system_cnf "/APPS/$(basename "$dir")/$elf" "$title_id"
        [ ${#title} -gt 79 ] && title="${title:0:76}..."

        cat >> "${ELF_LIST}" <<EOL
$title,ata:/APPS/$(basename "$dir")/$elf,$(basename "$dir")
EOL
        i=$((i + 1))
        show_progress "$i" "$APP_COUNT"
    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
    sort -t',' -k1,1 -f "${ELF_LIST}" -o "${ELF_LIST}"
    echo | tee -a "${LOG_FILE}"
fi

pp_max=$(( pp_max - APP_COUNT ))
echo "PP Max after ELFs: $pp_max" >> "${LOG_FILE}"

################################### OPL Artwork ###################################

if [ -f "${PS2_LIST}" ]; then
    SPLASH
    echo "Downloading artwork for OPL..."  >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_43]}"
    ps2_count=$(grep -c '^[^[:space:]]' "${PS2_LIST}")
    i="0"
    # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
    exec 3< "${PS2_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
        png_file_cover="${OPL}/ART/${game_id}_COV.png"
        png_file_disc="${OPL}/ART/${game_id}_ICO.png"
        if [[ -f "$png_file_cover" ]]; then
            echo "OPL Artwork for $game_id already exists. Skipping download." >> "${LOG_FILE}"
        else
            # Attempt to download artwork using wget
            echo "OPL Artwork not found locally for $game_id. Attempting to download from archive.org..." >> "${LOG_FILE}"
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
                    echo >> "${LOG_FILE}"
                    echo "[✓] Successfully downloaded OPL artwork for $game_id" >> "${LOG_FILE}"
                else
                    echo >> "${LOG_FILE}"
                    echo "[✓] Successfully downloaded some OPL artwork for $game_id, but missing: ${missing_files[*]}" >> "${LOG_FILE}"
                fi
            else
                echo >> "${LOG_FILE}"
                echo "Failed to download OPL artwork for $game_id" >> "${LOG_FILE}"
            fi
        fi
        i=$((i + 1))
        show_progress "$i" "$ps2_count"
    done
    echo
    exec 3<&-
else
    echo | tee -a "${LOG_FILE}"
    echo "No OPL artwork to download." >> "${LOG_FILE}"
fi

################################### POPSLoader Artwork ###################################

if [ -f "${ATA_POPS_LIST}" ]; then
    SPLASH
    echo "Downloading artwork for POPSLoader..."  >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_44]}"
    mkdir -p "${OPL}/POPS/ART"
    i="0"
    # First loop: Run the art downloader script for each game_id if artwork doesn't already exist
    exec 3< "${ATA_POPS_LIST}"
    while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
        png_file_cover="${OPL}/POPS/ART/${file_name%.*}.png"
        if [[ -f "$png_file_cover" ]]; then
            echo "POPSLoader Artwork for $filename already exists. Skipping download." >> "${LOG_FILE}"
        else
            # Attempt to download artwork using wget
            echo "POPSLoader Artwork not found locally for $filename. Attempting to download from archive.org..." >> "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 --output-document="$png_file_cover" \
            "https://archive.org/download/OPLM_ART_2024_09/OPLM_ART_2024_09.zip/PS1/${game_id}/${game_id}_COV.png"

            missing_files=()

            if [[ ! -s "$png_file_cover" ]]; then
                [[ -f "$png_file_cover" ]] && rm -f "$png_file_cover"
                missing_files+=("cover")
            fi

            if [[ -s "$png_file_cover" ]]; then
                if [[ ${#missing_files[@]} -eq 0 ]]; then
                    echo >> "${LOG_FILE}"
                    echo "[✓] Successfully downloaded POPSLoader artwork for $file_name" >> "${LOG_FILE}"
                fi
            else
                echo >> "${LOG_FILE}"
                echo "Failed to download POPSLoader artwork for $file_name" >> "${LOG_FILE}"
            fi
        fi
        i=$((i + 1))
        show_progress "$i" "$ata_pops_count"
    done
    echo
    exec 3<&-
else
    echo | tee -a "${LOG_FILE}"
    echo "No POPSLoader artwork to download." >> "${LOG_FILE}"
fi

################################### Assets for SMB POPStarter Games ###################################

if [ "$INSTALL_TYPE" = "sync" ]; then
    pops_ext=$(rsync -dL --dry-run --delete --ignore-existing --itemize-changes --include='SB.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
elif [ "$INSTALL_TYPE" = "copy" ]; then
    pops_ext=$(rsync -dL --dry-run --ignore-existing --itemize-changes --include='SB.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/")
fi

# Set flag if any changes
if [ -n "$pops_ext" ]; then
    SPLASH
    if [ "$INSTALL_TYPE" = "sync" ]; then
        echo "Syncing POPStarter SMB files..." >> "${LOG_FILE}"
        rsync -dL --progress --delete --ignore-existing --include='SB.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" >>"${LOG_FILE}" 2>&1 | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo echo "[X] Error: Failed to sync POPStarter SMB files." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_POPS_SYNC]}"
        fi
    else
        echo "Copying POPStarter ELF files..." >> "${LOG_FILE}"
        rsync -dL --progress --ignore-existing --include='SB.*.ELF' --exclude='.*' --exclude='*' "${GAMES_PATH}/POPS/" "${OPL}/POPS/" >>"${LOG_FILE}" 2>&1 | tee -a "${LOG_FILE}"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo "[X] Error: Failed to copy POPStarter SMB files." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_POPS_COPY]}"
        fi
    fi
else
    echo "POPStarter SMB files are already up-to-date." >> "${LOG_FILE}"
fi

# Create games list of PS1 External Games
if files=( "${OPL}/POPS/"*.ELF ); then
    SPLASH
    pops_count=${#files[@]}
    i="0"
    echo "Creating SMB games list..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_62]}"
    for file in "${OPL}/POPS/"*.ELF; do
        filename=$(basename "$file")
        game_id=""

        # First 3 chars determine prefix tag
        prefix="${filename:0:3}"

        case "$prefix" in
            "SB.") tag="SMB"; magic="SB" ;;
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
            echo "$title|$game_id|$publisher|$tag|$filename|$jpn_title|$partition_label" >> "${SMB_POPS_LIST}"
            i=$((i + 1))
            show_progress "$i" "$pops_count"
    done
fi

if [ -s "${SMB_POPS_LIST}" ]; then

    # Sort games list
    if [[ "$lang" == "jpn" ]]; then
        sort_jpn "${SMB_POPS_LIST}" "${POPS_JPN_LIST}"
    fi

    if [ -s "${SMB_POPS_LIST}" ]; then
        python3 "${HELPER_DIR}/list-sorter.py" "${SMB_POPS_LIST}" || {
            echo "[X] Error: Failed to sort the POPStarter SMB games list." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_PS1_SORT]}"
        }
    fi

    if [ -s "${POPS_JPN_LIST}" ]; then
        cat "${POPS_JPN_LIST}" > "${TMP_LIST}"
        cat "${SMB_POPS_LIST}" >> "${TMP_LIST}" 2> "${LOG_FILE}"
        cat "${TMP_LIST}" > "${SMB_POPS_LIST}"
    fi

    echo "smb-pops.list:" >> "${LOG_FILE}"
    cat "${SMB_POPS_LIST}" >> "${LOG_FILE}"
fi

if [ -s "$SMB_POPS_LIST" ]; then
    collection_count=$(grep -c '^[^[:space:]]' "${SMB_POPS_LIST}")
    if [ "$collection_count" -gt "$pp_max" ]; then
        echo "[!] Warning: Insufficient space to create the remaining SMB POPStarter launcher partitions." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_POPS_COUNT]}"

        # Overwrite $SMB_POPS_LIST with the first $pp_max lines
        head -n "$pp_max" "$SMB_POPS_LIST" > "${SMB_POPS_LIST}.tmp"
        mv "${SMB_POPS_LIST}.tmp" "$SMB_POPS_LIST" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to updated master.list."
        echo "Updated pops.list:" >> "${LOG_FILE}"
        cat "$SMB_POPS_LIST" >> "${LOG_FILE}"
        echo >> "${LOG_FILE}"
    fi
    if [ -s "$SMB_POPS_LIST" ]; then
        collection_count=$(grep -c '^[^[:space:]]' "${SMB_POPS_LIST}")
        create_game_assets "$SMB_POPS_LIST"
    else
        echo "No PS1 SMB games to process after truncating." >> "${LOG_FILE}"
        collection_count="0"
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No PS1 SMB games to process." >> "${LOG_FILE}"
    collection_count="0"
fi

################################### Assets for PS2 Games ###################################

pp_max=$(( pp_max - collection_count ))
echo "PP Remaining for PS2 games: $pp_max" >> "${LOG_FILE}"

if [ -s "$ALL_GAMES" ]; then
    cd ${TOOLKIT_PATH}
    python3 "${HELPER_DIR}/game-selector.py" "$ALL_GAMES" --max-games $pp_max --lang "$LANG_FILE" "${OPL}/exclude.list"
fi

if [ -s "$ALL_GAMES" ]; then
    collection_count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
    echo >> "${LOG_FILE}"
    echo "Games Selected:" >> "${LOG_FILE}"
    cat "$ALL_GAMES" >> "${LOG_FILE}"
else
    collection_count="0"
    echo >> "${LOG_FILE}"
    echo "No games selected." >> "${LOG_FILE}"
fi

if [ -s "$ALL_GAMES" ]; then
    create_game_assets "$ALL_GAMES"
else
    echo | tee -a "${LOG_FILE}"
    echo "No games to process." >> "${LOG_FILE}"
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
    if [ -d "$dir" ] && [ -n "$(find "$dir" -type f ! -name '.*' -print -quit 2>/dev/null)" ]; then
        folder_name=$(basename "$dir")
        dest_dir="${OPL}/$folder_name"
        
        # Copy non-hidden files to the corresponding destination subdirectory
        if [ "$folder_name" == "CFG" ] || [ "$folder_name" == "VMC" ]; then
            echo "Copying OPL $folder_name files..." >> "${LOG_FILE}"
            # Do not overwrite existing config and VMC files
            find "$dir" -type f ! -name '.*' -exec cp --update=none {} "$dest_dir" \; >> "${LOG_FILE}" 2>&1
        else
            if [ -n "$(find "$dir" -mindepth 1 ! -name '.*' -print -quit)" ]; then
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

if [ -s "${ATA_POPS_LIST}" ]; then
    if [ ! -d "$ASSETS_DIR/Hugopocked POPStarter Fixes (2023-08-11)" ]; then
        echo | tee -a "${LOG_FILE}"
        echo | tee -a "${LOG_FILE}"
        echo "Downloading Hugopocked POPStarter Fixes..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[GAME_INSTALLER_49]}"
        POPS_PATCH_DL >> "${LOG_FILE}" 2>&1
        echo | tee -a "${LOG_FILE}"
    else
        echo >> "${LOG_FILE}"
        echo "Hugopocked POPStarter Fixes are present." >> "${LOG_FILE}"
    fi
    CREATE_PS1_VMC
fi

# Create PS2 VMCs if enabled
if [ "$PS2_VMC" = "y" ] && [ -s "${PS2_LIST}" ]; then
    CREATE_PS2_VMC
else
    DISABLE_PS2_VMC
fi

# Enable Compatibility Mode 1 for all ZSO files in OPL game configs
exec 3< "${PS2_LIST}"
while IFS='|' read -r title game_id publisher disc_type file_name jpn_title <&3; do
    if [[ "$file_name" == *.zso || "$file_name" == *.ZSO ]]; then
        cfg_file="${OPL}/CFG/${game_id}.cfg"
        if [[ -f "$cfg_file" ]] && grep -q '^\$Compatibility=' "$cfg_file"; then
            : # Compatibility modes already configured
        else
            printf '$Compatibility=1\r\n' >> "$cfg_file"
        fi
    fi
done
exec 3<&-

################################### Modify Config Files ###################################

case "$lang" in
    jpn)
        OPL_LANG="japanese"
        R3CONFIG_LANG="en"
        ;;
    fre)
        OPL_LANG="French"
        R3CONFIG_LANG="fr"
        ;;
    spa)
        OPL_LANG="Spanish"
        R3CONFIG_LANG="es"
        ;;
    ger)
        OPL_LANG="German"
        R3CONFIG_LANG="en"
        ;;
    ita)
        OPL_LANG="Italian"
        R3CONFIG_LANG="en"
        ;;
    por)
        OPL_LANG="Portuguese_BR"
        R3CONFIG_LANG="pt"
        ;;
    hun)
        OPL_LANG="Hungarian"
        R3CONFIG_LANG="en"
       ;;
    *)
        OPL_LANG="English (internal)"
        R3CONFIG_LANG="en"
        ;;
esac

if [[ "$ENTER" == "O" ]]; then
    OPL_ENTER="0"
    R3CONFIG_ENTER="1"
else
    OPL_ENTER="1"
    R3CONFIG_ENTER="0"
fi

echo "OPL Language: $OPL_LANG" >> "${LOG_FILE}"
cp "${ASSETS_DIR}/OPL/LNG"/* "${OPL}/LNG" >> "${LOG_FILE}" 2>&1

if [[ -f "${OPL}/conf_opl.cfg" ]]; then
    sed -i \
        -e '/^enable_coverart=/d' \
        -e '/^default_device=/d' \
        -e '/^usb_mode=/d' \
        -e '/^app_mode=/d' \
        -e '/^enable_bdm_hdd=/d' \
        -e '/^language_text=/d' \
        -e '/^swap_select_btn=/d' \
        "${OPL}/conf_opl.cfg"
fi

cat >> "${OPL}/conf_opl.cfg" <<EOL
enable_coverart=1
default_device=0
usb_mode=2
app_mode=2
enable_bdm_hdd=1
language_text=$OPL_LANG
swap_select_btn=$OPL_ENTER
EOL

echo "R3CONFIGURATOR Language: $R3CONFIG_LANG" >> "${LOG_FILE}"
if [[ -d "${OPL}/APPS/SYS_R3CONFIGURATOR" ]]; then
    if [[ -f "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" ]]; then
        sed -i \
        -e '/^default_language[[:space:]]*=/d' \
        -e '/^show_freemcboot[[:space:]]*=/d' \
        -e '/^show_freehddboot[[:space:]]*=/d' \
        -e '/^show_osdmenu[[:space:]]*=/d' \
        -e '/^show_osdmenu_mbr[[:space:]]*=/d' \
        -e '/^show_hosdmenu[[:space:]]*=/d' \
        -e '/^show_ps2bbl[[:space:]]*=/d' \
        -e '/^show_psxbbl[[:space:]]*=/d' \
        -e '/^swap_buttons[[:space:]]*=/d' \
        "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf"
    fi

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

echo | tee -a "${LOG_FILE}"
echo "All assets have been sucessfully created." >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
SPLASH
echo -n "Unmounting OPL partition..." >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_48]}"

UNMOUNT_OPL
sleep 2
echo >> "${LOG_FILE}"
mount_pfs

if [ "$OS" = "PSBBN" ]; then
    mapper_probe
    mount_cfs
fi

SPLASH
update_apps "OPL" "${ASSETS_DIR}/OPL/OPNPS2LD.ELF" "${STORAGE_DIR}/__system/launcher/OPNPS2LD.ELF" "-t --progress"
update_apps "NHDDL" "${ASSETS_DIR}/NHDDL/nhddl.elf" "${STORAGE_DIR}/__system/launcher/nhddl.elf" "-t --progress"
update_apps "POPStarter" "$POPSTARTER" "${STORAGE_DIR}/__system/launcher/POPSTARTER.ELF" "-t --progress"

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

    if [ $((LINE_COUNT + 1)) -lt 4 ]; then
        echo "POPSLoader file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.POPSLOADER" >> "$TMP_FILE"
    fi

    if [ $((LINE_COUNT + 2)) -lt 4 ] && [ "$LAUNCHELF_INSTALLED" = "yes" ]; then
        echo "wLaunchELF-R3Z file%3A%2Fopt0%2Fbn%2Fscript%2Fgame%2Fboot_game3.xml uri%3Dpfs%3A%2FPP.APP_WLE-R3Z" >> "$TMP_FILE"
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

cat "${ELF_LIST}" > "${APPS_LIST}" 2>> "${LOG_FILE}"
cat "${SAS_LIST}" >> "${APPS_LIST}" 2>> "${LOG_FILE}"

cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" "${OSDMENU_CNF}"
sed -i '/^name_OSDSYS_ITEM/d; /^path/d; /^arg_OSDSYS_ITEM/d;' "$OSDMENU_CNF"

# Ensure the file ends with a newline
[ -n "$(tail -c1 "$OSDMENU_CNF" | tr -d '\n')" ] && echo >> "$OSDMENU_CNF"

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

{
    echo "name_OSDSYS_ITEM_2 = POPSLoader"
    echo "path1_OSDSYS_ITEM_2 = ata:/POPS/POPSLOADER.ELF"
    echo "arg_OSDSYS_ITEM_2 = -page=ata"
    echo "arg_OSDSYS_ITEM_2 = -titleid=POPSLOADER"
} >> "$OSDMENU_CNF"


if [ "$OS" = "PSBBN" ]; then
{
        echo "name_OSDSYS_ITEM_3 = BB Navigator"
        echo "path1_OSDSYS_ITEM_3 = hdd0:__system/p2lboot/osdboot.elf"
        echo "arg_OSDSYS_ITEM_3 = -titleid=SCPN-601.60"
} >> "$OSDMENU_CNF"
    item=4
    max_items=197
else
    item=3
    max_items=198
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

echo "Updating OSDMenu MBR boot keys..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[GAME_INSTALLER_52]}"

cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}"

# Remove any existing boot_square lines
sed -i '/^boot_square/d' "${OSDMBR_CNF}" 2>> "${LOG_FILE}"
sed -i '/^boot_triangle/d' "${OSDMBR_CNF}" 2>> "${LOG_FILE}"
sed -i '/^boot_start/d' "${OSDMBR_CNF}" 2>> "${LOG_FILE}"

# Ensure the file ends with a new line
[ -n "$(tail -c1 "$OSDMBR_CNF" | tr -d '\n')" ] && echo >> "$OSDMBR_CNF"
{
    if [ "$LAUNCHER" = "OPL" ]; then
        echo 'boot_square = hdd0:__system:pfs:launcher/OPNPS2LD.ELF'
    else
        echo 'boot_square = hdd0:__system:pfs:launcher/nhddl.elf'
        echo 'boot_square_arg1 = -mode=ata'
    fi

    if [ "$LAUNCHELF_INSTALLED" = "yes" ]; then
        echo 'boot_start = ata:/APPS/APP_WLE-R3Z/WLE-R3Z.ELF'
    fi

    echo 'boot_triangle = ata:/POPS/POPSLOADER.ELF'
    echo 'boot_triangle_arg1 = -page=ata'
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

if find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating Launcher Partitions for SAS Apps..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_53]}"
    i="0"
    while IFS= read -r dir; do

        folder_name=$(basename "$dir")
        pp_name="PP.${folder_name:0:29}"

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
            error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
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
        cd "${ICONS_DIR}/SAS/$folder_name" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to change directory: ${ICONS_DIR}/SAS/$folder_name" 2>>"${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CD]} ${ICONS_DIR}/SAS/$folder_name"
        }
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
        }
        echo "Created $pp_name" >> "${LOG_FILE}"
        i=$((i + 1))
        show_progress "$i" "$SAS_COUNT"
    done < <(find "${ICONS_DIR}/SAS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

if find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -q .; then
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating Launcher Partitions for ELF apps..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_54]}"
    i="0"
    while IFS= read -r dir; do

        APA_SIZE_CHECK

        # Check the value of available
        if [ "$available" -lt 8 ]; then
            echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
            error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
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

        cd "${ICONS_DIR}/APPS/$folder_name" 2>>"${LOG_FILE}" || {
            echo "[X] Error: Failed to change directory: ${ICONS_DIR}/APPS/$folder_name" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CD]} ${ICONS_DIR}/APPS/$folder_name"
        }
        sudo "${HDL_DUMP}" modify_header "${DEVICE}" "$pp_name" >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
        }
        echo "Created $pp_name" >> "${LOG_FILE}"
        i=$((i + 1))
        show_progress "$i" "$APP_COUNT"
    done < <(find "${ICONS_DIR}/APPS" -mindepth 1 -maxdepth 1 -type d | sort -r)
fi

SPLASH
echo >> "${LOG_FILE}"
echo "Creating Launcher Partitions for default apps..." >> "${LOG_FILE}"
echo "${UI_TEXT[GAME_INSTALLER_55]}"
i="0"
if [ "$OS" = "PSBBN" ]; then
    default_apps="4"
    # Create PP.SCPN_601.60.PSBBN
    
    APA_SIZE_CHECK

    # Check the value of available
    if [ "$available" -lt 8 ]; then
        echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
        break
    else
        mkdir -p "${ICONS_DIR}/PSBBN"
        cp "${ICONS_DIR}/ico/psbbn.ico" "${ICONS_DIR}/PSBBN/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/PSBBN/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/PSBBN/list.ico"
        }
        cp "${ICONS_DIR}/ico/psbbn-del.ico" "${ICONS_DIR}/PSBBN/del.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/PSBBN/del.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/PSBBN/del.ico"
        }

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
        pp_name="PP.SCPN_601.60.PSBBN"

        create_info_sys "$title" "$title_id" "$publisher"
        create_icon_sys "$title" "$publisher"
    
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart $pp_name 8M PFS\n"
        COMMANDS+="mount $pp_name\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/PSBBN'\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        PFS_COMMANDS

        cd "${ICONS_DIR}/PSBBN"

        sudo "${HDL_DUMP}" modify_header "${DEVICE}" $pp_name >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
        }
        echo "Created $pp_name" >> "${LOG_FILE}"
        i=$((i + 1))
        show_progress "$i" "$default_apps"
    fi

    # Create PP.HOSDMENU.HIDDEN
    APA_SIZE_CHECK

    # Check the value of available
    if [ "$available" -lt 8 ]; then
        echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
        error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
        break
    else
        mkdir -p "${ICONS_DIR}/HOSDMENU"
        cp "${ICONS_DIR}/ico/app.ico" "${ICONS_DIR}/HOSDMENU/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/HOSDMENU/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/HOSDMENU/list.ico"
        }

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
        pp_name="PP.HOSDMENU.HIDDEN"

        create_info_sys "$title" "$title_id" "$publisher"
        create_icon_sys "$title" " "
    
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mkpart $pp_name 8M PFS\n"
        COMMANDS+="mount $pp_name\n"
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

        sudo "${HDL_DUMP}" modify_header "${DEVICE}" $pp_name >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
        }
        echo "Created $pp_name" >> "${LOG_FILE}"
        i=$((i + 1))
        show_progress "$i" "$default_apps"
    fi
else
    default_apps="2"
fi

# Create PP.POPSLOADER
APA_SIZE_CHECK

# Check the value of available
if [ "$available" -lt 8 ]; then
    echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
    error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
    break
else

    mkdir -p "${ICONS_DIR}/POPSLOADER"

    info_sys_filename="${ICONS_DIR}/POPSLOADER/info.sys"
    icon_sys_filename="${ICONS_DIR}/POPSLOADER/icon.sys"

    cp "${ICONS_DIR}/ico/popsloader.ico" "${ICONS_DIR}/POPSLOADER/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/POPSLOADER/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/POPSLOADER/list.ico"
        }
    cp "${ICONS_DIR}/ico/popsloader-del.ico" "${ICONS_DIR}/POPSLOADER/del.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/POPSLOADER/del.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/POPSLOADER/del.ico"
        }
    title="POPSLoader"
    title_id="POPSLOADER"
    publisher="github.com/NathanNeurotic"
    pp_name="PP.POPSLOADER"

    cat > "${ICONS_DIR}/POPSLOADER/system.cnf" <<EOL
BOOT2 = PATINFO
HDDUNITPOWER = NICHDD
path = ata:/POPS/POPSLOADER.ELF
titleid = POPSLOADER
arg = -page=ata
EOL

    create_info_sys "$title" "$title_id" "$publisher"
    create_icon_sys "$title" " "

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart $pp_name 8M PFS\n"
    if [ "$OS" = "PSBBN" ]; then
        COMMANDS+="mount $pp_name\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="lcd '${ICONS_DIR}/POPSLOADER'\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="lcd '${ARTWORK_DIR}'\n"
        COMMANDS+="put POPSLOADER.png\n"
        COMMANDS+="rename POPSLOADER.png jkt_001.png\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
    fi
    COMMANDS+="exit"

    PFS_COMMANDS

    cd "${ICONS_DIR}/POPSLOADER"

    sudo "${HDL_DUMP}" modify_header "${DEVICE}" $pp_name >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
    }
    echo "Created $pp_name" >> "${LOG_FILE}"
    i=$((i + 1))
    show_progress "$i" "$default_apps"
fi

# Create PP.LAUNCHER
APA_SIZE_CHECK

# Check the value of available
if [ "$available" -lt 8 ]; then
    echo "[!] Warning: Insufficient space for another partition." >> "${LOG_FILE}"
    error_msg "Warning" "${UI_TEXT[WARN_PARTITION_MAX]}"
    break
else

    mkdir -p "${ICONS_DIR}/LAUNCHER"

    info_sys_filename="${ICONS_DIR}/LAUNCHER/info.sys"
    icon_sys_filename="${ICONS_DIR}/LAUNCHER/icon.sys"

    if [ "$LAUNCHER" = "OPL" ]; then
        cp "${ICONS_DIR}/ico/opl.ico" "${ICONS_DIR}/LAUNCHER/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/LAUNCHER/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/LAUNCHER/list.ico"
        }
        cp "${ICONS_DIR}/ico/opl-del.ico" "${ICONS_DIR}/LAUNCHER/del.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/LAUNCHER/del.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/LAUNCHER/del.ico"
        }
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
        cp "${ICONS_DIR}/ico/nhddl.ico" "${ICONS_DIR}/LAUNCHER/list.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/LAUNCHER/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/LAUNCHER/list.ico"
        }
        cp "${ICONS_DIR}/ico/nhddl-del.ico" "${ICONS_DIR}/LAUNCHER/del.ico" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to create: ${ICONS_DIR}/LAUNCHER/list.ico" >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_CREATE]} ${ICONS_DIR}/LAUNCHER/list.ico"
        }
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
    pp_name="PP.LAUNCHER"

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart $pp_name 8M PFS\n"
    if [ "$OS" = "PSBBN" ]; then
        COMMANDS+="mount $pp_name\n"
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

    PFS_COMMANDS

    cd "${ICONS_DIR}/LAUNCHER"

    sudo "${HDL_DUMP}" modify_header "${DEVICE}" $pp_name >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed to modify header: $pp_name" >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_HEADER]} $pp_name"
    }
    echo "Created PP.LAUNCHER" >> "${LOG_FILE}"
    i=$((i + 1))
    show_progress "$i" "$default_apps"
fi

if [ -s "$SMB_POPS_LIST" ]; then
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating Launcher Partitions SBM POPStarter games..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_63]}"
    collection_count=$(grep -c '^[^[:space:]]' "${SMB_POPS_LIST}")
    create_game_partitions "$SMB_POPS_LIST"
fi

if [ -s "$ALL_GAMES" ]; then
    SPLASH
    echo >> "${LOG_FILE}"
    echo "Creating Launcher Partitions for games..." >> "${LOG_FILE}"
    echo "${UI_TEXT[GAME_INSTALLER_56]}"
    collection_count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
    create_game_partitions "$ALL_GAMES"
fi

################################### Submit missing artwork to the PSBBN Art Database ###################################

SPLASH
cp "${MISSING_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_APP_ART}" "${ARTWORK_DIR}/tmp" >> "${LOG_FILE}" 2>&1
cp "${MISSING_ICON}" "${ICONS_DIR}/ico/tmp" >> "${LOG_FILE}" 2>&1

cd "${ICONS_DIR}/ico/tmp/"
rm *.png >/dev/null 2>&1
zip -r "${ARTWORK_DIR}/tmp/ico.zip" * >/dev/null 2>&1
cd "${ARTWORK_DIR}/tmp/" 
zip -r "${ARTWORK_DIR}/tmp/art.zip" * >/dev/null 2>&1

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


SPLASH
echo "================================== [✓] Game Installer Completed Successfully =================================" >> "${LOG_FILE}"
center_title "[✓] ${UI_TEXT[GAME_INSTALLER_60]}"
echo
if [ "$ps1_games_found" = true ]; then
    center_title "${UI_TEXT[MUSIC_INSTALLER_5]}"
    printf '\n  %s\n\n  %s\n  %s\n\n' \
        "${UI_TEXT[GAME_INSTALLER_67]}" \
        "${UI_TEXT[GAME_INSTALLER_68]}" \
        "https://github.com/CosmicScale/PSBBN-Definitive-Project/#installing-ata-bdm-assault"
    printf '%*s\n\n' 110 '' | tr ' ' '='
fi

center_text "${UI_TEXT[CONTINUE]}"
read -n 1 -s -r -p "$text" </dev/tty
echo

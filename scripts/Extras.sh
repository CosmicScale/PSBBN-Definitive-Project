#!/usr/bin/env bash
#
# Extras form the PSBBN Definitive Project
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

# Set paths
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
ICONS_DIR="${TOOLKIT_PATH}/icons"
ARTWORK_DIR="${ICONS_DIR}/art"
ICO_DIR="${ICONS_DIR}/ico"
VMC_ICON_DIR="${ICONS_DIR}/ico/vmc"
OPL="${SCRIPTS_DIR}/OPL"
OSDMBR_CNF="${SCRIPTS_DIR}/tmp/OSDMBR.CNF"
SYSCONF_XML="${SCRIPTS_DIR}/tmp/sysconf.xml"
LOG_FILE="${TOOLKIT_PATH}/logs/extras.log"

URL="https://archive.org/download/psbbn-definitive-patch-v4.1"

arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
fi

LANG_FILE="$1"
shift  # remove language
path_arg="$1"

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

center_menu() {
    local longest=0

    for key in "${MENU_KEYS[@]}"; do
        local text="${UI_TEXT[$key]}"
        local width=$(text_width "$text")

        (( width > longest )) && longest=$width
    done

    padding=$(( (term_width - longest + 3) / 2 ))
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

EXTRAS_SPLASH() {
clear
    cat << "EOF"
                                         _____     _                 
                                        |  ___|   | |                
                                        | |____  _| |_ _ __ __ _ ___ 
                                        |  __\ \/ / __| '__/ _` / __|
                                        | |___>  <| |_| | | (_| \__ \
                                        \____/_/\_\\__|_|  \__,_|___/



EOF
}

LINUX_SPLASH(){
    clear
    cat << "EOF"

                              ______  _____  _____   _     _                  
                              | ___ \/  ___|/ __  \ | |   (_)                 
                              | |_/ /\ `--. `' / /' | |    _ _ __  _   ___  __
                              |  __/  `--. \  / /   | |   | | '_ \| | | \ \/ /
                              | |    /\__/ /./ /___ | |___| | | | | |_| |>  < 
                              \_|    \____/ \_____/ \_____/_|_| |_|\__,_/_/\_\


EOF
} 

SWAP_SPLASH(){
    clear
    cat << "EOF"
                ______                   _              ______       _   _                  
                | ___ \                 (_)             | ___ \     | | | |                 
                | |_/ /___  __ _ ___ ___ _  __ _ _ __   | |_/ /_   _| |_| |_ ___  _ __  ___ 
                |    // _ \/ _` / __/ __| |/ _` | '_ \  | ___ \ | | | __| __/ _ \| '_ \/ __|
                | |\ \  __/ (_| \__ \__ \ | (_| | | | | | |_/ / |_| | |_| || (_) | | | \__ \
                \_| \_\___|\__,_|___/___/_|\__, |_| |_| \____/ \__,_|\__|\__\___/|_| |_|___/
                                            __/ |                                           
                                           |___/    


EOF
}           

LANGUAGE_SPLASH(){
    clear
cat << "EOF"
            _____ _                              _                                              
           /  __ \ |                            | |                                             
           | /  \/ |__   __ _ _ __   __ _  ___  | |     __ _ _ __   __ _ _   _  __ _  __ _  ___ 
           | |   | '_ \ / _` | '_ \ / _` |/ _ \ | |    / _` | '_ \ / _` | | | |/ _` |/ _` |/ _ \
           | \__/\ | | | (_| | | | | (_| |  __/ | |___| (_| | | | | (_| | |_| | (_| | (_| |  __/
            \____/_| |_|\__,_|_| |_|\__, |\___| \_____/\__,_|_| |_|\__, |\__,_|\__,_|\__, |\___|
                                     __/ |                          __/ |             __/ |     
                                    |___/                          |___/             |___/      



EOF
}

SCREEN_SPLASH(){
    clear
cat << "EOF"
          _____                            _____ _           _____      _   _   _                 
         /  ___|                          /  ___(_)         /  ___|    | | | | (_)
         \ `--.  ___ _ __ ___  ___ _ __   \ `--. _ _______  \ `--.  ___| |_| |_ _ _ __   __ _ ___ 
          `--. \/ __| '__/ _ \/ _ \ '_ \   `--. \ |_  / _ \  `--. \/ _ \ __| __| | '_ \ / _` / __|
         /\__/ / (__| | |  __/  __/ | | | /\__/ / |/ /  __/ /\__/ /  __/ |_| |_| | | | | (_| \__ \
         \____/ \___|_|  \___|\___|_| |_| \____/|_/___\___| \____/ \___|\__|\__|_|_| |_|\__, |___/
                                                                                         __/ |
                                                                                        |___/



EOF
}

CACHE_SPLASH(){
    clear
cat << "EOF"
   _____ _                    ___       _              _____                  _____            _
  /  __ \ |                  / _ \     | |     ___    |_   _|                /  __ \          | |
  | /  \/ | ___  __ _ _ __  / /_\ \_ __| |_   ( _ )     | |  ___ ___  _ __   | /  \/ __ _  ___| |__   ___ 
  | |   | |/ _ \/ _` | '__| |  _  | '__| __|  / _ \/\   | | / __/ _ \| '_ \  | |    / _` |/ __| '_ \ / _ \
  | \__/\ |  __/ (_| | |    | | | | |  | |_  | (_>  <  _| || (_| (_) | | | | | \__/\ (_| | (__| | | |  __/
   \____/_|\___|\__,_|_|    \_| |_/_|   \__|  \___/\/  \___/\___\___/|_| |_|  \____/\__,_|\___|_| |_|\___|



EOF
}

# Function to display the menu
display_menu() {
    EXTRAS_SPLASH
    printf "\n\n\n"
    printf "%*s%s\n\n" "$padding" "1) " "${UI_TEXT[EXTRAS_MENU_OPTION_1]}"
    printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[EXTRAS_MENU_OPTION_2]}"
    printf "%*s%s\n\n" "$padding" "3) " "${UI_TEXT[EXTRAS_MENU_OPTION_3]}"
    printf "%*s%s\n\n" "$padding" "4) " "${UI_TEXT[EXTRAS_MENU_OPTION_4]}"
    printf "%*s%s\n\n" "$padding" "5) " "${UI_TEXT[EXTRAS_MENU_OPTION_5]}"
    printf "%*s%s\n\n" "$padding" "b) " "${UI_TEXT[MENU_BACK]}"
    printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
}

error_msg() {
  error_1="$1"
  error_2="$2"
  error_3="$3"
  error_4="$4"

  echo
  echo "[X]" "$error_1"
  [ -n "$error_2" ] && echo && echo "$error_2"
  [ -n "$error_3" ] && echo "$error_3"
  [ -n "$error_4" ] && echo "$error_4"
  echo
  echo "${UI_TEXT[ERROR_TROUBLE]}"
  echo "https://github.com/CosmicScale/PSBBN-Definitive-Project#troubleshooting"
  echo
  read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}" </dev/tty
  echo
}

clean_up() {

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1
    sudo rm -rf "${SCRIPTS_DIR}/tmp"

    failure=0

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || {
                    echo "[X] Error: Failed to unmount $line" >> "${LOG_FILE}"
                    failure=1
                }
                ;;
        esac
    done

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
            echo "Some mounts remain under ${STORAGE_DIR}, not deleting." >> "$LOG_FILE"
            failure=1
        fi
    else
        echo "Directory ${STORAGE_DIR} does not exist." >> "$LOG_FILE"
    fi

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        echo "Removing existing mapper $map_name..." >> "$LOG_FILE"
        if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
            echo "Failed to delete mapper $map_name." >> "$LOG_FILE"
            failure=1
        fi
    done

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo | tee -a "${LOG_FILE}"
        echo "[X] Error: Cleanup error(s) occurred. Aborting." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_CLEANUP]}"
        return 1
    fi

}

exit_script() {
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo "[X] Error: Unable to detect the PS2 drive" >> "${LOG_FILE}"
        echo "[X] ${UI_TEXT[ERROR_DETECT_DRIVE_1]}"
        echo
        echo "${UI_TEXT[ERROR_DETECT_DRIVE_4]}"
        echo
        read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
        return 1
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

    # Find all mounted volumes associated with the device
    mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

    # Iterate through each mounted volume and unmount it
    echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
    for mount_point in $mounted_volumes; do
        echo "Unmounting $mount_point..." >> "${LOG_FILE}"
        if sudo umount "$mount_point"; then
            echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
            echo
            echo "[X] Error: Failed to unmount: $mount_point" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $mount_point"
            return 1
        fi
    done

    if ! sudo "${HDL_DUMP}" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
        return 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CREATE]} ${OPL}"
        return 1
    }

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        echo "[X] Error: Failed to mount ${DEVICE}3" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_MOUNT_2]} ${DEVICE}3"
        return 1
    fi

}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to unmount $DEVICE" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $DEVICE"
        return 1;
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

    if has_all "${psbbn_parts[@]}"; then
        echo "PSBBN Detected" >> "${LOG_FILE}"
        OS="PSBBN"
    elif has_all "${hosd_parts[@]}"; then
        echo "HOSDMenu Detected" >> "${LOG_FILE}"
        OS="HOSD"
    else
        echo "[X] Error: Failed to detect PSBBN or HOSDMenu on ${DEVICE}." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_OS_CHECK_1]}"
        return 1
    fi

}

mapper_probe() {
    DEVICE_CUT=$(basename "${DEVICE}")

    # 1) Remove existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v p="^${DEVICE_CUT}-" '$1 ~ p {print $1}')
    for map in $existing_maps; do
        sudo dmsetup remove "$map" 2>/dev/null
    done

    # 2) Build keep list
    keep_partitions=( "${LINUX_PARTITIONS[@]}" "${APA_PARTITIONS[@]}" )

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
            error_msg "[X] Error: Failed to mount ${PARTITION_NAME} partition."
            clean_up
            return 1
        fi
    else
        echo "[X] Error: Partition not found on disk: ${PARTITION_NAME}" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_MOUNT_3]} ${PARTITION_NAME}"
        clean_up
        return 1
    fi
  done
}

mount_pfs() {
    for PARTITION_NAME in "${APA_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        mkdir -p "$MOUNT_POINT"
        if ! sudo "${PFS_FUSE}" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to mount $PARTITION_NAME" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_MOUNT_2]} $PARTITION_NAME"
            clean_up
            return 1
        fi
    done
}

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    local exit_code

    # Print initial spinner
    echo
    printf "\r[%c] %s" "${spinstr:0:1}" "$message"

    # Animate while the process is running
    while kill -0 "$pid" 2>/dev/null; do
        for i in {0..3}; do
            printf "\r[%c] %s" "${spinstr:i:1}" "$message"
            sleep $delay
        done
    done

    # Wait for the process to capture its exit code
    wait "$pid"
    exit_code=$?

    # Replace spinner with success/failure
    if [ $exit_code -eq 0 ]; then
        printf "\r[✓] %s\n" "$message" | tee -a "${LOG_FILE}"
    else
        printf "\r[X] %s\n" "$message" | tee -a "${LOG_FILE}"
    fi
}

download_linux() {
    TARGET_MD5="a16eeabf87c97d4112f73f4c3df52091"

    # Check if file exists
    if [[ -f "${ASSETS_DIR}/PS2Linux.tar.gz" ]]; then
        # Get md5 checksum
        FILE_MD5=$(md5sum "${ASSETS_DIR}/PS2Linux.tar.gz" | awk '{print $1}')

        # Compare and delete if matches
        if [[ "$FILE_MD5" == "$TARGET_MD5" ]]; then
            rm -f "${ASSETS_DIR}/PS2Linux.tar.gz"
            echo "Deleted ${ASSETS_DIR}/PS2Linux.tar.gz (MD5 matched)" >> "${LOG_FILE}"
        else
            echo "MD5 of ${ASSETS_DIR}/PS2Linux.tar.gz does not match, file not deleted." >> "${LOG_FILE}"
        fi
    fi

    if [ -f "${ASSETS_DIR}/PS2Linux.tar.gz" ] && [ ! -f "${ASSETS_DIR}/PS2Linux.tar.gz.st" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" >> "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Downloading PS2 Linux..." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLOAD_REQUIRED]}"
        if axel -a https://archive.org/download/psbbn-definitive-patch-v4.1/PS2Linux.tar.gz -o "${ASSETS_DIR}"; then
            echo "[✓] Download completed successfully." >> "${LOG_FILE}"
            echo "[✓] ${UI_TEXT[DOWNLOAD_COMPLETE]}"
        else
            echo "[X] Error: PS2 Linux Download failed." >> "${LOG_FILE}"
            error_msg "[X] ${UI_TEXT[ERROR_DOWNLOAD]}" "${UI_TEXT[GET_LATEST_FILE_3]}"
            return 1
        fi
    fi
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    echo "[X] Error: PFS Shell returned an error." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_PFS_COMMANDS]}"
    return 1
fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
        return 1
    fi
}

AVAILABLE_SPACE(){
    HDL_TOC || return 1
    # Extract the "used" value, remove "MB" and any commas
    used=$(cat "$hdl_output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')

    # Calculate available space (APA_SIZE - used)
    available=$((APA_SIZE - used - 6400 - 128))
    free_space=$((available / 1024))
    echo "Free Space: $free_space GB" >> "${LOG_FILE}"
}

get_latest_file() {
    local prefix="$1"        # e.g., "psbbn-eng" or "psbbn-definitive-patch"
    local display="$2"       # e.g., "English language pack"
    local remote_list remote_versions remote_version
    local local_file local_version

    # Reset globals
    LATEST_FILE=""

    # Extract .gz filenames from the HTML
    remote_list=$(grep -oP "${prefix}-v[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz" "$HTML_FILE" 2>/dev/null)

    if [[ -n "$remote_list" ]]; then
    # Extract version numbers and sort them
        remote_versions=$(echo "$remote_list" | \
            grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | \
            sed 's/v//' | \
            sort -V)
        remote_version=$(echo "$remote_versions" | tail -n1)
        echo | tee -a "${LOG_FILE}"
        echo "Found $display version $remote_version" >> "${LOG_FILE}"
        echo "${UI_TEXT[GET_LATEST_FILE_1]} $display $remote_version"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Could not find the latest version of the $display." >> "${LOG_FILE}"
        echo "${UI_TEXT[GET_LATEST_FILE_2]} $display."
        echo "${UI_TEXT[GET_LATEST_FILE_3]}"
    fi

   # Check if any local file is newer than the remote version
    local_file=$(ls "${ASSETS_DIR}/${prefix}"*.tar.gz 2>/dev/null | sort -V | tail -n1)
    if [[ -n "$local_file" ]]; then
        local_version=$(basename "$local_file" | sed -E 's/.*-v([0-9.]+)\.tar\.gz/\1/')
    fi

    #Decide which file wins
    if [[ -n "$local_file" ]]; then
        if [[ -z "$remote_version" ]] || \
           [[ "$(printf '%s\n' "$remote_version" "$local_version" | sort -V | tail -n1)" == "$local_version" ]]; then

            # Local is equal/newer then local wins
            LATEST_FILE=$(basename "$local_file")
            echo
            echo "Newer local file found: ${LATEST_FILE}" >> "${LOG_FILE}"
            echo "${UI_TEXT[GET_LATEST_FILE_4]} ${LATEST_FILE}"

            # Only set LATEST_VERSION for the patch prefix
            if [[ "$prefix" == "language-pak-$lang" ]]; then
                LATEST_LANG="$local_version"
            elif [[ "$prefix" == "channels-$lang" ]]; then
                LATEST_CHAN="$local_version"
            fi
            return 0
        fi
    fi

    # Remote exists and is newer then remote wins
    if [[ -n "$remote_version" ]]; then
        LATEST_FILE="${prefix}-v${remote_version}.tar.gz"

        # Only set LATEST_VERSION for the patch prefix
        if [[ "$prefix" == "language-pak-$lang" ]]; then
            LATEST_LANG="$remote_version"
        elif [[ "$prefix" == "channels-$lang" ]]; then
            LATEST_CHAN="$remote_version"
        fi
        return 0
    fi

    # If neither version exists error
    echo "[X] Error: Failed to find: ${display}" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_GET_LATEST_FILE]} ${display}"
    return 1
}

downoad_latest_file() {
    local prefix="$1"
    # Check if the latest file exists in ${ASSETS_DIR}
    if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "${LATEST_FILE} already exists. Skipping download." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLOAD_LATEST_FILE_1]}"
    else
        # Check for and delete older files
        for file in "${ASSETS_DIR}"/$prefix*.tar.gz; do
            if [[ -f "$file" && "$(basename "$file")" != "$LATEST_FILE" ]]; then
                echo "Deleting old file: $file" >> "${LOG_FILE}"
                rm -f "$file"
            fi
        done

        # Construct the full URL for the .gz file and download it
        TAR_URL="$URL/$LATEST_FILE"
        echo "Downloading ${LATEST_FILE}..." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLAD_LATEST_FILE_2]}"
        axel -n 8 -a "$TAR_URL" -o "${ASSETS_DIR}"

        # Check if the file was downloaded successfully
        if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
            echo "Download completed: ${LATEST_FILE}" >> "${LOG_FILE}"
            echo "${UI_TEXT[DOWNLOAD_LATEST_FILE_3]} ${LATEST_FILE}"
        else
            echo "[X] Error: Download failed for ${LATEST_FILE}." "Please check your internet connection and try again." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_LATEST_FILE_1]} ${LATEST_FILE}." "${UI_TEXT[ERROR_LATEST_FILE_2]}"
            return 1
        fi
    fi

}

# Function for Option 1 - Install PS2 Linux
option_one() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Install PS2 Linux:" >> "${LOG_FILE}"
    LINUX_SPLASH
    if [ "$OS" = "HOSD" ]; then
        echo "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_OS_CHECK_2]}"
        return 1
    fi

    clean_up
    MOUNT_OPL || return 1
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    APA_SIZE=$(awk -F' *= *' '$1=="APA_SIZE"{print $2}' "${OPL}/version.txt")
    
    UNMOUNT_OPL || return 1

    version_check="4.0.0"

    HDL_TOC || return 1

    if cat "${hdl_output}" | grep -q '\b__linux\.3\b'; then
        linux3="yes"
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            echo "[X] Error: Linux is already installed on your PS2. If you want to reinstall Linux, update to PSBBN version 4.0.0 or higher first." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_PS2_LINUX_1]}" " " "${UI_TEXT[ERROR_PS2_LINUX_2]}"
            return 1
        else
            while true; do
                LINUX_SPLASH
                echo "Reinstall PS2 Linux?" >> "${LOG_FILE}"
                printf '\n%s\n\n' "${UI_TEXT[PS2_LINUX_1]}"
                if cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
                    echo "Home partition found."  >> "${LOG_FILE}"
                    printf '%s\n' "${UI_TEXT[PS2_LINUX_2]}"
                    printf '%s\n\n' "${UI_TEXT[PS2_LINUX_3]}"
                else
                    echo
                    echo "Home partition not found."  >> "${LOG_FILE}"
                    center_title "${UI_TEXT[WARNING]}"
                    printf '\n  %s\n' "${UI_TEXT[PS2_LINUX_4]}"
                    printf '  %s\n\n' "${UI_TEXT[PS2_LINUX_5]}"
                    printf "==============================================================================================================\n\n"
                fi
                
                read -rp "${UI_TEXT[PS2_LINUX_6]} (y/n): " answer
                case "$answer" in
                    [Yy])
                        break
                        ;;
                    [Nn])
                        return 0
                        ;;
                    *)
                        echo
                        echo -n "${UI_TEXT[MENU_INVALID]}"
                        sleep 3
                        ;;
                esac
            done
        fi
    fi

    LINUX_SPLASH

    if [ "$linux3" != "yes" ]; then
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            echo "[X] Error: To install or reinstall PS2 Linux, update to PSBBN version 4.0.0 or higher." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_PS2_LINUX_3]}"
            return 1
        else
            if [ -z "$APA_SIZE" ]; then
                echo "[X] Error: Unable to determine APA free space." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_PS2_LINUX_4]}"
                return 1
            else
                AVAILABLE_SPACE || return 1
                if [ "$free_space" -lt 3 ]; then
                    echo "[X] Error: Insufficient disk space. At least 3 GB of free space is required to install Linux." >> "${LOG_FILE}"
                    error_msg "${UI_TEXT[ERROR_PS2_LINUX_5]}"
                    return 1
                else
                    free_space=$((free_space -2))
                fi
            fi
        fi
    fi

    download_linux || return 1

    LINUX_SPLASH

    if [ "$linux3" == "yes" ]; then
        HDL_TOC || return 1
        LINUX_SIZE=$(grep '__linux\.3' "$hdl_output" | awk '{print $4}' | grep -oE '[0-9]+')
        if [ "$LINUX_SIZE" -gt 2048 ]; then
            COMMANDS="device ${DEVICE}\n"
            COMMANDS+="rmpart __linux.3\n"
            COMMANDS+="exit"
            PFS_COMMANDS || return 1
            linux3="no"
        fi
    fi

    if ! cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
        echo "Free Space available for home partition: $free_space GB" >> "${LOG_FILE}"

        while true; do
            printf '\n%s\n' "${UI_TEXT[PS2_LINUX_8]}"
            printf '%s\n' "${UI_TEXT[PS2_LINUX_9]}"
            printf '%s\n\n' "${UI_TEXT[PARTITION_SIZE_1]} $free_space GB"

            read -rp "${UI_TEXT[PARTITION_SIZE_2]} " home_gb

            if [[ ! "$home_gb" =~ ^[0-9]+$ ]]; then
                echo
                echo -n "${UI_TEXT[PARTITION_SIZE_3]}"
                sleep 3
                continue
            fi

            if (( home_gb < 1 || home_gb > free_space )); then
                echo
                echo "${UI_TEXT[PARTITION_SIZE_4]} $free_space GB"
                sleep 3
                continue
            fi
            break
        done

        echo "Home partition size: $home_gb" >> "${LOG_FILE}"
        home_mb=$((home_gb * 1024))
    fi

    if [[ "$linux3" != "yes" || -n "$home_gb" ]]; then
        COMMANDS="device ${DEVICE}\n"

        if [ "$linux3" != "yes" ]; then
            COMMANDS+="mkpart __linux.3 2048M EXT2\n"
        fi

        if [ -n "$home_gb" ]; then
            COMMANDS+="mkpart __linux.10 ${home_mb}M EXT2\n"
        fi

        COMMANDS+="exit"
        echo "Creating partitions..." >>"${LOG_FILE}"
        PFS_COMMANDS || return 1
    fi

    echo | tee -a "${LOG_FILE}"
    echo "Installing PS2 Linux..." >> "${LOG_FILE}"
    echo -n "${UI_TEXT[PS2_LINUX_10]}"

    LINUX_PARTITIONS=("__linux.3" )
    APA_PARTITIONS=("__system" "__sysconf" )

    clean_up   && \
    mapper_probe || return 1

    mount_cfs    && \
    mount_pfs    || return 1

    if ! sudo tar zxpf "${ASSETS_DIR}/PS2Linux.tar.gz" -C "${STORAGE_DIR}/__linux.3" >>"${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to extract files. Install Failed." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PS2_LINUX_6]}"
        return 1
    fi

    cp -f "${ASSETS_DIR}/kernel/ps2-linux-"{ntsc,vga} "${STORAGE_DIR}/__system/p2lboot/" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to copy kernel files." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PS2_LINUX_7]}"
        return 1
    }

    TMP_FILE=$(mktemp /tmp/OSDMBR.XXXXXX)
    cp -f "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "$TMP_FILE" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to copy: ${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_COPY]} ${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"
        return 1
    }

    # Remove any existing boot_circle lines
    sed -i '/^boot_circle/d' "$TMP_FILE" 2>> "${LOG_FILE}"

    # Ensure the file ends with a newline
[   -n "$(tail -c1 "$TMP_FILE" | tr -d '\n')" ] && echo >> "$TMP_FILE"

    # Append new PSBBN boot entries
    {
        echo 'boot_circle = $PSBBN'
        echo 'boot_circle_arg1 = --kernel'
        echo 'boot_circle_arg2 = pfs0:/p2lboot/ps2-linux-ntsc'
        echo 'boot_circle_arg3 = -noflags'
    } >> "$TMP_FILE"
    cp -f $TMP_FILE "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to copy: $TMP_FILE" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_COPY]} $TMP_FILE"
        return 1
        }

    clean_up || return 1

    LINUX_SPLASH
    echo "[✓] PS2 Linux Successfully Installed" >> "${LOG_FILE}"
    center_title "[✓] ${UI_TEXT[PS2_LINUX_11]}"

    printf '\n  %s\n\n' "${UI_TEXT[PS2_LINUX_12]}"
    printf '  %s\n\n' "${UI_TEXT[PS2_LINUX_13]}"
    printf '  %s\n' "${UI_TEXT[PS2_LINUX_14]}"
    printf '  %s\n\n' "${UI_TEXT[PS2_LINUX_15]}"
    printf '  %s\n\n' "${UI_TEXT[PS2_LINUX_16]}"
    printf "==============================================================================================================\n\n"
    center_text "${UI_TEXT[CONTINUE]}"
    read -n 1 -s -r -p "$text" </dev/tty

}

# Function for Option 2 - Reassign X and O Buttons
option_two() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Reassign Buttons:" >> "${LOG_FILE}"
    SWAP_SPLASH

    clean_up
    if [ "$OS" = "HOSD" ]; then
        echo "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_OS_CHECK_2]}"
        return 1
    fi

    MOUNT_OPL   || return 1
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 3.00. To update, please select 'Install PSBBN' from the main menu and try again." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 3.00" " " "${UI_TEXT[ERROR_VERSION_5]}"
        UNMOUNT_OPL
        return 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "3.00" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "3.00" ]]; then
        echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 3.00. To update, please select Update PSBBN Software from the main menu and try again." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 3.00" " " "${UI_TEXT[ERROR_VERSION_6]}"
        UNMOUNT_OPL
        return 1
    fi

    choice=""
    while :; do
        SWAP_SPLASH
        MENU_KEYS=(
            REASSIGN_BUTTONS_1
            REASSIGN_BUTTONS_2
            REASSIGN_BUTTONS_3
        )
        center_menu
        printf "\n\n\n"
        printf "%*s%s\n\n" "$((padding - 3))" "" "${UI_TEXT[REASSIGN_BUTTONS_1]}"
        printf "%*s%s\n\n" "$padding" "1) " "${UI_TEXT[REASSIGN_BUTTONS_2]}"
        printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[REASSIGN_BUTTONS_3]}"
        printf "%*s%s\n\n" "$padding" "b) " "${UI_TEXT[MENU_BACK]}"
        printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
        read -rp "" choice

        case "$choice" in
            1|2|b|B)
            break
            ;;
            *)
            printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
            sleep 3
            ;;
        esac
    done

    if [[ "$choice" == "1" ]]; then
        BUTTON="X"
        OPL_ENTER="1"
        R3CONFIG_ENTER="0"
    else
        BUTTON="O"
        OPL_ENTER="0"
        R3CONFIG_ENTER="1"
    fi

    if grep -q '^ENTER =' "$OPL/version.txt" 2>> "${LOG_FILE}"; then
        sed -i "s/^ENTER =.*/ENTER = $BUTTON/" "$OPL/version.txt" || {
            echo "[X] Error: Failed to update button config in version.txt." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "$OPL/version.txt"
            UNMOUNT_OPL
            return 1
        }
    else
        echo "ENTER = $BUTTON" >> "$OPL/version.txt" || {
            echo "[X] Error: Failed to add button config to version.txt." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "$OPL/version.txt"
            UNMOUNT_OPL
            return 1
        }
    fi

    if grep -q '^swap_select_btn=' "${OPL}/conf_opl.cfg" 2>> "${LOG_FILE}"; then
        sed -i "s/^swap_select_btn=.*/swap_select_btn=$OPL_ENTER/" "${OPL}/conf_opl.cfg" || {
            echo "[X] Error: Failed to update button config in conf_opl.cfg." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/conf_opl.cfg"
            UNMOUNT_OPL
            return 1
    }
    else
        echo "swap_select_btn=$OPL_ENTER" >> "${OPL}/conf_opl.cfg" || {
            echo "[X] Error: Failed to add button config to conf_opl.cfg." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/conf_opl.cfg"
            UNMOUNT_OPL
            return 1
        }
    fi

    if [[ -d "${OPL}/APPS/SYS_R3CONFIGURATOR" ]]; then
        if grep -q '^swap_select_btn =' "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" 2>> "${LOG_FILE}"; then
        sed -i "s/^swap_button[[:space:]]*=.*/swap_buttons = $R3CONFIG_ENTER/" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" || {
            echo "[X] Error: Failed to update button config in r3configurator.cnf." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf"
            UNMOUNT_OPL
            return 1
        }
        else
            echo "swap_buttons = $R3CONFIG_ENTER" >> "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" || {
                echo "[X] Error: Failed to add button config to r3configurator.cnf." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf"
                UNMOUNT_OPL
                return 1
            }
        fi
    fi

    UNMOUNT_OPL || return 1

    LINUX_PARTITIONS=("__linux.4" )
    APA_PARTITIONS=("__system" )

    mapper_probe && \
    mount_cfs    && \
    mount_pfs    || return 1

    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    case "$choice" in
        1)
            echo "Western layout selected." >> "${LOG_FILE}"
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
            then
                SWAP_SPLASH
                echo "[✓] Buttons Swapped Successfully" >> "${LOG_FILE}"
                center_title "[✓] ${UI_TEXT[REASSIGN_BUTTONS_4]}"
                echo
                center_text "${UI_TEXT[CONTINUE]}"
                read -n 1 -s -r -p "$text" </dev/tty
            else
                SWAP_SPLASH
                echo "[X] Error: Failed to swap buttons." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_REASSIGN_BUTTONS_3]}"
                return 1
            fi
            ;;

                
        2)
            echo "Japanese layout selected." >> "${LOG_FILE}"
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
            then
                SWAP_SPLASH
                echo "[✓] Buttons Swapped Successfully" >> "${LOG_FILE}"
                center_title "[✓] ${UI_TEXT[REASSIGN_BUTTONS_4]}"
                echo
                center_text "${UI_TEXT[CONTINUE]}"
                echo
                read -n 1 -s -r -p "$text" </dev/tty
            else
                SWAP_SPLASH
                echo "[X] Error: Failed to swap buttons." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_REASSIGN_BUTTONS_3]}"
                return 1
            fi
            ;;
        b|B)
            ;;
    esac

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"
}


option_three() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Change Language:" >> "${LOG_FILE}"
    
    LANGUAGE_SPLASH

    clean_up
    MOUNT_OPL   || return 1
    
    if [ "$OS" = "PSBBN" ]; then
        psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
        ENTER=$(awk -F' *= *' '$1=="ENTER"{print $2}' "${OPL}/version.txt")
        SCREEN=$(awk -F' *= *' '$1=="SCREEN"{print $2}' "${OPL}/version.txt")

        if [[ -z "$ENTER" ]]; then
            if [[ "$lang" == "jpn" ]]; then
                echo "ENTER = O" >> "$OPL/version.txt"
            else
                echo "ENTER = X" >> "$OPL/version.txt"
            fi
        fi

        if [[ -z "$SCREEN" ]]; then
            echo "SCREEN = 4:3" >> "$OPL/version.txt"
        fi

        if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
            # $psbbn_version < 2.10
            echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 4.1.0. To update, please select 'Install PSBBN' from the main menu and try again." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 4.1.0" " " "${UI_TEXT[ERROR_VERSION_5]}"
            UNMOUNT_OPL
            return 1
        elif [[ "$(printf '%s\n' "$psbbn_version" "4.1.0" | sort -V | head -n1)" = "$psbbn_version" ]] \
            && [[ "$psbbn_version" != "4.1.0" ]]; then
            echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 4.1.0. To update, please select Update PSBBN Software from the main menu and try again." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 4.1.0" " " "${UI_TEXT[ERROR_VERSION_6]}"
            UNMOUNT_OPL
            return 1
        fi
    fi

    while :; do
        LANGUAGE_SPLASH
        MENU_KEYS=(
            CHANGE_LANGUAGE_1
            CHANGE_LANGUAGE_2
            CHANGE_LANGUAGE_3
            CHANGE_LANGUAGE_4
            CHANGE_LANGUAGE_5
            CHANGE_LANGUAGE_6
            CHANGE_LANGUAGE_7
            CHANGE_LANGUAGE_8
            CHANGE_LANGUAGE_9
        )
        center_menu
        printf "%*s%s\n\n" "$((padding - 3))" "" "${UI_TEXT[CHANGE_LANGUAGE_1]}"
        printf "%*s%s\n\n" "$padding" "1) " "${UI_TEXT[CHANGE_LANGUAGE_2]}"
        printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[CHANGE_LANGUAGE_3]}"
        printf "%*s%s\n\n" "$padding" "3) " "${UI_TEXT[CHANGE_LANGUAGE_4]}"
        printf "%*s%s\n\n" "$padding" "4) " "${UI_TEXT[CHANGE_LANGUAGE_5]}"
        printf "%*s%s\n\n" "$padding" "5) " "${UI_TEXT[CHANGE_LANGUAGE_6]}"
        printf "%*s%s\n\n" "$padding" "6) " "${UI_TEXT[CHANGE_LANGUAGE_7]}"
        printf "%*s%s\n\n" "$padding" "7) " "${UI_TEXT[CHANGE_LANGUAGE_8]}"
        printf "%*s%s\n\n" "$padding" "8) " "${UI_TEXT[CHANGE_LANGUAGE_9]}"
        printf "%*s%s\n\n" "$padding" "b) " "${UI_TEXT[MENU_BACK]}"
        printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
        read -rp "" choice

        case "$choice" in
            1)
                lang="eng"
                OPL_LANG="English (internal)"
                R3CONFIG_LANG="en"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_2]}"
                break
                ;;
            2)
                lang="jpn"
                OPL_LANG="japanese"
                R3CONFIG_LANG="en"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_3]}"
                break
                ;;
            3)
                lang="fre"
                OPL_LANG="French"
                R3CONFIG_LANG="fr"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_4]}"
                break
                ;;
            4)
                lang="ger"
                OPL_LANG="German"
                R3CONFIG_LANG="en"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_5]}"
                break
                ;;
            5)
                lang="hun"
                OPL_LANG="Hungarian"
                R3CONFIG_LANG="en"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_6]}"
                break
                ;;
            6)
                lang="ita"
                OPL_LANG="Italian"
                R3CONFIG_LANG="en"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_7]}"
                break
                ;;
            7)
                lang="por"
                OPL_LANG="Portuguese_BR"
                R3CONFIG_LANG="pt"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_8]}"
                break
                ;;
            8)
                lang="spa"
                OPL_LANG="Spanish"
                R3CONFIG_LANG="es"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_9]}"
                break
                ;;
            b|B)
                UNMOUNT_OPL
                return 0
                ;;
            *)
                echo
                printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
                sleep 3
                ;;
        esac
    done

    echo "Language selected: $LANG_DISPLAY" >> "${LOG_FILE}"

    LANGUAGE_SPLASH

    cp "${ASSETS_DIR}/OPL/LNG"/* "${OPL}/LNG" >> "${LOG_FILE}" 2>&1

    if [[ "$lang" == "jpn" ]]; then
        rm -f "${OPL}/POPS/"{IGR_BG.TM2,IGR_NO.TM2,IGR_YES.TM2} 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to update POPS IGR textures." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_9]}"
            UNMOUNT_OPL
            return 1
    }
    else
        cp -f "${ASSETS_DIR}/POPStarter/$lang/"{IGR_BG.TM2,IGR_NO.TM2,IGR_YES.TM2} "${OPL}/POPS/" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to update POPS IGR textures." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_9]}"
            UNMOUNT_OPL
            return 1
        }
    fi

    if grep -q '^^language_text=' "${OPL}/conf_opl.cfg" 2>> "${LOG_FILE}"; then
    sed -i "s/^language_text=.*/language_text=$OPL_LANG/" "${OPL}/conf_opl.cfg" || {
        echo "[X] Error: Failed to update button config in conf_opl.cfg." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/conf_opl.cfg"
        UNMOUNT_OPL
        return 1
    }
    else
        echo "language_text=$OPL_LANG" >> "${OPL}/conf_opl.cfg" || {
            echo "[X] Error: Failed to add button config to conf_opl.cfg." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/conf_opl.cfg"
            UNMOUNT_OPL
            return 1
        }
    fi

    if [[ -d "${OPL}/APPS/SYS_R3CONFIGURATOR" ]]; then
        if grep -q '^swap_select_btn =' "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" 2>> "${LOG_FILE}"; then
        sed -i "s/^default_language[[:space:]]*=.*/default_language = $R3CONFIG_LANG/" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" || {
            echo "[X] Error: Failed to update button config in r3configurator.cnf." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf"
            UNMOUNT_OPL
            return 1
        }
        else
            echo "default_language = $R3CONFIG_LANG" >> "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf" || {
                echo "[X] Error: Failed to add button config to r3configurator.cnf." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_3]}" "${OPL}/APPS/SYS_R3CONFIGURATOR/r3configurator.cnf"
                UNMOUNT_OPL
                return 1
            }
        fi
    fi

    if [ "$OS" = "PSBBN" ]; then
        # Download the HTML of the page
        HTML_FILE=$(mktemp)
        timeout 20 wget -O "$HTML_FILE" "$URL" -o - >> "$LOG_FILE" 2>&1 &
        WGET_PID=$!

        spinner $WGET_PID "${UI_TEXT[CHANGE_LANGUAGE_10]}"

        get_latest_file "language-pak-$lang" "$LANG_DISPLAY ${UI_TEXT[CHANGE_LANGUAGE_11]}" || return 1
        downoad_latest_file "language-pak-$lang" || return 1
        LANG_PACK="${ASSETS_DIR}/${LATEST_FILE}"

        if [[ "$lang" == "jpn" ]]; then
            get_latest_file "channels-$lang" "$LANG_DISPLAY channels" || return 1
            downoad_latest_file "channels" || return 1
            CHANNELS="${ASSETS_DIR}/${LATEST_FILE}"
        fi

        echo
        echo -n "${UI_TEXT[CHANGE_LANGUAGE_12]}"
        {
            sed -i "s/^LANG =.*/LANG = $lang/" "$OPL/version.txt" &&
            sed -i "s|^LANG_VER =.*|LANG_VER = $LATEST_LANG|" "$OPL/version.txt" &&
            sed -i "s|^CHAN_VER =.*|CHAN_VER = $LATEST_CHAN|" "$OPL/version.txt"
        } >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to update version.txt." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_UPDATE_VER]}"
            return 1
        }

        LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.9" )
        APA_PARTITIONS=("__system" "__sysconf" "__common")

        clean_up   && \
        mapper_probe || return 1
        mount_cfs    && \
        mount_pfs    || return 1

        ls -l /dev/mapper >> "${LOG_FILE}"
        df >> "${LOG_FILE}"

        sudo tar zxpf "$LANG_PACK" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || {
            echo "[X] Error: Failed to install language pack: $LANG_DISPLAY" >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_2]}"
            return 1
        }

        if [[ "$lang" == "jpn" ]]; then
            cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" 2>> "${LOG_FILE}" || {
                echo "[X] Error: Failed to copy kernel file." >> "$LOG_FILE"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_5]}"
                return 1
            }
            sudo tar zxpf "${CHANNELS}" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || {
                echo "[X] Error: Failed to install channels." >> "$LOG_FILE"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_4]}"
                return 1
            }
        else
            cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" 2>> "${LOG_FILE}" || {
                echo "[X] Error: Failed to copy kernel file." >> "$LOG_FILE"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_5]}"
                return 1
            }
        fi

        mkdir -p "${SCRIPTS_DIR}/tmp"

        case "$lang" in
            ger|ita|por|spa|fre|dut|rus|kor|tch|sch)
                OSD_LANG="$lang"
                ;;
            jpn)
                OSD_LANG="jap"
                ;;
            *)
                OSD_LANG="eng"
                ;;
        esac

        {
            cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}" &&
            sed -i "s/^osd_language =.*/osd_language = $OSD_LANG/" "${OSDMBR_CNF}" &&
            cp -f "${OSDMBR_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"
        } >> "${LOG_FILE}" 2>&1 || {
            echo  "[X] Error: Failed to update OSDMBR.CNF." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_6]}"
            return 1
        }
        
        # Update buttons
        if [[ "$ENTER" == "O" ]] || { [[ -z "$ENTER" ]] && [[ "$lang" == "jpn" ]]; }; then
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
                echo "Enter button swapped to O" >> "${LOG_FILE}"
            else
                echo "[X] Error: Failed to swap enter button." >> "$LOG_FILE"

            fi
        elif [[ "$ENTER" == "X" ]] || { [[ -z "$ENTER" ]] && [[ "$lang" != "jpn" ]]; }; then
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
                echo "Enter button swapped to X" >> "${LOG_FILE}"
            else
                echo "Failed to swap enter button. See log for details." >> "$LOG_FILE"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_7]}"
            fi
        fi

        if [[ "$SCREEN" == "full" ]]; then
            SIZE_NAME="Full"
            case "$lang" in
                jpn) SIZE_NAME="フル" ;;
                fre) SIZE_NAME="Plein écran" ;;
                spa) SIZE_NAME="Pantalla Completa" ;;
                ger) SIZE_NAME="Ganzer Bildschirm" ;;
                ita) SIZE_NAME="Schermo Intero" ;;
                dut) SIZE_NAME="Volledig" ;;
                por) SIZE_NAME="Completo" ;;
                hun) SIZE_NAME="Teljes" ;;
            esac
        elif [[ "$SCREEN" == "16:9" ]]; then
            SIZE_NAME="16:9"
        fi

        if [[ "$SCREEN" == "full" || "$SCREEN" == "16:9" ]]; then
            mkdir -p "${SCRIPTS_DIR}/tmp"

            {
                sudo cp "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" "${SYSCONF_XML}" &&
                sed -i "/<menu id=\"sysconf_value_2_0\">/,/<\/menu>/ {
                    /<item value=/ {
                        s|<item value=.*|<item value=\"$SIZE_NAME\"/>|
                        :done
                        n
                        b done
                    }
                }" "${SYSCONF_XML}" &&
                sudo cp -f "${SYSCONF_XML}" "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml"
            } >> "${LOG_FILE}" 2>&1 || {
                echo "[X] Error: Failed to update sysconf.xml." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_CHANGE_LANGUAGE_8]}"
                return 1
            }
        fi
    else
        sed -i "s/^LANG =.*/LANG = $lang/" "$OPL/version.txt" || {
            echo "[X] Error: Failed to update version.txt." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_UPDATE_VER]}"
            return 1
        }
    fi

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    LANGUAGE_SPLASH
    echo "[✓] Language Successfully Changed to: $LANG_DISPLAY" >> "${LOG_FILE}"
    center_title "[✓] ${UI_TEXT[CHANGE_LANGUAGE_13]} $LANG_DISPLAY"

    printf '\n  %s\n\n' "${UI_TEXT[CHANGE_LANGUAGE_14]}"

    if [ "$OS" = "PSBBN" ]; then
        printf '  %s\n\n' "${UI_TEXT[CHANGE_LANGUAGE_15]}"
        if [[ -z "$ENTER" ]]; then
            printf '  %s\n\n' "${UI_TEXT[CHANGE_LANGUAGE_16]}"
        fi
    else
        printf '  %s\n\n' "${UI_TEXT[CHANGE_LANGUAGE_17]}"
    fi
    printf "==============================================================================================================\n\n"
    center_text "${UI_TEXT[CONTINUE]}"
    read -n 1 -s -r -p "$text" </dev/tty
}

option_four() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Change Screen Size:" >> "${LOG_FILE}"

    SCREEN_SPLASH

    clean_up

    if [ "$OS" = "HOSD" ]; then
        echo "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_OS_CHECK_2]}"
        return 1
    fi

    MOUNT_OPL   || return 1

    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 4.0. 0. To update, please select 'Install PSBBN' from the main menu and try again." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 4.0.0" " " "${UI_TEXT[ERROR_VERSION_5]}"
        return 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "4.0.0" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "4.0.0" ]]; then
        echo "[X] Error: PSBBN Definitive Patch version $psbbn_version is lower than the required version of 4.0.0. To update, please select Update PSBBN Software from the main menu and try again." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_VERSION_3]} $psbbn_version" "${UI_TEXT[ERROR_VERSION_4]} 4.0.0" " " "${UI_TEXT[ERROR_VERSION_6]}"
        return 1
    fi

    lang=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")
    echo "Language: $lang" >> "${LOG_FILE}"

        while :; do
        SCREEN_SPLASH
        MENU_KEYS=(
            SCREEN_SIZE_1
        )
        center_menu
        printf "%*s%s\n\n" "$((padding - 3))" "" "${UI_TEXT[SCREEN_SIZE_1]}"
        printf "%*s%s\n\n" "$padding" "1) " "4:3"
        printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[SCREEN_SIZE_2]}"
        printf "%*s%s\n\n" "$padding" "3) " "16:9"
        printf "%*s%s\n\n" "$padding" "b) " "${UI_TEXT[MENU_BACK]}"
        printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
        read -rp "" choice

        case "$choice" in
            1)
                SCREEN_SIZE="4:3"
                SIZE_NAME="4:3"
                break
                ;;
            2)
                SCREEN_SIZE="full"
                SIZE_NAME="Full"
                case "$lang" in
                    jpn) SIZE_NAME="フル" ;;
                    fre) SIZE_NAME="Plein écran" ;;
                    spa) SIZE_NAME="Pantalla Completa" ;;
                    ger) SIZE_NAME="Ganzer Bildschirm" ;;
                    ita) SIZE_NAME="Schermo Intero" ;;
                    dut) SIZE_NAME="Volledig" ;;
                    por) SIZE_NAME="Completo" ;;
                    hun) SIZE_NAME="Teljes" ;;
                esac
                break
                ;;
            3)
                SCREEN_SIZE="16:9"
                SIZE_NAME="16:9"
                break
                ;;
            b|B)
                UNMOUNT_OPL
                return 0
                ;;
            *)
                echo
                printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
                sleep 3
                ;;
        esac
    done

    echo "Screen size selected: $SCREEN_SIZE" >> "${LOG_FILE}"
    echo "Screen size name: $SIZE_NAME" >> "${LOG_FILE}"

    if grep -q '^SCREEN =' "$OPL/version.txt"; then
        sed -i "s/^SCREEN =.*/SCREEN = $SCREEN_SIZE/" "$OPL/version.txt" || {
            echo "[X] Error: Failed to update version.txt." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_UPDATE_VER]}"
            return 1
        }
    else
        echo "SCREEN = $SCREEN_SIZE" >> "$OPL/version.txt" || {
            echo "[X] Error: Failed to update version.txt." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_UPDATE_VER]}"
            return 1
        }
    fi

    LINUX_PARTITIONS=("__linux.4")
    APA_PARTITIONS=("__sysconf")

    clean_up   && \
    mapper_probe || return 1
    mount_cfs    && \
    mount_pfs    || return 1

    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    mkdir -p "${SCRIPTS_DIR}/tmp"
    cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}" || {
        echo "[X] Error: Failed to copy OSDMBR.CNF." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_1]}"
        return 1
    }

    # OSDMBR.CNF - Update osd_screentype if exists, otherwise append it
    if grep -q '^osd_screentype =' "${OSDMBR_CNF}"; then
        sed -i "s/^osd_screentype =.*/osd_screentype = $SCREEN_SIZE/" "${OSDMBR_CNF}" || {
            echo "[X] Error: Failed to update osd_screentype in OSDMBR.CNF." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_2]}"
            return 1
        }
    else
        # Ensure the file ends with a newline
        [ -n "$(tail -c1 "$OSDMBR_CNF" | tr -d '\n')" ] && echo >> "$OSDMBR_CNF"

        echo "osd_screentype = $SCREEN_SIZE" >> "${OSDMBR_CNF}" || {
            echo "[X] Error: Failed to add osd_screentype in OSDMBR.CNF." >> "$LOG_FILE"
            error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_3]}"
            return 1
        }
    fi

    cp -f "${OSDMBR_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" || {
        echo "[X] Error: Failed to replace OSDMBR.CNF." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_4]}"
        return 1
    }

    # Update sysconf.xml
    sudo cp "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" "${SYSCONF_XML}" || {
        echo "[X] Error: Failed to copy sysconf.xml" >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_5]}"
        return 1
    }

   # Use sed to replace the first <item value= inside the menu block
    sed -i "/<menu id=\"sysconf_value_2_0\">/,/<\/menu>/ {
        /<item value=/ {
            s|<item value=.*|<item value=\"$SIZE_NAME\"/>|
            :done
            n
            b done
        }
    }" "$SYSCONF_XML" || {
        echo "[X] Error: Failed to update $SYSCONF_XML" >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_APP_SUCCESS_CHECK]} $SYSCONF_XML"
        return 1;
    }

    sudo cp -f "${SYSCONF_XML}" "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" || {
        echo "[X] Error: Failed to replace sysconf.xml" >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_SCREEN_SIZE_6]}"
        return 1
    }

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    SCREEN_SPLASH
    echo "[✓] Screen Size Successfully Changed" >> "${LOG_FILE}"
    center_title "[✓] ${UI_TEXT[SCREEN_SIZE_3]}"
    center_text "${UI_TEXT[CONTINUE]}"
    echo
    read -n 1 -s -r -p "$text" </dev/tty
}

option_five() {
    CACHE_SPLASH

    # === Delete files in ARTWORK_DIR ===
    if ! find "$ARTWORK_DIR" -maxdepth 1 -type f ! \( \
        -name "APP.png" -o \
        -name "APP_WLE-R3Z.png" -o \
        -name "HOSDMENU.png" -o \
        -name "SYS_R3CONFIG.png" -o \
        -name "NHDDL.png" -o \
        -name "OPENPS2LOAD.png" -o \
        -name "ps1.png" -o \
        -name "ps2.png" -o \
        -name "POPSLOADER.png" \
    \) -delete; then
    echo "[X] Error: Some files could not be deleted in $ARTWORK_DIR" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_CLEAR_CACHE]}"
    return 1
    fi

    # === Delete files in ICO_DIR ===
    if ! find "$ICO_DIR" -maxdepth 1 -type f ! \( \
        -name "app-del.ico" -o \
        -name "app.ico" -o \
        -name "cd.ico" -o \
        -name "dvd.ico" -o \
        -name "nhddl-del.ico" -o \
        -name "nhddl.ico" -o \
        -name "opl-del.ico" -o \
        -name "opl.ico" -o \
        -name "ps1.ico" -o \
        -name "psbbn-del.ico" -o \
        -name "psbbn.ico" -o \
        -name "popsloader.ico" -o \
        -name "popsloader-del.ico" \
    \) -delete; then
        echo "[X] Error: Some files could not be deleted in $ICO_DIR" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CLEAR_CACHE]}"
        return 1
    fi

    # === Delete files in VMC_ICON_DIR ===
    rm -rf "$VMC_ICON_DIR"

    center_title "[✓] ${UI_TEXT[CLEAR_CACHE]}"
    center_text "${UI_TEXT[CONTINUE]}"
    echo
    read -n 1 -s -r -p "$text" </dev/tty
}

clear
trap 'echo; exit 130' INT
trap exit_script EXIT

cd "${TOOLKIT_PATH}"

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error_msg "${UI_TEXT[ERROR_LOG]}"
        exit 1
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo -n "PSBBN Definitive Project Version: " >> "${LOG_FILE}"
git rev-parse --short HEAD >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1

EXTRAS_SPLASH
detect_drive || exit 1
HDL_TOC || exit 1
CHECK_PARTITIONS || exit 1

if ! sudo rm -rf "${STORAGE_DIR}"; then
    echo "[X] Error: Failed to delete: $STORAGE_DIR" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_DELETE]} $STORAGE_DIR"
    exit 1
fi

# Main loop

while true; do
    MENU_KEYS=(
        EXTRAS_MENU_OPTION_1
        EXTRAS_MENU_OPTION_2
        EXTRAS_MENU_OPTION_3
        EXTRAS_MENU_OPTION_4
        EXTRAS_MENU_OPTION_5
    )
    center_menu
    display_menu
    read -rp "" choice

    case $choice in
        1)
            option_one
            ;;
        2)
            option_two
            ;;
        3)
            option_three
            ;;
        4)
            option_four
            ;;
        5)
            option_five
            ;;
        b|B)
            break
            ;;
        *)
            printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
            sleep 2
            ;;
    esac
done

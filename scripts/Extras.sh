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

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

# Set paths
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
ICONS_DIR="${TOOLKIT_PATH}/icons"
ARTWORK_DIR="${ICONS_DIR}/art"
ICO_DIR="${ICONS_DIR}/ico"
VMC_ICON_DIR="${ICONS_DIR}/ico/vmc"
OPL="${SCRIPTS_DIR}/OPL"
OSDMBR_CNF="${SCRIPTS_DIR}/tmp/OSDMBR.CNF"
SYSCONF_XML="${SCRIPTS_DIR}/tmp/sysconf.xml"
LOG_FILE="${TOOLKIT_PATH}/logs/extras.log"

path_arg="$1"
arch="$(uname -m)"

# Source unattended configuration if present
UNATTENDED_CONF="${TOOLKIT_PATH}/psbbn-unattended.conf"
if [[ -f "$UNATTENDED_CONF" ]]; then
    source "$UNATTENDED_CONF"
fi

CONF_LANG="${LANG:-}"
CONF_SCREEN="${SCREEN:-}"
CONF_SELECT_WITH_CROSS="${SELECT_WITH_CROSS:-}"

URL="https://archive.org/download/psbbn-definitive-patch-v4.1"

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

error_msg() {
    error_1="$1"
    error_2="$2"
    error_3="$3"
    error_4="$4"

    echo
    echo "$error_1" | tee -a "${LOG_FILE}"
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
    echo
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

clean_up() {

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1
    sudo rm -rf "${SCRIPTS_DIR}/tmp"

    failure=0

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || error_msg "Error" "Failed to unmount $line"
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
        error_msg "[X] Error: Cleanup error(s) occurred. Aborting."
        return 1
    fi

}

exit_script() {
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
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
        error_msg "[X] Error: Partition ${PARTITION_NAME} not found on disk."
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
            error_msg "[X] Error: Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
            clean_up
            return 1
        fi
    done
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "[X] Error: Unable to detect the PS2 drive. Please ensure the drive is properly connected." | tee -a "${LOG_FILE}"
        echo
        echo "You must install PSBBN or HOSDMenu before insalling extras."
        echo
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
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
            echo "Failed to unmount $mount_point. Please unmount manually." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
            return 1
        fi
    done

    if ! sudo "${HDL_DUMP}" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo
        echo "[X] Error: APA partition is broken on ${DEVICE}." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        return 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    if ! mkdir -p "${OPL}" 2>>"${LOG_FILE}"; then
        read -n 1 -s -r -p "Failed to create ${OPL}. Press any key to return to the menu..." </dev/tty
        return 1
    fi

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "[X] Error: Failed to mount ${DEVICE}3"
        return 1
    fi

}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        read -n 1 -s -r -p "Failed to unmount $DEVICE. Press any key to return to the menu..." </dev/tty
        return 1;
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
        echo "All required files are present. Skipping download" | tee -a "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Downloading required files..." | tee -a "${LOG_FILE}"
        if axel -a https://archive.org/download/psbbn-definitive-patch-v4.1/PS2Linux.tar.gz -o "${ASSETS_DIR}"; then
            echo "[✓] Download completed successfully." | tee -a "${LOG_FILE}"
        else
            error_msg "[X] Error: Download failed." "Please check the status of archive.org. You may need to use a VPN depending on your location."
            return 1
        fi
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
        error_msg "[X] Error: Failed to detect PSBBN or HOSDMenu on ${DEVICE}."
        return 1
    fi

}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "PFS Shell returned an error. See ${LOG_FILE}"
    return 1
fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "[X] Error: Failed to extract list of partitions." "APA partition could be broken on ${DEVICE}"
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
        echo "Found $display version $remote_version" | tee -a "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Could not find the latest version of the $display." | tee -a "${LOG_FILE}"
        echo "Please check the status of archive.org. You may need to use a VPN depending on your location."
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
            echo "Newer local file found: ${LATEST_FILE}" | tee -a "${LOG_FILE}"

            # Only set LATEST_VERSION for the patch prefix
            if [[ "$prefix" == "language-pak-$LANG" ]]; then
                LATEST_LANG="$local_version"
            elif [[ "$prefix" == "channels-$LANG" ]]; then
                LATEST_CHAN="$local_version"
            fi
            return 0
        fi
    fi

    # Remote exists and is newer then remote wins
    if [[ -n "$remote_version" ]]; then
        LATEST_FILE="${prefix}-v${remote_version}.tar.gz"

        # Only set LATEST_VERSION for the patch prefix
        if [[ "$prefix" == "language-pak-$LANG" ]]; then
            LATEST_LANG="$remote_version"
        elif [[ "$prefix" == "channels-$LANG" ]]; then
            LATEST_CHAN="$remote_version"
        fi
        return 0
    fi

    # If neither version exists error
    error_msg "[X] Error: Failed to find ${display}. Aborting."
    return 1
}

downoad_latest_file() {
    local prefix="$1"
    # Check if the latest file exists in ${ASSETS_DIR}
    if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "File ${LATEST_FILE} exists. Skipping download." | tee -a "${LOG_FILE}"
    else
        # Check for and delete older files
        for file in "${ASSETS_DIR}"/$prefix*.tar.gz; do
            if [[ -f "$file" && "$(basename "$file")" != "$LATEST_FILE" ]]; then
                echo "Deleting old file: $file" | tee -a "${LOG_FILE}"
                rm -f "$file"
            fi
        done

        # Construct the full URL for the .gz file and download it
        TAR_URL="$URL/$LATEST_FILE"
        echo "Downloading ${LATEST_FILE}..." | tee -a "${LOG_FILE}"
        axel -n 8 -a "$TAR_URL" -o "${ASSETS_DIR}"

        # Check if the file was downloaded successfully
        if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
            echo "Download completed: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
        else
            error_msg "[X] Error: Download failed for ${LATEST_FILE}." "Please check your internet connection and try again."
            return 1
        fi
    fi

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

# Function for Option 1 - Install PS2 Linux
option_one() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Install PS2 Linux:" >> "${LOG_FILE}"
    LINUX_SPLASH
    if [ "$OS" = "HOSD" ]; then
        error_msg "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature."
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
            error_msg "Linux is already installed." "If you want to reinstall Linux, update to PSBBN version 4.0.0 or higher first."
            return 0
        else
            while true; do
                LINUX_SPLASH
                echo "                   Linux is already installed on your PS2. Do you want to reinstall it?" | tee -a "${LOG_FILE}"
                
                if cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
                    echo
                    echo "                   - All Linux system files will be reinstalled." | tee -a "${LOG_FILE}"
                    echo "                   - Your personal files in the home directory will not be affected." | tee -a "${LOG_FILE}"
                else
                    echo
                    echo "                   ============================== WARNING ============================="
                    echo
                    echo "                    All PS2 Linux data will be erased, including your home direcrtory." | tee -a "${LOG_FILE}"
                    echo "                    Make sure to back up your files before continuing."
                    echo
                    echo "                   ===================================================================="
                fi
                
                echo
                read -p "                   Reinstall PS2 Linux? (y/n): " answer
                case "$answer" in
                    [Yy])
                        break
                        ;;
                    [Nn])
                        return 0
                        ;;
                    *)
                        echo
                        echo -n "                   Please enter y or n."
                        sleep 3
                        ;;
                esac
            done
        fi
    fi

    LINUX_SPLASH

    if [ "$linux3" != "yes" ]; then
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            error_msg "To install or reinstall PS2 Linux, update to PSBBN version 4.0.0 or higher."
            return 0
        else
            if [ -z "$APA_SIZE" ]; then
                error_msg "[X] Error: Unable to determine APA free space."
                return 1
            else
                AVAILABLE_SPACE || return 1
                if [ "$free_space" -lt 3 ]; then
                    error_msg "[X] Error: Insufficient disk space. At least 3 GB of free space is required to install Linux."
                    return 1
                else
                    free_space=$((free_space -2))
                fi
            fi
        fi
    fi

    download_linux || return 1

    if [ "$linux3" == "yes" ]; then
        HDL_TOC || return 1
        LINUX_SIZE=$(grep '__\linux.3' "$hdl_output" | awk '{print $4}' | grep -oE '[0-9]+')
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
            echo | tee -a "${LOG_FILE}"
            echo "APA Space Available: $free_space GB" >> "${LOG_FILE}"
            echo "What size would you like the \"home\" partition to be?"
            echo "Minimum 1 GB, maximum $free_space GB"
            echo
            read -p "Enter partition size (in GB): " home_gb

            if [[ ! "$home_gb" =~ ^[0-9]+$ ]]; then
                echo
                echo -n "Invalid input. Please enter a valid number."
                sleep 3
                continue
            fi

            if (( home_gb < 1 || home_gb > free_space )); then
                echo
                echo "Invalid size. Please enter a value between 1 and $free_space GB."
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
    echo -n "Installing PS2 Linux..." | tee -a "${LOG_FILE}"

    LINUX_PARTITIONS=("__linux.3" )
    APA_PARTITIONS=("__system" "__sysconf" )

    clean_up   && \
    mapper_probe || return 1

    mount_cfs    && \
    mount_pfs    || return 1

    if ! sudo tar zxpf "${ASSETS_DIR}/PS2Linux.tar.gz" -C "${STORAGE_DIR}/__linux.3" >>"${LOG_FILE}" 2>&1; then
        error_msg "Failed to extract files. Install Failed."
        return 1
    fi

    cp -f "${ASSETS_DIR}/kernel/ps2-linux-"{ntsc,vga} "${STORAGE_DIR}/__system/p2lboot/" 2>> "${LOG_FILE}" || { error_msg "Failed to copy kernel files."; return 1; }

    TMP_FILE=$(mktemp /tmp/OSDMBR.XXXXXX)
    cp -f "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "$TMP_FILE" 2>> "${LOG_FILE}" || { error_msg "Failed to copy OSDMBR.CNF."; return 1; }

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
    cp -f $TMP_FILE "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" 2>> "${LOG_FILE}" || { error_msg "Failed to copy OSDMBR.CNF."; return 1; }

    clean_up || return 1

    LINUX_SPLASH
    echo "    =============================== [✓] PS2 Linux Successfully Installed ==============================" | tee -a "${LOG_FILE}"
    cat << "EOF"

        To launch PS2 Linux, power on your PS2 console and hold the CIRCLE button on the controller.

        PS2 Linux requires a USB keyboard; a mouse is optional but recommended.

        Default "root" password: password
        Default password for "ps2" user account: password

        To launch a graphical interface type: startx

    ====================================================================================================

EOF
    read -n 1 -s -r -p "                                   Press any key to return to the menu..." </dev/tty

}

# Function for Option 2 - Reassign X and O Buttons
option_two() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Reassign Buttons:" >> "${LOG_FILE}"
    SWAP_SPLASH

    clean_up
    if [ "$OS" = "HOSD" ]; then
        error_msg "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature."
        return 1
    fi

    MOUNT_OPL   || return 1
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 3.00." "To update, please select 'Install PSBBN' from the main menu and try again."
        UNMOUNT_OPL
        return 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "3.00" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "3.00" ]]; then
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 3.00." "To update, please select “Update PSBBN Software” from the main menu and try again."
        UNMOUNT_OPL
        return 1
    fi

    if [[ -n "$CONF_SELECT_WITH_CROSS" ]]; then
        if [[ "$CONF_SELECT_WITH_CROSS" == "true" ]]; then
            BUTTON="X"
            choice="1"
        else
            BUTTON="O"
            choice="2"
        fi
        echo "[!] Using button layout from unattended config: Cross=$( [[ "$CONF_SELECT_WITH_CROSS" == "true" ]] && echo "Enter" || echo "Back" )" | tee -a "${LOG_FILE}"
    else
        choice=""
        while :; do
            SWAP_SPLASH
            cat << "EOF"
                                      Please select a button layout:

                                      1) Cross = Enter, Circle = Back

                                      2) Circle = Enter, Cross = Back

                                      b) Back

EOF
            read -rp "                                      Select an option: " choice

                case "$choice" in
                1|2|b|B)
                    break
                    ;;
                *)
                    echo "                                      Invalid choice, please enter 1, 2, or b."
                    sleep 3
                    ;;
            esac
        done

        if [[ "$choice" == "1" ]]; then
            BUTTON="X"
        else
            BUTTON="O"
        fi
    fi

    if grep -q '^ENTER =' "$OPL/version.txt"; then
        sed -i "s/^ENTER =.*/ENTER = $BUTTON/" "$OPL/version.txt" || {
            error_msg "[X] Error: Failed to update button config in version.txt."
            UNMOUNT_OPL
            return 1
        }
    else
        echo "ENTER = $BUTTON" >> "$OPL/version.txt" || {
            error_msg "[X] Error: Failed to add button config to version.txt."
            UNMOUNT_OPL
            return 1
        }
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
                echo "    ================================= [✓] Buttons Swapped Successfully =================================" | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "                                    Press any key to return to the menu..." </dev/tty
            else
                SWAP_SPLASH
                error_msg "[X] Error: Failed to swap buttons. See log for details."
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
                echo "    ================================= [✓] Buttons Swapped Successfully =================================" | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "                                    Press any key to return to the menu..." </dev/tty
            else
                SWAP_SPLASH
                error_msg "[X] Error: Failed to swap buttons. See log for details."
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
            if [[ "$LANG" == "jpn" ]]; then
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
            error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 4.1.0." "To update, please select 'Install PSBBN' from the main menu and try again."
            UNMOUNT_OPL
            return 1
        elif [[ "$(printf '%s\n' "$psbbn_version" "4.1.0" | sort -V | head -n1)" = "$psbbn_version" ]] \
            && [[ "$psbbn_version" != "4.1.0" ]]; then
            error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 4.1.0." "To update, please select “Update PSBBN Software” from the main menu and try again."
            UNMOUNT_OPL
            return 1
        fi
    fi

    if [[ -n "$CONF_LANG" ]]; then
        LANG="$CONF_LANG"
        case "$LANG" in
            eng) LANG_DISPLAY="English" ;;
            jpn) LANG_DISPLAY="Japanese" ;;
            fre) LANG_DISPLAY="French" ;;
            ger) LANG_DISPLAY="German" ;;
            ita) LANG_DISPLAY="Italian" ;;
            por) LANG_DISPLAY="Portuguese (Brazil)" ;;
            spa) LANG_DISPLAY="Spanish" ;;
            *) LANG_DISPLAY="$LANG" ;;
        esac
        echo "[!] Using language from unattended config: $LANG_DISPLAY" | tee -a "${LOG_FILE}"
    else
        while :; do
            LANGUAGE_SPLASH
            cat << "EOF"
                               Please select a language from the list below:

                               1) English

                               2) Japanese

                               3) French

                               4) German

                               5) Italian

                               6) Portuguese (Brazil)

                               7) Spanish

                               b) Back

EOF
            read -rp "                               Select an option: " choice

            case "$choice" in
                1)
                    LANG="eng"
                    LANG_DISPLAY="English"
                    break
                    ;;
                2)
                    LANG="jpn"
                    LANG_DISPLAY="Japanese"
                    break
                    ;;
                3)
                    LANG="fre"
                    LANG_DISPLAY="French"
                    break
                    ;;
                4)
                    LANG="ger"
                    LANG_DISPLAY="German"
                    break
                    ;;
                5)
                    LANG="ita"
                    LANG_DISPLAY="Italian"
                    break
                    ;;
                6)
                    LANG="por"
                    LANG_DISPLAY="Portuguese (Brazil)"
                    break
                    ;;
                7)
                    LANG="spa"
                    LANG_DISPLAY="Spanish"
                    break
                    ;;
                b|B)
                    UNMOUNT_OPL
                    return 0
                    ;;
                *)
                    echo
                    echo -n "                         Invalid choice. Please select a number between 1 and 7."
                    sleep 3
                    ;;
            esac
        done
    fi

    echo "Language selected: $LANG_DISPLAY" >> "${LOG_FILE}"
    LANGUAGE_SPLASH

    if [ "$OS" = "PSBBN" ]; then
        # Download the HTML of the page
        HTML_FILE=$(mktemp)
        timeout 20 wget -O "$HTML_FILE" "$URL" -o - >> "$LOG_FILE" 2>&1 &
        WGET_PID=$!

        spinner $WGET_PID "Checking for latest version of the PSBBN Definitive Patch"

        get_latest_file "language-pak-$LANG" "$LANG_DISPLAY language pack" || return 1
        downoad_latest_file "language-pak-$LANG" || return 1
        LANG_PACK="${ASSETS_DIR}/${LATEST_FILE}"

        if [[ "$LANG" == "jpn" ]]; then
            get_latest_file "channels-$LANG" "$LANG_DISPLAY channels" || return 1
            downoad_latest_file "channels" || return 1
            CHANNELS="${ASSETS_DIR}/${LATEST_FILE}"
        fi

        echo
        echo -n "Installing language pack..."

        sed -i "s/^LANG =.*/LANG = $LANG/" "$OPL/version.txt" || { error_msg "[X] Error: Failed to update language in version.txt."; return 1; }
        sed -i "s|^LANG_VER =.*|LANG_VER = $LATEST_LANG|" "${OPL}/version.txt" || { error_msg "[X] Error: Failed to update language in version.txt."; return 1; }
        sed -i "s|^CHAN_VER =.*|CHAN_VER = $LATEST_CHAN|" "${OPL}/version.txt" || { error_msg "[X] Error: Failed to update language in version.txt."; return 1; }

        LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.9" )
        APA_PARTITIONS=("__system" "__sysconf" "__common")

        clean_up   && \
        mapper_probe || return 1
        mount_cfs    && \
        mount_pfs    || return 1

        ls -l /dev/mapper >> "${LOG_FILE}"
        df >> "${LOG_FILE}"

        sudo tar zxpf "$LANG_PACK" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || { error_msg "[X] Error: Failed to install $LANG_DISPLAY language pack." "See ${LOG_FILE} for details."; return 1; }

        if [[ "$LANG" == "jpn" ]]; then
            cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" 2>> "${LOG_FILE}" || { error_msg "[X] Error: Failed to copy kernel file."; return 1; }
            sudo tar zxpf "${CHANNELS}" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || { error_msg "[X] Error: Failed to install channels." "See ${LOG_FILE} for details."; return 1; }
        else
            cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" 2>> "${LOG_FILE}" || { error_msg "[X] Error: Failed to copy kernel file."; return 1; }
        fi

        mkdir -p "${SCRIPTS_DIR}/tmp"
        cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}" || { error_msg "[X] Error: Failed to copy OSDMBR.CNF."; return 1; }
        sed -i "s/^osd_language =.*/osd_language = $LANG/" "${OSDMBR_CNF}" || { error_msg "[X] Error: Failed to update language in OSDMBR.CNF."; return 1; }
        cp -f "${OSDMBR_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" || { error_msg "[X] Error: Failed to replace OSDMBR.CNF."; return 1; }
        
        # Update buttons
        if [[ "$ENTER" == "O" ]] || { [[ -z "$ENTER" ]] && [[ "$LANG" == "jpn" ]]; }; then
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
                echo "Enter button swapped to O" >> "${LOG_FILE}"
            else
                error_msg "Failed to swap enter button. See log for details."
            fi
        elif [[ "$ENTER" == "X" ]] || { [[ -z "$ENTER" ]] && [[ "$LANG" != "jpn" ]]; }; then
            if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
                echo "Enter button swapped to X" >> "${LOG_FILE}"
            else
                error_msg "Failed to swap enter button. See log for details."
            fi
        fi

        if [[ "$SCREEN" == "full" ]]; then
            SIZE_NAME="Full"
            case "$LANG" in
                jpn) SIZE_NAME="フル" ;;
                fre) SIZE_NAME="Plein écran" ;;
                spa) SIZE_NAME="Pantalla Completa" ;;
                ger) SIZE_NAME="Ganzer Bildschirm" ;;
                ita) SIZE_NAME="Schermo Intero" ;;
                dut) SIZE_NAME="Volledig" ;;
                por) SIZE_NAME="Completo" ;;
            esac
        elif [[ "$SCREEN" == "16:9" ]]; then
            SIZE_NAME="16:9"
        fi

        if [[ "$SCREEN" == "full" || "$SCREEN" == "16:9" ]]; then
            mkdir -p "${SCRIPTS_DIR}/tmp"
            sudo cp "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" "${SYSCONF_XML}" || error_msg "Failed to copy sysconf.xml"

            sed -i "/<menu id=\"sysconf_value_2_0\">/,/<\/menu>/ {
                /<item value=/ {
                    s|<item value=.*|<item value=\"$SIZE_NAME\"/>|
                    :done
                    n
                    b done
                }
            }" "$SYSCONF_XML" ||
            error_msg "Failed to update $SYSCONF_XML";

            sudo cp -f "${SYSCONF_XML}" "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" || error_msg "Failed to replace sysconf.xml."
        fi
    else
        sed -i "s/^LANG =.*/LANG = $LANG/" "$OPL/version.txt" || { error_msg "[X] Error: Failed to update language in version.txt."; return 1; }
        APA_PARTITIONS=("__common")
        clean_up   && \
        mapper_probe && \
        mount_pfs    || return 1
    fi

    if [[ "$LANG" == "jpn" ]]; then
        rm -f "${STORAGE_DIR}/__common/POPS/"{IGR_BG.TM2,IGR_NO.TM2,IGR_YES.TM2} 2>> "${LOG_FILE}" || { error_msg "[X] Error: Update POPS IGR textures."; return 1; }
    else
        mkdir -p "${STORAGE_DIR}/__common/POPS"
        cp -f "${ASSETS_DIR}/POPStarter/$LANG/"{IGR_BG.TM2,IGR_NO.TM2,IGR_YES.TM2} "${STORAGE_DIR}/__common/POPS/" 2>> "${LOG_FILE}" || { error_msg "[X] Error: Update POPS IGR textures."; return 1; }
    fi

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    msg=" [✓] Language Successfully Changed to $LANG_DISPLAY "
    total_width=100

    # Length of the message including spaces around it
    msg_len=${#msg}

    # Calculate number of "=" on each side
    pad=$(( (total_width - msg_len) / 2 ))

    # If odd padding required, right side will get one more "=", so account for it
    extra=$(( (total_width - msg_len) % 2 ))

    left_pad=$(printf '%*s' "$pad" | tr ' ' '=')
    right_pad=$(printf '%*s' $((pad + extra)) | tr ' ' '=')

    LANGUAGE_SPLASH
    echo "    ${left_pad}${msg}${right_pad}"
    echo
    echo "      It is recommended to rerun the Game Installer and choose \"Add Additional Games and Apps\" to"
    if [ "$OS" = "PSBBN" ]; then
        echo "      update the game titles and PlaySation game manuals to your selected language."
        if [[ -z "$ENTER" ]]; then
            echo
            echo "      If you had previously swapped the X and O buttons, you'll need to do it again in the Extras menu."
        fi
    else
        echo "      update the game titles to your selected language."
    fi
    echo
    echo "    ===================================================================================================="
    echo
    read -n 1 -s -r -p "                                    Press any key to return to the menu..." </dev/tty
    
}

option_four() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Change Screen Size:" >> "${LOG_FILE}"

    SCREEN_SPLASH

    clean_up

    if [ "$OS" = "HOSD" ]; then
        error_msg "[X] Error: PSBBN is not installed. Please install PSBBN to use this feature."
        return 1
    fi

    MOUNT_OPL   || return 1

    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 4.0.0." "To update, please select 'Install PSBBN' from the main menu and try again."
        return 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "4.0.0" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "4.0.0" ]]; then
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than the required version of 4.0.0." "To update, please select “Update PSBBN Software” from the main menu and try again."
        return 1
    fi

    LANG=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")
    echo "Language: $LANG" >> "${LOG_FILE}"

    if [[ -n "$CONF_SCREEN" ]]; then
        SCREEN_SIZE="$CONF_SCREEN"
        case "$SCREEN_SIZE" in
            full) SIZE_NAME="Full" ;;
            16:9) SIZE_NAME="16:9" ;;
            *) SCREEN_SIZE="4:3"; SIZE_NAME="4:3" ;;
        esac
        echo "[!] Using screen size from unattended config: $SCREEN_SIZE" | tee -a "${LOG_FILE}"
    else
        while :; do
            SCREEN_SPLASH
            cat << "EOF"
                              Please select a screen size from the list below:

                              1) 4:3

                              2) Full

                              3) 16:9

                              b) Back

EOF
            read -rp "                              Select an option: " choice

            case "$choice" in
                1)
                    SCREEN_SIZE="4:3"
                    SIZE_NAME="4:3"
                    break
                    ;;
                2)
                    SCREEN_SIZE="full"
                    SIZE_NAME="Full"
                    case "$LANG" in
                        jpn) SIZE_NAME="フル" ;;
                        fre) SIZE_NAME="Plein écran" ;;
                        spa) SIZE_NAME="Pantalla Completa" ;;
                        ger) SIZE_NAME="Ganzer Bildschirm" ;;
                        ita) SIZE_NAME="Schermo Intero" ;;
                        dut) SIZE_NAME="Volledig" ;;
                        por) SIZE_NAME="Completo" ;;
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
                    echo -n "                               Invalid choice, enter a number between 1 and 3."
                    sleep 3
                    ;;
            esac
        done
    fi

    echo "Screen size selected: $SCREEN_SIZE" >> "${LOG_FILE}"
    echo "Screen size name: $SIZE_NAME" >> "${LOG_FILE}"

    if grep -q '^SCREEN =' "$OPL/version.txt"; then
        sed -i "s/^SCREEN =.*/SCREEN = $SCREEN_SIZE/" "$OPL/version.txt" || {
            error_msg "[X] Error: Failed to update screen size in version.txt."
            return 1
        }
    else
        echo "SCREEN = $SCREEN_SIZE" >> "$OPL/version.txt" || {
            error_msg "[X] Error: Failed to add screen size to version.txt."
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
    cp "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "${OSDMBR_CNF}" || { error_msg "[X] Error: Failed to copy OSDMBR.CNF."; return 1; }

    # OSDMBR.CNF - Update osd_screentype if exists, otherwise append it
    if grep -q '^osd_screentype =' "${OSDMBR_CNF}"; then
        sed -i "s/^osd_screentype =.*/osd_screentype = $SCREEN_SIZE/" "${OSDMBR_CNF}" || {
            error_msg "[X] Error: Failed to update osd_screentype in OSDMBR.CNF."; 
            return 1; 
        }
    else
        # Ensure the file ends with a newline
        [ -n "$(tail -c1 "$OSDMBR_CNF" | tr -d '\n')" ] && echo >> "$OSDMBR_CNF"

        echo "osd_screentype = $SCREEN_SIZE" >> "${OSDMBR_CNF}" || {
            error_msg "[X] Error: Failed to add osd_screentype in OSDMBR.CNF."; 
            return 1; 
        }
    fi

    cp -f "${OSDMBR_CNF}" "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" || { error_msg "[X] Error: Failed to replace OSDMBR.CNF."; return 1; }

    # Update sysconf.xml
    sudo cp "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" "${SYSCONF_XML}" || { error_msg "[X] Error: Failed to copy sysconf.xml"; return 1; }

   # Use sed to replace the first <item value= inside the menu block
    sed -i "/<menu id=\"sysconf_value_2_0\">/,/<\/menu>/ {
        /<item value=/ {
            s|<item value=.*|<item value=\"$SIZE_NAME\"/>|
            :done
            n
            b done
        }
    }" "$SYSCONF_XML" || {
        error_msg "[X] Error: Failed to update $SYSCONF_XML";
        return 1;
    }

    sudo cp -f "${SYSCONF_XML}" "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" || { error_msg "[X] Error: Failed to replace sysconf.xml."; return 1; }

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    SCREEN_SPLASH
    echo "    =============================== [✓] Screen Size Successfully Changed ===============================" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "                                   Press any key to return to the menu..." </dev/tty

}

option_five() {
    CACHE_SPLASH

    # === Delete files in ARTWORK_DIR ===
    if ! find "$ARTWORK_DIR" -maxdepth 1 -type f ! \( \
        -name "APP.png" -o \
        -name "APP_WLE-ISR.png" -o \
        -name "HOSDMENU.png" -o \
        -name "OSDMENUCONF.png" -o \
        -name "NHDDL.png" -o \
        -name "OPENPS2LOAD.png" -o \
        -name "ps1.png" -o \
        -name "ps2.png" \
    \) -delete; then
    error_msg "[X] Error: Some files in $ARTWORK_DIR could not be deleted."
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
        -name "psbbn.ico" \
    \) -delete; then
        error_msg "[X] Error: Some files in $ICO_DIR could not be deleted."
        return 1
    fi

    # === Delete files in VMC_ICON_DIR ===
    if ! find "$VMC_ICON_DIR" -maxdepth 1 -type f ! \( \
        -name "VMC.ico" -o \
        -name "GP_*" \
    \) -delete; then
        error_msg "[X] Error: Some files in $VMC_ICON_DIR could not be deleted."
        return 1
    fi

    echo "    ============================= [✓] Icon & Art Cache Cleared Successfully ============================"
    echo
    read -n 1 -s -r -p "                                    Press any key to return to the menu..." </dev/tty
}

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

# Function to display the menu
display_menu() {
    EXTRAS_SPLASH
    cat << "EOF"
                                    1) Install PS2 Linux

                                    2) Reassign Cross and Circle Buttons

                                    3) Change Language

                                    4) Change Screen Settings

                                    5) Clear Art & Icon Cache

                                    b) Back to Main Menu

EOF
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
        echo
        echo "[X] Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to exit..." </dev/tty
        echo
        exit 1
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1

EXTRAS_SPLASH
detect_drive || exit 1
HDL_TOC || exit 1
CHECK_PARTITIONS || exit 1

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
fi

# Main loop

while true; do
    display_menu
    read -p "                                    Select an option: " choice

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
            echo
            echo -n "                                    Invalid option, please try again."
            sleep 2
            ;;
    esac
done

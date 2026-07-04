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

export LC_ALL=en_US.UTF-8

# Set paths
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/extras.log"

path_arg="$1"

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

clean_up() {
    failure=0

    # Build list of partitions we care about
    targets=("${LINUX_PARTITIONS[@]}" "${APA_PARTITIONS[@]}")

    # Unmount if mounted
    for PARTITION_NAME in "${targets[@]}"; do
        MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
        if mountpoint -q "$MOUNT_PATH"; then
            if ! sudo umount "$MOUNT_PATH" 2>/dev/null; then
                echo "[X] Error: Failed to unmount ${PARTITION_NAME}." >> "${LOG_FILE}"
                failure=1
            fi
        fi
    done

    # Force-remove any existing dmsetup maps for just our partitions
    for PARTITION_NAME in "${targets[@]}"; do
        map_name=$(sudo dmsetup ls | awk -v devcut="$(basename "$DEVICE")" -v part="$PARTITION_NAME" '$1 == devcut"-"part {print $1}')
        if [ -n "$map_name" ]; then
            if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
                echo "[X] Error: Failed to delete mapper ${map_name}." >> "${LOG_FILE}"
                failure=1
            fi
        fi
    done

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        error_msg "[X] Error: Cleanup error(s) occurred. Aborting."
        retrun 1
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
    dm_output=$(sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" --dm | tr ';' '\n')

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
        [ -d "${MOUNT_PATH}" ] || sudo mkdir -p "${MOUNT_PATH}"
        if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
            error_msg "[X] Error: Failed to mount ${PARTITION_NAME} partition."
            clean_up
            retrun 1
        fi
    else
        error_msg "[X] Error: Partition ${PARTITION_NAME} not found on disk."
        clean_up
        retrun 1
    fi
  done
}

mount_pfs() {
    for PARTITION_NAME in "${APA_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        sudo mkdir -p "$MOUNT_POINT"
        if ! sudo "${HELPER_DIR}/PFS Fuse.elf" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            error_msg "[X] Error: Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
            clean_up
            retrun 1
        fi
    done
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "[X] Error: Unable to detect PS2 drive." | tee -a "${LOG_FILE}"
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

    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo
        echo "[X] Error: APA partition is broken on ${DEVICE}." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        return 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

check_device_size() {
    # Get the size of the device in bytes
    SIZE_CHECK=$(lsblk -o NAME,SIZE -b | grep -w "$(basename "$DEVICE")" | awk '{print $2}')
    
    # Check if we successfully got a size
    if [[ -z "$SIZE_CHECK" ]]; then
        echo "[X] Error: Could not determine device size."
        return 1
    fi

    # Convert size to GB (1 GB = 1,000,000,000 bytes)
    size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)

    if (( size_gb > 960 )); then
        echo
        echo "[!] Warning: Device is $size_gb GB. HDD-OSD may experience issues with drives larger than 960 GB." | tee -a "${LOG_FILE}"
        echo
        read -rp "Continue anyway? (y/n): " answer
        case "$answer" in
            [Yy]*) echo "Continuing...";;
            *) echo "Aborting."; return 1;;
        esac
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
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
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

hdd_osd_files_present() {
    local files=(
        FNTOSD
        HDD-OSD.elf
        ICOIMAGE
        JISUCS
        OSDSYS_A.XLF
        osdboot.elf
        PSBBN.ELF
        SKBIMAGE
        SNDIMAGE
        TEXIMAGE
    )

    for file in "${files[@]}"; do
        if [[ ! -f "${ASSETS_DIR}/extras/$file" ]]; then
            return 1  # false
        fi
    done

    return 0  # true
}

download_files() {
# Check for HDD-OSD files
    rm -rf "${ASSETS_DIR}/HDD-OSD.zip" "${ASSETS_DIR}/HDD-OSD" 2>>"$LOG_FILE"
    if hdd_osd_files_present; then
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" >> "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Required files are missing in ${ASSETS_DIR}/extras." | tee -a "${LOG_FILE}"
        # Check if extras.zip exists
        if [[ -f "${ASSETS_DIR}/extras.zip" && ! -f "${ASSETS_DIR}/extras.zip.st" ]]; then
            echo | tee -a "${LOG_FILE}"
            echo "extras.zip found in ${ASSETS_DIR}. Extracting..." | tee -a "${LOG_FILE}"
            unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        else
            echo | tee -a "${LOG_FILE}"
            echo "Downloading required files..." | tee -a "${LOG_FILE}"
            axel -a https://archive.org/download/psbbn-definitive-english-patch-v2/extras.zip -o "${ASSETS_DIR}"
            unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        fi
        # Check if HDD-OSD files exist after extraction
        if hdd_osd_files_present; then
            echo | tee -a "${LOG_FILE}"
            echo "[✓] Files successfully extracted." | tee -a "${LOG_FILE}"
        else
            echo | tee -a "${LOG_FILE}"
            echo "[X] Error: One or more files are missing after extraction." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
            return 1
        fi
    fi
}

download_linux() {
# Check for HDD-OSD files
    if [ -f "${ASSETS_DIR}/PS2Linux.tar.gz" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" | tee -a "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Downloading required files..." | tee -a "${LOG_FILE}"
        if axel -a https://archive.org/download/psbbn-definitive-patch-v3/PS2Linux.tar.gz -o "${ASSETS_DIR}"; then
            echo "[✓] Download completed successfully." | tee -a "${LOG_FILE}"
        else
            error_msg "[X] Error: Download failed."
            return 1
        fi
    fi
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "PFS Shell returned an error. See ${LOG_FILE}"
    return 1
fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "[X] Error: Failed to extract list of partitions." "APA partition could be broken on ${DEVICE}"
        return 1
    fi
}

AVAILABLE_SPACE(){
    HDL_TOC || return 1
    # Extract the "used" value, remove "MB" and any commas
    used=$(cat "$hdl_output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
    capacity=129960

    # Calculate available space (capacity - used)
    available=$((capacity - used - 6400 - 128))
    free_space=$((available / 1024))
    echo "Free Space: $free_space GB" >> "${LOG_FILE}"
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

PS2BBL_SPLASH(){
    clear
    cat << "EOF"
                             ______  _____  _____ ____________ _     
                             | ___ \/  ___|/ __  \| ___ \ ___ \ |    
                             | |_/ /\ `--. `' / /'| |_/ / |_/ / |    
                             |  __/  `--. \  / /  | ___ \ ___ \ |    
                             | |    /\__/ /./ /___| |_/ / |_/ / |____
                             \_|    \____/ \_____/\____/\____/\_____/
                                        
                                        
EOF
}

HDDOSD_SPLASH(){
    clear
    cat << "EOF"
                            _   _____________        _____ ___________ 
                           | | | |  _  \  _  \      |  _  /  ___|  _  \
                           | |_| | | | | | | |______| | | \ `--.| | | |
                           |  _  | | | | | | |______| | | |`--. \ | | |
                           | | | | |/ /| |/ /       \ \_/ /\__/ / |/ / 
                           \_| |_/___/ |___/         \___/\____/|___/  
                                            

EOF
}                                            

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

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
fi

# Function for Option 1 - Install PS2 Linux
option_one() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Install PS2 Linux:" >> "${LOG_FILE}"
    LINUX_SPLASH


    detect_drive   && \
    MOUNT_OPL || return 1
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    UNMOUNT_OPL || return 1

    version_check="3.00"

    HDL_TOC || return 1

    if cat "${hdl_output}" | grep -q '\b__linux\.3\b'; then
        linux3="yes"
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            error_msg "Linux is already installed." "If you want to reinstall Linux, update to PSBBN version 3.00 or higher first."
            return 0
        else
            while true; do
                LINUX_SPLASH
                echo "               Linux is already installed on your PS2. Do you want to reinstall it?" | tee -a "${LOG_FILE}"
                
                if cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
                    echo
                    echo "               - All Linux system files will be reinstalled." | tee -a "${LOG_FILE}"
                    echo "               - Your personal files in the home directory will not be affected." | tee -a "${LOG_FILE}"
                else
                    echo
                    echo "               ============================== WARNING ============================="
                    echo
                    echo "                All PS2 Linux data will be erased, including your home direcrtory." | tee -a "${LOG_FILE}"
                    echo "                Make sure to back up your files before continuing."
                    echo
                    echo "               ===================================================================="
                fi
                
                echo
                read -p "               Reinstall PS2 Linux? (y/n): " answer
                case "$answer" in
                    [Yy])
                        break
                        ;;
                    [Nn])
                        return 0
                        ;;
                    *)
                        echo
                        echo -n "               Please enter y or n."
                        sleep 3
                        ;;
                esac
            done
        fi
    fi

    LINUX_SPLASH

    if [ "$linux3" != "yes" ]; then
        AVAILABLE_SPACE || return 1
        if [ "$free_space" -lt 3 ]; then
            error_msg "[X] Error: Insufficient disk space. At least 3 GB of free space is required to install Linux."
            return 1
        else
            free_space=$((free_space -2))
        fi
    fi

    download_linux || return 1

    if [ "$linux3" = "yes" ]; then
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
        AVAILABLE_SPACE || return 1
        echo "Free Space available for home partition: $free_space GB" >> "${LOG_FILE}"

        while true; do
            echo | tee -a "${LOG_FILE}"
            echo "Available: $free_space GB" | tee -a "${LOG_FILE}"
            echo
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

    LINUX_PARTITIONS=("__linux.1" "__linux.3" )

    clean_up   && \
    mapper_probe || return 1

    if ! sudo mke2fs -t ext2 -b 4096 -I 128 -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode "${MAPPER}__linux.3" >>"${LOG_FILE}" 2>&1; then
        error_msg "[X] Error: Failed to create filesystem __linux.3."
        return 1
    fi

    mount_cfs || return 1

    if ! sudo tar zxpf "${ASSETS_DIR}/PS2Linux.tar.gz" -C "${STORAGE_DIR}/__linux.3" >>"${LOG_FILE}" 2>&1; then
        error_msg "Failed to extract files. Install Failed."
        return 1
    fi

    FILE="${STORAGE_DIR}/__linux.1/etc/rc.d/rc.sysinit"

    LINE1='BUTTON=`cat /proc/ps2pad | awk '\''$1==0 { print $5; }'\''`'
    LINE2='[ "$BUTTON" != "" -a "$BUTTON" != "FFFF" ] && /sbin/akload -r /boot/linux'

    # Read last two lines once
    LAST_LINES=$(tail -n 2 "$FILE")

    # Append the lines if either is missing
    if ! grep -Fxq "$LINE1" <<< "$LAST_LINES" || ! grep -Fxq "$LINE2" <<< "$LAST_LINES"; then
        echo "$LINE1" | sudo tee -a "$FILE" >/dev/null
        echo "$LINE2" | sudo tee -a "$FILE" >/dev/null
    fi

    clean_up

    echo
    echo
    echo "[✓] PS2 Linux successfully installed!" | tee -a "${LOG_FILE}"
    echo
    echo "To launch PS2 Linux, power on your PS2 console and hold any button on the controller"
    echo "when the "PlayStation 2" logo appears."
    echo
    echo "PS2 Linux requires a USB keyboard; a mouse is optional but recommended."
    echo
    echo "Default 'root' password: password"
    echo "Default user password for 'ps2' account: password"
    echo 
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty

}

# Function for Option 2 - Install HDD-OSD
option_two() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    HDDOSD_SPLASH
    echo "Installing HDD-OSD..." | tee -a "${LOG_FILE}"

    detect_drive || return 1

    # Now check size
    check_device_size || return 1

    download_files || return 1

    # Copy HDD-OSD files to __system
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="mkdir osd110u\n"
    COMMANDS+="cd osd110u\n"
    COMMANDS+="put FNTOSD\n"
    COMMANDS+="put HDD-OSD.elf\n"
    COMMANDS+="put ICOIMAGE\n"
    COMMANDS+="put JISUCS\n"
    COMMANDS+="put SKBIMAGE\n"
    COMMANDS+="put SNDIMAGE\n"
    COMMANDS+="put TEXIMAGE\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    cp "${ASSETS_DIR}/extras/"{HDD-OSD.elf,PSBBN.ELF} "${TOOLKIT_PATH}/games/APPS" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "[✓] HDD-OSD installed successfully." | tee -a "${LOG_FILE}"
    echo
    echo "Please run 'Install Games' from the main menu to add HDD-OSD to the PSBBN Game Channel and update"
    echo "the icons for your game collection."
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
}

# Function for Option 3 - Install PlayStation 2 Basic Boot Loader (PS2BBL)
option_three() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    PS2BBL_SPLASH
    echo "Installing PS2 Basic Boot Loader..." | tee -a "${LOG_FILE}"

    download_files || return 1
    detect_drive || return 1

    # Build the commands for PFS Shell
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __sysconf\n"
    COMMANDS+="cd PS2BBL\n"
    COMMANDS+="ls\n"
    COMMANDS+="exit"

    # Get the PS1 file list directly from PFS Shell output, filtered and sorted
    bbl_config=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)

    # Copy PS2BBL files to __system and __sysconf
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="cd p2lboot\n"
    COMMANDS+="rm osdboot.elf\n"
    COMMANDS+="rm PSBBN.ELF\n"
    COMMANDS+="put PSBBN.ELF\n"
    COMMANDS+="lcd '${ASSETS_DIR}/PS2BBL'\n"
    COMMANDS+="put osdboot.elf\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"

    if [[ ! "$bbl_config" == *"CONFIG.INI"* ]]; then
        COMMANDS+="mount __sysconf\n"
        COMMANDS+="mkdir PS2BBL\n"
        COMMANDS+="cd PS2BBL\n"
        COMMANDS+="put CONFIG.INI\n"
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
    fi
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "[✓] PS2BBL installed successfully." | tee -a "${LOG_FILE}"
    echo
    echo "When powering on your PS2, you can now hold X to boot into HDD-OSD (if installed)."
    echo
    echo "PS2BBL can be configured by editing hdd0:/__sysconf/PS2BBL/CONFIG.INI"
    echo "More details can be found at: https://israpps.github.io/PlayStation2-Basic-BootLoader/"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty

}

# Function for Option 4 - Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)
option_four() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    PS2BBL_SPLASH
    echo "Uninstall PS2 Basic Boot Loader..." | tee -a "${LOG_FILE}"

    download_files || return
    detect_drive || return

    # Copy PS2BBL files to __system and __sysconf
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="cd p2lboot\n"
    COMMANDS+="rm osdboot.elf\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="put osdboot.elf\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="mount __sysconf\n"
    COMMANDS+="cd PS2BBL\n"
    COMMANDS+="rm CONFIG.INI\n"
    COMMANDS+="cd /\n"
    COMMANDS+="rmdir PS2BBL\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "[✓] PS2BBL successfully uninstalled." | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
}

# Function for Option 5 - Reassign X and O Buttons
option_five() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Reassign Buttons:" >> "${LOG_FILE}"
    clear

    detect_drive    && \
    MOUNT_OPL   || return 1

    SWAP_SPLASH
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    UNMOUNT_OPL || return 1

    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than 3.00." "To update, please select 'Install PSBBN' from the main menu and try again."
        exit 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "3.00" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "3.00" ]]; then
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than 3.00." "To update, please select “Update PSBBN Software” from the main menu and try again."
        exit 1
    fi

    LINUX_PARTITIONS=("__linux.4" )
    APA_PARTITIONS=("__system" )

    clean_up   && \
    mapper_probe && \
    mount_cfs    && \
    mount_pfs    || return 1


    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    
    choice=""
    while :; do
        SWAP_SPLASH
        cat << "EOF"
                                  1) Cross = Enter, Circle = Back
                                  2) Circle = Enter, Cross = Back

                                  b) Back

EOF
        read -rp "                                  Select an option: " choice
        case "$choice" in
            1)
                echo "Western layout selected." >> "${LOG_FILE}"
                if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
                then
                    SWAP_SPLASH
                    echo "[✓] Buttons swapped successfully." >> "${LOG_FILE}"
                    read -n 1 -s -r -p "                     [✓] Buttons swapped! Press any key to return to the menu..." </dev/tty
                else
                    SWAP_SPLASH
                    error_msg "[X] Error: Failed to swap buttons. See log for details."
                    return 1
                fi
                break
                ;;

                
            2)
                echo "Japanese layout selected." >> "${LOG_FILE}"
                if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
                then
                    SWAP_SPLASH
                    echo "[✓] Buttons swapped successfully." >> "${LOG_FILE}"
                    read -n 1 -s -r -p "                     [✓] Buttons swapped! Press any key to return to the menu..." </dev/tty
                else
                    SWAP_SPLASH
                    error_msg "[X] Error: Failed to swap buttons. See log for details."
                    return 1
                fi
                break
                ;;
            b|B)
                break
                ;;
            *)
                echo -n "                                  Invalid choice, please enter 1, 2, or b."
                sleep 3
            ;;
        esac
    done

    clean_up
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"
}


# Function to display the menu
display_menu() {
    clear
    cat << "EOF"
                                     _____     _                 
                                    |  ___|   | |                
                                    | |____  _| |_ _ __ __ _ ___ 
                                    |  __\ \/ / __| '__/ _` / __|
                                    | |___>  <| |_| | | (_| \__ \
                                    \____/_/\_\\__|_|  \__,_|___/
                        

                         1) Install PS2 Linux
                         2) Install HDD-OSD (Browser 2.0)
                         3) Install PlayStation 2 Basic Boot Loader (PS2BBL)
                         4) Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)
                         5) Reassign Cross and Circle Buttons

                         b) Back to Main Menu

EOF
}

# Main loop

while true; do
    display_menu
    read -p "                         Select an option: " choice

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
            echo "                         Invalid option, please try again."
            sleep 2
            ;;
    esac
done

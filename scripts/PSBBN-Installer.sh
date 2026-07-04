#!/usr/bin/env bash
#
# PSBBN Installer form the PSBBN Definitive Project
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
version_check="2.10"
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
HELPER_DIR="${SCRIPTS_DIR}/helper"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/PSBBN-installer.log"

serialnumber="$2"
path_arg="$3"

case "$1" in
  -install)
    MODE="install"
    ;;
  -update)
    MODE="update"
    ;;
  *)
    echo "Usage: $0 -install | -update"
    exit 1
    ;;
esac

if [ "$MODE" = "install" ]; then
    LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.6" "__linux.7" "__linux.8" "__linux.9" )
    APA_PARTITIONS=("__contents" "__system" "__sysconf" "__common" )
else
    LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.9" )
    APA_PARTITIONS=("__system" "__sysconf" )
fi

error_msg() {
    error_1="[X] Error: $1"
    error_2="$2"
    error_3="$3"
    error_4="$4"

    echo | tee -a "${LOG_FILE}"
    echo "$error_1" | tee -a "${LOG_FILE}"
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
    echo
    exit 1
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
        printf "\r[X]%s\n" "$message" | tee -a "${LOG_FILE}"
    fi
}

clean_up() {
    failure=0

    # Build list of partitions we care about
    targets=("${LINUX_PARTITIONS[@]}" "${APA_PARTITIONS[@]}")
    if [ "$MODE" = "install" ]; then
        targets+=("__linux.2")
    fi

    # Unmount if mounted
    for PARTITION_NAME in "${targets[@]}"; do
        MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
        if mountpoint -q "$MOUNT_PATH"; then
            if ! sudo umount "$MOUNT_PATH" 2>/dev/null; then
                echo "Error: Failed to unmount ${PARTITION_NAME}." >> "${LOG_FILE}"
                failure=1
            fi
        fi
    done

    # Force-remove any existing dmsetup maps for just our partitions
    for PARTITION_NAME in "${targets[@]}"; do
        map_name=$(sudo dmsetup ls | awk -v devcut="$(basename "$DEVICE")" -v part="$PARTITION_NAME" '$1 == devcut"-"part {print $1}')
        if [ -n "$map_name" ]; then
            if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
                echo "Error: Failed to delete mapper ${map_name}." >> "${LOG_FILE}"
                failure=1
            fi
        fi
    done

    # Clean up directories and temp files
    sudo rm -rf /tmp/{apa_header_checksum.bin,apa_header_full.bin,apajail_magic_number.bin,apa_index.xz,gpt_2nd.xz} >> "${LOG_FILE}" 2>&1
    sudo rm -rf "${STORAGE_DIR}/bootstrap.xin" >> "${LOG_FILE}" 2>&1
    sudo rm -rf "${STORAGE_DIR}/__linux.7"/* >> "${LOG_FILE}" 2>&1
    sudo rm -rf "${STORAGE_DIR}/__contents"/* >> "${LOG_FILE}" 2>&1
    
    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        error_msg "Cleanup error(s) occurred. Aborting."
    fi

    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "$path_arg" > /dev/null 2>&1
    fi
}

exit_script() {
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "PFS Shell returned an error. See ${LOG_FILE}"
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
    if [ "$MODE" = "install" ]; then
        keep_partitions+=("__linux.2")
    fi

    # 3) Get HDL Dump --dm output, split semicolons into lines
    dm_output=$(sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" --dm | tr ';' '\n')

    # 4) Create each kept partition individually
    while IFS= read -r line; do
        for part in "${keep_partitions[@]}"; do
            if [[ "$line" == "${DEVICE_CUT}-${part},"* ]]; then
                echo "$line" | sudo dmsetup create --concise | tee -a "${LOG_FILE}"
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
            if [[ "$PARTITION_NAME" = "__linux.8" || "$PARTITION_NAME" = "__linux.9" ]]; then
                if ! sudo mkfs.vfat -F 32 "${MAPPER}${PARTITION_NAME}" >>"${LOG_FILE}" 2>&1; then
                    error_msg "Failed to create filesystem ${PARTITION_NAME}."
                fi
            else
                if ! sudo mke2fs -t ext2 -b 4096 -I 128 -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode "${MAPPER}${PARTITION_NAME}" >>"${LOG_FILE}" 2>&1; then
                    error_msg "Failed to create filesystem ${PARTITION_NAME}."
                fi
            fi

            [ -d "${MOUNT_PATH}" ] || sudo mkdir -p "${MOUNT_PATH}"
                if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
                    error_msg "Failed to mount ${PARTITION_NAME} partition."
                fi
        else
            error_msg "Partition ${PARTITION_NAME} not found on disk."
        fi
    done
    
    if [ "$MODE" = "install" ]; then
        if ! sudo mkswap "${MAPPER}__linux.2" >>"${LOG_FILE}" 2>&1; then
            error_msg "Failed to create swap filesystem."
        fi
    fi
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
            error_msg "Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
        fi
    done
}

apa_checksum_fix() {
	sudo dd if=${DEVICE} of=/tmp/apa_header_full.bin bs=512 count=2 >> "${LOG_FILE}" 2>&1
	"${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf" /tmp/apa_header_full.bin | sed -n 8p | awk '{print $6}' | xxd -r -p > /tmp/apa_header_checksum.bin 2>> "${LOG_FILE}"
	sudo dd if=/tmp/apa_header_checksum.bin of=${DEVICE} conv=notrunc >> "${LOG_FILE}" 2>&1
}

apajail_magic_number() {
	echo ${MAGIC_NUMBER} | xxd -r -p > /tmp/apajail_magic_number.bin
	sudo dd if=/tmp/apajail_magic_number.bin of=${DEVICE} bs=8 count=1 seek=28 conv=notrunc >> "${LOG_FILE}" 2>&1
}

BOOTSTRAP() {
    if [ -f "${STORAGE_DIR}/bootstrap.xin" ]; then
	    # BOOTSTRAP METADATA:
	    BOOTSTRAP_ADDRESS_HEX_BE=0020
	    BOOTSTRAP_SIZE=$(wc -c "${STORAGE_DIR}/bootstrap.xin" | cut -d' ' -f 1)
	    BOOTSTRAP_SIZE_LBA=$(echo "$((${BOOTSTRAP_SIZE}/512))")
	    BOOTSTRAP_SIZE_LBA_HEX_BE=$(printf "%04X" ${BOOTSTRAP_SIZE_LBA} | tac -rs .. | echo "$(tr -d '\n')")
	    echo "${BOOTSTRAP_ADDRESS_HEX_BE}0000${BOOTSTRAP_SIZE_LBA_HEX_BE}0000" | xxd -r -p > /tmp/apa_header_boot.bin 2>> "${LOG_FILE}"

	    # METADATA & BOOTSTRAP WRITING:
	    # 130h = 304d
	    sudo dd if=/tmp/apa_header_boot.bin of=${DEVICE} bs=1 seek=304 >> "${LOG_FILE}" 2>&1
	    # 2000h * 200h = 8192d * 512d = 4194304d = 400000h
	    sudo dd if=${STORAGE_DIR}/bootstrap.xin of=${DEVICE} bs=1M count=1 seek=4 conv=notrunc >> "${LOG_FILE}" 2>&1
    else
	    error_msg "Failed to inject bootstrap."
    fi
}

CHECK_PARTITIONS() {
# Run the command and capture output
    apa_checksum_fix
    TOC_OUTPUT=$(sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        error_msg "APA partition is broken on ${DEVICE}. Install failed."
    fi

    if echo "${TOC_OUTPUT}" | grep -Eq '\b(__linux\.(1|4|5|6|7|8|9)|__contents|__system|__sysconf|__.POPS|__common)\b'; then
        echo "All partitions exist." >> "${LOG_FILE}"
    else
        error_msg "Some partitions are missing on ${DEVICE}. See log for details."
    fi
}

UNMOUNT_ALL() {
    # Find all mounted volumes associated with the device
    mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

    # Iterate through each mounted volume and unmount it
    echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
    for mount_point in $mounted_volumes; do
        echo "Unmounting $mount_point..." >> "${LOG_FILE}"
        if sudo umount "$mount_point"; then
            echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
            error_msg "Failed to unmount $mount_point. Please unmount manually."

        fi
    done
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        error_msg "Failed to unmount $DEVICE"
    fi
}

MOUNT_OPL() {
    echo "Mounting OPL partition." >> "${LOG_FILE}"
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || error_msg "Failed to create ${OPL}."

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Failed to mount the PS2 drive."
    fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "Failed to extract list of partitions." "APA partition could be broken on ${DEVICE}"
    fi
}

SPLASH(){
    clear
        cat << "EOF"
              ______  _________________ _   _   _____          _        _ _           
              | ___ \/  ___| ___ \ ___ \ \ | | |_   _|        | |      | | |          
              | |_/ /\ `--.| |_/ / |_/ /  \| |   | | _ __  ___| |_ __ _| | | ___ _ __ 
              |  __/  `--. \ ___ \ ___ \ . ` |   | || '_ \/ __| __/ _` | | |/ _ \ '__|
              | |    /\__/ / |_/ / |_/ / |\  |  _| || | | \__ \ || (_| | | |  __/ |   
              \_|    \____/\____/\____/\_| \_/  \___/_| |_|___/\__\__,_|_|_|\___|_|   


EOF
}

clear
mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo
        echo "Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        echo
        exit 1
    fi
fi

cd "${TOOLKIT_PATH}"

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "Type: $MODE" >> "${LOG_FILE}"
echo "Disk Serial: $serialnumber" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

trap 'echo; exit 130' INT
trap exit_script EXIT

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
fi

if [ "$MODE" = "install" ]; then
    # Choose the PS2 storage device
    if [[ -n "$serialnumber" ]]; then
            DEVICE=$(lsblk -p -o NAME,SERIAL | awk -v sn="$serialnumber" '$2 == sn {print $1; exit}')
            drive_model=$(lsblk -ndo VENDOR,MODEL,SIZE,SERIAL "$DEVICE" | xargs)
    fi
    if [ -z "$DEVICE" ]; then
        while true; do
        SPLASH
            lsblk -dp -o NAME,MODEL,SIZE,SERIAL | tee -a "${LOG_FILE}"
            echo | tee -a "${LOG_FILE}"
        
            read -p "Choose your PS2 HDD from the list above (e.g., /dev/sdx): " DEVICE
        
        # Check if the device exists
        if [[ -n "$DEVICE" ]] && lsblk -dp -n -o NAME | grep -q "^$DEVICE$"; then
            break
        else
            echo
            echo -n "Invalid input. Please enter a valid device name (e.g., /dev/sdx)."
            sleep 3
        fi
        done
        drive_model=$(lsblk -ndo MODEL,SIZE,SERIAL "$DEVICE" | xargs)
    fi
    
    # Check the size of the chosen device
    SIZE_CHECK=$(lsblk -o NAME,SIZE -b | grep -w $(basename $DEVICE) | awk '{print $2}')

    # Convert size to GB (1 GB = 1,000,000,000 bytes)
    size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)
        
    if (( size_gb < 200 )); then
        error_msg "Device is $size_gb GB. Required minimum is 200 GB."
    else
        echo "Device Name: $DEVICE" >> "${LOG_FILE}"
        [[ -z "$drive_model" ]] && drive_model="$DEVICE"

        echo
        echo "Selected drive: $drive_model" | tee -a "${LOG_FILE}"
        echo
        echo "Are you sure you want to install to the selected dive?" | tee -a "${LOG_FILE}"
        echo
        read -p "This will erase all data on the drive. (yes/no): " CONFIRM
            if [[ $CONFIRM != "yes" ]]; then
                echo "Aborted." | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
                echo
                exit 1
            fi
    fi
else
    clear
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        error_msg "Unable to detect the PS2 drive. Please ensure the drive is properly connected." "If this is your first time using the installer, select 'Install PSBBN' from the main menu."
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"
    
    cat << "EOF"
               ______  _________________ _   _   _   _           _       _            
               | ___ \/  ___| ___ \ ___ \ \ | | | | | |         | |     | |           
               | |_/ /\ `--.| |_/ / |_/ /  \| | | | | |_ __   __| | __ _| |_ ___ _ __ 
               |  __/  `--. \ ___ \ ___ \ . ` | | | | | '_ \ / _` |/ _` | __/ _ \ '__|
               | |    /\__/ / |_/ / |_/ / |\  | | |_| | |_) | (_| | (_| | ||  __/ |   
               \_|    \____/\____/\____/\_| \_/  \___/| .__/ \__,_|\__,_|\__\___|_|   
                                                      | |                             
                                                      |_|                             

EOF

    UNMOUNT_ALL
    HDL_TOC
    MOUNT_OPL

    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)

    # Compare using sort -V
    if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
        UNMOUNT_OPL
        error_msg "The installed PSBBN Definitive Patch is older than version $version_check and cannot be updated" "directly. Please select 'Install PSBBN' from the main menu to perform a full installation."
    fi
    UNMOUNT_OPL
fi

if [ "$MODE" = "install" ]; then
    SPLASH
    UNMOUNT_ALL
fi

# URL of the webpage
URL="https://archive.org/download/psbbn-definitive-patch-v3"

# Download the HTML of the page
HTML_FILE=$(mktemp)
timeout 20 wget -O "$HTML_FILE" "$URL" -o - >> "$LOG_FILE" 2>&1 &
WGET_PID=$!

spinner $WGET_PID "Checking for latest version of the PSBBN Definitive Patch"

# Extract .gz filenames from the HTML
COMBINED_LIST=$(grep -oP 'psbbn-definitive-patch-v[0-9]+\.[0-9]+\.tar.gz' "$HTML_FILE")

# Extract version numbers and sort them
VERSION_LIST=$(echo "$COMBINED_LIST" | \
    grep -oP 'v[0-9]+\.[0-9]+' | \
    sed 's/v//' | \
    sort -V)

# Determine the latest version from the sorted list
LATEST_VERSION=$(echo "$VERSION_LIST" | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Could not find the latest version." | tee -a "${LOG_FILE}"
    # If $LATEST_VERSION is empty, check for psbbn-definitive-patch*.gz files
    PATCH_FILE=$(ls "${ASSETS_DIR}"/psbbn-definitive-patch*.tar.gz 2>/dev/null)
    if [ -n "$PATCH_FILE" ]; then
        # If patch file exists, set LATEST_FILE to the patch file name
        LATEST_VERSION=$(echo "$PATCH_FILE" | sed -E 's/.*-v([0-9.]+)\.tar.gz/\1/')
        LATEST_FILE=$(basename "$PATCH_FILE")
        echo | tee -a "${LOG_FILE}"
        echo "Found local file: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
    else
        rm -f "$HTML_FILE"
        error_msg "Failed to download PSBBN patch file. Aborting."
    fi
else
    # Set the default latest file based on remote version
    LATEST_FILE="psbbn-definitive-patch-v${LATEST_VERSION}.tar.gz"
    echo | tee -a "${LOG_FILE}"
    echo "Latest version of PSBBN Definitive English patch is v${LATEST_VERSION}" | tee -a "${LOG_FILE}"

    # Check if any local file is newer than the remote version
    PATCH_FILE=$(ls "${ASSETS_DIR}"/psbbn-definitive-patch*.tar.gz 2>/dev/null | sort -V | tail -n1)
    if [ -n "$PATCH_FILE" ]; then
        LOCAL_VERSION=$(echo "$PATCH_FILE" | sed -E 's/.*-v([0-9.]+)\.tar.gz/\1/')
        # Compare local vs remote version
        if [ "$(printf '%s\n' "$LATEST_VERSION" "$LOCAL_VERSION" | sort -V | tail -n1)" != "$LATEST_VERSION" ]; then
            LATEST_VERSION="$LOCAL_VERSION"
            LATEST_FILE=$(basename "$PATCH_FILE")
            echo "Newer local file found: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
        fi
    fi
fi

if [ "$MODE" = "update" ]; then
    echo "Current version: $psbbn_version"
    
    if [ "$(printf '%s\n' "$LATEST_VERSION" "$psbbn_version" | sort -V | tail -n1)" = "$psbbn_version" ]; then
        echo
        echo "You are already running the latest version. No need to update." | tee -a "${LOG_FILE}"
        echo
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        echo
        exit 0
    fi
fi

# Check if the latest file exists in ${ASSETS_DIR}
if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
    echo | tee -a "${LOG_FILE}"
    echo "File ${LATEST_FILE} exists in ${ASSETS_DIR}. Skipping download." | tee -a "${LOG_FILE}"
else
    # Check for and delete older files
    for file in "${ASSETS_DIR}"/psbbn-definitive-patch*.tar.gz; do
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
        error_msg "Download failed for ${LATEST_FILE}. Please check your internet connection and try again."
    fi
fi

# Clean up
rm -f "$HTML_FILE"

PSBBN_PATCH="${ASSETS_DIR}/${LATEST_FILE}"

clean_up

if [ "$MODE" = "install" ]; then
    echo | tee -a "${LOG_FILE}"
    echo -n "Initialising the drive..." | tee -a "${LOG_FILE}"

    {
        sudo wipefs -a ${DEVICE} &&
        sudo dd if=/dev/zero of="${DEVICE}" bs=1M count=100 status=progress &&
        sudo dd if=/dev/zero of="${DEVICE}" bs=1M seek=$(( $(sudo blockdev --getsz "${DEVICE}") / 2048 - 100 )) count=100 status=progress
    } >> "${LOG_FILE}" 2>&1 || error_msg "Failed to Initialising drive"

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="initialize yes\n"
    COMMANDS+="mkpart __linux.1 512M EXT2\n"
    COMMANDS+="mkpart __linux.2 128M EXT2SWAP\n"
    COMMANDS+="mkpart __linux.4 512M EXT2\n"
    COMMANDS+="mkpart __linux.5 512M EXT2\n"
    COMMANDS+="mkpart __linux.6 128M EXT2\n"
    COMMANDS+="mkpart __linux.7 256M EXT2\n"
    COMMANDS+="mkpart __linux.9 3072M EXT2\n"
    COMMANDS+="exit"

    PFS_COMMANDS

    # Retreive avaliable space

    output=$(sudo "${HELPER_DIR}"/HDL\ Dump.elf toc ${DEVICE} 2>&1)

    # Extract the "used" value, remove "MB" and any commas
    used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
    capacity=129960

    # Calculate available space (capacity - used)
    available=$((capacity - used - 6400 - 128))
    free_space=$((available / 1024))
    max_pops=$(((available - 2048) / 1024))

    echo | tee -a "${LOG_FILE}"
    SPLASH
    echo "===================================================================================================="
    echo "                                       Partitioning the Drive"
    echo "===================================================================================================="
    # Prompt user for partition size for POPS, Music and Contents, validate input, and keep asking until valid input is provided
    while true; do
        echo | tee -a "${LOG_FILE}"

        # Convert bytes to MB
        SIZE_MB=$(( SIZE_CHECK / 1024 / 1024 ))

        # Difference in MB
        OPL_MB=$(( SIZE_MB - capacity ))

        # Convert to GB
        OPL_GB=$(( OPL_MB / 1024 ))

        if (( OPL_GB >= 1000 )); then
            # Store difference as TB with one decimal
            difference="$(awk "BEGIN {printf \"%.1f TB\", $OPL_GB/1024}")"
            # Cap at 2 TB
            CAP=$(awk "BEGIN {print ($difference > 2.0) ? 2.0 : $difference}")
            OPL_SIZE="${CAP} TB"
        else
            # Store difference as GB
            OPL_SIZE="${OPL_GB} GB"
        fi
        echo "OPL Partition: $OPL_SIZE"
        echo "Remaining space: $free_space GB" | tee -a "${LOG_FILE}"
        echo
        echo "What size would you like the \"POPS\" partition to be?"
        echo "This partition is used to store PS1 games."
        echo "Minimum 1 GB, maximum $max_pops GB"
        echo
        read -p "Enter partition size (in GB): " pops_gb

        if [[ ! "$pops_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo "Invalid input. Please enter a valid number."
            sleep 3
            continue
        fi

        if (( pops_gb < 1 || pops_gb > max_pops )); then
            echo
            echo "Invalid size. Please enter a value between 1 and $max_pops GB."
            sleep 3
            continue
        fi

        remaining_gb=$((free_space - pops_gb -1))
        echo
        echo "What size would you like the \"Music\" partition to be?"
        echo "Minimum 1 GB, maximum $remaining_gb GB"
        echo
        read -p "Enter partition size (in GB): " music_gb

        if [[ ! "$music_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo "Invalid input. Please enter a valid number."
            sleep 3
            continue
        fi

        if (( music_gb < 1 || music_gb > remaining_gb )); then
            echo
            echo "Invalid size. Please enter a value between 1 and $remaining_gb GB."
            sleep 3
            continue
        fi

        remaining_gb=$((free_space - pops_gb - music_gb))
        echo
        echo "What size would you like the \"Contents\" partition to be?"
        echo "This partition is used to store movies and photos."
        echo "Minimum 1 GB, maximum $remaining_gb GB"
        echo
        read -p "Enter partition size (in GB): " contents_gb

        if [[ ! "$contents_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo "Invalid input. Please enter a valid number."
            sleep 3
            continue
        fi

        if (( contents_gb < 1 || contents_gb > remaining_gb )); then
            echo
            echo "Invalid size. Please enter a value between 1 and $remaining_gb GB."
            sleep 3
            continue
        fi

        allocated_gb=$((music_gb + pops_gb + contents_gb))
        unallocated_gb=$((free_space - allocated_gb))
        echo
        echo "The following partitions will be created:"
        echo "- OPL partition: $OPL_SIZE"
        echo "- POPS partition: $pops_gb GB"
        echo "- Music partition: $music_gb GB"
        echo "- Contents partition: $contents_gb GB"
        echo "- Unallocated space: $unallocated_gb GB"
        echo
        read -p "Do you wish to proceed? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            music_partition=$((music_gb * 1024))
            pops_partition=$((pops_gb * 1024))
            contents_partition=$((contents_gb * 1024))
            break
        fi
    done

    echo >> "${LOG_FILE}"
    echo "Music partition size: $music_partition" >> "${LOG_FILE}"
    echo "POPS partition size: $pops_partition" >> "${LOG_FILE}"
    echo "Contents partition size: $contents_partition" >> "${LOG_FILE}"

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart __linux.8 ${music_partition}M EXT2\n"
    COMMANDS+="mkpart __.POPS ${pops_partition}M PFS\n"
    COMMANDS+="mkpart __contents ${contents_partition}M PFS\n"
    COMMANDS+="mkpart +OPL 128M PFS\n"
    COMMANDS+="exit"
    echo "Creating partitions..." >>"${LOG_FILE}"
    PFS_COMMANDS
fi

echo | tee -a "${LOG_FILE}"
echo -n "Installing PSBBN..." | tee -a "${LOG_FILE}"
mapper_probe
mount_cfs
mount_pfs

if [ "$MODE" = "install" ]; then
    sudo mkdir -p "${STORAGE_DIR}/__linux.8/MusicCh/contents"
    sudo mkdir -p "${STORAGE_DIR}/__common"/{POPS,"Your Saves"}
    sudo cp "${ASSETS_DIR}/POPStarter/eng"/{IGR_BG.TM2,IGR_NO.TM2,IGR_YES.TM2} "${STORAGE_DIR}/__common/POPS/"
fi

ALL_ERRORS=$(sudo tar zxpf "${PSBBN_PATCH}" -C "${STORAGE_DIR}/" 2>&1 >/dev/null)

FILTERED_ERRORS=$(echo "$ALL_ERRORS" | grep -v -e "Cannot change ownership" -e "tar: Exiting with failure status")

if [ -n "$FILTERED_ERRORS" ]; then
    echo "$FILTERED_ERRORS" >> "${LOG_FILE}"
    error_msg "Failed to install PSBBN." "See ${LOG_FILE} for details."
fi

if [ "$MODE" = "update" ]; then
    sudo tee -a "${STORAGE_DIR}/__linux.1/etc/rc.d/rc.sysinit" >/dev/null <<'EOF'
BUTTON=`cat /proc/ps2pad | awk '$1==0 { print $5; }'`
[ "$BUTTON" != "" -a "$BUTTON" != "FFFF" ] && /sbin/akload -r /boot/linux
EOF
fi

BOOTSTRAP
clean_up
echo | tee -a "${LOG_FILE}"

if [ "$MODE" = "install" ]; then
    echo | tee -a "${LOG_FILE}"
    echo -n "Running APA-Jail..." | tee -a "${LOG_FILE}"
    ################################### APA-Jail code by Berion ###################################

    # Signature injection (type A2):
    MAGIC_NUMBER="4150414A2D413200"
    apajail_magic_number

    # Setting up MBR:
    {
    echo -e ",128GiB,17\n,32MiB,17\n,,07" | sudo sfdisk ${DEVICE}
    sudo partprobe ${DEVICE}
    if [ "$(echo ${DEVICE} | grep -o /dev/loop)" = "/dev/loop" ]; then
	    sudo mke2fs -t ext2 -L "RECOVERY" ${DEVICE}p2
	    sudo "${HELPER_DIR}/mkfs.exfat" -c 32K -L "OPL" ${DEVICE}p3
	else
		sleep 4
		sudo mke2fs -t ext2 -L "RECOVERY" ${DEVICE}2
		sudo "${HELPER_DIR}/mkfs.exfat" -c 32K -L "OPL" ${DEVICE}3
        fi
    } >> "${LOG_FILE}" 2>&1

    PARTITION_NUMBER=3

    # Finalising recovery:
    if [ ! -d "${STORAGE_DIR}/recovery" ]; then
	    sudo mkdir -p "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
    fi

    if [ "$(echo ${DEVICE} | grep -o /dev/loop)" = "/dev/loop" ]; then
	    sudo mount ${DEVICE}p2 "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
	else
        sudo mount ${DEVICE}2 "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
    fi

    sudo dd if=${DEVICE} bs=128M count=1 status=noxfer 2>> "${LOG_FILE}" | xz -z > /tmp/apa_index.xz 2>> "${LOG_FILE}" 
    sudo cp /tmp/apa_index.xz "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
    LBA_MAX=$(sudo blockdev --getsize ${DEVICE})
    LBA_GPT_BUP=$(echo $(($LBA_MAX-33)))
    sudo dd if=${DEVICE} skip=${LBA_GPT_BUP} bs=512 count=33 status=noxfer 2>> "${LOG_FILE}" | xz -z > /tmp/gpt_2nd.xz 2>> "${LOG_FILE}"
    sudo cp /tmp/gpt_2nd.xz "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
    sync 2>> "${LOG_FILE}"
    sudo umount -l "${STORAGE_DIR}/recovery" 2>> "${LOG_FILE}"
    CHECK_PARTITIONS
    MOUNT_OPL

    if ! mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,bbnl}; then
        error_msg "Failed to create OPL folders."
    fi

    echo | tee -a "${LOG_FILE}"
    ###############################################################################################
else
    MOUNT_OPL
fi

echo "$LATEST_VERSION" > "${OPL}/version.txt"
echo "eng" >> "${OPL}/version.txt"

UNMOUNT_OPL
CHECK_PARTITIONS

echo >> "${LOG_FILE}"
echo "${TOC_OUTPUT}" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
if [ "$MODE" = "install" ]; then
    echo "[✓] PSBBN successfully installed." | tee -a "${LOG_FILE}"
else
    echo "[✓] PSBBN successfully updated." | tee -a "${LOG_FILE}"
    echo
    echo "Now connect the drive to your PS2 console and boot into PSBBN to complete the installation."
    echo "If you had PS2BBL installed before, you'll need to reinstall it from the Extras menu."
fi
echo
read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
echo
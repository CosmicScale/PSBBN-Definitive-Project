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

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0" >&2
    exit 1
fi

# Set paths
TOOLKIT_PATH="$(pwd)"
ASSETS_DIR="${TOOLKIT_PATH}/assets"
HELPER_DIR="${TOOLKIT_PATH}/helper"
OPL="${TOOLKIT_PATH}/OPL"
LOG_FILE="${TOOLKIT_PATH}/PSBBN-installer.log"
version_check="2.10"

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

# Clean up on exit (even if interrupted)
trap prevent_sleep_stop EXIT

error_msg() {
    type=$1
    error_1="$2"
    error_2="$3"
    error_3="$4"
    error_4="$5"

    echo
    echo "$type: $error_1" | tee -a "${LOG_FILE}"
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    if [ "$type" = "Error" ]; then
        read -n 1 -s -r -p "Press any key to exit..."
        echo
        exit 1;
    else
        read -n 1 -s -r -p "Press any key to continue..."
        echo
    fi
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${TOOLKIT_PATH}/OPL" >> "${LOG_FILE}" 2>&1; then
        error_msg "Error" "Failed to unmount $DEVICE"
    fi
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "Error" "PFS Shell returned an error. See ${LOG_FILE}"
fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition and creating folders..." | tee -a "${LOG_FILE}"
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || error_msg "Error" "Failed to create ${OPL}."

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Error" "Failed to mount ${DEVICE}3"
    fi
}

clear

# Set terminal size: 100 columns and 40 rows
echo -e "\e[8;45;100t"

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo
        echo "Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to exit..."
        echo
        exit 1
    fi
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    error_msg "Error" "Unsupported CPU architecture: $(uname -m). This script requires x86-64."
fi

cd "${TOOLKIT_PATH}"

# Check if the helper files exists
if [[ ! -f "${HELPER_DIR}/PFS Shell.elf" || ! -f "${HELPER_DIR}/HDL Dump.elf" ]]; then
    error_msg "Error" "Helper files not found. Scripts must be from the 'PSBBN-Definitive-English-Patch' directory."
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "PSBBN Definitive Patch Version 2.11" >> "${LOG_FILE}"
echo "Path set to: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo "Helper files found." >> "${LOG_FILE}"

# Choose the PS2 storage device
while true; do
    echo "              ______  _________________ _   _   _____          _        _ _           ";
    echo "              | ___ \/  ___| ___ \ ___ \ \ | | |_   _|        | |      | | |          ";
    echo "              | |_/ /\ \`--.| |_/ / |_/ /  \| |   | | _ __  ___| |_ __ _| | | ___ _ __ ";
    echo "              |  __/  \`--. \ ___ \ ___ \ . \` |   | || '_ \/ __| __/ _\` | | |/ _ \ '__|";
    echo "              | |    /\__/ / |_/ / |_/ / |\  |  _| || | | \__ \ || (_| | | |  __/ |   ";
    echo "              \_|    \____/\____/\____/\_| \_/  \___/_| |_|___/\__\__,_|_|_|\___|_|   ";
    echo "                                                                                    ";
    echo "                                       Written by CosmicScale"
    echo
    echo | tee -a "${LOG_FILE}"
    lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
        
    read -p "Choose your PS2 HDD from the list above (e.g., /dev/sdx): " DEVICE
        
    # Check if the device exists
    if [[ -n "$DEVICE" ]] && lsblk -dp -n -o NAME | grep -q "^$DEVICE$"; then
        # Check the size of the chosen device
        SIZE_CHECK=$(lsblk -o NAME,SIZE -b | grep -w $(basename $DEVICE) | awk '{print $2}')

        # Convert size to GB (1 GB = 1,000,000,000 bytes)
        size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)
        
        if (( size_gb < 200 )); then
            error_msg "Error" "Device is $size_gb GB. Required minimum is 200 GB."
        else
            echo
            echo "Selected drive: ${DEVICE}" | tee -a "${LOG_FILE}"
            echo
            echo "Are you sure you want to write to ${DEVICE}?" | tee -a "${LOG_FILE}"
            read -p "This will erase all data on the drive. (yes/no): " CONFIRM
            if [[ $CONFIRM == "yes" ]]; then
                break
            else
                echo "Aborted." | tee -a "${LOG_FILE}"
                read -n 1 -s -r -p "Press any key to exit..."
                echo
                exit 1
            fi
        fi
    else
        error_msg "Error" "Invalid input. Please enter a valid device name (e.g., /dev/sdx)."
    fi
done

# Find all mounted volumes associated with the device
mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

# Iterate through each mounted volume and unmount it
echo | tee -a "${LOG_FILE}"
echo "Unmounting volumes associated with $DEVICE..."
for mount_point in $mounted_volumes; do
    echo "Unmounting $mount_point..." | tee -a "${LOG_FILE}"
    if sudo umount "$mount_point"; then
        echo "Successfully unmounted $mount_point." | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Failed to unmount $mount_point. Please unmount manually."
    fi
done

echo "All volumes unmounted for $DEVICE."

prevent_sleep_start

# URL of the webpage
URL="https://archive.org/download/psbbn-definitive-english-patch-v2"
echo | tee -a "${LOG_FILE}"
echo -n "Checking for latest version of the PSBBN Definitive English patch..." | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

# Download the HTML of the page
HTML_FILE=$(mktemp)
wget -O "$HTML_FILE" "$URL" >> "${LOG_FILE}" 2>&1

# Extract .gz filenames from the HTML
COMBINED_LIST=$(grep -oP 'psbbn-definitive-image-v[0-9]+\.[0-9]+\.gz' "$HTML_FILE")

# Extract version numbers and sort them
VERSION_LIST=$(echo "$COMBINED_LIST" | \
    grep -oP 'v[0-9]+\.[0-9]+' | \
    sed 's/v//' | \
    sort -V)

# Determine the latest version from the sorted list
LATEST_VERSION=$(echo "$VERSION_LIST" | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "Could not find the latest version." | tee -a "${LOG_FILE}"
    # If $LATEST_VERSION is empty, check for psbbn-definitive-image*.gz files
    IMAGE_FILE=$(ls "${ASSETS_DIR}"/psbbn-definitive-image*.gz 2>/dev/null)
    if [ -n "$IMAGE_FILE" ]; then
        # If image file exists, set LATEST_FILE to the image file name
        LATEST_FILE=$(basename "$IMAGE_FILE")
        echo "Found local file: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
    else
        rm -f "$HTML_FILE"
        error_msg "Error" "Failed to download PSBBN image file. Aborting."
    fi
else
    # Set the default latest file based on remote version
    LATEST_FILE="psbbn-definitive-image-v${LATEST_VERSION}.gz"
    echo "Latest version of PSBBN Definitive English patch is v${LATEST_VERSION}" | tee -a "${LOG_FILE}"

    # Check if any local file is newer than the remote version
    IMAGE_FILE=$(ls "${ASSETS_DIR}"/psbbn-definitive-image*.gz 2>/dev/null | sort -V | tail -n1)
    if [ -n "$IMAGE_FILE" ]; then
        LOCAL_VERSION=$(echo "$IMAGE_FILE" | sed -E 's/.*-v([0-9.]+)\.gz/\1/')
        # Compare local vs remote version
        if [ "$(printf '%s\n' "$LATEST_VERSION" "$LOCAL_VERSION" | sort -V | tail -n1)" != "$LATEST_VERSION" ]; then
            LATEST_VERSION="$LOCAL_VERSION"
            LATEST_FILE=$(basename "$IMAGE_FILE")
            echo "Newer local file found: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
        fi
    fi
fi

if [ "$(printf '%s\n' "$version_check" "$LATEST_VERSION" | sort -V | head -n1)" = "$version_check" ]; then
    echo "Latest version: $LATEST_VERSION"
else
    error_msg "Error" "Latest version $LATEST_VERSION is older than required version $version_check. Please try again later."
fi

# Check if the latest file exists in ${ASSETS_DIR}
if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
    echo "File ${LATEST_FILE} exists in ${ASSETS_DIR}." | tee -a "${LOG_FILE}"
    echo "Skipping download." | tee -a "${LOG_FILE}"
else
    # Check for and delete older files
    for file in "${ASSETS_DIR}"/psbbn-definitive-image*.gz; do
        if [[ -f "$file" && "$(basename "$file")" != "$LATEST_FILE" ]]; then
            echo "Deleting old file: $file" | tee -a "${LOG_FILE}"
            rm -f "$file"
        fi
    done

    # Construct the full URL for the .gz file and download it
    ZIP_URL="$URL/$LATEST_FILE"
    echo "Downloading ${LATEST_FILE}..." | tee -a "${LOG_FILE}"
    axel -n 8 -a "$ZIP_URL" -o "${ASSETS_DIR}"

    # Check if the file was downloaded successfully
    if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
        echo "Download completed: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
    else
        error_msg "Error" "Download failed for ${LATEST_FILE}. Please check your internet connection and try again."
    fi
fi

# Clean up
rm -f "$HTML_FILE"

PSBBN_IMAGE="${ASSETS_DIR}/${LATEST_FILE}"

# Write the PSBBN image
echo | tee -a "${LOG_FILE}"
echo "Writing the PSBBN image to ${DEVICE}..." | tee -a "${LOG_FILE}"
if gunzip -c ${PSBBN_IMAGE} | sudo dd of=${DEVICE} bs=4M status=progress 2>&1 | tee -a "${LOG_FILE}" ; then
    sync
    echo
    echo "Verifying installation..."
    if sudo "${TOOLKIT_PATH}"/helper/HDL\ Dump.elf toc "${DEVICE}" >> "${LOG_FILE}" 2>&1; then
        echo "Verification successful. PSBBN image installed successfully." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to continue.."
        echo
    else
        error_msg "Error" "Verification failed on ${DEVICE}."
    fi
else
    error_msg "Error" "Failed to write the image to ${DEVICE}."
fi

# Retreive avaliable space

output=$(sudo "${TOOLKIT_PATH}"/helper/HDL\ Dump.elf toc ${DEVICE} 2>&1)

# Extract the "used" value, remove "MB" and any commas
used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
capacity=129960

# Calculate available space (capacity - used)
available=$((capacity - used - 6400 - 128))
free_space=$((available / 1024))
max_music=$(((available - 1024) / 1024))

# Prompt user for partition size for music and POPS, validate input, and keep asking until valid input is provided
while true; do
    clear  
    echo | tee -a "${LOG_FILE}"
    echo "Partitioning the first 128 GB of the drive:"
    echo
    echo "Available: $free_space GB" | tee -a "${LOG_FILE}"
    echo
    echo "What size would you like the \"Music\" partition to be?"
    echo "Minimum 1 GB, maximum $max_music GB"
    echo
    read -p "Enter partition size (in GB): " music_gb

    if [[ ! "$music_gb" =~ ^[0-9]+$ ]]; then
        echo
        echo "Invalid input. Please enter a valid number."
        sleep 3
        continue
    fi

    if (( music_gb < 1 || music_gb > max_music )); then
        echo
        echo "Invalid size. Please enter a value between 1 and $max_music GB."
        sleep 3
        continue
    fi

    remaining_gb=$((free_space - music_gb))
    echo
    echo "What size would you like the \"POPS\" partition to be?"
    echo "Minimum 1 GB, maximum $remaining_gb GB"
    echo
    read -p "Enter partition size (in GB): " pops_gb

    if [[ ! "$pops_gb" =~ ^[0-9]+$ ]]; then
        echo
        echo "Invalid input. Please enter a valid number."
        sleep 3
        continue
    fi

    if (( pops_gb < 1 || pops_gb > remaining_gb )); then
        echo
        echo "Invalid size. Please enter a value between 1 and $remaining_gb GB."
        sleep 3
        continue
    fi

    allocated_gb=$((music_gb + pops_gb))
    unallocated_gb=$((free_space - allocated_gb))
    echo
    echo "The following partitions will be created:"
    echo "- Music partition: $music_gb GB"
    echo "- POPS partition: $pops_gb GB"
    echo "- Remaining space: $unallocated_gb GB"
    echo
    read -p "Do you wish to proceed? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        music_partition=$((music_gb * 1024))
        pops_partition=$((pops_gb * 1024))
        break
    fi
done

echo >> "${LOG_FILE}"
echo "Music partition size: $music_partition" >> "${LOG_FILE}"
echo "POPS partition size: $pops_partition" >> "${LOG_FILE}"

COMMANDS="device ${DEVICE}\n"
COMMANDS+="mkpart __linux.8 ${music_partition}M REISER\n"
COMMANDS+="mkpart __.POPS ${pops_partition}M PFS\n"
COMMANDS+="mkpart +OPL 128M PFS\n"
COMMANDS+="mount __common\n"
COMMANDS+="lcd '${TOOLKIT_PATH}/assets/POPStarter'\n"
COMMANDS+="mkdir POPS\n"
COMMANDS+="mkdir 'Your Saves'\n"
COMMANDS+="cd POPS\n"
COMMANDS+="put IGR_BG.TM2\n"
COMMANDS+="put IGR_NO.TM2\n"
COMMANDS+="put IGR_YES.TM2\n"
COMMANDS+="cd /\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

PFS_COMMANDS



################################### APA-Jail code by Berion ###################################

apajail_magic_number() {
	echo ${MAGIC_NUMBER} | xxd -r -p > /tmp/apajail_magic_number.bin
	sudo dd if=/tmp/apajail_magic_number.bin of=${DEVICE} bs=8 count=1 seek=28 conv=notrunc >> "${LOG_FILE}" 2>&1
	}

apa_checksum_fix() {
	sudo dd if=${DEVICE} of=/tmp/apa_header_full.bin bs=512 count=2 >> "${LOG_FILE}" 2>&1
	"${TOOLKIT_PATH}/helper/PS2 APA Header Checksum Fixer.elf" /tmp/apa_header_full.bin | sed -n 8p | awk '{print $6}' | xxd -r -p > /tmp/apa_header_checksum.bin 2>> "${LOG_FILE}"
	sudo dd if=/tmp/apa_header_checksum.bin of=${DEVICE} conv=notrunc >> "${LOG_FILE}" 2>&1
	}

clear_temp() {
	sudo rm -f /tmp/apa_header_checksum.bin	&>> "${LOG_FILE}"
	sudo rm -f /tmp/apa_header_full.bin			&>> "${LOG_FILE}"
	sudo rm -f /tmp/apajail_magic_number.bin	&>> "${LOG_FILE}"
	sudo rm -f /tmp/apa_index.xz					&>> "${LOG_FILE}"
	sudo rm -f /tmp/gpt_2nd.xz						&>> "${LOG_FILE}"
	}

echo | tee -a "${LOG_FILE}"
echo -n "Running APA-Jail by Berion..." | tee -a "${LOG_FILE}"

# Signature injection (type A2):
MAGIC_NUMBER="4150414A2D413200"
apajail_magic_number

# Setting up MBR:
{
echo -e ",128GiB,17\n,32MiB,17\n,,07" | sudo sfdisk ${DEVICE}
sudo partprobe ${DEVICE}
if [ "$(echo ${DEVICE} | grep -o /dev/loop)" = "/dev/loop" ]; then
	sudo mkfs.ext2 -L "RECOVERY" ${DEVICE}p2
	sudo "${TOOLKIT_PATH}/helper/mkfs.exfat" -c 32K -L "OPL" ${DEVICE}p3
	else
		sleep 4
		sudo mkfs.ext2 -L "RECOVERY" ${DEVICE}2
		sudo "${TOOLKIT_PATH}/helper/mkfs.exfat" -c 32K -L "OPL" ${DEVICE}3
fi
} >> "${LOG_FILE}" 2>&1

PARTITION_NUMBER=3

# Finalising recovery:
if [ ! -d "${TOOLKIT_PATH}/storage/hdd/recovery" ]; then
	mkdir -p "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
fi
if [ "$(echo ${DEVICE} | grep -o /dev/loop)" = "/dev/loop" ]; then
	sudo mount ${DEVICE}p2 "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
	else sudo mount ${DEVICE}2 "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
fi
sudo dd if=${DEVICE} bs=128M count=1 status=noxfer 2>> "${LOG_FILE}" | xz -z > /tmp/apa_index.xz 2>> "${LOG_FILE}"
sudo cp /tmp/apa_index.xz "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
LBA_MAX=$(sudo blockdev --getsize ${DEVICE})
LBA_GPT_BUP=$(echo $(($LBA_MAX-33)))
sudo dd if=${DEVICE} skip=${LBA_GPT_BUP} bs=512 count=33 status=noxfer 2>> "${LOG_FILE}" | xz -z > /tmp/gpt_2nd.xz 2>> "${LOG_FILE}"
sudo cp /tmp/gpt_2nd.xz "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
sync 2>> "${LOG_FILE}"
sudo umount -l "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"
rmdir "${TOOLKIT_PATH}/storage/hdd/recovery" 2>> "${LOG_FILE}"

apa_checksum_fix

clear_temp

unset LBA_GPT_BUP
unset LBA_MAX
unset MAGIC_NUMBER
unset PARTITION_NUMBER

###############################################################################################
echo | tee -a "${LOG_FILE}"

# Run the command and capture output
echo >> "${LOG_FILE}"
TOC_OUTPUT=$(sudo "${TOOLKIT_PATH}/helper/HDL Dump.elf" toc "${DEVICE}")
STATUS=$?

if [ $STATUS -ne 0 ]; then
    error_msg "Error" "APA partition is broken on ${DEVICE}. Install failed."
fi

if echo "${TOC_OUTPUT}" | grep -q '__.POPS' && echo "${TOC_OUTPUT}" | grep -q '__linux.8'; then
    echo
    echo "POPS and Music partitions were created successfully." | tee -a "${LOG_FILE}"
else
    echo
    error_msg "Error" "Some partitions are missing on ${DEVICE}. See log for details."
fi

MOUNT_OPL

# Create necessary folders if they don't exist
for folder in APPS ART CFG CHT LNG THM VMC CD DVD bbnl; do
    dir="${OPL}/${folder}"
    [[ -d "$dir" ]] || mkdir -p "$dir" || { 
        error_msg "Error" "Failed to create $dir."
    }
done

echo "$LATEST_VERSION" > "${OPL}/version.txt"
echo "eng" >> "${OPL}/version.txt"

UNMOUNT_OPL

echo >> "${LOG_FILE}"
echo "${TOC_OUTPUT}" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "PSBBN successfully installed." | tee -a "${LOG_FILE}"
echo
read -n 1 -s -r -p "Press any key to exit..."
echo

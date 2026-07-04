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

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0" >&2
    exit 1
fi

# Set terminal size: 100 columns and 40 rows
echo -e "\e[8;40;100t"

# Set paths
TOOLKIT_PATH="$(pwd)"
HELPER_DIR="${TOOLKIT_PATH}/helper"
ASSETS_DIR="${TOOLKIT_PATH}/assets"
OPL="${TOOLKIT_PATH}/OPL"
LOG_FILE="${TOOLKIT_PATH}/extras.log"

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

cd "${TOOLKIT_PATH}"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Error: This script requires an x86-64 CPU architecture. Detected: $(uname -m)" | tee -a "${LOG_FILE}"
  read -n 1 -s -r -p "Press any key to exit..."
  echo
  exit 1
fi

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

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "PSBBN Definitive Patch Version 2.11" >> "${LOG_FILE}"
echo "Path set to: $TOOLKIT_PATH" >> "${LOG_FILE}"

# Function to detect PS2 HDD

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "Error: Unable to detect PS2 drive." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the main menu..."
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
            echo "Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
            echo
            echo "Failed to unmount $mount_point. Please unmount manually." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return 1
        fi
    done

    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo
        echo "Error: APA partition is broken on ${DEVICE}." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the main menu..."
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
        echo "Error: Could not determine device size."
        return 1
    fi

    # Convert size to GB (1 GB = 1,000,000,000 bytes)
    size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)

    if (( size_gb > 960 )); then
        echo
        echo "Warning: Device is $size_gb GB. HDD-OSD may experience issues with drives larger than 960 GB." | tee -a "${LOG_FILE}"
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
        read -n 1 -s -r -p "Failed to create ${OPL}. Press any key to return to the main menu..."
        return 1
    fi

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Error" "Failed to mount ${DEVICE}3"
    fi

    # Create necessary folders if they don't exist
    for folder in APPS ART CFG CHT LNG THM VMC CD DVD bbnl; do
        dir="${OPL}/${folder}"
        [[ -d "$dir" ]] || mkdir -p "$dir" || { 
            error_msg "Error" "Failed to create $dir."
        }
    done
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${TOOLKIT_PATH}/OPL" >> "${LOG_FILE}" 2>&1; then
        read -n 1 -s -r -p "Failed to unmount $DEVICE. Press any key to return to the main menu..."
        return 1;
    fi
}

DOWNLOAD_BNUPDATE() {
    # URL of the webpage
    URL="https://archive.org/download/psbbn-definitive-english-patch-v2"
    echo -n "Checking for latest version of the PSBBN Definitive English patch..." | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"

    # Download the HTML of the page
    HTML_FILE=$(mktemp)
    wget -O "$HTML_FILE" "$URL" >> "${LOG_FILE}" 2>&1

    # Extract .zip filenames from the HTML
    COMBINED_LIST=$(grep -oP 'bnupdate-v[0-9]+\.[0-9]+\.tar.gz' "$HTML_FILE")

    # Extract version numbers and sort them
    VERSION_LIST=$(echo "$COMBINED_LIST" | \
        grep -oP 'v[0-9]+\.[0-9]+' | \
        sed 's/v//' | \
        sort -V)

    # Determine the latest version from the sorted list
    LATEST_VERSION=$(echo "$VERSION_LIST" | tail -n 1)

    if [ -z "$LATEST_VERSION" ]; then
        echo "Could not find the latest version." | tee -a "${LOG_FILE}"
        # If $LATEST_VERSION is empty, check for bnupdate.zip files
        IMAGE_FILE=$(ls "${ASSETS_DIR}"/bnupdate*.tar.gz 2>/dev/null)
        if [ -n "$IMAGE_FILE" ]; then
            # If image file exists, set LATEST_FILE to the image file name
            LATEST_FILE=$(basename "$IMAGE_FILE")
            LATEST_VERSION=$(echo "$IMAGE_FILE" | sed -E 's/.*-v([0-9.]+)\.tar.gz/\1/')
            echo "Found local file: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
        else
            rm -f "$HTML_FILE"
            echo "Failed to download PSBBN update file. Aborting." | tee -a "${LOG_FILE}"
            echo
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return 1
        fi
    else
        # Set the default latest file based on remote version
        LATEST_FILE="bnupdate-v${LATEST_VERSION}.tar.gz"
        echo "Latest version of PSBBN Definitive English patch is v${LATEST_VERSION}" | tee -a "${LOG_FILE}"

        # Check if any local file is newer than the remote version
        IMAGE_FILE=$(ls "${ASSETS_DIR}"/bnupdate*.tar.gz 2>/dev/null | sort -V | tail -n1)
        if [ -n "$IMAGE_FILE" ]; then
            LOCAL_VERSION=$(echo "$IMAGE_FILE" | sed -E 's/.*-v([0-9.]+)\.tar.gz/\1/')
            # Compare local vs remote version
            if [ "$(printf '%s\n' "$LATEST_VERSION" "$LOCAL_VERSION" | sort -V | tail -n1)" != "$LATEST_VERSION" ]; then
                LATEST_VERSION="$LOCAL_VERSION"
                LATEST_FILE=$(basename "$IMAGE_FILE")
                echo "Newer local file found: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
            fi
        fi
    fi

    echo
    echo "Latest version: $LATEST_VERSION"
    echo "Current version: $psbbn_version"
    
    if [ "$(printf '%s\n' "$LATEST_VERSION" "$psbbn_version" | sort -V | tail -n1)" = "$psbbn_version" ]; then
        UNMOUNT_OPL
        echo "You are already running the latest version" | tee -a "${LOG_FILE}"
        echo
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        return 1
    fi

    echo
    echo "To finalize this update, you will need:"
    echo
    echo "- A FAT32-formatted USB drive, 128 GB or smaller"
    echo "- A USB keyboard"
    echo
    read -n 1 -r -p "Do you wish to continue? [y/n] " choice
    echo  # move to a new line after the user's input
    echo
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        read -n 1 -s -r -p "Update cancelled. Press any key to return to the main menu..."
        return 1
    fi
    # Check if the latest file exists in ${ASSETS_DIR}
    if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
        echo "File ${LATEST_FILE} exists in ${ASSETS_DIR}." >> "${LOG_FILE}"
        echo "Skipping download." >> "${LOG_FILE}"
    else
        # Check for and delete older files
        for file in "${ASSETS_DIR}"/bnupdate*.tar.gz; do
            if [[ -f "$file" && "$(basename "$file")" != "$LATEST_FILE" ]]; then
                echo "Deleting old file: $file" | tee -a "${LOG_FILE}"
                rm -f "$file"
            fi
        done

        # Construct the full URL for the .zip file and download it
        ZIP_URL="$URL/$LATEST_FILE"
        echo "Downloading ${LATEST_FILE}..." | tee -a "${LOG_FILE}"
        axel -n 8 -a "$ZIP_URL" -o "${ASSETS_DIR}"

        # Check if the file was downloaded successfully
        if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
            echo "Download completed: ${LATEST_FILE}" | tee -a "${LOG_FILE}"
        else
            echo "Download failed for ${LATEST_FILE}. Please check your internet connection and try again." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return 1
        fi
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
            echo "Files successfully extracted." | tee -a "${LOG_FILE}"
        else
            echo | tee -a "${LOG_FILE}"
            echo "Error: One or more files are missing after extraction." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return 1
        fi
    fi
}

# Function for Option 1 - Update PSBBN Software
option_one() {
    clear

    if ! detect_drive; then
        return
    fi

    MOUNT_OPL

    version_check="2.10"
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)

    # Compare using sort -V
    if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
        UNMOUNT_OPL
        echo "Error: PSBBN Definitive Patch version lower than 2.10 cannot be updated."
        echo "Please run the '02-PSBBN-Installer.sh' script to update to the latest version."
        echo
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        return
    fi

    if ! DOWNLOAD_BNUPDATE; then
        return
    fi

    if [ "$psbbn_version" = "2.10" ]; then

        download_files

        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mount __sysconf\n"
        COMMANDS+="ls\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"
        BBL_FOLDER=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null)
        echo "$BBL_FOLDER" >> "${LOG_FILE}"

        if echo "$BBL_FOLDER" | grep -q "PS2BBL/"; then
            BBL="TRUE"
            echo  >> "${LOG_FILE}"
            echo "BBL is installed." >> "${LOG_FILE}"
        else
            BBL="FALSE"
            echo >> "${LOG_FILE}"
            echo "BBL not installed." >> "${LOG_FILE}"
        fi

        # Copy HDD-OSD files to __system
        COMMANDS="device ${DEVICE}\n"
        COMMANDS+="mount __system\n"
        COMMANDS+="cd p2lboot\n"
        COMMANDS+="lcd '${ASSETS_DIR}/kernel'\n"
        COMMANDS+="rm vmlinux\n"
        COMMANDS+="put vmlinux\n"
        COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
        
        if [ "$BBL" = "TRUE" ]; then
            COMMANDS+="rm PSBBN.ELF\n"
            COMMANDS+="put PSBBN.ELF\n"
        else
            COMMANDS+="rm osdboot.elf\n"
            COMMANDS+="put osdboot.elf\n"
        fi
        COMMANDS+="cd /\n"
        COMMANDS+="umount\n"
        COMMANDS+="exit"

        # Pipe all commands to PFS Shell for mounting, copying, and unmounting
        PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1)
        if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
            echo "Error: PFS Shell returned an error. See ${LOG_FILE}"
            echo
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return
        else
            echo "PSBBN kernel and binary sucessfully updated!"
        fi

        cp "${ASSETS_DIR}/extras/PSBBN.ELF" "${TOOLKIT_PATH}/games/APPS" >> "${LOG_FILE}" 2>&1

        if [ -d "${OPL}/APPS/PSBBN/" ]; then
            echo "Copying PSBBN.ELF to ${OPL}/APPS/PSBBN/" >> "${LOG_FILE}"
            cp "${ASSETS_DIR}/extras/PSBBN.ELF" "${OPL}/APPS/PSBBN/"
        elif [ -d "${OPL}/APPS/BBNAVIGATOR/" ]; then
            echo "Copying PSBBN.ELF to ${OPL}/APPS/BBNAVIGATOR/" >> "${LOG_FILE}"
            cp "${ASSETS_DIR}/extras/PSBBN.ELF" "${OPL}/APPS/BBNAVIGATOR/"
        fi
    fi

    if cp "${ASSETS_DIR}/$LATEST_FILE" "${TOOLKIT_PATH}/bnupdate.tar.gz"; then
        echo "$LATEST_VERSION" > "${OPL}/version.txt"
        echo "eng" >> "${OPL}/version.txt"
    else
        echo "Failed generate the update file."
        echo
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        return
    fi

    echo
    echo "To complete the update:"
    echo
    echo "1. Copy '${TOOLKIT_PATH}/bnupdate.tar.gz' to a USB drive"
    echo "2. Connect the HDD/SSD to your PS2 console"
    echo "3. Connect the USB drive and a USB keyboard to the PS2 console"
    echo "4. Turn on the console and hold any controller button at the "PlayStation 2" logo until Linux boots."
    echo "5. Log in as 'root' — the password is 'password'"
    echo "6. Type 'bnupdate' and press Enter to install the update"
    echo "7. Type 'halt' and press Enter to shut down the console"

    UNMOUNT_OPL
    echo
    read -n 1 -s -r -p "Press any key to return to the main menu..."

}

# Function for Option 2 - Install HDD-OSD
option_two() {

    clear

    if ! detect_drive; then
        return
    fi

    # Now check size
    if ! check_device_size; then
        return
    fi

    if ! download_files; then
        return
    fi

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
    echo "HDD-OSD installed sucessfully." | tee -a "${LOG_FILE}"
    echo
    echo "Please run '03-Game-Installer.sh' to add HDD-OSD to the PSBBN Game Channel and update the icons"
    echo "for your game collection."
    echo
    read -n 1 -s -r -p "Press any key to return to the main menu..."
}

# Function for Option 3 - Install PlayStation 2 Basic Boot Loader (PS2BBL)
option_three() {
    clear
    
    if ! download_files; then
        return
    fi

    if ! detect_drive; then
        return
    fi

    # Copy PS2BBL files to __system and __sysconf
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="cd p2lboot\n"
    COMMANDS+="rm osdboot.elf\n"
    COMMANDS+="put PSBBN.ELF\n"
    COMMANDS+="lcd '${ASSETS_DIR}/PS2BBL'\n"
    COMMANDS+="put osdboot.elf\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="mount __sysconf\n"
    COMMANDS+="mkdir PS2BBL\n"
    COMMANDS+="cd PS2BBL\n"
    COMMANDS+="put CONFIG.INI\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "PS2BBL installed sucessfully."
    echo
    read -n 1 -s -r -p "Press any key to return to the main menu..."

}

# Function for Option 4 - Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)
option_four() {
    clear

    if ! download_files; then
        return
    fi

    if ! detect_drive; then
        return
    fi

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
    echo "PS2BBL sucessfully uninstalled."
    echo
    read -n 1 -s -r -p "Press any key to return to the main menu..."
}


# Function to display the menu
display_menu() {
    clear

    echo "                                     _____     _                 "
    echo "                                    |  ___|   | |                "
    echo "                                    | |____  _| |_ _ __ __ _ ___"
    echo "                                    |  __\\ \\/ / __| '__/ _\` / __|"
    echo "                                    | |___>  <| |_| | | (_| \\__ \\"
    echo "                                    \\____/_/\\_\\\\__|_|  \\__,_|___/"                      
    echo ""
    echo "                                        Written by CosmicScale"
    echo ""
    echo ""
    echo "     1) Update PSBBN Software"
    echo "     2) Install HDD-OSD/Browser 2.0"
    echo "     3) Install PlayStation 2 Basic Boot Loader (PS2BBL)"
    echo "     4) Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)"
    echo "     q) Quit"
    echo ""
    echo ""
}

# Main loop

while true; do
    display_menu
    read -p "     Select an option: " choice

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
        q|Q)
            break
            ;;
        *)
            echo
            echo "     Invalid option, please try again."
            sleep 2
            ;;
    esac
done

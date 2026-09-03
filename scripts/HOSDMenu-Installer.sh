#!/usr/bin/env bash
#
# HOSDMenu Installer form the PSBBN Definitive Project
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
term_width=110

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

# Set paths
version_check="2.10"
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
HELPER_DIR="${SCRIPTS_DIR}/helper"
LANG_DIR="${ASSETS_DIR}/lang"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/hosdmenu.log"
arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/aarch64/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/aarch64/PS2 APA Header Checksum Fixer.elf"
fi

LANG_FILE="$1"
shift  # remove language

for arg in "$@"; do
    [[ -z "$arg" ]] && continue

    if [[ "$arg" == /* ]]; then
        path_arg="${arg%/}"
    elif [[ -z "$serialnumber" ]]; then
        serialnumber="$arg"
    fi
done

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

APA_PARTITIONS=("__system" "__common" "__sysconf" )

if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")

    if [ "$size" -gt 4194304 ]; then
        : > "$LOG_FILE"
    fi
fi

error_msg() {
    error_1="[X] $1"
    error_2="$2"
    error_3="$3"
    error_4="$4"

    echo
    echo
    echo "$error_1"
    [ -n "$error_2" ] && echo "$error_2"
    [ -n "$error_3" ] && echo "$error_3"
    [ -n "$error_4" ] && echo "$error_4"
    echo
    echo "${UI_TEXT[ERROR_TROUBLE]}"
    echo "${UI_TEXT[TROUBLE_URL]}"
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
    echo
    exit 1
}

clean_up() {
    failure=0

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || {
                    echo "[X] Error: Failed to unmount $line" >> "${LOG_FILE}"
                    error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $line"
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

    # Clean up directories and temp files
    sudo rm -rf /tmp/{apa_header_checksum.bin,apa_header_full.bin,apajail_magic_number.bin,apa_index.xz,gpt_2nd.xz} >> "${LOG_FILE}" 2>&1
    
    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo "[X] Error: Cleanup error(s) occurred. Aborting."
        error_msg "${UI_TEXT[ERROR_CLEANUP]}"
    fi

}

exit_script() {
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

PFS_COMMANDS() {
    PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
    if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
        echo "[X] Error: PFS Shell returned an error." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PFS_COMMANDS]}"
    fi
}

mount_pfs() {
    for PARTITION_NAME in "${APA_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        sudo mkdir -p "$MOUNT_POINT"
        if ! sudo "${PFS_FUSE}" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to mount $PARTITION_NAME" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_MOUNT_2]} $PARTITION_NAME"
        fi
    done
}

apa_checksum_fix() {
	sudo dd if=${DEVICE} of=/tmp/apa_header_full.bin bs=512 count=2 >> "${LOG_FILE}" 2>&1
	"${APA_FIXER}" /tmp/apa_header_full.bin | sed -n 8p | awk '{print $6}' | xxd -r -p > /tmp/apa_header_checksum.bin 2>> "${LOG_FILE}"
	sudo dd if=/tmp/apa_header_checksum.bin of=${DEVICE} conv=notrunc >> "${LOG_FILE}" 2>&1
}

apajail_magic_number() {
	echo ${MAGIC_NUMBER} | xxd -r -p > /tmp/apajail_magic_number.bin
	sudo dd if=/tmp/apajail_magic_number.bin of=${DEVICE} bs=8 count=1 seek=28 conv=notrunc >> "${LOG_FILE}" 2>&1
}

BOOTSTRAP() {
    if [ -f "${ASSETS_DIR}/osdmenu/OSDMBR.XLF" ]; then
	    # BOOTSTRAP METADATA:
	    BOOTSTRAP_ADDRESS_HEX_BE=0020
	    BOOTSTRAP_SIZE=$(wc -c "${ASSETS_DIR}/osdmenu/OSDMBR.XLF" | cut -d' ' -f 1)
	    BOOTSTRAP_SIZE_LBA=$(echo "$((${BOOTSTRAP_SIZE}/512))")
	    BOOTSTRAP_SIZE_LBA_HEX_BE=$(printf "%04X" ${BOOTSTRAP_SIZE_LBA} | tac -rs .. | echo "$(tr -d '\n')")
	    echo "${BOOTSTRAP_ADDRESS_HEX_BE}0000${BOOTSTRAP_SIZE_LBA_HEX_BE}0000" | xxd -r -p > /tmp/apa_header_boot.bin 2>> "${LOG_FILE}"

	    # METADATA & BOOTSTRAP WRITING:
	    # 130h = 304d
	    sudo dd if=/tmp/apa_header_boot.bin of=${DEVICE} bs=1 seek=304 >> "${LOG_FILE}" 2>&1
	    # 2000h * 200h = 8192d * 512d = 4194304d = 400000h
	    sudo dd if="${ASSETS_DIR}/osdmenu/OSDMBR.XLF" of=${DEVICE} bs=1M count=1 seek=4 conv=notrunc >> "${LOG_FILE}" 2>&1
    else
	    echo "[X] Error: Failed to inject OSDMenu MBR." >> "${LOG_FILE}"
	    error_msg "${UI_TEXT[ERROR_BOOTSTRAP]}"
    fi
}

CHECK_PARTITIONS() {
# Run the command and capture output
    apa_checksum_fix
    TOC_OUTPUT=$(sudo "${HDL_DUMP}" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        error_msg "APA partition is broken on ${DEVICE}. Install failed."
    fi

    if echo "${TOC_OUTPUT}" | grep -Eq '\b(__contents|__system|__sysconf|__common)\b'; then
        echo "All partitions exist." >> "${LOG_FILE}"
    else
        echo "[X] Error: Some partitions are missing." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CHECK_PARTITIONS_2]}"
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
            echo "[X] Error: Failed to unmount $mount_point." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $mount_point."
        fi
    done
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to unmount $DEVICE" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $DEVICE"
    fi
}

MOUNT_OPL() {
    echo "Mounting OPL partition." >> "${LOG_FILE}"
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}" 2>&1
        error_msg "${UI_TEXT[ERROR_CREATE]} ${OPL}"
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
    fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
    fi
}

hdd_osd_files_present() {
    local files=(
        FNTOSD
        ICOIMAGE
        JISUCS
        OSDSYS_A.XLF
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
    if hdd_osd_files_present; then
        echo "All required files are present. Skipping download" >> "${LOG_FILE}"
    else
        echo "Required files are missing in ${ASSETS_DIR}/extras." >> "${LOG_FILE}"
        # Check if extras.zip exists
        if [[ -f "${ASSETS_DIR}/extras.zip" && ! -f "${ASSETS_DIR}/extras.zip.st" ]]; then
            echo "extras.zip found in ${ASSETS_DIR}. Extracting..." >> "${LOG_FILE}"
            bsdtar -xf "${ASSETS_DIR}/extras.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        else
            echo "Downloading..." >> "${LOG_FILE}"
            echo -n "${UI_TEXT[DOWNLOAD_LATEST_FILE_2]}..."
            curl -s -m 10 --retry 3 -o "${ASSETS_DIR}/extras.zip" https://archive.org/download/psbbn-definitive-english-patch-v2/extras.zip
            echo
            if [[ -s "${ASSETS_DIR}/extras.zip" ]]; then
                bsdtar -xf "${ASSETS_DIR}/extras.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
            else
                rm "${ASSETS_DIR}/extras.zip"
                echo "[X] Error: Download failed for HDD-OSD." >> "${LOG_FILE}" 2>&1
                error_msg "${UI_TEXT[ERROR_LATEST_FILE_1]} HDD-OSD." "${UI_TEXT[GET_LATEST_FILE_3]}"
            fi
        fi
        # Check if HDD-OSD files exist after extraction
        if hdd_osd_files_present; then
            echo | tee -a "${LOG_FILE}"
            echo "[✓] Files successfully extracted." >> "${LOG_FILE}"
        else
            echo "[X] Error: One or more files are missing after extraction." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_EXTRACTION]}"
        fi
    fi
}

SPLASH(){
    clear
        cat << "EOF"
          _   _ _____ ______________  ___                   _____          _        _ _ 
         | | | |  _  /  ___|  _  \  \/  |                  |_   _|        | |      | | |
         | |_| | | | \ `--.| | | | .  . | ___ _ __  _   _    | | _ __  ___| |_ __ _| | | ___ _ __ 
         |  _  | | | |`--. \ | | | |\/| |/ _ \ '_ \| | | |   | || '_ \/ __| __/ _` | | |/ _ \ '__|
         | | | \ \_/ /\__/ / |/ /| |  | |  __/ | | | |_| |  _| || | | \__ \ || (_| | | |  __/ |
         \_| |_/\___/\____/|___/ \_|  |_/\___|_| |_|\__,_|  \___/_| |_|___/\__\__,_|_|_|\___|_|


EOF
}

clear
mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error_msg "${UI_TEXT[ERROR_LOG]}"
    fi
fi

cd "${TOOLKIT_PATH}"

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
echo -n "PSBBN Definitive Project Version: " >> "${LOG_FILE}"
git rev-parse --short HEAD >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "Type: $MODE" >> "${LOG_FILE}"
echo "Disk Serial: $serialnumber" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

trap 'echo; exit 130' INT
trap exit_script EXIT

SPLASH
download_files

if ! sudo rm -rf "${STORAGE_DIR}"; then
    echo "[X] Error: Failed to delete $STORAGE_DIR" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_DELETE]} $STORAGE_DIR"
fi

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
        
        read -rp "${UI_TEXT[CHOOSE_DRIVE_1]} " DEVICE
        
        # Check if the device exists
        if [[ -n "$DEVICE" ]] && lsblk -dp -n -o NAME | grep -q "^$DEVICE$"; then
            break
        else
            echo
            echo -n "${UI_TEXT[CHOOSE_DRIVE_2]}"
            sleep 3
        fi
    done
    drive_model=$(lsblk -ndo MODEL,SIZE,SERIAL "$DEVICE" | xargs)
fi
    
# Check the size of the chosen device
SIZE_CHECK=$(lsblk -o NAME,SIZE -b | grep -w $(basename $DEVICE) | awk '{print $2}')

# Convert size to GB
size_gb=$(echo "$SIZE_CHECK / (1024 * 1024 * 1024)" | bc)
        
if (( size_gb < 31 )); then
    echo "[X] Error: Required minimum is 32 GB. Device is $size_gb GB." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_DRIVE_SIZE]} $size_gb GB."
else
    echo "Device Name: $DEVICE" >> "${LOG_FILE}"
    [[ -z "$drive_model" ]] && drive_model="$DEVICE"

    echo
    echo "Selected drive: $drive_model" >> "${LOG_FILE}"
    echo "${UI_TEXT[CONFIRM_DRIVE_1]} $drive_model"

    while true; do
        echo
        echo "${UI_TEXT[CONFIRM_DRIVE_2]}"
        echo
        read -rp "${UI_TEXT[CONFIRM_DRIVE_3]} (yes/no): " CONFIRM

        case "$CONFIRM" in
            yes)
                # Valid confirmation → break out of loop and continue
                break
                ;;
            no)
                echo
                read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
                echo
                exit 1
                ;;
            *)
                echo
                echo "${UI_TEXT[CONFIRM]} (yes/no)"
                ;;
        esac
    done
fi

UNMOUNT_ALL
clean_up

case "$LANG_FILE" in
    eng)
        lang="eng"
        ;;
    jpn)
        lang="jpn"
        ;;
    fre)
        lang="fre"
        ;;
    ger)
        lang="ger"
        ;;
    ita)
        lang="ita"
        ;;
    por)
        lang="por"
        ;;
    spa)
        lang="spa"
        ;;
    hun)
        lang="hun"
        ;;
    *)
        echo
        echo "Unsupported language. Defaulting to English." >> "${LOG_FILE}"
        lang="eng"
        ;;
esac

echo "Language set to: $lang" >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "Initialising the drive..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[INITIALISE_DRIVE]}"

{
    sudo wipefs -a ${DEVICE} &&
    sudo dd if=/dev/zero of="${DEVICE}" bs=1M count=100 status=progress &&
    sudo dd if=/dev/zero of="${DEVICE}" bs=1M seek=$(( $(sudo blockdev --getsz "${DEVICE}") / 2048 - 100 )) count=100 status=progress
} >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed to Initialising drive" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_INITIALISE_DRIVE]}"
    }

COMMANDS="device ${DEVICE}\n"
COMMANDS+="initialize yes\n"
COMMANDS+="exit"

PFS_COMMANDS

# Retreive avaliable space

output=$(sudo "${HDL_DUMP}" toc ${DEVICE} 2>&1)

# Extract the "used" value, remove "MB" and any commas
used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
capacity=$(echo "$SIZE_CHECK / (1024 * 1024)" | bc)

# Calculate available space for APA (Max 50% of drive, upto max of 2 TB)
available=$(( capacity / 2 ))

if (( available > 2098208 )); then
    available=$(( 2098208 - used - 6400 - 128 ))
else
    available=$(( available - used - 6400 - 128 ))
fi

free_space=$((available / 1024))

echo >> "${LOG_FILE}"

# Prompt user for partition size for POPS, Music and Contents, validate input, and keep asking until valid input is provided
while true; do
    SPLASH
    center_title "${UI_TEXT[PARTITION_DRIVE_1]}"
    echo | tee -a "${LOG_FILE}"
    echo "Disk Size: $capacity MB" >> "${LOG_FILE}"
    echo "Used APA: $used MB" >> "${LOG_FILE}"
    echo "Space available for APA partitions: $available MB" >> "${LOG_FILE}"
    echo "${UI_TEXT[PARTITION_DRIVE_2]} $free_space GB"
    echo
    echo "${UI_TEXT[PARTITION_DRIVE_9]}"
    echo
    read -rp "${UI_TEXT[PARTITION_DRIVE_11]} (y/n): " answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo
        echo "${UI_TEXT[PARTITION_DRIVE_12]}"
        echo "${UI_TEXT[PARTITION_SIZE_1]} $free_space GB"
        echo
        read -rp "${UI_TEXT[PARTITION_SIZE_2]} " reserve_gb

        # Check if input is a valid number
        if [[ ! "$reserve_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo "${UI_TEXT[PARTITION_SIZE_3]}"
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi

        # Check if input is within valid range
        if (( reserve_gb < 1 || reserve_gb > free_space )); then
            echo
            echo "${UI_TEXT[PARTITION_SIZE_4]} $free_space GB."
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi
    elif [[ "$answer" =~ ^[Nn]$ ]]; then
        reserve_gb="0"
    else
        echo
        echo -n "${UI_TEXT[CONFIRM]} (y/n)"
        sleep 3
        echo | tee -a "${LOG_FILE}"
        continue
    fi

    # Convert bytes to MB
    reserved_mb=$(( reserve_gb * 1024 ))
    APA_MiB=$(( reserved_mb + used + 6400 +128 ))
    DIFF_MB=$(( capacity - APA_MiB - 32 ))

    # Convert to GiB for display (1 GiB = 1024 MiB) with 2 decimal places
    OPL_GB=$(awk "BEGIN { printf \"%.2f\", ${DIFF_MB}/1024 }")

    if awk "BEGIN {exit !($OPL_GB >= 1000)}"; then
        # Store difference as TB with one decimal
        difference="$(awk "BEGIN {printf \"%.1f TB\", $OPL_GB/1024}")"
        # Cap at 2 TB
        CAP=$(awk "BEGIN {print ($difference > 2.0) ? 2.0 : $difference}")
        OPL_SIZE="${CAP} TB"
    else
        # Store as GB
        OPL_SIZE="${OPL_GB} GB"
    fi

    echo
    echo "${UI_TEXT[PARTITION_DRIVE_13]}"
    echo "${UI_TEXT[PARTITION_DRIVE_14]} $OPL_SIZE"
    echo "${UI_TEXT[PARTITION_DRIVE_18]} $reserve_gb"
    echo
    read -rp "${UI_TEXT[PROCEED]} (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        break
    fi
done

echo >> "${LOG_FILE}"
echo "##########################################################################" >> "${LOG_FILE}"
echo "Disk size: $capacity MB" >> "${LOG_FILE}"
echo "Reserved user space: $reserved_mb MB" >> "${LOG_FILE}"
echo "Total APA Size: $APA_MiB MB" >> "${LOG_FILE}"
echo "OPL partition size: $DIFF_MB MB" >> "${LOG_FILE}"
echo "##########################################################################" >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "Installing HOSDMenu..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[INSTALL_HOSDMENU]}"
mount_pfs

mkdir -p "${STORAGE_DIR}/__common/Your Saves" 2>> "${LOG_FILE}"
mkdir -p "${STORAGE_DIR}/__system"/{osdmenu,osd100} 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create __system/osdmenu" 2>> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_CREATE]} __system/osdmenu"
}
mkdir -p "${STORAGE_DIR}/__sysconf/osdmenu/" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create __sysconf/osdmenu" 2>> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_CREATE]} __sysconf/osdmenu"
}
cp "${ASSETS_DIR}/osdmenu/hosdmenu.elf" "${STORAGE_DIR}/__system/osdmenu/" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to copy hosdmenu.elf." 2>> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_COPY]} hosdmenu.elf."
}
cp "${ASSETS_DIR}/extras"/{OSDSYS_A.XLF,FNTOSD,ICOIMAGE,JISUCS,SKBIMAGE,SNDIMAGE,TEXIMAGE} "${STORAGE_DIR}/__system/osd100/" 2>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to copy HDD-OSD." 2>> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_COPY]} HDD-OSD."
}


cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" <<'EOL'
boot_auto = $HOSDSYS
boot_auto_arg1 = -dev9=NICHDD
boot_cross =
boot_circle =
boot_square =
boot_triangle =
cdrom_skip_ps2logo = 0
cdrom_disable_gameid = 0
cdrom_use_dkwdrv = 0
ps1drv_enable_fast = 0
ps1drv_enable_smooth = 0
ps1drv_use_ps1vn = 1
app_gameid = 1
prefer_bbn = 0
EOL

if [[ $? -ne 0 ]]; then
    echo "[X] Error: Failed to write OSDMBR.CNF." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_OSDMBR_CNF]}"
fi

cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" <<'EOL'
boot_auto = $HOSDSYS
OSDSYS_video_mode = AUTO
OSDSYS_selected_color = 0x10,0x80,0xE0,0x80
OSDSYS_unselected_color = 0x33,0x33,0x33,0x80
OSDSYS_scroll_menu = 1
OSDSYS_menu_x = 320
OSDSYS_menu_y = 110
OSDSYS_enter_x = 30
OSDSYS_enter_y = -1
OSDSYS_version_x = -1
OSDSYS_version_y = -1
OSDSYS_cursor_max_velocity = 1500
OSDSYS_cursor_acceleration = 150
OSDSYS_left_cursor =
OSDSYS_right_cursor =
OSDSYS_menu_top_delimiter =
OSDSYS_menu_bottom_delimiter =
OSDSYS_num_displayed_items = 5
OSDSYS_Skip_Disc = 0
cdrom_skip_ps2logo = 0
cdrom_disable_gameid = 0
cdrom_use_dkwdrv = 0
ps1drv_enable_fast = 0
ps1drv_enable_smooth = 0
ps1drv_use_ps1vn = 1
app_gameid = 1
EOL

if [[ $? -ne 0 ]]; then
    echo "[X] Error: Failed to write OSDMENU.CNF." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_OSDMENU_CNF]}"
fi

BOOTSTRAP
clean_up
echo | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "Running APA-Jail..." >> "${LOG_FILE}"
echo -n "${UI_TEXT[APA_JAIL]}"

################################### APA-Jail code by Berion ###################################

# Signature injection (type A2):
MAGIC_NUMBER="4150414A2D413200"
apajail_magic_number

# Setting up MBR:
{
    echo -e ",${APA_MiB}MiB,17\n,32MiB,17\n,,07" | sudo sfdisk ${DEVICE}
    sudo partprobe ${DEVICE}
    if [ "$(echo ${DEVICE} | grep -o /dev/loop)" = "/dev/loop" ]; then
	    sudo mke2fs -t ext2 -L "RECOVERY" ${DEVICE}p2
	    sudo "${MKFS_EXFAT}" -c 32K -L "OPL" ${DEVICE}p3
	else
		sleep 4
		sudo mke2fs -t ext2 -L "RECOVERY" ${DEVICE}2
		sudo "${MKFS_EXFAT}" -c 32K -L "OPL" ${DEVICE}3
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

if ! mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,POPS,nhddl}; then
    echo "[X] Error: Failed to create OPL folders." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_OPL_FOLDER]}"
fi

echo | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

printf "OSDMenu = %s\n" "$(cat "${ASSETS_DIR}/osdmenu/version.txt")" >> "${OPL}/version.txt"
echo "APA_SIZE = $APA_MiB" >> "${OPL}/version.txt"
echo "LANG = $lang" >> "${OPL}/version.txt"

UNMOUNT_OPL

echo >> "${LOG_FILE}"
echo "${TOC_OUTPUT}" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT >> "${LOG_FILE}"

echo "[✓] ${UI_TEXT[HOSDMENU_SUCCESS]}" | tee -a "${LOG_FILE}"
echo
read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
echo

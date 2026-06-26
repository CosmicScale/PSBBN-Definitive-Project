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

for arg in "$@"; do
    [[ -z "$arg" ]] && continue

    if [[ "$arg" == /* ]]; then
        path_arg="${arg%/}"
    elif [[ -z "$serialnumber" ]]; then
        serialnumber="$arg"
    fi
done

# Source unattended configuration if present
UNATTENDED_CONF="${TOOLKIT_PATH}/psbbn-unattended.conf"
if [[ -f "$UNATTENDED_CONF" ]]; then
    source "$UNATTENDED_CONF"
fi

serialnumber="${serialnumber:-$DEVICE_DISK_SERIAL}"

APA_PARTITIONS=("__system" "__common" "__sysconf" )

error_msg() {
    error_1="[X] Error: $1"
    error_2="$2"
    error_3="$3"
    error_4="$4"

    echo | tee -a "${LOG_FILE}"
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

clean_up() {
    failure=0

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1

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

    # Clean up directories and temp files
    sudo rm -rf /tmp/{apa_header_checksum.bin,apa_header_full.bin,apajail_magic_number.bin,apa_index.xz,gpt_2nd.xz} >> "${LOG_FILE}" 2>&1
    
    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        error_msg "Cleanup error(s) occurred. Aborting."
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
        error_msg "PFS Shell returned an error. See ${LOG_FILE}"
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
            error_msg "Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
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
	    error_msg "Failed to inject bootstrap."
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

    if echo "${TOC_OUTPUT}" | grep -Eq '\b(__contents|__system|__sysconf|__.POPS|__common)\b'; then
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
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "Failed to extract list of partitions." "APA partition could be broken on ${DEVICE}"
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
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" >> "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Required files are missing in ${ASSETS_DIR}/extras." >> "${LOG_FILE}"
        # Check if extras.zip exists
        if [[ -f "${ASSETS_DIR}/extras.zip" && ! -f "${ASSETS_DIR}/extras.zip.st" ]]; then
            echo | tee -a "${LOG_FILE}"
            echo "extras.zip found in ${ASSETS_DIR}. Extracting..." | tee -a "${LOG_FILE}"
            unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        else
            echo | tee -a "${LOG_FILE}"
            echo -n "Downloading required files..." | tee -a "${LOG_FILE}"
            wget --quiet --timeout=10 --tries=3 -O "${ASSETS_DIR}/extras.zip" https://archive.org/download/psbbn-definitive-english-patch-v2/extras.zip
            echo
            if [[ -s "${ASSETS_DIR}/extras.zip" ]]; then
                unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
            else
                rm "${ASSETS_DIR}/extras.zip"
                error_msg "Download Failed." "Please check the status of archive.org. You may need to use a VPN depending on your location."
            fi
        fi
        # Check if HDD-OSD files exist after extraction
        if hdd_osd_files_present; then
            echo | tee -a "${LOG_FILE}"
            echo "[✓] Files successfully extracted." | tee -a "${LOG_FILE}"
        else
            error_msg "One or more files are missing after extraction."
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

SPLASH
download_files

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
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

# Convert size to GB
size_gb=$(echo "$SIZE_CHECK / (1024 * 1024 * 1024)" | bc)
        
if (( size_gb < 31 )); then
    error_msg "Device is $size_gb GB. Required minimum is 32 GB."
else
    echo "Device Name: $DEVICE" >> "${LOG_FILE}"
    [[ -z "$drive_model" ]] && drive_model="$DEVICE"

    echo
    echo "Selected drive: $drive_model" | tee -a "${LOG_FILE}"

    if [[ "$SKIP_CONFIRM" == "yes" ]]; then
        echo "[!] Skipping drive confirmation (SKIP_CONFIRM=yes)." | tee -a "${LOG_FILE}"
    else
        while true; do
            echo
            echo "Are you sure you want to install to the selected drive?" | tee -a "${LOG_FILE}"
            echo
            read -p "This will erase all data on the drive. (yes/no): " CONFIRM

            case "$CONFIRM" in
                yes)
                    break
                    ;;
                no)
                    echo
                    read -n 1 -s -r -p "Aborted. Press any key to return to the menu..." </dev/tty
                    echo
                    exit 1
                    ;;
                *)
                    echo
                    echo "Please enter 'yes' or 'no'."
                    ;;
            esac
        done
    fi
fi

UNMOUNT_ALL
clean_up

if [[ -z "$LANG" ]]; then
    echo
    echo "Please select a language from the list below:"
    echo
    echo "1) English"
    echo "2) Japanese"
    echo "3) French"
    echo "4) German"
    echo "5) Italian"
    echo "6) Portuguese (Brazil)"
    echo "7) Spanish"
    echo
    read -p "Enter the number for your chosen language: " choice

    case "$choice" in
        1)
            LANG="eng"
            ;;
        2)
            LANG="jpn"
            ;;
        3)
            LANG="fre"
            ;;
        4)
            LANG="ger"
            ;;
        5)
            LANG="ita"
            ;;
        6)
            LANG="por"
            ;;
        7)
            LANG="spa"
            ;;
        *)
            echo
            echo "Invalid selection. Defaulting to English." | tee -a "${LOG_FILE}"
            LANG="eng"
            ;;
    esac
fi

echo "Language set to: $LANG" >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo -n "Initialising the drive..." | tee -a "${LOG_FILE}"

{
    sudo wipefs -a ${DEVICE} &&
    sudo dd if=/dev/zero of="${DEVICE}" bs=1M count=100 status=progress &&
    sudo dd if=/dev/zero of="${DEVICE}" bs=1M seek=$(( $(sudo blockdev --getsz "${DEVICE}") / 2048 - 100 )) count=100 status=progress
} >> "${LOG_FILE}" 2>&1 || error_msg "Failed to Initialising drive"

COMMANDS="device ${DEVICE}\n"
COMMANDS+="initialize yes\n"
COMMANDS+="exit"

PFS_COMMANDS

# Retreive avaliable space

output=$(sudo "${HDL_DUMP}" toc ${DEVICE} 2>&1)

# Extract the "used" value, remove "MB" and any commas
used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
capacity=$(echo "$SIZE_CHECK / (1024 * 1024)" | bc)

# Calculate available space (capacity - used)

if [ $capacity -gt 2098208 ]; then
    available=$((2097152 - used - 6400 - 128 ))
else
    available=$((capacity - used - 6400 - 128 - 32 - 1024 ))
fi

max_pops=$((available / 1024 - 1))

if [ $max_pops -gt 130 ]; then
    max_pops="130"
fi

echo | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"
SPLASH
echo "    ====================================== Partitioning the Drive ======================================"

# Determine POPS partition size (interactive or unattended)
if [[ -n "$POPS_GB" ]]; then
    pops_gb="$POPS_GB"
    if [[ ! "$pops_gb" =~ ^[0-9]+$ ]] || (( pops_gb < 1 || pops_gb > max_pops )); then
        error_msg "Invalid POPS_GB value '$pops_gb' in unattended config. Must be between 1 and $max_pops."
    fi
    pops_partition=$(( pops_gb * 1024 ))
    APA_MiB=$(( pops_partition + used + 6400 +128 ))
    DIFF_MB=$(( capacity - APA_MiB - 32 ))
    OPL_GB=$(awk "BEGIN { printf \"%.2f\", ${DIFF_MB}/1024 }")
    if awk "BEGIN {exit !($OPL_GB >= 1000)}"; then
        difference="$(awk "BEGIN {printf \"%.1f TB\", $OPL_GB/1024}")"
        CAP=$(awk "BEGIN {print ($difference > 2.0) ? 2.0 : $difference}")
        OPL_SIZE="${CAP} TB"
    else
        OPL_SIZE="${OPL_GB} GB"
    fi

    echo | tee -a "${LOG_FILE}"
    echo "The following partitions will be created:" | tee -a "${LOG_FILE}"
    echo "- POPS partition: $pops_gb GB" | tee -a "${LOG_FILE}"
    echo "- OPL partition: $OPL_SIZE" | tee -a "${LOG_FILE}"

    if [[ "$SKIP_CONFIRM" == "yes" ]]; then
        echo "[!] Skipping partition confirmation (SKIP_CONFIRM=yes)." | tee -a "${LOG_FILE}"
    else
        echo
        read -p "Do you wish to proceed? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo
            read -n 1 -s -r -p "Aborted. Press any key to return to the menu..." </dev/tty
            echo
            exit 1
        fi
    fi
else
    while true; do
        echo | tee -a "${LOG_FILE}"
        echo "What size would you like the \"POPS\" partition to be?"
        echo "This partition is used to store PS1 games. A typically game requires between 200 and 700 MB."
        echo
        echo "Minimum 1 GB, maximum $max_pops GB"
        echo
        read -p "Enter partition size (in GB): " pops_gb

        if [[ ! "$pops_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo -n "Invalid input. Please enter a valid number."
            sleep 3
            echo
            continue
        fi

        if (( pops_gb < 1 || pops_gb > max_pops )); then
            echo
            echo -n "Invalid size. Please enter a value between 1 and $max_pops GB."
            sleep 3
            echo
            continue
        fi

        pops_partition=$(( pops_gb * 1024 ))
        APA_MiB=$(( pops_partition + used + 6400 +128 ))
        DIFF_MB=$(( capacity - APA_MiB - 32 ))

        OPL_GB=$(awk "BEGIN { printf \"%.2f\", ${DIFF_MB}/1024 }")

        if awk "BEGIN {exit !($OPL_GB >= 1000)}"; then
            difference="$(awk "BEGIN {printf \"%.1f TB\", $OPL_GB/1024}")"
            CAP=$(awk "BEGIN {print ($difference > 2.0) ? 2.0 : $difference}")
            OPL_SIZE="${CAP} TB"
        else
            OPL_SIZE="${OPL_GB} GB"
        fi

        echo
        echo "The following partitions will be created:"
        echo "- POPS partition: $pops_gb GB"
        echo "- OPL partition: $OPL_SIZE"
        echo
        read -p "Do you wish to proceed? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        fi
    done
fi

echo >> "${LOG_FILE}"
echo "##########################################################################" >> "${LOG_FILE}"
echo "Disk size: $capacity MB" >> "${LOG_FILE}"
echo "POPS partition size: $pops_partition MB" >> "${LOG_FILE}"
echo "Total APA Size: $APA_MiB MB" >> "${LOG_FILE}"
echo "OPL partition size: $DIFF_MB MB" >> "${LOG_FILE}"
echo "##########################################################################" >> "${LOG_FILE}"

COMMANDS="device ${DEVICE}\n"
COMMANDS+="mkpart __.POPS ${pops_partition}M PFS\n"
COMMANDS+="exit"
echo "Creating partitions..." >>"${LOG_FILE}"
PFS_COMMANDS

echo | tee -a "${LOG_FILE}"
echo -n "Installing HOSDMenu..." | tee -a "${LOG_FILE}"
mount_pfs

mkdir -p "${STORAGE_DIR}/__common"/{POPS,"Your Saves"} 2>> "${LOG_FILE}"
mkdir -p "${STORAGE_DIR}/__system"/{osdmenu,osd100} 2>> "${LOG_FILE}" || error_msg "Failed to create OSDMenu folders."
mkdir -p "${STORAGE_DIR}/__sysconf/osdmenu/" 2>> "${LOG_FILE}" || error_msg "Failed to create OSDMenu config folder."
cp "${ASSETS_DIR}/osdmenu/hosdmenu.elf" "${STORAGE_DIR}/__system/osdmenu/" 2>> "${LOG_FILE}" || error_msg "Failed to copy hosdmenu.elf."
cp "${ASSETS_DIR}/extras"/{OSDSYS_A.XLF,FNTOSD,ICOIMAGE,JISUCS,SKBIMAGE,SNDIMAGE,TEXIMAGE} "${STORAGE_DIR}/__system/osd100/" 2>> "${LOG_FILE}" || error_msg "Failed to copy hosdmenu.elf."


cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" <<'EOL' || error_msg "Error" "Failed to write OSDMBR.CNF."
boot_auto = $HOSDSYS
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

cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" <<'EOL' || error_msg "Error" "Failed to write OSDMBR.CNF."
boot_auto = $HOSDSYS
OSDSYS_video_mode = AUTO
OSDSYS_Inner_Browser = 0
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
OSDSYS_Skip_Logo = 0
cdrom_skip_ps2logo = 0
cdrom_disable_gameid = 0
cdrom_use_dkwdrv = 0
ps1drv_enable_fast = 0
ps1drv_enable_smooth = 0
ps1drv_use_ps1vn = 1
app_gameid = 1
EOL

BOOTSTRAP
clean_up
echo | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo -n "Running APA-Jail..." | tee -a "${LOG_FILE}"
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

if ! mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD}; then
    error_msg "Failed to create OPL folders."
fi

echo | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"

printf "OSDMenu = %s\n" "$(cat "${ASSETS_DIR}/osdmenu/version.txt")" >> "${OPL}/version.txt"
echo "APA_SIZE = $APA_MiB" >> "${OPL}/version.txt"
echo "LANG = $LANG" >> "${OPL}/version.txt"

UNMOUNT_OPL

echo >> "${LOG_FILE}"
echo "${TOC_OUTPUT}" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT >> "${LOG_FILE}"

echo "[✓] HOSDMenu successfully installed." | tee -a "${LOG_FILE}"
echo
read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
echo

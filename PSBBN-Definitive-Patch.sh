#!/usr/bin/env bash
#
# PSBBN Definitive Project
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
    echo "Error: This script must be run using Bash. Try running it with: bash $0"
    exit 1
fi

export LC_MESSAGES=C
export LAUNCHED_BY_MAIN=1

# Set paths
export PATH="$PATH:/sbin:/usr/sbin"
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
HELPER_DIR="${SCRIPTS_DIR}/helper"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"
arch="$(uname -m)"

URL="https://archive.org/download/psbbn-definitive-patch-v4.1"

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

# Initialize variable
wsl=false

# Check if first argument is -wsl and at least 2 more arguments follow
if [[ "$1" == "-wsl" ]]; then
    wsl=true
    shift  # remove -wsl from args

    for arg in "$@"; do
        [[ -z "$arg" ]] && continue

        if [[ "$arg" == /* ]]; then
            path_arg="${arg%/}"
        elif [[ -z "$serialnumber" ]]; then
            serialnumber="$arg"
        fi
    done
fi

error_msg() {
  error_1="$1"
  error_2="$2"
  error_3="$3"
  error_4="$4"

  echo
  echo "[X] Error: $error_1" | tee -a "${LOG_FILE}"
  [ -n "$error_2" ] && echo && echo "$error_2" | tee -a "${LOG_FILE}"
  [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
  [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
  echo
  read -n 1 -s -r -p "Press any key to exit..." </dev/tty
  echo
  exit 1
}

copy_log() {
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "$path_arg" > /dev/null 2>&1
    fi
}

git_update() {
    # Check if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        error_msg "This script cannot continue due to an unsupported installation." "The PSBBN Definitive Project is a rolling release." "To ensure you are always running the latest version, follow the installation instructions here:" "https://github.com/CosmicScale/PSBBN-Definitive-Project?tab=readme-ov-file#user-guide"
    else
        # Fetch updates from the remote
        git fetch >> "${LOG_FILE}" 2>&1

        # Check the current status of the repository
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})
        BASE=$(git merge-base @ @{u})

        if [ "$LOCAL" = "$REMOTE" ]; then
            echo "No updates available — running the latest version." >> "${LOG_FILE}"
        else
            echo "Downloading updates..." | tee -a "${LOG_FILE}"
            # Get a list of files that have changed remotely
            UPDATED_FILES=$(git diff --name-only "$LOCAL" "$REMOTE")

            if [ -n "$UPDATED_FILES" ]; then
                echo "Files updated in the remote repository:" | tee -a "${LOG_FILE}"
                echo "$UPDATED_FILES" | tee -a "${LOG_FILE}"

                # Reset only the files that were updated remotely (discard local changes to them)
                echo "$UPDATED_FILES" | xargs git checkout -- >> "${LOG_FILE}" 2>&1

                # Pull the latest changes
                if ! git pull --ff-only >> "${LOG_FILE}" 2>&1; then
                    error_msg "Update failed. Delete the PSBBN-Definitive-Project directory and run the command:" "git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git" "Then try running the script again."
                fi
                echo
                echo "[✓] The repository has been successfully updated." | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "Press any key to exit, then run the script again." </dev/tty
                echo
                exit 0
            fi
        fi
    fi
}

check_required_files() {
    local missing=false

    # List of required files
    local required_files=(
        "${SCRIPTS_DIR}/Setup.sh"
        "${SCRIPTS_DIR}/PSBBN-Installer.sh"
        "${SCRIPTS_DIR}/HOSDMenu-Installer.sh"
        "${SCRIPTS_DIR}/Game-Installer.sh"
        "${SCRIPTS_DIR}/Extras.sh"
        "${SCRIPTS_DIR}/Media-Installer.sh"
        "${HELPER_DIR}/art_downloader.py"
        "${HELPER_DIR}/binmerge.py"
        "${HELPER_DIR}/icon_sys_to_txt.py"
        "${HELPER_DIR}/list-builder.py"
        "${HELPER_DIR}/list-sorter.py"
        "${HELPER_DIR}/music-installer.py"
        "${HELPER_DIR}/ps2iconmaker.sh"
        "${HELPER_DIR}/txt_to_icon_sys.py"
        "${HELPER_DIR}/ziso.py"
        "${HELPER_DIR}/AppDB.csv"
        "${HELPER_DIR}/ArtDB.csv"
        "${HELPER_DIR}/TitlesDB_PS1.csv"
        "${HELPER_DIR}/TitlesDB_PS2.csv"
        "${HELPER_DIR}/vmc_groups.list"
        "${HELPER_DIR}/ps2_vmc_groups.list"
        "${HELPER_DIR}/genvmc.c"
        "${HELPER_DIR}/genvmc.h"
        "${HELPER_DIR}/psmbuild.py"
        "${HELPER_DIR}/POP-game-fixes.list"
        "${CUE2POPS}"
        "${HDL_DUMP}"
        "${MKFS_EXFAT}"
        "${PFS_FUSE}"
        "${PFS_SHELL}"
        "${APA_FIXER}"
        "${PSU_EXTRACT}"
        "${SQLITE}"
        "${ASSETS_DIR}/NHDDL/nhddl.elf"
        "${ASSETS_DIR}/osdmenu/hosdmenu.elf"
        "${ASSETS_DIR}/osdmenu/OSDMBR.XLF"
        "${ASSETS_DIR}/neutrino/neutrino.elf"
        "${ASSETS_DIR}/OPL/OPNPS2LD.ELF"
        "${ASSETS_DIR}/Icon-templates/PS1-Template.png"
        "${ASSETS_DIR}/POPStarter/POPSTARTER.ELF"
        "${ASSETS_DIR}/POPStarter/icon.sys"
        "${ASSETS_DIR}/POPStarter/CHEATS.TXT"
        "${ASSETS_DIR}/music/bitrate"
        "${ASSETS_DIR}/music/music.db"
        "${ASSETS_DIR}/kernel/vmlinux"
        "${ASSETS_DIR}/kernel/vmlinux_jpn"
        "${ASSETS_DIR}/kernel/ps2-linux-ntsc"
        "${ASSETS_DIR}/kernel/ps2-linux-vga"
        "${ASSETS_DIR}/kernel/o.tm2"
        "${ASSETS_DIR}/kernel/x.tm2"
        "${ASSETS_DIR}/autorun.ico"
        "${TOOLKIT_PATH}/.envrc"
        "${SCRIPTS_DIR}/nix/flake.lock"
        "${SCRIPTS_DIR}/nix/flake.nix"
    )

    # List of required non-empty directories
    local required_dirs=(
        "${TOOLKIT_PATH}/icons/art"
        "${TOOLKIT_PATH}/icons/ico"
        "${TOOLKIT_PATH}/games"
        "${TOOLKIT_PATH}/media"
    )

    # Check each file
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Missing file: $file"
            missing=true
        fi
    done

    # Check each directory
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" || -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            echo "Missing or empty directory: $dir"
            missing=true
        fi
    done

    # If any were missing, exit with error
    if [[ "$missing" == true ]]; then
        error_msg "Essential files not found." "The script must be run from the 'PSBBN-Definitive-Project' directory."
    fi
}

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo "[X] Missing command: $1" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] $1 found" >> "$LOG_FILE"
    fi
}

check_python_pkg() {
    if ! scripts/venv/bin/python -c "import $1" &> /dev/null; then
        echo "[X] Missing Python package: $1" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] Python package '$1' found" >> "$LOG_FILE"
    fi
}

check_dep(){
    MISSING=0
    echo >> "$LOG_FILE"
    echo "Checking Dependences:" >> "$LOG_FILE"
    echo "--- System commands ---" >> "$LOG_FILE"
    check_cmd axel
    check_cmd convert       # from ImageMagick
    check_cmd xxd
    check_cmd python3
    check_cmd bc
    check_cmd rsync
    check_cmd curl
    check_cmd zip
    check_cmd unzip
    check_cmd wget
    check_cmd ffmpeg
    check_cmd lvm
    check_cmd timeout
    check_cmd mkfs.vfat
    check_cmd mke2fs
    check_cmd ldconfig
    check_cmd sfdisk
    check_cmd partprobe
    check_cmd bchunk
    check_cmd pkg-config
    check_cmd ffmpegthumbnailer
    check_cmd unrar-free

    if ! pkg-config --exists icu-i18n 2>/dev/null; then
        echo "[X] libicu-dev not found." >> "$LOG_FILE"
        MISSING=1
    fi

    if [ "$wsl" = "true" ]; then
        [[ -d /proc/sys/fs/binfmt_misc ]] && echo "[✓] binfmt support exists"  >> "$LOG_FILE" || MISSING=1
    fi

    if [[ "$arch" = "x86_64" ]] && [[ -z "$IN_NIX_SHELL" ]]; then
        if [ -x /lib/ld-linux.so.2 ]; then
            echo "[✓] 32-bit glibc runtime exists (ld-linux.so.2)" >> "$LOG_FILE"
        else
            echo "[X] 32-bit glibc runtime missing (ld-linux.so.2)" >> "$LOG_FILE"
            MISSING=1
        fi
    fi

    echo >> "$LOG_FILE"
    echo "--- exFAT support ---" >> "$LOG_FILE"

    if grep -qw exfat /proc/filesystems; then
        echo "[✓] Native kernel exFAT support detected." >> "$LOG_FILE"
    else
        sudo modprobe exfat 2>/dev/null
        if grep -qw exfat /proc/filesystems; then
            echo "[✓] Native kernel exFAT support detected (after modprobe)." >> "$LOG_FILE"
        elif command -v mount.exfat-fuse &>/dev/null; then
            echo "[✓] FUSE-based exFAT support detected (mount.exfat-fuse)." >> "$LOG_FILE"
        else
            echo "[X] No exFAT support found. Running setup..." >> "$LOG_FILE"
            MISSING=1
        fi
    fi

    echo >> "$LOG_FILE"
    echo "--- Python virtual environment ---" >> "$LOG_FILE"
    if [ ! -d "scripts/venv" ]; then
        echo "[X] Python venv not found in scripts/venv" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] Python venv found" >> "$LOG_FILE"
        check_python_pkg lz4
        check_python_pkg natsort
        check_python_pkg mutagen
        check_python_pkg tqdm
        check_python_pkg icu
        check_python_pkg pykakasi
        check_python_pkg PIL
        check_python_pkg textual
    fi

    if { ldconfig -p 2>/dev/null | grep -q "libfuse.so.2"; } || pkg-config --exists fuse 2>/dev/null; then
        echo "[✓] FUSE2 (libfuse.so.2) is installed." >> "$LOG_FILE"
    else
        echo "[X] FUSE2 (libfuse.so.2) is missing." >> "$LOG_FILE"
        MISSING=1
    fi

    if [ "$MISSING" -ne 0 ]; then
        return 1
    fi
}

get_latest_file() {
    local prefix="$1"        # e.g., "psbbn-eng" or "psbbn-definitive-patch"
    local display="$2"       # e.g., "English language pack"
    local remote_list remote_versions remote_version

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
        echo "Found $display version $remote_version" >> "${LOG_FILE}"

        LATEST_FILE="${prefix}-v${remote_version}.tar.gz"

        if [[ "$prefix" == "psbbn-definitive-patch" ]]; then
            LATEST_VERSION="$remote_version"
        elif [[ "$prefix" == "language-pak-$LANG" ]]; then
            LATEST_LANG="$remote_version"
        elif [[ "$prefix" == "channels-$LANG" ]]; then
            LATEST_CHAN="$remote_version"
        fi
    else
        echo "Could not find the latest version of the $display." >> "${LOG_FILE}"
    fi
}

UNMOUNT_ALL() {
    while IFS= read -r mount_point; do
        [[ -z "$mount_point" ]] && continue

        echo "Unmounting $mount_point..." >> "${LOG_FILE}"

        sudo umount -- "$mount_point" \
            && echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}" \
            || error_msg "Failed to unmount $mount_point. Please unmount manually."
    done < <(lsblk -ln -o MOUNTPOINT "$DEVICE")

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || error_msg "Error" "Failed to unmount $line"
                ;;
        esac
    done

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        sudo dmsetup remove -f "$map_name" 2>/dev/null
    done
}

MOUNT_OPL() {
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || error_msg "Failed to create ${OPL}."

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi
}

UNMOUNT_OPL() {
    sync
    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1
}

flash_update() {
    local on=$1

    # Only flash if UPDATE is "YES"
    [[ "$UPDATE" != "YES" ]] && return

    # Save current cursor (so user can type)
    tput sc
    # Move cursor up 10 lines from prompt to option 3
    tput cuu 10
    tput cuf 12

    if (( on )); then
        printf "**UPDATE AVAILABLE!**"
    else
        printf "                     "
    fi

    # Restore cursor so input stays at prompt
    tput rc
}

option_one() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -install "$serialnumber" "$path_arg"
}

option_two() {
    "${SCRIPTS_DIR}/HOSDMenu-Installer.sh" "$serialnumber" "$path_arg"
}

option_three() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -update "$path_arg"
}

option_four() {
    "${SCRIPTS_DIR}/Game-Installer.sh" "$path_arg"
}

option_five() {
    "${SCRIPTS_DIR}/Media-Installer.sh" "$wsl" "$path_arg"
}

option_six() {
    "${SCRIPTS_DIR}/Extras.sh" "$path_arg"
}

SPLASH() {
    clear
    cat << "EOF"
 ______  _________________ _   _  ______      __ _       _ _   _            ______          _           _   
 | ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \        (_)         | |  
 | |_/ /\ `--.| |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ / __ ___  _  ___  ___| |_ 
 |  __/  `--. \ ___ \ ___ \ . ` | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ '__/ _ \| |/ _ \/ __| __|
 | |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | |  | | | (_) | |  __/ (__| |_ 
 \_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  |_|  \___/| |\___|\___|\__|
                                                                                          _/ |              
                                                                                         |__/               

                                            Created by CosmicScale



EOF
}

# Function to display the menu
display_menu() {
    SPLASH
    cat << "EOF"
                   1) Install PSBBN & HOSDMenu (Official Sony Network Adapter required)

                   2) Install HOSDMenu only (3rd-party HDD adapters supported)

                   3) Update PS2 System Software

                   4) Install Games and Apps

                   5) Install Media

                   6) Optional Extras

                   q) Quit

EOF
    # Print prompt without newline so cursor is ready
    printf "                   Select an option: "
}

check_required_files

if [ "$wsl" = "false" ]; then
        git_update
fi

trap 'echo; exit 130' INT
trap copy_log EXIT

echo -e "\e[8;45;110t"

SPLASH

cd "${TOOLKIT_PATH}"

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
    sudo rm -f "${LOG_FILE}"
    if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
        echo
        error_msg "Cannot create log file."
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "WSL: $wsl" >> "${LOG_FILE}"
echo "Disk Serial: $serialnumber" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
    error_msg "Unsupported CPU architecture: $(uname -m). This script requires x86-64 or ARM64."
    exit 1
fi

# Detect WSL
if grep -qi microsoft /proc/version; then
    # Detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case " $ID $ID_LIKE " in
            *" fedora "*|*" arch "*)
                echo "Unsupported distro under WSL: $NAME. Please use Debian instead."
                exit 1
                ;;
        esac
    fi
fi

rm "${TOOLKIT_PATH}/"*.log >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/"{storage,node_modules,venv,gamepath.cfg} >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/scripts/"{node_modules,package.json,package-lock.json} >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/scripts/assets/"psbbn-definitive-image* >/dev/null 2>&1
rmdir "${TOOLKIT_PATH}/OPL" >/dev/null 2>&1

if ! check_dep; then
    if ! "${TOOLKIT_PATH}/scripts/Setup.sh"; then
        exit 1
    else
        check_dep || error_msg "Dependencies still missing after setup." 
    fi
fi

DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

if [[ -z "$DEVICE" ]]; then
    UPDATE="NO"
else
    UNMOUNT_ALL
    MOUNT_OPL
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    osdmenu_version=$(awk -F' *= *' '$1=="OSDMenu"{print $2}' "${OPL}/version.txt")

    if [[ -z "$osdmenu_version" && "$(printf '%s\n' "4.0.0" "$psbbn_version" | sort -V | head -n1)" == "4.0.0" ]]; then
        osdmenu_version="1.0.0"
    fi

    LANG=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")

    if [[ "$LANG" != "jpn" && "$LANG" != "ger" && "$LANG" != "ita" && "$LANG" != "por" && "$LANG" != "spa" && "$LANG" != "fre" ]]; then
        LANG="eng"
    fi

    LANG_VER=$(awk -F' *= *' '$1=="LANG_VER"{print $2}' "${OPL}/version.txt")
    CHAN_VER=$(awk -F' *= *' '$1=="CHAN_VER"{print $2}' "${OPL}/version.txt")

    echo "psbbn_version = $psbbn_version" >> "${LOG_FILE}"
    echo "osdmenu_version = $osdmenu_version" >> "${LOG_FILE}"
    echo "LANG = $LANG" >> "${LOG_FILE}"
    echo "LANG_VER = $LANG_VER" >> "${LOG_FILE}"
    echo "CHAN_VER = $CHAN_VER" >> "${LOG_FILE}"


    UNMOUNT_OPL

    if [[ -n "$psbbn_version" || -n $osdmenu_version || -n "$LANG_VER" || -n "$CHAN_VER" ]]; then

        HTML_FILE=$(mktemp)
        timeout 20 wget -O "$HTML_FILE" "$URL" -o - >> "$LOG_FILE" 2>&1

        if [[ -n "$psbbn_version" ]]; then
            get_latest_file "psbbn-definitive-patch" "PSBBN Definitive Patch"

            if [ "$(printf '%s\n' "$LATEST_VERSION" "$psbbn_version" | sort -V | tail -n1)" != "$psbbn_version" ]; then
                PSBBN_UPDATE="YES"
            fi
        fi

        if [[ -n "$LANG_VER" ]]; then
            get_latest_file "language-pak-$LANG" "$LANG_DISPLAY language pack"

            if [ "$(printf '%s\n' "$LATEST_LANG" "$LANG_VER" | sort -V | tail -n1)" != "$LANG_VER" ]; then
                LANG_UPDATE="YES"
            fi
        fi

        if [[ -n "$CHAN_VER" ]]; then
            get_latest_file "channels-$LANG" "$LANG_DISPLAY channels"

            if [ "$(printf '%s\n' "$LATEST_CHAN" "$CHAN_VER" | sort -V | tail -n1)" != "$CHAN_VER" ]; then
                CHAN_UPDATE="YES"
            fi
        fi

        if [[ -n "$osdmenu_version" ]]; then
            LATEST_OSD=$(<"${ASSETS_DIR}/osdmenu/version.txt")
            
            if [ "$(printf '%s\n' "$LATEST_OSD" "$osdmenu_version" | sort -V | tail -n1)" != "$osdmenu_version" ]; then
                OSD_UPDATE="YES"
            fi
        fi

        if [ "$PSBBN_UPDATE" == "YES" ] || [ "$OSD_UPDATE" == "YES" ] || [ "$LANG_UPDATE" == "YES" ] || [ "$CHAN_UPDATE" == "YES" ]; then
            UPDATE="YES"
        else
            UPDATE="NO"
        fi
    fi
fi

echo "UPDATE: $UPDATE" >> "$LOG_FILE"

clear
display_menu

# Main loop
while true; do
    flash_update $flash
    flash=$((2 - flash))

    # Non-blocking read with 1s timeout
    if read -r -t 1 choice; then
        echo
        case $choice in
            1) option_one; UPDATE="NO"; display_menu ;;  # redraw menu once after script finishes
            2) option_two; UPDATE="NO"; display_menu ;;
            3) option_three; UPDATE="NO"; display_menu ;;
            4) option_four; display_menu ;;
            5) option_five; display_menu ;;
            6) option_six; display_menu ;;
            q|Q) clear; break ;;
            *) echo -n "                   Invalid option, please try again."
               sleep 2
               display_menu ;;
        esac
    fi
done

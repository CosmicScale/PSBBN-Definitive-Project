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

export LC_ALL=en_US.UTF-8

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0"
    exit 1
fi

# Set paths
export PATH="$PATH:/sbin:/usr/sbin"
TOOLKIT_PATH="$(pwd)"
HELPER_DIR="${TOOLKIT_PATH}/scripts/helper"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"

# Initialize variable
wsl=false

# Check if first argument is -wsl and at least 2 more arguments follow
if [[ "$1" == "-wsl" && -n "$2" && -n "$3" ]]; then
    wsl=true
    serialnumber="$2"
    path_arg="$3"
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

check_required_files() {
    local missing=false

    # List of required files
    local required_files=(
        "./scripts/Extras.sh"
        "./scripts/Game-Installer.sh"
        "./scripts/PSBBN-Installer.sh"
        "./scripts/Setup.sh"
        "./scripts/helper/AppDB.csv"
        "./scripts/helper/ArtDB.csv"
        "./scripts/helper/art_downloader.py"
        "./scripts/helper/HDL Dump.elf"
        "./scripts/helper/icon_sys_to_txt.py"
        "./scripts/helper/list-builder.py"
        "./scripts/helper/list-sorter.py"
        "./scripts/helper/mkfs.exfat"
        "./scripts/helper/PFS Fuse.elf"
        "./scripts/helper/PFS Shell.elf"
        "./scripts/helper/PS2 APA Header Checksum Fixer.elf"
        "./scripts/helper/ps2iconmaker.sh"
        "./scripts/helper/PSU Extractor.elf"
        "./scripts/helper/TitlesDB_PS1_English.csv"
        "./scripts/helper/TitlesDB_PS2_English.csv"
        "./scripts/helper/txt_to_icon_sys.py"
        "./scripts/helper/vmc_groups.list"
        "./scripts/helper/ziso.py"
    )

    # List of required non-empty directories
    local required_dirs=(
        "./scripts/assets"
        "./icons/art"
        "./icons/ico"
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
        error_msg "Essential files not found." "The script must be run from the 'PSBBN-Definitive-English-Patch' directory."
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

option_one() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -install $serialnumber "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -install
    fi
}

option_two() {
    "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -update
}

option_three() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Game-Installer.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Game-Installer.sh"
    fi
}

option_four() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Media-Installer.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Media-Installer.sh"
    fi
}

option_five() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Extras.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Extras.sh"
    fi
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

EOF
}

# Function to display the menu
display_menu() {
    SPLASH
    cat << "EOF"
                                     1) Install PSBBN
                                     2) Update PSBBN Software
                                     3) Install Games and Apps
                                     4) Install Media
                                     5) Optional Extras
                                     
                                     q) Quit

EOF
}

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

if [[ "$(uname -m)" != "x86_64" ]]; then
    error_msg "Unsupported CPU architecture: $(uname -m). This script requires x86-64."
    exit 1
fi

# Detect WSL
if grep -qi microsoft /proc/version; then
    # Detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            fedora|arch)
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

check_required_files

if ! check_dep; then
    if ! "${TOOLKIT_PATH}/scripts/Setup.sh"; then
        exit 1
    else
        check_dep || error_msg "Dependencies still missing after setup." 
    fi
fi

# Main loop

while true; do
    display_menu
    read -p "                                     Select an option: " choice

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
        6)
            option_six
            ;;
        q|Q)
            echo
            break
            ;;
        *)
            echo
            echo -n "                                     Invalid option, please try again."
            sleep 2
            ;;
    esac
done
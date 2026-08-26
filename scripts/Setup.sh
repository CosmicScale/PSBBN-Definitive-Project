#!/usr/bin/env bash
#
# Setup script form the PSBBN Definitive Project
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
    #exit 1
fi

trap 'echo; exit 130' INT

TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
SOURCES_LIST="/etc/apt/sources.list"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"
arch="$(uname -m)"

LANG_FILE="$1"

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

error_msg() {
    echo
    echo
    echo "[X] $1"
    echo
    echo "${UI_TEXT[ERROR_TROUBLE]}"
    echo "${UI_TEXT[TROUBLE_URL]}"
    echo
    read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}"
    echo
    exit 1
}

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'

    # Print initial spinner + message
    printf "\r[%c] %s" "${spinstr:0:1}" "$message"

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r[%c] %s" "${spinstr:i:1}" "$message"
            sleep $delay
        done
    done

    # Replace spinner with check mark when done
    printf "\r[✓] %s\n" "$message"
}

clear

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

# Clean sources.list if needed
if [[ -f "$SOURCES_LIST" ]]; then
    if grep -q 'deb cdrom' "$SOURCES_LIST"; then
        echo "Removing 'deb cdrom' line from $SOURCES_LIST..." >>"${LOG_FILE}"
        sudo sed -i '/deb cdrom/d' "$SOURCES_LIST" >> "${LOG_FILE}" 2>&1 || {
            echo "Failed to clean $SOURCES_LIST" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_SOURCES_LIST]} $SOURCES_LIST"
        }
        echo "'deb cdrom' line removed." >> "${LOG_FILE}"
    fi
fi

cat << "EOF"
                                        _____      _               
                                       /  ___|    | |              
                                       \ `--.  ___| |_ _   _ _ __  
                                        `--. \/ _ \ __| | | | '_ \ 
                                       /\__/ /  __/ |_| |_| | |_) |
                                       \____/ \___|\__|\__,_| .__/ 
                                                            | |    
                                                            |_|    


EOF

echo "${UI_TEXT[INSTALL_DEP]}"

# Detect package manager and install packages
if [ -x "$(command -v apt-get)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        sudo dpkg --add-architecture i386
        i386="libc6:i386"
    fi
    sudo apt-get -q update && sudo apt-get install -y axel imagemagick xxd python3 python3-venv python3-pip bc rsync curl wget ffmpeg lvm2 libfuse2 dosfstools e2fsprogs libc-bin exfatprogs exfat-fuse util-linux fdisk parted bchunk build-essential libicu-dev pkg-config ffmpegthumbnailer binfmt-support libarchive-tools dmsetup $i386 2>&1 | tee -a "${LOG_FILE}"
# Or if user is on Fedora-based system, do this instead
elif [ -x "$(command -v dnf)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        i386="glibc.i686"
    fi
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>&1 | tee -a "${LOG_FILE}"
    sudo dnf install -y gcc-c++ axel ImageMagick xxd python3 python3-devel python3-pip bc rsync curl wget ffmpeg lvm2 fuse-libs dosfstools e2fsprogs glibc-common exfatprogs fuse-exfat util-linux parted bchunk libicu-devel pkgconf ffmpegthumbnailer bsdtar device-mapper $i386 2>&1 | tee -a "${LOG_FILE}"
# Or if user is on Arch-based system, do this instead
elif [ -x "$(command -v pacman)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        i386="lib32-glibc"
    fi
    sudo pacman -S --needed --noconfirm axel imagemagick xxd python pyenv python-pip bc rsync curl wget ffmpeg lvm2 fuse2 dosfstools e2fsprogs glibc exfatprogs util-linux parted bchunk base-devel icu pkgconf ffmpegthumbnailer libarchive device-mapper $i386 2>&1 | tee -a "${LOG_FILE}"
# Or if user is on Gentoo-based system, do this instead
elif [ -x "$(command -v emerge)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        i386="glibc"
    fi
    # Check if device-mapper is in the user's kernel
    # First, see if it's built in
    if grep -q "device-mapper" /proc/devices 2>/dev/null && ! lsmod 2>/dev/null | grep -q "^dm_mod"; then :
    # If it's not built in, see if it's configured as a module
    elif modprobe -n dm_mod &>/dev/null || lsmod 2>/dev/null | grep -q "^dm_mod"; then
        # If it's a module, check if it's loaded
        if grep -q "device-mapper" /proc/devices 2>/dev/null || lsmod 2>/dev/null | grep -q "^dm_mod"; then :
        else
        # If it's not loaded, attempt to load it
        if sudo modprobe dm_mod 2>/dev/null; then :
        else
        echo "Error: Failed to load the 'dm_mod' kernel module." >&2
        exit 1
        fi
    fi
    else
    # If it's not present at all, halt and throw this error message
    echo "Error: device-mapper (CONFIG_BLK_DEV_DM) is missing from your kernel." >&2
    echo "Please rebuild your kernel with CONFIG_BLK_DEV_DM=y or CONFIG_BLK_DEV_DM=m before running this installer." >&2
        exit 1
    fi
    sudo mkdir -p /etc/portage/package.use
    cat << 'EOF' | sudo tee /etc/portage/package.use/psbbn-installer > /dev/null
    # Specific USE requirements for PSBBN installer dependencies
sys-fs/lvm2 lvm
media-video/ffmpeg opus
EOF
# Swap deprecated exfat-utils with exfatprogs if present
    if portageq has_version / sys-fs/exfat-utils &>/dev/null; then
        echo "Removing deprecated sys-fs/exfat-utils to prevent package blocks..."
        sudo emerge --deselect sys-fs/exfat-utils &>/dev/null
        sudo emerge --unmerge --quiet sys-fs/exfat-utils
    fi
    sudo emerge --sync && sudo USE='lvm' emerge -q --ask=n --quiet-fail --autounmask=y --autounmask-continue=y --autounmask-write=y -- net-misc/axel media-gfx/imagemagick dev-util/xxd dev-lang/python dev-python/pip sys-devel/bc net-misc/rsync net-misc/curl net-misc/wget media-video/ffmpeg sys-fs/lvm2 sys-fs/fuse sys-fs/dosfstools sys-fs/e2fsprogs sys-fs/exfatprogs sys-apps/util-linux sys-block/parted app-cdr/bchunk dev-libs/icu dev-util/pkgconf media-video/ffmpegthumbnailer app-arch/libarchive $i386 2>&1 | tee -a "${LOG_FILE}"
elif [ -n "$IN_NIX_SHELL" ]; then
    echo Running in Nix environment - packages should be provided by flake and setup should not be run. >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_NIX]}"
else
    echo "No supported package manager found (apt-get, dnf, pacman)." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_PACMAN]}"
fi

if [ $? -ne 0 ]; then
    echo >> "Package installation failed. Please update your OS and try again." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_PAC_INSTALL]}"
else
    echo "[✓] Packages checked/installed." >> "${LOG_FILE}"
    echo "[✓] ${UI_TEXT[PAC_SUCCESS]}"
fi

# Python virtual environment setup
(
    python3 -m venv scripts/venv >> "${LOG_FILE}" 2>&1 || {
        echo "Failed to create Python virtual environment." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PYTHON_ENV_1]}"
    }
    source scripts/venv/bin/activate || {
        echo "Failed to activate the Python virtual environment." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PYTHON_ENV_2]}"
    }
    pip install lz4 natsort mutagen tqdm PyICU pykakasi pillow Unidecode textual wcwidth >> "${LOG_FILE}" || {
        echo "Failed to install Python dependencies." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PYTHON_ENV_3]}"
    }
    deactivate
) &
PID=$!
spinner $PID "${UI_TEXT[SETUP_PYTHON]}"

echo
echo "[✓] Setup completed successfully!" >> "${LOG_FILE}"
echo -n "[✓] ${UI_TEXT[SETUP_SUCCESS]}"
sleep 3
echo

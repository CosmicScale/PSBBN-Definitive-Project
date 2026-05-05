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

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

trap 'echo; exit 130' INT

TOOLKIT_PATH="$(pwd)"
SOURCES_LIST="/etc/apt/sources.list"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"
arch="$(uname -m)"

error_msg() {
    echo
    echo
    echo "[X] Error: $1" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to exit..."
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
        sudo sed -i '/deb cdrom/d' "$SOURCES_LIST" >> "${LOG_FILE}" 2>&1 || error_msg "Failed to clean $SOURCES_LIST"
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


Installing Dependences:
EOF

# Detect package manager and install packages
if [ -x "$(command -v apt-get)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        sudo dpkg --add-architecture i386
        i386="libc6:i386"
    fi
    sudo apt-get -q update && sudo apt-get install -y axel imagemagick xxd python3 python3-venv python3-pip bc rsync curl zip unzip wget ffmpeg lvm2 libfuse2 dosfstools e2fsprogs libc-bin exfatprogs exfat-fuse util-linux fdisk parted bchunk build-essential libicu-dev pkg-config ffmpegthumbnailer binfmt-support unrar-free $i386 2>&1 | tee -a "${LOG_FILE}"
# Or if user is on Fedora-based system, do this instead
elif [ -x "$(command -v dnf)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        i386="glibc.i686"
    fi
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>&1 | tee -a "${LOG_FILE}"
    sudo dnf install -y gcc-c++ axel ImageMagick xxd python3 python3-devel python3-pip bc rsync curl zip unzip wget ffmpeg lvm2 fuse-libs dosfstools e2fsprogs glibc-common exfatprogs fuse-exfat util-linux parted bchunk libicu-devel pkgconf ffmpegthumbnailer unrar-free $i386 2>&1 | tee -a "${LOG_FILE}"
# Or if user is on Arch-based system, do this instead
elif [ -x "$(command -v pacman)" ]; then
    if [[ "$arch" = "x86_64" ]]; then
        i386="lib32-glibc"
    fi
    sudo pacman -S --needed --noconfirm axel imagemagick xxd python pyenv python-pip bc rsync curl zip unzip wget ffmpeg lvm2 fuse2 dosfstools e2fsprogs glibc exfatprogs util-linux parted bchunk base-devel icu pkgconf ffmpegthumbnailer unrar-free $i386 2>&1 | tee -a "${LOG_FILE}"
elif [ -n "$IN_NIX_SHELL" ]; then
    error_msg "Running in Nix environment - packages should be provided by flake and setup should not be run."
else
    error_msg "No supported package manager found (apt-get, dnf, pacman)."
fi

if [ $? -ne 0 ]; then
    error_msg "Package installation failed. Please update your OS and try again." "See $LOG_FILE for details."
else
    echo "[✓] Packages checked/installed." | tee -a "${LOG_FILE}"
fi

# Python virtual environment setup
(
    python3 -m venv scripts/venv >> "${LOG_FILE}" 2>&1 || error_msg "Failed to create Python virtual environment."
    source scripts/venv/bin/activate || error_msg "Failed to activate the Python virtual environment."
    pip install lz4 natsort mutagen tqdm PyICU pykakasi pillow textual >> "${LOG_FILE}" || error_msg "Failed to install Python dependencies."
    deactivate
) &
PID=$!
spinner $PID "Setting up Python virtual environment and installing dependencies..."

echo
echo -n "[✓] Setup completed successfully!" | tee -a "${LOG_FILE}"
sleep 3
echo| tee -a "${LOG_FILE}"
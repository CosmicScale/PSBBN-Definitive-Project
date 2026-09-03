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

[[ -t 0 && -t 1 ]] || exit 1

echo -e "\e[8;45;110t"
term_width=110

export LC_MESSAGES=C
export LC_ALL=C.UTF-8
export LAUNCHED_BY_MAIN=1

# Set paths
export PATH="$PATH:/sbin:/usr/sbin"
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
HELPER_DIR="${SCRIPTS_DIR}/helper"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
LANG_DIR="${ASSETS_DIR}/lang"
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

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")

    if [ "$size" -gt 4194304 ]; then
        : > "$LOG_FILE"
    fi
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

# Get system locale if $SYS_LANG is not already set
if [[ -z "$SYS_LANG" ]]; then
    SYS_LANG="${LANG:-$(locale 2>/dev/null | awk -F= '/^LANG=/{print $2}')}"
fi

SYS_LANG="${SYS_LANG,,}"  # lowercase for easier matching

case "$SYS_LANG" in
    ja*|jp*)
        LANG_FILE="jpn"
        ;;
    fr*)
        LANG_FILE="fre"
        ;;
    es*|sp*)
        LANG_FILE="spa"
        ;;
    de*|ge*)
        LANG_FILE="ger"
        ;;
    it*)
        LANG_FILE="ita"
        ;;
    pt*|po*)
        LANG_FILE="por"
        ;;
    hu*)
        LANG_FILE="hun"
       ;;
    *)
        LANG_FILE="eng"
        ;;
esac

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

center_menu() {
    local longest=0
    local MENU_KEYS=(
        MAIN_MENU_OPTION_1
        MAIN_MENU_OPTION_2
        MAIN_MENU_OPTION_3
        MAIN_MENU_OPTION_4
        MAIN_MENU_OPTION_5
        MAIN_MENU_OPTION_6
    )

    for key in "${MENU_KEYS[@]}"; do
        local text="${UI_TEXT[$key]}"
        local width=$(text_width "$text")

        (( width > longest )) && longest=$width
    done

    padding=$(( (term_width - longest + 3) / 2 ))
}

center_text() {
    local text="$1"

    local display_width=$(text_width "$text")

    local padding=$(( (term_width - display_width) / 2 ))

    (( padding < 0 )) && padding=0

    printf "%*s%s" "$padding" "" "$text"
}

print_centered_file() {
    local file="$1"

    python3 - "$term_width" "$file" <<'PY'
import sys
import re
from wcwidth import wcwidth

term_width = int(sys.argv[1])
file = sys.argv[2]

INDENT = "  "
INDENT_W = 2

_wcwidth = wcwidth

def w(s):
    total = 0
    for c in s:
        wc = _wcwidth(c)
        if wc > 0:
            total += wc
    return total


def wrap_english(text):
    words = text.split()
    lines = []
    cur = []
    cur_w = 0

    available_width = term_width

    for word in words:
        word_w = w(word)
        add_w = word_w + (1 if cur else 0)

        if cur_w + add_w <= available_width:
            cur.append(word)
            cur_w += add_w
        else:
            if cur:
                lines.append(" ".join(cur))
            cur = [word]
            cur_w = word_w
            available_width = term_width - INDENT_W

    if cur:
        lines.append(" ".join(cur))

    return lines


def wrap_japanese(text):
    lines = []
    cur = ""
    cur_w = 0

    available_width = term_width

    for ch in text:
        ch_w = _wcwidth(ch)
        if ch_w < 0:
            ch_w = 0

        if cur_w + ch_w <= available_width:
            cur += ch
            cur_w += ch_w
        else:
            lines.append(cur)
            cur = ch
            cur_w = ch_w
            available_width = term_width - INDENT_W

    if cur:
        lines.append(cur)

    return lines


def is_mostly_latin(text):
    return sum(1 for c in text if ord(c) < 128) > len(text) * 0.5


def wrap(line):
    return wrap_english(line) if is_mostly_latin(line) else wrap_japanese(line)


wrapped = []
max_w = 0

with open(file, encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n")

        if not line:
            wrapped.append("")
            continue

        is_bullet = line.startswith("•")

        parts = wrap(line)

        for i, p in enumerate(parts):

            if is_bullet:
                if i > 0:
                    p = INDENT + p
            else:
                p = INDENT + p

            wrapped.append(p)
            max_w = max(max_w, w(p))


pad = max((term_width - max_w) // 2, 0)
prefix = " " * pad

for line in wrapped:
    print(prefix + line)

PY
}

error_msg() {
  error_1="$1"
  error_2="$2"
  error_3="$3"
  error_4="$4"

  echo
  echo "[X]" "$error_1"
  [ -n "$error_2" ] && echo && echo "$error_2"
  [ -n "$error_3" ] && echo "$error_3"
  [ -n "$error_4" ] && echo "$error_4"
  echo
  echo "${UI_TEXT[ERROR_TROUBLE]}"
  echo "${UI_TEXT[TROUBLE_URL]}"
  echo
  read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}" </dev/tty
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
        echo "[X] Error: This script cannot continue due to an unsupported installation." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_UNSUPPORTED_1]}" "${UI_TEXT[ERROR_UNSUPPORTED_2]}" "${UI_TEXT[ERROR_UNSUPPORTED_3]}" "${UI_TEXT[INSTALL_URL]}"
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
            echo "Downloading updates..." >> "${LOG_FILE}"
            echo "${UI_TEXT[UPDATE_GIT_1]}"
            # Get a list of files that have changed remotely
            UPDATED_FILES=$(git diff --name-only "$LOCAL" "$REMOTE")

            if [ -n "$UPDATED_FILES" ]; then
                echo "Files updated in the remote repository:" >> "${LOG_FILE}"
                echo "${UI_TEXT[UPDATE_GIT_2]}"
                echo "$UPDATED_FILES" | tee -a "${LOG_FILE}"

                # Reset only the files that were updated remotely (discard local changes to them)
                echo "$UPDATED_FILES" | xargs git checkout -- >> "${LOG_FILE}" 2>&1

                # Pull the latest changes
                if ! git pull --ff-only >> "${LOG_FILE}" 2>&1; then
                    echo "[X] Error: Git pull failed." >> "${LOG_FILE}"
                    error_msg "${UI_TEXT[ERROR_GIT_1]}" "git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git" "${UI_TEXT[ERROR_GIT_2]}"
                fi
                echo
                echo "[✓] The repository has been successfully updated." >> "${LOG_FILE}"
                echo "[✓] ${UI_TEXT[UPDATE_GIT_3]}"
                echo
                read -n 1 -s -r -p "${UI_TEXT[UPDATE_GIT_4]}" </dev/tty
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
        "${ASSETS_DIR}/database/AppDB.csv"
        "${ASSETS_DIR}/database/ArtDB.csv"
        "${ASSETS_DIR}/database/TitlesDB_PS1.csv"
        "${ASSETS_DIR}/database/TitlesDB_PS2.csv"
        "${ASSETS_DIR}/database/ps1_vmc_groups.list"
        "${ASSETS_DIR}/database/ps2_vmc_groups.list"
        "${ASSETS_DIR}/database/POP-game-fixes.list"
        "${HELPER_DIR}/genvmc.c"
        "${HELPER_DIR}/genvmc.h"
        "${HELPER_DIR}/psmbuild.py"
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
            echo "Missing file: $file" >> "$LOG_FILE"
            missing=true
        fi
    done

    # Check each directory
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" || -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            echo "Missing or empty directory: $dir" >> "$LOG_FILE"
            missing=true
        fi
    done

    # If any were missing, exit with error
    if [[ "$missing" == true ]]; then
        echo "[X] Error: Essential files not found." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_MISSING_1]}" "${UI_TEXT[ERROR_MISSING_2]}"
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
    check_cmd bsdtar
    check_cmd dmsetup

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
        check_python_pkg unidecode
        check_python_pkg textual
        check_python_pkg wcwidth
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
        elif [[ "$prefix" == "language-pak-$lang" ]]; then
            LATEST_LANG="$remote_version"
        elif [[ "$prefix" == "channels-$lang" ]]; then
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
            && echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}" || {
                echo "[X] Error: Failed to unmount: $mount_point"
                error_msg "${UI_TEXT[ERROR_UNMOUNT]} $mount_point"
            }
    done < <(lsblk -ln -o MOUNTPOINT "$DEVICE")

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || {
                    echo "[X] Error: Failed to unmount $line" >> "${LOG_FILE}"
                    error_msg "${UI_TEXT[ERROR_UNMOUNT]} $line"
                    }
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
    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CREATE]} ${OPL}."
        }

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

    prompt_len=$(( ${#UI_TEXT[MENU_PROMPT]} + padding ))
    opt3_len=$(( ${#UI_TEXT[MAIN_MENU_OPTION_3]} + padding ))

    if (( prompt_len > opt3_len )); then
        # Prompt is longer
        diff=$(( prompt_len - opt3_len - 4 ))
        move="tput cub $diff"
    elif (( prompt_len < opt3_len )); then
        # Prompt is shorter
        diff=$(( opt3_len - prompt_len + 4 ))
        move="tput cuf $diff"
    fi

    # Save current cursor (so user can type)
    tput sc
    # Move cursor up 10 lines from prompt to option 3
    tput cuu 10
    $move

    if (( on )); then
        printf %s "${UI_TEXT[UPDATE_AVAILABLE]}"
    else
        printf "%*s" "${#UI_TEXT[UPDATE_AVAILABLE]}" ""
    fi

    # Restore cursor so input stays at prompt
    tput rc
}

activate_python() {

    if [ -n "$IN_NIX_SHELL" ]; then
        echo "Running in Nix environment - packages should be provided by flake." >> "${LOG_FILE}"
        return
    fi

    echo "Activating Python virtual environment..." >> "${LOG_FILE}"
    # Try activating the virtual environment twice before failing
    if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
        echo "Failed to activate the Python virtual environment. Retrying..." >> "${LOG_FILE}"
        sleep 2
    
        if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
            echo "[X] Error: Failed to activate the Python virtual environment." >> "${LOG_FILE}"
            error_msg "Error" "${UI_TEXT[ERROR_ACTIVATE_PYTHON]}"
        fi
    fi
}

option_one() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -install "$LANG_FILE" "$serialnumber" "$path_arg"
}

option_two() {
    "${SCRIPTS_DIR}/HOSDMenu-Installer.sh" "$LANG_FILE" "$serialnumber" "$path_arg"
}

option_three() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -update "$LANG_FILE" "$path_arg"
}

option_four() {
    "${SCRIPTS_DIR}/Game-Installer.sh" "$LANG_FILE" "$path_arg"
}

option_five() {
    "${SCRIPTS_DIR}/Media-Installer.sh" "$LANG_FILE" "$wsl" "$path_arg"
}

option_six() {
    "${SCRIPTS_DIR}/Extras.sh" "$LANG_FILE" "$path_arg"
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
    center_text "${UI_TEXT[CREDIT]}"
    printf "\n\n\n\n"
    printf "%*s%s\n\n" "$padding" "1) " "${UI_TEXT[MAIN_MENU_OPTION_1]}"
    printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[MAIN_MENU_OPTION_2]}"
    printf "%*s%s\n\n" "$padding" "3) " "${UI_TEXT[MAIN_MENU_OPTION_3]}"
    printf "%*s%s\n\n" "$padding" "4) " "${UI_TEXT[MAIN_MENU_OPTION_4]}"
    printf "%*s%s\n\n" "$padding" "5) " "${UI_TEXT[MAIN_MENU_OPTION_5]}"
    printf "%*s%s\n\n" "$padding" "6) " "${UI_TEXT[MAIN_MENU_OPTION_6]}"
    printf "%*s%s\n\n" "$padding" "q) " "${UI_TEXT[MENU_QUIT]}"
    printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
}

check_required_files

if [ "$wsl" = "false" ]; then
        git_update
fi

trap 'echo; exit 130' INT
trap copy_log EXIT

cd "${TOOLKIT_PATH}"

if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
    sudo rm -f "${LOG_FILE}"
    if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
        echo
        error_msg "${UI_TEXT[ERROR_LOG]}"
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
{ echo -n "PSBBN Definitive Project Version: "; git rev-parse --short HEAD; } >> "${LOG_FILE}" 2>&1
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "WSL: $wsl" >> "${LOG_FILE}"
echo "Disk Serial: $serialnumber" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo "Language: $lang" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
    echo "[X] Error: Unsupported CPU architecture: $(uname -m). This script requires x86-64 or ARM64." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_UNSUPPORTED_4]}"
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
                echo -n "${UI_TEXT[ERROR_UNSUPPORTED_5]}"; echo -n " $NAME. "; echo "${UI_TEXT[ERROR_UNSUPPORTED_6]}"
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
    if ! "${TOOLKIT_PATH}/scripts/Setup.sh" $LANG_FILE; then
        exit 1
    else
        check_dep || {
            echo "[X] Error: Dependencies still missing after setup." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHECK_DEP]}"
        }
    fi
fi

activate_python

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

    lang=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")

    if [[ "$lang" != "jpn" && "$lang" != "ger" && "$lang" != "ita" && "$lang" != "por" && "$lang" != "spa" && "$lang" != "fre" && "$lang" != "hun" ]]; then
        lang="eng"
    fi

    LANG_VER=$(awk -F' *= *' '$1=="LANG_VER"{print $2}' "${OPL}/version.txt")
    CHAN_VER=$(awk -F' *= *' '$1=="CHAN_VER"{print $2}' "${OPL}/version.txt")

    echo "psbbn_version = $psbbn_version" >> "${LOG_FILE}"
    echo "osdmenu_version = $osdmenu_version" >> "${LOG_FILE}"
    echo "LANG = $lang" >> "${LOG_FILE}"
    echo "LANG_VER = $LANG_VER" >> "${LOG_FILE}"
    echo "CHAN_VER = $CHAN_VER" >> "${LOG_FILE}"


    UNMOUNT_OPL

    if [[ -n "$psbbn_version" || -n $osdmenu_version || -n "$LANG_VER" || -n "$CHAN_VER" ]]; then

        HTML_FILE=$(mktemp)
        curl -sSL -m 20 -o "$HTML_FILE" "$URL" >> "$LOG_FILE" 2>&1

        if [[ -n "$psbbn_version" ]]; then
            get_latest_file "psbbn-definitive-patch" "PSBBN Definitive Patch"

            if [ "$(printf '%s\n' "$LATEST_VERSION" "$psbbn_version" | sort -V | tail -n1)" != "$psbbn_version" ]; then
                PSBBN_UPDATE="YES"
            fi
        fi

        if [[ -n "$LANG_VER" ]]; then
            get_latest_file "language-pak-$lang" "$lang language pack"

            if [ "$(printf '%s\n' "$LATEST_LANG" "$LANG_VER" | sort -V | tail -n1)" != "$LANG_VER" ]; then
                LANG_UPDATE="YES"
                echo "Lang Update: $LANG_UPDATE" >> "${LOG_FILE}"
            fi
        fi

        if [[ -n "$CHAN_VER" ]]; then
            get_latest_file "channels-$lang" "$lang channels"

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

if [ -f "${ASSETS_DIR}/lang/changelog_main_$LANG_FILE.txt" ]; then
    SPLASH
    center_title "${UI_TEXT[CHANGELOG]}"
    echo
    print_centered_file "${ASSETS_DIR}/lang/changelog_main_$LANG_FILE.txt"
    echo
    echo
    center_text "${UI_TEXT[CHANGELOG_1]}"
    echo "$text"
    center_text "${UI_TEXT[CHANGE_URL]}"
    echo "$text"
    # echo
    # center_text "${UI_TEXT[CHANGELOG_2]}"
    # echo "$text"
    # center_text "https://youtu.be/UEsqDorgbew"
    #echo "$text"
    echo
    echo "=============================================================================================================="
    echo
    center_text "${UI_TEXT[CONTINUE]}"
    read -n 1 -s -r -p "$text" </dev/tty
    rm "${ASSETS_DIR}/lang/changelog_main_$LANG_FILE.txt"
fi

clear
center_menu
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
            *) printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
               sleep 2
               display_menu ;;
        esac
    fi
done

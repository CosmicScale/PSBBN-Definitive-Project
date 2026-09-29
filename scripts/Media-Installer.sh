#!/usr/bin/env bash
#
# Media Installer form the PSBBN Definitive Project
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

term_width=110

TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
MEDIA_DIR="${TOOLKIT_PATH}/media"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/media.log"
CONFIG_FILE="${TOOLKIT_PATH}/scripts/media.cfg"
arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    SQLITE="${HELPER_DIR}/sqlite"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    SQLITE="${HELPER_DIR}/aarch64/sqlite"
fi

LANG_FILE="$1"
shift  # remove language
wsl="$1"
path_arg="$2"

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

if [[ "$wsl" = "true" ]]; then
  PS2STR="${ASSETS_DIR}/ps2str/win32/ps2str.exe"
else
  PS2STR="${ASSETS_DIR}/ps2str/linux/ps2str"
fi

if [[ -n "$path_arg" ]]; then
    if [[ -d "$path_arg" ]]; then
        MEDIA_DIR="$path_arg"
    fi
elif [[ -f "$CONFIG_FILE" && -s "$CONFIG_FILE" ]]; then
    cfg_path="$(<"$CONFIG_FILE")"
    if [[ -d "$cfg_path" ]]; then
        MEDIA_DIR="$cfg_path"
    fi
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
      MEDIA_MENU_OPTION_1
      MEDIA_MENU_OPTION_2
      MEDIA_MENU_OPTION_3
      MEDIA_MENU_OPTION_4
      MEDIA_MENU_OPTION_5
    )

    for key in "${MENU_KEYS[@]}"; do
        local text="${UI_TEXT[$key]}"
        local width=$(text_width "$text")

        (( width > longest )) && longest=$width
    done

    padding=$(( (term_width - longest + 3) / 2 ))
}

center_text() {
    local input="$1"

    local display_width
    display_width=$(text_width "$input")

    local padding=$(( (term_width - display_width) / 2 ))

    (( padding < 0 )) && padding=0

    text=$(printf "%*s%s" "$padding" "" "$input")
}

if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")

    if [ "$size" -gt 4194304 ]; then
        : > "$LOG_FILE"
    fi
fi



MEDIA_SPLASH() {
  clear
  cat << "EOF"
                     ___  ___         _ _         _____          _        _ _           
                     |  \/  |        | (_)       |_   _|        | |      | | |          
                     | .  . | ___  __| |_  __ _    | | _ __  ___| |_ __ _| | | ___ _ __ 
                     | |\/| |/ _ \/ _` | |/ _` |   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                     | |  | |  __/ (_| | | (_| |  _| || | | \__ \ || (_| | | |  __/ |   
                     \_|  |_/\___|\__,_|_|\__,_|  \___/_| |_|___/\__\__,_|_|_|\___|_|



EOF
}

MUSIC_SPLASH() {
  clear
  cat << "EOF"
                      ___  ___          _        _____          _        _ _           
                      |  \/  |         (_)      |_   _|        | |      | | |          
                      | .  . |_   _ ___ _  ___    | | _ __  ___| |_ __ _| | | ___ _ __ 
                      | |\/| | | | / __| |/ __|   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                      | |  | | |_| \__ \ | (__   _| || | | \__ \ || (_| | | |  __/ |   
                      \_|  |_/\__,_|___/_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|   



EOF
}

MOVIE_SPLASH() {
  clear
  cat << "EOF"
                     ___  ___           _        _____          _        _ _           
                     |  \/  |          (_)      |_   _|        | |      | | |          
                     | .  . | _____   ___  ___    | | _ __  ___| |_ __ _| | | ___ _ __ 
                     | |\/| |/ _ \ \ / / |/ _ \   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                     | |  | | (_) \ V /| |  __/  _| || | | \__ \ || (_| | | |  __/ |   
                     \_|  |_/\___/ \_/ |_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|   



EOF
}

PHOTO_SPLASH() {
  clear
  cat << "EOF"
                    ______ _           _          _____          _        _ _           
                    | ___ \ |         | |        |_   _|        | |      | | |          
                    | |_/ / |__   ___ | |_ ___     | | _ __  ___| |_ __ _| | | ___ _ __ 
                    |  __/| '_ \ / _ \| __/ _ \    | || '_ \/ __| __/ _` | | |/ _ \ '__|
                    | |   | | | | (_) | || (_) |  _| || | | \__ \ || (_| | | |  __/ |   
                    \_|   |_| |_|\___/ \__\___/   \___/_| |_|___/\__\__,_|_|_|\___|_|   



EOF
}

LOCATION_SPLASH() {
  clear
  cat << "EOF"
           _____      _    ___  ___         _ _         _                     _   _             
          /  ___|    | |   |  \/  |        | (_)       | |                   | | (_)            
          \ `--.  ___| |_  | .  . | ___  __| |_  __ _  | |     ___   ___ __ _| |_ _  ___  _ __  
           `--. \/ _ \ __| | |\/| |/ _ \/ _` | |/ _` | | |    / _ \ / __/ _` | __| |/ _ \| '_ \ 
          /\__/ /  __/ |_  | |  | |  __/ (_| | | (_| | | |___| (_) | (_| (_| | |_| | (_) | | | |
          \____/ \___|\__| \_|  |_/\___|\__,_|_|\__,_| \_____/\___/ \___\__,_|\__|_|\___/|_| |_|
                                                                                      


EOF
}

INI_SPLASH() {
  clear
  cat << "EOF"
                      _____      _ _   _       _ _           ___  ___          _      
                     |_   _|    (_) | (_)     | (_)          |  \/  |         (_)     
                       | | _ __  _| |_ _  __ _| |_ ___  ___  | .  . |_   _ ___ _  ___ 
                       | || '_ \| | __| |/ _` | | / __|/ _ \ | |\/| | | | / __| |/ __|
                      _| || | | | | |_| | (_| | | \__ \  __/ | |  | | |_| \__ \ | (__ 
                      \___/_| |_|_|\__|_|\__,_|_|_|___/\___| \_|  |_/\__,_|___/_|\___|
                                                                 


EOF
}

# Function to display the menu
display_menu() {
    MEDIA_SPLASH
    printf "\n\n\n"
    printf "%*s%s\n\n" "$padding" "1) " "${UI_TEXT[MEDIA_MENU_OPTION_1]}"
    printf "%*s%s\n\n" "$padding" "2) " "${UI_TEXT[MEDIA_MENU_OPTION_2]}"
    printf "%*s%s\n\n" "$padding" "3) " "${UI_TEXT[MEDIA_MENU_OPTION_3]}"
    printf "%*s%s\n\n" "$padding" "4) " "${UI_TEXT[MEDIA_MENU_OPTION_4]}"
    printf "%*s%s\n\n" "$padding" "5) " "${UI_TEXT[MEDIA_MENU_OPTION_5]}"
    printf "%*s%s\n\n" "$padding" "b) " "${UI_TEXT[MENU_BACK]}"
    printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_PROMPT]}"
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
}

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

clean_up() {
    cd "${TOOLKIT_PATH}"
    failure=0

    sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1
    sudo rm -rf "$TMP_DIR"

    findmnt -nr -o TARGET | sed 's/\\x20/ /g' | while IFS= read -r line; do
        case "$line" in
            "$STORAGE_DIR/"*)
                echo "Unmounting: <$line>" >> "$LOG_FILE"
                sudo umount "$line" || {
                    echo "[X] Error: Failed to unmount $line" >> "${LOG_FILE}"
                    failure=1
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

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo "[X] Error: Cleanup error(s) occurred. Aborting." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_CLEANUP]}"
        return 1
    fi
}

exit_script() {
    prevent_sleep_stop
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
      echo "[X] Error: Unable to detect the PS2 drive" >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_DETECT_DRIVE_1]}" "${UI_TEXT[ERROR_DETECT_DRIVE_3]}"
      exit 1
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

    # Find all mounted volumes associated with the device
    mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

    # Iterate through each mounted volume and unmount it
    echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
    for mount_point in $mounted_volumes; do
        echo "Unmounting $mount_point..." >> "${LOG_FILE}"
        if sudo umount "$mount_point" >> "${LOG_FILE}" 2>&1; then
          echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
          echo "[X] Error: Failed to unmount: $mount_point" >> "${LOG_FILE}"
          error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $mount_point"
          exit 1
        fi
    done

    if ! sudo "${HDL_DUMP}" toc $DEVICE >> /dev/null 2>&1; then
      echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
      exit 1
    else
      echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

MOUNT_OPL() {
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    mkdir -p "${OPL}" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CREATE]} ${OPL}"
        exit 1
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
        exit 1
    fi
}

UNMOUNT_OPL() {
    echo "Unmounting OPL partition..." >> "${LOG_FILE}"
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        echo "[X] Error: Failed to unmount $DEVICE" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $DEVICE"
        exit 1
    fi
}

CHECK_PARTITIONS() {
    TOC_OUTPUT=$(sudo "${HDL_DUMP}" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "[X] Error: Failed to extract list of partitions. APA partition table could be broken on ${DEVICE}" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
        exit 1
    fi

    # List of required partitions
    required=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.9 __contents __system __sysconf __common)

    # Check all required partitions
    for part in "${required[@]}"; do
        if ! echo "$TOC_OUTPUT" | grep -Fq "$part"; then
            error_msg "PSBBN is not installed." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_OS_CHECK_2]}"
            exit 1
        fi
    done
}

mapper_probe() {
  DEVICE_CUT=$(basename "${DEVICE}")
  existing_maps=$(sudo dmsetup ls | grep -o "^${DEVICE_CUT}-[^ ]*" || true)
  for map in $existing_maps; do
    sudo dmsetup remove "$map" 2>/dev/null
  done
  sudo "${HDL_DUMP}" toc "${DEVICE}" --dm | sudo dmsetup create --concise
  MAPPER="/dev/mapper/${DEVICE_CUT}-"
}

mount_cfs() {
  arg="$1"
  for PARTITION_NAME in "${PARTITION_NAMES[@]}"; do
    MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
    if [ -e "${MAPPER}${PARTITION_NAME}" ]; then
      [ -d "${MOUNT_PATH}" ] || mkdir -p "${MOUNT_PATH}"
      if ! sudo mount -o rw "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
        case "$PARTITION_NAME" in
          "__linux.7")
            if [ "$arg" = "music" ]; then
              echo "[X] Error: Failed to mount the Database partition." >>"${LOG_FILE}"
              error_msg "${UI_TEXT[ERROR_MOUNT_4]}"
              return 1
            fi
            ;;
          "__linux.8")
            echo  "[X] Error: Failed to mount the Music partition." >>"${LOG_FILE}"
            if [ "$arg" = "music" ]; then
              error_msg "${UI_TEXT[ERROR_MOUNT_5]}" "${UI_TEXT[ERROR_MOUNT_6]}" 
              return 1
            else
              error_msg "${UI_TEXT[ERROR_MOUNT_5]}" "${UI_TEXT[ERROR_MOUNT_7]}"
              return 1
            fi
            ;;
        esac
      fi
    else
      echo "[X] Error: Partition not found on disk: ${PARTITION_NAME}" >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MOUNT_3]} ${PARTITION_NAME}"
      return 1
    fi
  done
}

mount_pfs() {
    for PARTITION_NAME in "${PFS_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        mkdir -p "$MOUNT_POINT"
        if ! sudo "${PFS_FUSE}" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            echo "[X] Error: Failed to mount $PARTITION_NAME" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_MOUNT_2]} $PARTITION_NAME"
            return 1
        fi
    done
}

get_display_path() {
if [[ "$MEDIA_DIR" =~ ^/mnt/([a-zA-Z])(/.*)?$ ]]; then
    drive="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"

    # If the rest is empty, default to empty string
    [[ -z "$rest" ]] && rest=""

    # Convert to Windows format
    display_path="${drive^^}:$(echo "$rest" | sed 's#/#\\#g')\\"
else
    # For Linux paths, display_path is the same as MEDIA_DIR
    display_path="$MEDIA_DIR/"
fi
}

download_ps2str() {
    # Check if ps2str_v1.08_2001.zip exists
    if [[ -f "${ASSETS_DIR}/ps2str_v1.08_2001.zip" ]]; then
      echo "Found ${ASSETS_DIR}/ps2str_v1.08_2001.zip..." >> "${LOG_FILE}"
        echo "${UI_TEXT[GET_LATEST_FILE_1]} ${ASSETS_DIR}/ps2str_v1.08_2001.zip..."
        bsdtar -xf "${ASSETS_DIR}/ps2str_v1.08_2001.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
    else
        echo "Downloading ps2str..." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLOAD_REQUIRED]}"
        wget --quiet --timeout=10 --tries=3 -O "${ASSETS_DIR}/ps2str_v1.08_2001.zip" https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip
        echo
        if [[ -s "${ASSETS_DIR}/ps2str_v1.08_2001.zip" ]]; then
            bsdtar -xf "${ASSETS_DIR}/ps2str_v1.08_2001.zip" -C "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        fi
    fi
}

format_size() {
    local SIZE_MB=$1
    if (( $(echo "$SIZE_MB >= 1024" | bc -l) )); then
        # Convert to GB with 1 decimal
        printf "%.1f GB" "$(echo "$SIZE_MB / 1024" | bc -l)"
    else
        # Round to nearest MiB
        printf "%.0f MB" "$SIZE_MB"
    fi
}

movie_space_check() {
    local_space="0"
    ps2_space="0"
    DURATION_MINUTES="0"

    # Get duration in seconds
    local DURATION_SECONDS=$(ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$f")

    if [[ -z "$DURATION_SECONDS" ]]; then
        echo "Could not determine video duration." >>"${LOG_FILE}"
        return 1
    fi

    # Convert seconds to minutes
    DURATION_MINUTES=$(echo "scale=0; $DURATION_SECONDS / 60" | bc)

    # Estimates
    if [ "$DURATION_MINUTES" -le 31 ]; then
      bitrate=1800
      local VIDEO_MB_PER_MIN=24
    elif [ "$DURATION_MINUTES" -le 89 ]; then
      bitrate=1600
      local VIDEO_MB_PER_MIN=23
    elif [ "$DURATION_MINUTES" -le 92 ]; then
      bitrate=1400
      local VIDEO_MB_PER_MIN=22
    elif [ "$DURATION_MINUTES" -le 102 ]; then
      bitrate=1200
      local VIDEO_MB_PER_MIN=20
    elif [ "$DURATION_MINUTES" -le 107 ]; then
      bitrate=1000
      local VIDEO_MB_PER_MIN=19
    elif [ "$DURATION_MINUTES" -le 120 ]; then
      bitrate=800
      local VIDEO_MB_PER_MIN=17
    else
      bitrate=600
      local VIDEO_MB_PER_MIN=16
    fi

    local AUDIO_MB_PER_MIN=13

    local VIDEO_ESTIMATED_SIZE_MB=$(echo "$DURATION_MINUTES * $VIDEO_MB_PER_MIN" | bc -l)
    local AUDIO_ESTIMATED_SIZE_MB=$(echo "$DURATION_MINUTES * $AUDIO_MB_PER_MIN" | bc -l)
    local VIDEO_CONVERSION_SIZE_MB=$(echo "$VIDEO_ESTIMATED_SIZE_MB * 2" | bc -l)
    local BUFFER_MB=$(echo "$DURATION_MINUTES * 5" | bc -l)

    local TOTAL_MB=$(echo "$VIDEO_CONVERSION_SIZE_MB + $AUDIO_ESTIMATED_SIZE_MB + $BUFFER_MB" | bc -l)

    # Round estimates for display and comparison
    local AUDIO_ESTIMATED_SIZE_ROUNDED=$(printf "%.0f" "$AUDIO_ESTIMATED_SIZE_MB")
    local VIDEO_CONVERSION_ROUNDED=$(printf "%.0f" "$VIDEO_CONVERSION_SIZE_MB")
    local BUFFER_ROUNDED=$(printf "%.0f" "$BUFFER_MB")
    VIDEO_ESTIMATED_SIZE_ROUNDED=$(printf "%.0f" "$VIDEO_ESTIMATED_SIZE_MB")
    TOTAL_ROUNDED=$(printf "%.0f" "$TOTAL_MB")

    printf "\n" >> "${LOG_FILE}"
    printf "Video: $f\n" >> "${LOG_FILE}"
    printf "Video duration: %.2f minutes\n" "$DURATION_MINUTES" >> "${LOG_FILE}"
    printf "Estimated video size: %d MiB\n" "$VIDEO_ESTIMATED_SIZE_ROUNDED" >> "${LOG_FILE}"
    printf "Estimated space needed for conversion: %d MiB\n" "$VIDEO_CONVERSION_ROUNDED" >> "${LOG_FILE}"
    printf "Estimated audio size: %d MiB\n" "$AUDIO_ESTIMATED_SIZE_ROUNDED" >> "${LOG_FILE}"
    printf "Buffer required: %d MiB\n" "$BUFFER_ROUNDED" >> "${LOG_FILE}"
    printf "Total estimated space required: %d MiB\n" "$TOTAL_ROUNDED" >> "${LOG_FILE}"

    # Get available space (in MiB)
    local AVAILABLE_LOCAL_KB=$(df --output=avail "${MEDIA_DIR}/movie" | tail -n 1)
    local AVAILABLE_STORAGE_KB=$(df --output=avail "${STORAGE_DIR}/__contents" | tail -n 1)

    AVAILABLE_LOCAL_MB=$(echo "$AVAILABLE_LOCAL_KB / 1024" | bc)
    AVAILABLE_STORAGE_MB=$(echo "$AVAILABLE_STORAGE_KB / 1024" | bc)

    printf "Available space on local filesystem: %d MiB\n" "$AVAILABLE_LOCAL_MB" >> "${LOG_FILE}"
    printf "Available space on storage filesystem: %d MiB\n" "$AVAILABLE_STORAGE_MB" >> "${LOG_FILE}"

    if (( $(echo "$AVAILABLE_LOCAL_MB < $TOTAL_ROUNDED" | bc -l) )); then
        local_space="1"
        return 1
    fi

    if (( AVAILABLE_STORAGE_MB < VIDEO_ESTIMATED_SIZE_ROUNDED )); then
        ps2_space="1"
        return 1
    fi

    if [ "$DURATION_MINUTES" -gt 135 ]; then
        ps2_space="2"
        return 1
    fi

}

option_one() {
  echo >> "$LOG_FILE"
  echo "########################### Running Music Installer ###########################" >> "$LOG_FILE"

  MUSIC_SPLASH

  PARTITION_NAMES=("__linux.7" "__linux.8" )
  TMP_DIR="${SCRIPTS_DIR}/tmp"

  mkdir -p "${MEDIA_DIR}/music" &>> "${LOG_FILE}" || {
    echo "Failed to create folder: ${MEDIA_DIR}/music" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} ${MEDIA_DIR}/music"
    return 1
  }

  mkdir -p "${TMP_DIR}" &>> "${LOG_FILE}" || {
    error_msg "Failed to create tmp directory."
    echo "Failed to create folder: ${TMP_DIR}" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} ${TMP_DIR}"
    return 1
  }

  echo "Music Path ${MEDIA_DIR}/music" >> "$LOG_FILE"
  get_display_path

  center_title "${UI_TEXT[MUSIC_INSTALLER_1]}"

  printf '\n  %s\n'    "${UI_TEXT[MUSIC_INSTALLER_2]}"
  printf '  %s\n\n'  "${UI_TEXT[MUSIC_INSTALLER_3]}"
  printf '  %s\n'    "${UI_TEXT[MUSIC_INSTALLER_4]}"
  printf '  %s\n\n'  "${display_path}music"
  printf '  %s\n'    "${UI_TEXT[MUSIC_INSTALLER_5]}"
  printf '  %s\n\n'  "${UI_TEXT[MUSIC_INSTALLER_6]}"
  printf "==============================================================================================================\n"

  echo
  center_text "${UI_TEXT[CONTINUE]}"
  read -n 1 -s -r -p "$text" </dev/tty
  MUSIC_SPLASH

  echo "Contents of music folder:" >> "${LOG_FILE}"
  find "${MEDIA_DIR}/music/" -type f >> "${LOG_FILE}"
  echo >> "${LOG_FILE}"

  if find "${MEDIA_DIR}/music/" -type f ! -name ".*" \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.flac" -o -iname "*.ogg" \) | grep -q .; then
    echo "Preparing to installing music..." >> "${LOG_FILE}"
    echo -n "${UI_TEXT[MUSIC_INSTALLER_7]}"

    prevent_sleep_start

    mapper_probe

    if ! mount_cfs music; then
      return 1
    fi

    echo | tee -a "${LOG_FILE}"
    echo

    echo "Converting music..." >> "${LOG_FILE}"

    sql_out="$("${SQLITE}" "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" .dump > "${TMP_DIR}/music_dump.sql" 2>&1)"

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to extract music database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MUSIC_INSTALLER_1]}"
      return 1
    fi

    if ! sudo "${SCRIPTS_DIR}/venv/bin/python" "${HELPER_DIR}/music-installer.py" "${MEDIA_DIR}/music"; then
      echo "[X] Error: Failed to convert music." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MUSIC_INSTALLER_2]}"
      return 1
    else
      echo
      echo "[✓] Music successfully converted." >> "${LOG_FILE}"
    fi

    sql_out="$("${SQLITE}" "${TMP_DIR}/music.db" < "${TMP_DIR}/music_reconstructed.sql" 2>&1)"

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to create music database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MUSIC_INSTALLER_3]}"
      return 1
    fi

    if ! sudo mv "${TMP_DIR}/music.db" "${STORAGE_DIR}/__linux.7/database/sqlite/"; then
      echo "[X] Error: Failed to install music database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MUSIC_INSTALLER_4]}"
      return 1
    fi

    clean_up || return 1
    echo "[✓] Music successfully converted and database updated." >> "${LOG_FILE}"
    echo "[✓] ${UI_TEXT[MUSIC_INSTALLER_8]}"
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}"
  else
    echo "[X] Error: No music to install." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INSTALLER_5]}"
  fi

}

option_two() {
  echo >> "$LOG_FILE"
  echo "########################### Running Movie Installer ###########################" >> "$LOG_FILE"
  MOVIE_SPLASH

  if [[ "$arch" != "x86_64" ]]; then
    echo "[X] Error: The movie install requires a x86 processor." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_1]}"
    return 1
  fi

  # Check for ps2str
  if [[ -f "$PS2STR" ]]; then
      echo "ps2str present. Skipping download" >> "${LOG_FILE}"
  else
    echo "$PS2STR missing" >> "${LOG_FILE}"
    download_ps2str

    # Check if ps2str exists after extraction
    if [[ -f "$PS2STR" ]]; then
        echo "[✓] ps2str successfully extracted." >> "${LOG_FILE}"
    else
      rm "${ASSETS_DIR}/ps2str_v1.08_2001.zip"
      echo "[X] Error: ps2str_v1.08_2001.zip Download failed" >> "${LOG_FILE}"
      error_msg "[X] ${UI_TEXT[ERROR_DOWNLOAD]}" "${UI_TEXT[GET_LATEST_FILE_3]}"
      return 1
    fi  
  fi

  MOVIE_SPLASH

  chmod +x "$PS2STR"
  echo "Movie Path ${MEDIA_DIR}/movie" >> "$LOG_FILE"
  get_display_path

  center_title "${UI_TEXT[MOVIE_INSTALLER_1]}"

  printf '\n  %s\n' "${UI_TEXT[MOVIE_INSTALLER_2]}"
  printf '  %s\n' "${UI_TEXT[MOVIE_INSTALLER_3]}"
  printf '  %s\n\n' "${UI_TEXT[MOVIE_INSTALLER_4]}"
  printf '  %s\n' "${UI_TEXT[MOVIE_INSTALLER_5]}"
  printf '  %s\n\n' "${display_path}movie"
  printf "==============================================================================================================\n\n"

  center_text "${UI_TEXT[CONTINUE]}"
  read -n 1 -s -r -p "$text" </dev/tty

  MOVIE_SPLASH

  echo "Contents of movie folder:" >> "${LOG_FILE}"
  find "${MEDIA_DIR}/movie/" -type f >> "${LOG_FILE}"
  echo >> "${LOG_FILE}"

  # Collect movie files (case-insensitive, no hidden files, top-level only)
  mapfile -d '' movies < <(
    find "${MEDIA_DIR}/movie/" -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.mkv" \
        -o -iname "*.avi" -o -iname "*.webm" -o -iname "*.mpg" -o -iname "*.mpeg"\
        -o -iname "*.vob" -o -iname "*.ts" -o -iname "*.m2ts" -o -iname "*.mts" \
        -o -iname "*.ogv" -o -iname "*.pss" -o -iname "*.psm" \) -print0
  )

  if (( ${#movies[@]} )); then
    echo "Movies found. Processing movies: ${display_path}movie..." >> "${LOG_FILE}"
    echo "${UI_TEXT[MOVIE_INSTALLER_6]}"

    failure=0
    MOVIE_DIR=""
    PFS_PARTITIONS=("__contents")
    PARTITION_NAMES=("__linux.7")
    TMP_DIR="${MEDIA_DIR}/movie/tmp"
    SQL_FILE="${TMP_DIR}/movie.sql"

    mkdir -p "$TMP_DIR" || {
        echo "[X] Error: Failed to create folder: $TMP_DIR" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} $TMP_DIR"
        return 1
      }
    cd "$TMP_DIR" || {
        echo "[X] Error: Failed to change directory: $TMP_DIR" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CD]} $TMP_DIR"
        return 1
      }

    mapper_probe
  
    if ! mount_pfs; then
      clean_up
      return 1
    fi

    if ! mount_cfs; then
      clean_up
      return 1
    fi

    if [[ -f  "${STORAGE_DIR}/__linux.7/database/sqlite/movie.db" ]]; then
      sql_out="$("${SQLITE}" "${STORAGE_DIR}/__linux.7/database/sqlite/movie.db" .dump > "${SQL_FILE}" 2>&1)"
    else
      echo "[X] Error: Failed to extract movie database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_2]}"
      return 1
    fi

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to extract movie database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_2]}"
      return 1
    fi

    MOVIE_DIR=$(
      awk -F"," '
        $1 ~ /\(\047Your Movies\047/ {
          gsub(/[^0-9]/, "", $3)
          print $3
          exit
        }
      ' "$SQL_FILE"
    )

    if [[ -z "$MOVIE_DIR" ]]; then
      MOVIE_DIR=$(date +"%Y%m%d%H%M%S")
      sed -i "/^COMMIT;/i INSERT INTO sce_movie VALUES('Your Movies','Your Movies',${MOVIE_DIR},'pfs:/__contents/contents/video/${MOVIE_DIR}','Your Moviespfs:/__contents/contents/video/${MOVIE_DIR}',0,0,128,512);" "${SQL_FILE}" >> "${LOG_FILE}" 2>&1
    fi

    mkdir -p "${STORAGE_DIR}/__contents/contents/video/${MOVIE_DIR}" || {
      echo "[X] Error: Failed to create folder: $STORAGE_DIR/__contents/contents/video/$MOVIE_DIR" >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} $STORAGE_DIR/__contents/contents/video/$MOVIE_DIR"
      return 1
    }

    mapfile -t movies_sorted < <(printf '%s\n' "${movies[@]}" | sort -r)

    for f in "${movies_sorted[@]}"; do
      base="${f%.*}"      # remove extension
      base="${base##*/}"  # remove path
      file_name="${base// /_}"  # replace spaces with _
      file_name="${file_name//[^a-zA-Z0-9_-]/}" # remove everything except a-z, A-Z, 0-9, _ and -
      file_name="${file_name:0:29}" # truncate to 29 characters
      psm="${STORAGE_DIR}/__contents/contents/video/${MOVIE_DIR}/${file_name}.psm"
      wav="${TMP_DIR}/${file_name}.wav"
      ads="${TMP_DIR}/${file_name}.ads"
      m2v="${TMP_DIR}/${file_name}.m2v"
      pss="${TMP_DIR}/${file_name}.pss"
      mux="${TMP_DIR}/${file_name}.mux"
      BAT_FILE="${TMP_DIR}/${file_name}.bat"
      thumbnail="${TMP_DIR}/${file_name}.png"
      movie_title="${base//_/ }" # replace underscores with spaces
      database_file="${file_name//\'/\'\'}"

      # Skip if .psm already exists
      if [[ -f "$psm" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "Skipping (already processed): ${f##*/}" >> "${LOG_FILE}"
        echo "${UI_TEXT[MOVIE_INSTALLER_7]} ${f##*/}"
        continue
      fi

      # if not .psm or .pss file
      if [[ $f != *.pss && $f != *.psm && $f != *.PSS && $f != *.PSM ]]; then
          movie_space_check

        if [ "$local_space" = "1" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "[!] Warning: Not enough local storage space to convert: ${f##*/}." >> "${LOG_FILE}"
          echo "[!] ${UI_TEXT[WARN_MOVIE_INSTALLER_1]} ${f##*/}."
          echo "Required: $(format_size "$TOTAL_ROUNDED")" >> "${LOG_FILE}"
          echo "${UI_TEXT[REQUIRED]} $(format_size "$TOTAL_ROUNDED")"
          echo "Available: $(format_size "$AVAILABLE_LOCAL_MB")" >> "${LOG_FILE}"
          echo "${UI_TEXT[AVAILABLE_SPACE]} $(format_size "$AVAILABLE_LOCAL_MB")"
          failure=1
          continue
        else
          echo
          echo "Sufficient local free space available." >> "${LOG_FILE}"
        fi

        if [ "$ps2_space" = "1" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "[!] Warning: Not enough PS2 storage space to convert: ${f##*/}." >> "${LOG_FILE}"
          echo "[!] ${UI_TEXT[WARN_MOVIE_INSTALLER_2]} ${f##*/}."
          echo "Required: $(format_size "$VIDEO_ESTIMATED_SIZE_ROUNDED")" >> "${LOG_FILE}"
          echo "${UI_TEXT[REQUIRED]} $(format_size "$VIDEO_ESTIMATED_SIZE_ROUNDED")"
          echo "Available: $(format_size "$AVAILABLE_STORAGE_MB")" >> "${LOG_FILE}"
          echo "${UI_TEXT[AVAILABLE_SPACE]} $(format_size "$AVAILABLE_STORAGE_MB")"
          failure=1
          continue
        else
          echo "Sufficient free space available on PS2 storage." >> "${LOG_FILE}"
        fi

        if [ "$ps2_space" = "2" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "[!] Warning: The following movie might be too long: ${f##*/}" >> "${LOG_FILE}"
          echo "[!] ${UI_TEXT[WARN_MOVIE_INSTALLER_3]} ${f##*/}."
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_4]}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_5]}"
          echo
          while true; do
            read -rp "${UI_TEXT[WARN_MOVIE_INSTALLER_6]} (y/n):" CONVERT
            case "$CONVERT" in
            [Yy])
                break
                ;;
            [Nn])
                echo "${UI_TEXT[MOVIE_INSTALLER_8]} ${f##*/}" | tee -a "${LOG_FILE}"
                continue 2
                ;;
            *)
                echo
                echo "${UI_TEXT[MENU_INVALID]}"
                ;;
            esac
          done
        else
          echo "Video not too long." >> "${LOG_FILE}"
        fi

        echo "${UI_TEXT[MOVIE_INSTALLER_9]} ${f##*/}" | tee -a "${LOG_FILE}"

        tmp_log="$(mktemp)"

        # Extract audio
        ffmpeg -y -hide_banner -loglevel error -stats \
          -guess_layout_max 0 \
          -i "$f" \
          -af "aresample=48000,volume=3.874dB" \
          -map 0:a:0 \
          -vn \
          -ac 2 \
          -acodec pcm_s16le \
          "$wav" 2>&1 | tee "$tmp_log"

        # Detect interlacing
        field_order=$(ffprobe -v error -select_streams v:0 \
          -show_entries stream=field_order -of default=nw=1:nk=1 "$f")

        if [[ "$field_order" == "progressive" ]]; then
          interlace_opts=""
          echo "Input is progressive → encoding progressive" >> "${LOG_FILE}"
        else
          interlace_opts="-flags +ilme+ildct -top 1"
          echo "Input is interlaced → encoding interlaced" >> "${LOG_FILE}"
        fi

        echo "Encoding video at: $bitrate kbps" >> "${LOG_FILE}"
        echo "${UI_TEXT[MOVIE_INSTALLER_10]} $bitrate kbps"
        # Convert video
        ffmpeg -y -hide_banner -loglevel error -stats \
          -i "$f" \
          -vf "fps=30000/1001,scale=iw*sar:ih,setsar=1,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
          -an \
          -c:v mpeg2video \
          -b:v ${bitrate}k \
          -g 30 \
          -bf 3 \
          -trellis 1 \
          -dc 10 \
          -sc_threshold 40 \
          $interlace_opts \
          "$m2v" 2>&1 | tee -a "$tmp_log"

        # Append only lines that don’t start with frame= or size= to the real log
        grep -Ev '^(frame=|size=)' "$tmp_log" >> "$LOG_FILE"

        # Remove temp file
        rm -f "$tmp_log"

        if (( $(stat -c%s "$wav") + $(stat -c%s "$m2v") > 2147483648 - 15728640 )); then
          echo "[!] Warning: The following file will be larger than 2048 MiB: $file_name.psm" >> "${LOG_FILE}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_7]}"
          bitrate=$((bitrate - 200))
          echo "Re-encoding at: $bitrate kbps" >> "${LOG_FILE}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_8]} $bitrate kbps"
          rm -f "$m2v"
          ffmpeg -y -hide_banner -loglevel error -stats \
            -i "$f" \
            -vf "fps=30000/1001,scale=iw*sar:ih,setsar=1,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
            -an \
            -c:v mpeg2video \
            -b:v ${bitrate}k \
            -g 30 \
            -bf 3 \
            -trellis 1 \
            -dc 10 \
            -sc_threshold 40 \
            $interlace_opts \
            "$m2v" 2>&1 | tee -a "$tmp_log"

            if (( $(stat -c%s "$wav") + $(stat -c%s "$m2v") > 2147483648 - 15728640 )); then
              echo "[!] Warning: Skipping video - larger than 2048 MiB: $file_name.psm " >> "${LOG_FILE}"
              echo "${UI_TEXT[WARN_MOVIE_INSTALLER_9]} $file_name.psm"
              failure=1
              rm -f "$wav" "$m2v"
              continue
            fi
        fi
    
        if [[ -f "$wav" && -f "$m2v" ]]; then
          # Create .ads file

          if [ "$wsl" = "true" ]; then
            display_path="${display_path//\\//}"
            wav="${display_path}movie/tmp/${file_name}.wav"
            ads="${display_path}movie/tmp/${file_name}.ads"
          fi

          if ! "${PS2STR}" encode -v "$wav" "$ads" >> "${LOG_FILE}" 2>&1; then
            echo "Warning: Skipping video - Failed to encode: $ads" >> "${LOG_FILE}"
            echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} $ads"
            ads="${TMP_DIR}/${file_name}.ads"
            wav="${TMP_DIR}/${file_name}.wav"
            rm -f "$wav" "$ads" "$m2v"
            failure=1
            continue
          fi
          echo "Encoded $wav → $ads" >> "${LOG_FILE}"
          ads="${TMP_DIR}/${file_name}.ads"
          wav="${TMP_DIR}/${file_name}.wav"
        else
          echo "Warning: Skipping video - Failed to encode: ${f##*/}" >> "${LOG_FILE}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} ${f##*/}"
          failure=1
          rm -f "$wav" "$m2v"
        fi

        if [ -f "$ads" ]; then
          rm -f $wav
          if [ "$wsl" = "true" ]; then
            cat > "$mux" <<EOF
pss
	stream video:0
		input "${file_name}.m2v"
	end

	stream pcm:0
		input "${file_name}.ads"
	end
end
EOF
          else
            cat > "$mux" <<EOF
pss
	stream video:0
		input "$m2v"
	end

	stream pcm:0
		input "$ads"
	end
end
EOF
          fi
        fi

        echo "Encoding: $file_name.pss..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[MOVIE_INSTALLER_11]} $file_name.pss..."
        echo >> "${LOG_FILE}"

        # Create .pss file
        if [ "$wsl" = "true" ]; then
          wsl_path="${PS2STR//\//\\}"
          cat > "$BAT_FILE" <<EOF
cd /d "${display_path}movie\tmp
"\\\wsl.localhost\PSBBN$wsl_path" mux -v "${file_name}.mux"
EOF
          if ! cmd.exe /c "${display_path}movie/tmp/${file_name}.bat" >> "${LOG_FILE}" 2>&1; then
            echo
            echo "[!] Warning: Skipping video - Failed to encode: $pss" >> "${LOG_FILE}"
            echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} $pss"
            failure=1
            rm -f "$ads" "$m2v" "$mux" "$pss" "$BAT_FILE"
            continue
          fi
        else
          if ! "${PS2STR}" mux -v "$mux" >> "${LOG_FILE}" 2>&1; then
            echo
            echo "[!] Warning: Skipping video - Failed to encode: $pss" >> "${LOG_FILE}"
            echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} $pss"
            failure=1
            rm -f "$ads" "$m2v" "$mux" "$pss"
            continue
          fi
        fi
        echo

        rm -f "$ads" "$m2v" "$mux" "$BAT_FILE"
      fi

      if [[ $f != *.psm && $f != *.PSM ]]; then
        if [[ -z "$DURATION_SECONDS" ]]; then
          # Get duration in seconds
          DURATION_SECONDS=$(ffprobe -v error \
            -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 \
            "$f")

          # Convert seconds to minutes
          DURATION_MINUTES=$(echo "$DURATION_SECONDS / 60" | bc -l)

          if [[ -z "$DURATION_SECONDS" ]]; then
            echo "Could not determine video duration." >>"${LOG_FILE}"
            DURATION_SECONDS="0"
          fi
        fi

        if (( $(echo "$DURATION_MINUTES < 1" | bc -l) )); then
          ffmpegthumbnailer -i "$f" -o "$thumbnail" -t 30 -s 640 >> "${LOG_FILE}" 2>&1
        else
          ffmpegthumbnailer -i "$f" -o "$thumbnail" -s 640 >> "${LOG_FILE}" 2>&1
        fi

        # Build final .psm
        if [[ $f == *.pss || $f == *.PSS ]]; then
          pss="$f"
        fi

        if [ -f "$pss" ] && [ -f "$thumbnail" ]; then
          echo
          if ! python3 "${HELPER_DIR}/psmbuild.py" "$pss" "$thumbnail" "$psm" "$base" 2>> "${LOG_FILE}"; then
            echo
            echo "[!] Warning: Skipping video - Failed to encode: $psm" >> "${LOG_FILE}"
            echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} $psm"
            failure=1
            if [[ $f != *.pss && $f != *.PSS ]]; then
              rm -f "$pss"
            fi
            rm -f "$thumbnail"
            continue
          fi
          echo "Created $psm" >> "${LOG_FILE}"
        else
          echo
          echo "[!] Warning: Skipping video - Failed to encode: $psm" >> "${LOG_FILE}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_10]} $psm"
          failure=1
        fi
      fi

      if [[ $f == *.psm || $f == *.PSM ]]; then
        echo
        echo "Copying  $file_name.psm..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[COPYING]} $file_name.psm..."

        #extract title from header
        psm_title=$(
          tail -c +$((0x50 + 1)) "$f" |
          head -c $(( $(grep -abo $'TIM2\x04' "$f" | head -n1 | cut -d: -f1) - 0x50 )) |
          tr -d '\000'
        )

        # Validate UTF-8; fallback to filename if invalid
        if printf '%s' "$psm_title" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && [ -n "$psm_title" ]; then
          movie_title="$psm_title"
        fi

        echo "PSM Movie Title: $movie_title" >> "${LOG_FILE}"

        if ! cp -f "$f" "${STORAGE_DIR}/__contents/contents/video/${MOVIE_DIR}/${database_file}.psm" 2>> "${LOG_FILE}"; then
          echo
          echo "[!] Warning: Skipping video - Failed to copy: $f" >> "${LOG_FILE}"
          echo "${UI_TEXT[WARN_MOVIE_INSTALLER_11]} $f"
          failure=1
        else
          echo
          echo "Created $psm" >> "${LOG_FILE}"
        fi
      fi

      if [ -f "${STORAGE_DIR}/__contents/contents/video/${MOVIE_DIR}/${database_file}.psm" ]; then
        movie_title="${movie_title//\'/\'\'}"
        sed -i "/^COMMIT;/i INSERT INTO sce_movie VALUES('${movie_title}','Your Movies',${MOVIE_DIR},'pfs:/__contents/contents/video/${MOVIE_DIR}/${database_file}.psm','Your Moviespfs:/__contents/contents/video/${MOVIE_DIR}',260,0,0,512);" "${SQL_FILE}" >> "${LOG_FILE}" 2>&1
      fi

      if [[ $f != *.pss && $f != *.PSS ]]; then
        rm -f "$pss"
      fi
      rm -f "$wav" "$ads" "$m2v" "$mux" "$thumbnail" "$BAT_FILE"
    done

    sql_out="$("${SQLITE}" "${TMP_DIR}/movie.db" < "${SQL_FILE}" 2>&1)"

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to create movie database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_3]}"
      return 1
    fi

    if ! cp -f "${TMP_DIR}/movie.db" "${STORAGE_DIR}/__contents/contents/database/movie.db" 2>> "${LOG_FILE}" ||
        ! sudo cp "${TMP_DIR}/movie.db" "${STORAGE_DIR}/__linux.7/database/sqlite/movie.db" 2>> "${LOG_FILE}"
    then
    echo "[X] Error: Failed to copy movie database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_4]}"
      return 1
    fi

    echo
    if [ "$failure" -ne 0 ]; then
      echo "[✓] Movies converted with warnings and database updated." >> "${LOG_FILE}"
      echo "[✓] ${UI_TEXT[MOVIE_INSTALLER_12]}"
    else
      echo "[✓] Movies successfully converted and database updated." >> "${LOG_FILE}"
      echo "[✓] ${UI_TEXT[MOVIE_INSTALLER_13]}"
    fi
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}"
    echo

    clean_up || return 1
  else
    echo "[X] Error: No movies to install." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MOVIE_INSTALLER_5]}"
  fi
}

option_three() {
  echo >> "$LOG_FILE"
  echo "########################### Running Photo Installer ###########################" >> "$LOG_FILE"
  PHOTO_SPLASH

  echo "Photo Path ${MEDIA_DIR}/photo" >> "$LOG_FILE"
  get_display_path

  center_title "${UI_TEXT[PHOTO_INSTALLER_1]}"

  printf '\n  %s\n'    "${UI_TEXT[PHOTO_INSTALLER_2]}"
  printf '  %s\n\n'    "${UI_TEXT[PHOTO_INSTALLER_3]}"
  printf '  %s\n'    "${UI_TEXT[PHOTO_INSTALLER_4]}"
  printf '  %s\n\n'  "${display_path}photo"
  printf "==============================================================================================================\n\n"

  center_text "${UI_TEXT[CONTINUE]}"
  read -n 1 -s -r -p "$text" </dev/tty

  PHOTO_SPLASH

  echo "Contents of photo folder:" >> "${LOG_FILE}"
  find "${MEDIA_DIR}/photo/" -type f >> "${LOG_FILE}"
  echo >> "${LOG_FILE}"

  # Collect top-level photo files
  mapfile -d '' photos < <(
    find "$MEDIA_DIR/photo/" -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \
        -o -iname "*.gif" -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" \
        -o -iname "*.heic" -o -iname "*.heif" \) -print0
  )

  if (( ${#photos[@]} )); then
    echo "Photos found. Processing photos $MEDIA_DIR/photo..." >> "${LOG_FILE}"

    failure=0
    PHOTO_DIR=""
    NEW_DIR="0"
    PFS_PARTITIONS=("__contents")
    PARTITION_NAMES=("__linux.7")
    TMP_DIR="${SCRIPTS_DIR}/tmp"
    SQL_FILE="${TMP_DIR}/photo.sql"

    mkdir -p "$TMP_DIR" || {
        echo "[X] Error: Failed to create folder: $TMP_DIR" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} $TMP_DIR"
        return 1
      }

    mapper_probe
  
    if ! mount_pfs; then
      clean_up
      return 1
    fi

    if ! mount_cfs; then
      clean_up
      return 1
    fi

    if [[ -f  "${STORAGE_DIR}/__linux.7/database/sqlite/photo.db" ]]; then
      sql_out="$("${SQLITE}" "${STORAGE_DIR}/__linux.7/database/sqlite/photo.db" .dump > "${SQL_FILE}" 2>&1)"
    else
      echo "[X] Error: Failed to extract photo database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_PHOTO_INSTALLER_1]}"
      return 1
    fi

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to extract photo database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_PHOTO_INSTALLER_1]}"
      return 1
    fi

    PHOTO_DIR=$(
    awk -F"," '
      /VALUES\(3,0,\047Your Photos\047/ {
        # remove quotes from field 6 (the path)
        path = $6
        gsub(/^'\''|'\''$/, "", path)

        # split by "/" and take last non-empty component
        n = split(path, parts, "/")
        for (i = n; i >= 1; i--) {
          if (parts[i] != "") {
            print parts[i]
            exit
          }
        }
      }
    ' "$SQL_FILE"
    )

    if [[ -z "$PHOTO_DIR" ]]; then
      TIMESTAMP=$(date +"%Y/%m/%d %H:%M:%S"); PHOTO_DIR=${TIMESTAMP//[\/: ]/-}
      NEW_DIR="1"
    fi

    mkdir -p "${STORAGE_DIR}/__contents/contents/photo/${PHOTO_DIR}" || {
      echo "[X] Error: Failed to create folder: $STORAGE_DIR/__contents/contents/video/$PHOTO_DIR" >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_CREATE_FOLDER]} $STORAGE_DIR/__contents/contents/video/$PHOTO_DIR"
      return 1
    }

    # Build sorted array: timestamp | filename
    mapfile -d '' sorted_photos < <(
      for f in "${photos[@]}"; do
        # Extract timestamp
        ts=$(identify -format '%[EXIF:DateTimeOriginal]' "$f" 2>/dev/null)
        [[ -z "$ts" ]] && ts=$(identify -format '%[date:create]' "$f" 2>/dev/null)
        [[ -z "$ts" ]] && ts=$(stat --format '%y' "$f")

        # Extract digits only for sorting
        ts_digits=${ts//[^0-9]/}
        ts_digits=$(printf '%-14s' "$ts_digits" | tr ' ' '0')  # pad if needed

        # Split digits into components
        year=${ts_digits:0:4}; month=${ts_digits:4:2}; day=${ts_digits:6:2}
        hour=${ts_digits:8:2}; min=${ts_digits:10:2}; sec=${ts_digits:12:2}
        timestamp="${year}/${month}/${day} ${hour}:${min}:${sec}"

        # Store: numeric sortable + timestamp + filename
        printf '%s\t%s\t%s\t%s\0' "$ts_digits" "$timestamp" "$f"
      done |
      sort -z -nr | cut -z -f2-  # drop numeric key, keep formatted timestamp + filename
    )

    if [ "$NEW_DIR" = "1" ]; then
      THUMBNAIL="${sorted_photos[-1]##*/}"; THUMBNAIL="${THUMBNAIL%.*}.png"
      echo "Thumbnail: $THUMBNAIL" >> "${LOG_FILE}"
      sed -i "/^COMMIT;/i INSERT INTO sce_photo VALUES(3,0,'Your Photos','Your Photos','pfs:/__contents/contents/photo/${PHOTO_DIR}/${THUMBNAIL}','pfs:/__contents/contents/photo/${PHOTO_DIR}/','$TIMESTAMP',0,'BNIMG-00000',200);" "${SQL_FILE}" >> "${LOG_FILE}" 2>&1
    fi

    for entry in "${sorted_photos[@]}"; do
      IFS=$'\t' read -r timestamp photo <<< "$entry"
      filename=$(basename "$photo")
      name="${filename%.*}"
      TMP_PIC="${TMP_DIR}/${name}.png"
      PNG="${name:0:29}" # Truncate to 29 characters
      PNG="${PNG}.png"
      OUTPUT="${STORAGE_DIR}/__contents/contents/photo/${PHOTO_DIR}/${PNG}"
      DATABASE_FILE="${PNG//\'/\'\'}"
      DATABASE_NAME="${name//\'/\'\'}"

      # Skip if .png already exists
      if [[ -f "$OUTPUT" ]]; then
        echo "Skipping (already processed): ${photo##*/}" >> "${LOG_FILE}"
        echo "${UI_TEXT[PHOTO_INSTALLER_5]} ${photo##*/}"
        continue
      fi

      if convert "$photo[0]" \
        -auto-orient \
        -resize '640x480' \
        -strip \
        -depth 8 \
        -background black \
        -flatten \
        -define png:color-type=2 \
        "$TMP_PIC" 2>>"$LOG_FILE"
      then
        echo "Processed: ${photo##*/}"
        echo "Processed: $photo -> $TMP_PIC" >> "$LOG_FILE"
      fi

      cp "${TMP_PIC}" "${OUTPUT}" >> "${LOG_FILE}" 2>&1

      if [ -f "$OUTPUT" ]; then
        echo "Created $OUTPUT" >> "${LOG_FILE}"
        sed -i "/^COMMIT;/i INSERT INTO sce_photo VALUES(1,0,'$DATABASE_NAME','Your Photos','pfs:/__contents/contents/photo/${PHOTO_DIR}/${DATABASE_FILE}','pfs:/__contents/contents/photo/${PHOTO_DIR}/','$timestamp',0,'BNIMG-00000',200);" "${SQL_FILE}" >> "${LOG_FILE}" 2>&1
      else
        echo "[!] Warning: Failed to process photo: ${photo##*/}" >> "$LOG_FILE"
        echo "${UI_TEXT[WARN_PHOTO_INSTALLER]} ${photo##*/}"
        failure=1
      fi
    done

    tmp_file=$(mktemp)

    awk -F"," '
    BEGIN {
        earliest = ""
        uri = ""
    }
    ############################
    # PASS 1: find earliest URI
    ############################
    FNR==NR {

        if ($0 ~ /^INSERT INTO sce_photo VALUES\(1/) {
            content_uri = $5
            album_name  = $4
            create_date = $7

            gsub(/^'\''|'\''$/, "", content_uri)
            gsub(/^'\''|'\''$/, "", album_name)
            gsub(/^'\''|'\''\);?$/, "", create_date)

            if (album_name != "Your Photos") next
            if (content_uri == "NULL") next

            gsub(/[\/: ]/, "", create_date)

            if (earliest == "" || create_date < earliest) {
                earliest = create_date
                uri = content_uri
            }
        }
        next
    }

    ############################
    # PASS 2: update target row
    ############################
    {
        if ($0 ~ /^INSERT INTO sce_photo VALUES\(3/) {

            album_name = $4
            gsub(/^'\''|'\''$/, "", album_name)

            if (album_name == "Your Photos") {

                # Replace field 5 (content_uri) with new value
                $5 = "'"'"'" uri "'"'"'"

                # Rebuild line
                line = $1
                for (i = 2; i <= NF; i++) {
                    line = line "," $i
                }
                print line
                next
            }
        }

        print
    }
    ' "$SQL_FILE" "$SQL_FILE" > "$tmp_file"

    mv "$tmp_file" "$SQL_FILE" >> "${LOG_FILE}" 2>&1

    sql_out="$("${SQLITE}" "${TMP_DIR}/photo.db" < "${SQL_FILE}" 2>&1)"

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      echo "[X] Error: Failed to create photo database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_PHOTO_INSTALLER_2]}"
      return 1
    fi

    if ! cp -f "${TMP_DIR}/photo.db" "${STORAGE_DIR}/__contents/contents/database/photo.db" 2>> "${LOG_FILE}" ||
        ! sudo cp "${TMP_DIR}/photo.db" "${STORAGE_DIR}/__linux.7/database/sqlite/photo.db" 2>> "${LOG_FILE}"
    then
      echo "[X] Error: Failed to copy photo database." >> "${LOG_FILE}"
      error_msg "${UI_TEXT[ERROR_PHOTO_INSTALLER_3]}"
      return 1
    fi

    echo
    if [ "$failure" -ne 0 ]; then
      echo "[✓] Photos processed with warnings. Database updated." >> "${LOG_FILE}"
      echo "[✓] ${UI_TEXT[PHOTO_INSTALLER_5]}"
    else
      echo "[✓] Photos successfully processed and database updated." >> "${LOG_FILE}"
      echo "[✓] ${UI_TEXT[PHOTO_INSTALLER_6]}"
    fi
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}"
    echo

    clean_up || return 1
  else
    echo "[X] Error: No photos to install." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_PHOTO_INSTALLER_4]}"
  fi
}



option_four() {
  echo >> "$LOG_FILE"
  echo "########################### Set Media Location ###########################" >> "$LOG_FILE"
  while true; do
    LOCATION_SPLASH
    echo "Current Linux Media Folder: $MEDIA_DIR" >> "${LOG_FILE}"
    get_display_path

    printf '\n%s\n\n'    "${UI_TEXT[MEDIA_LOCATION_1]} $display_path"
    read -r -p "${UI_TEXT[MEDIA_LOCATION_2]} " new_path
    echo "Path entered: $new_path" >> "${LOG_FILE}"

    # --- Detect & convert Windows path ---
    if [[ "$new_path" =~ ^[A-Za-z]: ]]; then
      # Convert backslashes to forward slashes
      win_path=$(echo "$new_path" | sed 's#\\#/#g')

      # If there's no slash after the colon (C:Games), insert it
      if [[ "$win_path" =~ ^[A-Za-z]:[^/] ]]; then
          win_path="${win_path:0:2}/${win_path:2}"
      fi

      # Extract drive letter and lowercase it
      drive=$(echo "$win_path" | cut -d':' -f1 | tr '[:upper:]' '[:lower:]')

      # Remove the drive and colon safely
      path_without_drive=$(echo "$win_path" | sed 's#^[A-Za-z]:##')

      # Build Linux path
      new_path="/mnt/$drive$path_without_drive"
    fi
    # -----------------------------------

    if [[ -d "$new_path" ]]; then
        # Remove trailing slash unless it's the root directory
        new_path="${new_path%/}"
        [[ -z "$new_path" ]] && new_path="/"

        MEDIA_DIR="$new_path"
        echo "$MEDIA_DIR" > "$CONFIG_FILE"
        break
    else
        echo
        echo -n "${UI_TEXT[MEDIA_LOCATION_3]}" | tee -a "${LOG_FILE}"
        sleep 3
    fi
  done
  mkdir -p "${MEDIA_DIR}"/{music,movie,photo} &>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create media directories." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MEDIA_LOCATION]}"
    return 1
  }
    get_display_path
    echo
    echo "Linux Media Folder set to: $MEDIA_DIR" >> "${LOG_FILE}"
    echo "${UI_TEXT[MEDIA_LOCATION_4]} $display_path" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}"
}

option_five() {
  echo >> "$LOG_FILE"
  echo "########################### Initialise Music Partition ###########################" >> "$LOG_FILE"

  PARTITION_NAMES=("__linux.7" "__linux.8")

  while true; do
    INI_SPLASH
    center_title "${UI_TEXT[WARNING]}"
    center_text "${UI_TEXT[MUSIC_INI_3]}"
    printf '\n  %s\n\n' "$text"
    printf "==============================================================================================================\n\n"
    read -rp "${UI_TEXT[MUSIC_INI_1]} (y/n): " answer
    case "$answer" in
      [Yy])
          break
          ;;
      [Nn])
          return 0
          ;;
      *)
          echo
          echo -n "${UI_TEXT[MENU_INVALID]}"
          sleep 3
          ;;
    esac
  done

  INI_SPLASH
  mapper_probe

  for path in /dev/mapper/*linux.8*; do
    linux8="$path"
    break
  done
  
  if [ -z "$linux8" ]; then
    echo "[X] Error: Could not find music partition." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INI_1]}"
    return 1
  else
    echo -n "${UI_TEXT[MUSIC_INI_4]}"
  fi

  sudo wipefs -a $linux8 &>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to erase the music partition." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INI_2]}"
    return 1
  }

  sudo mkfs.vfat -F 32 $linux8 &>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create the music filesystem." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INI_3]}"
    return 1
  }

  if ! mount_cfs; then
      clean_up
      return 1
  fi

  sudo mkdir -p "${STORAGE_DIR}/__linux.8/MusicCh/contents" &>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to create music directory." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INI_4]}"
    return 1
  }

  if [ -f "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" ]; then
    sudo cp "${ASSETS_DIR}/music/music.db" "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" &>> "${LOG_FILE}" || {
    echo "[X] Error: Failed to reset music database." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_MUSIC_INI_5]}"
    return 1
    }
  fi

  clean_up || return 1

  INI_SPLASH
  center_title "[✓] ${UI_TEXT[MUSIC_INI_5]}"
  echo
  center_text "${UI_TEXT[MENU_RETURN]}"
  read -n 1 -s -r -p "$text"

}

trap 'echo; exit 130' INT
trap exit_script EXIT

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error_msg "${UI_TEXT[ERROR_LOG]}"
        exit 1
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
echo -n "PSBBN Definitive Project Version: " >> "${LOG_FILE}"
git rev-parse --short HEAD >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "WSL: $wsl" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

MEDIA_SPLASH

if ! sudo rm -rf "${STORAGE_DIR}"; then
    echo "[X] Error: Failed to delete: $STORAGE_DIR" >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_DELETE]} $STORAGE_DIR"
    exit 1
fi

detect_drive
CHECK_PARTITIONS
MOUNT_OPL

psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
lower_bound="2.10"
upper_bound="3.0"

# Version is below 2.10
if [[ "$(printf '%s\n' "$psbbn_version" "$lower_bound" | sort -V | head -n1)" == "$psbbn_version" ]] && \
  [[ "$psbbn_version" != "$lower_bound" ]]; then
  UNMOUNT_OPL
  echo "PSBBN Definitive Patch version is $psbbn_version (below $upper_bound). Please update by selecting 'Install PSBBN from the main menu." >> "${LOG_FILE}"
  error_msg "${UI_TEXT[ERROR_VERSION_3]} ($psbbn_version)" "${UI_TEXT[ERROR_VERSION_4]} ($upper_bound)" " " "${UI_TEXT[ERROR_VERSION_5]}"
  exit 1
    
# Version is >= 2.10 but < 3.0
elif [[ "$(printf '%s\n' "$lower_bound" "$psbbn_version" | sort -V | head -n1)" == "$lower_bound" ]] && \
  [[ "$(printf '%s\n' "$psbbn_version" "$upper_bound" | sort -V | head -n1)" == "$psbbn_version" ]] && \
  [[ "$psbbn_version" != "$upper_bound" ]]; then
  UNMOUNT_OPL
  echo "PSBBN version is $psbbn_version (below $upper_bound). Please update by selecting 'Update PSBBN Software' from the main menu." >> "${LOG_FILE}"
  error_msg "${UI_TEXT[ERROR_VERSION_3]} ($psbbn_version)" "${UI_TEXT[ERROR_VERSION_4]} ($upper_bound)" " " "${UI_TEXT[ERROR_VERSION_6]}"
  exit 1
fi

UNMOUNT_OPL

# Main loop

while true; do
    center_menu
    display_menu
    read -rp "" choice

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
        b|B)
            break
            ;;
        *)  printf "%*s%s " "$((padding - 3))" "" "${UI_TEXT[MENU_INVALID]}"
            sleep 2
            ;;
    esac
done

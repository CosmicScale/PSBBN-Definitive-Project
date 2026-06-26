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

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    # exit 1
fi

clear

TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
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

wsl="$1"
path_arg="$2"

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

# Function to display the menu
display_menu() {
    MEDIA_SPLASH
    cat << "EOF"
                                        1) Install Music

                                        2) Install Movies

                                        3) Install Photos
                                    
                                        4) Set Media Location

                                        5) Initialise Music Partition

                                        b) Back to Main Menu

EOF
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

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        error_msg "[X] Error: Cleanup error(s) occurred. Aborting."
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

error_msg() {
  error_1="$1"
  error_2="$2"
  error_3="$3"
  error_4="$4"

  echo
  echo
  echo "[X] Error: $error_1" | tee -a "${LOG_FILE}"
  echo
  [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
  [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
  [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
  echo
  clean_up
  prevent_sleep_stop
  read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
  echo
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        error_msg "Unable to detect the PS2 drive. Please ensure the drive is properly connected." "You must install PSBBN first before insalling media."
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
            error_msg "Failed to unmount $mount_point. Please unmount manually."
            exit 1
        fi
    done

    if ! sudo "${HDL_DUMP}" toc $DEVICE >> /dev/null 2>&1; then
        error_msg "APA partition is broken on ${DEVICE}."
        exit 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

MOUNT_OPL() {
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    if ! mkdir -p "${OPL}" 2>>"${LOG_FILE}"; then
      error_msg "Failed to create ${OPL}."
      exit 1
    fi

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." >> "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Failed to mount ${DEVICE}3"
        exit 1
    fi
}

UNMOUNT_OPL() {
    echo "Unmounting OPL partition..." >> "${LOG_FILE}"
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        error_msg "Failed to unmount $DEVICE."
        exit 1
    fi
}

CHECK_PARTITIONS() {
    TOC_OUTPUT=$(sudo "${HDL_DUMP}" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        error_msg "APA partition is broken on ${DEVICE}. Install failed."
    fi

    # List of required partitions
    required=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.8 __linux.9 __contents __system __sysconf __.POPS __common)

    # Check all required partitions
    for part in "${required[@]}"; do
        if ! echo "$TOC_OUTPUT" | grep -Fq "$part"; then
            error_msg "PSBBN is not installed. Please install PSBBN to use this feature."
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
              error_msg "Failed to mount the Database." "Before using the Music Installer:" "If you've just upgraded from PSBBN v2.11 or earlier, connect the drive to your PS2 console and boot" "into PSBBN to complete the installation. Then initialise the 'Music Partition' with the Media menu."
              exit 1
            else
              error_msg "Failed to mount the Database." "If you've just upgraded from PSBBN v2.11 or earlier, connect the drive to your PS2 console and boot" "into PSBBN to complete the installation. Then initialise the 'Music Partition' with the Media menu."
              exit 1
            fi
            ;;
          "__linux.8")
            if [ "$arg" = "music" ]; then
              error_msg "Failed to mount the Music partition." "Select 'Initialise Music Partition' from the Media Installer menu, then re-run the Music Installer."
              return 1
            else
              error_msg "Failed to mount the Music partition." "Failed to initialise the Music Partition."
              return 1
            fi
            ;;
        esac
      fi
    else
      error_msg "Partition ${PARTITION_NAME} not found on disk."
      exit 1
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
            error_msg "Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
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
        echo "ps2str_v1.08_2001.zip found in ${ASSETS_DIR}. Extracting..." | tee -a "${LOG_FILE}"
        unzip -o "${ASSETS_DIR}/ps2str_v1.08_2001.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
    else
        echo -n "Downloading required ps2str..." | tee -a "${LOG_FILE}"
        wget --quiet --timeout=10 --tries=3 -O "${ASSETS_DIR}/ps2str_v1.08_2001.zip" https://archive.org/download/ps2str_v1.08_2001/ps2str_v1.08_2001.zip
        echo
        if [[ -s "${ASSETS_DIR}/ps2str_v1.08_2001.zip" ]]; then
            unzip -o "${ASSETS_DIR}/ps2str_v1.08_2001.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
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
  echo "########################################################################################################" >> "$LOG_FILE"
  echo "Running Music Installer" >> "$LOG_FILE"

  MUSIC_SPLASH

  PARTITION_NAMES=("__linux.7" "__linux.8")
  TMP_DIR="${SCRIPTS_DIR}/tmp"

  mkdir -p "${MEDIA_DIR}/music" &>> "${LOG_FILE}" || {
    error_msg "Failed to create music directory."
    return 1
  }

  mkdir -p "${TMP_DIR}" &>> "${LOG_FILE}" || {
    error_msg "Failed to create tmp directory."
    return 1
  }

  get_display_path

  cat << EOF
======================================== Using the Music Installer =========================================

    Supported formats:
    The music installer supports mp3, m4a, flac, and ogg files.

    Place your music files in:
    ${display_path}music

    Note:
    If you encounter any problems, please initialise the music partition from the Media Installer menu.

============================================================================================================
EOF

  echo
  read -n 1 -s -r -p "Press any key to return to continue..."
  echo
  echo

  if find "${MEDIA_DIR}/music" -type f ! -name ".*" \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.flac" -o -iname "*.ogg" \) | grep -q .; then
    echo -n "Preparing to installing music..." | tee -a "${LOG_FILE}"

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
      error_msg "Failed to extract database."
      return 1
    fi

    if ! sudo "${SCRIPTS_DIR}/venv/bin/python" "${HELPER_DIR}/music-installer.py" "${MEDIA_DIR}/music"; then
      error_msg "Failed to convert music."
      return 1
    else
      echo
      echo "[✓] Music successfully converted." >> "${LOG_FILE}"
    fi

    sql_out="$("${SQLITE}" "${TMP_DIR}/music.db" < "${TMP_DIR}/music_reconstructed.sql" 2>&1)"

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      error_msg "Failed to create database."
      return 1
    fi

    if ! sudo mv "${TMP_DIR}/music.db" "${STORAGE_DIR}/__linux.7/database/sqlite/"; then
      error_msg "Failed to install music database."
      return 1
    fi

    clean_up || return 1
    echo
    echo "[✓] Music successfully converted and database updated." | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..."
  else
    error_msg "No music to install."

  fi

}

option_two() {
  echo "########################################################################################################" >> "$LOG_FILE"
  echo "Running Movie Installer" >> "$LOG_FILE"
  MOVIE_SPLASH

  if [[ "$arch" != "x86_64" ]]; then
    error_msg "The movie install requires a x86 processor."
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
        echo "[✓] ps2str successfully extracted." | tee -a "${LOG_FILE}"
    else
      rm "${ASSETS_DIR}/ps2str_v1.08_2001.zip"
      error_msg "Download Failed." "Please check the status of archive.org. You may need to use a VPN depending on your location."
      return 1
    fi  
  fi

  MOVIE_SPLASH

  chmod +x "$PS2STR"
  echo "Movie Path ${MEDIA_DIR}/movie" >> "$LOG_FILE"
  get_display_path

  cat << EOF

======================================== Using the Movie Installer =========================================

    Supported formats:
    The movie installer supports most common video formats including mp4, m4v, mkv, and vob, as well as
    the PlayStation 2 video formats pss and psm.

    Place your movie files in:
    ${display_path}movie

============================================================================================================

EOF
  read -n 1 -s -r -p "                                   Press any key to return to continue..."
  MOVIE_SPLASH

  # Collect movie files (case-insensitive, no hidden files, top-level only)
  mapfile -d '' movies < <(
    find "${MEDIA_DIR}/movie" -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.mkv" \
        -o -iname "*.avi" -o -iname "*.webm" -o -iname "*.mpg" -o -iname "*.mpeg"\
        -o -iname "*.vob" -o -iname "*.ts" -o -iname "*.m2ts" -o -iname "*.mts" \
        -o -iname "*.ogv" -o -iname "*.pss" -o -iname "*.psm" \) -print0
  )

  if (( ${#movies[@]} )); then
    echo "Movies found. Processing movies ${display_path}movie..." | tee -a "${LOG_FILE}"

    if [ -n "$IN_NIX_SHELL" ]; then
      echo "Running in Nix environment - packages should be provided by flake." >> "${LOG_FILE}"
    else
      echo "Activating Python virtual environment..." >> "${LOG_FILE}"
      # Try activating the virtual environment twice before failing
      if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
        echo -n "Failed to activate the Python virtual environment. Retrying..." | tee -a "${LOG_FILE}"
        sleep 2
        echo | tee -a "${LOG_FILE}"
    
        if ! source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}"; then
          error_msg "Error" "Failed to activate the Python virtual environment."
          return 1
        fi
      fi
    fi

    failure=0
    MOVIE_DIR=""
    PFS_PARTITIONS=("__contents")
    PARTITION_NAMES=("__linux.7")
    TMP_DIR="${MEDIA_DIR}/movie/tmp"
    SQL_FILE="${TMP_DIR}/movie.sql"

    mkdir -p "$TMP_DIR" || { error_msg "Failed to create $TMP_DIR"; return 1; }
    cd "$TMP_DIR" || { error_msg "Failed to change directory to $TMP_DIR"; return 1; }

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
      error_msg "Failed to extract movie database."
      return 1
    fi

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      error_msg "Failed to extract database."
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
      error_msg "Failed to create $STORAGE_DIR/__contents/contents/video/$MOVIE_DIR"
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
        echo "Skipping (already processed): ${f##*/}" | tee -a "${LOG_FILE}"
        continue
      fi

      # if not .psm or .pss file
      if [[ $f != *.pss && $f != *.psm && $f != *.PSS && $f != *.PSM ]]; then
          movie_space_check

        if [ "$local_space" = "1" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "Warning: Not enough local storage space to convert ${f##*/}." | tee -a "${LOG_FILE}"
          echo "Need $(format_size "$TOTAL_ROUNDED"), but only $(format_size "$AVAILABLE_LOCAL_MB") available." | tee -a "${LOG_FILE}"
          failure=1
          continue
        else
          echo
          echo "Sufficient local free space available." >> "${LOG_FILE}"
        fi

        if [ "$ps2_space" = "1" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "Warning: Not enough PS2 storage space to convert ${f##*/}." | tee -a "${LOG_FILE}"
          echo "Need $(format_size "$VIDEO_ESTIMATED_SIZE_ROUNDED"), but only $(format_size "$AVAILABLE_STORAGE_MB") available." | tee -a "${LOG_FILE}"
          failure=1
          continue
        else
          echo "Sufficient free space available on PS2 storage." >> "${LOG_FILE}"
        fi

        if [ "$ps2_space" = "2" ]; then
          echo | tee -a "${LOG_FILE}"
          echo "Warning: ${f##*/} might be too long." | tee -a "${LOG_FILE}"
          echo "The recommended maximum video length is approximately 2h 15m."
          echo "The video will be converted at a low bitrate and may fail to convert." | tee -a "${LOG_FILE}"
          echo
          while true; do
            read -p "Convert the video anyway? (y/n):" CONVERT
            case "$CONVERT" in
            [Yy])
                break
                ;;
            [Nn])
                echo "Skipping: ${f##*/}" | tee -a "${LOG_FILE}"
                continue 2
                ;;
            *)
                echo
                echo "Please enter y or n."
                ;;
            esac
          done
        else
          echo "Video not too long." >> "${LOG_FILE}"
        fi

        echo "Processing: ${f##*/}" | tee -a "${LOG_FILE}"

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
          echo "Input is progressive → encoding progressive" | tee -a "${LOG_FILE}"
        else
          interlace_opts="-flags +ilme+ildct -top 1"
          echo "Input is interlaced → encoding interlaced" | tee -a "${LOG_FILE}"
        fi

        echo "Encoding video at $bitrate kbps" | tee -a "${LOG_FILE}"
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
          echo "Warning: The file $file_name.psm will be larger than 2048 MiB" | tee -a "${LOG_FILE}"
          bitrate=$((bitrate - 200))
          echo "Re-encoding at $bitrate kbps" | tee -a "${LOG_FILE}"
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
              echo "Warning: Skipping video - file $file_name.psm larger than 2048 MiB" | tee -a "${LOG_FILE}"
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
            echo "Warning: Skipping video - Failed to encode $ads" | tee -a "${LOG_FILE}"
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
          echo "Warning: Skipping video - Failed to convert ${f##*/} with ffmpeg." | tee -a "${LOG_FILE}"
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

        echo -n "Encoding $file_name.pss..." | tee -a "${LOG_FILE}"
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
            echo "Warning: Skipping video - Failed to create $pss" | tee -a "${LOG_FILE}"
            failure=1
            rm -f "$ads" "$m2v" "$mux" "$pss" "$BAT_FILE"
            continue
          fi
        else
          if ! "${PS2STR}" mux -v "$mux" >> "${LOG_FILE}" 2>&1; then
            echo
            echo "Warning: Skipping video - Failed to create $pss" | tee -a "${LOG_FILE}"
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
            echo "Warning: Skipping video - Failed to create $psm" | tee -a "${LOG_FILE}"
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
          echo "Warning: Skipping video - Failed to create $psm"| tee -a "${LOG_FILE}"
          failure=1
        fi
      fi

      if [[ $f == *.psm || $f == *.PSM ]]; then
        echo
        echo -n "Copying $file_name.psm..."

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
          echo "Warning: Skipping video - Failed to copy $f"| tee -a "${LOG_FILE}"
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
      error_msg "Failed to create database."
      return 1
    fi

    if ! cp -f "${TMP_DIR}/movie.db" "${STORAGE_DIR}/__contents/contents/database/movie.db" 2>> "${LOG_FILE}" ||
        ! sudo cp "${TMP_DIR}/movie.db" "${STORAGE_DIR}/__linux.7/database/sqlite/movie.db" 2>> "${LOG_FILE}"
    then
      error_msg "Failed to copy database."
      return 1
    fi

    echo
    if [ "$failure" -ne 0 ]; then
      echo "[✓] Movies converted with warnings and database updated." | tee -a "${LOG_FILE}"
    else
      echo "[✓] Movies successfully converted and database updated." | tee -a "${LOG_FILE}"
    fi
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..."
    echo

    # Deactivate the virtual environment
    if [[ -n "$VIRTUAL_ENV" ]]; then
      deactivate
    fi

    clean_up || return 1
  else
    error_msg "No movies to install." | tee -a "${LOG_FILE}"
  fi
}

option_three() {
  echo "########################################################################################################" >> "$LOG_FILE"
  echo "Running Photo Installer" >> "$LOG_FILE"
  PHOTO_SPLASH

  echo "Photo Path ${MEDIA_DIR}/photo" >> "$LOG_FILE"
  get_display_path

  cat << EOF

======================================== Using the Photo Installer =========================================

    Supported formats:
    The photo installer supports most common image formats including jpg, png, tif, gif, and bmp

    Place your photos files in:
    ${display_path}photo

============================================================================================================

EOF
  read -n 1 -s -r -p "                                   Press any key to return to continue..."
  PHOTO_SPLASH

  # Collect top-level photo files
  mapfile -d '' photos < <(
    find "$MEDIA_DIR/photo" -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \
        -o -iname "*.gif" -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" \
        -o -iname "*.heic" -o -iname "*.heif" \) -print0
  )

  if (( ${#photos[@]} )); then
    echo "Photos found. Processing photos $MEDIA_DIR/photo..." | tee -a "${LOG_FILE}"

    failure=0
    PHOTO_DIR=""
    NEW_DIR="0"
    PFS_PARTITIONS=("__contents")
    PARTITION_NAMES=("__linux.7")
    TMP_DIR="${SCRIPTS_DIR}/tmp"
    SQL_FILE="${TMP_DIR}/photo.sql"

    mkdir -p "$TMP_DIR" || { error_msg "Failed to create $TMP_DIR"; return 1; }

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
      error_msg "Failed to extract photo database."
      return 1
    fi

    if [[ -n $sql_out ]]; then
      printf '%s\n' "$sql_out" >> "${LOG_FILE}"
      error_msg "Failed to extract database."
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
      error_msg "Failed to create $STORAGE_DIR/__contents/contents/video/$PHOTO_DIR"
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
        echo "Skipping (already processed): ${photo##*/}" | tee -a "${LOG_FILE}"
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
      else
        echo "Warning: Failed to process ${photo##*/}" | tee -a "$LOG_FILE"
      fi

      cp "${TMP_PIC}" "${OUTPUT}" >> "${LOG_FILE}" 2>&1

      if [ -f "$OUTPUT" ]; then
        echo "Created $OUTPUT" >> "${LOG_FILE}"
        sed -i "/^COMMIT;/i INSERT INTO sce_photo VALUES(1,0,'$DATABASE_NAME','Your Photos','pfs:/__contents/contents/photo/${PHOTO_DIR}/${DATABASE_FILE}','pfs:/__contents/contents/photo/${PHOTO_DIR}/','$timestamp',0,'BNIMG-00000',200);" "${SQL_FILE}" >> "${LOG_FILE}" 2>&1
      else
        echo "Warning: Skipping photo - Failed to process ${photo##*/}"
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
      error_msg "Failed to create database."
      return 1
    fi

    if ! cp -f "${TMP_DIR}/photo.db" "${STORAGE_DIR}/__contents/contents/database/photo.db" 2>> "${LOG_FILE}" ||
        ! sudo cp "${TMP_DIR}/photo.db" "${STORAGE_DIR}/__linux.7/database/sqlite/photo.db" 2>> "${LOG_FILE}"
    then
      error_msg "Failed to copy database."
      return 1
    fi

    echo
    if [ "$failure" -ne 0 ]; then
      echo "[✓] Photos processed with warnings. Database updated." | tee -a "${LOG_FILE}"
    else
      echo "[✓] Photos successfully processed and database updated." | tee -a "${LOG_FILE}"
    fi
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..."
    echo

    clean_up || return 1
  else
    error_msg "No photos to process." | tee -a "${LOG_FILE}"
  fi
}

option_four() {
  while true; do
    LOCATION_SPLASH
    get_display_path
    echo
    echo
    echo "Current Linux Media Folder: $MEDIA_DIR" >> "${LOG_FILE}"
    echo "Current Media Folder: $display_path" | tee -a "${LOG_FILE}"
    echo
    read -r -p "Enter new path for media folder: " new_path

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
        echo -n "Invalid path. Please try again." | tee -a "${LOG_FILE}"
        sleep 3
    fi
  done
  mkdir -p "${MEDIA_DIR}"/{music,movie,photo} &>> "${LOG_FILE}" || {
    error_msg "Failed to create media directories."
    return 1
  }
    get_display_path
    echo
    echo "Linux Media Folder set to: $MEDIA_DIR" >> "${LOG_FILE}"
    echo "Media path set to $display_path" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..."
}

option_five() {

  PARTITION_NAMES=("__linux.7" "__linux.8")

  while true; do
    INI_SPLASH
    echo "                    Do you want to initialise the Music Partition?" | tee -a "${LOG_FILE}"
    echo
    echo "                    ============================ WARNING ==============================="
    echo
    echo "                    Initialising the Music Partition will erase all existing music data." | tee -a "${LOG_FILE}"
    echo
    echo "                    ===================================================================="   
    echo
    read -p "                     Are you sure? (y/n): " answer
    case "$answer" in
      [Yy])
          break
          ;;
      [Nn])
          return 0
          ;;
      *)
          echo
          echo -n "                     Please enter y or n."
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
    error_msg "Could not find music partition."
    return 1
  else
    echo -n "Initialising music partition..."
  fi

  sudo wipefs -a $linux8 &>> "${LOG_FILE}" || {
    error_msg "Failed to erase the music partition."
    return 1
  }

  sudo mkfs.vfat -F 32 $linux8 &>> "${LOG_FILE}" || {
    error_msg "Failed to create the music filesystem."
    return 1
  }

  if ! mount_cfs; then
      clean_up
      return 1
  fi

  sudo mkdir -p "${STORAGE_DIR}/__linux.8/MusicCh/contents" &>> "${LOG_FILE}" || {
    error_msg "Failed to create music directory."
    return 1
  }

  if [ -f "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" ]; then
    sudo cp "${ASSETS_DIR}/music/music.db" "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" &>> "${LOG_FILE}" || {
    error_msg "Failed to reset music database."
    return 1
    }
  fi

  clean_up || return 1

  echo
  echo
  echo "[✓] The music partitions has been successfully initialisied."
  echo
  read -n 1 -s -r -p "Press any key to return to the menu..."

}

trap 'echo; exit 130' INT
trap exit_script EXIT

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo
        echo "Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to return to the menu..."
        echo
        exit 1
    fi
fi

# Source unattended configuration if present
UNATTENDED_CONF="${TOOLKIT_PATH}/psbbn-unattended.conf"
if [[ -f "$UNATTENDED_CONF" ]]; then
    source "$UNATTENDED_CONF"
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "WSL: $wsl" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

MEDIA_SPLASH

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
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
  error_msg "PSBBN Definitive Patch version is $psbbn_version (below $upper_bound)." "Please update by selecting 'Install PSBBN from the main menu."
  exit 1
    
# Version is >= 2.10 but < 3.0
elif [[ "$(printf '%s\n' "$lower_bound" "$psbbn_version" | sort -V | head -n1)" == "$lower_bound" ]] && \
  [[ "$(printf '%s\n' "$psbbn_version" "$upper_bound" | sort -V | head -n1)" == "$psbbn_version" ]] && \
  [[ "$psbbn_version" != "$upper_bound" ]]; then
  UNMOUNT_OPL
  error_msg "PSBBN version is $psbbn_version (below $upper_bound)." "Please update by selecting 'Update PSBBN Software' from the main menu."
  exit 1
fi

UNMOUNT_OPL

if ! command -v dmsetup &>/dev/null; then
  error_msg "Please run the setup script to install dependencies before using this script."
  exit 1
fi

# Main loop

while true; do
    display_menu
    read -p "                                        Select an option: " choice

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
        *)
            echo
            echo -n "                                        Invalid option, please try again."
            sleep 2
            ;;
    esac
done
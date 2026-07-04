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

export LC_ALL=en_US.UTF-8

clear

TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
MEDIA_DIR="${TOOLKIT_PATH}/media"
TMP_DIR="${SCRIPTS_DIR}/tmp"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/media.log"
CONFIG_FILE="${TOOLKIT_PATH}/scripts/media.cfg"

PARTITION_NAMES=("__linux.7" "__linux.8")

path_arg="$1"

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

MUSIC_SPLASH() {
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

# Function to display the menu
display_menu() {
    MUSIC_SPLASH
    cat << "EOF"
 


                                    1) Install Music
                                    
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
	for PARTITION_NAME in "${PARTITION_NAMES[@]}"; do
    	MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
    	sudo umount "${MOUNT_PATH}" 2>/dev/null
  	done
  	if [ -n "${DEVICE_CUT}" ]; then
    	existing_maps=$(sudo dmsetup ls | grep -o "^${DEVICE_CUT}-[^ ]*" || true)
    	for map in $existing_maps; do
      		sudo dmsetup remove "$map" 2>/dev/null
    	done
  	fi

    sudo rm -rf "${TMP_DIR}" 2>>"$LOG_FILE" \
        || { error_msg "Cleanup failed. See ${LOG_FILE} for details."; exit 1; }
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
        error_msg "Unable to detect the PS2 drive. Please ensure the drive is properly connected." "If this is your first time using the installer, select 'Install PSBBN' from the main menu."
        exit 1
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

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
            exit 1
        fi
    done

    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc $DEVICE >> /dev/null 2>&1; then
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
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Failed to mount ${DEVICE}3"
        exit 1
    fi
}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        error_msg "Failed to unmount $DEVICE."
        exit 1
    fi
}

mapper_probe() {
  DEVICE_CUT=$(basename "${DEVICE}")
  existing_maps=$(sudo dmsetup ls | grep -o "^${DEVICE_CUT}-[^ ]*" || true)
  for map in $existing_maps; do
    sudo dmsetup remove "$map" 2>/dev/null
  done
  sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" --dm | sudo dmsetup create --concise
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

option_one() {
  clear

  cat << "EOF"
                  ___  ___          _        _____          _        _ _           
                  |  \/  |         (_)      |_   _|        | |      | | |          
                  | .  . |_   _ ___ _  ___    | | _ __  ___| |_ __ _| | | ___ _ __ 
                  | |\/| | | | / __| |/ __|   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                  | |  | | |_| \__ \ | (__   _| || | | \__ \ || (_| | | |  __/ |   
                  \_|  |_/\__,_|___/_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|   


EOF

  if [[ ! -d "${MEDIA_DIR}" ]]; then
    MEDIA_DIR="${TOOLKIT_PATH}/media"
  fi

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
Supported formats:
The music installer supports mp3, m4a, flac, and ogg files.

Music location:
Place your music files in:
${display_path}music

Note:
If you encounter any problems, please initialise the music partition from the Media Installer menu.
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

    if [ -f "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" ]; then
      "${HELPER_DIR}/sqlite" "${STORAGE_DIR}/__linux.7/database/sqlite/music.db" .dump > "${TMP_DIR}/music_dump.sql"
    fi

    if ! sudo "${SCRIPTS_DIR}/venv/bin/python" "${HELPER_DIR}/music-installer.py" "${MEDIA_DIR}/music"; then
      error_msg "Failed to convert music."
      return 1
    else
      echo
      echo "[✓] Music successfully converted." >> "${LOG_FILE}"
    fi

    if ! "${HELPER_DIR}/sqlite" "${TMP_DIR}/music.db" < "${TMP_DIR}/music_reconstructed.sql"; then
      error_msg "Failed to create music.db" | tee -a "${LOG_FILE}"
      return 1
    fi

    if ! sudo mv "${TMP_DIR}/music.db" "${STORAGE_DIR}/__linux.7/database/sqlite/"; then
      error_msg "Failed to install music database."
      return 1
    fi

    clean_up
    echo
    echo "[✓] Music successfully converted and database updated." | tee -a "${LOG_FILE}"
    echo
    read -p "Press any key to return to the menu..."
  else
    error_msg "No music to install."

  fi

}

option_two() {
exit
}

option_three() {
exit
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
    read -p "Enter new path for media folder: " new_path

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
  mkdir -p "${MEDIA_DIR}/music" &>> "${LOG_FILE}" || {
    error_msg "Failed to create music directory."
    return 1
  }
    get_display_path
    echo
    echo "Linux Media Folder set to: $MEDIA_DIR" >> "${LOG_FILE}"
    echo "Media path set to $display_path" | tee -a "${LOG_FILE}"
    echo
    read -p "Press any key to return to the menu..."
}

option_five() {

  while true; do
    INI_SPLASH
    echo "                Do you want to initialise the Music Partition?" | tee -a "${LOG_FILE}"
    echo
    echo "                ============================ WARNING ==============================="
    echo
    echo "                Initialising the Music Partition will erase all existing music data." | tee -a "${LOG_FILE}"
    echo
    echo "                ===================================================================="   
    echo
    read -p "                 Are you sure? (y/n): " answer
    case "$answer" in
      [Yy])
          break
          ;;
      [Nn])
          return 0
          ;;
      *)
          echo
          echo -n "                 Please enter y or n."
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

  clean_up

  echo
  echo
  echo "[✓] The music partitions has been successfully initialisied."
  echo
  read -p "Press any key to return to the menu..."

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

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
fi

detect_drive
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
    read -p "                                    Select an option: " choice

    case $choice in
        1)
            option_one
            ;;
#        2)
#            option_two
#            ;;
#        3)
#            option_three
#            ;;
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
            echo -n "                                    Invalid option, please try again."
            sleep 2
            ;;
    esac
done
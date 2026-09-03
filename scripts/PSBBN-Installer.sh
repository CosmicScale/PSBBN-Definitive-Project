#!/usr/bin/env bash
#
# PSBBN Installer form the PSBBN Definitive Project
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

version_check="2.10"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    case " $ID $ID_LIKE " in
        *" fedora "*)
            version_check="3.00"
            ;;
    esac
fi

# Set paths
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
HELPER_DIR="${SCRIPTS_DIR}/helper"
LANG_DIR="${ASSETS_DIR}/lang"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
SYSCONF_XML="${SCRIPTS_DIR}/tmp/sysconf.xml"
OPL="${SCRIPTS_DIR}/OPL"
arch="$(uname -m)"

URL="https://archive.org/download/psbbn-definitive-patch-v4.1"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/PSU Extractor.elf"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/aarch64/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/aarch64/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/aarch64/PSU Extractor.elf"
fi

case "$1" in
  -install)
    MODE="install"
    OS="PSBBN"
    ;;
  -update)
    MODE="update"
    ;;
  *)
    echo "Usage: $0 -install | -update"
    exit 1
    ;;
esac

shift  # remove first arg

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

center_text() {
    local input="$1"

    local display_width
    display_width=$(text_width "$input")

    local padding=$(( (term_width - display_width) / 2 ))

    (( padding < 0 )) && padding=0

    text=$(printf "%*s%s" "$padding" "" "$input")
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

if [ "$MODE" = "install" ]; then
    LOG_FILE="${TOOLKIT_PATH}/logs/PSBBN-installer.log"
else
    LOG_FILE="${TOOLKIT_PATH}/logs/update.log"
fi

if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")

    if [ "$size" -gt 4194304 ]; then
        : > "$LOG_FILE"
    fi
fi

version_le() { # returns 0 (true) if $1 < $2
    [ "$1" = "$2" ] && return 1
    smallest=$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)
    [ "$smallest" = "$1" ]
}

if [ "$MODE" = "install" ]; then
    LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.6" "__linux.7" "__linux.8" "__linux.9" )
    PFS_PARTITIONS=("__contents" "__system" "__sysconf" "__common" )
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

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    local exit_code

    # Print initial spinner
    echo
    printf "\r[%c] %s" "${spinstr:0:1}" "$message"

    # Animate while the process is running
    while kill -0 "$pid" 2>/dev/null; do
        for i in {0..3}; do
            printf "\r[%c] %s" "${spinstr:i:1}" "$message"
            sleep $delay
        done
    done

    # Wait for the process to capture its exit code
    wait "$pid"
    exit_code=$?

    # Replace spinner with success/failure
    if [ $exit_code -eq 0 ]; then
        printf "\r[✓] %s\n" "$message"
    else
        printf "\r[X] %s\n" "$message"
    fi
}

clean_up() {
    failure=0

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

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo "[X] Error: Cleanup error(s) occurred. Aborting." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_CLEANUP]}"
    fi

    # Clean up directories and temp files
    sudo rm -rf /tmp/{apa_header_checksum.bin,apa_header_full.bin,apajail_magic_number.bin,apa_index.xz,gpt_2nd.xz} >> "${LOG_FILE}" 2>&1
    sudo rm -f "$HTML_FILE"
    sudo rm -rf "${SCRIPTS_DIR}/tmp"    
    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo "[X] Error: Cleanup error(s) occurred. Aborting." >> "$LOG_FILE"
        error_msg "${UI_TEXT[ERROR_CLEANUP]}"
    fi
}

exit_script() {
    UNMOUNT_ALL
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

get_latest_file() {
    local prefix="$1"        # e.g., "psbbn-eng" or "psbbn-definitive-patch"
    local display="$2"       # e.g., "English language pack"
    local remote_list remote_versions remote_version
    local local_file local_version

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
        echo | tee -a "${LOG_FILE}"
        echo "Found $display version $remote_version" >> "${LOG_FILE}"
        echo "${UI_TEXT[GET_LATEST_FILE_1]} $display $remote_version"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Could not find the latest version of the $display." >> "${LOG_FILE}"
        echo "${UI_TEXT[GET_LATEST_FILE_2]} $display."
        echo "${UI_TEXT[GET_LATEST_FILE_3]}"
    fi

   # Check if any local file is newer than the remote version
    local_file=$(ls "${ASSETS_DIR}/${prefix}"*.tar.gz 2>/dev/null | sort -V | tail -n1)
    if [[ -n "$local_file" ]]; then
        local_version=$(basename "$local_file" | sed -E 's/.*-v([0-9.]+)\.tar\.gz/\1/')
    fi

    #Decide which file wins
    if [[ -n "$local_file" ]]; then
        if [[ -z "$remote_version" ]] || \
           [[ "$(printf '%s\n' "$remote_version" "$local_version" | sort -V | tail -n1)" == "$local_version" ]]; then

            # Local is equal/newer then local wins
            LATEST_FILE=$(basename "$local_file")
            echo "Newer local file found: ${LATEST_FILE}" >> "${LOG_FILE}"
            echo "${UI_TEXT[GET_LATEST_FILE_4]} ${LATEST_FILE}"

            if [[ "$prefix" == "psbbn-definitive-patch" ]]; then
                LATEST_VERSION="$local_version"
            elif [[ "$prefix" == "language-pak-$lang" ]]; then
                LATEST_LANG="$local_version"
            elif [[ "$prefix" == "channels-$lang" ]]; then
                LATEST_CHAN="$local_version"
            fi
            return 0
        fi
    fi

    # Remote exists and is newer then remote wins
    if [[ -n "$remote_version" ]]; then
        LATEST_FILE="${prefix}-v${remote_version}.tar.gz"

        if [[ "$prefix" == "psbbn-definitive-patch" ]]; then
            LATEST_VERSION="$remote_version"
        elif [[ "$prefix" == "language-pak-$lang" ]]; then
            LATEST_LANG="$remote_version"
        elif [[ "$prefix" == "channels-$lang" ]]; then
            LATEST_CHAN="$remote_version"
        fi
        return 0
    fi

    # If neither version exists error
    echo "[X] Error: Failed to find ${display}." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_GET_LATEST_FILE]} ${display}."
}

downoad_latest_file() {
    local prefix="$1"
    # Check if the latest file exists in ${ASSETS_DIR}
    if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "${LATEST_FILE} already exists. Skipping download." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLOAD_LATEST_FILE_1]}"
    else
        # Check for and delete older files
        for file in "${ASSETS_DIR}"/$prefix*.tar.gz; do
            if [[ -f "$file" && "$(basename "$file")" != "$LATEST_FILE" ]]; then
                echo "Deleting old file: $file" >> "${LOG_FILE}"
                rm -f "$file"
            fi
        done

        # Construct the full URL for the .gz file and download it
        TAR_URL="$URL/$LATEST_FILE"
        echo "Downloading ${LATEST_FILE}..." >> "${LOG_FILE}"
        echo "${UI_TEXT[DOWNLOAD_LATEST_FILE_2]}"
        axel -n 8 -a "$TAR_URL" -o "${ASSETS_DIR}"

        # Check if the file was downloaded successfully
        if [[ -f "${ASSETS_DIR}/${LATEST_FILE}" && ! -f "${ASSETS_DIR}/${LATEST_FILE}.st" ]]; then
            echo "Download completed: ${LATEST_FILE}" >> "${LOG_FILE}"
            echo "${UI_TEXT[DOWNLOAD_LATEST_FILE_3]} ${LATEST_FILE}"
        else
            echo "[X] Error: Download failed for ${LATEST_FILE}." "Please check your internet connection and try again." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_LATEST_FILE_1]} ${LATEST_FILE}." "${UI_TEXT[GET_LATEST_FILE_3]}"
        fi
    fi

}

PFS_COMMANDS() {
    PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
    if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
        echo "[X] Error: PFS Shell returned an error." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_PFS_COMMANDS]}"
    fi
}

mapper_probe() {
    DEVICE_CUT=$(basename "${DEVICE}")

    # 1) Remove existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v p="^${DEVICE_CUT}-" '$1 ~ p {print $1}')
    for map in $existing_maps; do
        sudo dmsetup remove "$map" 2>/dev/null
    done

    # 2) Build keep list
    keep_partitions=( "${LINUX_PARTITIONS[@]}" "${PFS_PARTITIONS[@]}" )
    if [ "$MODE" = "install" ]; then
        keep_partitions+=("__linux.2")
    fi

    # 3) Get HDL Dump --dm output, split semicolons into lines
    dm_output=$(sudo "${HDL_DUMP}" toc "${DEVICE}" --dm | tr ';' '\n')

    # 4) Create each kept partition individually
    while IFS= read -r line; do
        for part in "${keep_partitions[@]}"; do
            if [[ "$line" == "${DEVICE_CUT}-${part},"* ]]; then
                echo "$line" | sudo dmsetup create --concise | tee -a "${LOG_FILE}"
                break
            fi
        done
    done <<< "$dm_output"

    # 5) Export base mapper path
    MAPPER="/dev/mapper/${DEVICE_CUT}-"
}

mount_cfs() {
    for PARTITION_NAME in "${LINUX_PARTITIONS[@]}"; do
        MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
        if [ -e "${MAPPER}${PARTITION_NAME}" ]; then
            if [ "$MODE" = "update" ]; then
                if [[ "$PARTITION_NAME" =~ ^__linux\.(6|7|9)$ ]]; then
                    echo "Skipping mke2fs for $PARTITION_NAME" >>"${LOG_FILE}"
                elif [[ "$PARTITION_NAME" =~ ^__linux\.(1|4|5)$ ]] && ! version_le "${psbbn_version:-0}" "3.00"; then
                    echo "Skipping mke2fs for $PARTITION_NAME" >>"${LOG_FILE}"
                else
                    echo "Formatting $PARTITION_NAME" >>"${LOG_FILE}"
                    if ! sudo mke2fs -t ext2 -b 4096 -I 128 -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode "${MAPPER}${PARTITION_NAME}" >>"${LOG_FILE}" 2>&1; then
                        echo "[X] Error: Failed to create filesystem ${PARTITION_NAME}." >> "${LOG_FILE}"
                        error_msg "${UI_TEXT[ERROR_MOUNT_1]} ${PARTITION_NAME}."
                    fi
                fi
            fi

            if [[ "$PARTITION_NAME" = "__linux.8" ]]; then
                echo "Formatting $PARTITION_NAME" >>"${LOG_FILE}"
                if ! sudo mkfs.vfat -F 32 "${MAPPER}${PARTITION_NAME}" >>"${LOG_FILE}" 2>&1; then
                    echo "[X] Error: Failed to create filesystem ${PARTITION_NAME}." >> "${LOG_FILE}"
                    error_msg "${UI_TEXT[ERROR_MOUNT_1]} ${PARTITION_NAME}."
                fi
            fi
            
            [ -d "${MOUNT_PATH}" ] || mkdir -p "${MOUNT_PATH}"
                sleep 2
                if [[ "$PARTITION_NAME" = "__linux.7" ]] && [ "$MODE" = "update" ]; then
                    echo echo "Skipping mount for __linux.7" >> "${LOG_FILE}"
                elif [[ "$PARTITION_NAME" = "__linux.9" ]] && [ "lang" != "jpn" ]; then
                    echo echo "Skipping mount for __linux.9" >> "${LOG_FILE}"
                else
                    echo "Mounting $PARTITION_NAME" >>"${LOG_FILE}"
                    if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >> "${LOG_FILE}" 2>&1; then
                        echo "[X] Error: Failed to mount ${PARTITION_NAME}" "${LOG_FILE}"
                        error_msg "${UI_TEXT[ERROR_MOUNT_2]} ${PARTITION_NAME}"
                    fi
                fi
        else
            echo "[X] Error: Partition not found on disk: ${PARTITION_NAME}" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_MOUNT_3]} ${PARTITION_NAME}"
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
    TOC_OUTPUT=$(sudo "${HDL_DUMP}" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "[X] Error: APA partition is broken. Install failed." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CHECK_PARTITIONS_1]}"
    fi

    # List of required partitions
    required=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.8 __linux.9 __contents __system __sysconf __common)

    # Check all required partitions
    for part in "${required[@]}"; do
        if ! echo "$TOC_OUTPUT" | grep -Fq "$part"; then
            echo "[X] Error: Some partitions are missing." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_CHECK_PARTITIONS_2]}"
        fi
    done
}

CHECK_OS() {

    # only grab the partition name column from lines that begin with 0x0100 or 0x0001
    mapfile -t names < <(grep -E '^0x0[01][0-9A-Fa-f]{2}' "${hdl_output}" | awk '{print $NF}')

    has_all() {
        local targets=("$@")
        for t in "${targets[@]}"; do
            local found=false
            for n in "${names[@]}"; do
                if [[ "$n" == "$t" ]]; then
                    found=true
                    break
                fi
            done
            # If any required partition is missing, return failure immediately
            $found || return 1
        done
        return 0  # all partitions found
        }

    psbbn_parts=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.8 __linux.9 __contents)
    hosd_parts=(__system __sysconf __common)

    if has_all "${psbbn_parts[@]}"; then
        echo "PSBBN Detected" >> "${LOG_FILE}"
        OS="PSBBN"
    elif has_all "${hosd_parts[@]}"; then
        echo "HOSDMenu Detected" >> "${LOG_FILE}"
        OS="HOSD"
    else
        echo "[X] Error: Failed to detect PSBBN or HOSDMenu on ${DEVICE}." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_CHECK_OS]} ${DEVICE}."
    fi

}

UNMOUNT_ALL() {
    while IFS= read -r mount_point; do
        [[ -z "$mount_point" ]] && continue

        echo "Unmounting $mount_point..." >> "${LOG_FILE}"

        sudo umount -- "$mount_point" \
            && echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}" || {
                echo "[X] Error: Failed to unmount $mount_point." >> "${LOG_FILE}"
                error_msg "${UI_TEXT[ERROR_UNMOUNT_1]} $mount_point."
            }
    done < <(lsblk -ln -o MOUNTPOINT "$DEVICE")

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

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        echo "Removing existing mapper $map_name..." >> "$LOG_FILE"
        if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
            echo "[X] Error: Failed to delete mapper $map_name." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_UNMOUNT_2]} $map_name."
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
        echo "[X] Error: Failed to create ${OPL}." >> "${LOG_FILE}"
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

INSTALL_SPLASH(){
    clear
        cat << "EOF"
                   ______  _________________ _   _   _____          _        _ _           
                   | ___ \/  ___| ___ \ ___ \ \ | | |_   _|        | |      | | |          
                   | |_/ /\ `--.| |_/ / |_/ /  \| |   | | _ __  ___| |_ __ _| | | ___ _ __ 
                   |  __/  `--. \ ___ \ ___ \ . ` |   | || '_ \/ __| __/ _` | | |/ _ \ '__|
                   | |    /\__/ / |_/ / |_/ / |\  |  _| || | | \__ \ || (_| | | |  __/ |   
                   \_|    \____/\____/\____/\_| \_/  \___/_| |_|___/\__\__,_|_|_|\___|_|   


EOF
}

UPDATE_SPLASH(){
    clear
    cat << "EOF"
                 _____        __ _                            _   _           _       _       
                /  ___|      / _| |                          | | | |         | |     | |      
                \ `--.  ___ | |_| |___      ____ _ _ __ ___  | | | |_ __   __| | __ _| |_ ___ 
                 `--. \/ _ \|  _| __\ \ /\ / / _` | '__/ _ \ | | | | '_ \ / _` |/ _` | __/ _ \
                /\__/ / (_) | | | |_ \ V  V / (_| | | |  __/ | |_| | |_) | (_| | (_| | ||  __/
                \____/ \___/|_|  \__| \_/\_/ \__,_|_|  \___|  \___/| .__/ \__,_|\__,_|\__\___|
                                                                   | |                        
                                                                   |_|                        


EOF
}

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

if [ "$MODE" = "install" ]; then
    INSTALL_SPLASH
    # Choose the PS2 storage device
    if [[ -n "$serialnumber" ]]; then
        DEVICE=$(lsblk -p -o NAME,SERIAL | awk -v sn="$serialnumber" '$2 == sn {print $1; exit}')
        drive_model=$(lsblk -ndo VENDOR,MODEL,SIZE,SERIAL "$DEVICE" | xargs)
    fi
    if [ -z "$DEVICE" ]; then
        while true; do
            INSTALL_SPLASH
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

    # Convert size to MiB
    SIZE_MB=$(( SIZE_CHECK / 1024 / 1024 ))

    # Convert size to GB (1 GB = 1,000,000,000 bytes)
    size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)
        
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

    case "$LANG_FILE" in
        eng)
            lang="eng"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_2]}"
            ;;
        jpn)
            lang="jpn"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_3]}"
            CHAN_UPDATE="yes"
            ;;
        fre)
            lang="fre"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_4]}"
            ;;
        ger)
            lang="ger"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_5]}"
            ;;
        ita)
            lang="ita"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_7]}"
            ;;
        por)
            lang="por"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_8]}"
            ;;
        spa)
            lang="spa"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_9]}"
            ;;
        hun)
            lang="hun"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_6]}"
            ;;
        *)
            echo
            echo "Unsupported language. Defaulting to English." >> "${LOG_FILE}"
            lang="eng"
            LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_2]}"
            ;;
    esac

    echo "Language set to: $lang" >> "${LOG_FILE}"
else

    UPDATE_SPLASH

    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo "[X] Error: Unable to detect the PS2 drive." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_DETECT_DRIVE_1]}" " " "${UI_TEXT[ERROR_DETECT_DRIVE_2]}"
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

    UNMOUNT_ALL
    clean_up
    HDL_TOC
    CHECK_OS
    MOUNT_OPL

    echo "OS Detected: $OS" >> "${LOG_FILE}"

    if [ "$OS" = "PSBBN" ]; then
        psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)

        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            UNMOUNT_OPL
            echo "[X] Error: The installed PSBBN Definitive Patch cannot be updated as is older than version $version_check" >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_OUTDATED_1]}" " " "${UI_TEXT[ERROR_OUTDATED_2]}"
        fi

        lang=$(awk -F' *= *' '$1=="LANG"{print $2}' "${OPL}/version.txt")
        if [[ "$lang" != "jpn" && "$lang" != "ger" && "$lang" != "ita" && "$lang" != "por" && "$lang" != "spa" && "$lang" != "fre" && "$lang" != "hun" ]]; then
            lang="eng"
        fi

        case "$lang" in
            eng)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_2]}"
                ;;
            jpn)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_3]}"
                CHAN_UPDATE="yes"
                ;;
            fre)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_4]}"
                ;;
            ger)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_5]}"
                ;;
            ita)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_7]}"
                ;;
            por)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_8]}"
                ;;
            spa)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_9]}"
                ;;
            hun)
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_6]}"
                ;;
            *)
                echo
                echo "Unsupported language. Defaulting to English." >> "${LOG_FILE}"
                lang="eng"
                LANG_DISPLAY="${UI_TEXT[CHANGE_LANGUAGE_2]}"
                ;;
        esac

        LANG_VER=$(awk -F' *= *' '$1=="LANG_VER"{print $2}' "${OPL}/version.txt")
        CHAN_VER=$(awk -F' *= *' '$1=="CHAN_VER"{print $2}' "${OPL}/version.txt")
        ENTER=$(awk -F' *= *' '$1=="ENTER"{print $2}' "${OPL}/version.txt")
        SCREEN=$(awk -F' *= *' '$1=="SCREEN"{print $2}' "${OPL}/version.txt")
    fi

    if [ "$OS" = "PSBBN" ] || [ "$OS" = "HOSD" ]; then
        osdmenu_version=$(awk -F' *= *' '$1=="OSDMenu"{print $2}' "${OPL}/version.txt")

        if [[ -z "$osdmenu_version" && "$(printf '%s\n' "4.0.0" "$psbbn_version" | sort -V | head -n1)" == "4.0.0" ]]; then
            osdmenu_version="1.0.0"
        fi
    fi

    UNMOUNT_OPL
fi

if [ "$MODE" = "install" ]; then
    INSTALL_SPLASH
    UNMOUNT_ALL
    clean_up
fi

if [ "$OS" = "PSBBN" ]; then
    # Download the HTML of the page
    HTML_FILE=$(mktemp)
    curl -sSL -m 20 -o "$HTML_FILE" "$URL" >> "$LOG_FILE" 2>&1 &
    CURL_PID=$!

    spinner $CURL_PID "${UI_TEXT[VERSION_CHECK_PSBBN]}"

    get_latest_file "psbbn-definitive-patch" "PSBBN Definitive Patch"

    if [ "$MODE" = "update" ]; then
        echo "Current PSBBN Definitive Patch version: $psbbn_version" >> "${LOG_FILE}"
        echo "${UI_TEXT[VERSION_CURRENT_PSBBN]} $psbbn_version"
    
        if [ "$(printf '%s\n' "$LATEST_VERSION" "$psbbn_version" | sort -V | tail -n1)" = "$psbbn_version" ]; then
            echo
            echo "You already have the latest PSBBN Definitive Patch installed." >> "${LOG_FILE}"
            echo "[✓] ${UI_TEXT[VERSION_UPTODATE_PSBBN]}"
            PSBBN_UPDATE="no"
        fi
    fi

    if [ "$PSBBN_UPDATE" != "no" ] || [ "$MODE" != "update" ]; then
        if [[ "$(printf '%s\n' "$LATEST_VERSION" "4.0.0" | sort -V | head -n1)" != "4.0.0" ]]; then
            echo "[X] Error: The latest version currently available is v$LATEST_VERSION. The installer requires version v4.1.0 or higher." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_VERSION_1]}" " " "${UI_TEXT[ERROR_VERSION_2]}"
        fi

        downoad_latest_file "psbbn-definitive-patch"
        PSBBN_PATCH="${ASSETS_DIR}/${LATEST_FILE}"
    fi

    get_latest_file "language-pak-$lang" "$LANG_DISPLAY ${UI_TEXT[LANG_PACK]}"

    echo "Current language pack version: $LANG_VER" >> "${LOG_FILE}"
    echo "${UI_TEXT[VERSION_CURRENT_LANG]} $LANG_VER"

    if [ "$(printf '%s\n' "$LATEST_LANG" "$LANG_VER" | sort -V | tail -n1)" = "$LANG_VER" ]; then
        echo
        echo "You already have the latest language pack installed." >> "${LOG_FILE}"
        echo "[✓] ${UI_TEXT[VERSION_UPTODATE_LANG]}"
        LANG_UPDATE="no"
    fi

    if [ "$LANG_UPDATE" != "no" ] || [ "$MODE" != "update" ]; then
        downoad_latest_file "language-pak-$lang"
        LANG_PACK="${ASSETS_DIR}/${LATEST_FILE}"
    fi

    if [[ "$lang" == "jpn" ]]; then
        get_latest_file "channels-$lang" "$LANG_DISPLAY  ${UI_TEXT[ONLINE_CHANNELS]}"

        echo "Current channels version: $CHAN_VER" >> "${LOG_FILE}"
        echo 
        if [ "$(printf '%s\n' "$LATEST_CHAN" "$CHAN_VER" | sort -V | tail -n1)" = "$CHAN_VER" ]; then
            echo "You already have the latest game channels installed." | tee -a "${LOG_FILE}"
            echo "[✓] ${UI_TEXT[VERSION_CURRENT_CHAN]}"
            CHAN_UPDATE="no"
        else
            CHAN_UPDATE="yes"
        fi

        if [ "$CHAN_UPDATE" != "no" ] || [ "$MODE" != "update" ]; then
            downoad_latest_file "channels"
            CHANNELS="${ASSETS_DIR}/${LATEST_FILE}"
        fi
    else
        CHAN_UPDATE="no"
    fi
fi

LATEST_OSD=$(<"${ASSETS_DIR}/osdmenu/version.txt")
echo
echo "Found OSDMenu version: $LATEST_OSD" >> "${LOG_FILE}"
echo "${UI_TEXT[VERSION_LATEST_OSD]} $LATEST_OSD"
echo "Current OSDMenu version: $osdmenu_version" >> "${LOG_FILE}"
echo "${UI_TEXT[VERSION_CURRENT_OSD]} $osdmenu_version"

if [ "$(printf '%s\n' "$LATEST_OSD" "$osdmenu_version" | sort -V | tail -n1)" = "$osdmenu_version" ]; then
    echo
    echo "You already have the latest OSDMenu system software installed." >> "${LOG_FILE}"
    echo "[✓] ${UI_TEXT[VERSION_UPTODATE_OSD]}"
    OSD_UPDATE="no"
fi

if [ "$OS" = "HOSD" ]; then
    echo "DID THIS RUN???" >> "${LOG_FILE}"
    PSBBN_UPDATE="no"
    LANG_UPDATE="no"
    CHAN_UPDATE="no"
fi

if [ "$PSBBN_UPDATE" == "no" ] && [ "$OSD_UPDATE" == "no" ] && [ "$LANG_UPDATE" == "no" ] && [ "$CHAN_UPDATE" == "no" ]; then
    echo
    echo "You are already running the latest version. No need to update." >> "${LOG_FILE}"
    echo "${UI_TEXT[ALL_UPTODATE]}"
    echo
    read -n 1 -s -r -p "${UI_TEXT[MENU_RETURN]}" </dev/tty
    echo
    exit 0
fi

if [ "$MODE" = "install" ]; then
    INSTALL_SPLASH
fi

if [ "$PSBBN_UPDATE" != "no" ] || [ "$MODE" != "update" ]; then
    if [ "$MODE" = "update" ]; then
        UPDATE_SPLASH
    fi
    echo "======================================= PSBBN Definitive Patch v$LATEST_VERSION ========================================"
    echo
    print_centered_file "${ASSETS_DIR}/lang/changelog_patch_$LANG_FILE.txt"
    echo
    echo
    center_text "${UI_TEXT[CHANGELOG_1]}"
    echo "$text"
    center_text "${UI_TEXT[CHANGE_URL]}"
    echo "$text"
    echo
    echo "=============================================================================================================="
    echo
    center_text "${UI_TEXT[CONTINUE]}"
    read -n 1 -s -r -p "$text" </dev/tty
    echo
fi

if [ "$MODE" = "install" ]; then
    echo | tee -a "${LOG_FILE}"
    INSTALL_SPLASH
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
    COMMANDS+="mkpart __linux.1 512M EXT2\n"
    COMMANDS+="mkpart __linux.2 128M EXT2SWAP\n"
    COMMANDS+="mkpart __linux.4 512M EXT2\n"
    COMMANDS+="mkpart __linux.5 512M EXT2\n"
    COMMANDS+="mkpart __linux.6 128M EXT2\n"
    COMMANDS+="mkpart __linux.7 256M EXT2\n"
    COMMANDS+="mkpart __linux.9 2048M EXT2\n"
    COMMANDS+="exit"

    PFS_COMMANDS

    # Retreive avaliable space

    output=$(sudo "${HDL_DUMP}" toc ${DEVICE} 2>&1)

    # Extract the "used" value, remove "MB" and any commas
    used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')

    if (( SIZE_MB >= 132128 )); then
        capacity=131072
    else
        capacity=$(( SIZE_MB - 1056 ))
    fi

    # Calculate available space (capacity - used)
    available=$((capacity - used - 6400 - 128))
    free_space=$((available / 1024))

    echo | tee -a "${LOG_FILE}"
    # Prompt user for partition size for Music and Contents, validate input, and keep asking until valid input is provided
    while true; do
        remaining_gb=$((free_space -1))
        INSTALL_SPLASH
        center_title "${UI_TEXT[PARTITION_DRIVE_1]}"
        echo
        echo "Space available for APA partitions: $free_space GB" >> "${LOG_FILE}"
        echo "${UI_TEXT[PARTITION_DRIVE_2]} $free_space GB"
        echo
        echo "${UI_TEXT[PARTITION_DRIVE_5]}"
        echo "${UI_TEXT[PARTITION_DRIVE_6]}"
        echo
        echo "${UI_TEXT[PARTITION_SIZE_1]} $remaining_gb GB"
        echo
        read -rp "${UI_TEXT[PARTITION_SIZE_2]} " music_gb

        if [[ ! "$music_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo -n "${UI_TEXT[PARTITION_SIZE_3]}"
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi

        if (( music_gb < 1 || music_gb > remaining_gb )); then
            echo
            echo -n "${UI_TEXT[PARTITION_SIZE_4]} $remaining_gb GB."
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi

        remaining_gb=$((free_space - music_gb))
        echo
        echo "${UI_TEXT[PARTITION_DRIVE_7]}"
        echo "${UI_TEXT[PARTITION_DRIVE_8]}"
        echo
        echo "${UI_TEXT[PARTITION_SIZE_1]} $remaining_gb GB"
        echo
        read -rp "${UI_TEXT[PARTITION_SIZE_2]} " contents_gb

        if [[ ! "$contents_gb" =~ ^[0-9]+$ ]]; then
            echo
            echo -n "${UI_TEXT[PARTITION_SIZE_3]}"
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi

        if (( contents_gb < 1 || contents_gb > remaining_gb )); then
            echo
            echo -n "${UI_TEXT[PARTITION_SIZE_4]} $remaining_gb GB."
            sleep 3
            echo | tee -a "${LOG_FILE}"
            continue
        fi

        remaining_gb=$((free_space - music_gb - contents_gb ))

        if (( remaining_gb > 0 )); then
            echo
            echo "${UI_TEXT[PARTITION_DRIVE_9]}"
            echo "${UI_TEXT[PARTITION_DRIVE_10]}"
            echo
            read -rp "${UI_TEXT[PARTITION_DRIVE_11]} (y/n): " answer

            if [[ "$answer" =~ ^[Yy]$ ]]; then
                echo
                echo "${UI_TEXT[PARTITION_DRIVE_12]}"
                echo "${UI_TEXT[PARTITION_SIZE_1]} $remaining_gb GB"
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
                if (( reserve_gb < 1 || reserve_gb > remaining_gb )); then
                    echo
                    echo "${UI_TEXT[PARTITION_SIZE_4]} $remaining_gb GB."
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
        else
            reserve_gb="0"
        fi

        allocated_mb=$(( (music_gb + contents_gb + reserve_gb) * 1024 ))
        APA_MiB=$(( allocated_mb + used + 6400 +128 ))
        DIFF_MB=$(( SIZE_MB - APA_MiB - 32 ))

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
        echo "${UI_TEXT[PARTITION_DRIVE_16]} $music_gb GB"
        echo "${UI_TEXT[PARTITION_DRIVE_17]} $contents_gb GB"
        echo "${UI_TEXT[PARTITION_DRIVE_18]} $reserve_gb GB"
        echo
        read -rp "${UI_TEXT[PROCEED]} (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            music_partition=$((music_gb * 1024))
            contents_partition=$((contents_gb * 1024))
            reserved_space=$((reserve_gb * 1024))
            break
        fi
    done

    echo >> "${LOG_FILE}"
    echo "##########################################################################" >> "${LOG_FILE}"
    echo "Disk size: $SIZE_MB MB" >> "${LOG_FILE}"
    echo "Used: $used MB" >> "${LOG_FILE}"
    echo "Music partition size: $music_partition MB" >> "${LOG_FILE}"
    echo "Contents partition size: $contents_partition MB" >> "${LOG_FILE}"
    echo "Reserved user space: $reserved_space MB" >> "${LOG_FILE}"
    echo "Reserved for launcher partitions: 6528 MB" >> "${LOG_FILE}"
    echo "Recovery partition: 32 MB" >> "${LOG_FILE}"
    echo "Total APA size: $APA_MiB MB" >> "${LOG_FILE}"
    echo "OPL partition size: $DIFF_MB MB" >> "${LOG_FILE}"
    echo "##########################################################################"  >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"

    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mkpart __linux.8 ${music_partition}M EXT2\n"
    COMMANDS+="mkpart __contents ${contents_partition}M PFS\n"
    COMMANDS+="exit"
    echo "Creating partitions..." >>"${LOG_FILE}"
    PFS_COMMANDS
fi

if [ "$OS" = "PSBBN" ]; then
    echo | tee -a "${LOG_FILE}"
    if [ "$MODE" = "update" ]; then
        if [ "$PSBBN_UPDATE" != "no" ]; then
            UPDATE_SPLASH
        fi
        echo "Updating PS2 System Software..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[UPDATE_SYSTEM]}"

        if version_le "${psbbn_version:-0}" "4.1.0"; then
            COMMANDS="device ${DEVICE}\n"
            COMMANDS+="rmpart __linux.6\n"
            COMMANDS+="mkpart __linux.6 128M EXT2\n"
            COMMANDS+="rmpart __linux.9\n"
            COMMANDS+="mkpart __linux.9 2048M EXT2\n"
            COMMANDS+="exit"
            echo "Deleting and recreating __linux.6 and __linux.9..." >>"${LOG_FILE}"
            PFS_COMMANDS
        fi
    else
        echo "Installing PSBBN..." >> "${LOG_FILE}"
        echo -n "${UI_TEXT[INSTALL_PSBBN]}"
    fi
fi

if [ "$MODE" = "update" ] && [ "$OS" = "PSBBN" ]; then
    LINUX_PARTITIONS=("__linux.1" "__linux.4" "__linux.5" "__linux.6" "__linux.7" "__linux.9" )
    PFS_PARTITIONS=("__system" "__sysconf" )
elif [ "$MODE" = "update" ] && [ "$OS" = "HOSD" ]; then
    PFS_PARTITIONS=("__system" "__sysconf" )
fi

mapper_probe

if [ "$OS" = "PSBBN" ]; then
    mount_cfs
fi

mount_pfs

if [ "$MODE" = "install" ]; then
    sudo mkdir -p "${STORAGE_DIR}/__linux.8/MusicCh/contents" || {
        echo "[X] Error: Failed to create __linux.8/MusicCh/contents" >>"${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_MUSIC_FOLDER]}"
    }
    mkdir -p "${STORAGE_DIR}/__common/Your Saves" 2>> "${LOG_FILE}"
fi

if [ "$PSBBN_UPDATE" != "no" ]; then
    echo "Installing PSBBN Update..." >> "${LOG_FILE}"
    ALL_ERRORS=$(sudo tar zxpf "${PSBBN_PATCH}" -C "${STORAGE_DIR}/" 2>&1 >/dev/null)

    FILTERED_ERRORS=$(echo "$ALL_ERRORS" | grep -v -e "Cannot change ownership" -e "tar: Exiting with failure status")

    if [ -n "$FILTERED_ERRORS" ]; then
        echo "$FILTERED_ERRORS" >> "${LOG_FILE}"
        echo "[X] Error: Failed to install PSBBN. TAR extraction failed" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_INSTALL_PSBBN]}"
    fi
fi

if [ "$LANG_UPDATE" != "no" ]; then
    echo "Installing PSBBN Language Pack..." >> "${LOG_FILE}"
    sudo tar zxpf "$LANG_PACK" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed to install $LANG_DISPLAY language pack." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_INSTALL_LANG]}"
    }
    if [[ "$lang" == "jpn" ]]; then
        cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to copy PSBBN kernel file." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_KERNEL_1]}"
        }

    fi
fi

if [ "$CHAN_UPDATE" == "yes" ]; then
    echo "Installing Game Channels..." >> "${LOG_FILE}"
    sudo tar zxpf "${CHANNELS}" -C "${STORAGE_DIR}/" >> "${LOG_FILE}" 2>&1 || {
        echo "[X] Error: Failed to install channels." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_INSTALL_CHAN]}"
    }
fi

if [ "$OSD_UPDATE" != "no" ]; then
    cp -f "${ASSETS_DIR}/osdmenu/"{hosdmenu.elf,version.txt} "${STORAGE_DIR}/__system/osdmenu/" 2>> "${LOG_FILE}" || {
        echo "[X] Error: Failed to copy hosdmenu.elf." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_INSTALL_HOSDMENU]}"
    }
fi

case "$lang" in
    ger|ita|por|spa|fre|dut|rus|kor|tch|sch)
        OSD_LANG="$lang"
        ;;
    jpn)
        OSD_LANG="jap"
        ;;
    *)
        OSD_LANG="eng"
        ;;
esac

# Check if OSDMBR.CNF exists
if [ ! -f "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" ]; then
    if sudo "${HDL_DUMP}" toc ${DEVICE} | grep -q "__linux.3"; then
        cp -f "${ASSETS_DIR}/kernel/ps2-linux-"{ntsc,vga} "${STORAGE_DIR}/__system/p2lboot/" 2>> "${LOG_FILE}" || {
            echo "[X] Error: Failed to copy PS2 Linux kernel files." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_KERNEL_2]}"
        }
        cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" <<EOL
boot_auto = \$PSBBN
boot_auto_arg1 = -dev9=NICHDD
boot_cross = \$HOSDSYS
boot_circle = \$PSBBN
boot_circle_arg1 = --kernel
boot_circle_arg2 = pfs0:/p2lboot/ps2-linux-ntsc
boot_circle_arg3 = -noflags
boot_square =
boot_triangle =
boot_start = 
cdrom_skip_ps2logo = 0
cdrom_disable_gameid = 0
cdrom_use_dkwdrv = 0
ps1drv_enable_fast = 0
ps1drv_enable_smooth = 0
ps1drv_use_ps1vn = 1
app_gameid = 1
prefer_bbn = 1
osd_language = $OSD_LANG
EOL
        if [[ $? -ne 0 ]]; then
            echo "[X] Error: Failed to write OSDMBR.CNF." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_OSDMBR_CNF]}"
        fi
    else
        cat > "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" <<EOL
boot_auto = \$PSBBN
boot_auto_arg1 = -dev9=NICHDD
boot_cross = \$HOSDSYS
boot_circle = 
boot_square =
boot_triangle = 
boot_start = 
cdrom_skip_ps2logo = 0
cdrom_disable_gameid = 0
cdrom_use_dkwdrv = 0
ps1drv_enable_fast = 0
ps1drv_enable_smooth = 0
ps1drv_use_ps1vn = 1
app_gameid = 1
prefer_bbn = 1
osd_language = $OSD_LANG
EOL
        if [[ $? -ne 0 ]]; then
            echo "[X] Error: Failed to write OSDMBR.CNF." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_OSDMBR_CNF]}"
        fi
    fi
else
    echo "OSDMBR.CNF already exists." >> "${LOG_FILE}"
    sed -i '/^boot_auto_arg/d;' "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" 2>> "${LOG_FILE}"
    if grep -q '^boot_auto = \$PSBBN$' "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"; then
        echo "boot_auto_arg1 = -dev9=NICHDD" >> "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF"
    fi
fi

# Check if OSDMENU.CNF exists
if [ ! -f "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" ]; then
    echo "OSDMENU.CNF not found — creating default version." >> "${LOG_FILE}"
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
else
    echo "OSDMENU.CNF already exists." >> "${LOG_FILE}"
    sed -i '/^OSDSYS_Inner_Browser/d; /^OSDSYS_Skip_Logo/d;' "${STORAGE_DIR}/__sysconf/osdmenu/OSDMENU.CNF" 2>> "${LOG_FILE}"
fi

if [ "$OS" = "PSBBN" ] && [ "$MODE" = "update" ] && version_le "${psbbn_version:-0}" "4.0.0"; then
    echo "Cleaning up files from older installs:" >> "${LOG_FILE}"
    rm -rf "${STORAGE_DIR}/__system/osd110u" 2>> "${LOG_FILE}"
    rm -f "${STORAGE_DIR}/__system/p2lboot/PSBBN.ELF" 2>> "${LOG_FILE}"
    rm -rf "${STORAGE_DIR}/__sysconf/PS2BBL" 2>> "${LOG_FILE}"

    if [ "$MODE" = "update" ] && [ "${psbbn_version:-0}" = "3.00" ]; then
        if ! sudo mount "${MAPPER}__linux.7" "${STORAGE_DIR}/__linux.7" >>"${LOG_FILE}" 2>&1; then
            error_msg "Failed to mount __linux.7 partition."
        fi
        
        mkdir -p "${SCRIPTS_DIR}/tmp"
        sudo cp "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0" "${SCRIPTS_DIR}/tmp" >> "${LOG_FILE}" 2>&1
        TARGET="${SCRIPTS_DIR}/tmp/shortcut_0"

        # If TARGET exists, remove lines ending with PP.LAUNCHELF, PP.HOSDMENU and PP.LAUNCHDISC
        if [ -f "$TARGET" ]; then
            sudo sed -i '/PP\.LAUNCHELF$/d' "$TARGET" >> "${LOG_FILE}" 2>&1
            sudo sed -i '/PP\.HOSDMENU\.HIDDEN$/d' "$TARGET" >> "${LOG_FILE}" 2>&1
            sudo sed -i '/PP\.LAUNCHDISC$/d' "$TARGET" >> "${LOG_FILE}" 2>&1
        fi

        sudo cp -f "${TARGET}" "${STORAGE_DIR}/__linux.7/bn/sysconf/shortcut_0"  >> "${LOG_FILE}" 2>&1
    fi
fi

if [ "$OS" = "PSBBN" ] && [ "$MODE" = "update" ]; then
    if [[ "$ENTER" == "O" ]] || { [[ -z "$ENTER" ]] && [[ "$lang" == "jpn" ]]; }; then
        if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
            && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
            && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
            echo "Enter button swapped to O" >> "${LOG_FILE}"
        else
            echo "[X] Error: Failed to swap enter button. See log for details." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_BUTTON_SWAP]}"
        fi
    elif [[ "$ENTER" == "X" ]] || { [[ -z "$ENTER" ]] && [[ "$lang" != "jpn" ]]; }; then
        if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
            && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
            && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1 ; then
            echo "Enter button swapped to X" >> "${LOG_FILE}"
        else
            echo "[X] Error: Failed to swap enter button. See log for details." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[ERROR_BUTTON_SWAP]}"
        fi
    fi

    if [[ "$SCREEN" == "full" ]]; then
        case "$lang" in
            eng) SIZE_NAME="Full" ;;
            fre) SIZE_NAME="Plein écran" ;;
            spa) SIZE_NAME="Pantalla Completa" ;;
            ger) SIZE_NAME="Ganzer Bildschirm" ;;
            ita) SIZE_NAME="Schermo Intero" ;;
            dut) SIZE_NAME="Volledig" ;;
            por) SIZE_NAME="Completo" ;;
        esac
    elif [[ "$SCREEN" == "16:9" ]]; then
            SIZE_NAME="16:9"
    else
        SIZE_NAME="4:3"
    fi

    mkdir -p "${SCRIPTS_DIR}/tmp"
    sudo cp "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" "${SYSCONF_XML}" || {
        echo "[X] Error: Failed to copy sysconf.xml" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_SYSCONF_1]}"
    }

    sed -i "/<menu id=\"sysconf_value_2_0\">/,/<\/menu>/ {
        /<item value=/ {
            s|<item value=.*|<item value=\"$SIZE_NAME\"/>|
            :done
            n
            b done
        }
    }" "$SYSCONF_XML" || {
        echo "[X] Error: Failed to update $SYSCONF_XML" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_SYSCONF_2]}"
    }

    sudo cp -f "${SYSCONF_XML}" "${STORAGE_DIR}/__linux.4/bn/script/utility/sysconf.xml" || {
        echo "[X] Error: Failed to replace sysconf.xml" >> "${LOG_FILE}"
       error_msg "${UI_TEXT[ERROR_SYSCONF_3]}"
    }
fi

UNMOUNT_ALL

COMMANDS="device ${DEVICE}\n"
COMMANDS+="rmpart PP.SYS_OSDMENU-CONFIGURATOR\n"

if [ "$OS" = "PSBBN" ] && [ "$MODE" = "update" ] && version_le "${psbbn_version:-0}" "4.0.0"; then
    COMMANDS+="rmpart PP.LAUNCHDISC\n"
    COMMANDS+="rmpart PP.HDDOSD\n"
    COMMANDS+="rmpart PP.LAUNCHELF\n"
    COMMANDS+="rmpart PP.BBNAVIGATOR\n"
fi

COMMANDS+="exit"
echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1

clean_up

if [ "$OSD_UPDATE" != "no" ]; then
    BOOTSTRAP
fi

echo | tee -a "${LOG_FILE}"

################################### APA-Jail code by Berion ###################################
if [ "$MODE" = "install" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Running APA-Jail..." >> "${LOG_FILE}"
    echo -n "${UI_TEXT[APA_JAIL]}"

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
    echo | tee -a "${LOG_FILE}"
fi

apa_checksum_fix

###############################################################################################

if [ "$OS" = "PSBBN" ]; then
    CHECK_PARTITIONS
fi

MOUNT_OPL

if [ "$MODE" = "update" ]; then
    rm -rf "${OPL}/APPS/LAUNCHDISC" 2>> "${LOG_FILE}"
    rm -rf "${OPL}/APPS/HDDOSD" 2>> "${LOG_FILE}"
    rm -rf "${OPL}/APPS/LAUNCHELF" 2>> "${LOG_FILE}"
    rm -rf "${OPL}/APPS/BBNAVIGATOR" 2>> "${LOG_FILE}"
    rm -rf "${OPL}/APPS/SYS_OSDMENU-CONFIGURATOR" 2>> "${LOG_FILE}"
    rm -f "${TOOLKIT_PATH}/games/APPS/"{Launch-Disc.elf,HDD-OSD.elf,PSBBN.ELF,SYS_OSDMENU-CONFIGURATOR.psu} 2>> "${LOG_FILE}"

    FILE="${TOOLKIT_PATH}/games/APPS/BOOT.ELF"
    TARGET_MD5="20a5b2c1ffb86e742fb5705b5d9d7370"

    # Check if file exists
    if [[ -f "$FILE" ]]; then
        # Get md5 checksum
        FILE_MD5=$(md5sum "$FILE" | awk '{print $1}')

        # Compare and delete if matches
        if [[ "$FILE_MD5" == "$TARGET_MD5" ]]; then
            rm -f "$FILE"
            echo "Deleted $FILE (MD5 matched)" >> "${LOG_FILE}"
        else
            echo "MD5 does not match, file not deleted." >> "${LOG_FILE}"
        fi
    else
        echo "File not found: $FILE" >> "${LOG_FILE}"
    fi

    cd "${OPL}/APPS/" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to change directory: $OPL/APPS." >> "${LOG_FILE}"
        error_msg "Error" "${UI_TEXT[ERROR_CD]} $OPL/APPS."
    }

    echo "Extracting SYS_R3CONFIGURATOR.psu..." >> "${LOG_FILE}"
    "${PSU_EXTRACT}" "${TOOLKIT_PATH}/games/APPS/SYS_R3CONFIGURATOR.psu" -f >> "${LOG_FILE}" 2>&1
    cd "$TOOLKIT_PATH"
fi

if [ "$MODE" = "install" ]; then
    mkdir -p "${OPL}"/{APPS,ART,CFG,CHT,LNG,THM,VMC,CD,DVD,POPS,nhddl} 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to create OPL folders." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_OPL_FOLDER]}"
    }
    echo "$LATEST_VERSION" > "${OPL}/version.txt"
    echo "APA_SIZE = $APA_MiB" >> "${OPL}/version.txt"
    echo "LANG = $lang" >> "${OPL}/version.txt"
    echo "LANG_VER = $LATEST_LANG" >> "${OPL}/version.txt"
    echo "CHAN_VER = $LATEST_CHAN" >> "${OPL}/version.txt"
    if [[ "$lang" == "jpn" ]]; then
        echo "ENTER = O" >> "$OPL/version.txt"
    else
        echo "ENTER = X" >> "$OPL/version.txt"
    fi
    echo "SCREEN = 4:3" >> "$OPL/version.txt"
fi

if [ "$OS" = "PSBBN" ] && [ "$MODE" = "update" ]; then
    if [[ -f "${OPL}/version.txt" ]]; then
        sed -i "1s|.*|$LATEST_VERSION|" "${OPL}/version.txt"
        if ! grep -q "APA_SIZE *=" "${OPL}/version.txt"; then
            echo "APA_SIZE = 131072" >> "${OPL}/version.txt"
        fi

        # Delete any line beginning with "eng"
        sed -i '/^eng/d' "${OPL}/version.txt"

        # If no line begins with "LANG =" then append it
        if ! grep -q "^LANG =" "${OPL}/version.txt"; then
            echo "LANG = $lang" >> "${OPL}/version.txt"
        fi

        # Update or add LANG_VER
        if grep -q "^LANG_VER =" "${OPL}/version.txt"; then
            sed -i "s|^LANG_VER =.*|LANG_VER = $LATEST_LANG|" "${OPL}/version.txt"
        else
            echo "LANG_VER = $LATEST_LANG" >> "${OPL}/version.txt"
        fi

        # Update or add CHAN_VER
        if grep -q "^CHAN_VER =" "${OPL}/version.txt"; then
            sed -i "s|^CHAN_VER =.*|CHAN_VER = $LATEST_CHAN|" "${OPL}/version.txt"
        else
            echo "CHAN_VER = $LATEST_CHAN" >> "${OPL}/version.txt"
        fi

        if [[ -z "$ENTER" ]]; then
            if [[ "$lang" == "jpn" ]]; then
                echo "ENTER = O" >> "$OPL/version.txt"
            else
                echo "ENTER = X" >> "$OPL/version.txt"
            fi
        fi

        if [[ -z "$SCREEN" ]]; then
            echo "SCREEN = 4:3" >> "$OPL/version.txt"
        fi

    else
        echo "[X] Error: Failed to update version.txt" >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_UPDATE_VER]}"
    fi
fi

# Update or add OSDMenu version
if grep -q "^OSDMenu =" "${OPL}/version.txt"; then
    sed -i "s|^OSDMenu =.*|OSDMenu = $LATEST_OSD|" "${OPL}/version.txt"
else
    echo "OSDMenu = $LATEST_OSD" >> "${OPL}/version.txt"
fi

# Add disk icon
cp -f "${ASSETS_DIR}/autorun.ico" "${OPL}"
cat << EOF > "${OPL}/autorun.inf"
[AutoRun]
icon=autorun.ico
label=OPL
EOF

UNMOUNT_OPL

echo >> "${LOG_FILE}"
echo "${TOC_OUTPUT}" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
if [ "$MODE" = "install" ]; then
    echo "[✓] PSBBN Successfully Installed!" >> "${LOG_FILE}"
    echo "[✓] ${UI_TEXT[PSBBN_SUCCESS]}"
else
    UPDATE_SPLASH
    echo "[✓] PS2 System Software Successfully Updated" >> "${LOG_FILE}"
    center_title "${UI_TEXT[UPDATE_SUCCESS_1]}"
    echo
    if [ "$PSBBN_UPDATE" != "no" ]; then
        echo "  ${UI_TEXT[UPDATE_SUCCESS_2]} $LATEST_VERSION" | tee -a "${LOG_FILE}"
    fi

    if [ "$LANG_UPDATE" != "no" ]; then
        echo "  ${UI_TEXT[UPDATE_SUCCESS_3]} $LANG_DISPLAY $LATEST_LANG" | tee -a "${LOG_FILE}"
    fi

    if [ "$CHAN_UPDATE" == "yes" ]; then
        echo "  ${UI_TEXT[UPDATE_SUCCESS_4]} $LANG_DISPLAY $LATEST_CHAN" | tee -a "${LOG_FILE}"
    fi

    echo
    if [ "$OSD_UPDATE" != "no" ]; then
        echo "  ${UI_TEXT[UPDATE_SUCCESS_5]} $LATEST_OSD" | tee -a "${LOG_FILE}"
        echo
        echo "  ${UI_TEXT[UPDATE_SUCCESS_6]} https://github.com/pcm720/OSDMenu/releases"
    fi

    if [ "$PSBBN_UPDATE" != "no" ] && version_le "${psbbn_version:-0}" "3.00"; then
        echo
        center_text "========= ${UI_TEXT[UPDATE_NOTE_1]} ========="
        echo "$text"
        echo
        echo "  ${UI_TEXT[UPDATE_NOTE_2]}"
        echo "  ${UI_TEXT[UPDATE_NOTE_3]}"
    fi

    if [ "$PSBBN_UPDATE" != "no" ] && version_le "${psbbn_version:-0}" "4.0.0"; then
        echo
        echo "  ${UI_TEXT[UPDATE_NOTE_4]}"
        echo "  ${UI_TEXT[UPDATE_NOTE_5]}"
    fi

    if [[ ( "$PSBBN_UPDATE" != "no" || "$LANG_UPDATE" != "no" ) && -z "$ENTER" ]]; then
        echo
        echo "  ${UI_TEXT[UPDATE_NOTE_6]}"
    fi
    echo
    echo "=============================================================================================================="
fi
echo

if [ "$MODE" = "update" ]; then
    center_text "${UI_TEXT[MENU_RETURN]}"
else
    text="${UI_TEXT[MENU_RETURN]}"
fi

read -n 1 -s -r -p "$text" </dev/tty
echo

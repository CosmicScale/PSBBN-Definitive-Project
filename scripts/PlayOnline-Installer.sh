#!/usr/bin/env bash
#
# PlayOnline Installer for the PSBBN Definitive Project
# Copyright (C) 2026 PrettyOpenLobby
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
#
# Adds PlayOnline titles to a drive that already has PSBBN or HOSDMenu on it.
# Nothing already on the drive is touched: the games, the exFAT region and
# the APA-Jail layout are left exactly as they are.

[[ -t 0 && -t 1 ]] || exit 1

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

term_width=110

TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
LANG_DIR="${ASSETS_DIR}/lang"
LOGS_DIR="${TOOLKIT_PATH}/logs"
LOG_FILE="${LOGS_DIR}/playonline-installer.log"
GAMES_PATH="${TOOLKIT_PATH}/games"
# The folder holding the user's own disc images. The main menu passes a path
# when the user has moved their games folder, as it does for the Game
# Installer. POL_DISC_DIR overrides both.
DISC_DIR="${GAMES_PATH}/POL"
WORK_DIR="${SCRIPTS_DIR}/tmp/playonline"

arch="$(uname -m)"
if [[ "$arch" = "x86_64" ]]; then
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
else
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
fi

LANG_FILE="$1"
shift

if [[ -n "$1" ]] && [[ "$1" == /* ]]; then
    path_arg="$1"
    # The Game Installer takes the path the launcher passes as the games folder
    # itself and puts its subfolders under it, so POL belongs under it too.
    #
    # Accepting it only when it already existed meant a user whose POL folder
    # was anywhere else silently fell back to <toolkit>/games/POL, which on a
    # Windows install is inside the WSL filesystem and not somewhere they can
    # reach from Explorer. They were then told no usable discs were found while
    # their disc sat in the folder they had picked. Name the folder under the
    # path instead, so the "put your discs in" message points somewhere real.
    DISC_DIR="${path_arg}/POL"
fi
[[ -n "${POL_DISC_DIR}" ]] && DISC_DIR="${POL_DISC_DIR}"

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

mkdir -p "${LOGS_DIR}" "${WORK_DIR}"
# Anything a write replaces (mostly a browser entry) is backed up under logs/,
# with the rest of what this step leaves behind.
export PLAYONLINE_BACKUP_DIR="${LOGS_DIR}/playonline-backups"
mkdir -p "${PLAYONLINE_BACKUP_DIR}"

text_width() { echo -n "$1" | wc -L; }

center_text() {
    local w; w=$(text_width "$1")
    printf "%*s%s\n" $(( (term_width - w) / 2 )) "" "$1"
}

error_msg() {
    echo
    center_text "$1"
    echo
    # Write the report before the pause, so its location is on screen while the
    # user is still looking at the error. The EXIT trap would run after this
    # keypress, by which point the window is usually cleared.
    REPORT_RC=1
    write_report
    read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}" </dev/tty
    echo
    exit 1
}

# Preparing one title failed. Same shape as error_msg, with a second line that
# tells the user how to retry: with POL_NO_ROUTE the titles are installed in
# the form the disc carries.
route_failed() {
    echo
    center_text "${UI_TEXT[POL_ERROR_ROUTE]} $1"
    center_text "${UI_TEXT[POL_ROUTE_RETRY]}"
    echo
    REPORT_RC=1
    write_report
    read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}" </dev/tty
    echo
    exit 1
}

SPLASH() {
    clear
    cat << "EOF"

    ____  __            ____        ___
   / __ \/ /___ ___  __/ __ \____  / (_)___  ___
  / /_/ / / __ `/ / / / / / / __ \/ / / __ \/ _ \
 / ____/ / /_/ / /_/ / /_/ / / / / / / / / /  __/
/_/   /_/\__,_/\__, /\____/_/ /_/_/_/_/ /_/\___/
              /____/

EOF
}

# The interpreter is named outright, as the Media Installer does. The venv's
# python3 carries the packages Setup.sh installed, and sudo resets PATH, so
# activating the venv does not reach the steps that write the drive. Without
# a venv (a nix shell) it is whatever python3 is on PATH.
POL_PY="${SCRIPTS_DIR}/venv/bin/python3"
[[ -x "${POL_PY}" ]] || POL_PY="python3"
pol() { PYTHONPATH="${HELPER_DIR}" "${POL_PY}" -m playonline "$@"; }
polmod() { local m="$1"; shift; PYTHONPATH="${HELPER_DIR}" "${POL_PY}" -m "playonline.$m" "$@"; }
polsudo() { local m="$1"; shift; sudo -E env PYTHONPATH="${HELPER_DIR}" "${POL_PY}" -m "playonline.$m" "$@"; }
# The package CLI as root, for the sizing step, which reads the drive's free
# space off the device.
polroot() { sudo -E env PYTHONPATH="${HELPER_DIR}" "${POL_PY}" -m playonline "$@"; }

# A report the user can read without a terminal.
#
# The log lives under the toolkit, which on a Windows install is inside the WSL
# filesystem and not somewhere most people can reach. The POL folder is the one
# they put their discs in, so on those installs it is a folder already open in
# Explorer. Write the report there, on every exit including the error paths,
# because a run that failed is the one that needs sending.
#
# Anything that is not a disc image is ignored by the folder scan and skipped by
# route derive-elf, so leaving a .txt here is safe.
REPORT_FILE="${DISC_DIR}/playonline-report.txt"
REPORT_DONE=0
write_report() {
    local rc=$?
    # error_msg calls this before its keypress and sets REPORT_RC, so the path
    # is on screen while the error still is. The trap then finds it done.
    [[ -n "${REPORT_RC}" ]] && rc="${REPORT_RC}"
    [[ ${REPORT_DONE} -eq 1 ]] && return 0
    REPORT_DONE=1
    [[ -d "${DISC_DIR}" ]] || return 0
    {
        echo "PlayOnline installer report"
        echo "date:    $(date)"
        echo "result:  $([[ $rc -eq 0 ]] && echo "finished" || echo "stopped early (exit $rc)")"
        echo "toolkit: $(git -C "${TOOLKIT_PATH}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        echo "discs:   ${DISC_DIR}"
        echo "drive:   ${DEVICE:-none chosen}"
        echo "region:  ${REGION:-not reached}"
        echo "console: ${CONSOLE_REGION:-not asked}"
        echo "loader:  ${LOADER_KELF:-none}"
        echo "skipped: ${SKIPPED[*]:-none}"
        echo "keyed:   $([[ "${ROUTE_READY:-0}" -eq 1 ]] && echo "yes" || echo "no - the titles will not start")"
        echo "mode:    ${ROUTE_MODE:-none}"
        echo
        if [[ -n "${DEVICE}" ]]; then
            echo "--- drive ---"
            timeout 120 sudo -n true 2>/dev/null \
                && { polroot inspect "${DEVICE}" 2>&1
                     echo
                     echo "--- __net ---"
                     polsudo netpart "${DEVICE}" --verify 2>&1; } \
                || echo "(skipped: needs a password this late in the run)"
            echo
        fi
        echo "--- log ---"
        cat "${LOG_FILE}" 2>/dev/null
    } > "${REPORT_FILE}" 2>&1
    printf '\n%s %s\n' "${UI_TEXT[POL_REPORT_WRITTEN]}" "${REPORT_FILE}"
}
trap write_report EXIT

activate_python() {
    [ -n "$IN_NIX_SHELL" ] && return
    source "${SCRIPTS_DIR}/venv/bin/activate" 2>>"${LOG_FILE}" || {
        echo "[X] Error: Failed to activate the Python virtual environment." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[ERROR_ACTIVATE_PYTHON]}"
    }
}

# Find the drive PSBBN is installed on, the way Game-Installer.sh does: the
# exFAT partition labelled OPL identifies the disk.
#
# That partition's UUID is kept to seed the HDD ID. Every title on a drive has
# to be keyed to the same HDD ID, because the console is served one block, so
# a lost HDD ID file must come back with the same value on a later run.
find_device() {
    local line
    line=$(sudo blkid -t TYPE=exfat 2>/dev/null | grep OPL)
    DEVICE=$(awk -F: '{print $1}' <<< "$line" | sed 's/[0-9]*$//')
    if [[ -z "$DEVICE" ]]; then
        echo "[X] Error: no PSBBN drive found." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[POL_ERROR_NO_DEVICE]}"
    fi
    # ` UUID="..."` with the leading space, so PARTUUID does not match first.
    DRIVE_UUID=$(grep -o ' UUID="[^"]*"' <<< "$line" | head -1 | cut -d'"' -f2)
    echo "Device: $DEVICE (UUID ${DRIVE_UUID:-none})" >> "${LOG_FILE}"
}

# Refuse to touch a disk that is not a PSBBN or HOSDMenu install. These are
# the same three partitions the Game Installer checks for.
check_os() {
    local toc
    toc=$(sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}") || {
        error_msg "${UI_TEXT[ERROR_HDL_TOC]}"
    }
    for part in __system __sysconf __common; do
        if ! grep -q -- "$part" <<< "$toc"; then
            echo "[X] Error: $part missing; not a PSBBN/HOSDMenu drive." >> "${LOG_FILE}"
            error_msg "${UI_TEXT[POL_ERROR_NOT_PSBBN]}"
        fi
    done
}

make_partition() {
    local label="$1" size="$2"
    echo "Creating $label (${size}M)..." >> "${LOG_FILE}"
    printf 'device %s\nmkpart %s %sM PFS\nexit\n' "$DEVICE" "$label" "$size" \
        | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" | grep -q -- "$label"; then
        echo "[X] Error: $label was not created." >> "${LOG_FILE}"
        error_msg "${UI_TEXT[POL_ERROR_MKPART]} $label"
    fi
}

SPLASH
center_text "${UI_TEXT[POL_TITLE]}"
echo
date >> "${LOG_FILE}"
activate_python
# Setup.sh installs pycryptodome into the venv. A venv made by an older
# Setup.sh lacks it, and the crypto modules import it at load.
"${POL_PY}" -c "import Crypto" 2>/dev/null || "${POL_PY}" -m pip install pycryptodome >> "${LOG_FILE}" 2>&1 || {
    echo "[X] Error: could not install pycryptodome into the venv." >> "${LOG_FILE}"
    error_msg "${UI_TEXT[ERROR_ACTIVATE_PYTHON]}"
}
find_device
check_os

# ---- what the user has --------------------------------------------------
if [[ ! -d "${DISC_DIR}" ]]; then
    mkdir -p "${DISC_DIR}"
    error_msg "${UI_TEXT[POL_NO_DISCS]} ${DISC_DIR}"
fi

# A .chd is extracted once, beside the original, with MAME's chdman (see
# chd.py). chdman comes from the mame-tools package, which is installed here
# only when a .chd is actually present.
if [[ -n "$(polmod chd "${DISC_DIR}" --list 2>>"${LOG_FILE}")" ]]; then
    if ! command -v chdman >/dev/null 2>&1; then
        echo "${UI_TEXT[POL_CHD_TOOL]}"
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get install -y mame-tools >> "${LOG_FILE}" 2>&1
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install -y mame-tools >> "${LOG_FILE}" 2>&1
        elif [ -x "$(command -v pacman)" ]; then
            sudo pacman -S --needed --noconfirm mame-tools >> "${LOG_FILE}" 2>&1
        fi
    fi
    echo "${UI_TEXT[POL_CHD_EXTRACT]}"
    polmod chd "${DISC_DIR}" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}" | sed 's/^/  /'
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "  ${UI_TEXT[POL_CHD_FAILED]}"
    fi
    echo
fi

# One call lists which titles the user's discs can supply and, where two discs
# carry the same title, which holds the newer build.
declare -A TITLE_DISC TITLE_PART TITLE_SIZE TITLE_STATUS TITLE_VER
ORDER=()
while IFS='|' read -r key disc part need status ver build; do
    [[ -z "$key" ]] && continue
    TITLE_DISC["$key"]="$disc"; TITLE_PART["$key"]="$part"
    TITLE_SIZE["$key"]="$need"; TITLE_STATUS["$key"]="$status"
    TITLE_VER["$key"]="${build:-$ver}"
    ORDER+=("$key")
done < <(pol sources --plain "${DISC_DIR}" 2>>"${LOG_FILE}" | tr -d '\r')

if [[ ${#ORDER[@]} -eq 0 ]]; then
    # `pol sources` collects the reason a disc was rejected and then drops it,
    # so on its own this error cannot tell an unrecognised disc from an empty
    # folder from a disc that was never read. `pol discs` prints one line per
    # image, including why each one was skipped. When it prints nothing at all
    # the folder held no file with a disc image extension, and the listing is
    # what says so.
    echo "${UI_TEXT[POL_DISCS_FOUND]} ${DISC_DIR}"
    disc_report=$(pol discs "${DISC_DIR}" 2>&1)
    if [[ -n "${disc_report}" ]]; then
        printf '%s\n' "${disc_report}" | tee -a "${LOG_FILE}" | sed 's/^/  /'
    else
        ls -la "${DISC_DIR}" 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/  /'
    fi
    error_msg "${UI_TEXT[POL_NOTHING_TO_DO]}"
fi

# ---- region: which Viewer the drive gets ---------------------------------
# One Viewer per drive. A US Viewer launches the US titles and the Japan-only
# ones (Janhourou, FMO, Dirge) through its own install.inf; a JP Viewer
# launches only Japanese-serial partitions. The region is chosen first, and
# the title list is then read again for what that Viewer can launch.
REGION="${POL_REGION:-}"
HAVE_US=0; HAVE_JP=0
for k in "${ORDER[@]}"; do
    [[ "$k" == viewer-us ]] && HAVE_US=1
    [[ "$k" == viewer-jp ]] && HAVE_JP=1
done
if [[ -z "${REGION}" ]]; then
    if [[ $HAVE_US -eq 1 && $HAVE_JP -eq 1 ]]; then
        printf "%s " "${UI_TEXT[POL_SELECT_REGION]}"
        read -r answer </dev/tty
        case "$answer" in
            [Jj]*) REGION=jp ;;
            *) REGION=us ;;
        esac
    elif [[ $HAVE_JP -eq 1 ]]; then
        REGION=jp
    else
        REGION=us
    fi
fi
VIEWER_KEY="viewer-${REGION}"
if [[ $HAVE_US -eq 0 && $HAVE_JP -eq 0 ]]; then
    error_msg "${UI_TEXT[POL_NO_VIEWER_DISC]}"
fi
declare -A TITLE_DISC TITLE_PART TITLE_SIZE TITLE_STATUS TITLE_VER
ORDER=()
while IFS='|' read -r key disc part need status ver build; do
    [[ -z "$key" ]] && continue
    TITLE_DISC["$key"]="$disc"; TITLE_PART["$key"]="$part"
    TITLE_SIZE["$key"]="$need"; TITLE_STATUS["$key"]="$status"
    TITLE_VER["$key"]="${build:-$ver}"
    ORDER+=("$key")
done < <(pol sources --plain --region "${REGION}" "${DISC_DIR}" 2>>"${LOG_FILE}" | tr -d '\r')
if [[ ! -v "TITLE_PART[$VIEWER_KEY]" ]]; then
    error_msg "${UI_TEXT[POL_NO_VIEWER_DISC]}"
fi

echo "${UI_TEXT[POL_DISCS_FOUND]} ${DISC_DIR}"
echo "  ${UI_TEXT[POL_REGION_SET]} ${REGION}"
echo
i=0
for k in "${ORDER[@]}"; do
    i=$((i + 1))
    printf "  %2d  %-16s %-30s %-10s %s\n" "$i" "$k" "${TITLE_PART[$k]}" "${TITLE_VER[$k]}" "$(basename "${TITLE_DISC[$k]}")"
done
echo

# ---- which titles ---------------------------------------------------------
# The Viewer is always installed, because it is what launches the titles.
# POL_TITLES names keys for a scripted run.
CHOSEN=()
if [[ -n "${POL_TITLES}" ]]; then
    for k in ${POL_TITLES//,/ }; do
        [[ -v "TITLE_PART[$k]" ]] && CHOSEN+=("$k")
    done
else
    printf "%s " "${UI_TEXT[POL_SELECT_TITLES]}"
    read -r answer </dev/tty
    if [[ -z "$answer" || "$answer" == [Aa]* ]]; then
        CHOSEN=("${ORDER[@]}")
    else
        for n in ${answer//,/ }; do
            [[ "$n" =~ ^[0-9]+$ ]] || continue
            (( n >= 1 && n <= ${#ORDER[@]} )) && CHOSEN+=("${ORDER[$((n - 1))]}")
        done
    fi
fi
if [[ ${#CHOSEN[@]} -eq 0 ]]; then
    echo; echo "${UI_TEXT[POL_ABORTED]}"; sleep 2; exit 0
fi
has_viewer=0
for k in "${CHOSEN[@]}"; do [[ "$k" == "$VIEWER_KEY" ]] && has_viewer=1; done
if [[ $has_viewer -eq 0 ]]; then
    echo "  ${UI_TEXT[POL_SELECT_VIEWER_REQUIRED]}"
    CHOSEN=("$VIEWER_KEY" "${CHOSEN[@]}")
fi
# The Viewer goes first, so the module mode it decides reaches the titles
# prepared after it.
ORDER=("$VIEWER_KEY")
for k in "${CHOSEN[@]}"; do
    [[ "$k" == "$VIEWER_KEY" ]] || ORDER+=("$k")
done
echo

# ---- what making the titles bootable needs -------------------------------
# A partition filled straight from a disc holds the disc form of the boot
# container and of every module, and Square Enix's own loader. playonline.route
# rewrites the staged tree so that it boots through this package's loader
# (scripts/assets/playonline/polbbnexec.kelf, source in
# scripts/helper/playonline/loader-src). The Viewer's boot ELF and IOP image
# go into the loader. The modules become plain files where the build has
# Square Enix's plaintext switch (every Viewer from the 1.13 era on), and are
# keyed to the drive where it does not (the two 2003-era discs). It needs:
#
#   an HDD ID          minted once and kept. The loader serves it to the
#                      console, and keyed modules are built against it
#   a boot executable  taken from one of the user's discs; Square Enix's
#                      public keys, which open a disc's containers, are read
#                      out of it
#   the loader         shipped with the toolkit
#
# The last two are checked here, before anything is written. A run that
# cannot do the conversion says so in the plan and installs the disc form.
# The HDD ID is minted later, once the user has confirmed.
ROUTE_READY=0
ROUTE_MISSING=()
HDDID_FILE="${POL_HDDID:-${DISC_DIR}/playonline.hddid}"
DERIVE_ELF="${WORK_DIR}/derivation.elf"
# The loader is a signed KELF, and a KELF carries the MagicGate zone of the
# disc it was signed from: Square Enix's US dnasload.elf is AppType 0x0B in
# zone 0x2, the Japanese one AppType 0x01 in zone 0x1. A console opens a KELF
# only for its own zone, and it checks before any of this runs, so a loader
# from the wrong zone drops straight back to the browser with nothing drawn.
# polkelf cannot widen a zone, so there is one signed loader per console
# region.
#
# This is the console's region, not the disc's. They are independent: a
# Japanese console runs the US Viewer perfectly well, and it needs the
# Japanese loader to do it. REGION above is the Viewer's and decides the
# titles; this decides which loader can open at all.
CONSOLE_REGION="${POL_CONSOLE:-}"
if [[ -z "${CONSOLE_REGION}" ]]; then
    printf "%s " "${UI_TEXT[POL_SELECT_CONSOLE]}"
    read -r answer </dev/tty
    case "$answer" in
        [Jj]*) CONSOLE_REGION=jp ;;
        *)     CONSOLE_REGION=us ;;
    esac
fi
LOADER_KELF="${POL_LOADER:-${SCRIPTS_DIR}/assets/playonline/polbbnexec-${CONSOLE_REGION}.kelf}"
# The toolkit shipped a single loader before it shipped one per region, and
# that file is the Japanese-zoned build. A US console has no fallback on
# purpose: using the Japanese one would install a Viewer that cannot start.
if [[ -z "${POL_LOADER}" && ! -f "${LOADER_KELF}" && "${CONSOLE_REGION}" == "jp" ]]; then
    LOADER_KELF="${SCRIPTS_DIR}/assets/playonline/polbbnexec.kelf"
fi
# Every title on a drive has to be in the same mode as the Viewer partition:
# a plaintext Viewer opens plain title modules and a keyed one opens keyed
# ones. The mode is read off the Viewer as it is prepared. When the Viewer is
# already on the drive and not part of this run, POL_ROUTE_MODE supplies it.
ROUTE_MODE="${POL_ROUTE_MODE:-}"

# POL_NO_ROUTE asks for the disc form, and is the way to retry when the
# conversion fails on a title.
if [[ -z "${POL_NO_ROUTE}" ]]; then
    rm -f "${DERIVE_ELF}"
    polmod route derive-elf "${DISC_DIR}"/* --out "${DERIVE_ELF}" \
        >> "${LOG_FILE}" 2>&1
    if [[ ! -s "${DERIVE_ELF}" ]]; then
        DERIVE_ELF=""
        ROUTE_MISSING+=("${UI_TEXT[POL_ROUTE_NEED_ELF]}")
    fi
    if [[ ! -f "${LOADER_KELF}" ]]; then
        ROUTE_MISSING+=("${UI_TEXT[POL_ROUTE_NEED_LOADER]} ${LOADER_KELF}")
    fi
    [[ ${#ROUTE_MISSING[@]} -eq 0 ]] && ROUTE_READY=1
fi

# ---- what it would do ---------------------------------------------------
echo "${UI_TEXT[POL_PLAN]}"
echo
# Show the PC partition table too. On an APA-Jail drive the PS2's view of
# free space can run past the APA region into the exFAT partition holding the
# user's games, so the user is shown where the boundary is.
polsudo jail "$DEVICE"     2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
echo
TOC=$(sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}")
grep -q -- "__net" <<< "$TOC" && NET_EXISTS=1 || NET_EXISTS=0
[[ $NET_EXISTS -eq 0 ]] && echo "  + __net (128M)  ${UI_TEXT[POL_PLAN_NET]}"
for k in "${ORDER[@]}"; do
    if grep -q -- "${TITLE_PART[$k]}" <<< "$TOC"; then
        echo "  = ${TITLE_PART[$k]}  ${UI_TEXT[POL_PLAN_SKIP]}"
    else
        echo "  + ${TITLE_PART[$k]} (${TITLE_SIZE[$k]}M)  ${UI_TEXT[POL_PLAN_ADD]}"
    fi
done
echo
if [[ $ROUTE_READY -eq 1 ]]; then
    echo "  ${UI_TEXT[POL_PLAN_ROUTE]}"
    echo "  ${UI_TEXT[POL_HDDID_KEEP]} ${HDDID_FILE}"
    [[ -n "${ROUTE_MODE}" ]] && echo "  ${UI_TEXT[POL_ROUTE_MODE_SET]} ${ROUTE_MODE}"
    echo
    center_text "${UI_TEXT[POL_ROUTE_LOADER]}"
    center_text "${UI_TEXT[POL_EXPERIMENTAL]}"
else
    echo "  ${UI_TEXT[POL_PLAN_DISC_FORM]}"
    if [[ -n "${POL_NO_ROUTE}" ]]; then
        echo "  ${UI_TEXT[POL_ROUTE_OFF]}"
    else
        echo "  ${UI_TEXT[POL_ROUTE_MISSING]}"
        for missing in "${ROUTE_MISSING[@]}"; do
            echo "    - ${missing}"
        done
    fi
    echo
    center_text "${UI_TEXT[POL_NOT_BOOTABLE]}"
fi
echo
printf "%s " "${UI_TEXT[POL_CONFIRM]}"
read -r answer </dev/tty
case "$answer" in
    [Yy]*) ;;
    *) echo; echo "${UI_TEXT[POL_ABORTED]}"; sleep 2; exit 0 ;;
esac

# A title already on the drive is left alone unless the user asks for a
# refresh, which compares it with what this version would install and writes
# the difference. Files the disc does not carry are never removed, so saves
# and settings stay. Asked only when it could apply. See resync.py.
RESYNC="${POL_RESYNC:-}"
if [[ -z "${RESYNC}" && $ROUTE_READY -eq 1 ]]; then
    for k in "${ORDER[@]}"; do
        if [[ "$k" != viewer-* ]] && grep -q -- "${TITLE_PART[$k]}" <<< "$TOC"; then
            printf "%s " "${UI_TEXT[POL_ASK_RESYNC]}"
            read -r answer </dev/tty
            case "$answer" in [Yy]*) RESYNC=1 ;; *) RESYNC=0 ;; esac
            break
        fi
    done
fi
echo

# ---- do it --------------------------------------------------------------
# The HDD ID is minted here and not while the plan is drawn, so that
# answering no to the confirmation leaves nothing behind.
if [[ $ROUTE_READY -eq 1 && ! -f "${HDDID_FILE}" ]]; then
    echo "${UI_TEXT[POL_DOING_HDDID]}"
    seed_args=()
    [[ -n "${DRIVE_UUID}" ]] && seed_args=(--seed "psbbn-playonline-${DRIVE_UUID}")
    polmod hddid --mint "${HDDID_FILE}" "${seed_args[@]}" \
        >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_HDDID]}"
fi

# netpart runs every time, whether __net exists or not. A PSBBN install makes
# its own `__net` with blank passwords, and the Viewer cannot open that: it
# boots, and then the first online certification fails with "DNAS error -401"
# (POL-1536). netpart adds the partition when it is missing and otherwise
# only sets the two password fields, so running it again is harmless.
[[ $NET_EXISTS -eq 0 ]] && echo "${UI_TEXT[POL_DOING_NET]}"
# The backup gets a fresh name each run, because polapaadd refuses to overwrite
# an existing backup file.
polsudo netpart "$DEVICE" --write \
    --backup "${WORK_DIR}/apa-before-net-$(date +%Y%m%d-%H%M%S).json" \
    >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_NET]}"

# Titles that did not fit. They are named again at the end, because a message
# printed before a long write has scrolled away by the time the run finishes.
SKIPPED=()

# A Japanese install keeps every browser title as Square Enix wrote it.
title_args=()
[[ "${REGION}" == "jp" ]] && title_args=(--original-titles)

for k in "${ORDER[@]}"; do
    disc="${TITLE_DISC[$k]}"
    part="${TITLE_PART[$k]}"
    # The plan showed this partition as already on the drive. It may hold a
    # save or a newer build, so it is not rewritten.
    if grep -q -- "$part" <<< "$TOC"; then
        echo "${UI_TEXT[POL_SKIPPING]} $k"
        # An installed Viewer still gets its loader replaced when it differs
        # (see reloader.py): the file the console boots, with the Viewer's
        # boot executable inside. Preparing it also reads the module mode off
        # the disc, so titles added by this run match the installed Viewer.
        if [[ $ROUTE_READY -eq 1 && "$k" == viewer-* ]]; then
            rm -rf "${WORK_DIR}/$k"
            mode_args=()
            [[ -n "${ROUTE_MODE}" ]] && mode_args=(--mode "${ROUTE_MODE}")
            if polmod stage "$disc" --title "$k" --out "${WORK_DIR}/$k" >> "${LOG_FILE}" 2>&1 \
               && route_out="$(polmod route prepare "${WORK_DIR}/$k" --title "$k" \
                    --hddid "${HDDID_FILE}" --disc "$disc" \
                    --derive-elf "${DERIVE_ELF}" --loader "${LOADER_KELF}" \
                    "${mode_args[@]}" 2>&1)"; then
                echo "${route_out}" >> "${LOG_FILE}"
                ROUTE_MODE="$(awk '/^mode:/ {print $2; exit}' <<< "${route_out}")"
                echo "  ${UI_TEXT[POL_ROUTE_MODE_SET]} ${ROUTE_MODE}"
                polsudo reloader "$DEVICE" --partition "$part" \
                    --loader "${WORK_DIR}/$k/POL/install/PS2/dnasload.elf" --write \
                    2>&1 | tee -a "${LOG_FILE}" | sed 's/^/  /'
                # The installed Viewer's patch host, in place (see patchhost.py).
                # It reads POL_PATCH_HOST itself, and changes nothing when that
                # is "none" or when both files already name the host.
                polsudo patchhost --drive "$DEVICE" --title "$k" --write \
                    2>&1 | tee -a "${LOG_FILE}" | sed 's/^/  /'
            else
                echo "${route_out}" >> "${LOG_FILE}"
            fi
            rm -rf "${WORK_DIR}/$k" "${WORK_DIR}/${k}-net-record.bin"
        fi
        # Everything else is skipped unless a refresh was asked for. A
        # refreshed title is staged and prepared like a new install and then
        # compared with the partition, further down.
        if [[ "${RESYNC}" != "1" || "$k" == viewer-* || $ROUTE_READY -ne 1 ]]; then
            continue
        fi
        REFRESH=1
    else
        REFRESH=0
    fi
    # Stage before creating the partition, so that it is sized from the tree
    # that came off the disc.
    echo "${UI_TEXT[POL_DOING_STAGE]} $k"
    rm -rf "${WORK_DIR}/$k"
    polmod stage "$disc" --title "$k" --out "${WORK_DIR}/$k" >> "${LOG_FILE}" 2>&1 \
        || error_msg "${UI_TEXT[POL_ERROR_STAGE]} $k"

    # Prepare the tree before it is measured: the plaintext modules written
    # beside the disc's add a few MiB to the Viewer, and a title that cannot
    # be converted fails here, before any partition is created.
    #
    # The staged tree decides which command applies. Only the Viewer carries
    # a boot container, named after its product code, and the Viewer sets the
    # mode for the whole drive. Tetra Master and Janhourou are one module
    # each (TetraMaster/TMaster.pex.enc, Warashi/JanHouRou.pex.enc),
    # converted the same way as the Viewer's.
    if [[ $ROUTE_READY -eq 1 ]]; then
        product="$(cut -d. -f2 <<< "$part")"
        record="${WORK_DIR}/${k}-net-record.bin"
        if [[ -f "${WORK_DIR}/$k/POL/install/PS2/${product}" ]]; then
            echo "${UI_TEXT[POL_DOING_ROUTE]} $k"
            rm -f "$record"
            mode_args=()
            [[ -n "${ROUTE_MODE}" ]] && mode_args=(--mode "${ROUTE_MODE}")
            route_out="$(polmod route prepare "${WORK_DIR}/$k" --title "$k" \
                --hddid "${HDDID_FILE}" --disc "$disc" \
                --derive-elf "${DERIVE_ELF}" --loader "${LOADER_KELF}" \
                "${mode_args[@]}" 2>&1)" || { echo "${route_out}" >> "${LOG_FILE}"; route_failed "$k"; }
            echo "${route_out}" >> "${LOG_FILE}"
            ROUTE_MODE="$(awk '/^mode:/ {print $2; exit}' <<< "${route_out}")"
            echo "  ${UI_TEXT[POL_ROUTE_MODE_SET]} ${ROUTE_MODE}"
            # The record belongs at __net + 0x201800, outside any filesystem,
            # so it is written to the drive and not into the tree. __net
            # exists by now, from this run or an earlier one.
            [[ -s "$record" ]] || error_msg "${UI_TEXT[POL_ERROR_RECORD]}"
            echo "  ${UI_TEXT[POL_DOING_RECORD]}"
            polsudo route \
                record "$DEVICE" --record "$record" --write \
                >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_RECORD]}"
        elif [[ -d "${WORK_DIR}/$k/image/ffxi" ]]; then
            # FFXI: its own loader opens two containers that are keyed to the
            # drive in either mode. The disc's CONFIGU.SYS names them and
            # they are taken from the disc root.
            echo "${UI_TEXT[POL_DOING_ROUTE]} $k"
            polmod route ffxi "${WORK_DIR}/$k" --hddid "${HDDID_FILE}"                 --disc "$disc" --derive-elf "${DERIVE_ELF}"                 >> "${LOG_FILE}" 2>&1 || route_failed "$k"
        elif [[ -f "${WORK_DIR}/$k/filelist.bin" ]]; then
            # Dirge: its modules are installed as the disc ships them, in
            # both forms, as on a partition Square Enix's installer made.
            :
        elif [[ -n "$(find "${WORK_DIR}/$k" -name '*.pex.enc' -print -quit)" ]]; then
            if [[ -z "${ROUTE_MODE}" ]]; then
                echo "  ${UI_TEXT[POL_ROUTE_MODE_UNKNOWN]}"
                ROUTE_MODE=plaintext
            fi
            echo "${UI_TEXT[POL_DOING_ROUTE]} $k (${ROUTE_MODE})"
            polmod route modules "${WORK_DIR}/$k" --mode "${ROUTE_MODE}" \
                --hddid "${HDDID_FILE}" --disc "$disc" \
                --derive-elf "${DERIVE_ELF}" \
                >> "${LOG_FILE}" 2>&1 || route_failed "$k"
        fi
    fi

    # A refresh: compare the prepared tree with the partition and have
    # pfsshell write what is missing or differs. pfsshell mounts a partition
    # whatever password its header carries, so the password is left in place.
    if [[ $REFRESH -eq 1 ]]; then
        echo "${UI_TEXT[POL_DOING_RESYNC]} $k"
        rm -f "${WORK_DIR}/$k-resync.txt"
        polsudo resync "$DEVICE" --title "$k" --src "${WORK_DIR}/$k" \
            --out "${WORK_DIR}/$k-resync.txt" >> "${LOG_FILE}" 2>&1
        rc=$?
        if [[ $rc -eq 3 ]]; then
            echo "  ${UI_TEXT[POL_RESYNC_CURRENT]}"
        elif [[ $rc -eq 0 && -s "${WORK_DIR}/$k-resync.txt" ]]; then
            sudo "${PFS_SHELL}" < "${WORK_DIR}/$k-resync.txt" 2>&1 \
                | polmod pfsprogress "$(wc -l < "${WORK_DIR}/$k-resync.txt")" \
                    --log "${LOG_FILE}"
            # Run again so the log shows what is left, if anything.
            polsudo resync "$DEVICE" --title "$k" --src "${WORK_DIR}/$k" \
                >> "${LOG_FILE}" 2>&1
        else
            error_msg "${UI_TEXT[POL_ERROR_WRITE]} $k"
        fi
        rm -rf "${WORK_DIR}/$k" "${WORK_DIR}/$k-resync.txt"
        continue
    fi

    size=$(polroot size --src "${WORK_DIR}/$k" --title "$k" --drive "$DEVICE" --plain \
           2>>"${LOG_FILE}" | tr -d '\r')
    if [[ -z "$size" ]]; then
        # The verbose run goes to the log: it names the staged size and every
        # free entry it considered.
        polroot size --src "${WORK_DIR}/$k" --title "$k" --drive "$DEVICE" \
            >> "${LOG_FILE}" 2>&1
        # One title that does not fit is not a reason to abandon the others.
        # Stopping here used to leave the run short of installinf and retitle,
        # so a drive that had taken the Viewer perfectly well was left without
        # the registry that tells the Viewer anything is installed. Skip it,
        # say so, and carry on to the steps after the loop.
        #
        # The Viewer is the exception: it is what launches everything else, so
        # there is nothing worth finishing without it.
        if [[ "$k" == "$VIEWER_KEY" ]]; then
            error_msg "${UI_TEXT[POL_ERROR_NOROOM]} $k"
        fi
        echo "  ${UI_TEXT[POL_SKIP_NOROOM]} $k"
        SKIPPED+=("$k")
        rm -rf "${WORK_DIR}/$k"
        continue
    fi
    echo "  ${UI_TEXT[POL_SIZED]} ${size}M"
    make_partition "$part" "$size"

    # The files are written through pfsshell, like everything else the
    # toolkit writes. `mkpart` splits a partition larger than the drive's
    # ceiling into a main partition plus sub-partitions, and only pfsshell's
    # driver lays a volume out across them. playonline.pfsput writes the
    # command list, and build --populated then writes what pfsshell does
    # not: the header password and the browser entry.
    echo "${UI_TEXT[POL_DOING_WRITE]} $k"
    rm -rf "${WORK_DIR}/$k-extras" "${WORK_DIR}/$k-pfsshell.txt"
    mkdir -p "${WORK_DIR}/$k-extras"
    polmod pfsput "$DEVICE" --title "$k" --src "${WORK_DIR}/$k" \
        --extras "${WORK_DIR}/$k-extras" --out "${WORK_DIR}/$k-pfsshell.txt" \
        >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_WRITE]} $k"
    # pfsshell prints a prompt for each command it takes, which is the only
    # progress available; pfsprogress counts them into one redrawn line.
    sudo "${PFS_SHELL}" < "${WORK_DIR}/$k-pfsshell.txt" 2>&1 \
        | polmod pfsprogress "$(wc -l < "${WORK_DIR}/$k-pfsshell.txt")" \
            --log "${LOG_FILE}"
    [[ ${PIPESTATUS[0]} -eq 0 ]] || error_msg "${UI_TEXT[POL_ERROR_WRITE]} $k"
    rm -rf "${WORK_DIR}/$k-extras" "${WORK_DIR}/$k-pfsshell.txt"
    polsudo build "$DEVICE" \
        --title "$k" --src "${WORK_DIR}/$k" --disc "$disc" --populated --write \
        "${title_args[@]}" \
        >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_WRITE]} $k"

    echo "${UI_TEXT[POL_DOING_VERIFY]} $k"
    polsudo build "$DEVICE" \
        --title "$k" --src "${WORK_DIR}/$k" --verify \
        >> "${LOG_FILE}" 2>&1 || error_msg "${UI_TEXT[POL_ERROR_VERIFY]} $k"

    rm -rf "${WORK_DIR}/$k"
done

# The Viewer decides what is installed from its own registry,
# pub/all/install.inf: a title with no record there is "not installed"
# however complete its partition is. Square Enix's installers append a record
# per title; installinf does the same for every known title on the drive,
# from this run or an earlier one. See installinf.py.
polsudo installinf "$DEVICE" --write >> "${LOG_FILE}" 2>&1 \
    || echo "[!] installinf failed; the Viewer may report titles as not installed." >> "${LOG_FILE}"

# Janhourou, Dirge and Front Mission Online were only released in Japan, and
# the US Viewer launches all three. On a US install their names in the
# console's browser and in PSBBN's list are set to English, on every such
# partition on the drive. See retitle.py.
if [[ "${REGION}" == "us" ]]; then
    polsudo retitle "$DEVICE" --write >> "${LOG_FILE}" 2>&1 \
        || echo "[!] retitle failed; the titles keep their Japanese names." >> "${LOG_FILE}"
fi

# The boot executable was extracted from the user's own disc to derive the
# keys. It is not kept in the toolkit afterwards.
[[ -n "${DERIVE_ELF}" ]] && rm -f "${DERIVE_ELF}"

echo
center_text "${UI_TEXT[POL_DONE]}"
echo
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    center_text "${UI_TEXT[POL_SKIPPED_NOROOM]} ${SKIPPED[*]}"
    center_text "${UI_TEXT[POL_SKIPPED_RETRY]}"
    echo
fi
if [[ $ROUTE_READY -eq 1 ]]; then
    center_text "${UI_TEXT[POL_DONE_KEYED]} ${HDDID_FILE}"
    [[ -n "${ROUTE_MODE}" ]] && center_text "${UI_TEXT[POL_ROUTE_MODE_SET]} ${ROUTE_MODE}"
else
    center_text "${UI_TEXT[POL_NOT_BOOTABLE]}"
fi
echo
read -n 1 -s -r -p "${UI_TEXT[EXIT_KEY]}" </dev/tty
echo

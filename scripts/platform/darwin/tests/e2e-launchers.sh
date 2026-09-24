#!/opt/homebrew/bin/bash
# Rehearsal of the Game-Installer launcher-partition loop against a file image.
# No real disk and no sudo. Sends the command streams Game-Installer sends,
# through the same sudo shim, PFS Shell wrapper and HDL Dump wrapper:
# toc, rmpart of every PP.* partition, then per launcher toc (size check),
# mkpart 8M PFS, mount, put, umount and modify_header, then a second sync
# that deletes and recreates everything, like a second Game-Installer run.
#
#   tests/e2e-launchers.sh                       synthetic launcher folders
#   PSBBN_PP_DIRS=DIR tests/e2e-launchers.sh     every DIR/PP.* folder instead
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
bin="$root/bin"
repo=$(cd "$root/../../.." && pwd)
helper="$repo/scripts/helper/darwin-arm64"
fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
stamp() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

export PATH="$bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
work=$(mktemp -d /tmp/psbbn-launchers.XXXXXX)
export PSBBN_MOUNT_STATE="$work/state"
export PSBBN_MAPPER_DIR="$work/maps"
export PSBBN_DM_STATE="$work/dm"
export COPYFILE_DISABLE=1
# The installer calls sudo. The shim hands helper commands to platform_elevate,
# which runs PSBBN_SUDO instead of /usr/bin/sudo. Here that is a plain exec.
printf '#!/bin/bash\nexec "$@"\n' > "$work/run-sudo"
chmod +x "$work/run-sudo"
export PSBBN_SUDO="$work/run-sudo"
img="$work/disk.img"
log="$work/log"
: > "$log"
PFS_SHELL="$helper/PFS Shell.elf"
HDL_DUMP="$helper/HDL Dump.elf"
pfsshell="$helper/pfsshell"
assets="$work/assets"
mkdir -p "$assets/POPStarter/eng"
for f in POPStarter/bg.png POPStarter/eng/1.png POPStarter/eng/2.png POPStarter/eng/man.xml; do
    head -c 4096 /dev/urandom > "$assets/$f"
done

# label|type|folder, in the order Game-Installer would create them.
LAUNCHERS=()
make_launcher() {
    local label="$1" type="$2" del="$3" dir="$work/tmp/$1"
    mkdir -p "$dir"
    printf 'BOOT2 = pfs0:/EXECUTE.KELF\nVER = 1.00\nVMODE = NTSC\nHDDUNITPOWER = NICHDD\n' > "$dir/system.cnf"
    printf 'title = rehearsal\nlauncher = %s\n' "$label" > "$dir/info.sys"
    head -c 964 /dev/urandom > "$dir/icon.sys"
    head -c 30368 /dev/urandom > "$dir/list.ico"
    head -c 20686 /dev/urandom > "$dir/jkt_001.png"
    [[ "$del" == del ]] && head -c 29728 /dev/urandom > "$dir/del.ico"
    LAUNCHERS+=("$label|$type|$dir")
}
if [[ -n "${PSBBN_PP_DIRS:-}" ]]; then
    for dir in "$PSBBN_PP_DIRS"/PP.*; do
        [[ -d "$dir" ]] || continue
        LAUNCHERS+=("$(basename "$dir")|DVD|$dir")
    done
else
    # Same shapes make_partition_label produces: the 32-character cap,
    # one under it, short ones, a PS1 launcher and the system apps.
    make_launcher PP.SLUS-00001.01.THIRTY_TWO_CHAR DVD nodel
    make_launcher PP.SLUS-00002.01.THIRTY_ONE_CHA DVD nodel
    make_launcher PP.SLUS-00003.01.SHORT DVD nodel
    make_launcher PP.SLES-00004.01.CD_TITLE_1 CD nodel
    make_launcher PP.SLUS-00005.01.PS1_TITLE POPS nodel
    make_launcher PP.SCPN_601.60.TEST INC del
    make_launcher PP.APP_TESTAPP APP del
    make_launcher PP.SYS_TESTCONFIGURATOR INC del
fi
count=${#LAUNCHERS[@]}
(( count > 0 )) || { bad "no launcher folders"; exit 1; }

hdl_toc() {
    hdl_output="$work/toc.txt"
    "$bin/sudo" "$HDL_DUMP" toc "$img" 2>>"$log" > "$hdl_output"
}
toc_has() {
    awk -v l="$1" '$(NF-1) == "8MB" && $NF == l { f = 1 } END { exit !f }' "$hdl_output"
}
pp_count() {
    grep -c 'PP\.' "$hdl_output"
}

stamp "image at $img"
/usr/sbin/mkfile -n 40g "$img"
# Leftovers from an earlier run, including one at the 32-character cap.
printf 'device %s\ninitialize yes\nmkpart __contents 128M PFS\nmkpart PP.LEFTOVER 8M PFS\nmkpart PP.SLUS-00099.01.LEFTOVER_AT_CAP 8M PFS\nexit\n' "$img" \
    | "$pfsshell" > "$work/init.out" 2>&1 || { bad "init $(tail -3 "$work/init.out")"; exit 1; }

delete_launchers() {
    local round="$1" partition COMMANDS
    hdl_toc || { bad "$round toc-before-delete"; return; }
    delete_partition=$(grep -o 'PP\.[^ ]\+' "$hdl_output")
    [[ -n "$delete_partition" ]] || { bad "$round nothing-to-delete"; return; }
    COMMANDS="device ${img}\n"
    while IFS= read -r partition; do
        COMMANDS+="rmpart ${partition}\n"
    done <<< "$delete_partition"
    COMMANDS+="exit"
    echo -e "$COMMANDS" | "$bin/sudo" "$PFS_SHELL" >> "$log" 2>&1
    hdl_toc || { bad "$round toc-after-delete"; return; }
    if [[ -z "$(grep -o 'PP\.[^ ]\+' "$hdl_output")" ]]; then
        ok "$round delete-existing-launchers"
    else
        bad "$round delete-existing-launchers: $(grep -o 'PP\.[^ ]\+' "$hdl_output" | tr '\n' ' ')"
    fi
}

create_launchers() {
    local round="$1" entry label type dir used COMMANDS
    for entry in "${LAUNCHERS[@]}"; do
        IFS='|' read -r label type dir <<< "$entry"
        hdl_toc || { bad "$round size-check $label"; continue; }
        used=$(awk '/used:/ {print $6}' "$hdl_output" | sed 's/,//; s/MB//')
        [[ "$used" =~ ^[0-9]+$ ]] || bad "$round used-parse '$used'"
        COMMANDS="device ${img}\n"
        COMMANDS+="mkpart ${label} 8M PFS\n"
        COMMANDS+="mount ${label}\n"
        COMMANDS+="cd /\n"
        COMMANDS+="lcd '${dir}'\n"
        COMMANDS+="mkdir res\n"
        COMMANDS+="cd res\n"
        COMMANDS+="put info.sys\n"
        COMMANDS+="put jkt_001.png\n"
        if [[ "$type" == POPS ]]; then
            COMMANDS+="lcd '${assets}/POPStarter'\n"
            COMMANDS+="put bg.png\n"
            COMMANDS+="lcd '${assets}/POPStarter/eng'\n"
            COMMANDS+="put 1.png\n"
            COMMANDS+="put 2.png\n"
            COMMANDS+="put man.xml\n"
        fi
        COMMANDS+="umount\n"
        COMMANDS+="exit\n"
        echo -e "$COMMANDS" | "$bin/sudo" "$PFS_SHELL" >> "$log" 2>&1
        if (cd "$dir" && "$bin/sudo" "$HDL_DUMP" modify_header "$img" "$label" >> "$log" 2>&1); then
            ok "$round header $label"
        else
            bad "$round header $label: $(tail -n 2 "$log" | tr '\n' ' ')"
        fi
    done
    hdl_toc || { bad "$round toc-after-create"; return; }
    for entry in "${LAUNCHERS[@]}"; do
        IFS='|' read -r label type dir <<< "$entry"
        toc_has "$label" || bad "$round toc-missing $label"
    done
    [[ "$(pp_count)" -eq "$count" ]] && ok "$round toc-lists-all ($count)" || bad "$round toc-lists-all: $(pp_count) of $count"
}

stamp "first sync: delete leftovers, create $count launchers"
delete_launchers first
create_launchers first

IFS='|' read -r first_label _ _ <<< "${LAUNCHERS[0]}"
listing=$(printf 'device %s\nmount %s\ncd res\nls\numount\nexit\n' "$img" "$first_label" | "$pfsshell" 2>/dev/null)
grep -q 'jkt_001.png' <<<"$listing" && ok "res-folder-populated $first_label" || bad "res-folder-populated $first_label"
if [[ -z "${PSBBN_PP_DIRS:-}" ]]; then
    listing=$(printf 'device %s\nmount PP.SLUS-00005.01.PS1_TITLE\ncd res\nls\numount\nexit\n' "$img" | "$pfsshell" 2>/dev/null)
    grep -q 'man.xml' <<<"$listing" && ok pops-assets-populated || bad pops-assets-populated
fi

stamp "second sync: delete everything, create again"
delete_launchers second
create_launchers second

stamp "name over the 32-character cap is refused, not crashed"
out=$(printf 'device %s\nmkpart PP.SLUS-00009.01.THIRTY_THREE_CHR 8M PFS\nexit\n' "$img" | "$bin/sudo" "$PFS_SHELL" 2>&1)
grep -q 'longer than 32 characters' <<<"$out" && ok name-too-long-refused || bad "name-too-long-refused: $(tail -n 2 <<<"$out" | tr '\n' ' ')"
hdl_toc && ! grep -q 'THIRTY_THREE' "$hdl_output" && ok name-too-long-not-created || bad name-too-long-not-created

grep -q 'died with signal' "$log" && bad "pfsshell crashed: $(grep 'died with signal' "$log" | head -1)" || ok no-pfsshell-crash
grep -q 'Resource busy' "$log" && bad "resource busy in log" || ok no-resource-busy
if [[ -z "${PSBBN_PP_DIRS:-}" ]]; then
    grep -q 'Exit code is' "$log" && bad "pfsshell error: $(grep -B1 'Exit code is' "$log" | head -2 | tr '\n' ' ')" || ok no-pfsshell-errors
fi

printf '\n%d passed, %d failed  (work dir %s)\n' "$pass" "$fail" "$work"
if [[ "$fail" -eq 0 ]]; then
    rm -rf "$work"
    exit 0
fi
exit 1

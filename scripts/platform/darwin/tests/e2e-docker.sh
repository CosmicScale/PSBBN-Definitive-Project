#!/opt/homebrew/bin/bash
# The Linux side of the macOS port, in Docker: what the project's Linux
# helpers write, and how a Linux kernel and PS2 Linux's own /bin/mkhome see
# what the macOS PFS Shell wrapper writes. Needs Docker and PS2Linux.tar.gz
# (the archive Extras downloads for PS2 Linux).
#
#   tests/e2e-docker.sh PS2Linux.tar.gz
#
# On a drive the size of the one in the report on the pull request
# (PSBBN_DRIVE_SECTORS) with old bytes where the partitions go, for each
# home partition size (PSBBN_HOME_SIZES, MB):
#   mac     the macOS wrapper makes __linux.3 and __linux.10, as Extras does
#   linux   the project's Linux PFS Shell.elf makes them
#   before  the wrapper at git revision PSBBN_BEFORE, if set; shown, not counted
# The container maps __linux.10 the way the PS2 kernel does
# (fs/partitions/ps2.c), runs e2fsck on it, runs /bin/mkhome, copies files
# in and reads the kernel log. It also builds genvmc the way Game-Installer
# does on Linux and compares its cards with the macOS genvmc's.
# Not in the container: the PS2's own 2.4 kernel, and macOS itself (the
# other e2e tests run the macOS side natively).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
repo=$(cd "$root/../../.." && pwd)
tarball="${1:?PS2Linux.tar.gz}"
tarball=$(cd "$(dirname "$tarball")" && pwd)/$(basename "$tarball")
sectors="${PSBBN_DRIVE_SECTORS:-$((0x1bf244b0))}"
sizes="${PSBBN_HOME_SIZES:-1024 2048 5120}"
image=psbbn-linux-check
fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
stamp() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }

docker info > /dev/null 2>&1 || { echo "Docker is not running." >&2; exit 2; }
stamp "docker build $image"
docker build -q --platform linux/amd64 -t "$image" "$root/tests/docker" > /dev/null || exit 1

# Docker Desktop shares /private; /tmp is a link to it.
work=$(cd "$(mktemp -d /tmp/psbbn-docker.XXXXXX)" && pwd -P)
before=""
if [[ -n "${PSBBN_BEFORE:-}" ]]; then
    before="$work/before-tree"
    git -C "$repo" worktree add --detach "$before" "$PSBBN_BEFORE" > /dev/null 2>&1 \
        || { echo "git worktree $PSBBN_BEFORE failed" >&2; exit 1; }
fi
cleanup() {
    [[ -n "$before" ]] && git -C "$repo" worktree remove --force "$before" > /dev/null 2>&1
    rm -rf "${work:?}"
}
trap cleanup EXIT

run() {
    local stdin=()
    [[ "$1" == format ]] && stdin=(-i)
    docker run --rm --privileged --platform linux/amd64 "${stdin[@]}" \
        -v "$work:/work" -v "$repo/scripts/helper:/helper:ro" -v "$tarball:/ps2linux.tar.gz:ro" \
        "$image" "$@"
}

# A sparse drive with old bytes from 2 GiB, past the partitions initialize
# makes, to the end of the home partition.
new_drive() {
    rm -f "$work/drive.img"
    python3 -I -c 'import os, sys; fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR, 0o644); os.ftruncate(fd, int(sys.argv[2]) * 512); os.close(fd)' \
        "$work/drive.img" "$sectors"
    LC_ALL=C tr '\0' '\245' < /dev/zero | /bin/dd of="$work/drive.img" bs=1048576 seek=2048 count=$((2048 + $1 + 1024)) conv=notrunc 2> /dev/null
}

# PS2 Linux's partitions, the way Extras makes them on a HOSDMenu drive.
commands() {
    printf 'device %s\ninitialize yes\nmkpart __linux.3 2048M EXT2\nmkpart __linux.10 %sM EXT2\nexit\n' "$1" "$2"
}

mac_format() {
    local tree="$1" size="$2"
    (
        export PATH="$tree/scripts/platform/darwin/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export PSBBN_MOUNT_STATE="$work/state" PSBBN_MAPPER_DIR="$work/maps" PSBBN_DM_STATE="$work/dm" COPYFILE_DISABLE=1
        commands "$work/drive.img" "$size" | "$tree/scripts/helper/darwin-arm64/PFS Shell.elf"
    ) > "$work/format.out" 2>&1
}

# The key=value lines of one check, in KEY.
declare -A KEY
check() {
    local line
    run home /work/drive.img /ps2linux.tar.gz > "$work/home.out" 2>&1
    KEY=()
    # A check that stopped early leaves keys out; set -u would stop here.
    for line in pieces blocks sectors fsck_new root mkhome_rc home_ps2 fstab_entry kernel_errors kernel_first fsck_used error; do
        KEY[$line]=""
    done
    while IFS= read -r line; do
        [[ "$line" =~ ^([a-z0-9_]+)=(.*)$ ]] && KEY[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    done < "$work/home.out"
}

summary() {
    printf '    %s pieces=%s blocks=%s e2fsck=%s root=[%s] /home/ps2=%s kernel ext2 errors=%s e2fsck after copy=%s%s\n' \
        "$1" "${KEY[pieces]}" "${KEY[blocks]}" "${KEY[fsck_new]}" "${KEY[root]% }" "${KEY[home_ps2]}" "${KEY[kernel_errors]}" "${KEY[fsck_used]}" \
        "${KEY[kernel_first]:+ first: ${KEY[kernel_first]}}${KEY[error]:+ error: ${KEY[error]}}"
}

for size in $sizes; do
    if [[ -n "$before" ]]; then
        stamp "before ($PSBBN_BEFORE): ${size} MB home"
        new_drive "$size"
        if mac_format "$before" "$size"; then check; summary before; else echo "    before: PFS Shell failed $(tail -n 2 "$work/format.out")"; fi
    fi

    stamp "linux PFS Shell.elf: ${size} MB home"
    new_drive "$size"
    commands /work/drive.img "$size" | run format > "$work/format.out" 2>&1
    if grep -q '^format_rc=0$' "$work/format.out"; then
        check
        summary linux
        linux_blocks=${KEY[blocks]:-}
        [[ "${KEY[fsck_new]}" == 0 && "${KEY[home_ps2]}" == yes && "${KEY[kernel_errors]}" == 0 && "${KEY[fsck_used]}" == 0 ]] \
            && ok "linux-reference-home ($size MB)" || bad "linux-reference-home ($size MB) $(tail -n 3 "$work/home.out")"
    else
        linux_blocks=""
        bad "linux-reference-home ($size MB) PFS Shell.elf: $(tail -n 3 "$work/format.out")"
    fi

    stamp "mac PFS Shell wrapper: ${size} MB home"
    new_drive "$size"
    if mac_format "$repo" "$size"; then
        check
        summary mac
        [[ "${KEY[fsck_new]}" == 0 && "${KEY[root]}" == ". .. " ]] \
            && ok "mac-home-as-the-ps2-maps-it ($size MB)" || bad "mac-home-as-the-ps2-maps-it ($size MB) $(tail -n 3 "$work/home.out")"
        [[ "${KEY[home_ps2]}" == yes && "${KEY[fstab_entry]}" == yes ]] \
            && ok "mac-home-mkhome-fills-it ($size MB)" || bad "mac-home-mkhome-fills-it ($size MB) $(tail -n 3 "$work/home.out")"
        [[ "${KEY[kernel_errors]}" == 0 && "${KEY[fsck_used]}" == 0 ]] \
            && ok "mac-home-takes-files ($size MB)" || bad "mac-home-takes-files ($size MB) ${KEY[kernel_first]}"
        [[ -n "$linux_blocks" && "${KEY[blocks]}" == "$linux_blocks" ]] \
            && ok "mac-home-size-matches-linux ($size MB, ${KEY[blocks]} blocks)" || bad "mac-home-size-matches-linux mac=${KEY[blocks]} linux=$linux_blocks"
    else
        bad "mac-home ($size MB) PFS Shell: $(tail -n 3 "$work/format.out")"
    fi
done
rm -f "$work/drive.img"

stamp "genvmc: the macOS build against Game-Installer's Linux build"
mkdir -p "$work/vmc"
"$repo/scripts/helper/darwin-arm64/genvmc" 8 "$work/vmc/mac-8.bin" > /dev/null
"$repo/scripts/helper/darwin-arm64/genvmc" 32 "$work/vmc/mac-32.bin" > /dev/null
run vmc /work/vmc > "$work/vmc.out" 2>&1
grep -q '^vmc_8=same$' "$work/vmc.out" && grep -q '^vmc_32=same$' "$work/vmc.out" \
    && ok "vmc-cards-match-linux-build (8 and 32 MB)" || bad "vmc-cards-match-linux-build $(tr '\n' ' ' < "$work/vmc.out")"
printf '    the Linux build with glibc fortify (-O2 -D_FORTIFY_SOURCE=2): rc=%s %s\n' \
    "$(sed -n 's/^linux_fortify_rc=//p' "$work/vmc.out")" "$(sed -n 's/^linux_fortify_says=//p' "$work/vmc.out")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

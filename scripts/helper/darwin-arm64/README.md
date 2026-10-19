# macOS (Apple silicon) helper binaries

These are the macOS builds of the helpers the Linux installer ships as
`scripts/helper/*.elf`. The installer never calls them by these names;
`scripts/platform/darwin/lib.sh` links them into the overlay under the
names the scripts expect (`HDL Dump.elf`, `PFS Shell.elf`, ...).

| File | What it is |
| --- | --- |
| `hdl_dump` | hdl-dump from <https://github.com/AKuHAK/hdl-dump>, branch **`8M`**, with `hdl-dump-apple.patch` applied, built with `make RELEASE=yes`. The `8M` branch is required: the master branch treats every partition smaller than 128 MB as a broken table, and the launcher partitions Game-Installer creates are 8 MB. |
| `HDL Dump.elf` | Wrapper around `hdl_dump` that evicts Disk Arbitration's automounts of the drive and retries an open that macOS refused with "Resource busy". |
| `pfsshell` | pfsshell from <https://github.com/AKuHAK/pfsshell>, branch **`ext2`** (commit `7586a0d`, ps2sdk submodule `e94c67e`), the source of the Linux `PFS Shell.elf`, with `pfsshell-name32.patch` applied; build steps below. Its `mkpart` formats EXT2 and EXT2SWAP the way the Linux build does, where the PS2 kernel reads the partition (`fs/partitions/ps2.c`: the main partition from 4 MiB in, each sub-partition from 4 KiB in) and with no `lost+found`, so PS2 Linux's `/bin/mkhome` fills a new home partition; the partitions it writes are byte for byte the Linux build's apart from the times. Creates and packs 8 MB partitions. The patch is required: `mkpart` writes "hdd0:" plus the partition name into a 37-byte buffer, one byte short for the 32-character names Game-Installer produces. Linux at -O0 truncates silently; macOS clang's fortified `sprintf` traps, pfsshell dies after the first prompt and the partition is never created. |
| `PFS Shell.elf` | Wrapper around `pfsshell`: refuses an internal disk, and evicts and retries like `HDL Dump.elf`. |
| `mkfs.exfat` | Wrapper that maps the Linux `mkfs.exfat` arguments onto `/sbin/newfs_exfat`. |
| `cue2pops` | BIN+CUE to POPS VCD converter from <https://github.com/bucanero/pops2cue>, the project the main README credits for `cue2pops`. |
| `pops2cue` | POPS VCD to BIN+CUE converter from <https://github.com/bucanero/pops2cue> (commit `981e776`), built with `MACOSX_DEPLOYMENT_TARGET=11.0 make pops2cue`. It writes the CUE and BIN next to the VCD and recognises only an upper-case `.VCD` name; with any other name it builds the output names wrongly. |
| `genvmc` | The PS2 VMC generator Game-Installer otherwise compiles from `scripts/helper/genvmc.c` with `gcc`, built from that file with `genvmc-magic.patch` applied. `genvmc.c` copies the 29-byte magic string, terminator included, into the 28-byte magic field; Linux's unoptimized gcc build lets it through, while Apple clang's fortified `strcpy` stops it ("Trace/BPT trap: 5") and every card is left empty. The cards are byte for byte the Linux build's. The overlay links it over any `genvmc` an earlier run compiled. |
| `genvmc-magic.patch` | Fills the magic and version fields with `memcpy`. |
| `sqlite` | SQLite **2.8.17** from <https://www.sqlite.org/sqlite-2.8.17.tar.gz> (SHA-256 `3f35ebfb67867fb5b583a03e480f900206af637efe7179b32294a6a0cf806f37`), the version of the Linux helper, built with the same ISO8859 encoding and no readline. PSBBN's `music.db`, `photo.db` and `movie.db` are SQLite 2.1 files: the macOS `sqlite3` cannot read them ("file is not a database") and writes files PSBBN cannot open. |
| `da-veto` | Disk Arbitration mount-approval client, built from `da-veto.c` next to it with `clang -O2 -Wall -framework CoreFoundation -framework DiskArbitration -o da-veto da-veto.c`. Disk Arbitration re-probes the drive after every whole-disk write closes and mounts its volumes under `/Volumes` again; such a mount makes the next whole-disk open fail with EBUSY, and for a few seconds after it appears macOS will not even unmount it. The shims start `da-veto` for the selected drive on first contact; it refuses every mount of that drive until the installer session ends (`PSBBN_SESSION_PID` from `enter.sh` is gone), except while the allow file the mount shim creates around the installer's own OPL mounts exists. Runs as the user. |
| `PFS Fuse.elf` | Not used. The overlay links `PFS Fuse.elf` to `scripts/platform/darwin/bin/pfs-fuse`, which stages a PFS partition as a plain folder through `pfsshell`. |
| `hdl-dump-apple.patch` | The one source change needed for macOS: accept character devices and regular files as disks, since raw disks are character devices there. |
| `pfsshell-name32.patch` | Sizes the `mkpart` open string for a full 32-character partition id and refuses longer names with a message instead of an overflow. |

To rebuild `hdl_dump`:

```sh
git clone -b 8M https://github.com/AKuHAK/hdl-dump.git
cd hdl-dump
patch -p1 < /path/to/hdl-dump-apple.patch
make RELEASE=yes
```

The result is ad-hoc signed by the linker, which is enough to run locally.

To rebuild `pfsshell` (needs `meson` and `ninja`, from Homebrew or
`pip install meson ninja`):

```sh
git clone -b ext2 https://github.com/AKuHAK/pfsshell.git
cd pfsshell
git checkout 7586a0d
git submodule update --init --depth 1 external/ps2sdk
patch -p1 < /path/to/pfsshell-name32.patch
CFLAGS=-mmacosx-version-min=11.0 LDFLAGS=-mmacosx-version-min=11.0 meson setup build -Denable_pfs2tar=false
ninja -C build pfsshell
```

To rebuild `pops2cue`:

```sh
git clone https://github.com/bucanero/pops2cue.git
cd pops2cue
git checkout 981e776
MACOSX_DEPLOYMENT_TARGET=11.0 make pops2cue
```

To rebuild `genvmc`, from the project folder:

```sh
mkdir build && cp scripts/helper/genvmc.c scripts/helper/genvmc.h build/
cd build
patch -p1 < ../scripts/helper/darwin-arm64/genvmc-magic.patch
cc -std=gnu99 -O2 -Wall -mmacosx-version-min=11.0 -o genvmc genvmc.c
```

To rebuild `sqlite` (its 2005 `configure` does not know Apple silicon, so
`main.mk` is driven directly, the way the source's `Makefile.linux-gcc` does):

```sh
curl -LO https://www.sqlite.org/sqlite-2.8.17.tar.gz
tar xzf sqlite-2.8.17.tar.gz
mkdir build && cd build
cat > Makefile << 'EOF'
TOP = ../sqlite-2.8.17
FLAGS = -O2 -Wno-deprecated-non-prototype -mmacosx-version-min=11.0
# BCC builds only the build-time probe and the lemon parser generator.
BCC = cc $(FLAGS) -Wno-implicit-function-declaration -Wno-implicit-int -Wno-format
TCC = cc $(FLAGS) -Werror=implicit-function-declaration -Werror=int-conversion
USLEEP = -DHAVE_USLEEP=1
THREADSAFE = -DTHREADSAFE=0
OPTS = -DNDEBUG=1
AR = ar cr
RANLIB = ranlib
ENCODING = ISO8859
include $(TOP)/main.mk
EOF
make sqlite
```

Rehearsals that exercise these binaries the way the installers do, on a
file image and without sudo: `scripts/platform/darwin/tests/e2e-image.sh`
(PSBBN install), `scripts/platform/darwin/tests/e2e-launchers.sh`
(Game-Installer launcher partitions, including the 32-character names),
`scripts/platform/darwin/tests/e2e-extents.sh` (partitions above the APA
size cap, which span a main partition and sub-partitions, checked as the
PS2 kernel maps them) and
`scripts/platform/darwin/tests/e2e-hosdmenu.sh` (HOSDMenu-only install,
whose BOOTSTRAP writes the APA header while its PFS partitions are still
mounted). `scripts/platform/darwin/tests/e2e-docker.sh PS2Linux.tar.gz`
needs Docker: in a Linux container it formats the same PS2 Linux
partitions with the Linux `PFS Shell.elf` and compares the drive with the
one this `pfsshell` formats, maps the home partition the way the PS2
kernel does, runs PS2 Linux's `/bin/mkhome` on it and copies files in. It
installs PS2 Linux's root partition the way Extras does on each system and
compares every path, setuid bits and times included, and compares
`genvmc`'s cards with Game-Installer's Linux build. `PSBBN_BEFORE=<revision>`
adds that revision's macOS side to the run.

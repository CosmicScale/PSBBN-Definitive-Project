# macOS (Apple silicon) helper binaries

These are the macOS builds of the helpers the Linux installer ships as
`scripts/helper/*.elf`. The installer never calls them by these names;
`scripts/platform/darwin/lib.sh` links them into the overlay under the
names the scripts expect (`HDL Dump.elf`, `PFS Shell.elf`, ...).

| File | What it is |
| --- | --- |
| `hdl_dump` | hdl-dump from <https://github.com/AKuHAK/hdl-dump>, branch **`8M`**, with `hdl-dump-apple.patch` applied, built with `make RELEASE=yes`. The `8M` branch is required: the master branch treats every partition smaller than 128 MB as a broken table, and the launcher partitions Game-Installer creates are 8 MB. |
| `HDL Dump.elf` | Wrapper around `hdl_dump` that evicts Disk Arbitration's automounts of the drive and retries an open that macOS refused with "Resource busy". |
| `pfsshell` | pfsshell from <https://github.com/ps2homebrew/pfsshell> (commit `8c92467`, ps2sdk submodule `023b678`) with `pfsshell-name32.patch` applied, built with `meson setup build && ninja -C build pfsshell`. Creates and packs 8 MB partitions. The patch is required: upstream `mkpart` writes "hdd0:" plus the partition name into a 37-byte buffer, one byte short for the 32-character names Game-Installer produces. Linux at -O0 truncates silently; macOS clang's fortified `sprintf` traps, pfsshell dies after the first prompt and the partition is never created. |
| `PFS Shell.elf` | Wrapper around `pfsshell`. Adds the EXT2 and EXT2SWAP formatting that the Linux build (AKuHAK's `ext2` branch) does inside `mkpart`, and the same eviction and retry as `HDL Dump.elf`. |
| `mkfs.exfat` | Wrapper that maps the Linux `mkfs.exfat` arguments onto `/sbin/newfs_exfat`. |
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

To rebuild `pfsshell` (needs `meson` and `ninja` from Homebrew):

```sh
git clone https://github.com/ps2homebrew/pfsshell.git
cd pfsshell
git submodule update --init --depth 1 external/ps2sdk
patch -p1 < /path/to/pfsshell-name32.patch
meson setup build -Denable_pfs2tar=false
ninja -C build pfsshell
```

Rehearsals that exercise these binaries the way the installers do, on a
file image and without sudo: `scripts/platform/darwin/tests/e2e-image.sh`
(PSBBN install) and `scripts/platform/darwin/tests/e2e-launchers.sh`
(Game-Installer launcher partitions, including the 32-character names).

# neutrino
Small, Fast and Modular PS2 Device Emulator

## Design
A neutrino is a particle with almost zero mass, and that's what this device emulator's primary goal is. To have almost 0 mass when emulating devices to maximize compatibility.

Neutrino also does not have a user interface, instead it's meant to be integrated as a backend to a frontend (user interface). This makes neutrino much more easy to maintain, and allows many more applications to be made using neutrino as the backend.

With neutrino all modules are... modular. They are in a separate folder called `modules`. This allows the user add new and improved modules. What modules are loaded is fully configurable using TOML config files in the `config` folder.

## Environments
An environment in neutrino describes what IOP modules are loaded and defines what features the environment has. In neutrino there are 3 environments:
- Boot Environment (BE): environment neutrino is loaded from (by uLE / ps2link / ...), containing neutrino, configuration files and drivers
- Load Environment (LE): neutrino's loader.elf reboots into the LE, containing virtual disk images
- Emulation Environment (EE): neutrino's ee_core.elf reboots into the EE, emulating devices

## Backing Store Driver (BSD)
A backing store driver provides a storage location for storing virtual disk images. For instance of DVD's, HDD's or MC's.
The following backing storage devices are supported:
Device             | PS2 model  | Speed                                                                            | Device comp.                       | Type         | BSD
-------------------|------------|----------------------------------------------------------------------------------|------------------------------------|--------------|----------
USB                | FAT + 70k  |![x](https://progress-bar.xyz/750?scale=2200&suffix=KB/s&&progress_color=d9534f)  | ![x](https://progress-bar.xyz/80)  | Block Device | `usb`
USB                | slim       |![x](https://progress-bar.xyz/900?scale=2200&suffix=KB/s)                         | ![x](https://progress-bar.xyz/80)  | Block Device | `usb`
MX4SIO             | slim       |![x](https://progress-bar.xyz/1150?scale=2200&suffix=KB/s)                        | ![x](https://progress-bar.xyz/60)  | Block Device | `mx4sio`
MMCE               | slim       |![x](https://progress-bar.xyz/1350?scale=2200&suffix=KB/s)                        | ![x](https://progress-bar.xyz/100) | File System  | `mmce`
MX4SIO             | FAT + 70k  |![x](https://progress-bar.xyz/1500?scale=2200&suffix=KB/s)                        | ![x](https://progress-bar.xyz/60)  | Block Device | `mx4sio`
MMCE               | FAT + 70k  |![x](https://progress-bar.xyz/1700?scale=2200&suffix=KB/s)                        | ![x](https://progress-bar.xyz/100) | File System  | `mmce`
iLink / IEEE1394   | FAT        |![x](https://progress-bar.xyz/6?scale=2&suffix=MB/s)                              | ![x](https://progress-bar.xyz/10)  | Block Device | `ilink`
UDPBD              | ALL        |![x](https://progress-bar.xyz/10?scale=2&suffix=MB/s)                             | ![x](https://progress-bar.xyz/100) | Block Device | `udpbd`
UDPFS              | ALL        |![x](https://progress-bar.xyz/10?scale=2&suffix=MB/s)                             | ![x](https://progress-bar.xyz/100) | File System  | `udpfs`
ATA (internal HDD) | FAT        |![x](https://progress-bar.xyz/30?scale=2&suffix=MB/s)                             | ![x](https://progress-bar.xyz/100) | Block Device | `ata`

Clarifying information:

- **PS2 model**: The older FAT PS2 models and the first slim PS2 model (70k) have the original PS1 MIPS R3000 CPU. Later slim PS2 models have a new CPU with 'DECKARD' emulating the MIPS R3000. This is why there is a speed difference between those two groups of PS2 models.

- **Speed**: USB, MX4SIO and MMCE have been tested with neutrino v1.5.0. The other speeds are based on older tests and should serve as an indication. For proper emulation of the ps2 DVD drive a speed of at least 2.2MB/s is needed. The slower the speed, the more likely video's will stutter. Due to game-bugs, some games will not even run if the device is too slow.

- **Device comp.**: how many devices will work with neutrino. For instance most USB sticks work, but some (mostly USB3.0 sticks) don't work. With mx4sio, many SD cards are not compatible, etc... Don't hold these values for fact, they are based on my personal observations and should give you an indication on what devices would fit your need.

- **Type**: How the device exposes itself to the PS2: as a file system with files that can be opened/closed read and written. Or as a block device with 512byte sectors.

- **BSD**: Name of the BSD for use with the neutrino command line, such as: `-bsd=ilink`

### Block devices
For block devices the PS2 will use it's own filesystem and partition drivers.

The following partitioning schemes are supported:
- MBR (Master Boot Record)
- GPT (GUID Partition Table)

The following file systems are supported:
- FAT32, accessable as `mass:<file>.iso`
- exFat, accessable as `mass:<file>.iso`
- HDLoader, accessable as `hdl:<file>`, `hdl:<file>.iso`, `hdl:<part>` or `hdl:<part>.iso`

Note that the HDLoader backing store is currently read-ony, and limited to only emulating the DVD.

### Block device fragmentation
During load neutrino will request all 'fragments' where virtual disk images are located. After rebooting into the Emulation Environment there is no more file system available, instead neutrino will access the sectors of the block device directly using a fragment table. A **maximum of 64 fragments** is supported for the combined total of the virtual disk images you need. If for instance you have 1 virtual DVD and 1 virtual MC (that's already 2 fragments), then they cannot have more than 64 fragments combined. If your (FAT32/exFat) drive is more fragmented you'll need to de-fragment your drive (details not covered here).

Note that this limitation only applies to the "block device" type, and not the "file system" type, even though it can be the uSD card. MX4SIO for instance is used as a block device with the 64 fragment limitation. But when inserting the same exFat formatted uSD card into an MMCE device, this limitation does not exist, becouse the CPU on MMCE device will completely handle the exFat filesystem.

## CD/DVD emulation
The following CD/DVD emulation drivers are supported:
- No: using original CD's / DVD's in the optical drive
- ESR: using ESR patched DVD's in the optical drive
- File: using an iso file from the backing store

## ATA HDD emulation
The following HDD emulation drivers are supported:
- No: using ATA HDD in the PS2
- File: using a virtual HDD image file from the backing store

## Usage instructions
Neutrino is a command line application. To get the most out of neutrino you will need to run it from the command line, for instance using [ps2link](https://github.com/ps2dev/ps2link) and [ps2client](https://github.com/ps2dev/ps2client).

Alternatively you can use a more user friendly GUI from one of the third-party projects (see below), but with a limited feature set.

Command line usage instructions:

```
Usage: neutrino.elf options

Options:
  -bsd=<driver>     Backing store drivers (optional, auto-detected from path prefix), supported are:
                    - no     (uses cdvd)
                    - ata    (block device)
                    - usb    (block device)
                    - mx4sio (block device)
                    - udpbd  (block device)
                    - udpfs  (file system)
                    - ilink  (block device)
                    - mmce   (file system)

  -bsdfs=<driver>   Backing store fileystem drivers used for block device, supported are:
                    - exfat (default)
                    - hdl   (HD Loader)
                    - bd    (Block Device)
                    NOTE: Used only for block devices (see -bsd)

  -dvd=<mode>       DVD emulation mode, supported are:
                    - no (default)
                    - esr
                    - <file>

  -ata0=<mode>      ATA HDD 0 emulation mode, supported are:
                    - no (default)
                    - <file>
                    NOTE: only both emulated, or both real.
                          mixing not possible
  -ata0id=<mode>    ATA 0 HDD ID emulation mode, supported are:
                    - no (default)
                    - <file>
                    NOTE: only supported if ata0 is present
  -ata1=<mode>      See -ata0=<mode>

  -mc0=<mode>       MC0 emulation mode, supported are:
                    - no (default)
                    - <file>
  -mc1=<mode>       See -mc0=<mode>

  -elf=<file>       ELF file to boot, supported are:
                    - auto (elf file from cd/dvd) (default)
                    - <file>

  -gc=<compat>      Game compatibility modes, supported are:
                    - 0: IOP: Fast reads (sceCdRead)
                    - 1: dummy
                    - 2: IOP: Sync reads (sceCdRead)
                    - 3: EE : Unhook syscalls
                    - 5: IOP: Emulate DVD-DL
                    - 7: IOP: Fix game buffer overrun
                    Multiple options possible, for example -gc=23

  -gsm=v:c          GS video mode

                    Parameter v = Force video mode to:
                    -         : don't force (default)  (480i/576i)
                    - fp1     : force 240p/288p - auto PAL/NTSC
                    - fp2     : force 480p/576p - auto PAL/NTSC
                    - 1080ix1 : force 1080i width x1, height x1 (very small!)
                    - 1080ix2 : force 1080i width x2, height x2
                    - 1080ix3 : force 1080i width x3, height x3

                    Parameter c = Compatibility mode:
                    -      : no compatibility mode (default)
                    - 1    : field flipping type 1 (GSM/OPL)
                    - 2    : field flipping type 2
                    - 3    : field flipping type 3

                    Examples:
                    -gsm=fp2      - recommended mode
                    -gsm=fp2:1    - recommended mode, with compatibility 1
                    -gsm=1080ix2

  -cwd=<path>       Change working directory

  -cfg=<file>       Load extra user/game specific config file (without .toml extension)

  -dbc              Enable debug colors
  -logo             Enable logo (adds rom0:PS2LOGO to arguments)
  -qb               Quick-Boot directly into load environment

  --b               Break, all following parameters are passed to the ELF

Usage examples:
  neutrino.elf -dvd=usb:path/to/filename.iso
  neutrino.elf -dvd=mx4sio:path/to/filename.iso
  neutrino.elf -dvd=mmce:path/to/filename.iso
  neutrino.elf -dvd=ilink:path/to/filename.iso
  neutrino.elf -dvd=udpbd:path/to/filename.iso
  neutrino.elf -dvd=udpfs:path/to/filename.iso
  neutrino.elf -dvd=ata:path/to/filename.iso
  neutrino.elf -bsd=ata -bsdfs=hdl -dvd=hdl:filename.iso
  neutrino.elf -bsd=udpbd -bsdfs=bd -dvd=bdfs:udp0p0
```

## UDPFS / UDPBD PC Server

The `pc/udpfs_server.py` script serves files and/or block devices to the PS2 over UDP (Ethernet).

### Requirements

- **Python 3** (no additional packages required for basic use)
- **`lz4`** — optional, required only for `.zso` (LZ4-compressed ISO) support:
  ```
  pip install lz4
  ```
- **`libchdr0`** — required for `.chd` (CHD compressed ISO) support:
  ```
  apt install libchdr0
  ```
  Build from source: https://github.com/rtissera/libchdr

The `pc/compressed_iso/` directory is a local module bundled with the server; no installation is needed.

### Usage

```
# Share a USB drive (or any block device) with many games — typical UDPBD use case
python pc/udpfs_server.py -b /dev/sdX          # Linux
python pc/udpfs_server.py -b \\.\PhysicalDriveX  # Windows

# Share a single disk image (UDPBD mode)
python pc/udpfs_server.py -b game.iso

# Share a directory as a filesystem (UDPFS mode)
python pc/udpfs_server.py -d /path/to/ps2games

# Share both a block device and a directory
python pc/udpfs_server.py -b /dev/sdX -d /path/to/ps2games

# With transparent decompression (.iso is appended to .zso/.cso/.chd names)
python pc/udpfs_server.py -d /games --enable-compression

# Read-only mode
python pc/udpfs_server.py -b /dev/sdX --read-only
```

### Compression support

When `--enable-compression` is passed, the server transparently decompresses compressed ISO images:

Format | Extension | Compression          | Extra dependency
-------|-----------|----------------------|----------------
ZSO    | `.zso`    | LZ4                  | `pip install lz4`
CSO    | `.cso`    | zlib                 | none
CHD    | `.chd`    | zlib/lzma/huff/flac  | `apt install libchdr0`

## Third-Party Loaders
The following third-party projects use neutrino:

Loader | Author
-|-
[XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) | sync-on-luma
[NHDDL](https://github.com/pcm720/nhddl) | pcm720
[RETROLauncher](https://github.com/Spaghetticode-Boon-Tobias/RETROLauncher) | Boon Tobias
[OSD-XMB](https://github.com/HiroTex/OSD-XMB) | Hiro Tex
[PSBBN](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch) + [BBNL](https://github.com/pcm720/bbnl) | CosmicScale + pcm720
[RiptOPL](https://github.com/NathanNeurotic/Open-PS2-Loader) | NathanNeurotic
[wOPL](https://github.com/ps2homebrew/wOPL) | KrahJohlito
[Modulo](https://github.com/AdityaKumar7209/Modulo-R1-Beta-Preview---PS2) | AdityaKumar7209

Add your project here? Send me a PR.

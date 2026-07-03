# PSBBN Definitive English Patch

This is the Definitive English Patch for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console.

PSBBN is official Sony software for the PlayStation 2, released exclusively in Japan. Introduced in 2002 as a replacement for the PS2’s OSD, it required both a hard drive and a network adapter to function. It added many new features:
- Launching games from the hard drive
- Accessing online channels
- Downloading full games, demos, videos, and pictures
- Ripping audio CDs and transferring music to MiniDisc recorders in the Music Channel
- Watching videos in the Movie Channel
- Transferring photos from a digital camera and viewing them in the Photo Channel

This project aims to translate PSBBN from Japanese to English, introduce modern features, and make it a viable daily driver in 2025 and beyond.

You can find out more about the PSBBN software on [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) and on my [YouTube channel](https://www.youtube.com/@CosmicScaleFactor).

# Donations  
If you appreciate my work and want to support the ongoing development of the PSBBN Definitive English Patch and other PS2-related projects, [you can donate to my Ko-Fi](https://ko-fi.com/cosmicscale).

This project uses [webhook.site](https://webhook.site/) to automatically contribute game artwork/icons and report missing artwork/icons to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) and the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). As the project has grow in popularity, we're exceeding the limit offered by a free account. A paid subscription costs $9/month or $90/year, donations help fund this.

# Video demonstration of PSBBN

[![PSBBN in 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Patch Features
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console as well as PS2 Slim SCPH-700xx models with an [IDE Resurrector](#slim-ps2-console-model-scph-700xx) or similar hardware mod, regardless of region
- DNAS authorization checks bypassed to enable access the online channels
- Online game channels from Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, and Bandai have been translated into English (work in progress). Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing [compatibility with NetMD MiniDisc Recorders](#known-issues)
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard**
- The `cross` and `circle` buttons have been swapped: `cross` is now Enter, and `circle` is now Back.
- Support for the PlayStation 2 DVD remote control
- Direct link to the Game Collection in the Top Menu
- Launch up to 800 PS1/PS2 games and apps directly from the Game Collection
- Large HDD support: no longer limited to 128 GB. It now supports larger drives, with 128 GB allocated to the PlayStation File System (PFS) and up to 2 TB allocated to exFAT
- 2 TB storage capacity for both PS2 games and homebrew apps
- [POPS](#popstarter-and-virtual-memory-cards) partition up to 111 GB for PS1 games
- [VMC Groups](#popstarter-and-virtual-memory-cards) for PS1 games
- Full [Game ID](#game-id) support for the Pixel FX Retro GEM and MemCard Pro/SD2PSX
- Set a custom size for your music partition. Originally limited to 5 GB. Now the partition can be up to 111 GB for around 170 albums
- Set a custom size for your contents partition for the storage of movies and photos. Originally limited to 5 GB, can now be up to 111 GB
- [PSBBN installer](#psbbn-installer) makes setup easy
- [Game and App Installer](#game-and-app-installer) fully automates the installation of PS1/PS2 games as well as `ELF` and [SAS-compliant](#save-application-system-sas) homebrew apps
- A choice of [OPL](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for you game launcher
- Includes the apps [wLaunchELF_ISR](#wlaunchelf_isr) and [Retro GEM Disc Launcher](#launch-disc), with a choice of either [OPL](#open-ps2-loader-opl) or [NHDDL](#neutrino-and-nhddl)
- [Media Installer](#media-installer) for converting and installing music
- Install [optional extras](#extras) such as [HDD-OSD (Browser 2.0)](#hdd-osd-browser-20), [PS2BBL](#playstation-2-basic-boot-loader-ps2bbl) and [PS2 Linux](#ps2-linux)

# Changelog

## September 09, 2025 - PSBBN Launcher for Windows: Easy Install & Setup

[![PSBBN Launcher for Windows: Easy Install & Setup](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**[NEW! PSBBN Launcher For Windows](#installing-on-windows)** - The New way to install the **PSBBN Definitive Patch** on Windows 10 and 11.  
Special thanks to Yornn for all his work on this feature.

## August 28, 2025 - PSBBN Definitive Patch v3.00 - Music Installer, Menu System, Faster Installs & More!

<details>
<summary><b>Release Notes:</b></summary>
  
[![PSBBN Definitive English Patch 3.0](https://github.com/user-attachments/assets/3b82d809-28d5-4675-87c2-c7f1abf96ae6)](https://www.youtube.com/watch?v=lUMKZck6G08) 
  
**[NEW! Menu System:](#main-menu)**
- New central menu system instead of separate scripts, making it easier to navigate the various features of the PSBBN Definitive Patch
- Setup now runs automatically if missing dependencies are detected

**[NEW! Music Installer:](#music-installer)**
- Install music for playback on the PSBBN Music Channel. Supported formats: `.mp3`, `.m4a`, `.flac`, and `.ogg`

**[NEW! PSBBN Installer:](#psbbn-installer)**
- PSBBN has fully transitioned from ReiserFS (an old, no-longer-supported filesystem) to ext2, allowing direct access to all BBN partitions
- The new PSBBN Installer works with a tar archive instead of a disk image, reducing download size and drastically improving install time
- When installing, you can set a custom size for the `contents` partition used for movies and photos (previously limited to 5 GB)
- Increased maximum size of the Music, Contents, and POPS partitions — now up to 111 GB

**[NEW! PSBBN Updater:](#update-psbbn-software)**
- Allows updating to the latest version of the Definitive Patch directly from the menu. No USB thumb drive or USB keyboard required!

**[Game Installer:](#game-and-app-installer)**
- The game installer now offers an HDTV fix for PS1 games, allowing them to display on TVs that do not support 240p
- Bug fixes and improved Game ID extraction for ISO and VCD files.  
- Extracts Game ID directly from ZSO files by decompressing only part of the disc image; ZSO files no longer need to be fully decompressed or renamed, greatly improving processing time

**[Extras:](#extras)**
- PS2 Linux is now an optional install. You can set a custom size for your home partition. PS2 Linux can also be reinstalled if you experience issues
- Swap the functions of the Cross and Circle buttons on your controller. Choose between the standard layout (Cross = Enter, Circle = Back) or the alternate layout (Circle = Enter, Cross = Back)

**[HDD-OSD (Browser 2.0):](#hdd-osd-browser-20)**
- New PSBBN icon designed by Yornn
- New improved background colour when viewing game icons

</details>

## July 17, 2025 - Definitive Patch v2.11 - Boot Security Patched! Button Swap, VMC Groups & More!

<details>
<summary><b>Release Notes:</b></summary>
  
[![PSBBN Definitive Patch v2.11](https://github.com/user-attachments/assets/49511803-429b-4cd8-8546-40334be3f244)](https://www.youtube.com/watch?v=kgXe8rlqsr0)

**PSBBN Updated to Definitive Patch v2.11**

Patch v2.11 can be installed by running the [PSBBN Installer script](#psbbn-installer) (all data will be lost), or via the new `Update PSBBN Software` option in the [Extras script](#extras) (requires a FAT32-formatted USB drive, 128 GB or smaller, and a USB keyboard to complete setup).

New in Definitive Patch v2.11:
- Boot Security Patched. The CRC security check in PSBBN’s boot ELF has been bypassed, allowing the loading of custom kernels.
- The `cross` and `circle` buttons have been swapped: `cross` is now Enter, and `circle` is now Back.
- Added support for the PlayStation 2 DVD remote control. The `PLAY`, `PAUSE`, `STOP`, `PREV`, `NEXT`, `SCAN`, and `DISPLAY` buttons can now be used during music and movie playback in the Music and Movie channels. The `ENTER` button can also be used when navigating menus.
- The `PlayStation BB Guide` has been updated to reflect the button swap and the relocation of the `Game Collection`. A new section has been added covering the Online Channels. Numerous improvements to the English translation.
- Improves the update process. A USB drive and keyboard will not be required for future updates.

**`02-PSBBN-Installer.sh`:**
- You can now set a custom size for the [POPS](#popstarter-and-virtual-memory-cards) partition. Previously, it filled all remaining space after creating the music partition.

**`03-Game-Installer.sh`, `ps2iconmaker.sh` & `txt_to_icon_sys.py`:**

- Multi-disc PS1 games now support disc swapping without additional setup. A `DISCS.TXT` file is created for every multi-disc game. Multi-disc games also now share a [POPStarter Virtual Memory Card (VMC)](#popstarter-and-virtual-memory-cards)
- [POPStarter VMC Groups](#popstarter-and-virtual-memory-cards) for PS1 games: games that can interact with each other's save data now share a single VMC. For example, licenses earned in Gran Turismo can be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis can comment on other Konami games you've played.
- VMCs now display clearer titles in `Save Data Management` and `Browser 2.0` with custom icons for each game and group.
- The game installer now automatically generates HDD-OSD (Browser 2.0) icons if not found on the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If cover images for a game are available in the OPL Manager Art Database, a 3D icon for the game will be automatically generated. 3D icons are also created for VMCs when a game logo is available. All newly generated icons are automatically contributed to the HDD-OSD Icon Database, and missing icons are reported.
- Fixed a bug where incorrect publisher information could be displayed for `ELF` files

**`list-builder.py`:**

- Improved Game ID extraction for edge cases. Now handles non-standard IDs like `LSP99016.101` and PS1 games with non-standard `system.cnf` files.

**Neutrino Updated to Version 1.7.0**

- Full changelog for Neutrino can be found [here](https://github.com/rickgaiser/neutrino/releases/tag/v1.7.0)

**Open PS2 Loader Updated to v1.2.0 Beta-2210-6b300b0**
- Adds support for VMC Groups and bug fixes.

**wLaunchELF**
- Upgraded to [wLaunchELF v4.43x_isr](#wlaunchelf_isr). Improves stability, and adds support for exFAT on external drives and MMCE (SD card browsing on Mem Card Pro 2/SD2PSX).

</details>

## June 05, 2025 - PSBBN Definitive Patch v2.10 – Big Game Installer Changes & More!

<details>
<summary><b>Release Notes:</b></summary>

[![PSBBN Definitive Patch v2.10](https://github.com/user-attachments/assets/ff4e6e5b-8556-4fe2-88b2-99e7eb09121c)](https://www.youtube.com/watch?v=XTacIPOGAwE)

**PFS Shell.elf & HDL Dump.elf:**

- PFS Shell updated to support creating 8 MB PFS partitions
- HDL Dump updated to properly modify their headers

**PSBBN Disk Image Updated to Version 2.10:**

- Disk created with a new version of PFS Shell for full compatibility with 8 MB PFS partitions 
- Added a direct link to the Game Collection in the Top Menu  
- Improved boot time for users without a connected Ethernet cable  
- Modified the startup script to format and initialize the Music partition, allowing it to be smaller or larger than before.
- Reduced delay before button presses are registered when booting into Linux  
- PS2 Linux partition now uses `ext2` instead of `reiserfs`   
- Removed ISP Settings from the Top Menu  
- Removed Open PS2 Loader shortcut from the Navigator Menu (user can add a shortcut to their choice of game launcher manually)
- Modified shortcuts to [LaunchELF](https://github.com/ps2homebrew/wLaunchELF) and [Launch Disc](#launch-disc)
- Updated the About PlayStation BB Navigator page  
- Enabled telnet access to PSBBN for development purposes  
- Corrections to the English translation  

**`02-PSBBN-Installer.sh`:**

- Prevents the script from installing the PSBBN Definitive Patch if the version is below 2.10  
- Partitions the remaining space of the first 128 GB of the drive:
  - Music partition can now range between 1 GB and 104 GB  
  - [POPS](#popstarter-and-virtual-memory-cards) partition can now range between 1 GB and 104 GB  
  - Space reserved for 800 [BBNL](#bbn-launcher-bbnl) partitions  
- Removed [POPS](#popstarter-and-virtual-memory-cards) installer (now handled by the Game Installer script)  
- Code has been significantly cleaned up and optimized  

**`03-Game-Installer.sh`:**

- Added a warning for users running PSBBN Definitive Patch below version 2.10
- The PS2 drive is now auto-detected  
- Added an option to set a custom path to the `games` folder on your PC
- Allows new games and apps to be added without requiring a full sync  
- [BBNL](#bbn-launcher-bbnl) partition size reduced from 128 MB to 8 MB, enabling up to 800 games/apps to be displayed in the Game Collection
- Fixed a bug preventing games with superscript numbers in their titles from launching  
- General improvements to error checking and messaging  
- Fixed issues detecting success/failure of some `rsync` commands  
- `rsync` now runs only when needed  
- Improved update process for [POPStarter](#popstarter-and-virtual-memory-cards), [OPL](#open-ps2-loader-opl), [NHDDL, and Neutrino](#neutrino-and-nhddl)
- Game Installer now installs [POPS](#popstarter-and-virtual-memory-cards) binaries if missing  
- Reduced number of commands executed with `sudo`  
- `ELF` files are now installed in folders and include a `title.cfg`  
- Code has been significantly cleaned up and optimized  

**`list-builder.py`:**

- Merged `list-builder-ps1.py` and `list-builder-ps2.py` into a single script  
- Now extracts game IDs for both PS1 and PS2 games  

**`list-sorter.py`:**

- Game sorting logic has been moved here from the previous list builder scripts  
- Sorting has been significantly improved  

**General**

- PSBBN Installer and Game Installer scripts now prevent the PC from sleeping during execution  
- Added a check in each script to ensure it is run using Bash  
- Updated README.md

</details>

## May 01, 2025 - SAS, HDD-OSD, PS2BBL & More!

<details>
<summary><b>Release Notes:</b></summary>

[![SAS, HDD-OSD, PS2BBL & More!](https://github.com/user-attachments/assets/be5b32d2-665c-4505-aefe-3c9ab864f72a)](https://www.youtube.com/watch?v=vpbHlS8nY58)

- Added support for the [Save Application System (SAS)](#save-application-system-sas). `PSU` files can now also be placed in the local `games/APPS` folder on your PC and will be installed by the `03-Game-Installer.sh` script
- Added support for HDD-OSD to the `03-Game-Installer.sh` script. 3D icons are now downloaded from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- New script: [04-Extras.sh](#extras). Added ability to install HDD-OSD and [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
- Make your own HDD-OSD icons with the [HDD-OSD Icon Templates](https://github.com/CosmicScale/HDD-OSD-Icon-Database/releases/download/v1.0.0/HDD-OSD-Icon-Templates.zip)
- Translate PSBBN using the [Translation Pack](https://mega.nz/file/iBUh2SaT#TrbFtoj6rjONfaiYnfyCxLPms01iJclva_gr6bJAFd0) to localize the software into different languages.

</details>

## Mar 28, 2025 - Homebrew Launcher & More!

<details>
<summary><b>Release Notes:</b></summary>

[![Homebrew Launcher & More!](https://github.com/user-attachments/assets/57e7842c-f5b5-46b0-950e-246eebfb0e4a)](https://www.youtube.com/watch?v=q9LvE_OPIPo)

- [Open PS2 Loader](#open-ps2-loader-opl) updated to version 1.2.0-Beta-2201-4b6cc21:
  - Limited max BDM UDMA mode to UDMA4 to avoid compatibility issues with various SATA/IDE2SD adapters
- Added a manual for PS1 games. It can be accessed in the Game Collection by selecting a game, pressing Triangle, and then selecting `Manual`
- Transitioned to [BBN Launcher (BBNL)](#bbn-launcher-bbnl) version 2.0:
  - Dropped APA support in favour of loading [OPL](#open-ps2-loader-opl), [POPStarter](#popstarter-and-virtual-memory-cards), [Neutrino](#neutrino-and-nhddl), and configuration files from the exFAT partition to speed up initialization.
  - Moved [BBNL](#bbn-launcher-bbnl) to the APA header to further improve loading times.
  - Removed dependency on renamed [POPStarter](#popstarter-and-virtual-memory-cards) `ELF` files to launch PS1 VCDs; [POPStarter](#popstarter-and-virtual-memory-cards) is now launched directly with a boot argument.
  - [NHDDL](https://github.com/pcm720/nhddl) now launches in ATA mode, improving startup time and avoiding potential error messages.
- Updated [Neutrino](#neutrino-and-nhddl) to version 1.6.1
- Updated [NHDDL](#neutrino-and-nhddl) to version MMCE + HDL Beta 4.17
- Added cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups). Artwork for PS2 games is now displayed in OPL/NHDDL
- Added homebrew support to the `03-Game-Installer.sh` script. `ELF` files placed in the local `games/APPS` folder on your PC will be installed and appear in the Game Collection in PSBBN and the Apps tab in OPL
- Apps now support [Game ID](#game-id) for both the Pixel FX Retro GEM and MemCard Pro/SD2PSX

</details>

## Feb 19, 2025 - BBN Launcher, Neutrino & NHDDL

<details>
<summary><b>Release Notes:</b></summary>

[![BBN Launcher, Neutrino & NHDDL](https://github.com/user-attachments/assets/8007d102-3019-4037-8c52-24d1454777da)](https://www.youtube.com/watch?v=0vpSiAa6ITc)

- [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) has been replaced by [BBN Launcher (BBNL)](#bbn-launcher-bbnl)
- Added [Neutrino](#neutrino-and-nhddl) support. You can now choose between [Open PS2 Loader](#open-ps2-loader-opl) and [Neutrino](#neutrino-and-nhddl) as your game launcher
- When using Neutrino as your game launcher, [NHDDL](#neutrino-and-nhddl) can be used to make per-game settings

</details>

## Jan 22, 2025 - Game ID, PSBBN Art Database, Updated Tutorial & More!

<details>
<summary><b>Release Notes:</b></summary>

[![Game ID, PSBBN Art Database, Updated Tutorial & More!](https://github.com/user-attachments/assets/1bae03fe-b3eb-447e-99da-8f184279a848)](https://www.youtube.com/watch?v=sHz0yKYybhk)

- Added [Game ID](#game-id) support for the Pixel FX Retro GEM, as well as MemCard Pro 2 and SD2PSX. Works for both PS1 and PS2 games
- PS2 games now launch up to 5 seconds faster
- Resolved conflict with mass storage devices (USB, iLink, MX4SIO). Games now launch without issues if these devices are connected
- Apps now automatically update when you sync your games
- The art downloader has been improved to grab significantly more artwork
- Improved error handling in the PSBBN installer script
- The setup script has been modified to work on live Linux environments without issues
- Added support for Arch-based and Fedora-based Linux distributions in addition to Debian
- Added confirmation prompts to the PSBBN installer script when creating partitions
- PSBBN image updated to version 2.01:
  - Set USB keyboard layout to US English. Press `ALT+~` to toggle between kana and direct input
  - Minor corrections to the English translation
- Added [Open PS2 Loader](#open-ps2-loader-opl) and [Launch Disc](#launch-disc) to the Game Collection
- The Game Installer script has been updated to create and delete game partitions as needed. Say goodbye to those annoying "Coming soon..." placeholders!
- Files placed in the `CFG`, `CHT`, `LNG`, `THM`, and `APPS` folders on your PC will now be copied to the PS2 drive during game sync
- The scripts now auto-update when an update is available
- Optimised art work
- Introducing the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database)
- If artwork is not found in the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), an attempt is made to download from IGN. Art downloads from IGN are now automatically contributed to the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), and missing artwork is also automatically reported. Manual submissions are welcome, see the [PSBBN art database GitHub page](https://github.com/CosmicScale/psbbn-art-database) for details

</details>

## Dec 11, 2024 - PSBBN Definitive English Patch 2.0

<details>
<summary><b>Release Notes:</b></summary>

[![PSBBN Definitive English Patch 2.0](https://github.com/user-attachments/assets/608c9430-25d8-4918-8111-023eac16ab62)](https://www.youtube.com/watch?v=ooH0FjltsyE)

- Initial release of patch version 2.0
- Bandai and SCEI online channels have been added to the Game Channel
- PS2 Linux dual-boot
- [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) pre-installed
- Large HDD support: no longer limited to 128 GB
- Introducing [APA-Jail](#apa-jail), allowing the PlayStation's PFS partitions to co-exist with an exFAT partition
- Introducing [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM), allowing PS2 games stored on the exFAT partition to be launched from within PSBBN
- Introducing the [PSBBN Installer script](#psbbn-installer):
  - Installs PSBBN, [POPS binaries and POPStarter](#popstarter-and-virtual-memory-cards)
  - Partition the first 128 GB of the drive as PFS:
    - Create up to 700 OPL launcher partitions
    - Custom size music partition from 10 GB to max 97 GB
    - Remaining space allocated to [POPS](#popstarter-and-virtual-memory-cards) partition for PS1 games
  - Creates an exFAT partition with drive space beyond the first 128 GB for storage of PS2 games
- Introducing the [Game Installer script](#game-and-app-installer):
  - Fully automates the installation of PS1 and PS2 games
  - Creates all assets and meta-data
  - Downloads game artwork from IGN

</details>  

# User Guide
The PSBBN Definitive Patch script is essential for unlocking all the new features exclusive to version 2.0 and above. The script require an x86-64 processor and a 64-bit operating system. ARM-based systems, including Apple Silicon, are not supported.

PSBBN requires a Fat PS2 console (**SCPH-3000x to SCPH-500xx**) with an expansion bay and an [official Sony Network Adapter](#known-issues).  

It is also compatible with the PS2 Slim **SCPH-700xx** model with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod and **SCPH-10000 to SCPH-18000** models with an official external HDD enclosure, as long as the drive in the enclosure has been replaced with one that is 200 GB or larger. [Additional setup is required for these consoles](#early-scph-10000–18000-and-slim-scph-700xx-consoles).

For expansion bay type consoles, I would highly recommend using a **Kaico or BitFunx IDE to SATA Upgrade Kit**

You also require a HDD/SSD for your PS2 that is at least 200 GB, ideally 500 GB to 2 TB. A SATA SSD is also highly recommended. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface. You can connect the HDD/SSD to your PC either directly via SATA or using a USB adapter.

### Installing on Linux
Debian-based distributions using `apt`, Arch-based distributions using `pacman`, and Fedora-based distributions using `dnf` are supported.

<span style="font-size: 17px; font-weight: bold;">It is highly recommended to install the scripts using `git clone` to enable automatic updates:</span>

Install git, for Debian-based distributions run:
```
sudo apt update
sudo apt install git
```
Clone the repository:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git
```

You can then change to the `PSBBN-Definitive-English-Patch` directory and run `PSBBN-Definitive-Patch.sh`:
```
cd PSBBN-Definitive-English-Patch
./PSBBN-Definitive-Patch.sh
```
### Installing on Windows
The recommended way to install the PSBBN Definitive Patch on Windows 10 and 11 is to use the **PSBBN Launcher For Windows**.

**Video Tutorial:**

[![PSBBN Launcher for Windows: Easy Install & Setup](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**Enabling Virtualization:**  
It may be necessary to enable SVM Mode (for AMD CPUs) or VT-x (for Intel CPUs) in your BIOS settings if they are not already enabled. Instructions on how to do this can be found [here](https://www.elevenforum.com/t/enable-or-disable-cpu-virtualization-in-uefi-bios-firmware-settings-on-windows-pc.4928/).

Download the **PSBBN Launcher for Windows** [here](https://raw.githubusercontent.com/CosmicScale/PSBBN-Definitive-Project/refs/heads/release-v3.00/scripts/PSBBN-Launcher-For-Windows.ps1) (Right-click and select **Save link as**).

**Set the PowerShell Execution Policy:**  
Before running the script for the first time, you must change the execution policy in PowerShell:
1. Open a new PowerShell window from the **Start menu** by searching for **PowerShell** and select **Run as Administrator**.
2. Type the following command and press Enter:

```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

**You are now ready to run the script:**  
Right-click on `PSBBN-Launcher-For-Windows.ps1` and select **Run with PowerShell**.

The script will:
- Automatically set up the [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/about)
- Prompt you to select a **drive** and `games` folder
- Launch the **PSBBN Definitive Patch** [Main Menu](#main-menu)

**Accessing the PSBBN Definitive Patch Main Menu in the Future:**  
Simply right-click on `PSBBN-Launcher-For-Windows.ps1` and select **Run with PowerShell**

**NOTE:**  
Always exit the PSBBN Definitive Patch Main Menu by pressing `q` to quit. This ensures the drive is unmounted from WSL. If you are using a drive connected via USB, remember to also eject it from the Windows system tray.

## Main Menu
`PSBBN-Definitive-Patch.sh` is your gateway to the PSBBN Definitive Patch. Running this script launches the main menu.  
If this is your first time running the script or you are missing dependencies, the setup process will automatically run and install everything required.  

From the main menu, you will have the following options:

1. [Install PSBBN](#psbbn-installer)  
   Performs a fresh install of PSBBN.

2. [Update PSBBN Software](#update-psbbn-software)  
   Updates an existing install to the latest version of the PSBBN Definitive Patch.

3. [Install Games and Apps](#game-and-app-installer)  
   Installs PS1 and PS2 games, plus homebrew apps.

4. [Install Media](#media-installer)  
   1. [Install Music](#music-installer)
   4. [Set Media Location](#set-media-location)
   5. [Initialise Music Partition](#initialise-music-partition)

5. [Optional Extras](#extras)  
   1. [Install PS2 Linux](#ps2-linux)
   2. [Install HDD-OSD (Browser 2.0)](#hdd-osd-browser-20)
   3. [Install PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
   4. [Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)](#uninstall-playstation-2-basic-boot-loader-ps2bbl)
   5. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons)

## PSBBN Installer
Fully automates the installation of PSBBN:
- Formats the drive for a clean installation
- Downloads and installs the latest version of the **PSBBN Definitive English Patch** from [archive.org](https://archive.org/)
- Creates partitions for the Music, Contents (to store movies and photos) and [POPS](#popstarter-and-virtual-memory-cards) (to store PS1 games), with user-defined sizes on the first 128 GB of the drive.
- Reserves space for 800 [BBN Launcher](#bbn-launcher-bbnl) partitions, used to launch games and apps.
- Runs [APA-Jail](#apa-jail), creating an exFAT partition using all remaining disk space beyond the first 128 GB (up to 2 TB) for the storage of PS2 games and apps

## Update PSBBN Software
Selecting this option will check online for the latest version of the PSBBN Definitive Patch and installs it automatically. All your games, settings, and personal data will remain intact.

## Game and App Installer
Fully automates the installation of PS1 and PS2 games, as well as homebrew apps:
- Auto-detects your PS2 drive
- Let you set a custom path to the `games` folder on your PC
- Gives you a choice of [Open PS2 Loader (OPL)](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for the game launcher
- Installs any available updates for [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [Neutrino, NHDDL](#neutrino-and-nhddl), [Retro GEM Disc Launcher](#launch-disc), and [wLaunchELF_ISR](#wlaunchelf_isr)
- Downloads and installs the [POPS](#popstarter-and-virtual-memory-cards) binaries and installs [POPStarter](#popstarter-and-virtual-memory-cards)
- Offers the option to apply a HDTV fix for PS1 games, useful for users with a TV that does not support 240p
- Offers the option to synchronise the games and apps on your PC with your PS2's drive, or to add additional games and apps
- Creates all assets including meta-data, artwork and icons for all your games/apps
- Downloads artwork for the PSBBN Game Collection from the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) or IGN if not found in the database
- Automatically contributes game artwork downloaded from IGN and reports missing artwork to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
- Downloads cover art for PS2 games from the [OPL Manager art database](https://oplmanager.com/site/?backups) for display in [OPL](#open-ps2-loader-opl)/[NHDDL](#neutrino-and-nhddl)
- Creates [Virtual Memory Cards (VMCs)](#popstarter-and-virtual-memory-cards) for all PS1 games. Creates VMC Groups for for games that can interact with each other's save data
- Downloads icons for both games and [VMCs](#popstarter-and-virtual-memory-cards) for use with HDD-OSD/Browser 2.0 from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If icons are unavailable, but images for a game are available in the [OPL Manager Art Database](https://oplmanager.com/site/?backups), 3D icons will be automatically created.
- Automatically contributes HDD-OSD icons and reports missing icons to the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Creates [BBN Launcher](#bbn-launcher-bbnl) partitions, making games and apps launchable from the PSBBN Game Collection and HDD-OSD

### Synchronize All Games and Apps

The script lets you set the location of the `games` folder on your PC. Simply place your files in the `games` folder: PS2 `ISO` or `ZSO` files in the `CD`/`DVD` folders, PS1 `VCD` files in the `POPS` folder, and `ELF` or 
[SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder. To add or delete games and apps, just modify the contents of the `games` folder on your PC, then run the script and select `Synchronize All Games and Apps`.

### Add Additional Games and Apps

Alternatively, you can add PS2 games directly to the exFAT partition of your PS2 drive by placing `ISO` or `ZSO` files in the `CD` or `DVD` folders, and `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder. Then run the script and select `Add Additional Games and Apps`. This will add the new content to the PSBBN Game Collection and HDD-OSD. Additionally, any new PS1 and PS2 games and apps found in the `games` folder on your PC will also be installed.

**Note:** PS1 games can only be installed by placing the `VCD` files in the `games/POPS` folder on your PC.

Additionally, PS2 games and homebrew apps can be manually deleted from the exFAT partition on the PS2 drive, and PS1 games can be deleted from the PFS `__.POPS` partition. Running the script and selecting `Add Additional Games and Apps` will remove any deleted games from the PSBBN Game Channel and HDD-OSD.

### Sorting
In the PSBBN Game Collection, items are grouped into PS1 games, PS2 games, and homebrew apps. PS1 and PS2 games are sorted alphabetically and organized by game series, with games in a series ordered by release date. Homebrew apps are sorted alphabetically, while SAS apps are further divided into sub-groups based on app type (system, game, emulator, etc.).

## Media Installer
Select `Install Media` from the main menu and you will be presented with the following option:
1. [Install Music](#music-installer)
4. [Set Media Location](#set-media-location)
5. [Initialise Music Partition](#initialise-music-partition)

### Music Installer
Install music for playback on the PSBBN Music Channel. To use the Music Installer, you must be running PSBBN Definitive Patch version 3.00 or later. If you have previously upgraded from a lower version, you must [Initialise the Music Partition](#initialise-music-partition) first.

Supported formats are `.mp3`, `.m4a`, `.flac` and `.ogg`. Each file’s metadata must include the album title and track number. Place your music files in the default `music` folder, or choose a custom location using [Set Media Location](#set-media-location) and place the files its `music` subfolder.

### Set Media Location
Set a custom location for your media folder. Music should be placed in a `music` subfolder.

### Initialise Music Partition
Erases all music data from PSBBN and resets the music database. Use this option if you have upgraded from a version of PSBBN Definitive Patch lower than 3.00, in order to use the [Music Installer](#music-installer). You can also use this option if you experience problems with the Music Channel.

## Extras
Select `Optional Extras` from the main menu and you will be presented with the following option:
1. [Install PS2 Linux](#ps2-linux)
2. [Install HDD-OSD (Browser 2.0)](#hdd-osd-browser-20)
3. [Install PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
4. [Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)](#uninstall-playstation-2-basic-boot-loader-ps2bbl)
5. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons)

### PS2 Linux
PlayStation 2 Linux is an official kit from Sony that turned the PS2 into a Linux-based personal computer.  
The `Install PS2 Linux` option allows you to install or reinstall PS2 Linux.

To install PS2 Linux you need at least 3 GB of free space on your PS2 drive. During installation, you will be asked to set the size of your home directory (used for storing personal files and apps).

When reinstalling Linux:  
- If Linux came pre-installed with your version of the PSBBN Definitive Patch, all PS2 Linux data will be erased, including your home directory.  
- If you installed or reinstalled Linux using this menu, only the system files will be reinstalled — your personal files in the home directory will not be affected.

**Notes:**  
- To launch PS2 Linux, power on your PS2 console, wait for the `PlayStation 2` logo, then hold any button on the controller until the spinning orbs stop. PS2 Linux will then boot.  
- PS2 Linux requires a USB keyboard; a mouse is optional but recommended.  
- The `root` password is `password`. There is also a `ps2` user account with the password `password`.  
- To start a graphical interface, type `startx` at the command line.  
- Launching the `Dillo` web browser will open a mirror of the old official PS2 Linux website, where you can find a wide range of software to download and try.  

### HDD-OSD (Browser 2.0)
`HDD-OSD (Browser 2.0)` is an enhanced version of the PlayStation 2’s system menu that adds hard drive support, letting you manage software, save data, and launch games/apps directly from the HDD. It is fully compatible with both the official Sony Network Adapter and 3rd-party HDD adapters.

`HDD-OSD (Browser 2.0)` can be launched from the PSBBN Game Channel, or, if [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl) is installed, by holding down the `cross` button while the console starts up.

Games installed with the [Game Installer](#game-and-app-installer) will appear in the Browser represented by 3D icons modelled after the game case. Apps downloaded from the [Save Application System Apps Archive](https://ps2wiki.github.io/sas-apps-archive/) will also be represented by unique icons. [POPStarter virtual memory cards](#popstarter-and-virtual-memory-cards) also get unique icons.  

Game and VMC icons are downloaded from, and contributed to, the [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database).  

**Note:**  
`HDD-OSD (Browser 2.0)` is not compatible with drives larger than 1 TB.

### PlayStation 2 Basic Boot Loader (PS2BBL)
If you choose to install the [PlayStation 2 Basic Boot Loader (PS2BBL)](https://israpps.github.io/PlayStation2-Basic-BootLoader/), the console will auto-boot into PSBBN unless the `cross` button is held during startup, in which case [HDD-OSD (Browser 2.0)](#hdd-osd-browser-20) will be launched instead (if installed).

Launch keys and other settings for PS2BBL can be modified by editing the `CONFIG.INI` file stored on the internal drive at `__sysconf/PS2BBL`, more info can be found [here](https://israpps.github.io/PlayStation2-Basic-BootLoader/documentation/configuration.html).

### Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)
Provides the option to uninstall [PS2BBL](#playstation-2-basic-boot-loader-ps2bbl), returning the boot process to normal.

### Reassign Cross and Circle Buttons
This option lets you swap the functions of the `cross` and `circle` buttons on your controller. You can choose between the standard layout (`cross` = enter, `circle` = back) or the alternate layout (`circle` = enter, `cross` = back), depending on your preference.

# Notes
## Exiting Games
- To quit PS1 games, press `L1 + SELECT + START`
- If you are using [OPL](#open-ps2-loader-opl) as your game launcher, to quit PS2 games, press `L1 + L2 + R1 + R2 + SELECT + START` and to power off the console press `L1 + L2 + L3 + R1 + R2 + R3`

## BBN Launcher (BBNL)
[BBN Launcher](https://github.com/pcm720/bbnl) is a multi-purpose launcher co-developed by [pcm720](https://github.com/pcm720) and [CosmicScale](https://github.com/CosmicScale). It is responsible for launching PS1 games (via [POPStarter](#popstarter-and-virtual-memory-cards)), PS2 games (via [OPL](#open-ps2-loader-opl) and [Neutrino](#neutrino-and-nhddl)), and homebrew `ELF` files from the PSBBN Game Collection.

## Open PS2 Loader (OPL)
[Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) is a 100% open source game and application loader for the PS2.
- If you selected OPL as your game launcher, per-game settings assigned in OPL are reflected when launching games from the PSBBN Game Collection
- If OPL freezes at startup, delete any existing OPL configuration files from your PS2 Memory Cards or connected USB devices.
- To display the games list in OPL, make sure a regular PS2 Memory Card inserted into your console (if you are using either the MemCard Pro 2 or SD2PSX, remove it), launch OPL and adjust the following settings:
1. Settings > HDD (APA) Start Mode: Off
2. Settings > BDM Start Mode: Auto
3. Settings > BDM Devices > HDD (GPT/MBR): On
4. Settings > Save Changes

These settings will be saved to your PS2 Memory Card. You can keep this card in Slot 2 and use your MemCard Pro 2 or SD2PSX in Slot 1.

## Neutrino and NHDDL
[Neutrino](https://github.com/rickgaiser/neutrino) is a lightweight device emulator for PS2. [NHDDL](https://github.com/pcm720/nhddl) is a frontend for Neutrino.
- If you selected Neutrino as your game launcher, per-game settings assigned in NHDDL are reflected when launching games from the PSBBN Game Collection
- Neutrino does not support compressed `ZSO` files. If `ZSO` files are found in your `games` folder, they will be automatically decompressed to `ISO` files by the [Game Installer](#game-and-app-installer)

## POPStarter and Virtual Memory Cards
POPS is an official Sony PS1 emulator for PS2, originally released exclusively in Japan as a way to distribute PS1 games over the internet to PSBBN users. POPStarter is a homebrew launcher for POPS that enables the emulator to play any PS1 game.

A POPStarter Virtual Memory Card (VMC) is created for every PS1 game played, and your progress is stored there. VMCs can be found on PSBBN in `Save Data Management` and in `Browser 2.0`, under the `POPS` folder. A VMC Group is used for games that can interact with each other's save data. This allows, for example, licenses earned in Gran Turismo to be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis to comment on other Konami games you've played.

Hotkey button combinations are supported for disc swapping and various other options. Full details can be found in the `Manual` of each installed PS1 game. To access it, select a game in the `Game Collection`, press `Triangle`, then select `Manual`.

## Save Application System (SAS)

Save Application System (SAS) is a new standard for distributing homebrew applications for the PS2. Currently in beta, but already has over 20 apps available for download on the [Save Application System Apps Archive](https://ps2wiki.github.io/sas-apps-archive/) with many more coming soon. All SAS-compliant apps come packed in a `PSU` file and include icons and metadata, making it the recommended way to install homebrew on PSBBN.

## Game ID
Game ID for both the Retro GEM, MemCard Pro 2, and SD2PSX is fully supported when launching PS1 games, PS2 games, and homebrew apps from the Game Collection.

If you have a Retro GEM, I would highly recommend that you install the [Retro GEM Game ID Resetter](https://github.com/CosmicScale/Retro-GEM-GameId-Resetter) on your PS2 Memory Card. With this app, when you quit a game, the Game ID is reset, and the Retro GEM settings are returned to global.

## Launch Disc
**Launch Disc** loads the [Retro GEM Disc Launcher](https://github.com/CosmicScale/Retro-GEM-PS2-Disc-Launcher) application.

For physical PlayStation game discs:
- Sets the Retro GEM Game ID
- Adjusts the PlayStation driver's video mode, if needed, to ensure imports play in the correct mode

For physical PlayStation 2 game discs:
- Sets the Retro GEM Game ID
- Skips the PlayStation 2 logo check, allowing MechaPwn users to launch imports and master discs

Recommended usage:
- Add a shortcut for **Launch Disc** to the **Navigator Menu** if it is not there already
- Press `SELECT` to open the **Navigator Menu**
- Insert a game disc
- Select **Launch Disc** from the menu

## wLaunchELF_ISR
A fork of [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) written by [Matías Israelson](https://github.com/israpps). The version included with this project offers improved stability and adds support for exFAT on external drives and MMCE (SD card browsing on Mem Card Pro 2/SD2PSX). More details about this fork can be found [here](https://israpps.github.io/projects/wlaunchelf-isr).

## APA-Jail

![APA-Jail Type-A2](https://github.com/user-attachments/assets/8c83dab7-f49f-4a77-b641-9f63d92c85e7)

APA-Jail, created and developed by [Berion](https://www.psx-place.com/resources/authors/berion.1431/), enables the PS2's APA partitions to coexist with an exFAT partition. The first 128 GB of the HDD/SSD are reserved for APA partitions, while the remaining space (up to 2 TB) is formatted as exFAT. This setup allows PSBBN to access the first 128 GB directly.

An application called [BBN Launcher](#bbn-launcher-bbnl) resides on the APA partitions and directs [Open PS2 Loader](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) to launch specific PS2 games and apps from the exFAT partition.

<font size="4"><b>Warning: Manually creating new APA partitions on your PS2 drive and exceeding the 128 GB limit will corrupt the drive.</b></font>

# Legacy versions of the PSBBN Definitive English Patch

<details>
<summary>Click to expand</summary>

# Patch Features
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console as well as PS2 Slim SCPH-700xx models with an [IDE Resurrector](#slim-ps2-console-model-scph-700xx) or similar hardware mod, regardless of region
- DNAS authorization checks bypassed to enable access the online channels
- Online game channels from Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI have been translated into English. Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard**
- Storage capacity limited to 128 GB
- Legacy versions of the PSBBN Definitive Patch are **not** compatible with the [PSBBN installer](#psbbn-installer), [PSBBN Software Updater](#update-psbbn-software), [Game Installer](#game-and-app-installer), [Media Installer](#media-installer), or [Extras](#extras)

## Version History

**v1.2 - 4th September 2024**
- Fixed a bug on the Photo Channel that could potentially prevent the Digital Camera feature from being launched.
- Fixed formatting issues with a number of error messages where text was too long to fit on the screen.
- Various small adjustments and corrections to the translation throughout.

**v1.1.1 - 8th March 2024**
**NEW**  
- X11 has been set to run in English. The restore, move, resize, minimize, and close buttons now show in English while using the NetFront web browser. When saving files, time stamps now also display in English formatting.

**v1.1 - 5th March 2024**
**NEW**  
- The NetFront web browser is now in English. The browser can be accessed by going through the "Confirm/Change" network setting dialogs, then selecting "Change router settings".
- Atok user manual has been translated.

**BUG FIXES**  
- **General**: When a game disc was inserted while on the Top Menu, it would cause the console to freeze.  
- **Music Channel**: The number of times a track had been checked-out to a MiniDisc recorder was not displayed correctly.  
- A number of typos have been fixed.

**v1.0 - 21st September 2023**
- Initial release.

## Installation Instructions
There are two ways to install this English patch:

1. [PS2 HDD RAW Image Install](#ps2-hdd-raw-image-install): Use this method if you have access to a PC and a way to connect your PS2 HDD/SSD to your PC. This is the most straightforward option. All data on the HDD will be lost.

2. [Patch an existing PSBBN install](#patch-an-existing-psbbn-install): Use this method if you already have an existing PSBBN install on your PlayStation 2 console. Also, follow these instructions to install future patch updates. No data will be lost.

### PS2 HDD RAW Image Install
**What You Will Need:**
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter). The drive must be 120 GB or larger
- A way to connect the PS2 HDD to a PC
- 120 GB of free space on your PC to extract the files
- Disk imaging software

**Installation Procedure:**
1. Download [PSBBN_English_Patched_v1.x.x_Image.7z](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patched_v1.2_Image.7z) and uncompress it.
`PSBBN_English_Patched_v1.x.x_HDD_RAW.img` is a raw PS2 disk image of the Japanese PlayStation BB Navigator Version 0.32 with the PlayStation Broadband Navigator (PSBBN) Definitive English Patch pre-installed.
2. To write this image to your PS2 HDD, you need disk imaging software. For Windows, I recommend using HDD Raw Copy ver. 1.10 portable. You can download it [here](https://hddguru.com/software/HDD-Raw-Copy-Tool/).

### Patch an existing PSBBN install

**What You Will Need:**
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter)
- An existing install of PSBBN software 0.32 on your PS2 console
- A Free McBoot Memory Card
- A USB flash drive formatted as FAT32
- A USB keyboard

**Installing the English Patch:**
1. Install the PSBBN software on your PS2 console if you haven't done so already. Either via a disk image or manually, see the section [Installing the Japanese PSBBN software](#installing-the-japanese-psbbn-software) below for details on a manual install.
2. Download [PSBBN_English_Patch_Installer_v1.x.x.zip](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patch_Installer_v1.2.zip) and unzip it on your PC.
3. Copy the files `kloader3.0.elf`, `config.txt`, `xrvmlinux`, `xrinitfs_install.gz`, and `PSBBN_English.tar.gz` to the root of a FAT32 formatted USB flash drive.
4. Connect the USB flash drive and a USB keyboard to the USB ports on the front of your PS2 console.
5. Turn the PS2 console on with your Free McBoot Memory Card inserted and load wLaunchELF.
6. Load `kloader3.0.elf` from the USB flash drive.
7. Eventually, you will be presented with a login prompt:  
     Type `root` and press enter.  
     Type `install` and press enter.
8. When you see the text `INIT: no more processes left in this runlevel`, hold the standby button down until the console powers off.

Remove your Free McBoot Memory Card. Power the console on and enjoy PSBBN in full English!

## Installing the Japanese PSBBN software

There are a number of ways this can be achieved. On a Japanese PlayStation 2 console with an **official PSBBN installation disc**, or with **Sony Utility Discs Compilation 3**.

To install via **Sony Utility Discs Compilation 3** you will need a way to boot backup discs on your console, be that a mod chip or a swap disc. If you are lucky enough to have a **SCPH-500xx** series console you can use the **MechaPwn** softmod.

Installing with Sony Utility Discs Compilation 3:

**Preparations:**
1. Download the **Sony Utility Discs Compilation 3** ISO from the Internet Archive [here](https://archive.org/details/sony-utility-disc-compilation-v3).
2. **SCPH-500xx consoles only**: Patch the ISO with the [Master Disc Patcher](https://www.psx-place.com/threads/playstation-2-master-disc-patcher-for-mechapwn.36547/).
3. Burn this ISO to a writable DVD. I recommend using [ImgBurn](https://www.imgburn.com).
4. **SCPH-500xx consoles only**: MechaPwn your PS2 console with the latest release candidate, currently [MechaPwn 3.0 Release Candidate 4 (RC4)](https://github.com/MechaResearch/MechaPwn/releases/tag/3.00-rc4). It is important that you use a version of MechaPwn that does not change the **Model Name** of your console or it will break compatibility with the Kloader app, we use later in this guide. Currently the latest stable version is not compatible. More details about exactly what MechaPwn does and how to use it can be found [here](https://github.com/MechaResearch/MechaPwn).
5. Format the PS2 HDD. In wLaunchELF press the `circle` button for **FileBrowser**, then select **MISC > HddManager**. Press `R1` to open the menu and select **Format**. When done, press `triangle` to exit.
6. Launch the **Sony Utility Discs Compilation 3** DVD on your console. **SCPH-500xx consoles only:** Insert your newly burnt **Sony Utility Discs Compilation 3** DVD into the DVD drive on your PS2 console. On the first screen of wLaunchELF, press the `circle` button for **FileBrowser**, then select **MISC > PS2Disc**. The DVD will launch. On all other model consoles, launch the **Sony Utility Discs Compilation 3** DVD any way you can (e.g. Mod chip/Swap disc).
7. After the disc loads, select **HDD Utility Discs > PlayStation BB Navigator Version 0.32** from the menu to begin the installation.

**Installation:**  
There's an excellent guide [here](https://bungiefan.tripod.com/psbbninstall_01.html) that talks you through the Japanese install. Because we have already formatted the hard drive, during the install you will be presented with a [different screen](https://bungiefan.tripod.com/psbbninstall_02.html). It's important that you select the 3rd install option. This will install PSBBN without re-formatting the HDD. When the install is complete you will be instructed to remove the DVD, do so but also remove your Free McBoot Memory Card, before pressing the `circle` button.

**Network Settings:**  
You will be asked to enter your network settings. Make sure your Ethernet cable is connected. Everything is still in Japanese, but it's relatively straightforward:
1. Press the `circle` button on the first screen.
2. On the next screen, select the **bottom** option, "Do not use PPPoE" and press `circle`.
3. On the next screen, select the **top** option, "Auto" for you IP address and press `circle`.
4. On the next screen, select the **top** option, "Auto" for DNS settings and press `circle`.
5. Press `right` on the d-pad to proceed to the next screen.
6. Select the **bottom** option, "Do not change router settings" and press `circle`.
7. Finally, press `circle` again to confirm your settings.

For your efforts you will be given a DNAS error. This is to be expected. We'll fix that next. Press `cross` and feel free to explore your fresh install of the Japanese PSBBN.

**Disable DNAS Authentication:**  
1. Turn off the console and put your Free McBoot Memory Card back into a memory card slot.  
2. Turn the console on and load wLaunchELF.  
3. Go to **FileBrowser**. Navigate to `hdd0:/__contents/bn.conf/` and delete the file `default_isp.dat`. This will disable the DNAS checks.

**Please Note**
Before installing the English patch, you **must** power off your console to standby mode by holding the reset button. Failure to do so will cause issues with Kloader.

## Notes

\* Also compatible with the PS2 Slim SCPH-700xx models with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod. [PS2 HDD RAW Image Install](#ps2-hdd-raw-image-install) is not compatible with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000) that have an external HDD due to space limitations (unless the stock drive is replaced with a 120+ GB drive). When [patching an existing PSBBN install](#patch-an-existing-psbbn-install), Kloader might have compatibility issues with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000).  
- Use OPL-Launcher to launch PS2 games from the Game Channel. More details can be found [here](https://github.com/ps2homebrew/OPL-Launcher).
- Lacks support for large HDDs, drives larger than 130 GB cannot be taken full advantage of. PSBBN can only see the first 130,999 MB of data on your HDD/SSD (as reported by wLaunchELF). If there is 131,000 MB or more on your HDD/SSD, PSBBN will fail to launch. Delete data so there is less than 131,000 MB used, and PSBBN will launch again. Be extra careful if you have installed via the [PS2 HDD RAW Image](#ps2-hdd-raw-image-install) on a drive larger than 120 GB, going over 130,999 MB will corrupt the drive.
- You may need to manually change the title of your "Favorite" folders if they were created before you [Patched an existing PSBBN install](#patch-an-existing-psbbn-install).

</details>

# Troubleshooting

## Problems Launching PSBBN
When you connect the drive to your PS2 console and power it on, PSBBN should automatically launch.

### Fat PS2 console models SCPH-3000x-500xx:
If your console boots to the regular OSD or freezes, it means that your drive has not been recognised or you are experiencing a hardware issue. You should check the following:
1. There is currently a known issue when installing on Fedora. It is recommended to use a Debian-based distribution or the [PSBBN Launcher for Windows](#installing-on-windows) instead.
2. Make sure you are using an official Sony Network Adapter; 3rd-party adapters are not supported
3. Ensure the network adapter and drive are securely connected to the console
4. Check that the connectors on the console and network adapter are clean and free of dust/debris
5. If using a SATA mod, make sure it has been installed correctly
6. Try using a different HDD/SSD
7. Try using a different IDE converter/SATA mod
8. Try a different official Sony Network Adapter
9. Try a different PS2 console

### Early (SCPH-10000–18000) and Slim (SCPH-700xx) Consoles
If you are using a PS2 Slim **SCPH-700xx** model with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod, or **SCPH-10000 to SCPH-18000** model with an official external HDD enclosure, download the [External HDD Drivers](https://israpps.github.io/FreeMcBoot-Installer/test/8_Downloads.html). Extract the files and place `hddload.irx`, `dev9.irx`, and `atad.irx` in the appropriate system folder for your region on an official Sony PS2 Memory Card:

| Region   | Folder Name   |
|----------|-------------- |
| Japanese | BIEXEC-SYSTEM |
| American | BAEXEC-SYSTEM |
| Asian 	 | BAEXEC-SYSTEM |
| European | BEEXEC-SYSTEM |
| Chinese  | BCEXEC-SYSTEM |

For the **SCPH-700xx** model if, after doing so, the console freezes at the `PlayStation 2` logo, the most likely cause is an incompatible IDE to SD card adapter.

## Problems Launching Games
If games do not appear in the games list in [NHDDL](#neutrino-and-nhddl) or [OPL](#open-ps2-loader-opl) (after modifying the OPL settings as described [above](#open-ps2-loader-opl)), or fail to launch from the PSBBN Game Collection, try the following:

1. If you have a [mod chip](#known-issues), disable it
2. Re-run the [Game Installer](#game-and-app-installer) and select the alternative game launcher ([OPL](#open-ps2-loader-opl)/[Neutrino](#neutrino-and-nhddl))
3. Connect the PS2 HDD/SSD directly to your PC using an internal SATA connection or a different USB adapter, then [reinstall PSBBN](#psbbn-installer)
4. Try using a different HDD/SSD and then [reinstall PSBBN](#psbbn-installer)
5. Try using a different IDE converter/SATA mod on your console

# Known Issues
- Using a Definitive Patch version older than 2.10 with the latest game installer may corrupt APA partitions, rendering PSBBN unbootable. If you are running an older version, it is highly recommended that you upgrade by selecting [Install PSBBN](#psbbn-installer) from the main menu.
- PSBBN only supports dates up to the end of 2030. When setting the time and date, the year must be set to 2030 or below.  
- PSBBN will freeze when launching games/apps if a mod chip is active. To use PSBBN, mod chips must be disabled.  
- PSBBN will freeze at the "PlayStation 2" logo when booting, if a 3rd party, unofficial HDD adapter is used. An official Sony Network Adapter is required.  
- When using a drive larger than 2 TB, the first 128 GB will be allocated to the PlayStation File System (PFS), and the next 2 TB will be formatted as an exFAT partition. Any remaining space beyond that will be unusable.
- [OPL](#open-ps2-loader-opl) cannot read settings saved on the exFAT partition of the internal drive. Settings should be saved to a PS2 memory card. If you have a MemCard Pro 2 or SD2PSX, it is recommended that you save your OPL settings to a standard PS2 memory card inserted in slot 2.
- `wLaunchELF` and other native PS2 apps cannot create PFS partitions on the PS2 drive. New partitions should only be created using the version of `PFS Shell` included with this project. When creating additional partitions, care must be taken to ensure PFS partitions do not exceed the first 128 GB of drive space, or the drive will become corrupted.
- [HDD-OSD (Browser 2.0)](#hdd-osd-browser-20) may report drives larger than 1 TB as broken.
- MiniDisc support is broken on patch version 2.10. I hope to fix this in a future update
- The PS2 DVD Remote Control can behave erratically if no controller is plugged into Controller Port 1

\* Instances in feega where some Japanese text couldn't be translated due to it being hard-coded in an encrypted file. Atok software has not been translated.  
\** The default on-screen keyboard is set to Japanese. However, a US English on-screen keyboard has been added, though you’ll need to press the `SELECT` button multiple times to switch to it. There's a bug where spacebar doesn't work on the US English on-screen keyboard, but you can enter a space by pressing the `triangle` button on the controller instead.

# Credits
PS2 Homebrew Community:
- PSBBN Definitive English Patch project by [CosmicScale](https://github.com/CosmicScale)
- PSBBN English translation by [CosmicScale](https://github.com/CosmicScale)
- `Setup.sh`, `PSBBN-Installer.sh`, `Game-Installer.sh`, `Media-Installer.sh`, `music-installer.py`, `Extras.sh`, `art_downloader.py`, `list-sorter.py` `txt_to_icon_sys.py`, `vmc_groups.list` written by [CosmicScale](https://github.com/CosmicScale)
- `ps2iconmaker.sh` written by [Sakitoshi](https://github.com/Sakitoshi) and [CosmicScale](https://github.com/CosmicScale)
- `PSBBN-Launcher-For-Windows.ps1` written by Yornn
- Contains code from `list_builder.py` from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma), modified by [CosmicScale](https://github.com/CosmicScale)
- Contains data from `TitlesDB_PS1_English.txt` and `TitlesDB_PS2_English.txt` from the [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) by [GDX-X](https://github.com/GDX-X), modified by [CosmicScale](https://github.com/CosmicScale)
- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/8Mb) and [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) with 8MB PFS partition modifications by [AKuHAK](https://github.com/AKuHAK)
- [PFS Fuse](https://github.com/ps2homebrew/pfsshell) by [PS2 Homebrew Projects](https://github.com/ps2homebrew)
- [BBN Launcher](https://github.com/pcm720/bbnl) written by [pcm720](https://github.com/pcm720) and [CosmicScale](https://github.com/CosmicScale)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) with BDM contributions from [KrahJohlito](https://github.com/KrahJohlito) and Auto Launch modifications by [CosmicScale](https://github.com/CosmicScale)
- [Neutrino](https://github.com/rickgaiser/neutrino) by [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) written by [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/threads/popstarter.19139/) written by [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [Retro GEM Disc Launcher](https://github.com/CosmicScale/Retro-GEM-PS2-Disc-Launcher) written by [CosmicScale](https://github.com/CosmicScale)
- [PS1VModeNeg](https://github.com/ps2homebrew/PS1VModeNeg) written by [AKuHAK](https://github.com/AKuHAK)
- Uses APA-Jail code from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) by [Berion](https://www.psx-place.com/members/berion.1431/)
- [APA Partition Header Checksumer](https://www.psx-place.com/resources/apa-partition-header-checksumer.1057/) by [Pink1](https://www.psx-place.com/members/pink1.1907/) and [Berion](https://www.psx-place.com/members/berion.1431/). [Linux port](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) by [Bucanero](https://github.com/Bucanero)
- [PSU Extractor](https://github.com/bucanero/psv-save-converter) written by [Bucanero](https://github.com/Bucanero) from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) project
- `ziso.py` from [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) written by Virtuous Flame
- `icon_sys_to_txt.py` written by [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- [PlayStation 2 Basic Boot Loader (PS2BBL)](https://github.com/israpps/PlayStation2-Basic-BootLoader) written by [Matías Israelson (israpps)](https://github.com/israpps)
- [wLaunchELF_ISR](https://israpps.github.io/projects/wlaunchelf-isr) by [Matías Israelson (israpps)](https://github.com/israpps)
- Online channels resurrected, translated, maintained and hosted by vitas155 at [psbbn.ru](https://psbbn.ru/)
- PlayStation Now! and Konami online channels translated by [CosmicScale](https://github.com/CosmicScale)
- [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- Uses PS2 cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups)
- Uses App icons from [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) and [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) courtesy of [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- VMC and PSBBN 3D icons designed by Yornn
- Thanks to everyone on the [Save Application System team](https://ps2wiki.github.io/documentation/homebrew/PS2-App-System/SAS/index.html#Credits) for their ongoing work on the [Save Application System Apps Archive](https://ps2wiki.github.io/sas-apps-archive/)
- Special thanks to [pcm720](https://github.com/pcm720) for patching `osdboot.elf` to bypass the CRC security check

Third-Party Libraries & Binaries:  
- `vmlinux` **BB Navigator kernel (Linux 2.4.17)** – Source code available [here](https://github.com/rickgaiser/linux-2.4.17-ps2)
- **SQLite v2.8.17** from [sqlite.org](https://www.sqlite.org) 
- **mkfs.exfat (exfatprogs 1.2.2)** from [exfatprogs](https://github.com/exfatprogs/exfatprogs)

All libraries and utilities are open-source and used in accordance with their respective licenses.

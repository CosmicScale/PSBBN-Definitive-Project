# PSBBN Definitive Project v2.1

This is the PSBBN Definitive Definitive Project (formerly the PSBBN Definitive English Patch) for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console. The latest version of the PSBBN Definitive Project can be found [here](https://github.com/CosmicScale/PSBBN-Definitive-Project).

PSBBN is official Sony software for the PlayStation 2, released exclusively in Japan. Introduced in 2002 as a replacement for the PS2’s OSD, it required both a hard drive and a network adapter to function. It added many new features:
- Launching games from the hard drive in the Game Channel
- Accessing online channels
- Downloading full games, demos, videos, and pictures
- Ripping audio CDs and transferring music to MiniDisc recorders in the Music Channel
- Watching videos in the Movie Channel
- Transferring photos from a digital camera and viewing them in the Photo Channel

This project aims to translate PSBBN from Japanese to English, introduce modern features, and make it a viable daily driver in 2025 and beyond.

You can find out more about the PSBBN software on [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) and on my [YouTube channel](https://www.youtube.com/@CosmicScaleFactor).

# Donations  
If you appreciate my work and want to support the ongoing development of the PSBBN Definitive English Patch and other PS2-related projects, [you can donate to my Ko-Fi here](https://ko-fi.com/cosmicscale).

This project uses [webhook.site](https://webhook.site/) to automatically contribute game artwork and report missing artwork to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database). As the project has grow in popularity, we're exceeding the limit offered by a free account. A paid subscription costs $9/month or $90/year, donations help fund this.

# Video demonstration of PSBBN

[![PSBBN in 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Patch Features
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console as well as PS2 Slim SCPH-700xx models with an [IDE Resurrector](#slim-ps2-console-model-scph-700xx) or similar mod, regardless of region
- DNAS authorization checks bypassed to enable online connectivity
- Online game channels from Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI have been translated into English. Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard**

# Exclusive to version 2
- Direct link to the Game Collection in the Top Menu 
- Launch up to 800 PS1/PS2 games and apps directly from the PSBBN Game Collection
- Large HDD support: no longer limited to 128 GB. It now supports larger drives, with 128 GB allocated to the PlayStation File System (PFS) and up to 2 TB allocated to exFAT for PS2 games and homebrew apps.
- Set a custom size for your music partition. Original limit of 5 GB allowed the storage of around 7 albums. Now the partition can be up to 104 GB for around 160 albums
- [POPS](#popstarter-and-virtual-memory-cards) partition up to 104 GB for PS1 games
- Includes the apps [wLaunchELF_ISR](#wlaunchelf_isr) and [Retro GEM Disc Launcher](#launch-disc), with a choice of either [OPL](#open-ps2-loader-opl) or [NHDDL](#neutrino-and-nhddl)
- PS2 Linux is pre-installed. See [General Notes](#general-notes) for details
- Bandai and SCEI online channels have been added to the Game Channel
- Full [Game ID](#game-id) support for the Pixel FX Retro GEM and MemCard Pro/SD2PSX
- [PSBBN installer script](#psbbn-installer-script) makes setup easy
- [Game Installer script](#game-installer-script) fully automates the installation of PS1/PS2 games as well as `ELF` and [SAS-compliant](#save-application-system-sas) homebrew apps
- A choice of [OPL](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for you game launcher
- Install [optional extras](#extras-script) such as HDD-OSD and [PS2BBL](#playstation-2-basic-boot-loader-ps2bbl)

# Changelog

## July 17, 2025 - Definitive Patch v2.11 - Boot Security Patched! Button Swap, VMC Groups & More! - [Click to Watch](https://www.youtube.com/watch?v=kgXe8rlqsr0)

**Release Notes:**

**PSBBN Updated to Definitive Patch v2.11**

Patch v2.11 can be installed by running the [PSBBN Installer script](#psbbn-installer-script) (all data will be lost), or via the new `Update PSBBN Software` option in the [Extras script](#extras-script) (requires a FAT32-formatted USB drive, 128 GB or smaller, and a USB keyboard to complete setup).

New in Definitive Patch v2.11:
- Boot Security Patched. The CRC security check in PSBBN’s boot ELF has been bypassed, allowing the loading of custom kernels.
- The `X` and `O` buttons have been swapped: `X` is now Enter, and `O` is now Back.
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

## June 05, 2025 - PSBBN Definitive Patch v2.10 – Big Game Installer Changes & More! - [Click to Watch](https://www.youtube.com/watch?v=XTacIPOGAwE)

<details>
<summary><b>Release Notes:</b></summary>

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
- Partitions the remaing space of the first 128 GB of the drive:
  - Music partition can now range between 1 GB and 104 GB  
  - [POPS](#popstarter-and-virtual-memory-cards) partition can now range between 1 GB and 104 GB  
  - Space reserved for 800 BBNL partitions  
- Removed [POPS](#popstarter-and-virtual-memory-cards) installer (now handled by the Game Installer script)  
- Code has been significantly cleaned up and optimized  

**`03-Game-Installer.sh`:**

- Added a warning for users running PSBBN Definitive Patch below version 2.10
- The PS2 drive is now auto-detected  
- Added an option to set a custom path to the `games` folder on your PC
- Allows new games and apps to be added without requiring a full sync  
- [BBNL](https://github.com/pcm720/bbnl) partition size reduced from 128 MB to 8 MB, enabling up to 800 games/apps to be displayed in the Game Collection
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

## May 01, 2025 - SAS, HDD-OSD, PS2BBL & More! - [Click to Watch](https://www.youtube.com/watch?v=vpbHlS8nY58)

<details>
<summary><b>Release Notes:</b></summary>

- Added support for the [Save Application System (SAS)](#save-application-system-sas). `PSU` files can now also be placed in the local `games/APPS` folder on your PC and will be installed by the `03-Game-Installer.sh` script
- Added support for HDD-OSD to the `03-Game-Installer.sh` script. 3D icons are now downloaded from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- New script: [04-Extras.sh](#extras-script). Added ability to install HDD-OSD and [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
- Make your own HDD-OSD icons with the [HDD-OSD Icon Templates](https://github.com/CosmicScale/HDD-OSD-Icon-Database/releases/download/v1.0.0/HDD-OSD-Icon-Templates.zip)
- Translate PSBBN using the [Translation Pack](https://mega.nz/file/iBUh2SaT#TrbFtoj6rjONfaiYnfyCxLPms01iJclva_gr6bJAFd0) to localize the software into different languages.

</details>

## Mar 28, 2025 - Homebrew Launcher & More! - [Click to Watch](https://www.youtube.com/watch?v=q9LvE_OPIPo)

<details>
<summary><b>Release Notes:</b></summary>

- [Open PS2 Loader](#open-ps2-loader-opl) updated to version 1.2.0-Beta-2201-4b6cc21:
  - Limited max BDM UDMA mode to UDMA4 to avoid compatibility issues with various SATA/IDE2SD adapters
- Added a manual for PS1 games. It can be accessed in the Game Collection by selecting a game, pressing Triangle, and then selecting `Manual`
- Transitioned to [BBN Launcher (BBNL)](https://github.com/pcm720/bbnl) version 2.0:
  - Dropped APA support in favor of loading [OPL](#open-ps2-loader-opl), [POPStarter](#popstarter-and-virtual-memory-cards), [Neutrino](#neutrino-and-nhddl), and configuration files from the exFAT partition to speed up initialization.
  - Moved [BBNL](https://github.com/pcm720/bbnl) to the APA header to further improve loading times.
  - Removed dependency on renamed [POPStarter](#popstarter-and-virtual-memory-cards) `ELF` files to launch PS1 VCDs; [POPStarter](#popstarter-and-virtual-memory-cards) is now launched directly with a boot argument.
  - [NHDDL](https://github.com/pcm720/nhddl) now launches in ATA mode, improving startup time and avoiding potential error messages.
- Updated [Neutrino](#neutrino-and-nhddl) to version 1.6.1
- Updated [NHDDL](#neutrino-and-nhddl) to version MMCE + HDL Beta 4.17
- Added cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups). Artwork for PS2 games is now displayed in OPL/NHDDL
- Added homebrew support to the `03-Game-Installer.sh` script. `ELF` files placed in the local `games/APPS` folder on your PC will be installed and appear in the Game Collection in PSBBN and the Apps tab in OPL
- Apps now support [Game ID](#game-id) for both the Pixel FX Retro GEM and MemCard Pro/SD2PSX

</details>

## Feb 19, 2025 - BBN Launcher, Neutrino & NHDDL - [Click to Watch](https://www.youtube.com/watch?v=0vpSiAa6ITc)

<details>
<summary><b>Release Notes:</b></summary>

- [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) has been replaced by [BBN Launcher (BBNL)](https://github.com/pcm720/bbnl)
- Added [Neutrino](#neutrino-and-nhddl) support. You can now choose between [Open PS2 Loader](#open-ps2-loader-opl) and [Neutrino](#neutrino-and-nhddl) as your game launcher
- When using Neutrino as your game launcher, [NHDDL](#neutrino-and-nhddl) can be used to make per-game settings

</details>

## Jan 22, 2025 - Game ID, PSBBN Art Database, Updated Tutorial & More! – [Click to Watch](https://www.youtube.com/watch?v=sHz0yKYybhk)

<details>
<summary><b>Release Notes:</b></summary>

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

## Dec 11, 2024 - PSBBN Definitive English Patch 2.0 – [Click to Watch](https://www.youtube.com/watch?v=ooH0FjltsyE)

<details>
<summary><b>Release Notes:</b></summary>

- Initial release of patch version 2.0
- Bandai and SCEI online channels have been added to the Game Channel
- PS2 Linux dual-boot
- [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) pre-installed
- Large HDD support: no longer limited to 128 GB
- Introducing [APA-Jail](#apa-jail), allowing the PlayStation's PFS partitions to co-exist with an exFAT partition
- Introducing [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM), allowing PS2 games stored on the exFAT partition to be launched from within PSBBN
- Introducing the [PSBBN Installer script](#psbbn-installer-script):
  - Installs PSBBN, [POPS binaries and POPStarter](#popstarter-and-virtual-memory-cards)
  - Partition the first 128 GB of the drive as PFS:
    - Create up to 700 OPL launcher partitions
    - Custom size music partition from 10 GB to max 97 GB
    - Remaining space allocated to [POPS](#popstarter-and-virtual-memory-cards) partition for PS1 games
  - Creates an exFAT partition with drive space beyond the first 128 GB for storage of PS2 games
- Introducing the [Game Installer script](#game-installer-script):
  - Fully automates the installation of PS1 and PS2 games
  - Creates all assets and meta-data
  - Downloads game artwork from IGN

</details>  

# Installation scripts

These scripts are essential for unlocking all the new features exclusive to version 2.0 and above. The scripts require an x86-64 Linux environment. If Linux is not installed on your PC, you can use a live Linux environment on a bootable USB drive, Windows users can also use [Windows Subsystem for Linux (WSL)](#installing-on-windows-with-the-windows-subsystem-for-linux-wsl). Debian-based distributions using `apt`, Arch-based distributions using `pacman`, and Fedora-based distributions using `dnf` are supported. You will require a HDD/SSD for your PS2 that is larger than 200 GB, ideally 500 GB or larger. I highly recommend a SSD for better performance. You can connect the HDD/SSD to your PC either directly via SATA or using a USB adapter.

When run, the scripts automatically update to the latest version if an update is available.

## Video Tutorial

[![PSBBN Definitive English Patch 2.0](https://github.com/user-attachments/assets/d60dc4ff-85f8-4fb4-8acb-201b063545b0)](https://www.youtube.com/watch?v=sHz0yKYybhk)  
**Note: The tutorial in the video is slightly out of date. An updated version will be available soon.**

## Installing the scripts
<span style="font-size: 17px; font-weight: bold;">It is highly recommended to install the scripts using the following command to enable automatic updates:</span>
```
git clone --branch PSBBN-Definitive-Project-v2.1 https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```
If you have not used Git before, you might need to install it first. On Debian-based distributions, it can be installed with the following command:
```
sudo apt install git
```

## Setup script
`01-Setup.sh` installs all the necessary dependencies for the other scripts and must be run first.

## PSBBN installer script
`02-PSBBN-Installer.sh` fully automates the installation of PSBBN:

- Downloads and installs the latest version of the **PSBBN Definitive English Patch** from archive.org
- Creates partitions for the Music Channel and [POPS](#popstarter-and-virtual-memory-cards) (to store PS1 games), with user-defined sizes on the first 128 GB of the drive.
- Reserves space for 800 [BBN Launcher](https://github.com/pcm720/bbnl) partitions, used to launch games and apps.
- Runs [APA-Jail](#apa-jail), creating an exFAT partition using all remaining disk space beyond the first 128 GB (up to 2 TB) for the storage of PS2 games and apps

## Game installer script
`03-Game-Installer.sh` fully automates the installation of PS1 and PS2 games, as well as homebrew apps:
- Auto-detects your PS2 drive
- Let you set a custom path to the `games` folder on your PC
- Gives you a choice of [Open PS2 Loader (OPL)](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for the game launcher
- Installs any available updates for [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [Neutrino, NHDDL](#neutrino-and-nhddl), [Retro GEM Disc Launcher](#launch-disc), and [wLaunchELF_ISR](#wlaunchelf_isr)
- Downloads and installs the [POPS](#popstarter-and-virtual-memory-cards) binaries and installs [POPStarter](#popstarter-and-virtual-memory-cards)
- Offers the option to synchronise the games and apps on your PC with your PS2's drive, or to add additional games and apps
- Creates all assets including meta-data, artwork and icons for all your games/apps
- Downloads artwork for the PSBBN Game Collection from the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) or IGN if not found in the database
- Automatically contributes game artwork downloaded from IGN and reports missing artwork to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
- Downloads cover art for PS2 games from the [OPL Manager art database](https://oplmanager.com/site/?backups) for display in [OPL](#open-ps2-loader-opl)/[NHDDL](#neutrino-and-nhddl)
- Creates [Virtual Memory Cards (VMCs)](#popstarter-and-virtual-memory-cards) for all PS1 games. Creates VMC Groups for for games that can interact with each other's save data
- Downloads icons for both games and [VMCs](#popstarter-and-virtual-memory-cards) for use with HDD-OSD/Browser 2.0 from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If icons are unavailable, but images for a game are available in the [OPL Manager Art Database](https://oplmanager.com/site/?backups), 3D icons will be automatically created.
- Automatically contributes HDD-OSD icons and reports missing icons to the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Creates [BBN Launcher](https://github.com/pcm720/bbnl) partitions, making games and apps launchable from the PSBBN Game Collection and HDD-OSD

### Synchronize All Games and Apps

Simply place your files in the `games` folder on your PC: PS2 `ISO` or `ZSO` files in the `CD`/`DVD` folders, PS1 `VCD` files in the `POPS` folder, and `ELF` or 
[SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder. By default, the `games` folder is located in the same directory where you installed the scripts, but the script lets you change this. To add or delete games and apps, just modify the contents of the `games` folder on your PC, then run the script and select `Synchronize All Games and Apps`.

### Add Additional Games and Apps

Alternatively, you can add PS2 games directly to the exFAT partition of your PS2 drive by placing `ISO` or `ZSO` files in the `CD` or `DVD` folders, and `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder. Then run the script and select `Add Additional Games and Apps`. This will add the new content to the PSBBN Game Collection and HDD-OSD. Additionally, any new PS1 and PS2 games and apps found in the `games` folder on your PC will also be installed.

**Note:** PS1 games can only be installed by placing the `VCD` files in the `games/POPS` folder on your PC.

Additionally, PS2 games and homebrew apps can be manually deleted from the exFAT partition on the PS2 drive, and PS1 games can be deleted from the PFS `__.POPS` partition. Running the script and selecting `Add Additional Games and Apps` will remove any deleted games from the PSBBN Game Channel and HDD-OSD.

### Sorting
In the PSBBN Game Collection, items are grouped into PS1 games, PS2 games, and homebrew apps. PS1 and PS2 games are sorted alphabetically and organized by game series, with games in a series ordered by release date. Homebrew apps are sorted alphabetically, while SAS apps are further divided into sub-groups based on app type (system, game, emulator, etc.).

## Extras script
`04-Extras.sh` installs optional extras:
1. Update PSBBN Software - Updates the PSBBN software to the latest version of the Definitive Patch.
2. Install HDD-OSD/Browser 2.0 - an updated version of the stock OSD shipped with every PS2 console, but with added HDD support.
3. Install [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl) - a simple PS2 bootloader that handles system initialisation and `ELF` programs execution. With this bootloader, holding a button on the controller during startup determines which application is launched.
4. Uninstall [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl).

## Installing on Windows with the Windows Subsystem for Linux (WSL)
If you are running Microsoft Windows 10 or 11, it is recommended to install the PSBBN Definitive Project using WSL. WSL is a feature of Windows that allows you to run a Linux environment directly within Windows.

To install WSL and Debian, launch PowerShell as administrator and run:
```
wsl --install --distribution Debian
```
If you receive an error, it most likely means your hypervisor is disabled. Open “Turn Windows features on or off” and enable the following:
- Hyper-V
- Virtual Machine Platform
- Windows Subsystem for Linux

It may also be necessary to enable `SVM Mode` (for AMD CPUs) or `VT-x` (for Intel CPUs) in your BIOS settings. After making these changes, re-run the command above.

To mount your PS2 Drive, from PowerShell as administrator, run:
```
wmic diskdrive list brief
```
This will display a list of drives connected to your PC. Identify the appropriate drive and note the physical drive number (e.g., PHYSICALDRIVE3).

Then run the following command, substituting `x` with the correct drive number:
```
wsl --mount \\.\PHYSICALDRIVEx --bare
```
From the Linux command line, you can now run the [installation scripts](#installation-scripts):
```
sudo apt update
sudo apt install git
git clone --branch PSBBN-Definitive-Project-v2.1 https://github.com/CosmicScale/PSBBN-Definitive-Project.git
cd PSBBN-Definitive-Project
./01-Setup.sh
./02-PSBBN-Installer.sh
./03-Game-Installer.sh
./04-Extras.sh
```
When complete, don’t forget to unmount the drive in PowerShell, replacing `x` with the drive number:
```
wsl --unmount \\.\PHYSICALDRIVEx
```
# Notes
## General Notes
- PSBBN requires a Fat PS2 console (SCPH-3000x to SCPH-500xx) with an expansion bay and an [official Sony Network Adapter](#known-issueslimitations-of-psbbn), or a PS2 Slim SCPH-700xx model with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar mod. It is also compatible with the SCPH-10000 to SCPH-18000 models with an official external HDD, as long as the drive in the enclosure has been replaced with one that is 200 GB or larger.
- For expansion bay type consoles, I would highly recommend using a **Kaico or BitFunx IDE to SATA Upgrade Kit**
- A SATA SSD is also highly recommended. The **Kingston A400 SSDs** have been tried and tested with PSBBN and work very well. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface.
- PS2 games must be in ISO or ZSO format. PS1 games must be in VCD format. Apps must be in the `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` format
- PS2 Linux is pre-installed. Wait until the `PlayStation 2` icon is displayed, then hold any button on the controller and keep holding it until the spinning orbs stop. PS2 Linux will then boot.
- PS2 Linux requires a USB keyboard; a mouse is optional but recommended
- The `root` password for Linux is `password`. There is also a `ps2` user account with the password set as `password`
- To quit PS1 games, press `L1 + SELECT + START`
- If you are using [OPL](#open-ps2-loader-opl) as your game launcher, to quit PS2 games, press `L1 + L2 + R1 + R2 + SELECT + START` and to power off the console press `L1 + L2 + L3 + R1 + R2 + R3`

## Open PS2 Loader (OPL)
[Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) is a 100% open source game and application loader for the PS2.
- If you selected OPL as your game launcher, per-game settings assigned in OPL are reflected when launching games from the PSBBN Game Collection
- If OPL freezes at startup, delete any existing OPL configuration files from your PS2 Memory Cards or connected USB devices.
- To display the games list in OPL, make sure a PS2 memory card is inserted into your console, launch OPL and adjust the following settings:
1. Settings > HDD (APA) Start Mode: Off
2. Settings > BDM Start Mode: Auto
3. Settings > BDM Devices > HDD (GPT/MBR): On
4. Settings > Save Changes

## Neutrino and NHDDL
[Neutrino](https://github.com/rickgaiser/neutrino) is a lightweight device emulator for PS2. [NHDDL](https://github.com/pcm720/nhddl) is a frontend for Neutrino.
- If you selected Neutrino as your game launcher, per-game settings assigned in NHDDL are reflected when launching games from the PSBBN Game Collection
- Neutrino does not support compressed `ZSO` files. If `ZSO` files are found in your `games` folder, they will be automatically decompressed to `ISO` files by the `03-Game-Installer.sh` script

## POPStarter and Virtual Memory Cards
POPS is an official Sony PS1 emulator for PS2, originally released exclusively in Japan as a way to distribute PS1 games over the internet to PSBBN users. POPStarter is a homebrew launcher for POPS that enables the emulator to play any PS1 game.

A POPStarter Virtual Memory Card (VMC) is created for every PS1 game played, and your progress is stored there. VMCs can be found on PSBBN in `Save Data Management` and in `Browser 2.0`, under the `POPS` folder. A VMC Group is used for games that can interact with each other's save data. This allows, for example, licenses earned in Gran Turismo to be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis to comment on other Konami games you've played.

Hotkey button combinations are supported for disc swapping and various other options. Full details can be found in the `Manual` of each installed PS1 game. To access it, select a game in the `Game Collection`, press `Triangle`, then select `Manual`.

## Save Application System (SAS)

Save Application System (SAS) is a new standard for distributing homebrew applications for the PS2. Currently in beta, but already has over 20 apps available for download on the [Save Application System Apps Archive](https://ps2wiki.github.io/sas-apps-archive/) with many more coming soon. All SAS-compliant apps come packed in a `PSU` file and include icons and metadata, making it the recommended way to install homebrew on PSBBN.

## PlayStation 2 Basic Boot Loader (PS2BBL)
If you choose to install the [PlayStation 2 Basic Boot Loader (PS2BBL)](https://israpps.github.io/PlayStation2-Basic-BootLoader/), the console will auto-boot into PSBBN unless the `cross` button is held during startup, in which case HDD-OSD will be launched instead (if installed).
Launch keys and other settings for PS2BBL can be modified by editing the `CONFIG.INI` file stored on the internal drive at `__sysconf/PS2BBL`, more info can be found [here](https://israpps.github.io/PlayStation2-Basic-BootLoader/documentation/configuration.html).

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

An application called [BBN Launcher](https://github.com/pcm720/bbnl) resides on the APA partitions and directs [Open PS2 Loader](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) to launch specific PS2 games and apps from the exFAT partition.

<font size="4"><b>Warning: Manually creating new APA partitions on your PS2 drive and exceeding the 128 GB limit will corrupt the drive.</b></font>

# Troubleshooting

## Problems Launching PSBBN
When you connect the drive to your PS2 console and power it on, PSBBN should automatically launch.

### Fat PS2 console models SCPH-3000x-500xx:
If your console boots to the regular OSD or freezes, it means that your drive has not been recognised or you are experiencing a hardware issue. You should check the following:
1. Make sure you are using an official Sony Network Adapter; 3rd-party adapters are not supported
2. Ensure the network adapter and drive are securely connected to the console
3. Check that the connectors on the console and network adapter are clean and free of dust/debris
4. If using a SATA mod, make sure it has been installed correctly
5. Try using a different HDD/SSD
7. Try using a different IDE converter/SATA mod
8. Try a different official Sony Network Adapter

### Slim PS2 console model SCPH-700xx:
If you are using a PS2 Slim SCPH-700xx model with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar mod, download the [External HDD Drivers](https://israpps.github.io/FreeMcBoot-Installer/test/8_Downloads.html). Extract the files and place `hddload.irx`, `dev9.irx`, and `atad.irx` in the appropriate system folder for your region on an official Sony PS2 Memory Card:

| Region   | Folder Name   |
|----------|-------------- |
| Japanese | BIEXEC-SYSTEM |
| American | BAEXEC-SYSTEM |
| Asian 	 | BAEXEC-SYSTEM |
| European | BEEXEC-SYSTEM |
| Chinese  | BCEXEC-SYSTEM |

If, after doing so, the console freezes at the `PlayStation 2` logo, the most likely cause is an incompatible IDE to SD card adapter.

## Problems Launching Games
If games do not appear in the games list in [NHDDL](#neutrino-and-nhddl) or [OPL](#open-ps2-loader-opl) after modifying the OPL settings as described [above](#open-ps2-loader-opl), and fail to launch from the PSBBN Game Collection, try the following:

1. If you have a [mod chip](#known-issueslimitations-of-psbbn), disable it
2. Re-run `03-Game-Installer.sh` and select a different game launcher
3. Connect the PS2 HDD/SSD directly to your PC using an internal SATA connection or a different USB adapter, then re-run `02-PSBBN-Installer.sh`
4. Try using a different HDD/SSD and re-run `02-PSBBN-Installer.sh`
5. Try using a different IDE converter/SATA mod on your console

# Known Issues
- Using a Definitive Patch version older than 2.10 with the latest game installer may corrupt APA partitions, rendering PSBBN unbootable. If you are running an older version, it is highly recommended that you upgrade by running the `02-PSBBN-Installer.sh` script.
- PSBBN only supports dates up to the end of 2030. When setting the time and date, the year must be set to 2030 or below.  
- PSBBN will freeze when launching apps if a mod chip is detected. To use PSBBN, mod chips must be disabled.  
- PSBBN will freeze at the "PlayStation 2" logo when booting, if a 3rd party, unofficial HDD adapter is used. An official Sony Network Adapter is required.  
- When using a drive larger than 2 TB, the first 128 GB will be allocated to the PlayStation File System (PFS), and the next 2 TB will be formatted as an exFAT partition. Any remaining space beyond that will be unusable.
- [OPL](#open-ps2-loader-opl) cannot read settings saved on the exFAT partition of the internal drive. Settings should be saved to a PS2 memory card. If you have a MemCard Pro 2 or SD2PSX, it is recommended that you save your OPL settings to a standard PS2 memory card inserted in slot 2.
- `wLaunchELF` and other native PS2 apps cannot create PFS partitions on the PS2 drive. New partitions should only be created using the version of `PFS Shell` included with this project. When creating additional partitions, care must be taken to ensure PFS partitions do not exceed the first 128 GB of drive space, or the drive will become corrupted.
- HDD-OSD may report drives larger than 960 GB as broken.

\* Instances in feega where some Japanese text couldn't be translated due to it being hard-coded in an encrypted file. Atok software has not been translated.  
\** The default on-screen keyboard is set to Japanese. However, a US English on-screen keyboard has been added, though you’ll need to press the `SELECT` button multiple times to switch to it. There's a bug where spacebar doesn't work on the US English on-screen keyboard, but you can enter a space by pressing the `triangle` button on the controller instead.

# Credits
**PSBBN Definitive Project - Copyright © 2024-2026 by [CosmicScale](https://github.com/CosmicScale)**
- PSBBN English translation by [CosmicScale](https://github.com/CosmicScale)
- `01-Setup.sh`, `02-PSBBN-Installer.sh`, `03-Game-Installer.sh`, `04-Extras.sh`, `art_downloader.js`, `list-sorter.py` `txt_to_icon_sys.py` written by [CosmicScale](https://github.com/CosmicScale)
- `ps2iconmaker.sh` written by [Sakitoshi](https://github.com/Sakitoshi) and [CosmicScale](https://github.com/CosmicScale)
- `icon_sys_to_txt.py` written by [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- VMC icon designed by Yornn
- Uses APA-Jail code from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) by [Berion](https://www.psx-place.com/members/berion.1431/)
- Contains code from `list_builder.py` from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma), modified by [CosmicScale](https://github.com/CosmicScale)
- Contains data from `TitlesDB_PS1_English.txt` and `TitlesDB_PS2_English.txt` from the [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) by [GDX-X](https://github.com/GDX-X), modified by [CosmicScale](https://github.com/CosmicScale)


- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/8Mb) and [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) with 8MB PFS partition modifications by [AKuHAK](https://github.com/AKuHAK)
- [BBN Launcher](https://github.com/pcm720/bbnl) written by [pcm720](https://github.com/pcm720) and [CosmicScale](https://github.com/CosmicScale)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) with BDM contributions from [KrahJohlito](https://github.com/KrahJohlito) and Auto Launch modifications by [CosmicScale](https://github.com/CosmicScale)
- [Neutrino](https://github.com/rickgaiser/neutrino) by [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) written by [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/threads/popstarter.19139/) written by [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [Retro GEM Disc Launcher](https://github.com/CosmicScale/Retro-GEM-PS2-Disc-Launcher) written by [CosmicScale](https://github.com/CosmicScale)
- [APA Partition Header Checksumer](https://www.psx-place.com/resources/apa-partition-header-checksumer.1057/) by [Pink1](https://www.psx-place.com/members/pink1.1907/) and [Berion](https://www.psx-place.com/members/berion.1431/). [Linux port](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) by [Bucanero](https://github.com/Bucanero)
- [`PSU Extractor.elf`](https://github.com/bucanero/psv-save-converter) written by [Bucanero](https://github.com/Bucanero) from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) project
- `ziso.py` from [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) written by Virtuous Flame
- [PlayStation 2 Basic Boot Loader (PS2BBL)](https://github.com/israpps/PlayStation2-Basic-BootLoader) written by [Matías Israelson (israpps)](https://github.com/israpps)
- [wLaunchELF_ISR](https://israpps.github.io/projects/wlaunchelf-isr) by [Matías Israelson (israpps)](https://github.com/israpps)
- Online channels resurrected, translated, maintained and hosted by vitas155 at [psbbn.ru](https://psbbn.ru/)
- PlayStation Now! and Konami online channels translated by [CosmicScale](https://github.com/CosmicScale)
- [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- Uses PS2 cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups)
- Uses App icons from [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) and [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) courtesy of [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- This project also uses [PS1VModeNeg](https://github.com/ps2homebrew/PS1VModeNeg)

**Third-Party Libraries & Binaries:** 
- Source code for the BB Navigator kernel can be found [here](https://github.com/rickgaiser/linux-2.4.17-ps2)
- `mkfs.exfat` from [exfatprogs](https://github.com/exfatprogs/exfatprogs)

**All libraries and utilities are open-source and used in accordance with their respective licenses.**

**Thanks:**
- Thanks to everyone on the [Save Application System team](https://ps2wiki.github.io/documentation/homebrew/PS2-App-System/SAS/index.html#Credits) for their ongoing work on the [Save Application System Apps Archive](https://ps2wiki.github.io/sas-apps-archive/)
- Thanks to [pcm720](https://github.com/pcm720) for patching osdboot.elf ansd bypassing the CRC security check
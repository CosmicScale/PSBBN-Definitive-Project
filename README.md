# PSBBN Definitive Project
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/blob/main/LICENSE)  
This is the Definitive Project for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console.

PSBBN is official Sony software for the PlayStation 2, released exclusively in Japan. Introduced in 2002 as a replacement for the PS2’s OSD, it required both a hard drive and a network adapter to function. It added many new features:
- Launching games from the hard drive
- Accessing online channels
- Downloading full games, demos, videos, and pictures
- Ripping audio CDs and transferring music to MiniDisc recorders in the Music Channel
- Watching videos in the Movie Channel
- Transferring photos from a digital camera and viewing them in the Photo Channel

The **PSBBN Definitive Project** (formerly the PSBBN Definitive English Patch) began in 2023 as an English-language patch for PSBBN, but steadily expanded well beyond its original scope. The project aims to translate PSBBN from Japanese into multiple languages, introduce modern features, and make it a viable daily driver in 2026 and beyond.

You can find out more about the original PSBBN software on [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) and follow the development of this project on my [YouTube channel](https://www.youtube.com/@CosmicScaleFactor).

# Donations  
If you appreciate my work and want to support the ongoing development of the **PSBBN Definitive Project** and other PS2-related projects, [you can donate to my Ko-Fi](https://ko-fi.com/cosmicscale).

This project uses [webhook.site](https://webhook.site/) to automatically contribute game artwork/icons and report missing artwork/icons to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) and the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). As the project has grow in popularity, we're exceeding the limit offered by a free account. A paid subscription costs $9/month or $90/year, donations help fund this.

# Video demonstration of PSBBN

[![PSBBN in 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Features
- A full translation of the stock Japanese BB Navigator version 0.32 — All binaries, XML files, textures, and pictures have been translated[*](#known-issues)
- Available in English, German, Italian, Portuguese (Brazil), Spanish, French, and the original Japanese
- Compatible with any fat model PS2 console as well as [PS2 Slim SCPH-700xx models](#early-scph-1000018000-and-slim-scph-700xx-consoles) with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod, regardless of region
- DNAS authorization checks bypassed to enable access the online channels
- English translations of the [online channels](#internet-channel) from Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, and Bandai hosted by vitas155 at [psbbn.ru](https://psbbn.ru/) (work in progress)
- Access the original Japanese [online channels](#internet-channel) if you select Japanese as your language
- **Audio Player** feature re-added to the [Music Channel](#music-channel) from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders[*](#known-issues)
- Associated manual pages and troubleshooting regarding the **Audio Player** feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard[*](#known-issues)
- The **×** and **○** buttons have been swapped: **×** is now Enter, and **○** is now Back.
- Support for the PlayStation 2 DVD remote control[*](#known-issues)
- Direct link to the [Game Collection](#game-collection) in the Top Menu
- Launch up to 800 PS1/PS2 games and apps directly from the [Game Collection](#game-collection)
- Large HDD support: No longer limited to 128 GB — now supports larger drives, with a user-definable space between 16 GB and 128 GB allocated to the PlayStation File System (PFS), and up to 2 TB allocated to exFAT
- exFAT filesystem for storing both PS2 games and homebrew applications
- [POPS](#popstarter-and-virtual-memory-cards) partition up to 113 GB for PS1 games
- Set a custom size for your music partition. Originally limited to 5 GB. Now the partition can be up to 113 GB for around 180 albums[*](#known-issues)
- Set a custom size for your contents partition for the storage of movies and photos. Originally limited to 5 GB, can now be up to 113 GB
- [VMC Groups](#popstarter-and-virtual-memory-cards) for PS1 games
- Full [Game ID](#game-id) support for the **Pixel FX Retro GEM** and **MemCard Pro/SD2PSX** — works with installed games and apps, as well as physical PS1 and PS2 game discs
- [HOSDMenu](#hosdmenu): A patched **HDD-OSD** that brings a number of improvements
- [PSBBN and HOSDMenu installer](#install-psbbn-and-hosdmenu) makes setup easy
- [Game and App Installer](#game-and-app-installer) fully automates the installation of PS1/PS2 games as well as `ELF` and [SAS-compliant](#save-application-system-sas) homebrew apps
- A choice of [OPL](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for you game launcher
- Includes the apps [wLaunchELF_ISR](#wlaunchelf_isr), [OSDMenu Configurator](#osdmenu-configurator), with a choice of either [OPL](#open-ps2-loader-opl) or [NHDDL](#neutrino-and-nhddl)
- [Music Installer](#music-installer) for converting and installing music
- [Movie Installer](#movie-installer) for converting and installing videos
- [Photo Installer](#photo-installer) for converting and installing images
- Install [optional extras](#optional-extras) such a [PS2 Linux](#install-ps2-linux)

# Changelog

**March 26th, 2026 - 4.2.0 Update: New Online Channels plus French Localisation**
- PSBBN system software updated to patch 4.2.0
- The Game Channel has been renamed to the **[Internet Channel](#internet-channel)**, reflecting its online focus
- New online channels added: BANDAI CHANNEL, So-Net, and BIGLOBE
- Download new game trailer in higher quality, with thumbnails
- French language support is now available for PSBBN

**March 5th, 2026 - Movie and Photo Installers, OSDMenu Configurator and more!**  
<p></p>

[![Movie and Photo Installers, OSDMenu Configurator and more!](https://github.com/user-attachments/assets/f0fae1ee-bf04-4aea-88a6-89e030926282)](https://youtu.be/_jKzzsClgOY)

**More Languages:**
- In addition to English, Japanese, and German, PSBBN is now available in Italian, Portuguese (Brazil), and Spanish

**[Update PS2 System Software:](#update-ps2-system-software)**
- Replaces **Update PSBBN Software**. This new option updates both the **PSBBN** and **[OSDMenu](#hosdmenu)** System Software
- The **PSBBN Definitive Project** **[Main Menu](#main-menu)** now shows a notification when **PS2 system software updates** are available

**[Install Movies:](#movie-installer)**
- The **[Install Movies](#movie-installer)** option has been added to the **[Install Media Menu](#media-installer)**
- You can now place a variety of video formats, including `MP4`, `M4V`, `MKV`, `VOB`, and more, in the `movie` folder
- Selecting **[Install Movies](#movie-installer)** will convert the video files to the `PSM` format supported by **PSBBN**
- Videos will then be playable in the **[PSBBN Movie Channel](#movie-channel)**

**[Install Photos:](#photo-installer)**
- The **[Install Photos](#photo-installer)** option has been added to the **[Install Media Menu](#media-installer)**
- You can now place a variety of image formats, including `JPG`, `PNG`, `TIF`, `GIF`, `BMP`, and more, in the `photo` folder
- Selecting **[Install Photos](#photo-installer)** will convert the image files to `PNG` and resized them if necessary
- Images will then be viewable in the **[PSBBN Photo Channel](#photo-channel)**

**[OSDMenu 1.2.0:](#osdmenu-mbr)**
- Both **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)** have been updated to version 1.2.0. The changelog can be found **[here](https://github.com/pcm720/OSDMenu/releases)**
- The **[OSDMenu Configurator](#osdmenu-configurator)** app has been added. This allows you to customise your PS2 console by modifying the settings for both **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)**
- The **[OSDMenu Configurator](#osdmenu-configurator)** will be installed the next time you select **[Install Games and Apps](#game-and-app-installer)** from the **PSBBN Definitive Project [Main Menu](#main-menu)**. It can be launched from the **[PSBBN Game Collection](#game-collection)**, or **[HOSDMenu](#hosdmenu)**

**[HOSDMenu-only installs:](#install-hosdmenu-only)**
- Increased maximum **[POPS](#popstarter-and-virtual-memory-cards)** partition size to 130 GB.
- Added language selection. The selected language is used by the game installer for game titles and the **[POPS IGR message](#exiting-games)**
- **[HOSDMenu-only](#hosdmenu)** users can now change the language of their install in the **[Optional Extras Menu](#optional-extras)**

**[Change Screen Settings:](#change-screen-settings)**
- Previously locked on **PSBBN**, you can now change your system’s screen settings in the **[Optional Extras Menu](#optional-extras)** to 4:3, Full, or 16:9
- **Note:** This setting is used by some games and **[HOSDMenu](#hosdmenu)**. It does not change the aspect ratio of **PSBBN** itself

**[Clear Art & Icon Cache:](#clear-art--icon-cache)**
- In the **[Optional Extras Menu](#optional-extras)**, you now have the option to clears all previously downloaded artwork and icons that are stored locally on your PC
- You may want to clear the cache if games display incorrect or low-quality artwork, as updated artwork may now be available
- Running the **[Game Installer](#game-and-app-installer)** will then download the latest artwork and icons

**[PSBBN Launcher for Windows:](#installing-on-windows)**
- Added support for installing games from a network drive
- Added a prompt that displays supported files for the **[Movie Installer](#movie-installer)** and **[Photo Installer](#photo-installer)**
- Corrected minimum drive capacity warning message
- Bug fixes

**Bug Fixes and Improvements:**
- Enabled PS2 logo when launching physical PS2 game discs for fresh installs. Users upgrading can turn this option on using the **[OSDMenu Configurator](#osdmenu-configurator)**. **[MechaPwn](https://github.com/MechaResearch/MechaPwn)** users can now launch imports and master discs without skipping the PlayStation 2 logo or encountering a corrupted logo screen
- When **[reassigning the Cross and Circle buttons](#reassign-cross-and-circle-buttons)**, your preference is now stored and no longer reset when installing updates
- Improved the title ID extraction from VCD files
- PSBBN Installer display the typical size requirements for music and movies when creating partitions 
- A separate log file is used when installing and updating
- Fixed PSU extraction when folder names exceed 12 characters
- Fixed an issue with **[Navigator Menu shortcut](#game-collection)** being removed on reboot
- Fixed capacity and available space calculations for drives smaller than 128 GB
- Added a delay between unmounting and mounting filesystems to improve reliability
- Fixed error tracking for SQLite
- Improved art downloads for `SAS` and `ELF` apps

<details>
<summary><b>January 8th, 2026 - PSBBN Definitive Project: New Name and Multilingual Support</b></summary>
<p></p>

[![PSBBN Definitive Project: New Name and Multilingual Support](https://github.com/user-attachments/assets/32bb93f2-c009-4b82-ba62-67933ff30e83)](https://www.youtube.com/watch?v=dvCt_ExHwro)

The PSBBN Definitive English Patch started life in 2023 as an English language patch for PSBBN, this work has steadily expanded well beyond its original scope. Going forward, it will now collectively be called the **PSBBN Definitive Project**.

PSBBN is now available in English, German, Italian, and the original Japanese, with a French translation coming soon. You will be given a choice of languages when installing PSBBN. The language can also be changed later in the **[Extras Menu](#optional-extras)**.

When the language is set to Japanese, titles of Japanese-region games are displayed in Japanese and sorted in “gojūon” (五十音) order in both the **[PSBBN Game Collection](#game-collection)** and the **[HOSDMenu Browser](#hosdmenu)**. In addition, the original Japanese online channels are also accessible from the **[Internet Channel](#internet-channel)**.

**Full release notes**  

- **NEW!** PSBBN German translation by [Argo707](https://github.com/Argo707)  
- Improved English translation  
- Original Japanese online channels restored

**[PSBBN Installer:](#install-psbbn-and-hosdmenu)**
- Added an option to select a language when installing PSBBN
- Selecting Japanese will also install the original Japanese **[online channels](#internet-channel)**

**[Update PSBBN Software:](#update-ps2-system-software)**
- Now updates the PSBBN System Software and language pack to the latest version
- When the language is set to Japanese, the online channels are also updated

**[Optional Extras:](#optional-extras)**
- Added the option to change the language of PSBBN in the **[Optional Extras](#optional-extras)** menu

**[Game Installer:](#game-and-app-installer)**
- When the language is set to Japanese, titles of Japanese-region games will be displayed in Japanese and sorted in “gojūon” (五十音) order
- The POPS IGR message is installed for the selected language
- PS1 game manuals are installed for the selected language

**`TitlesDB_PS1.csv` and `TitlesDB_PS2.csv`:**  
- Added Japanese game titles for all Japanese-region games

**`list-builder.py`:**
- Updated to handle Japanese game titles

**PSBBN Definitive Patch updated to v4.1.0**
- Updated the link to the new Konami Channel for non-Japanese installations
- Modified `fstab` to mount `channels` partition

**General**:  
- The system language is now set to the selected PSBBN language and is no longer reset to English or Japanese when launching PSBBN
- Added `libicu-dev` and `pkg-config` to the dependencies
- Improved POPS English IGR message
- Added warning to prevent internal scripts from being run directly
- Added installation validation check to abort unsupported installs
</details>

<details>
<summary><b>November 14, 2025 - PSBBN Definitive Patch v4.0 - OSDMenu, 3rd Party HDD adapters and more!</b></summary>
<p></p>

[![PSBBN Definitive Patch v4.0 - OSDMenu, 3rd Party HDD adapters and more!](https://github.com/user-attachments/assets/1a3f2d69-6bec-4fe4-aa27-c367f5d98f98)](https://www.youtube.com/watch?v=fT368C90Trc)

**[NEW! OSDMenu MBR:](#osdmenu-mbr)**  
Replaced Sony’s original MBR application with **[OSDMenu MBR](#osdmenu-mbr)**, a homebrew alternative that:
- Handles launching games and apps directly instead of relying on **BBN Launcher (BBNL)**
- Improves boot speed
- Games now launch up to 6 seconds faster
- Eliminates the need for the **PlayStation 2 Basic Boot Loader (PS2BBL)** — **[OSDMenu MBR](#osdmenu-mbr)** natively supports launching ELFs by holding a gamepad button at startup, drastically reducing boot times compared to **PS2BBL**
- PS2 Linux is now booted directly by holding **○** at power-on instead of interrupting **PSBBN** startup
- Removed the **"Launch Disc"** app — simply insert a game disc to play, with support for **[Game ID, MechaPwn and built-in PS1VmodeNeg!](#launching-ps1-and-ps2-game-discs)**
- Improves **[Retro GEM Game ID](#game-id)** handling — **PSBBN** and **[HOSDMenu](#hosdmenu)** now both set a **Game ID** on boot, removing the need for the **Retro GEM Game ID Resetter**
- When using a **MemCard Pro 2 or SD2PSX**, unnecessary **VMCs** are no longer generated when launching PS1 games with **[POPStarter](#popstarter-and-virtual-memory-cards)** or other homebrew apps

**[NEW! HOSDMenu:](#hosdmenu)**  
Patches **HDD-OSD** and introduces several improvements:
- Supports larger drives — previously limited to 1 TB
- Launch homebrew apps directly from the **OSDSYS menu**
- Launch **[SAS-compatible applications](#save-application-system-sas)** from Memory Cards and from the internal drive in **[Browser 2.0](#hosdmenu)**
- Support for launching applications from MMCE, MX4SIO, UDPBD, iLink devices and APA- and exFAT-formatted HDDs
- Integrated GSM for disc games and applications
- Support for 1080i and 480p
- And more — see the [GitHub repository](https://github.com/pcm720/OSDMenu) for full details

**[NEW! Install PSBBN and HOSDMenu:](#install-psbbn-and-hosdmenu)**
- The PSBBN Installer now installs **[HOSDMenu](#hosdmenu)** alongside **PSBBN**
- Shows latest release notes when installing and updating
- Supports smaller drives — minimum capacity reduced from 200 GB to 32 GB
- Increased max APA partition size to 112 GB
- After partitioning, any unallocated space is now assigned to the **[OPL](#open-ps2-loader-opl)** partition
- Advises users to check [archive.org](https://archive.org/) or use a VPN if downloads fail

**[NEW! Install HOSDMenu only:](#install-hosdmenu-only)**
- Adds an option to install **[HOSDMenu](#hosdmenu)** only (for users with third-party HDD adapters)
- Create a custom-size **[POPS](#popstarter-and-virtual-memory-cards)** partition (up to 118 GB), automatically assigning remaining space to the **[OPL](#open-ps2-loader-opl)** partition (up to 2 TB)

**[Game Installer:](#game-and-app-installer)**
- **[Game Installer](#game-and-app-installer)** now requires **PSBBN Definitive Project v4.0.0** and above or **[HOSDMenu-only](#install-hosdmenu-only)**
- Adds support for **[HOSDMenu](#hosdmenu)**-only setups
- Updates **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)** if newer versions are available
- Updates the **Navigator Menu** with shortcuts to your selected game launcher (**[OPL](#open-ps2-loader-opl)** or **[NHDDL](#neutrino-and-nhddl)**), **[HOSDMenu](#hosdmenu)** and **[wLaunchELF_ISR](#wlaunchelf_isr)**
- Updates the **[HOSDMenu](#hosdmenu)** config to display installed homebrew apps in the **OSDSYS menu**
- Automatically converts PS1 `BIN/CUE` files to `VCD` and PS2 `BIN/CUE` file to `ISO`
- PS1 games are now copied and synced through `PFS FUSE` using `rsync`, with visible progress during transfer
- Copies only valid game and homebrew files when syncing or adding games and apps — `rsync` now ignores Windows `:Zone.Identifier` metadata files that could cause sync failures
- Automatically capitalizes lowercase `.VCD` extensions to ensure compatibility with **[POPStarter](#popstarter-and-virtual-memory-cards)**
- Relocated `OPNPS2LD.ELF` and `nhddl.elf` to `__system/launcher` and `POPSTARTER.ELF` to `__common/POPS` from exFAT

**`list-builder.py`:**
- Now scans the PFS `__.POPS` partition for `VCD` files instead of local `POPS` folder

**`art_downloader.py`:**
- Converted `art_downloader` from JavaScript to Python, removing dependencies on Node.js, npm, Puppeteer, and Chromium

**[Install Music:](#music-installer)**
- Adds support for multi-disc albums using disc numbers from metadata
- Uses **Album Artist** metadata for albums, and **Artist** metadata for individual tracks
- Replaces unsupported characters in metadata with safe alternatives
- Clearly groups skipped files by reason

**[PS2 Linux Installer:](#install-ps2-linux)**
- Updates **[OSDMenu MBR](#osdmenu-mbr)** config to enable the booting of PS2 Linux.

**[PSBBN Launcher for Windows:](#installing-on-windows)**
- Minimum disk capacity reduced from 200 GB to 32 GB
- User prompts are now more descriptive
- Prevents users from selecting a WSL folder to store their games and media
- Enforces build 19041 as the minimum Windows version required to run WSL
- Runs `wsl --install --no-distribution` to ensure WSL 2 is available
- Explicitly uses WSL 2 when installing the PSBBN distribution
- Checks that apt successfully installed git; exits gracefully otherwise
- Updated disk number input to support values greater than 9
- Gracefully exits if disk mounting fails

**[NHDDL:](#neutrino-and-nhddl)**
- Updated to version v1.2.0

**`Setup.sh` and `flake.nix`:**
- Added `bchunk` to dependences 

**Definitive Patch 4.0.0 Tar Archive:**
- Fixes file permissions and ownership
- Removed cached files and other unnecessary bloat, reducing the archive size
- Added additional folders for **[HOSDMenu and HDD-OSD](#hosdmenu)** files
- Replaced encrypted **osdboot.elf** with unencrypted version

**General:**
- Added support for ARM64 systems. Tested on a Raspberry Pi with the latest version of Raspberry Pi OS
- `BOOT.ELF` replaced with [SAS-compliant](#save-application-system-sas) [wLaunchELF_ISR](#wlaunchelf_isr) version 4.43x_isr-bb13043
- Removed `PS1VModeNeg.elf`
- Changes locale setting from `en_US.UTF-8` to `C.UTF-8` (some systems lacked `en_US.UTF-8`), ensuring script output and logs remain in English and preventing related failures
- Improved handling of mounting and unmounting APA partitions
- Bug fixes
- Added software licences

</details>

<details>
<summary><b>September 09, 2025 - PSBBN Launcher for Windows: Easy Install & Setup</b></summary>
<p></p>

[![PSBBN Launcher for Windows: Easy Install & Setup](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**[NEW! PSBBN Launcher For Windows](#installing-on-windows)** - The New way to install the **PSBBN Definitive Project** on Windows 10 and 11.  
Special thanks to Yornn for all his work on this feature.

</details>

<details>
<summary><b>August 28, 2025 - PSBBN Definitive Patch v3.00 - Music Installer, Menu System, Faster Installs & More!</b></summary>
<p></p>

[![PSBBN Definitive English Patch 3.0](https://github.com/user-attachments/assets/3b82d809-28d5-4675-87c2-c7f1abf96ae6)](https://www.youtube.com/watch?v=lUMKZck6G08) 
  
**[NEW! Menu System:](#main-menu)**
- New central menu system instead of separate scripts, making it easier to navigate the various features of the **PSBBN Definitive Project**
- Setup now runs automatically if missing dependencies are detected

**[NEW! Music Installer:](#music-installer)**
- Install music for playback on the **[PSBBN Music Channel](#music-channel)**. Supported formats: `.mp3`, `.m4a`, `.flac`, and `.ogg`

**[NEW! PSBBN Installer:](#install-psbbn-and-hosdmenu)**
- **PSBBN** has fully transitioned from ReiserFS (an old, no-longer-supported filesystem) to ext2, allowing direct access to all BBN partitions
- The new PSBBN Installer works with a tar archive instead of a disk image, reducing download size and drastically improving install time
- When installing, you can set a custom size for the `contents` partition used for movies and photos (previously limited to 5 GB)
- Increased maximum size of the Music, Contents, and POPS partitions — now up to 111 GB

**[NEW! PSBBN Updater:](#update-ps2-system-software)**
- Allows updating to the latest version of the Definitive Project directly from the menu. No USB thumb drive or USB keyboard required!

**[Game Installer:](#game-and-app-installer)**
- The game installer now offers an HDTV fix for PS1 games, allowing them to display on TVs that do not support 240p
- Bug fixes and improved Game ID extraction for ISO and VCD files.  
- Extracts Game ID directly from ZSO files by decompressing only part of the disc image; ZSO files no longer need to be fully decompressed or renamed, greatly improving processing time

**[Extras:](#optional-extras)**
- PS2 Linux is now an optional install. You can set a custom size for your home partition. PS2 Linux can also be reinstalled if you experience issues
- Swap the functions of the Cross and Circle buttons on your controller. Choose between the standard layout (Cross = Enter, Circle = Back) or the alternate layout (Circle = Enter, Cross = Back)

**HDD-OSD (Browser 2.0):**
- New PSBBN icon designed by Yornn
- New improved background colour when viewing game icons

</details>

<details>
<summary><b>July 17, 2025 - Definitive Patch v2.11 - Boot Security Patched! Button Swap, VMC Groups & More!</b></summary>
<p></p>

[![PSBBN Definitive Patch v2.11](https://github.com/user-attachments/assets/49511803-429b-4cd8-8546-40334be3f244)](https://www.youtube.com/watch?v=kgXe8rlqsr0)

**PSBBN Updated to Definitive Patch v2.11**

Patch v2.11 can be installed by running the [PSBBN Installer script](#install-psbbn-and-hosdmenu) (all data will be lost), or via the new **Update PSBBN Software** option in the [Extras script](#optional-extras).

**New in Definitive Patch v2.11:**
- Boot Security Patched. The CRC security check in PSBBN’s boot ELF has been bypassed, allowing the loading of custom kernels.
- The **×** and **○** buttons have been swapped: **×** is now Enter, and **○** is now Back.
- Added support for the PlayStation 2 DVD remote control. The `PLAY`, `PAUSE`, `STOP`, `PREV`, `NEXT`, `SCAN`, and `DISPLAY` buttons can now be used during music and movie playback in the [Music](#music-channel) and [Movie](#movie-channel) channels. The `ENTER` button can also be used when navigating menus.
- The **PlayStation BB Guide** has been updated to reflect the button swap and the relocation of the [Game Collection](#game-collection). A new section has been added covering the Online Channels. Numerous improvements to the English translation.
- Improves the update process. A USB drive and keyboard will not be required for future updates.

**`02-PSBBN-Installer.sh`:**
- You can now set a custom size for the [POPS](#popstarter-and-virtual-memory-cards) partition. Previously, it filled all remaining space after creating the music partition.

**`03-Game-Installer.sh`, `ps2iconmaker.sh` & `txt_to_icon_sys.py`:**

- Multi-disc PS1 games now support disc swapping without additional setup. A `DISCS.TXT` file is created for every multi-disc game. Multi-disc games also now share a [POPStarter Virtual Memory Card (VMC)](#popstarter-and-virtual-memory-cards)
- [POPStarter VMC Groups](#popstarter-and-virtual-memory-cards) for PS1 games: games that can interact with each other's save data now share a single VMC. For example, licenses earned in Gran Turismo can be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis can comment on other Konami games you've played.
- VMCs now display clearer titles in **Save Data Management** and **Browser 2.0** with custom icons for each game and group.
- The game installer now automatically generates HDD-OSD (Browser 2.0) icons if not found on the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If cover images for a game are available in the OPL Manager Art Database, a 3D icon for the game will be automatically generated. 3D icons are also created for VMCs when a game logo is available. All newly generated icons are automatically contributed to the HDD-OSD Icon Database, and missing icons are reported.
- Fixed a bug where incorrect publisher information could be displayed for `ELF` files

**`list-builder.py`:**

- Improved Game ID extraction for edge cases. Now handles non-standard IDs like `LSP99016.101` and PS1 games with non-standard `system.cnf` files.

**Neutrino Updated to Version 1.7.0**

- Full changelog for Neutrino can be found [here](https://github.com/rickgaiser/neutrino/releases/tag/v1.7.0)

**Open PS2 Loader Updated to v1.2.0 Beta-2210-6b300b0**
- Adds support for VMC Groups and bug fixes.

**wLaunchELF**
- Upgraded to [wLaunchELF v4.43x_isr](#wlaunchelf_isr). Improves stability, and adds support for exFAT on external drives and MMCE (SD card browsing on MemCard Pro 2/SD2PSX).

</details>

<details>
<summary><b>June 05, 2025 - PSBBN Definitive Patch v2.10 – Big Game Installer Changes & More!</b></summary>
<p></p>

[![PSBBN Definitive Patch v2.10](https://github.com/user-attachments/assets/ff4e6e5b-8556-4fe2-88b2-99e7eb09121c)](https://www.youtube.com/watch?v=XTacIPOGAwE)

**PFS Shell.elf & HDL Dump.elf:**

- PFS Shell updated to support creating 8 MB APA partitions
- HDL Dump updated to properly modify their headers

**PSBBN Disk Image Updated to Version 2.10:**

- Disk created with a new version of PFS Shell for full compatibility with 8 MB APA partitions 
- Added a direct link to the [Game Collection](#game-collection) in the Top Menu  
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
  - Space reserved for 800 **BBNL partitions**  
- Removed [POPS](#popstarter-and-virtual-memory-cards) installer (now handled by the Game Installer script)  
- Code has been significantly cleaned up and optimized  

**`03-Game-Installer.sh`:**

- Added a warning for users running PSBBN Definitive Patch below version 2.10
- The PS2 drive is now auto-detected  
- Added an option to set a custom path to the `games` folder on your PC
- Allows new games and apps to be added without requiring a full sync  
- **BBNL** partition size reduced from 128 MB to 8 MB, enabling up to 800 games/apps to be displayed in the [Game Collection](#game-collection)
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

<details>
<summary><b>May 01, 2025 - SAS, HDD-OSD, PS2BBL & More!</b></summary>

[![SAS, HDD-OSD, PS2BBL & More!](https://github.com/user-attachments/assets/be5b32d2-665c-4505-aefe-3c9ab864f72a)](https://www.youtube.com/watch?v=vpbHlS8nY58)

- Added support for the [Save Application System (SAS)](#save-application-system-sas). `PSU` files can now also be placed in the local `games/APPS` folder on your PC and will be installed by the `03-Game-Installer.sh` script
- Added support for HDD-OSD to the `03-Game-Installer.sh` script. 3D icons are now downloaded from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- New script: [04-Extras.sh](#optional-extras). Added ability to install HDD-OSD and [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
- Make your own HDD-OSD icons with the [HDD-OSD Icon Templates](https://github.com/CosmicScale/HDD-OSD-Icon-Database/releases/download/v1.0.0/HDD-OSD-Icon-Templates.zip)
- Translate PSBBN using the [Translation Pack](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/issues/299) to localize the software into different languages.

</details>

<details>
<summary><b>Mar 28, 2025 - Homebrew Launcher & More!</b></summary>
<p></p>

[![Homebrew Launcher & More!](https://github.com/user-attachments/assets/57e7842c-f5b5-46b0-950e-246eebfb0e4a)](https://www.youtube.com/watch?v=q9LvE_OPIPo)

- [Open PS2 Loader](#open-ps2-loader-opl) updated to version 1.2.0-Beta-2201-4b6cc21:
  - Limited max BDM UDMA mode to UDMA4 to avoid compatibility issues with various SATA/IDE2SD adapters
- Added a manual for PS1 games. It can be accessed in the [Game Collection](#game-collection) by selecting a game, pressing **△** and then selecting **Manual**
- Transitioned to **BBN Launcher (BBNL)** version 2.0:
  - Dropped PFS support in favour of loading [OPL](#open-ps2-loader-opl), [POPStarter](#popstarter-and-virtual-memory-cards), [Neutrino](#neutrino-and-nhddl), and configuration files from the exFAT partition to speed up initialization.
  - Moved **BBNL** to the APA header to further improve loading times.
  - Removed dependency on renamed [POPStarter](#popstarter-and-virtual-memory-cards) `ELF` files to launch PS1 VCDs; [POPStarter](#popstarter-and-virtual-memory-cards) is now launched directly with a boot argument.
  - [NHDDL](https://github.com/pcm720/nhddl) now launches in ATA mode, improving startup time and avoiding potential error messages.
- Updated [Neutrino](#neutrino-and-nhddl) to version 1.6.1
- Updated [NHDDL](#neutrino-and-nhddl) to version MMCE + HDL Beta 4.17
- Added cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups). Artwork for PS2 games is now displayed in OPL/NHDDL
- Added homebrew support to the `03-Game-Installer.sh` script. `ELF` files placed in the local `games/APPS` folder on your PC will be installed and appear in the [Game Collection](#game-collection) in PSBBN and the Apps tab in OPL
- Apps now support [Game ID](#game-id) for both the Pixel FX Retro GEM and MemCard Pro/SD2PSX

</details>

<details>
<summary><b>Feb 19, 2025 - BBN Launcher, Neutrino & NHDDL</b></summary>
<p></p>

[![BBN Launcher, Neutrino & NHDDL](https://github.com/user-attachments/assets/8007d102-3019-4037-8c52-24d1454777da)](https://www.youtube.com/watch?v=0vpSiAa6ITc)

- [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) has been replaced by **BBN Launcher (BBNL)**
- Added [Neutrino](#neutrino-and-nhddl) support. You can now choose between [Open PS2 Loader](#open-ps2-loader-opl) and [Neutrino](#neutrino-and-nhddl) as your game launcher
- When using Neutrino as your game launcher, [NHDDL](#neutrino-and-nhddl) can be used to make per-game settings

</details>

<details>
<summary><b>Jan 22, 2025 - Game ID, PSBBN Art Database, Updated Tutorial & More!</b></summary>

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
- Added [Open PS2 Loader](#open-ps2-loader-opl) and [Launch Disc](#launch-disc) to the [Game Collection](#game-collection)
- The Game Installer script has been updated to create and delete game partitions as needed. Say goodbye to those annoying "Coming soon..." placeholders!
- Files placed in the `CFG`, `CHT`, `LNG`, `THM`, and `APPS` folders on your PC will now be copied to the PS2 drive during game sync
- The scripts now auto-update when an update is available
- Optimised art work
- Introducing the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database)
- If artwork is not found in the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), an attempt is made to download from IGN. Art downloads from IGN are now automatically contributed to the [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), and missing artwork is also automatically reported. Manual submissions are welcome, see the [PSBBN art database GitHub page](https://github.com/CosmicScale/psbbn-art-database) for details

</details>

<details>
<summary><b>Dec 11, 2024 - PSBBN Definitive English Patch 2.0</b></summary>
<p></p>

[![PSBBN Definitive English Patch 2.0](https://github.com/user-attachments/assets/608c9430-25d8-4918-8111-023eac16ab62)](https://www.youtube.com/watch?v=ooH0FjltsyE)

- Initial release of patch version 2.0
- Bandai and SCEI online channels have been added to the Game Channel
- PS2 Linux dual-boot
- [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) pre-installed
- Large HDD support: no longer limited to 128 GB
- Introducing [APA-Jail](#apa-jail), allowing the PlayStation's APA partitions to co-exist with an exFAT partition
- Introducing [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM), allowing PS2 games stored on the exFAT partition to be launched from within PSBBN
- Introducing the [PSBBN Installer script](#install-psbbn-and-hosdmenu):
  - Installs PSBBN, [POPS binaries and POPStarter](#popstarter-and-virtual-memory-cards)
  - Partition the first 128 GB of the drive as APA:
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
## Requirements
The **PSBBN Definitive Project** script is essential for unlocking all the new features exclusive to version 2.0 and above. The script requires a PC with an x86-64 or ARM64 processor.

It is **recommended** to use a **fat PS2 console with an expansion bay** (**SCPH-3000x to SCPH-500xx**) and an **official Sony Network Adapter**.

**[PSBBN does not support third party HDD Adapters](#known-issues)**. However, when **[installing HOSDMenu only](#install-hosdmenu-only)**, third party HDD adapters are supported.

When using an official Sony Network Adapter, I would highly recommend installing a **Kaico** or **BitFunx IDE to SATA Upgrade Kit**.

It is also compatible with the **PS2 Slim SCPH-700xx** model with an **[IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/)** or similar hardware mod, as well as **SCPH-10000 to SCPH-18000** models with an **official external HDD enclosure**. **[Additional setup is required for these consoles](#early-scph-10000–18000-and-slim-scph-700xx-consoles)**.

You will also need an HDD/SSD for your PS2 that is at least 32 GB, ideally between 256 GB and 2 TB. A SATA SSD is also highly recommended. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface. To perform the installation, connect the HDD/SSD to your PC either directly via SATA or through a USB adapter.

## Installing on Linux
64-bit Debian-based distributions using `apt`, Arch-based distributions using `pacman`, and Fedora-based[*](#troubleshooting) distributions using `dnf` are supported. Nix-based systems are also supported via flakes. Recommended distributions are Linux Mint, and for Raspberry Pi, Raspberry Pi OS.

**The PSBBN Definitive Project is a rolling release. To get automatic updates and the latest bug fixes, you must install the scripts using `git clone`.**

Install git, for Debian-based distributions run:
```
sudo apt update
sudo apt install git
```
Clone the repository:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

You can then change to the `PSBBN-Definitive-Project` directory and run `PSBBN-Definitive-Patch.sh`:
```
cd PSBBN-Definitive-Project
./PSBBN-Definitive-Patch.sh
```
## Installing on Windows
The recommended way to install the **PSBBN Definitive Project** on Windows is by using the **PSBBN Launcher for Windows**. The **PSBBN Launcher for Windows** is compatible with Windows 10 and 11 Home editions; other editions may not be compatible. For a trouble-free experience, make sure Windows is fully up to date.

**Video Tutorial:**

[![PSBBN Launcher for Windows: Easy Install & Setup](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**Enabling Virtualization:**  
It may be necessary to enable SVM Mode (for AMD CPUs) or VT-x (for Intel CPUs) in your BIOS settings if it is not already enabled. Instructions on how to do this can be found [here](https://www.elevenforum.com/t/enable-or-disable-cpu-virtualization-in-uefi-bios-firmware-settings-on-windows-pc.4928/).

Download the **PSBBN Launcher for Windows [here](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)**.

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
- Automatically set up the **[Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/about)**
- Prompt you to select the target drive for installing **[PSBBN and HOSDMenu](#install-psbbn-and-hosdmenu)**, and a folder on your PC’s internal drive for managing games and media
- Launch the **PSBBN Definitive Project** **[Main Menu](#main-menu)**

**Accessing the PSBBN Definitive Project Main Menu in the Future:**  
Simply right-click on `PSBBN-Launcher-For-Windows.ps1` and select **Run with PowerShell**

**NOTE:**  
It is normal for the selected drive to be unmounted in Windows while running the script. Always exit the **[PSBBN Definitive Project Main Menu](main-menu)** by pressing `q`. This ensures the drive is safely unmounted from WSL and returned to Windows. For USB drives, remember to also eject them from the Windows system tray before unplugging them.

If you experience any issues while running the **PSBBN Launcher for Windows**, see **[troubleshooting](#problems-running-the-script)**.

## Main Menu
If this is your first time running the script, or if required dependencies are missing, the setup process will automatically run and install everything needed before the main menu is displayed.

From the main menu, you will have the following options:

1. [Install PSBBN and HOSDMenu](#install-psbbn-and-hosdmenu) (Official Sony Network Adapter required)  
Performs a fresh install of **PSBBN** and **[HOSDMenu](#hosdmenu)**

2. [Install HOSDMenu only](#install-hosdmenu-only) (3rd-party HDD adapters supported)  
Performs a fresh install **[HOSDMenu](#hosdmenu)**

3. [Update PS2 System Software](#update-ps2-system-software)  
Updates an existing install of **PSBBN** and **[HOSDMenu](#hosdmenu)** to the latest version

4. [Install Games and Apps](#game-and-app-installer)  
Installs PS1 and PS2 games, plus homebrew apps.

5. [Install Media](#media-installer)  
    1. [Install Music](#music-installer)
    2. [Install Movies](#movie-installer)
    3. [Install Photos](#photo-installer)
    4. [Set Media Location](#set-media-location)
    5. [Initialise Music Partition](#initialise-music-partition)

6. [Optional Extras](#optional-extras)  
    1. [Install PS2 Linux](#install-ps2-linux)
    2. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons) 
    3. [Change Language](#change-language)
    4. [Change Screen Settings](#change-screen-settings)
    5. [Clear Art & Icon Cache](#clear-art--icon-cache)

## Install PSBBN and HOSDMenu
Installs both **PSBBN** and [HOSDMenu](#hosdmenu). Requires an official Sony Network Adapter:
- Formats the drive for a clean installation
- Prompts you to select a language
- Downloads and installs the latest versions of the **PSBBN System Software** and **Language Pack** from [archive.org](https://archive.org/)
- When the language is set to Japanese, the [Online Channels](#internet-channel) are also downloaded and installed from [archive.org](https://archive.org/)
- Installs [OSDMenu MBR](#osdmenu-mbr) and [HOSDMenu](#hosdmenu)
- Creates partitions for [POPS](#popstarter-and-virtual-memory-cards) (to store PS1 games), [Music](#music-installer), and Contents (to store movies and photos), with user-defined sizes on the first 128 GB of the drive.
- Reserves space for 800 **Launcher partitions**, used to launch games and apps.
- Runs [APA-Jail](#apa-jail), creating an exFAT partition using all remaining disk space (up to 2 TB) for the storage of PS2 games and apps

## Install HOSDMenu only
Installs [HOSDMenu](#hosdmenu) without PSBBN. Compatible with 3rd party HDD adapters:
- Formats the drive for a clean installation
- Prompts you to select a language
- Installs [OSDMenu MBR](#osdmenu-mbr) and [HOSDMenu](#hosdmenu)
- Creates a partition for [POPS](#popstarter-and-virtual-memory-cards) (to store PS1 games) with a user-defined size up to 130 GB
- Reserves space for 800 **Launcher partitions**, used to launch games and apps
- Runs [APA-Jail](#apa-jail), creating an exFAT partition using all remaining disk space (up to 2 TB) for the storage of PS2 games and homebrew apps

## Update PS2 System Software
Selecting this option checks online for the latest versions of the **PSBBN System Software**, **Language Pack**, [Online Channels](#internet-channel), and [OSDMenu](#hosdmenu), then automatically installs any available updates. All your games, settings, and personal data remain intact.

## Game and App Installer
Fully automates the installation of PS1 and PS2 games, as well as homebrew apps:
- Auto-detects your PS2 drive
- Let you set a custom path to the `games` folder on your PC
- Gives you a choice of [Open PS2 Loader (OPL)](#open-ps2-loader-opl) or [Neutrino](#neutrino-and-nhddl) for the game launcher
- Installs any available updates for [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [Neutrino](#neutrino-and-nhddl), and [NHDDL](#neutrino-and-nhddl)
- Downloads and installs the [POPS](#popstarter-and-virtual-memory-cards) binaries and installs [POPStarter](#popstarter-and-virtual-memory-cards)
- Offers the option to apply a HDTV fix for PS1 games, useful for users with a TV that does not support 240p
- Offers the option to [synchronise](#synchronize-all-games-and-apps) the games and apps on your PC with your PS2's drive, or to [add additional](#add-additional-games-and-apps) games and apps
- Automatically converts PS2 games in `BIN/CUE` format to `ISO` when placed in the `CD` folder on your PC, and PS1 games in `BIN/CUE` format to `VCD` when placed in the `POPS` folder on your PC
- Creates [Virtual Memory Cards (VMCs)](#popstarter-and-virtual-memory-cards) for all PS1 games. Creates VMC Groups for games that can interact with each other's save data
- Creates all assets including meta-data, artwork and icons for all your games/apps:
  - Downloads artwork for the PSBBN [Game Collection](#game-collection) from the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) or IGN if not found in the database
  - Automatically contributes game artwork downloaded from IGN and reports missing artwork to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
  - Downloads cover art for PS2 games from the [OPL Manager art database](https://oplmanager.com/site/?backups) for display in [OPL](#open-ps2-loader-opl)/[NHDDL](#neutrino-and-nhddl)
  - Downloads icons for both games and [VMCs](#popstarter-and-virtual-memory-cards) for [HOSDMenu's](#hosdmenu) Browser 2.0 from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If icons are unavailable, but images for a game are available in the [OPL Manager Art Database](https://oplmanager.com/site/?backups), 3D icons will be automatically created.
  - Automatically contributes HDD-OSD icons and reports missing icons to the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Updates shortcuts for homebrew apps in the [PSBBN Navigator Menu](#game-collection) and in the [HOSDMenu's](#hosdmenu) **OSDSYS menu**
- Creates **launcher partitions**, making games and apps launchable from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#hosdmenu)

### Synchronize All Games and Apps
This option updates the contents of your PS2’s storage to match the `games` folder on your PC. Any new games or apps are copied over, and any that were removed from your PC are deleted from the console.

The script lets you set the location of the `games` folder on your PC. Simply place your files in the `games` folder: PS2 `ISO`, `ZSO` or `BIN/CUE` files go in the `CD` folder; `ISO` or `ZSO` files in the `DVD` folder; PS1 `VCD` or `BIN/CUE` files in the `POPS` folder; and `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder.

To add or delete games and apps, just modify the contents of the `games` folder on your PC, then select **Synchronize All Games and Apps**.

### Add Additional Games and Apps
Alternatively, you can add PS2 games directly to the exFAT filesystem of your PS2 drive by placing `ISO` or `ZSO` files in the `CD` or `DVD` folders, and `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder. PS1 `VCD` files can be placed in the `__.POPS` PFS filesystem.

Selecting **Add Additional Games and Apps** adds the new content to the **[PSBBN Game Collection](#game-collection)** and [HOSDMenu](#hosdmenu). Additionally, any new PS1 or PS2 games and apps found in the `games` folder on your PC will also be installed. As with syncing: PS2 `ISO`, `ZSO` or `BIN/CUE` files go in the `CD` folder; `ISO` or `ZSO` files in the `DVD` folder; PS1 `VCD` or `BIN/CUE` files in the `POPS` folder; and `ELF` or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder.

PS2 games and homebrew apps can be manually deleted from the exFAT filesystem on the PS2 drive, and PS1 games can be deleted from the `__.POPS` PFS filesystem. Selecting **Add Additional Games and Apps** will remove any deleted titles from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#hosdmenu).

## Media Installer
Select **Install Media** from the main menu and you will be presented with the following option:
1. [Install Music](#music-installer)
2. [Install Movies](#movie-installer)
3. [Install Photos](#photo-installer)
4. [Set Media Location](#set-media-location)
5. [Initialise Music Partition](#initialise-music-partition)

### Music Installer
Install music for playback on the [PSBBN Music Channel](#music-channel). To use the Music Installer, you must be running **PSBBN Definitive Project version 3.00 or later**. If you have previously upgraded from a lower version, you must [Initialise the Music Partition](#initialise-music-partition) first.

Supported formats are `.mp3`, `.m4a`, `.flac` and `.ogg`. Each file’s metadata must include the album title and track number. Place your music files in the default `music` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location), and place the files in the `music` subfolder.

### Movie Installer
Install videos for playback on the [PSBBN Movie Channel](#movie-channel). To use the Movie Installer, you must be running **PSBBN Definitive Project version 3.00 or later**. Your PC must also have an x86 processor.

The Movie Installer supports `MP4`, `M4V`, `MKV`, `VOB`, and other popular formats, as well as the PlayStation 2 video formats `pss` and `psm`. Shorter movies are encoded with a higher bitrate than longer movies. For best results, limit movie length to 2 hours and 15 minutes; longer movies may encode poorly or fail to convert.

Place your video files in the default `movie` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location), and place the files in the `movie` subfolder.

### Photo Installer
Install images for viewing on the [PSBBN Photo Channel](#photo-channel). To use the Photo Installer, you must be running **PSBBN Definitive Project version 3.00 or later**.

Supported formats including `JPG`, `PNG`, `TIF`, `GIF`, `BMP`, and more. Place your image files in the default `photo` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location), and place the files in the `photo` subfolder.

### Set Media Location
Set a custom location for your `media` folder. Music should be placed in a `music` subfolder, videos should be placed in a `movie` subfolder, and images should be placed in a `photo` subfolder.

### Initialise Music Partition
Erases all music data from **PSBBN** and resets the music database. Use this option if you have upgraded from a version of **PSBBN Definitive Project** lower than 3.00, in order to use the [Music Installer](#music-installer). You can also use this option if you experience problems with the [Music Channel](#music-channel).

## Optional Extras
Select **Optional Extras** from the main menu and you will be presented with the following option:
1. [Install PS2 Linux](#install-ps2-linux)
2. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons)
3. [Change Language](#change-language)
4. [Change Screen Settings](#change-screen-settings)
5. [Clear Art & Icon Cache](#clear-art--icon-cache)

### Install PS2 Linux
**NOTE: This feature is for PSBBN only.**  
PlayStation 2 Linux is an official kit from Sony that turned the PS2 into a Linux-based personal computer.  
The **Install PS2 Linux** option allows you to install or reinstall PS2 Linux. To install PS2 Linux, you must be running **PSBBN Definitive Project version 4.0.0 or later**.

To install PS2 Linux you need at least 3 GB of free space on your PS2 drive. During installation, you will be asked to set the size of your home directory (used for storing personal files and apps).

When reinstalling Linux:  
- If Linux came pre-installed with your version of the **PSBBN Definitive Project**, all PS2 Linux data will be erased, including your home directory.  
- If you installed or reinstalled Linux using this menu, only the system files will be reinstalled — your personal files in the home directory will not be affected.

**Notes:**  
- To launch PS2 Linux, power on your PS2 console, then hold the **○** button on the controller. PS2 Linux will then boot.  
- PS2 Linux requires a USB keyboard; a mouse is optional but recommended.  
- The `root` password is `password`. There is also a `ps2` user account with the password `password`.  
- To start a graphical interface, type `startx` at the command line.  
- Launching the **Dillo** web browser will open a mirror of the old official PS2 Linux website, where you can find a wide range of software to download and try.  

### Reassign Cross and Circle Buttons
This option lets you swap the functions of the **×** and **○** buttons on your controller. You can choose between the standard layout (**×** = enter, **○** = back) or the alternate layout (**○** = enter, **×** = back), depending on your preference.  

**NOTE: This feature applies to PSBBN only. It does not swap the button layout for the POPS in-game reset dialog when exiting a PS1 game, or HOSDMenu.**  

### Change Language
When **PSBBN** is installed, this option changes the system language of PSBBN. Select from English, German, Italian, Portuguese (Brazil), Spanish, French, and the original Japanese. More languages will be added with future updates. For Japanese users, it also downloads and installs the Japanese versions of the [Online Channels](#internet-channel).

For both **PSBBN** and [HOSDMenu](#hosdmenu) users, this option also updates the [POPS](#popstarter-and-virtual-memory-cards) IGR message and the language preference used by the [Game Installer](#game-and-app-installer).

After changing the language, it is recommended that you rerun the [Game Installer](#game-and-app-installer) and select *Add Additional Games and Apps* to update game titles to your selected language. For PSBBN users, this will also update the PlayStation game manuals.

### Change Screen Settings
**NOTE: This feature is for PSBBN only.**  
**PSBBN** normally locks the screen system settings to **4:3**. This option allows you to change the screen setting. You can choose between **4:3**, **Full**, and **16:9**.

This setting is used by some games and [HOSDMenu](#hosdmenu). It does not change the aspect ratio of PSBBN itself.

### Clear Art & Icon Cache
This option removes all game artwork and icons that are stored locally on your PC. When you next run the game installer, it will scan your game collection, then download and apply fresh copies of the required artwork and icons.  

You might want to clear the cache if games display incorrect or low-quality artwork, as updated artwork may now be available.

# Notes

## Game Collection
You can find the **Game Collection** in the **PSBBN Top Menu**.
- All your installed games and apps are displayed in a cover-flow style.
- Items are grouped into PS1 games, PS2 games, and homebrew apps.
- PS1 and PS2 games are sorted alphabetically and organized by game series, with games in a series ordered by release date.
- When the language is set to Japanese, Japanese-region game titles are displayed in their original Japanese and sorted in “gojūon” (五十音) order.
- Homebrew apps are sorted alphabetically, while [SAS apps](#save-application-system-sas) are further divided into sub-groups based on app type (system, game, emulator, etc.).  
- You can view a manual for PS1 games that lists supported hotkeys. To access the manual, press **△** on a highlighted PS1 game and select *Manual*.
- You can set shortcuts for up to four items by pressing **△** on a highlighted game and selecting *Add to Navigator Menu*. You can quickly access your shortcuts by pressing **SELECT**.

## Open PS2 Loader (OPL)
[Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) is a 100% open source game and application loader for the PS2. If you selected OPL as your game launcher, per-game settings assigned in OPL are reflected when launching games from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#hosdmenu).

If you have problems saving OPL settings, or if games do not appear in the games list, see [troubleshooting](#problems-launching-games).

## Neutrino and NHDDL
[Neutrino](https://github.com/rickgaiser/neutrino) is a lightweight device emulator for PS2. [NHDDL](https://github.com/pcm720/nhddl) is a frontend for Neutrino. If you selected Neutrino as your game launcher, per-game settings assigned in [NHDDL](https://github.com/pcm720/nhddl) are reflected when launching games from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#hosdmenu)  

**NOTE:** Neutrino does not support compressed `ZSO` files. If `ZSO` files are found in your `games` folder, or on the PS2 drive, they will be automatically decompressed to `ISO` files by the [Game Installer](#game-and-app-installer).

## Exiting Games
- To quit PS1 games, press `L1 + SELECT + START`
- If you are using [OPL](#open-ps2-loader-opl) as your game launcher, to quit PS2 games, press `L1 + L2 + R1 + R2 + SELECT + START` and to power off the console press `L1 + L2 + L3 + R1 + R2 + R3`
- Neutrino does not have an in-game reset function

## POPStarter and Virtual Memory Cards
**POPS** is an official Sony PS1 emulator for PS2, originally released exclusively in Japan as a way to distribute PS1 games over the internet to **PSBBN** users. **POPStarter** is a homebrew launcher for **POPS** that enables the emulator to play any PS1 game from the internal and external drives.

A **POPStarter Virtual Memory Card (VMC)** is created for every PS1 game played, and your progress is stored there. **VMCs** can be found on **PSBBN** in *Save Data Management* and in [Browser 2.0](#hosdmenu), under the `POPS` folder. A **VMC Group** is used for games that can interact with each other's save data. This allows, for example, licenses earned in Gran Turismo to be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis to comment on other Konami games you've played.

Hotkey button combinations are supported for disc swapping and various other options. Full details can be found in the **Manual** of each installed PS1 game. To access it, in **PSBBN** select a game in the **[Game Collection](#game-collection)**, press **△** then select **Manual**.

## Save Application System (SAS)
**Save Application System (SAS)** is a new standard for distributing homebrew applications for the PS2. All SAS-compliant apps are packaged in a `PSU` file and include icons and metadata, making it the recommended way to install homebrew on **PSBBN** and [HOSDMenu](#hosdmenu). You can download SAS compliant apps from the [PS2 Homebrew Store](https://ps2homebrewstore.com/).

## Game ID
**Game ID** for the **Retro GEM**, **MemCard Pro 2**, and **SD2PSX** is fully supported when launching PS1 games, PS2 games, and homebrew apps from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#hosdmenu), as well as physical PS1 and PS2 game discs.

The **Retro GEM** is a digital to digital HDMI output upgrade for multiple consoles. **Retro GEM Game ID** allows the auto-switching of display profiles on a per-game basis. You can find out more about the Retro GEM on the [Pixel FX website](https://www.pixelfx.co/hdmi-retro-gem).

**MemCard Pro 2** and **SD2PSX** allow save games to be stored on an SD card, supporting multiple **Virtual Memory Cards (VMCs)** and many other features. The **Game ID** identifies which game is running, allowing each game to be assigned its own **VMC**, and automatically switching to the correct card when the game is launched. You can find out more about the **MemCard Pro 2** on the [8BitMods website](https://8bitmods.com/accessories/memcard-pro/) and the **SD2PSX** on the [SD2PSX website](https://sd2psx.net/)

## Launching PS1 and PS2 Game Discs
When running PSBBN or [HOSDMenu](#hosdmenu), simply insert a game disc into the DVD drive. The game will boot and set the [Game ID](#game-id) on both the **Retro GEM** and **MemCard Pro/SD2PSX** accordingly.

For physical PlayStation (PS1) discs:
- Adjusts the PlayStation driver's video mode, if needed, to ensure imports play in the correct mode

For physical PlayStation 2 (PS2) discs:
- Applies automatic PS2 logo patching, allowing [MechaPwn](https://github.com/MechaResearch/MechaPwn) users to launch imports and master discs without skipping the PlayStation 2 logo or encountering a corrupted logo screen.

## Internet Channel
On the **Internet Channel**, you can access archives of various publishers’ online channels, just as they appeared in the early 2000s. The channels have been translated into English (work in progress). If you have a Japanese install of PSBBN, you will have access to the original Japanese versions. To view these online channels, your PlayStation 2 system must be connected to the internet.
- Explore the online channels of various game publishers, including Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, and Bandai.
- Download trailers for *Metal Gear Solid 3: Subsistence*, *Bomberman Online*, and more. Trailers can be downloaded from the **Konami Channel**, **BANDAI Entertainment World**, and the **HUDSON CHANNEL**. Downloaded trailers are saved to an album in the [Movie Channel](#movie-channel).
- Download artwork and screenshots from the **PlayStation® Now!** channel. Downloaded images are saved to an album in the [Photo Channel](#photo-channel).
- Play a number of classic games from the Hudson archive, including *Star Soldier*, *Milon’s Secret Castle*, and *Nuts & Milk*. Games can be played by selecting *PLAY GAMES* from the **HUDSON CHANNEL** main menu.

## Music Channel
The **Music Channel** allows you to play back music stored on your PS2's internal drive and create playlists. Music can be ripped directly on the PS2 from an audio CD, and installed using the [Music Installer](#music-installer).

It also supports exporting music to a NetMD-compatible MiniDisc recorder. However, MiniDisc support is broken in the current version of the PSBBN Definitive Project. If you want to try the MiniDisc functionality, you can use a [legacy version of the PSBBN Definitive English Patch](#legacy-versions-of-the-psbbn-definitive-english-patch).

## Movie Channel
The **Movie Channel** allows you to play back movies stored on your PS2's internal drive, organise your movies, and create playlists. Movies can be downloaded from several of the [Online Channels](#internet-channel), and installed using the [Movie Installer](#movie-installer).

## Photo Channel
The Photo Channel allows you to view photos stored on the PS2's internal drive or a FAT-formatted USB device (USB stick, digital camera, etc.). Photos can be imported from USB devices, and installed using the [Photo Installer](#photo-installer). You can create albums and playlists of your photos. You can also download game artwork and screenshots from the [Online Channels](#internet-channel).

## OSDMenu MBR
Written by [pcm720](https://github.com/pcm720). This program is executed on every system boot and when an application is launched from **PSBBN**. It is a homebrew replacement for Sony’s original MBR program. It is responsible for initializing the hardware, as well as launching applications and game discs.

**OSDMenu MBR** comes with many advantages over the original implementation including support for launching ELFs by holding a gamepad button at startup, automatic PS2 logo patching when [launching PS2 game discs](#launching-ps1-and-ps2-game-discs), adjusting video modes when [launching imported PS1 game discs](#launching-ps1-and-ps2-game-discs), [Visual Game ID](#game-id) for the Retro GEM, modifying system settings, and launching games via [OPL](#open-ps2-loader-opl), [NHDDL](#neutrino-and-nhddl), and [POPStarter](#popstarter-and-virtual-memory-cards).

The full readme can be found [here](https://github.com/pcm720/OSDMenu/blob/main/mbr/README.md).

## HOSDMenu
**HDD-OSD (Browser 2.0)** is an enhanced version of the PlayStation 2’s system menu (OSDSYS) that adds hard drive support, letting you manage software, save data, and launch games and apps directly from the HDD. **HOSDMenu**, written by [pcm720](https://github.com/pcm720), patches **HDD-OSD** and adds additional features, including:
- Support for larger drives — **HDD-OSD** was previously limited to 1 TB
- Launch homebrew apps directly from the **OSDSYS** menu
- Launch [SAS-compatible applications](#save-application-system-sas) from Memory Cards and from the internal drive in **Browser 2.0**
- Support for launching applications from MMCE, MX4SIO, UDPBD, iLink devices and APA- and exFAT-formatted HDDs
- [Launch PS1 and PS2 Game Discs](#launching-ps1-and-ps2-game-discs) with support for Game ID, MechaPwn, and built-in PS1VmodeNeg
- Integrated GSM for disc games and applications
- Support for 1080i and 480p
- And more — see the [GitHub repository](https://github.com/pcm720/OSDMenu) for full details

**HOSDMenu** is compatible with both the official Sony Network Adapter and 3rd-party HDD adapters. It can be installed alongside PSBBN or separately.

If installed alongside **PSBBN**, it can be launched from the [PSBBN Game Collection](#game-collection), via a [shortcut in the Navigator Menu](#game-collection), or by holding down the **×** while the console starts up. If only **HOSDMenu** was installed, it will autoboot.

Apps installed with the [Game Installer](#game-and-app-installer) will appear in the **OSDSYS menu**, allowing quick launching. Games will appear in the **Browser** represented by 3D icons modelled after the game case. [SAS compliant apps](#save-application-system-sas) downloaded from the [PS2 Homebrew Store](https://ps2homebrewstore.com/) will also appear in the **Browser** represented by unique icons. [POPStarter virtual memory cards](#popstarter-and-virtual-memory-cards) also get unique icons.

Game and VMC icons are downloaded from, and contributed to, the [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database).  

## OSDMenu Configurator
A PlayStation 2 GUI application for editing [OSDMenu-related](osdmenu-mbr) config files. The application can be launched from the [PSBBN Game Collection](#game-collection) or [HOSDMenu](#hosdmenu).

It allows you to modify boot options, such as assigning an app to a button for quick launch at startup, setting the display modes for [HOSDMenu](#hosdmenu), enabling or disabling the **OSDSYS** custom menu, and much more.

You can find full details on the [OSDMenu Configurator GitHub page](https://github.com/pcm720/OSDMenu-Configurator).

## wLaunchELF_ISR
A fork of [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) written by [Matías Israelson](https://github.com/israpps). The version included with this project offers improved stability and adds support for exFAT on external drives and MMCE (SD card browsing on **MemCard Pro 2/SD2PSX**). More details about this fork can be found [here](https://israpps.github.io/projects/wlaunchelf-isr).

## APA-Jail

![APA-Jail Type-A2](https://github.com/user-attachments/assets/8c83dab7-f49f-4a77-b641-9f63d92c85e7)

**PSBBN** was originally limited to just 128 GB of usable storage. **APA-Jail** allows for just over 2 TB.  
**APA-Jail**, created and developed by [Berion](https://www.psx-place.com/resources/authors/berion.1431/), enables the PS2's APA partitions to coexist with an exFAT partition. Up to 128 GB of the HDD/SSD is reserved for APA partitions, while the remaining space (up to 2 TB) is formatted as exFAT. This setup allows **PSBBN** and [HOSDMenu](#hosdmenu) to be installed on the APA partitions, while PS2 games and homebrew can be installed on the exFAT partition.

[OSDMenu MBR](#osdmenu-mbr) resides in the `__mbr` partition and launches apps, or directs [Open PS2 Loader](#open-ps2-loader-opl) or [NHDDL](#neutrino-and-nhddl) to launch specific PS2 games from the exFAT partition.

**Warning: Manually creating new APA partitions on your PS2 drive and exceeding the allocated space for APA will corrupt the drive.**

## Early (SCPH-10000–18000) and Slim (SCPH-700xx) Consoles
The **PSBBN Definitive Project** can be installed on PS2 Slim **SCPH-700xx** models with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod. Installing to a SD card is not supported, A SATA adapter must be used, such as the [iFlash-Sata v10](https://www.iflash.xyz/store/iflash-sata-v10/).

You must also download the [External HDD Drivers](https://israpps.github.io/FreeMcBoot-Installer/test/8_Downloads.html). Extract the files and place `hddload.irx`, `dev9.irx`, and `atad.irx` in the appropriate system folder for your region on an **official Sony PS2 Memory Card**:

| Region   | Folder Name   |
|----------|-------------- |
| Japanese | BIEXEC-SYSTEM |
| American | BAEXEC-SYSTEM |
| Asian 	 | BAEXEC-SYSTEM |
| European | BEEXEC-SYSTEM |
| Chinese  | BCEXEC-SYSTEM |

**SCPH-10000 to SCPH-18000** models with an official external HDD enclosure lack the ability to auto-boot without additional software. To launch PSBBN, it is recommend to use the **PlayStation 2 Basic Boot Loader (PS2BBL)**. [Install PS2BBL as a system update](https://israpps.github.io/PlayStation2-Basic-BootLoader/Downloads/) to your PS2 Memory Card. In the configuration file, set `LK_AUTO_E1` to `hdd0:/__system/p2lboot/osdboot.elf`.

# Troubleshooting

## Problems Running the Script
⚠️ **Known issue**: Installing on **Fedora** is currently problematic. It is recommended to use a Debian-based distribution or the [PSBBN Launcher for Windows](#installing-on-windows).

If you encounter problems running the **PSBBN Definitive Project** on your PC:
1. Make sure you are running the latest version of your operating system and that it is fully updated
2. Use a recommended OS. The **PSBBN Definitive Project** has been fully tested on:
- Linux Mint
- Raspberry Pi OS
- Windows 10 Home Edition
- Windows 11 Home Edition

If you are using the [PSBBN Launcher for Windows](#installing-on-windows) script and experience issues:
1. Open PowerShell as an administrator and run the following command:
```
wsl --unregister PSBBN
```
2. Download the latest version of the `PSBBN-Launcher-For-Windows.ps1` script [here](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1).
3. Make sure you have an active internet connection. If you are using a VPN, try disabling it
4. Run the `PSBBN-Launcher-For-Windows.ps1` script again

If you still encounter errors:
1. Connect the PS2 HDD or SSD directly to your PC using an internal SATA connection, or a USB port directly on the motherboard
2. Try installing to a different HDD or SSD, or try a different SATA to USB adapter

## Problems Launching PSBBN and HOSDMenu
When you connect the drive to your PS2 console and power it on, **PSBBN** or **[HOSDMenu](#hosdmenu)** should automatically launch.

If your console boots to the regular OSD or freezes, it means that your drive has not been recognised and you are experiencing a hardware issue. You should check the following:
1. If using **PSBBN**, make sure you are using an **official Sony Network Adapter**; 3rd-party adapters are not supported
2. Check that the connectors on the console and network/HDD adapter are clean and free of dust/debris
3. Ensure the network or HDD adapter and drive are securely connected to the console
4. If using a SATA mod, make sure it has been installed correctly
5. Try installing to a different HDD or SSD
6. Try using a different IDE converter or SATA mod
7. Try using a different official Sony Network Adapter or 3rd-party HDD adapter
8. Try a different PS2 console

## Problems Launching Games

If OPL freezes at startup, delete any existing OPL configuration files from your PS2 Memory Cards or connected USB devices.  
To display the games list in OPL, make sure a regular PS2 Memory Card is inserted into your console (if you are using either the MemCard Pro 2 or SD2PSX, remove it), launch OPL and adjust the following settings:
1. Settings > HDD (APA) Start Mode: Off
2. Settings > BDM Start Mode: Auto
3. Settings > BDM Devices > HDD (GPT/MBR): On
4. Settings > Save Changes

These settings will be saved to your PS2 Memory Card. You can keep this card in Slot 2 and use your MemCard Pro 2 or SD2PSX in Slot 1.

If games do not appear in the games list in [NHDDL](#neutrino-and-nhddl) or [OPL](#open-ps2-loader-opl) (after modifying the OPL settings as described above), or fail to launch from the [PSBBN Game Collection](#game-collection) and [HOSDMenu](#HOSDMenu), try the following:

1. If you have a [mod chip](#known-issues), disable it
2. Remove all PS2 Memory Cards from your console
3. Check that the connectors on the console and network/HDD adapter are clean and free of dust/debris
4. Ensure the network/HDD adapter and drive are securely connected to the console
5. If using a SATA mod, make sure it has been installed correctly
6. Re-run the [Game Installer](#game-and-app-installer) and select the alternative game launcher ([OPL](#open-ps2-loader-opl)/[Neutrino](#neutrino-and-nhddl))
7. Connect the PS2 HDD/SSD directly to your PC using an internal SATA connection or use a different USB adapter, then reinstall [PSBBN](#install-psbbn-and-hosdmenu) or [HOSDMenu](#install-hosdmenu-only)
8. Try using a different HDD/SSD and then reinstall [PSBBN](#install-psbbn-and-hosdmenu) or [HOSDMenu](#install-hosdmenu-only)
9. Try using a different IDE converter/SATA mod on your console
10. Try using a different official Sony Network Adapter or 3rd-party HDD adapter
11. Try a different PS2 console

# Known Issues
- Instances in feega where some Japanese text couldn't be translated due to it being hard-coded in an encrypted file. Atok software has not been translated.  
- MiniDisc support is broken as of patch version 2.10 and above. I hope to fix this in a future update  
- The default on-screen keyboard is set to Japanese. However, a US English on-screen keyboard has been added, though you’ll need to press the `SELECT` button multiple times to switch to it. There's a bug where spacebar doesn't work on the US English on-screen keyboard, but you can enter a space by pressing the **△** button on the controller instead.  
- The PS2 DVD Remote Control can behave erratically if no controller is plugged into Controller Port 1  
- Music installed with the Music Installer is only playable if written to the first 3 GB of the music partition. Music ripped from audio CDs in the [Music Channel](#music-channel) is unaffected and can use the full capacity of the partition.
- PSBBN only supports dates up to the end of 2030. When setting the time and date, the year must be set to 2030 or below.  
- PSBBN will freeze when launching games/apps if a mod chip is active. To use PSBBN, mod chips must be disabled.  
- PSBBN will freeze at the "PlayStation 2" logo when booting, if a 3rd party, unofficial HDD adapter is used. **An official Sony Network Adapter is required**.
- exFAT partition cannot exceed 2 TB. When using a drive larger, remaining space beyond that will be unusable.
- **wLaunchELF** and other native PS2 apps cannot create APA partitions on the PS2 drive. New partitions should only be created using the version of **PFS Shell** included with this project.
- APA partitions must not be created beyond the space allocated for APA during PSBBN/HOSDMenu installation. Doing so will overwrite data on the exFAT partition.
- OPL cannot read settings saved on the exFAT partition of the internal drive. Settings should be saved to a PS2 memory card. For details see the **[troubleshooting](#problems-launching-games)** section for details.

# Legacy versions of the PSBBN Definitive English Patch
<details>
<summary>Click to expand</summary>

**Patch Features**
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console as well as PS2 Slim SCPH-700xx models with an [IDE Resurrector](#early-scph-1000018000-and-slim-scph-700xx-consoles) or similar hardware mod, regardless of region
- DNAS authorization checks bypassed to enable access the online channels
- Online channels from Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI have been translated into English. Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard**
- Storage capacity limited to 130 GB
- Legacy versions of the **PSBBN Definitive Project** are **not** compatible with the [PSBBN installer](#install-psbbn-and-hosdmenu), [PS2 System Software Updater](#update-ps2-system-software), [Game Installer](#game-and-app-installer), [Media Installer](#media-installer), or [Extras](#optional-extras)

**Version History**  
v1.2 - 4th September 2024:
- Fixed a bug on the Photo Channel that could potentially prevent the Digital Camera feature from being launched.
- Fixed formatting issues with a number of error messages where text was too long to fit on the screen.
- Various small adjustments and corrections to the translation throughout.

v1.1.1 - 8th March 2024:  
- X11 has been set to run in English. The restore, move, resize, minimize, and close buttons now show in English while using the NetFront web browser. When saving files, time stamps now also display in English formatting.

v1.1 - 5th March 2024:
- The NetFront web browser is now in English. The browser can be accessed by going through the "Confirm/Change" network setting dialogs, then selecting "Change router settings".
- Atok user manual has been translated.
- Bug fixes:
- **General**: When a game disc was inserted while on the Top Menu, it would cause the console to freeze.  
- **Music Channel**: The number of times a track had been checked-out to a MiniDisc recorder was not displayed correctly.  
- A number of typos have been fixed.

v1.0 - 21st September 2023:
- Initial release.

**Installation Instructions**  
There are two ways to install this English patch:

1. **PS2 HDD RAW Image Install:** Use this method if you have access to a PC and a way to connect your PS2 HDD/SSD to your PC. This is the most straightforward option. All data on the HDD will be lost.

2. **Patch an existing PSBBN install:** Use this method if you already have an existing PSBBN install on your PlayStation 2 console. Also, follow these instructions to install future patch updates. No data will be lost.

**PS2 HDD RAW Image Install**  
What You Will Need:
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter). The drive must be 120 GB or larger
- A way to connect the PS2 HDD to a PC
- 120 GB of free space on your PC to extract the files
- Disk imaging software

Installation Procedure:  
1. Download [PSBBN_English_Patched_v1.x.x_Image.7z](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patched_v1.2_Image.7z) and uncompress it.
`PSBBN_English_Patched_v1.x.x_HDD_RAW.img` is a raw PS2 disk image of the Japanese PlayStation BB Navigator Version 0.32 with the PlayStation Broadband Navigator (PSBBN) Definitive English Patch pre-installed.
2. To write this image to your PS2 HDD, you need disk imaging software. For Windows, I recommend using HDD Raw Copy ver. 1.10 portable. You can download it [here](https://hddguru.com/software/HDD-Raw-Copy-Tool/).

**Patch an existing PSBBN install**  
What You Will Need:
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter)
- An existing install of PSBBN software 0.32 on your PS2 console
- A FreeMcBoot Memory Card
- A USB flash drive formatted as FAT32
- A USB keyboard

Installing the English Patch:  
1. Install the PSBBN software on your PS2 console if you haven't done so already. Either via a disk image or manually, see the section **Installing the Japanese PSBBN software** below for details on a manual install.
2. Download [PSBBN_English_Patch_Installer_v1.x.x.zip](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patch_Installer_v1.2.zip) and unzip it on your PC.
3. Copy the files `kloader3.0.elf`, `config.txt`, `xrvmlinux`, `xrinitfs_install.gz`, and `PSBBN_English.tar.gz` to the root of a FAT32 formatted USB flash drive.
4. Connect the USB flash drive and a USB keyboard to the USB ports on the front of your PS2 console.
5. Turn the PS2 console on with your FreeMcBoot Memory Card inserted and load wLaunchELF.
6. Load `kloader3.0.elf` from the USB flash drive.
7. Eventually, you will be presented with a login prompt:  
     Type `root` and press enter.  
     Type `install` and press enter.
8. When you see the text `INIT: no more processes left in this runlevel`, hold the standby button down until the console powers off.

Remove your FreeMcBoot Memory Card. Power the console on and enjoy PSBBN in full English!

**Installing the Japanese PSBBN software**  
There are a number of ways this can be achieved. On a Japanese PlayStation 2 console with an **official PSBBN installation disc**, or with **Sony Utility Discs Compilation 3**.

To install via **Sony Utility Discs Compilation 3** you will need a way to boot backup discs on your console, be that a mod chip or a swap disc. If you are lucky enough to have a **SCPH-500xx** series console you can use the **MechaPwn** softmod.

Installing with Sony Utility Discs Compilation 3  
Preparations:
1. Download the **Sony Utility Discs Compilation 3** ISO from the Internet Archive [here](https://archive.org/details/sony-utility-disc-compilation-v3).
2. **SCPH-500xx consoles only**: Patch the ISO with the [Master Disc Patcher](https://www.psx-place.com/threads/playstation-2-master-disc-patcher-for-mechapwn.36547/).
3. Burn this ISO to a writable DVD. I recommend using [ImgBurn](https://www.imgburn.com).
4. **SCPH-500xx consoles only**: MechaPwn your PS2 console with the latest release candidate, currently [MechaPwn 3.0 Release Candidate 4 (RC4)](https://github.com/MechaResearch/MechaPwn/releases/tag/3.00-rc4). It is important that you use a version of MechaPwn that does not change the **Model Name** of your console or it will break compatibility with the Kloader app, we use later in this guide. Currently the latest stable version is not compatible. More details about exactly what MechaPwn does and how to use it can be found [here](https://github.com/MechaResearch/MechaPwn).
5. Format the PS2 HDD. In wLaunchELF press the **○** button for **FileBrowser**, then select **MISC > HddManager**. Press `R1` to open the menu and select **Format**. When done, press **△** to exit.
6. Launch the **Sony Utility Discs Compilation 3** DVD on your console. **SCPH-500xx consoles only:** Insert your newly burnt **Sony Utility Discs Compilation 3** DVD into the DVD drive on your PS2 console. On the first screen of wLaunchELF, press the **○** button for **FileBrowser**, then select **MISC > PS2Disc**. The DVD will launch. On all other model consoles, launch the **Sony Utility Discs Compilation 3** DVD any way you can (e.g. Mod chip/Swap disc).
7. After the disc loads, select **HDD Utility Discs > PlayStation BB Navigator Version 0.32** from the menu to begin the installation.

Installation:  
There's an excellent guide [here](https://bungiefan.tripod.com/psbbninstall_01.html) that talks you through the Japanese install. Because we have already formatted the hard drive, during the install you will be presented with a [different screen](https://bungiefan.tripod.com/psbbninstall_02.html). It's important that you select the 3rd install option. This will install PSBBN without re-formatting the HDD. When the install is complete you will be instructed to remove the DVD, do so but also remove your FreeMcBoot Memory Card, before pressing the **○** button.

Network Settings:  
You will be asked to enter your network settings. Make sure your Ethernet cable is connected. Everything is still in Japanese, but it's relatively straightforward:
1. Press the **○** button on the first screen.
2. On the next screen, select the **bottom** option, "Do not use PPPoE" and press **○**.
3. On the next screen, select the **top** option, "Auto" for you IP address and press **○**.
4. On the next screen, select the **top** option, "Auto" for DNS settings and press **○**.
5. Press `right` on the d-pad to proceed to the next screen.
6. Select the **bottom** option, "Do not change router settings" and press **○**.
7. Finally, press **○** again to confirm your settings.

For your efforts you will be given a DNAS error. This is to be expected. We'll fix that next. Press **×** and feel free to explore your fresh install of the Japanese PSBBN.

Disable DNAS Authentication:  
1. Turn off the console and put your FreeMcBoot Memory Card back into a memory card slot.  
2. Turn the console on and load wLaunchELF.  
3. Go to **FileBrowser**. Navigate to `hdd0:/__contents/bn.conf/` and delete the file `default_isp.dat`. This will disable the DNAS checks.

**Please Note:** Before installing the English patch, you **must** power off your console to standby mode by holding the reset button. Failure to do so will cause issues with Kloader.

**Notes**  
\* Also compatible with the PS2 Slim SCPH-700xx models with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod. **PS2 HDD RAW Image Install** is not compatible with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000) that have an external HDD due to space limitations (unless the stock drive is replaced with a 120+ GB drive). When **patching an existing PSBBN install**, Kloader might have compatibility issues with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000).  
- Use OPL-Launcher to launch PS2 games from the Game Channel. More details can be found [here](https://github.com/ps2homebrew/OPL-Launcher).
- Lacks support for large HDDs, drives larger than 130 GB cannot be taken full advantage of. PSBBN can only see the first 130,999 MB of data on your HDD/SSD (as reported by wLaunchELF). If there is 131,000 MB or more on your HDD/SSD, PSBBN will fail to launch. Delete data so there is less than 131,000 MB used, and PSBBN will launch again. Be extra careful if you have installed via the **PS2 HDD RAW Image** on a drive larger than 120 GB, going over 130,999 MB will corrupt the drive.
- You may need to manually change the title of your "Favorite" folders if they were created before you **Patched an existing PSBBN install**.

</details>

# Credits
- PSBBN Definitive Project - Copyright © 2024-2026 by [CosmicScale](https://github.com/CosmicScale)
- `PSBBN-Definitive-Patch.sh`, `Setup.sh`, `PSBBN-Installer.sh`, `HOSDMenu-Installer.sh`, `Game-Installer.sh`, `Media-Installer.sh`, `music-installer.py`, `psmbuild.py`, `Extras.sh`, `art_downloader.py`, `list-builder.py`, `list-sorter.py`, `txt_to_icon_sys.py`, `ps2iconmaker.sh`, `AppDB.csv`, `TitlesDB_PS1.csv`, `TitlesDB_PS2.csv`, `vmc_groups.list` written by [CosmicScale](https://github.com/CosmicScale)
- `PSBBN-Launcher-For-Windows.ps1` written by Yornn
- `icon_sys_to_txt.py` written by [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- VMC and PSBBN 3D icons designed by Yornn
- PSBBN English translation by [CosmicScale](https://github.com/CosmicScale)
- PSBBN German translation by [Argo707](https://github.com/Argo707)
- PSBBN Italian translation by [plamadika](https://github.com/plamadika) & [lcipria](https://github.com/lcipria)
- Portuguese (Brazil) translation by [Emerson Teles (Emertels)](https://github.com/Emertels)
- Spanish translation by [Ignacio Trillo (Nacheras)](https://github.com/Nacheras) & [ViZoRRetrogames](https://github.com/ViZoRRetrogames)
- French translation by [Bistroww](https://github.com/Bistroww) & [iSlickick](https://github.com/iSlickick)
- Uses APA-Jail code from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) by [Berion](https://www.psx-place.com/members/berion.1431/)
- Contains code from [`list_builder.py`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/list_builder.py) from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma)
- Contains code from [`ps2iconmaker.sh`](https://github.com/CosmicScale/HDD-OSD-Icon-Database/issues/1#issuecomment-2852499188) by [Sakitoshi](https://github.com/Sakitoshi)
- Contains data from [`TitlesDB_PS1_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS1_English.txt) and [`TitlesDB_PS2_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS2_English.txt) from the [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) by [GDX-X](https://github.com/GDX-X)

**This software uses the following PS2 homebrew projects:**
- [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [OSDMenu](https://github.com/pcm720/OSDMenu) and [OSDMenu Configurator](https://github.com/pcm720/OSDMenu-Configurator) by [pcm720](https://github.com/pcm720)
- [APA Partition Header Checksumer](https://github.com/pink1stools/APA-Partition-Header-Checksumer/) by [Pink1](https://github.com/pink1stools) and [Berion](https://www.psx-place.com/members/berion.1431/). [Linux port](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) by [Bucanero](https://github.com/Bucanero)
- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/ext2) and [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) with 8MB APA partition and EXT2 modifications by [AKuHAK](https://github.com/AKuHAK)
- PFS Fuse from [PFS Shell](https://github.com/ps2homebrew/pfsshell) by [PS2 Homebrew Projects](https://github.com/ps2homebrew)
- PSU Extractor from [PSV Save Converter](https://github.com/bucanero/psv-save-converter) by [Bucanero](https://github.com/Bucanero)
- [ziso.py](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/pc/ziso.py) by Virtuous Flame
- cue2pops from [pops2cue](https://github.com/bucanero/pops2cue) by [Bucanero](https://github.com/Bucanero)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) from [PS2 Homebrew Projects](https://github.com/ps2homebrew) with BDM contributions from [KrahJohlito](https://github.com/KrahJohlito) and Auto Launch modifications by [CosmicScale](https://github.com/CosmicScale)
- [Neutrino](https://github.com/rickgaiser/neutrino) by [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) by [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/resources/popstarter.683/) by [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [wLaunchELF_ISR](https://israpps.github.io/projects/wlaunchelf-isr) by [Matías Israelson (israpps)](https://github.com/israpps)
- PS2 cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups)
- App icons from [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) and [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) courtesy of [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- Online channels hosted and translated into English by vitas155 at [psbbn.ru](https://psbbn.ru/), with the exception of the PlayStation Now! and Konami Channel, translated into English by [CosmicScale](https://github.com/CosmicScale)

**Third-Party Libraries & Binaries:**  
- `vmlinux` **BB Navigator kernel (Linux 2.4.17)** – Source code available [here](https://github.com/CosmicScale/PSBBN-Definitive-Patch-Kernel)
- **SQLite v2.8.17** from [sqlite.org](https://www.sqlite.org) 
- **mkfs.exfat (exfatprogs 1.2.2)** from [exfatprogs](https://github.com/exfatprogs/exfatprogs)
- `binmerge.py` from [binmerge](https://github.com/putnam/binmerge)

**All libraries and utilities are open-source and used in accordance with their respective licenses.**

**Thanks:**
- [Bucanero](https://github.com/Bucanero) for compiling the ARM64 binaries
- Everyone on the [SAS/UMCS Team](https://ps2homebrewstore.com/thanks/) for their ongoing work on the [PS2 Homebrew Store](https://ps2homebrewstore.com/)
- Special thanks to [pcm720](https://github.com/pcm720) for patching `osdboot.elf` to bypass the CRC security check

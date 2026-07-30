# PSBBN Definitive Project

| **English** | [Português (Brasil)](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README-PT-BR.md) |

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/blob/main/LICENSE)  
This is the Definitive Project for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console.

PSBBN is official Sony software for the PlayStation 2, released exclusively in Japan. Introduced in 2002 as a replacement for the PS2’s OSD, it required both a hard drive and a network adapter to function. It added many new features:
- Launching games from the hard drive
- Accessing online channels
- Downloading full games, demos, videos, and pictures
- Ripping audio CDs and transferring music to MiniDisc recorders in the Music Channel
- Watching videos in the Movie Channel
- Transferring photos from a digital camera and viewing them in the Photo Channel

The **PSBBN Definitive Project** (formerly the PSBBN Definitive English Patch) began in 2023 as an English-language patch for PSBBN, but steadily expanded well beyond its original scope. This project now aims to provide the ultimate setup for the PlayStation 2's internal drive.

You can find out more about the original PSBBN software on [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) and follow the development of this project on my [YouTube channel](https://www.youtube.com/@CosmicScaleFactor).

# Donations  
If you appreciate my work and want to support the ongoing development of the **PSBBN Definitive Project** and other PS2-related projects, [you can donate to my Ko-Fi](https://ko-fi.com/cosmicscale).

This project uses [webhook.site](https://webhook.site/) to automatically contribute and report missing artwork and icons to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) and [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). As the project has grow in popularity, we're exceeding the limit offered by a free account. A paid subscription costs $9/month or $90/year, donations also help fund this.

# Video demonstration of PSBBN

[![PSBBN in 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Features
There are two installation options:
- [PSBBN and HOSDMenu](#install-psbbn-and-hosdmenu) — requires an official Sony Network Adapter[*](#known-issues)
- [HOSDMenu only](#install-hosdmenu-only) — supports both official Sony Network Adapters and third-party HDD adapters

Both installation options offer:
- [Installers](#install-psbbn-and-hosdmenu) that make setup easy
- Support for larger drives with [APA-Jail](#apa-jail) — a hybrid partitioning scheme allows an exFAT filesystem and PlayStation File System (PFS) to coexist on the same drive
- exFAT filesystem used for storage and easy management of both games and homebrew apps
- PFS filesystem used for system software and legacy support
- [HOSDMenu](#hosdmenu) — a patched version of Sony's HDD-OSD software that offers many advantages over FreeHDBoot
- View, browse, and launch your games and apps directly from the [Browser](#hosdmenu), represented by [3D icons](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- [Game ID](#game-id) support for the **Pixel FX Retro GEM**, **MemCard Pro** and **SD2PSX** — works with installed games and apps, as well as physical game discs
- [MechaPwn](#launching-ps1-and-ps2-game-discs) support with automatic PS2 logo patching, allowing imports and backup discs to be launched. Also adjusts the PlayStation driver's video mode for imported PS1 game discs
- Includes the apps [wLaunchELF-R3Z](#wlaunchelf-r3z), [R3CONFIGURATOR](#r3configurator), and [POPSLoader](#popsloader), with a choice of [OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl) for your game launcher
- A [Game and App Installer](#install-games-and-apps) that fully automates the installation of PS1 and PS2 games as well as homebrew apps:
  - Creates assets and downloads artwork and icons for all your games and apps
  - Offers an option to create [Virtual Memory Cards](#virtual-memory-cards) (VMCs) for PS2 games, with support for [VMC Groups](#virtual-memory-cards) for both PS1 and PS2 games
  - Sets up multi-disc PS1 games to enable disc swapping
  - Automatically installs [HugoPocked POPStarter fixes](#popstarter)
  - Converts `.bin`/`.cue` files to `.VCD` (PS1), or `.ISO` (PS2)
  - Configures OPL compatibility settings for games
  - Adds installed apps to [HOSDMenu's](#hosdmenu) system menu

**Exclusive to PSBBN installs:**
- **PSBBN Definitive Patch** — an enhanced version of Sony's [PSBBN](#psbbn) software that offers [many advantages](#psbbn) over the stock version
- View, browse, and launch your games and apps directly from the [Game Collection](#game-collection) with a cover-flow-style interface
- [Music Channel](#music-channel) for music playback and CD ripping. Use the [Music Installer](#install-music) to install music files from your PC (`.mp3`, `.m4a`, `.flac`, `.ogg`)
- [Movie Channel](#movie-channel) for video playback. Download videos from the [online channels](#internet-channel), or use the [Movie Installer](#install-movies) to install video files from your PC (`.mp4,` `.m4v`, `.mkv`, `.vob`, `.pss`, `.psm` and other popular formats)
- [Photo Channel](#photo-channel) for viewing image. Import images from USB drives or digital cameras, or install them from your PC using the [Photo Installer](#install-photos) (`.jpg`, `.png`, `.tif`, `.gif`, `.bmp`, and other common formats)
- [Internet Channel](#internet-channel) offering access to mirrors of the original online game channels from various publishers, allowing you to download game trailers and screenshots, and play classic retro games
- [Optional extras](#optional-extras) such as installing [PS2 Linux](#install-ps2-linux)

# Changelog

**July 29, 2026 - Game Selector v2, OSDMenu 1.3.0 and more!**
<p></p>

**[Game Selector:](#game-selector)**
- Manage all your games and applications with [Game Selector](#game-selector) v2.
- Select which titles appear in the [Game Collection](#game-collection) and [Browser](#hosdmenu).
- Customise the order in which categories appear, such as PS2 Games, PS1 Games, Launchers, and Applications, giving you full control over how your library is organised.

**OSDMenu:**
- [OSDMenu MBR](#osdmenu-mbr) and [HOSDMenu](#hosdmenu) updated to [v1.3.0](#https://github.com/pcm720/OSDMenu/releases/tag/v1.3.0).
- Reduced [PSBBN](#psbbn) boot time.
- Added support for additional [gamepad launch keys](#boot-options). All keys are now supported except `L3` and `R3`.
- [R3CONFIGURATOR](#r3configurator) updated to [v1.3.0](https://github.com/saildot4k/R3CONFIGURATOR/releases/tag/v1.3.0).

**Other Changes:**
- [POPSLoader](#popsloader) updated to latest rolling release
- Easier [ATA BDM Assault Driver Installation](#installing-ata-bdm-assault) with [POPSLoader](#popsloader)
- [wLaunchELF_R3Z](#wlaunchelf-r3z) updated to [v4.75](#https://github.com/saildot4k/wLaunchELF_R3Z/releases/tag/v4.75)
- Language setting for [wLaunchELF_R3Z](#wlaunchelf-r3z) and [POPSLoader](#popsloader) are now automatically set.
- [Button configuration](#reassign-cross-and-circle-buttons) setting for [wLaunchELF_R3Z](#wlaunchelf-r3z) is now automatically set.
- Added a Brazilian Portuguese translation of the [PSBBN Definitive Project README](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README-PT-BR.md).
- Various bug fixes and code clean-up.

**July 02, 2026 - Enhanced Localization, Game Selector, PS1 on exFAT, POPSLoader, wLaunchELF-R3Z, and R3CONFIGURATOR**
<p></p>

[![Enhanced Localization, Game Selector, PS1 on exFAT, POPSLoader & more!](https://github.com/user-attachments/assets/c1828dbf-e1ba-4c67-8ae0-ccff79f4a524)](https://youtu.be/Bqf8XCfa0QM)  

**New Features:**
- A changelog is now displayed before the [Main Menu](#main-menu) whenever a new update is released.
- The **PSBBN Definitive Project** scripts have been fully localised into English, Japanese, French, Spanish, German, Italian, and Brazilian Portuguese. Your operating system's language is detected automatically, and the project runs in that language, defaulting to English if it is not available. **Windows** users will need to update to the latest version of the **[PSBBN Launcher for Windows](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)** for this feature to work.
- The [Game Installer](#install-games-and-apps) now features a [Game Selector](#game-selector), allowing you to select which games to display in the [Game Collection](#game-collection) and [Browser](#hosdmenu). If you have a large collection, limiting the number of displayed games can improve your browsing experience.
- PS1 games are now installed to the exFAT partition alongside your PS2 games and apps, removing the space limitations caused by APA. Previously installed games will remain on the `POPS` partition and will still be playable. To play PS1 games from the exFAT partition, you **MUST** install the [ATA BDM Assault drivers](#installing-ata-bdm-assault) on a PS2 Memory Card.
- PS1 games stored on an [SMB network share](#launching-ps1-games-from-smb) can now be launched from the [Game Collection](#game-collection) and [Browser](#hosdmenu). Place a renamed `POPSTARTER.ELF` with the `SB.` prefix in the `POPS` folder, then run the [Game Installer](#install-games-and-apps).
- The [POPSLoader](#popsloader) application has been added. This allows you to easily browse and load PS1 games. [POPSLoader](#popsloader) can be launched from the [Game Collection](#game-collection) or Navigator Menu, the [HOSDMenu](#hosdmenu) Browser or system menu, and by holding [△](#boot-options) at boot.
- [POPSLoader](#popsloader) integration has been added to the [Game Installer](#install-games-and-apps), game artwork is automatically downloaded for all your PS1 games.
- **wLaunchELF-ISR** has been replaced with [wLaunchELF-R3Z](#wlaunchelf-r3z), adding support for managing files on the internal drive's exFAT partition. It can now be launched at boot by holding the [START](#boot-options) button.
- **OSDMenu Configurator** has been replaced with [R3CONFIGURATOR](#r3configurator), adding multilingual support.

**Enhancements:**
- [PSBBN and HOSDMenu installer](#install-psbbn-and-hosdmenu), and [HOSDMenu only installer](#install-hosdmenu-only):
  - No longer creates a `POPS` partition, allowing for larger Music and Contents partitions or a larger exFAT partition.
  - Language selection has been removed. It now automatically installs in the same language as your operating system, defaulting to English if that language is unavailable.
- [HOSDMenu only installer](#install-hosdmenu-only):
  - Allows you to reserve space for future APA partitions. Up to 50% of the drive’s capacity (maximum 2 TB) can be reserved.
- [Game Installer](#install-games-and-apps):
  - Language and button configuration is now automatically set in [OPL](#open-ps2-loader-opl) and [R3CONFIGURATOR](#r3configurator) to match the install settings.
  - PS2 games are now displayed first in the [Game Collection](#game-collection) and [Browser](#hosdmenu), followed by PS1 games and homebrew apps.
  - The [Game Installer](#install-games-and-apps) output has been streamlined and now includes progress bars.
  - You now have the option to disable [PS2 VMCs](#virtual-memory-cards) if they were previously enabled.
  - Available space is now displayed in MB, GB, or TB depending on size.
  - OPL artwork is now saved directly to the PS2 drive.
  - Instructions have been added for **Linux** users on where to put supported files, mirroring the [PSBBN Launcher for Windows](#installing-on-windows).
- All log files are now truncated when they exceed 4 MB.
- The current **PSBBN Definitive Project** commit number is logged in the log files.
- A link to the [troubleshooting guide](#troubleshooting) has been added to all error messages.
- Updated, restructured and improved readme.

**Bug Fixes:**
- The script is prevented from running in non-interactive mode.
- [OPL](#open-ps2-loader-opl) has been updated to v1.2.0-Beta-2245-3e3f34e, fixing a configuration read issue on startup that some users were experiencing.
- The [Music Installer](#install-music) now supports international character handling.
- The [Game Installer](#install-games-and-apps) now skips over hidden files, preventing them from being installed.
- Duplicate `.ZSO` files are prevented from decompressing when `.ZSO` files are present and [NHDDL](#nhddl) is selected as the game launcher.
- Displays a warning if a `.bin` file is missing when converting to `.iso`. Skips converting `.VCD` if `.bin` file is missing
- Improved checks for the successful creation of the game lists.
- Correctly handle duplicate game IDs even when files are in different folders.
- Fixed incorrect truncation of Japanese game titles in the [Browser](#hosdmenu).
- The mounting of `__linux.9` is now skipped for non-Japanese installs, allowing the support of smaller drives.

<details>
<summary><b>April 16, 2026 - Improved PS1 Compatibility, PS2 VMCs, OPL Update & More!</summary></b> 
<p></p>

[![Improved PS1 Compatibility, PS2 VMCs, OPL Update & More!](https://github.com/user-attachments/assets/1dc75789-bbd4-45df-9615-7e9bd8bd3ac5)](https://youtu.be/oRm3QIwdf1o)  

- **[OPL](#open-ps2-loader-opl)** updated to **v1.2.0 Beta-2241-39afed2** - fixes configuration read issues on the internal drive’s exFAT partition
- **[NHDDL](#nhddl)** updated to **[v1.2.2](https://github.com/pcm720/nhddl/releases/tag/v1.2.2)** 
- **[Neutrino](#nhddl)** updated to **[v1.8.0](https://github.com/rickgaiser/neutrino/releases/tag/v1.8.0)** - reduces game launch time by around 4 seconds
- **[OSDMenu](#osdmenu-mbr)** updated to **v1.2.1** - fixes issues with launch arguments when starting ELFs via gamepad button at startup

**[Game Installer](#install-games-and-apps):**
- Assigns chosen game launcher ([OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl)) to the □ button, allowing it to be quickly launched at startup 
- Creates an **[OPL](#open-ps2-loader-opl)** configuration file on your drive. BDM HDD, Apps, and artwork are now automatically enabled
- Games in the `ZSO` format now have "Compatibility Mode 1" automatically enabled in their per-game **[OPL](#open-ps2-loader-opl)** configurations
- Multiple games that share the same Title ID can now be installed, allowing the installation of a variety of mods
- PS1 games now feature a new PSN-style border in the PSBBN **[Game Collection](#game-collection)**, making it easier to distinguish between PS1 and PS2 games
- Automatic installation of **[HugoPocked POPStarter fixes](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)**, improving compatibility with over 100 PS1 games

**Bug Fixes:**
- **OSDMenu Configurator** now has the correct artwork in the Apps tab in **[OPL](#open-ps2-loader-opl)**
- Fixed `.vcd` to `.VCD` renaming on case-insensitive filesystems
- Deletes existing `neutrino` folder before updating to prevent conflicts
- Ensures OSDMenu config files ends with a new line before appending content

**README**:
- New section [Boot Options](#boot-options)
- Added table for [POPStarter hotkeys](#popstarter)
- Added Debian to the list of [recommended operating systems](#installing-on-linux)
- Added new features to [Install Games and Apps](#install-games-and-apps) section
- Changed references from Neutrino to [NHDDL](#nhddl), reflecting how games now launch
- General improvements

**March 27, 2026 - Virtual Memory Cards (VMCs) for PS2 games**
- The **[Game Installer](#game-and-app-installer)** now offers the option to enable **[VMCs](#virtual-memory-cards)** for PS2 games. No additional setup is necessary
- This feature is compatible with both **[OPL](#open-ps2-loader-opl)** and **[NHDDL](#nhddl)**
- Supports **[VMC Groups](#virtual-memory-cards)**

**March 26, 2026 - 4.2.0 Update: New Online Channels plus French Localisation**
- PSBBN system software updated to patch 4.2.0
- The Game Channel has been renamed to the **[Internet Channel](#internet-channel)**, reflecting its online focus
- New online channels added: BANDAI CHANNEL, So-Net, and BIGLOBE
- Download new game trailer in higher quality, with thumbnails
- French language support is now available for PSBBN
</details>

<details>
<summary><b>March 05, 2026 - Movie and Photo Installers, OSDMenu Configurator and more!</summary></b> 
<p></p>

[![Movie and Photo Installers, OSDMenu Configurator and more!](https://github.com/user-attachments/assets/f0fae1ee-bf04-4aea-88a6-89e030926282)](https://youtu.be/_jKzzsClgOY)

**More Languages:**
- In addition to English, Japanese, and German, PSBBN is now available in Italian, Brazilian Portuguese, and Spanish

**[Update PS2 System Software:](#update-ps2-system-software)**
- Replaces **Update PSBBN Software**. This new option updates both the **[PSBBN](#psbbn)** and **[OSDMenu](#hosdmenu)** System Software
- The **PSBBN Definitive Project** **[Main Menu](#main-menu)** now shows a notification when **PS2 system software updates** are available

**[Install Movies:](#install-movies)**
- The **[Install Movies](#install-movies)** option has been added to the **[Install Media Menu](#install-media)**
- You can now place a variety of video formats, including `MP4`, `M4V`, `MKV`, `VOB`, and more, in the `movie` folder
- Selecting **[Install Movies](#install-movies)** will convert the video files to the `PSM` format supported by **[PSBBN](#psbbn)**
- Videos will then be playable in the **[PSBBN Movie Channel](#movie-channel)**

**[Install Photos:](#install-photos)**
- The **[Install Photos](#install-photos)** option has been added to the **[Install Media Menu](#install-media)**
- You can now place a variety of image formats, including `JPG`, `PNG`, `TIF`, `GIF`, `BMP`, and more, in the `photo` folder
- Selecting **[Install Photos](#install-photos)** will convert the image files to `PNG` and resized them if necessary
- Images will then be viewable in the **[PSBBN Photo Channel](#photo-channel)**

**[OSDMenu 1.2.0:](#osdmenu-mbr)**
- Both **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)** have been updated to version 1.2.0. The changelog can be found **[here](https://github.com/pcm720/OSDMenu/releases)**
- The **OSDMenu Configurator** app has been added. This allows you to customise your PS2 console by modifying the settings for both **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)**
- The **OSDMenu Configurator** will be installed the next time you select **[Install Games and Apps](#install-games-and-apps)** from the **PSBBN Definitive Project [Main Menu](#main-menu)**. It can be launched from the **[Game Collection](#game-collection)**, or **[HOSDMenu](#hosdmenu)**

**[HOSDMenu-only installs:](#install-hosdmenu-only)**
- Increased maximum **[POPS](#popstarter)** partition size to 130 GB.
- Added language selection. The selected language is used by the game installer for game titles and the **[POPS IGR message](#exiting-games)**
- **[HOSDMenu-only](#hosdmenu)** users can now change the language of their install in the **[Optional Extras Menu](#optional-extras)**

**[Change Screen Settings:](#change-screen-settings)**
- Previously locked on **[PSBBN](#psbbn)**, you can now change your system’s screen settings in the **[Optional Extras Menu](#optional-extras)** to 4:3, Full, or 16:9
- **Note:** This setting is used by some games and **[HOSDMenu](#hosdmenu)**. It does not change the aspect ratio of **[PSBBN](#psbbn)** itself

**[Clear Art & Icon Cache:](#clear-art--icon-cache)**
- In the **[Optional Extras Menu](#optional-extras)**, you now have the option to clears all previously downloaded artwork and icons that are stored locally on your PC
- You may want to clear the cache if games display incorrect or low-quality artwork, as updated artwork may now be available
- Running the **[Game Installer](#install-games-and-apps)** will then download the latest artwork and icons

**[PSBBN Launcher for Windows:](#installing-on-windows)**
- Added support for installing games from a network drive
- Added a prompt that displays supported files for the **[Movie Installer](#install-movies)** and **[Photo Installer](#install-photos)**
- Corrected minimum drive capacity warning message
- Bug fixes

**Bug Fixes and Improvements:**
- Enabled PS2 logo when launching physical PS2 game discs for fresh installs. Users upgrading can turn this option on using the **OSDMenu Configurator**. **[MechaPwn](https://github.com/MechaResearch/MechaPwn)** users can now launch imports and master discs without skipping the PlayStation 2 logo or encountering a corrupted logo screen
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
</details>

<details>
<summary><b>January 08, 2026 - PSBBN Definitive Project: New Name and Multilingual Support</b></summary>
<p></p>

[![PSBBN Definitive Project: New Name and Multilingual Support](https://github.com/user-attachments/assets/32bb93f2-c009-4b82-ba62-67933ff30e83)](https://www.youtube.com/watch?v=dvCt_ExHwro)

The PSBBN Definitive English Patch started life in 2023 as an English language patch for PSBBN, this work has steadily expanded well beyond its original scope. Going forward, it will now collectively be called the **PSBBN Definitive Project**.

PSBBN is now available in English, German, Italian, and the original Japanese, with a French translation coming soon. You will be given a choice of languages when installing PSBBN. The language can also be changed later in the **[Extras Menu](#optional-extras)**.

When the language is set to Japanese, titles of Japanese-region games are displayed in Japanese and sorted in “gojūon” (五十音) order in both the **[Game Collection](#game-collection)** and the **[HOSDMenu Browser](#hosdmenu)**. In addition, the original Japanese online channels are also accessible from the **[Internet Channel](#internet-channel)**.

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

**[Game Installer:](#install-games-and-apps)**
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
- **[NHDDL](#nhddl)** updated to version 1.2.1
</details>

<details>
<summary><b>November 14, 2025 - PSBBN Definitive Patch v4.0 - OSDMenu, third-party HDD adapters and more!</b></summary>
<p></p>

[![PSBBN Definitive Patch v4.0 - OSDMenu, third-party HDD adapters and more!](https://github.com/user-attachments/assets/1a3f2d69-6bec-4fe4-aa27-c367f5d98f98)](https://www.youtube.com/watch?v=fT368C90Trc)

**[NEW! OSDMenu MBR:](#osdmenu-mbr)**  
Replaced Sony’s original MBR application with **[OSDMenu MBR](#osdmenu-mbr)**, a homebrew alternative that:
- Handles launching games and apps directly instead of relying on **BBN Launcher (BBNL)**
- Improves boot speed
- Games now launch up to 6 seconds faster
- Eliminates the need for the **PlayStation 2 Basic Boot Loader (PS2BBL)** — **[OSDMenu MBR](#osdmenu-mbr)** natively supports launching ELFs by holding a gamepad button at startup, drastically reducing boot times compared to **PS2BBL**
- PS2 Linux is now booted directly by holding ○ at power-on instead of interrupting **[PSBBN](#psbbn)** startup
- Removed the **"Launch Disc"** app — simply insert a game disc to play, with support for **[Game ID, MechaPwn and built-in PS1VmodeNeg!](#launching-ps1-and-ps2-game-discs)**
- Improves **[Retro GEM Game ID](#game-id)** handling — **[PSBBN](#psbbn)** and **[HOSDMenu](#hosdmenu)** now both set a **Game ID** on boot, removing the need for the **Retro GEM Game ID Resetter**
- When using a **MemCard Pro 2 or SD2PSX**, unnecessary **VMCs** are no longer generated when launching PS1 games with **[POPStarter](#popstarter)** or other homebrew apps

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
- The PSBBN Installer now installs **[HOSDMenu](#hosdmenu)** alongside **[PSBBN](#psbbn)**
- Shows latest release notes when installing and updating
- Supports smaller drives — minimum capacity reduced from 200 GB to 32 GB
- Increased max APA partition size to 112 GB
- After partitioning, any unallocated space is now assigned to the **[OPL](#open-ps2-loader-opl)** partition
- Advises users to check [archive.org](https://archive.org/) or use a VPN if downloads fail

**[NEW! Install HOSDMenu only:](#install-hosdmenu-only)**
- Adds an option to install **[HOSDMenu](#hosdmenu)** only (for users with third-party HDD adapters)
- Create a custom-size **[POPS](#popstarter)** partition (up to 118 GB), automatically assigning remaining space to the **[OPL](#open-ps2-loader-opl)** partition (up to 2 TB)

**[Game Installer:](#install-games-and-apps)**
- **[Game Installer](#install-games-and-apps)** now requires **PSBBN Definitive Project v4.0.0** and above or **[HOSDMenu-only](#install-hosdmenu-only)**
- Adds support for **[HOSDMenu](#hosdmenu)**-only setups
- Updates **[OSDMenu MBR](#osdmenu-mbr)** and **[HOSDMenu](#hosdmenu)** if newer versions are available
- Updates the **Navigator Menu** with shortcuts to your selected game launcher (**[OPL](#open-ps2-loader-opl)** or **[NHDDL](#nhddl)**), **[HOSDMenu](#hosdmenu)** and **[wLaunchELF_ISR](#wlaunchelf_isr)**
- Updates the **[HOSDMenu](#hosdmenu)** config to display installed homebrew apps in the **OSDSYS menu**
- Automatically converts PS1 `BIN/CUE` files to `VCD` and PS2 `BIN/CUE` file to `ISO`
- PS1 games are now copied and synced through `PFS FUSE` using `rsync`, with visible progress during transfer
- Copies only valid game and homebrew files when syncing or adding games and apps — `rsync` now ignores Windows `:Zone.Identifier` metadata files that could cause sync failures
- Automatically capitalizes lowercase `.VCD` extensions to ensure compatibility with **[POPStarter](#popstarter)**
- Relocated `OPNPS2LD.ELF` and `nhddl.elf` to `__system/launcher` and `POPSTARTER.ELF` to `__common/POPS` from exFAT

**`list-builder.py`:**
- Now scans the PFS `__.POPS` partition for `VCD` files instead of local `POPS` folder

**`art_downloader.py`:**
- Converted `art_downloader` from JavaScript to Python, removing dependencies on Node.js, npm, Puppeteer, and Chromium

**[Install Music:](#install-music)**
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

**[NHDDL:](#nhddl)**
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

**[NEW! Music Installer:](#install-music)**
- Install music for playback on the **[PSBBN Music Channel](#music-channel)**. Supported formats: `.mp3`, `.m4a`, `.flac`, and `.ogg`

**[NEW! PSBBN Installer:](#install-psbbn-and-hosdmenu)**
- **[PSBBN](#psbbn)** has fully transitioned from ReiserFS (an old, no-longer-supported filesystem) to ext2, allowing direct access to all BBN partitions
- The new PSBBN Installer works with a tar archive instead of a disk image, reducing download size and drastically improving install time
- When installing, you can set a custom size for the `contents` partition used for movies and photos (previously limited to 5 GB)
- Increased maximum size of the Music, Contents, and POPS partitions — now up to 111 GB

**[NEW! PSBBN Updater:](#update-ps2-system-software)**
- Allows updating to the latest version of the Definitive Project directly from the menu. No USB thumb drive or USB keyboard required!

**[Game Installer:](#install-games-and-apps)**
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
- The × and ○ buttons have been swapped: × is now Enter, and ○ is now Back.
- Added support for the PlayStation 2 DVD remote control. The `PLAY`, `PAUSE`, `STOP`, `PREV`, `NEXT`, `SCAN`, and `DISPLAY` buttons can now be used during music and movie playback in the [Music](#music-channel) and [Movie](#movie-channel) channels. The `ENTER` button can also be used when navigating menus.
- The **PlayStation BB Guide** has been updated to reflect the button swap and the relocation of the [Game Collection](#game-collection). A new section has been added covering the Online Channels. Numerous improvements to the English translation.
- Improves the update process. A USB drive and keyboard will not be required for future updates.

**`02-PSBBN-Installer.sh`:**
- You can now set a custom size for the [POPS](#popstarter) partition. Previously, it filled all remaining space after creating the music partition.

**`03-Game-Installer.sh`, `ps2iconmaker.sh` & `txt_to_icon_sys.py`:**

- Multi-disc PS1 games now support disc swapping without additional setup. A `DISCS.TXT` file is created for every multi-disc game. Multi-disc games also now share a [POPStarter Virtual Memory Card (VMC)](#virtual-memory-cards)
- [POPStarter VMC Groups](#virtual-memory-cards) for PS1 games: games that can interact with each other's save data now share a single VMC. For example, licenses earned in Gran Turismo can be transferred to Gran Turismo 2, and Metal Gear Solid’s Psycho Mantis can comment on other Konami games you've played.
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
  - [POPS](#popstarter) partition can now range between 1 GB and 104 GB  
  - Space reserved for 800 **BBNL partitions**  
- Removed [POPS](#popstarter) installer (now handled by the Game Installer script)  
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
- Improved update process for [POPStarter](#popstarter), [OPL](#open-ps2-loader-opl), [NHDDL, and Neutrino](#nhddl)
- Game Installer now installs [POPS](#popstarter) binaries if missing  
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
  - Dropped PFS support in favour of loading [OPL](#open-ps2-loader-opl), [POPStarter](#popstarter), [Neutrino](#nhddl), and configuration files from the exFAT partition to speed up initialization.
  - Moved **BBNL** to the APA header to further improve loading times.
  - Removed dependency on renamed [POPStarter](#popstarter) `ELF` files to launch PS1 VCDs; [POPStarter](#popstarter) is now launched directly with a boot argument.
  - [NHDDL](https://github.com/pcm720/nhddl) now launches in ATA mode, improving startup time and avoiding potential error messages.
- Updated [Neutrino](#nhddl) to version 1.6.1
- Updated [NHDDL](#nhddl) to version MMCE + HDL Beta 4.17
- Added cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups). Artwork for PS2 games is now displayed in OPL/NHDDL
- Added homebrew support to the `03-Game-Installer.sh` script. `ELF` files placed in the local `games/APPS` folder on your PC will be installed and appear in the [Game Collection](#game-collection) in PSBBN and the Apps tab in OPL
- Apps now support [Game ID](#game-id) for both the Pixel FX Retro GEM and MemCard Pro/SD2PSX

</details>

<details>
<summary><b>Feb 19, 2025 - BBN Launcher, Neutrino & NHDDL</b></summary>
<p></p>

[![BBN Launcher, Neutrino & NHDDL](https://github.com/user-attachments/assets/8007d102-3019-4037-8c52-24d1454777da)](https://www.youtube.com/watch?v=0vpSiAa6ITc)

- [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) has been replaced by **BBN Launcher (BBNL)**
- Added [Neutrino](#nhddl) support. You can now choose between [Open PS2 Loader](#open-ps2-loader-opl) and [Neutrino](#nhddl) as your game launcher
- When using Neutrino as your game launcher, [NHDDL](#nhddl) can be used to make per-game settings

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
  - Installs PSBBN, [POPS binaries and POPStarter](#popstarter)
  - Partition the first 128 GB of the drive as APA:
    - Create up to 700 OPL launcher partitions
    - Custom size music partition from 10 GB to max 97 GB
    - Remaining space allocated to [POPS](#popstarter) partition for PS1 games
  - Creates an exFAT partition with drive space beyond the first 128 GB for storage of PS2 games
- Introducing the [Game Installer script](#install-games-and-apps):
  - Fully automates the installation of PS1 and PS2 games
  - Creates all assets and meta-data
  - Downloads game artwork from IGN

</details>  

# Installation Guide
The **PSBBN Definitive Project** has been fully localised into English, Japanese, French, Spanish, German, Italian, and Brazilian Portuguese. Your operating system's language is detected automatically, and the project runs in that language, defaulting to English if it is not available.

## Requirements
For the best experience, a PS2 Fat model (SCPH-30000 to SCPH-55000 series) is recommended.

**Minimum requirements:**
- Third-party HDD adapter
- IDE or SATA HDD (minimum 32 GB[*](#known-issues))

**Recommended setup:**
- Official Sony Network Adapter
- Kaico or BitFunx SATA Adapter Upgrade Board
- SATA SSD (256 GB to 2 TB)

**Notes:**
- A SATA SSD is recommended for [PSBBN](#psbbn), as improved random access speed results in faster menu responsiveness.
- [PSBBN](#psbbn) does not support third-party HDD adapters[*](#known-issues). Third-party adapters are only supported for [HOSDMenu installation](#install-hosdmenu-only).
- [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu) are both compatible with PS2 Slim SCPH-700xx models using an IDE Resurrector (or equivalent hardware mod), and early PS2 models (SCPH-10000 to SCPH-18000 series) with an official external HDD enclosure. [Additional setup is required for both configurations](#early-scph-1000018000-and-slim-scph-700xx-consoles).

The **PSBBN Definitive Project** requires an x86-64 or ARM64 PC for installation. Connect the HDD or SSD to the PC via SATA or a USB adapter.

## Installing on Linux
64-bit Debian-based distributions using `apt`, Arch-based distributions using `pacman`, and Fedora-based[*](#troubleshooting) distributions using `dnf` are supported. Nix-based systems are also supported via flakes. Recommended distributions are Linux Mint, Debian, and for Raspberry Pi, Raspberry Pi OS.

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
- Prompt you to select the target drive for installing **[PSBBN and HOSDMenu](#install-psbbn-and-hosdmenu)**, or a drive that already has an existing installation
- Prompt you to select a local folder on your PC where games and media will be managed (e.g., C:\PSBBN).
- Launch the **PSBBN Definitive Project** **[Main Menu](#main-menu)**

**Accessing the PSBBN Definitive Project Main Menu in the Future:**  
Simply right-click on `PSBBN-Launcher-For-Windows.ps1` and select **Run with PowerShell**

**NOTE:**  
It is normal for the selected drive to be unmounted in Windows while running the script. Always exit the **[PSBBN Definitive Project Main Menu](main-menu)** by pressing `q`. This ensures the drive is safely unmounted from WSL and returned to Windows. For USB drives, remember to also eject them from the Windows system tray before unplugging them.

If you experience any issues while running the **PSBBN Launcher for Windows**, see **[troubleshooting](#problems-running-the-script)**.

## Main Menu
If this is your first time running the script, or if required dependencies are missing, the setup process will automatically install everything needed before the main menu is shown.

From the main menu, you will have the following options:

1. [Install PSBBN and HOSDMenu](#install-psbbn-and-hosdmenu) (Official Sony Network Adapter required)  
Performs a fresh install of [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu)

2. [Install HOSDMenu only](#install-hosdmenu-only) (third-party HDD adapters supported)  
Performs a fresh install [HOSDMenu](#hosdmenu)

3. [Update PS2 System Software](#update-ps2-system-software)  
Updates an existing install of [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu) to the latest version

4. [Install Games and Apps](#install-games-and-apps)  
Installs PS1 and PS2 games, plus homebrew apps.

5. [Install Media](#install-media)  
    1. [Install Music](#install-music)
    2. [Install Movies](#install-movies)
    3. [Install Photos](#install-photos)
    4. [Set Media Location](#set-media-location)
    5. [Initialise Music Partition](#initialise-music-partition)

6. [Optional Extras](#optional-extras)  
    1. [Install PS2 Linux](#install-ps2-linux)
    2. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons) 
    3. [Change Language](#change-language)
    4. [Change Screen Settings](#change-screen-settings)
    5. [Clear Art & Icon Cache](#clear-art--icon-cache)

## Install PSBBN and HOSDMenu
This option installs both [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu). An official Sony Network Adapter is required[*](#known-issues). The installer performs the following actions:
- Formats the drive for a clean installation
- Downloads the latest [PSBBN](#psbbn) system software and language pack from [archive.org](https://archive.org/)
- Installs [PSBBN](#psbbn), [OSDMenu MBR](#osdmenu-mbr), and [HOSDMenu](#hosdmenu)
- Sets the interface language to match your operating system (defaults to English if unavailable)
- If the language is set to Japanese, downloads and installs [Online Channels](#internet-channel) from [archive.org](https://archive.org/)
- Prompts you to partition the drive

You have **114 GB** available for APA partitions. You will be asked to select a size for the following partitions:
- Music (used by the [Music Channel](#music-channel))
- Contents (used by the [Movie Channel](#movie-channel) and [Photo Channel](#photo-channel))

You can optionally reserve space on the drive for future use. This space is left unallocated and can later be used for APA partitions. If you plan to install PS2 Linux, reserve at least 3 GB.

An exFAT partition is then created using the remaining disk space (up to 2 TB) for storing games and apps.

## Install HOSDMenu only
This option installs [HOSDMenu](#hosdmenu) without [PSBBN](#psbbn) and is compatible with third-party HDD adapters The installer performs the following actions:
- Formats the drive for a clean installation
- Installs [OSDMenu MBR](#osdmenu-mbr) and [HOSDMenu](#hosdmenu)
- Sets the interface language to match your operating system (defaults to English if unavailable)
- Prompts you to partition the drive

You can optionally reserve space on the drive for future use. This space is left unallocated and can later be used for APA partitions. Up to 50% of the drive’s capacity (maximum 2 TB) can be reserved.

An exFAT partition is then created using the remaining disk space (up to 2 TB) for storing games and apps.

## Update PS2 System Software
Selecting this option checks online for the latest versions of the **PSBBN System Software**, **Language Pack**, [Online Channels](#internet-channel), and [OSDMenu](#hosdmenu), then automatically installs any available updates. All your games, settings, and personal data remain intact.

## Install Games and Apps
The **Game Installer** Fully automates the installation of PS1 and PS2 games, as well as homebrew apps:
- Auto-detects your PS2 drive
- For Linux users, lets you set a custom path on your PC for storing games and apps prior to installation
- Gives you a choice of [Open PS2 Loader (OPL)](#open-ps2-loader-opl) or [NHDDL](#nhddl) for the game launcher
- Assigns your chosen game launcher, [POPSLoader](#popsloader), and [wLaunchELF-R3Z](#wlaunchelf-r3z) to [startup button](#boot-options)
- Installs any available updates for [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [NHDDL](#nhddl), [Neutrino](#nhddl), [POPSLoader](#popsloader), [wLaunchELF-R3Z](#wlaunchelf-r3z), and [R3CONFIGURATOR](#r3configurator)
- Downloads and installs the [POPS](#popstarter) binaries and installs [POPStarter](#popstarter)
- Offers the option to apply a HDTV fix for PS1 games, useful for users with a TV that does not support 240p
- Offers the option to [synchronise](#synchronize-all-games-and-apps) the games and apps on your PC with your PS2's drive, or to [add additional](#add-additional-games-and-apps) games and apps
- Automatically converts PS2 games in `BIN/CUE` format to `ISO` when placed in the `CD` folder on your PC, and PS1 games in `BIN/CUE` format to `VCD` when placed in the `POPS` folder on your PC
- Let's you to select which games to display in the [Game Collection](#game-collection) and [Browser](#hosdmenu)
- For games in the `ZSO` format, "Compatibility Mode 1" is automatically enabled in their per-game [OPL](#open-ps2-loader-opl) configurations
- Creates [Virtual Memory Cards (VMCs)](#virtual-memory-cards) for all PS1 games, with the option to enable VMCs for all PS2 games. Also creates [VMC Groups](#virtual-memory-cards) for games that can interact with each other's save data
- Sets up multi-disc PS1 games to enable disc swapping
- Automatically downloads and installs [HugoPocked POPStarter fixes](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/), improving compatibility with over 100 PS1 games
- Creates all assets including meta-data, artwork and icons for all your games and apps:
  - Downloads artwork for the PSBBN [Game Collection](#game-collection) from the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) or IGN if not found in the database
  - Automatically contributes game artwork downloaded from IGN and reports missing artwork to the [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
  - Downloads cover art for PS2 and PS1 games from the [OPL Manager art database](https://oplmanager.com/site/?backups) for display in [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl), and [POPSLoader](#popsloader)
  - Downloads icons for the [Browser](#hosdmenu) from the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). If icons are unavailable, but images for a game are available in the [OPL Manager Art Database](https://oplmanager.com/site/?backups), 3D icons will be automatically created
  - Automatically contributes HDD-OSD icons and reports missing icons to the [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Updates shortcuts for homebrew apps in the [PSBBN Navigator Menu](#game-collection) and in the [HOSDMenu's](#hosdmenu) **OSDSYS menu**
- Creates **launcher partitions** that allow selected games and apps installed on your drive, along with PS1 games stored on an SMB network share, to be launched from the [Game Collection](#game-collection) and [Browser](#hosdmenu)
- Enables BDM HDD, Apps, and artwork in the [OPL](#open-ps2-loader-opl) configuration file
- Sets the language and [button configuration](#reassign-cross-and-circle-buttons) in the [OPL](#open-ps2-loader-opl) and [R3CONFIGURATOR](#r3configurator) configuration files to match the install settings

**NOTE:** To use `ZSO` files, you must select [OPL](#open-ps2-loader-opl) as your game launcher. When using [NHDDL](#nhddl), any `ZSO` files in your PC's games folder or on the PS2 drive are decompressed into `ISO` files.

### Synchronize All Games and Apps
This option updates the contents of your PS2’s storage to match the contents of the folder you selected on your PC. Any new games or apps are copied over, and any that were removed from your PC are deleted from the console.

The script lets you set a custom path on your PC for storing games to be installed. Simply place your files in the correct subfolder:
- PS2 `ISO`, `ZSO` or `BIN/CUE` files go in the `CD` folder
- PS2 `ISO` or `ZSO` files in the `DVD` folder
- PS1 `VCD` or `BIN/CUE` files in the `POPS` folder
- `ELF` files or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder

To add or delete games and apps, just modify the contents of the folder on your PC, then select **Synchronize All Games and Apps**.

### Add Additional Games and Apps
Alternatively, you can add games and homebrew apps directly to the exFAT filesystem on your PS2 drive by placing:
- PS2 `ISO` or `ZSO` files in the `CD` or `DVD` folders
- PS1 `VCD` files in the `POPS` folder
- `ELF` files or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder

Additionally, any new games or apps found in the selected folder on your PC will be installed. As with syncing, place:
- PS2 `ISO`, `ZSO` or `BIN/CUE` files go in the `CD` folder
- PS2 `ISO` or `ZSO` files in the `DVD` folder
- PS1 `VCD` or `BIN/CUE` files in the `POPS` folder
- `ELF` files or [SAS-compliant](#save-application-system-sas) `PSU` files in the `APPS` folder

Selecting **Add Additional Games and Apps** downloads metadata and artwork for all newly added content.

Games and apps can be deleted manually from the exFAT filesystem on the PS2 drive. Selecting **Add Additional Games and Apps** will also remove any deleted titles from the [Game Collection](#game-collection) and [Browser](#hosdmenu).

### Game Selector
When running the Game Installer, you will be presented with a list of all installed games and applications, allowing you to choose which titles appear in the [Game Collection](#game-collection) and [Browser](#hosdmenu). If you have a large collection, limiting the number of titles displayed can improve your browsing experience.

Up to 800 titles can be displayed in the [Game Collection](#game-collection) and [Browser](#hosdmenu). All PS2 games will remain available in your chosen game launcher ([OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl)), and all PS1 games will remain available in [POPSLoader](#popsloader).

You can also customise the order in which categories appear, such as PS2 Games, PS1 Games, Launchers, and Applications, giving you full control over how your library is organised.

### Installing ATA BDM Assault
To launch PS1 games from the [Game Collection](#game-collection) or [Browser](#hosdmenu), you must first install the **ATA BDM Assault drivers** onto a PS2 Memory Card.

1. Insert a PS2 Memory Card into your PS2 console.
2. Launch [POPSLoader](#popsloader).
3. Launch any PS1 game.

The required drivers will be installed automatically to the PS2 Memory Card.

### Launching PS1 Games from SMB
PS1 games in the `.VCD` format stored on an SMB network share can be launched from the [Game Collection](#game-collection) and [Browser](#hosdmenu). Before running the Game Installer:
1. Install your PS1 games and the required support files to your external device. Instructions can be found [here](https://nathanneurotic.github.io/POPSTARTERINFO/smb-network.html)
2. Place the renamed `POPSTARTER.ELF` files with the `SB.` prefix in the `POPS` folder, either on your PC or directly on your PS2's drive

### Save Application System (SAS)
The **Save Application System (SAS)** is a new standard for distributing homebrew applications for the PS2. All SAS-compliant apps are packaged in a `PSU` file and include icons and metadata, making it the recommended way to [install homebrew apps](#install-games-and-apps) on [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu). You can download SAS compliant apps from the [PS2 Homebrew Store](https://ps2homebrewstore.com/).

## Install Media
**NOTE: These features are for PSBBN users only.**  

Select **Install Media** from the main menu and you will be presented with the following option:
1. [Install Music](#install-music)
2. [Install Movies](#install-movies)
3. [Install Photos](#install-photos)
4. [Set Media Location](#set-media-location)
5. [Initialise Music Partition](#initialise-music-partition)

### Install Music
Install music for playback on the [PSBBN Music Channel](#music-channel). To use the Music Installer, you must be running **PSBBN Definitive Patch version 3.00 or later**. If you have previously upgraded from a lower version, you must [Initialise the Music Partition](#initialise-music-partition) first.

Supported formats are `.mp3`, `.m4a`, `.flac` and `.ogg`. Each file’s metadata must include the album title and track number. Place your music files in the default `music` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location) and place the files in the `music` subfolder.

### Install Movies
Install videos for playback on the [PSBBN Movie Channel](#movie-channel). To use the Movie Installer, you must be running **PSBBN Definitive Patch version 3.00 or later**. Your PC must also have an x86 processor.

The Movie Installer supports `MP4`, `M4V`, `MKV`, `VOB`, and other popular formats, as well as the PlayStation 2 video formats `pss` and `psm`. Shorter videos are encoded with a higher bitrate than longer videos. You should limit the video length to 2 hours and 15 minutes; longer videos may encode poorly or fail to convert.

Place your video files in the default `movie` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location) and place the files in the `movie` subfolder.

### Install Photos
Install images for viewing on the [PSBBN Photo Channel](#photo-channel). To use the Photo Installer, you must be running **PSBBN Definitive Patch version 3.00 or later**.

Supported formats including `JPG`, `PNG`, `TIF`, `GIF`, `BMP`, and more. Place your image files in the default `photo` folder on your PC, or choose a custom location using [Set Media Location](#set-media-location) and place the files in the `photo` subfolder.

### Set Media Location
Set a custom location for your `media` folder. Music should be placed in a `music` subfolder, videos should be placed in a `movie` subfolder, and images should be placed in a `photo` subfolder.

### Initialise Music Partition
This option erases all music data and resets the music database used by the [PSBBN Music Channel](#music-channel). Use this option if you have upgraded from a version of **PSBBN Definitive Patch** lower than 3.0 and want to use the [Music Installer](#install-music). You can also use this option if you experience problems with the [Music Channel](#music-channel).

## Optional Extras
Select **Optional Extras** from the main menu and you will be presented with the following option:
1. [Install PS2 Linux](#install-ps2-linux)
2. [Reassign Cross and Circle Buttons](#reassign-cross-and-circle-buttons)
3. [Change Language](#change-language)
4. [Change Screen Settings](#change-screen-settings)
5. [Clear Art & Icon Cache](#clear-art--icon-cache)

### Install PS2 Linux
**NOTE: This feature is for PSBBN users only.**  

PlayStation 2 Linux is an official kit from Sony that turned the PS2 into a Linux-based personal computer.  
The **Install PS2 Linux** option allows you to install or reinstall PS2 Linux.

To use this feature, you must:
- Reserve at least 3 GB of space during [PSBBN installation](#install-psbbn-and-hosdmenu).
- Have PSBBN Definitive Project version 4.0.0 or later installed.

When reinstalling PS2 Linux:
- If Linux came pre-installed with your version of the PSBBN Definitive Project, all PS2 Linux data will be erased, including your home directory.
- If you installed or reinstalled Linux using the **Install PS2 Linux** option, only the system files will be reinstalled — your personal files in the home directory will not be affected.

When installing PS2 Linux for the first time, or reinstalling a version that came pre-installed with the PSBBN Definitive Project, you will be prompted to choose the size of your home directory. The home directory is where your personal files and applications are stored.

**Notes:**  
- To launch PS2 Linux, power on your PS2 console, then hold the ○ button on the controller. PS2 Linux will then boot.  
- PS2 Linux requires a USB keyboard; a mouse is optional but recommended.  
- The `root` and `ps2` user accounts are both configured with the default password `password`. 
- To start a graphical interface, type `startx` at the command line.  
- Launching the **Dillo** web browser will open a mirror of the old official PS2 Linux website, where you can find a wide range of software to download and try.  

### Reassign Cross and Circle Buttons
This option lets you swap the functions of the × and ○ buttons on your controller. You can choose between the standard layout (× = enter, ○ = back) or the alternate layout (○ = enter, × = back), depending on your preference.  

**NOTE: This feature only applies to [PSBBN](#psbbn), [OPL](#open-ps2-loader-opl), and [R3CONFIGURATOR](#r3configurator). It does not swap the button layout for the [POPS](#popstarter) in-game reset dialog when exiting a PS1 game, or [HOSDMenu](#hosdmenu).**  

### Change Language
When [PSBBN](#psbbn) is installed, this option changes the system language of PSBBN. Select from English, German, Italian, Brazilian Portuguese, Spanish, French, and the original Japanese. More languages will be added with future updates. For Japanese users, it also downloads and installs the Japanese versions of the [Online Channels](#internet-channel).

For both [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu) users, this option also changes the language for the [POPS](#popstarter) in-game reset (IGR) message, [OPL](#open-ps2-loader-opl), [R3CONFIGURATOR](#r3configurator), and the language preference used by the [Game Installer](#install-games-and-apps).

After changing the language, it is recommended to rerun the [Game Installer](#install-games-and-apps) and select *Add Additional Games and Apps* to update game titles to your selected language (English and Japanese only). For [PSBBN](#psbbn) users, this will also update the PlayStation game manuals.

### Change Screen Settings
**NOTE: This feature is for PSBBN only.**  
[PSBBN](#psbbn) normally locks the screen system settings to **4:3**. This option allows you to change the screen setting. You can choose between **4:3**, **Full**, and **16:9**.

This setting is used by some games and [HOSDMenu](#hosdmenu). It does not change the aspect ratio of [PSBBN](#psbbn) itself.

### Clear Art & Icon Cache
This option removes all game artwork and icons that are stored locally on your PC. When you next run the game installer, it will scan your game collection, then download and apply fresh copies of the required artwork and icons.  

You might want to clear the cache if games display incorrect or low-quality artwork, as updated artwork may now be available.

# User Guide

## Boot Options
You can hold controller buttons while powering on the PS2 console to change how the system boots:

| Button | PS2 System Software | Boot Behavior                                      |
|--------|---------------------|----------------------------------------------------|
| None   | PSBBN + HOSDMenu    | Automatically boots [PSBBN](#psbbn)                |
| None   | HOSDMenu only       | Automatically boots [HOSDMenu](#hosdmenu)          |
| ✕      | PSBBN + HOSDMenu    | Boots [HOSDMenu](#hosdmenu)                          |
| ○      | PSBBN + HOSDMenu    | Boots [PS2 Linux](#install-ps2-linux) (if installed) |
| □      | Any configuration   | Boots the selected game launcher ([OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl)) |
| △      | Any configuration   | Boots [POPSLoader](#popsloader) |
| START  | Any configuration   | Boots [wLaunchELF-R3Z](#wlaunchelf-r3z) |

## PSBBN
PlayStation Broadband Navigator (also referred to as BB Navigator and PSBBN) is an official PlayStation 2 operating system released exclusively in Japan. It features channels for [games](#game-collection), [music](#music-channel), [movies](#movie-channel), [photos](#photo-channel), and [internet services](#internet-channel).

The **Definitive Patch** enhances and extends its functionality, offering:
- A full translation of the stock Japanese BB Navigator software version 0.32 — All binaries, XML files, textures, and pictures have been translated[*](#known-issues)
- Available in English, German, Italian, Brazilian Portuguese, Spanish, French, and the original Japanese
- Support for PS2 consoles from all regions; the original software was restricted to Japanese consoles
- [OSDMenu MBR](#osdmenu-mbr) — a homebrew replacement for Sony’s original MBR program with numerous improvements over the original implementation
- A patched `osdboot.elf` to bypass the CRC security check, allowing the use of custom kernels
- Large HDD support — originally limited to 128 GB. Drives up to 2 TB are now supported using [APA-Jail](#apa-jail)
- A music partition up to 114 GB for around 180 albums[*](#known-issues); originally limited to 5 GB
- A contents partition up to 114 GB for the storage of movies and photos; originally limited to 5 GB
- A Direct link to the [Game Collection](#game-collection) on the **Top Menu** for quick access
- DNAS authorization checks bypassed to enable access to the [online channels](#internet-channel)
- [Online channels](#internet-channel) from Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, Bandai, So-Net, and BIGLOBE
- Original Japanese [online channels](#internet-channel) in Japanese on Japanese installs and in English on all other installs
- **Audio Player** feature re-added to the [Music Channel](#music-channel) from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders[*](#known-issues)
- Manual and troubleshooting pages regarding the **Audio Player** feature re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard[*](#known-issues)
- An option to swap the functions of the × and ○ buttons
- An option to change screen settings (normally locked 4:3), with selectable modes: 4:3, Full, and 16:9.
- Support for the PlayStation 2 DVD remote control[*](#known-issues)

For full details on all features and a complete user guide, refer to the **PlayStation BB Guide**, accessible from the **Top Menu**.

### Game Collection
You can find the **Game Collection** on the PSBBN **Top Menu**. This is the first menu you see when PSBBN starts up.
- When installed using the [Game Installer](#install-games-and-apps), all apps and [selected games](#game-selector) will be displayed in the collection as a cover flow-style interface.
- Items are grouped into PS2 games, PS1 games, and homebrew apps.
- PS2 and PS1 games are sorted alphabetically and organized by game series, with games in a series ordered by release date.
- When the language is set to Japanese, Japanese-region game titles are displayed in their original Japanese and sorted in “gojūon” (五十音) order.
- Homebrew apps are sorted alphabetically, while [SAS apps](#save-application-system-sas) are further divided into sub-groups based on app type (system, game, emulator, etc.).  
- You can view a manual for PS1 games that lists supported hotkeys. To access the manual, press **△** on a highlighted PS1 game and select *Manual*.
- You can set shortcuts for up to four items by pressing **△** on a highlighted game and selecting *Add to Navigator Menu*. You can quickly access your shortcuts by pressing **SELECT**.

### Music Channel
The **Music Channel** lets you play audio CDs, listen to music stored on your PS2’s internal drive, and create custom playlists. Music can be ripped directly on the PS2 from an audio CD, and installed using the [Music Installer](#install-music).

It also supports exporting music to a NetMD-compatible MiniDisc recorder. However, MiniDisc support is broken in the current version of the PSBBN Definitive Patch. If you want to try the MiniDisc functionality, you can use a [legacy version of the PSBBN Definitive English Patch](https://github.com/CosmicScale/PSBBN-Definitive-Project/tree/PSBBN-Definitive-English-Patch).

### Movie Channel
The **Movie Channel** allows you to play back movies stored on your PS2's internal drive, organise your movies, and create playlists. Movies can be downloaded from several of the [Online Channels](#internet-channel), and installed using the [Movie Installer](#install-movies).

### Photo Channel
The Photo Channel allows you to view photos stored on the PS2's internal drive or a FAT-formatted USB device (USB stick, digital camera, etc.). Photos can be imported from USB devices, and installed using the [Photo Installer](#install-photos). You can create albums and playlists of your photos. You can also download game artwork and screenshots from the [Online Channels](#internet-channel).

### Internet Channel
On the **Internet Channel**, you can access archives of various publishers’ online channels, just as they appeared in the early 2000s. The channels have been translated into English (work in progress). If you have a Japanese install of PSBBN, you will have access to the original Japanese versions. To view these online channels, your PlayStation 2 system must be connected to the internet. On the **Internet Channel** you can:
- Explore the online channels of various game publishers, including Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, and Bandai.
- Download trailers for *Metal Gear Solid 3: Subsistence*, *Bomberman Online*, and more. Trailers can be downloaded from the **Konami Channel**, **BANDAI Entertainment World**, and the **HUDSON CHANNEL**. Downloaded trailers are saved to an album in the [Movie Channel](#movie-channel).
- Download artwork and screenshots from the **PlayStation® Now!** channel. Downloaded images are saved to an album in the [Photo Channel](#photo-channel).
- Play a number of classic games from the Hudson archive, including *Star Soldier*, *Milon’s Secret Castle*, and *Nuts & Milk*. Games can be played by selecting *PLAY GAMES* from the **HUDSON CHANNEL** main menu.

## HOSDMenu
**HDD-OSD** is official Sony software that extends the PlayStation 2's system menu (OSDSYS) with hard drive support, allowing you to manage software, save data, and launch games and apps directly from the HDD through Browser 2.0. **HOSDMenu**, written by [pcm720](https://github.com/pcm720), patches **HDD-OSD** and adds additional features, including:
- Support for larger drives — **HDD-OSD** was previously limited to 1 TB
- Launch homebrew apps directly from the **OSDSYS** custom menu
- Launch [SAS-compatible applications](#save-application-system-sas) from Memory Cards and from the internal drive in **Browser 2.0**
- Support for launching applications from MMCE, MX4SIO, UDPBD, iLink devices and APA- and exFAT-formatted HDDs
- [Launch PS1 and PS2 Game Discs](#launching-ps1-and-ps2-game-discs) with support for Game ID, MechaPwn, and built-in PS1VmodeNeg
- Integrated GSM for disc games and applications
- Support for 1080i and 480p
- And more — see the [GitHub repository](https://github.com/pcm720/OSDMenu) for full details

If installed alongside [PSBBN](#psbbn), it can be launched from the [Game Collection](#game-collection), via a [shortcut in the Navigator Menu](#game-collection), or by holding down the × button while the console starts up. If only **HOSDMenu** was installed, it will autoboot.

When installed with the [Game Installer](#install-games-and-apps):
- Apps will appear in the **OSDSYS menu**, allowing quick launching
- [Selected games](#game-selector) games will appear in the **Browser** as unique 3D icons, modelled on the physical DVD/CD game case, sourced from the [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- [SAS compliant apps](#save-application-system-sas) downloaded from the [PS2 Homebrew Store](https://ps2homebrewstore.com/) will also appear in the **Browser** represented by unique icons.

## Open PS2 Loader (OPL)
[Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) is a 100% open source game and application loader for the PS2. All installed PS2 game will be displayed in OPL. If you select OPL as your game launcher when [installing games and apps](#install-games-and-apps), per-game settings assigned in OPL are reflected when launching games from the [Game Collection](#game-collection) and [Browser](#hosdmenu).

## NHDDL
[NHDDL](https://github.com/pcm720/nhddl) is a launcher for [Neutrino](https://github.com/rickgaiser/neutrino), a small, fast, and modular PS2 device emulator. All installed PS2 game will be displayed in NHDDL. If you select NHDDL as your game launcher when [installing games and apps](#install-games-and-apps), per-game settings assigned in NHDDL are reflected when launching games from the [Game Collection](#game-collection) and [Browser](#hosdmenu).

## POPSLoader
[POPSLoader](https://github.com/NathanNeurotic/POPSLoader) is a graphical launcher designed to easily browse and launch your PS1 games (using [POPStarter](#popstarter)) from various storage devices. All installed PS1 game will be displayed in **POPSLoader**.

## POPStarter
**POPS** is an official Sony PS1 emulator for PS2, originally released exclusively in Japan as a way to distribute PS1 games over the internet to [PSBBN](#psbbn) users. **POPStarter** is a homebrew launcher for **POPS** that enables the emulator to play any PS1 game from internal and external drives.

When installing PS1 games, **[HugoPocked POPStarter fixes](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)** are automatically downloaded and installed, improving compatibility with over 100 PS1 games.

Hotkey button combinations are supported for disc swapping and various other options:

| Hotkey               | Function                       |
|----------------------|--------------------------------|
| SELECT + START + L1  | Quit Game                      |
| SELECT + L2 + R2 + ✕ | Software Reset                 |
| SELECT + L1 + R2 	   | Enable smooth texture mapping  |
| SELECT + L2 + R1     | Disable smooth texture mapping |
| SELECT + R1 + R2     | Enable scanlines               |
| SELECT + L1 + L2     | Disable scanlines              |
| SELECT + L2 + R2 + △ | Open PlayStation CD lid        |
| SELECT + L2 + R2 + ↑ | Insert disc 1                  |
| SELECT + L2 + R2 + → | Insert disc 2                  |
| SELECT + L2 + R2 + ↓ | Insert disc 3                  |
| SELECT + L2 + R2 + ← | Insert disc 4                  |
| SELECT + L2 + R2 + □ | Close PlayStation CD lid       |

Details on hotkeys can also be found in the **Manual** of each installed PS1 game. To access it, in the **[Game Collection](#game-collection)**, press **△** then select **Manual**.

## Exiting Games
Hotkey button combinations are supported for quitting games and powering off the console.

**NOTE: If you selected [NHDDL](#nhddl) as your game launcher, you will not be able to perform these functions while playing PS2 games.**

| Hotkey                             | Function                           |
|------------------------------------|------------------------------------|
| SELECT + START + L1 	             | Quit PS1 Game                      |
| L1 + L2 + R1 + R2 + SELECT + START | Quit PS2 Games                     |
| L1 + L2 + L3 + R1 + R2 + R3        | Power Off Console (PS2 Games Only) |

## Virtual Memory Cards
A **Virtual Memory Card (VMC)** allows you to store game progress on your PlayStation 2’s internal drive rather than on a standard Memory Card.

A **POPStarter VMC** is created for every PS1 game, and when running the [Game Installer](#install-games-and-apps), you will be given the option to enable **VMCs** for all your PS2 games.

Both PS1 and PS2 games support **VMC Groups**, enabling certain games to share a VMC and access save data created by other titles. For example, *Metal Gear Solid’s* Psycho Mantis can comment on other Konami games you've played, and credits from *Gran Turismo 3* can be transferred to *Gran Turismo 4*.

## Game ID
The Game ID feature on the **Retro GEM**, **MemCard Pro 2**, and **SD2PSX** is fully supported when launching games and homebrew apps from the [Game Collection](#game-collection) and [Browser](#hosdmenu), as well as from physical PS1 and PS2 game discs.

The **Retro GEM** is a digital to digital HDMI output upgrade for multiple consoles. **Retro GEM Game ID** allows the auto-switching of display profiles on a per-game basis. You can find out more about the **Retro GEM** on the [Pixel FX website](https://www.pixelfx.co/hdmi-retro-gem).

**MemCard Pro 2** and **SD2PSX** allow save data to be stored on an SD card, supporting multiple **Virtual Memory Cards (VMCs)** and many other features. The **Game ID** identifies which game is running, allowing each game to be assigned its own **VMC**, and automatically switching to the correct card when the game is launched. You can find out more about the **MemCard Pro 2** on the [8BitMods website](https://8bitmods.com/accessories/memcard-pro/) and the **SD2PSX** on the [SD2PSX website](https://sd2psx.net/)

## Launching PS1 and PS2 Game Discs
When running [PSBBN](#psbbn) or [HOSDMenu](#hosdmenu), simply insert a game disc into the DVD drive. The game will boot and set the [Game ID](#game-id) on both the **Retro GEM** and **MemCard Pro** or **SD2PSX** accordingly.

[MechaPwn](https://github.com/MechaResearch/MechaPwn) is also fully supported, with automatic PS2 logo patching that allows imported and master discs to be launched without skipping the PlayStation 2 logo or encountering a corrupted logo screen. When playing imported PS1 games, the PlayStation driver's video mode is adjusted if necessary to ensure they run in the correct video mode.

## wLaunchELF-R3Z
A fork of [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) by [R3Z3N](https://github.com/saildot4k) that includes several advanced features. Notably, it allows you to manage files on the internal drive's exFAT partition, a capability not available in other wLaunchELF forks. More information is available [here](https://github.com/saildot4k/wLaunchELF_R3Z).

## R3CONFIGURATOR
A GUI application for editing [OSDMenu](osdmenu-mbr) and other config files. It allows you to modify boot options, such as assigning an app to a button for quick launch at startup, setting the display modes for [HOSDMenu](#hosdmenu), enabling or disabling the [HOSDMenu](#hosdmenu) **OSDSYS** custom menu, and much more.

You can find full details on the [R3CONFIGURATOR GitHub page](https://github.com/saildot4k/R3CONFIGURATOR).

## OSDMenu MBR
**OSDMenu MBR** is a core component of the **PSBBN Definitive Project**. Written by [pcm720](https://github.com/pcm720). This program is executed on every system boot and when an application is launched from [PSBBN](#psbbn). It is a homebrew replacement for Sony’s original MBR program. It is responsible for initializing the hardware, as well as launching applications and game discs.

**OSDMenu MBR** comes with many advantages over the original implementation including support for launching ELFs by holding a gamepad button at startup, automatic PS2 logo patching when [launching PS2 game discs](#launching-ps1-and-ps2-game-discs), adjusting video modes when [launching imported PS1 game discs](#launching-ps1-and-ps2-game-discs), [Visual Game ID](#game-id) for the **Retro GEM**, modifying system settings, and launching homebrew apps, and games via [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl), and [POPStarter](#popstarter).

The full readme can be found [here](https://github.com/pcm720/OSDMenu/blob/main/mbr/README.md).

## APA-Jail
![APA-Jail Type-A2](https://github.com/user-attachments/assets/8c83dab7-f49f-4a77-b641-9f63d92c85e7)

**APA-Jail** is another core component of the **PSBBN Definitive Project**. [PSBBN](#psbbn) was originally limited to just 128 GB of usable storage. **APA-Jail** allows for just over 2 TB.  

**APA-Jail**, created and developed by [Berion](https://www.psx-place.com/resources/authors/berion.1431/), enables the PS2's APA partitions to coexist with an exFAT partition. For [PSBBN](#psbbn), up to 128 GB of the drive can be reserved for APA partitions, while the remaining space (up to 2 TB) is formatted as exFAT. This setup allows [PSBBN](#psbbn) and [HOSDMenu](#hosdmenu) to be installed on the APA partitions, while games and homebrew apps are installed on the exFAT partition.

[OSDMenu MBR](#osdmenu-mbr) resides on a special APA partition. When an item is selected from the [Game Collection](#game-collection), [OSDMenu MBR](#osdmenu-mbr) loads games and homebrew apps from the exFAT partition. PS1 games are handled via [POPStarter](#popstarter) and PS2 games via [OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl).

**Warning: Manually creating new APA partitions on your PS2 drive and exceeding the allocated space for APA will corrupt the drive.**

## Early (SCPH-10000–18000) and Slim (SCPH-700xx) Consoles
The **PSBBN Definitive Project** can be installed on PS2 Slim **SCPH-700xx** models with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod. Installing to an SD card is not supported on Windows. For PSBBN compatibility, an SATA adapter must be used, such as the [iFlash-Sata v10](https://www.iflash.xyz/store/iflash-sata-v10/).

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
⚠️ **Known issue**: Installing on **Fedora** is currently problematic. It is recommended to use a **Debian-based** distribution or the **[PSBBN Launcher for Windows](#installing-on-windows)**.

1. Make sure you are running the latest version of your operating system and all available updates are installed
2. Use a recommended OS. The **PSBBN Definitive Project** has been fully tested on:
- Debian
- Linux Mint
- Raspberry Pi OS
- Windows 10 Home Edition
- Windows 11 Home Edition

## Problems Running the Script

**If you receive the "Failed to create games list" error:**

The `ISO`, `ZSO`, or `VCD` file being processed is likely invalid or corrupted. Remove the file from both the local folder on your PC and your PS2 drive, then try again.

To avoid this issue, make sure your game image is a verified good dump. Check the MD5 or SHA-1 checksum of your `ISO` or `BIN` file and confirm that it matches the corresponding entry on [redump.org](http://redump.org).

**If you are using [Windows](#installing-on-windows) and experience issues:**

If the [PSBBN Definitive Project menu](#main-menu) displays squares instead of text, or the [Game Selector menu](#game-selector) does not render correctly, change the PowerShell font. Right-click the PowerShell title bar, open **Properties**, and select **Cascadia Mono** (Windows 11) or **MS Gothic** (Windows 10).

For other issues, continue with the troubleshooting steps below:

1. Open PowerShell as an administrator and run the following command:
```
wsl --unregister PSBBN
```
2. Download the latest version of the `PSBBN-Launcher-For-Windows.ps1` script [here](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)
3. Ensure you have an active internet connection. If you are using a VPN, try disabling it
4. Run the `PSBBN-Launcher-For-Windows.ps1` script again

**If you are using [Linux](#installing-on-linux) and experience issues:**
1. Delete the `PSBBN-Definitive-Project` folder
2. Re-Clone the repository with the following command:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

**Still having issues?**
1. Try connecting the PS2 drive directly to your PC using an internal SATA connection or a USB port directly on the motherboard. Avoid using add-on cards
2. If you are using a SATA-to-USB adapter, try using a different make or model
3. If you still have issues, try a different drive

## Problems Launching PSBBN and HOSDMenu
When you connect the drive to your PS2 console and power it on, **[PSBBN or HOSDMenu](#boot-options)** should automatically launch.

If your console boots to the regular OSD, freezes, or displays an error, you should try the following:
1. Remove all PS2 Memory Cards from your console
2. If you installed [PSBBN](#psbbn), make sure you are using an **official Sony Network Adapter**; PSBBN does not support third-party HDD adapters
3. Check that the connectors on the console and network or HDD adapter are clean and free of dust/debris
4. Ensure the network or HDD adapter and drive are securely connected to the console
5. If using a SATA mod, make sure it has been installed correctly
6. Use a different drive and reinstall [PSBBN](#install-psbbn-and-hosdmenu) or [HOSDMenu](#install-hosdmenu-only)
7. If your console has an IDE converter or SATA mod installed, try using a different converter or mod.
8. Use a different official Sony Network Adapter or third-party HDD adapter
9. Use a different PS2 console

## Games Not Working
Some games may fail to launch or exhibit compatibility issues. First, make sure your game image is a verified good dump. Check the MD5 or SHA-1 checksum of your `ISO` or `BIN` file and confirm that it matches the corresponding entry on [redump.org](http://redump.org).

For issues with PS2 games, if you selected [OPL](#open-ps2-loader-opl) as your game launcher, you can check for existing issues or report a new one [here](https://github.com/ps2homebrew/Open-PS2-Loader/issues). If you selected [NHDDL](#nhddl), you can do so [here](https://github.com/rickgaiser/neutrino/issues).

If all PS1 or PS2 games fail to launch, follow the steps below:

If you experience problems launching PS1 games, make sure you have correctly installed the **ATA BDM Assault drivers** on a PS2 Memory Card and that the card is inserted into your console. Installation instructions and a download link can be found [here](#installing-ata-bdm-assault).

If games fail to launch from the [Game Collection](#game-collection) or [Browser](#hosdmenu), try the following:
1. If you have a [mod chip](#known-issues), disable it
2. If you're having trouble launching PS2 games, remove all PS2 Memory Cards from your console and try again. If this resolves the issue, delete any `Your System Configuration` save files from the memory cards, as corrupted configuration data can prevent games from launching.
3. Check that the connectors on the console and Network or HDD Adapter are clean and free of dust or debris
4. Ensure the Network or HDD adapter and drive are securely connected to the console
5. If using a SATA mod, make sure it has been installed correctly

If games still fail to launch, try loading PS2 games using [OPL](#open-ps2-loader-opl) or [NHDDL](#nhddl), and PS1 games using [POPSLoader](#popsloader).

If OPL freezes at startup, delete any existing OPL configuration files from your PS2 Memory Cards or connected USB devices. You can also hold `START` while OPL launches to bypass reading the configuration file.

To display the games list in OPL, adjust the following settings:
1. Settings > HDD (APA) Start Mode: Off
2. Settings > BDM Start Mode: Auto
3. Settings > BDM Devices > HDD (GPT/MBR): On
4. Settings > Save Changes

If PS2 games do not appear in the games list in [NHDDL](#nhddl) or [OPL](#open-ps2-loader-opl) (after modifying the OPL settings as described above), or PS1 games do not appear in [POPSLoader](#popsloader), try the following:
1. Connect the PS2 drive directly to your PC using an internal SATA connection or a different SATA-to-USB adapter, then reinstall [PSBBN](#install-psbbn-and-hosdmenu) or [HOSDMenu](#install-hosdmenu-only)
2. Use a different drive and reinstall [PSBBN](#install-psbbn-and-hosdmenu) or [HOSDMenu](#install-hosdmenu-only)
3. If your console has an IDE converter or SATA mod installed, try using a different converter or mod
4. Use a different official Sony Network Adapter or third-party HDD adapter
5. Use a different PS2 console

## Reporting issues
If you have tried the relevant steps above and the problem persists, check for an existing issue or open a new one [here](https://github.com/CosmicScale/PSBBN-Definitive-Project/issues).  
Please include all relevant log files:
- `setup.log`
- `PSBBN-installer.log`
- `hosdmenu.log`
- `game-installer.log`
- `extras.log`
- `media.log`

**Linux** users can find these logs in `PSBBN-Definitive-Project/logs`. **Windows** users can find these logs in the folder where their games and media files are stored.

# Known Issues
- PSBBN will freeze at the "PlayStation 2" logo when booting, if a third-party, unofficial HDD adapter is used. **An official Sony Network Adapter is required**.
- PSBBN will freeze when launching games or apps if a mod chip is active. To use PSBBN, mod chips must be disabled.  
- Instances in feega where some Japanese text couldn't be translated due to it being hard-coded in an encrypted file. Atok software has not been translated.  
- MiniDisc support is broken as of patch version 2.10 and above. I hope to fix this in a future update  
- PSBBN's default on-screen keyboard is set to Japanese. However, a US English on-screen keyboard has been added, though you’ll need to press the `SELECT` button multiple times to switch to it. There's a bug where spacebar doesn't work on the US English on-screen keyboard, but you can enter a space by pressing the **△** button on the controller instead.  
- In PSBBN, the × and ○ button swap is only supported on DualShock 2 controllers
- In PSBBN, the media buttons on the PS2 DVD Remote Control are only supported on SCPH-5000x consoles with a built-in IR receiver. The remote control can behave erratically if no controller is plugged into Controller Port 1.
- Music installed with the Music Installer is only playable if written to the first 3 GB of the music partition. Music ripped from audio CDs in the [Music Channel](#music-channel) is unaffected and can use the full capacity of the partition.
- PSBBN only supports dates up to the end of 2030. When setting the time and date, the year must be set to 2030 or below.
- Japanese PSBBN installations will fail on drives smaller than 128 GB
- exFAT partition cannot exceed 2 TB. When using a larger drive, remaining space beyond that will be unusable.
- **wLaunchELF** and other native PS2 apps cannot create APA partitions on the PS2 drive. New partitions should only be created using the version of **PFS Shell** included with this project.
- APA partitions must not be created beyond the space reserved for APA during installation. Doing so will overwrite data on the exFAT partition.

# Credits
**PSBBN Definitive Project - Copyright © 2024-2026 by [CosmicScale](https://github.com/CosmicScale)**
- `PSBBN-Definitive-Patch.sh`, `Setup.sh`, `PSBBN-Installer.sh`, `HOSDMenu-Installer.sh`, `Game-Installer.sh`, `Media-Installer.sh`, `music-installer.py`, `psmbuild.py`, `Extras.sh`, `art_downloader.py`, `list-builder.py`, `list-sorter.py`, `txt_to_icon_sys.py`, `ps2iconmaker.sh`, `AppDB.csv`, `TitlesDB_PS1.csv`, `TitlesDB_PS2.csv`, `ps1_vmc_groups.list`, `POP-game-fixes.list`, `game-selector.py` written by [CosmicScale](https://github.com/CosmicScale)
- `game-selector.py` based on a script written by [Luiz Antonio Lazoti](https://github.com/luizoti)
- `PSBBN-Launcher-For-Windows.ps1` written by Yornn
- `icon_sys_to_txt.py` written by [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- PSBBN 3D icon designed by Yornn
- Uses APA-Jail code from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) by [Berion](https://www.psx-place.com/members/berion.1431/)
- Contains code from [`list_builder.py`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/list_builder.py) from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma)
- Contains code from [`ps2iconmaker.sh`](https://github.com/CosmicScale/HDD-OSD-Icon-Database/issues/1#issuecomment-2852499188) by [Sakitoshi](https://github.com/Sakitoshi)
- Contains data from [`TitlesDB_PS1_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS1_English.txt) and [`TitlesDB_PS2_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS2_English.txt) from the [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) by [GDX-X](https://github.com/GDX-X)
- Contains data from [`vmc_groups.list`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/vmc_groups.list) from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma)
- PSBBN Localization Team
  - English — [CosmicScale](https://github.com/CosmicScale)
  - German — [Argo707](https://github.com/Argo707)
  - Italian — [plamadika](https://github.com/plamadika) & [lcipria](https://github.com/lcipria)
  - Brazilian Portuguese — [Emerson Teles (Emertels)](https://github.com/Emertels)
  - Spanish — [Ignacio Trillo (Nacheras)](https://github.com/Nacheras) & [ViZoRRetrogames](https://github.com/ViZoRRetrogames)
  - French — [Bistroww](https://github.com/Bistroww) & [iSlickick](https://github.com/iSlickick)

**The PSBBN Definitive Project uses the following PS2 homebrew tools and applications:**
- [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) created and maintained by [CosmicScale](https://github.com/CosmicScale)
- [OSDMenu](https://github.com/pcm720/OSDMenu) by [pcm720](https://github.com/pcm720)
- [APA Partition Header Checksumer](https://github.com/pink1stools/APA-Partition-Header-Checksumer/) by [Pink1](https://github.com/pink1stools) and [Berion](https://www.psx-place.com/members/berion.1431/). [Linux port](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) by [Bucanero](https://github.com/Bucanero)
- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/ext2) and [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) with 8MB APA partition and EXT2 modifications by [AKuHAK](https://github.com/AKuHAK)
- PFS Fuse from [PFS Shell](https://github.com/ps2homebrew/pfsshell) by [PS2 Homebrew Projects](https://github.com/ps2homebrew)
- PSU Extractor from [PSV Save Converter](https://github.com/bucanero/psv-save-converter) by [Bucanero](https://github.com/Bucanero)
- [`ziso.py`](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/pc/ziso.py) by Virtuous Flame
- cue2pops from [pops2cue](https://github.com/bucanero/pops2cue) by [Bucanero](https://github.com/Bucanero)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) from [PS2 Homebrew Projects](https://github.com/ps2homebrew) with BDM contributions from [KrahJohlito](https://github.com/KrahJohlito) and Auto Launch modifications by [CosmicScale](https://github.com/CosmicScale)
- [Neutrino](https://github.com/rickgaiser/neutrino) by [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) by [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/resources/popstarter.683/) by [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [POPSLoader](https://github.com/NathanNeurotic/POPSLoader) by [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- [HugoPocked POPStarter fixes](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/) by [HugoPocked](https://ko-fi.com/hugopocked)
- [ATA BDM Assault](https://github.com/saildot4k/ATA-Assault) by [R3Z3N](https://github.com/saildot4k)
- [wLaunchELF_R3Z](https://github.com/saildot4k/wLaunchELF_R3Z) by [R3Z3N](https://github.com/saildot4k)
- [R3CONFIGURATOR](https://github.com/saildot4k/R3CONFIGURATOR) by [R3Z3N](https://github.com/saildot4k)
- PS2 cover art from the [OPL Manager Art DB backups](https://oplmanager.com/site/index.php?backups)
- App artwork from [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) and [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) courtesy of [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
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

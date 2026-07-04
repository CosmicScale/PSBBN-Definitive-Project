# PSBBN Definitive English Patch

This is an English-language patch for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console.

This patch can be applied to a PS2 running the original Japanese version of PSBBN. A pre-patched HDD image is also available.

Legacy versions of the **PSBBN Definitive Patch** are **not** compatible with the **[PSBBN Definitive Project](https://github.com/CosmicScale/PSBBN-Definitive-Project)**, its **Game Installer**, or other tools.

## Patch Features
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console as well as PS2 Slim SCPH-700xx models with an **IDE Resurrector** or similar hardware mod, regardless of region
- DNAS authorization checks bypassed to enable access the online channels
- Online channels from Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI have been translated into English. Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese QWERTY on-screen keyboard replaced with US English on-screen keyboard**
- Storage capacity limited to 130 GB

## Version History 
**v1.2 - 4th September 2024:**
- Fixed a bug on the Photo Channel that could potentially prevent the Digital Camera feature from being launched.
- Fixed formatting issues with a number of error messages where text was too long to fit on the screen.
- Various small adjustments and corrections to the translation throughout.

**v1.1.1 - 8th March 2024:**  
- X11 has been set to run in English. The restore, move, resize, minimize, and close buttons now show in English while using the NetFront web browser. When saving files, time stamps now also display in English formatting.

**v1.1 - 5th March 2024:**
- The NetFront web browser is now in English. The browser can be accessed by going through the "Confirm/Change" network setting dialogs, then selecting "Change router settings".
- Atok user manual has been translated.
- Bug fixes:
- **General**: When a game disc was inserted while on the Top Menu, it would cause the console to freeze.  
- **Music Channel**: The number of times a track had been checked-out to a MiniDisc recorder was not displayed correctly.  
- A number of typos have been fixed.

**v1.0 - 21st September 2023:**
- Initial release.

## Installation Instructions
There are two ways to install this English patch:

1. **PS2 HDD RAW Image Install:** Use this method if you have access to a PC and a way to connect your PS2 HDD/SSD to your PC. This is the most straightforward option. All data on the HDD will be lost.

2. **Patch an existing PSBBN install:** Use this method if you already have an existing PSBBN install on your PlayStation 2 console. Also, follow these instructions to install future patch updates. No data will be lost.

### PS2 HDD RAW Image Install
#### What You Will Need:
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter). The drive must be 120 GB or larger
- A way to connect the PS2 HDD to a PC
- 120 GB of free space on your PC to extract the files
- Disk imaging software

#### Installing the HDD Image
1. Download [PSBBN_English_Patched_v1.x.x_Image.7z](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patched_v1.2_Image.7z) and uncompress it.
`PSBBN_English_Patched_v1.x.x_HDD_RAW.img` is a raw PS2 disk image of the Japanese PlayStation BB Navigator Version 0.32 with the PlayStation Broadband Navigator (PSBBN) Definitive English Patch pre-installed.
2. To write this image to your PS2 HDD, you need disk imaging software. For Windows, I recommend using HDD Raw Copy ver. 1.10 portable. You can download it [here](https://hddguru.com/software/HDD-Raw-Copy-Tool/).

### Patch an existing PSBBN install
#### What You Will Need:
- Any fat model PS2 console*
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter)
- An existing install of PSBBN software 0.32 on your PS2 console
- A FreeMcBoot Memory Card
- A USB flash drive formatted as FAT32
- A USB keyboard

#### Installing the English Patch:  
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

## Installing the Japanese PSBBN software
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

## Notes
- Use OPL-Launcher to launch PS2 games from the Game Channel. More details can be found [here](https://github.com/ps2homebrew/OPL-Launcher).
- Lacks support for large HDDs, drives larger than 130 GB cannot be taken full advantage of. PSBBN can only see the first 130,999 MB of data on your HDD/SSD (as reported by wLaunchELF). If there is 131,000 MB or more on your HDD/SSD, PSBBN will fail to launch. Delete data so there is less than 131,000 MB used, and PSBBN will launch again. Be extra careful if you have installed via the **PS2 HDD RAW Image** on a drive larger than 120 GB, going over 130,999 MB will corrupt the drive.
- You may need to manually change the title of your "Favorite" folders if they were created before you **Patched an existing PSBBN install**.

\* Also compatible with the PS2 Slim SCPH-700xx models with an [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) or similar hardware mod, A SATA adapter must be used, such as the [iFlash-Sata v10](https://www.iflash.xyz/store/iflash-sata-v10/). **PS2 HDD RAW Image Install** is not compatible with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000) that have an external HDD due to space limitations (unless the stock drive is replaced with a 120+ GB drive). When **patching an existing PSBBN install**, Kloader might have compatibility issues with early model Japanese PS2 consoles (SCPH-10000, SCPH-15000 and SCPH-18000).
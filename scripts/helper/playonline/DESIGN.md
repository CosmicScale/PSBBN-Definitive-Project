# PlayOnline installer: design notes

Technical notes for maintainers. The user guide is the **Install PlayOnline**
section of the top-level [README](../../../README.md).

## Files

    PSBBN-Definitive-Patch.sh          one menu entry (option 7) and a check
                                       for the pycryptodome package
    scripts/PlayOnline-Installer.sh    the menu step, in the toolkit's idiom
    scripts/assets/lang/*.txt          the strings it prints
    scripts/assets/playonline/         the signed boot loader
    scripts/helper/playonline/         a self-contained Python package

Nothing of Sony's or Square Enix's is included. Every file the installer
writes comes from the user's own disc images at run time, and
`python3 -m playonline.shipcheck` checks that the repository stays that way.

## Why this is not a row in the game list

1. A PlayOnline disc does not hold the installed tree. It holds an install
   archive, in one of several Square Enix container formats, that their
   installer unpacks onto the drive.
2. The installed modules and boot container are normally encrypted against
   the 512-byte HDD ID of an official Sony drive. A third-party drive has no
   HDD ID, and official software powers the console off when it finds none.
3. The titles are launched by the PlayOnline Viewer from their own `PP.`
   partitions, each with a browser entry, a generated partition password and
   a record in the Viewer's registry.

## Division of labour with the toolkit

The package does not bring a partition editor to a PSBBN drive.

    partition creation, PFS format, file copy    the toolkit's pfsshell
    partition password, browser entry,           this package, at fixed
    __net record                                 offsets inside a partition
                                                 that already exists

The one exception is `__net` (below). `jail.py` finds the end of the APA
area so that nothing is ever carved into the exFAT region.

## What the menu step does

1. Finds the drive the way the Game Installer does, and refuses a drive
   without PSBBN or HOSDMenu on it.
2. Identifies the disc images in `games/POL` by their `SYSTEM.CNF`
   (`discs.py`) and asks for the Viewer region and the titles. A drive has
   one Viewer. `titles.LAUNCHES` records which partitions each Viewer can
   launch. `POL_REGION` and `POL_TITLES` answer both questions for a
   scripted run.
3. Stages each title from its disc (`stage.py`). Where two discs supply a
   title, the newer build is used.
4. Makes the staged tree bootable (`route.py`, see "Boot path"). A tree that
   cannot be prepared fails here, before anything is written.
5. Prepares `__net` (`netpart.py`).
6. For each title: `mkpart` through pfsshell, a generated `put` command list
   (`pfsput.py`), then the partition password and browser entry
   (`build.py --populated`), then a byte-for-byte verify that follows
   sub-partitions (`build.py --verify`).
7. Registers the titles in the Viewer's `pub/all/install.inf`
   (`installinf.py`) and, under the US Viewer, gives the Japan-only titles
   English names (`retitle.py`).

A title already on the drive is left alone. A second run offers to refresh
installed titles from the discs (`resync.py`), which adds and replaces files
and never removes one, and refreshes the loader in place when a newer
package ships a different one (`reloader.py`).

## Disc containers

| container | discs | reader |
|---|---|---|
| `_/N/M.K` archive | PlayOnline Viewer discs (`SLPS-20200`, `SCUS-97269`) | `archive.py` |
| `POL/INSTALL.DAT` + `INSTALL.INF` | Vana'diel Collection 2008, Dirge of Cerberus, Front Mission Online | `installdat.py` |
| `DATA/ROM*.DAT`, `MISC*.DAT`, `FILE.TXT` | FFXI on Vana'diel Collection 2008 | `ffxidata.py` |
| `KEL.DAT` | Dirge of Cerberus | `dirgedata.py` |
| `DVDIMAGE.DAT` | Front Mission Online | `fmodata.py` |

Each reader documents its format in its module docstring and verifies what
it extracts against the container's own checksums or manifest hashes.
FFXI's manifest hash is MD5 in base64 with a permuted alphabet.

Builds found on each disc:

| disc | Viewer | Tetra Master | Janhourou |
|---|---|---|---|
| PlayOnline Viewer (JP) | 1.05.00d | 20020314_0 | 20020314_0 |
| PlayOnline Viewer (US) | 1.11.00m | 20031021_0 | |
| Dirge of Cerberus (JP) | 1.14.03 | 20040908_0 | 20040727_2 |
| Vana'diel Collection 2008 (US) | 1.18.03b | 20040908_0 | |

A staged tree is not a flat image of the partition. For the Viewer,
`POL/install/PS2` is the partition root, `POL/Data/PS2` becomes `V` and
`POL/ps2drv` becomes `ps2drv`. The mapping is in `titles.py`. Three entries
are created, not copied: `installed` (zero bytes), `pub/all/install.inf`
(a copy of the disc's `default/pub/all/install.inf`) and `usr/all/`.

## Browser entries

The console's browser reads the attribute area at partition offset 0x1000,
not the file system. A partition with a valid file system and an empty
attribute area shows as "Corrupted Data".

Every disc ships complete `PS2ICON3D` attribute areas, one per title.
`prebuilt.py` finds them by magic. Square Enix's installer copies one to the
partition and changes only `VER = 0.00` to `VER = 1.00`. This installer does
the same, and the result is byte-identical to a partition their installer
made. `attrarea.py` can also build an area from parts, which is how FFXI,
Dirge and FMO get theirs, since those discs ship the pieces separately.

## Partition passwords

A title mounts its own partition with a password generated from the
partition name (`password.py`). Only `fpwd` is read, and `rpwd` stays zero.
pfsshell creates partitions with both fields zero, so the installer writes
`fpwd` after `mkpart`.

## `__net`

PlayOnline mounts `__net` with Sony's fixed passwords and keeps a 20-byte
per-drive record at raw offset 0x201800 inside it, outside the file system.
PSBBN creates `__net` with zero passwords, and a HOSDMenu drive may have
none.

`netpart.py` sets the passwords on an existing `__net`, or creates the
partition when it is missing. Creation is the only place this package
writes the partition table. It goes through `lib/polapaadd.py`, which
splits a free entry, keeps the APA list circular (hdl_dump rejects a table
that is not) and saves the sectors it changes before writing.

## Partition sizes and sub-partitions

Partitions are sized from the staged tree, preferring Square Enix's own
size where the tree fits. pfsshell's `mkpart` caps a main partition at the
drive's ceiling (2 GiB on the 128 GiB APA area PSBBN leaves) and lays the
remainder out as sub-partitions without reporting it. On a PSBBN drive FFXI
is therefore a 2 GiB main plus three 2 GiB subs, and one PFS volume spans
them. That is why files are written through pfsshell. The package's own PFS
writer, used for emulator images, lays out single partitions only. The
verifier reads the volume geometry from the superblock and follows each
entry's sub index. [SUBPARTITIONS.md](SUBPARTITIONS.md) specifies the
format.

## Boot path

Square Enix's `dnasload.elf` cannot be used: opening it needs MagicGate
keys, and its chain has no room for the HDD ID shim. The installer writes
its own loader under the same name, so the browser entry is unchanged.
Source and build notes are in [loader-src/README.md](loader-src/README.md).

`route prepare` takes the Viewer's boot ELF and IOP reboot image from the
disc's own boot container. A disc-form ("universal") container carries its
own bulk key, so no drive or console material is needed. Square Enix's
public keys are read from a disc boot executable (`SLPS_202.00` or
`SLUS_217.04`), so one of those two discs must be present. The ELF's DNAS
and drive-binding checks are patched (tables in `lib/ci_viewerpatch.py`,
one per supported Viewer build), and both payloads are written into the
unsigned payload block of the signed loader. The loader is signed once and
ships with the toolkit, so filling it needs no keys.

At boot the loader reboots the IOP from the Viewer's image, installs
`atadpatch.irx`, which answers the ATA driver's HDD ID call with the ID
this install minted, and enters the boot ELF. The ID is kept in
`games/POL/playonline.hddid` and is seeded from the drive's OPL partition
UUID, so it can be regenerated.

Modules are prepared one of two ways, decided by the Viewer build:

* **Plaintext**, for Viewer 1.13 and later (Vana'diel Collection 2008 and
  the Dirge disc). These builds carry Square Enix's own switch for loading
  plain `.pex` modules. Each module is unwrapped from its container and
  written beside its `.pex.enc`. Nothing on the partition is keyed to the
  drive.
* **Transcrypt**, for the 2002-2003 Viewer discs, which have no such
  switch. Each container is converted from disc form to installed form,
  keyed to the minted HDD ID.

FFXI's own loader does not read the plaintext switch, so its two root
containers are always keyed. `ffxioverlay.py` also reconciles a data file:
Vana'diel Collection 2008 pairs a 2004 boot module with 2007 data whose
`ROM/121/46.DAT` lacks a resource the module requires, so that entry is
copied from the disc's own `ROM/0/1.DAT`.


## The boot trace

A console that stops owns the screen, and the power cycle that follows clears
IOP RAM, so the only record that survives is one on the disk. The installer
writes `/trace.bin` into the Viewer partition, blank but for the magic in
`loader-src/poltrace.h`, and reads it back on every later run into the report
it leaves in the POL folder. `poltrace.py` is the reader.

The magic is the safety catch. A diagnostic loader reads the sector before its
first write and refuses unless the magic is already there, so a wrong location
costs one harmless read on a user's real drive and nothing else. Exactly one
sector is ever written, always the same one.

The PC side is finished and does nothing harmful on a loader that has no trace
in it: the record stays blank and the report says so, which is itself an answer
when a title returns to the browser having drawn nothing.

What the loader still needs, which is one build:

* take the trace sector from a fillable payload slot rather than the
  compile-time `-DTRACE_LBA`, since the sector differs per drive and the
  installer already fills slots (the boot ELF, the IOPRP image, the HDD ID)
  the same way;
* the installer then writes the LBA of `/trace.bin` into that slot when it
  prepares the Viewer, the way it writes the HDD ID.

Until then `build.sh` builds with `TRACE_LBA=0`, which disables the channel
completely, and `POL_LOADER` is the way to put a diagnostic build on a drive
without replacing the shipped one.

## The Viewer's registry

The Viewer decides whether a title is installed from `pub/all/install.inf`,
not from the partition table. `installinf.py` documents the format and adds
the records Square Enix's installers would have written.

## Emulator images

`python3 -m playonline.pcsx2image` builds a PCSX2 hard drive image from the
same discs, with an unsigned copy of the loader, since PCSX2 has no
MagicGate keys and cannot run the signed one.

## Environment variables

The menu step reads these. They are meant for scripted runs and
troubleshooting, and the README mentions only `POL_PATCH_HOST`.

| variable | effect |
|---|---|
| `POL_REGION=us` or `jp` | answers the Viewer region question |
| `POL_TITLES=key,key` | answers the title question; `python3 -m playonline titles` lists the keys |
| `POL_PATCH_HOST=host` | the update server written into the Viewer; `none` keeps the disc's names |
| `POL_ROUTE_MODE=plaintext` or `transcrypt` | the module mode, when the Viewer is already on the drive and its mode cannot be read |
| `POL_NO_ROUTE=1` | installs titles in disc form; they will not start |
| `POL_HDDID=file` | where the HDD ID file is kept |
| `POL_CONSOLE=us` or `jp` | answers the console region question, which picks the loader. This is the console's MagicGate zone, not the Viewer's region |
| `POL_LOADER=file` | a loader KELF to use instead of the shipped one, such as a `VERBOSE=1` build |
| `POL_RESYNC=1` or `0` | answers the refresh question on a second run |

## Checks

    cd scripts/helper
    python3 -m playonline status
    python3 -m playonline titles
    python3 -m playonline inspect /dev/sdX          # or a drive image
    python3 -m playonline.discs IMAGE [IMAGE ...]
    python3 -m playonline.selftest [DRIVE ...] [--disc IMAGE ...]
    python3 -m playonline.shipcheck

With no arguments `selftest` checks the package imports, the path
containment rules, the shipped loader (header version, payload slot
alignment, a fill and read-back round trip) and the per-build patch tables.
Given a drive it takes each PlayOnline browser entry apart, rebuilds it and
requires an identical result. Given discs it checks their containers.

## Containment

Square Enix's PS2 patch servers still answer, and the update they serve is
the end-of-service patch. Every other PlayOnline service of theirs is closed,
so the patch servers are the only way a console can be harmed by resolving
the `pol.com` names publicly.

`patchhost.py` closes that path when the Viewer is installed. The Viewer
takes its patch server from two places, and both are rewritten to name the
host in `$POL_PATCH_HOST`: `PATCH_SERVER_DOMAIN` in `data/utf/env.dat`, which
is the Viewer's own patch host, and the template `pc%03d%s.pol.com` in the
login module, which is each title's. The port already selects the title, so
one host serves them all. Both are data edits; no code is patched. The
default host is `play.openlobby.fyi`, and `none` keeps the disc's names.

This has two limits. The template is edited in the plain login module, so a
transcrypt-mode drive (the 2002-2003 Viewer discs) gets only the settings
edit. A Viewer update that replaces `env.dat` brings the original name
back unless the patch server it came from serves an edited copy.

Every other service is still found by name, so a console must resolve the
PlayOnline host names to a community server. See the Install PlayOnline
section of the README.

## Licence

GPL-3.0-or-later, following the toolkit.

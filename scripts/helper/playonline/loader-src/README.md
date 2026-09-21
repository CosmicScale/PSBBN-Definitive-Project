# The loader

`polbbnexec` is the program this step writes to a Viewer partition as
`dnasload.elf`, in place of Square Enix's. The signed build ships at
`scripts/assets/playonline/polbbnexec.kelf`; this directory is its source,
and `build.sh` reproduces it.

## Why the step has a loader of its own

Square Enix's `dnasload` decrypts the Viewer's boot container, reboots the
IOP from an image inside its own payload and hands over. Two things about
that chain do not fit a drive the PSBBN toolkit manages.

1. On a third-party drive the Viewer asks its ATA driver for the drive's
   Sony HDD ID, a generic drive has none, and the console powers off. The
   answer is a small IOP module, `atadpatch.irx`, that hooks the loader
   core and serves an HDD ID the installer minted. It has to be resident
   before the Viewer's own drivers register, and there is nowhere in
   Square Enix's chain to load it from: their IOP reboot image has no room
   and its length is signed.
2. Opening their `dnasload` at all needs the MagicGate keys from the
   user's console.

So the step boots its own loader. It carries the Viewer's boot ELF and IOP
reboot image, both taken from the user's own disc at install time, reboots
the IOP from that image, installs the shim with this install's HDD ID, and
enters the boot ELF. Nothing of Square Enix's is opened and no console keys
are needed.

## What is in it

| file | what it is |
| --- | --- |
| `polbbnexec.c` | the EE loader. `FORK_INSTALL` selects the build that ships: its payloads are reserved slots the installer fills |
| `atadpatch.c`, `atadhook.S`, `modhook.S`, `loadcore_stub.S`, `modload_stub.S` | the HDD ID shim: a loadcore hook that rewrites the ATA driver's export for `sceAtaGetSceId`, and a modload hook that substitutes the Viewer's own dev9/atad with `polnull` so its hdd binds to the preloaded ATA layer |
| `polnull.c` | the do-nothing module substituted for those two drivers |
| `poltracechk.c`, `atad_rw_stub.S`, `poltrace.h` | the ATA device probe the preloaded driver needs before it will move a sector |
| `build.sh` | builds every IOP module, embeds them, links the loader high at 0x01800000 and signs it |

The ATA layer under the Viewer is ps2sdk's `ps2dev9.irx` and `ps2atad.irx`,
taken from the SDK as built; they are not in this directory.

## How the installer uses the signed file

The install header is a struct found by the magic `POLBBNFORKHDR1`:
version, the two slot capacities and lengths, an address and value the
loader writes to low memory before the handover, `argv[0]`, the HDD ID to
serve, then the boot ELF slot and the IOP reboot image slot. `loader.py` in
the package reads and fills it. A KELF signed by `polkelf --encrypt` keeps
its content in one unsigned block after the first 32 bytes, so filling the
slots does not disturb the signatures, and a user needs neither a toolchain
nor console keys.

Both slots are on 64-byte boundaries, and the loader checks the address it
is about to hand to the IOP reboot. `SifIopRebootBuffer` passes the caller's
pointer to the EE DMA controller, which ignores the low bits of an address.
A misaligned reboot image reaches the IOP shifted, the IOP finds no module
directory in it and restarts on its ROM kernel, and the Viewer then loads
none of its modules, so the slots stay aligned.

## Building

    PS2DEV=/path/to/ps2dev PS2KEYS=/path/to/PS2KEYS.dat \
    TEMPLATE_KELF=/path/to/disc/POL/install/PS2/dnasload.elf bash build.sh

`PS2KEYS.dat` is read only to sign; the template lends the 32-byte KELF
header layout and none of its content. `DRIVERS=2` builds the variant that
installs the HDD ID hook alone and leaves the Viewer's own ATA layer in
place. `4` is the default.

The shipped loader draws nothing: between the console's browser and the
Viewer's logo the screen stays as it was, the way it does with Square
Enix's own loader. It turns the screen on only to say why it is stopping.
`VERBOSE=1` builds the one that narrates every step, addresses and module
results included, which is the build to put on a drive when a console
stops somewhere and you need to see how far it got. The pauses between the
steps are the same in both.

## Status

See "PlayOnline Status" in the README at the repository root.

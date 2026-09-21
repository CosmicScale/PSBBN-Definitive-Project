# APA sub-partitions and PFS

A PFS volume can span a main APA partition and up to 64 sub-partitions.
Square Enix's installer builds its large titles that way (its FFXI install
is a 1 GiB main with seven 1 GiB subs), and pfsshell's `mkpart` does the same
whenever the requested size exceeds the drive's largest partition size. On
the 128 GiB APA area of a PSBBN drive that ceiling is 2 GiB, so an 8 GiB
FFXI partition is a 2 GiB main with three 2 GiB subs.

This package does not create sub-partitions. pfsshell creates and fills
them. The package reads them, to verify an install and to compare an
installed title with its disc (`lib/polpfsread.py`, `lib/polfill.py`,
`lib/polnetdump.py`). This note records the layout those readers rely on.

## APA header fields

    0x048 u16 type          0x100 = PFS
    0x04A u16 flags         bit 0 set on a sub, clear on a main
    0x04C u32 nsub          on a main: how many subs it has
    0x058 u32 main          on a sub: the main partition's LBA
    0x05C u32 number        on a sub: its index, 1-based
    0x200 (u32 start, u32 length) x 64    on a main: the subs, in order

Subs need not be adjacent to their main or to each other. Use the main's
`subs[]` table for ordering.

## PFS

The superblock's sixth word is `num_subs`.

Every block reference on disc is a `blockinfo`: `u32 number`, `u16 subpart`,
`u16 count`. Zone numbering restarts in each sub, so a run is a
(zone, sub, count) triple and not a linear offset into the volume.
A directory entry carries the sub index of the inode it names.

Each sub has its own allocation bitmap, at sector `1 << scale` inside that
sub. The main's bitmap is at `(1 << scale) + 0x2000`, past the superblock.

The zone size varies by volume. Square Enix's installs use 65536 bytes for
FFXI, 8192 for Front Mission Online and 2048 for Dirge of Cerberus. A reader
must take it from the superblock.

## Reserved zones

From `pfsFormat` in ps2sdk (`iop/hdd/libpfs/src/superWrite.c`), which
formats the main and every sub in one loop:

    pfsFormatSub(blockDev, fd, i, i ? 1 : (0x2000 >> scale) + sb->log.count + 3,
                 scale, fragment)

and inside `pfsFormatSub`:

    sector = 1 << scale;
    count  = pfsGetBitmapSizeSectors(scale, size);
    if (reserved >= 2) sector += 0x2000;
    reserved += pfsGetBitmapSizeBlocks(scale, size);

| | reserved zones | bitmap at |
|---|---|---|
| main (sub 0) | `(0x2000 >> scale) + log.count + 3 + bitmapSizeBlocks` | `(1 << scale) + 0x2000` |
| any sub | `1 + bitmapSizeBlocks` | `1 << scale` |

The main's formula is what `lib/polpfs.py` implements when it formats a
single partition for an emulator image.

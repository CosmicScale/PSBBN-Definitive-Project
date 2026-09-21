/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * PlayOnline installer for the PSBBN Definitive Project
 * Copyright (C) 2026 PrettyOpenLobby
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
 * General Public License for details, <https://www.gnu.org/licenses/>.
 */
/* Import table for atad v1.03: sceAtaGetDevInfo (4) and sceAtaSectorIo (9).
 * ps2sdk calls ordinal 9 ata_device_sector_io; its older name is
 * ata_device_dma_transfer.
 *
 * Signature of ordinal 9, from the Viewer's own atad v2.04 (module vaddr
 * 0x1180): a0 = device, a1 = buf, a2 = lba, a3 = nsectors, and the fifth
 * argument at 16(sp) is the direction. The function selects ATA command 0x35
 * (WRITE DMA EXT) when it is 1 and 0x25 (READ DMA EXT) otherwise.
 *
 * This table is for poltracechk, which reads and writes a single sector
 * inside a file placed for that purpose. Ordinals 10, 11 and 12
 * (SetPassword, UnLock, EraseUnit) are deliberately not imported anywhere in
 * this directory: they alter a drive.
 */
	.set noreorder
	.section .text
	.align 2
	.word 0x41e00000
	.word 0
	.word 0x103
	.ascii "atad\0\0\0\0"

/* Ordinal 4, ata_get_devinfo, is imported because atad refuses every
 * transfer until the device has been probed. ata_device_sector_io reads
 * atad's devinfo table and returns an error while `exists` is zero, and the
 * table is filled by the probe this call triggers, which Sony's hdd normally
 * performs. A module talking to a freshly loaded atad with no hdd above it
 * has to do it itself. The probe is a read (ATA IDENTIFY) and nothing more. */
	.globl sceAtaGetDevInfo
	.ent sceAtaGetDevInfo
sceAtaGetDevInfo:
	jr $ra
	li $0, 4
	.end sceAtaGetDevInfo

	.globl sceAtaSectorIo
	.ent sceAtaSectorIo
sceAtaSectorIo:
	jr $ra
	li $0, 9
	.end sceAtaSectorIo

	.word 0
	.word 0

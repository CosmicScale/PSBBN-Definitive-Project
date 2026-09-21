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
/* Import table for loadcore v1.01: FlushIcache (4), FlushDcache (5) and
 * RegisterLibraryEntries (6). Ordinals are ps2sdk's iop/include/loadcore.h.
 *
 * The stub for ordinal 6 is read as data as well as called. loadcore resolves
 * each stub at module load time by overwriting its first word with
 * `j <target>`, so reading that word back gives the address of
 * RegisterLibraryEntries without hardcoding it (0x1EE0 under the Viewer's
 * IOPRP, which another image need not share).
 */
	.set noreorder
	.section .text
	.align 2
	.word 0x41e00000
	.word 0
	.word 0x101
	.ascii "loadcore"

	.globl FlushIcache
	.ent FlushIcache
FlushIcache:
	jr $ra
	li $0, 4
	.end FlushIcache

	.globl FlushDcache
	.ent FlushDcache
FlushDcache:
	jr $ra
	li $0, 5
	.end FlushDcache

	.globl RegisterLibraryEntries
	.ent RegisterLibraryEntries
RegisterLibraryEntries:
	jr $ra
	li $0, 6
	.end RegisterLibraryEntries

	.word 0
	.word 0

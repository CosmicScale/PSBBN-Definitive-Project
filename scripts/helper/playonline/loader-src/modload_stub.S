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
/* Import table for modload v1.04: LoadModuleBufferAddress (9). Ordinal is
 * ps2sdk's iop/include/modload.h.
 *
 * The function is never called. It is imported so that its resolved stub can
 * be read as data, like the loadcore stub: loadcore rewrites the first word
 * to `j <target>` at load time, which is how atadpatch finds the real
 * function without hardcoding an address.
 *
 * The hook is on module load because rejecting the Viewer's own dev9 and
 * atad at RegisterLibraryEntries is too late: by the time a module registers,
 * its _start has already reprogrammed the dev9 hardware, which breaks every
 * ps2atad transfer that follows. The load has to be intercepted before the
 * module runs, and every LoadModuleBuffer goes through
 * LoadModuleBufferAddress.
 */
	.set noreorder
	.section .text
	.align 2
	.word 0x41e00000
	.word 0
	.word 0x104
	.ascii "modload\0"

	.globl LoadModuleBufferAddress
	.ent LoadModuleBufferAddress
LoadModuleBufferAddress:
	jr $ra
	li $0, 9
	.end LoadModuleBufferAddress

	.word 0
	.word 0

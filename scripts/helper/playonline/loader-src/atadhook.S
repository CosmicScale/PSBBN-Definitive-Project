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
/* Trampoline installed over the first two instructions of loadcore's
 * RegisterLibraryEntries.
 *
 * Those two instructions are `addiu sp,sp,-40` and `sw s4,32(sp)` under the
 * Viewer's IOPRP. Neither is a branch and neither touches a0, so they can be
 * replayed here. The first branch in the function is at +0x1c.
 *
 * Entry is via `j`, so $ra still points at the original caller and a0 still
 * holds the export table being registered. The trampoline borrows the stack
 * (valid at function entry), calls patch_if_atad, restores, replays the two
 * displaced instructions and continues into the real function at +8.
 */
	.set noreorder
	.set noat
	.text
	.globl atad_hook
	.ent atad_hook
atad_hook:
	addiu	$sp, $sp, -32
	sw	$ra, 28($sp)
	sw	$a0, 24($sp)
	jal	patch_if_atad
	nop
	bnez	$v0, 1f			/* nonzero: reject this registration */
	nop
	lw	$ra, 28($sp)
	lw	$a0, 24($sp)
	addiu	$sp, $sp, 32

	addiu	$sp, $sp, -40		/* replayed: original instruction 0 */
	sw	$s4, 32($sp)		/* replayed: original instruction 1 */
	lui	$at, %hi(atad_cont)
	lw	$at, %lo(atad_cont)($at)
	nop				/* R3000 load delay slot: the instruction after a load
					 * still sees the old $at, so the jr must not follow
					 * the lw directly. PCSX2 does not model this; a real
					 * IOP jumps to the stale address without the nop. */
	jr	$at
	nop
	/* Reject: return RegisterLibraryEntries' failure code to the caller
	 * without entering the real function. Used for the Viewer's own dev9
	 * and atad when a preloaded pair is already registered, so that its hdd
	 * binds to that pair and one driver owns the ATA controller. */
1:	lw	$ra, 28($sp)
	lw	$a0, 24($sp)
	addiu	$sp, $sp, 32
	jr	$ra
	li	$v0, -1
	.end atad_hook

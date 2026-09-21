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
/* Trampoline installed over the first two instructions of modload's
 * LoadModuleBufferAddress (ordinal 9), which every LoadModuleBuffer goes
 * through.
 *
 * Under the Viewer's IOPRP those two instructions are `addiu sp,sp,-80` and
 * `li v0,2` (from the MODLOAD entry of ioprp.img). Neither is a branch and
 * neither touches a0 (the module image) or a1, so they can be replayed here;
 * the first branch in the function is at +0xc.
 *
 * Entry is via `j`, so $ra still points at the original caller and a0 still
 * holds the buffer. block_module(a0) reads the image's .iopmod name and
 * returns 0 to load the image as it is, or the address of a substitute
 * (polnull.irx) for the Viewer's own dev9 and atad. The substitute replaces
 * a0 and the real function loads it, so the Viewer's loader sees an ordinary
 * successful load and its positional argument passing stays in step.
 */
	.set noreorder
	.set noat
	.text
	.globl modload_hook
	.ent modload_hook
modload_hook:
	addiu	$sp, $sp, -32
	sw	$ra, 28($sp)
	sw	$a0, 24($sp)
	sw	$a1, 20($sp)
	sw	$a2, 16($sp)
	jal	block_module
	nop
	beqz	$v0, 1f			/* 0: load this image as it is */
	nop
	sw	$v0, 24($sp)		/* nonzero: the substitute image becomes a0 */
1:	lw	$ra, 28($sp)
	lw	$a0, 24($sp)
	lw	$a1, 20($sp)
	lw	$a2, 16($sp)
	addiu	$sp, $sp, 32

	addiu	$sp, $sp, -80		/* replayed: original instruction 0 */
	li	$v0, 2			/* replayed: original instruction 1 */
	lui	$at, %hi(modload_cont)
	lw	$at, %lo(modload_cont)($at)
	nop				/* R3000 load delay slot: the instruction after a load
					 * still sees the old $at, so the jr must not follow
					 * the lw directly. */
	jr	$at
	nop
	.end modload_hook

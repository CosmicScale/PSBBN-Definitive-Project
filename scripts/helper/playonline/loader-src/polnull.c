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
/* polnull.irx: a module that does nothing and stays resident.
 *
 * atadpatch's modload hook substitutes it for the Viewer's own dev9 and atad
 * images at load time. The Viewer's IOP loader (sqiopmem) loads its driver
 * set by position and hands each one its arguments in turn, so refusing two
 * loads outright puts that sequence out of step and hdd and pfs start with no
 * arguments (pfs then offers one mount unit, and the Viewer needs three).
 * With this module every load succeeds (id assigned, _start run, resident)
 * while the hardware is never touched and no library is registered, so the
 * Viewer's hdd binds to the preloaded ps2atad.
 */
#include <types.h>
#include <irx.h>

IRX_ID("polnull", 1, 0);

int _start(int argc, char **argv)
{
    (void)argc; (void)argv;
    return 0;                               /* MODULE_RESIDENT_END */
}

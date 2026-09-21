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
/* poltracechk.irx: probe the ATA device and, with a trace LBA, check the
 * telemetry channel with one sector round trip.
 *
 * The channel is a developer diagnostic that build.sh does not enable. It is
 * one sector of /trace.bin, a file a developer places in the POLVIEWER
 * partition, addressed by its absolute device LBA and compiled in as
 * -DTRACE_LBA. atadpatch.irx writes a running trace there while the Viewer
 * boots. This module checks the channel before anything depends on it:
 *
 *   1. Read the sector. This is harmless whatever TRACE_LBA is.
 *   2. Require POLTRACE_MAGIC in it. Only trace.bin carries that, so a wrong
 *      LBA stops here and nothing is written. atadpatch uses the same gate.
 *   3. Write a marker sector: the magic, this build's LBA, and 0xC0DE0001 in
 *      seq so a stale trace cannot be mistaken for a fresh one.
 *   4. Read it back and compare, so the result is a whole round trip and not
 *      only a return code.
 *
 * With TRACE_LBA 0, which is how build.sh builds it, steps 1 to 4 are skipped
 * and the module only calls sceAtaGetDevInfo: a freshly loaded atad refuses
 * every transfer until the device has been probed.
 *
 * `boots` is carried forward from the sector and incremented, so a marker
 * found on the disk afterwards shows which boot wrote it.
 *
 * Returns 0x40000000 | b0 | b1<<8 | b2<<16 | b3<<24
 *   b0 = read result + 128
 *   b1 = write result + 128 (255 if the write was refused)
 *   b2 = flags: 1 magic found, 2 written, 4 read back and identical
 *   b3 = the new boot count, low 6 bits
 */
#include <types.h>
#include <irx.h>
#include "poltrace.h"

IRX_ID("poltracechk", 1, 0);

#ifndef TRACE_LBA
#define TRACE_LBA 0
#endif

#define ATA_DIR_READ  0
#define ATA_DIR_WRITE 1

extern void *sceAtaGetDevInfo(int device);
extern int sceAtaSectorIo(int device, void *buf, unsigned int lba,
                          unsigned int nsectors, int dir);

static unsigned char rd[512] __attribute__((aligned(64)));
static poltrace_t    tr __attribute__((aligned(64)));

static int clamp(int r)
{
    if (r > 0) r = 0;
    if (r < -127) r = -127;
    return r + 128;
}

int _start(int argc, char **argv)
{
    unsigned int *w = (unsigned int *)rd;
    unsigned char *a, *b;
    unsigned int i, boots = 0;
    int rr, wr = -128, flags = 0;

    (void)argc; (void)argv;

    if (TRACE_LBA == 0) {
        /* The channel is off, but the device probe is still needed. A freshly
         * loaded atad refuses every transfer until something calls
         * sceAtaGetDevInfo, and under DRIVERS=4 this module is the only thing
         * between ps2atad and the handover that does. Without it the Viewer's
         * hdd binds to an atad that answers nothing, which looks like a drive
         * fault. */
        sceAtaGetDevInfo(0);
        return 0x40000000 | 128 | (255 << 8);      /* channel not configured */
    }

    for (i = 0; i < 512; i++) rd[i] = 0;
    rr = sceAtaSectorIo(0, rd, (unsigned int)TRACE_LBA, 1, ATA_DIR_READ);
    if (rr != 0) {
        /* A freshly loaded atad refuses transfers until the device is probed,
         * which hdd normally does. Under HDD-OSD's IOP that has already
         * happened, so the probe is only a fallback after a failed read. See
         * atad_rw_stub.S. */
        sceAtaGetDevInfo(0);
        rr = sceAtaSectorIo(0, rd, (unsigned int)TRACE_LBA, 1, ATA_DIR_READ);
    }
    if (rr != 0)
        return 0x40000000 | clamp(rr) | (255 << 8);

    if (w[0] != POLTRACE_MAGIC0 || w[1] != POLTRACE_MAGIC1)
        return 0x40000000 | clamp(rr) | (255 << 8);   /* refused: not the trace file */
    flags |= 1;
    boots = ((poltrace_t *)rd)->boots + 1;

    a = (unsigned char *)&tr;
    for (i = 0; i < sizeof(tr); i++) a[i] = 0;
    tr.magic0    = POLTRACE_MAGIC0;
    tr.magic1    = POLTRACE_MAGIC1;
    tr.ver       = POLTRACE_VER;
    tr.tail      = POLTRACE_MAGIC1;
    tr.trace_lba = (unsigned int)TRACE_LBA;
    tr.seq       = 0xC0DE0001u;
    tr.state     = TRST_CHECKED | TRST_ARMED;
    tr.boots     = boots;
    tr.ev[0].code = TREV_ARM;
    tr.ev[0].a    = (unsigned int)TRACE_LBA;
    tr.ev[0].b    = 0xC0DE0001u;
    tr.nevent     = 1;

    wr = sceAtaSectorIo(0, &tr, (unsigned int)TRACE_LBA, 1, ATA_DIR_WRITE);
    if (wr != 0)
        return 0x40000000 | clamp(rr) | (clamp(wr) << 8) | (flags << 16)
               | ((boots & 0x3f) << 24);
    flags |= 2;

    for (i = 0; i < 512; i++) rd[i] = 0;
    if (sceAtaSectorIo(0, rd, (unsigned int)TRACE_LBA, 1, ATA_DIR_READ) == 0) {
        b = (unsigned char *)&tr;
        for (i = 0; i < sizeof(tr); i++)
            if (rd[i] != b[i]) break;
        if (i == sizeof(tr))
            flags |= 4;
    }

    return 0x40000000 | clamp(rr) | (clamp(wr) << 8) | (flags << 16)
           | ((boots & 0x3f) << 24);
}

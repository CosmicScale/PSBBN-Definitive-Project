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
/* atadpatch.irx: serve an HDD ID to the PlayOnline Viewer on a drive that has
 * none, and optionally trace what the IOP does while the Viewer boots.
 *
 * Official Sony PS2 drives implement ATA_C_SCE_SECURITY_CONTROL (0x8e) with
 * ATA_SCE_IDENTIFY_DRIVE (0xec), which returns a 512-byte sector beginning
 * "Sony Computer Entertainment Inc.". A third-party drive refuses the
 * command. The Viewer's hdd imports atad ordinal 14, sceAtaGetSceId, and with
 * no HDD ID the Viewer powers the console off a few seconds in.
 *
 * No driver file is patched. The module hooks loadcore's
 * RegisterLibraryEntries, and when an atad registers, its export table is
 * edited before registration completes. Import stubs are resolved when a
 * module is loaded, so an hdd loaded afterwards binds to the replaced
 * entries. The hook target is found by reading this module's own resolved
 * import stub, whose first word loadcore rewrote to
 * `j <RegisterLibraryEntries>`; loadcore publishes no export table to scan.
 *
 * What is redirected:
 *   14 sceAtaGetSceId        -> returns the stored HDD ID
 *   11 sceAtaSecurityUnLock, 15 sceAtaSmartReturnStatus,
 *   16 sceAtaSmartSaveAttr   -> success, nothing sent to the drive
 *   10 sceAtaSecuritySetPassword, 12 sceAtaSecurityEraseUnit
 *                            -> logged and refused with an error; these alter
 *                               a drive and are never forwarded
 *    9 sceAtaSectorIo        -> with a trace LBA only, a pass-through wrapper
 *                               that logs and then calls the original
 *
 * When the loader preloads ps2sdk's dev9 and atad (DRIVERS=4), that atad is
 * the first to register and gets the treatment above. A later dev9 or atad,
 * the Viewer's own, is replaced with polnull.irx by a second hook on
 * modload's LoadModuleBufferAddress, and rejected at registration as a
 * fallback, so the Viewer's hdd binds to the preloaded pair.
 *
 * See poltrace.h for the trace sector and the rules around writing it. Built
 * with -DTRACE_LBA=0 (the default) nothing is ever written to the drive.
 */
#include <types.h>
#include <irx.h>
#include <loadcore.h>
#include "poltrace.h"

IRX_ID("atadpatch", 3, 1);

#ifndef TRACE_LBA
#define TRACE_LBA 0
#endif

extern unsigned char hddid_bin[];
extern unsigned int size_hddid_bin;
extern unsigned char polnull_irx[];          /* 16-byte aligned, see build.sh */
extern unsigned int size_polnull_irx;
extern void atad_hook(void);
extern void modload_hook(void);
extern int  LoadModuleBufferAddress(void *buf, unsigned int addr, int *ret);

unsigned int atad_cont;                     /* where the loadcore trampoline resumes */
unsigned int modload_cont;                  /* where the modload trampoline resumes  */

#define FPTR0        5      /* u32 index of fptrs[0] in an export table */
#define ORD_SECTORIO 9      /* atad: sceAtaSectorIo / DmaTransfer */
#define ORD_SETPASS  10     /* atad: sceAtaSecuritySetPassword, modifies a drive */
#define ORD_UNLOCK   11     /* atad: sceAtaSecurityUnLock  */
#define ORD_ERASE    12     /* atad: sceAtaSecurityEraseUnit, modifies a drive   */
#define ORD_GETSCEID 14     /* atad: sceAtaGetSceId        */
#define ORD_SMARTRET 15     /* atad: sceAtaSmartReturnStatus */
#define ORD_SMARTSAV 16     /* atad: sceAtaSmartSaveAttr     */

#define ATA_DIR_READ  0
#define ATA_DIR_WRITE 1

typedef int (*sector_io_t)(int device, void *buf, unsigned int lba,
                           unsigned int nsectors, int dir);

static poltrace_t    tr __attribute__((aligned(64)));
static unsigned char probe[512] __attribute__((aligned(64)));
static sector_io_t   orig_io;
static int           in_flush;              /* re-entrancy guard on the write */

/* Which thread may write the trace.
 *
 * Sony's atad is not re-entrant. Its import tables (the Viewer's atad v2.04)
 * carry loadcore, thbase, thevent, stdio, sysclib and dev9 but no thsemap, so
 * there is no lock inside it; hdd owns the device and serialises every call
 * from its own thread. A flush from any other thread could meet hdd halfway
 * through a transfer on shared ATA registers. Every write below therefore
 * happens inside a call hdd itself made: the ordinal 9 wrapper or one of the
 * replaced security ordinals.
 *
 * The cost is that a library registering with no disk I/O after it is
 * recorded in RAM but may never reach the disk.
 */

/* ---- the trace ------------------------------------------------------- */

static void ev_add(unsigned int code, unsigned int a, unsigned int b)
{
    unsigned int i = tr.nevent % POLTRACE_NEV;
    tr.ev[i].code = code;
    tr.ev[i].a    = a;
    tr.ev[i].b    = b;
    tr.nevent++;
}

/* Commit the sector. Refuses unless the target already carried the trace
 * magic, so a mistaken TRACE_LBA cannot overwrite anything (see poltrace.h). */
static void trace_flush(void)
{
    int r;

    if (TRACE_LBA == 0 || orig_io == 0)
        return;
    if ((tr.state & TRST_ARMED) == 0 || in_flush)
        return;
    in_flush = 1;
    tr.seq++;
    r = orig_io(0, &tr, (unsigned int)TRACE_LBA, 1, ATA_DIR_WRITE);
    if (r == 0) tr.writes_ok++; else tr.writes_err++;
    in_flush = 0;
}

/* Read the target sector and, if it carries the magic, allow writing.
 *
 * This cannot happen inside RegisterLibraryEntries: atad registers before it
 * initialises its hardware, and that is the wrong thread. Arming is lazy and
 * is attempted from every hooked entry, because hdd calls sceAtaGetSceId
 * during its own init, before it reads a sector. A failed read is retried up
 * to ARM_TRIES times. A missing magic means the LBA is not the trace file,
 * and that closes the channel for good. */
#define ARM_TRIES 8

static void trace_try_arm(void)
{
    unsigned int *w = (unsigned int *)probe;
    int r;

    if (tr.state & (TRST_ARMED | TRST_NOMAGIC))
        return;
    if (TRACE_LBA == 0 || orig_io == 0)
        return;
    if (tr.arm_tries >= ARM_TRIES)
        return;
    tr.arm_tries++;
    tr.state |= TRST_CHECKED;

    r = orig_io(0, probe, (unsigned int)TRACE_LBA, 1, ATA_DIR_READ);
    if (r != 0) {
        tr.state |= TRST_READERR;
        ev_add(TREV_ARM, (unsigned int)r, tr.state);
        return;
    }
    if (w[0] != POLTRACE_MAGIC0 || w[1] != POLTRACE_MAGIC1) {
        tr.state |= TRST_NOMAGIC;
        ev_add(TREV_ARM, w[0], w[1]);
        return;
    }
    tr.state &= ~TRST_READERR;
    tr.state |= TRST_ARMED;
    tr.boots = ((poltrace_t *)probe)->boots;   /* carry the boot count forward */
    ev_add(TREV_ARM, 0, tr.state);
}

/* ---- the redirected atad entries ------------------------------------- */

static int fake_get_sce_id(int device, void *data)
{
    unsigned char *d = (unsigned char *)data;
    unsigned int i, n = size_hddid_bin;
    (void)device;
    tr.ncall[ORD_GETSCEID]++;
    ev_add(TREV_FAKE, ORD_GETSCEID, tr.ncall[ORD_GETSCEID]);
    if (!d) return -1;
    if (n > 512) n = 512;
    for (i = 0; i < n; i++) d[i] = hddid_bin[i];
    for (; i < 512; i++) d[i] = 0;
    trace_try_arm();                        /* hdd's earliest call into this module */
    trace_flush();
    return 0;
}

/* Ordinals 10 and 12 alter a drive, so they are never forwarded and never
 * answered with success. Each call is logged and returns an error, which is
 * what a third-party drive itself says to Sony's 0x8e commands, and nothing
 * is sent to the disk. */
static int refuse_logged(int ord, int device)
{
    (void)device;
    tr.ncall[ord]++;
    ev_add(TREV_FAKE, (unsigned int)ord, tr.ncall[ord]);
    trace_try_arm();
    trace_flush();
    return -1;
}
static int refuse_setpass(int device, void *pw) { (void)pw; return refuse_logged(ORD_SETPASS, device); }
static int refuse_erase(int device)             { return refuse_logged(ORD_ERASE, device); }

/* Once sceAtaGetSceId answers, hdd carries on into the rest of the security
 * sequence (the ATA security unlock and the SMART calls), which a third-party
 * drive also refuses. This returns success without issuing any ATA command.
 * The drive is not locked, so reporting "unlocked" is accurate. */
static int fake_ok(int device)
{
    (void)device;
    tr.ncall[ORD_UNLOCK]++;                 /* one bucket for all three */
    ev_add(TREV_FAKE, ORD_UNLOCK, tr.ncall[ORD_UNLOCK]);
    trace_try_arm();
    trace_flush();
    return 0;
}

/* Pass-through for sceAtaSectorIo. The flush happens before the original
 * call, so an operation that never returns is still recorded. */
static int wrap_sector_io(int device, void *buf, unsigned int lba,
                          unsigned int nsectors, int dir)
{
    int r;

    if (in_flush)                           /* the trace's own write: never recurse */
        return orig_io(device, buf, lba, nsectors, dir);

    tr.ncall[ORD_SECTORIO]++;
    tr.last_lba = lba;
    tr.last_nsec_dir = (nsectors << 8) | (dir & 0xff);
    ev_add(TREV_IO, (ORD_SECTORIO << 24) | (nsectors & 0xffff), lba);

    trace_try_arm();
    trace_flush();

    r = orig_io(device, buf, lba, nsectors, dir);

    if (r != 0) {
        ev_add(TREV_IOERR, ORD_SECTORIO, (unsigned int)r);
        trace_flush();
    }
    return r;
}

/* ---- the loadcore hook ----------------------------------------------- */

/* Set once a dev9 and an atad have registered. With DRIVERS=4 the first of
 * each is the pair the loader preloaded, and a later one is the Viewer's. */
static int seen_dev9, seen_atad;

/* Called from the modload trampoline with the module image about to be
 * loaded. Returns 0 to load it as it is, or the address of a substitute image
 * that the trampoline loads in its place. Once a dev9 or atad has registered,
 * a later module of the same name gets polnull.irx, which stays resident,
 * registers nothing and touches no hardware. The Viewer's IOP loader
 * (sqiopmem) loads its drivers by position and passes their arguments in
 * turn, so it has to see an ordinary success; an outright refusal leaves hdd
 * and pfs with no arguments. */
int block_module(void *buf)
{
    unsigned char *d = (unsigned char *)buf;
    unsigned int phoff, phentsize, phnum, i, off;
    unsigned char *nm;

    if (!d || d[0] != 0x7f || d[1] != 'E' || d[2] != 'L' || d[3] != 'F')
        return 0;                           /* not an ELF: leave it alone */
    phoff     = *(unsigned int *)(d + 28);
    phentsize = *(unsigned short *)(d + 42);
    phnum     = *(unsigned short *)(d + 44);
    if (phentsize < 32 || phnum > 8)
        return 0;
    for (i = 0; i < phnum; i++) {
        unsigned char *ph = d + phoff + i * phentsize;
        if (*(unsigned int *)ph != 0x70000080u)   /* PT_MIPS_IRXHDR / .iopmod */
            continue;
        off = *(unsigned int *)(ph + 4);
        nm  = d + off + 26;                        /* u32 x6, u16 version, name */
        if (nm[0] == 'd' && nm[1] == 'e' && nm[2] == 'v' && nm[3] == '9' && nm[4] == 0 && seen_dev9) {
            ev_add(TREV_HBSTOP, 0x39766564u, 0x5B5);    /* "dev9" substituted */
            return (int)(unsigned int)polnull_irx;
        }
        if (nm[0] == 'a' && nm[1] == 't' && nm[2] == 'a' && nm[3] == 'd' && nm[4] == 0 && seen_atad) {
            ev_add(TREV_HBSTOP, 0x64617461u, 0x5B5);    /* "atad" substituted */
            return (int)(unsigned int)polnull_irx;
        }
        return 0;
    }
    return 0;
}

/* Called from the loadcore trampoline with the export table about to be
 * registered. Every library passes through here and is recorded, so the trace
 * lists the libraries that registered, in order. Returns 0 to let the
 * registration proceed, or nonzero to reject it; the trampoline then returns
 * -1 to the caller without entering RegisterLibraryEntries. The first atad
 * gets the replaced exports, and a second dev9 or atad is rejected. */
int patch_if_atad(void *lib)
{
    unsigned int *t = (unsigned int *)lib;
    unsigned char *nm;
    unsigned int i, n;
    int is_atad, is_dev9;

    if (!lib)
        return 0;
    nm = (unsigned char *)lib + 12;

    n = tr.nreg;
    if (n < POLTRACE_NREG) {
        for (i = 0; i < 8; i++) tr.reg[n].name[i] = nm[i];
        tr.reg[n].ver = t[2];
    }
    tr.nreg++;
    ev_add(TREV_REG, t[3], t[2]);           /* t[3] = the first 4 name bytes */

    is_atad = nm[0] == 'a' && nm[1] == 't' && nm[2] == 'a' && nm[3] == 'd' && nm[4] == 0;
    is_dev9 = nm[0] == 'd' && nm[1] == 'e' && nm[2] == 'v' && nm[3] == '9' && nm[4] == 0;

    if (is_dev9) {
        if (seen_dev9) {
            ev_add(TREV_HBSTOP, t[3], 0x0DE9);  /* rejected a second dev9 */
            return 1;
        }
        seen_dev9 = 1;
        return 0;
    }

    if (is_atad && t[FPTR0 + ORD_GETSCEID] != 0) {
        if (seen_atad) {
            ev_add(TREV_HBSTOP, t[3], 0x0A7AD); /* rejected a second atad */
            return 1;
        }
        seen_atad = 1;
        tr.state |= TRST_ATAD;
        orig_io = (sector_io_t)t[FPTR0 + ORD_SECTORIO];

        t[FPTR0 + ORD_GETSCEID] = (unsigned int)fake_get_sce_id;
        if (t[FPTR0 + ORD_UNLOCK])   t[FPTR0 + ORD_UNLOCK]   = (unsigned int)fake_ok;
        if (t[FPTR0 + ORD_SMARTRET]) t[FPTR0 + ORD_SMARTRET] = (unsigned int)fake_ok;
        if (t[FPTR0 + ORD_SMARTSAV]) t[FPTR0 + ORD_SMARTSAV] = (unsigned int)fake_ok;
        if (t[FPTR0 + ORD_SETPASS])  t[FPTR0 + ORD_SETPASS]  = (unsigned int)refuse_setpass;
        if (t[FPTR0 + ORD_ERASE])    t[FPTR0 + ORD_ERASE]    = (unsigned int)refuse_erase;
        if (TRACE_LBA != 0 && orig_io != 0)
            t[FPTR0 + ORD_SECTORIO] = (unsigned int)wrap_sector_io;
    }

    /* No flush here. This runs on whichever thread is loading a module, which
     * is not hdd's, and atad has no lock (see the note above ev_add). The
     * registration reaches the disk on hdd's next transfer. */
    return 0;
}

int _start(int argc, char **argv)
{
    volatile unsigned int *stub = (volatile unsigned int *)&RegisterLibraryEntries;
    volatile unsigned int *fn;
    unsigned int target, jump, i;
    unsigned char *z = (unsigned char *)&tr;

    (void)argc; (void)argv;

    for (i = 0; i < sizeof(tr); i++) z[i] = 0;
    tr.magic0    = POLTRACE_MAGIC0;
    tr.magic1    = POLTRACE_MAGIC1;
    tr.ver       = POLTRACE_VER;
    tr.tail      = POLTRACE_MAGIC1;
    tr.trace_lba = (unsigned int)TRACE_LBA;

    /* loadcore rewrote the stub's first word to `j <target>` (opcode 2) */
    if ((stub[0] >> 26) != 2)
        return 1;                       /* not resolved as expected */
    target = (stub[0] & 0x03FFFFFF) << 2;
    if (target < 0x1000 || target > 0x001FFF00)
        return 2;                       /* implausible address, do not poke it */

    fn = (volatile unsigned int *)target;
    atad_cont = target + 8;

    jump = (2u << 26) | (((unsigned int)atad_hook >> 2) & 0x03FFFFFF);
    fn[0] = jump;
    fn[1] = 0;                          /* nop in the delay slot */

    tr.state |= TRST_HOOKED;
    ev_add(TREV_HOOK, (unsigned int)TRACE_LBA, target);

    /* Second hook: modload's LoadModuleBufferAddress, found the same way. Its
     * first two instructions under the Viewer's IOPRP are `addiu sp,sp,-80`
     * and `li v0,2`; neither branches nor reads a0, and modhook.S replays
     * them. If the stub is not a resolved jump the hook is skipped, and the
     * rejection at registration above still applies. */
    stub = (volatile unsigned int *)&LoadModuleBufferAddress;
    if ((stub[0] >> 26) == 2) {
        target = (stub[0] & 0x03FFFFFF) << 2;
        if (target >= 0x1000 && target <= 0x001FFF00) {
            fn = (volatile unsigned int *)target;
            modload_cont = target + 8;
            jump = (2u << 26) | (((unsigned int)modload_hook >> 2) & 0x03FFFFFF);
            fn[0] = jump;
            fn[1] = 0;
            ev_add(TREV_HOOK, 2, target);
        }
    }

    FlushDcache();
    FlushIcache();
    return 0;                           /* MODULE_RESIDENT_END */
}

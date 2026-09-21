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
/* poltrace.h: the 512-byte telemetry sector the IOP modules can write to the
 * drive, and the rules that keep that write safe.
 *
 * Once the Viewer has been entered it owns the screen, and a hang needs a
 * power cycle, which clears IOP RAM. The disk is the only medium that
 * survives, so a diagnostic build records its progress in one sector.
 *
 * The write goes to a user's real drive, where a stray sector can destroy an
 * install, so:
 *
 *   - the target LBA is compiled in (-DTRACE_LBA=n) and is the first sector
 *     of /trace.bin, a file placed in the POLVIEWER partition for this;
 *   - before the first write the sector is read and must already contain
 *     POLTRACE_MAGIC, which only trace.bin carries. Without the magic nothing
 *     is written, so a wrong LBA costs one harmless read;
 *   - exactly one sector is ever written, and always the same one;
 *   - TRACE_LBA 0 disables the channel completely. build.sh builds with 0.
 *
 * Everything is little-endian u32 and the whole struct is exactly 512 bytes,
 * so one sceAtaSectorIo(0, buf, TRACE_LBA, 1, ATA_DIR_WRITE) commits it.
 */
#ifndef POLTRACE_H
#define POLTRACE_H

#define POLTRACE_MAGIC0 0x544c4f50u          /* "POLT" */
#define POLTRACE_MAGIC1 0x45434152u          /* "RACE" */
#define POLTRACE_VER    0x00020000u

#define POLTRACE_NORD   20                   /* atad exports 19 functions */
#define POLTRACE_NREG   16                   /* libraries whose names are kept */
#define POLTRACE_NEV    15                   /* ring of most recent events */

/* state bits */
#define TRST_CHECKED    0x0001               /* the magic read has happened */
#define TRST_ARMED      0x0002               /* magic was there; writing allowed */
#define TRST_ATAD       0x0004               /* an atad registered and was patched */
#define TRST_HOOKED     0x0008               /* the loadcore trampoline is in */
#define TRST_NOMAGIC    0x0010               /* read worked, magic absent - refused */
#define TRST_READERR    0x0020               /* the probe read itself failed */
#define TRST_HEARTBEAT  0x0040               /* reserved; no module here sets it  */
#define TRST_HBSTOP     0x0080               /* reserved; no module here sets it  */

/* event codes */
#define TREV_HOOK       1                    /* a = TRACE_LBA                     */
#define TREV_REG        2                    /* a = name[0..3], b = version       */
#define TREV_ARM        3                    /* a = read result, b = state        */
#define TREV_IO         4                    /* a = (ord<<24)|nsectors, b = lba   */
#define TREV_IOERR      5                    /* a = ordinal, b = result           */
#define TREV_FAKE       6                    /* a = ordinal, b = call count       */
#define TREV_TICK       7                    /* reserved; no module here logs it  */
#define TREV_HBSTOP     8                    /* a = name[0..3] of a second dev9 or
                                              * atad, b = 0x5B5 when its image
                                              * was substituted at load, 0x0DE9
                                              * (dev9) or 0x0A7AD (atad) when its
                                              * registration was rejected */
#define TREV_STAGE      9                    /* reserved; no module here logs it  */

typedef struct {
    unsigned int  magic0;                    /* 0x000 "POLT" */
    unsigned int  magic1;                    /* 0x004 "RACE" */
    unsigned int  ver;                       /* 0x008 */
    unsigned int  seq;                       /* 0x00c bumped on every flush */
    unsigned int  ncall[POLTRACE_NORD];      /* 0x010 calls per atad ordinal */
    unsigned int  nreg;                      /* 0x060 libraries registered */
    unsigned int  nevent;                    /* 0x064 events ever recorded */
    unsigned int  last_lba;                  /* 0x068 last ordinal-9 LBA */
    unsigned int  last_nsec_dir;             /* 0x06c (nsectors<<8)|dir */
    unsigned int  writes_ok;                 /* 0x070 trace flushes that worked */
    unsigned int  writes_err;                /* 0x074 ... and that did not */
    unsigned int  state;                     /* 0x078 TRST_* */
    unsigned int  trace_lba;                 /* 0x07c the LBA this build was given */
    struct {
        unsigned char name[8];
        unsigned int  ver;
    } reg[POLTRACE_NREG];                    /* 0x080 .. 0x140 */
    struct {
        unsigned int code;
        unsigned int a;
        unsigned int b;
    } ev[POLTRACE_NEV];                      /* 0x140 .. 0x1f4 */
    unsigned int  tail;                      /* 0x1f4 == POLTRACE_MAGIC1 */
    unsigned int  boots;                     /* 0x1f8 bumped by poltracechk */
    unsigned int  arm_tries;                 /* 0x1fc reads spent trying to arm */
} poltrace_t;

/* `boots` is the one field that survives a boot. poltracechk reads the
 * sector, adds one to the old count and writes it back, so a marker on the
 * disk shows which boot wrote it; a count that did not move means that boot
 * never reached the check. atadpatch copies the count out of the sector it
 * reads while arming, so a trace carries the same number. */

#endif /* POLTRACE_H */

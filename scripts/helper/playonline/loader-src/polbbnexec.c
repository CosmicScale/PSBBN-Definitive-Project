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
/* polbbnexec: the loader written to the PlayOnline Viewer partition as
 * dnasload.elf, in place of Square Enix's.
 *
 * It does the retail dnasload's job without any of the crypto: reboot the IOP
 * from the Viewer's own image, install the HDD ID shim, copy the plaintext
 * boot ELF into place and enter it with ExecPS2.
 *
 * The IOP reboot is required. HDD-OSD's pfs offers two mount units and the
 * Viewer uses three (pfs0 for the Japanese IME partition, pfs1 for the title
 * partition, pfs2 for its own), and HDD-OSD's resident hdd and pfs would
 * collide with the newer pair the Viewer loads for itself. It has to be
 * SifIopRebootBuffer with the Viewer's IOPRP image; a plain SifIopReset does
 * not bring the drive up.
 *
 * Nothing is mounted here. The Viewer's boot ELF mounts its own partition on
 * pfs2:. argv[0] has the `hdd0:<partition>:pfs:/<file>` shape the retail
 * dnasload builds for its child.
 *
 * DRIVERS selects what stays resident under the Viewer (see main). ps2sdk's
 * ps2dev9 (exports dev9 1.09) and ps2atad (exports atad 1.03) can sit under
 * Sony's hdd (imports dev9 1.02, atad 1.01) because loadcore only needs an
 * equal major version and an imported minor no greater than the exported one.
 *
 * Linked at 0x01800000 so that copying the Viewer's segments (0x00100000,
 * 0x001d8000, 0x00800000) cannot overwrite this code.
 *
 * The FORK_ prefix on the macros and the POLBBNFORKHDR1 magic are historical
 * names. The installer finds the header by that magic, so they are kept.
 */
#include <tamtypes.h>
#include <kernel.h>
#include <sifrpc.h>
#include <sifdma.h>
#include <iopcontrol.h>
#include <iopcontrol_special.h>
#include <loadfile.h>
#include <sbv_patches.h>
#include <fileio.h>
#include <debug.h>
#include <string.h>
#include <stdio.h>

/* Developer diagnostic: the sector atadpatch writes a trace to. build.sh
 * always passes -DTRACE_LBA=0, which turns the trace off. */
#ifndef TRACE_LBA
#define TRACE_LBA 0
#endif

extern unsigned char ps2dev9_irx[];      extern unsigned int size_ps2dev9_irx;
extern unsigned char ps2atad_irx[];      extern unsigned int size_ps2atad_irx;
extern unsigned char atadpatch_irx[];    extern unsigned int size_atadpatch_irx;
extern unsigned char poltracechk_irx[];  extern unsigned int size_poltracechk_irx;

#ifndef FORK_INSTALL
#error "build with -DFORK_INSTALL, as build.sh does"
#endif

/* ------------------------------------------------------------------------
 * The install header.
 *
 * The loader is signed once and shipped. It does not link in one
 * title's boot ELF, which differs per region and per Viewer version. It
 * reserves slots that the installer fills with plain byte patches:
 *
 *   - the boot ELF, into the elf slot, with its length in the header
 *   - the IOP reboot image, into the ioprp slot, likewise
 *   - the HDD ID the shim serves, which has to be the block the partition's
 *     modules were transcrypted against
 *
 * That is possible because a KELF built by polkelf --encrypt carries its
 * content in one unsigned, unencrypted block: only the first 32 bytes are
 * signed and encrypted, and the header, bit table and root signatures cover
 * neither the content nor its length. An install therefore needs no
 * toolchain and no console keys.
 *
 * The installer finds the header by its magic, so a rebuild that moves it
 * does not break the installer.
 * ------------------------------------------------------------------------ */
#ifndef FORK_ELF_SLOT
#define FORK_ELF_SLOT   2097152      /* the US Viewer's boot ELF is 1,909,516 */
#endif
#ifndef FORK_IOPRP_SLOT
#define FORK_IOPRP_SLOT  262144      /* the US container's IOPRP is 250,425 */
#endif

/* The payload slots are members of the header, so the installer needs one
 * thing, the offset of the magic; everything else is a fixed distance from
 * it. Slots held separately would each need a marker of their own, and a
 * marker can collide with data.
 *
 * Both slots are aligned to 64 bytes, and must stay that way.
 * SifIopRebootBuffer hands the caller's pointer straight to the EE DMA
 * controller (through SifSetDma), which moves 16-byte quadwords and ignores
 * the low four bits of the source address. An image that starts off a
 * quadword boundary reaches the IOP shifted by those bytes, UDNL finds no
 * romdir at the front of it, and the reboot quietly comes back with the ROM's
 * own module set. Every later step of this loader still succeeds on that IOP
 * (SifInitRpc, the buffer module loads, ExecPS2); only the Viewer then fails
 * to load a single IOP module.
 *
 * With the alignment the slots sit at +768 and +768+elf_capacity from the
 * magic (header version 3).
 * fork_check_install also checks the address before the reboot uses it. */
typedef struct {
    char          magic[16];         /* POLBBNFORKHDR1 */
    unsigned int  version;
    unsigned int  elf_capacity;
    unsigned int  elf_len;           /* 0 = the installer wrote nothing */
    unsigned int  ioprp_capacity;
    unsigned int  ioprp_len;
    /* A word written to low memory immediately before ExecPS2. Square Enix's
     * US dnasload does the same (`[0x0009F000] = s0`, at 0x00224cb8) and
     * leaves 0x003daec0 there. Both numbers are carried in the header because
     * they were read off one build of dnasload and another build may differ. */
    unsigned int  handover_addr;     /* 0 = write nothing */
    unsigned int  handover_value;
    char          argv0[192];        /* hdd0:PP.<id>:pfs:/<file> */
    unsigned char hddid[512];        /* what the shim serves */
    unsigned char elf[FORK_ELF_SLOT]     __attribute__((aligned(64)));
    unsigned char ioprp[FORK_IOPRP_SLOT] __attribute__((aligned(64)));
} fork_install_t;

#define FORK_HDR_VERSION 3

/* Given non-zero initialisers so that the linker places it in .data, inside
 * the file the installer patches. A zeroed object would go to .bss. */
fork_install_t fork_install __attribute__((aligned(64))) = {
    "POLBBNFORKHDR1", FORK_HDR_VERSION,
    FORK_ELF_SLOT, 0, FORK_IOPRP_SLOT, 0,
    0x0009F000, 0x003DAEC0,
    "hdd0:PP.SCUS-97269.1000.POLVIEWER:pfs:/SCUS-97269",
    { 0 }, { 1 }, { 1 }
};

/* Where the IOP reboot image is DMA'd from: the slot itself when it is
 * quadword aligned, otherwise an aligned copy made by fork_check_install. */
static unsigned char  fork_ioprp_bounce[FORK_IOPRP_SLOT] __attribute__((aligned(64)));
static unsigned char *fork_ioprp = fork_install.ioprp;

#define VIEWER_PATH            fork_install.argv0
#define polboot_elf            fork_install.elf
#define size_polboot_elf       fork_install.elf_len
#define ioprp_viewer_img       fork_ioprp
#define size_ioprp_viewer_img  fork_install.ioprp_len

static char hddarg[] = "hdd\0" "-o\0" "8\0" "-n\0" "20";
static char pfsarg[] = "pfs\0" "-m\0" "4\0" "-o\0" "10";

static char line[256];
/* Silent unless built with -DFORK_VERBOSE (build.sh: VERBOSE=1), like Square
 * Enix's dnasload. By default the screen is never initialised and SAY prints
 * nothing. The pauses after the module loads are the same in both builds, so
 * the timing does not depend on the setting. STOP always turns the screen on
 * and prints the reason. */
#ifdef FORK_VERBOSE
static int say_on = 1;
#else
static int say_on = 0;
#endif
static void screen_on(void)
{
    if (!say_on) {
        init_scr();
        say_on = 1;
    }
}
#define SAY(...) do { if (say_on) { sprintf(line, __VA_ARGS__); scr_printf("%s\n", line); } } while (0)
#define STOP(...) do { screen_on(); scr_printf("\n\n polbbnexec -- PlayOnline loader\n\n"); \
                       sprintf(line, __VA_ARGS__); scr_printf("%s\n", line); SleepThread(); } while (0)

static void wait_secs(int secs)
{
    int s; unsigned int k;
    for (s = 0; s < secs; s++)
        for (k = 0; k < 250000000u; k++) __asm__ __volatile__("nop");
}

static void load_mod(const char *nm, unsigned char *p, unsigned int sz,
                     int arglen, const char *args)
{
    int res = -12345;
    int id = SifExecModuleBuffer(p, sz, arglen, args, &res);
    SAY("  %-7s id=%-4d res=%-3d %s", nm, id, res,
        id < 0 ? "LOAD FAILED" : (res == 0 ? "resident" : "not resident"));
}

#define SCE_MAGIC "Sony Computer Entertainment Inc."

/* Stop on a header the installer did not fill in completely. Each case would
 * otherwise show up as something harder to diagnose: a blank slot reads as a
 * corrupt ELF, and a wrong HDD ID does not fail here at all (the modules
 * decrypt to noise much later). */
static void fork_check_install(void)
{
    SAY("install: hdr v%u, elf %u/%u B, ioprp %u/%u B",
        fork_install.version,
        fork_install.elf_len, fork_install.elf_capacity,
        fork_install.ioprp_len, fork_install.ioprp_capacity);
    SAY("  argv0 %s", fork_install.argv0);
    SAY("  slots: elf 0x%08x, ioprp 0x%08x",
        (unsigned)fork_install.elf, (unsigned)fork_install.ioprp);

    const char *why;
    if (fork_install.elf_len == 0 || fork_install.elf_len > FORK_ELF_SLOT)
        why = "NO BOOT ELF in this KELF -- the installer wrote none.";
    else if (fork_install.ioprp_len == 0 ||
             fork_install.ioprp_len > FORK_IOPRP_SLOT)
        why = "NO IOPRP in this KELF -- the installer wrote none.";
    else if (memcmp(fork_install.hddid, SCE_MAGIC, 32) != 0)
        why = "NO HDD ID in this KELF -- the installer wrote none.";
    else if (memcmp(fork_install.ioprp, "RESET", 5) != 0)
        why = "the IOPRP slot does not start RESET -- not a reboot image.";
    else {
        /* The address SifIopRebootBuffer will DMA from; see fork_install_t. */
        if (((unsigned)fork_install.ioprp & 15) != 0) {
            SAY("  ioprp slot is NOT quadword aligned; using an aligned copy");
            memcpy(fork_ioprp_bounce, fork_install.ioprp, fork_install.ioprp_len);
            fork_ioprp = fork_ioprp_bounce;
        }
        return;
    }

    STOP("  %s\n  stopping: this KELF was never filled in.", why);
}

/* Write this install's HDD ID into the shim image before it is loaded.
 *
 * atadpatch is built with a placeholder block; the one that matters is the
 * block the partition's modules were transcrypted against. It is located by
 * searching the image for Sony's magic, so nothing here depends on a link
 * map. Not finding it stops the boot. */
static void fork_set_shim_id(void)
{
    unsigned int i, j;
    for (i = 0; i + 512 <= size_atadpatch_irx; i++) {
        if (memcmp(atadpatch_irx + i, SCE_MAGIC, 32) != 0) continue;
        for (j = 0; j < 512; j++)
            atadpatch_irx[i + j] = fork_install.hddid[j];
        SAY("  shim: HDD ID written at +%u", i);
        return;
    }
    STOP("  shim: no HDD ID block inside atadpatch -- stopping.");
}

/* ---- the entry marker (ENTRY_MARKER and ENTRY_JUMP) --------------------
 *
 * Developer diagnostics that build.sh does not build. With either macro the
 * handover enters viewer_tramp in place of the Viewer's entry point. The
 * trampoline records that it ran and then jumps to the real entry with the
 * stack and arguments it was given. This loader sits at 0x01800000, clear of
 * every Viewer segment, and ExecPS2 does not clear memory, so the trampoline
 * is still in place when it is entered.
 */
static u32   real_entry;
static char *tramp_argv[1];

/* Stage reporting.
 *
 * Progress is reported through the SIF main-to-sub flag register (MSFLAG,
 * 0x1000F220 on the EE), which the IOP reads with sceSifGetMSFlag. It
 * involves no memory, DMA or RPC, so nothing ExecPS2 tears down is in its
 * path. The register is written with SifSetReg, a kernel syscall that still
 * works after ExecPS2. The accumulated mask is written each time, so it does
 * not matter whether the register sets bits or replaces them.
 *
 * MSCOM is not used as a second channel: the IOP's sifcmd may read it to
 * find the EE's command buffer. */
static u32 stage_mask;

/* Stage n maps to bit n-1, except that bits 16..18 belong to the SIF
 * protocol and are stepped over: 1..16 -> bits 0..15, 17..21 -> bits 19..23,
 * 22..24 -> bits 29..31. Stages 1..5 also raise bit 23+n as a second copy
 * (see stage_set). This loader raises stages 1..5 only. */
static u32 stage_bit(int n)
{
    if (n <= 16) return 1u << (n - 1);
    if (n <= 21) return 1u << (n + 2);
    return 1u << (n + 7);
}

static void stage_set(int n)
{
    stage_mask |= stage_bit(n);
    if (n <= 5)
        stage_mask |= 1u << (23 + n);
    SifSetReg(SIF_REG_MSFLAG, (int)stage_mask);
}

/* The handover stages. Each step between the `exec:` line and the
 * trampoline's first instruction raises its bit before the next step is
 * taken, so the last bit set shows where a boot stopped. */
#define STAGE_EXEC_LINE   1     /* printed `exec:`, the last print            */
#define STAGE_WAITED      2     /* entered the handover block                 */
#define STAGE_FLUSHED     3     /* FlushCache(0)/FlushCache(2) returned       */
#define STAGE_RPC_DOWN    4     /* SifExitRpc returned, entering the handover */
#define STAGE_TRAMP       5     /* the trampoline is running = entry reached  */

static u8 jump_stack[64 * 1024] __attribute__((aligned(16)));

/* Two standalone MSFLAG bits the trampoline raises together, immediately
 * before it records the jump target and jumps. */
#define TRAMP_FC0_BIT (1u << 30)
#define TRAMP_FC2_BIT (1u << 31)

static void viewer_tramp(void)
{
    register u32 sp asm("sp");
    u32 saved_sp = sp;

    stage_set(STAGE_TRAMP);

    /* No screen output and no delay loop from here on: ExecPS2 has just
     * re-initialised INTC, the timers and the GS. The IOP side samples MSFLAG
     * on its own timer, so nothing has to wait for it. Only two kernel
     * syscalls and the jump follow. */

    stage_mask |= TRAMP_FC0_BIT | TRAMP_FC2_BIT;
    SifSetReg(SIF_REG_MSFLAG, (int)stage_mask);

    /* Record the jump target in MAINADDR, so that a corrupted real_entry is
     * visible from the IOP side. */
    SifSetReg(SIF_REG_MAINADDR, (int)real_entry);

    __asm__ __volatile__(
        "move $sp, %0\n\t"
        "li   $a0, 1\n\t"
        "move $a1, %1\n\t"
        "jr   %2\n\t"
        "nop\n\t"
        :: "r"(saved_sp), "r"(tramp_argv), "r"(real_entry)
        : "a0", "a1");
}

typedef struct {
    u8  ident[16]; u16 type; u16 machine; u32 version; u32 entry;
    u32 phoff; u32 shoff; u32 flags; u16 ehsize; u16 phentsize; u16 phnum;
    u16 shentsize; u16 shnum; u16 shstrndx;
} elf_hdr_t;
typedef struct {
    u32 type; u32 offset; u32 vaddr; u32 paddr; u32 filesz; u32 memsz; u32 flags; u32 align;
} elf_phdr_t;

int main(int argc, char *argv[])
{
    static elf_hdr_t eh;
    static char *boot_argv[1];
    elf_hdr_t *ehp;
    int i, n, res = -12345;

    SifInitRpc(0);
    if (say_on)
        init_scr();
    /* The banner version identifies the build on screen, so a stale KELF on
     * the drive is obvious at a glance. */
    if (say_on)
        scr_printf("\n\n polbbnexec 1.7 -- PlayOnline plaintext loader\n\n");

    SAY("trace LBA = %u %s", (unsigned)TRACE_LBA,
        TRACE_LBA ? "(atadpatch will log to /trace.bin)" : "(no telemetry)");
    SAY("argc=%d", argc);

    fork_check_install();

    /* ---- check the trace sector (developer diagnostic) -----------------
     *
     * Never runs in a build.sh build, which passes -DTRACE_LBA=0. It runs
     * before the IOP reboot, while HDD-OSD's drivers are still resident, and
     * the reboot below discards whatever it loads. */
    if (TRACE_LBA) {
        int rd, wr, flags, boots;
        SAY("channel: checking /trace.bin through the running IOP ...");
        sbv_patch_enable_lmb();
        sbv_patch_disable_prefix_check();
        res = -12345;
        i = SifExecModuleBuffer(poltracechk_irx, size_poltracechk_irx, 0, NULL, &res);
        if (i < 0) {
            SAY("channel: poltracechk did not load (%d)", i);
        } else if ((res & 0x40000000) == 0) {
            SAY("channel: poltracechk returned %d, not a result word", res);
        } else {
            rd    = (res & 0xff) - 128;
            wr    = ((res >> 8) & 0xff) - 128;
            flags = (res >> 16) & 0xff;
            boots = (res >> 24) & 0x3f;
            SAY("channel: read %d, magic %s, write %d, readback %s, boot #%d",
                rd, (flags & 1) ? "FOUND" : "ABSENT", wr,
                (flags & 4) ? "same" : "differs", boots);
            if ((flags & 7) != 7)
                SAY("  -> the trace below will NOT be written. Fix this first.");
        }
        SAY(" ");
    }
    for (i = 0; i < argc && i < 2; i++)
        SAY("  argv[%d]=\"%s\"", i, argv[i] ? argv[i] : "(null)");

    /* ---- reboot the IOP from the Viewer's own image ------------------ */
    SAY(" ");
    SAY("IOP reboot (partition ioprp.img, %u B) ...", size_ioprp_viewer_img);
    fioExit();
    SifLoadFileExit();
    SifExitRpc();
    i = SifIopRebootBuffer(ioprp_viewer_img, size_ioprp_viewer_img);
    while (!SifIopSync()) ;
    SifInitRpc(0);
    SifLoadFileInit();
    fioInit();
    sbv_patch_enable_lmb();              /* the patch does not survive an IOP reset */
    sbv_patch_disable_prefix_check();
    SAY("  reboot -> %d", i);

    /* What stays resident under the Viewer.
     *
     * After the handover the Viewer loads its own dev9, atad, hdd (version
     * 0203) and pfs (0201) and mounts its partition on pfs2:. This loader
     * therefore never loads an hdd or pfs: two hdd drivers claiming the same
     * ioman device names crash the IOP, which is also why HDD-OSD's resident
     * pair has to be cleared out by the reboot above. The retail dnasload
     * tears its filesystem drivers down before handing over for the same
     * reason. The boot ELF is embedded, so this loader needs no file I/O.
     *
     * DRIVERS selects the rest:
     *   2  the HDD ID shim alone (this file's default)
     *   4  the shim, ps2sdk's ATA layer, and the Viewer's own dev9 and atad
     *      substituted (build.sh's default)
     */
#ifndef DRIVERS
#define DRIVERS 2
#endif
    fork_set_shim_id();
#if DRIVERS == 2
    /* The Viewer brings its whole driver stack. One small module hooks
     * loadcore's RegisterLibraryEntries, and when the Viewer's atad
     * registers, export 14 (sceAtaGetSceId) is redirected to a function that
     * returns a valid HDD ID. A drive that refuses Sony's ATA command 0x8e
     * otherwise makes the Viewer power the console off a few seconds in. */
    load_mod("atadfix", atadpatch_irx, size_atadpatch_irx, 0, NULL);
    wait_secs(1);
#elif DRIVERS == 4
    /* Replace the Viewer's ATA layer. ps2sdk's ps2dev9 and ps2atad are
     * preloaded; atadpatch fakes the HDD ID on that atad's export table (the
     * first atad it sees register); and its modload hook substitutes the
     * Viewer's own dev9 and atad when they are loaded on top, so the Viewer's
     * hdd binds to the preloaded pair and one driver owns the controller.
     * This is build.sh's default.
     *
     * Order matters: the hook must be resident before ps2dev9 and ps2atad
     * register, or they pass through unseen and the Viewer's own pair is
     * taken for the first.
     *
     * poltracechk after ps2atad is the device probe: atad refuses transfers
     * until something calls sceAtaGetDevInfo. With a trace LBA it also does
     * a one-sector round trip, and the result is printed. */
    load_mod("atadfix", atadpatch_irx, size_atadpatch_irx, 0, NULL);
    load_mod("ps2dev9", ps2dev9_irx, size_ps2dev9_irx, 0, NULL);
    wait_secs(1);
    load_mod("ps2atad", ps2atad_irx, size_ps2atad_irx, 0, NULL);
    wait_secs(1);
    {
        int cres = -12345, cid;
        cid = SifExecModuleBuffer(poltracechk_irx, size_poltracechk_irx, 0, NULL, &cres);
        if (cid < 0 || (cres & 0x40000000) == 0)
            SAY("  probe   id=%-4d res=%d (no result word)", cid, cres);
        else
            SAY("  probe   read %d, magic %s, write %d, readback %s",
                (cres & 0xff) - 128, (cres >> 16) & 1 ? "FOUND" : "absent",
                ((cres >> 8) & 0xff) - 128, (cres >> 16) & 4 ? "same" : "differs");
    }
#else
#error "DRIVERS must be 2 or 4"
#endif

    /* ---- load the Viewer and go -------------------------------------- */
    ehp = (elf_hdr_t *)polboot_elf;
    if (memcmp(ehp->ident, "\177ELF", 4) != 0) {
        STOP("embedded boot ELF is corrupt -- stopping.");
    }
    memcpy(&eh, ehp, sizeof(eh));
    SAY(" ");
    SAY("POLBOOT.ELF: %u B, entry 0x%08x, %d phdrs",
        size_polboot_elf, (unsigned)eh.entry, eh.phnum);

    n = eh.phnum > 8 ? 8 : eh.phnum;
    for (i = 0; i < n; i++) {
        elf_phdr_t *p = (elf_phdr_t *)(polboot_elf + eh.phoff + i * eh.phentsize);
        if (p->type != 1) continue;                     /* PT_LOAD */
        memcpy((void *)p->vaddr, polboot_elf + p->offset, p->filesz);
        if (p->memsz > p->filesz)
            memset((void *)(p->vaddr + p->filesz), 0, p->memsz - p->filesz);
        SAY("  LOAD 0x%08x %u bytes", (unsigned)p->vaddr, (unsigned)p->filesz);
    }

    SAY(" ");
    /* The word the retail dnasload leaves in low memory. Written last, so
     * nothing else of this loader runs between it and the handover. */
    if (fork_install.handover_addr) {
        *(volatile unsigned int *)fork_install.handover_addr =
            fork_install.handover_value;
        SAY("handover: [0x%08x] = 0x%08x",
            fork_install.handover_addr, fork_install.handover_value);
    }

    SAY("exec: argv[0]=\"%s\"", VIEWER_PATH);
    stage_set(STAGE_EXEC_LINE);

    /* No delay between the stages: the IOP side records when each stage
     * first appears. */
    stage_set(STAGE_WAITED);

    boot_argv[0] = VIEWER_PATH;
    real_entry   = eh.entry;
    tramp_argv[0] = VIEWER_PATH;
    FlushCache(0);
    FlushCache(2);
    stage_set(STAGE_FLUSHED);
    SifExitRpc();
    stage_set(STAGE_RPC_DOWN);
#if defined(ENTRY_JUMP)
    /* ENTRY_JUMP (developer diagnostic, not built by build.sh): no ExecPS2.
     * Land on the trampoline with a fresh stack from this loader's BSS and
     * let it jump to the Viewer, whose startup sets up its own thread and
     * heap regardless. */
    {
        u32 top = ((u32)jump_stack + sizeof(jump_stack) - 16) & ~15u;
        __asm__ __volatile__(
            "move $sp, %0\n\t"
            "jr   %1\n\t"
            "nop\n\t"
            :: "r"(top), "r"(viewer_tramp));
    }
#elif defined(ENTRY_MARKER)
    ExecPS2((void *)viewer_tramp, NULL, 1, boot_argv);
#else
    ExecPS2((void *)eh.entry, NULL, 1, boot_argv);
#endif

    STOP("ExecPS2 returned -- should not happen");
    return 0;
}

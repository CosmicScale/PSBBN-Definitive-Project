#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# PlayOnline installer for the PSBBN Definitive Project
# Copyright (C) 2026 PrettyOpenLobby
#
# Build and sign polbbnexec.kelf, the loader the installer writes to a Viewer
# partition as `dnasload.elf`. The signed file is kept at
# scripts/assets/playonline/polbbnexec.kelf; a user never runs this. See
# README.md here for what the loader does and why it exists.
#
# Needs:
#   PS2DEV          a ps2sdk toolchain root: ee-gcc, iop-gcc, bin2c, and
#                   ps2sdk with its iop/irx/ps2dev9.irx and ps2atad.irx
#   PS2KEYS         PS2KEYS.dat, the MagicGate keys a retail console signs
#                   KELFs with; only the signing step reads it
#   TEMPLATE_KELF   any PlayOnline disc's POL/install/PS2/dnasload.elf. Only
#                   its 32-byte header layout is borrowed, none of its content
#   python3         with pycryptodome, for the generated default HDD ID and the
#                   signing
#
#   PS2DEV=... PS2KEYS=... TEMPLATE_KELF=... bash build.sh
#
# DRIVERS picks what the loader leaves under the Viewer, as polbbnexec.c
# documents: 4 preloads ps2sdk's dev9/atad and substitutes the Viewer's own
# pair, 2 installs only the HDD ID hook. 4 is the default.
set -e
: "${PS2DEV:?set PS2DEV to the ps2dev toolchain root}"
: "${PS2KEYS:?set PS2KEYS to your console's PS2KEYS.dat}"
: "${TEMPLATE_KELF:?set TEMPLATE_KELF to a disc's POL/install/PS2/dnasload.elf}"
: "${DRIVERS:=4}"
# VERBOSE=1 builds the loader that narrates every step on screen, for finding
# where a console stops. The default draws nothing unless it has to stop, so
# the handover looks like Square Enix's.
: "${VERBOSE:=0}"
VERBOSE_FLAG=""
[ "$VERBOSE" = "1" ] && VERBOSE_FLAG="-DFORK_VERBOSE"
SDK="${PS2SDK:-$PS2DEV/ps2sdk}"
export PATH="$PS2DEV/ee/bin:$PS2DEV/iop/bin:$SDK/bin:$PATH"
HERE="$(cd "$(dirname "$0")" && pwd)"
HELPER="$(cd "$HERE/../.." && pwd)"          # scripts/helper, the package root
OUT="$HERE/out"
mkdir -p "$OUT"
cd "$OUT"

IOPCFLAGS="-D_IOP -fno-builtin -Os -G0 -I$SDK/iop/include -I$SDK/common/include"
IOPLIBS="-nostdlib -L$SDK/iop/lib -lkernel -lgcc"

# The default HDD ID block compiled into the shim. The loader overwrites it
# at boot with the block the installer wrote into its header, so its value
# never reaches a console; it exists so the shim has a slot of the right
# shape to find. Generated from a fixed seed, so a rebuild is reproducible.
PYTHONPATH="$HELPER" python3 -m playonline.hddid --mint hddid.bin --seed polbbnexec-default-hddid >/dev/null
bin2c hddid.bin hddid_iop.c hddid_bin >/dev/null
iop-gcc -D_IOP -Os -G0 -c hddid_iop.c -o hddid_iop.o

# polnull.irx: the do-nothing module substituted for the Viewer's own dev9 and
# atad. It is embedded with 16-byte alignment (bin2c does not align), because
# modload reads the ELF headers out of the buffer with word loads and the
# R3000 traps on a misaligned one.
iop-gcc $IOPCFLAGS -c "$HERE/polnull.c" -o polnull.o
iop-gcc -o polnull.irx polnull.o $IOPLIBS
python3 - <<'PY'
d = open('polnull.irx', 'rb').read()
lines = ['unsigned char polnull_irx[] __attribute__((aligned(16))) = {']
for i in range(0, len(d), 16):
    lines.append('  ' + ','.join('0x%02x' % b for b in d[i:i+16]) + ',')
lines.append('};')
lines.append('unsigned int size_polnull_irx = %d;' % len(d))
with open('polnull_iop.c', 'w') as f:
    f.write(chr(10).join(lines) + chr(10))
PY
iop-gcc -D_IOP -Os -G0 -c polnull_iop.c -o polnull_iop.o

# atadpatch.irx: the HDD ID shim (loadcore and modload hooks).
for s in atadhook modhook loadcore_stub modload_stub atad_rw_stub; do
    iop-gcc -D_IOP -Os -G0 -I"$SDK/iop/include" -c "$HERE/$s.S" -o "$s.o"
done
iop-gcc $IOPCFLAGS -DTRACE_LBA=0 -I"$HERE" -c "$HERE/atadpatch.c" -o atadpatch.o
iop-gcc -o atadpatch.irx atadpatch.o atadhook.o modhook.o loadcore_stub.o modload_stub.o hddid_iop.o polnull_iop.o $IOPLIBS

# poltracechk.irx: with no trace LBA its one job is the ATA device probe that
# atad needs before it will move a sector.
iop-gcc $IOPCFLAGS -DTRACE_LBA=0 -I"$HERE" -c "$HERE/poltracechk.c" -o poltracechk.o
iop-gcc -o poltracechk.irx poltracechk.o atad_rw_stub.o $IOPLIBS

# ps2sdk's ATA layer, taken from the SDK as built.
cp "$SDK/iop/irx/ps2dev9.irx" "$SDK/iop/irx/ps2atad.irx" .

# EE side: every IOP module becomes an array the loader hands to the IOP.
for pair in ps2dev9_irx:ps2dev9.irx ps2atad_irx:ps2atad.irx \
            atadpatch_irx:atadpatch.irx poltracechk_irx:poltracechk.irx; do
    lab="${pair%%:*}"; f="${pair##*:}"
    bin2c "$f" "${lab}_blob.c" "$lab" >/dev/null
    ee-gcc -D_EE -O2 -G0 -I"$SDK/ee/include" -c "${lab}_blob.c" -o "${lab}_blob.o"
done

# The loader is linked at 0x01800000 so it never overlaps the Viewer's
# segments (0x00100000, 0x001d8000, 0x00800000) while it copies them in.
sed 's/0x00100000/0x01800000/' "$SDK/ee/startup/linkfile" > linkfile.hi
ee-gcc -D_EE -O2 -G0 -Wall -DFORK_INSTALL -DDRIVERS="$DRIVERS" -DTRACE_LBA=0 $VERBOSE_FLAG \
       -I"$SDK/ee/include" -I"$SDK/common/include" \
       -c "$HERE/polbbnexec.c" -o polbbnexec.o
ee-gcc -mno-crt0 -Tlinkfile.hi -L"$SDK/ee/lib" -o POLBBNEXEC.ELF \
       "$SDK/ee/startup/crt0.o" polbbnexec.o \
       ps2dev9_irx_blob.o ps2atad_irx_blob.o atadpatch_irx_blob.o poltracechk_irx_blob.o \
       -ldebug -lpatches -liopreboot -lkernel -lc
ee-strip POLBBNEXEC.ELF 2>/dev/null || true

# Sign. The template lends its 32-byte header layout and nothing else.
PYTHONPATH="$HELPER" python3 -m playonline.lib.polkelf "$TEMPLATE_KELF" \
    --keys "$PS2KEYS" --encrypt POLBBNEXEC.ELF -o polbbnexec.kelf
PYTHONPATH="$HELPER" python3 -m playonline.loader polbbnexec.kelf --show
ls -la POLBBNEXEC.ELF polbbnexec.kelf
echo "copy $OUT/polbbnexec.kelf to scripts/assets/playonline/ to ship it"

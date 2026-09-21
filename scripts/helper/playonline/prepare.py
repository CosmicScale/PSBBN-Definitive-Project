#!/usr/bin/env python3
#
# PlayOnline installer for the PSBBN Definitive Project
# Copyright (C) 2026 PrettyOpenLobby
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""How a PlayOnline install is made to run, and what each way costs.

Square Enix's install is bound to its drive: the boot container and every
`.pex.enc` module are encrypted under a key derived from the drive's HDD ID,
and their `dnasload` opens the container and starts the Viewer. This package
uses its own signed loader instead (`playonline/loader-src`, shipped as
`scripts/assets/playonline/polbbnexec.kelf`). It takes the Viewer's boot ELF
and IOP reboot image from the user's own disc, reboots the IOP, installs the
HDD ID shim a generic drive needs, and enters the ELF. Nothing of Square
Enix's has to be opened, so the user's console keys are not needed.

The modules can then be prepared in two ways:

plaintext (the default where the build allows it)
    The Viewer's boot ELF has a development switch: one flag makes every
    stage open a plain `.pex` instead of the drive-keyed `.pex.enc`. The
    partition then holds decompressed modules keyed to nothing. The switch
    exists in every build from the 1.13 era on, which covers Vana'diel
    Collection 2008 (1.18.03b) and the Dirge of Cerberus disc (1.14.03).

transcrypt (the fallback for the two 2003-era discs)
    The US PlayOnline Viewer disc (1.11.00m) and the Japanese one (1.05.00d)
    carry a loader stub without the switch. Every container and module is
    converted from the disc form to the installed form, keyed to the HDD ID
    this install mints. The shim serves that same ID back to the console.

Both routes mint an HDD ID and write a `__net` record. In plaintext mode the
record is not needed to boot; it is written because the in-Viewer updater
keys what it downloads through it.

    python3 -m playonline.prepare          # this table
"""

PLAINTEXT = "plaintext"
TRANSCRYPT = "transcrypt"

# `needs_hddid` means the modules are keyed to an HDD ID. The drive does not
# need one of its own: on a generic drive the loader's shim serves the ID the
# installer minted (see hddid.served_by_shim). Both routes ship the shim, so
# both mint an ID; only transcrypt keys anything to it.
BACKENDS = {
    PLAINTEXT: {
        "status": "modules run unencrypted through the Viewer's "
                  "development switch",
        "needs_hddid": False,
        "needs_net_record": True,
        "needs_installed_container": False,
        "per_module_work": "every module decompressed to a plain .pex beside "
                           "its .pex.enc",
        "builds": "every Viewer build with the plaintext switch: 1.13 era and "
                  "later, including Vana'diel Collection 2008 and the Dirge "
                  "of Cerberus disc",
    },
    TRANSCRYPT: {
        "status": "modules are re-keyed to the HDD ID this install mints",
        "needs_hddid": True,
        "needs_net_record": True,
        "needs_installed_container": True,
        "per_module_work": "every .pex.enc transcrypted to this drive",
        "builds": "the two 2003-era discs, US 1.11.00m and JP 1.05.00d, whose "
                  "loader stub has no plaintext switch",
    },
}

DEFAULT = PLAINTEXT


def describe(name=None):
    names = [name] if name else sorted(BACKENDS)
    out = []
    for n in names:
        b = BACKENDS[n]
        out.append("%s%s" % (n, "  (default where the build allows it)"
                              if n == DEFAULT else "  (fallback)"))
        out.append("  status: %s" % b["status"])
        out.append("  builds: %s" % b["builds"])
        needs = [k[6:].replace("_", " ") for k in
                 ("needs_hddid", "needs_net_record",
                  "needs_installed_container") if b[k]]
        out.append("  needs:  %s" % (", ".join(needs) if needs else "nothing drive-specific"))
        out.append("  modules: %s" % b["per_module_work"])
    out.append("both routes boot through the package's own loader, which "
               "serves the minted HDD ID to the console")
    return "\n".join(out)


def requires_drive_identity(name):
    """True when the modules are keyed to a specific HDD ID.

    This is not a hardware requirement: on a generic drive the loader's shim
    serves the minted ID. The install and the shim must be staged from one
    source, because a mismatched ID decrypts to noise without any error.
    """
    return BACKENDS[name]["needs_hddid"]


if __name__ == "__main__":
    print(describe())

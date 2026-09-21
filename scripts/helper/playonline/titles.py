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
"""The titles this installer knows, their partitions and sizes.

Partition names follow `PP.<product>.<slot>.<TAG>`. The slot and the tag are
Square Enix's choices and follow no rule (Tetra Master is 0002, Janhourou
0003, Dirge 0010, FFXI 0001), so the names and `se_mib` values here are those
Square Enix's installer uses. The installer refuses a title that is not in
this table.

`status`, which the installer prints:

    tested        the title starts on a console
    installs      the partition builds and verifies
    unsupported   the name and size are known; this package cannot build it

A partition is a power of two of at least 128 MiB, the APA granule. `MAX_MIB`
is 8192, the largest main partition this installer creates. Square Enix
never exceed 1024 MiB in one header (a large title is a 1024 MiB main plus
sub-partitions). `se_mib` and `subs_mib` record Square Enix's sizes; `needs_subs`
records that they split the title and gates nothing.
"""

# The discs titles come from. A disc the user did not supply is skipped and
# never substituted: the JP Viewer disc cannot supply the US tree.
DISCS = {
    "pol-jp": {
        "product": "SLPS-20200",
        "name": "PlayOnline Viewer - Tetra Master & Janhourou (Japan)",
        "supplies": ["viewer-jp", "tetramaster-jp", "janhourou-jp"],
    },
    "pol-us": {
        "product": "SCUS-97269",
        "name": "PlayOnline Viewer and Tetra Master (USA, Canada)",
        "supplies": ["viewer-us", "tetramaster-us"],
    },
    "ffxi-us-2008": {
        "product": "SLUS-21704",
        "name": "Final Fantasy XI - Online - Vana'diel Collection 2008 (USA)",
        "supplies": ["viewer-us", "tetramaster-us", "ffxi-us"],
        "note": "The recommended source for a US install. Carries two "
                "containers: POL/INSTALL.DAT with the Viewer and Tetra "
                "Master, and FFXI's own DATA/ROM*.DAT and MISC*.DAT set "
                "with its DATA/FILE.TXT manifest.",
    },
    "ffxi-jp": {
        "product": "SLPS-25200",
        "name": "Final Fantasy XI (Japan)",
        "supplies": ["ffxi-jp"],
    },
    "fmo-jp": {
        "product": "SLPM-65981",
        "name": "Front Mission Online (Japan)",
        "supplies": ["viewer-jp", "janhourou-jp", "tetramaster-jp", "fmo-jp"],
        "note": "Also a PlayOnline install disc: POL/INSTALL.DAT holds the "
                "Japanese Viewer, Janhourou and Tetra Master. The game "
                "itself is the root file DVDIMAGE.DAT, and its boot module "
                "is the root file MIDAS.PEX.",
    },
    "dirge-jp": {
        "product": "SLPM-66271",
        "name": "Dirge of Cerberus - Final Fantasy VII (Japan, Asia)",
        "supplies": ["viewer-jp", "janhourou-jp", "tetramaster-jp", "dirge-jp"],
        "note": "Also a PlayOnline install disc: POL/INSTALL.DAT holds the "
                "Japanese Viewer, Janhourou and Tetra Master. The game "
                "itself is in the root KEL.DAT container.",
    },
}


GRANULE_MIB = 128       # the APA granule, and so the smallest partition
MAX_MIB = 8192          # the largest this installer creates

# Which container a title's files come out of. The choice belongs to the
# title and not to the disc: Vana'diel Collection 2008 carries the PlayOnline
# install container and FFXI's own DATA/ side by side.
ARCHIVE = "install-archive"     # the `_/N/M.K` tree, read by archive.py
INSTALL_DAT = "install-dat"     # POL/INSTALL.DAT, read by installdat.py
FFXI_DATA = "ffxi-data"         # DATA/ROM*.DAT and MISC*.DAT, read by ffxidata.py
DIRGE_KEL = "dirge-kel"         # E419C51B/KEL.DAT indexed by FILELIST.BIN, read by dirgedata.py
FMO_IMAGE = "fmo-image"         # /DVDIMAGE.DAT, raw files behind a manifest, read by fmodata.py

# The two forms of the PlayOnline install container. A title that does not name
# a container comes out of whichever of these its disc carries.
POL_CONTAINERS = (ARCHIVE, INSTALL_DAT)


class Title(object):
    def __init__(self, key, disc, partition, se_mib, need_mib, title0, title1="",
                 status="unsupported", encoding="ascii", subs_mib=0, icon=None,
                 boot="NOBOOT", note="", tree=None, layout=None,
                 aliases=None, title0_en=None, needs_subs=False,
                 container=None):
        self.key = key
        self.disc = disc
        self.partition = partition
        self.se_mib = se_mib            # Square Enix's main partition size
        self.subs_mib = subs_mib        # what they add in sub-partitions
        self.need_mib = need_mib        # what this installer asks for
        self.title0 = title0            # browser line 1
        self.title1 = title1            # browser line 2
        self.encoding = encoding        # icon.sys text encoding
        self.status = status
        self.icon = icon                # path in the disc install tree
        # Which container this title's files come out of. None means the
        # PlayOnline install container, in whichever form the disc carries.
        self.container = container
        self.boot = boot                # slot 0 BOOT2 value
        self.note = note
        # The prefix this title's files carry inside a disc's install
        # container, in Square Enix's naming (Janhourou's tree is
        # `Warashi/`). None means the title's files are not in the PlayOnline
        # container.
        self.tree = tree
        # How the staged tree maps into the partition: [(staged subpath,
        # destination directory)], "" meaning the partition root. It is not
        # a flat copy of the staged tree. A POLVIEWER root written by
        # Square Enix's 1.18.03b US installer holds SCUS-97269,
        # dnasload.elf, patch.ver, data/, default/, export/ and res/ (the
        # contents of POL/install/PS2) plus V/ and ps2drv/. `usr/`, `pub/`
        # and `installed` are created at install time and are not on the
        # disc.
        self.layout = layout or ([(tree.rstrip("/"), "")] if tree else [])
        # The title0 spellings that mean this title, for matching a prebuilt
        # attribute area off a disc. Square Enix is not consistent: the JP
        # Viewer partition reads PlayOnlineViewer where the US one reads
        # PlayOnline, and some discs pad the field with spaces.
        self.aliases = set(aliases or []) | {title0.strip()}
        # The name this project uses for the title in English. Set only
        # where Square Enix's browser title is not already English, which is
        # Janhourou alone: Tetra Master reads "Tetra Master" even on the JP
        # drive, and the Viewer reads PlayOnline.
        self.title0_en = title0_en
        # True when Square Enix split this title over sub-partitions. It
        # gates nothing: the largest tree fits one main partition.
        self.needs_subs = needs_subs
        if need_mib > MAX_MIB:
            raise ValueError("%s: %d MiB is larger than the largest main "
                             "partition supported (%d MiB)"
                             % (key, need_mib, MAX_MIB))

    @property
    def product(self):
        return self.partition.split(".")[1]

    @property
    def stageable(self):
        """True when this project can extract this title's files.

        Most titles are a named subtree of the PlayOnline install container,
        so having a `tree` is enough. FFXI, Dirge and FMO come from
        containers of their own that hold nothing else, and have no subtree
        to name.
        """
        return bool(self.tree) or self.container in (FFXI_DATA, DIRGE_KEL,
                                                     FMO_IMAGE)

    def container_on(self, disc_format):
        """Return the container to read this title from, on a disc of that format."""
        return self.container or disc_format

    def __repr__(self):
        return "<Title %s %s %s>" % (self.key, self.partition, self.status)


# The Viewer is the only partition the browser boots: BOOT2 is the loader and
# DNASBOOT2 is its container. Every other title carries BOOT2 = NOBOOT and is
# launched from inside the Viewer.
_VIEWER_BOOT = "pfs:/dnasload.elf"

TITLES = {}


def _add(*a, **kw):
    t = Title(*a, **kw)
    TITLES[t.key] = t
    return t


# Square Enix's installer flattens `POL/ps2drv`, and the Viewer depends on
# the flattened layout: it opens `pfs2:/ps2drv/kbd/kcd000.dat`, while every
# install container (the JP archive, the US archive, Vana'diel Collection
# 2008's INSTALL.DAT) holds those seven files at `POL/ps2drv/data/kbd/` with
# the IOP modules under `POL/ps2drv/modules/`.
#
# The disc's layout copied unchanged does not boot: the keymap load fails.
_VIEWER_LAYOUT = [("POL/install/PS2", ""), ("POL/Data/PS2", "V"),
                  ("POL/ps2drv/modules", "ps2drv"),
                  ("POL/ps2drv/data/kbd", "ps2drv/kbd")]


# ---- JP Viewer disc titles ---------------------------------------------------
_add("viewer-jp", "pol-jp", "PP.SLPS-20200.1000.POLVIEWER", se_mib=1024,
     need_mib=1024, title0="PlayOnlineViewer", title1=" " * 16,
     encoding="utf-8", tree="POL/", layout=_VIEWER_LAYOUT, aliases=["PlayOnline"], status="installs", boot=_VIEWER_BOOT,
     icon="POL/Data/PS2/system/image/playonline.ico",
     note="SE writes title1 as 16 spaces, not empty")

_add("tetramaster-jp", "pol-jp", "PP.SLPS-20200.0002.TETRAMASTER", se_mib=128,
     subs_mib=512, need_mib=1024, title0="Tetra Master", tree="TetraMaster/", status="installs",
     note="SE's own attribute area reads title0=Tetra Master in English even "
          "on the JP drive")

_add("janhourou-jp", "pol-jp", "PP.SLPS-20200.0003.JANHOUROU", se_mib=256,
     need_mib=1024, title0="雀鳳楼", aliases=["Janhourou"],
     title0_en="JongHoLow", encoding="utf-8", tree="Warashi/", status="tested",
     note="Square Enix ships this partition with zero password fields")

# ---- US Viewer disc titles ---------------------------------------------------
_add("viewer-us", "pol-us", "PP.SCUS-97269.1000.POLVIEWER", se_mib=1024,
     need_mib=1024, title0="PlayOnline", title1="Viewer", tree="POL/", layout=_VIEWER_LAYOUT, aliases=["PlayOnlineViewer"], status="tested",
     boot=_VIEWER_BOOT, icon="POL/Data/PS2/system/image/playonline.ico")

_add("tetramaster-us", "pol-us", "PP.SCUS-97269.0002.TETRAMASTER", se_mib=128,
     need_mib=1024, title0="Tetra Master", tree="TetraMaster/", status="tested",
     note="se_mib is the size of Square Enix's Japanese Tetra Master "
          "partition")

# ---- other titles ------------------------------------------------------------
_add("ffxi-jp", "ffxi-jp", "PP.SLPS-25200.0001.FFXI", se_mib=1024,
     subs_mib=8192, need_mib=1024, needs_subs=True, title0="FINAL FANTASY XI",
     encoding="utf-8", status="unsupported",
     note="Square Enix grows this with eight 1 GiB sub-partitions; not "
          "staged by this installer yet")

_add("fmo-jp", "fmo-jp", "PP.SLPM-65981.0004.FMO", se_mib=1024, subs_mib=8192,
     need_mib=4096, needs_subs=True, title0="FRONT MISSION ONLINE", encoding="utf-8",
     aliases=["フロントミッション"],
     status="tested", container=FMO_IMAGE, layout=[("", "")],
     note="staged from the disc's DVDIMAGE.DAT (fmodata.py)")

# Dirge. The disc's own container (dirgedata.py) yields 1.71 GiB, so the tree
# takes a 4096 MiB main where Square Enix used 1024 plus eight subs. Its
# browser entry is assembled from the disc's install/ pieces (icon.sys and
# the two kel_hdd icons, which match the sizes in Square Enix's area), behind
# a disc-boot block: HDD-OSD launches Dirge from its disc and the Viewer
# launches it from the drive. Some files in Square Enix's installed partition
# are not on the disc and are written by their installer or the patch
# service, notably memown.pol, which the title waits for.
_add("dirge-jp", "dirge-jp", "PP.SLPM-66271.0010.CERBERUS", se_mib=1024,
     subs_mib=8192, need_mib=4096, needs_subs=True, title0="DIRGE of CERBERUS",
     encoding="utf-8", status="installs", container=DIRGE_KEL, layout=[("", "")],
     boot="DISC",
     note="installs from the disc's KEL container; launch waits on "
          "memown.pol and other files Square Enix's installer and patch "
          "service add")

# FFXI US. The partition name comes from the US install.inf, and the US
# Viewer looks for it. The tree is FFXI's own DATA container plus the two
# boot-side containers the disc's CONFIGU.SYS names in its ENC= line, which
# `route ffxi` keys to the install. Square Enix grow their FFXI with eight
# 1 GiB sub-partitions; the same tree fits one 8192 MiB main.
#
# The product in the partition name is not the disc's code: Vana'diel
# Collection 2008 boots SLUS-21704. A partition name cannot be derived from
# the disc a title came on.
_add("ffxi-us", "ffxi-us-2008", "PP.SCUS-97266.0001.FFXI", se_mib=1024,
     subs_mib=8192, need_mib=8192, needs_subs=True, title0="FINAL FANTASY XI",
     title1="-ONLINE-", encoding="utf-8", status="tested",
     container=FFXI_DATA, layout=[("", "")],
     note="the disc pairs a 2004 boot module with 2007 data whose menu "
          "overlay lacks a resource the module needs; `route ffxi` "
          "reconciles the overlay (ffxioverlay.py)")


def fit_size(tree_bytes, headroom=2.0, floor=GRANULE_MIB, cap=MAX_MIB):
    """Return the smallest legal partition size, in MiB, that holds `tree_bytes` with headroom.

    Partitions are powers of two of at least 128 MiB. The default headroom
    doubles the tree, because the Viewer writes settings into `usr/` and an
    in-Viewer update adds files.
    """
    want = max(floor, (tree_bytes * headroom) / (1024.0 * 1024.0))
    size = floor
    while size < want and size < cap:
        size *= 2
    return min(size, cap)


def choose_size(tree_bytes, free_mibs=(), prefer=None):
    """Return (size, why) for a title of `tree_bytes`, given the free entries.

    Square Enix's size (`prefer`) is used where there is room for it, so that
    an install matches theirs. On a drive with little free space a smaller
    partition that still fits the tree is chosen. The size is None when no
    free entry can hold the tree.
    """
    need = fit_size(tree_bytes)
    usable = sorted((m for m in free_mibs if m >= need), reverse=True)
    if prefer and prefer >= need and (not free_mibs or any(m >= prefer for m in free_mibs)):
        return prefer, "Square Enix's own size"
    if not free_mibs:
        return need, "smallest that fits the tree"
    if not usable:
        return None, ("no free entry holds %d MiB; the largest is %d"
                      % (need, max(free_mibs) if free_mibs else 0))
    # Square Enix's size fits no free entry, so take the largest power of two
    # that does, no smaller than the tree needs and no larger than their
    # size. On a PSBBN drive the rest of the space is for the user's games.
    ceiling = prefer or need
    size = need
    while size * 2 <= min(usable[0], ceiling):
        size *= 2
    return size, "trimmed to fit a %d MiB free entry" % usable[0]


# Which titles each Viewer launches, by key. A drive holds one Viewer. The US
# Viewer launches the US-serial titles and also the Japan-only ones, through
# the partition names its install.inf carries for contents 3, 4 and 10. The
# JP Viewer's install.inf names only Japanese-serial partitions, so it does
# not see a US Tetra Master or FFXI partition.
LAUNCHES = {
    "viewer-us": ("viewer-us", "tetramaster-us", "ffxi-us",
                  "janhourou-jp", "dirge-jp", "fmo-jp"),
    "viewer-jp": ("viewer-jp", "tetramaster-jp", "ffxi-jp",
                  "janhourou-jp", "dirge-jp", "fmo-jp"),
}


def launchable_under(viewer_key):
    return [TITLES[k] for k in LAUNCHES[viewer_key] if k in TITLES]


def for_disc(disc_key):
    return [TITLES[k] for k in DISCS[disc_key]["supplies"] if k in TITLES]


def by_status(*wanted):
    return [t for t in TITLES.values() if t.status in wanted]


def summary():
    rows = ["%-16s %-32s %8s %8s  %s" % ("title", "partition", "SE MiB", "need", "status")]
    for t in sorted(TITLES.values(), key=lambda t: (t.status, t.key)):
        rows.append("%-16s %-32s %8d %8d  %s"
                    % (t.key, t.partition, t.se_mib, t.need_mib, t.status))
    return "\n".join(rows)


if __name__ == "__main__":
    print(summary())


# ---- partition passwords ---------------------------------------------------
# A title mounts its own partition with `hdd0:<id>,<password>`, so the APA
# header has to carry the matching `fpwd`. See password.py for what is
# checked.
#
# The passwords are generated from the 64-bit key Square Enix ship per
# content id in `install.inf`. `polhdd.selftest_build_pw` regenerates them
# and checks one against a header Square Enix wrote.
#
# The Viewer's password is not derived from install.inf, which covers the
# titles the Viewer launches and has no record for POLVIEWER. `zbaa.nbu`
# matches Square Enix's US and JP headers.
VIEWER_PASSWORD = "zbaa.nbu"

#: title key -> the install.inf content id whose key generates its password.
#: A title absent here, or whose module has no constant key (Dirge loops over
#: a table instead), has no generated password and its fields stay as created.
PASSWORD_CONTENT = {
    "tetramaster-jp": 2,
    "tetramaster-us": 2,
    "ffxi-jp": 1,
    "ffxi-us": 1,
    "fmo-jp": 4,
    "dirge-jp": 10,
}


def password_of(title):
    """Return the password `title`'s module mounts its partition with, or None."""
    if title.key in ("viewer-jp", "viewer-us"):
        return VIEWER_PASSWORD
    cid = PASSWORD_CONTENT.get(title.key)
    if cid is None:
        return None
    from .lib.polhdd import INSTALL_KEYS, build_pw
    key = INSTALL_KEYS.get(cid)
    if not key:
        return None
    return build_pw(key).decode("latin-1")

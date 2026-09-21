# The PlayOnline step

Installs Square Enix's PlayOnline titles onto a PlayStation 2 drive from
discs you already own, beside the games PSBBN put there.

The user guide is the **Install PlayOnline** section of the top-level
[README](../../../README.md). [DESIGN.md](DESIGN.md) explains how the step
works and why it is built the way it is.

## What you need

* **A drive with PSBBN or HOSDMenu already on it.** This step adds to that
  install. It refuses to touch a disk that is not one.
* **Your own discs**, as image files in `games/POL`. Any of:
  * PlayOnline Viewer & Tetra Master, Japan (`SLPS-20200`)
  * PlayOnline Viewer and Tetra Master, USA (`SCUS-97269`)
  * Final Fantasy XI Vana'diel Collection 2008, USA (`SLUS-21704`)
  * Dirge of Cerberus, Japan (`SLPM-66271`), which is also a PlayOnline
    install disc
  * Front Mission Online, Japan (`SLPM-65981`), which is one as well
* Nothing from your console. The step boots the Viewer through a loader of
  its own (`scripts/assets/playonline/polbbnexec.kelf`, source in
  `loader-src/`), which serves the drive identity a third-party disk lacks,
  so Square Enix's own loader is never opened and no MagicGate keys are
  needed.

Nothing of Sony's or Square Enix's ships with this. The discs are yours,
read at the moment they are used.
`python3 -m playonline.shipcheck` checks that this stays true.

## Using it

From the toolkit's main menu, choose **Install PlayOnline**. It finds your
drive, asks which region's Viewer and which titles you want, shows what it
will add, and asks before writing anything.

Where two discs carry the same title it takes the newer build. Vana'diel
Collection 2008 carries Viewer 1.18.03b against the Viewer disc's 1.11.00m,
and the Dirge disc carries a newer Japanese Viewer than the Japanese
PlayOnline disc does.

Partitions are sized from the tree that comes off the disc, so a small
title gets a small partition. Square Enix's own sizes are used where the
drive has room for them.

## The pieces, if you are reading the code

    discs.py        identify a disc from its own SYSTEM.CNF, and say which
                    of the two install containers it carries
    chd.py          extract a `.chd` image with chdman, once, beside the original
    archive.py      read the `_/N/M.K` container, from inside the image
    installdat.py   read the `POL/INSTALL.DAT` container
    ffxidata.py     read FFXI's own `ROM*.DAT` and `MISC*.DAT`
    dirgedata.py    read Dirge of Cerberus's `KEL.DAT`
    fmodata.py      read Front Mission Online's `DVDIMAGE.DAT`
    stage.py        put one title's files on disk
    titles.py       what is installable and at what size
    apa.py          read a partition table, and only read it
    jail.py         find the edge of the APA region so nothing is carved
                    into the exFAT partition holding your games
    netpart.py      create `__net`, or make the one PSBBN made openable
    build.py        give a partition its password and browser entry; on an
                    image, format and fill it too
    pfsprogress.py  a progress line from pfsshell's prompts while it writes
    pfsput.py       the pfsshell command list that puts a staged tree on a
                    drive's partition, main and sub-partitions alike
    installinf.py   register each title in the Viewer's own list of what
                    is installed, which is what it checks before a launch
    retitle.py      English names for the Japan-only titles under the US
                    Viewer, in the browser and in PSBBN's own list
    attrarea.py     build a browser entry from parts
    prebuilt.py     find the browser entry Square Enix already made
    keys.py         find Square Enix's public keys in your own disc
    route.py        make a staged tree bootable: plain or keyed modules,
                    the loader filled, the `__net` record minted
    loader.py       read and fill the loader's install header
    patchhost.py    name a community server (by default play.openlobby.fyi)
                    as the Viewer's patch host, so a console cannot take
                    Square Enix's end-of-service update
    resync.py       bring an installed title up to what would be installed
                    today, without removing anything that is the user's
    reloader.py     replace the loader on an installed Viewer, in place,
                    when a later version of this package changes it
    loader-src/     the loader itself, and how it is built and signed
    prepare.py      the two module routes and what each needs
    hddid.py        the drive identity the loader serves, and that keyed
                    modules are built against
    selftest.py     check all of the above against Square Enix's own bytes
    shipcheck.py    check that none of their bytes are in this repository
    pcsx2image.py   build a PCSX2 hard drive image from the same discs
    lib/            the format and crypto modules the above are built on:
                    APA, PFS, the module containers, the KELF container,
                    and the Viewer's per-build patch tables

## Checking it

    python3 -m playonline.selftest DRIVE [DRIVE ...] [--disc IMAGE ...]

Given drives or images it takes Square Enix's own attribute areas apart,
rebuilds them, and requires the result to be identical to what Sony's browser
was actually given. Given discs it checks that their keystore can be found
and that their install container's sizes add up. With no arguments it checks
the package imports, the shipped loader and the per-build patch tables.

Everything else in this directory writes nothing unless told to. `build`,
`netpart` and `route` are dry runs until `--write`.

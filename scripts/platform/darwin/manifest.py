#!/usr/bin/env python3
"""Snapshot of a staged partition directory.

A staged partition is an ordinary folder. The snapshot taken right after
the folder is filled (mount, or the tar shim) is what unmount compares
against, so only files the installer added, replaced or removed are
written back to the PS2 drive.

Entry formats:
  ["f", size, mtime_ns]   regular file
  ["l", target]           symbolic link
  ["d"]                   directory
"""
import json
import os
import stat
import sys

JUNK = (".", "..", "lost+found", ".DS_Store")


def skip(name):
    return name in JUNK or name.startswith("._")


def entry(path, info=None):
    if info is None:
        info = os.lstat(path)
    if stat.S_ISLNK(info.st_mode):
        return ["l", os.readlink(path)]
    if stat.S_ISDIR(info.st_mode):
        return ["d"]
    if stat.S_ISREG(info.st_mode):
        return ["f", info.st_size, info.st_mtime_ns]
    return ["?"]


def scan(root):
    found = {}
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = sorted(d for d in dirnames if not skip(d))
        rel = os.path.relpath(dirpath, root)
        rel = "" if rel == "." else rel.replace(os.sep, "/")
        for name in dirnames:
            found[(rel + "/" + name) if rel else name] = ["d"]
        for name in sorted(filenames):
            if skip(name):
                continue
            full = os.path.join(dirpath, name)
            found[(rel + "/" + name) if rel else name] = entry(full)
    return found


def load(path):
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def write(root, out):
    data = scan(root)
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    os.replace(tmp, out)
    return data


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "write":
        write(sys.argv[2], sys.argv[3])
        sys.exit(0)
    sys.stderr.write("usage: manifest.py write ROOT OUT\n")
    sys.exit(2)

#!/usr/bin/env python3
"""Decide which parts of a slice file unmount has to write to the drive.

A slice read off the drive gets SLICE.sums: one SHA-256 per 1 MiB chunk,
taken right after the read. Unmount writes only the chunks whose hash
changed, so adding one album to a full music partition writes the album
and the filesystem blocks that point to it, not the partition.

A slice with no sums was formatted, not read. It is a sparse file, and
only the chunks that hold data are written: what the formatter and the
installer wrote. Its holes were never written by anyone and the drive
keeps whatever it had there, as mkfs on Linux does.

After a successful write the sums describe what the drive now holds, so a
second unmount in the same run is incremental too.

  slice_sums.py write SLICE           hash a slice that was just read
  slice_sums.py plan SLICE RANGES     print the write ranges, stage new sums
  slice_sums.py commit SLICE          the write succeeded, keep the new sums

RANGES is "skip:seek:count ..." in 512-byte sectors, skip being the offset
in the slice.
"""
import errno
import hashlib
import json
import os
import sys

CHUNK = 1 << 20
SECTOR = 512
VERSION = 1


def data_regions(fd, size):
    regions = []
    off = 0
    while off < size:
        try:
            start = os.lseek(fd, off, os.SEEK_DATA)
        except OSError as exc:
            if exc.errno == errno.ENXIO:
                break
            raise
        stop = os.lseek(fd, start, os.SEEK_HOLE)
        regions.append((start, stop))
        off = stop
    return regions


def chunk_has_data(regions, size):
    """One flag per chunk: True if any byte of the chunk is data."""
    count = (size + CHUNK - 1) // CHUNK
    flags = [False] * count
    for start, stop in regions:
        for index in range(start // CHUNK, (stop - 1) // CHUNK + 1):
            flags[index] = True
    return flags


def digests(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        size = os.fstat(fd).st_size
        try:
            flags = chunk_has_data(data_regions(fd, size), size)
        except OSError:
            flags = [True] * ((size + CHUNK - 1) // CHUNK)
        out = []
        for index, has_data in enumerate(flags):
            length = min(CHUNK, size - index * CHUNK)
            if has_data:
                block = os.pread(fd, length, index * CHUNK)
            else:
                block = bytes(length)
            out.append(hashlib.sha256(block).digest())
        return size, flags, out
    finally:
        os.close(fd)


def save(path, size, sums):
    tmp = path + ".tmp"
    with open(tmp, "wb") as fh:
        header = json.dumps({"version": VERSION, "size": size, "chunk": CHUNK}) + "\n"
        fh.write(header.encode())
        fh.write(b"".join(sums))
    os.replace(tmp, path)


def load(path, size):
    try:
        with open(path, "rb") as fh:
            header = json.loads(fh.readline())
            body = fh.read()
    except (OSError, ValueError):
        return None
    if header != {"version": VERSION, "size": size, "chunk": CHUNK}:
        return None
    count = (size + CHUNK - 1) // CHUNK
    if len(body) != 32 * count:
        return None
    return [body[i * 32:(i + 1) * 32] for i in range(count)]


def plan(path, ranges):
    size, flags, sums = digests(path)
    old = load(path + ".sums", size)
    if old is None:
        dirty = flags
    else:
        dirty = [a != b for a, b in zip(sums, old)]
    save(path + ".sums.next", size, sums)
    spans = []
    for index, flag in enumerate(dirty):
        if not flag:
            continue
        lo, hi = index * CHUNK // SECTOR, min(size, (index + 1) * CHUNK) // SECTOR
        if spans and spans[-1][1] == lo:
            spans[-1][1] = hi
        else:
            spans.append([lo, hi])
    out = []
    for item in ranges:
        skip, seek, count = (int(x) for x in item.split(":"))
        for lo, hi in spans:
            a, b = max(lo, skip), min(hi, skip + count)
            if a < b:
                out.append("%d:%d:%d" % (a, seek + a - skip, b - a))
    return out


def main(argv):
    if len(argv) == 3 and argv[1] == "write":
        size, _, sums = digests(argv[2])
        save(argv[2] + ".sums", size, sums)
        return 0
    if len(argv) == 4 and argv[1] == "plan":
        print(" ".join(plan(argv[2], argv[3].split())))
        return 0
    if len(argv) == 3 and argv[1] == "commit":
        if os.path.exists(argv[2] + ".sums.next"):
            os.replace(argv[2] + ".sums.next", argv[2] + ".sums")
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

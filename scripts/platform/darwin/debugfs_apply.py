#!/usr/bin/env python3
"""Apply a debugfs command script to an ext2 image and prove the result.

Two e2fsprogs behaviours matter for the PSBBN root filesystem:

* `ln` does not grow a full directory (every other creating command does):
  make_link() reports "No free space in the directory" and moves on. The
  root filesystem carries about 1200 hard links (terminfo aliases, e2fsprogs
  names), so a full directory block is routine. Failed links are retried
  after `expand_dir` on their parent until none are left.

* `mkdir` and `symlink` write the new inode to disk before they notice the
  name already exists, then roll back only the bitmaps. The zombie inode
  survives if nothing reuses its number and e2fsck reports it as an
  unattached inode. Directories that already exist are therefore never
  re-created, and after every apply the image is checked with e2fsck; a
  zombie that slipped through is cleared, anything else fails the apply.

Usage: debugfs_apply.py IMAGE SCRIPT      apply, then check
       debugfs_apply.py --check IMAGE     check only
Exit status is 0 only when every command succeeded and e2fsck is clean.
On failure only the failing commands and their messages are printed.
"""
import os
import posixpath
import re
import shlex
import subprocess
import sys

MAX_ROUNDS = 12
DIR_FULL = "No free space in the directory"
TOOLDIRS = ("/opt/homebrew/opt/e2fsprogs/sbin", "/usr/local/opt/e2fsprogs/sbin")


def tool(name, env_var=None):
    env = os.environ.get(env_var) if env_var else None
    if env and os.access(env, os.X_OK):
        return env
    for base in TOOLDIRS:
        candidate = os.path.join(base, name)
        if os.access(candidate, os.X_OK):
            return candidate
    sys.stderr.write("%s is not installed (brew install e2fsprogs)\n" % name)
    raise SystemExit(127)


def benign(line):
    if not line or line.startswith("debugfs ") or line.startswith("Allocated inode"):
        return True
    if line.startswith("rm:") and "File not found" in line:
        return True
    if line.startswith("rmdir:") and ("directory not empty" in line or "File not found" in line):
        return True
    if "already exists" in line:
        return True
    if "Operation not permitted while changing ownership" in line:
        return True
    return False


def run(debugfs, image, lines, write=True):
    script = "\n".join(lines) + "\n"
    argv = [debugfs] + (["-w"] if write else []) + ["-f", "/dev/stdin", image]
    proc = subprocess.run(argv, input=script, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return proc.returncode, proc.stdout


def classify(output):
    """Return (failed hard links, other failures) from a -f transcript.

    debugfs echoes every command as `debugfs: <cmd>`; messages follow the
    command that produced them.
    """
    current = None
    full_links = []
    bad = []
    for raw in output.splitlines():
        line = raw.rstrip()
        if line.startswith("debugfs: "):
            current = line[len("debugfs: "):]
            continue
        if benign(line):
            continue
        if line.startswith("make_link:") and DIR_FULL in line and current and current.startswith("ln "):
            full_links.append(current)
            continue
        bad.append((current, line))
    return full_links, bad


def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def args_of(cmd):
    try:
        return shlex.split(cmd)[1:]
    except ValueError:
        return []


def link_parent(cmd):
    args = args_of(cmd)
    if len(args) != 2:
        return None
    parent = posixpath.dirname(args[1])
    return parent or "/"


def existing_paths(debugfs, image, paths):
    """Subset of paths that already resolve in the image (one read-only pass)."""
    if not paths:
        return set()
    rc, out = run(debugfs, image, ["stat %s" % quote(p) for p in paths], write=False)
    found = set()
    current = None
    for raw in out.splitlines():
        line = raw.rstrip()
        if line.startswith("debugfs: stat "):
            args = args_of(line[len("debugfs: "):])
            current = args[0] if args else None
            continue
        if line.startswith("Inode:") and current is not None:
            found.add(current)
    return found


def drop_existing_mkdirs(debugfs, image, lines):
    wanted = []
    for cmd in lines:
        if cmd.startswith("mkdir "):
            args = args_of(cmd)
            if len(args) == 1:
                wanted.append(args[0])
    present = existing_paths(debugfs, image, wanted)
    if not present:
        return lines
    kept = []
    for cmd in lines:
        if cmd.startswith("mkdir "):
            args = args_of(cmd)
            if len(args) == 1 and args[0] in present:
                continue
        kept.append(cmd)
    return kept


def apply(debugfs, image, lines):
    lines = drop_existing_mkdirs(debugfs, image, lines)
    if not lines:
        return 0
    for _round in range(MAX_ROUNDS):
        rc, out = run(debugfs, image, lines)
        full_links, bad = classify(out)
        if bad or (rc != 0 and not full_links):
            sys.stderr.write("debugfs failed on %s (exit %d):\n" % (image, rc))
            for cmd, msg in bad[:40]:
                sys.stderr.write("  %s\n    %s\n" % (cmd or "?", msg))
            if len(bad) > 40:
                sys.stderr.write("  ... %d more\n" % (len(bad) - 40))
            return 1
        if not full_links:
            return 0
        by_parent = {}
        for cmd in full_links:
            parent = link_parent(cmd)
            if parent is None:
                sys.stderr.write("cannot parse hard link command: %s\n" % cmd)
                return 1
            by_parent.setdefault(parent, []).append(cmd)
        lines = []
        for parent, cmds in by_parent.items():
            lines.append("expand_dir " + quote(parent))
            lines.extend(cmds)
    sys.stderr.write("hard links still failing after %d rounds on %s\n" % (MAX_ROUNDS, image))
    return 1


def fsck(image):
    e2fsck = tool("e2fsck", "PSBBN_E2FSCK")
    proc = subprocess.run([e2fsck, "-fn", image], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return proc.returncode, proc.stdout


def zombie_inodes(output):
    found = set(re.findall(r"Unattached (?:zero-length )?inode (\d+)", output))
    found |= set(re.findall(r"Unconnected directory inode (\d+)", output))
    match = re.search(r"Inode bitmap differences:\s*(.*)", output)
    if match:
        for token in match.group(1).split():
            if not token.startswith("+"):
                continue
            token = token[1:].strip("()")
            if "--" in token:
                lo, hi = token.split("--")
                found.update(str(i) for i in range(int(lo), int(hi) + 1))
            else:
                found.add(token)
    return sorted(found, key=int)


def check(image):
    rc, out = fsck(image)
    if rc == 0:
        return 0
    debugfs = tool("debugfs", "PSBBN_DEBUGFS")
    candidates = zombie_inodes(out)
    free = []
    if candidates:
        _rc, probe = run(debugfs, image, ["testi <%s>" % ino for ino in candidates], write=False)
        for ino in candidates:
            if re.search(r"Inode %s is not in use" % ino, probe):
                free.append(ino)
    if free:
        run(debugfs, image, ["clri <%s>" % ino for ino in free])
        rc, out = fsck(image)
        if rc == 0:
            return 0
    sys.stderr.write("e2fsck is not clean on %s (exit %d):\n" % (image, rc))
    for line in out.splitlines():
        if line and not line.startswith("Pass ") and not line.startswith("e2fsck "):
            sys.stderr.write("  %s\n" % line)
    return 1


def main(argv):
    if len(argv) == 3 and argv[1] == "--check":
        return check(argv[2])
    if len(argv) != 3:
        sys.stderr.write("usage: debugfs_apply.py IMAGE SCRIPT | --check IMAGE\n")
        return 2
    image, script_path = argv[1], argv[2]
    debugfs = tool("debugfs", "PSBBN_DEBUGFS")
    with open(script_path, encoding="utf-8") as fh:
        lines = [line.rstrip("\n") for line in fh if line.strip()]
    rc = apply(debugfs, image, lines)
    if rc != 0:
        return rc
    return check(image)


if __name__ == "__main__":
    sys.exit(main(sys.argv))

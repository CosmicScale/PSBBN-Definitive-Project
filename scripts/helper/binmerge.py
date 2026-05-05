#!/usr/bin/env python3
#
#  binmerge
#
#  Takes a cue sheet with multiple binary track files and merges them together,
#  generating a corrected cue sheet in the process.
#
#  Copyright (C) 2024 Chris Putnam
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#
#  Please report any bugs on GitHub: https://github.com/putnam/binmerge
#
#
import argparse
import re
import os
import sys
import textwrap
import traceback
VERBOSE = False
VERSION_STRING = "1.0.3"

def print_license():
  print(textwrap.dedent(f"""
    binmerge {VERSION_STRING}
    Copyright (C) 2024 Chris Putnam

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

    Source code available at: https://github.com/putnam/binmerge
  """))

def d(s):
  if VERBOSE:
    print("[DEBUG]\t%s" % s)

def e(s):
  print("[ERROR]\t%s" % s)

def p(s):
  print("[INFO]\t%s" % s)

class Track:
  globalBlocksize = None

  def __init__(self, num, track_type):
    self.num = num
    self.indexes = []
    self.track_type = track_type
    self.sectors = None
    self.file_offset = None

    # All possible blocksize types. You cannot mix types on a disc, so we will use the first one we see and lock it in.
    #
    # AUDIO – Audio/Music (2352)
    # CDG – Karaoke CD+G (2448)
    # MODE1/2048 – CDROM Mode1 Data (cooked)
    # MODE1/2352 – CDROM Mode1 Data (raw)
    # MODE2/2336 – CDROM-XA Mode2 Data
    # MODE2/2352 – CDROM-XA Mode2 Data
    # CDI/2336 – CDI Mode2 Data
    # CDI/2352 – CDI Mode2 Data
    if not Track.globalBlocksize:
      if track_type in ['AUDIO', 'MODE1/2352', 'MODE2/2352', 'CDI/2352']:
        Track.globalBlocksize = 2352
      elif track_type == 'CDG':
        Track.globalBlocksize = 2448
      elif track_type == 'MODE1/2048':
        Track.globalBlocksize = 2048
      elif track_type in ['MODE2/2336', 'CDI/2336']:
        Track.globalBlocksize = 2336
      d("Locked blocksize to %d" % Track.globalBlocksize)

class File:
  def __init__(self, filename):
    self.filename = filename
    self.tracks = []
    self.size = os.path.getsize(filename)

class ZeroBinFilesException(Exception):
  pass

class BinFilesMissingException(Exception):
  pass

def read_cue_file(cue_path):
  files = []
  this_track = None
  this_file = None
  bin_files_missing = False

  f = open(cue_path, 'r')
  for line in f:
    m = re.search(r'FILE "?(.*?)"? BINARY', line)
    if m:
      this_path = os.path.join(os.path.dirname(cue_path), m.group(1))
      if not (os.path.isfile(this_path) or os.access(this_path, os.R_OK)):
        e("Bin file not found or not readable: %s" % this_path)
        bin_files_missing = True
      else:
        this_file = File(this_path)
        files.append(this_file)
      continue

    m = re.search(r'TRACK (\d+) ([^\s]*)', line)
    if m and this_file:
      this_track = Track(int(m.group(1)), m.group(2))
      this_file.tracks.append(this_track)
      continue

    m = re.search(r'INDEX (\d+) (\d+:\d+:\d+)', line)
    if m and this_track:
      this_track.indexes.append({'id': int(m.group(1)), 'stamp': m.group(2), 'file_offset':cuestamp_to_sectors(m.group(2))})
      continue

  if bin_files_missing:
    raise BinFilesMissingException

  if not len(files):
    raise ZeroBinFilesException

  if len(files) == 1:
    # only 1 file, assume splitting, calc sectors of each
    next_item_offset = files[0].size // Track.globalBlocksize
    for t in reversed(files[0].tracks):
      t.sectors = next_item_offset - t.indexes[0]["file_offset"]
      next_item_offset = t.indexes[0]["file_offset"]

  for f in files:
    d("-- File --")
    d("Filename: %s" % f.filename)
    d("Size: %d" % f.size)
    d("Tracks:")

    for t in f.tracks:
      d("  -- Track --")
      d("  Num: %d" % t.num)
      d("  Type: %s" % t.track_type)
      if t.sectors: d("  Sectors: %s" % t.sectors)
      d("  Indexes: %s" % repr(t.indexes))

  return files


def sectors_to_cuestamp(sectors):
  # 75 sectors per second
  minutes = sectors / 4500
  fields = sectors % 4500
  seconds = fields / 75
  fields = sectors % 75
  return '%02d:%02d:%02d' % (minutes, seconds, fields)

def cuestamp_to_sectors(stamp):
  # 75 sectors per second
  m = re.match(r"(\d+):(\d+):(\d+)", stamp)
  minutes = int(m.group(1))
  seconds = int(m.group(2))
  fields = int(m.group(3))
  return fields + (seconds * 75) + (minutes * 60 * 75)

# Generates track filename based on redump naming convention
# (Note: prefix should NEVER contain a path; this function deals only in filenames)
def track_filename(prefix, track_num, track_count):
  # Redump is strangely inconsistent in their datfiles and cuesheets when it
  # comes to track numbers. The naming convention currently seems to be:
  # If there is exactly one track: "" (nothing)
  # If there are less than 10 tracks: "Track 1", "Track 2", etc.
  # If there are more than 10 tracks: "Track 01", "Track 02", etc.
  #
  # It'd be nice if it were consistently %02d!
  #
  # TODO: Migrate everything to pathlib
  if track_count == 1:
    return "%s.bin" % (prefix)
  if track_count > 9:
    return "%s (Track %02d).bin" % (prefix, track_num)
  return "%s (Track %d).bin" % (prefix, track_num)

# Generates a 'merged' cuesheet, that is, one bin file with tracks indexed within.
def gen_merged_cuesheet(basename, files):
  cuesheet = 'FILE "%s.bin" BINARY\n' % basename
  # One sector is (BLOCKSIZE) bytes
  sector_pos = 0
  for f in files:
    for t in f.tracks:
      cuesheet += '  TRACK %02d %s\n' % (t.num, t.track_type)
      for i in t.indexes:
        cuesheet += '    INDEX %02d %s\n' % (i['id'], sectors_to_cuestamp(sector_pos + i['file_offset']))
    sector_pos += f.size / Track.globalBlocksize
  return cuesheet

# Generates a 'split' cuesheet, that is, with one bin file for every track.
def gen_split_cuesheet(basename, merged_file):
  cuesheet = ""
  for t in merged_file.tracks:
    track_fn = track_filename(basename, t.num, len(merged_file.tracks))
    cuesheet += 'FILE "%s" BINARY\n' % track_fn
    cuesheet += '  TRACK %02d %s\n' % (t.num, t.track_type)
    for i in t.indexes:
      sector_pos = i['file_offset'] - t.indexes[0]['file_offset']
      cuesheet += '    INDEX %02d %s\n' % (i['id'], sectors_to_cuestamp(sector_pos))
  return cuesheet

# Merges files together to new file `merged_filename`, in listed order.
def merge_files(merged_filename, files):
  if os.path.exists(merged_filename):
    e('Target merged bin path already exists: %s' % merged_filename)
    return False

  # cat is actually a bit faster, but this is multi-platform and no special-casing
  chunksize = 1024 * 1024
  with open(merged_filename, 'wb') as outfile:
    for f in files:
      with open(f.filename, 'rb') as infile:
        while True:
          chunk = infile.read(chunksize)
          if not chunk:
            break
          outfile.write(chunk)
  return True

# Writes each track in a File to a new file
def split_files(new_basename, merged_file, outdir):
  with open(merged_file.filename, 'rb') as infile:
    # Check all tracks for potential file-clobbering first before writing anything
    for t in merged_file.tracks:
      out_basename = track_filename(new_basename, t.num, len(merged_file.tracks))
      out_path = os.path.join(outdir, out_basename)
      if os.path.exists(out_path):
        e('Target bin path already exists: %s' % out_path)
        return False

    for t in merged_file.tracks:
      chunksize = 1024 * 1024
      out_basename = track_filename(new_basename, t.num, len(merged_file.tracks))
      out_path = os.path.join(outdir, out_basename)
      tracksize = t.sectors * Track.globalBlocksize
      written = 0
      with open(out_path, 'wb') as outfile:
        d('Writing bin file: %s' % out_path)
        while True:
          if chunksize + written > tracksize:
            chunksize = tracksize - written
          chunk = infile.read(chunksize)
          outfile.write(chunk)
          written += chunksize
          if written == tracksize:
            break
  return True

def main():
  parser = argparse.ArgumentParser(description="Using a cuesheet, merges numerous bin files into a single bin file and produces a new cuesheet with corrected offsets. Works great with Redump. Supports all block modes, but only binary track types.")
  parser.add_argument('cuefile', help='path to current cue file (bin files are expected in the same dir)')
  parser.add_argument('basename', help='name (without extension) for your new bin/cue files; will be placed in the same dir as input unless --outdir is specified')

  # argparse is bad. make -l work like -h (no args required)
  class licenseAction(argparse._StoreTrueAction):
    def __call__(self, parser, namespace, values, option_string=None):
      print_license()
      parser.exit()
  parser.add_argument('-l', '--license', default=False, help='prints license info and exits', action=licenseAction)
  parser.add_argument('-v', '--verbose', action='store_true', help='print more verbose messages')
  parser.add_argument('-s', '--split', help='reverses operation, splitting merged files back to individual tracks', required=False, action='store_true')
  parser.add_argument('-o', '--outdir', default=False, help='output directory. defaults to the same directory as source cue. directory will be created (recursively) if needed.')

  args = parser.parse_args()

  if args.verbose:
    global VERBOSE
    VERBOSE = True

  # Resolve relative paths and cwd
  cuefile = os.path.abspath(args.cuefile)

  if not os.path.exists(cuefile):
    e("Cue file does not exist: %s" % cuefile)
    return False

  if not os.access(cuefile, os.R_OK):
    e("Cue file is not readable: %s" % cuefile)
    return False

  if args.outdir:
    outdir = os.path.abspath(args.outdir)
    p("Output directory: %s" % outdir)
    if not os.path.exists(outdir):
      try:
        p("Output directory did not exist; creating it.")
        os.makedirs(outdir)
      except:
        e("Could not create output directory (permissions?)")
        traceback.print_exc()
        return False
  else:
    outdir = os.path.dirname(cuefile)
    p("Output directory: %s" % outdir)

  if not (os.path.exists(outdir) or os.path.isdir(outdir)):
    e("Output directory does not exist or is not a directory: %s" % outdir)
    return False

  if not os.access(outdir, os.W_OK):
    e("Output directory is not writable: %s" % outdir)
    return False

  p("Opening cue: %s" % cuefile)
  try:
    cue_map = read_cue_file(cuefile)
  except BinFilesMissingException:
    e("One or more bin files were missing on disk. Aborting.")
    return False
  except ZeroBinFilesException:
    e("Unable to parse any bin files in the cuesheet. Is it empty?")
    return False
  except Exception:
    e("Error parsing cuesheet. Is it valid?")
    traceback.print_exc()
    return False

  if args.split:
    cuesheet = gen_split_cuesheet(args.basename, cue_map[0])
  else:
    cuesheet = gen_merged_cuesheet(args.basename, cue_map)

  if not os.path.exists(args.outdir):
    e("Output dir does not exist")
    return False

  new_cue_fn = os.path.join(outdir, args.basename+'.cue')
  if os.path.exists(new_cue_fn):
    e("Output cue file already exists. Quitting. Path: %s" % new_cue_fn)
    return False

  if args.split:
    p("Splitting files...")
    if split_files(args.basename, cue_map[0], outdir):
      p("Wrote %d bin files" % len(cue_map[0].tracks))
    else:
      e("Unable to split bin files.")
      return False
  else:
    p("Merging %d tracks..." % len(cue_map))
    out_path = os.path.join(outdir, args.basename+'.bin')
    if merge_files(out_path, cue_map):
      p("Wrote %s" % out_path)
    else:
      e("Unable to merge bin files.")
      return False

  with open(new_cue_fn, 'w', newline='\r\n') as f:
    f.write(cuesheet)
  p("Wrote new cue: %s" % new_cue_fn)

  return True

if not main():
  sys.exit(1)

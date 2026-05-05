#!/usr/bin/env python3
"""
UDPFS Server over UDPRDMA

Unified server for PS2 file and block device access.
UDPBD is a subset of UDPFS using block I/O messages (BREAD/BWRITE/INFO).

Usage:
    python udpfs_server.py --block-device disk.iso
    python udpfs_server.py --root-dir /path/to/serve
    python udpfs_server.py --block-device disk.iso --root-dir /path/to/serve

Examples:
    python udpfs_server.py -b game.iso                # Block device only (UDPBD mode)
    python udpfs_server.py -d /home/user/ps2games      # Filesystem only
    python udpfs_server.py -b game.iso -d /games        # Both block device and filesystem
    python udpfs_server.py -b game.iso --sector-size 2048  # Custom sector size
    python udpfs_server.py -b game.iso --read-only      # Read-only mode
    python udpfs_server.py -d /games --enable-compression  # Transparent .zso/.cso/.chd decompression

Compression Support:
    With --enable-compression, the server transparently decompresses .zso (LZ4),
    .cso (zlib), and .chd (MAME CHD v5) files. Compressed files appear as .iso in
    directory listings.
    Requires 'lz4' package for ZSO support: pip install lz4
"""

import argparse
import errno
import math
import os
import socket
import struct
import sys
import time
from dataclasses import dataclass
from enum import IntEnum
from typing import Dict, List, Optional, Tuple

# Compressed ISO support
from compressed_iso import CompressedFileWrapper, ZsoFileWrapper, CsoFileWrapper, ChdFileWrapper, LIBCHDR_AVAILABLE

# Check LZ4 availability for ZSO format
try:
    import lz4
    LZ4_AVAILABLE = True
except ImportError:
    LZ4_AVAILABLE = False


# UDPRDMA Protocol Constants
UDPFS_PORT = 0xF5F6
UDPRDMA_SVC_UDPFS = 0xF5F5

# UDPRDMA Packet Types
class PacketType(IntEnum):
    DISCOVERY = 0
    INFORM = 1
    DATA = 2

# UDPRDMA Data Flags
class DataFlags(IntEnum):
    ACK = 1
    FIN = 2

# UDPFS Message Types (unified protocol - includes UDPBD subset)
class MsgType(IntEnum):
    # File operations
    OPEN_REQ      = 0x10
    OPEN_REPLY    = 0x11
    CLOSE_REQ     = 0x12
    CLOSE_REPLY   = 0x13
    READ_REQ      = 0x14
    WRITE_REQ     = 0x16
    WRITE_DATA    = 0x17
    WRITE_DONE    = 0x18
    LSEEK_REQ     = 0x1A
    LSEEK_REPLY   = 0x1B
    DREAD_REQ     = 0x1C
    DREAD_REPLY   = 0x1D
    GETSTAT_REQ   = 0x1E
    GETSTAT_REPLY = 0x1F
    MKDIR_REQ     = 0x20
    REMOVE_REQ    = 0x22
    RMDIR_REQ     = 0x24
    RESULT_REPLY  = 0x26
    # Block I/O operations (UDPBD subset)
    BREAD_REQ     = 0x28
    BWRITE_REQ    = 0x2A

# PS2 file mode flags
FIO_S_IFREG = 0x2000
FIO_S_IFDIR = 0x1000

# Limits
MAX_DATA_PAYLOAD = 1408  # Maximum UDPRDMA payload
MAX_HANDLES = 32

# Flow control
SEND_WINDOW = 8           # Max unacked packets in flight
WINDOW_ACK_TIMEOUT = 0.1  # Seconds to wait for window ACK
MAX_WINDOW_RETRIES = 4    # Max retries waiting for window ACK (matches IOP)

# Fixed handle for block device
BLOCK_DEVICE_HANDLE = 0

# Compressed file format constants (for get_compressed_info)
ZSO_MAGIC = b'ZSO\x00'
CSO_MAGIC = 0x4F534943  # "CISO"


def open_compressed(file_path: str, cache_size: int = None) -> Optional[CompressedFileWrapper]:
    """Open a compressed file and return appropriate wrapper based on extension.
    
    Args:
        file_path: Path to the file
        cache_size: Number of blocks to cache (default: 32)
        
    Returns:
        CompressedFileWrapper subclass instance, or None if unsupported format
    """
    ext = os.path.splitext(file_path)[1].lower()
    
    if ext == '.zso':
        if not LZ4_AVAILABLE:
            return None
        return ZsoFileWrapper(file_path, cache_size)
    elif ext == '.cso':
        return CsoFileWrapper(file_path, cache_size)
    elif ext == '.chd':
        return ChdFileWrapper(file_path, cache_size)
    
    return None


def get_compressed_info(file_path: str) -> Optional[Tuple[int, str]]:
    """
    Get info about a compressed file without fully opening it.
    Returns (uncompressed_size, format_name) or None if not a supported compressed file.
    """
    ext = os.path.splitext(file_path)[1].lower()
    
    try:
        with open(file_path, 'rb') as f:
            if ext == '.chd':
                # CHD has different header structure
                header = f.read(64)
                if len(header) < 64:
                    return None
                
                # Check CHD magic "MComprHD"
                magic = header[0:8]
                if magic != b'MComprHD':
                    return None
                
                # Check version (only v5 supported)
                version = struct.unpack('>I', header[12:16])[0]
                if version != 5:
                    return None
                
                # Uncompressed size is at offset 32 (big-endian uint64 in v5)
                uncompressed_size = struct.unpack('>Q', header[32:40])[0]
                compressors = struct.unpack('>4I', header[16:32])
                hunk_size = struct.unpack('>I', header[56:60])[0]

                # For CD-format CHDs (cdlz/cdzl/cdfl), the stored uncompressed_size
                # counts full 2448-byte CD frames (2352 sector + 96 subcode).
                # We present as 2048-byte/sector ISO, so correct the size.
                _CD_FRAME_SIZE = 2448
                _CD_CODECS = (0x63646c7a, 0x63647a6c, 0x6364666c)  # cdlz, cdzl, cdfl
                if (any(c in _CD_CODECS for c in compressors if c != 0)
                        and hunk_size > 0 and hunk_size % _CD_FRAME_SIZE == 0):
                    frames_per_hunk = hunk_size // _CD_FRAME_SIZE
                    total_hunks = (uncompressed_size + hunk_size - 1) // hunk_size
                    uncompressed_size = total_hunks * frames_per_hunk * 2048

                return (uncompressed_size, 'CHD')
            
            header = f.read(24)
            if len(header) < 16:
                return None
            
            magic = header[0:4]
            magic_int = struct.unpack('<I', magic)[0]
            
            if ext == '.zso':
                if magic == ZSO_MAGIC:
                    uncompressed_size = struct.unpack('<Q', header[8:16])[0]
                    return (uncompressed_size, 'ZSO')
                elif magic == b'ZISO':
                    uncompressed_size = struct.unpack('<Q', header[8:16])[0]
                    return (uncompressed_size, 'ZISO')
            elif ext == '.cso':
                if magic_int == CSO_MAGIC:
                    uncompressed_size = struct.unpack('<Q', header[8:16])[0]
                    return (uncompressed_size, 'CSO')
    except (IOError, struct.error):
        pass
    
    return None


@dataclass
class Header:
    """UDPRDMA base header (2 bytes)"""
    packet_type: int  # 4 bits
    seq_nr: int       # 12 bits

    @classmethod
    def unpack(cls, data: bytes) -> 'Header':
        val = struct.unpack('<H', data[:2])[0]
        return cls(
            packet_type=val & 0xF,
            seq_nr=(val >> 4) & 0xFFF
        )

    def pack(self) -> bytes:
        val = (self.packet_type & 0xF) | ((self.seq_nr & 0xFFF) << 4)
        return struct.pack('<H', val)


@dataclass
class DiscHeader:
    """Discovery/Inform header (4 bytes)"""
    service_id: int
    reserved: int = 0

    @classmethod
    def unpack(cls, data: bytes) -> 'DiscHeader':
        service_id, reserved = struct.unpack('<HH', data[:4])
        return cls(service_id=service_id, reserved=reserved)

    def pack(self) -> bytes:
        return struct.pack('<HH', self.service_id, self.reserved)


@dataclass
class DataHeader:
    """Data header (4 bytes)"""
    seq_nr_ack: int       # 12 bits
    flags: int            # 2 bits
    hdr_word_count: int   # 4 bits: app header size in 4-byte words
    data_byte_count: int  # 14 bits: data payload size

    @classmethod
    def unpack(cls, data: bytes) -> 'DataHeader':
        val = struct.unpack('<I', data[:4])[0]
        return cls(
            seq_nr_ack=val & 0xFFF,
            flags=(val >> 12) & 0x3,
            hdr_word_count=(val >> 14) & 0xF,
            data_byte_count=(val >> 18) & 0x3FFF
        )

    def pack(self) -> bytes:
        val = ((self.seq_nr_ack & 0xFFF) |
               ((self.flags & 0x3) << 12) |
               ((self.hdr_word_count & 0xF) << 14) |
               ((self.data_byte_count & 0x3FFF) << 18))
        return struct.pack('<I', val)


class FileHandle:
    """Represents an open file handle on the server"""
    def __init__(self, obj, is_dir: bool = False):
        self.obj = obj
        self.is_dir = is_dir

    def close(self):
        if self.is_dir:
            pass  # Directory entries are a list, nothing to close
        else:
            self.obj.close()


class UdpfsServer:
    """UDPFS Server over UDPRDMA - unified file and block device server"""

    def __init__(self, root_dir: Optional[str] = None,
                 block_device: Optional[str] = None,
                 port: int = UDPFS_PORT,
                 sector_size: int = 512,
                 read_only: bool = False, verbose: bool = False,
                 enable_compression: bool = False,
                 compression_cache_size: int = 32):
        self.root_dir = os.path.realpath(root_dir) if root_dir else None
        self.port = port
        self.sector_size = sector_size
        self.read_only = read_only
        self.verbose = verbose
        self.enable_compression = enable_compression
        self.compression_cache_size = compression_cache_size

        if self.root_dir and not os.path.isdir(self.root_dir):
            print(f"Error: '{root_dir}' is not a directory")
            sys.exit(1)

        # Create UDP socket
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.sock.bind(('', port))

        # Protocol state
        self.peer_addr: Optional[Tuple[str, int]] = None
        self.tx_seq_nr = 0
        self.tx_seq_nr_acked = 0  # Last ACKed seq (for send window)
        self.rx_seq_nr_expected = 0

        # TX buffer for retransmit
        self.tx_buffer: List[Tuple[int, bytes]] = []
        self.tx_start_seq = 0

        # Handle management - dynamic handles start from 1
        self.handles: Dict[int, FileHandle] = {}
        self.next_handle = 1

        # Block device setup (handle 0)
        self.bd_sector_size = sector_size
        self.bd_sector_count = 0
        if block_device:
            mode = 'rb' if read_only else 'r+b'
            try:
                bd_file = open(block_device, mode)
            except IOError as e:
                print(f"Error: Cannot open '{block_device}': {e}")
                sys.exit(1)
            bd_file.seek(0, os.SEEK_END)
            bd_size = bd_file.tell()
            bd_file.seek(0)
            self.bd_sector_count = bd_size // sector_size
            self.handles[BLOCK_DEVICE_HANDLE] = FileHandle(bd_file, is_dir=False)

        # Write state (shared between file writes and block writes)
        self.write_handle = -1
        self.write_is_block = False
        self.write_sector_nr = 0
        self.write_sector_count = 0
        self.write_data = bytearray()
        self.write_total_chunks = 0
        self.write_received_chunks = 0

        # Statistics
        self.stats = {
            'discovery': 0,
            'open': 0,
            'close': 0,
            'read': 0,
            'write': 0,
            'bread': 0,
            'bwrite': 0,
            'lseek': 0,
            'dread': 0,
            'getstat': 0,
            'mkdir': 0,
            'remove': 0,
            'rmdir': 0,
            'bytes_read': 0,
            'bytes_written': 0,
        }

        # Live status line
        self._start_time = time.monotonic()
        self._last_status_time = 0.0
        self._last_status_bytes = 0
        self._status_visible = False

    def run(self):
        """Main server loop"""
        print("UDPFS Server")
        if self.root_dir:
            print(f"  Root: {self.root_dir}")
        if BLOCK_DEVICE_HANDLE in self.handles:
            print(f"  Block device: handle={BLOCK_DEVICE_HANDLE}, "
                  f"sectors={self.bd_sector_count:,}, "
                  f"sector_size={self.bd_sector_size}")
        print(f"  Port: {self.port} (0x{self.port:04X})")
        print(f"  Mode: {'read-only' if self.read_only else 'read-write'}")
        if self.enable_compression:
            formats = []
            if LZ4_AVAILABLE:
                formats.append('ZSO')
            formats.append('CSO')
            formats.append('CHD')
            print(f"  Compression: enabled ({', '.join(formats)})")
        print("  Listening...")
        print()

        while True:
            try:
                data, addr = self.sock.recvfrom(2048)
                self._handle_packet(data, addr)
            except KeyboardInterrupt:
                if self._status_visible:
                    sys.stdout.write(f"\r{'':<79}\r")
                print("\nShutting down...")
                self._cleanup()
                self._print_stats()
                break

    def _format_bytes(self, n: int) -> str:
        """Format byte count as human-readable string"""
        if n < 1024:
            return f"{n} B"
        elif n < 1024 * 1024:
            return f"{n / 1024:.1f} KB"
        elif n < 1024 * 1024 * 1024:
            return f"{n / (1024 * 1024):.1f} MB"
        else:
            return f"{n / (1024 * 1024 * 1024):.1f} GB"

    def _update_status(self):
        """Update in-place status line (throttled to 1/sec)"""
        now = time.monotonic()
        if now - self._last_status_time < 1.0:
            return
        elapsed = now - self._start_time
        dt = now - self._last_status_time if self._last_status_time else elapsed
        bytes_delta = self.stats['bytes_read'] + self.stats['bytes_written'] - self._last_status_bytes

        # Build compact op counts (only non-zero)
        ops = []
        for key in ('bread', 'read', 'write', 'bwrite', 'open', 'close', 'dread', 'getstat', 'lseek'):
            v = self.stats[key]
            if v > 0:
                ops.append(f"{key}:{v:,}")
        op_str = ' '.join(ops) if ops else 'idle'

        # Throughput
        rate = bytes_delta / dt if dt > 0 else 0
        total_bytes = self.stats['bytes_read'] + self.stats['bytes_written']
        h, rem = divmod(int(elapsed), 3600)
        m, s = divmod(rem, 60)

        line = f"[{h:02d}:{m:02d}:{s:02d}] {op_str} | {self._format_bytes(total_bytes)} @ {self._format_bytes(int(rate))}/s"
        sys.stdout.write(f"\r{line:<79}")
        sys.stdout.flush()

        self._last_status_time = now
        self._last_status_bytes = total_bytes
        self._status_visible = True

    def _print_event(self, msg: str):
        """Print an event message, clearing the status line first"""
        if self._status_visible:
            sys.stdout.write(f"\r{'':<79}\r")
            self._status_visible = False
        print(msg)

    def _cleanup(self):
        """Close all open handles"""
        for handle_id, fh in self.handles.items():
            try:
                fh.close()
            except Exception:
                pass
        self.handles.clear()

    def _resolve_path(self, client_path: str) -> Optional[str]:
        """Resolve client path to absolute path within root_dir."""
        if self.root_dir is None:
            return None

        # Strip leading slashes
        while client_path.startswith('/') or client_path.startswith('\\'):
            client_path = client_path[1:]

        # Normalize separators
        client_path = client_path.replace('\\', '/')
        
        # Resolve
        resolved = os.path.realpath(os.path.join(self.root_dir, client_path))

        # Ensure within root
        if not resolved.startswith((self.root_dir + os.sep).replace('\\\\', '\\')) and resolved != self.root_dir:
            return None

        return resolved

    def _transform_compressed_name(self, name: str) -> str:
        """Transform .zso/.cso/.chd extensions to .iso for directory listing."""
        if not self.enable_compression:
            return name
        lower_name = name.lower()
        for ext in ['.zso', '.cso', '.chd']:
            if lower_name.endswith(ext):
                return name[:-len(ext)] + '.iso'
        return name

    def _find_compressed_version(self, iso_path: str) -> Optional[str]:
        """Check if a compressed version of the ISO exists."""
        if not self.enable_compression:
            return None
        if not iso_path.lower().endswith('.iso'):
            return None
        for ext in ['.zso', '.cso', '.chd']:
            compressed = iso_path[:-4] + ext
            if os.path.exists(compressed):
                return compressed
        return None

    def _get_compressed_stat(self, file_path: str, original_stat) -> Optional[dict]:
        """Get stat info for a compressed file, returning uncompressed size."""
        info = get_compressed_info(file_path)
        if info is None:
            return None
        
        uncompressed_size, format_name = info
        return {
            'mode': FIO_S_IFREG,
            'attr': 0,
            'size': uncompressed_size & 0xFFFFFFFF,
            'hisize': (uncompressed_size >> 32) & 0xFFFFFFFF,
            'ctime': self._encode_time(original_stat.st_ctime),
            'atime': self._encode_time(original_stat.st_atime),
            'mtime': self._encode_time(original_stat.st_mtime),
        }
        # Resolve
        resolved = os.path.realpath(os.path.join(self.root_dir, client_path))

        # Ensure within root
        if not resolved.startswith((self.root_dir + os.sep).replace('\\\\', '\\')) and resolved != self.root_dir:
            return None

        return resolved

    def _alloc_handle(self, obj, is_dir: bool = False) -> int:
        """Allocate a new handle"""
        if len(self.handles) >= MAX_HANDLES:
            return -errno.EMFILE

        handle_id = self.next_handle
        self.next_handle += 1
        self.handles[handle_id] = FileHandle(obj, is_dir)
        return handle_id

    def _free_handle(self, handle_id: int):
        """Free a handle"""
        # Block device handle cannot be closed
        if handle_id == BLOCK_DEVICE_HANDLE:
            return
        if handle_id in self.handles:
            try:
                self.handles[handle_id].close()
            except Exception:
                pass
            del self.handles[handle_id]

    def _encode_time(self, timestamp: float) -> bytes:
        """Encode Unix timestamp to PS2 iox_stat_t time format (8 bytes)."""
        try:
            t = time.localtime(timestamp)
            return struct.pack('<BBBBBBH',
                0,           # unused
                t.tm_sec,
                t.tm_min,
                t.tm_hour,
                t.tm_mday,
                t.tm_mon,
                t.tm_year
            )
        except (OSError, ValueError):
            return b'\x00' * 8

    def _stat_to_bytes(self, st) -> dict:
        """Convert os.stat_result to PS2-compatible stat fields"""
        import stat as stat_mod
        mode = 0
        if stat_mod.S_ISREG(st.st_mode):
            mode = FIO_S_IFREG
        elif stat_mod.S_ISDIR(st.st_mode):
            mode = FIO_S_IFDIR

        return {
            'mode': mode,
            'attr': 0,
            'size': st.st_size & 0xFFFFFFFF,
            'hisize': (st.st_size >> 32) & 0xFFFFFFFF,
            'ctime': self._encode_time(st.st_ctime),
            'atime': self._encode_time(st.st_atime),
            'mtime': self._encode_time(st.st_mtime),
        }

    def _flags_to_mode(self, flags: int) -> str:
        """Convert PS2 open flags to Python file mode"""
        access = flags & 0x03
        if access == 0x01:  # O_RDONLY
            return 'rb'
        elif access == 0x02:  # O_WRONLY
            if flags & 0x0100:  # O_APPEND
                return 'ab'
            elif flags & 0x0400:  # O_TRUNC
                return 'wb'
            elif flags & 0x0200:  # O_CREAT
                return 'wb'
            else:
                return 'r+b'
        elif access == 0x03:  # O_RDWR
            if flags & 0x0200:  # O_CREAT
                if flags & 0x0400:  # O_TRUNC
                    return 'w+b'
                else:
                    return 'a+b' if (flags & 0x0100) else 'r+b'
            else:
                return 'r+b'
        return 'rb'

    # --- UDPRDMA packet handling ---

    def _handle_packet(self, data: bytes, addr: Tuple[str, int]):
        """Handle incoming UDPRDMA packet"""
        if len(data) < 2:
            return

        hdr = Header.unpack(data)

        if hdr.packet_type == PacketType.DISCOVERY:
            self._handle_discovery(data, addr, hdr)
        elif hdr.packet_type == PacketType.DATA:
            self._handle_data(data, addr, hdr)

    def _handle_discovery(self, data: bytes, addr: Tuple[str, int], hdr: Header):
        """Handle DISCOVERY packet"""
        if len(data) < 6:
            return

        disc = DiscHeader.unpack(data[2:6])

        if disc.service_id != UDPRDMA_SVC_UDPFS:
            return

        self.stats['discovery'] += 1
        self.peer_addr = addr
        self.rx_seq_nr_expected = (hdr.seq_nr + 1) & 0xFFF

        self._print_event(f"[{addr[0]}:{addr[1]}] DISCOVERY -> INFORM")

        self._send_inform(addr)
        # Initialize acked to just before current tx_seq (INFORM consumed one)
        self.tx_seq_nr_acked = (self.tx_seq_nr - 1) & 0xFFF

    def _handle_data(self, data: bytes, addr: Tuple[str, int], hdr: Header):
        """Handle DATA packet containing UDPFS message"""
        if len(data) < 6:
            return

        data_hdr = DataHeader.unpack(data[2:6])
        payload = data[6:]
        hdr_size = data_hdr.hdr_word_count * 4
        payload_size = hdr_size + data_hdr.data_byte_count
        actual_payload = payload[:payload_size] if payload_size > 0 else b''

        # Process piggybacked ACK from any packet with ACK flag
        if data_hdr.flags & DataFlags.ACK:
            self.tx_seq_nr_acked = data_hdr.seq_nr_ack
            if self.tx_buffer:
                self.tx_buffer = [
                    (seq, pkt) for seq, pkt in self.tx_buffer
                    if ((seq - data_hdr.seq_nr_ack - 1) & 0xFFF) < 2048
                ]

        # Pure ACK (no payload) - done
        if payload_size == 0 and (data_hdr.flags & DataFlags.ACK):
            return

        # Handle NACK - update acked position and retransmit
        if payload_size == 0 and not (data_hdr.flags & DataFlags.ACK):
            # NACK seq_nr_ack = expected seq, so acked up to expected-1
            self.tx_seq_nr_acked = (data_hdr.seq_nr_ack - 1) & 0xFFF
            if self.verbose:
                self._print_event(f"  NACK received, retransmit from seq={data_hdr.seq_nr_ack}")
            self._retransmit_from(addr, data_hdr.seq_nr_ack)
            return

        # Check sequence number
        if hdr.seq_nr != self.rx_seq_nr_expected:
            prev_seq = (self.rx_seq_nr_expected - 1) & 0xFFF
            if hdr.seq_nr == prev_seq:
                # Duplicate of last processed packet - re-ACK and retransmit response
                if self.verbose:
                    self._print_event(f"  Duplicate seq={hdr.seq_nr}, re-ACK + retransmit")
                self._send_ack(addr, is_ack=True)
                if self.tx_buffer:
                    self._retransmit_from(addr, self.tx_buffer[0][0])
            else:
                if self.verbose:
                    self._print_event(f"  WARNING: Expected seq={self.rx_seq_nr_expected}, got {hdr.seq_nr}")
                self._send_ack(addr, is_ack=False)
            return

        self.rx_seq_nr_expected = (self.rx_seq_nr_expected + 1) & 0xFFF

        # Immediate ACK - lets PS2's udprdma_send() return quickly,
        # so it can enter udprdma_recv() (5s timeout) while we process
        self._send_ack(addr, is_ack=True)

        if len(actual_payload) == 0:
            return

        msg_type = actual_payload[0]

        # File operations
        if msg_type == MsgType.OPEN_REQ:
            self._handle_open(addr, actual_payload)
        elif msg_type == MsgType.CLOSE_REQ:
            self._handle_close(addr, actual_payload)
        elif msg_type == MsgType.READ_REQ:
            self._handle_read(addr, actual_payload)
        elif msg_type == MsgType.WRITE_REQ:
            self._handle_write_req(addr, actual_payload)
        elif msg_type == MsgType.WRITE_DATA:
            self._handle_write_data(addr, actual_payload)
        elif msg_type == MsgType.LSEEK_REQ:
            self._handle_lseek(addr, actual_payload)
        elif msg_type == MsgType.DREAD_REQ:
            self._handle_dread(addr, actual_payload)
        elif msg_type == MsgType.GETSTAT_REQ:
            self._handle_getstat(addr, actual_payload)
        elif msg_type == MsgType.MKDIR_REQ:
            self._handle_mkdir(addr, actual_payload)
        elif msg_type == MsgType.REMOVE_REQ:
            self._handle_remove(addr, actual_payload)
        elif msg_type == MsgType.RMDIR_REQ:
            self._handle_rmdir(addr, actual_payload)
        # Block I/O operations (UDPBD subset)
        elif msg_type == MsgType.BREAD_REQ:
            self._handle_bread(addr, actual_payload)
        elif msg_type == MsgType.BWRITE_REQ:
            self._handle_bwrite_req(addr, actual_payload)
        else:
            self._print_event(f"[{addr[0]}:{addr[1]}] Unknown message type: 0x{msg_type:02x}")
            self._send_ack(addr, is_ack=True)

    # --- File operation handlers ---

    def _handle_open(self, addr: Tuple[str, int], payload: bytes):
        """Handle OPEN_REQ"""
        if len(payload) < 8:
            self._send_open_reply(addr, -errno.EINVAL)
            return

        _, is_dir, flags, mode = struct.unpack('<BBHi', payload[:8])
        path_bytes = payload[8:]
        path = path_bytes.split(b'\x00')[0].decode('utf-8', errors='replace')

        self.stats['open'] += 1

        resolved = self._resolve_path(path)
        
        # Check for compressed version when .iso is requested but file doesn't exist
        compressed_resolved = None
        if self.enable_compression and path.lower().endswith('.iso'):
            # Check if the .iso file doesn't exist
            if resolved is None or not os.path.exists(resolved):
                base_path = path[:-4]  # Remove .iso
                for ext in ['.zso', '.cso', '.chd']:
                    compressed_path = base_path + ext
                    compressed_resolved = self._resolve_path(compressed_path)
                    if compressed_resolved and os.path.exists(compressed_resolved):
                        break
                    else:
                        compressed_resolved = None
        
        if resolved is None and compressed_resolved is None:
            self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> EACCES (path traversal or no root_dir)")
            self._send_open_reply(addr, -errno.EACCES)
            return

        if is_dir:
            # Directory open
            try:
                entries = list(os.scandir(resolved))
                handle = self._alloc_handle({'entries': entries, 'index': 0}, is_dir=True)
                if handle < 0:
                    self._send_open_reply(addr, handle)
                    return
                st = os.stat(resolved)
                stat_info = self._stat_to_bytes(st)
                self._print_event(f"[{addr[0]}:{addr[1]}] DOPEN '{path}' -> handle={handle}")
                self._send_open_reply(addr, handle, stat_info=stat_info)
            except OSError as e:
                self._print_event(f"[{addr[0]}:{addr[1]}] DOPEN '{path}' -> error: {e}")
                self._send_open_reply(addr, -e.errno)
        else:
            # File open
            if self.read_only and (flags & 0x02):  # O_WRONLY or O_RDWR
                self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> EACCES (read-only)")
                self._send_open_reply(addr, -errno.EACCES)
                return

            # Check if we should open compressed version
            actual_resolved = compressed_resolved if compressed_resolved else resolved
            
            # Check if the file exists
            if not os.path.exists(actual_resolved):
                self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> ENOENT (file not found)")
                self._send_open_reply(addr, -errno.ENOENT)
                return
            
            # Check if the file is a compressed format
            is_compressed = False
            if self.enable_compression:
                lower_path = actual_resolved.lower()
                if lower_path.endswith('.zso') or lower_path.endswith('.cso') or lower_path.endswith('.chd'):
                    is_compressed = True
            
            py_mode = self._flags_to_mode(flags)
            try:
                # Create parent directories if O_CREAT and they don't exist
                if (flags & 0x0200) and not os.path.exists(os.path.dirname(actual_resolved)):
                    os.makedirs(os.path.dirname(actual_resolved), exist_ok=True)

                if is_compressed:
                    # Open compressed file with wrapper
                    try:
                        wrapper = open_compressed(actual_resolved, self.compression_cache_size)
                        if wrapper is None:
                            # Fall back to regular open if wrapper creation fails
                            f = open(actual_resolved, py_mode)
                            st = os.fstat(f.fileno())
                            stat_info = self._stat_to_bytes(st)
                            handle = self._alloc_handle(f, is_dir=False)
                        else:
                            # Use wrapper for handle
                            st = os.stat(actual_resolved)
                            stat_info = self._get_compressed_stat(actual_resolved, st)
                            if stat_info is None:
                                stat_info = self._stat_to_bytes(st)
                            handle = self._alloc_handle(wrapper, is_dir=False)
                            uncompressed_size = wrapper.uncompressed_size
                            if handle < 0:
                                wrapper.close()
                                self._send_open_reply(addr, handle)
                                return
                            display_path = path if compressed_resolved else path
                            self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{display_path}' -> handle={handle}, size={uncompressed_size} (compressed)")
                            self._send_open_reply(addr, handle, stat_info=stat_info)
                            return
                    except (ImportError, ValueError, OSError, struct.error) as e:
                        # Fall back to regular open if compression fails
                        self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> compression error: {type(e).__name__}: {e}, falling back")
                        f = open(actual_resolved, py_mode)
                        st = os.fstat(f.fileno())
                        stat_info = self._stat_to_bytes(st)
                        handle = self._alloc_handle(f, is_dir=False)
                else:
                    f = open(actual_resolved, py_mode)
                    st = os.fstat(f.fileno())
                    stat_info = self._stat_to_bytes(st)
                    handle = self._alloc_handle(f, is_dir=False)
                
                if handle < 0:
                    if 'f' in dir():
                        f.close()
                    self._send_open_reply(addr, handle)
                    return
                self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> handle={handle}, size={st.st_size}")
                self._send_open_reply(addr, handle, stat_info=stat_info)
            except OSError as e:
                self._print_event(f"[{addr[0]}:{addr[1]}] OPEN '{path}' -> error: {e}")
                self._send_open_reply(addr, -e.errno)

    def _handle_close(self, addr: Tuple[str, int], payload: bytes):
        """Handle CLOSE_REQ"""
        if len(payload) < 8:
            self._send_close_reply(addr, -errno.EINVAL)
            return

        _, _, _, _, handle = struct.unpack('<BBBBi', payload[:8])

        self.stats['close'] += 1

        if handle == BLOCK_DEVICE_HANDLE:
            # Block device handle cannot be closed
            self._send_close_reply(addr, 0)
            return

        if handle not in self.handles:
            self._send_close_reply(addr, -errno.EBADF)
            return

        self._free_handle(handle)
        if self.verbose:
            self._print_event(f"[{addr[0]}:{addr[1]}] CLOSE handle={handle}")
        self._send_close_reply(addr, 0)

    def _handle_read(self, addr: Tuple[str, int], payload: bytes):
        """Handle READ_REQ - combined RESULT_REPLY header + raw data"""
        if len(payload) < 12:
            self._send_read_result(addr, -errno.EINVAL, b'')
            return

        _, _, _, _, handle, size = struct.unpack('<BBBBiI', payload[:12])

        self.stats['read'] += 1

        fh = self.handles.get(handle)
        if fh is None or fh.is_dir:
            self._send_read_result(addr, -errno.EBADF, b'')
            return

        try:
            data = fh.obj.read(size)
            bytes_read = len(data)

            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] READ handle={handle} size={size} -> {bytes_read} bytes")

            self.stats['bytes_read'] += bytes_read
            self._update_status()
            self._send_read_result(addr, bytes_read, data)

        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] READ error: {e}")
            self._send_read_result(addr, -e.errno, b'')

    def _handle_write_req(self, addr: Tuple[str, int], payload: bytes):
        """Handle WRITE_REQ - start of file write operation"""
        if len(payload) < 12:
            self._send_ack(addr, is_ack=True)
            return

        _, _, _, _, handle, size = struct.unpack('<BBBBiI', payload[:12])

        self.stats['write'] += 1

        if self.read_only:
            self._print_event(f"[{addr[0]}:{addr[1]}] WRITE -> EACCES (read-only)")
            self._send_write_done(addr, -errno.EACCES)
            return

        fh = self.handles.get(handle)
        if fh is None or fh.is_dir:
            self._send_write_done(addr, -errno.EBADF)
            return

        if self.verbose:
            self._print_event(f"[{addr[0]}:{addr[1]}] WRITE_REQ handle={handle} size={size}")

        # Initialize write state (file write mode)
        self.write_handle = handle
        self.write_is_block = False
        self.write_data = bytearray()
        self.write_total_chunks = 0
        self.write_received_chunks = 0

        # Check for inline WRITE_DATA (combined WRITE_REQ + first chunk)
        if len(payload) > 12:
            self._handle_write_data(addr, payload[12:])
        else:
            self._send_ack(addr, is_ack=True)

    def _handle_write_data(self, addr: Tuple[str, int], payload: bytes):
        """Handle WRITE_DATA chunk (shared between file write and block write)"""
        if len(payload) < 8:
            self._send_ack(addr, is_ack=True)
            return

        _, _, chunk_nr, chunk_size, total_chunks = struct.unpack('<BBHHH', payload[:8])
        chunk_data = payload[8:8 + chunk_size]

        if self.verbose:
            self._print_event(f"[{addr[0]}:{addr[1]}] WRITE_DATA chunk={chunk_nr}/{total_chunks} size={chunk_size}")

        if chunk_nr != self.write_received_chunks:
            self._print_event(f"  ERROR: Chunk order error (expected {self.write_received_chunks}, got {chunk_nr})")
            self._send_ack(addr, is_ack=True)
            return

        self.write_data.extend(chunk_data)
        self.write_total_chunks = total_chunks
        self.write_received_chunks += 1

        if self.write_received_chunks >= total_chunks:
            if self.write_is_block:
                self._complete_bwrite(addr)
            else:
                self._complete_write(addr)
        else:
            self._send_ack(addr, is_ack=True)

    def _complete_write(self, addr: Tuple[str, int]):
        """Complete a file write operation"""
        fh = self.handles.get(self.write_handle)
        if fh is None or fh.is_dir:
            self._send_write_done(addr, -errno.EBADF)
            return

        try:
            bytes_written = fh.obj.write(self.write_data)
            fh.obj.flush()
            self.stats['bytes_written'] += bytes_written

            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] WRITE handle={self.write_handle} -> {bytes_written} bytes")
            self._update_status()
            self._send_write_done(addr, bytes_written)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] WRITE error: {e}")
            self._send_write_done(addr, -e.errno)

    def _complete_bwrite(self, addr: Tuple[str, int]):
        """Complete a block write operation"""
        fh = self.handles.get(self.write_handle)
        if fh is None or fh.is_dir:
            self._send_write_done(addr, -errno.EBADF)
            return

        sector_size = self.bd_sector_size if self.write_handle == BLOCK_DEVICE_HANDLE else 512
        expected_size = self.write_sector_count * sector_size

        try:
            fh.obj.seek(self.write_sector_nr * sector_size)
            fh.obj.write(self.write_data[:expected_size])
            fh.obj.flush()
            self.stats['bytes_written'] += expected_size

            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] BWRITE handle={self.write_handle} "
                      f"sector={self.write_sector_nr} count={self.write_sector_count}")
            self._update_status()
            self._send_write_done(addr, 0)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] BWRITE error: {e}")
            self._send_write_done(addr, -e.errno)

    def _handle_lseek(self, addr: Tuple[str, int], payload: bytes):
        """Handle LSEEK_REQ"""
        if len(payload) < 16:
            self._send_lseek_reply(addr, -errno.EINVAL)
            return

        _, whence, _, handle, offset_lo, offset_hi = struct.unpack('<BBHiii', payload[:16])
        offset = (offset_hi << 32) | (offset_lo & 0xFFFFFFFF)

        self.stats['lseek'] += 1

        fh = self.handles.get(handle)
        if fh is None or fh.is_dir:
            self._send_lseek_reply(addr, -errno.EBADF)
            return

        try:
            new_pos = fh.obj.seek(offset, whence)

            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] LSEEK handle={handle} offset={offset} whence={whence} -> {new_pos}")

            self._send_lseek_reply(addr, new_pos)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] LSEEK error: {e}")
            self._send_lseek_reply(addr, -e.errno)

    def _handle_dread(self, addr: Tuple[str, int], payload: bytes):
        """Handle DREAD_REQ"""
        if len(payload) < 8:
            self._send_dread_reply(addr, result=-errno.EINVAL)
            return

        _, _, _, _, handle = struct.unpack('<BBBBi', payload[:8])

        self.stats['dread'] += 1

        fh = self.handles.get(handle)
        if fh is None or not fh.is_dir:
            self._send_dread_reply(addr, result=-errno.EBADF)
            return

        dir_data = fh.obj
        if dir_data['index'] >= len(dir_data['entries']):
            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] DREAD handle={handle} -> end of dir")
            self._send_dread_reply(addr, result=0)
            return

        entry = dir_data['entries'][dir_data['index']]
        dir_data['index'] += 1

        try:
            st = entry.stat(follow_symlinks=False)
            
            # Check if this is a compressed file and transform display
            display_name = entry.name
            stat_info = self._stat_to_bytes(st)
            
            if self.enable_compression:
                lower_name = entry.name.lower()
                if lower_name.endswith('.zso') or lower_name.endswith('.cso'):
                    # Transform name to .iso
                    display_name = self._transform_compressed_name(entry.name)
                    # Get uncompressed size
                    compressed_stat = self._get_compressed_stat(entry.path, st)
                    if compressed_stat:
                        stat_info = compressed_stat

            if self.verbose:
                if display_name != entry.name:
                    self._print_event(f"[{addr[0]}:{addr[1]}] DREAD handle={handle} -> '{display_name}' (from {entry.name})")
                else:
                    self._print_event(f"[{addr[0]}:{addr[1]}] DREAD handle={handle} -> '{entry.name}'")

            self._send_dread_reply(addr, result=1, name=display_name, stat_info=stat_info)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] DREAD stat error: {e}")
            # Skip this entry and return end-of-dir
            self._send_dread_reply(addr, result=0)

    def _handle_getstat(self, addr: Tuple[str, int], payload: bytes):
        """Handle GETSTAT_REQ"""
        if len(payload) < 4:
            self._send_getstat_reply(addr, result=-errno.EINVAL)
            return

        path_bytes = payload[4:]
        path = path_bytes.split(b'\x00')[0].decode('utf-8', errors='replace')

        self.stats['getstat'] += 1

        # Empty path = block device capacity query (BD variant sends no path)
        if path == '' and BLOCK_DEVICE_HANDLE in self.handles:
            total_bytes = self.bd_sector_size * self.bd_sector_count
            stat_info = {
                'mode': 0, 'attr': 0,
                'size': total_bytes & 0xFFFFFFFF,
                'hisize': (total_bytes >> 32) & 0xFFFFFFFF,
                'ctime': b'\x00' * 8, 'atime': b'\x00' * 8, 'mtime': b'\x00' * 8,
            }
            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] GETSTAT '' -> block device {total_bytes} bytes")
            self._send_getstat_reply(addr, result=0, stat_info=stat_info)
            return

        resolved = self._resolve_path(path)
        if resolved is None:
            # Check for compressed version when .iso is requested
            if self.enable_compression and path.lower().endswith('.iso'):
                # Try to find compressed version
                base_path = path[:-4]  # Remove .iso
                for ext in ['.zso', '.cso']:
                    compressed_path = base_path + ext
                    compressed_resolved = self._resolve_path(compressed_path)
                    if compressed_resolved and os.path.exists(compressed_resolved):
                        try:
                            st = os.stat(compressed_resolved)
                            compressed_stat = self._get_compressed_stat(compressed_resolved, st)
                            if compressed_stat:
                                if self.verbose:
                                    self._print_event(f"[{addr[0]}:{addr[1]}] GETSTAT '{path}' -> compressed size={compressed_stat['size']} (from {compressed_path})")
                                self._send_getstat_reply(addr, result=0, stat_info=compressed_stat)
                                return
                        except OSError:
                            pass
            self._send_getstat_reply(addr, result=-errno.EACCES)
            return

        try:
            st = os.stat(resolved)
            stat_info = self._stat_to_bytes(st)
            
            # Check if this is a compressed file
            if self.enable_compression:
                lower_path = resolved.lower()
                if lower_path.endswith('.zso') or lower_path.endswith('.cso'):
                    compressed_stat = self._get_compressed_stat(resolved, st)
                    if compressed_stat:
                        stat_info = compressed_stat

            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] GETSTAT '{path}' -> size={stat_info['size']}")

            self._send_getstat_reply(addr, result=0, stat_info=stat_info)
        except OSError as e:
            if self.verbose:
                self._print_event(f"[{addr[0]}:{addr[1]}] GETSTAT '{path}' -> error: {e}")
            self._send_getstat_reply(addr, result=-e.errno)

    def _handle_mkdir(self, addr: Tuple[str, int], payload: bytes):
        """Handle MKDIR_REQ"""
        if len(payload) < 4:
            self._send_result_reply(addr, -errno.EINVAL)
            return

        _, _, mode = struct.unpack('<BBH', payload[:4])
        path_bytes = payload[4:]
        path = path_bytes.split(b'\x00')[0].decode('utf-8', errors='replace')

        self.stats['mkdir'] += 1

        if self.read_only:
            self._send_result_reply(addr, -errno.EACCES)
            return

        resolved = self._resolve_path(path)
        if resolved is None:
            self._send_result_reply(addr, -errno.EACCES)
            return

        try:
            os.mkdir(resolved, mode if mode else 0o755)
            self._print_event(f"[{addr[0]}:{addr[1]}] MKDIR '{path}'")
            self._send_result_reply(addr, 0)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] MKDIR '{path}' -> error: {e}")
            self._send_result_reply(addr, -e.errno)

    def _handle_remove(self, addr: Tuple[str, int], payload: bytes):
        """Handle REMOVE_REQ"""
        if len(payload) < 4:
            self._send_result_reply(addr, -errno.EINVAL)
            return

        path_bytes = payload[4:]
        path = path_bytes.split(b'\x00')[0].decode('utf-8', errors='replace')

        self.stats['remove'] += 1

        if self.read_only:
            self._send_result_reply(addr, -errno.EACCES)
            return

        resolved = self._resolve_path(path)
        if resolved is None:
            self._send_result_reply(addr, -errno.EACCES)
            return

        try:
            os.remove(resolved)
            self._print_event(f"[{addr[0]}:{addr[1]}] REMOVE '{path}'")
            self._send_result_reply(addr, 0)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] REMOVE '{path}' -> error: {e}")
            self._send_result_reply(addr, -e.errno)

    def _handle_rmdir(self, addr: Tuple[str, int], payload: bytes):
        """Handle RMDIR_REQ"""
        if len(payload) < 4:
            self._send_result_reply(addr, -errno.EINVAL)
            return

        path_bytes = payload[4:]
        path = path_bytes.split(b'\x00')[0].decode('utf-8', errors='replace')

        self.stats['rmdir'] += 1

        if self.read_only:
            self._send_result_reply(addr, -errno.EACCES)
            return

        resolved = self._resolve_path(path)
        if resolved is None:
            self._send_result_reply(addr, -errno.EACCES)
            return

        try:
            os.rmdir(resolved)
            self._print_event(f"[{addr[0]}:{addr[1]}] RMDIR '{path}'")
            self._send_result_reply(addr, 0)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] RMDIR '{path}' -> error: {e}")
            self._send_result_reply(addr, -e.errno)

    # --- Block I/O handlers (UDPBD subset) ---

    def _handle_bread(self, addr: Tuple[str, int], payload: bytes):
        """Handle BREAD_REQ - unified RESULT_REPLY + raw data response"""
        if len(payload) < 16:
            self._send_read_result(addr, -errno.EINVAL, b'')
            return

        # msg_type(1) + reserved(1) + sector_count(2) + handle(4) + sector_nr_lo(4) + sector_nr_hi(4)
        _, _, sector_count, handle, sector_nr_lo, sector_nr_hi = \
            struct.unpack('<BBHiII', payload[:16])
        sector_nr = sector_nr_lo | (sector_nr_hi << 32)

        self.stats['bread'] += 1

        fh = self.handles.get(handle)
        if fh is None or fh.is_dir:
            self._send_read_result(addr, -errno.EBADF, b'')
            return

        sector_size = self.bd_sector_size if handle == BLOCK_DEVICE_HANDLE else 512
        total_size = sector_count * sector_size

        if self.verbose:
            self._print_event(f"[{addr[0]}:{addr[1]}] BREAD handle={handle} sector={sector_nr} count={sector_count} ({total_size} bytes)")

        try:
            fh.obj.seek(sector_nr * sector_size)
            data = fh.obj.read(total_size)
        except OSError as e:
            self._print_event(f"[{addr[0]}:{addr[1]}] BREAD error: {e}")
            self._send_read_result(addr, -e.errno, b'')
            return

        self.stats['bytes_read'] += len(data)
        self._update_status()

        self._send_read_result(addr, len(data), data)

    def _handle_bwrite_req(self, addr: Tuple[str, int], payload: bytes):
        """Handle BWRITE_REQ - start of block write operation"""
        if len(payload) < 16:
            self._send_ack(addr, is_ack=True)
            return

        # msg_type(1) + reserved(1) + sector_count(2) + handle(4) + sector_nr_lo(4) + sector_nr_hi(4)
        _, _, sector_count, handle, sector_nr_lo, sector_nr_hi = \
            struct.unpack('<BBHiII', payload[:16])
        sector_nr = sector_nr_lo | (sector_nr_hi << 32)

        self.stats['bwrite'] += 1

        if self.read_only:
            self._print_event(f"[{addr[0]}:{addr[1]}] BWRITE -> EACCES (read-only)")
            self._send_write_done(addr, -errno.EACCES)
            return

        fh = self.handles.get(handle)
        if fh is None or fh.is_dir:
            self._send_write_done(addr, -errno.EBADF)
            return

        if self.verbose:
            self._print_event(f"[{addr[0]}:{addr[1]}] BWRITE_REQ handle={handle} sector={sector_nr} count={sector_count}")

        # Initialize write state (block write mode)
        self.write_handle = handle
        self.write_is_block = True
        self.write_sector_nr = sector_nr
        self.write_sector_count = sector_count
        self.write_data = bytearray()
        self.write_total_chunks = 0
        self.write_received_chunks = 0

        # Check for inline WRITE_DATA (combined BWRITE_REQ + first chunk)
        if len(payload) > 16:
            self._handle_write_data(addr, payload[16:])
        else:
            self._send_ack(addr, is_ack=True)

    # --- Send helpers ---

    def _send_inform(self, addr: Tuple[str, int]):
        """Send INFORM packet"""
        hdr = Header(packet_type=PacketType.INFORM, seq_nr=self.tx_seq_nr)
        disc = DiscHeader(service_id=UDPRDMA_SVC_UDPFS)

        packet = hdr.pack() + disc.pack()
        self.sock.sendto(packet, addr)

        self.tx_seq_nr = (self.tx_seq_nr + 1) & 0xFFF

    def _send_ack(self, addr: Tuple[str, int], is_ack: bool = True):
        """Send ACK or NACK packet"""
        hdr = Header(packet_type=PacketType.DATA, seq_nr=self.tx_seq_nr)
        data_hdr = DataHeader(
            seq_nr_ack=(self.rx_seq_nr_expected - 1) & 0xFFF if is_ack else self.rx_seq_nr_expected,
            flags=DataFlags.ACK if is_ack else 0,
            hdr_word_count=0,
            data_byte_count=0
        )

        packet = hdr.pack() + data_hdr.pack()
        self.sock.sendto(packet, addr)

    def _send_data(self, addr: Tuple[str, int], payload: bytes):
        """Send DATA packet with payload (single packet, always FIN)"""
        padded_size = (len(payload) + 3) & ~3
        padded_payload = payload.ljust(padded_size, b'\x00')

        hdr = Header(packet_type=PacketType.DATA, seq_nr=self.tx_seq_nr)
        data_hdr = DataHeader(
            seq_nr_ack=(self.rx_seq_nr_expected - 1) & 0xFFF,
            flags=DataFlags.ACK | DataFlags.FIN,
            hdr_word_count=0,
            data_byte_count=padded_size
        )

        packet = hdr.pack() + data_hdr.pack() + padded_payload
        self.sock.sendto(packet, addr)

        self.tx_seq_nr = (self.tx_seq_nr + 1) & 0xFFF

    def _send_data_packet(self, addr: Tuple[str, int], payload: bytes,
                          fin: bool = False, hdr_size: int = 0):
        """Send DATA packet and store for retransmit.

        If hdr_size > 0, the first hdr_size bytes of payload are treated as
        an app-level header (encoded via hdr_word_count in the UDPRDMA header).
        """
        data_size = len(payload) - hdr_size
        padded_data_size = (data_size + 3) & ~3
        padded_payload = payload[:hdr_size] + payload[hdr_size:].ljust(padded_data_size, b'\x00')

        hdr = Header(packet_type=PacketType.DATA, seq_nr=self.tx_seq_nr)
        data_hdr = DataHeader(
            seq_nr_ack=(self.rx_seq_nr_expected - 1) & 0xFFF,
            flags=DataFlags.ACK | (DataFlags.FIN if fin else 0),
            hdr_word_count=hdr_size // 4,
            data_byte_count=padded_data_size
        )

        packet = hdr.pack() + data_hdr.pack() + padded_payload

        self.tx_buffer.append((self.tx_seq_nr, packet))

        self.sock.sendto(packet, addr)
        self.tx_seq_nr = (self.tx_seq_nr + 1) & 0xFFF

    def _retransmit_from(self, addr: Tuple[str, int], from_seq: int):
        """Retransmit packets starting from sequence number"""
        count = 0
        for seq, packet in self.tx_buffer:
            seq_diff = (seq - from_seq) & 0xFFF
            if seq_diff < 2048:
                self.sock.sendto(packet, addr)
                count += 1
        if self.verbose and count > 0:
            self._print_event(f"  Retransmitted {count} packets from seq={from_seq}")

    def _optimal_chunk_size(self, total_bytes: int) -> int:
        """Choose chunk size for DMA efficiency"""
        candidates = [
            (1024, 512),
            (1280, 256),
            (1408, 128),
        ]

        best_chunk = 1408
        best_packets = math.ceil(total_bytes / 1408)
        best_align = 128

        for max_chunk, alignment in candidates:
            packets = math.ceil(total_bytes / max_chunk)
            if (packets < best_packets or
                (packets == best_packets and alignment > best_align)):
                best_packets = packets
                best_chunk = max_chunk
                best_align = alignment

        return best_chunk

    def _wait_for_window_ack(self, addr: Tuple[str, int]):
        """Wait for window ACK/NACK during multi-packet send.
        Updates tx_seq_nr_acked. On NACK, retransmits."""
        self.sock.settimeout(WINDOW_ACK_TIMEOUT)
        try:
            while True:
                pkt, recv_addr = self.sock.recvfrom(2048)
                if len(pkt) < 6:
                    continue
                hdr = Header.unpack(pkt)
                if hdr.packet_type != PacketType.DATA:
                    continue
                data_hdr = DataHeader.unpack(pkt[2:6])
                if data_hdr.data_byte_count > 0 or data_hdr.hdr_word_count > 0:
                    continue  # Not an ACK/NACK packet
                if data_hdr.flags & DataFlags.ACK:
                    # Window ACK - advance acked position
                    self.tx_seq_nr_acked = data_hdr.seq_nr_ack
                    self.tx_buffer = [
                        (seq, pkt) for seq, pkt in self.tx_buffer
                        if ((seq - data_hdr.seq_nr_ack - 1) & 0xFFF) < 2048
                    ]
                    return
                else:
                    # NACK - update acked position and retransmit
                    self.tx_seq_nr_acked = (data_hdr.seq_nr_ack - 1) & 0xFFF
                    self._retransmit_from(addr, data_hdr.seq_nr_ack)
                    return
        except socket.timeout:
            # No ACK received - retransmit all unacked
            self.sock.settimeout(None)
            if self.tx_buffer:
                start_seq = self.tx_buffer[0][0]
                self._retransmit_from(addr, start_seq)
            return
        finally:
            self.sock.settimeout(None)

    def _in_flight(self) -> int:
        """Number of unacknowledged packets in flight"""
        return (self.tx_seq_nr - self.tx_seq_nr_acked - 1) & 0xFFF

    def _wait_for_ack(self, addr: Tuple[str, int], timeout: float = 5.0) -> bool:
        """Wait for ACK from peer before proceeding with next transfer"""
        self.sock.settimeout(timeout)
        try:
            while True:
                pkt, recv_addr = self.sock.recvfrom(2048)
                if len(pkt) < 6:
                    continue
                hdr = Header.unpack(pkt)
                if hdr.packet_type != PacketType.DATA:
                    continue
                data_hdr = DataHeader.unpack(pkt[2:6])
                if data_hdr.data_byte_count == 0 and data_hdr.hdr_word_count == 0:
                    if data_hdr.flags & DataFlags.ACK:
                        self.tx_buffer = []
                        return True
                    else:
                        # NACK - retransmit
                        self._retransmit_from(addr, data_hdr.seq_nr_ack)
        except socket.timeout:
            return False
        finally:
            self.sock.settimeout(None)

    def _send_raw_data(self, addr: Tuple[str, int], data: bytes):
        """Send raw data as UDPRDMA multi-packet transfer with flow control"""
        self.tx_buffer = []
        self.tx_start_seq = self.tx_seq_nr

        max_chunk = self._optimal_chunk_size(len(data))

        offset = 0
        window_retries = 0
        while offset < len(data):
            # Flow control: wait if send window is full
            if self._in_flight() >= SEND_WINDOW:
                old_acked = self.tx_seq_nr_acked
                self._wait_for_window_ack(addr)
                if self.tx_seq_nr_acked == old_acked:
                    window_retries += 1
                    if window_retries >= MAX_WINDOW_RETRIES:
                        self._print_event("  Window ACK retries exhausted, aborting transfer")
                        return
                else:
                    window_retries = 0
                continue

            window_retries = 0
            chunk_size = min(max_chunk, len(data) - offset)
            chunk_data = data[offset:offset + chunk_size]
            is_last = (offset + chunk_size >= len(data))

            self._send_data_packet(addr, chunk_data, fin=is_last)
            offset += chunk_size

    def _send_raw_data_with_header(self, addr: Tuple[str, int],
                                   header: bytes, data: bytes):
        """Send raw data with app header on first packet, with flow control"""
        self.tx_buffer = []
        self.tx_start_seq = self.tx_seq_nr

        max_chunk = self._optimal_chunk_size(len(data))

        # First packet: header + data (cap data to fit in max payload)
        first_data_max = min(max_chunk, MAX_DATA_PAYLOAD - len(header))
        first_chunk_size = min(first_data_max, len(data))
        is_last = (first_chunk_size >= len(data))
        self._send_data_packet(addr, header + data[:first_chunk_size],
                               fin=is_last, hdr_size=len(header))

        # Remaining packets: data only
        offset = first_chunk_size
        window_retries = 0
        while offset < len(data):
            # Flow control: wait if send window is full
            if self._in_flight() >= SEND_WINDOW:
                old_acked = self.tx_seq_nr_acked
                self._wait_for_window_ack(addr)
                if self.tx_seq_nr_acked == old_acked:
                    window_retries += 1
                    if window_retries >= MAX_WINDOW_RETRIES:
                        self._print_event("  Window ACK retries exhausted, aborting transfer")
                        return
                else:
                    window_retries = 0
                continue

            window_retries = 0
            chunk_size = min(max_chunk, len(data) - offset)
            is_last = (offset + chunk_size >= len(data))
            self._send_data_packet(addr, data[offset:offset + chunk_size],
                                   fin=is_last)
            offset += chunk_size

    # --- Response builders ---

    def _send_open_reply(self, addr: Tuple[str, int], handle: int,
                         stat_info: Optional[dict] = None):
        """Send OPEN_REPLY"""
        if stat_info is None:
            stat_info = {'mode': 0, 'size': 0, 'hisize': 0,
                        'ctime': b'\x00' * 8, 'mtime': b'\x00' * 8}

        reply = struct.pack('<BBBBiIII',
            MsgType.OPEN_REPLY, 0, 0, 0,
            handle,
            stat_info['mode'],
            stat_info['size'],
            stat_info['hisize'],
        ) + stat_info['ctime'] + stat_info['mtime']

        self._send_data(addr, reply)

    def _send_close_reply(self, addr: Tuple[str, int], result: int):
        """Send CLOSE_REPLY"""
        reply = struct.pack('<BBBBi', MsgType.CLOSE_REPLY, 0, 0, 0, result)
        self._send_data(addr, reply)

    def _send_read_result(self, addr: Tuple[str, int], result: int, data: bytes):
        """Send READ response: RESULT_REPLY as app header + optional data"""
        result_reply = struct.pack('<BBBBi', MsgType.RESULT_REPLY, 0, 0, 0, result)
        self._send_raw_data_with_header(addr, result_reply, data)

    def _send_result_reply(self, addr: Tuple[str, int], result: int):
        """Send RESULT_REPLY"""
        reply = struct.pack('<BBBBi', MsgType.RESULT_REPLY, 0, 0, 0, result)
        self._send_data(addr, reply)

    def _send_write_done(self, addr: Tuple[str, int], result: int):
        """Send WRITE_DONE"""
        reply = struct.pack('<BBBBi', MsgType.WRITE_DONE, 0, 0, 0, result)
        self._send_data(addr, reply)

    def _send_lseek_reply(self, addr: Tuple[str, int], position: int):
        """Send LSEEK_REPLY"""
        if position < 0:
            # Error code: pack as signed
            reply = struct.pack('<BBBBii', MsgType.LSEEK_REPLY, 0, 0, 0, position, -1)
        else:
            # Position: pack as unsigned to handle values > 2GB
            pos_lo = position & 0xFFFFFFFF
            pos_hi = (position >> 32) & 0xFFFFFFFF
            reply = struct.pack('<BBBBII', MsgType.LSEEK_REPLY, 0, 0, 0, pos_lo, pos_hi)
        self._send_data(addr, reply)

    def _send_dread_reply(self, addr: Tuple[str, int], result: int,
                          name: Optional[str] = None,
                          stat_info: Optional[dict] = None):
        """Send DREAD_REPLY"""
        if name is None:
            name = ''
        if stat_info is None:
            stat_info = {'mode': 0, 'attr': 0, 'size': 0, 'hisize': 0,
                        'ctime': b'\x00' * 8, 'atime': b'\x00' * 8,
                        'mtime': b'\x00' * 8}

        name_bytes = name.encode('utf-8') + b'\x00'
        name_len = len(name_bytes) - 1  # Exclude null terminator from length

        # Pad name to 4-byte boundary
        padded_name_len = (len(name_bytes) + 3) & ~3
        name_padded = name_bytes.ljust(padded_name_len, b'\x00')

        reply = struct.pack('<BBHiIIII',
            MsgType.DREAD_REPLY, 0,
            name_len,
            result,
            stat_info['mode'],
            stat_info['attr'],
            stat_info['size'],
            stat_info['hisize'],
        ) + stat_info['ctime'] + stat_info['atime'] + stat_info['mtime']

        if result > 0:
            reply += name_padded

        self._send_data(addr, reply)

    def _send_getstat_reply(self, addr: Tuple[str, int], result: int,
                            stat_info: Optional[dict] = None):
        """Send GETSTAT_REPLY"""
        if stat_info is None:
            stat_info = {'mode': 0, 'attr': 0, 'size': 0, 'hisize': 0,
                        'ctime': b'\x00' * 8, 'atime': b'\x00' * 8,
                        'mtime': b'\x00' * 8}

        reply = struct.pack('<BBBBiIIII',
            MsgType.GETSTAT_REPLY, 0, 0, 0,
            result,
            stat_info['mode'],
            stat_info['attr'],
            stat_info['size'],
            stat_info['hisize'],
        ) + stat_info['ctime'] + stat_info['atime'] + stat_info['mtime']

        self._send_data(addr, reply)

    def _print_stats(self):
        """Print final statistics summary"""
        elapsed = time.monotonic() - self._start_time
        h, rem = divmod(int(elapsed), 3600)
        m, s = divmod(rem, 60)

        print()
        print(f"Session: {h:02d}:{m:02d}:{s:02d}")
        print()

        # Operations table
        ops = [(k, v) for k, v in self.stats.items()
               if k not in ('bytes_read', 'bytes_written') and v > 0]
        if ops:
            print("Operations:")
            for key, val in ops:
                print(f"  {key:<12s} {val:>10,}")

        # Throughput
        total_read = self.stats['bytes_read']
        total_written = self.stats['bytes_written']
        if total_read > 0 or total_written > 0:
            print()
            print("Transfer:")
            if total_read > 0:
                rate = total_read / elapsed if elapsed > 0 else 0
                print(f"  read         {self._format_bytes(total_read):>10s}  ({self._format_bytes(int(rate))}/s)")
            if total_written > 0:
                rate = total_written / elapsed if elapsed > 0 else 0
                print(f"  written      {self._format_bytes(total_written):>10s}  ({self._format_bytes(int(rate))}/s)")


def main():
    parser = argparse.ArgumentParser(
        description='UDPFS Server - Unified file and block device server over UDPRDMA',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--block-device', '-b',
        help='Block device or disk image to serve as handle 0'
    )
    parser.add_argument(
        '--root-dir', '-d',
        help='Root directory to serve files from'
    )
    parser.add_argument(
        '--port', '-p',
        type=lambda x: int(x, 0),
        default=UDPFS_PORT,
        help=f'UDP port to listen on (default: 0x{UDPFS_PORT:04X})'
    )
    parser.add_argument(
        '--sector-size', '-s',
        type=int,
        default=512,
        help='Sector size for block device (default: 512)'
    )
    parser.add_argument(
        '--read-only', '-r',
        action='store_true',
        help='Serve in read-only mode'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Verbose output'
    )
    parser.add_argument(
        '--enable-compression', '-c',
        action='store_true',
        help='Enable transparent decompression of .zso (LZ4), .cso (zlib), and .chd (CHD v5) files. '
             'Compressed files appear as .iso in directory listings.'
    )
    parser.add_argument(
        '--compression-cache-size',
        type=int,
        default=32,
        help='Number of decompressed blocks to cache per file (default: 32)'
    )

    args = parser.parse_args()

    if not args.block_device and not args.root_dir:
        parser.error("At least one of --block-device or --root-dir is required")

    if args.root_dir and not os.path.isdir(args.root_dir):
        print(f"Error: '{args.root_dir}' is not a directory")
        sys.exit(1)

    if args.block_device and not os.path.exists(args.block_device):
        print(f"Error: '{args.block_device}' not found")
        sys.exit(1)

    # Check LZ4 availability if compression is enabled
    if args.enable_compression and not LZ4_AVAILABLE:
        print("Warning: LZ4 library not available. ZSO files will not be supported.")
        print("Install with: pip install lz4")
    if args.enable_compression and not LIBCHDR_AVAILABLE:
        print("Warning: libchdr not found. CHD files will not be supported.")
        print("Install with: apt install libchdr0")

    server = UdpfsServer(
        root_dir=args.root_dir,
        block_device=args.block_device,
        port=args.port,
        sector_size=args.sector_size,
        read_only=args.read_only,
        verbose=args.verbose,
        enable_compression=args.enable_compression,
        compression_cache_size=args.compression_cache_size
    )
    server.run()


if __name__ == '__main__':
    main()

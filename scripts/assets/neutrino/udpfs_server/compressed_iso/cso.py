"""
CSO/CISO format wrapper (zlib block-based compression).

Standard CSO format used by various PSP/PS2 tools.
"""

import struct
import zlib

from .base import CompressedFileWrapper

# CSO magic number
CSO_MAGIC = 0x4F534943  # "CISO"


class CsoFileWrapper(CompressedFileWrapper):
    """CSO/CISO format wrapper (zlib block-based compression).
    
    CSO Header (24 bytes):
        - magic: 4 bytes (0x4F534943 = "CISO")
        - header_size: 4 bytes (little-endian)
        - uncompressed_size: 8 bytes (little-endian)
        - block_size: 4 bytes (little-endian)
        - version: 1 byte
        - align: 1 byte (alignment shift for offsets)
        - reserved: 2 bytes
    
    Block offset table follows header. Each offset is 4 bytes:
        - MSB (0x80000000): Set if block is uncompressed
        - Lower31 bits: Offset >> align
    
    Note: Some CSO files use raw deflate without zlib headers. This wrapper
    tries raw deflate first, then falls back to standard zlib decompression.
    """
    
    def __init__(self, file_path: str, cache_size: int = None):
        """Initialize CSO wrapper.
        
        Args:
            file_path: Path to the CSO file
            cache_size: Number of blocks to cache (default: 32)
            
        Raises:
            ValueError: If file is not a valid CSO file
        """
        super().__init__(file_path, cache_size)
        self.align = 0
        self._parse_header()
    
    def _parse_header(self):
        """Parse CSO header and block offset table."""
        self.file.seek(0)
        header = self.file.read(24)
        
        if len(header) < 24:
            raise ValueError(f"Invalid CSO file: header too short ({len(header)} bytes)")
        
        magic = struct.unpack('<I', header[0:4])[0]
        if magic != CSO_MAGIC:
            raise ValueError(f"Invalid CSO magic: 0x{magic:08X}, expected 0x{CSO_MAGIC:08X}")
        
        header_size = struct.unpack('<I', header[4:8])[0]
        self.uncompressed_size = struct.unpack('<Q', header[8:16])[0]
        self.block_size = struct.unpack('<I', header[16:20])[0]
        # version = header[20]
        self.align = header[21]
        # reserved = header[22:24]
        
        if self.block_size == 0:
            raise ValueError("Invalid CSO: block_size is 0")
        
        # Calculate number of blocks
        self._num_blocks = (self.uncompressed_size + self.block_size - 1) // self.block_size
        
        # Read block offset table (CSO has num_blocks + 1 entries)
        self.file.seek(header_size)
        offset_data = self.file.read((self._num_blocks + 1) * 4)
        
        if len(offset_data) < (self._num_blocks + 1) * 4:
            raise ValueError("Invalid CSO: offset table truncated")
        
        self.block_offsets = list(struct.unpack(f'<{self._num_blocks + 1}I', offset_data))
    
    def _decompress_block(self, block_idx: int) -> bytes:
        """Decompress a single CSO block using zlib.
        
        Tries raw deflate first (wbits=-15), then standard zlib, as some
        CSO files use raw deflate without zlib headers.
        
        Args:
            block_idx: Block index (0-based)
            
        Returns:
            Decompressed block data (block_size bytes, padded with zeros if needed)
            
        Raises:
            ValueError: If block index is out of range or decompression fails
        """
        if block_idx >= self._num_blocks:
            raise ValueError(f"Block index {block_idx} out of range (0-{self._num_blocks-1})")
        
        raw_offset = self.block_offsets[block_idx]
        next_raw_offset = self.block_offsets[block_idx + 1]
        
        # Check if block is uncompressed (MSB set)
        is_uncompressed = (raw_offset & 0x80000000) != 0
        
        # Calculate actual offset (remove MSB, apply alignment)
        offset = (raw_offset & 0x7FFFFFFF) << self.align
        next_offset = (next_raw_offset & 0x7FFFFFFF) << self.align
        compressed_size = next_offset - offset
        
        # Read compressed data
        self.file.seek(offset)
        compressed_data = self.file.read(compressed_size)
        
        if is_uncompressed:
            decompressed = compressed_data
        else:
            # Try raw deflate first (wbits=-15), then standard zlib
            # Some CSO files use raw deflate without zlib headers
            try:
                decompressor = zlib.decompressobj(-zlib.MAX_WBITS)
                decompressed = decompressor.decompress(compressed_data)
            except zlib.error:
                try:
                    decompressed = zlib.decompress(compressed_data)
                except zlib.error as e:
                    raise ValueError(f"zlib decompression failed for block {block_idx}: {e}")
        
        # Pad to block size if needed (for last block)
        if len(decompressed) < self.block_size:
            decompressed += b'\x00' * (self.block_size - len(decompressed))
        
        return decompressed

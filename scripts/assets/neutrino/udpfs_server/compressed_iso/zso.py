"""
ZSO format wrapper (LZ4 block-based compression).

Supports both ZSO\x00 (OPL) and ZISO (PCSX2) magic values.
"""

import struct

from .base import CompressedFileWrapper

# Check for LZ4 availability
try:
    import lz4.block
    LZ4_AVAILABLE = True
except ImportError:
    LZ4_AVAILABLE = False


class ZsoFileWrapper(CompressedFileWrapper):
    """ZSO format wrapper (LZ4 block-based compression).
    
    Supports both ZSO\\x00 (OPL) and ZISO (PCSX2) magic values.
    ZISO format uses CSO-like layout with alignment and n+1 offset entries.
    
    ZSO Header (24 bytes):
        - magic: 4 bytes (ZSO\\x00 or ZISO)
        - header_size: 4 bytes (little-endian)
        - uncompressed_size: 8 bytes (little-endian)
        - block_size: 4 bytes (little-endian)
        - version: 1 byte
        - align: 1 byte (alignment shift for offsets)
        - reserved: 2 bytes
    
    Block offset table follows header. Each offset is 4 bytes:
        - MSB (0x80000000): Set if block is uncompressed
        - Lower31 bits: Offset >> align
    """
    
    ZSO_MAGIC = b'ZSO\x00'
    ZISO_MAGIC = b'ZISO'
    
    def __init__(self, file_path: str, cache_size: int = None):
        """Initialize ZSO wrapper.
        
        Args:
            file_path: Path to the ZSO file
            cache_size: Number of blocks to cache (default: 32)
            
        Raises:
            ImportError: If LZ4 library is not available
            ValueError: If file is not a valid ZSO file
        """
        if not LZ4_AVAILABLE:
            raise ImportError("LZ4 library not available. Install with: pip install lz4")
        super().__init__(file_path, cache_size)
        self.align = 0
        self._is_ziso = False
        self._parse_header()
    
    def _parse_header(self):
        """Parse ZSO/ZISO header and block offset table."""
        self.file.seek(0)
        header = self.file.read(24)
        
        if len(header) < 24:
            raise ValueError(f"Invalid ZSO file: header too short ({len(header)} bytes)")
        
        magic = header[0:4]
        if magic == self.ZISO_MAGIC:
            self._is_ziso = True
        elif magic != self.ZSO_MAGIC:
            raise ValueError(f"Invalid ZSO magic: {magic!r}, expected {self.ZSO_MAGIC!r} or {self.ZISO_MAGIC!r}")
        
        header_size = struct.unpack('<I', header[4:8])[0]
        self.uncompressed_size = struct.unpack('<Q', header[8:16])[0]
        self.block_size = struct.unpack('<I', header[16:20])[0]
        
        if self.block_size == 0:
            raise ValueError("Invalid ZSO: block_size is 0")
        
        # ZISO format has version and align bytes like CSO
        if self._is_ziso:
            # version = header[20]
            self.align = header[21]
        
        # Calculate number of blocks
        self._num_blocks = (self.uncompressed_size + self.block_size - 1) // self.block_size
        
        # Read block offset table
        # ZISO format has n+1 entries like CSO, ZSO has n entries
        num_offset_entries = self._num_blocks + 1 if self._is_ziso else self._num_blocks
        
        self.file.seek(header_size)
        offset_data = self.file.read(num_offset_entries * 4)
        
        if len(offset_data) < num_offset_entries * 4:
            raise ValueError("Invalid ZSO: offset table truncated")
        
        self.block_offsets = list(struct.unpack(f'<{num_offset_entries}I', offset_data))
    
    def _decompress_block(self, block_idx: int) -> bytes:
        """Decompress a single ZSO block using LZ4.
        
        Uses OPL-style retry loop to handle alignment padding bytes at the
        end of compressed data.
        
        Args:
            block_idx: Block index (0-based)
            
        Returns:
            Decompressed block data (block_size bytes)
            
        Raises:
            ValueError: If block index is out of range or decompression fails
        """
        if block_idx >= self._num_blocks:
            raise ValueError(f"Block index {block_idx} out of range (0-{self._num_blocks-1})")
        
        raw_offset = self.block_offsets[block_idx]
        
        # Calculate compressed size from next block offset or file end
        if self._is_ziso:
            # ZISO uses n+1 entries like CSO
            next_raw_offset = self.block_offsets[block_idx + 1]
            is_uncompressed = (raw_offset & 0x80000000) != 0
            offset = (raw_offset & 0x7FFFFFFF) << self.align
            next_offset = (next_raw_offset & 0x7FFFFFFF) << self.align
            compressed_size = next_offset - offset
        else:
            # Original ZSO format
            if block_idx + 1 < self._num_blocks:
                next_offset = self.block_offsets[block_idx + 1]
                compressed_size = next_offset - raw_offset
            else:
                # Last block - get file size
                self.file.seek(0, 2)
                file_size = self.file.tell()
                compressed_size = file_size - raw_offset
            offset = raw_offset
            is_uncompressed = (raw_offset & 0x80000000) != 0
        
        # Read compressed data
        self.file.seek(offset)
        compressed_data = self.file.read(compressed_size)
        
        if is_uncompressed:
            return compressed_data
        
        # Decompress with LZ4 using OPL-style retry loop
        # The compressed data may have alignment padding bytes at the end
        while compressed_data:
            try:
                decompressed = lz4.block.decompress(compressed_data, uncompressed_size=self.block_size)
                return decompressed
            except lz4.block.LZ4BlockError:
                # Remove trailing byte (alignment padding) and retry
                compressed_data = compressed_data[:-1]
        
        raise ValueError(f"LZ4 decompression failed for block {block_idx}: all retry attempts exhausted")

"""Deterministic lossless 8-bit PNG writer for procedural bake data."""
import struct, zlib
import numpy as np
def png(path, pixels):
    a=np.ascontiguousarray(pixels,dtype=np.uint8)
    h,w=a.shape[:2]; channels=1 if a.ndim==2 else a.shape[2]
    def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    raw=b''.join(b'\x00'+row.tobytes() for row in a)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,{1:0,3:2,4:6}[channels],0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

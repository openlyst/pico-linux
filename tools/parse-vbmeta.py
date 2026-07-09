#!/usr/bin/env python3
import struct, sys

with open(sys.argv[1], 'rb') as f:
    v = f.read()

auth = struct.unpack('>Q', v[12:20])[0]
aux = struct.unpack('>Q', v[20:28])[0]
doff = struct.unpack('>I', v[128:132])[0]
dsz = struct.unpack('>I', v[132:136])[0]
flags = struct.unpack('>I', v[144:148])[0]

print(f"auth_block={auth} aux_block={aux} desc_off={doff} desc_size={dsz} flags={flags}")

base = 256 + auth + doff
end = base + dsz
off = base

while off < end - 4:
    tag = v[off:off+4]
    if tag == b'hash':
        nb = struct.unpack('>I', v[off+4:off+8])[0]
        img_sz = struct.unpack('>Q', v[off+8:off+16])[0]
        sl = struct.unpack('>I', v[off+16:off+20])[0]
        dl = struct.unpack('>I', v[off+20:off+24])[0]
        nm = v[off+24:v.index(0, off+24)].decode()
        print(f"  hash: {nm} image_size={img_sz} ({img_sz//1048576}MB) salt_len={sl} digest_len={dl}")
        off += 8 + nb
    elif tag == b'\x00\x00\x00\x00':
        break
    else:
        off += 4

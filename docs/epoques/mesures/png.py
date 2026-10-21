"""Décodeur PNG minimal (stdlib seulement : zlib, struct). 8 bits, non entrelacé.
Renvoie (w, h, rgba) où rgba est un bytearray de w*h*4 octets."""
import struct
import zlib


def read_header(path):
    with open(path, "rb") as f:
        sig = f.read(8)
        assert sig == b"\x89PNG\r\n\x1a\n", path
        ln, typ = struct.unpack(">I4s", f.read(8))
        assert typ == b"IHDR"
        w, h, bd, ct, comp, filt, inter = struct.unpack(">IIBBBBB", f.read(13))
    return w, h, bd, ct, inter


def _paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode(path):
    with open(path, "rb") as f:
        data = f.read()
    pos = 8
    idat = []
    plte = None
    trns = None
    w = h = bd = ct = inter = None
    while pos < len(data):
        ln, typ = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, comp, filt, inter = struct.unpack(">IIBBBBB", chunk)
        elif typ == b"PLTE":
            plte = chunk
        elif typ == b"tRNS":
            trns = chunk
        elif typ == b"IDAT":
            idat.append(chunk)
        elif typ == b"IEND":
            break
    if bd != 8 or inter != 0:
        raise ValueError(f"non géré : bd={bd} interlace={inter} ({path})")
    bpp = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    out = bytearray(h * stride)
    prev = bytearray(stride)
    i = 0
    for y in range(h):
        ft = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        if ft == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif ft == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif ft == 3:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif ft == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                c = prev[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + _paeth(a, prev[x], c)) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if ct == 6:
        return w, h, out
    rgba = bytearray(w * h * 4)
    for p in range(w * h):
        if ct == 2:
            r, g, b = out[p * 3:p * 3 + 3]
            a = 255
        elif ct == 3:
            idx = out[p]
            r, g, b = plte[idx * 3:idx * 3 + 3]
            a = trns[idx] if trns and idx < len(trns) else 255
        elif ct == 4:
            r = g = b = out[p * 2]
            a = out[p * 2 + 1]
        else:
            r = g = b = out[p]
            a = 255
        rgba[p * 4:p * 4 + 4] = bytes((r, g, b, a))
    return w, h, rgba

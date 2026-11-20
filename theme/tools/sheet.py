#!/usr/bin/env python3
"""Combine Rockbox simulator BMP screendumps into one enlarged PNG contact sheet."""
import struct, sys, zlib

def read_bmp(path):
    b = open(path, 'rb').read()
    off, = struct.unpack_from('<I', b, 10)
    hs, w, h, _, bpp, comp = struct.unpack_from('<IiiHHI', b, 14)
    ncol, = struct.unpack_from('<I', b, 46)
    flip = h > 0
    h = abs(h)
    pal = []
    if bpp <= 8:
        n = ncol or (1 << bpp)
        for i in range(n):
            bl, g, r, _ = struct.unpack_from('<BBBB', b, 14 + hs + 4 * i)
            pal.append((r, g, bl))
    stride = ((w * bpp + 31) // 32) * 4
    rows = []
    for y in range(h):
        row = b[off + y * stride: off + (y + 1) * stride]
        px = []
        for x in range(w):
            if bpp == 24:
                px.append((row[3 * x + 2], row[3 * x + 1], row[3 * x]))
            elif bpp == 32:
                px.append((row[4 * x + 2], row[4 * x + 1], row[4 * x]))
            elif bpp == 16:
                v, = struct.unpack_from('<H', row, 2 * x)
                px.append((((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31))
            else:
                byte = row[(x * bpp) // 8]
                shift = 8 - bpp - (x * bpp) % 8
                px.append(pal[(byte >> shift) & ((1 << bpp) - 1)])
        rows.append(px)
    if flip:
        rows.reverse()
    return w, h, rows

def write_png(path, w, h, rows):
    raw = b''.join(b'\0' + bytes(c for p in r for c in p) for r in rows)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def main():
    out, scale, cols, files = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:]
    imgs = [read_bmp(f) for f in files]
    w, h = imgs[0][0], imgs[0][1]
    gap, bg = 6, (60, 60, 60)
    nrows = (len(imgs) + cols - 1) // cols
    W = cols * w + (cols + 1) * gap
    H = nrows * h + (nrows + 1) * gap
    canvas = [[bg] * W for _ in range(H)]
    for i, (_, _, rows) in enumerate(imgs):
        ox = gap + (i % cols) * (w + gap)
        oy = gap + (i // cols) * (h + gap)
        for y in range(h):
            canvas[oy + y][ox:ox + w] = rows[y]
    big = []
    for r in canvas:
        line = [p for p in r for _ in range(scale)]
        big.extend([line] * scale)
    write_png(out, W * scale, H * scale, big)

main()

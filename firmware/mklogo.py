#!/usr/bin/env python3
"""Turn a text drawing ('#' = dark pixel, '.' = background) into the
138-pixel-wide BMP the firmware embeds as its startup logo.

The iPod's own ROM shows a 44x52 logo at x=47, y=23 before Rockbox starts. A
drawing of the same size, placed at the same spot, makes the hand-over seamless.
The repository ships a neutral placeholder; to match your own device, trace its
power-on logo into boot-logo-trace.txt (not included here).
usage: mklogo.py drawing.txt out.bmp"""
import struct, sys
LCD_W, LOGO_X = 138, 47          # logo's left edge on the 138x110 screen
rows = [l.rstrip('\n') for l in open(sys.argv[1]) if l.strip()]
w, h = len(rows[0]), len(rows)
assert all(len(r) == w for r in rows) and LOGO_X + w <= LCD_W
pix = [[255] * LCD_W for _ in range(h)]
for y, r in enumerate(rows):
    for x, c in enumerate(r):
        if c == '#':
            pix[y][LOGO_X + x] = 0
pad = (4 - (LCD_W * 3) % 4) % 4
data = b''.join(b''.join(bytes((v, v, v)) for v in r) + b'\0' * pad for r in reversed(pix))
open(sys.argv[2], 'wb').write(b'BM' + struct.pack('<IHHI', 54 + len(data), 0, 0, 54)
    + struct.pack('<IiiHHIIiiII', 40, LCD_W, h, 1, 24, 0, len(data), 2835, 2835, 0, 0) + data)
print('logo %dx%d at x=%d' % (w, h, LOGO_X))

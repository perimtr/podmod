#!/usr/bin/env python3
"""Generate the theme's icon strips as 24-bit BMPs (white glyphs on black)."""
import struct, sys, os
out = sys.argv[1]

def bmp(path, rows):
    h, w = len(rows), len(rows[0])
    pad = (4 - (w * 3) % 4) % 4
    data = b''
    for r in reversed(rows):
        data += b''.join(bytes((255, 255, 255)) if c == '#' else bytes((0, 0, 0)) for c in r) + b'\0' * pad
    hdr = b'BM' + struct.pack('<IHHI', 54 + len(data), 0, 0, 54) + struct.pack('<IiiHHIIiiII', 40, w, h, 1, 24, 0, len(data), 2835, 2835, 0, 0)
    open(path, 'wb').write(hdr + data)

# playback state, 9x9 each, stacked: stop, play, pause, ffwd, rewind
mode = [
 ".........", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".........",
 ".##......", ".####....", ".######..", ".#######.", ".########", ".#######.", ".######..", ".####....", ".##......",
 ".........", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".........",
 ".........", "#...#....", "##..##...", "###.###..", "########.", "###.###..", "##..##...", "#...#....", ".........",
 ".........", "....#...#", "...##..##", "..###.###", ".########", "..###.###", "...##..##", "....#...#", ".........",
]
bmp(os.path.join(out, 'mode.bmp'), mode)

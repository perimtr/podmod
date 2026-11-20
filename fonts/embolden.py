#!/usr/bin/env python3
"""Embolden a BDF pixel font by smearing every glyph one pixel to the right.
usage: embolden.py in.bdf out.bdf NewFamilyName"""
import re, sys
src, dst, name = sys.argv[1:4]
out, w, in_bitmap = [], 0, False
for line in open(src, encoding='latin-1'):
    line = line.rstrip('\n')
    if line.startswith('FONT '):
        line = re.sub(r'-Medium-', '-Bold-', line)
    elif line.startswith('FAMILY_NAME'):
        line = 'FAMILY_NAME "%s"' % name
    elif line.startswith('WEIGHT_NAME'):
        line = 'WEIGHT_NAME "Bold"'
    elif line.startswith('FONTBOUNDINGBOX'):
        p = line.split(); p[1] = str(int(p[1]) + 1); line = ' '.join(p)
    elif line.startswith('DWIDTH'):
        p = line.split(); p[1] = str(int(p[1]) + 1); line = ' '.join(p)
    elif line.startswith('SWIDTH'):
        p = line.split(); p[1] = str(int(int(p[1]) * 1.08)); line = ' '.join(p)
    elif line.startswith('BBX'):
        p = line.split(); w = int(p[1]); p[1] = str(w + 1); line = ' '.join(p)
    elif line == 'BITMAP':
        in_bitmap = True
    elif line == 'ENDCHAR':
        in_bitmap = False
    elif in_bitmap and w > 0:
        bits = len(line) * 4
        v = int(line, 16) >> (bits - w)          # glyph row, w bits
        o = v << 1                                # original row in w+1 bits
        mask = (1 << (w + 1)) - 1
        # add a pixel to the right of each set pixel, unless that would close
        # a one-pixel gap between two strokes (keeps letters like \u0448 legible)
        v = o | (v & ~(o << 1) & mask)
        nb = ((w + 1 + 7) // 8) * 8
        line = '%0*X' % (nb // 4, v << (nb - (w + 1)))
    out.append(line)
open(dst, 'w', encoding='latin-1').write('\n'.join(out) + '\n')

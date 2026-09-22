#!/usr/bin/env python3
"""Measure each poster panel's bbox off the raw drop and re-paste it filling its quadrant.

Same pass corp/posters' own note records: the model does not honour a stated 2x2 split and it
paints each panel with a margin, so the seams are FOUND as the widest empty run and each panel is
cropped to its measured bbox. Its aspect travels to render.corp.CorpSigns.ASPECT.
"""
import sys
import numpy as np
from PIL import Image

src = sys.argv[1]
a = np.asarray(Image.open(src).convert('RGB')).astype(float)
H, W, _ = a.shape
g = a.mean(axis=2)
bg = np.median(g)                      # the flat charcoal wall
mark = np.abs(g - bg) > 10             # a pixel that is not wall

def runs(flags):
    """(start, length) of every maximal True run"""
    out, s = [], None
    for i, f in enumerate(list(flags) + [False]):
        if f and s is None:
            s = i
        elif not f and s is not None:
            out.append((s, i - s))
            s = None
    return out

def widest_gap(flags, lo, hi):
    """centre of the widest empty run inside [lo, hi)"""
    empty = [not f for f in flags]
    cand = [(s, l) for s, l in runs(empty) if s >= lo and s + l <= hi]
    s, l = max(cand, key=lambda r: r[1])
    return s + l // 2

colc = mark.sum(axis=0)                # content per column, whole sheet
rowc = mark.sum(axis=1)
ROW_MIN, COL_MIN = 12, 12              # the wall's own grain, per the sheet's note

rseam = widest_gap(rowc > ROW_MIN, H // 4, 3 * H // 4)
print('row seam', rseam, '(nominal %d)' % (H // 2))

def bbox(y0, y1, x0, x1):
    m = mark[y0:y1, x0:x1]
    cs = np.where(m.sum(axis=0) > COL_MIN)[0]
    rs = np.where(m.sum(axis=1) > ROW_MIN)[0]
    return (x0 + cs[0], x0 + cs[-1] + 1, y0 + rs[0], y0 + rs[-1] + 1)

out = Image.new('RGB', (W, H))
im = Image.open(src).convert('RGB')
QW, QH = W // 2, H // 2
aspects = []
for bi, (by0, by1) in enumerate(((0, rseam), (rseam, H))):
    band = mark[by0:by1, :]
    cseam = widest_gap(band.sum(axis=0) > COL_MIN, W // 4, 3 * W // 4)
    print('band %d column seam %d (nominal %d)' % (bi, cseam, W // 2))
    for qi, (bx0, bx1) in enumerate(((0, cseam), (cseam, W))):
        x0, x1, y0, y1 = bbox(by0, by1, bx0, bx1)
        w, h = x1 - x0, y1 - y0
        aspects.append(w / h)
        print('  slot %d  bbox %d,%d..%d,%d  %dx%d  aspect %.4f'
              % (4 + bi * 2 + qi, x0, y0, x1, y1, w, h, w / h))
        cell = im.crop((x0, y0, x1, y1)).resize((QW, QH), Image.LANCZOS)
        out.paste(cell, (qi * QW, bi * QH))
out.save(sys.argv[2])
print('ASPECT slots 4..7: ' + ', '.join('%.4f' % v for v in aspects))

#!/usr/bin/env python3
"""Paste one freshly generated object into ONE cell of an already-packed pack sheet.

tools/pack16.py re-packs a WHOLE drop onto a grid; this is the other half of that — the sheet is
the source of record, so a single cell that has gone dead (here facility/electrical-pack's cells 6,
7 and 15, dropped when FacilityStyle.SOCK_SKIP landed) can be refilled without paying for the other
63. Same CUT and margin conventions as pack16 so the cell matches its neighbours.

usage: pastecell.py <sheet.png> <object.png> <cellIndex> [--grid 8] [--margin 10]
"""
import argparse

import numpy as np
from PIL import Image

# pack16's own: alpha at or under this is the wash gpt paints outside the subject, not the subject
CUT = 24


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("obj")
    ap.add_argument("cell", type=int)
    ap.add_argument("--grid", type=int, default=8)
    ap.add_argument("--margin", type=int, default=10)
    a = ap.parse_args()

    # read it all in and drop the handle: textures-src is a mounted share, and saving over a path
    # PIL still has lazily open there fails with EINVAL rather than with anything readable
    with Image.open(a.sheet) as f:
        sheet = f.convert("RGBA")
    cw = sheet.width // a.grid
    ch = sheet.height // a.grid
    cx = (a.cell % a.grid) * cw
    cy = (a.cell // a.grid) * ch

    with Image.open(a.obj) as f:
        im = f.convert("RGBA")
    arr = np.asarray(im)
    # flatten the near-transparent wash, then take the subject's own alpha box
    arr = arr.copy()
    arr[:, :, 3] = np.where(arr[:, :, 3] <= CUT, 0, arr[:, :, 3])
    ys, xs = np.where(arr[:, :, 3] > 0)
    if len(xs) == 0:
        raise SystemExit("object is fully transparent")
    im = Image.fromarray(arr).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    room = min(cw, ch) - 2 * a.margin
    s = min(room / im.width, room / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)

    sheet.paste((0, 0, 0, 0), (cx, cy, cx + cw, cy + ch))
    sheet.paste(im, (cx + (cw - im.width) // 2, cy + (ch - im.height) // 2), im)
    sheet.save(a.sheet)
    print(f"  pasted {im.width}x{im.height} into cell {a.cell} of {a.sheet}")


main()

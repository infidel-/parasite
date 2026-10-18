#!/usr/bin/env python3
"""cellgamma: re-gamma ONE rect of a packed source, leaving the rest of the sheet alone.

`lift` in art/textures.json is per LABEL, so a sheet holding two objects that want different
exposures cannot be fixed with it — moving one drags the other. facility/placards hit this first
(a prohibition disc is mostly pale off-white field and came back 0.2123 linear against its
neighbours' 0.1220, and the fix was a gamma of 1.450 on that one cell), and facility/sink hit it
again from both ends: an upright polished TAP reading 1.45x the flask and scale sprites sharing its
bench, over a flat BASIN whose rim was the brightest thing on the worktop once the tap came down.

So the gamma goes on the RECT, baked into the source at composite time. Two rules:

  * ALWAYS RUN FROM A PRISTINE COPY. A gamma stacks, so a second pass over an already-corrected
    sheet is not a retune, it is a compound. Park the untouched drop in textures-src/<dir>/Unused/
    and point this at that.
  * RECORD THE RECT AND THE GAMMA IN THE textures.json NOTE. The sources are an unversioned asset
    store; the manifest is what is in the repo, so a number that is not written there cannot be
    re-derived from anything.

Rects come off the source's own alpha bboxes, which the entry's note already carries for any sheet
built this way (facility/sink: basin x 31..648 y 288..736, tap x 670..1013 y 243..735).

usage: python3 tools/cellgamma.py <pristine.png> <out.png> x0,x1,y0,y1=<gamma> [more...]
   e.g. python3 tools/cellgamma.py Unused/sink.png facility/sink.png \\
          670,1013,243,735=2.0  31,648,288,736=1.27
"""
import sys

import numpy as np
from PIL import Image


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__.strip().splitlines()[-3].strip())
    src, dst = sys.argv[1], sys.argv[2]

    im = np.asarray(Image.open(src).convert("RGBA")).copy()
    before = np.asarray(Image.open(src).convert("RGBA"))

    for spec in sys.argv[3:]:
        rect, _, g = spec.partition("=")
        x0, x1, y0, y1 = (int(v) for v in rect.split(","))
        g = float(g)
        cell = im[y0:y1, x0:x1, :3].astype(np.float64) / 255.0
        im[y0:y1, x0:x1, :3] = np.clip(cell ** g, 0, 1) * 255.0
        # report on the object's OWN opaque pixels, so the number compares with the note's srgb
        # figures rather than being diluted by the transparent field around it
        m = im[y0:y1, x0:x1, 3] > 200
        print(f"  {x0},{x1},{y0},{y1}  srgb {before[y0:y1, x0:x1, :3][m].mean():.1f}"
              f" -> {im[y0:y1, x0:x1, :3][m].mean():.1f}  (gamma {g})")

    Image.fromarray(im, "RGBA").save(dst)
    print(f"  wrote  {dst}")


if __name__ == "__main__":
    main()

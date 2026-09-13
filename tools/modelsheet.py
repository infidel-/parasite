#!/usr/bin/env python3
"""Pack BUILT game textures into one sheet for a hand-modelled glb to UV onto.

A glb gets ONE material, because render.Models.instanced takes `mesh.material` and an
InstancedMesh with a material array draws once per material — which is the draw call the
whole exercise is trying not to spend. So a Blender model that wears three of the game's
existing surfaces (a rack front, its flanks, its lid) needs those three in a single image.

Why the BUILT pngs under app/textures/ and not the textures-src/ sheet they were cropped
from: every label carries its own fitted `lift` in art/textures.json and they differ inside
one pack — the cabinet's three are 1.394 / 1.632 / 1.624 — so the source quadrants are the
UNFITTED art and packing those would silently drop three separate value fits.

The output belongs in models-src/ beside the build script, NOT in textures-src/: it is a
model source and never a game texture, so it takes no manifest entry and no `make tex`.
Name it `<something>-sheet.png` and never `<glb name>.png` — tools/models.mjs treats a bare
`<label>.png` next to a model source as a texSrc base-colour OVERRIDE.

  python3 tools/modelsheet.py models-src/facility/rack-sheet.png --cell 512 --cols 2 \
      --repeat 1x1,0.75x2,1.05x0.75,0.75x1 \
      app/textures/facility/deco-rack.png app/textures/facility/deco-rack-side.png \
      app/textures/facility/deco-rack-top.png app/textures/facility/deco-rack-side.png

Cells fill left to right, top to bottom, so cell 0 is the top-left — the same order
models-src/facility/computer_build.py's `rect()` reads.

WHY --repeat EXISTS, and it is the whole reason this is not just a montage. The emitters these
models replace TILE their art: render.facility.FacilityDeco.localFace divides the face by
DECO_RACK_TILE on both axes, so a rack's flank carries 0.75 of the image across its depth and
2.0 up its height. A hand-modelled face maps its cell 0..1 instead, which stretches a square
swatch 2.67x — and it cannot simply wrap, because walking u past a packed cell's edge slides
into the NEIGHBOURING image (docs/3d-textures.md). So the repeat is baked into the CELL: the
source is tiled and cropped to `u x v` repeats before it is scaled in. Values under 1 are a
crop, which is exactly what 0.75 across a flank means. Pass one `uxv` per cell, in order.
"""
import argparse
import sys

from PIL import Image


def tiled(im, ru, rv, cell):
    """The source repeated `ru` x `rv` times, scaled into one `cell` x `cell` square."""
    w, h = max(1, round(im.width * ru)), max(1, round(im.height * rv))
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, im.height):
        for x in range(0, w, im.width):
            out.paste(im, (x, y))
    return out.resize((cell, cell), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("src", nargs="+")
    ap.add_argument("--cell", type=int, default=512)
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--repeat", default="", help="per cell, comma-separated 'uxv' (e.g. 0.75x2)")
    a = ap.parse_args()

    reps = [tuple(float(v) for v in s.split("x")) for s in a.repeat.split(",")] if a.repeat else []
    if reps and len(reps) != len(a.src):
        print(f"--repeat has {len(reps)} entries for {len(a.src)} cells")
        return 1

    rows = (len(a.src) + a.cols - 1) // a.cols
    sheet = Image.new("RGBA", (a.cols * a.cell, rows * a.cell), (0, 0, 0, 255))
    for i, p in enumerate(a.src):
        im = Image.open(p).convert("RGBA")
        if im.width != im.height:
            print(f"  note: {p} is {im.width}x{im.height}, not square — stretched to the cell")
        ru, rv = reps[i] if reps else (1.0, 1.0)
        sheet.paste(tiled(im, ru, rv, a.cell),
                    ((i % a.cols) * a.cell, (i // a.cols) * a.cell))
        print(f"  cell {i}: {p}  repeat {ru}x{rv}")
    sheet.convert("RGB").save(a.out)
    print(f"{a.out}  {sheet.width}x{sheet.height}  {len(a.src)} cells of {a.cell}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

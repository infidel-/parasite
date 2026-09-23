#!/usr/bin/env python3
"""pack16: re-pack a generated 4x4 decoration sheet onto an EXACT grid.

gpt-image-2 draws sixteen separated groups when it is asked to, but it does not put the
seams where the prompt says (docs/3d-textures.md records the same refusal for a 2x2 pack).
Measured on the first bench sheet: the three COLUMN gaps straddled 256/512/768 cleanly, and
the three ROW gaps landed at ~262/495/731 — two of them 17 and 37 px high, so seven of the
sixteen groups crossed a nominal cell boundary. A runtime that crops cell (ix, iy) at a fixed
stride cannot use that sheet.

So the grid is DERIVED and not assumed: find the empty corridors in the alpha coverage
profile, take the sixteen content boxes they bound, and paste each one back into an exact
cell. Two things ride along, and both were bugs the sheet would otherwise have shipped:

  * ONE scale for the whole sheet, not one per cell. Every group keeps its size relative to
    its neighbours (a bench balance really is bigger than a test-tube rack); only the sheet
    as a whole is fitted so its tallest group just clears the margin.
  * horizontally centred, and vertically aligned by --valign. render.particles.Sprites anchors
    an upright sprite by its content box, and render.facility.FacilityModel places the contact
    pool off the same box — over the 43 stock icons those box centres sat -0.49..+0.15 world
    units off the cell centre, which is what "black splotches on both sides" was. Centred here,
    that offset is 0 by construction.

    --valign BOTTOM (the default) is for a sprite standing on a common ground line, which is
    what an elevation-drawn decoration is. --valign CENTER is for a TOP-DOWN object, where
    there is no ground line and bottom-aligning hangs the quad by a point that is not the
    object's own centre — see render.facility.FacilityClutter, which lays its cells flat on a
    worktop and rotates them about that centre.

Also flattens the near-transparent wash gpt paints outside the subject (alpha 1-15 over 25%
of the first drop): the sprite pool's material is `transparent` with no alphaTest, so a 2%
wash draws as a faint dark square around every decoration.

Usage: python3 tools/pack16.py <sheet.png> [-o out.png] [--cols 4] [--rows 4] [--cell 256]
                               [--tol 0] [--valign bottom|center]
The raw drop is left alone; the gridded sheet is written to -o (default: <sheet>-grid.png).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

# alpha at or under this is not the subject: gpt paints a coloured wash into the cut, and
# tools/textures.py's own bleed_alpha uses the same 24 as its "unknown colour" line
CUT = 24
# and this is what counts as SUBJECT when looking for the empty corridors between groups. it
# is well over CUT on purpose — a corridor has to be empty of art, not merely of solid art
SOLID = 96


def bands(cov, n, size, tol=0):
    """The n-1 interior splits of a coverage profile, as the midpoints of its empty runs.

    Takes the widest empty run nearest each nominal split rather than the widest overall: a
    sheet with a wide margin around one group would otherwise hand back that margin as a
    seam.

    `tol` is how many opaque px a line may still carry and count as empty. ZERO for a 4x4 or
    a 6x6, where corridors come back 12-26 px wide and a tolerance would only invite clipping.
    It exists for the 8x8, where the budget runs out: measured on a 64-cell drop, twelve of
    the fourteen seams had healthy corridors and the other two were 1 px and 0 px, so the run
    is rejected over a single antialiased pixel. Raising tol clips that many px of a
    neighbour into the wrong cell — 3% of a 128 cell at tol 4 — so it buys a marginal sheet,
    not a good one."""
    empty = cov <= tol
    runs = []
    start = None
    for i, e in enumerate(empty):
        if e and start is None:
            start = i
        elif not e and start is not None:
            runs.append((start, i - 1))
            start = None
    if start is not None:
        runs.append((start, len(empty) - 1))
    # interior runs only: the outer margins are not seams
    runs = [r for r in runs if r[0] > 0 and r[1] < len(empty) - 1]
    splits = []
    for k in range(1, n):
        want = size * k / n
        near = [r for r in runs if r[0] <= want + size / n * 0.4 and r[1] >= want - size / n * 0.4]
        if not near:
            # say HOW FAR off it is: the answer is always to re-roll the sheet with a wider gutter,
            # and the depth of the thinnest line is what says whether one group is reaching over the
            # boundary or the whole grid has drifted
            lo = max(0, int(want - size / n * 0.4))
            hi = min(len(cov), int(want + size / n * 0.4))
            worst = int(cov[lo:hi].min())
            sys.exit(f"pack16: no empty corridor near {want:.0f} — thinnest line there still carries "
                     f"{worst} opaque px, so groups touch across it. Re-roll the sheet"
                     + (f" (or --tol {worst} to clip through it)." if worst <= 4 else "."))
        r = max(near, key=lambda r: r[1] - r[0])
        splits.append((r[0] + r[1]) // 2)
    return [0] + splits + [size]


def box(alpha):
    """Opaque bounding box of a sub-rect, or None when it holds nothing."""
    ys, xs = np.where(alpha > CUT)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def shadow(cell, cx, cy, w, h, strength):
    """A soft contact ellipse to sit UNDER a group, as an RGBA layer the size of one cell.

    The pack16 sheets used to carry a painted shadow of their own, and the runtime pool
    (render.facility.FacilityStyle.TABLE_POOL_*) was only ever the other half of the grounding:
    the pool is a decal on the WORKTOP, so the sprite's tilt carries the drawn base away from
    it, and what closed that gap was the art. A repaint that drops the shadow leaves every
    decoration hanging over its own pool. This puts it back deterministically instead of
    re-rolling sixteen cells and hoping the model draws one.

    Centred on the group's bottom edge, so it reads as contact and not as a cast shadow: the
    art is pasted over the top half of it."""
    rx = max(2.0, w * 0.60)
    ry = max(1.5, h * 0.055)
    yy, xx = np.mgrid[0:cell, 0:cell]
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    # squared falloff: a soft edge with no visible rim, zero outside the ellipse
    a = np.clip(1.0 - d, 0.0, 1.0) ** 2 * (255.0 * strength)
    lay = np.zeros((cell, cell, 4), dtype=np.uint8)
    lay[:, :, 3] = a.astype(np.uint8)
    return Image.fromarray(lay, "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("-o", "--out")
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--rows", type=int, default=4)
    ap.add_argument("--cell", type=int, default=256)
    ap.add_argument("--margin", type=int, default=8, help="empty px on every side of a cell")
    ap.add_argument("--tol", type=int, default=0,
                    help="opaque px a seam line may still carry (8x8 only — see bands())")
    ap.add_argument("--valign", choices=("bottom", "center"), default="bottom",
                    help="bottom for a sprite on a ground line, center for a top-down object")
    ap.add_argument("--shadow", type=float, default=0.0,
                    help="peak alpha of a baked contact ellipse under each group (0 = none)")
    ap.add_argument("--fill", action="store_true",
                    help="stretch each group to fill its whole cell and print its aspect, for a "
                         "family whose quad is sized from the art (see --fill in main())")
    a = ap.parse_args()
    out = a.out or os.path.splitext(a.src)[0] + "-grid.png"

    im = Image.open(a.src).convert("RGBA")
    px = np.asarray(im).copy()
    # kill the wash before anything measures it, so a corridor is judged on the art alone
    px[px[:, :, 3] <= CUT, 3] = 0
    im = Image.fromarray(px, "RGBA")
    alpha = px[:, :, 3]
    solid = alpha > SOLID

    xs = bands(solid.sum(0), a.cols, im.width, a.tol)
    ys = bands(solid.sum(1), a.rows, im.height, a.tol)
    print(f"  seams  x {xs}  y {ys}")

    # every group's own box, in sheet pixels
    boxes = []
    for r in range(a.rows):
        for c in range(a.cols):
            b = box(alpha[ys[r]:ys[r + 1], xs[c]:xs[c + 1]])
            if b is None:
                sys.exit(f"pack16: cell ({c},{r}) is empty — the sheet is short a group")
            boxes.append((b[0] + xs[c], b[1] + ys[r], b[2] + xs[c], b[3] + ys[r]))

    # --fill: EACH GROUP FILLS ITS OWN CELL and its measured aspect goes to the runtime instead.
    # the one-scale-for-the-sheet rule above is for a family drawn at a common ground line, where a
    # bigger object has to stay bigger; a WALL PANEL is sized by its own longest edge against a
    # single constant (render.corp.CorpSigns.quad off CorpStyle.SIGN_MAX), so the sheet wants every
    # texel spent on art and the aspect carried in code -- which is also what keeps the uv a plain
    # grid division. Same pass tools/posterpack.py runs for the 2x2 sheets
    if a.fill:
        sheet = Image.new("RGB", (a.cols * a.cell, a.rows * a.cell))
        for i, b in enumerate(boxes):
            g = np.asarray(im.crop(b).resize((a.cell, a.cell), Image.LANCZOS)).astype(float)
            # AND THE CELL IS FLATTENED OVER ITS OWN MEDIAN, not saved with its alpha: the sheet
            # goes on a wall through a plain opaque material, so a transparent pixel draws as the
            # BLACK under it. Only a panel the model drew a degree or two off square has any --
            # 5% of a cell on this drop, all of it in the corners -- and the panel's own median is
            # the colour that corner would have been if it had been drawn straight
            al = (g[:, :, 3:4] / 255.0)
            med = np.median(g[:, :, :3][al[:, :, 0] > 0.9], axis=0)
            rgb = g[:, :, :3] * al + med * (1.0 - al)
            sheet.paste(Image.fromarray(rgb.astype(np.uint8), "RGB"),
                        ((i % a.cols) * a.cell, (i // a.cols) * a.cell))
        sheet.save(out)
        print("  aspects " + ", ".join("%.4f" % ((b[2] - b[0]) / (b[3] - b[1])) for b in boxes))
        print(f"  wrote  {out}  {sheet.width}x{sheet.height}  (filled)")
        return

    # ONE scale for the sheet: the tallest/widest group just clears the margin
    fit = a.cell - 2 * a.margin
    scale = min(fit / max(b[2] - b[0] for b in boxes), fit / max(b[3] - b[1] for b in boxes))
    print(f"  scale  {scale:.4f}  (largest group {max(b[2] - b[0] for b in boxes)}"
          f"x{max(b[3] - b[1] for b in boxes)} px)")

    sheet = Image.new("RGBA", (a.cols * a.cell, a.rows * a.cell), (0, 0, 0, 0))
    for i, b in enumerate(boxes):
        w = max(1, int(round((b[2] - b[0]) * scale)))
        h = max(1, int(round((b[3] - b[1]) * scale)))
        g = im.crop(b).resize((w, h), Image.LANCZOS)
        cx = (i % a.cols) * a.cell + (a.cell - w) // 2
        cy = (i // a.cols) * a.cell + ((a.cell - h) // 2 if a.valign == "center"
                                       else a.cell - a.margin - h)
        # the shadow goes down FIRST, so the art sits on top of its own near half
        if a.shadow > 0:
            lay = shadow(a.cell, cx - (i % a.cols) * a.cell + w / 2.0,
                         cy - (i // a.cols) * a.cell + h, w, h, a.shadow)
            sheet.alpha_composite(lay, ((i % a.cols) * a.cell, (i // a.cols) * a.cell))
        # composite and not paste: paste REPLACES alpha, which would punch the shadow back out
        # everywhere the group's own bounding box is transparent
        sheet.alpha_composite(g, (cx, cy))
    sheet.save(out)
    print(f"  wrote  {out}  {sheet.width}x{sheet.height}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""atlaspaste: bake a pack16 cell down into an entities64 frame, for the 2D view.

The 3D sprite pool draws a bench decoration off its 256 px pack cell (Const.FACILITY_DECO_HD),
but everything else in the engine addresses it as an entities64 frame. For a frame that already
existed that is fine — the two are the same object drawn twice. For a frame the packs INVENT the
atlas cell is EMPTY, and every non-pool reader of it draws nothing.

Today that is insurance rather than a live path: GameScene.is3DArea lists 'facility', so a
compound never takes the 2D `area.draw()` branch and the sprite pool is the only thing asking.
It is still the right thing to bake — a frame that exists in the deal table and not in the atlas
is a trap for the next reader of it, and the whole family is one command to rebuild.

So a new frame gets its 64 px icon from the same art, LANCZOS'd down. Measured on the four-item
clusters this family draws: they still read at 64 (a centrifuge, a crate stack, a pH meter and a
vacuum pump are all still nameable), which is what makes the invented frames possible at all.

The atlas is NOT in the repo — assets/graphics/entities64.png is a stale 512x1280 from February
and the live sheet is 768x3072 in the unversioned app dir, the same arrangement textures-src has.
That is survivable only because this tool is deterministic and re-runnable: the pack sheets are
the source, so a lost atlas cell is one command back.

Usage:
  python3 tools/atlaspaste.py <sheet.png> <cell>=<row>,<col> [...] [--atlas PATH] [--grow]
                              [--cols 4] [--cell 256]
    <cell>  0-based index into the sheet, reading order (the same order as FACILITY_DECO_HD)
    --grow  extend the atlas downward when a target row is past its last one
    --cols/--cell  the SHEET's grid, for a pack that is not the bench family's 4x4 of 256 —
                   Const.CLUE_PACK_COLS/CLUE_PACK_CELL is 6 and 170
"""
import argparse
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "parasite", "resources", "app", "img", "entities64.png")
CELL = 64
PACK_COLS = 4
PACK_CELL = 256


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("pairs", nargs="+", help="<cell>=<row>,<col>")
    ap.add_argument("--atlas", default=ATLAS)
    ap.add_argument("--grow", action="store_true")
    ap.add_argument("--cols", type=int, default=PACK_COLS)
    ap.add_argument("--cell", type=int, default=PACK_CELL)
    a = ap.parse_args()

    sheet = Image.open(a.sheet).convert("RGBA")
    atlas = Image.open(a.atlas).convert("RGBA")
    cols = atlas.width // CELL
    rows = atlas.height // CELL

    jobs = []
    for p in a.pairs:
        cell, _, rc = p.partition("=")
        row, _, col = rc.partition(",")
        jobs.append((int(cell), int(row), int(col)))

    want = max(r for _, r, _ in jobs) + 1
    if want > rows:
        if not a.grow:
            sys.exit(f"atlaspaste: row {want - 1} is past the atlas' last ({rows - 1}) — pass --grow")
        grown = Image.new("RGBA", (atlas.width, want * CELL), (0, 0, 0, 0))
        grown.paste(atlas, (0, 0))
        atlas = grown
        print(f"  grew atlas {rows} -> {want} rows")
        rows = want

    for cell, row, col in jobs:
        if col >= cols:
            sys.exit(f"atlaspaste: column {col} is past the atlas' last ({cols - 1})")
        sx = (cell % a.cols) * a.cell
        sy = (cell // a.cols) * a.cell
        icon = sheet.crop((sx, sy, sx + a.cell, sy + a.cell)).resize((CELL, CELL), Image.LANCZOS)
        # clear first: paste() with an alpha mask leaves whatever the cell already held showing
        # through the transparent margin, and these cells are mostly margin
        atlas.paste((0, 0, 0, 0), (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
        atlas.paste(icon, (col * CELL, row * CELL))
        print(f"  cell {cell:2d} -> frame {row}/{col}")

    # write beside it and rename, rather than saving over it: the atlas lives on the Windows-side
    # DrvFs mount and opening an existing file there "w+b" (which is what PIL's save does) comes
    # back OSError 22 Invalid argument, while creating a new one and replacing works
    tmp = a.atlas + ".tmp.png"
    atlas.save(tmp)
    os.replace(tmp, a.atlas)
    print(f"  wrote  {a.atlas}  {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    main()

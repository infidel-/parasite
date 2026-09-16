#!/usr/bin/env python3
"""Texture build: textures-src/ (1024 sources) -> textures/ (downscaled runtime).

Driven by art/textures.json (tracked; the sources it points at are not). For each texture it:
  1. renames freshly generated gpt files (image-*/edit-* -> <label>.png) in src,
  2. downscales src -> textures/<label>.png at the entry's res (default_res else),
     only when the source is newer than the last conversion (or output missing),
  3. for class "chroma": bakes the key color to alpha before downscaling,
  3b. for an entry with "lift": raises its RGB by that gamma, for art gpt painted too
     dark for the surface it lands on (see lift_gamma; alpha is left alone),
  3c. for an entry with "glass_alpha": drops the alpha of the BRIGHT half of a glazing
     texture so the panes go see-through and the dark frame stays solid (see glass_cut),
  3d. for an entry with "sat": mixes it toward its own luminance, for art painted in a
     chroma the room's palette cannot take (see sat_mix; luma is preserved),
  3e. for an entry with "cells": scales any cell of a PACK sheet that is brighter than the
     stated cap down onto it, and leaves the rest alone — over the whole sheet or over one
     row band of it (see cell_cap),
  3f. for an entry with "regrid": finds each object of a PACK sheet and re-centres it in its
     own cell, so the UV split the render side deals by index lands on one subject (see regrid),
  4. warns when a needs_alpha texture has no real alpha (gpt can't emit it ->
     the source must be human-edited),
  5. rewrites textures.json with the new last_converted timestamps.

It never calls gpt-image-2; regeneration is manual (use the stored prompt).

Usage: python3 tools/textures.py   (run from repo root; `make tex` wraps it)
"""
import json
import os
import re
import sys
from datetime import datetime

import numpy as np
from PIL import Image

from pix import measure  # one copy of the value statistic, shared with the measuring tool

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "textures-src")
# runtime textures are served from the electron app dir (staged into app/ by the build)
OUT_DIR = os.path.join(ROOT, "parasite", "resources", "app", "textures")
# the manifest is TRACKED and lives in the repo, while the sources it points at do not: it carries
# every prompt, crop and lift, so a commit's measured constants (an aspect lock, a rail fraction)
# stay explainable even though the art store is unversioned
INFO = os.path.join(ROOT, "art", "textures.json")
GPT_PREFIX = re.compile(r"^(image|edit)-\d+-\d+-[0-9a-f]+-(.+)$")

warnings = []


def warn(msg):
    warnings.append(msg)
    print(f"  ! {msg}")


def rename_generated():
    """Strip gpt prefix so a freshly generated image-...-<label>.png becomes <label>.png.
    Walks subdirs (e.g. decals/) so a drop generated into textures-src/<sub>/ is renamed in place."""
    for root, _dirs, files in os.walk(SRC_DIR):
        for f in sorted(files):
            m = GPT_PREFIX.match(f)
            if not m:
                continue
            dst = m.group(2)
            os.replace(os.path.join(root, f), os.path.join(root, dst))
            print(f"  renamed {f} -> {dst}")


def has_alpha(im):
    if "A" not in im.getbands():
        return False
    lo, hi = im.getchannel("A").getextrema()
    return lo < 255  # some pixel is non-opaque


def chroma_key(im, color_hex, tol):
    """Make pixels within `tol` of color_hex transparent (RGBA out)."""
    im = im.convert("RGBA")
    c = int(color_hex, 16)
    key = np.array([(c >> 16) & 255, (c >> 8) & 255, c & 255])
    a = np.asarray(im).copy()
    dist = np.abs(a[:, :, :3].astype(int) - key).max(axis=2)
    a[dist < tol, 3] = 0
    return Image.fromarray(a, "RGBA")


def lift_gamma(im, g):
    """Re-gamma a source with out = (v/255)**g. g < 1 lifts the darks and leaves the top end alone;
    g > 1 pulls it DOWN the same way, for the opposite failure — gpt handed back a lab corridor wall
    at linear 0.1077, the brightest thing in the facility set and above its own lit windows, where
    the value ladder wanted 0.069 (facility/wall-interior, lift 1.22). Same knob, both directions.

    For art authored much darker than the surface it lands on. gpt paints a rusted pipe or a drain
    grate near-black, and three decodes sRGB to LINEAR before the Lambert multiply, so a decal at
    0.46x the surface in bytes is 0.19x in light — it renders as a HOLE in the ground, not an object
    (measured: sewer top-valve at luma 6.7 against the ledge cap's 35.7). Dropping material opacity
    fixes the value but makes a see-through valve; lifting the source keeps it solid. Alpha is
    untouched, so a hand-cut cut-out survives and needs no re-cutting."""
    mode = "RGBA" if "A" in im.getbands() else "RGB"
    a = np.asarray(im.convert(mode)).astype(np.float32)
    out = a.copy()
    out[:, :, :3] = np.clip((a[:, :, :3] / 255.0) ** g * 255.0, 0, 255)
    return Image.fromarray(out.astype(np.uint8), mode)


# sRGB <-> linear, the IEC transfer, on 0..255 float arrays. tools/pix.py carries the forward half
# because measuring only ever goes one way; both directions are needed here, because every knob below
# does its arithmetic in LIGHT and has to hand bytes back.
def to_linear(v):
    v = v / 255.0
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)


def to_srgb(v):
    v = np.clip(v, 0.0, 1.0)
    return np.where(v <= 0.0031308, v * 12.92, 1.055 * v ** (1 / 2.4) - 0.055) * 255.0


W709 = np.array([0.2126, 0.7152, 0.0722], np.float32)


def sat_mix(im, s):
    """Mix every pixel toward its own Rec.709 luminance: s = 1 is a byte-exact no-op, 0 is grey.

    For art whose chroma the room's palette cannot take — flat-design vector work in a dark laboratory,
    the case render.facility.FacilityStyle.DECO_TABLE_SAT exists for.

    DELIBERATELY THE SAME INSTRUMENT IN THE SAME SPACE as the `spriteSat` uniform that
    render.particles.Sprites patches into the sprite pool: Rec.709 weights are a linear-light
    instrument, so a mix taken above the EOTF desaturates by a different amount at every value and a
    number baked here would stop meaning what the same number means handed to that uniform. Luminance
    is preserved by construction, so this moves chroma and not value — pair it with `cell_cap` or
    `lift_gamma` if the level is wrong too. Alpha is untouched."""
    mode = "RGBA" if "A" in im.getbands() else "RGB"
    a = np.asarray(im.convert(mode)).astype(np.float32)
    lin = to_linear(a[:, :, :3])
    y = (lin * W709).sum(axis=2, keepdims=True)
    out = a.copy()
    out[:, :, :3] = to_srgb(y + (lin - y) * s)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), mode)


def components(mask):
    """Every 4-connected run of True in `mask`, as a label image and its labels (background 0).

    A scanline union-find rather than scipy.ndimage, which is not installed and is not worth a
    dependency for eighty lines: the loop runs over the OPAQUE pixels only (43% of a pack sheet) and
    a 1024 sheet labels in about a second, which is a build-time cost paid once per source change."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    parent = [0]

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    nxt = 1
    for y in range(h):
        cols = np.nonzero(mask[y])[0]
        if not len(cols):
            continue
        prev = lab[y - 1] if y else None
        for x in cols:
            up = int(prev[x]) if prev is not None else 0
            left = int(lab[y, x - 1]) if x else 0
            if up and left:
                lab[y, x] = up
                ra, rb = find(up), find(left)
                if ra != rb:
                    parent[max(ra, rb)] = min(ra, rb)
            elif up or left:
                lab[y, x] = up or left
            else:
                lab[y, x] = nxt
                parent.append(nxt)
                nxt += 1
    roots = np.array([find(i) for i in range(nxt)], np.int32)
    return roots[lab]


def regrid(im, grid, cut=200, fill=0.86, floor=0.0006, grow=6):
    """Re-centre every object of a pack sheet into its own cell of a strict grid:grid split.

    THE SHEET'S GRID IS THE ONE THING THE PROMPT CANNOT BUY. render.facility.FacilityClutter and its
    two copies deal a cell by index and map `cc/grid .. (cc+1)/grid` across the quad, so a subject
    that sits half a cell low is drawn as two halves of two different objects. Measured on
    facility/hangar-clutter, whose prompt asks for a 20% empty gutter in both axes and whose COLUMN
    lanes land within a texel of the nominal split while its ROW lanes come in at 0/128/384/512/640/
    736/864/992 against a nominal 128 pitch: the clipboard in cell 61 straddles the boundary into 53
    and was reported from the game as the tripod above it carrying a strip of clipboard.

    A GAMMA, A CAP AND A SKIP LIST CANNOT TOUCH THIS — it is geometry, not value — and neither can a
    per-row v offset, since the measured lanes do not partition the sheet evenly. So the objects are
    found and MOVED: one alpha component per cell, scaled down only if its own bbox will not fit, and
    centred. Nothing is repainted, so every texel a subject owns survives.

    `cut` IS A FINDING THRESHOLD AND NOT A CUT, and it is high (200, not the 128 the render side
    tests) for one measured reason: these sheets carry wide soft haze — oil stains, scorch, scuff —
    whose alpha crosses the lanes and BRIDGES two solid subjects into one component. Swept on the
    hangar sheet: 128 finds 44 of 64 objects, 180 finds 53, 200 finds 56, 250 finds 8. The patch is
    then taken from the component's bbox GROWN by `grow` and keeps every faint texel in it, so the
    halo travels with its object; only another object's solid core is masked out.

    A CELL NOTHING WAS FOUND IN IS COPIED THROUGH UNCHANGED rather than left empty. Eight of the
    hangar sheet's cells are still bridged or under the floor, and a pass-through leaves those
    exactly as bad as they are today instead of dealing a hole — the conservative half of the trade.

    `fill` is the most of a cell's width an object may take, which is what keeps the gutter the UV
    split needs. `floor` is the smallest component worth keeping as a fraction of the sheet, which
    drops the speckle a chroma key or a soft edge leaves behind. Returns (image, moved, passed)."""
    im = im.convert("RGBA")
    a = np.asarray(im).copy()
    h, w = a.shape[:2]
    ch, cw = h // grid, w // grid
    lab = components(a[:, :, 3] > cut)
    area = np.bincount(lab.ravel())
    ys, xs = np.nonzero(lab)
    ids = lab[ys, xs]
    # one component per cell: the biggest whose CENTROID lands in it, so a stain that spreads over a
    # lane still belongs to the cell it is centred on rather than to both
    big = max(1, int(floor * h * w))
    best = {}
    for i in np.nonzero(area >= big)[0]:
        if i == 0:
            continue
        m = ids == i
        cy, cx = ys[m].mean(), xs[m].mean()
        cell = (min(grid - 1, int(cy // ch)), min(grid - 1, int(cx // cw)))
        if cell not in best or area[i] > area[best[cell]]:
            best[cell] = i
    out = np.zeros_like(a)
    moved, passed = 0, []
    for r in range(grid):
        for c in range(grid):
            if (r, c) not in best:
                out[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = \
                    a[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
                passed.append(r * grid + c)
                continue
            i = best[(r, c)]
            m = ids == i
            y0 = max(0, int(ys[m].min()) - grow)
            y1 = min(h, int(ys[m].max()) + 1 + grow)
            x0 = max(0, int(xs[m].min()) - grow)
            x1 = min(w, int(xs[m].max()) + 1 + grow)
            box = lab[y0:y1, x0:x1]
            patch = a[y0:y1, x0:x1].copy()
            patch[:, :, 3] = np.where((box == i) | (box == 0), patch[:, :, 3], 0)
            ph, pw = y1 - y0, x1 - x0
            sc = min(1.0, fill * ch / ph, fill * cw / pw)
            if sc < 1.0:
                ph, pw = max(1, int(round(ph * sc))), max(1, int(round(pw * sc)))
                patch = np.asarray(Image.fromarray(patch, "RGBA").resize((pw, ph), Image.LANCZOS))
            oy, ox = r * ch + (ch - ph) // 2, c * cw + (cw - pw) // 2
            out[oy:oy + ph, ox:ox + pw] = patch
            moved += 1
    return Image.fromarray(out, "RGBA"), moved, passed


def cell_cap(im, grid, cap, rows=None):
    """Scale any cell of a grid:grid pack sheet whose mean linear luminance is over `cap` down onto it,
    in LINEAR light, and leave every cell already at or under it alone. Returns (image, cells moved).

    `rows` is an optional [first, last) ROW BAND, for a pack whose halves land on different surfaces:
    facility/electrical-pack draws its first four rows on a WALL (0.55x facility/wall-room is the band
    every shipped wall fitting sits in) and its last four flat on a FLOOR, where the same cap would
    take a dull orange lead and a yellow warning plate down to a quarter of the tile they lie on.

    THE ONLY THING THAT CAN SAY "these cells and not those". `lift` is one number over a whole sheet,
    and on a pack whose subjects genuinely differ in albedo it cannot be fitted at all: measured on
    facility/worktop-clutter, whose 57 dealt cells run 0.0476 at p10 to 0.3171 at p90, the gamma that
    lands the sheet on the bench family's band (1.25) takes the cells rendering UNDER their own worktop
    from 5 to 13 and the darkest to 0.24x it — lift_gamma's own hole-in-the-ground failure, reached
    from the other direction.

    A LINEAR SCALE AND NOT A SECOND GAMMA, for the other half of the same reason: the paper cells on
    that sheet want a factor of 0.24, which as a gamma is 2.66 and crushes their printed detail to
    black. A multiply moves a cell's level and holds its internal contrast.

    AND IT CAN ONLY EVER DARKEN. A cell under the cap is not touched, so the dark cells that read
    correctly as dark objects (the finding docs/3d-render.md records against condemning them by value)
    survive by construction rather than by a skip list.

    Measured over OPAQUE pixels only — tools/pix.py prints its `opaque` column for this reason:
    including a cut-out sheet's transparent margin reports 0.0686 where its subjects are at 0.1528."""
    mode = "RGBA" if "A" in im.getbands() else "RGB"
    a = np.asarray(im.convert(mode)).astype(np.float32)
    h, w = a.shape[:2]
    ch, cw = h // grid, w // grid
    moved = 0
    r0, r1 = (rows if rows else (0, grid))
    for r in range(r0, r1):
        for c in range(grid):
            cell = a[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
            op = cell[:, :, 3] > 128 if mode == "RGBA" else np.ones(cell.shape[:2], bool)
            if not op.any():
                continue
            lin = to_linear(cell[:, :, :3])
            m = float((lin * W709).sum(axis=2)[op].mean())
            if m <= cap:
                continue
            cell[:, :, :3] = to_srgb(lin * (cap / m))
            moved += 1
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), mode), moved


def glass_cut(im, thr, a):
    """Take every pixel brighter than `thr` down to alpha `a`, leaving darker ones opaque.

    For a window unit painted as one flat elevation: the frame and mullions have to stay solid
    while the panes go see-through, and a luma threshold separates them outright because the two
    are the texture's two modes. Measured on facility/window-large-lit: frame at luma 16-127
    (25.9%), glass at 144-207 (73.4%), and a 0.7% valley at 128-143 to put the threshold in.
    Run on the FULL-RES source, before the LANCZOS downscale, so the frame/glass alpha edge is
    resampled soft instead of landing jagged. Pixels already cut (the API's transparent margin)
    are left alone, so this composes with background:"transparent" rather than fighting it."""
    im = im.convert("RGBA")
    px = np.asarray(im).copy()
    rgb = px[:, :, :3].astype(int)  # explicit: uint8 * 299 overflows in place under NEP 50
    luma = (rgb[:, :, 0] * 299 + rgb[:, :, 1] * 587 + rgb[:, :, 2] * 114) // 1000
    px[(luma >= thr) & (px[:, :, 3] > 128), 3] = a
    return Image.fromarray(px, "RGBA")


def bleed_alpha(im, iters=20):
    """Overwrite (near-)transparent texels' RGB with their nearest opaque colour.
    Run AFTER the LANCZOS downscale: PIL resizes RGBA without premultiplying, so the
    alpha edge drives per-channel ringing that manufactures saturated colour at low
    alpha (invisible until straight-alpha texture filtering bleeds it out as cyan/
    magenta specks on dark walls). Flooding clean neighbour colour over those texels
    erases the junk (and leaves no dark halo). Alpha itself is left untouched."""
    im = im.convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb = a[:, :, :3]
    known = a[:, :, 3] > 24  # low alpha (incl. the ring fringe) = unknown colour, to be refilled
    for _ in range(iters):
        if known.all():
            break
        sums = np.zeros_like(rgb)
        cnt = np.zeros(rgb.shape[:2], np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            kn = np.roll(known, (dy, dx), (0, 1))
            sums += np.roll(rgb, (dy, dx), (0, 1)) * kn[:, :, None]
            cnt += kn
        fill = (~known) & (cnt > 0)
        rgb[fill] = sums[fill] / cnt[fill][:, None]
        known |= fill
    out = np.empty(a.shape, np.uint8)
    out[:, :, :3] = np.clip(rgb, 0, 255)
    out[:, :, 3] = np.asarray(im)[:, :, 3]
    return Image.fromarray(out, "RGBA")


def convert(label, e, default_res):
    src = os.path.join(SRC_DIR, e["src"])
    out = os.path.join(OUT_DIR, label + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)  # nested labels (e.g. decals/...) -> subdir
    if not os.path.exists(src):
        warn(f"{label}: source {e['src']} missing")
        return False

    src_mtime = datetime.fromtimestamp(os.path.getmtime(src)).replace(microsecond=0)
    last = e.get("last_converted")
    lift = e.get("lift")
    glass = e.get("glass_alpha")
    sat = e.get("sat")
    cells = e.get("cells")
    grid = e.get("regrid")
    fresh = (
        not os.path.exists(out)
        or last is None
        or src_mtime > datetime.fromisoformat(last)
        or lift != e.get("last_lift")  # retuning the lift must rebuild; the source never changed
        or glass != e.get("last_glass_alpha")  # and the same for the glazing cut
        or sat != e.get("last_sat")  # and the desaturation
        or cells != e.get("last_cells")  # and the per-cell cap
        or grid != e.get("last_regrid")  # and the pack re-grid
    )

    res = e.get("res", default_res)
    ow, oh = (int(res[0]), int(res[1])) if isinstance(res, (list, tuple)) else (int(res), int(res))
    if fresh:
        im = Image.open(src)
        # a hand-cut source saved as an 8-bit PALETTE png carries its alpha in a tRNS chunk, which
        # getbands() reports as ("P",) — every alpha test below would then read it as opaque, the
        # lift would convert it to RGB and DROP the cut, and the run would end telling you to go
        # hand-edit a source that already had alpha. normalise it here, once
        if "transparency" in im.info or im.mode == "LA":
            im = im.convert("RGBA")
        # "crop": [x, y, w, h] takes one sub-rect of the source, so SEVERAL labels can share one
        # generated sheet (four 512 tiles packed into one 1024 gen — a quarter of the image cost).
        # cropped before the lift, so each tile on a shared sheet still takes its own gamma
        cr = e.get("crop")
        if cr:
            im = im.crop((int(cr[0]), int(cr[1]), int(cr[0]) + int(cr[2]), int(cr[1]) + int(cr[3])))
        if e["class"] == "chroma":
            im = chroma_key(im, e.get("chroma", "0x000000"), e.get("tol", 24))
        # AFTER the chroma key and BEFORE everything else: the key is what makes the alpha this
        # reads the objects out of, and the two value passes below plus `cells` all measure per cell,
        # so they have to see the corrected grid
        moved, passed = 0, []
        if grid:
            im, moved, passed = regrid(im, int(grid["grid"]), int(grid.get("cut", 200)),
                float(grid.get("fill", 0.86)), float(grid.get("floor", 0.0006)))
            if passed:
                print(f"    regrid found nothing in cells {passed} — copied through unchanged")
        if lift:
            im = lift_gamma(im, lift)
        if glass:
            im = glass_cut(im, int(glass[0]), int(glass[1]))
        # chroma first and then level, which is an order and not a preference: `sat_mix` preserves
        # luminance, so the cap below measures the same number either way, while a cap taken first
        # would still be correct only by that same accident. Both run on the FULL-RES source, ahead of
        # the LANCZOS downscale, for glass_cut's reason — and the cap needs the source's own grid
        if sat is not None:
            im = sat_mix(im, float(sat))
        capped = 0
        if cells:
            im, capped = cell_cap(im, int(cells["grid"]), float(cells["cap"]), cells.get("rows"))
        im = im.resize((ow, oh), Image.LANCZOS)
        if has_alpha(im):
            im = bleed_alpha(im)  # scrub the LANCZOS colour-ring fringe at low alpha
        im.save(out)
        e["last_converted"] = src_mtime.isoformat()
        if lift is None:
            e.pop("last_lift", None)
        else:
            e["last_lift"] = lift
        if glass is None:
            e.pop("last_glass_alpha", None)
        else:
            e["last_glass_alpha"] = glass
        if sat is None:
            e.pop("last_sat", None)
        else:
            e["last_sat"] = sat
        if cells is None:
            e.pop("last_cells", None)
        else:
            e["last_cells"] = cells
        if grid is None:
            e.pop("last_regrid", None)
        else:
            e["last_regrid"] = grid
        extra = ("  lift " + str(lift) if lift else "") + ("  glass " + str(glass) if glass else "")
        extra += ("  sat " + str(sat) if sat is not None else "")
        extra += (f"  regrid {moved}/{int(grid['grid']) ** 2}" if grid else "")
        extra += (f"  cap {cells['cap']} on {capped}/{cells['grid'] ** 2}"
                  + (f" rows {cells['rows']}" if cells.get("rows") else "") if cells else "")
        print(f"  built {label}.png  {ow}x{oh}  ({im.mode}){extra}")

    if e.get("needs_alpha") and not has_alpha(Image.open(out)):
        warn(f"{label}: needs transparency but {e['src']} is opaque — human-edit the source")

    # record what the surface ACTUALLY came out at. Nearly every judgement in docs/3d-render.md is a
    # ratio between two of these ("a ground layer at 1.11x its neighbour is invisible"), and until
    # now each one cost a throwaway measuring script, so the numbers only survived in prose. Written
    # for every entry, not just rebuilt ones, so an untouched tree backfills on the next run; the
    # lift notes above are the same statistic, so old and new rows compare directly.
    if fresh or "built_linear" not in e:
        lum, srgb = measure(out)
        e["built_linear"] = round(lum, 4)
        e["built_srgb"] = round(srgb, 1)
    return fresh


def main():
    # `--rename` only adopts freshly generated gpt drops (strip prefix), no baking.
    # Use for raw sources kept in textures-src/ that never go through the square bake
    # (e.g. the 16:9 storefronts): `make adopt`.
    if "--rename" in sys.argv:
        rename_generated()
        return
    if not os.path.exists(INFO):
        sys.exit(f"missing {INFO}")
    rename_generated()
    with open(INFO) as f:
        info = json.load(f)
    default_res = info.get("default_res", 512)
    os.makedirs(OUT_DIR, exist_ok=True)

    tracked = set()
    built = 0
    ok = []
    for label, e in info["textures"].items():
        tracked.add(e["src"])
        if convert(label, e, default_res):
            built += 1
        else:
            ok.append(label)
    if ok:
        print(f"  ok    {len(ok)} up to date")

    # Untracked sources (ignore the json and any un-renamed gpt drops). Walk subdirs so
    # tracked paths like "decals/foo.png" match and stray files in subfolders are flagged.
    for root, _dirs, files in os.walk(SRC_DIR):
        # skip the unused/ and used/ shelves (any case): sources parked out of the pipeline, not deleted
        for d in [d for d in _dirs if d.lower() in ("unused", "used")]:
            _dirs.remove(d)
        for f in files:
            # sweep editor backup files (*~) instead of leaving them to clutter the source tree
            if f.endswith("~"):
                os.remove(os.path.join(root, f))
                print(f"  removed backup {os.path.relpath(os.path.join(root, f), SRC_DIR)}")
                continue
            # skip Krita working files silently (editable source, not a texture)
            if f.endswith(".kra"):
                continue
            rel = os.path.relpath(os.path.join(root, f), SRC_DIR)
            if GPT_PREFIX.match(f) or rel in tracked:
                continue
            warn(f"untracked source {rel} (add it to textures.json or delete it)")

    with open(INFO, "w") as f:
        json.dump(info, f, indent=2)
        f.write("\n")

    print(f"\n{built} built, {len(info['textures']) - built} up-to-date, {len(warnings)} warning(s)")
    if warnings:
        print("warnings:")
        for w in warnings:
            print("  - " + w)


if __name__ == "__main__":
    main()

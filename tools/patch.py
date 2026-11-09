#!/usr/bin/env python3
"""Add a detail to accepted art without touching the rest: a mask for the edit, then a merge that keeps the original.

    python3 tools/patch.py mask W H x0,y0,x1,y1 OUT.png          -> an API mask, transparent over the box
    python3 tools/patch.py merge ORIG EDIT x0,y0,x1,y1 OUT.png   -> EDIT pasted over ORIG only where it changed, in the box
    python3 tools/patch.py selftest

Every edit re-draws the whole image, mask or markup or not (2.5: ~1% of pixels unchanged; 2.6 sunburst with a
mask: 2-3%; median drift 4-6/255). merge finds where the edit really changed inside the box (max-channel diff
over 40, specks opened away, gaps closed, grown a few px), feathers that 1.5 px and composites the edit there
only: the rest comes back byte-identical (nullstone's Varn tails: 96-97% of the figure). Works on any edit, of any
model, made with or without the mask. Alpha is kept: a transparent original merges as RGBA, an opaque one as RGB.
See docs/3d-textures.md, *Non-destructive detail edits*.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter


def box(s: str):
    return tuple(int(v) for v in s.split(","))


def grow(a, flt):
    """a morphology step on a bool array, through a PIL rank filter"""
    return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(flt)) > 127


def mask(w: int, h: int, b, out: str):
    a = np.full((h, w), 255, np.uint8)
    a[b[1]:b[3], b[0]:b[2]] = 0
    Image.fromarray(np.dstack([np.zeros((h, w, 3), np.uint8), a]), "RGBA").save(out)


def merge(orig: Image.Image, edit: Image.Image, b) -> tuple:
    """the composite, and the share of pixels left byte-identical and the share taken from the edit"""
    mode = "RGBA" if orig.has_transparency_data else "RGB"
    orig, edit = orig.convert(mode), edit.convert(mode)
    o, e = np.asarray(orig).astype(int), np.asarray(edit).astype(int)
    inside = np.zeros(o.shape[:2], bool)
    inside[b[1]:b[3], b[0]:b[2]] = True
    t = (np.abs(o - e).max(2) > 40) & inside
    t = grow(grow(t, ImageFilter.MinFilter(3)), ImageFilter.MaxFilter(3))
    t = grow(grow(t, ImageFilter.MaxFilter(15)), ImageFilter.MinFilter(9)) & inside
    alpha = Image.fromarray((t * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))
    out = Image.composite(edit, orig, alpha)
    same = (np.asarray(out).astype(int) == o).all(2).mean()
    return out, same, t.mean()


def selftest():
    rng = np.random.default_rng(1)
    o = rng.integers(0, 256, (200, 160, 3))
    e = np.clip(o + rng.integers(-6, 7, o.shape), 0, 255)  # the re-draw drift everywhere
    e[120:170, 30:70] = (200, 120, 40)                      # the new detail
    out, same, took = merge(Image.fromarray(o.astype(np.uint8)), Image.fromarray(e.astype(np.uint8)), (20, 100, 90, 190))
    r = np.asarray(out).astype(int)
    assert (r[:100] == o[:100]).all() and (r[:, 100:] == o[:, 100:]).all(), "outside the box changed"
    assert (r[130:160, 40:60] == (200, 120, 40)).all(), "the detail was lost"
    assert same > 0.9, same
    a = np.dstack([o, np.full(o.shape[:2], 255)]).astype(np.uint8)  # a transparent sprite: the alpha must survive
    a[:20] = 0
    ra = np.asarray(merge(Image.fromarray(a), Image.fromarray(e.astype(np.uint8)), (20, 100, 90, 190))[0])
    assert ra.shape[2] == 4 and (ra[:20, :, 3] == 0).all(), "the alpha was lost"
    print(f"selftest ok: {same:.1%} identical, {took:.1%} taken")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "mask":
        mask(int(sys.argv[2]), int(sys.argv[3]), box(sys.argv[4]), sys.argv[5])
    elif cmd == "merge":
        out, same, took = merge(Image.open(sys.argv[2]), Image.open(sys.argv[3]), box(sys.argv[4]))
        out.save(sys.argv[5])
        print(f"{sys.argv[5]}: {same:.1%} of pixels byte-identical to the original, {took:.1%} taken from the edit")
    else:
        selftest()

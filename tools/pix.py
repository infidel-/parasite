#!/usr/bin/env python3
"""Measure the value of a texture, a screenshot region or an atlas cell.

This is the measurement the render log is written in. Nearly every verdict row in
docs/3d-render.md and every `lift` note in art/textures.json quotes a mean LINEAR luminance,
because sRGB bytes lie about ratios: 127.5/51 is 2.5x in bytes and 6.66x in light, and reading
one for the other is a trap the log records more than once. Eight throwaway scripts in three
sessions computed exactly this, four of them retyping the same sRGB->linear transfer.

  python3 tools/pix.py app/textures/wild/ground.png                     one surface
  python3 tools/pix.py app/textures/wild/*.png                          a value ladder
  python3 tools/pix.py sshot.jpg --box lino,900,600,1020,660 --scene    a region of a frame
  python3 tools/pix.py app/img/entities128.png --atlas 16,0,16,16,32,32  one atlas cell
  python3 tools/pix.py models-src/sewer/drum-base.png --hue             what colour IS it

What each column is, and why it is there:

  srgb / rgb    the bytes, for talking to an image model about a repaint. `chroma` is
                max-min of the channel means: a neutral surface here renders at G-B ~ -2.6
                (the rig is blue), so anything much off that is carrying a cast of its own.
  linear        mean linear LUMINANCE (Rec.709, per pixel then averaged). THE number, and not
                the flat channel mean — on the green-dominant wilderness set those two differ
                by 3-9%, enough to invert a judgement about which of two layers is lighter.
                Compare a surface to its NEIGHBOUR, never to an absolute: a ground layer at
                1.11x its neighbour is invisible in the built frame however good the ratio
                looks on paper.
  scene         (--scene) the pre-tonemap scene value a screenshot pixel came from, by
                bisecting three's ACESFilmic. Only meaningful on a captured FRAME; on a
                texture the linear column is already the authored value.

A texture measured here is the BUILT artifact under app/textures/. The source in textures-src/
is a different number — 0.2206 vs 0.056 on the sewer floor — and confusing the two is its own
entry in the log. `make tex` now records `built_linear` per entry in art/textures.json, so the
ladder is greppable; this tool is for the things the manifest does not hold.
"""
import sys

import numpy as np
from PIL import Image

from livery import to_hsv  # the same vectorised rgb->hsv the livery recolour uses

# render.particles.Sprites.SIZE = CityConfig.CELL * 0.75 — an atlas cell's world size at scale 1
SPRITE_SIZE = 3.0


# sRGB -> linear, the IEC transfer. On a 0..255 float array.
def lin(v):
    v = v / 255.0
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)


# mean linear LUMINANCE, Rec.709 weights, per pixel then averaged. This is the exact statistic the
# whole render log is written in and it is not the flat channel mean: on the green-dominant
# wilderness set the two differ by 3-9%, enough to invert a judgement about which of two layers is
# lighter. Verified against the three values art/textures.json records as measured as built —
# earth 0.0348, turf 0.0476, dead grass 0.0560 — which this reproduces to 0.0001.
def luma(px):
    L = lin(px.reshape(-1, 3))
    return float((0.2126 * L[:, 0] + 0.7152 * L[:, 1] + 0.0722 * L[:, 2]).mean())


# invert three's ACESFilmic tone map by bisection: displayed value -> post-exposure scene value
def aces_inv(y):
    def f(x):
        return (x * (x + 0.0245786) - 0.000090537) / (x * (0.983729 * x + 0.4329510) + 0.238081)
    lo, hi = 0.0, 20.0
    for _ in range(80):
        mid = (lo + hi) / 2
        if f(mid) < y:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


# one row: the channel means, the chroma spread, and the linear luminance that ratios are taken in
def row(label, px, scene=False):
    m = px.reshape(-1, 3).mean(axis=0)
    L = luma(px)
    out = ('  %-30s srgb %6.1f  rgb %5.1f/%5.1f/%5.1f  chroma %5.1f  linear %.4f'
           % (label, m.mean(), m[0], m[1], m[2], m.max() - m.min(), L))
    if scene:
        out += '  scene %.4f' % aces_inv(L)
    print(out)


# saturated fraction and a 12-bin hue histogram — what separates rust from steel on a prop bake,
# where the two sit at nearly the same luma and differ only in hue
def hues(px):
    h, s, v = to_hsv(px / 255.0)
    m = s > 0.12
    print('  saturated %.1f%%   value p05/p50/p95 %.3f/%.3f/%.3f'
          % (100.0 * m.mean(), *np.percentile(v, [5, 50, 95])))
    if not m.any():
        return
    hh, edges = np.histogram(h[m], bins=12, range=(0, 360))
    for i, c in enumerate(hh):
        if c:
            print('    hue %3d-%3d  %5.1f%%' % (edges[i], edges[i + 1], 100.0 * c / m.sum()))


# one atlas cell: alpha bounding box, coverage and the world size the sprite quad will take.
# spec is row,col[,ox,oy,w,h] — the offsets crop to the artwork inside a padded cell
def atlas(im, spec, cell):
    p = [int(x) for x in spec.split(',')]
    r, c = p[0], p[1]
    if len(p) >= 6:
        ox, oy, w, h = p[2], p[3], p[4], p[5]
    else:
        ox, oy, w, h = 0, 0, cell, cell
    q = im[r * cell + oy:r * cell + oy + h, c * cell + ox:c * cell + ox + w]
    a = q[:, :, 3] if q.shape[2] == 4 else np.full(q.shape[:2], 255.0)
    ys, xs = np.where(a > 8)
    if not len(ys):
        print('  %d,%d  EMPTY' % (r, c))
        return
    bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    print('  %d,%d  bbox %dx%d  aspect %.2f  world %.2fx%.2f  opaque %.1f%%'
          % (r, c, bw, bh, bw / bh, SPRITE_SIZE * bw / cell, SPRITE_SIZE * bh / cell,
             100.0 * (a > 128).mean()))
    # measured over the OPAQUE texels only: the transparent margin would drag every mean down
    row('cell %d,%d' % (r, c), q[:, :, :3][a > 128])


# the built value of one file, over its opaque texels: (linear luminance, mean sRGB byte).
# imported by tools/textures.py, which stamps these into art/textures.json so the value ladder is
# a grep instead of a measuring run. Both tools must report the SAME statistic, hence one copy.
def measure(path):
    im = Image.open(path)
    rgba = np.asarray(im.convert('RGBA')).astype(np.float64)
    px = rgba[:, :, :3]
    if rgba[:, :, 3].min() < 255:
        px = px[rgba[:, :, 3] > 128]
    if not px.size:
        return 0.0, 0.0
    return luma(px), float(px.reshape(-1, 3).mean())


def main(args):
    if not args:
        sys.exit(__doc__)

    # flags that take a value, so their argument is never mistaken for an image path
    paths, boxes, cells, scene, hue, cell_px = [], [], [], False, False, 64
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--box':
            boxes.append(args[i + 1])
        elif a == '--atlas':
            cells.append(args[i + 1])
        elif a == '--cell':
            cell_px = int(args[i + 1])
        elif a == '--scene':
            scene = True
        elif a == '--hue':
            hue = True
        elif a.startswith('--'):
            sys.exit('unknown flag ' + a)
        else:
            paths.append(a)
            i += 1
            continue
        i += 2 if a in ('--box', '--atlas', '--cell') else 1

    for p in paths:
        im = Image.open(p)
        rgba = np.asarray(im.convert('RGBA')).astype(np.float64)
        a = rgba[:, :, :3]
        # an alpha-cut overlay (grass tufts, ground patches, decals) is measured over its OPAQUE
        # texels alone — the transparent margin is not a surface, and averaging it in as black is
        # what makes a sprite look darker than the ground it stands on when it is in fact lighter.
        # Every `lift` note in art/textures.json comparing layers says "over the opaque texels".
        op = rgba[:, :, 3] > 128 if rgba[:, :, 3].min() < 255 else None
        print('%s  %dx%d%s' % (p.split('/')[-1], im.size[0], im.size[1],
                               '  (opaque %.1f%%)' % (100.0 * op.mean()) if op is not None else ''))
        if cells:
            for spec in cells:
                atlas(rgba, spec, cell_px)
            continue
        if boxes:
            for spec in boxes:
                name, x0, y0, x1, y1 = spec.split(',')
                q = a[int(y0):int(y1), int(x0):int(x1)]
                m = op[int(y0):int(y1), int(x0):int(x1)] if op is not None else None
                row(name, q[m] if m is not None else q, scene)
        else:
            row('whole', a[op] if op is not None else a, scene)
        if hue:
            hues(a[op] if op is not None else a)


if __name__ == '__main__':
    main(sys.argv[1:])

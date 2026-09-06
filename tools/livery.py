#!/usr/bin/env python3
"""Recolour a baked glb base map into another livery, WITHOUT moving a single texel.

Why this exists rather than an `edit_image` pass: a TRELLIS base map is a fragmented UV ATLAS —
circular lid/base charts scattered through rectangular body panels — not a picture. An image model
regenerates the whole canvas (`docs/3d-textures.md` records it refusing to honour even a stated seam
position), and a chart that moves by a few texels is a smeared prop. This is a per-pixel HSV
transform, so the layout is preserved by construction.

WHAT IT ACTUALLY DOES, and why one operation covers both jobs: on `sewer/drum` the rust and the
steel have nearly the same LUMA (54/44/42 against 44/47/54) and differ only in HUE — 17% of the
saturated pixels sit at hue 0-30, 71% at 210-240. So assigning ONE hue to every saturated pixel
deletes the grime and applies the new colour at the same time, and the value channel it leaves alone
is what keeps the dents, weld seams and wear reading as wear.

Near-neutral texels (the dark lid rims and the baked contact shadows) are left alone: they carry no
hue to replace, and tinting them would paint the shadows.

usage: python3 tools/livery.py <in.png> <out.png> --hue 48 --sat 0.55 --gain 1.7
"""
import argparse
import numpy as np
from PIL import Image

# below this saturation a texel is a shadow or a rim, not paint — see the header
SAT_MIN = 0.12


# rgb -> hsv on a float array in 0..1, h in degrees. vectorised; colorsys is per-pixel and far too
# slow at 2048 squared
def to_hsv(im):
    mx = im.max(axis=2)
    mn = im.min(axis=2)
    d = mx - mn
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    h = np.zeros_like(mx)
    nz = d > 1e-6
    i = (mx == r) & nz
    h[i] = ((g[i] - b[i]) / d[i]) % 6
    i = (mx == g) & nz
    h[i] = (b[i] - r[i]) / d[i] + 2
    i = (mx == b) & nz
    h[i] = (r[i] - g[i]) / d[i] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return h * 60.0, s, mx


# and back
def to_rgb(h, s, v):
    hp = (h % 360.0) / 60.0
    c = v * s
    x = c * (1 - np.abs(hp % 2 - 1))
    m = v - c
    z = np.zeros_like(v)
    i = hp.astype(np.int32) % 6
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [c, x, z, z, x, c])
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [x, c, c, x, z, z])
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], axis=2)


# one livery: every painted texel takes `hue`, its saturation is rescaled toward `sat` (the original
# spread survives as a fraction of it, so a worn patch stays a worn patch), and the whole map is
# scaled by `gain`
def livery(im, hue, sat, gain):
    h, s, v = to_hsv(im)
    paint = s > SAT_MIN
    h = np.where(paint, hue, h)
    # keep HALF the original variation around the target rather than flattening to it
    s = np.where(paint, np.clip(sat * (0.5 + 0.5 * s / max(s[paint].mean(), 1e-6)), 0, 1), s)
    v = np.clip(v * gain, 0, 1)
    return to_rgb(h, s, v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--hue', type=float, required=True, help='livery hue, degrees')
    ap.add_argument('--sat', type=float, required=True, help='target saturation 0..1')
    ap.add_argument('--gain', type=float, default=1.0, help='value multiplier')
    a = ap.parse_args()

    src = Image.open(a.src).convert('RGB')
    im = np.asarray(src).astype(np.float32) / 255.0
    out = livery(im, a.hue, a.sat, a.gain)
    Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8)).save(a.dst)

    m = out.reshape(-1, 3).mean(axis=0) * 255
    luma = 0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2]
    print('%s  mean %.1f/%.1f/%.1f  chroma %.1f  luma %.1f'
          % (a.dst, m[0], m[1], m[2], m.max() - m.min(), luma))


if __name__ == '__main__':
    main()

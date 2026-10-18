#!/usr/bin/env python3
"""Build textures-src/military/razor-coil.png, the razor-wire coil's tube texture, from a generated
strand drop.

The drop (textures-src/unused/military/razor-coil-raw.png) is four straight 45-degree strands with
barbs on a dark painted ground. Its strand spacing and barb phase drift, so no crop of it wraps.
This script cuts ONE strand out of it and lays it back down as a HELIX:
  - u (x) is one turn round the tube, v (y) runs along its axis;
  - HELICES interleaved strands, each climbing PITCH * HELICES per turn, so a loop crosses the
    axis every PITCH world units;
  - BARBS whole barb periods per turn, so the tile wraps on both axes by construction.
The image is sized so a texel covers the same world distance on both axes (the turn is CIRC long,
the tile LV tall). Alpha comes from the drop's luminance: ground and glow sit under LUMA_LO, wire
over LUMA_HI.

render.military.MilitaryGeom.coil maps u 0..1 round the tube and v at LV world units.
"""
import math
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "textures-src", "unused", "military", "razor-coil-raw.png")
OUT = os.path.join(ROOT, "textures-src", "military", "razor-coil.png")

DIAMETER = 1.12  # MilitaryGeom.WIRE_D
CIRC = math.pi * DIAMETER
PITCH = 0.35  # world units between loops along the axis
HELICES = 4
LV = PITCH * HELICES  # MilitaryGeom.COIL_LV
BARBS = 12
W = 1024
H = round(W * LV / CIRC)

LUMA_LO = 72
LUMA_HI = 86
ANGLE = 45  # the drop's strands, measured by projection variance
STRAND_ROW = 613  # a strand's centre row in the drop rotated flat (spacing 261)
SRC_PERIOD = 156  # its barb period along the strand, by autocorrelation
SRC_X0 = 600  # where along it the cut starts, clear of both ends
HALF = 30  # px either side of the strand centre the wire and barbs reach (measured 26)


# the drop rotated so its strands run along x, wire in alpha
def flat_strand():
    rgb = np.asarray(Image.open(RAW).convert("RGB")).astype(float)
    luma = rgb @ [0.299, 0.587, 0.114]
    t = np.clip((luma - LUMA_LO) / (LUMA_HI - LUMA_LO), 0, 1)
    a = t * t * (3 - 2 * t) * 255
    im = Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), "RGBA")
    return np.asarray(im.rotate(-ANGLE, resample=Image.BICUBIC, expand=True)).astype(float)


# bilinear sample of `src` at float pixel coords
def sample(src, x, y):
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    h, w = src.shape[:2]
    x0 = np.clip(x0, 0, w - 2)
    y0 = np.clip(y0, 0, h - 2)
    a = src[y0, x0] * (1 - fx) + src[y0, x0 + 1] * fx
    b = src[y0 + 1, x0] * (1 - fx) + src[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def main():
    src = flat_strand()
    # world position of every texel: wx round the turn, wy along the axis
    xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    wx = xs / W * CIRC
    wy = ys / H * LV
    # each helix climbs PITCH * HELICES per turn; the nearest one is a PITCH-periodic offset
    climb = LV / CIRC
    off = (wy - wx * climb) % PITCH
    off = np.where(off > PITCH / 2, off - PITCH, off)
    slope = math.atan(climb)
    perp = off * math.cos(slope)
    along = wx / math.cos(slope)
    turn = CIRC / math.cos(slope)
    # drop px per world unit along the strand, so BARBS periods fill one turn exactly
    k = SRC_PERIOD * BARBS / turn
    sx = SRC_X0 + (along * k) % SRC_PERIOD
    sy = STRAND_ROW + perp * k
    out = sample(src, sx, sy)
    out[np.abs(perp * k) > HALF, 3] = 0
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").save(OUT)
    print(f"wrote {OUT} {W}x{H}, {k:.0f} drop px per world unit, opaque "
          f"{(out[:, :, 3] > 127).mean():.3f}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Close the wrap on a generated tiling texture whose seam is STRUCTURAL, not tonal.

A generated "seamless" swatch of a coursed surface usually fails at the wrap in one of two ways
that a blend cannot fix, because a blend ghosts the joints:

  planks  an offset-bond plank floor whose courses do not divide the height (8 courses drawn at
          126 px leave a 145 px course across the vertical wrap) and whose wrap column cuts through
          two DIFFERENT planks, so every course shows a tone step there. Rebuilt course by course:
          the courses are re-stacked whole (the wrap course dropped, a mirrored copy of a real one
          put in its place, the stack resampled by the ~2% it misses the size by), and in each
          course the wrap cut is turned into a butt joint (the course's own joint copied onto it)
          and the course is rolled so its joints stagger against its neighbours'.
  grout   a stack-bond tile band whose grout lines sit at the right pitch but with none drawn AT
          the wrap, so two tiles merge into one double-width tile. The nearest grout line is
          copied onto the edge columns. Also the slat wall (corp/wall-meeting): same fault, a
          batten groove missing at the wrap.

  grid    a stack-bond floor of square tiles (military/floor-mess's quarry tiles) whose quadrant drew
          the grout lines inside it at an even pitch but none at its edges, so the crop's first and
          last tiles merged into one double-width tile across every wrap. Each axis is resampled
          piecewise so the inner lines land on exact quarters of the output, the virtual line one
          pitch out from each end on its edges, and the middle line is copied onto the wrap.

And one seam that IS tonal, where a blend is the right tool because there is nothing to ghost:

  tone    a plain field (cut-pile carpet) whose wrap shows a low-frequency tone step. The image is
          rolled half a period on both axes, so the rolled copy's edges are the original's
          interior, and the two are cross-faded: the original in the middle, the rolled copy at
          the edges, a linear ramp over FEATHER of the size between. Joints or grain would double
          in the ramp; a pile field does not.

Usage: python3 tools/seamfix.py planks|grout|tone|boards|grid <src.png> <out.png> [x,y,w,h]
"""
import sys
import numpy as np
from PIL import Image


def dark_runs(profile, thresh):
  """centres of the runs of entries darker than `thresh`"""
  out, start = [], None
  for i, v in enumerate(list(profile) + [thresh + 1]):
    if v < thresh and start is None:
      start = i
    elif v >= thresh and start is not None:
      out.append((start, i))
      start = None
  return out


def planks(a):
  g = a.astype(float).mean(2)
  h, w = g.shape
  rp = g.mean(1)
  rows = dark_runs(rp, np.median(rp) - 12)
  # a course is a joint line plus the board under it; the last one runs into the wrap
  starts = [r[0] for r in rows]
  courses = [a[starts[i]:starts[i + 1]] for i in range(len(starts) - 1)]
  courses.append(courses[len(courses) // 2][:, ::-1])
  fixed = []
  prev = []
  first = None
  for k, c in enumerate(courses):
    cg = c.astype(float).mean(2)
    inner = cg[6:-3].mean(0)
    runs = dark_runs(inner, np.median(inner) - 12)
    out = c.copy()
    joints = [(s + e) // 2 for s, e in runs]
    # the wrap cut becomes a butt joint: the course's own joint strip copied onto column 0
    if runs:
      s, e = runs[0]
      strip = c[3:, s - 1:e + 1]
      half = strip.shape[1] // 2
      for i in range(strip.shape[1]):
        out[3:, (i - half) % w] = strip[:, i]
    joints.append(0)
    # then the course is rolled, so the new joints stagger against the course above (and, for the
    # last course, the first one across the vertical wrap)
    against = prev + (first if first is not None and k == len(courses) - 1 else [])
    def gap(r):
      return min([min(abs((j + r) % w - q), w - abs((j + r) % w - q)) for j in joints for q in against] or [w])
    r = max(range(0, w, 8), key=gap)
    out = np.roll(out, r, 1)
    prev = [(j + r) % w for j in joints]
    if first is None:
      first = prev
    fixed.append(out)
  stack = np.concatenate(fixed, 0)
  return np.asarray(Image.fromarray(stack).resize((w, h), Image.LANCZOS))


def grout(a):
  g = a.astype(float).mean(2)
  h, w = g.shape
  # the tile band is where the column profile has its grout dips
  lo, hi = int(h * 0.45), int(h * 0.95)
  cp = g[lo:hi].mean(0)
  # a run touching either edge is the half-drawn line AT the wrap, i.e. the fault itself
  runs = [r for r in dark_runs(cp, cp.mean() - 8) if r[0] > 0 and r[1] < w]
  s, e = runs[0]
  src = a[:, s:e]
  # the rows the line spans, against the MEDIAN column: column 0 is the fault and can be the
  # darkest column in the image (wall-meeting's is)
  band = g[:, (s + e) // 2] < np.median(g, 1) - 6
  ys = np.where(band)[0]
  y0, y1 = ys.min(), ys.max() + 1
  out = a.copy()
  half = (e - s) // 2
  for i in range(e - s):
    x = (i - half) % w
    out[y0:y1, x] = src[y0:y1, i]
  return out


def boards(a):
  g = a.astype(float).mean(2)
  h, w = g.shape
  # the gaps between the boards; the last one, touching the right edge, is the first one again
  cp = g.mean(0)
  runs = dark_runs(cp, np.median(cp) - 12)
  cuts = [s for s, e in runs if s < w - 4]
  bands = [a[:, cuts[i]:(cuts[i + 1] if i + 1 < len(cuts) else runs[-1][0])] for i in range(len(cuts))]
  # each board's wrap cut becomes a butt joint, the gap line laid on its side, and the board is
  # rolled down by its own share of the height so the ends stagger and the image wraps through
  # the uncut middle of every board
  s, e = runs[1]
  joint = a[:, s - 1:e + 1].transpose(1, 0, 2)
  out = []
  for k, b in enumerate(bands):
    b = b.copy()
    jw = b.shape[1]
    half = joint.shape[0] // 2
    for i in range(joint.shape[0]):
      b[(i - half) % h] = joint[i, k * jw:(k + 1) * jw] if (k + 1) * jw <= h else joint[i, :jw]
    out.append(np.roll(b, int(h * ((k * 0.618) % 1)), 0))
  stack = np.concatenate(out, 1)
  n = min(stack.shape[0], stack.shape[1])
  return np.asarray(Image.fromarray(stack[:n, :n]).resize((w, w), Image.LANCZOS))


GRID_OUT = 512


def grid(a):
  g = a.astype(float).mean(2)
  h = w = GRID_OUT
  out = a

  def axis(profile, n):
    # the inner grout lines, then one pitch out past each end
    runs = [r for r in dark_runs(profile, np.median(profile) - 12) if r[0] > 2 and r[1] < n - 2]
    c = [(s + e - 1) / 2 for s, e in runs]
    p = (c[-1] - c[0]) / (len(c) - 1)
    k = len(c) + 1
    anchors = [c[0] - p] + c + [c[-1] + p]
    # output position of each anchor: the k tiles evenly over GRID_OUT, line 0 on the wrap
    dst = [GRID_OUT * i / k for i in range(k + 1)]
    src = np.interp(np.arange(GRID_OUT) + 0.5, dst, anchors) - 0.5
    return np.clip(src, 0, n - 1), int(round(GRID_OUT * (k // 2) / k)), max(e - s for s, e in runs)

  sx, mx, wx = axis(g.mean(0), g.shape[1])
  sy, my, wy = axis(g.mean(1), g.shape[0])
  # bilinear resample on both axes
  def resample(img, idx, ax):
    i0 = np.floor(idx).astype(int)
    i1 = np.minimum(i0 + 1, img.shape[ax] - 1)
    f = (idx - i0).reshape([-1 if d == ax else 1 for d in range(img.ndim)])
    return np.take(img, i0, ax) * (1 - f) + np.take(img, i1, ax) * f
  o = resample(resample(out.astype(float), sx, 1), sy, 0)
  # the middle line, with its bevels, copied onto the wrap: columns first, then rows over them
  hx = wx // 2 + 3
  for i in range(-hx, hx + 1):
    o[:, i % w] = o[:, mx + i]
  hy = wy // 2 + 3
  for i in range(-hy, hy + 1):
    o[i % h, :] = o[my + i, :]
  return np.clip(o + 0.5, 0, 255).astype(np.uint8)


FEATHER = 0.25


def tone(a):
  h, w = a.shape[:2]
  b = np.roll(a, (h // 2, w // 2), (0, 1)).astype(float)
  ramp = lambda n: np.clip(np.minimum(np.arange(n) + 0.5, n - np.arange(n) - 0.5) / (n * FEATHER), 0, 1)
  m = (ramp(h)[:, None] * ramp(w)[None, :])[:, :, None]
  return np.clip(a * m + b * (1 - m) + 0.5, 0, 255).astype(np.uint8)


if __name__ == '__main__':
  mode, src, dst = sys.argv[1:4]
  a = np.asarray(Image.open(src).convert('RGB'))
  # an optional x,y,w,h: one cell of a packed sheet
  if len(sys.argv) > 4:
    x, y, cw, ch = [int(v) for v in sys.argv[4].split(',')]
    a = a[y:y + ch, x:x + cw]
  out = {'planks': planks, 'grout': grout, 'tone': tone, 'boards': boards, 'grid': grid}[mode](a)
  Image.fromarray(out).save(dst)
  o = out.astype(float)
  print('%s wrapH %.1f wrapV %.1f' % (dst, np.abs(o[:, 0] - o[:, -1]).mean(), np.abs(o[0] - o[-1]).mean()))

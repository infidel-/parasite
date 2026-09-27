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
          copied onto the edge columns.

Usage: python3 tools/seamfix.py planks|grout <src.png> <out.png>
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
  runs = dark_runs(cp, cp.mean() - 8)
  s, e = runs[0]
  src = a[:, s:e]
  band = g[:, (s + e) // 2] < g[:, 0] - 6
  ys = np.where(band)[0]
  y0, y1 = ys.min(), ys.max() + 1
  out = a.copy()
  half = (e - s) // 2
  for i in range(e - s):
    x = (i - half) % w
    out[y0:y1, x] = src[y0:y1, i]
  return out


if __name__ == '__main__':
  mode, src, dst = sys.argv[1:4]
  a = np.asarray(Image.open(src).convert('RGB'))
  out = planks(a) if mode == 'planks' else grout(a)
  Image.fromarray(out).save(dst)
  o = out.astype(float)
  print('%s wrapH %.1f wrapV %.1f' % (dst, np.abs(o[:, 0] - o[:, -1]).mean(), np.abs(o[0] - o[-1]).mean()))

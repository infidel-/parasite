"""Build app/img/entities128.png, the 3D view's 128 px redraw of the entities64 cells in Const.HD128,
from the ORIGINAL art under the asset store (the Krita files and pngs the 64 px cells were made from)
instead of the gpt upscale it first shipped as. The blood family and the money are GENERATED in the
game's own style instead (asked for: "closer to our game style" than the old flat art): four sheets of
six splats, textures-src/img/entities128/blood-<colour>.png, five of each used, and money-bill.png and
money-scatter.png. The first cut, off the old flat splats and the dollar.kra vectors, is parked in v1/.

Each source is fitted ASPECT-LOCKED onto its old 64 px cell's content box at 2x, bottom-aligned for the
upright sprites, so every anchor, content rect and shadow root lands where the 64 px cell put it. An
original then has its saturation and mean linear luminance matched to the old cell's (it lands within
0.92-1.00: it IS that cell's source, bar the darkened barrel); a generated cell keeps its painted colours.

usage: python3 tools/entities128.py [out.png]      (default app/img/entities128.png)
"""
import io
import itertools
import os
import re
import sys
import zipfile

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.realpath(os.path.join(ROOT, 'textures-src', '..'))
GEN = os.path.join(ROOT, 'textures-src', 'img', 'entities128', '%s.png')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'app', 'img', 'entities128.png')
CELL = 128
COLS = 8
# Const.HD128, in its order
CELLS = [(4, 0), (4, 1), (2, 4), (2, 7), (4, 6), (4, 7), (16, 2), (3, 2), (3, 3), (3, 6), (3, 7), (3, 8),
         (1, 10), (1, 11)] + [(40, c) for c in range(10)] + [(21, c) for c in range(3, 8)] + \
        [(22, c) for c in range(3, 8)]
# the first seven stand on their foot: bottom-aligned in their box
UPRIGHT = 7
# the generated cells, which keep their own colours: the money and every splat
GENERATED = {7, 8} | set(range(14, 34))


def lzf(src, n):
    # Krita's tile compression
    out = bytearray()
    i = 0
    while i < len(src):
        c = src[i]
        i += 1
        if c < 32:
            out += src[i:i + c + 1]
            i += c + 1
            continue
        ln = c >> 5
        if ln == 7:
            ln += src[i]
            i += 1
        ref = len(out) - ((c & 31) << 8) - src[i] - 1
        i += 1
        for _ in range(ln + 2):
            out.append(out[ref])
            ref += 1
    return bytes(out[:n])


def kra(path, layer=None):
    # a Krita file's flattened image, or one paint layer of it on the canvas (planar BGRA 64 px tiles)
    z = zipfile.ZipFile(os.path.join(ASSETS, path))
    if layer is None:
        return Image.open(io.BytesIO(z.read('mergedimage.png'))).convert('RGBA')
    doc = z.read('maindoc.xml').decode()
    w = int(re.search(r'<IMAGE [^>]*\swidth="(\d+)"', doc).group(1))
    h = int(re.search(r'<IMAGE [^>]*\sheight="(\d+)"', doc).group(1))
    root = re.search(r'<IMAGE [^>]*\sname="([^"]*)"', doc).group(1)
    for m in re.finditer(r'<layer ([^>]*)/?>', doc):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        if a.get('name') != layer:
            continue
        data = z.read(root + '/layers/' + a['filename'])
        head, _, rest = data.partition(b'DATA ')
        meta = dict(l.split(b' ', 1) for l in head.split(b'\n') if b' ' in l)
        tw, th = int(meta[b'TILEWIDTH']), int(meta[b'TILEHEIGHT'])
        count, _, rest = rest.partition(b'\n')
        img = Image.new('RGBA', (w, h))
        ox, oy = int(a.get('x', 0)), int(a.get('y', 0))
        pos = 0
        for _ in range(int(count)):
            nl = rest.index(b'\n', pos)
            x, y, _, size = rest[pos:nl].split(b',')
            blob = rest[nl + 1:nl + 1 + int(size)]
            pos = nl + 1 + int(size)
            n = tw * th * 4
            raw = lzf(blob[1:], n) if blob[0] == 1 else blob[1:1 + n]
            pl = [Image.frombytes('L', (tw, th), raw[k * tw * th:(k + 1) * tw * th]) for k in range(4)]
            tile = Image.merge('RGBA', (pl[2], pl[1], pl[0], pl[3]))
            img.paste(tile, (int(x) + ox, int(y) + oy), tile)
        return img
    raise KeyError(path + ': no layer ' + layer)


def trim(im):
    # crop to the content, a lone pixel left on the canvas not counted (item.kra has one at its corner)
    m = np.asarray(im)[..., 3] > 8
    p = np.pad(m, 1)
    near = sum(p[1 + dy:p.shape[0] - 1 + dy, 1 + dx:p.shape[1] - 1 + dx]
               for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    ys, xs = np.nonzero(m & (near > 0))
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def inside(im):
    # drop a neighbour's droplet that crossed the grid line: a small part touching the crop's edge.
    # the faint haze gpt leaves round the art touches the edge too, and joins everything it reaches,
    # so the parts are told apart on SOLID alpha. labelled at quarter size, which is plenty to tell a
    # droplet from a splat, and grown a step back so the soft edge survives
    q = 4
    small = np.asarray(im.getchannel('A').resize((im.width // q, im.height // q), Image.BOX)) > 128
    lab, n = label(small)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    size = np.bincount(lab.ravel(), minlength=n + 1)
    # a splat whose own body reaches the line (black's wide puddle does) is no sliver: only a part
    # small beside the biggest is dropped
    keep = np.isin(lab, [k for k in range(1, n + 1) if k not in edge or size[k] > 0.25 * size[1:].max()])
    p = np.pad(keep, 1)
    keep = sum(p[1 + dy:p.shape[0] - 1 + dy, 1 + dx:p.shape[1] - 1 + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) > 0
    keep = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).resize(im.size, Image.NEAREST)) > 0
    a = np.asarray(im).copy()
    a[..., 3] = np.where(keep, a[..., 3], 0)
    return Image.fromarray(a)


def shrink(im, w, h):
    # premultiplied, so the colour under transparent texels cannot bleed into the edge
    return im.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')


def split(im, n):
    # n subjects side by side: cut at the n - 1 widest empty column runs
    cols = (np.asarray(im)[..., 3] > 8).any(0)
    runs = []
    x = 0
    while x < len(cols):
        if not cols[x]:
            s = x
            while x < len(cols) and not cols[x]:
                x += 1
            if s > 0 and x < len(cols):
                runs.append((x - s, s, x))
        x += 1
    cuts = sorted((s + e) // 2 for _, s, e in sorted(runs, reverse=True)[:n - 1])
    edges = [0] + cuts + [im.width]
    return [trim(im.crop((edges[k], 0, edges[k + 1], im.height))) for k in range(n)]


def box(old):
    # an old cell's content box at 2x, and its alpha ceiling
    ys, xs = np.nonzero(old[..., 3] > 8)
    return (xs.min() * 2, ys.min() * 2, xs.max() * 2 + 2, ys.max() * 2 + 2), old[..., 3].max()


def fill(sub, b):
    # how much of the box an aspect-locked fit covers
    tw, th = b[2] - b[0], b[3] - b[1]
    k = min(tw / sub.width, th / sub.height)
    return k * sub.width * k * sub.height / (tw * th)


def place(sub, b, upright, amax, crop_top=False):
    tx0, ty0, tx1, ty1 = b
    tw, th = tx1 - tx0, ty1 - ty0
    # a source taller than its box is cut from the top: the barrel's flames, which the 64 px cell
    # stopped at the rim (the game draws its own)
    if crop_top and sub.width / sub.height < tw / th:
        sub = sub.crop((0, sub.height - round(sub.width * th / tw), sub.width, sub.height))
    k = min(tw / sub.width, th / sub.height)
    nw, nh = max(1, round(sub.width * k)), max(1, round(sub.height * k))
    sub = shrink(sub, nw, nh)
    if amax < 255:
        a = np.asarray(sub).copy()
        a[..., 3] = (a[..., 3].astype(float) * amax / 255).astype(np.uint8)
        sub = Image.fromarray(a)
    cell = Image.new('RGBA', (CELL, CELL))
    cell.alpha_composite(sub, (tx0 + (tw - nw) // 2, (ty1 - nh) if upright else ty0 + (th - nh) // 2))
    return cell, nw / tw, nh / th


def label(m):
    # 8-connected blobs of a small mask, by flood fill
    lab = np.zeros(m.shape, int)
    n = 0
    for y0, x0 in zip(*np.nonzero(m)):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        stack = [(y0, x0)]
        while stack:
            y, x = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    v, u = y + dy, x + dx
                    if 0 <= v < m.shape[0] and 0 <= u < m.shape[1] and m[v, u] and not lab[v, u]:
                        lab[v, u] = n
                        stack.append((v, u))
    return lab, n


def lin(px):
    rgb = px[..., :3] / 255
    l = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return l, l @ [0.2126, 0.7152, 0.0722]


def mask(cell):
    m = cell[..., 3] > 128
    return m if m.any() else cell[..., 3] > 60


def sat(cell, l=None):
    # mean HSV saturation over the opaque pixels, in sRGB as an eye reads it
    m = mask(cell)
    rgb = cell[..., :3][m] / 255 if l is None else np.where(np.clip(l[m], 0, 1) <= 0.0031308,
        np.clip(l[m], 0, 1) * 12.92, 1.055 * np.clip(l[m], 0, 1) ** (1 / 2.4) - 0.055)
    mx = rgb.max(1)
    return np.where(mx > 0.02, (mx - rgb.min(1)) / np.maximum(mx, 1e-6), 0).mean()


def match(n, o):
    # the old cell's saturation (a blend toward each pixel's luminance in LINEAR light, so luminance
    # holds), then its mean linear luminance (a gain, so hue holds)
    ln, yn = lin(n)
    target = sat(o)
    f = 1.0
    if sat(n) > target:
        lo, hi = 0.0, 1.0
        for _ in range(30):
            mid = (lo + hi) / 2
            if sat(n, yn[..., None] + mid * (ln - yn[..., None])) > target:
                hi = mid
            else:
                lo = mid
        f = (lo + hi) / 2
    gain = lin(o)[1][mask(o)].mean() / lin(n)[1][mask(n)].mean()
    l = np.clip((yn[..., None] + f * (ln - yn[..., None])) * gain, 0, 1)
    n[..., :3] = np.where(l <= 0.0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - 0.055) * 255
    return gain, f


atlas = np.asarray(Image.open(os.path.join(ROOT, 'app', 'img', 'entities64.png')).convert('RGBA'))
olds = [atlas[r * 64:r * 64 + 64, c * 64:c * 64 + 64] for r, c in CELLS]
spits = split(kra('Effects/spit.kra'), 3)
# every cell's source, in CELLS order
src = [
    kra('parasite-icon3.kra'),
    kra('AI/dog.kra'),
    kra('Objects/item.kra'),
    kra('Objects/nutrient.kra'),
    kra('Sewers/choir.kra', 'choir 3'),
    kra('Sewers/choir.kra', 'choir dead'),
    kra('Street/burning barrel.kra', 'Background'),
    Image.open(GEN % 'money-bill').convert('RGBA'),
    Image.open(GEN % 'money-scatter').convert('RGBA'),
    spits[0],
    spits[1],
    spits[2],
    kra('UI Elements/targeting-reticle.kra'),
    kra('UI Elements/targeting-frame.kra'),
]
# the splats: each sheet a 3 x 2 of six, five of them dealt to the old five shapes by best fit
for colour in ('red', 'black', 'acid', 'slime'):
    sheet = Image.open(GEN % ('blood-' + colour)).convert('RGBA')
    w, h = sheet.width // 3, sheet.height // 2
    six = [trim(inside(sheet.crop((x * w, y * h, x * w + w, y * h + h)))) for y in range(2) for x in range(3)]
    boxes = [box(olds[len(src) + k])[0] for k in range(5)]
    best = max(itertools.permutations(range(6), 5), key=lambda p: sum(fill(six[p[k]], boxes[k]) for k in range(5)))
    print('%-5s splats %s' % (colour, best))
    src += [six[k] for k in best]

out = Image.new('RGBA', (COLS * CELL, COLS * CELL))
for i, (r, c) in enumerate(CELLS):
    b, amax = box(olds[i])
    cell, fx, fy = place(trim(src[i]), b, i < UPRIGHT, amax, crop_top=(i == 6))
    note = 'fit %3.0f%% x %3.0f%%' % (100 * fx, 100 * fy)
    if i not in GENERATED:
        n = np.asarray(cell).astype(float).copy()
        gain, f = match(n, olds[i].astype(float))
        cell = Image.fromarray(n.round().astype(np.uint8))
        note += '  gain %.2f  sat f %.2f' % (gain, f)
    out.alpha_composite(cell, ((i % COLS) * CELL, (i // COLS) * CELL))
    print('%2d %2d/%-2d %s' % (i, r, c, note))
# through a temp file: overwriting in place fails with EINVAL while the game on the Windows host holds
# the sheet open
out.save(OUT + '.tmp.png')
os.replace(OUT + '.tmp.png', OUT)
print('wrote', OUT)

#!/usr/bin/env python3
"""Prop acceptance gate: measure a TRELLIS reference or the glb it produced.

Every rule in AGENTS.md's "3D models" section is written in these numbers, and each one
was learned by shipping a prop that was wrong in a way nothing already measured could see.
So this reports all of them at once, before a prop is wired in.

  python3 tools/propstat.py models-src/wild/bush-bramble.glb      mesh + bake
  python3 tools/propstat.py models-src/wild/bush-bramble-src.png  the reference
  python3 tools/propstat.py ref.png --lift 70 -o lifted.png       correct a reference

What a .glb reports and why each number is there:

  split ratio = verts / UNIQUE POSITIONS. meshopt cannot collapse an edge across an
    attribute discontinuity, so this predicts where an offline decimate lands, not how
    dense the mesh is. Below ~1.5x the 100k-master route works; at ~2x it does not and
    the prop has to be generated AT the game budget with "tris": -1.
  CONNECTED COMPONENTS over unique positions, and the largest one's share. Split ratio
    describes the ATLAS; this describes the SURFACE. A prop can pass every other number
    here while being a cloud of disconnected blobs -- the bush that failed this was 96
    components with the largest holding 24.3%, at the same bbox and unique-position count
    as its replacement. Read it as FEW components each holding a substantial share, not as
    a raw count: 2 at 51/49 is a canopy plus a trunk, 17 at 93.9% is 16 specks.
  bbox widest/height, because render.Models.instanced scales a prop by HEIGHT ALONE, so a
    WildStyle/SewerStyle `h` silently sets the world width through this ratio.
  albedo mean sRGB against the prop family's 46-52, whole-atlas and sampled at triangle UV
    CENTROIDS (a vertex UV sits on a chart corner, which is the gutter). The two disagreeing
    means the atlas is mostly padding.
  the MR map: glTF packs G = roughness, B = metalness. Pure green is a rough dielectric and
    is fine; cyan is metalness ~1 across the whole prop, which underground with no env map
    renders BLACK rather than chrome, and needs dropMR. Re-read it after every regeneration
    -- two props from the same generator on the same day came back opposite.

What a .png reports: subject value against the p50 69-77 the references that bake correctly
sit at, the frame margin (a subject touching the edge comes back a blob), and the bbox
aspect, which is the w/h the mesh will land near.
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

# glTF component type -> numpy dtype, and element type -> component count
CT = {5120: 'i1', 5121: 'u1', 5122: 'i2', 5123: 'u2', 5125: 'u4', 5126: 'f4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
# the flat grey both pipelines generate on, and the tolerance that separates subject from it
BG = np.array([0x5a, 0x5d, 0x63], np.float64)
BG_TOL = 60.0


# split a .glb into its JSON and BIN chunks
def load(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'glTF':
        sys.exit(path + ': not a glb')
    off, js, bin_ = 12, None, None
    while off < len(data):
        clen, ctype = struct.unpack_from('<II', data, off)
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            bin_ = chunk
        off += 8 + clen + (-clen % 4)
    return js, bin_


# read one accessor as an (count, components) array, honouring an interleaved byteStride
def acc(g, bin_, i):
    a = g['accessors'][i]
    bv = g['bufferViews'][a['bufferView']]
    n = NC[a['type']]
    dt = np.dtype('<' + CT[a['componentType']])
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride') or n * dt.itemsize
    if stride == n * dt.itemsize:
        return np.frombuffer(bin_, dt, a['count'] * n, start).reshape(a['count'], n)
    raw = np.frombuffer(bin_, 'u1', a['count'] * stride, start).reshape(a['count'], stride)
    return raw[:, :n * dt.itemsize].copy().view(dt)


# decode a glb-embedded texture
def image(g, bin_, ti):
    src = g['images'][g['textures'][ti]['source']]
    bv = g['bufferViews'][src['bufferView']]
    s = bv.get('byteOffset', 0)
    return Image.open(io.BytesIO(bin_[s:s + bv['byteLength']]))


# component sizes, largest first, from union-find over triangle edges keyed on unique position
# -- keyed on POSITION so a seam in the atlas does not read as a break in the surface
def components(uidx, tri):
    parent = np.arange(uidx.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b, c in uidx[tri]:
        for u, v in ((a, b), (b, c), (c, a)):
            ru, rv = find(u), find(v)
            if ru != rv:
                parent[rv] = ru
    roots = np.array([find(x) for x in range(len(parent))])
    _, counts = np.unique(roots, return_counts=True)
    return np.sort(counts)[::-1]


# subject mask + luminance for a reference painted on the flat grey
def subject(im):
    d = np.abs(im - BG).sum(axis=2)
    m = d > BG_TOL
    lum = 0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2]
    return m, lum


def stat_glb(path):
    g, bin_ = load(path)
    prim = g['meshes'][0]['primitives'][0]
    pos = acc(g, bin_, prim['attributes']['POSITION']).astype(np.float64)
    tri = acc(g, bin_, prim['indices']).reshape(-1, 3).astype(np.int64)
    uniq, uidx = np.unique(np.round(pos, 6), axis=0, return_inverse=True)
    split = len(pos) / len(uniq)
    print('  meshes         %d%s' % (len(g['meshes']),
          '   !! Models.instanced keeps only the FIRST' if len(g['meshes']) > 1 else ''))
    print('  tris           %d' % len(tri))
    print('  verts / uniq   %d / %d   split %.2fx   -> %s' % (
        len(pos), len(uniq), split,
        'offline decimate works' if split < 1.5 else
        'borderline, sweep `error`' if split < 2.0 else
        'UNDECIMATABLE, generate AT the budget with tris -1'))
    cc = components(uidx, tri)
    share = 100.0 * cc[0] / cc.sum()
    print('  COMPONENTS     %d   largest %.1f%%   top5 %s   -> %s' % (
        len(cc), share, ' '.join(str(x) for x in cc[:5]),
        'ok' if share >= 90 else 'REJECT: largest under 90%, the surface is a blob cloud'))
    lo, hi = pos.min(axis=0), pos.max(axis=0)
    size = hi - lo
    print('  bbox           %.3f x %.3f x %.3f   widest/height %.2f  (world width = h * this)' % (
        size[0], size[1], size[2], max(size[0], size[2]) / size[1]))
    pbr = g['materials'][prim.get('material', 0)].get('pbrMetallicRoughness', {})
    if 'baseColorTexture' in pbr:
        im = np.asarray(image(g, bin_, pbr['baseColorTexture']['index']).convert('RGB'))
        uv = acc(g, bin_, prim['attributes']['TEXCOORD_0']).astype(np.float64)
        c = uv[tri].mean(axis=1)
        px = np.clip((c * [im.shape[1], im.shape[0]]).astype(int), 0,
                     [im.shape[1] - 1, im.shape[0] - 1])
        s = im[px[:, 1], px[:, 0]].mean(axis=0)
        print('  albedo %-6s  atlas %d/%d/%d   sampled %d/%d/%d   (family 46-52)' % (
            '%dpx' % im.shape[0], *im.reshape(-1, 3).mean(axis=0).round(), *s.round()))
        # texels per triangle, and the `tex` that holds it near what the source was authored at.
        # this is only meaningful against the BAKED tex -- on a models-src source it is just the
        # 2048 export over a small tri count, which is why the recommendation is what gets printed
        edge = min((e for e in (256, 512, 1024, 2048)
                    if e * e / len(tri) >= 45), default=2048)
        print('  texels/tri     %d at %dpx  ->  tex %d gives %d  (hold near the ~43-55 band)' % (
            im.shape[0] * im.shape[1] / len(tri), im.shape[0], edge, edge * edge / len(tri)))
        # baseColor multiplies DOWN, lift gammas UP -- name whichever one this bake needs. a
        # STARTING POINT only: it solves for a flat 49, where a fit by hand usually keeps some of
        # the prop's own lean (bush-low is deliberately left at 44/50/44, greener than neutral)
        want = 49.0
        if abs(s.mean() - want) > 6:
            if s.mean() > want:
                f = [round(((want / 255) ** 2.2) / max((v / 255) ** 2.2, 1e-6), 2) for v in s]
                print('  -> baseColor   [%s, %s, %s, 1]  (LINEAR, per-channel, darkens; start here)'
                      % tuple(f))
            else:
                print('  -> lift        %.2f  (gamma on the MAP; baseColor cannot brighten)'
                      % (np.log(want / 255) / np.log(max(s.mean(), 1) / 255)))
    if 'metallicRoughnessTexture' in pbr:
        f = np.asarray(image(g, bin_, pbr['metallicRoughnessTexture']['index'])
                       .convert('RGB')).reshape(-1, 3)
        print('  MR map         mean %d/%d/%d  (G=rough B=metal)  metal max %d  -> %s' % (
            *f.mean(axis=0).round(), f[:, 2].max(),
            'dropMR NEEDED (renders BLACK, not chrome)' if f[:, 2].mean() > 40
            else 'rough dielectric, no dropMR'))
    print('  factors        metallic %s  roughness %s' % (
        pbr.get('metallicFactor', 1), pbr.get('roughnessFactor', 1)))


def stat_png(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    m, lum = subject(im)
    px = im[m]
    p05, p50 = np.percentile(lum[m], 5), np.percentile(lum[m], 50)
    print('  subject        %.1f%% of frame   mean %d/%d/%d' % (
        100.0 * m.mean(), *px.mean(axis=0).round()))
    print('  subject luma   p05 %.0f  p50 %.0f  p95 %.0f   -> %s' % (
        p05, p50, np.percentile(lum[m], 95),
        'ok' if 65 <= p50 <= 82 else
        'TOO DARK, bakes crushed (references that work sit at p50 69-77)' if p50 < 65
        else 'bright -- check it still separates from the backdrop'))
    ys, xs = np.where(m)
    w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    print('  bbox           %dx%d px   w/h %.2f   (the mesh lands near this)' % (w, h, w / h))
    mar = [xs.min(), im.shape[1] - 1 - xs.max(), ys.min(), im.shape[0] - 1 - ys.max()]
    print('  frame margin   l %d r %d t %d b %d   -> %s' % (
        *mar, 'ok' if min(mar) > 20 else 'TOUCHING THE EDGE, comes back a blob'))
    bg = im[~m]
    print('  backdrop       mean %d/%d/%d  (asked for 90/93/99)   subject margin %.0f' % (
        *bg.mean(axis=0).round(), bg.mean() - p50))


# gamma the subject to a target median and re-lay it on a truly flat backdrop. holds the
# composition fixed, so the next bake differs from the last by VALUE ALONE -- and it also
# scrubs the vignette gpt paints instead of the flat grey it was asked for
def lift(path, out, target):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    d = np.abs(im - BG).sum(axis=2)
    # soft coverage, ramped across the antialiased edge so the composite leaves no halo
    alpha = np.clip((d - 30.0) / 50.0, 0, 1)[..., None]
    lum = 0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2]
    p50 = np.percentile(lum[alpha[..., 0] > 0.9], 50)
    # a gamma rather than a scale: it lifts the darks hardest and leaves the few light texels
    # alone, so the subject keeps its own value range instead of flattening
    gam = np.log(target / 255.0) / np.log(p50 / 255.0)
    px = 255.0 * np.power(np.clip(im, 0, 255) / 255.0, gam) * alpha + BG * (1 - alpha)
    Image.fromarray(np.clip(px, 0, 255).astype(np.uint8)).save(out)
    print('  subject p50 %.0f -> %.0f  (gamma %.3f), backdrop flattened -> %s' % (
        p50, target, gam, out))


args = sys.argv[1:]
if not args:
    sys.exit(__doc__)
path = args[0]
print(path.split('/')[-1])
if '--lift' in args:
    i = args.index('--lift')
    o = args[args.index('-o') + 1] if '-o' in args else path.replace('.png', '-lifted.png')
    lift(path, o, float(args[i + 1]))
elif path.lower().endswith('.glb'):
    stat_glb(path)
else:
    stat_png(path)

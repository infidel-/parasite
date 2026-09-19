#!/usr/bin/env python3
"""
Generate an emissive map for a glb whose UV atlas layout is unknown.

A TRELLIS export packs its atlas as a mosaic of small charts, so an emissive map cannot be
hand-painted: there is no way to tell by looking which patch is the lamp lens. It does not have to
be painted. The glowing part of a prop is a REGION IN SPACE, and the atlas is a bijection from
surface to texels, so selecting triangles by their position and rasterizing their UV triangles puts
the mask exactly where the surface is.

Selection is by BOUNDING BOX ON THE TRIANGLE CENTROID, in the glb's own frame, and deliberately
nothing else. Two other selectors were tried on facility/lamp-post and both failed:

  - the whole head box. The head is a flat SLAB, so its biggest face is the top, pointing straight
    at a camera that looks down: the fixture read as a glowing white card lying on the mast.
  - the head's DOWNWARD-FACING triangles (averaged NORMAL, ny < -0.5). A generated mesh's normals
    are not trustworthy at that resolution -- the result still caught strays and still missed part
    of the face it was aiming at.

A box has neither problem: it is stated in the same coordinates --bbox prints, it is verifiable by
eye in the preview, and it does not care what the generator wrote into NORMAL.

BLEED is the other half, and it is what puts "a few white polys" somewhere they do not belong. The
dilation that pushes the mask into the chart gutter (so the map survives being resized down by
`make models`, and so bilinear sampling at a chart edge does not read black) will cross into the
NEXT chart, which on a mosaic atlas is a completely unrelated part of the surface. So the dilation
is masked against the rasterized coverage of every UNSELECTED triangle, and the run reports how many
unselected triangles still sample a lit texel. That number must be 0.

A BOX IS NOT ALWAYS ENOUGH, and the alien ship is the case that proves it: its lamp discs and its
ramp doorway share one equatorial band, so the box holds both and only an albedo key can tell them
apart -- and a luminance threshold has no idea what a lamp is. It kept 4,983 scattered triangles.
`--tris` is the answer to that: the selection is painted ON the prop in the running game
(render.PolyPaint, debug key T) and exported as the triangle indices themselves, and this script
does only what it is actually good at -- the conservative rasterisation, the gutter dilation and the
bleed gate.

usage:
  python3 tools/emissive.py <glb> --bbox                      # print the frame, pick a box in it
  python3 tools/emissive.py <glb> -o out.png --box x0,x1,y0,y1,z0,z1 [--tint 9db4d4] [--preview p.png]
  python3 tools/emissive.py <glb> -o out.png --tris paint.json --family e0c23c

Run it on the BUILT glb (app/models/...), never the 100k master: the mask has to match the UVs the
game samples, and decimation moves charts.
"""

import argparse
import io
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CT = {5120: 'i1', 5121: 'u1', 5122: 'i2', 5123: 'u2', 5125: 'u4', 5126: 'f4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


# read a glb into its json chunk and its binary chunk
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


# CONSERVATIVE coverage: which texels a set of triangles touches AT ALL, as a res x res bool.
#
# not plain rasterization, and the difference is the whole reason this tool exists. PIL fills a
# polygon by pixel CENTRE, so a chart thinner than a texel covers nothing at all -- and a TRELLIS
# atlas is full of those. A chart that rasterizes to nothing is invisible to the bleed mask below
# while the GPU still samples the texel under it, which is exactly how "white specks on the pole"
# survives a mask that measured clean. So rasterize at ss x and max-pool down: a texel counts as
# covered if ANY part of any triangle falls in it. `outline` too, for a triangle so thin that even
# the supersampled fill misses it
def cover(uvs, res, ss=4):
    n = res * ss
    im = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(im)
    for t in uvs:
        p = [(float(q[0]) * n, float(q[1]) * n) for q in t]
        d.polygon(p, fill=255, outline=255)
    return np.asarray(im).reshape(res, ss, res, ss).max(axis=(1, 3)) > 0


# the glb's OWN base-colour map, resized to res: what --modulate multiplies the flat mask by.
#
# a flat mask is right for a LENS, which is one small bright thing, and wrong for a WINDOW RUN, which
# is a big region whose whole read is its structure. lit flat, facility/booth's glazing came back as
# a white card stuck on a black box -- the same failure the lamp head's whole-head box produced, one
# scale up. the base map already separates the panes from the mullions by a factor of ~3 in value, so
# multiplying by it puts the glow ON THE GLASS and leaves the frames dark for free.
def basemap(g, bin_, res):
    """`res` None returns the map at its authored size — what --key samples per triangle."""
    mat = g['materials'][0]
    tex = mat.get('pbrMetallicRoughness', {}).get('baseColorTexture')
    if tex is None:
        sys.exit('--modulate: the glb carries no base-colour texture')
    bv = g['bufferViews'][g['images'][g['textures'][tex['index']]['source']]['bufferView']]
    off = bv.get('byteOffset', 0)
    im = Image.open(io.BytesIO(bin_[off:off + bv['byteLength']])).convert('RGB')
    if res is not None:
        im = im.resize((res, res), Image.LANCZOS)
    return np.asarray(im).astype(np.float64) / 255.0


# grow a bool mask by r texels (chebyshev)
def grow(m, r):
    if r <= 0:
        return m
    im = Image.fromarray((m * 255).astype(np.uint8), 'L')
    return np.asarray(im.filter(ImageFilter.MaxFilter(2 * r + 1))) > 0


# an orthographic preview down one axis, selected triangles in red over the rest in grey. painter's
# algorithm on the triangle centroid, which is enough to read a silhouette.
#
# FRAMED ON THE SELECTION, not on the prop: a lamp lens is 2% of a 6-metre mast and is one unreadable
# pixel in a whole-prop view. and the PLAN view sorts the other way round, because it looks from
# BELOW — the one direction from which a downlight's lens is the near face rather than the hidden one
def preview(pos, tri, sel, axis, res, focus):
    ax = {'x': (2, 1, 0), 'y': (0, 2, 1), 'z': (0, 1, 2)}[axis]
    p = pos[:, ax]
    c = focus.mean(axis=0)[list(ax[:2])]
    span = (focus[1] - focus[0]).max() * 3.0
    q = (p[:, :2] - c + span / 2) / span * res
    q[:, 1] = res - q[:, 1]  # +up on screen
    im = Image.new('RGB', (res, res), (18, 18, 22))
    d = ImageDraw.Draw(im)
    depth = pos[tri][:, :, ax[2]].mean(axis=1)
    for i in (np.argsort(depth)[::-1] if axis == 'y' else np.argsort(depth)):
        t = tri[i]
        d.polygon([(q[v][0], q[v][1]) for v in t],
                  fill=(235, 60, 45) if sel[i] else (108, 110, 116),
                  outline=(120, 24, 18) if sel[i] else (78, 80, 86))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('glb')
    ap.add_argument('-o', '--out')
    ap.add_argument('--box', help='x0,x1,y0,y1,z0,z1 on the triangle centroid, glb frame')
    ap.add_argument('--bbox', action='store_true', help='print the mesh frame and exit')
    ap.add_argument('--res', type=int, default=512)
    ap.add_argument('--dilate', type=int, default=2, help='px pushed into the chart gutter')
    ap.add_argument('--tint', default='ffffff', help='RRGGBB; models.mjs pins emissiveFactor to 1,1,1')
    ap.add_argument('--key', choices=('warm', 'pale'),
                    help="narrow the box by each triangle's OWN baked albedo, sampled at its uv "
                         "centroid. A BOX CANNOT SEPARATE INTERLEAVED LAMPS: the alien ship carries "
                         'a yellow panel and a pale lamp disc alternating round one equatorial ring, '
                         'so every box that holds either holds both, and two tints cannot come out '
                         "of one selection. 'warm' keeps the texels whose blue is well under their "
                         "red (a yellow panel), 'pale' keeps the bright near-neutral ones (a white "
                         'lamp). The gates below are unchanged and still apply: a keyed selection is '
                         'a smaller selection, so its bleed check is if anything stricter')
    ap.add_argument('--keylo', type=float, default=None,
                    help="the key's one threshold: for 'warm' the blue/red ratio under which a texel "
                         "counts (default 0.62), for 'pale' the mean value over which it does "
                         '(default 115). Fit it by eye on --preview, which paints the kept triangles')
    ap.add_argument('--modulate', action='store_true',
                    help="multiply the mask by the glb's own base map, so a window run keeps its "
                         'mullions dark instead of reading as one glowing card')
    ap.add_argument('--tris', help='select by an EXPLICIT triangle index list instead of a box: the '
                                   'JSON render.PolyPaint exports from the running game '
                                   '(localStorage `emispaint`). A box plus an albedo key cannot see '
                                   'what a lamp IS -- it kept 4,983 scattered triangles of the alien '
                                   "ship's hull -- so the selection is made on the prop with the "
                                   'mouse and only the RASTERISATION happens here. Needs --family')
    ap.add_argument('--family', help='which family of the --tris export to bake, by its marker hue '
                                     '(RRGGBB). --tint defaults to that hue')
    ap.add_argument('--near', action='store_true',
                    help='let the mask bleed onto triangles that TOUCH the selection, and keep the '
                         'zero gate only for foreign ones. The subtraction below protects every '
                         'unselected triangle equally, which is right for a mosaic atlas (a '
                         'dilation can land on an unrelated part of the model) and much too strict '
                         'for a dense mesh: at ~8 texels per triangle almost every texel of a '
                         'selected triangle is within one of the hull triangle it shares an edge '
                         'with, so the mask erodes to slivers the mip chain then washes out. '
                         'Measured on the alien ship at 1024: 1.098%% kept against 1.637%% eaten, '
                         'and the prop read as unlit. One texel of glow on the neighbour a lamp is '
                         'set into is invisible; a speck on the far side of the model is not, and '
                         'that is still gated at 0')
    ap.add_argument('--preview', help='write a 3-view selection check here')
    a = ap.parse_args()

    g, bin_ = load(a.glb)
    prim = g['meshes'][0]['primitives'][0]
    pos = acc(g, bin_, prim['attributes']['POSITION']).astype(np.float64)
    uv = acc(g, bin_, prim['attributes']['TEXCOORD_0']).astype(np.float64)
    tri = acc(g, bin_, prim['indices']).reshape(-1, 3).astype(np.int64)
    cen = pos[tri].mean(axis=1)

    if a.bbox or not (a.box or a.tris):
        print('tris %d  verts %d' % (len(tri), len(pos)))
        print('bbox min %s' % np.round(pos.min(axis=0), 4))
        print('bbox max %s' % np.round(pos.max(axis=0), 4))
        if not a.bbox:
            sys.exit('--box or --tris is required to write a map')
        return

    if a.tris:
        # an index list is only meaningful against the bake it was painted on: decimation moves both
        # the indices and the charts, so a count mismatch would light an unrelated surface
        if not a.family:
            sys.exit('--tris needs --family <RRGGBB>')
        with open(a.tris) as f:
            doc = json.load(f)
        if doc.get('tris') != len(tri):
            sys.exit('--tris was painted on a %s-triangle bake, this glb has %d -- repaint it'
                     % (doc.get('tris'), len(tri)))
        picked = None
        for fam in doc['families']:
            if fam['hue'].lower() == a.family.lower():
                picked = fam['tris']
        if picked is None:
            sys.exit('no family %s in %s (have %s)'
                     % (a.family, a.tris, ', '.join(f['hue'] for f in doc['families'])))
        sel = np.zeros(len(tri), dtype=bool)
        sel[np.array(picked, dtype=np.int64)] = True
        if a.tint == 'ffffff':
            a.tint = a.family.lower()
        print('family %s: %d painted tris' % (a.family, len(picked)))
    else:
        b = [float(v) for v in a.box.split(',')]
        sel = ((cen[:, 0] >= b[0]) & (cen[:, 0] <= b[1]) &
               (cen[:, 1] >= b[2]) & (cen[:, 1] <= b[3]) &
               (cen[:, 2] >= b[4]) & (cen[:, 2] <= b[5]))
    if a.key:
        # the base map at FULL resolution, sampled at each triangle's uv centroid. full and not the
        # res-scaled copy `--modulate` uses: this is a per-triangle question and a lamp disc is a few
        # texels across, so a downscale would average it into the hull around it
        full = basemap(g, bin_, None)
        h, w = full.shape[:2]
        c = uv[tri].mean(axis=1)
        px = np.clip((c[:, 0] * w).astype(int), 0, w - 1)
        py = np.clip((c[:, 1] * h).astype(int), 0, h - 1)
        rgb = full[py, px] * 255.0
        if a.key == 'warm':
            lo = 0.62 if a.keylo is None else a.keylo
            hit = (rgb[:, 2] < rgb[:, 0] * lo) & (rgb[:, 0] > 90)
        else:
            lo = 115.0 if a.keylo is None else a.keylo
            hit = (rgb.mean(axis=1) > lo) & (np.abs(rgb[:, 0] - rgb[:, 2]) < 45)
        print('key %s at %g: %d of %d boxed tris kept' % (a.key, lo, (sel & hit).sum(), sel.sum()))
        sel = sel & hit

    e = pos[tri]
    area = 0.5 * np.linalg.norm(np.cross(e[:, 1] - e[:, 0], e[:, 2] - e[:, 0]), axis=1)
    print('selected %d of %d tris, %.1f%% of surface area'
          % (sel.sum(), len(tri), 100 * area[sel].sum() / area.sum()))
    if sel.sum() == 0:
        sys.exit('empty selection' + (' — the box holds tris but the key kept none of them'
                                      if a.key else ''))

    # which unselected triangles TOUCH the selection (share a vertex with it). --near exempts these
    # from the subtraction below: they are the surface the lamp is set into, not a foreign chart
    near = np.zeros(len(tri), dtype=bool)
    if a.near:
        near = np.isin(tri, np.unique(tri[sel])).any(axis=1) & ~sel
        print('touching the selection: %d unselected tris exempted from the bleed subtraction'
              % near.sum())

    # the two conservative coverages, and then the subtraction that is the whole point: a texel is
    # lit only if the selection touches it AND nothing else does. `other` is grown by one texel
    # first, because a fragment does not sample one texel — bilinear reads a 2x2 neighbourhood, so a
    # texel merely ADJACENT to a foreign chart leaks into it
    lit = grow(cover(uv[tri[sel]], a.res), a.dilate)
    oth = grow(cover(uv[tri[~sel & ~near]], a.res), 1)
    kept = lit & ~oth
    print('lit texels %.3f%%  (the dilation lost %.3f%% to neighbouring charts)'
          % (100 * kept.mean(), 100 * (lit & oth).mean()))

    # and the gate: does any UNSELECTED triangle touch a lit texel. by construction it cannot, so
    # this is a check on the construction, and it is per-TRIANGLE rather than per-centroid — a
    # triangle with one lit corner still draws a speck, which a centroid test never sees
    bad = 0
    touched = 0
    for k, t in zip(np.nonzero(~sel)[0], uv[tri[~sel]]):
        x0 = max(0, int(np.floor(t[:, 0].min() * a.res)))
        x1 = min(a.res - 1, int(np.ceil(t[:, 0].max() * a.res)))
        y0 = max(0, int(np.floor(t[:, 1].min() * a.res)))
        y1 = min(a.res - 1, int(np.ceil(t[:, 1].max() * a.res)))
        # the UV bbox is a superset of the triangle, so a clean bbox needs no exact test — and it is
        # clean for nearly every triangle, which is what keeps this loop cheap
        if not kept[y0:y1 + 1, x0:x1 + 1].any():
            continue
        if not (cover([t], a.res) & kept).any():
            continue
        if near[k]:
            touched += 1
        else:
            bad += 1
    if a.near:
        print('bleed onto tris touching the selection: %d  (allowed)' % touched)
    print('bleed onto FOREIGN tris: %d  (must be 0)' % bad)

    col = np.array([int(a.tint[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    px = kept[..., None] * col
    if a.modulate:
        px = px * basemap(g, bin_, a.res)
        print('modulated by the base map: lit texels mean %.0f of 255' % px[kept].mean())
    Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), 'RGB').save(a.out)
    print('wrote ' + a.out)

    if a.preview:
        w = 420
        sv = pos[np.unique(tri[sel])]
        focus = np.array([sv.min(axis=0), sv.max(axis=0)])
        strip = Image.new('RGB', (w * 3, w))
        for i, axis in enumerate(('z', 'x', 'y')):
            strip.paste(preview(pos, tri, sel, axis, w, focus), (w * i, 0))
        strip.save(a.preview)
        print('wrote ' + a.preview + '  (views: front +z, side +x, plan -y)')


main()

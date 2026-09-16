// offline model bake: mirror of tools/textures.py for .glb props.
// walks art/models.json, decimates each source to a target tri count (meshopt) and shrinks
// its embedded texture, writes a self-contained optimized glb into parasite/resources/app/models/.
// models.json is both manifest and cache: a per-entry last_converted stamp drives the mtime-skip.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, KHRMaterialsEmissiveStrength } from '@gltf-transform/extensions';
import { weld, simplify, textureCompress, prune, dedup } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
import { readFileSync, writeFileSync, existsSync, statSync, mkdirSync, readdirSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'models-src');
const OUT = join(ROOT, 'parasite/resources/app/models');
// the manifest is TRACKED and lives in the repo, while the sources it points at do not: it carries
// every entry's params and notes, so a commit stays explainable even though the art store is not
// versioned (mirrors textures.py's art/textures.json)
const INFO = join(ROOT, 'art/models.json');
// bake-STEP version, folded into every entry's signature so a change to what the bake DOES (as
// opposed to the per-entry params it does it with) rebuilds every prop once on the next run
const PIPELINE = 'n1';

// delete Krita/editor backup files (name ends with ~) under a dir, recursively (mirrors textures.py)
function sweepBackups(dir)
{
  let n = 0;
  for (const ent of readdirSync(dir, { withFileTypes: true }))
    {
      const p = join(dir, ent.name);
      if (ent.isDirectory())
        n += sweepBackups(p);
      else if (ent.name.endsWith('~'))
        {
          unlinkSync(p);
          n++;
        }
    }
  return n;
}

// total triangles across every mesh primitive in a document
function countTris(doc)
{
  let tris = 0;
  for (const mesh of doc.getRoot().listMeshes())
    for (const prim of mesh.listPrimitives())
      {
        const idx = prim.getIndices();
        const pos = prim.getAttribute('POSITION');
        tris += (idx ? idx.getCount() : (pos ? pos.getCount() : 0)) / 3;
      }
  return Math.round(tris);
}

// per-vertex AMBIENT OCCLUSION baked into COLOR_0, so a prop carries its own crevices in the mesh
// and needs nothing at all from the runtime rig.
//
// WHY IT IS BAKED AND NOT LIT. measured in the facility: an indoor prop's pixel is ~93% flat
// normal-blind fill, and flooding every light in the room by 6.7x moved the lab trolley's standard
// deviation over its own pixels from 7.02 to 7.48. no lighting change reaches the inside of an open
// trolley frame or the gap between two cylinders, because no light in the game is in there. AO is
// the only term that darkens a place because of the SHAPE around it, and computing it once offline
// costs the frame nothing forever after: COLOR_0 multiplies the base colour in three's own shader,
// so this is zero draw calls, zero texture memory and one program permutation (USE_COLOR).
//
// VOXELS AND NOT RAY-TRIANGLE, which is the one implementation choice worth defending. these props
// are ~6k triangles and ~5k vertices; a naive ray cast is verts x rays x tris = 700M tests and takes
// minutes, and a BVH is a dependency this pipeline does not have. rasterizing the mesh into an
// occupancy grid once and DDA-marching that instead makes it verts x rays x steps = ~5M lookups,
// which is instant, and the error it introduces is bounded by one cell — invisible in a term that is
// blurred over a whole hemisphere anyway.
//
// DETERMINISTIC: the ray directions are a golden-angle cosine-weighted spiral, never Math.random,
// so a rebuild of an unchanged source produces a byte-identical glb
function bakeAO(doc, strength, rays, res, reachFrac)
{
  let done = 0;
  for (const mesh of doc.getRoot().listMeshes())
    for (const prim of mesh.listPrimitives())
      {
        const posAttr = prim.getAttribute('POSITION');
        const nrmAttr = prim.getAttribute('NORMAL');
        const idxAttr = prim.getIndices();
        if (posAttr == null || nrmAttr == null || idxAttr == null)
          continue;
        const pos = posAttr.getArray();
        const nrm = nrmAttr.getArray();
        const idx = idxAttr.getArray();
        const nv = posAttr.getCount();
        // bbox, and a CUBIC grid over its longest axis so a cell is the same size on every axis —
        // a stretched cell would make the march's step length direction-dependent
        let lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
        for (let i = 0; i < nv; i++)
          for (let k = 0; k < 3; k++)
            {
              const v = pos[i * 3 + k];
              if (v < lo[k]) lo[k] = v;
              if (v > hi[k]) hi[k] = v;
            }
        const span = Math.max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]);
        if (!(span > 0))
          continue;
        const cell = span / res;
        const dim = [0, 1, 2].map(k => Math.max(1, Math.ceil((hi[k] - lo[k]) / cell) + 1));
        const grid = new Uint8Array(dim[0] * dim[1] * dim[2]);
        const at = (x, y, z) => (z * dim[1] + y) * dim[0] + x;
        const mark = (x, y, z) =>
          {
            const gx = Math.floor((x - lo[0]) / cell), gy = Math.floor((y - lo[1]) / cell), gz = Math.floor((z - lo[2]) / cell);
            if (gx < 0 || gy < 0 || gz < 0 || gx >= dim[0] || gy >= dim[1] || gz >= dim[2])
              return;
            grid[at(gx, gy, gz)] = 1;
          };
        // rasterize every triangle onto the grid, sampled on a barycentric lattice fine enough that
        // consecutive samples are under a cell apart — so a triangle can never straddle a cell it
        // failed to mark and leave a hole a ray walks through
        for (let t = 0; t < idx.length; t += 3)
          {
            const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
            const e1 = Math.hypot(pos[b] - pos[a], pos[b + 1] - pos[a + 1], pos[b + 2] - pos[a + 2]);
            const e2 = Math.hypot(pos[c] - pos[a], pos[c + 1] - pos[a + 1], pos[c + 2] - pos[a + 2]);
            const n = Math.max(1, Math.ceil(Math.max(e1, e2) / (cell * 0.5)));
            for (let i = 0; i <= n; i++)
              for (let j = 0; j <= n - i; j++)
                {
                  const u = i / n, v = j / n, w = 1 - u - v;
                  mark(pos[a] * w + pos[b] * u + pos[c] * v,
                       pos[a + 1] * w + pos[b + 1] * u + pos[c + 1] * v,
                       pos[a + 2] * w + pos[b + 2] * u + pos[c + 2] * v);
                }
          }
        // and march. the ray starts 1.5 cells off the surface along the normal, which is what stops a
        // vertex occluding itself on the very cell it sits in.
        //
        // HOW FAR A RAY LOOKS IS A FRACTION OF THE PROP, and 0.35 of it is not always enough — which
        // is the trap the janitor bucket found. A ray leaving the inside wall of a vessel has to
        // cross the whole BORE to hit the far side, and the bucket's bore is 0.5 against a span of
        // 0.84: at 0.35 the reach is 0.294, every cross-bore ray runs out of steps and escapes, and
        // the inside of a bucket comes back as open as the outside. The default stays 0.35 because
        // on a normal prop a longer reach only adds distant geometry that a hemisphere average is
        // going to wash out anyway; a DEEP CONCAVITY is what wants `aoReach` in the manifest
        const reach = span * reachFrac;
        const steps = Math.ceil(reach / (cell * 0.9));
        const col = new Float32Array(nv * 3);
        for (let i = 0; i < nv; i++)
          {
            let nx = nrm[i * 3], ny = nrm[i * 3 + 1], nz = nrm[i * 3 + 2];
            const nl = Math.hypot(nx, ny, nz) || 1;
            nx /= nl; ny /= nl; nz /= nl;
            // an orthonormal basis about the normal, branch chosen so the cross product never
            // degenerates on an axis-aligned normal
            let tx, ty, tz;
            if (Math.abs(ny) < 0.9) { tx = -nz; ty = 0; tz = nx; }
            else { tx = 0; ty = -nz; tz = ny; }
            const tl = Math.hypot(tx, ty, tz) || 1;
            tx /= tl; ty /= tl; tz /= tl;
            const bx = ny * tz - nz * ty, by = nz * tx - nx * tz, bz = nx * ty - ny * tx;
            const ox = pos[i * 3] + nx * cell * 1.5, oy = pos[i * 3 + 1] + ny * cell * 1.5, oz = pos[i * 3 + 2] + nz * cell * 1.5;
            let hits = 0;
            for (let r = 0; r < rays; r++)
              {
                const s = (r + 0.5) / rays;
                const st = Math.sqrt(s), ct = Math.sqrt(1 - s), ph = r * 2.399963229728653;
                const cp = Math.cos(ph) * st, sp = Math.sin(ph) * st;
                const dx = tx * cp + bx * sp + nx * ct;
                const dy = ty * cp + by * sp + ny * ct;
                const dz = tz * cp + bz * sp + nz * ct;
                for (let k = 1; k <= steps; k++)
                  {
                    const d = k * cell * 0.9;
                    const gx = Math.floor((ox + dx * d - lo[0]) / cell);
                    const gy = Math.floor((oy + dy * d - lo[1]) / cell);
                    const gz = Math.floor((oz + dz * d - lo[2]) / cell);
                    if (gx < 0 || gy < 0 || gz < 0 || gx >= dim[0] || gy >= dim[1] || gz >= dim[2])
                      break;
                    if (grid[at(gx, gy, gz)])
                      {
                        hits++;
                        break;
                      }
                  }
              }
            const ao = 1 - strength * (hits / rays);
            col[i * 3] = ao;
            col[i * 3 + 1] = ao;
            col[i * 3 + 2] = ao;
          }
        prim.setAttribute('COLOR_0', doc.createAccessor()
          .setType('VEC3')
          .setArray(col)
          .setBuffer(doc.getRoot().listBuffers()[0]));
        done++;
      }
  return done;
}

// replace every zero-length vertex normal with one borrowed from an adjacent face, and report how
// many. THIS IS NOT COSMETIC: `normalize(vec3(0.0))` is NaN in GLSL, so a single such vertex shades a
// few NaN fragments, they land in the half-float post buffer, and UnrealBloom's downsample-and-blur
// chain smears the NaN across every texel it touches — the whole frame composites BLACK, flickering
// in and out as the camera moves those few pixels on and off screen. TRELLIS exports carry a handful
// (19 on habitat/biomineral, 1 on habitat/assimilation, 0 on the props that shipped before), so the
// glb is where it has to be caught: nothing downstream can tell a NaN pixel from a dark one
function fixNormals(doc)
{
  let fixed = 0;
  for (const mesh of doc.getRoot().listMeshes())
    for (const prim of mesh.listPrimitives())
      {
        const nrm = prim.getAttribute('NORMAL');
        const pos = prim.getAttribute('POSITION');
        if (nrm == null || pos == null)
          continue;
        // find the bad vertices first, so the triangle walk below is skipped outright on a clean mesh
        const bad = new Set();
        const n = [];
        for (let i = 0; i < nrm.getCount(); i++)
          {
            nrm.getElement(i, n);
            if (n[0] * n[0] + n[1] * n[1] + n[2] * n[2] < 1e-12)
              bad.add(i);
          }
        if (bad.size == 0)
          continue;
        // accumulate the UNNORMALIZED cross product of every triangle touching a bad vertex, which
        // weights each face by its own area — the standard smooth-normal sum, so the repaired vertex
        // agrees with the shading of the surface around it instead of snapping to one arbitrary face
        const acc = new Map();
        const idx = prim.getIndices();
        const count = idx ? idx.getCount() : pos.getCount();
        const a = [], b = [], c = [];
        for (let t = 0; t < count; t += 3)
          {
            const ia = idx ? idx.getScalar(t) : t;
            const ib = idx ? idx.getScalar(t + 1) : t + 1;
            const ic = idx ? idx.getScalar(t + 2) : t + 2;
            if (!bad.has(ia) && !bad.has(ib) && !bad.has(ic))
              continue;
            pos.getElement(ia, a);
            pos.getElement(ib, b);
            pos.getElement(ic, c);
            const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
            const vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
            const f = [uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx];
            for (const i of [ia, ib, ic])
              {
                if (!bad.has(i))
                  continue;
                const s = acc.get(i) ?? [0, 0, 0];
                s[0] += f[0];
                s[1] += f[1];
                s[2] += f[2];
                acc.set(i, s);
              }
          }
        for (const i of bad)
          {
            const s = acc.get(i) ?? [0, 0, 0];
            const len = Math.hypot(s[0], s[1], s[2]);
            // a vertex whose every adjacent face is degenerate too (or that no triangle references)
            // has nothing to borrow from. any unit vector will do — it is never visibly shaded, and
            // the only thing that matters is that it is not zero
            nrm.setElement(i, len > 0 ? [s[0] / len, s[1] / len, s[2] / len] : [0, 1, 0]);
            fixed++;
          }
      }
  return fixed;
}

// dump the embedded textures of a source glb to models-src/ as PNGs, so an emissive map can be
// traced off the base color (mirrors the street-lamp2 base+emissive workflow). base color goes to
// <src>-base.png (a reference, not the texSrc override), other maps to <src>-<role>.png — named off
// the SOURCE glb's path so the dumps sit next to the mesh they came from.
// usage: node tools/models.mjs --export <label>
async function exportTextures(label)
{
  if (!existsSync(INFO))
    {
      console.error('missing ' + INFO);
      process.exit(1);
    }
  const info = JSON.parse(readFileSync(INFO, 'utf8'));
  const e = info.models[label];
  if (e == null)
    {
      console.error('no model "' + label + '" in models.json');
      process.exit(1);
    }
  const src = join(SRC, e.src);
  if (!existsSync(src))
    {
      console.error('missing source ' + e.src + ' for ' + label);
      process.exit(1);
    }
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
  const doc = await io.read(src);
  // resolve each texture to a role suffix via the material slot that references it (first wins)
  const roles = new Map();
  for (const m of doc.getRoot().listMaterials())
    for (const [suffix, t] of [
      ['-base', m.getBaseColorTexture()],
      ['-normal', m.getNormalTexture()],
      ['-mr', m.getMetallicRoughnessTexture()],
      ['-emissive-embedded', m.getEmissiveTexture()],
      ['-ao', m.getOcclusionTexture()],
    ])
      if (t != null && !roles.has(t))
        roles.set(t, suffix);
  // dumped BESIDE the glb, not beside the label: a label's folder and its source's folder are
  // independent, and an export that followed the label landed a folder away from the mesh it belongs
  // to. the case that proved it was habitat/assimilation living at habitat/flat/assimilation.glb —
  // that folder level has since been flattened away, so every label's two paths happen to match
  // today, which is exactly the state in which this would silently rot if it were keyed on the label
  const stem = e.src.replace(/\.glb$/i, '');
  let n = 0;
  for (const [t, suffix] of roles)
    {
      const img = t.getImage();
      if (img == null)
        continue;
      const outName = stem + suffix + '.png';
      // re-encode to png (glb may store jpeg) so Krita opens it straight
      await sharp(Buffer.from(img)).png().toFile(join(SRC, outName));
      const meta = await sharp(Buffer.from(img)).metadata();
      console.log('   exported  ' + outName + '  ' + meta.width + 'x' + meta.height);
      n++;
    }
  console.log('export: ' + n + ' textures from ' + e.src + ' -> models-src/');
}

async function main()
{
  if (!existsSync(INFO))
    {
      console.error('missing ' + INFO);
      process.exit(1);
    }
  const swept = sweepBackups(SRC);
  if (swept > 0)
    console.log('   swept       ' + swept + ' backup (~) file(s)');
  const info = JSON.parse(readFileSync(INFO, 'utf8'));
  const defaultTris = info.default_tris ?? 200;
  const defaultTex = info.default_tex ?? 256;
  mkdirSync(OUT, { recursive: true });
  await MeshoptSimplifier.ready;
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
  let built = 0, fresh = 0;

  for (const [label, e] of Object.entries(info.models))
    {
      const src = join(SRC, e.src);
      // a label may nest ("sewer/drum" -> models-src/sewer/drum.glb, app/models/sewer/drum.glb),
      // the same subfolder idiom textures.json uses for decals/ — so make the leaf dir, not just OUT
      const out = join(OUT, label + '.glb');
      mkdirSync(dirname(out), { recursive: true });
      if (!existsSync(src))
        {
          console.warn('!! missing source ' + e.src + ' for ' + label);
          continue;
        }
      const target = e.tris ?? defaultTris;
      const tex = e.tex ?? defaultTex;
      // meshopt error cap: how much shape distortion simplify may introduce (smaller = keep more
      // detail, may fall short of the tri target; larger = hit the target harder, coarser shape)
      const error = e.error ?? info.default_error ?? 0.01;
      // optional texture override: a hand-edited PNG (Krita etc) that replaces the glb's embedded
      // base-color texture at bake time. defaults to <label>.png next to the source if it exists
      const texSrc = e.texSrc ?? (label + '.png');
      const texPath = join(SRC, texSrc);
      const hasTex = existsSync(texPath);
      // optional emissive map: a hand-painted PNG (black except the glowing parts, e.g. the lamp
      // head/lens) added as the material's emissiveTexture. emissiveStrength scales it HDR>1 so bloom
      // picks it up. no default filename — only wired when emissiveSrc is set and the file exists
      const emiSrc = e.emissiveSrc ?? null;
      const emiPath = emiSrc != null ? join(SRC, emiSrc) : null;
      const emiStrength = e.emissiveStrength ?? info.default_emissive_strength ?? 3.0;
      // strength 0 is glow OFF, and it is off properly: the map is not baked in at all, so the glb
      // carries no dead texture and the material declares no USE_EMISSIVEMAP (which would be its own
      // program permutation and a texture fetch per fragment). the manifest keeps pointing at the PNG,
      // so turning a prop's glow back on is one number
      const hasEmi = emiPath != null && existsSync(emiPath) && emiStrength > 0;
      // effective source mtime = newest of the glb and any override PNG, so editing any rebuilds
      const srcMtime = Math.max(
        Math.floor(statSync(src).mtimeMs / 1000),
        hasTex ? Math.floor(statSync(texPath).mtimeMs / 1000) : 0,
        hasEmi ? Math.floor(statSync(emiPath).mtimeMs / 1000) : 0,
      );
      // skip if the output exists, no input is newer, AND the bake params are unchanged —
      // so editing tris/tex/error/maps rebuilds without a manual `touch` of the source
      const sig = PIPELINE + '/' + target + '/' + tex + '/' + error + '/' + (hasTex ? texSrc : '-') + '/' + (hasEmi ? emiSrc + '@' + emiStrength : '-') + (e.dropMR ? '/noMR' : '') + (e.baseColor ? '/bc' + e.baseColor.join(',') : '') + (e.lift != null ? '/lf' + e.lift : '') + (e.sat != null ? '/st' + e.sat : '') + (e.gradeRect ? '/gr' + JSON.stringify(e.gradeRect) : '') + (e.roughness != null ? '/rf' + e.roughness : '') + (e.metalness != null ? '/mf' + e.metalness : '') + (e.ao != null ? '/ao' + e.ao + ',' + (e.aoRays ?? '-') + ',' + (e.aoRes ?? '-') + ',' + (e.aoReach ?? '-') : '');
      const last = e.last_converted != null ? Math.floor(Date.parse(e.last_converted) / 1000) : null;
      if (existsSync(out) && last != null && srcMtime <= last && e.last_sig === sig)
        {
          console.log('   up to date  ' + label);
          fresh++;
          continue;
        }

      const doc = await io.read(src);
      const before = countTris(doc);
      const ratio = Math.min(1, target / Math.max(before, 1));
      // swap in the override PNG (full-res) before the resize step below shrinks it to `tex`
      if (hasTex)
        {
          const bytes = new Uint8Array(readFileSync(texPath));
          for (const m of doc.getRoot().listMaterials())
            {
              const t = m.getBaseColorTexture();
              if (t != null)
                t.setImage(bytes).setMimeType('image/png');
            }
          console.log('     baseColor <- ' + texSrc + ' (' + Math.round(bytes.length / 1024) + 'KB)');
        }
      // optional gamma LIFT on the base-colour MAP: out = (v/255)**lift, so lift < 1 brightens. same
      // knob name and meaning as textures.json's `lift`, and the missing inverse of baseColor below —
      // that one is a factor in [0,1] and can only multiply DOWN.
      //
      // what needs it: a prop dense enough to occlude itself comes back with that occlusion baked
      // into its albedo. measured on wild/bush-bramble, a lace of interlocking canes — from the same
      // reference value a conifer bakes at 0.79x and the bramble at 0.44x, landing on 30/29/29
      // against the prop family's 46-52. repainting the reference does not reach it either: the lift
      // tracks proportionally (a 28% brighter reference moved the bake 29%), so the reference would
      // have to out-brighten the flat #5a5d63 backdrop TRELLIS segments it against, which costs the
      // segmentation. so the correction has to happen here, on the bake.
      //
      // runs on the FULL-RES map, before the resize step below, for the same reason texSrc does
      if (e.lift != null)
        {
          const lut = Array.from({ length: 256 }, (_, v) => Math.round(255 * Math.pow(v / 255, e.lift)));
          for (const m of doc.getRoot().listMaterials())
            {
              const t = m.getBaseColorTexture();
              if (t == null)
                continue;
              const { data, info: raw } = await sharp(Buffer.from(t.getImage()))
                .ensureAlpha().raw().toBuffer({ resolveWithObject: true });
              // colour channels only — alpha is coverage, not brightness
              for (let i = 0; i < data.length; i += 4)
                {
                  data[i] = lut[data[i]];
                  data[i + 1] = lut[data[i + 1]];
                  data[i + 2] = lut[data[i + 2]];
                }
              const png = await sharp(data, { raw: { width: raw.width, height: raw.height, channels: 4 } })
                .png().toBuffer();
              t.setImage(new Uint8Array(png)).setMimeType('image/png');
            }
          console.log('     baseColor lifted ^' + e.lift + ' (gamma on the map; <1 brightens)');
        }
      // optional DESATURATION of the base-colour map: mix every pixel toward its own Rec.709
      // luminance, s = 1 a byte-exact no-op and 0 grey. DELIBERATELY THE SAME INSTRUMENT IN THE SAME
      // SPACE as textures.json's own `sat` (tools/textures.py sat_mix) and as the runtime `spriteSat`
      // uniform, so 0.5 means one thing across all three manifests — Rec.709 weights are a
      // linear-light instrument, so the mix is taken there and not on the sRGB bytes.
      //
      // what needs it: a prop whose colour is a FACT about it (a hazard drum, an amber gas bottle) is
      // generated against style_prop, which deliberately keeps it saturated — and a roomful of those
      // reads as toys beside surfaces painted against `style`. baseColor cannot do this job: it is a
      // per-channel FACTOR, so the only way it can flatten a 135/90/26 atlas is to invent blue, which
      // is the neutraliser facility/gas-cylinders' own note rejects. LUMINANCE IS PRESERVED BY
      // CONSTRUCTION, so this commutes with `lift` and with baseColor and leaves a fitted value alone.
      //
      // runs on the FULL-RES map, before the resize, for `lift`'s reason
      if (e.sat != null)
        {
          // sRGB EOTF both ways, so the mix happens in linear light
          const lin = Array.from({ length: 256 }, (_, v) =>
            {
              const c = v / 255;
              return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            });
          const enc = (c) =>
            {
              const v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
              return Math.max(0, Math.min(255, Math.round(v * 255)));
            };
          for (const m of doc.getRoot().listMaterials())
            {
              const t = m.getBaseColorTexture();
              if (t == null)
                continue;
              const { data, info: raw } = await sharp(Buffer.from(t.getImage()))
                .ensureAlpha().raw().toBuffer({ resolveWithObject: true });
              // colour channels only — alpha is coverage, not colour
              for (let i = 0; i < data.length; i += 4)
                {
                  const r = lin[data[i]], g = lin[data[i + 1]], b = lin[data[i + 2]];
                  const y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
                  data[i] = enc(y + (r - y) * e.sat);
                  data[i + 1] = enc(y + (g - y) * e.sat);
                  data[i + 2] = enc(y + (b - y) * e.sat);
                }
              const png = await sharp(data, { raw: { width: raw.width, height: raw.height, channels: 4 } })
                .png().toBuffer();
              t.setImage(new Uint8Array(png)).setMimeType('image/png');
            }
          console.log('     baseColor desaturated x' + e.sat + ' (Rec.709 in linear light)');
        }
      // optional PER-RECT grade of the base-colour MAP, and the one thing `lift`, `sat` and
      // `baseColor` above cannot state between them: all three are per LABEL, and a hand-modelled
      // prop's sheet is shared both between labels AND between that one prop's own surfaces.
      // facility/desk-tray hit it from both ends at once — a paper sheaf at srgb 165.6 standing in a
      // tray body at 59.6, off one map, while its own sheetmate facility/desk-journals had already
      // had its page edges graded to 92.1 in the PIXELS of a different sheet. No whole-map knob can
      // serve both: the gamma that brings the paper down takes the body to 10.
      //
      // tools/cellgamma.py is this instrument for textures.json and it rewrites the SOURCE drop. This
      // one rewrites the LABEL'S OWN BAKED COPY, which is the better place for a model sheet: the
      // number then lives in art/models.json, in the repo, rather than in the unversioned asset store
      // — and two labels off one sheet can grade the same rect differently.
      //
      // `scale` is a LINEAR multiply and holds the rect's internal contrast; a gamma does not, and on
      // that paper the gamma that reached the level took its chroma from 53 to 65 and left an ochre
      // card. `sat` is the block above's own Rec.709 mix, restricted to the rect. The rect is
      // x0,x1,y0,y1 in the EMBEDDED MAP's pixels — the frame the entry's note quotes the sheet's cells
      // in — and the map's size is logged so a sheet that was re-exported at another resolution shows
      if (e.gradeRect != null)
        {
          const lin = Array.from({ length: 256 }, (_, v) =>
            {
              const c = v / 255;
              return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            });
          const enc = (c) =>
            {
              const v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
              return Math.max(0, Math.min(255, Math.round(v * 255)));
            };
          for (const m of doc.getRoot().listMaterials())
            {
              const t = m.getBaseColorTexture();
              if (t == null)
                continue;
              const { data, info: raw } = await sharp(Buffer.from(t.getImage()))
                .ensureAlpha().raw().toBuffer({ resolveWithObject: true });
              for (const r of e.gradeRect)
                {
                  const sc = r.scale ?? 1, st = r.sat ?? 1;
                  const x0 = Math.max(0, r.rect[0]), x1 = Math.min(raw.width, r.rect[1]);
                  const y0 = Math.max(0, r.rect[2]), y1 = Math.min(raw.height, r.rect[3]);
                  for (let y = y0; y < y1; y++)
                    for (let x = x0; x < x1; x++)
                      {
                        const i = (y * raw.width + x) * 4;
                        const cr = lin[data[i]] * sc, cg = lin[data[i + 1]] * sc, cb = lin[data[i + 2]] * sc;
                        const yy = 0.2126 * cr + 0.7152 * cg + 0.0722 * cb;
                        data[i] = enc(yy + (cr - yy) * st);
                        data[i + 1] = enc(yy + (cg - yy) * st);
                        data[i + 2] = enc(yy + (cb - yy) * st);
                      }
                }
              const png = await sharp(data, { raw: { width: raw.width, height: raw.height, channels: 4 } })
                .png().toBuffer();
              t.setImage(new Uint8Array(png)).setMimeType('image/png');
              console.log('     baseColor graded on ' + e.gradeRect.length + ' rect(s) of the ' +
                raw.width + 'x' + raw.height + ' map');
            }
        }
      // FLATTEN a stray alpha channel out of an OPAQUE prop's base map. TRELLIS occasionally bakes one
      // in with the UV gutter at alpha 0, and that is not dead weight, it is a live trap: the resize
      // below PREMULTIPLIES, averages, then UNPREMULTIPLIES, so a block that is mostly gutter comes out
      // with an averaged alpha near 1/255 and its colour divided by that — saturated primaries
      // scattered along every chart boundary, which is worst on a shattered atlas because that is where
      // the boundaries are.
      //
      // measured on wild/tree-broadleaf-full, the one prop of 23 whose atlas carries a gutter (35.4% of
      // texels at alpha < 8): 2.949% of the built 512 landed at saturation > 0.75, ALL of them at alpha
      // < 128 with a mean of 2, and the map's own mean darkened 85/126/84 -> 73/110/72. flattening
      // first puts both back to 0.002% and 85/126/84, i.e. the source exactly.
      //
      // removeAlpha, never flatten({background}): the gutter already holds the right COLOUR (TRELLIS
      // dilates the charts into it — its mean rgb matches the atlas mean), so the channel is the only
      // thing wrong and compositing would throw the dilation away. safe by definition on an OPAQUE
      // material, which ignores alpha. scoped to the base map because that is where it was measured;
      // the same trap would hit any other map that arrived with a transparent gutter. runs LAST before
      // the resize, so it also strips the alpha `lift`'s ensureAlpha() re-adds
      for (const m of doc.getRoot().listMaterials())
        {
          if (m.getAlphaMode() !== 'OPAQUE')
            continue;
          const t = m.getBaseColorTexture();
          if (t == null)
            continue;
          const buf = Buffer.from(t.getImage());
          if (!(await sharp(buf).metadata()).hasAlpha)
            continue;
          t.setImage(new Uint8Array(await sharp(buf).removeAlpha().png().toBuffer())).setMimeType('image/png');
          console.log('     base map alpha flattened (opaque material; a transparent gutter explodes in the resize)');
        }
      // add the hand-painted emissive map (same UVs as base) + HDR strength so the head glows + blooms
      if (hasEmi)
        {
          const ebytes = new Uint8Array(readFileSync(emiPath));
          const etex = doc.createTexture('emissive').setImage(ebytes).setMimeType('image/png');
          const strengthExt = doc.createExtension(KHRMaterialsEmissiveStrength);
          for (const m of doc.getRoot().listMaterials())
            {
              m.setEmissiveTexture(etex);
              m.setEmissiveFactor([1, 1, 1]);
              m.setExtension('KHR_materials_emissive_strength',
                strengthExt.createEmissiveStrength().setEmissiveStrength(emiStrength));
            }
          console.log('     emissive  <- ' + emiSrc + ' (' + Math.round(ebytes.length / 1024) + 'KB, x' + emiStrength + ')');
        }
      // optional: strip the metallic-roughness map (temp — kills unwanted metal/gloss reflections);
      // fall back to matte non-metal factors so the prop reads flat like the game art. prune() below
      // drops the now-orphaned image from the glb
      if (e.dropMR)
        {
          for (const m of doc.getRoot().listMaterials())
            {
              m.setMetallicRoughnessTexture(null);
              m.setMetallicFactor(0);
              m.setRoughnessFactor(1);
            }
          console.log('     metallic-roughness map dropped (matte 0/1)');
        }
      // optional flat tint on the base colour (glTF baseColorFactor, LINEAR — three multiplies it
      // onto the sRGB-decoded map). for a prop whose authored albedo is far brighter than the game
      // art: a uniform map has nothing to repaint, so scale it rather than replace it via texSrc
      if (e.baseColor)
        {
          for (const m of doc.getRoot().listMaterials())
            m.setBaseColorFactor(e.baseColor);
          console.log('     baseColorFactor <- [' + e.baseColor.join(', ') + ']');
        }
      // optional roughness FACTOR — the specular dial. glTF MULTIPLIES it by the MR map's green
      // channel, so the map's own variation survives and only its level moves: a TRELLIS bake lands
      // uniformly matte (measured green p05..p95 of 0.71-0.94 across the habitat organs), which reads
      // as dead putty because nothing in that band catches a highlight from an analytic light. scaling
      // the whole map down brings it into highlight range while KEEPING crystal glossier than slime.
      //
      // DO NOT take this far below ~0.3, and never to 0. Specular is GGX D = a2 / (PI * d^2) with
      // a2 = roughness^4, so it blows up as roughness falls: against the tunnel's 45-candela spotlights
      // a mid-0.1 roughness peaks in the thousands (safe in a half-float buffer), while three's own
      // 0.0525 clamp peaks past 65504 at grazing incidence — which is INFINITY in the half-float post
      // buffer, and UnrealBloom's blur turns one such texel into a black frame. That failure is
      // documented in docs/3d-changes.md; this is the other way to reach it
      if (e.roughness != null)
        {
          for (const m of doc.getRoot().listMaterials())
            m.setRoughnessFactor(e.roughness);
          console.log('     roughnessFactor <- ' + e.roughness + ' (multiplies the MR map, not replacing it)');
        }
      // optional metallic FACTOR, the twin of the dial above and multiplied into the MR map's BLUE
      // channel the same way. TRELLIS exports every prop at metallicFactor 1, which is not a claim
      // about the object — it is the glTF default the bake never touches.
      //
      // A METAL HAS NO DIFFUSE TERM. Left at 1 with nothing to reflect, a prop renders BLACK; it only
      // ever looked passable because roughnessFactor 1 sent it down render.Models.toLambert and off
      // the PBR path entirely. So this is safe to raise ONLY where the runtime hands the material an
      // environment — render.world.PropEnv, which the facility's lab kit gets and nothing else does
      if (e.metalness != null)
        {
          for (const m of doc.getRoot().listMaterials())
            m.setMetallicFactor(e.metalness);
          console.log('     metallicFactor <- ' + e.metalness + ' (needs an envMap at runtime, see PropEnv)');
        }
      // decimate only when the target is below the source count; otherwise leave the geometry (and
      // its authored normals/hard edges) untouched — meshopt would keep hi-poly normals that mismatch
      // a coarser surface. always shrink the texture + clean up
      const steps = [];
      // tris: -1 explicitly keeps full geometry (no decimate); otherwise decimate when above target
      if (target >= 0 && before > target)
        steps.push(weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error }));
      else
        console.log('     geometry kept full (' + before + ' tris' + (target >= 0 ? ', target ' + target : ', decimate off') + ')');
      steps.push(textureCompress({ encoder: sharp, resize: [tex, tex], targetFormat: 'png' }), prune(), dedup());
      await doc.transform(...steps);
      // AFTER the transforms, never on the source: simplify() welds and collapses vertices, so it can
      // leave a normal degenerate that the export did not
      const badNormals = fixNormals(doc);
      if (badNormals > 0)
        console.log('     ' + badNormals + ' zero-length normal(s) rebuilt from adjacent faces');
      // AO goes on LAST, after simplify has settled the final vertex set and after prune() — which
      // would otherwise drop an attribute nothing references yet
      if (e.ao != null && e.ao > 0)
        {
          const t0 = Date.now();
          const prims = bakeAO(doc, e.ao, e.aoRays ?? info.default_ao_rays ?? 24, e.aoRes ?? info.default_ao_res ?? 72, e.aoReach ?? info.default_ao_reach ?? 0.35);
          console.log('     AO baked into COLOR_0 on ' + prims + ' primitive(s), strength ' + e.ao + ', res ' + (e.aoRes ?? info.default_ao_res ?? 72) + ', reach ' + (e.aoReach ?? info.default_ao_reach ?? 0.35) + ' (' + (Date.now() - t0) + 'ms)');
        }
      await io.write(out, doc);
      // UTC stamp (keep the Z) so the re-read compares in the same timezone as srcMtime's epoch
      e.last_converted = new Date(srcMtime * 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
      e.last_sig = sig; // bake-param signature; a mismatch forces a rebuild next run
      const after = countTris(doc);
      const kb = Math.round(statSync(out).size / 1024);
      const srcKb = Math.round(statSync(src).size / 1024);
      console.log('   built       ' + label + ': ' + before + '->' + after + ' tris, ' + srcKb + 'KB->' + kb + 'KB');
      // per-image summary: every baked texture (base/normal/MR/emissive) with its final dims + size
      for (const t of doc.getRoot().listTextures())
        {
          const sz = t.getSize();
          const img = t.getImage();
          console.log('     img ' + (t.getName() || '?') + '  ' + (sz ? sz[0] + 'x' + sz[1] : '?') + '  ' + (img ? Math.round(img.byteLength / 1024) : 0) + 'KB');
        }
      built++;
    }

  // write manifest + state back in place (like textures.py)
  writeFileSync(INFO, JSON.stringify(info, null, 2) + '\n');
  console.log('models: ' + built + ' built, ' + fresh + ' up to date');
}

// --export <label> dumps embedded textures for authoring; no arg runs the normal bake
const exportIdx = process.argv.indexOf('--export');
if (exportIdx >= 0)
  exportTextures(process.argv[exportIdx + 1]);
else
  main();

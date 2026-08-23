// offline model bake: mirror of tools/textures.py for .glb props.
// walks models-src/models.json, decimates each source to a target tri count (meshopt) and shrinks
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
const INFO = join(SRC, 'models.json');
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
      const sig = PIPELINE + '/' + target + '/' + tex + '/' + error + '/' + (hasTex ? texSrc : '-') + '/' + (hasEmi ? emiSrc + '@' + emiStrength : '-') + (e.dropMR ? '/noMR' : '') + (e.baseColor ? '/bc' + e.baseColor.join(',') : '') + (e.roughness != null ? '/rf' + e.roughness : '');
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

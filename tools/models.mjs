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

// dump the embedded textures of a source glb to models-src/ as PNGs, so an emissive map can be
// traced off the base color (mirrors the street-lamp2 base+emissive workflow). base color goes to
// <label>-base.png (a reference, not the texSrc override), other maps to <label>-<role>.png.
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
  let n = 0;
  for (const [t, suffix] of roles)
    {
      const img = t.getImage();
      if (img == null)
        continue;
      const outName = label + suffix + '.png';
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
      const out = join(OUT, label + '.glb');
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
      const hasEmi = emiPath != null && existsSync(emiPath);
      const emiStrength = e.emissiveStrength ?? info.default_emissive_strength ?? 3.0;
      // effective source mtime = newest of the glb and any override PNG, so editing any rebuilds
      const srcMtime = Math.max(
        Math.floor(statSync(src).mtimeMs / 1000),
        hasTex ? Math.floor(statSync(texPath).mtimeMs / 1000) : 0,
        hasEmi ? Math.floor(statSync(emiPath).mtimeMs / 1000) : 0,
      );
      // skip if the output exists, no input is newer, AND the bake params are unchanged —
      // so editing tris/tex/error/maps rebuilds without a manual `touch` of the source
      const sig = target + '/' + tex + '/' + error + '/' + (hasTex ? texSrc : '-') + '/' + (hasEmi ? emiSrc + '@' + emiStrength : '-') + (e.dropMR ? '/noMR' : '');
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

// offline model bake: mirror of tools/textures.py for .glb props.
// walks models-src/models.json, decimates each source to a target tri count (meshopt) and shrinks
// its embedded texture, writes a self-contained optimized glb into parasite/resources/app/models/.
// models.json is both manifest and cache: a per-entry last_converted stamp drives the mtime-skip.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, KHRMaterialsEmissiveStrength } from '@gltf-transform/extensions';
import { weld, simplify, textureCompress, prune, dedup } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
import { readFileSync, writeFileSync, existsSync, statSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'models-src');
const OUT = join(ROOT, 'parasite/resources/app/models');
const INFO = join(SRC, 'models.json');

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

async function main()
{
  if (!existsSync(INFO))
    {
      console.error('missing ' + INFO);
      process.exit(1);
    }
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
      const sig = target + '/' + tex + '/' + error + '/' + (hasTex ? texSrc : '-') + '/' + (hasEmi ? emiSrc + '@' + emiStrength : '-');
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
      // decimate only when the target is below the source count; otherwise leave the geometry (and
      // its authored normals/hard edges) untouched — meshopt would keep hi-poly normals that mismatch
      // a coarser surface. always shrink the texture + clean up
      const steps = [];
      if (before > target)
        steps.push(weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error }));
      else
        console.log('     geometry kept full (' + before + ' tris, target ' + target + ')');
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

main();

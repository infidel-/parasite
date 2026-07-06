// offline model bake: mirror of tools/textures.py for .glb props.
// walks models-src/models.json, decimates each source to a target tri count (meshopt) and shrinks
// its embedded texture, writes a self-contained optimized glb into parasite/resources/app/models/.
// models.json is both manifest and cache: a per-entry last_converted stamp drives the mtime-skip.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
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
      // mtime-skip: whole-second source mtime vs the recorded last_converted
      const srcMtime = Math.floor(statSync(src).mtimeMs / 1000);
      const last = e.last_converted != null ? Math.floor(Date.parse(e.last_converted) / 1000) : null;
      if (existsSync(out) && last != null && srcMtime <= last)
        {
          console.log('   up to date  ' + label);
          fresh++;
          continue;
        }

      const doc = await io.read(src);
      const before = countTris(doc);
      const target = e.tris ?? defaultTris;
      const tex = e.tex ?? defaultTex;
      const ratio = Math.min(1, target / Math.max(before, 1));
      // weld first (simplify needs shared vertices), decimate toward target, shrink texture, clean up
      await doc.transform(
        weld(),
        simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.01 }),
        textureCompress({ encoder: sharp, resize: [tex, tex], targetFormat: 'png' }),
        prune(),
        dedup(),
      );
      await io.write(out, doc);
      // UTC stamp (keep the Z) so the re-read compares in the same timezone as srcMtime's epoch
      e.last_converted = new Date(srcMtime * 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
      const after = countTris(doc);
      const kb = Math.round(statSync(out).size / 1024);
      const srcKb = Math.round(statSync(src).size / 1024);
      console.log('   built       ' + label + ': ' + before + '->' + after + ' tris, ' + srcKb + 'KB->' + kb + 'KB');
      built++;
    }

  // write manifest + state back in place (like textures.py)
  writeFileSync(INFO, JSON.stringify(info, null, 2) + '\n');
  console.log('models: ' + built + ' built, ' + fresh + ' up to date');
}

main();

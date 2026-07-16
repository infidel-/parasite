// bundle tools/three-entry.js into electron/three.global.js as a global `var THREE = (...)()`.
// this is the ONLY way to rebuild the previously-opaque vendored three bundle; run via `make three`.
// writes to a temp file, verifies the expected THREE.* surface survived, then swaps it in.
import * as esbuild from 'esbuild';
import { readFileSync, renameSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'electron/three.global.js');
const TMP = OUT + '.new';
// symbols the game reaches as THREE.* (Haxe externs); build fails if any go missing
const REQUIRED = ['EffectComposer', 'RenderPass', 'UnrealBloomPass', 'GTAOPass', 'OutputPass', 'ShaderPass', 'GLTFLoader'];

await esbuild.build({
  entryPoints: [join(ROOT, 'tools/three-entry.js')],
  bundle: true,
  format: 'iife',
  globalName: 'THREE',
  outfile: TMP,
  legalComments: 'none',
});

const src = readFileSync(TMP, 'utf8');
const missing = REQUIRED.filter(s => !src.includes(s));
if (missing.length)
  {
    console.error('build-three: missing symbols ' + missing.join(', ') + ' — NOT swapping');
    process.exit(1);
  }
renameSync(TMP, OUT);
console.log('three.global.js rebuilt: ' + Math.round(statSync(OUT).size / 1024) + 'KB, all required symbols present');

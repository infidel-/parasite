// headless runner for area generation (bin/genrun.js, built by src/project_gen.hxml)
//
// usage: node tools/genrun.mjs [--type facility] [--seed N] [--count N] [--print]
//   or:  make gen
//
// WHY THE STUBS BELOW EXIST. The compiled bundle is one file and its CLASS-STATIC INITIALIZERS all
// run at import, whatever the entry point reaches — `render_Gizmo.fwd = new THREE.Vector3()` fires
// on load even under -dce full, because Const alone transitively references the render tree. None of
// that code is CALLED here; it just has to survive being defined. A bottomless proxy is enough and
// is the whole of the shim.
//
// what is NOT stubbed, deliberately: game.Game. Constructing one reaches ui.UI -> MainMenu ->
// MainMenuGL.initTextures -> `new Image()` and WebGL, and stubbing down that path would wire the
// generator's test suite to the UI. The generator is written against gen._GenCtx instead and never
// sees a Game — see src/gen/GenRun.hx.

import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

// returns itself for any property, call or construction, so a static initializer can chain as deep
// as it likes and still get something back
const stub = new Proxy(function () {}, {
  get: (t, k) => {
    if (k === Symbol.toPrimitive) return () => 0;
    // a thenable would make `await import()` hang on it
    if (k === 'then') return undefined;
    return stub;
  },
  apply: () => stub,
  construct: () => stub,
  set: () => true,
  has: () => true,
});

globalThis.THREE = stub;
globalThis.document = stub;
globalThis.localStorage = stub;
globalThis.host = stub;
globalThis.Image = function () { return stub; };
// window falls through to node's real globals where they exist (console, Math, setTimeout) and to
// the stub where they do not (addEventListener, host, ...)
globalThis.window = new Proxy(globalThis, {
  get: (t, k) => (k in t ? t[k] : stub),
  set: (t, k, v) => { t[k] = v; return true; },
  has: () => true,
});

const here = dirname(fileURLToPath(import.meta.url));
const bundle = resolve(here, '..', 'bin', 'genrun.js');
createRequire(import.meta.url)(bundle);

// headless runner for the game tests (bin/test.js, built by src/project_test.hxml)
//
// usage: node tools/test.mjs [--suite smoke] [--seed N] [--count N] [--steps N] ...
//   or:  make test   /   cd src && make (runs the quick smoke)
//
// THE SHIM. This runs the REAL game: Game, UI, GameScene, render.View, Sounds and Images are all
// constructed and called. Only the LEAF browser APIs underneath them are stubbed — THREE, the DOM,
// WebAudio — with the bottomless proxy tools/genrun.mjs uses. That split is the whole design: a
// stubbed game.scene or game.ui would hand logic a truthy proxy wherever it reads a value back
// (view3d.liftDepart, the play* booleans, scene.images job data), and logic would silently take
// the wrong branch. Read-backs from real Haxe objects are real; render.View is never shown, so its
// `running` stays false and every play* call answers "not handled" exactly as it does off-3D.
//
// what is NOT a bottomless proxy, and why each one has to be real:
//   - the canvas: its width/height size AreaGame.getViewRect, and 0/0 is a NaN rect that spawns
//     nothing and mutes every sound
//   - window.host: Config/Profile/Loader/Saver read real strings off it; a proxy there parses as
//     garbage. saves live in an in-memory slot map the tests read back
//   - Math.random: seeded (mulberry32), reseeded per run through globalThis.__seed, so a seed is a
//     replayable game — Std.random compiles to Math.random
//   - fetch: never resolves, like a texture that never finished loading. a real node fetch on a
//     relative url rejects, and an unhandled rejection kills node
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { gunzipSync } from 'node:zlib';
import { readFileSync } from 'node:fs';

// returns itself for any property, call or construction; `then` answers with a function that never
// calls back, so a promise chained off a stub stays pending instead of throwing
const stub = new Proxy(function () {}, {
  get: (t, k) => {
    if (k === Symbol.toPrimitive) return () => 0;
    if (k === Symbol.iterator) return function* () {};
    if (k === 'then') return () => stub;
    // a stub element has no children, or `while (el.firstChild != null) el.removeChild(...)`
    // (ActionsHud, GoalsHud) never ends
    if (k === 'firstChild') return null;
    return stub;
  },
  apply: () => stub,
  construct: () => stub,
  set: () => true,
  has: () => true,
});

// an object whose own fields are real and whose every other field is the stub
const over = (o) => new Proxy(o, {
  get: (t, k) => (k in t ? t[k] : stub),
  set: (t, k, v) => { t[k] = v; return true; },
  has: () => true,
});

// seeded Math.random
let rngState = 1;
Math.random = () => {
  rngState = (rngState + 0x6D2B79F5) | 0;
  let t = rngState;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
globalThis.__seed = (n) => { rngState = n | 0; };

const canvas = over({ id: 'canvas', width: 1920, height: 1080 });

// in-memory host: save slots, a log sink that counts the alerts UI.onError writes through it
const saves = new Map();
const metas = new Map();
const host = {
  platform: 'linux',
  isDebug: true,
  settings: { read: () => null, write: () => true },
  profile: { read: () => null, write: () => true, exists: () => false },
  save: {
    read: (s) => saves.get(s) ?? null,
    write: (s, d) => { saves.set(s, d); return true; },
    exists: (s) => saves.has(s),
    readMeta: (s) => metas.get(s) ?? null,
    writeMeta: (s, d) => { metas.set(s, d); return true; },
    delete: (s) => { saves.delete(s); metas.delete(s); return true; },
  },
  lang: () => ({ code: 'en', available: ['en'], json: null }),
  consoleHistory: { read: () => null, write: () => true, exists: () => false },
  log: { append: (line) => { host.alerts.push(String(line)); return true; } },
  assets: { listSounds: () => [] },
  mods: { list: () => [], rescan: () => [], openFolder: () => {} },
  shell: { openExternal: () => {} },
  debug: { writeRegionRoads: () => {}, writeRegionBuildings: () => {}, writeImage: () => {} },
  quit: () => {},
  reload: () => {},
  onFocusChange: () => {},
  // test side: every line UI.onError forwarded, and a gzipped fixture loaded into a slot
  alerts: [],
  loadFixture: (slot, path) => {
    saves.set(slot, gunzipSync(readFileSync(path)).toString('utf8'));
    return true;
  },
};

globalThis.THREE = stub;
globalThis.Image = function () { return stub; };
// the bare DOM classes the bundle names (casts, constructors); node has Event of its own
globalThis.HTMLInputElement = stub;
globalThis.MouseEvent = stub;
globalThis.ResizeObserver = stub;
// the one other extern library (soundmanager2); its onready never fires, so Sounds stays unready
globalThis.SoundManager = stub;
globalThis.localStorage = stub;
globalThis.host = host;
globalThis.fetch = () => new Promise(() => {});
globalThis.requestAnimationFrame = () => 0;
// the game clock (GameScene's setInterval(game.update)) is driven by the tests, not by time
globalThis.setInterval = () => 0;
globalThis.document = over({
  getElementById: (id) => (id === 'canvas' ? canvas : stub),
});
// window falls through to node's real globals where they exist and to the stub where they do not
globalThis.window = new Proxy(globalThis, {
  get: (t, k) => (k in t ? t[k] : stub),
  set: (t, k, v) => { t[k] = v; return true; },
  has: () => true,
});
process.on('unhandledRejection', (e) => host.alerts.push('unhandled rejection: ' + (e && e.stack || e)));

const here = dirname(fileURLToPath(import.meta.url));
createRequire(import.meta.url)(resolve(here, '..', 'bin', 'test.js'));

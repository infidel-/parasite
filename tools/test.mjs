// headless runner for the game tests (bin/test.js, built by src/project_test.hxml)
//
// usage: node tools/test.mjs [--quick] [--suite all|smoke|fuzz] [--start s1,s2] [--seed N]
//                            [--count N] [--steps N] [--trace]
//        node tools/test.mjs --run <id>        one run, as a failure's replay line prints it
//   or:  make test [args="..."]   /   cd src && make (runs --quick)
//
// TWO ROLES. Without --run this is the PARENT: it asks bin/test.js for the suite's run ids
// (--plan), spawns one child process per id, pools them over the cores and prints the summary. With
// --run it is a CHILD: it installs the shim below and loads bin/test.js, which plays that one run.
// A process per run is the point — see the header of src/test/Headless.hx.
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
//   - Math.random: seeded, fixed while the bundle loads and reseeded per run by test.Bot.seed, so a
//     seed is a replayable game — Std.random compiles to Math.random
//   - fetch: never resolves, like a texture that never finished loading. a real node fetch on a
//     relative url rejects, and an unhandled rejection kills node
import { spawn } from 'node:child_process';
import { availableParallelism } from 'node:os';
import { createRequire, register } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { gunzipSync, gzipSync } from 'node:zlib';
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const self = fileURLToPath(import.meta.url);
const args = process.argv.slice(2);

// run this script again as a child with extra args; resolves to its exit code and output
const child = (extra) => new Promise((done) => {
  const p = spawn(process.execPath, [self, ...args, ...extra]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});

// the parent: plan, run every id in its own process, report. exit codes from src/test/Headless.hx
// (0 ok, 1 failed, 3 known failure, 2 bad arguments)
if (!args.includes('--run') && !args.includes('--plan')) {
  const t0 = Date.now();
  const planned = await child(['--plan']);
  if (planned.code != 0) {
    process.stdout.write(planned.out);
    process.exit(planned.code);
  }
  const ids = JSON.parse(planned.out.trim().split('\n').pop());
  const results = new Array(ids.length);
  let next = 0;
  const worker = async () => {
    while (next < ids.length) {
      const i = next++;
      let r = await child(['--run', ids[i]]);
      // a language run's English twin: the same play must save the same, apart from the log
      const lh = /^@lochash (\S+)$/m.exec(r.out);
      if (lh) {
        const twin = ids[i].replace(/^loc:[^:]+:/, 'loc:en:');
        const t = await child(['--run', twin]);
        const th = /^@lochash (\S+)$/m.exec(t.out);
        if (t.code != 0 || !th || th[1] != lh[1])
          r = { code: 1, out: r.out + ids[i] + ': its save differs from the English twin ' + twin + "'s, apart from the log" +
            (t.code != 0 ? ' (the twin exited ' + t.code + ')' : '') + '\n    both saves: tests/out/' +
            ids[i].replaceAll(':', '-').replaceAll('/', '-') + '.json.gz, tests/out/' + twin.replaceAll(':', '-').replaceAll('/', '-') + '.json.gz\n' +
            t.out };
      }
      // a continue run's second half, in a fresh process of its own
      if (/^@resume$/m.test(r.out)) {
        const b = await child(['--run', ids[i], '--resume']);
        r = { code: b.code, out: r.out + b.out };
      }
      // a failure is played again in a fresh process, stopped the step before, for its save
      const at = /^@fail (\d+)$/m.exec(r.out);
      if (at && +at[1] > 0)
        r.out += (await child(['--run', ids[i], '--stop', at[1]])).out;
      results[i] = r;
    }
  };
  await Promise.all(Array.from({ length: Math.min(availableParallelism(), ids.length) }, worker));
  let failed = 0;
  let known = 0;
  // each run's slowest bot step (`@slow <ms> <where>`): the soak lists the worst five
  const slow = [];
  // the goal runs (tutorial, timeline, endgame, cult): per kind, how many reached their goal (exit 0, else stalled:
  // exit 4), and each milestone of the chain on the way, with the turns it took (`@reach <goal> <turn>`)
  const tally = new Map();
  for (let i = 0; i < ids.length; i++) {
    const r = results[i];
    // a timeline run that learned event 11 by console is tallied apart: its PROGRESS_TIMELINE is given
    const kind = ids[i].split(':')[0] + (ids[i].includes('+learn_event_11') ? '+11' : '');
    if (kind == 'tutorial' ||
        kind == 'timeline' ||
        kind == 'timeline+11' ||
        kind == 'endgame' ||
        kind == 'cult') {
      if (!tally.has(kind))
        tally.set(kind, { runs: 0, goals: 0, milestones: [], reachedBy: new Map() });
      const t = tally.get(kind);
      t.runs++;
      if (r.code == 0)
        t.goals++;
      const order = /^@milestones (\S+)$/m.exec(r.out);
      if (order)
        t.milestones = order[1].split(',');
      for (const [, g, turn] of r.out.matchAll(/^@reach (\S+) (\d+)$/gm)) {
        if (!t.reachedBy.has(g))
          t.reachedBy.set(g, []);
        t.reachedBy.get(g).push(+turn);
      }
    }
    for (const [, n, some] of r.out.matchAll(/^@locmiss (\d+) ?(.*)$/gm))
      if (+n > 0 && !args.includes('--quick'))
        console.log('[test] ' + ids[i] + ': ' + n + ' strings with no translation met in play' + (some ? ': ' + some : ''));
    for (const [, ms, where] of r.out.matchAll(/^@slow (\d+) (.*)$/gm))
      slow.push({ ms: +ms, line: ids[i] + ' ' + where });
    if (r.code == 0)
      continue;
    if (r.code == 3) known++;
    else if (r.code != 4) failed++;
    // the quick cut (every build) counts its known failures and stalls without listing them
    if ((r.code != 3 && r.code != 4) || !args.includes('--quick'))
      process.stdout.write(r.out.split('\n').filter((l) => !l.startsWith('@')).join('\n'));
  }
  if (!args.includes('--quick'))
    for (const x of slow.sort((a, b) => b.ms - a.ms).slice(0, 5))
      console.log('[test] slow step ' + x.ms + ' ms: ' + x.line);
  // no bot step may take longer than SLOW_MS: about three times the worst measured (2026-11-07, 450 ms,
  // the first entry into an old save's city area, which migrates its grid)
  const SLOW_MS = 1500;
  const tooSlow = slow.filter((x) => x.ms > SLOW_MS);
  for (const x of tooSlow)
    console.log('[test] TOO SLOW: step ' + x.ms + ' ms > ' + SLOW_MS + ': ' + x.line);
  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  console.log('[test] ' + ids.length + ' runs, ' + failed + ' failed, ' + known + ' known (' + secs + ' s)' +
    (known > 0 ? ' — known failures are filed in tests/known.json' : ''));
  // a goal suite passes when enough runs reach each gated milestone, not all of them: --reach
  // GOAL=N,... is the minimum number of runs per milestone (GOAL_ / SCENARIO_ALIEN_ dropped). The
  // defaults are one run each, under what the bots measured (2026-11-07; the quick cut's 5 seeds:
  // TRAVEL_EVENT 2; the soak's 40: LEARN_NPC 9, CREATE_HABITAT 16, USE_COMPUTER 6; the timeline's
  // 20: PROGRESS_TIMELINE 3; the endgame's 40: FINISH 5): low enough for the bots' own deaths, high
  // enough that a broken step in the chain, which nothing gets past, fails. Raise them as the bots
  // improve. `kind:GOAL=N` counts that kind's runs alone (the tutorial's chain has PROGRESS_TIMELINE
  // too, and the timeline+11 runs are given it)
  const ri = args.indexOf('--reach');
  const spec = (ri >= 0 ? args[ri + 1] :
    (args.includes('--quick') ? 'TRAVEL_EVENT=1' :
      'LEARN_NPC=1,CREATE_HABITAT=1,USE_COMPUTER=1,timeline:PROGRESS_TIMELINE=1,FINISH=1,PROFANE_DONE=1'));
  const shortName = (g) => g.replace(/^GOAL_|^SCENARIO_ALIEN_/, '');
  for (const [kind, t] of tally) {
    // the milestone table is the soak's; every build's quick cut prints only the verdict
    for (const g of (args.includes('--quick') ? [] : t.milestones.filter((m) => t.reachedBy.has(m)))) {
      const turns = t.reachedBy.get(g);
      turns.sort((a, b) => a - b);
      console.log('[test]   ' + shortName(g).padEnd(27) + ' ' + String(turns.length).padStart(3) + '/' + t.runs +
        ', turns min ' + turns[0] + ' / median ' + turns[turns.length >> 1] + ' / max ' + turns[turns.length - 1]);
    }
    console.log('[test] ' + kind + ': ' + t.goals + '/' + t.runs + ' reached the goal');
  }
  // each gate counts the runs of the kind whose chain has that milestone; a gate no kind in this
  // suite has is skipped (a --suite or --start that leaves its kind out)
  const short = [];
  for (const [name, n] of spec.split(',').filter((x) => x.length > 0).map((x) => x.split('='))) {
    const [k, g] = (name.includes(':') ? name.split(':') : [null, name]);
    const t = (k != null ? tally.get(k) : [...tally.values()].find((x) => x.milestones.some((m) => shortName(m) == g)));
    if (t == null)
      continue;
    const got = [...t.reachedBy.entries()].filter(([m]) => shortName(m) == g).reduce((a, [, v]) => a + v.length, 0);
    if (got < +n)
      short.push(name + ' ' + got + ' < ' + n);
  }
  const low = short.length > 0;
  if (tally.size > 0)
    console.log('[test] gates ' + spec + (low ? ' — TOO FEW: ' + short.join(', ') : ' met'));
  process.exit(failed > 0 || low || tooSlow.length > 0 ? 1 : 0);
}

// the report goes out through __out; the game's own console chatter (debug dumps, [mods] lines) is
// dropped unless --trace, which also keeps its haxe traces (test.Headless)
globalThis.__out = console.log.bind(console);
if (!process.argv.includes('--trace'))
  console.log = console.info = console.debug = console.warn = console.group = console.groupEnd = () => {};

// the mp3s under app/sound, as electron's main process lists them for Sounds (MainElectron
// listSoundFiles): an empty list logs "Sound [x] not found" on every play. sorted, because readdir
// order is the filesystem's and Sounds picks variants off this list
const listSounds = (dir, prefix) => {
  let out = [];
  let names;
  try { names = readdirSync(dir).sort(); } catch (e) { return out; }
  for (const name of names) {
    const rel = prefix.length == 0 ? name : prefix + '/' + name;
    if (name.endsWith('.mp3')) out.push(rel);
    else if (name.indexOf('.') < 0 && statSync(resolve(dir, name)).isDirectory())
      out = out.concat(listSounds(resolve(dir, name), rel));
  }
  return out;
};

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

// a fixed Math.random while the bundle loads, so any static initializer that rolls rolls the same;
// each run then reseeds it itself (test.Bot.seed, with gen.Rng's mulberry32)
let rngState = 1;
Math.random = () => {
  rngState = (rngState + 0x6D2B79F5) | 0;
  let t = rngState;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

const canvas = over({ id: 'canvas', width: 1920, height: 1080 });

// the mods a fixture was saved with (its _activeMods), as MainElectron's scan describes them, from
// the dev install's parasite/dev (the examples' `make` installs them there). a new game or a preset
// runs with none. a mod not installed is left out, and the load says so the way the game does
const modInfos = () => {
  const run = args[args.indexOf('--run') + 1] ?? '';
  const f = run.split(':');
  const start = ((f[0] == 'loc' ? f[2] : f[1]) ?? '').split('+')[0];
  // the `mods` start: a new game with every mod installed
  const ids = (start == 'mods' ? readdirSync(resolve(root, 'parasite', 'dev')).sort().map((id) => ({ id })) :
    start.startsWith('save/') ?
      JSON.parse(gunzipSync(readFileSync(resolve(root, 'tests', 'saves', start.substr(5)))))._activeMods ?? [] : []);
  const out = [];
  for (const { id } of ids) {
    const rootDir = resolve(root, 'parasite', 'dev', id);
    if (!existsSync(resolve(rootDir, 'manifest.json')))
      continue;
    const m = JSON.parse(readFileSync(resolve(rootDir, 'manifest.json'), 'utf8'));
    out.push({ ...m, name: m.name ?? m.id, author: m.author ?? '', rootDir, source: 'sideload-dev', assets: [],
      hasModCss: existsSync(resolve(rootDir, 'mod.css')) });
  }
  return out;
};
const mods = modInfos();

// ModLoader imports each mod's entry from mod://<id>/<file>, which electron's protocol handler serves;
// a loader hook serves it here. the entry is a plain Haxe script, so as a module it sees no `exports`
// and @:expose puts its class on window, the contract ModLoader reads
register('data:text/javascript,' + encodeURIComponent(`
import { readFileSync } from 'node:fs';
let roots = {};
export function initialize(data) { roots = data; }
export function resolve(spec, ctx, next) {
  return spec.startsWith('mod://') ? { url: spec, shortCircuit: true } : next(spec, ctx);
}
export function load(url, ctx, next) {
  if (!url.startsWith('mod://'))
    return next(url, ctx);
  const [id, ...rest] = url.substr(6).split('/');
  return { format: 'module', source: readFileSync(roots[id] + '/' + rest.join('/'), 'utf8'), shortCircuit: true };
}
`), { data: Object.fromEntries(mods.map((m) => [m.id, m.rootDir])) });

// in-memory host: save slots, a log sink that counts the alerts UI.onError writes through it
const saves = new Map();
const metas = new Map();
const host = {
  platform: 'linux',
  isDebug: true,
  settings: { read: () => null, write: () => true },
  // a continue run's second half plays with the first half's profile (profileText)
  profile: { read: () => host.profileText ?? null, write: () => true, exists: () => host.profileText != null },
  save: {
    read: (s) => saves.get(s) ?? null,
    write: (s, d) => { saves.set(s, d); return true; },
    exists: (s) => saves.has(s),
    readMeta: (s) => metas.get(s) ?? null,
    writeMeta: (s, d) => { metas.set(s, d); return true; },
    delete: (s) => { saves.delete(s); metas.delete(s); return true; },
  },
  // a loc run's language (loc:<code>:...): fr from the shipped electron/lang, pseudo from Loc itself
  lang: () => {
    const run = args[args.indexOf('--run') + 1] ?? '';
    const code = run.startsWith('loc:') ? run.split(':')[1] : 'en';
    return { code, available: ['en', code],
      json: code == 'fr' ? readFileSync(resolve(root, 'electron', 'lang', 'fr.json'), 'utf8') : null };
  },
  consoleHistory: { read: () => null, write: () => true, exists: () => false },
  // testmod registers `bad*` ids on purpose, to see them rejected (examples/testmod)
  log: { append: (line) => {
    if (!/^MOD REGISTER REJECT \[testmod\] .*id "bad/.test(String(line)))
      host.alerts.push(String(line));
    return true;
  } },
  assets: { listSounds: () => listSounds(resolve(root, 'app', 'sound'), '') },
  mods: { list: () => mods, rescan: () => mods, openFolder: () => {} },
  shell: { openExternal: () => {} },
  debug: { writeRegionRoads: () => {}, writeRegionBuildings: () => {}, writeImage: () => {} },
  quit: () => {},
  reload: () => {},
  onFocusChange: () => {},
  // test side: every line UI.onError forwarded, the failures already filed (tests/known.json, id
  // -> where it is filed), a gzipped fixture loaded into a slot, and a gzipped file written out
  alerts: [],
  known: [],
  loadFixture: (slot, path) => {
    saves.set(slot, gunzipSync(readFileSync(resolve(root, path))).toString('utf8'));
    return true;
  },
  readOut: (name) => gunzipSync(readFileSync(resolve(root, 'tests', 'out', name))).toString('utf8'),
  writeOut: (name, data) => {
    mkdirSync(resolve(root, 'tests', 'out'), { recursive: true });
    writeFileSync(resolve(root, 'tests', 'out', name), gzipSync(data));
    return true;
  },
};
// the fixture saves under tests/saves, which the compat and roundtrip suites load
host.fixtures = readdirSync(resolve(root, 'tests', 'saves')).filter((f) => f.endsWith('.json.gz')).sort();
const knownPath = resolve(root, 'tests', 'known.json');
if (existsSync(knownPath))
  host.known = JSON.parse(readFileSync(knownPath, 'utf8'));

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
// fetch serves a mod's own files (ModLoader.loadLang reads mod://<id>/lang/<code>.json); anything
// else stays pending, as a blocked remote fetch does
globalThis.fetch = (url) => {
  if (!String(url).startsWith('mod://'))
    return new Promise(() => {});
  const [id, ...rest] = String(url).substr(6).split('/');
  const m = mods.find((x) => x.id == id);
  const file = m ? resolve(m.rootDir, ...rest) : null;
  return Promise.resolve(file && existsSync(file) ? new Response(readFileSync(file)) : new Response(null, { status: 404 }));
};
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

createRequire(import.meta.url)(resolve(root, 'bin', 'test.js'));

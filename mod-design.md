# Mod System — Design

Living doc. Review before any code lands.

> Convention: code comments do **not** need to cite paragraphs of this document (no `§9.2`-style references in source). This doc tracks design; the code stands on its own.

> **Definition of done:** any mod-facing feature is not complete until the author docs are updated too. After implementing, update (a) this design doc, (b) the SDK author guide in `parasite-mod-sdk/docs/` (the relevant `NN-*.md` + README doc index + cross-refs in `01-getting-started.md`), and (c) the curated externs under `parasite-mod-sdk/externs/` (every new field/method commented). Code + design without docs ships silent API to third parties.

---

## 1. Goals / Non-goals

**Goals**
- Mods can read and mutate any engine state (`Game.inst`, AI classes, areas, items, UI, etc.). No capability boundary.
- Mods authored in Haxe, distributed as compiled `.js` + manifest + assets.
- Two sources: Steam Workshop (curated by user subscribing) and local sideload (dev / off-Steam users).
- Boot-time load. No hot-reload in release.
- Per-mod error isolation: one bad mod logs + skips, game still boots.
- Deterministic, user-controllable load order.
- Save files record active mods + versions; mismatch warns on load.

**Non-goals**
- Sandboxing mod code. Mods are trusted (plan.md threat model: trust the author, not the content; Workshop is curated, not safe).
- Runtime capability manifests, permission prompts.
- Hot-reload during gameplay.
- Mods authored in JS-from-scratch. Toolchain assumes Haxe.
- Engine API stability across game versions in v1. Mods declare `modApiVersion` (integer); engine bumps `Const.MOD_API_VERSION` when breaking changes ship (§3.1, §3.2).

---

## 2. Threat Model

Mods run in the same JS realm as the engine, full `window`, full `window.host` (the IPC bridge). They can:
- Read/write save files via `HostBridge.save*`.
- Read/write settings, profile, console history.
- Quit the app, toggle fullscreen.
- (mydebug only) Write debug images to userData/debug.

They **cannot** (because preload doesn't expose):
- Arbitrary filesystem outside the paths above.
- `child_process`, raw network, native modules.
- Anything not in `preload.js`'s `contextBridge`.

User's risk surface is the IPC bridge cap (already validators + size caps). Mods can't escalate beyond what the engine itself can already do.

Workshop trust: Steam moderation, user discretion. Sideload trust: user explicit opt-in by dropping files.

---

## 3. Mod Anatomy

Each mod is a directory:

```
<modId>/
  manifest.json
  entry.js              # Haxe-compiled, see §9
  entry.js.map          # optional, source map
  assets/               # optional
    sprites/...
    sounds/...
```

### 3.1 Manifest

```json
{
  "id": "com.author.modname",
  "name": "Display Name",
  "author": "Author",
  "version": "1.0.0",
  "modApiVersion": 1,
  "minGameVersion": "0.x.y",
  "entry": "entry.js",
  "exportGlobal": "modname_Entry",
  "dependencies": [
    { "id": "com.other.lib", "version": ">=1.2.0" }
  ],
  "loadAfter": [ "com.other.mod" ],
  "loadBefore": [],
  "workshop": {
    "publishedFileId": null,
    "title": "Display Name",
    "description": "Long description, markdown supported.",
    "preview": "preview.png",
    "tags": ["weapons", "balance"],
    "visibility": "public",
    "changeNote": "v1.0.0 initial"
  }
}
```

- `id`: lowercase identifier with optional dot segments, regex `^[a-z0-9_]+(\.[a-z0-9_]+)*$`, 4–80 chars. Reverse-DNS recommended for distributed mods to avoid collisions; single segment (`testmod`) accepted for examples / private mods. Collisions = last-wins is bad → loader errors on duplicate id.
- `version`: semver (`major.minor.patch`).
- `modApiVersion`: integer, must equal `Const.MOD_API_VERSION` exactly. Mismatch = skip + log with explicit message (`"mod targets API v3, engine is v4"`).
- `minGameVersion`: optional, semver. Compared `>=` against `Version.getVersion()`. Used when a mod relies on a feature added in a specific patch (engine API version stayed the same but new surface area appeared). No `maxGameVersion` — upper bound is enforced by `modApiVersion`.
- `exportGlobal`: required, single-segment JS identifier (1–64 chars, `^[A-Za-z_$][A-Za-z0-9_$]*$`). Must equal the `@:expose("...")` string in the mod's `Entry.hx`. The loader calls `window[exportGlobal].init(parasite)` (§8.2). Missing/malformed = rejected at scan + logged; valid but mismatched with the source = mod loads but the lookup is `undefined` → marked failed + logged.
- `dependencies`: missing dep = skip + log. Version mismatch = skip + log.
- `loadAfter`/`loadBefore`: ordering hints feed a toposort. Cycles = skip cycle members + log.
- `workshop`: ~~optional block, consumed by publish CLI~~. **As-built the publish CLI does not read a `workshop` block** — it uses flat `name`/`description` and stores the item id in `<mod-dir>/.workshop-id` (§8.8). The block above is retained as the original spec only; the engine ignores it either way.

### 3.2 `MOD_API_VERSION` Bump Rules

Lives at `src/Const.hx`:

```haxe
public static inline var MOD_API_VERSION = 1;
```

Bumped manually by engine devs **whenever a change can break existing mods**. Rule of thumb — bump on:

- Rename, move, or remove of any class/field/method reachable from `window.parasite` (i.e. anything mods reasonably touch via prototype rewrite or property access).
- Signature change of any method mods commonly override (AI logic, FSM ticks, area generators).
- Save format change (mods may serialize state into saves; v3 already adds `_activeMods`).
- Change to `parasite` object shape (§8.1) — adding fields is **not** breaking; removing or renaming is.
- Change to `host` IPC surface signatures.

Do **not** bump for:
- Pure additions (new classes, new methods, new fields).
- Internal refactor that leaves public symbol names unchanged.
- Asset additions.
- Bugfixes that don't change call signatures.

When in doubt, bump. False bumps cost mod authors one config update; missed bumps cost users crashes.

On bump: update `Const.MOD_API_VERSION`, add a `MOD_API_CHANGES.md` entry (one line per release: `v4: renamed AI.tick → AI.update`). Mod authors read that file to update their manifests.

---

## 4. Discovery

### 4.1 Sideload

Two roots, both scanned (linux/win32 only; darwin not supported for v1):

| Source | Path |
|--------|------|
| release | `<cwd>/mods/` (next to executable) |
| dev     | `<cwd>/dev/` (always scanned, no flag needed) |

Each child dir = candidate mod. Skip if no `manifest.json`.

`<cwd>/dev/` is gitignored. Devs drop in-progress mods (or `make install` output from `examples/<modid>/`) there without polluting the user-facing `mods/`. Same load pipeline as `mods/`; no special handling.

Repo-level `examples/<modid>/` is **source only**, never scanned by the engine. Each example holds Haxe sources + Makefile that compiles and copies the built mod into `<cwd>/dev/<modid>/`. Generated `entry.js` is gitignored.

### 4.2 Workshop

Wired via **steamworks.js** in main process. Main owns the SDK; renderer never sees the native module.

API mapping (from steamworks.js `workshop.*`, mirroring ISteamUGC):

| Need | steamworks.js call | ISteamUGC equiv |
|------|-------------------|-----------------|
| List subscribed item IDs | `workshop.getSubscribedItems(): Array<bigint>` | `GetSubscribedItems` (+ `GetNumSubscribedItems`) |
| Check item ready | `workshop.state(id): number` | `GetItemState` (bitmask) |
| Get install path | `workshop.installInfo(id): { folder, sizeOnDisk, timestamp } \| null` | `GetItemInstallInfo` |
| Trigger download | `workshop.download(id, highPriority): boolean` | `DownloadItem` |
| Download progress | `workshop.downloadInfo(id): { current, total } \| null` | (DownloadItemResult_t callback) |

Item state bitmask (relevant bits):
- `k_EItemStateInstalled = 4`
- `k_EItemStateNeedsUpdate = 8`
- `k_EItemStateDownloading = 16`

Boot-time discovery flow:

```
for id in workshop.getSubscribedItems():
  st = workshop.state(id)
  if !(st & 4):                        # not installed
    workshop.download(id, false)       # async; skip this boot
    log("workshop mod <id> downloading, will load next launch")
    continue
  if st & 8:                           # installed but stale
    workshop.download(id, false)       # async; load current version anyway
  info = workshop.installInfo(id)
  if info == null: skip + log
  treat info.folder as a mod dir (same manifest.json convention as sideload)
```

Caveats:
- Items mid-download at boot are skipped this run; user relaunches after Steam finishes.
- Query result page cap (50) doesn't apply here — `getSubscribedItems` returns the full subscribed list.
- 1000-item request cap is theoretical; users won't hit it.
- Init order: `steamworks.init(appId)` must run before any workshop call. Failed init (no Steam, no app id, sandbox refused) → log, skip Workshop, sideload still works.

### 4.3 Steam Overlay & Sandbox Conflict

`steamworks.js` ships `electronEnableSteamOverlay()` — call at end of main.js to enable Steam overlay rendering. The docs' example sets `contextIsolation:false, nodeIntegration:true` for the renderer. **That is a direct regression vs. our current sandbox** (just-locked Tier 0/1 baseline).

Options, in order of preference:

1. **Empirical test**: call `electronEnableSteamOverlay()` while keeping `sandbox:true, contextIsolation:true, nodeIntegration:false`. We already pass `in-process-gpu` + `disable-direct-composition` (Steam overlay needs single GPU process to hook). May Just Work. If overlay shows + game still boots clean → ship as-is.
2. **Per-flag relaxation**: if (1) fails, try toggling only what's strictly required (e.g. drop `sandbox` but keep `contextIsolation:true` + `nodeIntegration:false`). Document the specific flag and reason.
3. **Skip overlay**: ship without `electronEnableSteamOverlay()`. Overlay broken, achievements/UGC still work (those go through main-process SDK calls). Acceptable v1 fallback.

Decision deferred to integration time. Track as v1.1 risk.

### 4.3 Order

1. Resolve all candidates (sideload + workshop).
2. Drop invalid (manifest malformed, id collision, version out-of-range, missing dep).
3. Toposort by `loadAfter`/`loadBefore`.
4. Stable secondary sort by id.

User can disable individual mods via `profile.json` — new `disabledMods: Array<String>` field holding mod ids to skip. Profile is already unified state and already shipped over `host:profile:*` IPC; no new file or IPC.

---

## 5. Load Pipeline

Boot sequence with mods:

```
main process:
  App.ready
    → ModRegistry.scan()              [enumerate dirs, parse manifests, validate]
    → register `mod://` protocol
    → BrowserWindow.loadFile('app.html')

renderer:
  Main.main()
    → Main.init()                     [canvas, Game ctor, scene init]
    → ModLoader.load(registry)        [new step, before ui.state = MAINMENU]
        for each mod (in toposorted order):
          try:
            await import(`mod://<id>/<entry>`)   # side effect: @:expose sets window[exportGlobal]
            window[mod.exportGlobal].init?.(parasite)
          catch e:
            log, mark mod failed, continue
    → ui.state = UISTATE_MAINMENU
```

Mods get the engine fully constructed but pre-gameplay. They can:
- Monkey-patch any class on the global namespace.
- Register listeners (none built yet — see §8.4).
- Add new content (v1: items) via registration API (§8.7); engine reruns registrations on every const-table init, additions survive new-game cycles. Other const tables wrapped in v1.1+.

Mods do **not** get to intercept engine boot. If they need that, they need engine cooperation (out of scope v1).

---

## 6. Custom Protocol `mod://`

### 6.1 Registration (main process)

```haxe
import electron.main.Protocol;

// in MainElectron, before window load:
Protocol.registerSchemesAsPrivileged([
  { scheme: 'mod', privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: false,
      stream: true,
    }}
]);

// after App.ready:
Protocol.handle('mod', function(req) {
  // parse: mod://<id>/<path...>
  // resolve modId → real disk path (sideload or workshop)
  // reject if id unknown, path escapes mod root, mime unknown
  return new Response(stream, { headers: { 'content-type': mime } });
});
```

Path-traversal defense: after resolving `<id>` to its absolute root, `path.resolve(root, requested)` must `startsWith(root + sep)`. Else 403.

MIME table: `.js → text/javascript`, `.json → application/json`, `.png → image/png`, `.mp3 → audio/mpeg`. Unknown extensions = 415.

### 6.2 CSP

Update `electron/app.html`:

```
script-src 'self' 'sha256-...' mod:;
img-src 'self' data: mod:;
media-src 'self' data: mod:;
font-src 'self' data: mod:;
connect-src 'self' mod:;
```

No relaxation of `default-src 'none'`, no `'unsafe-eval'`, no `'unsafe-inline'`. Just add the new scheme to existing source lists.

Mods get an inline `<script>` in `app.html` from us? No — mods load via dynamic `import('mod://...')` from `ModLoader.hx`. That's `script-src` from a dynamically-imported source, governed by `script-src` after the [Trusted Types / module rules](https://w3c.github.io/webappsec-csp/#directive-script-src) — adding `mod:` to `script-src` covers it.

---

## 7. Engine-side Pieces

New files / changes:

| File | Purpose |
|------|---------|
| `electron/preload.js` | + `mods.list()` IPC surface (returns merged sideload+workshop list with manifests + asset listings) |
| `electron/MainElectron.hx` | Register `mod://` protocol, register `host:mods:*` IPC, scan `mods/` + `dev/` on boot, log-rotation §11.1 |
| `src/HostBridge.hx` | + `modsList()` |
| `src/mods/ModRegistry.hx` | Parse `mods.list()` result, read `profile.disabledMods`, toposort, expose `enabled: Array<ModInfo>` and `byId(): Map<String, ModInfo>` |
| `src/mods/ModLoader.hx` | Boot-time `load(): Promise<Void>` — for each enabled mod: build per-mod `parasite` object, dynamic-import entry, call `init` in try/catch |
| `src/mods/ModInfo.hx` | Manifest typedef |
| `src/mods/ModSettings.hx` | Per-mod settings accessor (§8.5), reads/writes `Config.mods.<id>` subtree |
| `src/mods/AssetPath.hx` | Logical → physical path resolver (§8.6), populated by ModLoader at boot |
| `src/mods/ModContentRegistry.hx` | Registry for mod-registered content (v1: items only) (§8.7) |
| `src/mods/ModContentApi.hx` | Per-mod facade exposed as `parasite.api`, calls into registry with modId for logging (§8.7) |
| `src/const/ItemsConst.hx` | `init()` iterates `ModContentRegistry.items` after built-in `classes` (§8.7) |
| `src/Main.hx` | Add `await ModLoader.load()` before `ui.state = MAINMENU` |
| `src/Profile.hx` | + `disabledMods: Array<String>` field |
| `src/Const.hx` | + `MOD_API_VERSION: Int = 1` (bump rules §3.2) |
| `MOD_API_CHANGES.md` | Repo-root changelog of API-breaking bumps, one line per version |
| `src/Config.hx` | + `mods: Dynamic` subtree (raw bucket of mod-id → settings object) |
| `src/Images.hx` | Refactor all `img.src = '<path>'` to `img.src = AssetPath.resolve('<path>')` (~10 sites) |
| `src/Sounds.hx` | Use `ModRegistry.mergedSoundList()` + `AssetPath.resolve` for each sound |
| `src/console/Console.hx` | + `mods` subcommand: `mods list` / `mods enable <id>` / `mods disable <id>` / `mods errors` |

Main-side scan logic lives in main (Fs access). Renderer gets a serialized list via IPC. Renderer chooses load order from the list + `profile.disabledMods`.

Manifest validation (in main, before shipping to renderer): JSON.parse, schema check, dep check, version-range check. Invalid mods get logged via §11.1 and dropped from the list — renderer never sees them.

---

## 8. Mod API Surface

### 8.1 Global access

Haxe-generated JS already populates `$hxClasses` (registry of all classes by name) and `$hx_exports` (only `@:expose`-decorated classes). With `-dce no`, every class is in `$hxClasses`.

Engine exposes a stable mod-facing object at load time:

```haxe
// in ModLoader, before importing any mod:
js.Syntax.code("window.parasite = {0}", {
  game: game.Game.inst,
  hxClasses: js.Syntax.code("$hxClasses"),
  version: Version.getVersion(),
  host: js.Syntax.code("window.host"), // same bridge engine uses
  settings: ModSettings.api(modID),    // per-mod scoped (§8.5)
  assets: AssetPath,                   // path resolver (§8.6)
  api: ModContentApi.forMod(modID),    // register content (§8.7)
});
```

Mods can `window.parasite.game`, `window.parasite.hxClasses["ai.AI"]`, etc.

Note: `parasite` passed to `init(parasite)` is per-mod (the `settings` accessor is scoped to that mod's id). Loader builds a fresh object per import.

### 8.2 Mod entry contract

Haxe emits `entry.js` as a plain script (an IIFE), **not** an ES module with a named export. `@:expose("modname_Entry")` assigns the class to `window.modname_Entry` when the script runs (`$hx_exports` resolves to `window` under a browser `import()` — there is no CommonJS `exports` binding). The loader exploits that: it `import()`s the entry for its side effect, then reads the class off `window` by the manifest's `exportGlobal` name and calls `init`:

```haxe
@:expose("modname_Entry")   // MUST equal manifest.exportGlobal
class Entry {
  public static function main() {}                          // satisfies -main Entry; engine never calls it
  public static function init(p: ModRuntime): Void { /* ... */ }
}
```

```
// loader, conceptually:
await import('mod://<id>/entry.js')         // side effect: window.modname_Entry = Entry
window[manifest.exportGlobal].init(parasite)
```

This means there is **no post-compile step** — `haxe build.hxml` output loads as-is, which matters for authors on Windows without `make`/shell redirection. The only contract is `exportGlobal` == `@:expose(...)`; mismatch → `window[exportGlobal]` is `undefined` → mod marked failed + logged (loud on three surfaces: devtools `console.error`, session log, Mods UI / `mods errors`). Mod authors compile with `-D mod` so their `Main`-class is `Entry`. Build pipeline ships a template.

### 8.3 Static-class monkey-patching

Easy: `window.parasite.hxClasses["ai.AI"].prototype.someMethod = function(...) { ... }`. Standard JS prototype rewrite.

### 8.4 Event hooks

**[x] done (v1.1)** — runtime event bus shipped. Mods subscribe via `parasite.events` (`ModEvents` facade); monkey-patching still works alongside (additive, no conflict).

Pieces:
- `src/mods/ModEventRegistry.hx` — static `Map<event, Array<{modID, handler}>>`. `subscribe(event, modID, handler)` appends in load order; `fire(event, payload)` invokes each handler in a per-handler try/catch (one throwing handler logs to devtools + session log, never breaks the hook site). Empty-map early return keeps the turn-loop fire cheap.
- `src/mods/ModEvents.hx` — per-mod facade (`forMod(modID)`), one typed `on<Event>` method per event, logs each subscription. Holds the payload typedefs.
- `parasite.events` field added to `ModRuntime` (engine + SDK extern). Pure addition → no `MOD_API_VERSION` bump.

Five v1.1 events (typed payloads, all extend `ModEventBase`):

| Event | Hook site | Payload fields (beyond base) |
|-------|-----------|------------------------------|
| `turn:pre` | `Game.turnInternal()` top (before `player.turn()` + counter increment) | `turn: Int` |
| `turn:post` | `Game.turnInternal()` end (after counter; **skipped on early-return abort** — game over / transition) | `turn: Int` |
| `area:enter` | `Game.setLocation()` after `area.enter()` | `area: AreaGame` |
| `area:leave` | `Game.setLocation()` before `area.leave()` | `area: AreaGame` |
| `ai:spawn` | `AreaGame.addAI()` after `createEntity()` (funnel sink; catches `spawnAI` callers) | `ai: AI`, `area: AreaGame` |

**`ModEventBase`** (shared by every payload):

```haxe
typedef ModEventBase = {
  // the live engine game instance
  var game: Game;
}
```

Every fire site supplies `game:` directly in the payload literal (`{ game: this, turn: turns }` from `Game`, `{ game: game, ai: ai, area: this }` from `AreaGame`). `ModEventRegistry.fire()` passes the payload through unchanged — no per-subscriber clone, no map lookup. Handlers read `e.game` without closing over the `parasite` parameter from `init()`, which lets mods use static methods as handlers (the closure-vs-method tradeoff).

Mods that also need their `ModRuntime` (for `settings`/`api`/`host`) inside a static handler stash it on a static field at init:

```haxe
class Mod {
  static var P: ModRuntime;
  public static function init(parasite: ModRuntime) {
    P = parasite;
    parasite.events.onTurnPost(onTurn);
  }
  static function onTurn(e: ModTurnEvent) { /* e.game ... P.settings ... */ }
}
```

No unsubscribe API (mods can't reload mid-session — matches §8.7 no-removal). Event names are engine-defined; mods subscribe only, can't define custom events in v1.1 (see §13 open question). Bus is runtime-only — no persisted state, no save-format change.

### 8.5 Per-mod Settings

Mods get persistent key/value storage namespaced by mod id, backed by `settings.json` (existing IPC).

Layout in `settings.json`:

```json
{
  "fullscreen": "1",
  "mods": {
    "com.author.modname": {
      "difficulty": "hard",
      "showOverlay": true
    },
    "com.other.mod": { ... }
  }
}
```

API surface (Haxe externs in SDK):

```haxe
extern class ModSettings {
  function get(key: String): Dynamic;        // returns null if unset
  function set(key: String, value: Dynamic): Void;
  function remove(key: String): Void;
  function all(): Dynamic;                   // shallow copy of this mod's bucket
}
```

Engine impl: `ModSettings.api(modId)` returns a thin wrapper that reads/writes the global `Config` object's `mods.<id>` subtree, then triggers existing save-on-change. No new IPC.

Total `settings.json` cap stays at 256 KiB (existing). Mods sharing one file means a runaway mod can exhaust it; per-mod soft cap of 16 KiB enforced in setter (rejects with thrown error). Out-of-scope: per-mod arbitrary-blob storage. Mods needing more should be redesigned to store state in saves.

### 8.6 Asset Overrides

Mods may replace engine assets (images, sounds, music) by shipping a file at the same logical path.

Convention: mod's `assets/<category>/<name>` shadows engine's `<category>/<name>`.

| Engine path | Mod override path |
|-------------|-------------------|
| `img/entities64.png` | `<mod>/assets/img/entities64.png` |
| `sound/ai-arrive-police.mp3` | `<mod>/assets/sound/ai-arrive-police.mp3` |
| `music/menu.mp3` | `<mod>/assets/music/menu.mp3` |

Conflict resolution: last-mod-wins per file (load order from §4.3). Engine logs each override at boot so users see what got replaced.

**Resolver**:

```haxe
class AssetPath {
  // returns engine path or mod:// URL if overridden
  public static function resolve(logical: String): String;
}
```

`ModLoader` walks each mod's `assets/` dir at boot, builds `Map<String, String>` of logical → `mod://<id>/assets/<path>`. `AssetPath.resolve` consults the map; unmatched → returns `logical` unchanged.

**Call-site refactor** (engine):
- `Images.hx`: `img.src = 'img/entities64.png'` → `img.src = AssetPath.resolve('img/entities64.png')`. ~10 sites.
- `Sounds.hx`: sound URLs constructed from `HostBridge.listSounds()`. Replace listing with merged engine+mods listing; resolve each sound name through `AssetPath`.
- Music: same as sounds.

**Sound listing change**: `host:assets:listSounds` returns engine list only. Add `ModRegistry.mergedSoundList()` that overlays mod-provided `assets/sound/*` filenames. Mod loader populates after scan.

CSP: already permits `mod:` in `img-src`, `media-src` (§6.2). No further change.

### 8.7 Registration API (content additions)

**Why**: const tables like `ItemsConst` re-init on every `Game.new()` and on `console/Add.hx:121`. `init()` wipes the derived map (`infos`) and rebuilds from a source list (`classes`). Mods that mutate the derived map silently lose changes after a second new-game. Pushing onto `classes` directly works but couples mods to internal field names — any engine refactor breaks them.

**Solution**: mods don't touch const tables. They call a registration API. Engine's `init()` consults built-in + registered lists every time. Idempotent by construction.

**v1 scope: items only.** Other const tables follow same pattern in v1.1+ (audit list below).

Registry (renderer):

```haxe
class ModContentRegistry {
  public static var items: Array<Class<ItemInfo>> = [];
}
```

Mod-facing API (per-mod `parasite.api`):

```haxe
extern class ModContentApi {
  function registerItem(cls: Class<ItemInfo>): Void;
}
```

Engine `ItemsConst.init` change:

```haxe
public static function init(game: Game) {
  infos = new StringMap();
  for (cls in classes)                   addInfo(game, cls);
  for (cls in ModContentRegistry.items)  addInfo(game, cls);
}
static inline function addInfo(game, cls) {
  var info = Type.createInstance(cls, [game]);
  if (infos.exists(info.id))
    Const.p('mod content collision on item id: ' + info.id + ' (last-wins)');
  infos.set(info.id, info);
}
```

Collisions: last-wins, logged at every init so devs/users see the conflict at boot, not later. Registration is also logged once at boot (`registered item: <modId>/<itemId>`).

No removal API in v1. No reordering API. Mods can't unregister content. If a user wants to undo a mod's items, they disable the mod (§4).

**Not a wall — convention only.** Per §2's trusted-mod model, mods can still reach `const_ItemsConst.classes` (or `parasite.hxClasses["const.ItemsConst"]`) directly and mutate freely. `-dce no` keeps every symbol alive. We're not enforcing — JS realm is open. Matrix of what survives engine re-init:

| Path | Survives re-init? | Use when |
|------|------|------|
| `parasite.api.registerItem(MyItem)` | ✅ | adding new content (**recommended**) |
| Push to `const_ItemsConst.classes` directly | ✅ | same, but couples to internal field name → fragile |
| Mutate `infos["pistol"]` instance | ❌ | never; lost on re-init |
| Replace `classes[0] = MyHandgun` | ✅ | overriding built-in item id (no registration API for replace yet) |
| Monkey-patch `ItemHandgun.prototype.fire` | ✅ | changing built-in behavior (not registration API's job) |

SDK README documents the recommended path. Optional cheap detection: warn at boot if `infos.size` changes between init calls without a matching registration delta — flags mods quietly mutating the derived map.

### 8.7.1 v1.1+ Tables to Wrap

Note: This table is WIP, needs review and more thinking about capabilities and actual setup.

Audit pass over `src/const/`:

| Table | Shape | API call | Notes |
|-------|-------|----------|-------|
| `EvolutionConst.improvements` | `Array<ImprovInfo>` | `registerEvolution(info)` | **[x] done (Phase B3)** — `_Improv` converted to `enum abstract _Improv(String) to String from String`; builtin IMP_* constants kept for engine code, mods register plain string ids. The 4 `Type.createEnum(_Improv, …)` sites (Organs, EvolutionManager) and 2 `Type.allEnums(_Improv)` console sites rewritten to string casts / list iteration. `EvolutionConst.addImprovement(info)` appends live. SDK externs: `_Improv`, `_ImprovType`, `_OrganInfo`, `_ImprovInfo`. |
| `Goals.map` | `Map<_Goal, GoalInfo>` | `registerGoal(info)` | **[x] done (Phase B4)** — `_Goal` converted to `enum abstract _Goal(String) to String from String`; builtin GOAL_*/SCENARIO_* constants kept for engine code, mods register plain string ids. No `Type.createEnum`/`allEnums(_Goal)` reflection sites existed; `Map<_Goal,…>` literals (`const.Goals.map`, scenario maps) auto-resolve to StringMap. Loader migrates legacy `{_classID:"_Goal",val}` save wrappers to bare strings (shared shim, gated `formatVersion < 3`). `Goals.addGoal(info)` appends live (map built once, never wiped). SDK externs: `_Goal`, `_GoalInfo`. |
| `Jobs` | instance, `new Jobs(g)` | `registerJob(info)` via post-ctor hook | Deferred (later stage). Different shape — needs engine to expose a `Jobs.addJob` then call mod registry after `new`. |
| `PediaConst.contents` | `Array<_PediaGroupInfo>` | `registerPediaEntry(info)` | **[x] done (Phase A)** — `contents` renamed `builtinContents`; derived `contents` rebuilt by `PediaConst.init(game)` from builtin + `ModContentRegistry.pediaContents`. `addGroup` handles live append. |
| `SkillsConst.skills` | `Array<SkillInfo>` | `registerSkill(info)` | **[x] done (Phase B2)** — `_Skill` converted to `enum abstract _Skill(String) to String from String`; builtin SKILL_*/KNOW_* constants kept for engine code, mods register plain string ids. Loader migrates legacy `{_classID:"_Skill",val}` save wrappers to bare strings (shared shim with `_AITraitType`). `SkillsConst.addSkill(info)` appends live (list built once, never wiped). |
| `SoundConst.{dog,firmus,mordax,choir}` | `Map<String, Array<AISound>>` | `registerAISound(faction, id, sounds)` | Deferred (later stage). |
| `TraitsConst.traits` | `StringMap<Array<_TraitInfo>>` | `registerTrait(category, info)` | **[x] done (Phase B1)** — `_AITraitType` converted to `enum abstract _AITraitType(String) to String from String`; builtin TRAIT_* constants kept for engine code, mods register plain string ids. Loader migrates legacy `{_classID:"_AITraitType",val}` save wrappers to bare strings. `TraitsConst.addTrait(category, info)` appends live. |
| `WorldConst.areas` / `.regions` | `Map` / `Array` | `registerAreaInfo` / `registerRegionInfo` | Deferred (later stage). |

**Prefix enforcement (all mod-registered ids):** every id passed through any `register<X>` call must start with `mod-<modID>-`. Violations are rejected at registration time and logged to devtools console + session log (no silent accept). Implemented in `ModContentApi.checkPrefix`.

**Save format bumped to v3 (done, Phase B3):** the four enum→enum-abstract conversions (`_AITraitType`, `_Skill`, `_Improv`, `_Goal`) now serialize as bare strings. `Loader.initEnum` migrates `{_classID,val,_isEnum}` wrappers for those classIDs. `_AITraitType`/`_Skill`/`_Improv` were converted at the v3 bump, so their wrappers only appear in pre-v3 saves → migration gated on `formatVersion < 3` (`getFormatVersion` returns 1 for versionless/old saves, so the shim runs for them). `_Goal` was converted in Phase B4, *after* the v3 bump — its wrapper appears in pre-v3 **and** interim (unreleased) v3 saves, so its migration is **ungated**: post-conversion saves write a bare string and never reach `initEnum`, so any `{_classID:"_Goal"}` wrapper is by definition a pre-conversion save needing the strip. No v4 bump (v3 never released). `Saver.SAVE_FORMAT_VERSION` is 3. The migration branches can be deleted once no pre-conversion saves remain in the wild. No `Const.MOD_API_VERSION` bump needed — the mod API has not shipped yet, so no mods exist that target v2 (the §3.2 save-format bump rule protects mod authors, of which there are none).

Not wrapped:
- `NameConst` — name generator data; if mod wants new names, they patch the generator method (behavior, not content).
- `Lang` — cultist scream-text repo; mods monkey-patch the instance.

Each table in the v1.1+ list needs:
1. Engine `init()` (or equivalent) updated to iterate registry alongside built-in source.
2. Collision policy (default: last-wins + log).
3. New `parasite.api.register<X>(...)` method + extern.
4. Smoke test.

### 8.8 Mod Publishing (Workshop Upload)

**Decision**: ship a standalone Node CLI (`publish-workshop.js`) that wraps `steamworks.js` directly. Game code is not involved in publishing.

Reasons:
- Authors already compile Haxe in a terminal → adding `node publish-workshop.js ./my-mod` is one more command, not a workflow change.
- Zero game-side IPC, zero new UI, zero coupling to overlay (§4.3) or sandbox-flag risk.
- Idempotent and re-runnable. CI-friendly.
- Author audience is dev-only (Haxe toolchain is the gate); no benefit to in-game polish.

> **Note**: implementation diverged from the original SDK-side plan. The CLI ships **inside the game install** (beside the bundled `steamworks.js`), not as a separate SDK package, and reads flat manifest fields rather than a `workshop` block. The original plan (`parasite-mod-sdk/publish/`, `workshop` manifest block, `publishedFileId` stamping, preview/tags) is preserved below struck through where it differs, with the as-built behavior following.

#### 8.8.1 Tool layout

Source lives in the engine repo and is copied into the packaged app by the electron Makefile:

```
electron/tools/publish-workshop.js          # source
  → <game>/resources/app/tools/publish-workshop.js   # shipped, beside:
    <game>/resources/app/node_modules/steamworks.js  # bundled dep
```

No SDK-side `package.json` and no separate `npm install`: the script piggybacks the app's bundled `steamworks.js`, so it must be run from `<game>/resources/app/` for `require('steamworks.js')` to resolve. `APPID` (1920320) is hardcoded in the script.

#### 8.8.2 Upload flow

```
cd <game>/resources/app
node tools/publish-workshop.js <mod-dir> [itemId]

1. Read <mod-dir>/manifest.json. Require it exists (no `workshop` block needed).
   title = manifest.name || manifest.id || 'Untitled mod'
   description = manifest.description || null
   changeNote = auto-generated timestamp
2. Resolve item id:
     [itemId] arg, else <mod-dir>/.workshop-id file, else null (→ create new).
3. steamworks.init(APPID). Fail clean if Steam not running / not logged in.
4. If id == null:
     created = workshop.createItem(APPID)
     write created.itemId to <mod-dir>/.workshop-id
     if created.needsToAcceptAgreement:
       print item URL, exit 0 — author accepts, then re-runs (id already saved)
5. Build update payload { contentPath: <mod-dir>, title?, changeNote?,
     description?, visibility? }. visibility = 3 (unlisted) only on a new item.
     --fields=a,b,c restricts which of title/changeNote/description/visibility
     are sent (contentPath always included).
6. workshop.updateItem(itemId, payload, APPID), with transient-error retry (§8.8.4).
7. On success: print subscribe URL + Community page URL, exit 0.
```

#### 8.8.3 Item id storage

The Workshop item id is stored in `<mod-dir>/.workshop-id` (plain text), **not** stamped into `manifest.json`. First publish creates the item and writes the id there; later runs reuse it (or accept an explicit `[itemId]` arg override). README guidance: commit `.workshop-id`, don't hand-edit it, don't share an id across forks (each fork → its own Workshop item).

~~After first successful `CreateItem`, CLI writes `publishedFileId` back into `manifest.json`.~~ (Not implemented — id lives in `.workshop-id`.)

#### 8.8.4 Legal agreement & transient errors

Legal agreement is one-time per author per app. If `createItem` returns `needsToAcceptAgreement`, the CLI prints the item URL and exits — author accepts, then re-runs. The id is already written to `.workshop-id`, so the re-run continues straight to the update. No interactive stdin wait, no daemon.

Right after `createItem`, Steam's backend can take ~10–30s to settle; the update call may report "method busy" or "a parameter is invalid". The CLI retries those (up to 3 times, 5s × attempt backoff) before failing fast.

#### 8.8.5 Visibility (preview/tags not implemented)

- `visibility`: new items are created **Unlisted** (`3`); only the author sees them until they change visibility on the item's Steam Community page. Not changed on later updates.
- ~~`preview` (PNG/JPG ≤1 MB) and `tags` (developer-defined vocabulary)~~ — not read by the current CLI; set them on the Steam Community page if needed.

#### 8.8.6 Alternatives considered (not chosen for v1.1)

- **SteamCmd VDF**: zero code, but author needs steamcmd installed, two-factor friction, no manifest integration, no stamping. Worse UX than B for marginal savings.
- **In-game publish UI (option C)**: viable now that legal-agreement acceptance can route through `shell.openExternal` (no Steam overlay dependency, no §4.3 sandbox flag relaxation needed). Tradeoff: ~10 new `host:steam:workshop:*` IPC calls, publish form, preview-image picker, progress bar, error-state UI. Audience is Haxe-comfortable devs, so the UI investment buys little over B. **Revisit when the Mods tab (§11) lands** — publish button could bolt on once mod-list UI exists. Not committed for v1.1.

---

## 9. Externs Distribution

Mod authors need Haxe externs to reference engine types. Strategy:

1. **v1** (current): hand-curated minimal extern set shipped as `parasite-mod-sdk/` directory in repo. Covers `ModRuntime` + `ModContentApi` typedefs and `ItemInfo` extern. Grows incrementally as content APIs are wrapped (§8.7.1).
2. **v1.1+** (done): auto-generate from `--xml` output (`haxe -xml types.xml` post-build), filter, emit `extern class` shims for the full engine surface. Generator at `gen-externs/GenExterns.hx`, driven by `make mod-sdk` (emits to `externs-generated/`, zips into `parasite/mod-sdk/`). Curated externs (`externs/`) stay authoritative and win on overlap; the generated set fills the rest. Module sub-types and enum-abstracts collapse to `Dynamic`.

SDK layout:

```
parasite-mod-sdk/
  README.md
  externs/
    mods/
      ModRuntime.hx        # typedef
      ModContentApi.hx     # typedef
    ItemInfo.hx            # @:native('window.parasiteHx.ItemInfo') extern
  template/                # copy-paste starter mod
    manifest.json
    build.hxml
    Makefile
    src/Entry.hx
```

Mod build hxml (shipped in SDK template):

```hxml
-cp src
-cp ../../parasite-mod-sdk/externs
-D js-es=6
-D mod
-dce no
-js entry.js
-main Entry
```

Mod's `Entry` class uses `@:expose("<id>_Entry")` and `init(parasite)`, and the manifest's `exportGlobal` mirrors that string. The loader `import()`s the entry for its side effect (which sets `window["<id>_Entry"]`) then calls `window[exportGlobal].init` (§8.2) — no post-compile wrapper, no Makefile echo step. SDK README explains the load contract.

**`window.parasiteHx` global**: engine `$hxClasses` is local to the engine IIFE; a mod's IIFE shadows it with an empty local. To let `extern class X extends ItemInfo` emit valid JS that resolves at mod module-load time, `ModLoader.load()` publishes `window.parasiteHx = $hxClasses` *before* dynamically importing any mod. SDK externs target this global via `@:native('window.parasiteHx.<ClassName>')`. Engine package-path classes use bracket form: `@:native('window.parasiteHx["game.Game"]')`.

**Symbol stability**: engine `-dce no` keeps every symbol. Classes register in `$hxClasses` by their Haxe-side `__name__` (the dotted package path). As long as engine package paths stay stable, mod externs keep working. Renames are breaking changes → bump `Const.MOD_API_VERSION` (§3.2), mods bump their manifest's `modApiVersion` to match.

**SDK extern field commenting**: every public field on an SDK extern class/typedef MUST carry a short comment describing its purpose, valid value range, and any runtime-vs-author-set semantics. SDK externs are the only documentation many mod authors read — unlike engine internal types (which devs trace via callers), mod authors have no callgraph to mine. Examples:
- `id: String` — say it's a unique key, who guarantees uniqueness, what collision policy is.
- `type: String` — list common valid values if the field is a freeform string with engine-side `==` checks.
- `isKnown: Bool` — clarify whether engine flips it at runtime or whether author should preset.

Mirror this comment density across `ItemInfo`, `ModRuntime`, `ModContentApi`, and every future extern. Rule applies to extern types under `parasite-mod-sdk/externs/` only; engine-internal sources keep their existing comment density (or lack thereof).

---

## 10. Save Compatibility

Saver writes an `_activeMods` array into the save root:

```json
{
  "version": 2,
  "_activeMods": [
    { "id": "com.foo.bar", "version": "1.0.0" }
  ],
  "game": { ... }
}
```

On load:
- Compare save's `_activeMods` to currently loaded mods.
- Missing mod (was active, now absent) → warn + ask user confirm (load may fail).
- New mod (was absent, now active) → warn (state may be inconsistent).
- Version mismatch → warn.

Loader UI gets a new "mod warnings" prompt. Out of scope for save-format v2 → bump to v3.

---

## 11. Error Isolation

Per-mod try/catch around:
- Manifest parse (main)
- Dynamic import (renderer)
- `init()` call (renderer)

Each failure:
- Log full stack via `HostBridge.logAppend` (see §11.1).
- Mark mod as `failed` in `ModRegistry`.
- Skip its subsequent hooks/integrations.
- Game continues to boot.

UI: add a "Mods" tab to main menu showing each mod's status (loaded / disabled / failed + error message). Out of scope for v1 mod-load MVP; minimal console output until then.

### 11.1 Log Rotation & Session Markers

Replace single `exceptions.txt` with `log-<YYYY-MM-DD>.txt` (UTC date). Lives at same `writablePath` location as current `exceptions.txt`.

Filename resolved **once at session start** (on `App.on('ready')`) and frozen for that session's lifetime. No mid-session rollover — a session that crosses midnight keeps writing to the file dated when it started. New file only on next launch.

No renderer API change (`HostBridge.logAppend` keeps signature). Main caches the resolved path; every `host:log:append` appends there.

Session markers, written by main (renderer not involved):

```
--- session start 2026-05-17T14:32:18.453Z v0.x.y
<log lines from this session>
--- session end 2026-05-17T18:01:02.012Z
```

- **Start**: write on `App.on('ready')`, include game version (`Version.getVersion()`) and platform.
- **End**: write on `App.on('before-quit')` and `App.on('window-all-closed')`. Best-effort — hard crash of main, OS kill, or power loss skips it. That's acceptable; missing end-marker is itself a signal.

Rationale: per-day files keep logs from growing unbounded over months. Session markers turn the log into a timeline reviewer can scan instead of an undifferentiated stream. Required for v1 mod work because mod errors will dominate volume.

Implementation lives in `MainElectron.hx` only — no renderer-side changes, no new IPC. Rename happens in same patch.

---

## 12. Steamworks (v1.1)

**Pick**: `steamworks.js` (ceifa fork, active, N-API). `greenworks` is stale; custom sidecar = overkill.

**Process placement**: main only. Renderer keeps `sandbox:true, contextIsolation:true, nodeIntegration:false`. Renderer reaches Steam via existing `host:*` IPC pattern.

**New IPC surface** (preload + MainElectron):

```js
host.steam = {
  init: (appId) => sendSync('host:steam:init'),
  workshop: {
    list:        ()      => sendSync('host:steam:workshop:list'),         // -> [{id, folder, state}]
    download:    (id)    => invoke('host:steam:workshop:download', id),   // -> bool
    downloadInfo:(id)    => sendSync('host:steam:workshop:downloadInfo', id), // -> {current,total} | null
  },
  overlay: {
    activated:   (cb)    => /* events from main */,
  },
};
```

Main wraps `steamworks.js` calls with try/catch — failed Steam init must not crash boot. Sideload still works.

**Discovery glue**: §4.2 flow runs in main, returns mods to renderer through `host:mods:list` (no separate `host:steam:workshop:list` needed for boot — the list call collapses into the unified `mods:list` after workshop+sideload merge). Keep workshop IPC for runtime UI (downloading state, retry button).

**Overlay**: see §4.3. Empirically test `electronEnableSteamOverlay()` with current sandbox before relaxing flags.

**App ID + publishing**: out of scope.

**Steam_appid.txt**: dev builds drop `steam_appid.txt` next to executable so steamworks.js init works without Steam client launching the game.

**Upload/publishing**: out of scope for the game process. Authors publish via a standalone CLI shipped in the game install at `resources/app/tools/publish-workshop.js` (§8.8). Game stays read-only against Workshop.

---

## 13. Open Questions

Resolved (folded into spec):
- ~~Mod-disable storage~~ → `profile.disabledMods` (§4).
- ~~Asset overrides~~ → in scope, last-mod-wins, `AssetPath.resolve` (§8.6).
- ~~Per-mod storage~~ → `settings.json` namespaced under `mods.<id>`; no separate storage layer (§8.5).
- ~~Console `mods` command~~ → in scope (§7, §15).

Resolved (cont):
- ~~Engine version matching~~ → `Const.MOD_API_VERSION` integer, exact match; bump rules in §3.2. Optional `minGameVersion` for feature-add gating.

Resolved (cont):
- ~~Const-table re-init idempotency~~ → mods don't mutate const tables; they use registration API (§8.7). v1: items only. v1.1+ wraps remaining tables (§8.7.1 list).

Still open:
- **Mod-defined custom events**. The v1.1 event bus (§8.4) ships engine-named events only; mods subscribe but cannot declare/emit their own event names (for mod-to-mod integration). Open: do we let mods register custom event names (prefix-enforced `mod-<id>-` like content ids?), expose `fire()` to mods, and how handler ordering / error attribution works across mods. Deferred — monkey-patching covers mod-to-mod coupling today.
- **Per-mod settings UI**. §8.5 ships the storage + read/write API; users currently have no in-game path to view or edit a mod's persisted values (only by hand-editing `settings.json`). Mods tab (v1.1, §11) shows status only. Open: do we add a settings editor (declared schema vs freeform key/value), where it lives (Mods tab row, Options subtab), and which milestone it ships in.
- **Partial asset changes**. A lot of the tilemaps are in `img/` — if a mod wants to change just one tile's image, they have to ship the whole tileset. We could add a way for mods to specify partial overrides (e.g. "my mod changes `img/entities64.png` at row=5, col=6) without forcing them to override the full image.
- **Runtime-gated debug build**. Debug + console are currently gated at compile time behind `#if mydebug`, so debug and release are separate builds. Could we ship one build for both and gate debug functionality behind a runtime command-line arg (e.g. `-debug`) instead? Tradeoffs to resolve: (a) `#if mydebug` blocks are dead-code-eliminated today — moving to runtime checks keeps the debug code in the shipped bundle (size + the console/cheat surface is present in release binaries, reachable by anyone passing the flag); (b) some `#if mydebug` sites guard imports/types that don't exist in release, not just statements — those can't all collapse to a runtime `if`; (c) mod implications — mods already run with full realm access (§2), so a flag-gated console is not a new capability boundary, but it does change what a vanilla release exposes by default. Decide: single build + `-debug` runtime flag, or keep compile-time split.

---

## 14. Milestones

### v1.0 — Sideload MVP
1. [x] Log rotation §11.1: rename `exceptions.txt` → `log-<YYYY-MM-DD>.txt`, session start/end markers, frozen-at-boot filename.
2. [x] `MainElectron.hx` registers `mod://` protocol, `host:mods:list` IPC, scans `mods/` + `dev/`.
3. [x] Manifest validation in main (schema, deps, version range).
4. [x] CSP update in `app.html` to add `mod:` to script/img/media/font/connect lists.
5. [x] `ModRegistry.hx`, `ModLoader.hx`, `ModInfo.hx`, per-mod `window.parasite` surface.
6. [x] `ModSettings.hx` + `Config.mods` subtree (§8.5).
7. [x] `AssetPath.hx` + refactor of `Images.hx` + `Sounds.hx` call sites (§8.6).
7a. [x] `ModContentRegistry.hx` + `ModContentApi.hx` + `ItemsConst.init` registry merge (§8.7).
8. [x] `Profile.disabledMods` field + read at boot.
9. [x] Hook `ModLoader.load()` into `Main.init()` before `ui.state = MAINMENU`.
10. [x] `Console.hx` `mods` subcommand: list, enable, disable, errors.
11. [x] Externs SDK skeleton: `parasite-mod-sdk/` with `Parasite.hx`, key engine externs, build hxml, README, hello-world example.
12. [x] Save format v3 with `_activeMods` array + loader warning UI.

### v1.1 — Workshop + Polish
- [x] `steamworks.js` integration in main process; `host:steam:*` IPC.
- [x] Workshop discovery + download via `workshop.getSubscribedItems`/`state`/`installInfo`/`download` (§4.2).
- [x] Overlay enablement test under current sandbox (§4.3). Works with current sandbox via `electronEnableSteamOverlay()` + pre-ready chromium switches.
- [x] `steam_appid.txt` in dev builds.
- [x] Event bus (§8.4) — `parasite.events` facade, 5 typed events (`turn:pre`/`turn:post`/`area:enter`/`area:leave`/`ai:spawn`), per-handler error isolation.
- [x] Mod SDK documentation pass: author-facing guide in `parasite-mod-sdk/docs/` (01–10) covering load contract, `parasite` object, registration APIs, monkey-patching, asset overrides, settings, publishing, console reference, and the extern sets. Trimmed top-level README to overview + quickstart + doc index; added `template/README.md`. `docs/` added to the `make mod-sdk` zip. Console reference lists all commands marking release-vs-debug per current `#if mydebug` gating (final `-debug` flag decision still open — see §13).
- [x] Mod manager UI in main menu (loaded/disabled/failed/downloading per mod).
- [x] Auto-generated externs from `--xml`. `parasite-mod-sdk/gen-externs/GenExterns.hx` parses the engine `haxe --xml` dump (`haxe.rtti.XmlParser`) and emits one `@:native('window.parasiteHx[...]')` extern per engine class + a typedef per anonymous record (310 types after blacklist). Hand-curated externs win on overlap (skipped by path); module sub-types (file != path) and enum-abstracts are skipped → resolve to `Dynamic`. A `blacklist` drops internal machinery mods never reference (`aPath.*`, `console.*`, `cult.{missions,ordeals,events,effects}.*`, `lighting.*`, `map.*`, `mods.*`, `AreaLighting*`, `HostBridge`, `Version`, …) → `Dynamic`. Field/function doc comments are scraped from the `//` block above each source decl. `make mod-sdk` wipes the output dir, regenerates, version-stamps (`VERSION` file from `src/VERSION`), and zips the SDK (curated + generated + template + README) into `parasite/mod-sdk/parasite-mod-sdk-<ver>.zip` for the game download. Generated dir is gitignored; template `build.hxml` `-cp`s both extern sets.
- [x] Publish CLI: `electron/tools/publish-workshop.js` (shipped to `resources/app/tools/`, beside bundled `steamworks.js`) — Node + `steamworks.js`, drives `createItem` → `updateItem` ({contentPath, title, changeNote, description, visibility}); reads flat `manifest.name`/`description`, stores item id in `<mod-dir>/.workshop-id`, new items Unlisted, `--fields=` payload filter, transient-error retry (§8.8).

### v1.2+ (deferred)
- [ ] Wrap remaining const tables in registration API (§8.7.1). Done: PediaConst (A), TraitsConst (B1), SkillsConst (B2), EvolutionConst (B3), Goals (B4). Remaining: ChatConst, Jobs, SoundConst, WorldConst. Each table: engine `init()` change + new `api.register<X>` method + extern + smoke test.
- In-game publish UI (§8.8.6 option C). Revisit after Mods tab lands. Uses `shell.openExternal` for legal agreement; no Steam overlay dependency.

---

## 15. Build & Test (MVP scope)

```sh
cd src && make           # engine
cd electron && make      # main + preload
# Drop a test mod into <cwd>/mods/com.test.hello/ with manifest.json + entry.js
# Launch — verify init() ran via console log
```

Smoke checklist:
- Mod with bad manifest → logged, game boots.
- Mod with throwing init → logged, game boots.
- Mod with missing/malformed `exportGlobal` → rejected at scan, never loads, log shows "missing/invalid exportGlobal".
- Mod with `exportGlobal` not matching its `@:expose` → loads, `window[exportGlobal]` undefined → marked failed + logged, game boots.
- Mod with `modApiVersion` ≠ `Const.MOD_API_VERSION` → skipped, log shows "mod targets API vX, engine is vY".
- Mod with `minGameVersion` newer than current engine → skipped + log.
- Path-traversal `mod://com.x.y/../../etc/passwd` → 403.
- Disabled mod via `profile.disabledMods` → skipped.
- Asset override: mod ships `assets/img/entities64.png` → engine uses mod's image.
- Per-mod settings: mod writes via `parasite.settings`, persisted under `settings.mods.<id>.*`.
- Console `mods` command lists loaded/disabled/failed mods.
- Mod calls `parasite.api.registerItem(MyItem)` → item appears in `ItemsConst.infos`. Start new game → item still present. Open console, run `add` flow that re-inits → item still present.
- Two mods register same item id → boot log shows collision warning.
- Mod calls `parasite.events.onAISpawn(...)` → handler fires on next AI spawn; `onTurnPre`/`onAreaEnter` fire on turn/area transition. Throwing handler → logged, turn loop continues.
- Save with mods, reload with one removed → warning.

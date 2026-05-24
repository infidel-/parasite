# The runtime object

`init(parasite)` receives one argument: a per-mod runtime object. The engine
builds a fresh one for each mod, so the scoped fields (`modID`, `settings`,
`api`) belong to your mod specifically.

Its Haxe type is `mods.ModRuntime` (in `externs/mods/ModRuntime.hx`):

```haxe
typedef ModRuntime = {
  var modID: String;
  var modVersion: String;
  var modApiVersion: Int;
  var game: game.Game;
  var host: Dynamic;
  var hxClasses: Dynamic;
  var version: String;
  var api: ModContentApi;
  var settings: ModSettings;
  var savedata: ModSaveData;
  var events: ModEvents;
  var fx: ModFx;
}
```

## Fields

| Field           | Type             | What it is                                                                 |
|-----------------|------------------|----------------------------------------------------------------------------|
| `modID`         | `String`         | your mod's id, matching `manifest.json`. Used to scope settings and to build the required `mod-<modID>-` content-id prefix. |
| `modVersion`    | `String`         | your mod's version, from the manifest.                                     |
| `modApiVersion` | `Int`            | the engine's `Const.MOD_API_VERSION` at load time. Equals your manifest's value (you were only loaded because they matched). |
| `version`       | `String`         | engine version string (e.g. `0.22`).                                       |
| `game`          | `game.Game`      | the live engine game instance (`Game.inst`). Fully typed via the generated extern — the entire engine state tree hangs off this. |
| `host`          | `Dynamic`        | the `window.host` IPC bridge — the same preload surface the engine uses (save/load, settings, profile, log, quit, …). Untyped: it is the contextBridge surface, not a Haxe type. |
| `hxClasses`     | `Dynamic`        | the raw `$hxClasses` registry: a JS map of dotted class name → Haxe class reference. Reach any engine class by name, e.g. `Reflect.field(parasite.hxClasses, 'const.ItemsConst')`. Also published as `window.parasiteHx` for `@:native` extern targets. |
| `api`           | `ModContentApi`  | your content-registration facade — `registerItem`, `registerPediaEntry`, etc. See [04-registering-content.md](04-registering-content.md). |
| `settings`      | `ModSettings`    | your persistent key/value store, namespaced under your `modID`. Cross-run, backed by `settings.json` — NOT savegame-scoped. See [07-settings.md](07-settings.md). |
| `savedata`      | `ModSaveData`    | per-mod savegame-scoped k/v storage. Same getter/setter shape as `settings` but persisted as part of the active savegame and reloaded on load. Use for per-playthrough state (counters, story flags). See [07-settings.md](07-settings.md#per-mod-savegame-data-parasitesavedata). |
| `events`        | `ModEvents`      | subscribe to engine event hooks with typed payloads. See [05-monkey-patching.md](05-monkey-patching.md#event-hooks). |
| `fx`            | `ModFx`          | named fx registry + RAF/canvas/overlay primitives. Register your effects by id (must start with `mod-<modID>-`), fire them with `parasite.fx.play(id, params)`, compose using `tick` (RAF scheduler), `canvas()` (game `#canvas` el), `overlay()` (engine-owned reusable fullscreen div). See [05-monkey-patching.md](05-monkey-patching.md#fx-system). |

## Typed vs untyped fields

`game` is fully typed against the generated `game.Game` extern, so you get
completion and compile-time checking against the engine tree. `host` and
`hxClasses` are `Dynamic` on purpose: `host` is an external (preload) surface
with no Haxe type, and `hxClasses` is a raw name→class map you index
dynamically.

When you reach an engine class through `hxClasses`, the result is `Dynamic`. If
you want typing, reference the generated extern for that class directly instead
(see [10-api-reference.md](10-api-reference.md)) rather than going through
`hxClasses`.

## Reaching engine globals

Two equivalent ways to get an engine class:

```haxe
// dynamic, by name, no typing:
var ItemsConst: Dynamic = Reflect.field(parasite.hxClasses, 'const.ItemsConst');
ItemsConst.infos.exists('mod-mymod-thing');
```

```haxe
// typed, via the generated extern (preferred when you need the type):
const.ItemsConst.infos.exists('mod-mymod-thing');
```

The generated externs already target `window.parasiteHx`, so a typed reference
resolves at runtime to the same class the dynamic lookup would find.

# Load contract

How a mod goes from `.hx` source to running engine code. If your mod compiles
but never loads, the cause is almost always here.

## The shape of a mod on disk

```
<modId>/
  manifest.json     # required — metadata + entry filename
  entry.js          # required — Haxe-compiled ES module
  entry.js.map      # optional — source map
  assets/           # optional — see 06-assets.md
```

The engine discovers a mod directory by the presence of `manifest.json`. A
directory without one is skipped silently.

## Discovery roots

The engine scans two directories next to the executable (Linux/Windows; macOS
is not supported in v1):

| Root            | Use                                                         |
|-----------------|------------------------------------------------------------|
| `<game>/mods/`  | user-facing sideloaded mods                                |
| `<game>/dev/`   | in-progress mods (gitignored); the template's `DEST` points here |

Steam Workshop subscriptions are also discovered and merged into the same list.

## manifest.json

```json
{
  "id": "com.you.mymod",
  "name": "My Mod",
  "author": "you",
  "version": "1.0.0",
  "modApiVersion": 1,
  "entry": "entry.js"
}
```

| Field           | Required | Meaning                                                                 |
|-----------------|----------|-------------------------------------------------------------------------|
| `id`            | yes      | unique key, regex `^[a-z0-9_]+(\.[a-z0-9_]+)*$`, 4–80 chars. Duplicate ids across mods = loader error. |
| `name`          | yes      | display name (menus, console, Workshop title fallback)                  |
| `author`        | yes      | author label                                                            |
| `version`       | yes      | semver `major.minor.patch`                                              |
| `modApiVersion` | yes      | integer; must equal engine `Const.MOD_API_VERSION` exactly (currently `1`). Mismatch = skipped + logged. |
| `entry`         | yes      | entry JS filename, relative to mod root (almost always `entry.js`)      |
| `minGameVersion`| no       | semver; compared `>=` against the engine version. Use when you depend on a feature added in a specific patch. Newer than current engine = skipped + logged. |
| `description`   | no       | long description; consumed by the publish tool (see 08-publishing.md)   |
| `dependencies`  | no       | array of `{ id, version }`; missing/mismatched dep = skipped + logged   |
| `loadAfter` / `loadBefore` | no | arrays of mod ids; ordering hints fed to a toposort. Cycles = members skipped + logged. |

`modApiVersion` is an exact-match gate, not a floor. The engine bumps
`Const.MOD_API_VERSION` only on breaking changes; when it does, bump your
manifest to match. See [versioning](#versioning) below.

## The entry module

The engine loads your mod with a dynamic `import('mod://<id>/entry.js')` and
then calls the module's exported `init`:

```js
modExports.init(parasite);
```

So `entry.js` must be an **ES module that exports an `init` function**. Haxe's
`@:expose` puts your class on `window`, not on the module's exports — so the
template's Makefile appends one line to bridge the two:

```js
export const init = window.yourmod_Entry.init;
```

That is why `EXPOSE_NAME` in the Makefile must match the string in
`@:expose("...")`. If they disagree, `window.<EXPOSE_NAME>` is `undefined` and
the import throws (visible via `mods errors`).

### Entry.hx

```haxe
package;

import mods.ModRuntime;
import js.Browser.console;

@:expose("yourmod_Entry")
class Entry
{
  public static function main() {}

  // engine calls this at boot with the per-mod runtime object
  public static function init(parasite: ModRuntime)
    {
      console.log('[yourmod] hello from ' + parasite.modID);
    }
}
```

`main()` exists only to satisfy `-main Entry`; the engine never calls it. The
real entry point is `init`. What `parasite` carries is documented in
[03-runtime-object.md](03-runtime-object.md).

## When init runs

Mods are loaded **after** the engine is fully constructed but **before** the
main menu appears (before any gameplay). At `init` time you can:

- Monkey-patch any engine class ([05-monkey-patching.md](05-monkey-patching.md)).
- Register content via `parasite.api` ([04-registering-content.md](04-registering-content.md)).
- Read/write your settings ([07-settings.md](07-settings.md)).

You **cannot** intercept engine boot itself, and there is no hot-reload — to
apply a rebuilt mod, reload the renderer (Ctrl-F5) or relaunch.

## Build flags

The template `build.hxml`:

```hxml
-cp src
-cp ../../parasite-mod-sdk/externs
-cp ../../parasite-mod-sdk/externs-generated
-main Entry
-D js-es=6
-D mod
-dce no
-js entry.js
```

| Flag                          | Why it matters                                                            |
|-------------------------------|---------------------------------------------------------------------------|
| `-cp .../externs`             | hand-curated mod-API externs (win on overlap)                             |
| `-cp .../externs-generated`   | full engine surface                                                       |
| `-D js-es=6`                  | engine compiled extern classes (e.g. `ItemInfo`) to ES6 `class`; your mod must match to `extends` them |
| `-D mod`                      | conditional-compile guard for mod-only code                               |
| `-dce no`                     | keep every symbol — the engine's `$hxClasses` registry depends on it      |

## Error isolation

Each mod is wrapped in try/catch at three points: manifest parse, dynamic
import, and the `init` call. A failure logs a full stack and marks the mod
`failed`; the game still boots and other mods still load. Inspect failures with
the `mods errors` console command.

## Versioning

The engine bumps `Const.MOD_API_VERSION` (an integer) whenever a change can
break existing mods — extern renames/removals, signature changes to commonly
overridden methods, save-format shifts affecting mod content. Pure additions do
not bump it.

Your manifest's `modApiVersion` must equal the engine's value exactly. On a
bump, mods targeting the old value are skipped with a console message like
`mod targets API v1, engine is v2`. Update your manifest and recompile.

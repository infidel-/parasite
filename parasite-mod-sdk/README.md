# parasite-mod-sdk

Haxe externs and a starter template for writing **Parasite** mods.

Mods are Haxe→JS ES modules dynamically imported by the engine at boot. The engine
runs in a locked-down Electron renderer (`sandbox:true`, `contextIsolation:true`,
`nodeIntegration:false`), so mods cannot touch Node/FS directly — they reach the
host only via the per-mod `parasite` runtime object passed to `init()`.

---

## Layout

```
parasite-mod-sdk/
  externs/              # Haxe externs for engine types
    mods/
      ModRuntime.hx     # typedef for parasite.* surface
      ModContentApi.hx  # typedef for parasite.api
    ItemInfo.hx         # @:native extern — resolves to window.parasiteHx.ItemInfo
  template/             # copy-paste starter mod
    manifest.json
    build.hxml
    Makefile
    src/Entry.hx
```

---

## Quick start

1. Copy `template/` to a new directory (anywhere).
2. Edit `manifest.json` — pick a unique `id` (must match `^[a-z0-9_]+(\.[a-z0-9_]+)*$`).
3. Edit `Makefile` — set `DEST` to your game install's `dev/<your-id>/` and
   `EXPOSE_NAME` to match the `@:expose("...")` in `Entry.hx`.
4. Edit `src/Entry.hx` — rename `@:expose("yourmod_Entry")` and the package the
   way you like, but keep a `public static function init(parasite: ModRuntime)`
   entry point.
5. `make` — builds `entry.js`, copies it + `manifest.json` to `DEST`.
6. Launch Parasite. Look for `[mods] loading ...` in DevTools console.
   Console command `mods` lists status, `mods errors` shows per-mod failures.

---

## Build flags (`build.hxml`)

| Flag         | Why                                                              |
|--------------|------------------------------------------------------------------|
| `-D js-es=6` | engine compiles `extern class ItemInfo` to ES6 `class`; mods must match to `extends` it |
| `-D mod`     | conditional-compile guard for mod-only code (mirrors `#if electron` in engine) |
| `-dce no`    | keep every symbol — engine's `$hxClasses` registry depends on it |

---

## Engine API contract

Engine `init()` call:

```haxe
public static function init(parasite: ModRuntime)
```

`parasite` fields:

| field           | type                       | purpose                                     |
|-----------------|----------------------------|---------------------------------------------|
| `modID`         | `String`                   | this mod's id (matches `manifest.json`)     |
| `modVersion`    | `String`                   | this mod's version                          |
| `modApiVersion` | `Int`                      | engine `Const.MOD_API_VERSION` at load time |
| `version`       | `String`                   | engine version string                       |
| `game`          | `Dynamic` (engine `Game`)  | live game instance — untyped pending Game extern |
| `host`          | `Dynamic`                  | `window.host` IPC bridge (preload surface)  |
| `hxClasses`     | `Dynamic`                  | raw `$hxClasses` map — name → class ref     |
| `api`           | `ModContentApi`            | content registration (registerItem, …)      |

---

## Registering content

```haxe
import mods.ModRuntime;
import ItemInfo;

class MyItem extends ItemInfo
{
  public function new(game: Dynamic)
    {
      super(game);
      id = 'mymod_trinket';
      type = 'misc';
      name = 'odd trinket';
      unknown = 'odd trinket';
    }
}

class Entry
{
  public static function init(parasite: ModRuntime)
    {
      parasite.api.registerItem(MyItem);
    }
}
```

Re-registration on subsequent `ItemsConst.init` runs is automatic
(see engine §8.7). Id collisions log a warning, last-wins.

---

## Versioning

Engine bumps `Const.MOD_API_VERSION` on breaking changes (extern renames,
`ModRuntime` field removals, save-format shifts that affect mod content).
Mods must bump their `manifest.json` `modApiVersion` to match — mismatched
mods are skipped at load with a console warning.

The MVP extern set (v1) is hand-curated and minimal. Auto-generated full
externs from `haxe -xml` land in v1.1+.

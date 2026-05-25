# parasite-mod-sdk

Haxe externs, docs, and a starter template for writing **Parasite** mods.

Mods are written in Haxe, compiled to a JS ES module, and dynamically imported
by the engine at boot. The engine runs in a locked-down Electron renderer
(`sandbox:true`, `contextIsolation:true`, `nodeIntegration:false`), so mods reach
the host only through the per-mod `parasite` runtime object passed to `init()` —
not via Node/FS directly.

Mods have full access to engine state through that object; there is no
capability sandbox. Workshop content is curated by Steam moderation and user
choice, sideloaded content by the user dropping in files.

## Layout

```
parasite-mod-sdk/
  README.md             # this file
  docs/                 # the guide (start here)
  externs/              # hand-curated mod-API externs (win on overlap)
  externs-generated/    # auto-generated full engine externs
  template/             # copy-paste starter mod
```

## Quick start

1. Copy `template/` to a new directory.
2. Edit `manifest.json` — pick a unique `id` (`^[a-z0-9_]+(\.[a-z0-9_]+)*$`); set
   `exportGlobal` to match the `@:expose("...")` in `src/Entry.hx`.
3. Edit `Makefile` — set `DEST` to your install's `dev/<your-id>/`.
4. Edit `src/Entry.hx` — keep `public static function init(parasite: ModRuntime)`.
5. `make` — builds `entry.js`, copies it + `manifest.json` to `DEST`.
6. Launch Parasite. DevTools console shows `[mods] loading ...`; the in-game
   `mods` command lists status, `mods errors` shows failures.

Full walkthrough in [docs/01-getting-started.md](docs/01-getting-started.md).

## Documentation

| Doc | Covers |
|-----|--------|
| [01-getting-started](docs/01-getting-started.md)   | zero to a loading mod |
| [02-load-contract](docs/02-load-contract.md)       | manifest, `entry.js`, `@:expose`/`exportGlobal`, build flags, versioning |
| [03-runtime-object](docs/03-runtime-object.md)     | the `parasite` object field by field |
| [04-registering-content](docs/04-registering-content.md) | items, pedia, traits, skills, evolution, goals |
| [05-monkey-patching](docs/05-monkey-patching.md)   | changing engine behavior; event hooks; what survives re-init |
| [06-assets](docs/06-assets.md)                     | shipping/overriding images, sounds, music |
| [07-settings](docs/07-settings.md)                 | per-mod persistent settings |
| [08-publishing](docs/08-publishing.md)             | Steam Workshop upload |
| [09-console-reference](docs/09-console-reference.md) | console commands |
| [10-api-reference](docs/10-api-reference.md)       | how the two extern sets work |
| [11-save-data-pitfalls](docs/11-save-data-pitfalls.md) | what survives `parasite.savedata`; testing your mod across save/load |

## The entry contract, in one block

```haxe
package;

import mods.ModRuntime;

@:expose("yourmod_Entry")
class Entry
{
  public static function main() {}

  public static function init(parasite: ModRuntime)
    {
      // parasite.api      — register content
      // parasite.game     — live engine state
      // parasite.hxClasses — every engine class, by name
      // parasite.settings — persistent per-mod storage
      // parasite.host     — IPC bridge
    }
}
```

The loader `import()`s `entry.js` for its side effect, then calls
`window[manifest.exportGlobal].init(parasite)` — `@:expose("yourmod_Entry")`
puts the class there. No post-processing; just keep `exportGlobal` equal to the
`@:expose` name. Details in [docs/02-load-contract.md](docs/02-load-contract.md).

## Versioning

The engine bumps `Const.MOD_API_VERSION` on breaking changes (extern
renames/removals, save-format shifts affecting mod content). Your manifest's
`modApiVersion` must equal it exactly — mismatched mods are skipped with a
console message. Current value: **1**.

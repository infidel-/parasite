# Getting started

This walks you from zero to a mod that the engine loads and logs at boot.

## Prerequisites

- **Haxe** compiler (4.x). Mods are written in Haxe and compiled to a JS ES module.
- A **Parasite** install. You need write access to its `dev/` directory (where
  in-progress mods are sideloaded from).
- `make` (the template ships a Makefile; you can build by hand without it).

No Node, no game-engine checkout. The SDK ships the externs you compile against.

## 1. Get the SDK

The SDK is bundled with the game download at `<game>/mod-sdk/parasite-mod-sdk-<version>.zip`.
Unzip it anywhere. You get:

```
parasite-mod-sdk/
  README.md
  docs/                 # you are here
  externs/              # hand-curated mod-API externs
  externs-generated/    # auto-generated engine externs (the full surface)
  template/             # copy-paste starter mod
```

See [10-api-reference.md](10-api-reference.md) for what the two extern sets are
and which wins.

## 2. Copy the template

```sh
cp -r parasite-mod-sdk/template ~/mymod
cd ~/mymod
```

## 3. Edit four things

1. **`manifest.json`** — pick a unique `id`. It must match
   `^[a-z0-9_]+(\.[a-z0-9_]+)*$` (lowercase, optional dot segments). Reverse-DNS
   (`com.you.mymod`) is recommended for distributed mods; a single segment
   (`mymod`) is fine for local/private ones. Set `exportGlobal` to match the
   `@:expose("...")` in `Entry.hx`.
2. **`Makefile`** — set `DEST` to your install's `dev/<your-id>/`.
3. **`src/Entry.hx`** — rename `@:expose("yourmod_Entry")` (and keep it equal to
   the manifest's `exportGlobal`); keep a
   `public static function init(parasite: ModRuntime)` entry point.
4. **`build.hxml`** — usually no change. It already `-cp`s both extern sets.

Full field reference for each file: [02-load-contract.md](02-load-contract.md)
and [template/README.md](../template/README.md).

## 4. Build and install

```sh
make
```

This compiles `entry.js` and copies it + `manifest.json` into `DEST`. There is no
post-processing step — `haxe build.hxml` output loads as-is, so building without
`make` is just the `haxe build.hxml` line plus copying the two files.

`dev/` is gitignored in the install and scanned by the engine the same way as
`mods/` — no flag needed.

## 5. Enable debug mode (optional)

Mod-author conveniences (verbose in-game console commands, debug HUD, host-side
debug image/text dumps from `HostBridge.debugWrite*`) are gated at runtime by a
sentinel file. To turn them on:

1. Quit the game.
2. Create an empty file named `.debug` in the game install directory (the
   directory containing the game executable / Electron app cwd).
3. Launch the game.

The flag is resolved once at startup and cached for the whole session — to
toggle, restart. Delete (or rename) `.debug` to return to the default release
surface.

With debug on you also get the expanded in-game console command set described
in [09-console-reference.md](09-console-reference.md) (`give`, `go`, `goal`,
`learn`, `set`, `spa`, `spc`, `snd`, etc.). With it off the console still
exposes the release subset (`load`, `save`, `restart`, `quit`, `mods`,
`debug renderstats|ai|sound|lights`, `cfg`).

## 6. Launch and verify

Launch Parasite. Open DevTools console. You should see the loader log:

```
[mods] loading mymod ...
```

and your own line from `Entry.init`:

```
[mymod] hello from mymod v0.1.0
```

In the in-game console (not DevTools), the `mods` command lists every
discovered mod and its status; `mods errors` prints per-mod failure reasons.
See [09-console-reference.md](09-console-reference.md).

## What next

- Add content (items, pedia, traits, skills, evolution, goals):
  [04-registering-content.md](04-registering-content.md).
- Change existing engine behavior: [05-monkey-patching.md](05-monkey-patching.md).
- React to turn/area/spawn events: [05-monkey-patching.md#event-hooks](05-monkey-patching.md#event-hooks).
- Replace art/sound: [06-assets.md](06-assets.md).
- Persist mod state: [07-settings.md](07-settings.md).
- Ship to Steam Workshop: [08-publishing.md](08-publishing.md).

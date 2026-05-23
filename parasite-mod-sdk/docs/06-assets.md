# Assets and overrides

A mod can ship its own images, sounds, and music, and can **replace** engine
assets by shipping a file at the same logical path.

## Convention

Put files under `assets/` in your mod, mirroring the engine's own layout. A
mod file at `assets/<category>/<name>` shadows the engine's `<category>/<name>`:

| Engine asset                  | Override it with                          |
|-------------------------------|-------------------------------------------|
| `img/entities64.png`          | `<mod>/assets/img/entities64.png`         |
| `sound/ai-arrive-police.mp3`  | `<mod>/assets/sound/ai-arrive-police.mp3` |
| `music/menu.mp3`              | `<mod>/assets/music/menu.mp3`             |

Shipping a path the engine does **not** bundle simply adds a new asset (this is
how mods add new sounds — the engine enumerates mod-added audio).

```
mymod/
  manifest.json
  entry.js
  assets/
    img/entities64.png
    sound/mod-mymod-bark.mp3
```

The engine walks each mod's `assets/` at boot and registers every file. No
registration call is needed from your `init` — dropping the file in `assets/` is
enough.

## How resolution works

Engine asset lookups go through `AssetPath.resolve(path)`:

- If some mod registered an override for that logical path, it returns the
  `mod://<id>/assets/<path>` URL.
- Otherwise it returns the original engine path unchanged.

You normally don't call this yourself — the engine call sites do. If you're
writing code that loads an asset and want it to respect overrides, resolve
through `mods.AssetPath` rather than hard-coding the path.

## Conflict resolution

If two mods override the same file, **last-mod-wins**, where order is the
toposorted load order (see [02-load-contract.md](02-load-contract.md)). Each
override is logged at boot, so users can see which mod replaced what.

## Notes and limits

- Overriding `img/entities64.png` (or any tilemap) means shipping the **whole**
  image — there is no partial/per-tile override in v1.
- The `mod://` scheme is already permitted by the engine's content-security
  policy for images, media, and fonts, so overrides load without any further
  setup on your side.
- Asset filenames you *add* (vs. override) should stay namespaced — prefix new
  sounds/images with `mod-<modID>-` to avoid colliding with engine or other-mod
  assets.

## Stylesheet overrides (`mod.css`)

A file at the **root** of your mod named `mod.css` is auto-loaded by the engine
at boot as a stylesheet — appended to `<head>` *after* the engine's `app.css`,
so same-specificity rules win the cascade and override engine styles.

```
mymod/
  manifest.json
  entry.js
  mod.css           <- auto-loaded, after app.css
  assets/
    ...
```

The engine only consults `mod.css` at the mod root — dropping `app.css` into
the mod dir does nothing. Mods load in toposorted order, so a later mod's
`mod.css` stomps an earlier mod's same-selector rules.

Example — paint the main-menu buttons red:

```css
.window-mainmenu-item { background: red; }
```

To find the right selector, inspect the engine UI in the devtools elements
panel; selectors are stable across engine versions but not guaranteed.

The `mod:` scheme is whitelisted in the engine CSP for stylesheets, so no
further setup is needed.

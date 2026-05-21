# Starter template

A minimal mod that compiles, loads, and logs at boot. Copy this directory
anywhere and edit the four files below.

```
template/
  manifest.json     # mod metadata
  build.hxml        # Haxe compile flags
  Makefile          # build + install to your game's dev/ dir
  src/Entry.hx      # the init() entry point
```

## What to edit

### 1. `manifest.json`

```json
{
  "id": "yourmod",
  "name": "Your Mod",
  "author": "you",
  "version": "0.1.0",
  "modApiVersion": 1,
  "entry": "entry.js"
}
```

- `id` — change it. Must match `^[a-z0-9_]+(\.[a-z0-9_]+)*$`. Reverse-DNS
  (`com.you.yourmod`) for anything you distribute.
- `name`, `author`, `version` — your values.
- `modApiVersion` — leave at the current engine value (`1`); only change on an
  engine API bump.
- Full field list: [../docs/02-load-contract.md](../docs/02-load-contract.md).

### 2. `Makefile`

```make
DEST = ../../parasite/dev/yourmod
EXPOSE_NAME = yourmod_Entry
```

- `DEST` — point at your install's `dev/<your-id>/`.
- `EXPOSE_NAME` — **must** match the string in `@:expose("...")` in `Entry.hx`.
  If they disagree, the mod won't load (the ESM export wrapper resolves
  `window.<EXPOSE_NAME>`).

### 3. `src/Entry.hx`

```haxe
@:expose("yourmod_Entry")
class Entry
{
  public static function main() {}

  public static function init(parasite: ModRuntime)
    {
      // your mod starts here
    }
}
```

- Rename `@:expose("yourmod_Entry")` to match `EXPOSE_NAME`.
- Keep `init(parasite: ModRuntime)` — it's the engine entry point.
- `main()` only satisfies `-main Entry`; the engine never calls it.

### 4. `build.hxml`

Usually no change. It already adds both extern sets to the classpath. See
[../docs/02-load-contract.md](../docs/02-load-contract.md#build-flags) for what
each flag does.

## Build

```sh
make
```

Compiles `entry.js`, appends the ESM `export const init = ...` wrapper line, and
copies `entry.js` + `manifest.json` into `DEST`. Then launch the game and look
for your mod in the `mods` console command.

Full walkthrough: [../docs/01-getting-started.md](../docs/01-getting-started.md).

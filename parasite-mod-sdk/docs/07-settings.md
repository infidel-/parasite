# Per-mod settings & savegame data

The SDK ships two k/v stores. Pick by scope:

- **`parasite.settings`** — backed by the game's `settings.json`. Cross-run, one
  bucket per `modID`. Use for **mod config** the player should keep across
  savegames (difficulty knobs, debug toggles, "hide this prompt once" flags).
- **`parasite.savedata`** — backed by the active savegame. Per-playthrough.
  Reloaded when the player loads a slot. Use for **per-game state** (kill
  counters, story flags, mod-specific quest progress). See
  [Savegame-scoped data](#per-mod-savegame-data-parasitesavedata) below.

Both expose the same getter/setter API; the only differences are where the
data lives and when it's persisted.

## Per-mod settings (`parasite.settings`)

`parasite.settings` gives your mod a persistent key/value store, namespaced by
your `modID` and backed by the game's `settings.json`. No new file, no IPC of
your own.

## API

`parasite.settings` is `mods.ModSettings`:

```haxe
typedef ModSettings = {
  function get(key: String): Dynamic;
  function getInt(key: String, ?def: Int): Int;
  function getFloat(key: String, ?def: Float): Float;
  function getBool(key: String, ?def: Bool): Bool;
  function getString(key: String, ?def: String): String;
  function set(key: String, value: Dynamic): Void;
  function remove(key: String): Void;
  function all(): Dynamic;
}
```

| Method        | Behavior                                                                         |
|---------------|----------------------------------------------------------------------------------|
| `get`         | raw value, or `null` if unset. Round-trips any JSON-serializable value (String/Int/Float/Bool/Array/object). |
| `getInt`      | typed Int; numeric or numeric-string storage; `null`/unparseable → `def` (default `0`). |
| `getFloat`    | typed Float; `null`/NaN → `def` (default `0.0`).                                 |
| `getBool`     | typed Bool; accepts `true/false`, `1/0`, `'1'/'0'`, `'true'/'false'`; anything else → `def` (default `false`). |
| `getString`   | typed String; `null` → `def` (default `null`); other values coerced to string.   |
| `set`         | store and persist immediately. **Throws** if your bucket would exceed 16 KiB.    |
| `remove`      | delete a key and persist; no-op if absent.                                       |
| `all`         | shallow copy of your full bucket; safe to mutate (it's a copy).                  |

Prefer the typed getters for primitives — they coerce and apply a default.

## Example

```haxe
public static function init(parasite: ModRuntime)
{
  var boots = parasite.settings.getInt('boots');     // 0 on first ever launch
  parasite.settings.set('boots', boots + 1);
  trace('[mymod] launch #' + parasite.settings.getInt('boots'));
}
```

## Where it lives

Your values sit under `mods.<modID>` in the shared `settings.json`:

```json
{
  "fullscreen": "1",
  "mods": {
    "com.you.mymod": {
      "boots": 7,
      "difficulty": "hard"
    }
  }
}
```

The store is keyed by your `modID`, so two mods never see each other's keys.

## Limits

- **16 KiB per-mod soft cap.** `set` throws if your bucket would exceed it. The
  whole `settings.json` shares the engine's existing 256 KiB cap, so the per-mod
  cap stops one runaway mod from exhausting the file.
- This is for small config/state, not bulk data. A mod that needs to persist
  large or per-save state should write into the save instead (the save records
  active mods; see the engine design doc, save compatibility section).
- There is no in-game settings editor in v1 — users change values by editing
  `settings.json` by hand. A Mods-tab settings UI is a future item.

## Per-mod savegame data (`parasite.savedata`)

`parasite.savedata` (type `mods.ModSaveData`) is the same getter/setter shape
as `parasite.settings`, but backed by the **active savegame** instead of
`settings.json`. Use it for any state that should live and die with a single
playthrough — kill counters, faction reputation, mod-specific story flags.

The store is namespaced by `modID` under `game.modData`:

```jsonc
// inside the savegame
"modData": {
  "com.you.chainsaw": { "kills": 17 },
  "com.you.othermod": { "questStage": "act2" }
}
```

### When data persists

- `set` writes to the live bucket — **no immediate disk write.** The value is
  picked up by the next `Saver.save` (player saves the game).
- The bucket is reloaded when the player loads a slot. Mods don't get a load
  hook — read keys lazily in your event handlers; `getInt('kills', 0)` returns
  `0` on a fresh game and the saved value after load.
- Starting a new game clears `game.modData` (mod `init()` re-fires; mod's own
  bucket is recreated on first `set` / `get`).

### Compared to `parasite.settings`

| Concern                       | `parasite.settings`            | `parasite.savedata`           |
|-------------------------------|--------------------------------|-------------------------------|
| Backing store                 | `settings.json` (electron config) | active savegame             |
| Lifetime                      | cross-run, cross-savegame      | per-playthrough               |
| Persisted                     | on every `set` / `remove`      | on next `Saver.save`          |
| Cap                           | 16 KiB per mod (soft)          | bounded by savegame size only |
| Reload semantics              | always live                    | reloaded on slot load         |

### Example

```haxe
public static function init(parasite: ModRuntime)
{
  parasite.events.onAIDie(function(e) {
    var n = parasite.savedata.getInt('kills', 0);
    parasite.savedata.set('kills', n + 1);
  });

  parasite.events.onFinishPre(function(e) {
    if (e.result != 'lose') return;
    var kills = parasite.savedata.getInt('kills', 0);
    e.text = 'You took ' + kills + ' with you on the way out.';
    e.img = 'mymod-game-over';
  });
}
```

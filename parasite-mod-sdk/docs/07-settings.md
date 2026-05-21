# Per-mod settings

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

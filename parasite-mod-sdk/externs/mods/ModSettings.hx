// per-mod persistent k/v settings facade extern
// mirrors engine src/mods/ModSettings.hx public surface
// backed by settings.json under mods.<modID>.<key>; persists on every set/remove
package mods;

typedef ModSettings = {
  // fetch stored value by key; returns null if unset.
  // value type round-trips intact (String/Int/Float/Bool/Array/object) via JSON.
  // for primitives prefer typed getInt/getFloat/getBool/getString below
  function get(key: String): Dynamic;
  // typed Int fetch; accepts numeric or numeric-string storage.
  // null / unparseable → def (default 0)
  function getInt(key: String, ?def: Int): Int;
  // typed Float fetch; null / NaN → def (default 0.0)
  function getFloat(key: String, ?def: Float): Float;
  // typed Bool fetch; accepts true/false, 1/0, '1'/'0', 'true'/'false'.
  // anything else → def (default false)
  function getBool(key: String, ?def: Bool): Bool;
  // typed String fetch; null → def (default null); any other value coerced to string
  function getString(key: String, ?def: String): String;
  // store value under key; persists settings.json immediately.
  // throws if this mod's bucket would exceed 16 KiB (per-mod soft cap)
  function set(key: String, value: Dynamic): Void;
  // delete key from this mod's bucket; persists settings.json. no-op if absent
  function remove(key: String): Void;
  // shallow copy of this mod's full bucket; safe to mutate
  function all(): Dynamic;
}

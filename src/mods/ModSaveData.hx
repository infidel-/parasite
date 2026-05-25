// per-mod savegame-scoped data facade — namespaced k/v storage backed by
// game.modData.<modID>. unlike ModSettings (electron config, cross-run), this
// is serialized with the savegame and reloaded when the player loads a slot.
// no per-set persistence — the Saver picks up game.modData on the next save
package mods;

import game.Game;

class ModSaveData
{
  static var game: Game;
  var modID: String;

// returns the live per-mod bucket, creating it on first access
  function bucket(): Dynamic
    {
      var b = Reflect.field(game.modData, modID);
      if (b == null)
        {
          b = {};
          Reflect.setField(game.modData, modID, b);
        }
      return b;
    }

// returns stored value or null if unset; structured JSON (any type) round-trips intact
  public function get(key: String): Dynamic
    {
      return Reflect.field(bucket(), key);
    }

// typed Int getter; accepts numeric or numeric-string storage. null/unparseable → def
  public function getInt(key: String, ?def: Int = 0): Int
    {
      var v: Dynamic = Reflect.field(bucket(), key);
      if (v == null) return def;
      var n = Std.parseInt(Std.string(v));
      return (n == null) ? def : n;
    }

// typed Float getter; null/NaN → def
  public function getFloat(key: String, ?def: Float = 0.0): Float
    {
      var v: Dynamic = Reflect.field(bucket(), key);
      if (v == null) return def;
      var n = Std.parseFloat(Std.string(v));
      return Math.isNaN(n) ? def : n;
    }

// typed Bool getter; accepts true/false, 1/0, '1'/'0', 'true'/'false'. else def
  public function getBool(key: String, ?def: Bool = false): Bool
    {
      var v: Dynamic = Reflect.field(bucket(), key);
      if (v == null) return def;
      if (v == true || v == 1 || v == '1' || v == 'true') return true;
      if (v == false || v == 0 || v == '0' || v == 'false') return false;
      return def;
    }

// typed String getter; null → def; any other value coerced via Std.string
  public function getString(key: String, ?def: String = null): String
    {
      var v: Dynamic = Reflect.field(bucket(), key);
      return (v == null) ? def : Std.string(v);
    }

// writes key into this mod's bucket; persists with next savegame write.
// validates value is JSON-safe and free of engine refs/cycles so a bad
// write is rejected at the call site rather than corrupting the next save
// or silently mangling state on load. throws with the full path of the
// offending sub-value
  public function set(key: String, value: Dynamic): Void
    {
      validate(value, key, []);
      Reflect.setField(bucket(), key, value);
    }

// recursive JSON-safety check; throws with a descriptive path on cycles,
// function refs, live class instances (engine objects, Maps, Dates…),
// or non-finite numbers. plain anon objects, arrays, primitives, and
// Haxe enums (Saver handles those via _classID wrapper) are allowed
  static function validate(v: Dynamic, path: String,
      visited: Array<Dynamic>): Void
    {
      // primitives, null
      if (v == null ||
          Std.isOfType(v, Bool) ||
          Std.isOfType(v, String) ||
          Std.isOfType(v, Int))
        return;
      // floats — reject NaN / Infinity (Json.stringify silently coerces to null)
      if (Std.isOfType(v, Float))
        {
          var f: Float = v;
          if (Math.isNaN(f) || !Math.isFinite(f))
            throw 'mod-savedata: invalid value at \'' + path +
              '\' — non-finite number (' + f + '). use null or 0.';
          return;
        }
      // function / closure
      if (Reflect.isFunction(v))
        throw 'mod-savedata: invalid value at \'' + path +
          '\' — function references are not serializable. ' +
          'store data, not closures.';
      // array — recurse with cycle guard
      if (Std.isOfType(v, Array))
        {
          if (Lambda.has(visited, v))
            throw 'mod-savedata: invalid value at \'' + path +
              '\' — cyclic structure detected.';
          visited.push(v);
          var arr: Array<Dynamic> = v;
          for (i in 0...arr.length)
            validate(arr[i], path + '[' + i + ']', visited);
          visited.pop();
          return;
        }
      // haxe enum value — Saver serializes via _classID wrapper, allow
      switch (Type.typeof(v))
        {
          case TEnum(_): return;
          default:
        }
      // typed class instance — engine _SaveObject (Cult/AI/Area/Game/…),
      // Map, Date, DOM node, mod's own class. all lose identity / shape on
      // reload. reject with a hint pointing at the lookup-by-id pattern
      var cl = Type.getClass(v);
      if (cl != null)
        {
          var clname = Type.getClassName(cl);
          throw 'mod-savedata: invalid value at \'' + path +
            '\' — cannot store live class instance (' + clname + '). ' +
            'store an id and look up via game.getCultByID / area.getAI / ' +
            'world.get on read, or snapshot the fields you need into a ' +
            'plain object.';
        }
      // plain anonymous object — recurse fields with cycle guard
      if (Type.typeof(v) == TObject)
        {
          if (Lambda.has(visited, v))
            throw 'mod-savedata: invalid value at \'' + path +
              '\' — cyclic structure detected.';
          visited.push(v);
          for (f in Reflect.fields(v))
            validate(Reflect.field(v, f), path + '.' + f, visited);
          visited.pop();
          return;
        }
      // anything else (TUnknown, etc)
      throw 'mod-savedata: invalid value at \'' + path +
        '\' — unsupported type.';
    }

// removes key from this mod's bucket; no-op if absent
  public function remove(key: String): Void
    {
      Reflect.deleteField(bucket(), key);
    }

// shallow copy of this mod's bucket; safe to mutate by caller
  public function all(): Dynamic
    {
      var b = bucket();
      var out = {};
      for (f in Reflect.fields(b))
        Reflect.setField(out, f, Reflect.field(b, f));
      return out;
    }

  function new(modID: String)
    { this.modID = modID; }

// boot-time wiring; ModLoader.load calls this before building per-mod facades
  public static function init(g: Game)
    {
      game = g;
    }

// builds per-mod facade; called by ModLoader per import
  public static function api(modID: String): ModSaveData
    {
      return new ModSaveData(modID);
    }
}

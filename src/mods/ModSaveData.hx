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

// writes key into this mod's bucket; persists with next savegame write
  public function set(key: String, value: Dynamic): Void
    {
      Reflect.setField(bucket(), key, value);
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

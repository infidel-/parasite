// per-mod settings facade — namespaced k/v storage backed by Config.mods.<modID>
// thin wrapper; no IPC, no separate storage layer
package mods;

import haxe.Json;
import game.Game;

class ModSettings
{
  // per-mod soft cap to keep one runaway mod from blowing settings.json
  static inline var PER_MOD_CAP_BYTES = 16 * 1024;

  static var game: Game;
  var modID: String;
  // direct ref to game.config.mods.<modID> — created on first access if absent
  var bucket: Dynamic;

  function new(modID: String)
    {
      this.modID = modID;
      var all = game.config.mods;
      var b = Reflect.field(all, modID);
      if (b == null)
        {
          b = {};
          Reflect.setField(all, modID, b);
        }
      bucket = b;
    }

// returns stored value or null if unset; structured JSON (any type) round-trips intact
  public function get(key: String): Dynamic
    {
      return Reflect.field(bucket, key);
    }

// typed Int getter; accepts numeric or numeric-string storage. null/unparseable → def
  public function getInt(key: String, ?def: Int = 0): Int
    {
      var v: Dynamic = Reflect.field(bucket, key);
      if (v == null) return def;
      var n = Std.parseInt(Std.string(v));
      return (n == null) ? def : n;
    }

// typed Float getter; null/NaN → def
  public function getFloat(key: String, ?def: Float = 0.0): Float
    {
      var v: Dynamic = Reflect.field(bucket, key);
      if (v == null) return def;
      var n = Std.parseFloat(Std.string(v));
      return Math.isNaN(n) ? def : n;
    }

// typed Bool getter; accepts true/false, 1/0, '1'/'0', 'true'/'false'. else def
  public function getBool(key: String, ?def: Bool = false): Bool
    {
      var v: Dynamic = Reflect.field(bucket, key);
      if (v == null) return def;
      if (v == true || v == 1 || v == '1' || v == 'true') return true;
      if (v == false || v == 0 || v == '0' || v == 'false') return false;
      return def;
    }

// typed String getter; null → def; any other value coerced via Std.string
  public function getString(key: String, ?def: String = null): String
    {
      var v: Dynamic = Reflect.field(bucket, key);
      return (v == null) ? def : Std.string(v);
    }

// writes key, enforces per-mod 16 KiB cap, persists config to disk
  public function set(key: String, value: Dynamic): Void
    {
      var prev = Reflect.field(bucket, key);
      Reflect.setField(bucket, key, value);
      var size = Json.stringify(bucket).length;
      if (size > PER_MOD_CAP_BYTES)
        {
          // rollback before throw to keep invariant: persisted state always ≤ cap
          if (prev == null)
            Reflect.deleteField(bucket, key);
          else
            Reflect.setField(bucket, key, prev);
          throw 'mod [' + modID + '] settings exceed ' +
            PER_MOD_CAP_BYTES + ' B cap (would be ' + size + ' B)';
        }
      game.config.save(false);
    }

// removes key and persists; no-op if key absent
  public function remove(key: String): Void
    {
      Reflect.deleteField(bucket, key);
      game.config.save(false);
    }

// shallow copy of this mod's bucket; safe to mutate by caller
  public function all(): Dynamic
    {
      var out = {};
      for (f in Reflect.fields(bucket))
        Reflect.setField(out, f, Reflect.field(bucket, f));
      return out;
    }

// boot-time wiring; ModLoader.load calls this before building per-mod facades
  public static function init(g: Game)
    {
      game = g;
    }

// builds per-mod facade; called by ModLoader per import
  public static function api(modID: String): ModSettings
    {
      return new ModSettings(modID);
    }
}

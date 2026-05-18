// renderer-side mod registry
package mods;

import game.Game;
import js.Browser.console;

class ModRegistry
{
  public static var all: Array<ModInfo> = [];
  public static var enabled: Array<ModInfo> = [];
  public static var failed: Map<String, String> = new Map();

// receive scanned mod list from main, filter by profile.disabledMods, sort by id
  public static function init(game: Game, raw: Array<ModInfo>)
    {
      all = [];
      enabled = [];
      failed = new Map();
      if (raw == null)
        {
          console.warn('[mods] host:mods:list returned null');
          return;
        }

      // log raw list from main
      console.log('[mods] registry init: ' + raw.length + ' mod(s) from main');
      for (info in raw)
        {
          all.push(info);
          console.log('[mods]   found: ' + info.id + ' v' + info.version +
            ' (api ' + info.modApiVersion + ', source ' + info.source + ')');
        }

      // filter out disabled mods; build map for quick lookup
      var disabled = new Map<String, Bool>();
      for (id in game.profile.object.disabledMods)
        disabled.set(id, true);
      for (info in all)
        {
          if (disabled.exists(info.id))
            {
              console.log('[mods]   skip ' + info.id + ' (disabled in profile)');
              continue;
            }
          enabled.push(info);
        }

      // stable sort by id (v1: no toposort yet — loadAfter/loadBefore land in phase C)
      enabled.sort(function(a, b) return Reflect.compare(a.id, b.id));

      console.log('[mods] registry: ' + all.length + ' found, ' + enabled.length + ' enabled');
    }

// record per-mod failure reason; subsequent integrations skip this mod
  public static function markFailed(id: String, err: String)
    {
      failed.set(id, err);
    }

// look up mod info by id; returns null if unknown
  public static function byID(id: String): ModInfo
    {
      for (info in all)
        if (info.id == id)
          return info;
      return null;
    }
}

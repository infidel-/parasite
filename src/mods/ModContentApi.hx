// per-mod content-registration facade exposed as parasite.api
// thin wrapper that records modID for logging, delegates to ModContentRegistry
// see mod-design.md §8.7
package mods;

import js.Browser.console;

class ModContentApi
{
  var modID: String;

  function new(modID: String)
    {
      this.modID = modID;
    }

// register a custom item class; survives ItemsConst.init re-runs
// if ItemsConst already inited, also adds the instance live so first new-game sees it
  public function registerItem(cls: Class<ItemInfo>)
    {
      ModContentRegistry.items.push(cls);
      console.log('[mods] register item: ' + modID + '/' + Type.getClassName(cls));
      if (const.ItemsConst.infos != null)
        const.ItemsConst.addInfo(game.Game.inst, cls);
    }

// builds a per-mod api instance; called by ModLoader per import
  public static function forMod(modID: String): ModContentApi
    {
      return new ModContentApi(modID);
    }
}

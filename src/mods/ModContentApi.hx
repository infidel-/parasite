// per-mod content-registration facade exposed as parasite.api
// thin wrapper that records modID for logging + prefix enforcement,
// delegates to ModContentRegistry
package mods;

import const.PediaConst;
import const.PediaConst._PediaGroupInfo;
import js.Browser.console;

class ModContentApi
{
  var modID: String;
  var prefix: String;

  function new(modID: String)
    {
      this.modID = modID;
      this.prefix = 'mod-' + modID + '-';
    }

// id-prefix gate: every mod-registered content id must start with
// `mod-<modID>-` to avoid colliding with core ids and ids from other mods.
// returns true if id is acceptable; logs error + returns false otherwise.
  function checkPrefix(kind: String, id: String): Bool
    {
      if (id != null &&
          StringTools.startsWith(id, prefix))
        return true;
      error(kind, 'id "' + id + '" must start with "' + prefix + '"');
      return false;
    }

// emit registration failure to devtools console + session log
  function error(kind: String, msg: String)
    {
      var line = '[mods] register ' + kind + ' rejected (' +
        modID + '): ' + msg;
      console.error(line);
#if electron
      try { HostBridge.logAppend('MOD REGISTER REJECT [' + modID + '] ' +
        kind + ': ' + msg + '\n'); }
      catch (e: Dynamic) {}
#end
    }

// register a custom item class. constructs an instance to read the id and
// enforce the mod-<modID>- prefix; rejects + logs on violation.
// survives ItemsConst.init re-runs. if ItemsConst already inited,
// also adds the instance live so first new-game sees it.
  public function registerItem(cls: Class<ItemInfo>)
    {
      // probe the instance to learn id (cls itself doesn't expose it)
      var probe: ItemInfo;
      try { probe = Type.createInstance(cls, [game.Game.inst]); }
      catch (e: Dynamic)
        {
          error('item', 'ctor threw: ' + e);
          return;
        }
      if (!checkPrefix('item', probe.id))
        return;

      // all checks passed; add to registry
      ModContentRegistry.items.push(cls);
      console.log('[mods] register item: ' + modID + '/' + probe.id);
      if (const.ItemsConst.infos != null)
        const.ItemsConst.addInfo(game.Game.inst, cls);
    }

// register a mod pedia group with its articles. group id and every
// article id must start with mod-<modID>-; rejects whole group on first
// violation. if PediaConst already inited, also appends live.
  public function registerPediaEntry(info: _PediaGroupInfo)
    {
      // probe the info to enforce group + article id prefixes
      if (info == null)
        {
          error('pedia', 'info is null');
          return;
        }
      if (!checkPrefix('pedia', info.id))
        return;
      if (info.articles == null)
        {
          error('pedia', 'group "' + info.id + '" has no articles');
          return;
        }
      for (a in info.articles)
        if (!checkPrefix('pedia', a.id))
          return;

      // all checks passed; add to registry
      ModContentRegistry.pediaContents.push(info);
      console.log('[mods] register pedia: ' + modID + '/' + info.id +
        ' (' + info.articles.length + ' article(s))');
      if (PediaConst.inited)
        PediaConst.addGroup(info);

      // auto-learn mod articles so they appear in the pedia immediately
      for (a in info.articles)
        game.Game.inst.profile.addPediaArticle(a.id, false);
    }

// builds a per-mod api instance; called by ModLoader per import
  public static function forMod(modID: String): ModContentApi
    {
      return new ModContentApi(modID);
    }
}

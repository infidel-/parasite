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

// register an AI trait under a named category.
// info.id must start with mod-<modID>-; category is a free-form string that
// is appended to TraitsConst.traits live. existing builtin categories are
// 'misc', 'skill', 'mind', 'body', 'cultBasic'; mods may introduce new ones.
  public function registerTrait(category: String, info: _TraitInfo)
    {
      if (info == null)
        {
          error('trait', 'info is null');
          return;
        }
      if (category == null || category == '')
        {
          error('trait', 'category is empty for id "' + info.id + '"');
          return;
        }
      if (!checkPrefix('trait', info.id))
        return;

      // all checks passed; record + add live
      ModContentRegistry.traits.push({ category: category, info: info });
      console.log('[mods] register trait: ' + modID + '/' + info.id +
        ' in group "' + category + '"');
      const.TraitsConst.addTrait(category, info);
    }

// register a skill/knowledge.
// info.id must start with mod-<modID>-; appended to SkillsConst.skills live.
// set isKnowledge/isBool for knowledge-style entries (see SkillInfo).
  public function registerSkill(info: const.SkillsConst.SkillInfo)
    {
      if (info == null)
        {
          error('skill', 'info is null');
          return;
        }
      if (!checkPrefix('skill', info.id))
        return;

      // all checks passed; record + add live
      ModContentRegistry.skills.push(info);
      console.log('[mods] register skill: ' + modID + '/' + info.id);
      const.SkillsConst.addSkill(info);
    }

// register an evolution improvement.
// info.id must start with mod-<modID>-; appended to EvolutionConst.improvements
// live. id collision = last-wins + log.
  public function registerEvolution(info: const.EvolutionConst.ImprovInfo)
    {
      if (info == null)
        {
          error('evolution', 'info is null');
          return;
        }
      if (!checkPrefix('evolution', info.id))
        return;

      // all checks passed; record + add live
      ModContentRegistry.improvements.push(info);
      console.log('[mods] register evolution: ' + modID + '/' + info.id);
      const.EvolutionConst.addImprovement(info);
    }

// register a custom goal.
// info.id must start with mod-<modID>-; added to const.Goals.map live.
// id collision = last-wins + log.
  public function registerGoal(info: GoalInfo)
    {
      if (info == null)
        {
          error('goal', 'info is null');
          return;
        }
      if (!checkPrefix('goal', info.id))
        return;

      // all checks passed; record + add live
      ModContentRegistry.goals.push(info);
      console.log('[mods] register goal: ' + modID + '/' + info.id);
      const.Goals.addGoal(info);
    }

// builds a per-mod api instance; called by ModLoader per import
  public static function forMod(modID: String): ModContentApi
    {
      return new ModContentApi(modID);
    }
}

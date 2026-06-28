// renderer-side registry for mod-added content
// engine const-table init() iterates these alongside built-ins
package mods;

import const.PediaConst._PediaGroupInfo;
import const.SkillsConst.SkillInfo;
import const.EvolutionConst.ImprovInfo;

class ModContentRegistry
{
  // mod-registered item classes; appended after built-ins in ItemsConst.init
  public static var items: Array<Class<ItemInfo>> = [];

  // mod-registered pedia groups (each holds its own articles array);
  // appended after built-ins in PediaConst.init
  public static var pediaContents: Array<_PediaGroupInfo> = [];

  // mod-registered AI traits paired with their target category id;
  // pushed live into TraitsConst.traits at registration time
  public static var traits: Array<_RegisteredTrait> = [];

  // mod-registered skill/knowledge infos; pushed live into SkillsConst.skills
  // at registration time
  public static var skills: Array<SkillInfo> = [];

  // mod-registered evolution improvements; pushed live into
  // EvolutionConst.improvements at registration time
  public static var improvements: Array<ImprovInfo> = [];

  // mod-registered goals; pushed live into const.Goals.map at registration time
  public static var goals: Array<GoalInfo> = [];

  // mod-registered AI spawn types: type string -> AI subclass; consulted by
  // game.createAI as a fall-through after the built-in types
  public static var aiTypes: Map<String, Class<ai.AI>> = [];

  // mod-registered area-action contributors: id -> callback; each is invoked at
  // the tail of PlayerArea.updateActionList and adds its own action(s)
  public static var areaActions: Map<String, game.Game -> Void> = [];
}

// pending/recorded mod trait registration
typedef _RegisteredTrait = {
  var category: String;
  var info: _TraitInfo;
}

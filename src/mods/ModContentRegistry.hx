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
}

// pending/recorded mod trait registration
typedef _RegisteredTrait = {
  var category: String;
  var info: _TraitInfo;
}

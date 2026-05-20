// per-mod content-registration facade extern
// mirrors engine src/mods/ModContentApi.hx public surface
// all mod-registered ids must start with `mod-<modID>-` (prefix enforced;
// violations are rejected, logged and reported to The Group)
package mods;

import const.PediaConst._PediaGroupInfo;

typedef ModContentApi = {
  // register a custom item class; survives ItemsConst.init re-runs
  function registerItem(cls: Class<ItemInfo>): Void;
  // register a pedia group + its articles; survives PediaConst.init re-runs
  function registerPediaEntry(info: _PediaGroupInfo): Void;
  // register an AI trait under a category id (e.g. 'misc', 'skill', 'mind',
  // 'body', 'cultBasic', or a custom mod-defined group). id collision within
  // the same group = last-wins + log
  function registerTrait(category: String, info: _TraitInfo): Void;
  // register a skill/knowledge; appended to SkillsConst.skills live.
  // id collision = last-wins + log
  function registerSkill(info: _SkillInfo): Void;
}

// skill / knowledge info shape (mirrors engine const.SkillsConst.SkillInfo)
// supplied to ModContentApi.registerSkill.

typedef _SkillInfo = {
  // skill id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerSkill; id collision = last-wins + log)
  var id: _Skill;
  // optional UI grouping label (e.g. 'Combat', 'Manipulation'); null = ungrouped
  @:optional var group: String;
  // display name shown in skill lists, console, training UI
  var name: String;
  // starting level granted when the skill is first added (0-100 scale)
  var defaultLevel: Int;
  // optional: true marks this as a knowledge (separate UI section, not a skill)
  @:optional var isKnowledge: Bool;
  // optional: true makes it a boolean knowledge (known/unknown, no level)
  @:optional var isBool: Bool;
}

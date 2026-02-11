typedef WeaponInfo = {
  @:optional var sound: AISound;
  @:optional var soundMiss: AISound;
  var isRanged: Bool;
  var skill: _Skill;
  var minDamage: Int;
  var maxDamage: Int;
  var verb1: String;
  var verb2: String;
  var type: _WeaponType;
  @:optional var spawnBlood: Bool;
  var canConceal: Bool;
};

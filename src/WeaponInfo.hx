typedef WeaponInfo = {
  @:optional var sound: AISound;
  @:optional var soundMiss: AISound;
  var isRanged: Bool;
  var skill: _Skill;
  var minDamage: Int;
  var maxDamage: Int;
  var textMiss: String; // T() template: {attacker:The} misses {target}
  var textMissYou: String; // T() template: {attacker:The} misses you (the parasite: French puts the pronoun before the verb)
  var textHit: String; // T() template: {attacker:The} hits {target} for {damage}
  var textHitYou: String; // T() template: {attacker:The} hits you for {damage}
  @:optional var textStun: String; // T() template, stun weapons: {attacker:The} stuns {target} for {rounds}
  @:optional var verb1: String; // 1.0 mod API, instead of the text* templates: 'rip' (English only)
  @:optional var verb2: String; // 1.0 mod API, instead of the text* templates: 'rips' (English only)
  var type: _WeaponType;
  @:optional var attackEffect: _AttackEffect;
  @:optional var spawnBlood: Bool;
  @:optional var projectile: String;
  var canConceal: Bool;
};

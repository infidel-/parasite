typedef _DamageBonus = {
  var name: String;
  @:optional var chance: Float; // chance of damage
  @:optional var min: Int; // min damage
  @:optional var max: Int; // max damage
  @:optional var val: Int; // fixed value (alternative)
}

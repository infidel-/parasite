// item info

package game;

typedef _ItemInfo =
{
  var id: String; // item id
  var type: String; // item type
  @:optional var name: String; // item name
  @:optional var names: Array<String>; // item names (one is picked on item generation)
  var unknown: String; // item name when it's unknown

  // weapon-related stats; null if not a weapon
  @:optional var weapon: {
    @:optional var sounds: Array<String>; // attack sounds
    var isRanged: Bool; // is this weapon type ranged?
    var skill: _Skill; // associated skill
    var minDamage: Int; // min weapon damage
    var maxDamage: Int; // max weapon damage
    var verb1: String; // X tries to $verb1 you; but misses.
    var verb2: String; // X $verb2 you for Y damage.
    var type: _WeaponType; // weapon damage type
  };
  @:optional var armor: {
    var canAttach: Bool; // armor can disable parasite attach
    var damage: Int; // value of damage reduced
  };

  @:optional var areaObjectClass: Dynamic; // area object class
}


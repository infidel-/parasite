// item info

package game;

typedef _ItemInfo =
{
  var id: String; // item id
  var type: String; // item type
  @:optional var isKnown: Bool; // always known
  @:optional var name: String; // item name
  @:optional var names: Array<String>; // item names (one is picked on item generation)
  var unknown: String; // item name when it's unknown

  // weapon-related stats; null if not a weapon
  @:optional var weapon: {
    @:optional var sound: AISound; // attack sound
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
    var needleDeathChance: Int; // chance of paralyzing needles killing
  };

  @:optional var areaObjectClass: Dynamic; // area object class
  @:optional var onLearn: Game -> Player -> Void; // called on learning about this item
}


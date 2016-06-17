// item info

package game;

typedef ItemInfo =
{
  var id: String; // item id
  var type: String; // item type
  @:optional var name: String; // item name
  @:optional var names: Array<String>; // item names (one is picked on item generation)
  var unknown: String; // item name when it's unknown
  @:optional var verb1: String; // X tries to $verb1 you; but misses.
  @:optional var verb2: String; // X $verb2 you for Y damage.
  @:optional var weaponStats: { // weapon-related stats; null if not a weapon
    var isRanged: Bool; // is this weapon type ranged?
    var skill: _Skill; // associated skill
    var minDamage: Int; // min weapon damage
    var maxDamage: Int; // max weapon damage
    };
  @:optional var areaObjectClass: Dynamic; // area object class

//  public function getInt(key: String): Int;
/*
    {
      return 15;
    }
*/
}


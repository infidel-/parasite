// item info

typedef ItemInfo =
{
  id: String, // item id
  type: String, // item type
  ?name: String, // item name
  ?names: Array<String>, // item names (one is picked on item generation)
  unknown: String, // item name when it's unknown
  ?verb1: String, // X tries to $verb1 you, but misses.
  ?verb2: String, // X $verb2 you for Y damage.
  ?weaponStats: { // weapon-related stats, null if not a weapon
    isRanged: Bool, // is this weapon type ranged? 
    skill: _Skill, // associated skill
    minDamage: Int, // min weapon damage
    maxDamage: Int // mxa weapon damage
    },
}


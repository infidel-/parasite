// item list

class ConstItems
{
// return item info by id
  public static function getInfo(id: String): ItemInfo
    {
      for (ii in items)
        if (ii.id == id)
          return ii;

      return null;
    }


// special item: fists
  public static var fists: ItemInfo = 
    {
      id: 'fists',
      name: 'fists',
      verb1: 'punch',
      verb2: 'punches',
      weaponStats:
        {
          isRanged: false,
          skill: 'fists',
          minDamage: 1,
          maxDamage: 3
        }
    };


// all item infos
  public static var items: Array<ItemInfo> = [
    {
      id: 'pistol',
      name: 'pistol',
      verb1: 'shoot',
      verb2: 'shoots',
      weaponStats:
        {
          isRanged: true,
          skill: 'pistol',
          minDamage: 1,
          maxDamage: 10
        }
    }
    ];
}


// item info

typedef ItemInfo =
{
  var id: String; // item id
  var name: String; // item name
  var verb1: String; // X tries to $verb1 you, but misses.
  var verb2: String; // X $verb2 you for Y damage.
  var weaponStats: { // weapon-related stats, null if not a weapon
    isRanged: Bool, // is this weapon type ranged? 
    skill: String, // associated skill
    minDamage: Int, // min weapon damage
    maxDamage: Int // mxa weapon damage
    };
}
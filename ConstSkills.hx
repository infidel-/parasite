// item list

class ConstItems
{
// return item info by id
  public static function getInfo(id: String): Item
    {
      for (ii in items)
        if (ii.id == id)
          return ii;

      return null;
    }


  public static var items: Array<ItemInfo> = [
    {
      id: 'pistol',
      name: 'pistol',
      weaponStats:
        {
          isRanged: true,
          skill: 'pistol',
          minDamage: 1,
          maxDamage: 8
        }
    }
    ];
}


// item info

typedef ItemInfo =
{
  var id: String; // item id
  var name: String; // item name
  var weaponStats: { // weapon-related stats, null if not a weapon
    isRanged: Bool, // is this weapon type ranged? 
    skill: String, // associated skill
    minDamage: Int, // min weapon damage
    maxDamage: Int // mxa weapon damage
    };
}

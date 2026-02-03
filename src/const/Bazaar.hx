// bazaar constants

package const;

import haxe.ds.StringMap;

class Bazaar
{
// price for random melee weapon menu item
  public static var randomMeleePrice: Int = 2500;

// weights for random melee weapon roll
  public static var bazaarRandomMelee: Array<{ id: String, weight: Int }> = [
    { id: 'baton', weight: 20 },
    { id: 'brassKnuckles', weight: 20 },
    { id: 'knife', weight: 20 },
    { id: 'baseballBat', weight: 15 },
    { id: 'machete', weight: 15 },
    { id: 'katana', weight: 5 },
    { id: 'stunner', weight: 5 }
  ];

// price list for bazaar items
  public static var bazaarPrices: StringMap<Int> = initPrices();
  static function initPrices(): StringMap<Int>
    {
      var map: StringMap<Int> = [
        'randomMelee' => randomMeleePrice,
        'pistol' => 5000,
        'assaultRifle' => 10000,
        'combatShotgun' => 10000,
        'kevlarArmor' => 20000
      ];
      return map;
    }
}

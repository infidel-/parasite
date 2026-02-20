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
  public static var bazaarPrices: StringMap<_CultPower> = initPrices();
  static function initPrices(): StringMap<_CultPower>
    {
      var map: StringMap<_CultPower> = [
        'randomMelee' => {
          money: randomMeleePrice
        },
        'pistol' => {
          money: 5000,
          combat: 1
        },
        'assaultRifle' => {
          money: 10000,
          combat: 1
        },
        'combatShotgun' => {
          money: 10000,
          combat: 2
        },
        'kevlarArmor' => {
          money: 20000,
          combat: 2
        }
      ];
      return map;
    }
}

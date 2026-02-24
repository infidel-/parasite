package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class BumCult
{
// return ordeal info for the bum cult cell assault
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "Unauspr. Bum Litany",
        note: "A gutter cult of bums keeps chanting your enemy's liturgy in a low-city shell. Break their congregation before it hardens into a street crusade.",
        success: "The alley choir is silenced. Bedroll altars burn, and the low-city flock scatters into static hunger.",
        fail: "You are driven back through broken glass and rusted carts. The bum cult claims the district and recruits in daylight.",
        mission: MISSION_COMBAT,
        combat: {
          template: TARGET_WITH_GUARDS,
          targets: [
            {
              target: {
                isMale: true,
                job: "bum preacher",
                type: "bum",
                icon: "bum",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 1],
              loadout: loadoutBumPreacher,
            },
            {
              target: {
                job: "bum shivman",
                type: "bum",
                icon: "bum",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 2],
              loadout: loadoutBumMelee,
            },
            {
              target: {
                job: "bum zealot",
                type: "bum",
                icon: "bum",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 1],
              loadout: loadoutBumFists,
            },
            {
              target: {
                job: "bum bruiser",
                type: "bum",
                icon: "bum",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [0, 1, 2],
              loadout: loadoutBumMelee,
            },
            {
              target: {
                job: "bum scavenger",
                type: "bum",
                icon: "bum",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [0, 1, 2],
              loadout: loadoutBumFists,
            }
          ]
        }
      };
    }

// apply loadout for armed bum kultists
  static function loadoutBumMelee(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripRangedWeapons();
      if (!aiData.inventory.hasWeapon())
        {
          var melee = ['brassKnuckles', 'knife', 'baseballBat'];
          if (difficulty == HARD)
            melee.push('machete');
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }
      aiData.isAggressive = true;
    }

// apply loadout for bum preacher with bleeding weapon
  static function loadoutBumPreacher(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.addID('curvedKnife');
      aiData.isAggressive = true;
    }

// apply loadout for unarmed bum kultists
  static function loadoutBumFists(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.stripRangedWeapons();
      aiData.isAggressive = true;
    }
}

// data for generic combat profane ordeals
package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class CombatConst extends OrdealConst
{
// define combat profane ordeals
  public function new()
    {
      super();
      // define combat ordeal entries
      infos = [

        // first ordeal - strike a corporate cult head guarded by private security
        {
          name: "Unaussprechliche Head",
          note: "The Unaussprechliche Kult keeps its head in a corporate suite, flanked by two armed guards. Strike together or die alone.",
          success: "Head and guards fall. The kult fractures, rituals collapsing into static. The suite goes dark.",
          fail: "You are repelled. The head slips away, guards calling backup. The Unaussprechliche Kult grows bold.",
          mission: MISSION_COMBAT,
          combat: {
            template: TARGET_WITH_GUARDS,
            targets: [
              {
                target: {
                  job: "cult head",
                  type: "smiler",
                  icon: "smiler",
                  location: AREA_CORP,
                  helpAvailable: false,
                },
                amount: [1, 1, 1],
                loadout: loadoutCultHead,
              },
              {
                target: {
                  job: "security guard",
                  type: "security",
                  icon: "security",
                  location: AREA_CORP,
                  helpAvailable: false,
                },
                amount: [2, 2, 2],
                loadout: loadoutSecurityGuard,
              }
            ]
          }
        },

        // second ordeal - cleanse a bum kult cell entrenched in the low city
        {
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
                  icon: "casualCivilian",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [1, 1, 1],
                loadout: loadoutBumMelee,
              },
              {
                target: {
                  job: "bum shivman",
                  type: "bum",
                  icon: "casualCivilian",
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
                  icon: "casualCivilian",
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
                  icon: "casualCivilian",
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
                  icon: "casualCivilian",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [0, 1, 2],
                loadout: loadoutBumFists,
              }
            ]
          }
        },

        // third ordeal - break a thug syndicate cell in the low city
        {
          name: "Unauspr. Thug Syndicate",
          note: "A street syndicate keeps your enemy's rite alive in crackhouse chapels and shuttered courtyards. Drugged zealots charge first while gunmen cover the flock.",
          success: "Their block liturgy collapses. The katana priest falls, shooters scatter, and the street altar bleeds out into rainwater.",
          fail: "You are pinned by crossfire and rushed by howling blades. The thug cult keeps the block and recruits another night.",
          mission: MISSION_COMBAT,
          combat: {
            template: TARGET_WITH_GUARDS,
            targets: [
              {
                target: {
                  isMale: true,
                  job: "thug lieutenant",
                  type: "thug",
                  icon: "thug",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [1, 1, 1],
                loadout: loadoutThugLeader,
              },
              {
                target: {
                  job: "thug bruiser",
                  type: "thug",
                  icon: "thug",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [1, 1, 2],
                loadout: loadoutThugMelee,
              },
              {
                target: {
                  job: "drugged thug",
                  type: "thug",
                  icon: "thug",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [1, 1, 2],
                loadout: loadoutThugDrugged,
              },
              {
                target: {
                  job: "thug gunman",
                  type: "thug",
                  icon: "thug",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [0, 1, 2],
                loadout: loadoutThugPistol,
              },
              {
                target: {
                  job: "thug shooter",
                  type: "thug",
                  icon: "thug",
                  location: AREA_CITY_LOW,
                  helpAvailable: false,
                },
                amount: [0, 1, 1],
                loadout: loadoutThugPistol,
              }
            ]
          }
        }
      ];
    }

// remove ranged weapons from inventory
  static function stripRangedWeapons(aiData: AIData)
    {
      var toRemove = [];
      for (item in aiData.inventory)
        if (item.info.weapon != null &&
            item.info.weapon.isRanged)
          toRemove.push(item);
      for (item in toRemove)
        aiData.inventory.removeItem(item);
    }

// remove all weapons from inventory
  static function stripAllWeapons(aiData: AIData)
    {
      var toRemove = [];
      for (item in aiData.inventory)
        if (item.info.weapon != null)
          toRemove.push(item);
      for (item in toRemove)
        aiData.inventory.removeItem(item);
    }

// apply loadout for the corporate cult head
  static function loadoutCultHead(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      switch (difficulty)
        {
          case HARD:
            if (!aiData.inventory.has('pistol'))
              aiData.inventory.addID('pistol');
            aiData.skills.addID(SKILL_PISTOL, 20 + Std.random(10));
          case EASY:
            1;
          case NORMAL:
            1;
          default:
        }
    }

// apply loadout for armed security guards
  static function loadoutSecurityGuard(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      switch (difficulty)
        {
          case EASY:
            stripRangedWeapons(aiData);
          case NORMAL:
            1;
          case HARD:
            if (!aiData.inventory.has('pistol'))
              aiData.inventory.addID('pistol');
            if (aiData.inventory.clothing.id != 'kevlarArmor')
              aiData.inventory.addID('kevlarArmor', true);
            aiData.skills.addID(SKILL_PISTOL, 60 + Std.random(20));
          default:
        }
    }

// apply loadout for armed bum kultists
  static function loadoutBumMelee(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      stripRangedWeapons(aiData);
      if (aiData.inventory.getFirstWeapon() == null)
        {
          var melee = ['brassKnuckles', 'knife', 'baseballBat'];
          if (difficulty == HARD)
            melee.push('machete');
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }
      aiData.isAggressive = true;
    }

// apply loadout for unarmed bum kultists
  static function loadoutBumFists(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      stripAllWeapons(aiData);
      stripRangedWeapons(aiData);
      aiData.isAggressive = true;
    }

// apply loadout for thug leader with boosted health
  static function loadoutThugLeader(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      stripAllWeapons(aiData);
      aiData.inventory.addID('katana');
      aiData.skills.addID(SKILL_KATANA, 55 + Std.random(15));
      aiData.maxHealth += 5;
      aiData.health = aiData.maxHealth;
      aiData.isAggressive = true;
    }

// apply loadout for thug melee fighters
  static function loadoutThugMelee(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      stripRangedWeapons(aiData);
      if (aiData.inventory.getFirstWeapon() == null)
        {
          var melee = ['brassKnuckles', 'knife', 'baseballBat'];
          if (difficulty == HARD)
            melee.push('machete');
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }
      aiData.isAggressive = true;
    }

// apply loadout for thug pistol shooters
  static function loadoutThugPistol(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      if (difficulty == EASY)
        {
          loadoutThugMelee(game, aiData, difficulty);
          return;
        }

      stripAllWeapons(aiData);
      aiData.inventory.addID('pistol');
      aiData.skills.addID(SKILL_PISTOL, 30 + Std.random(15));
      aiData.isAggressive = true;
    }

// apply loadout for drugged thug berserkers
  static function loadoutThugDrugged(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      loadoutThugMelee(game, aiData, difficulty);
      if (Std.random(100) < 70)
        return;
      aiData.effects.add(new effects.Berserk(game, 8 + Std.random(5)));
      aiData.isAggressive = true;
    }
}

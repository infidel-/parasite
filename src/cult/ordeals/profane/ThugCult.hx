package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class ThugCult
{
// return ordeal info for the thug syndicate strike
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "Block Liturgy",
        note: "The unaussprechliche kult maintains a street chapel in shuttered courtyards. Their katana priest leads block liturgy while shooters provide overwatch. The membrane grows thick where territory marks flesh.",
        success: "The block liturgy collapses. The katana priest falls, shooters scatter into static, and the street altar bleeds out into rainwater.",
        fail: "You are pinned by crossfire and rushed by howling steel. The kult keeps the block and recruits another night, their territory marked in fresh scar.",
        mission: MISSION_COMBAT,
        combat: {
          template: TARGET_WITH_GUARDS,
          targets: [
            {
              target: {
                job: "thug lieutenant",
                isMale: true,
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
              amount: [2, 2, 2],
              loadout: loadoutThugMelee,
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
          ]
        }
      };
    }

// apply loadout for thug leader with boosted health
  static function loadoutThugLeader(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.addID('katana');
      aiData.skills.addID(SKILL_KATANA, 55 + Std.random(15));
      aiData.maxHealth += 5;
      aiData.health = aiData.maxHealth;
      aiData.isAggressive = true;
    }

// apply loadout for thug melee fighters
  static function loadoutThugMelee(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripRangedWeapons();
      if (!aiData.inventory.hasWeapon())
        {
          var melee = ['brassKnuckles', 'knife', 'baseballBat'];
          if (difficulty == HARD)
            melee.push('machete');
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }
      if (Std.random(100) < 30)
        {
          if (!aiData.inventory.has('rawSmash'))
            aiData.inventory.addID('rawSmash');
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

      aiData.inventory.stripAllWeapons();
      aiData.inventory.addID('pistol');
      aiData.skills.addID(SKILL_PISTOL, 30 + Std.random(15));
      aiData.isAggressive = true;
    }
}

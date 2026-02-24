package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class ProstituteCult
{
// return ordeal info for the shock ring cult strike
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "Unauspr. Shock Ring",
        note: "A ring of smiling sex workers stalks the alleys in ritual cadence. Their madam carries a predatory sacrament called deadly caress.",
        success: "The ring shatters. The madam collapses and her escorts flee into neon rain, leaving only lipstick sigils on concrete.",
        fail: "You are swarmed and pinned against wet brick while the madam's kiss rite leaves you reeling. The ring keeps the block.",
        mission: MISSION_COMBAT,
        combat: {
          template: TARGET_WITH_GUARDS,
          targets: [
            {
              target: {
                isMale: false,
                job: "ring madam",
                type: "prostitute",
                icon: "prostitute",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 1],
              loadout: loadoutProstituteCultLeader,
            },
            {
              target: {
                isMale: false,
                job: "shock escort",
                type: "prostitute",
                icon: "prostitute",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 2, 2],
              loadout: loadoutProstituteShockEscort,
            },
            {
              target: {
                isMale: false,
                job: "ring bruiser",
                type: "prostitute",
                icon: "prostitute",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 2],
              loadout: loadoutProstituteRingBruiser,
            },
          ]
        }
      };
    }

// apply loadout for prostitute cult leader with deadly caress
  static function loadoutProstituteCultLeader(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripRangedWeapons();
      if (!aiData.inventory.hasWeapon())
        aiData.inventory.addID('knife');

      aiData.maxHealth += 5;
      aiData.health = aiData.maxHealth;
      aiData.abilities.addID(ABILITY_DEADLY_CARESS);
      aiData.skills.addID(SKILL_KNIFE, 50 + Std.random(15));

      switch (difficulty)
        {
          case EASY:
          case NORMAL:
          case HARD:
            if (aiData.inventory.clothing.id != 'kevlarArmor')
              aiData.inventory.addID('kevlarArmor', true);
          default:
        }

      aiData.isAggressive = true;
    }

// apply loadout for prostitute shock escorts
  static function loadoutProstituteShockEscort(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripRangedWeapons();
      if (!aiData.inventory.hasWeapon())
        {
          var melee = ['brassKnuckles', 'knife'];
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }

      aiData.skills.addID(SKILL_FISTS, 35 + Std.random(10));
      aiData.skills.addID(SKILL_KNIFE, 30 + Std.random(10));
      if (difficulty == HARD &&
          Std.random(100) < 25 &&
          !aiData.inventory.has('rawSmash'))
        aiData.inventory.addID('rawSmash');

      aiData.isAggressive = true;
    }

// apply loadout for prostitute ring bruisers
  static function loadoutProstituteRingBruiser(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripRangedWeapons();
      if (!aiData.inventory.hasWeapon())
        {
          var melee = ['brassKnuckles', 'knife', 'baseballBat'];
          if (difficulty == HARD)
            melee.push('machete');
          aiData.inventory.addID(melee[Std.random(melee.length)]);
        }

      if (difficulty != EASY &&
          Std.random(100) < 20 &&
          !aiData.inventory.has('rawSmash'))
        aiData.inventory.addID('rawSmash');

      aiData.isAggressive = true;
    }
}

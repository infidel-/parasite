package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class LabCloning
{
// return ordeal info for the underground clone lab purge
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "Unauspr. Clone Cistern",
        note: "A clandestine laboratory keeps green clone stock alive for the Unaussprechliche Kult. Eliminate the lead science triad and purge every vat.",
        success: "The clone line collapses in hissing drains. Dead scientists lie among empty glass, and the underground lab goes sterile.",
        fail: "You are pushed out before the purge finishes. The triad seals their notes and the clone line keeps breathing.",
        mission: MISSION_COMBAT,
        combat: {
          template: UNDERGROUND_LAB_PURGE,
          targets: [
            {
              target: {
                job: "lead scientist",
                type: "scientist",
                icon: "scientist",
                location: AREA_UNDERGROUND_LAB,
                helpAvailable: false,
              },
              amount: [1, 1, 1],
              loadout: loadoutLabScientistLead,
            },
            {
              target: {
                job: "clone scientist",
                type: "scientist",
                icon: "scientist",
                location: AREA_UNDERGROUND_LAB,
                helpAvailable: false,
              },
              amount: [2, 2, 2],
              loadout: loadoutLabScientist,
            },
            {
              target: {
                job: "lab security guard",
                type: "security",
                icon: "security",
                location: AREA_UNDERGROUND_LAB,
                helpAvailable: false,
              },
              amount: [2, 2, 2],
              loadout: loadoutLabSecurityGuard,
            },
          ]
        }
      };
    }

// apply loadout for the lead clone scientist
  static function loadoutLabScientistLead(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.stripRangedWeapons();
      aiData.skills.addID(SKILL_FISTS, 25 + Std.random(10));
      aiData.maxHealth += 2;
      aiData.health = aiData.maxHealth;
      aiData.isAggressive = true;
    }

// apply loadout for clone scientists
  static function loadoutLabScientist(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.stripRangedWeapons();
      aiData.skills.addID(SKILL_FISTS, 15 + Std.random(10));
      aiData.isAggressive = true;
    }

// apply loadout for underground lab guards by difficulty
  static function loadoutLabSecurityGuard(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      switch (difficulty)
        {
          case EASY:
            aiData.inventory.stripRangedWeapons();
            if (!aiData.inventory.hasWeapon())
              aiData.inventory.addID('baseballBat');
            aiData.skills.addID(SKILL_FISTS, 35 + Std.random(10));

          case NORMAL:
            aiData.inventory.stripAllWeapons();
            aiData.inventory.addID('pistol');
            aiData.skills.addID(SKILL_PISTOL, 35 + Std.random(10));

          case HARD:
            aiData.inventory.stripAllWeapons();
            aiData.inventory.addID('pistol');
            if (aiData.inventory.clothing.id != 'kevlarArmor')
              aiData.inventory.addID('kevlarArmor', true);
            aiData.skills.addID(SKILL_PISTOL, 55 + Std.random(15));

          default:
        }
      aiData.isAggressive = true;
    }
}

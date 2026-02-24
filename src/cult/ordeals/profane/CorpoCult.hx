package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class CorpoCult
{
// return ordeal info for the corporate cult head strike
  public static function getInfo(): _OrdealInfo
    {
      return {
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
      };
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
            aiData.inventory.stripRangedWeapons();
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
}

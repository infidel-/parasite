package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class CorpoCult
{
// return ordeal info for the corporate cult head strike
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "C-Suite Sacrament",
        note: "The unaussprechliche kult keeps its head in a corner office, executing quarterly flesh dividends. Two armed guardians maintain the perimeter. Disrupt the executive function before the merger closes.",
        success: "The head falls. His vertical integration collapses into static. The boardroom exhales, and the suite goes dark.",
        fail: "You are repelled through glass doors. The head slips away, calling hostile takeover. The kult absorbs another subsidiary.",
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

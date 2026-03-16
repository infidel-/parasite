package cult.ordeals.profane;

import game.Game;
import ai.AIData;

class SewerSummoning
{
// return ordeal info for the sewer summoning conclave
  public static function getInfo(): _OrdealInfo
    {
      return {
        name: "Subterranean Hymn",
        note: "The unaussprechliche kult gathers below the city, chanting around a membrane gate in wet stone. Their cantor leads the hymn while zealots guard the circle. Cut the ritual before the membrane tears.",
        success: "The choir gutters out. The chamber exhales, pipes fall quiet, and the membrane holds.",
        fail: "You falter in the tunnels. The kult completes their hymn and something answers from the far side.",
        mission: MISSION_COMBAT,
        combat: {
          template: SUMMONING_RITUAL,
          targets: [
            {
              target: {
                job: "ritual cantor",
                type: "civilian",
                icon: "cultist",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 1],
              loadout: loadoutRitualCantor,
            },
            {
              target: {
                job: "ritual guard",
                type: "civilian",
                icon: "cultist",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 2, 2],
              loadout: loadoutRitualGuard,
            },
            {
              target: {
                job: "ritual zealot",
                type: "civilian",
                icon: "cultist",
                location: AREA_CITY_LOW,
                helpAvailable: false,
              },
              amount: [1, 1, 2],
              loadout: loadoutRitualZealot,
            },
          ]
        }
      };
    }

// apply loadout for ritual cantor
  static function loadoutRitualCantor(game: Game, aiData: AIData, difficulty: _Difficulty)
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

// apply loadout for ritual guards
  static function loadoutRitualGuard(game: Game, aiData: AIData, difficulty: _Difficulty)
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

// apply loadout for ritual zealots
  static function loadoutRitualZealot(game: Game, aiData: AIData, difficulty: _Difficulty)
    {
      aiData.inventory.stripAllWeapons();
      aiData.inventory.stripRangedWeapons();
      aiData.isAggressive = true;
    }
}

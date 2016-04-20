// AI for civilians

package ai;

import ai.AI;
import _AIState;
import game.Game;

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'civilian';
      name.unknown = 'random civilian';
      name.unknownCapped = 'Random civilian';
      sounds = [
        '' + REASON_DAMAGE => [
          { text: 'Ouch!', radius: 2, alertness: 5, params: null },
          { text: '*GROAN*', radius: 2, alertness: 5, params: null },
          ],
        '' + AI_STATE_IDLE => [
          { text: 'Huh?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'Whu?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'What the?', radius: 0, alertness: 0, params: { minAlertness: 50 } },
          { text: '*GASP*', radius: 0, alertness: 0, params: { minAlertness: 75 } },
          ],
        '' + AI_STATE_ALERT => [
          { text: '*SCREAM*', radius: 7, alertness: 15, params: null },
          ],
        '' + AI_STATE_HOST => [
          { text: '*moan*', radius: 2, alertness: 5, params: null },
          { text: '*MOAN*', radius: 3, alertness: 5, params: null },
          ]
        ];

      // these only spawn when they're useful
      if (game.player.vars.searchEnabled)
        {
          // civs in higher class areas have a higher chance of having computers
          // smartphones
          var chance = 25;
          if (game.area.info.id == AREA_CITY_LOW)
            chance = 25;
          else if (game.area.info.id == AREA_CITY_MEDIUM)
            chance = 50;
          else if (game.area.info.id == AREA_CITY_HIGH)
            chance = 75;
          else if (game.area.info.id == AREA_FACILITY)
            chance = 75;

          if (Std.random(100) < chance)
            {
              skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
              inventory.addID('smartphone');
            }

          // laptops
          var chance = 5;
          if (game.area.info.id == AREA_CITY_LOW)
            chance = 5;
          else if (game.area.info.id == AREA_CITY_MEDIUM)
            chance = 10;
          else if (game.area.info.id == AREA_CITY_HIGH)
            chance = 15;
          else if (game.area.info.id == AREA_FACILITY)
            chance = 20;

          if (Std.random(100) < 10)
            {
              skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
              inventory.addID('laptop');
            }
        }
    }


// event: on state change
  public override function onStateChange()
    {
      // try to call police on next turn if not struggling with parasite
      if (state == AI_STATE_ALERT && !parasiteAttached)
        game.managerArea.addAI(this, AREAEVENT_CALL_LAW, 1);
    }
}

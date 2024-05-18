// AI for civilians

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // civs in higher class areas have a higher chance of having
      // smartphones
      var chance = 50;
      if (game.area.info.id == AREA_CITY_LOW)
        chance = 70;
      else if (game.area.info.id == AREA_CITY_MEDIUM)
        chance = 75;
      else if (game.area.info.id == AREA_CITY_HIGH)
        chance = 85;
      else if (game.area.info.id == AREA_FACILITY)
        chance = 90;
      if (Std.random(100) < chance)
        {
          skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
          inventory.addID('smartphone');
        }
      else inventory.addID('mobilePhone');

      // these only spawn when they're useful
      if (game.player.vars.searchEnabled)
        {
          // laptops
          var chance = 5;
          if (game.area.info.id == AREA_CITY_LOW)
            chance = 10;
          else if (game.area.info.id == AREA_CITY_MEDIUM)
            chance = 20;
          else if (game.area.info.id == AREA_CITY_HIGH)
            chance = 25;
          else if (game.area.info.id == AREA_FACILITY)
            chance = 30;
          if (Std.random(100) < chance)
            {
              skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
              inventory.addID('laptop');
            }
        }
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'civilian';
      name.unknown = 'random civilian';
      name.unknownCapped = 'Random civilian';
      soundsID = 'civilian';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on state change
  public override function onStateChange()
    {
      onStateChangeDefault();
    }
}

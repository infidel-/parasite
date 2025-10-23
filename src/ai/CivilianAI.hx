// AI for civilians

package ai;

import game.Game;

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // civs in higher class areas have a higher chance of having
      // smartphones
      var chance = 50;
      var areaType = game.area.info.id;
      switch (areaType)
        {
          case AREA_CITY_LOW:
            chance = 70;
          case AREA_CITY_MEDIUM:
            chance = 75;
          case AREA_CITY_HIGH:
            chance = 85;
          case AREA_FACILITY:
            chance = 90;
          default:
        }
      if (Std.random(100) < chance)
        {
          skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
          inventory.addID('smartphone');
        }
      else inventory.addID('mobilePhone');

      // rarely carry illicit narcotics for flavor events
      if (Std.random(100) < 5)
        inventory.addID('narcotics');

      // these only spawn when they're useful
      if (game.player.vars.searchEnabled)
        {
          // laptops
          var chance = 5;
          switch (areaType)
            {
              case AREA_CITY_LOW:
                chance = 10;
              case AREA_CITY_MEDIUM:
                chance = 20;
              case AREA_CITY_HIGH:
                chance = 25;
              case AREA_FACILITY:
                chance = 30;
              default:
            }
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
      var info = game.scene.images.getRandomCivilianAI(isMale);
      tileAtlasX = info.x;
      tileAtlasY = info.y;
      job = info.job;
      income = info.income;
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

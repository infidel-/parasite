// AI for scientists

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class ScientistAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      if (Std.random(100) < 75)
        {
          skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
          inventory.addID('smartphone');
        }
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'scientist';
      name.unknown = 'random scientist';
      name.unknownCapped = 'Random scientist';
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

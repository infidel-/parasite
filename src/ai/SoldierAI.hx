// AI for soldiers 

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class SoldierAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      inventory.addID('assaultRifle');
      skills.addID(SKILL_RIFLE, 40 + Std.random(25));
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'soldier';
      name.unknown = 'soldier';
      name.unknownCapped = 'Soldier';
      soundsID = 'soldier';
      isAggressive = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

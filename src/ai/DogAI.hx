// AI for dogs

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class DogAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'dog';
      name = {
        real: 'the dog',
        realCapped: 'The dog',
        unknown: 'the dog',
        unknownCapped: 'The dog'
      };
      soundsID = 'dog';

      strength = 2 + Std.random(4);
      constitution = 2 + Std.random(4);
      intellect = 1;
      psyche = 1 + Std.random(1);

      skills.addID(SKILL_ATTACK, 65);

      derivedStats();
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

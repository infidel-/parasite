// panic effect

package effects;

import ai.AI;
import game.Effect;
import game.Game;

class Panic extends Effect
{
// creates panic effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_PANIC, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'panic';
    }

// panic causes AI to run away or tear parasite away
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;

      if (ai.parasiteAttached)
        ai.logicTearParasiteAway();
      else ai.logicRunAwayFromEnemies();
    }

// returns true if effect should skip default AI turn logic
  public override function skipDefaultTurnLogic(): Bool
    {
      return true;
    }
}

// slime effect

package effects;

import ai.AI;
import game.Effect;
import game.Game;

class Slime extends Effect
{
// creates slime effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_SLIME, points, false);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'slime';
    }

// slime restrains AI each turn
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;

      var free = ai.effects.decrease(EFFECT_SLIME, ai.strength, ai);
      if (free)
        ai.log('manages to get free of the mucus.');
      else ai.log('desperately tries to get free of the mucus.');

      // set alerted state
      if (ai.state == AI_STATE_IDLE)
        ai.setState(AI_STATE_ALERT, REASON_DAMAGE);

      ai.emitRandomSound('' + REASON_DAMAGE, 30);
    }

// returns true if effect should skip default AI turn logic
  public override function skipDefaultTurnLogic(): Bool
    {
      return true;
    }
}

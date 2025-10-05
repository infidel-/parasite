// withdrawal effect

package effects;

import game.Effect;
import game.Game;
import ai.AI;

class Withdrawal extends Effect
{
// creates withdrawal effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_WITHDRAWAL, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'withdrawal';
    }

// lowers host energy each turn
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;
      ai.energy -= 5 * time;
      ai.log('shivers as withdrawal drains their strength.');
      game.info('- ' + (5 * time) + ' energy.');
    }
}

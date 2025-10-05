// drunk effect

package effects;

import ai.AI;
import game.Effect;
import game.Game;

class Drunk extends Effect
{
// creates drunk effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_DRUNK, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'drunk';
    }

// reduces control or scrambles host each turn
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;

      var host = game.player.host;

      // reduce control when parasite possesses this host
      if (host != null && host == ai)
        {
          if (game.player.hostControl > 0)
            game.player.hostControl -= 5 * time;
          return;
        }

      // scramble non-player AI movement and add side effects
      ai.changeRandomDirection();
      if (Std.random(100) < 30)
        {
          if (Std.random(2) == 0)
            {
              ai.log('starts sobbing.');
              ai.onEffect(new Crying(game, 3));
            }
          else
            {
              ai.log('staggers aimlessly.');
              ai.onEffect(new Paralysis(game, 3));
            }
        }
    }
}

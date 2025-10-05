// panic effect

package effects;

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
}

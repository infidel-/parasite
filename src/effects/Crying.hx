// crying effect

package effects;

import game.Effect;
import game.Game;

class Crying extends Effect
{
// creates crying effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_CRYING, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'crying';
    }
}

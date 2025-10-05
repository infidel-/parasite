// cannot tear away effect

package effects;

import game.Effect;
import game.Game;

class CannotTearAway extends Effect
{
// creates cannot tear away effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_CANNOT_TEAR_AWAY, points, true);
      init();
      initPost(false);
    }
}

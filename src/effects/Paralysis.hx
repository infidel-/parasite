// paralysis effect

package effects;

import game.Effect;
import game.Game;

class Paralysis extends Effect
{
// creates paralysis effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_PARALYSIS, points, true);
      init();
      initPost(false);
    }
}

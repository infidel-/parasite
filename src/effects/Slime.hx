// slime effect

package effects;

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
}

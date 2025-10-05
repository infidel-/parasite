// berserk effect

package effects;

import game.Effect;
import game.Game;

class Berserk extends Effect
{
// creates berserk effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_BERSERK, points, true);
      init();
      initPost(false);
    }
}

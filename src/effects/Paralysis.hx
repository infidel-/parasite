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

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'paralysis';
    }

// returns true if effect should skip default AI turn logic
  public override function skipDefaultTurnLogic(): Bool
    {
      return true;
    }
}

// effect that blocks starting communal ordeals
package cult.effects;

import cult.Effect;
import game.Game;

class BlockCommunal extends Effect
{
// creates block communal effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_BLOCK_COMMUNAL, turns);
    }

// sets effect display name
  public override function init()
    {
      super.init();
      name = 'vain probation';
      allowMultiple = false;
    }
}

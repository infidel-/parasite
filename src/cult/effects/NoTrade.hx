// effect that blocks cult trade actions
package cult.effects;

import cult.Effect;
import game.Game;

class NoTrade extends Effect
{
// creates no-trade effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_NOTRADE, turns);
    }

// sets effect display name
  public override function init()
    {
      super.init();
      name = 'trade silence';
      allowMultiple = false;
    }

  // returns effect description
  public override function note(): String
    {
      return 'blocks all trading';
    }
}

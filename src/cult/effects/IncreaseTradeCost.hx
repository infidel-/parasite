// effect that increases trade cost
package cult.effects;

import cult.Effect;
import game.Game;

class IncreaseTradeCost extends Effect
{
  public var percent: Int;

// creates increase trade cost effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_INCREASE_TRADE_COST, turns);
    }

// sets effect display name and calculates percentage
  public override function init()
    {
      super.init();
      name = 'trade cost increase';
      allowMultiple = true;
      
      // calculate random percentage: 15% base, 25% with 25% chance, 50% with 5% chance
      percent = 15;
      var roll = Std.random(100);
      if (roll < 5)
        percent = 50;
      else if (roll < 30)
        percent = 25;
    }

// returns custom display name with percentage
  public override function customName(): String
    {
      return '+' + percent + '% trade cost';
    }
}

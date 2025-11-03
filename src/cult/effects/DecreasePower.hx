// effect that decreases cult power
package cult.effects;

import cult.Effect;
import cult.Cult;
import game.Game;

class DecreasePower extends Effect
{
  public var powerType: String;
  var value: Int;

// creates decrease power effect
  public function new(game: Game, turns: Int, powerType: String)
    {
      super(game, CULT_EFFECT_DECREASE_POWER, turns);
      this.powerType = powerType;
    }

// sets effect display name and calculates value
  public override function init()
    {
      super.init();
      name = 'power drain';
      allowMultiple = true;
      
      // calculate random value: 1 base, 3 with 25% chance, 9 with 5% chance
      value = 1;
      var roll = Std.random(100);
      if (roll < 5)
        value = 9;
      else if (roll < 30)
        value = 3;
    }

// applies power decrease during recalc
  public override function run(cult: Cult)
    {
      cult.power.dec(powerType, value);
    }

// returns custom display name with value
  public override function customName(): String
    {
      return '-' + value + ' ' + powerType + ' power';
    }
}

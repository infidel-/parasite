// effect that increases cult income
package cult.effects;

import cult.Effect;
import cult.Cult;
import game.Game;

class IncreaseIncome extends Effect
{
  var percent: Int;

// creates increase income effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_INCREASE_INCOME, turns);
    }

// sets effect display name and calculates percentage
  public override function init()
    {
      super.init();
      name = 'income boost';
      allowMultiple = true;
      
      // calculate random percentage: 10% base, 20% with 25% chance, 30% with 5% chance
      percent = 10;
      var roll = Std.random(100);
      if (roll < 5)
        percent = 30;
      else if (roll < 30)
        percent = 20;
    }

// applies income increase during recalc
  public override function run(cult: Cult)
    {
      // calculate base income from members
      var baseIncome = 0;
      for (member in cult.members)
        baseIncome += member.income;
      
      // apply percentage increase
      var increase = Std.int(baseIncome * percent / 100);
      cult.power.inc('money', increase);
    }

// returns custom display name with percentage
  public override function customName(): String
    {
      return '+' + percent + '% ' + Icon.money;
    }
}

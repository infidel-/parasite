// effect that decreases cult income
package cult.effects;

import cult.Effect;
import cult.Cult;
import game.Game;

class DecreaseIncome extends Effect
{
  var percent: Int;

// creates decrease income effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_DECREASE_INCOME, turns);
    }

// sets effect display name and calculates percentage
  public override function init()
    {
      super.init();
      name = 'income drain';
      allowMultiple = true;
      
      // calculate random percentage: 10% base, 20% with 25% chance, 30% with 5% chance
      percent = 10;
      var roll = Std.random(100);
      if (roll < 5)
        percent = 30;
      else if (roll < 30)
        percent = 20;
    }

// applies income decrease during recalc
  public override function run(cult: Cult)
    {
      // calculate base income from members
      var baseIncome = 0;
      for (member in cult.members)
        baseIncome += member.income;
      
      // apply percentage decrease
      var decrease = Std.int(baseIncome * percent / 100);
      cult.power.dec('money', decrease);
    }

// returns custom display name with percentage
  public override function customName(): String
    {
      return '-' + percent + '% ' + Icon.money;
    }
}

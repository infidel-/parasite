// effect that progresses random ordeals each turn
package cult.effects;

import cult.Effect;
import cult.Cult;
import game.Game;

class OrdealActions extends Effect
{
// creates ordeal actions effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_ORDEAL_ACTIONS, turns);
    }

// sets effect display name
  public override function init()
    {
      super.init();
      name = 'grievous burdens';
      allowMultiple = true;
    }

// progresses random ordeals each turn
  public override function turn(cult: Cult, time: Int)
    {
      // get active ordeals
      var activeOrdeals = [];
      for (ordeal in cult.ordeals.list)
        activeOrdeals.push(ordeal);
      
      if (activeOrdeals.length == 0)
        return;
      
      // calculate number of ordeals to pick: 1 base, 2 with 25% chance, 3 with 5% chance
      var numOrdeals = 1;
      var roll = Std.random(100);
      if (roll < 5)
        numOrdeals = 3;
      else if (roll < 30)
        numOrdeals = 2;
      
      // limit to available ordeals
      if (numOrdeals > activeOrdeals.length)
        numOrdeals = activeOrdeals.length;
      
      // shuffle and pick random ordeals
      var shuffled = activeOrdeals.copy();
      for (i in 0...shuffled.length)
        {
          var j = Std.random(shuffled.length);
          var tmp = shuffled[i];
          shuffled[i] = shuffled[j];
          shuffled[j] = tmp;
        }
      
      // process selected ordeals
      for (i in 0...numOrdeals)
        {
          var ordeal = shuffled[i];
          
          // calculate action increase: 1 base, 2 with 25% chance
          var actionIncrease = 1;
          var actionRoll = Std.random(100);
          if (actionRoll < 25)
            actionIncrease = 2;
          
          // increase actions, capped by requiredMembers
          ordeal.actions += actionIncrease;
          if (ordeal.actions > ordeal.requiredMembers)
            ordeal.actions = ordeal.requiredMembers;
        }
    }
}

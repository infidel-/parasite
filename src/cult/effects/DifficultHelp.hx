// effect that makes calling help harder
package cult.effects;

import cult.Effect;
import game.Game;

class DifficultHelp extends Effect
{
  public var percent: Int; // difficulty percent (25/50/100)

// creates difficult help effect
  public function new(game: Game, turns: Int)
    {
      super(game, CULT_EFFECT_DIFFICULT_HELP, turns);
    }

// sets effect display name and rolls difficulty
  public override function init()
    {
      super.init();
      name = 'summoning disruption';
      allowMultiple = false;
      
      percent = 25;
      var roll = Std.random(100);
      if (roll < 5)
        percent = 100;
      else if (roll < 30)
        percent = 50;
    }

// returns custom display name with difficulty level
  public override function customName(): String
    {
      var level = '';
      if (percent <= 25)
        level = 'low';
      else if (percent <= 50)
        level = 'medium';
      else
        level = 'impossible';
      return name + ' (' + level + ')';
    }
}

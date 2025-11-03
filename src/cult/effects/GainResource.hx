// effect that gains cult resources each turn
package cult.effects;

import cult.Effect;
import cult.Cult;
import game.Game;

class GainResource extends Effect
{
  public var resourceType: String;

// creates gain resource effect
  public function new(game: Game, turns: Int, resourceType: String)
    {
      super(game, CULT_EFFECT_GAIN_RESOURCE, turns);
      this.resourceType = resourceType;
    }

// sets effect display name
  public override function init()
    {
      super.init();
      name = 'resource gain';
      allowMultiple = true;
    }

// gains resources each turn
  public override function turn(cult: Cult, time: Int)
    {
      // calculate random value: 1 base, 2 with 25% chance, 3 with 5% chance
      var value = 1;
      var roll = Std.random(100);
      if (roll < 5)
        value = 3;
      else if (roll < 30)
        value = 2;
      
      cult.resources.inc(resourceType, value);
    }

// returns custom display name
  public override function customName(): String
    {
      return '+1-3 ' + resourceType + ' income';
    }
}

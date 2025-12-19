// effect that blocks a specific cultist
package cult.effects;

import cult.Effect;
import game.Game;

class BlockCultist extends Effect
{
  public var targetID: Int;

// creates block cultist effect
  public function new(game: Game, turns: Int, targetID: Int)
    {
      super(game, CULT_EFFECT_BLOCK_CULTIST, turns);
      this.targetID = targetID;
    }

// creates block cultist effect with automatic target selection
  public static function create(game: Game, turns: Int): BlockCultist
    {
      var cult = game.cults[0];
      
      // pick level: 1 base, 2 with 25% chance, 3 with 5% chance
      var level = 1;
      var roll = Std.random(100);
      if (roll < 5)
        level = 3;
      else if (roll < 30)
        level = 2;
      
      // get free cultists of selected level
      var freeMembers = cult.getFreeMembers(level, true);
      
      // if no free cultists of selected level, fall back to level 1 (we want these low chances for 2+ blocks)
      if (freeMembers.length == 0)
        freeMembers = cult.getFreeMembers(1, true);
      
      // if no free cultists at all, return null
      if (freeMembers.length == 0)
        return null;
      
      // pick random cultist from available
      var targetID = freeMembers[Std.random(freeMembers.length)];
      
      return new BlockCultist(game, turns, targetID);
    }

// sets effect display name
  public override function init()
    {
      super.init();
      name = 'recessu';
      allowMultiple = true;
    }

// returns custom display name with target name
  public override function customName(): String
    {
      var cult = game.cults[0];
      var member = cult.getMemberByID(targetID);
      if (member == null)
        return name;
      return name + ' - ' + member.TheName();
    }

  // returns effect description
  public override function note(): String
    {
      return 'blocks member actions';
    }
}

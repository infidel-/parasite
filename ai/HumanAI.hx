// AI for humans (should not be used in the game itself)

package ai;

import game.Game;
import const.NameConst;

class HumanAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'human';
      name.real = name.realCapped = const.NameConst.getHumanName();

      isHuman = true;
      strength = 4 + Std.random(4);
      constitution = 4 + Std.random(4);
      intellect = 4 + Std.random(4);
      psyche = 4 + Std.random(4);

      // common stuff for all humans
      if (Std.random(100) < 20)
        {
          skills.addID(KNOW_SMOKING);
          inventory.addID('cigarettes');
        }
      if (Std.random(100) < 75)
        {
          skills.addID(KNOW_SHOPPING);
          inventory.addID(Std.random(10) < 7 ? 'wallet' : 'money');
        }

      derivedStats();
    }
}

// AI for humans (should not be used in the game itself)

package ai;

import game.Game;

class HumanAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'human';
      name.real = name.realCapped = 'Joe Smith';

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
      if (Std.random(100) < 50)
        {
          skills.addID(KNOW_SHOPPING);
          inventory.addID('money');
        }

      derivedStats();
    }
}

package objects.base;

import ai.AI;
import effects.Paralysis;
import game.Game;

class BloodTrap extends BaseOrganObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, organID: Int,
      ?basePartIndex: Int = 0)
    {
      super(g, vaid, vx, vy, organID, basePartIndex);
    }

// init object appearance
  public override function init()
    {
      super.init();
      name = 'Tardans';
    }

// walkable sludge slows enemies
  public override function frob(isPlayer: Bool, ai: AI): Int
    {
      var organ = getOrgan();
      if (organ != null &&
          organ.isWorking() &&
          ai != null &&
          !ai.isPlayerCultist() &&
          !ai.isCustos)
        ai.onEffect(new Paralysis(game, 2));
      return 1;
    }

// blood traps can be crossed by actors
  public override function isWalkable(): Bool
    {
      return true;
    }

// blood traps are triggered by movement, not attacks
  public override function isAttackable(): Bool
    {
      return false;
    }
}

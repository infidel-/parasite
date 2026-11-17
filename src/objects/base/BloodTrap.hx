package objects.base;

import ai.AI;
import const.CultBaseConst;
import effects.Slime;
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
      name = N('Tardans');
    }

// walkable sludge slows enemies
  public override function frob(isPlayer: Bool, ai: AI): Int
    {
      var organ = getOrgan();
      if (organ != null &&
          organ.isWorking() &&
          !isPlayer &&
          ai != null &&
          !ai.isPlayerCultist() &&
          !ai.isCustos)
        {
          // the mud clings by level and wears the pool down
          ai.onEffect(new Slime(game, CultBaseConst.trapSlime(organ.level)));
          damage(1);
        }
      return 1;
    }

// blood traps can be crossed by actors
  public override function isWalkable(): Bool
    {
      return true;
    }
}

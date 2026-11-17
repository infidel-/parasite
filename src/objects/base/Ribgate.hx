package objects.base;

import ai.AI;
import const.CultBaseConst;
import effects.Bleeding;
import game.Game;

class Ribgate extends BaseOrganObject
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
      name = N('Porta Costarum');
    }

// lets allies through and blocks enemies while intact
  public override function frob(isPlayer: Bool, ai: AI): Int
    {
      var organ = getOrgan();
      if (organ != null &&
          organ.broken)
        return 1;
      if (isPlayer ||
          ai.isPlayerCultist() ||
          ai.isCustos)
        return 1;
      // the bite grows with the level and leaves the foe bleeding
      var bite = CultBaseConst.gateBite(organ.level);
      damage(1);
      ai.onDamage(Const.roll(bite.min, bite.max));
      ai.onEffect(new Bleeding(game, 3));
      return 0;
    }

// a working gate is shut to sight, a broken one is not
  public override function canSeeThrough(): Bool
    {
      var organ = getOrgan();
      return (organ == null ||
        !organ.isWorking());
    }

// gate tile is passable; frob blocks enemies
  public override function isWalkable(): Bool
    {
      return true;
    }
}

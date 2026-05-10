package objects.base;

import ai.AI;
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
      name = 'Porta Costarum';
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
      damage(1);
      ai.onDamage(Const.roll(1, 3));
      return 0;
    }

// gate tile is passable; frob blocks enemies
  public override function isWalkable(): Bool
    {
      return true;
    }
}

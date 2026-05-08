package objects.base;

import game.Game;

class SpineTurret extends BaseOrganObject
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
      name = 'Turris Spinarum';
    }

// fires down the chosen cardinal line
  public override function turn()
    {
      var organ = getOrgan();
      if (organ == null ||
          !organ.isWorking())
        return;
      var dx = Const.dir4x[organ.direction];
      var dy = Const.dir4y[organ.direction];
      var tx = x + dx;
      var ty = y + dy;
      while (tx >= 0 &&
          ty >= 0 &&
          tx < game.area.width &&
          ty < game.area.height &&
          game.area.canSeeThrough(tx, ty))
        {
          var ai = game.area.getAI(tx, ty);
          if (ai != null &&
              !ai.isPlayerCultist() &&
              !ai.isCustos)
            {
              ai.onDamage(Const.roll(1, 4));
              return;
            }
          tx += dx;
          ty += dy;
        }
    }
}

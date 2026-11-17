package objects.base;

import game.Game;

class Ribwall extends BaseOrganObject
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
      name = N('Murus Costarum');
    }

// a working wall blocks sight, a broken one does not
  public override function canSeeThrough(): Bool
    {
      var organ = getOrgan();
      return (organ == null ||
        !organ.isWorking());
    }
}

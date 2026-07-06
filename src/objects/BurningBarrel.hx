// burning barrel - impassable street clutter (low-tier city)

package objects;

import game.Game;

class BurningBarrel extends Decoration
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy, Const.ROW_OBJECT2, Const.FRAME_BURNING_BARREL);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageRow = Const.ROW_OBJECT2;
      imageCol = Const.FRAME_BURNING_BARREL;
      type = 'burning_barrel';
      name = 'burning barrel';
    }

// stand upright in the 3D street view instead of lying flat like ground clutter
  public override function isGroundDecal(): Bool
    { return false; }
}

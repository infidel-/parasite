// car wreck - a stripped, rusted car carcass abandoned at a slum kerb, two cells long

package objects;

import game.Game;

class CarWreck extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageRow = Const.ROW_OBJECT2;
      imageCol = Const.FRAME_CAR_WRECK;
      type = 'car_wreck';
      name = 'car wreck';
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// the 3D view draws the shell over this cell and the next one along the kerb
// (render.CityArea.objYaw KERB); the 2D sprite is its fallback
  public override function getModelKey(): String
    {
      return 'car_wreck';
    }

  public override function known(): Bool
    { return true; }

  public override function isGroundDecal(): Bool
    { return false; }

// a steel shell on its sills: nobody walks through it, everybody sees over it
  public override function isWalkable(): Bool
    { return false; }
}

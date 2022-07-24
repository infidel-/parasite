// decorative objects, non-interactive

package objects;

import game.Game;

class Decoration extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, row: Int, col: Int)
    {
      super(g, vaid, vx, vy);
      init();
      imageRow = row;
      imageCol = col;
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageCol = Const.FRAME_SEWER_HATCH;
      type = 'decoration';
      name = 'decoration';
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

  public override function known(): Bool
    { return true; }

  public override function visible(): Bool
    { return false; }
}

// decorative objects, non-interactive
// this version supports rotation and scaling

package objects;

import game.Game;
import Const.TILE_SIZE as tile;

class DecorationExt extends AreaObject
{
  public var scale: Float;
  public var angle: Float;
  public var dx: Int;
  public var dy: Int;

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
      type = 'decorationExt';
      name = 'decorationExt';
      isStatic = true;
      scale = Const.round2(0.1 + 0.9 * Math.random());
      angle = Const.round2(360 * Math.random() * Math.PI / 180);
      var min = - tile * (1.0 - scale) / 2.0;
      var max = tile * (1.0 - scale) / 2.0;
      dx = Std.int(min + Math.random() * (max - min));
      dy = Std.int(min + Math.random() * (max - min));
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

// document with different tiles (clue)
// replaces generic paper in labs

package objects;

import game.Game;

class Document extends Pickup
{
  static var _ignoredFields = [ 'event' ];

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
      type = 'document';
      name = 'document';
      imageCol = Const.FRAME_PAPER;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    { return true; }
}

// book (clue)

package objects;

import game.Game;

class Book extends Pickup
{
  static var _ignoredFields = [ 'event' ];

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
      type = 'book';
      name = 'book';
      imageCol = Const.FRAME_BOOK;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

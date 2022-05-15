// piece of paper (clue)

package objects;

import game.Game;

class Paper extends Pickup
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
      type = 'paper';
      name = 'paper';
      imageCol = Const.FRAME_PAPER;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

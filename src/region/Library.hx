// the university library's region mark

package region;

import game.Game;

class Library extends RegionObject
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'library';
      name = N('University library');
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      icon = {
        row: Const.ROW_REGION_ICON,
        col: Const.FRAME_LIBRARY_MARK,
      };
    }
}

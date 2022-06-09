// nutrient spawned after decay accelerant works on the body

package objects;

import game.Game;
import const.ItemsConst;

class Nutrient extends Pickup
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
      imageCol = Const.FRAME_NUTRIENT;
      var info = ItemsConst.getInfo('nutrients');
      name = info.name;
      type = info.type;
      item = {
        game: game,
        id: info.id,
        name: info.name,
        info: info,
        event: null,
      };
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

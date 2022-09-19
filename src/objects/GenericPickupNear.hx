// generic pickup that can be activated near

package objects;

import game.Game;

class GenericPickupNear extends Pickup
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, imgID: Int)
    {
      super(g, vaid, vx, vy);
      imageCol = imgID;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
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


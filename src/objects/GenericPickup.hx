// generic pickup

package objects;

import game.Game;

class GenericPickup extends Pickup
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, imgID: Int)
    {
      super(g, vaid, vx, vy);
      imageCol = imgID;
      init();
      loadPost();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
    }

// called after load or creation
  public override function loadPost()
    {
      super.loadPost();
    }
}


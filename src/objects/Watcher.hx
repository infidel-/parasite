// habitat - watcher

package objects;

import game.Game;

class Watcher extends HabitatObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy, l);
      init();
      loadPost();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'watcher';
      spawnMessage = 'The watcher blinks its eyes and joins you.';
      imageRow = Const.ROW_WATCHER;
      imageCol = level;
    }

// called after load or creation
  public override function loadPost()
    {
      super.loadPost();
    }
}


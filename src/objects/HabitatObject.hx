// habitat object

package objects;

import game.Game;

class HabitatObject extends AreaObject
{
  public var level: Int;
  public var spawnMessage: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy);
      level = l;
      init();
      loadPost();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'habitat';
      spawnMessage = null;
      isStatic = true;
    }

// called after load or creation
  public override function loadPost()
    {
      super.loadPost();
    }


// habitat objects also return level
  public override function getName()
    {
      return name + ' (level ' + level + ')';
    }
}


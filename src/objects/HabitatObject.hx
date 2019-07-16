// habitat object

package objects;

import game.Game;

class HabitatObject extends AreaObject
{
  public var level: Int;
  public var spawnMessage: String;

  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy);

      type = 'habitat';
      spawnMessage = null;
      isStatic = true;
      level = l;
    }


// habitat objects also return level
  public override function getName()
    {
      return name + ' (level ' + level + ')';
    }
}


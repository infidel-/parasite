// habitat object

package objects;

import game.Game;
import const.EvolutionConst;

class HabitatObject extends AreaObject
{
  public var level: Int;
  public var spawnMessage: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy);
      level = l;
//      init();
//      initPost(false);
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
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// get improvement ID
  public function getImprovementID(): _Improv
    {
      throw 'must set improvement ID for ' + name;
    }

// get evolution params
  public function getParams()
    {
      return EvolutionConst.getParams(getImprovementID(), level);
    }


// habitat objects also return level
  public override function getName()
    {
      return name + ' (level ' + level + ')';
    }
}


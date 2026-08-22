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

// habitat structures stand upright in the 3D view, not flat on the ground
  public override function isGroundDecal(): Bool
    { return false; }

// get improvement ID
  public function getImprovementID(): _Improv
    {
      throw 'must set improvement ID for ' + name;
    }

// get evolution params
// Dynamic because const.EvolutionConst.levelParams is a DIFFERENT anonymous structure per
// improvement (the preservator's carries hostAmount, the biomineral's energy and three restore
// rates, and so on), so there is no one type it could be given. it was inferred before, which is
// worse than declaring it: the first call site to concatenate a field with a string bound the whole
// return type to String and broke every numeric comparison elsewhere
  public function getParams(): Dynamic
    {
      return EvolutionConst.getParams(getImprovementID(), level);
    }


// habitat objects also return level
  public override function getName()
    {
      return name + ' (level ' + level + ')';
    }
}


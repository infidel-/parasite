// habitat - watcher

package objects;

import game.Game;
import lighting.AtmosphereLightProfiles;

class Watcher extends HabitatObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy, l);
      init();
      initPost(false);
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
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// every habitat object shares the 'habitat' type, so the 3D prop lookup keys on this instead
  public override function getModelKey(): String
    { return 'habitat_watcher'; }

// a grown body is solid, the same as the biomineral and the preservator — an eye-studded mass is
// not something you walk over. the assimilation cavity is the one organ that stays walkable, and it
// is not an oversight: that one is a DOORWAY, and stepping through the arch is what it is for
  public override function isWalkable(): Bool
    { return false; }

// get static atmosphere light emitted by this object
  public override function getAtmosphereLight(): _AtmosphereLightMeta
    {
      return AtmosphereLightProfiles.HABITAT_WATCHER;
    }

// get atmosphere light stamp kind used by this object
  public override function getAtmosphereLightKind(): String
    {
      return 'habitat-watcher';
    }
}

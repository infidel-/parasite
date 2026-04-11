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

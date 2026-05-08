package objects.base;

import _AtmosphereLightMeta;
import game.Game;
import lighting.AtmosphereLightProfiles;

class CorNefandum extends BaseOrganObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, organID: Int,
      ?basePartIndex: Int = 0)
    {
      super(g, vaid, vx, vy, organID, basePartIndex);
    }

// init object appearance
  public override function init()
    {
      super.init();
      name = 'Cor Nefandum';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      if (game != null &&
          game.scene != null &&
          game.scene.areaLighting != null)
        game.scene.areaLighting.invalidateArea(game.region.get(areaID));
    }

// get creepy red fleshy glow emitted by the heart
  public override function getAtmosphereLight(): _AtmosphereLightMeta
    {
      return AtmosphereLightProfiles.CULT_BASE_HEART;
    }
}

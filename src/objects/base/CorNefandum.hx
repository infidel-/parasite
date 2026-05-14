package objects.base;

import _AtmosphereLightMeta;
import ai.AI;
import ai.CustosLogic;
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

// alerts custodes when the heart takes combat damage
  public override function onDamage(damage: Int, ?attacker: AI)
    {
      CustosLogic.onHeartAttacked(attacker);
      var base = game.cults[0].base;
      var organ = getOrgan();
      if (base != null && organ != null)
        base.damageOrgan(organ, damage);
    }

// get creepy red fleshy glow emitted by the heart
  public override function getAtmosphereLight(): _AtmosphereLightMeta
    {
      return AtmosphereLightProfiles.CULT_BASE_HEART;
    }
}

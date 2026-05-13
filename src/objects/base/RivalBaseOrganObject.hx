// area object wrapper for rival base organs
package objects.base;

import ai.AI;
import const.CultBaseConst;
import cult.base.RivalBaseOrgan;
import cult.missions.RivalBase;
import game.Game;
import objects.AreaObject;

class RivalBaseOrganObject extends AreaObject
{
  public var missionID: Int;
  public var organID: Int;
  public var basePartIndex: Int;
  public var destroyed: Bool;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, missionID: Int,
      organID: Int, ?basePartIndex: Int = 0)
    {
      super(g, vaid, vx, vy);
      init();
      this.missionID = missionID;
      this.organID = organID;
      this.basePartIndex = basePartIndex;
      syncOrganImage();
      initPost(false);
    }

// init rival base organ object fields
  public override function init()
    {
      super.init();
      type = 'rival_base_organ';
      name = 'rival sanctum';
      isStatic = true;
      missionID = -1;
      organID = -1;
      basePartIndex = 0;
      destroyed = false;
      imageName = CultBaseConst.IMAGE_NAME;
      syncOrganImage();
    }

// refresh rival organ atlas coordinates
  public function syncOrganImage()
    {
      imageName = CultBaseConst.IMAGE_NAME;
      var icon = { row: 4, col: 2 };
      var width = 2;
      var organ = getOrgan();
      if (organ != null)
        {
          destroyed = organ.destroyed;
          icon = isDestroyed() ?
            CultBaseConst.sanctumDestroyedIcon :
            organ.icon;
          width = organ.width;
        }
      else if (isDestroyed())
        icon = CultBaseConst.sanctumDestroyedIcon;
      imageRow = icon.row + Std.int(basePartIndex / width);
      imageCol = icon.col + basePartIndex % width;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      syncOrganImage();
      super.initPost(onLoad);
    }

// rival base organs are known mission targets
  public override function known(): Bool
    {
      return true;
    }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    {
      return true;
    }

// returns display name
  public override function getName(): String
    {
      var organ = getOrgan();
      if (organ == null)
        return name;
      return organ.name;
    }

// returns organ name without an article
  public override function theName(): String
    {
      return getName();
    }

// update available object actions
  override function updateActionList()
    {
      if (!isAttackable())
        return;
      game.ui.hud.addAction({
        id: 'attackRivalBaseOrgan',
        type: ACTION_OBJECT,
        name: 'Attack ' + getName(),
        energy: 0,
        obj: this
      });
    }

// handles object actions
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id != 'attackRivalBaseOrgan')
        return false;
      game.playerArea.attackObjectAction(this, true);
      return false;
    }

// damages the linked rival organ through combat
  public override function onDamage(damage: Int, ?attacker: AI)
    {
      var mission = getMission();
      var organ = getOrgan();
      if (mission != null &&
          organ != null)
        {
          mission.onSanctumAttacked(attacker);
          mission.damageOrgan(organ, damage);
        }
    }

// can actors walk through this object tile?
  public override function isWalkable(): Bool
    {
      return false;
    }

// can this object be attacked?
  public override function isAttackable(): Bool
    {
      var organ = getOrgan();
      return organ != null && !isDestroyed();
    }

// returns whether the object has been destroyed
  function isDestroyed(): Bool
    {
      if (destroyed)
        return true;
      var organ = getOrgan();
      return organ != null && organ.destroyed;
    }

// returns linked rival organ record
  public function getOrgan(): RivalBaseOrgan
    {
      var mission = getMission();
      if (mission == null)
        return null;
      return mission.getOrgan(organID);
    }

// returns an attackable part of this organ near a tile
  public function getAttackPartNear(x: Int, y: Int): RivalBaseOrganObject
    {
      var area = game.region.get(areaID);
      if (area == null)
        return null;
      var best: RivalBaseOrganObject = null;
      var bestDist = 999999;
      for (o in area.getObjects())
        {
          if (o.type != 'rival_base_organ')
            continue;
          var obj: RivalBaseOrganObject = cast o;
          if (obj.missionID != missionID ||
              obj.organID != organID ||
              !obj.isAttackable() ||
              Math.abs(obj.x - x) > 1 ||
              Math.abs(obj.y - y) > 1)
            continue;
          var dist = Const.distanceSquared(x, y, obj.x, obj.y);
          if (best == null ||
              dist < bestDist)
            {
              best = obj;
              bestDist = dist;
            }
        }
      return best;
    }

// returns linked rival base mission
  function getMission(): RivalBase
    {
      if (game == null ||
          game.cults.length == 0 ||
          game.cults[0].ordeals == null)
        return null;
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          !Std.isOfType(mission, RivalBase))
        return null;
      return cast mission;
    }
}

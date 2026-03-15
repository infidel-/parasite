// summoning portal object used by ritual combat mission
// NOTE: we assume this does not need to be saved/loaded!

package objects.mission;

import cult.missions.CombatSummoningRitual;
import game.Game;
import objects.AreaObject;
import tiles.Sewers;

class SummoningPortal extends AreaObject
{
  public static inline var PORTAL_W = 2;
  public static inline var PORTAL_H = 2;

  public var missionID: Int;
  public var isBroken: Bool;
  public var portalRootObjectID: Int;
  public var portalPartIndex: Int;
  public var portalPartObjectIDs: Array<Int>;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, vmissionID: Int,
      ?vportalPartIndex: Int = 0)
    {
      super(g, vaid, vx, vy);
      init();
      missionID = vmissionID;
      portalPartIndex = vportalPartIndex;
      updatePortalIcon();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      isBroken = false;
      portalRootObjectID = -1;
      portalPartIndex = 0;
      portalPartObjectIDs = [];
      type = 'summoning_portal';
      name = 'summoning portal';
      imageName = Sewers.OBJECTS_IMAGE;
      updatePortalIcon();
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      updatePortalIcon();
    }

// assign linked object ids for a 2x2 portal group
  public function setPortalGroup(rootObjectID: Int, partObjectIDs: Array<Int>)
    {
      portalRootObjectID = rootObjectID;
      portalPartObjectIDs = partObjectIDs.copy();
    }

// swap the whole portal group to the broken art state
  public function breakPortalGroup()
    {
      var area = game.region.get(areaID);
      if (area == null)
        return;

      for (objectID in getGroupObjectIDs())
        {
          var o = area.getObject(objectID);
          if (o == null ||
              o.type != 'summoning_portal')
            continue;
          var portal: SummoningPortal = cast o;
          portal.isBroken = true;
          portal.updatePortalIcon();
          area.recalcTile(portal.x, portal.y);
        }

      if (game != null &&
          game.scene != null &&
          game.scene.areaLighting != null)
        game.scene.areaLighting.invalidateArea(area);
    }

// remove every portal part object from its area
  public function removePortalGroup()
    {
      var area = game.region.get(areaID);
      if (area == null)
        return;

      var objectIDs = getGroupObjectIDs();
      for (objectID in objectIDs)
        {
          var o = area.getObject(objectID);
          if (o == null ||
              o.type != 'summoning_portal')
            continue;
          area.removeObject(o);
        }
    }

// update icon frame for current portal part and broken state
  function updatePortalIcon()
    {
      var block = (isBroken ? Sewers.BROKEN_PORTAL : Sewers.SUMMONING_PORTAL);
      imageRow = block.row + Std.int(portalPartIndex / block.width);
      imageCol = block.col + portalPartIndex % block.width;
      if (entity != null)
        updateImage();
    }

// resolve root portal object for this portal part
  function getRootPortal(): SummoningPortal
    {
      if (portalRootObjectID < 0 ||
          portalRootObjectID == id)
        return this;
      var area = game.region.get(areaID);
      if (area == null)
        return this;
      var o = area.getObject(portalRootObjectID);
      if (o == null ||
          o.type != 'summoning_portal')
        return this;
      return cast o;
    }

// resolve group object ids from the root portal
  function getGroupObjectIDs(): Array<Int>
    {
      var root = getRootPortal();
      if (root.portalPartObjectIDs == null ||
          root.portalPartObjectIDs.length == 0)
        return [root.id];
      return root.portalPartObjectIDs;
    }

// get logical center tile x of the full 2x2 portal
  function getCenterX(): Int
    {
      var root = getRootPortal();
      return root.x + 1;
    }

// get logical center tile y of the full 2x2 portal
  function getCenterY(): Int
    {
      var root = getRootPortal();
      return root.y + 1;
    }

// monitor player proximity to trigger ritual start
  public override function turn()
    {
      var root = getRootPortal();
      if (root.id != id)
        return;

      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          mission.isCompleted ||
          mission.type != MISSION_COMBAT)
        return;
      var ritual: CombatSummoningRitual = cast mission;

      if (Const.distanceSquared(game.playerArea.x, game.playerArea.y,
            getCenterX(), getCenterY()) > 10 * 10)
        return;

      ritual.onPortalProximity(this);
    }

// block movement on intact portal tiles
  public override function isWalkable(): Bool
    {
      return isBroken;
    }

// stop movement onto intact portal tiles even if tile cache is stale
  public override function frob(isPlayer: Bool, ai: ai.AI): Int
    {
      return (isBroken ? 1 : 0);
    }

  public override function known(): Bool
    { return true; }
}

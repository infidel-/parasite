package lighting;

import _AtmosphereLightMeta;
import AreaLighting;
import GameScene;
import game.AreaGame;
import objects.mission.SummoningPortal;
import tiles.*;

class SewerAreaLighting
{
// build sewer atmosphere light stamps
  public static function buildLightStamps(scene: GameScene, area: AreaGame,
      areaLighting: AreaLighting): Array<_AreaLightStamp>
    {
      var stamps = [];
      if (scene == null ||
          scene.images == null)
        return stamps;

      var tileset = scene.images.getTileset(area.getTilesetTypeID());
      if (!Std.isOfType(tileset, Sewers))
        return stamps;

      if (area.tiles == null ||
          area.tiles.length == 0)
        area.initTilesFromCells();
      var sewerTileset: Sewers = cast tileset;

      addSewerExitLights(area, stamps, areaLighting);
      addSummoningPortalLights(area, stamps, areaLighting);
      addSewerCorridorLayoutLights(area, stamps, sewerTileset, areaLighting);
      return stamps;
    }

// collect sewer projected-shadow casters
  public static function collectProjectedShadowCasters(scene: GameScene,
      area: AreaGame): Array<_ProjectedShadowCaster>
    {
      var casters = [];
      if (scene == null ||
          scene.images == null)
        return casters;

      for (o in area.getObjects())
        {
          if (o.type != 'sewer_exit')
            continue;

          casters.push({
            layerID: -1,
            image: scene.images.entities,
            maskKey: 'entities:' + o.imageRow + ':' + o.imageCol + ':1:1',
            srcRow: o.imageRow,
            srcCol: o.imageCol,
            blockW: 1,
            blockH: 1,
            centerX: o.x + 0.5,
            centerY: o.y + 0.5,
            skipSelfShadow: true,
          });
        }
      return casters;
    }

// add one center light per intact summoning portal group
  static function addSummoningPortalLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      areaLighting: AreaLighting)
    {
      var processedRootIDs = new Map();
      for (o in area.getObjects())
        {
          if (o.type != 'summoning_portal')
            continue;

          var portal: SummoningPortal = cast o;
          var rootID = (portal.portalRootObjectID >= 0 ?
            portal.portalRootObjectID : portal.id);
          if (processedRootIDs[rootID])
            continue;
          processedRootIDs[rootID] = true;

          var rootPortal: SummoningPortal = portal;
          if (rootID != portal.id)
            {
              var rootObj = area.getObject(rootID);
              if (rootObj != null &&
                  rootObj.type == 'summoning_portal')
                rootPortal = cast rootObj;
            }
          if (rootPortal.isBroken)
            continue;

          var partObjectIDs = rootPortal.portalPartObjectIDs;
          if (partObjectIDs == null ||
              partObjectIDs.length == 0)
            partObjectIDs = portal.portalPartObjectIDs;

          var x1 = rootPortal.x;
          var y1 = rootPortal.y;
          var x2 = rootPortal.x;
          var y2 = rootPortal.y;
          if (partObjectIDs != null &&
              partObjectIDs.length > 0)
            for (objectID in partObjectIDs)
              {
                var partObj = area.getObject(objectID);
                if (partObj == null ||
                    partObj.type != 'summoning_portal')
                  continue;
                if (partObj.x < x1)
                  x1 = partObj.x;
                if (partObj.y < y1)
                  y1 = partObj.y;
                if (partObj.x > x2)
                  x2 = partObj.x;
                if (partObj.y > y2)
                  y2 = partObj.y;
              }

          var centerX = (x1 + x2 + 1) / 2.0;
          var centerY = (y1 + y2 + 1) / 2.0;
          areaLighting.pushLightStamp(area, stamps, centerX, centerY,
            UndergroundLab.ATMOS_LIGHT_LARGE_RED, 'summoning-portal');
        }
    }

// add one white light per sewer exit object
  static function addSewerExitLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      areaLighting: AreaLighting)
    {
      for (o in area.getObjects())
        {
          if (o.type != 'sewer_exit' &&
              o.type != 'habitat_exit')
            continue;

          var stampKind = (o.type == 'habitat_exit' ?
            'habitat-exit' : 'sewer-exit');
          areaLighting.pushLightStamp(area, stamps,
            o.x + 0.5, o.y + 0.5,
            UndergroundLab.ATMOS_LIGHT_LARGE_WHITE, stampKind);
        }
    }

// add sewer corridor lights without any room-light pass
  static function addSewerCorridorLayoutLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, sewerTileset: Sewers,
      areaLighting: AreaLighting)
    {
      var sources = [];
      addSewerCorridorLayoutSources(area, sources, sewerTileset);
      areaLighting.addLayoutLightSources(area, stamps, sources);
    }

// add sewer lights only at 3x3 corridor corners and intersections
  static function addSewerCorridorLayoutSources(area: AreaGame,
      sources: Array<_LayoutLightSource>, sewerTileset: Sewers)
    {
      if (area.generatorInfo == null ||
          area.generatorInfo.rooms == null)
        return;

      var roomMask = buildRoomMask(area);
      var doorMask = buildDoorMask(area);
      var corridorMask = buildCorridorMask(area, sewerTileset, roomMask,
        doorMask);
      var corridorLight = getLayoutCorridorLight();

      for (y in 0...area.height - 2)
        for (x in 0...area.width - 2)
          {
            if (!isSolidSewerCorridorBlock(corridorMask, x, y))
              continue;

            var north = hasSewerHorizontalBranch(corridorMask, x, y - 1);
            var south = hasSewerHorizontalBranch(corridorMask, x, y + 3);
            var west = hasSewerVerticalBranch(corridorMask, x - 1, y);
            var east = hasSewerVerticalBranch(corridorMask, x + 3, y);

            var directionCount = 0;
            if (north)
              directionCount++;
            if (south)
              directionCount++;
            if (west)
              directionCount++;
            if (east)
              directionCount++;

            var isCorner = (directionCount == 2 &&
              ((north || south) &&
               (west || east)));
            var isIntersection = directionCount >= 3;
            if (!isCorner &&
                !isIntersection)
              continue;

            sources.push({
              x: x + 1.5,
              y: y + 1.5,
              tintR: corridorLight.tintR,
              tintG: corridorLight.tintG,
              tintB: corridorLight.tintB,
              kind: 'layout-corridor',
              sourceGroupID: 'corridor-node',
            });
          }
    }

// check whether one 3x3 block is fully corridor floor
  static function isSolidSewerCorridorBlock(
      corridorMask: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      for (dy in 0...3)
        for (dx in 0...3)
          if (!getCorridorMask(corridorMask, x + dx, y + dy))
            return false;
      return true;
    }

// check whether one 3-tile horizontal branch continues beyond a node
  static function hasSewerHorizontalBranch(
      corridorMask: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (getCorridorMask(corridorMask, x, y) &&
        getCorridorMask(corridorMask, x + 1, y) &&
        getCorridorMask(corridorMask, x + 2, y));
    }

// check whether one 3-tile vertical branch continues beyond a node
  static function hasSewerVerticalBranch(
      corridorMask: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (getCorridorMask(corridorMask, x, y) &&
        getCorridorMask(corridorMask, x, y + 1) &&
        getCorridorMask(corridorMask, x, y + 2));
    }

// safely read one corridor-mask tile
  static function getCorridorMask(
      corridorMask: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= corridorMask.length ||
          y >= corridorMask[x].length)
        return false;
      return corridorMask[x][y];
    }

// build boolean mask of room tiles from generator room rectangles
  static function buildRoomMask(area: AreaGame): Array<Array<Bool>>
    {
      var mask = [];
      for (x in 0...area.width)
        {
          mask[x] = [];
          for (y in 0...area.height)
            mask[x][y] = false;
        }

      for (room in area.generatorInfo.rooms)
        for (y in room.y1...room.y2 + 1)
          for (x in room.x1...room.x2 + 1)
            mask[x][y] = true;
      return mask;
    }

// build corridor mask from walkable non-room tiles for the current tileset
  static function buildCorridorMask(area: AreaGame, tileset: Tileset,
      roomMask: Array<Array<Bool>>,
      doorMask: Array<Array<Bool>>): Array<Array<Bool>>
    {
      var mask = [];
      for (x in 0...area.width)
        {
          mask[x] = [];
          for (y in 0...area.height)
            {
              var tileID = area.getCellType(x, y);
              mask[x][y] = (!roomMask[x][y] &&
                !doorMask[x][y] &&
                tileset.isWalkable(tileID));
            }
        }
      return mask;
    }

// build boolean mask of door object tiles
  static function buildDoorMask(area: AreaGame): Array<Array<Bool>>
    {
      var mask = [];
      for (x in 0...area.width)
        {
          mask[x] = [];
          for (y in 0...area.height)
            mask[x][y] = false;
        }

      for (o in area.getObjects())
        {
          if (o.type != 'door' ||
              o.x < 0 ||
              o.y < 0 ||
              o.x >= area.width ||
              o.y >= area.height)
            continue;
          mask[o.x][o.y] = true;
        }
      return mask;
    }

// get corridor color profile for layout light sources
  static function getLayoutCorridorLight(): _AtmosphereLightMeta
    {
      return UndergroundLab.ATMOS_LIGHT_LARGE_WHITE;
    }
}

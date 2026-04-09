package lighting;

import _AtmosphereLightMeta;
import AreaLighting;
import Const;
import GameScene;
import game.AreaGame;
import objects.mission.CloneVat;
import tiles.*;

class UndergroundLabAreaLighting
{
// layout room role ID for entry rooms
  static var LAYOUT_ROLE_ENTRANCE = 'entrance';
// layout room role ID for clone-vat rooms
  static var LAYOUT_ROLE_VAT = 'vat';
// layout room role ID for workshop rooms
  static var LAYOUT_ROLE_WORKSHOP = 'workshop';
// layout room role ID for storage rooms
  static var LAYOUT_ROLE_STORAGE = 'storage';
// layout room role ID for research rooms
  static var LAYOUT_ROLE_RESEARCH = 'research';
// spacing in tiles between corridor light anchors
  static var LAYOUT_LIGHT_CORRIDOR_SPACING = 4;
// minimum corridor run span required before placing lights
  static var LAYOUT_LIGHT_CORRIDOR_MIN_RUN_SPAN = 3;

// build underground-lab atmosphere light stamps
  public static function buildLightStamps(scene: GameScene, area: AreaGame,
      areaLighting: AreaLighting): Array<_AreaLightStamp>
    {
      var stamps = [];
      if (scene == null ||
          scene.images == null)
        return stamps;

      var tileset = scene.images.getTileset(area.typeID);
      if (!Std.isOfType(tileset, UndergroundLab))
        return stamps;

      if (area.tiles == null ||
          area.tiles.length == 0)
        area.initTilesFromCells();
      var undergroundLab: UndergroundLab = cast tileset;

      addFloorDecorationLights(area, stamps, areaLighting);
      addWallDecorationLights(area, stamps, undergroundLab, areaLighting);
      addNearTopWallDecorationLights(area, stamps, undergroundLab, areaLighting);
      addDecorationObjectLights(area, stamps, undergroundLab, areaLighting);
      addCloneVatLights(area, stamps, areaLighting);
      addRoomAndCorridorLayoutLights(area, stamps, undergroundLab, areaLighting);
      return stamps;
    }

// collect underground-lab projected-shadow casters
  public static function collectProjectedShadowCasters(area: AreaGame,
      undergroundLab: UndergroundLab): Array<_ProjectedShadowCaster>
    {
      var casters = [];
      var groups = collectDecorationObjGroups(area, undergroundLab);
      for (group in groups)
        {
          var blockInfo = getDecorationObjBlock(undergroundLab, group, false);
          if (blockInfo == null)
            continue;
          var layerID = group.layerID;
          casters.push({
            layerID: layerID,
            image: undergroundLab.floorDecorationLayers[layerID],
            maskKey: layerID + ':' + blockInfo.block.row + ':' +
              blockInfo.block.col + ':' + blockInfo.block.width + ':' +
              blockInfo.block.height,
            srcRow: blockInfo.block.row,
            srcCol: blockInfo.block.col,
            blockW: blockInfo.block.width,
            blockH: blockInfo.block.height,
            centerX: (group.x1 + group.x2 + 1) / 2.0,
            centerY: (group.y1 + group.y2 + 1) / 2.0,
            skipSelfShadow: false,
          });
        }

      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = tiles[x][y];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            var tileID = area.getCellType(x, y);
            if (!undergroundLab.isHorizontalWallTile(tileID))
              continue;
            for (decoration in tile.decoration)
              {
                if (!undergroundLab.isNearTopWallDecorationWallLayerID(
                    decoration.layerID) ||
                    decoration.icon == null)
                  continue;
                var blockInfo = getNearTopWallDecorationBlock(undergroundLab,
                  decoration.layerID, decoration.icon.row, decoration.icon.col);
                if (blockInfo == null)
                  continue;
                var layerID = undergroundLab.getNearTopDecorationLayerID(
                  blockInfo, 1);
                casters.push({
                  layerID: layerID,
                  image: undergroundLab.floorDecorationLayers[layerID],
                  maskKey: layerID + ':' + blockInfo.block.row + ':' +
                    blockInfo.block.col + ':' + blockInfo.block.width + ':' +
                    blockInfo.block.height,
                  srcRow: blockInfo.block.row,
                  srcCol: blockInfo.block.col,
                  blockW: blockInfo.block.width,
                  blockH: blockInfo.block.height,
                  centerX: x + blockInfo.block.width / 2.0,
                  centerY: y + blockInfo.block.height / 2.0,
                  skipSelfShadow: false,
                });
              }
          }
      return casters;
    }

// resolve one debug-friendly decoration source id for a lab decoration
  public static function getDebugDecorationSourceID(undergroundLab: UndergroundLab,
      tileID: Int, decoration: Decoration): String
    {
      if (decoration.icon == null)
        return '-';

      if (decoration.tag != null &&
          decoration.tag.indexOf('DECO_OBJ:') == 0)
        {
          var objectSourceID = getDecorationObjDebugSourceID(undergroundLab,
            decoration);
          if (objectSourceID != null)
            return objectSourceID;
        }

      var nearTopSourceID = getNearTopDebugSourceID(undergroundLab, tileID,
        decoration);
      if (nearTopSourceID != null)
        return nearTopSourceID;

      if (decoration.layerID == 0)
        {
          var floorSourceID = getFloorDecorDebugSourceID(decoration.icon);
          if (floorSourceID != null)
            return floorSourceID;
        }

      return '-';
    }

// add floor decoration light stamps from floor metadata
  static function addFloorDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      areaLighting: AreaLighting)
    {
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = tiles[x][y];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;

            for (decoration in tile.decoration)
              {
                if (decoration.layerID != 0 ||
                    decoration.icon == null)
                  continue;

                for (floorMeta in UndergroundLab.FLOOR_DECOR_META)
                  {
                    if (floorMeta.icon.row != decoration.icon.row ||
                        floorMeta.icon.col != decoration.icon.col ||
                        floorMeta.light == null)
                      continue;

                    areaLighting.pushLightStamp(area, stamps,
                      x + 0.5, y + 0.5,
                      floorMeta.light,
                      'floor-decor');
                    break;
                  }
              }
          }
    }

// add wall decoration light stamps from wall layer metadata
  static function addWallDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab,
      areaLighting: AreaLighting)
    {
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = tiles[x][y];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            var tileID = area.getCellType(x, y);
            if (!undergroundLab.isWallTile(tileID))
              continue;

            var hasNearTopDecoration = false;
            for (decoration in tile.decoration)
              {
                if (undergroundLab.isNearTopWallDecorationWallLayerID(
                    decoration.layerID))
                  {
                    hasNearTopDecoration = true;
                    break;
                  }
              }
            if (hasNearTopDecoration)
              continue;

            for (decoration in tile.decoration)
              {
                var light = undergroundLab.getWallDecorationLayerLight(
                  decoration.layerID);
                if (light == null)
                  continue;
                areaLighting.pushLightStamp(area, stamps,
                  x + 0.5, y + 0.5,
                  light, 'wall-decor');
              }
          }
    }

// add near-top wall decoration light stamps from near-top metadata
  static function addNearTopWallDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab,
      areaLighting: AreaLighting)
    {
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = tiles[x][y];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            var tileID = area.getCellType(x, y);
            if (!undergroundLab.isHorizontalWallTile(tileID))
              continue;

            for (decoration in tile.decoration)
              {
                if (!undergroundLab.isNearTopWallDecorationWallLayerID(
                    decoration.layerID) ||
                    decoration.icon == null)
                  continue;
                var blockInfo = getNearTopWallDecorationBlock(undergroundLab,
                  decoration.layerID, decoration.icon.row, decoration.icon.col);
                if (blockInfo == null ||
                    blockInfo.meta.light == null)
                  continue;
                areaLighting.pushLightStamp(area, stamps,
                  x + 0.5, y + 1.5,
                  blockInfo.meta.light, 'near-top-wall');
              }
          }
    }

// get near-top wall block metadata by layer and wall icon coordinates
  static function getNearTopWallDecorationBlock(undergroundLab: UndergroundLab,
      layerID: Int, row: Int, col: Int): _DecorBlock
    {
      for (blockInfo in UndergroundLab.NEAR_TOP_WALL_META)
        {
          if (blockInfo.block.row != row ||
              blockInfo.block.col != col)
            continue;
          if (undergroundLab.getNearTopDecorationLayerID(blockInfo, 0) != layerID)
            continue;
          return blockInfo;
        }
      return null;
    }

// collect grouped decoration object bounds keyed by placement tags
  static function collectDecorationObjGroups(area: AreaGame,
      undergroundLab: UndergroundLab): Array<_AtmosphereDecorObjGroup>
    {
      var groupsByTag: Map<String, _AtmosphereDecorObjGroup> = new Map();
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = tiles[x][y];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;

            for (decoration in tile.decoration)
              {
                if (decoration.tag == null ||
                    decoration.icon == null ||
                    decoration.tag.indexOf('DECO_OBJ:') != 0 ||
                    !undergroundLab.isDecorationObjLayerID(decoration.layerID))
                  continue;

                var group = groupsByTag.get(decoration.tag);
                if (group == null)
                  {
                    groupsByTag.set(decoration.tag, {
                      layerID: decoration.layerID,
                      x1: x,
                      y1: y,
                      x2: x,
                      y2: y,
                      minIconRow: decoration.icon.row,
                      minIconCol: decoration.icon.col,
                    });
                    continue;
                  }

                if (x < group.x1)
                  group.x1 = x;
                if (y < group.y1)
                  group.y1 = y;
                if (x > group.x2)
                  group.x2 = x;
                if (y > group.y2)
                  group.y2 = y;
                if (decoration.icon.row < group.minIconRow)
                  group.minIconRow = decoration.icon.row;
                if (decoration.icon.col < group.minIconCol)
                  group.minIconCol = decoration.icon.col;
              }
          }

      var groups = [];
      for (group in groupsByTag)
        groups.push(group);
      return groups;
    }

// add decoration object light stamps by grouped object placement tags
  static function addDecorationObjectLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab,
      areaLighting: AreaLighting)
    {
      var groups = collectDecorationObjGroups(area, undergroundLab);
      for (group in groups)
        {
          var blockInfo = getDecorationObjBlock(undergroundLab, group, true);
          if (blockInfo == null ||
              blockInfo.meta.light == null)
            continue;

          var centerX = (group.x1 + group.x2 + 1) / 2.0;
          var centerY = (group.y1 + group.y2 + 1) / 2.0;
          areaLighting.pushLightStamp(area, stamps, centerX, centerY,
            blockInfo.meta.light, blockInfo.meta.id);
        }
    }

// get decoration object block info from grouped placement signature
  static function getDecorationObjBlock(undergroundLab: UndergroundLab,
      group: _AtmosphereDecorObjGroup, requireLight: Bool): _DecorBlock
    {
      var width = group.x2 - group.x1 + 1;
      var height = group.y2 - group.y1 + 1;
      for (b in UndergroundLab.DECORATION_OBJ_META)
        {
          if (b.meta.imageKey == null)
            continue;
          if (requireLight &&
              b.meta.light == null)
            continue;
          if (b.block.row != group.minIconRow ||
              b.block.col != group.minIconCol ||
              b.block.width != width ||
              b.block.height != height)
            continue;

          var layerID = undergroundLab.getDecorationObjLayerID(
            b.meta.imageKey);
          if (layerID == group.layerID)
            return b;
        }
      return null;
    }

// add one center light per clone vat group
  static function addCloneVatLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      areaLighting: AreaLighting)
    {
      var processedRootIDs = new Map();
      for (o in area.getObjects())
        {
          if (o.type != 'clone_vat')
            continue;

          var vat: CloneVat = cast o;
          var rootID = (vat.vatRootObjectID >= 0 ?
            vat.vatRootObjectID : vat.id);
          if (processedRootIDs[rootID])
            continue;
          processedRootIDs[rootID] = true;

          var rootVat: CloneVat = vat;
          if (rootID != vat.id)
            {
              var rootObj = area.getObject(rootID);
              if (rootObj != null &&
                  rootObj.type == 'clone_vat')
                rootVat = cast rootObj;
            }
          if (rootVat.isFlushed)
            continue;

          var partObjectIDs = rootVat.vatPartObjectIDs;
          if (partObjectIDs == null ||
              partObjectIDs.length == 0)
            partObjectIDs = vat.vatPartObjectIDs;

          var x1 = rootVat.x;
          var y1 = rootVat.y;
          var x2 = rootVat.x;
          var y2 = rootVat.y;
          if (partObjectIDs != null &&
              partObjectIDs.length > 0)
            for (objectID in partObjectIDs)
              {
                var partObj = area.getObject(objectID);
                if (partObj == null ||
                    partObj.type != 'clone_vat')
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
            UndergroundLab.ATMOS_LIGHT_LARGE_GREEN, 'clone-vat', true);
        }
    }

// add role-based room and corridor lights with two-pass profiles
  static function addRoomAndCorridorLayoutLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab,
      areaLighting: AreaLighting)
    {
      var sources = [];
      addRoomLayoutSources(area, sources);
      addCorridorLayoutSources(area, sources, undergroundLab);
      areaLighting.addLayoutLightSources(area, stamps, sources);
    }

// add evenly spaced room light sources based on room dimensions
  static function addRoomLayoutSources(area: AreaGame,
      sources: Array<_LayoutLightSource>)
    {
      if (area.generatorInfo == null ||
          area.generatorInfo.rooms == null ||
          area.generatorInfo.rooms.length == 0)
        return;
      for (room in area.generatorInfo.rooms)
        {
          var xAnchors = buildRoomAxisAnchors(room.x1, room.w);
          var yAnchors = buildRoomAxisAnchors(room.y1, room.h);
          var roleLight = getLayoutRoomRoleLight(room.role);
          for (y in yAnchors)
            for (x in xAnchors)
              sources.push({
                x: x,
                y: y,
                tintR: roleLight.tintR,
                tintG: roleLight.tintG,
                tintB: roleLight.tintB,
                kind: 'layout-room',
                sourceGroupID: 'room-' + room.id,
              });
        }
    }

// add corridor centerline sources from horizontal and vertical runs
  static function addCorridorLayoutSources(area: AreaGame,
      sources: Array<_LayoutLightSource>, undergroundLab: UndergroundLab)
    {
      if (area.generatorInfo == null ||
          area.generatorInfo.rooms == null)
        return;

      var roomMask = buildRoomMask(area);
      var doorMask = buildDoorMask(area);
      var corridorMask = buildCorridorMask(area, undergroundLab, roomMask,
        doorMask);
      var corridorLight = getLayoutCorridorLight();

      for (y in 0...area.height - 1)
        {
          var x = 0;
          while (x < area.width)
            {
              if (!(corridorMask[x][y] &&
                  corridorMask[x][y + 1]))
                {
                  x++;
                  continue;
                }
              var runStart = x;
              while (x < area.width &&
                  corridorMask[x][y] &&
                  corridorMask[x][y + 1])
                x++;
              var runEnd = x - 1;
              var runSpan = runEnd - runStart + 1;
              if (runSpan < LAYOUT_LIGHT_CORRIDOR_MIN_RUN_SPAN)
                continue;
              var anchors = buildRunAnchors(runStart, runEnd + 1,
                LAYOUT_LIGHT_CORRIDOR_SPACING);
              for (ax in anchors)
                sources.push({
                  x: ax,
                  y: y + 1,
                  tintR: corridorLight.tintR,
                  tintG: corridorLight.tintG,
                  tintB: corridorLight.tintB,
                  kind: 'layout-corridor',
                  sourceGroupID: 'corridor',
                });
            }
        }

      for (x in 0...area.width - 1)
        {
          var y = 0;
          while (y < area.height)
            {
              if (!(corridorMask[x][y] &&
                  corridorMask[x + 1][y]))
                {
                  y++;
                  continue;
                }
              var runStart = y;
              while (y < area.height &&
                  corridorMask[x][y] &&
                  corridorMask[x + 1][y])
                y++;
              var runEnd = y - 1;
              var runSpan = runEnd - runStart + 1;
              if (runSpan < LAYOUT_LIGHT_CORRIDOR_MIN_RUN_SPAN)
                continue;
              var anchors = buildRunAnchors(runStart, runEnd + 1,
                LAYOUT_LIGHT_CORRIDOR_SPACING);
              for (ay in anchors)
                sources.push({
                  x: x + 1,
                  y: ay,
                  tintR: corridorLight.tintR,
                  tintG: corridorLight.tintG,
                  tintB: corridorLight.tintB,
                  kind: 'layout-corridor',
                  sourceGroupID: 'corridor',
                });
            }
        }
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

// build one room axis anchor sequence by room-size rule
  static function buildRoomAxisAnchors(start: Int, size: Int): Array<Int>
    {
      var minPos = start + 1;
      var maxPos = start + size - 1;
      if (minPos > maxPos)
        return [start];

      var count = getRoomAxisAnchorCount(size);
      if (count <= 1)
        return [Std.int(Math.round((minPos + maxPos) / 2.0))];
      if (count == 2)
        {
          var pos1 = Std.int(Math.round(start + size * 0.25));
          var pos2 = Std.int(Math.round(start + size * 0.75));
          pos1 = Const.clamp(pos1, minPos, maxPos);
          pos2 = Const.clamp(pos2, minPos, maxPos);
          if (pos2 <= pos1)
            pos2 = Const.clamp(pos1 + 1, minPos, maxPos);
          if (pos1 == pos2)
            return [pos1];
          return [pos1, pos2];
        }

      // for larger dimensions, place one anchor per 4-tile block at block center
      var blockAnchors = [];
      var blockStart = 0;
      while (blockStart < size)
        {
          var blockEnd = blockStart + 4;
          if (blockEnd > size)
            blockEnd = size;
          var pos = Std.int(Math.round(start + (blockStart + blockEnd) / 2.0));
          pos = Const.clamp(pos, minPos, maxPos);
          if (blockAnchors.indexOf(pos) < 0)
            blockAnchors.push(pos);
          blockStart += 4;
        }
      if (blockAnchors.length > 0)
        {
          var filteredBlockAnchors = [];
          for (pos in blockAnchors)
            {
              if (filteredBlockAnchors.length > 0 &&
                  pos - filteredBlockAnchors[filteredBlockAnchors.length - 1] < 3)
                continue;
              filteredBlockAnchors.push(pos);
            }
          if (filteredBlockAnchors.length > 0)
            return filteredBlockAnchors;
        }

      var anchors = [];
      for (i in 0...count)
        {
          var t = (i + 1.0) / (count + 1.0);
          var pos = Std.int(Math.round(minPos + (maxPos - minPos) * t));
          pos = Const.clamp(pos, minPos, maxPos);
          if (anchors.indexOf(pos) < 0)
            anchors.push(pos);
        }
      if (anchors.length <= 0)
        anchors.push(Std.int(Math.round((minPos + maxPos) / 2.0)));
      return anchors;
    }

// get room axis anchor count from room dimension
  static function getRoomAxisAnchorCount(size: Int): Int
    {
      if (size <= 8)
        return 1;
      return Std.int(Math.ceil(size / 8.0));
    }

// build centered run anchors with approximate fixed spacing
  static function buildRunAnchors(start: Int, end: Int,
      spacing: Int): Array<Int>
    {
      var span = end - start;
      if (span <= 0)
        return [];

      var count = Std.int(Math.ceil(span / spacing));
      if (count < 1)
        count = 1;
      var anchors = [];
      for (i in 0...count)
        {
          var t = (i + 0.5) / count;
          var pos = Std.int(Math.round(start + span * t));
          pos = Const.clamp(pos, start, end);
          if (anchors.indexOf(pos) < 0)
            anchors.push(pos);
        }
      return anchors;
    }

// get room role color profile for layout light sources
  static function getLayoutRoomRoleLight(role: String): _AtmosphereLightMeta
    {
      if (role == LAYOUT_ROLE_ENTRANCE)
        return UndergroundLab.ATMOS_LIGHT_SMALL_CYAN;
      if (role == LAYOUT_ROLE_VAT)
        return UndergroundLab.ATMOS_LIGHT_LARGE_GREEN;
      if (role == LAYOUT_ROLE_WORKSHOP)
        return UndergroundLab.ATMOS_LIGHT_LARGE_ORANGE;
      if (role == LAYOUT_ROLE_STORAGE)
        return UndergroundLab.ATMOS_LIGHT_LARGE_RED;
      if (role == LAYOUT_ROLE_RESEARCH)
        return UndergroundLab.ATMOS_LIGHT_LARGE_BLUE;
      return UndergroundLab.ATMOS_LIGHT_LARGE_BLUE;
    }

// get corridor color profile for layout light sources
  static function getLayoutCorridorLight(): _AtmosphereLightMeta
    {
      return UndergroundLab.ATMOS_LIGHT_LARGE_WHITE;
    }

// resolve debug source id for a floor decoration icon
  static function getFloorDecorDebugSourceID(icon: _Icon): String
    {
      for (floorMeta in UndergroundLab.FLOOR_DECOR_META)
        {
          if (floorMeta.icon.row != icon.row ||
              floorMeta.icon.col != icon.col)
            continue;
          return 'floor:' + floorMeta.motifs.join('+');
        }
      return null;
    }

// resolve debug source id for an object decoration fragment
  static function getDecorationObjDebugSourceID(undergroundLab: UndergroundLab,
      decoration: Decoration): String
    {
      for (blockInfo in UndergroundLab.DECORATION_OBJ_META)
        {
          if (blockInfo.meta.imageKey == null)
            continue;
          if (undergroundLab.getDecorationObjLayerID(blockInfo.meta.imageKey) !=
              decoration.layerID)
            continue;
          if (decoration.icon.row < blockInfo.block.row ||
              decoration.icon.row >= blockInfo.block.row + blockInfo.block.height ||
              decoration.icon.col < blockInfo.block.col ||
              decoration.icon.col >= blockInfo.block.col + blockInfo.block.width)
            continue;
          return 'object:' + blockInfo.meta.id;
        }
      return null;
    }

// resolve debug source id for a near-top decoration fragment on the correct tile namespace
  static function getNearTopDebugSourceID(undergroundLab: UndergroundLab,
      tileID: Int, decoration: Decoration): String
    {
      var isWallTile = undergroundLab.isWallTile(tileID);
      for (b in UndergroundLab.NEAR_TOP_WALL_META)
        {
          var rowDYs = (isWallTile ? [0] : [1]);
          for (dy in rowDYs)
            {
              if (dy >= b.block.height)
                continue;
              if (undergroundLab.getNearTopDecorationLayerID(b, dy) !=
                  decoration.layerID)
                continue;
              if (decoration.icon.row != b.block.row + dy ||
                  decoration.icon.col < b.block.col ||
                  decoration.icon.col >= b.block.col + b.block.width)
                continue;
              return 'nearTop:' + b.meta.id;
            }
        }
      return null;
    }
}

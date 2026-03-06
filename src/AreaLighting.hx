// area atmosphere lighting orchestration and light-stamp building

import haxe.Timer;
import haxe.ds.IntMap;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import game.AreaGame;
import game.Game;
import objects.mission.CloneVat;
import particles.Particle;
import particles._ParticleLightPulse;
import tiles.UndergroundLab;
import tiles.UndergroundLab._DecorBlock;

class AreaLighting
{
  static var ATMOS_LIGHTMAP_TILE_SIZE = 8;
  static var ATMOS_DYNAMIC_REBUILD_MS = 25;
  static var ATMOS_MAX_TRANSIENT_LIGHTS = 14;

  var scene: GameScene;
  var game: Game;
  var staticMap: CanvasElement;
  var dynamicMap: CanvasElement;
  var composeMap: CanvasElement;
  var visibilityMaskMap: CanvasElement;
  var mapAreaID: Int;
  var staticDirty: Bool;
  var dynamicDirty: Bool;
  var dynamicRebuildTS: Float;
  var transientAtmosphereLights: Array<_TransientAtmosphereLight>;
  var areaLightStampsByAreaID: IntMap<Array<_AreaLightStamp>>;

// create area lighting service for one scene
  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      staticMap = null;
      dynamicMap = null;
      composeMap = null;
      visibilityMaskMap = null;
      mapAreaID = -1;
      staticDirty = true;
      dynamicDirty = true;
      dynamicRebuildTS = 0;
      transientAtmosphereLights = [];
      areaLightStampsByAreaID = new IntMap();
    }

// draw full atmosphere lighting overlay for current area
  public function drawAreaLighting(ctx: CanvasRenderingContext2D,
      cache: Array<Array<Int>>)
    {
      var area = game.area;
      if (!hasLighting(area))
        return;

      if (mapAreaID != area.id)
        {
          mapAreaID = area.id;
          staticDirty = true;
          dynamicDirty = true;
          transientAtmosphereLights = [];
        }

      // make sure atmosphere maps exist and match area size, rebuild if area changed
      ensureMaps(area);

      var nowTS = Timer.stamp() * 1000;
      // remove expired transient lights
      pruneTransientLights(nowTS);
      // rebuild static map if area changed
      if (staticDirty)
        rebuildStaticMap(area);

      // rebuild dynamic map if transient lights changed or it's been a while since last rebuild
      if (transientAtmosphereLights.length > 0)
        dynamicDirty = true;
      if (dynamicDirty &&
          (transientAtmosphereLights.length == 0 ||
           nowTS - dynamicRebuildTS >= ATMOS_DYNAMIC_REBUILD_MS))
        rebuildDynamicMap(nowTS);

      // compose atmosphere overlay from static and dynamic maps, masked by current visibility, and draw it
      composeOverlay(area, cache);
      drawComposed(ctx);
      fillUnseenBase(area, cache, ctx);
    }

// queue atmosphere light pulses emitted by one particle
  public function onParticleAdded(p: Particle)
    {
      var area = game.area;
      if (!hasLighting(area))
        return;

      var pulses = p.getLightPulses();
      if (pulses == null ||
          pulses.length == 0)
        return;

      for (pulse in pulses)
        addTransientLight(pulse);
    }

// check if transient pulse lights are active
  public inline function hasActiveTransientLights(): Bool
    {
      return transientAtmosphereLights.length > 0;
    }

// invalidate cached lighting for one area
  public function invalidateArea(area: AreaGame)
    {
      if (area == null)
        return;

      areaLightStampsByAreaID.remove(area.id);
      if (game.area != null &&
          game.area.id == area.id)
        invalidateCurrentView();
    }

// invalidate current view atmosphere maps and transient pulses
  public function invalidateCurrentView()
    {
      mapAreaID = -1;
      staticDirty = true;
      dynamicDirty = true;
      transientAtmosphereLights = [];
    }

// check whether this area uses atmosphere lighting
  inline function hasLighting(area: AreaGame): Bool
    {
      return (area != null &&
        area.info != null &&
        area.info.id == AREA_UNDERGROUND_LAB);
    }

// get cached static atmosphere light stamps for an area
  function getAreaLightStamps(area: AreaGame): Array<_AreaLightStamp>
    {
      if (!hasLighting(area))
        return [];

      var stamps = areaLightStampsByAreaID.get(area.id);
      if (stamps != null)
        return stamps;

      stamps = buildUndergroundLabLightStamps(area);
      areaLightStampsByAreaID.set(area.id, stamps);
      return stamps;
    }

// build underground lab atmosphere stamps from placed light sources
  function buildUndergroundLabLightStamps(area: AreaGame): Array<_AreaLightStamp>
    {
      var stamps = [];
      if (game == null ||
          scene == null ||
          scene.images == null)
        return stamps;

      var tileset = scene.images.getTileset(area.typeID);
      if (!Std.isOfType(tileset, UndergroundLab))
        return stamps;

      if (area.tiles == null ||
          area.tiles.length == 0)
        area.initTilesFromCells();
      var undergroundLab: UndergroundLab = cast tileset;

      addFloorDecorationLights(area, stamps);
      addWallDecorationLights(area, stamps, undergroundLab);
      addNearTopWallDecorationLights(area, stamps, undergroundLab);
      addDecorationObjectLights(area, stamps, undergroundLab);
      addCloneVatLights(area, stamps);
      return stamps;
    }

// add floor decoration light stamps from floor metadata
  function addFloorDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>)
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

                    pushLightStamp(area, stamps, x + 0.5, y + 0.5,
                      floorMeta.light,
                      'floor-decor');
                    break;
                  }
              }
          }
    }

// add wall decoration light stamps from wall layer metadata
  function addWallDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab)
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
                if (decoration.layerID == undergroundLab.nearTopWallWallLayerID)
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
                pushLightStamp(area, stamps, x + 0.5, y + 0.5,
                  light, 'wall-decor');
              }
          }
    }

// add near-top wall decoration light stamps from near-top metadata
  function addNearTopWallDecorationLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab)
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
                if (decoration.layerID != undergroundLab.nearTopWallWallLayerID ||
                    decoration.icon == null)
                  continue;

                var light = getNearTopWallDecorationLight(
                  decoration.icon.row, decoration.icon.col);
                if (light == null)
                  continue;
                pushLightStamp(area, stamps, x + 0.5, y + 1.5,
                  light, 'near-top-wall');
              }
          }
    }

// get near-top wall light metadata by wall icon coordinates
  function getNearTopWallDecorationLight(row: Int, col: Int): _AtmosphereLightMeta
    {
      for (blockInfo in UndergroundLab.NEAR_TOP_WALL_META)
        {
          if (blockInfo.block.row != row ||
              blockInfo.block.col != col ||
              blockInfo.meta.light == null)
            continue;
          return blockInfo.meta.light;
        }
      return null;
    }

// add decoration object light stamps by grouped object placement tags
  function addDecorationObjectLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab)
    {
      var groups: Map<String, _AtmosphereDecorObjGroup> = new Map();
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

                var group = groups.get(decoration.tag);
                if (group == null)
                  {
                    groups.set(decoration.tag, {
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

      for (group in groups)
        {
          var blockInfo = getDecorationObjLightBlock(undergroundLab, group);
          if (blockInfo == null ||
              blockInfo.meta.light == null)
            continue;

          var centerX = (group.x1 + group.x2 + 1) / 2.0;
          var centerY = (group.y1 + group.y2 + 1) / 2.0;
          pushLightStamp(area, stamps, centerX, centerY,
            blockInfo.meta.light, blockInfo.meta.id);
        }
    }

// get decoration object block info from grouped placement signature
  function getDecorationObjLightBlock(undergroundLab: UndergroundLab,
      group: _AtmosphereDecorObjGroup): _DecorBlock
    {
      var width = group.x2 - group.x1 + 1;
      var height = group.y2 - group.y1 + 1;
      for (blockInfo in UndergroundLab.DECORATION_OBJ_META)
        {
          if (blockInfo.meta.light == null ||
              blockInfo.meta.imageKey == null)
            continue;
          if (blockInfo.block.row != group.minIconRow ||
              blockInfo.block.col != group.minIconCol ||
              blockInfo.block.width != width ||
              blockInfo.block.height != height)
            continue;

          var layerID = undergroundLab.getDecorationObjLayerID(
            blockInfo.meta.imageKey);
          if (layerID == group.layerID)
            return blockInfo;
        }
      return null;
    }

// add clone vat lights with hybrid multi-stamp placement for large vats
  function addCloneVatLights(area: AreaGame, stamps: Array<_AreaLightStamp>)
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

          var vatWidth = x2 - x1 + 1;
          var vatHeight = y2 - y1 + 1;
          if (vatWidth >= 2 &&
              vatHeight >= 2)
            {
              var centerY = (y1 + y2 + 1) / 2.0;
              var leftX = x1 + vatWidth * 0.35;
              var rightX = x1 + vatWidth * 0.65;
              pushLightStamp(area, stamps, leftX, centerY,
                UndergroundLab.ATMOS_LIGHT_LARGE_GREEN, 'clone-vat');
              pushLightStamp(area, stamps, rightX, centerY,
                UndergroundLab.ATMOS_LIGHT_LARGE_GREEN, 'clone-vat');
              continue;
            }

          var centerX = (x1 + x2 + 1) / 2.0;
          var centerY = (y1 + y2 + 1) / 2.0;
          pushLightStamp(area, stamps, centerX, centerY,
            UndergroundLab.ATMOS_LIGHT_LARGE_GREEN, 'clone-vat');
        }
    }

// append one atmosphere light stamp with short-range deduplication
  function pushLightStamp(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      x: Float, y: Float, light: _AtmosphereLightMeta, kind: String)
    {
      var ix = Std.int(Math.floor(x));
      var iy = Std.int(Math.floor(y));
      if (ix < 0 ||
          iy < 0 ||
          ix >= area.width ||
          iy >= area.height)
        return;

      for (stamp in stamps)
        {
          var dx = stamp.x - x;
          var dy = stamp.y - y;
          if (dx * dx + dy * dy < 0.04)
            return;
        }

      stamps.push({
        x: x,
        y: y,
        radiusTiles: light.radiusTiles,
        intensity: light.intensity,
        tintR: light.tintR,
        tintG: light.tintG,
        tintB: light.tintB,
        kind: kind,
      });
    }

// add one short-lived atmosphere pulse light
  function addTransientLight(pulse: _ParticleLightPulse)
    {
      var nowTS = Timer.stamp() * 1000;
      transientAtmosphereLights.push({
        x: pulse.x,
        y: pulse.y,
        radiusTiles: pulse.radiusTiles,
        intensity: pulse.intensity,
        tintR: pulse.tintR,
        tintG: pulse.tintG,
        tintB: pulse.tintB,
        startTS: nowTS,
        endTS: nowTS + pulse.durationMs,
      });
      while (transientAtmosphereLights.length > ATMOS_MAX_TRANSIENT_LIGHTS)
        transientAtmosphereLights.shift();
      dynamicDirty = true;
    }

// remove expired transient atmosphere lights
  function pruneTransientLights(nowTS: Float)
    {
      var removed = false;
      var i = 0;
      while (i < transientAtmosphereLights.length)
        {
          if (nowTS >= transientAtmosphereLights[i].endTS)
            {
              transientAtmosphereLights.splice(i, 1);
              removed = true;
              continue;
            }
          i++;
        }
      if (removed)
        dynamicDirty = true;
    }

// make sure offscreen atmosphere maps exist and match area size
  function ensureMaps(area: AreaGame)
    {
      if (staticMap == null)
        staticMap = Browser.document.createCanvasElement();
      if (dynamicMap == null)
        dynamicMap = Browser.document.createCanvasElement();
      if (composeMap == null)
        composeMap = Browser.document.createCanvasElement();
      if (visibilityMaskMap == null)
        visibilityMaskMap = Browser.document.createCanvasElement();

      var mapWidth = Std.int(Math.ceil(area.width * ATMOS_LIGHTMAP_TILE_SIZE));
      var mapHeight = Std.int(Math.ceil(area.height * ATMOS_LIGHTMAP_TILE_SIZE));
      var screenWidth = scene.canvas.width;
      var screenHeight = scene.canvas.height;
      if (staticMap.width != mapWidth ||
          staticMap.height != mapHeight)
        {
          staticMap.width = mapWidth;
          staticMap.height = mapHeight;
          staticDirty = true;
        }
      if (dynamicMap.width != mapWidth ||
          dynamicMap.height != mapHeight)
        {
          dynamicMap.width = mapWidth;
          dynamicMap.height = mapHeight;
          dynamicDirty = true;
        }
      if (composeMap.width != screenWidth ||
          composeMap.height != screenHeight)
        {
          composeMap.width = screenWidth;
          composeMap.height = screenHeight;
        }
      if (visibilityMaskMap.width != screenWidth ||
          visibilityMaskMap.height != screenHeight)
        {
          visibilityMaskMap.width = screenWidth;
          visibilityMaskMap.height = screenHeight;
        }
    }

// rebuild static atmosphere overlay from area light stamps
  function rebuildStaticMap(area: AreaGame)
    {
      var mapCtx = staticMap.getContext2d();
      var mapWidth = staticMap.width;
      var mapHeight = staticMap.height;
      mapCtx.clearRect(0, 0, mapWidth, mapHeight);
      fillDarkBase(mapCtx, mapWidth, mapHeight);

      var stamps = getAreaLightStamps(area);
      for (stamp in stamps)
        paintStaticLight(mapCtx, stamp);
      staticDirty = false;
    }

// rebuild transient atmosphere overlay from active pulse lights
  function rebuildDynamicMap(nowTS: Float)
    {
      var mapCtx = dynamicMap.getContext2d();
      mapCtx.clearRect(0, 0, dynamicMap.width, dynamicMap.height);
      for (light in transientAtmosphereLights)
        paintDynamicLight(mapCtx, light, nowTS);
      dynamicRebuildTS = nowTS;
      dynamicDirty = false;
    }

// draw one atmosphere lightmap onto target context
  function paintMap(ctx: CanvasRenderingContext2D,
      map: CanvasElement, additive: Bool, dstX: Float, dstY: Float)
    {
      if (map == null ||
          map.width <= 0 ||
          map.height <= 0)
        return;

      var srcX = scene.cameraX * ATMOS_LIGHTMAP_TILE_SIZE / Const.TILE_SIZE;
      var srcY = scene.cameraY * ATMOS_LIGHTMAP_TILE_SIZE / Const.TILE_SIZE;
      var srcW = scene.canvas.width * ATMOS_LIGHTMAP_TILE_SIZE / Const.TILE_SIZE;
      var srcH = scene.canvas.height * ATMOS_LIGHTMAP_TILE_SIZE / Const.TILE_SIZE;
      if (srcW > map.width)
        srcW = map.width;
      if (srcH > map.height)
        srcH = map.height;
      if (srcX < 0)
        srcX = 0;
      else if (srcX + srcW > map.width)
        srcX = map.width - srcW;
      if (srcY < 0)
        srcY = 0;
      else if (srcY + srcH > map.height)
        srcY = map.height - srcH;

      if (srcW <= 0 ||
          srcH <= 0)
        return;

      ctx.save();
      if (additive)
        ctx.globalCompositeOperation = 'lighter';
      ctx.drawImage(map,
        srcX, srcY, srcW, srcH,
        dstX, dstY,
        scene.canvas.width, scene.canvas.height);
      ctx.restore();
    }

// compose atmosphere overlay and clip it by current visibility mask
  function composeOverlay(area: AreaGame, cache: Array<Array<Int>>)
    {
      var composeCtx = composeMap.getContext2d();
      composeCtx.clearRect(0, 0, composeMap.width,
        composeMap.height);
      paintMap(composeCtx, staticMap, false, 0, 0);
      if (transientAtmosphereLights.length > 0)
        paintMap(composeCtx, dynamicMap, true, 0, 0);

      rebuildVisibilityMask(area, cache);
      composeCtx.save();
      composeCtx.globalCompositeOperation = 'destination-in';
      composeCtx.drawImage(visibilityMaskMap, 0, 0);
      composeCtx.restore();
    }

// rebuild screen-space visibility mask from current tile visibility cache
  function rebuildVisibilityMask(area: AreaGame, cache: Array<Array<Int>>)
    {
      var maskCtx = visibilityMaskMap.getContext2d();
      maskCtx.clearRect(0, 0, visibilityMaskMap.width,
        visibilityMaskMap.height);
      maskCtx.fillStyle = '#ffffff';

      var rect = area.getVisibleRect();
      for (y in rect.y1...rect.y2)
        {
          var runStart = -1;
          for (x in rect.x1...rect.x2)
            {
              var isVisibleTile = (cache[x][y] != Const.TILE_HIDDEN);
              if (isVisibleTile)
                {
                  if (runStart < 0)
                    runStart = x;
                  continue;
                }
              if (runStart < 0)
                continue;
              fillVisibilityRun(maskCtx, runStart, x, y);
              runStart = -1;
            }
          if (runStart >= 0)
            fillVisibilityRun(maskCtx, runStart, rect.x2, y);
        }
    }

// fill one continuous row run in screen-space visibility mask
  function fillVisibilityRun(maskCtx: CanvasRenderingContext2D,
      x1: Int, x2: Int, y: Int)
    {
      var sx = (x1 - scene.cameraTileX1) * Const.TILE_SIZE - scene.cameraSubX;
      var sy = (y - scene.cameraTileY1) * Const.TILE_SIZE - scene.cameraSubY;
      var sw = (x2 - x1) * Const.TILE_SIZE;
      maskCtx.fillRect(sx, sy, sw, Const.TILE_SIZE);
    }

// draw composed and masked atmosphere to world context
  function drawComposed(ctx: CanvasRenderingContext2D)
    {
      ctx.drawImage(composeMap,
        scene.cameraSubX, scene.cameraSubY);
    }

// apply base atmosphere darkness to unseen tiles
  function fillUnseenBase(area: AreaGame,
      cache: Array<Array<Int>>, ctx: CanvasRenderingContext2D)
    {
      ctx.save();
      ctx.fillStyle = 'rgba(8, 12, 18, ' + UndergroundLab.ATMOS_BASE_ALPHA + ')';

      var rect = area.getVisibleRect();
      for (y in rect.y1...rect.y2)
        {
          var runStart = -1;
          for (x in rect.x1...rect.x2)
            {
              var isHiddenTile = (cache[x][y] == Const.TILE_HIDDEN);
              if (isHiddenTile)
                {
                  if (runStart < 0)
                    runStart = x;
                  continue;
                }
              if (runStart < 0)
                continue;
              fillUnseenRun(ctx, runStart, x, y);
              runStart = -1;
            }
          if (runStart >= 0)
            fillUnseenRun(ctx, runStart, rect.x2, y);
        }
      ctx.restore();
    }

// fill one continuous unseen row run with base atmosphere darkness
  function fillUnseenRun(ctx: CanvasRenderingContext2D,
      x1: Int, x2: Int, y: Int)
    {
      var sx = (x1 - scene.cameraTileX1) * Const.TILE_SIZE - scene.cameraSubX;
      var sy = (y - scene.cameraTileY1) * Const.TILE_SIZE - scene.cameraSubY;
      var sw = (x2 - x1) * Const.TILE_SIZE;
      ctx.fillRect(sx, sy, sw, Const.TILE_SIZE);
    }

// fill base darkness and vignette for static atmosphere map
  function fillDarkBase(mapCtx: CanvasRenderingContext2D,
      mapWidth: Int, mapHeight: Int)
    {
      mapCtx.fillStyle = 'rgba(8, 12, 18, ' + UndergroundLab.ATMOS_BASE_ALPHA + ')';
      mapCtx.fillRect(0, 0, mapWidth, mapHeight);

      var cx = mapWidth / 2;
      var cy = mapHeight / 2;
      var radius = Math.max(mapWidth, mapHeight) * 0.78;
      var vignette = mapCtx.createRadialGradient(cx, cy, radius * 0.18,
        cx, cy, radius);
      vignette.addColorStop(0, 'rgba(0, 0, 0, 0)');
      vignette.addColorStop(1,
        'rgba(0, 0, 0, ' + UndergroundLab.ATMOS_VIGNETTE_ALPHA + ')');
      mapCtx.fillStyle = vignette;
      mapCtx.fillRect(0, 0, mapWidth, mapHeight);
    }

// paint one static atmosphere light into dark map and glow tint layers
  function paintStaticLight(mapCtx: CanvasRenderingContext2D,
      stamp: _AreaLightStamp)
    {
      var cx = toMapX(stamp.x);
      var cy = toMapY(stamp.y);
      var radius = stamp.radiusTiles * ATMOS_LIGHTMAP_TILE_SIZE;
      var cutAlpha = Const.round2(stamp.intensity);
      mapCtx.save();
      mapCtx.globalCompositeOperation = 'destination-out';
      var cutout = mapCtx.createRadialGradient(cx, cy, 0, cx, cy, radius);
      cutout.addColorStop(0, 'rgba(0, 0, 0, ' + cutAlpha + ')');
      cutout.addColorStop(0.86,
        'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.68) + ')');
      cutout.addColorStop(0.96,
        'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.12) + ')');
      cutout.addColorStop(1, 'rgba(0, 0, 0, 0)');
      mapCtx.fillStyle = cutout;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius, 0, Math.PI * 2, false);
      mapCtx.fill();
      mapCtx.restore();

      mapCtx.save();
      var glow = mapCtx.createRadialGradient(cx, cy, 0, cx, cy, radius * 1.08);
      var glowAlpha = Const.round2(stamp.intensity * 0.38);
      glow.addColorStop(0, 'rgba(' + stamp.tintR + ', ' + stamp.tintG + ', ' +
        stamp.tintB + ', ' + glowAlpha + ')');
      glow.addColorStop(0.78, 'rgba(' + stamp.tintR + ', ' + stamp.tintG + ', ' +
        stamp.tintB + ', ' + Const.round2(glowAlpha * 0.48) + ')');
      glow.addColorStop(0.95, 'rgba(' + stamp.tintR + ', ' + stamp.tintG + ', ' +
        stamp.tintB + ', ' + Const.round2(glowAlpha * 0.06) + ')');
      glow.addColorStop(1, 'rgba(' + stamp.tintR + ', ' + stamp.tintG + ', ' +
        stamp.tintB + ', 0)');
      mapCtx.fillStyle = glow;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius * 1.08, 0, Math.PI * 2, false);
      mapCtx.fill();
      mapCtx.restore();
    }

// paint one transient pulse light on the dynamic map
  function paintDynamicLight(mapCtx: CanvasRenderingContext2D,
      light: _TransientAtmosphereLight, nowTS: Float)
    {
      var duration = light.endTS - light.startTS;
      if (duration <= 0)
        return;
      var lifeDT = (nowTS - light.startTS) / duration;
      if (lifeDT < 0)
        lifeDT = 0;
      else if (lifeDT > 1)
        lifeDT = 1;
      var intensity = light.intensity * (1 - lifeDT);
      if (intensity <= 0)
        return;

      var cx = toMapX(light.x);
      var cy = toMapY(light.y);
      var radius = light.radiusTiles * ATMOS_LIGHTMAP_TILE_SIZE *
        (0.82 + 0.28 * lifeDT);
      var alpha = Const.round2(intensity * 0.95);
      var glow = mapCtx.createRadialGradient(cx, cy, 0, cx, cy, radius);
      glow.addColorStop(0, 'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + alpha + ')');
      glow.addColorStop(0.72,
        'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + Const.round2(alpha * 0.52) + ')');
      glow.addColorStop(0.93,
        'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + Const.round2(alpha * 0.07) + ')');
      glow.addColorStop(1, 'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', 0)');
      mapCtx.fillStyle = glow;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius, 0, Math.PI * 2, false);
      mapCtx.fill();
    }

// convert tile coordinate to atmosphere map x
  inline function toMapX(tileX: Float): Float
    {
      return tileX * ATMOS_LIGHTMAP_TILE_SIZE;
    }

// convert tile coordinate to atmosphere map y
  inline function toMapY(tileY: Float): Float
    {
      return tileY * ATMOS_LIGHTMAP_TILE_SIZE;
    }
}

private typedef _AtmosphereDecorObjGroup = {
  var layerID: Int;
  var x1: Int;
  var y1: Int;
  var x2: Int;
  var y2: Int;
  var minIconRow: Int;
  var minIconCol: Int;
}

private typedef _TransientAtmosphereLight = {
  var x: Float;
  var y: Float;
  var radiusTiles: Float;
  var intensity: Float;
  var tintR: Int;
  var tintG: Int;
  var tintB: Int;
  var startTS: Float;
  var endTS: Float;
}

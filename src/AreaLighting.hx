// area atmosphere lighting orchestration and light-stamp building

import haxe.Timer;
import haxe.ds.IntMap;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Image;
import ai.AI;
import game.AreaGame;
import game.Game;
import objects.mission.CloneVat;
import particles.Particle;
import particles._ParticleLightPulse;
import tiles.UndergroundLab;
import tiles.UndergroundLab._DecorBlock;

class AreaLighting
{
// atmosphere lightmap pixels per world tile
  static var ATMOS_LIGHTMAP_TILE_SIZE = 16;
// minimum interval between dynamic lightmap rebuilds in milliseconds
  static var ATMOS_DYNAMIC_REBUILD_MS = 25;
// cap for simultaneously tracked transient particle lights
  static var ATMOS_MAX_TRANSIENT_LIGHTS = 14;
// chance that one generated layout light source is broken
  static var LAYOUT_LIGHT_BROKEN_CHANCE_PERCENT = 10;
// spacing in tiles between corridor light anchors
  static var LAYOUT_LIGHT_CORRIDOR_SPACING = 4;
// minimum corridor run span required before placing lights
  static var LAYOUT_LIGHT_CORRIDOR_MIN_RUN_SPAN = 3;
// radius for the soft outer layout-light pass
  static var LAYOUT_LIGHT_RADIUS_OUTER = 2.5;
// radius for the sharper inner layout-light pass
  static var LAYOUT_LIGHT_RADIUS_INNER = 1.2;
// cutout intensity used for the outer layout-light pass (higher = brighter and broader-feeling outer fill)
  static var LAYOUT_LIGHT_INTENSITY_OUTER = 0.62;
// cutout intensity used for the inner layout-light pass (higher = brighter and more pronounced inner core)
  static var LAYOUT_LIGHT_INTENSITY_INNER = 0.84;
// saturation multiplier applied to inner pass tint color
  static var LAYOUT_LIGHT_INNER_SATURATION_BOOST = 1.35;
// gate for enabling the temporary outer layout-light pass
  static var LAYOUT_LIGHT_ENABLE_OUTER_PASS = true;
// falloff ID for the current smooth radial profile
  static var FALL_OFF_PROFILE_SMOOTH_CURRENT = 'smooth-current';
// falloff ID for the legacy sharp radial profile
  static var FALL_OFF_PROFILE_SHARP_LEGACY = 'sharp-legacy';
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
// max number of layout emitters that can project one object shadow
  static var PROJECTED_SHADOW_MAX_EMITTERS = 4;
// max emitter distance in tiles to affect one projected shadow
  static var PROJECTED_SHADOW_MAX_DISTANCE_TILES = 4.0;
// base projected shadow alpha before per-emitter falloff (higher = darker projected shadows overall)
  static var PROJECTED_SHADOW_BASE_ALPHA = 0.40;
// small caster max footprint (in tiles) that uses short shadow extension
  static var PROJECTED_SHADOW_SMALL_OBJECT_MAX_TILES = 2;
// short shadow extension length in tiles for small casters
  static var PROJECTED_SHADOW_LENGTH_SMALL_TILES = 0.5;
// long shadow extension length in tiles for larger casters
  static var PROJECTED_SHADOW_LENGTH_LARGE_TILES = 1.0;
// alpha threshold for considering source sprite pixel as solid
  static var PROJECTED_SHADOW_MASK_ALPHA_THRESHOLD = 10;
// sampling step in pixels for projected shadow mask extraction
  static var PROJECTED_SHADOW_MASK_SAMPLE_STEP_PX = 1;
// number of segments used to approximate semicircle shadow cap
  static var PROJECTED_SHADOW_SEMICIRCLE_SEGMENTS = 12;
// marker radius in tiles for light source debug rendering
  static var DEBUG_LIGHT_MARKER_RADIUS_TILES = 0.11;
// marker stroke width in tile fractions for debug rendering
  static var DEBUG_LIGHT_MARKER_STROKE_WIDTH_TILES = 0.03;
// marker fill alpha used for light source debug rendering
  static var DEBUG_LIGHT_MARKER_FILL_ALPHA = 0.28;
// marker ring alpha used for light source debug rendering
  static var DEBUG_LIGHT_MARKER_RING_ALPHA = 0.95;

  var scene: GameScene;
  var game: Game;
  var staticMap: CanvasElement;
  var projectedShadowUnderMap: CanvasElement;
  var dynamicMap: CanvasElement;
  var aiShadowMap: CanvasElement;
  var composeMap: CanvasElement;
  var visMaskMap: CanvasElement;
  var shadowWorkMap: CanvasElement;
  var projectedShadowMaskByKey: Map<String, _ProjectedShadowMask>;
  var visMaskDirty: Bool;
  var visMaskAreaID: Int;
  var visMaskCameraX: Int;
  var visMaskCameraY: Int;
  var visMaskSubX: Int;
  var visMaskSubY: Int;
  var visMaskScreenW: Int;
  var visMaskScreenH: Int;
  var mapAreaID: Int;
  var staticDirty: Bool;
  var dynamicDirty: Bool;
  var aiShadowDirty: Bool;
  var dynamicRebuildTS: Float;
  var aiShadowRebuildTS: Float;
  var aiShadowStateKey: String;
  var transientAtmosphereLights: Array<_TransientAtmosphereLight>;
  var areaLightStampsByAreaID: IntMap<Array<_AreaLightStamp>>;

// create area lighting service for one scene
  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      staticMap = null;
      projectedShadowUnderMap = null;
      dynamicMap = null;
      aiShadowMap = null;
      composeMap = null;
      visMaskMap = null;
      shadowWorkMap = null;
      projectedShadowMaskByKey = new Map();
      visMaskDirty = true;
      visMaskAreaID = -1;
      visMaskCameraX = -1;
      visMaskCameraY = -1;
      visMaskSubX = -1;
      visMaskSubY = -1;
      visMaskScreenW = -1;
      visMaskScreenH = -1;
      mapAreaID = -1;
      staticDirty = true;
      dynamicDirty = true;
      aiShadowDirty = true;
      dynamicRebuildTS = 0;
      aiShadowRebuildTS = 0;
      aiShadowStateKey = '';
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

      syncAreaState(area);

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

// draw static projected shadows below decorations and sprites
  public function drawStaticUnderSpriteShadows(ctx: CanvasRenderingContext2D,
      cache: Array<Array<Int>>)
    {
      var area = game.area;
      if (!hasLighting(area))
        return;

      syncAreaState(area);
      ensureMaps(area);
      if (staticDirty)
        rebuildStaticMap(area);

      drawMapsMaskedByVis(ctx, area, cache,
        projectedShadowUnderMap);
    }

// draw dynamic ai shadows above decorations and below sprites
  public function drawDynamicUnderSpriteShadows(ctx: CanvasRenderingContext2D,
      cache: Array<Array<Int>>)
    {
      var area = game.area;
      if (!hasLighting(area))
        return;

      syncAreaState(area);
      ensureMaps(area);

      var stateKey = buildAIShadowStateKey(area);
      if (stateKey != aiShadowStateKey)
        aiShadowDirty = true;

      var nowTS = Timer.stamp() * 1000;
      if (aiShadowDirty &&
          nowTS - aiShadowRebuildTS >= ATMOS_DYNAMIC_REBUILD_MS)
        {
          rebuildAIShadowMap(area, nowTS);
          aiShadowStateKey = stateKey;
        }

      drawMapsMaskedByVis(ctx, area, cache,
        aiShadowMap);
    }

// draw bright source markers for all active light emitters
  public function drawDebugLightMarkers(ctx: CanvasRenderingContext2D)
    {
      if (!game.player.vars.debugLightsEnabled)
        return;

      var area = game.area;
      if (!hasLighting(area))
        return;

      syncAreaState(area);
      var markers = collectDebugLightMarkers(area);
      if (markers.length <= 0)
        return;

      var rect = area.getVisibleRect();
      var radius = DEBUG_LIGHT_MARKER_RADIUS_TILES * Const.TILE_SIZE;
      var strokeWidth = DEBUG_LIGHT_MARKER_STROKE_WIDTH_TILES * Const.TILE_SIZE;
      if (strokeWidth < 1)
        strokeWidth = 1;

      ctx.save();
      ctx.globalCompositeOperation = 'source-over';
      ctx.lineWidth = strokeWidth;
      for (marker in markers)
        {
          var tileX = Std.int(Math.floor(marker.x));
          var tileY = Std.int(Math.floor(marker.y));
          if (tileX < rect.x1 ||
              tileY < rect.y1 ||
              tileX >= rect.x2 ||
              tileY >= rect.y2)
            continue;

          var sx = (marker.x - scene.cameraTileX1) * Const.TILE_SIZE;
          var sy = (marker.y - scene.cameraTileY1) * Const.TILE_SIZE;
          var rgb = (marker.castsShadows ? '0, 0, 0' : '255, 255, 255');
          ctx.fillStyle = 'rgba(' + rgb + ', ' + DEBUG_LIGHT_MARKER_FILL_ALPHA + ')';
          ctx.strokeStyle = 'rgba(' + rgb + ', ' + DEBUG_LIGHT_MARKER_RING_ALPHA + ')';
          ctx.beginPath();
          ctx.arc(sx, sy, radius, 0, Math.PI * 2, false);
          ctx.fill();
          ctx.stroke();
        }
      ctx.restore();
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

// invalidate cached visibility mask after visibility cache update
  public function onVisCacheUpdated()
    {
      visMaskDirty = true;
    }

// check if transient pulse lights are active
  public inline function hasActiveTransientLights(): Bool
    {
      return transientAtmosphereLights.length > 0;
    }

// reset area lighting cache for a freshly entered area
  public function onAreaEntered()
    {
      if (game != null &&
          game.area != null)
        areaLightStampsByAreaID.remove(game.area.id);
      invalidateCurrentView();
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
      aiShadowDirty = true;
      aiShadowRebuildTS = 0;
      aiShadowStateKey = '';
      visMaskDirty = true;
      visMaskAreaID = -1;
      transientAtmosphereLights = [];
    }

// sync internal caches when active area changed
  function syncAreaState(area: AreaGame)
    {
      if (mapAreaID == area.id)
        return;

      mapAreaID = area.id;
      staticDirty = true;
      dynamicDirty = true;
      aiShadowDirty = true;
      aiShadowRebuildTS = 0;
      aiShadowStateKey = '';
      visMaskDirty = true;
      visMaskAreaID = -1;
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

// collect deduplicated light source marker centers for debug overlay
  function collectDebugLightMarkers(
      area: AreaGame): Array<_DebugLightMarker>
    {
      var markers: Array<_DebugLightMarker> = [];
      var markerByPos: Map<String, _DebugLightMarker> = new Map();
      for (stamp in getAreaLightStamps(area))
        {
          var key = stamp.x + ':' + stamp.y;
          var marker = markerByPos.get(key);
          var castsShadows = isProjectedShadowEmitterStamp(stamp);
          if (marker == null)
            {
              marker = {
                x: stamp.x,
                y: stamp.y,
                castsShadows: castsShadows,
              };
              markerByPos.set(key, marker);
              markers.push(marker);
            }
          else if (castsShadows)
            marker.castsShadows = true;
        }

      for (pulse in transientAtmosphereLights)
        {
          var key = pulse.x + ':' + pulse.y;
          if (markerByPos.exists(key))
            continue;
          var marker: _DebugLightMarker = {
            x: pulse.x,
            y: pulse.y,
            castsShadows: false,
          };
          markerByPos.set(key, marker);
          markers.push(marker);
        }
      return markers;
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
      addRoomAndCorridorLayoutLights(area, stamps, undergroundLab);
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
                if (!undergroundLab.isNearTopWallDecorationWallLayerID(
                    decoration.layerID) ||
                    decoration.icon == null)
                  continue;
                var blockInfo = getNearTopWallDecorationBlock(undergroundLab,
                  decoration.layerID, decoration.icon.row, decoration.icon.col);
                if (blockInfo == null ||
                    blockInfo.meta.light == null)
                  continue;
                pushLightStamp(area, stamps, x + 0.5, y + 1.5,
                  blockInfo.meta.light, 'near-top-wall');
              }
          }
    }

// get near-top wall block metadata by layer and wall icon coordinates
  function getNearTopWallDecorationBlock(undergroundLab: UndergroundLab,
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
  function collectDecorationObjGroups(area: AreaGame,
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

      var groups: Array<_AtmosphereDecorObjGroup> = [];
      for (group in groupsByTag)
        groups.push(group);
      return groups;
    }

// add decoration object light stamps by grouped object placement tags
  function addDecorationObjectLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab)
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
          pushLightStamp(area, stamps, centerX, centerY,
            blockInfo.meta.light, blockInfo.meta.id);
        }
    }

// get decoration object block info from grouped placement signature
  function getDecorationObjBlock(undergroundLab: UndergroundLab,
      group: _AtmosphereDecorObjGroup, requireLight: Bool): _DecorBlock
    {
      var width = group.x2 - group.x1 + 1;
      var height = group.y2 - group.y1 + 1;
      for (blockInfo in UndergroundLab.DECORATION_OBJ_META)
        {
          if (blockInfo.meta.imageKey == null)
            continue;
          if (requireLight &&
              blockInfo.meta.light == null)
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

// add one center light per clone vat group
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

          var centerX = (x1 + x2 + 1) / 2.0;
          var centerY = (y1 + y2 + 1) / 2.0;
          pushLightStamp(area, stamps, centerX, centerY,
            UndergroundLab.ATMOS_LIGHT_LARGE_GREEN, 'clone-vat');
        }
    }

// add role-based room and corridor lights with two-pass profiles
  function addRoomAndCorridorLayoutLights(area: AreaGame,
      stamps: Array<_AreaLightStamp>, undergroundLab: UndergroundLab)
    {
      var sources: Array<_LayoutLightSource> = [];
      addRoomLayoutSources(area, sources);
      addCorridorLayoutSources(area, sources, undergroundLab);
      sources = filterAdjacentLayoutSources(sources);
      for (source in sources)
        {
          if (Std.random(100) < LAYOUT_LIGHT_BROKEN_CHANCE_PERCENT)
            continue;
          if (LAYOUT_LIGHT_ENABLE_OUTER_PASS)
            pushCustomLightStamp(area, stamps, source.x, source.y,
              LAYOUT_LIGHT_RADIUS_OUTER,
              LAYOUT_LIGHT_INTENSITY_OUTER,
              source.tintR,
              source.tintG,
              source.tintB,
              source.kind + '-outer',
              FALL_OFF_PROFILE_SMOOTH_CURRENT,
              1.0,
              source.sourceGroupID);
          pushCustomLightStamp(area, stamps, source.x, source.y,
            LAYOUT_LIGHT_RADIUS_INNER,
            LAYOUT_LIGHT_INTENSITY_INNER,
            source.tintR,
            source.tintG,
            source.tintB,
            source.kind + '-inner',
            FALL_OFF_PROFILE_SHARP_LEGACY,
            LAYOUT_LIGHT_INNER_SATURATION_BOOST,
            source.sourceGroupID);
        }
    }

// filter out nearby layout sources in the same kind (including diagonals)
  function filterAdjacentLayoutSources(
      sources: Array<_LayoutLightSource>): Array<_LayoutLightSource>
    {
      if (sources.length <= 1)
        return sources;

      var sortedSources = sources.copy();
      sortedSources.sort((a, b) -> {
        if (a.kind != b.kind)
          return (a.kind < b.kind ? -1 : 1);
        if (a.y != b.y)
          return a.y - b.y;
        return a.x - b.x;
      });

      var filtered: Array<_LayoutLightSource> = [];
      for (source in sortedSources)
        {
          var keep = true;
          for (existing in filtered)
            {
              if (existing.kind != source.kind)
                continue;
              var dx = source.x - existing.x;
              if (dx < 0)
                dx = -dx;
              var dy = source.y - existing.y;
              if (dy < 0)
                dy = -dy;
              if (dx <= 1 &&
                  dy <= 1)
                {
                  keep = false;
                  break;
                }
            }
          if (keep)
            filtered.push(source);
        }
      return filtered;
    }

// add evenly spaced room light sources based on room dimensions
  function addRoomLayoutSources(area: AreaGame, sources: Array<_LayoutLightSource>)
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
  function addCorridorLayoutSources(area: AreaGame,
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
  function buildRoomMask(area: AreaGame): Array<Array<Bool>>
    {
      var mask: Array<Array<Bool>> = [];
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

// build corridor mask from walkable non-room underground tiles
  function buildCorridorMask(area: AreaGame, undergroundLab: UndergroundLab,
      roomMask: Array<Array<Bool>>,
      doorMask: Array<Array<Bool>>): Array<Array<Bool>>
    {
      var mask: Array<Array<Bool>> = [];
      for (x in 0...area.width)
        {
          mask[x] = [];
          for (y in 0...area.height)
            {
              var tileID = area.getCellType(x, y);
              mask[x][y] = (!roomMask[x][y] &&
                !doorMask[x][y] &&
                undergroundLab.isWalkable(tileID));
            }
        }
      return mask;
    }

// build boolean mask of door object tiles
  function buildDoorMask(area: AreaGame): Array<Array<Bool>>
    {
      var mask: Array<Array<Bool>> = [];
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
  function buildRoomAxisAnchors(start: Int, size: Int): Array<Int>
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
      var blockAnchors: Array<Int> = [];
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
          var filteredBlockAnchors: Array<Int> = [];
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

      var anchors: Array<Int> = [];
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
  function getRoomAxisAnchorCount(size: Int): Int
    {
      if (size <= 8)
        return 1;
      return Std.int(Math.ceil(size / 8.0));
    }

// build centered run anchors with approximate fixed spacing
  function buildRunAnchors(start: Int, end: Int, spacing: Int): Array<Int>
    {
      var span = end - start;
      if (span <= 0)
        return [];

      var count = Std.int(Math.ceil(span / spacing));
      if (count < 1)
        count = 1;
      var anchors: Array<Int> = [];
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
  function getLayoutRoomRoleLight(role: String): _AtmosphereLightMeta
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
  function getLayoutCorridorLight(): _AtmosphereLightMeta
    {
      return UndergroundLab.ATMOS_LIGHT_LARGE_WHITE;
    }

// append one atmosphere light stamp with short-range deduplication
  function pushLightStamp(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      x: Float, y: Float, light: _AtmosphereLightMeta, kind: String)
    {
      pushCustomLightStamp(area, stamps, x, y,
        light.radiusTiles,
        light.intensity,
        light.tintR,
        light.tintG,
        light.tintB,
        kind);
    }

// append one atmosphere light stamp with optional profile metadata
  function pushCustomLightStamp(area: AreaGame,
      stamps: Array<_AreaLightStamp>,
      x: Float, y: Float,
      radiusTiles: Float, intensity: Float,
      tintR: Int, tintG: Int, tintB: Int,
      kind: String,
      ?falloffProfile: String,
      ?saturationBoost: Float,
      ?sourceGroupID: String)
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
          if (dx * dx + dy * dy < 0.04 &&
              stamp.kind == kind &&
              Math.abs(stamp.radiusTiles - radiusTiles) < 0.04)
            return;
        }

      var stamp: _AreaLightStamp = {
        x: x,
        y: y,
        radiusTiles: radiusTiles,
        intensity: intensity,
        tintR: tintR,
        tintG: tintG,
        tintB: tintB,
        kind: kind,
      };
      if (falloffProfile != null)
        stamp.falloffProfile = falloffProfile;
      if (saturationBoost != null)
        stamp.saturationBoost = saturationBoost;
      if (sourceGroupID != null)
        stamp.sourceGroupID = sourceGroupID;
      stamps.push(stamp);
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
      if (projectedShadowUnderMap == null)
        projectedShadowUnderMap = Browser.document.createCanvasElement();
      if (dynamicMap == null)
        dynamicMap = Browser.document.createCanvasElement();
      if (aiShadowMap == null)
        aiShadowMap = Browser.document.createCanvasElement();
      if (composeMap == null)
        composeMap = Browser.document.createCanvasElement();
      if (visMaskMap == null)
        visMaskMap = Browser.document.createCanvasElement();

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
      if (projectedShadowUnderMap.width != mapWidth ||
          projectedShadowUnderMap.height != mapHeight)
        {
          projectedShadowUnderMap.width = mapWidth;
          projectedShadowUnderMap.height = mapHeight;
          staticDirty = true;
        }
      if (dynamicMap.width != mapWidth ||
          dynamicMap.height != mapHeight)
        {
          dynamicMap.width = mapWidth;
          dynamicMap.height = mapHeight;
          dynamicDirty = true;
        }
      if (aiShadowMap.width != mapWidth ||
          aiShadowMap.height != mapHeight)
        {
          aiShadowMap.width = mapWidth;
          aiShadowMap.height = mapHeight;
          aiShadowDirty = true;
        }
      if (composeMap.width != screenWidth ||
          composeMap.height != screenHeight)
        {
          composeMap.width = screenWidth;
          composeMap.height = screenHeight;
        }
      if (visMaskMap.width != screenWidth ||
          visMaskMap.height != screenHeight)
        {
          visMaskMap.width = screenWidth;
          visMaskMap.height = screenHeight;
          visMaskDirty = true;
        }
    }

// make sure visibility mask exists and matches current camera/visibility state
  function ensureVisMask(area: AreaGame, cache: Array<Array<Int>>)
    {
      var screenW = scene.canvas.width;
      var screenH = scene.canvas.height;
      if (!visMaskDirty &&
          visMaskAreaID == area.id &&
          visMaskCameraX == scene.cameraX &&
          visMaskCameraY == scene.cameraY &&
          visMaskSubX == scene.cameraSubX &&
          visMaskSubY == scene.cameraSubY &&
          visMaskScreenW == screenW &&
          visMaskScreenH == screenH)
        return;

      rebuildVisMask(area, cache);
      visMaskDirty = false;
      visMaskAreaID = area.id;
      visMaskCameraX = scene.cameraX;
      visMaskCameraY = scene.cameraY;
      visMaskSubX = scene.cameraSubX;
      visMaskSubY = scene.cameraSubY;
      visMaskScreenW = screenW;
      visMaskScreenH = screenH;
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
      var hasPendingProjectedShadowAssets = rebuildProjectedShadowUnderMap(area,
        stamps);
      staticDirty = hasPendingProjectedShadowAssets;
    }

// rebuild static projected-shadow map rendered below sprites
  function rebuildProjectedShadowUnderMap(area: AreaGame,
      stamps: Array<_AreaLightStamp>): Bool
    {
      var mapCtx = projectedShadowUnderMap.getContext2d();
      mapCtx.clearRect(0, 0, projectedShadowUnderMap.width,
        projectedShadowUnderMap.height);
      return paintProjectedDecorationShadows(area, mapCtx, stamps);
    }

// rebuild dynamic AI projected shadows from current visible actors
  function rebuildAIShadowMap(area: AreaGame, nowTS: Float)
    {
      var mapCtx = aiShadowMap.getContext2d();
      mapCtx.clearRect(0, 0, aiShadowMap.width, aiShadowMap.height);

      var tileset = scene.images.getTileset(area.typeID);
      if (!Std.isOfType(tileset, UndergroundLab))
        {
          aiShadowDirty = false;
          aiShadowRebuildTS = nowTS;
          return;
        }

      // collect shadow emitter metadata from area light stamps
      var undergroundLab: UndergroundLab = cast tileset;
      var emitters = collectProjectedShadowEmitters(getAreaLightStamps(area));
      if (emitters.length <= 0)
        {
          aiShadowDirty = false;
          aiShadowRebuildTS = nowTS;
          return;
        }

      // collect visible AI shadow casters
      var casters = collectVisibleAIProjectedShadowCasters(area);
      if (casters.length <= 0)
        {
          aiShadowDirty = false;
          aiShadowRebuildTS = nowTS;
          return;
        }

      // for each visible AI caster, find valid shadow mask and nearby emitters to
      var hasPendingAssets = false;
      for (casterInfo in casters)
        {
          var layer = casterInfo.layer;
          if (layer == null ||
              !layer.complete ||
              layer.naturalWidth <= 0)
            {
              hasPendingAssets = true;
              continue;
            }

          // get cached solid-pixel shadow mask points
          var caster = casterInfo.caster;
          var mask = getProjectedShadowMaskForSource(casterInfo.maskKey, layer,
            caster.srcRow, caster.srcCol, caster.blockW, caster.blockH);
          if (mask == null)
            continue;

          // find nearby emitters
          var emitterHits = getNearestLayoutShadowEmitters(area,
            caster, emitters);
          if (emitterHits.length <= 0)
            continue;

          // combine emitter proximity and distance-based falloff for final shadow alpha
          var perEmitterAlpha = PROJECTED_SHADOW_BASE_ALPHA /
            Math.sqrt(emitterHits.length);
          for (hit in emitterHits)
            {
              if (caster.layerID != undergroundLab.nearTopWallFloorLayerID &&
                  isEmitterInsideProjectedShadowCaster(hit.emitter, caster))
                continue;
              var dist = Math.sqrt(hit.distSq);
              var distanceFalloff = 1.0 -
                dist / PROJECTED_SHADOW_MAX_DISTANCE_TILES;
              if (distanceFalloff <= 0)
                continue;
              var alpha = perEmitterAlpha *
                (0.35 + 0.65 * distanceFalloff);
              if (alpha <= 0)
                continue;
              paintProjectedShadowFromEmitter(area, mapCtx,
                caster, mask, hit.emitter, alpha);
            }
        }

      aiShadowDirty = hasPendingAssets;
      aiShadowRebuildTS = nowTS;
    }

// build deterministic state key for visible AI caster set
  function buildAIShadowStateKey(area: AreaGame): String
    {
      var parts: Array<String> = [];
      for (ai in area.getAllAI())
        {
          if (ai.entity == null ||
              !ai.entity.isVisible())
            continue;
          if (game.player.vars.losEnabled &&
              !game.playerArea.sees(ai.x, ai.y))
            continue;
          var sprite = getAIProjectedShadowSpriteSource(ai);
          if (sprite == null)
            continue;
          parts.push(ai.id + ':' + ai.x + ':' + ai.y + ':' +
            sprite.imageKey + ':' + sprite.srcRow + ':' + sprite.srcCol);
        }
      if (parts.length <= 0)
        return '';
      parts.sort((a, b) -> {
        if (a < b)
          return -1;
        if (a > b)
          return 1;
        return 0;
      });
      return parts.join('|');
    }

// collect visible AI casters with sprite atlas source for shadow masks
  function collectVisibleAIProjectedShadowCasters(
      area: AreaGame): Array<_AIShadowCaster>
    {
      var casters: Array<_AIShadowCaster> = [];
      for (ai in area.getAllAI())
        {
          if (ai.entity == null ||
              !ai.entity.isVisible())
            continue;
          if (game.player.vars.losEnabled &&
              !game.playerArea.sees(ai.x, ai.y))
            continue;

          var sprite = getAIProjectedShadowSpriteSource(ai);
          if (sprite == null)
            continue;

          casters.push({
            caster: {
              layerID: -1,
              srcRow: sprite.srcRow,
              srcCol: sprite.srcCol,
              blockW: 1,
              blockH: 1,
              centerX: ai.x + 0.5,
              centerY: ai.y + 0.5,
            },
            layer: sprite.image,
            maskKey: 'ai:' + sprite.imageKey + ':' + sprite.srcRow + ':' +
              sprite.srcCol + ':1:1',
          });
        }
      return casters;
    }

// resolve current sprite atlas source for one AI shadow caster
  function getAIProjectedShadowSpriteSource(ai: AI): _AIShadowSpriteSource
    {
      if (ai.type == 'dog')
        return {
          imageKey: 'entities',
          image: scene.images.entities,
          srcRow: Const.ROW_PARASITE,
          srcCol: 1,
        };
      if (ai.type == 'choirOfDiscord')
        return {
          imageKey: 'entities',
          image: scene.images.entities,
          srcRow: Const.ROW_PARASITE,
          srcCol: Const.FRAME_CHOIR,
        };
      if (ai.tileAtlasX < 0 ||
          ai.tileAtlasY < 0)
        return null;

      var useMaleAtlas = (ai.isMale ||
        (ai.entity != null &&
         ai.entity.isMaleAtlas));
      return {
        imageKey: (useMaleAtlas ? 'male' : 'female'),
        image: (useMaleAtlas ? scene.images.male : scene.images.female),
        srcRow: ai.tileAtlasY,
        srcCol: ai.tileAtlasX,
      };
    }

// paint projected decoration shadows using nearby logical layout emitters
  function paintProjectedDecorationShadows(area: AreaGame,
      mapCtx: CanvasRenderingContext2D,
      stamps: Array<_AreaLightStamp>): Bool
    {
      var tileset = scene.images.getTileset(area.typeID);
      if (!Std.isOfType(tileset, UndergroundLab))
        return false;
      var undergroundLab: UndergroundLab = cast tileset;
      var emitters = collectProjectedShadowEmitters(stamps);
      if (emitters.length <= 0)
        return false;
      var casters = collectDecorationProjectedShadowCasters(area, undergroundLab);
      if (casters.length <= 0)
        return false;

      var hasPendingAssets = false;

      for (caster in casters)
        {
          var layer = undergroundLab.floorDecorationLayers[caster.layerID];
          if (layer == null ||
              !layer.complete ||
              layer.naturalWidth <= 0)
            {
              hasPendingAssets = true;
              continue;
            }
          var mask = getProjectedShadowMask(caster, layer);
          if (mask == null)
            continue;
          var emitterHits = getNearestLayoutShadowEmitters(area,
            caster, emitters);
          if (emitterHits.length <= 0)
            continue;
          var perEmitterAlpha = PROJECTED_SHADOW_BASE_ALPHA /
            Math.sqrt(emitterHits.length);
          for (hit in emitterHits)
            {
              var dist = Math.sqrt(hit.distSq);
              var distanceFalloff = 1.0 -
                dist / PROJECTED_SHADOW_MAX_DISTANCE_TILES;
              if (distanceFalloff <= 0)
                continue;
              var alpha = perEmitterAlpha *
                (0.35 + 0.65 * distanceFalloff);
              if (alpha <= 0)
                continue;
              paintProjectedShadowFromEmitter(area, mapCtx,
                caster, mask, hit.emitter, alpha);
            }
        }
      return hasPendingAssets;
    }

// check whether projected-shadow emitter point lies inside caster footprint bounds
  function isEmitterInsideProjectedShadowCaster(emitter: _LayoutShadowEmitter,
      caster: _ProjectedShadowCaster): Bool
    {
      var x1 = caster.centerX - caster.blockW / 2.0;
      var y1 = caster.centerY - caster.blockH / 2.0;
      var x2 = x1 + caster.blockW;
      var y2 = y1 + caster.blockH;
      return (emitter.x >= x1 &&
        emitter.y >= y1 &&
        emitter.x <= x2 &&
        emitter.y <= y2);
    }

// collect unique projected-shadow emitters from selected light stamp kinds
  function collectProjectedShadowEmitters(
      stamps: Array<_AreaLightStamp>): Array<_LayoutShadowEmitter>
    {
      var emitters: Array<_LayoutShadowEmitter> = [];
      var byPos = new Map<String, Bool>();
      for (stamp in stamps)
        {
          if (!isProjectedShadowEmitterStamp(stamp))
            continue;
          var key = stamp.x + ':' + stamp.y;
          if (byPos[key])
            continue;
          byPos[key] = true;
          emitters.push({
            x: stamp.x,
            y: stamp.y,
          });
        }
      return emitters;
    }

// check whether one light stamp acts as projected-shadow emitter
  function isProjectedShadowEmitterStamp(stamp: _AreaLightStamp): Bool
    {
      return (stamp.kind.indexOf('layout-room') == 0 ||
        stamp.kind.indexOf('layout-corridor') == 0 ||
        stamp.kind == 'clone-vat');
    }

// collect projected-shadow casters from grouped decoration object blocks
  function collectDecorationProjectedShadowCasters(area: AreaGame,
      undergroundLab: UndergroundLab): Array<_ProjectedShadowCaster>
    {
      var casters: Array<_ProjectedShadowCaster> = [];
      var groups = collectDecorationObjGroups(area, undergroundLab);
      for (group in groups)
        {
          var blockInfo = getDecorationObjBlock(undergroundLab, group, false);
          if (blockInfo == null)
            continue;
          casters.push({
            layerID: group.layerID,
            srcRow: blockInfo.block.row,
            srcCol: blockInfo.block.col,
            blockW: blockInfo.block.width,
            blockH: blockInfo.block.height,
            centerX: (group.x1 + group.x2 + 1) / 2.0,
            centerY: (group.y1 + group.y2 + 1) / 2.0,
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
                casters.push({
                  layerID: undergroundLab.getNearTopDecorationLayerID(
                    blockInfo, 1),
                  srcRow: blockInfo.block.row,
                  srcCol: blockInfo.block.col,
                  blockW: blockInfo.block.width,
                  blockH: blockInfo.block.height,
                  centerX: x + blockInfo.block.width / 2.0,
                  centerY: y + blockInfo.block.height / 2.0,
                });
              }
          }
      return casters;
    }

// get nearest layout emitters that can cast projected shadows for one caster
  function getNearestLayoutShadowEmitters(area: AreaGame,
      caster: _ProjectedShadowCaster,
      emitters: Array<_LayoutShadowEmitter>): Array<_LayoutShadowEmitterHit>
    {
      var maxDistSq = PROJECTED_SHADOW_MAX_DISTANCE_TILES *
        PROJECTED_SHADOW_MAX_DISTANCE_TILES;
      var hits: Array<_LayoutShadowEmitterHit> = [];
      for (emitter in emitters)
        {
          var dx = caster.centerX - emitter.x;
          var dy = caster.centerY - emitter.y;
          var distSq = dx * dx + dy * dy;
          if (distSq <= 0.0001 ||
              distSq > maxDistSq)
            continue;
          if (!hasProjectedShadowEmitterLineOfSight(area,
              emitter.x, emitter.y, caster.centerX, caster.centerY))
            continue;
          hits.push({
            emitter: emitter,
            distSq: distSq,
          });
        }
      hits.sort((a, b) -> {
        if (a.distSq < b.distSq)
          return -1;
        if (a.distSq > b.distSq)
          return 1;
        return 0;
      });
      if (hits.length > PROJECTED_SHADOW_MAX_EMITTERS)
        hits = hits.slice(0, PROJECTED_SHADOW_MAX_EMITTERS);
      return hits;
    }

// check line of sight from emitter to caster center for shadow projection
  function hasProjectedShadowEmitterLineOfSight(area: AreaGame,
      emitterX: Float, emitterY: Float,
      targetX: Float, targetY: Float): Bool
    {
      var startX = toMapX(emitterX);
      var startY = toMapY(emitterY);
      var endX = toMapX(targetX);
      var endY = toMapY(targetY);
      var dx = endX - startX;
      var dy = endY - startY;
      var lenPx = Math.sqrt(dx * dx + dy * dy);
      if (lenPx <= 0.0001)
        return true;
      var dirX = dx / lenPx;
      var dirY = dy / lenPx;
      var stepPx = 1.0;
      var distPx = stepPx;
      while (distPx < lenPx - stepPx)
        {
          var sampleX = startX + dirX * distPx;
          var sampleY = startY + dirY * distPx;
          var tileX = Std.int(Math.floor(sampleX / ATMOS_LIGHTMAP_TILE_SIZE));
          var tileY = Std.int(Math.floor(sampleY / ATMOS_LIGHTMAP_TILE_SIZE));
          if (tileX < 0 ||
              tileY < 0 ||
              tileX >= area.width ||
              tileY >= area.height)
            return false;
          if (!canProjectedShadowPassTile(area, tileX, tileY))
            return false;
          distPx += stepPx;
        }
      return true;
    }

// check whether projected-shadow light can pass through this tile
  function canProjectedShadowPassTile(area: AreaGame,
      tileX: Int, tileY: Int): Bool
    {
      return area.canSeeThrough(tileX, tileY);
    }

// get cached solid-pixel shadow mask points for one decoration block sprite
  function getProjectedShadowMask(caster: _ProjectedShadowCaster,
      layer: Image): _ProjectedShadowMask
    {
      var key = caster.layerID + ':' + caster.srcRow + ':' + caster.srcCol +
        ':' + caster.blockW + ':' + caster.blockH;
      return getProjectedShadowMaskForSource(key, layer,
        caster.srcRow, caster.srcCol, caster.blockW, caster.blockH);
    }

// get cached solid-pixel shadow mask points for one source sprite region
  function getProjectedShadowMaskForSource(key: String,
      layer: Image, srcRow: Int, srcCol: Int,
      blockW: Int, blockH: Int): _ProjectedShadowMask
    {
      var cachedMask = projectedShadowMaskByKey.get(key);
      if (cachedMask != null)
        return cachedMask;

      var srcX = srcCol * Const.TILE_SIZE_CLEAN;
      var srcY = srcRow * Const.TILE_SIZE_CLEAN;
      var srcW = blockW * Const.TILE_SIZE_CLEAN;
      var srcH = blockH * Const.TILE_SIZE_CLEAN;
      var maskW = blockW * ATMOS_LIGHTMAP_TILE_SIZE;
      var maskH = blockH * ATMOS_LIGHTMAP_TILE_SIZE;
      if (maskW <= 0 ||
          maskH <= 0)
        return null;

      var workMap = getShadowWorkMap(maskW, maskH);
      var workCtx = workMap.getContext2d();
      workCtx.clearRect(0, 0, maskW, maskH);
      workCtx.drawImage(layer,
        srcX, srcY, srcW, srcH,
        0, 0, maskW, maskH);

      var data = workCtx.getImageData(0, 0, maskW, maskH).data;
      var points: Array<_ProjectedShadowMaskPoint> = [];
      var halfW = maskW / 2.0;
      var halfH = maskH / 2.0;
      var sampleStep = PROJECTED_SHADOW_MASK_SAMPLE_STEP_PX;
      if (sampleStep < 1)
        sampleStep = 1;

      // iterate mask pixels and collect center points of solid pixels above alpha threshold
      var py = 0;
      while (py < maskH)
        {
          var rowOffset = py * maskW * 4;
          var px = 0;
          while (px < maskW)
            {
              var alphaIndex = rowOffset + px * 4 + 3;
              if (data[alphaIndex] >= PROJECTED_SHADOW_MASK_ALPHA_THRESHOLD)
                points.push({
                  x: px + 0.5 - halfW,
                  y: py + 0.5 - halfH,
                });
              px += sampleStep;
            }
          py += sampleStep;
        }
      if (points.length <= 0)
        return null;

      // cache mask points by source key for reuse across frames and casters with same source
      var builtMask: _ProjectedShadowMask = {
        points: points,
      };
      projectedShadowMaskByKey.set(key, builtMask);
      return builtMask;
    }

// get silhouette edge pair of solid pixels from one emitter perspective
  function getProjectedShadowEdgePair(caster: _ProjectedShadowCaster,
      mask: _ProjectedShadowMask,
      lightX: Float, lightY: Float): _ProjectedShadowEdgePair
    {
      var centerX = toMapX(caster.centerX);
      var centerY = toMapY(caster.centerY);
      var axisX = centerX - lightX;
      var axisY = centerY - lightY;
      var axisLen = Math.sqrt(axisX * axisX + axisY * axisY);
      if (axisLen <= 0.0001)
        return null;
      axisX /= axisLen;
      axisY /= axisLen;
      var perpX = -axisY;
      var perpY = axisX;

      var minPoint: _ProjectedShadowMaskPoint = null;
      var maxPoint: _ProjectedShadowMaskPoint = null;

      // pass 0 keeps only positive-depth points for cleaner silhouette; pass 1 falls back to all points to avoid shadow dropouts
      for (pass in 0...2)
        {
          var bestMinSide = 1e20;
          var bestMaxSide = -1e20;
          var bestMinDepth = -1e20;
          var bestMaxDepth = -1e20;
          minPoint = null;
          maxPoint = null;

          for (point in mask.points)
            {
              var worldX = centerX + point.x;
              var worldY = centerY + point.y;
              var relX = worldX - lightX;
              var relY = worldY - lightY;
              var depth = relX * axisX + relY * axisY;
              if (pass == 0 &&
                  depth <= 0)
                continue;
              var side = relX * perpX + relY * perpY;

              if (minPoint == null ||
                  side < bestMinSide - 0.0001 ||
                  (Math.abs(side - bestMinSide) <= 0.0001 &&
                   depth > bestMinDepth))
                {
                  bestMinSide = side;
                  bestMinDepth = depth;
                  minPoint = {
                    x: worldX,
                    y: worldY,
                  };
                }
              if (maxPoint == null ||
                  side > bestMaxSide + 0.0001 ||
                  (Math.abs(side - bestMaxSide) <= 0.0001 &&
                   depth > bestMaxDepth))
                {
                  bestMaxSide = side;
                  bestMaxDepth = depth;
                  maxPoint = {
                    x: worldX,
                    y: worldY,
                  };
                }
            }
          if (minPoint != null &&
              maxPoint != null)
            break;
        }

      if (minPoint == null ||
          maxPoint == null)
        return null;
      var edgeDX = maxPoint.x - minPoint.x;
      var edgeDY = maxPoint.y - minPoint.y;
      if (edgeDX * edgeDX + edgeDY * edgeDY <= 0.25)
        return null;
      return {
        edge1: minPoint,
        edge2: maxPoint,
      };
    }

// paint one geometric trapezoid shadow with semicircle cap from one emitter
  function paintProjectedShadowFromEmitter(area: AreaGame,
      mapCtx: CanvasRenderingContext2D,
      caster: _ProjectedShadowCaster,
      mask: _ProjectedShadowMask,
      emitter: _LayoutShadowEmitter, alpha: Float)
    {
      var baseAlpha = Const.clampFloat(alpha, 0, 1);
      if (baseAlpha <= 0)
        return;

      var lightX = toMapX(emitter.x);
      var lightY = toMapY(emitter.y);
      var edges = getProjectedShadowEdgePair(caster, mask, lightX, lightY);
      if (edges == null)
        return;

      var edge1 = edges.edge1;
      var edge2 = edges.edge2;
      var ray1X = edge1.x - lightX;
      var ray1Y = edge1.y - lightY;
      var ray1Len = Math.sqrt(ray1X * ray1X + ray1Y * ray1Y);
      var ray2X = edge2.x - lightX;
      var ray2Y = edge2.y - lightY;
      var ray2Len = Math.sqrt(ray2X * ray2X + ray2Y * ray2Y);
      if (ray1Len <= 0.0001 ||
          ray2Len <= 0.0001)
        return;
      ray1X /= ray1Len;
      ray1Y /= ray1Len;
      ray2X /= ray2Len;
      ray2Y /= ray2Len;

      var casterTiles = caster.blockW * caster.blockH;
      var extensionTiles = (casterTiles <= PROJECTED_SHADOW_SMALL_OBJECT_MAX_TILES ?
        PROJECTED_SHADOW_LENGTH_SMALL_TILES :
        PROJECTED_SHADOW_LENGTH_LARGE_TILES);
      var extensionPxMax = extensionTiles * ATMOS_LIGHTMAP_TILE_SIZE;
      var extension1Px = getProjectedShadowWalkableDistancePx(area,
        edge1.x, edge1.y, ray1X, ray1Y, extensionPxMax);
      var extension2Px = getProjectedShadowWalkableDistancePx(area,
        edge2.x, edge2.y, ray2X, ray2Y, extensionPxMax);
      if (extension1Px <= 0 &&
          extension2Px <= 0)
        return;
      var cap1X = edge1.x + ray1X * extension1Px;
      var cap1Y = edge1.y + ray1Y * extension1Px;
      var cap2X = edge2.x + ray2X * extension2Px;
      var cap2Y = edge2.y + ray2Y * extension2Px;

      var chordX = cap2X - cap1X;
      var chordY = cap2Y - cap1Y;
      var chordLen = Math.sqrt(chordX * chordX + chordY * chordY);
      if (chordLen <= 0.0001)
        return;
      var chordDirX = chordX / chordLen;
      var chordDirY = chordY / chordLen;
      var radius = chordLen / 2.0;
      var capCenterX = (cap1X + cap2X) / 2.0;
      var capCenterY = (cap1Y + cap2Y) / 2.0;
      var capNormalX = -chordDirY;
      var capNormalY = chordDirX;
      var toCapX = capCenterX - lightX;
      var toCapY = capCenterY - lightY;
      if (capNormalX * toCapX + capNormalY * toCapY < 0)
        {
          capNormalX = -capNormalX;
          capNormalY = -capNormalY;
        }

      var nearMidX = (edge1.x + edge2.x) / 2.0;
      var nearMidY = (edge1.y + edge2.y) / 2.0;
      var farMidX = capCenterX + capNormalX * radius;
      var farMidY = capCenterY + capNormalY * radius;
      var tailFade = mapCtx.createLinearGradient(nearMidX, nearMidY,
        farMidX, farMidY);
      tailFade.addColorStop(0,
        'rgba(0, 0, 0, ' + Const.round2(baseAlpha) + ')');
      tailFade.addColorStop(0.84,
        'rgba(0, 0, 0, ' + Const.round2(baseAlpha * 0.94) + ')');
      tailFade.addColorStop(1, 'rgba(0, 0, 0, 0)');

      var segments = PROJECTED_SHADOW_SEMICIRCLE_SEGMENTS;
      if (segments < 3)
        segments = 3;
      var semicircleEnd = segments + 1;

      mapCtx.save();
      mapCtx.globalCompositeOperation = 'source-over';
      mapCtx.fillStyle = tailFade;
      mapCtx.beginPath();
      mapCtx.moveTo(edge1.x, edge1.y);
      mapCtx.lineTo(edge2.x, edge2.y);
      mapCtx.lineTo(cap2X, cap2Y);

      for (i in 1...semicircleEnd)
        {
          var t = i / segments;
          var angle = t * Math.PI;
          var px = capCenterX +
            chordDirX * (Math.cos(angle) * radius) +
            capNormalX * (Math.sin(angle) * radius);
          var py = capCenterY +
            chordDirY * (Math.cos(angle) * radius) +
            capNormalY * (Math.sin(angle) * radius);
          mapCtx.lineTo(px, py);
        }

      mapCtx.lineTo(edge1.x, edge1.y);
      mapCtx.closePath();
      mapCtx.fill();
      mapCtx.restore();
    }

// get max ray travel in lightmap pixels before hitting vision-blocking tile
  function getProjectedShadowWalkableDistancePx(area: AreaGame,
      startX: Float, startY: Float,
      dirX: Float, dirY: Float,
      maxDistancePx: Float): Float
    {
      var stepPx = 1.0;
      var distPx = 0.0;
      while (distPx <= maxDistancePx)
        {
          var sampleX = startX + dirX * distPx;
          var sampleY = startY + dirY * distPx;
          var tileX = Std.int(Math.floor(sampleX / ATMOS_LIGHTMAP_TILE_SIZE));
          var tileY = Std.int(Math.floor(sampleY / ATMOS_LIGHTMAP_TILE_SIZE));
          if (tileX < 0 ||
              tileY < 0 ||
              tileX >= area.width ||
              tileY >= area.height)
            return Const.clampFloat(distPx - stepPx, 0, maxDistancePx);
          if (!canProjectedShadowPassTile(area, tileX, tileY))
            return Const.clampFloat(distPx - stepPx, 0, maxDistancePx);
          distPx += stepPx;
        }
      return maxDistancePx;
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

// draw one or two lightmaps to world context clipped by current visibility
  function drawMapsMaskedByVis(ctx: CanvasRenderingContext2D,
      area: AreaGame, cache: Array<Array<Int>>,
      map1: CanvasElement, ?map2: CanvasElement)
    {
      var composeCtx = composeMap.getContext2d();
      composeCtx.clearRect(0, 0, composeMap.width,
        composeMap.height);
      paintMap(composeCtx, map1, false, 0, 0);
      if (map2 != null)
        paintMap(composeCtx, map2, false, 0, 0);
      ensureVisMask(area, cache);
      composeCtx.save();
      composeCtx.globalCompositeOperation = 'destination-in';
      composeCtx.drawImage(visMaskMap, 0, 0);
      composeCtx.restore();

      ctx.drawImage(composeMap,
        scene.cameraSubX, scene.cameraSubY);
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

      ensureVisMask(area, cache);
      composeCtx.save();
      composeCtx.globalCompositeOperation = 'destination-in';
      composeCtx.drawImage(visMaskMap, 0, 0);
      composeCtx.restore();
    }

// rebuild screen-space visibility mask from current tile visibility cache
  function rebuildVisMask(area: AreaGame, cache: Array<Array<Int>>)
    {
      var maskCtx = visMaskMap.getContext2d();
      maskCtx.clearRect(0, 0, visMaskMap.width,
        visMaskMap.height);
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
              fillVisRun(maskCtx, runStart, x, y);
              runStart = -1;
            }
          if (runStart >= 0)
            fillVisRun(maskCtx, runStart, rect.x2, y);
        }
    }

// fill one continuous row run in screen-space visibility mask
  function fillVisRun(maskCtx: CanvasRenderingContext2D,
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
      var falloffProfile = (stamp.falloffProfile != null ?
        stamp.falloffProfile : FALL_OFF_PROFILE_SMOOTH_CURRENT);
      var isSharpLegacy = (falloffProfile == FALL_OFF_PROFILE_SHARP_LEGACY);
      var cutAlpha = Const.round2(stamp.intensity);
      mapCtx.save();
      mapCtx.globalCompositeOperation = 'destination-out';
      var cutout = mapCtx.createRadialGradient(cx, cy, 0, cx, cy, radius);
      cutout.addColorStop(0, 'rgba(0, 0, 0, ' + cutAlpha + ')');
      if (isSharpLegacy)
        {
          cutout.addColorStop(0.86,
            'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.68) + ')');
          cutout.addColorStop(0.96,
            'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.12) + ')');
        }
      else
        {
          cutout.addColorStop(0.42,
            'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.78) + ')');
          cutout.addColorStop(0.72,
            'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.46) + ')');
          cutout.addColorStop(0.90,
            'rgba(0, 0, 0, ' + Const.round2(cutAlpha * 0.16) + ')');
        }
      cutout.addColorStop(1, 'rgba(0, 0, 0, 0)');
      mapCtx.fillStyle = cutout;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius, 0, Math.PI * 2, false);
      mapCtx.fill();
      mapCtx.restore();

      mapCtx.save();
      var glowRadiusMul = (isSharpLegacy ? 1.08 : 1.16);
      var glow = mapCtx.createRadialGradient(cx, cy, 0, cx, cy,
        radius * glowRadiusMul);
      var glowAlpha = Const.round2(stamp.intensity * 0.38);
      var saturationBoost = (stamp.saturationBoost != null ?
        stamp.saturationBoost : 1.0);
      var tint = getSaturatedTint(stamp.tintR, stamp.tintG, stamp.tintB,
        saturationBoost);
      glow.addColorStop(0, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
        tint.b + ', ' + glowAlpha + ')');
      if (isSharpLegacy)
        {
          glow.addColorStop(0.78, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
            tint.b + ', ' + Const.round2(glowAlpha * 0.48) + ')');
          glow.addColorStop(0.95, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
            tint.b + ', ' + Const.round2(glowAlpha * 0.06) + ')');
        }
      else
        {
          glow.addColorStop(0.34, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
            tint.b + ', ' + Const.round2(glowAlpha * 0.72) + ')');
          glow.addColorStop(0.68, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
            tint.b + ', ' + Const.round2(glowAlpha * 0.36) + ')');
          glow.addColorStop(0.90, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
            tint.b + ', ' + Const.round2(glowAlpha * 0.12) + ')');
        }
      glow.addColorStop(1, 'rgba(' + tint.r + ', ' + tint.g + ', ' +
        tint.b + ', 0)');
      mapCtx.fillStyle = glow;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius * glowRadiusMul, 0, Math.PI * 2, false);
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
      glow.addColorStop(0.30,
        'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + Const.round2(alpha * 0.72) + ')');
      glow.addColorStop(0.64,
        'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + Const.round2(alpha * 0.34) + ')');
      glow.addColorStop(0.88,
        'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', ' + Const.round2(alpha * 0.10) + ')');
      glow.addColorStop(1, 'rgba(' + light.tintR + ', ' + light.tintG + ', ' +
        light.tintB + ', 0)');
      mapCtx.fillStyle = glow;
      mapCtx.beginPath();
      mapCtx.arc(cx, cy, radius, 0, Math.PI * 2, false);
      mapCtx.fill();
    }

// apply saturation boost to rgb tint around its channel average
  function getSaturatedTint(r: Int, g: Int, b: Int,
      saturationBoost: Float): _LightTint
    {
      if (saturationBoost == 1.0)
        return { r: r, g: g, b: b };
      var avg = (r + g + b) / 3.0;
      var boostedR = Std.int(Math.round(Const.clampFloat(avg +
        (r - avg) * saturationBoost, 0, 255)));
      var boostedG = Std.int(Math.round(Const.clampFloat(avg +
        (g - avg) * saturationBoost, 0, 255)));
      var boostedB = Std.int(Math.round(Const.clampFloat(avg +
        (b - avg) * saturationBoost, 0, 255)));
      return {
        r: boostedR,
        g: boostedG,
        b: boostedB,
      };
    }

// get reusable offscreen canvas for projected-shadow mask extraction
  function getShadowWorkMap(width: Int, height: Int): CanvasElement
    {
      if (shadowWorkMap == null)
        shadowWorkMap = Browser.document.createCanvasElement();
      if (shadowWorkMap.width != width ||
          shadowWorkMap.height != height)
        {
          shadowWorkMap.width = width;
          shadowWorkMap.height = height;
        }
      return shadowWorkMap;
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

private typedef _ProjectedShadowCaster = {
  var layerID: Int;
  var srcRow: Int;
  var srcCol: Int;
  var blockW: Int;
  var blockH: Int;
  var centerX: Float;
  var centerY: Float;
}

private typedef _ProjectedShadowMaskPoint = {
  var x: Float;
  var y: Float;
}

private typedef _ProjectedShadowMask = {
  var points: Array<_ProjectedShadowMaskPoint>;
}

private typedef _ProjectedShadowEdgePair = {
  var edge1: _ProjectedShadowMaskPoint;
  var edge2: _ProjectedShadowMaskPoint;
}

private typedef _LayoutShadowEmitter = {
  var x: Float;
  var y: Float;
}

private typedef _LayoutShadowEmitterHit = {
  var emitter: _LayoutShadowEmitter;
  var distSq: Float;
}

private typedef _DebugLightMarker = {
  var x: Float;
  var y: Float;
  var castsShadows: Bool;
}

private typedef _AIShadowCaster = {
  var caster: _ProjectedShadowCaster;
  var layer: Image;
  var maskKey: String;
}

private typedef _AIShadowSpriteSource = {
  var imageKey: String;
  var image: Image;
  var srcRow: Int;
  var srcCol: Int;
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

private typedef _LayoutLightSource = {
  var x: Int;
  var y: Int;
  var tintR: Int;
  var tintG: Int;
  var tintB: Int;
  var kind: String;
  var sourceGroupID: String;
}

private typedef _LightTint = {
  var r: Int;
  var g: Int;
  var b: Int;
}

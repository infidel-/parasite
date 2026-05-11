// tiled area view

import haxe.Timer;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import particles.Particle;
import entities.EffectEntity;
import game.Game;
import tiles.Tileset;

@:expose
class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene
  var minimap: CanvasElement; // minimap element
  var losOverlay: CanvasElement; // screen-space los blackout overlay
  var losRenderStats: _LOSRenderStats; // smooth los overlay render profile
  var minimapAreaID: Int;

  var _particles: List<Particle>;
  var _effects: List<EffectEntity>; // visual effects list
  var _cache: Array<Array<Int>>; // tiles drawn on screen
  var path: Array<aPath.Node>; // currently visible path
  var fakeHosts: Array<_FakeHost>; // background hosts
  var _tileset: Tileset;
  var tileset(get, null): Tileset;

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  static var maxSize = 120;
  static inline var LOS_RAY_EPSILON: Float = 0.0001;
  static inline var LOS_RAY_DEDUPE_EPSILON: Float = 0.0000001;
  static inline var LOS_INTERSECTION_EPSILON: Float = 0.0001;
  var drawIntervalID: Int; // if set, draw will be called every 10 ms

  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      fakeHosts = [];
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;
      drawIntervalID = 0;
      path = null;
      minimap = null;
      losOverlay = null;
      losRenderStats = createLOSRenderStats();
      _tileset = null;

      // init tiles cache 
      _cache = [];
      for (i in 0...width)
        _cache[i] = [];
      for (y in 0...height)
        for (x in 0...width)
          _cache[x][y] = 0;

      _effects = new List();
      _particles = new List();
    }

// add particle to list
  public function addParticle(p: Particle)
    {
      _particles.add(p);
      scene.areaLighting.onParticleAdded(p);
      // set interval to call draw every 10 ms 
      if (drawIntervalID == 0)
        drawIntervalID = Browser.window.setInterval(draw, 10);
    }

// redraw area map
  public function draw()
    {
      var renderTS = scene.beginRenderSample();
//      var time = Sys.time();
//      trace('draw area');
      var ctx:CanvasRenderingContext2D = scene.canvas.getContext('2d');
      ctx.clearRect(0, 0, scene.canvas.width, scene.canvas.height);

      ctx.save();
      ctx.translate(-scene.cameraSubX, -scene.cameraSubY);

      // tiles
      ctx.imageSmoothingEnabled = false;
      drawTiles(ctx);
      // smooth everything else
      ctx.imageSmoothingEnabled = true;
      scene.areaLighting.drawDynamicUnderSpriteShadows(ctx, _cache);

      // objects
      for (o in game.area.getObjects())
        if (o.entity != null)
          if (isFormaMode() ||
              !game.player.vars.losEnabled ||
              (game.player.state != PLR_STATE_HOST &&
               o.sensable()) ||
              (game.playerArea.sees(o.x, o.y) &&
              o.entity.isVisible()))
            o.entity.draw(ctx);

      // effects
      for (e in _effects)
        if (e.isVisible())
          e.draw(ctx);

      // ai and player
      if (game.player.state == PLR_STATE_PARASITE)
        game.playerArea.entity.draw(ctx);
      for (ai in @:privateAccess game.area._ai)
        if (ai.entity != null)
          if (isFormaMode() ||
              !game.player.vars.losEnabled ||
              (game.playerArea.sees(ai.x, ai.y) &&
              ai.entity.isVisible()))
            ai.entity.draw(ctx);

      // atmospheric lighting overlay
      scene.areaLighting.drawAreaLighting(ctx, _cache);

      // particles
      drawParticles(ctx);

      // path
      if (path != null)
        for (pos in path)
          ctx.drawImage(scene.images.entities,
            Const.FRAME_DOT * Const.TILE_SIZE_CLEAN, 
            Const.ROW_PARASITE * Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,

            (pos.x - scene.cameraTileX1) * Const.TILE_SIZE,
            (pos.y - scene.cameraTileY1) * Const.TILE_SIZE,
            Const.TILE_SIZE,
            Const.TILE_SIZE);
      drawBaseCursorReticle(ctx);
      AreaLightingDebug.drawDebugLightMarkers(scene.areaLighting, ctx);
      ctx.restore();
      drawSmoothLOSOverlay(ctx);

      // regen minimap on first draw for area
      if (minimapAreaID != game.area.id)
        {
          generateMinimap();
          minimapAreaID = game.area.id;
        }
      // minimap
      if (minimap != null &&
          (game.ui.hud.isVisible() ||
           game.ui.state == UISTATE_OPTIONS) &&
          game.player.vars.mapAbsorbed)
        {
          var log = Browser.document.getElementById('hud-log');
          var rect = log.getBoundingClientRect();
          var logy = rect.top + Browser.window.scrollY;
          var mx = 15 * Browser.window.devicePixelRatio;
          var my = (logy + log.offsetHeight + 10) *
            Browser.window.devicePixelRatio;
          ctx.drawImage(minimap, mx, my);

          // draw player dot
          ctx.fillStyle = '#c441c4';
          ctx.beginPath();
          var px = mx + game.playerArea.x * game.config.minimapScale;
          var py = my + game.playerArea.y * game.config.minimapScale;
          ctx.arc(px, py, 2 * game.config.minimapScale,
            0, Math.PI * 2, false);
          ctx.fill();

        }
      scene.endRenderSampleArea(renderTS);
//      trace('draw: ' + (Sys.time() - time) + 'ms');
    }

// get formatted smooth los overlay render profiling text
  public function getSmoothLOSRenderStatsText(): String
    {
      if (!losRenderStats.hasSamples)
        return Const.small('Area smooth LOS overlay render time (ms): N/A<br/>' +
          'Area smooth LOS overlay counts: N/A');
      return Const.small('Area smooth LOS overlay render time (ms): max ' +
        Const.round2(losRenderStats.maxMs) + ' / avg ' +
        Const.round2(losRenderStats.avgMs) + ' / last ' +
        Const.round2(losRenderStats.lastMs) + '<br/>' +
        'Area smooth LOS overlay counts: blockers ' +
        losRenderStats.lastBlockers +
        ', segments ' + losRenderStats.lastSegments +
        ', rays ' + losRenderStats.lastRays +
        ', hits ' + losRenderStats.lastHits +
        ', hit tiles ' + losRenderStats.lastHitTiles +
        ', room tiles ' + losRenderStats.lastRoomTiles);
    }

// get plain smooth los overlay render profile for browser console copy-paste
  public function getSmoothLOSRenderStatsConsoleText(): String
    {
      if (!losRenderStats.hasSamples)
        return 'Area smooth LOS overlay: no samples';
      return 'Area smooth LOS overlay\n' +
        '  total ms: max ' + Const.round2(losRenderStats.maxMs) +
        ' / avg ' + Const.round2(losRenderStats.avgMs) +
        ' / last ' + Const.round2(losRenderStats.lastMs) + '\n' +
        '  phase ms last: setup ' +
        Const.round2(losRenderStats.lastSetupMs) +
        ', segments ' + Const.round2(losRenderStats.lastSegmentsMs) +
        ', polygon ' + Const.round2(losRenderStats.lastPolygonMs) +
        ', compose ' + Const.round2(losRenderStats.lastComposeMs) +
        ', draw ' + Const.round2(losRenderStats.lastDrawMs) + '\n' +
        '  counts last: blockers ' + losRenderStats.lastBlockers +
        ', segments ' + losRenderStats.lastSegments +
        ', rays ' + losRenderStats.lastRays +
        ', hits ' + losRenderStats.lastHits +
        ', hit tiles ' + losRenderStats.lastHitTiles +
        ', room tiles ' + losRenderStats.lastRoomTiles + '\n' +
        '  canvas: ' + scene.canvas.width + 'x' + scene.canvas.height +
        ', tiles: ' +
        Std.int(scene.canvas.width / Const.TILE_SIZE) + 'x' +
        Std.int(scene.canvas.height / Const.TILE_SIZE) +
        ', tile size: ' + Const.TILE_SIZE;
    }

// draw area tiles
  function drawTiles(ctx: CanvasRenderingContext2D)
    {
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();
      var tiles = game.area.getTiles();
      var hasTileData = (tiles != null &&
        tiles.length > 0);
      var drawRealTiles = isFormaMode() || shouldDrawSmoothLOSOverlay();
      var tileID = 0;
      var icon: _Icon = null;

      // draw base tiles first
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            tileID = (drawRealTiles ? cells[x][y] : _cache[x][y]);
            icon = tileset.getIcon(tileID);
            var sx = (x - scene.cameraTileX1) * Const.TILE_SIZE;
            var sy = (y - scene.cameraTileY1) * Const.TILE_SIZE;
            tileset.draw(ctx, icon,
              sx, sy);
          }

      // draw static projected shadows above base tiles and below decorations
      var prevSmoothing = ctx.imageSmoothingEnabled;
      ctx.imageSmoothingEnabled = true;
      scene.areaLighting.drawStaticUnderSpriteShadows(ctx, _cache);
      ctx.imageSmoothingEnabled = prevSmoothing;

      // draw floor decorations on top of base tiles and shadows
      if (hasTileData)
        for (y in rect.y1...rect.y2)
          for (x in rect.x1...rect.x2)
            {
              tileID = (drawRealTiles ? cells[x][y] : _cache[x][y]);
              var sx = (x - scene.cameraTileX1) * Const.TILE_SIZE;
              var sy = (y - scene.cameraTileY1) * Const.TILE_SIZE;
              tileset.drawFloorDecoration(ctx,
                tileID, tiles[x][y], sx, sy);
            }

      // draw wall decorations above floor decorations
      if (hasTileData)
        for (y in rect.y1...rect.y2)
          for (x in rect.x1...rect.x2)
            {
              tileID = (drawRealTiles ? cells[x][y] : _cache[x][y]);
              icon = tileset.getIcon(tileID);
              var sx = (x - scene.cameraTileX1) * Const.TILE_SIZE;
              var sy = (y - scene.cameraTileY1) * Const.TILE_SIZE;
              tileset.drawWallDecoration(ctx, icon,
                tileID, tiles[x][y], sx, sy);
            }

      // corp has fake people in the background
      if (game.area.info.id == AREA_CORP)
        for (y in rect.y1...rect.y2)
          for (x in rect.x1...rect.x2)
            {
              tileID = (drawRealTiles ? cells[x][y] : _cache[x][y]);
              icon = tileset.getIcon(tileID);
              paintFakeHost(ctx, icon, x, y);
            }
    }

// return whether host los should render real tiles under a smooth blackout overlay
  inline function shouldDrawSmoothLOSOverlay(): Bool
    {
      return (game.player.vars.losEnabled &&
        !isFormaMode() &&
        game.player.state == PLR_STATE_HOST);
    }

// returns true while forma mode is active
  inline function isFormaMode(): Bool
    {
      return game.ui.hud.state == HUD_BASE_BUILDING;
    }

// draw smooth host line-of-sight blackout using one visibility polygon
  function drawSmoothLOSOverlay(ctx: CanvasRenderingContext2D)
    {
      if (!shouldDrawSmoothLOSOverlay())
        return;

      var profileTS = Timer.stamp() * 1000;
      var phaseTS = profileTS;
      var rect = game.area.getVisibleRect();
      var origin: _LOSPoint = {
        x: (game.playerArea.x - scene.cameraTileX1) * Const.TILE_SIZE +
          Const.TILE_SIZE / 2 - scene.cameraSubX,
        y: (game.playerArea.y - scene.cameraTileY1) * Const.TILE_SIZE +
          Const.TILE_SIZE / 2 - scene.cameraSubY,
      };
      var setupMs = Timer.stamp() * 1000 - phaseTS;
      var rayAngles: Array<Float> = [];
      phaseTS = Timer.stamp() * 1000;
      var segmentBuild = buildLOSSegments(rect, origin, rayAngles);
      var segments = segmentBuild.segments;
      rayAngles = dedupeLOSRayAngles(rayAngles);
      var segmentsMs = Timer.stamp() * 1000 - phaseTS;
      phaseTS = Timer.stamp() * 1000;
      var hits = buildLOSVisiblePolygon(origin, rayAngles, segments);
      var polygonMs = Timer.stamp() * 1000 - phaseTS;
      if (hits.length < 3)
        {
          updateSmoothLOSRenderStats(Timer.stamp() * 1000 - profileTS,
            segmentBuild.blockers, segments.length, rayAngles.length,
            hits.length, 0, 0, setupMs, segmentsMs, polygonMs, 0, 0);
          return;
        }

      phaseTS = Timer.stamp() * 1000;
      var overlay = ensureLOSOverlay();
      var overlayCtx = overlay.getContext2d();
      overlayCtx.clearRect(0, 0, overlay.width, overlay.height);
      overlayCtx.save();
      overlayCtx.fillStyle = '#000000';
      overlayCtx.fillRect(0, 0, overlay.width, overlay.height);
      overlayCtx.globalCompositeOperation = 'destination-out';
      overlayCtx.beginPath();
      addLOSVisiblePolygonPath(overlayCtx, hits);
      overlayCtx.fill();
      overlayCtx.beginPath();
      var hitTiles = addLOSHitOpaqueTilePaths(overlayCtx, hits);
      overlayCtx.fill();
      overlayCtx.beginPath();
      var roomTiles = addLOSCurrentRoomPerimeterPaths(overlayCtx, rect);
      overlayCtx.fill();
      overlayCtx.restore();
      var composeMs = Timer.stamp() * 1000 - phaseTS;

      phaseTS = Timer.stamp() * 1000;
      ctx.drawImage(overlay, 0, 0);
      var drawMs = Timer.stamp() * 1000 - phaseTS;

      updateSmoothLOSRenderStats(Timer.stamp() * 1000 - profileTS,
        segmentBuild.blockers, segments.length, rayAngles.length, hits.length,
        hitTiles, roomTiles, setupMs, segmentsMs, polygonMs, composeMs,
        drawMs);
    }

// create or resize screen-space los overlay canvas
  function ensureLOSOverlay(): CanvasElement
    {
      if (losOverlay == null)
        losOverlay = Browser.document.createCanvasElement();
      if (losOverlay.width != scene.canvas.width)
        losOverlay.width = scene.canvas.width;
      if (losOverlay.height != scene.canvas.height)
        losOverlay.height = scene.canvas.height;
      return losOverlay;
    }

// return whether a screen-space rect overlaps the canvas viewport
  inline function losRectIntersectsScreen(x1: Float, y1: Float,
      x2: Float, y2: Float): Bool
    {
      return !(x2 <= 0 ||
        y2 <= 0 ||
        x1 >= scene.canvas.width ||
        y1 >= scene.canvas.height);
    }

// build los blocker and screen-boundary segments for ray intersection
  function buildLOSSegments(rect: { x1: Int, y1: Int, x2: Int, y2: Int },
      origin: _LOSPoint, rayAngles: Array<Float>): _LOSSegmentBuild
    {
      var segments: Array<_LOSSegment> = [];
      addLOSRectSegments(segments, rayAngles, origin,
        0, 0, scene.canvas.width, scene.canvas.height, -1, -1);

      var blockers = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            if (!isLOSBoundaryBlocker(x, y))
              continue;

            var sx1 = (x - scene.cameraTileX1) * Const.TILE_SIZE -
              scene.cameraSubX;
            var sy1 = (y - scene.cameraTileY1) * Const.TILE_SIZE -
              scene.cameraSubY;
            var sx2 = sx1 + Const.TILE_SIZE;
            var sy2 = sy1 + Const.TILE_SIZE;
            if (!losRectIntersectsScreen(sx1, sy1, sx2, sy2))
              continue;
            addLOSBlockerSegments(segments, rayAngles, origin,
              sx1, sy1, sx2, sy2, x, y);
            blockers++;
          }
      return {
        segments: segments,
        blockers: blockers,
      };
    }

// return whether one opaque tile touches see-through space
  function isLOSBoundaryBlocker(x: Int, y: Int): Bool
    {
      if (game.area.canSeeThrough(x, y))
        return false;
      return (game.area.canSeeThrough(x - 1, y) ||
        game.area.canSeeThrough(x + 1, y) ||
        game.area.canSeeThrough(x, y - 1) ||
        game.area.canSeeThrough(x, y + 1));
    }

// add rectangle edges and corner ray angles to los polygon inputs
  function addLOSRectSegments(segments: Array<_LOSSegment>,
      rayAngles: Array<Float>, origin: _LOSPoint,
      x1: Float, y1: Float, x2: Float, y2: Float,
      tileX: Int, tileY: Int)
    {
      addLOSSegment(segments, x1, y1, x2, y1, tileX, tileY);
      addLOSSegment(segments, x2, y1, x2, y2, tileX, tileY);
      addLOSSegment(segments, x2, y2, x1, y2, tileX, tileY);
      addLOSSegment(segments, x1, y2, x1, y1, tileX, tileY);

      addLOSRayAngles(rayAngles, origin, x1, y1);
      addLOSRayAngles(rayAngles, origin, x2, y1);
      addLOSRayAngles(rayAngles, origin, x2, y2);
      addLOSRayAngles(rayAngles, origin, x1, y2);
    }

// add only see-through-facing blocker edges and their endpoint ray angles
  function addLOSBlockerSegments(segments: Array<_LOSSegment>,
      rayAngles: Array<Float>, origin: _LOSPoint,
      x1: Float, y1: Float, x2: Float, y2: Float,
      tileX: Int, tileY: Int)
    {
      if (game.area.canSeeThrough(tileX, tileY - 1))
        addLOSEdgeSegment(segments, rayAngles, origin,
          x1, y1, x2, y1, tileX, tileY);
      if (game.area.canSeeThrough(tileX + 1, tileY))
        addLOSEdgeSegment(segments, rayAngles, origin,
          x2, y1, x2, y2, tileX, tileY);
      if (game.area.canSeeThrough(tileX, tileY + 1))
        addLOSEdgeSegment(segments, rayAngles, origin,
          x2, y2, x1, y2, tileX, tileY);
      if (game.area.canSeeThrough(tileX - 1, tileY))
        addLOSEdgeSegment(segments, rayAngles, origin,
          x1, y2, x1, y1, tileX, tileY);
    }

// add one exposed blocker edge and rays to both endpoints
  function addLOSEdgeSegment(segments: Array<_LOSSegment>,
      rayAngles: Array<Float>, origin: _LOSPoint,
      x1: Float, y1: Float, x2: Float, y2: Float,
      tileX: Int, tileY: Int)
    {
      addLOSSegment(segments, x1, y1, x2, y2, tileX, tileY);
      addLOSRayAngles(rayAngles, origin, x1, y1);
      addLOSRayAngles(rayAngles, origin, x2, y2);
    }

// add one los line segment
  inline function addLOSSegment(segments: Array<_LOSSegment>,
      x1: Float, y1: Float, x2: Float, y2: Float,
      tileX: Int, tileY: Int)
    {
      segments.push({
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        tileX: tileX,
        tileY: tileY,
      });
    }

// add center, left, and right corner ray angles for robust corner hits
  function addLOSRayAngles(rayAngles: Array<Float>,
      origin: _LOSPoint, x: Float, y: Float)
    {
      var angle = Math.atan2(y - origin.y, x - origin.x);
      rayAngles.push(angle - LOS_RAY_EPSILON);
      rayAngles.push(angle);
      rayAngles.push(angle + LOS_RAY_EPSILON);
    }

// remove duplicate ray angles created by shared blocker edge endpoints
  function dedupeLOSRayAngles(rayAngles: Array<Float>): Array<Float>
    {
      if (rayAngles.length <= 1)
        return rayAngles;

      rayAngles.sort(function(a: Float, b: Float): Int
        {
          if (a < b)
            return -1;
          if (a > b)
            return 1;
          return 0;
        });

      var ret: Array<Float> = [];
      for (angle in rayAngles)
        {
          if (ret.length == 0 ||
              Math.abs(angle - ret[ret.length - 1]) >
              LOS_RAY_DEDUPE_EPSILON)
            ret.push(angle);
        }
      return ret;
    }

// draws the forma cursor reticle
  function drawBaseCursorReticle(ctx: CanvasRenderingContext2D)
    {
      if (game.ui.hud.state != HUD_BASE_BUILDING ||
          game.cults.length == 0 ||
          game.cults[0].base == null)
        return;

      var base = game.cults[0].base;
      if (!game.area.inVisibleRect(base.cursorX, base.cursorY))
        return;

      ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
      ctx.shadowBlur = 5;
      ctx.shadowOffsetX = 1;
      ctx.shadowOffsetY = 1;
      ctx.drawImage(scene.images.entities,
        Const.FRAME_TARGET_RETICLE * Const.TILE_SIZE_CLEAN,
        Const.ROW_REGION_ICON * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,
        (base.cursorX - scene.cameraTileX1) * Const.TILE_SIZE,
        (base.cursorY - scene.cameraTileY1) * Const.TILE_SIZE,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
      ctx.shadowColor = 'transparent';
    }

// build sorted los polygon points from nearest ray-segment intersections
  function buildLOSVisiblePolygon(origin: _LOSPoint,
      rayAngles: Array<Float>, segments: Array<_LOSSegment>): Array<_LOSRayHit>
    {
      var hits: Array<_LOSRayHit> = [];
      for (angle in rayAngles)
        {
          var hit = castLOSRay(origin, angle, segments);
          if (hit != null)
            hits.push(hit);
        }
      hits.sort(function(a: _LOSRayHit, b: _LOSRayHit): Int
        {
          if (a.angle < b.angle)
            return -1;
          if (a.angle > b.angle)
            return 1;
          return 0;
        });
      return dedupeLOSRayHits(hits);
    }

// cast one los ray and return the closest segment intersection
  function castLOSRay(origin: _LOSPoint,
      angle: Float, segments: Array<_LOSSegment>): _LOSRayHit
    {
      var rayX = Math.cos(angle);
      var rayY = Math.sin(angle);
      var bestDistance = 1000000.0;
      var bestHit: _LOSRayHit = null;
      for (segment in segments)
        {
          var hit = intersectLOSRaySegment(origin, rayX, rayY, segment);
          if (hit == null ||
              hit.distance >= bestDistance)
            continue;
          bestDistance = hit.distance;
          bestHit = hit;
        }
      if (bestHit == null)
        return null;
      bestHit.angle = angle;
      return bestHit;
    }

// return intersection between one ray and one finite segment
  function intersectLOSRaySegment(origin: _LOSPoint,
      rayX: Float, rayY: Float, segment: _LOSSegment): _LOSRayHit
    {
      var segX = segment.x2 - segment.x1;
      var segY = segment.y2 - segment.y1;
      var dx = segment.x1 - origin.x;
      var dy = segment.y1 - origin.y;
      var denom = rayX * segY - rayY * segX;
      if (Math.abs(denom) < LOS_INTERSECTION_EPSILON)
        return null;

      var distance = (dx * segY - dy * segX) / denom;
      var segmentPos = (dx * rayY - dy * rayX) / denom;
      if (distance < LOS_INTERSECTION_EPSILON ||
          segmentPos < -LOS_INTERSECTION_EPSILON ||
          segmentPos > 1 + LOS_INTERSECTION_EPSILON)
        return null;

      return {
        angle: 0,
        point: {
          x: origin.x + rayX * distance,
          y: origin.y + rayY * distance,
        },
        distance: distance,
        tileX: segment.tileX,
        tileY: segment.tileY,
      };
    }

// remove adjacent duplicate ray hits before drawing the polygon
  function dedupeLOSRayHits(hits: Array<_LOSRayHit>): Array<_LOSRayHit>
    {
      if (hits.length <= 1)
        return hits;

      var ret: Array<_LOSRayHit> = [];
      for (hit in hits)
        {
          if (ret.length == 0 ||
              losPointDistanceSquared(hit.point,
                ret[ret.length - 1].point) > 0.01)
            ret.push(hit);
        }
      if (ret.length > 1 &&
          losPointDistanceSquared(ret[0].point,
            ret[ret.length - 1].point) <= 0.01)
        ret.pop();
      return ret;
    }

// return squared distance between two screen-space points
  inline function losPointDistanceSquared(a: _LOSPoint, b: _LOSPoint): Float
    {
      var dx = a.x - b.x;
      var dy = a.y - b.y;
      return dx * dx + dy * dy;
    }

// add the visible los polygon as a hole in the blackout path
  function addLOSVisiblePolygonPath(ctx: CanvasRenderingContext2D,
      hits: Array<_LOSRayHit>)
    {
      ctx.moveTo(hits[0].point.x, hits[0].point.y);
      for (i in 1...hits.length)
        ctx.lineTo(hits[i].point.x, hits[i].point.y);
      ctx.closePath();
    }

// add opaque tiles directly hit by los rays as holes in the blackout path
  function addLOSHitOpaqueTilePaths(ctx: CanvasRenderingContext2D,
      hits: Array<_LOSRayHit>): Int
    {
      var revealed: Map<String, Bool> = new Map();
      var count = 0;
      for (hit in hits)
        {
          if (hit.tileX < 0 ||
              hit.tileY < 0)
            continue;

          var key = hit.tileX + ',' + hit.tileY;
          if (revealed.exists(key))
            continue;
          revealed.set(key, true);

          var sx = (hit.tileX - scene.cameraTileX1) * Const.TILE_SIZE -
            scene.cameraSubX;
          var sy = (hit.tileY - scene.cameraTileY1) * Const.TILE_SIZE -
            scene.cameraSubY;
          ctx.rect(sx, sy, Const.TILE_SIZE, Const.TILE_SIZE);
          count++;
        }
      return count;
    }

// add current room perimeter tiles as holes in the blackout path
  function addLOSCurrentRoomPerimeterPaths(ctx: CanvasRenderingContext2D,
      rect: { x1: Int, y1: Int, x2: Int, y2: Int }): Int
    {
      var info = game.area.generatorInfo;
      if (info == null ||
          info.rooms == null ||
          info.rooms.length == 0)
        return 0;

      var room = info.getRoomAt(game.playerArea.x, game.playerArea.y);
      if (room == null)
        return 0;

      var sx = room.x1 - 1;
      var sy = room.y1 - 1;
      var ex = room.x2 + 1;
      var ey = room.y2 + 1;

      if (sx < rect.x1)
        sx = rect.x1;
      if (sy < rect.y1)
        sy = rect.y1;
      if (ex >= rect.x2)
        ex = rect.x2 - 1;
      if (ey >= rect.y2)
        ey = rect.y2 - 1;
      if (sx > ex ||
          sy > ey)
        return 0;

      var count = 0;
      for (y in sy...ey + 1)
        for (x in sx...ex + 1)
          {
            if (x > sx &&
                x < ex &&
                y > sy &&
                y < ey)
              continue;

            var px = (x - scene.cameraTileX1) * Const.TILE_SIZE -
              scene.cameraSubX;
            var py = (y - scene.cameraTileY1) * Const.TILE_SIZE -
              scene.cameraSubY;
            ctx.rect(px, py, Const.TILE_SIZE, Const.TILE_SIZE);
            count++;
          }
      return count;
    }

// create empty smooth los overlay render stats holder
  function createLOSRenderStats(): _LOSRenderStats
    {
      return {
        samples: [],
        nextIndex: 0,
        count: 0,
        sumMs: 0,
        maxMs: 0,
        avgMs: 0,
        lastMs: 0,
        lastBlockers: 0,
        lastSegments: 0,
        lastRays: 0,
        lastHits: 0,
        lastHitTiles: 0,
        lastRoomTiles: 0,
        lastSetupMs: 0,
        lastSegmentsMs: 0,
        lastPolygonMs: 0,
        lastComposeMs: 0,
        lastDrawMs: 0,
        hasSamples: false,
      };
    }

// update rolling smooth los overlay render stats from one sample
  function updateSmoothLOSRenderStats(duration: Float,
      blockers: Int, segments: Int, rays: Int, hits: Int,
      hitTiles: Int, roomTiles: Int, setupMs: Float, segmentsMs: Float,
      polygonMs: Float, composeMs: Float, drawMs: Float)
    {
      if (duration < 0)
        duration = 0;
      if (losRenderStats.count < 10)
        {
          losRenderStats.samples.push(duration);
          losRenderStats.sumMs += duration;
          losRenderStats.count = losRenderStats.samples.length;
        }
      else
        {
          var old = losRenderStats.samples[losRenderStats.nextIndex];
          losRenderStats.sumMs -= old;
          losRenderStats.samples[losRenderStats.nextIndex] = duration;
          losRenderStats.sumMs += duration;
          losRenderStats.nextIndex++;
          if (losRenderStats.nextIndex >= 10)
            losRenderStats.nextIndex = 0;
        }

      losRenderStats.lastMs = duration;
      losRenderStats.avgMs = losRenderStats.sumMs / losRenderStats.count;
      losRenderStats.maxMs = 0;
      for (sample in losRenderStats.samples)
        if (sample > losRenderStats.maxMs)
          losRenderStats.maxMs = sample;
      losRenderStats.lastBlockers = blockers;
      losRenderStats.lastSegments = segments;
      losRenderStats.lastRays = rays;
      losRenderStats.lastHits = hits;
      losRenderStats.lastHitTiles = hitTiles;
      losRenderStats.lastRoomTiles = roomTiles;
      losRenderStats.lastSetupMs = setupMs;
      losRenderStats.lastSegmentsMs = segmentsMs;
      losRenderStats.lastPolygonMs = polygonMs;
      losRenderStats.lastComposeMs = composeMs;
      losRenderStats.lastDrawMs = drawMs;
      losRenderStats.hasSamples = true;
    }

// draw particles
  function drawParticles(ctx: CanvasRenderingContext2D)
    {
      for (p in _particles)
        {
          if (p.isDead())
            {
              p.onDeath();
              _particles.remove(p);
              continue;
            }
          var dt = (Timer.stamp() * 1000 - p.createdTS) / p.time;
          // most likely final frame
          if (dt > 0.8)
            dt = 1.0;
          p.draw(ctx, dt);
        }
      // stop redrawing
      if (_particles.length == 0 &&
          !scene.areaLighting.hasActiveTransientLights())
        {
          Browser.window.clearInterval(drawIntervalID);
          drawIntervalID = 0;
        }
    }

// mark atmosphere maps for rebuild
  public function invalidateAtmosphereLighting()
    {
      scene.areaLighting.invalidateCurrentView();
    }

// corp has fake people in the background
  function paintFakeHost(ctx, icon: _Icon, x: Int, y: Int)
    {
      // TILE_ROAD_UNWALKABLE
      if (icon.row != 2 || icon.col < 11)
        return;

      // find host
      var host = null;
      for (h in fakeHosts)
        if (h.x == x && h.y == y)
          {
            host = h;
            break;
          }
      if (host == null)
        return;

      var img = 
        (host.isMale ?
         game.scene.images.male :
         game.scene.images.female);
      ctx.globalAlpha = 0.5;
      ctx.drawImage(img,
        host.ix * Const.TILE_SIZE_CLEAN,
        host.iy * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        (x - scene.cameraTileX1) * Const.TILE_SIZE +
        Const.TILE_SIZE / 4,
        (y - scene.cameraTileY1) * Const.TILE_SIZE +
        Const.TILE_SIZE / 4,
        Const.TILE_SIZE / 2,
        Const.TILE_SIZE / 2);
      ctx.globalAlpha = 1.0;
    }

// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;
      _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
      invalidateAtmosphereLighting();
      scene.updateCamera(); // center camera on player
    }

// clears visible path
  public function clearPath(?clearAll: Bool = false)
    {
      if (clearAll)
        game.playerArea.clearPath();
      if (path == null)
        return;
      path = null;
      scene.draw();
    }


// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      path = game.area.getPath(x1, y1, x2, y2);
      if (path == null)
        return;
      path.pop();
      scene.draw();
    }

// hide gui
  public function hide()
    {
      // clear all effects
      for (eff in _effects)
        _effects.remove(eff);
      path = null;
      invalidateAtmosphereLighting();
    }


// add visual effect entity
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int): EffectEntity
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return null;

      var effect = new EffectEntity(game, x, y, turns);
      effect.setIcon('entities', frame, Const.ROW_EFFECT);
      _effects.add(effect);
      return effect;
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();
      scene.areaLighting.onVisCacheUpdated();
      scene.draw();
    }


// update visible area
// host version
  function updateVisibilityHost()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      emptyScreenCells = 0;
      var tileID = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (!game.player.vars.losEnabled ||
                game.area.isVisible(game.playerArea.x,
                  game.playerArea.y, x, y))
              tileID = cells[x][y];
            else tileID = Const.TILE_HIDDEN;
            setTile(x, y, tileID);
          }
      // additional visibility code, makes walls look better
      if (game.player.vars.losEnabled)
        {
          // go left to right and up/down on each cell
          for (x in rect.x1...rect.x2)
            if (isVisible(x, game.playerArea.y))
              {
                // check up
                var y = game.playerArea.y;
                while (true)
                  {
                    y--;
                    if (y < rect.y1)
                      break;
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
                // check down
                var y = game.playerArea.y;
                while (true)
                  {
                    y++;
                    if (y >= rect.y2)
                      break;
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }

          // go top to bottom and left/right on each cell
          for (y in rect.y1...rect.y2)
            if (isVisible(game.playerArea.x, y))
              {
                // check left
                var x = game.playerArea.x;
                while (true)
                  {
                    x--;
                    if (x < rect.x1)
                      break;
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
                // check right
                var x = game.playerArea.x;
                while (true)
                  {
                    x++;
                    if (x >= rect.x2)
                      break;
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }

          // if player is inside a room, reveal that room and its perimeter
          revealCurrentRoom(rect, cells);
        }
    }

// reveal current room tiles and perimeter using generator room info
  function revealCurrentRoom(rect: { x1: Int, y1: Int, x2: Int, y2: Int },
      cells: Array<Array<Int>>)
    {
      var info = game.area.generatorInfo;
      if (info == null ||
          info.rooms == null ||
          info.rooms.length == 0)
        return;

      var room = info.getRoomAt(game.playerArea.x, game.playerArea.y);
      if (room == null)
        return;

      revealRoomRect(room, rect, cells);
    }

// reveal room interior and one-tile perimeter
  function revealRoomRect(room: _Room,
      rect: { x1: Int, y1: Int, x2: Int, y2: Int },
      cells: Array<Array<Int>>)
    {
      var sx = room.x1 - 1;
      var sy = room.y1 - 1;
      var ex = room.x2 + 1;
      var ey = room.y2 + 1;

      if (sx < rect.x1)
        sx = rect.x1;
      if (sy < rect.y1)
        sy = rect.y1;
      if (ex >= rect.x2)
        ex = rect.x2 - 1;
      if (ey >= rect.y2)
        ey = rect.y2 - 1;
      if (sx > ex ||
          sy > ey)
        return;

      for (y in sy...ey + 1)
        for (x in sx...ex + 1)
          setTile(x, y, cells[x][y]);
    }

// set tile at x,y
  inline function setTile(x: Int, y: Int, tileID: Int)
    {
      _cache[x][y] = tileID;
    }

// update visible area
// parasite version
// parasite only sees one tile around him but "feels" AIs in a larger radius
  function updateVisibilityParasite()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      // set visibility for all tiles in that area
      emptyScreenCells = 0;
      var tileID = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (Math.abs(game.playerArea.x - x) < 2 &&
                Math.abs(game.playerArea.y - y) < 2)
              tileID = cells[x][y];
            else tileID = Const.TILE_HIDDEN;

            _cache[x][y] = tileID;
          }
    }


// returns whether this tile is currently visible to the player
// using graphics tile cache
  public inline function isVisible(x: Int, y: Int): Bool
    {
      return (_cache[x][y] != Const.TILE_HIDDEN);
    }


// TURN: area time passage
  public function turn()
    {
      // effect removal
      for (e in _effects)
        {
          // called on first turn this was created
          if (game.turns <= e.createdOn + 1)
            continue;
          e.turns--;
          if (e.turns <= 0)
            _effects.remove(e);
        }

      // fake hosts logic
      if (game.area.info.id == AREA_CORP)
        turnCorp(false);
    }

// area entered
  public function onEnter()
    {
      _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
      fakeHosts = [];
      scene.areaLighting.onAreaEntered();
      turnCorp(true);
    }

// generate minimap from tiles
  public function generateMinimap()
    {
      var scale = game.config.minimapScale;
      minimap = Browser.document.createCanvasElement();
      minimap.width = Std.int(game.area.width * scale);
      minimap.height = Std.int(game.area.height * scale);
      var ctx = minimap.getContext2d();
      untyped ctx.imageSmoothingEnabled = true;
      var tileID = 0;
      var icon: _Icon = null;
      var cells = game.area.getCells();
      ctx.fillStyle = 'red';
      ctx.fillRect(0, 0, minimap.width, minimap.height);
      for (y in 0...game.area.height)
        for (x in 0...game.area.width)
          {
            tileID = cells[x][y];
            icon = tileset.getIcon(tileID);
            ctx.drawImage(tileset.image,
              icon.col * Const.TILE_SIZE_CLEAN, 
              icon.row * Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,

              (x) * scale,
              (y) * scale,
              scale,
              scale);
          }
      // border
      ctx.strokeStyle = '#649afb';
      ctx.lineWidth = 1;
      ctx.strokeRect(0, 0, minimap.width, minimap.height);
    }

// corp area turn - fake hosts
  function turnCorp(force: Bool)
    {
      if (game.turns % 3 != 0 && !force)
        return;
      var rect = game.area.getVisibleRect();
      var icon: _Icon = null;
      var tileID = 0;
      // spawn new ones
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            tileID = _cache[x][y];
            icon = tileset.getIcon(tileID);
            // TILE_ROAD_UNWALKABLE
            if (icon.row != 2 || icon.col < 11)
              continue;
            if (Std.random(100) < 95)
              continue;
            var h: _FakeHost = {
              x: x,
              y: y,
              isMale: (Std.random(100) < 50),
              ix: Std.random(10),
              iy: 0,
            }
            h.iy = Std.random(h.isMale ? 8 : 6);
            fakeHosts.push(h);
            // limit amount
            if (fakeHosts.length > 10)
              fakeHosts.shift();
          }
    }

// get active area tileset with lazy cache
  function get_tileset(): Tileset
    {
      if (_tileset == null &&
          game.area != null)
        _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
      return _tileset;
    }
}

typedef _FakeHost = {
  var x: Int;
  var y: Int;
  var isMale: Bool;
  var ix: Int;
  var iy: Int;
}

typedef _LOSPoint = {
  var x: Float;
  var y: Float;
}

typedef _LOSSegment = {
  var x1: Float;
  var y1: Float;
  var x2: Float;
  var y2: Float;
  var tileX: Int;
  var tileY: Int;
}

typedef _LOSRayHit = {
  var angle: Float;
  var point: _LOSPoint;
  var distance: Float;
  var tileX: Int;
  var tileY: Int;
}

typedef _LOSSegmentBuild = {
  var segments: Array<_LOSSegment>;
  var blockers: Int;
}

typedef _LOSRenderStats = {
  var samples: Array<Float>;
  var nextIndex: Int;
  var count: Int;
  var sumMs: Float;
  var maxMs: Float;
  var avgMs: Float;
  var lastMs: Float;
  var lastBlockers: Int;
  var lastSegments: Int;
  var lastRays: Int;
  var lastHits: Int;
  var lastHitTiles: Int;
  var lastRoomTiles: Int;
  var lastSetupMs: Float;
  var lastSegmentsMs: Float;
  var lastPolygonMs: Float;
  var lastComposeMs: Float;
  var lastDrawMs: Float;
  var hasSamples: Bool;
}

// tiled region view (each tile corresponds to an area)

import haxe.ds.IntMap;
import js.html.CanvasRenderingContext2D;
import js.html.CanvasElement;
import js.Browser;
import game.*;
import map.Image;
import render.Viewport;
import render.particles.Sprites;

// one region-border marker: a point of interest pinned to the screen edge while it is off-screen
typedef RegionMarker = {
  x: Int,           // region tile
  y: Int,
  key: String,      // UISvg.badge glyph key
  color: String,    // ring + glyph css color
  scale: Float,     // icon scale (habitats and the spaceship draw 25% larger)
}

class RegionView
{
  var game: Game; // game state link
  var scene: GameScene; // scene link

  var path: Array<{ x: Int, y: Int }>; // currently visible path
  var haloCache: IntMap<CanvasElement>; // cached soft dark halos under the location icons

  // move slide: the player and camera are drawn offset from their logical spots, easing to zero
  static inline var SLIDE_MULT = 0.6; // slide length in BASE_MS multiples (under the 100ms path step)
  static inline var REVEAL_MULT = 1.0; // newly known tile fade length in BASE_MS multiples
  // the soft dark halo under every location icon (drawHaloIcon), in source cell px (128 a tile)
  static var HALO_BLUR = 3.0; // blur radius (6, three passes at 0.9 read too dark and too wide)
  static var HALO_PAD = 12; // canvas margin a side, room for the blur to spread
  static var HALO_PASSES = 2; // blurred copies stacked: one alone left a fringe too faint to read
  static var HALO_ALPHA = 0.5; // its opacity
  // the coloured disc under a lab, corp HQ or military base icon instead of the halo (drawDiscIcon),
  // lighter than the art on it so the silhouette reads
  static var DISC_LAB = '#d9a24a'; // yellow-orange
  static var DISC_CORP = '#4fb3cf'; // blue-cyan
  static var DISC_BASE = '#8aa85a'; // green
  static var DISC_RADIUS = 0.46; // share of the tile
  var lastPX: Int; // player tile and camera px at the last draw (-1: snap next draw)
  var lastPY: Int;
  var lastCamX: Int;
  var lastCamY: Int;
  var plFromX: Float; // player draw offset px at slide start
  var plFromY: Float;
  var camFromX: Float; // camera draw offset px at slide start
  var camFromY: Float;
  var slideStart: Float; // slide start timestamp, ms
  var revealStart: IntMap<Float>; // area id -> fade-in start timestamp, ms
  var ticking: Bool; // animation frame requested
  var markers: Array<RegionMarker>; // region-border markers, rebuilt per turn
  var tileMarks: IntMap<js.html.Image>; // the SVG timeline tile marks by ROW_REGION_ICON frame

  public var width: Int; // width, height in cells
  public var height: Int;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = 100; // should be larger than any region
      height = 100;
      path = null;
      haloCache = new IntMap();
      lastPX = -1;
      lastPY = lastCamX = lastCamY = 0;
      plFromX = plFromY = camFromX = camFromY = 0;
      slideStart = 0;
      revealStart = new IntMap();
      ticking = false;
      markers = [];
      tileMarks = new IntMap();
    }


// update tilemaps from current region
  public function update()
    {
      width = game.region.width;
      height = game.region.height;
      updateMarkers();

      scene.updateCamera(); // center camera on player
    }

// collect the region-border markers: timeline leads with notes still unknown, NPCs with unread
// memories, open cult missions and habitats. rebuilt per turn, projected on every draw
  function updateMarkers()
    {
      markers = [];
      function add(a: AreaGame, key: String, color: String, scale: Float)
        markers.push({
          x: a.x,
          y: a.y,
          key: key,
          color: color,
          scale: scale,
        });
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = cells[x][y];
            var ev = getEventIcon(a);
            if (ev != null &&
                ev.col == Const.FRAME_EVENT_UNKNOWN)
              add(a, 'regionlead', '#f7af46', 1);
            if (getNPCIcon(a) != null)
              add(a, 'regionnpc', '#f7af46', 1);
            if (drawAreaCultMission(a) != null)
              add(a, 'regionmission', '#fd97ff', 1);
            var hab = drawAreaHabitat(a);
            if (hab != null)
              add(a, 'regionhabitat',
                (hab.col == Const.FRAME_HABITAT_AMBUSHED ? '#ff5b45' : '#c9a8ef'), 1.25);
            if (getShipIcon(a) != null)
              add(a, 'regionship', '#92b9ff', 1.25);
          }
    }

// update alertness icon for this area
  function getAlertnessIcon(a: AreaGame): _Icon
    {
      // update alert icon
      if (!isKnown(a))
        return null;
      var frame = Const.FRAME_EMPTY;
      if (a.alertness > 75)
        frame = Const.FRAME_ALERT3;
      else if (a.alertness > 50)
        frame = Const.FRAME_ALERT2;
      else if (a.alertness > 0)
        frame = Const.FRAME_ALERT1;

      return { row: Const.ROW_ALERT, col: frame };
    }


// update event icon for this area
  function getEventIcon(a: AreaGame): _Icon
    {
      if (!game.player.vars.timelineEnabled ||
          a.events.length == 0)
        return null;

      // need at least one event with known location to show icon
      // need all notes for all events known to show the right icon
      var oneLocationKnown = false;
      var allNotesKnown = true;
      for (e in a.events)
        {
          if (e.locationKnown)
            oneLocationKnown = true;

          if (!e.notesKnown())
            allNotesKnown = false;
        }
      if (!oneLocationKnown)
        return null;

      var frame = Const.FRAME_EVENT_UNKNOWN;
      if (allNotesKnown)
        frame = Const.FRAME_EVENT_KNOWN;

      return { row: Const.ROW_REGION_ICON, col: frame };
    }


// update npc icon for this area
  function getNPCIcon(a: AreaGame): _Icon
    {
      if (!game.player.vars.timelineEnabled)
        return null;
      var len = 0;
      for (v in a.npc)
        len++;
      if (len == 0)
        return null;

      var ok = true;
      for (npc in a.npc)
        if (!npc.isDead && npc.areaKnown && !npc.memoryKnown)
          ok = false;
      if (ok)
        return null;

      return {
        row: Const.ROW_REGION_ICON,
        col: Const.FRAME_EVENT_NPC,
      };
    }

// clears visible path
  public function clearPath(?clearAll: Bool = false)
    {
      if (clearAll)
        game.playerRegion.clearPath();
      if (path == null)
        return;
      path = null;
      scene.draw();
    }

// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      path = [];
      var xx = x1;
      var yy = y1;
      var cnt = 0;
      while (cnt++ < 100)
        {
          var dx = 0;
          var dy = 0;
          if (x2 - xx > 0)
            dx = 1;
          else if (x2 - xx < 0)
            dx = -1;
          if (y2 - yy > 0)
            dy = 1;
          else if (y2 - yy < 0)
            dy = -1;
          xx += dx;
          yy += dy;
          if (xx == x2 && yy == y2)
            break;
          path.push({ x: xx, y: yy });
        }
      scene.draw();
    }


// show region view
// called twice in case player host dies on entering sewers
  public function show()
    {
      lastPX = -1; // entering the region snaps, never slides
      var ple = game.playerRegion.entity;
      // update player image and mask
      if (game.player.host != null)
        {
          var ai = game.player.host;
          ple.skinColor = ai.skinColor;
          ple.isMaleAtlas = ai.usesMaleAtlas();
          ple.setIcon(
            (ai.isMale ? 'male' : 'female'),
            ai.tileAtlasX,
            ai.tileAtlasY);
          ple.setMask(
            Const.FRAME_MASK_CONTROL);
        }
      else
        {
          ple.isMaleAtlas = false;
          ple.setIcon(
            'entities',
            Const.FRAME_PARASITE,
            Const.ROW_PARASITE);
          ple.setMask(-1);
        }
    }

// redraw region map
  public function draw()
    {
      var renderTS = scene.beginRenderSample();
      var ctx = scene.canvas.getContext('2d');
      var now = Browser.window.performance.now();
      updateSlide(now);
      var k = 1 - ease((now - slideStart) * render.RenderConfig.ANIM_SPEED /
        (render.RenderConfig.BASE_MS * SLIDE_MULT));
      ctx.save();
      ctx.translate(-scene.cameraSubX + camFromX * k, -scene.cameraSubY + camFromY * k);

      // ensure region map image exists
      if (game.region.regionMapImage == null)
        {
          game.region.regionMapImage = new Image(game);
          var t = haxe.Timer.stamp();
          trace('Region map image generation started');
          game.region.regionMapImage.generate();
          trace('Region map image generated in ' + Std.int((haxe.Timer.stamp() - t) * 1000) + ' ms');
        }

      // draw region map image (only visible portion)
      // (one extra tile on every side, so the slide offset never shows a bare edge)
      var visibleTilesW = scene.cameraTileX2 - scene.cameraTileX1 + 3;
      var visibleTilesH = scene.cameraTileY2 - scene.cameraTileY1 + 3;
      game.region.regionMapImage.drawTo(ctx,
        (scene.cameraTileX1 - 1) * Const.TILE_SIZE_CLEAN,
        (scene.cameraTileY1 - 1) * Const.TILE_SIZE_CLEAN,
        visibleTilesW * Const.TILE_SIZE_CLEAN,
        visibleTilesH * Const.TILE_SIZE_CLEAN,
        - Const.TILE_SIZE,
        - Const.TILE_SIZE,
        visibleTilesW * Const.TILE_SIZE,
        visibleTilesH * Const.TILE_SIZE);

      // draw area icons
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          drawArea(ctx, cells[x][y], now);

      // draw player at its slide offset
      ctx.save();
      ctx.translate(plFromX * k, plFromY * k);
      game.playerRegion.entity.draw(ctx);
      ctx.restore();

      // path
      if (path != null)
        for (pos in path)
          drawEntityCell(ctx, Const.FRAME_DOT, Const.ROW_PARASITE,
            (pos.x - scene.cameraTileX1) * Const.TILE_SIZE,
            (pos.y - scene.cameraTileY1) * Const.TILE_SIZE);
      ctx.restore();
      drawMarkers(camFromX * k, camFromY * k);
      scene.endRenderSampleRegion(renderTS);

      // keep redrawing while the slide or a reveal is still moving
      if (k > 0 ||
          revealStart.keys().hasNext())
        kick();
    }

// pin the off-screen markers to the screen edge (offX/offY: the camera slide offset, device px)
  function drawMarkers(offX: Float, offY: Float)
    {
      var hud = game.ui.hud.offscreen;
      var ts = Const.TILE_SIZE;
      var ratio = Browser.window.devicePixelRatio;
      hud.begin(true);
      for (m in markers)
        {
          var cx = (m.x * ts + ts / 2 - scene.cameraX + offX) / ratio;
          var cy = (m.y * ts + ts / 2 - scene.cameraY + offY) / ratio;
          if (cx >= 0 &&
              cx <= Viewport.w &&
              cy >= 0 &&
              cy <= Viewport.h)
            continue;
          hud.show(m.key, m.color, cx / Viewport.w * 2 - 1, 1 - cy / Viewport.h * 2, m.scale);
        }
      hud.end();
    }

// a move since the last draw starts a slide from where the player and camera were drawn; a jump
// (teleport, load, region entry, resize) snaps instead
  function updateSlide(now: Float)
    {
      var px = game.playerRegion.x;
      var py = game.playerRegion.y;
      if (px == lastPX &&
          py == lastPY &&
          scene.cameraX == lastCamX &&
          scene.cameraY == lastCamY)
        return;
      var tile = Const.TILE_SIZE;
      if (lastPX < 0 ||
          Math.abs(px - lastPX) > 1 ||
          Math.abs(py - lastPY) > 1 ||
          Math.abs(scene.cameraX - lastCamX) > 2 * tile ||
          Math.abs(scene.cameraY - lastCamY) > 2 * tile)
        plFromX = plFromY = camFromX = camFromY = 0;
      // fold what is left of the running slide into the new one, at most a tile and a half away
      else
        {
          var k = 1 - ease((now - slideStart) * render.RenderConfig.ANIM_SPEED /
            (render.RenderConfig.BASE_MS * SLIDE_MULT));
          plFromX = clampSlide(plFromX * k + (lastPX - px) * tile);
          plFromY = clampSlide(plFromY * k + (lastPY - py) * tile);
          camFromX = clampSlide(camFromX * k + (scene.cameraX - lastCamX));
          camFromY = clampSlide(camFromY * k + (scene.cameraY - lastCamY));
        }
      slideStart = now;
      lastPX = px;
      lastPY = py;
      lastCamX = scene.cameraX;
      lastCamY = scene.cameraY;
    }

// clamp one slide offset to a tile and a half (fast path steps would otherwise pile up)
  inline function clampSlide(v: Float): Float
    {
      var max = Const.TILE_SIZE * 1.5;
      return (v > max ? max : (v < - max ? - max : v));
    }

// smoothstep over 0..1, clamped
  inline function ease(t: Float): Float
    {
      if (t >= 1)
        return 1;
      if (t <= 0)
        return 0;
      return t * t * (3 - 2 * t);
    }

// request one animation frame redraw (draw re-requests while anything still moves)
  function kick()
    {
      if (ticking)
        return;
      ticking = true;
      Browser.window.requestAnimationFrame(function(_)
        {
          ticking = false;
          if (game.location == LOCATION_REGION)
            scene.draw();
        });
    }

// a tile just became known: fade its darkening out instead of popping it
  public function reveal(a: AreaGame)
    {
      revealStart.set(a.id, Browser.window.performance.now());
    }

// draw a facility's or a military base's own mark over its map tile: a facility's by its tile id
// (Const.TILE_FACILITY1 + 0-3, rolled at creation), a base's by its map position (its tile id only
// ever rolled two)
  function drawAreaTileOverlay(ctx: CanvasRenderingContext2D, area: AreaGame, ax: Int, ay: Int)
    {
      if (area.typeID == AREA_FACILITY)
        drawDiscIcon(ctx, Const.FRAME_FACILITY_MARK + area.tileID - Const.TILE_FACILITY1,
          Const.ROW_REGION_ICON, ax, ay, DISC_LAB);
      else if (area.typeID == AREA_MILITARY_BASE)
        drawDiscIcon(ctx, Const.FRAME_BASE_MARK + (area.x * 3 + area.y * 5) % 4,
          Const.ROW_REGION_ICON, ax, ay, DISC_BASE);
    }

// draw one alpha feather strip inside one unknown frontier tile
  function drawUnknownAreaFeather(ctx: CanvasRenderingContext2D,
      x: Float, y: Float, width: Float, height: Float,
      x1: Float, y1: Float, x2: Float, y2: Float, alpha: Float)
    {
      var gradient = ctx.createLinearGradient(x1, y1, x2, y2);
      gradient.addColorStop(0, 'rgba(0, 0, 0, ' + alpha + ')');
      gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = gradient;
      ctx.fillRect(x, y, width, height);
    }

// draw one unknown area tile with a softened frontier silhouette
  function drawUnknownAreaTile(ctx: CanvasRenderingContext2D,
      area: AreaGame, ax: Int, ay: Int)
    {
      var leftKnown = isAreaKnownAt(area.x - 1, area.y);
      var rightKnown = isAreaKnownAt(area.x + 1, area.y);
      var topKnown = isAreaKnownAt(area.x, area.y - 1);
      var bottomKnown = isAreaKnownAt(area.x, area.y + 1);

      ctx.save();
      ctx.fillStyle = '#111111';
      ctx.globalAlpha = 0.7;

      if (!leftKnown &&
          !rightKnown &&
          !topKnown &&
          !bottomKnown)
        {
          ctx.fillRect(ax, ay, Const.TILE_SIZE, Const.TILE_SIZE);
          ctx.restore();
          return;
        }

      var tile = Const.TILE_SIZE;
      var edgeInset = tile * 0.16;
      var cornerInset = tile * 0.10;
      var featherSize = tile * 0.20;
      var featherAlpha = 0.35;
      var x1 = ax;
      var y1 = ay;
      var x2 = ax + tile;
      var y2 = ay + tile;
      var midX = ax + tile / 2.0;
      var midY = ay + tile / 2.0;
      var topLeftX = x1 + (leftKnown ? cornerInset : 0.0);
      var topRightX = x2 - (rightKnown ? cornerInset : 0.0);
      var rightTopY = y1 + (topKnown ? cornerInset : 0.0);
      var rightBottomY = y2 - (bottomKnown ? cornerInset : 0.0);
      var bottomRightX = x2 - (rightKnown ? cornerInset : 0.0);
      var bottomLeftX = x1 + (leftKnown ? cornerInset : 0.0);
      var leftBottomY = y2 - (bottomKnown ? cornerInset : 0.0);
      var leftTopY = y1 + (topKnown ? cornerInset : 0.0);

      ctx.beginPath();
      ctx.moveTo(topLeftX, y1);
      if (topKnown)
        ctx.quadraticCurveTo(midX, y1 + edgeInset, topRightX, y1);
      else
        ctx.lineTo(topRightX, y1);
      ctx.lineTo(x2, rightTopY);
      if (rightKnown)
        ctx.quadraticCurveTo(x2 - edgeInset, midY, x2, rightBottomY);
      else
        ctx.lineTo(x2, rightBottomY);
      ctx.lineTo(bottomRightX, y2);
      if (bottomKnown)
        ctx.quadraticCurveTo(midX, y2 - edgeInset, bottomLeftX, y2);
      else
        ctx.lineTo(bottomLeftX, y2);
      ctx.lineTo(x1, leftBottomY);
      if (leftKnown)
        ctx.quadraticCurveTo(x1 + edgeInset, midY, x1, leftTopY);
      else
        ctx.lineTo(x1, leftTopY);
      ctx.closePath();
      ctx.fill();

      ctx.clip();
      untyped ctx.globalCompositeOperation = 'destination-out';
      if (topKnown)
        drawUnknownAreaFeather(ctx,
          ax,
          ay,
          tile,
          featherSize,
          ax,
          ay,
          ax,
          ay + featherSize,
          featherAlpha);
      if (rightKnown)
        drawUnknownAreaFeather(ctx,
          ax + tile - featherSize,
          ay,
          featherSize,
          tile,
          ax + tile,
          ay,
          ax + tile - featherSize,
          ay,
          featherAlpha);
      if (bottomKnown)
        drawUnknownAreaFeather(ctx,
          ax,
          ay + tile - featherSize,
          tile,
          featherSize,
          ax,
          ay + tile,
          ax,
          ay + tile - featherSize,
          featherAlpha);
      if (leftKnown)
        drawUnknownAreaFeather(ctx,
          ax,
          ay,
          featherSize,
          tile,
          ax,
          ay,
          ax + featherSize,
          ay,
          featherAlpha);
      ctx.restore();
    }

// return whether one region coordinate is currently known
  function isAreaKnownAt(x: Int, y: Int): Bool
    {
      var area = game.region.getXY(x, y);
      return area != null && isKnown(area);
    }

// paint area icons on top of the region map image
  function drawArea(ctx: CanvasRenderingContext2D, area: AreaGame, now: Float)
    {
      // area not visible
      if (area.x < scene.cameraTileX1 - 1 ||
          area.y < scene.cameraTileY1 - 1 ||
          area.x > scene.cameraTileX2 + 2 ||
          area.y > scene.cameraTileY2 + 2)
        return;
      var ax =
        (area.x - scene.cameraTileX1) * Const.TILE_SIZE;
      var ay =
        (area.y - scene.cameraTileY1) * Const.TILE_SIZE;

      // unknown areas are hidden, draw darkened tile
      if (!isKnown(area))
        {
          drawUnknownAreaTile(ctx, area, ax, ay);
          // still surface timeline intel known independent of area exploration
          drawIcon(ctx, getEventIcon(area), ax, ay, false);
          drawIcon(ctx, getNPCIcon(area), ax, ay, false);
          return;
        }

      drawAreaTileOverlay(ctx, area, ax, ay);

      // high crime marker
      if (area.highCrime)
        {
          drawHaloIcon(ctx, Const.FRAME_HIGH_CRIME, Const.ROW_ALERT, ax, ay, 0.85);
        }

      // area icons
      for (i in 0...7)
        {
          var icon = null;
          switch (i)
            {
              // region object (under all other icons)
              case 0:
                var o = game.region.getObjectAt(area.x, area.y);
                if (o != null && area.isKnown)
                  icon = o.icon;
              // alertness
              case 1:
                icon = getAlertnessIcon(area);
              // event
              case 2:
                icon = getEventIcon(area);
              // npc
              case 3:
                icon = getNPCIcon(area);
              // habitat
              case 4:
                icon = drawAreaHabitat(area);
              // cult mission
              case 5:
                icon = drawAreaCultMission(area);
              // crashed spaceship
              case 6:
                icon = getShipIcon(area);
            }
          // the location icons (region object, habitat, cult mission) sit on a halo, the marks do not
          drawIcon(ctx, icon, ax, ay, i == 0 || i == 4 || i == 5);
        }

      // just revealed: the darkening fades out over the whole tile
      if (!revealStart.exists(area.id))
        return;
      var t = (now - revealStart.get(area.id)) * render.RenderConfig.ANIM_SPEED /
        (render.RenderConfig.BASE_MS * REVEAL_MULT);
      if (t >= 1)
        {
          revealStart.remove(area.id);
          return;
        }
      ctx.save();
      ctx.fillStyle = '#111111';
      ctx.globalAlpha = 0.7 * (1 - ease(t));
      ctx.fillRect(ax, ay, Const.TILE_SIZE, Const.TILE_SIZE);
      ctx.restore();
    }

// draw one area icon: a timeline mark from its SVG, the rest from the entities sprite sheet, a
// location icon over its halo
  function drawIcon(ctx: CanvasRenderingContext2D, icon: _Icon, ax: Int, ay: Int, halo: Bool)
    {
      if (icon == null)
        return;
      var mark = tileMark(icon);
      if (mark != null)
        {
          if (mark.complete)
            ctx.drawImage(mark, ax, ay, Const.TILE_SIZE, Const.TILE_SIZE);
          return;
        }
      if (halo &&
          icon.row == Const.ROW_REGION_ICON &&
          Const.FRAME_CORPHQ_VARIANTS.indexOf(icon.col) >= 0)
        drawDiscIcon(ctx, icon.col, icon.row, ax, ay, DISC_CORP);
      else if (halo)
        drawHaloIcon(ctx, icon.col, icon.row, ax, ay, 1.0);
      else drawEntityCell(ctx, icon.col, icon.row, ax, ay);
    }

// draw one entities frame at a map spot, off whichever sheet holds its pixels now
// (render.particles.Sprites.atlasFor); nothing until that image decodes
  function drawEntityCell(ctx: CanvasRenderingContext2D, col: Int, row: Int, ax: Float, ay: Float)
    {
      var src = Sprites.atlasFor(scene.images, 'entities', col, row, false, 0);
      if (src.img == null ||
          src.img.naturalWidth <= 0)
        return;
      ctx.drawImage(src.img,
        src.ix * src.t,
        src.iy * src.t,
        src.t,
        src.t,
        ax,
        ay,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
    }

// the timeline tile marks (lead, finished lead, NPC) as full-tile images built from SVG, each where
// the sheet's flat disc sat; null for every other frame. the first draw starts the decode and the
// load redraws the map
  function tileMark(icon: _Icon): js.html.Image
    {
      if (icon.row != Const.ROW_REGION_ICON)
        return null;
      var img = tileMarks.get(icon.col);
      if (img != null)
        return img;
      var svg = null;
      if (icon.col == Const.FRAME_EVENT_UNKNOWN)
        svg = tileMarkSvg(32, 31, 15, '#f7af46', ui.UISvg.regionLead());
      else if (icon.col == Const.FRAME_EVENT_KNOWN)
        svg = tileMarkSvg(32, 31, 15, '#9aa0aa', ui.UISvg.regionLeadDone());
      else if (icon.col == Const.FRAME_EVENT_NPC)
        svg = tileMarkSvg(14, 14, 12, '#f7af46', ui.UISvg.regionNPC());
      else if (icon.col == Const.FRAME_SPACESHIP)
        svg = tileMarkSvg(32, 32, 19, '#92b9ff', ui.UISvg.regionShip()); // 25% over a lead, like the habitat
      else return null;
      img = new js.html.Image();
      img.onload = function() scene.draw();
      img.src = 'data:image/svg+xml;charset=utf-8,' + StringTools.urlEncode(svg);
      tileMarks.set(icon.col, img);
      return img;
    }

// one tile mark on the 64 px tile grid: a glass disc ringed in its colour around a UISvg glyph,
// rasterised at 2x so a raised map scale stays sharp
  static function tileMarkSvg(cx: Float, cy: Float, r: Float, color: String, glyph: String): String
    {
      var g = r * 1.45;
      return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64" color="' + color + '">' +
        '<circle cx="' + cx + '" cy="' + cy + '" r="' + r + '" fill="rgba(12,14,20,0.82)" stroke="currentColor" stroke-width="2"/>' +
        StringTools.replace(glyph, '<svg ',
          '<svg x="' + (cx - g / 2) + '" y="' + (cy - g / 2) + '" width="' + g + '" height="' + g + '" ') +
        '</svg>';
    }

// draw one entity icon over a flat disc of its kind's colour, ringed darker so it holds on a light tile
  function drawDiscIcon(ctx: CanvasRenderingContext2D, col: Int, row: Int,
      ax: Float, ay: Float, color: String)
    {
      var r = Const.TILE_SIZE * DISC_RADIUS;
      ctx.beginPath();
      ctx.arc(ax + Const.TILE_SIZE / 2, ay + Const.TILE_SIZE / 2, r, 0, 2 * Math.PI);
      ctx.fillStyle = color;
      ctx.fill();
      ctx.lineWidth = Const.TILE_SIZE / 32;
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.45)';
      ctx.stroke();
      drawEntityCell(ctx, col, row, ax, ay);
    }

// draw one entity icon over its soft dark halo (getHaloCanvas), both at alpha
  function drawHaloIcon(ctx: CanvasRenderingContext2D, col: Int, row: Int,
      ax: Float, ay: Float, alpha: Float)
    {
      var halo = getHaloCanvas(col, row);
      if (halo != null)
        {
          // the halo canvas is the cell plus HALO_PAD a side, scaled like the cell to the tile
          var k = Const.TILE_SIZE / (halo.width - 2 * HALO_PAD);
          ctx.globalAlpha = HALO_ALPHA * alpha;
          ctx.drawImage(halo,
            ax - HALO_PAD * k,
            ay - HALO_PAD * k,
            halo.width * k,
            halo.height * k);
        }
      ctx.globalAlpha = alpha;
      drawEntityCell(ctx, col, row, ax, ay);
      ctx.globalAlpha = 1.0;
    }

// return one cached soft dark halo for an entity icon: its silhouette blurred onto a canvas HALO_PAD
// bigger on every side, at its source sheet's cell size; null until that sheet decodes (caching an
// empty canvas would lose the halo for the session)
  function getHaloCanvas(col: Int, row: Int): CanvasElement
    {
      var key = (row << 16) | col;
      var halo = haloCache.get(key);
      if (halo != null)
        return halo;
      var src = Sprites.atlasFor(scene.images, 'entities', col, row, false, 0);
      if (src.img == null ||
          src.img.naturalWidth <= 0)
        return null;

      var t = src.t;
      halo = Browser.document.createCanvasElement();
      halo.width = t + 2 * HALO_PAD;
      halo.height = t + 2 * HALO_PAD;
      var hctx = halo.getContext2d();
      // the sprite blurred and stacked (each copy lifts the soft edge, a + a(1 - a)), then every pixel
      // it reached turned black at its own alpha
      hctx.filter = 'blur(' + HALO_BLUR + 'px)';
      for (_ in 0...HALO_PASSES)
        hctx.drawImage(src.img,
          src.ix * t,
          src.iy * t,
          t,
          t,
          HALO_PAD,
          HALO_PAD,
          t,
          t);
      hctx.filter = 'none';
      hctx.globalCompositeOperation = 'source-in';
      hctx.fillStyle = '#000000';
      hctx.fillRect(0, 0, halo.width, halo.height);

      haloCache.set(key, halo);
      return halo;
    }

// hide gui
  public function hide()
    {
      // clear path
      clearPath();
      // the border markers would otherwise sit over the transition fade
      game.ui.hud.offscreen.clear();
    }


// returns whether this tile is known to the player
  public inline function isKnown(a: AreaGame): Bool
    {
      return
        ((Math.abs(game.playerRegion.x - a.x) < 2 &&
          Math.abs(game.playerRegion.y - a.y) < 2) || a.isKnown);
    }

  // draw cult mission icon for area
  function drawAreaCultMission(area: AreaGame): { row: Int, col: Int }
    {
      // check if cult is active
      if (game.cults[0].state != CULT_STATE_ACTIVE)
        return null;
      var mission = game.cults[0].ordeals.getMarkerMission(area);
      if (mission != null)
        return {
          row: Const.ROW_REGION_ICON,
          col: Const.FRAME_CULT_MISSION,
        };
      return null;
    }

// the crashed spaceship's tile mark, on the wilderness area it hides in (GoalsAlienCrashLanding
// repaints that area's tileID)
  function getShipIcon(area: AreaGame): _Icon
    {
      if (area.tileID != Const.TILE_SPACESHIP)
        return null;
      return {
        row: Const.ROW_REGION_ICON,
        col: Const.FRAME_SPACESHIP,
      };
    }

  // draw habitat icon for area
  function drawAreaHabitat(area: AreaGame): { row: Int, col: Int }
    {
      // check if area has habitat
      if (!area.hasHabitat)
        return null;

      var icon = {
        row: Const.ROW_REGION_ICON,
        col: Const.FRAME_HABITAT,
      };

      // check for ambushed habitat
      var team = game.group.team;
      if (team == null)
        return icon;
      var hab = team.ambushedHabitat;
      if (hab != null &&
          hab.hasWatcher &&
          hab.area.id == area.habitatAreaID)
        icon.col = Const.FRAME_HABITAT_AMBUSHED;

      return icon;
    }
}

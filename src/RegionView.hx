// tiled region view (each tile corresponds to an area)

import haxe.ds.IntMap;
import js.html.CanvasRenderingContext2D;
import js.html.CanvasElement;
import js.Browser;
import game.*;
import tiles.Tileset;
import map.Image;

class RegionView
{
  var game: Game; // game state link
  var scene: GameScene; // scene link

  var path: Array<{ x: Int, y: Int }>; // currently visible path
  var outlinedEntityIconCache: IntMap<CanvasElement>; // cached black silhouette icons

  public var width: Int; // width, height in cells
  public var height: Int;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = 100; // should be larger than any region
      height = 100;
      path = null;
      outlinedEntityIconCache = new IntMap();
    }


// update tilemaps from current region
  public function update()
    {
      width = game.region.width;
      height = game.region.height;

      scene.updateCamera(); // center camera on player
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
      if (path == null)
        return;
      if (clearAll)
        game.playerRegion.clearPath();
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
      var ple = game.playerRegion.entity;
      // update player image and mask
      if (game.player.host != null)
        {
          var ai = game.player.host;
          ple.setIcon(
            (ai.isMale ? 'male' : 'female'),
            ai.tileAtlasX,
            ai.tileAtlasY);
          ple.setMask(
            Const.FRAME_MASK_CONTROL);
        }
      else
        {
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
      ctx.save();
      ctx.translate(-scene.cameraSubX, -scene.cameraSubY);

      // ensure region map image exists
      if (game.region.regionMapImage == null)
        {
          game.region.regionMapImage = new Image(game);
          var t = Sys.time();
          trace('Region map image generation started');
          game.region.regionMapImage.generate();
          trace('Region map image generated in ' + Std.int((Sys.time() - t) * 1000) + ' ms');
        }

      // draw region map image (only visible portion)
      var visibleTilesW = scene.cameraTileX2 - scene.cameraTileX1 + 1;
      var visibleTilesH = scene.cameraTileY2 - scene.cameraTileY1 + 1;
      game.region.regionMapImage.drawTo(ctx,
        scene.cameraTileX1 * Const.TILE_SIZE_CLEAN,
        scene.cameraTileY1 * Const.TILE_SIZE_CLEAN,
        visibleTilesW * Const.TILE_SIZE_CLEAN,
        visibleTilesH * Const.TILE_SIZE_CLEAN,
        0,
        0,
        visibleTilesW * Const.TILE_SIZE,
        visibleTilesH * Const.TILE_SIZE);

      // draw area icons
      var tileset = scene.images.getDefaultTileset();
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          drawArea(ctx, cells[x][y], tileset);

      // draw player
      game.playerRegion.entity.draw(ctx);

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
      ctx.restore();
      scene.endRenderSampleRegion(renderTS);
    }

// draw one special area tile on top of the region map image
  function drawAreaTileOverlay(ctx: CanvasRenderingContext2D,
      area: AreaGame, tileset: Tileset, ax: Int, ay: Int)
    {
      if (area.typeID != AREA_MILITARY_BASE &&
          area.typeID != AREA_FACILITY)
        return;

      var icon = tileset.getIcon(area.tileID);
      untyped ctx.imageSmoothingEnabled = false;
      tileset.draw(ctx, icon, ax, ay);
      untyped ctx.imageSmoothingEnabled = true;
    }

// paint area icons on top of the region map image
  function drawArea(ctx: CanvasRenderingContext2D, area: AreaGame, tileset: Tileset)
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
          ctx.fillStyle = '#111111';
          ctx.globalAlpha = 0.7;
          ctx.fillRect(ax, ay, Const.TILE_SIZE, Const.TILE_SIZE);
          ctx.globalAlpha = 1.0;
          return;
        }

      drawAreaTileOverlay(ctx, area, tileset, ax, ay);

      // high crime marker
      if (area.highCrime)
        {
          drawOutlinedEntityIcon(ctx, Const.FRAME_HIGH_CRIME, Const.ROW_ALERT, ax, ay, 0.85);
        }

      // area icons
      for (i in 0...6)
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
            }
          if (icon == null)
            continue;
          ctx.drawImage(scene.images.entities,
            icon.col * Const.TILE_SIZE_CLEAN, 
            icon.row * Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            ax, ay,
            Const.TILE_SIZE,
            Const.TILE_SIZE);
        }
    }

// draw one entity icon with a small black outline
  function drawOutlinedEntityIcon(ctx: CanvasRenderingContext2D, col: Int, row: Int,
      ax: Int, ay: Int, alpha: Float)
    {
      var iconCanvas = getOutlinedEntityIconCanvas(col, row);
      var outlineOffset = 0.5;

      ctx.globalAlpha = alpha * 0.75;
      ctx.drawImage(iconCanvas,
        0,
        0,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax - outlineOffset,
        ay,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
      ctx.drawImage(iconCanvas,
        0,
        0,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax + outlineOffset,
        ay,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
      ctx.drawImage(iconCanvas,
        0,
        0,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax,
        ay - outlineOffset,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
      ctx.drawImage(iconCanvas,
        0,
        0,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax,
        ay + outlineOffset,
        Const.TILE_SIZE,
        Const.TILE_SIZE);

// draw the original icon on top of the outline
      ctx.globalAlpha = alpha;
      ctx.drawImage(scene.images.entities,
        col * Const.TILE_SIZE_CLEAN,
        row * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax,
        ay,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
      ctx.globalAlpha = 1.0;
    }

// return one cached black silhouette for an entity icon
  function getOutlinedEntityIconCanvas(col: Int, row: Int): CanvasElement
    {
      var key = (row << 16) | col;
      var iconCanvas = outlinedEntityIconCache.get(key);
      if (iconCanvas != null)
        return iconCanvas;

      iconCanvas = Browser.document.createCanvasElement();
      iconCanvas.width = Const.TILE_SIZE_CLEAN;
      iconCanvas.height = Const.TILE_SIZE_CLEAN;
      var iconCtx = iconCanvas.getContext('2d');

// draw the source sprite into a temporary canvas
      iconCtx.drawImage(scene.images.entities,
        col * Const.TILE_SIZE_CLEAN,
        row * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        0,
        0,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN);

// convert the sprite silhouette into a black outline source
      untyped iconCtx.globalCompositeOperation = 'source-in';
      iconCtx.fillStyle = '#000000';
      iconCtx.fillRect(0, 0, Const.TILE_SIZE_CLEAN, Const.TILE_SIZE_CLEAN);
      untyped iconCtx.globalCompositeOperation = 'source-over';

      outlinedEntityIconCache.set(key, iconCanvas);
      return iconCanvas;
    }

// hide gui
  public function hide()
    {
      // clear path
      clearPath();
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

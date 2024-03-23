// tiled region view (each tile corresponds to an area)

import js.html.CanvasRenderingContext2D;
import h2d.Bitmap;
import game.*;

class RegionView
{
  var game: Game; // game state link
  var scene: GameScene; // scene link

  var _path: Array<Bitmap>; // currently visible path

  public var width: Int; // width, height in cells
  public var height: Int;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = 100; // should be larger than any region
      height = 100;

      _path = null;
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
      if (_path == null)
        return;
      for (dot in _path)
        dot.remove();

      if (clearAll)
        game.playerRegion.clearPath();
      _path = null;
    }

// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      clearPath();
      _path = [];
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

          var dot = new Bitmap(scene.entityAtlas
            [Const.FRAME_DOT][Const.ROW_PARASITE]);
          dot.x = xx * Const.TILE_SIZE - scene.cameraX;
          dot.y = yy * Const.TILE_SIZE - scene.cameraY;
          scene.add(dot, Const.LAYER_DOT);
          _path.push(dot);
        }
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
      var ctx = scene.canvas.getContext('2d');

      // draw area tiles and icons
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          drawArea(ctx, cells[x][y]);

      // draw player
      game.playerRegion.entity.draw(ctx);
    }

// paint area tile and icons
  function drawArea(ctx: CanvasRenderingContext2D, area: AreaGame)
    {
      // area not visible
      if (area.x < scene.cameraTileX1 - 1 ||
          area.y < scene.cameraTileY1 - 1 ||
          area.x > scene.cameraTileX2 + 2 ||
          area.y > scene.cameraTileY2 + 2)
        return;
      var ax =
        (area.x * Const.TILE_SIZE_CLEAN - scene.cameraX) * game.config.mapScale;
      var ay =
        (area.y * Const.TILE_SIZE_CLEAN - scene.cameraY) * game.config.mapScale;

      // area tile
      var tileID = (isKnown(area) ? area.tileID : Const.TILE_HIDDEN);
      var icon = {
        row: Std.int(tileID / 16),
        col: tileID % 16,
      };
      ctx.drawImage(scene.images.tileset,
        icon.col * Const.TILE_SIZE_CLEAN, 
        icon.row * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        ax, ay,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN);

      // area icons
      for (i in 0...5)
        {
          var icon = null;
          switch (i)
            {
              // alertness
              case 0:
                icon = getAlertnessIcon(area);
              // event
              case 1:
                icon = getEventIcon(area);
              // npc
              case 2:
                icon = getNPCIcon(area);
              // habitat
              case 3:
                if (!area.hasHabitat)
                  continue;
                icon = {
                  row: Const.ROW_REGION_ICON,
                  col: Const.FRAME_HABITAT,
                };
                var team = game.group.team;
                if (team != null)
                  {
                    var hab = team.ambushedHabitat;
                    if (hab != null &&
                        hab.hasWatcher &&
                        hab.area.id == area.habitatAreaID)
                      icon.col = Const.FRAME_HABITAT_AMBUSHED;
                  }
              // ovum
              case 4:
                var o = game.region.getObjectAt(area.x, area.y);
                if (o != null && o.type == 'ovum')
                  icon = {
                    row: Const.ROW_REGION_ICON,
                    col: Const.FRAME_OVUM,
                  };
            }
          if (icon == null)
            continue;
          ctx.drawImage(scene.images.entities,
            icon.col * Const.TILE_SIZE_CLEAN, 
            icon.row * Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            ax, ay,
            Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN);
        }
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
}

typedef _Icon = { row: Int, col: Int };


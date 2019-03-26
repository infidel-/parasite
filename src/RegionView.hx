// tiled region view (each tile corresponds to an area)

import h2d.Bitmap;
import h2d.TileGroup;
import h2d.Object;
import game.*;
import entities.RegionEntity;

class RegionView
{
  var game: Game; // game state link
  var scene: GameScene; // scene link

  var _tilemap: TileGroup;
  var _path: Array<Bitmap>; // currently visible path
  public var icons: Object; // all region icons container

  public var width: Int; // width, height in cells
  public var height: Int;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = 100; // should be larger than any region
      height = 100;

      _tilemap = new TileGroup(scene.tileAtlas[Const.TILE_REGION_GROUND]);
      scene.add(_tilemap, Const.LAYER_TILES);
      _tilemap.blendMode = None;
      _path = null;

      icons = new Object();
      scene.add(icons, Const.LAYER_OBJECT);
    }


// update tilemaps from current region
  static var ICON_ALERTNESS = 0;
  static var ICON_EVENT = 1;
  static var ICON_NPC = 2;
  static var ICON_HABITAT = 3;
  public function update()
    {
      width = game.region.width;
      height = game.region.height;

      trace('update');

      // set tiles
      // TODO: redoing all tiles on each turn is probably slow...
      _tilemap.clear();
      var cells = game.region.getCells();
      var tileID = 0;
      var row = 0;
      var a = null;
      for (y in 0...height)
        for (x in 0...width)
          {
            a = cells[x][y];

            tileID = Const.TILE_HIDDEN;
            if (isKnown(a))
              tileID = a.tileID;

            // update tile
            _tilemap.add(x * Const.TILE_SIZE, y * Const.TILE_SIZE,
              scene.tileAtlas[tileID]);

            // update icons
            updateIconsArea(a.x, a.y);
          }

      trace('RegionView.update updateCamera()');
      scene.updateCamera(); // center camera on player
    }


// update icons on this area
  public function updateIconsArea(x: Int, y: Int)
    {
      var a = game.region.getXY(x, y);

      var icon = getAlertnessIcon(a);
      setAreaIcon(a, ICON_ALERTNESS, icon);
      icon = getEventIcon(a);
      setAreaIcon(a, ICON_EVENT, icon);
      icon = getNPCIcon(a);
      setAreaIcon(a, ICON_NPC, icon);

      icon = {
        row: Const.ROW_REGION_ICON,
        col: (a.hasHabitat ? Const.FRAME_HABITAT : Const.FRAME_EMPTY)
      };
      setAreaIcon(a, ICON_HABITAT, icon);
    }


// update camera
  public function updateCamera(x: Int, y: Int)
    {
      _tilemap.x = - x;
      _tilemap.y = - y;
      icons.x = - x;
      icons.y = - y;
    }


// set a given area icon
  function setAreaIcon(a: AreaGame, idx: Int, icon: _Icon)
    {
      if (icon == null)
        return;

      if (icon.col > 0)
        {
          if (a.icons[idx] == null)
            a.icons[idx] =
              new RegionEntity(scene, a.x, a.y, icon.row, icon.col);
          else a.icons[idx].setImage(icon.col);
        }
      else if (a.icons[idx] != null)
        {
          a.icons[idx].remove();
          a.icons[idx] = null;
        }
    }


// update alertness icon for this area
  function getAlertnessIcon(a: AreaGame): _Icon
    {
      // update alert icon
      var frame = Const.FRAME_EMPTY;
      if (isKnown(a))
        {
          if (a.alertness > 75)
            frame = Const.FRAME_ALERT3;
          else if (a.alertness > 50)
            frame = Const.FRAME_ALERT2;
          else if (a.alertness > 0)
            frame = Const.FRAME_ALERT1;
        }

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
      if (!game.player.vars.timelineEnabled || a.npc.length == 0)
        return null;

      var ok = true;
      for (npc in a.npc)
        if (!npc.isDead && npc.areaKnown && !npc.memoryKnown)
          ok = false;

      return {
        row: Const.ROW_REGION_ICON,
        col: (ok ? Const.FRAME_EMPTY : Const.FRAME_EVENT_NPC)
      };
    }


// clear icons (needed on game restart)
  public function clearIcons()
    {
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          {
            if (cells[x] == null || cells[x][y] == null)
              continue;

            for (e in cells[x][y].icons)
              if (e != null)
                e.remove();
          }
    }


// update icons
  public inline function updateIcons()
    {
      for (y in 0...height)
        for (x in 0...width)
          updateIconsArea(x, y);
    }


// clears visible path
  public function clearPath()
    {
      if (_path == null)
        return;
      for (dot in _path)
        dot.remove();

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

          var dot = new Bitmap(game.scene.entityAtlas
            [Const.FRAME_DOT][Const.ROW_PARASITE]);
          dot.x = xx * Const.TILE_SIZE - game.scene.cameraX;
          dot.y = yy * Const.TILE_SIZE - game.scene.cameraY;
          game.scene.add(dot, Const.LAYER_DOT);
          _path.push(dot);
        }
    }


// show region view
  public function show()
    {
      // update player image and mask
      if (game.player.host != null)
        {
          game.playerRegion.entity.tile = game.player.host.tile;
          game.playerRegion.entity.setMask(game.scene.entityAtlas
            [Const.FRAME_MASK_CONTROL][Const.ROW_PARASITE]);
        }
      else
        {
          game.playerRegion.entity.tile = 
            game.scene.entityAtlas
              [Const.FRAME_PARASITE][Const.ROW_PARASITE];
        }

      // make all visible
      _tilemap.visible = true;
      game.playerRegion.entity.visible = true;
      icons.visible = true;
    }


// hide gui
  public function hide()
    {
      _tilemap.visible = false;
      icons.visible = false;
      game.playerRegion.entity.visible = false;

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


// tiled area view

import h2d.Bitmap;
import h2d.TileGroup;
import entities.EffectEntity;
import game.Game;

class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene

  var _tilemap: TileGroup;
  var _effects: List<EffectEntity>; // visual effects list
  var _cache: Array<Array<Int>>; // currently drawn tiles
  var _path: Array<Bitmap>; // currently visible path

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  static var maxSize = 120;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;

      // init tiles cache 
      _cache = [];
      for (i in 0...width)
        _cache[i] = [];
      for (y in 0...height)
        for (x in 0...width)
          _cache[x][y] = 0;

      _path = null;
      _effects = new List<EffectEntity>();
      _tilemap = new TileGroup(scene.tileAtlas[Const.TILE_GROUND]);
      scene.add(_tilemap, Const.LAYER_TILES);
    }


// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;

      _tilemap.clear(); // clear all tiles left over from last entry
      scene.updateCamera(); // center camera on player
    }


// update camera
  public function updateCamera(x: Int, y: Int)
    {
      _tilemap.x = - x;
      _tilemap.y = - y;

      // adjust all entity positions
      for (ai in game.area.getAllAI())
        ai.entity.setPosition(ai.x, ai.y);
      for (obj in game.area.getObjects())
        {
          obj.entity.setPosition(obj.x, obj.y);
          // hide objects outside of parasite vision
          if (game.player.state != PLR_STATE_HOST)
            {
              if (!obj.sensable() &&
                  Const.distanceSquared(
                    game.playerArea.x, game.playerArea.y,
                    obj.x, obj.y) > 2)
                obj.entity.visible = false;
              else obj.entity.visible = true;
            }
          // host vision
          else obj.entity.visible = isVisible(obj.x, obj.y);
        }
      for (e in _effects)
        e.setPosition(e.x, e.y);
    }


// clears visible path
  public function clearPath(?clearAll: Bool = false)
    {
      if (_path == null)
        return;
      for (dot in _path)
        dot.remove();

      if (clearAll)
        game.playerArea.clearPath();
      _path = null;
    }


// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      clearPath();
      _path = [];
      var path = game.area.getPath(x1, y1, x2, y2);
      if (path == null)
        return;
      path.pop();
      for (pos in path)
        {
          var dot = new Bitmap(game.scene.entityAtlas
            [Const.FRAME_DOT][Const.ROW_PARASITE]);
          dot.x = pos.x * Const.TILE_SIZE - game.scene.cameraX;
          dot.y = pos.y * Const.TILE_SIZE - game.scene.cameraY;
          game.scene.add(dot, Const.LAYER_DOT);
          _path.push(dot);
        }
    }


// show gui
  public function show()
    {
      _tilemap.visible = true;
      if (game.player.state != PLR_STATE_HOST)
        game.playerArea.entity.visible = true;
    }


// hide gui
  public function hide()
    {
      _tilemap.visible = false;
      game.playerArea.entity.visible = false;

      // clear all effects
      for (eff in _effects)
        {
          eff.remove();
          _effects.remove(eff);
        }

      // clear path
      clearPath();
    }


// add visual effect entity
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int)
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return;

      var effect = new EffectEntity(game, x, y, turns, Const.ROW_EFFECT, frame);
      _effects.add(effect);
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();
    }


// update visible area
// host version
  function updateVisibilityHost()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      emptyScreenCells = 0;
      _tilemap.clear();
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
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
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
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
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
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
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
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }
        }
    }

// set tile at x,y
  function setTile(x: Int, y: Int, tileID: Int)
    {
      _tilemap.add(x * Const.TILE_SIZE,
        y * Const.TILE_SIZE, scene.tileAtlas[tileID]);
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
      _tilemap.clear();
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

            _tilemap.add(x * Const.TILE_SIZE, y * Const.TILE_SIZE,
              scene.tileAtlas[tileID]);
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
          e.turns--;
          if (e.turns <= 0)
            {
              e.remove();
              _effects.remove(e);
            }
        }
    }
}

// tiled world map grid

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;


class MapGrid
{
  var game: Game; // game state link

  var _tilemap: Tilemap;
  var _ai: List<AI>;
  var _objects: List<GridObject>;
  var _cells: Array<Array<Int>>; // cell types
  public var width: Int; // map width, height in cells
  public var height: Int;
  public var entity: Entity; // map entity

  public function new (g: Game, tileset: Dynamic, w: Int, h: Int)
    {
      game = g;
      entity = new Entity();
      entity.layer = Const.LAYER_TILES;
      width = w;
      height = h;

      _ai = new List<AI>();
      _objects = new List<GridObject>();
      _tilemap = new Tilemap(tileset, 
        w * Const.TILE_WIDTH, h * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);
    }


// generate a new map
  public function generate()
    {
      _cells = new Array<Array<Int>>();
      for (i in 0...width)
        _cells[i] = [];

      // clear map
      for (y in 0...width)
        for (x in 0...height)
          setType(x, y, Const.TILE_GROUND);

      generateBuildings();
      generateAI();
    }


// generate buildings
  function generateBuildings()
    {
      // buildings
      for (y in 0...height)
        for (x in 0...width)
          {
            if (Math.random() > 0.05)
              continue;

            // size
            var sx = 5 + Std.int(Math.random() * 10);
            var sy = 5 + Std.int(Math.random() * 10);

//            var cell = get(x,y);

            // check for adjacent buildings
            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  //var cell = get(x + dx, y + dy);
                  var cellType = getType(x + dx, y + dy);
                  if (cellType == "building")
                    {
                      ok = false;
                      break;
                    }
                }

            if (!ok)
              continue;
  
            // draw a building rect
            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = getType(x + dx, y + dy);
                  if (cellType == null)
                    continue;

                  setType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate AI
  function generateAI()
    {
      var maxHumans = Std.int(0.01 * width * height);
      for (i in 0...maxHumans)
        {
          // find empty spot for new ai
          var loc = findEmptyLocation();

          // spawn new ai
          var ai = new HumanAI(game, loc.x, loc.y);
          _ai.add(ai);
          ai.createEntity();
        }

      var maxDogs = Std.int(0.0025 * width * height);
      for (i in 0...maxDogs)
        {
          // find empty spot for new ai
          var loc = findEmptyLocation();

          // spawn new ai
          var ai = new DogAI(game, loc.x, loc.y);
          _ai.add(ai);
          ai.createEntity();
        }
    }


// create object with this type
  public function createObject(x: Int, y: Int, type: String, parentType: String)
    {
      var o = new GridObject(game, x, y);
      o.type = type;
      o.createEntity(parentType);
      _objects.add(o);
    }


// find empty location on map (to spawn stuff)
  public function findEmptyLocation(): { x: Int, y: Int }
    {
      var x = -1;
      var y = -1;
      var cnt = 0;
      while (true)
        {
          cnt++;
          if (cnt > 100)
            {
              trace('could not find empty spot!');
              return { x: 0, y: 0 };
            }

          x = Std.random(width);
          y = Std.random(height);
          if (getType(x, y) != 'ground')
            continue;

          if (getAI(x, y) != null)
            continue;

          break;
        }

      return { x: x, y: y };
    }


// get cell type of this cell
  public function getType(x: Int, y: Int): String
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return null;
      return Const.TILE_TYPE[_cells[x][y]];

//      var index = _tilemap.getTile(x, y);
//      return Const.TILE_TYPE[index];
    }


// does this cell has ai?
  public function hasAI(x: Int, y: Int): Bool
    {
      for (ai in _ai)
        if (ai.x == x && ai.y == y)
          return true;

      return false;
    }


// get ai on this cell
  public function getAI(x: Int, y: Int): AI
    {
      for (ai in _ai)
        if (ai.x == x && ai.y == y)
          return ai;

      return null;
    }


// set cell type 
  inline function setType(x: Int, y: Int, index: Int)
    {
      _tilemap.setTile(x, y, index);
      _cells[x][y] = index;
    }


// check if tile is walkable
  public function isWalkable(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;
    
//      trace(x + ' ' + y + ' ' + _isWalkable[x][y]);
      return Const.TILE_WALKABLE[_cells[x][y]];
    }


// check if x1, y1 sees x2, y2
// bresenham copied from wikipedia with one slight modification
  public function isVisible(x1: Int, y1: Int, x2: Int, y2: Int, ?doTrace: Bool)
    {
      var ox2 = x2;
      var oy2 = y2;
      var steep: Bool = (Math.abs(y2 - y1) > Math.abs(x2 - x1));
      var tmp: Int;
      if (steep)
        {
          // swap x1 and y1
          tmp = x1;
          x1 = y1;
          y1 = tmp;

          // swap x2 and y2
          tmp = x2;
          x2 = y2;
          y2 = tmp;
        }

      // make sure x1 < x2
      if (x1 > x2)
        {
          // swap x1 and x2
          tmp = x1;
          x1 = x2;
          x2 = tmp;

          // swap y1 and y2
          tmp = y1;
          y1 = y2;
          y2 = tmp;
        }

      var dx: Int = x2 - x1;
      var dy: Int = Math.floor(Math.abs(y2 - y1));
      var error: Int = Math.floor(dx / 2);
      var yy: Int = y1;
      var ystep: Int = (y1 < y2 ? 1 : -1);

      for (xx in x1...x2)
        {
          // check if this x,y is walkable
          var ok = true;
          if (steep)
            {
              if (doTrace)
                trace(yy + ',' + xx);
              ok = isWalkable(yy, xx);

              // slight modification - even if endpoint is not walkable, it's still visible
              if (ox2 == yy && oy2 == xx)
                ok = true;
            }
          else
            {
              if (doTrace)
                trace(xx + ',' + yy);
              ok = isWalkable(xx, yy);

              // slight modification - even if endpoint is not walkable, it's still visible
              if (ox2 == xx && oy2 == yy)
                ok = true;
            }
              if (doTrace)
                trace(xx + ',' + yy);
          if (!ok)
            return false;

          error -= dy;
          if (error < 0)
            {
              yy = yy + ystep;
              error = error + dx;
            }
        }

      return true;
    }


// add AI back to map
  public function addAI(ai: AI)
    {
      game.scene.add(ai.entity);
      _ai.add(ai);
    }


// destroy AI
  public function destroyAI(ai: AI)
    {
      game.scene.remove(ai.entity);
      _ai.remove(ai);
    }


// AI turn to act
  public function aiTurn()
    {
      for (ai in _ai)
        ai.ai();
    }


// update AI visibility
  public function updateVisibility()
    {
      // calculate visible rectangle
      var x1 = Std.int(HXP.camera.x / Const.TILE_WIDTH) - 1;
      var y1 = Std.int(HXP.camera.y / Const.TILE_HEIGHT) - 1;
      var x2 = Std.int((HXP.camera.x + HXP.windowWidth) / Const.TILE_WIDTH) + 2;
      var y2 = Std.int((HXP.camera.y + HXP.windowHeight) / Const.TILE_HEIGHT) + 2;
      if (x1 < 0)
        x1 = 0;
      if (y1 < 0)
        y1 = 0;
      if (x2 > width)
        x2 = width;
      if (y2 > height)
        y2 = height;

      for (y in y1...y2)
        for (x in x1...x2)
          if (isVisible(game.player.x, game.player.y, x, y))
            _tilemap.setTile(x, y, _cells[x][y]);
          else _tilemap.setTile(x, y, Const.TILE_HIDDEN);

      for (ai in _ai)
        ai.entity.visible = isVisible(game.player.x, game.player.y, ai.x, ai.y);

      for (obj in _objects)
        obj.entity.visible = isVisible(game.player.x, game.player.y, obj.x, obj.y);
    }


// get random direction to a near empty space
// returns index of Const.dirx[], Const.diry[]
  public function getRandomDirection(x: Int, y: Int): Int
    {
      // form a temp list of walkable dirs
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok = 
            (isWalkable(nx, ny) && 
             !hasAI(nx, ny) && 
             !(game.player.x == nx && game.player.y == ny));
          if (ok)
            tmp.push(i);
        }

      // nowhere to go, return
      if (tmp.length == 0)
        {
          trace('ai at (' + x + ',' + y + '): no dirs');
          return -1;
        }

      return tmp[Std.random(tmp.length)];
    }
}

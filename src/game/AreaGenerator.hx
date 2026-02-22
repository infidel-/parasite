// area generation

package game;

import const.WorldConst;
import Const;
import objects.*;
import game.AreaGame;
import game.CityAreaGenerator;
import game.SewerAreaGenerator;
import game.UndergroundLabAreaGenerator;

class AreaGenerator
{
  public var game: Game;
  public var facility: FacilityAreaGenerator;
  public var city: CityAreaGenerator;
  public var corp: CorpAreaGenerator;
  public var sewers: SewerAreaGenerator;
  public var undergroundLab: UndergroundLabAreaGenerator;

  public static var deltaMap: Map<Int, { x: Int, y: Int }>;
  public static var DIR_UP = 8;
  public static var DIR_LEFT = 4;
  public static var DIR_RIGHT = 6;
  public static var DIR_DOWN = 2;

  public function new(g: Game)
    {
      game = g;
      facility = new FacilityAreaGenerator(game, this);
      city = new CityAreaGenerator(game, this);
      corp = new CorpAreaGenerator(game, this);
      sewers = new SewerAreaGenerator(game, this);
      undergroundLab = new UndergroundLabAreaGenerator(game, this);
      deltaMap = [
        DIR_LEFT => { x: -1, y: 0 },
        DIR_RIGHT => { x: 1, y: 0 },
        DIR_UP => { x: 0, y: -1 },
        DIR_DOWN => { x: 0, y: 1 },
      ];
    }

// generate area
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var state: _GeneratorState = {
        alleys: new List(),
        sewers: new List(),
        blockSize: 20,
      };

      if (info.type == 'city')
        city.generate(state, area, info);
      else if (info.type == 'militaryBase')
        generateBuildings(game, area, info);
      else if (info.type == 'facility')
        facility.generate(area, info);
      else if (info.type == 'wilderness')
        generateWilderness(game, area, info);
      else if (info.type == 'habitat')
        generateHabitat(game, area, info);
      else if (info.type == 'corp')
        corp.generate(area, info);
      else if (info.type == 'sewers')
        sewers.generate(area, info);
      else if (info.type == 'undergroundLab')
        undergroundLab.generate(area, info);
      else trace('AreaGenerator.generate(): unknown area type: ' + info.type);

      if (info.type == 'city')
        city.generateObjects(state, area, info);
      else generateObjects(state, game, area, info);

/*
      // draw map
      var map = new h2d.Graphics();
      var scale = 4;
      map.x = 0;
      map.y = 0;
      map.clear();
      map.beginFill(0, 1);
      map.drawRect(0, 0, area.width * (scale + 1),
        area.height * (scale + 1));

      var cells = area.getCells();
      var cols1 = [
        TEMP_BUILDING => 0x22ff22,
        TEMP_ROAD => 0x222222, // dark grey
        TEMP_ALLEY => 0x666666,
        TEMP_ALLEY_TB => 0xffff44,
        TEMP_ALLEY_BT => 0x44ffff,
        TEMP_ALLEY_LR => 0xff44ff,
        TEMP_ALLEY_RL => 0x4444ff,
        TEMP_MARKER => 0xffffff,
        TEMP_ACTUAL_BUILDING => 0xff6666, // pink
        TEMP_WALKWAY => 0x6666ff,
        TEMP_BLOCK => 0x00ffff,
      ];

      var cols = [
        Const.TILE_ROAD => cols1[TEMP_ROAD],
        Const.TILE_ALLEY => cols1[TEMP_ALLEY],
        Const.TILE_WALKWAY => cols1[TEMP_BLOCK],
        Const.TILE_BUILDING => cols1[TEMP_ACTUAL_BUILDING],
      ];
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
            {
              map.beginFill(cols1[cells[x][y]], 1);
              map.drawRect(x * (scale + 1), y * (scale + 1), scale, scale);
            }
        }
      map.endFill();
      game.scene.add(map, 100);
*/
    }

// add decoration from a list of decoration groups
// except the ones used, updating and returning the remaining groups
// if the array becomes empty, replenish from the full list
  public function addDecorationExt(area: AreaGame,
      x: Int, y: Int,
      groups: Array<_TileGroup>, groupsFull: Array<_TileGroup>): Array<_TileGroup>
    {
      if (groups.length == 0)
        {
          trace('groups empty!');
          return groups;
        }
      var group = groups[Std.random(groups.length)];
      groups.remove(group);
      if (groups.length == 0)
        groups = groupsFull.copy();
      var info = group[Std.random(group.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);
      var o = new Decoration(game, area.id, x, y, info.row, col);
      area.addObject(o);
      return groups;
    }

// add decoration from a list
  public function addDecoration(area: AreaGame,
      x: Int, y: Int, infos: Array<_TileRow>)
    {
      var info = infos[Std.random(infos.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);
      var o = new Decoration(game, area.id, x, y, info.row, col);
      area.addObject(o);
    }

// add extended decoration from a list
  public function addDecorationTransformable(area: AreaGame,
      x: Int, y: Int, infos: Array<_TileRow>)
    {
      var info = infos[Std.random(infos.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);
      var o = new DecorationExt(game, area.id, x, y, info.row, col);
      area.addObject(o);
    }

// adjust walkable street tiles to their unwalkable variants
  public function makeTileUnwalkable(area: AreaGame, x: Int, y: Int)
    {
      var tile = area.getCellType(x, y);
      var newTile = tile;
      if (tile == Const.TILE_ROAD)
        newTile = Const.TILE_ROAD_UNWALKABLE;
      else if (tile == Const.TILE_ALLEY)
        newTile = Const.TILE_ALLEY_UNWALKABLE;
      else if (tile == Const.TILE_WALKWAY)
        newTile = Const.TILE_WALKWAY_UNWALKABLE;

      if (newTile != tile)
        area.setCellType(x, y, newTile);
    }

// print generated area tiles 
  public static function printArea(game: Game, area: AreaGame, mapTiles: Array<String>)
    {
      var cells = area.getCells();
      var s = 'XX: ';
      for (i in 0...Std.int(cells.length / 10))
        s += '|123456789';
      js.Browser.console.group();
      js.Browser.console.log(s);
      var list = '';
      var lastRoomID = 0;
      for (y in 0...area.height)
        {
          var s = '';
          var tileID = 0;
          for (x in 0...area.width)
            {
              tileID = cells[x][y];
              var char = mapTiles[cells[x][y]];
//              if (char == null)
//                trace(cells[x][y]);
              s += (char != null ? char : '?');
/*
              // room IDs after
              if (tileID < 100)
                {
                  var char = mapTiles[cells[x][y]];
                  s += (char != null ? char : '?');
                }
              else
                {
                  var char = String.fromCharCode(tileID - 100 + 97);
                  if (lastRoomID < tileID)
                    {

                      list += char + ': ' + tileID + ', ';
                      lastRoomID = tileID;
                    }
                  s += char;
                }*/
            }
          js.Browser.console.log((y < 10 ? '0' : '') + y + ': ' + s);
        }
      js.Browser.console.log(list);
      js.Browser.console.groupEnd();
    }

// generate a habitat
  static function generateHabitat(game: Game, area: AreaGame, info: AreaInfo)
    {
      // fill with walls
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, Const.TILE_WALL);

      // make some rooms
      for (i in 0...10)
        {
          var x1 = 1 + Std.random(area.width - 5);
          var y1 = 1 + Std.random(area.height - 5);
          var w = 5 + Std.random(15);
          var h = 5 + Std.random(15);
          if (x1 + w >= area.width - 1)
            w = area.width - x1 - 2;
          if (y1 + h >= area.height - 1)
            h = area.height - y1 - 2;
          makeRoom(area, x1, y1, w, h);
        }
    }


// helper: make a room
  static function makeRoom(area: AreaGame, x1: Int, y1: Int, w: Int, h: Int)
    {
      for (y in y1...y1 + h)
        for (x in x1...x1 + w)
          area.setCellType(x, y, Const.TILE_WALKWAY);
    }


// generate rocks, trees, etc
  static function generateWilderness(game: Game, area: AreaGame, info: AreaInfo)
    {
      var numStuff = Std.int(area.width * area.height / 20);
      for (i in 0...numStuff)
        {
          var x = Std.random(area.width);
          var y = Std.random(area.height);

          var t = Const.TILE_BUSH;
          if (Std.random(100) < 30)
            t = Const.TILE_ROCK;
          if (Std.random(100) < 30)
            t = Const.TILE_TREE1 +
              Std.random(Const.TILE_BUSH - Const.TILE_TREE1);

          area.setCellType(x, y, t);
        }
    }


// generate buildings
  static function generateBuildings(game: Game, area: AreaGame, info: AreaInfo)
    {
      // buildings
      for (y in 1...area.height)
        for (x in 1...area.width)
          {
            if (Math.random() > info.buildingChance)
              continue;

            // size
            var sx = 5 + Std.random(10);
            var sy = 5 + Std.random(10);

            if (x + sx > area.width - 1)
              sx = area.width - 1 - x;
            if (y + sy > area.height - 1)
              sy = area.height - 1 - y;

            if (sx < 2)
              continue;
            if (sy < 2)
              continue;

//            var cell = get(x,y);

            // check for adjacent buildings
            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  //var cell = get(x + dx, y + dy);
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == Const.TILE_BUILDING)
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
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == -1)
                    continue;

                  area.setCellType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate objects
  static function generateObjects(state: _GeneratorState, game: Game, area: AreaGame, info: AreaInfo)
    {
      // spawn all objects
      for (objInfo in info.objects)
        for (i in 0...objInfo.amount)
          {
            // find free spot that is not close to another object like this
            var loc = null;
            var cnt = 0;
            while (true)
              {
                loc = area.findEmptyLocation();
                cnt++;
                if (cnt > 500)
                  {
                    trace('Area.generateObjects(): no free spot for another ' + 
                      objInfo.id + ', please report');
                    return;
                  }

                // check for close objects
                var ok = true;
                for (y in -3...3)
                  for (x in -3...3)
                    {
                      var olist = area.getObjectsAt(loc.x + x, loc.y + y);
                      for (o in olist)
                        if (o.type == objInfo.id)
                          {
                            ok = false;
                            break;
                          }

                      if (!ok)
                        break;
                    }

                if (ok)
                  break;
              }

            var o: AreaObject = null;
            if (objInfo.id == 'sewer_hatch')
              o = new SewerHatch(game, area.id, loc.x, loc.y);
            else if (objInfo.id == 'sewer_exit')
              o = new SewerExit(game, area.id, loc.x, loc.y);
              
            else throw 'unknown object type: ' + objInfo.id;

            area.addObject(o);
          }
    }


// draw a w,h block at x,y 
  public static function drawBlock(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int, tile: Int)
    {
      for (i in 0...w)
        for (j in 0...h)
          cells[x + i][y + j] = tile;
    }

// draw a chunk of a line of a given width and direction
  public static function drawChunk(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, dir: Int, tile: Int)
    {
      if (dir == DIR_UP || dir == DIR_DOWN)
        for (i in 0...w)
          cells[x + i][y] = tile;
      else for (i in 0...w)
        cells[x][y + i] = tile;
    }

// draw an 2-dim array at x,y 
  public static function drawArray(cells: Array<Array<Int>>, x: Int, y: Int,
      block: Array<Array<Int>>)
    {
      for (i in 0...block[0].length)
        for (j in 0...block.length)
          cells[x + i][y + j] = block[j][i];
    }

// mark all A tiles to B tiles in rect
  public static function replaceTiles(cells: Array<Array<Int>>,
      sx: Int, sy: Int, w: Int, h: Int, from: Int, to: Int)
    {
      for (y in sy...sy + h + 1)
        for (x in sx...sx + w + 1)
          if (cells[x][y] == from)
            cells[x][y] = to;
    }

// draw line from starting position into a given direction
  public static function drawLine(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int, tile: Int): Int
    {
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      var startTile = cells[sx][sy];
//      trace(startTile);
      cells[sx][sy] = tile;
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] != startTile)
            break;
          cells[x][y] = tile;
//          trace(x + ',' + y + ' = ' + tile + cells[x][y]);
        }
//      trace('len:' + len);
      return len - 1;
    }

// get potential door spots in room
  public static function getRoomDoorSpots(room: _Room): Array<_Spot>
    {
      return [
        {
          x: room.x1 - 1,
          y: Std.int(room.y1 + room.h / 2),
          dir: DIR_LEFT,
          dir90: 0,
        },
        {
          x: room.x2 + 1,
          y: Std.int(room.y1 + room.h / 2),
          dir: DIR_RIGHT,
          dir90: 0,
        },
        {
          x: Std.int(room.x1 + room.w / 2),
          y: room.y1 - 1,
          dir: DIR_UP,
          dir90: 0,
        },
        {
          x: Std.int(room.x1 + room.w / 2),
          y: room.y2 + 1,
          dir: DIR_DOWN,
          dir90: 0,
        },
      ];
    }

// mark room as sub-divided
  public static function markRoom(cells: Array<Array<Int>>,
      room: _Room, tileID: Int)
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          cells[x][y] = tileID;
    }

// get room dimensions
  public static function getRoom(cells: Array<Array<Int>>,
      sx: Int, sy: Int): _Room 
    {
      var w = 0, h = 0;
      var tile = cells[sx][sy];
      while (true)
        {
          w++;
          if (w > 100)
            {
              trace('room too large?');
              break;
            }

          if (cells[sx + w][sy] != tile)
            break;
        }
      while (true)
        {
          h++;
          if (h > 100)
            {
              trace('room too large?');
              break;
            }

          if (cells[sx][sy + h] != tile)
            break;
        }
      w--;
      h--;
      return {
        id: -1,
        x1: sx,
        y1: sy,
        x2: sx + w,
        y2: sy + h,
        w: w + 1,
        h: h + 1,
      }
    }

// check if this cell is next to a tile from a list
  public static function nextToAny(cells: Array<Array<Int>>,
      x: Int, y: Int, tiles: Array<Int>): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (Lambda.has(tiles, cells[x + Const.dir4x[i]][y + Const.dir4y[i]]))
          return true;
      return false;
    }

// check if this cell is next to a given tile
  public static function nextTo(cells: Array<Array<Int>>,
      x: Int, y: Int, tile: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == tile)
          return true;
      return false;
    }

// get room wall corner spots with wall directions
  public static function getRoomWallCorners(room: _Room): Array<_Spot>
    {
      return [
        {
          x: room.x1 - 1,
          y: room.y1 - 1,
          dir: DIR_RIGHT,
          dir90: DIR_DOWN,
        },
        {
          x: room.x1 - 1,
          y: room.y2 + 1,
          dir: DIR_RIGHT,
          dir90: DIR_UP,
        },
        {
          x: room.x1 - 1,
          y: room.y1 - 1,
          dir: DIR_DOWN,
          dir90: DIR_RIGHT,
        },
        {
          x: room.x2 + 1,
          y: room.y1 - 1,
          dir: DIR_DOWN,
          dir90: DIR_LEFT,
        },
      ];
    }

}


enum _LineDir
{
  TB;
  BT;
  LR;
  RL;
}

typedef _GeneratorState = {
  alleys: List<{
    x: Int,
    y: Int,
    t: _LineDir
  }>,
  sewers: List<{
    x: Int,
    y: Int,
  }>,
  blockSize: Int,
}

typedef _Block = {
  x1: Int,
  y1: Int,
  x2: Int,
  y2: Int,
  w: Int,
  h: Int,
}
typedef _Spot = {
  x: Int,
  y: Int,
  dir: Int,
  dir90: Int,
}

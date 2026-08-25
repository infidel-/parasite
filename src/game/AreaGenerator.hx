// area generation

package game;

import const.WorldConst;
import map.Terrain;
import Const;
import objects.*;
import game.AreaGame;
import game.CityAreaGenerator;
import game.SewerAreaGenerator;
import game.UndergroundLabAreaGenerator;
import objects.mission.SewerExit;

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

  // wilderness highway width, in cells. an actor billboard is 3 world units against a 4-unit cell, so
  // a cell is roughly 2.4m and three of them is a two-lane rural highway. two reads as a farm track,
  // four as a motorway the region map is not drawing. read by render.wild.WildRoad through the
  // recovered rect rather than directly, so this number lives in one place
  public static inline var ROAD_W = 3;

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
        sewers.generate(area, info, getHabitatSewerOptions());
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

// get sewer generator options for habitat areas
  static function getHabitatSewerOptions()
    {
      return {
        blockWidth: 3,
        blockHeight: 2,
        minRoomBlocks: 4,
        maxRoomBlocks: 5,
        exitCount: 2,
        useHabitatExits: true,
      };
    }
// what grows on a wilderness area, per terrain band. the region map has painted three bands since
// map.Terrain landed and until now they only named areas, so a forest tile and a mountain tile
// generated the identical scatter. the render side reads the same band for its ground, relief and
// models (render.wild.WildBand), but DENSITY has to be decided here: walkability follows the tiles, so
// a renderer that simply drew fewer trees would leave blocked cells looking like open ground.
//
// the FOREST row is held down by the CAMERA and not by the fiction: there is no occlusion fade out
// here (render.Occlusion buckets buildings and a wilderness area has none), so every canopy between
// the camera and the player hides the player. it went in at 0.12 / 60% trees and that kept the actor
// under a crown; 0.10 / 50% still reads as a wood against the plains' 0.025, and takes ~25% of the
// triangles off with it
  static function wildMix(band: _TerrainBand): _WildMix
    {
      if (band == TERRAIN_FOREST)
        return {
          density: 0.10,
          tree: 50,
          bush: 35,
          big: Const.TILE_TREE_CLUSTER,
          bigCount: 7,
        };
      if (band == TERRAIN_MOUNTAIN)
        return {
          density: 0.07,
          tree: 15,
          bush: 25,
          big: Const.TILE_ROCK_LARGE,
          bigCount: 8,
        };
      return {
        density: 0.025,
        tree: 20,
        bush: 55,
        big: -1,
        bigCount: 0,
      };
    }

// lay the region map's highway across the area, where one crosses it at all.
//
// the axis and the offset are NOT rolled here — map.Highway reads them off the region's persisted
// mapSeed, the same way the terrain band is read, so the corridor lands where the region map already
// paints it and leaves each area exactly where it enters the next. width is the only local decision.
//
// through area.regionID rather than game.region, like the band above it: an area can be generated
// remotely while the player is standing somewhere else entirely
  static function placeHighway(game: Game, area: AreaGame)
    {
      var road = map.Highway.atArea(game.world.get(area.regionID), area.x, area.y);
      if (road == null)
        return;
      // the corridor spans the whole grid on its axis; the offset is a fraction ACROSS the other one
      var span = (road.horizontal ? area.height : area.width);
      var mid = Std.int(road.offset * span);
      var from = mid - Std.int(ROAD_W / 2);
      for (i in 0...ROAD_W)
        {
          var line = from + i;
          if (line < 0 ||
              line >= span)
            continue;
          if (road.horizontal)
            for (x in 0...area.width)
              area.setCellType(x, line, Const.TILE_ROAD);
          else
            for (y in 0...area.height)
              area.setCellType(line, y, Const.TILE_ROAD);
        }
    }

// stamp the band's large obstacles onto clear ground. these are the only cells the wilderness writes
// that block SIGHT as well as movement, so each one is real cover rather than another tree to walk
// around: a 2x2 boulder in the mountains, a 2-3 x 2-3 tree thicket in the forest, nothing on the
// plains. run BEFORE the scatter, while the grid is still uniform ground and nothing can fail to fit
  static function placeBigObstacles(area: AreaGame, mix: _WildMix, depth: Float)
    {
      if (mix.big < 0)
        return;
      var count = Std.int(mix.bigCount * (0.8 + 0.4 * depth));
      for (i in 0...count)
        {
          // the rock is its own model and is exactly two cells; a thicket is grown cell by cell out of
          // the band's own trees and bushes, so it can be any size
          var w = (mix.big == Const.TILE_ROCK_LARGE ? 2 : 2 + Std.random(2));
          var h = (mix.big == Const.TILE_ROCK_LARGE ? 2 : 2 + Std.random(2));
          for (t in 0...20)
            {
              var x = 2 + Std.random(area.width - w - 4);
              var y = 2 + Std.random(area.height - h - 4);
              if (!isBigObstacleClear(area, x, y, w, h, mix.big))
                continue;
              for (dy in 0...h)
                for (dx in 0...w)
                  area.setCellType(x + dx, y + dy, mix.big);
              break;
            }
        }
    }

// is this rect, plus a one-cell margin, free of other large obstacles? the MARGIN is load-bearing and
// not politeness: render.wild.WildModel recovers each 2x2 rock's rect by looking for the corner with
// no rock left of it and none above it, and two rocks allowed to touch would read as one L-shaped
// blob with the model landing on the wrong cell
  static function isBigObstacleClear(area: AreaGame, x: Int, y: Int, w: Int,
      h: Int, tile: Int): Bool
    {
      for (dy in -1...h + 1)
        for (dx in -1...w + 1)
          {
            var t = area.getCellType(x + dx, y + dy);
            // the ROAD is tested over the same margin as another obstacle, and the margin earns its
            // keep twice here: it keeps a boulder off the asphalt, and it leaves the shoulder cell
            // free for the guard rail render.wild.WildProps stands there
            if (t == tile ||
                t == Const.TILE_ROAD)
              return false;
          }
      return true;
    }

// is this cell on the highway or in the two-cell margin beside it?
//
// that margin is the VERGE, and the number is not a taste call: the dirt shoulder reaches
// WildStyle.VERGE_HALF = 2.75 cells from the centreline, which is 1.25 cells past the asphalt, and the
// GUARD RAIL stands on it at half + WildStyle.RAIL_OFF = 2.4. so a scatter tile inside this ring is a
// tree standing on a graded shoulder between the barrier and the road, where nothing can reach it and
// its canopy (4.8-6.7 world units across, over a 4-unit cell) hangs out over the traffic lane.
//
// it went in at ONE cell, sized off the rail alone, and that was already half a cell short of the verge
// the render layer now lays — a dilation of 1 keeps scatter to 2.5 cells from the centreline against a
// shoulder that ends at 2.75. isBigObstacleClear applies whatever this returns, which is why no boulder
// or thicket was ever caught doing it and only the single-cell scatter was
  static function nearRoad(area: AreaGame, x: Int, y: Int): Bool
    {
      for (dy in -2...3)
        for (dx in -2...3)
          if (area.getCellType(x + dx, y + dy) == Const.TILE_ROAD)
            return true;
      return false;
    }

// generate rocks, trees, etc
  static function generateWilderness(game: Game, area: AreaGame, info: AreaInfo)
    {
      // through regionID rather than game.region: an area can be generated remotely (an event
      // spawning an object in it) while the player is standing somewhere else entirely
      var seed = game.world.get(area.regionID).mapSeed;
      var mix = wildMix(Terrain.bandAtArea(seed, area.x, area.y));
      // scaled by how deep into its band the area sits, so a wood on the plains edge is thinner than
      // one in the middle of the forest and neither snaps at the threshold
      var depth = Terrain.depthAt(seed, area.x, area.y);
      var numStuff = Std.int(area.width * area.height * mix.density *
        (0.8 + 0.4 * depth));
      // the highway goes down before anything else: it is the only feature out here whose position is
      // dictated from OUTSIDE the area, so everything below has to fit around it rather than the
      // other way round
      placeHighway(game, area);
      // then the large obstacles, onto a grid that is still uniform ground apart from the road, so
      // none of them can fail to find room
      placeBigObstacles(area, mix, depth);
      for (i in 0...numStuff)
        {
          var x = Std.random(area.width);
          var y = Std.random(area.height);

          // a scatter tile dropped into a large obstacle would punch a hole in it, and a rect with a
          // hole in it stops being a rect. plains passes `big` -1, which an in-bounds getCellType can
          // never return, so this test simply never fires there. the road is the same argument — a
          // tree growing out of the asphalt, and a corridor the render layer can no longer recover —
          // and it takes the guard rail's margin with it (see nearRoad)
          var cur = area.getCellType(x, y);
          if (cur == mix.big ||
              nearRoad(area, x, y))
            continue;

          // one roll across the three, so the percentages mean what they say. the tree tile keeps its
          // 1-of-4 variant: those four IDs are what the 3D area maps onto four models
          var roll = Std.random(100);
          var t = Const.TILE_BUSH;
          if (roll < mix.tree)
            t = Const.TILE_TREE1 +
              Std.random(Const.TILE_BUSH - Const.TILE_TREE1);
          else if (roll >= mix.tree + mix.bush)
            t = Const.TILE_ROCK;

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

// one terrain band's wilderness scatter (AreaGenerator.wildMix)
typedef _WildMix = {
  // share of the area's cells that get a prop tile, before the band-depth scale
  density: Float,
  // percent of those cells that take a tree
  tree: Int,
  // percent that take a bush; whatever is left over takes a rock
  bush: Int,
  // the band's LARGE obstacle tile, or -1 where it has none. these are the only cells the wilderness
  // writes that block sight as well as movement
  big: Int,
  // how many of them to place, before the same band-depth scale the density takes
  bigCount: Int,
}

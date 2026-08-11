// sewer mission area generation

package game;

import Const;
import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import objects.mission.HabitatExit;
import objects.mission.SewerExit;
import tiles.Sewers;
import tiles._FloorDecorMeta;

typedef SewerAreaGeneratorOptions = {
  @:optional var blockWidth: Int;
  @:optional var blockHeight: Int;
  @:optional var minRoomBlocks: Int;
  @:optional var maxRoomBlocks: Int;
  @:optional var exitCount: Int;
  @:optional var useHabitatExits: Bool;
}

private typedef _GridPos = {
  var bx: Int;
  var by: Int;
}

private typedef _SewerGrid = {
  var startX: Int;
  var startY: Int;
  var width: Int;
  var height: Int;
}

private typedef _SewerBlockLink = {
  var bx1: Int;
  var by1: Int;
  var bx2: Int;
  var by2: Int;
}

class SewerAreaGenerator
{
  static inline var BLOCK_SIZE = 7;
  static inline var ROOM_SIZE = 5;
  static inline var TUNNEL_SIZE = 3;

  static inline var BLOCK_EMPTY = 0;
  static inline var BLOCK_ROOM = 1;
  static inline var BLOCK_TUNNEL = 2;

  var game: Game;
  var gen: AreaGenerator;

// store references to game and shared generator helper
  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
    }

// generate sewer area from aligned 7x7 blocks
  public function generate(area: AreaGame, info: AreaInfo,
      ?options: SewerAreaGeneratorOptions)
    {
      // fill with walls first
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, Const.TILE_WALL);

      // build block layout and mark room blocks
      var grid = buildGrid(area, options);
      var blockKinds = buildBlockKindMap(grid);
      var roomBlocks = rollRoomBlocks(grid, options);
      markRoomBlocks(blockKinds, roomBlocks);

      // connect room blocks and mark tunnel blocks
      var links = connectRoomBlocks(grid, blockKinds, roomBlocks);

      // add blind paths and alternate connections
      addBlindPaths(grid, blockKinds, roomBlocks, links);
      addAlternatePaths(grid, blockKinds, roomBlocks, links);

      // carve room/tunnel geometry from block plan
      var rooms = carveFromBlocks(area, grid, blockKinds, roomBlocks, links);

      // place exits on tunnel junctions
      placeExits(area, rooms, options);

      // convert carved walkway markers to sewer floor and wall tiles
      finalizeTiles(area);
      // initialize tile metadata
      area.initTilesFromCells();
      // NOTE: floor decoration and debris used to be placed here as persisted tile decorations.
      // sewers render in 3D now, so that clutter is owned by the render layer instead
      // (render.sewer.Debris — derived per cell, never saved). old saves keep their inert entries

      area.generatorInfo = {
        rooms: rooms,
        doors: [],
      };
    }

// build 7x7 block grid with no offset
  function buildGrid(area: AreaGame,
      ?options: SewerAreaGeneratorOptions): _SewerGrid
    {
      var gw = Std.int(area.width / BLOCK_SIZE);
      var gh = Std.int(area.height / BLOCK_SIZE);
      if (gw < 1)
        gw = 1;
      if (gh < 1)
        gh = 1;

      if (options != null &&
          options.blockWidth != null)
        gw = Std.int(Math.min(gw, options.blockWidth));
      if (options != null &&
          options.blockHeight != null)
        gh = Std.int(Math.min(gh, options.blockHeight));

      return {
        startX: 0,
        startY: 0,
        width: gw,
        height: gh,
      };
    }

// allocate block kind matrix
  function buildBlockKindMap(grid: _SewerGrid): Array<Array<Int>>
    {
      var map = [];
      for (_ in 0...grid.height)
        {
          var row = [];
          for (_ in 0...grid.width)
            row.push(BLOCK_EMPTY);
          map.push(row);
        }
      return map;
    }

// roll room block positions first
  function rollRoomBlocks(grid: _SewerGrid,
      ?options: SewerAreaGeneratorOptions): Array<_GridPos>
    {
      var rooms = [];
      var total = grid.width * grid.height;

      var minRooms = getMinRoomBlocks(total, options);
      var maxRooms = getMaxRoomBlocks(total, minRooms, options);
      if (maxRooms > total)
        maxRooms = total;
      var target = minRooms;
      if (maxRooms > minRooms)
        target += Std.random(maxRooms - minRooms + 1);
      if (target > total)
        target = total;

      var tries = 0;
      while (rooms.length < target &&
          tries < 600)
        {
          tries++;
          var bx = Std.random(grid.width);
          var by = Std.random(grid.height);
          if (!canPlaceRoomBlock(rooms, bx, by, false))
            continue;
          rooms.push({ bx: bx, by: by });
        }

      // relax adjacency if strict spacing ran out of space
      while (rooms.length < target &&
          tries < 1200)
        {
          tries++;
          var bx = Std.random(grid.width);
          var by = Std.random(grid.height);
          if (!canPlaceRoomBlock(rooms, bx, by, true))
            continue;
          rooms.push({ bx: bx, by: by });
        }

      // fallback room in center
      if (rooms.length == 0)
        rooms.push({
          bx: Std.int(grid.width / 2),
          by: Std.int(grid.height / 2),
        });

      // keep at least two rooms when possible
      if (rooms.length == 1 &&
          total > 1)
        {
          var best = { bx: 0, by: 0 };
          var bestDist = -1;
          for (by in 0...grid.height)
            for (bx in 0...grid.width)
              {
                if (bx == rooms[0].bx &&
                    by == rooms[0].by)
                  continue;
                var dist = Std.int(Math.abs(bx - rooms[0].bx) +
                  Math.abs(by - rooms[0].by));
                if (dist <= bestDist)
                  continue;
                bestDist = dist;
                best = { bx: bx, by: by };
              }
          rooms.push(best);
        }

      return rooms;
    }

// get minimum amount of room blocks to place
  function getMinRoomBlocks(total: Int,
      ?options: SewerAreaGeneratorOptions): Int
    {
      if (options != null &&
          options.minRoomBlocks != null)
        return Std.int(Math.max(0, Math.min(total, options.minRoomBlocks)));
      return Std.int(Math.max(6, Math.ceil(total * 0.16)));
    }

// get maximum amount of room blocks to place
  function getMaxRoomBlocks(total: Int, minRooms: Int,
      ?options: SewerAreaGeneratorOptions): Int
    {
      if (options != null &&
          options.maxRoomBlocks != null)
        return Std.int(Math.max(minRooms,
          Math.min(total, options.maxRoomBlocks)));
      return Std.int(Math.max(minRooms, Math.floor(total * 0.28)));
    }

// validate candidate room block placement
  function canPlaceRoomBlock(rooms: Array<_GridPos>,
      bx: Int, by: Int, allowAdjacent: Bool): Bool
    {
      for (room in rooms)
        {
          if (room.bx == bx &&
              room.by == by)
            return false;

          if (allowAdjacent)
            continue;

          var manhattan = Math.abs(room.bx - bx) +
            Math.abs(room.by - by);
          if (manhattan <= 1)
            return false;
        }
      return true;
    }

// mark selected room blocks in kind map
  function markRoomBlocks(kinds: Array<Array<Int>>, rooms: Array<_GridPos>)
    {
      for (room in rooms)
        kinds[room.by][room.bx] = BLOCK_ROOM;
    }

// connect room blocks and mark tunnel blocks between them
  function connectRoomBlocks(grid: _SewerGrid,
      kinds: Array<Array<Int>>, rooms: Array<_GridPos>): Array<_SewerBlockLink>
    {
      var links = [];
      if (rooms.length <= 1)
        return links;

      var connected = [rooms[0]];
      var remaining = [];
      for (i in 1...rooms.length)
        remaining.push(rooms[i]);

      // build room graph as one connected tunnel network
      while (remaining.length > 0)
        {
          var bestDist = 1000000;
          var bestFrom = connected[0];
          var bestTo = remaining[0];

          for (from in connected)
            for (to in remaining)
              {
                var dist = blockDistance(from, to);
                if (dist >= bestDist)
                  continue;
                bestDist = dist;
                bestFrom = from;
                bestTo = to;
              }

          // route by block centers and mark path
          var path = buildPathByCenters(kinds, bestFrom, bestTo);
          for (i in 0...path.length)
            {
              var p = path[i];
              if (i > 0)
                addLink(links, path[i - 1], p);

              if (i == 0 ||
                  i == path.length - 1)
                continue;

              if (kinds[p.by][p.bx] == BLOCK_EMPTY)
                kinds[p.by][p.bx] = BLOCK_TUNNEL;
            }

          connected.push(bestTo);
          remaining.remove(bestTo);
        }

      return links;
    }

// add blind dead-end paths from some rooms
  function addBlindPaths(grid: _SewerGrid, kinds: Array<Array<Int>>,
      rooms: Array<_GridPos>, links: Array<_SewerBlockLink>)
    {
      if (rooms.length < 3)
        return;

      // pick 1-3 rooms to extend blind paths from
      var candidates = [];
      for (room in rooms)
        candidates.push(room);

      var toExtend = Std.random(Std.int(Math.min(3, candidates.length))) + 1;
      for (_ in 0...toExtend)
        {
          if (candidates.length == 0)
            break;
          var idx = Std.random(candidates.length);
          var room = candidates[idx];
          candidates.splice(idx, 1);

          // find an empty direction to extend
          var dirs = [
            { dx: 1, dy: 0 },
            { dx: -1, dy: 0 },
            { dx: 0, dy: 1 },
            { dx: 0, dy: -1 },
          ];
          while (dirs.length > 0)
            {
              var dIdx = Std.random(dirs.length);
              var dir = dirs[dIdx];
              dirs.splice(dIdx, 1);

              var nbx = room.bx + dir.dx;
              var nby = room.by + dir.dy;
              if (nbx < 0 || nbx >= grid.width || nby < 0 || nby >= grid.height)
                continue;
              if (kinds[nby][nbx] != BLOCK_EMPTY)
                continue;

              // mark as tunnel and add link
              kinds[nby][nbx] = BLOCK_TUNNEL;
              addLink(links, room, { bx: nbx, by: nby });
              break;
            }
        }
    }

// add alternate paths between nearby rooms that aren't directly connected
  function addAlternatePaths(grid: _SewerGrid, kinds: Array<Array<Int>>,
      rooms: Array<_GridPos>, links: Array<_SewerBlockLink>)
    {
      if (rooms.length < 4)
        return;

      // find pairs of rooms that are close but not directly linked
      var pairs = [];
      for (i in 0...rooms.length)
        for (j in (i + 1)...rooms.length)
          {
            var dist = blockDistance(rooms[i], rooms[j]);
            if (dist < 2 || dist > 3)
              continue;
            if (hasDirectLink(links, rooms[i], rooms[j]))
              continue;
            pairs.push({ a: rooms[i], b: rooms[j], dist: dist });
          }

      if (pairs.length == 0)
        return;

      // shuffle and pick some to connect
      for (i in 0...pairs.length)
        {
          var j = Std.random(pairs.length);
          var tmp = pairs[i];
          pairs[i] = pairs[j];
          pairs[j] = tmp;
        }

      var toAdd = Std.random(Std.int(Math.min(pairs.length, 2))) + 1;
      for (i in 0...toAdd)
        {
          if (i >= pairs.length)
            break;
          var pair = pairs[i];
          var path = buildPathByCenters(kinds, pair.a, pair.b);
          for (k in 0...path.length)
            {
              var p = path[k];
              if (k > 0)
                addLink(links, path[k - 1], p);

              if (k == 0 || k == path.length - 1)
                continue;

              if (kinds[p.by][p.bx] == BLOCK_EMPTY)
                kinds[p.by][p.bx] = BLOCK_TUNNEL;
            }
        }
    }

// check if two blocks have a direct link
  function hasDirectLink(links: Array<_SewerBlockLink>, a: _GridPos, b: _GridPos): Bool
    {
      for (link in links)
        {
          var matchA = (link.bx1 == a.bx && link.by1 == a.by) ||
            (link.bx2 == a.bx && link.by2 == a.by);
          var matchB = (link.bx1 == b.bx && link.by1 == b.by) ||
            (link.bx2 == b.bx && link.by2 == b.by);
          if (matchA && matchB)
            return true;
        }
      return false;
    }

// build orthogonal block path and choose bend order
  function buildPathByCenters(kinds: Array<Array<Int>>,
      from: _GridPos, to: _GridPos): Array<_GridPos>
    {
      var pathH = buildPath(from, to, true);
      var pathV = buildPath(from, to, false);
      var scoreH = scorePath(kinds, pathH);
      var scoreV = scorePath(kinds, pathV);
      if (scoreH < scoreV)
        return pathH;
      if (scoreV < scoreH)
        return pathV;
      return (Std.random(2) == 0 ? pathH : pathV);
    }

// build one orthogonal block path variant
  function buildPath(from: _GridPos, to: _GridPos,
      horizontalFirst: Bool): Array<_GridPos>
    {
      var path = [];
      var bx = from.bx;
      var by = from.by;
      path.push({ bx: bx, by: by });

      if (horizontalFirst)
        {
          while (bx != to.bx)
            {
              bx += (to.bx > bx ? 1 : -1);
              path.push({ bx: bx, by: by });
            }
          while (by != to.by)
            {
              by += (to.by > by ? 1 : -1);
              path.push({ bx: bx, by: by });
            }
        }
      else
        {
          while (by != to.by)
            {
              by += (to.by > by ? 1 : -1);
              path.push({ bx: bx, by: by });
            }
          while (bx != to.bx)
            {
              bx += (to.bx > bx ? 1 : -1);
              path.push({ bx: bx, by: by });
            }
        }

      return path;
    }

// score path by unrelated room crossings
  function scorePath(kinds: Array<Array<Int>>, path: Array<_GridPos>): Int
    {
      var score = 0;
      for (i in 1...path.length - 1)
        {
          var p = path[i];
          if (kinds[p.by][p.bx] == BLOCK_ROOM)
            score += 3;
        }
      return score;
    }

// add unique adjacency link between two block cells
  function addLink(links: Array<_SewerBlockLink>,
      a: _GridPos, b: _GridPos)
    {
      var bx1 = a.bx;
      var by1 = a.by;
      var bx2 = b.bx;
      var by2 = b.by;
      if (by2 < by1 ||
          (by2 == by1 &&
           bx2 < bx1))
        {
          var tx = bx1;
          var ty = by1;
          bx1 = bx2;
          by1 = by2;
          bx2 = tx;
          by2 = ty;
        }

      for (link in links)
        if (link.bx1 == bx1 &&
            link.by1 == by1 &&
            link.bx2 == bx2 &&
            link.by2 == by2)
          return;

      links.push({
        bx1: bx1,
        by1: by1,
        bx2: bx2,
        by2: by2,
      });
    }

// carve rooms, tunnel blocks and links into area tiles
  function carveFromBlocks(area: AreaGame, grid: _SewerGrid,
      kinds: Array<Array<Int>>, roomBlocks: Array<_GridPos>,
      links: Array<_SewerBlockLink>): Array<_Room>
    {
      var rooms = [];

      // carve room blocks as centered 5x5 rooms
      for (room in roomBlocks)
        {
          var sx = blockStartX(grid, room.bx);
          var sy = blockStartY(grid, room.by);
          var roomOffset = Std.int((BLOCK_SIZE - ROOM_SIZE) / 2);
          var rx1 = sx + roomOffset;
          var ry1 = sy + roomOffset;
          for (y in ry1...ry1 + ROOM_SIZE)
            for (x in rx1...rx1 + ROOM_SIZE)
              area.setCellType(x, y, Const.TILE_WALKWAY);

          rooms.push({
            id: rooms.length,
            x1: rx1,
            y1: ry1,
            x2: rx1 + ROOM_SIZE - 1,
            y2: ry1 + ROOM_SIZE - 1,
            w: ROOM_SIZE,
            h: ROOM_SIZE,
          });
        }

      // carve tunnel blocks as centered 3x3
      for (by in 0...grid.height)
        for (bx in 0...grid.width)
          {
            if (kinds[by][bx] != BLOCK_TUNNEL)
              continue;
            carveTunnelBlock(area, grid, bx, by);
          }

      // carve center-to-center links between adjacent blocks
      for (link in links)
        carveBlockLink(area, grid, link);

      return rooms;
    }

// carve one 3x3 tunnel block centered in a 7x7 block
  function carveTunnelBlock(area: AreaGame, grid: _SewerGrid,
      bx: Int, by: Int)
    {
      var sx = blockStartX(grid, bx);
      var sy = blockStartY(grid, by);
      var tunnelOffset = Std.int((BLOCK_SIZE - TUNNEL_SIZE) / 2);
      for (y in sy + tunnelOffset...sy + tunnelOffset + TUNNEL_SIZE)
        for (x in sx + tunnelOffset...sx + tunnelOffset + TUNNEL_SIZE)
          area.setCellType(x, y, Const.TILE_WALKWAY);
    }

// carve a 3-wide centerline link between two adjacent blocks
  function carveBlockLink(area: AreaGame, grid: _SewerGrid,
      link: _SewerBlockLink)
    {
      var x1 = blockCenterX(grid, link.bx1);
      var y1 = blockCenterY(grid, link.by1);
      var x2 = blockCenterX(grid, link.bx2);
      var y2 = blockCenterY(grid, link.by2);

      if (y1 == y2)
        {
          var xx1 = x1;
          var xx2 = x2;
          if (xx1 > xx2)
            {
              var tmp = xx1;
              xx1 = xx2;
              xx2 = tmp;
            }
          for (x in xx1...xx2 + 1)
            for (yy in y1 - 1...y1 + 2)
              area.setCellType(x, yy, Const.TILE_WALKWAY);
          return;
        }

      var yy1 = y1;
      var yy2 = y2;
      if (yy1 > yy2)
        {
          var tmp = yy1;
          yy1 = yy2;
          yy2 = tmp;
        }
      for (y in yy1...yy2 + 1)
        for (xx in x1 - 1...x1 + 2)
          area.setCellType(xx, y, Const.TILE_WALKWAY);
    }

// convert walkway markers into sewer floor and wall shell tiles
  function finalizeTiles(area: AreaGame)
    {
      var floorMap: Array<Array<Bool>> = [];
      for (x in 0...area.width)
        {
          floorMap[x] = [];
          for (y in 0...area.height)
            floorMap[x][y] = isFloorMarker(area.getCellType(x, y));
        }

      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (floorMap[x][y])
              {
                area.setCellType(x, y, Sewers.TILE_FLOOR);
                continue;
              }
            if (isWallShell(floorMap, x, y))
              area.setCellType(x, y, getWallTileID(floorMap, x, y));
            else
              {
                var tileID = getDiagonalCornerTileID(floorMap, x, y);
                if (tileID == Const.TILE_HIDDEN)
                  area.setCellType(x, y, Const.TILE_HIDDEN);
                else area.setCellType(x, y, tileID);
              }
          }
    }

// check whether current tile is still a pre-finalize floor marker
  inline function isFloorMarker(tile: Int): Bool
    {
      return tile == Const.TILE_WALKWAY;
    }

// check whether this cell should become a visible wall shell tile
  inline function isWallShell(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (getFloor(floorMap, x, y - 1) ||
        getFloor(floorMap, x, y + 1) ||
        getFloor(floorMap, x - 1, y) ||
        getFloor(floorMap, x + 1, y));
    }

// safely read floor-map occupancy
  inline function getFloor(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= floorMap.length ||
          y >= floorMap[x].length)
        return false;
      return floorMap[x][y];
    }

// map wall shell shape to one sewer wall tile id
  function getWallTileID(floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);

      if (e &&
          s &&
          !n &&
          !w)
        return Sewers.TILE_WALL_INNER_TOP_LEFT;
      if (w &&
          s &&
          !n &&
          !e)
        return Sewers.TILE_WALL_INNER_TOP_RIGHT;
      if (e &&
          n &&
          !s &&
          !w)
        return Sewers.TILE_WALL_INNER_BOTTOM_LEFT;
      if (w &&
          n &&
          !s &&
          !e)
        return Sewers.TILE_WALL_INNER_BOTTOM_RIGHT;

      if (n &&
          w &&
          !s &&
          !e)
        return Sewers.TILE_WALL_OUTER_TOP_LEFT;
      if (n &&
          e &&
          !s &&
          !w)
        return Sewers.TILE_WALL_OUTER_TOP_RIGHT;
      if (s &&
          w &&
          !n &&
          !e)
        return Sewers.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (s &&
          e &&
          !n &&
          !w)
        return Sewers.TILE_WALL_OUTER_BOTTOM_RIGHT;

      if (s && !n)
        return Sewers.TILE_WALL_UPPER;
      if (n && !s)
        return Sewers.TILE_WALL_LOWER;
      if (e && !w)
        return Sewers.TILE_WALL_LEFT;
      if (w && !e)
        return Sewers.TILE_WALL_RIGHT;

      if (s)
        return Sewers.TILE_WALL_UPPER;
      if (n)
        return Sewers.TILE_WALL_LOWER;
      if (e)
        return Sewers.TILE_WALL_LEFT;
      if (w)
        return Sewers.TILE_WALL_RIGHT;
      return Const.TILE_HIDDEN;
    }

// map single diagonal floor adjacency to an outer-corner wall tile
  inline function getDiagonalCornerTileID(
      floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);
      if (n || s || w || e)
        return Const.TILE_HIDDEN;

      var nw = getFloor(floorMap, x - 1, y - 1);
      var ne = getFloor(floorMap, x + 1, y - 1);
      var sw = getFloor(floorMap, x - 1, y + 1);
      var se = getFloor(floorMap, x + 1, y + 1);
      var diagonalFloors = 0;
      if (nw)
        diagonalFloors++;
      if (ne)
        diagonalFloors++;
      if (sw)
        diagonalFloors++;
      if (se)
        diagonalFloors++;
      if (diagonalFloors != 1)
        return Const.TILE_HIDDEN;

      if (nw)
        return Sewers.TILE_WALL_OUTER_TOP_LEFT;
      if (ne)
        return Sewers.TILE_WALL_OUTER_TOP_RIGHT;
      if (sw)
        return Sewers.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (se)
        return Sewers.TILE_WALL_OUTER_BOTTOM_RIGHT;
      return Const.TILE_HIDDEN;
    }

// place sewer exits in room centers
  function placeExits(area: AreaGame, rooms: Array<_Room>,
      ?options: SewerAreaGeneratorOptions)
    {
      if (rooms.length == 0)
        return;

      var exitsToPlace = getExitCount(rooms.length, options);
      if (exitsToPlace > rooms.length)
        exitsToPlace = rooms.length;
      if (exitsToPlace <= 0)
        return;

      // shuffle rooms to pick random ones
      var shuffled = [];
      for (room in rooms)
        shuffled.push(room);
      for (i in 0...shuffled.length)
        {
          var j = Std.random(shuffled.length);
          var tmp = shuffled[i];
          shuffled[i] = shuffled[j];
          shuffled[j] = tmp;
        }

      for (i in 0...exitsToPlace)
        {
          if (i >= shuffled.length)
            return;
          var room = shuffled[i];
          var cx = room.x1 + Std.int(room.w / 2);
          var cy = room.y1 + Std.int(room.h / 2);
          addExit(area, cx, cy, options);
        }
    }

// get number of exits to place
  function getExitCount(roomCount: Int,
      ?options: SewerAreaGeneratorOptions): Int
    {
      if (options != null &&
          options.exitCount != null)
        return Std.int(Math.max(0, options.exitCount));

      var exitsToPlace = 1;
      if (roomCount > 2)
        exitsToPlace += Std.random(Std.int(Math.min(3, roomCount)) - 1);
      return exitsToPlace;
    }

// add one exit object using configured exit behavior
  function addExit(area: AreaGame, x: Int, y: Int,
      ?options: SewerAreaGeneratorOptions)
    {
      if (options != null &&
          options.useHabitatExits)
        {
          area.addObject(new HabitatExit(game, area.id, x, y));
          return;
        }
      area.addObject(new SewerExit(game, area.id, x, y));
    }

// pick fallback exit tile when no junctions were found
  function findFallbackExit(area: AreaGame, rooms: Array<_Room>): { x: Int, y: Int }
    {
      for (y in 1...area.height - 1)
        for (x in 1...area.width - 1)
          if (area.getCellType(x, y) == Const.TILE_WALKWAY &&
              !isInsideAnyRoom(rooms, x, y))
            return { x: x, y: y };

      var room = rooms[0];
      return {
        x: room.x1 + Std.int(room.w / 2),
        y: room.y1 + Std.int(room.h / 2),
      };
    }

// check if tile belongs to any room rectangle
  function isInsideAnyRoom(rooms: Array<_Room>, x: Int, y: Int): Bool
    {
      for (room in rooms)
        if (x >= room.x1 &&
            x <= room.x2 &&
            y >= room.y1 &&
            y <= room.y2)
          return true;
      return false;
    }

// compute manhattan distance between block cells
  function blockDistance(a: _GridPos, b: _GridPos): Int
    {
      return Std.int(Math.abs(a.bx - b.bx) + Math.abs(a.by - b.by));
    }

// get x start of a block
  inline function blockStartX(grid: _SewerGrid, bx: Int): Int
    {
      return grid.startX + bx * BLOCK_SIZE;
    }

// get y start of a block
  inline function blockStartY(grid: _SewerGrid, by: Int): Int
    {
      return grid.startY + by * BLOCK_SIZE;
    }

// get x center of a block
  inline function blockCenterX(grid: _SewerGrid, bx: Int): Int
    {
      return blockStartX(grid, bx) + Std.int(BLOCK_SIZE / 2);
    }

// get y center of a block
  inline function blockCenterY(grid: _SewerGrid, by: Int): Int
    {
      return blockStartY(grid, by) + Std.int(BLOCK_SIZE / 2);
    }
}

// sewer mission area generation

package game;

import Const;
import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import objects.SewerExit;

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
  public function generate(area: AreaGame, info: AreaInfo)
    {
      // fill with walls first
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, Const.TILE_WALL);

      // build block layout and mark room blocks
      var grid = buildGrid(area);
      var blockKinds = buildBlockKindMap(grid);
      var roomBlocks = rollRoomBlocks(grid);
      markRoomBlocks(blockKinds, roomBlocks);

      // connect room blocks and mark tunnel blocks
      var links = connectRoomBlocks(grid, blockKinds, roomBlocks);

      // carve room/tunnel geometry from block plan
      var rooms = carveFromBlocks(area, grid, blockKinds, roomBlocks, links);

      // place exits on tunnel junctions
      placeExits(area, rooms);

      area.generatorInfo = {
        rooms: rooms,
        doors: [],
      };
    }

// build 7x7 block grid with no offset
  function buildGrid(area: AreaGame): _SewerGrid
    {
      var gw = Std.int(area.width / BLOCK_SIZE);
      var gh = Std.int(area.height / BLOCK_SIZE);
      if (gw < 1)
        gw = 1;
      if (gh < 1)
        gh = 1;

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
  function rollRoomBlocks(grid: _SewerGrid): Array<_GridPos>
    {
      var rooms = [];
      var total = grid.width * grid.height;

      var minRooms = Std.int(Math.max(6, Math.ceil(total * 0.16)));
      var maxRooms = Std.int(Math.max(minRooms, Math.floor(total * 0.28)));
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

// place sewer exits on tunnel junctions
  function placeExits(area: AreaGame, rooms: Array<_Room>)
    {
      var junctions = [];
      for (y in 1...area.height - 1)
        for (x in 1...area.width - 1)
          {
            if (area.getCellType(x, y) != Const.TILE_WALKWAY)
              continue;
            if (isInsideAnyRoom(rooms, x, y))
              continue;

            var cnt = 0;
            if (area.getCellType(x - 1, y) == Const.TILE_WALKWAY)
              cnt++;
            if (area.getCellType(x + 1, y) == Const.TILE_WALKWAY)
              cnt++;
            if (area.getCellType(x, y - 1) == Const.TILE_WALKWAY)
              cnt++;
            if (area.getCellType(x, y + 1) == Const.TILE_WALKWAY)
              cnt++;
            if (cnt >= 3)
              junctions.push({ x: x, y: y });
          }

      if (junctions.length == 0)
        {
          var fallback = findFallbackExit(area, rooms);
          area.addObject(new SewerExit(game, area.id, fallback.x, fallback.y));
          return;
        }

      var exitsToPlace = 1;
      if (junctions.length > 2)
        exitsToPlace += Std.random(Std.int(Math.min(3, junctions.length)) - 1);

      for (_ in 0...exitsToPlace)
        {
          if (junctions.length == 0)
            return;
          var pick = junctions[Std.random(junctions.length)];
          junctions.remove(pick);
          area.addObject(new SewerExit(game, area.id, pick.x, pick.y));
        }
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

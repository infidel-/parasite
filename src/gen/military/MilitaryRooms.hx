// what a military building's rooms hold
//
// the shared building pass (gen.facility.FacilityBuilding) lays the walls, the corridors and the
// rooms, gen.facility.FacilityRooms.militaryThemes deals each room a kind, and gen.blocks.RoomBlock
// glazes it and hands it here. Every kind stands its furniture as Const row-20 tiles (or, for the
// armory, as objects) and paints the room's floor LAST, while FacilityRooms.roomWallRuns can still
// tell bare floor from what was stood on it. render.military.MilitaryInterior draws all of it.
//
// NOTHING HERE MAY SEAL A CELL OFF. Furniture goes against a wall, never on a cell beside a door,
// and a free-standing table keeps a full cell clear round it; gen.GenCheck.floorReachable asserts it

package gen.military;

import gen.facility._FacilityState;
import gen.facility.FacilityRooms;
import gen.facility.FacilityTemp.*;

class MilitaryRooms
{
  // how many lockers one armory takes at most, the gun cabinet and the safe not counted
  public static inline var LOCKERS_MAX = 5;
  // a bunk's depth off its wall, its footlocker included, and the aisle a room keeps past them
  static inline var BUNK_DEPTH = 3;
  // wall lockers in one barracks room, between the bunks
  static inline var BARRACKS_LOCKERS = 3;
  // an HQ office's desks (each two cells along its wall, one per this many cells of perimeter)
  // and filing cabinets
  static inline var DESK_PER = 8;
  static inline var FILES_MAX = 2;
  // a latrine's cubicles and trough cells
  static inline var STALLS_MAX = 4;
  static inline var TROUGH_MAX = 3;

// furnish one room by its kind, then floor it
  public static function fill(state: _FacilityState, room: _Room)
    {
      var floor = Const.TILE_MIL_FLOOR_HQ;
      switch (room.role)
        {
          case ROLE_ARMORY:
            armory(state, room);
          case ROLE_HQ:
            office(state, room);
          case ROLE_BRIEFING:
            briefing(state, room);
            floor = Const.TILE_MIL_FLOOR_BRIEFING;
          case ROLE_MESS:
            mess(state, room);
            floor = Const.TILE_MIL_FLOOR_MESS;
          case ROLE_BARRACKS:
            barracks(state, room);
            floor = Const.TILE_MIL_FLOOR_BARRACKS;
          case ROLE_LATRINE:
            latrine(state, room);
            floor = Const.TILE_MIL_FLOOR_LATRINE;
          default:
        }
      FacilityRooms.paintRoomFloor(state, room, floor, floor);
    }

// rows of bunks out from the long walls — both when the room is deep enough for two rows and an
// aisle, one otherwise — a bunk on every other wall cell, its footlocker at its foot, and wall
// lockers in the gaps between them
  static function barracks(state: _FacilityState, room: _Room)
    {
      var runs = FacilityRooms.roomWallRuns(state, room);
      var alongX = (room.w >= room.h);
      var depth = (alongX ? room.h : room.w);
      // the two long walls are runs 0/1 (top, bottom) on a wide room and 2/3 (left, right) on a tall one
      var walls = (alongX ? [ 0, 1 ] : [ 2, 3 ]);
      if (depth < BUNK_DEPTH * 2 + 1)
        walls = [ walls[0] ];
      // too shallow to stand them out from the wall: lay them ALONG it instead
      if (depth < BUNK_DEPTH + 1)
        {
          if (depth >= 2)
            bunksAlong(state, runs[walls[0]]);
          return;
        }
      var lockers = 0;
      for (w in walls)
        {
          var dx = INWARD_X[w];
          var dy = INWARD_Y[w];
          var last = -2;
          var run = runs[w];
          for (k in 0...run.length)
            {
              var c = run[k];
              var at = (alongX ? c.x : c.y);
              // the cell straight after a bunk is the gap between two, where a wall locker goes
              if (at - last == 1)
                {
                  if (lockers < BARRACKS_LOCKERS &&
                      free(state, c.x, c.y))
                    {
                      state.area.add('locker', c.x, c.y);
                      lockers++;
                    }
                  continue;
                }
              var ok = true;
              for (i in 0...BUNK_DEPTH)
                if (!free(state, c.x + dx * i, c.y + dy * i))
                  ok = false;
              if (!ok)
                continue;
              stand(state, c.x, c.y, Const.TILE_MIL_BUNK);
              stand(state, c.x + dx, c.y + dy, Const.TILE_MIL_BUNK);
              stand(state, c.x + dx * 2, c.y + dy * 2, Const.TILE_MIL_FOOTLOCKER);
              last = at;
            }
        }
    }

// a shallow barracks' bunks, each two cells along the wall with its footlocker after it and a
// cell clear before the next, so the strip in front of them stays a corridor
  static function bunksAlong(state: _FacilityState, run: Array<{ x: Int, y: Int }>)
    {
      var k = 0;
      while (k + 2 < run.length)
        {
          var a = run[k];
          var b = run[k + 1];
          var c = run[k + 2];
          // three cells in a straight unbroken line, which a run with a doorway cut out of it is not
          if (Math.abs(c.x - a.x) + Math.abs(c.y - a.y) == 2 &&
              free(state, a.x, a.y) &&
              free(state, b.x, b.y) &&
              free(state, c.x, c.y))
            {
              stand(state, a.x, a.y, Const.TILE_MIL_BUNK);
              stand(state, b.x, b.y, Const.TILE_MIL_BUNK);
              stand(state, c.x, c.y, Const.TILE_MIL_FOOTLOCKER);
              k += 4;
            }
          else
            k++;
        }
    }

// tables in rows down the room's long axis, a bench either side of each, an aisle between pairs,
// a cell clear all round them, and the serving counter along one end wall
  static function mess(state: _FacilityState, room: _Room)
    {
      var alongX = (room.w >= room.h);
      // the counter on the end wall: run 2 (left) on a wide room, run 0 (top) on a tall one
      var runs = FacilityRooms.roomWallRuns(state, room);
      for (c in runs[alongX ? 2 : 0])
        if (free(state, c.x, c.y))
          stand(state, c.x, c.y, Const.TILE_MIL_COUNTER);
      tableRows(state, room, alongX, Const.TILE_MIL_MESS_TABLE, true);
    }

// one long table down the middle with a bench each side, and the map board on an end wall
  static function briefing(state: _FacilityState, room: _Room)
    {
      var alongX = (room.w >= room.h);
      var runs = FacilityRooms.roomWallRuns(state, room);
      var end = runs[alongX ? 2 : 0];
      if (end.length > 0)
        {
          var c = end[Std.int(end.length / 2)];
          stand(state, c.x, c.y, Const.TILE_MIL_MAP_BOARD);
        }
      tableRows(state, room, alongX, Const.TILE_MIL_BRIEF_TABLE, false);
    }

// the rows of a mess hall or the one table of a briefing room. Cells from 2 in off the end walls
// (a cell for the counter or the board and one to walk past it) and from 1 in off the side walls;
// across that band a row is bench, table, bench, then an aisle when `many` asks for another
  static function tableRows(state: _FacilityState, room: _Room, alongX: Bool, table: Int, many: Bool)
    {
      var len = (alongX ? room.w : room.h);
      var span = (alongX ? room.h : room.w);
      if (len < 5 ||
          span < 3)
        return;
      var benches = (span >= 5);
      var row = (benches ? 3 : 1);
      // where the band starts across the room: centred when there is one row
      var first = (many ? 1 : Std.int((span - row) / 2));
      var at = first;
      while (at + row <= span - 1)
        {
          for (i in 2...len - 2)
            for (j in 0...row)
              {
                var tile = (benches && j != 1 ? Const.TILE_MIL_BENCH : table);
                var x = (alongX ? room.x1 + i : room.x1 + at + j);
                var y = (alongX ? room.y1 + at + j : room.y1 + i);
                if (free(state, x, y))
                  stand(state, x, y, tile);
              }
          if (!many)
            break;
          at += row + 1;
        }
    }

// a desk or two against the walls, each two cells along it, and a filing cabinet or two
  static function office(state: _FacilityState, room: _Room)
    {
      var runs = FacilityRooms.roomWallRuns(state, room);
      runs.sort(function(a, b) return b.length - a.length);
      var desks = 0;
      var files = 0;
      // a desk for every eight cells of the room's perimeter, one at least
      var desksMax = Std.int(Math.max(1, (room.w + room.h) * 2 / DESK_PER));
      for (run in runs)
        {
          var k = 0;
          while (k < run.length)
            {
              var c = run[k];
              var n = (k + 1 < run.length ? run[k + 1] : null);
              if (desks < desksMax &&
                  n != null &&
                  Math.abs(n.x - c.x) + Math.abs(n.y - c.y) == 1 &&
                  free(state, c.x, c.y) &&
                  free(state, n.x, n.y))
                {
                  stand(state, c.x, c.y, Const.TILE_MIL_DESK);
                  stand(state, n.x, n.y, Const.TILE_MIL_DESK);
                  desks++;
                  k += 3;
                  continue;
                }
              if (files < FILES_MAX &&
                  free(state, c.x, c.y))
                {
                  stand(state, c.x, c.y, Const.TILE_MIL_FILE);
                  files++;
                  k += 2;
                  continue;
                }
              // a blocked cell (a doorway's neighbour, a corner pocket) ends nothing: the rest of
              // the wall may still take a desk. It used to break, and most offices got one or none
              k++;
            }
        }
    }

// a row of cubicles down the longest wall and the trough down the one facing it
  static function latrine(state: _FacilityState, room: _Room)
    {
      var runs = FacilityRooms.roomWallRuns(state, room);
      var best = 0;
      for (i in 1...4)
        if (runs[i].length > runs[best].length)
          best = i;
      for (k in 0...Std.int(Math.min(STALLS_MAX, runs[best].length)))
        if (free(state, runs[best][k].x, runs[best][k].y))
          stand(state, runs[best][k].x, runs[best][k].y, Const.TILE_MIL_STALL);
      // the facing wall is the other of the pair: 0 with 1, 2 with 3
      var face = runs[best ^ 1];
      for (k in 0...Std.int(Math.min(TROUGH_MAX, face.length)))
        if (free(state, face[k].x, face[k].y))
          stand(state, face[k].x, face[k].y, Const.TILE_MIL_TROUGH);
    }

// may furniture stand on this cell: still bare room floor with nothing on it, no doorway beside
// it, and no bare neighbour that it would leave with no other bare floor beside it — the one-cell
// pocket two pieces meeting at a corner close
  static function free(state: _FacilityState, x: Int, y: Int): Bool
    {
      var cells = state.area.getCells();
      if (cells[x][y] != TEMP_BUILDING_ROOM ||
          state.area.hasObjectAt(x, y))
        return false;
      for (i in 0...Const.dir4x.length)
        {
          var nx = x + Const.dir4x[i];
          var ny = y + Const.dir4y[i];
          var t = cells[nx][ny];
          if (isDoor(t))
            return false;
          if (t != TEMP_BUILDING_ROOM)
            continue;
          var exits = 0;
          for (j in 0...Const.dir4x.length)
            {
              var ex = nx + Const.dir4x[j];
              var ey = ny + Const.dir4y[j];
              // the doorway is NOT an exit: the cell inside a door, boxed in by a cabinet and a
              // desk, still has the door and cut the whole room off from it (seed 455)
              if ((ex != x || ey != y) &&
                  cells[ex][ey] == TEMP_BUILDING_ROOM)
                exits++;
            }
          if (exits == 0)
            return false;
        }
      return true;
    }

// is this temp id a doorway of any kind?
  static inline function isDoor(t: Int): Bool
    {
      return t == TEMP_BUILDING_INNER_DOOR ||
        t == TEMP_BUILDING_SIDE_DOOR ||
        t == TEMP_BUILDING_FRONT_DOOR;
    }

// stand a piece of furniture on a cell
  static inline function stand(state: _FacilityState, x: Int, y: Int, tile: Int)
    {
      state.area.getCells()[x][y] = tile;
    }

  // the step INTO the room from each of roomWallRuns' four walls: top, bottom, left, right
  static var INWARD_X = [ 0, 0, 1, -1 ];
  static var INWARD_Y = [ 1, -1, 0, 0 ];

// stand the lockers, the gun cabinet and (in the first armory dealt, which is the HQ's) the safe on
// this store's free wall cells.
//
// they are OBJECTS on plain floor, like the corp security room's gun cabinet: each stands in its
// wall's margin and its cell stays walkable, so nothing here can seal the room. The cabinet stands in
// the middle of the longest free wall with the lockers either side, spilling onto the next walls, and
// the safe goes on the second wall. NEVER IN A CORNER, for the cabinet's own reason: the render turns
// each one by its wall, and a corner has two
  public static function armory(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var runs = [for (run in FacilityRooms.roomWallRuns(state, room))
        [for (c in run) if (!corner(room, c.x, c.y)) c]];
      runs.sort(function(a, b) return b.length - a.length);
      if (runs[0].length == 0)
        return;
      // the safe takes the second wall's first cell, or the first wall's last when there is no second
      if (area.countSpawns('safe') == 0)
        {
          var run = (runs[1].length > 0 ? runs[1] : runs[0]);
          var c = (run == runs[0] ? run.pop() : run.shift());
          area.add('safe', c.x, c.y);
        }
      // the cabinet in the middle of the longest run, lockers either side of it and on down the
      // other walls in turn
      var lockers = 0;
      for (i in 0...runs.length)
        {
          var mid = (i == 0 ? Std.int(Math.min(runs[0].length, LOCKERS_MAX + 1) / 2) : -1);
          for (k in 0...runs[i].length)
            {
              if (k == mid)
                area.add('gunCabinet', runs[i][k].x, runs[i][k].y);
              else if (lockers < LOCKERS_MAX)
                {
                  area.add('locker', runs[i][k].x, runs[i][k].y);
                  lockers++;
                }
            }
        }
    }

// is this cell one of the room's four corners?
  static inline function corner(room: _Room, x: Int, y: Int): Bool
    {
      return (x == room.x1 || x == room.x2) &&
        (y == room.y1 || y == room.y2);
    }
}

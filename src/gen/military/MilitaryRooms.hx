// what a military building's zones hold
//
// the shared building pass (gen.facility.FacilityBuilding) lays the walls, the corridors and the
// rooms, gen.facility.FacilityRooms.militaryThemes deals each room a role, gen.military.MilitaryZones
// gives the role its room kind, divides the room into bays and deals the kind's zones over them, and
// gen.blocks.RoomBlock's walk hands every zone here. Each zone stands its furniture as Const row-20/21
// tiles (or, for the armory, as objects), and the room's `mil-floor` paints its floor after all of
// them, while FacilityRooms.roomWallRuns can still tell bare floor from what was stood on it.
// render.military.MilitaryInterior draws all of it.
//
// NOTHING HERE MAY SEAL A CELL OFF. Furniture goes against a wall, never on a cell beside a door,
// and a free-standing table keeps a full cell clear round it; gen.GenCheck.floorReachable asserts it

package gen.military;

import gen.blocks.RoomBlock;
import gen.facility._FacilityState;
import gen.facility.FacilityRooms;
import gen.facility.FacilityTemp.*;
import gen.military.MilitaryZones.*;

class MilitaryRooms
{
  // how many lockers one armory takes at most, the gun cabinet and the safe not counted
  public static inline var LOCKERS_MAX = 5;
  // wall lockers in one barracks room, between the bunks
  static inline var BARRACKS_LOCKERS = 3;
  // an HQ office's desks (each two cells along its wall, one per this many cells of perimeter)
  // and filing cabinets
  static inline var DESK_PER = 8;
  static inline var FILES_MAX = 4;
  // free-standing pieces in a room's middle: an office's desk pairs, an armory's or a store's crate
  // stacks
  static inline var DESK_ISLANDS = 2;
  static inline var CRATE_ISLANDS = 4;
  // a comms room's radio racks and two-cell consoles
  static inline var RACKS_MAX = 4;
  static inline var CONSOLES_MAX = 2;
  // a store's shelves
  static inline var SHELVES_MAX = 10;
  // a medical bay's cots and cabinets
  static inline var COTS_MAX = 6;
  static inline var COT_ISLANDS = 2;
  static inline var MEDCABS_MAX = 2;
  // a latrine's cubicles and trough cells
  static inline var STALLS_MAX = 4;
  static inline var TROUGH_MAX = 3;
  // the mark a zone gets when it stood nothing, counted by gen.GenRun
  public static inline var TAG_EMPTY = 'empty';

// fill one zone of a base room. A zone that stood nothing is tagged, so the stats can say which
// kind keeps coming out bare
  public static function fill(state: _FacilityState, room: _Room, node: _GenNode)
    {
      var cells = RoomBlock.cellsOf(node);
      var n = switch (node.kind)
        {
          case BUNK_ROW: bunkRow(state, room, node);
          case BUNK_ALONG: bunksAlong(state, cells);
          case DESK_RUN: deskRun(state, room, cells);
          case FILE_RUN: fileRun(state, room, cells);
          case DESK_ISLAND: islands(state, room, (room.w >= room.h ? 2 : 1),
            (room.w >= room.h ? 1 : 2), Const.TILE_MIL_DESK,
            (room.role == ROLE_COMMS ? 1 : DESK_ISLANDS));
          case RACK_RUN: line(state, room, cells, Const.TILE_MIL_RADIO_RACK, RACKS_MAX, 1);
          case CONSOLE_RUN: consoleRun(state, room, cells);
          case SHELVING: line(state, room, cells, Const.TILE_MIL_SHELF, SHELVES_MAX, 1);
          case CRATE_ISLAND: islands(state, room, 1, 1, Const.TILE_MIL_CRATES, CRATE_ISLANDS);
          case COT_RUN: line(state, room, cells, Const.TILE_MIL_COT, COTS_MAX, 2);
          case CABINET_RUN: line(state, room, cells, Const.TILE_MIL_MED_CABINET, MEDCABS_MAX, 1);
          case COT_ISLAND: islands(state, room, 1, 1, Const.TILE_MIL_COT, COT_ISLANDS);
          case COUNTER_RUN: line(state, room, cells, Const.TILE_MIL_COUNTER, 99, 1);
          case TABLE_ROWS: tableRows(state, room, (room.w >= room.h),
            (room.role == ROLE_MESS ? Const.TILE_MIL_MESS_TABLE : Const.TILE_MIL_BRIEF_TABLE),
            room.role == ROLE_MESS);
          case BOARD: board(state, cells);
          case CUBICLES: line(state, room, cells, Const.TILE_MIL_STALL, STALLS_MAX, 1);
          case TROUGH_RUN: line(state, room, cells, Const.TILE_MIL_TROUGH, TROUGH_MAX, 1);
          case GUN_CABINET: gunCabinet(state, room, cells);
          case SAFE: safe(state, room, cells);
          case LOCKER_RUN: lockers(state, room, cells);
          case FLOOR: floor(state, room);
          case SLOT: slot(state, room, node, cells);
          default: 1;
        }
      if (n == 0)
        node.tags = (node.tags == null ? [] : node.tags).concat([ TAG_EMPTY ]);
    }

// the standing props a room of this role takes in the bays its zones left over, in the order it takes
// them, one of each at most. The barracks takes none: its rifle rack was reported as not belonging
// there, the weapons are the armory's
  static function propsOf(role: String): Array<Int>
    {
      return switch (role)
        {
          case ROLE_ARMORY: [ Const.TILE_MIL_RIFLE_RACK, Const.TILE_MIL_AMMO_CANS ];
          case ROLE_SUPPLY: [ Const.TILE_MIL_JERRYCANS, Const.TILE_MIL_AMMO_CANS ];
          case ROLE_MEDICAL: [ Const.TILE_MIL_IV_STAND, Const.TILE_MIL_STRETCHER ];
          case ROLE_HQ: [ Const.TILE_MIL_FLAG, Const.TILE_MIL_WATER_COOLER ];
          case ROLE_BRIEFING: [ Const.TILE_MIL_FLAG ];
          case ROLE_MESS, ROLE_COMMS: [ Const.TILE_MIL_WATER_COOLER ];
          default: [];
        };
    }

// a leftover wall bay of a base room: the next of the room's standing props it does not have yet, on
// the free cell nearest the bay's middle. The rooms were reported as empty, and these bays are where
// nothing stood. A leftover floor bay takes nothing: the middle of a room is where it is walked
  static function slot(state: _FacilityState, room: _Room, node: _GenNode,
      run: Array<{ x: Int, y: Int }>): Int
    {
      if (RoomBlock.tagged(node, TAG_FLOOR))
        return 1;
      for (tile in propsOf(room.role))
        {
          if (tilesIn(state, room, tile) > 0)
            continue;
          var mid = Std.int(run.length / 2);
          for (k in 0...run.length)
            {
              var c = run[mid + (k % 2 == 0 ? Std.int(k / 2) : -Std.int(k / 2) - 1)];
              if (c == null ||
                  !free(state, c.x, c.y))
                continue;
              // a prop in a bay is the one piece a zone does not plan round, and the first build
              // stood a barracks' rifle rack in the aisle its bunk rows left (3208 floor cells
              // cut off over 500 seeds): it stays only if every bare cell can still be walked to
              stand(state, c.x, c.y, tile);
              if (!sealsOff(state, room))
                return 1;
              stand(state, c.x, c.y, TEMP_BUILDING_ROOM);
            }
          return 1;
        }
      return 1;
    }

// is the room's bare floor no longer ONE piece? Reachable from some doorway is not enough: two rooms
// side by side each split by a prop left a pocket in each that only opened onto the other's (seed 10)
  static function sealsOff(state: _FacilityState, room: _Room): Bool
    {
      var cells = state.area.getCells();
      var seen = new Map<Int, Bool>();
      var open = [];
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (open.length == 0 &&
              cells[x][y] == TEMP_BUILDING_ROOM)
            {
              seen.set(x * 1000 + y, true);
              open.push({ x: x, y: y });
            }
      while (open.length > 0)
        {
          var c = open.pop();
          for (i in 0...Const.dir4x.length)
            {
              var x = c.x + Const.dir4x[i];
              var y = c.y + Const.dir4y[i];
              if (x < room.x1 ||
                  x > room.x2 ||
                  y < room.y1 ||
                  y > room.y2 ||
                  cells[x][y] != TEMP_BUILDING_ROOM ||
                  seen.exists(x * 1000 + y))
                continue;
              seen.set(x * 1000 + y, true);
              open.push({ x: x, y: y });
            }
        }
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (cells[x][y] == TEMP_BUILDING_ROOM &&
              !seen.exists(x * 1000 + y))
            return true;
      return false;
    }

// paint the room's floor once its zones have stood their furniture, by its role. An armory whose
// zones found no second wall for the safe takes it here, on any wall cell left
  static function floor(state: _FacilityState, room: _Room): Int
    {
      var floor = switch (room.role)
        {
          case ROLE_SUPPLY, ROLE_BARRACKS: Const.TILE_MIL_FLOOR_BARRACKS;
          case ROLE_BRIEFING: Const.TILE_MIL_FLOOR_BRIEFING;
          case ROLE_MESS: Const.TILE_MIL_FLOOR_MESS;
          case ROLE_LATRINE: Const.TILE_MIL_FLOOR_LATRINE;
          default: Const.TILE_MIL_FLOOR_HQ;
        }
      if (room.role == ROLE_ARMORY &&
          state.area.countSpawns('safe') == 0)
        for (run in FacilityRooms.roomWallRuns(state, room))
          if (safe(state, room, run) > 0)
            break;
      FacilityRooms.paintRoomFloor(state, room, floor, floor);
      return 1;
    }

// one bay of bunks stood out from its wall, a bunk on every other wall cell with its footlocker at
// its foot, and a wall locker in the gaps between them
  static function bunkRow(state: _FacilityState, room: _Room, node: _GenNode): Int
    {
      var w = MilitaryZones.wallOf(node);
      var dx = INWARD_X[w];
      var dy = INWARD_Y[w];
      var lockers = objectsIn(state, room, 'locker');
      var last = -2;
      var n = 0;
      for (c in RoomBlock.cellsOf(node))
        {
          var at = (w < 2 ? c.x : c.y);
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
          n++;
        }
      return n;
    }

// a shallow barracks' bunks, each two cells along the wall with its footlocker after it and a
// cell clear before the next, so the strip in front of them stays a corridor
  static function bunksAlong(state: _FacilityState, run: Array<{ x: Int, y: Int }>): Int
    {
      var k = 0;
      var n = 0;
      while (k + 2 < run.length)
        {
          var a = run[k];
          var b = run[k + 1];
          var c = run[k + 2];
          if (free(state, a.x, a.y) &&
              free(state, b.x, b.y) &&
              free(state, c.x, c.y))
            {
              stand(state, a.x, a.y, Const.TILE_MIL_BUNK);
              stand(state, b.x, b.y, Const.TILE_MIL_BUNK);
              stand(state, c.x, c.y, Const.TILE_MIL_FOOTLOCKER);
              k += 4;
              n++;
            }
          else
            k++;
        }
      return n;
    }

// the rows of a mess hall or the one table of a briefing room. Cells from 2 in off the end walls
// (a cell for the counter or the board and one to walk past it) and from 1 in off the side walls;
// across that band a row is bench, table, bench, then an aisle when `many` asks for another
  static function tableRows(state: _FacilityState, room: _Room, alongX: Bool, table: Int,
      many: Bool): Int
    {
      var len = (alongX ? room.w : room.h);
      var span = (alongX ? room.h : room.w);
      if (len < 5 ||
          span < 3)
        return 0;
      var benches = (span >= 5);
      var row = (benches ? 3 : 1);
      // where the band starts across the room: centred when there is one row
      var first = (many ? 1 : Std.int((span - row) / 2));
      var at = first;
      var n = 0;
      while (at + row <= span - 1)
        {
          for (i in 2...len - 2)
            for (j in 0...row)
              {
                var tile = (benches && j != 1 ? Const.TILE_MIL_BENCH : table);
                var x = (alongX ? room.x1 + i : room.x1 + at + j);
                var y = (alongX ? room.y1 + at + j : room.y1 + i);
                if (free(state, x, y))
                  {
                    stand(state, x, y, tile);
                    n++;
                  }
              }
          if (!many)
            break;
          at += row + 1;
        }
      return n;
    }

// one wall bay of an office: a desk every two cells, a cell clear after each, and a filing cabinet
// on a cell a desk does not fit. A desk for every eight cells of the room's perimeter, one at least
  static function deskRun(state: _FacilityState, room: _Room, run: Array<{ x: Int, y: Int }>): Int
    {
      var desks = Std.int(tilesIn(state, room, Const.TILE_MIL_DESK) / 2);
      var files = tilesIn(state, room, Const.TILE_MIL_FILE);
      var desksMax = Std.int(Math.max(1, (room.w + room.h) * 2 / DESK_PER));
      var n = 0;
      var k = 0;
      while (k < run.length)
        {
          var c = run[k];
          var e = (k + 1 < run.length ? run[k + 1] : null);
          if (desks < desksMax &&
              e != null &&
              free(state, c.x, c.y) &&
              free(state, e.x, e.y))
            {
              stand(state, c.x, c.y, Const.TILE_MIL_DESK);
              stand(state, e.x, e.y, Const.TILE_MIL_DESK);
              desks++;
              n++;
              k += 3;
              continue;
            }
          if (files < FILES_MAX &&
              free(state, c.x, c.y))
            {
              stand(state, c.x, c.y, Const.TILE_MIL_FILE);
              files++;
              n++;
              k += 2;
              continue;
            }
          // a blocked cell (a corner pocket) ends nothing: the rest of the bay may still take a desk
          k++;
        }
      return n;
    }

// an office's filing: a cabinet on every other cell of the bay
  static function fileRun(state: _FacilityState, room: _Room, run: Array<{ x: Int, y: Int }>): Int
    {
      return line(state, room, run, Const.TILE_MIL_FILE, FILES_MAX, 2);
    }

// a comms room's two-cell consoles along one bay, a cell clear between them
  static function consoleRun(state: _FacilityState, room: _Room,
      run: Array<{ x: Int, y: Int }>): Int
    {
      var consoles = Std.int(tilesIn(state, room, Const.TILE_MIL_CONSOLE) / 2);
      var n = 0;
      var k = 0;
      while (k + 1 < run.length &&
          consoles < CONSOLES_MAX)
        {
          var c = run[k];
          var e = run[k + 1];
          if (free(state, c.x, c.y) &&
              free(state, e.x, e.y))
            {
              stand(state, c.x, c.y, Const.TILE_MIL_CONSOLE);
              stand(state, e.x, e.y, Const.TILE_MIL_CONSOLE);
              consoles++;
              n++;
              k += 3;
            }
          else
            k++;
        }
      return n;
    }

// `tile` on every `step`th free cell of a bay, until the room holds `max` of it
  static function line(state: _FacilityState, room: _Room, run: Array<{ x: Int, y: Int }>,
      tile: Int, max: Int, step: Int): Int
    {
      var have = tilesIn(state, room, tile);
      var n = 0;
      for (k in 0...run.length)
        {
          var c = run[k];
          if (k % step == 0 &&
              have < max &&
              free(state, c.x, c.y))
            {
              stand(state, c.x, c.y, tile);
              have++;
              n++;
            }
        }
      return n;
    }

// the map board on the middle cell of its bay. It hangs on the wall, so its cell only has to be
// floor: the board takes the cell's tile and nothing stands in front of it
  static function board(state: _FacilityState, run: Array<{ x: Int, y: Int }>): Int
    {
      var c = run[Std.int(run.length / 2)];
      stand(state, c.x, c.y, Const.TILE_MIL_MAP_BOARD);
      return 1;
    }

// up to `max` free-standing blocks of `tile`, bw x bh cells, nearest the room's middle first. Each
// keeps a whole ring of bare floor round it, so it cuts nothing off, and two never touch
  static function islands(state: _FacilityState, room: _Room, bw: Int, bh: Int, tile: Int,
      max: Int): Int
    {
      var cells = state.area.getCells();
      var spots = [];
      for (x in room.x1 + 1...room.x2 - bw + 1)
        for (y in room.y1 + 1...room.y2 - bh + 1)
          spots.push({
            x: x,
            y: y,
            d: Std.int(Math.pow(x * 2 + bw - room.x1 - room.x2, 2) +
              Math.pow(y * 2 + bh - room.y1 - room.y2, 2)),
          });
      spots.sort(function(a, b) return a.d - b.d);
      var n = 0;
      for (s in spots)
        {
          if (n >= max)
            break;
          var ok = true;
          for (x in s.x - 1...s.x + bw + 1)
            for (y in s.y - 1...s.y + bh + 1)
              if (cells[x][y] != TEMP_BUILDING_ROOM ||
                  state.area.hasObjectAt(x, y))
                ok = false;
          if (!ok)
            continue;
          for (x in s.x...s.x + bw)
            for (y in s.y...s.y + bh)
              stand(state, x, y, tile);
          n++;
        }
      return n;
    }

// how many cells of the room hold `tile`
  static function tilesIn(state: _FacilityState, room: _Room, tile: Int): Int
    {
      var cells = state.area.getCells();
      var n = 0;
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (cells[x][y] == tile)
            n++;
      return n;
    }

// how many objects of `type` stand in the room
  static function objectsIn(state: _FacilityState, room: _Room, type: String): Int
    {
      var n = 0;
      for (s in state.area.spawns)
        if (s.type == type &&
            s.x >= room.x1 &&
            s.x <= room.x2 &&
            s.y >= room.y1 &&
            s.y <= room.y2)
          n++;
      return n;
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

// the armory's pieces are OBJECTS on plain floor, like the corp security room's gun cabinet: each
// stands in its wall's margin and its cell stays walkable, so nothing here can seal the room. NEVER
// IN A CORNER, for the cabinet's own reason: the render turns each one by its wall, and a corner has
// two. A cell is usable when it is bare floor with nothing on it yet
  static function wallSpot(state: _FacilityState, room: _Room, x: Int, y: Int): Bool
    {
      return state.area.getCells()[x][y] == TEMP_BUILDING_ROOM &&
        !state.area.hasObjectAt(x, y) &&
        !corner(room, x, y);
    }

// the gun cabinet in the middle of the armory's longest bay, its lockers either side of it
  static function gunCabinet(state: _FacilityState, room: _Room,
      run: Array<{ x: Int, y: Int }>): Int
    {
      var spots = [for (c in run) if (wallSpot(state, room, c.x, c.y)) c];
      if (spots.length == 0)
        return 0;
      var mid = Std.int(Math.min(spots.length, LOCKERS_MAX + 1) / 2);
      state.area.add('gunCabinet', spots[mid].x, spots[mid].y);
      spots.splice(mid, 1);
      return 1 + lockers(state, room, spots);
    }

// the base's one safe, on the first usable cell of its bay
  static function safe(state: _FacilityState, room: _Room, run: Array<{ x: Int, y: Int }>): Int
    {
      for (c in run)
        if (wallSpot(state, room, c.x, c.y))
          {
            state.area.add('safe', c.x, c.y);
            return 1;
          }
      return 0;
    }

// lockers down a bay, until the armory holds LOCKERS_MAX
  static function lockers(state: _FacilityState, room: _Room, run: Array<{ x: Int, y: Int }>): Int
    {
      var have = objectsIn(state, room, 'locker');
      var n = 0;
      for (c in run)
        if (have < LOCKERS_MAX &&
            wallSpot(state, room, c.x, c.y))
          {
            state.area.add('locker', c.x, c.y);
            have++;
            n++;
          }
      return n;
    }

// is this cell one of the room's four corners?
  static inline function corner(room: _Room, x: Int, y: Int): Bool
    {
      return (x == room.x1 || x == room.x2) &&
        (y == room.y1 || y == room.y2);
    }
}

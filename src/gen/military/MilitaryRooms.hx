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
  // free-standing pieces in a room's middle: an armory's or a store's crate stacks
  static inline var CRATE_ISLANDS = 4;
  // a comms room's radio racks and two-cell consoles
  static inline var RACKS_MAX = 4;
  static inline var CONSOLES_MAX = 2;
  // a medical bay's cots and cabinets
  static inline var COTS_MAX = 10;
  static inline var COT_ISLANDS = 2;
  static inline var MEDCABS_MAX = 2;
  // a latrine's cubicles and basin cells (two basins to a cell)
  static inline var STALLS_MAX = 4;
  static inline var SINKS_MAX = 3;
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
          case DESK_ISLAND: deskIsland(state, room);
          case RACK_RUN: line(state, room, cells, Const.TILE_MIL_RADIO_RACK, RACKS_MAX, 1);
          case CONSOLE_RUN: consoleRun(state, room, cells);
          case SHELVING: shelving(state, cells);
          case SHELF_ROW: shelfRows(state, room);
          case CRATE_ISLAND: crateIslands(state, room);
          case COT_RUN: line(state, room, cells, Const.TILE_MIL_COT, COTS_MAX,
            (MilitaryZones.wallOf(node) < 2 ? 1 : 2));
          case CABINET_RUN: line(state, room, cells, Const.TILE_MIL_MED_CABINET, MEDCABS_MAX, 1);
          case COT_ISLAND: cotIsland(state, room);
          case COUNTER_RUN: line(state, room, cells, Const.TILE_MIL_COUNTER, 99, 1);
          case TABLE_ROWS: tableRows(state, room, (room.w >= room.h),
            (room.role == ROLE_MESS ? Const.TILE_MIL_MESS_TABLE : Const.TILE_MIL_BRIEF_TABLE),
            room.role == ROLE_MESS);
          case BOARD: board(state, cells);
          case CUBICLES: line(state, room, cells, Const.TILE_MIL_STALL, STALLS_MAX, 1);
          case SINK_RUN: line(state, room, cells, Const.TILE_MIL_SINKS, SINKS_MAX, 1);
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
          case ROLE_ARMORY: [ Const.TILE_MIL_GUN_LOCKER, Const.TILE_MIL_AMMO_CANS ];
          case ROLE_SUPPLY: [ Const.TILE_MIL_JERRYCANS, Const.TILE_MIL_AMMO_CANS ];
          case ROLE_MEDICAL: [ Const.TILE_MIL_IV_STAND, Const.TILE_MIL_STRETCHER ];
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
                  !walled(state, c.x, c.y) ||
                  glass(state, c.x, c.y, tile))
                continue;
              // a prop in a bay is the one piece a zone does not plan round, and the first build
              // stood a barracks' rifle rack in the aisle its bunk rows left (3208 floor cells
              // cut off over 500 seeds): it stays only if every bare cell can still be walked to
              stand(state, c.x, c.y, tile);
              if (!sealsOff(state, room))
                return 1;
              stand(state, c.x, c.y, TEMP_BUILDING_ROOM);
            }
          // and if it found no cell here the next one tries: a medical bay's IV stand will not stand
          // in front of glass, and its stretcher, which lies under the sill, went without
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
              walled(state, c.x, c.y) &&
              !glass(state, c.x, c.y, tile))
            {
              stand(state, c.x, c.y, tile);
              have++;
              n++;
            }
        }
      return n;
    }

// a store's wall shelving: a unit on every cell of the bay but its two ends, which take a crate stack
// each ("stacks of crates near all"). A bay of two cells or less is shelving only
  static function shelving(state: _FacilityState, run: Array<{ x: Int, y: Int }>): Int
    {
      var n = 0;
      for (k in 0...run.length)
        {
          var c = run[k];
          if (!walled(state, c.x, c.y))
            continue;
          stand(state, c.x, c.y, (run.length > 2 &&
            (k == 0 || k == run.length - 1) ? Const.TILE_MIL_CRATES : Const.TILE_MIL_SHELF));
          n++;
        }
      return n;
    }

// a store's free-standing shelving out in its floor ("supply room need to have shelving unit rows as
// well"), down whichever axis stands more of it, the more rows on a tie: a 7x6 store takes two short
// rows across it and not one long one down it ("there's enough space for two rows here"). A row is
// shelving back to back (Const.TILE_MIL_SHELF_ROW: render.military.MilitaryInterior stands two
// units in each cell, one facing each aisle) with a crate stack on its far end when it is three or
// longer. A room too narrow for one takes crate stacks instead
  static function shelfRows(state: _FacilityState, room: _Room): Int
    {
      var a = lines(room, room.w >= room.h);
      var b = lines(room, room.w < room.h);
      var na = (a.length == 0 ? 0 : a.length * a[0].length);
      var nb = (b.length == 0 ? 0 : b.length * b[0].length);
      var n = 0;
      for (row in (nb > na || nb == na && b.length > a.length ? b : a))
        if (Lambda.foreach(row, function(c) return free(state, c.x, c.y)))
          {
            for (k in 0...row.length)
              stand(state, row[k].x, row[k].y, (k == row.length - 1 &&
                row.length >= 3 ? Const.TILE_MIL_CRATES : Const.TILE_MIL_SHELF_ROW));
            if (!sealsOff(state, room))
              n += row.length;
            else
              for (c in row)
                stand(state, c.x, c.y, TEMP_BUILDING_ROOM);
          }
      if (n == 0)
        return islands(state, room, 1, 1, Const.TILE_MIL_CRATES, CRATE_ISLANDS);
      return n;
    }

// a store's or an armory's crate stacks in its middle. An armory's are runs down the room's long axis,
// the longest that fits with its ring, its middle being its only free floor: one cell each read as
// "pretty empty". Single cells where no run fits
  static function crateIslands(state: _FacilityState, room: _Room): Int
    {
      if (room.role == ROLE_ARMORY)
        for (k in [ 3, 2 ])
          {
            var n = islands(state, room, (room.w > room.h ? k : 1), (room.w > room.h ? 1 : k),
              Const.TILE_MIL_CRATES, CRATE_ISLANDS);
            if (n > 0)
              return n;
          }
      return islands(state, room, 1, 1, Const.TILE_MIL_CRATES, CRATE_ISLANDS);
    }

// a comms room's desks back to back in its middle, three cells long where the ring still fits round
// them and two where it does not: the 5x5 room had "space for one more doubled table"
  static function deskIsland(state: _FacilityState, room: _Room): Int
    {
      for (k in [ 3, 2 ])
        {
          var n = islands(state, room, (room.w >= room.h ? k : 1), (room.w >= room.h ? 1 : k),
            Const.TILE_MIL_DESK, 1);
          if (n > 0)
            return n;
        }
      return 0;
    }

// a medical bay's cots out in its middle, two side by side where they fit (the render lies each one
// down the screen), single ones where they do not
  static function cotIsland(state: _FacilityState, room: _Room): Int
    {
      var n = islands(state, room, 2, 1, Const.TILE_MIL_COT, COT_ISLANDS);
      if (n > 0)
        return n;
      return islands(state, room, 1, 1, Const.TILE_MIL_COT, COT_ISLANDS);
    }

// the rows of shelving a store's floor has room for along x or along z, two cells or longer: one on
// every other line across the room from the second in off each side wall, so each has an aisle either
// side, from the second cell in off each end wall, so a cross aisle is kept at both
  static function lines(room: _Room, alongX: Bool): Array<Array<{ x: Int, y: Int }>>
    {
      var a0 = (alongX ? room.x1 : room.y1) + 2;
      var a1 = (alongX ? room.x2 : room.y2) - 2;
      var rows = [];
      var b = (alongX ? room.y1 : room.x1) + 2;
      while (a1 > a0 &&
          b <= (alongX ? room.y2 : room.x2) - 2)
        {
          rows.push([for (a in a0...a1 + 1) (alongX ? { x: a, y: b } : { x: b, y: a })]);
          b += 2;
        }
      return rows;
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
// it, no bare neighbour that it would leave with no other bare floor beside it — the one-cell
// pocket two pieces meeting at a corner close — and no neighbour reached from its front that it
// would leave nothing to stand on there: the ammo cans stood in front of a shelf ("tile in front of
// the shelving units as well")
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
          if (isDoor(t) ||
              facing(t) &&
              !faces(state, nx, ny, x, y))
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

// may a piece reached from its front go on this cell: free, with a bare cell in front of it. The
// jerrycans stood with a crate stack in front of them ("tile in front of cans should be walkable")
  static function walled(state: _FacilityState, x: Int, y: Int): Bool
    {
      return free(state, x, y) &&
        faces(state, x, y, x, y);
    }

// has the piece on (x, y) a bare cell to face, (ox, oy) counted as taken: the far side from a wall it
// backs onto. One out in the room backs onto nothing and needs none
  static function faces(state: _FacilityState, x: Int, y: Int, ox: Int, oy: Int): Bool
    {
      var cells = state.area.getCells();
      var walls = 0;
      for (i in 0...Const.dir4x.length)
        {
          var b = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (b == TEMP_BUILDING_ROOM ||
              b >= Const.TILE_MIL_BUNK && b <= Const.TILE_MIL_SINKS ||
              b >= Const.TILE_MIL_RADIO_RACK && b <= Const.TILE_MIL_SHELF_ROW)
            continue;
          walls++;
          var fx = x - Const.dir4x[i];
          var fy = y - Const.dir4y[i];
          if ((fx != ox || fy != oy) &&
              cells[fx][fy] == TEMP_BUILDING_ROOM)
            return true;
        }
      return walls == 0;
    }

// would `tile` on this cell stand in front of a window: only a medical bay's bays reach the glass, and
// only what lies under the sill may go there
  static function glass(state: _FacilityState, x: Int, y: Int, tile: Int): Bool
    {
      return !low(tile) &&
        RoomBlock.nextToWindow(state.area.getCells(), x, y);
    }

// does this piece lie under a window's sill: a cot, a stretcher
  public static inline function low(t: Int): Bool
    {
      return t == Const.TILE_MIL_COT ||
        t == Const.TILE_MIL_STRETCHER;
    }

// is this a piece one cell deep that is reached from its front: a shelf, a cabinet, a rack or one of
// the rooms' standing props
  public static function facing(t: Int): Bool
    {
      return t == Const.TILE_MIL_SHELF ||
        t == Const.TILE_MIL_MED_CABINET ||
        t == Const.TILE_MIL_RADIO_RACK ||
        t >= Const.TILE_MIL_GUN_LOCKER &&
        t <= Const.TILE_MIL_IV_STAND;
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

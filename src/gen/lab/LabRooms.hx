// what a lab room's zones hold
//
// gen.lab.LabZones divides a room into bays and deals its kind's zones over them; the walk hands every
// zone here. Each stands its furniture as Const row-23 tiles, one per cell, and its machines as
// footprints of Const.TILE_LAB_MACHINE named by an ORIGIN tile (gen.lab.LabKinds), which render.lab
// reads back. Every machine keeps a ring of bare floor round it, which is what lets the render tell
// a machine's turn from its footprint alone: no two footprints ever touch.
//
// NOTHING HERE MAY SEAL A CELL OFF, the base's rules verbatim: furniture never goes beside a doorway,
// a piece reached from its front keeps a bare cell there, and whatever is not planned round a whole
// ring of floor (a machine, a shelf row, a standing prop) stays only if the room's bare floor is
// still one piece. gen.GenCheck.floorReachable asserts it.

package gen.lab;

import gen.blocks.LabBlocks;
import gen.lab.LabZones.*;

class LabRooms
{
  // the most of each per-cell run one zone stands
  static inline var HAZMAT_MAX = 4;
  static inline var LOCKERS_MAX = 4;
  static inline var SEATS_MAX = 3;
  static inline var SHELVES_MAX = 6;
  static inline var BOOKCASES_MAX = 4;
  static inline var FRIDGES_MAX = 2;
  static inline var BENCHES_MAX = 6;
  static inline var WORKBENCHES_MAX = 5;
  static inline var CRATES_MAX = 2;
  // computer desks, two cells each with a cell between
  static inline var CONSOLES_MAX = 3;
  // machines one wall zone stands, and one floor zone
  static inline var WALL_MACHINES = 3;
  static inline var ISLANDS = 2;
  // the mark a zone gets when it stood nothing, counted by gen.GenRun
  public static inline var TAG_EMPTY = 'empty';

  // the machines each zone deals from, rarest on the level first
  static var BANK = [ 'screenwall', 'hatchbox', 'switchrack', 'joystick', 'pipecapsule', 'powerbox',
    'upw', 'incinerator', 'ambertanks', 'embryonic', 'winconsole', 'monitorstack', 'bioscreen',
    'terminal', 'instconsole', 'tubeconsole' ];
  static var SPECIMENS = [ 'tube', 'tubeempty', 'stasis' ];
  static var VAT_FLOOR = [ 'reactor', 'centrifuge', 'gestation', 'tentacle', 'cryopod', 'dialtank' ];
  static var WORKSHOP_WALL = [ 'switchrack', 'powerbox', 'leverbox', 'controlbox', 'canisters',
    'drawercab', 'generator', 'upw', 'drawers' ];
  static var WORKSHOP_FLOOR = [ 'press', 'robotarm', 'clamp', 'dialtank', 'trolley' ];
  static var COLD = [ 'cryobank', 'coldbank', 'specimencase', 'processor', 'incubator', 'rack8',
    'rack6', 'ambertanks', 'drawercab', 'radlocker', 'drawers', 'vault', 'sr203' ];
  static var STORE_FLOOR = [ 'vault', 'sr203', 'tarpcrate', 'palletcrate' ];
  static var RESEARCH_WALL = [ 'booth', 'brainscan', 'incubator', 'bioscreen', 'winconsole',
    'monitorstack', 'terminal', 'instconsole', 'specimencase', 'rack8', 'rack6', 'embryonic',
    'incinerator', 'screenwall' ];
  static var RESEARCH_FLOOR = [ 'autopsy', 'holo', 'analysis', 'bioprinter', 'centrifuge',
    'gestation', 'capsule', 'cryopod', 'restraint', 'robochair', 'scanner', 'probe', 'stasis',
    'clamp' ];
  static var LOBBY_FLOOR = [ 'cagecase', 'sheetcage', 'gurney', 'tarpcrate', 'incbin', 'gurneys',
    'palletcrate', 'scanframe' ];

// fill one zone. A zone that stood nothing is tagged, so the stats can say which kind keeps coming
// out bare
  public static function fill(state: _LabState, node: _GenNode)
    {
      if (node.kind == VAT_PAD)
        return;
      var room = LabZones.roomOf(state, node.roomID);
      var run = cellsOf(node);
      var n = switch (node.kind)
        {
          case HAZMAT_RACK: line(state, room, run, Const.TILE_LAB_HAZMAT, HAZMAT_MAX);
          case LOCKER_RUN: line(state, room, run, Const.TILE_LAB_LOCKER, LOCKERS_MAX);
          case SEAT_ROW: line(state, room, run, Const.TILE_LAB_SEAT, SEATS_MAX);
          case SHELVING: line(state, room, run, Const.TILE_LAB_SHELF, SHELVES_MAX);
          case BOOKCASE_RUN: line(state, room, run, Const.TILE_LAB_SHELF_LOW, BOOKCASES_MAX);
          case FRIDGE_RUN: line(state, room, run, Const.TILE_LAB_FRIDGE, FRIDGES_MAX);
          case BENCH_RUN: line(state, room, run, Const.TILE_LAB_BENCH, BENCHES_MAX);
          case WORKBENCH_RUN: line(state, room, run, Const.TILE_LAB_WORKBENCH, WORKBENCHES_MAX);
          case CRATE_STACK: line(state, room, run, Const.TILE_LAB_CRATES, CRATES_MAX);
          case CONSOLE_RUN: consoles(state, room, run);
          case KIOSK: wallMachines(state, room, node, run, [ 'kiosk' ], 1);
          case MACHINE_BANK: wallMachines(state, room, node, run, BANK, WALL_MACHINES);
          case SPECIMEN_RUN: wallMachines(state, room, node, run, SPECIMENS, WALL_MACHINES, false);
          case MACHINE_WALL: wallMachines(state, room, node, run,
            (room.role == LabBlocks.ROLE_WORKSHOP ? WORKSHOP_WALL : RESEARCH_WALL), WALL_MACHINES);
          // the two sealed safes stand along a wall too: out on the floor only a store too narrow
          // for a shelf row ever took one, 0.01 a level
          case COLD_BANK: wallMachines(state, room, node, run, COLD, WALL_MACHINES, false);
          case CONTAINER: wallMachines(state, room, node, run, [ 'container' ], 1);
          case VAT_ISLAND: islands(state, room, VAT_FLOOR, ISLANDS, false);
          case MACHINE_ISLAND: islands(state, room, WORKSHOP_FLOOR, ISLANDS, false);
          case ANALYSER: islands(state, room, RESEARCH_FLOOR, ISLANDS, false);
          case GURNEY_BAY: islands(state, room, LOBBY_FLOOR, ISLANDS + 1, true);
          case SHELF_ROW: shelfRows(state, room);
          case SLOT: slot(state, room, node, run);
          default: 1;
        }
      if (n == 0)
        node.tags = (node.tags == null ? [] : node.tags).concat([ TAG_EMPTY ]);
    }

// the standing props a room of this role takes in its leftover wall bays, in the order it takes them,
// one of each at most
  static function propsOf(role: String): Array<Int>
    {
      return switch (role)
        {
          case LabBlocks.ROLE_ENTRANCE: [ Const.TILE_LAB_PLANT, Const.TILE_LAB_BIN ];
          case LabBlocks.ROLE_VAT: [ Const.TILE_LAB_BIN, Const.TILE_LAB_DRUMS ];
          case LabBlocks.ROLE_WORKSHOP: [ Const.TILE_LAB_BIN, Const.TILE_LAB_DRUMS ];
          case LabBlocks.ROLE_STORAGE: [ Const.TILE_LAB_DRUMS, Const.TILE_LAB_CRATES ];
          default: [ Const.TILE_LAB_PLANT, Const.TILE_LAB_BIN ];
        };
    }

// a leftover wall bay: the next of the room's standing props it does not have yet, on the free cell
// nearest the bay's middle. A leftover floor bay takes nothing: the middle is where a room is walked
  static function slot(state: _LabState, room: _Room, node: _GenNode, run: Array<_Point>): Int
    {
      if (LabZones.tagged(node, TAG_FLOOR))
        return 1;
      var floor = LabBlocks.floorOf(room.role);
      for (tile in propsOf(room.role))
        {
          if (tilesIn(state, room, tile) > 0)
            continue;
          var mid = Std.int(run.length / 2);
          for (k in 0...run.length)
            {
              var c = run[mid + (k % 2 == 0 ? Std.int(k / 2) : -Std.int(k / 2) - 1)];
              if (c == null ||
                  !walled(state, room, c.x, c.y))
                continue;
              stand(state, c.x, c.y, tile);
              if (!sealsOff(state, room))
                return 1;
              stand(state, c.x, c.y, floor);
            }
        }
      return 1;
    }

// `tile` on every free cell of a bay that has a bare cell to face, until the room holds `max`
  static function line(state: _LabState, room: _Room, run: Array<_Point>, tile: Int,
      max: Int): Int
    {
      var have = tilesIn(state, room, tile);
      var n = 0;
      for (c in run)
        if (have < max &&
            walled(state, room, c.x, c.y))
          {
            stand(state, c.x, c.y, tile);
            have++;
            n++;
          }
      return n;
    }

// computer desks along a bay, two cells each with a bare cell between them
  static function consoles(state: _LabState, room: _Room, run: Array<_Point>): Int
    {
      var n = 0;
      var k = 0;
      while (k + 1 < run.length &&
          n < CONSOLES_MAX)
        {
          var a = run[k];
          var b = run[k + 1];
          if (walled(state, room, a.x, a.y) &&
              walled(state, room, b.x, b.y))
            {
              stand(state, a.x, a.y, Const.TILE_LAB_CONSOLE);
              stand(state, b.x, b.y, Const.TILE_LAB_CONSOLE);
              n++;
              k += 3;
            }
          else
            k++;
        }
      return n;
    }

// machines backed onto a bay's wall, rarest kind first, a cell of bare floor between each. A
// free-standing kind may stand along a wall too (a specimen tube), when `wallOnly` is false
  static function wallMachines(state: _LabState, room: _Room, node: _GenNode, run: Array<_Point>,
      names: Array<String>, max: Int, ?wallOnly: Bool = true): Int
    {
      var w = LabZones.wallOf(node);
      var n = 0;
      var k = 0;
      while (k < run.length &&
          n < max)
        {
          var c = run[k];
          var placed = 0;
          for (i in rarest(state, room, names, (wallOnly ? true : null)))
            {
              var kind = LabKinds.MACHINES[i];
              if (k + kind.len > run.length)
                continue;
              // the rect off this wall cell: its long side along the wall, its depth into the room
              var horiz = (w < 2);
              var rw = (horiz ? kind.len : kind.depth);
              var rh = (horiz ? kind.depth : kind.len);
              var x0 = (horiz ? c.x : (w == 2 ? room.x1 : room.x2 - rw + 1));
              var y0 = (horiz ? (w == 0 ? room.y1 : room.y2 - rh + 1) : c.y);
              if (machine(state, room, i, x0, y0, rw, rh))
                {
                  placed = kind.len;
                  break;
                }
            }
          if (placed > 0)
            {
              n++;
              k += placed + 1;
            }
          else
            k++;
        }
      return n;
    }

// free-standing machines out on a room's floor, up to `max`, nearest its middle (or nearest its
// corners), each with a whole ring of bare floor round it
  static function islands(state: _LabState, room: _Room, names: Array<String>, max: Int,
      corners: Bool): Int
    {
      var n = 0;
      for (i in rarest(state, room, names, false))
        {
          if (n >= max)
            break;
          var kind = LabKinds.MACHINES[i];
          var spots = [];
          for (turn in 0...(kind.len == kind.depth ? 1 : 2))
            {
              var rw = (turn == 0 ? kind.len : kind.depth);
              var rh = (turn == 0 ? kind.depth : kind.len);
              for (x in room.x1 + 1...room.x2 - rw + 1)
                for (y in room.y1 + 1...room.y2 - rh + 1)
                  {
                    var dx = x * 2 + rw - room.x1 - room.x2 - 1;
                    var dy = y * 2 + rh - room.y1 - room.y2 - 1;
                    var d = dx * dx + dy * dy;
                    spots.push({
                      x: x,
                      y: y,
                      w: rw,
                      h: rh,
                      // the corners' spots are the ones FARTHEST from the middle
                      d: (corners ? -d : d),
                    });
                  }
            }
          spots.sort(function(a, b) return a.d - b.d);
          for (s in spots)
            if (machine(state, room, i, s.x, s.y, s.w, s.h))
              {
                n++;
                break;
              }
        }
      return n;
    }

// stand machine `index` on the rect, if every cell of it is free floor and every cell of the ring
// round it is bare floor or masonry, and keep it only if the room's floor is still one piece
  static function machine(state: _LabState, room: _Room, index: Int, x0: Int, y0: Int, rw: Int,
      rh: Int): Bool
    {
      var cells = state.area.getCells();
      var floor = LabBlocks.floorOf(room.role);
      for (x in x0 - 1...x0 + rw + 1)
        for (y in y0 - 1...y0 + rh + 1)
          {
            var inRect = (x >= x0 &&
              x < x0 + rw &&
              y >= y0 &&
              y < y0 + rh);
            var inRoom = (x >= room.x1 &&
              x <= room.x2 &&
              y >= room.y1 &&
              y <= room.y2);
            if (inRect &&
                (!inRoom ||
                cells[x][y] != floor ||
                state.keep[x][y] ||
                state.area.hasObjectAt(x, y) ||
                LabZones.nextToDoor(cells, x, y)))
              return false;
            if (!inRect &&
                inRoom &&
                !isOpen(cells[x][y]))
              return false;
          }
      for (x in x0...x0 + rw)
        for (y in y0...y0 + rh)
          stand(state, x, y, Const.TILE_LAB_MACHINE);
      stand(state, x0, y0, Const.TILE_LAB_MACHINE0 + index);
      if (sealsOff(state, room))
        {
          for (x in x0...x0 + rw)
            for (y in y0...y0 + rh)
              stand(state, x, y, floor);
          return false;
        }
      state.used[index]++;
      return true;
    }

// a store's free-standing shelving down its middle, the military store's rows: one on every other
// line across the room from the second in off each side wall, from the second cell in off each end
// wall, down whichever axis stands more, with a crate stack on the far end of a row three or longer.
// A room too narrow for a row takes a crate or a vault out on its floor instead
  static function shelfRows(state: _LabState, room: _Room): Int
    {
      var floor = LabBlocks.floorOf(room.role);
      var a = lines(room, room.w >= room.h);
      var b = lines(room, room.w < room.h);
      var na = (a.length == 0 ? 0 : a.length * a[0].length);
      var nb = (b.length == 0 ? 0 : b.length * b[0].length);
      var n = 0;
      for (row in (nb > na || nb == na && b.length > a.length ? b : a))
        if (Lambda.foreach(row, function(c) return free(state, room, c.x, c.y)))
          {
            for (k in 0...row.length)
              stand(state, row[k].x, row[k].y, (k == row.length - 1 &&
                row.length >= 3 ? Const.TILE_LAB_CRATES : Const.TILE_LAB_SHELF_ROW));
            if (!sealsOff(state, room))
              n += row.length;
            else
              for (c in row)
                stand(state, c.x, c.y, floor);
          }
      if (n == 0)
        return islands(state, room, STORE_FLOOR, ISLANDS, false);
      return n;
    }

// the rows of shelving a store's floor has room for along x or along y
  static function lines(room: _Room, alongX: Bool): Array<Array<_Point>>
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

// the kinds of `names` this room's role may stand — only the wall ones when `wall` is true, only
// the floor ones when it is false, either for null — ordered rarest on the level first with a seeded
// roll breaking ties, so a level shows as many kinds as it has room for
  static function rarest(state: _LabState, room: _Room, names: Array<String>,
      wall: Null<Bool>): Array<Int>
    {
      var list = [];
      for (name in names)
        {
          var i = LabKinds.indexOf(name);
          var k = LabKinds.MACHINES[i];
          if ((wall == null || k.wall == wall) &&
              k.rooms.indexOf(room.role) >= 0)
            list.push({
              i: i,
              key: state.used[i] * 1000 + state.area.random(1000),
            });
        }
      list.sort(function(a, b) return a.key - b.key);
      return [for (e in list) e.i];
    }

// may furniture stand on this cell: still the room's bare floor and not kept bare, no doorway beside
// it, no bare neighbour it would leave with no other bare floor beside it, and no neighbour reached
// from its front that it would leave nothing to stand on there
  static function free(state: _LabState, room: _Room, x: Int, y: Int): Bool
    {
      var cells = state.area.getCells();
      if (cells[x][y] != LabBlocks.floorOf(room.role) ||
          state.keep[x][y] ||
          state.area.hasObjectAt(x, y))
        return false;
      for (i in 0...Const.dir4x.length)
        {
          var nx = x + Const.dir4x[i];
          var ny = y + Const.dir4y[i];
          var t = cells[nx][ny];
          if (t == Const.TILE_LAB_DOOR ||
              facing(t) &&
              !faces(state, nx, ny, x, y))
            return false;
          if (!isOpen(t))
            continue;
          var exits = 0;
          for (j in 0...Const.dir4x.length)
            {
              var ex = nx + Const.dir4x[j];
              var ey = ny + Const.dir4y[j];
              if ((ex != x || ey != y) &&
                  isOpen(cells[ex][ey]))
                exits++;
            }
          if (exits == 0)
            return false;
        }
      return true;
    }

// may a piece reached from its front go on this cell: free, with a bare cell in front of it
  static function walled(state: _LabState, room: _Room, x: Int, y: Int): Bool
    {
      return free(state, room, x, y) &&
        faces(state, x, y, x, y);
    }

// has the piece on (x, y) a bare cell to face, (ox, oy) counted as taken: the far side from a wall it
// backs onto. One out in the room backs onto nothing and needs none
  static function faces(state: _LabState, x: Int, y: Int, ox: Int, oy: Int): Bool
    {
      var cells = state.area.getCells();
      var walls = 0;
      for (i in 0...Const.dir4x.length)
        {
          if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] != Const.TILE_LAB_WALL)
            continue;
          walls++;
          var fx = x - Const.dir4x[i];
          var fy = y - Const.dir4y[i];
          if ((fx != ox || fy != oy) &&
              isOpen(cells[fx][fy]))
            return true;
        }
      return walls == 0;
    }

// is the room's bare floor no longer ONE piece?
  static function sealsOff(state: _LabState, room: _Room): Bool
    {
      var cells = state.area.getCells();
      var seen = new Map<Int, Bool>();
      var open = [];
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (open.length == 0 &&
              isOpen(cells[x][y]))
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
                  !isOpen(cells[x][y]) ||
                  seen.exists(x * 1000 + y))
                continue;
              seen.set(x * 1000 + y, true);
              open.push({ x: x, y: y });
            }
        }
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (isOpen(cells[x][y]) &&
              !seen.exists(x * 1000 + y))
            return true;
      return false;
    }

// is this cell open floor: a room's, the corridor's or the lift's. A vat pad is not: the mission
// stands a vat on it
  public static inline function isOpen(t: Int): Bool
    {
      return t >= Const.TILE_LAB_CORRIDOR &&
        t <= Const.TILE_LAB_LIFT;
    }

// is this a piece reached from its front, one cell deep at a wall?
  public static inline function facing(t: Int): Bool
    {
      return t >= Const.TILE_LAB_BENCH &&
        t <= Const.TILE_LAB_FRIDGE ||
        t == Const.TILE_LAB_PLANT ||
        t == Const.TILE_LAB_BIN;
    }

// how many cells of the room hold `tile`
  static function tilesIn(state: _LabState, room: _Room, tile: Int): Int
    {
      var cells = state.area.getCells();
      var n = 0;
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (cells[x][y] == tile)
            n++;
      return n;
    }

// a bay's cells in order along it
  static function cellsOf(node: _GenNode): Array<_Point>
    {
      return [for (x in node.x1...node.x2 + 1) for (y in node.y1...node.y2 + 1) { x: x, y: y }];
    }

  static inline function stand(state: _LabState, x: Int, y: Int, tile: Int)
    {
      state.area.getCells()[x][y] = tile;
    }
}

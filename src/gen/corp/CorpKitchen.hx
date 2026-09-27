// the staff kitchen's sub-blocks
//
// the kitchen template (gen.corp.CorpRooms.kitchen) lays the floor and hands the room here, and
// `zones` divides it the way a real office kitchen is divided: a PREP counter along one wall, with
// the sink, the appliances and the fridge; a SNACK CORNER by a door, vending machine, cooler and
// bin; and the DINING tables with their chairs in what is left. Each is a node the walk reaches a
// level down, so each filler sees the zones pushed before it already on the grid.
//
// IT REPLACES a flat template that laid a column of tables or, below 5 x 5, a galley made of OFFICE
// desk tiles with a computer and a task chair on it, then dressed the left and right walls from a
// list that mixed fridges, vending machines, taps and plants at random. Nothing in it had a place:
// a kitchen was a room with appliances scattered round two of its walls and nowhere to sit.

package gen.corp;

import Const;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.blocks.CorpBlocks;
import gen.corp.CorpTemp.*;

class CorpKitchen
{
  // the longest a prep counter runs along its wall, fridge included, and the shortest worth laying
  public static inline var PREP_MAX = 5;
  static inline var PREP_MIN = 2;
  // the snack corner: a vending machine, the cooler and a bin
  static inline var SNACK_MAX = 3;
  static inline var SNACK_MIN = 2;
  // a 2x2 table and the shared row of chairs beside it
  static inline var TABLE_PITCH = 3;
  // and percent chance each counter cell past the sink takes one of the appliances
  static inline var APPLIANCE_CHANCE = 80;

  // which wall a run stands against
  static inline var SIDE_N = 'n';
  static inline var SIDE_S = 's';
  static inline var SIDE_W = 'w';
  static inline var SIDE_E = 'e';

// divide a kitchen into its prep counter, snack corner and dining area, and push them in that
// order — the snack corner is chosen clear of the counter and the dining area clear of both
  public static function zones(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var runs = wallRuns(cells, room);

      // the prep counter takes the longest clear stretch of wall, anchored in a corner where it has one
      var prep = null;
      var best = 0;
      for (r in runs)
        {
          var len = r.cells.length;
          if (len > best ||
              (len == best && state.area.chance(50)))
            {
              prep = r;
              best = len;
            }
        }
      var taken = new Map<Int, Bool>();
      if (prep != null &&
          best >= PREP_MIN)
        {
          var cut = prep.cells;
          if (cut.length > PREP_MAX)
            {
              var last = cut[cut.length - 1];
              cut = (isCorner(room, last.x, last.y) ?
                cut.slice(cut.length - PREP_MAX) : cut.slice(0, PREP_MAX));
            }
          for (c in cut)
            taken.set(c.x * 1000 + c.y, true);
          push(node, room, CorpBlocks.ZONE_PREP, cut);
        }
      else
        prep = null;

      // the snack corner: the window of wall nearest a doorway that the counter did not take
      var doors = [];
      for (d in state.doors)
        if (d.roomID1 == room.id ||
            d.roomID2 == room.id)
          doors.push(d);
      var snack = null;
      var bestD = 1000000;
      for (r in runs)
        {
          // the free pieces of this run, split wherever the counter stands
          var pieces = [[]];
          for (c in r.cells)
            if (taken.exists(c.x * 1000 + c.y))
              pieces.push([]);
            else
              pieces[pieces.length - 1].push(c);
          for (p in pieces)
            {
              if (p.length < SNACK_MIN)
                continue;
              var len = Std.int(Math.min(SNACK_MAX, p.length));
              for (i in 0...p.length - len + 1)
                {
                  var w = p.slice(i, i + len);
                  var mid = w[Std.int(len / 2)];
                  var d = 1000;
                  for (door in doors)
                    d = Std.int(Math.min(d, Math.abs(door.x - mid.x) + Math.abs(door.y - mid.y)));
                  if (d < bestD)
                    {
                      bestD = d;
                      snack = w;
                    }
                }
            }
        }
      if (snack != null)
        push(node, room, CorpBlocks.ZONE_VENDING, snack);

      // the dining area: the whole room, which the filler lays its tables over clear of the counter
      // and the snack corner already on the grid
      var z = GenTree.add(node, CorpBlocks.ZONE_DINING, room.x1, room.y1, room.x2, room.y2);
      z.roomID = room.id;
    }

// fill one kitchen zone
  public static function fill(state: _CorpState, node: _GenNode)
    {
      var room = null;
      for (r in state.rooms)
        if (r.id == node.roomID)
          {
            room = r;
            break;
          }
      if (room == null)
        return;
      switch (node.kind)
        {
          case CorpBlocks.ZONE_PREP:
            prep(state, node, room);
          case CorpBlocks.ZONE_VENDING:
            snack(state, node, room);
          default:
            dining(state, node, room);
        }
    }

// the prep counter: the fridge at the run's corner end, the sink next along, and the microwave,
// kettle and coffee machine dealt over the counter cells past it.
//
// EVERY CELL OF IT STAYS WALKABLE FLOOR, the piece named by its decoration alone. A counter is
// COUNTER_D 1.32 deep against a wall whose own cell keeps a 1.4 strip of floor in front of the
// masonry, so render.corp.CorpKitchen stands the whole unit on the WALL cell and its own tile was
// bare floor marked impassable — reported as the tiles beside the counter "not walkable" with
// plenty of space. A bare counter cell carries Const.CORP_COUNTER so the render still finds it
  static function prep(state: _CorpState, node: _GenNode, room: _Room)
    {
      var run = runCells(node);
      // the corner end first, so the tall fridge closes the run off against the return wall
      var last = run[run.length - 1];
      if (isCorner(room, last.x, last.y))
        run.reverse();
      var i = 0;
      if (run.length >= 3)
        {
          CorpRooms.addDecoration(state, run[0].x, run[0].y, Const.CORP_FRIDGE);
          i = 1;
        }
      var sink = i;
      var full = [
        Const.CORP_TABLE_MICROWAVE,
        Const.CORP_TABLE_KETTLE,
        Const.CORP_TABLE_COFFEE,
      ];
      var deco = full.copy();
      for (j in i...run.length)
        {
          var c = run[j];
          if (j == sink)
            CorpRooms.addDecoration(state, c.x, c.y, Const.CORP_TAP);
          else if (state.area.chance(APPLIANCE_CHANCE))
            deco = CorpRooms.addDecorationExt(state, c.x, c.y, deco, full);
          else
            CorpRooms.addDecoration(state, c.x, c.y, Const.CORP_COUNTER);
        }
    }

// the snack corner: a vending machine, then the cooler, then a bin, each against the wall on a cell
// that stays walkable, the counter's reason
  static function snack(state: _CorpState, node: _GenNode, room: _Room)
    {
      var run = runCells(node);
      var groups = [ Const.CORP_VENDING, Const.CORP_COOLER, Const.CORP_TRASH ];
      for (i in 0...run.length)
        CorpRooms.addDecoration(state, run[i].x, run[i].y, groups[i]);
    }

// the dining area: 2x2 tables on a pitch of three, each kept only if the room stays walkable round
// it, and a chair on every free cell of the two sides that face along the row of tables.
//
// EVERY OFFSET THE SPARE CELLS ALLOW IS TRIED, scored on tables and then on seats, and the best is
// laid. Centring alone left a spare row on each side of an 8x6 kitchen's two tables where a second
// row of two fits; a door, the counter or the glazing decides where the spare row goes, and
// only a trial sees all three
  static function dining(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var w = GenTree.width(node), h = GenTree.height(node);
      var cols = Std.int((w + 1) / TABLE_PITCH);
      var rows = Std.int((h + 1) / TABLE_PITCH);
      if (cols < 1 ||
          rows < 1)
        return;
      // CHAIRS ON THE SIDES THE ROW DOES NOT RUN ALONG: two tables side by side share the one cell
      // between them, and a chair there would belong to both
      var seatsNS = (cols > rows ||
        (cols == rows && room.w >= room.h));
      var tables = [];
      var chairs = [];
      var best = -1;
      for (oy in 0...h - (rows * TABLE_PITCH - 1) + 1)
        for (ox in 0...w - (cols * TABLE_PITCH - 1) + 1)
          {
            var t = fit(state, room, node.x1 + ox, node.y1 + oy, cols, rows);
            var c = seats(state, room, t, seatsNS);
            if (t.length * 10 + c.length > best)
              {
                best = t.length * 10 + c.length;
                tables = t;
                chairs = c;
              }
          }
      var full = [
        Const.CORP_TABLE_TISSUE,
        Const.CORP_TABLE_SAUCES,
        Const.CORP_TABLE_SALT,
        Const.CORP_TABLE_MUG,
        Const.CORP_TABLE_FRUIT,
      ];
      var deco = full.copy();
      for (t in tables)
        {
          GenTree.add(node, CorpBlocks.ZONE_TABLE, t.x, t.y, t.x + 1, t.y + 1);
          for (dy in 0...2)
            for (dx in 0...2)
              {
                cells[t.x + dx][t.y + dy] = Const.LIGHT_TABLE_WOOD1_2X2[dy][dx];
                if (state.area.chance(30))
                  deco = CorpRooms.addDecorationExt(state, t.x + dx, t.y + dy, deco, full);
              }
        }
      for (c in chairs)
        CorpRooms.addDecoration(state, c.x, c.y, Const.CORP_CHAIR);
    }

// the tables one offset lays: a 2x2 at every pitch point whose cells are bare floor clear of a
// doorway, kept only while the room stays walkable
  static function fit(state: _CorpState, room: _Room, sx: Int, sy: Int,
      cols: Int, rows: Int): Array<{ x: Int, y: Int }>
    {
      var cells = state.area.getCells();
      var blocked = new Map<Int, Bool>();
      var out = [];
      for (r in 0...rows)
        for (c in 0...cols)
          {
            var tx = sx + c * TABLE_PITCH, ty = sy + r * TABLE_PITCH;
            var ok = true;
            for (dy in 0...2)
              for (dx in 0...2)
                if (cells[tx + dx][ty + dy] != WOOD1 ||
                    state.area.hasObjectAt(tx + dx, ty + dy) ||
                    CorpRooms.atDoor(cells, tx + dx, ty + dy))
                  ok = false;
            if (!ok)
              continue;
            for (dy in 0...2)
              for (dx in 0...2)
                blocked.set((tx + dx) * 1000 + ty + dy, true);
            if (!CorpRooms.roomOpen(state, room, blocked, WOOD1))
              {
                for (dy in 0...2)
                  for (dx in 0...2)
                    blocked.remove((tx + dx) * 1000 + ty + dy);
                continue;
              }
            out.push({ x: tx, y: ty });
          }
      return out;
    }

// the chairs round a set of tables: every free cell of each table's two seated sides, then, for a
// table that got fewer than two, its other two sides. A chair is walkable, so none of this can
// shut the room
  static function seats(state: _CorpState, room: _Room,
      tables: Array<{ x: Int, y: Int }>, ns: Bool): Array<{ x: Int, y: Int }>
    {
      var cells = state.area.getCells();
      var used = new Map<Int, Bool>();
      for (t in tables)
        for (dy in 0...2)
          for (dx in 0...2)
            used.set((t.x + dx) * 1000 + t.y + dy, true);
      var sideNS = [ [ 0, -1 ], [ 1, -1 ], [ 0, 2 ], [ 1, 2 ] ];
      var sideWE = [ [ -1, 0 ], [ -1, 1 ], [ 2, 0 ], [ 2, 1 ] ];
      var out = [];
      var take = function(t: { x: Int, y: Int }, side: Array<Array<Int>>): Int
        {
          var n = 0;
          for (s in side)
            {
              var x = t.x + s[0], y = t.y + s[1];
              if (x < room.x1 ||
                  x > room.x2 ||
                  y < room.y1 ||
                  y > room.y2 ||
                  used.exists(x * 1000 + y) ||
                  cells[x][y] != WOOD1 ||
                  CorpRooms.atDoor(cells, x, y) ||
                  state.area.hasObjectAt(x, y))
                continue;
              used.set(x * 1000 + y, true);
              out.push({ x: x, y: y });
              n++;
            }
          return n;
        }
      var got = [for (t in tables) take(t, ns ? sideNS : sideWE)];
      for (i in 0...tables.length)
        if (got[i] < 2)
          take(tables[i], ns ? sideWE : sideNS);
      return out;
    }

// every stretch of the room's wall ring that no doorway opens onto and no glazing backs, one side
// at a time, in order along the wall.
//
// NOT AGAINST GLASS: a counter, a fridge and a vending machine stand against MASONRY, and
// render.corp.CorpKitchen hangs a wall cabinet over every counter cell whose wall is solid — a
// curtain wall has no face to stand them on
  static function wallRuns(cells: Array<Array<Int>>, room: _Room): Array<{ side: String, cells: Array<{ x: Int, y: Int }> }>
    {
      var out = [];
      var sides = [
        { side: SIDE_N, dx: 0, dy: -1, line: [for (x in room.x1...room.x2 + 1) { x: x, y: room.y1 }] },
        { side: SIDE_S, dx: 0, dy: 1, line: [for (x in room.x1...room.x2 + 1) { x: x, y: room.y2 }] },
        { side: SIDE_W, dx: -1, dy: 0, line: [for (y in room.y1...room.y2 + 1) { x: room.x1, y: y }] },
        { side: SIDE_E, dx: 1, dy: 0, line: [for (y in room.y1...room.y2 + 1) { x: room.x2, y: y }] },
      ];
      for (s in sides)
        {
          var cur = [];
          for (c in s.line)
            if (CorpRooms.atDoor(cells, c.x, c.y) ||
                glazed(cells[c.x + s.dx][c.y + s.dy]))
              {
                if (cur.length > 0)
                  out.push({ side: s.side, cells: cur });
                cur = [];
              }
            else
              cur.push(c);
          if (cur.length > 0)
            out.push({ side: s.side, cells: cur });
        }
      return out;
    }

// is this wall tile a window, outer or inner?
  static inline function glazed(t: Int): Bool
    {
      return (t >= BLDG_WINDOW && t <= BLDG_WINDOWV3) ||
        (t >= INNER_WINDOW && t <= INNER_WINDOWV3);
    }

// push one wall-run zone over `run`
  static function push(node: _GenNode, room: _Room, kind: String, run: Array<{ x: Int, y: Int }>)
    {
      var a = run[0], b = run[run.length - 1];
      var z = GenTree.add(node, kind,
        Std.int(Math.min(a.x, b.x)), Std.int(Math.min(a.y, b.y)),
        Std.int(Math.max(a.x, b.x)), Std.int(Math.max(a.y, b.y)));
      z.roomID = room.id;
    }

// the cells of a one-deep run node, in order along it
  static function runCells(node: _GenNode): Array<{ x: Int, y: Int }>
    {
      var out = [];
      for (x in node.x1...node.x2 + 1)
        for (y in node.y1...node.y2 + 1)
          out.push({ x: x, y: y });
      return out;
    }

// is this cell one of the room's four corners?
  static function isCorner(room: _Room, x: Int, y: Int): Bool
    {
      return (x == room.x1 || x == room.x2) &&
        (y == room.y1 || y == room.y2);
    }
}

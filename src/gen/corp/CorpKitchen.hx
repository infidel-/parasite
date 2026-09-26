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
  // percent chance each free cell along a table's seated sides takes a chair
  static inline var CHAIR_CHANCE = 75;
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

      // the dining area: the room inside its wall ring, one lane clear of the counter where the
      // room is deep enough to spare it
      var x1 = room.x1 + 1, y1 = room.y1 + 1, x2 = room.x2 - 1, y2 = room.y2 - 1;
      if (prep != null)
        switch (prep.side)
          {
            case SIDE_N:
              if (y2 - y1 >= 2)
                y1++;
            case SIDE_S:
              if (y2 - y1 >= 2)
                y2--;
            case SIDE_W:
              if (x2 - x1 >= 2)
                x1++;
            default:
              if (x2 - x1 >= 2)
                x2--;
          }
      if (x2 > x1 &&
          y2 > y1)
        {
          var z = GenTree.add(node, CorpBlocks.ZONE_DINING, x1, y1, x2, y2);
          z.roomID = room.id;
        }
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
// kettle and coffee machine dealt over the counter cells past it
  static function prep(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var run = runCells(node);
      // the corner end first, so the tall fridge closes the run off against the return wall
      var last = run[run.length - 1];
      if (isCorner(room, last.x, last.y))
        run.reverse();
      var blocked = new Map<Int, Bool>();
      for (c in run)
        blocked.set(c.x * 1000 + c.y, true);
      if (!CorpRooms.roomOpen(state, room, blocked, WOOD1))
        return;
      var i = 0;
      if (run.length >= 3)
        {
          cells[run[0].x][run[0].y] = Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET;
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
          cells[c.x][c.y] = Const.TILE_LIGHT_TABLE_WOOD1_1X1;
          if (j == sink)
            CorpRooms.addDecoration(state, c.x, c.y, Const.CORP_TAP);
          else if (state.area.chance(APPLIANCE_CHANCE))
            deco = CorpRooms.addDecorationExt(state, c.x, c.y, deco, full);
        }
    }

// the snack corner: a vending machine, then the cooler, then a bin you can step round
  static function snack(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var run = runCells(node);
      var blocked = new Map<Int, Bool>();
      for (i in 0...Std.int(Math.min(2, run.length)))
        blocked.set(run[i].x * 1000 + run[i].y, true);
      if (!CorpRooms.roomOpen(state, room, blocked, WOOD1))
        return;
      var groups = [ Const.CORP_VENDING, Const.CORP_COOLER, Const.CORP_TRASH ];
      for (i in 0...run.length)
        {
          var c = run[i];
          if (groups[i] != Const.CORP_TRASH)
            cells[c.x][c.y] = Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET;
          CorpRooms.addDecoration(state, c.x, c.y, groups[i]);
        }
    }

// the dining area: 2x2 tables on a pitch of three, centred, each kept only if the room stays
// walkable round it, and chairs on the two sides that face along the row of tables
  static function dining(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var w = GenTree.width(node), h = GenTree.height(node);
      var cols = Std.int((w + 1) / TABLE_PITCH);
      var rows = Std.int((h + 1) / TABLE_PITCH);
      if (cols < 1 ||
          rows < 1)
        return;
      var sx = node.x1 + Std.int((w - (cols * TABLE_PITCH - 1)) / 2);
      var sy = node.y1 + Std.int((h - (rows * TABLE_PITCH - 1)) / 2);
      // CHAIRS ON THE SIDES THE ROW DOES NOT RUN ALONG: two tables side by side share the one cell
      // between them, and a chair there would belong to both
      var seatsNS = (cols > rows ||
        (cols == rows && room.w >= room.h));
      var full = [
        Const.CORP_TABLE_TISSUE,
        Const.CORP_TABLE_SAUCES,
        Const.CORP_TABLE_SALT,
        Const.CORP_TABLE_MUG,
        Const.CORP_TABLE_FRUIT,
      ];
      var deco = full.copy();
      var blocked = new Map<Int, Bool>();
      var tables = [];
      for (r in 0...rows)
        for (c in 0...cols)
          {
            var tx = sx + c * TABLE_PITCH, ty = sy + r * TABLE_PITCH;
            var ok = true;
            for (dy in 0...2)
              for (dx in 0...2)
                if (cells[tx + dx][ty + dy] != WOOD1 ||
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
            GenTree.add(node, CorpBlocks.ZONE_TABLE, tx, ty, tx + 1, ty + 1);
            tables.push({ x: tx, y: ty });
            for (dy in 0...2)
              for (dx in 0...2)
                {
                  cells[tx + dx][ty + dy] = Const.LIGHT_TABLE_WOOD1_2X2[dy][dx];
                  if (state.area.chance(30))
                    deco = CorpRooms.addDecorationExt(state, tx + dx, ty + dy, deco, full);
                }
          }
      // the chairs last, once every table is down, so no chair takes a cell a table wanted
      for (t in tables)
        {
          var seats = (seatsNS ?
            [ [ 0, -1 ], [ 1, -1 ], [ 0, 2 ], [ 1, 2 ] ] :
            [ [ -1, 0 ], [ -1, 1 ], [ 2, 0 ], [ 2, 1 ] ]);
          for (s in seats)
            {
              var x = t.x + s[0], y = t.y + s[1];
              if (x < room.x1 ||
                  x > room.x2 ||
                  y < room.y1 ||
                  y > room.y2 ||
                  cells[x][y] != WOOD1 ||
                  CorpRooms.atDoor(cells, x, y) ||
                  state.area.hasObjectAt(x, y) ||
                  !state.area.chance(CHAIR_CHANCE))
                continue;
              CorpRooms.addDecoration(state, x, y, Const.CORP_CHAIR);
            }
        }
    }

// every stretch of the room's wall ring that no doorway opens onto, one side at a time, in order
// along the wall
  static function wallRuns(cells: Array<Array<Int>>, room: _Room): Array<{ side: String, cells: Array<{ x: Int, y: Int }> }>
    {
      var out = [];
      var sides = [
        { side: SIDE_N, line: [for (x in room.x1...room.x2 + 1) { x: x, y: room.y1 }] },
        { side: SIDE_S, line: [for (x in room.x1...room.x2 + 1) { x: x, y: room.y2 }] },
        { side: SIDE_W, line: [for (y in room.y1...room.y2 + 1) { x: room.x1, y: y }] },
        { side: SIDE_E, line: [for (y in room.y1...room.y2 + 1) { x: room.x2, y: y }] },
      ];
      for (s in sides)
        {
          var cur = [];
          for (c in s.line)
            if (CorpRooms.atDoor(cells, c.x, c.y))
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

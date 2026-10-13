// what a lab room is made of: the bays its floor divides into and the quota dealt over them
//
// the base's gen.military.MilitaryZones, for a level cut into rock. A room divides into one BAY per
// straight span of wall it can stand things against, plus one for the middle of its floor, and its
// kind's zones are dealt over them by gen.Quota; gen.lab.LabRooms fills each zone. A wall bay is
// cut at every cell with a doorway beside it, so nothing ever stands in a door's swing, and at the
// cells kept bare (_LabState.keep: the vat pads' ring, the lift's approach).
//
// THE TOP WALL IS THE ONE THE CAMERA SEES. The tactical camera looks north, so a piece backed onto a
// room's north wall faces the player and one on its south wall shows its back. The run a room is
// read by — the benches, the consoles, the suit racks — asks for the top wall first.

package gen.lab;

import gen.GenTree;
import gen.Quota;
import gen.blocks.LabBlocks;

class LabZones
{
  // a room's bays before they are dealt, and what is left of them after
  public static inline var BAY = 'lab-bay';
  public static inline var SLOT = 'lab-slot';
  // the vat chamber's four pads, carved before anything is dealt
  public static inline var VAT_PAD = 'vat-pad';

  // the zones
  public static inline var HAZMAT_RACK = 'hazmat-rack';
  public static inline var KIOSK = 'kiosk';
  public static inline var LOCKER_RUN = 'locker-run';
  public static inline var SEAT_ROW = 'seat-row';
  public static inline var GURNEY_BAY = 'gurney-bay';
  public static inline var CONSOLE_RUN = 'console-run';
  public static inline var MACHINE_BANK = 'machine-bank';
  public static inline var SPECIMEN_RUN = 'specimen-run';
  public static inline var VAT_ISLAND = 'vat-island';
  public static inline var WORKBENCH_RUN = 'workbench-run';
  public static inline var MACHINE_WALL = 'machine-wall';
  public static inline var CRATE_STACK = 'crate-stack';
  public static inline var MACHINE_ISLAND = 'machine-island';
  public static inline var CONTAINER = 'container';
  public static inline var COLD_BANK = 'cold-bank';
  public static inline var SHELVING = 'shelving';
  public static inline var SHELF_ROW = 'shelf-row';
  public static inline var BENCH_RUN = 'bench-run';
  public static inline var BOOKCASE_RUN = 'bookcase-run';
  public static inline var FRIDGE_RUN = 'fridge-run';
  public static inline var ANALYSER = 'analyser';

  // a bay's marks: its wall (w0 top, w1 bottom, w2 left, w3 right) or the middle of the floor
  public static inline var TAG_FLOOR = 'floor';
  // and the room's own, when its deal fell short of a min; gen.GenCheck.labSane fails on it
  public static inline var TAG_UNMET = 'unmet';

  // the step INTO the room from each wall, and the step to the cell behind it
  public static var INWARD_X = [ 0, 0, 1, -1 ];
  public static var INWARD_Y = [ 1, -1, 0, 0 ];

  static var ZONES = [ VAT_PAD, HAZMAT_RACK, KIOSK, LOCKER_RUN, SEAT_ROW, GURNEY_BAY, CONSOLE_RUN,
    MACHINE_BANK, SPECIMEN_RUN, VAT_ISLAND, WORKBENCH_RUN, MACHINE_WALL, CRATE_STACK, MACHINE_ISLAND,
    CONTAINER, COLD_BANK, SHELVING, SHELF_ROW, BENCH_RUN, BOOKCASE_RUN, FRIDGE_RUN, ANALYSER, SLOT ];

// is this one of the zones a lab room divides into?
  public static function isZone(kind: String): Bool
    {
      return ZONES.indexOf(kind) >= 0;
    }

// divide this room into its bays and deal its kind's quota over them. The vat chamber carves its
// pads first, so no bay reaches them
  public static function deal(state: _LabState, node: _GenNode)
    {
      var room = roomOf(state, node.roomID);
      if (node.kind == LabBlocks.VAT)
        pads(state, room, node);
      var bays = [];
      var runs = wallRuns(state, room);
      for (w in 0...4)
        for (span in spans(runs[w]))
          {
            var a = span[0];
            var z = span[span.length - 1];
            var b = GenTree.add(node, BAY, Std.int(Math.min(a.x, z.x)), Std.int(Math.min(a.y, z.y)),
              Std.int(Math.max(a.x, z.x)), Std.int(Math.max(a.y, z.y)));
            b.roomID = room.id;
            b.tags = [ 'w' + w ];
            bays.push(b);
          }
      if (room.w >= 3 &&
          room.h >= 3)
        {
          var b = GenTree.add(node, BAY, room.x1 + 1, room.y1 + 1, room.x2 - 1, room.y2 - 1);
          b.roomID = room.id;
          b.tags = [ TAG_FLOOR ];
          bays.push(b);
        }
      var want = demands(node.kind);
      Quota.deal(bays, want, SLOT, state.area.rng);
      if (!Quota.satisfied(bays, want))
        node.tags = [ TAG_UNMET ];
      // zones fill in the order their kind's quota lists them, the core one first: walked in wall
      // order, a store's cold bank on the top wall took the corners its container on the side wall
      // needed, and one store in ten stood none. The leftover bays LAST: a slot stands a prop no
      // zone planned round
      var order = [for (d in want) d.kind].concat([ SLOT ]);
      var pads = [for (c in node.children) if (c.kind == VAT_PAD) c];
      var zones = [for (c in node.children) if (c.kind != VAT_PAD) c];
      zones.sort(function(a, b) return order.indexOf(a.kind) - order.indexOf(b.kind));
      node.children = pads.concat(zones);
    }

// the vat chamber's four pads, 2x3 each in a two by two round its middle with a one-cell aisle
// through it both ways — where the 2D generator put them, so the mission's anchors are the same
// cells they always were — and a ring of bare floor round the four, kept clear of every zone
  static function pads(state: _LabState, room: _Room, node: _GenNode)
    {
      var cells = state.area.getCells();
      var cx = room.x1 + Std.int(room.w / 2);
      var cy = room.y1 + Std.int(room.h / 2);
      state.vatAnchors = [
        { x: cx - 2, y: cy - 3 },
        { x: cx + 1, y: cy - 3 },
        { x: cx - 2, y: cy + 1 },
        { x: cx + 1, y: cy + 1 },
      ];
      state.reservedRects = [];
      for (a in state.vatAnchors)
        {
          for (x in a.x...a.x + 2)
            for (y in a.y...a.y + 3)
              cells[x][y] = Const.TILE_LAB_VAT_PAD;
          state.reservedRects.push({
            x1: a.x,
            y1: a.y,
            x2: a.x + 1,
            y2: a.y + 2,
            kind: 'clone-vat',
          });
          var n = GenTree.add(node, VAT_PAD, a.x, a.y, a.x + 1, a.y + 2);
          n.roomID = room.id;
        }
      for (x in cx - 3...cx + 4)
        for (y in cy - 4...cy + 5)
          state.keep[x][y] = true;
    }

// the quota for one room kind. The core zones carry its min; the rest are `max` only and are dealt
// in gen.Quota's second pass, in this order
  static function demands(kind: String): Array<_GenDemand>
    {
      return switch (kind)
        {
          // the suit racks facing the lift, the info kiosk, seats and lockers on what wall is left,
          // and what was wheeled down and left out on the floor
          case LabBlocks.ENTRANCE: [
              wall(HAZMAT_RACK, 1, 1, 2, top(100)),
              wall(KIOSK, 1, 1, 1, function(b) return (tagged(b, 'w2') ? 100 : 0) + len(b)),
              wall(SEAT_ROW, 0, 1, 2, top(50)),
              wall(LOCKER_RUN, 0, 1, 2),
              floor(GURNEY_BAY),
            ];

          // the monitoring desks on the top wall, the plant on the back wall facing the doorway, the
          // specimen tubes on the south, and a machine in a corner the pads leave
          case LabBlocks.VAT: [
              wall(CONSOLE_RUN, 1, 1, 2, top(100)),
              wall(MACHINE_BANK, 1, 2, 2, function(b)
                return (tagged(b, 'w3') ? 100 : tagged(b, 'w0') ? 50 : 0) + len(b)),
              wall(SPECIMEN_RUN, 0, 2, 1, function(b)
                return (tagged(b, 'w1') ? 100 : tagged(b, 'w2') ? 50 : 0) + len(b)),
              floor(VAT_ISLAND),
            ];

          // the workbenches on the top wall, machines on the others, lockers, crates and a press or
          // an arm out on the floor
          case LabBlocks.WORKSHOP: [
              wall(WORKBENCH_RUN, 1, 1, 2, top(100)),
              wall(MACHINE_WALL, 1, 2, 1),
              wall(LOCKER_RUN, 0, 1, 2),
              wall(CRATE_STACK, 0, 1, 1),
              floor(MACHINE_ISLAND),
            ];

          // the sealed containers on the side walls, the cold chain on the top one, shelving and
          // suit racks round what is left and shelf rows down the middle
          case LabBlocks.STORAGE: [
              wall(CONTAINER, 1, 2, 3, function(b)
                return (tagged(b, 'w2') || tagged(b, 'w3') ? 100 : 0) + len(b)),
              wall(COLD_BANK, 1, 2, 2, top(100)),
              wall(SHELVING, 0, 2, 2),
              wall(HAZMAT_RACK, 0, 1, 2),
              wall(CRATE_STACK, 0, 1, 1),
              floor(SHELF_ROW),
            ];

          // the benches on the top wall, desks, machines, bookcases and specimen fridges round the
          // rest, and an analyser out on the floor
          default: [
              wall(BENCH_RUN, 1, 1, 2, top(100)),
              wall(CONSOLE_RUN, 0, 1, 2),
              wall(MACHINE_WALL, 0, 2, 2),
              wall(BOOKCASE_RUN, 0, 1, 2),
              wall(FRIDGE_RUN, 0, 1, 1),
              floor(ANALYSER),
            ];
        };
    }

// a fit that prefers the top wall by `bonus`, anything but the south one by a little, then the
// longest bay
  static function top(bonus: Int): _GenNode -> Int
    {
      return function(b: _GenNode)
        return (tagged(b, 'w0') ? bonus : tagged(b, 'w1') ? 0 : 20) + len(b);
    }

// a zone on one bay of a wall, at least `minLen` cells long. With no fit of its own it takes any
// wall before the south one, whose pieces show the camera their backs: a research room's desks and a
// lobby's seats both landed there first
  static function wall(kind: String, min: Int, max: Int, minLen: Int,
      ?fit: _GenNode -> Int): _GenDemand
    {
      return {
        kind: kind,
        min: min,
        max: max,
        minW: 1,
        minH: 1,
        fit: (fit != null ? fit : function(b: _GenNode)
          return (tagged(b, 'w1') ? 0 : 50) + len(b)),
        must: function(b: _GenNode)
          return (!tagged(b, TAG_FLOOR) &&
            len(b) >= minLen),
      };
    }

// a zone on the middle of the floor, which a room has one of at most
  static function floor(kind: String): _GenDemand
    {
      return {
        kind: kind,
        min: 0,
        max: 1,
        minW: 1,
        minH: 1,
        must: function(b: _GenNode)
          return tagged(b, TAG_FLOOR),
      };
    }

// each wall's inner cells a piece can back onto, in order along it: the room's own bare floor, with
// masonry straight behind and no doorway beside, and not kept bare. Top, bottom, left, right
  public static function wallRuns(state: _LabState, room: _Room): Array<Array<_Point>>
    {
      var cells = state.area.getCells();
      var floor = LabBlocks.floorOf(room.role);
      var runs = [];
      for (w in 0...4)
        {
          var run = [];
          var horiz = (w < 2);
          var n = (horiz ? room.w : room.h);
          for (i in 0...n)
            {
              var x = (horiz ? room.x1 + i : (w == 2 ? room.x1 : room.x2));
              var y = (horiz ? (w == 0 ? room.y1 : room.y2) : room.y1 + i);
              if (cells[x][y] == floor &&
                  !state.keep[x][y] &&
                  cells[x - INWARD_X[w]][y - INWARD_Y[w]] == Const.TILE_LAB_WALL &&
                  !nextToDoor(cells, x, y))
                run.push({ x: x, y: y });
            }
          runs.push(run);
        }
      return runs;
    }

// a run cut into its unbroken stretches
  static function spans(run: Array<_Point>): Array<Array<_Point>>
    {
      var out = [];
      var cur = [];
      for (c in run)
        {
          if (cur.length > 0 &&
              Math.abs(c.x - cur[cur.length - 1].x) + Math.abs(c.y - cur[cur.length - 1].y) != 1)
            {
              out.push(cur);
              cur = [];
            }
          cur.push(c);
        }
      if (cur.length > 0)
        out.push(cur);
      return out;
    }

// is there a doorway cell beside this one?
  public static function nextToDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == Const.TILE_LAB_DOOR)
          return true;
      return false;
    }

// the room a node belongs to
  public static function roomOf(state: _LabState, id: Int): _Room
    {
      for (r in state.rooms)
        if (r.id == id)
          return r;
      return null;
    }

// the wall a bay stands against, 0..3, or -1 for the floor bay
  public static function wallOf(b: _GenNode): Int
    {
      for (w in 0...4)
        if (tagged(b, 'w' + w))
          return w;
      return -1;
    }

// a wall bay's length in cells
  public static inline function len(b: _GenNode): Int
    {
      return Std.int(Math.max(GenTree.width(b), GenTree.height(b)));
    }

  public static inline function tagged(b: _GenNode, tag: String): Bool
    {
      return b.tags != null &&
        b.tags.indexOf(tag) >= 0;
    }
}

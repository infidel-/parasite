// what a military room is made of: its kind, the bays its floor divides into, and the quota dealt
// over them
//
// the base's counterpart of gen.blocks.RoomZones. A military room used to be ONE node kind,
// `room-military`, whatever its role, and gen.military.MilitaryRooms stood its furniture with plain
// loops off `room.role` — so the tree could not say what a room was or what it held, and nothing
// could assert it. Every role is now its own kind, and every room divides into BAYS dealt by
// gen.Quota exactly as a laboratory's do: one per straight span of masonry it can stand things
// against, plus one for the middle of its floor. MilitaryRooms fills each zone.
//
// A WALL BAY NEVER TOUCHES GLASS. roomWallRuns only asks about the cell straight behind each cell,
// so a corner cell with the ribbon's first pane beside it passed, and the comms room stood a radio
// rack in front of the window (the render then backed it ONTO the glass, the window being the first
// wall it found). A cell with a window on any side, or a doorway of any kind, is cut out of the run
// before it is split into bays.

package gen.military;

import gen.GenTree;
import gen.Quota;
import gen.blocks.RoomBlock;
import gen.facility._FacilityState;
import gen.facility.FacilityBuilding;
import gen.facility.FacilityRooms;
import gen.facility.FacilityToilet;
import gen.facility.FacilityTemp.*;

class MilitaryZones
{
  // the room kinds, one per role FacilityRooms.militaryThemes deals
  public static inline var ARMORY = 'room-armory';
  public static inline var HQ = 'room-hq';
  public static inline var COMMS = 'room-comms';
  public static inline var SUPPLY = 'room-supply';
  public static inline var MEDICAL = 'room-medical';
  public static inline var BRIEFING = 'room-briefing';
  public static inline var MESS = 'room-mess';
  public static inline var BARRACKS = 'room-barracks';
  public static inline var LATRINE = 'room-latrine';

  // and the zones they divide into. A wall zone is one bay of one wall, a floor zone the room's
  // middle less a cell all round
  public static inline var BUNK_ROW = 'bunk-row';
  public static inline var BUNK_ALONG = 'bunk-along';
  public static inline var DESK_RUN = 'desk-run';
  public static inline var FILE_RUN = 'file-run';
  public static inline var DESK_ISLAND = 'desk-island';
  public static inline var RACK_RUN = 'rack-run';
  public static inline var CONSOLE_RUN = 'console-run';
  public static inline var SHELVING = 'shelving';
  public static inline var CRATE_ISLAND = 'crate-island';
  public static inline var COT_RUN = 'cot-run';
  public static inline var CABINET_RUN = 'cabinet-run';
  public static inline var COT_ISLAND = 'cot-island';
  public static inline var COUNTER_RUN = 'counter-run';
  public static inline var TABLE_ROWS = 'table-rows';
  public static inline var BOARD = 'map-board';
  public static inline var CUBICLES = 'cubicles';
  public static inline var TROUGH_RUN = 'trough-run';
  public static inline var GUN_CABINET = 'gun-cabinet';
  public static inline var SAFE = 'safe-spot';
  public static inline var LOCKER_RUN = 'locker-run';
  // what no demand wanted, and the room's floor paint, pushed after its zones
  public static inline var SLOT = 'mil-slot';
  public static inline var FLOOR = 'mil-floor';

  // a bay's marks: its wall (top, bottom, left, right, as roomWallRuns orders them), whether that is
  // the room's longest usable wall or the one facing it, whether it is a long or an end wall, and the
  // middle-of-the-floor bay
  public static inline var TAG_BEST = 'best';
  public static inline var TAG_FACE = 'face';
  public static inline var TAG_LONG = 'long';
  public static inline var TAG_SHORT = 'short';
  public static inline var TAG_FLOOR = 'floor';
  // and the room's own, when its deal fell short of a min; gen.GenCheck.militaryRooms fails on it
  public static inline var TAG_UNMET = 'unmet';

  // "as many as will fit", RoomZones.MANY's
  static inline var MANY = 99;
  // a bunk's depth off its wall, its footlocker included
  public static inline var BUNK_DEPTH = 3;

  static var KIND_OF = [
    ROLE_ARMORY => ARMORY,
    ROLE_HQ => HQ,
    ROLE_COMMS => COMMS,
    ROLE_SUPPLY => SUPPLY,
    ROLE_MEDICAL => MEDICAL,
    ROLE_BRIEFING => BRIEFING,
    ROLE_MESS => MESS,
    ROLE_BARRACKS => BARRACKS,
    ROLE_LATRINE => LATRINE,
  ];
  static var ZONES = [ BUNK_ROW, BUNK_ALONG, DESK_RUN, FILE_RUN, DESK_ISLAND, RACK_RUN, CONSOLE_RUN,
    SHELVING, CRATE_ISLAND, COT_RUN, CABINET_RUN, COT_ISLAND, COUNTER_RUN, TABLE_ROWS, BOARD, CUBICLES,
    TROUGH_RUN, GUN_CABINET, SAFE, LOCKER_RUN, SLOT, FLOOR ];

// the room kind a military role builds, or null for any other role
  public static function kindOf(role: String): String
    {
      return KIND_OF.get(role);
    }

// is this one of the base's room kinds?
  public static function isRoom(kind: String): Bool
    {
      return Lambda.has(KIND_OF, kind);
    }

// is this one of the zones a base room divides into?
  public static function isZone(kind: String): Bool
    {
      return ZONES.indexOf(kind) >= 0;
    }

// divide this room into its bays and deal its quota over them, then push its floor paint. Called
// from RoomBlock.glaze in place of the laboratory's deal: the glazing's own bays are the window
// bays a worktop runs under, and they are taken back off the node first
  public static function deal(state: _FacilityState, room: _Room, node: _GenNode,
      glazed: Array<_GenNode>)
    {
      for (b in glazed)
        node.children.remove(b);
      var cells = state.area.getCells();
      var runs = [for (run in FacilityRooms.roomWallRuns(state, room))
        [for (c in run)
          if (!RoomBlock.nextToWindow(cells, c.x, c.y) &&
              !nextToDoor(cells, c.x, c.y)) c]];
      var best = 0;
      for (i in 1...4)
        if (runs[i].length > runs[best].length)
          best = i;
      var alongX = (room.w >= room.h);
      var bays = [];
      for (w in 0...4)
        for (span in FacilityToilet.spans(runs[w]))
          {
            var a = span[0];
            var z = span[span.length - 1];
            var b = GenTree.add(node, RoomBlock.BAY, Std.int(Math.min(a.x, z.x)),
              Std.int(Math.min(a.y, z.y)), Std.int(Math.max(a.x, z.x)), Std.int(Math.max(a.y, z.y)));
            b.roomID = room.id;
            b.tags = [ 'w' + w, ((w < 2) == alongX ? TAG_LONG : TAG_SHORT) ];
            if (w == best)
              b.tags.push(TAG_BEST);
            if (w == (best ^ 1))
              b.tags.push(TAG_FACE);
            bays.push(b);
          }
      if (room.w >= 3 &&
          room.h >= 3)
        {
          var b = GenTree.add(node, RoomBlock.BAY, room.x1 + 1, room.y1 + 1, room.x2 - 1,
            room.y2 - 1);
          b.roomID = room.id;
          b.tags = [ TAG_FLOOR ];
          bays.push(b);
        }
      var want = demands(state, room, node.kind, bays);
      Quota.deal(bays, want, SLOT, state.area.rng);
      if (!Quota.satisfied(bays, want))
        node.tags = [ TAG_UNMET ];
      // the floor is painted after every zone has stood its furniture, and before the vent caps
      // glaze pushes next: a cap reads the floor inside its window, and painted it reads as not bare
      var f = GenTree.add(node, FLOOR, room.x1, room.y1, room.x2, room.y2);
      f.roomID = room.id;
    }

// the quota for one room. The core zone carries the room's min; the rest are `max` only and so are
// dealt in gen.Quota's second pass, in this order, before a `max: MANY` zone takes the leftovers
  static function demands(state: _FacilityState, room: _Room, kind: String,
      bays: Array<_GenNode>): Array<_GenDemand>
    {
      var alongX = (room.w >= room.h);
      // does any bay along wall `w` reach `n` cells?
      var reach = function(w: Int, n: Int)
        return Lambda.exists(bays, function(b)
          return (RoomBlock.tagged(b, 'w' + w) &&
            len(b) >= n));
      switch (kind)
        {
          // the cabinet in the middle of the longest wall, the safe (one per base) on another,
          // lockers on the rest and crates in the middle
          case ARMORY:
            var safe = (state.area.countSpawns('safe') == 0 ? 1 : 0);
            return [
              wall(GUN_CABINET, 1, 1, 1, function(b) return len(b)),
              wall(SAFE, 0, safe, 1, function(b) return (RoomBlock.tagged(b, TAG_BEST) ? 0 : 100)),
              floor(CRATE_ISLAND),
              wall(LOCKER_RUN, 0, 2, 1),
            ];

          // desks along the walls with the filing on the shortest bay, and desk pairs in the middle.
          // An office with no bay two cells long is filing only
          case HQ:
            var desks = Lambda.exists([ 0, 1, 2, 3 ], function(w) return reach(w, 2));
            return [
              wall(DESK_RUN, (desks ? 1 : 0), 1, 2, function(b) return len(b)),
              wall(FILE_RUN, (desks ? 0 : 1), 1, 1, function(b) return -len(b)),
              floor(DESK_ISLAND),
              wall(DESK_RUN, 0, MANY, 2),
            ];

          // the racks down the longest wall, the consoles facing them, a desk pair in the middle
          case COMMS:
            return [
              wall(RACK_RUN, 1, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_BEST) ? 100 : 0) + len(b)),
              wall(CONSOLE_RUN, 1, 2, 2, function(b)
                return (RoomBlock.tagged(b, TAG_FACE) ? 100 : 0) +
                  (RoomBlock.tagged(b, TAG_BEST) ? 0 : 50) + len(b)),
              floor(DESK_ISLAND),
            ];

          case SUPPLY:
            return [
              wall(SHELVING, 1, 1, 1, function(b) return len(b)),
              floor(CRATE_ISLAND),
              wall(SHELVING, 0, 2, 1),
            ];

          // cots along the longest wall and the one facing it, the cabinets on an end wall
          case MEDICAL:
            return [
              wall(COT_RUN, 1, 2, 1, function(b)
                return (RoomBlock.tagged(b, TAG_BEST) ? 100 : 0) +
                  (RoomBlock.tagged(b, TAG_FACE) ? 50 : 0) + len(b)),
              wall(CABINET_RUN, 0, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_BEST) ||
                  RoomBlock.tagged(b, TAG_FACE) ? 0 : 100)),
              floor(COT_ISLAND),
            ];

          // the counter (or the map board) on an end wall and the tables down the middle
          case MESS:
            return [
              wall(COUNTER_RUN, 1, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_SHORT) ? 100 : 0) + len(b)),
              floor(TABLE_ROWS),
            ];

          case BRIEFING:
            return [
              wall(BOARD, 1, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_SHORT) ? 100 : 0) + len(b)),
              floor(TABLE_ROWS),
            ];

          // bunks stood out from the long walls when the room is deep enough (both of them when
          // there is an aisle to spare), laid along a wall when it is not
          case BARRACKS:
            var depth = (alongX ? room.h : room.w);
            // the long wall the bunks go on first: the top or the left, unless doorways and glass
            // left it nothing to stand them against
            var first = (alongX ? 0 : 2);
            var deep = (depth >= BUNK_DEPTH + 1);
            if (!reach(first, (deep ? 1 : 3)))
              first ^= 1;
            var rowsOk = (deep &&
              reach(first, 1));
            // too shallow to stand them out from a long wall (or no long wall left to): lay them
            // ALONG the first wall that takes three in a line, the end walls included
            var lay = -1;
            if (!rowsOk)
              for (w in [ first, first ^ 1 ].concat(alongX ? [ 2, 3 ] : [ 0, 1 ]))
                if (lay < 0 &&
                    reach(w, 3))
                  lay = w;
            return [
              {
                kind: BUNK_ROW,
                min: (rowsOk ? 1 : 0),
                max: (rowsOk ? MANY : 0),
                minW: 1,
                minH: 1,
                must: function(b: _GenNode)
                  return (RoomBlock.tagged(b, 'w' + first) ||
                    depth >= BUNK_DEPTH * 2 + 1 &&
                    RoomBlock.tagged(b, 'w' + (first ^ 1))),
              },
              // and a room deep enough for one row and an aisle but not two lays a row along the
              // wall facing it, where it used to stand empty
              {
                kind: BUNK_ALONG,
                min: (lay >= 0 ? 1 : 0),
                max: MANY,
                minW: 1,
                minH: 1,
                must: function(b: _GenNode)
                  return (len(b) >= 3 &&
                    (rowsOk ?
                      depth >= BUNK_DEPTH + 2 &&
                      depth < BUNK_DEPTH * 2 + 1 &&
                      RoomBlock.tagged(b, 'w' + (first ^ 1)) :
                      RoomBlock.tagged(b, 'w' + lay))),
              },
            ];

          // the cubicles down the longest wall and the trough facing them
          case LATRINE:
            return [
              wall(CUBICLES, 1, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_BEST) ? 100 : 0) + len(b)),
              wall(TROUGH_RUN, 0, 1, 1, function(b)
                return (RoomBlock.tagged(b, TAG_FACE) ? 100 : 0) + len(b)),
            ];

          default:
            return [];
        }
    }

// a zone on one bay of a wall, at least `minLen` cells long
  static function wall(kind: String, min: Int, max: Int, minLen: Int,
      ?fit: _GenNode -> Int): _GenDemand
    {
      return {
        kind: kind,
        min: min,
        max: max,
        minW: 1,
        minH: 1,
        fit: fit,
        must: function(b: _GenNode)
          return (!RoomBlock.tagged(b, TAG_FLOOR) &&
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
          return RoomBlock.tagged(b, TAG_FLOOR),
      };
    }

// a wall bay's length in cells
  public static inline function len(b: _GenNode): Int
    {
      return Std.int(Math.max(GenTree.width(b), GenTree.height(b)));
    }

// the wall a bay stands against, as roomWallRuns numbers them, or -1 for the floor bay
  public static function wallOf(b: _GenNode): Int
    {
      for (w in 0...4)
        if (RoomBlock.tagged(b, 'w' + w))
          return w;
      return -1;
    }

// is there a doorway of any kind beside this cell?
  static function nextToDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var t = FacilityBuilding.at(cells, x + Const.dir4x[i], y + Const.dir4y[i]);
          if (t == TEMP_BUILDING_INNER_DOOR ||
              t == TEMP_BUILDING_SIDE_DOOR ||
              t == TEMP_BUILDING_FRONT_DOOR)
            return true;
        }
      return false;
    }
}

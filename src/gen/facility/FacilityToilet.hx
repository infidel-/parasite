// the washroom
//
// its own module because it is the one room template that builds its own geometry rather than
// dressing what FacilityBuilding left: it takes no bench runs and no ribbon glazing, and it divides
// itself in two. Everything else about it — the wall runs it ranks, the fittings it stands, the
// floor it paints — is FacilityRooms' shared machinery.

package gen.facility;

import Const;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.Quota;
import gen.blocks.RoomBlock;
import gen.blocks.RoomZones;
import gen.facility.FacilityTemp.*;

class FacilityToilet
{
  // how many cubicles one washroom may rank out in total, across every wall it builds on. a room is
  // at most 7x7 here, so two full walls would deal 14 and the place would read as a cell block
  public static inline var TOILET_STALL_MAX = 8;

  // the narrowest room, on either axis, that takes the T partition. below it the room is one space
  static inline var TOILET_SPLIT_MIN = 5;

  // how many cubicles THIS washroom has ranked out so far. a running total and not a parameter,
  // because the two halves are dealt in two passes and the runs are filled a tree level after that —
  // there is no one call the budget could be threaded through. Reset by `zones` at the top of each
  // washroom, which is the only thing that starts one
  static var stalls = 0;

// a washroom's glazing: small light wells up ONE wall and nothing on the other three.
//
// one wall because that is what a washroom has — a room you are not seen into gets its light from a
// single external face — and because every cell of the other three is then free for cubicles and
// basins, which is what roomToilet wants and what roomWallRuns measures.
//
// EVERY OTHER CELL and not a run: these are separate openings, not a ribbon, so the renderer maps one
// image across each rather than one across the whole length. the first and last cell of the wall are
// left as masonry so an opening never lands in a corner
  public static function toiletWindows(cells: Array<Array<Int>>, room: _Room)
    {
      var spot = FacilityRooms.exteriorWall(cells, room);
      if (spot == null)
        return;
      var delta = deltaMap[spot.dir];
      var len = (spot.dir == DIR_RIGHT ? room.w : room.h);
      for (i in 1...len - 1)
        if (i % 2 == 1)
          cells[spot.x + delta.x * (i + 1)][spot.y + delta.y * (i + 1)] =
            TEMP_BUILDING_WINDOW_HIGH;
    }

// divide a washroom into its zones: the T that splits it, the lobby strip against the door, and one
// dealt run of cubicles and one of basins in EACH half.
//
// EACH HALF IS DEALT ON ITS OWN, which is the whole reason there are two passes. One deal over all
// four walls put every cubicle on one side of the T and every basin on the other — two rooms, one
// with nowhere to wash and the other with nothing to use. Dealing per half runs the same quota twice
// and each half comes out a washroom.
//
// the LOBBY comes out of every run first. It is the strip you stand in with the door at your back,
// one cell deep, and a cubicle in it is a cubicle across the entrance
  public static function zones(state: _FacilityState, room: _Room, node: _GenNode)
    {
      stalls = 0;
      // the dividing wall goes in FIRST: it takes cells out of the wall runs below, and the two it
      // deliberately leaves bare are passages that nothing else may stand in
      var split = toiletPartition(state, room);
      var edges = FacilityRooms.roomWallRuns(state, room);
      for (run in edges)
        for (p in split.pass)
          {
            for (i in 0...run.length)
              if (run[i].x == p.x && run[i].y == p.y)
                {
                  run.splice(i, 1);
                  break;
                }
          }
      // the lobby is pushed outright rather than dealt: nothing competes for it, and a zone that
      // exists to stay empty has nothing to lose a deal to
      if (split.lobby >= 0)
        lobbyZone(node, room, split);
      for (half in 0...2)
        {
          var bays = [];
          for (run in edges)
            for (span in spans(halfRun(run, split, half)))
              {
                var n = GenTree.add(node, RoomBlock.BAY, span[0].x, span[0].y,
                  span[span.length - 1].x, span[span.length - 1].y);
                n.roomID = room.id;
                bays.push(n);
              }
          if (bays.length == 0)
            continue;
          Quota.deal(bays, RoomZones.washroom(bays), RoomBlock.SLOT, state.area.rng);
        }
    }

// cut a list of cells into its CONTIGUOUS runs.
//
// A NODE'S RECT MAY ONLY HOLD CELLS THE NODE OWNS, and this is what keeps that true. A washroom wall
// run arrives with cells already dropped out of the MIDDLE of it — FacilityRooms.roomWallRuns drops
// one beside a doorway or under an object, and `zones` above splices out the T's two PASSAGES — so a
// node built from the list's first and last cell claims those gaps as well. Both cost a compound,
// measured on seed 2993: first a cubicle went up on the cell dropped next to the NEIGHBOURING room's
// only door, and with that fixed another went up in the passage itself, sealing half the washroom
// and the office behind it. The old pass indexed the kept list and could not reach either.
//
// A SPAN OF ONE IS KEPT, and that is not the old rule. The old pass ranked a holey run by its total
// length and then stood fittings on non-adjacent cells, so a four-cell "counter" could be two pairs
// either side of a passage; ranking the pieces separately is what the runs really are. One cell
// still holds a basin — `basinRun` deals 1 + random(2) — and gen.blocks.RoomZones asks the CUBICLES
// for two, which is where the old minimum belonged
  static function spans(run: Array<{ x: Int, y: Int }>): Array<Array<{ x: Int, y: Int }>>
    {
      var out: Array<Array<{ x: Int, y: Int }>> = [];
      var cur: Array<{ x: Int, y: Int }> = [];
      for (c in run)
        {
          var last = (cur.length > 0 ? cur[cur.length - 1] : null);
          if (last != null &&
              Std.int(Math.abs(c.x - last.x) + Math.abs(c.y - last.y)) > 1)
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

// the cells of one wall run that fall in this half of the T: not in the lobby strip, not on the stem
// itself, and on the right side of it. a room too small for a T has no stem and no halves, so the
// whole of it is dealt on the first pass
  static function halfRun(run: Array<{ x: Int, y: Int }>, split: _ToiletSplit,
      half: Int): Array<{ x: Int, y: Int }>
    {
      var keep = [];
      for (c in run)
        {
          var o = (split.vertical ? c.x : c.y);
          if (split.lobby >= 0 &&
              o == split.lobby)
            continue;
          if (split.stem >= 0)
            {
              var s = (split.vertical ? c.y : c.x);
              if (s == split.stem ||
                  (s < split.stem) != (half == 0))
                continue;
            }
          else if (half > 0)
            continue;
          keep.push(c);
        }
      return keep;
    }

// the strip against the entrance wall, as a node. one cell deep and the room's full span
  static function lobbyZone(node: _GenNode, room: _Room, split: _ToiletSplit)
    {
      var n = (split.vertical ?
        GenTree.add(node, RoomBlock.LOBBY, split.lobby, room.y1, split.lobby, room.y2) :
        GenTree.add(node, RoomBlock.LOBBY, room.x1, split.lobby, room.x2, split.lobby));
      n.roomID = room.id;
    }

// rank a run of cubicles out along this wall
  public static function stallRun(state: _FacilityState, node: _GenNode)
    {
      var n = run(state, node, 2 + state.area.random(2));
      if (stalls + n > TOILET_STALL_MAX)
        n = TOILET_STALL_MAX - stalls;
      place(state, node, n, FIT_STALL);
      stalls += n;
    }

// and the basin counter along the next one
  public static function basinRun(state: _FacilityState, node: _GenNode)
    {
      place(state, node, run(state, node, 1 + state.area.random(2)), FIT_BASIN);
    }

// how many of this run's cells the zone fills
  static inline function run(state: _FacilityState, node: _GenNode, want: Int): Int
    {
      var len = RoomBlock.cellsOf(node).length;
      return (want > len ? len : want);
    }

// stand the first `n` cells of this run. every cell of it is one the run owns — see `spans`
  static function place(state: _FacilityState, node: _GenNode, n: Int, kind: _FittingKind)
    {
      var cells = RoomBlock.cellsOf(node);
      for (i in 0...n)
        FacilityRooms.placeFitting(state, cells[i].x, cells[i].y, kind);
    }

// make this room a washroom. the cubicles and the basins are standing by here — gen.blocks.RoomBlock
// dealt them a tree level up, because the zones are where a room's contents are decided now. All this
// owes is the finish: the marble, and the drain the laboratory rolls
  public static function roomToilet(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();

      // a washroom keeps the floor drain the laboratory rolls. BEFORE the marble, because the
      // paint is what turns TEMP_BUILDING_ROOM into a final id — run after it and the test below
      // can never hold. the drain tile is already final, so the paint steps over it
      var cx = room.x1 + 1 + area.random(room.w - 2),
        cy = room.y1 + 1 + area.random(room.h - 2);
      if (cells[cx][cy] == TEMP_BUILDING_ROOM &&
          area.chance(50))
        {
          cells[cx][cy] = Const.TILE_FLOOR_TILE + 1 + area.random(3);
          area.add('floorDrain', cx, cy);
        }

      FacilityRooms.paintRoomFloor(state, room, Const.TILE_FLOOR_MARBLE1);
    }

// split the washroom into its two halves and say where the split went.
//
// A LINE OF FITTINGS AND NOT A WALL. state.rooms is frozen at makeDoors and the room ids are already
// written into the cell grid, so masonry stamped here would leave two halves sharing one _Room, one
// id, one ceiling light and one stale mark. A fitting line costs none of that: placeFitting stamps
// each cell unwalkable exactly as a cubicle does, and render.facility.FacilityDeco stands a
// full-height slab on it (FacilityStyle.PART_T).
//
// AND IT IS A T, WHICH IS THE WHOLE POINT AND WAS A SINGLE LINE FOR ONE BUILD. That line ran down the
// middle with the cell at EACH end left open, and two halves joined at both ends are not two rooms —
// you walked in and could see and reach the whole place, which is the one thing a washroom may not
// do. A T fixes it with the same fittings:
//
//   * the BAR runs parallel to the entrance wall, ONE CELL IN FROM IT. The strip it leaves against
//     that wall is the lobby, i.e. the bit you stand in with the door behind you, and the cell at
//     each END of the bar is left open — those two are the passages, one into each half.
//   * the STEM runs from the middle of the bar to the opposite wall, so everything past the bar is
//     split in two and there is NO path from one half to the other.
//
// so the walk is door -> lobby -> the men's gap or the women's, and each half is closed. The bar's
// own middle cell is where the two lines meet, and render.facility.FacilityDeco.rectOf emits a CROSS
// there rather than one slab (see its FIT_PARTITION branch) — without that the stem stops
// (CELL - PART_T) / 2 short of the bar and the T has a hole in it.
//
// A ROOM UNDER TOILET_SPLIT_MIN ON EITHER AXIS GETS NO PARTITION AT ALL. A T in a 4-wide room is a
// bar of two slabs and a stem leaving one cell either side of it — two halves too narrow to hold a
// cubicle run and a basin each, reported from the game as half-broken. The single centre line this
// used to fall back to was worse: open at both ends, so it divided nothing
  static function toiletPartition(state: _FacilityState, room: _Room): _ToiletSplit
    {
      // which wall the door is in, as the hand pointing INTO the room off it. the door cell itself is
      // in the wall ring, i.e. outside the room's own rect, which is what makes this a comparison
      var side = -1;
      // ITS OWN DOORS, exactly the set FacilityRooms.washroomDoor picks the room by. A neighbour's
      // door can land in a wall this room shares with it, and taking the FIRST door in the list laid
      // the T against that wall instead — a lobby against an opening the washroom does not own, with
      // its real entrance then opening straight into one closed half
      for (d in FacilityConnect.getRoomDoors(state, room))
        {
          if (d.roomID1 != room.id)
            continue;
          if (d.x < room.x1)
            side = 3;
          else if (d.x > room.x2)
            side = 2;
          else if (d.y < room.y1)
            side = 1;
          else if (d.y > room.y2)
            side = 0;
          if (side >= 0)
            break;
        }
      if (side < 0 ||
          room.w < TOILET_SPLIT_MIN ||
          room.h < TOILET_SPLIT_MIN)
        return {
          pass: [],
          vertical: false,
          bar: -1,
          lobby: -1,
          stem: -1,
        };
      // the BAR is parallel to that wall, so it runs on the axis the hand is NOT on
      var vertical = (side >= 2);
      var barLen = (vertical ? room.h : room.w);
      var deep = (vertical ? room.w : room.h);
      // one cell in from the entrance wall, which leaves exactly one cell of lobby against it
      var bar = (vertical ?
        (side == 3 ? room.x1 + 1 : room.x2 - 1) :
        (side == 1 ? room.y1 + 1 : room.y2 - 1));
      var lobby = (vertical ?
        (side == 3 ? room.x1 : room.x2) :
        (side == 1 ? room.y1 : room.y2));
      // and the stem leaves the bar at its middle, on the same even-span rule the old line took
      var stem = (vertical ?
        room.y1 + Std.int(room.h / 2) :
        room.x1 + Std.int(room.w / 2));
      var pass = [];
      for (i in 0...barLen)
        {
          var x = (vertical ? bar : room.x1 + i);
          var y = (vertical ? room.y1 + i : bar);
          // the two ends of the bar are the passages
          if (i == 0 ||
              i == barLen - 1)
            {
              pass.push({ x: x, y: y });
              continue;
            }
          partitionCell(state, x, y);
        }
      // the stem, from the cell past the bar to the far wall
      for (i in 0...deep)
        {
          var o = (vertical ? room.x1 + i : room.y1 + i);
          // past the bar only: the lobby side of it is the entrance and must stay open. which way
          // "past" is depends on which wall the door was in, and sides 1 and 3 are the two the hand
          // runs with the axis on
          var beyond = (side == 3 || side == 1 ? o > bar : o < bar);
          if (!beyond)
            continue;
          if (vertical)
            partitionCell(state, o, stem);
          else partitionCell(state, stem, o);
        }
      return {
        pass: pass,
        vertical: vertical,
        bar: bar,
        lobby: lobby,
        stem: stem,
      };
    }

// one cell of the T. a cell already taken — a doorway's clearance, an object — is simply
// skipped: a wider gap in the middle of a partition is still a washroom, where a slab standing in a
// doorway is not
  static function partitionCell(state: _FacilityState, x: Int, y: Int)
    {
      var cells = state.area.getCells();
      if (cells[x][y] != TEMP_BUILDING_ROOM ||
          nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR) ||
          state.area.hasObjectAt(x, y))
        return;
      FacilityRooms.placeFitting(state, x, y, FIT_PARTITION);
    }
}

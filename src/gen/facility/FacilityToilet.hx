// the washroom
//
// its own module because it is the one room template that builds its own geometry rather than
// dressing what FacilityBuilding left: it takes no bench runs and no ribbon glazing, and it divides
// itself in two. Everything else about it — the wall runs it ranks, the fittings it stands, the
// floor it paints — is FacilityRooms' shared machinery.

package gen.facility;

import Const;
import game.AreaGenerator.*;
import gen.facility.FacilityTemp.*;

class FacilityToilet
{
  // how many cubicles one washroom may rank out in total, across every wall it builds on. a room is
  // at most 7x7 here, so two full walls would deal 14 and the place would read as a cell block
  static inline var TOILET_STALL_MAX = 8;

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

// make this room a washroom: a run of cubicles against the best wall, a basin counter against the
// next best, and no benches at all (makeWindows skipped it)
  public static function roomToilet(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
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
      // AND EACH HALF IS FURNISHED ON ITS OWN, which the one-room pass could not do. Sorting all four
      // walls together and giving the longest two cubicles put every cubicle on one side of the T and
      // every basin on the other — two rooms, one of them with nowhere to wash and the other with
      // nothing to use. Split by which side of the stem a cell is on and the same rule runs twice:
      // the half's longest wall takes cubicles, its next takes basins.
      //
      // the LOBBY comes out of every run first. It is the strip you stand in with the door at your
      // back, one cell deep, and a cubicle in it is a cubicle across the entrance
      var stalls = 0;
      for (half in 0...2)
        {
          var runs = [];
          for (run in edges)
            {
              var keep = [];
              for (c in run)
                {
                  var o = (split.vertical ? c.x : c.y);
                  if (split.lobby >= 0 &&
                      o == split.lobby)
                    continue;
                  // a room with no stem has no halves, so the whole of it is dealt on the first pass
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
              runs.push(keep);
            }
          // longest first: cubicles want the long wall, the basin counter takes the next, and
          // whatever is shortest is left bare — a half ranked out on every wall is a corridor with
          // nowhere to turn round
          runs.sort(function(a, b) return b.length - a.length);
          // TWO walls of the four, never more: the rest of the half is floor
          for (e in 0...2)
            {
              if (e >= runs.length)
                break;
              var run = runs[e];
              if (run.length < 2)
                continue;
              // the first wall of the half is cubicles, the next is basins
              var kind: _FittingKind = (e < 1 ? FIT_STALL : FIT_BASIN);
              var n = (kind == FIT_STALL ? 2 + area.random(2) : 1 + area.random(2));
              if (n > run.length)
                n = run.length;
              if (kind == FIT_STALL && stalls + n > TOILET_STALL_MAX)
                n = TOILET_STALL_MAX - stalls;
              for (i in 0...n)
                FacilityRooms.placeFitting(state, run[i].x, run[i].y, kind);
              if (kind == FIT_STALL)
                stalls += n;
            }
        }
      FacilityRooms.paintRoomFloor(state, room, Const.TILE_FLOOR_MARBLE1);

      // a washroom keeps the floor drain the laboratory rolls
      var cx = room.x1 + 1 + area.random(room.w - 2),
        cy = room.y1 + 1 + area.random(room.h - 2);
      if (cells[cx][cy] == TEMP_BUILDING_ROOM &&
          area.chance(50))
        {
          cells[cx][cy] = Const.TILE_FLOOR_TILE + 1 + area.random(3);
          area.add('floorDrain', cx, cy);
        }
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
// A ROOM TOO SMALL FOR A T FALLS BACK to the old single line: the bar needs three cells to have a
// middle that is not one of its own passages, and the stem needs a cell to stand in past it
  static function toiletPartition(state: _FacilityState, room: _Room): _ToiletSplit
    {
      // which wall the door is in, as the hand pointing INTO the room off it. the door cell itself is
      // in the wall ring, i.e. outside the room's own rect, which is what makes this a comparison
      var side = -1;
      for (d in FacilityConnect.getRoomDoors(state, room))
        {
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
      // the BAR is parallel to that wall, so it runs on the axis the hand is NOT on
      var vertical = (side >= 2);
      var barLen = (vertical ? room.h : room.w);
      var deep = (vertical ? room.w : room.h);
      if (side < 0 ||
          barLen < 3 ||
          deep < 3)
        return toiletLine(state, room);
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

// the single centre line the T falls back to on a room with no room for one. the shape this family
// shipped with, kept whole rather than special-cased inside the T: both ends open, no stem, and so no
// halves — `stem` comes back -1 and roomToilet furnishes the room as one space
  static function toiletLine(state: _FacilityState, room: _Room): _ToiletSplit
    {
      var vertical = (room.w >= room.h);
      var bar = (vertical ?
        room.x1 + Std.int(room.w / 2) :
        room.y1 + Std.int(room.h / 2));
      var len = (vertical ? room.h : room.w);
      var pass = [];
      for (i in 0...len)
        {
          var x = (vertical ? bar : room.x1 + i);
          var y = (vertical ? room.y1 + i : bar);
          if (i == 0 ||
              i == len - 1)
            {
              pass.push({ x: x, y: y });
              continue;
            }
          partitionCell(state, x, y);
        }
      return {
        pass: pass,
        vertical: vertical,
        bar: bar,
        lobby: -1,
        stem: -1,
      };
    }

// one cell of either line. a cell already taken — a doorway's clearance, an object — is simply
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

// one corp tower floor plate: the wall ring, the lift, the corridors and the rooms they carve out
//
// PORTED FROM game.CorpAreaGenerator.generateBuilding AND ITS SIX HELPERS, which were a near
// line-for-line fork of the facility's building pipeline written before either had a block tree.
// Two things changed on the way and neither is cosmetic:
//
//   * every roll comes off the seeded stream (`area.random` / `area.chance`) instead of
//     Std.random, so a corp floor is reproducible and `make gen args="--digest"` can gate a
//     refactor of it;
//   * the room THEMES are dealt by gen.blocks.CorpBlocks' quota instead of the dice ladder that
//     used to sit at the bottom of generateBuilding.
//
// what is unchanged is the carve itself: a main corridor driven in from the lift, side corridors
// rolled off it every ROOM_SIZE cells, rooms flooded out of what is left and halved while they are
// over ROOM_SIZE * 1.5.

package gen.corp;

import Const;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.blocks.CorpBlocks;
import gen.blocks.ElevatorBlock;
import gen.corp.CorpTemp.*;

class CorpBuilding
{
// build the whole plate and push the lift and every room as children of its node
  public static function generate(state: _CorpState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var bx = node.x1;
      var by = node.y1;
      var bw = GenTree.width(node);
      var bh = GenTree.height(node);

      // the wall ring, the floor inside it, and the 2-cell pavement apron outside it
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 ||
                y < 0 ||
                x >= area.width ||
                y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = BLDG_ROOM;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              {
                cells[x][y] = WALKWAY;
                continue;
              }
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = BLDG_WALL;
          }

      // pick which outer wall the lift stands against. `dir` is the direction the main corridor
      // runs INWARD from it, which is what every pass below and the lift block itself read
      var outerWalls = [
        { x1: bx, y1: by, x2: bx + bw - 1, y2: by, dir: DIR_DOWN },
        { x1: bx, y1: by, x2: bx, y2: by + bh - 1, dir: DIR_RIGHT },
        { x1: bx, y1: by + bh - 1, x2: bx + bw - 1, y2: by + bh - 1, dir: DIR_UP },
        { x1: bx + bw - 1, y1: by, x2: bx + bw - 1, y2: by + bh - 1, dir: DIR_LEFT },
      ];
      var frontWall = outerWalls[area.random(outerWalls.length)];
      state.frontDir = frontWall.dir;

      var frontDoor = null;
      if (frontWall.dir == DIR_UP ||
          frontWall.dir == DIR_DOWN)
        frontDoor = {
          x: Std.int((frontWall.x2 - frontWall.x1) / 2) + frontWall.x1,
          y: frontWall.y1,
        };
      else frontDoor = {
        x: frontWall.x1,
        y: Std.int((frontWall.y2 - frontWall.y1) / 2) + frontWall.y1,
      };

      // the lift is a BLOCK: it is pushed here and painted by the walk a level later, because
      // nothing the plate does afterwards reads the cells it writes (they are all outside the
      // wall ring, bar the one door cell the corridor never touches)
      ElevatorBlock.node(state, node, frontDoor.x, frontDoor.y, frontWall.dir);

      // drive the main corridor in from the lift door, branching every ROOM_SIZE cells
      var len = 0, x = frontDoor.x, y = frontDoor.y;
      if (frontWall.dir == DIR_UP ||
          frontWall.dir == DIR_DOWN)
        x--;
      else y--;
      var delta = deltaMap[frontWall.dir];
      var sideCount1 = 0, sideCount2 = 0;
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('CorpBuilding: main corridor ran past 100 cells');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < BLDG_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              // cap the far end off, so the corridor does not open onto the pavement
              drawChunk(cells, x, y, CORRIDOR_W, frontWall.dir, BLDG_WALL);
              break;
            }
          drawChunk(cells, x, y, CORRIDOR_W, frontWall.dir, BLDG_CORRIDOR);

          // a branch off each hand, never closer than ROOM_SIZE to the last one on that hand and
          // never within ROOM_SIZE of the far wall — a stub that short is not a corridor, it is a
          // notch in one room
          sideCount1++;
          if (sideCount1 > ROOM_SIZE &&
              area.random(100) > 70)
            {
              var dir = (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN
                ? DIR_LEFT : DIR_UP);
              if (distanceToFinish(state, x, y, frontWall.dir) > ROOM_SIZE)
                drawSideCorridor(state, x, y, dir);
              sideCount1 = 0;
            }
          sideCount2++;
          if (sideCount2 > ROOM_SIZE &&
              area.random(100) > 70)
            {
              var dir = (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN
                ? DIR_RIGHT : DIR_DOWN);
              if (distanceToFinish(state, x, y, frontWall.dir) > ROOM_SIZE)
                drawSideCorridor(state, x, y, dir);
              sideCount2 = 0;
            }
        }

      // the stairs, in the corner of the corridor's far end. ONE OBJECT AND NOT A BLOCK: nothing
      // about it is laid out, it is a single cell with a model on it
      var sx = x, sy = y;
      switch (frontWall.dir)
        {
          case DIR_LEFT:
            sx++;
            sy++;
          case DIR_RIGHT:
            sx--;
            sy++;
          case DIR_UP:
            sx++;
            sy++;
          default:
            sx++;
            sy--;
        }
      area.add('stairs', sx, sy);

      // and the window at the far end of the corridor, so the walk in from the lift ends on the
      // city rather than on a blank wall
      if (frontWall.dir == DIR_UP ||
          frontWall.dir == DIR_DOWN)
        {
          cells[x][y] = BLDG_WINDOWH1;
          cells[x + 1][y] = BLDG_WINDOWH2;
          cells[x + 2][y] = BLDG_WINDOWH3;
        }
      else
        {
          cells[x][y] = BLDG_WINDOWV1;
          cells[x][y + 1] = BLDG_WINDOWV2;
          cells[x][y + 2] = BLDG_WINDOWV3;
        }

      // every floor cell touching a corridor becomes the rooms' shared wall
      for (y in by + 1...by + bh + 1)
        for (x in bx + 1...bx + bw + 1)
          if (cells[x][y] == BLDG_ROOM &&
              nextTo(cells, x, y, BLDG_CORRIDOR))
            cells[x][y] = BLDG_INNER_WALL;

      // halve whatever came out oversized
      subdivideLargeRooms(state, bx, by, bw, bh);
      replaceTiles(cells, bx, by, bw, bh, BLDG_ROOM_MARKED, BLDG_ROOM);

      makeDoors(state, bx, by, bw, bh);
      fixDoors(state);
      makeWindows(state);

      // and last, deal each room its kind. AFTER makeWindows, because that pass clears every room
      // back to bare floor before it draws the glazing and would wipe a template that ran first
      CorpBlocks.assign(state, node);
    }

// THE ROOMS A WC OR A SERVER ROOM MUST NOT BE DEALT TO: something else's only route runs through
// them.
//
// fixDoors gives every room a door onto a corridor wherever its own walls allow one, and a few
// per cent of towers hold a room whose walls do not — it sits behind the rooms on the plate's edge
// with no corridor of its own to open onto, so its one door goes to the room in front of it. If
// THAT room is then dealt the WC, the only way in is through the WC: the server room reached
// through the toilet, exactly as reported from the game.
//
// REPAIRED BY NOT DEALING IT rather than by cutting another door, because there is no other door
// to cut — the walls that would take one face the plate's edge, which is why the room is in this
// position at all. gen.blocks.CorpBlocks.demands hands this to its `must`, which Quota.deal and
// gen.GenCheck.blocksFit both honour, so the toilet simply lands somewhere a corridor reaches
  public static function passThrough(state: _CorpState): Map<Int, Bool>
    {
      var out = new Map<Int, Bool>();
      for (r in state.rooms)
        if (blocksRoute(state, r.id))
          out.set(r.id, true);
      return out;
    }

// the rooms a finished deal has put in the way: every WC and server room on the floor, named only
// when SOMETHING IS BEHIND THEM.
//
// The single-room test above cannot see this case and asking it of PAIRS instead is far too
// strong — it rules out a room in any two-room cut whatever the other room turns out to be, and
// measured, that left 997 of 3000 towers with nowhere to put a server room at all. So the pair is
// not predicted: the deal is made, the routes are walked, and CorpBlocks.assign re-deals with
// whatever was in the way added to `blocked`. 3 towers in 3000 need the second attempt
  public static function deadEnds(state: _CorpState): Array<Int>
    {
      var seen = new Map<Int, Bool>();
      seen.set(0, true);
      var open = [0];
      while (open.length > 0)
        {
          var id = open.pop();
          if (id != 0 && isDeadEnd(state, id))
            continue;
          for (d in state.doors)
            {
              var far = (d.roomID1 == id ? d.roomID2 : (d.roomID2 == id ? d.roomID1 : -1));
              if (far < 0 ||
                  seen.exists(far))
                continue;
              seen.set(far, true);
              open.push(far);
            }
        }
      for (r in state.rooms)
        if (!seen.exists(r.id))
          return [for (d in state.rooms) if (isDeadEnd(state, d.id)) d.id];
      return [];
    }

// is this room one nobody should have to walk THROUGH?
  static function isDeadEnd(state: _CorpState, roomID: Int): Bool
    {
      for (r in state.rooms)
        if (r.id == roomID)
          return r.role == ROLE_TOILET || r.role == ROLE_SERVERS;
      return false;
    }

// would shutting this room off leave another room with no way to the corridor? walked over the
// DOOR GRAPH and not the tiles, from room 0 — the corridor, doorsSane's own sentinel
  static function blocksRoute(state: _CorpState, roomID: Int): Bool
    {
      var seen = new Map<Int, Bool>();
      seen.set(0, true);
      var open = [0];
      while (open.length > 0)
        {
          var id = open.pop();
          for (d in state.doors)
            {
              var far = (d.roomID1 == id ? d.roomID2 : (d.roomID2 == id ? d.roomID1 : -1));
              if (far < 0 ||
                  far == roomID ||
                  seen.exists(far))
                continue;
              seen.set(far, true);
              open.push(far);
            }
        }
      for (r in state.rooms)
        if (r.id != roomID &&
            !seen.exists(r.id))
          return true;
      return false;
    }

// halve every room still over ROOM_SIZE * 1.5 on either axis
  static function subdivideLargeRooms(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in by + 1...by + bh)
        for (x in bx + 1...bx + bw)
          {
            if (cells[x][y] != BLDG_ROOM)
              continue;
            var room = getRoom(cells, x, y);
            var dir = 0;
            if (room.w > ROOM_SIZE * 1.5)
              dir = DIR_DOWN;
            if (room.h > ROOM_SIZE * 1.5)
              dir = DIR_RIGHT;
            if (dir == 0)
              {
                markRoom(cells, room, BLDG_ROOM_MARKED);
                continue;
              }

            var sx = 0, sy = 0;
            if (dir == DIR_DOWN)
              {
                var neww = Std.int(room.w / 2);
                if (area.chance(30))
                  neww = Std.int(room.w / 3);
                neww += area.random(4) - 2;
                if (neww < 4)
                  neww = 4;
                sx = room.x1 + neww;
                sy = room.y1;
              }
            else
              {
                var newh = Std.int(room.h / 2);
                if (area.chance(30))
                  newh = Std.int(room.h / 3);
                newh += area.random(4) - 2;
                if (newh < 4)
                  newh = 4;
                sx = room.x1;
                sy = room.y1 + newh;
              }
            drawLine(cells, sx, sy, dir, BLDG_INNER_WALL);
            markRoom(cells, getRoom(cells, x, y), BLDG_ROOM_MARKED);
          }
    }

// flood every room out of the carve, number it, and cut it one door
  static function makeDoors(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var doors = [];
      var rooms = [];
      for (y in (by + 1)...(by + bh))
        for (x in (bx + 1)...(bx + bw))
          {
            if (cells[x][y] != BLDG_ROOM)
              continue;

            var room = getRoom(cells, x, y);
            room.id = state.nextRoomID++;
            rooms.push(room);

            var spots = [];
            for (s in getRoomDoorSpots(room))
              {
                if (cells[s.x][s.y] != BLDG_INNER_WALL)
                  continue;
                // a cell with three or more walls round it is an inside corner, and a door cut
                // into one opens into masonry
                var cnt = 0;
                for (i in 0...Const.dir4x.length)
                  {
                    var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
                    if (t == BLDG_INNER_WALL ||
                        t == BLDG_WALL)
                      cnt++;
                  }
                if (cnt > 2)
                  continue;
                spots.push(s);
              }
            if (spots.length == 0)
              {
                markRoom(cells, room, room.id);
                continue;
              }
            var spot = spots[area.random(spots.length)];
            cells[spot.x][spot.y] = BLDG_INNER_DOOR;
            doors.push({
              x: spot.x,
              y: spot.y,
              dir: spot.dir,
              roomID1: room.id,
              roomID2: -1,
              skip: false,
            });
            markRoom(cells, room, room.id);
          }
      state.doors = doors;
      state.rooms = rooms;
    }

// drop doors that join the same pair of rooms twice, and give every ROOM that has no corridor exit
// one of its own
  static function fixDoors(state: _CorpState)
    {
      var doors = state.doors;
      var cells = state.area.getCells();
      for (door in doors)
        {
          var delta = deltaMap[door.dir];
          door.roomID2 = cells[door.x + delta.x][door.y + delta.y];
          if (door.roomID2 < BLDG_ROOM_ID_START)
            door.roomID2 = 0;
        }

      var toRemove = [];
      for (door in doors)
        {
          if (door.skip || door.roomID2 == 0)
            continue;
          for (door2 in doors)
            {
              if (door2.skip || door2.roomID2 == 0 || door2 == door)
                continue;
              if (door2.roomID1 == door.roomID2 &&
                  door.roomID1 == door2.roomID2)
                {
                  toRemove.push(door);
                  door2.skip = true;
                }
            }
        }
      for (door in toRemove)
        {
          cells[door.x][door.y] = BLDG_INNER_WALL;
          doors.remove(door);
        }

      // EVERY ROOM OWNS A DOOR ONTO A CORRIDOR, AND A CLUSTER DOES NOT COUNT.
      //
      // This used to group the rooms the surviving doors join and open ONE door per group that
      // reached no corridor — a test satisfied the moment ANY room in the group touched one. So
      // `servers -> toilet -> corridor` passed it, and the server room was reported from the game
      // as reachable only by walking through the WC. A route through somebody else's room is not
      // a route: the question is asked per ROOM, and the room that cannot answer cuts its own
      // door. This also subsumes the pass that followed it, for a room makeDoors cut no door into
      // at all (every one of its wall spots an inside corner) — that room owns nothing either
      for (room in state.rooms)
        {
          var own = false;
          for (d in doors)
            {
              if (d.roomID1 != room.id)
                continue;
              var delta = deltaMap[d.dir];
              if (cells[d.x + delta.x][d.y + delta.y] == BLDG_CORRIDOR)
                {
                  own = true;
                  break;
                }
            }
          if (!own)
            makeDoorToCorridor(state, room.id);
        }
    }

// find a wall of this room that is adjacent to a corridor and cut a door through it
  static function makeDoorToCorridor(state: _CorpState, roomID: Int): Bool
    {
      var cells = state.area.getCells();
      var room = null;
      for (r in state.rooms)
        if (r.id == roomID)
          {
            room = r;
            break;
          }
      if (room == null)
        return false;

      var spots = [];
      for (s in getRoomDoorSpots(room))
        {
          var delta = deltaMap[s.dir];
          if (cells[s.x + delta.x][s.y + delta.y] != BLDG_CORRIDOR)
            continue;
          spots.push(s);
        }
      if (spots.length == 0)
        return false;
      var spot = spots[state.area.random(spots.length)];
      cells[spot.x][spot.y] = BLDG_INNER_DOOR;
      state.doors.push({
        x: spot.x,
        y: spot.y,
        dir: spot.dir,
        roomID1: roomID,
        roomID2: 0,
        skip: false,
      });
      return true;
    }

  static var windowTilesList = [
    [ BLDG_WINDOWH1, BLDG_WINDOWH2, BLDG_WINDOWH3 ],
    [ BLDG_WINDOWV1, BLDG_WINDOWV2, BLDG_WINDOWV3 ],
  ];
  static var innerWindowTilesList = [
    [ INNER_WINDOWH1, INNER_WINDOWH2, INNER_WINDOWH3 ],
    [ INNER_WINDOWV1, INNER_WINDOWV2, INNER_WINDOWV3 ],
  ];

// clear every room back to bare floor and run glazing along its two walls.
//
// an OUTER wall gets the curtain-wall run, an inner one usually gets the office partition glass —
// which is what makes the floor read as one open volume cut up by glass rather than as a warren
  static function makeWindows(state: _CorpState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (room in state.rooms)
        {
          drawBlock(cells, room.x1, room.y1, room.w, room.h, BLDG_ROOM);
          for (spot in getRoomWallCorners(room))
            {
              var delta = deltaMap[spot.dir];
              var innerWall = (cells[spot.x + delta.x][spot.y + delta.y] != BLDG_WALL);
              var windowIdx = (spot.dir == DIR_DOWN ? 1 : 0);
              var windowTiles = (innerWall
                ? innerWindowTilesList[windowIdx] : windowTilesList[windowIdx]);

              var newWindow = true;
              var hasWindow = true;
              var x = spot.x, y = spot.y;
              // most inner walls are solid; the glazed ones are the exception that reads
              if (cells[x + delta.x][y + delta.y] == BLDG_INNER_WALL &&
                  area.chance(70))
                hasWindow = false;
              while (true)
                {
                  x += delta.x;
                  y += delta.y;
                  if (x < 0 ||
                      y < 0 ||
                      x >= area.width ||
                      y >= area.height)
                    break;
                  // a doorway breaks the run and the pane before it takes the closing frame
                  if (cells[x][y] == BLDG_INNER_DOOR)
                    {
                      if (hasWindow)
                        cells[x - delta.x][y - delta.y] = windowTiles[2];
                      newWindow = true;
                      continue;
                    }
                  if (spot.dir == DIR_RIGHT && x >= room.x2 + 1)
                    break;
                  else if (spot.dir == DIR_DOWN && y >= room.y2 + 1)
                    break;
                  if (hasWindow)
                    cells[x][y] = windowTiles[newWindow ? 0 : 1];
                  newWindow = false;
                }
              // and close the last pane of the run, whichever frame it was left on
              x -= delta.x;
              y -= delta.y;
              var t = cells[x][y];
              if (t == BLDG_WINDOWH2)
                cells[x][y] = BLDG_WINDOWH3;
              else if (t == BLDG_WINDOWH1)
                cells[x][y] = BLDG_WINDOW;
              else if (t == BLDG_WINDOWV2)
                cells[x][y] = BLDG_WINDOWV3;
              else if (t == BLDG_WINDOWV1)
                cells[x][y] = BLDG_WINDOW;
              else if (t == INNER_WINDOWH2)
                cells[x][y] = INNER_WINDOWH3;
              else if (t == INNER_WINDOWH1)
                cells[x][y] = INNER_WINDOW;
              else if (t == INNER_WINDOWV2)
                cells[x][y] = INNER_WINDOWV3;
              else if (t == INNER_WINDOWV1)
                cells[x][y] = INNER_WINDOW;
            }
        }
    }

// how far it is from here to the end of the corridor running this way
  static function distanceToFinish(state: _CorpState, sx: Int, sy: Int, dir: Int): Int
    {
      var cells = state.area.getCells();
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            break;
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < BLDG_WALL)
            break;
        }
      return len - 1;
    }

// a narrow branch off the main corridor, ending on the outer wall — usually in a window
  static function drawSideCorridor(state: _CorpState, sx: Int, sy: Int, dir: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('CorpBuilding: side corridor ran past 100 cells');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < BLDG_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              drawChunk(cells, x, y, SIDE_CORRIDOR_W, dir, BLDG_WALL);
              if (area.chance(60))
                cells[x][y] = BLDG_WINDOW;
              break;
            }
          drawChunk(cells, x, y, SIDE_CORRIDOR_W, dir, BLDG_CORRIDOR);
        }
    }
}

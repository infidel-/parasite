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
import game.AreaGenerator._Spot;
import gen.GenTree;
import gen.blocks.CorpBlocks;
import gen.blocks.ElevatorBlock;
import gen.corp.CorpTemp.*;

class CorpBuilding
{
  // the narrowest half a subdivision cut may leave. it is a floor on the jitter and not on the
  // room: a cut takes the half width, rolls a third 30% of the time and then moves +-2, and this
  // is what stops that arithmetic producing a slot nothing can be put in.
  //
  // 6 AND NOT 4, and the oracle is what says so rather than taste. At 4, with the cap brought
  // down to ROOM_SIZE * SUBDIVIDE_OVER, the carve minted enough 4-wide slots that 11 towers in
  // 3,000 had no room left that clears the washroom's and the server room's own 5 x 5 minimum and
  // came out "quota short: room-toilet got 0". A 4-wide room was also the one the old open-plan
  // template could not furnish at all (it laid no desk under 7), so the same number fixed both
  static inline var SPLIT_MIN = 5;

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
          // notch in one room.
          //
          // THE ROLL IS 50% AND WAS 30%, because the ROOM behind the branch got smaller. At 30%
          // the gap between two branches on one hand is ROOM_SIZE plus a geometric tail, ~9 cells
          // on a 10-cell room; against a 5-cell room that is two rooms deep and the inner one has
          // no corridor wall at all. Whole corner blocks came out with no frontage: 8 towers in
          // 3,000 held a cluster gen.corp.CorpConnect could not open, because there was nothing
          // reached anywhere on its boundary to open onto
          sideCount1++;
          if (sideCount1 > ROOM_SIZE &&
              area.random(100) > 50)
            {
              var dir = (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN
                ? DIR_LEFT : DIR_UP);
              if (distanceToFinish(state, x, y, frontWall.dir) > ROOM_SIZE)
                drawSideCorridor(state, x, y, dir);
              sideCount1 = 0;
            }
          sideCount2++;
          if (sideCount2 > ROOM_SIZE &&
              area.random(100) > 50)
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

      // and the stairs' SECOND CELL, which the model's down flight stands over: beside the stairs on
      // the right hand of someone facing the end wall, sealed as the corridor carpet's unwalkable
      // twin. LAST, because it is corridor to every pass above — written before the walls went up,
      // the room cell behind it was never walled off from the corridor
      var twin = stairsTwin(sx, sy, sx + delta.x, sy + delta.y);
      cells[twin.x][twin.y] = Const.TILE_FLOOR_CARPET + UNWALKABLE_TILE_OFFSET;
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
      var base = reached(state, -1);
      for (r in state.rooms)
        if (blocksRoute(state, r.id, base))
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
      // THE RECEPTION'S FRONT IS WALKED AS SHUT, because its template will shut it — the counter
      // takes the whole wall. A WC that is the reception's only other way in is otherwise a dead
      // end this walk passes and gen.GenCheck.corpRoutesSane, reading the finished doors, does not
      var shut = [];
      for (r in state.rooms)
        if (r.role == ROLE_RECEPTION)
          shut = frontDoors(state, CorpBlocks.fronts.get(r.id));
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
                  seen.exists(far) ||
                  shut.indexOf(d) >= 0)
                continue;
              seen.set(far, true);
              open.push(far);
            }
        }
      // and it names EVERY WC and server room on the floor, not just the one in the way. Narrowed
      // to those that individually fail blocksRoute it went from 1 failing seed in 3,000 to more
      // than 30: the case this exists for is TWO dead ends in parallel, where neither of them on
      // its own disconnects anything and the pair does. What keeps the bluntness affordable is
      // the cap on how much of it CorpBlocks.assign is allowed to act on per round
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

// every room the corridor reaches over the DOOR GRAPH — not the tiles — with `skip` shut off, and
// every door in `shut` closed. `skip` of -1 shuts nothing and gives the baseline. From room 0,
// doorsSane's own sentinel
  static function reached(state: _CorpState, skip: Int, ?shut: Array<_Door>): Map<Int, Bool>
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
                  far == skip ||
                  seen.exists(far) ||
                  (shut != null &&
                  shut.indexOf(d) >= 0))
                continue;
              seen.set(far, true);
              open.push(far);
            }
        }
      return seen;
    }

// would shutting this room off cut the corridor off from a room it OTHERWISE reaches?
//
// AGAINST THE BASELINE, which is the whole of the fix and was the bug: this used to ask whether
// every room in state.rooms was still seen, so ONE room the corridor cannot reach at all made it
// true for every roomID — and CorpConnect's guarantee is that the LIFT reaches every room over
// TILES, which is a different graph from the doors'. Measured on seed 777: all 18 rooms came back
// blocked, CorpBlocks.assign had nowhere legal left for either 5 x 5 demand, and the protection
// turned itself off entirely — the server room behind the toilet that started all this
  static function blocksRoute(state: _CorpState, roomID: Int, base: Map<Int, Bool>): Bool
    {
      var seen = reached(state, roomID);
      for (r in state.rooms)
        if (r.id != roomID &&
            base.exists(r.id) &&
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
            // CUT UNTIL IT FITS, and the loop is the fix. This used to cut ONCE and then mark
            // whatever was left at (x, y) done — but a cut makes TWO rooms, and only the far one
            // stays BLDG_ROOM for the scan to find again. The near one was stamped finished at
            // whatever size one cut left it, which is where the 20-to-26-cell tail came from:
            // 235 rooms of 3,629, exactly one cut short of the cap.
            //
            // (x, y) is the room's TOP-LEFT — the scan is row-major and getRoom measures right
            // and down from where it is given, never walking back — and it stays the top-left of
            // the near product, so re-measuring there is what lets the same cell be cut twice
            var room = getRoom(cells, x, y);
            var cap = ROOM_SIZE * SUBDIVIDE_OVER;
            while (true)
              {
                // **SPLIT_MIN FLOORS BOTH PRODUCTS, NOT JUST THE NEAR ONE.** It used to clamp the
                // near side alone, and the far side is `span - near - 1` — which was safe only by
                // luck at the old 12-cell cap, where the smallest room that could be cut was 13
                // and left 6 behind. Dropping the cap to 8 made rooms of 9..12 cuttable and the
                // far side came out 2 to 5 cells: measured, **1,456 of 3,000 towers** had a room
                // that could not be walked into, the first of them a 2 x 2.
                //
                // so an axis is cuttable only when BOTH halves can clear SPLIT_MIN, i.e. when it
                // is at least `2 * SPLIT_MIN + 1`, and a room that is over the cap on an axis it
                // cannot cut simply stays over the cap. That is the real floor on room size and
                // it is why the cap alone does not set the room count
                var room2 = SPLIT_MIN * 2 + 1;
                var cutW = (room.w > cap && room.w >= room2);
                var cutH = (room.h > cap && room.h >= room2);
                if (!cutW && !cutH)
                  break;
                // h wins a tie, which is the order the old pair of ifs resolved in
                var dir = (cutH ? DIR_RIGHT : DIR_DOWN);
                var sx = 0, sy = 0;
                if (dir == DIR_DOWN)
                  {
                    var neww = Std.int(room.w / 2);
                    if (area.chance(30))
                      neww = Std.int(room.w / 3);
                    neww += area.random(4) - 2;
                    if (neww > room.w - 1 - SPLIT_MIN)
                      neww = room.w - 1 - SPLIT_MIN;
                    if (neww < SPLIT_MIN)
                      neww = SPLIT_MIN;
                    sx = room.x1 + neww;
                    sy = room.y1;
                  }
                else
                  {
                    var newh = Std.int(room.h / 2);
                    if (area.chance(30))
                      newh = Std.int(room.h / 3);
                    newh += area.random(4) - 2;
                    if (newh > room.h - 1 - SPLIT_MIN)
                      newh = room.h - 1 - SPLIT_MIN;
                    if (newh < SPLIT_MIN)
                      newh = SPLIT_MIN;
                    sx = room.x1;
                    sy = room.y1 + newh;
                  }
                drawLine(cells, sx, sy, dir, BLDG_INNER_WALL);
                room = getRoom(cells, x, y);
              }
            markRoom(cells, room, BLDG_ROOM_MARKED);
          }
    }

// which of these candidate cells a door could actually be cut into
  static function doorSpots(cells: Array<Array<Int>>, list: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in list)
        {
          if (cells[s.x][s.y] != BLDG_INNER_WALL)
            continue;
          // a cell with three or more walls round it is an inside corner, and a door cut into one
          // opens into masonry
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
          out.push(s);
        }
      return out;
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

            // the four wall MIDPOINTS first, so a door lands in the middle of its wall wherever
            // one legally can and the floor plan reads as it always has
            var spots = doorSpots(cells, getRoomDoorSpots(room));
            if (spots.length == 0)
              // AND EVERY OTHER CELL OF THE WALL RING when none of the four works, most central
              // first. game.AreaGenerator.getRoomWallSpots exists for exactly this and its own
              // header measured the cost of not using it — four candidates out of a perimeter of
              // 2(w+h), and a room whose four midpoints all happen to be exterior masonry gets no
              // door at all. The compound has used the fallback since FacilityConnect was written;
              // this generator never did, and it did not show while rooms were 8 x 8. Halving them
              // made it show: 5 towers in 150 carried a room nothing could walk into
              spots = doorSpots(cells, getRoomWallSpots(room));
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

      // AND A ROOM THAT STILL CANNOT BE WALKED INTO CUTS A DOOR INTO SOMEWHERE THAT CAN.
      //
      // The pass above gives a room a corridor door WHERE ITS OWN WALLS ALLOW ONE, and a room in
      // the middle of a block has none — the corridor lattice branches every ROOM_SIZE cells and
      // two rooms now fit between two branches. Measured at the halved room size: **1,038 rooms
      // over 200 towers own no corridor door**, five per floor. Most are fine, because the one
      // door makeDoors cut leads somewhere that is; the ones that are not are a chain of cut-off
      // rooms that dead-ends, and the oracle sees that as a room nothing can walk into.
      //
      // **IT IS FLOODED OVER TILES AND NOT OVER THE DOOR GRAPH**, which is the trap here and cost
      // an attempt. `reached` treats every non-room cell as ONE node, id 0, so two corridor
      // fragments with no path between them are the same node to it — the door graph came back
      // fully connected on every one of 200 towers while 37 of them still had a room the tile
      // flood could not enter. gen.GenCheck.reachable walks tiles, so this walks tiles.
      //
      // gen.facility.FacilityConnect has had the shape of the answer since it was written —
      // `pickRoomSpot` takes a `reachable` set and opens into it. Iterated, because opening one
      // room makes its neighbour reachable in turn, and bounded by the room count
      var guard = 0;
      while (guard++ <= state.rooms.length)
        {
          var open = floodWalkable(state);
          var cut = false;
          for (room in state.rooms)
            {
              if (open[room.x1][room.y1])
                continue;
              if (joinOpen(state, room, open))
                cut = true;
            }
          if (!cut)
            break;
        }
    }

// every walkable cell the corridors reach, over TILES. The carve's own ids: a room is stamped with
// its own id by makeDoors, a corridor is BLDG_CORRIDOR and a cut door BLDG_INNER_DOOR
  static function floodWalkable(state: _CorpState): Array<Array<Bool>>
    {
      var area = state.area;
      var cells = area.getCells();
      var w = area.width;
      var h = area.height;
      var seen = [for (x in 0...w) [for (y in 0...h) false]];
      inline function walkable(t: Int)
        return (t == BLDG_CORRIDOR || t == BLDG_INNER_DOOR || t == BLDG_ROOM ||
          t >= BLDG_ROOM_ID_START);
      var open = [];
      for (y in 0...h)
        for (x in 0...w)
          if (cells[x][y] == BLDG_CORRIDOR)
            {
              seen[x][y] = true;
              open.push({ x: x, y: y });
            }
      while (open.length > 0)
        {
          var p = open.pop();
          for (i in 0...Const.dir4x.length)
            {
              var nx = p.x + Const.dir4x[i];
              var ny = p.y + Const.dir4y[i];
              if (nx < 0 || ny < 0 || nx >= w || ny >= h || seen[nx][ny])
                continue;
              if (!walkable(cells[nx][ny]))
                continue;
              seen[nx][ny] = true;
              open.push({ x: nx, y: ny });
            }
        }
      return seen;
    }

// cut this room a door into a cell the corridors already reach, most central of its wall first
  static function joinOpen(state: _CorpState, room: _Room, open: Array<Array<Bool>>): Bool
    {
      var cells = state.area.getCells();
      for (s in doorSpots(cells, getRoomWallSpots(room)))
        {
          var delta = deltaMap[s.dir];
          var fx = s.x + delta.x;
          var fy = s.y + delta.y;
          if (!open[fx][fy])
            continue;
          var far = cells[fx][fy];
          cells[s.x][s.y] = BLDG_INNER_DOOR;
          state.doors.push({
            x: s.x,
            y: s.y,
            dir: s.dir,
            roomID1: room.id,
            roomID2: (far >= BLDG_ROOM_ID_START ? far : 0),
            skip: false,
          });
          return true;
        }
      return false;
    }

// A ROOM'S FRONT, the wall a reception's counter replaces: the one that faces a corridor along its
// whole length and comes nearest the lift door, as the ring cells alongside the room's floor (the
// corner posts are not in it), or an empty list when no wall does both within `near` cells.
// `dir` on each spot is the hand the wall faces out of the room, `dir90` the way the run goes.
//
// READ OFF THE CARVE BEFORE ANY TEMPLATE RUNS, while the corridor is still BLDG_CORRIDOR — which
// is the only time the far side of a wall can be told apart from a room's floor
  public static function frontWall(state: _CorpState, room: _Room, liftX: Int, liftY: Int,
      near: Int): Array<_Spot>
    {
      var cells = state.area.getCells();
      var best = [];
      var bestD = near + 1;
      for (dir in [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT])
        {
          var d = deltaMap[dir];
          var horiz = (d.y != 0);
          var run = [];
          var dist = bestD;
          for (i in 0...(horiz ? room.x2 - room.x1 + 1 : room.y2 - room.y1 + 1))
            {
              var x = (horiz ? room.x1 + i : (d.x < 0 ? room.x1 - 1 : room.x2 + 1));
              var y = (horiz ? (d.y < 0 ? room.y1 - 1 : room.y2 + 1) : room.y1 + i);
              if (cells[x + d.x][y + d.y] != BLDG_CORRIDOR)
                {
                  run = null;
                  break;
                }
              var cd = Std.int(Math.abs(x - liftX) + Math.abs(y - liftY));
              if (cd < dist)
                dist = cd;
              run.push({
                x: x,
                y: y,
                dir: dir,
                dir90: (horiz ? DIR_RIGHT : DIR_DOWN),
              });
            }
          if (run != null &&
              dist < bestD)
            {
              best = run;
              bestD = dist;
            }
        }
      return best;
    }

// the doors that stand in a room's front wall
  public static function frontDoors(state: _CorpState, front: Array<_Spot>): Array<_Door>
    {
      return [for (d in state.doors) for (s in front) if (d.x == s.x && d.y == s.y) d];
    }

// can this front be shut — every door in it closed — with the corridor still reaching everything
// it reaches now? The counter takes the whole wall, so a room whose only way in is that wall, or
// one with a room behind it that is only reached THROUGH it, would be walled in by its own desk
  public static function frontShuts(state: _CorpState, front: Array<_Spot>): Bool
    {
      var base = reached(state, -1);
      var seen = reached(state, -1, frontDoors(state, front));
      for (id in base.keys())
        if (!seen.exists(id))
          return false;
      return true;
    }

// which of these candidate cells have a CORRIDOR on their far side
  static function corridorSpots(cells: Array<Array<Int>>, list: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in list)
        {
          var delta = deltaMap[s.dir];
          if (cells[s.x + delta.x][s.y + delta.y] != BLDG_CORRIDOR)
            continue;
          out.push(s);
        }
      return out;
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

      // the four wall midpoints first, then EVERY cell of the ring, most central first — the
      // second half of what game.AreaGenerator.getRoomWallSpots' header says the four-cell limit
      // costs: "makeDoorToCorridor report[s] failure while some other cell of the same wall faces
      // the corridor it was looking for". Invisible at 8 x 8 rooms and 20% of towers at 5 x 5
      var spots = corridorSpots(cells, getRoomDoorSpots(room));
      if (spots.length == 0)
        spots = corridorSpots(cells, getRoomWallSpots(room));
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

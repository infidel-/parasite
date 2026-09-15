// making sure you can get in
//
// every door the compound cuts and every check that the cutting worked. Two passes that look alike
// and are not, and the difference is the reason this file exists as one module:
//
//   * fixDoors reasons about the ROOM GRAPH — which rooms have doors to which — and runs inside
//     generateBuilding, while the building is still TEMP tiles.
//   * connectRooms reasons about the TILE GRID, and runs at the very END of generation, after
//     finalizeTiles, because the graph is the optimistic one. See its own comment.
//
// docs/area-gen.md § "Sealed rooms" has the measurements.

package gen.facility;

import Const;
import game.AreaGenerator;
import game.AreaGenerator.*;
import gen.facility.FacilityTemp.*;

class FacilityConnect
{
// make inner wall doors
  public static function makeDoors(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomID = state.nextRoomID - 1;
      var doors = [];
      var rooms = [];
      for (y in (by + 1)...(by + bh))
        for (x in (bx + 1)...(bx + bw))
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and door direction
            var room = getRoom(cells, x, y);
            roomID++;
            room.id = roomID;
            rooms.push(room);

            // the four wall midpoints first, so a door lands in the middle of its wall wherever one
            // legally can and the compound looks exactly as it always has
            var spots = doorSpots(cells, getRoomDoorSpots(room));
            var spot = null;
            if (spots.length > 0)
              spot = spots[area.random(spots.length)];
            else
              {
                // and every other cell of the wall ring when none of the four works, most central
                // first. WITHOUT THIS the room simply never gets a door — it used to trace "bug, no
                // door spots in room" and carry on, leaving a room nothing can walk into
                spots = doorSpots(cells, getRoomWallSpots(room));
                if (spots.length == 0)
                  {
                    trace('bug, no door spots anywhere on the wall of room ' + room);
                    continue;
                  }
                spot = spots[0];
              }
            cells[spot.x][spot.y] = TEMP_BUILDING_INNER_DOOR;
            doors.push({
              x: spot.x,
              y: spot.y,
              dir: spot.dir,
              roomID1: roomID,
              roomID2: -1, // unknown yet
              skip: false,
            });
            markRoom(cells, room, roomID);
          }
      state.doors = doors;
      state.rooms = rooms;
      state.nextRoomID = roomID + 1;
    }

// which of these candidate spots a door may actually be cut into: an inner wall, and not a cell with
// walls on three sides of it (the "triangle", where an opening would face into masonry)
  static function doorSpots(cells: Array<Array<Int>>, cand: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in cand)
        {
          if (cells[s.x][s.y] != TEMP_BUILDING_INNER_WALL)
            continue;
          var cnt = 0;
          for (i in 0...Const.dir4x.length)
            {
              var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
              if (t == TEMP_BUILDING_INNER_WALL ||
                  t == TEMP_BUILDING_WALL)
                cnt++;
            }
          if (cnt > 2)
            continue;
          out.push(s);
        }
      return out;
    }

// remove double doors into the same rooms
// fix room clusters that have no exit into any corridors
  public static function fixDoors(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var doors = state.doors;
      // find rooms that the doors lead to
      var area = state.area;
      var cells = area.getCells();
      for (door in doors)
        {
          var delta = deltaMap[door.dir];
          door.roomID2 =
            cells[door.x + delta.x][door.y + delta.y];
          if (door.roomID2 < TEMP_BUILDING_ROOM_ID_START)
            door.roomID2 = 0;
        }

      // remove doors between same rooms
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
          cells[door.x][door.y] = TEMP_BUILDING_INNER_WALL;
          doors.remove(door);
        }

      // group the rooms into everything-can-reach-everything sets
      var clusters = roomClusters(state);

      // every room that can already be walked to, which is whichever set ended up holding 0
      var reachable = new Map<Int, Bool>();
      var pending = [];
      for (c in clusters)
        {
          if (Lambda.has(c, 0))
            {
              for (id in c)
                reachable.set(id, true);
            }
          else pending.push(c);
        }

      // and let every other set in.
      //
      // REPEATED UNTIL NOTHING MOVES, because connecting one pocket can be what makes the next one
      // connectable: a pocket buried behind another pocket has no reachable neighbour on the first
      // pass and a perfectly good one on the second. A pass that changes nothing means the rest
      // genuinely cannot be reached and the loop stops rather than spinning
      var progress = true;
      while (pending.length > 0 &&
             progress)
        {
          progress = false;
          for (c in pending.copy())
            {
              var done = false;
              // a corridor is the good outcome: it puts the rooms on the building's circulation
              // rather than making somebody walk through a laboratory to reach them
              for (roomID in c)
                if (makeDoorToCorridor(state, roomID))
                  {
                    done = true;
                    break;
                  }
              // and failing that, any room that can already be reached. a pocket of rooms in the
              // middle of a structure has no corridor wall at all — that is what being in the
              // middle means — so without this it stays sealed however hard the corridor pass looks
              if (!done)
                for (roomID in c)
                  if (makeDoorToRoom(state, roomID, reachable))
                    {
                      done = true;
                      break;
                    }
              if (!done)
                continue;
              for (id in c)
                reachable.set(id, true);
              pending.remove(c);
              progress = true;
            }
        }
      for (c in pending)
        trace('bug, cluster ' + c + ' cannot reach a corridor or any reachable room');
    }

// group this structure's rooms into sets that can reach each other, with room id 0 standing for
// "a corridor, or outdoors".
//
// REPLACES A SINGLE-PASS GROUPING THAT COULD NOT MERGE. The old loop walked the doors once and, for
// each, looked for an existing cluster already holding one of its two rooms — so if rooms A-B had
// formed one cluster and C-D another, a later door joining B to C pushed C into A's cluster and left
// D sitting in the second one, still recorded as a separate group. Which group a room ended up in,
// and whether that group appeared to contain a corridor at all, came down to the order the doors
// happened to be created in.
//
// that is what left 8% of compounds with a room nothing could walk into: a set of rooms joined only
// to each other got merged into a record that DID contain 0, so the "no corridor exit" branch below
// skipped it and never cut the door that would have let anyone in. The rooms had doors, the doors
// were walkable, and every one of them led to another room in the same sealed pocket.
//
// union-find, so merging is the operation it is built on rather than the case it misses
  static function roomClusters(state: _FacilityState): Array<Array<Int>>
    {
      var parent = new Map<Int, Int>();
      // 0 is a node like any other: whichever set ends up holding it is the reachable one
      parent.set(0, 0);
      for (r in state.rooms)
        parent.set(r.id, r.id);
      for (d in state.doors)
        {
          if (!parent.exists(d.roomID1) ||
              !parent.exists(d.roomID2))
            continue;
          unite(parent, d.roomID1, d.roomID2);
        }

      var byRoot = new Map<Int, Array<Int>>();
      // 0 goes in first so the set holding it always carries the marker the caller tests for
      var zero = root(parent, 0);
      byRoot.set(zero, [0]);
      for (r in state.rooms)
        {
          var k = root(parent, r.id);
          if (!byRoot.exists(k))
            byRoot.set(k, []);
          byRoot.get(k).push(r.id);
        }
      return [for (k in byRoot.keys()) byRoot.get(k)];
    }

// the representative of a node's set, flattening the path it walked on the way
  static function root(parent: Map<Int, Int>, a: Int): Int
    {
      while (parent.get(a) != a)
        {
          parent.set(a, parent.get(parent.get(a)));
          a = parent.get(a);
        }
      return a;
    }

// put two nodes in the same set
  static function unite(parent: Map<Int, Int>, a: Int, b: Int)
    {
      var ra = root(parent, a);
      var rb = root(parent, b);
      if (ra != rb)
        parent.set(ra, rb);
    }

// cut a door from this room into whichever neighbouring room can already be walked to.
//
// the last resort for a pocket of rooms with no corridor wall between them and the rest of the
// building. A door into a neighbour is a worse answer than a door onto a corridor — it means
// reaching these rooms by walking through another one — but it is the difference between a room
// that is awkward to get to and a room that cannot be entered at all.
//
// the far side of a wall cell is read straight off the grid: makeDoors has already stamped every
// room's id into its own cells, so the neighbour identifies itself
  static function makeDoorToRoom(state: _FacilityState, roomID: Int,
      reachable: Map<Int, Bool>): Bool
    {
      var cells = state.area.getCells();
      var room = roomByID(state, roomID);
      if (room == null)
        return false;
      // wall midpoints first, then the rest of the ring, exactly as the corridor pass does
      var hit = pickRoomSpot(cells, doorSpots(cells, getRoomDoorSpots(room)), reachable);
      if (hit == null)
        hit = pickRoomSpot(cells, doorSpots(cells, getRoomWallSpots(room)), reachable);
      if (hit == null)
        return false;
      cells[hit.spot.x][hit.spot.y] = TEMP_BUILDING_INNER_DOOR;
      state.doors.push({
        x: hit.spot.x,
        y: hit.spot.y,
        dir: hit.spot.dir,
        roomID1: roomID,
        roomID2: hit.target,
        skip: false,
      });
      return true;
    }

// the first of these spots whose far side is a room that can already be reached, with that room's id
  static function pickRoomSpot(cells: Array<Array<Int>>, cand: Array<_Spot>,
      reachable: Map<Int, Bool>): { spot: _Spot, target: Int }
    {
      for (s in cand)
        {
          var delta = deltaMap[s.dir];
          var t = cells[s.x + delta.x][s.y + delta.y];
          if (t < TEMP_BUILDING_ROOM_ID_START ||
              !reachable.exists(t))
            continue;
          return {
            spot: s,
            target: t,
          };
        }
      return null;
    }

// this structure's room with that id, or null
  public static function roomByID(state: _FacilityState, roomID: Int): _Room
    {
      for (r in state.rooms)
        if (r.id == roomID)
          return r;
      return null;
    }

// which of these candidate spots open straight onto a corridor
  static function corridorSpots(cells: Array<Array<Int>>, cand: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in cand)
        {
          var delta = deltaMap[s.dir];
          if (cells[s.x + delta.x][s.y + delta.y] == TEMP_BUILDING_CORRIDOR)
            out.push(s);
        }
      return out;
    }

// find a wall adjacent to a corridor and make a hole in it
  static function makeDoorToCorridor(state: _FacilityState, roomID: Int): Bool
    {
      // find room
      var area = state.area;
      var cells = area.getCells();
      var room = null;
      for (r in state.rooms)
        if (r.id == roomID)
          {
            room = r;
            break;
          }

      // get door spots and check which will go into the corridor. the four wall midpoints first,
      // then the whole wall ring most-central-first — a room can easily have a corridor along one
      // wall and a midpoint that is not the cell facing it, which used to come back as "this room
      // cannot reach a corridor" and strand its whole cluster
      var spots = corridorSpots(cells, getRoomDoorSpots(room));
      if (spots.length == 0)
        spots = corridorSpots(cells, getRoomWallSpots(room));
      if (spots.length == 0)
        return false;
      var spot = spots[0];
      cells[spot.x][spot.y] = TEMP_BUILDING_INNER_DOOR;
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

// get all doors that lead into this room
  public static function getRoomDoors(state: _FacilityState, room: _Room): Array<_Door>
    {
      var doors = [];
      for (door in state.doors)
        if (door.roomID1 == room.id ||
            door.roomID2 == room.id)
          doors.push(door);
      return doors;
    }

// --- the grid half, run once at the end of generation ---

// cut a door into any room that cannot be reached on foot.
//
// WHY THIS IS A SEPARATE PASS AT THE VERY END, rather than more logic inside fixDoors: fixDoors
// reasons about the ROOM GRAPH — which rooms have doors to which — and reachability is a property of
// the TILE GRID. The two disagree, and the graph is the optimistic one. A room can hold a door that
// fixDoors counts as a connection while the cells behind it are furniture, a partition, or another
// room that is itself sealed; and furniture is not even placed until after fixDoors has run, so at
// the point the graph is checked half the obstacles do not exist yet.
//
// so this asks the only question that matters, on the finished grid, the same way
// game.AreaGame.isWalkable will: flood the walkable cells from outside, and cut a door into whatever
// the flood did not reach. Measured before it existed: 8% of compounds carried at least one room
// that rendered perfectly and could not be entered, with clues, guards and mission anchors all able
// to spawn inside it.
  public static function connectRooms(state: _FacilityState)
    {
      // bounded rather than `while (true)`: each round opens at least one room or stops, so the
      // room count is the ceiling, and a cap means a bug here cannot hang generation
      for (round in 0...state.allRooms.length + 1)
        {
          var seen = floodWalkable(state);
          var stuck = [for (r in state.allRooms) if (!roomReached(r, seen)) r];
          if (stuck.length == 0)
            return;
          var opened = false;
          for (r in stuck)
            {
              // a wall that does not duplicate an existing door first. The room being sealed means
              // any door it already has is unusable, so a second one between the same pair would be
              // correct — but scenario.AlienMissionCommon locks a room by taking the FIRST door it
              // finds for it and stopping, so a duplicate pair leaves the other way in unlocked.
              //
              // AND THAT IS WHY THE DUPLICATE IS NOW THE LAST OF THE THREE AND NOT THE SECOND.
              // Taking one fitting away (clearWayToReached) is invisible — a room comes back with one
              // less cabinet in it — where a duplicate pair is a mission that silently locks nothing,
              // and gen.GenCheck.doorsSane has always rejected it. The branch simply never fired in
              // 4000 seeds until RoomBlock.glazeWall's `noTable` off-by-one was fixed and the extra
              // bench run moved enough furniture to seal a room the other way; seed 131 then reported
              // exactly the pair the check was written for. The duplicate stays as the third
              // fallback: a room nothing can enter at all is worse than either
              if (cutDoorToReached(state, r, seen, false) ||
                  clearWayToReached(state, r, seen) ||
                  cutDoorToReached(state, r, seen, true))
                opened = true;
            }
          // nothing could be opened this round, so nothing will be next round either
          if (!opened)
            {
              trace('connectRooms(): ' + stuck.length + ' room(s) still sealed, first is ' +
                stuck[0].x1 + ',' + stuck[0].y1 + '..' + stuck[0].x2 + ',' + stuck[0].y2);
              return;
            }
        }
    }

// every walkable cell reachable from outside the area, flooded from the rim. the road and its
// pavement span the full width, so whichever edge they landed on seeds the fill
  static function floodWalkable(state: _FacilityState): Array<Array<Bool>>
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      var seen = [for (x in 0...ctx.width) [for (y in 0...ctx.height) false]];
      var stack = [];
      inline function open(x: Int, y: Int)
        {
          if (x < 0 ||
              y < 0 ||
              x >= ctx.width ||
              y >= ctx.height ||
              seen[x][y])
            return;
          var t = cells[x][y];
          if (t < 0 ||
              t >= walk.length ||
              walk[t] == 0)
            return;
          seen[x][y] = true;
          stack.push({ x: x, y: y });
        }
      for (x in 0...ctx.width)
        {
          open(x, 0);
          open(x, ctx.height - 1);
        }
      for (y in 0...ctx.height)
        {
          open(0, y);
          open(ctx.width - 1, y);
        }
      while (stack.length > 0)
        {
          var p = stack.pop();
          for (i in 0...Const.dir4x.length)
            open(p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
        }
      return seen;
    }

// did the flood reach any cell of this room? any one will do — a room's floor is a single rect, and
// the furniture standing in it cannot cut that rect in two without also blocking the door
  static function roomReached(room: _Room, seen: Array<Array<Bool>>): Bool
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          if (seen[x][y])
            return true;
      return false;
    }

// open one wall cell of this room onto somewhere the flood already got to.
//
// candidates come centre-of-wall first, and an INDOOR neighbour is taken over an outdoor one in the
// same position — a door onto the corridor is what a room wants, and a hole cut straight through the
// compound's outside wall is a last resort rather than a choice
  static function cutDoorToReached(state: _FacilityState, room: _Room,
      seen: Array<Array<Bool>>, allowDuplicate: Bool): Bool
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      var best = null;
      var bestIndoor = false;
      for (s in getRoomWallSpots(room))
        {
          // the cell being opened has to be masonry: everything else is either already a way in or
          // something that must not be cut through
          if (cells[s.x][s.y] != Const.TILE_BUILDING)
            continue;
          var d = deltaMap[s.dir];
          var fx = s.x + d.x;
          var fy = s.y + d.y;
          if (fx < 0 ||
              fy < 0 ||
              fx >= ctx.width ||
              fy >= ctx.height)
            continue;
          // the far side must be somewhere you can already stand...
          var ft = cells[fx][fy];
          if (ft < 0 ||
              ft >= walk.length ||
              walk[ft] == 0 ||
              !seen[fx][fy])
            continue;
          // ...and the room side must be floor, or the new door opens into a cabinet
          var nt = cells[s.x - d.x][s.y - d.y];
          if (nt < 0 ||
              nt >= walk.length ||
              walk[nt] == 0)
            continue;
          // would this repeat a door the room already has? see the caller for why that matters.
          //
          // AND NOT INTO A WASHROOM, which is the same `allowDuplicate` escalation and the same kind
          // of reason: gen.facility.FacilityRooms picks the washroom for having exactly one door
          // onto a corridor and FacilityToilet lays the whole T against that one wall, so a door cut
          // in here at the end of generation seals half the room behind the partition. Measured at 4
          // seeds in 20000 before this. It is dropped on the last pass, where the alternative is a
          // room nothing can walk into
          if (!allowDuplicate)
            {
              var far = roomAtCell(state, fx, fy);
              if (hasDoorBetween(state, room.id, far) ||
                  isRole(state, far, ROLE_TOILET))
                continue;
            }
          // every indoor floor id sits at or above the chem-lab band; the road, pavement, alley and
          // grass the compound is built on are all well below it
          var indoor = (ft >= Const.OFFSET_CHEM_LAB);
          if (best != null &&
              (bestIndoor || !indoor))
            continue;
          best = s;
          bestIndoor = indoor;
          // nothing beats an indoor neighbour at the middle of the first wall that offers one
          if (indoor)
            break;
        }
      if (best == null)
        return false;

      cells[best.x][best.y] = Const.TILE_FLOOR_LINO;
      var priv = opensOnPrivateRoom(cells, best.x, best.y);
      ctx.addDoor(best.x, best.y,
        (priv ? Const.FRAME_DOOR_PRIVATE : Const.FRAME_DOOR_CABINET),
        (priv ? Const.FRAME_DOOR_PRIVATE_OPEN : Const.FRAME_DOOR_CABINET_OPEN));
      var d = deltaMap[best.dir];
      state.allDoors.push({
        x: best.x,
        y: best.y,
        dir: best.dir,
        roomID1: room.id,
        roomID2: roomAtCell(state, best.x + d.x, best.y + d.y),
        skip: false,
      });
      return true;
    }

// LAST RESORT: take a piece of furniture away rather than leave a room sealed.
//
// cutDoorToReached needs three things at once — masonry to cut, a reached cell on the far side, and
// a cell you can STAND ON on the room side — and it is the third that runs out. A room's perimeter
// is where all of its furniture goes, so a room can be ringed by its own fittings with a perfectly
// good corridor on the other side of every wall, and there is then nowhere to put a door however
// many rounds the loop runs.
//
// WHY THIS IS ALLOWED TO DELETE SOMETHING, when nothing else in generation does: the alternative is
// what the pass exists to prevent. A compound with a room that renders perfectly and cannot be
// entered still spawns clues, guards and mission anchors inside it — so one fitting fewer is not a
// close call. It is rare enough to stay a last resort: measured at 4 seeds in 20000 with the room
// zones in, against 0 in 10000 before them, and the zones' own lane rule (gen.blocks.RoomBlock
// .standing) is what took it down to that.
  static function clearWayToReached(state: _FacilityState, room: _Room,
      seen: Array<Array<Bool>>): Bool
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      for (s in getRoomWallSpots(room))
        {
          var d = deltaMap[s.dir];
          var fx = s.x + d.x;
          var fy = s.y + d.y;
          if (fx < 0 ||
              fy < 0 ||
              fx >= ctx.width ||
              fy >= ctx.height ||
              !seen[fx][fy])
            continue;
          // the wall itself has to be something a door can be in or already is
          if (cells[s.x][s.y] != Const.TILE_BUILDING &&
              cells[s.x][s.y] != Const.TILE_FLOOR_LINO)
            continue;
          // and the room side has to be a cell that is blocked ONLY by something standing on it —
          // the unwalkable twin of a floor is exactly one tileset row above the walkable one, so
          // undoing it is the same arithmetic FacilityRooms.paintRoomFloor did
          var nx = s.x - d.x;
          var ny = s.y - d.y;
          var nt = cells[nx][ny];
          if (nt < 0 ||
              nt >= walk.length ||
              walk[nt] == 1 ||
              !ctx.hasObjectAt(nx, ny))
            continue;
          var below = nt - UNWALKABLE_TILE_OFFSET;
          if (below < Const.OFFSET_CHEM_LAB ||
              below >= walk.length ||
              walk[below] == 0)
            continue;
          for (o in ctx.getObjectsAt(nx, ny))
            ctx.removeObject(o);
          cells[nx][ny] = below;
          return true;
        }
      return false;
    }

// is there already a door recorded between these two rooms?
  static function hasDoorBetween(state: _FacilityState, a: Int, b: Int): Bool
    {
      for (d in state.allDoors)
        if ((d.roomID1 == a && d.roomID2 == b) ||
            (d.roomID1 == b && d.roomID2 == a))
          return true;
      return false;
    }

// does the room with this id carry this role? over allRooms, like roomAtCell below and unlike
// roomByID, which holds only the building being generated and answers null at the end of generation
  static function isRole(state: _FacilityState, roomID: Int, role: String): Bool
    {
      for (r in state.allRooms)
        if (r.id == roomID)
          return (r.role == role);
      return false;
    }

// which recorded room holds this cell, or 0 for a corridor or the outdoors. by rect and not by the
// grid marks: those are gone by the time this runs, finalizeTiles having written real tiles over them
  static function roomAtCell(state: _FacilityState, x: Int, y: Int): Int
    {
      for (r in state.allRooms)
        if (x >= r.x1 &&
            x <= r.x2 &&
            y >= r.y1 &&
            y <= r.y2)
          return r.id;
      return 0;
    }
}

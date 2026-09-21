// making sure you can get in, on a corp tower floor
//
// the TILE-GRID half of connectivity, run once at the very end of generation. The ROOM-GRAPH half
// is gen.corp.CorpBuilding.fixDoors, and the two disagree on purpose: the graph says which rooms
// have doors to which, reachability is a property of the cells, and the graph is the optimistic
// one. A room can hold a door the graph counts while the cells behind it are a cubicle spine, a
// rack row or a filing cabinet — and none of that furniture exists yet when fixDoors runs.
//
// THE FLOOD STARTS AT THE LIFT and not at the area rim, which is the one structural difference
// from gen.facility.FacilityConnect.connectRooms. A compound is entered over its kerb from a road
// that spans the whole grid; the 20th floor of a tower is entered out of the lift car and by
// nothing else, with unwalkable void on every side of the plate. Flooding from the rim here
// reaches exactly zero cells and reports every room on the floor as sealed.
//
// measured before this pass existed: 190 of 1000 corp floors carried at least one room that
// rendered perfectly and could not be walked into.

package gen.corp;

import Const;
import game.AreaGenerator.*;
import gen.corp.CorpTemp.*;

class CorpConnect
{
// can a doorway be cut through this wall cell? MASONRY OR AN INNER GLASS PARTITION, and leaving
// the glass out is what kept 33 of 1000 floors sealed on the first build of this pass: a corp room
// is walled in curtain wall and office glazing as often as in blockwork, so a test for
// TILE_BUILDING alone skips most of the wall ring and reports "nothing to cut" on a room with a
// corridor down one whole side of it.
//
// THE OUTER GLAZING IS IN HERE TOO and it cannot put a door into the void: the far side of a cut
// has to be a cell the flood already reached, and there is nothing walkable outside the tower at
// all. It has to be in, because CorpBuilding.makeWindows picks outer-vs-inner glass off the cell
// BEYOND the wall corner it starts a run from, so an interior partition facing a corridor can
// legitimately come out wearing the curtain-wall art — which is the last 1 floor in 1000 that
// stayed sealed with only the inner ids listed
  static inline function cuttable(t: Int): Bool
    {
      return t == Const.TILE_BUILDING ||
        (t >= Const.TILE_CORP_WINDOW1 && t <= Const.TILE_CORP_WINDOWV3) ||
        (t >= Const.TILE_CORP_INNER_WINDOW1 && t <= Const.TILE_CORP_INNER_WINDOWV3);
    }

// cut a door into any room the lift cannot reach on foot
  public static function connectRooms(state: _CorpState)
    {
      // bounded rather than `while (true)`: each round opens at least one room or stops, so the
      // room count is the ceiling and a bug here cannot hang generation
      for (round in 0...state.rooms.length + 1)
        {
          var seen = floodWalkable(state);
          var stuck = [for (r in state.rooms) if (!roomReached(r, seen)) r];
          if (stuck.length == 0)
            return;
          var opened = false;
          for (r in stuck)
            if (cutDoorToReached(state, r, seen, false) ||
                clearWayToReached(state, r, seen) ||
                cutDoorToReached(state, r, seen, true))
              opened = true;
          if (!opened)
            for (r in stuck)
              if (carveToReached(state, r, seen))
                opened = true;
          if (!opened)
            {
              report(stuck, 'nothing left to open');
              return;
            }
        }
      // and the other way out of the loop, which used to be silent: every round DID open
      // something and the room is still sealed, i.e. the repair is going round in circles
      var seen = floodWalkable(state);
      var stuck = [for (r in state.rooms) if (!roomReached(r, seen)) r];
      if (stuck.length > 0)
        report(stuck, 'out of rounds');
    }

// say which rooms are still sealed and why the loop stopped trying
  static function report(stuck: Array<_Room>, why: String)
    {
      trace('CorpConnect: ' + stuck.length + ' room(s) still sealed (' + why + '), first is ' +
        stuck[0].x1 + ',' + stuck[0].y1 + '..' + stuck[0].x2 + ',' + stuck[0].y2);
    }

// every walkable cell reachable from the lift car
  static function floodWalkable(state: _CorpState): Array<Array<Bool>>
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
      for (s in ctx.spawns)
        if (s.type == 'elevator')
          open(s.x, s.y);
      while (stack.length > 0)
        {
          var p = stack.pop();
          for (i in 0...Const.dir4x.length)
            open(p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
        }
      return seen;
    }

// did the flood reach any cell of this room? any one will do — a room's floor is a single rect and
// its furniture cannot cut that rect in two without also blocking the door
  static function roomReached(room: _Room, seen: Array<Array<Bool>>): Bool
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          if (seen[x][y])
            return true;
      return false;
    }

// open one wall cell of this room onto somewhere the flood already got to
  static function cutDoorToReached(state: _CorpState, room: _Room,
      seen: Array<Array<Bool>>, allowDuplicate: Bool): Bool
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      for (s in getRoomWallSpots(room))
        {
          // the cell being opened has to be EMPTY masonry: a vent is an object standing on a
          // TILE_BUILDING cell, and cutting a doorway through the grille puts two spawns in it
          if (!cuttable(cells[s.x][s.y]) ||
              ctx.hasObjectAt(s.x, s.y))
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
          // a second door between the same pair of ROOMS is what gen.GenCheck.doorsSane rejects
          // and what a mission's "lock the first door of this room" silently misses, so it is the
          // last of the three fallbacks rather than the first.
          //
          // ROOM ID 0 IS EXEMPT AND HAS TO BE: it is the sentinel for "a corridor, or the void
          // outside", not a room, and doorsSane says in as many words that several doors onto
          // corridors are intended. Without the exemption a room that already holds one BLOCKED
          // corridor door can never be given a working one — cut(false) refuses it as a duplicate
          // forever, clearWayToReached succeeds every round on the room's own furniture, and the
          // `||` chain therefore never reaches the allowDuplicate pass at all. That is one sealed
          // room in 1000 and eight pieces of furniture deleted trying to reach it
          if (!allowDuplicate)
            {
              var far = roomAtCell(state, fx, fy);
              if (far != 0 &&
                  hasDoorBetween(state, room.id, far))
                continue;
            }

          var far = roomAtCell(state, fx, fy);
          // and on the duplicate pass, RETIRE the door that is already there. Reaching here means
          // the pair is joined by a door the player cannot use — something is standing in front of
          // it, or the room behind it is itself sealed — so the old record is not a live connection
          // and `skip` is exactly what that flag means to gen.corp.CorpBuilding.fixDoors. Leaving
          // both live is what gen.GenCheck.doorsSane rejects, and it rejects it for a real reason:
          // scenario.AlienMissionCommon locks a room by taking the FIRST door it finds and
          // stopping, so a live pair is a mission that silently locks nothing. Measured at 1 floor
          // in 3000
          if (allowDuplicate &&
              far != 0)
            for (d in state.doors)
              if ((d.roomID1 == room.id && d.roomID2 == far) ||
                  (d.roomID1 == far && d.roomID2 == room.id))
                d.skip = true;

          cells[s.x][s.y] = Const.TILE_FLOOR_CARPET;
          ctx.addDoor(s.x, s.y, Const.FRAME_DOOR_CORP, Const.FRAME_DOOR_CORP_OPEN);
          state.doors.push({
            x: s.x,
            y: s.y,
            dir: s.dir,
            roomID1: room.id,
            roomID2: far,
            skip: false,
          });
          return true;
        }
      return false;
    }

// what a blocking furniture cell becomes when it is taken away, or -1 when it cannot be.
//
// TWO BANDS AND THEY UNDO DIFFERENTLY. A wall dressing or a fixture is the room's own floor plus
// UNWALKABLE_TILE_OFFSET, exactly one tileset row below it, so subtracting the offset gives the
// floor back. A TABLE is not: `Const.isCorpTableTile` ids sit in an unrelated band (rows 8-11) and
// "one row up" means nothing there, which is what the row-12 test originally guarded against. But
// a boardroom slab or a desk run can still be the one thing between a sealed room and the
// corridor, so it comes away too — to plain carpet, the tile this pass already writes into the
// doorways it cuts. Measured at the halved room size: 26 towers in 400 still sealed with only the
// row-12 band clearable, 5 with the tables in
  static function clearedTo(t: Int): Int
    {
      var walk = tiles.Default.TILE_WALKABLE;
      if (t < 0 ||
          t >= walk.length ||
          walk[t] == 1)
        return -1;
      var below = t - UNWALKABLE_TILE_OFFSET;
      if (below >= Const.OFFSET_ROW12 &&
          below < Const.OFFSET_ROW13 &&
          walk[below] == 1)
        return below;
      if (Const.isCorpTableTile(t))
        return Const.TILE_FLOOR_CARPET;
      return -1;
    }

// LAST RESORT: take one piece of furniture away rather than leave a room sealed.
//
// cutDoorToReached needs three things at once — masonry to cut, a reached cell on the far side,
// and a cell you can STAND ON on the room side — and it is the third that runs out. A corp room's
// perimeter is where all of its wall furniture goes and a cubicle farm fills the middle too, so a
// room can be ringed by its own fittings with a perfectly good corridor beyond every wall.
//
// the twin of a corp floor is exactly one tileset row below it (OFFSET_ROW12 -> OFFSET_ROW13), so
// undoing a furniture cell is that arithmetic backwards. The row test is what keeps it off the
// TABLE tiles, whose ids are in an unrelated band and whose "one row up" means nothing
  static function clearWayToReached(state: _CorpState, room: _Room,
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
          if (!cuttable(cells[s.x][s.y]) &&
              cells[s.x][s.y] != Const.TILE_FLOOR_CARPET)
            continue;
          var nx = s.x - d.x;
          var ny = s.y - d.y;
          var below = clearedTo(cells[nx][ny]);
          if (below < 0)
            continue;
          for (o in ctx.getObjectsAt(nx, ny))
            ctx.removeObject(o);
          cells[nx][ny] = below;
          return true;
        }
      // AND THE BLOCKING CELL CAN BE ON THE OTHER SIDE OF THE WALL JUST AS EASILY.
      //
      // everything above needs `seen[far]`, and a cell is only seen if it is walkable — so a
      // neighbour room the lift DOES reach, whose edge column happens to carry a filing cabinet
      // exactly where this room's wall meets it, is invisible to all three passes. The room next
      // door is open, the wall is cuttable, and there is nothing to cut TO.
      //
      // Measured at the halved room size: whole corner clusters of one to four rooms reported
      // "nothing left to open" with a reached room on the far side of every one. Clearing the far
      // cell puts it back in the flood and the NEXT round cuts the door through it normally —
      // 76 sealed towers in 400 down to 26
      for (s in getRoomWallSpots(room))
        {
          var d = deltaMap[s.dir];
          var fx = s.x + d.x;
          var fy = s.y + d.y;
          if (fx < 0 ||
              fy < 0 ||
              fx >= ctx.width ||
              fy >= ctx.height)
            continue;
          if (!cuttable(cells[s.x][s.y]) &&
              cells[s.x][s.y] != Const.TILE_FLOOR_CARPET)
            continue;
          var below = clearedTo(cells[fx][fy]);
          if (below < 0)
            continue;
          // and it has to be the EDGE of somewhere already reached, or clearing it buys nothing.
          // Both alternatives were measured and neither moved the number: dropping the guard
          // entirely took 5 sealed towers to 6, and asking it of the far ROOM rather than of the
          // cell's four neighbours changed nothing at all — what is left after this is a cluster
          // with no reached boundary of any kind, which is a carve problem and not a repair one
          var touches = false;
          for (i in 0...Const.dir4x.length)
            {
              var tx = fx + Const.dir4x[i];
              var ty = fy + Const.dir4y[i];
              if (tx >= 0 && ty >= 0 && tx < ctx.width && ty < ctx.height && seen[tx][ty])
                touches = true;
            }
          if (!touches)
            continue;
          for (o in ctx.getObjectsAt(fx, fy))
            ctx.removeObject(o);
          cells[fx][fy] = below;
          return true;
        }
      return false;
    }

// THE CLOSER: cut a straight run from this room to the nearest cell the lift reaches, clearing
// whatever is on the way.
//
// the three passes above all need a REACHED cell on the far side of one wall, and what defeats
// them is a cluster of sealed rooms with no reached cell anywhere on its boundary — a block of
// the plate the corridor never entered. There is nothing one wall away to open onto, so this
// opens a route to whatever IS there.
//
// it is a breadth-first search over the PLATE ONLY, so a run can never be carved out through the
// curtain wall into the void, and it clears rather than chooses: every cell of the path that is
// not already walkable becomes plain carpet, and a doorway is recorded where the path crosses the
// room's own wall ring. Rare by construction and measured so — 4 towers in 3,000 after everything
// above, and it is the difference between the oracle being green and not
  static function carveToReached(state: _CorpState, room: _Room,
      seen: Array<Array<Bool>>): Bool
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      var x1 = state.px1;
      var y1 = state.py1;
      var x2 = state.px2;
      var y2 = state.py2;
      var from = [for (x in 0...ctx.width) [for (y in 0...ctx.height) -1]];
      var open = [];
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            from[x][y] = -2;
            open.push({ x: x, y: y });
          }
      var hit = null;
      var head = 0;
      while (head < open.length && hit == null)
        {
          var p = open[head++];
          for (i in 0...Const.dir4x.length)
            {
              var nx = p.x + Const.dir4x[i];
              var ny = p.y + Const.dir4y[i];
              if (nx < x1 || ny < y1 || nx > x2 || ny > y2 || from[nx][ny] != -1)
                continue;
              from[nx][ny] = p.y * ctx.width + p.x;
              if (seen[nx][ny])
                {
                  hit = { x: nx, y: ny };
                  break;
                }
              open.push({ x: nx, y: ny });
            }
        }
      if (hit == null)
        return false;
      // walk the path back, clearing everything that is not already floor
      var cx = hit.x;
      var cy = hit.y;
      while (from[cx][cy] != -2)
        {
          var t = cells[cx][cy];
          if (t < 0 || t >= walk.length || walk[t] == 0)
            {
              for (o in ctx.getObjectsAt(cx, cy))
                ctx.removeObject(o);
              // the cell where the run leaves the room's own ring is a DOORWAY and gets a leaf;
              // everywhere else is simply opened
              if (cx >= room.x1 - 1 && cx <= room.x2 + 1 &&
                  cy >= room.y1 - 1 && cy <= room.y2 + 1)
                ctx.addDoor(cx, cy, Const.FRAME_DOOR_CORP, Const.FRAME_DOOR_CORP_OPEN);
              cells[cx][cy] = Const.TILE_FLOOR_CARPET;
            }
          var prev = from[cx][cy];
          cx = prev % ctx.width;
          cy = Std.int(prev / ctx.width);
        }
      return true;
    }

// is there already a door recorded between these two rooms?
  static function hasDoorBetween(state: _CorpState, a: Int, b: Int): Bool
    {
      for (d in state.doors)
        if ((d.roomID1 == a && d.roomID2 == b) ||
            (d.roomID1 == b && d.roomID2 == a))
          return true;
      return false;
    }

// which recorded room holds this cell, or 0 for a corridor or the void outside. by rect and not by
// the grid marks: those are gone by the time this runs, finalizeTiles having written real tiles
// over them
  static function roomAtCell(state: _CorpState, x: Int, y: Int): Int
    {
      for (r in state.rooms)
        if (x >= r.x1 &&
            x <= r.x2 &&
            y >= r.y1 &&
            y <= r.y2)
          return r.id;
      return 0;
    }
}

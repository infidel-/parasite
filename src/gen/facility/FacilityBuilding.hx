// one lab building
//
// the wall ring, the main corridor and its branches, and the rooms cut off that corridor. What goes
// INSIDE a room once it exists is gen.blocks.RoomBlock, one level further down the tree. The pass
// ORDER in generateBuilding is load-bearing and is commented at each step.

package gen.facility;

import game.AreaGenerator;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.blocks.RoomBlock;
import gen.facility.FacilityTemp.*;

class FacilityBuilding
{
  // how many ROOM_SIZEs a room may run to on one axis before subdivideLargeRooms cuts it in two.
  //
  // 1.5 while a compound's buildings were hand-placed and LONG — the side building was 0.4 of the
  // area's width by nearly its whole height — because a long building's corridor throws off plenty
  // of narrow rooms by itself. The block tree hands out plots capped at splitProfile().maxSide and
  // bounded in aspect, so the buildings are squarer and their rooms came out 60 cells against the
  // 45 they used to average. This is the constant that puts them back
  static inline var SUBDIVIDE_OVER = 1.2;
  // the biggest room on both axes a military building knocks through into a neighbour
  public static inline var SMALL_ROOM = 4;

// generate a single building over its plot
  public static function generateBuilding(state: _FacilityState, node: _GenNode)
    {
      // draw outer walls and walkways
      var area = state.area;
      var cells = area.getCells();
      var bx = node.x1, by = node.y1;
      var bw = GenTree.width(node), bh = GenTree.height(node);
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 || y < 0 || x >= area.width || y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = TEMP_BUILDING_ROOM;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              {
                cells[x][y] = TEMP_WALKWAY;
                continue;
              }
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = TEMP_BUILDING_WALL;
          }

      // pick a wall for a front door
      var outerWalls = [
        { x1: bx, y1: by, x2: bx + bw - 1, y2: by, dir: DIR_DOWN }, // top
        { x1: bx, y1: by, x2: bx, y2: by + bh - 1, dir: DIR_RIGHT }, // left
        { x1: bx, y1: by + bh - 1, x2: bx + bw - 1,
          y2: by + bh - 1, dir: DIR_UP }, // bottom
        { x1: bx + bw - 1, y1: by, x2: bx + bw - 1, y2: by + bh - 1, dir: DIR_LEFT }, // right
      ];
      var frontWall = outerWalls[area.random(outerWalls.length)];

      // pick a main corridor starting spot
      var frontDoor = null;
      if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
        frontDoor = {
          x: Std.int((frontWall.x2 - frontWall.x1) / 2) + frontWall.x1,
          y: frontWall.y1,
        };
      else frontDoor = {
        x: frontWall.x1,
        y: Std.int((frontWall.y2 - frontWall.y1) / 2) + frontWall.y1,
      };

      // main doors and wall between them
      var corridorWidth = 3;
      drawChunk(cells, frontDoor.x, frontDoor.y, corridorWidth,
        frontWall.dir, TEMP_BUILDING_FRONT_DOOR);
      if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
        cells[frontDoor.x + 1][frontDoor.y] = TEMP_BUILDING_WALL;
      else cells[frontDoor.x][frontDoor.y + 1] = TEMP_BUILDING_WALL;

      // draw main corridor
      var len = 0, x = frontDoor.x, y = frontDoor.y;
      var delta = deltaMap[frontWall.dir];
      var sideCorridorCount1 = 0, sideCorridorCount2 = 0;
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (at(cells, x, y) < TEMP_BUILDING_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              // fix the hole :)
              drawChunk(cells, x, y, corridorWidth,
                frontWall.dir, TEMP_BUILDING_WALL);
              break;
            }
          drawChunk(cells, x, y, corridorWidth,
            frontWall.dir, TEMP_BUILDING_CORRIDOR);

          // check for side corridors
          sideCorridorCount1++;
          if (sideCorridorCount1 > ROOM_SIZE && area.random(100) > 70)
            {
              var dir = 0;
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_LEFT;
              else dir = DIR_UP;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(state, x, y, dir);
              sideCorridorCount1 = 0;
            }
          sideCorridorCount2++;
          if (sideCorridorCount2 > ROOM_SIZE && area.random(100) > 70)
            {
              var dir = 0;
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_RIGHT;
              else dir = DIR_DOWN;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(state, x, y, dir);
              sideCorridorCount2 = 0;
            }
        }

      // side door/window
      if (area.chance(50))
        {
          if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
            {
              cells[x][y] = TEMP_BUILDING_WINDOWH1;
              cells[x + 1][y] = TEMP_BUILDING_WINDOWH2;
              cells[x + 2][y] = TEMP_BUILDING_WINDOWH3;
            }
          else
            {
              cells[x][y] = TEMP_BUILDING_WINDOWV1;
              cells[x][y + 1] = TEMP_BUILDING_WINDOWV2;
              cells[x][y + 2] = TEMP_BUILDING_WINDOWV3;
            }
        }
      else
        {
          if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
            cells[x + 1][y] = TEMP_BUILDING_SIDE_DOOR;
          else cells[x][y + 1] = TEMP_BUILDING_SIDE_DOOR;
        }

      // draw inner walls
      for (y in by + 1...by + bh + 1)
        for (x in bx + 1...bx + bw + 1)
          if (cells[x][y] == TEMP_BUILDING_ROOM &&
              nextTo(cells, x, y, TEMP_BUILDING_CORRIDOR))
            cells[x][y] = TEMP_BUILDING_INNER_WALL;

      // sub-divide larger rooms
      for (i in 0...2)
        {
          subdivideLargeRooms(state, bx, by, bw, bh);
          replaceTiles(cells, bx, by, bw, bh,
            TEMP_BUILDING_ROOM_MARKED, TEMP_BUILDING_ROOM);
        }

      // a base has no use for a room 4x4 or smaller ("they can't contain anything useful")
      if (state.military)
        mergeSmallRooms(cells, bx, by, bw, bh);

      // make doors
      FacilityConnect.makeDoors(state, bx, by, bw, bh);

      // various door fixes
      FacilityConnect.fixDoors(state, bx, by, bw, bh);

      // hand each room its template. BEFORE the room level below, which is where the bench runs are
      // laid: a washroom must never get one, and a researcher's office wants desks and not
      // laboratory glassware
      FacilityRooms.assignRoomThemes(state);

      // the ROOM level of the tree. each room hangs off this building's node and divides itself into
      // the bays of worktop and slots of clutter that gen.blocks.RoomBlock fills.
      //
      // WALKED HERE AND NOT DEFERRED TO THE AREA WALK, which is the one thing the breadth-first
      // ordering cannot give: generateRoomContents two lines below needs the benches already
      // standing, because roomChemistryLab's island only takes a spot that is still bare floor. The
      // nodes stay attached all the same, so the finished tree is a record of the whole area — the
      // area walk reaches them again a level later and FacilityGen.fill has no case for them, which
      // is what makes that second visit a no-op
      for (room in state.rooms)
        {
          GenTree.build(RoomBlock.node(state, node, room),
            function(n) RoomBlock.fill(state, n));
          // and with the room's benches dealt, close up any pair that meets only at a corner, then
          // make sure a clue still has somewhere to land on what is left
          FacilityRooms.fixDiagonalTables(state, room);
          // and a STORE gets its floor walked: its whole floor is an array of racking (the
          // TAG_FLOOR block RoomBlock.glaze pushes), so it is the one room here that can wall a
          // corner of itself off — FacilityRooms.openPockets
          if (room.role == ROLE_STORAGE)
            FacilityRooms.openPockets(state, room);
          // a washroom has no worktop and neither has a STORE: both are furnished entirely by
          // their own zones, so there are no bench cells to keep clear and nothing for a clue to
          // land on in either of them
          if (room.role != ROLE_TOILET &&
              room.role != ROLE_STORAGE &&
              !state.military)
            FacilityRooms.clearTableSpots(state, room);
        }

      // work on individual rooms
      FacilityRooms.generateRoomContents(state);

      // fold this building into the area-wide lists. done LAST, because every pass above reads
      // state.rooms/doors and must only ever see this building's own
      for (r in state.rooms)
        state.allRooms.push(r);
      for (d in state.doors)
        state.allDoors.push(d);
    }

// sub-divide larger rooms
// if isFinal is true, mark with room ids
// if it is false, mark with TEMP_BUILDING_ROOM_MARKED
  static function subdivideLargeRooms(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var rooms = 0;
      for (y in by + 1...by + bh)
        for (x in bx + 1...bx + bw)
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and wall division direction
            var room = getRoom(cells, x, y);
            var dir = 0;
            if (room.w > ROOM_SIZE * SUBDIVIDE_OVER)
              dir = DIR_DOWN;
            if (room.h > ROOM_SIZE * SUBDIVIDE_OVER)
              dir = DIR_RIGHT;
            if (dir == 0)
              {
                markRoom(cells, room, TEMP_BUILDING_ROOM_MARKED);
                continue;
              }

            // find starting wall division spot
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
            else if (dir == DIR_RIGHT)
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
            var len = drawLine(cells, sx, sy, dir, TEMP_BUILDING_INNER_WALL);
            var newRoom = getRoom(cells, x, y);
            markRoom(cells, newRoom, TEMP_BUILDING_ROOM_MARKED);
            rooms++;
          }
    }

// rid a military building of every room that fits in SMALL_ROOM x SMALL_ROOM, the smallest first:
// knocked through into a neighbour that lines up with it, else opened onto a corridor as an alcove
// of it. Over again until none is left that can go either way
  static function mergeSmallRooms(cells: Array<Array<Int>>, bx: Int, by: Int, bw: Int, bh: Int)
    {
      var changed = true;
      while (changed)
        {
          var rooms = [];
          for (y in by + 1...by + bh)
            for (x in bx + 1...bx + bw)
              if (cells[x][y] == TEMP_BUILDING_ROOM)
                {
                  var r = getRoom(cells, x, y);
                  markRoom(cells, r, TEMP_BUILDING_ROOM_MARKED);
                  rooms.push(r);
                }
          replaceTiles(cells, bx, by, bw, bh, TEMP_BUILDING_ROOM_MARKED, TEMP_BUILDING_ROOM);
          rooms.sort(function(a, b) return a.w * a.h - b.w * b.h);
          changed = false;
          for (r in rooms)
            if (r.w <= SMALL_ROOM &&
                r.h <= SMALL_ROOM &&
                (knock(cells, r, rooms) || alcove(cells, r)))
              {
                changed = true;
                break;
              }
        }
    }

// knock a room through into the smallest neighbour across one inner wall that matches it edge to edge,
// so the two make one rectangle
  static function knock(cells: Array<Array<Int>>, r: _Room, rooms: Array<_Room>): Bool
    {
      var wall = null;
      var best = -1;
      for (n in rooms)
        {
          // the wall between as its first cell and step, when n lines up with r across it
          var rows = (n.y1 == r.y1 &&
            n.y2 == r.y2);
          var cols = (n.x1 == r.x1 &&
            n.x2 == r.x2);
          var line = (rows && n.x1 == r.x2 + 2 ? [ r.x2 + 1, r.y1, 0, 1 ] :
            rows && n.x2 == r.x1 - 2 ? [ r.x1 - 1, r.y1, 0, 1 ] :
            cols && n.y1 == r.y2 + 2 ? [ r.x1, r.y2 + 1, 1, 0 ] :
            cols && n.y2 == r.y1 - 2 ? [ r.x1, r.y1 - 1, 1, 0 ] : null);
          if (line == null ||
              (best >= 0 && n.w * n.h >= best))
            continue;
          var len = (line[2] == 1 ? r.w : r.h);
          var inner = true;
          for (i in 0...len)
            if (cells[line[0] + line[2] * i][line[1] + line[3] * i] != TEMP_BUILDING_INNER_WALL)
              inner = false;
          if (!inner)
            continue;
          best = n.w * n.h;
          wall = [ line[0], line[1], line[2], line[3], len ];
        }
      if (wall == null)
        return false;
      for (i in 0...wall[4])
        cells[wall[0] + wall[2] * i][wall[1] + wall[3] * i] = TEMP_BUILDING_ROOM;
      return true;
    }

// open a room onto a corridor that runs the whole length of one of its walls, wall and floor turned
// corridor: a room walled in by corridors on every side has no neighbour to take in (7 seeds in 2000)
  static function alcove(cells: Array<Array<Int>>, r: _Room): Bool
    {
      // each wall as its first cell, the step along it and the step out across it
      var sides = [
        [ r.x1, r.y1 - 1, 1, 0, 0, -1 ],
        [ r.x1, r.y2 + 1, 1, 0, 0, 1 ],
        [ r.x1 - 1, r.y1, 0, 1, -1, 0 ],
        [ r.x2 + 1, r.y1, 0, 1, 1, 0 ],
      ];
      for (s in sides)
        {
          var len = (s[2] == 1 ? r.w : r.h);
          var open = true;
          for (i in 0...len)
            {
              var x = s[0] + s[2] * i;
              var y = s[1] + s[3] * i;
              if (cells[x][y] != TEMP_BUILDING_INNER_WALL ||
                  cells[x + s[4]][y + s[5]] != TEMP_BUILDING_CORRIDOR)
                open = false;
            }
          if (!open)
            continue;
          for (i in 0...len)
            cells[s[0] + s[2] * i][s[1] + s[3] * i] = TEMP_BUILDING_CORRIDOR;
          markRoom(cells, r, TEMP_BUILDING_CORRIDOR);
          return true;
        }
      return false;
    }

// calc distance from this point to end of the main corridor
  static function distanceToFinish(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int): Int
    {
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < TEMP_BUILDING_WALL)
            break;
        }
      return len - 1;
    }

// draw a narrow side corridor
  static function drawSideCorridor(state: _FacilityState,
      sx: Int, sy: Int, dir: Int)
    {
      var cells = state.area.getCells();
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (at(cells, x, y) < TEMP_BUILDING_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_WALL);
              var rnd = state.area.random(100);
              if (rnd < 30)
                cells[x][y] = TEMP_BUILDING_SIDE_DOOR;
              else if (rnd < 60)
                cells[x][y] = TEMP_BUILDING_WINDOW;
              break;
            }
          drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_CORRIDOR);
        }
    }

// read a cell, or -1 off the grid.
//
// THE GRID EDGE IS A REAL BOUNDARY HERE and not a defensive check. Every probe below looks OUTSIDE
// the building it is working on — a corridor reads the cell past the wall it is about to stop at, a
// bench block reads the ring around itself — and until Phase 4 nothing ever put a building near the
// map border, so a raw `cells[x][y]` was safe by accident of the arithmetic. The block tree hands
// out whatever plot the split produced, so it is safe by rule now. -1 matches nothing, which is the
// answer every caller wants for a cell that is not there
  public static inline function at(cells: Array<Array<Int>>, x: Int, y: Int): Int
    {
      if (x < 0 ||
          y < 0 ||
          x >= cells.length ||
          y >= cells[0].length)
        return -1;
      return cells[x][y];
    }

// check a w,h block at x,y if it is near a door
  public static function isBlockNearDoor(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int): Bool
    {
      for (i in -1...w + 1)
        for (j in -1...h + 1)
          if (at(cells, x + i, y + j) == TEMP_BUILDING_INNER_DOOR)
            return true;
      return false;
    }
}

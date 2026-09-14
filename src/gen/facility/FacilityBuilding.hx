// one lab building
//
// the wall ring, the main corridor and its branches, the rooms cut off that corridor, and the ribbon
// glazing with the bench runs under it. The pass ORDER inside generateBuilding is load-bearing and is
// commented at each step.

package gen.facility;

import Const;
import game.AreaGenerator;
import game.AreaGenerator.*;
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

// generate a single building of a given size at given coordinates
  public static function generateBuilding(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      // draw outer walls and walkways
      var area = state.area;
      var cells = area.getCells();
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

      // make doors
      FacilityConnect.makeDoors(state, bx, by, bw, bh);

      // various door fixes
      FacilityConnect.fixDoors(state, bx, by, bw, bh);

      // hand each room its template. BEFORE makeWindows, which is where the bench runs are laid: a
      // washroom must never get one, and a researcher's office wants desks and not laboratory glassware
      FacilityRooms.assignRoomThemes(state);

      // make windows
      makeWindows(state, bx, by, bw, bh);

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

// make windows
  static function makeWindows(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var windowTilesList = [
        [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH2, TEMP_BUILDING_WINDOWH3 ],
        [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV2, TEMP_BUILDING_WINDOWV3 ],
        [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH3 ],
        [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV3 ],
      ];
      var table1TilesList = [
        [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_2, Const.TILE_LABS_TABLE_3X1_3, ],
        [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_2, Const.TILE_LABS_TABLE_1X3_3, ],
        [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_3, ],
        [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_3, ],
      ];
      var table2TilesList = [
        [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_2, Const.TILE_LABS_TABLE2_3X1_3, ],
        [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_2, Const.TILE_LABS_TABLE2_1X3_3, ],
        [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_3, ],
        [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_3, ],
      ];
      for (room in state.rooms)
        {
          // clear room to default tile
          drawBlock(cells, room.x1, room.y1, room.w, room.h, TEMP_BUILDING_ROOM);
          // a washroom takes NONE of what follows: not the ribbon glazing, not the bench runs, not
          // the floor decoration. it gets light wells up one wall and is otherwise dressed entirely
          // by its own template
          if (room.role == ROLE_TOILET)
            {
              FacilityToilet.toiletWindows(cells, room);
              continue;
            }
          var corners = getRoomWallCorners(room);
          for (spot in corners)
            {
              var noWindow = false;
              if (cells[spot.x][spot.y] != TEMP_BUILDING_WALL)
                noWindow = true;

              // pick correct window tiles list
              var windowSize = 3;
              var windowTiles = null;
              var tableTilesList = table1TilesList;
              // only upper horizontal tables can have drawers
              if (spot.dir == DIR_RIGHT &&
                  spot.dir90 == DIR_DOWN &&
                  area.chance(50))
                tableTilesList = table2TilesList;
              var tableTiles = null;
              if (spot.dir == DIR_RIGHT && room.w < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[2];
                  tableTiles = tableTilesList[2];
                }
              else if (spot.dir == DIR_RIGHT)
                {
                  windowTiles = windowTilesList[0];
                  tableTiles = tableTilesList[0];
                }
              else if (spot.dir == DIR_DOWN && room.h < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[3];
                  tableTiles = tableTilesList[3];
                }
              else if (spot.dir == DIR_DOWN)
                {
                  windowTiles = windowTilesList[1];
                  tableTiles = tableTilesList[1];
                }

              // paint window and table near it
              var len = 0;
              var tablelen = 0;
              var cnt = 0;
              var delta = deltaMap[spot.dir];
              var delta90 = deltaMap[spot.dir90];
              var x = spot.x, y = spot.y;
              var tx = 0, ty = 0; // table x,y
              var noTable = false;
              // the door-clearance box one BLOCK of tables needs: its length along the run and its
              // one cell across it
              var tw = (spot.dir == DIR_DOWN ? 1 : windowSize);
              var th = (spot.dir == DIR_RIGHT ? 1 : windowSize);
              // does THIS block of tables stand beside a doorway? two things differ from the test it
              // replaces. It is taken on the TABLE line and not the window line, because a doorway
              // one row PAST the tables is still a doorway a bench stands in the swing of and a box
              // centred on the glazing does not reach it. And it is evaluated HERE as well as at
              // each block boundary, because that branch only fires once windowSize cells have gone
              // by — a run's OPENING block was never tested at all, which is the block the bench
              // reported as clipping an open door was in.
              //
              // per block and not latched like noTable above: a run that passes a door in the middle
              // carries on tabling afterwards
              var doorBlock = isBlockNearDoor(cells, spot.x + delta.x + delta90.x,
                spot.y + delta.y + delta90.y, tw, th);
              var hasVentSpace = false; // space near window corner
              while (true)
                {
                  x += delta.x;
                  y += delta.y;
                  tx = x + delta90.x;
                  ty = y + delta90.y;
                  if (cells[x][y] != TEMP_BUILDING_WALL)
                    noWindow = true;
                  if (len >= windowSize)
                    {
                      len = 0;
                      tablelen = 0;
                      cnt++;
                      if (spot.dir == DIR_DOWN &&
                          y >= room.y2 - windowSize)
                        noTable = true;
                      else if (spot.dir == DIR_RIGHT &&
                          x > room.x2 - windowSize)
                        noTable = true;
                      doorBlock = isBlockNearDoor(cells, tx, ty, tw, th);
                      continue;
                    }
                  if (spot.dir == DIR_RIGHT && x >= room.x2 + 1)
                    break;
                  else if (spot.dir == DIR_DOWN && y >= room.y2 + 1)
                    break;
                  if (!noWindow)
                    cells[x][y] = windowTiles[len];
                  len++;
                  // skip first vertical table
                  if (spot.dir == DIR_DOWN && (cnt == 0))
                    continue;
                  // already table or decoration there
                  if (cells[tx][ty] != TEMP_BUILDING_ROOM)
                    continue;
                  if (noTable || doorBlock)
                    {
                      // no table - add floor decoration
                      if (!nextTo(cells, tx, ty, TEMP_BUILDING_INNER_DOOR) &&
                          !area.hasObjectAt(tx, ty))
                        {
                          if (area.chance(70))
                            {
                              var high = area.chance(50);
                              var nextToWindow = nextToWindow(cells, tx, ty);
                              // a decoration beside glazing has to be a LOW one or it stands in
                              // the window
                              if (nextToWindow)
                                high = false;
                              // and so does the one standing in for a bench beside a DOORWAY: a
                              // 2.8-tall fitting there reads as blocking the opening, where a bin or
                              // a drum reads as something somebody left by the door. the cell
                              // orthogonally next to the opening still gets nothing at all — the
                              // nextTo test above keeps the doorway itself walkable
                              if (doorBlock)
                                high = false;
                              // leave space for
                              if (nextToWindow && area.chance(70))
                                hasVentSpace = true;
                              else
                                {
                                  // a HIGH decoration has plain masonry behind it, which is what a
                                  // piece of standing furniture needs, so it may come out as real
                                  // 3D geometry instead of an upright sprite — see
                                  // Const.FACILITY_DECO and render.facility.FacilityDeco
                                  // an office takes STANDING furniture and nothing else: a crate of
                                  // flasks or a waste drum on the floor is the laboratory's clutter,
                                  // and the low list is all laboratory
                                  if (room.role == ROLE_CABINET)
                                    {
                                      if (high)
                                        FacilityRooms.addFitting(state, tx, ty, room.role);
                                    }
                                  else if (high &&
                                      area.chance(Const.FACILITY_FITTING_PCT))
                                    FacilityRooms.addFitting(state, tx, ty);
                                  else
                                    FacilityRooms.addDecoration(state, tx, ty, high ?
                                      Const.CHEM_LABS_DECO_FLOOR_HIGH :
                                      Const.CHEM_LABS_DECO_FLOOR_LOW);
                                  // change to unwalkable tile
                                  if (area.hasObjectAt(tx, ty))
                                    cells[tx][ty] =
                                      Const.TILE_FLOOR_TILE_UNWALKABLE;
                                }
                            }
                        }
                    }
                  else
                    {
                      // add next table tile
                      if (cells[tx][ty] == TEMP_BUILDING_ROOM)
                        {
                          cells[tx][ty] = tableTiles[tablelen];
                          tablelen++;
                        }
                      // add table decoration
                      // NOTE: corner tile always has decoration
                      // so that we cannot spawn clues there
                      // because of the clue activation range cross
                      if (area.chance(70) ||
                          (tx == room.x1 && ty == room.y1) ||
                          (tx == room.x2 && ty == room.y1) ||
                          (tx == room.x1 && ty == room.y2) ||
                          (tx == room.x2 && ty == room.y2))
                        FacilityRooms.addDecoration(state, tx, ty,
                          Const.CHEM_LABS_DECO_TABLE);
                    }
                }
              // fix last cell if necessary
              x -= delta.x;
              y -= delta.y;
              if (cells[x][y] == TEMP_BUILDING_WINDOWH2)
                cells[x][y] = TEMP_BUILDING_WINDOWH3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWH1)
                {
                  cells[x][y] = TEMP_BUILDING_WINDOW;
                  if (area.chance(30) || hasVentSpace)
                    cells[x][y] = TEMP_BUILDING_VENT;
                }
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV2)
                cells[x][y] = TEMP_BUILDING_WINDOWV3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV1)
                {
                  cells[x][y] = TEMP_BUILDING_WINDOW;
                  if (area.chance(30) || hasVentSpace)
                    cells[x][y] = TEMP_BUILDING_VENT;
                }
            }
          // and with the room's benches dealt, make sure a clue still has somewhere to land on them
          FacilityRooms.clearTableSpots(state, room);
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
  static inline function at(cells: Array<Array<Int>>, x: Int, y: Int): Int
    {
      if (x < 0 ||
          y < 0 ||
          x >= cells.length ||
          y >= cells[0].length)
        return -1;
      return cells[x][y];
    }

// check a w,h block at x,y if it is near a door
  static function isBlockNearDoor(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int): Bool
    {
      for (i in -1...w + 1)
        for (j in -1...h + 1)
          if (at(cells, x + i, y + j) == TEMP_BUILDING_INNER_DOOR)
            return true;
      return false;
    }

// check if this cell is next to a window
  static function nextToWindow(cells: Array<Array<Int>>,
      x: Int, y: Int): Bool
    {
      var tile = 0;
      for (i in 0...Const.dir4x.length)
        {
          tile = at(cells, x + Const.dir4x[i], y + Const.dir4y[i]);
          if (tile >= TEMP_BUILDING_WINDOW &&
              tile <= TEMP_BUILDING_WINDOWV3)
            return true;
        }
      return false;
    }
}

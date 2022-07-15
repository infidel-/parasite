// facility area generation

package game;

import const.WorldConst;
import objects.*;
import game.AreaGame;

class FacilityAreaGenerator
{
// entry-point for facility generation
  public static function generate(game: Game, area: AreaGame, info: AreaInfo)
    {
      deltaMap = [
        DIR_LEFT => { x: -1, y: 0 },
        DIR_RIGHT => { x: 1, y: 0 },
        DIR_UP => { x: 0, y: -1 },
        DIR_DOWN => { x: 0, y: 1 },
      ];
      finalTiles = [
        TEMP_BLANK => Const.TILE_ROAD,
        TEMP_BUILDING_WALL => Const.TILE_BUILDING,
        TEMP_BUILDING_ROOM => Const.TILE_FLOOR_TILE,
        TEMP_BUILDING_CORRIDOR => Const.TILE_FLOOR_LINO,
        TEMP_BUILDING_FRONT_DOOR => Const.TILE_DOOR_DOUBLE,
        TEMP_BUILDING_SIDE_DOOR => Const.TILE_DOOR_GLASS,
        TEMP_BUILDING_WINDOW => Const.TILE_WINDOW1,
        TEMP_BUILDING_WINDOWH1 => Const.TILE_WINDOWH1,
        TEMP_BUILDING_WINDOWH2 => Const.TILE_WINDOWH2,
        TEMP_BUILDING_WINDOWH3 => Const.TILE_WINDOWH3,
        TEMP_BUILDING_WINDOWV1 => Const.TILE_WINDOWV1,
        TEMP_BUILDING_WINDOWV2 => Const.TILE_WINDOWV2,
        TEMP_BUILDING_WINDOWV3 => Const.TILE_WINDOWV3,
        TEMP_BUILDING_INNER_WALL => Const.TILE_BUILDING,
//        TEMP_BUILDING_ROOM_MARKED => Const.TILE_GROUND,
        TEMP_BUILDING_INNER_DOOR => Const.TILE_DOOR_CABINET,
      ];
      var state: _FacilityState = {
        game: game,
        area: area,
        info: info,
        rooms: null,
        doors: null,
      }
      // fill with blank
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = TEMP_BLANK;
      var t1 = Sys.time();
      generateBuilding(state, 1, 1,
        Std.int(area.width * 0.75),
        Std.int(area.height * 0.75));
      AreaGenerator.printArea(state.game, state.area, mapTempTiles);

      // convert temp tiles to ingame ones
      finalizeTiles(state);
      trace(Std.int((Sys.time() - t1) * 1000) + 'ms');
    }

// generate a single building of a given sizen at given coordinates
  static function generateBuilding(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      trace('b: ' + bx + ',' + by + ' sz:' + bw + ',' + bh);
      // fill with blank
      var area = state.area;
      var cells = area.getCells();
      for (y in by...bh + 1)
        for (x in bx...bw + 1)
          {
            var tile = TEMP_BUILDING_ROOM;
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              tile = TEMP_BUILDING_WALL;
            cells[x][y] = tile;
          }

      // pick a wall for a front door
      var outerWalls = [
        { x1: bx, y1: by, x2: bx + bw - 1, y2: by, dir: DIR_DOWN }, // top
        { x1: bx, y1: by, x2: bx, y2: by + bh - 1, dir: DIR_RIGHT }, // left
        { x1: bx, y1: by + bh - 1, x2: bx + bw - 1,
          y2: by + bh - 1, dir: DIR_UP }, // bottom
        { x1: bx + bw - 1, y1: by, x2: bx + bw - 1, y2: by + bh - 1, dir: DIR_LEFT }, // right
      ];
      var frontWall = outerWalls[Std.random(outerWalls.length)];

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
      var sideCorridorAmount1 = 0, sideCorridorAmount2 = 0;
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
          if (cells[x][y] == TEMP_BLANK)
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
          if (sideCorridorCount1 > ROOM_SIZE && Std.random(100) > 70)
            {
              var dir = 0; 
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_LEFT;
              else dir = DIR_UP;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(cells, x, y, dir);
              sideCorridorCount1 = 0;
            }
          sideCorridorCount2++;
          if (sideCorridorCount2 > ROOM_SIZE && Std.random(100) > 70)
            {
              var dir = 0; 
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_RIGHT;
              else dir = DIR_DOWN;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(cells, x, y, dir);
              sideCorridorCount2 = 0;
            }
        }
      // side door/window
      if (Std.random(100) < 50)
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
//        drawChunk(cells, x, y, corridorWidth,
//          frontWall.dir, TEMP_BUILDING_WINDOW);
        }
      else
        {
          if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
            cells[x + 1][y] = TEMP_BUILDING_SIDE_DOOR;
          else cells[x][y + 1] = TEMP_BUILDING_SIDE_DOOR;

        }

      // draw inner walls
      for (y in by + 1...bh)
        for (x in bx + 1...bw)
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
      makeDoors(state, bx, by, bw, bh);

      // various door fixes
      fixDoors(state, bx, by, bw, bh);

      // make windows
      makeWindows(state, bx, by, bw, bh);

      // work on individual rooms
      generateRoomContents(state);

//      replaceTiles(cells, bx, by, bw, bh,
//        TEMP_BUILDING_ROOM_MARKED, TEMP_BUILDING_ROOM);
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
      for (y in by + 1...bh)
        for (x in bx + 1...bw)
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and wall division direction
            var room = getRoom(cells, x, y);
//            trace(room);
            var dir = 0;
            if (room.w > ROOM_SIZE * 1.5)
              dir = DIR_DOWN;
            if (room.h > ROOM_SIZE * 1.5)
              dir = DIR_RIGHT;
            if (dir == 0)
              {
                markRoom(cells, room, TEMP_BUILDING_ROOM_MARKED);
                continue;
              }
/*
            if (Std.random(100) < 10)
              {
                markRoom(cells, room);
                continue;
              }*/

            // find starting wall division spot
            var sx = 0, sy = 0;
            if (dir == DIR_DOWN)
              {
                var neww = Std.int(room.w / 2);
                if (Std.random(100) < 30)
                  neww = Std.int(room.w / 3);
                neww += Std.random(4) - 2;
                if (neww < 4)
                  neww = 4;
                sx = room.x1 + neww;
                sy = room.y1;
              }
            else if (dir == DIR_RIGHT)
              {
                var newh = Std.int(room.h / 2);
                if (Std.random(100) < 30)
                  newh = Std.int(room.h / 3);
                newh += Std.random(4) - 2;
                if (newh < 4)
                  newh = 4;
                sx = room.x1;
                sy = room.y1 + newh;
              }
//            trace(sx + ',' + sy);
            var len = drawLine(cells, sx, sy, dir, TEMP_BUILDING_INNER_WALL);
//            trace('len:' + len);
            var newRoom = getRoom(cells, x, y);
//            trace(newRoom);
            markRoom(cells, newRoom, TEMP_BUILDING_ROOM_MARKED);
            rooms++;
//            if (rooms >= 2)
//            return;
          }
    }
  
// make inner wall doors
  static function makeDoors(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomID = TEMP_BUILDING_ROOM_ID_START - 1;
      var doors = [];
      var rooms = [];
      for (y in by + 1...bh)
        for (x in bx + 1...bw)
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and door direction
            var room = getRoom(cells, x, y);
            roomID++;
            room.id = roomID;
            rooms.push(room);
//            trace(room);
/*
            if (Std.random(100) < 30)
              {
                markRoom(cells, room);
                continue;
              }*/

            var tmp = getRoomDoorSpots(room);
            var spots = [];
            for (s in tmp)
              {
                if (cells[s.x][s.y] != TEMP_BUILDING_INNER_WALL)
                  continue;
                // check for neighbouring tiles
                var cnt = 0;
                for (i in 0...Const.dir4x.length)
                  {
                    var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
                    if (t == TEMP_BUILDING_INNER_WALL ||
                        t == TEMP_BUILDING_WALL) 
                      cnt++;
                  }
                if (cnt > 2) // triangle
                  continue;
                
                spots.push(s);
              }
            if (spots.length == 0)
              {
                trace('bug, no door spots in room ' + room);
                continue;
              }
            var spot = spots[Std.random(spots.length)];
//            trace(spot + ' old: ' + cells[spot.x][spot.y]);
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
    }

// remove double doors into the same rooms
// fix room clusters that have no exit into any corridors
  static function fixDoors(state: _FacilityState,
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
//      trace(doors);

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
//                  trace('to remove ' + door + ' door2:' + door2);
                  toRemove.push(door);
                  door2.skip = true;
                }
            }
        }
      for (door in toRemove)
        {
          cells[door.x][door.y] = TEMP_BUILDING_INNER_WALL;
          doors.remove(door);
//          trace('removed ' + door);
        }
//      trace(doors);

      // generate lists of interconnected rooms
      var clusters: Array<Array<Int>> = [];
      for (door in doors)
        {
          var ok = false;
          for (c in clusters)
            {
              if (door.roomID1 > 0 && Lambda.has(c, door.roomID1))
                {
                  if (!Lambda.has(c, door.roomID2))
                    c.push(door.roomID2);
                  ok = true;
                }
              if (door.roomID2 > 0 && Lambda.has(c, door.roomID2))
                {
                  if (!Lambda.has(c, door.roomID1))
                    c.push(door.roomID1);
                  ok = true;
                }
            }
          if (ok)
            continue;
          var cluster = [ door.roomID1, door.roomID2 ];
          clusters.push(cluster);
        }
      trace(clusters);

      // find room blocks that do not have a corridor exit and make one
      for (c in clusters)
        {
          // has corridor exit
          if (Lambda.has(c, 0))
            continue;
          var cluster = c.slice(0, c.length);
          while (true)
            {
              var roomID = cluster[Std.random(cluster.length)];
              var ret = makeDoorToCorridor(state, roomID);
              if (ret)
                break;
              cluster.remove(roomID);
              if (cluster.length == 0)
                {
                  trace('bug, no corridor-adjacent walls in cluster ' + cluster);
                  break;
                }
            }
        }
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
//      trace('adding door to room ' + roomID + ' '+ room);

      // get door spots and check which will go into the corridor
      var tmp = getRoomDoorSpots(room);
      var spots = [];
      for (s in tmp)
        {
          var delta = deltaMap[s.dir];
          if (cells[s.x + delta.x][s.y + delta.y] != TEMP_BUILDING_CORRIDOR)
            continue;
          spots.push(s);
        }
      if (spots.length == 0)
        return false;
      var spot = spots[Std.random(spots.length)];
      cells[spot.x][spot.y] = TEMP_BUILDING_INNER_DOOR;
      state.doors.push({
        x: spot.x,
        y: spot.y,
        dir: spot.dir,
        roomID1: roomID,
        roomID2: 0,
        skip: false,
      });
//      trace(spot);
      return true;
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
      for (room in state.rooms)
        {
          var corners = getRoomWallCorners(room);
//          trace(room + ' ' + corners);
          for (spot in corners)
            {
              if (cells[spot.x][spot.y] != TEMP_BUILDING_WALL)
                continue;

              // pick correct window tiles list
              var windowSize = 3;
              var windowTiles = null;
              if (spot.dir == DIR_RIGHT && room.w < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[2];
                }
              else if (spot.dir == DIR_RIGHT)
                windowTiles = windowTilesList[0];
              else if (spot.dir == DIR_DOWN && room.h < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[3];
                }
              else if (spot.dir == DIR_DOWN)
                windowTiles = windowTilesList[1];

              // paint window
              var len = 0;
              var delta = deltaMap[spot.dir];
              var x = spot.x, y = spot.y;
              while (true)
                {
                  x += delta.x;
                  y += delta.y;
                  if (cells[x][y] != TEMP_BUILDING_WALL)
                    break;
                  if (len >= windowSize)
                    {
                      len = 0;
                      continue;
                    }
                  if (spot.dir == DIR_RIGHT && x >= room.x2 + 1)
                    break;
                  else if (spot.dir == DIR_DOWN && y >= room.y2 + 1)
                    break;
                  cells[x][y] = windowTiles[len];
                  len++;
                }
              // fix last cell if necessary
              x -= delta.x;
              y -= delta.y;
              if (cells[x][y] == TEMP_BUILDING_WINDOWH2)
                cells[x][y] = TEMP_BUILDING_WINDOWH3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWH1)
                cells[x][y] = TEMP_BUILDING_WINDOW;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV2)
                cells[x][y] = TEMP_BUILDING_WINDOWV3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV1)
                cells[x][y] = TEMP_BUILDING_WINDOW;
            }
        }
    }

// fill rooms with content
  static function generateRoomContents(state: _FacilityState)
    {
      for (room in state.rooms)
        {
          roomChemistryLab(state, room);
        }
    }

// make this room a chem lab
  static function roomChemistryLab(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var tableW = 1 + Std.random(3), tableH = 1 + Std.random(3);
      if (room.w <= 5)
        tableW = 1;
      else if (room.w > 5)
        tableW = 2;
      if (room.h <= 5)
        tableH = 1;
      else if (room.h > 5)
        tableH = 2;
      if (tableW == 3 && tableH == 3)
        tableW = 2;
      var table1: Array<Array<Int>> =
        Reflect.field(Const, 'LABS_TABLE_' + tableW + 'X' + tableH);
      var table2: Array<Array<Int>> =
        Reflect.field(Const, 'LABS_TABLE2_' + tableW + 'X' + tableH);

      // clear room to default tile
      drawBlock(cells, room.x1, room.y1, room.w, room.h, TEMP_BUILDING_ROOM);

      // go left
      var sx = room.x1 + Std.random(2), sy = room.y1 + Std.random(2);
      var x = sx, y = sy;
      while (x <= room.x2 + 1 - tableW)
        {
          // go down
          while (y <= room.y2 + 1 - tableH)
            {
              // check if this block is near door
              if (!isBlockNearDoor(cells, x, y, tableW, tableH))
                drawArray(cells, x, y,
                  (Std.random(100) < 30 ? table2 : table1));
              y += tableH + 1;
            }
          x += tableW + 1;
          y = sy;
        }
    }

// check a w,h block at x,y if it is near a door
  static function isBlockNearDoor(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int): Bool
    {
      for (i in -1...w + 1)
        for (j in -1...h + 1)
          if (cells[x + i][y + j] == TEMP_BUILDING_INNER_DOOR)
            return true;
      return false;
    }

// mark all A tiles to B tiles in rect
  static function replaceTiles(cells: Array<Array<Int>>,
      sx: Int, sy: Int, w: Int, h: Int, from: Int, to: Int)
    {
      for (y in sy...h + 1)
        for (x in sx...w + 1)
          if (cells[x][y] == from)
            cells[x][y] = to;
    }

// draw line from starting position into a given direction
  static function drawLine(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int, tile: Int): Int
    {
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      var startTile = cells[sx][sy];
//      trace(startTile);
      cells[sx][sy] = tile;
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
          if (cells[x][y] != startTile)
            break;
          cells[x][y] = tile;
//          trace(x + ',' + y + ' = ' + tile + cells[x][y]);
        }
//      trace('len:' + len);
      return len - 1;
    }

// mark room as sub-divided
  static function markRoom(cells: Array<Array<Int>>,
      room: _Room, tileID: Int)
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          cells[x][y] = tileID;
    }

// get room dimensions
  static function getRoom(cells: Array<Array<Int>>,
      sx: Int, sy: Int): _Room 
    {
      var w = 0, h = 0;
      while (true)
        {
          w++;
          if (w > 100)
            {
              trace('room too large?');
              break;
            }

          if (cells[sx + w][sy] != TEMP_BUILDING_ROOM)
            break;
        }
      while (true)
        {
          h++;
          if (h > 100)
            {
              trace('room too large?');
              break;
            }

          if (cells[sx][sy + h] != TEMP_BUILDING_ROOM)
            break;
        }
      w--;
      h--;
      return {
        id: -1,
        x1: sx,
        y1: sy,
        x2: sx + w,
        y2: sy + h,
        w: w + 1,
        h: h + 1,
      }
    }

// check if this cell is next to a given tile
  static function nextTo(cells: Array<Array<Int>>,
      x: Int, y: Int, tile: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == tile)
          return true;
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
          if (cells[x][y] == TEMP_BLANK)
            break;
        }
      return len - 1;
    }

// draw a narrow side corridor
  static function drawSideCorridor(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int)
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
          if (cells[x][y] == TEMP_BLANK)
            {
              x -= delta.x;
              y -= delta.y;
              drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_WALL);
              var rnd = Std.random(100);
              if (rnd < 30)
                cells[x][y] = TEMP_BUILDING_SIDE_DOOR;
              else if (rnd < 60)
                cells[x][y] = TEMP_BUILDING_WINDOW;
              break;
            }
          drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_CORRIDOR);
        }
    }

// get potential door spots in room
  static function getRoomDoorSpots(room: _Room): Array<_Spot>
    {
      return [
        {
          x: room.x1 - 1,
          y: Std.int(room.y1 + room.h / 2),
          dir: DIR_LEFT,
        },
        {
          x: room.x2 + 1,
          y: Std.int(room.y1 + room.h / 2),
          dir: DIR_RIGHT,
        },
        {
          x: Std.int(room.x1 + room.w / 2),
          y: room.y1 - 1,
          dir: DIR_UP,
        },
        {
          x: Std.int(room.x1 + room.w / 2),
          y: room.y2 + 1,
          dir: DIR_DOWN,
        },
      ];
    }

// get room wall corner spots with wall directions
  static function getRoomWallCorners(room: _Room): Array<_Spot>
    {
      return [
        {
          x: room.x1 - 1,
          y: room.y1 - 1,
          dir: DIR_RIGHT,
        },
        {
          x: room.x1 - 1,
          y: room.y2 + 1,
          dir: DIR_RIGHT,
        },
        {
          x: room.x1 - 1,
          y: room.y1 - 1,
          dir: DIR_DOWN,
        },
        {
          x: room.x2 + 1,
          y: room.y1 - 1,
          dir: DIR_DOWN,
        },
      ];
    }

// draw a chunk of a line of a given width and direction
  static function drawChunk(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, dir: Int, tile: Int)
    {
      if (dir == DIR_UP || dir == DIR_DOWN)
        for (i in 0...w)
          cells[x + i][y] = tile;
      else for (i in 0...w)
        cells[x][y + i] = tile;
    }

// draw a w,h block at x,y 
  static function drawBlock(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int, tile: Int)
    {
      for (i in 0...w)
        for (j in 0...h)
          cells[x + i][y + j] = tile;
    }

// draw an 2-dim array at x,y 
  static function drawArray(cells: Array<Array<Int>>, x: Int, y: Int,
      block: Array<Array<Int>>)
    {
      for (i in 0...block[0].length)
        for (j in 0...block.length)
          cells[x + i][y + j] = block[j][i];
    }

// replace all temp tiles into final ones
  static function finalizeTiles(state: _FacilityState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            if (tileID >= Const.OFFSET_ROW8)
              continue;
/*
            if (tileID >= TEMP_BUILDING_ROOM_ID_START)
              tileID = Const.TILE_FLOOR_TILE;*/
            else tileID = finalTiles[tileID];

            cells[x][y] = tileID;
          }
    }

  static var finalTiles: Map<Int, Int>;
  static var deltaMap: Map<Int, { x: Int, y: Int }>;/* = [
    DIR_LEFT => { x: -1, y: 0 },
    DIR_RIGHT => { x: 1, y: 0 },
    DIR_UP => { x: 0, y: -1 },
    DIR_DOWN => { x: 0, y: 1 },
  ];*/

  static var DIR_UP = 8;
  static var DIR_LEFT = 4;
  static var DIR_RIGHT = 6;
  static var DIR_DOWN = 2;

  static var ROOM_SIZE = 7; // 6 + 1 wall
  static var TEMP_BLANK = 0;
  static var TEMP_BUILDING_WALL = 1;
  static var TEMP_BUILDING_ROOM = 2;
  static var TEMP_BUILDING_CORRIDOR = 3;
  static var TEMP_BUILDING_FRONT_DOOR = 4;
  static var TEMP_BUILDING_SIDE_DOOR = 5;
  static var TEMP_BUILDING_WINDOW = 6;
  static var TEMP_BUILDING_INNER_WALL = 7;
  static var TEMP_BUILDING_ROOM_MARKED = 8;
  static var TEMP_BUILDING_INNER_DOOR = 9;
  static var TEMP_BUILDING_WINDOWH1 = 10;
  static var TEMP_BUILDING_WINDOWH2 = 11;
  static var TEMP_BUILDING_WINDOWH3 = 12;
  static var TEMP_BUILDING_WINDOWV1 = 13;
  static var TEMP_BUILDING_WINDOWV2 = 14;
  static var TEMP_BUILDING_WINDOWV3 = 15;
  static var TEMP_BUILDING_TABLE = 16;
  static var TEMP_BUILDING_ROOM_ID_START = 100;
  static var mapTempTiles = [
    '0', '#', '2', '.', 'x', '+', 'w', '*', '8', 'X',
    '<', '-', '>', '^', '|', 'v', '_'
  ];
}

typedef _FacilityState = {
  var game: Game;
  var area: AreaGame;
  var info: AreaInfo;

  // temp state
  var rooms: Array<_Room>;
  var doors: Array<_Door>;
}
typedef _Room = {
  id: Int,
  x1: Int,
  y1: Int,
  x2: Int,
  y2: Int,
  w: Int,
  h: Int
}
typedef _Door = {
  x: Int,
  y: Int,
  dir: Int,
  roomID1: Int,
  roomID2: Int,
  skip: Bool,
}
typedef _Spot = {
  x: Int,
  y: Int,
  dir: Int,
}

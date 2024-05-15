// corp area generation

package game;

import const.WorldConst;
import Const;
import objects.*;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator.*;

class CorpAreaGenerator
{
  var game: Game;
  var gen: AreaGenerator;
  var state: _CorpState;

  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
      finalTiles = [
        ROAD => Const.TILE_ROAD_UNWALKABLE,
        WALKWAY => Const.TILE_WALKWAY_UNWALKABLE,
        ALLEY => Const.TILE_ALLEY_UNWALKABLE,
        GRASS => Const.TILE_GRASS,
        CONCRETE => Const.TILE_FLOOR_CONCRETE,
        CARPET => Const.TILE_FLOOR_CARPET,
        WOOD1 => Const.TILE_FLOOR_WOOD1,
        WOOD2 => Const.TILE_FLOOR_WOOD2,
        MARBLE1 => Const.TILE_FLOOR_MARBLE1,
        MARBLE2 => Const.TILE_FLOOR_MARBLE2,
        BLDG_WALL => Const.TILE_BUILDING,
        BLDG_ROOM => Const.TILE_FLOOR_CARPET,
        BLDG_CORRIDOR => Const.TILE_FLOOR_CARPET,
        BLDG_ELEVATOR_DOOR => Const.TILE_FLOOR_TILE_CANNOTSEE,
        BLDG_WINDOW => Const.TILE_CORP_WINDOW1,
        BLDG_WINDOWH1 => Const.TILE_CORP_WINDOWH1,
        BLDG_WINDOWH2 => Const.TILE_CORP_WINDOWH2,
        BLDG_WINDOWH3 => Const.TILE_CORP_WINDOWH3,
        BLDG_WINDOWV1 => Const.TILE_CORP_WINDOWV1,
        BLDG_WINDOWV2 => Const.TILE_CORP_WINDOWV2,
        BLDG_WINDOWV3 => Const.TILE_CORP_WINDOWV3,
        BLDG_INNER_WALL => Const.TILE_BUILDING,
        BLDG_INNER_DOOR => Const.TILE_FLOOR_CARPET,
        BLDG_VENT => Const.TILE_BUILDING,
        INNER_WINDOW => Const.TILE_CORP_INNER_WINDOW1,
        INNER_WINDOWH1 => Const.TILE_CORP_INNER_WINDOWH1,
        INNER_WINDOWH2 => Const.TILE_CORP_INNER_WINDOWH2,
        INNER_WINDOWH3 => Const.TILE_CORP_INNER_WINDOWH3,
        INNER_WINDOWV1 => Const.TILE_CORP_INNER_WINDOWV1,
        INNER_WINDOWV2 => Const.TILE_CORP_INNER_WINDOWV2,
        INNER_WINDOWV3 => Const.TILE_CORP_INNER_WINDOWV3,
      ];
    }

// entry-point for facility generation
  public function generate(area: AreaGame, info: AreaInfo)
    {
      state = {
        area: area,
        info: info,
        rooms: null,
        doors: null,
      }
      // fill with blank
      var cells = area.getCells();
      drawBlock(cells, 0, 0, area.width, area.height, ALLEY);

      // main building
      var t1 = Sys.time();
      var mainw = Std.int(area.width * 0.75),
        mainh = Std.int(area.height * 0.75);
      var mainx = Std.int(area.width * 0.1),
        mainy = Std.int(area.height * 0.1);
      generateBuilding(state, mainx, mainy, mainw, mainh);
      state.rooms = null;
      state.doors = null;

/*
      // hole in sidewalk for entry to parking lot
      var hx = mainx + mainw + 10, hy = sidewalky;
      drawBlock(cells, hx, hy, 4, 2, ALLEY);
      // sewer hatches
      var cnt = 0;
      var sewersDist = 10 + Std.random(10);
      for (x in 0...hx)
        {
          cnt++;
          if (cnt < sewersDist)
            continue;
          var o = new SewerHatch(game, area.id, x, sidewalky +
            (state.mainRoadNorth ? 0 : 1));
          area.addObject(o);
          cnt = 0;
        }
*/

      // trace area
      AreaGenerator.printArea(game, state.area, mapTempTiles);

      // convert temp tiles to ingame ones
      finalizeTiles(state);
      trace(Std.int((Sys.time() - t1) * 1000) + 'ms');
    }

// generate a single building of a given size at given coordinates
  function generateBuilding(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
//      trace('b: ' + bx + ',' + by + ' sz:' + bw + ',' + bh);
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

      // pick a wall for elevator
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

      // elevator door
      var corridorWidth = 3;
      cells[frontDoor.x][frontDoor.y] = BLDG_ELEVATOR_DOOR;
      // elevator stuff
      elevator(frontDoor, frontWall.dir);

      // draw main corridor
      var len = 0, x = frontDoor.x, y = frontDoor.y;
      if (frontWall.dir == DIR_UP ||
          frontWall.dir == DIR_DOWN)
        x--;
      else y--;
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
          if (cells[x][y] < BLDG_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              // fix the hole :)
              drawChunk(cells, x, y, corridorWidth,
                frontWall.dir, BLDG_WALL);
              break;
            }
          drawChunk(cells, x, y, corridorWidth,
            frontWall.dir, BLDG_CORRIDOR);

          // check for side corridors
          sideCorridorCount1++;
          if (sideCorridorCount1 > ROOM_SIZE &&
              Std.random(100) > 70)
            {
              var dir = 0; 
              if (frontWall.dir == DIR_UP ||
                  frontWall.dir == DIR_DOWN)
                dir = DIR_LEFT;
              else dir = DIR_UP;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(cells, x, y, dir);
              sideCorridorCount1 = 0;
            }
          sideCorridorCount2++;
          if (sideCorridorCount2 > ROOM_SIZE &&
              Std.random(100) > 70)
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

      // stairs
      var stairsx = x, stairsy = y;
      if (frontWall.dir == DIR_LEFT)
        {
          stairsx++;
          stairsy++;
        }
      if (frontWall.dir == DIR_RIGHT)
        {
          stairsx--;
          stairsy++;
        }
      if (frontWall.dir == DIR_UP)
        {
          stairsx++;
          stairsy++;
        }
      if (frontWall.dir == DIR_DOWN)
        {
          stairsx++;
          stairsy--;
        }
      area.addObject(new Stairs(game, area.id, stairsx, stairsy));

      // back window
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

      // draw inner walls
      for (y in by + 1...by + bh + 1)
        for (x in bx + 1...bx + bw + 1)
          if (cells[x][y] == BLDG_ROOM &&
              nextTo(cells, x, y, BLDG_CORRIDOR))
            cells[x][y] = BLDG_INNER_WALL;

      // sub-divide larger rooms
      for (i in 0...1)
        {
          subdivideLargeRooms(state, bx, by, bw, bh);
          replaceTiles(cells, bx, by, bw, bh,
            BLDG_ROOM_MARKED, BLDG_ROOM);
        }

      // make doors
      makeDoors(state, bx, by, bw, bh);

      // various door fixes
      fixDoors(state, bx, by, bw, bh);

      // make windows
      makeWindows(state, bx, by, bw, bh);

      // work on individual rooms
      var numKitchen = 0, numMeeting = 0, numSolo = 0;
      for (room in state.rooms)
        {
          // small room
          if (room.w <= 7 || room.h <= 7)
            {
              if (numKitchen < 2 && Std.random(100) < 85)
                {
                  numKitchen++;
                  roomKitchen(room);
                }
              else if (numMeeting < 2 && Std.random(100) < 85)
                {
                  numMeeting++;
                  roomMeeting(room);
                }
              else if (numSolo < 3 && Std.random(100) < 85)
                {
                  numSolo++;
                  roomSolo(room);
                }
              // there is a chance that nothing rolled, add another random room
              else
                {
                  var rnd = Std.random(100);
                  if (rnd < 33)
                    roomKitchen(room);
                  else if (rnd < 66)
                    roomMeeting(room);
                  else roomSolo(room);
                }
            }
          else roomWork(room);
        }

//      replaceTiles(cells, bx, by, bw, bh,
//        BLDG_ROOM_MARKED, BLDG_ROOM);
    }

// paint elevator (walls, door, etc)
  function elevator(door, dir: Int)
    {
      // elevator floor coordinates
      var area = state.area;
      var cells = area.getCells();
      var el: _Room = {
        id: 0,
        x1: 0,
        y1: 0,
        x2: 0,
        y2: 0,
        w: 3,
        h: 3,
      };
      switch (dir)
        {
          // top
          case 2:
            el.x1 = door.x - 1;
            el.y1 = door.y - 3;
          // bottom
          case 8:
            el.x1 = door.x - 1;
            el.y1 = door.y + 1;
          // left
          case 6:
            el.x1 = door.x - 3;
            el.y1 = door.y - 1;
          // right
          case 4:
            el.x1 = door.x + 1;
            el.y1 = door.y - 1;
        }
      el.x2 = el.x1 + 2;
      el.y2 = el.y1 + 2;

      // elevator floor (concrete looks good)
      drawBlock(cells, el.x1, el.y1, el.w, el.h, CONCRETE);
      // invisible objects
      for (dy in 0...3)
        for (dx in 0...3)
          area.addObject(new Elevator(game, area.id, el.x1 + dx, el.y1 + dy));
      // wall corners
      cells[el.x1 - 1][el.y1 - 1] = BLDG_WALL;
      cells[el.x1 - 1][el.y2 + 1] = BLDG_WALL;
      cells[el.x2 + 1][el.y1 - 1] = BLDG_WALL;
      cells[el.x2 + 1][el.y2 + 1] = BLDG_WALL;

      // top wall
      if (dir != DIR_UP)
        {
          cells[el.x1][el.y1 - 1] = BLDG_WINDOWH1;
          cells[el.x1 + 1][el.y1 - 1] = BLDG_WINDOWH2;
          cells[el.x1 + 2][el.y1 - 1] = BLDG_WINDOWH3;
        }
      // bottom wall
      if (dir != DIR_DOWN)
        {
          cells[el.x1][el.y2 + 1] = BLDG_WINDOWH1;
          cells[el.x1 + 1][el.y2 + 1] = BLDG_WINDOWH2;
          cells[el.x1 + 2][el.y2 + 1] = BLDG_WINDOWH3;
        }
      // left wall
      if (dir != DIR_LEFT)
        {
          cells[el.x1 - 1][el.y1] = BLDG_WINDOWV1;
          cells[el.x1 - 1][el.y1 + 1] = BLDG_WINDOWV2;
          cells[el.x1 - 1][el.y1 + 2] = BLDG_WINDOWV3;
        }
      // right wall
      if (dir != DIR_RIGHT)
        {
          cells[el.x2 + 1][el.y1] = BLDG_WINDOWV1;
          cells[el.x2 + 1][el.y1 + 1] = BLDG_WINDOWV2;
          cells[el.x2 + 1][el.y1 + 2] = BLDG_WINDOWV3;
        }
    }
  
// sub-divide larger rooms
// if isFinal is true, mark with room ids
// if it is false, mark with BLDG_ROOM_MARKED
  function subdivideLargeRooms(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var rooms = 0;
      for (y in by + 1...by + bh)
        for (x in bx + 1...bx + bw)
          {
            // find next room start spot
            if (cells[x][y] != BLDG_ROOM)
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
                markRoom(cells, room, BLDG_ROOM_MARKED);
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
            var len = drawLine(cells, sx, sy, dir, BLDG_INNER_WALL);
//            trace('len:' + len);
            var newRoom = getRoom(cells, x, y);
//            trace(newRoom);
            markRoom(cells, newRoom, BLDG_ROOM_MARKED);
            rooms++;
//            if (rooms >= 2)
//            return;
          }
    }
  
// make inner wall doors
  function makeDoors(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomID = BLDG_ROOM_ID_START - 1;
      var doors = [];
      var rooms = [];
      for (y in (by + 1)...(by + bh))
        for (x in (bx + 1)...(bx + bw))
          {
            // find next room start spot
            if (cells[x][y] != BLDG_ROOM)
              continue;

            // get room dimensions and door direction
            var room = getRoom(cells, x, y);
            roomID++;
            room.id = roomID;
            rooms.push(room);
/*
            if (roomID < 104)
              trace(room);*/
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
                if (cells[s.x][s.y] != BLDG_INNER_WALL)
                  continue;
                // check for neighbouring tiles
                var cnt = 0;
                for (i in 0...Const.dir4x.length)
                  {
                    var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
                    if (t == BLDG_INNER_WALL ||
                        t == BLDG_WALL) 
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
            cells[spot.x][spot.y] = BLDG_INNER_DOOR;
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
  function fixDoors(state: _CorpState,
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
          if (door.roomID2 < BLDG_ROOM_ID_START)
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
          cells[door.x][door.y] = BLDG_INNER_WALL;
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
//      trace(clusters);

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
  function makeDoorToCorridor(state: _CorpState, roomID: Int): Bool
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
          if (cells[s.x + delta.x][s.y + delta.y] != BLDG_CORRIDOR)
            continue;
          spots.push(s);
        }
      if (spots.length == 0)
        return false;
      var spot = spots[Std.random(spots.length)];
      cells[spot.x][spot.y] = BLDG_INNER_DOOR;
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

  var windowTilesList = [
    [ BLDG_WINDOWH1, BLDG_WINDOWH2, BLDG_WINDOWH3 ],
    [ BLDG_WINDOWV1, BLDG_WINDOWV2, BLDG_WINDOWV3 ],
  ];
  var innerWindowTilesList = [
    [ INNER_WINDOWH1, INNER_WINDOWH2, INNER_WINDOWH3 ],
    [ INNER_WINDOWV1, INNER_WINDOWV2, INNER_WINDOWV3 ],
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
// make windows
  function makeWindows(state: _CorpState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      for (room in state.rooms)
        {
          // clear room to default tile
          drawBlock(cells, room.x1, room.y1, room.w, room.h, BLDG_ROOM);
          var corners = getRoomWallCorners(room);
//          trace(room + ' ' + corners);
          // loop all corners drawing a line
          for (spot in corners)
            {
              var innerWall = false;
              var delta = deltaMap[spot.dir];
              var delta90 = deltaMap[spot.dir90];
              if (cells[spot.x + delta.x][spot.y + delta.y] != BLDG_WALL)
                innerWall = true;

              // pick correct window tiles list
              var windowTiles = null;
              var tableTilesList = table1TilesList;
              // only upper horizontal tables can have drawers
              if (spot.dir == DIR_RIGHT &&
                  spot.dir90 == DIR_DOWN &&
                  Std.random(100) < 50)
                tableTilesList = table2TilesList;
              var tableTiles = null;
              var windowIdx = 0;
              if (spot.dir == DIR_RIGHT)
                windowIdx = 0;
              else if (spot.dir == DIR_DOWN)
                windowIdx = 1;
              windowTiles = (innerWall ? innerWindowTilesList[windowIdx] : windowTilesList[windowIdx]);
              tableTiles = tableTilesList[windowIdx];

              // paint window and table near it
              var newWindow = true;
              var hasWindow = true;
              var tablelen = 0;
              var cnt = 0;
              var x = spot.x, y = spot.y;
              var tx = 0, ty = 0; // table x,y
              var noTable = false;
              // inner walls are often windows
              if (cells[x + delta.x][y + delta.y] == BLDG_INNER_WALL &&
                  Std.random(100) < 70)
                hasWindow = false;
              while (true)
                {
                  x += delta.x;
                  y += delta.y;
                  if (x < 0 || y < 0 || x >= state.area.width || y >= state.area.height)
                    break;
                  tx = x + delta90.x;
                  ty = y + delta90.y;
                  // leave door alone
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
/*
                  // skip first vertical table
                  if (spot.dir == DIR_DOWN && (cnt == 0))// || !noWindow))
                    continue;
                  // already table or decoration there
                  if (cells[tx][ty] != BLDG_ROOM)
                    continue;
                  if (noTable)
                    {
                      // no table - add floor decoration
                      if (!nextTo(cells, tx, ty, BLDG_INNER_DOOR) &&
                          !area.hasObjectAt(tx, ty))
                        {
                          if (Std.random(100) < 70)
                            {
                              var arr = (Std.random(100) < 50 ?
                                Const.CHEM_LABS_DECO_FLOOR_HIGH :
                                Const.CHEM_LABS_DECO_FLOOR_LOW);
                              var nextToWindow = nextToWindow(cells, tx, ty);
                              if (nextToWindow)
                                arr = Const.CHEM_LABS_DECO_FLOOR_LOW;
                              // leave space for
                              if (nextToWindow && Std.random(100) < 70)
                                hasVentSpace = true;
                              else
                                {
                                  addDecoration(tx, ty, arr);
                                  // change to unwalkable tile
                                  cells[tx][ty] =
                                    Const.TILE_FLOOR_TILE_UNWALKABLE;
                                }
                            }
                        }
                    }
                  else
                    {
                      // add next table tile
                      if (cells[tx][ty] == BLDG_ROOM)
                        {
                          cells[tx][ty] = tableTiles[tablelen];
                          tablelen++;
                        }
                      // add table decoration
                      // NOTE: corner tile always has decoration
                      // so that we cannot spawn clues there
                      // because of the clue activation range cross
                      if (Std.random(100) < 70 ||
                          (tx == room.x1 && ty == room.y1) ||
                          (tx == room.x2 && ty == room.y1) ||
                          (tx == room.x1 && ty == room.y2) ||
                          (tx == room.x2 && ty == room.y2))
                        addDecoration(tx, ty,
                          Const.CHEM_LABS_DECO_TABLE);
                    }
*/
                }
              // fix last cell if necessary
              x -= delta.x;
              y -= delta.y;
              // cannot use switch here
              if (cells[x][y] == BLDG_WINDOWH2)
                cells[x][y] = BLDG_WINDOWH3;
              else if (cells[x][y] == BLDG_WINDOWH1)
                cells[x][y] = BLDG_WINDOW;
              else if (cells[x][y] == BLDG_WINDOWV2)
                cells[x][y] = BLDG_WINDOWV3;
              else if (cells[x][y] == BLDG_WINDOWV1)
                cells[x][y] = BLDG_WINDOW;
              else if (cells[x][y] == INNER_WINDOWH2)
                cells[x][y] = INNER_WINDOWH3;
              else if (cells[x][y] == INNER_WINDOWH1)
                cells[x][y] = INNER_WINDOW;
              else if (cells[x][y] == INNER_WINDOWV2)
                cells[x][y] = INNER_WINDOWV3;
              else if (cells[x][y] == INNER_WINDOWV1)
                cells[x][y] = INNER_WINDOW;
            }
        }
    }

// make this room a solo office
  function roomSolo(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, MARBLE1);

      // tables in the center if there's room
      if (room.w >= 6 && room.h >= 6)
        soloTable(room);

      // decorate room near walls
      if (room.w >= 7)
        decorateCorners(room, [
            Const.CORP_TABLE_COFFEE,
            Const.CORP_TABLE_ROUTER,
          ], [
            Const.CORP_COOLER,
            Const.CORP_PLANT,
          ],
          Const.TILE_DARK_TABLE_MARBLE1_1X1,
          Const.TILE_FLOOR_MARBLE1 + 16,
          20);
    }

// solo: single 2x3 table near the n/s wall
  function soloTable(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var decorationFull = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_LAMP,
        Const.CORP_TABLE_FILES,
        Const.CORP_TABLE_STATIONERY,
      ];
      var decoration = decorationFull.copy();

      // find if there's any n/s door
      var hasNorthDoor = false, hasSouthDoor = false;
      for (door in state.doors)
        if (door.roomID1 == room.id ||
            door.roomID2 == room.id)
          {
            if (door.y == room.y1 - 1)
              hasNorthDoor = true;
            if (door.y == room.y2 + 1)
              hasSouthDoor = true;
          }
      // both doors, nowhere to put table
      if (hasNorthDoor && hasSouthDoor)
        return;

      var tx = room.x1 + Std.int(room.w / 2) - 1;
      var ty = room.y1 + 1;
      var cx = tx + 1, cy = ty - 1;
      var compx = cx, compy = ty;
      if (hasNorthDoor)
        {
          ty = room.y2 - 2;
          cy = ty + 2;
          compy = ty + 1;
        }
      // chair
      var o = new Decoration(game, state.area.id,
        cx, cy, Const.CORP_CHAIR[0].row, 1);
      state.area.addObject(o);
      // computer
      addDecoration(compx, compy, Const.CORP_COMPUTERS);

      // other decoration
      var decorationAmount = decorationFull.length;
      for (dy in 0...2)
        for (dx in 0...3)
          {
            cells[tx + dx][ty + dy] =
              Const.DARK_TABLE_MARBLE1_3X2[dy][dx];
            if (tx + dx == compx && ty + dy == compy)
              continue;
            // 1 decoration item per table per group
            if (Std.random(100) < 40 &&
                decorationAmount > 0)
              {
                decoration = addDecorationExt(
                  tx + dx, ty + dy, decoration,
                  decorationFull);
                decorationAmount--;
              }
          }
    }

// decorate room corners
  function decorateCorners(room: _Room,
      decorationFull: Array<_TileGroup>,
      decorationBigFull: Array<_TileGroup>,
      decorationFloorID: Int,
      decorationBigFloorID: Int,
      tableDecorationChance: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // decoration on a small table
      var decoration = decorationFull.copy();
      var decorationBig = decorationBigFull.copy();
      var corners = [
        { x: room.x1, y: room.y1 },
        { x: room.x2, y: room.y1 },
        { x: room.x1, y: room.y2 },
        { x: room.x2, y: room.y2 },
      ];
      for (c in corners)
        {
          // on table
          if (Std.random(100) < tableDecorationChance)
            {
              cells[c.x][c.y] = decorationFloorID;
              decoration = addDecorationExt(
                c.x, c.y, decoration,
                decorationFull);
            }
          // full height
          else 
            {
              cells[c.x][c.y] = decorationBigFloorID;
              decorationBig = addDecorationExt(
                c.x, c.y, decorationBig,
                decorationBigFull); 
            }
        }
    }

// decorate near walls
  function decorateWalls(room: _Room,
      decorationFull: Array<_TileGroup>,
      decorationBigFull: Array<_TileGroup>,
      decorationFloorID: Int,
      decorationBigFloorID: Int,
      decorationChance: Int,
      tableDecorationChance: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // decoration near wall on the small table
      var decoration = decorationFull.copy();
      var decorationBig = decorationBigFull.copy();
      var prevLeft = false, prevRight = false;
      for (y in room.y1...room.y2 + 1)
        {
          var isCorner = (y == room.y1 || y == room.y2);
          // left side
          var hasLeft = (Std.random(100) < decorationChance);
          if (cells[room.x1 - 1][y] == BLDG_INNER_DOOR)
            hasLeft = false;
          if (prevLeft)
            {
              hasLeft = false;
              prevLeft = false;
            }
          if (hasLeft || isCorner)
            {
              prevLeft = true;
              // on table
              if (Std.random(100) < tableDecorationChance)
                {
                  cells[room.x1][y] = decorationFloorID;
                  decoration = addDecorationExt(
                    room.x1, y, decoration,
                    decorationFull);
                }
              // full height
              else 
                {
                  cells[room.x1][y] = decorationBigFloorID;
                  decorationBig = addDecorationExt(
                    room.x1, y, decorationBig,
                    decorationBigFull); 
                }
            }

          // right side
          var hasRight = (Std.random(100) < decorationChance);
          if (cells[room.x2 + 1][y] == BLDG_INNER_DOOR)
            hasRight = false;
          if (prevRight)
            {
              hasRight = false;
              prevRight = false;
            }
          if (hasRight || isCorner)
            {
              prevRight = true;
              // on table
              if (Std.random(100) < tableDecorationChance)
                {
                  cells[room.x2][y] = decorationFloorID;
                  decoration = addDecorationExt(
                    room.x2, y, decoration,
                    decorationFull);
                }
              // full height
              else
                {
                  cells[room.x2][y] = decorationBigFloorID;
                  decorationBig = addDecorationExt(
                    room.x2, y, decorationBig,
                    decorationBigFull); 
                }
            }
        }
    }

// make this room a meeting room
  function roomMeeting(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CARPET);

      // tables in the center if there's room
      if (room.w >= 6 && room.h >= 6)
        meetingTable(room);

      // decorate room near walls
      decorateWalls(room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_PHONE,
          Const.CORP_TABLE_PROJECTOR,
          Const.CORP_TABLE_ROUTER,
        ], [
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
          Const.CORP_WHITEBOARD,
        ],
        Const.TILE_DARK_TABLE_CARPET_1X1,
        Const.TILE_FLOOR_CARPET + 16,
      50, 20);
    }

// meeting: single long table in the center
  function meetingTable(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var decorationFull = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_PROJECTOR,
      ];
      var decoration = decorationFull.copy();

      var tx = room.x1 + 2, ty = room.y1 + 2;
      var tw = room.w - 4, th = room.h - 4;
      var decorationAmount = decorationFull.length;
      for (dy in 0...th)
        for (dx in 0...tw)
          {
            // convert table x,y to tile x,y
            var tilex = tx, tiley = ty;
            if (dy == 0)
              tiley = 0;
            else if (dy == th - 1)
              tiley = 2;
            else tiley = 1;
            if (dx == 0)
              tilex = 0;
            else if (dx == tw - 1)
              tilex = 2;
            else tilex = 1;

            cells[tx + dx][ty + dy] =
              Const.DARK_TABLE_CARPET_3X3[tiley][tilex];
            // 1 decoration item per table per group
            if (Std.random(100) < 20 && decorationAmount > 0)
              {
                decoration = addDecorationExt(
                  tx + dx, ty + dy, decoration,
                  decorationFull);
                decorationAmount--;
              }
          }
    }

// make this room a small kitchen
  function roomKitchen(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD1);

      // tables in the center if there's room
      if (room.w >= 6 && room.h >= 6)
        kitchenTables(room);

      // decorate room near walls
      decorateWalls(room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_CLEANING,
          Const.CORP_TABLE_BLENDER,
          Const.CORP_TABLE_KETTLE,
          Const.CORP_TABLE_MICROWAVE,
          Const.CORP_TABLE_TOILET_PAPER,
          Const.CORP_TABLE_CONTAINER,
        ], [
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
          Const.CORP_VENDING,
          Const.CORP_FRIDGE,
          Const.CORP_TAP,
        ],
        Const.TILE_LIGHT_TABLE_WOOD1_1X1,
        Const.TILE_FLOOR_WOOD1 + 16,
      50, 20);
    }

// kitchen: a column of tables in the center
  function kitchenTables(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var tx = room.x1 + Std.int(room.w / 2) - 1;
      var cnt = -1;
      var decorationFull = [
        Const.CORP_TABLE_TISSUE,
        Const.CORP_TABLE_SAUCES,
        Const.CORP_TABLE_SALT,
        Const.CORP_TABLE_MUG,
        Const.CORP_TABLE_FRUIT,
      ];

      var decoration = decorationFull.copy();
      // loop in cols adding 2x2 tables
      while (true)
        {
          cnt++;
          if (cnt > 100)
            break;

          var ty = cnt * 3 + room.y1 + 2; 
          if (ty + 2 >= room.y2)
            break;
          for (dy in 0...2)
            for (dx in 0...2)
              {
                cells[tx + dx][ty + dy] =
                  Const.LIGHT_TABLE_WOOD1_2X2[dy][dx];
                if (Std.random(100) < 30)
                  decoration = addDecorationExt(
                    tx + dx, ty + dy, decoration,
                    decorationFull);
              }
        }
    }

// make this room an office
  function roomWork(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD2);
      var block = Const.CORP_TABLE_3X1;
      var tableW = 3, tableH = 1;
      // fill room with tables
      var sx = 0, sy = 0, ry = 0;
      var lastx = 0;
      var cnt = 0;
      var effectiveWidth = room.w - 4;
      var cols = Std.int(effectiveWidth / 4);
      if (effectiveWidth == 7)
        cols = 2;
      else if (effectiveWidth == 3)
        cols = 1;
      var col = 0;
      var xstep = Std.int(effectiveWidth / cols);
      if (effectiveWidth == 7)
        xstep = 4;
//      trace(room + ' effWidth:' + effectiveWidth + ', cols:' + cols);

      // find if there is a south door
      var hasSouthDoor = false;
      for (door in state.doors)
        if (door.roomID1 == room.id || door.roomID2 == room.id)
          {
            if (door.y == room.y2 + 1)
              {
                hasSouthDoor = true;
                break;
              }
          }
      // one chair/computer for all tables
      var chairID = Std.random(Const.CORP_CHAIR[0].amount);
      var computerID = 
        Std.random(Const.CORP_COMPUTERS_BLOCK.width);

      // loop in rows, cols adding tables
      while (true)
        {
          cnt++;
          if (cnt > 100)
            break;
          // pick new spot
          sx = room.x1 + 2 + (col * xstep);
          if (cols == 1) // center
            sx = room.x1 + Std.int(room.w / 2) - 1;
          sy = room.y1 + 1 + (tableH + 1) * ry;
          if (sx + tableW >= room.x2)
            {
              ry++;
              col = 0;
              continue;
            }
          col++;
          if (cols == 1)
            ry++;
          if (sy + tableH > room.y2 - (hasSouthDoor ? 1 : 0))
            break;

          // put tables
          var decorationFull = [
            Const.CORP_TABLE_MISC,
            Const.CORP_TABLE_LAMP,
            Const.CORP_TABLE_PLANTS,
            Const.CORP_TABLE_PHONE,
            Const.CORP_TABLE_FILES,
            Const.CORP_TABLE_STATIONERY,
          ];
          var decoration = decorationFull.copy();
          for (i in 0...block.length)
            {
              cells[sx + i][sy] = block[i];
              if (i == 1)
                {
                  // computer
                  var o = new Decoration(game,
                    state.area.id,
                    sx + i, sy,
                    Const.CORP_COMPUTERS_BLOCK.row,
                    Const.CORP_COMPUTERS_BLOCK.col +
                    computerID);
                  state.area.addObject(o);
                }
              else if (Std.random(100) < 50)
                decoration = addDecorationExt(sx + i, sy, decoration, decorationFull);
            }

          var o = new Decoration(game, state.area.id,
            sx + 1, sy + 1,
            Const.CORP_CHAIR[0].row, chairID);
          state.area.addObject(o);
          lastx = sx + 3;
        }
//      trace(room, lastx);

      // decorate room near walls
      decorateWorkWalls(room);
    }

// decorate work room near walls
  function decorateWorkWalls(room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      // decoration near wall on a small table
      var decorationFull = [
        Const.CORP_TABLE_COFFEE,
        Const.CORP_TABLE_PRINTER,
        Const.CORP_TABLE_PROJECTOR,
        Const.CORP_TABLE_ROUTER,
        Const.CORP_TABLE_MISC_LARGE,
      ];
      var decoration = decorationFull.copy();
      var decorationBigFull = [
        Const.CORP_WHITEBOARD,
        Const.CORP_COOLER,
        Const.CORP_PLANT,
        Const.CORP_CABINET,
        Const.CORP_TRASH,
        Const.CORP_MACHINERY,
      ];
      var decorationBig = decorationBigFull.copy();
      var prevLeft = false, prevRight = false;
      for (y in room.y1...room.y2 + 1)
        {
          var isCorner = (y == room.y1 || y == room.y2);

          // left side
          var hasLeft = (Std.random(100) < 40);
          if (cells[room.x1 - 1][y] == BLDG_INNER_DOOR)
            hasLeft = false;
          if (prevLeft)
            {
              hasLeft = false;
              prevLeft = false;
            }
          if (hasLeft || isCorner)
            {
              prevLeft = true;
              // on table
              if (Std.random(100) < 50)
                {
                  cells[room.x1][y] = Const.TILE_DARK_TABLE_WOOD2_1X1;
                  decoration = addDecorationExt(
                    room.x1, y, decoration,
                    decorationFull);
                }
              // full height
              else 
                {
                  cells[room.x1][y] = Const.TILE_FLOOR_WOOD2 + 16;
                  decorationBig = addDecorationExt(
                    room.x1, y, decorationBig,
                    decorationBigFull); 
                }
            }

          // right side
          var hasRight = (Std.random(100) < 40);
          if (cells[room.x2 + 1][y] == BLDG_INNER_DOOR)
            hasRight = false;
          if (prevRight)
            {
              hasRight = false;
              prevRight = false;
            }
          if (hasRight || isCorner)
            {
              prevRight = true;
              // on table
              if (Std.random(100) < 50)
                {
                  cells[room.x2][y] = Const.TILE_DARK_TABLE_WOOD2_1X1;
                  decoration = addDecorationExt(
                    room.x2, y, decoration,
                    decorationFull);
                }
              // full height
              else
                {
                  cells[room.x2][y] = Const.TILE_FLOOR_WOOD2 + 16;
                  decorationBig = addDecorationExt(
                    room.x2, y, decorationBig,
                    decorationBigFull); 
                }
            }
        }
    }

// add decoration from a list of decoration groups
// except the ones used
// update and return the ones used
// if the array is empty, refill from full
  function addDecorationExt(x: Int, y: Int, groups: Array<_TileGroup>, groupsFull: Array<_TileGroup>): Array<_TileGroup>
    {
      if (groups.length == 0)
        {
          trace('groups empty!');
          return groups;
        }
      var group = groups[Std.random(groups.length)];
      groups.remove(group);
      if (groups.length == 0)
        groups = groupsFull.copy();
      var info = group[Std.random(group.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);
      var o = new Decoration(game, state.area.id,
        x, y, info.row, col);
      state.area.addObject(o);
      return groups;
    }

// add decoration from a list
  function addDecoration(x: Int, y: Int, infos: Array<_TileRow>)
    {
      var info = infos[Std.random(infos.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);
      var o = new Decoration(game, state.area.id,
        x, y, info.row, col);
      state.area.addObject(o);
    }

// check a w,h block at x,y if it is near a door
  function isBlockNearDoor(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int): Bool
    {
      for (i in -1...w + 1)
        for (j in -1...h + 1)
          if (cells[x + i][y + j] == BLDG_INNER_DOOR)
            return true;
      return false;
    }

// check if this cell is next to a window
  function nextToWindow(cells: Array<Array<Int>>,
      x: Int, y: Int): Bool
    {
      var tile = 0;
      for (i in 0...Const.dir4x.length)
        {
          tile = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (tile >= BLDG_WINDOW &&
              tile <= BLDG_WINDOWV3)
            return true;
        }
      return false;
    }

// calc distance from this point to end of the main corridor
  function distanceToFinish(cells: Array<Array<Int>>,
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
          if (cells[x][y] < BLDG_WALL)
            break;
        }
      return len - 1;
    }

// draw a narrow side corridor
  function drawSideCorridor(cells: Array<Array<Int>>,
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
          if (cells[x][y] < BLDG_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              drawChunk(cells, x, y, 2, dir, BLDG_WALL);
              var rnd = Std.random(100);
              if (rnd < 60)
                cells[x][y] = BLDG_WINDOW;
              break;
            }
          drawChunk(cells, x, y, 2, dir, BLDG_CORRIDOR);
        }
    }

// replace all temp tiles into final ones
  function finalizeTiles(state: _CorpState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            // spawn doors
            if (tileID == BLDG_ELEVATOR_DOOR)
              {
                var o = new Door(game, area.id, x, y,
                  Const.ROW_DOORS, Const.FRAME_DOOR_ELEVATOR);
                state.area.addObject(o);
              }
            else if (tileID == BLDG_INNER_DOOR)
              {
                var o = new Door(game, area.id, x, y,
                  Const.ROW_DOORS, Const.FRAME_DOOR_CORP);
                state.area.addObject(o);
              }
            // spawn vent object
            else if (tileID == BLDG_VENT)
              {
                var o = new Vent(game, area.id, x, y);
                state.area.addObject(o);
              }
            // randomize greenery
            else if (tileID == GRASS)
              {
                var rnd = Std.random(100);
                // trees
                if (rnd < 10)
                  cells[x][y] = Const.TILE_TREE1 +
                    Std.random(Const.TILE_BUSH - Const.TILE_TREE1);
                else if (rnd < 40)
                  cells[x][y] = Const.TILE_BUSH;
                else cells[x][y] = Const.TILE_GRASS;
                continue;
              }

            //if (tileID >= Const.OFFSET_ROW8)
            if (tileID >= Const.OFFSET_CHEM_LAB)
              continue;
/*
            if (tileID >= BLDG_ROOM_ID_START)
              tileID = Const.TILE_FLOOR_TILE;*/
            else tileID = finalTiles[tileID];

            cells[x][y] = tileID;
          }
    }

// get room by id
  function getRoomByID(id: Int): _Room
    {
      for (room in state.rooms)
        if (room.id == id)
          return room;
      return null;
    }

  static var finalTiles: Map<Int, Int>;

  static var ROOM_SIZE = 10; // 9 + 1 wall
  static var ROAD = 0;
  static var WALKWAY = 1;
  static var ALLEY = 2;
  static var GRASS = 3;
  static var CONCRETE = 4;
  // first building tile!
  static var BLDG_WALL = 10;
  static var BLDG_ROOM = 11;
  static var BLDG_CORRIDOR = 12;
  static var BLDG_ELEVATOR_DOOR = 13;
//  static var BLDG_SIDE_DOOR = 14;
  static var BLDG_INNER_WALL = 15;
  static var BLDG_ROOM_MARKED = 16;
  static var BLDG_INNER_DOOR = 17;
  static var BLDG_WINDOW = 18;
  static var BLDG_WINDOWH1 = 19;
  static var BLDG_WINDOWH2 = 20;
  static var BLDG_WINDOWH3 = 21;
  static var BLDG_WINDOWV1 = 22;
  static var BLDG_WINDOWV2 = 23;
  static var BLDG_WINDOWV3 = 24;
  static var BLDG_TABLE = 25;
  static var BLDG_VENT = 26;
  static var INNER_WINDOW = 27;
  static var INNER_WINDOWH1 = 28;
  static var INNER_WINDOWH2 = 29;
  static var INNER_WINDOWH3 = 30;
  static var INNER_WINDOWV1 = 31;
  static var INNER_WINDOWV2 = 32;
  static var INNER_WINDOWV3 = 33;
  static var CARPET = 34;
  static var WOOD1 = 35;
  static var WOOD2 = 36;
  static var MARBLE1 = 37;
  static var MARBLE2 = 38;

  static var BLDG_ROOM_ID_START = 100;
  static var mapTempTiles = [
    // 0
    '0', '1', '2', '%', '%', '%', '%', '%', '%', '%',
    // 10
    '#', 'r', '.', 'x', '+', '*', '8', 'X', 'w', 
    // 19
    '<', '-', '>', '^', '|', 'v', '_', 'Y', 'W',
    // 28
    'a', 'b', 'c', 'A', 'B', 'C', '_', '_', '_',
    // 37
    '_', '_', '_', '_', '_', '_', 'r', 'r', 'r',
  ];
}

typedef _CorpState = {
  var area: AreaGame;
  var info: AreaInfo;

  // temp state
  var rooms: Array<_Room>;
  var doors: Array<_Door>;
}

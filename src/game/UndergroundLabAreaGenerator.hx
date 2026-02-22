// underground laboratory mission area generation

package game;

import Const;
import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import objects.Elevator;
import objects.FloorDrain;
import objects.Stairs;

class UndergroundLabAreaGenerator
{
  static var TILE_WALL = Const.TILE_BUILDING;
  static var TILE_ROOM = Const.TILE_FLOOR_TILE;
  static var TILE_CORRIDOR = Const.TILE_FLOOR_LINO;
  static var TILE_ENTRY = Const.TILE_FLOOR_CONCRETE;

  var game: Game;
  var gen: AreaGenerator;

// store references to game and shared area generator
  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
    }

// generate compact underground lab area with mission exits
  public function generate(area: AreaGame, info: AreaInfo)
    {
      // fill map with walls first
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, TILE_WALL);

      var rooms = [];
      var roomID = 0;

      // entry room on the left
      var entryRoom = makeRoom(area, rooms, roomID++, 6,
        Std.int(area.height / 2) - 4, 8, 8, TILE_ROOM);

      // primary vat chamber on the right
      var vatW = 14;
      var vatH = 16;
      var vatX = area.width - vatW - 6;
      var vatY = Std.int(area.height / 2) - Std.int(vatH / 2);
      var vatRoom = makeRoom(area, rooms, roomID++,
        vatX, vatY, vatW, vatH, TILE_ROOM);

      // top service room connected to the central hall
      var topRoom = makeRoom(area, rooms, roomID++,
        entryRoom.x2 + 3, entryRoom.y1 - 7,
        10, 5, TILE_ROOM);

      // bottom service room connected to the central hall
      var bottomRoom = makeRoom(area, rooms, roomID++,
        entryRoom.x2 + 3, entryRoom.y2 + 3,
        10, 5, TILE_ROOM);

      // central corridor to vat room entry
      var corridorY = Std.int(area.height / 2) - 1;
      carveRect(area, entryRoom.x2 - 1, corridorY,
        vatRoom.x1 - entryRoom.x2 + 2, 2, TILE_CORRIDOR);

      // short side corridors for service rooms
      carveRect(area, topRoom.x1 + Std.int(topRoom.w / 2),
        topRoom.y2, 2, corridorY - topRoom.y2 + 1, TILE_CORRIDOR);
      carveRect(area, bottomRoom.x1 + Std.int(bottomRoom.w / 2),
        corridorY + 1, 2, bottomRoom.y1 - corridorY, TILE_CORRIDOR);

      // narrow doorway into the vat chamber
      carveRect(area, vatRoom.x1 - 1, corridorY, 2, 2, TILE_CORRIDOR);

      // elevator bay in the entry room (corp style 3x3 slab)
      var elevatorX = entryRoom.x1 + 1;
      var elevatorY = entryRoom.y1 + 1;
      carveRect(area, elevatorX, elevatorY, 3, 3, TILE_ENTRY);
      for (dy in 0...3)
        for (dx in 0...3)
          area.addObject(new Elevator(game, area.id, elevatorX + dx, elevatorY + dy));

      // stairs exit in the entry room
      var stairsX = entryRoom.x2 - 1;
      var stairsY = entryRoom.y2 - 1;
      area.addObject(new Stairs(game, area.id, stairsX, stairsY));

      // add research-themed decoration and furniture
      decorateLab(area, entryRoom, topRoom, bottomRoom, vatRoom,
        elevatorX, elevatorY, stairsX, stairsY);

      area.generatorInfo = {
        rooms: rooms,
        doors: [],
      };
    }

// carve a room and append it to generator room list
  function makeRoom(area: AreaGame, rooms: Array<_Room>, roomID: Int,
      x1: Int, y1: Int, w: Int, h: Int, tile: Int): _Room
    {
      carveRect(area, x1, y1, w, h, tile);
      var room: _Room = {
        id: roomID,
        x1: x1,
        y1: y1,
        x2: x1 + w - 1,
        y2: y1 + h - 1,
        w: w,
        h: h,
      };
      rooms.push(room);
      return room;
    }

// carve rectangular floor patch safely within bounds
  function carveRect(area: AreaGame, x1: Int, y1: Int,
      w: Int, h: Int, tile: Int)
    {
      var x2 = x1 + w;
      var y2 = y1 + h;
      for (y in y1...y2)
        for (x in x1...x2)
          {
            if (x < 1 ||
                y < 1 ||
                x >= area.width - 1 ||
                y >= area.height - 1)
              continue;
            area.setCellType(x, y, tile);
          }
    }

// add facility-style chemistry decoration to rooms
  function decorateLab(area: AreaGame,
      entryRoom: _Room,
      topRoom: _Room,
      bottomRoom: _Room,
      vatRoom: _Room,
      elevatorX: Int,
      elevatorY: Int,
      stairsX: Int,
      stairsY: Int)
    {
      decorateChemRoom(area, topRoom, null, false);
      decorateChemRoom(area, bottomRoom, null, false);

      decorateChemRoom(area, entryRoom, function(x: Int, y: Int)
        {
          if (x >= elevatorX &&
              x <= elevatorX + 2 &&
              y >= elevatorY &&
              y <= elevatorY + 2)
            return true;
          if (Math.abs(x - stairsX) <= 1 &&
              Math.abs(y - stairsY) <= 1)
            return true;
          return false;
        }, false);

      var vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      var vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
      decorateChemRoom(area, vatRoom, function(x: Int, y: Int)
        {
          return (Math.abs(x - vatCenterX) <= 3 &&
            Math.abs(y - vatCenterY) <= 3);
        }, true);
    }

// decorate one room using chemistry lab style
  function decorateChemRoom(area: AreaGame, room: _Room,
      blocked: Int -> Int -> Bool, skipCenterTable: Bool)
    {
      placeRoomDrain(area, room, blocked);
      decorateNearWalls(area, room, blocked);
      if (!skipCenterTable)
        placeCenterTable(area, room, blocked);
    }

// place a random grate/drain in a room
  function placeRoomDrain(area: AreaGame, room: _Room, blocked: Int -> Int -> Bool)
    {
      if (room.w < 3 ||
          room.h < 3)
        return;

      var attempts = 0;
      while (attempts < 20)
        {
          attempts++;
          var x = room.x1 + 1 + Std.random(room.w - 2);
          var y = room.y1 + 1 + Std.random(room.h - 2);
          if (!canDecorateCell(area, x, y, blocked))
            continue;

          area.setCellType(x, y, Const.TILE_FLOOR_TILE + 1 + Std.random(3));
          if (Std.random(100) < 30)
            area.addObject(new FloorDrain(game, area.id, x, y));
          return;
        }
    }

// place floor decoration around room walls
  function decorateNearWalls(area: AreaGame, room: _Room, blocked: Int -> Int -> Bool)
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            var nearWall =
              (x <= room.x1 + 1 ||
               x >= room.x2 - 1 ||
               y <= room.y1 + 1 ||
               y >= room.y2 - 1);
            if (!nearWall ||
                Std.random(100) >= 40 ||
                !canDecorateCell(area, x, y, blocked))
              continue;

            if (Std.random(100) < 50)
              gen.addDecoration(area, x, y, Const.CHEM_LABS_DECO_FLOOR_LOW);
            else
              gen.addDecoration(area, x, y, Const.CHEM_LABS_DECO_FLOOR_HIGH);
          }
    }

// place a center lab table block with tabletop decoration
  function placeCenterTable(area: AreaGame, room: _Room, blocked: Int -> Int -> Bool)
    {
      if (room.w < 7 ||
          room.h < 7)
        return;

      var block = (Std.random(100) < 50 ? Const.LABS_TABLE_3X2 : Const.LABS_TABLE_2X3);
      var tableW = block[0].length;
      var tableH = block.length;

      var sx = room.x1 + Std.int((room.w - tableW) / 2);
      var sy = room.y1 + Std.int((room.h - tableH) / 2);
      if (room.w - tableW >= 4)
        sx += Std.random(3) - 1;
      if (room.h - tableH >= 4)
        sy += Std.random(3) - 1;

      sx = Const.clamp(sx, room.x1 + 2, room.x2 - tableW - 1);
      sy = Const.clamp(sy, room.y1 + 2, room.y2 - tableH - 1);

      for (i in 0...tableH)
        for (j in 0...tableW)
          {
            var x = sx + j;
            var y = sy + i;
            if (!canDecorateCell(area, x, y, blocked))
              return;
          }

      for (i in 0...tableH)
        for (j in 0...tableW)
          {
            var x = sx + j;
            var y = sy + i;
            area.setCellType(x, y, block[i][j]);
            if (Std.random(100) < 70)
              gen.addDecoration(area, x, y, Const.CHEM_LABS_DECO_TABLE);
          }
    }

// check if a tile can receive room decoration
  function canDecorateCell(area: AreaGame, x: Int, y: Int,
      blocked: Int -> Int -> Bool): Bool
    {
      if (x < 1 ||
          y < 1 ||
          x >= area.width - 1 ||
          y >= area.height - 1)
        return false;
      if (area.hasObjectAt(x, y))
        return false;
      if (blocked != null &&
          blocked(x, y))
        return false;
      var tile = area.getCellType(x, y);
      return tile == TILE_ROOM;
    }
}

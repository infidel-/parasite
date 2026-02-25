// underground laboratory mission area generation

package game;

import Const;
import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import objects.Elevator;
import objects.FloorDrain;
import objects.Stairs;
import tiles.UndergroundLab;

class UndergroundLabAreaGenerator
{
  static var TEMP_VOID = 0;
  static var TEMP_ROOM = 1;
  static var TEMP_CORRIDOR = 2;
  static var TEMP_ENTRY = 3;

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
      // fill map with void first
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, TEMP_VOID);

      var rooms = [];
      var roomID = 0;

      // entry room on the left
      var entryRoom = makeRoom(area, rooms, roomID++, 6,
        Std.int(area.height / 2) - 4, 8, 8, TEMP_ROOM);

      // primary vat chamber on the right
      var vatW = 14;
      var vatH = 16;
      var vatX = area.width - vatW - 6;
      var vatY = Std.int(area.height / 2) - Std.int(vatH / 2);
      var vatRoom = makeRoom(area, rooms, roomID++,
        vatX, vatY, vatW, vatH, TEMP_ROOM);

      // top service room connected to the central hall
      var topRoom = makeRoom(area, rooms, roomID++,
        entryRoom.x2 + 3, entryRoom.y1 - 7,
        10, 5, TEMP_ROOM);

      // bottom service room connected to the central hall
      var bottomRoom = makeRoom(area, rooms, roomID++,
        entryRoom.x2 + 3, entryRoom.y2 + 3,
        10, 5, TEMP_ROOM);

      // central corridor to vat room entry
      var corridorY = Std.int(area.height / 2) - 1;
      carveRect(area, entryRoom.x2 - 1, corridorY,
        vatRoom.x1 - entryRoom.x2 + 2, 2, TEMP_CORRIDOR);

      // short side corridors for service rooms
      carveRect(area, topRoom.x1 + Std.int(topRoom.w / 2),
        topRoom.y2, 2, corridorY - topRoom.y2 + 1, TEMP_CORRIDOR);
      carveRect(area, bottomRoom.x1 + Std.int(bottomRoom.w / 2),
        corridorY + 1, 2, bottomRoom.y1 - corridorY, TEMP_CORRIDOR);

      // narrow doorway into the vat chamber
      carveRect(area, vatRoom.x1 - 1, corridorY, 2, 2, TEMP_CORRIDOR);

      // elevator bay in the entry room (corp style 3x3 slab)
      var elevatorX = entryRoom.x1 + 1;
      var elevatorY = entryRoom.y1 + 1;
      carveRect(area, elevatorX, elevatorY, 3, 3, TEMP_ENTRY);
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
      // convert temp markers to final floor and wall tiles
      finalizeTiles(area);
      // add wall decoration metadata for rendering layers
      decorateWalls(area);

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
      decorateChemRoom(area, topRoom, null);
      decorateChemRoom(area, bottomRoom, null);

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
        });

      var vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      var vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
      decorateChemRoom(area, vatRoom, function(x: Int, y: Int)
        {
          return (Math.abs(x - vatCenterX) <= 3 &&
            Math.abs(y - vatCenterY) <= 3);
        });
    }

// decorate one room using chemistry lab style
  function decorateChemRoom(area: AreaGame, room: _Room,
      blocked: Int -> Int -> Bool)
    {
      placeRoomDrain(area, room, blocked);
      decorateNearWalls(area, room, blocked);
    }

// place a random floor drain in a room
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
      return tile == TEMP_ROOM;
    }

// place wall decoration metadata for wall tiles
  function decorateWalls(area: AreaGame)
    {
      var tileset = game.scene.images.getTileset(area.typeID);
      area.initTilesFromCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          tileset.decorateWallTile(area, x, y);
    }

// convert temporary room/corridor map to final floor and wall tiles
  function finalizeTiles(area: AreaGame)
    {
      var floorMap: Array<Array<Bool>> = [];
      for (x in 0...area.width)
        {
          floorMap[x] = [];
          for (y in 0...area.height)
            floorMap[x][y] = isFloorMarker(area.getCellType(x, y));
        }

      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (floorMap[x][y])
              {
                area.setCellType(x, y, getFloorTileID(x, y));
                continue;
              }
            if (isWallShell(floorMap, x, y))
              area.setCellType(x, y, getWallTileID(floorMap, x, y));
            else
              {
                var tileID = getDiagonalCornerTileID(floorMap, x, y);
                if (tileID == Const.TILE_HIDDEN)
                  area.setCellType(x, y, Const.TILE_HIDDEN);
                else area.setCellType(x, y, tileID);
              }
          }
    }

// check whether temporary tile is a floor marker
  inline function isFloorMarker(tile: Int): Bool
    {
      return (tile == TEMP_ROOM ||
        tile == TEMP_CORRIDOR ||
        tile == TEMP_ENTRY);
    }

// pick checkerboard floor tile id
  inline function getFloorTileID(x: Int, y: Int): Int
    {
      if ((x + y) % 2 == 0)
        return UndergroundLab.TILE_FLOOR_LIGHT;
      return UndergroundLab.TILE_FLOOR_DARK;
    }

// check whether this cell should become a wall shell tile
  inline function isWallShell(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (getFloor(floorMap, x, y - 1) ||
        getFloor(floorMap, x, y + 1) ||
        getFloor(floorMap, x - 1, y) ||
        getFloor(floorMap, x + 1, y));
    }

// safely read floor map
  inline function getFloor(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= floorMap.length ||
          y >= floorMap[x].length)
        return false;
      return floorMap[x][y];
    }

// map wall shell shape to a wall tile id
  function getWallTileID(floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);

      // inner corners (looking into floor)
      if (e &&
          s &&
          !n &&
          !w)
        return UndergroundLab.TILE_WALL_INNER_TOP_LEFT;
      if (w &&
          s &&
          !n &&
          !e)
        return UndergroundLab.TILE_WALL_INNER_TOP_RIGHT;
      if (e &&
          n &&
          !s &&
          !w)
        return UndergroundLab.TILE_WALL_INNER_BOTTOM_LEFT;
      if (w &&
          n &&
          !s &&
          !e)
        return UndergroundLab.TILE_WALL_INNER_BOTTOM_RIGHT;

      // outer corners (looking out the floor)
      if (n &&
          w &&
          !s &&
          !e)
        return UndergroundLab.TILE_WALL_OUTER_TOP_LEFT;
      if (n &&
          e &&
          !s &&
          !w)
        return UndergroundLab.TILE_WALL_OUTER_TOP_RIGHT;
      if (s &&
          w &&
          !n &&
          !e)
        return UndergroundLab.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (s &&
          e &&
          !n &&
          !w)
        return UndergroundLab.TILE_WALL_OUTER_BOTTOM_RIGHT;

      // straight wall edges
      if (s && !n)
        return UndergroundLab.TILE_WALL_UPPER;
      if (n && !s)
        return UndergroundLab.TILE_WALL_LOWER;
      if (e && !w)
        return UndergroundLab.TILE_WALL_LEFT;
      if (w && !e)
        return UndergroundLab.TILE_WALL_RIGHT;

      // fallback for complex adjacencies
      if (s)
        return UndergroundLab.TILE_WALL_UPPER;
      if (n)
        return UndergroundLab.TILE_WALL_LOWER;
      if (e)
        return UndergroundLab.TILE_WALL_LEFT;
      if (w)
        return UndergroundLab.TILE_WALL_RIGHT;
      return Const.TILE_HIDDEN;
    }

// map diagonal-only floor adjacency to an outer corner wall tile
  inline function getDiagonalCornerTileID(floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      // keep normal wall-shell handling for orthogonal floor adjacency
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);
      if (n || s || w || e)
        return Const.TILE_HIDDEN;

      var nw = getFloor(floorMap, x - 1, y - 1);
      var ne = getFloor(floorMap, x + 1, y - 1);
      var sw = getFloor(floorMap, x - 1, y + 1);
      var se = getFloor(floorMap, x + 1, y + 1);
      var diagonalFloors = 0;
      if (nw)
        diagonalFloors++;
      if (ne)
        diagonalFloors++;
      if (sw)
        diagonalFloors++;
      if (se)
        diagonalFloors++;
      // only fill single-diagonal void corners to avoid overpainting
      if (diagonalFloors != 1)
        return Const.TILE_HIDDEN;

      if (nw)
        return UndergroundLab.TILE_WALL_OUTER_TOP_LEFT;
      if (ne)
        return UndergroundLab.TILE_WALL_OUTER_TOP_RIGHT;
      if (sw)
        return UndergroundLab.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (se)
        return UndergroundLab.TILE_WALL_OUTER_BOTTOM_RIGHT;
      return Const.TILE_HIDDEN;
    }
}

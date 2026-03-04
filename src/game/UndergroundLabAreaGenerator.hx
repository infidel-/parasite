// underground laboratory mission area generation

package game;

import Const;
import _IconBlock;
import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import objects.Door;
import objects.Elevator;
import tiles.UndergroundLab;

private typedef _MakeRoomArgs = {
  var roomID: Int;
  var x1: Int;
  var y1: Int;
  var w: Int;
  var h: Int;
  var tile: Int;
  @:optional var role: String;
  @:optional var templateID: String;
  @:optional var tags: Array<String>;
}

class UndergroundLabAreaGenerator
{
  static var TEMP_VOID = 0;
  static var TEMP_ROOM = 1;
  static var TEMP_CORRIDOR = 2;
  static var TEMP_ENTRY = 3;
  static var ROOM_ROLE_ENTRANCE = 'entrance';
  static var ROOM_ROLE_VAT = 'vat';
  static var ROOM_ROLE_WORKSHOP = 'workshop';
  static var ROOM_ROLE_STORAGE = 'storage';
  static var RESERVED_KIND_CLONE_VAT = 'clone-vat';

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
      var entryRoom = makeRoom(area, rooms, {
        roomID: roomID++,
        x1: 6,
        y1: Std.int(area.height / 2) - 4,
        w: 8,
        h: 8,
        tile: TEMP_ROOM,
        role: ROOM_ROLE_ENTRANCE,
        templateID: 'entrance-default',
        tags: ['entry', 'elevator'],
      });

      // primary vat chamber on the right
      var vatW = 14;
      var vatH = 16;
      var vatX = area.width - vatW - 6;
      var vatY = Std.int(area.height / 2) - Std.int(vatH / 2);
      var vatRoom = makeRoom(area, rooms, {
        roomID: roomID++,
        x1: vatX,
        y1: vatY,
        w: vatW,
        h: vatH,
        tile: TEMP_ROOM,
        role: ROOM_ROLE_VAT,
        templateID: 'vat-default',
        tags: ['clone', 'critical'],
      });

      var serviceRoomW = 10;
      var serviceRoomH = 5;
      var serviceRoomVatGap = 2;
      var serviceRoomX = vatRoom.x1 - serviceRoomW - serviceRoomVatGap;

      // top service room connected to the central hall
      var topRoom = makeRoom(area, rooms, {
        roomID: roomID++,
        x1: serviceRoomX,
        y1: entryRoom.y1 - 7,
        w: serviceRoomW,
        h: serviceRoomH,
        tile: TEMP_ROOM,
        role: ROOM_ROLE_WORKSHOP,
        templateID: 'service-top-default',
        tags: ['service', 'workshop'],
      });

      // bottom service room connected to the central hall
      var bottomRoom = makeRoom(area, rooms, {
        roomID: roomID++,
        x1: serviceRoomX,
        y1: entryRoom.y2 + 3,
        w: serviceRoomW,
        h: serviceRoomH,
        tile: TEMP_ROOM,
        role: ROOM_ROLE_STORAGE,
        templateID: 'service-bottom-default',
        tags: ['service', 'storage'],
      });

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

      // elevator bay in the entry room
      var elevatorX = entryRoom.x1;
      var elevatorY = entryRoom.y1;
      carveRect(area, elevatorX, elevatorY, 2, 2, TEMP_ENTRY);
      for (dy in 0...2)
        for (dx in 0...2)
          {
            var partIndex = dy * 2 + dx;
            area.addObject(new Elevator(game, area.id, elevatorX + dx, elevatorY + dy,
              -1, partIndex, UndergroundLab.OBJECTS_IMAGE));
          }

      // spawn linked double doors for all room entrances
      spawnDoubleDoorVertical(area, entryRoom.x2 + 1, corridorY);
      spawnDoubleDoorHorizontal(area, topRoom.x1 + Std.int(topRoom.w / 2), topRoom.y2 + 1);
      spawnDoubleDoorHorizontal(area, bottomRoom.x1 + Std.int(bottomRoom.w / 2), bottomRoom.y1 - 1);
      spawnDoubleDoorVertical(area, vatRoom.x1 - 1, corridorY);

      var vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      var vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
      var vatDoorX = vatRoom.x1 - 1;
      var vatDoorY = vatCenterY;
      var vatAnchors = [
        { x: vatCenterX - 2, y: vatCenterY - 3 },
        { x: vatCenterX + 1, y: vatCenterY - 3 },
        { x: vatCenterX - 2, y: vatCenterY + 1 },
        { x: vatCenterX + 1, y: vatCenterY + 1 },
      ];
      var reservedRects = [];
      for (anchor in vatAnchors)
        reservedRects.push({
          x1: anchor.x,
          y1: anchor.y,
          x2: anchor.x + 1,
          y2: anchor.y + 2,
          kind: RESERVED_KIND_CLONE_VAT,
        });

      // convert temp markers to final floor and wall tiles
      finalizeTiles(area);
      // initialize tile metadata and add floor decoration entries
      area.initTilesFromCells();
      decorateFloors(area);
      // add wall decoration metadata for rendering layers
      decorateWalls(area);
      // add near-top wall decoration after base wall pass so it renders on top
      spawnNearTopWallDecorations(area, rooms);
      // add decoration objects as the final decoration pass
      spawnDecorationObj(area, rooms);

      area.generatorInfo = {
        rooms: rooms,
        doors: [],
        missionHints: {
          vatRoomID: vatRoom.id,
          vatDoor: {
            x: vatDoorX,
            y: vatDoorY,
          },
          vatAnchors: vatAnchors,
          reservedRects: reservedRects,
        },
      };
    }

// carve a room and append it to generator room list with optional metadata
  function makeRoom(area: AreaGame, rooms: Array<_Room>,
      args: _MakeRoomArgs): _Room
    {
      carveRect(area, args.x1, args.y1, args.w, args.h, args.tile);
      var room: _Room = {
        id: args.roomID,
        x1: args.x1,
        y1: args.y1,
        x2: args.x1 + args.w - 1,
        y2: args.y1 + args.h - 1,
        w: args.w,
        h: args.h,
      };
      if (args.role != null)
        room.role = args.role;
      if (args.templateID != null)
        room.templateID = args.templateID;
      if (args.tags != null)
        room.tags = args.tags;
      rooms.push(room);
      return room;
    }

// spawn linked vertical two-tile door (upper/lower)
  function spawnDoubleDoorVertical(area: AreaGame, x: Int, yUpper: Int)
    {
      var upperDoor = new Door(game, area.id, x, yUpper,
        UndergroundLab.DOOR_VERTICAL_CLOSED_UPPER,
        UndergroundLab.DOOR_VERTICAL_OPEN_UPPER,
        UndergroundLab.OBJECTS_IMAGE);
      var lowerDoor = new Door(game, area.id, x, yUpper + 1,
        UndergroundLab.DOOR_VERTICAL_CLOSED_LOWER,
        UndergroundLab.DOOR_VERTICAL_OPEN_LOWER,
        UndergroundLab.OBJECTS_IMAGE);
      upperDoor.linkedDoorID = lowerDoor.id;
      lowerDoor.linkedDoorID = upperDoor.id;
      area.addObject(upperDoor);
      area.addObject(lowerDoor);
    }

// spawn linked horizontal two-tile door (left/right)
  function spawnDoubleDoorHorizontal(area: AreaGame, xLeft: Int, y: Int)
    {
      var leftDoor = new Door(game, area.id, xLeft, y,
        UndergroundLab.DOOR_HORIZONTAL_CLOSED_LEFT,
        UndergroundLab.DOOR_HORIZONTAL_OPEN_LEFT,
        UndergroundLab.OBJECTS_IMAGE);
      var rightDoor = new Door(game, area.id, xLeft + 1, y,
        UndergroundLab.DOOR_HORIZONTAL_CLOSED_RIGHT,
        UndergroundLab.DOOR_HORIZONTAL_OPEN_RIGHT,
        UndergroundLab.OBJECTS_IMAGE);
      leftDoor.linkedDoorID = rightDoor.id;
      rightDoor.linkedDoorID = leftDoor.id;
      area.addObject(leftDoor);
      area.addObject(rightDoor);
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

// place wall decoration metadata for wall tiles
  function decorateWalls(area: AreaGame)
    {
      var tileset = game.scene.images.getTileset(area.typeID);
      for (y in 0...area.height)
        for (x in 0...area.width)
          tileset.decorateWallTile(area, x, y);
    }

// spawn near-top wall decorations in each room at 50-80% fill
  function spawnNearTopWallDecorations(area: AreaGame, rooms: Array<_Room>)
    {
      var tileset: UndergroundLab = cast game.scene.images.getTileset(area.typeID);
      for (room in rooms)
        {
          var anchors = collectNearTopWallAnchors(area, room);
          if (anchors.length == 0)
            continue;

          var fillPercent = 50 + Std.random(31);
          var targetCount = Std.int(Math.ceil(anchors.length * fillPercent / 100.0));
          for (_ in 0...targetCount)
            {
              if (anchors.length == 0)
                break;

              var anchorIndex = Std.random(anchors.length);
              var anchor = anchors[anchorIndex];
              anchors.splice(anchorIndex, 1);
              var block = UndergroundLab.NEAR_TOP_WALL[Std.random(UndergroundLab.NEAR_TOP_WALL.length)];

              area.addTileDecoration(anchor.x, anchor.y, {
                layerID: tileset.nearTopWallWallLayerID,
                icon: {
                  row: block.row,
                  col: block.col,
                },
              });
              area.addTileDecoration(anchor.x, anchor.y + 1, {
                layerID: tileset.nearTopWallFloorLayerID,
                icon: {
                  row: block.row + 1,
                  col: block.col,
                },
              });
              area.recalcTile(anchor.x, anchor.y);
              area.recalcTile(anchor.x, anchor.y + 1);
            }
        }
    }

// collect all valid near-top wall anchors for a room
  function collectNearTopWallAnchors(area: AreaGame, room: _Room): Array<{x: Int, y: Int}>
    {
      var anchors = [];
      var tileset = game.scene.images.getTileset(area.typeID);
      var wallY = room.y1 - 1;
      var floorY = room.y1;
      if (wallY < 0 ||
          floorY < 0 ||
          floorY >= area.height)
        return anchors;

      for (x in room.x1...room.x2 + 1)
        {
          var wallTileID = area.getCellType(x, wallY);
          var floorTileID = area.getCellType(x, floorY);
          if (!tileset.isHorizontalWallTile(wallTileID) ||
              !tileset.isWalkable(floorTileID))
            continue;
          if (area.hasObjectAt(x, wallY) ||
              area.hasObjectAt(x, floorY))
            continue;
          anchors.push({
            x: x,
            y: wallY,
          });
        }
      return anchors;
    }

// spawn decoration object blocks on floor with adjacency exclusion
  function spawnDecorationObj(area: AreaGame, rooms: Array<_Room>)
    {
      var tileset: UndergroundLab = cast game.scene.images.getTileset(area.typeID);
      var tiles = area.getTiles();
      var doorRects = getDoorFootprints(area);
      for (room in rooms)
        for (y in room.y1...room.y2 + 1)
          for (x in room.x1...room.x2 + 1)
            {
              if (Std.random(100) >= 30)
                continue;

              var block = UndergroundLab.DECORATION_OBJ[Std.random(UndergroundLab.DECORATION_OBJ.length)];
              if (!canPlaceDecorationObjBlock(area, tileset, tiles, room, x, y, block, doorRects))
                continue;
              var groupTag = 'DECO_OBJ:' + x + ':' + y + ':' + Std.random(1000000);
              for (dy in 0...block.height)
                for (dx in 0...block.width)
                  area.addTileDecoration(x + dx, y + dy, {
                    layerID: tileset.decorationObjFloorLayerID,
                    icon: {
                      row: block.row + dy,
                      col: block.col + dx,
                    },
                    tag: groupTag,
                  });
            }
    }

// check if a decoration object block can be placed at top-left x,y
  function canPlaceDecorationObjBlock(area: AreaGame, tileset: tiles.Tileset,
      tiles: Array<Array<tiles.Tile>>, room: _Room, x: Int, y: Int, block: _IconBlock,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>): Bool
    {
      if (x + block.width - 1 > room.x2 ||
          y + block.height - 1 > room.y2)
        return false;

      for (dy in 0...block.height)
        for (dx in 0...block.width)
          {
            var tx = x + dx;
            var ty = y + dy;
            if (!tileset.isWalkable(area.getCellType(tx, ty)) ||
                area.hasObjectAt(tx, ty) ||
                hasTileDecoration(tiles, tx, ty))
              return false;
          }

      for (ny in y - 1...y + block.height + 1)
        for (nx in x - 1...x + block.width + 1)
          {
            if (nx < 0 ||
                ny < 0 ||
                nx >= area.width ||
                ny >= area.height)
              continue;
            if (nx >= x &&
                nx < x + block.width &&
                ny >= y &&
                ny < y + block.height)
              continue;
            if (area.hasObjectAt(nx, ny))
              return false;
            if (!tileset.isWalkable(area.getCellType(nx, ny)))
              continue;
            if (hasTileDecoration(tiles, nx, ny))
              return false;
          }

      var decorationRect = {
        x1: x,
        y1: y,
        x2: x + block.width - 1,
        y2: y + block.height - 1,
      };
      if (isTooCloseToAnyDoor(decorationRect, doorRects))
        return false;
      return true;
    }

// collect rectangle footprints for all linked and unlinked doors
  function getDoorFootprints(area: AreaGame): Array<{x1: Int, y1: Int, x2: Int, y2: Int}>
    {
      var doorRects = [];
      var processedDoorIDs: Map<Int, Bool> = new Map<Int, Bool>();
      for (o in area.getObjects())
        {
          if (o.type != 'door' ||
              processedDoorIDs[o.id])
            continue;

          var door: Door = cast o;
          var x1 = door.x;
          var y1 = door.y;
          var x2 = door.x;
          var y2 = door.y;
          processedDoorIDs[door.id] = true;

          if (door.linkedDoorID >= 0)
            {
              var linked = area.getObject(door.linkedDoorID);
              if (linked != null &&
                  linked.type == 'door')
                {
                  processedDoorIDs[linked.id] = true;
                  if (linked.x < x1)
                    x1 = linked.x;
                  if (linked.y < y1)
                    y1 = linked.y;
                  if (linked.x > x2)
                    x2 = linked.x;
                  if (linked.y > y2)
                    y2 = linked.y;
                }
            }

          doorRects.push({
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
          });
        }
      return doorRects;
    }

// check whether rectangle is too close to any door footprint
  function isTooCloseToAnyDoor(rect: {x1: Int, y1: Int, x2: Int, y2: Int},
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>): Bool
    {
      for (doorRect in doorRects)
        if (getRectEdgeGapChebyshev(rect, doorRect) < 2)
          return true;
      return false;
    }

// calculate chebyshev gap in tiles between two rectangle edges
  function getRectEdgeGapChebyshev(a: {x1: Int, y1: Int, x2: Int, y2: Int},
      b: {x1: Int, y1: Int, x2: Int, y2: Int}): Int
    {
      var sepX = 0;
      if (a.x2 < b.x1)
        sepX = b.x1 - a.x2 - 1;
      else if (b.x2 < a.x1)
        sepX = a.x1 - b.x2 - 1;

      var sepY = 0;
      if (a.y2 < b.y1)
        sepY = b.y1 - a.y2 - 1;
      else if (b.y2 < a.y1)
        sepY = a.y1 - b.y2 - 1;

      return Std.int(Math.max(sepX, sepY));
    }

// check whether this tile already has decoration metadata entries
  function hasTileDecoration(tiles: Array<Array<tiles.Tile>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= tiles.length ||
          tiles[x] == null ||
          y >= tiles[x].length)
        return false;
      var tile = tiles[x][y];
      return (tile != null &&
        tile.decoration != null &&
        tile.decoration.length > 0);
    }

// place floor decoration metadata for walkable floor tiles
  function decorateFloors(area: AreaGame)
    {
      var tileset = game.scene.images.getTileset(area.typeID);
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = area.getCellType(x, y);
            if (!tileset.isWalkable(tileID) ||
                area.hasObjectAt(x, y) ||
                Std.random(100) >= 10 ||
                hasAdjacentFloorDecoration(area, tiles, x, y))
              continue;

            var tile = tiles[x][y];
            if (tile != null &&
                tile.decoration != null &&
                tile.decoration.length > 0)
              continue;

            tileset.decorateFloor(area, x, y, 0);
          }
    }

// check whether this cell has any adjacent floor decoration
  function hasAdjacentFloorDecoration(area: AreaGame,
      tiles: Array<Array<tiles.Tile>>, x: Int, y: Int): Bool
    {
      for (dy in -1...2)
        for (dx in -1...2)
          {
            if (dx == 0 &&
                dy == 0)
              continue;

            var nx = x + dx;
            var ny = y + dy;
            if (nx < 0 ||
                ny < 0 ||
                nx >= area.width ||
                ny >= area.height)
              continue;

            var tile = tiles[nx][ny];
            if (tile != null &&
                tile.decoration != null &&
                tile.decoration.length > 0)
              return true;
          }
      return false;
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

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

private typedef _RoomTemplate = {
  var templateID: String;
  var role: String;
  var sizeMinW: Int;
  var sizeMaxW: Int;
  var sizeMinH: Int;
  var sizeMaxH: Int;
  var doorMode: String;
  var corridorAttach: String;
  var tags: Array<String>;
}

private typedef _LayoutRoomSpec = {
  var x1: Int;
  var y1: Int;
  var w: Int;
  var h: Int;
  var role: String;
  var templateID: String;
  var tags: Array<String>;
  var doorMode: String;
  var corridorAttach: String;
}

private typedef _LayoutBuildResult = {
  var roomSpecs: Array<_LayoutRoomSpec>;
  var corridorY: Int;
  var entryDoorX: Int;
  var entryDoorY: Int;
  var topDoorX: Int;
  var topDoorY: Int;
  var bottomDoorX: Int;
  var bottomDoorY: Int;
  var vatDoorX: Int;
  var vatDoorY: Int;
  var vatAnchors: Array<_Point>;
  var reservedRects: Array<_ReservedRect>;
}

private typedef _RoleWeight = {
  var role: String;
  var weight: Int;
}

class UndergroundLabAreaGenerator
{
  static var TEMP_VOID = 0;
  static var TEMP_ROOM = 1;
  static var TEMP_CORRIDOR = 2;
  static var TEMP_ENTRY = 3;
  static var MAX_LAYOUT_ATTEMPTS = 30;
  static var ROOM_ROLE_ENTRANCE = 'entrance';
  static var ROOM_ROLE_VAT = 'vat';
  static var ROOM_ROLE_WORKSHOP = 'workshop';
  static var ROOM_ROLE_STORAGE = 'storage';
  static var ROOM_ROLE_RESEARCH = 'research';
  static var DOOR_MODE_LEFT_CENTER = 'left-center';
  static var DOOR_MODE_BOTTOM_CENTER = 'bottom-center';
  static var DOOR_MODE_TOP_CENTER = 'top-center';
  static var CORRIDOR_ATTACH_MAIN = 'main';
  static var CORRIDOR_ATTACH_MAIN_TOP = 'main-top';
  static var CORRIDOR_ATTACH_MAIN_BOTTOM = 'main-bottom';
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

      // build a variable template layout and fallback to legacy shape on failure
      var layout = buildLabLayout(area);
      if (layout == null)
        {
          trace('UndergroundLabAreaGenerator.generate(): template layout failed, using legacy fallback.');
          layout = buildLegacyLayout(area);
        }

      // carve all role-authored rooms in a stable order
      var rooms = carveRoomSpecs(area, layout.roomSpecs);
      var entryRoom = rooms[0];
      var vatRoom = rooms[1];
      var topRoom = rooms[2];
      var bottomRoom = rooms[3];

      // carve central circulation and room connectors
      var mainCorridorW = vatRoom.x1 - entryRoom.x2 + 2;
      carveRect(area, entryRoom.x2 - 1, layout.corridorY, mainCorridorW, 2, TEMP_CORRIDOR);

      var topCorridorH = layout.corridorY - topRoom.y2 + 1;
      carveRect(area, layout.topDoorX, topRoom.y2, 2, topCorridorH, TEMP_CORRIDOR);

      var bottomCorridorH = bottomRoom.y1 - layout.corridorY;
      carveRect(area, layout.bottomDoorX, layout.corridorY + 1, 2, bottomCorridorH, TEMP_CORRIDOR);

      // carve doorway tiles into the vat chamber
      carveRect(area, layout.vatDoorX, layout.corridorY, 2, 2, TEMP_CORRIDOR);

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
      spawnDoubleDoorVertical(area, layout.entryDoorX, layout.entryDoorY);
      spawnDoubleDoorHorizontal(area, layout.topDoorX, layout.topDoorY);
      spawnDoubleDoorHorizontal(area, layout.bottomDoorX, layout.bottomDoorY);
      spawnDoubleDoorVertical(area, layout.vatDoorX, layout.vatDoorY);

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
            x: layout.vatDoorX,
            y: layout.vatDoorY,
          },
          vatAnchors: layout.vatAnchors,
          reservedRects: layout.reservedRects,
        },
      };
    }

// build a valid role-based layout with bounded retries
  function buildLabLayout(area: AreaGame): _LayoutBuildResult
    {
      for (_ in 0...MAX_LAYOUT_ATTEMPTS)
        {
          var layout = buildLayoutAttempt(area);
          if (layout != null)
            return layout;
        }
      return null;
    }

// build a single randomized layout candidate
  function buildLayoutAttempt(area: AreaGame): _LayoutBuildResult
    {
      // pick role templates for mandatory and service rooms
      var sideRoles = pickSideRoomRoles();
      var entryTemplate = pickTemplateForRole(ROOM_ROLE_ENTRANCE, []);
      var vatTemplate = pickTemplateForRole(ROOM_ROLE_VAT, []);
      var topTemplate = pickTemplateForRole(sideRoles.topRole, []);
      var bottomTemplate = pickTemplateForRole(sideRoles.bottomRole, [topTemplate.templateID]);

      // resolve randomized room dimensions
      var entryW = Const.roll(entryTemplate.sizeMinW, entryTemplate.sizeMaxW);
      var entryH = Const.roll(entryTemplate.sizeMinH, entryTemplate.sizeMaxH);
      var vatW = Const.roll(vatTemplate.sizeMinW, vatTemplate.sizeMaxW);
      var vatH = Const.roll(vatTemplate.sizeMinH, vatTemplate.sizeMaxH);
      var topW = Const.roll(topTemplate.sizeMinW, topTemplate.sizeMaxW);
      var topH = Const.roll(topTemplate.sizeMinH, topTemplate.sizeMaxH);
      var bottomW = Const.roll(bottomTemplate.sizeMinW, bottomTemplate.sizeMaxW);
      var bottomH = Const.roll(bottomTemplate.sizeMinH, bottomTemplate.sizeMaxH);

      // place entrance and vat rooms in left/right anchor bands
      var corridorY = Const.clamp(Std.int(area.height / 2) - 1 + Const.roll(-2, 2), 8, area.height - 9);
      var entryX1 = Const.roll(4, 7);
      var entryY1 = Const.clamp(corridorY - Std.int(entryH / 2) + Const.roll(-2, 2),
        2, area.height - entryH - 3);
      var vatX1 = area.width - vatW - Const.roll(4, 6);
      var vatY1 = Const.clamp(corridorY - Std.int(vatH / 2) + Const.roll(-2, 2),
        2, area.height - vatH - 3);

      // place upper/lower service rooms between entrance and vat bands
      var topXMin = entryX1 + entryW + 4;
      var topXMax = vatX1 - topW - 2;
      if (topXMin > topXMax)
        return null;
      var topX1 = Const.roll(topXMin, topXMax);

      var bottomXMin = entryX1 + entryW + 4;
      var bottomXMax = vatX1 - bottomW - 2;
      if (bottomXMin > bottomXMax)
        return null;
      var bottomX1 = Const.roll(bottomXMin, bottomXMax);

      var topYMin = 2;
      var topYMax = corridorY - topH - 2;
      if (topYMin > topYMax)
        return null;
      var topY1 = Const.roll(topYMin, topYMax);

      var bottomYMin = corridorY + 3;
      var bottomYMax = area.height - bottomH - 3;
      if (bottomYMin > bottomYMax)
        return null;
      var bottomY1 = Const.roll(bottomYMin, bottomYMax);

      var entryRoom = buildRoomSpec(entryTemplate, entryX1, entryY1, entryW, entryH);
      var vatRoom = buildRoomSpec(vatTemplate, vatX1, vatY1, vatW, vatH);
      var topRoom = buildRoomSpec(topTemplate, topX1, topY1, topW, topH);
      var bottomRoom = buildRoomSpec(bottomTemplate, bottomX1, bottomY1, bottomW, bottomH);
      topRoom.doorMode = DOOR_MODE_BOTTOM_CENTER;
      topRoom.corridorAttach = CORRIDOR_ATTACH_MAIN_TOP;
      bottomRoom.doorMode = DOOR_MODE_TOP_CENTER;
      bottomRoom.corridorAttach = CORRIDOR_ATTACH_MAIN_BOTTOM;

      var layout = buildLayoutResult([entryRoom, vatRoom, topRoom, bottomRoom], corridorY);
      if (!isLayoutGeometryValid(area, layout) ||
          !isLayoutConnected(area, layout))
        return null;
      return layout;
    }

// build the deterministic legacy room arrangement
  function buildLegacyLayout(area: AreaGame): _LayoutBuildResult
    {
      var corridorY = Std.int(area.height / 2) - 1;

      var entryRoom = {
        x1: 6,
        y1: Std.int(area.height / 2) - 4,
        w: 8,
        h: 8,
        role: ROOM_ROLE_ENTRANCE,
        templateID: 'entrance-default',
        tags: ['entry', 'elevator'],
        doorMode: DOOR_MODE_LEFT_CENTER,
        corridorAttach: CORRIDOR_ATTACH_MAIN,
      };
      var vatW = 14;
      var vatH = 16;
      var vatX = area.width - vatW - 6;
      var vatY = Std.int(area.height / 2) - Std.int(vatH / 2);
      var vatRoom = {
        x1: vatX,
        y1: vatY,
        w: vatW,
        h: vatH,
        role: ROOM_ROLE_VAT,
        templateID: 'vat-default',
        tags: ['clone', 'critical'],
        doorMode: DOOR_MODE_LEFT_CENTER,
        corridorAttach: CORRIDOR_ATTACH_MAIN,
      };
      var serviceRoomW = 10;
      var serviceRoomH = 5;
      var serviceRoomVatGap = 2;
      var serviceRoomX = vatRoom.x1 - serviceRoomW - serviceRoomVatGap;
      var topRoom = {
        x1: serviceRoomX,
        y1: entryRoom.y1 - 7,
        w: serviceRoomW,
        h: serviceRoomH,
        role: ROOM_ROLE_WORKSHOP,
        templateID: 'service-top-default',
        tags: ['service', 'workshop'],
        doorMode: DOOR_MODE_BOTTOM_CENTER,
        corridorAttach: CORRIDOR_ATTACH_MAIN_TOP,
      };
      var bottomRoom = {
        x1: serviceRoomX,
        y1: entryRoom.y1 + entryRoom.h + 2,
        w: serviceRoomW,
        h: serviceRoomH,
        role: ROOM_ROLE_STORAGE,
        templateID: 'service-bottom-default',
        tags: ['service', 'storage'],
        doorMode: DOOR_MODE_TOP_CENTER,
        corridorAttach: CORRIDOR_ATTACH_MAIN_BOTTOM,
      };
      return buildLayoutResult([entryRoom, vatRoom, topRoom, bottomRoom], corridorY);
    }

// build mission hints and connector anchors from room specs
  function buildLayoutResult(roomSpecs: Array<_LayoutRoomSpec>, corridorY: Int): _LayoutBuildResult
    {
      var entryRoom = roomSpecs[0];
      var vatRoom = roomSpecs[1];
      var topRoom = roomSpecs[2];
      var bottomRoom = roomSpecs[3];

      var entryDoorX = getRoomSpecX2(entryRoom) + 1;
      var topDoorX = topRoom.x1 + Std.int(topRoom.w / 2);
      var topDoorY = getRoomSpecY2(topRoom) + 1;
      var bottomDoorX = bottomRoom.x1 + Std.int(bottomRoom.w / 2);
      var bottomDoorY = bottomRoom.y1 - 1;
      var vatDoorX = vatRoom.x1 - 1;

      var vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      var vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
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

      return {
        roomSpecs: roomSpecs,
        corridorY: corridorY,
        entryDoorX: entryDoorX,
        entryDoorY: corridorY,
        topDoorX: topDoorX,
        topDoorY: topDoorY,
        bottomDoorX: bottomDoorX,
        bottomDoorY: bottomDoorY,
        vatDoorX: vatDoorX,
        vatDoorY: corridorY,
        vatAnchors: vatAnchors,
        reservedRects: reservedRects,
      };
    }

// create one resolved room spec from a template selection
  function buildRoomSpec(template: _RoomTemplate, x1: Int, y1: Int,
      w: Int, h: Int): _LayoutRoomSpec
    {
      return {
        x1: x1,
        y1: y1,
        w: w,
        h: h,
        role: template.role,
        templateID: template.templateID,
        tags: template.tags.copy(),
        doorMode: template.doorMode,
        corridorAttach: template.corridorAttach,
      };
    }

// carve layout room specs and emit generator room metadata
  function carveRoomSpecs(area: AreaGame, roomSpecs: Array<_LayoutRoomSpec>): Array<_Room>
    {
      var rooms = [];
      var roomID = 0;
      for (roomSpec in roomSpecs)
        makeRoom(area, rooms, {
          roomID: roomID++,
          x1: roomSpec.x1,
          y1: roomSpec.y1,
          w: roomSpec.w,
          h: roomSpec.h,
          tile: TEMP_ROOM,
          role: roomSpec.role,
          templateID: roomSpec.templateID,
          tags: roomSpec.tags,
        });
      return rooms;
    }

// pick one template for the requested role with optional exclusions
  function pickTemplateForRole(role: String,
      blockedTemplateIDs: Array<String>): _RoomTemplate
    {
      var templates = getTemplatesForRole(role);
      var candidates = [];
      for (template in templates)
        if (blockedTemplateIDs.indexOf(template.templateID) < 0)
          candidates.push(template);
      if (candidates.length == 0)
        candidates = templates;
      return candidates[Std.random(candidates.length)];
    }

// return all templates available for a room role
  function getTemplatesForRole(role: String): Array<_RoomTemplate>
    {
      if (role == ROOM_ROLE_ENTRANCE)
        return [
          {
            templateID: 'entrance-a',
            role: ROOM_ROLE_ENTRANCE,
            sizeMinW: 7,
            sizeMaxW: 9,
            sizeMinH: 7,
            sizeMaxH: 9,
            doorMode: DOOR_MODE_LEFT_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['entry', 'elevator'],
          },
          {
            templateID: 'entrance-b',
            role: ROOM_ROLE_ENTRANCE,
            sizeMinW: 8,
            sizeMaxW: 10,
            sizeMinH: 6,
            sizeMaxH: 8,
            doorMode: DOOR_MODE_LEFT_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['entry', 'elevator'],
          },
        ];

      if (role == ROOM_ROLE_VAT)
        return [
          {
            templateID: 'vat-a',
            role: ROOM_ROLE_VAT,
            sizeMinW: 13,
            sizeMaxW: 15,
            sizeMinH: 15,
            sizeMaxH: 17,
            doorMode: DOOR_MODE_LEFT_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['clone', 'critical'],
          },
          {
            templateID: 'vat-b',
            role: ROOM_ROLE_VAT,
            sizeMinW: 12,
            sizeMaxW: 14,
            sizeMinH: 14,
            sizeMaxH: 16,
            doorMode: DOOR_MODE_LEFT_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['clone', 'critical'],
          },
        ];

      if (role == ROOM_ROLE_WORKSHOP)
        return [
          {
            templateID: 'service-workshop-a',
            role: ROOM_ROLE_WORKSHOP,
            sizeMinW: 9,
            sizeMaxW: 11,
            sizeMinH: 4,
            sizeMaxH: 6,
            doorMode: DOOR_MODE_BOTTOM_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['service', 'workshop'],
          },
          {
            templateID: 'service-workshop-b',
            role: ROOM_ROLE_WORKSHOP,
            sizeMinW: 8,
            sizeMaxW: 10,
            sizeMinH: 5,
            sizeMaxH: 7,
            doorMode: DOOR_MODE_BOTTOM_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['service', 'workshop'],
          },
        ];

      if (role == ROOM_ROLE_STORAGE)
        return [
          {
            templateID: 'service-storage-a',
            role: ROOM_ROLE_STORAGE,
            sizeMinW: 9,
            sizeMaxW: 11,
            sizeMinH: 4,
            sizeMaxH: 6,
            doorMode: DOOR_MODE_BOTTOM_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['service', 'storage'],
          },
          {
            templateID: 'service-storage-b',
            role: ROOM_ROLE_STORAGE,
            sizeMinW: 8,
            sizeMaxW: 10,
            sizeMinH: 5,
            sizeMaxH: 6,
            doorMode: DOOR_MODE_BOTTOM_CENTER,
            corridorAttach: CORRIDOR_ATTACH_MAIN,
            tags: ['service', 'storage'],
          },
        ];

      return [
        {
          templateID: 'service-research-a',
          role: ROOM_ROLE_RESEARCH,
          sizeMinW: 8,
          sizeMaxW: 10,
          sizeMinH: 5,
          sizeMaxH: 7,
          doorMode: DOOR_MODE_BOTTOM_CENTER,
          corridorAttach: CORRIDOR_ATTACH_MAIN,
          tags: ['service', 'research'],
        },
        {
          templateID: 'service-research-b',
          role: ROOM_ROLE_RESEARCH,
          sizeMinW: 9,
          sizeMaxW: 11,
          sizeMinH: 4,
          sizeMaxH: 6,
          doorMode: DOOR_MODE_BOTTOM_CENTER,
          corridorAttach: CORRIDOR_ATTACH_MAIN,
          tags: ['service', 'research'],
        },
      ];
    }

// pick weighted roles for top and bottom service rooms
  function pickSideRoomRoles(): { topRole: String, bottomRole: String }
    {
      var roleWeights: Array<_RoleWeight> = [
        { role: ROOM_ROLE_WORKSHOP, weight: 40 },
        { role: ROOM_ROLE_STORAGE, weight: 35 },
        { role: ROOM_ROLE_RESEARCH, weight: 25 },
      ];
      var topRole = pickWeightedRole(roleWeights);
      var filteredRoleWeights = [];
      for (entry in roleWeights)
        if (entry.role != topRole)
          filteredRoleWeights.push(entry);
      var bottomWeights = filteredRoleWeights;
      if (bottomWeights.length == 0)
        bottomWeights = roleWeights;
      return {
        topRole: topRole,
        bottomRole: pickWeightedRole(bottomWeights),
      };
    }

// pick one role using weighted random selection
  function pickWeightedRole(roleWeights: Array<_RoleWeight>): String
    {
      var totalWeight = 0;
      for (entry in roleWeights)
        totalWeight += entry.weight;

      var roll = Std.random(totalWeight);
      var cumulativeWeight = 0;
      for (entry in roleWeights)
        {
          cumulativeWeight += entry.weight;
          if (roll < cumulativeWeight)
            return entry.role;
        }
      return roleWeights[roleWeights.length - 1].role;
    }

// validate room bounds, separation, and corridor geometry
  function isLayoutGeometryValid(area: AreaGame, layout: _LayoutBuildResult): Bool
    {
      var roomSpecs = layout.roomSpecs;
      var entryRoom = roomSpecs[0];
      var vatRoom = roomSpecs[1];
      var topRoom = roomSpecs[2];
      var bottomRoom = roomSpecs[3];

      // validate room rectangles in map interior
      for (room in roomSpecs)
        if (!canCarveRect(area, room.x1, room.y1, room.w, room.h))
          return false;

      // enforce one-tile clearance between authored rooms
      for (i in 0...roomSpecs.length)
        for (j in i + 1...roomSpecs.length)
          if (roomsOverlapWithClearance(roomSpecs[i], roomSpecs[j], 1))
            return false;

      // validate high-level left-to-right room ordering
      if (entryRoom.x1 >= vatRoom.x1 ||
          getRoomSpecX2(entryRoom) >= vatRoom.x1)
        return false;

      // validate service room vertical relationship to the main corridor
      if (getRoomSpecY2(topRoom) >= layout.corridorY ||
          bottomRoom.y1 <= layout.corridorY)
        return false;

      // validate all carved corridor pieces and door stubs
      var mainCorridorW = vatRoom.x1 - getRoomSpecX2(entryRoom) + 2;
      if (!canCarveRect(area, getRoomSpecX2(entryRoom) - 1, layout.corridorY, mainCorridorW, 2))
        return false;

      var topCorridorH = layout.corridorY - getRoomSpecY2(topRoom) + 1;
      if (!canCarveRect(area, layout.topDoorX, getRoomSpecY2(topRoom), 2, topCorridorH))
        return false;

      var bottomCorridorH = bottomRoom.y1 - layout.corridorY;
      if (!canCarveRect(area, layout.bottomDoorX, layout.corridorY + 1, 2, bottomCorridorH))
        return false;

      if (!canCarveRect(area, layout.vatDoorX, layout.corridorY, 2, 2))
        return false;

      // validate vat anchors remain inside the vat room footprint
      for (anchor in layout.vatAnchors)
        {
          if (anchor.x < vatRoom.x1 ||
              anchor.y < vatRoom.y1 ||
              anchor.x + 1 > getRoomSpecX2(vatRoom) ||
              anchor.y + 2 > getRoomSpecY2(vatRoom))
            return false;
        }

      return true;
    }

// validate that all key rooms are reachable through carved floors
  function isLayoutConnected(area: AreaGame, layout: _LayoutBuildResult): Bool
    {
      var mask = buildConnectivityMask(area, layout);
      var roomSpecs = layout.roomSpecs;
      var entryRoom = roomSpecs[0];
      var topRoom = roomSpecs[2];
      var bottomRoom = roomSpecs[3];

      var start = {
        x: entryRoom.x1 + Std.int(entryRoom.w / 2),
        y: entryRoom.y1 + Std.int(entryRoom.h / 2),
      };
      var targets = [
        { x: layout.vatDoorX, y: layout.vatDoorY },
        {
          x: topRoom.x1 + Std.int(topRoom.w / 2),
          y: topRoom.y1 + Std.int(topRoom.h / 2),
        },
        {
          x: bottomRoom.x1 + Std.int(bottomRoom.w / 2),
          y: bottomRoom.y1 + Std.int(bottomRoom.h / 2),
        },
      ];

      if (!isPointInMaskBounds(mask, start.x, start.y) ||
          !mask[start.x][start.y])
        return false;
      for (target in targets)
        if (!isPointInMaskBounds(mask, target.x, target.y) ||
            !mask[target.x][target.y])
          return false;

      var visited: Array<Array<Bool>> = [];
      for (x in 0...area.width)
        {
          visited[x] = [];
          for (y in 0...area.height)
            visited[x][y] = false;
        }

      var queue = [start];
      var queueIndex = 0;
      visited[start.x][start.y] = true;
      while (queueIndex < queue.length)
        {
          var point = queue[queueIndex];
          queueIndex++;

          if (point.x > 0 &&
              mask[point.x - 1][point.y] &&
              !visited[point.x - 1][point.y])
            {
              visited[point.x - 1][point.y] = true;
              queue.push({
                x: point.x - 1,
                y: point.y,
              });
            }
          if (point.x < area.width - 1 &&
              mask[point.x + 1][point.y] &&
              !visited[point.x + 1][point.y])
            {
              visited[point.x + 1][point.y] = true;
              queue.push({
                x: point.x + 1,
                y: point.y,
              });
            }
          if (point.y > 0 &&
              mask[point.x][point.y - 1] &&
              !visited[point.x][point.y - 1])
            {
              visited[point.x][point.y - 1] = true;
              queue.push({
                x: point.x,
                y: point.y - 1,
              });
            }
          if (point.y < area.height - 1 &&
              mask[point.x][point.y + 1] &&
              !visited[point.x][point.y + 1])
            {
              visited[point.x][point.y + 1] = true;
              queue.push({
                x: point.x,
                y: point.y + 1,
              });
            }
        }

      for (target in targets)
        if (!visited[target.x][target.y])
          return false;
      return true;
    }

// build a temporary floor mask that mirrors intended carving
  function buildConnectivityMask(area: AreaGame,
      layout: _LayoutBuildResult): Array<Array<Bool>>
    {
      var mask = [];
      for (x in 0...area.width)
        {
          mask[x] = [];
          for (y in 0...area.height)
            mask[x][y] = false;
        }

      for (room in layout.roomSpecs)
        carveRectOnMask(mask, room.x1, room.y1, room.w, room.h);

      var entryRoom = layout.roomSpecs[0];
      var vatRoom = layout.roomSpecs[1];
      var topRoom = layout.roomSpecs[2];
      var bottomRoom = layout.roomSpecs[3];
      carveRectOnMask(mask, getRoomSpecX2(entryRoom) - 1, layout.corridorY,
        vatRoom.x1 - getRoomSpecX2(entryRoom) + 2, 2);
      carveRectOnMask(mask, layout.topDoorX, getRoomSpecY2(topRoom),
        2, layout.corridorY - getRoomSpecY2(topRoom) + 1);
      carveRectOnMask(mask, layout.bottomDoorX, layout.corridorY + 1,
        2, bottomRoom.y1 - layout.corridorY);
      carveRectOnMask(mask, layout.vatDoorX, layout.corridorY, 2, 2);
      return mask;
    }

// set a rectangle as walkable in a temporary mask
  function carveRectOnMask(mask: Array<Array<Bool>>,
      x1: Int, y1: Int, w: Int, h: Int)
    {
      for (y in y1...y1 + h)
        for (x in x1...x1 + w)
          mask[x][y] = true;
    }

// check whether a carve rectangle stays inside map interior
  function canCarveRect(area: AreaGame, x1: Int, y1: Int, w: Int, h: Int): Bool
    {
      if (w <= 0 ||
          h <= 0)
        return false;
      var x2 = x1 + w - 1;
      var y2 = y1 + h - 1;
      return (x1 >= 1 &&
        y1 >= 1 &&
        x2 <= area.width - 2 &&
        y2 <= area.height - 2);
    }

// check whether two room specs overlap with the requested clearance
  function roomsOverlapWithClearance(a: _LayoutRoomSpec,
      b: _LayoutRoomSpec, clearance: Int): Bool
    {
      var aX1 = a.x1 - clearance;
      var aY1 = a.y1 - clearance;
      var aX2 = getRoomSpecX2(a) + clearance;
      var aY2 = getRoomSpecY2(a) + clearance;
      var bX1 = b.x1;
      var bY1 = b.y1;
      var bX2 = getRoomSpecX2(b);
      var bY2 = getRoomSpecY2(b);
      return !(aX2 < bX1 ||
        bX2 < aX1 ||
        aY2 < bY1 ||
        bY2 < aY1);
    }

// check whether point coordinates are valid for a mask lookup
  function isPointInMaskBounds(mask: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (x >= 0 &&
        y >= 0 &&
        x < mask.length &&
        y < mask[x].length);
    }

// get right-most x tile for a room spec
  inline function getRoomSpecX2(room: _LayoutRoomSpec): Int
    {
      return room.x1 + room.w - 1;
    }

// get bottom-most y tile for a room spec
  inline function getRoomSpecY2(room: _LayoutRoomSpec): Int
    {
      return room.y1 + room.h - 1;
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

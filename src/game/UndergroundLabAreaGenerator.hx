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
import tiles.UndergroundLab._DecorBlock;
import tiles.UndergroundLab._DecorPadding;
import tiles.UndergroundLab._FloorDecorMeta;

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

private typedef _DecorWeights = {
  var roleWeight: Int;
  var zoneWeight: Int;
  var motifWeight: Int;
  var tagWeight: Int;
}

private typedef _RoomDecorContext = {
  var room: _Room;
  var doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>;
  var corridorY: Int;
  var reservedRects: Array<_ReservedRect>;
}

private typedef _RoleGatedDecorCandidates = {
  var blocks: Array<_DecorBlock>;
  var usedFallback: Bool;
}

private typedef _DecorPickResult = {
  var blockInfo: _DecorBlock;
  var usedFallback: Bool;
}

private typedef _RoomDecorRolePickStats = {
  var roomID: Int;
  var roomRole: String;
  var nearTopRoleMatchPicks: Int;
  var nearTopFallbackPicks: Int;
  var objectRoleMatchPicks: Int;
  var objectFallbackPicks: Int;
}

private typedef _PlacedLargeDecor = {
  var family: String;
  var x1: Int;
  var y1: Int;
  var x2: Int;
  var y2: Int;
}

private typedef _RoomObjectDecorAnchor = {
  var x: Int;
  var y: Int;
  var zone: String;
}

private typedef _RoomObjectDecorPlan = {
  var largeTargetCount: Int;
  var clutterTargetCount: Int;
}

private typedef _RoomObjectDecorPassResult = {
  var attempted: Int;
  var placed: Int;
  var blockedByLargeFamilySpacing: Int;
}

private typedef _NearTopWallAnchorRun = {
  var x1: Int;
  var x2: Int;
  var y: Int;
}

class UndergroundLabAreaGenerator
{
  static var TEMP_VOID = 0;
  static var TEMP_ROOM = 1;
  static var TEMP_CORRIDOR = 2;
  static var TEMP_ENTRY = 3;
  static var MAIN_CORRIDOR_HEIGHT = 2;
  static var ROOM_TO_CORRIDOR_MIN_GAP = 2;
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
  static var DECOR_LAYER_FLOOR = 'floor';
  static var DECOR_LAYER_NEAR_TOP_WALL = 'near-top-wall';
  static var DECOR_LAYER_OBJECT = 'object';
  static var DECOR_ZONE_DOOR_BUFFER = 'door-buffer';
  static var DECOR_ZONE_TRAFFIC_LANE = 'traffic-lane';
  static var DECOR_ZONE_WALL_EDGE = 'wall-edge';
  static var DECOR_ZONE_WORK_CORE = 'work-core';
  static var DECOR_ZONE_ROOM_GENERIC = 'room-generic';
  static var DECOR_ZONE_MISSION_RESERVED = 'mission-reserved';
  static var DECOR_ROLE_GATING_STRICT = true;
  static var DECOR_ROLE_GATING_FALLBACK_PICK_CHANCE_PERCENT = 60;
  static var DEBUG_LOG_DECOR_ROLE_PICK_STATS = false;
  static var DEBUG_LOG_LARGE_DECOR_BUDGET_STATS = false;
  static var DEBUG_LOG_OBJECT_DECOR_PASS_STATS = false;
  static var DEBUG_LOG_OBJECT_ZONE_SIZE_HISTOGRAM = false;
  static var DEBUG_LOG_DECOR_WEIGHT_BREAKDOWN = false;
  static var DEBUG_LOG_NEAR_TOP_COVERAGE_STATS = false;

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
      logCreatedRooms(rooms);

      // carve central circulation and room connectors
      var mainCorridorW = vatRoom.x1 - entryRoom.x2 + 2;
      carveRect(area, entryRoom.x2 - 1, layout.corridorY, mainCorridorW,
        MAIN_CORRIDOR_HEIGHT, TEMP_CORRIDOR);

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
      // initialize tile metadata before decoration passes
      area.initTilesFromCells();
      var doorRects = getDoorFootprints(area);
      var roomDecorRolePickStatsByRoomID = createRoomDecorRolePickStatsByRoomID(rooms);
      // add wall decoration metadata for rendering layers
      decorateWalls(area);
      // add near-top wall decoration after base wall pass so it renders on top
      spawnNearTopWallDecorations(area, rooms, doorRects, layout.corridorY,
        layout.reservedRects, roomDecorRolePickStatsByRoomID);
      // add decoration objects as the final decoration pass
      spawnDecorationObj(area, rooms, doorRects, layout.corridorY,
        layout.reservedRects, roomDecorRolePickStatsByRoomID);
      // add corridor floor decorations at lower density
      decorateCorridorFloors(area, rooms, doorRects, layout.corridorY, layout.reservedRects);
      // add floor decorations last on remaining empty spots
      decorateFloors(area, rooms, doorRects, layout.corridorY, layout.reservedRects);
      logRoomDecorRolePickStats(roomDecorRolePickStatsByRoomID);

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
      var topYMax = corridorY - topH - ROOM_TO_CORRIDOR_MIN_GAP;
      if (topYMin > topYMax)
        return null;
      var topY1 = Const.roll(topYMin, topYMax);

      var bottomYMin = corridorY + MAIN_CORRIDOR_HEIGHT +
        ROOM_TO_CORRIDOR_MIN_GAP;
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

// log created room metadata with top-left coordinates
  function logCreatedRooms(rooms: Array<_Room>)
    {
      js.Browser.console.log('Underground lab rooms created:');
      for (room in rooms)
        js.Browser.console.log('roomID=' + room.id +
          ', role=' + room.role +
          ', template=' + room.templateID +
          ', topLeft=(' + room.x1 + ',' + room.y1 + ')');
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
      var topRoomMaxY = layout.corridorY - ROOM_TO_CORRIDOR_MIN_GAP - 1;
      var bottomRoomMinY = layout.corridorY + MAIN_CORRIDOR_HEIGHT +
        ROOM_TO_CORRIDOR_MIN_GAP;
      if (getRoomSpecY2(topRoom) > topRoomMaxY ||
          bottomRoom.y1 < bottomRoomMinY)
        return false;

      // validate all carved corridor pieces and door stubs
      var mainCorridorW = vatRoom.x1 - getRoomSpecX2(entryRoom) + 2;
      if (!canCarveRect(area, getRoomSpecX2(entryRoom) - 1, layout.corridorY,
        mainCorridorW, MAIN_CORRIDOR_HEIGHT))
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

// create room-level role-pick counters used for decoration diagnostics
  function createRoomDecorRolePickStatsByRoomID(rooms: Array<_Room>): Map<Int, _RoomDecorRolePickStats>
    {
      var statsByRoomID = new Map<Int, _RoomDecorRolePickStats>();
      for (room in rooms)
        {
          statsByRoomID.set(room.id, {
            roomID: room.id,
            roomRole: room.role,
            nearTopRoleMatchPicks: 0,
            nearTopFallbackPicks: 0,
            objectRoleMatchPicks: 0,
            objectFallbackPicks: 0,
          });
        }
      return statsByRoomID;
    }

// get room role-pick counter bucket, creating it if missing
  function getOrCreateRoomDecorRolePickStats(statsByRoomID: Map<Int, _RoomDecorRolePickStats>,
      room: _Room): _RoomDecorRolePickStats
    {
      var stats = statsByRoomID.get(room.id);
      if (stats != null)
        return stats;
      stats = {
        roomID: room.id,
        roomRole: room.role,
        nearTopRoleMatchPicks: 0,
        nearTopFallbackPicks: 0,
        objectRoleMatchPicks: 0,
        objectFallbackPicks: 0,
      };
      statsByRoomID.set(room.id, stats);
      return stats;
    }

// register one successful decoration pick in per-room diagnostics
  function registerRoomDecorRolePick(stats: _RoomDecorRolePickStats,
      layer: String, usedFallback: Bool)
    {
      if (layer == DECOR_LAYER_NEAR_TOP_WALL)
        {
          if (usedFallback)
            stats.nearTopFallbackPicks += 1;
          else stats.nearTopRoleMatchPicks += 1;
          return;
        }
      if (layer == DECOR_LAYER_OBJECT)
        {
          if (usedFallback)
            stats.objectFallbackPicks += 1;
          else stats.objectRoleMatchPicks += 1;
        }
    }

// log room-level role-pick diagnostics when debug flag is enabled
  function logRoomDecorRolePickStats(statsByRoomID: Map<Int, _RoomDecorRolePickStats>)
    {
      if (!DEBUG_LOG_DECOR_ROLE_PICK_STATS)
        return;
      js.Browser.console.log('Underground lab decor role-pick stats:');
      for (stats in statsByRoomID)
        js.Browser.console.log('roomID=' + stats.roomID +
          ', role=' + stats.roomRole +
          ', nearTopRoleMatch=' + stats.nearTopRoleMatchPicks +
          ', nearTopFallback=' + stats.nearTopFallbackPicks +
          ', objectRoleMatch=' + stats.objectRoleMatchPicks +
          ', objectFallback=' + stats.objectFallbackPicks);
    }

// spawn near-top wall decorations in each room using role and zone weights
  function spawnNearTopWallDecorations(area: AreaGame, rooms: Array<_Room>,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>,
      corridorY: Int, reservedRects: Array<_ReservedRect>,
      roomDecorRolePickStatsByRoomID: Map<Int, _RoomDecorRolePickStats>)
    {
      var tileset: UndergroundLab = cast game.scene.images.getTileset(area.typeID);
      for (room in rooms)
        {
          var roomRolePickStats = getOrCreateRoomDecorRolePickStats(
            roomDecorRolePickStatsByRoomID, room);
          var context: _RoomDecorContext = {
            room: room,
            doorRects: doorRects,
            corridorY: corridorY,
            reservedRects: reservedRects,
          };
          var anchors = collectNearTopWallAnchors(area, room);
          if (anchors.length == 0)
            continue;
          var runs = collectNearTopWallAnchorRuns(anchors);
          runs.sort(function(a: _NearTopWallAnchorRun, b: _NearTopWallAnchorRun)
            {
              return Reflect.compare((b.x2 - b.x1), (a.x2 - a.x1));
            });

          var fillPercent = getNearTopWallFillPercent(room.role);
          var targetCoverage = Std.int(Math.ceil(anchors.length * fillPercent / 100.0));
          var continuityTarget = getNearTopWallContinuityTarget(room.role);
          var filledCoverage = 0;
          var longestContiguousRun = 0;
          for (run in runs)
            {
              if (filledCoverage >= targetCoverage)
                break;
              var runX = run.x1;
              var runStreak = 0;
              while (runX <= run.x2 &&
                     filledCoverage < targetCoverage)
                {
                  var zone = getDecorationZone(context, runX, run.y + 1);
                  if (zone == DECOR_ZONE_MISSION_RESERVED)
                    {
                      runX += 1;
                      runStreak = 0;
                      continue;
                    }

                  var maxWidth = run.x2 - runX + 1;
                  var pickResult = pickNearTopWallDecorBlockWithFallbackWidths(area,
                    tileset, room.role, zone, runX, run.y, maxWidth);
                  if (pickResult == null)
                    {
                      runX += 1;
                      runStreak = 0;
                      continue;
                    }

                  var blockInfo = pickResult.blockInfo;
                  var block = blockInfo.block;
                  for (dy in 0...block.height)
                    for (dx in 0...block.width)
                      {
                        area.addTileDecoration(runX + dx, run.y + dy, {
                          layerID: (dy == 0 ?
                            tileset.nearTopWallWallLayerID :
                            tileset.nearTopWallFloorLayerID),
                          icon: {
                            row: block.row + dy,
                            col: block.col + dx,
                          },
                        });
                        area.recalcTile(runX + dx, run.y + dy);
                      }
                  registerRoomDecorRolePick(roomRolePickStats,
                    DECOR_LAYER_NEAR_TOP_WALL, pickResult.usedFallback);

                  filledCoverage += block.width;
                  runStreak += block.width;
                  if (runStreak > longestContiguousRun)
                    longestContiguousRun = runStreak;
                  if (runStreak < continuityTarget)
                    runX += block.width;
                  else
                    {
                      var gap = Const.roll(0, 1);
                      runX += block.width + gap;
                      if (gap > 0)
                        runStreak = 0;
                    }
                }
            }
          logNearTopCoverageStats(room, anchors.length, targetCoverage,
            filledCoverage, longestContiguousRun, continuityTarget);
        }
    }

// collect contiguous x-runs from near-top wall anchors
  function collectNearTopWallAnchorRuns(
      anchors: Array<{x: Int, y: Int}>): Array<_NearTopWallAnchorRun>
    {
      var sortedAnchors = anchors.copy();
      sortedAnchors.sort(function(a: {x: Int, y: Int}, b: {x: Int, y: Int})
        {
          return Reflect.compare(a.x, b.x);
        });
      var runs = [];
      if (sortedAnchors.length == 0)
        return runs;

      var runX1 = sortedAnchors[0].x;
      var runX2 = sortedAnchors[0].x;
      var runY = sortedAnchors[0].y;
      for (i in 1...sortedAnchors.length)
        {
          var anchor = sortedAnchors[i];
          if (anchor.y == runY &&
              anchor.x == runX2 + 1)
            {
              runX2 = anchor.x;
              continue;
            }
          runs.push({
            x1: runX1,
            x2: runX2,
            y: runY,
          });
          runX1 = anchor.x;
          runX2 = anchor.x;
          runY = anchor.y;
        }
      runs.push({
        x1: runX1,
        x2: runX2,
        y: runY,
      });
      return runs;
    }

// pick one near-top decoration block constrained by available run width
  function pickNearTopWallDecorBlock(role: String, zone: String,
      maxWidth: Int): _DecorPickResult
    {
      var candidates = [];
      for (blockInfo in UndergroundLab.NEAR_TOP_WALL_META)
        {
          if (blockInfo.block.width > maxWidth)
            continue;
          candidates.push(blockInfo);
        }
      if (candidates.length == 0)
        return null;
      return pickWeightedDecorBlock(candidates, role, zone,
        DECOR_LAYER_NEAR_TOP_WALL);
    }

// pick and place-test near-top block with narrower-width retries
  function pickNearTopWallDecorBlockWithFallbackWidths(area: AreaGame,
      tileset: UndergroundLab, role: String, zone: String,
      x: Int, y: Int, maxWidth: Int): _DecorPickResult
    {
      var widthCap = maxWidth;
      while (widthCap >= 1)
        {
          var pickResult = pickNearTopWallDecorBlock(role, zone, widthCap);
          if (pickResult == null)
            {
              widthCap -= 1;
              continue;
            }
          var block = pickResult.blockInfo.block;
          if (canPlaceNearTopWallDecorBlock(area, tileset, x, y, block))
            return pickResult;
          widthCap = block.width - 1;
        }
      return null;
    }

// get room-role near-top continuity target in tiles
  function getNearTopWallContinuityTarget(role: String): Int
    {
      if (role == ROOM_ROLE_ENTRANCE)
        return 2;
      if (role == ROOM_ROLE_STORAGE)
        return 3;
      return 4;
    }

// log near-top coverage and continuity metrics when debug is enabled
  function logNearTopCoverageStats(room: _Room,
      availableAnchors: Int, targetCoverage: Int, filledCoverage: Int,
      longestContiguousRun: Int, continuityTarget: Int)
    {
      if (!DEBUG_LOG_NEAR_TOP_COVERAGE_STATS)
        return;
      js.Browser.console.log('roomID=' + room.id +
        ', role=' + room.role +
        ', nearTopAvailable=' + availableAnchors +
        ', nearTopTarget=' + targetCoverage +
        ', nearTopFilled=' + filledCoverage +
        ', nearTopLongestRun=' + longestContiguousRun +
        ', nearTopContinuityTarget=' + continuityTarget);
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

// check whether near-top wall block fits wall/floor tiles without conflicting near-top decorations
  function canPlaceNearTopWallDecorBlock(area: AreaGame, tileset: UndergroundLab,
      x: Int, y: Int, block: _IconBlock): Bool
    {
      var tiles = area.getTiles();
      for (dy in 0...block.height)
        for (dx in 0...block.width)
          {
            var tx = x + dx;
            var ty = y + dy;
            if (tx < 0 ||
                ty < 0 ||
                tx >= area.width ||
                ty >= area.height)
              return false;

            var tileID = area.getCellType(tx, ty);
            if (dy == 0)
              {
                if (!tileset.isHorizontalWallTile(tileID))
                  return false;
              }
            else
              {
                if (!tileset.isWalkable(tileID))
                  return false;
              }

            if (area.hasObjectAt(tx, ty))
              return false;

            var tile = tiles[tx][ty];
            if (tile == null ||
                tile.decoration == null)
              continue;
            for (decoration in tile.decoration)
              if (decoration.layerID == tileset.nearTopWallWallLayerID ||
                  decoration.layerID == tileset.nearTopWallFloorLayerID)
                return false;
          }
      return true;
    }

// spawn decoration object blocks on floor with semantic weighted placement
  function spawnDecorationObj(area: AreaGame, rooms: Array<_Room>,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>,
      corridorY: Int, reservedRects: Array<_ReservedRect>,
      roomDecorRolePickStatsByRoomID: Map<Int, _RoomDecorRolePickStats>)
    {
      var tileset: UndergroundLab = cast game.scene.images.getTileset(area.typeID);
      var tiles = area.getTiles();
      for (room in rooms)
        {
          var roomLargeDecorFamilyCounts = new Map<String, Int>();
          var roomPlacedLargeDecors: Array<_PlacedLargeDecor> = [];
          var roomObjectZoneSizeHistogram = new Map<String, Int>();
          var roomRolePickStats = getOrCreateRoomDecorRolePickStats(
            roomDecorRolePickStatsByRoomID, room);
          var context: _RoomDecorContext = {
            room: room,
            doorRects: doorRects,
            corridorY: corridorY,
            reservedRects: reservedRects,
          };
          var plan = buildRoomObjectDecorPlan(room);
          var allAnchors = collectRoomObjectDecorAnchors(room, context);
          var anchorPassAnchors = collectRoomObjectDecorPassAnchors(allAnchors,
            [DECOR_ZONE_WALL_EDGE],
            [DECOR_ZONE_ROOM_GENERIC]);
          var clutterPassAnchors = collectRoomObjectDecorPassAnchors(allAnchors,
            [DECOR_ZONE_WORK_CORE, DECOR_ZONE_ROOM_GENERIC],
            [DECOR_ZONE_WALL_EDGE, DECOR_ZONE_TRAFFIC_LANE]);
          var anchorPassResult = executeRoomObjectDecorPass(area, tileset, tiles,
            room, anchorPassAnchors, plan.largeTargetCount,
            true, true, doorRects, reservedRects, roomLargeDecorFamilyCounts,
            roomPlacedLargeDecors, roomRolePickStats,
            roomObjectZoneSizeHistogram);
          var clutterPassResult = executeRoomObjectDecorPass(area, tileset, tiles,
            room, clutterPassAnchors, plan.clutterTargetCount,
            false, false, doorRects, reservedRects, roomLargeDecorFamilyCounts,
            roomPlacedLargeDecors, roomRolePickStats,
            roomObjectZoneSizeHistogram);
          logLargeDecorBudgetStats(room, roomLargeDecorFamilyCounts,
            anchorPassResult.blockedByLargeFamilySpacing +
            clutterPassResult.blockedByLargeFamilySpacing);
          logRoomObjectDecorPassStats(room, plan, anchorPassResult, clutterPassResult);
          logRoomObjectZoneSizeHistogram(room, roomObjectZoneSizeHistogram);
        }
    }

// build role-aware per-room targets for object decoration passes
  function buildRoomObjectDecorPlan(room: _Room): _RoomObjectDecorPlan
    {
      var roomArea = room.w * room.h;
      var largeTargetCount = 0;
      var clutterTargetCount = 0;
      if (room.role == ROOM_ROLE_ENTRANCE)
        {
          largeTargetCount = Const.clamp(Std.int(roomArea / 30), 1, 3);
          clutterTargetCount = Const.clamp(Std.int(roomArea / 18), 2, 6);
        }
      else if (room.role == ROOM_ROLE_VAT)
        {
          largeTargetCount = Const.clamp(Std.int(roomArea / 22), 2, 5);
          clutterTargetCount = Const.clamp(Std.int(roomArea / 16), 3, 8);
        }
      else if (room.role == ROOM_ROLE_WORKSHOP)
        {
          largeTargetCount = Const.clamp(Std.int(roomArea / 24), 2, 5);
          clutterTargetCount = Const.clamp(Std.int(roomArea / 16), 3, 7);
        }
      else if (room.role == ROOM_ROLE_STORAGE)
        {
          largeTargetCount = Const.clamp(Std.int(roomArea / 24), 2, 4);
          clutterTargetCount = Const.clamp(Std.int(roomArea / 15), 3, 8);
        }
      else
        {
          largeTargetCount = Const.clamp(Std.int(roomArea / 22), 2, 5);
          clutterTargetCount = Const.clamp(Std.int(roomArea / 15), 3, 8);
        }
      return {
        largeTargetCount: largeTargetCount,
        clutterTargetCount: clutterTargetCount,
      };
    }

// collect zone-tagged object anchors for a room-level decoration plan
  function collectRoomObjectDecorAnchors(room: _Room,
      context: _RoomDecorContext): Array<_RoomObjectDecorAnchor>
    {
      var anchors = [];
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            var zone = getDecorationZone(context, x, y);
            if (zone == DECOR_ZONE_MISSION_RESERVED ||
                zone == DECOR_ZONE_DOOR_BUFFER)
              continue;
            anchors.push({
              x: x,
              y: y,
              zone: zone,
            });
          }
      return anchors;
    }

// collect one ordered anchor list using primary then secondary zones
  function collectRoomObjectDecorPassAnchors(
      allAnchors: Array<_RoomObjectDecorAnchor>,
      primaryZones: Array<String>,
      secondaryZones: Array<String>): Array<_RoomObjectDecorAnchor>
    {
      var anchors = [];
      for (anchor in allAnchors)
        if (primaryZones.indexOf(anchor.zone) >= 0)
          anchors.push(anchor);
      for (anchor in allAnchors)
        {
          if (primaryZones.indexOf(anchor.zone) >= 0 ||
              secondaryZones.indexOf(anchor.zone) < 0)
            continue;
          anchors.push(anchor);
        }
      return anchors;
    }

// execute one room-level object decoration pass over a planned anchor queue
  function executeRoomObjectDecorPass(area: AreaGame, tileset: UndergroundLab,
      tiles: Array<Array<tiles.Tile>>, room: _Room,
      passAnchors: Array<_RoomObjectDecorAnchor>, targetCount: Int,
      requireLarge: Bool, allowLarge: Bool,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>,
      reservedRects: Array<_ReservedRect>,
      roomLargeDecorFamilyCounts: Map<String, Int>,
      roomPlacedLargeDecors: Array<_PlacedLargeDecor>,
      roomRolePickStats: _RoomDecorRolePickStats,
      roomObjectZoneSizeHistogram: Map<String, Int>): _RoomObjectDecorPassResult
    {
      var anchors = passAnchors.copy();
      var placed = 0;
      var attempted = 0;
      var blockedByLargeFamilySpacing = 0;
      var maxAttempts = Const.clamp(targetCount * 8, 12, 120);
      while (placed < targetCount &&
             anchors.length > 0 &&
             attempted < maxAttempts)
        {
          var anchorIndex = Const.roll(0, anchors.length - 1);
          var anchor = anchors[anchorIndex];
          anchors.splice(anchorIndex, 1);
          attempted += 1;

          var pickResult = pickWeightedObjectDecorBlock(room.role, anchor.zone,
            roomLargeDecorFamilyCounts, requireLarge, allowLarge);
          if (pickResult == null)
            continue;
          var blockInfo = pickResult.blockInfo;
          var block = blockInfo.block;
          var largeDecorFamily = null;
          if (isLargeDecorBlock(blockInfo))
            {
              largeDecorFamily = getLargeDecorFamily(blockInfo);
              if (!canPlaceLargeDecorFamilyWithSpacing(room.role, anchor.x, anchor.y,
                  block, largeDecorFamily, roomPlacedLargeDecors))
                {
                  blockedByLargeFamilySpacing += 1;
                  continue;
                }
            }
          if (isRectOverlappingReservedRect(anchor.x, anchor.y,
              anchor.x + block.width - 1, anchor.y + block.height - 1, reservedRects))
            continue;
          if (!canPlaceDecorationObjBlock(area, tileset, tiles, room,
              anchor.x, anchor.y, blockInfo, doorRects))
            continue;

          if (largeDecorFamily != null)
            {
              incrementLargeDecorFamilyCount(roomLargeDecorFamilyCounts,
                largeDecorFamily);
              roomPlacedLargeDecors.push({
                family: largeDecorFamily,
                x1: anchor.x,
                y1: anchor.y,
                x2: anchor.x + block.width - 1,
                y2: anchor.y + block.height - 1,
              });
            }
          var objectLayerID = tileset.getDecorationObjLayerID(blockInfo.meta.imageKey);
          var groupTag = 'DECO_OBJ:' + anchor.x + ':' + anchor.y + ':' + Const.roll(0, 999999);
          for (dy in 0...block.height)
            for (dx in 0...block.width)
              area.addTileDecoration(anchor.x + dx, anchor.y + dy, {
                layerID: objectLayerID,
                icon: {
                  row: block.row + dy,
                  col: block.col + dx,
                },
                tag: groupTag,
              });
          registerRoomDecorRolePick(roomRolePickStats,
            DECOR_LAYER_OBJECT, pickResult.usedFallback);
          incrementRoomObjectZoneSizeHistogram(roomObjectZoneSizeHistogram,
            anchor.zone, isLargeDecorBlock(blockInfo));
          placed += 1;
          pruneRoomObjectDecorAnchors(anchors, anchor.x, anchor.y, block);
        }
      return {
        attempted: attempted,
        placed: placed,
        blockedByLargeFamilySpacing: blockedByLargeFamilySpacing,
      };
    }

// prune anchors overlapping or immediately hugging a just-placed block
  function pruneRoomObjectDecorAnchors(anchors: Array<_RoomObjectDecorAnchor>,
      x: Int, y: Int, block: _IconBlock)
    {
      var x2 = x + block.width - 1;
      var y2 = y + block.height - 1;
      var i = anchors.length - 1;
      while (i >= 0)
        {
          var anchor = anchors[i];
          if (anchor.x >= x - 1 &&
              anchor.x <= x2 + 1 &&
              anchor.y >= y - 1 &&
              anchor.y <= y2 + 1)
            anchors.splice(i, 1);
          i -= 1;
        }
    }

// log room-level pass metrics when object-pass debug flag is enabled
  function logRoomObjectDecorPassStats(room: _Room, plan: _RoomObjectDecorPlan,
      anchorPassResult: _RoomObjectDecorPassResult,
      clutterPassResult: _RoomObjectDecorPassResult)
    {
      if (!DEBUG_LOG_OBJECT_DECOR_PASS_STATS)
        return;
      js.Browser.console.log('roomID=' + room.id +
        ', role=' + room.role +
        ', anchorAttempted=' + anchorPassResult.attempted +
        ', anchorPlaced=' + anchorPassResult.placed +
        ', anchorTarget=' + plan.largeTargetCount +
        ', clutterAttempted=' + clutterPassResult.attempted +
        ', clutterPlaced=' + clutterPassResult.placed +
        ', clutterTarget=' + plan.clutterTargetCount);
    }

// increment zone/size placement histogram for one successful object placement
  function incrementRoomObjectZoneSizeHistogram(
      roomObjectZoneSizeHistogram: Map<String, Int>,
      zone: String, isLarge: Bool)
    {
      var key = zone + ':' + (isLarge ? 'large' : 'small');
      var count = roomObjectZoneSizeHistogram.get(key);
      if (count == null)
        count = 0;
      roomObjectZoneSizeHistogram.set(key, count + 1);
    }

// log room-level zone/size histogram when debug flag is enabled
  function logRoomObjectZoneSizeHistogram(room: _Room,
      roomObjectZoneSizeHistogram: Map<String, Int>)
    {
      if (!DEBUG_LOG_OBJECT_ZONE_SIZE_HISTOGRAM)
        return;
      var items = [];
      for (key in roomObjectZoneSizeHistogram.keys())
        items.push(key + '=' + roomObjectZoneSizeHistogram.get(key));
      items.sort(function(a: String, b: String)
        {
          return Reflect.compare(a, b);
        });
      js.Browser.console.log('roomID=' + room.id +
        ', role=' + room.role +
        ', objectZoneSizeHistogram=' + items.join(','));
    }

// log per-room large-decoration budget usage when debug flag is enabled
  function logLargeDecorBudgetStats(room: _Room,
      roomLargeDecorFamilyCounts: Map<String, Int>,
      blockedByLargeFamilySpacing: Int)
    {
      if (!DEBUG_LOG_LARGE_DECOR_BUDGET_STATS)
        return;
      var placedByFamily = [];
      for (family in roomLargeDecorFamilyCounts.keys())
        placedByFamily.push(family + '=' + roomLargeDecorFamilyCounts.get(family));
      placedByFamily.sort(function(a: String, b: String)
        {
          return Reflect.compare(a, b);
        });
      js.Browser.console.log('roomID=' + room.id +
        ', role=' + room.role +
        ', largePlacedByFamily=' + placedByFamily.join(',') +
        ', blockedByFamilySpacing=' + blockedByLargeFamilySpacing);
    }

// check if a decoration object block can be placed at top-left x,y
  function canPlaceDecorationObjBlock(area: AreaGame, tileset: tiles.Tileset,
      tiles: Array<Array<tiles.Tile>>, room: _Room, x: Int, y: Int,
      blockInfo: _DecorBlock,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>): Bool
    {
      var block = blockInfo.block;
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
                hasBlockingTileDecorationForObjectPlacement(area, tileset, tiles,
                  tx, ty, false))
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
            if (hasBlockingTileDecorationForObjectPlacement(area, tileset, tiles,
              nx, ny, false))
              return false;
          }
      if (!isDecorPaddingClear(area, tileset, tiles, room, x, y, blockInfo))
        return false;

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

// normalize optional padding values so negative/null resolves to zero
  inline function getDecorPaddingValue(value: Null<Int>): Int
    {
      if (value == null ||
          value < 0)
        return 0;
      return value;
    }

// check whether one padding rectangle is fully inside room and clear
  function isDecorPaddingRectClear(area: AreaGame, tileset: tiles.Tileset,
      tiles: Array<Array<tiles.Tile>>, room: _Room,
      x1: Int, y1: Int, x2: Int, y2: Int): Bool
    {
      if (x1 > x2 ||
          y1 > y2)
        return true;
      if (x1 < room.x1 ||
          y1 < room.y1 ||
          x2 > room.x2 ||
          y2 > room.y2)
        return false;

      for (y in y1...y2 + 1)
        for (x in x1...x2 + 1)
          {
            if (!tileset.isWalkable(area.getCellType(x, y)) ||
                area.hasObjectAt(x, y) ||
                hasBlockingTileDecorationForObjectPlacement(area, tileset, tiles,
                  x, y, false))
              return false;
          }
      return true;
    }

// check whether directional padding around one block is clear
  function isDecorPaddingClear(area: AreaGame, tileset: tiles.Tileset,
      tiles: Array<Array<tiles.Tile>>, room: _Room,
      x: Int, y: Int, blockInfo: _DecorBlock): Bool
    {
      var padding: _DecorPadding = blockInfo.meta.padding;
      if (padding == null)
        return true;

      var block = blockInfo.block;
      var padUp = getDecorPaddingValue(padding.up);
      var padRight = getDecorPaddingValue(padding.right);
      var padDown = getDecorPaddingValue(padding.down);
      var padLeft = getDecorPaddingValue(padding.left);

      if (padUp > 0 &&
          !isDecorPaddingRectClear(area, tileset, tiles, room,
            x, y - padUp, x + block.width - 1, y - 1))
        return false;
      if (padRight > 0 &&
          !isDecorPaddingRectClear(area, tileset, tiles, room,
            x + block.width, y, x + block.width + padRight - 1,
            y + block.height - 1))
        return false;
      if (padDown > 0 &&
          !isDecorPaddingRectClear(area, tileset, tiles, room,
            x, y + block.height, x + block.width - 1,
            y + block.height + padDown - 1))
        return false;
      if (padLeft > 0 &&
          !isDecorPaddingRectClear(area, tileset, tiles, room,
            x - padLeft, y, x - 1, y + block.height - 1))
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

// check whether this tile has any blocking decoration entry
  function hasBlockingTileDecoration(area: AreaGame, tileset: tiles.Tileset,
      tiles: Array<Array<tiles.Tile>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= tiles.length ||
          tiles[x] == null ||
          y >= tiles[x].length)
        return false;
      var tile = tiles[x][y];
      if (tile == null ||
          tile.decoration == null ||
          tile.decoration.length == 0)
        return false;

      var tileID = area.getCellType(x, y);
      for (decoration in tile.decoration)
        if (tileset.isBlockingDecoration(tileID, decoration))
          return true;
      return false;
    }

// check blocking decoration for object placement
  function hasBlockingTileDecorationForObjectPlacement(area: AreaGame,
      tileset: tiles.Tileset, tiles: Array<Array<tiles.Tile>>, x: Int, y: Int,
      ignoreNearTopFloorOverlay: Bool): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= tiles.length ||
          tiles[x] == null ||
          y >= tiles[x].length)
        return false;
      var tile = tiles[x][y];
      if (tile == null ||
          tile.decoration == null ||
          tile.decoration.length == 0)
        return false;

      var nearTopFloorLayerID = -1;
      if (Std.isOfType(tileset, UndergroundLab))
        {
          var undergroundLab: UndergroundLab = cast tileset;
          nearTopFloorLayerID = undergroundLab.nearTopWallFloorLayerID;
        }

      var tileID = area.getCellType(x, y);
      for (decoration in tile.decoration)
        {
          if (!tileset.isBlockingDecoration(tileID, decoration))
            continue;
          if (ignoreNearTopFloorOverlay &&
              decoration.layerID == nearTopFloorLayerID)
            continue;
          return true;
        }
      return false;
    }

// place floor decoration metadata using room role and zone weights
  function decorateFloors(area: AreaGame, rooms: Array<_Room>,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>,
      corridorY: Int, reservedRects: Array<_ReservedRect>)
    {
      var tileset = game.scene.images.getTileset(area.typeID);
      var tiles = area.getTiles();
      for (room in rooms)
        {
          var context: _RoomDecorContext = {
            room: room,
            doorRects: doorRects,
            corridorY: corridorY,
            reservedRects: reservedRects,
          };
          for (y in room.y1...room.y2 + 1)
            for (x in room.x1...room.x2 + 1)
              {
                var tileID = area.getCellType(x, y);
                if (!tileset.isWalkable(tileID) ||
                    area.hasObjectAt(x, y) ||
                    hasBlockingTileDecoration(area, tileset, tiles, x, y) ||
                    hasAdjacentFloorDecoration(area, tiles, x, y))
                  continue;

                if (hasFloorDecorationAtTile(tiles, x, y))
                  continue;

                var zone = getDecorationZone(context, x, y);
                var chance = getPlacementChancePercent(DECOR_LAYER_FLOOR, room.role, zone);
                if (chance <= 0 ||
                    Const.roll(1, 100) > chance)
                  continue;

                var floorInfo = pickWeightedFloorDecorMeta(room.role, zone);
                if (floorInfo == null)
                  continue;

                area.addTileDecoration(x, y, {
                  layerID: 0,
                  icon: {
                    row: floorInfo.icon.row,
                    col: floorInfo.icon.col,
                  },
                });
              }
        }
    }

// place floor decorations on corridor tiles outside room footprints
  function decorateCorridorFloors(area: AreaGame, rooms: Array<_Room>,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>,
      corridorY: Int, reservedRects: Array<_ReservedRect>)
    {
      var tileset = game.scene.images.getTileset(area.typeID);
      var tiles = area.getTiles();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (isPointInsideAnyRoom(rooms, x, y))
              continue;

            var tileID = area.getCellType(x, y);
            if (!tileset.isWalkable(tileID) ||
                area.hasObjectAt(x, y) ||
                hasBlockingTileDecoration(area, tileset, tiles, x, y) ||
                hasFloorDecorationAtTile(tiles, x, y) ||
                hasAdjacentFloorDecoration(area, tiles, x, y) ||
                isPointInAnyReservedRect(x, y, reservedRects))
              continue;

            var zone = DECOR_ZONE_ROOM_GENERIC;
            if (isInDoorBufferZone(x, y, doorRects))
              zone = DECOR_ZONE_DOOR_BUFFER;
            else if (isInTrafficLaneZone(x, y, corridorY))
              zone = DECOR_ZONE_TRAFFIC_LANE;

            var baseChance = getPlacementChancePercent(DECOR_LAYER_FLOOR,
              ROOM_ROLE_ENTRANCE, zone);
            var chance = Std.int(baseChance * 2 / 3) + 11;
            chance = Const.clamp(chance, 0, 95);
            if (chance <= 0 ||
                Const.roll(1, 100) > chance)
              continue;

            var floorInfo = pickWeightedFloorDecorMeta(ROOM_ROLE_ENTRANCE, zone);
            if (floorInfo == null)
              continue;

            area.addTileDecoration(x, y, {
              layerID: 0,
              icon: {
                row: floorInfo.icon.row,
                col: floorInfo.icon.col,
              },
            });
          }
    }

// check whether point is inside any generated room footprint
  function isPointInsideAnyRoom(rooms: Array<_Room>, x: Int, y: Int): Bool
    {
      for (room in rooms)
        if (x >= room.x1 &&
            x <= room.x2 &&
            y >= room.y1 &&
            y <= room.y2)
          return true;
      return false;
    }

// check whether this tile has a floor decoration entry
  function hasFloorDecorationAtTile(tiles: Array<Array<tiles.Tile>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= tiles.length ||
          tiles[x] == null ||
          y >= tiles[x].length)
        return false;
      var tile = tiles[x][y];
      if (tile == null ||
          tile.decoration == null ||
          tile.decoration.length == 0)
        return false;
      for (decoration in tile.decoration)
        if (decoration.layerID == 0)
          return true;
      return false;
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

            if (hasFloorDecorationAtTile(tiles, nx, ny))
              return true;
          }
      return false;
    }

// get role-aware near-top wall fill percentage
  function getNearTopWallFillPercent(role: String): Int
    {
      var fill = 0;
      if (role == ROOM_ROLE_ENTRANCE)
        fill = 28 + Const.roll(0, 18);
      else if (role == ROOM_ROLE_VAT)
        fill = 56 + Const.roll(0, 24);
      else if (role == ROOM_ROLE_WORKSHOP)
        fill = 54 + Const.roll(0, 22);
      else if (role == ROOM_ROLE_STORAGE)
        fill = 50 + Const.roll(0, 22);
      else if (role == ROOM_ROLE_RESEARCH)
        fill = 52 + Const.roll(0, 22);
      else fill = 48 + Const.roll(0, 20);
      return Const.clamp(fill, 8, 88);
    }

// get base placement chance for a layer/role/zone combination
  function getPlacementChancePercent(layer: String, role: String, zone: String): Int
    {
      var baseChance = 0;
      if (layer == DECOR_LAYER_FLOOR)
        baseChance = 18;
      else if (layer == DECOR_LAYER_OBJECT)
        baseChance = 34;
      else baseChance = 100;

      var weights = getDecorWeights(layer, role, zone, [], []);
      var chance = Std.int(baseChance * weights.roleWeight * weights.zoneWeight / 10000);
      return Const.clamp(chance, 0, 95);
    }

// check whether block metadata includes the requested room role
  inline function isRoleMatchedDecorBlock(blockInfo: _DecorBlock, role: String): Bool
    {
      return (blockInfo.meta.roles.indexOf(role) >= 0);
    }

// build role-gated candidate pool for strict and legacy modes
  function getRoleGatedDecorCandidates(blocks: Array<_DecorBlock>,
      role: String): _RoleGatedDecorCandidates
    {
      if (!DECOR_ROLE_GATING_STRICT)
        return {
          blocks: blocks,
          usedFallback: false,
        };

      var roleMatchedBlocks = [];
      for (blockInfo in blocks)
        if (isRoleMatchedDecorBlock(blockInfo, role))
          roleMatchedBlocks.push(blockInfo);
      if (roleMatchedBlocks.length > 0)
        return {
          blocks: roleMatchedBlocks,
          usedFallback: false,
        };
      return {
        blocks: blocks,
        usedFallback: true,
      };
    }

// roll explicit fallback penalty gate for strict role-gating mode
  function isFallbackPickRejected(usedFallback: Bool): Bool
    {
      if (!DECOR_ROLE_GATING_STRICT ||
          !usedFallback)
        return false;
      return (Const.roll(1, 100) > DECOR_ROLE_GATING_FALLBACK_PICK_CHANCE_PERCENT);
    }

// log sampled weight breakdown for one decoration candidate when debug is enabled
  function logDecorWeightBreakdownSample(layer: String, role: String, zone: String,
      blockInfo: _DecorBlock, weights: _DecorWeights,
      roleAffinity: Int, weight: Int)
    {
      if (!DEBUG_LOG_DECOR_WEIGHT_BREAKDOWN ||
          Const.roll(1, 180) != 1)
        return;
      js.Browser.console.log('decorWeightSample layer=' + layer +
        ', role=' + role +
        ', zone=' + zone +
        ', decorID=' + blockInfo.meta.id +
        ', roleWeight=' + weights.roleWeight +
        ', zoneWeight=' + weights.zoneWeight +
        ', motifWeight=' + weights.motifWeight +
        ', tagWeight=' + weights.tagWeight +
        ', roleAffinity=' + roleAffinity +
        ', finalWeight=' + weight);
    }

// pick weighted decoration block metadata for near-top or object layer
  function pickWeightedDecorBlock(blocks: Array<_DecorBlock>,
      role: String, zone: String, layer: String): _DecorPickResult
    {
      var candidateInfo = getRoleGatedDecorCandidates(blocks, role);
      if (candidateInfo.blocks.length == 0 ||
          isFallbackPickRejected(candidateInfo.usedFallback))
        return null;

      var weightList = [];
      for (blockInfo in candidateInfo.blocks)
        {
          var weights = getDecorWeights(layer, role, zone, blockInfo.meta.motifs,
            blockInfo.meta.tags);
          var roleAffinity = (blockInfo.meta.roles.indexOf(role) >= 0 ? 130 : 60);
          var weight = Std.int(blockInfo.meta.baseWeight *
            weights.roleWeight *
            weights.zoneWeight *
            weights.motifWeight *
            weights.tagWeight *
            roleAffinity / 10000000000);
          weight = Const.clamp(weight, blockInfo.meta.minZoneWeight, blockInfo.meta.maxZoneWeight);
          logDecorWeightBreakdownSample(layer, role, zone, blockInfo,
            weights, roleAffinity, weight);
          weightList.push(weight);
        }

      var index = pickWeightedIndex(weightList);
      if (index < 0)
        return null;
      var pickedBlockInfo = candidateInfo.blocks[index];
      return {
        blockInfo: pickedBlockInfo,
        usedFallback: !isRoleMatchedDecorBlock(pickedBlockInfo, role),
      };
    }

// pick weighted object decoration block with role/size filters and local budgets
  function pickWeightedObjectDecorBlock(role: String, zone: String,
      roomLargeDecorFamilyCounts: Map<String, Int>,
      requireLarge: Bool, allowLarge: Bool): _DecorPickResult
    {
      var blocks = UndergroundLab.DECORATION_OBJ_META;
      var candidateInfo = getRoleGatedDecorCandidates(blocks, role);
      if (candidateInfo.blocks.length == 0 ||
          isFallbackPickRejected(candidateInfo.usedFallback))
        return null;
      var weightList = [];
      for (blockInfo in candidateInfo.blocks)
        {
          var isLargeBlock = isLargeDecorBlock(blockInfo);
          if ((requireLarge &&
               !isLargeBlock) ||
              (!allowLarge &&
               isLargeBlock))
            {
              weightList.push(0);
              continue;
            }
          var weights = getDecorWeights(DECOR_LAYER_OBJECT, role, zone,
            blockInfo.meta.motifs, blockInfo.meta.tags);
          var roleAffinity = (blockInfo.meta.roles.indexOf(role) >= 0 ? 130 : 60);
          var weight = Std.int(blockInfo.meta.baseWeight *
            weights.roleWeight *
            weights.zoneWeight *
            weights.motifWeight *
            weights.tagWeight *
            roleAffinity / 10000000000);
          weight = Const.clamp(weight, blockInfo.meta.minZoneWeight, blockInfo.meta.maxZoneWeight);
          if (zone == DECOR_ZONE_WALL_EDGE &&
              blockInfo.meta.tags.indexOf('table') >= 0)
            {
              if (role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_RESEARCH ||
                  role == ROOM_ROLE_WORKSHOP)
                weight = Std.int(weight * 2);
              else weight = Std.int(weight * 16 / 10);
              if (blockInfo.meta.padding != null &&
                  blockInfo.meta.padding.down > 0)
                weight = Std.int(weight * 15 / 10);
            }
          else if (blockInfo.meta.tags.indexOf('table') >= 0 &&
                   blockInfo.meta.padding != null &&
                   blockInfo.meta.padding.down > 0)
            weight = Std.int(weight * 55 / 100);

          if (isLargeBlock)
            weight = applyLargeDecorFamilyBudgetPenalty(role,
              getLargeDecorFamily(blockInfo), roomLargeDecorFamilyCounts, weight);

          if (zone == DECOR_ZONE_WALL_EDGE)
            {
              if (!isLargeBlock)
                weight = Std.int(weight * 80 / 100);
            }
          else if (zone == DECOR_ZONE_WORK_CORE)
            {
              if (isLargeBlock)
                weight = Std.int(weight * 35 / 100);
            }
          else if (zone == DECOR_ZONE_TRAFFIC_LANE)
            {
              if (isLargeBlock)
                weight = Std.int(weight * 12 / 100);
              else weight = Std.int(weight * 8 / 100);
            }

          logDecorWeightBreakdownSample(DECOR_LAYER_OBJECT, role, zone,
            blockInfo, weights, roleAffinity, weight);
          weightList.push(weight);
        }

      var index = pickWeightedIndex(weightList);
      if (index < 0)
        return null;
      var pickedBlockInfo = candidateInfo.blocks[index];
      return {
        blockInfo: pickedBlockInfo,
        usedFallback: !isRoleMatchedDecorBlock(pickedBlockInfo, role),
      };
    }

// check whether decoration block is large
  inline function isLargeDecorBlock(blockInfo: _DecorBlock): Bool
    {
      return (blockInfo.block.width > 1 ||
        blockInfo.block.height > 1);
    }

// increment one room-local large-decoration family counter
  function incrementLargeDecorFamilyCount(roomLargeDecorFamilyCounts: Map<String, Int>,
      family: String)
    {
      var count = roomLargeDecorFamilyCounts.get(family);
      if (count == null)
        count = 0;
      roomLargeDecorFamilyCounts.set(family, count + 1);
    }

// resolve large-decoration family for room-local repetition budgets
  function getLargeDecorFamily(blockInfo: _DecorBlock): String
    {
      if (blockInfo.meta.tags.indexOf('table') >= 0)
        return 'table';
      if (blockInfo.meta.tags.indexOf('computer') >= 0)
        return 'computer';
      if (blockInfo.meta.tags.indexOf('gurney') >= 0)
        return 'gurney';
      if (blockInfo.meta.tags.indexOf('crate') >= 0)
        return 'crate';
      if (blockInfo.meta.tags.indexOf('machinery') >= 0)
        return 'machinery';
      return 'generic';
    }

// get room-role family budget for large-decoration repetition
  function getLargeDecorFamilyBudget(role: String, family: String): Int
    {
      if (role == ROOM_ROLE_ENTRANCE)
        {
          if (family == 'machinery')
            return 2;
          if (family == 'crate')
            return 2;
          if (family == 'gurney')
            return 2;
          if (family == 'table' ||
              family == 'computer')
            return 1;
          return 1;
        }

      if (role == ROOM_ROLE_VAT)
        {
          if (family == 'machinery')
            return 4;
          if (family == 'table' ||
              family == 'computer')
            return 3;
          if (family == 'crate')
            return 1;
          if (family == 'gurney')
            return 0;
          return 2;
        }

      if (role == ROOM_ROLE_WORKSHOP)
        {
          if (family == 'machinery')
            return 4;
          if (family == 'table' ||
              family == 'computer')
            return 3;
          if (family == 'crate')
            return 2;
          if (family == 'gurney')
            return 0;
          return 2;
        }

      if (role == ROOM_ROLE_STORAGE)
        {
          if (family == 'crate')
            return 4;
          if (family == 'machinery')
            return 3;
          if (family == 'table' ||
              family == 'computer')
            return 1;
          if (family == 'gurney')
            return 0;
          return 2;
        }

      if (family == 'machinery')
        return 5;
      if (family == 'table' ||
          family == 'computer')
        return 4;
      if (family == 'crate')
        return 1;
      if (family == 'gurney')
        return 0;
      return 2;
    }

// apply room-local soft penalty once a large family budget is exceeded
  function applyLargeDecorFamilyBudgetPenalty(role: String, family: String,
      roomLargeDecorFamilyCounts: Map<String, Int>, weight: Int): Int
    {
      var budget = getLargeDecorFamilyBudget(role, family);
      var count = roomLargeDecorFamilyCounts.get(family);
      if (count == null)
        count = 0;
      if (count < budget)
        return weight;
      if (count == budget)
        return Std.int(weight * 55 / 100);
      if (count == budget + 1)
        return Std.int(weight * 35 / 100);
      return 0;
    }

// get minimum gap required between large decorations of the same family
  function getLargeDecorFamilySpacingRadius(role: String, family: String): Int
    {
      if (family == 'machinery')
        {
          if (role == ROOM_ROLE_WORKSHOP ||
              role == ROOM_ROLE_RESEARCH)
            return 2;
          return 3;
        }
      if (family == 'crate')
        return 2;
      if (family == 'gurney')
        return 3;
      return 2;
    }

// check whether same-family large decorations keep enough local spacing
  function canPlaceLargeDecorFamilyWithSpacing(role: String, x: Int, y: Int,
      block: _IconBlock, family: String,
      roomPlacedLargeDecors: Array<_PlacedLargeDecor>): Bool
    {
      var minGap = getLargeDecorFamilySpacingRadius(role, family);
      var candidateRect = {
        x1: x,
        y1: y,
        x2: x + block.width - 1,
        y2: y + block.height - 1,
      };
      for (placedDecor in roomPlacedLargeDecors)
        {
          if (placedDecor.family != family)
            continue;
          if (getRectEdgeGapChebyshev(candidateRect, {
              x1: placedDecor.x1,
              y1: placedDecor.y1,
              x2: placedDecor.x2,
              y2: placedDecor.y2,
            }) < minGap)
            return false;
        }
      return true;
    }

// pick weighted floor decoration icon metadata
  function pickWeightedFloorDecorMeta(role: String, zone: String): _FloorDecorMeta
    {
      var weightList = [];
      for (floorInfo in UndergroundLab.FLOOR_DECOR_META)
        {
          var weights = getDecorWeights(DECOR_LAYER_FLOOR, role, zone,
            floorInfo.motifs, []);
          var roleAffinity = (floorInfo.roles.indexOf(role) >= 0 ? 130 : 65);
          var weight = Std.int(floorInfo.baseWeight *
            weights.roleWeight *
            weights.zoneWeight *
            weights.motifWeight *
            weights.tagWeight *
            roleAffinity / 10000000000);
          weightList.push(weight);
        }

      var index = pickWeightedIndex(weightList);
      if (index < 0)
        return null;
      return UndergroundLab.FLOOR_DECOR_META[index];
    }

// pick one index by integer weights
  function pickWeightedIndex(weights: Array<Int>): Int
    {
      var total = 0;
      for (weight in weights)
        {
          if (weight <= 0)
            continue;
          total += weight;
        }
      if (total <= 0)
        return -1;

      var roll = Const.roll(1, total);
      var cumulative = 0;
      for (i in 0...weights.length)
        {
          var weight = weights[i];
          if (weight <= 0)
            continue;
          cumulative += weight;
          if (roll <= cumulative)
            return i;
        }
      return -1;
    }

// get combined role/zone/motif weights for one placement decision
  function getDecorWeights(layer: String, role: String,
      zone: String, motifs: Array<String>, tags: Array<String>): _DecorWeights
    {
      return {
        roleWeight: getLayerRoleWeight(layer, role),
        zoneWeight: getLayerZoneWeight(layer, zone),
        motifWeight: getMotifRoleWeight(role, motifs),
        tagWeight: getTagRoleWeight(role, tags),
      };
    }

// get role weight for the decoration layer
  function getLayerRoleWeight(layer: String, role: String): Int
    {
      if (layer == DECOR_LAYER_FLOOR)
        {
          if (role == ROOM_ROLE_ENTRANCE)
            return 80;
          if (role == ROOM_ROLE_VAT)
            return 110;
          if (role == ROOM_ROLE_WORKSHOP)
            return 120;
          if (role == ROOM_ROLE_STORAGE)
            return 100;
          if (role == ROOM_ROLE_RESEARCH)
            return 105;
          return 100;
        }

      if (layer == DECOR_LAYER_NEAR_TOP_WALL)
        {
          if (role == ROOM_ROLE_ENTRANCE)
            return 85;
          if (role == ROOM_ROLE_VAT)
            return 115;
          if (role == ROOM_ROLE_WORKSHOP)
            return 110;
          if (role == ROOM_ROLE_STORAGE)
            return 95;
          if (role == ROOM_ROLE_RESEARCH)
            return 108;
          return 100;
        }

      if (role == ROOM_ROLE_ENTRANCE)
        return 70;
      if (role == ROOM_ROLE_VAT)
        return 115;
      if (role == ROOM_ROLE_WORKSHOP)
        return 120;
      if (role == ROOM_ROLE_STORAGE)
        return 105;
      if (role == ROOM_ROLE_RESEARCH)
        return 110;
      return 100;
    }

// get zone weight for the decoration layer
  function getLayerZoneWeight(layer: String, zone: String): Int
    {
      if (zone == DECOR_ZONE_MISSION_RESERVED)
        return 0;

      if (layer == DECOR_LAYER_FLOOR)
        {
          if (zone == DECOR_ZONE_DOOR_BUFFER)
            return 30;
          if (zone == DECOR_ZONE_TRAFFIC_LANE)
            return 20;
          if (zone == DECOR_ZONE_WALL_EDGE)
            return 120;
          if (zone == DECOR_ZONE_WORK_CORE)
            return 110;
          return 90;
        }

      if (layer == DECOR_LAYER_NEAR_TOP_WALL)
        {
          if (zone == DECOR_ZONE_DOOR_BUFFER)
            return 55;
          if (zone == DECOR_ZONE_TRAFFIC_LANE)
            return 65;
          if (zone == DECOR_ZONE_WALL_EDGE)
            return 125;
          if (zone == DECOR_ZONE_WORK_CORE)
            return 100;
          return 95;
        }

      if (zone == DECOR_ZONE_DOOR_BUFFER)
        return 0;
      if (zone == DECOR_ZONE_TRAFFIC_LANE)
        return 4;
      if (zone == DECOR_ZONE_WALL_EDGE)
        return 190;
      if (zone == DECOR_ZONE_WORK_CORE)
        return 70;
      return 55;
    }

// get motif affinity weight for the room role
  function getMotifRoleWeight(role: String, motifs: Array<String>): Int
    {
      var weight = 100;
      for (motif in motifs)
        {
          if (motif == 'machinery')
            {
              if (role == ROOM_ROLE_WORKSHOP ||
                  role == ROOM_ROLE_VAT)
                weight += 18;
              else weight -= 4;
              continue;
            }
          if (motif == 'storage')
            {
              if (role == ROOM_ROLE_STORAGE)
                weight += 22;
              else if (role == ROOM_ROLE_WORKSHOP)
                weight += 8;
              else weight -= 4;
              continue;
            }
          if (motif == 'research')
            {
              if (role == ROOM_ROLE_RESEARCH)
                weight += 22;
              else if (role == ROOM_ROLE_VAT)
                weight += 8;
              else weight -= 6;
              continue;
            }
          if (motif == 'hazard-marking')
            {
              if (role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_WORKSHOP)
                weight += 15;
              else weight -= 5;
              continue;
            }
          if (motif == 'grime' ||
              motif == 'spill')
            {
              if (role == ROOM_ROLE_ENTRANCE)
                weight -= 10;
              else weight += 6;
              continue;
            }
          if (motif == 'cable')
            {
              if (role == ROOM_ROLE_RESEARCH ||
                  role == ROOM_ROLE_WORKSHOP)
                weight += 14;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight -= 5;
              continue;
            }
          if (motif == 'furniture')
            {
              if (role == ROOM_ROLE_ENTRANCE)
                weight += 16;
              else if (role == ROOM_ROLE_RESEARCH ||
                       role == ROOM_ROLE_STORAGE)
                weight += 6;
              else if (role == ROOM_ROLE_VAT)
                weight -= 8;
              else weight -= 4;
              continue;
            }
          if (motif == 'floor-grate' ||
              motif == 'floor-hatch' ||
              motif == 'glowing-green-grate')
            {
              if (role == ROOM_ROLE_WORKSHOP ||
                  role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_RESEARCH)
                weight += 14;
              else weight -= 5;
              continue;
            }
          if (motif == 'lab-number-marking' ||
              motif == 'section-number-marking')
            {
              if (role == ROOM_ROLE_ENTRANCE ||
                  role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_RESEARCH)
                weight += 10;
              else weight -= 3;
              continue;
            }
          if (motif == 'biohazard-sign')
            {
              if (role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_WORKSHOP)
                weight += 16;
              else weight -= 6;
              continue;
            }
          if (motif == 'scratches' ||
              motif == 'crack')
            {
              if (role == ROOM_ROLE_STORAGE ||
                  role == ROOM_ROLE_WORKSHOP)
                weight += 8;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight -= 6;
              else weight += 2;
              continue;
            }
          if (motif.indexOf('puddle') >= 0)
            {
              if (role == ROOM_ROLE_VAT ||
                  role == ROOM_ROLE_WORKSHOP)
                weight += 9;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight -= 9;
              else weight += 3;
            }
        }
      return Const.clamp(weight, 20, 220);
    }

// get tag affinity weight for the room role
  function getTagRoleWeight(role: String, tags: Array<String>): Int
    {
      var weight = 100;
      for (tag in tags)
        {
          if (tag == 'computer')
            {
              if (role == ROOM_ROLE_RESEARCH)
                weight += 18;
              else if (role == ROOM_ROLE_VAT ||
                       role == ROOM_ROLE_WORKSHOP)
                weight += 12;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight -= 8;
              else weight -= 10;
              continue;
            }
          if (tag == 'table')
            {
              if (role == ROOM_ROLE_WORKSHOP ||
                  role == ROOM_ROLE_RESEARCH ||
                  role == ROOM_ROLE_VAT)
                weight += 12;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight += 2;
              else weight -= 6;
              continue;
            }
          if (tag == 'crate')
            {
              if (role == ROOM_ROLE_STORAGE)
                weight += 22;
              else if (role == ROOM_ROLE_WORKSHOP)
                weight += 10;
              else if (role == ROOM_ROLE_ENTRANCE)
                weight += 4;
              else weight -= 8;
              continue;
            }
          if (tag == 'gurney')
            {
              if (role == ROOM_ROLE_ENTRANCE)
                weight += 16;
              else if (role == ROOM_ROLE_VAT)
                weight += 8;
              else weight -= 8;
              continue;
            }
          if (tag == 'hazmat')
            {
              if (role == ROOM_ROLE_ENTRANCE)
                weight += 18;
              else if (role == ROOM_ROLE_VAT)
                weight += 10;
              else if (role == ROOM_ROLE_WORKSHOP)
                weight += 6;
              else weight -= 6;
              continue;
            }
          if (tag == 'plant' ||
              tag == 'seats')
            {
              if (role == ROOM_ROLE_ENTRANCE)
                weight += 16;
              else if (role == ROOM_ROLE_RESEARCH ||
                       role == ROOM_ROLE_STORAGE)
                weight += 6;
              else weight -= 6;
              continue;
            }
          if (tag == 'rack')
            {
              if (role == ROOM_ROLE_STORAGE ||
                  role == ROOM_ROLE_ENTRANCE)
                weight += 10;
              else weight -= 3;
            }
        }
      return Const.clamp(weight, 20, 240);
    }

// classify tile by semantic room zone for weighted decoration
  function getDecorationZone(context: _RoomDecorContext, x: Int, y: Int): String
    {
      if (isPointInAnyReservedRect(x, y, context.reservedRects))
        return DECOR_ZONE_MISSION_RESERVED;
      if (isInDoorBufferZone(x, y, context.doorRects))
        return DECOR_ZONE_DOOR_BUFFER;
      if (isInTrafficLaneZone(x, y, context.corridorY))
        return DECOR_ZONE_TRAFFIC_LANE;
      if (x == context.room.x1 ||
          x == context.room.x2 ||
          y == context.room.y1 ||
          y == context.room.y2)
        return DECOR_ZONE_WALL_EDGE;
      if (x >= context.room.x1 + 2 &&
          x <= context.room.x2 - 2 &&
          y >= context.room.y1 + 2 &&
          y <= context.room.y2 - 2)
        return DECOR_ZONE_WORK_CORE;
      return DECOR_ZONE_ROOM_GENERIC;
    }

// check whether point is close to any door footprint
  function isInDoorBufferZone(x: Int, y: Int,
      doorRects: Array<{x1: Int, y1: Int, x2: Int, y2: Int}>): Bool
    {
      var pointRect = {
        x1: x,
        y1: y,
        x2: x,
        y2: y,
      };
      for (doorRect in doorRects)
        if (getRectEdgeGapChebyshev(pointRect, doorRect) <= 1)
          return true;
      return false;
    }

// check whether point belongs to the main traffic lane band
  function isInTrafficLaneZone(x: Int, y: Int, corridorY: Int): Bool
    {
      if (x < 0)
        return false;
      return Math.abs(y - corridorY) <= 1;
    }

// check whether point is inside any mission reserved rectangle
  function isPointInAnyReservedRect(x: Int, y: Int,
      reservedRects: Array<_ReservedRect>): Bool
    {
      for (rect in reservedRects)
        if (x >= rect.x1 &&
            x <= rect.x2 &&
            y >= rect.y1 &&
            y <= rect.y2)
          return true;
      return false;
    }

// check whether rectangle overlaps any mission reserved rectangle
  function isRectOverlappingReservedRect(x1: Int, y1: Int, x2: Int, y2: Int,
      reservedRects: Array<_ReservedRect>): Bool
    {
      for (rect in reservedRects)
        {
          if (x2 < rect.x1 ||
              rect.x2 < x1 ||
              y2 < rect.y1 ||
              rect.y2 < y1)
            continue;
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

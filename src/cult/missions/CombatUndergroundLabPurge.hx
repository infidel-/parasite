// combat mission with underground lab and clone vat purge objectives
package cult.missions;

import ai.AI;
import ai.AIData;
import game.Game;
import objects.Elevator;
import objects.mission.CloneVat;
import objects.Stairs;
import cult.missions.Combat.CombatSpawnTarget;

private typedef _MissionHints = {
  @:optional var vatRoomID: Int;
  @:optional var vatDoor: _Point;
  @:optional var vatAnchors: Array<_Point>;
  @:optional var reservedRects: Array<_ReservedRect>;
}

class CombatUndergroundLabPurge extends Combat
{
  static var REQUIRED_VAT_COUNT = 4;
  static var VAT_W = 2;
  static var VAT_H = 3;
  static var RESERVED_KIND_CLONE_VAT = 'clone-vat';

  public var vatObjectIDs: Array<Int>;
  public var flushedVatObjectIDs: Array<Int>;
  public var scientistIDs: Array<Int>;
  public var guardIDs: Array<Int>;
  public var guardData: Array<AIData>;
  public var leadScientistID: Int;
  public var vatRoomID: Int;
  public var vatCenterX: Int;
  public var vatCenterY: Int;
  public var vatDoorX: Int;
  public var vatDoorY: Int;
  public var isInitialized: Bool;
  public var leadTriggerDone: Bool;
  public var guardsSpawned: Bool;

// create underground lab combat mission
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g, combatInfo);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Break Clone Program';
      note = 'Kill the target scientists and purge every clone vat.';

      vatObjectIDs = [];
      flushedVatObjectIDs = [];
      scientistIDs = [];
      guardIDs = [];
      guardData = [];
      leadScientistID = -1;
      vatRoomID = -1;
      vatCenterX = -1;
      vatCenterY = -1;
      vatDoorX = -1;
      vatDoorY = -1;
      isInitialized = false;
      leadTriggerDone = false;
      guardsSpawned = false;
    }

// template-specific initialization
  override function initTemplate(combatInfo: _CombatMissionInfo, targetList: Array<CombatSpawnTarget>)
    {
      var marker = pickMissionMarkerArea();
      if (marker == null)
        throw 'Could not find city marker area for underground lab mission.';

      markerAreaID = marker.id;
      x = marker.x;
      y = marker.y;

      var missionArea = game.region.createArea(AREA_UNDERGROUND_LAB);
      missionArea.parentID = marker.id;
      missionArea.width = 45;
      missionArea.height = 35;
      areaID = missionArea.id;

      splitScientistsAndGuards();
    }

// template-specific turn processing
  override function turnTemplate()
    {
      if (!isInitialized)
        initMissionArea();
      if (!isInitialized)
        return;

      spawnMissingScientists();
      spawnGuards();
      checkLeadScientistTrigger();
    }

// process vat flush callback from clone vat objects
  public function onVatFlushed(vatObjectID: Int)
    {
      if (vatObjectIDs.indexOf(vatObjectID) < 0 ||
          flushedVatObjectIDs.indexOf(vatObjectID) >= 0)
        return;

      flushedVatObjectIDs.push(vatObjectID);
      var remaining = vatObjectIDs.length - flushedVatObjectIDs.length;
      if (remaining > 0)
        game.message({
          text: 'Purged vat ' + flushedVatObjectIDs.length + '/' + REQUIRED_VAT_COUNT + '. The lab stinks of bleach and protein rot.',
          col: 'cult',
        });
      else
        game.message({
          text: 'All vats are draining. The clone floor goes silent.',
          col: 'cult',
        });

      checkMissionComplete();
    }

// handle mission AI deaths
  public override function onEventAI(type: _MissionEvent, ai: AI)
    {
      if (type != ON_AI_DEATH)
        return;

      var scientistIndex = scientistIDs.indexOf(ai.id);
      if (scientistIndex >= 0)
        {
          scientistIDs.splice(scientistIndex, 1);
          var targetIndex = targetIDs.indexOf(ai.id);
          if (targetIndex >= 0)
            targetIDs.splice(targetIndex, 1);
          checkMissionComplete();
          return;
        }

      var guardIndex = guardIDs.indexOf(ai.id);
      if (guardIndex >= 0)
        guardIDs.splice(guardIndex, 1);
    }

// show mission-specific completion message
  public override function onSuccess()
    {
      game.message({
        text: 'The scientists are dead and the vats are ruined. The underground program collapses.',
        col: 'cult',
      });
    }

// split configured target list into objective scientists and non-target guards
  function splitScientistsAndGuards()
    {
      scientistIDs = [];
      guardData = [];

      for (data in targets)
        {
          if (data.type == 'security')
            {
              guardData.push(data);
              continue;
            }
          scientistIDs.push(data.id);
        }

      if (scientistIDs.length == 0)
        throw 'Underground lab mission has no scientist targets.';

      leadScientistID = scientistIDs[0];
      targetIDs = scientistIDs.copy();
    }

// initialize mission objects and anchor points after area generation
  function initMissionArea()
    {
      if (game.area.generatorInfo == null ||
          game.area.generatorInfo.rooms == null ||
          game.area.generatorInfo.rooms.length == 0)
        return;

      var hints = readMissionHints();

      for (o in game.area.getObjects())
        {
          if (o.type == 'elevator')
            {
              var elevator: Elevator = cast o;
              elevator.missionID = id;
            }
          else if (o.type == 'stairs')
            {
              var stairs: Stairs = cast o;
              stairs.missionID = id;
            }
        }

      var vatRoom = pickVatRoomFromHintsOrFallback(game.area.generatorInfo.rooms, hints);
      vatRoomID = vatRoom.id;
      vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
      var vatDoor = pickVatDoorFromHintsOrFallback(vatRoom, hints);
      vatDoorX = vatDoor.x;
      vatDoorY = vatDoor.y;

      if (!game.area.isWalkable(vatDoorX, vatDoorY))
        {
          var fallbackDoor = game.area.findEmptyLocationNear(vatRoom.x1, vatCenterY, 3);
          if (fallbackDoor != null)
            {
              vatDoorX = fallbackDoor.x;
              vatDoorY = fallbackDoor.y;
            }
        }

      if (vatObjectIDs.length == 0)
        if (!spawnCloneVats(vatRoom, hints))
          throw 'Underground lab purge mission failed to place ' + REQUIRED_VAT_COUNT + ' vats.';

      isInitialized = true;
    }

// read typed mission hints from generator metadata
  function readMissionHints(): _MissionHints
    {
      if (game.area.generatorInfo == null ||
          game.area.generatorInfo.missionHints == null)
        return null;
      return game.area.generatorInfo.missionHints;
    }

// spawn any scientist targets that are not yet present in mission area
  function spawnMissingScientists()
    {
      var missing = getMissingTargets();
      for (data in missing)
        {
          var spawn = findScientistSpawnPoint();
          if (spawn == null)
            continue;
          spawnMissionTarget(data, spawn.x, spawn.y);
        }
    }

// spawn non-target guards near vat room entrance once
  function spawnGuards()
    {
      if (guardsSpawned)
        return;

      var preferred = [
        // left of upper/lower vertical door tiles
        { x: vatDoorX - 1, y: vatDoorY },
        { x: vatDoorX - 1, y: vatDoorY + 1 },
      ];
      var fallback = collectWalkablePointsNear(vatDoorX - 1, vatDoorY, 4);
      var leftFallback = [];
      for (spot in fallback)
        if (spot.x == vatDoorX - 1)
          leftFallback.push(spot);
      var spots = mergeUniquePoints(preferred, leftFallback);

      var spotIndex = 0;
      for (data in guardData)
        {
          while (spotIndex < spots.length &&
              !isSpawnPointFree(spots[spotIndex].x, spots[spotIndex].y))
            spotIndex++;
          if (spotIndex >= spots.length)
            continue;
          var point = spots[spotIndex];
          spotIndex++;

          var ai = game.area.spawnAI(data.type, point.x, point.y, false);
          ai.updateData(data, 'on spawn');
          ai.isGuard = true;
          ai.guardTargetX = point.x;
          ai.guardTargetY = point.y;
          game.area.addAI(ai);
          guardIDs.push(ai.id);
        }

      guardsSpawned = true;
    }

// trigger scientist aggro and message when lead scientist sees the player
  function checkLeadScientistTrigger()
    {
      if (leadTriggerDone ||
          leadScientistID < 0)
        return;

      var lead = game.area.getAIByID(leadScientistID);
      if (lead == null ||
          !lead.seesPosition(game.playerArea.x, game.playerArea.y))
        return;

      leadTriggerDone = true;
      game.message({
        text: "We're so close, dammit!",
        col: 'cult',
      });

      for (scientistID in scientistIDs)
        {
          var ai = game.area.getAIByID(scientistID);
          if (ai == null)
            continue;

          ai.setState(AI_STATE_ALERT, REASON_WITNESS);
          if (game.player.state == PLR_STATE_HOST)
            ai.addEnemy(game.player.host);
        }
    }

// spawn required mission vats with hint-first deterministic fallback
  function spawnCloneVats(vatRoom: _Room, hints: _MissionHints): Bool
    {
      var anchors = collectVatAnchorCandidates(vatRoom, hints);
      for (anchor in anchors)
        {
          if (vatObjectIDs.length >= REQUIRED_VAT_COUNT)
            break;
          if (!canPlaceCloneVatAt(anchor.x, anchor.y))
            continue;
          clearFloorDecorationAroundVat(anchor.x, anchor.y, 1);
          if (!canPlaceCloneVatAt(anchor.x, anchor.y))
            continue;
          spawnCloneVatGroup(anchor.x, anchor.y);
        }
      return (vatObjectIDs.length >= REQUIRED_VAT_COUNT);
    }

// choose vat room from generator metadata, fallback to largest room
  function pickVatRoomFromHintsOrFallback(rooms: Array<_Room>,
      hints: _MissionHints): _Room
    {
      if (hints != null &&
          hints.vatRoomID != null)
        {
          var room = game.area.generatorInfo.getRoom(hints.vatRoomID);
          if (room != null)
            return room;
        }
      return pickLargestRoom(rooms);
    }

// choose vat door from metadata, fallback to default room-side door
  function pickVatDoorFromHintsOrFallback(vatRoom: _Room,
      hints: _MissionHints): _Point
    {
      var door = {
        x: vatRoom.x1 - 1,
        y: vatRoom.y1 + Std.int(vatRoom.h / 2),
      };
      if (hints != null &&
          hints.vatDoor != null)
        {
          door.x = hints.vatDoor.x;
          door.y = hints.vatDoor.y;
        }
      return door;
    }

// build default 4-vat anchor formation from vat room center
  function getDefaultVatAnchors(): Array<_Point>
    {
      return [
        { x: vatCenterX - 2, y: vatCenterY - 3 },
        { x: vatCenterX + 1, y: vatCenterY - 3 },
        { x: vatCenterX - 2, y: vatCenterY + 1 },
        { x: vatCenterX + 1, y: vatCenterY + 1 },
      ];
    }

// find one scientist spawn point with near-vat and room-fallback priority
  function findScientistSpawnPoint(): _Point
    {
      var spawn = game.area.findEmptyLocationNear(vatCenterX, vatCenterY, 4);
      if (spawn != null)
        return spawn;
      spawn = game.area.findEmptyLocationNear(vatDoorX, vatDoorY, 4);
      if (spawn != null)
        return spawn;
      spawn = game.area.findEmptyLocationNear(vatCenterX, vatCenterY, 8);
      if (spawn != null)
        return spawn;

      var vatRoom = game.area.generatorInfo.getRoom(vatRoomID);
      if (vatRoom == null)
        return null;
      var roomSpots = collectWalkablePointsNear(vatCenterX, vatCenterY, 10);
      for (spot in roomSpots)
        if (spot.x >= vatRoom.x1 &&
            spot.x <= vatRoom.x2 &&
            spot.y >= vatRoom.y1 &&
            spot.y <= vatRoom.y2)
          return spot;
      return null;
    }

// build deterministic vat anchor candidates from hints and room scan
  function collectVatAnchorCandidates(vatRoom: _Room, hints: _MissionHints): Array<_Point>
    {
      var anchors = [];
      var seen: Map<String, Bool> = new Map<String, Bool>();

      if (hints != null &&
          hints.vatAnchors != null)
        for (anchor in hints.vatAnchors)
          appendUniqueVatAnchor(vatRoom, anchor.x, anchor.y, anchors, seen);

      if (hints != null &&
          hints.reservedRects != null)
        for (rect in hints.reservedRects)
          {
            if (rect.kind != RESERVED_KIND_CLONE_VAT ||
                rect.x2 - rect.x1 != VAT_W - 1 ||
                rect.y2 - rect.y1 != VAT_H - 1)
              continue;
            appendUniqueVatAnchor(vatRoom, rect.x1, rect.y1, anchors, seen);
          }

      for (anchor in getDefaultVatAnchors())
        appendUniqueVatAnchor(vatRoom, anchor.x, anchor.y, anchors, seen);

      var scored = [];
      for (y in vatRoom.y1...vatRoom.y2 + 1)
        for (x in vatRoom.x1...vatRoom.x2 + 1)
          {
            if (!isVatAnchorInsideRoom(vatRoom, x, y))
              continue;
            var dx = x - vatCenterX;
            var dy = y - vatCenterY;
            scored.push({
              x: x,
              y: y,
              d2: dx * dx + dy * dy,
            });
          }
      scored.sort(function(a, b)
        {
          if (a.d2 != b.d2)
            return a.d2 - b.d2;
          if (a.y != b.y)
            return a.y - b.y;
          return a.x - b.x;
        });
      for (spot in scored)
        appendUniqueVatAnchor(vatRoom, spot.x, spot.y, anchors, seen);

      return anchors;
    }

// append vat anchor if it is unique and fully inside the vat room
  function appendUniqueVatAnchor(vatRoom: _Room, x: Int, y: Int,
      anchors: Array<_Point>, seen: Map<String, Bool>)
    {
      if (!isVatAnchorInsideRoom(vatRoom, x, y))
        return;
      var key = x + ':' + y;
      if (seen.exists(key))
        return;
      seen.set(key, true);
      anchors.push({
        x: x,
        y: y,
      });
    }

// check if vat top-left anchor keeps full 2x3 vat inside room bounds
  function isVatAnchorInsideRoom(room: _Room, x: Int, y: Int): Bool
    {
      return (x >= room.x1 &&
        y >= room.y1 &&
        x + VAT_W - 1 <= room.x2 &&
        y + VAT_H - 1 <= room.y2);
    }

// merge two point arrays while preserving order and removing duplicates
  function mergeUniquePoints(primary: Array<_Point>,
      secondary: Array<_Point>): Array<_Point>
    {
      var merged = [];
      var seen: Map<String, Bool> = new Map<String, Bool>();
      for (pt in primary)
        {
          var key = pt.x + ':' + pt.y;
          if (seen.exists(key))
            continue;
          seen.set(key, true);
          merged.push(pt);
        }
      for (pt in secondary)
        {
          var key = pt.x + ':' + pt.y;
          if (seen.exists(key))
            continue;
          seen.set(key, true);
          merged.push(pt);
        }
      return merged;
    }

// collect free walkable points near center sorted by distance
  function collectWalkablePointsNear(cx: Int, cy: Int, radius: Int): Array<_Point>
    {
      var spots = [];
      for (dy in -radius...radius + 1)
        for (dx in -radius...radius + 1)
          {
            var x = cx + dx;
            var y = cy + dy;
            if (!isSpawnPointFree(x, y))
              continue;
            spots.push({
              x: x,
              y: y,
              d2: dx * dx + dy * dy,
            });
          }
      spots.sort(function(a, b)
        {
          if (a.d2 != b.d2)
            return a.d2 - b.d2;
          if (a.y != b.y)
            return a.y - b.y;
          return a.x - b.x;
        });

      var points = [];
      for (spot in spots)
        points.push({
          x: spot.x,
          y: spot.y,
        });
      return points;
    }

// check if a single-tile spawn point is free for mission AI
  function isSpawnPointFree(x: Int, y: Int): Bool
    {
      return (isInAreaBounds(x, y) &&
        game.area.isWalkable(x, y) &&
        game.area.getAI(x, y) == null &&
        !game.area.hasObjectAt(x, y) &&
        (game.playerArea.x != x ||
         game.playerArea.y != y));
    }

// check if tile coordinates are inside current area bounds
  inline function isInAreaBounds(x: Int, y: Int): Bool
    {
      return (x >= 0 &&
        y >= 0 &&
        x < game.area.width &&
        y < game.area.height);
    }

// check if a 2x3 vat can be placed at top-left tile x,y
  function canPlaceCloneVatAt(x: Int, y: Int): Bool
    {
      var tileset = game.scene.images.getTileset(game.area.typeID);
      for (dy in 0...VAT_H)
        for (dx in 0...VAT_W)
          {
            var tx = x + dx;
            var ty = y + dy;
            if (!tileset.isWalkable(game.area.getCellType(tx, ty)) ||
                game.area.hasObjectAt(tx, ty) ||
                game.area.getAI(tx, ty) != null ||
                (game.playerArea.x == tx &&
                 game.playerArea.y == ty))
              return false;
          }
      return true;
    }

// spawn one linked 2x3 vat and register root ID in mission objective list
  function spawnCloneVatGroup(x: Int, y: Int)
    {
      var vats = [];
      for (dy in 0...VAT_H)
        for (dx in 0...VAT_W)
          {
            var partIndex = dy * VAT_W + dx;
            vats.push(new CloneVat(game, game.area.id,
              x + dx, y + dy, id, partIndex));
          }

      var partObjectIDs = [];
      for (vat in vats)
        partObjectIDs.push(vat.id);

      var rootObjectID = vats[0].id;
      for (vat in vats)
        vat.setVatGroup(rootObjectID, partObjectIDs);
      vatObjectIDs.push(rootObjectID);
    }

// clear blocking/object decoration around vat footprint and movement ring
  function clearFloorDecorationAroundVat(x: Int, y: Int, padding: Int)
    {
      var tileset: tiles.UndergroundLab =
        cast game.scene.images.getTileset(game.area.typeID);
      var tiles = game.area.getTiles();
      var tagsToRemove: Map<String, Bool> = new Map<String, Bool>();
      var ringX1 = x - padding;
      var ringY1 = y - padding;
      var ringX2 = x + VAT_W - 1 + padding;
      var ringY2 = y + VAT_H - 1 + padding;
      var vatX2 = x + VAT_W - 1;
      var vatY2 = y + VAT_H - 1;

      // gather decoration object group tags intersecting vat footprint + ring
      for (ty in ringY1...ringY2 + 1)
        for (tx in ringX1...ringX2 + 1)
          {
            if (!isInAreaBounds(tx, ty))
              continue;
            var tile = tiles[tx][ty];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            for (decoration in tile.decoration)
              if (tileset.isDecorationObjLayerID(decoration.layerID) &&
                  decoration.tag != null)
                tagsToRemove[decoration.tag] = true;
          }

      // remove all tagged decoration object tiles across the area
      if (tagsToRemove.keys().hasNext())
        for (ty in 0...game.area.height)
          for (tx in 0...game.area.width)
            {
              var tile = tiles[tx][ty];
              if (tile == null ||
                  tile.decoration == null ||
                  tile.decoration.length == 0)
                continue;

              var kept = [];
              for (decoration in tile.decoration)
                {
                  if (tileset.isDecorationObjLayerID(decoration.layerID) &&
                      decoration.tag != null &&
                      tagsToRemove[decoration.tag])
                    continue;
                  kept.push(decoration);
                }
              if (kept.length == tile.decoration.length)
                continue;
              tile.decoration = kept;
              game.area.recalcTile(tx, ty);
            }

      // clear footprint decorations and blocking ring decorations
      for (ty in ringY1...ringY2 + 1)
        for (tx in ringX1...ringX2 + 1)
          {
            if (!isInAreaBounds(tx, ty))
              continue;
            var tile = tiles[tx][ty];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;

            var tileID = game.area.getCellType(tx, ty);
            var inVatFootprint = (tx >= x &&
              tx <= vatX2 &&
              ty >= y &&
              ty <= vatY2);
            var kept = [];
            for (decoration in tile.decoration)
              {
                if (inVatFootprint)
                  continue;
                if (tileset.isBlockingDecoration(tileID, decoration))
                  continue;
                kept.push(decoration);
              }
            tile.decoration = kept;
            game.area.recalcTile(tx, ty);
          }
    }

// choose the largest room from generator metadata
  function pickLargestRoom(rooms: Array<_Room>): _Room
    {
      var best = rooms[0];
      var bestArea = best.w * best.h;
      for (room in rooms)
        {
          var area = room.w * room.h;
          if (area <= bestArea)
            continue;
          best = room;
          bestArea = area;
        }
      return best;
    }

// complete mission when both objectives are satisfied
  function checkMissionComplete()
    {
      if (scientistIDs.length > 0 ||
          vatObjectIDs.length == 0 ||
          flushedVatObjectIDs.length < vatObjectIDs.length)
        return;
      success();
    }
}

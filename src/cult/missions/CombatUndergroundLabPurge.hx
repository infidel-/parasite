// combat mission with underground lab and clone vat purge objectives
package cult.missions;

import ai.AI;
import ai.AIData;
import game.Game;
import objects.Elevator;
import objects.mission.CloneVat;
import objects.Stairs;
import cult.missions.Combat.CombatSpawnTarget;

private typedef _SpawnSpot = {
  var x: Int;
  var y: Int;
}

class CombatUndergroundLabPurge extends Combat
{
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
          text: 'Purged vat ' + flushedVatObjectIDs.length + '/4. The lab stinks of bleach and protein rot.',
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

      var vatRoom = pickLargestRoom(game.area.generatorInfo.rooms);
      vatRoomID = vatRoom.id;
      vatCenterX = vatRoom.x1 + Std.int(vatRoom.w / 2);
      vatCenterY = vatRoom.y1 + Std.int(vatRoom.h / 2);
      vatDoorX = vatRoom.x1 - 1;
      vatDoorY = vatCenterY;

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
        spawnCloneVats();

      isInitialized = true;
    }

// spawn any scientist targets that are not yet present in mission area
  function spawnMissingScientists()
    {
      var missing = getMissingTargets();
      for (data in missing)
        {
          var spawn = game.area.findEmptyLocationNear(vatCenterX, vatCenterY, 4);
          if (spawn == null)
            spawn = game.area.findEmptyLocationNear(vatDoorX, vatDoorY, 4);
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

      var spots = [
        // left of upper/lower vertical door tiles
        { x: vatDoorX - 1, y: vatDoorY - 1 },
        { x: vatDoorX - 1, y: vatDoorY },
      ];

      for (i in 0...guardData.length)
        {
          if (i >= spots.length)
            continue;

          var data = guardData[i];
          var spot = spots[i];
          if (!game.area.isWalkable(spot.x, spot.y) ||
              game.area.getAI(spot.x, spot.y) != null)
            continue;

          var ai = game.area.spawnAI(data.type, spot.x, spot.y, false);
          ai.updateData(data, 'on spawn');
          ai.isGuard = true;
          ai.guardTargetX = spot.x;
          ai.guardTargetY = spot.y;
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

// spawn four mission vats in a fixed formation inside the vat room
  function spawnCloneVats()
    {
      var offsets = [
        { x: -2, y: -3 },
        { x: 1, y: -3 },
        { x: -2, y: 1 },
        { x: 1, y: 1 },
      ];

      for (offset in offsets)
        {
          var anchorX = vatCenterX + offset.x;
          var anchorY = vatCenterY + offset.y;
          if (!canPlaceCloneVatAt(anchorX, anchorY))
            {
              var fallback = findCloneVatAnchorNear(vatCenterX, vatCenterY, 4);
              if (fallback != null)
                {
                  anchorX = fallback.x;
                  anchorY = fallback.y;
                }
            }

          if (!canPlaceCloneVatAt(anchorX, anchorY))
            continue;
          spawnCloneVatGroup(anchorX, anchorY);
        }
    }

// check if a 2x3 vat can be placed at top-left tile x,y
  function canPlaceCloneVatAt(x: Int, y: Int): Bool
    {
      var tileset = game.scene.images.getTileset(game.area.typeID);
      for (dy in 0...3)
        for (dx in 0...2)
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

// find random valid 2x3 vat anchor near x,y
  function findCloneVatAnchorNear(x: Int, y: Int, radius: Int): _SpawnSpot
    {
      var spots = [];
      for (dy in -radius...radius + 1)
        for (dx in -radius...radius + 1)
          {
            var nx = x + dx;
            var ny = y + dy;
            if (!canPlaceCloneVatAt(nx, ny))
              continue;
            spots.push({ x: nx, y: ny });
          }
      if (spots.length == 0)
        return null;
      return spots[Std.random(spots.length)];
    }

// spawn one linked 2x3 vat and register root ID in mission objective list
  function spawnCloneVatGroup(x: Int, y: Int)
    {
      clearFloorDecorationUnderVat(x, y);

      var vats = [];
      for (dy in 0...3)
        for (dx in 0...2)
          {
            var partIndex = dy * 2 + dx;
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

// clear floor decoration from vat footprint tiles before vat spawn
  function clearFloorDecorationUnderVat(x: Int, y: Int)
    {
      var tileset: tiles.UndergroundLab =
        cast game.scene.images.getTileset(game.area.typeID);
      var tiles = game.area.getTiles();
      var tagsToRemove: Map<String, Bool> = new Map<String, Bool>();

      // gather decoration object group tags intersecting vat footprint
      for (dy in 0...3)
        for (dx in 0...2)
          {
            var tile = tiles[x + dx][y + dy];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            for (decoration in tile.decoration)
              if (decoration.layerID == tileset.decorationObjFloorLayerID &&
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
                  if (decoration.tag != null &&
                      tagsToRemove[decoration.tag])
                    continue;
                  kept.push(decoration);
                }
              tile.decoration = kept;
            }

      // always clear remaining decoration inside the vat footprint
      for (dy in 0...3)
        for (dx in 0...2)
          {
            var tile = tiles[x + dx][y + dy];
            if (tile == null ||
                tile.decoration == null ||
                tile.decoration.length == 0)
              continue;
            tile.decoration = [];
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

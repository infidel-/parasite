// combat mission with summoning ritual template
package cult.missions;

import ai.AI;
import game.Game;
import objects.SewerExit;
import objects.SummoningPortal;
import cult.missions.Combat.CombatSpawnTarget;

private enum _RitualState
{
  PENDING_INIT;     // waiting for room/portal setup
  WAITING;          // initialized, player hasn't approached portal
  WAITING_DAMAGED;  // cultist died before player arrived
  ACTIVE;           // player approached, countdown running
  BREAKING;         // ritual interrupted, collapse timer running
  COMPLETED;        // ritual finished successfully (choir spawned)
  RESOLVED;         // broken ritual resolved (choir may spawn)
}

class CombatSummoningRitual extends Combat
{
  public var state: _RitualState;
  public var ritualTimer: Int;
  public var ritualBreakTimer: Int;
  public var choirSpawned: Bool;
  public var ritualPortalObjectID: Int;
  public var ritualPortalX: Int;
  public var ritualPortalY: Int;
  public var ritualRoomID: Int;

// create a combat mission with summoning ritual
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g, combatInfo);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Stop Ritual';
      note = 'A summoning ritual must be interrupted before it completes.';
      state = PENDING_INIT;
      ritualTimer = 0;
      ritualBreakTimer = 0;
      choirSpawned = false;
      ritualPortalObjectID = -1;
      ritualPortalX = -1;
      ritualPortalY = -1;
      ritualRoomID = -1;
    }

// template-specific initialization
  override function initTemplate(combatInfo: _CombatMissionInfo, targetList: Array<CombatSpawnTarget>)
    {
      var marker = pickMissionMarkerArea();
      if (marker == null)
        throw 'Could not find city marker area for summoning ritual mission.';
      markerAreaID = marker.id;
      x = marker.x;
      y = marker.y;

      var missionArea = game.region.createArea(AREA_SEWERS);
      missionArea.parentID = marker.id;
      missionArea.width = 49;
      missionArea.height = 49;
      areaID = missionArea.id;
    }

// template-specific turn processing
  override function turnTemplate()
    {
      switch (state)
        {
          case PENDING_INIT:
            initSummoningRitual();

          case WAITING, WAITING_DAMAGED:
            spawnMissingRitualTargets();

          case ACTIVE:
            spawnMissingRitualTargets();
            checkAlertBreak();
            tickRitualTimer();

          case BREAKING:
            tickBreakTimer();

          case COMPLETED, RESOLVED:
            {}
        }
    }

// check if any ritual participant is alerted
  function checkAlertBreak()
    {
      for (targetID in targetIDs)
        {
          var ai = game.area.getAIByID(targetID);
          if (ai == null ||
              !ai.wasAlerted)
            continue;
          breakRitual();
          break;
        }
    }

// tick down ritual completion timer
  function tickRitualTimer()
    {
      if (ritualTimer > 0)
        {
          ritualTimer--;
          if (ritualTimer <= 0)
            completeRitual();
        }
    }

// tick down ritual break timer
  function tickBreakTimer()
    {
      ritualBreakTimer--;
      if (ritualBreakTimer <= 0)
        resolveBrokenRitual();
    }

// initialize ritual room, portal and participants
  function initSummoningRitual()
    {
      if (game.area.generatorInfo == null ||
          game.area.generatorInfo.rooms == null ||
          game.area.generatorInfo.rooms.length == 0)
        return;

      // set mission ID on sewer exit objects so they can remove the mission area on use
      for (o in game.area.getObjects())
        if (o.type == 'sewer_exit')
          {
            var exit: SewerExit = cast o;
            exit.missionID = id;
          }

      // pick a random room and get its center
      var rooms = game.area.generatorInfo.rooms;
      var room = rooms[Std.random(rooms.length)];
      ritualRoomID = room.id;
      var centerX = room.x1 + Std.int(room.w / 2);
      var centerY = room.y1 + Std.int(room.h / 2);
      if (!game.area.isWalkable(centerX, centerY) ||
          game.area.hasAI(centerX, centerY))
        {
          var fallback = game.area.findEmptyLocationNear(centerX, centerY, 3);
          if (fallback != null)
            {
              centerX = fallback.x;
              centerY = fallback.y;
            }
        }

      // spawn the summoning portal at the center
      var portal = new SummoningPortal(game, game.area.id, centerX, centerY, id);
      game.area.addObject(portal);
      ritualPortalObjectID = portal.id;
      ritualPortalX = centerX;
      ritualPortalY = centerY;

      // spawn ritual participants around the portal
      spawnMissingRitualTargets();
      state = WAITING;
    }

// start the ritual timer when player approaches the portal
  public function onPortalProximity(portal: SummoningPortal)
    {
      switch (state)
        {
          case WAITING:
            state = ACTIVE;
            ritualTimer = 10;
            game.message({
              text: 'The chant tightens around the stone. Completion is near. Fewer cultists alive, weaker chance to break through.',
              col: 'cult',
            });

          case WAITING_DAMAGED:
            breakRitual();

          default:
            {}
        }
    }

// mark ritual as broken by death or alert
  function breakRitual()
    {
      if (state != WAITING &&
          state != WAITING_DAMAGED &&
          state != ACTIVE)
        return;

      state = BREAKING;
      ritualBreakTimer = 2;
      game.message({
        text: 'The ritual flow is broken. Unforeseen consequences gather.',
        col: 'cult',
      });
    }

// resolve intact ritual completion when timer expires
  function completeRitual()
    {
      if (state != ACTIVE)
        return;

      state = COMPLETED;
      removePortal();
      spawnChoirOfDiscord();
      game.message({
        text: 'The chant closes. The membrane tears.',
        col: 'cult',
      });
    }

// resolve broken ritual after delay
  function resolveBrokenRitual()
    {
      state = RESOLVED;
      removePortal();

      var chance = brokenRitualChoirChance();
      if (Std.random(100) < chance)
        {
          spawnChoirOfDiscord();
          game.message({
            text: 'The membrane tears. A choir of discord spills through.',
            col: 'cult',
          });
        }
      else
        game.message({
          text: 'The membrane yet holds.',
          col: 'cult',
        });
    }

// remove portal object from area
  function removePortal()
    {
      if (ritualPortalObjectID >= 0)
        {
          var portal = game.area.getObject(ritualPortalObjectID);
          if (portal != null)
            game.area.removeObject(portal);
        }
    }

// count currently living ritual cultists in mission area
  function livingRitualCultists(): Int
    {
      if (game.area == null)
        return 0;

      var living = 0;
      for (targetID in targetIDs)
        {
          var ai = game.area.getAIByID(targetID);
          if (ai == null ||
              ai.state == AI_STATE_DEAD)
            continue;
          living++;
        }
      return living;
    }

// get choir spawn chance for broken ritual flow
  function brokenRitualChoirChance(): Int
    {
      var chance = 10 + livingRitualCultists() * 10;
      if (chance > 100)
        chance = 100;
      return chance;
    }

// spawn all currently missing ritual targets around portal
  function spawnMissingRitualTargets()
    {
      if (ritualPortalX < 0 ||
          ritualPortalY < 0)
        return;

      for (t in getMissingTargets())
        {
          var loc = null;
          var attempts = 0;
          while (attempts < 10)
            {
              loc = game.area.findEmptyLocationNear(ritualPortalX, ritualPortalY, 4);
              if (loc == null)
                break;
              // don't spawn on top of portal
              if (loc.x != ritualPortalX || loc.y != ritualPortalY)
                break;
              attempts++;
            }
          if (loc == null)
            return;
          spawnMissionTarget(t, loc.x, loc.y);
        }
    }

// spawn choir near the ritual site and keep only one instance per mission
  function spawnChoirOfDiscord(): Bool
    {
      if (choirSpawned)
        return true;
      if (game.area == null)
        return false;
      if (areaID >= 0 &&
          game.area.id != areaID)
        return false;

      // check if choir is already present for some reason
      for (ai in game.area.getAllAI())
        if (ai.type == 'choirOfDiscord' &&
            ai.state != AI_STATE_DEAD)
          {
            choirSpawned = true;
            return true;
          }

      // spawn choir at portal location or fallback to player area if portal is missing for some reason
      var anchorX = ritualPortalX;
      var anchorY = ritualPortalY;
      if (anchorX < 0 ||
          anchorY < 0)
        {
          anchorX = game.playerArea.x;
          anchorY = game.playerArea.y;
        }

      // spawn choir a bit away from the portal
      var loc = game.area.findEmptyLocationNear(anchorX, anchorY, 3);
      if (loc == null)
        return false;

      // spawn the choir
      var choir = game.area.spawnAI('choirOfDiscord', loc.x, loc.y, false);
      game.area.addAI(choir);
      choirSpawned = true;
      return true;
    }

// handle mission target death
  public override function onEventAI(type: _MissionEvent, ai: AI)
    {
      if (type != ON_AI_DEATH)
        return;
      var idx = targetIDs.indexOf(ai.id);
      if (idx < 0)
        return;
      targetIDs.splice(idx, 1);

      switch (state)
        {
          case WAITING:
            state = WAITING_DAMAGED;

          case ACTIVE:
            breakRitual();

          default:
            {}
        }

      if (targetIDs.length == 0)
        success();
    }

// show ritual-specific completion message
  public override function onSuccess()
    {
      if (ritualPortalObjectID >= 0 &&
          game.area != null &&
          game.area.id == areaID)
        {
          var portal = game.area.getObject(ritualPortalObjectID);
          if (portal != null)
            game.area.removeObject(portal);
        }
      if (state == COMPLETED)
        {
          spawnChoirOfDiscord();
          game.message({
            text: 'The ritual is complete. The membrane tears and a discordant hymn spills through.',
            col: 'cult',
          });
        }
      else
        game.message({
          text: 'The circle is silent. The membrane shudders in the dark.',
          col: 'cult',
        });
    }
}

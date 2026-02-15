// combat mission with summoning ritual template
package cult.missions;

import ai.AI;
import game.Game;
import objects.SewerExit;
import objects.SummoningPortal;
import cult.missions.Combat.CombatSpawnTarget;

class CombatSummoningRitual extends Combat
{
  public var ritualStarted: Bool;
  public var ritualTimer: Int;
  public var ritualBroken: Bool;
  public var ritualBreakPending: Bool;
  public var ritualBreakTimer: Int;
  public var ritualCompleted: Bool;
  public var ritualResolved: Bool;
  public var choirSpawned: Bool;
  public var ritualInitDone: Bool;
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
      ritualStarted = false;
      ritualTimer = 0;
      ritualBroken = false;
      ritualBreakPending = false;
      ritualBreakTimer = 0;
      ritualCompleted = false;
      ritualResolved = false;
      choirSpawned = false;
      ritualInitDone = false;
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
      if (!ritualInitDone)
        {
          initSummoningRitual();
          if (!ritualInitDone)
            return;
        }

      spawnMissingRitualTargets();

      if (!ritualStarted)
        return;

      if (ritualBreakPending &&
          !ritualBroken)
        breakRitual();

      if (!ritualBroken)
        for (targetID in targetIDs)
          {
            var ai = game.area.getAIByID(targetID);
            if (ai == null ||
                !ai.wasAlerted)
              continue;
            breakRitual();
            break;
          }

      if (!ritualBroken &&
          ritualTimer > 0)
        {
          ritualTimer--;
          if (ritualTimer <= 0)
            completeRitual();
        }

      if (ritualBroken &&
          !ritualResolved)
        {
          ritualBreakTimer--;
          if (ritualBreakTimer <= 0)
            resolveBrokenRitual();
        }
    }

// initialize ritual room, portal and participants
  function initSummoningRitual()
    {
      if (game.area.generatorInfo == null ||
          game.area.generatorInfo.rooms == null ||
          game.area.generatorInfo.rooms.length == 0)
        return;

      for (o in game.area.getObjects())
        if (o.type == 'sewer_exit')
          {
            var exit: SewerExit = cast o;
            exit.missionID = id;
          }

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

      var portal = new SummoningPortal(game, game.area.id, centerX, centerY, id);
      game.area.addObject(portal);
      ritualPortalObjectID = portal.id;
      ritualPortalX = centerX;
      ritualPortalY = centerY;

      spawnMissingRitualTargets();
      ritualInitDone = true;
    }

// start the ritual timer when player approaches the portal
  public function onPortalProximity(portal: SummoningPortal)
    {
      if (ritualStarted)
        return;

      ritualStarted = true;
      ritualTimer = 10;
      if (ritualBreakPending)
        breakRitual();
      game.message({
        text: 'The chant tightens around the stone. Completion is near. Fewer cultists alive, weaker chance to break through.',
        col: 'cult',
      });
    }

// mark ritual as broken by death or alert
  function breakRitual()
    {
      if (ritualBroken ||
          ritualCompleted)
        return;

      ritualBroken = true;
      ritualBreakPending = false;
      ritualBreakTimer = 2;
      game.message({
        text: 'The ritual flow is broken. Unforeseen consequences gather.',
        col: 'cult',
      });
    }

// resolve intact ritual completion when timer expires
  function completeRitual()
    {
      if (ritualCompleted)
        return;
      ritualCompleted = true;
      ritualResolved = true;

      if (ritualPortalObjectID >= 0)
        {
          var portal = game.area.getObject(ritualPortalObjectID);
          if (portal != null)
            game.area.removeObject(portal);
        }

      spawnChoirOfDiscord();
      game.message({
        text: 'The chant closes. The membrane tears.',
        col: 'cult',
      });
    }

// resolve broken ritual after delay
  function resolveBrokenRitual()
    {
      ritualResolved = true;
      if (ritualPortalObjectID >= 0)
        {
          var portal = game.area.getObject(ritualPortalObjectID);
          if (portal != null)
            game.area.removeObject(portal);
        }

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
          var loc = game.area.findEmptyLocationNear(ritualPortalX, ritualPortalY, 4);
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

      for (ai in game.area.getAllAI())
        if (ai.type == 'choirOfDiscord' &&
            ai.state != AI_STATE_DEAD)
          {
            choirSpawned = true;
            return true;
          }

      var anchorX = ritualPortalX;
      var anchorY = ritualPortalY;
      if (anchorX < 0 ||
          anchorY < 0)
        {
          anchorX = game.playerArea.x;
          anchorY = game.playerArea.y;
        }

      var loc = game.area.findEmptyLocationNear(anchorX, anchorY, 3);
      if (loc == null)
        return false;

      var choir = game.area.spawnAI('choirOfDiscord', loc.x, loc.y, false);
      choir.isGuard = true;
      choir.guardTargetX = loc.x;
      choir.guardTargetY = loc.y;
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

      if (!ritualBroken &&
          !ritualCompleted)
        {
          if (ritualStarted)
            breakRitual();
          else ritualBreakPending = true;
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
      if (ritualCompleted)
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

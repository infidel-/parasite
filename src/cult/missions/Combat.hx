// combat mission with clustered and ritual templates
package cult.missions;

import ai.*;
import cult.Mission;
import game.AreaGame;
import game.Game;
import objects.SewerExit;
import objects.SummoningPortal;

private typedef _CombatSpawnTarget = {
  var target: _MissionTarget;
  var loadout: Game -> AIData -> _Difficulty -> Void;
}

class Combat extends Mission
{
  public var template: _CombatMissionTemplate;
  public var primaryTarget: AIData;
  public var targets: Array<AIData>;
  public var targetIDs: Array<Int>;
  public var clusterX: Int;
  public var clusterY: Int;

  // ritual state
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

// create a combat mission with configured template
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g);
      init();
      initPost(false);

      if (combatInfo == null)
        throw 'Combat mission info not provided.';

      // default template
      template = combatInfo.template;
      if (template == null)
        template = TARGET_WITH_GUARDS;

      // roll difficulty if unset
      if (difficulty == null ||
          difficulty == UNSET)
        difficulty = rollDifficulty();

      // resolve target list from configured entries and difficulty amounts
      var targetList = expandTargetsForDifficulty(combatInfo.targets, difficulty);
      if (targetList.length == 0)
        throw 'Combat mission has no targets for selected difficulty.';

      // pick mission target language if unset
      if (targetList[0].target.lang == null ||
          targetList[0].target.lang == '')
        targetList[0].target.lang = game.lang.getRandomID();
      lang = targetList[0].target.lang;
      for (entry in targetList)
        if (entry.target.lang == null ||
            entry.target.lang == '')
          entry.target.lang = lang;

      // build target records used by both templates
      for (i in 0...targetList.length)
        {
          var entry = targetList[i];
          var ai = game.createAI(entry.target.type, 0, 0);
          var data = ai.cloneData();
          data.applyTargetInfo(entry.target);
          data.lang = entry.target.lang;
          data.isGuard = true;
          if (entry.loadout != null)
            entry.loadout(game, data, difficulty);
          if (i == 0)
            {
              data.isNameKnown = true;
              primaryTarget = data;
            }
          targets.push(data);
          targetIDs.push(data.id);
        }

      // pick mission marker / mission area by template
      switch (template)
        {
          case TARGET_WITH_GUARDS:
            var area = game.region.getMissionArea(targetList[0].target);
            if (area != null)
              {
                x = area.x;
                y = area.y;
              }
          case SUMMONING_RITUAL:
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
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Combat Mission';
      note = 'Multiple targets guard a single location.';
      targets = [];
      targetIDs = [];
      clusterX = -1;
      clusterY = -1;
      difficulty = UNSET;

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

// turn hook for combat mission
  public override function turn()
    {
      if (game.location != LOCATION_AREA)
        return;
      if (game.area == null)
        return;
      if (areaID >= 0)
        {
          if (game.area.id != areaID)
            return;
        }
      else if (game.area.x != x ||
          game.area.y != y)
        return;
      if (targetIDs.length == 0)
        return;

      switch (template)
        {
          case TARGET_WITH_GUARDS:
            turnTargetsWithGuards();
          case SUMMONING_RITUAL:
            turnSummoningRitual();
        }
    }

// handle clustered guard mission spawn loop
  function turnTargetsWithGuards()
    {
      var missing = getMissingTargets();
      if (missing.length == 0)
        return;

      // resolve cluster center
      if (clusterX < 0 ||
          clusterY < 0)
        {
          var center = game.area.findUnseenEmptyLocation();
          if (center.x < 0)
            center = game.area.findEmptyLocationNear(
              game.playerArea.x, game.playerArea.y, 5);
          if (center == null)
            return;
          clusterX = center.x;
          clusterY = center.y;
        }

      // spawn missing targets near the cluster center
      for (t in missing)
        {
          var loc = game.area.findEmptyLocationNear(clusterX, clusterY, 2);
          if (loc == null)
            return;
          spawnMissionTarget(t, loc.x, loc.y);
        }
    }

// run summoning ritual mission logic
  function turnSummoningRitual()
    {
      if (!ritualInitDone)
        {
          initSummoningRitual();
          if (!ritualInitDone)
            return;
        }

      // keep spawning unresolved targets if initial placement was cramped
      spawnMissingRitualTargets();

      // ritual can only break after it has started
      if (!ritualStarted)
        return;

      if (ritualBreakPending &&
          !ritualBroken)
        breakRitual();

      // detect alerted participants
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

      // count down active ritual timer while intact
      if (!ritualBroken &&
          ritualTimer > 0)
        {
          ritualTimer--;
          if (ritualTimer <= 0)
            completeRitual();
        }

      // broken flow countdown to portal collapse
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

      // stamp mission ID onto exits for cleanup after completion
      for (o in game.area.getObjects())
        if (o.type == 'sewer_exit')
          {
            var exit: SewerExit = cast o;
            exit.missionID = id;
          }

      // pick ritual room and portal location
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

// collect mission targets that should be present but are missing in area
  function getMissingTargets(): Array<AIData>
    {
      var missing = [];
      for (t in targets)
        {
          if (targetIDs.indexOf(t.id) < 0)
            continue;
          var targetAI = game.area.getAIByID(t.id);
          if (targetAI == null)
            missing.push(t);
        }
      return missing;
    }

// spawn one mission target and mark it as guarded objective
  function spawnMissionTarget(data: AIData, x: Int, y: Int)
    {
      var ai = game.area.spawnAI(data.type, x, y, false);
      ai.updateData(data, 'on spawn');
      ai.isGuard = true;
      ai.guardTargetX = x;
      ai.guardTargetY = y;
      game.area.addAI(ai);
      ai.entity.setMissionTarget();
      game.debug('Combat target ' + data.TheName() + ' has appeared in the mission area at (' + x + ',' + y + ').');
    }

// pick a free city tile that can host a mission marker
  function pickMissionMarkerArea(): AreaGame
    {
      var candidates = [];
      for (area in game.region)
        {
          if (area.x < 0 ||
              area.y < 0)
            continue;
          if (area.typeID != AREA_CITY_LOW &&
              area.typeID != AREA_CITY_MEDIUM &&
              area.typeID != AREA_CITY_HIGH)
            continue;
          if (area.events.length > 0)
            continue;
          if (game.cults[0].ordeals.getMarkerMission(area) != null)
            continue;
          candidates.push(area);
        }

      if (candidates.length > 0)
        return candidates[Std.random(candidates.length)];

      // fallback: allow city areas with events
      for (area in game.region)
        {
          if (area.x < 0 ||
              area.y < 0)
            continue;
          if (area.typeID != AREA_CITY_LOW &&
              area.typeID != AREA_CITY_MEDIUM &&
              area.typeID != AREA_CITY_HIGH)
            continue;
          if (game.cults[0].ordeals.getMarkerMission(area) != null)
            continue;
          candidates.push(area);
        }

      if (candidates.length == 0)
        return null;
      return candidates[Std.random(candidates.length)];
    }

// get custom name for display
  public override function customName(): String
    {
      if (primaryTarget != null)
        return name + ' - ' + primaryTarget.TheName();
      return name;
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

      if (template == SUMMONING_RITUAL &&
          !ritualBroken &&
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
      if (template != SUMMONING_RITUAL)
        return;

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

// roll mission difficulty based on configured odds
  function rollDifficulty(): _Difficulty
    {
      var roll = Std.random(100);
      if (roll < 70)
        return NORMAL;
      if (roll < 90)
        return EASY;
      return HARD;
    }

// expand configured combat target entries for selected difficulty
  function expandTargetsForDifficulty(entries: Array<_CombatMissionTargetInfo>, difficulty: _Difficulty): Array<_CombatSpawnTarget>
    {
      var expanded = [];
      var idx = 1;
      switch (difficulty)
        {
          case EASY:
            idx = 0;
          case NORMAL:
            idx = 1;
          case HARD:
            idx = 2;
          default:
            idx = 1;
        }
      for (entry in entries)
        {
          var amount = entry.amount[idx];
          for (_ in 0...amount)
            expanded.push({
              target: cloneTarget(entry.target),
              loadout: entry.loadout,
            });
        }
      return expanded;
    }

// clone target info to avoid mutating constant target data
  function cloneTarget(target: _MissionTarget): _MissionTarget
    {
      return {
        isMale: target.isMale,
        job: target.job,
        icon: target.icon,
        type: target.type,
        lang: target.lang,
        location: target.location,
        helpAvailable: target.helpAvailable,
      };
    }
}

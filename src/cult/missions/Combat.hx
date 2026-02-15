// combat mission with clustered and ritual templates
package cult.missions;

import ai.*;
import cult.Mission;
import game.AreaGame;
import game.Game;
import objects.SewerExit;
import objects.SummoningPortal;

typedef CombatSpawnTarget = {
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

// create a combat mission with configured template
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g);
      init();
      initPost(false);

      if (combatInfo == null)
        throw 'Combat mission info not provided.';

      template = combatInfo.template;
      if (template == null)
        template = TARGET_WITH_GUARDS;

      if (difficulty == null ||
          difficulty == UNSET)
        difficulty = rollDifficulty();

      var targetList = expandTargetsForDifficulty(combatInfo.targets, difficulty);
      if (targetList.length == 0)
        throw 'Combat mission has no targets for selected difficulty.';

      if (targetList[0].target.lang == null ||
          targetList[0].target.lang == '')
        targetList[0].target.lang = game.lang.getRandomID();
      lang = targetList[0].target.lang;
      for (entry in targetList)
        if (entry.target.lang == null ||
            entry.target.lang == '')
          entry.target.lang = lang;

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

      initTemplate(combatInfo, targetList);
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
    }

// template-specific initialization (override in subclasses)
  function initTemplate(combatInfo: _CombatMissionInfo, targetList: Array<CombatSpawnTarget>)
    {}

// template-specific turn processing (override in subclasses)
  function turnTemplate()
    {}

// turn hook for combat mission
  public override function turn()
    {
      // combat missions are only active in mission area
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

      turnTemplate();
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

      if (targetIDs.length == 0)
        success();
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
  function expandTargetsForDifficulty(entries: Array<_CombatMissionTargetInfo>, difficulty: _Difficulty): Array<CombatSpawnTarget>
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

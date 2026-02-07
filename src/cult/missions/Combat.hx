// combat mission with clustered targets
package cult.missions;

import game.Game;
import cult.Mission;
import ai.*;

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

// create a combat mission with clustered targets
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g);
      init();
      initPost(false);

      if (combatInfo == null)
        throw 'Combat mission info not provided.';

      // default template
      this.template = combatInfo.template;
      if (this.template == null)
        this.template = TARGET_WITH_GUARDS;

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

      // build targets for the selected template
      switch (this.template)
        {
          case TARGET_WITH_GUARDS:
            // create primary target and guards
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
        }

      // pick area based on target location
      var area = game.region.getMissionArea(targetList[0].target);
      if (area != null)
        {
          x = area.x;
          y = area.y;
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
    }

// turn hook for combat mission
  public override function turn()
    {
      if (game.location != LOCATION_AREA) return;
      if (game.area == null) return;
      if (game.area.x != x ||
          game.area.y != y)
        return;
      if (targetIDs.length == 0)
        return;

      // collect missing targets
      var missing: Array<AIData> = [];
      for (t in targets)
        if (targetIDs.indexOf(t.id) >= 0)
          {
            var targetAI = game.area.getAIByID(t.id);
            if (targetAI == null)
              missing.push(t);
          }
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
          var ai = game.area.spawnAI(t.type, loc.x, loc.y, false);
          ai.updateData(t, 'on spawn');
          ai.isGuard = true;
          ai.guardTargetX = loc.x;
          ai.guardTargetY = loc.y;
          game.area.addAI(ai);
          ai.entity.setMissionTarget();
          game.debug('Combat target ' + t.TheName() + ' has appeared in the mission area.');
        }
    }

// get custom name for display
  public override function customName(): String
    {
      if (primaryTarget != null)
        return name + ' - ' + primaryTarget.TheName();
      return name;
    }

// handle mission target death
  public override function onEventAI(type:_MissionEvent, ai: AI)
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

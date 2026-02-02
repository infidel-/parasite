// combat mission with clustered targets
package cult.missions;

import game.Game;
import cult.Mission;
import ai.*;

class Combat extends Mission
{
  public var targetInfo: _MissionTarget;
  public var targetsInfo: Array<_MissionTarget>;
  public var template: _CombatMissionTemplate;
  public var primaryTarget: AIData;
  public var targets: Array<AIData>;
  public var targetIDs: Array<Int>;
  public var clusterX: Int;
  public var clusterY: Int;

// create a combat mission with clustered targets
  public function new(g: Game, targetInfo: _MissionTarget, template: _CombatMissionTemplate, targetsInfo: Array<_MissionTarget>)
    {
      this.targetInfo = targetInfo;
      this.template = template;
      this.targetsInfo = targetsInfo;
      super(g);
      init();
      initPost(false);

      // default template
      if (this.template == null)
        this.template = TARGET_WITH_GUARDS;

      // resolve target list and validate template count
      var targetList: Array<_MissionTarget> = null;
      if (this.targetsInfo != null &&
          this.targetsInfo.length > 0)
        {
          var expected = getTemplateTargetCount(this.template);
          if (this.targetsInfo.length != expected)
            throw 'Combat mission targets mismatch: expected ' + expected +
              ', got ' + this.targetsInfo.length + '.';
          targetList = this.targetsInfo;
        }
      else
        {
          if (this.targetInfo == null)
            throw 'Combat mission target info not provided.';
          targetList = [ this.targetInfo ];
        }

      // pick mission target language if unset
      if (targetList[0].lang == null ||
          targetList[0].lang == '')
        targetList[0].lang = game.lang.getRandomID();
      lang = targetList[0].lang;
      for (t in targetList)
        if (t.lang == null || t.lang == '')
          t.lang = lang;

      // roll difficulty if unset
      if (difficulty == null ||
          difficulty == UNSET)
        difficulty = rollDifficulty();

      // build targets for the selected template
      switch (this.template)
        {
          case TARGET_WITH_GUARDS:
            // create primary target and guards
            for (i in 0...targetList.length)
              {
                var entry = targetList[i];
                var ai = game.createAI(entry.type, 0, 0);
                var data = ai.cloneData();
                data.applyTargetInfo(entry);
                data.lang = entry.lang;
                data.isGuard = true;
                applyLoadout(data, i == 0);
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
      var area = game.region.getMissionArea(targetList[0]);
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

// get expected target count for template
  function getTemplateTargetCount(template: _CombatMissionTemplate): Int
    {
      switch (template)
        {
          case TARGET_WITH_GUARDS:
            return 3;
          default:
            return 1;
        }
    }

// apply difficulty-based loadout to a target
  function applyLoadout(aiData: AIData, isPrimary: Bool)
    {
      // adjust inventory and skills per difficulty
      switch (difficulty)
        {
          case EASY:
            // guards have no guns on easy
            if (!isPrimary)
              {
                while (aiData.inventory.has('pistol'))
                  aiData.inventory.remove('pistol');
              }
          case NORMAL:
            1;
          case HARD:
            if (isPrimary)
              {
                if (!aiData.inventory.has('pistol'))
                  aiData.inventory.addID('pistol');
                aiData.skills.addID(SKILL_PISTOL, 20 + Std.random(10));
              }
            else
              {
                if (!aiData.inventory.has('pistol'))
                  aiData.inventory.addID('pistol');
                if (aiData.inventory.clothing.id != 'kevlarArmor')
                  aiData.inventory.addID('kevlarArmor', true);
                aiData.skills.addID(SKILL_PISTOL, 60 + Std.random(20));
              }
          default:
        }
    }
}

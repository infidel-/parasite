// combat mission with clustered targets
package cult.missions;

import game.Game;
import cult.Mission;
import ai.*;

class Combat extends Mission
{
  public var targetInfo: _MissionTarget;
  public var template: _CombatMissionTemplate;
  public var primaryTarget: AIData;
  public var targets: Array<AIData>;
  public var targetIDs: Array<Int>;
  public var clusterX: Int;
  public var clusterY: Int;

// create a combat mission with clustered targets
  public function new(g: Game, ?targetInfo: _MissionTarget, ?template: _CombatMissionTemplate)
    {
      this.targetInfo = targetInfo;
      this.template = template;
      super(g);
      init();
      initPost(false);

      // roll difficulty if unset
      if (difficulty == null ||
          difficulty == UNSET)
        difficulty = rollDifficulty();

      // default template
      if (this.template == null)
        this.template = TARGET_WITH_GUARDS;

      // build targets for the selected template
      switch (this.template)
        {
          case TARGET_WITH_GUARDS:
            // create primary target
            var ai = game.createAI(targetInfo.type, 0, 0);
            primaryTarget = ai.cloneData();
            primaryTarget.isNameKnown = true;
            primaryTarget.applyTargetInfo(targetInfo);
            primaryTarget.isGuard = true;
            applyLoadout(primaryTarget, true);
            targets.push(primaryTarget);
            targetIDs.push(primaryTarget.id);

            // create guards
            for (i in 0...2)
              {
                var guardAI = game.createAI('security', 0, 0);
                var guard = guardAI.cloneData();
                guard.isGuard = true;
                applyLoadout(guard, false);
                targets.push(guard);
                targetIDs.push(guard.id);
              }
        }

      // pick area based on target location
      var area = game.region.getMissionArea(targetInfo);
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

// apply difficulty-based loadout to a target
  function applyLoadout(aiData: AIData, isPrimary: Bool)
    {
      // adjust inventory and skills per difficulty
      switch (difficulty)
        {
          case EASY:
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

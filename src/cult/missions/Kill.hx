// kill mission sample
package cult.missions;

import game.Game;
import cult.Mission;
import ai.*;

class Kill extends Mission
{
  public var target: AIData;
  public var targetInfo: _MissionTarget;

  public function new(g: Game, ?targetInfo: _MissionTarget)
    {
      // used only in init
      this.targetInfo = targetInfo;
      super(g);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = MISSION_KILL;
      name = 'Eliminate Target';
      note = 'A specific target must be eliminated.';
      
      // create random civilian AI and clone its data
      var ai = game.createAI(targetInfo.type, 0, 0);
      target = ai.cloneData();
      target.isNameKnown = true;
      
      // apply target info if provided
      if (targetInfo != null)
        target.applyTargetInfo(targetInfo);
      
      // pick area based on target location
      var area = game.region.getMissionArea(targetInfo);
      if (area != null)
        {
          x = area.x;
          y = area.y;
        }
    }

// turn hook for kill mission
  public override function turn()
    {
      if (game.location != LOCATION_AREA) return;
      if (game.area == null) return;
      if (game.area.x != x || game.area.y != y)
        return;

      // return if target already spawned
      var targetAI = game.area.getAIByID(target.id);
      if (targetAI != null) return;

      // return if cannot find spawn location
      var loc = game.area.findUnseenEmptyLocation();
      if (loc.x < 0)
        loc = game.area.findEmptyLocationNear(
          game.playerArea.x, game.playerArea.y, 5);
      if (loc == null) return;

      // spawn target AI
      var ai = game.area.spawnAI(target.type, loc.x, loc.y, false);
      ai.updateData(target, 'on spawn');
      game.area.addAI(ai);
      ai.entity.setMissionTarget();
      game.debug('Target ' + target.TheName() + ' has appeared in the mission area.');
    }


// get custom name for display
  public override function customName(): String
    {
      if (target != null)
        return name + ' - ' + target.TheName();
      return name;
    }

// handle mission target death
  public override function onEventAI(type:_MissionEvent, ai: AI)
    {
      if (type != ON_AI_DEATH ||
          ai.id != target.id)
        return;
      success(); // complete the mission
    }
}

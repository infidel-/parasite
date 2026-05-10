// mission where the group team attacks the player cult base
package cult.missions;

import ai.*;
import cult.Mission;
import game.Game;

class TeamBaseDefense extends Mission
{
  public var targetIDs: Array<Int>;
  public var spawned: Bool;

  public function new(g: Game, areaID: Int)
    {
      super(g);
      init();
      initPost(false);
      this.areaID = areaID;
      markerAreaID = areaID;
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Base Defense (Group)';
      note = 'Defeat the team before Cor Nefandum falls.';
      targetIDs = [];
      spawned = false;
    }

// spawn and drive team attackers
  public override function turn()
    {
      if (game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.id != areaID)
        return;
      if (!spawned)
        spawnAttackers();
      BaseDefenseLogic.commandAttackers(game, targetIDs);
      checkComplete();
    }

// handles AI death events
  public override function onEventAI(type: _MissionEvent, ai: AI)
    {
      if (type != ON_AI_DEATH)
        return;
      targetIDs.remove(ai.id);
      checkComplete();
    }

// completes linked team base-defense ordeal
  public override function onSuccess()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      base.activeDefenseMissionID = -1;
      base.activeDefenseTimer = 0;
      base.defensesSurvived++;
      BaseDefenseLogic.loadBodiesIntoStorage(game);
      game.group.onRepelAmbush();
    }

// spawns team blackops from sewer-style arrival points
  function spawnAttackers()
    {
      spawned = true;
      var base = game.cults[0].base;
      var heart = base != null ? base.getHeart() : null;
      var near = heart != null ?
        { x: heart.x, y: heart.y } :
        { x: game.playerArea.x, y: game.playerArea.y };
      for (_ in 0...game.group.team.size)
        {
          var loc = game.area.findArriveLocation({
            near: near,
            radius: 10,
            fallbackRadius: 5
          });
          if (loc == null)
            continue;
          var ai = game.area.spawnAI('blackops', loc.x, loc.y);
          ai.isGuard = true;
          ai.isAggressive = true;
          ai.isRelentless = true;
          ai.setState(AI_STATE_ALERT);
          targetIDs.push(ai.id);
        }
      game.logsg('The team breaches the base.');
    }

// completes mission when all attackers are gone
  function checkComplete()
    {
      if (!spawned ||
          targetIDs.length > 0)
        return;
      success();
    }
}

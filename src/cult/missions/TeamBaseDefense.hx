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
      setMarkerAreaID(areaID);
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = N('Base Defense (Group)');
      note = N('Defeat the team before Cor Nefandum falls.');
      targetIDs = [];
      spawned = false;
    }

// spawns team attackers before area AI turns, again when the wave vanished without dying
  public override function turnPreAI()
    {
      if (spawned &&
          BaseDefenseLogic.waveGone(game, targetIDs))
        {
          targetIDs = [];
          spawned = false;
        }
      if (!spawned)
        spawnAttackers();
    }

// drive one team attacker during its AI turn
  public override function turnAI(ai: AI): Bool
    {
      for (id in targetIDs)
        if (id == ai.id)
          {
            BaseDefenseLogic.commandAttacker(game, ai);
            return true;
          }
      return false;
    }

// check mission progress
  public override function turn()
    {
      if (game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.id != areaID)
        return;
      checkComplete();
    }

// handles AI death events
  public override function onEventAI(type: _MissionEvent, ai: AI)
    {
      if (type != ON_AI_DEATH)
        return;
      // the mission ends on the next turn(): the dead attacker's body is made after this event
      targetIDs.remove(ai.id);
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
      BaseDefenseLogic.calmAreaAI(game);
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
      game.logsg(T('The team breaches the base.'));
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

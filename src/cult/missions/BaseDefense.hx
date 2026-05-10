// mission that attacks the player cult base
package cult.missions;

import ai.*;
import cult.Mission;
import game.Game;

class BaseDefense extends Mission
{
  public var targetIDs: Array<Int>;
  public var spawned: Bool;
  public var cultID: Int;

  public function new(g: Game, areaID: Int, ?cultID: Int = -1)
    {
      super(g);
      init();
      this.cultID = cultID;
      initPost(false);
      this.areaID = areaID;
      markerAreaID = areaID;
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Base Defense';
      note = 'Defeat all attackers before Cor Nefandum falls.';
      targetIDs = [];
      spawned = false;
      cultID = -1;
    }

// spawn and drive attackers
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

// completes linked base-defense ordeal
  public override function onSuccess()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      base.activeDefenseMissionID = -1;
      base.activeDefenseTimer = 0;
      base.defensesSurvived++;
      BaseDefenseLogic.loadBodiesIntoStorage(game);
    }

// spawns attackers from sewer-style arrival points
  function spawnAttackers()
    {
      spawned = true;
      var base = game.cults[0].base;
      var heart = base != null ? base.getHeart() : null;
      var near = heart != null ?
        { x: heart.x, y: heart.y } :
        { x: game.playerArea.x, y: game.playerArea.y };
      var attackers = rivalAttackers();
      for (i in 0...4)
        {
          if (attackers != null &&
              i >= attackers.length)
            break;
          var loc = game.area.findArriveLocation({
            near: near,
            radius: 10,
            fallbackRadius: 5
          });
          if (loc == null)
            continue;
          var data = attackers != null ? attackers[i] : null;
          var ai = spawnRivalAttacker(i, loc.x, loc.y, data);
          if (ai != null)
            targetIDs.push(ai.id);
        }
      var rival = game.getCultByID(cultID);
      if (rival != null)
        game.logsg(rival.customName() + ' attackers enter the base.');
      else
        game.logsg('Attackers enter the base.');
    }

// spawns one rival cultist or generic fallback attacker
  function spawnRivalAttacker(index: Int, x: Int, y: Int,
      data: AIData): AI
    {
      var rival = game.getCultByID(cultID);
      var ai = game.area.spawnAI(data != null ? data.type :
        (index < 2 ? 'thug' : 'security'), x, y, false);
      if (data != null)
        {
          ai.updateData(data, 'on base defense spawn');
          ai.setCult(rival);
        }
      ai.isGuard = true;
      ai.isAggressive = true;
      ai.isRelentless = true;
      ai.setState(AI_STATE_ALERT);
      game.area.addAI(ai);
      return ai;
    }

// returns available rival cultists for this attack
  function rivalAttackers(): Array<AIData>
    {
      var rival = game.getCultByID(cultID);
      if (rival == null)
        return null;
      var members = [];
      for (i in 0...rival.members.length)
        if (i > 0 ||
            rival.members.length == 1)
          members.push(rival.members[i]);
      members.sort(function(a, b) return Std.random(3) - 1);
      if (members.length > 4)
        members.resize(4);
      return members;
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

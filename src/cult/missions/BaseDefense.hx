// mission that attacks the player cult base
package cult.missions;

import ai.*;
import cult.base.*;
import cult.Mission;
import game.Game;
import objects.base.BaseOrganObject;

typedef BaseDefenseAttackTarget = {
  var obj: BaseOrganObject;
  var x: Int;
  var y: Int;
}

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
      commandAttackers();
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
      loadBodiesIntoStorage();
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

// pushes attackers toward heart and damages adjacent organs
  function commandAttackers()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      var heart = base.getHeart();
      if (heart == null)
        return;
      for (id in targetIDs)
        {
          var ai = game.area.getAIByID(id);
          if (ai == null)
            continue;
          var target = getAdjacentAttackTarget(base, ai);
          if (target != null)
            {
              CommonLogic.logicAttack(ai, {
                game: game,
                type: TARGET_OBJECT,
                ai: null,
                obj: target.obj
              }, false);
              continue;
            }
          target = getAttackTarget(base, ai);
          if (target == null)
            continue;
          if (ai.state != AI_STATE_ALERT)
            ai.setState(AI_STATE_ALERT);
          ai.roamTargetX = target.x;
          ai.roamTargetY = target.y;
        }
    }

// finds a target object part adjacent to the attacker
  function getAdjacentAttackTarget(base: CultBase, ai: AI): BaseDefenseAttackTarget
    {
      var best: BaseDefenseAttackTarget = null;
      var bestDist = 999999;
      for (organ in base.organs)
        {
          if (!organ.isWorking())
            continue;
          for (pt in organ.footprint())
            {
              if (Math.abs(ai.x - pt.x) > 1 ||
                  Math.abs(ai.y - pt.y) > 1)
                continue;
              var obj = getOrganObject(organ, pt.x, pt.y);
              if (obj == null)
                continue;
              if (!obj.isAttackable())
                continue;
              var dist = Const.distanceSquared(ai.x, ai.y, pt.x, pt.y);
              if (best == null ||
                  dist < bestDist)
                {
                  best = {
                    obj: obj,
                    x: ai.x,
                    y: ai.y
                  };
                  bestDist = dist;
                }
            }
        }
      return best;
    }

// finds the closest reachable tile where an attacker can hit an organ
  function getAttackTarget(base: CultBase, ai: AI): BaseDefenseAttackTarget
    {
      var best: BaseDefenseAttackTarget = null;
      var bestPathLength = -1;
      var seen = new Map<String, Bool>();
      for (organ in base.organs)
        {
          if (!organ.isWorking())
            continue;
          for (pt in organ.footprint())
            {
              var obj = getOrganObject(organ, pt.x, pt.y);
              if (obj == null)
                continue;
              if (!obj.isAttackable())
                continue;
              for (i in 0...Const.dirx.length)
                {
                  var x = pt.x + Const.dirx[i];
                  var y = pt.y + Const.diry[i];
                  var key = x + ',' + y;
                  if (seen.exists(key))
                    continue;
                  seen.set(key, true);
                  if (!game.area.isWalkable(x, y))
                    continue;
                  var occupant = game.area.getAI(x, y);
                  if (occupant != null &&
                      occupant != ai)
                    continue;
                  var path = game.area.getPath(ai.x, ai.y, x, y);
                  if (path == null)
                    continue;
                  if (best == null ||
                      path.length < bestPathLength)
                    {
                      best = {
                        obj: obj,
                        x: x,
                        y: y
                      };
                      bestPathLength = path.length;
                    }
                }
            }
        }
      return best;
    }

// returns the base organ object part at a tile
  function getOrganObject(organ: CultBaseOrgan, x: Int, y: Int): BaseOrganObject
    {
      for (o in game.area.getObjectsAt(x, y))
        if (o.type == 'base_organ')
          {
            var obj: BaseOrganObject = cast o;
            if (obj.organID == organ.id)
              return obj;
          }
      return null;
    }

// completes mission when all attackers are gone
  function checkComplete()
    {
      if (!spawned ||
          targetIDs.length > 0)
        return;
      success();
    }

// stores bodies left after defense
  function loadBodiesIntoStorage()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      var bodies = 0;
      for (o in game.area.getObjects())
        if (o.type == 'body')
          bodies++;
      var lost = base.addBodies(bodies);
      if (bodies > 0)
        game.logsg('Body storage receives ' + (bodies - lost) +
          ' remains; ' + lost + ' are lost.');
    }
}

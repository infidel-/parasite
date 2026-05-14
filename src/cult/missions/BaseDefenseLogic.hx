// shared logic for missions that attack the player cult base
package cult.missions;

import ai.*;
import cult.base.*;
import game.Game;
import objects.base.BaseOrganObject;

typedef BaseDefenseAttackTarget = {
  var obj: BaseOrganObject;
  var x: Int;
  var y: Int;
}

class BaseDefenseLogic
{
// pushes one attacker toward heart or damages an adjacent organ
// this is called in ai.turnInternal() through mission turnAI() hook
  public static function commandAttacker(game: Game, ai: AI)
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      var heart = base.getHeart();
      if (heart == null)
        return;

      // if defender has drawn aggro, retaliate before attacking the base
      var retaliationTarget = getRetaliationTarget(game, ai);
      if (retaliationTarget != null)
        {
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false),
            retaliationTarget);
          return;
        }

      // if adjacent to an organ part, attack it
      var target = getAdjacentAttackTarget(game, base, ai);
      if (target != null)
        {
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), {
            game: game,
            type: TARGET_OBJECT,
            ai: null,
            obj: target.obj
          });
          return;
        }

      // otherwise move toward the closest reachable tile adjacent to an organ part
      target = getAttackTarget(game, base, ai);
      if (target == null)
        return;
      if (ai.state != AI_STATE_ALERT)
        ai.setState(AI_STATE_ALERT);
      ai.logicMoveTo(target.x, target.y);
    }

// stores bodies left after defense
  public static function loadBodiesIntoStorage(game: Game)
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

// calms living area AI after base defense ends
  public static function calmAreaAI(game: Game)
    {
      if (game.area == null)
        return;
      for (ai in game.area.getAllAI())
        {
          if (ai.state == AI_STATE_DEAD ||
              ai.state == AI_STATE_PRESERVED ||
              ai.isPlayerHost())
            continue;
          ai.enemies = new List();
          ai.alertness = 0;
          if (ai.command != null)
            {
              ai.command.type = CMD_NONE;
              ai.command.attackTargetType = TARGET_AI;
              ai.command.attackTargetID = -1;
              ai.command.attackObjectID = -1;
              ai.command.leaveAreaTurns = 0;
            }
          if (ai.state != AI_STATE_IDLE)
            ai.setState(AI_STATE_IDLE);
        }
    }

// finds the closest visible enemy that has already attacked this attacker
  static function getRetaliationTarget(game: Game, ai: AI): AttackTarget
    {
      var best: AI = null;
      var bestDist = 999999;
      for (enemyID in ai.enemies)
        {
          var enemy = game.area.getAIByID(enemyID);
          if (enemy == null ||
              enemy.state == AI_STATE_DEAD ||
              ai.isSameCult(enemy) ||
              !ai.seesPosition(enemy.x, enemy.y))
            continue;
          var dist = Const.distanceSquared(ai.x, ai.y, enemy.x, enemy.y);
          if (best == null ||
              dist < bestDist)
            {
              best = enemy;
              bestDist = dist;
            }
        }
      if (best == null)
        return null;
      return {
        game: game,
        type: TARGET_AI,
        ai: best
      };
    }

// finds a target object part adjacent to the attacker
  static function getAdjacentAttackTarget(game: Game, base: CultBase,
      ai: AI): BaseDefenseAttackTarget
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
              var obj = getOrganObject(game, organ, pt.x, pt.y);
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
  static function getAttackTarget(game: Game, base: CultBase,
      ai: AI): BaseDefenseAttackTarget
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
              var obj = getOrganObject(game, organ, pt.x, pt.y);
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
  static function getOrganObject(game: Game, organ: CultBaseOrgan, x: Int,
      y: Int): BaseOrganObject
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
}

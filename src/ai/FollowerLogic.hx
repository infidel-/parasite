// friendly follower AI logic
package ai;

import ai.AI;
import game.Game;
import objects.AreaObject;
import objects.base.RivalBaseOrganObject;

typedef FollowerOrganAttackTile = {
  var x: Int;
  var y: Int;
}

class FollowerLogic
{
  public static var game: Game;

// run AI logic turn
  public static function turn(ai: AI)
    {
      switch (ai.state)
        {
          // idle - roam around or guard, etc
          case AI_STATE_IDLE:
            stateIdle(ai);

          // alerted - try to get to enemy and attack
          case AI_STATE_ALERT:
            stateAlert(ai);
/*

          // controlled by parasite
          case AI_STATE_HOST:
            stateHost(ai);

          // move to target x,y
          case AI_STATE_MOVE_TARGET:
            stateMoveTarget(ai);

          // investigate
          case AI_STATE_INVESTIGATE:
            stateInvestigate(ai);
*/
          default:
        }
    }

// state: idle (follow player)
  static function stateIdle(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      ai.logicMoveTo(game.playerArea.x, game.playerArea.y);
    }

// AI idle vision: look for enemies in list
  static function visionIdle(ai: AI)
    {
      if (findNearestRivalBaseOrgan(ai) != null)
        {
          ai.setState(AI_STATE_ALERT);
          return;
        }

      // find visible enemies
      if (ai.enemies.length == 0)
        return;
      for (enemyID in ai.enemies)
        {
          var enemy = game.area.getAIByID(enemyID);
          if (enemy == null)
            continue;
          if (ai.seesPosition(enemy.x, enemy.y))
            {
              // enemy is seen, go to alert
              ai.setState(AI_STATE_ALERT);
              break;
            }
        }
    }

// state: alert (find and attack enemies)
  static function stateAlert(ai: AI)
    {
      // find nearest target
      var target = findAttackTarget(ai);
      if (target == null)
        {
          ai.setState(AI_STATE_IDLE);
          return;
        }

      // alerted timer update
      if (ai.seesPosition(target.x, target.y))
        ai.timers.alert = AI.ALERTED_TIMER;
      else ai.timers.alert--;

      // AI calms down
      // relentless AI cannot calm down once alerted
      if (ai.timers.alert == 0 && !ai.isRelentless)
        {
          // become idle
          ai.setState(AI_STATE_IDLE);
          ai.alertness = 10;
          return;
        }

      // try to attack
      var attacker = Attacker.fromAI(game, ai, false);
      if (attackRivalBaseOrgan(ai, attacker, target))
        return;
      CommonLogic.logicAttack(attacker, target);
    }

// handles melee attacks against multi-tile rival base organs
  static function attackRivalBaseOrgan(ai: AI, attacker: Attacker,
      target: AttackTarget): Bool
    {
      if (target.type != TARGET_OBJECT ||
          !Std.isOfType(target.obj, RivalBaseOrganObject) ||
          attacker.weapon.isRanged)
        return false;

      var rivalObj: RivalBaseOrganObject = cast target.obj;
      var attackPart = rivalObj.getAttackPartNear(ai.x, ai.y);
      if (attackPart != null)
        {
          target.obj = attackPart;
          CommonLogic.logicAttack(attacker, target);
          return true;
        }

      var moveTarget = getRivalBaseOrganAttackTile(ai, rivalObj);
      if (moveTarget != null)
        {
          var oldX = ai.x;
          var oldY = ai.y;
          ai.logicMoveTo(moveTarget.x, moveTarget.y);
        }
      return true;
    }

// finds the closest reachable tile where a follower can hit a rival organ
  static function getRivalBaseOrganAttackTile(ai: AI,
      organObj: RivalBaseOrganObject): FollowerOrganAttackTile
    {
      var best: FollowerOrganAttackTile = null;
      var bestPathLength = -1;
      var seen = new Map<String, Bool>();
      var parts = 0;
      var candidates = 0;
      var blockedWalk = 0;
      var occupied = 0;
      var noPath = 0;
      var reachable = 0;
      for (o in game.area.getObjects())
        {
          if (o.type != 'rival_base_organ')
            continue;
          var obj: RivalBaseOrganObject = cast o;
          if (obj.missionID != organObj.missionID ||
              obj.organID != organObj.organID ||
              !obj.isAttackable())
            continue;
          parts++;
          for (i in 0...Const.dirx.length)
            {
              var x = obj.x + Const.dirx[i];
              var y = obj.y + Const.diry[i];
              var key = x + ',' + y;
              if (seen.exists(key))
                continue;
              seen.set(key, true);
              candidates++;
              if (!game.area.isWalkable(x, y))
                {
                  blockedWalk++;
                  continue;
                }
              var occupant = game.area.getAI(x, y);
              if (occupant != null &&
                  occupant != ai)
                {
                  occupied++;
                  continue;
                }
              var path = game.area.getPath(ai.x, ai.y, x, y);
              if (path == null)
                {
                  noPath++;
                  continue;
                }
              reachable++;
              if (best == null ||
                  path.length < bestPathLength)
                {
                  best = {
                    x: x,
                    y: y
                  };
                  bestPathLength = path.length;
                }
            }
        }
      return best;
    }

// finds the follower attack target with rival organs as mission objectives
  static function findAttackTarget(ai: AI): AttackTarget
    {
      var organTarget = findNearestRivalBaseOrgan(ai);
      if (organTarget == null)
        return ai.findNearestEnemy();

      var enemyTarget = ai.findNearestVisibleEnemy();
      if (enemyTarget == null)
        return organTarget;

      var organDist = Const.distanceSquared(
        ai.x, ai.y, organTarget.x, organTarget.y);
      var enemyDist = Const.distanceSquared(
        ai.x, ai.y, enemyTarget.x, enemyTarget.y);
      if (organDist < enemyDist)
        return organTarget;
      return enemyTarget;
    }

// finds the nearest visible rival base organ object
  static function findNearestRivalBaseOrgan(ai: AI): AttackTarget
    {
      var best: AreaObject = null;
      var bestDist = 999999;
      for (o in game.area.getObjects())
        {
          if (o.type != 'rival_base_organ' ||
              !o.isAttackable() ||
              !ai.seesPosition(o.x, o.y))
            continue;
          var dist = Const.distanceSquared(ai.x, ai.y, o.x, o.y);
          if (best == null ||
              dist < bestDist)
            {
              best = o;
              bestDist = dist;
            }
        }
      if (best == null)
        return null;
      return {
        game: game,
        type: TARGET_OBJECT,
        ai: null,
        obj: best
      };
    }
}

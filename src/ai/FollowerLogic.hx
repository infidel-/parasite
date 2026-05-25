// friendly follower AI logic
package ai;

import ai.AI;
import game.Game;
import objects.AreaObject;

class FollowerLogic
{
  public static var game: Game;

// run AI logic turn
  public static function turn(ai: AI)
    {
      ai.traceAI('FollowerLogic', 'turn()');
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
          ai.traceAI('FollowerLogic', 'idle sees rival organ');
          ai.setState(AI_STATE_ALERT);
          return;
        }

      var enemyCultist = ai.findNearestVisibleEnemyCultist();
      if (enemyCultist != null)
        {
          ai.addEnemy(enemyCultist);
          ai.traceAI('FollowerLogic', 'idle sees enemy cultist ' +
            enemyCultist.id);
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
              ai.traceAI('FollowerLogic', 'idle sees enemy ' + enemy.id);
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
          ai.traceAI('FollowerLogic', 'no attack target');
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
          ai.traceAI('FollowerLogic', 'calm from alert');
          // become idle
          ai.setState(AI_STATE_IDLE);
          ai.alertness = 10;
          return;
        }

      // try to attack
      var attacker = Attacker.fromAI(game, ai, false);
      if (RivalBaseOrganAttackLogic.tryAttack(game, ai, attacker, target))
        {
          ai.traceAI('FollowerLogic', 'rival organ attack handled');
          return;
        }
      ai.traceAI('FollowerLogic', 'attack target ' + target.type);
      CommonLogic.logicAttack(attacker, target);
    }

// finds the follower attack target with rival organs as mission objectives
  static function findAttackTarget(ai: AI): AttackTarget
    {
      var organTarget = findNearestRivalBaseOrgan(ai);
      if (organTarget == null)
        {
          ai.traceAI('FollowerLogic', 'use nearest enemy');
          var enemyTarget = ai.findNearestEnemy();
          if (enemyTarget != null &&
              ai.isEnemyCultist(enemyTarget.ai))
            ai.traceAI('FollowerLogic', 'use enemy cultist');
          return enemyTarget;
        }

      var enemyTarget = ai.findNearestVisibleEnemy();
      if (enemyTarget == null)
        {
          ai.traceAI('FollowerLogic', 'use organ target');
          return organTarget;
        }

      var organDist = Const.distanceSquared(
        ai.x, ai.y, organTarget.x, organTarget.y);
      var enemyDist = Const.distanceSquared(
        ai.x, ai.y, enemyTarget.x, enemyTarget.y);
      if (organDist < enemyDist)
        {
          ai.traceAI('FollowerLogic', 'prefer organ target');
          return organTarget;
        }
      ai.traceAI('FollowerLogic', 'prefer enemy target');
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
              !o.isAttackableByFriend() ||
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

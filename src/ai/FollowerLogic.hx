// friendly follower AI logic
package ai;

import ai.AI;
import game.Game;

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
      var target = ai.findNearestEnemy();
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
      CommonLogic.logicAttack(ai, target, false);
    }
}

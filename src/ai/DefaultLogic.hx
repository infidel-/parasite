// default AI logic moved to separate class
package ai;

import game.Game;
import const.*;
import objects.*;
import ai.AI;
import _AIState;
import _Point;

class DefaultLogic
{
  public static var game: Game;
  static var SEARCH_AREA_MAX_RADIUS = 3;

// run AI logic turn
  public static function turn(ai: AI)
    {
      ai.traceAI('DefaultLogic', 'turn()');
      switch (ai.state)
        {
          // idle - roam around or guard, etc
          case AI_STATE_IDLE:
            stateIdle(ai);

          // alerted - try to run away or attack
          case AI_STATE_ALERT:
            stateAlert(ai);

          // search the last seen hostile target tile
          case AI_STATE_SEARCH_LAST_SEEN:
            stateSearchLastSeen(ai);

          // search around the last seen hostile target tile
          case AI_STATE_SEARCH_AREA:
            stateSearchArea(ai);

          // controlled by parasite
          case AI_STATE_HOST:
            stateHost(ai);

          // move to target x,y
          case AI_STATE_MOVE_TARGET:
            stateMoveTarget(ai);

          // investigate
          case AI_STATE_INVESTIGATE:
            stateInvestigate(ai);
          default:
        }
    }

// AI vision: called in idle and movement to target states
  static function visionIdle(ai: AI)
    {
      // alert immediately if a tracked enemy is in sight
      for (enemyID in ai.enemies)
        {
          var enemy = game.area.getAIByID(enemyID);
          if (enemy == null)
            continue;
          if (!ai.seesPosition(enemy.x, enemy.y))
            continue;
          ai.traceAI('DefaultLogic', 'idle sees enemy ' + enemy.id);
          ai.setState(AI_STATE_ALERT, REASON_WITNESS);
          return;
        }

      // full affinity + consent results in ignore
      if (ai.isAgreeable())
        ai.alertness -= 5;
      // player visibility
      else if (!game.player.vars.invisibilityEnabled &&
          ai.seesPosition(game.playerArea.x, game.playerArea.y))
        {
          var distance = game.playerArea.distance(ai.x, ai.y);
          var baseAlertness = 3;
          var alertnessBonus = 0;

          // if player is on a host, check for organs
          if (game.player.state == PLR_STATE_HOST)
            {
              // organ: camouflage layer
              var params = EvolutionConst.getParams(IMP_CAMO_LAYER, 0);
              var o = ai.organs.get(IMP_CAMO_LAYER);
              if (o != null)
                baseAlertness = o.params.alertness;
              else baseAlertness = params.alertness;

              // organ: protective cover
              var params = EvolutionConst.getParams(IMP_PROT_COVER, 0);
              var o = ai.organs.get(IMP_PROT_COVER);
              if (o != null)
                alertnessBonus += o.params.alertness;
              else alertnessBonus += params.alertness;

              // check if player host has a visible (non-concealable) weapon
              if (game.player.host.inventory.hasVisibleWeapon())
                alertnessBonus += 10;
            }
          ai.alertness += Std.int(baseAlertness * (AI.VIEW_DISTANCE + 1 - distance)) +
            alertnessBonus;
          game.profile.addPediaArticle('npcAlertness');
        }
      else ai.alertness -= 5;

      // nearby ai with visible weapons also raise alertness
      var nearbyAI = game.area.getAIinRadius(ai.x, ai.y, 3, true);
      for (other in nearbyAI)
        {
          if (other == ai)
            continue;
          // player host is handled by dedicated player visibility logic above
          if (other.isPlayerHost())
            continue;
          if (!other.inventory.hasVisibleWeapon())
            continue;
          if (other.isLaw())
            continue;
          if (ai.isLaw())
            {
              ai.alertness += 10;
              ai.addEnemy(other);
            }
          else if (!ai.isAggressive)
            ai.alertness += 5;
        }

      // AI has become alerted
      if (ai.alertness >= 100)
        {
          ai.traceAI('DefaultLogic', 'alertness reached 100');
          var reason = REASON_PARASITE;

          if (game.player.state == PLR_STATE_HOST &&
              game.player.host.isHuman)
            reason = REASON_HOST;

          ai.setState(AI_STATE_ALERT, reason);
          return;
        }

      // get all objects that this AI sees
      var tmp = game.area.getObjectsInRadius(ai.x, ai.y, AI.VIEW_DISTANCE, true);

      for (obj in tmp)
        {
          // not a body
          if (obj.type != 'body')
            continue;

          // object already seen by this AI
          if (ai.hasSeenObject(obj.id))
            continue;

          var body: BodyObject = cast obj;

          // human AI becomes alert on seeing dangerous body evidence
          if (ai.isHuman && body.canAlertHumans())
            {
              if (!body.wasSeen)
                {
                  ai.traceAI('DefaultLogic', 'sees body');
                  // mark body as seen by someone to limit the law response
                  body.wasSeen = true;

                  ai.setState(AI_STATE_ALERT, REASON_BODY);
                }

              // silent alert - no calling law
              else ai.setState(AI_STATE_ALERT, REASON_BODY_SILENT);
            }

          ai.objectSeen(obj.id);
        }
    }

// logic: roam around (default)
  static function logicRoam(ai: AI)
    {
      // roam target set, move to it
      if (ai.roamTargetX >= 0 && ai.roamTargetY >= 0)
        {
          ai.traceAI('DefaultLogic', 'roam target');
          ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
          return;
        }

      if (Math.random() < 0.2)
        ai.changeRandomDirection();

      // nowhere to move - should be a bug
      if (ai.direction == -1)
        {
          ai.traceAI('DefaultLogic', 'no roam direction');
          return;
        }

      var nx = ai.x + Const.dirx[ai.direction];
      var ny = ai.y + Const.diry[ai.direction];
      var ok =
        (game.area.isWalkable(nx, ny) &&
         !game.area.hasAI(nx, ny) &&
         !(game.playerArea.x == nx && game.playerArea.y == ny));
      if (!ok)
        {
          ai.traceAI('DefaultLogic', 'blocked roam direction');
          ai.changeRandomDirection();
          return;
        }
      else
        {
          ai.traceAI('DefaultLogic', 'roam move');
          ai.setPosition(nx, ny);
        }
    }

// state: default idle state handling
  static function stateIdle(ai: AI)
    {
      // AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness go down
      // if roam target is set, continue moving instead
      if (ai.alertness > 0 && ai.roamTargetX < 0)
        {
          ai.traceAI('DefaultLogic', 'idle waits alertness ' + ai.alertness);
          return;
        }

      // TODO: i could make hooks here, leaving the alert logic intact

      // guards stand on one spot
      // someday there might even be patrollers...
      if (ai.isGuard)
        ai.traceAI('DefaultLogic', 'guard idle');
      // roam by default
      else logicRoam(ai);
    }

// state: default alert state handling
  static function stateAlert(ai: AI)
    {
      // NOTE: must be first check in this function
      // parasite attached - try to tear it away
      if (ai.parasiteAttached)
        {
          ai.traceAI('DefaultLogic', 'tear parasite away');
          if (!ai.isAgreeable())
            ai.logicTearParasiteAway();
          return;
        }

      // alerted timer update
      if (ai.seesAnyEnemy())
        ai.timers.alert = AI.ALERTED_TIMER;
      else ai.timers.alert--;

      // AI calms down
      // relentless AI cannot calm down once alerted
      if (ai.timers.alert == 0 && !ai.isRelentless)
        {
          ai.traceAI('DefaultLogic', 'calm from alert');
          calmFromAlert(ai);
          return;
        }

      // aggressive AI - find/attack enemies/player
      // same for berserk effect
      if (ai.isAggressive ||
          ai.effects.has(EFFECT_BERSERK))
        stateAlertAggressive(ai);

      // not aggressive AI - try to run away
      else
        {
          ai.traceAI('DefaultLogic', 'run away from enemies');
          ai.logicRunAwayFromEnemies();
        }
    }

// state: alert for aggressive AI
  static function stateAlertAggressive(ai: AI)
    {
      // find nearest visible enemy and remember its last seen tile
      var target = ai.findNearestVisibleEnemy();
      if (target == null)
        {
          ai.traceAI('DefaultLogic', 'no visible enemy');
          if (ai.lastSeenX >= 0 &&
              ai.lastSeenY >= 0)
            {
              ai.setState(AI_STATE_SEARCH_LAST_SEEN);
              ai.logicMoveTo(ai.lastSeenX, ai.lastSeenY);
            }
          return;
        }

      ai.lastSeenX = target.x;
      ai.lastSeenY = target.y;
      ai.traceAI('DefaultLogic', 'attack target ' + target.type);
      CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), target);
    }

// state: host logic
  static function stateHost(ai: AI)
    {
      // non-assimilated hosts emit random sounds
      if (!ai.hasTrait(TRAIT_ASSIMILATED))
        ai.emitRandomSound('' + AI_STATE_HOST,
          Std.int((100 - game.player.hostControl) / 3));

      // effect: cannot tear parasite away (given right after invasion)
      if (ai.effects.has(EFFECT_CANNOT_TEAR_AWAY))
        {
          ai.traceAI('DefaultLogic', 'host cannot tear away');
          return;
        }

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          ai.log('manages to tear you away.');
          ai.onDetach('default');
          game.playerArea.onDetach(); // notify player
        }
    }

// calm alerted ai and resume their normal post-alert behavior
  static function calmFromAlert(ai: AI)
    {
      // guard must return to guard spot
      if (ai.isGuard &&
          (ai.x != ai.guardTargetX || ai.y != ai.guardTargetY))
        {
          ai.setState(AI_STATE_MOVE_TARGET);
          ai.roamTargetX = ai.guardTargetX;
          ai.roamTargetY = ai.guardTargetY;
        }
      // otherwise become idle
      else ai.setState(AI_STATE_IDLE);
      ai.alertness = 10;
    }

// switch to alert state without resetting the current alert timer
  static function setAlertPreserveTimer(ai: AI)
    {
      var timer = ai.timers.alert;
      ai.setState(AI_STATE_ALERT);
      ai.timers.alert = timer;
    }

// build candidate tiles for one search radius ring
  static function getSearchAreaPoints(originX: Int, originY: Int,
      radius: Int): Array<_Point>
    {
      var points = [];
      for (dy in -radius...radius + 1)
        for (dx in -radius...radius + 1)
          {
            if (dx != -radius &&
                dx != radius &&
                dy != -radius &&
                dy != radius)
              continue;
            points.push({
              x: originX + dx,
              y: originY + dy,
            });
          }
      return points;
    }

// pick the next reachable tile in the active area search pattern
  static function getSearchAreaTarget(ai: AI): _Point
    {
      while (ai.search != null &&
          ai.search.radius <= SEARCH_AREA_MAX_RADIUS)
        {
          // build candidate tiles for current radius
          var points = getSearchAreaPoints(ai.search.originX,
            ai.search.originY, ai.search.radius);
          if (ai.search.pointID >= points.length)
            {
              ai.search.radius++;
              ai.search.pointID = 0;
              continue;
            }

          var idx = (ai.search.pointID + ai.id) % points.length;
          var point = points[idx];
          ai.search.pointID++;

          // check if tile is walkable and not occupied by player
          if (!game.area.isWalkable(point.x, point.y))
            continue;
          if (game.playerArea.x == point.x &&
              game.playerArea.y == point.y)
            continue;

          // check for other AI occupying the tile
          var occupant = game.area.getAI(point.x, point.y);
          if (occupant != null &&
              occupant != ai)
            continue;
          // check if the tile is reachable
          if (game.area.getPath(ai.x, ai.y, point.x, point.y) == null)
            continue;
          return point;
        }
      return null;
    }

// state: search the last seen hostile target tile
  static function stateSearchLastSeen(ai: AI)
    {
      // find nearest visible enemy and update last seen tile
      var target = ai.findNearestVisibleEnemy();
      if (target != null)
        {
          ai.setState(AI_STATE_ALERT);
          ai.lastSeenX = target.x;
          ai.lastSeenY = target.y;
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), target);
          return;
        }

      // stand and wonder what happened until alertness goes down
      ai.timers.alert--;
      if (ai.timers.alert == 0 && !ai.isRelentless)
        {
          calmFromAlert(ai);
          return;
        }

      if (ai.lastSeenX < 0 ||
          ai.lastSeenY < 0)
        {
          ai.traceAI('DefaultLogic', 'search last seen without target');
          return;
        }

      // move to last seen tile
      ai.logicMoveTo(ai.lastSeenX, ai.lastSeenY);
      if (ai.x != ai.lastSeenX ||
          ai.y != ai.lastSeenY)
        {
          ai.traceAI('DefaultLogic', 'move to last seen');
          return;
        }

      // reached the last seen tile, start searching around it
      ai.search = {
        originX: ai.lastSeenX,
        originY: ai.lastSeenY,
        radius: 1,
        pointID: 0,
      };
      ai.setState(AI_STATE_SEARCH_AREA);
      ai.traceAI('DefaultLogic', 'start search area');
    }

// state: search around the last seen hostile target tile
  static function stateSearchArea(ai: AI)
    {
      // find nearest visible enemy and update last seen tile
      var target = ai.findNearestVisibleEnemy();
      if (target != null)
        {
          ai.setState(AI_STATE_ALERT);
          ai.lastSeenX = target.x;
          ai.lastSeenY = target.y;
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), target);
          return;
        }

      // stand and search until the alert timer runs out
      ai.timers.alert--;
      if (ai.timers.alert == 0)
        {
          ai.roamTargetX = -1;
          ai.roamTargetY = -1;
          if (!ai.isRelentless)
            {
              calmFromAlert(ai);
              return;
            }
          setAlertPreserveTimer(ai);
          return;
        }

      // no last seen tile - should be a bug, but just calm down and return to idle
      if (ai.search == null)
        {
          ai.roamTargetX = -1;
          ai.roamTargetY = -1;
          setAlertPreserveTimer(ai);
          return;
        }

      // search area target not set, pick the next one
      if (ai.roamTargetX < 0 ||
          ai.roamTargetY < 0)
        {
          var point = getSearchAreaTarget(ai);
          if (point == null)
            {
              ai.traceAI('DefaultLogic', 'no search area target');
              ai.roamTargetX = -1;
              ai.roamTargetY = -1;
              setAlertPreserveTimer(ai);
              return;
            }
          ai.roamTargetX = point.x;
          ai.roamTargetY = point.y;
        }

      // move to search area target
      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX ||
          ai.y != ai.roamTargetY)
        {
          ai.traceAI('DefaultLogic', 'move to search area target');
          return;
        }

      // reached search area target, pick the next one
      ai.roamTargetX = -1;
      ai.roamTargetY = -1;
    }

// state: move to target spot
  static function stateMoveTarget(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness goes down
      if (ai.alertness > 0)
        {
          ai.traceAI('DefaultLogic', 'move target waits alertness ' +
            ai.alertness);
          return;
        }

      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX || ai.y != ai.roamTargetY)
        {
          ai.traceAI('DefaultLogic', 'move target');
          return;
        }
      // spot reached, idling
      ai.roamTargetY = -1;
      ai.roamTargetY = -1;
      ai.setState(AI_STATE_IDLE);
    }

// state: investigate (move to target spot ignoring alertness)
  static function stateInvestigate(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX || ai.y != ai.roamTargetY)
        {
          ai.traceAI('DefaultLogic', 'investigate move');
          return;
        }
      // spot reached, idling
      ai.roamTargetY = -1;
      ai.roamTargetY = -1;
      ai.setState(AI_STATE_IDLE);
    }
}

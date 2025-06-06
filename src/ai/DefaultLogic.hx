// default AI logic moved to separate class
package ai;

import game.Game;
import const.*;
import objects.*;
import particles.*;
import ai.AI;
import _AIState;
import __Math;

class DefaultLogic
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

          // alerted - try to run away or attack
          case AI_STATE_ALERT:
            stateAlert(ai);

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
            }
          ai.alertness += Std.int(baseAlertness * (AI.VIEW_DISTANCE + 1 - distance)) +
            alertnessBonus;
          game.profile.addPediaArticle('npcAlertness');
        }
      else ai.alertness -= 5;

      // AI has become alerted
      if (ai.alertness >= 100)
        {
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

          // human AI becomes alert on seeing human bodies
          if (ai.isHuman && body.isHumanBody)
            {
              if (!body.wasSeen)
                {
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
          ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
          return;
        }

      if (Math.random() < 0.2)
        ai.changeRandomDirection();

      // nowhere to move - should be a bug
      if (ai.direction == -1)
        return;

      var nx = ai.x + Const.dirx[ai.direction];
      var ny = ai.y + Const.diry[ai.direction];
      var ok =
        (game.area.isWalkable(nx, ny) &&
         !game.area.hasAI(nx, ny) &&
         !(game.playerArea.x == nx && game.playerArea.y == ny));
      if (!ok)
        {
          ai.changeRandomDirection();
          return;
        }
      else ai.setPosition(nx, ny);
    }

// state: default idle state handling
  static function stateIdle(ai: AI)
    {
      // AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness go down
      // if roam target is set, continue moving instead
      if (ai.alertness > 0 && ai.roamTargetX < 0)
        return;

      // TODO: i could make hooks here, leaving the alert logic intact

      // guards stand on one spot
      // someday there might even be patrollers...
      if (ai.isGuard)
        1;
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
          return;
        }

      // aggressive AI - find/attack enemies/player
      // same for berserk effect
      if (ai.isAggressive ||
          ai.effects.has(EFFECT_BERSERK))
        stateAlertAggressive(ai);

      // not aggressive AI - try to run away
      else ai.logicRunAwayFromEnemies();
    }

// state: alert for aggressive AI
  static function stateAlertAggressive(ai: AI)
    {
      // find nearest enemy (and magically know where they are until alert timer runs out)
      var target = ai.findNearestEnemy();
      if (target == null)
        {
          ai.setState(AI_STATE_IDLE);
          return;
        }

      // search for target
      // we cheat a little and follow invisible target
      // emulating ai memory before alert timer ends
      if (!ai.seesPosition(target.x, target.y))
        ai.logicMoveTo(target.x, target.y);
      // try to attack
      else CommonLogic.logicAttack(ai, target, false);
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
        return;

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          ai.log('manages to tear you away.');
          ai.onDetach('default');
          game.playerArea.onDetach(); // notify player
        }
    }

// state: move to target spot
  static function stateMoveTarget(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness goes down
      if (ai.alertness > 0)
        return;

      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX || ai.y != ai.roamTargetY)
        return;
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
        return;
      // spot reached, idling
      ai.roamTargetY = -1;
      ai.roamTargetY = -1;
      ai.setState(AI_STATE_IDLE);
    }
}

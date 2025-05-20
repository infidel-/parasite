// default AI logic moved to separate class
package ai;

import game.Game;
import const.*;
import objects.*;
import ai.AI;

class DefaultLogic
{
  public static var game: Game;

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
  public static function stateIdle(ai: AI)
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
  
}

// base guardian AI logic
package ai;

import game.Game;

class CustodesLogic
{
// run guardian logic
  public static function turn(ai: AI)
    {
      // if we see an intruder, attack
      var game = Game.inst;
      var target = findTarget(ai);
      if (target != null)
        {
          ai.addEnemy(target);
          ai.setState(AI_STATE_ALERT);
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), {
            game: game,
            type: TARGET_AI,
            ai: target
          });
          return;
        }

      // find heart if it's damaged and move to it
      var heart = game.cults[0].base.getHeart();
      if (heart != null &&
          heart.health < heart.maxHealth())
        {
          ai.logicMoveTo(heart.x, heart.y);
          return;
        }

      // otherwise, move to guard position if we have one
      if (ai.guardTargetX >= 0 &&
          Const.distanceSquared(ai.x, ai.y,
            ai.guardTargetX, ai.guardTargetY) > 2)
        ai.logicMoveTo(ai.guardTargetX, ai.guardTargetY);
    }

// finds nearest visible intruder
  static function findTarget(ai: AI): AI
    {
      var game = Game.inst;
      var best: AI = null;
      var bestDist = 999999;
      for (other in game.area.getAllAI())
        {
          if (other == ai ||
              other.state == AI_STATE_DEAD ||
              other.isPlayerCultist() ||
              other.isCustos)
            continue;
          if (!ai.seesPosition(other.x, other.y))
            continue;
          var dist = Const.distanceSquared(ai.x, ai.y, other.x, other.y);
          if (best == null || dist < bestDist)
            {
              best = other;
              bestDist = dist;
            }
        }
      return best;
    }
}

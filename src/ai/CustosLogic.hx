// base guardian AI logic
package ai;

import cult.base.CultBaseOrgan;
import game.Game;

typedef CustosDefenseTarget = {
  var x: Int;
  var y: Int;
}

class CustosLogic
{
// alerts free custodes when the heart is attacked
  public static function onHeartAttacked(attacker: AI)
    {
      var game = Game.inst;
      if (game.area == null)
        return;
      for (ai in game.area.getAllAI())
        {
          if (!ai.isCustos ||
              ai.state == AI_STATE_DEAD ||
              isInFight(ai))
            continue;
          if (attacker != null &&
              attacker.state != AI_STATE_DEAD)
            ai.addEnemy(attacker);
          ai.setState(AI_STATE_ALERT);
        }
    }

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

      // find heart if it's damaged and move to defend it
      var heart = game.cults[0].base.getHeart();
      if (heart != null &&
          heart.health < heart.maxHealth())
        {
          var guardTarget = findHeartDefenseTarget(ai, heart);
          if (guardTarget != null)
            ai.logicMoveTo(guardTarget.x, guardTarget.y);
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

// returns true when custos is already fighting a visible intruder
  static function isInFight(ai: AI): Bool
    {
      return findTarget(ai) != null;
    }

// finds closest reachable tile adjacent to the heart
  static function findHeartDefenseTarget(ai: AI,
      heart: CultBaseOrgan): CustosDefenseTarget
    {
      var game = Game.inst;
      var best: CustosDefenseTarget = null;
      var bestPathLength = -1;
      var seen = new Map<String, Bool>();
      for (pt in heart.footprint())
        for (i in 0...Const.dirx.length)
          {
            var x = pt.x + Const.dirx[i];
            var y = pt.y + Const.diry[i];
            if (ai.x == x &&
                ai.y == y)
              return null;
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
                  x: x,
                  y: y
                };
                bestPathLength = path.length;
              }
          }
      return best;
    }
}

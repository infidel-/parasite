// shared AI attack logic for rival base organs
package ai;

import game.Game;
import objects.base.RivalBaseOrganObject;

class RivalBaseOrganAttackLogic
{
// handles melee attacks against multi-tile rival base organs
  public static function tryAttack(game: Game, ai: AI, attacker: Attacker,
      target: AttackTarget): Bool
    {
      if (target.type != TARGET_OBJECT ||
          !Std.isOfType(target.obj, RivalBaseOrganObject) ||
          attacker.weapon.isRanged)
        return false;

      ai.traceAI('RivalBaseOrganAttackLogic', 'tryAttack()');
      var rivalObj: RivalBaseOrganObject = cast target.obj;
      var attackPart = rivalObj.getAttackPartNear(ai.x, ai.y);
      if (attackPart != null)
        {
          ai.traceAI('RivalBaseOrganAttackLogic', 'attack adjacent part');
          target.obj = attackPart;
          CommonLogic.logicAttack(attacker, target);
          return true;
        }

      var moveTarget = getAttackTile(game, ai, rivalObj);
      if (moveTarget != null)
        {
          ai.traceAI('RivalBaseOrganAttackLogic', 'move to attack tile');
          ai.logicMoveTo(moveTarget.x, moveTarget.y);
        }
      else ai.traceAI('RivalBaseOrganAttackLogic', 'no attack tile');
      return true;
    }

// finds the closest reachable tile where an AI can hit a rival organ
  static function getAttackTile(game: Game, ai: AI,
      organObj: RivalBaseOrganObject): _Tile
    {
      var best: _Tile = null;
      var bestPathLength = -1;
      var seen = new Map<String, Bool>();
      for (o in game.area.getObjects())
        {
          if (o.type != 'rival_base_organ')
            continue;
          var obj: RivalBaseOrganObject = cast o;
          if (obj.missionID != organObj.missionID ||
              obj.organID != organObj.organID ||
              !obj.isAttackableByFriend())
            continue;
          for (i in 0...Const.dirx.length)
            {
              var x = obj.x + Const.dirx[i];
              var y = obj.y + Const.diry[i];
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
        }
      return best;
    }
}

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
// moves cost of a free tile, and of a working organ the attackers must break to pass
  static inline var FREE_COST = 1;
  static inline var BREAK_COST = 6;

// drives one attacker: fights a visible defender, else heads for Cor Nefandum and breaks the organs
// that stand in its way
// this is called in ai.turnInternal() through mission turnAI() hook
  public static function commandAttacker(game: Game, ai: AI)
    {
      ai.traceAI('BaseDefenseLogic', 'commandAttacker()');
      var base = game.cults[0].base;
      if (base == null)
        {
          ai.traceAI('BaseDefenseLogic', 'no base');
          return;
        }
      var heart = base.getHeart();
      if (heart == null)
        {
          ai.traceAI('BaseDefenseLogic', 'no heart');
          return;
        }

      // a visible defender, or anyone who already attacked this attacker, is fought first
      var enemy = getEngageTarget(game, ai);
      if (enemy != null)
        {
          ai.traceAI('BaseDefenseLogic', 'engage target');
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), enemy);
          return;
        }

      // otherwise follow the cheapest route to Cor Nefandum
      var step = getHeartRoute(game, base, heart, ai);
      if (step == null)
        {
          ai.traceAI('BaseDefenseLogic', 'no route to the heart');
          return;
        }
      if (step.obj != null)
        {
          ai.traceAI('BaseDefenseLogic', 'attack organ on the route');
          CommonLogic.logicAttack(Attacker.fromAI(game, ai, false), {
            game: game,
            type: TARGET_OBJECT,
            ai: null,
            obj: step.obj
          });
          return;
        }
      if (ai.state != AI_STATE_ALERT)
        ai.setState(AI_STATE_ALERT);
      ai.traceAI('BaseDefenseLogic', 'move along the route');
      ai.logicMoveTo(step.x, step.y);
    }

// stores the bodies with an object ID from firstBodyID up and clears the stored ones off the floor:
// the default is the running defense's mark (the bodies made since it began), 0 is every body in the area
  public static function loadBodiesIntoStorage(game: Game, ?firstBodyID: Int = -1)
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      if (firstBodyID < 0)
        firstBodyID = base.defenseFirstBodyID;
      var bodies = [];
      for (o in game.area.getObjects())
        if (o.type == 'body' &&
            o.id >= firstBodyID)
          bodies.push(o);
      var lost = base.addBodies(bodies.length);
      for (i in 0...(bodies.length - lost))
        game.area.removeObject(bodies[i]);
      if (bodies.length > 0)
        game.logsg(T('Body storage receives {received} remains; {lost, plural, one{# is lost} other{# are lost}}.', {
          received: bodies.length - lost,
          lost: lost,
        }));
    }

// true when a wave was tracked and none of it is left in the area: attackers that vanished without
// dying (rebirth walked the player out, an invaded one despawned). targetIDs shrinks only on a death,
// so the defense could never finish; the missions spawn a fresh wave instead
  public static function waveGone(game: Game, targetIDs: Array<Int>): Bool
    {
      return (targetIDs.length > 0 &&
        !Lambda.exists(targetIDs, function(id) return game.area.getAIByID(id) != null));
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

// finds the closest visible defender: a custos, a cultist of the player's cult or the player's host,
// or anyone who already attacked this attacker. preserved hosts are never a target
  static function getEngageTarget(game: Game, ai: AI): AttackTarget
    {
      var best: AI = null;
      var bestDist = 999999;
      for (other in game.area.getAllAI())
        {
          if (other == ai ||
              other.state == AI_STATE_DEAD ||
              other.state == AI_STATE_PRESERVED ||
              ai.isSameCult(other) ||
              !(other.isCustos ||
                (other.isCultist &&
                 other.cultID == game.cults[0].id) ||
                other.isPlayerHost() ||
                Lambda.has(ai.enemies, other.id)) ||
              !ai.seesPosition(other.x, other.y))
            continue;
          var dist = Const.distanceSquared(ai.x, ai.y, other.x, other.y);
          if (best == null ||
              dist < bestDist)
            {
              best = other;
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

// finds the next move toward Cor Nefandum along the cheapest route, where a working organ in the way
// costs BREAK_COST: the tile to walk to, or the organ part to hit when it is the next step (obj set),
// or the heart itself once the attacker stands beside it. null when there is no route
  static function getHeartRoute(game: Game, base: CultBase, heart: CultBaseOrgan,
      ai: AI): BaseDefenseAttackTarget
    {
      var area = game.area;
      var w = area.width;
      var n = w * area.height;
      var dist = [ for (_ in 0...n) 999999 ];
      var prev = [ for (_ in 0...n) -1 ];
      var done = [ for (_ in 0...n) false ];
      var start = ai.y * w + ai.x;
      dist[start] = 0;

      // dijkstra over the habitat (small), until a tile beside the heart is reached
      var goal = -1;
      while (true)
        {
          var cur = -1;
          var best = 999999;
          for (i in 0...n)
            if (!done[i] &&
                dist[i] < best)
              {
                cur = i;
                best = dist[i];
              }
          if (cur < 0)
            break;
          done[cur] = true;
          var cx = cur % w;
          var cy = Std.int(cur / w);
          if (isBesideOrgan(heart, cx, cy))
            {
              goal = cur;
              break;
            }
          for (d in 0...Const.dirx.length)
            {
              var x = cx + Const.dirx[d];
              var y = cy + Const.diry[d];
              if (x < 0 ||
                  y < 0 ||
                  x >= w ||
                  y >= area.height)
                continue;
              var cost = getTileCost(game, base, heart, x, y);
              var next = y * w + x;
              if (cost < 0 ||
                  done[next] ||
                  dist[cur] + cost >= dist[next])
                continue;
              dist[next] = dist[cur] + cost;
              prev[next] = cur;
            }
        }
      if (goal < 0)
        return null;

      // the route from the attacker to the goal
      var route = [ goal ];
      while (prev[route[0]] >= 0)
        route.unshift(prev[route[0]]);

      // beside the heart already: hit it
      if (route.length == 1)
        return getOrganHit(game, heart, ai);

      // the first organ on the route is hit when next to the attacker, else walked up to
      for (i in 1...route.length)
        {
          var x = route[i] % w;
          var y = Std.int(route[i] / w);
          if (area.isWalkable(x, y))
            continue;
          if (i == 1)
            {
              var organ = base.getOrganAt(x, y);
              return {
                obj: getOrganObject(game, organ, x, y),
                x: ai.x,
                y: ai.y
              };
            }
          return {
            obj: null,
            x: route[i - 1] % w,
            y: Std.int(route[i - 1] / w)
          };
        }
      return {
        obj: null,
        x: goal % w,
        y: Std.int(goal / w)
      };
    }

// returns the cost of stepping onto a tile: -1 blocked, FREE_COST free, BREAK_COST a working organ
// (the heart itself is the goal, never a step)
  static function getTileCost(game: Game, base: CultBase, heart: CultBaseOrgan,
      x: Int, y: Int): Int
    {
      if (game.area.isWalkable(x, y))
        return FREE_COST;
      var organ = base.getOrganAt(x, y);
      if (organ == null ||
          organ == heart ||
          !organ.isWorking())
        return -1;
      return BREAK_COST;
    }

// true when the tile touches the organ's footprint and is not part of it
  static function isBesideOrgan(organ: CultBaseOrgan, x: Int, y: Int): Bool
    {
      var beside = false;
      for (pt in organ.footprint())
        {
          if (pt.x == x &&
              pt.y == y)
            return false;
          if (Math.abs(x - pt.x) <= 1 &&
              Math.abs(y - pt.y) <= 1)
            beside = true;
        }
      return beside;
    }

// finds a part of the organ next to the attacker to hit, null when none can be
  static function getOrganHit(game: Game, organ: CultBaseOrgan,
      ai: AI): BaseDefenseAttackTarget
    {
      for (pt in organ.footprint())
        {
          if (Math.abs(ai.x - pt.x) > 1 ||
              Math.abs(ai.y - pt.y) > 1)
            continue;
          var obj = getOrganObject(game, organ, pt.x, pt.y);
          if (obj != null &&
              obj.isAttackableByEnemy())
            return {
              obj: obj,
              x: ai.x,
              y: ai.y
            };
        }
      return null;
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

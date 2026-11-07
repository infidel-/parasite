// black noise effect

package effects;

import ai.AI;
import ai.CommonLogic;
import game.Effect;
import game.Game;
import particles.Particle;

class BlackNoise extends Effect
{
// creates black noise effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_BLACK_NOISE, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = N('black noise');
    }

// drop black blood each turn while effect is active
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      // area behaviour: on the region map the effect only runs down
      if (ai == null ||
          game.location != LOCATION_AREA)
        return;

      // apply one random black-noise behavior to this AI
      var roll = Std.random(3);
      switch (roll)
        {
          case 0:
            // attack nearest AI
            var nearest: AI = null;
            var bestDist = 1000000;
            for (other in game.area.getAllAI())
              {
                if (other == ai ||
                    other.state == AI_STATE_DEAD)
                  continue;
                var dist = Const.distanceSquared(ai.x, ai.y, other.x, other.y);
                if (dist >= bestDist)
                  continue;
                nearest = other;
                bestDist = dist;
              }
            // an attacker that cannot chase (the player's host) lashes out only when adjacent
            var attacker = Attacker.fromAI(game, ai, false);
            if (nearest == null ||
                (!attacker.canMoveToTarget() && !ai.isNear(nearest.x, nearest.y)))
              ai.log(T('{ai:The} stands catatonic, staring into nothingness.', { ai: ai }));
            else
              {
                ai.log(T('{ai:The} lashes out through black static.', { ai: ai }));
                CommonLogic.logicAttack(attacker, {
                  game: game,
                  type: TARGET_AI,
                  ai: nearest,
                });
              }
          case 1:
            // clawing own eyes out (direct self-damage)
            ai.log(T('{ai:The} claws at {ai, select, m{his} f{her} other{its}} own eyes in mute panic.', { ai: ai }));
            ai.onDamage(1 + Std.random(3));
          case 2:
            // catatonic state
            ai.log(T('{ai:The} stands catatonic, staring into nothingness.', { ai: ai }));
          default:
        }

      // create splat particle
      Particle.createSplat('black', game.scene, { x: ai.x, y: ai.y });
    }

// returns true if effect should skip default AI turn logic
  public override function skipDefaultTurnLogic(): Bool
    {
      return true;
    }

// returns effect icon for world entity badge
  public override function icon(): _Icon
    {
      return {
        row: Const.ROW_ALERT,
        col: Const.FRAME_BLACK_NOISE,
      };
    }
}

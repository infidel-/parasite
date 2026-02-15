// black noise effect

package effects;

import ai.AI;
import ai.CommonLogic;
import game.Effect;
import game.Game;
import particles.ParticleBlackSplat;

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
      name = 'black noise';
    }

// drop black blood each turn while effect is active
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null ||
          game.area == null)
        return;

      new ParticleBlackSplat(game.scene, { x: ai.x, y: ai.y });
    }

// apply one random black-noise behavior to this AI
  public function applyBehavior(ai: AI)
    {
      if (ai == null ||
          game.area == null)
        return;

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
            if (nearest == null)
              ai.log('stands catatonic, staring into nothingness.');
            else
              {
                ai.log('lashes out through black static.');
                CommonLogic.logicAttack(ai, {
                  game: game,
                  type: TARGET_AI,
                  ai: nearest,
                }, false);
              }
          case 1:
            // clawing own eyes out (direct self-damage)
            ai.log('claws at his own eyes in mute panic.');
            ai.onDamage(1 + Std.random(3));
          case 2:
            // catatonic state
            ai.log('stands catatonic, staring into nothingness.');
          default:
        }
    }
}

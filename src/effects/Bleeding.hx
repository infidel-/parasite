// bleeding effect

package effects;

import ai.AI;
import game.Effect;
import game.Game;
import particles.Particle;

class Bleeding extends Effect
{
// creates bleeding effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_BLEEDING, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = N('bleeding');
    }

// deals periodic damage while bleeding is active
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;
      // on the region map the host only bleeds: no splat or alert, and a death takes the region
      // host-death path (Player.onHostDeath → AI.dieRegion), not AI.die
      if (game.location != LOCATION_AREA)
        {
          ai.health -= time;
          if (ai.health == 0)
            game.player.onHostDeath(T('Your host has bled out.'));
          return;
        }

      ai.onDamage(1 * time);
      Particle.createSplat(ai.bloodType(), game.scene, {
        x: ai.x,
        y: ai.y
      });
    }

// returns effect icon for world entity badge
  public override function icon(): _Icon
    {
      return {
        row: Const.ROW_ALERT,
        col: Const.FRAME_BLEEDING,
      };
    }
}

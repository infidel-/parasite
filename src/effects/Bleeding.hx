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
      name = 'bleeding';
    }

// deals periodic damage while bleeding is active
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null ||
          game.area == null)
        return;

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

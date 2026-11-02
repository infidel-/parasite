// white powder effect

package effects;

import game.Effect;
import game.Game;
import ai.AI;

class WhitePowder extends Effect
{
// creates white powder effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_WHITE_POWDER, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = N('white powder');
    }

// restores host energy each turn
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      var restored = (5 + Std.random(6)) * time;
      ai.energy += restored;
      ai.log(T('{ai:The} seems unnaturally energized by the powder.', { ai: ai }));
      game.info('+ ' + restored + ' energy.');
    }

// triggers withdrawal when removed
  public override function onRemove(ai: AI)
    {
      super.onRemove(ai);
      ai.onEffect(new effects.Withdrawal(game, 5));
    }
}

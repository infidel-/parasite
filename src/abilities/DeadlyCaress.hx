// deadly caress ingrained ability
package abilities;

import ai.AI;
import effects.Paralysis;

class DeadlyCaress extends Ability
{
  public function new()
    {
      super();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      id = ABILITY_DEADLY_CARESS;
      name = 'deadly caress';
    }

// handles deadly caress attack logic
  public override function logicAttack(ai: AI, target: AITarget): Bool
    {
      // cooldown check
      if (timeout > 0)
        {
          timeout--;
          return false;
        }

      // only melee, and not on players
      if (target.type == TARGET_PLAYER ||
          !ai.isNear(target.x, target.y) ||
          Std.random(100) >= 85)
        return false;

      ai.log('lunges at ' + target.theName() +
        ' and plants a hard kiss, smiling far too wide.');

      // opposing constitution check to resist
      var resisted = __Math.opposingAttr(
        target.ai.constitution - 2,
        4 + Std.random(6),
        'con/deadly caress');
      if (resisted)
        {
          ai.log(target.theName() + ' resists the caress.');
          return true;
        }

      var turns = 1 + Std.random(3);
      target.ai.onEffect(new Paralysis(target.game, turns));
      target.onDamage(0);
      timeout = 3;
      ai.log('leaves ' + target.theName() + ' trembling for ' +
        turns + ' turns.');
      return true;
    }
}

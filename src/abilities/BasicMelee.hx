// configurable melee ability used by special AI attacks
package abilities;

import ai.AI;

class BasicMelee extends Ability
{
  public var attackMessage: String;
  public var skill: Int;
  public var sound: AISound;
  public var minDamage: Int;
  public var maxDamage: Int;

  public function new()
    {
      super();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      attackMessage = 'XX attacks YY.';
      skill = 50;
      sound = null;
      minDamage = 1;
      maxDamage = 3;
    }

// handles configurable melee attack logic
  public override function logicAttack(ai: AI, target: AITarget): Bool
    {
      if (!ai.isNear(target.x, target.y))
        return false;

      // roll to hit
      var chance = skill;
      if (chance < 1)
        chance = 1;
      else if (chance > 99)
        chance = 99;
      if (Std.random(100) >= chance)
        {
          ai.log('tries to attack ' + target.theName() + ', but misses.');
          return true;
        }

      if (sound != null)
        ai.emitSound(sound);

      // roll damage
      var damage = __Math.damage({
        name: 'ability/' + name,
        min: minDamage,
        max: maxDamage,
      });
      // replace templates and log
      var msg = StringTools.replace(attackMessage, 'XX', ai.TheName());
      msg = StringTools.replace(msg, 'YY', target.theName());
      target.game.log(msg + ' for ' + damage + ' damage.');

      // apply damage
      target.onDamage(damage);
      return true;
    }
}

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
  public override function logicAttack(ai: AI, target: AttackTarget): Bool
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
          playMelee3D(ai, target, false);
          ai.log('tries to attack ' + target.theName() + ', but misses.');
          return true;
        }

      // 3D lunge + target shake; when the view takes over it owns the attack audio too
      var handled = playMelee3D(ai, target, true);
      if (sound != null)
        ai.emitSound(sound, !handled);

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

// 3D melee choreography for the ability path (it bypasses the CommonLogic weapon bridge):
// lunge + hit sound + target shake, no blood (ability damage spawns none in 2D either).
// returns true if the view took over (the caller then skips the attack audio)
  function playMelee3D(ai: AI, target: AttackTarget, hit: Bool): Bool
    {
      var scene = target.game.scene;
      if (scene.city3d == null)
        return false;
      return scene.city3d.playMelee(ai.entity, hit ? target.entity() : null,
        ai.x, ai.y, target.x, target.y,
        hit && sound != null ? sound.file : null, null, false, 0, 0);
    }
}

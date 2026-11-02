// configurable melee ability used by special AI attacks
package abilities;

import l10n.Loc;

import ai.AI;

class BasicMelee extends Ability
{
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
          ai.log(target.type == TARGET_PLAYER ?
            T('{ai:The} tries to attack you, but misses.', { ai: ai }) :
            T('{ai:The} tries to attack {target:the}, but misses.', {
              ai: ai,
              target: target,
            }));
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
      // log the hit
      target.game.log(Loc.fmt(hitText(target.type == TARGET_PLAYER), {
        ai: ai,
        target: target,
        damage: damage,
      }));

      // apply damage
      target.onDamage(damage);
      return true;
    }

// the hit sentence template, formatted with {ai}, {target} and {damage}; isYou = the target is the
// parasite itself, a separate template that names no {target} (French puts "you" before the verb)
  function hitText(isYou: Bool): String
    {
      return (isYou ?
        T('{ai:The} attacks you for {damage} damage.') :
        T('{ai:The} attacks {target:the} for {damage} damage.'));
    }

// 3D melee choreography for the ability path (it bypasses the CommonLogic weapon bridge):
// lunge + hit sound + target shake, no blood (ability damage spawns none in 2D either).
// returns true if the view took over (the caller then skips the attack audio)
  function playMelee3D(ai: AI, target: AttackTarget, hit: Bool): Bool
    {
      return target.game.scene.view3d.playMelee(ai.entity, hit ? target.entity() : null,
        ai.x, ai.y, target.x, target.y,
        hit && sound != null ? sound.file : null, null, false, 0, 0);
    }
}

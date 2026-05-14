// common AI logic routines
package ai;

import game.Game;
import particles.*;
import _PlayerAction;
import __Math;

class CommonLogic
{
  public static var game: Game;

// runs post-hit weapon hook
  static function logicAttackPost(attacker: Attacker, target: AttackTarget)
    {
      if (attacker.weaponInfo == null ||
          attacker.ai == null)
        return;
      var weaponItem: items.Weapon = cast attacker.weaponInfo;
      weaponItem.logicAttackPost(attacker.ai, target, attacker.isPlayer);
    }

// handles first-turn raw smash use for melee AI
  public static function useRawSmash(attacker: Attacker,
      weapon: WeaponInfo): Bool
    {
      if (!attacker.canUseAttackAbilities())
        return false;
      var ai = attacker.ai;
      if (ai.state != AI_STATE_ALERT ||
          ai.stateTime != 1)
        return false;
      if (weapon.isRanged ||
          weapon.type != WEAPON_MELEE)
        return false;
      if (!ai.inventory.has('rawSmash') ||
          ai.effects.has(EFFECT_SMASH))
        return false;

      var item = ai.inventory.get('rawSmash');
      if (item == null)
        return false;

      var action: _PlayerAction = {
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Inject ' + item.getName(),
        item: item,
        who: ai
      };
      var handled = item.info.action('use', action);
      return (handled == true);
    }

// handles ingrained ability use before normal attack flow
  public static function useAttackAbilities(attacker: Attacker,
      target: AttackTarget): Bool
    {
      if (!attacker.canUseAttackAbilities())
        return false;
      if (target.type == TARGET_OBJECT)
        return false;
      for (ability in attacker.ai.abilities)
        if (ability.logicAttack(attacker.ai, target))
          return true;
      return false;
    }

// returns debug label for attack damage rolls
  static function getTargetDebugName(target: AttackTarget): String
    {
      switch (target.type)
        {
          case TARGET_AI:
            return 'AI';
          case TARGET_OBJECT:
            return 'object';
          case TARGET_PLAYER:
            return 'player';
        }
    }

// logic: attack target (player, ai, or object)
  public static function logicAttack(attacker: Attacker, target: AttackTarget)
    {
      // get current weapon
      var weapon = attacker.weapon;

      // ingrained abilities can consume the attack action
      if (useAttackAbilities(attacker, target))
        return;

      // first-turn melee users consume raw smash before attacking
      if (useRawSmash(attacker, weapon))
        return;

      // check for distance on melee
      if (!weapon.isRanged &&
          !attacker.isNear(target.x, target.y))
        {
          if (attacker.canMoveToTarget())
            attacker.logicMoveTo(target.x, target.y);
          return;
        }

      // check for line of sight on ranged
      if (attacker.needsRangedLineOfSight() &&
          weapon.isRanged &&
          !attacker.seesPosition(target.x, target.y))
        {
          attacker.logicMoveTo(target.x, target.y);
          return;
        }

      // parasite attached to human, do not shoot (blackops are fine)
      if (!attacker.isPlayer &&
          attacker.ai != null &&
          attacker.ai.isHuman &&
          target.type == TARGET_PLAYER &&
          game.player.state == PLR_STATE_ATTACHED &&
          game.playerArea.attachHost.isHuman &&
          attacker.ai.type != 'blackops')
        {
          if (Std.random(100) < 30)
            {
              attacker.log('hesitates to attack you.');
              attacker.emitSound({
                text: 'Shit!',
                radius: 5,
                alertness: 10
              });
              return;
            }
        }

      // propagate attacker-side combat noise
      game.managerArea.onNoise(attacker.x, attacker.y, weapon.isRanged);

      // notify target
      if (target.type == TARGET_AI)
        {
          target.ai.attacked({
            who: attacker.getAttackEventWho(),
            ai: attacker.ai,
            weapon: weapon,
          });
        }

      // weapon skill level (ai + parasite bonus)
      var rollMods = [];
      if (attacker.isPlayer)
        rollMods.push({
          name: '0.5x parasite',
          val: 0.5 * game.player.skills.getLevel(weapon.skill)
        });
      var roll = true;
      if (!attacker.alwaysHits)
        roll = __Math.skill({
          id: weapon.skill,
          level: attacker.skillLevel,
          mods: rollMods,
        });

      // +1 from passive when not assimilated, so it becomes 3
      attacker.spendAttackEnergy();
//        (ai.hasTrait(TRAIT_ASSIMILATED) ? 2 : 2);

      var targetBloodType = 'red';
      if (target.type == TARGET_AI)
        targetBloodType = target.ai.bloodType();

      // draw attack effects
      if (weapon.isRanged)
        {
          if (weapon.projectile != null)
            Particle.createProjectile(weapon.projectile, game.scene,
              attacker.x, attacker.y, { x: target.x, y: target.y },
              roll, targetBloodType);
          else Particle.createShot(
            weapon.sound.file, game.scene, attacker.x, attacker.y,
            { x: target.x, y: target.y }, roll, targetBloodType);
        }

      // roll skill
      if (!roll)
        {
          var sound = (weapon.soundMiss != null ? weapon.soundMiss : weapon.sound);
          attacker.emitSound(sound);
          attacker.log('tries to ' + weapon.verb1 + ' ' +
            target.theName() + ', but misses.');

          if (attacker.isPlayer)
            {
              // set alerted state
              if (attacker.ai.state == AI_STATE_IDLE)
                attacker.ai.setState(AI_STATE_ALERT, REASON_DAMAGE);
              // post-action call
              game.playerArea.actionPost();
            }
          return;
        }
      else attacker.emitSound(weapon.sound);

      // blood effect on hit
      if (weapon.spawnBlood)
        Particle.createSplat(targetBloodType, game.scene,
          { x: target.x, y: target.y }, {
            x: attacker.x,
            y: attacker.y,
          });

      // stun damage on ai - stun the host
      // if target is parasite, works as regular damage
      if (weapon.type == WEAPON_STUN &&
          target.type == TARGET_AI)
        {
          var mods: Array<_DamageBonus> = [];

          // protective cover
          var o = target.ai.organs.get(IMP_PROT_COVER);
          if (o != null)
            mods.push({
              name: 'protective cover',
              val: - Std.int(o.params.armor)
            });

          var roll = __Math.damage({
            name: 'STUN ' + attacker.getDebugName() + '->AI',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          var resist = __Math.opposingAttr(
            target.ai.constitution, roll, 'con/stun');
          if (resist)
            roll = Std.int(roll / 2);
          if (game.config.extendedInfo)
            game.info('stun for ' + roll + ' rounds, -' + (roll * 2) +
              ' control.');

          // lose control if attacking host
          if (target.ai.isPlayerHost())
            {
              game.player.hostControl -= roll * 2;
              attacker.log(weapon.verb2 + ' your host for ' + roll +
                " rounds. You're losing control.");
              // on damage event
              game.playerArea.onDamage(0);
            }
          else attacker.log(weapon.verb2 + ' ' +
            target.theName() + ' for ' + roll + " rounds.");

          target.ai.onEffect(new effects.Paralysis(game, roll));
          // damage event (for alert)
          target.onDamage(0);
        }

      // normal damage
      else
        {
          var mods: Array<_DamageBonus> = [];
          // all melee weapons have damage bonus
          if (!weapon.isRanged &&
              weapon.type == WEAPON_MELEE)
            mods.push({
              name: 'melee 0.5xSTR',
              min: 0,
              max: Std.int(attacker.strength / 2)
            });

          // protective cover
          if (target.type == TARGET_AI)
            {
              var o = target.ai.organs.get(IMP_PROT_COVER);
              if (o != null)
                mods.push({
                  name: 'protective cover',
                  val: - Std.int(o.params.armor)
                });

              // armor
              var clothing = target.ai.inventory.clothing.info;
              if (clothing.armor.damage != 0)
                mods.push({
                  name: clothing.name,
                  val: - clothing.armor.damage
                });
            }
          // effect-driven damage bonuses
          var effectMods = attacker.damageMods(weapon);
          for (mod in effectMods)
            mods.push(mod);

          var damage = __Math.damage({
            name: attacker.getDebugName() +
              '->' +
              getTargetDebugName(target),
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          attacker.log(weapon.verb2 + ' ' + target.theName() +
            ' for ' + damage + ' damage.');

          // on damage event
          target.onDamage(damage, attacker.ai);
        }

      // run weapon-specific post-hit effects
      logicAttackPost(attacker, target);
    }
}

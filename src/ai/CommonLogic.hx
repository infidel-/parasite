// common AI logic routines
package ai;

import game.Game;
import particles.*;
import ai.AI;
import ItemInfo;
import _PlayerAction;
import __Math;

class CommonLogic
{
  public static var game: Game;

// runs post-hit weapon hook
  static function logicAttackPost(ai: AI, target: AITarget,
      isAttackerPlayer: Bool, weaponInfo: ItemInfo)
    {
      var weaponItem: items.Weapon = cast weaponInfo;
      weaponItem.logicAttackPost(ai, target, isAttackerPlayer);
    }

// handles first-turn raw smash use for melee AI
  public static function useRawSmash(ai: AI, weapon: WeaponInfo,
      isAttackerPlayer: Bool): Bool
    {
      if (isAttackerPlayer)
        return false;
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
  public static function useAttackAbilities(ai: AI, target: AITarget,
      isAttackerPlayer: Bool): Bool
    {
      if (isAttackerPlayer)
        return false;
      for (ability in ai.abilities)
        if (ability.logicAttack(ai, target))
          return true;
      return false;
    }

// logic: attack target (player or ai)
  public static function logicAttack(ai: AI, target: AITarget, isAttackerPlayer: Bool)
    {
      // get current weapon
      var weaponInfo = ai.getCurrentWeaponItemInfo();
      var weapon = weaponInfo.weapon;

      // ingrained abilities can consume the attack action
      if (useAttackAbilities(ai, target, isAttackerPlayer))
        return;

      // first-turn melee users consume raw smash before attacking
      if (useRawSmash(ai, weapon, isAttackerPlayer))
        return;

      // check for distance on melee
      if (!weapon.isRanged &&
          !ai.isNear(target.x, target.y))
        {
          if (!isAttackerPlayer)
            ai.logicMoveTo(target.x, target.y);
          return;
        }

      // check for line of sight on ranged
      if (!isAttackerPlayer &&
          weapon.isRanged &&
          !ai.seesPosition(target.x, target.y))
        {
          ai.logicMoveTo(target.x, target.y);
          return;
        }

      // parasite attached to human, do not shoot (blackops are fine)
      if (!isAttackerPlayer &&
          ai.isHuman &&
          target.type == TARGET_PLAYER &&
          game.player.state == PLR_STATE_ATTACHED &&
          game.playerArea.attachHost.isHuman &&
          ai.type != 'blackops')
        {
          if (Std.random(100) < 30)
            {
              ai.log('hesitates to attack you.');
              ai.emitSound({
                text: 'Shit!',
                radius: 5,
                alertness: 10
              });
              return;
            }
        }

      // notify target
      if (target.type == TARGET_AI)
        {
          if (isAttackerPlayer)
            target.ai.attacked({
              who: 'player',
              ai: null,
              weapon: weapon,
            });
          else target.ai.attacked({
            who: 'ai',
            ai: ai,
            weapon: weapon,
          });
        }

      // weapon skill level (ai + parasite bonus)
      var rollMods = [];
      if (isAttackerPlayer)
        rollMods.push({
          name: '0.5x parasite',
          val: 0.5 * game.player.skills.getLevel(weapon.skill)
        });
      var roll = __Math.skill({
        id: weapon.skill,
        level: ai.skills.getLevel(weapon.skill),
        mods: rollMods,
      });

      // +1 from passive when not assimilated, so it becomes 3
      if (isAttackerPlayer)
        ai.energy -= 2;
//        (ai.hasTrait(TRAIT_ASSIMILATED) ? 2 : 2);

      var targetBloodType = 'red';
      if (target.type == TARGET_AI)
        targetBloodType = target.ai.bloodType();

      // draw attack effects
      if (weapon.isRanged)
        Particle.createShot(
          weapon.sound.file, game.scene, ai.x, ai.y,
          { x: target.x, y: target.y }, roll, targetBloodType);

      // roll skill
      if (!roll)
        {
          var sound = (weapon.soundMiss != null ? weapon.soundMiss : weapon.sound);
          ai.emitSound(sound);
          ai.log('tries to ' + weapon.verb1 + ' ' + target.theName() + ', but misses.');

          if (isAttackerPlayer)
            {
              // set alerted state
              if (ai.state == AI_STATE_IDLE)
                ai.setState(AI_STATE_ALERT, REASON_DAMAGE);
              // post-action call
              game.playerArea.actionPost();
            }
          return;
        }
      else ai.emitSound(weapon.sound);

      // blood effect on hit
      if (weapon.spawnBlood)
        Particle.createSplat(targetBloodType, game.scene,
          { x: target.x, y: target.y });

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
            name: 'STUN ' + (isAttackerPlayer ? 'player' : 'AI') + '->AI',
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
              ai.log(weapon.verb2 + ' your host for ' + roll +
                " rounds. You're losing control.");
              // on damage event
              game.playerArea.onDamage(0);
            }
          else ai.log(weapon.verb2 + ' ' +
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
              max: Std.int(ai.strength / 2)
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
          var effectMods = ai.effects.damageMods(weapon);
          for (mod in effectMods)
            mods.push(mod);

          var damage = __Math.damage({
            name: (isAttackerPlayer ? 'player' : 'AI') +
              '->' +
              (target.type == TARGET_AI ? 'AI' : 'player'),
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          ai.log(weapon.verb2 + ' ' + target.theName() +
            ' for ' + damage + ' damage.');

          // on damage event
          target.onDamage(damage);
        }

      // run weapon-specific post-hit effects
      logicAttackPost(ai, target, isAttackerPlayer, weaponInfo);
    }
}

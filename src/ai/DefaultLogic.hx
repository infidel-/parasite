// default AI logic moved to separate class
package ai;

import game.Game;
import const.*;
import objects.*;
import particles.*;
import ai.AI;
import _AIState;
import __Math;

class DefaultLogic
{
  public static var game: Game;

// run AI logic turn
  public static function turn(ai: AI)
    {
      switch (ai.state)
        {
          // idle - roam around or guard, etc
          case AI_STATE_IDLE:
            stateIdle(ai);

          // alerted - try to run away or attack
          case AI_STATE_ALERT:
            stateAlert(ai);

          // controlled by parasite
          case AI_STATE_HOST:
            stateHost(ai);

          // move to target x,y
          case AI_STATE_MOVE_TARGET:
            stateMoveTarget(ai);

          // investigate
          case AI_STATE_INVESTIGATE:
            stateInvestigate(ai);
          default:
        }
    }

// AI vision: called in idle and movement to target states
  static function visionIdle(ai: AI)
    {
      // full affinity + consent results in ignore
      if (ai.isAgreeable())
        ai.alertness -= 5;
      // player visibility
      else if (!game.player.vars.invisibilityEnabled &&
          ai.seesPosition(game.playerArea.x, game.playerArea.y))
        {
          var distance = game.playerArea.distance(ai.x, ai.y);
          var baseAlertness = 3;
          var alertnessBonus = 0;

          // if player is on a host, check for organs
          if (game.player.state == PLR_STATE_HOST)
            {
              // organ: camouflage layer
              var params = EvolutionConst.getParams(IMP_CAMO_LAYER, 0);
              var o = ai.organs.get(IMP_CAMO_LAYER);
              if (o != null)
                baseAlertness = o.params.alertness;
              else baseAlertness = params.alertness;

              // organ: protective cover
              var params = EvolutionConst.getParams(IMP_PROT_COVER, 0);
              var o = ai.organs.get(IMP_PROT_COVER);
              if (o != null)
                alertnessBonus += o.params.alertness;
              else alertnessBonus += params.alertness;
            }
          ai.alertness += Std.int(baseAlertness * (AI.VIEW_DISTANCE + 1 - distance)) +
            alertnessBonus;
          game.profile.addPediaArticle('npcAlertness');
        }
      else ai.alertness -= 5;

      // AI has become alerted
      if (ai.alertness >= 100)
        {
          var reason = REASON_PARASITE;

          if (game.player.state == PLR_STATE_HOST &&
              game.player.host.isHuman)
            reason = REASON_HOST;

          ai.setState(AI_STATE_ALERT, reason);
          return;
        }

      // get all objects that this AI sees
      var tmp = game.area.getObjectsInRadius(ai.x, ai.y, AI.VIEW_DISTANCE, true);

      for (obj in tmp)
        {
          // not a body
          if (obj.type != 'body')
            continue;

          // object already seen by this AI
          if (ai.hasSeenObject(obj.id))
            continue;

          var body: BodyObject = cast obj;

          // human AI becomes alert on seeing human bodies
          if (ai.isHuman && body.isHumanBody)
            {
              if (!body.wasSeen)
                {
                  // mark body as seen by someone to limit the law response
                  body.wasSeen = true;

                  ai.setState(AI_STATE_ALERT, REASON_BODY);
                }

              // silent alert - no calling law
              else ai.setState(AI_STATE_ALERT, REASON_BODY_SILENT);
            }

          ai.objectSeen(obj.id);
        }
    }

// logic: roam around (default)
  static function logicRoam(ai: AI)
    {
      // roam target set, move to it
      if (ai.roamTargetX >= 0 && ai.roamTargetY >= 0)
        {
          ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
          return;
        }

      if (Math.random() < 0.2)
        ai.changeRandomDirection();

      // nowhere to move - should be a bug
      if (ai.direction == -1)
        return;

      var nx = ai.x + Const.dirx[ai.direction];
      var ny = ai.y + Const.diry[ai.direction];
      var ok =
        (game.area.isWalkable(nx, ny) &&
         !game.area.hasAI(nx, ny) &&
         !(game.playerArea.x == nx && game.playerArea.y == ny));
      if (!ok)
        {
          ai.changeRandomDirection();
          return;
        }
      else ai.setPosition(nx, ny);
    }

// state: default idle state handling
  static function stateIdle(ai: AI)
    {
      // AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness go down
      // if roam target is set, continue moving instead
      if (ai.alertness > 0 && ai.roamTargetX < 0)
        return;

      // TODO: i could make hooks here, leaving the alert logic intact

      // guards stand on one spot
      // someday there might even be patrollers...
      if (ai.isGuard)
        1;
      // roam by default
      else logicRoam(ai);
    }

// state: default alert state handling
  static function stateAlert(ai: AI)
    {
      // NOTE: must be first check in this function
      // parasite attached - try to tear it away
      if (ai.parasiteAttached)
        {
          if (!ai.isAgreeable())
            ai.logicTearParasiteAway();
          return;
        }

      // alerted timer update
      if (!game.player.vars.invisibilityEnabled &&
          ai.seesPosition(game.playerArea.x, game.playerArea.y))
        ai.timers.alert = AI.ALERTED_TIMER;
      else ai.timers.alert--;

      // AI calms down
      // relentless AI cannot calm down once alerted
      if (ai.timers.alert == 0 && !ai.isRelentless)
        {
          // guard must return to guard spot
          if (ai.isGuard &&
              (ai.x != ai.guardTargetX || ai.y != ai.guardTargetY))
            {
              ai.setState(AI_STATE_MOVE_TARGET);
              ai.roamTargetX = ai.guardTargetX;
              ai.roamTargetY = ai.guardTargetY;
            }
          // otherwise become idle
          else ai.setState(AI_STATE_IDLE);
          ai.alertness = 10;
          return;
        }

      // aggressive AI - attack player if he is near or search for him
      // same for berserk effect
      if (ai.isAggressive ||
          ai.effects.has(EFFECT_BERSERK))
        {
          if (!game.player.vars.invisibilityEnabled)
            {
              // search for player
              // we cheat a little and follow invisible player
              // before alert timer ends
              if (!ai.seesPosition(game.playerArea.x, game.playerArea.y))
                ai.logicMoveTo(game.playerArea.x, game.playerArea.y);

              // try to attack
              else logicAttack(ai);
            }
        }

      // not aggressive AI - try to run away
      else ai.logicRunAwayFrom(game.playerArea.x, game.playerArea.y);
    }

// logic: attack player
  static function logicAttack(ai: AI)
    {
      // get current weapon
      var item = ai.inventory.getFirstWeapon();
      var info = null;

      // use animal attack
      if (!ai.isHuman)
        info = ItemsConst.animal;
      // use fists
      else if (item == null)
        info = ItemsConst.fists;
      else info = item.info;
      var weapon = info.weapon;

      // check for distance on melee
      if (!weapon.isRanged &&
          !ai.isNear(game.playerArea.x, game.playerArea.y))
        {
          ai.logicMoveTo(game.playerArea.x, game.playerArea.y);
          return;
        }

      // parasite attached to human, do not shoot (blackops are fine)
      if (ai.isHuman &&
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

      // play weapon sound
      if (weapon.sound != null)
        ai.emitSound(weapon.sound);

      // weapon skill level (ai + parasite bonus)
      var roll = __Math.skill({
        id: weapon.skill,
        // hardcoded animal attack skill level
        level: ai.skills.getLevel(weapon.skill),
      });

      // draw attack effect
      if (weapon.isRanged)
        Particle.createShot(
          weapon.sound.file, game.scene, ai.x, ai.y,
          game.playerArea, roll);

      // roll skill
      if (!roll)
        {
          ai.log('tries to ' + weapon.verb1 + ' you, but misses.');
          return;
        }

      // stun damage
      // when player has a host, stuns the host
      // when player is a parasite, just do regular damage
      if (weapon.type == WEAPON_STUN &&
          game.player.state == PLR_STATE_HOST)
        {
          var mods: Array<_DamageBonus> = [];

          // protective cover
          if (game.player.state == PLR_STATE_HOST)
            {
              var o = game.player.host.organs.get(IMP_PROT_COVER);
              if (o != null)
                mods.push({
                  name: 'protective cover',
                  val: - Std.int(o.params.armor)
                });
            }

          var roll = __Math.damage({
            name: 'STUN AI->player',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          var resist = __Math.opposingAttr(
            game.player.host.constitution, roll, 'con/stun');
          if (resist)
            roll = Std.int(roll / 2);
          if (game.config.extendedInfo)
            game.info('stun for ' + roll + ' rounds, -' + (roll * 2) +
              ' control.');
          game.player.hostControl -= roll * 2;

          ai.log(weapon.verb2 + ' your host for ' + roll +
            " rounds. You're losing control.");

          game.player.host.onEffect({
            type: EFFECT_PARALYSIS,
            points: roll,
            isTimer: true
          });

          game.playerArea.onDamage(0); // on damage event
        }

      // normal damage
      else
        {
          var mods: Array<_DamageBonus> = [];
          // all melee weapons have damage bonus
          if (!weapon.isRanged && weapon.type == WEAPON_BLUNT)
            mods.push({
              name: 'melee 0.5xSTR',
              min: 0,
              max: Std.int(ai.strength / 2)
            });

          // protective cover
          if (game.player.state == PLR_STATE_HOST)
            {
              var o = game.player.host.organs.get(IMP_PROT_COVER);
              if (o != null)
                mods.push({
                  name: 'protective cover',
                  val: - Std.int(o.params.armor)
                });

              // armor
              var clothing = game.player.host.inventory.clothing.info;
              if (clothing.armor.damage != 0)
                mods.push({
                  name: clothing.name,
                  val: - clothing.armor.damage
                });
            }

          var damage = __Math.damage({
            name: 'AI->player',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          ai.log(weapon.verb2 + ' ' +
            (game.player.state == PLR_STATE_HOST ? 'your host' : 'you') +
            ' for ' + damage + ' damage.');

          game.playerArea.onDamage(damage); // on damage event
        }
    }

// state: host logic
  static function stateHost(ai: AI)
    {
      // non-assimilated hosts emit random sounds
      if (!ai.hasTrait(TRAIT_ASSIMILATED))
        ai.emitRandomSound('' + AI_STATE_HOST,
          Std.int((100 - game.player.hostControl) / 3));

      // effect: cannot tear parasite away (given right after invasion)
      if (ai.effects.has(EFFECT_CANNOT_TEAR_AWAY))
        return;

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          ai.log('manages to tear you away.');
          ai.onDetach('default');
          game.playerArea.onDetach(); // notify player
        }
    }

// state: move to target spot
  static function stateMoveTarget(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      // stand and wonder what happened until alertness goes down
      if (ai.alertness > 0)
        return;

      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX || ai.y != ai.roamTargetY)
        return;
      // spot reached, idling
      ai.roamTargetY = -1;
      ai.roamTargetY = -1;
      ai.setState(AI_STATE_IDLE);
    }

// state: investigate (move to target spot ignoring alertness)
  static function stateInvestigate(ai: AI)
    {
      // basic AI vision
      visionIdle(ai);

      ai.logicMoveTo(ai.roamTargetX, ai.roamTargetY);
      if (ai.x != ai.roamTargetX || ai.y != ai.roamTargetY)
        return;
      // spot reached, idling
      ai.roamTargetY = -1;
      ai.roamTargetY = -1;
      ai.setState(AI_STATE_IDLE);
    }
}

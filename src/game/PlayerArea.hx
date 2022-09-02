// state (area mode)

package game;

import hxd.Key;
import ai.AI;
import entities.PlayerEntity;
import objects.AreaObject;
import const.*;
import __Math;

class PlayerArea extends _SaveObject
{
  static var _ignoredFields = [ 'player', 'entity', 'actionTS',
    'currentAction', 'attachHost',
  ];
  var game: Game; // game state link
  var player: Player; // state link

  public var entity: PlayerEntity; // player ui entity
  public var x: Int; // x,y on grid
  public var y: Int;
  public var ap: Int; // player action points (2 per turn)
  var knownObjects: List<String>; // list of known area object types
  var state(get, set): _PlayerState; // state link
  public var path(default, null): Array<aPath.Node>; // current player path
  var actionTS: Float; // last time player moved on a path/did action
  public var currentAction(default, null): _PlayerAction; // current continuous action

  // state "parasite"

  // state "attach"
  var attachHostID: Int;
  public var attachHost: AI; // host player is attached to
  public var attachHold(default, set): Int; // hold strength


  public function new(g: Game)
    {
      game = g;
      player = game.player;
      path = null;
      actionTS = 0;
      currentAction = null;
      x = 0;
      y = 0;
      ap = 2;
      attachHold = 0;
      attachHost = null;
      attachHostID = -1;
      knownObjects = new List<String>();
      knownObjects.add('body');
      knownObjects.add('pickup');
      knownObjects.add('habitat');
      knownObjects.add('nutrients');
      entity = new PlayerEntity(game, x, y);
    }

// called post-loading game
  public function loadPost()
    {
      if (state == PLR_STATE_ATTACHED && attachHostID >= 0)
        {
          entity.visible = false;
          attachHost = game.area.getAIByID(attachHostID);
          attachHost.updateMask(Const.FRAME_MASK_ATTACHED);
        }
    }

// end of turn for player (in area mode)
  public function turn()
    {
      // these can only happen in area mode
      // (region mode will throw player in area mode before that)

      // state: host (we might lose it if energy drops to zero earlier)
      if (state == PLR_STATE_HOST)
        {
          // control grows while in habitat
          if (game.area.isHabitat)
            player.hostControl++;

          // also when player has dopamine control
          else if (player.evolutionManager.getLevel(IMP_DOPAMINE) > 0)
            player.hostControl += 5;

          else player.hostControl--;

          if (player.hostControl <= 0)
            {
              player.host.onDetach('default');
              onDetach();

              log("You've lost control of the host.");
            }
        }

      ap = 2;
    }


// does player know about this object?
  public inline function knowsObject(id: String): Bool
    {
      return (Lambda.has(knownObjects, id));
    }


// ==============================   ACTIONS   =======================================


// get actions list (area mode)
  public function updateActionList()
    {
      if (state == PLR_STATE_PARASITE)
        {
          if (game.area.hasAI(x, y))
            game.ui.hud.addAction({
              id: 'attachHost',
              type: ACTION_AREA,
              name: 'Attach To Host',
              energy: 0
            });
        }

      // parasite is attached to host
      else if (state == PLR_STATE_ATTACHED)
        {
          if (attachHold >= 90)
            game.ui.hud.addAction({
              id: 'invadeHost',
              type: ACTION_AREA,
              name: 'Invade Host',
              energy: 10
            });
          if (attachHold < 90)
            game.ui.hud.addAction({
              id: 'hardenGrip',
              type: ACTION_AREA,
              name: 'Harden Grip',
              canRepeat: true,
              energy: 5
            });
          if (game.player.energy <= 30)
            game.ui.hud.addAction({
              id: 'invadeEarly',
              type: ACTION_AREA,
              name: 'Early Invasion',
              energy: 1
            });
        }

      // parasite in control of host
      else if (state == PLR_STATE_HOST)
        {
          if (player.hostControl < 100)
            game.ui.hud.addAction({
              id: 'reinforceControl',
              type: ACTION_AREA,
              name: 'Reinforce Control',
              canRepeat: true,
              energy: 5
            });

          // organ-based actions
          player.host.organs.updateActionList();

          // evolution manager actions
          player.evolutionManager.updateActionList();

          game.ui.hud.addKeyAction({
            id: 'leaveHost',
            type: ACTION_AREA,
            name: 'Leave Host',
            energy: 0,
            key: 'x'
          });
        }

      // improvement actions
      for (imp in player.evolutionManager)
        {
          var info = imp.info;
          if (info.action != null)
            game.ui.hud.addAction(info.action);
        }

      // area object actions - need to learn about objects
//      var olist = game.area.getObjectsAt(x, y);
      var olist = game.area.getObjectsInRadius(x, y, 1, false);
      if (olist != null && game.goals.completed(GOAL_PROBE_BRAIN))
        for (o in olist)
          {
            // check if object is near and can be activated when near
            if ((o.x != x || o.y != y) && !o.canActivateNear())
              continue;
            // player does not know what this is, cannot activate it
            if (state == PLR_STATE_HOST &&
                !o.known() &&
                player.host.isHuman &&
                game.player.vars.objectsEnabled)
              game.ui.hud.addAction({
                id: 'learnObject',
                type: ACTION_AREA,
                name: 'Learn About Object',
                energy: 10,
                obj: o,
              });
            // object known - add all actions defined by object
            else if (o.known())
              o.updateActionList();
          }

      // leave area action
      if (state != PLR_STATE_ATTACHED && !game.area.info.isInhabited)
        game.ui.hud.addAction({
          id: 'leaveArea',
          type: ACTION_AREA,
          name: 'Leave Area',
          energy: 0
        });
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(action: _PlayerAction)
    {
      // restart
      if (action.id == 'restart')
        {
          game.restart();
          return;
        }

      var ret = true;
      // cannot do some actions while in paralysis
      if (state == PLR_STATE_HOST &&
          player.host.effects.has(EFFECT_PARALYSIS) &&
          (action.type == ACTION_OBJECT || action.id == 'leaveArea'))
        {
          log('Your host is paralyzed.', COLOR_HINT);
          game.updateHUD();
          return;
        }

      // area object action
      if (action.type == ACTION_OBJECT)
        {
          var ao: AreaObject = action.obj;
          ret = ao.action(action);
        }

      // host organ-based action
      else if (action.type == ACTION_ORGAN)
        ret = player.host.organs.areaAction(action);

      // evolution manager action
      else if (action.type == ACTION_EVOLUTION)
        ret = player.evolutionManager.action(action);

      // harden grip on the victim
      else if (action.id == 'hardenGrip')
        hardenGripAction();

      // attach host
      else if (action.id == 'attachHost')
        {
          var ai = game.area.getAI(x, y);
          ret = attachToHostAction(ai);

          game.updateHUD();
        }

      // invade host
      else if (action.id == 'invadeHost')
        invadeHostAction(false);

      // invade host early
      else if (action.id == 'invadeEarly')
        invadeEarlyAction();

      // try to reinforce control over host
      else if (action.id == 'reinforceControl')
        reinforceControlAction();

      // try to leave current host
      else if (action.id == 'leaveHost')
        {
          log('You release the host.');
          leaveHostAction('default');
        }

      // probe host brain
      else if (action.id == 'probeBrain')
        probeBrainAction();

      // learn about object
      else if (action.id == 'learnObject')
        learnObjectAction(action.obj);

      // try to leave area
      else if (action.id == 'leaveArea')
        leaveAreaAction();
      else if (action.id == 'skipTurn')
        game.turn();

      // action interrupted for some reason
      if (!ret)
        return;

      // spend energy
      if (action.energy != null)
        {
          if (state == PLR_STATE_HOST)
            player.host.energy -= action.energy;
          else player.energy -= action.energy;
        }
      else if (action.energyFunc != null)
        {
          if (state == PLR_STATE_HOST)
            player.host.energy -= action.energyFunc(player);
          else player.energy -= action.energyFunc(player);
        }

      postAction(); // post-action call
    }


// post-action call: remove AP and new turn
  public function postAction()
    {
      // host death
      if (state == PLR_STATE_HOST &&
          (player.host.state == AI_STATE_DEAD || player.host.energy <= 0))
        {
          game.player.onHostDeath('Your host has expired. You have to find a new one.');

          // close window just in case
          if (game.ui.state != UISTATE_MESSAGE)
            game.ui.state = UISTATE_DEFAULT;
        }

      // parasite could also be dead
      if (state == PLR_STATE_PARASITE && player.energy <= 0)
        {
          game.finish('lose', 'noHost');
          return;
        }

      else if (state == PLR_STATE_ATTACHED && player.energy <= 0)
        {
          game.finish('lose', 'noEnergy');
          return;
        }

      else if (player.health <= 0)
        {
          game.finish('lose', 'noHealth');
          return;
        }

      // fix for when player enters sewers and host dies
      // we need to recheck player icon
      if (game.location == LOCATION_REGION)
        game.scene.region.show();

      // remove 1 AP
      ap--;
      if (ap > 0)
        {
          // update AI and cell visibility to player
          if (game.location == LOCATION_AREA)
            game.area.updateVisibility();

          // update HUD info
          game.updateHUD();

          return;
        }

      // new turn and update visibility (only if still in area mode)
      if (game.location == LOCATION_AREA)
        {
          game.turn();

          // update AI and cell visibility to player
          game.area.updateVisibility();
        }

      // update HUD info
      game.updateHUD();
    }


// action: move player by dx,dy
  public function moveAction(dx: Int, dy: Int): Bool
    {
      // cannot move while in paralysis
      if (state == PLR_STATE_HOST && player.host.effects.has(EFFECT_PARALYSIS))
        {
          log('Your host is paralyzed.', COLOR_HINT);
          return false;
        }

      // try to move to the new location
      return moveBy(dx, dy);
    }


// frob the AI - atm just attach to host as a parasite
  function frobAIAction(ai: AI): Bool
    {
      var ret = false;

      // attach to new host
      if (state == PLR_STATE_PARASITE)
        {
          ret = attachToHostAction(ai);
        }

      // push past AI
      else if (state == PLR_STATE_HOST)
        {
          if (ai.state == AI_STATE_PRESERVED)
            {
              log('Your host is unable to budge ' + ai.getName() + '.');
              return true;
            }
          // opposing strength check
          if (!__Math.opposingAttr(player.host.strength, ai.strength, 'strength'))
            {
              log('Your host does not manage to push past ' + ai.getName() + '.');
              return true;
            }

          var newx = ai.x, newy = ai.y;
          ai.setPosition(x, y, true);
          moveTo(newx, newy);
          log('Your host pushes past ' + ai.getName() + '.');
          ret = true;
        }

      return ret;
    }


// debug action: attach and invade
  public function debugAttachAndInvadeAction(ai: AI)
    {
      attachToHostAction(ai);
      attachHold = 100;
      invadeHostAction(false);
    }


// get current player weapon
  public function getWeapon()
    {
      // get current weapon
      var item = null;
      var info = null;

      // for now, just get first weapon player knows how to use
      for (ii in player.host.inventory)
        if (ii.info.weapon != null && player.knowsItem(ii.id))
          {
            item = ii;
            break;
          }

      // use animal attack
      if (!player.host.isHuman)
        info = ItemsConst.animal;
      // use fists
      else if (item == null)
        info = ItemsConst.fists;
      else info = item.info;

      return info.weapon;
    }


// action: attack this ai
  public function attackAction(ai: AI)
    {
      // not in a host mode
      if (state != PLR_STATE_HOST)
        return;

      // cannot attack when paralyzed
      if (player.host.effects.has(EFFECT_PARALYSIS))
        {
          log('Your host is paralyzed.', COLOR_HINT);
          return;
        }

      // check if player can see that spot
      if (!game.area.isVisible(x, y, ai.x, ai.y))
        return;

      // get current weapon
      var weapon = getWeapon();

      // check for distance on melee
      if (!weapon.isRanged && !ai.isNear(x, y))
        return;

      // propagate shooting/melee event
      game.managerArea.onAttack(x, y, weapon.isRanged);

      ai.onAttack(); // attack event

      // weapon skill level (ai + parasite bonus)
      var roll = __Math.skill({
        id: weapon.skill,
        level: player.host.skills.getLevel(weapon.skill),
        mods: [{
          name: '0.5x parasite',
          val: 0.5 * player.skills.getLevel(weapon.skill)
        }]
      });

      // play weapon sound
      if (weapon.sound != null)
        game.scene.sounds.play(weapon.sound);

      // +1 from passive when not assimilated, so it becomes 3
      player.host.energy -= 2;
//        (player.host.hasTrait(TRAIT_ASSIMILATED) ? 2 : 2);

      // roll skill
      if (!roll)
        {
          log('Your host tries to ' + weapon.verb1 + ' ' +
            ai.getName() + ', but misses.');

          // set alerted state
          if (ai.state == AI_STATE_IDLE)
            ai.setState(AI_STATE_ALERT, REASON_DAMAGE);

          postAction(); // post-action call

          return;
        }

      // stun damage
      if (weapon.type == WEAPON_STUN)
        {
          var roll = __Math.damage({
            name: 'STUN player->AI',
            min: weapon.minDamage,
            max: weapon.maxDamage,
          });
          var resist = __Math.opposingAttr(ai.constitution, roll,
            'con/stun');
          if (resist)
            roll = Std.int(roll / 2);
          if (game.config.extendedInfo)
            game.info('stun for ' + roll + ' rounds');

          log('Your host ' + weapon.verb2 + ' ' + ai.getName() +
            ' for ' + roll + ' rounds.');

          ai.onEffect({
            type: EFFECT_PARALYSIS,
            points: roll,
            isTimer: true
          });
          ai.onDamage(0); // damage event (for alert)
        }

      // normal damage
      else
        {
          var mods: Array<_DamageBonus> = [];
          // all melee weapons have damage bonus
          if (!weapon.isRanged)
            mods.push({
              name: 'melee 0.5xSTR',
              min: 0,
              max: Std.int(player.host.strength / 2)
            });

          // armor
          var clothing = ai.inventory.clothing.info;
          if (clothing.armor.damage != 0)
            mods.push({
              name: clothing.name,
              val: - clothing.armor.damage
            });
          var damage = __Math.damage({
            name: 'player->AI',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          log('Your host ' + weapon.verb2 + ' ' + ai.getName() +
            ' for ' + damage + ' damage.');

          ai.onDamage(damage); // damage event
        }

      postAction(); // post-action call
    }


// action: attach to host
  function attachToHostAction(ai: AI): Bool
    {
      // armor protection
      if (ai.inventory.clothing.info.armor != null &&
          !ai.inventory.clothing.info.armor.canAttach)
        {
          game.log('You cannot attach to this host due to its clothing.',
            COLOR_HINT);
          return false;
        }

      // move to the same spot as AI
      moveTo(ai.x, ai.y);

      // set starting attach parameters
      state = PLR_STATE_ATTACHED;
      attachHost = ai;
      attachHostID = ai.id;
      entity.visible = false;

      if (ai.state == AI_STATE_PRESERVED)
        {
          attachHold = 99;
          log('You smoothly attach to the preserved host.');
        }
      else
        {
          // improv: attach efficiency
          var params = player.evolutionManager.getParams(IMP_ATTACH);
          attachHold = params.attachHoldBase;
          log('You have managed to attach to the host.');
        }

      game.profile.addPediaArticle('hostInvading');
      game.scene.sounds.play('parasite-attach');
      ai.onAttach(); // callback to AI

      return true;
    }


// action: harden grip when attached to host
  function hardenGripAction()
    {
      log('You harden your grip on the host.');

      // improv: harden grip bonus
      var params = player.evolutionManager.getParams(IMP_HARDEN_GRIP);

      var tmp = params.attachHoldBase;

      // effect: paralysis
      if (!attachHost.effects.has(EFFECT_PARALYSIS))
        tmp -= Std.int(attachHost.strength / 2);

      attachHold += tmp;
    }


// action: try to invade this AI host early
  function invadeEarlyAction()
    {
      // calculate and roll chance
      var chance = attachHold;
      if (game.player.difficulty == HARD)
        chance -= 20;
      else if (game.player.difficulty == NORMAL)
        chance -= 10;
      else if (game.player.difficulty == EASY)
        chance -= 10;
      if (chance < 5)
        chance = 5;
      if (chance > 90)
        chance = 90;
      var roll = Std.random(100);
      game.info('invade early, ' + chance + '% (roll: ' + roll + '), ' +
        (roll <= chance ? 'success' : 'fail'));
      if (roll > chance)
        {
          player.health -= 2;
          log('The host wrestles with you frantically, injuring you in the process.');
          return;
        }
      player.health -= 1;
      if (player.health == 0)
        {
          log('The host violently wrestles with you which results in a fatal injury.');
          return;
        }
      log('Your proboscis painfully penetrates the warm flesh. You are now in control of the host.');
      invadeHostAction(true);
    }

// action: try to invade this AI host
  function invadeHostAction(fromInvadeEarly: Bool)
    {
      if (!fromInvadeEarly)
        log('Your proboscis penetrates the warm flesh. You are now in control of the host.');

      // save AI link
      player.host = attachHost;
      player.hostID = attachHostID;
      player.hostControl = 
        (attachHost.hasTrait(TRAIT_ASSIMILATED) ?
        Player.HOST_CONTROL_ASSIMILATED :
        Player.HOST_CONTROL_BASE);
      entity.visible = false;
      attachHost = null;
      attachHostID = -1;
      player.host.onInvade(); // notify ai

      // disable evolution for dogs - they can die in the same turn
      if (!player.host.isHuman)
        game.player.evolutionManager.stop();

      // set state
      state = PLR_STATE_HOST;

      // update AI visibility to player
      game.area.updateVisibility();

      // goal completed: host invaded
      game.goals.complete(GOAL_INVADE_HOST);

      // goal completed: human host invaded
      if (player.host.isHuman)
        game.goals.complete(GOAL_INVADE_HUMAN);
      game.profile.addPediaArticle('hudInfoHost');
    }


// action: try to reinforce control over host
  function reinforceControlAction()
    {
      log('You reinforce mental control over the host.');

      // improv: control efficiency
      var params = player.evolutionManager.getParams(IMP_REINFORCE);
      player.hostControl += params.reinforceControlBase -
        Std.int(player.host.psyche / 2);
    }


// action: try to leave this AI host
// NOTE: also called from preservator
  public function leaveHostAction(src: String)
    {
      player.host.onDetach(src);
      onDetach();
    }


// action: leave area
  function leaveAreaAction()
    {
      // special checks for habitat
      if (game.area.typeID == AREA_HABITAT)
        {
          // currently fighting ambush
          if (game.group.team != null && game.group.team.state == TEAM_FIGHT)
            {
              if (game.group.team.timer > 0)
                {
                  log('You try to leave but the exit is blocked! You can leave the area in ' + game.group.team.timer + ' turns.',
                    COLOR_HINT);
                  return;
                }
            }

          // no free AI allowed with some exceptions
          else if (game.area.hasAnyAI())
            {
              // preserved AI are allowed
              var ok = true;
              for (ai in game.area.getAllAI())
                if (ai.state != AI_STATE_PRESERVED && ai.state != AI_STATE_HOST)
                  {
                    ok = false;
                    break;
                  }
              if (!ok)
                {
                  log('You cannot leave the habitat with outsiders in it!',
                    COLOR_HINT);
                  return;
                }
            }

          // no leaving with any construction molds
          if (state == PLR_STATE_HOST && player.host.organs.hasMold())
            {
              log('You cannot leave the habitat with a mold.',
                COLOR_HINT);
              return;
            }
        }

      log("You leave the area.");
      path = null; // clear path
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
    }


// action: remove attached parasite from host
  function detachAction()
    {
      attachHost.parasiteAttached = false;
      attachHost.entity.setMask(null);
      onDetach();

      log('You detach from the potential host.');
    }

// updates probe brain action color
  public function getProbeBrainActionName()
    {
      var col = 'white';
      if (player.host.isHuman)
        {
          var params: Dynamic =
            player.evolutionManager.getParams(IMP_BRAIN_PROBE);
          if (player.host.isNPC && !player.host.npc.memoryKnown)
            col = 'timeline';
          else if (player.vars.skillsEnabled && params.hostSkillsMod > 0)
            {
              var hostSkill = player.host.skills.getRandomLearnableSkill();
              if (hostSkill != null)
                col = 'skill-title';
            }
        }
      return Const.col(col, 'Probe Brain');
    }

// action: probe host brain
  function probeBrainAction()
    {
      // animals do not have any useful memories
      if (!player.host.isHuman)
        {
          log('This host is not intelligent enough.');
          return;
        }

      log('You probe the brain of the host and learn its contents. The host grows weaker.');

      // skills and knowledge
      var params: Dynamic = player.evolutionManager.getParams(IMP_BRAIN_PROBE);
      if (player.vars.skillsEnabled)
        {
          // can access skills from level 2
          if (params.hostSkillsMod > 0)
            accessSkillsAction(params.hostSkillsMod);

          // can access attributes and traits on level 3
          if (params.hostAttrsMod > 0 && !player.host.isAttrsKnown)
            {
              player.host.isAttrsKnown = true;
              log('You have learned the parameters of this host.');
              game.profile.addPediaArticle('hostAttributes');

              // drug addict goal chain
              if (player.host.hasTrait(TRAIT_DRUG_ADDICT))
                game.goals.receive(GOAL_EVOLVE_DOPAMINE);
            }

          // human society knowledge
          player.skills.increase(KNOW_SOCIETY,
            params.humanSociety * player.host.intellect);
        }

      // get host name
      if (!player.host.isNameKnown)
        {
          player.host.isNameKnown = true;
          log('You find out that the name of this host is ' +
            player.host.getName() + '.');
        }

      // on first brain probe learn about items and area objects
      game.goals.complete(GOAL_PROBE_BRAIN);

      // get clues
      if (player.host.isNPC)
        {
          if (!player.host.npc.memoryKnown)
            {
              var ret = game.timeline.learnClues(player.host.event, true);
              if (!ret)
                log('You did not learn any new information.', COLOR_TIMELINE);

              // knowledge about group timer
              game.group.brainProbe();
            }

          // mark npc as scanned (after 3 times)
          if (player.host.brainProbed >= 2 &&
              !player.host.npc.memoryKnown)
            {
              player.host.npc.memoryKnown = true;

              log('This human does not know anything else.', COLOR_TIMELINE);
            }
        }

      // damage
      var damage = __Math.damage({
        name: 'brain probe',
        val: params.hostHealthBase,
        mods: [{
          name: 'luck',
          val: params.hostHealthMod,
          chance: 25 }]
      });

      player.host.onDamage(damage); // damage host

      player.host.brainProbed++; // increase counter
    }


// action: learn about area object
  function learnObjectAction(o: AreaObject)
    {
      log('You probe the brain of the host and learn what that object is for.');

      knownObjects.add(o.type);
      if (o.item != null)
        player.addKnownItem(o.item.id);
    }


//  action: access host skills (called from probeBrain)
  function accessSkillsAction(hostSkillsMod: Float)
    {
      var hostSkill = player.host.skills.getRandomLearnableSkill();
      if (hostSkill == null)
        return;

      // player already knows this skill better than the host
      var skill = player.skills.get(hostSkill.id);

      // goal completion
      game.goals.complete(GOAL_LEARN_SKILLS);

      var amount = Std.int((player.host.intellect / 10.0) *
        hostSkillsMod * hostSkill.level);

      if (skill == null)
        {
          log('You have learned the basics of ' + hostSkill.info.name + ' skill.');
          player.skills.addID(hostSkill.id, amount);
        }
      else if (!hostSkill.info.isBool)
        {
          log('You have increased your knowledge of ' + hostSkill.info.name +
            ' skill.');
          var val = Const.clampFloat(skill.level + amount, 0, hostSkill.level);
          player.skills.increase(hostSkill.id, val - skill.level);
        }
    }


// move player by dx, dy
// returns true on success
  public function moveBy(dx: Int, dy: Int): Bool
    {
      // if player tries to move when attached, that detaches the parasite
      if (state == PLR_STATE_ATTACHED)
        detachAction();

      var nx = x + dx;
      var ny = y + dy;

      // random: change movement direction
      if (state == PLR_STATE_HOST && player.hostControl < 90 &&
          Std.random(100) < 0.75 * (100 - player.hostControl))
        {
          log('The host resists your command.');
          var dir = game.area.getRandomDirection(x, y);
          if (dir == -1)
            throw 'nowhere to move!';
          nx = x + Const.dirx[dir];
          ny = y + Const.diry[dir];
        }

      // frob objects on this position
      var objs = game.area.getObjectsAt(nx, ny);
      for (o in objs)
        {
          // 0 - return false
          // 1 - ok, continue
          var ret = o.frob(true, player.host);
          if (ret == 0)
            return false;
          else if (ret == 1)
            1;
        }

      // frob the AI
      var ai = game.area.getAI(nx, ny);
      if (ai != null)
        {
          var ret = frobAIAction(ai);
          if (!ret)
            return false;
          postAction(); // post-action call
          // update AI visibility to player
          game.area.updateVisibility();
          return true;
        }

      moveTo(nx, ny, true);

      return true;
    }


// move player to x, y
// returns true on success
  public function moveTo(nx: Int, ny: Int, ?doPost: Bool = false): Bool
    {
      if (!game.area.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      // move invaded host entity with invisible player entity
      if (state == PLR_STATE_HOST)
        player.host.setPosition(x, y);

      entity.setPosition(x, y); // move player entity (even if invisible)

      if (doPost)
        postAction(); // post-action call

      // describe objects on the ground
      var s = new StringBuf();
      var cnt = 0;
      var objs = game.area.getObjectsAt(x, y);
      for (o in objs)
        {
          if (!o.visible())
            continue;
          cnt++;
          s.add(o.getName());
          if (cnt < objs.length)
            s.add(', ');
        }
      if (s.length == 0)
        return true;

      log('You can see ' +
        (cnt > 1 ? 'the following objects ' : 'an object ') + 'here: ' +
        s.toString() + '.');

      // run trigger on move to
      for (o in objs)
        o.onMoveTo();

      return true;
    }


// does the player hear something in this location?
// technically we should separate parasite/host hearing radius
// but nobody will probably notice the difference :)
  public inline function hears(xx: Int, yy: Int): Bool
    {
      return (distanceSquared(xx, yy) <
        player.vars.listenRadius * player.vars.listenRadius);
    }

// does player sees this spot
  public function sees(xx: Int, yy: Int): Bool
    {
      // host vision
      if (player.state == PLR_STATE_HOST)
        return game.area.isVisible(x, y, xx, yy);
      else
        {
          // parasite vision
          if (Math.abs(x - xx) < 2 && Math.abs(y - yy) < 2)
            return true;
        }
      return false;
    }

// distance from player to point
  public inline function distanceSquared(xx: Int, yy: Int): Int
    {
      return Const.distanceSquared(x, y, xx, yy);
    }

// distance from player to point
  public inline function distance(xx: Int, yy: Int): Int
    {
      return Const.distance(x, y, xx, yy);
    }

// set action to repeat continuously
  public function setAction(a: _PlayerAction)
    {
      currentAction = a;
      game.ui.hud.showOverlay();
      
      // start doing it
      nextAction();
    }

// create a path to given x,y and start moving on it
  public function setPath(destx: Int, desty: Int)
    {
      path = game.area.getPath(x, y, destx, desty);
      if (path == null)
        return;
      game.ui.hud.showOverlay();
      // start moving
      nextPath();
    }

// repeat action
// returns true on success
  public function nextAction(): Bool
    {
      // path clear
      if (currentAction == null ||
          (haxe.Timer.stamp() - actionTS) * 1000.0 <
          game.config.repeatDelay)
        return false;

      actionTS = haxe.Timer.stamp();
      var prevState = player.state;
      action(currentAction);
      var stop = false;
      // player changed state
      if (player.state != prevState)
        stop = true;
      // probe brain stops when its color changes
      else if (currentAction.id == 'probeBrain')
        {
          var actionName = getProbeBrainActionName();
          if (actionName.indexOf('white') > 0)
            stop = true;
        }
      else
        {
          // stop when the player state changes or not enough energy
          var energy = (currentAction.energyFunc != null ?
            currentAction.energyFunc(player) : currentAction.energy);
          if (player.energy < energy)
            stop = true;
          // grip fully hardened
          else if (currentAction.id == 'hardenGrip')
            {
              if (attachHold >= 100)
                stop = true;
            }
          // fully in control
          else if (currentAction.id == 'reinforceControl')
            {
              if (player.hostControl >= 90)
                stop = true;
            }
        }
      if (stop)
        {
          currentAction = null;
          game.ui.hud.hideOverlay();
          return true;
        }
      return true;
    }

// move to next path waypoint
// returns true on success
  public function nextPath(): Bool
    {
      // path clear
      if (path == null ||
          (haxe.Timer.stamp() - actionTS) * 1000.0 < game.config.repeatDelay)
        return false;

      var n = path.shift();
      actionTS = haxe.Timer.stamp();
      var ret = moveAction(n.x - x, n.y - y);
      if (!ret)
        {
          path = null;
          game.ui.hud.hideOverlay();
          return true;
        }

      if (path != null && path.length == 0)
        {
          game.ui.hud.hideOverlay();
          path = null;
        }

      return true;
    }


// clear path
  public inline function clearPath()
    {
      path = null;
    }

// ================================ EVENTS =========================================


// event: on taking damage
  public function onDamage(damage: Int)
    {
      if (player.vars.godmodeEnabled)
        return;

      if (state == PLR_STATE_HOST)
        onDamageHost(damage);

      else onDamagePlayer(damage);
    }


// helper: on taking host damage
  function onDamageHost(damage: Int)
    {
      // stop moving
      game.scene.clearPath();

      player.host.onDamage(damage);
      if (player.host.state == AI_STATE_DEAD)
        {
          onDetach();

          log('Your host has died from injuries.');

          return;
        }

      // 10% chance of parasite receiving part of damage
      var damage = __Math.damage({
        name: 'transmit to parasite',
        chance: 10,
        val: (damage == 1 ? 1 : 2),
      });
    }


// helper: on taking player damage
  function onDamagePlayer(damage: Int)
    {
      // not attached to host
      player.health -= damage;

      if (player.health <= 0)
        game.finish('lose', 'noHealth');
    }


// event: parasite detached from AI
  public function onDetach()
    {
      // set state
      state = PLR_STATE_PARASITE;

      // make player entity visible again
      entity.visible = true;

      attachHost = null;
      player.host = null;

      game.scene.sounds.play('parasite-detach');
    }


// event: host expired
  public inline function onHostDeath()
    {
      // close open windows
      if (game.ui.state != UISTATE_MESSAGE)
        game.ui.state = UISTATE_DEFAULT;

      player.host.die();
      onDetach();
    }


// debug: learn about object
  public inline function debugLearnObject(t: String )
    {
      knownObjects.add(t);
    }


// =================================================================================


// log
  public inline function log(s: String, ?col: _TextColor)
    {
      game.log(s, col);
    }


// =================================  SETTERS  ====================================

  function get_state()
    { return player.state; }

  function set_state(v: _PlayerState)
    { return player.state = v; }

  function set_attachHold(v: Int)
    { return attachHold = Const.clamp(v, 0, 100); }


// =================================================================================
}

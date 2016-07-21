// state (area mode)

package game;

import com.haxepunk.HXP;

import ai.AI;
import entities.PlayerEntity;
import objects.AreaObject;
import const.*;

class PlayerArea
{
  var game: Game; // game state link
  var player: Player; // state link

  public var entity: PlayerEntity; // player ui entity
  public var x: Int; // x,y on grid
  public var y: Int;
  public var ap: Int; // player action points (2 per turn)
  var knownObjects: List<String>; // list of known area object types
  var state(get, set): _PlayerState; // state link

  // state "parasite"

  // state "attach"
  public var attachHost: AI; // potential host
  public var attachHold(default, set): Int; // hold strength


  public function new(g: Game)
    {
      game = g;
      player = game.player;

      x = 0;
      y = 0;
      ap = 2;
      attachHold = 0;
      knownObjects = new List<String>();
      knownObjects.add('body');
      knownObjects.add('pickup');

      entity = new PlayerEntity(game, x, y);
      game.scene.add(entity);
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
          else player.hostControl--;

          if (player.hostControl <= 0)
            {
              player.host.onDetach();
              onDetach();

              game.log("You've lost control of the host.");
            }
        }

      ap = 2;
    }

/*
// does player know about this object?
  public inline function knowsObject(id: String): Bool
    {
      return (Lambda.has(knownObjects, id));
    }
*/

// ==============================   ACTIONS   =======================================


// helper: add action to list and check for energy
  inline function addActionToList(list: List<_PlayerAction>, id: String, ?o: Dynamic)
    {
      var action = Const.getAction(id);
      if (action.energy <= player.energy)
        {
          if (o != null)
            {
              var a = Reflect.copy(action);
              a.obj = o;
              list.add(a);
            }
          else list.add(action);
        }
    }


// get actions list (area mode)
  public function getActionList(): List<_PlayerAction>
    {
      var tmp = new List<_PlayerAction>();

      if (state == PLR_STATE_PARASITE)
        {
          if (game.area.hasAI(x, y))
            addActionToList(tmp, 'attachHost');
        }

      // parasite is attached to host
      else if (state == PLR_STATE_ATTACHED)
        {
          addActionToList(tmp, 'hardenGrip');
          if (attachHold >= 90)
            addActionToList(tmp, 'invadeHost');
        }

      // parasite in control of host
      else if (state == PLR_STATE_HOST)
        {
          if (player.hostControl < 100)
            addActionToList(tmp, 'reinforceControl');
//          if (player.evolutionManager.getLevel(IMP_BRAIN_PROBE) > 0)
//            addActionToList(tmp, 'probeBrain');

          // organ-based actions
          player.host.organs.addActions(tmp);

          addActionToList(tmp, 'leaveHost');
        }

      // improvement actions
      for (imp in player.evolutionManager)
        {
          var info = imp.info;
          if (info.action != null)
            {
              if (info.action.energy != null && info.action.energy <= player.energy)
                tmp.add(info.action);

              else if (info.action.energyFunc != null)
                {
                  var e = info.action.energyFunc(player);
                  if (e >= 0 && e <= player.energy)
                    tmp.add(info.action);
                }
            }
        }

      // area object actions
      var olist = game.area.getObjectsAt(x, y);
      if (olist == null)
        return tmp;

      // need to learn about objects
      if (game.goals.completed(GOAL_PROBE_BRAIN))
        for (o in olist)
          {
            // player does not know what this object is, cannot activate it
            if (state == PLR_STATE_HOST && !Lambda.has(knownObjects, o.type) &&
                player.host.isHuman && o.type != 'event_object')
              addActionToList(tmp, 'learnObject', o);

            // object known - add all actions defined by object
            else if (Lambda.has(knownObjects, o.type))
              o.addActions(tmp);
          }

      // event objects always known
      for (o in olist)
        if (o.type == 'event_object')
          o.addActions(tmp);

      // leave area action
      if (state != PLR_STATE_ATTACHED && !game.area.info.isInhabited)
        addActionToList(tmp, 'leaveArea');

      return tmp;
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(action: _PlayerAction)
    {
      // area object action
      if (action.type == ACTION_OBJECT)
        {
          // cannot act while in paralysis
          if (state == PLR_STATE_HOST && player.host.effects.has(EFFECT_PARALYSIS))
            {
              log('Your host is paralyzed.', COLOR_HINT);
              return;
            }

          var ao: AreaObject = action.obj;
          ao.action(action);
        }

      // host organ-based action
      if (action.type == ACTION_ORGAN)
        player.host.organs.areaAction(action);

      // harden grip on the victim
      else if (action.id == 'hardenGrip')
        hardenGripAction();

      // attach host
      else if (action.id == 'attachHost')
        {
          var ai = game.area.getAI(x, y);
          attachToHostAction(ai);

          game.updateHUD();
        }

      // invade host
      else if (action.id == 'invadeHost')
        invadeHostAction();

      // try to reinforce control over host
      else if (action.id == 'reinforceControl')
        reinforceControlAction();

      // try to leave current host
      else if (action.id == 'leaveHost')
        leaveHostAction();

      // probe host brain
      else if (action.id == 'probeBrain')
        probeBrainAction();

      // learn about object
      else if (action.id == 'learnObject')
        learnObjectAction(action.obj);

      // try to leave area
      else if (action.id == 'leaveArea')
        leaveAreaAction();

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

      // update HUD info
      game.updateHUD();
    }


// post-action call: remove AP and new turn
  public function postAction()
    {
      // host death
      if (state == PLR_STATE_HOST &&
          (player.host.state == AI_STATE_DEAD || player.host.energy <= 0))
        {
          onHostDeath();

          log('Your host has expired. You have to find a new one.');
          game.scene.setState(HUDSTATE_DEFAULT); // close window if it's open
        }

      // parasite could also be dead
      if (state == PLR_STATE_PARASITE && player.energy <= 0)
        {
          game.finish('lose', 'noHost');
          return;
        }

      // remove 1 AP
      ap--;
      if (ap > 0)
        return;

      // new turn (only if still in area mode)
      if (game.location == LOCATION_AREA)
        game.turn();
    }


// action: move player by dx,dy
  public function moveAction(dx: Int, dy: Int)
    {
      // cannot move while in paralysis
      if (state == PLR_STATE_HOST && player.host.effects.has(EFFECT_PARALYSIS))
        {
          log('Your host is paralyzed.', COLOR_HINT);
          return;
        }

      // frob the AI
      var ai = game.area.getAI(x + dx, y + dy);
      if (ai != null)
        {
          frobAIAction(ai);
          return;
        }

      // try to move to the new location
      moveBy(dx, dy);
    }


// frob the AI - atm just attach to host as a parasite
  function frobAIAction(ai: AI)
    {
      // attach to new host
      if (state == PLR_STATE_PARASITE)
        {
          attachToHostAction(ai);

          // update HUD info
          game.updateHUD();
        }

      // push past AI
      else if (state == PLR_STATE_HOST)
        {
          // opposing strength check
          if (!_Math.opposingAttr(player.host.strength, ai.strength, 'strength'))
            {
              log('Your host does not manage to push past ' + ai.getName() + '.');
              return;
            }

          var newx = ai.x, newy = ai.y;

          ai.setPosition(x, y, true);

          moveTo(newx, newy);

          game.area.updateVisibility();

          log('Your host pushes past ' + ai.getName() + '.');

          // update HUD info
          game.updateHUD();
        }
    }


// debug action: attach and invade
  public function debugAttachAndInvadeAction(ai: AI)
    {
      attachToHostAction(ai);
      attachHold = 100;
      invadeHostAction();
    }


// action: attack this ai
  public function attackAction(ai: AI)
    {
      // not in a host mode
      if (state != PLR_STATE_HOST)
        return;

      // check if player can see that spot
      if (!game.area.isVisible(x, y, ai.x, ai.y))
        return;

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

      // use fists
      if (item == null)
        info = ItemsConst.fists;
      else info = item.info;

      // check for distance on melee
      if (!info.weapon.isRanged && !ai.isNear(x, y))
        return;

      // propagate shooting/melee event
      game.managerArea.onAttack(x, y, info.weapon.isRanged);

      // weapon skill level (ai + parasite bonus)
      var skillLevel = player.host.skills.getLevel(info.weapon.skill) +
        0.5 * player.skills.getLevel(info.weapon.skill);

      ai.onAttack(); // attack event

      // roll skill
      if (Std.random(100) > skillLevel)
        {
          log('Your host tries to ' + info.weapon.verb1 + ' ' +
            ai.getName() + ', but misses.');

          // set alerted state
          if (ai.state == AI_STATE_IDLE)
            ai.setState(AI_STATE_ALERT, REASON_DAMAGE);

          postAction(); // post-action call
          game.updateHUD(); // update HUD info

          return;
        }

      // success, roll damage
      var damage = Const.roll(info.weapon.minDamage, info.weapon.maxDamage);
      if (!info.weapon.isRanged) // all melee weapons have damage bonus
        damage += Const.roll(0, Std.int(player.host.strength / 2));

      log('Your host ' + info.weapon.verb2 + ' ' + ai.getName() +
        ' for ' + damage + ' damage.');

      ai.onDamage(damage); // damage event
      postAction(); // post-action call
      game.updateHUD(); // update HUD info
    }


// action: attach to host
  function attachToHostAction(ai: AI)
    {
      // move to the same spot as AI
      moveTo(ai.x, ai.y);

      // set starting attach parameters
      state = PLR_STATE_ATTACHED;
      attachHost = ai;

      // improv: attach efficiency
      var params = player.evolutionManager.getParams(IMP_ATTACH);
      attachHold = params.attachHoldBase;

      game.log('You have managed to attach to a host.');

      ai.onAttach(); // callback to AI
    }


// action: harden grip when attached to host
  function hardenGripAction()
    {
      game.log('You harden your grip on the host.');

      // improv: harden grip bonus
      var params = player.evolutionManager.getParams(IMP_HARDEN_GRIP);

      var tmp = params.attachHoldBase;

      // effect: paralysis
      if (!attachHost.effects.has(EFFECT_PARALYSIS))
        tmp -= Std.int(attachHost.strength / 2);

      attachHold += tmp;
    }


// action: try to invade this AI host
  function invadeHostAction()
    {
//      game.log('You attempt to invade the host.');
//      if (Std.random(100) < )
      game.log('Your proboscis penetrates the warm flesh. You are now in control of the host.');

      // save AI link
      player.host = attachHost;
      player.hostControl = Player.HOST_CONTROL_BASE;
      entity.visible = false;
      attachHost = null;
      player.host.onInvade(); // notify ai

      // set state
      state = PLR_STATE_HOST;

      // update AI visibility to player
      game.area.updateVisibility();

      // goal completed: host invaded
      game.goals.complete(GOAL_INVADE_HOST);

      // goal completed: human host invaded
      if (player.host.isHuman)
        game.goals.complete(GOAL_INVADE_HUMAN);
    }


// action: try to reinforce control over host
  function reinforceControlAction()
    {
      game.log('You reinforce mental control over the host.');

      // improv: control efficiency
      var params = player.evolutionManager.getParams(IMP_REINFORCE);
      player.hostControl += params.reinforceControlBase -
        Std.int(player.host.psyche / 2);
    }


// action: try to leave this AI host
  function leaveHostAction()
    {
      game.log('You release the host.');
      player.host.onDetach();
      onDetach();
    }


// action: leave area
  function leaveAreaAction()
    {
      // special check for habitat
      if (game.area.typeID == AREA_HABITAT && game.area.hasAnyAI())
        {
          game.log('You cannot leave the habitat with outsiders in it!');
          return;
        }

      game.log("You leave the area.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
    }


// action: remove attached parasite from host
  function detachAction()
    {
      attachHost.parasiteAttached = false;
      onDetach();

      game.log('You detach from the potential host.');
    }


// action: probe host brain
  function probeBrainAction()
    {
      // animals do not have any useful memories
      if (!player.host.isHuman)
        {
          game.log('This host is not intelligent enough.');
          return;
        }

      game.log('You probe the brain of the host and learn its contents. The host grows weaker.');

      // skills and knowledge
//      var info = EvolutionConst.getInfo(IMP_BRAIN_PROBE);
      var params = player.evolutionManager.getParams(IMP_BRAIN_PROBE);
      if (game.player.vars.skillsEnabled)
        {
          // can access skills from level 2
          if (params.hostSkillsMod > 0)
            accessSkillsAction(params.hostSkillsMod);

          // can access attributes on level 3
          if (params.hostAttrsMod > 0 && !player.host.isAttrsKnown)
            {
              player.host.isAttrsKnown = true;
              game.log('You have learned the parameters of this host.');
            }

          // human society knowledge
          player.skills.increase(KNOW_SOCIETY,
            params.humanSociety * player.host.intellect);
        }

      // spend energy
//      player.host.energy -= params.hostEnergyBase - player.host.psyche;
//      player.host.energy -= info.action.energyFunc(player);
      player.host.onDamage(params.hostHealthBase); // damage host
      if (Std.random(100) < 25)
        player.host.onDamage(params.hostHealthMod); // more damage if unlucky

      // get host name
      if (!player.host.isNameKnown)
        {
          player.host.isNameKnown = true;
          game.log('You find out that the name of this host is ' +
            player.host.getName() + '.');
        }

      // on first brain probe learn about items and area objects
      game.goals.complete(GOAL_PROBE_BRAIN);

      // get clues
      if (player.host.event != null && player.host.brainProbed < 3)
        {
          var chance = 100;
          if (player.host.brainProbed == 1)
            chance = 30;
          else if (player.host.brainProbed == 2)
            chance = 10;

          var ret = false;
          if (Std.random(100) < chance)
            ret = game.timeline.learnClue(player.host.event, true);

          // no clues learned
          if (!ret)
            game.player.log('You have not been able to gain any clues.',
              COLOR_TIMELINE);
        }

      // mark npc as scanned
      if (player.host.event != null && player.host.brainProbed >= 2)
        player.host.npc.memoryKnown = true;

      player.host.brainProbed++; // increase counter
    }


// action: learn about area object
  function learnObjectAction(o: AreaObject)
    {
      game.log('You probe the brain of the host and learn what that object is for.');

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
          game.log('You have learned the basics of ' + hostSkill.info.name + ' skill.');
          player.skills.addID(hostSkill.id, amount);
        }
      else if (!hostSkill.info.isBool)
        {
          game.log('You have increased your knowledge of ' + hostSkill.info.name +
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

      // cell not walkable
      if (!game.area.isWalkable(nx, ny))
        return false;

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

      x = nx;
      y = ny;

      // move invaded host entity with invisible player entity
      if (state == PLR_STATE_HOST)
        player.host.setPosition(x, y);

      entity.setPosition(x, y); // move player entity (even if invisible)

      postAction(); // post-action call

      // update HUD info
      game.updateHUD();

      // update AI visibility to player
      game.area.updateVisibility();

      return true;
    }


// move player to x, y
// returns true on success
  public function moveTo(nx: Int, ny: Int): Bool
    {
      if (!game.area.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      // move invaded host entity with invisible player entity
      if (state == PLR_STATE_HOST)
        player.host.setPosition(x, y);

      entity.setPosition(x, y);

      // update cell visibility to player
      game.area.updateVisibility();

      return true;
    }


// does the player hear something in this location?
// technically we should separate parasite/host hearing radius
// but nobody will probably notice the difference :)
  public inline function hears(xx: Int, yy: Int): Bool
    {
      return (HXP.distanceSquared(x, y, xx, yy) <
        player.vars.listenRadius * player.vars.listenRadius);
    }


// ================================ EVENTS =========================================


// event: on taking damage
  public function onDamage(damage: Int)
    {
      if (state == PLR_STATE_HOST)
        onDamageHost(damage);

      else onDamagePlayer(damage);
    }


// helper: on taking host damage
  function onDamageHost(damage: Int)
    {
      player.host.onDamage(damage);
      if (player.host.state == AI_STATE_DEAD)
        {
          onDetach();

          log('Your host has died from injuries.');
          return;
        }

      // 10% chance of parasite receiving part of damage
      if (Std.random(100) < 10)
        onDamagePlayer(damage == 1 ? 1 : 2);
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
    }


// event: host expired
  public inline function onHostDeath()
    {
      // close open windows
      game.scene.setState(HUDSTATE_DEFAULT);

      player.host.onDeath();
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

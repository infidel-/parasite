// state (area mode)

import com.haxepunk.HXP;

import ai.AI;
import entities.PlayerEntity;
import objects.AreaObject;

class PlayerArea
{
  var game: Game; // game state link
  var area: Area; // area link
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


  public function new(g: Game, a: Area)
    {
      game = g;
      player = game.player;
      area = a;

      x = 0;
      y = 0;
      ap = 2;
      attachHold = 0;
      knownObjects = new List<String>();
      knownObjects.add('body');
    }


// create player entity
  public inline function createEntity(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
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
          player.hostControl--;
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

      // parasite is attached to host
      if (state == PLR_STATE_ATTACHED)
        {
          addActionToList(tmp, 'hardenGrip');
          if (attachHold >= 90)
            addActionToList(tmp, 'invadeHost');
        }

      // parasite in control of host
      else if (state == PLR_STATE_HOST)
        {
          addActionToList(tmp, 'reinforceControl');
          if (player.evolutionManager.getLevel(IMP_BRAIN_PROBE) > 0)
            addActionToList(tmp, 'probeBrain');

          // organ-based actions
          player.host.organs.addActions(tmp);

          addActionToList(tmp, 'leaveHost');
        }

      // area object actions
      var olist = area.getObjectsAt(x, y);
      if (olist == null)
        return tmp;

      // need to learn about objects
      if (player.goals.completed(GOAL_PROBE_BRAIN))
        for (o in olist)
          {
            // player does not know what this object is, cannot activate it
            if (state == PLR_STATE_HOST && !Lambda.has(knownObjects, o.type) &&
                player.host.isHuman)
              addActionToList(tmp, 'learnObject', o);

            // object known - add all actions defined by object
            else if (Lambda.has(knownObjects, o.type)) 
              o.addActions(tmp);
          }

      // leave area action
      if (state != PLR_STATE_ATTACHED && !area.getArea().info.isInhabited)
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
      if (state == PLR_STATE_HOST)
        player.host.energy -= action.energy;
      else player.energy -= action.energy;

      postAction(); // post-action call

      // update HUD info
      game.updateHUD();
    }


// post-action call: remove AP and new turn
  public function postAction()
    {
      // host could be dead
      if (state == PLR_STATE_HOST && player.host.state == AI_STATE_DEAD)
        {
          onHostDeath();

          log('Your host has died.');
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
      if (game.location == Game.LOCATION_AREA)
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
      var ai = area.getAI(x + dx, y + dy);
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
      if (!area.isVisible(x, y, ai.x, ai.y))
        return;

      // get current weapon
      var item = null;
      var info = null;

      // for now, just get first weapon player knows how to use
      for (ii in player.host.inventory)
        if (ii.info.weaponStats != null && player.knowsItem(ii.id))
          {
            item = ii;
            break;
          }

      // use fists
      if (item == null)
        info = ConstItems.fists;
      else info = item.info;

      // check for distance on melee
      if (!info.weaponStats.isRanged && !ai.isNear(x, y))
        return;

      // propagate shooting/melee event
      game.area.manager.onAttack(x, y, info.weaponStats.isRanged);

      // weapon skill level (ai + parasite bonus)
      var skillLevel = player.host.skills.getLevel(info.weaponStats.skill) +
        0.5 * player.skills.getLevel(info.weaponStats.skill);

      ai.onAttack(); // attack event

      // roll skill
      if (Std.random(100) > skillLevel)
        {
          log('Your host tries to ' + info.verb1 + ' ' + ai.getName() + ', but misses.');

          // set alerted state
          if (ai.state == AI_STATE_IDLE)
            ai.setState(AI_STATE_ALERT, REASON_DAMAGE);

          postAction(); // post-action call
          game.updateHUD(); // update HUD info

          return;
        }

      // success, roll damage
      var damage = Const.roll(info.weaponStats.minDamage, info.weaponStats.maxDamage);
      if (!info.weaponStats.isRanged) // all melee weapons have damage bonus
        damage += Const.roll(0, Std.int(player.host.strength / 2));

      log('Your host ' + info.verb2 + ' ' + ai.getName() + ' for ' + damage + ' damage.');

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
      area.updateVisibility();

      // goal completed: host invaded 
      player.goals.complete(GOAL_INVADE_HOST);

      // goal completed: human host invaded 
      if (player.host.isHuman)
        player.goals.complete(GOAL_INVADE_HUMAN);
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
      player.host.onDetach();
      onDetach();

      game.log('You release the host.');
    }


// action: leave area
  function leaveAreaAction()
    {
      game.log("You leave the area."); 
      game.turns++; // manually increase number of turns
      game.setLocation(Game.LOCATION_REGION);
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
      var params = player.evolutionManager.getParams(IMP_BRAIN_PROBE);
      if (game.player.vars.skillsEnabled)
        {
          // can access skills from level 2
          if (params.hostSkillsMod > 0)
            accessSkillsAction(params.hostSkillsMod);

          // human society knowledge
          player.skills.increase(KNOW_SOCIETY,
            params.humanSociety * player.host.intellect);
        }

      // spend energy
      player.host.energy -= params.hostEnergyBase - player.host.psyche; 
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
      player.goals.complete(GOAL_PROBE_BRAIN);

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
      var hostSkill = player.host.skills.getRandomSkill();
      if (hostSkill == null)
        return;

      // player already knows this skill better than the host
      var skill = player.skills.get(hostSkill.id);
      if (skill != null && skill.level >= hostSkill.level)
        return;

      // goal completion
      player.goals.complete(GOAL_LEARN_SKILLS);

      var amount = Std.int((player.host.intellect / 10.0) *
        hostSkillsMod * hostSkill.level);

      if (skill == null)
        {
          player.skills.addID(hostSkill.id, amount);
          game.log('You have learned the basics of ' + hostSkill.info.name + ' skill.');
        }
      else
        {
          game.log('You have increased your knowledge of ' + hostSkill.info.name +
            ' skill.');
          skill.level = Const.clampFloat(skill.level + amount, 0, hostSkill.level);
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
      if (!area.isWalkable(nx, ny))
        return false;

      // random: change movement direction
      if (state == PLR_STATE_HOST && 
          Std.random(100) < 0.9 * (100 - player.hostControl))
        {
          log('The host resists your command.');
          var dir = area.getRandomDirection(x, y);
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
      area.updateVisibility();

      return true;
    }


// move player to x, y
// returns true on success
  public function moveTo(nx: Int, ny: Int): Bool
    {
      if (!area.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      entity.setPosition(x, y);

      // update cell visibility to player
      area.updateVisibility();

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

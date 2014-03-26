// player state (area mode)

import com.haxepunk.HXP;

import entities.PlayerEntity;
import ai.AI;

class PlayerArea
{
  var game: Game; // game state link
  var area: Area; // area link
  var player: Player; // player state link

  public var entity: PlayerEntity; // player ui entity
  public var x: Int; // x,y on grid
  public var y: Int;
  public var ap: Int; // player action points (2 per turn)

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
      if (player.state == Player.STATE_HOST)
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


// ==============================   ACTIONS   =======================================


// helper: add action to list and check for energy
  inline function addActionToList(list: List<String>, name: String)
    {
      var action = Const.getAction(name);
      if (action.energy <= player.energy)
        list.add(name);
    }


// get actions list (area mode)
  public function getActionList(): List<String>
    {
      var tmp = new List<String>();

      // parasite is attached to host
      if (player.state == Player.STATE_ATTACHED)
        {
          addActionToList(tmp, 'hardenGrip');
          if (attachHold >= 90)
            addActionToList(tmp, 'invadeHost');
        }

      // parasite in control of host
      else if (player.state == Player.STATE_HOST)
        {
          addActionToList(tmp, 'reinforceControl');
          if (player.evolutionManager.getLevel('hostMemory') > 0)
            addActionToList(tmp, 'accessMemory');
          addActionToList(tmp, 'leaveHost');
        }

      // area object actions
      var o = area.getObjectAt(x, y);
      if (o == null)
        return tmp;

      // TODO: add this to appropriate object class
      if (player.state != Player.STATE_ATTACHED && o.type == 'sewer_hatch')
        addActionToList(tmp, 'enterSewers');
      
      return tmp;
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(actionName: String)
    {
      var action = Const.getAction(actionName);

      // harden grip on the victim
      if (actionName == 'hardenGrip')
        actionHardenGrip();

      // invade host 
      else if (actionName == 'invadeHost')
        actionInvadeHost();

      // try to reinforce control over host 
      else if (actionName == 'reinforceControl')
        actionReinforceControl();

      // try to leave current host
      else if (actionName == 'leaveHost')
        actionLeaveHost();

      // access host memory
      else if (actionName == 'accessMemory')
        actionAccessMemory();

      // activate object (will make it a common action)
      else if (actionName == 'enterSewers')
        actionActivateObject();

      player.energy -= action.energy;

      // host could be dead
      if (player.state == Player.STATE_HOST && player.host.state == AI.STATE_DEAD)
        {
          onHostDeath();

          log('Your host has died.');
        }

      // parasite could also be dead
      if (player.state == Player.STATE_PARASITE && player.energy <= 0)
        {
          game.finish('lose', 'noHost');
          return;
        }

      postAction(); // post-action call

      // update HUD info
      game.updateHUD();
    }


// post-action call: remove AP and new turn
  function postAction()
    {
      // remove 1 AP
      ap--;
      if (ap > 0)
        return;

      // new turn (only if still in area mode)
      if (game.location == Game.LOCATION_AREA)
        game.turn();
    }


// action: move player by dx,dy
  public function actionMove(dx: Int, dy: Int)
    {
      // frob the AI
      var ai = area.getAI(x + dx, y + dy);
      if (ai != null)
        {
          actionFrobAI(ai);
          return;
        }

      // try to move to the new location
      moveBy(dx, dy);
    }


// frob the AI - atm just attach to host as a parasite
  function actionFrobAI(ai: AI)
    {
      // attach to new host
      if (player.state == Player.STATE_PARASITE)
        {
          actionAttachToHost(ai);

          // update HUD info
          game.updateHUD();
        }
    }


// debug action: attach and invade
  public function actionDebugAttachAndInvade(ai: AI)
    {
      actionAttachToHost(ai);
      attachHold = 100;
      actionInvadeHost();
    }


// action: activate object 
  public function actionActivateObject()
    {
      var o = area.getObjectAt(x, y);
      o.onActivate();
    }


// action: attack this ai
  public function actionAttack(ai: AI)
    {
      // not in a host mode
      if (player.state != Player.STATE_HOST)
        return;

      // check if player can see that spot
      if (!area.isVisible(x, y, ai.x, ai.y))
        return;

      // get current weapon
      var item = player.host.inventory.getFirstWeapon();
      var info = null;

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
          if (ai.state == AI.STATE_IDLE)
            ai.setState(AI.STATE_ALERT, AI.REASON_DAMAGE);

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
  function actionAttachToHost(ai: AI)
    {
      // move to the same spot as AI
      moveTo(ai.x, ai.y);

      // set starting attach parameters
      player.state = Player.STATE_ATTACHED;
      attachHost = ai;
      attachHold = ATTACH_HOLD_BASE;

      game.log('You have managed to attach to a host.');

      ai.onAttach(); // callback to AI
    }


// action: harden grip when attached to host
  function actionHardenGrip()
    {
      game.log('You harden your grip on the host.');
      attachHold += 15;
    }


// action: try to invade this AI host
  function actionInvadeHost()
    {
//      game.log('You attempt to invade the host.');
//      if (Std.random(100) < )
      game.log('You are now in control of the host.');

      // save AI link
      player.host = attachHost;
      player.hostControl = Player.HOST_CONTROL_BASE;
      entity.visible = false;
      attachHost = null;
      player.host.onInvade(); // notify ai

      // set state
      player.state = Player.STATE_HOST;

      // update AI visibility to player
      area.updateVisibility();
    }


// action: try to reinforce control over host
  function actionReinforceControl()
    {
      game.log('You reinforce mental control over the host.');
      player.hostControl += 10 - Std.int(player.host.psyche / 2);
    }


// action: try to leave this AI host
  function actionLeaveHost()
    {
      player.host.onDetach();
      onDetach();

      game.log('You release the host.');
    }


// action: remove attached parasite from host
  function actionDetach()
    {
      attachHost.parasiteAttached = false;
      onDetach();

      game.log('You detach from the potential host.');
    }


// action: access host memory
  function actionAccessMemory()
    {
      // animals do not have any useful memories
      if (!player.host.isHuman)
        {
          game.log('The brain of this host contains nothing useful.');
          return;
        }
     
      game.log('You probe the brain of the host and access its memory.');

      var params = player.evolutionManager.getParams('hostMemory');
      player.humanSociety += params.humanSociety * player.host.intellect;

      // can access skills from level 2
      if (params.hostSkillsMod > 0)
        actionAccessSkills(params.hostSkillsMod);

      // spend energy
      player.host.energy -= params.hostEnergyBase - player.host.psyche; 
      player.host.onDamage(params.hostHealthBase); // damage host
      if (Std.random(100) < 25)
        player.host.onDamage(params.hostHealthMod); // more damage if unlucky

      if (!player.host.isNameKnown)
        {
          player.host.isNameKnown = true;
          game.log('You find out that the name of this host is ' + 
            player.host.getName() + '.');
        }
    }


//  action: access host skills
  function actionAccessSkills(hostSkillsMod: Float)
    {
      var hostSkill = player.host.skills.getRandomSkill();
      if (hostSkill == null)
        return;

      // player already knows this skill better than the host
      var skill = player.skills.get(hostSkill.id);
      if (skill != null && skill.level >= hostSkill.level)
        return;

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
          skill.level = Const.clamp(skill.level + amount, 0, hostSkill.level);
        }
    }


// move player by dx, dy
// returns true on success
  public function moveBy(dx: Int, dy: Int): Bool
    {
      // if player tries to move when attached, that detaches the parasite
      if (player.state == Player.STATE_ATTACHED)
        actionDetach();

      var nx = x + dx;
      var ny = y + dy;

      // cell not walkable
      if (!area.isWalkable(nx, ny))
        return false;

      // random: change movement direction
      if (player.state == Player.STATE_HOST && 
          Std.random(100) < 100 - player.hostControl)
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
      if (player.state == Player.STATE_HOST) 
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
      if (player.state == Player.STATE_HOST)
        {
          player.host.onDamage(damage);
          if (player.host.state == AI.STATE_DEAD)
            {
              onDetach();
              
              log('Your host has died from injuries.');
            }

          return;
        }

      // not attached to host
      player.health -= damage;

      if (player.health <= 0)
        {
          game.finish('lose', 'noHealth');
          return;
        }
    }


// event: parasite detached from AI 
  public function onDetach()
    {
      // set state 
      player.state = Player.STATE_PARASITE;

      // make player entity visible again
      entity.visible = true;

      attachHost = null;
      player.host = null;
    }


// event: host expired
  public inline function onHostDeath()
    {
      player.host.onDeath();
      onDetach();
    }


// =================================================================================


// log
  public inline function log(s: String, ?col: Int = 0)
    {
      game.log(s, col);
    }


// =================================  SETTERS  ====================================

  function set_attachHold(v: Int)
    { return attachHold = Const.clamp(v, 0, 100); }


// =================================================================================

  // base hold on attach to host
  public static var ATTACH_HOLD_BASE = 10;
}

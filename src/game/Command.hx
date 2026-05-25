// command menu helper
package game;

import ai.AI;
import ui.HUD;

class Command
{
  var player: Player;
  var game: Game;
  var hud: HUD;
  var hasAttackAction: Bool;

// create command menu handler
  public function new(p: Player, g: Game, h: HUD)
    {
      player = p;
      game = g;
      hud = h;
      hasAttackAction = false;
    }

// check if player has cult followers in area
  public function hasFollowers(): Bool
    {
      if (game.location != LOCATION_AREA ||
          game.area == null)
        return false;

      for (ai in game.area.getAllAI())
        {
          if (!ai.isPlayerCultist() ||
              ai.state == AI_STATE_DEAD ||
              ai == player.host)
            continue;
          return true;
        }
      return false;
    }

// enter command menu state
  public function enter(): Bool
    {
      if (hud.state != HUD_DEFAULT)
        return false;
      if (!hasFollowers())
        return false;
      hud.state = HUD_COMMAND_MENU;
      game.updateHUD();
      return true;
    }

// exit command menu state
  public function exit()
    {
      if (hud.state != HUD_COMMAND_MENU)
        return;
      hud.state = HUD_DEFAULT;
      game.updateHUD();
    }

// add command menu actions to hud
  public function updateActions()
    {
      if (hud.state != HUD_COMMAND_MENU)
        return;

      var target = getAttackTarget();
      hasAttackAction = (target != null);
      if (hasAttackAction)
        {
          hud.addAction({
            id: 'command.attack',
            type: ACTION_AREA,
            name: (target.type == TARGET_AI ?
              target.ai.prepLog('"Destroy him!"') : '"Destroy that!"'),
          });
        }
      hud.addAction({
        id: 'command.leaveArea',
        type: ACTION_AREA,
        name: '"Leave us!"',
      });
      hud.addAction({
        id: 'command.abort',
        type: ACTION_AREA,
        name: 'Abort',
        isVirtual: true,
      });
    }

// handle command menu action by index
  public function action(index: Int): Bool
    {
      if (hud.state != HUD_COMMAND_MENU)
        return false;

      var i = 1;
      if (hasAttackAction &&
          index == i++)
        return commandAttack();
      if (index == i++)
        return commandLeaveArea();
      if (index == i)
        {
          exit();
          return false;
        }
      return false;
    }

// get current list of cult followers
  function getFollowers(): Array<AI>
    {
      var list: Array<AI> = [];
      if (game.location != LOCATION_AREA ||
          game.area == null)
        return list;

      for (ai in game.area.getAllAI())
        {
          if (!ai.isPlayerCultist() ||
              ai.state == AI_STATE_DEAD ||
              ai == player.host)
            continue;
          list.push(ai);
        }

      return list;
    }

// get current valid attack target
  function getAttackTarget(): AttackTarget
    {
      if (game.area == null)
        return null;

      var target = hud.targeting.target;
      if (target == null ||
          !hud.targeting.isTargetVisibleOnScreen())
        return null;

      switch (target.type)
        {
          case TARGET_AI:
            if (target.ai == null ||
                target.ai.state == AI_STATE_DEAD ||
                game.area.getAIByID(target.ai.id) == null)
              return null;
          case TARGET_OBJECT:
            if (target.obj == null ||
                !target.obj.isAttackableByFriend() ||
                game.area.getObject(target.obj.id) == null)
              return null;
          default:
            return null;
        }
      return target;
    }

// issue attack command
  function commandAttack(): Bool
    {
      var target = getAttackTarget();
      if (target == null)
        {
          game.actionFailed('No visible target.');
          return false;
        }

      if (target.type == TARGET_AI &&
          target.ai.isPlayerCultist())
        {
          game.actionFailed('Followers refuse to attack their own cult.');
          return false;
        }

      var followers = getFollowers();
      for (ai in followers)
        {
          ai.command.type = CMD_ATTACK;
          ai.command.attackTargetType = target.type;
          ai.command.attackTargetID = (
            target.type == TARGET_AI ? target.ai.id : -1);
          ai.command.attackObjectID = (
            target.type == TARGET_OBJECT ? target.obj.id : -1);
          ai.command.leaveAreaTurns = 0;
          if (target.type == TARGET_AI)
            ai.addEnemy(target.ai);
          if (ai.state != AI_STATE_ALERT)
            ai.setState(AI_STATE_ALERT);
        }

      game.log('You order your followers to attack.');
      exit();
      return true;
    }

// issue leave area command
  function commandLeaveArea(): Bool
    {
      var followers = getFollowers();
      for (ai in followers)
        {
          ai.command.type = CMD_LEAVE_AREA;
          ai.command.attackTargetType = TARGET_AI;
          ai.command.attackTargetID = -1;
          ai.command.attackObjectID = -1;
          ai.command.leaveAreaTurns = 0;
          ai.enemies = new List();
          if (ai.state != AI_STATE_IDLE)
            ai.setState(AI_STATE_IDLE);
        }

      game.log('You order your followers to leave.');
      exit();
      return true;
    }
}

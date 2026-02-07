// command menu helper
package game;

import ai.AI;
import jsui.HUD;

class Command
{
  var player: Player;
  var game: Game;
  var hud: HUD;

// create command menu handler
  public function new(p: Player, g: Game, h: HUD)
    {
      player = p;
      game = g;
      hud = h;
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

      hud.addAction({
        id: 'command.attack',
        type: ACTION_AREA,
        name: '"Destroy ' + (hud.targeting.target.isMale ? 'him' : 'her') + '!"',
      });
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

      switch (index)
        {
          case 1:
            return commandAttack();
          case 2:
            return commandLeaveArea();
          case 3:
            exit();
            return false;
          default:
            return false;
        }
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

// issue attack command
  function commandAttack(): Bool
    {
      if (game.area == null)
        return false;

      var target = hud.targeting.target;
      if (target == null ||
          target.state == AI_STATE_DEAD ||
          !hud.targeting.isTargetVisibleOnScreen() ||
          game.area.getAIByID(target.id) == null)
        {
          game.actionFailed('No visible target.');
          return false;
        }

      var followers = getFollowers();
      for (ai in followers)
        {
          ai.command.type = CMD_ATTACK;
          ai.command.attackTargetID = target.id;
          ai.command.leaveAreaTurns = 0;
          ai.addEnemy(target);
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
          ai.command.attackTargetID = -1;
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

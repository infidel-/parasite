// follower command logic
package ai;

import game.Game;

class CommandLogic
{
  public static var game: Game;

// run command logic for follower ai
  public static function turn(ai: AI): Bool
    {
      if (ai.command == null)
        return false;

      switch (ai.command.type)
        {
          case CMD_ATTACK:
            return commandAttack(ai);
          case CMD_LEAVE_AREA:
            return commandLeaveArea(ai);
          case CMD_NONE:
            return false;
        }
      return false;
    }

// clear current command
  static function clearCommand(ai: AI)
    {
      ai.command.type = CMD_NONE;
      ai.command.attackTargetID = -1;
      ai.command.leaveAreaTurns = 0;
    }

// apply attack command state
  static function commandAttack(ai: AI): Bool
    {
      if (game == null ||
          game.area == null)
        return false;

      var targetID = ai.command.attackTargetID;
      if (targetID < 0)
        {
          clearCommand(ai);
          return false;
        }

      var target = game.area.getAIByID(targetID);
      if (target == null ||
          target.state == AI_STATE_DEAD)
        {
          clearCommand(ai);
          return false;
        }

      if (!Lambda.has(ai.enemies, target.id))
        ai.addEnemy(target);
      if (ai.state != AI_STATE_ALERT)
        ai.setState(AI_STATE_ALERT);

      return false;
    }

// apply leave area command state
  static function commandLeaveArea(ai: AI): Bool
    {
      if (game == null ||
          game.area == null)
        return false;

      ai.command.leaveAreaTurns++;

      // check despawn conditions
      var isVisible = game.area.isVisible(
        game.playerArea.x, game.playerArea.y, ai.x, ai.y);
      if (!isVisible ||
          ai.command.leaveAreaTurns >= 10)
        {
          game.area.removeAI(ai);
          return true;
        }

      // move away from the player
      var bestDir = -1;
      var bestDist = -1;
      for (i in 0...Const.dirx.length)
        {
          var nx = ai.x + Const.dirx[i];
          var ny = ai.y + Const.diry[i];
          if (!game.area.isWalkable(nx, ny))
            continue;
          if (game.area.hasAI(nx, ny))
            continue;
          var dist = Const.distanceSquared(
            nx, ny, game.playerArea.x, game.playerArea.y);
          if (dist > bestDist)
            {
              bestDist = dist;
              bestDir = i;
            }
        }
      if (bestDir >= 0)
        ai.setPosition(
          ai.x + Const.dirx[bestDir],
          ai.y + Const.diry[bestDir]);

      return true;
    }
}

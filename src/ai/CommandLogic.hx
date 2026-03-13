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

// check if ai is standing on an exit tile
  static function isExitTile(ai: AI): Bool
    {
      for (o in game.area.getObjectsAt(ai.x, ai.y))
        {
          if (o.type == 'elevator' ||
              o.type == 'stairs')
            return true;
        }
      return false;
    }

// find nearest reachable exit tile for leave-area command
  static function getLeaveAreaTarget(ai: AI): { x: Int, y: Int }
    {
      var best = null;
      var bestPathLength = -1;

      for (o in game.area.getObjects())
        {
          // only consider elevator and stairs tiles
          if (o.type != 'elevator' &&
              o.type != 'stairs')
            continue;
          if (!game.area.isWalkable(o.x, o.y))
            continue;

          // check if the tile is occupied by another ai
          var occupant = game.area.getAI(o.x, o.y);
          if (occupant != null &&
              occupant != ai)
            continue;

          // check if the tile is reachable
          var path = game.area.getPath(ai.x, ai.y, o.x, o.y);
          if (path == null)
            continue;

          // prefer the closest reachable exit tile
          if (best == null ||
              path.length < bestPathLength)
            {
              best = { x: o.x, y: o.y };
              bestPathLength = path.length;
            }
        }

      return best;
    }

// apply leave area command state
  static function commandLeaveArea(ai: AI): Bool
    {
      if (game == null ||
          game.area == null)
        return false;

      ai.command.leaveAreaTurns++;

      var isVisible = game.area.isVisible(
        game.playerArea.x, game.playerArea.y, ai.x, ai.y);

      // despawn immediately after reaching elevator or stairs
      if (isExitTile(ai))
        {
          if (!isVisible)
            game.area.removeAI(ai);
          return true;
        }

      // despawn only after leaving the player's sight
      if (!isVisible)
        {
          game.area.removeAI(ai);
          return true;
        }

      // move toward the nearest reachable exit tile
      var target = getLeaveAreaTarget(ai);
      if (target != null)
        {
          ai.logicMoveTo(target.x, target.y);
          if (isExitTile(ai))
            {
              if (!game.area.isVisible(
                game.playerArea.x, game.playerArea.y, ai.x, ai.y))
                game.area.removeAI(ai);
              return true;
            }
          return true;
        }

      // fallback: move away from the player
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

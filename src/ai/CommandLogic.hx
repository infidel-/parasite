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

      ai.traceAI('CommandLogic', 'turn()');
      ai.traceAI('CommandLogic', 'command ' + ai.command.type);
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
      ai.command.attackTargetType = TARGET_AI;
      ai.command.attackTargetID = -1;
      ai.command.attackObjectID = -1;
      ai.command.leaveAreaTurns = 0;
    }

// apply attack command state
  static function commandAttack(ai: AI): Bool
    {
      if (game == null ||
          game.area == null)
        return false;

      switch (ai.command.attackTargetType)
        {
          case TARGET_AI:
            return commandAttackAI(ai);
          case TARGET_OBJECT:
            return commandAttackObject(ai);
          case TARGET_PLAYER:
            clearCommand(ai);
            return false;
        }
    }

// apply attack command state for an ai target
  static function commandAttackAI(ai: AI): Bool
    {
      var targetID = ai.command.attackTargetID;
      if (targetID < 0)
        {
          ai.traceAI('CommandLogic', 'missing ai target id');
          clearCommand(ai);
          return false;
        }

      var target = game.area.getAIByID(targetID);
      if (target == null ||
          target.state == AI_STATE_DEAD)
        {
          ai.traceAI('CommandLogic', 'ai target gone');
          clearCommand(ai);
          return false;
        }

      if (!Lambda.has(ai.enemies, target.id))
        ai.addEnemy(target);
      if (ai.state != AI_STATE_ALERT)
        ai.setState(AI_STATE_ALERT);

      ai.traceAI('CommandLogic', 'ai target tracked');
      return false;
    }

// apply attack command state for an object target
  static function commandAttackObject(ai: AI): Bool
    {
      var objectID = ai.command.attackObjectID;
      if (objectID < 0)
        {
          ai.traceAI('CommandLogic', 'missing object target id');
          clearCommand(ai);
          return false;
        }

      var obj = game.area.getObject(objectID);
      if (obj == null ||
          !obj.isAttackableByFriend())
        {
          ai.traceAI('CommandLogic', 'object target gone');
          clearCommand(ai);
          return false;
        }

      if (ai.state != AI_STATE_ALERT)
        ai.setState(AI_STATE_ALERT);

      var attacker = Attacker.fromAI(game, ai, false);
      var target: AttackTarget = {
        game: game,
        type: TARGET_OBJECT,
        ai: null,
        obj: obj
      };
      if (RivalBaseOrganAttackLogic.tryAttack(game, ai, attacker, target))
        {
          ai.traceAI('CommandLogic', 'rival organ attack handled');
          return true;
        }
      ai.traceAI('CommandLogic', 'attack object');
      CommonLogic.logicAttack(attacker, target);
      return true;
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
  static function getLeaveAreaTarget(ai: AI): _Tile
    {
      var best: _Tile = null;
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
          ai.traceAI('CommandLogic', 'leave area exit tile');
          if (!isVisible)
            game.area.removeAI(ai);
          return true;
        }

      // despawn only after leaving the player's sight
      if (!isVisible)
        {
          ai.traceAI('CommandLogic', 'leave area unseen');
          game.area.removeAI(ai);
          return true;
        }

      // move toward the nearest reachable exit tile
      var target = getLeaveAreaTarget(ai);
      if (target != null)
        {
          ai.traceAI('CommandLogic', 'leave area move to exit');
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
        {
          ai.traceAI('CommandLogic', 'leave area fallback move');
          ai.setPosition(
            ai.x + Const.dirx[bestDir],
            ai.y + Const.diry[bestDir]);
        }

      return true;
    }
}

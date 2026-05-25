// console goal command helper
package console;

import game.Game;

class Goal
{
  public var console: Console;
  var game: Game;

// sets up goal command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a goal command to its sub-handler; returns false if not a goal command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'goal')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          case 'complete':
            complete(arr.length > 2 ? arr[2] : '');
          case 'receive':
            receive(arr.length > 2 ? arr[2] : '');
          case '':
            log('Usage: goal complete | goal receive <id>');
          default:
            log('Unknown goal command: ' + sub + '.');
        }
      return true;
    }

// completes player goals; with no id completes all current goals, otherwise
// matches the friendly display form against current goals and completes one
  function complete(arg: String)
    {
      if (arg == '')
        {
          for (g in @:privateAccess game.goals._listCurrent)
            game.goals.complete(g);
          return;
        }
      var target = arg.toLowerCase();
      var id: _Goal = null;
      for (g in game.goals.iteratorCurrent())
        if (displayID(g) == target)
          { id = g; break; }
      if (id == null)
        {
          log('No current goal: ' + arg + '.');
          return;
        }
      game.goals.complete(id);
      log('Completed goal: ' + id + '.');
    }

// receives a goal by id (mod/testing helper); accepts the friendly display
// form (GOAL_ prefix stripped, lowercased) and reverse-matches it against the
// common and scenario goal maps before granting
  function receive(arg: String)
    {
      if (arg == '')
        {
          log('Usage: goal receive <id>');
          return;
        }
      var target = arg.toLowerCase();
      var id: _Goal = null;
      for (g in const.Goals.map.keys())
        if (displayID(g) == target)
          { id = g; break; }
      if (id == null)
        for (g in game.timeline.getGoals().keys())
          if (displayID(g) == target)
            { id = g; break; }
      if (id == null)
        {
          log('No such goal: ' + arg + '.');
          return;
        }
      game.goals.receive(id);
      log('Received goal: ' + id + '.');
    }

// friendly console form of a goal id: strips the GOAL_ prefix (if present) and
// lowercases. used by receive() and the tab-completion candidate list
  public static function displayID(id: String): String
    {
      if (StringTools.startsWith(id, 'GOAL_'))
        return id.substr(5).toLowerCase();
      return id.toLowerCase();
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

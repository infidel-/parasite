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
            complete();
          case '':
            log('Usage: goal complete');
          default:
            log('Unknown goal command: ' + sub + '.');
        }
      return true;
    }

// completes all current player goals
  function complete()
    {
      for (g in @:privateAccess game.goals._listCurrent)
        game.goals.complete(g);
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

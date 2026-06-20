// console info command helper (debug traces)
package console;

import const.*;
import game.Game;

class Info
{
  public var console: Console;
  var game: Game;

// sets up info command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes an info command to its sub-handler; returns false if not an info command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'info')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          case 'improvements':
            improvements();
          case 'timeline':
            timeline();
          case '':
            log('Usage: info [improvements|timeline]');
          default:
            log('Unknown info command: ' + sub + '.');
        }
      return true;
    }

// traces every improvement (index, name, id, type, organ)
  function improvements()
    {
      var s = new StringBuf();
      for (i in 0...EvolutionConst.improvements.length)
        {
          var imp = EvolutionConst.improvements[i];
          s.add(i + ': ' + imp.name + ', ' + imp.id +
            ' (' + ('' + imp.type).substr(5) + ')');
          if (imp.organ != null)
            s.add(' [' + imp.organ.name + ']');
          if (i < EvolutionConst.improvements.length - 1)
            s.add(', ');
        }
      log(Const.small(s.toString()));
    }

// traces every timeline event to the browser console
  function timeline()
    {
      for (ev in game.timeline)
        Const.p('' + ev);
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

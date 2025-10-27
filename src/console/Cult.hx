// console cult command helper
package console;

import game.Game;

class Cult
{
  public var console: Console;
  var game: Game;

// sets up cult command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles cult command routing
  public function run(cmd: String): Bool
    {
      if (cmd.length < 2)
        return false;
      
      var arr = cmd.split(' ');
      
      // cu/cult - list sub-commands
      if (arr[0] == 'cu' || arr[0] == 'cult')
        {
          if (arr.length == 1)
            {
              log('Cult commands:');
              log('cu/cult gr - give +10 all resources and +100k money');
              return true;
            }
          
          // cu/cult gr - give resources
          if (arr[1] == 'gr')
            {
              giveResources();
              return true;
            }
          
          log('Unknown cult command: ' + arr[1]);
          return true;
        }
      
      return false;
    }

// give resources to cult
  function giveResources()
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }
      
      var cult = game.cults[0];
      cult.resources.combat += 10;
      cult.resources.media += 10;
      cult.resources.lawfare += 10;
      cult.resources.corporate += 10;
      cult.resources.political += 10;
      cult.resources.money += 100000;
      
      log('Added +10 to all cult resources and +100k money.');
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
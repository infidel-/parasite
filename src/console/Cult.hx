// console cult command helper
package console;

import game.Game;
import cult.UpgradeFollower;

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
              log('cu/cult t - call cult turn');
              log('cu/cult u1 - upgrade random level 1 follower to level 2');
              return true;
            }
          
          // cu/cult gr - give resources
          if (arr[1] == 'gr')
            {
              giveResources();
              return true;
            }
          
          // cu/cult t - advance cult turn
          if (arr[1] == 't')
            {
              advanceTurn();
              return true;
            }

          // cu/cult u1 - upgrade random level 1 member
          if (arr[1] == 'u1')
            {
              upgradeRandomLevelOne();
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

// call next cult turn
  function advanceTurn()
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }
      
      var cult = game.cults[0];
      cult.turn(10);
      
      log('Called next cult turn.');
    }

// upgrade random level 1 member to level 2
  function upgradeRandomLevelOne()
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }

      var cult = game.cults[0];
      if (cult.members.length == 0)
        {
          log('Cult has no members.');
          return;
        }

      var freeIDs = cult.getFreeMembers(1);
      if (freeIDs.length == 0)
        {
          log('No free followers available.');
          return;
        }

      var levelOne = [];
      for (id in freeIDs)
        {
          var member = cult.getMemberByID(id);
          if (member == null)
            continue;
          var jobInfo = game.jobs.getJobInfo(member.job);
          if (jobInfo != null &&
              jobInfo.level == 1)
            levelOne.push(member);
        }

      if (levelOne.length == 0)
        {
          log('No free level 1 followers available.');
          return;
        }

      var target = levelOne[Std.random(levelOne.length)];
      if (UpgradeFollower.upgradeMember(game, cult, target))
        log('Upgraded ' + target.TheName() + ' to level 2.');
      else
        log('Failed to upgrade follower.');
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

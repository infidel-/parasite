// console cult command helper
package console;

import game.Game;
import cult.ordeals.RecruitFollower;
import cult.ordeals.UpgradeFollower;
import cult.ordeals.profane.*;

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
              log('cu/cult r [power] - recruit follower (default combat)');
              log('cu/cult po [power] [idx] - add profane ordeal');
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

          // cu/cult r - recruit follower
          if (arr[1] == 'r')
            {
              recruitFollower(arr);
              return true;
            }
          
          // cu/cult po - add profane ordeal
          if (arr[1] == 'po')
            {
              addProfaneOrdeal(arr);
              return true;
            }
          
          log('Unknown cult command: ' + arr[1]);
          return true;
        }
      
      return false;
    }

// recruit follower by power type
  function recruitFollower(arr: Array<String>)
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }

      // resolve power type or default
      var followerType = 'combat';
      var followerTypes = ['combat', 'media', 'lawfare', 'corporate', 'political'];
      if (arr.length >= 3)
        {
          followerType = arr[2];
          if (followerTypes.indexOf(followerType) == -1)
            {
              log('Unknown power type: ' + followerType);
              log('Available types: ' + followerTypes.join(', '));
              return;
            }
        }

      // create a recruit ordeal and run success immediately
      var cult = game.cults[0];
      var memberCount = cult.members.length;
      var ordeal = new RecruitFollower(game, followerType);
      ordeal.onSuccess();
      if (cult.members.length > memberCount)
        log('Recruited a ' + followerType + ' follower.');
      else
        log('Failed to recruit follower.');
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

// add profane ordeal to cult
  function addProfaneOrdeal(arr: Array<String>)
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }
      
      var cult = game.cults[0];
      
      // show power list if no arguments provided
      if (arr.length == 2)
        {
          log('Available profane ordeal powers:');
          for (power in ProfaneConst.availableTypes)
            {
              var cc = ProfaneConst.constMap.get(power);
              var ordealCount = cc.getInfos().length;
              log(power + ' (' + ordealCount + ' ordeals)');
            }
          return;
        }
      
      // show ordeal list for specific power type
      if (arr.length == 3)
        {
          var powerType = arr[2];
          var cc = ProfaneConst.constMap.get(powerType);
          
          if (cc == null)
            {
              log('Unknown power type: ' + powerType);
              log('Available types: ' + ProfaneConst.availableTypes.join(', '));
              return;
            }

          log('Available ' + powerType + ' ordeals:');
          var infos = cc.getInfos();
          var ordealList = [];
          for (i in 0...infos.length)
            ordealList.push(i + ': ' + infos[i].name);
          log(ordealList.join(', '));
          return;
        }

      // add specific profane ordeal
      if (arr.length >= 4)
        {
          var powerType = arr[2];
          var ordealIndex = Std.parseInt(arr[3]);
          var cc = ProfaneConst.constMap.get(powerType);
          if (cc == null)
            {
              log('Unknown power type: ' + powerType);
              return;
            }

          var infos = cc.getInfos();
          if (ordealIndex < 0 || ordealIndex >= infos.length)
            {
              log('Invalid ordeal index: ' + ordealIndex);
              log('Valid range: 0-' + (infos.length - 1));
              return;
            }

          // create and add the profane ordeal
          var o = new GenericProfaneOrdeal(game, powerType, ordealIndex);
          cult.ordeals.list.push(o);
          log('Added profane ordeal: ' + o.coloredName());
          game.message({
            text: 'A tribulation most foul has descended upon us: ' + o.coloredName() + '.',
            col: 'white'
          });
          return;
        }
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

// console cult command helper
package console;

import game.Game;
import game.Team;
import cult.ordeals.*;
import cult.ordeals.profane.*;
import cult.UpgradeFollowerEvents;
import ui.Choice._ChoiceParams;
import _CultEvent;

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
              log('cu/cult start - start the cult with the current human host as its leader');
              log('cu/cult members - add 3-5 randomly generated followers');
              log('cu/cult gr - give +10 all resources and +100k money');
              log('cu/cult br [amount] - give base resources (default +100)');
              log('cu/cult def [cultID] - add rival base defense ordeal');
              log('cu/cult tdef - add team base defense ordeal');
              log('cu/cult t - call cult turn');
              log('cu/cult u1 - upgrade random level 1 follower to level 2');
              log('cu/cult r [power] - recruit follower (default combat)');
              log('cu/cult po [power] [idx] - add profane ordeal');
              log('cu/cult occasio - open a random occasio choice window (no cult needed)');
              return true;
            }
          
          // cu/cult start - start the cult
          if (arr[1] == 'start')
            {
              startCult();
              return true;
            }

          // cu/cult members - add random followers
          if (arr[1] == 'members')
            {
              addRandomFollowers();
              return true;
            }

          // cu/cult gr - give resources
          if (arr[1] == 'gr')
            {
              giveResources();
              return true;
            }

          // cu/cult br - give base resources
          if (arr[1] == 'br')
            {
              giveBaseResources(arr);
              return true;
            }

          // cu/cult def - add base defense ordeal
          if (arr[1] == 'def')
            {
              addBaseDefenseOrdeal(arr);
              return true;
            }

          // cu/cult tdef - add team base defense ordeal
          if (arr[1] == 'tdef')
            {
              addTeamBaseDefenseOrdeal();
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

          // cu/cult occasio - open a random occasio choice window for testing
          if (arr[1] == 'occasio' || arr[1] == 'occ')
            {
              showRandomOccasio();
              return true;
            }

          log('Unknown cult command: ' + arr[1]);
          return true;
        }
      
      return false;
    }

// start the cult with the current host as its leader
// NOTE: the player cult object always exists (Game.init creates it at cults[0]), so this
// activates the existing inactive/dead one rather than making a new one
  function startCult()
    {
      var cult = game.cults[0];
      if (cult.state == CULT_STATE_ACTIVE)
        {
          log('Cult is already active, led by ' + cult.leader.TheName() + '.');
          return;
        }

      // the leader is a real in-world AI, so it has to be a human host we currently ride
      if (game.player.state != PLR_STATE_HOST ||
          !game.player.host.isHuman)
        {
          log('Needs a human host to lead the cult. Invade one first.');
          return;
        }

      cult.addLeader(game.player.host);
      log('Started ' + cult.customName() + ', led by ' + cult.leader.TheName() + '.');
    }

// add 3-5 randomly generated followers to the cult.
// RecruitFollower builds a properly-jobbed AIData per power type (a bare CivilianAI would keep
// job 'undefined' and be rejected), so reuse it as the generator like `cu r` does. the ordeal is
// discarded and never enters cult.ordeals.list, so it locks no members (see Cult.getFreeMembers)
  function addRandomFollowers()
    {
      var cult = game.cults[0];
      if (cult.state != CULT_STATE_ACTIVE)
        {
          log('No active cult. Use cu start first.');
          return;
        }

      var followerTypes = ['combat', 'media', 'lawfare', 'corporate', 'political'];
      var amount = 3 + Std.random(3);
      var added = 0;
      for (i in 0...amount)
        {
          var memberCount = cult.members.length;
          var ordeal = new RecruitFollower(game, followerTypes[Std.random(followerTypes.length)]);
          ordeal.onSuccess();
          if (cult.members.length > memberCount)
            added++;
        }

      // addAIData enforces cult size + per-level job limits, so a roll can legitimately be refused
      if (added < amount)
        log('Added ' + added + ' of ' + amount + ' followers (the rest hit cult size/level limits).');
      else log('Added ' + added + ' followers.');
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

// give resources to the cult base
  function giveBaseResources(arr: Array<String>)
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }

      var cult = game.cults[0];
      if (cult.base == null)
        {
          log('Cult has no base.');
          return;
        }

      var amount = 100;
      if (arr.length >= 3)
        {
          var parsed = Std.parseInt(arr[2]);
          if (parsed == null)
            {
              log('Invalid base resource amount: ' + arr[2]);
              return;
            }
          amount = parsed;
        }

      cult.base.resources.flesh += amount;
      cult.base.resources.blood += amount;
      cult.base.resources.bone += amount;
      game.updateHUD();

      log('Added +' + amount + ' flesh, blood, and bone to cult base.');
    }

// add base defense ordeal to cult
  function addBaseDefenseOrdeal(arr: Array<String>)
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }

      var cult = game.cults[0];
      var base = cult.base;
      if (base == null)
        {
          log('Cult has no base.');
          return;
        }
      if (base.activeDefenseMissionID >= 0)
        {
          log('Base defense already active.');
          return;
        }

      var rival = getBaseDefenseRival(arr);
      if (rival == null)
        return;

      var ordeal = new BaseDefense(game, rival.id);
      cult.ordeals.list.push(ordeal);
      base.activeDefenseMissionID = ordeal.missions[0].id;
      base.activeDefenseTimer = ordeal.timer;
      game.updateHUD();

      log('Added base defense ordeal: ' + ordeal.coloredName());
      game.message({
        text: 'Heretics close on Cor Nefandum. Defend the base before the timer expires.',
        col: 'alert'
      });
    }

// add team base defense ordeal to cult
  function addTeamBaseDefenseOrdeal()
    {
      if (game.cults.length == 0)
        {
          log('No cult found.');
          return;
        }

      var cult = game.cults[0];
      var base = cult.base;
      if (base == null)
        {
          log('Cult has no base.');
          return;
        }
      if (base.activeDefenseMissionID >= 0)
        {
          log('Base defense already active.');
          return;
        }

      if (game.group.team == null)
        game.group.team = new Team(game);
      if (!game.group.team.spawnBaseDefenseOrdeal())
        {
          log('Failed to add team base defense ordeal.');
          return;
        }

      game.updateHUD();
      log('Added team base defense ordeal.');
    }

// returns rival cult for console-spawned base defense
  function getBaseDefenseRival(arr: Array<String>): cult.Cult
    {
      if (arr.length >= 3)
        {
          var cultID = Std.parseInt(arr[2]);
          if (cultID == null)
            {
              log('Invalid rival cult ID.');
              return null;
            }
          var rival = game.getRivalCultByID(cultID);
          if (rival == null ||
              rival.state != CULT_STATE_ACTIVE)
            {
              log('No active rival cult with ID ' + cultID + '.');
              return null;
            }
          return rival;
        }

      var rivals = game.getRivalCults(true);
      if (rivals.length == 0)
        {
          log('No active rival cult found.');
          return null;
        }
      return rivals[Std.random(rivals.length)];
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
      cult.turnInternal(10);
      
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
          moveToOrdealMissionSpotInRegion(o);
          return;
        }
    }

// move player to ordeal mission marker spot when in region mode
  function moveToOrdealMissionSpotInRegion(ordeal: GenericProfaneOrdeal)
    {
      if (game.location != LOCATION_REGION ||
          ordeal == null ||
          ordeal.missions == null ||
          ordeal.missions.length == 0)
        return;

      var mission = ordeal.missions[0];
      var spotX = mission.x;
      var spotY = mission.y;

      if (mission.markerAreaID >= 0)
        {
          var markerArea = game.region.get(mission.markerAreaID);
          if (markerArea != null)
            {
              spotX = markerArea.x;
              spotY = markerArea.y;
            }
        }

      if (spotX < 0 ||
          spotY < 0)
        {
          log('Ordeal added, but mission spot coordinates are invalid.');
          return;
        }

      if (!game.playerRegion.moveTo(spotX, spotY, false))
        {
          log('Ordeal added, but could not move to mission spot (' + spotX + ',' + spotY + ').');
          return;
        }
      log('Moved to ordeal mission spot: (' + spotX + ',' + spotY + ').');
    }

// open a random occasio choice window from the predefined event pool.
// choices are replaced with a log-only handler, so no real cult is needed
  function showRandomOccasio()
    {
      // flatten the predefined occasio events across all job groups
      var pool: Array<_CultEvent> = [];
      for (events in UpgradeFollowerEvents.list)
        for (e in events)
          pool.push(e);
      if (pool.length == 0)
        {
          log('No occasio events available.');
          return;
        }
      var event = pool[Std.random(pool.length)];

      // build choice params; f only logs (no cult side effects)
      var params: _ChoiceParams = {
        title: Const.col('occasio', 'Occasio') + ': ' + event.title,
        text: event.text,
        img: 'img/cult/occasio.jpg',
        choices: [],
        buttons: [],
        textClass: 'choice-occasio',
        src: event,
        f: function(src: Dynamic, choiceID: Int)
          {
            var e: _CultEvent = cast src;
            var choice = e.choices[choiceID - 1];
            game.log('You chose ' + Const.col('gray', choice.button) +
              ' in occasio ' + Const.col('occasio', e.title) + '.');
          }
      };
      for (choice in event.choices)
        {
          params.buttons.push(choice.button);
          params.choices.push(choice.text);
        }

      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_CHOICE,
        obj: params
      });
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

// console stage command helper
package console;

import const.*;
import const.EvolutionConst;
import game.Game;
import game.Team;
import scenario.GoalsAlienCrashLanding;
import Std;

class Stage
{
  public var console: Console;
  var game: Game;

// sets up stage command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles stage command routing
  public function run(cmd: String): Bool
    {
      if (cmd == 's')
        {
          console.log(
            ';s1 - set player stage 1 (human civilian host, tutorial done)<br/>' +
            ';s11 - set player stage 1.1 (stage 1 + group knowledge)<br/>' +
            ';s12 - set player stage 1.2 (stage 1.1 + ambush)<br/>' +
            ';s2 - set player stage 2 (stage 1 + microhabitat)<br/>' +
            ';s21 - set player stage 2.1 (stage 2 + camo layer, computer use)<br/>' +
            ';s22 - set player stage 2.2 (stage 2.1 + biomineral)<br/>' +
            ';s23 - set player stage 2.3 (stage 2.2 + assimilation)<br/>' +
            ';s24 - set player stage 2.4 (stage 2.1 + group knowledge)<br/>' +
            ';s25 - set player stage 2.5 (stage 2 + ambush)<br/>' +
            ';s3 - set player stage 3 (stage 2.3 + spaceship)<br/>' +
            ';s31 - set player stage 3.1 (stage 3 + ready to launch)'
            );
          return true;
        }

      if (cmd.length < 2)
        return false;

      var stage = Std.parseInt(cmd.substr(1));
      if (stage == null || stage <= 0)
        return false;

      game.importantMessagesEnabled = false;

      if (stage == 1)
        stage1();
      else if (stage == 11)
        {
          stage1();
          stage11();
        }
      else if (stage == 12)
        {
          stage1();
          stage11();
          stage12();
        }
      else if (stage == 2)
        {
          stage1();
          stage2();
        }
      else if (stage == 21)
        {
          stage1();
          stage2();
          stage21();
        }
      else if (stage == 22)
        {
          stage1();
          stage2();
          stage21();
          stage22();
        }
      else if (stage == 23)
        {
          stage1();
          stage2();
          stage21();
          stage22();
          stage23();
        }
      else if (stage == 24)
        {
          stage1();
          stage2();
          stage21();
          stage24();
        }
      else if (stage == 25)
        {
          stage1();
          stage2();
          stage25();
        }
      else if (stage == 3)
        {
          stage1();
          stage2();
          stage21();
          stage22();
          stage23();
          stage3();
        }
      else if (stage == 31)
        {
          stage1();
          stage2();
          stage21();
          stage22();
          stage23();
          stage3();
          stage31();
        }
      else
        {
          game.importantMessagesEnabled = true;
          return false;
        }

      game.importantMessagesEnabled = true;
      return true;
    }

// runs console go command helper
  inline function goCommand(cmd: String)
    {
      console.goCommand(cmd);
    }

// logs through the console helper
  inline function log(s: String)
    {
      console.log(s);
    }

// stage 1: civ host, tutorial done
  function stage1()
    {
      game.log('stage 1');
      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      ai.skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // tutorial line
      game.goals.complete(GOAL_TUTORIAL_ALERT);
      game.goals.complete(GOAL_TUTORIAL_BODY);
      game.goals.complete(GOAL_TUTORIAL_BODY_SEWERS);
      game.goals.complete(GOAL_TUTORIAL_ENERGY);
      game.goals.complete(GOAL_TUTORIAL_AREA_ALERT);
      game.goals.complete(GOAL_INVADE_HOST);
      game.goals.complete(GOAL_INVADE_HUMAN);
      game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 2);
      game.goals.complete(GOAL_EVOLVE_PROBE);
      var probeInfo = const.EvolutionConst.getInfo(IMP_BRAIN_PROBE);
      game.playerArea.action(probeInfo.action);
      game.goals.complete(GOAL_LEARN_ITEMS);
      game.playerArea.action(probeInfo.action);

      // society knowledge
      game.player.skills.increase(KNOW_SOCIETY, 1);
      game.player.skills.increase(KNOW_SOCIETY, 24);
      game.timeline.difficulty = EASY;
    }


// stage 1.1: stage 1 + group knowledge
  function stage11()
    {
      game.log('stage 1.1');
      var ai = game.player.host;
      ai.brainProbed = 0;
      game.group.knownCount = 1;

      if (game.scenarioStringID == 'alien')
        {
          // get a random live npc and tie it to the host
          var listEvents = [ 'parasiteRemoval', 'parasiteTransportation' ];
          for (id in listEvents)
            {
              var ev = game.timeline.getEvent(id);
              var npc = null;
              trace(ev.npc);
              for (n in ev.npc)
                if (!n.isDead)
                  {
                    npc = n;
                    break;
                  }
              // all npcs dead, try next event
              if (npc == null)
                continue;

              // link host to this npc
              npc.ai = ai;
              ai.eventID = ev.id;
              ai.npcID = npc.id;
              ai.isNPC = true;
              ai.entity.setNPC();

              break;
            }
        }
      else
        {
          // kill host from stage 1
          game.playerArea.leaveHostAction('default');
          ai.die();

          game.group.team = new Team(game);
          game.group.team.distance = 10;

          // spawn team member AI, attach to it and invade
          var teamAI = game.area.spawnAI('team',
            game.playerArea.x, game.playerArea.y);
          teamAI.isTeamMember = true;
          game.playerArea.debugAttachAndInvadeAction(teamAI);
          game.player.hostControl = 100;
        }
    }


// stage 1.2: stage 1.1 + ambush
  function stage12()
    {
      game.log('stage 1.2');
      game.group.team = new Team(game);
      game.group.team.distance = 0;
      game.group.team.level = 4;
      game.group.team.state = TEAM_AMBUSH;
      game.group.team.timer = 0;
    }


// stage 2: stage 1 + microhabitat, timeline open
  function stage2()
    {
      game.log('stage 2');
      game.player.evolutionManager.addImprov(IMP_ENERGY, 1);
      game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 3);
      game.goals.complete(GOAL_EVOLVE_ORGAN);
      game.player.host.organs.action('set.IMP_ENERGY');
      game.player.host.organs.debugCompleteCurrent();

      // habitat
      game.player.evolutionManager.addImprov(IMP_MICROHABITAT, 1);
      game.goals.complete(GOAL_EVOLVE_MICROHABITAT);

      // learn and enter sewers
      game.playerArea.debugLearnObject('sewer_hatch');
      game.ui.state = UISTATE_DEFAULT;
      game.setLocation(LOCATION_REGION);

      game.playerRegion.action({
        id: 'createHabitat',
        type: ACTION_REGION,
        name: 'Create habitat',
        energy: 0
      });
//      game.goals.complete(GOAL_CREATE_HABITAT);
    }


// stage 2.1: stage 2 + camo, dopamine, computer
  function stage21()
    {
      // camo
      game.goals.receive(GOAL_EVOLVE_CAMO);
      game.goals.complete(GOAL_EVOLVE_CAMO);
      game.player.evolutionManager.addImprov(IMP_CAMO_LAYER, 2);
      game.player.host.organs.action('set.IMP_CAMO_LAYER');
      game.player.host.organs.debugCompleteCurrent();

      // dopamine
      game.goals.receive(GOAL_EVOLVE_DOPAMINE);
      game.goals.complete(GOAL_EVOLVE_DOPAMINE);
      game.player.evolutionManager.addImprov(IMP_DOPAMINE, 1);

      // computer and computer use
      game.player.host.inventory.addID('smartphone');
      game.player.addKnownItem('smartphone');
      game.player.host.inventory.addID('laptop');
      game.player.addKnownItem('laptop');
      game.player.host.skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
      game.player.skills.addID(SKILL_COMPUTER, 30);

      // forward timeline
      if (game.scenarioStringID == 'alien')
        {
          game.goals.receive(GOAL_LEARN_CLUE);
          game.timeline.learnClues(game.timeline.getStartEvent(), true);
          game.timeline.getStartEvent().learnNPC();
          game.goals.complete(GOAL_LEARN_NPC);
        }
    }


// stage 2.2: stage 2.1 + biomineral
  function stage22()
    {
      // enter habitat
      game.playerRegion.action({
        id: 'enterHabitat',
        type: ACTION_REGION,
        name: 'Enter habitat',
        energy: 0
      });

      // biomineral
      game.player.evolutionManager.addImprov(IMP_BIOMINERAL, 2);
      game.player.host.organs.action('set.IMP_BIOMINERAL');
      game.player.host.organs.debugCompleteCurrent();

      // build biomineral
      var o = game.player.host.organs.get(IMP_BIOMINERAL);
      var a = o.info.action;
      a.obj = o;
      game.player.host.organs.areaAction(a);

      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;
    }


// stage 2.3: stage 2.2 + assimilation cavity
  function stage23()
    {
      // assimilation cavity
      game.player.evolutionManager.addImprov(IMP_ASSIMILATION, 1);
      game.player.host.organs.action('set.IMP_ASSIMILATION');
      game.player.host.organs.debugCompleteCurrent();

      // move right
      game.playerArea.moveBy(1, 0);

      // build assimilation cavity
      var o = game.player.host.organs.get(IMP_ASSIMILATION);
      var a = o.info.action;
      a.obj = o;
      game.player.host.organs.areaAction(a);

      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // computer and computer use
      game.player.host.inventory.addID('smartphone');
      game.player.addKnownItem('smartphone');
      game.player.host.inventory.addID('laptop');
      game.player.addKnownItem('laptop');
      game.player.host.skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
    }


// stage 2.4: stage 2.1 + group knowledge
  function stage24()
    {
      game.log('stage 2.4');
      game.setLocation(LOCATION_AREA);
      stage11();
    }


// stage 2.5: stage 2 + ambush
  function stage25()
    {
      // enter habitat
      game.playerRegion.action({
        id: 'enterHabitat',
        type: ACTION_REGION,
        name: 'Enter habitat',
        energy: 0
      });
      game.group.team = new Team(game);
      game.group.team.distance = 2;
      game.group.team.level = 4;
      game.group.team.state = TEAM_AMBUSH;
      game.group.team.timer = 0;
    }


// stage 3: stage 2.3 + timeline open until scenario goals
  function stage3()
    {
      if (game.scenarioStringID != 'alien')
        {
          log('Different scenario: ' + game.scenarioStringID + '.');
          return;
        }

      // assimilate current host
      game.player.host.addTrait(TRAIT_ASSIMILATED);

      // learn needed events
      for (idx in [ 12, 11, 8, 7 ])
        {
          var event = game.timeline.getEventByIndex(idx);
          while (!event.notesKnown())
            event.learnNote();
          event.learnLocation();
        }

      // go to the spaceship location
      var ev = game.timeline.getEvent('alienShipStudy');
      var area = ev.location.area;
      goCommand('ga' + area.x + ' ' + area.y);

      var obj = @:privateAccess GoalsAlienCrashLanding.getSpaceshipObject(game);
      goCommand('gg' + obj.x + ' ' + obj.y);
    }


// stage 3.1: stage 3 + ready to launch
  function stage31()
    {
      game.player.vars.npcEnabled = true;
      game.player.vars.searchEnabled = true;
      var state = @:privateAccess GoalsAlienCrashLanding.getSpaceshipState(game);
      state.part1Installed = true;
      state.part2Installed = true;
      state.part3Installed = true;
    }
}

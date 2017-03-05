// game console

package game;

import ai.*;
import const.*;
import objects.EventObject;

class ConsoleGame
{
  public var game: Game;


  public function new(g: Game)
    {
      game = g;
    }


// run console command
  public function run(cmd: String)
    {
      cmd = StringTools.trim(cmd);
      if (cmd == '')
        return;

      game.debug('Console command: ' + cmd);
      var arr = cmd.split(' ');

      // XXX add commands
      if (cmd.charAt(0) == 'a')
        addCommand(cmd);

      // XXX config commands
      else if (cmd.charAt(0) == 'c')
        {
          // XXX config|cfg <option> <value>
          if (arr[0] == 'config' || arr[0] == 'cfg')
            configOptionCommand(arr);
        }

      // XXX go commands
      else if (cmd.charAt(0) == 'g')
        goCommand(cmd);

      // XXX info commands
      else if (cmd.charAt(0) == 'i')
        infoCommand(cmd);

      // XXX learn commands
      else if (cmd.charAt(0) == 'l')
        learnCommand(cmd);

      // XXX restart
      else if (cmd.charAt(0) == 'r')
        {
          if (arr[0] == 'restart')
            game.restart();
        }

      // XXX set commands
      else if (cmd.charAt(0) == 's')
        {
          // XXX set <variable> <value>
          if (arr[0] == 'set')
            setVariableCommand(arr);

          else setCommand(cmd);
        }

      // XXX quit game
      else if (cmd.charAt(0) == 'q')
        game.scene.exit();

      game.updateHUD(); // update HUD state
    }


// config <option> <value>
// config
  function configOptionCommand(arr: Array<String>)
    {
      if (arr.length == 1)
        {
          game.config.dump();
          return;
        }

      if (arr.length < 3)
        {
          game.debug('config|cfg <option> <value> - set config option');
          game.debug('config|cfg - show config options');
          return;
        }

      var key = arr[1];
      var val = arr[2];
      game.config.set(key, val, true);
    }


// set <variable> <value>
// set
  function setVariableCommand(arr: Array<String>)
    {
      if (arr.length < 3)
        {
          game.debug('set <variable> <value> - set game variable');
          game.debug('set - show options');
          game.debug('group.priority, ' +
            'team.distance, team.size, team.timeout, team.timer');
          return;
        }

      var key = arr[1];
      var val = arr[2];
      var valInt = Std.parseInt(val);

      if (key == 'group.priority')
        game.group.priority = valInt;
      else if (key == 'team.distance')
        {
          if (game.group.team != null)
            game.group.team.distance = valInt;
        }
      else if (key == 'team.size')
        {
          if (game.group.team != null)
            game.group.team.size = valInt;
        }
      else if (key == 'team.timeout')
        game.group.teamTimeout = valInt;
      else if (key == 'team.timer')
        {
          if (game.group.team != null)
            game.group.team.timer = valInt;
        }
    }


// add commands
  function addCommand(cmd: String)
    {
      // XXX [ao10] add organ X
      if (cmd.charAt(1) == 'o')
        {
          var idx = Std.parseInt(cmd.substr(2));
          var imp = EvolutionConst.improvements[idx];
          if (imp == null)
            {
              game.debug('Improvement [' + idx + '] not found.');
              return;
            }

          game.player.evolutionManager.addImprov(imp.id, 3);
          game.player.host.organs.action('set.' + imp.id);
          game.player.host.organs.debugCompleteCurrent();
        }
    }


// go commands
  function goCommand(cmd: String)
    {
      // XXX [ge10] go to event X location
      if (cmd.charAt(1) == 'e')
        {
          var idx = Std.parseInt(cmd.substr(2));
          var event = game.timeline.getEventByIndex(idx);
          if (event == null)
            {
              game.debug('Event ' + idx + ' not found in the timeline.');
              return;
            }

          if (event.location == null)
            {
              game.debug('Event ' + idx + ' has no location.');
              return;
            }

          game.debug('Teleporting to event ' + idx + ' location.');

          var area = event.location.area;
          game.scene.setState(HUDSTATE_DEFAULT);

          // leave current area
          if (game.location == LOCATION_AREA)
            game.setLocation(LOCATION_REGION);

          // move to new location
          game.playerRegion.moveTo(area.x, area.y);

          // enter area
          game.setLocation(LOCATION_AREA);
        }

      // XXX [ga10 10] go to area and enter it
      else if (cmd.charAt(1) == 'a')
        {
          var tmp = cmd.substr(2).split(' ');
          if (tmp.length < 2 || tmp.length > 2)
            {
              game.debug('wrong format');
              return;
            }

          var x = Std.parseInt(tmp[0]);
          var y = Std.parseInt(tmp[1]);
          var area = game.region.getXY(x, y);
          if (area == null)
            {
              game.debug('wrong location');
              return;
            }

          game.debug('Teleporting to area (' + x + ',' + y + ').');

          // leave current area
          if (game.location == LOCATION_AREA)
            game.setLocation(LOCATION_REGION);

          // move to new location
          game.playerRegion.moveTo(area.x, area.y);

          // enter area
          game.setLocation(LOCATION_AREA);
        }

      // XXX [gg10 10] go to location x,y at current location
      else if (cmd.charAt(1) == 'g')
        {
          var tmp = cmd.substr(2).split(' ');
          if (tmp.length < 2 || tmp.length > 2)
            {
              game.debug('wrong format');
              return;
            }

          var x = Std.parseInt(tmp[0]);
          var y = Std.parseInt(tmp[1]);

          game.debug('Teleporting to location (' + x + ',' + y + ').');

          if (game.location == LOCATION_AREA)
            game.playerArea.moveTo(x, y);
          else game.playerRegion.moveTo(x, y);
        }
    }


// info commands
  function infoCommand(cmd: String)
    {
      // XXX [ie] events info
      if (cmd.charAt(1) == 'e')
        {
          for (ev in game.timeline)
            Const.p('' + ev);
        }

      // XXX [ii] improvements info
      else if (cmd.charAt(1) == 'i')
        {
          for (i in 0...EvolutionConst.improvements.length)
            {
              var imp = EvolutionConst.improvements[i];

              Const.p(i + ': ' + imp.name + ', ' + imp.id +
                ' (' + imp.path + ')');
              if (imp.organ != null)
                Const.p('  organ: ' + imp.organ.name);
            }
        }
    }


// learn commands
  function learnCommand(cmd: String)
    {
      // XXX [le10] learn everything about event X
      if (cmd.charAt(1) == 'e')
        {
          var idx = Std.parseInt(cmd.substr(2));
          var event = game.timeline.getEventByIndex(idx);
          if (event == null)
            {
              game.debug('Event [' + idx + '] not found in the timeline.');
              return;
            }

          while (!event.notesKnown())
            event.learnNote();
          event.learnLocation();
        }

      // XXX [lia] learn all improvements
      else if (cmd.charAt(1) == 'i' && cmd.charAt(2) == 'a')
        {
          var level = 3;
          if (cmd.length > 2)
            level = Std.parseInt(cmd.substr(3));
          for (imp in EvolutionConst.improvements)
            game.player.evolutionManager.addImprov(imp.id, level);

          game.player.evolutionManager.state = 2;
        }

      // XXX [li10] learn improvement X
      else if (cmd.charAt(1) == 'i')
        {
          var idx = Std.parseInt(cmd.substr(2));
          var imp = EvolutionConst.improvements[idx];
          if (imp == null)
            {
              game.debug('Improvement [' + idx + '] not found.');
              return;
            }

          game.player.evolutionManager.addImprov(imp.id, 3);
        }

      // XXX [lt] learn all timeline
      else if (cmd.charAt(1) == 't')
        {
          game.log('Timeline opened.');
          for (e in game.timeline)
            {
              e.locationKnown = true;
              for (n in e.notes)
                n.isKnown = true;

              for (npc in e.npc)
                {
                  npc.nameKnown = true;
                  npc.jobKnown = true;
                  npc.areaKnown = true;
                  npc.statusKnown = true;
                }
            }

          game.timeline.update(); // update event numbering
        }
    }


// set commands
  function setCommand(cmd: String)
    {
      // no arguments, show available
      if (cmd == 's')
        {
          game.debug(
            ';s1 - set player stage 1 (human civilian host, tutorial done)\n' +
            ';s2 - set player stage 2 (stage 1 + microhabitat)\n' +
            ';s21 - set player stage 2.1 (stage 2 + camo layer, computer use)\n' +
            ';s22 - set player stage 2.2 (stage 2.1 + biomineral)\n' +
            ';s23 - set player stage 2.3 (stage 2.2 + assimilation)\n' +
            ';s3 - set player stage 3 (stage 2.3 + timeline open until scenario goals)'
            );
          return;
        }

      var stage = Std.parseInt(cmd.substr(1));

      // XXX [s1] set stage X
      if (stage > 0)
        {
          game.importantMessagesEnabled = false;

          // stage 1: civ host, tutorial done
          if (stage == 1)
            {
              stage1();
            }

          // stage 2: civ host, microhabitat, timeline open
          else if (stage == 2)
            {
              stage1();
              stage2();
            }

          // stage 2.1: 2 + camo, dopamine, computer
          else if (stage == 21)
            {
              stage1();
              stage2();
              stage21();
            }

          // stage 2.2: 2.1 + biomineral
          else if (stage == 22)
            {
              stage1();
              stage2();
              stage21();
              stage22();
            }

          // stage 2.3: 2.2 + assimilation cavity
          else if (stage == 23)
            {
              stage1();
              stage2();
              stage21();
              stage22();
              stage23();
            }

          // stage 3: 2.3 + timeline open until scenario goals
          else if (stage == 3)
            {
              stage1();
              stage2();
              stage21();
              stage22();
              stage23();
              stage3();
            }

          game.importantMessagesEnabled = true;
        }

      // XXX [sa] set area commands
      else if (cmd.charAt(1) == 'a')
        {
        }
    }


// stage 1: civ host, tutorial done
  function stage1()
    {
      game.log('stage 1');
      // spawn AI, attach to it and invade
      var ai = new CivilianAI(game, game.playerArea.x, game.playerArea.y);
      game.area.addAI(ai);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // tutorial line
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
      game.scene.setState(HUDSTATE_DEFAULT);
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
      game.goals.receive(GOAL_LEARN_CLUE);
      game.timeline.learnClue(game.timeline.getStartEvent(), true);
      game.timeline.getStartEvent().learnNPC();
      game.goals.complete(GOAL_LEARN_NPC);
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
      var ai = new CivilianAI(game, game.playerArea.x, game.playerArea.y);
      game.area.addAI(ai);
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
      var ai = new CivilianAI(game, game.playerArea.x, game.playerArea.y);
      game.area.addAI(ai);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // computer and computer use
      game.player.host.inventory.addID('smartphone');
      game.player.addKnownItem('smartphone');
      game.player.host.inventory.addID('laptop');
      game.player.addKnownItem('laptop');
      game.player.host.skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
    }


// stage 3: stage 2.3 + timeline open until scenario goals
  function stage3()
    {
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

      var obj: EventObject = game.timeline.getDynamicVar('spaceShipObject');
      goCommand('gg' + obj.x + ' ' + obj.y);
    }
}


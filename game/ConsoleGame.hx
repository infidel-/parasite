// game console

package game;

import ai.*;

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

      // XXX go commands
      if (cmd.charAt(0) == 'g')
        goCommand(cmd);

      // XXX learn commands
      else if (cmd.charAt(0) == 'l')
        learnCommand(cmd);

      // XXX stage commands 
      else if (cmd.charAt(0) == 's')
        stageCommand(cmd);

      game.updateHUD(); // update HUD state
    }


// go commands
  function goCommand(cmd: String)
    {
      // XXX [ge10] go to event location
      if (cmd.charAt(1) == 'e')
        {
          var id = Std.parseInt(cmd.substr(2));
          var cnt = 0;
          var event = null;
          for (ev in game.timeline.iterator())
            {
              if (cnt == id)
                {
                  event = ev;
                  break;
                }
                
              cnt++;
            }

          if (event == null)
            {
              game.debug('No event with id ' + id + ' found in timeline.');
              return;
            }

          if (event.location == null)
            {
              game.debug('Event ' + id + ' has no location.');
              return;
            }

          game.debug('Teleporting to event ' + id + ' location.');

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


// learn commands
  function learnCommand(cmd: String)
    {
      // XXX [le10] learn everything about event 
      if (cmd.charAt(1) == 'e')
        {
          var id = Std.parseInt(cmd.substr(2));
          var cnt = 0;
          var event = null;
          for (ev in game.timeline.iterator())
            {
              if (cnt == id)
                {
                  event = ev;
                  break;
                }
                
              cnt++;
            }

          while (!event.notesKnown())
            event.learnNote();
          event.learnLocation();
        }
    }


// stage commands
  function stageCommand(cmd: String)
    {
      var stage = Std.parseInt(cmd.substr(1));
     
      // stage 1: civ host, tutorial done
      if (stage >= 1)
        {
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
//          game.goals.complete();
        }
    }
}

// game console

package game;

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

      // go commands
      if (cmd.charAt(0) == 'g')
        {
          // [ge10] go to event location
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

          // [ga10 10] go to area and enter it
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

          // [gg10 10] go to location x,y at current location 
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
      else if (cmd.charAt(0) == 'l')
        {
          // [le10] learn everything about event 
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

      game.updateHUD(); // update HUD state
    }
}

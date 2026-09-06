// console go (teleport) command helper
package console;

import game.Game;

class Go
{
  public var console: Console;
  var game: Game;

// sets up go command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a go command to its sub-handler; returns false if not a go command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'go')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          case 'area':
            goArea(arr);
          case 'event':
            goEvent(arr);
          case 'xy':
            goXY(arr);
          case '':
            log('Usage: go [area [x] [y]|event [index]|xy [x] [y]]');
          default:
            log('Unknown go target: ' + sub + '.');
        }
      return true;
    }

// go to region area and enter it: go area [x] [y]
  function goArea(arr: Array<String>)
    {
      if (arr.length < 4)
        {
          log('Usage: go area [x] [y]');
          return;
        }
      var x = Std.parseInt(arr[2]);
      var y = Std.parseInt(arr[3]);
      var area = game.region.getXY(x, y);
      if (area == null)
        {
          log('wrong location');
          return;
        }
      log('Teleporting to area (' + x + ',' + y + ').');
      game.player.teleport(area);
    }

// go to event location: go event [index]
  function goEvent(arr: Array<String>)
    {
      if (arr.length < 3)
        {
          log('Usage: go event [event index]');
          return;
        }
      var idx = Std.parseInt(arr[2]);
      var event = game.timeline.getEventByIndex(idx);
      if (event == null)
        {
          log('Event ' + idx + ' not found in the timeline.');
          return;
        }
      if (event.location == null)
        {
          log('Event ' + idx + ' has no location.');
          return;
        }
      log('Teleporting to event ' + idx + ' location.');
      var area = event.location.area;
      game.ui.state = UISTATE_DEFAULT;
      game.player.teleport(area);
    }

// go to x,y at current location (region or area mode): go xy [x] [y]
  function goXY(arr: Array<String>)
    {
      if (arr.length < 4)
        {
          log('Usage: go xy [x] [y]');
          return;
        }
      var x = Std.parseInt(arr[2]);
      var y = Std.parseInt(arr[3]);
      if (game.location == LOCATION_AREA)
        {
          // a wall, a closed door or a piece of furniture makes the target unwalkable, and moveTo
          // then returns false and does nothing while the log still claimed a teleport. land on the
          // nearest free tile instead — an unwalkable cell is usually exactly what you aimed at
          var to = walkableNear(x, y);
          if (to == null)
            {
              log('Cannot teleport to (' + x + ',' + y + '): tile and all its neighbours are blocked.');
              return;
            }
          if (to.x != x ||
              to.y != y)
            log('(' + x + ',' + y + ') is blocked, teleporting to adjacent (' + to.x + ',' +
              to.y + ').');
          else log('Teleporting to location (' + x + ',' + y + ').');
          game.playerArea.moveTo(to.x, to.y);
        }
      else
        {
          log('Teleporting to location (' + x + ',' + y + ').');
          game.playerRegion.moveTo(x, y, false);
        }
      game.scene.updateCamera();
      game.scene.draw();
    }

// the target tile if it is walkable, else its first walkable neighbour, else null
  function walkableNear(x: Int, y: Int): { x: Int, y: Int }
    {
      if (game.area.isWalkable(x, y))
        return { x: x, y: y };
      for (i in 0...Const.dirx.length)
        if (game.area.isWalkable(x + Const.dirx[i], y + Const.diry[i]))
          return { x: x + Const.dirx[i], y: y + Const.diry[i] };
      return null;
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

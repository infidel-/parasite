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
          case 'block':
            goBlock(arr);
          case 'sound':
            goSound(arr);
          case 'event':
            goEvent(arr);
          case 'xy':
            goXY(arr);
          case '':
            log('Usage: go [area [x] [y]|block [kind]|sound [kind]|event [index]|xy [x] [y]]');
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

// go to a random block of a given kind: go block [kind]
//
// RANDOM AND NOT THE FIRST, which is the whole point of it: a compound has two buildings, a dozen
// labs and four offices — and a tower floor two cubicle farms and three exec rooms — and what this
// is for is looking at ANOTHER one of them. Run it twice and
// you are somewhere else. See console.GoBlock for where the list comes from and what it cannot
// offer — the block tree is not persisted, so this is derived from the saved grid
  function goBlock(arr: Array<String>)
    {
      var all = GoBlock.list(game);
      if (all.length == 0)
        {
          log('No blocks here: `go block` reads a compound\'s or a tower\'s layout off its grid.');
          return;
        }
      if (arr.length < 3)
        {
          log('Usage: go block [kind]. On this map: ' + GoBlock.summary(game) + '.');
          return;
        }
      var kind = arr[2];
      var hits = [for (b in all) if (b.kind == kind) b];
      if (hits.length == 0)
        {
          log('No ' + kind + ' on this map. Try: ' + GoBlock.summary(game) + '.');
          return;
        }
      // NOT THE ONE YOU ARE STANDING IN: run it from inside a room and the roll used to put you
      // back in the same room one time in N, which read as the command doing nothing
      var here = [for (i in 0...hits.length) if (holds(hits[i], game.playerArea.x,
        game.playerArea.y)) i];
      var pick = [for (i in 0...hits.length) if (here.indexOf(i) < 0) i];
      if (pick.length == 0)
        {
          log('You are already in the only ' + kind + ' on this map.');
          return;
        }
      var i = pick[Std.random(pick.length)];
      var b = hits[i];
      var c = b.cells[Std.random(b.cells.length)];
      log('Teleporting to ' + kind + ' ' + (hits.length > 1 ?
        '(' + (i + 1) + ' of ' + hits.length + ') ' : '') + 'at (' + c.x + ',' + c.y + ').');
      game.playerArea.moveTo(c.x, c.y);
      game.scene.updateCamera();
      game.scene.draw();
    }

// go to a random looping sound source of a given kind: go sound [kind]. the sources are the ones
// the 3D view registered for this area (render.SoundSources), so a contiguous run — a rack row, a
// lift — is one source, and it never picks the one the player is already standing at
  function goSound(arr: Array<String>)
    {
      var all = render.SoundSources.sources;
      if (all.length == 0)
        {
          log('No sound sources here.');
          return;
        }
      if (arr.length < 3)
        {
          var census = [for (k in render.SoundSources.kinds())
            k + ' ' + Lambda.count(all, function(s) return render.SoundSources.label(s.key) == k)];
          log('Usage: go sound [kind]. On this map: ' + census.join(', ') + '.');
          return;
        }
      var kind = arr[2];
      var hits = [for (s in all) if (render.SoundSources.label(s.key) == kind) s];
      if (hits.length == 0)
        {
          log('No ' + kind + ' on this map. Try: ' + render.SoundSources.kinds().join(', ') + '.');
          return;
        }
      var px = game.playerArea.x;
      var py = game.playerArea.y;
      var pick = [for (s in hits) if (!Lambda.exists(s.cells, function(c)
        return Math.abs(c.col - px) <= 1 && Math.abs(c.row - py) <= 1)) s];
      if (pick.length == 0)
        {
          log('You are already at the only ' + kind + ' on this map.');
          return;
        }
      var i = Std.random(pick.length);
      // a walkable cell on or touching the source: a rack is solid, a cooler can be stood on
      var spots = [];
      for (c in pick[i].cells)
        for (dy in -1...2)
          for (dx in -1...2)
            if (game.area.isWalkable(c.col + dx, c.row + dy))
              spots.push({ x: c.col + dx, y: c.row + dy });
      if (spots.length == 0)
        {
          log('No standable cell next to that ' + kind + '.');
          return;
        }
      var c = spots[Std.random(spots.length)];
      log('Teleporting to ' + kind + ' ' + (pick.length > 1 ?
        '(' + (i + 1) + ' of ' + pick.length + ') ' : '') + 'at (' + c.x + ',' + c.y + ').');
      game.playerArea.moveTo(c.x, c.y);
      game.scene.updateCamera();
      game.scene.draw();
    }

// does this block hold the cell? its own cells, or one a step off them — a doorway or a furniture
// cell is not in the walkable list but is still standing in the room
  static function holds(b: GoBlock._GoBlock, x: Int, y: Int): Bool
    {
      for (c in b.cells)
        if (Math.abs(c.x - x) + Math.abs(c.y - y) <= 1)
          return true;
      return false;
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

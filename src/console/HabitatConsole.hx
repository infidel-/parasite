// console habitat command helper: builds the habitat's grown objects directly.
// the normal path (game.Habitat.putObject, reached from an organ action) needs a live host, spends
// habitat energy and then KILLS that host, so standing all four up to look at them costs a
// spawn-attach-harden-invade cycle each. this skips every bit of that, which is what art and render
// work on the props actually needs

package console;

import const.*;
import const.EvolutionConst;
import game.Game;
import objects.*;

// one buildable habitat object: what to type, what it grows, and how to make one
typedef HabitatKind = {
  name: String,               // full command word
  alias: String,              // short form
  id: _Improv,                // improvement it belongs to (levels + maxLevel come from here)
  make: Game -> Int -> Int -> Int -> HabitatObject, // (game, x, y, level) -> the object
}

class HabitatConsole
{
  public var console: Console;
  var game: Game;

  // every habitat object there is, in the order `hab all` places them
  static var KINDS: Array<HabitatKind> = [
    {
      name: 'biomineral',
      alias: 'bio',
      id: IMP_BIOMINERAL,
      make: function(g, x, y, l) return new Biomineral(g, g.area.id, x, y, l),
    },
    {
      name: 'assimilation',
      alias: 'cav',
      id: IMP_ASSIMILATION,
      make: function(g, x, y, l) return new AssimilationCavity(g, g.area.id, x, y, l),
    },
    {
      name: 'preservator',
      alias: 'pre',
      id: IMP_PRESERVATOR,
      make: function(g, x, y, l) return new Preservator(g, g.area.id, x, y, l),
    },
    {
      name: 'watcher',
      alias: 'wat',
      id: IMP_WATCHER,
      make: function(g, x, y, l) return new Watcher(g, g.area.id, x, y, l),
    },
  ];

// sets up habitat command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles habitat command routing
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');

      // hab/habitat - list sub-commands
      if (arr.length == 1)
        {
          log('Habitat commands (must be standing in a habitat area):');
          log('hab/habitat all [level] - build one of every habitat object around the player');
          log('hab/habitat biomineral|bio [level] - build a biomineral formation');
          log('hab/habitat assimilation|cav [level] - build an assimilation cavity');
          log('hab/habitat preservator|pre [level] - build a preservator');
          log('hab/habitat watcher|wat [level] - build a watcher');
          log('hab/habitat clear - remove every habitat object in this area');
          return true;
        }

      if (!game.area.isHabitat)
        {
          log('Not in a habitat area.');
          return true;
        }

      // hab clear - remove them all again
      if (arr[1] == 'clear')
        {
          clear();
          return true;
        }

      var level = (arr.length > 2 ? Std.parseInt(arr[2]) : null);

      // hab all - one of each, so the whole set can be looked at in one go
      if (arr[1] == 'all')
        {
          var n = 0;
          for (kind in KINDS)
            if (build(kind, level))
              n++;
          log('Built ' + n + ' habitat object(s).');
          update();
          return true;
        }

      for (kind in KINDS)
        if (arr[1] == kind.name || arr[1] == kind.alias)
          {
            build(kind, level);
            update();
            return true;
          }

      log('Unknown habitat object [' + arr[1] + '].');
      return true;
    }

// builds one object on the nearest free cell, at the given level or the improvement's max
  function build(kind: HabitatKind, level: Null<Int>): Bool
    {
      var info = EvolutionConst.getInfo(kind.id);
      var lvl = (level == null ? info.maxLevel : level);
      if (lvl < 1)
        lvl = 1;
      if (lvl > info.maxLevel)
        lvl = info.maxLevel;

      var pt = freeCell();
      if (pt == null)
        {
          log('No free cell near the player for ' + kind.name + '.');
          return false;
        }

      // the constructor runs init + initPost, and initPost is what adds it to the area — which is
      // also what tells the 3D view to rebuild its object props (game.AreaGame.addObject)
      var o = kind.make(game, pt.x, pt.y, lvl);
      log('Built ' + o.name + ' (level ' + lvl + ') at ' + pt.x + ',' + pt.y + '.');
      return true;
    }

// removes every habitat object in the area
  function clear()
    {
      var list = [];
      for (o in game.area.getObjects())
        if (o.type == 'habitat')
          list.push(o);
      for (o in list)
        game.area.removeObject(o);
      log('Removed ' + list.length + ' habitat object(s).');
      update();
    }

// nearest walkable cell to the player holding nothing and nobody, searched in widening rings so the
// set lands in a readable clump rather than scattered across the level
  function freeCell(): { x: Int, y: Int }
    {
      var px = game.playerArea.x;
      var py = game.playerArea.y;
      for (r in 1...8)
        for (dy in -r...r + 1)
          for (dx in -r...r + 1)
            {
              // ring only: the inner cells were covered by a smaller r
              if (Std.int(Math.max(Math.abs(dx), Math.abs(dy))) != r)
                continue;
              var x = px + dx;
              var y = py + dy;
              if (game.area.isWalkable(x, y) &&
                  !game.area.hasObjectAt(x, y) &&
                  !game.area.hasAI(x, y))
                return { x: x, y: y };
            }

      return null;
    }

// recalc habitat stats and let the area redraw with the new objects in it
  function update()
    {
      if (game.area.habitat != null)
        game.area.habitat.update();
      game.area.updateVisibility();
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}

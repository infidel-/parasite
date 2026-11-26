package render.library;

import game.Game;
import game.AreaGame;
import gen.library.LibraryGen;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;

// the sounds of the library's reading floor (sound/library/*.mp3, see docs/sound-gen.md): a bed per
// room, crossfaded by the room the player stands in; the wall clocks ticking and the Necronomicon's
// drone while it lies on the lectern, faded by path distance in render.AreaSounds; and the building's
// own noises now and then: the stacks' room tone, a shelf settling, a book sliding off one, a
// radiator knocking, a draught in the pages of an open book on a table
class LibrarySounds
{
  // the beds, in bedAt's order: the halls, the corridor and the stacks, the archive, the stair lobby
  static var BEDS = [ 'library/hall', 'library/archive', 'library/lobby' ];

  var game:Game;
  // the area this was built for, never game.area: a restart swaps that for the new game's start
  // area while the view still ticks this one under the fade
  var area:AreaGame;
  var loops:AreaSounds;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;

  // `clocks` are the cells under the wall clocks LibraryWall hung
  public function new(game:Game, clocks:Array<{ col:Int, row:Int }>)
    {
      this.game = game;
      area = game.area;
      var stacks = [];
      var cases = [];
      var tables = [];
      var lectern = [];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (t == Const.TILE_LIB_STACK)
              stacks.push({ col: col, row: row });
            else if (t == Const.TILE_LIB_BOOKCASE)
              cases.push({ col: col, row: row });
            else if (t == Const.TILE_LIB_TABLE)
              tables.push({ col: col, row: row });
            else if (t == Const.TILE_LIB_LECTERN)
              lectern.push({ col: col, row: row });
          }
      loops = new AreaSounds(game, [
        { key: 'library/clock', range: 3, cells: clocks },
        { key: 'library/tome', range: 3, cells: lectern, gate: function(_) return bookOut() },
      ], [
        { key: 'library/creak', range: 5, gap: 45, cells: stacks },
        { key: 'library/thud', range: 6, gap: 90, cells: stacks.concat(cases) },
        { key: 'library/radiator', range: 5, gap: 70, cells: cases },
        { key: 'library/pages', range: 4, gap: 60, cells: tables },
        // the stacks' own clacking room tone, now and then over the halls' muted bed, so it does not
        // loop audibly
        { key: 'library/stacks', range: 6, gap: 60, cells: stacks },
      ]);
      bed = [for (_ in BEDS) 0.0];
      SoundSources.beds = BEDS.copy();
      SoundSources.events = [];
    }

// does the Necronomicon lie on this floor (on the lectern, or dropped), so its drone plays
  function bookOut():Bool
    {
      for (o in area.getObjects())
        if (Std.isOfType(o, objects.Pickup) &&
            (cast o:objects.Pickup).item.id == 'necronomicon')
          return true;
      return false;
    }

// which bed plays at the player's cell, by the room rects the generator saved: a doorway and the
// corridor are in none and take the halls' bed, as the stacks do
  function bedAt(pc:Int, pr:Int):Int
    {
      var room = area.generatorInfo.getRoomAt(pc, pr);
      if (room == null)
        return 0;
      return switch (room.role)
        {
          case LibraryGen.ROLE_ARCHIVE: 1;
          case LibraryGen.ROLE_LOBBY: 2;
          default: 0;
        }
    }

// per frame: the loops and events, then the beds crossfaded over four BASE_MS so a doorway step is
// a fade, never a cut
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var on = bedAt(pc, pr);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
    }
}

// university library generation, the live-game side
//
// the adapter (game.CorpAreaGenerator's pattern): wrap the area's grid in a gen.GenCtx, run
// gen.library.LibraryGen, turn its spawn intents into real objects. See docs/area-gen.md.

package game;

import game.AreaGame;
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.library.LibraryGen;

class LibraryAreaGenerator
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// entry-point for library generation
  public function generate(area: AreaGame)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      // the whole repro: `make gen seeds=1 args="--type library --seed <n> --print"`
      trace('library ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = LibraryGen.build(ctx);
      area.generatorInfo = {
        rooms: state.rooms,
        doors: state.doors,
      };
      area.genTree = ctx.root;
      area.genSeed = ctx.seed;
      GenSpawner.drain(game, area, ctx);
    }

// on every entry: the librarian at its post in the archive when none lives on the floor, and the
// Necronomicon on the lectern until Phase I is complete, ordeal or not, while the book is neither
// held nor already lying on this floor. The ordeal's mission and the secret path share this one spawn
  public static function enter(game: Game, area: AreaGame)
    {
      var cells = area.getCells();
      var post = LibraryGen.librarianPost(cells);
      if (post == null)
        return;
      var keeper = false;
      for (ai in area.getAllAI())
        if (ai.type == 'librarian' &&
            ai.state != AI_STATE_DEAD)
          keeper = true;
      if (!keeper)
        {
          var ai = area.spawnAI('librarian', post.x, post.y);
          ai.isGuard = true;
          ai.guardTargetX = post.x;
          ai.guardTargetY = post.y;
        }

      if (game.cults[0].metamorphosisPhaseIComplete ||
          cult.ordeals.MetamorphosisPhaseI.isHeld(game))
        return;
      for (o in area.getObjects())
        if (Std.isOfType(o, objects.Pickup) &&
            (cast o: objects.Pickup).item.id == 'necronomicon')
          return;
      var l = LibraryGen.lectern(cells);
      area.addItem(l.x, l.y, const.ItemsConst.spawnItem(game, 'necronomicon'), Const.FRAME_BOOK,
        true);
    }
}

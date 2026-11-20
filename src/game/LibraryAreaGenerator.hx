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
}

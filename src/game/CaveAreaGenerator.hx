// mountain cave habitat generation, the live-game side
//
// THE ADAPTER AND NOTHING ELSE, like UndergroundLabAreaGenerator: generation lives in gen.cave so
// the headless oracle can run it. this wraps the live grid in a gen.GenCtx, runs the generator and
// turns its spawn intents (the two cave mouths) into real objects

package game;

import game.AreaGame;
import const.WorldConst;
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.cave.CaveGen;

class CaveAreaGenerator
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// entry-point for cave generation. `info` is unused: game.AreaGenerator dispatches every area type
// through the same signature
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      // the whole repro: `make gen seeds=1 args="--type cave --seed <n> --print"`
      trace('cave ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = CaveGen.build(ctx);
      area.initTilesFromCells();
      area.generatorInfo = {
        rooms: state.rooms,
        doors: [],
      };
      area.genTree = ctx.root;
      area.genSeed = ctx.seed;
      GenSpawner.drain(game, area, ctx);
    }
}

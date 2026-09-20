// corp area generation, the live-game side
//
// THE ADAPTER AND NOTHING ELSE. All of generation moved to gen.corp — see docs/area-gen.md —
// because the generator must not touch a game.Game if tools/genrun.mjs is to run it headless. What
// is left here is the one thing that genuinely needs the live area: wrapping its grid in a
// gen.GenCtx, running the generator, and turning the spawn intents it recorded into real
// AreaObjects.
//
// the class name and package are unchanged on purpose: game.AreaGenerator dispatches through it.

package game;

import const.WorldConst;
import game.AreaGame;
import game.AreaGenerator;
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.corp.CorpGen;

class CorpAreaGenerator
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// entry-point for corp generation.
//
// `info` is unused and has been since this file was written; it stays in the signature because
// game.AreaGenerator.generate dispatches every area type through the same one
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      // every roll below comes off that seed, so this line is the whole repro: `make gen
      // seeds=1 args="--type corp --seed <n> --size <w>x<h> --print"` lays the same floor again
      // with no game running. the SIZE is part of it — game.AreaGame.initPost rolls each axis
      // before we get here
      trace('corp ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = CorpGen.build(ctx);
      area.generatorInfo = {
        rooms: state.rooms,
        doors: state.doors,
      };
      GenSpawner.drain(game, area, ctx);
    }
}

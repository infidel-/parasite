// underground lab generation, the live-game side
//
// THE ADAPTER AND NOTHING ELSE. All of generation moved to gen.lab — see docs/area-gen.md — because
// the generator must not touch a game.Game if tools/genrun.mjs is to run it headless. What is left
// here is wrapping the live grid in a gen.GenCtx, running the generator, handing the mission its
// hints and turning the spawn intents (the lift's four parts, the doors' linked pairs) into real
// AreaObjects.
//
// the class name and package are unchanged on purpose: game.AreaGenerator dispatches through it.

package game;

import game.AreaGame;
import const.WorldConst;
import game.AreaGenerator;
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.lab.LabGen;

class UndergroundLabAreaGenerator
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// entry-point for lab generation. `info` is unused, as it is for the corp floor: game.AreaGenerator
// dispatches every area type through the same signature
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      // the whole repro: `make gen seeds=1 args="--type lab --seed <n> --print"` lays the same level
      // again with no game running
      trace('lab ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = LabGen.build(ctx);
      area.generatorInfo = {
        rooms: state.rooms,
        doors: state.doors,
        // what cult.missions.CombatUndergroundLabPurge reads to stand its four vat groups
        missionHints: {
          vatRoomID: state.vatRoomID,
          vatDoor: state.vatDoor,
          vatAnchors: state.vatAnchors,
          reservedRects: state.reservedRects,
        },
      };
      // and the tree + the seed, for the console's `area room` (transient, see game.AreaGame.genTree)
      area.genTree = ctx.root;
      area.genSeed = ctx.seed;
      GenSpawner.drain(game, area, ctx);
    }
}

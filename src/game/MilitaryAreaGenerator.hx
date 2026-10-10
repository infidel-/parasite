// military base generation, the live half: what still needs a Game
//
// gen.military.MilitaryGen.build lays the base into a gen.GenCtx and records spawn intents; this
// reads the terrain band the margin grows out of (which needs the region), runs it, and drains the
// spawns into real objects. The facility's adapter, game.FacilityAreaGenerator, has the same shape

package game;

import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.military.MilitaryGen;
import map.Terrain;

class MilitaryAreaGenerator
{
// generate a base into this area's grid
  public static function generate(game: Game, area: AreaGame)
    {
      // through regionID rather than game.region: an area can be generated remotely
      var seed = game.world.get(area.regionID).mapSeed;
      var mix = AreaGenerator.wildMix(Terrain.bandAtArea(seed, area.x, area.y));
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      trace('militaryBase ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = MilitaryGen.build(ctx, mix, Terrain.depthAt(seed, area.x, area.y));
      area.generatorInfo = {
        rooms: state.allRooms,
        doors: state.allDoors,
      };
      area.genTree = ctx.root;
      area.genSeed = ctx.seed;
      GenSpawner.drain(game, area, ctx);
    }
}

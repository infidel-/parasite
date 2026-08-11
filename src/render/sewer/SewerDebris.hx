package render.sewer;

import Const;
import citygen.CityGen;
import render.sewer.SewerModel.Sewer;
import render.world.Debris;
import render.world.Debris.DebrisSpot;

// sparse ground litter for the 3D tunnels. render-only and never persisted: the scatter is derived
// from each cell's own coordinate hash, so it is stable across reloads and costs no save space —
// the same contract render.world.Debris gives the city, minus the seed (a sewer has none; its
// SAVED cell grid is the layout). ports the chances of the old SewerAreaGenerator debris pass.
//
// only the ROLL and the cluster SHAPE live here. picking a sprite, its transform and a sub-cell
// offset that stays over walkable ground is render.world.Debris.addFragment, which takes the ground
// test as an argument for exactly this reason — that code was duplicated line for line until it was
// not. named SewerDebris rather than Debris so the two never shadow each other at an import
class SewerDebris
{
// build the litter list for a tunnel model
  public static function build(m:Sewer):Array<DebrisSpot>
    {
      var spots:Array<DebrisSpot> = [];
      var ok = function(col:Int, row:Int):Bool return SewerModel.isFloor(m, col, row);
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.floor[row][col])
              continue;
            var h = hash(col, row);
            // rooms are kept tidier than the tunnels, as in the 2D pass (8 vs 20 per 1000)
            if (h % 1000 >= (m.room[row][col] ? 8 : 20))
              continue;
            var rng = CityGen.mulberry32(h);
            if (rng() < 0.45)
              cluster(spots, ok, col, row, rng);
            else
              Debris.addFragment(spots, col, row, Const.STREET_DEBRIS_STATIC, false, rng, ok);
          }
      return spots;
    }

// a mild transformable pile on this cell plus a chance of one on each orthogonal neighbour.
// tighter than the city's radial scatter on purpose: a corridor is 3 cells wide, so a radius-2
// spray would spend most of its rolls on wall cells
  static function cluster(spots:Array<DebrisSpot>, ok:Int->Int->Bool, col:Int, row:Int, rng:Void->Float):Void
    {
      Debris.spawnCluster(spots, ok, col, row, 1 + Std.int(rng() * 2), rng);
      for (dr in -1...2)
        for (dc in -1...2)
          {
            if ((dc == 0 && dr == 0) ||
                (dc * dc + dr * dr) > 1)
              continue;
            if (rng() >= 0.22 ||
                !ok(col + dc, row + dr))
              continue;
            Debris.spawnCluster(spots, ok, col + dc, row + dr, 1 + Std.int(rng() * 2), rng);
          }
    }

// stable per-cell hash — the same footprint-hash idiom the lamp and wall variants use
  static inline function hash(col:Int, row:Int):Int
    {
      return ((col * 73856093) ^ (row * 19349663)) & 0x7fffffff;
    }
}

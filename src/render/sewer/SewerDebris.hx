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
            // rooms are kept tidier than the tunnels, as in the 2D pass
            if (h % 1000 >= (m.room[row][col] ? SewerStyle.DEBRIS_PCT_ROOM : SewerStyle.DEBRIS_PCT_TUNNEL))
              continue;
            var rng = CityGen.mulberry32(h);
            if (rng() < 0.45)
              cluster(spots, ok, col, row, rng);
            else
              Debris.addFragment(spots, col, row, Const.STREET_DEBRIS_STATIC, false, rng, ok);
          }
      dress(spots);
      return spots;
    }

// second pass over our own spots, fixing two things the shared placer does that read badly on a
// tunnel floor. it runs HERE rather than in render.world.Debris because that one is the city's too
// (and is already at 7 positional args): the streets are seen from much further out, where neither
// matters. no ground test is needed for the jitter — Debris.canPlace only rejects an offset past
// 0.25 of a cell, so anything inside DEBRIS_JITTER is legal by construction
  static function dress(spots:Array<DebrisSpot>):Void
    {
      for (s in spots)
        {
          // a cluster fragment rolls scale 0.1..1.0, and drawn size is 3.0 * contentFraction * scale —
          // so the low end of that roll is a fragment a fifth of a metre across, invisible on a 4-unit
          // cell. clamp rather than rescale, so the spread above the floor is untouched
          if (s.scale < SewerStyle.DEBRIS_MIN_SCALE)
            s.scale = SewerStyle.DEBRIS_MIN_SCALE;
          // a STATIC fragment gets no offset and no rotation at all from addFragment, and static is
          // the half of the litter big enough to actually see — so the visible half was every piece
          // dead-centre in its cell and axis-aligned, which reads as a grid
          if (s.dx == 0.0 &&
              s.dy == 0.0 &&
              s.angle == 0.0)
            {
              var h = SewerModel.mix((s.col * 92837111) ^ (s.row * 689287499));
              s.dx = ((h % 1000) / 1000 - 0.5) * 2 * SewerStyle.DEBRIS_JITTER;
              s.dy = (((h >>> 10) % 1000) / 1000 - 0.5) * 2 * SewerStyle.DEBRIS_JITTER;
              s.angle = ((h >>> 20) % 628) / 100;
            }
        }
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

// stable per-cell hash, run through SewerModel.mix like every other sewer pass. the bare
// (col*A) ^ (row*B) footprint hash this used to be COMBS on row 0 / col 0 — one term goes to zero and
// what is left is an arithmetic sequence, which deals props in a straight line down the area border
  static inline function hash(col:Int, row:Int):Int
    {
      return SewerModel.mix(((col * 73856093) ^ (row * 19349663)) & 0x7fffffff);
    }
}

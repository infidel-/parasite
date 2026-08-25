package render.wild;

import Const;
import citygen.CityGen;
import render.wild.WildModel.Wild;
import render.world.Debris;
import render.world.Debris.DebrisSpot;

// roadside litter for the wilderness — and ONLY roadside. an open area has no litter of its own
// (WildArea.debris returned null until this existed, on the grounds that the grass layer is what
// dresses open ground), so every piece here is a piece somebody threw out of a car.
//
// that makes the gate the interesting part: render.sewer.SewerDebris rolls over every floor cell,
// where this rolls over a BAND either side of the corridor and thins with distance from it. a scatter
// that ignored the road would read as fly-tipping over a whole mountainside.
//
// render-only and never persisted, the same contract the tunnels get: the roll is each cell's own
// coordinate hash, so it is stable across reloads and costs no save space. picking the sprite, its
// transform and a sub-cell offset that stays over legal ground is render.world.Debris.addFragment,
// which takes the ground test as an argument for exactly this reason. named WildDebris so it never
// shadows render.world.Debris at an import
class WildDebris
{
// build the litter list for a wilderness model. empty where no highway crosses the area
  public static function build(m:Wild):Array<DebrisSpot>
    {
      var spots:Array<DebrisSpot> = [];
      if (m.road == null)
        return spots;
      // litter lands on open ground and on the asphalt alike — a verge is where it collects — but
      // never inside a thicket or under a boulder, which is what the prop grid already says
      var ok = function(col:Int, row:Int):Bool
        {
          if (!WildModel.inside(m, col, row))
            return false;
          // the asphalt itself is legal and is where most of it collects. off the road only OPEN
          // ground counts: the prop grid already says which cells hold a bush, a boulder or a
          // thicket, and a crushed can inside a bramble is a can nobody will ever see
          return WildRoad.isRoad(m, col, row) ||
            m.prop[row][col] == -1;
        };
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var d = WildRoad.distTo(m, col, row);
            if (d > WildStyle.LITTER_REACH)
              continue;
            if (!ok(col, row))
              continue;
            var h = WildModel.mix(((col * 73856093) ^ (row * 19349663)) & 0x7fffffff);
            // the chance falls off linearly with distance, so the verge is dirty and the field two
            // dozen paces away is clean. squared would starve the far half before it read as a
            // gradient at all
            var chance = WildStyle.LITTER_PCT * (1.0 - d / WildStyle.LITTER_REACH);
            if (h % 1000 >= chance * 1000)
              continue;
            var rng = CityGen.mulberry32(h);
            if (rng() < 0.35)
              Debris.spawnCluster(spots, ok, col, row, 1 + Std.int(rng() * 2), rng);
            else
              Debris.addFragment(spots, col, row, Const.STREET_DEBRIS_STATIC, false, rng, ok);
          }
      dress(spots);
      return spots;
    }

// the same two fixes render.sewer.SewerDebris makes to the shared placer, and for the same reasons —
// a cluster fragment can roll a scale too small to see, and a STATIC fragment comes back with no
// offset and no rotation at all, which reads as a grid. kept local rather than pushed into
// render.world.Debris because that one is the city's too and is already at 7 positional args
  static function dress(spots:Array<DebrisSpot>):Void
    {
      for (s in spots)
        {
          if (s.scale < WildStyle.LITTER_MIN_SCALE)
            s.scale = WildStyle.LITTER_MIN_SCALE;
          if (s.dx == 0.0 &&
              s.dy == 0.0 &&
              s.angle == 0.0)
            {
              var h = WildModel.mix((s.col * 92837111) ^ (s.row * 689287499));
              s.dx = ((h % 1000) / 1000 - 0.5) * 2 * WildStyle.LITTER_JITTER;
              s.dy = (((h >>> 10) % 1000) / 1000 - 0.5) * 2 * WildStyle.LITTER_JITTER;
              s.angle = ((h >>> 20) % 628) / 100;
            }
        }
    }
}

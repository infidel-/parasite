// where the region map's highway crosses an area (reproduces map.RoadPlan's own ROAD1 line picking)

package map;

import const.WorldConst;

// the two ROAD1 lines a region gets, in PLAN-cell coordinates with the halo included
typedef Road1Lines = {
  // the trunk runs east-west (dx 1) rather than north-south
  primaryHorizontal:Bool,
  // the plan row the trunk sits on, or its plan column when it runs north-south
  primaryLine:Int,
  // the plan column the branch sits on, or its plan row when the trunk runs north-south
  branchLine:Int,
  // which way the branch leaves the trunk, -1 or +1. it runs to that edge and stops
  branchSign:Int,
};

// the highway crossing ONE area, in that area's own fractions
typedef AreaHighway = {
  // the corridor runs east-west across the area
  horizontal:Bool,
  // its centreline, as a fraction 0..1 across the PERPENDICULAR axis
  offset:Float,
};

// map.RoadPlan lays exactly two ROAD1 lines over a region: a trunk running edge to edge, and one
// perpendicular branch leaving it for the nearest edge. Both are dead straight and one plan cell
// wide (see RoadPlan.walkRoad1), and ROAD1 is order 0 — the strongest tier — so nothing ever
// overwrites them. That makes the whole highway describable as four numbers, which is why area
// generation can have it without the region map existing.
//
// and it does not exist: the plan grid lives on the map.Image at RegionGame.regionMapImage, which is
// in that class's _ignoredFields (never saved) and is constructed lazily on the first region-map
// VIEW. Generating one allocates seventeen 832x832 grids and is timed in a trace of its own, so it
// is not something area generation can reach for.
//
// this is map.Terrain's play a second time, with one difference: Terrain DUPLICATED the renderer's
// literals, and this EXTRACTS the decision, so RoadPlan calls lines() too and there is one source of
// truth. RoadPlan hands in its own rng, so the shared draw sequence is byte-for-byte what it was —
// nextFloat, next, next, nextFloat, in that order. A headless caller hands in a fresh
// SeededRandom(mapSeed), which is the same state: Core.initRandom seeds it and nothing between there
// and the ROAD1 block draws from it (paintGround hashes, and paintGrainOverlay's 16k draws come
// after the roads).
class Highway
{
  // plan cells per region tile.
  // ponytail: the one literal duplicated from map.Core, where it is an instance var reached as
  // `plan.PLAN_CELLS_PER_TILE` from ~40 sites — making it a public static would be a rename of all
  // of them for one caller. Same trade map.Terrain's header spells out
  static inline var CELLS_PER_TILE = 8;

// the region's two ROAD1 lines. the DRAW ORDER is the contract: RoadPlan used to interleave the
// walker builders between these four draws, and the builders take none, so hoisting them here leaves
// the sequence identical
  public static function lines(o:HighwayOpts):Road1Lines
    {
      var primaryHorizontal = o.rng.nextFloat() < 0.5;
      var primaryLine = pick(o, primaryHorizontal, 10, 4, 'road1.primary');
      // the branch runs across the trunk, so it is picked on the OTHER axis, with a tighter jitter
      var branchLine = pick(o, !primaryHorizontal, 12, 3, 'road1.branch');
      return {
        primaryHorizontal: primaryHorizontal,
        primaryLine: primaryLine,
        branchLine: branchLine,
        branchSign: (o.rng.nextFloat() < 0.5 ? -1 : 1),
      };
    }

// the corridor crossing one area, or null where the highway misses it.
//
// takes REGION coordinates and adds the halo itself, which is map.Terrain.bandAtArea's contract and
// deliberately NOT RoadPlanGridOps.hasRoadTypeInRegionTile's — that one takes full-cell coordinates
// and leaves the halo to its caller, and every call site adds it by hand. Getting that wrong does not
// throw, it silently answers about the tile two up and two left, which is exactly the ~40% band
// disagreement Terrain's header records
  public static function atArea(region:game.RegionGame, x:Int, y:Int):AreaHighway
    {
      var cells = region.getCells();
      var rw = region.width;
      var rh = region.height;
      var l = lines({
        rng: new SeededRandom(region.mapSeed),
        planWidth: (rw + Core.HALO_CELLS * 2) * CELLS_PER_TILE,
        planHeight: (rh + Core.HALO_CELLS * 2) * CELLS_PER_TILE,
        cellsPerTile: CELLS_PER_TILE,
        // RoadPlan reads this off its halo-expanded areaTypes field, which is the region's own cell
        // types clamped outward into the halo (map.Ground.buildAreaTypeField) — so the clamp here
        // reproduces it rather than approximating it
        blocked: function(px, py)
          {
            var cx = clampInt(Std.int(px / CELLS_PER_TILE) - Core.HALO_CELLS, 0, rw - 1);
            var cy = clampInt(Std.int(py / CELLS_PER_TILE) - Core.HALO_CELLS, 0, rh - 1);
            return WorldConst.blocksRegionRoad1(cells[cx][cy].typeID);
          },
      });
      // the TRUNK crosses every tile on its line: walkRoad1 starts at plan 0 and runs to the far edge
      var trunkTile = Std.int(l.primaryLine / CELLS_PER_TILE) - Core.HALO_CELLS;
      if (trunkTile == (l.primaryHorizontal ? y : x))
        return {
          horizontal: l.primaryHorizontal,
          offset: frac(l.primaryLine),
        };
      // the BRANCH only covers the tiles on its own side of the trunk, and runs across it, so an
      // east-west trunk throws a north-south branch
      var branchTile = Std.int(l.branchLine / CELLS_PER_TILE) - Core.HALO_CELLS;
      var along = (l.primaryHorizontal ? y : x);
      if (branchTile == (l.primaryHorizontal ? x : y) &&
          (l.branchSign < 0 ? along <= trunkTile : along >= trunkTile))
        return {
          horizontal: !l.primaryHorizontal,
          offset: frac(l.branchLine),
        };
      return null;
    }

// the centreline of a plan line within its own region tile, as a fraction. this is why an area does
// not roll its own offset: every area along the highway reads the same plan line, so the corridor
// leaves one area exactly where it enters the next
  static inline function frac(planLine:Int):Float
    {
      return (planLine % CELLS_PER_TILE + 0.5) / CELLS_PER_TILE;
    }

// the nearest centred plan line that crosses no blocked area, falling back to the least bad one.
// `div` and `minJit` are the two jitter constants RoadPlan used, which differ between the trunk and
// the branch and are the only thing that did
  static function pick(o:HighwayOpts, horizontal:Bool, div:Int, minJit:Int, label:String):Int
    {
      var limit = (horizontal ? o.planHeight : o.planWidth);
      var jitter = clampInt(Std.int(limit / div), minJit, o.cellsPerTile * 2);
      var target = clampInt(Std.int(limit / 2) + randomRangeInt(o.rng, -jitter, jitter),
        1, limit - 2);
      var bestLine = target;
      var bestHits = hits(o, horizontal, target);
      var bestOffset = 0;

      if (bestHits == 0)
        return target;

      for (offset in 1...limit)
        {
          var lowerLine = target - offset;
          if (lowerLine >= 1)
            {
              var lowerHits = hits(o, horizontal, lowerLine);
              if (lowerHits == 0)
                {
                  count(o, label + '.blockedAreaRerolls', 1);
                  count(o, label + '.shiftCells', offset);
                  return lowerLine;
                }
              if (lowerHits < bestHits ||
                  (lowerHits == bestHits &&
                  offset < bestOffset))
                {
                  bestLine = lowerLine;
                  bestHits = lowerHits;
                  bestOffset = offset;
                }
            }

          var upperLine = target + offset;
          if (upperLine <= limit - 2)
            {
              var upperHits = hits(o, horizontal, upperLine);
              if (upperHits == 0)
                {
                  count(o, label + '.blockedAreaRerolls', 1);
                  count(o, label + '.shiftCells', offset);
                  return upperLine;
                }
              if (upperHits < bestHits ||
                  (upperHits == bestHits &&
                  offset < bestOffset))
                {
                  bestLine = upperLine;
                  bestHits = upperHits;
                  bestOffset = offset;
                }
            }
        }

      count(o, label + '.fallbacks', 1);
      count(o, label + '.fallbackBlockedAreaCells', bestHits);
      return bestLine;
    }

// how many blocked-area plan cells a 3-cell-wide line would cross
  static function hits(o:HighwayOpts, horizontal:Bool, line:Int):Int
    {
      var hitCount = 0;

      if (horizontal)
        {
          var minY = clampInt(line - 1, 0, o.planHeight - 1);
          var maxY = clampInt(line + 1, 0, o.planHeight - 1);

          for (xx in 0...o.planWidth)
            for (yy in minY...maxY + 1)
              if (o.blocked(xx, yy))
                hitCount++;
          return hitCount;
        }

      var minX = clampInt(line - 1, 0, o.planWidth - 1);
      var maxX = clampInt(line + 1, 0, o.planWidth - 1);

      for (yy in 0...o.planHeight)
        for (xx in minX...maxX + 1)
          if (o.blocked(xx, yy))
            hitCount++;
      return hitCount;
    }

// bump a debug counter, where the caller kept one
  static inline function count(o:HighwayOpts, label:String, amount:Int):Void
    {
      if (o.count != null)
        o.count(label, amount);
    }

// an inclusive random integer, matching map.Core.randomRangeInt exactly — it draws next() and not
// nextFloat(), and swapping the two would shift every road below ROAD1 on every existing map
  static inline function randomRangeInt(rng:SeededRandom, min:Int, max:Int):Int
    {
      if (max <= min)
        return min;
      return min + rng.next() % (max - min + 1);
    }

// clamp an int to bounds
  static inline function clampInt(v:Int, min:Int, max:Int):Int
    {
      return (v < min ? min : (v > max ? max : v));
    }
}

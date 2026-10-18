// the compound's park
//
// a path through it, benches down that path, and greenery in CLUMPS. Moved out of
// game.FacilityAreaGenerator whole; the signature is still (state, x, y, w, h) rather than a tree
// filler, which is the one thing Phase 4 changes when the block tree starts driving it.

package gen.blocks;

import game.AreaGenerator.*;
import gen.facility._FacilityState;
import gen.facility.FacilityTemp.*;

class ParkBlock
{
  // how wide the path is, how far apart the benches down it sit, how far apart the clump centres are
  // laid, and how far one clump reaches (both in cells, the second Manhattan). the step is what sets
  // DENSITY — clump count goes as its inverse square, so 6 -> 4 is 2.25x the centres
  public static inline var PARK_PATH_W = 2;
  public static inline var PARK_BENCH_SPACING = 5;
  public static inline var PARK_CLUMP_STEP = 4;
  public static inline var PARK_CLUMP_R = 3;
  // one shrub every this many cells along the park's outer edge, under the railing
  public static inline var PARK_EDGE_BUSH_SPACING = 3;

// lay the park out inside its own rect: a path through it, benches down that path, and greenery in
// CLUMPS rather than the flat per-cell roll this used to be (10% tree / 30% bush everywhere, which
// gave an even scrub with no shape and left 40% of the lawn unwalkable).
//
// the path is written as plain WALKWAY and that is the whole trick: it costs nothing here and the
// render layer already knows what to do with it. render.facility.FacilityGround kerbs any pavement
// edge that steps down, and render.facility.FacilityLamps' lit-line table already has a row for
// grass bordering a walkway, so the path arrives edged and lit with no code on either side
  public static function generatePark(state: _FacilityState, gx: Int, gy: Int, gw: Int, gh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // down the park's LONG axis, and two cells wide so it reads as a path and not as a seam
      var vertical = (gh >= gw);
      var px = (vertical ? gx + Std.int((gw - PARK_PATH_W) / 2) : gx);
      var py = (vertical ? gy : gy + Std.int((gh - PARK_PATH_W) / 2));
      drawBlock(cells, px, py, (vertical ? PARK_PATH_W : gw), (vertical ? gh : PARK_PATH_W),
        TEMP_WALKWAY);

      // benches, alternating sides on the way down, each on the grass cell against the path's kerb.
      // they finalize to Const.TILE_GRASS_UNWALKABLE, which the renderer MUST draw something for —
      // a green cell with no prop on it is a wall the player cannot see
      var len = (vertical ? gh : gw);
      var i = PARK_BENCH_SPACING;
      while (i < len - 1)
        {
          var side = (Std.int(i / PARK_BENCH_SPACING) % 2 == 0 ? -1 : PARK_PATH_W);
          var bx = (vertical ? px + side : gx + i);
          var by = (vertical ? gy + i : py + side);
          if (cells[bx][by] == TEMP_GRASS)
            cells[bx][by] = TEMP_GRASS_BENCH;
          i += PARK_BENCH_SPACING;
        }

      // an even line of shrubs round the OUTSIDE of the lawn, which is what the railing reads
      // against: render.facility.FacilityGround.fence stands one segment per rim edge, and a bare
      // strip of turf behind a railing looks like a fence in a field. the gate is on (x + y), which
      // on a rim run has one coordinate fixed and so steps evenly along it — the diagonal it would
      // step on elsewhere never arises here. only lawn is overwritten, so the two cells where the
      // path crosses the rim stay open
      for (y in gy...gy + gh)
        for (x in gx...gx + gw)
          {
            if (x != gx &&
                y != gy &&
                x != gx + gw - 1 &&
                y != gy + gh - 1)
              continue;
            if ((x + y) % PARK_EDGE_BUSH_SPACING != 0 ||
                cells[x][y] != TEMP_GRASS)
              continue;
            cells[x][y] = TEMP_GRASS_BUSH;
          }

      // and the planting: a centre TREE every PARK_CLUMP_STEP cells on a lattice, jittered a cell
      // off its node, with a clump grown around each one.
      //
      // the lattice is the whole point and it replaces four centres drawn UNIFORM over the rect.
      // uniform is what left whole bands of the lawn bare, and not by bad luck: measured over 2000
      // runs of the old code on a real 12x25 park, 29% of park ROWS came back with nothing on them
      // at all and the average longest unbroken bare band was 5.8 rows out of 25, with a tail out
      // to 19. four samples cannot cover a rect, however far each one reaches
      var y = gy + Std.int(PARK_CLUMP_STEP / 2);
      while (y < gy + gh)
        {
          var x = gx + Std.int(PARK_CLUMP_STEP / 2);
          while (x < gx + gw)
            {
              plantClump(state, x + area.random(3) - 1, y + area.random(3) - 1, gx, gy, gw, gh);
              x += PARK_CLUMP_STEP;
            }
          y += PARK_CLUMP_STEP;
        }
    }

// grow one clump of planting around a centre: a tree ON the centre, trees or bushes through its
// core, bushes thinning out to PARK_CLUMP_R, open lawn past that. distance is Manhattan, so a clump
// is a diamond and no two of them tile into a hedge.
//
// only TEMP_GRASS is ever overwritten, which is what keeps the path, the benches and any clump
// already grown beside this one intact — the passes are ordered and this one runs last
  static function plantClump(state: _FacilityState, cx: Int, cy: Int,
      gx: Int, gy: Int, gw: Int, gh: Int)
    {
      var cells = state.area.getCells();
      for (y in cy - PARK_CLUMP_R...cy + PARK_CLUMP_R + 1)
        for (x in cx - PARK_CLUMP_R...cx + PARK_CLUMP_R + 1)
          {
            if (x < gx ||
                y < gy ||
                x >= gx + gw ||
                y >= gy + gh ||
                cells[x][y] != TEMP_GRASS)
              continue;
            var d = Std.int(Math.abs(x - cx) + Math.abs(y - cy));
            var rnd = state.area.random(100);
            // the tree zone is d < R and not the d * 2 <= R it started as, which is what doubled the
            // trees without touching the bushes. a Manhattan diamond of radius 3 holds 1 / 4 / 8 / 12
            // cells at d = 0..3, so the old core was 5 cells and the new one is 13 — trees go from
            // 1 + 4 * 0.55 = 3.2 per clump to 1 + 12 * 0.55 = 7.6, while the bush count is unmoved at
            // 10.8 either way (12 * 0.45 in the core plus 12 * 0.45 in the skirt, against 4 * 0.45
            // plus 20 * 0.45 before). the skirt is now the single outermost ring
            if (d == 0)
              cells[x][y] = TEMP_GRASS_TREE;
            else if (d < PARK_CLUMP_R)
              cells[x][y] = (rnd < 55 ? TEMP_GRASS_TREE : TEMP_GRASS_BUSH);
            else if (d == PARK_CLUMP_R && rnd < 45)
              cells[x][y] = TEMP_GRASS_BUSH;
          }
    }
}

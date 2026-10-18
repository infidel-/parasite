// which bays of the compound's car park hold a car, stamped on the grid
//
// THE RENDERER USED TO DECIDE THIS AND NOTHING WAS PERSISTED, which was the right answer while a car
// was decoration: render.facility.FacilityCars deals every whole bay off the saved tile grid, ranks
// them by distance from the gate's mouth, takes the nearest few and rolls one in CAR_EMPTY empty.
// Nothing about that is wrong except its conclusion — a car the player walks straight through is not
// a car — so the DEAL moved here and the renderer reads the marks back. It is the boom barrier's own
// move (gen.facility.FacilityTemp.TEMP_BARRIER) for the boom barrier's own reason, and like the boom
// it costs no new art: both marks alias to the alley's asphalt (tiles.Default.getIcon).
//
// THE BAY RHYTHM IS FacilityPaint's AND IS COPIED RATHER THAN SHARED, and that is a real cost worth
// stating. The phase comes off `runStart` below, which is render.facility.FacilityPaint.runStart
// rewritten against the TEMP alphabet — the paint is render-side and this is not, and neither can
// reach the other. What a divergence would cost is only cosmetic now: the renderer finds a car by its
// ORIGIN mark and not by re-deriving the phase, so a bay one cell out of step would stand a car
// across a painted divider rather than making it vanish. GenCheck asserts the shape of every mark
// instead, which is the half of this that can be checked without a renderer.
//
// STRICTER THAN THE RENDERER WAS on one point, deliberately: a bay's cells must all be TEMP_PARKING,
// where the render pass asked only for Surf.LOT. Surf.LOT is every piece of open asphalt in the
// compound — the yard, the gaps between plots, the gateway — so the old test let a bay hang half out
// of the car park it was dealt in.

package gen.facility;

import Const;
import gen.facility.FacilityTemp.*;

class FacilityBays
{
  // one bay: SPACING cells along the kerb by DEPTH away from it, which is the rect
  // render.facility.FacilityPaint.bayLine strikes and the footprint FacilityStyle.CAR_H is sized for.
  // render.facility.FacilityStyle.BAY_SPACING and BAY_CELLS are these
  public static inline var SPACING = 2;
  public static inline var DEPTH = 2;
  // how many of the bays nearest the mouth get a car. NEAREST FIRST is the whole placement rule: a
  // compound deals dozens of bays and a lot parked solid reads as a showroom, while the spots by the
  // barrier are the ones a camera following the player through the entry actually looks at
  public static inline var CARS = 5;
  // and one bay in EMPTY is left open. There is ONE car model, so a solid run of them is one car
  // repeated
  public static inline var EMPTY = 3;

  // the four cell-edge directions in render.facility.FacilityGeom's numbering, which is what makes
  // `dir < 2` mean "the kerb runs along the column axis" here as well. `dir ^ 1` is the opposite of a
  // direction, which is how a bay marches away from the kerb it hangs off
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// stamp the cars. no boom row means no gateway to rank the bays from and nothing is marked
  public static function cars(state: _FacilityState)
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      // the gateway, read off the boom's own row: TEMP_BARRIER is one row of the ENTRYWAY rect and
      // the only place it is ever written, so its bounding box IS the mouth
      var x0 = -1;
      var x1 = -1;
      var brow = -1;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (cells[x][y] != TEMP_BARRIER)
              continue;
            if (x0 < 0 ||
                x < x0)
              x0 = x;
            if (x > x1)
              x1 = x;
            brow = y;
          }
      if (x0 < 0)
        return;
      // the lot lies on the far side of that row from the road, and the booth stands on the bay off
      // the mouth's low-column flank — render.facility.FacilityEntry.find's own arithmetic
      var dr = (state.mainRoadNorth ? 1 : -1);
      var mouthRow = brow + dr;
      var boothCol = x0 - 1;
      var gx = (x0 + x1) / 2.0;
      var bays = [];
      for (row in 0...ctx.height)
        for (col in 0...ctx.width)
          {
            if (cells[col][row] != TEMP_PARKING)
              continue;
            // the FIRST pavement this cell finds, so a cell in a corner belongs to one run only —
            // the same claim the paint makes when it stripes it
            for (dir in 0...4)
              {
                if (mark(cells, ctx, col + DC[dir], row + DR[dir]) != TEMP_WALKWAY)
                  continue;
                if (((dir < 2 ? col : row) - runStart(cells, ctx, col, row, dir)) % SPACING == 0 &&
                    whole(cells, ctx, col, row, dir, boothCol, mouthRow))
                  bays.push({
                    col: col,
                    row: row,
                    dir: dir,
                    d: (col - gx) * (col - gx) + (row - mouthRow) * (row - mouthRow),
                  });
                break;
              }
          }
      bays.sort(function(a, b) return (a.d < b.d ? -1 : (a.d > b.d ? 1 : 0)));
      var n = 0;
      for (b in bays)
        {
          if (n >= CARS)
            break;
          // ASKED A SECOND TIME, and not for tidiness: two bays can overlap. A cell claims the FIRST
          // kerb it finds, so on a lot two cells deep with pavement on both sides each row deals its
          // own bay over the same rect, and at a corner the two runs meeting there do the same. The
          // marks laid below are no longer TEMP_PARKING, so re-asking is what makes the first bay
          // dealt the one that keeps the ground — measured before this line went in as 18 marked
          // cells where five whole bays are 20
          if (!whole(cells, ctx, b.col, b.row, b.dir, boothCol, mouthRow))
            continue;
          if (ctx.chance(Std.int(100 / EMPTY)))
            continue;
          stamp(cells, b.col, b.row, b.dir);
          n++;
        }
    }

// the mark on a cell, or -1 off the grid
  static inline function mark(cells: Array<Array<Int>>, ctx: GenCtx, col: Int, row: Int): Int
    {
      return (col < 0 || row < 0 || col >= ctx.width || row >= ctx.height
        ? -1 : cells[col][row]);
    }

// is this cell a piece of open asphalt? every temp mark that finalizes to a tile
// render.facility.FacilityModel.surfOf answers Surf.LOT for — the lot, the yard, the gateway and the
// boom's row. it is what `runStart` walks along, so the phase matches the paint's on a kerb that runs
// past the end of the car park
  static inline function isLot(cells: Array<Array<Int>>, ctx: GenCtx, col: Int, row: Int): Bool
    {
      var t = mark(cells, ctx, col, row);
      return t == TEMP_ALLEY ||
        t == TEMP_PARKING ||
        t == TEMP_BARRIER;
    }

// the coordinate along the kerb where this cell's bay run BEGINS — walk back while the cells keep
// their pavement on the same side. render.facility.FacilityPaint.runStart, against the temp alphabet
  static function runStart(cells: Array<Array<Int>>, ctx: GenCtx, col: Int, row: Int,
      dir: Int): Int
    {
      var dc = (dir < 2 ? -1 : 0);
      var dr = (dir < 2 ? 0 : -1);
      while (isLot(cells, ctx, col + dc, row + dr) &&
             mark(cells, ctx, col + dc + DC[dir], row + dr + DR[dir]) == TEMP_WALKWAY)
        {
          col += dc;
          row += dr;
        }
      return (dir < 2 ? col : row);
    }

// is the whole bay this cell opens free car park? the gate mouth is the way in and never a spot (its
// cells are TEMP_ALLEY, so that falls out), and the booth stands on the one bay the paint already
// leaves unstriped for it
  static function whole(cells: Array<Array<Int>>, ctx: GenCtx, col: Int, row: Int, dir: Int,
      boothCol: Int, mouthRow: Int): Bool
    {
      var ac = (dir < 2 ? 1 : 0);
      var ar = (dir < 2 ? 0 : 1);
      for (a in 0...SPACING)
        for (i in 0...DEPTH)
          {
            var c = col + ac * a + DC[dir ^ 1] * i;
            var r = row + ar * a + DR[dir ^ 1] * i;
            if (mark(cells, ctx, c, r) != TEMP_PARKING ||
                (c == boothCol && r == mouthRow))
              return false;
          }
      return true;
    }

// one car's footprint: the whole bay, with its low corner against the kerb carrying the ORIGIN mark
// the renderer stands the model on
  static function stamp(cells: Array<Array<Int>>, col: Int, row: Int, dir: Int)
    {
      var ac = (dir < 2 ? 1 : 0);
      var ar = (dir < 2 ? 0 : 1);
      for (a in 0...SPACING)
        for (i in 0...DEPTH)
          cells[col + ac * a + DC[dir ^ 1] * i][row + ar * a + DR[dir ^ 1] * i] = TEMP_CAR;
      cells[col][row] = TEMP_CAR_ORIGIN;
    }
}

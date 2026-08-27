package render.wild;

import game.AreaGame;

// what the 3D wilderness builder needs, derived from an area's SAVED cell grid. there is no seeded
// wilderness generator worth reading here: game.AreaGenerator.generateWilderness scatters
// TILE_TREE1..4 / TILE_ROCK / TILE_BUSH over TILE_GRASS and those persisted cells ARE the layout, so
// this works on every existing save and costs nothing to store. grids are [row][col] (the render
// convention, transposed from the game's [x][y]) so they index like citygen's tile grid
typedef Wild = {
  // area width in cells
  w:Int,
  // area height in cells
  h:Int,
  // [row][col]: index into WildStyle.PROPS, -1 where the cell carries no prop, or OCCUPIED
  prop:Array<Array<Int>>,
  // top-left cell of each 2x2 large rock. the only prop out here that is not per-cell, so the rect has
  // to be recovered somewhere and this is it — generation leaves a one-cell margin around every one of
  // them (AreaGenerator.isBigObstacleClear), which is what makes "no rock left of me and none above
  // me" name each rect exactly once
  rocks:Array<{ col:Int, row:Int }>,
  // every cell of every tree thicket. no rect needed here: a thicket is grown cell by cell out of the
  // band's own models, so the list is only so the understorey pass does not rescan the grid
  thicket:Array<{ col:Int, row:Int }>,
  // the highway corridor, or null where no road crosses this area
  road:WildRoadRect,
};

// the highway corridor, in CELL units, recovered from the TILE_ROAD cells rather than persisted
// alongside them — the same trick `rocks` plays with its 2x2 rects, and it works for the same reason:
// game.AreaGenerator.placeHighway lays a straight full-span band, so the shape is implied by the cells
typedef WildRoadRect = {
  // the corridor runs east-west across the area
  alongX:Bool,
  // its centreline, in cell-edge units on the PERPENDICULAR axis
  centre:Float,
  // half its width, in cells
  half:Float,
};

class WildModel
{
  // a cell covered by something drawn from somewhere else: no prop of its own, but no grass and no
  // loose stones either. render.wild.WildGrass and WildProps.small therefore test against -1 rather
  // than against 0, and WildProps.places skips anything negative as it always did.
  //
  // it means two things now — a cell under a 2x2 boulder, and a cell of highway. neither wants a
  // suppression test of its own, which is the whole point of the sentinel being about COVERAGE rather
  // than about which feature did the covering
  public static inline var OCCUPIED = -2;

// build the model from an area's saved cells
  public static function fromArea(area:AreaGame):Wild
    {
      var m = blank(area.width, area.height);
      // the corridor's bounding box, grown as the scan meets road cells
      var minCol = area.width;
      var maxCol = -1;
      var minRow = area.height;
      var maxRow = -1;
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var t = area.getCellType(x, y);
            // one bush TILE, several bush MODELS, and which ones is the BAND's call
            // (render.wild.WildBand holds the weighted list). unlike the trees below there is no
            // per-cell variant in the saved grid to honour, so the pick is hashed off the cell —
            // deterministic, so a bush is the same one on every re-entry, and with its own multipliers
            // so which cells take the bramble does not correlate with the rock split
            if (t == Const.TILE_BUSH)
              m.prop[y][x] = WildBand.pick(WildBand.cur.bushes, mix((x * 20011) ^ (y * 40009)));
            // the four tree tiles map ONE TO ONE onto four tree models, which is what those tile IDs
            // were always for: the 2D generator already rolls a variant per cell
            // (AreaGenerator.generateWilderness deals TILE_TREE1 + Std.random(4)), so honouring it
            // keeps the 3D area showing the same stand of trees the tile grid always described, and
            // the same one on every re-entry, for free. the BAND decides which four models those four
            // IDs mean — a forest tile that says "variant 3" is a broadleaf in leaf where a mountain
            // one is a dead snag — so the mapping is a per-band table rather than an offset now
            else if (t >= Const.TILE_TREE1 &&
                t < Const.TILE_TREE1 + 4)
              m.prop[y][x] = WildBand.cur.trees[t - Const.TILE_TREE1];
            else if (t == Const.TILE_ROCK)
              m.prop[y][x] = WildBand.pick(WildBand.cur.rocks, mix((x * 30011) ^ (y * 50021)));
            // the 2x2 boulder: every cell of it is covered, and only the top-left one draws
            else if (t == Const.TILE_ROCK_LARGE)
              {
                m.prop[y][x] = OCCUPIED;
                if (area.getCellType(x - 1, y) != t &&
                    area.getCellType(x, y - 1) != t)
                  m.rocks.push({ col: x, row: y });
              }
            // a thicket cell gets a REAL tree index rather than OCCUPIED, which does three jobs with
            // one line: the scatter below plants the tree with the yaw and scale spread it already
            // deals, and the cell loses its grass and its loose stones the same way any prop cell does
            else if (t == Const.TILE_TREE_CLUSTER)
              {
                m.prop[y][x] = WildBand.pick(WildBand.cur.trees, mix((x * 60013) ^ (y * 70001)));
                m.thicket.push({ col: x, row: y });
              }
            // the highway. OCCUPIED for the same reason a boulder's cells are: the asphalt is drawn by
            // render.wild.WildRoad, and grass and pebbles must not grow through it
            else if (t == Const.TILE_ROAD)
              {
                m.prop[y][x] = OCCUPIED;
                if (x < minCol)
                  minCol = x;
                if (x > maxCol)
                  maxCol = x;
                if (y < minRow)
                  minRow = y;
                if (y > maxRow)
                  maxRow = y;
              }
          }
      m.road = recoverRoad(minCol, maxCol, minRow, maxRow);
      return m;
    }

// turn the road cells' bounding box back into a corridor. the band spans the whole grid on the axis it
// runs along, so whichever span is the longer names that axis and the other one gives the centreline
// and the width. no tie is possible in practice — the corridor is 3 cells wide against a 90-100 cell
// grid — and a square box would mean the generator wrote something this cannot describe anyway
  static function recoverRoad(minCol:Int, maxCol:Int, minRow:Int, maxRow:Int):WildRoadRect
    {
      if (maxCol < 0)
        return null;
      var colSpan = maxCol - minCol + 1;
      var rowSpan = maxRow - minRow + 1;
      var alongX = colSpan > rowSpan;
      var lo = (alongX ? minRow : minCol);
      var hi = (alongX ? maxRow : maxCol);
      return {
        alongX: alongX,
        centre: (lo + hi + 1) / 2.0,
        half: (hi - lo + 1) / 2.0,
      };
    }

// an empty model of the given size (also the base for demo())
  static function blank(w:Int, h:Int):Wild
    {
      return {
        w: w,
        h: h,
        prop: [for (_ in 0...h) [for (_ in 0...w) -1]],
        rocks: [],
        thicket: [],
        road: null,
      };
    }

// is (col,row) inside the grid?
  public static inline function inside(m:Wild, col:Int, row:Int):Bool
    {
      return col >= 0 &&
        row >= 0 &&
        col < m.w &&
        row < m.h;
    }

// xorshift32 avalanche over a cell hash, for every deterministic placement decision out here. the
// same function render.sewer.SewerModel.mix is, and called through it rather than copied: its header
// carries the measurement that justifies it (the bare `(col * A) ^ (row * B)` hash collapses to an
// arithmetic sequence on row 0 and column 0, where one term is zero, and deals runs of eight)
  public static inline function mix(h:Int):Int
    {
      return render.sewer.SewerModel.mix(h);
    }
}

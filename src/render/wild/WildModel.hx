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
  // [row][col]: index into WildStyle.PROPS, or -1 where the cell carries no prop
  prop:Array<Array<Int>>,
};

class WildModel
{
// build the model from an area's saved cells
  public static function fromArea(area:AreaGame):Wild
    {
      var m = blank(area.width, area.height);
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
          }
      return m;
    }

// an empty model of the given size (also the base for demo())
  static function blank(w:Int, h:Int):Wild
    {
      return {
        w: w,
        h: h,
        prop: [for (_ in 0...h) [for (_ in 0...w) -1]],
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

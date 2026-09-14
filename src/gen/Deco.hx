// deals decorations by PLACE: a mount (what it stands on) and a block (what room it is in).
//
// this is the whole of the selection rule. `Const.highFittings()` and `Const.officeFittings()` used
// to be it — two hardcoded lists, the second a literal `kind == FIT_BOOKCASE || ...` — so adding a
// decoration meant editing a filter as well as the table, and a new room role meant a third list.
// Now the table says where each entry belongs and this asks it.
//
// NOTHING HERE TOUCHES A Game: it reads Const and rolls off the GenCtx, so tools/genrun.mjs runs it
// headless like the rest of gen/.

package gen;

import Const;

class Deco
{
  // what a decoration stands on
  public static inline var MOUNT_FLOOR_HIGH = 'floor-high';
  public static inline var MOUNT_FLOOR_LOW = 'floor-low';
  // and the blocks it may stand in. the two named ones are _Room.role verbatim
  // (gen.facility.FacilityTemp.ROLE_CABINET / ROLE_TOILET); a null role is a laboratory
  public static inline var BLOCK_LAB = 'lab';

// every decoration that may appear on this mount in this block, IN TABLE ORDER — the order is part
// of the seeded stream, so do not sort it
  public static function places(mount: String, block: String): Array<_DecoPlace>
    {
      return [for (p in Const.FACILITY_DECO)
        if (p.mount.indexOf(mount) >= 0 &&
            p.blocks.indexOf(block) >= 0) p];
    }

// roll one decoration for this place and return the atlas frame to draw it with: an entry first,
// then one of that entry's own frames. Two rolls and not one flat roll over every matching frame,
// because a KIND is what the player reads — a machine casing carrying five icons must not turn up
// two and a half times as often as the shelving carrying two
  public static function pick(ctx: GenCtx, mount: String, block: String): _FittingFrame
    {
      var list = places(mount, block);
      if (list.length == 0)
        throw 'Deco.pick: nothing is placed on "' + mount + '" in a "' + block + '"';
      var p = list[ctx.random(list.length)];
      return p.frames[ctx.random(p.frames.length)];
    }

// the table's own invariants, run once by gen.GenRun so `make gen` is the check:
//
//   * every frame appears on ONE entry only, or Const.fittingOf stops being a function and a saved
//     decoration resolves to whichever kind the table happens to list first
//   * every (mount, block) pair the facility actually asks for deals something
  public static function selfCheck()
    {
      var seen = new Map<Int, String>();
      for (p in Const.FACILITY_DECO)
        for (fr in p.frames)
          {
            var key = fr.row * 100 + fr.col;
            if (seen.exists(key))
              throw 'Deco: frame ' + fr.row + '/' + fr.col + ' is on both "' +
                seen.get(key) + '" and "' + p.id + '"';
            seen.set(key, p.id);
          }
      for (block in [ BLOCK_LAB, 'cabinet', 'toilet' ])
        for (mount in [ MOUNT_FLOOR_HIGH ])
          if (places(mount, block).length == 0)
            throw 'Deco: nothing is placed on "' + mount + '" in a "' + block + '"';
    }
}

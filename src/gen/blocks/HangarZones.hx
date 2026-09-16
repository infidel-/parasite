// what a hangar's wall runs must carry
//
// the quota for the HANGAR level, and the exact counterpart of gen.blocks.RoomZones one structure
// over: that one says a laboratory must have worktop in it and may have a machine bank, this one
// says a hangar has server racks in its corners and a bank of computers against a wall. Both are
// dealt by the same gen.Quota, and the split between what is DEALT and what is CARVED is the same
// one the washroom makes — see gen.blocks.HangarBlock's header.
//
// only the wall runs come here. The study pad and the machine banks that feed it are carved before
// this is ever called, because "arranged around the thing the cables run to" is a statement about
// the floor's centre and no `must` over a bay can express it.

package gen.blocks;

import gen.facility._FacilityState;

class HangarZones
{
  // how many corners get a server bay, and how often the second one is there at all. two of the
  // four, so the shed reads as equipped without its span being ringed
  static inline var RACK_BAYS = 2;
  static inline var SECOND_RACK_PCT = 70;

// the quota for one hangar floor, over the bays its perimeter ring was cut into.
//
// the core zone comes FIRST, because gen.Quota's second pass spends what is left in demand order
// and `max` on the core is what reclaims every bay nothing else wanted — except that here the core
// IS the filler, so there is no core demand at all and gen.Quota's `filler` argument does the whole
// of that job. That is the difference a hangar makes: a laboratory's leftovers are worktop and a
// hangar's leftovers are floor
  public static function demands(state: _FacilityState, node: _GenNode,
      bays: Array<_GenNode>): Array<_GenDemand>
    {
      // the second bay rolls, the first does not. a hangar with no server rack in it at all reads
      // as a shed, which is what the compound already has three of
      var racks = (state.area.chance(SECOND_RACK_PCT) ? RACK_BAYS : 1);
      return [
        {
          kind: HangarBlock.RACK_BAY,
          min: racks,
          max: racks,
          minW: 1,
          minH: 1,
          // a corner, and long enough to be a bank rather than one cabinet left against a wall.
          // TAG_END is what gen.blocks.HangarBlock.walls marks a corner bay with, and it is the
          // INVERSE of what it means in a room: there it is the bay running off the end of a run
          // and carrying nothing, here it is the one thing this demand is looking for
          must: function(b: _GenNode)
            return (RoomBlock.tagged(b, RoomBlock.TAG_END) &&
              free(state, b) >= 2),
          // WITHOUT THIS BOTH BAYS LAND ON THE SAME WALL, every compound. All four corner bays are
          // three cells, so they are the same area, and gen.Quota.best breaks a tie on area by
          // taking the first — which is whichever wall gen.blocks.HangarBlock.walls emitted first,
          // i.e. always the top. A hash of the bay's own corner spreads them over the four instead,
          // and being a hash rather than a roll it does not depend on how often `fit` is called
          fit: function(b: _GenNode)
            return spread(b),
        },
        {
          kind: HangarBlock.CONSOLE,
          min: 1,
          max: 1,
          minW: 1,
          minH: 1,
          // a straight run, off the corners and off the door. a desk in a corner faces a wall, and
          // a desk in the doorway is the one thing the shed's single entrance cannot afford
          must: function(b: _GenNode)
            return (!RoomBlock.tagged(b, RoomBlock.TAG_END) &&
              !RoomBlock.tagged(b, RoomBlock.TAG_DOOR) &&
              free(state, b) >= HangarBlock.CONSOLE_MIN),
        },
      ];
    }

// a stable per-bay number to rank corners by, so two bays dealt in a row do not both take the wall
// that happens to be first in the list. THE SAME XORSHIFT render.sewer.SewerModel.mix uses, and
// written out here rather than imported because gen/ must not reach into render/ — the shifts stay
// inside Int32 by construction, which a multiply-based hash does not
  static function spread(b: _GenNode): Int
    {
      var x = (b.x1 * 73856093) ^ (b.y1 * 19349663) ^ 0x9E3779B9;
      x ^= x << 13;
      x ^= x >>> 17;
      x ^= x << 5;
      return x & 0x7fffffff;
    }

// how many cells of this bay are still bare concrete. the same question gen.blocks.RoomBlock's
// solidRun asks of a room, and asked here for the same reason: a `must` that accepts a bay the
// filler cannot then fill is a zone that comes out half empty
  static function free(state: _FacilityState, node: _GenNode): Int
    {
      var cells = state.area.getCells();
      var n = 0;
      for (c in RoomBlock.cellsOf(node))
        if (cells[c.x][c.y] == gen.facility.FacilityTemp.TEMP_CONCRETE &&
            !state.area.hasObjectAt(c.x, c.y))
          n++;
      return n;
    }
}

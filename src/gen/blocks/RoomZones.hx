// what a room of each kind must contain
//
// the quota for the ROOM level, and the exact counterpart of gen.blocks.FacilityBlocks.demands one
// level up: that one says a compound must have two lab buildings, a hangar and a car park, this one
// says a laboratory must have worktop in it and may have a machine bank. Both are dealt by the same
// gen.Quota.
//
// WHY A QUOTA AND NOT THE ROLL IT REPLACES: gen.blocks.RoomBlock used to decide each bay's kind AT
// THE MOMENT IT PUSHED IT, from two flags carried along the wall — which is the shape the compound
// itself had before the block tree, one level further down. A bay decided that way can only ever
// answer a question about itself, so nothing could say "this room has a lounge in it": that is a
// statement about the room, and nothing looked at the room.
//
// CORE ZONES AND OPTIONAL ONES. A core zone is `min >= 1` and is always there. An optional one rolls
// its own `min` HERE, before the deal — which matters, because gen.Quota's first pass is
// most-constrained-first and only sees demands with a min. A zone that rolled in therefore picks its
// bay before the core zone takes the room, and one that rolled out costs nothing.
//
// and the leftovers go to the room's PRIMARY core zone, which is the one carrying `max: MANY`. Still
// one node per bay and never one merged run — a bay is a bay because the glazing above it says so.
// A bay no demand's `must` accepts falls through to gen.Quota's filler, which is the slot: that is
// the bay standing in a doorway's swing or running off the end of the room, and neither has ever
// held furniture.

package gen.blocks;

import gen.GenTree;
import gen.facility._FacilityState;
import gen.facility.FacilityTemp.*;

class RoomZones
{
  // "as many as will fit". _GenDemand.max is an Int and the dealer loops until `best` returns null,
  // so any number past the most bays a room can have does the job — a 7x7 room offers 8
  static inline var MANY = 99;

  // the shortest run that reads as a BAY rather than as one thing left against a wall. two racks in
  // a row is a server bay; one rack is what Deco.pick has always dealt as ordinary wall furniture
  static inline var RUN_MIN = 2;

  // how often a laboratory gets a machine bank, how often it gets a server bay, and how often an
  // office gets one. rolled per room in `optional` below, BEFORE the deal — see the header
  static inline var LAB_MACHINERY_PCT = 35;
  static inline var LAB_SERVER_PCT = 25;
  static inline var OFFICE_SERVER_PCT = 30;
  // and how often an office has a corner to sit in
  static inline var OFFICE_LOUNGE_PCT = 50;

// the quota for one room, by the kind gen.blocks.RoomBlock dealt it.
//
// the core zone comes FIRST in the array, because gen.Quota's second pass spends what is left in
// demand order and `max: MANY` on the core is what reclaims every bay nothing else wanted
  public static function demands(state: _FacilityState, room: _Room,
      kind: String): Array<_GenDemand>
    {
      switch (kind)
        {
          case RoomBlock.OFFICE:
            return [
              core(RoomBlock.WORKPLACE),
              lounge(state, room),
              optional(state, RoomBlock.SERVER_RACK_BAY, OFFICE_SERVER_PCT),
            ];

          default:
            return [
              core(RoomBlock.BENCH),
              optional(state, RoomBlock.MACHINERY, LAB_MACHINERY_PCT),
              optional(state, RoomBlock.SERVER_RACK_BAY, LAB_SERVER_PCT),
            ];
        }
    }

// a zone that rolls whether it is in this room at all.
//
// THE ROLL IS THE `min` AND THAT IS THE POINT. A demand with a min is in gen.Quota's first pass,
// which is most-constrained-first, so a machine bank that rolled in picks its wall before the core
// zone takes the room. Rolled as a `chance` inside the filler instead, it would be picking over
// whatever the core had already left, which is how the arithmetic era placed everything
  static function optional(state: _FacilityState, kind: String, pct: Int): _GenDemand
    {
      // THE ROLL IS BOTH min AND max, and a `max: 1` beside a `min: 0` is the trap. gen.Quota's
      // second pass spends every demand up to its max whatever its min was — that is what turns a
      // leftover plot into a second lab building one level up — so `min: 0, max: 1` does not mean
      // "maybe one", it means "one, dealt later". Measured: it put a machine bank and a server bay
      // in every room of every compound, 11.6 of each against the 4.7 the odds ask for
      var n = (state.area.chance(pct) ? 1 : 0);
      return {
        kind: kind,
        min: n,
        max: n,
        minW: 1,
        minH: 1,
        // plain masonry the whole way along, and long enough to read as a run. the same test
        // `standing` then fills by, so a bay this accepts is never half empty
        must: function(b: _GenNode)
          return (RoomBlock.solidRun(state, b) >= RUN_MIN),
      };
    }

// the worktop run, and every room's primary core zone: a laboratory is benches and an office is
// desks, and they are the same tile one texture family apart — which is why one function returns
// both and only the kind differs.
//
// `must` is the pair of flags the walk used to latch — see RoomBlock.TAG_END and TAG_DOOR. They are
// read off the node rather than recomputed because the walk is where the bay rhythm lives: a bay's
// door box is measured at the blank cell BEFORE it and at the full bay width even when the bay came
// out short, and re-deriving that from the finished rect would be a reimplementation that drifts
  static function core(kind: String): _GenDemand
    {
      return {
        kind: kind,
        min: 1,
        max: MANY,
        minW: 1,
        minH: 1,
        must: function(b: _GenNode)
          return (!RoomBlock.tagged(b, RoomBlock.TAG_END) &&
            !RoomBlock.tagged(b, RoomBlock.TAG_DOOR)),
      };
    }

// the sofa and the table BESIDE it. Its own function rather than another `optional` because its
// `must` asks two things no other zone does: two ADJACENT cells of the bay, since the suite is a pair
// and a bay with two usable cells at opposite ends houses no lounge, and a LANE — two cells of clear
// room floor in front of each, which is what keeps a 7x3 office reachable past a run that fills both
// of its own cells outright
  static function lounge(state: _FacilityState, room: _Room): _GenDemand
    {
      var n = (state.area.chance(OFFICE_LOUNGE_PCT) ? 1 : 0);
      return {
        kind: RoomBlock.LOUNGE,
        min: n,
        max: n,
        minW: 1,
        minH: 1,
        must: function(b: _GenNode)
          return (RoomBlock.loungeRun(state, room, b) > 0),
      };
    }

// one HALF of a washroom: its longest wall takes the cubicles, the next takes the basin counter, and
// whatever is left is floor — a half ranked out on every wall is a corridor with nowhere to turn
// round.
//
// THE CUBICLES ARE PINNED TO THE LONGEST RUN AND THAT IS WHAT MAKES THE ORDER DETERMINISTIC. Both
// demands would otherwise accept every run, gen.Quota's first pass would find them equally
// constrained, and which of the two picked first would rest on the sort being stable. `must` = "be
// the longest" gives the cubicles exactly one legal home, so they are dealt first by the rule that
// is already there, and the basins then take the roomiest of what is left — which is the old
// longest-first ranking, arrived at rather than hand-written
  public static function washroom(bays: Array<_GenNode>): Array<_GenDemand>
    {
      var longest = 0;
      for (b in bays)
        {
          var len = GenTree.width(b) * GenTree.height(b);
          if (len > longest)
            longest = len;
        }
      return [
        {
          kind: RoomBlock.STALL_RUN,
          min: 1,
          max: 1,
          minW: 1,
          minH: 1,
          // two cells at least, which is where the washroom's old "a run of one is not a counter"
          // minimum belongs: a basin is happy alone and a row of cubicles is not a row
          must: function(b: _GenNode)
            {
              var len = GenTree.width(b) * GenTree.height(b);
              return (len >= 2 && len == longest);
            },
        },
        {
          kind: RoomBlock.BASIN_RUN,
          min: 1,
          max: 1,
          minW: 1,
          minH: 1,
        },
      ];
    }
}

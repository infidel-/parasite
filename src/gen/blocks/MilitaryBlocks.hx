// what a military base is made of
//
// the top level of the base's generation tree: how the ground INSIDE THE FENCE divides into plots,
// and which plots must exist. The fence, the road past the gate and the wild margin round it are not
// in the split — gen.military.MilitaryGen lays them around the rect handed to plan(), the same way
// gen.blocks.FacilityBlocks reserves its road band before it cuts anything.

package gen.blocks;

class MilitaryBlocks
{
  // the node kinds a base deals in, besides the two it shares with the lab compound
  // (FacilityBlocks.BUILDING, FacilityBlocks.HANGAR) and the filler (FacilityBlocks.YARD)
  public static inline var CAMP = 'camp';
  public static inline var DEPOT = 'depot';
  public static inline var MOTORPOOL = 'motorpool';
  public static inline var HELIPAD = 'helipad';
  // the open yard the gate opens onto, filled as yard: a building straight behind the boom read as
  // a wall at the end of the drive
  public static inline var ENTRY = 'entry';

  // how many splits to try before giving up on housing the whole quota. 16 still failed one 70x60
  // base in 2000; the underground lab retries 30 for the same reason. The entry yard's must (a plot
  // on the gate's edge) failed 3 in 2000 at 30, none at 60, mean 3.5 splits
  public static inline var MAX_PLAN_TRIES = 60;
  // how many splits the last plan() needed, for the oracle's `planTries` mean
  public static var lastPlanTries = 0;

// split the fenced ground and deal the quota onto it, re-rolling the split until it houses
// everything. called by the live generator and the headless oracle alike
  public static function plan(x1: Int, y1: Int, x2: Int, y2: Int, gateNorth: Bool,
      rng: Void -> Float): Array<_GenNode>
    {
      var p = splitProfile();
      var ds = demands(gateNorth, (gateNorth ? y1 : y2));
      var blocks = null;
      for (i in 0...MAX_PLAN_TRIES)
        {
          lastPlanTries = i + 1;
          blocks = Subdivide.split(x1, y1, x2, y2, p, rng);
          Quota.deal(blocks, ds, FacilityBlocks.YARD, rng);
          if (Quota.satisfied(blocks, ds))
            return blocks;
        }
      trace('MilitaryBlocks.plan(): quota unsatisfiable after ' + MAX_PLAN_TRIES +
        ' splits of ' + (x2 - x1 + 1) + 'x' + (y2 - y1 + 1));
      return blocks;
    }

// how the fenced ground is cut. The gap is the lab compound's 2, because gen.facility.FacilityGen
// insets the hangar off it, and minSide is lower than the compound's 16: four of the six plots a
// base must have are small (a motor pool, a helipad, a camp). Measured over 400 seeds at each of the
// four sizes: 10/24/30 failed the quota 73 times at 70x60, 14/28/34 once, and these never, with a
// mean of 1.7-2.7 splits per base
  public static function splitProfile(): _SplitProfile
    {
      return {
        minSide: 12,
        splitOver: 26,
        maxSide: 32,
        gap: 2,
        depth: 4,
        earlyLeafChance: 0.08,
        maxAspect: 2.8,
      };
    }

// what a base must end up with. `edge` is the plotted rect's row on the gate side
  public static function demands(gateNorth: Bool, edge: Int): Array<_GenDemand>
    {
      // distance from the gate's edge, so "deep in the base" reads the same whichever side it is on
      var fromGate = function(b: _GenNode) return (gateNorth ? b.y1 : -b.y1);
      return [
        // the HQ and the barracks, on the lab building's own minimum, as deep as they will go: the
        // front row is where the entry yard has to find a plot
        {
          kind: FacilityBlocks.BUILDING,
          min: 2,
          max: 2,
          minW: 18,
          minH: 16,
          fit: fromGate,
        },
        // the yard the gate opens onto, on the gate side's edge (a MUST, the facility parking lot's
        // lesson: a preference loses to whatever was dealt first) and as small as will do, so it
        // leaves the big front plots to the rest
        {
          kind: ENTRY,
          min: 1,
          max: 1,
          minW: 8,
          minH: 5,
          must: function(b: _GenNode) return (gateNorth ? b.y1 == edge : b.y2 == edge),
          fit: function(b: _GenNode) return -GenTree.width(b) * GenTree.height(b),
        },
        // the hangar, deep in the base. its floor carries the plane (Const.MIL_PLANE_SIZE) with a
        // lane round it, so the plot has to be bigger than the bare shed would be
        {
          kind: FacilityBlocks.HANGAR,
          min: 1,
          max: 1,
          minW: 14,
          minH: 13,
          fit: fromGate,
        },
        // the helipad wants the open ground of a square plot
        {
          kind: HELIPAD,
          min: 1,
          max: 1,
          minW: 10,
          minH: 10,
          fit: function(b: _GenNode) return -Std.int(Math.abs(GenTree.width(b) -
            GenTree.height(b))),
        },
        // the motor pool, near the gate: vehicles leave by it
        {
          kind: MOTORPOOL,
          min: 1,
          max: 1,
          minW: 10,
          minH: 6,
          fit: function(b: _GenNode) return -fromGate(b),
        },
        // a container depot, never required, but its FIRST plot dealt before a second camp: with the
        // entry yard taking a plot, a 90x70 base otherwise never got one (0.22 a base to 0). The
        // two DEPOT rows share one count (gen.Quota), so this one stops at 1
        {
          kind: DEPOT,
          min: 0,
          max: 1,
          minW: 8,
          minH: 5,
        },
        // the tent camp, one required and a second allowed out of what is left
        {
          kind: CAMP,
          min: 1,
          max: 2,
          minW: 8,
          minH: 6,
        },
        // and a second depot out of whatever the camps leave
        {
          kind: DEPOT,
          min: 0,
          max: 2,
          minW: 8,
          minH: 5,
        },
      ];
    }
}

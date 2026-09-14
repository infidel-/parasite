// what a facility compound is made of
//
// the top level of the generation tree: how the compound's open ground divides into plots, and which
// plots MUST exist. game.FacilityAreaGenerator.generate used to answer both questions with
// arithmetic on area.width/height — the main building at 0.5 x 0.5, the side building at 0.4 width,
// the hangar at 0.2, the park in whatever was left on the left — so a compound had exactly one
// layout with a north/south mirror on it. This is the same compound described as a quota instead, so
// every seed lays it out differently and every seed still has everything in it.
//
// THE ROAD IS NOT IN THE SPLIT. Its band is reserved before the rect is ever cut, because its
// position is dictated from outside the tree — the same reason game.AreaGenerator.placeHighway runs
// before anything else in the wilderness. Everything below divides what is left.

package gen.blocks;

class FacilityBlocks
{
  // the node kinds a compound deals in. strings and not an enum, because gen.GenTree is shared with
  // every other area type and a filler table keyed on one area's enum would not be
  public static inline var ROAD = 'road';
  public static inline var PARK = 'park';
  public static inline var HANGAR = 'hangar';
  public static inline var BUILDING = 'building';
  public static inline var PARKING = 'parking';
  public static inline var ENTRYWAY = 'entryway';
  public static inline var YARD = 'yard';

  // the road band and the pavement beside it, in cells. both were literals in generate()
  public static inline var ROAD_W = 4;
  public static inline var SIDEWALK_W = 2;

  // how many splits to try before giving up on housing the whole quota. a split is cheap and an
  // unsatisfiable one is thrown away whole rather than patched, the same shape
  // game.UndergroundLabAreaGenerator.buildLabLayout uses (MAX_LAYOUT_ATTEMPTS = 30). Measured over
  // 2000 seeds with the profile below, the first attempt succeeds ~96% of the time, so this is deep
  // enough that failing every attempt is not a thing that happens
  public static inline var MAX_PLAN_TRIES = 12;

  // how many splits the last plan() needed. read by tools/genrun.mjs to report how MARGINAL the
  // profile is against the quota: a mean near 1 means the numbers agree, and a mean creeping up is
  // the warning that comes before the cap is hit and a compound ships without its second building
  public static var lastPlanTries = 0;

// lay out one compound's plots: reserve the road band, split what is left, deal the quota onto it,
// and re-roll the whole split if it cannot house everything.
//
// the one place a compound's layout is decided, called by both game.FacilityAreaGenerator and the
// headless oracle — which is the point. A check that runs a reimplementation of the thing it is
// checking is worth nothing
  public static function plan(w: Int, h: Int, roadNorth: Bool,
      rng: Void -> Float): Array<_GenNode>
    {
      var p = splitProfile();
      var ds = demands(roadNorth);
      // the road takes its band off one edge before anything is cut: its side is dictated from
      // outside the tree, so everything else divides what is left rather than the other way round
      var reserved = ROAD_W + SIDEWALK_W;
      var y1 = (roadNorth ? reserved : 0);
      var y2 = (roadNorth ? h - 1 : h - 1 - reserved);

      var blocks = null;
      for (i in 0...MAX_PLAN_TRIES)
        {
          lastPlanTries = i + 1;
          blocks = Subdivide.split(0, y1, w - 1, y2, p, rng);
          Quota.deal(blocks, ds, YARD, rng);
          if (Quota.satisfied(blocks, ds))
            return blocks;
        }
      // every attempt fell short. return the last one rather than nothing: a compound missing its
      // second building is still playable, where a null layout is a crash, and the trace is what
      // says the profile and the quota have drifted apart
      trace('FacilityBlocks.plan(): quota unsatisfiable after ' + MAX_PLAN_TRIES +
        ' splits of ' + w + 'x' + h + ', check splitProfile() against demands()');
      return blocks;
    }

// how the compound's open ground is cut into plots.
//
// maxSide is the load-bearing one, and THE SIZE IT HAS TO WORK AT IS THE SMALL ONE. A facility is
// not 75x60 — game.AreaGame.initPost rolls each axis separately as `info.width - 10 + 10 *
// Std.random(2)`, so it is 65 or 75 by 50 or 60, and the WorldConst dimensions are the largest of
// the four rather than the size. 65x50 loses six rows to the road band and has to fit the same five
// plots into what is left, so it is the case that binds.
//
// the cap is set below half the short axis so one forced cut per axis cannot be the end of it: at
// 34 a 44-row column must split and a 65-column row must split twice, which floors the compound at
// six plots against a quota of five. Measured over 4000 seeds across all four sizes, the first
// split satisfies the quota 95% of the time (planTries mean 1.05) and the retry cap is never
// reached
  public static function splitProfile(): _SplitProfile
    {
      return {
        minSide: 16,
        splitOver: 30,
        maxSide: 34,
        // two cells of gap, which is what becomes the lane between one plot's pavement apron and the
        // next. one reads as a seam at the game's camera pitch, the same finding HANGAR_GAP records
        gap: 2,
        depth: 3,
        earlyLeafChance: 0.08,
        maxAspect: 2.8,
      };
    }

// what a compound must end up with. the sizes are what each filler needs to produce something that
// reads as the thing rather than a token of it — a building below 18x16 has no room for a corridor
// with rooms either side of it once the wall ring and the 2-cell apron are taken off.
//
// `roadNorth` is which edge the road band was reserved against, and two of the four fit functions
// are measured from it — "furthest from the road" is a different plot depending on which side it is
  public static function demands(roadNorth: Bool): Array<_GenDemand>
    {
      // distance from the road edge, so a fit function reads the same whichever side it landed on
      var fromRoad = function(b: _GenNode) return (roadNorth ? b.y1 : -b.y1);
      return [
        // the two lab buildings. exactly two: one is a compound with nothing to cross between, and
        // three leaves no ground for the yard the place is looked at across
        {
          kind: BUILDING,
          min: 2,
          max: 2,
          minW: 18,
          minH: 16,
        },
        // the hangar wants the plot FURTHEST from the road. its wall is a blank storey-and-a-half
        // face with no apron, and putting that on the street frontage is what the compound looks
        // like from the gate
        {
          kind: HANGAR,
          min: 1,
          max: 1,
          minW: 12,
          minH: 12,
          fit: fromRoad,
        },
        // and parking wants the plot NEAREST it, because the gate has to reach the pavement: the
        // entryway child punches its hole through the sidewalk band, and game.AreaGame.gate()
        // re-derives the checkpoint from that hole on every load
        {
          kind: PARKING,
          min: 1,
          max: 1,
          minW: 14,
          minH: 10,
          fit: function(b: _GenNode) return -fromRoad(b),
        },
        // the park takes what is left, and would rather be a strip than a square: a path down the
        // long axis with benches off it is what render.facility.FacilityGround kerbs and
        // FacilityLamps lights, and a square lawn gives that nothing to run along
        {
          kind: PARK,
          min: 1,
          max: 1,
          minW: 8,
          minH: 10,
          fit: function(b: _GenNode)
            {
              var w = GenTree.width(b);
              var h = GenTree.height(b);
              return Std.int(10 * (w > h ? w / h : h / w));
            },
        },
      ];
    }
}

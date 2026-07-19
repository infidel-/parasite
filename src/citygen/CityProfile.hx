package citygen;

import citygen.profiles.DowntownProfile;

// per-area-type generation knobs. CityGen is otherwise a pure seed->City function;
// a profile carries every value/roll that differs between area tiers, so downtown
// (skyscrapers) can be tuned independently of the residential default without
// touching the shared algorithm. DEFAULT reproduces the old CityConfig inlines
// verbatim, so LOW/MEDIUM (and any caller that omits a profile) stay byte-identical.
typedef CityProfile = {
  // --- block layout / spacing ---
  minBlock:Int,             // block-size range low (road pitch = ROAD_W + this)
  maxBlock:Int,             // block-size range high
  setback:Int,              // pavement gap between buildings and roads
  subdivDepth:Int,          // block subdivision recursion depth
  splitOver:Int,            // blocks bigger than this MUST split
  maxBuilding:Int,          // hard per-axis cap on a building/shape piece
  blockGap:Int,             // empty cells left between two split siblings (residential 1; downtown 3 for wide back alleys)
  earlyLeafChance:Float,    // chance a mid-size splittable block stops early
  // --- shaped-building rolls ---
  courtyardChance:Float,    // chance a big leaf becomes a U-courtyard
  lChance:Float,            // chance a big non-full-block leaf becomes an L
  tChance:Float,            // chance a big leaf becomes a T
  plusChance:Float,         // chance a big leaf becomes a +
  courtyardBlockChance:Float, // chance to carve a central courtyard from a finished block
  // --- road treatment (DEFAULT == current, so residential roads unchanged) ---
  turnChance:Float,         // chance an interior vertical road L-turns
  deadendChance:Float,      // chance an interior vertical road dead-ends
  // --- floors ---
  minFloors:Int,            // fewest window floors
  maxFloors:Int,            // most window floors (global draw pool)
  maxFloorsBrick:Int,       // brick storey cap (courtyard centre grow/shrink)
  floorCap:Array<Int>,      // per-facade window-floor cap [concrete, brick, stone, metal]
  // --- shop downgrade ---
  downgradeChance:Float,    // chance a small footprint becomes a single-story shop
  // --- big-box reshape thresholds ---
  bigW:Int,                 // plain rectangle wider than this (+ deeper than bigD on both) reshapes
  bigD:Int,
  // --- downtown switches (ignored on the default path) ---
  downtown:Bool,            // downtown massing/facades active
  keepAlleyFront:Bool,      // keep a building that only fronts an alley (downtown back-alley blocks); else drop like a landlocked box
  metalWarehouses:Bool,     // facade 3 behaves as a squat metal warehouse (DEFAULT true; downtown false)
  towerStepChance:Float,    // chance a downtown leaf becomes a stepped setback tower
  towerMinTiers:Int,        // fewest tiers in a stepped tower
  towerMaxTiers:Int,        // most tiers in a stepped tower
  towerInset:Int,           // cells each tier steps back per side
  glassTypes:Array<Int>,    // facade indices rendered as glass curtain wall (downtown)
};

// profile registry: DEFAULT (residential, verbatim from CityConfig) + downtown factory
class Profiles {
  // residential default — every field equals the corresponding CityConfig inline, so
  // the default generation stream is unchanged
  public static final DEFAULT:CityProfile = {
    minBlock: 8,
    maxBlock: 20,
    setback: 1,
    subdivDepth: 5,
    splitOver: 12,
    maxBuilding: 8,
    blockGap: 1,
    earlyLeafChance: 0.3,
    courtyardChance: 0.3,
    lChance: 0.35,
    tChance: 0.6,
    plusChance: 0.85,
    courtyardBlockChance: 0.35,
    turnChance: 0.55,
    deadendChance: 0.7,
    minFloors: 2,
    maxFloors: 7,
    maxFloorsBrick: 5,
    floorCap: [7, 5, 5, 2],
    downgradeChance: 0.35,
    bigW: 8,
    bigD: 6,
    downtown: false,
    keepAlleyFront: false,
    metalWarehouses: true,
    towerStepChance: 0,
    towerMinTiers: 0,
    towerMaxTiers: 0,
    towerInset: 0,
    glassTypes: [],
  };

  // pick the generation profile for an area: downtown when the area was generated as
  // high-density under the downtown code (area.downtownGen), else the residential default
  public static function forDowntown(downtown:Bool):CityProfile {
    return downtown ? DowntownProfile.INSTANCE : DEFAULT;
  }
}

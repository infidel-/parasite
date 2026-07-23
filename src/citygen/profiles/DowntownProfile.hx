package citygen.profiles;

import citygen.CityProfile;

// downtown (skyscraper) generation knobs — the single file to tune the high-density
// look independently of residential: larger blocks/footprints, wider spacing, taller
// glass office towers, stepped setback massing, no metal warehouses, no single-story
// shops. Selected only for areas generated as high-density under the downtown code
// (AreaGame.downtownGen), so older/other areas keep the residential default.
class DowntownProfile {
  public static final INSTANCE:CityProfile = {
    // larger blocks + more spacing between buildings
    minBlock: 12,
    maxBlock: 26,
    // 1, like residential: a wider setback puts a dead alley strip between the building and
    // the walkway (a cell 2 out from a road is not road-adjacent, so it classifies as alley)
    setback: 1,
    subdivDepth: 5,
    // bigger acreage per building. maxBuilding/earlyLeafChance are what actually decide how
    // many leaves come out square enough (min side >= 5 + 2*TOWER_CLEAR) to be glass towers:
    // at 14/0.15 a city produced ~2 towers, at 16/0.7 it produces ~10
    splitOver: 20,
    maxBuilding: 16,
    // 1 empty cell between split siblings, exactly like residential: mid-rises pack tight
    // and only the glass towers step back (CityConfig.TOWER_CLEAR) for their 3-cell ring
    blockGap: 1,
    earlyLeafChance: 0.7,
    // the residential shape rolls, at residential rates. CityGen.leaf() gates them to the
    // MID-RISE infill (facade 0/1): a shape is built on the raw leaf rect, so on a glass leaf
    // it would throw away the tower step-back, and a tower's tiered massing is the point
    courtyardChance: 0.3,
    lChance: 0.35,
    tChance: 0.6,
    plusChance: 0.85,
    courtyardBlockChance: 0.15,
    // roads unchanged
    turnChance: 0.55,
    deadendChance: 0.7,
    // wide floor range: small footprints stay mid-rise (medium-city look), big glass
    // footprints climb to the caps as setback towers
    minFloors: 2,
    maxFloors: 24,
    maxFloorsBrick: 16,
    // [0 office-concrete, 1 office-stone, 2 glass, 3 full-glass tallest]
    floorCap: [12, 10, 24, 30],
    // no single-story shops downtown
    downgradeChance: 0.0,
    bigW: 14,
    bigD: 12,
    downtown: true,
    metalWarehouses: false,
    towerStepChance: 0.7,
    towerMinTiers: 2,
    towerMaxTiers: 4,
    towerInset: 1,
    glassTypes: [2, 3],
  };
}

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
    setback: 2,
    subdivDepth: 5,
    // bigger acreage per building
    splitOver: 20,
    maxBuilding: 14,
    // 3 empty cells between split siblings → wide back alleys / plaza gaps
    blockGap: 3,
    earlyLeafChance: 0.15,
    // suppress the residential shape rolls; downtown uses tower massing instead
    courtyardChance: 0.1,
    lChance: 0.0,
    tChance: 0.0,
    plusChance: 0.0,
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
    keepAlleyFront: true,
    metalWarehouses: false,
    towerStepChance: 0.7,
    towerMinTiers: 2,
    towerMaxTiers: 4,
    towerInset: 1,
    glassTypes: [2, 3],
  };
}

package citygen.profiles;

import citygen.CityProfile;

// slums (low-density outskirts) generation knobs — the single file to tune the run-down
// look independently of the mid-density residential default: smaller, lower footprints,
// more single-story corner shops, and two dilapidated single-floor house types (4 clapboard
// cottage, 5 cinderblock bungalow) that small leaves are remapped to. Selected only for
// AREA_CITY_LOW (see CityProfile.Profiles.forArea).
class SlumsProfile {
  public static final INSTANCE:CityProfile = {
    // same road pitch as residential — the street grid is not what makes a slum
    minBlock: 8,
    maxBlock: 20,
    setback: 1,
    // one more subdivision level, split earlier and cap harder: brick/stone buildings come
    // out smaller and shorter far more often than in the mid-density default (8 -> 6 cells)
    subdivDepth: 6,
    splitOver: 10,
    maxBuilding: 6,
    // stop early LESS often than residential (0.3) so a splittable block keeps getting cut
    earlyLeafChance: 0.15,
    blockGap: 1,
    // the residential shape rolls, unchanged. courtyardBlockChance especially: burning barrels
    // are placed one per carved inner courtyard (CityAreaGenerator.placeBurningBarrels), so
    // lowering it would thin the barrels out
    courtyardChance: 0.3,
    lChance: 0.35,
    tChance: 0.6,
    plusChance: 0.85,
    // derelict inner lots far more often than the mid-density default (0.35): the carved courtyard
    // is the ONLY burning-barrel site, and at 0.35 a slums city averaged 3.9 courtyards -> too few
    courtyardBlockChance: 0.6,
    // roads unchanged
    turnChance: 0.55,
    deadendChance: 0.7,
    // low and squat: nothing here is a mid-rise
    minFloors: 1,
    maxFloors: 4,
    maxFloorsBrick: 3,
    // [0 concrete, 1 brick, 2 stone, 3 metal warehouse, 4 clapboard cottage, 5 cinderblock
    // bungalow]. the two house slots are capped at ONE window floor — that is what makes them
    // single-floor (mk() clamps to this cap)
    floorCap: [4, 3, 3, 2, 1, 1],
    // more boarded-up single-story corner shops than the mid-density default
    downgradeChance: 0.45,
    bigW: 8,
    bigD: 6,
    downtown: false,
    metalWarehouses: true,
    towerStepChance: 0,
    towerMinTiers: 0,
    towerMaxTiers: 0,
    towerInset: 0,
    glassTypes: [],
    houseSlots: [4, 5],
    // measured over 30 seeds: 5 gives 36% houses and all but wipes out stone (7%) and the metal
    // warehouses (5%); 3 leaves only 6% houses. 4 is the balance — ~21% houses with stone at 14%
    // and metal at 10%, so the district still reads as the same city, only poorer
    houseMaxSide: 4,
  };
}

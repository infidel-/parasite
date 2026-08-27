// what map.Highway.lines needs to reproduce map.RoadPlan's ROAD1 trunk picking.
//
// replaces the six positional args that would otherwise be needed, and exists because the SAME
// function is called from two places that hold none of the same state: RoadPlan, which has a live
// plan grid and an area-type field, and area generation, which has neither and rebuilds the answer
// from the region's persisted mapSeed alone

package map;

typedef HighwayOpts = {
  // the draw stream. RoadPlan passes its OWN rng so the shared sequence is unchanged; a headless
  // caller passes a fresh SeededRandom(mapSeed), which is provably the same state (nothing consumes
  // rng between Core.initRandom and the ROAD1 block)
  rng:SeededRandom,
  // plan grid size, in plan cells
  planWidth:Int,
  planHeight:Int,
  // plan cells per region tile, i.e. Core.PLAN_CELLS_PER_TILE
  cellsPerTile:Int,
  // does the area type at this PLAN cell refuse a ROAD1 trunk? in plan coordinates, halo included,
  // which is the frame RoadPlan's own areaTypes field is in. handed in rather than read, so this
  // file needs neither a map.Image nor the region
  blocked:(Int, Int) -> Bool,
  // debug counter sink (Core.addMapProfileCount). only RoadPlan has one, hence optional
  ?count:(String, Int) -> Void,
};

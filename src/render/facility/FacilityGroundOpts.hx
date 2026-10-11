package render.facility;

// one thing standing on an interior floor, for render.facility.FacilityDetail.ground.
//
// replaced ground(m, rect, h), which read the room cell back off the world rect — and a thing backed
// onto masonry stands in the WALL cell's room-side margin (a slab is thinner than CELL), so a corner
// bin resolved to a wall cell on both axes and its halos went up on the wrong slab, in mid air. The
// caller knows its cell; it hands it over
typedef FacilityGroundOpts = {
  // the room cell it stands in — for a run, the run's FIRST cell (lowest col/row)
  col:Int,
  row:Int,
  // how many cells the run covers, 1 for a single object
  len:Int,
  // which way a run of more than one cell runs; ignored at len 1
  alongX:Bool,
  // its footprint, world
  rect:FacilityGeom.Rect,
  // and how tall it stands off the floor
  h:Float,
  // the floor pool's size against GROUND_POOL_SCALE's own, 1 when absent
  ?pool:Float,
}

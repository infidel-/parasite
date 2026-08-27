package render.facility;

// the per-build lookup grids render.facility.FacilityGeom.build precomputes once and every
// structure() call reads. all three are [row][col], the render convention.
//
// replaces the (sill, head) tail of FacilityGeom.structure(scene, m, si, sill, head): that signature
// was already at the repo's positional-argument ceiling, and the door pass needed a third grid
typedef FacilityShellOpts = {
  // the bottom of a window opening on this cell, world units up the wall, or -1 for no opening.
  // per CELL because a wall face is emitted per cell while a pane is emitted per RUN
  sill:Array<Array<Float>>,
  // and its top
  head:Array<Array<Float>>,
  // index into Facility.doors for a door cell, -1 otherwise. what tells the wall pass to close the
  // gap above an opening the tile grid records as ordinary corridor floor
  doorAt:Array<Array<Int>>,
};

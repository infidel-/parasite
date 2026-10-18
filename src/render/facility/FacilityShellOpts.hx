package render.facility;

import render.world.MeshBuf.MeshBuf;

// the per-build lookup grids render.facility.FacilityGeom.build precomputes once and every
// structure() call reads. all three are [row][col], the render convention.
//
// replaces the (sill, head) tail of FacilityGeom.structure(scene, m, si, sill, head): that signature
// was already at the repo's positional-argument ceiling, and the door pass needed a third grid.
//
// `hood` is the one field that is not a grid and not read-only: it is a BUFFER the structures write
// into and FacilityGeom.build merges after the loop — see its own comment
typedef FacilityShellOpts = {
  // the bottom of a window opening on this cell, world units up the wall, or -1 for no opening.
  // per CELL because a wall face is emitted per cell while a pane is emitted per RUN
  sill:Array<Array<Float>>,
  // and its top
  head:Array<Array<Float>>,
  // index into Facility.doors for a door cell, -1 otherwise. what tells the wall pass to close the
  // gap above an opening the tile grid records as ordinary corridor floor
  doorAt:Array<Array<Int>>,
  // every bulkhead lamp hood in the compound, in ONE buffer shared by all three structures. it is
  // NOT per structure like every other shell buffer, and the reason is the same one that lets it be:
  // the hood takes its own art (FacilityStyle.DOOR_LAMP_TEX), so it cannot ride the cladding any
  // more, and a per-structure mesh would be one draw call per building for four quads each. nothing
  // about a hood is per structure — the exterior cladding does not fade, so there is no reveal state
  // to keep apart, and a lamp is a fitting bolted to a wall rather than a piece of one
  hood:MeshBuf,
};

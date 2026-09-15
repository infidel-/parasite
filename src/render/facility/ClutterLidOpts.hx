package render.facility;

import render.world.MeshBuf.MeshBuf;

// one flat surface the clutter pass dresses, and everything it needs to know about it.
//
// replaces slot(b, m, col, row, kind, pick) — which read its rect back out of
// render.facility.FacilityDeco.rectOf and its height out of that rect, so it could only ever dress ONE
// lid per grid cell, square to the world. Neither holds any more: a shelving unit has three shelves
// and a lab trolley has two, the trolley is render-only and has no grid cell at all, and it carries
// FacilityStyle.KIT_YAW_JIT so its lid is not axis-aligned. Stating the surface instead of looking it
// up covers all three, and a fitting simply passes `yaw: 0`.
//
// THE ITEMS ARE SAMPLED IN THE LID'S OWN FRAME and rotated out by `yaw`, so the rejection sampler and
// ClutterSlotTools keep working in the axis-aligned terms they were written in
typedef ClutterLidOpts = {
  // where the flat decals go — the merged mesh for this lid's sheet
  b:MeshBuf,
  // and where a CRATE goes, or null on a lid that takes no boxes. the two buffers are separate
  // because they are separate materials: a decal is an alpha-cut sheet and a box is opaque
  // cardboard carrying its own shading on the vertex colour channel
  box:MeshBuf,
  // the lid's centre, world
  cx:Float,
  cz:Float,
  // its extents BEFORE the turn — w along the lid's own x, d along its own z
  w:Float,
  d:Float,
  // the height things stand on
  y:Float,
  // the lid's own turn about its centre, radians
  yaw:Float,
  // headroom over it, which caps how tall a crate may be. 0 for a lid with nothing above it
  bay:Float,
  // how much light this bay gets, 0 = black .. 1 = open — a crate's vertex shading, and nothing
  // else reads it. see FacilityStyle.DECO_BOX_AO_LOW
  ao:Float,
  // the placement hash for this lid. every position, size, turn and choice of art comes off it
  seed:Int,
  // the sheet cells a flat decal may be dealt
  pick:Array<Int>,
  // the most items rolled for, and the fewest that must land
  max:Int,
  floor:Int,
}

package render.facility;

import render.world.MeshBuf.MeshBuf;

// one box standing on a shelf, the shape render.facility.FacilityDeco.crate emits.
//
// replaces crate(b, cx, cz, hw, hd, y0, y1, yaw, ph, ao) — ten positional arguments, of which four
// are a bare Float pair the caller already builds through a `dir < 2 ?` ternary each. A call site
// reading `(dir < 2 ? bw : 2 * hd) / 2, (dir < 2 ? 2 * hd : bw) / 2` is exactly the silently
// mis-orderable list the style guide says to stop appending to.
typedef FacilityCrateOpts = {
  // the box's centre in world xz, on the shelf's own plane
  cx:Float,
  cz:Float,
  // its half-extents about that centre BEFORE the turn — hw runs along the wall, hd across it
  hw:Float,
  hd:Float,
  // the shelf it stands on, and the top of the box
  y0:Float,
  y1:Float,
  // its turn about its own vertical axis, radians
  yaw:Float,
  // where its faces start reading the cardboard sheet, 0..1. per box, so no two show the same patch
  ph:Float,
  // and how much light the bay it stands in gets, 0 = black .. 1 = the top shelf. carried on the
  // vertex colour channel because nothing in the room can supply it — see FacilityStyle.DECO_BOX_AO_LOW
  ao:Float,
  // the SIDES' u period, world units per repeat, where DECO_BOX_TILE is not it. null = DECO_BOX_TILE.
  // a ream's striations are a crop that does not wrap, so it passes one longer than its whole
  // perimeter and the four sides read a single run of the sheet with no seam on any of them
  ?tileU:Float,
  // where the TOP goes instead of the sides' buffer, mapped 0..1 across the box onto `lidUV` —
  // a lid is a picture of a lid and not more of the same board. null = the top tiles with the sides
  ?lid:MeshBuf,
  // that top's rect in the lid sheet, [u0, v0, u1, v1]. openBox reads it for its FILL as well
  ?lidUV:Array<Float>,
}

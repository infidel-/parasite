package render.facility;

// the standing thing a FLAT contact quad is laid under, and the surface it has to stay on.
//
// replaced a seven-argument positional signature on render.facility.FacilityDetail.pool — four of
// them adjacent Floats, which is the mis-orderable list the style guide names
typedef FacilityPoolOpts = {
  // the footprint's centre, world
  cx:Float,
  cz:Float,
  // and its half extents in the object's OWN frame, i.e. BEFORE `yaw` turns it
  hw:Float,
  hd:Float,
  // the turn about its vertical axis, radians. the quad is turned with the thing
  yaw:Float,
  // the surface it stands on. the quad is laid FacilityStyle.POOL_EPS above this
  y:Float,
  // and that surface's own extent, world — the quad is shrunk to stay inside it rather than hanging
  // a gradient off the front of a shelf
  plate:FacilityGeom.Rect,
  // a FIXED world width for the falloff past the footprint, which is then the ramp's opaque core:
  // FacilityDetail.pool lays nine quads instead of one. Left out, the falloff is POOL_GROW of the half
  // extent, right for a box on a shelf and 1.8 units past the end of a 12-unit table run
  ?fade:Float,
}

package render.actors;

import render.world.ObjModels.PropArc;

// one pass of one lightning bolt's ribbon, for render.actors.PropFX.boltRibbon. it replaces what
// would have been an 18-positional-arg signature: the emitter is called TWICE per bolt down the same
// path — a wide soft halo and then the hot core over it — so everything describing the path has to
// be identical between the two calls and only `bright`, `wMul` and `edge` differ. a bare arg list of
// that length, called twice with three values changed, is exactly the mis-ordering the typedef rule
// exists to prevent.
//
// every point here is already in WORLD space. the bolt used to be laid out in a flat upright plane at
// the prop's own depth and offset from an anchor, which meant it could only ever travel left, right
// or up — never toward the camera
typedef BoltOpts = {
  arc:PropArc,   // the row this bolt is authored by: segs, jag, width, taper and glow are read off it
  h:Float,       // the prop's world height — every authored fraction scales by it
  ph:Float,      // per-cell phase, so two organs of a kind never strike alike
  bucket:Float,  // which strike this is. seeds the kink, so it MUST match between the two passes or
                 // the halo would run down a different zigzag than the core it is meant to be under
  slot:Int,      // which bolt slot within the prop, same role in that hash
  sx:Float,      // strike point on the body, world X
  sy:Float,      // strike point, world Y
  sz:Float,      // strike point, world Z
  ex:Float,      // tip, world X
  ey:Float,      // tip, world Y
  ez:Float,      // tip, world Z
  nx:Float,      // unit width axis, world X. perpendicular to BOTH the bolt and the view direction,
  ny:Float,      // so a bolt aimed straight at the camera still shows its full width instead of
  nz:Float,      // going edge-on and vanishing. carries the kink as well as the ribbon's half-width
  bright:Float,  // this pass's brightness at the centreline, before the row's `glow`
  wMul:Float,    // this pass's half-width as a multiple of the row's `width`
  edge:Float,    // and its brightness at the ribbon's OUTER edge as a fraction of the centreline.
                 // 1 is a flat bar (the core pass wants that — a bright thread with a hard edge),
                 // 0 falls off to nothing, which is the only reason the halo pass reads as a flare
                 // and not as a fat glowing plank
};

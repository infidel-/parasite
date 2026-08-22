package render.actors;

import render.world.ObjModels.PropTether;

// one pass of one tether's ribbon, for render.actors.PropFX.tetherRibbon. it exists for the reason
// render.actors.BoltOpts does: the emitter is called TWICE down the SAME path — a wide soft halo and
// then the core over it — so every field describing that path has to be identical between the two
// calls and only `bright`, `wMul` and `edge` differ. A fifteen-arg list called twice with three
// values changed is exactly the mis-ordering the options-typedef rule exists to prevent.
//
// every point here is already in WORLD space: a cord spans two cells and bows over the gap, so there
// is no local frame it could sensibly be authored in
typedef TetherOpts = {
  tether:PropTether, // the row this cord is authored by: segs, lift, jag, width, taper and glow are
                     // read off it, so the two passes cannot disagree about the shape
  h:Float,           // the prop's world height — every authored fraction scales by it
  ph:Float,          // per-cord phase, rolled off the bound actor's own id. it MUST match between
                     // the two passes, or the halo would waver down a different path than the core
                     // it is meant to sit under
  sx:Float,          // anchor on the prop's own surface, world X
  sy:Float,          // anchor, world Y
  sz:Float,          // anchor, world Z
  ex:Float,          // the bound actor's head, world X
  ey:Float,          // head, world Y
  ez:Float,          // head, world Z
  nx:Float,          // unit width axis, world X. perpendicular to BOTH the chord and the view
  ny:Float,          // direction, so a cord running straight at the camera still shows its full
  nz:Float,          // width instead of going edge-on. carries the waver as well as the half-width
  bright:Float,      // this pass's brightness at the centreline, before the row's `glow`
  wMul:Float,        // this pass's half-width as a multiple of the row's `width`
  edge:Float,        // and its brightness at the ribbon's OUTER edge as a fraction of the
                     // centreline. 1 is a flat bar (what the core pass wants — a bright thread with
                     // a hard edge), 0 falls off to nothing, which is the only reason the halo pass
                     // reads as a flare and not as a fat glowing plank
};

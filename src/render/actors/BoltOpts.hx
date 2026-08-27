package render.actors;

import render.actors.Ribbon.RibbonPass;
import render.world.ObjModels.PropArc;

// one pass of one lightning bolt's ribbon, for render.actors.PropFX.boltRibbon. it replaces what
// would have been an 18-positional-arg signature: the emitter is called TWICE per bolt down the same
// path — a wide soft halo and then the hot core over it — so everything describing the path has to
// be identical between the two calls and only `bright`, `wMul` and `edge` differ. A bare arg list of
// that length, called twice with three values changed, is exactly the mis-ordering the typedef rule
// exists to prevent.
//
// everything a bolt shares with any other kind of strip is in RibbonPass, including the note about
// world space: the bolt used to be laid out in a flat upright plane at the prop's own depth and
// offset from an anchor, which meant it could only ever travel left, right or up — never toward the
// camera. only the three fields below are a bolt's own
typedef BoltOpts = {
  > RibbonPass,
  arc:PropArc,   // the row this bolt is authored by: segs, jag, width, taper and glow are read off it
  bucket:Float,  // which strike this is. seeds the kink, so it MUST match between the two passes or
                 // the halo would run down a different zigzag than the core it is meant to be under
  slot:Int,      // which bolt slot within the prop, same role in that hash
};

package gen;

// the knobs gen.Subdivide cuts a rect with.
//
// one profile per THING BEING DIVIDED, not per area type: the compound splits into plots with one
// set of numbers and a building splits into rooms with another, and both go through the same
// splitter. The shape is citygen.CityProfile's layout half, which is where these names come from.
typedef _SplitProfile = {
  // smallest side a child may come out with. also sets the smallest rect that can be cut at all:
  // two of these plus the gap between them
  var minSide: Int;
  // a rect bigger than this on either axis usually splits rather than rolling earlyLeafChance
  var splitOver: Int;
  // and one bigger than this MUST split, whatever else says stop. the hard size contract a leaf
  // arrives under
  var maxSide: Int;
  // empty cells left between two siblings. this is what becomes the alley between two plots, or the
  // wall between two rooms — 0 for children that should touch
  var gap: Int;
  // how many times the recursion may cut. the practical size floor, together with minSide
  var depth: Int;
  // chance a mid-size rect stops early instead of cutting again, which is what makes the leaves
  // uneven. never applies to the rect the caller passed in, only to rects a cut produced
  var earlyLeafChance: Float;
  // a rect longer than this many times its width keeps cutting its long axis even when every other
  // rule says stop. without it the cut range can leave a 2-cell sliver beside a 15-cell child
  var maxAspect: Float;
}

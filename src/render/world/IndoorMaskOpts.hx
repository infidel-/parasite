package render.world;

// the per-area-kind tuning of render.world.IndoorMask.
//
// same shape and the same reasoning as render.world.VisionMaskOpts next door: the values live with
// the preset that measured them (FacilityStyle.INDOOR is the only one so far) and the comments here
// only say what a field IS. IndoorMask holds the live one in a static, set by attach(), because
// exactly one area is ever built
typedef IndoorMaskOpts = {
  // mask texels per cell. this mask carries a blurred step and nothing finer, so it wants far less
  // resolution than the vision mask's polygon edge does
  px:Int,
  // gaussian sigma the indoor plane is blurred by on its way into the mask, in WORLD units. this is
  // the whole transition: an actor walking through a door crossfades over roughly this distance
  blur:Float,
  // how far past an indoor cell's own boundary the region is grown, in WORLD units. a wall cell has
  // an indoor face and an outdoor face at the SAME xz, which a top-down mask cannot separate on its
  // own — growing to the inner face of the wall slab is what puts the two on opposite sides of the
  // boundary. FacilityStyle.WALL_T / 2 is that distance
  grow:Float,
  // the indoor fill, as a light colour (sRGB hex, decoded the way an AmbientLight's is)
  ambient:Int,
  // and its intensity. the two multiply into one irradiance that REPLACES the scene's ambient +
  // hemisphere indoors, so this is tuned against those two together and not against either alone
  intensity:Float,
  // what fraction of DIRECT light survives indoors: the moon, and every spotlight with it. see the
  // shader in IndoorMask.patch for why the two cannot be separated, and what that costs a caller
  direct:Float,
}

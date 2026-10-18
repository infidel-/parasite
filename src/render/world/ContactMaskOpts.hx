package render.world;

// the per-area-kind tuning of render.world.ContactMask.
//
// same shape and the same reasoning as render.world.IndoorMaskOpts and VisionMaskOpts beside it: the
// values live with the preset that measured them (FacilityStyle.CONTACT is the only one so far) and
// the comments here only say what a field IS. ContactMask holds the live one in a static, set by
// attach(), because exactly one area is ever built
typedef ContactMaskOpts = {
  // mask texels per cell. this one carries a BLURRED RAMP that the eye reads directly as a gradient
  // on the floor, where the indoor mask's step only has to land in the right place — so it wants
  // real resolution, and the indoor mask's own 8 would quantise the ramp into visible bands
  px:Int,
  // gaussian sigma the masonry footprint is blurred by, in WORLD units. THIS IS THE FALLOFF: it is
  // the whole reach of the contact shadow, and it replaces the reach-plus-gradient-texture pair a
  // quad-based version needs
  blur:Float,
  // how dark the floor goes where the mask reads solid, 0 = off .. 1 = black. note the blurred step
  // sits at HALF strength on the masonry boundary itself, so the darkest floor fragment — the one
  // touching the wall face — lands near strength/2 and this number is fitted against that, not
  // against a value anything actually renders at
  strength:Float,
}

// one masonry rectangle in WORLD xz, the shape ContactMask.attach paints from. structurally the same
// as render.facility.FacilityGeom.Rect, deliberately, so a caller hands its slabs straight over
// without converting or allocating
typedef ContactRect = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
}

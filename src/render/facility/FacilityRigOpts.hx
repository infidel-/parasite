package render.facility;

// the night rig one area kind is lit by: render.facility.FacilityScene.build's sky, fog and the three
// fill colours.
//
// replaced build(renderer, lampPool, sky, near, far), whose fill colours were constants inside it
// until the military base needed its own and the signature would have run to eight arguments
typedef FacilityRigOpts = {
  // background and fog colour, one and the same (render.world.VisionMask depends on it)
  sky:Int,
  // fog start and end, world units
  near:Float,
  far:Float,
  // the ambient fill
  ambient:Int,
  // the hemisphere's sky and ground tints
  hemiSky:Int,
  hemiGround:Int,
  // the moon, the only directional term
  moon:Int,
}

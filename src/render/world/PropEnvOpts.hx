package render.world;

// the per-area-kind tuning of render.world.PropEnv, and the same shape and reasoning as
// render.world.IndoorMaskOpts next door: the values live with the preset that measured them
// (FacilityStyle.PROP_ENV is the only one so far) and the comments here only say what a field IS.
//
// replaced a 4-argument PropEnv.attach(sky, horizon, ground, intensity)
typedef PropEnvOpts = {
  // the fake overhead light the GLINT reflects, as a world direction [x, y, z] — normalized in
  // attach, so write it at any length. it is NOT any light in the scene and must not be aimed like
  // one: this is the lamp bank a lab ceiling would carry, and a prop reflects it whether or not a
  // spotlight slot happens to be pointed there
  keyDir:Array<Float>,
  // the glint's colour, before `sheen` scales it. reads as the tube's own metal, so keep it near
  // `sky` — a highlight the room could not have cast is the one thing that gives the fake away
  key:Int,
  // the lobe's tightness: the exponent on dot(reflection, keyDir). low is a broad sheen over a whole
  // shelf, high is a hard spot that only a near-mirror facet catches
  gloss:Float,
  // and how bright the lobe lands. separate from `intensity` on purpose — the wash below fills a
  // shape in, this picks the edges out, and they are fitted against different failures
  sheen:Float,
  // the band a straight-UP reflection sees: the ceiling, and the fixtures hanging off it. the
  // brightest of the three by a wide margin, because in a lit room it is the only thing emitting
  sky:Int,
  // what a HORIZONTAL reflection sees, which is the room's walls. the value a vertical prop face
  // spends most of its reflection budget on, so it is the one tuned against the interior ladder
  horizon:Int,
  // and what a downward reflection sees: the floor, plus whatever is standing on it
  ground:Int,
  // scales the whole reflection on every material this dresses. the taste knob — the three colours
  // above set the SHAPE of the gradient and this sets how much of it lands
  intensity:Float,
}

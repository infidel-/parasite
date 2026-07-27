package render.particles;

// a placed street lamp for the light pool: bulb ground x/z (pushed out over the road edge) + the post
// grid cell (for player-distance gating). its own module so every consumer imports one top-level type.
// a DEAD lamp never becomes a LampPost at all (SceneSetup drops it) — only its model stays on the street
typedef LampPost = {
  x:Float,
  z:Float,
  col:Int,
  row:Int,
  phase:Float, // flicker phase; 0 = a healthy bulb, burns steady and never sputters
  flick:Float, // this frame's flicker multiplier (1 = steady), published by LampLights for the fake ground shadows
};

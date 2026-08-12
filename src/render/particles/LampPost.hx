package render.particles;

// a placed street lamp for the light pool: bulb ground x/z (pushed out over the road edge) + the post
// grid cell (for player-distance gating). its own module so every consumer imports one top-level type.
// a DEAD lamp never becomes a LampPost at all (SceneSetup drops it) — only its model stays on the street
typedef LampPost = {
  x:Float,
  z:Float,
  y:Float,     // bulb height. per-post, not a pool constant: a street bulb hangs at CELL * yMul while
               // a sewer WALL lamp is bracketed low on the wall face
  col:Int,
  row:Int,
  phase:Float, // flicker phase; 0 = a healthy bulb, burns steady and never sputters
  flick:Float, // this frame's flicker multiplier (1 = steady), published by LampLights for the fake ground shadows
  mul:Float,   // intensity multiplier on the pooled spotlight; 1 = a full street lamp, < 1 = a weak fixture
};

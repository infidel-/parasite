package render.particles;

// a placed street lamp for the light pool: bulb ground x/z (pushed out over the road edge) + the post
// grid cell (for player-distance gating). its own module so every consumer imports one top-level type.
// a DEAD lamp never becomes a LampPost at all (SceneSetup drops it) — only its model stays on the street
typedef LampPost = {
  x:Float,
  z:Float,
  y:Float,     // bulb height. per-post, not a pool constant: a street bulb hangs at CELL * yMul while
               // a sewer WALL lamp is bracketed low on the wall face
  tx:Float,    // ground point the spotlight AIMS at. a street lamp pools straight down (tx/tz = x/z);
  tz:Float,    // a low wall bracket aims metres out along the wall normal, so its beam rakes the floor
  color:Int,   // bulb tint, published onto whichever pool slot serves this post. per-post because one
               // pool serves BOTH kinds underground: a slot carries a manhole shaft one frame and a
               // wall fixture the next, and the two are deliberately different lights
  col:Int,
  row:Int,
  phase:Float, // flicker phase; 0 = a healthy bulb, burns steady and never sputters
  flick:Float, // this frame's flicker multiplier (1 = steady), published by LampLights for the fake ground shadows
  mul:Float,   // intensity multiplier on the pooled spotlight; 1 = a full street lamp, < 1 = a weak fixture
  // never takes a shadow-casting slot: routed after every casting post and, if one still lands in a
  // caster slot, its shadow is off and its map never re-renders. a facility room fixture throws no
  // shadow anyone can see (0.000-0.006% of pixels) and cost 1.7-1.9 spot-map renders a frame on a walk
  ?noCast:Bool,
  // its light or what it lights MOVES (the lab's turning beacon, a lamp over a turning fan): a caster
  // slot serving it re-renders its map every frame instead of only on a hand-off (LampLights.update)
  ?moving:Bool,
};

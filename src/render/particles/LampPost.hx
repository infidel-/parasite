package render.particles;

// a placed street lamp for the light pool: bulb ground x/z (pushed out over the road edge) + the post
// grid cell (for player-distance gating). its own module so every consumer imports one top-level type
typedef LampPost = { x:Float, z:Float, col:Int, row:Int };

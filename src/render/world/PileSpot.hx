package render.world;

// where one street pile is being dealt (render.world.StreetProps.deal)
typedef PileSpot = {
  x:Float,         // world anchor: the middle of the back line (HEAP, STACK) or the prop itself (LOAD)
  z:Float,
  y:Float,         // the floor under it (a walkway stands CURB_H up)
  yaw:Float,       // square to the street (HEAP, STACK) or the prop's own yaw (LOAD)
  nx:Float,        // unit step off the back line toward the street (HEAP, STACK)
  nz:Float,
  span:Float,      // how far either way along the back line a piece may stand (HEAP, STACK)
  rng:Void->Float, // the cell's own stream, so a cell deals the same pile on every entry
};

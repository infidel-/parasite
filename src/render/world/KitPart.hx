package render.world;

import three.Three;

// one building's slice of a wall-kit chunk (render.world.KitChunk)
typedef KitPart = {
  // the building's own view of the chunk geometry (its drawRange is the slice), tagged userData.b and
  // never drawn itself (an invisible material): it is what render.Occlusion buckets, hides and ghosts
  proxy:Mesh,
  // the slice's first index in the chunk geometry
  start:Int,
  // its index count
  count:Int,
  // whether the chunk mesh draws the slice, as last synced off proxy.visible (StreetProps.sync)
  shown:Bool,
};

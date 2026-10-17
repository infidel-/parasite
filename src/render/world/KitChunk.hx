package render.world;

import three.Three;

// the wall kit of every dressed building in one render.Chunks cell, merged (render.world.StreetProps)
typedef KitChunk = {
  // the merged kit: one draw while every building in it is solid, one per run of solid slices otherwise
  mesh:Mesh,
  // its buildings' slices, in index order
  parts:Array<KitPart>,
};

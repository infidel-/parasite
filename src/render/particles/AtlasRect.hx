package render.particles;

// one atlas cell (or its opaque content box) as a UV rectangle into the shared atlas texture, plus
// that box's size as a fraction of the full cell. lets a batched decal sample the atlas directly
// instead of owning a cropped copy of its cell, so every decal sharing a material shares one draw
typedef AtlasRect = {
  var u:Float;   // left edge, atlas UV space
  var v:Float;   // bottom edge, atlas UV space (texture flipY is on, so v grows upward)
  var w:Float;   // width as a fraction of the atlas
  var h:Float;   // height as a fraction of the atlas
  var fw:Float;  // content width as a fraction of the full cell (1 = the whole cell)
  var fh:Float;  // content height as a fraction of the full cell (1 = the whole cell)
};

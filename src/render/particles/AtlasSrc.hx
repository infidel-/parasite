package render.particles;

// where one atlas cell's pixels ACTUALLY come from, after render.particles.Sprites.atlasFor has
// applied the 3D-only redirections. The cell asked for is an entities64 (or actor-sheet) frame, and
// what comes back may be a different image, at a different cell size, at different coordinates —
// see the two redirections in atlasFor's own header
typedef AtlasSrc = {
  // the decoded <img> to crop from. null (or still decoding) means "retry next frame"
  var img:Dynamic;
  // that image's cell size in pixels: 64 for entities64, 128 for an actor skin sheet, 256 for a
  // facility bench decoration pack
  var t:Int;
  // and the cell to crop, in THAT image's grid — not the caller's
  var ix:Int;
  var iy:Int;
};

package render.particles;

// where one atlas cell's pixels ACTUALLY come from, after render.particles.Sprites.atlasFor has
// applied its redirections. The cell asked for is an entities64 frame ID (or an actor-sheet cell),
// and what comes back may be a different image, at a different cell size, at different coordinates —
// see atlasFor's own header
typedef AtlasSrc = {
  // the decoded <img> to crop from. still decoding means "retry next frame"; null means the frame has
  // no art left (the 64 px sheet is retired) and draws nothing
  var img:Dynamic;
  // that image's cell size in pixels: 128 for an actor skin sheet or the entities128 redraw, 170 for
  // the clue pack, 256 for a facility bench decoration pack, 64 for the other 64 px sheets
  var t:Int;
  // and the cell to crop, in THAT image's grid — not the caller's
  var ix:Int;
  var iy:Int;
};

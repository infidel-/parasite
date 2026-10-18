package render.particles;

// where a BATCHED ground decal cuts its entities64 frame from (render.particles.Sprites.batchCell):
// atlasTex and cellRect take one whole image, so a frame the 128 redraw replaced (Const.HD128) has to
// name that image and its cell there, where atlasFor would have redirected it per cell
typedef BatchCell = {
  // the Images.getImage name to hand atlasTex and cellRect
  var name:String;
  // and the cell, in THAT image's grid
  var ix:Int;
  var iy:Int;
};

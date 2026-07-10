package render.particles;

import three.Three;

// a content-cropped atlas cell: texture trimmed to the cell's opaque bounding box, plus that
// box's size as a fraction (0..1) of the full cell. lets small sprites (debris) paint at their
// true pixel footprint, centered on the point, instead of stretched across the whole SIZE quad
typedef GroundSprite = {
  var tex:CanvasTexture; // content-trimmed texture
  var fw:Float;          // content width as a fraction of the full cell
  var fh:Float;          // content height as a fraction of the full cell
};

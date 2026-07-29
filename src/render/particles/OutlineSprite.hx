package render.particles;

import three.Three;

// a sprite's outline ring: the cell's alpha dilated outward and the original punched back out, so
// only the band just outside the silhouette remains (flooded white, tinted at paint time). the art
// is inset by the ring width inside the crop, so the quad must be painted at `scale` times the
// sprite's own scale for the ring to hug the un-inset sprite exactly
typedef OutlineSprite = {
  var tex:CanvasTexture; // white ring texture (interior punched out)
  var scale:Float;       // quad-scale factor lining the ring up with the un-inset sprite
};

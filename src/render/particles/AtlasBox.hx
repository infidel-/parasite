package render.particles;

// one atlas cell's opaque bounding box, in that cell's own pixels (0..t). the raw scan behind
// GroundSprite's fractions, handed out on its own for the one caller that wants the numbers without
// a texture: render.facility.FacilityModel sizes and places a bench decoration's contact pool off
// this while an area is derived, which is a step BEFORE the sprite pool exists (see Sprites.cellBox)
typedef AtlasBox = {
  // the box's top-left in cell pixels, y growing DOWNWARD as atlas rows do
  var x:Int;
  var y:Int;
  // and its size. never zero — a fully transparent cell falls back to the whole cell
  var w:Int;
  var h:Int;
};

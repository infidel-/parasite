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
  // the CELL the box was scanned in, in pixels. carried on the box because every consumer turns
  // these pixels into a cell FRACTION, and the cell is no longer one number: a facility bench
  // decoration is scanned at Const.DECO_PACK_CELL 256 off a pack sheet where the frame it replaces
  // is 64 (Const.FACILITY_DECO_HD), and an actor at 128. Dividing by Const.TILE_SIZE_CLEAN was
  // correct for exactly as long as there was one atlas
  var t:Int;
};

// which piece of room furniture a facility floor decoration draws as in 3D.
//
// Int-backed on purpose: render.facility.FacilityModel stamps these into a per-cell grid as kind + 1
// (0 meaning "no fitting here"), which is the same shape the `table` grid beside it takes

enum abstract _FittingKind(Int) from Int to Int
{
  var FIT_SHELVING = 0; // open metal shelving with boxes on it
  var FIT_BOOKCASE = 1; // a case of books, and the wooden shelf of bottles that reads the same
  var FIT_RACK = 2;     // a server rack, the one fitting carrying lights
  var FIT_RACK_LOW = 3; // the same cabinet one tile tall: the stacked server units of the LOW list
  // one twin-door lab case for the whole top of row 8: a fridge, a glass-door freezer, a storage
  // cabinet and a biohazard safety cabinet are one silhouette with four decals on it, and a decal is
  // not worth a kind — see art/textures.json's facility/deco-cabinet-front
  var FIT_CABINET = 4;
  // and one machine casing for the rest of row 8 plus two of the low list: a hopper filler, an
  // analyser console, a CNC enclosure, a gear press, a bench lathe. Its front TILES rather than
  // mapping 0..1, which is what lets ONE image serve two heights — see FacilityStyle.DECO_MACHINE_H
  var FIT_MACHINE = 5;
  // and that same casing knee-high, for the low list's placard panel and grey appliance cabinet
  var FIT_MACHINE_LOW = 6;
  // the ones that are not emitted at all. they are round, and render.facility.FacilityGeom emits
  // axis-aligned quads only, so these stamp their cell for everything that reads `deco` and are
  // then drawn as instanced glbs — see FacilityDeco.drums and FacilityGround.bins.
  //
  // THE THREE DRUMS ARE THREE KINDS AND NOT ONE, because the low list draws three different barrels
  // and each livery is its own glb: render.Models.instanced is keyed by PATH and carries no
  // per-instance UV offset, so a livery is a batch and a batch is a draw call. All three are the
  // same mesh repainted — see art/models.json's facility/drum-steel
  var FIT_DRUM_STEEL = 7; // grey drum, yellow hazard triangle (entities64 12/1)
  var FIT_DRUM_BIO = 8;   // yellow drum, biohazard trefoil (12/2)
  var FIT_DRUM_RAD = 9;   // red drum, radiation trefoil (12/5)
  var FIT_BIN = 10;       // a lidded waste bin, the compound's own outdoor bin standing indoors
}

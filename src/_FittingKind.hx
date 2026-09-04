// which piece of room furniture a facility floor decoration draws as in 3D.
//
// Int-backed on purpose: render.facility.FacilityModel stamps these into a per-cell grid as kind + 1
// (0 meaning "no fitting here"), which is the same shape the `table` grid beside it takes

enum abstract _FittingKind(Int) from Int to Int
{
  var FIT_SHELVING = 0; // open metal shelving with boxes on it
  var FIT_BOOKCASE = 1; // a case of books, and the wooden shelf of bottles that reads the same
  var FIT_RACK = 2;     // a server rack, the one fitting carrying lights
}

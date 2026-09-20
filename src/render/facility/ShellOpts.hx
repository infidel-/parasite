package render.facility;

import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;

// how one AREA KIND reads an indoor shell out of its saved cell grid.
//
// replaces the four things render.facility.FacilityModel.fromArea used to hardcode, so the same
// derivation — structures, window runs, doors, decorations, room theming — serves both the
// compound and the corp tower. Everything NOT here is genuinely generic and stays shared.
typedef ShellOpts = {
  // which area kind this is, carried onto the model so a shared pass can branch. 'facility' or
  // 'corp'
  var kind: String;
  // the art every surface of this kind is dressed in
  var tex: ShellTex;
  // tile id -> the horizontal surface it paints
  var surfOf: Int -> Surf;
  // tile id -> what it blocks
  var wallOf: Int -> Wall;
  // may a structure come back flagged as a HANGAR — the concrete-majority test? A compound has one
  // shed and needs it. A corp floor must not: its LIFT CAR is nine cells of concrete inside its own
  // ring of posts and glazing, so the same test calls a lift a hangar and arches a barrel vault
  // over it
  var hangars: Bool;
}

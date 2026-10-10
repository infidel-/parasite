package render.facility;

import render.facility.FacilityModel.Surf;

// the ART one indoor shell is dressed in, as data rather than as constants in the emitter.
//
// WHY IT EXISTS: render.facility.FacilityGeom builds the floors, walls, glazing and roof of any
// indoor building from the saved cell grid, and everything it does is generic — the wall faces, the
// window runs, the slab insets, the parapet. The only facility-specific thing in the whole file was
// the sixteen `FacilityStyle.FLOOR_TILE` / `WALL_ROOM` / … constants at the flush. Moving those onto
// the MODEL is what lets the corp tower reuse the emitter with an entirely new art set, which is
// the brief: share the code, share nothing else.
//
// `floor` and `wallInto` are INDEXED BY Surf, and a null entry means "this area has no such
// surface". A facility fills six of the floor slots and a corp floor fills eight different ones;
// an empty buffer emits no mesh at all, so the unused slots cost nothing.
typedef ShellTex = {
  // the horizontal surface each Surf paints, indexed by Surf
  var floor: Array<String>;
  // the exterior cladding
  var wallOut: String;
  // and an INTERIOR wall face, indexed by the Surf the face LOOKS INTO — which is the rule the
  // emitter has always used and the reason a corridor is painted board where the room the other
  // side of the same slab is tiled
  var wallInto: Array<String>;
  // the two glazing arts, one per window RUN LENGTH (nothing is ever stretched, so a 2-cell opening
  // and a 3-cell one are two different images and not one image at two scales)
  var pane: String;
  var pane2: String;
  // and those two images' OWN width:height, measured off the built crop. the quad's height is
  // DERIVED from it (FacilityGeom.paneTall) and never chosen, so these are a property of the art
  // and have to travel with it — a corp unit drawn at the compound's 2.90 would be a stretch
  var aspect: Float;
  var aspect2: Float;
  // the high light well, which is glazed and not see-through
  var paneHigh: String;
  // the aluminium capping that closes a window run's reveal
  var head: String;
  // the roof deck and the coping cap along its edge
  var roof: String;
  var coping: String;
  // the roll-up shutter strip. null where the area has none
  var shutter: String;
  // THE LIFT DOORWAY'S OWN TWO DETAILS, null where the area has none. A doorway's reveal is painted
  // in `circ` whichever way it faces (see below), which is right for an office door and left a lift
  // car's opening with no read at all: the jambs and the -0.2..0 threshold strip both came out in
  // the corridor's own board. `pocket` is the near-black slot the leaves slide into, run as a strip
  // down each jamb, and `sill` is the metal plate under the opening where the two floors meet
  var pocket: String;
  var sill: String;
  // the painted door pairs, indexed by render.facility.FacilityModel.Look. ONE image holds BOTH
  // leaves of an opening — FacilityDoors.leafGeom maps its left half onto each leaf and takes the
  // mirror for the other — so this is four images and not eight. It is here and not a constant in
  // the emitter because a door was the LAST facility texture the corp tower still wore
  var door: Array<String>;
  // which surface is CIRCULATION — the corridor and every door cell. a doorway's reveal is painted
  // in it whichever way the opening faces, because a doorway belongs to the circulation and not to
  // either space it joins, and it is the fallback finish for a cell whose own surface has no art
  var circ: Surf;
  // the hood of the bulkhead lamp over an exterior door
  var hood: String;
  // ---- the OUTDOORS, which only a compound and a military base have. A corp tower is all indoor
  // and never reaches the passes that read these, so it leaves them out. Every one was a facility
  // constant at its emitter until the base needed the same emitters in its own art
  // the hangar's cladding and its barrel vault
  @:optional var hangarWall: String;
  @:optional var vault: String;
  // the four outdoor grounds the lot is laid in, and the kerb edging between them
  @:optional var road: String;
  @:optional var walkway: String;
  @:optional var lot: String;
  @:optional var kerb: String;
  // the line paint, and the keep-clear hatch inside an exterior door
  @:optional var paint: String;
  @:optional var zone: String;
  // the damp band at a wall's foot, the cable runs and the wall/floor electrical kit sheet
  @:optional var grime: String;
  @:optional var cable: String;
  @:optional var elec: String;
  // the light colours: the outdoor masts and their cones, the indoor fixtures and the window spill
  // they cast, and the bulkhead lamps over exterior doors
  @:optional var mastColor: Int;
  @:optional var lampColor: Int;
  @:optional var doorLampColor: Int;
}

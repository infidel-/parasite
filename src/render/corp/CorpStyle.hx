package render.corp;

import Const;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Surf;
import render.facility.ShellOpts;

// ONE CAR on the traffic sheet: where its picture is, and how big it is drawn.
//
// the uv rect is in 0..1 of the BUILT texture and is what render.corp.CorpCrowd hands the shader
// per instance; `len`/`wide` are world units and are DERIVED from the same crop, never chosen
typedef CarCell = {
  var u0:Float;    // the crop's left edge
  var v0:Float;    // and its bottom edge, with flipY already folded in
  var du:Float;    // its width
  var dv:Float;    // and its height
  var len:Float;   // the car's world length, nose to tail
  var wide:Float;  // and its width, which is `len` times the crop's own aspect
};

// every art path and tuning constant for the CORP TOWER, and the ShellOpts that says how its saved
// grid is read.
//
// the corp office shares render.facility's EMITTERS and none of its art. That is the whole shape of
// this file: it fills the same ShellTex the compound's FacilityStyle.shell() fills, with a
// different set of labels, so render.facility.FacilityGeom builds a tower floor without knowing
// one exists.
class CorpStyle
{
  // ---- the shell ---------------------------------------------------------------------------

  // the colour the fog and the sky share. they MUST be the same value: render.world.VisionMask's
  // rim channel takes visibility to zero at the area border, and zero only reads as nothing rather
  // than as a silhouette when the surface fades toward what is behind it
  public static inline var SKY = 0x0a0e16;
  // fog. PULLED IN hard against the facility's 200/460, because a corp floor is small and what is
  // past its edge is a 20-storey drop rather than more lot — the far street belongs in haze
  public static inline var FOG_NEAR = 90.0;
  public static inline var FOG_FAR = 240.0;

  // only the lit glazing blooms
  public static inline var BLOOM_THRESHOLD = 0.72;

  // how far a glb prop is still drawn from the camera, world units
  public static inline var PROP_CULL_R = 120.0;

  // ---- art ---------------------------------------------------------------------------------
  //
  // the corp set, authored for this kind and shared with nothing. Values are FITTED against the
  // facility's own built ladder rather than predicted: an interior floor lands 0.090-0.124 linear
  // against the compound's 0.094-0.135, an interior wall 0.115-0.219 against its 0.137-0.159, and
  // the exterior 0.031 against its 0.033. Each label's gamma is in art/textures.json.
  //
  // EIGHT of the nine floors come off TWO packed 2x2 sheets, which is the trade docs/3d-textures.md
  // describes: a quarter of the cost, roughly double the wrap error, and the neighbours fixing a
  // chroma no solo roll reaches — right for a family of carpets and stones and wrong for anything
  // that tiles across a whole facade. The server room's raised-access panel is the one solo floor
  // for exactly that reason: its grid has to close, and a packed cell's wrap error is a visible
  // step in a panel joint.
  public static inline var WALL_EXTERIOR = 'textures/corp/wall-curtain.png';
  // the corridor, the open plan, the cubicle farm and the server room share one painted
  // plasterboard: in a real tower they are the same wall, and a room reads by its FLOOR and its
  // furniture. the four that differ are the four with a material of their own
  public static inline var WALL_OFFICE = 'textures/corp/wall-office.png';
  public static inline var WALL_MEETING = 'textures/corp/wall-meeting.png';
  public static inline var WALL_KITCHEN = 'textures/corp/wall-kitchen.png';
  public static inline var WALL_WASHROOM = 'textures/corp/wall-washroom.png';
  public static inline var WALL_EXEC = 'textures/corp/wall-exec.png';
  public static inline var WALL_LIFT = 'textures/corp/wall-lift.png';

  public static inline var FLOOR_CARPET = 'textures/corp/floor-carpet.png';
  public static inline var FLOOR_OPEN = 'textures/corp/floor-open.png';
  public static inline var FLOOR_CUBICLE = 'textures/corp/floor-cubicle.png';
  public static inline var FLOOR_MEETING = 'textures/corp/floor-meeting.png';
  public static inline var FLOOR_KITCHEN = 'textures/corp/floor-kitchen.png';
  public static inline var FLOOR_EXEC = 'textures/corp/floor-exec.png';
  public static inline var FLOOR_WASHROOM = 'textures/corp/floor-washroom.png';
  public static inline var FLOOR_SERVER = 'textures/corp/floor-server.png';
  public static inline var FLOOR_LIFT = 'textures/corp/floor-lift.png';

  // one capping serves the wall head and the window head both: they ARE the same extrusion seen
  // from the same angle, which is the one case docs/3d-textures.md allows a label to be reused
  public static inline var CAP = 'textures/corp/cap-alu.png';
  public static inline var COPING = 'textures/corp/coping.png';
  // the glazing, one image per RUN LENGTH. their aspects are MEASURED off the built crops
  // (512x183 and 512x280) and not chosen — see ShellTex.aspect
  public static inline var WINDOW_3 = 'textures/corp/window-3bay.png';
  public static inline var WINDOW_2 = 'textures/corp/window-2bay.png';
  public static inline var WINDOW_ASPECT = 512 / 183.0;
  public static inline var WINDOW_ASPECT_2 = 512 / 280.0;

  // the FITTING art. one texture per FACE — a top is a different surface from a front, and one
  // sheet over both is the mistake docs/3d-geometry.md opens with
  public static inline var DESK_TOP = 'textures/corp/desk-top.png';
  public static inline var DESK_FRONT = 'textures/corp/desk-front.png';
  public static inline var DESK_SIDE = 'textures/corp/desk-side.png';
  public static inline var PARTITION = 'textures/corp/partition.png';
  public static inline var COUNTER_TOP = 'textures/corp/counter-top.png';
  public static inline var COUNTER_FRONT = 'textures/corp/counter-front.png';
  public static inline var VANITY_TOP = 'textures/corp/vanity-top.png';
  public static inline var STALL_PANEL = 'textures/corp/stall-panel.png';
  public static inline var TABLE_TOP = 'textures/corp/table-top.png';
  public static inline var TABLE_SIDE = 'textures/corp/table-side.png';
  public static inline var RACK_FRONT = 'textures/corp/rack-front.png';
  public static inline var RACK_SIDE = 'textures/corp/rack-side.png';
  // and the LID, which is its OWN surface and not the flank seen from above — the rule
  // docs/3d-geometry.md opens with. Capped in RACK_SIDE, every cabinet in the room wore its
  // perforated flank across its top
  public static inline var RACK_TOP = 'textures/corp/rack-top.png';

  // THE BLINKING STATUS FIELD ON A RACK'S FRONT, read off corp/rack-front.png rather than laid on
  // an even grid — the trap render.facility.FacilityDeco.lights' own header records, where a
  // regular lattice put specks across the vent mesh. The corp image holds THREE cabinets across
  // with EIGHT units each, and every unit's dots are a short row at 0.242 / 0.566 / 0.891 of the
  // image width; LED_U0/U1 are the lerp those three centres fall out of, so U1 past 1.0 is
  // arithmetic and not a band the art has
  public static inline var LED_U0 = 0.080;
  public static inline var LED_U1 = 1.053;
  public static inline var LED_COLS = 3;
  public static inline var LED_ROWS = 8;
  public static inline var LED_SIZE = 0.20;
  // and the BAND up the face those eight rows sit in. The art's own frame leaves a margin top and
  // bottom, so a field spread over the whole RACK_H would put its first and last row on steel:
  // the units run 0.104 .. 0.935 of the face, which is 0.42 .. 3.74 of a 4.0 cabinet
  public static inline var LED_Y0 = 0.42;
  public static inline var LED_H = 3.32;

  // the cable drape between two cabinets of one rank, ON their lids. bow swings a run sideways off
  // the straight chord and wave keeps two of them from being parallel curves —
  // render.facility.StripOpts spells both out.
  //
  // AND NO SAG, which is the one thing to get right here: the ribbon lies FLAT so that the camera,
  // which looks down at 51 degrees, sees its width — and `sag` is taken out of world DOWN, so on a
  // flat ribbon it does not hang the run, it sinks its middle into the lid it is lying on
  public static inline var CABLE_BOW = 0.55;
  public static inline var CABLE_WAVE = 0.14;
  public static inline var CABLE_Y = 0.10;
  // three strands per gap, each with its own bow sign and phase: one ribbon reads as a scratch on
  // the lid and a patch bundle is what a rank of cabinets actually carries
  public static inline var CABLE_N = 3;
  public static inline var MIRROR = 'textures/corp/mirror.png';

  // THE FOUR DOOR PAIRS, indexed by render.facility.FacilityModel.Look — the last facility texture
  // the tower still wore. Off ONE 2x2 sheet and not four solo rolls, which is the one place packing
  // is not a trade but the only route: a leaf is LEAF_W 2.0 x DOOR_H 4.0, so the pair maps a 0..1
  // face of aspect 1.0 and each LEAF reads at 0.5 — under the ~0.64 aspect floor a 1k generation
  // can produce at all. Nothing here tiles, so packing's own cost (a doubled wrap error) is nil
  public static inline var DOOR_GLASS = 'textures/corp/door-glass.png';
  public static inline var DOOR_OFFICE = 'textures/corp/door-office.png';
  public static inline var DOOR_STEEL = 'textures/corp/door-steel.png';
  public static inline var DOOR_PRIVATE = 'textures/corp/door-private.png';
  // and the lift pair, which is SOLO where the other four are quadrants of one sheet: the 2x2 was
  // already spent, and a sliding pair is a different drawing anyway — two blank panels on one
  // seam, where a hinged pair shows its stiles and a lever
  public static inline var DOOR_LIFT = 'textures/corp/door-lift.png';

  // ---- the fittings ------------------------------------------------------------------------
  //
  // every one of these is written at the compound's own scale, where FacilityStyle.WALL_H 6.0 is
  // one 3 m storey and a unit is therefore HALF A METRE. So a desk at 1.5 is 75 cm, a kitchen
  // counter at 1.8 is 90 cm, a cubicle spine at 2.8 is 1.4 m and a server rack at 4.0 is 2 m —
  // real heights, not chosen proportions.
  public static inline var DESK_H = 1.5;
  public static inline var COUNTER_H = 1.8;
  public static inline var TABLE_H = 1.5;
  public static inline var VANITY_H = 1.7;
  // the cubicle spine. 1.4 m is a real low-wall partition: over a seated head and under a standing
  // one, which is the whole point of the thing
  public static inline var PARTITION_H = 2.8;
  public static inline var PARTITION_T = 0.4;
  // a WC cubicle's own divider, 1.9 m, and a 15 cm panel
  public static inline var STALL_H = 3.8;
  public static inline var STALL_T = 0.3;
  // the leaf that closes a cubicle, and the two gaps that say it is a door and not a wall: it
  // stops STALL_DOOR_GAP short of the floor, the way every public cubicle in the world does, and
  // leaves a reveal at each jamb so the divider reads THROUGH the opening
  public static inline var STALL_DOOR_GAP = 0.6;
  public static inline var STALL_DOOR_REVEAL = 0.14;
  // the mirror band over the basin run, sill to head
  public static inline var MIRROR_Y0 = 2.2;
  public static inline var MIRROR_Y1 = 4.4;
  // how far a fitting is pulled back inside its cell, so two units in a run still read as two and
  // a unit against masonry does not z-fight the wall slab
  public static inline var FIT_INSET = 0.12;
  // how much EDGE a boardroom or executive slab shows. it keeps a cap and this much fascia and
  // nothing else, with `corp/table-leg` standing under it: a 3x3 block of table tile is one 6 m
  // top, and a box of quads under a 6 m top is a plinth the size of a car
  public static inline var TABLE_FASCIA = 0.26;
  // the two hand-modelled tables. built at WORLD SIZE, so render.Models.instanced (which scales by
  // HEIGHT alone) scales them by exactly 1 and every number in the build script is the game's
  public static inline var DESK_GLB_H = 1.5;
  public static inline var DESK_GLB_W = 3.76;
  public static inline var LEG_H = 1.24;
  public static inline var LEG_W = 0.46;
  // the waste bin, the one ROUND piece of the tower's furniture and so the only one of the
  // decoration families that is a glb rather than emitted quads. 0.9 is 45 cm tall
  public static inline var BIN_H = 0.9;
  public static inline var BIN_W = 0.62;
  // a server rack. 2 m tall and 1 m deep, standing against the aisle it is reached from
  public static inline var RACK_H = 4.0;
  public static inline var RACK_D = 2.0;

  // the material scales. a MATERIAL scale and never the object's own size: the laminate grain, the
  // drawer course, the felt weave and the perforation pitch are each chosen against the thing they
  // draw. the drawer front's art carries THREE courses over its square, so at 3.0 a 1.5-high
  // carcass shows half of them, which is the two drawers a 75 cm pedestal really has
  public static inline var DESK_TILE = 4.0;
  public static inline var DESK_FRONT_TILE = 3.0;
  public static inline var COUNTER_TILE = 4.0;
  public static inline var PARTITION_TILE = 2.8;
  public static inline var RACK_TILE = 2.0;
  public static inline var MIRROR_TILE = 4.4;

  // ---- the glb props -------------------------------------------------------------------------
  //
  // seven models, and the split between them is docs/3d-models.md's own triage rather than a
  // preference: the PLANT is generated (a head of forty leaves has no parametric description), and
  // the chair, the monitor, the keyboard and the WC pan are HAND-MODELLED because each of their
  // briefs is a number on this list. The cooler and the printer are generated because a stepped
  // body with a recessed tray IS a silhouette.
  //
  // every height is the number render.Models.instanced scales the mesh to, and it scales by HEIGHT
  // ALONE — so a width here is a claim about the footprint the contact field darkens and never a
  // second scale.
  public static inline var CHAIR_H = 2.2;      // 1.1 m to the top of the back
  public static inline var CHAIR_W = 1.3;
  public static inline var CHAIR_YAW_JIT = 0.30;
  // how far the chair's centre stands back from the desk cell's own edge, into the seat cell
  // WRITTEN AS THE SUM THAT PRODUCED IT so the coupling cannot be edited away. It was 1.35, which
  // is INSIDE the desk: the offset is measured from the desk CELL's centre and the carcass reaches
  // CELL / 2 - FIT_INSET = 1.88, so a 1.3-wide seat sat 0.70 .. 2.00 and 1.18 of its width was
  // buried in the desk it was supposed to be pulled up to. CELL / 2 puts its centre on the desk's
  // own edge; + CHAIR_W / 2 clears it entirely; - CHAIR_TUCK slides it back under the worktop's
  // overhang, which is where a pushed-in chair sits
  public static inline var CHAIR_TUCK = 0.42;
  public static inline var CHAIR_OUT = 4.0 / 2 + 1.3 / 2 - CHAIR_TUCK;
  public static inline var MON_H = 1.66;       // the built mesh exactly, so the batch's scale is 1
  public static inline var MON_W = 1.95;
  public static inline var MON_D = 0.45;
  public static inline var KEY_H = 0.09;
  public static inline var KEY_W = 1.60;
  public static inline var KEY_D = 0.58;
  // where the two sit on the worktop, measured from the desk cell's BACK edge forward
  public static inline var MON_BACK = 0.85;
  public static inline var KEY_FWD = 2.55;
  // one desk cell in this many carries a workstation. A DESK RUN IS NOT A CALL CENTRE: every cell
  // manned puts a monitor every 2 m down a wall, which reads as a bank of screens rather than as
  // an office
  public static inline var WORK_EVERY = 2;
  public static inline var PLANT_H = 2.8;      // 1.4 m
  public static inline var PLANT_W = 1.35;
  public static inline var COOLER_H = 2.2;     // 1.1 m
  public static inline var COOLER_W = 0.55;
  public static inline var PRINTER_H = 2.2;
  public static inline var PRINTER_W = 1.05;
  public static inline var PRINTER_D = 1.30;
  public static inline var WC_H = 1.5;
  public static inline var WC_W = 0.80;
  public static inline var WC_D = 1.40;        // built to this exactly, so the cistern meets masonry
  // how far a wall-hugging prop's back stands off the masonry FACE (and not off the cell boundary,
  // which is a whole unit away — FacilityGeom.slab is what a corp wall really is)
  public static inline var PROP_GAP = 0.10;
  // one candidate cell in this many carries a floor prop, per family. a stride over the whole
  // candidate list and never a counter cap: the scan is row-major, so a cap spends the allowance
  // on the northernmost rooms (render.facility.FacilityDebris records it)
  public static inline var FLOOR_MAX = 10;

  // ---- the dressing --------------------------------------------------------------------------
  //
  // two PACK64 sheets and one 2x2 of signs. an 8x8 sheet is the wrong grid for a billboard and the
  // right one here, which is the measurement docs/3d-textures.md carries: a 1024 cut into 64 cells
  // hands each object ~89 px, and over the ~0.8 units one of these is DRAWN at that is 111 texels
  // per unit — half again past the carpet's own. density is art px over the size a thing is drawn
  // at, never over the cell it was cut from
  public static inline var CLUTTER_DESK_TEX = 'textures/corp/desk-clutter.png';
  public static inline var CLUTTER_UTIL_TEX = 'textures/corp/util-clutter.png';
  public static inline var CLUTTER_COLS = 8;
  public static inline var CLUTTER_CELLS = 64;
  // how many items a worktop cell may roll, and the roll REACHES ZERO on purpose: the empty cells
  // are what stop a desk run reading as a grid, which is the whole complaint this family answers
  public static inline var CLUTTER_MAX = 3;
  public static inline var CLUTTER_TRIES = 6;
  public static inline var CLUTTER_SZ = 0.55;
  public static inline var CLUTTER_SZ_VAR = 0.40;
  // how far proud of the worktop a decal lies. over the slab and under nothing
  public static inline var CLUTTER_Y = 0.03;
  public static inline var CLUTTER_CUT = 0.5;
  // and how far inside the worktop's own edge an item must keep its whole box
  public static inline var CLUTTER_INSET = 0.18;
  // the clearance between two items, counted ONCE per pair
  public static inline var CLUTTER_GAP = 0.10;

  // the wall signs. ONE sheet, four quadrants, four DIFFERENT aspects — see CorpSigns.ASPECT
  public static inline var SIGN_TEX = 'textures/corp/signs.png';
  // the longest edge of a sign quad; the other edge comes off the art's own aspect
  public static inline var SIGN_MAX = 2.1;
  // the height of a sign's CENTRE. clear of the tallest thing that can stand under it (a server
  // rack at RACK_H 4.0) and under the head of a WALL_H 6.0 storey
  public static inline var SIGN_Y = 4.6;
  // how far proud of the wall slab a sign hangs
  public static inline var SIGN_PROUD = 0.05;
  // and the shortest run of unbroken masonry that earns one. a sign every cell turns a wall into
  // a strip of stickers
  public static inline var SIGN_RUN_MIN = 3;

  // ---- the lighting rig ----------------------------------------------------------------------
  //
  // THE PLATE HAD NO LIGHT SOURCE AT ALL until this: CorpArea handed render.particles.LampLights an
  // EMPTY post list from phase 2, so twenty storeys of office were lit by render.world.IndoorMask's
  // flat ambient and nothing else — which is what every screenshot of phases 2-6 shows.
  //
  // the fixtures go into the SHARED 12-slot spotlight pool, which every area kind already builds at
  // full size so NUM_SPOT_LIGHTS matches: the lights are already in each lit material's program key
  // and already run their per-fragment loop, so claiming them costs nothing that was not already
  // being paid. Two things come free with them and both are keyed off LampLights.active(): the fake
  // actor ground shadows and the real spotlight shadow maps on the low 8 slots.
  //
  // NOTHING FLICKERS. A tower is powered and maintained; every post takes phase 0, which is also
  // the STEADY marker LampLights and LightCone.pulse key on, so no cone is repacked and the whole
  // per-frame cost of the rig is one LampLights.update call.
  public static inline var LAMP_COLOR = 0xa8bcd8;
  // how far under the slab above a recessed panel sits. a tower plate draws NO ceiling deck (see
  // CorpArea's header), so this is where the fitting hangs and not where it is let into anything
  public static inline var CEIL_DROP = 0.2;
  public static inline var CEIL_Y = 6.0 - CEIL_DROP;   // FacilityStyle.WALL_H, one 3 m storey
  // the lattice: one fitting per this many cells of a room, each way
  public static inline var ROOM_SPACING = 5;
  // and how far apart two corridor fittings must be, in cells
  public static inline var CORR_SPACING = 5;
  // the compensation for IndoorMask's own direct term, the compound's number and not a taste knob
  public static inline var CEIL_MUL = 3.3;
  // a corridor is lit but not worked in
  public static inline var CORR_MUL = CEIL_MUL * 0.7;

  // ---- the additive glow (one merged mesh, one material, per-vertex brightness) ----------------
  //
  // the compound keeps its room pair (FacilityStyle.CEIL_GLOW) switched OFF, and a tower cannot:
  // a compound room is seen through a roof deck that FADES, so the pooled spotlight lands on a
  // floor the player is looking straight down at. Here there is no deck at all and the camera sits
  // at 51 degrees over an open plate — past the 12 nearest fixtures the floor falls to the flat
  // ambient, and a plate is wider than twelve spotlights reach. The pool is what covers that, and
  // it costs no per-frame work: nothing here moves, fades or is repacked.
  //
  // the C_* are FITTED against the built frame and never derived. the compound's own note is the
  // warning: predicting them off the lamp colour's luminance gave a pool THIRTY-ONE TIMES the
  // surface it lies on. A quad renders at roughly 2.1 * C, so C 0.43 is where a BLOOM_THRESHOLD of
  // 0.9 is crossed — and the corp threshold is 0.72, i.e. LOWER, so C_PANEL is pulled down to
  // match rather than left at the compound's 1.0
  public static inline var GLOW = 2.6;
  public static inline var C_PANEL = 0.8;
  public static inline var C_POOL = 0.014;
  // the call panel beside a lift door, the one WARM light on the plate
  public static inline var C_CALL = 0.55;
  public static inline var CALL_COLOR = 0xffb347;
  // a recessed panel is a LONG rectangle and follows the long axis of the room it lights
  public static inline var PANEL_W = 2.6;
  public static inline var PANEL_H = 0.9;
  public static inline var PANEL_DROP = 0.05;
  // how far a ground-lying glow floats over the floor. under the tactical grid's own 0.06
  public static inline var GLOW_Y = 0.04;
  // and how far inside a room's own rect its pool stops
  public static inline var POOL_INSET = 1.6;
  // the lift call panel: a small upright plate beside the car door
  public static inline var CALL_W = 0.5;
  public static inline var CALL_H = 0.8;
  public static inline var CALL_Y = 3.0;
  public static inline var CALL_OFF = 1.3;    // along the wall, from the door cell's centre

  // ---- the twentieth floor -------------------------------------------------------------------
  //
  // where the STREET is, in world units under the floor plate. FacilityStyle.WALL_H 6.0 is one 3 m
  // storey, so -114 is nineteen of them: the plate is the twentieth floor, which is the brief.
  public static inline var STREET_Y = -114.0;
  // the tower is a DOWNTOWN GLASS TOWER SEEN FROM THE INSIDE, so its own drop wears downtown's
  // full-glass curtain wall and not a label of its own. The first port generated `corp/facade` for
  // this and it read as a different building from the ones around it — which it was
  public static inline var FACADE_SLOT = 3;
  // one CELL per bay, both axes (FacilityGeom.face takes one period for both). This is downtown's
  // own pitch — render.world.Buildings locks a curtain wall to CELL / winPerCell — so the drop's
  // bays line up with the street towers' beside it and with the plate's own window grid above it.
  // It replaces a FACADE_TILE of 20, which was fitted to art that carried two storeys per repeat
  public static inline var FACADE_TILE = 4.0;
  // the soffit under the plate, a hair below the floor so nothing is coplanar with it
  public static inline var SOFFIT_Y = -0.03;

  // ---- the street, 114 units down (render.corp.CorpStreet) -------------------------------------
  //
  // A REAL citygen CITY AT LOW LOD, which is the brief's own answer and not the cheap one. The
  // MODEL is the real thing — CityGen.generate with the downtown profile, so the block structure,
  // the road hierarchy and the building footprints are a city and not a pattern. What is low is
  // the RENDERING: render.World's own pass list is eleven passes and lands a city area at
  // hundreds of draw calls, and nothing down there is closer than 114 units. So this kind emits
  // its own merged meshes off that model instead — the LOD is the point of the exercise.
  //
  // AND IT HAS NO ART OF ITS OWN. Every label comes off render.world.DowntownStyle, the very
  // style the city model is generated with: the tower stands in a downtown, and a second set of
  // asphalt, paving and curtain wall for the same materials one storey-count away is what made
  // the drop read as a different zone. The four corp/street-* labels it used to carry are retired.
  //
  // THE PLATE IS A HOLE IN IT — see render.corp.CorpStreet.PlateBox. The street is built over the
  // eight half-areas AROUND the building and never under it, where it is invisible anyway.
  // `STREET_REACH_FRAC` is how far past the plate's own footprint it goes, as a fraction of the
  // area's size: 0.5 each hand IS "eight half-areas".
  //
  // 0.65 IS THE FOG WALL AND NOT A TASTE. The camera sits ~26 over a plate at y 0 and the street
  // is 114 below it, so a cell at horizontal distance d is at range sqrt(d^2 + 140^2) and FOG_FAR
  // 240 puts it fully in haze at d = sqrt(240^2 - 140^2) = 195. On a 75 x 60 area 0.65 gives
  // 195 / 156 — exactly as far as anything can be seen, and no further. Growing it past this
  // builds geometry into the fog colour.
  //
  // It only means anything because render.corp.CorpStreet.fold mirror-tiles the model: the city
  // is 400 units square and the ring at 0.5 already overran it, so the reach was not the limit
  public static inline var STREET_REACH_FRAC = 0.65;
  // no street building rises past this, world units. the plate is at 0 and the street at -114, so
  // anything over 114 would come up THROUGH the floor the player is standing on
  public static inline var STREET_MAX_H = 90.0;
  // what the street surfaces' ALBEDO is multiplied by before the moon gets to it. Downtown's art
  // is authored for a lit city area and its pale masonry mid-rises (city/wall-3 at 0.1666 linear)
  // come out as chalk-white slabs at midnight beside its glass towers at 0.017, so the whole set
  // is pulled down as one. Fitted live against the lit panes rather than derived: this is the one
  // number that says how dark the street is.
  //
  // 0.62 -> 0.45 in the fourth pass, with STREET_SUN: the surfaces became lambert, so the moon's
  // key is now MULTIPLYING this rather than replacing it, and "reduce overall fake street
  // lighting" wanted the product lower than the old flat value and not the same
  public static inline var STREET_DIM = 0.45;
  // and what the TOWER'S OWN FLANK is multiplied by. It shipped with no `color:` field at all,
  // i.e. 1.0 — the nineteen storeys immediately outside the window rendered at full authored albedo
  // and were BRIGHTER than the office behind the player. Above STREET_DIM because the facade is
  // nearer than the street and a value ladder has to survive perspective, fitted live against it
  public static inline var FACADE_DIM = 0.62;
  // and the one thing the flank gained with the real shadow map: a neighbouring tower's shadow now
  // crosses it, measured at 0.0194 linear lit against 0.0013 in shade from the office window

  // ---- THE OUTDOOR KEY ------------------------------------------------------------------------
  //
  // WHY THE OUTSIDE LOOKED LIKE THE INSIDE. Everything past the glass used to be MeshBasicMaterial,
  // so the authored albedo WAS the rendered pixel: no lit side, no shade side, nothing saying where
  // light comes from. The third pass answered that with a key baked per face into the vertex colour
  // channel and a hand-marched heightfield for shadow; both were reported back as reading fake, and
  // they were — a per-cell horizon test gives 4-unit hard squares that are not the shape of any
  // building, and a flat per-face term gives no contact anywhere.
  //
  // SO THE STREET IS LAMBERT NOW AND TAKES A REAL SHADOW MAP. The one number that made it
  // affordable is `distance`: see render.corp.CorpStreet.light. Nothing outside moves, so the depth
  // pass runs ONCE on area entry and is frozen, and the near plane clips the office out of the map
  // rather than a layer doing it (three has no per-object light filtering — render.world.IndoorMask
  // carries that obituary).
  //
  // `dir` is the SAME (-1, 2, 1.5) render.facility.FacilityScene's moon stands at, normalised, so
  // the city below and the plate above are lit from one place by two lights. `color` is that moon's
  // 0x8294c0 for the same reason.
  //
  // `halfExtent` 250 against `mapSize` 2048 is 0.244 world units per shadow texel. That is 2.8x
  // coarser than the office's own box (90 half-wide at 2048 = 0.088) and it does not matter: the
  // nearest thing it shadows is 114 units below the camera and the furthest is in fog.
  public static final STREET_SUN = {
    color: 0x8294c0,
    intensity: 1.6,
    dir: [-0.3714, 0.7428, 0.5571],  // normalised (-1, 2, 1.5)
    distance: 400.0,   // how far up-light the shadow camera sits from the street plane
    halfExtent: 250.0, // ortho box half-width, world units — the whole 3x3 mirrored city
    mapSize: 2048,
    // how much past the plate the near plane sits, world units along the light. the plate is
    // `-STREET_Y / dir.y` = 153.5 units of travel nearer the light than the street, and the tallest
    // street building's roof is 121 — so anything from 0 to 32 clips the office out and keeps the
    // city in. 8 leaves the tower's own flank casting from its foot up to y = -5.9
    clear: 8.0,
    bias: -0.0004,
    normalBias: 0.04,
  };

  // ---- THE FAR CITY GOES SOFT ------------------------------------------------------------------
  //
  // "SAMEY" IS DETAIL, AND WHAT REPEATS IS DETAIL. The city below is one 100 x 100 model mirror-
  // tiled 3 x 3 (render.corp.CorpStreet.fold), so at range the eye is reading the same kerb, the
  // same paving and the same curtain grid four times over. Fog already takes the far city toward
  // the sky colour; what it cannot do is stop the pattern being legible on the way there.
  //
  // THE THIRD PASS ANSWERED THIS WITH A TEXTURE LOD BIAS AND IT WAS THE WRONG ANSWER. Measured:
  // bias 2.5 moved far-roof high-frequency energy 6.109 -> 6.060, −1%. A minified texture has
  // almost nothing left to lose at 200 units, and most of what still reads as structure out there
  // is GEOMETRY — roof edges, parapets, the lit-pane grid — which no map bias can touch.
  //
  // SO IT IS A REAL SCREEN-SPACE BLUR NOW, render.StreetBlur, one full-screen quad in the composer
  // masked by the alpha channel every street material writes (CorpStreet.blur). These two numbers
  // are where that mask ramps, in view units, and they sit inside the fog's own 90 .. 240 so the
  // softening arrives before the fog has finished swallowing the city rather than after.
  public static final BLUR = {
    near: 110.0,
    far: 230.0,
  };

  // how far a MIRROR TILE of the city may move a building off the one it reflects. The tiling is
  // exact by construction (render.corp.CorpStreet.fold), and exact is what makes four copies of a
  // skyline read as one skyline repeated. A height jitter and a facade re-deal per tile cost
  // nothing — they are a hash at build — and they break the symmetry the eye is actually picking
  // up. The CENTRE tile is left alone: it is the city the tower really stands in, it is the only
  // one near enough to resolve, and the crowd's lanes are dealt over it
  public static inline var TILE_VARY = 0.3;

  // ---- THE INDOOR SWAP ------------------------------------------------------------------------
  //
  // render.world.IndoorMask's per-kind preset, and the tower's own rather than the compound's. The
  // corp area attached `FacilityStyle.INDOOR` verbatim from the day it was written, which is why
  // "outside lighting is the same as indoor" had a second half to it: the inside was wearing a
  // LABORATORY's light. render.world.IndoorMaskOpts says a per-kind preset is the intended shape.
  //
  // What differs from the compound's, and only what differs:
  //   `ambient` is warmer and less green — an office runs 4000K tubes over carpet and timber, a lab
  //     runs 5000K over lino. Against the street's moonlit key above (blue-peaked) this is the whole
  //     of the indoor/outdoor read: warm inside, cool outside, and the window between them.
  //   `intensity` is a touch lower because the corp art is brighter than the compound's — an
  //     interior floor lands 0.090-0.124 linear against its 0.094-0.135 and a wall 0.115-0.219
  //     against its 0.137-0.159, which is the ladder this whole file is fitted on.
  //   `direct` is lower because a tower has 125 of its own fixtures (render.corp.CorpLamps) where a
  //     compound room has a handful, and this scales EVERY direct light and not just the moon.
  // `px`, `blur` and `grow` are geometry, not taste — the wall slab is the same WALL_T here
  public static final INDOOR:render.world.IndoorMaskOpts = {
    px: 8,
    blur: 0.5,
    grow: render.facility.FacilityStyle.WALL_T * 0.75,
    ambient: 0xb4aca0,
    intensity: 2.2,
    direct: 0.22,
    bounce: 0.5,
  };
  // ---- what stands on a street roof (render.corp.CorpStreet.roof) -------------------------------
  //
  // A BARE BOX WITH A LID IS NOT A BUILDING SEEN FROM ABOVE, and from the twentieth floor a roof is
  // most of what there is to see. Three pieces, and the order they are worth anything in is the
  // order of the cost: a coping rim round every edge (the roofline is what reads at range), a
  // mechanical penthouse where the city's own rule says there is one, and the city's own rooftop
  // plant decals on the sectors that are left.
  //
  // THE RIM'S SKINS WEAR THE BUILDING'S OWN WALL and only its top cap takes the coping label, which
  // is what keeps this to ONE new draw call for 200-odd buildings: a face in a buffer that already
  // exists costs nothing at all. render.world.roofs.Parapets is the other way of doing it — eight
  // BoxGeometry blocks and up to six texture clones per roof — and is affordable 40 times, not 200
  public static inline var COPING_STREET = 'textures/city/coping.png';
  public static inline var ROOF_PARA_H = 1.0;
  public static inline var ROOF_PARA_T = 0.6;
  // the cap's repeat ALONG the rim. Tiled at the rim's own 1.0 the coping art repeated every world
  // unit and the roofline read as a dashed hazard stripe from the plate; 4.0 is one repeat per
  // city cell, which is the pitch every other surface down there already uses
  public static inline var COPING_TILE = 4.0;
  // the sector grid the plant is dealt on, and the cap on it — the city's own numbers
  // (RenderConfig.ROOF_SECTOR / DETAIL_MAX), so a street roof and a real one read alike
  public static inline var ROOF_SECTOR = 6.0;
  public static inline var ROOF_DECO_MAX = 6;
  // WHICH of RenderConfig.DETAIL_TYPES a street roof deals, and it is THREE of the six on a
  // measured budget and not on taste: each type is its own chroma-cut image and so its own merged
  // mesh, six of them took the pinned pose to 85 against a ceiling of 85, and the plan named this
  // as the fallback before the first one was emitted. The three kept are the ones that read as a
  // SHAPE from 114 units up — a boxy unit, a round vent and a tank; the long AC, the duct run and
  // the skylight are all flat rectangles at this range and are what the other three already say
  public static final ROOF_DECO_TYPES = [0, 2, 5];
  // and how far a decal keeps off the rim, which has to clear ROOF_PARA_T or it climbs it
  public static inline var ROOF_DECO_EDGE = 2.2;

  // how far a lit pane stands proud of the curtain wall it is set into. render.world.Windows uses
  // 0.07 for the same job on a real tower, and it is the same trade: enough to clear the depth
  // buffer at this range, small enough that the pane does not read as a box on the facade
  public static inline var LIT_PROUD = 0.07;

  // ---- the fake crowd (render.corp.CorpCrowd) --------------------------------------------------
  //
  // PURELY VISUAL: no entity, no state, no spawn or despawn, nothing persisted — the contract
  // render.particles.PropFX's gnat swarms run on, and the direct 3D successor to the 2D
  // _FakeHost / turnCorp / paintFakeHost code the corp AreaView used to carry.
  //
  // AND ON A WALL CLOCK. Every other timed animation in the game derives from
  // RenderConfig.BASE_MS and is scaled by the global ANIM_SPEED; this one takes RAW dtMs, which is
  // the documented exception for ambient city life (the window-light switches and the failing-lamp
  // flicker are the others). Traffic that speeds up when the player's animation speed does would
  // be wrong, and the whole point of the thing is that it keeps moving while the player stands
  // still thinking.
  public static inline var WALKERS = 64;
  public static inline var CARS = 28;
  // world units per second. a unit is half a metre, so 2.8 is 1.4 m/s (a walk) and 20 is 10 m/s
  // (36 km/h, a city street)
  public static inline var WALK_SPEED = 2.8;
  public static inline var CAR_SPEED = 20.0;
  // and how much either varies per agent, as a fraction
  public static inline var CROWD_SPEED_VAR = 0.45;
  // the quads.
  //
  // THE PEDESTRIANS ARE THE GAME'S OWN AI ICONS, which is what "random ai art" meant and what the
  // 2D corp view already did: `AreaView.paintFakeHost` (commit ab37666) drew each fake host from
  // `images.male` / `images.female` at a random `ix`/`iy`, off the very sheets `AI.createIcon`
  // deals a civilian's own portrait from. The first 3D pass replaced them with additive glow
  // gradients on the argument that at this range a person is the light they stand in; asked for
  // twice, and the answer is the sheets. See render.corp.CorpCrowd.people.
  //
  // UPRIGHT AND LEANED BACK by render.particles.Sprites.TILT, "slanted so we can see it better" —
  // the same lean every actor billboard in the game takes toward the overhead camera, and for the
  // same reason. A quad lying flat on the pavement shows a person from directly overhead, which is
  // a head and two shoulders
  public static inline var WALK_H = 3.2;
  public static inline var CROWD_Y = 0.06;
  // what the people quad's albedo is multiplied by, before the street's own moon. ABOVE STREET_DIM
  // because the icons are the smallest thing down here and the thing the eye is meant to find.
  //
  // THE QUAD IS LAMBERT AND THAT IS THE FIX, not this number — see render.corp.CorpCrowd.people. A
  // civilian icon is flat, saturated and high-value by construction, so an UNLIT one is the
  // brightest thing on a night street at any multiplier: at 0.42 against a road measuring 0.0032
  // linear it still read as a sticker stuck on the pavement
  public static inline var WALK_DIM = 0.55;
  // the people sheets, stacked into one canvas so both sexes ride one draw call
  public static inline var WALK_ATLAS_W = 640;
  public static inline var WALK_ATLAS_H = 1024;

  // A CAR IS NOT A PATCH OF LIGHT AND THE PEDESTRIANS STILL ARE, which is the one place the
  // paragraph above has been overruled: an 8 x 3.6 quad wearing a circular gradient is an ELLIPSE,
  // and at this range that read as a yellow lozenge rather than as traffic. A person at 1.8 units
  // is genuinely too small to be anything but the light they stand in and keeps the old treatment.
  //
  // FOUR CARS ON ONE SHEET, cropped per cell at draw time (render.corp.CorpCrowd injects the UV
  // rect per instance the way render.decals.DecalBatch does), so the whole street's traffic is
  // still ONE draw call whatever the family grows to
  public static inline var TRAFFIC = 'textures/corp/traffic.png';
  // the nominal length a car is drawn at. each cell below scales off its OWN pixel height against
  // the sheet's median, so the van really is longer than the hatchback
  public static inline var CAR_LEN = 8.0;
  // what the car quad's albedo is multiplied by, before the street's own moon. a touch over
  // STREET_DIM because a car is small, moving and the thing the eye is meant to follow — fitted
  // live, like STREET_DIM itself. Lambert for the walkers' reason
  public static inline var CAR_DIM = 0.60;
  // and the cells, MEASURED off the drop at alpha > 220 and padded 3 px — an authored cell is an
  // object in a quadrant and not the quadrant, and cropping to the quadrant would draw a third of
  // each car as empty road. `len`/`wide` come out of each crop's own aspect, so nothing is
  // stretched. See the note on `corp/traffic` in art/textures.json for the pixel rects
  public static final CAR_CELLS:Array<CarCell> = [
    // saloon    174x372 px, aspect 0.468
    { u0: 0.1719, v0: 0.5850, du: 0.1699, dv: 0.3633, len: 8.08, wide: 3.78 },
    // hatchback 171x303 px, aspect 0.564
    { u0: 0.6621, v0: 0.6084, du: 0.1670, dv: 0.2959, len: 6.58, wide: 3.71 },
    // van       180x421 px, aspect 0.428
    { u0: 0.1699, v0: 0.0771, du: 0.1758, dv: 0.4111, len: 9.14, wide: 3.91 },
    // estate    170x365 px, aspect 0.466
    { u0: 0.6621, v0: 0.0996, du: 0.1660, dv: 0.3564, len: 7.92, wide: 3.69 },
  ];
  // the shortest straight run of cells that is worth walking or driving down
  public static inline var LANE_MIN = 6;

// the tower's own ShellOpts: how CorpModel reads a saved corp grid, and what the shell is dressed
// in. the shape FacilityStyle.shell() has, and the reason both exist
  public static function shell(): ShellOpts
    {
      var floor = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.CARPET] = FLOOR_CARPET;
      floor[Surf.OPEN] = FLOOR_OPEN;
      floor[Surf.CUBICLE] = FLOOR_CUBICLE;
      floor[Surf.MEETING] = FLOOR_MEETING;
      floor[Surf.KITCHEN] = FLOOR_KITCHEN;
      floor[Surf.EXEC] = FLOOR_EXEC;
      floor[Surf.WASHROOM] = FLOOR_WASHROOM;
      floor[Surf.SERVER] = FLOOR_SERVER;
      floor[Surf.LIFT] = FLOOR_LIFT;
      // an interior face is picked off the surface it LOOKS INTO, so the corridor side of a
      // partition is painted board and the boardroom side of the same slab is not
      var into = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) WALL_OFFICE];
      into[Surf.MEETING] = WALL_MEETING;
      into[Surf.KITCHEN] = WALL_KITCHEN;
      into[Surf.EXEC] = WALL_EXEC;
      into[Surf.WASHROOM] = WALL_WASHROOM;
      into[Surf.LIFT] = WALL_LIFT;
      return {
        kind: 'corp',
        tex: {
          floor: floor,
          wallOut: WALL_EXTERIOR,
          wallInto: into,
          pane: WINDOW_3,
          pane2: WINDOW_2,
          aspect: WINDOW_ASPECT,
          aspect2: WINDOW_ASPECT_2,
          // a tower floor has no light well, so nothing ever draws this — it is filled with the
          // three-bay art so the warm compiles the same material the game will ask for
          paneHigh: WINDOW_3,
          head: CAP,
          roof: CAP,
          coping: COPING,
          // a tower floor has no roll-up shutter
          shutter: null,
          door: [DOOR_GLASS, DOOR_OFFICE, DOOR_STEEL, DOOR_PRIVATE, DOOR_LIFT],
          circ: Surf.CARPET,
        },
        surfOf: CorpModel.surfOf,
        fitOf: CorpModel.fitOf,
        tableOf: Const.isCorpTableTile,
        wallOf: CorpModel.wallOf,
        // and NO hangars: the lift car is nine cells of concrete in a ring of its own, which the
        // concrete-majority test would call a shed and arch a barrel vault over
        hangars: false,
      };
    }
}

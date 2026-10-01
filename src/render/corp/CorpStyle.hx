package render.corp;

import Const;
import render.RenderConfig;
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

  // margin on each glb prop's own bounding sphere in the per-instance cull, world units: covers the
  // sway shader's displacement and the moon throw of the tallest prop (arch-shelf, 4.8)
  public static inline var PROP_CULL_R = 2.0;

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
  public static inline var WALL_RECEPTION = 'textures/corp/wall-reception.png';
  public static inline var WALL_LIFT = 'textures/corp/wall-lift.png';

  public static inline var FLOOR_CARPET = 'textures/corp/floor-carpet.png';
  public static inline var FLOOR_OPEN = 'textures/corp/floor-open.png';
  public static inline var FLOOR_CUBICLE = 'textures/corp/floor-cubicle.png';
  public static inline var FLOOR_MEETING = 'textures/corp/floor-meeting.png';
  public static inline var FLOOR_KITCHEN = 'textures/corp/floor-kitchen.png';
  public static inline var FLOOR_EXEC = 'textures/corp/floor-exec.png';
  public static inline var FLOOR_RECEPTION = 'textures/corp/floor-reception.png';
  public static inline var FLOOR_WASHROOM = 'textures/corp/floor-washroom.png';
  public static inline var FLOOR_SERVER = 'textures/corp/floor-server.png';
  public static inline var FLOOR_LIFT = 'textures/corp/floor-lift.png';

  // one capping serves the wall head and the window head both: they ARE the same extrusion seen
  // from the same angle, which is the one case docs/3d-textures.md allows a label to be reused
  public static inline var CAP = 'textures/corp/cap-alu.png';
  public static inline var COPING = 'textures/corp/coping.png';
  // the lift doorway's two details — see ShellTex.pocket/sill. The reveal is painted in the
  // CIRCULATION finish whichever way an opening faces, which left the car's own opening reading as
  // a hole in the corridor board: no track, no threshold, nothing to say a door slides there
  public static inline var LIFT_POCKET = 'textures/corp/lift-pocket.png';
  public static inline var LIFT_SILL = 'textures/corp/lift-sill.png';
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
  public static inline var COUNTER_FRONT = 'textures/corp/counter-front.png';
  public static inline var VANITY_TOP = 'textures/corp/vanity-top.png';
  public static inline var STALL_PANEL = 'textures/corp/stall-panel.png';
  public static inline var TABLE_TOP = 'textures/corp/table-top.png';
  // and the reception counter's two marbles, cut from one packed sheet (art/textures.json
  // corp/reception-pack): the TOP of both tiers, and the corridor-side FRONT and the ledge's edges
  public static inline var RECEPTION_TOP = 'textures/corp/reception-top.png';
  public static inline var RECEPTION_FRONT = 'textures/corp/reception-front.png';
  // and the company's name on the reception's back wall, facing its counter: ONE composition mapped
  // 0..1, so its height comes off the MEASURED crop's aspect (463 x 169) and never off a choice
  public static inline var RECEPTION_LOGO = 'textures/corp/reception-logo.png';
  public static inline var RECEPTION_LOGO_ASPECT = 463 / 169.0;
  // and the whiteboard's face, ONE authored composition mapped 0..1 over the board (a frame, a
  // marker tray, a sketch), so render.corp.CorpDeco locks the board's aspect to this 1024x768 source
  public static inline var WHITEBOARD = 'textures/corp/whiteboard.png';
  // the security room's own: a locker bank's front, ends and lid, its video wall's feeds
  // (render.corp.CorpSecurity), and the lit header over its doorway
  public static inline var LOCKER_FRONT = 'textures/corp/locker-front.png';
  public static inline var LOCKER_SIDE = 'textures/corp/locker-side.png';
  public static inline var LOCKER_TOP = 'textures/corp/locker-top.png';
  public static inline var SECURITY_SIGN = 'textures/corp/security-sign.png';
  public static inline var CCTV_WALL = 'textures/corp/cctv-wall.png';
  public static inline var RACK_FRONT = 'textures/corp/rack-front.png';
  public static inline var RACK_SIDE = 'textures/corp/rack-side.png';
  // and the LID, which is its OWN surface and not the flank seen from above — the rule
  // docs/3d-geometry.md opens with. Capped in RACK_SIDE, every cabinet in the room wore its
  // perforated flank across its top
  public static inline var RACK_TOP = 'textures/corp/rack-top.png';
  // and the records room's two LOOSE surfaces — what is stacked on the casework rather than what
  // the casework is made of. The drawer course and the binder spines are baked into the two glbs
  // (models-src/corp/arch_build.py) and are never named here; these two are
  public static inline var ARCH_BOARD = 'textures/corp/archive-board.png';
  public static inline var ARCH_PAPER = 'textures/corp/archive-paper.png';
  // and the TOPS: one sheet, four 0..1 caps, one draw call (art/textures.json corp/archive-tops).
  // The rects are [u0, v0, u1, v1] measured off the drop, inset inside its separator (cols 511-514,
  // rows 510-513) and its frame
  public static inline var ARCH_TOPS = 'textures/corp/archive-tops.png';
  public static final ARCH_TOP_PAPER = [ 0.0039, 0.5059, 0.4951, 0.9961 ];
  public static final ARCH_TOP_CARTON = [ 0.5049, 0.5059, 0.9951, 0.9961 ];
  public static final ARCH_TOP_FOLDERS = [ 0.0039, 0.0049, 0.4951, 0.4961 ];
  public static final ARCH_TOP_REAM = [ 0.5049, 0.0049, 0.9951, 0.4961 ];

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
  // the cubicle panel. 1.4 m is a real low-wall partition: over a seated head and under a standing
  // one, which is the whole point of the thing
  public static inline var PARTITION_H = 2.8;
  // 5 cm of panel, HALVED TWICE: 0.4 was 20 cm of fabric-faced board and read as a stud wall, and
  // 0.2 still read as one now that the panel sits ON a desk boundary with a worktop either side
  // of it instead of floating in a cell of its own. emitted +-T/2 about the boundary, so nothing
  // else moves with it
  public static inline var PARTITION_T = 0.1;
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
  // top, and a box of quads under a 6 m top is a plinth the size of a car. 0.12 AND NOT 0.26: 13 cm
  // of edge read as a slab of worktop a hand deep, reported as "make the table top thinner". The
  // fascia wears TABLE_TOP, since it is the same board seen edge-on, and the underside is capped
  public static inline var TABLE_FASCIA = 0.12;
  // and the radius its top arris is rounded to, in this many flat bands. under half the fascia, so
  // a straight strip of edge still shows below the round
  public static inline var TABLE_ROUND = 0.05;
  public static inline var TABLE_ROUND_SEG = 3;
  // and its polish: the Blinn-Phong highlight the ceiling spots leave on it (CorpFurniture.glossy).
  // Swept live at the rig camera: 0x666666 / 40 was a blown white disc, 0x2a2a2a / 30 a smear;
  // 0x444444 / 120 is a tight glint and leaves the rest of the top wood
  public static inline var TABLE_SPECULAR = 0x444444;
  public static inline var TABLE_SHININESS = 120.0;

  // THE RECEPTION COUNTER, which stands IN THE WALL LINE where the reception's wall onto the
  // corridor was (render.corp.CorpReception). Every depth is off the WALL CELL's centre line, `u`
  // positive toward the corridor; the cell is CELL 4.0 across, so all of it fits inside the one
  // cell the wall stood in and the room keeps its whole edge row for the receptionist.
  //
  // TWO TIERS, the front desk's own silhouette: a tall body with a marble TRANSACTION LEDGE at
  // 1.1 m on the visitor's side, and the receptionist's worktop at DESK_H behind it
  public static inline var REC_LEDGE_H = 2.2;
  // the ledge slab's thickness, and how far it overhangs the body's front
  public static inline var REC_LEDGE_T = 0.1;
  public static inline var REC_LEDGE_OVER = 0.25;
  // the body's corridor face and its room face. the front stands 0.2 proud of an interior wall's
  // own face (WALL_INNER / 2 = 0.6), so the counter reads as a thing set INTO the opening
  public static inline var REC_FRONT_U = 0.8;
  public static inline var REC_BACK_U = -0.2;
  // the worktop's room edge, and its slab. -1.9 and not the cell boundary, so it stops just short
  // of the edge row the receptionist sits in
  public static inline var REC_WORK_U = -1.9;
  public static inline var REC_WORK_T = 0.1;
  // the radius both slabs' open top arrises are rounded to (CorpFurniture.roundEdge), in
  // TABLE_ROUND_SEG bands. Reported as a hard edge off the ledge's and the worktop's front faces
  public static inline var REC_ROUND = 0.06;
  // the marble's world period: one 512 swatch over a CELL, the desk laminate's own density
  public static inline var REC_TILE = 4.0;
  // the workstation on the worktop, in from the body's room face: the screen at the back of the
  // top and the keyboard toward its edge. The worktop is 1.7 deep, where DESK_TOP_D is 3.30 — so
  // not MON_BACK / KEY_FWD, which were fitted to the deeper top and put the keys off its edge
  public static inline var REC_MON_IN = 0.5;
  public static inline var REC_KEY_IN = 1.3;
  // THE COUNTER'S TRINKETS (render.corp.CorpReception.dress), hand-modelled and drawn at TWICE their
  // built height for the exec trinkets' reason: sized off the counter and not off the real object.
  // _R is half the glb's widest extent over its own height, the form CLUTTER_PROP_R keeps
  public static inline var REC_PHONE_H = 0.321;
  public static inline var REC_PHONE_R = 1.4255;
  // the board at THREE times: at two its WELCOME was 44 x 16 px from the rig camera on a counter
  // that is 28 units long, and a sign nobody can read is not a sign
  public static inline var REC_BOARD_H = 0.7053;
  public static inline var REC_BOARD_R = 1.446;
  public static inline var REC_BELL_H = 0.246;
  public static inline var REC_BELL_R = 0.813;
  // where across the ledge its things stand (its middle), and across the worktop the phone and the
  // second plant do (toward the back, clear of the keyboard's line)
  public static inline var REC_LEDGE_MID_U = 0.43;
  public static inline var REC_WORK_BACK_U = -0.75;
  // the desk-clutter cells it deals by NAME, off corp/desk-clutter's own prompt order: the open
  // notebook is the visitor book, with the fountain pen beside it, the business cards and a
  // lanyard badge for the visitor's pass on the ledge, the sticky notes on the worktop
  public static var REC_DECALS = [10, 11, 30, 23, 13];
  // the logo on the back wall: its width (under a CELL, so one solid wall cell carries it), its
  // bottom edge -- over any casework dressed under it, the whiteboard's own band -- and how proud
  // of the wall it hangs
  public static inline var REC_LOGO_W = 3.6;
  public static inline var REC_LOGO_Y0 = 3.0;
  public static inline var REC_LOGO_PROUD = 0.08;
  // how many cells either side of the logo the tower's own framed art keeps off (CorpSigns)
  public static inline var REC_LOGO_CLEAR = 2;
  // the two hand-modelled tables. built at WORLD SIZE, so render.Models.instanced (which scales by
  // HEIGHT alone) scales them by exactly 1 and every number in the build script is the game's
  public static inline var DESK_GLB_H = 1.5;
  public static inline var DESK_GLB_W = 3.76;
  // and its worktop DEPTH, which is NOT the cell. models-src/corp/desk_build.py lays a 3.30 top
  // centred in a 4.0 cell, so the top edge is 1.65 from the centre where the cell boundary is
  // 2.00 — and everything standing on the desk used to be offset from CELL / 2, which put the
  // keyboard's front lip 0.04 PAST the front of the desk it sits on and the monitor's back within
  // 0.275 of the far edge. Keep this equal to desk_build.py's TOP_D
  public static inline var DESK_TOP_D = 3.30;
  // the blade leg runs up to the fascia's underside. Keep models-src/corp/desk_build.py's LEG_H
  // equal to this
  public static inline var LEG_H = TABLE_H - TABLE_FASCIA;
  public static inline var LEG_W = 0.46;
  // the waste bin, the one ROUND piece of the tower's furniture and so the only one of the
  // decoration families that is a glb rather than emitted quads. 0.9 is 45 cm tall
  public static inline var BIN_H = 0.9;
  public static inline var BIN_W = 0.62;
  // a server rack. 2 m tall and 1 m deep, standing against the aisle it is reached from
  public static inline var RACK_H = 4.0;
  public static inline var RACK_D = 2.0;
  // and a rack against masonry (the security room's column): as deep as the wall's margin allows,
  // the locker's depth, so it stands off its cell like the lockers across the room
  public static inline var RACK_WALL_D = LOCKER_D;
  // and a wall machine's depth off the masonry (render.corp.CorpFurniture.machine)
  public static inline var MACHINE_D = 1.15;

  // A SECURITY ROOM LOCKER BANK, one cell of it: the full cell along the wall so a column of them
  // butts into one run, and exactly as tall -- corp/locker-front is a square composition mapped 0..1
  // over the front (render.corp.CorpFurniture.locker)
  public static inline var LOCKER_W = 4.0;
  public static inline var LOCKER_H = LOCKER_W;
  public static inline var LOCKER_D = 1.3;
  // THE VIDEO WALL'S FEEDS (render.corp.CorpSecurity.feeds): corp/cctv-wall's screen edges MEASURED
  // off the source (dark bezel columns at 342 and 682 of 1024, the row gap at 324 of 672 -- not at
  // the half), how many turns a screen holds a view, and the share of that spent in static at a cut
  public static inline var FEED_COL1 = 342 / 1024;
  public static inline var FEED_COL2 = 682 / 1024;
  public static inline var FEED_ROW1 = 324 / 672;
  public static inline var FEED_TURNS = 40.0;
  public static inline var FEED_STATIC = 0.05;
  // THE SECURITY HEADER over the room's doorways: corp/security-sign's measured 990 x 161 crop,
  // centred between the door head (DOOR_H 4.0 + the kerb) and the ceiling (5.8)
  public static inline var SEC_SIGN_W = 3.2;
  public static inline var SEC_SIGN_H = SEC_SIGN_W * 161 / 990;
  public static inline var SEC_SIGN_Y = 4.95;
  public static inline var SEC_SIGN_EMISSIVE = 1.0;
  // the ends' and lid's repeat: one tile per locker height, so corp/locker-side's four ribs sit on
  // the bank as a real side panel's pressings would
  public static inline var LOCKER_TILE = LOCKER_H;
  // THE GUN CABINET, objects.GunCabinet's two glbs (models-src/corp/gun_cabinet_build.py): its
  // height, and how far its carcass centre stands off the cell centre toward the wall -- its back on
  // an inner wall slab's room face, WALL_INNER / 2 short of the wall cell's centre, less half its
  // 1.3 depth. A perimeter wall is thicker, and CorpArea.objWall brings the cabinet out to its face
  public static inline var GUN_CAB_H = 3.6;
  public static inline var GUN_CAB_W = 2.4;
  public static inline var GUN_CAB_BACK = 4.0 - WALL_INNER / 2 - 1.3 / 2;
  // and both glbs' footprint centre, printed by the build script: their leaf stands proud of the
  // carcass, and Models.normalize recentres on it, so render.world.ObjModels' `off` puts it back
  public static inline var GUN_CAB_OPEN_X = 0.0;
  public static inline var GUN_CAB_OPEN_Y = -0.03;
  // BOTH GLBS' LEAF IS BUILT SHUT and CorpSecurity.swing turns the open one's, in the glb's frame
  // (glTF z is Blender -y): every vertex deeper than LEAF_Z is the leaf's, half way across the
  // build script's LEAF_GAP, and it turns SWING radians about the hinge at its back left corner
  public static inline var GUN_CAB_LEAF_Z = 0.655;
  public static inline var GUN_CAB_HINGE_X = -1.2;
  public static inline var GUN_CAB_HINGE_Z = 0.66;
  public static inline var GUN_CAB_SWING = -1.745;
  // and how long the swing takes, in turns (RenderConfig.BASE_MS)
  public static inline var GUN_CAB_SWING_TURNS = 3.0;
  // THE VIDEO WALL: one panel of corp/cctv-wall per console cell, hung on the north wall over it.
  // Its aspect is the art's 1024x672 (1.524); the head stops under SIGN_Y's band's own top
  public static inline var VIDEO_W = 3.6;
  public static inline var VIDEO_H = VIDEO_W * 672 / 1024;
  public static inline var VIDEO_Y0 = 2.5;
  public static inline var VIDEO_PROUD = 0.06;
  // how bright the feeds glow, on the emissive map that IS the art: the bezels are near black and
  // stay dark, the monochrome feeds clear the bloom threshold
  public static inline var VIDEO_EMISSIVE = 0.9;
  // A CCTV CAMERA on the corridor's inside corners and the reception's (models-src/corp/
  // wall_cam_build.py): the glb's height and depth off its own wall plate, the plate's mount height,
  // how far along the wall from the corner, the turn toward the room, and one corner in how many
  public static inline var CAM_H = 0.4203;
  public static inline var CAM_D = 0.8807;
  public static inline var CAM_Y = 5.0;
  public static inline var CAM_SIDE = 0.8;
  public static inline var CAM_TURN = 0.3;
  public static inline var CAM_EVERY = 2;
  // and its red recording light, a speck on the wall plate beside the arm, in the plate's own frame.
  // the plate spans 0.08..0.42 up the glb; 0.36 sat at its top edge and read as floating over it
  public static final CAM_LED = [ 0.08, 0.28, 0.05 ];
  public static inline var CAM_LED_SIZE = 0.07;

  // WHAT IS STACKED ON THE ARCHIVE'S CASEWORK, dealt per LEVEL of every unit — see
  // render.corp.CorpArchive. In world units, like the compound's DECO_BOX_* band and for its
  // reason: a carton is a carton whatever it is standing on, and a band written as a fraction of
  // the level it lands on produces one 1.6-wide monster whenever the roll comes back with a
  // single box.
  //
  // 0.60 .. 1.05 across and 0.50 .. 0.85 tall is a 30-52 cm carton at the half-metre unit WALL_H
  // fixes, which is a records box. _D is a CEILING as a fraction of the unit's depth, not the
  // value: the box is squared up to the unit (there is no free turn here — see CorpArchive.load),
  // so the only thing it has to clear is the carcass front.
  //
  // _GAP is the margin left at each end of a level, so a box never overhangs the flank it stands
  // over, and _MAX is how many are dealt across one. _CHANCE is per LEVEL and not per unit: a rank
  // where every lid carries something reads as a delivery and not as a room people work in
  public static inline var ARCH_LOAD_CHANCE = 72;
  // THE SIDE OF A RUN'S END UNIT IS A WALL TOO, asked for as "excellent clutter spots for wall
  // clutter and propaganda": the percent of them that take the poster (render.corp.CorpSigns), and
  // how many pinned things the rest may carry (render.corp.CorpClutter, zero reachable)
  public static inline var ARCH_END_POSTER_PCT = 35;
  public static inline var ARCH_END_PIN_MAX = 2;
  // how far in from a side's edges a poster or a pinned sheet keeps, and the band of the unit's
  // height they hang in: nothing lower than a hand reaches, nothing over the top edge
  public static inline var ARCH_END_EDGE = 0.1;
  public static inline var ARCH_END_LO = 1.3;
  public static inline var ARCH_END_TOP = 0.35;
  // and how many flat things a level of a unit that took no load may carry, off the desk sheet
  public static inline var ARCH_DECAL_MAX = 2;
  public static inline var ARCH_LOAD_MAX = 3;
  public static inline var ARCH_GAP = 0.18;
  public static inline var ARCH_BOX_W = 0.60;
  public static inline var ARCH_BOX_W_VAR = 0.45;
  public static inline var ARCH_BOX_H = 0.50;
  public static inline var ARCH_BOX_H_VAR = 0.35;
  public static inline var ARCH_BOX_D = 0.72;
  // and a BARE STACK OF PAPER, which is the same emitter with the paper sheet on all five faces —
  // four edges and a top IS a ream. Flatter than a carton by this fraction, because a stack nobody
  // boxed is what has been left out on top of a cabinet and it is 10-25 cm, not half a metre
  public static inline var ARCH_REAM_H = 0.42;
  // and the ream's SIDE period: longer than the largest ream's whole perimeter (2 x (1.05 + 1.05)),
  // read from phase 0, so u never wraps round a stack. archive-paper is a quadrant crop whose u wrap
  // measures 31.2 and at DECO_BOX_TILE 0.5 a 0.8 side crossed two seams. The striations run along
  // u, so the stretch this costs is along the lines and invisible
  public static inline var ARCH_REAM_TILE = 4.5;
  // the gap between two archive units standing END TO END in a run, and between the two backs of a
  // back-to-back pair: enough that no two glb faces are coplanar, too little to see daylight through
  public static inline var ARCH_BUTT = 0.04;
  // one wall run in this many is arch-shelves rather than file cabinets
  public static inline var ARCH_WALL_SHELF = 3;
  // and the clearance left under the plane that closes a bay, so a capped box does not meet the
  // shelf over it exactly and z-fight along its whole lid
  public static inline var ARCH_HEAD_GAP = 0.06;

  // the material scales. a MATERIAL scale and never the object's own size: the laminate grain, the
  // drawer course, the felt weave and the perforation pitch are each chosen against the thing they
  // draw. the drawer front's art carries THREE courses over its square, so at 3.0 a 1.5-high
  // carcass shows half of them, which is the two drawers a 75 cm pedestal really has
  public static inline var DESK_TILE = 4.0;
  public static inline var DESK_FRONT_TILE = 3.0;
  public static inline var COUNTER_TILE = 4.0;
  // and the boardroom table's own, on its top and BOTH kinds of edge. it used to have none: the
  // MEETING branch never set `tile`, so a table's top tiled at the desk laminate's 4.0 and its two
  // end faces at DESK_FRONT_TILE 3.0 — a drawer pitch, on a boardroom table's edge
  public static inline var TABLE_TILE = 4.0;
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
  // THE EXEC OFFICE'S GLBS (models-src/corp/exec_build.py, render.corp.CorpExec), every height the
  // built mesh's own so render.Models.instanced scales each by 1, and every footprint the mesh's
  // own for the contact under it. A seat is pulled IN toward what it faces off its cell's centre:
  // the owner's chair tucks under the desk's edge, an armchair keeps a knee's gap off the desk or
  // the low table. The sofa is pushed BACK off its cell toward the end wall it stands against
  public static inline var EXEC_DESK_H = 1.52;
  public static inline var EXEC_CHAIR_H = 2.698;
  public static inline var EXEC_CHAIR_W = 1.54;
  public static inline var EXEC_CHAIR_IN = 1.40;
  public static inline var ARMCHAIR_H = 1.8;
  public static inline var ARMCHAIR_W = 2.5;
  public static inline var ARMCHAIR_IN = 0.40;
  public static inline var SOFA_H = 1.9;
  public static inline var SOFA_W = 7.2;
  public static inline var SOFA_D = 2.5;
  public static inline var SOFA_BACK = 0.60;
  public static inline var TABLE_LOW_H = 0.9;
  public static inline var TABLE_LOW_W = 6.4;
  public static inline var TABLE_LOW_D = 2.6;
  // THE STAFF KITCHEN'S GLBS (models-src/corp/kitchen_build.py, render.corp.CorpKitchen), every
  // height and footprint the built mesh's own. A counter module is the full cell along its wall and
  // COUNTER_D deep against it; the wall cabinet over it hangs at CAB_Y, which normalize() cannot
  // keep, because it grounds every glb. A dining chair stands KITCHEN_CHAIR_GAP off the edge of the
  // table it faces: its cell's centre is 6 units from the table's and the edge 1.8 or 2.6 off it,
  // so un-pulled it stands a metre and a half or more clear of the table it belongs to
  public static inline var KITCHEN_TABLE_H = 1.5;
  public static inline var KITCHEN_TABLE_W = 5.2;
  public static inline var KITCHEN_TABLE_D = 3.6;
  public static inline var KITCHEN_CHAIR_H = 1.706;
  public static inline var KITCHEN_CHAIR_W = 0.99;
  public static inline var KITCHEN_CHAIR_GAP = 0.8;
  // and each chair's turn off square, rolled per cell up to this either way: a row of chairs
  // squared to the table reads as a layout, and a chair somebody sat on is never square
  public static inline var KITCHEN_CHAIR_JITTER = 0.14;
  public static inline var COUNTER_D = 1.32;
  public static inline var SINK_H = 2.5308;
  public static inline var CAB_H = 1.4;
  public static inline var CAB_W = 3.94;
  public static inline var CAB_D = 0.74;
  // over the tallest thing on the counter: the coffee machine's top is COUNTER_H + 0.95 x
  // APPLIANCE_SCALE = 3.04, so at 3.0 it stood up into the cabinet's carcass
  public static inline var CAB_Y = 3.4;
  public static inline var FRIDGE_H = 3.6;
  public static inline var FRIDGE_W = 1.6;
  public static inline var FRIDGE_D = 1.41;
  public static inline var VENDING_H = 4.2;
  public static inline var VENDING_W = 2.2;
  public static inline var VENDING_D = 1.43;
  // how bright its brushed steel's FACES glint, render.world.PropEnv's view-anchored lobe: the room's
  // own glint only ever lands on the chamfer strips from the tactical camera. Swept live, a face
  // turned onto a key: p90 128 at 0, 170 at 0.35, 197 at 0.8 — which washes the brushing out to a
  // white box; at the default yaw the side moved 131 -> 147 at 0.35
  public static inline var VENDING_GLINT = 0.3;
  // the four things on a counter, as (height, width, depth) at the size they were built, and the
  // one scale all four are drawn at: the exec trinkets' lesson, sized off the counter they stand
  // on rather than off their own centimetres. They keep APPLIANCE_BACK off the counter's back edge
  public static final MICROWAVE = [0.6, 1.0, 0.72];
  public static final COFFEE = [0.95, 0.6, 1.1];
  public static final KETTLE = [0.47, 0.44, 0.65];
  public static final TOASTER = [0.4, 0.64, 0.36];
  public static inline var APPLIANCE_SCALE = 1.3;
  public static inline var APPLIANCE_BACK = 0.10;
  // THE KITCHEN'S OWN PACK16 (corp/kitchen-clutter), exec-clutter's 4x4 with its last two cells
  // (a cleaning rota and a crayon drawing) never dealt, so the exec office's COLS and CELLS read it
  // as they stand. Its things are smaller than an executive's: a plate on a dining table, not a
  // leather portfolio on a desk. It lies on the dining tables and the fridge's top, and NOT on the
  // counters, which the appliances dress: a plate beside the microwave was reported as clutter
  public static inline var CLUTTER_KITCHEN_TEX = 'textures/corp/kitchen-clutter.png';
  public static inline var CLUTTER_KITCHEN_SZ = 0.45;
  public static inline var CLUTTER_KITCHEN_SZ_VAR = 0.30;
  public static inline var CLUTTER_KITCHEN_TABLE = 3;
  public static inline var FRIDGE_TOP_MAX = 2;
  // THE FRIDGE'S MAGNET CLUTTER (corp/fridge-magnets, render.corp.CorpClutter.fridge): 1 to
  // MAGNET_FRONT things held on the fridge door and up to MAGNET_SIDE on each side, hung square on.
  // FRIDGE_FACE is the door's face off the model's centre and FRIDGE_SIDE its side's; the door's
  // items keep between MAGNET_ACROSS_LO and _HI across it, clear of the pull on its hinge-free
  // hand, and between FRIDGE_DOOR_LO and _HI up it, above the freezer's split. A side's run from
  // MAGNET_SIDE_LO up
  public static inline var MAGNET_TEX = 'textures/corp/fridge-magnets.png';
  public static inline var MAGNET_COLS = 4;
  public static inline var MAGNET_CELLS = 16;
  public static inline var MAGNET_SZ = 0.36;
  public static inline var MAGNET_SZ_VAR = 0.22;
  public static inline var MAGNET_FRONT = 5;
  public static inline var MAGNET_SIDE = 2;
  public static inline var FRIDGE_FACE = 0.66;
  public static inline var FRIDGE_SIDE = 0.8;
  public static inline var MAGNET_ACROSS_LO = -0.72;
  public static inline var MAGNET_ACROSS_HI = 0.48;
  public static inline var FRIDGE_DOOR_LO = 1.42;
  public static inline var FRIDGE_DOOR_HI = 3.48;
  public static inline var MAGNET_SIDE_LO = 1.2;
  // THE EXEC RUG (render.corp.CorpRugs): corp/exec-rug is 1024 x 640, so the quad is laid at that
  // aspect and never stretched to its rect; it keeps RUG_INSET off the rect's edge, and lies at
  // RUG_Y — over the floor, under CorpLamps' pools at GLOW_Y 0.04
  public static inline var RUG_TEX = 'textures/corp/exec-rug.png';
  public static inline var RUG_ASPECT = 1.6;
  public static inline var RUG_INSET = 0.30;
  public static inline var RUG_Y = 0.02;
  // how far an exec monitor stands back from its cell's centre, away from its owner
  public static inline var EXEC_MON_BACK = 0.60;
  // and how many exec clutter decals a low table's top takes, at most
  public static inline var TABLE_LOW_CLUTTER = 2;
  // THE EXEC DESK TRINKETS (render.corp.CorpExec.trinkets), both hand-modelled: the nameplate stands
  // PLAQUE_IN in from the desk's front edge, the photo PHOTO_IN in from an owner-side corner on
  // PHOTO_EVERY desks in 100. Sizes are the built glbs' at TWICE their modelled scale: the desk is
  // 11.76 long, and at 0.74 a nameplate read as a crumb on it, a sixteenth of the desk where a real
  // one is an eighth
  public static inline var PLAQUE_H = 0.6508;
  public static inline var PLAQUE_W = 1.48;
  public static inline var PLAQUE_D = 0.41;
  public static inline var PLAQUE_IN = 0.55;
  public static inline var PHOTO_H = 1.0858;
  public static inline var PHOTO_W = 1.30;
  public static inline var PHOTO_D = 0.63;
  public static inline var PHOTO_IN = 0.95;
  public static inline var PHOTO_EVERY = 70;
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
  // and a boardroom chair's, off the slab CELL's centre: the slab's edge is FIT_INSET in from the
  // cell boundary, and the seat's front slides BOARD_CHAIR_TUCK under it
  public static inline var BOARD_CHAIR_TUCK = 0.10;
  public static inline var BOARD_CHAIR_OUT = 4.0 / 2 - FIT_INSET + CHAIR_W / 2 - BOARD_CHAIR_TUCK;
  public static inline var MON_H = 1.66;       // the built mesh exactly, so the batch's scale is 1
  public static inline var MON_W = 1.95;
  public static inline var MON_D = 0.45;
  public static inline var KEY_H = 0.09;
  public static inline var KEY_W = 1.60;
  public static inline var KEY_D = 0.58;
  // where the two sit on the worktop, measured from the DESK TOP's back edge forward — see
  // DESK_TOP_D, which is what these were wrongly taken off the cell for. Fitted so both clear the
  // top: the monitor's back lands 0.45 inside it (centre 0.975, half-depth 0.225) and the
  // keyboard's front lip 0.435 inside (centre -0.925, half-depth 0.29)
  public static inline var MON_BACK = 0.675;
  public static inline var KEY_FWD = 1.90;
  // one desk cell in this many carries a workstation. A DESK RUN IS NOT A CALL CENTRE: every cell
  // manned puts a monitor every 2 m down a wall, which reads as a bank of screens rather than as
  // an office
  public static inline var WORK_EVERY = 2;
  public static inline var PLANT_H = 2.8;      // 1.4 m
  public static inline var PLANT_W = 1.35;
  public static inline var COOLER_H = 2.2;     // 1.1 m
  // and the two footprints, MEASURED on the built glbs rather than chosen: both props are
  // hand-modelled at world size now (models-src/corp/appliance_build.py), so the collar's 0.03
  // oversail and the output slot's 0.03 proud are part of what they really occupy
  public static inline var COOLER_W = 0.58;
  public static inline var PRINTER_H = 2.2;
  public static inline var PRINTER_W = 1.05;
  public static inline var PRINTER_D = 1.33;
  // the percent chance a standing copier gets a bin beside it when its room already holds one —
  // render.corp.CorpDeco.bins; with none in the room it always does
  public static inline var COPIER_BIN_PCT = 50;
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
  // AND THE EXEC OFFICE'S OWN SHEET, a PACK16: an executive's desk carries fewer, bigger things
  // than a clerk's, so the 4x4 of 256 px cells is dealt fewer to a cell and drawn larger. Its last
  // two cells (the photo print and the brass nameplate face) are not decals at all but the faces of
  // the desk trinkets, so only the first CLUTTER_EXEC_CELLS are dealt
  public static inline var CLUTTER_EXEC_TEX = 'textures/corp/exec-clutter.png';
  public static inline var CLUTTER_EXEC_COLS = 4;
  public static inline var CLUTTER_EXEC_CELLS = 14;
  public static inline var CLUTTER_EXEC_MAX = 2;
  public static inline var CLUTTER_EXEC_SZ = 0.80;
  public static inline var CLUTTER_EXEC_SZ_VAR = 0.45;
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

  // THE CUBICLE PANEL'S OWN SHEET, and the first PACK36 in the repo. 6x6 rather than the worktops'
  // 8x8 for one reason and it is not the density: a partition is what a worker pins his own things
  // to, and 36 subjects is already more than a floor's panels can show without repeating - the
  // measurement in docs/3d-textures.md puts a 170 px cell at ~138 art px, i.e. 197 texels per unit
  // over the 0.7 a pinned sheet is drawn at, which is nearly triple the carpet's
  public static inline var PANEL_TEX = 'textures/corp/panel-clutter.png';
  public static inline var PANEL_COLS = 6;
  public static inline var PANEL_CELLS = 36;
  // how many things one FACE of a panel may carry, and zero is reachable for the reason
  // CLUTTER_MAX is: a farm where every bay is dressed reads as a display and not as an office.
  //
  // 2 -> 3 when the pod's BACK panel went bare: the monitor stands against it, so everything
  // pinned there was behind a screen. The two sides carry the bay's whole dressing now
  public static inline var PANEL_MAX = 3;
  public static inline var PANEL_SZ = 0.55;
  public static inline var PANEL_SZ_VAR = 0.35;
  // the band of the panel's height things are pinned in, as a fraction of PARTITION_H. Nothing
  // sits on the trim rail and nothing hangs below the worktop the panel stands on.
  //
  // THE BAND IS THE CENTRE'S AND THE ITEM HAS A HALF HEIGHT, which is what PANEL_HI 0.90 forgot:
  // 2.8 * 0.90 = 2.52 plus a half size of up to 0.45 is 2.97, a fifth of a unit ABOVE the panel,
  // straight over the aluminium trim capTrim pins to v 0.9643..1.0. PANEL_TOP_GAP is the clear air
  // left under that rail and the clamp in CorpClutter.face is what enforces it
  //
  // AND THE WORKTOP IS THE OTHER END OF IT. A face that looks at a desk has DESK_H 1.5 of bench
  // across its bottom, so PANEL_LO 0.55 * 2.8 = 1.54 less a half size put the lower row BEHIND the
  // desk — reported as clutter that "goes under the table". PANEL_BOT_GAP is the clear air left
  // over the worktop, and the clamp only fires on a face that has a desk in front of it
  public static inline var PANEL_LO = 0.55;
  public static inline var PANEL_HI = 0.90;
  public static inline var PANEL_TOP_GAP = 0.05;
  public static inline var PANEL_BOT_GAP = 0.05;
  // how far proud of the panel face a decal hangs, and how far in from the run's ends it keeps
  public static inline var PANEL_PROUD = 0.03;
  public static inline var PANEL_END = 0.35;
  // and how big the PROPAGANDA POSTER on a panel is, and how many of the faces that CAN carry one
  // do. Only a face looking at the passage is eligible (render.corp.CorpFurniture.aisleFace) — the
  // desk side is the worker's own wall — but "every eligible face" was overboard: 50 posters on 62
  // faces turned the farm into a gallery. A passage wall is mostly the usual pinned clutter with
  // the occasional poster on it, which is this roll. Drawn by render.corp.CorpSigns into the sheet
  // it already owns, so it costs no draw call
  public static inline var PANEL_POSTER_MAX = 1.5;
  public static inline var PANEL_POSTER_PCT = 12;
  // the clearance between two items, counted ONCE per pair
  public static inline var CLUTTER_GAP = 0.10;

  // SIX OF THE SIXTY-FOUR CELLS ARE PROPS AND NOT DECALS, and the rule behind the list is worth
  // stating because it decides the next one too: a PACK64 cell is a flat cut-out seen from
  // overhead, which is not a compromise for a sheet of paper, a folder or a mouse mat — those
  // really are flat — and is a lie for anything carried by a ROUND or UPRIGHT silhouette, because
  // no top-down art can give an object a side. Reported from the game cell by cell.
  //
  // FOUR GLBS FOR SIX CELLS, which is what the pairs buy: a mug and a glass tumbler are one lathe,
  // a vacuum flask and a water bottle are one shouldered cylinder. Cells 24 (the amber pen pot)
  // and 48 (the takeaway cup) STAY DECALS on purpose — at 51 degrees a pen pot is a disc of pen
  // ends and a paper cup is a disc with a lid, and neither is worth the draw call an instanced
  // batch costs, which is the number this route really spends
  public static inline var CLUTTER_MUG = 0;
  public static inline var CLUTTER_BOTTLE = 1;
  public static inline var CLUTTER_PLANT = 2;
  public static inline var CLUTTER_CAM = 3;
  public static inline var CLUTTER_PROPS = 4;
  // which prop an atlas index becomes, or -1 for a cell that stays a decal. indexed by cell
  public static var CLUTTER_PROP_OF: Map<Int, Int> = [
    3 => CLUTTER_MUG,        // the ceramic mug
    5 => CLUTTER_MUG,        // the glass tumbler
    4 => CLUTTER_BOTTLE,     // the steel flask
    49 => CLUTTER_BOTTLE,    // the water bottle
    25 => CLUTTER_PLANT,     // the potted succulent
    58 => CLUTTER_CAM,       // the tripod webcam
  ];
  // their DRAWN heights, in the order above, and their glb paths. every one of them is built at
  // world size, so render.Models.instanced scales by 1 wherever the number here is the glb's own —
  // and the PLANT is deliberately not: at its built 0.2534 it was reported as too small on a desk,
  // and 2x is the number asked for
  public static var CLUTTER_PROP_H = [0.19, 0.52, 0.5068, 0.17];
  // and their FOOTPRINT RADIUS PER UNIT OF HEIGHT, which is the form that survives an edit to the
  // line above. render.Models.instanced scales an instance by HEIGHT ALONE, so a hand-typed width
  // goes stale the moment a height moves — the trap docs/3d-render.md records against
  // render.sewer.SewerProp.margin, where three of five props ended up standing inside a wall. Half
  // the glb's own widest horizontal extent over its own height: mug 0.207/0.19, bottle 0.11/0.52,
  // plant 0.182/0.253, cam 0.104/0.17 (art/models.json's notes carry all eight numbers)
  public static var CLUTTER_PROP_R = [0.5447, 0.1058, 0.3597, 0.3059];
  public static var CLUTTER_PROP_PATH = [
    RenderConfig.MODELS.corpDeskMug,
    RenderConfig.MODELS.corpDeskBottle,
    RenderConfig.MODELS.corpDeskPlant,
    RenderConfig.MODELS.corpDeskCam,
  ];

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
  // ONE PANEL PER THIS MANY CELLS of the run, spread the way CorpLamps.lattice spreads a fixture:
  // (i + 0.5) / n, so a run under the spacing still falls to one panel on its own centre and a
  // long corridor wall carries several instead of one lost in the middle of it
  public static inline var SIGN_SPACING = 6;

  // the SECOND sheet: four more quadrants, propaganda and the boardroom's own two — see
  // CorpSigns.ASPECT, which holds all eight. A second atlas is a second material and so a second
  // draw call, and it is that rather than a re-roll of `signs` because those four are fitted
  public static inline var POSTER_TEX = 'textures/corp/posters.png';
  // a projector screen is not a plate. its longest edge, against SIGN_MAX 2.1 — sized so the quad
  // still clears CEIL_Y: at the art's 1.4263 it stands 2.10 tall about SIGN_Y, i.e. 3.55 to 5.65
  public static inline var SCREEN_MAX = 3.0;
  // and the shortest boardroom wall that earns one. under this the room takes a chart instead
  public static inline var SCREEN_RUN_MIN = 4;

  // the THIRD sheet, and the first 4x4 one: sixteen cells of the paperwork, fire plates,
  // evacuation diagrams and department markers a real floor is signed with — CorpSigns.SHEETS
  // holds it beside the other two and CorpSigns.ASPECT all twenty-four aspects. A third atlas is
  // a third material and a third draw call, but NOT a third program: the three share one
  // MeshLambertMaterial shape, so CorpWarm needs nothing for it
  public static inline var SIGN2_TEX = 'textures/corp/signs2.png';

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
  // a recessed panel is a LONG rectangle and follows the long axis of the room it lights
  public static inline var PANEL_W = 2.6;
  public static inline var PANEL_H = 0.9;
  public static inline var PANEL_DROP = 0.05;
  // how far a ground-lying glow floats over the floor. under the tactical grid's own 0.06
  public static inline var GLOW_Y = 0.04;
  // and how far inside a room's own rect its pool stops
  public static inline var POOL_INSET = 1.6;

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
  // THE LIFT SHAFT under the car, which is not glazing: the exposed steel frame the glass car rides
  // on, its own art (corp/lift-shaft) with no lit bays. The art is two X-braced bays square, so a
  // repeat of two storeys (WALL_H 6) puts one bay on each storey
  public static inline var SHAFT = 'textures/corp/lift-shaft.png';
  public static inline var SHAFT_TILE = 12.0;
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

  // how thick the tower draws an INTERIOR wall, against the compound's FacilityStyle.WALL_T 2.0
  // (half a cell, one real metre). A doorway's REVEAL is exactly this deep — render.facility
  // .FacilityGeom.slab insets a wall cell by (CELL - thick) / 2 on every hand the wall line stops,
  // and a door cell's two wall-line neighbours carry, so the opening comes out full width and the
  // two jambs come out `thick` deep and DOOR_H + KERB_DROP tall. At 2.0 that is a 4.2-high, 2.0-deep
  // masonry tunnel at every office door, which is what "door frame walls are too large" was
  // pointing at: the OPENING is already the whole 4-unit cell and the two leaves already fill it,
  // so nothing was narrowing the door — the reveal was simply a compound's wall.
  //
  // the PERIMETER is untouched at WALL_T, by FacilityGeom.thick's own four-hand test: the parapet,
  // the window shoulders and CorpFacade's ring plane are all arithmetic on that number
  public static inline var WALL_INNER = 1.2;

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
  // 28 -> 80, and what it buys is a CONVOY of `ceil(CARS / lanes)` per lane rather than more
  // traffic. Requiring BOTH ends of a lane to leave the plate — so that no car ever fades in
  // pointed at the tower — took this plate's road lanes from 46 to 16, and a pass no longer fills
  // its window either: it runs at or above the lane's base speed, waits out the slack, and may be
  // skipped. The mean actually drawn is 29, against the 28 drawn every single frame before
  public static inline var CARS = 80;
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
  // what the people quad's albedo is multiplied by, before the street's own moon.
  //
  // 0.55 -> 0.13 on "street citizens look too bright", and THE LAMBERT WAS NOT THE FIX this note
  // used to say it was: the quad and the road are lit by the same three lights, so going Lambert
  // scales both and leaves the RATIO exactly where it was. Measured off the built sheets, mean
  // linear luminance over opaque pixels times each material's own colour: road 0.0329 x 0.45 =
  // 0.0148, car body 0.0255 x 0.85 = 0.0217, and a walker **0.4326** x 0.55 = **0.2379** — 16x the
  // road and 11x a car, which is a person rendered as a light source.
  //
  // THE SOURCE IS THE WHOLE OF IT AND THIS NUMBER IS THE ONLY LEVER ON IT. A civilian icon is a
  // HUD portrait, authored flat and high-value (0.43 linear, srgb 175) to read on the game's dark
  // interface; a street texture is night asphalt at 0.033. 0.13 is fitted to cancel that 13x and
  // leave the icon where a person's clothing actually sits against tarmac — effective 0.056, about
  // 3.8x the road and 2.6x a car body, still the brightest thing on the street
  public static inline var WALK_DIM = 0.13;
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
  // live, like STREET_DIM itself. Lambert for the walkers' reason.
  //
  // 0.60 -> 0.85 on "cars became way too dark", and THE MULTIPLIER IS NOT WHAT FIXED THAT. Measured
  // on the drop under the street's own moon: body 0.0027 linear against a road at 0.0010 and a
  // walker at 0.1109. The art is a matte unlit car panel at night and there is nothing in it to
  // reveal — 40x the multiplier would be needed to reach the icons, and it would reach it as grey
  // mush. What makes a car read as traffic is CAR_LIGHT_* below
  public static inline var CAR_DIM = 0.85;
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
  // THE HEADLIGHTS, AND THEY ARE THE GRADIENT THAT WAS ALREADY HERE. render.Textures
  // .makeGlowGradient is the 64px centred radial falloff the first 3D pass drew the whole crowd
  // with, and it has been referenced by nothing at all since the civilian sheets replaced it. The
  // paragraph above says why a car is not a patch of light — but the two dots at its nose are
  // exactly that, and the traffic sheet was generated with them as "clearly the brightest thing on
  // the whole image". Two per car in ONE additive batch, so the street's lights are one draw call.
  public static inline var CAR_LIGHT_COLOR = 0xfff0c0;
  // one lamp's quad, world units. far wider than a lens because what is drawn is the GLOW
  public static inline var CAR_LIGHT_SZ = 2.2;
  // where the pair sits on its own car, as fractions of that CELL's measured crop — so a van's
  // lights are as far apart as a van is wide. `IN` is back from the nose, `SPREAD` is either side
  // of the centre line
  public static inline var CAR_LIGHT_IN = 0.1;
  public static inline var CAR_LIGHT_SPREAD = 0.3;
  // and clear of the car quad's own plane: the traffic batch is opaque and writes depth, so a glow
  // at CROWD_Y exactly would lose the depth test to the car it belongs to
  public static inline var CAR_LIGHT_Y = 0.12;
  // how bright, before the additive blend. NOT a dim — nothing multiplies a glow down here and the
  // gradient's own falloff is the whole of the shape
  public static inline var CAR_LIGHT_MUL = 0.8;

  // HOW FAR FROM ITS LANE'S END AN AGENT IS STILL FADING, world units.
  //
  // A CLOSED-FORM CROWD BLINKS AT THE MODULO and there is nowhere else it can blink: position is
  // `(phase * len + clock * v) % len`, so the wrap teleports the agent from one end of its lane to
  // the other in one frame. Reported from the game as people popping in and out of existence.
  // Fading both ends of the run is the whole fix, and it costs one float per instance.
  //
  // Two numbers because the two families differ 7x in speed: 8 units is ~3s of walking and 10 is
  // ~0.5s of driving, which is what a car wants — any longer and a lane shorter than 2 * FADE
  // never reaches full opacity at all, which is what CAR_LANE_MIN below now guarantees it is not
  public static inline var WALK_FADE = 8.0;
  public static inline var CAR_FADE = 10.0;

  // the shortest straight run of cells that is worth walking down
  public static inline var LANE_MIN = 6;
  // AND A LONGER ONE FOR TRAFFIC, because a car covers seven times the ground a walker does: at
  // CAR_SPEED 20 a LANE_MIN lane is 24 units and 1.2 SECONDS end to end, and with CAR_FADE 10 on
  // each end it never even reaches full opacity — reported from the game as a "very short car run".
  // 16 cells is 64 units: 3.2s, with 44 of them at full. Measured on the tower's own plate, the
  // lengths are 6, 33, 37, 49, 77, 84, 108 and 156 cells, so this drops exactly the two stubs and
  // keeps all 44 real runs. CorpCrowd falls back to LANE_MIN if a plate has nothing longer
  public static inline var CAR_LANE_MIN = 16;
  // HOW ONE PASS DOWN A LANE VARIES, which is what stops the traffic reading as a loop — see
  // CorpCrowd.drive. `SKIP` is the percent of passes a car sits out entirely and `SPEED_JIT` how
  // much faster than the lane's own base speed it may run, as a fraction; the leftover time is
  // slack it may start anywhere inside. A pass is never SLOWER than the base, because the lap is a
  // fixed window and a slower one would not finish inside it.
  //
  // THEY ARE ONLY SAFE BECAUSE A CAR OWNS ITS LANE. With two cars on one line a varying speed is
  // the exact defect `Lane.v` was introduced to cure — see the typedef
  public static inline var CAR_SKIP = 15;
  public static inline var CAR_SPEED_JIT = 0.6;

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
      floor[Surf.RECEPTION] = FLOOR_RECEPTION;
      floor[Surf.WASHROOM] = FLOOR_WASHROOM;
      floor[Surf.SERVER] = FLOOR_SERVER;
      floor[Surf.LIFT] = FLOOR_LIFT;
      // an interior face is picked off the surface it LOOKS INTO, so the corridor side of a
      // partition is painted board and the boardroom side of the same slab is not
      var into = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) WALL_OFFICE];
      into[Surf.MEETING] = WALL_MEETING;
      into[Surf.KITCHEN] = WALL_KITCHEN;
      into[Surf.EXEC] = WALL_EXEC;
      into[Surf.RECEPTION] = WALL_RECEPTION;
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
          pocket: LIFT_POCKET,
          sill: LIFT_SILL,
          door: [DOOR_GLASS, DOOR_OFFICE, DOOR_STEEL, DOOR_PRIVATE, DOOR_LIFT],
          circ: Surf.CARPET,
        },
        surfOf: CorpModel.surfOf,
        fitOf: CorpModel.fitOf,
        // BOTH families, and the second one is why an executive office and a reception counter
        // used to draw nothing: gen.corp.CorpRooms.execDesk lays DARK_TABLE_MARBLE1_3X2, which is
        // on tileset rows 14 and 16 and so falls outside isCorpTableTile's four rows entirely
        tableOf: function(t:Int) return Const.isCorpTableTile(t) || Const.isCorpDeskBlock(t),
        wallOf: CorpModel.wallOf,
        // an office partition is a stud wall and not blockwork — see WALL_INNER
        wallIn: WALL_INNER,
        // and NO hangars: the lift car is nine cells of concrete in a ring of its own, which the
        // concrete-majority test would call a shed and arch a barrel vault over
        hangars: false,
      };
    }
}

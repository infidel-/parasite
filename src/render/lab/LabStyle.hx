package render.lab;

import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.facility.ShellOpts;

// one lit-fluid machine's glow on the floor before it (LabInterior.machine): its colour and strength
typedef LabTankGlow = {
  color:Int,
  mul:Float,
  // a FAKE glow: no lamp, a trapezoid on the floor (LabInterior.fake) and a light only the actors'
  // fake shadows see; a real one takes a pool lamp
  ?fake:Bool,
  // a fake one glowing on ALL sides of a round piece: one smaller square of the glow centred under it,
  // its light over the axis
  ?ring:Bool,
  // a fake one's width at its front, where the tank is wider than TANK_SPILL_W
  ?w:Float,
};

// the underground lab's art set and its tuning constants: the shell's ShellTex, the scene rig and
// the numbers the lab's own passes are written against.
//
// the lab is a SHELL KIND like the corp tower — render.facility's emitters build its floors, walls
// and doorways off this ShellTex — and it shares nothing else: every path below is lab art
// (art/textures.json `lab/*`, four packed 2x2 sheets and a door sheet)
class LabStyle
{
  // ---- the shell: floors, one per Surf the lab paints
  public static inline var FLOOR_ENTRANCE = 'textures/lab/floor-entrance.png';
  public static inline var FLOOR_VAT = 'textures/lab/floor-vat.png';
  // the world size the grid floors (vat hall, store) tile at: two 4-unit cells
  public static inline var FLOOR_GRID_SZ = 8.0;
  // the borrowed electrical kit's size against the compound's (ShellTex.elecScale)
  public static inline var ELEC_SCALE = 0.8;
  // and its art's brightness (ShellTex.elecTint)
  public static inline var ELEC_TINT = 0.5;
  public static inline var FLOOR_CORRIDOR = 'textures/lab/floor-corridor.png';
  public static inline var FLOOR_WORKSHOP = 'textures/lab/floor-workshop.png';
  public static inline var FLOOR_STORAGE = 'textures/lab/floor-storage.png';
  public static inline var FLOOR_RESEARCH = 'textures/lab/floor-research.png';
  public static inline var FLOOR_PAD = 'textures/lab/floor-pad.png';
  // the interior wall faces, picked off the room a face LOOKS INTO
  public static inline var WALL_ENTRANCE = 'textures/lab/wall-entrance.png';
  public static inline var WALL_VAT = 'textures/lab/wall-vat.png';
  public static inline var WALL_CORRIDOR = 'textures/lab/wall-corridor.png';
  public static inline var WALL_WORKSHOP = 'textures/lab/wall-workshop.png';
  public static inline var WALL_STORAGE = 'textures/lab/wall-storage.png';
  public static inline var WALL_RESEARCH = 'textures/lab/wall-research.png';
  // the bedrock: the cap over every rock cell (LabGeom) and the cladding on every wall face that
  // looks into rock, which the cap hides from this camera anyway
  public static inline var ROCK = 'textures/lab/rock.png';
  // the wall head, poured concrete
  public static inline var COPING = 'textures/lab/coping.png';
  // the four door leaves, one per look (LabDoors)
  public static inline var DOOR_BLAST = 'textures/lab/door-blast.png';
  public static inline var DOOR_SERVICE = 'textures/lab/door-service.png';
  public static inline var DOOR_RESEARCH = 'textures/lab/door-research.png';
  public static inline var DOOR_VAT = 'textures/lab/door-vat.png';

  // ---- the rock cap
  // how many cells past the area's edge the cap carries on, so the camera at the plate's rim looks
  // at more bedrock rather than at the fog colour where the grid stops
  public static inline var ROCK_MARGIN = 14;
  // the cap's own tile, world units per repeat — the rock's facets are fist-to-head sized at this
  public static inline var ROCK_TILE = 10.0;

  // ---- the doors
  // a blast leaf is a CELL wide (the doorway is two) and thicker than the compound's 0.12 leaf
  public static inline var DOOR_T = 0.28;
  // how far past CELL a leaf slides, so its stile does not stop in the reveal's own plane — the
  // trap FacilityStyle.DOOR_SLIDE_CLEAR records for the corp lift
  public static inline var DOOR_CLEAR = 0.06;
  // an opening slides shut or open over this many BASE_MS — heavier than the compound's swing (0.6
  // snapped shut)
  public static inline var DOOR_MULT = 3.0;
  // a pair's cull radius about the opening's centre: a slid leaf's far stile is 2 CELL + DOOR_CLEAR
  // out, plus the leaf's own height for the sphere
  public static inline var DOOR_CULL_R = 10.0;

  // ---- the clone vats (render.lab.LabVats, models-src/lab/vat_build.py). every height is the glb's
  // measured one, so Models.instanced draws each part at scale 1 and the script's numbers hold
  public static inline var VAT_H = 9.8636;         // the frame, slab to the feed pipes' crown
  // the cylinder's axis north of the 2x3 footprint's centre: on the back 2x2's centre (AXIS_Y)
  public static inline var VAT_AXIS = 2.0;
  public static inline var VAT_GLASS_Y = 1.0;      // the base ring's top, where glass and medium stand
  public static inline var VAT_GLASS_H = 7.0;
  public static inline var VAT_FLUID_H = 6.7;
  public static inline var VAT_GLASS_OPACITY = 0.22;
  public static inline var VAT_FLUID_OPACITY = 0.5;
  // the medium's foot over the base ring's top, which it z-fought through the fluid
  public static inline var VAT_FLUID_LIFT = 0.03;
  // the medium's glow (render.lab.LabWater.patchVat), and the colour its sheet is worn in: the 2D vat
  // sprite's salad green (measured 112,182,144 over its lit fluid), where the sheet's own olive read
  // "too primal"
  public static inline var VAT_FLUID_GLOW = 0x1c5a3a;
  public static inline var VAT_TINT = 0x70b690;
  // the fluid sheet's mean linear luminance (models-src/lab/fluid-sheet.png), so the tint keeps its
  // value; the swirl's phase speed per BASE_MS; how far the flow bends the sheet's lookup, in uv
  public static inline var VAT_SHEET_LUM = 0.0506;
  // how much of the tint the medium's surface takes as albedo: at the full tint it lit up mint and
  // hid the clone, which the 2D vat shows through its fluid
  public static inline var VAT_TINT_K = 0.3;
  public static inline var VAT_SWIRL_RATE = 0.12;
  public static inline var VAT_WARP = 0.012;
  // the bubbles: columns round the turn, the climb of one cell, its rise in cells per BASE_MS, and a
  // bubble's radius, world units
  public static inline var VAT_BUB_N = 28;
  public static inline var VAT_BUB_CELL = 0.9;
  public static inline var VAT_BUB_RISE = 0.08;
  public static inline var VAT_BUB_R = 0.09;
  // the share of cells with no bubble in them, and the radius off the axis past which the side starts
  // (the medium is r 3.12; its lid is inside this)
  public static inline var VAT_BUB_ON = 0.78;
  public static inline var VAT_BUB_RIM = 3.0;
  // the clone floats CLONE_FLOAT clear of the ring, CLONE_H from its feet to its tentacles' tips
  public static inline var CLONE_H = 5.0;
  public static inline var CLONE_FLOAT = 0.6;
  public static inline var CLONE_YAW = 0.0;
  // the medium's light on it, through its own map
  public static inline var CLONE_GLOW = 0x6fd49a;
  // its sway in the medium at its crown, its bob, world units, and their phase speed per BASE_MS
  public static inline var CLONE_SWAY = 0.18;
  public static inline var CLONE_BOB = 0.12;
  public static inline var CLONE_SWAY_RATE = 0.35;
  public static inline var CLONE_SLUMP_H = 1.4;
  // the floating clone fades out while the level falls CLONE_FADE either side of this fraction of its
  // height (world units), and the heap fades in over the HEAP_FADE the surface falls below its top
  public static inline var CLONE_SLUMP_AT = 0.35;
  public static inline var CLONE_FADE = 1.5;
  public static inline var HEAP_FADE = 1.0;
  // a purged vat drains over this many BASE_MS
  public static inline var VAT_DRAIN_MULT = 20.0;
  // the amber tanks' fetuses (LabWater.patchEmbryo): the sway's reach in the glb's units (the tank
  // is drawn at scale 1), the height under which nothing moves (the tank floor is at 1.09), and the
  // uv rects (u0, v0, u1, v1, glTF's v down) of the fetus skin and its eyes on the body's atlas
  public static inline var EMBRYO_SWAY = 0.05;
  public static inline var EMBRYO_FOOT = 1.12;
  public static var EMBRYO_SKIN = [0.27, 0.57, 0.405, 0.88];
  public static var EMBRYO_EYE = [0.112, 0.949, 0.138, 0.986];
  // each vat's own green lamp, faded out with its level: out in front of the glass, off the axis by
  // VAT_LAMP_OUT and aimed VAT_LAMP_AIM out, so it lays the medium's colour on the floor past the
  // console the way the amber tanks do (inside the glass it lit the glass and little else)
  public static inline var VAT_LAMP_Y = 3.6;
  public static inline var VAT_LAMP_OUT = 3.85;
  public static inline var VAT_LAMP_AIM = 9.0;
  public static inline var VAT_LAMP_COLOR = 0x7cff9a;
  public static inline var VAT_LAMP_MUL = 1.6;
  // the medium's light on the floor round each vat (LabVats.pool, additive, the vat's level): a radial
  // glow VAT_POOL_R about the axis at VAT_POOL_Y, clipped at the room's walls, VAT_POOL_GLOW times the
  // lamp's colour at its centre (0.4 blew out where four vats' pools meet, 0.11 read too opaque). The
  // plinth covers the inner 3.6
  public static inline var VAT_POOL_R = 8.0;
  public static inline var VAT_POOL_Y = 0.04;
  public static inline var VAT_POOL_GLOW = 0.06;
  // the plinth slab the glow is laid over too (models-src/lab/vat_build.py: 7.8 x 11.8, 0.3 tall), its
  // half-sizes and the glow's height over it
  public static inline var VAT_SLAB_HW = 3.9;
  public static inline var VAT_SLAB_HD = 5.9;
  public static inline var VAT_SLAB_Y = 0.31;
  // a vat's cull radius about its placement: the frame is 7.8 x 11.8 and 10.3 tall
  public static inline var VAT_CULL_R = 12.0;

  // ---- the lift (render.lab.LabLift, models-src/lab/lift_build.py)
  public static inline var LIFT_SHAFT_H = 10.33;   // the shaft glb's measured height
  public static inline var LIFT_DECK_GLB_H = 2.95; // the car glb's, guard rail and clamps included
  public static inline var LIFT_DECK_H = 0.25;     // the deck's tread, which is what anyone stands on
  // the car comes down from this far up the shaft on arrival, over this many BASE_MS. 5.5 keeps its
  // rope clamps under the sheave the whole way
  public static inline var LIFT_DROP = 5.5;
  public static inline var LIFT_MULT = 16.0;
  public static inline var LIFT_CULL_R = 10.0;

  // ---- the furniture and the box machines (render.lab.LabInterior): a piece's cull radius about its
  // placement, the container's half-diagonal and its height
  public static inline var PIECE_CULL_R = 9.0;
  // the suits on a hazmat rack: their height, the rail's height off the floor and its reach out of the
  // rack's centre (models-src/lab/labkit_build.py hazmat, rail at 4.0 over a rack whose foot is 0.4
  // up, 0.47 in front of its centre), how many hang on one rack and how far apart
  public static inline var SUIT_H = 3.3;
  public static inline var SUIT_HOOK = 3.6;
  public static inline var SUIT_RAIL = 0.47;
  public static inline var SUIT_N = 3;
  public static inline var SUIT_GAP = 1.22;
  // one hung suit in this many is the torn one
  public static inline var SUIT_TORN = 5;

  // ---- the flat cut-outs (render.lab.LabDecals): the four pack sheets; a floor cell's odds, in
  // thousandths, of a grime decal and of a painted mark; their sizes (base + up to VAR); the height
  // they lie at over the floor; the bench tops' item size and lift; the tries an item gets to find
  // room on its top; and the alpha cut
  public static inline var DECAL_GRIME_TEX = 'textures/lab/floor-decals.png';
  public static inline var DECAL_MARKS_TEX = 'textures/lab/floor-marks.png';
  public static inline var DECAL_RESEARCH_TEX = 'textures/lab/bench-research.png';
  public static inline var DECAL_WORKSHOP_TEX = 'textures/lab/bench-workshop.png';
  public static inline var GRIME_RATE = 80;
  public static inline var MARK_RATE = 40;
  public static inline var GRIME_SZ = 1.8;
  public static inline var GRIME_SZ_VAR = 1.0;
  public static inline var MARK_SZ = 2.0;
  public static inline var MARK_SZ_VAR = 0.6;
  public static inline var DECAL_Y = 0.02;
  // the amber tanks' fluid on their glass (render.lab.LabWater): its glow, the ripple's phase speed
  // per BASE_MS, the bubble columns' spacing, the climb of one bubble cell and its rise in cells per
  // BASE_MS, a bubble's radius and the fluid's top over the floor
  public static inline var WATER_TINT = 0x6a3608;
  public static inline var WATER_RATE = 0.09;
  public static inline var WATER_COL = 0.32;
  public static inline var WATER_CELL = 0.7;
  public static inline var WATER_RISE = 0.05;
  public static inline var WATER_BUBBLE = 0.09;
  public static inline var WATER_TOP = 3.35;
  // the lamp the tank's fluid lights the floor with: how far out of its front, its bulb height, how
  // far out it aims, its colour and strength
  public static inline var TANK_LAMP_OUT = 0.6;
  public static inline var TANK_LAMP_Y = 2.4;
  public static inline var TANK_LAMP_AIM = 3.0;
  // a fake glow's trapezoid (LabInterior.fake): its width at the front, how far it reaches out, how
  // much wider each side its far edge is, how far under the piece it starts, its height and the mesh's
  // strength over each glow's own (additive in linear: 0.35 and 0.12 read as a torch beam, 0.05 too
  // opaque)
  public static inline var TANK_SPILL_W = 3.0;
  public static inline var TANK_SPILL_DEPTH = 6.5;
  public static inline var TANK_SPILL_SPREAD = 2.2;
  public static inline var TANK_SPILL_IN = 0.4;
  public static inline var TANK_SPILL_Y = 0.04;
  public static inline var TANK_SPILL_GLOW = 0.03;
  // a ring glow's reach past the piece's own radius: the square's half-side, so its rounded core
  // (Textures.makeRectGlowGradient's 0.3) stays under the piece and the fade lands about this far out
  public static inline var TANK_RING_OUT = 1.3;
  // and which machines' fluid does it, by gen.lab.LabKinds name: the amber tanks, the blue tube and
  // stasis pod, the teal specimen case (its glass's own colour: the green it had read as another
  // light) and the embryonic bank
  public static var TANK_GLOW:Map<String, LabTankGlow> = [
    'ambertanks' => {
      color: 0xffa040,
      mul: 0.9,
      fake: true,
      w: 5.6,
    },
    'tube' => {
      color: 0x5ad2ff,
      mul: 0.9,
      fake: true,
      ring: true,
    },
    'stasis' => {
      color: 0x8ae0ff,
      mul: 0.8,
      fake: true,
    },
    'specimencase' => {
      color: 0x6ae8d8,
      mul: 0.8,
      fake: true,
    },
    'embryonic' => {
      color: 0x5cffc0,
      mul: 0.8,
    },
  ];
  // the glowing plants' halos on the floor round them (LabInterior.halos): how far past the plant's
  // own half-width the round falloff reaches, and each one's colour (its emissive map's mean, measured)
  // and strength over the tank spill's TANK_SPILL_GLOW (a halo's disc is a fraction of a trapezoid's
  // area: at the tanks' 0.9 it did not show). Only the three whose glow covers a share of the plant;
  // plant4's is 0.7% of its map
  public static inline var PLANT_HALO_OUT = 1.0;
  public static var PLANT_GLOW:Map<String, LabTankGlow> = [
    'models/lab/plant5.glb' => {
      color: 0xae65ff,
      mul: 2.4,
    },
    'models/lab/plant1.glb' => {
      color: 0x5affde,
      mul: 2.0,
    },
    'models/lab/plant6.glb' => {
      color: 0x88ffd8,
      mul: 1.4,
    },
  ];
  // a desk's chair (LabInterior.chair): how far its seat tucks under the desk's edge, how far more it
  // is pulled out at most, how far off the desk's centre it slides either way, its swing off square and
  // the share swung well round (left as someone got up) with that swing
  public static inline var CHAIR_TUCK = 0.45;
  public static inline var CHAIR_PULL = 0.9;
  public static inline var CHAIR_SIDE = 0.5;
  public static inline var CHAIR_TURN = 0.35;
  public static inline var CHAIR_ASKEW_PCT = 20;
  public static inline var CHAIR_ASKEW = 1.3;
  // the lab's two moving lights (render.lab.LabSpin). The lift's beacon: its place off the shaft's
  // centre (models-src/lab/mach/liftshaft.py BX, BY: x 4.4, hung tip-down under the back girder's lip
  // on y 4.55, the bulb just under the dome's 7.63 tip and the guard cage's 7.60 so neither shadows
  // it), its colour and strength, how far out its beam lands, its turns per BASE_MS, and over what
  // share of the turn's cosine off the open +z hemisphere it goes dark: the shaft backs onto the
  // lobby's north wall 0.45 behind it, and a beam turned past it lit the bedrock over the wall
  public static inline var SPIN_BEACON_X = 4.4;
  public static inline var SPIN_BEACON_Z = -4.55;
  public static inline var SPIN_BEACON_Y = 7.55;
  public static inline var SPIN_BEACON_COLOR = 0xffa030;
  public static inline var SPIN_BEACON_MUL = 2.2;
  public static inline var SPIN_BEACON_OUT = 9.0;
  public static inline var SPIN_BEACON_RATE = 0.35;
  public static inline var SPIN_BEACON_DARK = 0.05;
  public static inline var SPIN_BEACON_FADE = 0.35;
  // its turning reflector and its glass dome (liftshaft.py beacon()): each one's foot off the floor and
  // its measured height, so both draw at the scale they were built, and the dome's glow in its light
  public static inline var SPIN_REFLECTOR_Y = 7.76;
  public static inline var SPIN_REFLECTOR_H = 0.38;
  public static inline var SPIN_DOME_Y = 7.63;
  public static inline var SPIN_DOME_H = 0.53;
  public static inline var SPIN_DOME_GLOW = 0.45;
  // and how far out its fake actor shadows reach down the beam: past the 9.0 it lands at by the pool's
  // own spread
  public static inline var SPIN_BEACON_REACH = 16.0;
  // the workshop fan: the blades' height off the floor (the fan hangs at the walls' 6.0 head), the
  // two glbs' measured heights (models-src/lab/mach/fan.py), the work lamp's height over the blades
  // and its strength, and the rotor's turns per BASE_MS (0.6 strobed the blades' shadows)
  public static inline var FAN_Y = 5.7;
  public static inline var FAN_BLADES_H = 0.1;
  public static inline var FAN_BODY_H = 1.02;
  public static inline var FAN_LAMP_UP = 1.9;
  public static inline var FAN_LAMP_MUL = 1.5;
  public static inline var FAN_RATE = 0.08;
  // frost round the cold machines (render.lab.LabDecals.frost, lab/frost): the sheet, the kinds that
  // shed it, the floor patches' spacing round the footprint and how far out of it they sit, their
  // size and its spread, the wall crust's size and how far proud of the masonry it stands, which
  // floor cells ring a footprint (not the hollow ring, which stacked into a row of loops along an
  // edge), and which wall cells stand on the floor and which hang icicles
  public static inline var FROST_TEX = 'textures/lab/frost.png';
  public static var FROST_KINDS = ['cryobank', 'coldbank', 'cryopod', 'stasis', 'sr203'];
  public static inline var FROST_STEP = 1.1;
  public static inline var FROST_OUT = 0.25;
  public static inline var FROST_SZ = 1.9;
  public static inline var FROST_SZ_VAR = 1.2;
  public static inline var FROST_WALL_SZ = 2.2;
  public static inline var FROST_PROUD = 0.03;
  public static var FROST_PATCH_CELLS = [0, 2, 3, 4, 5, 6, 7];
  // not 15: that cell is an L-shaped corner crust, which stood in the open beside a box as a corner
  // of nothing
  public static var FROST_FLOOR_CELLS = [10, 11];
  public static var FROST_FRINGE_CELLS = [9, 12];
  // the frost's own faint cold light off its map, so it reads in a dark room the way rime catches
  // whatever light there is
  public static inline var FROST_GLOW = 0x3a4a5c;
  // and its strength over the floor (blended, so overlapping patches never z-fight)
  public static inline var FROST_ALPHA = 0.5;
  public static inline var FROST_CUT = 0.02;
  public static inline var TOP_SZ = 0.75;
  public static inline var TOP_SZ_VAR = 0.3;
  public static inline var TOP_LIFT = 0.008;
  public static inline var DECAL_TRIES = 8;
  // a bench lid's standing kit (LabInterior.kit): how far in from the lid's back and end, the chance
  // in a hundred of a second piece, and the turn step its hashed -4..4 jitter takes
  public static inline var TOP_MARGIN = 0.15;
  public static inline var TOP_PAIR = 45;
  // the shelving's stock (render.lab.LabInterior.stock): a bay's width, the stocked plates' top
  // surfaces on the tall units and the low bookcase, their top boards, the chance in a hundred a
  // bay-face stands empty, the gap between two pieces, how far in from the plate's edge a front
  // stands, the most flat things on a top board, and the chance in a hundred one piece stands there
  public static inline var SHELF_BAY = 1.8;
  public static var SHELF_PLATES = [0.3, 1.35, 2.4, 3.45];
  public static var LOW_PLATES = [0.25, 1.4];
  public static inline var SHELF_TOP = 4.5;
  public static inline var LOW_TOP = 2.6;
  public static inline var STOCK_GAP = 15;
  public static inline var STOCK_SPACE = 0.06;
  public static inline var STOCK_INSET = 0.08;
  public static inline var STOCK_LID_COUNT = 3;
  public static inline var STOCK_TOP = 55;
  // the most flat things a bench top carries (render.lab.LabDecals deals that or up to two fewer)
  public static inline var TOP_COUNT = 4;
  // a workbench's lower shelf: its board's top, the clear lid between the legs, the most flat things
  // it carries, the chance in a hundred of a standing piece, and the headroom that piece must clear
  public static inline var UNDER_Y = 0.53;
  public static inline var UNDER_W = 3.4;
  public static inline var UNDER_D = 2.0;
  public static inline var UNDER_COUNT = 2;
  public static inline var UNDER_KIT = 40;
  public static inline var UNDER_HEAD = 1.1;
  public static inline var TOP_JITTER = 0.08;
  // the floor machines that stand askew, pushed about rather than set square, and the most they turn
  // off square either way (radians; never under 0.4 of it): a gurney's 5.42 x 2.32 at 0.2 still fits
  // its 8 x 4 footprint
  public static var MACHINE_JITTER = [
    'gurney' => 0.2,
    'gurneys' => 0.2,
  ];
  // a bench-top glass shell's look (LabInterior.glass): a faint tint that writes no depth, the vat
  // glass's own recipe at a stronger opacity, since a jar is far smaller than a vat
  public static inline var TOP_GLASS_OPACITY = 0.3;
  // a bench-top status light (LabInterior.leds): its world size, and how far proud of its face
  public static inline var TOP_LED_SZ = 0.035;
  public static inline var TOP_LED_EPS = 0.004;
  // a status light's size per unit of its piece's height, over TOP_LED_SZ: ~0.13 on a 4.5 machine
  // (a soft dot, so its core reads at half that)
  public static inline var LED_PER_H = 0.03;
  // the machines' painted lamps blinking (render.lab.LabBlink): the two rates in blinks per BASE_MS
  // (a slow ~2 s pulse and a busy ~0.6 s one), how far a lamp drops when off, and how much brighter
  // than its paint a lamp burns
  public static inline var BLINK_SLOW = 0.075;
  public static inline var BLINK_FAST = 0.25;
  public static inline var BLINK_DEPTH = 0.85;
  public static inline var BLINK_GAIN = 2.5;
  // a bunsen burner's gas flame (LabFlames): its rest height and width, the glow under it, their
  // peak additive opacities, and the two blues — the outer layer's and the hot inner cone's
  public static inline var FLAME_H = 0.34;
  public static inline var FLAME_W = 0.13;
  public static inline var FLAME_GLOW_W = 0.42;
  public static inline var FLAME_A = 0.7;
  public static inline var FLAME_GLOW_A = 0.28;
  public static inline var FLAME_TIP = 0x2c5cff;
  public static inline var FLAME_HOT = 0xa8dcff;
  public static inline var DECAL_CUT = 0.5;
  // the slurry a drained vat leaves (render.lab.LabVats, lab/floor-marks cell 8): how wide it has
  // spread once the vat is empty, how far in front of the footprint's centre it pools — out past the
  // plinth's front edge (6 units), which covers the whole 2x3 and hid a spill centred under it — and
  // its height over the floor (over the grime)
  public static inline var SPILL_SZ = 7.0;
  public static inline var SPILL_OUT = 7.0;
  public static inline var SPILL_Y = 0.03;

  // ---- the lamps (render.lab.LabLamps): a room fixture's lattice pitch and the corridor's spacing, in
  // cells; the bulb height (just under the 6.0 wall head); its strength on the pooled spotlight; the
  // odds, in percent of fixtures, of a dead bulb and of a sputtering one; and the 2D lab's room tints
  public static inline var LAMP_SPACING = 5;
  public static inline var LAMP_Y = 5.6;
  public static inline var LAMP_MUL = 1.1;
  // how far a fixture may sit off its cell centre, and how much weaker than LAMP_MUL it may burn, by
  // the cell hash: a lattice of identical pools read as polka dots
  public static inline var LAMP_JITTER = 1.4;
  public static inline var LAMP_MUL_VAR = 0.35;
  public static inline var LAMP_DEAD_PCT = 8;
  public static inline var LAMP_SPUTTER_PCT = 10;
  public static inline var LAMP_ENTRANCE = 0x5fd8ee;
  public static inline var LAMP_VAT = 0x6dff8c;
  public static inline var LAMP_WORKSHOP = 0xffb054;
  public static inline var LAMP_STORAGE = 0xff5e4a;
  public static inline var LAMP_RESEARCH = 0x6f8cff;
  public static inline var LAMP_CORRIDOR = 0xd4e2ff;
  // the alarm: its red, its period in BASE_MS, and how low the strobe swells down to
  public static inline var LAMP_ALARM = 0xff2a1a;
  public static inline var ALARM_MULT = 2.0;
  public static inline var ALARM_LO = 0.25;
  // the lab's death: how long it takes in BASE_MS, what the rooms outside the vat chamber dim to, and
  // the sputter phase every bulb takes while it goes (offset per post so they do not stutter as one)
  public static inline var DEAD_MULT = 4.0;
  public static inline var DEAD_DIM = 0.4;
  public static inline var DEAD_PHASE = 3.1;
  // and how much of the machines' screen and window glow goes with it (render.lab.LabInterior.dim)
  public static inline var DEAD_EMISSIVE = 0.85;

  // ---- the walls' signs, fittings, screens and lamps (render.lab.LabWall)
  public static inline var WALL_SIGNS_TEX = 'textures/lab/wall-signs.png';
  // the signs' art drawn at this of its albedo: their white and red grounds read as lit in the dark
  // rooms
  public static inline var WALL_SIGN_TINT = 0.5;
  public static inline var WALL_FITTINGS_TEX = 'textures/lab/wall-fittings.png';
  public static inline var WALL_SCREENS_TEX = 'textures/lab/wall-screens.png';
  // the shortest stretch of plain masonry that takes anything, and one sign per this many cells of it
  public static inline var WALL_RUN_MIN = 2;
  public static inline var WALL_SIGN_SPACING = 6;
  // the sign plate's side and its centre's height: clear of the 4.4-5.4 machines only where nothing
  // stands in front, which LabWall checks, and under the 6.0 wall head
  public static inline var WALL_SIGN_W = 1.5;
  public static inline var WALL_SIGN_Y = 4.6;
  // a fitting's drawn HEIGHT, by sheet cell (LabWall.FIT_BOX crops each to its own art, so its width
  // follows the art's aspect): one cell side for all of them drew a keypad as big as a notice board and
  // everything small and squashed into its square. Its centre's height, over the borrowed
  // electrical's 1.7 m panels, and the share of runs that take one
  public static var WALL_FIT_H = [1.6, 1.5, 1.3, 1.2, 1.4, 1.4, 1.3, 1.9, 1.6, 1.6, 1.4, 1.9, 1.8, 1.3,
    2.4, 2.8];
  public static inline var WALL_FIT_Y = 2.9;
  public static inline var WALL_FIT_PCT = 70;
  // a monitor's longest edge, its centre's height, and the share of vat and research runs with one
  public static inline var WALL_SCREEN_W = 1.5;
  public static inline var WALL_SCREEN_Y = 3.4;
  public static inline var WALL_SCREEN_PCT = 60;
  // a strip lamp's length, a caged lamp's side, their height and the share of runs with one
  public static inline var WALL_LAMP_W = 2.0;
  public static inline var WALL_CAGE_W = 0.8;
  public static inline var WALL_LAMP_Y = 5.4;
  public static inline var WALL_LAMP_PCT = 45;
  // off the slab's face, and the screens' and lamps' glow over their own map (dimmed by the death)
  public static inline var WALL_PROUD = 0.1;
  public static inline var WALL_GLOW = 1.4;

  // ---- the rig. no moon and no sky: the bedrock is the ceiling, so the background and the fog are
  // one near-black (render.world.VisionMask fades unseen cells TO this, so they must match)
  public static inline var DARK = 0x040608;
  // fog closes in well past the camera's own reach (CAMERA_FACILITY, up to ~51 units off), so the
  // room the player stands in is never fogged and the far end of the corridor is
  public static inline var FOG_NEAR = 64.0;
  public static inline var FOG_FAR = 150.0;
  // the fill. cold and low — the lamps are what light this place. The tunnels' colours; at 2.4
  // a room was black between its pools at the gameplay camera (swept live 2.4 / 3.6 / 5.5 / 9, and 9
  // flattened the pools into the fill)
  public static inline var AMBIENT = 0x3a4657;
  public static inline var AMBIENT_I = 5.5;
  public static inline var HEMI_SKY = 0x46536e;
  public static inline var HEMI_GROUND = 0x141a22;
  public static inline var HEMI_I = 1.8;

// the lab's ShellOpts: how render.lab.LabModel reads the saved grid, and what the shell is dressed in
  public static function shell():ShellOpts
    {
      var floor = [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.LINO] = FLOOR_CORRIDOR;
      floor[Surf.LAB_ENTRANCE] = FLOOR_ENTRANCE;
      floor[Surf.LAB_VAT] = FLOOR_VAT;
      floor[Surf.LAB_WORKSHOP] = FLOOR_WORKSHOP;
      floor[Surf.LAB_STORAGE] = FLOOR_STORAGE;
      floor[Surf.LAB_RESEARCH] = FLOOR_RESEARCH;
      floor[Surf.LAB_PAD] = FLOOR_PAD;
      // the vat hall's drain channels and the store's painted squares are a grid: two cells a tile,
      // so their lines land on the cell edges (the shell's x and z are -200 + 4k)
      var tile = [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : Float)];
      tile[Surf.LAB_VAT] = FLOOR_GRID_SZ;
      tile[Surf.LAB_STORAGE] = FLOOR_GRID_SZ;
      var into = [for (_ in 0...FacilityStyle.SURF_SLOTS) WALL_CORRIDOR];
      into[Surf.LAB_ENTRANCE] = WALL_ENTRANCE;
      into[Surf.LIFT] = WALL_ENTRANCE;
      into[Surf.LAB_VAT] = WALL_VAT;
      into[Surf.LAB_PAD] = WALL_VAT;
      into[Surf.LAB_WORKSHOP] = WALL_WORKSHOP;
      into[Surf.LAB_STORAGE] = WALL_STORAGE;
      into[Surf.LAB_RESEARCH] = WALL_RESEARCH;
      return {
        kind: 'lab',
        tex: {
          floor: floor,
          wallOut: ROCK,
          wallInto: into,
          // the lab has no windows and no light wells, so nothing draws these; filled with real lab
          // art so a stray pane could never fall back to another kind's
          pane: WALL_CORRIDOR,
          pane2: WALL_CORRIDOR,
          aspect: 1.0,
          aspect2: 1.0,
          paneHigh: WALL_CORRIDOR,
          head: COPING,
          roof: COPING,
          coping: COPING,
          shutter: null,
          pocket: null,
          sill: null,
          // FacilityDoors never runs here (LabDoors slides its own leaves), so this is only ever
          // indexed by nothing — five so the array is the length the emitter expects
          door: [DOOR_BLAST, DOOR_SERVICE, DOOR_SERVICE, DOOR_RESEARCH, DOOR_VAT],
          circ: Surf.LINO,
          // the compound's electrical kit and cable, the one family the lab borrows whole
          // (render.facility.FacilityCable)
          cable: FacilityStyle.CABLE_TEX,
          elec: FacilityStyle.ELEC_TEX,
          elecScale: ELEC_SCALE,
          elecTint: ELEC_TINT,
          floorTile: tile,
          hood: COPING,
        },
        surfOf: LabModel.surfOf,
        wallOf: LabModel.wallOf,
        fitOf: function(t:Int) return 0,
        tableOf: function(t:Int) return false,
        // the lab's partitions are cut out of the same bedrock as its perimeter
        wallIn: FacilityStyle.WALL_T,
        hangars: false,
        hangarH: FacilityStyle.WALL_H,
        deck: false,
        parapet: false,
      };
    }
}

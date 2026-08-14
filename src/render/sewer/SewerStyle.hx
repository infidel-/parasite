package render.sewer;

// one entry of PROP_MODELS: a wall-clutter glb and the two numbers that are its own rather than the
// scatter's. a drum stands tall on a small round footprint and a cable coil is flat on a wide one,
// so a single global height/standoff pair (which is what this replaced) either floats one prop off
// the wall or buries the other in it.
//
// `r` is a RATIO, not a distance, and that is the whole point. Models.instanced scales a prop by
// HEIGHT alone (targetH / native height), so its footprint is native radius * h / native height —
// i.e. r * h. A hand-typed standoff goes stale the moment h changes, which is exactly how the cable
// ended up 0.33 world units inside the masonry: it was authored at 0.5 for a footprint of 0.83.
// SewerProps derives the standoff from r instead, so it can never disagree with the mesh again
typedef SewerProp = {
  path:String,   // RenderConfig.MODELS entry
  h:Float,       // world height Models.instanced scales the prop to
  r:Float,       // footprint radius as a MULTIPLE of h — max XZ distance from the glb's bbox centre,
                 // divided by its native height. yaw-independent, so PROP_YAW_JITTER cannot break it
  corner:Bool,   // true = only ever placed where two perpendicular walls meet. this PARTITIONS the
                 // table: a corner spot deals only from the corner props and a flat run of wall only
                 // from the rest, so BOTH sides must stay non-empty
}

// art + dimensions for the 3D sewer tunnels — the render.world.CityStyle of underground areas.
// there is only one sewer look today, so this is plain constants rather than a swappable instance
class SewerStyle
{
  // wall variations, one picked PER FACE (SewerGeom). a clean/worn PAIR was tried this way before
  // and rejected — 47% of cell boundaries changed variant and every switch was a hard seam — but
  // that pair was two independently painted tiles with DIFFERENT block layouts, so a switch moved
  // the mortar. these four are repaints of one source: the courses line up across a switch and only
  // the wear differs, which is a discontinuity in the dirt rather than in the masonry
  public static var WALLS = [
    'textures/sewer/wall.png',
    'textures/sewer/wall-2.png',
    'textures/sewer/wall-3.png',
    'textures/sewer/wall-4.png',
  ];
  public static inline var FLOOR = 'textures/sewer/floor.png';   // wet concrete walkway
  public static inline var LEDGE = 'textures/sewer/ledge.png';   // flat top of a wall, seen from the overhead camera
  public static inline var GRIME = 'textures/sewer/grime.png';   // damp base band; alpha is hand-painted into the source
  // NO sludge gutter and NO ledge pipe run. both are switched off, so their paths are not listed
  // here — the art itself is still registered in textures-src/textures.json (sewer/sludge,
  // sewer/top-pipe-1) and still builds, so reviving either is a path plus its emit

  // wall detail decals. these ARE the old wall-worn variant, broken into pieces: everything that
  // used to justify a second whole-wall texture (fractures, seepage, moss, missing blocks) now
  // lands on individual faces, where it cannot seam
  public static inline var CRACK = 'textures/sewer/crack-1.png';
  public static inline var SEEPAGE = 'textures/sewer/seepage-1.png';
  public static inline var MOSS = 'textures/sewer/moss-1.png';
  public static inline var BROKEN = 'textures/sewer/broken-1.png';

  // world units per texture repeat. UVs are worldPos / these on BOTH axes, so nothing stretches
  // and the brick keeps one scale everywhere regardless of how long a tunnel run is
  public static inline var WALL_TILE = 6.0;
  public static inline var FLOOR_TILE = 8.0;
  public static inline var LEDGE_TILE = 8.0;

  // wall height in world units (CELL is 4, an actor billboard is 3): tall enough to enclose, low
  // enough that the near-top-down sewer camera never has a wall between it and the player. at
  // actor height the walls read as a kerb the tunnel is cut into rather than as a deep shaft,
  // which is what keeps sightlines open on the steeper preset
  public static inline var WALL_H = 3.0;

  // --- damp band at the foot of every wall (render.sewer.SewerDetail) ---
  // RenderConfig.GRIME_H is 3.0, which down here is the ENTIRE wall, so the sewer needs its own
  public static inline var GRIME_H = 1.2;       // band height in world units, from the floor up
  public static inline var GRIME_TILE = 3.0;    // world units per grime repeat along the wall
  public static inline var GRIME_OPACITY = 0.7; // band strength (0 = none .. 1 = the source's own alpha)

  // --- fake contact shadow where a wall meets the floor (render.sewer.SewerDetail) ---
  // the street equivalents are RenderConfig.ROOF_SHADOW_W / ROOF_SHADOW_ALPHA under a parapet
  public static inline var SHADOW_W = 1.1;      // how far the shadow reaches out from the wall
  public static inline var SHADOW_ALPHA = 0.55; // darkness right at the wall, fading to 0 outward
  public static inline var SHADOW_Y = 0.02;     // lift off the floor so it never z-fights the walkway

  // ledge-top clutter and floor decals, both TOP-DOWN art laid flat (render.sewer.SewerGround).
  // these dress the two surfaces that actually fill the screen: measured on the habitat, wall faces
  // are 0.67% of the 3D view against the ledge tops' 14.68%, with the floor taking most of the rest
  public static inline var TOP_VALVE = 'textures/sewer/top-valve-1.png';
  public static inline var TOP_RUBBLE = 'textures/sewer/top-rubble-1.png';
  public static inline var TOP_MOSS = 'textures/sewer/top-moss-1.png';
  public static inline var FLOOR_PUDDLE = 'textures/sewer/floor-puddle-1.png';
  public static inline var FLOOR_PUDDLE_2 = 'textures/sewer/floor-puddle-2.png';
  public static inline var FLOOR_GRATE = 'textures/sewer/floor-grate-1.png';
  public static inline var FLOOR_STAIN = 'textures/sewer/floor-stain-1.png';

  // NO darkening band along the ledge rim. it was tried (a strip pass mirroring SewerDetail's floor
  // contact shadows, opaque at the drop and fading inward) and it looks wrong for a reason no tuning
  // fixes: nothing STANDS above a wall cap. a roof gets that band from its parapet; here the cap just
  // ends, so the darkening reads as a stripe floating over a BRIGHTER wall face, and its hard edge
  // lands exactly on the silhouette and shimmers. see docs/3d-changes.md
  // --- top-down clutter scattered on the two horizontal surfaces (render.sewer.SewerGround) ---
  // both rates are per CELL, unlike the wall decals' per-FACE roll, so they read much sparser than
  // the same number would on a wall: one cell shows a single 4x4 patch of ground
  public static inline var LEDGE_PCT = 22;      // % of solid cells that get a ledge-top prop
  public static inline var LEDGE_MARGIN = 0.3;  // keep a prop this far inside the cell (never overhangs the drop)
  public static inline var LEDGE_DECAL_Y = 0.03; // clear of the cap, so a prop never z-fights the ledge
  public static inline var FLOOR_PCT = 16;      // % of eligible floor cells that get a decal
  public static inline var FLOOR_MARGIN = 0.2;  // decals sit inside their own cell, never across a wall
  public static inline var FLOOR_DECAL_Y = 0.01; // UNDER the contact shadows at SHADOW_Y, so a puddle at a wall foot still darkens

  // --- wall detail decals (render.sewer.SewerDetail) ---
  // RenderConfig.WALLDECAL_PCT is 35, but that is per whole building FACE; a sewer face is a single
  // 4x3 cell, so the same rate covers the tunnel in graffiti-density clutter
  public static inline var DECAL_PCT = 18;      // % of wall faces that get a decal
  public static inline var DECAL_EPS = 0.05;    // proud of the wall face (avoid z-fight)
  public static inline var DECAL_MARGIN = 0.5;  // keep a decal this far inside the cell's edges

  // bloom threshold underground. was 0.75 (below the street's 0.9) so the few lamps would bloom
  // against near-black surroundings, but the lamps clear 0.9 on their own — their glow quads and
  // emissives run 2.6-3.2x over the amber. What lived in that 0.75-0.9 band was over-lit SURFACES:
  // a pale face straight under a bulb (the exit ladder's top rail) haloed onto the floor around it
  public static inline var BLOOM_THRESHOLD = 0.9;

  // --- overhead node/exit light shafts (render.LightCone via SewerScene) ---
  // a street shaft tapers to RenderConfig.LAMP_CONE.topR = 0.2, i.e. a point at the bulb, because it
  // IS a bulb. down here the light falls through a MANHOLE, so the shaft is already a manhole wide
  // where it starts and only spreads a little on the way down
  public static inline var CONE_TOP_R = 0.9;
  // and it is not lit like a street lamp either. this is the NIGHT SKY falling down a hole, so it is
  // cold and pale where the street's is sodium amber — which is also what tells it apart from the
  // wall fixtures at a glance. no bloom constraint: the shaft draws at LAMP_CONE.opacity 0.03, so
  // even at full luminance it lands three orders under BLOOM_THRESHOLD
  public static inline var SHAFT_COLOR = 0x9db4d4;

  // --- weak bracketed lamps on the tunnel walls (render.sewer.SewerLamps) ---
  // these are the between-junctions lighting: the node lamps only land on 3x3 corridor corners and
  // intersections, so without these a whole run of corridor has no light source of its own
  public static inline var WALL_LAMP_PCT = 12;         // % of wall faces that get a fixture
  // cells of clearance a fixture keeps from any overhead shaft (render.sewer.SewerLamps.nearShaft).
  // a bracket standing inside a manhole column is two light sources lighting one pool of floor, and
  // the weak one only muddies it. derived, not picked: the shaft's ground radius is
  // bulbY * tan(LAMP_LIGHT.angle) * LAMP_CONE.radiusMul = 3.66 world units (0.92 cells), and a
  // bracket throws its own pool WALL_LAMP_AIM = 5.0 (1.25 cells) out from the wall — so they stop
  // touching at ~2.2 cells apart. rejecting a cell also shrinks the block's `faces` count, which the
  // density gate multiplies by, so blocks near a shaft thin out on their own
  public static inline var WALL_LAMP_CLEAR = 2;
  public static inline var WALL_LAMP_BROKEN_PCT = 30;  // % of those permanently dead (housing only, no light)
  public static inline var WALL_LAMP_FLICKER_PCT = 35; // % of the SURVIVORS that sputter (failing-sodium)
  // bracket height on the wall face. DOWN at the foot of the wall, not up under the cap: a fixture at
  // head height pooled its light straight beneath itself and nothing in the tunnel cast a shadow worth
  // seeing. from here the beam rakes the walkway (see WALL_LAMP_AIM) and everything it touches throws
  // a long one. the glow quad is WALL_LAMP_H tall, so its bottom edge still clears the floor
  public static inline var WALL_LAMP_Y = 0.6;
  public static inline var WALL_LAMP_OUT = 0.6;        // how far the SPOTLIGHT stands off the wall, so its
                                                       // cone starts in open air instead of half inside masonry
  // how far out along the wall normal the spotlight AIMS (LampPost.tx/tz). the bulb is WALL_LAMP_Y
  // high and aims at the floor this far away, i.e. a ~7 degree grazing beam — which is the whole
  // point of dropping it down here. shorten this to pull the lit pool back off the opposite wall
  public static inline var WALL_LAMP_AIM = 5.0;
  public static inline var WALL_LAMP_W = 0.75;         // glow quad width in world units
  public static inline var WALL_LAMP_H = 0.5;          // glow quad height
  public static inline var WALL_LAMP_HOUSING = 2.6;    // housing/soot quad size, as a multiple of the glow
  public static inline var WALL_LAMP_MUL = 0.35;       // pooled-spotlight intensity multiplier — a weak fixture
  // fixture tint, and NOT the street's amber (RenderConfig.LAMP_CONE.color): these are bolted-on
  // tubes gone bad, not sodium street lighting, and they must read apart from the manhole shafts
  // overhead. pale olive — deliberately clear of the flame/ember/alert warm band, of the saturated
  // UI greens (OBJMARK 0x35dd7a, path/slime 0x7ddc46, acid 0x58ff3c) and of the cool UI blues.
  // CHECK THE BLOOM MATH BEFORE CHANGING IT: the glow quad is this * WALL_LAMP_GLOW, unclamped, and
  // UnrealBloomPass thresholds LINEAR Rec.709 luminance where blue weighs only 0.0722 — a cool hue
  // can look bright and silently stop blooming. this one is Y_linear 0.627, so 0.627 * 2.6 = 1.63
  // against BLOOM_THRESHOLD 0.9 (the amber it replaced was 1.47)
  public static inline var WALL_LAMP_COLOR = 0xc8d69a;
  public static inline var WALL_LAMP_GLOW = 2.6;       // HDR multiplier on WALL_LAMP_COLOR so the quad clears BLOOM_THRESHOLD
  public static inline var WALL_LAMP_SOOT = 0.18;      // housing darkness (opacity of the black smudge behind the glow)

  // --- the exit ladder prop (RenderConfig.MODELS.sewerExit via render.world.ObjModels) ---
  // taller than WALL_H so it visibly climbs PAST the ledge toward the hole we do not render
  public static inline var EXIT_MODEL_H = 4.0;
  // the exit's light steps SOUTH (+Z, screen-DOWN under CAMERA_SEWER) off the ladder's own cell, so
  // the prop is not standing in the middle of its own shaft and the lit pool lands on the walkway in
  // FRONT of it. the SpotLight moves with the cone — a shaft whose lit floor pool sat somewhere else
  // would read as two different lights. the lamp's col/row stay the exit cell: that is what
  // LampLights gates player distance on
  public static inline var EXIT_LAMP_SOUTH = 2.0;

  // --- 3D clutter scattered against the walls (render.sewer.SewerProps) ---
  // the first CONVEX geometry down here. the shell is a concave box and everything dressing it is
  // flat, so until these a wall bracket's raking beam had nothing to throw a shadow off.
  // one entry = one glb = one draw call for however many the level places
  // r is measured off the baked glb, NOT guessed — max XZ radius from the bbox centre over native
  // height. re-measure it whenever a source model is regenerated
  public static var PROP_MODELS:Array<SewerProp> = [
    // the two CORNER props: a big upright drum or a crate stack standing against a flat run of wall
    // reads as dropped in the walkway, while tucked into the angle of two walls it reads as stored
    // there. corners are ~14% of spots and these two share them, so expect 1-2 of each per level
    { path: render.RenderConfig.MODELS.sewerDrum, h: 1.8, r: 0.34, corner: true },
    { path: render.RenderConfig.MODELS.sewerCrates, h: 1.65, r: 0.52, corner: true },
    { path: render.RenderConfig.MODELS.sewerCable, h: 0.24, r: 2.77, corner: false },
    // h 1.0 rather than the 0.7 the flat-wide first generation wanted: the charcoal-reference regen
    // came back a proper pyramid (aspect 1.23 against 1.98), so the old height shrank its footprint
    // from 1.38 world units across to 0.86 and it read as a pebble
    { path: render.RenderConfig.MODELS.sewerBags, h: 1.0, r: 0.73, corner: false },
    // the three the old sewer-pile-1 heap was split into. heights read off the drum as a ruler — it
    // ships at h 1.8 for a real 0.88m 200L drum, so one world unit is ~0.49m and these are a 0.34m
    // block, a 0.22m-tall heap 0.75m across, and a 0.39m-bore pipe 0.72m long.
    // the block is the smallest prop down here by design (it is what the "single brick" idea became
    // once a real brick measured 0.44 world units, under the 2D litter's own 0.46 floor) — but 0.55
    // made it a speck beside the others on screen, the same mistake bags started with
    { path: render.RenderConfig.MODELS.sewerBlock, h: 0.7, r: 0.80, corner: false },
    { path: render.RenderConfig.MODELS.sewerBricks, h: 0.45, r: 2.06, corner: false },
    { path: render.RenderConfig.MODELS.sewerPipe, h: 0.8, r: 1.02, corner: false },
  ];
  // breathing room between the prop's footprint circle and the wall plane, on top of r * h. small
  // on purpose: these are meant to look dumped against the wall, not parked a pace off it
  public static inline var PROP_CLEAR = 0.05;
  // one prop per 2x2 block, gated per eligible wall FACE exactly as WALL_LAMP_PCT is. was 14 while
  // all four wall directions were eligible; SewerProps now rejects the camera-side one, which takes
  // roughly a quarter of the faces out of the gate, so this is scaled up to hold the same density
  public static inline var PROP_PCT = 18;
  // +/- yaw wobble (radians) around the face's outward facing, so two props on parallel walls are
  // not the same silhouette twice
  public static inline var PROP_YAW_JITTER = 0.5;

  // --- ground litter (render.sewer.SewerDebris), per 1000 floor cells ---
  // rooms stay tidier than the tunnels as the old 2D pass had it, but only just: a habitat is pinned
  // to 4-5 rooms of 5x5, so 62-77% of its floor IS room and the low rate was the one underfoot. these
  // were 20/8, then 60/24 — a whole habitat level came to ~9-11 fragments, which reads as swept
  public static inline var DEBRIS_PCT_TUNNEL = 180;
  public static inline var DEBRIS_PCT_ROOM = 120;
  // smallest fragment scale the tunnels will keep. render.world.Debris rolls 0.1 + 0.9 * rng for a
  // cluster fragment, and the drawn size is Sprites.SIZE (3.0) * contentFraction * scale — so a 0.1
  // roll on a half-content sprite draws 0.15 world units against a CELL of 4, i.e. a pixel. measured
  // in the habitat before this: 0.15 / 0.73 / 0.86 / 0.88 / 1.21
  public static inline var DEBRIS_MIN_SCALE = 0.5;
  // sub-cell jitter for a STATIC fragment, which render.world.Debris leaves dead-centre and unrotated
  // (only transformable ones get an offset). stays inside Debris.canPlace's free band, so a fragment
  // can never end up over a wall and no ground test is needed
  public static inline var DEBRIS_JITTER = 0.25;
}

package render;

typedef DetailType = { tex:String, w:Float, d:Float, crop:Float };
typedef CropXY = { x:Float, y:Float };

// rendering constants (texture tiling, parapet, windows, bloom, camera); grid and
// floor constants plus cellToWorld live in citygen.CityConfig (shared, pure)
class RenderConfig {
  // --- texture tiling knobs (UV = worldPos / *_TILE → no stretch, continuous flow) ---
  public static inline var ROAD_TILE = 16;     // world units per asphalt repeat on roads
  public static inline var WALKWAY_TILE = 8;   // world units per sidewalk-paving repeat
  public static inline var ALLEY_TILE = 10;    // world units per alley-grime repeat
  public static inline var CURB_H = 0.2;       // walkway raised this far above road/alley (curb step)
  public static inline var WALKWAY_BORDER_W = 0.2;   // kerb-edging lip width, protruding onto the road/alley at each open (curbed) edge
  public static inline var WALKWAY_BORDER_TILE = 4;  // world units per kerb-edging repeat (along the run)
  // --- road markings (painted overlay mesh over roads; pattern = geometry, fill = worn-paint tex) ---
  public static inline var PAINT_Y = 0.03;     // marks float this far above road (y=0) — no z-fight
  public static inline var PAINT_TILE = 4;     // world units per worn-paint wear repeat (along the mark)
  public static inline var LINE_W = 0.18;      // painted line thickness
  public static inline var DASH_LEN = 2.0;     // dashed line: painted run
  public static inline var DASH_GAP = 2.0;     // dashed line: gap (DASH_LEN+DASH_GAP = one CELL)
  public static inline var DOUBLE_GAP = 0.7;   // centre-to-centre offset of the two lines in a double line
  public static inline var ZEBRA_DEPTH = 2.4;  // crosswalk band depth (along the road), at the mouth
  public static inline var ZEBRA_BAR = 0.68;   // target zebra strip width (paint=gap); bars fit equally with an edge inset
  public static inline var STOP_W = 0.5;       // stop-line bar thickness
  public static inline var STOP_GAP = 0.6;     // gap between the zebra and the stop line
  public static inline var WALL_TILE = 12;     // world units per windowless-wall texture tile (brick/concrete scale)
  // --- near-ground grime band (street-level base overlay; B+C: alpha-ramp gradient darken + grime/scuff art) ---
  public static inline var GRIME_H = 3.0;      // band world height (bottom at ground, fades up); raise = taller band
  public static inline var GRIME_TILE = 3.0;   // world units per grime repeat horizontally; smaller = finer/denser detail
  public static inline var GRIME_OPACITY = 0.6; // overall grime strength (0 = none .. 1 = full texture alpha)
  public static inline var ROOF_TILE = 16;     // world units per roof-base tile (tiled, not stretched)
  public static inline var GABLE_V = 0.5;      // metal gable-end V anchor: sample a clean mid-texture band so the worn-metal dirty base strip never lands on the high gable triangle

  // --- building fronts: stores vs plain entrances (deterministic per footprint, no rng) ----
  public static inline var STORE_PCT = 30;          // % of normal simple buildings that keep a storefront band (rest = plain entrance + windows)
  public static inline var BACK_ENTRANCE_WORN_PCT = 40;  // each worn wall independently gets a side/maintenance door
  public static inline var BACK_ENTRANCE_CLEAN_PCT = 8;  // rare side door on a clean non-street wall
  public static inline var DOOR_SIZE = 3.9;         // door quad side (world); SQUARE to match the square door texture (no stretch); capped to face/wall
  public static inline var DOOR_EDGE_CLEAR = 1.2;   // side doors keep this much clear of any corner / T-junction (end of the open wall run)
  public static inline var DOOR_MIN = 1.6;          // smallest side door worth placing; a narrower open run gets no side door
  public static inline var DOOR_PATH_MAX_DEPTH = 5;  // a windowed wall with a clear straight path (≤ this many non-building tiles) to a road earns an extra door, even off the street

  // --- front-door entrance covers (thin per-facade lintel/canopy over each FRONT door) ----
  public static inline var COVER_WIDTH_FRAC = 0.7; // cover width = this fraction of the door quad side (~ door-panel width, not wall-wide)
  public static inline var COVER_DEPTH = 0.8;  // how far it juts OUT from the wall (door sits 0.06 proud; cover overhangs it)
  public static inline var COVER_EMBED = 0.1;  // sink the back/bottom into wall+door so there is no seam/gap
  public static inline var COVER_Y_FRAC = 0.8; // cover BOTTOM sits at this fraction of the door quad height — just above the visible door, small gap
  // per-facade cover geometry: brick = thin flat metal awning, stone = inset slope, concrete = half-barrel
  public static inline var COVER_METAL_H  = 0.07; // brick: thin painted-metal awning slab (metal reads thin)
  public static inline var COVER_SLOPE_RISE = 0.5; // stone: eave→ridge rise (inset so only the front slope shows)
  public static inline var COVER_BARREL_R = 0.5;  // concrete: half-barrel radius (protrusion + vertical half-height)
  public static inline var COVER_ARC_SEG  = 12;   // concrete barrel: radial segments (curve smoothness)
  public static inline var COVER_MAT_TILE   = 2.5; // world units per material-swatch tile on covers (no stretch)

  // --- roof parapet + details -----------------------------------------------
  public static inline var PARAPET_H = 0.7;        // raised rim height (concrete buildings, world units)
  public static inline var PARAPET_H_BRICK = 1.0;  // brick wall continues up this far above the roofline (then a coping cap)
  public static inline var PARAPET_T = 0.5;        // rim thickness
  public static inline var PARAPET_EMBED = 0.6;    // sink rim into the roof so no coplanar face (no z-fight)
  public static inline var ROOF_SHADOW_W = 4.0;    // fake contact-shadow band width inside the parapet
  public static inline var ROOF_SHADOW_ALPHA = 0.7; // max darkness of that band (at the parapet edge)
  public static inline var DETAIL_BOX_COLOR = 0x5a5d63; // gray bg of the detail sprites (chroma-keyed out)
  public static inline var ROOF_DETAIL_MARGIN = 1.6; // keep details this far from roof edges
  public static inline var ROOF_SECTOR = 6;        // roof split into ~this-size sectors; one detail centered per sector (symmetry)
  public static inline var DETAIL_MAX = 9;         // cap details per roof
  // w×d = footprint world size; crop = sprite crop fraction (object + small margin)
  public static final DETAIL_TYPES:Array<DetailType> = [
    { tex: 'textures/detail-ac.png',     w: 3.0, d: 3.0, crop: 0.74 },
    { tex: 'textures/detail-aclong.png', w: 4.8, d: 2.6, crop: 0.80 },
    { tex: 'textures/detail-vent.png',   w: 2.6, d: 2.6, crop: 0.66 },
    { tex: 'textures/detail-duct.png',   w: 4.0, d: 4.0, crop: 0.90 },
    { tex: 'textures/detail-sky.png',    w: 3.4, d: 3.4, crop: 0.82 },
    { tex: 'textures/detail-tank.png',   w: 3.2, d: 3.2, crop: 0.80 },
  ];

  // --- windows (instanced quads placed on plain walls) ----------------------
  // crop fraction of each cell that is just the window+frame, per facade variant
  // (concrete = square, brick = tall); used to cut an opaque window sprite
  public static final WINDOW_SPRITE_CROP:Array<CropXY> = [{ x: 0.42, y: 0.42 }, { x: 0.30, y: 0.52 }, { x: 0.46, y: 0.82 }, { x: 0.42, y: 0.42 }];
  // facade variant names by Building.facade index (inspector tags + per-variant logic)
  public static final FACADE_NAMES = ['concrete', 'brick', 'stone', 'metal'];
  public static inline var WIN_W = 1.6;        // window world width (height derived from sprite aspect)
  public static inline var WIN_PITCH_X = 2.6;  // horizontal center-to-center spacing (vertical = FLOOR_H)
  public static inline var WIN_MARGIN = 0.9;   // min plain-wall border at face edges

  // --- lit windows + bloom --------------------------------------------------
  public static inline var LIT_RATIO = 0.15;       // fraction of windows that are lit (warm glass)
  public static inline var WINDOW_LIT_COLOR = 0xffcf8f; // warm glow color for lit windows
  public static inline var WINDOW_LIT_INTENSITY = 2.2;  // emissive intensity (HDR > 1 so bloom picks it up)
  public static inline var BLOOM_STRENGTH = 0.25;  // overall bloom amount
  public static inline var BLOOM_RADIUS = 0.1;     // bloom spread radius
  public static inline var BLOOM_THRESHOLD = 0.9;  // luminance above which pixels bloom

  // camera: ~20deg tilt from vertical, trailing slightly to +Z (south)
  public static final CAMERA = { offset: { x: 0.0, y: 60.0, z: 22.0 }, fov: 45.0, follow: 0.9 }; // tan(20deg) ≈ 0.36 → 22/60; follow = per-frame lerp (higher = tighter)
  public static inline var MOVE_MS = 150;          // per-cell slide duration

  // texture paths, grouped by role; arrays indexed by facade variant [concrete, brick]
  public static final TEXTURES = {
    asphalt: 'textures/ground-asphalt.png',     // road surface (no markings yet)
    walkway: 'textures/ground-walkway.png',     // sidewalk / plaza paving
    walkwayBorder: 'textures/ground-walkway-border.png', // kerb-edging stripe on walkway outer edges
    roadPaint: 'textures/ground-road-paint.png', // worn white traffic paint (scuffs chroma-keyed to alpha)
    alley: 'textures/ground-alley.png',         // grimy back-alley ground
    roofBases: ['textures/roof-base-concrete.png', 'textures/roof-base.png', 'textures/roof-base.png', 'textures/roof-base.png'], // roof base by facade variant [concrete, brick, stone, metal]; stone+metal reuse tar

    coping: 'textures/coping.png',              // parapet coping cap strip
    shopWorn: 'textures/shop-wall-worn.png',    // single-story shop box wall (own worn texture)
    shopCoping: 'textures/shop-coping.png',     // single-story shop parapet coping cap
    storefronts: ['textures/facade-concrete.png', 'textures/facade-brick.png', 'textures/facade-stone.png', 'textures/facade-metal.png'], // ground-floor storefront bay [concrete, brick, stone, metal]
    // single-story shop storefronts: baked 16:9 (1280x720) from 2K sources via textures.json
    // (non-square res). Indexed by Building.shop (0..3): diner, corner, garage, laundromat.
    // door variant + door-less continuation, each in lit (open) / unlit (closed).
    shopFrontLit:   ['textures/shop-diner-front-lit.png', 'textures/shop-corner-front-lit.png', 'textures/shop-garage-front-lit.png', 'textures/shop-laundromat-front-lit.png'],
    shopFront:      ['textures/shop-diner-front.png', 'textures/shop-corner-front.png', 'textures/shop-garage-front.png', 'textures/shop-laundromat-front.png'],
    shopFrontNdLit: ['textures/shop-diner-front-nd-lit.png', 'textures/shop-corner-front-nd-lit.png', 'textures/shop-garage-front-nd-lit.png', 'textures/shop-laundromat-front-nd-lit.png'],
    shopFrontNd:    ['textures/shop-diner-front-nd.png', 'textures/shop-corner-front-nd.png', 'textures/shop-garage-front-nd.png', 'textures/shop-laundromat-front-nd.png'],
    // window sprites by facade [concrete, brick, stone, metal]; stone has its own pale-stone
    // sprite (window-3), metal reuses square (concrete, unused — metal has no windows)
    windows: ['textures/window-1.png', 'textures/window-2.png', 'textures/window-3.png', 'textures/window-1.png'],         // dark window sprites
    litWindows: ['textures/window-lit-1.png', 'textures/window-lit-2.png', 'textures/window-lit-3.png', 'textures/window-lit-1.png'], // warm-lit window sprites
    walls: ['textures/wall-1.png', 'textures/wall-2.png', 'textures/wall-3.png', 'textures/wall-4.png'],               // street-facing clean walls [concrete, brick, stone, metal]
    wornWalls: ['textures/wall-1-worn.png', 'textures/wall-2-worn.png', 'textures/wall-3-worn.png', 'textures/wall-4-worn.png'], // alley-facing back walls
    // metal warehouses pick one of these corrugated-steel variants per-building (ridged rust-red,
    // galvanized grey-blue, olive box-profile, plus the base wall-4); clean/worn paired by index
    metalWalls: ['textures/wall-4.png', 'textures/wall-5.png', 'textures/wall-6.png', 'textures/wall-7.png'],
    metalWorn: ['textures/wall-4-worn.png', 'textures/wall-5-worn.png', 'textures/wall-6-worn.png', 'textures/wall-7-worn.png'],
    // street-level grime variants (alpha ramp applied in code); picked per-building, overlaid on each
    // non-metal street face base. soot/drip, scuff, damp-stain — neutral dark, read over any wall
    grime: ['textures/grime-1.png', 'textures/grime-2.png', 'textures/grime-3.png'],
    doorMetal: 'textures/door-metal.png',       // closed roll-up warehouse door (metal facade street faces)
    // pedestrian entrance doors per masonry facade [concrete, brick, stone]; clean = front/street
    // (edited from wall-N), worn = side/maintenance door (edited from wall-N-worn). picked by isWornFace
    doors: ['textures/door-concrete.png', 'textures/door-brick.png', 'textures/door-stone.png'],
    doorsWorn: ['textures/door-concrete-worn.png', 'textures/door-brick-worn.png', 'textures/door-stone-worn.png'],
    // per-facade entrance-cover lintel/cornice band [concrete, brick, stone] (over FRONT doors)
    doorCovers: ['textures/door-cover-concrete.png', 'textures/door-cover-brick.png', 'textures/door-cover-stone.png'],
    roofMetal: 'textures/roof-metal.png',       // metal warehouse gable-roof slopes (distinct from the wall)
    player: 'textures/player.png',              // player billboard sprite
  };
}

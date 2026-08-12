package render.sewer;

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

  // --- weak bracketed lamps on the tunnel walls (render.sewer.SewerLamps) ---
  // these are the between-junctions lighting: the node lamps only land on 3x3 corridor corners and
  // intersections, so without these a whole run of corridor has no light source of its own
  public static inline var WALL_LAMP_PCT = 12;         // % of wall faces that get a fixture
  public static inline var WALL_LAMP_BROKEN_PCT = 30;  // % of those permanently dead (housing only, no light)
  public static inline var WALL_LAMP_FLICKER_PCT = 35; // % of the SURVIVORS that sputter (failing-sodium)
  public static inline var WALL_LAMP_Y = 2.2;          // bracket height on the wall face (under WALL_H)
  public static inline var WALL_LAMP_OUT = 0.6;        // how far the SPOTLIGHT stands off the wall, so its
                                                       // downward cone lands on floor instead of half inside masonry
  public static inline var WALL_LAMP_W = 0.75;         // glow quad width in world units
  public static inline var WALL_LAMP_H = 0.5;          // glow quad height
  public static inline var WALL_LAMP_HOUSING = 2.6;    // housing/soot quad size, as a multiple of the glow
  public static inline var WALL_LAMP_MUL = 0.35;       // pooled-spotlight intensity multiplier — a weak fixture
  public static inline var WALL_LAMP_GLOW = 2.6;       // HDR multiplier on LAMP_CONE.color so the quad clears BLOOM_THRESHOLD
  public static inline var WALL_LAMP_SOOT = 0.18;      // housing darkness (opacity of the black smudge behind the glow)

  // --- the exit ladder prop (RenderConfig.MODELS.sewerExit via render.world.ObjModels) ---
  // taller than WALL_H so it visibly climbs PAST the ledge toward the hole we do not render
  public static inline var EXIT_MODEL_H = 4.0;
}

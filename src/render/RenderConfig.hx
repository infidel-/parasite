package render;

typedef DetailType = { tex:String, w:Float, d:Float, crop:Float };
typedef CropXY = { x:Float, y:Float };
// one camera distance preset: the offsets a CameraRig lerps between at zoom 0 and zoom 1.
// only the distance differs per area kind — fov, easing and the orbit clamps stay shared
typedef CamOffset = { x:Float, y:Float, z:Float };
typedef CameraOffsets = { near:CamOffset, far:CamOffset };
// one SHOT.kinds entry: per-weapon pellet pattern + tracer style (see the kinds block)
typedef ShotKind = {
  pellets:Int,
  spread:Float,
  stagger:Float,
  range:Int,
  color:Int,
  width:Float,
  waveAmp:Float,
  waveLen:Float,
  travelMult:Float,
  bullet:Bool,
};

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
  public static inline var GABLE_OVER = 0.5;   // gable eave/rake overhang past the box on ALL four sides, world units (CELL = 4). 0 = the old flush roof
  public static inline var GABLE_THICK = 0.05; // gable slab thickness, measured VERTICALLY — what turns each slope from a bare polygon into a slab with a visible fascia/rake edge

  // --- building fronts: stores vs plain entrances (deterministic per footprint, no rng) ----
  public static inline var STORE_PCT = 30;          // % of normal simple buildings that keep a storefront band (rest = plain entrance + windows)
  public static inline var BACK_ENTRANCE_WORN_PCT = 40;  // each worn wall independently gets a side/maintenance door
  public static inline var BACK_ENTRANCE_CLEAN_PCT = 8;  // rare side door on a clean non-street wall
  public static inline var DOOR_SIZE = 3.9;         // door quad side (world); SQUARE to match the square door texture (no stretch); capped to face/wall
  public static inline var DOOR_EDGE_CLEAR = 1.2;   // side doors keep this much clear of any corner / T-junction (end of the open wall run)
  public static inline var DOOR_MIN = 1.6;          // smallest side door worth placing; a narrower open run gets no side door
  public static inline var DOOR_PATH_MAX_DEPTH = 5;  // a windowed wall with a clear straight path (≤ this many non-building tiles) to a road earns an extra door, even off the street

  // --- front-door entrance covers (thin per-facade lintel/canopy over each FRONT door) ----
  // DEFAULTS ONLY. a style can override them per facade slot via AreaStyle.coverDims (see
  // DowntownStyle) — these values are what a slot gets when it says nothing. COVER_EMBED and
  // COVER_ARC_SEG stay global (not per-facade)
  public static inline var COVER_WIDTH_FRAC = 0.7; // cover width = this fraction of the door quad side (~ door-panel width, not wall-wide)
  public static inline var COVER_DEPTH = 0.8;  // how far it juts OUT from the wall (door sits 0.06 proud; cover overhangs it)
  public static inline var COVER_EMBED = 0.1;  // sink the back/bottom into wall+door so there is no seam/gap
  public static inline var COVER_Y_FRAC = 0.9; // cover BOTTOM sits at this fraction of the door quad height — just above the visible door, small gap
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
    { tex: 'textures/decals/detail-ac.png',     w: 3.0, d: 3.0, crop: 0.74 },
    { tex: 'textures/decals/detail-aclong.png', w: 4.8, d: 2.6, crop: 0.80 },
    { tex: 'textures/decals/detail-vent.png',   w: 2.6, d: 2.6, crop: 0.66 },
    { tex: 'textures/decals/detail-duct.png',   w: 4.0, d: 4.0, crop: 0.90 },
    { tex: 'textures/decals/detail-sky.png',    w: 3.4, d: 3.4, crop: 0.82 },
    { tex: 'textures/decals/detail-tank.png',   w: 3.2, d: 3.2, crop: 0.80 },
  ];
  // helicopter pad: a big centred deck marking that takes over a tall tower's roof (the style
  // supplies the texture + the odds — AreaStyle.helipadTex/helipadChance; FlatRoofs.helipadRect)
  public static inline var HELIPAD_SIZE = 16.0;      // max pad side (shrinks to fit inside ROOF_DETAIL_MARGIN)
  public static inline var HELIPAD_MIN_FLOORS = 12;  // only towers at least this tall get one
  public static inline var HELIPAD_MIN_CELLS = 4;    // ...and at least this many cells on the short side (a setback tower's top tier is usually 4-5 cells)

  // --- windows (instanced quads placed on plain walls) ----------------------
  // the per-facade crop/glow knobs are per-AREA, not global: see AreaStyle.winCrop/litColor/
  // litRatio/litIntensity and the style file that sets them (render.world.CityStyle et al)
  // facade variant names by Building.facade index (inspector tags + per-variant logic)
  public static final FACADE_NAMES = ['concrete', 'brick', 'stone', 'metal', 'sleek'];
  public static inline var WIN_W = 1.6;        // window world width (height derived from sprite aspect)
  public static inline var WIN_PITCH_X = 2.6;  // horizontal center-to-center spacing (vertical = FLOOR_H)
  public static inline var WIN_MARGIN = 0.9;   // min plain-wall border at face edges

  // --- tone mapping ---------------------------------------------------------
  // the authored exposure fed to ACES in the composer's OutputPass. the config brightness slider
  // (vidBrightness) is a percentage OF this, so the art value stays the single source of the default
  // look. it is a plain uniform read per frame by OutputPass, so changing it live costs nothing
  public static inline var EXPOSURE = 1.5;

  // --- bloom ----------------------------------------------------------------
  public static inline var BLOOM_STRENGTH = 0.25;  // overall bloom amount
  public static inline var BLOOM_RADIUS = 0.1;     // bloom spread radius
  public static inline var BLOOM_THRESHOLD = 0.9;  // luminance above which pixels bloom

  // --- window light switches (render.world.Windows.pulse) ---------------------
  // someone in the city flips a light. RAW ms, not BASE_MS multiples, and deliberately so: this is
  // ambient city life on a wall clock, not a turn-derived animation — the same reasoning that keeps
  // the failing-lamp flicker on raw ms. each building runs its own countdown, and on each tick it
  // RESAMPLES one random window against the style's litRatio, so the lit fraction stays where the
  // build put it instead of drifting to half. a resample that lands on the state the window is
  // already in is a no-op, which is most of them at ratio 0.1 — hence the short interval
  public static final WIN_SWITCH = {
    minMs: 3000.0,  // shortest gap between one building's resamples
    maxMs: 12000.0, // longest gap; the initial countdown is drawn from the same range so buildings never tick in unison
  };

  // --- ambient occlusion (GTAOPass; only runs when config vidAO) --------------
  // kept subtle on purpose: this should read as contact shadow where geometry meets, not as
  // photoreal dirt — the city art is flat/hand-painted. tune blendIntensity first, radius second
  public static final GTAO = {
    blendIntensity: 0.6,    // AO strength over the beauty pass (1 = full darkening)
    radius: 1.5,            // world-space sample radius, ~a third of a cell (CityConfig.CELL = 4);
                            // must be scaled against CELL — below ~0.5 the effect is invisible at city scale
    distanceExponent: 1.0,  // falloff curve with distance from the sample point
    thickness: 1.0,         // assumed occluder thickness (higher = less light leak behind edges)
    scale: 1.0,             // overall AO scale before blending
    samples: 16,            // per-pixel AO samples; lower = cheaper + noisier (denoiser cleans up)
  };

  // camera: offset lerps near..far by a normalized zoom (0=close/parallel, 1=far/top-down);
  // far is the absolute max distance, ~20deg tilt from vertical, trailing to +Z (south)
  public static final CAMERA = {
    near: { x: 0.0, y: 14.0, z: 24.0 },  // zoom=0: close, ~30deg above ground (parallel-ish)
    far:  { x: 0.0, y: 60.0, z: 22.0 },  // zoom=1: top-down = absolute max distance
    fov: 45.0,
    follow: 1.0,          // per-frame camera-position lerp (higher = tighter); zoom smoothing is separate
    zoomLerp: 0.12,       // per-frame ease of zoom toward its target (the smoothing)
    zoomStep: 0.12,       // zoom delta per wheel notch
    parasiteZoom: 0.30,   // parasite + attached: cap AND resting target (much smaller than max)
    hostZoom: 0.60,       // host: auto pull-out target on invade (cap stays 1.0 = far/max)
    sideAngle: Math.PI / 36, // 5-degree orbit toward a wall-side view
    sideTurnLerp: 0.2,     // half-speed easing: fraction of the remaining angle per BASE_MS
    orbitSens: 0.006,      // radians of orbit per mouse pixel (hold-RMB drag)
    orbitPitchMin: -0.9,   // added-pitch clamp (rad): how far the camera can rise toward overhead
    orbitPitchMax: 0.15,   // added-pitch clamp (rad): lowest camera = only a little below the default view
    orbitYawMax: Math.PI / 6, // max left/right orbit from the default heading (rad) — ±30 degrees
    orbitElevMax: 1.5,     // hard cap (rad, ~86deg) on the camera's total elevation so a raise at
                           // high zoom-out can't carry it past vertical and flip over the top
    orbitReturnLerp: 0.15, // per-BASE_MS ease of the orbit back to 0 on RMB release
    introMult: 6.0,       // enter effect: zoom-out from closest to resting target, BASE_MS multiples
    exitMult: 6.0         // leave effect: zoom-in to closest over the frozen last frame, then tear down
  };
  // enclosed areas (sewer/habitat tunnels) look almost straight down. the walls are only ~1.5 cells
  // tall and there is no ceiling, so the shallow street angle above would stare into a wall face
  // instead of down the corridor — and at this pitch a wall occludes almost nothing, which is what
  // lets the tunnels skip building fading entirely
  public static final CAMERA_SEWER:CameraOffsets = {
    near: { x: 0.0, y: 16.0, z: 12.0 },  // zoom=0: close, looking well down into the corridor
    far:  { x: 0.0, y: 40.0, z: 14.0 },  // zoom=1: near top-down
  };
  // open wilderness. between the street and the tunnel presets, and for the same reason the tunnel
  // one is steep: there is NO occlusion fade out here (nothing is a building), so a tree or a rock
  // between the camera and the player just hides them. a steeper look-down shortens what any prop
  // can cover, and it is also the honest view of ground whose whole content is what is lying on it
  public static final CAMERA_WILD:CameraOffsets = {
    near: { x: 0.0, y: 18.0, z: 20.0 },  // zoom=0: closest, ~42 degrees above ground
    far:  { x: 0.0, y: 55.0, z: 18.0 },  // zoom=1: near top-down
  };
  // a facility compound: an open lot with single-storey buildings standing on it, and the only kind
  // the player goes INSIDE. between the street and the tunnel presets and for a reason neither of
  // them has — indoors a south wall is 1.5 cells tall and a corridor 3 cells wide, so the pitch sets
  // how much of that corridor the near wall eats: 6 / tan(pitch) is 4.9 units here (1.2 cells) and
  // would be 8.4 at the street's 30 degrees. the rest of that problem is paid for by fading the
  // south faces with the roof (render.facility.FacilityStyle.WALL_FADE) rather than by going steeper
  // still, because outdoors the height is what makes the thing read as a building at all
  public static final CAMERA_FACILITY:CameraOffsets = {
    near: { x: 0.0, y: 20.0, z: 16.0 },  // zoom=0: closest, ~51 degrees above ground
    far:  { x: 0.0, y: 48.0, z: 16.0 },  // zoom=1: near top-down
  };
  // occlusion fade: a building between camera and player eases to this opacity so the player
  // stays visible, then eases back to solid when it no longer blocks the sightline
  public static final OCCLUSION = {
    fade: 0.22,    // opacity an occluding building fades to (0 = invisible, 1 = solid)
    ghostDim: 1.0,  // faded facades swap to a LIT-but-shadowless Lambert ghost (samples moon/lamps,
                    // NOT the shadow maps — the costly part); the lighting supplies brightness so this
                    // is just a tint/dim knob (1.0 = match the lit real, lower to darken the ghost)
    ghostCross: 0.6, // fade level where the ghost has fully dissolved IN over the still-solid real
                     // (real is hidden below this, ghost eases on to see-through above it). raises =
                     // longer lit->ghost cross-dissolve, less pop; must stay above `fade`
    lerp: 0.15,    // per-30fps-frame ease of fade toward its target (dt-compensated)
    snap: 0.15,    // lock fade to target once within this gap: skips the slow exponential tail
                   // (invisible on the flat wall) so windows crisp back + bloom the moment the
                   // wall reads solid, instead of ~0.8s later
    margin: 1.0,   // XZ expansion when bucketing face-proud decals into their building
    aimGrow: 1.5,  // targeting-mode: cells of lateral slack, so buildings flanking the
                   // cam->player / cam->target line fade too (not just strict occluders)
    // footprint plate: a flat semi-transparent quad on the ground over each building, shown only
    // while the building is faded (building cells are unpaved, so a see-through wall would leave
    // no sign the building stands there). alpha scales with how faded the building is
    plateColor: 0x3a4152, // plate tint (cool grey-blue, reads as a footprint marker)
    plateAlpha: 0.38,     // plate opacity at full fade (scaled by 1 - fade each frame)
    plateY: 0.05,         // plate height above the (unpaved) building-cell ground
    // glowing footprint outline: a dashed thin ground line tracing the footprint edge, drawn in the
    // tactical-grid recipe — an unlit MeshBasic quad strip whose color is multiplied past 1 (HDR,
    // toneMapped off) so it clears the bloom threshold and glows regardless of scene lighting
    outlineColor: 0x74c0ff,  // outline tint (cool cyan-blue)
    outlineGlow: 5.0,        // HDR color multiplier (like TacticalGrid.GLOW) so the dashes bloom
    outlineAlpha: 0.7,       // outline opacity at full fade (scaled by 1 - fade each frame)
    outlineWidth: 0.015,     // dash half-width as a fraction of a cell (matches the tactical grid line)
    outlineDash: 0.6,        // dash length (world units)
    outlineGap: 0.4          // gap between dashes (world units)
  };
  // melee choreography + 3D blood. lunge = attacker there-and-back reach; on lunge finish the
  // impact sound + target shake + blood burst fire. drops arc ballistically and land as SPLAT
  // ground decorations (rendered flat, persisted + cleared on area exit like 2D splats)
  public static final MELEE = {
    lungeMs: 260.0,      // lunge duration (ms); sound/shake/blood/arc fire at the apex dwell
    lungeReach: 0.55,    // lunge peak reach toward the target, as a fraction of a CELL
    apexStart: 0.42,     // progress where the reach lands + the impact beat/arc fire
    apexEnd: 0.58,       // progress where the retreat begins (dwell = apexStart..apexEnd)
    shakeMs: 150.0,      // target hit-shake duration
    shakeAmp: 0.10,      // target hit-shake amplitude, as a fraction of a CELL
  };
  // host breaking hit: the player's host flashes red once and shakes when degradation brings it
  // close to collapsing (render.anim.BreakShake)
  public static final BREAKING = {
    ms: BASE_MS * 3.0,   // flash + shake duration
    shakeAmp: 0.09,      // jitter amplitude, as a fraction of a CELL
    color: 0xff2a2a,     // flash color: purer than --text-color-alert, as it multiplies the sprite's own colors
    glow: 2.0,           // flash peak self-glow intensity
  };
  // attack-FX sprite visuals: a glowing procedural rasterized-SVG shape — melee swings spawned at
  // the strike apex (keyed by the weapon's _AttackEffect) and impact marks stamped on a struck
  // target. per kind: color (emissive tint), scale (of Sprites.SIZE), sweep (roll swept over the
  // life, radians), flat (lie the sprite on the ground vs upright billboard), travel (slide
  // attacker->target over the life, e.g. a thrown punch)
  public static final ATTACK_FX = {
    lifeMult: 1.3,       // fx life as a multiple of BASE_MS (all kinds share the base timing)
    emissiveInt: 1.3,    // emissive intensity — bright enough to read at night, low enough to keep tint
    px: 128,             // rasterized shape texture edge (px)
    kinds: {
      // horizontal blade streak lying flat on the ground, aligned to the swing
      SLASH_LIGHT: { color: 0xcfe6ff, scale: 1.1, sweep: 0.4, flat: true,  travel: false, travelMult: 1.0 },
      // big horizontal blade streak lying flat on the ground (like the knife, wider)
      SLASH_HEAVY: { color: 0xffffff, scale: 1.7, sweep: 0.3, flat: true, travel: false, travelMult: 1.0 },
      // short fat upright impact arc
      BLUNT:       { color: 0xf0e2c0, scale: 1.0, sweep: 0.4, flat: false, travel: false, travelMult: 1.0 },
      // a fist thrust from attacker to target (travelMult > 1 = flies faster, lands before life ends)
      PUNCH:       { color: 0xffffff, scale: 0.55, sweep: 0.0, flat: false, travel: true, travelMult: 1.5 },
      // triple horizontal claw slash
      BITE:        { color: 0xff5030, scale: 1.0, sweep: 0.0, flat: false, travel: false, travelMult: 1.0 },
      // blue electric bolt
      STUN:        { color: 0x66ccff, scale: 1.0, sweep: 0.0, flat: false, travel: false, travelMult: 1.0 },
      // curved-X mark stamped on the target when a thrown projectile connects
      IMPACT:      { color: 0x98b4f0, scale: 0.9, sweep: 0.4, flat: false, travel: false, travelMult: 1.0 },
    },
  };
  public static final BLOOD = {
    drops: 7,            // droplets thrown per bloody hit
    dripDrops: 3,        // droplets for a non-combat splat (bleeding drip, black noise) — smaller, unbiased
    dropMs: 260.0,       // droplet flight time before it lands as a decal
    speed: 3.6,          // horizontal launch speed spread (cells worth, away from attacker)
    up: 9.6,             // upward launch impulse
    gravity: 144.0,      // downward accel pulling drops back to the ground
    dropScale: 0.3,      // in-flight droplet quad scale (of a billboard)
    scaleMin: 0.15,      // landed splat min scale
    scaleMax: 0.5,       // landed splat max scale
    wetRough: 0.4,       // landed-splat specular roughness (< 1 = wet sheen off moon/lamps; 1 = matte)
    // acid/slime goop glow: emissive tint pushed through the splat's own sprite (emissiveMap), so
    // the glow is alpha-shaped; intensity compensates the DECAL.bloodMul-darkened crop and lets the
    // hottest pixels cross BLOOM_THRESHOLD for a faint halo. 0 intensity = off
    acidGlow: 0x58ff3c,  // acid emissive tint (in-flight blob + landed splat)
    slimeGlow: 0x7ddc46, // slime emissive tint
    glowInt: 1.0,        // landed-splat emissive intensity
    glowIntFlight: 0.8,  // in-flight blob emissive intensity (full-bright atlas crop, needs less)
    // otherworldly black blood: an iridescent oil-slick film (emissive hue ping-ponging over the
    // teal->violet->magenta arc on a slow clock, each splat phase-offset by a cell hash) plus rare
    // star glints (short deterministic emissive spikes over BLOOM_THRESHOLD). timing in BASE_MS
    // multiples; in-flight black drops get a fixed violet glow (too short-lived to cycle)
    blackShimmerInt: 0.55, // iridescent film emissive intensity
    blackCycleMult: 32.0,  // hue-cycle period (BASE_MS multiples)
    blackGlintMult: 6.0,   // glint time-bucket size per splat (BASE_MS multiples)
    blackGlintFrac: 1.7,   // fraction of a bucket the glint swell lasts (sine bell in + out)
    blackGlintPct: 5,     // % of buckets where a splat actually glints
    blackGlintInt: 2.5,    // glint emissive spike intensity (well over the bloom threshold)
    blackStarMax: 2,      // max concurrent point stars; new spawns hard-blocked while slots full
    blackStarScale: 0.1,   // point-star quad scale at glint peak (of a billboard)
    blackStarAlpha: 0.9,    // point-star opacity cap (subdues the glint; emissive still glows through)
    blackFlightGlow: 0x8a5cff, // in-flight black-drop violet tint
    wetMetal: 0.5,       // landed-splat metalness (> 0 tints the glint by the red albedo; stronger, wetter)
  };
  // green slime the free (unhosted) parasite leaves as it crawls, plus a lingering puddle where it
  // lands from a leap on/off a host. both are render-only (NOT persisted): the trail is a triangle
  // strip rebuilt each frame along the parasite's recent path (follows turns, dissolves over the
  // last ~lengthCells tiles), the puddle a fading ground quad. reuses BLOOD.slimeGlow for the green
  public static final SLIME = {
    sampleCells: 0.3,     // commit a new ribbon spine point once the parasite has moved this far (cells)
    lengthCells: 4.0,     // path length kept behind the parasite; older trimmed (the ~4-tile tail)
    widthCells: 0.42,     // ribbon width (cells); tapered to a point at the tail
    fadeCells: 1.5,       // tail dissolve band (cells): width + alpha ramp 0 -> 1 over this length from the tail
    headFadeCells: 0.5,   // head shaping band (cells): the leading end narrows over this length so it isn't a flat cut
    headMinFrac: 0.35,    // head width at the very tip as a fraction of full: 0 = sharp comet point, 0.35 = rounded nub, 1 = flat cut
    waveAmpCells: 0.22,   // max lateral wander of the ribbon centerline (cells); a random-walk per sample = gentle meander (0 = dead straight)
    waveStepCells: 0.12,  // random-walk step per sample toward that wander (bigger = wavier / faster wobble)
    widthJitter: 0.25,    // per-point width variation as a fraction (0.25 = +/-25%) for irregular, non-parallel edges
    yOff: 0.05,           // ribbon/puddle height above the floor (like the ground decals)
    baseAlpha: 0.7,       // overall ribbon opacity (multiplies the tail-fade vertex alpha; head caps here)
    glowInt: 0.0,         // slime emissive intensity (BLOOD.slimeGlow tint), catches the bloom faintly. TEST: 0 = no glow (restore ~0.7)
    fadeOutMult: 6.0,     // when the parasite stops crawling (jumps on a host), the frozen trail fades out over this (BASE_MS multiples) instead of vanishing
    puddleScale: 0.8,     // landing-puddle quad scale (of a billboard)
    puddleLifeMult: 24.0, // puddle fade-out duration (BASE_MS multiples)
  };
  // mouse-hover move path preview in the 3D street view (render.PathLine): a thin, greenish, wavy
  // bloom-glowing ribbon from the player to the hovered tile, ending in a slightly larger target dot.
  // waviness is driven by host control (low control = wavy, full control / free parasite = straight).
  // render-only, rebuilt from the pathfinder's cell list whenever the hover target changes
  public static final PATH = {
    color: 0x7ddc46,      // sickly alien-slime green (matches BLOOD.slimeGlow) at FULL control, HDR-multiplied by glow so bloom picks it up
    lostColor: 0xd0452a,  // discolored toward this toxic rust-red as host control is lost (0 control = full shift)
    glow: 3.2,            // HDR color multiplier (must clear the bloom threshold; lower = softer glow)
    alpha: 0.85,          // overall ribbon/dot opacity
    widthCells: 0.010,    // ribbon half-width (cells); thinner than the tactical grid marks (0.015)
    dotScaleCells: 0.053, // target-dot disc radius (cells) at the path end
    dotStartScale: 0.8,   // start-dot radius as a fraction of the target dot (0.8 = 20% smaller)
    dotPulse: 0.18,       // dot pulse depth (fraction of its size; 0 = no pulse)
    dotPulseMult: 32.0,    // dot pulse speed as a BASE_MS multiplier (one throb per this many base-turns)
    samplesPerCell: 16,   // Catmull-Rom resample density per cell segment (curve smoothness; higher = smoother wavy line at low control)
    waveAmpCells: 0.30,   // max lateral wander of the centerline (cells) at ZERO host control (fully wavy)
    waveLenCells: 1.4,    // wavelength of the sine wobble (cells); smaller = tighter waves
    waveSpeedMult: 0.2,   // wobble scroll speed as a BASE_MS multiplier (phase advance per turn)
    yOff: 0.06,           // height above the floor (like the tactical grid / ring)
  };
  // 3D ground-decal albedo darkening (0..1): decal art was authored for the unlit 2D view, so in the
  // lit 3D rig (full ambient+hemisphere+moon on an up-facing quad) it reads too bright. multiply the
  // 3D texture crop down so decals sit in the road instead of glowing on top. 2D is unaffected
  // (it draws from the source image, not these crops). blood stays a touch more vivid than debris
  public static final DECAL = {
    bloodMul: 0.6,       // blood-splat crop darken factor
    // how far proud of a wall's own face a splat standing on it sits. it was 0.12 written inline and
    // measured from the CELL CENTRE, which is only the same thing where the masonry fills its cell;
    // it is measured from the face the area kind actually draws now (WorldCtx.faceOff)
    wallProud: 0.12,
    // street-debris + thrown-money crop darken factor (matte trash, no bright glow).
    //
    // 0.40 and MEASURED, after the wilderness roadside litter put this art on turf for the first
    // time and it read as scattered paper. the atlas is painted at sRGB mean 199/193/187 (singles)
    // and 208/208/205 (clusters) — paper values — and at 0.55 that still delivered LINEAR luminance
    // 0.1501 / 0.1740, against turf 0.0476, blades 0.0673 and asphalt 0.0329. So 3.15x the ground it
    // lies on, where the blades are 1.41x and WildStyle's header calls THEM the brightest thing out
    // there bar the actor; city/ground-road-paint, which is white lane paint, measures 0.2402, so a
    // crushed can was landing 62% of the way from the ground to a road marking. 0.40 puts it at
    // 0.0773 — composited over the ground through the atlas's own alpha, 1.27x turf / 1.57x asphalt,
    // just under the blades.
    //
    // the city gets the same correction and wants it: its streets are that same asphalt, so the
    // defect was identical there and simply had no bright ground beside it to be caught against
    debrisMul: 0.40,
    // how far a GROUND decal (litter, blood, bullet holes) is lifted off the floor it lies on.
    //
    // 0.12 rather than the 0.04 it ran at, and the number is not a nudge: it has to clear the tallest
    // ground LAYER an area lays over its own floor, or the layer is drawn on top of the decal and the
    // decal simply vanishes under it. the wilderness stacks four — patch 0.02, patch 0.04, asphalt
    // WildStyle.ROAD_Y 0.06, centre line ROAD_PAINT_Y 0.09 — so at 0.04 every piece of roadside litter
    // that landed on the highway was UNDER it. measured live: 54 of 109 spots on the asphalt, 47 of
    // them buried, worst by 0.087.
    //
    // it pairs with WorldCtx.floorYAt: a decal holds a real world position, so sampling its height at
    // the CELL CENTRE (floorY) is off by the cell's own slope, measured mean 0.019 / max 0.083 out
    // here — which is the same order as the gap above and was MASKING it. fixing the sampler alone
    // took the buried count from 47 to 54, because the seven that escaped only did so by accident
    groundLift: 0.12,
    actorMul: 0.7,       // actor-sprite crop darken factor (knock the full-bright atlas down so AI
                         // don't read too white in the surrounding night; 1.0 = off, lit-only)
    radiusCells: 20.0,   // ground-decal reveal radius (cells) around the smoothed player pos; replaces LOS
    fadeCells: 1.5,      // soft edge band (cells): opaque inside (radius-fade), invisible past radius
    // shared FIFO cap for dynamic decals (blood splats + thrown money + bullet holes): oldest evicted
    // past this. high headroom since decals are instanced (one draw call per texture, not per decal)
    dynamicMax: 384,
  };
  // burning barrels that actually burn (low-tier only): a pooled warm point light (MuzzleLights
  // pattern, constant NUM_POINT_LIGHTS), an uneven flicker, a soft additive flame body + rising
  // embers, and fake projected-silhouette shadows cast from nearby actors onto the ground. no real
  // shadow maps. distances in "cells" are * CityConfig.CELL; ms are durations; colors are warm tones
  public static final FLAME = {
    lightPool: 5,           // fixed warm point-light count (idle at 0, never toggled -> no recompile)
    lightColor: 0xff7a1e,   // flame point-light tint
    lightIntensity: 26.0,   // base peak intensity (flicker modulates it)
    lightDistance: 16.0,    // point-light reach (world units, 4 cells): falls to 0 by here (decay curve)
    lightRangeCells: 10,    // only barrels within this many cells of the player claim a pool light
    litRangeCells: 4,       // an actor this many or more cells from a barrel gets no warm flicker glow (like shadows)
    rimY: 1.8,              // flame + light height above the barrel's ground (world units)
    // flicker: two summed sines on a raw-dt clock, per-barrel phase (freqs are per-ms)
    flickFreqA: 0.017,
    flickFreqB: 0.031,
    flickMin: 0.55,         // dimmest the flicker pulls the light/flame to (fraction of peak)
    // flame body: a camera-facing flame sprite (static art, code-animated) over a soft glow halo
    bodyRise: 2.3,          // flame sprite height at rest (world units; flicker stretches it)
    bodyW: 1.2,             // flame sprite width (world units; flicker breathes it)
    bodyAlpha: 0.25,        // flame sprite base opacity (additive; flicker + layer scale it)
    glowW: 2.2,             // soft glow halo width (world units)
    glowAlpha: 0.1,         // soft glow halo opacity (additive underlay, centered on the rim)
    colorHot: 0xffd070,     // hot tint (inner flame layer + glow)
    colorTip: 0xd83400,     // cooler tint (outer flame layer)
    // warm flicker the flame throws onto nearby actors (emissive on their own sprite, shaped + fading
    // with distance, pulsing with the flicker) — on top of the pooled point light's lit flicker
    litColor: 0xff8434,     // warm emissive tint on a lit actor
    litStrength: 0.3,       // peak emissive intensity (0 = off); scales by flicker * distance falloff
    // embers: one FlameEmber3D spawned ~every emberMs per visible barrel
    emberMs: 130.0,         // avg ms between ember spawns per barrel
    emberLife: 750.0,       // ember lifetime (ms)
    emberRise: 1.2,         // ember upward speed (cells/sec)
    emberColor: 0xffb050,   // ember tint
    emberW: 0.05,           // ember dot width (cells)
    // fake shadows: black soft-edged silhouettes stretched away from each nearby barrel
    shadowMax: 4,           // at most this many shadows per actor (its nearest barrels)
    shadowRangeCells: 4,    // a barrel this many or more cells away casts no shadow on the actor
    shadowOp: 0.9,          // per-shadow opacity (stacks where several overlap near the feet)
    shadowLenMul: 1.4,      // shadow length = sprite world-height * this * distance falloff
    shadowSoftPx: 3,        // blur radius baked into the black crop for the soft edge
    shadowFade: 0.3,        // outer fraction of the range over which a shadow eases to 0 (smooth
                            // enter/leave as the actor slides across the radius — motion is the anim)
  };
  // 3D gun-shot choreography: a blooming tracer streak races muzzle->impact, a muzzle flash +
  // transient point light pop at the shooter, impact sparks + blood on a hit, and (player only)
  // a small camera recoil. per-weapon pellet counts mirror the 2D shot feel. sizes marked
  // "cells" are fractions of CityConfig.CELL; ms are durations; colors are warm muzzle tones
  public static final SHOT = {
    tracerJitter: 0.1,      // random offset on both tracer ends so shots don't share one exact line (cells)
    tailFrac: 0.55,         // streak visible length as a fraction of the full muzzle->impact run
    travelMs: 55.0,         // time the tracer head takes to race to the target
    flashSize: 0.1,         // muzzle flash quad size (cells)
    flashMs: 70.0,          // muzzle flash fade time
    flashColor: 0xffdf9c,   // muzzle flash tint
    lightIntensity: 42.0,   // muzzle point-light peak intensity
    lightDistance: 24.0,    // muzzle point-light reach (world units, ~6 cells)
    lightMs: 90.0,          // muzzle point-light decay time
    lightColor: 0xffc474,   // muzzle point-light tint (matches the lamps' warm)
    lightPool: 5,           // fixed muzzle-light count (always in the scene, idle at intensity 0
                            // so NUM_POINT_LIGHTS never changes -> no shader recompile on a shot)
    lightRangeCells: 14,    // only shots within this many cells of the player claim a muzzle light
    sparkCount: 7,          // impact embers per wall strike
    sparkMs: 100.0,         // ember life
    sparkSpeed: 6.0,        // ember launch speed (cells/sec)
    sparkCone: 1.8,         // spray cone width around the back-off-wall direction (radians)
    sparkGravity: 20.0,     // ember downward accel (cells/sec^2), gives the arc
    sparkWidth: 0.05,       // ember streak width (cells)
    sparkStreak: 0.03,      // ember streak length = speed * this (seconds of travel drawn)
    sparkColor: 0xfff0d0,   // ember tint
    recoilAmp: 0.9,         // player-shot camera kick (world units, back along the shot)
    recoilMs: 160.0,        // camera recoil settle time
    waveMs: 250.0,          // stun-bolt wave drift period (one sine cycle slithers per this)
    // per-weapon: pellets fired, target jitter (cells), stagger between pellets (ms), the max
    // tiles a missed bullet flies before it fades off-camera (shotgun stops short), tracer
    // color/width, sine-wave shape (waveAmp 0 = straight; waveLen = cells per cycle),
    // travelMult = travelMs multiplier (stun bolt flies slower), and bullet = real slug
    // (blood burst + wall hole) vs energy bolt (neither)
    kinds: {
      pistol:  { pellets: 1, spread: 0.0,  stagger: 0.0,  range: 14, color: 0xfff2c8, width: 0.03, waveAmp: 0.0,  waveLen: 1.0, travelMult: 1.0, bullet: true },
      rifle:   { pellets: 3, spread: 0.15, stagger: 45.0, range: 14, color: 0xfff2c8, width: 0.03, waveAmp: 0.0,  waveLen: 1.0, travelMult: 1.0, bullet: true },
      shotgun: { pellets: 5, spread: 0.5,  stagger: 0.0,  range: 5,  color: 0xfff2c8, width: 0.03, waveAmp: 0.0,  waveLen: 1.0, travelMult: 1.0, bullet: true },
      stun:    { pellets: 1, spread: 0.0,  stagger: 0.0,  range: 14, color: 0x66ccff, width: 0.06, waveAmp: 0.08, waveLen: 0.8, travelMult: 2.0, bullet: false },
    },
  };

  // 3D thrown-projectile choreography (spit clots / spine needles / blood clots): an entities-atlas
  // blob with trailing drips races source->target at chest height, then the impact splat beat (burst
  // decals + splat sound) fires. timings mirror the 2D ParticleSpit/ParticleNeedle feel.
  // arc = sine lob peak above the flight line (cells); 0 = the flat chest-height race
  public static final PROJECTILE = {
    spit:   { travelMs: 150.0, scale: 0.3,  drips: 3, arc: 0.0 },   // spit clot: fat blob + drip trail
    needle: { travelMs: 110.0, scale: 0.16, drips: 2, arc: 0.0 },   // spine needle: small + fast afterimages
    blood:  { travelMs: 220.0, scale: 0.22, drips: 2, arc: 0.55 },  // blood clot: lobbed, short trail
    dripGap: 0.2,        // spacing between trail blobs along the flight line (cells)
    dripSway: 0.1,       // per-drip lateral offset amplitude (cells)
    wobbleAmp: 0.04,     // sine wobble amplitude on the drips (cells)
    fadeFrac: 0.2,       // trailing fraction of the flight over which everything fades out
  };

  // thrown money crowd control: a chaotic fountain of tumbling bills launched from the thrower,
  // arcing out over the throw radius, landing flat on the ground and fading out after a rest.
  // 3D port of ParticleMoney (real flying bills instead of per-tile pops)
  public static final MONEY = {
    bills: 80,           // bills per throw
    flyMult: 2.5,        // per-bill flight duration (BASE_MS multiples)
    flyVar: 1.0,         // random flight-duration spread (+/-, BASE_MS multiples)
    staggerMult: 1.5,    // random per-bill launch delay window (BASE_MS multiples)
    restMult: 5.0,       // landed rest before fading (BASE_MS multiples)
    fadeMult: 2.0,       // landed fade-out duration (BASE_MS multiples)
    scale: 0.44,         // bill scale (of a billboard)
    arcHeight: 0.8,      // arc peak above the launch line (cells)
    spinMax: 6.0,        // horizontal-mirror tumble speed cap (rad per BASE_MS)
    rollMax: 3.0,        // in-plane roll speed cap (+/-, rad per BASE_MS)
    flutter: 0.12,       // lateral flutter amplitude at landing speed (cells)
    minDist: 0.4,        // min landing distance from the thrower (cells)
    // lingering ground stains: a flat money decal laid on every walkable tile in the throw radius.
    // ~permFrac of them are permanent (persisted tile decorations in the shared dynamic-decal FIFO,
    // like blood splats), the rest fade out after a short rest (view-side). 3D port of 2D
    // ParticleMoney.onDeath's addEffect ground decal
    groundScaleMin: 0.9, // ground-stain scale min (of a billboard)
    groundScaleMax: 1.0, // ground-stain scale max
    groundScatter: 0.3,  // per-tile sub-cell random offset (cells)
    permFrac: 0.5,       // fraction of stains that stay permanent (rest fade out)
    tempHoldMult: 6.0,   // fading stain: full-opacity rest before fading (BASE_MS multiples)
    tempFadeMult: 3.0,   // fading stain: fade-out duration (BASE_MS multiples)
  };

  // choir silent scream: an expanding ghostly dome (additive hemisphere mesh) + a screen-space
  // shockwave ripple (post pass before bloom) that distorts the image under the wave front.
  // timing in BASE_MS multiples; the 2D particle ran 320ms over 5 tiles
  public static final SCREAM = {
    lifeMult: 8.0,        // pulse duration (BASE_MS multiples)
    radiusCells: 1.0 * abilities.ChoirSilentScream.RADIUS, // wave end radius (cells) = the gameplay effect radius
    easePow: 5.0,         // radius ease-out exponent (higher = harder slowdown near the end)
    domeColor: 0xc0c8dc,  // dome tint (the 2D light pulse's pale blue-white)
    domeAlpha: 0.18,      // dome peak opacity (additive)
    domeSquash: 0.5,      // dome height vs radius (1 = full hemisphere)
    domeSegs: 48,         // hemisphere segments around
    noisePx: 3.0,         // dome static: screen-space grain size (px)
    noiseRate: 3.0,       // dome static: noise re-rolls per BASE_MS (TV-static flicker speed)
    rippleAmp: 0.025,     // shockwave UV displacement at full strength (screen fractions)
    rippleWidth: 0.35,    // ripple band half-width as a fraction of the current ring radius
    rippleCycles: 3.0,    // sine waves across the band (water rings; more = finer ripples)
    maxPulses: 4,         // shader uniform slots (max simultaneous screams rippling)
  };

  // organ gas clouds (panic / paralysis): a cluster of soft, LIT, alpha-blended puff sprites over the
  // emission cell. lit (like actor sprites) so the gas catches the lamp spotlights + moon instead of
  // self-glowing; a baked spherical normal map rounds each puff. the cluster billows in (activation
  // burst), drifts up + spreads low and wide, then fades over its life. cosmetic only (entering re-
  // applies nothing). colors are desaturated/light so the lit tint stays readable at night
  public static final GAS = {
    panicColor: 0xe0907a,     // panic gas tint (dusty light red)
    paralysisColor: 0x6ab0ff, // paralysis spore tint (light dodger blue)
    speed: 1.5,               // playback speed multiplier for the whole cloud (life + drift + spin)
    atlasFrac: 0.4,           // fraction of puffs drawn with the game's own 2D gas frame (entities
                              // ROW_EFFECT / FRAME_*_GAS) instead of the baked blob — blends the art in
    pixelSize: 40,            // baked puff texture resolution (px); low + NearestFilter = chunky pixels
    puffDensity: 9.0,         // puffs per cell² of footprint (count scales with range² for even density)
    puffMin: 30,              // floor on puff count (tiny clouds still read solid)
    puffCap: 120,             // ceiling on puff count (overdraw budget)
    puffScaleMin: 1.6,        // per-puff base size (multiples of Sprites.SIZE)
    puffScaleMax: 2.8,
    startScale: 0.6,          // fraction of base size at spawn (grows toward base+growth)
    growth: 1.1,              // extra size added over the full life (fraction of base)
    spread: 1.0,              // footprint jitter radius = gas range (cells) * CELL * this (= the
                              // Euclidean effect radius; puff size then softly overspills the edge)
    drift: 0.5,               // outward drift speed (cells/sec)
    rise: 0.4,                // upward drift speed (cells/sec) — gentle, ground-hugging
    spin: 0.5,                // baked-blob in-plane roll speed cap (rad/sec, +/-)
    atlasSpin: 0.6,           // atlas-sprite roll speed cap (rad/sec, +/-) — subtle, recognizable art
    alpha: 0.38,              // peak per-puff opacity (many overlap -> denser centre; kept low for smooth buildup)
    normalScale: 1.0,         // spherical normal-map strength (how rounded the lamp shading reads)
    lifeMult: 24.0,           // total cloud lifetime (BASE_MS multiples) ~ a few seconds
    burstMult: 2.0,           // billow-in window: puff appear stagger + ramp (BASE_MS multiples)
    fadeFrac: 0.4,            // trailing fraction of life over which the cloud fades out
  };

  // bullet holes: a missed shot that strikes a BARE (worn/windowless) wall leaves a small
  // rotated decal, persisted as a WALLHOLE tile-decoration + re-painted on the wall each frame
  // (fog-gated, cleared on area exit, capped like blood splats). glass/window faces get none
  public static final WALLHOLE = {
    scale: 0.13,       // hole quad scale (of Sprites.SIZE)
    scaleVar: 0.04,    // +/- random scale spread
    spread: 0.35,      // horizontal wall-miss scatter (cells): tracer end + spark + hole SHARE it,
                       // so repeated shots at one wall spread out (and stay aligned) instead of stacking
    vspread: 0.12,     // vertical scatter (cells): kept small so holes cluster near aim height
                       // (full `spread` vertically would range knee->head and read as random)
  };
  // AI through-wall x-ray outline: a colored, patterned silhouette of an AI's own sprite drawn ONLY
  // where a wall hides it from the camera (GreaterDepth depth compare) while the player still has LOS
  // — clear-view AIs show nothing. color = alert state (cult-pink for followers, see Actors)
  public static final XRAY = {
    fill: 'scan',        // interior pattern: 'diag' | 'cross' | 'scan' | 'dots' | 'solid'
    hatchSpacing: 7,     // pattern line period (crop px)
    hatchThick: 2,       // pattern line width (crop px)
    grow: 1.0,          // silhouette scale vs the sprite
    emissive: 0.9,       // silhouette self-glow (legibility at night)
  };
  // world-object marks (render.Actors object pass), the object twin of XRAY above: a glowing ring
  // hugging the object's sprite while the TACTICAL view is up (the icons are tiny at that zoom), and
  // a patterned silhouette wherever a building hides the object from the camera (GreaterDepth, like
  // the AI x-ray) — that one is always on. only objects AreaObject.visible() calls player-noticeable
  // are marked, so decorations/doors stay unmarked. the color and pattern are deliberately outside
  // the AI alert ramp (white/amber/orange/red/cult-pink/slate, 'scan') so a mark never reads as an AI.
  // the green also splits objects from the BLUE overlays (tactical grid, faded-building footprints)
  public static final OBJMARK = {
    color: 0x35dd7a,     // emerald green — clear of the AI colors, the cool-blue footprint dashes, and
                         // bluer/colder than the path line's yellow-green slime (PATH.color 0x7ddc46)
    emissive: 0.9,       // silhouette/ring self-glow (legibility at night), as XRAY.emissive
    outlinePx: 1.5,      // tactical ring width (crop px; fractional is fine, the dilation is canvas-drawn)
    fill: 'dots',        // occluded-silhouette pattern: the AI keeps 'scan'
    hatchSpacing: 6,     // pattern period (crop px)
    hatchThick: 2,       // pattern dot width (crop px)
    hullW: 0.06,         // an object drawn as a 3D PROP is outlined by a backface shell instead (see
                         // render.Models ModelVariant.HULL): this is how far the shell stands off the
                         // real surface, in WORLD units, so it is the outline's thickness
  };
  // AI status badges float this fraction of Sprites.SIZE above the head (screen-up lift; clears the
  // head at any camera pitch — see Actors.drawBadges)
  public static inline var BADGE_LIFT = 0.65;
  // chat bubbles anchor their tail this fraction of Sprites.SIZE above the head (same screen-up
  // lift as the badges, but clear of them — see Actors.drawBubble)
  public static inline var BUBBLE_LIFT = 0.95;

  // chat-mode talking bubbles (render.actors.ChatConvo): the ... bubbles alternating over the two
  // conversers; turn/jump timing in BASE_MS multiples, hop height in screen px
  public static var CHAT_BUBBLE = {
    turnMin: 8.0,        // shortest speaker turn before handing off (BASE_MS multiples)
    turnVar: 8.0,        // random extra turn length (BASE_MS multiples); turn = [turnMin .. turnMin+turnVar]
    jumpMult: 2.0,       // the bubble hops during this final window of the turn (BASE_MS multiples)
    hops: 2.0,           // number of little hops in that window
    jumpPx: 5.0,         // hop height in screen px
  };

  // static wall decals (graffiti/posters/cracks): % of bare (worn) building faces that get one,
  // deterministic per col/row/dir hash (no rng -> stable across reloads, not saved)
  public static inline var WALLDECAL_PCT = 35;
  // wall-decal albedo tint — the vertical twin of DECAL.debrisMul above. Poster/graffiti art is
  // authored at paper-and-paint values while every wall texture is authored dark for the night
  // palette (worn walls measure ~28-48 mean luma, poster-2 ~98), so an untinted decal reads as lit
  // from nowhere. 0x8c8c8c is ~0.55 in sRGB and is colour-managed to linear exactly like the map, so
  // it lands about where debrisMul puts the street trash. cracks are already dark enough and stay
  // untinted (see WallDecals.cats)
  public static inline var WALLDECAL_TINT = 0x8c8c8c;

  public static inline var BASE_MS = 150;          // base one-turn anim duration; all anims are multiples of it
  public static var ANIM_SPEED = 1.0;              // global anim-speed multiplier (future options: 0.5/1/1.5); bullets etc. bypass and use raw dt

  // texture paths, grouped by role; arrays indexed by facade variant [concrete, brick]
  // normal-map influence on loaded glb props: the maps are baked for hi-poly + have no tangents, and
  // we decimate hard, so full strength lights faces that turn away. 0 = ignore (flat geo normals),
  // 1 = full. tune down until the artifact clears
  public static inline var MODEL_NORMAL_SCALE = 1.0;
  // DEBUG toggle: recompute smooth vertex normals on loaded glb props. meshopt-decimated meshes keep
  // hi-poly vertex normals that light faces turning away (shading artifacts); recomputing smooths
  // them (fixes the artifact but loses hard-edge detail). true = smooth, false = keep authored normals
  public static inline var MODEL_SMOOTH_NORMALS = false;
  // anisotropic filtering on a loaded glb's textures. GLTFLoader leaves every texture it makes at 1,
  // while render.Textures.loadTexture sets 4 on everything the game loads BY HAND — so the ground,
  // the walkway and the grass sprite were filtered and every PROP was not. Anisotropy 1 blurs hardest
  // at grazing angles, which from a camera 18-55 units up is a tree's flank and a bush's top, i.e.
  // most of what a prop shows. 4 to match Textures, so a prop and the ground it stands on sample alike
  public static inline var MODEL_ANISO = 4;
  // baked glb props (make models -> app/models/), loaded via render.Models
  public static final MODELS = {
    streetLamp: 'models/street-lamp.glb',
    streetLamp2: 'models/street-lamp2.glb', // PBR variant (base + normal + metallic-roughness maps)
    sewerExit: 'models/sewer/exit.glb',     // the sewer/habitat exit ladder (render.world.ObjModels)
    // tunnel clutter, scattered against the walls by render.sewer.SewerProps. everything under
    // sewer/ is ONE simple object per glb — a composite comes back with an atlas that cannot be
    // decimated (see docs/3d-models.md), which is why the sewer-pile-1 rubble-and-pipe heap and the
    // sewer-pile-2 sack-and-crate heap are both gone, split into the simple objects they were made of
    sewerDrum: 'models/sewer/drum.glb',     // 200L steel drum, upright
    sewerCrates: 'models/sewer/crates.glb', // two solid-walled plastic stacking crates
    sewerCable: 'models/sewer/cable.glb',   // heavy industrial cable coiled flat
    sewerBags: 'models/sewer/bags.glb',     // three tied refuse sacks heaped together
    sewerBlock: 'models/sewer/block.glb',   // broken half of a hollow concrete block, rebar stub
    sewerBricks: 'models/sewer/bricks.glb', // low heap of broken bricks and concrete fragments
    sewerPipe: 'models/sewer/pipe.glb',     // short broken section of concrete sewer pipe, on its side
    // wilderness scatter, placed off the area's own tile grid by render.wild.WildProps. FOUR trees,
    // one per tile ID the 2D generator rolls (Const.TILE_TREE1 + 0..3), so the variant already written
    // into the saved grid picks the model. every one of them is HAND-MODELLED in models-src/wild
    // (*_build.py) except the bramble, which is still the TRELLIS bake — see the models.json notes
    wildTreeBroadleaf: 'models/wild/tree-bare-hand.glb',          // bare broadleaf, thick forked limbs, no foliage
    wildTreeDead: 'models/wild/tree-dead-hand.glb',               // dead snag, ragged top, broken bare limbs
    wildRockBoulder: 'models/wild/rock-boulder-hand.glb',         // low weathered boulder, chipped facets
    wildRockCluster: 'models/wild/rock-cluster-hand.glb',         // three angular slabs fused into one mass
    wildBushBramble: 'models/wild/bush-bramble.glb',              // low sprawling bramble, interlocking thorny canes
    // the planting, shared by the wilderness scatter and the facility's park
    // (render.facility.FacilityGround.GREEN): the conifer as five lobed skirts over a bole, and the
    // shrub dealt out into two silhouettes
    wildTreeConiferHand: 'models/wild/tree-conifer-hand.glb',     // lobed conifer, 824 tris against 4,880
    wildTreeBroadleafHand: 'models/wild/tree-broadleaf-hand.glb', // broadleaf, one deep lobed crown, 800 against 4,866
    wildBushDomeHand: 'models/wild/bush-dome-hand.glb',           // shrub dome, one lathe plus an off-centre crown
    wildBushUprightHand: 'models/wild/bush-upright-hand.glb',     // upright shrub, three canes each with a crown
    // the two BAND props: what a TILE_ROCK cell means in the forest and in the mountains respectively
    // (render.wild.WildBand), where plains keeps the two rocks above
    wildLogFallen: 'models/wild/log-fallen-hand.glb',             // fallen trunk, broken at both ends, one stub
    wildRockOutcrop: 'models/wild/rock-outcrop-hand.glb',         // low wedge of stacked tilted bedrock
    // the one wilderness prop that is not per-cell: one of these covers the 2x2 Const.TILE_ROCK_LARGE
    // rect it is placed on (render.wild.WildProps.bigRocks)
    wildRockLarge: 'models/wild/rock-large-hand.glb',             // 2x2 boulder, domed mass with a shoulder
    // the facility compound's own lamp, instanced along the walkway kerb, the lot edge and the park
    // path (render.facility.FacilityLamps). it carries NO emissive map where the two street lamps
    // above both do — the glowing head is an additive quad in the area's merged glow mesh instead
    facilityLamp: 'models/facility/lamp-post.glb',        // modern slim mast, shrouded downlight head
    // the compound's park bench, one per unwalkable grass cell beside the park path. the second prop
    // in the game with an AUTHORED FRONT after the guard rail: its yaw is turned at the path, never
    // random (render.facility.FacilityGround.facing)
    facilityBenchPark: 'models/facility/bench-park.glb',  // slatted seat and back on cast-steel ends
    // and the same bench hand-modelled (models-src/facility/bench_build.py), 1,660 tris against
    // 3,650 — five seat slats and four back slats, the count the generated one's reference asked
    // for, with the gaps as real gaps rather than as something a bake had to resolve, and all nine
    // placed by ARC LENGTH on one lumbar curve rather than square to a flat seat
    facilityBenchParkHand: 'models/facility/bench-park-hand.glb', // same slats, stated not segmented
    // the railing round the OUTSIDE of the park — never along the path through it. the second prop in
    // the game sized to TILE after the guard rail: FacilityStyle.FENCE_H is derived from its own
    // aspect so one segment draws exactly a cell wide and a run meets end to end
    facilityFence: 'models/facility/fence-park.glb',      // flat-topped steel railing, one cell long
    // and the same railing hand-modelled (models-src/facility/fence_build.py), 564 tris against
    // 5,056 — two end posts, two rails and eleven balusters, built at LEN 4.0 by LEN / FENCE_ASPECT
    // so the segment is exactly a cell wide and a run still meets end to end
    facilityFenceHand: 'models/facility/fence-park-hand.glb', // boxes, because a railing is a RHYTHM
    // the park litter bin, one beside every bench. it is placed off the BENCH and not off a tile of
    // its own, so it needs no generator change and is retroactive to every saved compound
    // (render.facility.FacilityGround.bins)
    facilityBin: 'models/facility/trash-bin.glb',         // solid-walled steel bin, domed lid, side mouth
    // and the same bin hand-modelled (models-src/facility/bin_build.py), 504 tris against 4,765 — a
    // sixteen-sided lathe with a rolled foot and a rolled rim, wearing a FLAT UNROLLED WRAP whose
    // painted aperture the seam lands on local +Z. FacilityStyle.BIN_BLENDER picks between the pair
    facilityBinHand: 'models/facility/trash-bin-hand.glb', // same can, cell of a sheet not a bake
    // the cars parked in the lot, in the bays nearest the gate (render.facility.FacilityCars). the
    // one prop in the compound the silhouette-vs-surface test says yes to outright — a car is nothing
    // but its outline, where the booth and the barrier beside it are boxes and a stripe pattern
    facilityCar: 'models/facility/car.glb',               // modern compact hatchback, four wheels, dark glass
    // a military base's hardware, parked on the footprints gen.military.MilitaryGen stamps
    // (render.military.MilitaryVehicles)
    militaryTank: 'models/military/tank.glb',             // main battle tank, along local z
    militaryHumvee: 'models/military/humvee.glb',         // light utility 4x4, along local x
    militaryHeli: 'models/military/heli.glb',             // utility helicopter, four-blade rotor
    militaryPlane: 'models/military/plane.glb',           // high-wing twin-jet transport, span along local z
    // and its hand-modelled kit (models-src/military/basekit_build.py)
    militarySandbag: 'models/military/sandbag-hand.glb',  // one bag, long axis local x, one course high
    militaryMast: 'models/military/mast-hand.glb',        // floodlight mast on the facility lamp's head contract
    militaryDrum: 'models/military/drum-hand.glb',        // fuel drum, lid up
    militaryCrate: 'models/military/crate-hand.glb',      // ammo crate, long axis local x, lid and battens on top
    militaryContainer: 'models/military/container-hand.glb', // 20 ft container, long axis local x, door at -x
    militaryWaterTank: 'models/military/water-tank-hand.glb', // roof water tank on its legs
    // the roofs' own kit (models-src/military/roofkit_build.py), on FacilityRoof's spots and batches
    militaryRoofHatch: 'models/military/roof-hatch-hand.glb', // access hatch, hinges at local +z
    militaryRoofJbox: 'models/military/roof-jbox-hand.glb',   // isolator on struts, door to local -z
    militaryRoofVent: 'models/military/roof-vent-hand.glb',   // mushroom extract vent
    militaryRoofDuct: 'models/military/roof-duct-hand.glb',   // one cell of round duct along local x
    militaryRoofAerial: 'models/military/roof-aerial-hand.glb', // lattice aerial mast on the dish spot
    // the rooms' hand-modelled kit (models-src/military/roomkit_build.py), each facing local +z
    militaryRadioRack: 'models/military/radio-rack-hand.glb', // comms rack, four radio units proud of its front
    militaryRadioDesk: 'models/military/radio-desk-hand.glb', // operator desk, one cell long, pedestal at local -x
    militaryRadioBig: 'models/military/radio-big-hand.glb',   // field transceiver, carry handle on top
    militaryRadioSmall: 'models/military/radio-small-hand.glb', // keypad radio set, handset on top
    militaryBunk: 'models/military/bunk-hand.glb',        // two-deck bunk, two cells along local x, head at -x
    militaryCot: 'models/military/cot-hand.glb',          // camp cot along local x, pillow at -x
    militaryFootlocker: 'models/military/footlocker-hand.glb', // plank trunk, long axis x, hasp at +z
    militaryOfficeDesk: 'models/military/office-desk-hand.glb', // office desk, one cell long, pedestal at -x
    militaryFileCabinet: 'models/military/file-cabinet-hand.glb', // two-drawer filing cabinet
    militaryChair: 'models/military/chair-hand.glb',      // folding chair, the sitter facing +z
    militaryShelf: 'models/military/shelf-unit-hand.glb', // store shelf unit with its cartons
    militaryMedCabinet: 'models/military/medcab-hand.glb', // white medical cabinet
    militaryMessTable: 'models/military/mess-table-hand.glb', // one cell of mess table along x
    militaryBriefTable: 'models/military/brief-table-hand.glb', // the same in darkwood
    militaryBench: 'models/military/bench-hand.glb',      // one cell of bench along x
    militaryCounter: 'models/military/counter-hand.glb',  // one cell of serving counter, pans at the top
    militaryCounter2: 'models/military/counter2-hand.glb', // and its other two pans
    militaryAmmoCans: 'models/military/ammo-cans-hand.glb', // stack of five ammo cans
    militaryJerrycans: 'models/military/jerrycans-hand.glb', // three jerrycans and one across them
    militaryFlag: 'models/military/flag-stand-hand.glb',  // flag stand, the flag facing +z
    militaryWaterCooler: 'models/military/water-cooler-hand.glb', // water cooler, its tap at +z
    militaryIvStand: 'models/military/iv-stand-hand.glb', // IV stand with its bag
    militaryStretcher: 'models/military/stretcher-hand.glb', // stretcher on two trestles along x, head at -x
    militarySink: 'models/military/sink-hand.glb',        // latrine pedestal basin, its tap at the back (-z)
    militaryToilet: 'models/military/toilet-hand.glb',    // latrine toilet, the bowl at +z, cistern at -z
    militaryUrinal: 'models/military/urinal-hand.glb',    // latrine urinal, wall-hung, its screen on the floor
    militaryShower: 'models/military/shower-hand.glb',    // latrine shower, riser and rose, the grate under it
    militaryLocker: 'models/military/locker-hand.glb',    // armory locker bank, one cell wide, doors at +z
    militaryGunCabinet: 'models/military/gun-cabinet-hand.glb', // gun cabinet, doors at +z
    militarySafe: 'models/military/safe-hand.glb',        // the HQ safe, its door at +z
    militaryBoots: 'models/military/boots-hand.glb',      // a pair of combat boots, toes at -x
    militaryCanteen: 'models/military/canteen-hand.glb',  // a canteen in its cover, upright, flanks at +-z
    militaryRucksack: 'models/military/rucksack-hand.glb', // a rucksack standing, its front at +z
    // what stands on a lab building's roof, inside its parapet (render.facility.FacilityRoof). the
    // ACCESS HATCH standing beside them is not here and never will be: it is a box, so it is merged
    // geometry, the same call the guard booth's rebuild settled
    // the hangar's study podium: a two-step dais with a ring of eight emitters, hand-modelled at
    // 540 tris because the generator had already fixed every number in it — the pad it stands on is
    // carved PAD_SZ cells square and the machine banks are placed off its edge. It is the one prop
    // in the compound the cable service runs TO rather than from
    facilityHangarPodium: 'models/facility/hangar-podium.glb',
    facilityRoofAc: 'models/facility/roof-ac.glb',        // rooftop condenser, fan guard on the lid, coil louvres
    facilityRoofDish: 'models/facility/roof-dish.glb',    // comms dish on a solid pedestal, feed horn on one arm
    // and the hand-modelled pair that replaces those two behind FacilityStyle.ROOF_BLENDER, at 660
    // and 948 tris against 5,619 and 5,800. Both are built AT the world size the batch draws them
    // at: the condenser's fan well is a real cowl with the guard set down inside it, and the dish is
    // a paraboloid at a stated focal ratio with its horn standing at the focus
    facilityRoofAcHand: 'models/facility/roof-ac-hand.glb',
    facilityRoofDishHand: 'models/facility/roof-dish-hand.glb',
    // and the two SERVICE boxes, which used to be merged quads and are behind the same flag. They
    // are a box each and they went to Blender anyway, because the thing they were reported for was
    // the ART: merged geometry takes a TILING texture on a world-aligned UV, and a tread-plate lid
    // and a louvred door are both a picture that has to map 0..1 onto one face
    facilityRoofHatchHand: 'models/facility/roof-hatch-hand.glb',
    facilityRoofJboxHand: 'models/facility/roof-jbox-hand.glb',
    // and the SERVICE KIT, three families off one sheet (models-src/facility/roofsvc_build.py) at
    // 172 / 220 / 236 tris. The duct is the odd one: it is built exactly ONE CELL long, so a run is
    // N placements on neighbouring cell centres rather than a swept mesh, and it abuts seamlessly
    // because render.Models.instanced scales by height alone and the segment is built at its own
    facilityRoofVentHand: 'models/facility/roof-vent-hand.glb',
    facilityRoofDuctHand: 'models/facility/roof-duct-hand.glb',
    facilityRoofTankHand: 'models/facility/roof-tank-hand.glb',
    // the junk standing about in the parking lot (render.facility.FacilityDebris), which scatters
    // flat litter decals over the same asphalt. all three are DROPPED objects and take a free turn,
    // unlike the parked cars and the roof condensers above; all three are carried by their outline
    // and none of them is a box, which is what the emit-it test in FacilityEntry's header asks
    facilityLotCone: 'models/facility/lot-cone.glb',      // traffic cone, weighted square base, one collar
    facilityLotTyres: 'models/facility/lot-tyres.glb',    // three worn car tyres stacked flat, no rims
    facilityLotReel: 'models/facility/lot-reel.glb',      // empty steel cable reel standing on its flanges
    // and the two of those three that are hand-modelled (models-src/facility/lot_build.py), 360 and
    // 676 tris against 4,798 and 4,960. FacilityStyle.LOT_BLENDER picks between the pairs. The TYRE
    // STACK has no hand row and never will — it is the one prop in the compound that passes its own
    // propstat gate, and a stack of holed toroids is not a shape a lathe states
    facilityLotConeHand: 'models/facility/lot-cone-hand.glb', // shell as a wrap, slab as a base
    facilityLotReelHand: 'models/facility/lot-reel-hand.glb', // ONE lathe: flanges, barrel, rib, hub
    // the lab kit standing INDOORS, against the room walls (render.facility.FacilityKit) — the first
    // two glb props in the compound that are not outdoors. both earn a glb on the same test the
    // corridor's casework fails: a rack of domed bottles and an open wheeled frame are silhouette,
    // where a cabinet run is a box and is merged geometry
    facilityKitGas: 'models/facility/gas-cylinders.glb',  // four-bottle cylinder rack, strap rail, foot rail
    facilityKitTrolley: 'models/facility/lab-trolley-hand.glb', // two trays, tube frame, castors
    // the three hazard barrels standing on a LOW decoration cell (render.facility.FacilityDeco).
    // ONE MESH, THREE PAINTS — all three are art/models.json labels over the tunnels' own
    // sewer/drum.glb source, recoloured by tools/livery.py, so they cost three batches and no new
    // geometry. They are separate paths because a batch is keyed by path and carries no
    // per-instance UV offset, which is the whole reason a livery costs a draw call
    facilityDrumSteel: 'models/facility/drum-steel.glb', // grey drum, clean steel, hoop ribs
    facilityDrumBio: 'models/facility/drum-bio.glb',     // yellow drum, biohazard livery
    facilityDrumRad: 'models/facility/drum-rad.glb',     // red drum, radioactive livery
    // and the same four ROUND props hand-modelled instead of generated — a twelve-sided can and four
    // eight-sided bottles in an angle-iron frame, wearing a pack4 of flat UNROLLED cylinder wraps
    // rather than a bake (models-src/facility/drum_build.py). FacilityStyle.DECO_DRUM_BLENDER picks
    // between the pairs; no draw call is at stake here, only triangles and control of the palette
    facilityDrumSteelHand: 'models/facility/drum-steel-hand.glb', // 44 tris against 1,200
    facilityDrumBioHand: 'models/facility/drum-bio-hand.glb',     // same can, yellow cell
    facilityDrumRadHand: 'models/facility/drum-rad-hand.glb',     // same can, orange-red cell
    facilityGasHand: 'models/facility/gas-rack-hand.glb',         // 284 tris against 5,710
    // the four things that stand ON the researcher's desk, all off one pack4 and all NEW — nothing
    // was there before but the three machines (models-src/facility/desk_build.py). Placed by
    // render.facility.FacilityWork.trinket, two per desk
    facilityDeskMug: 'models/facility/desk-mug.glb',           // cup, 28 tris
    facilityDeskPlant: 'models/facility/desk-plant.glb',       // pot and a leaf cone, 56
    facilityDeskLamp: 'models/facility/desk-lamp.glb',         // foot, stem, shade, 52
    facilityDeskTray: 'models/facility/desk-tray.glb',         // a sheaf and a folder, 24
    // and TWO MORE GLAZES OF THE SAME CUP, which is what a mug on a desk that is somebody's needs:
    // one model dealt to every desk in the compound reads as issue kit whatever its frequency. Three
    // LABELS OFF ONE MESH exactly as the three hazard barrels are — art/models.json gives each its own
    // baseColor tint and sat over the same desk-mug.glb, so the variety costs no art and no
    // triangles. It does cost a batch each (render.Models.instanced is keyed by path and carries no
    // per-instance colour), which is the same price the drums pay for the same thing
    facilityDeskMugB: 'models/facility/desk-mug-b.glb',        // the same cup, grey-blue
    facilityDeskMugC: 'models/facility/desk-mug-c.glb',        // the same cup, warm brown
    // and the stack of logbooks beside them, off the JANITOR pack rather than the desk one — it
    // shares its binding cloth and its page edges with nothing on that sheet
    facilityDeskJournals: 'models/facility/desk-journals.glb', // four hardbacks, 48 tris
    // the two things a cleaner leaves in a corridor or a washroom (models-src/facility/janitor_build.py).
    // render-only and unstamped, the litter bin's own contract — see render.facility.FacilityJanitor
    facilityBroom: 'models/facility/janitor-broom.glb',        // leaning, 52 tris
    facilityBucket: 'models/facility/janitor-bucket.glb',      // a vessel with a bail, 300
    // the ROOM TEMPLATE props. A WC pan is a curved shell with a cistern behind it and a chair is a
    // shaped back over a five-star base on castors: both are silhouettes no axis-aligned quad states,
    // which is what earns a mesh generator
    facilityToilet: 'models/facility/toilet.glb',        // WC pan, closed cistern, lid down
    facilityChair: 'models/facility/chair.glb',          // office swivel chair, arms, star base
    // and the same two hand-modelled (models-src/facility/toilet_build.py, chair_build.py), 692 and
    // 1,072 tris against 4,068 and 2,930. THE PAN IS BUILT TO TOILET_D AND THE BAKE WAS NOT: 1.4 is
    // what FacilityDeco.toilets stands it off the cubicle wall by, and the generated mesh is 0.954
    // deep at TOILET_H, so the shipped pan floats 0.22 off the masonry. The chair is the closest
    // call of the eleven — CHAIR_H's own note argues it is the case FOR a generator — but five arms
    // at 72 degrees is a loop index, and the bake was a REJECT at 9 components / 61.8% anyway
    facilityToiletHand: 'models/facility/toilet-hand.glb',  // open bowl, seat ring, 692 tris
    // THE CORP TOWER'S SEVEN (render.corp.CorpProps). Five of them are hand-modelled, which is the
    // opposite balance to the compound's and is not a change of policy: every brief on this floor
    // plate is a NUMBER off CorpStyle — a chair that has to sit at DESK_H, a monitor that has to
    // stand on it, a pan built to WC_D so its cistern meets the divider. The plant is the one shape
    // no lathe states, and the cooler and the printer are stepped bodies, i.e. silhouette
    corpChair: 'models/corp/chair.glb',        // task chair, split back, five-star base, 1,344 tris
    corpMonitor: 'models/corp/monitor.glb',    // 16:9 panel on a stainless stem, 268
    corpKeyboard: 'models/corp/keyboard.glb',  // a wedge, 44
    corpWc: 'models/corp/wc.glb',              // open bowl, water at the profile's own cap, 652
    corpPlant: 'models/corp/plant.glb',        // potted ficus, TRELLIS, the one generated silhouette
    corpCooler: 'models/corp/cooler.glb',      // water cooler, bottle on a lacquer cabinet
    corpPrinter: 'models/corp/printer.glb',    // multifunction copier, drawer pedestal, amber panel
    corpDesk: 'models/corp/desk-bench.glb',    // bench desk: thin top, O-leg frame, pedestal, 96 tris
    corpTableLeg: 'models/corp/table-leg.glb', // the blade leg under a boardroom slab, 36 tris
    corpBin: 'models/corp/bin.glb',            // the waste bin, a 12-sided lathe, the one round piece
    // the casework credenza, which used to be render.corp.CorpDeco.box — a plain slab with the
    // OFFICE DESK LAMINATE on its lid, reported by probing a face at local y 1.3 (exactly
    // CorpDeco.CASE[K_CABINET][2]). Its height was then fixed TO the drawer art, 1.30 -> 2.00, so
    // two full-width courses land with no stretch; see art/models.json's note
    corpCase: 'models/corp/case-cabinet.glb',  // carcass, two proud drawers, brass label holders, 324
    corpGunCabinet: 'models/corp/gun-cabinet.glb',            // security room, shut, 108
    corpGunCabinetOpen: 'models/corp/gun-cabinet-open.glb',   // and open, leaf swung, 264
    corpStairs: 'models/corp/stairs.glb',                     // switchback over two cells, 924
    corpWallCam: 'models/corp/wall-cam.glb',                  // plate, arm, pitched bullet head, 124
    // AND THE RECORDS ROOM'S TWO, which stand in the ranks gen.corp.CorpRooms.archive lays and are
    // dealt one per rank (render.corp.CorpFurniture.archive). Both are glbs for the reason the
    // credenza is: a drawer standing proud of a carcass and a board standing proud of the binders
    // behind it are the one thing a flat face cannot have. Both sizes came off the ART -- the
    // drawer course's aspect and the spine sheet's bay -- so neither number was chosen; see
    // art/models.json
    corpArchCase: 'models/corp/arch-cabinet.glb',   // four-drawer lateral file, 2.70 x 3.60, 156 tris
    corpArchShelf: 'models/corp/arch-shelf.glb',    // six shelves of box files, 3.20 x 4.80, 168
    // AND THE FOUR DESK-CLUTTER CELLS THAT ARE PROPS (render.corp.CorpClutter). corp/desk-clutter
    // is a PACK64 of flat cut-outs and that is the right route for a sheet of paper or a folder;
    // it fails on a cell whose read is a ROUND or UPRIGHT silhouette, which no top-down art can
    // give a side to. These four were reported cell by cell from the game
    corpDeskMug: 'models/corp/desk-mug.glb',        // a vessel lathe with a swept handle, 220 tris
    corpDeskBottle: 'models/corp/desk-bottle.glb',  // shouldered steel, charcoal cap, 184
    corpDeskPlant: 'models/corp/desk-plant.glb',    // pot, soil cap, six pitched leaves, 280
    corpDeskCam: 'models/corp/desk-cam.glb',        // puck, stalk, lens head with an amber ring, 120
    // AND THE EXEC OFFICE'S SEVEN (render.corp.CorpExec, models-src/corp/exec_build.py), all one
    // sheet packed off the exec pack4's built labels. The desk comes in three footprints because a
    // footprint is the generator's cells and a glb cannot be stretched to one
    corpExecDesk: 'models/corp/exec-desk.glb',          // 3x2 pedestal desk, leather inlay, 516
    corpExecDesk3: 'models/corp/exec-desk-3.glb',       // the 3-cell run, 516
    corpExecDesk2: 'models/corp/exec-desk-2.glb',       // the 2-cell run, 516
    corpExecChair: 'models/corp/exec-chair.glb',        // high-backed leather swivel, 1,380
    corpExecArmchair: 'models/corp/exec-armchair.glb',  // club chair, lounge and visitor, 552
    corpExecSofa: 'models/corp/exec-sofa.glb',          // two-cell chesterfield, 768
    corpExecTableLow: 'models/corp/exec-table-low.glb', // walnut on brass legs, 168
    corpExecPlaque: 'models/corp/exec-plaque.glb',      // brass nameplate on walnut, 24
    corpExecPhoto: 'models/corp/exec-photo.glb',        // brass frame on an easel, 80
    // the reception counter's three trinkets (models-src/corp/reception_build.py)
    corpRecPhone: 'models/corp/rec-phone.glb',          // base, cradle, handset, key pad, 48
    corpRecBoard: 'models/corp/rec-board.glb',          // WELCOME on a brass foot, 44
    corpRecBell: 'models/corp/rec-bell.glb',            // base, brass dome, plunger, 248
    // AND THE STAFF KITCHEN'S ELEVEN (render.corp.CorpKitchen, models-src/corp/kitchen_build.py),
    // on five sheets packed off built labels. The fridge and the vending machine were
    // render.corp.CorpDeco.box, casework wearing the office desk's laminate
    corpKitchenTable: 'models/corp/kitchen-table.glb',       // beech on four steel legs, 376
    corpKitchenChair: 'models/corp/kitchen-chair.glb',       // terracotta shell, four legs, 412
    corpKitchenCounter: 'models/corp/kitchen-counter.glb',   // one cell of base unit, 452
    corpVanity: 'models/corp/vanity.glb',                    // washroom basin cell, glazed bowl, 896
    corpKitchenSink: 'models/corp/kitchen-sink.glb',         // the unit with bowl and tap, 884
    corpKitchenCab: 'models/corp/kitchen-wall-cab.glb',      // the wall cabinet over it, 336
    corpKitchenFridge: 'models/corp/kitchen-fridge.glb',     // fridge-freezer with notes, 552
    corpKitchenVending: 'models/corp/kitchen-vending.glb',   // lit snack machine, emissive, 216
    corpKitchenMicrowave: 'models/corp/kitchen-microwave.glb', // 192
    corpKitchenCoffee: 'models/corp/kitchen-coffee.glb',     // bean-to-cup, 256
    corpKitchenKettle: 'models/corp/kitchen-kettle.glb',     // 344
    corpKitchenToaster: 'models/corp/kitchen-toaster.glb',   // 220
    facilityChairHand: 'models/facility/chair-hand.glb',    // split back, star base, 1,072
    // and the workstation on the desk in front of that chair, which is the one family here to have
    // been a glb, then emitted quads, and now a glb again — for a different reason each time. The
    // GENERATED facility/computer.glb died correctly: 1,200 triangles rounding the corners off three
    // slabs, reported as blocky. The 22 emitted quads that replaced it were right about the
    // proportions and could state no silhouette at all. These three are HAND-MODELLED IN BLENDER
    // (models-src/facility/computer_build.py) on the same FacilityStyle numbers, at 268/116/44 tris,
    // and they wear the game's OWN facility/workstation sheet rather than a bake — so the screen
    // tilts, the tower's front panel is recessed and the keyboard is a wedge, which is what the
    // quads could not do. THREE PATHS AND NOT ONE PROP: the tower stands on a hand rolled per desk
    // (WorkSpot.side), so a fused set could only ever stand on one of them
    facilityMonitor: 'models/facility/computer-monitor.glb',   // screen on a tapered neck, tilted 8° back
    facilityTower: 'models/facility/computer-tower.glb',       // desktop case on end, front panel recessed
    facilityKeyboard: 'models/facility/computer-keyboard.glb', // keyboard wedge, front lip low
    // the server rack, the first of the room FITTINGS down that same route
    // (models-src/facility/rack_build.py, 156 tris). It does NOT replace the four quads
    // render.facility.FacilityDeco still emits — FacilityStyle.DECO_RACK_GLB picks between them and
    // both ship, because a fitting on a wall is exactly the axis-aligned slab the triage says to
    // EMIT and the only way to settle that is to measure both in the same frame
    facilityRack: 'models/facility/deco-rack.glb',             // six chassis in a skirted frame
    // and the one-tile cabinet, which is a SECOND MESH and not the first one scaled. DECO_RACK_LOW_H
    // is DECO_RACK_TILE, i.e. exactly three chassis, and FacilityDeco.lights deals its status specks
    // off that same arithmetic — Models.instanced scales by HEIGHT alone, so the six-chassis mesh
    // drawn at the low height gave six squashed units under three rows of lights
    facilityRackLow: 'models/facility/deco-rack-low.glb',      // three of them, same frame
    // and the storage cabinet, same switch and same argument: three labels emitted is three calls,
    // one packed sheet is one. Its shape claim is smaller than the rack's — two proud door LEAVES,
    // for a reveal at their edges and a toe kick under them (models-src/facility/cabinet_build.py)
    facilityCabinet: 'models/facility/deco-cabinet.glb',       // double-door case, leaves proud
    // and the lab machine, ONE mesh for both of its heights — DECO_MACHINE_LOW_SZ is not a count of
    // anything, the unit is a cube at either size and `machLights` reads fractions, so scaling by
    // height (which is all Models.instanced does) is exactly right here and was wrong for the rack
    facilityMachine: 'models/facility/deco-machine.glb',       // three bands, louvre panel set back
    facilityAnalyser: 'models/facility/deco-analyser.glb',     // the tall one: sloped console on top
    // and the bookcase, whose whole read at this camera is that the BOARDS stand in front of the
    // spines — four proud boxes running between the stiles (models-src/facility/bookcase_build.py)
    facilityBookcase: 'models/facility/deco-bookcase.glb',     // four boards, books behind them
    // and the open shelving, the strongest shape claim of the lot: the quads it replaces are two
    // alpha-cut PANES standing in for end frames, i.e. a cut-out drawing of a frame with
    // zero-thickness shelves between them (models-src/facility/store_build.py, one sheet with the
    // trolley, and neither of them a pixel of new art)
    facilityShelving: 'models/facility/deco-shelving.glb',     // four uprights, rails, three plates
    // and the washroom counter, whose bowl is a real RECESS and whose tap is two boxes — which
    // between them retire the family's only alpha-cut mesh (models-src/facility/basin_build.py)
    facilityBasin: 'models/facility/deco-basin.glb',           // counter, sunk bowl, mixer tap
    // and the lounge's pair, the first two here that never had an emitted version to convert: what
    // earns a sofa a mesh is the notch its arms and back cut out of a rectangle, and a low table is
    // one the camera sees THROUGH (models-src/facility/lounge_build.py, one sheet between them)
    facilitySofa: 'models/facility/deco-sofa.glb',             // two-seater, arms, dark plinth
    facilityTableLow: 'models/facility/deco-table-low.glb',    // slab on four legs, seen through
    // and the STORE ROOM's three (models-src/facility/storerack_build.py), glbs only like the
    // lounge pair above: none of them had an emitted version, because none of them is a box —
    // racking is mostly the air between its members, and a pallet is read by the slot of shadow
    // under it
    facilityPalletRack: 'models/facility/deco-pallet-rack.glb',   // two bays, three beam levels
    facilityPalletStack: 'models/facility/deco-pallet-stack.glb', // wrapped cartons on a pallet
    facilityDrumPallet: 'models/facility/deco-drum-pallet.glb',   // four drums on a pallet
    facilityGenerator: 'models/facility/deco-generator.glb',      // the hangar's olive genset
    // and the parking entry's checkpoint, which is here for the THIRD time and by a different route
    // each time. Generated it was a 40-component bake with the hazard bands merged to orange on tan;
    // emitted it was 56 triangles of quad with no arris on it anywhere; these are hand-modelled to
    // FacilityStyle's own numbers (models-src/facility/entry_build.py) and switched by
    // FacilityStyle.ENTRY_BLENDER, with the emitted pair still shipping behind that flag. The BOOM
    // is the one mesh in the compound whose LENGTH is load-bearing — see that script's header
    facilityBarrier: 'models/facility/barrier-hand.glb',       // cabinet, boom, splice collar, tip lamp
    facilityBooth: 'models/facility/booth-hand.glb',           // kiosk shell, sill and head reveals, aerial
    // the only wilderness prop with an AUTHORED FRONT: it lines the highway shoulder, so its yaw is
    // locked to the corridor axis where every other row out there takes a full random turn
    wildGuardRail: 'models/wild/guard-rail-hand.glb',             // W-beam on two posts, hand-modelled, one cell long
    // the habitat's four grown objects, standing in for their atlas sprites. unlike the clutter above
    // each of these HAS an AreaObject behind it, so they go through render.world.ObjModels and carry
    // the full solid / ghost / outline-hull set rather than one decoration batch
    habitatBiomineral: 'models/habitat/biomineral.glb',     // crystal spire in a slime mound
    habitatAssimilation: 'models/habitat/assimilation.glb', // braided tentacle arch with a maw
    habitatPreservator: 'models/habitat/preservator.glb',   // amber pod caged in veins
    habitatWatcher: 'models/habitat/watcher.glb',           // eye-studded mass ringed by tendrils
    // the alien ship of the crash-landing scenario, which goes through render.world.ObjModels for
    // the same reason the four organs above do: it has an objects.EventObject behind it, so it
    // carries the full solid / ghost / outline-hull set. supplied as a 584k-tri master and decimated
    // by the pipeline — see its art/models.json note for why tex is 1024 and why it carries no
    // baseColor
    scenarioSpaceship: 'models/scenario-a/spaceship.glb',   // saucer, lit panels and lamp discs
    // and the rig round it, hand-modelled to three silhouettes that cannot be confused with each
    // other or with the machine banks already standing in the same shed
    // (models-src/scenario-a/scenario_build.py)
    scenarioCase: 'models/scenario-a/case.glb',             // orange transport case, overhanging lid
    scenarioConsole: 'models/scenario-a/console.glb',       // lectern: column and a canted head
    scenarioSlot: 'models/scenario-a/slot.glb',             // receptacle, socket plate facing up
  };
  // a prop the player is STANDING on fades see-through, so its body does not hide the sprite. one
  // InstancedMesh carries one material, so the fade is a second (ghost) batch over the same placements
  // with a per-frame mask picking which one draws each prop — render.world.ObjModels
  public static final PROP_GHOST = {
    alpha: 0.3,  // opacity at full fade (0 = invisible, 1 = solid)
    lerp: 0.25,  // per-30fps-frame ease toward the target (dt-compensated, as OCCLUSION.lerp)
    snap: 0.02,  // lock to solid within this of 0 — the handover BACK to the opaque batch is gated on
                 // it, and an exponential tail never reaches 0 on its own
  };
  // coloured point lights for the object props that glow — the habitat's grown organs. the light is
  // what makes an organ read as luminescing now: an emissive MAP only brightens the prop's own texels
  // and lights nothing around it, so the two are alternatives rather than a pair (see
  // render.world.ObjModels.MODELS `light`, and docs/3d-changes.md).
  //
  // same fixed-pool discipline as LAMP_LIGHT and FLAME: every slot exists for the whole life of the
  // scene at intensity 0 and the nearest props claim one per frame, so NUM_POINT_LIGHTS never changes
  // and no lit material ever recompiles. built ONLY into the tunnel scene (render.sewer.SewerScene) —
  // three unrolls the point-light loop into every lit material, so a slot a city could never use would
  // still cost it a full light evaluation on every lit fragment
  public static final PROP_LIGHT = {
    // live point lights, and the whole feature's on/off switch: 0 builds none, so NUM_POINT_LIGHTS
    // drops back to the flame pool's 5 and the point-light block leaves the tunnel shaders entirely.
    // an organ is a room feature and a habitat room holds ~1-3, so this is sized for what ONE room
    // shows rather than for the level (4 was the original value). each slot is a full extra light
    // evaluation in every lit fragment of the frame — the street spotlight pool measured LINEAR at
    // ~0.32ms per light on the integrated Radeon (docs/3d-render.md).
    //
    // 2 because exactly ONE prop declares a `light` now: the biomineral, which is the energy organ
    // and the one that should read as lighting its room. A habitat holds several of them (Habitat
    // .update sums energy over every formation), so a pool of 1 would light the nearest and leave
    // its neighbour dark. The other three organs' rows are `light: null` with their old colours in
    // the comment, so giving one of them a light back is an edit to that row, not to this number
    pool: 2,
    intensity: 9.0,   // base intensity, scaled per prop by its table row's `mul`
    distCells: 3.0,   // hard cutoff radius in cells. SHORT on purpose: these cast NO shadow (a point
                      // shadow is six cube faces per light), so reach is the only thing stopping an
                      // organ bleeding through a wall into the next corridor. the vision mask hides
                      // most of what still leaks — a surface the player cannot see is sunk to the fog
                      // colour whatever lit it
    decay: 1.6,       // as FLAME/LAMP: softer than physical 2.0 so the pool does not collapse to a dot
    yMul: 1.15,       // light height = the prop's OWN table height * this, so it sits just above the
                      // crown. inside the prop it would only reach backfaces and the organ itself
                      // would read dark; from just above, the near-overhead camera sees a lit crown
                      // and a coloured pool on the floor around it
    rangeCells: 9.0,  // player distance at which a prop claims a slot
    fadeMul: 1.0,     // fade in/out duration as a multiple of BASE_MS — fade, never blink
  };
  // idle motion for the grown props, folded into their own materials by render.world.PropShader: a
  // height-weighted sway that moves the geometry and a finer ripple on the shading normal that a
  // specular highlight crawls on. costs no draw call, no pass and no geometry.
  //
  // there is nothing per-prop here on purpose — amplitudes, speeds and falloffs are the `anim` column
  // of render.world.ObjModels.MODELS, so a prop's motion lives on the same row as its height, yaw and
  // light. this is only the master switch, the same role PROP_LIGHT.pool 0 plays for the point lights
  public static final PROP_ANIM = {
    enabled: true, // false stops the patch entirely, so every prop keeps the plain unanimated program
  };
  // the grown props' SURFACE glow, folded into their own materials by render.world.PropGlow: motes
  // travelling a slow helix through the body, masked to whatever the prop's own baked albedo says is
  // mineral. costs no draw call, no pass and no art; the halo is the composer's existing bloom pass
  // catching an HDR tint.
  //
  // nothing per-prop here either, for the same reason as PROP_ANIM — the mask band, the tint, the
  // mote count and every rate are the `shine` column of render.world.ObjModels.MODELS. this is only
  // the master switch, and it is also the A/B lever: false keeps every prop on the unpatched program
  public static final PROP_GLOW = {
    enabled: true,
  };
  // the grown props' living FX, drawn by render.actors.PropFX as additive quads glued to the prop: a
  // pulsing, writhing knot of innards hung inside it, and a ring of fireflies orbiting it, one per
  // habitat level. HDR-tinted, so the bloom pass is what gives them their halo.
  //
  // nothing per-prop here either, for the same reason as PROP_ANIM — sizes, speeds, colours and the
  // ring geometry are the `core` and `fly` columns of render.world.ObjModels.MODELS, so a prop's FX
  // sit on the same row as its height, yaw, light and motion. this is only the master switch
  public static final PROP_FX = {
    enabled: true, // false draws none of it, and the pools stay empty
  };
  // street-lamp SPOTLIGHT placed relative to the lamp model. the light sits at the bulb (dx/dz =
  // local horizontal offset rotated by the lamp yaw, yMul = height CELL*this) and aims at a ground
  // target offset by tdx/tdz (also local, rotated) — so the cone is a downward street pool, not an
  // omni glow on the post. angle = cone half-angle (rad), penumbra = soft edge 0..1. the RESIDENTIAL
  // defaults; the height/cone/pool are shared across all areas, but a per-area lamp MODEL overrides
  // the placement offsets (model/dx/dz/pdx/pdz) via AreaStyle.lamp (see DowntownStyle → street-lamp2)
  public static final LAMP_LIGHT = {         // residential lamp; downtown swaps via AreaStyle.lamp
    yMul: 1.4,   // light height = CityConfig.CELL * this
    dx: 0.0,     // local +X offset toward the bulb (world units)
    dz: 0.6,     // local +Z (toward-road) offset of the bulb — pushes it out over the road edge
    pdx: 2.0,    // post local +X offset from cell centre (slides along the road/wall) — CELL/2 = corner
    pdz: 2.6,    // post local +Z offset: +toward road edge, -toward the wall — CELL/2 = road/walkway edge
    angle: Math.PI / 5,  // cone half-angle (radians)
    penumbra: 0.2,       // soft-edge fraction 0..1
    tdx: 0.0,    // ground-target local +X offset (aim the pool along the street)
    tdz: 0.0,    // ground-target local +Z offset
    markerVisible: false, // draw a small red sphere at the light position (tuning aid)
    // lamps everywhere, bounded spotlight budget: only POOL live spotlights exist, following the
    // nearest lamps to the player (render.particles.LampLights); every post shows its model + cone
    // number of live SpotLights (fixed → NUM_SPOT_LIGHTS constant, no recompile). three UNROLLS this
    // loop into every lit material, so each slot is a full extra light evaluation — GGX included — on
    // every lit fragment in the frame, and it is the single most expensive thing in the street frame:
    // measured 41% of GPU on the integrated-Radeon laptop, LINEAR at ~0.32ms (~3.5% of frame) per
    // light (docs/3d-render.md). 12 is an ART value — it sets how far lamp light reaches from the
    // player, so lowering it visibly darkens the frame edge. tune for looks, not for frames; the perf
    // dial for weak GPUs is the render scale. never set BELOW shadowCasters (LampLights sizes its
    // per-slot arrays from THIS number)
    pool: 12,
    intensity: 45.0,     // live-lamp spotlight intensity
    lightRangeCells: 16, // a lamp within this many cells of the player may claim one of the pool lights
    fadeMul: 4.0,        // fade in/out duration = BASE_MS * this — ramps intensity so lamps don't blink
    // real spotlight shadows: of `pool`, this many slots cast a shadow map. FIXED (not toggled per
    // frame): castShadow is part of the material program key (NUM_SPOT_LIGHT_SHADOWS), so flipping it
    // live would trigger the very recompile the fixed pool exists to avoid. nearest lit lamps tend to
    // occupy the low-index slots (LampLights fills nearest-first), so these casters follow the player
    // live spotlights that cast real shadows (nearby buildings/objects go radial). MUST be <= pool:
    // update() walks 0...shadowCasters indexing the per-slot arrays, which are sized by pool, and at
    // 8 against a 6-slot pool it writes past the end of `lights`. not a perf knob either — ALL shadow
    // sampling (these plus the moon) measured only 12% of the GPU frame
    shadowCasters: 8,
    shadowMapSize: 512,   // per-caster shadow map edge — cone is local + small, 512 is plenty
    shadowBias: -0.0009,  // depth bias to kill acne in the cone (tune)
    shadowFadeBand: 4.0,  // cells over which a caster's shadow.intensity ramps to 0 as it nears the
                          // casting-set boundary — so a lamp crossing the boundary fades its shadow, no pop
    // failing-sodium lamps, for the ones AreaStyle.lampFlickerRatio marks (LampLights.flicker). TWO
    // gate sines ride on top of each other: a fast one breaking the lit stretches with ~1s stutter
    // bursts, and a slow one that every ~20s takes the bulb all the way out for a few seconds. so the
    // cycle reads lit ~3.5s / flicker ~1s / lit ~3.5s / flicker ~1s / ... / dead ~3s. rates are per RAW
    // ms and deliberately bypass ANIM_SPEED — a dying bulb is physical, not gameplay-paced (same call
    // as FLAME.flick*)
    flickGate: 0.000314,  // outage gate sine rate: 2*PI/this = outage period, ~20s
    flickGateOn: 0.81,    // gate value above which the outage window is open — 0.81 = 20% of the period, ~4s
    flickOutEdge: 0.4,    // how deep into that window the stutter gives way to dead black (~3.1s fully dark)
    flickBurst: 0.001396, // stutter-burst gate rate: 2*PI/this = burst period, ~4.5s
    flickBurstOn: 0.77,   // gate value above which a burst runs — 0.77 = ~1s of stutter per burst period
    flickOff: 0.05,       // below this a bulb counts as OUT: its cone stops drawing and it casts no fake shadow.
                          // a stutter burst bottoms out at ~0.27, well above it, so only the full outage kills them
    flickFastA: 0.020,    // stutter sine A — used by both the bursts and the outage ramps
    flickFastB: 0.029,    // stutter sine B — beats against A for an uneven, unrepeating flutter
    flickSteady: 0.82,    // brightness floor between outages (the +0.18 above it is the per-lamp bias)
    flickMin: 0.3,        // how dark the stutter dips before the blackout takes over
    deadLensMul: 0.28,    // a BROKEN lamp's lens/hood texels multiplied down by this (Models.instanced): the
                          // glb paints them pale cream, so killing the emissive alone still leaves a bright head
  };
  // real moon (DirectionalLight) shadow: a single ortho shadow map that FOLLOWS the player each frame
  // (SceneSetup.fitMoon) — the box tracks the focus so shadows appear across the whole visible area, not
  // just world origin. one extra depth pass per frame. all tuning knobs live here (bias/box/res)
  public static final MOON_SHADOW = {
    mapSize: 2048,      // shadow map resolution per edge (bump to 4096 if building-edge stairstepping shows)
    halfExtent: 90.0,   // ortho box half-width around the focus (world units) — sized to the on-screen area
    distance: 200.0,    // how far up-light the shadow camera sits from the focus. MUST clear the tallest
                        // building or the light plane sits below a tower top and its shadow truncates —
                        // downtown full-glass towers reach ~113 (30 floors), needing y-offset dist*0.74 > 113.
                        // ortho shadow quality is independent of distance (only halfExtent/mapSize set texel size)
    near: 1.0,          // shadow camera near plane
    far: 400.0,         // shadow camera far plane (>= 2*distance)
    bias: -0.0004,      // depth bias to kill self-shadow acne on box walls (tune)
    normalBias: 0.04,   // normal-offset bias — pushes the sample along the surface normal (box corners)
  };
  // volumetric shaft (render.LightCone): a hollow additive amber cone hung under the bulb, faking
  // the cone of lit air the SpotLight can't render. radius = bulb height * tan(LAMP_LIGHT.angle) *
  // radiusMul (matches the real cone). topA/botA = alpha fade down the shell (bulb -> ground)
  public static final LAMP_CONE = {
    opacity: 0.03,      // overall additive strength (keep under bloom threshold 0.9 * this)
    color: 0xffb866,    // amber, matches the SpotLight color
    topR: 0.2,         // min top radius — small so it reads as a cone, not a tube
    radiusMul: 0.9,     // scale on the geometric ground radius (height * tan(angle)) to match the lit circle
    startFrac: -0.1,     // where the shaft starts along the bulb->ground axis: 0 = at the bulb, 0.2 = a
                        // fifth of the way down (lifts the top below the lamp fixture)
    seg: 20,            // radial segments (roundness of the shell)
    topA: 0.9,          // alpha at the top (brightest)
    botA: 0.05,         // alpha at the ground (faintest)
  };
  // fake shadows cast from lamps (render.particles.CastShadows), mirroring the barrel shadow block
  // above. overhead light -> short shadows, small pool: an actor this many cells from the lamp base
  // casts none. steady (no flicker)
  public static final LAMP_SHADOW = {
    max: 2,             // at most this many lamp shadows per actor (its nearest lamps)
    rangeCells: 2,      // a lamp this many or more cells away casts no shadow on the actor
    lenMul: 0.6,        // shadow length = sprite world-height * this * distance falloff (overhead = short)
    op: 0.8,            // per-shadow opacity
    fade: 0.3,          // outer fraction of the range over which a shadow eases to 0
    lowMax: 3.0,        // both numbers above are tuned for a street bulb at CELL * LAMP_LIGHT.yMul, and
                        // a LOW fixture (a sewer wall bracket at 0.6) rakes light across the floor
                        // instead of pooling it — so lenMul and rangeCells are both scaled by
                        // refY / post.y, capped here. a street lamp lands on exactly 1.0, and a
                        // facility ceiling fixture at 5.8 against refY 5.6 lands on 0.966 — so the
                        // one HIGH fixture in the game is the reference bulb to within 4% and needs
                        // no floor under this ratio
    lowRangeCells: 3,   // absolute reach cap in cells for that scaled-up low fixture, so a bracket
                        // still throws LONG shadows (lenMul keeps the full lowMax) but only over a
                        // small pool. sits just under the burning barrel's FLAME.shadowRangeCells 4.
                        // no effect on a street lamp: it scales by 1.0 and stays at rangeCells
  };
  // CROSS-AREA textures: the ones every style draws, read straight off here by the sub-builders
  // instead of going through AreaStyle. Per-area art is NOT here — that lives in the style file
  // (render.world.CityStyle / DowntownStyle / SlumsStyle), which is also where a new swap belongs
  public static final TEXTURES = {
    coping: 'textures/city/coping.png',              // parapet coping cap strip
    shopWorn: 'textures/city/shop-wall-worn.png',    // single-story shop box wall (own worn texture)
    shopCoping: 'textures/city/shop-coping.png',     // single-story shop parapet coping cap
    // single-story shop storefronts: baked 16:9 (1280x720) from 2K sources via textures.json
    // (non-square res). Indexed by Building.shop (0..3): diner, corner, garage, laundromat.
    // door variant + door-less continuation, each in lit (open) / unlit (closed).
    shopFrontLit:   ['textures/city/shop-diner-front-lit.png', 'textures/city/shop-corner-front-lit.png', 'textures/city/shop-garage-front-lit.png', 'textures/city/shop-laundromat-front-lit.png'],
    shopFront:      ['textures/city/shop-diner-front.png', 'textures/city/shop-corner-front.png', 'textures/city/shop-garage-front.png', 'textures/city/shop-laundromat-front.png'],
    shopFrontNdLit: ['textures/city/shop-diner-front-nd-lit.png', 'textures/city/shop-corner-front-nd-lit.png', 'textures/city/shop-garage-front-nd-lit.png', 'textures/city/shop-laundromat-front-nd-lit.png'],
    shopFrontNd:    ['textures/city/shop-diner-front-nd.png', 'textures/city/shop-corner-front-nd.png', 'textures/city/shop-garage-front-nd.png', 'textures/city/shop-laundromat-front-nd.png'],
    // street-level grime variants (alpha ramp applied in code); picked per-building, overlaid on each
    // non-metal street face base. soot/drip, scuff, damp-stain — neutral dark, read over any wall
    grime: ['textures/decals/grime-1.png', 'textures/decals/grime-2.png', 'textures/decals/grime-3.png'],
    doorMetal: 'textures/city/door-metal.png',       // closed roll-up warehouse door (metal facade street faces)
    roofMetal: 'textures/city/roof-metal.png',       // metal warehouse gable-roof slopes (distinct from the wall)
    flame: 'textures/fx/flame.png',                  // burning-barrel flame sprite (chroma-keyed alpha)
    // wall decals (alpha PNGs, bg removed). bullet holes are spawned dynamically on wall hits;
    // graffiti/posters/cracks are placed statically on bare walls at city build. missing files
    // fall back to a procedural canvas (opaque) until real art is supplied
    bulletHoles: ['textures/decals/bullet-hole-1.png', 'textures/decals/bullet-hole-2.png'],
    // corrugated-steel dents/punctures for hits on metal-warehouse walls (facade 3)
    bulletHolesMetal: ['textures/decals/bullet-hole-metal-1.png', 'textures/decals/bullet-hole-metal-2.png'],
    graffiti: ['textures/decals/graffiti-1.png', 'textures/decals/graffiti-2.png'],
    posters: ['textures/decals/poster-1.png', 'textures/decals/poster-2.png'],
    cracks: ['textures/decals/wall-crack-1.png', 'textures/decals/wall-crack-2.png'],
    slimeTrail: 'textures/fx/slime-trail.png', // green slime ribbon behind the free parasite (chroma-keyed, tiled along length)
    // the grown props' living FX (render.actors.PropFX): a knot of tentacles that hangs in the
    // assimilation arch and writhes, and the mote its fireflies are drawn with. both chroma-keyed
    fxInnards: 'textures/fx/innards.png',
    fxFirefly: 'textures/fx/firefly.png',
  };
  // the gnats over the compound's PARK lamps, drawn by the very same pass: a `fly` row is a fraction
  // of its prop's height, so handing it a lamp's FacilityStyle.LAMP_H makes the mast the prop. Only
  // the park's masts get them (render.facility.FacilityLamps.LampSet.park) — a bug cloud belongs
  // over a lawn, not over a parking bay.
  //
  // EVERY POOLED QUAD IS A DRAW CALL and that is the whole budget (measured: 21 dots took calls
  // 88-90 to 109-111, exactly +21). So `trail` is 0 — a trail multiplies a swarm by trail + 1 — and
  // `posts` x `count` is what the feature costs, in full, every frame it draws
  public static final LAMP_FLY = {
    enabled: true,
    posts: 2,   // the nearest park masts to the player that carry a swarm at all
    count: 4,   // flies per mast. 2 x 4 = 8 quads = 8 draw calls
    // and how near a mast has to be before it is one of them, in cells. past this the swarm is a
    // few pixels of noise and not worth a call — the same distance gate LampLights keys its pool on
    rangeCells: 14.0,
    fly: {
      tex: RenderConfig.TEXTURES.fxFirefly,
      perLevel: 1,  // unused here: `count` is passed straight to drawFlies
      // a fraction of LAMP_H 5.9, so the ring centre sits at 5.02 — just under the head, which is at
      // LAMP_HEAD_Y 0.95. flies gather at the bulb and not halfway down the pole
      y: 0.88,
      yVar: 0.06,   // 4.9..5.6 world, a tight band around the lamp head
      r: 0.14,      // 0.83 world — clear of the hood without leaving the light
      rVar: 0.35,
      // steeper than the arch's: a gnat cloud has no plane, and the lean is what says so. it is also
      // what sets the vertical reach — r * sin(tilt) = 0.34 either side, so a dot laps from just
      // under the hood to level with it rather than falling away down the pole
      tilt: 0.45,
      size: 0.05,   // 0.30 world, a third of the arch's dot — these are insects, not spirits
      color: 0xffe3a8, // the sodium head's own warm, so they read as lit BY the lamp
      glow: 2.2,
      alpha: 0.75,
      rate: 0.9,    // five times the arch's: an insect's orbit is frantic where an organ's is slow
      rateVar: 0.55,
      bob: 0.05,
      twinkle: 0.7, // deep, so a fly keeps blinking out of the light and back into it
      trail: 0,
      trailGap: 0.0,
      trailSize: 0.0,
    },
  };
}

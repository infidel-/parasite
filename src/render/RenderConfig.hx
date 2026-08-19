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
    debrisMul: 0.55,     // street-debris + thrown-money crop darken factor (matte trash, no bright glow)
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
    soundRangeCells: 4,     // looping fire sound fades to silent at this world-cell distance
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
  // baked glb props (make models -> app/models/), loaded via render.Models
  public static final MODELS = {
    streetLamp: 'models/street-lamp.glb',
    streetLamp2: 'models/street-lamp2.glb', // PBR variant (base + normal + metallic-roughness maps)
    sewerExit: 'models/sewer/exit.glb',     // the sewer/habitat exit ladder (render.world.ObjModels)
    // tunnel clutter, scattered against the walls by render.sewer.SewerProps. everything under
    // sewer/ is ONE simple object per glb — a composite comes back with an atlas that cannot be
    // decimated (see AGENTS.md), which is why the sewer-pile-1 rubble-and-pipe heap and the
    // sewer-pile-2 sack-and-crate heap are both gone, split into the simple objects they were made of
    sewerDrum: 'models/sewer/drum.glb',     // 200L steel drum, upright
    sewerCrates: 'models/sewer/crates.glb', // two solid-walled plastic stacking crates
    sewerCable: 'models/sewer/cable.glb',   // heavy industrial cable coiled flat
    sewerBags: 'models/sewer/bags.glb',     // three tied refuse sacks heaped together
    sewerBlock: 'models/sewer/block.glb',   // broken half of a hollow concrete block, rebar stub
    sewerBricks: 'models/sewer/bricks.glb', // low heap of broken bricks and concrete fragments
    sewerPipe: 'models/sewer/pipe.glb',     // short broken section of concrete sewer pipe, on its side
    // the habitat's four grown objects, standing in for their atlas sprites. unlike the clutter above
    // each of these HAS an AreaObject behind it, so they go through render.world.ObjModels and carry
    // the full solid / ghost / outline-hull set rather than one decoration batch
    habitatBiomineral: 'models/habitat/biomineral.glb',     // crystal spire in a slime mound
    habitatAssimilation: 'models/habitat/assimilation.glb', // braided tentacle arch with a maw
    habitatPreservator: 'models/habitat/preservator.glb',   // amber pod caged in veins
    habitatWatcher: 'models/habitat/watcher.glb',           // eye-studded mass ringed by tendrils
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
    // CURRENTLY 0 — the organs' lighting is being worked case by case and the coloured pools were
    // pulled for now; the table rows in ObjModels.MODELS keep their colours, so turning it back on is
    // this one number.
    // when on: an organ is a room feature and a habitat room holds ~1-3, so size it for what ONE room
    // shows rather than for the level (4 was the starting value). each slot is a full extra light
    // evaluation in every lit fragment of the frame — the street spotlight pool measured LINEAR at
    // ~0.32ms per light on the integrated Radeon (docs/3d-render.md)
    pool: 0,
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
                        // refY / post.y, capped here. a street lamp lands on exactly 1.0
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
  };
}

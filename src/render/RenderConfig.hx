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
    introMult: 6.0,       // enter effect: zoom-out from closest to resting target, BASE_MS multiples
    exitMult: 6.0         // leave effect: zoom-in to closest over the frozen last frame, then tear down
  };
  // occlusion fade: a building between camera and player eases to this opacity so the player
  // stays visible, then eases back to solid when it no longer blocks the sightline
  public static final OCCLUSION = {
    fade: 0.22,    // opacity an occluding building fades to (0 = invisible, 1 = solid)
    lerp: 0.15,    // per-30fps-frame ease of fade toward its target (dt-compensated)
    snap: 0.15,    // lock fade to target once within this gap: skips the slow exponential tail
                   // (invisible on the flat wall) so windows crisp back + bloom the moment the
                   // wall reads solid, instead of ~0.8s later
    margin: 1.0,   // XZ expansion when bucketing face-proud decals into their building
    aimGrow: 1.5   // targeting-mode: cells of lateral slack, so buildings flanking the
                   // cam->player / cam->target line fade too (not just strict occluders)
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
    splatMax: 80,        // per-area SPLAT decoration cap (oldest evicted)
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
  // 3D ground-decal albedo darkening (0..1): decal art was authored for the unlit 2D view, so in the
  // lit 3D rig (full ambient+hemisphere+moon on an up-facing quad) it reads too bright. multiply the
  // 3D texture crop down so decals sit in the road instead of glowing on top. 2D is unaffected
  // (it draws from the source image, not these crops). blood stays a touch more vivid than debris
  public static final DECAL = {
    bloodMul: 0.6,       // blood-splat crop darken factor
    debrisMul: 0.55,     // street-debris crop darken factor
    actorMul: 0.7,       // actor-sprite crop darken factor (knock the full-bright atlas down so AI
                         // don't read too white in the surrounding night; 1.0 = off, lit-only)
    radiusCells: 20.0,   // ground-decal reveal radius (cells) around the smoothed player pos; replaces LOS
    fadeCells: 1.5,      // soft edge band (cells): opaque inside (radius-fade), invisible past radius
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
    tracerWidth: 0.03,      // tracer quad width (cells)
    tracerJitter: 0.1,      // random offset on both tracer ends so shots don't share one exact line (cells)
    tailFrac: 0.55,         // streak visible length as a fraction of the full muzzle->impact run
    travelMs: 55.0,         // time the tracer head takes to race to the target
    tracerColor: 0xfff2c8,  // warm-white tracer
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
    // per-weapon: pellets fired, target jitter (cells), stagger between pellets (ms), and the
    // max tiles a missed bullet flies before it fades off-camera (shotgun stops short)
    kinds: {
      pistol:  { pellets: 1, spread: 0.0,  stagger: 0.0,  range: 14 },
      rifle:   { pellets: 3, spread: 0.15, stagger: 45.0, range: 14 },
      shotgun: { pellets: 5, spread: 0.5,  stagger: 0.0,  range: 5 },
    },
  };

  // 3D thrown-projectile choreography (spit clots / spine needles): an entities-atlas blob with
  // trailing drips races source->target at chest height, then the impact splat beat (burst
  // decals + splat sound) fires. timings mirror the 2D ParticleSpit/ParticleNeedle feel
  public static final PROJECTILE = {
    spit:   { travelMs: 150.0, scale: 0.3,  drips: 3 },  // spit clot: fat blob + drip trail
    needle: { travelMs: 110.0, scale: 0.16, drips: 2 },  // spine needle: small + fast afterimages
    dripGap: 0.2,        // spacing between trail blobs along the flight line (cells)
    dripSway: 0.1,       // per-drip lateral offset amplitude (cells)
    wobbleAmp: 0.04,     // sine wobble amplitude on the drips (cells)
    fadeFrac: 0.2,       // trailing fraction of the flight over which everything fades out
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

  // bullet holes: a missed shot that strikes a BARE (worn/windowless) wall leaves a small
  // rotated decal, persisted as a WALLHOLE tile-decoration + re-painted on the wall each frame
  // (fog-gated, cleared on area exit, capped like blood splats). glass/window faces get none
  public static final WALLHOLE = {
    max: 60,           // per-area bullet-hole cap (oldest evicted)
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
  // AI status badges float this fraction of Sprites.SIZE above the head (screen-up lift; clears the
  // head at any camera pitch — see Actors.drawBadges)
  public static inline var BADGE_LIFT = 0.65;

  // static wall decals (graffiti/posters/cracks): % of bare (worn) building faces that get one,
  // deterministic per col/row/dir hash (no rng -> stable across reloads, not saved)
  public static inline var WALLDECAL_PCT = 35;

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
  };
  // street-lamp SPOTLIGHT placed relative to the lamp model. the light sits at the bulb (dx/dz =
  // local horizontal offset rotated by the lamp yaw, yMul = height CELL*this) and aims at a ground
  // target offset by tdx/tdz (also local, rotated) — so the cone is a downward street pool, not an
  // omni glow on the post. angle = cone half-angle (rad), penumbra = soft edge 0..1. one block per
  // lamp model (different geometry = different bulb); SceneSetup pairs the placed model with a block
  public static final LAMP_LIGHT = {         // pairs with MODELS.streetLamp
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
    pool: 12,            // number of live SpotLights (fixed → NUM_SPOT_LIGHTS constant, no recompile)
    intensity: 45.0,     // live-lamp spotlight intensity
    lightRangeCells: 16, // a lamp within this many cells of the player may claim one of the pool lights
    fadeMul: 4.0,        // fade in/out duration = BASE_MS * this — ramps intensity so lamps don't blink
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
  };
  public static final LAMP_LIGHT2 = {        // pairs with MODELS.streetLamp2 (PBR)
    yMul: 1.4,
    dx: 1.0,
    dz: 0.0,
    angle: Math.PI / 5,
    penumbra: 0.1,
    tdx: 0.0,
    tdz: 0.0,
    markerVisible: true,
  };
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
    flame: 'textures/flame.png',                // burning-barrel flame sprite (chroma-keyed alpha)
    // wall decals (alpha PNGs, bg removed). bullet holes are spawned dynamically on wall hits;
    // graffiti/posters/cracks are placed statically on bare walls at city build. missing files
    // fall back to a procedural canvas (opaque) until real art is supplied
    bulletHoles: ['textures/decals/bullet-hole-1.png', 'textures/decals/bullet-hole-2.png'],
    // corrugated-steel dents/punctures for hits on metal-warehouse walls (facade 3)
    bulletHolesMetal: ['textures/decals/bullet-hole-metal-1.png', 'textures/decals/bullet-hole-metal-2.png'],
    graffiti: ['textures/decals/graffiti-1.png', 'textures/decals/graffiti-2.png'],
    posters: ['textures/decals/poster-1.png', 'textures/decals/poster-2.png'],
    cracks: ['textures/decals/wall-crack-1.png', 'textures/decals/wall-crack-2.png'],
  };
}

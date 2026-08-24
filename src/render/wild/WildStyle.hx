package render.wild;

import render.RenderConfig;

// one entry of PROPS: a wilderness glb and the numbers that belong to the MODEL rather than to the
// scatter that places it. `r` is the footprint radius as a MULTIPLE of h, the same ratio
// render.sewer.SewerStyle.SewerProp carries and for the same reason — render.Models.instanced scales
// a prop by HEIGHT alone, so any hand-typed world radius silently stops meaning what it said the
// moment `h` is edited
typedef WildProp = {
  path:String,   // RenderConfig.MODELS entry
  h:Float,       // world height render.Models.instanced scales the prop to
  r:Float,       // footprint radius as a multiple of h. WildProps.sit reads it: h * r * slope is how far
                 // a prop is SUNK so its downhill edge meets the ground instead of hanging over it, so
                 // this is the one field that decides how a prop meets uneven land
  jitter:Float,  // per-instance scale spread, as a fraction of h either side of 1.0. a hundred
                 // identical trees is wallpaper, and this is the cheapest thing that breaks it
};

// art + dimensions for the 3D wilderness — the render.world.CityStyle of open ground. there is one
// wilderness look today, so this is plain constants rather than a swappable instance
class WildStyle
{
  public static inline var GRASS = 'textures/wild/grass.png';   // side-on blade cluster, alpha cut
  // the GROUND texture is per-band and lives in render.wild.WildBand — plains keeps the grassland turf
  // this section is written about, forest lays leaf litter over it and mountain lays scree. all three
  // are the same class of art at the same GROUND_TILE, and their lifts are fitted against the turf's
  // own measured value (textures.json carries each number).
  //
  // measured mean LINEAR luminance of the two as BUILT (the sRGB byte mean is the wrong number — see
  // render.sewer.SewerScene): ground 0.0503 after its 0.75 lift, blades 0.0660 after their 1.4 one.
  // BOTH lifts are load-bearing and neither is a taste call. the ground as painted was 0.0208, DARKER
  // than the city road (0.0329), in an area lit by fill alone. the blades as painted were 0.1357 —
  // 2.70x the ground and the brightest thing out here bar the actor — so their gamma runs the other
  // way, above 1, to bring them DOWN to 1.31x. that ratio is the whole read and must survive any
  // re-art: a field where the grass and the earth sit at one value has nothing to read, and there is
  // no lamp, no window and no kerb out here to supply a value break (see textures.json)

  // world units per texture repeat on the ground. UVs are worldPos / this on BOTH axes so nothing
  // stretches, and it is deliberately NOT a multiple of CELL (4): at 8.0 the period would be exactly
  // two cells and every grid line would land on the same point of the tile, which reads as a lattice
  public static inline var GROUND_TILE = 9.0;

  // --- the ground surface (render.wild.WildGround) ---
  // sub-quads per cell per axis. ONE quad per cell is what the city lays and it is not enough here:
  // a 4-unit flat quad with a tiling texture reads as a tile, and there is no kerb, no road paint and
  // no building to break it up. at 2 the whole area is 200x200 quads = 80k tris, which is why the
  // ground is emitted per CHUNK rather than as one mesh — render.Chunks then only submits the visible
  // few. it is also the lattice render.wild.WildHeight displaces into relief, and it does NOT have to
  // rise for that: the tighter of the field's two octaves is 29 world units, so a 2-unit sample gives
  // it 14 points per period
  public static inline var SUB = 2;
  // the relief AMPLITUDE is per-band and lives in render.wild.WildBand: the field's own numbers are a
  // SLOPE budget rather than a look — everything downstream is paid for in slope, not in height — so
  // the band scales the whole field by one factor and everything follows. at 1.0 the ground runs 3.80
  // units peak to trough with a p50 slope of 0.110, and an actor crossing a cell steps a measured p50
  // of 0.272 world units (the city's own curb step is 0.2), so a band that asks for more scales that
  // step with it
  // low-frequency value swing of the ground mottle, on the per-vertex colour channel. this is what
  // makes the extra polygons pay: dry patches and damp hollows drift across the surface with no
  // second texture, no splat shader and no extra draw call
  public static inline var TINT_AMP = 0.18;

  // --- the grass layer (render.wild.WildGrass) ---
  // the tuft COUNT per cell and the tuft HEIGHT are per-band (render.wild.WildBand): open plains grow
  // deep grass, a canopy shades it out and a rock face barely holds any. a tuft is two crossed
  // alpha-tested quads (4 tris), merged per chunk, so a chunk is one draw call whatever it holds
  public static inline var TUFT_W = 1.5;         // world width of one of its two quads
  public static inline var TUFT_JITTER = 0.35;   // +/- fraction of both, dealt per tuft
  public static inline var TUFT_ALPHA = 0.4;     // alphaTest cut — no transparency, so no sorting
  // wind. amplitude is a world offset at the BLADE TIP and tapers to nothing at the base (the weight
  // is the quad's own v), rate is in BASE_MS units like every other timed anim in the renderer.
  // both were halved from the 0.22 / 0.55 they went in at: at that throw a tuft swung a fifth of its
  // own width and read as a breeze the rest of the scene has no sign of, and the field caught the eye
  // instead of sitting under it
  public static inline var WIND_AMP = 0.11;
  public static inline var WIND_RATE = 0.28;

  // --- the props (render.wild.WildProps) ---
  // `h` IS NOT A FREE NUMBER: render.Models.instanced scales a prop by HEIGHT ALONE, so a row's world
  // WIDTH is `h * (widest / height)` of the glb's own bbox. measured, in that order: conifer 0.34,
  // broadleaf 0.84, broadleaf-full 0.71, dead 0.47, boulder 3.67, cluster 1.31, bush 1.91,
  // bramble 2.86. the boulder is the reason this is written down — at the 1.5 it went in with, a 3.67
  // aspect made it 5.5 units across, well over a cell, and the bush's first mesh came back at 25
  // (see its models.json note).
  //
  // the trees are 25% taller than they went in at (6.0 / 5.2), by request. that puts the conifer 4.8
  // world units across and the broadleaf 5.5, both over the 4-unit cell — which is CORRECT for a
  // canopy and would not be for a rock: a boulder IS its footprint, where an overhanging canopy is
  // what a tree does, and only the trunk has to sit inside the blocked cell. the standing caution is
  // unchanged though: an actor billboard is 3 world units and there is no occlusion fade out here, so
  // a tree tall enough to be impressive is a tree that hides the player behind it.
  //
  // that 3 units is also a CLEARANCE the canopies have to respect, which the first pass missed: a
  // crown that skirts down the trunk puts leaves at head height however tall the tree is, and the
  // player walks into the green. the fix belongs in the MODEL — a crown confined to the top of its
  // own bbox — and `h` then scales the clearance with it. see the broadleaf-full row below, which is
  // the only `h` here set by that number rather than by look
  public static var PROPS:Array<WildProp> = [
    {
      path: RenderConfig.MODELS.wildTreeConifer,
      h: 7.5,
      r: 0.30,
      jitter: 0.20,
    },
    {
      path: RenderConfig.MODELS.wildTreeBroadleaf,
      h: 6.5,
      r: 0.38,
      jitter: 0.22,
    },
    // the only prop out here whose `h` is set by CLEARANCE rather than by look, and the tallest thing
    // in the area because of it. measured on the glb by binning vertices along Y: a bare trunk holding
    // 13-16% of the max radius up to 0.30 of the height, then the crown flares to 59% at 0.35 and is
    // at 90% by 0.45. so the height an actor walks under is 0.35 * h, and 3.0 of that is spoken for by
    // the actor billboard — 9.5 leaves 3.32. the original mesh had no such number at all: its canopy
    // skirted down to ~22% of its height and the player walked head-first into the foliage.
    //
    // being TALL is not what costs footprint here, the bbox is: at aspect 0.71 this is the narrowest
    // tree of the four for its height, so 9.5 draws 6.7 world units across — LESS than the 7.15 the
    // first replacement took at h 6.5, and less than the 6.3 of the original at 5.8 is close to.
    // models.json carries the whole record, including the two retired meshes in Unused/
    {
      path: RenderConfig.MODELS.wildTreeBroadleafFull,
      h: 9.5,
      r: 0.37,
      jitter: 0.22,
    },
    {
      path: RenderConfig.MODELS.wildTreeDead,
      h: 5.6,
      r: 0.24,
      jitter: 0.26,
    },
    {
      path: RenderConfig.MODELS.wildRockBoulder,
      h: 0.9,
      r: 1.85,
      jitter: 0.30,
    },
    {
      path: RenderConfig.MODELS.wildRockCluster,
      h: 2.2,
      r: 0.55,
      jitter: 0.25,
    },
    {
      path: RenderConfig.MODELS.wildBushLow,
      h: 1.1,
      r: 0.80,
      jitter: 0.28,
    },
    // the second bush, and the widest prop out here: aspect 2.86 against bush-low's 1.91, so a lower
    // `h` still draws WIDER — 2.9 world units across at 1.0. that is the shape difference doing the
    // work, a sprawling bramble beside a rounded scrub, rather than two domes at two sizes
    {
      path: RenderConfig.MODELS.wildBushBramble,
      h: 1.0,
      r: 1.43,
      jitter: 0.30,
    },
    // the same two rock glbs again at SMALL_ROCK_SCALE — loose stones on open ground, where the two
    // full-size rows above stand on a TILE_ROCK cell the player cannot walk through. render.Models
    // caches one template per PATH, so a second row over the same file is a second InstancedMesh and
    // not a second load
    {
      path: RenderConfig.MODELS.wildRockBoulder,
      h: 0.9 * SMALL_ROCK_SCALE,
      r: 1.85,
      jitter: 0.40,
    },
    {
      path: RenderConfig.MODELS.wildRockCluster,
      h: 2.2 * SMALL_ROCK_SCALE,
      r: 0.55,
      jitter: 0.40,
    },
    // the two BAND props, both of them variants of a TILE_ROCK cell rather than tiles of their own —
    // the trick the two bushes already play on TILE_BUSH. a fallen trunk that blocks movement and is
    // see-through is exactly what a rock tile means, so this costs no tile ID, no walkability entry
    // and no 2D map art. aspect 3.83 makes the log the widest prop out here: 3.4 units end to end at
    // h 0.9, which is a cell's worth of trunk lying across it
    {
      path: RenderConfig.MODELS.wildLogFallen,
      h: 0.9,
      r: 1.90,
      jitter: 0.25,
    },
    {
      path: RenderConfig.MODELS.wildRockOutcrop,
      h: 1.8,
      r: 1.00,
      jitter: 0.30,
    },
    // the 2x2 boulder, and the only prop out here whose size is not a taste call: it has to fill the
    // four cells Const.TILE_ROCK_LARGE blocks and must not spill far past them. aspect 1.68, so h 5.0
    // draws 8.4 world units across against a blocked footprint of 8.0 — a hand's breadth of overhang,
    // where the widest point of a boulder sits at mid height anyway. `r` 0.84 is that footprint radius
    // over `h` (4.2, one CELL), which is exactly what sit() wants to seat an object this wide in a
    // hillside, and `jitter` is the smallest here for the same reason: a scale roll on this prop moves
    // its footprint, not just its look. at 5.0 it also stands well over the 3.0 actor billboard, which
    // is the read a cell that blocks SIGHT has to earn
    {
      path: RenderConfig.MODELS.wildRockLarge,
      h: 5.0,
      r: 0.84,
      jitter: 0.08,
    },
  ];
  // indices into PROPS, named where the model builder picks them. the four trees are FIRST and in
  // order, because render.wild.WildModel maps Const.TILE_TREE1 + 0..3 straight onto them
  public static inline var TREE_CONIFER = 0;
  public static inline var TREE_BROADLEAF = 1;
  public static inline var TREE_BROADLEAF_FULL = 2;
  public static inline var TREE_DEAD = 3;
  public static inline var ROCK_BOULDER = 4;
  public static inline var ROCK_CLUSTER = 5;
  public static inline var BUSH_LOW = 6;
  public static inline var BUSH_BRAMBLE = 7;
  public static inline var ROCK_BOULDER_SMALL = 8;
  public static inline var ROCK_CLUSTER_SMALL = 9;
  public static inline var LOG_FALLEN = 10;
  public static inline var ROCK_OUTCROP = 11;
  public static inline var ROCK_LARGE = 12;
  // WHICH of these a bush, rock or tree tile means is per-band (render.wild.WildBand) — the band holds
  // weighted lists of these indices rather than a chance constant per pair
  // the small rocks are the full-size ones at a tenth of their height, and the number is literal —
  // 0.09 and 0.22 world units tall, i.e. 0.33 and 0.29 across. that is a stone, not a boulder, seen
  // from a camera 18-55 units up, so this is the one knob to raise if they read as nothing at all
  public static inline var SMALL_ROCK_SCALE = 0.1;
  // the odds an open cell also gets a loose stone are per-band (render.wild.WildBand): scree country
  // is made of them, a forest floor mostly is not
  // instance cull radius, in world units: a margin around a prop's centre so nothing pops at the
  // frame edge. sized to the tallest prop, since render.Models.cull tests ONE sphere radius for every
  // batch. it went 7.0 -> 9.0 with the broadleaf-full's h, which is the standing tie: raise the
  // tallest prop and this has to follow it or that prop pops in at the frame edge
  public static inline var PROP_CULL_R = 9.0;

  // --- the ground patches (render.wild.WildPatches) ---
  // two ragged overlays laid over the turf, so the base ground varies without a second base texture,
  // a splat shader or a per-vertex blend. this is render.world.Lawns' idiom and the first layer is
  // literally its art: a dead-lawn tile is a dry patch wherever it lands. the values below are Lawns'
  // own, and they are load-bearing rather than taste — see render.world.CoverageMask for why KERN has
  // to clear CELL * 0.5, and Lawns' TILE comment for why the repeat sits UNDER the cell size
  public static inline var PATCH_DEAD = 'textures/slums/grass-dead.png';   // dry dead grass, reused as-is
  public static inline var PATCH_EARTH = 'textures/wild/ground-earth.png'; // cracked bare soil
  public static inline var PATCH_TILE = 3.0;      // world units per repeat, both axes, never stretched
  // base opacity. Lawns takes 0.5 and that is wrong here — measured LINEAR luminance of the three
  // ground arts as BUILT: turf 0.0476, bare earth 0.0348 (0.73x), dead grass 0.0560 (1.18x). that is a
  // real value ladder, but at 0.5 the blend halves it to 0.87x and 1.09x, which is under the threshold
  // in a frame this dark and is exactly why the first pass read as nothing. at 0.85 the patch mostly
  // REPLACES the turf where its art is opaque, which is what bare earth actually is — and the art is
  // only ~38% opaque either way, so the turf still shows through the gaps and nothing looks pasted on
  public static inline var PATCH_ALPHA = 0.85;
  public static inline var PATCH_Y = 0.02;        // per-LAYER lift off the ground, multiplied by the layer
                                                  // index — the two overlays are both depthWrite:false at
                                                  // one renderOrder, so without a separation they sort
                                                  // against each other and flicker where they overlap
  // coverage kernel radius in world units, well over Lawns' own 7.0. a city lawn is read from a yard
  // away and 7 gives a blob of radius ~3.15, under one cell; out here the camera sits 18-55 units up
  // and a blob that size is not an island, it is grain. 11.0 gives ~4.95, two and a half cells across
  public static inline var PATCH_KERN = 11.0;
  public static inline var PATCH_KERN_JIT = 0.35; // its per-cell jitter, as a fraction
  // odds a cell seeds a patch, and they are LOW because everything downstream multiplies: a seed grows
  // into a 1-5 cell clump, every marked cell grows a blob of radius ~KERN*0.45, and neighbouring blobs
  // merge. these went in at 0.07 / 0.045 and that put 25.8% and 18.4% of the mask over the alphaTest
  // line — so much that the two layers covered the whole frame and read as SPECKLE rather than as
  // patches, since what shows through a near-uniform mask is just the art's own ~40% coverage. the
  // rule of thumb: judge the mask, not the seed count, and keep the strong coverage near 10%. the two
  // chances themselves are per-band (render.wild.WildBand) and the numbers above are the plains row's

  // --- the scene (render.wild.WildScene) ---
  public static inline var SKY = 0x0a0f14;          // background + fog: night, a shade greener than the city's
  // fog, as multiples of the 400-unit area span (0.65 and 1.4, against the city's own 0.55 and 1.2).
  // it went in at 120/320 on the reasoning that open ground should end sooner than a street, and that
  // was WRONG by a factor of two — the fog is keyed on distance from the CAMERA, not from the player,
  // and this camera sits 18-55 units up looking down, so at 320 the far half of every frame was
  // already solid background. It read as a lit band of ground around the player with black beyond,
  // with a curved organic edge (the iso-distance conic on the ground plane), and looked exactly like
  // missing geometry — the ground A/B'd byte-identical with the fog off (13.71 vs 13.65 mean over a
  // 120px box, band vs "hole"). If a wilderness frame ever looks like it is missing its ground, check
  // this before anything else
  public static inline var FOG_NEAR = 260.0;
  public static inline var FOG_FAR = 560.0;
  public static inline var BLOOM_THRESHOLD = 0.9;   // nothing out here glows; the street's own level

  // --- the vision mask: what the player cannot see (render.world.VisionMask) ---
  // the wilderness's preset of the tunnel mask. only TWO fields differ from SewerStyle.MASK, which is
  // the whole reason that file was generalised instead of forked — read the rationale for the other
  // seven there, because they were measured underground and carry over unchanged.
  //
  // what the mask DOES out here is different in kind, and worth knowing before tuning it. underground
  // it is an atmosphere layer: a tunnel is mostly wall, so most of the frame is behind something and
  // the mask is on all the time. an open area is 99.5% see-through by construction — the only cells
  // that block sight are the two large obstacles (Const.TILE_ROCK_LARGE / TILE_TREE_CLUSTER), of which
  // a mountain area holds ~8 and a forest ~7. measured over 1000 player poses against generated
  // layouts: ~1.2% of the visible ground is shadowed on average and only ~20% of frames carry any
  // shadow at all, while standing beside a boulder puts up to 55% of the frame behind it, and the
  // PLAINS has no blocker of any kind so its mask is uniformly lit forever. so this is a COVER CUE
  // that fires on contact, not a fog — if it ever reads as "always on" out here, something has started
  // writing opaque tiles that should not be
  public static final MASK:render.world.VisionMaskOpts = {
    // DARKER than the tunnel's 0.18, and for the reason above inverted. underground a hard black would
    // empty the frame, because the frame IS the thing being hidden; out here the hidden part is a wedge
    // behind one rock in an otherwise lit field, so it can afford to read as a real shadow — which is
    // what makes the cover legible at a glance. 0.10 mixes 90% toward WildScene's SKY
    hidden: 0.10,
    // nothing out here is additive: no lamps, no glow quads, no cones (see WildScene). kept at the
    // tunnel's value so an additive effect that does wander in — a muzzle flash, a gas puff — takes the
    // same hard floor it would anywhere else
    hiddenAdd: 0.0,
    // same as the tunnel's, and affordable at four times the canvas because a rebuild is FLAT in canvas
    // area — every part of it except fadeCell, which is the one thing an open area barely runs. measured
    // in the live renderer, one full raster: habitat 168x112 0.68ms, sewer 600x480 1.14ms, wilderness
    // 800x800 1.34ms. 34x the texels for 2x the time
    px: 8,
    blur: 0.5,
    wallFade: 0.5,
    // the wilderness has no always-solid border ring the way a tunnel does — the turf is walkable right
    // to the edge — so this does dim the outermost cell of real ground. kept anyway: past that cell the
    // area simply stops, and a lit rim meeting the background on a hard line is exactly the failure this
    // channel exists to fix. it only ever shows when the player walks up to the border
    edgeFade: 1.0,
    wobble: 0.3,
    step: 0.05,
    // 20, against the tunnel's 14, and DERIVED the same way. CAMERA_WILD at full zoom-out covers 305
    // cells (CameraRig.maxFootprintCells at 16:9) and reaches 7.5 cells ahead of the player, 5.4 behind
    // and 13.4 to the side — 15.4 at the far corner, against the sewer camera's 12.2. at 14 the square
    // range bound would have been ON SCREEN, which would read as a vision radius the game logic does
    // not have (AreaGame.isVisible is unbounded). 20 puts it 4.6 cells past the far corner
    r: 20,
  };
}

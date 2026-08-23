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
  r:Float,       // footprint radius as a multiple of h (unused by the scatter today, but it is what
                 // a future placement rule has to derive its clearance from)
  jitter:Float,  // per-instance scale spread, as a fraction of h either side of 1.0. a hundred
                 // identical trees is wallpaper, and this is the cheapest thing that breaks it
};

// art + dimensions for the 3D wilderness — the render.world.CityStyle of open ground. there is one
// wilderness look today, so this is plain constants rather than a swappable instance
class WildStyle
{
  public static inline var GROUND = 'textures/wild/ground.png'; // matted grassland turf, full coverage
  public static inline var GRASS = 'textures/wild/grass.png';   // side-on blade cluster, alpha cut
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
  // few. it is also the lattice Phase 2 displaces, so raising it buys smoother relief as well
  public static inline var SUB = 2;
  // low-frequency value swing of the ground mottle, on the per-vertex colour channel. this is what
  // makes the extra polygons pay: dry patches and damp hollows drift across the surface with no
  // second texture, no splat shader and no extra draw call
  public static inline var TINT_AMP = 0.18;

  // --- the grass layer (render.wild.WildGrass) ---
  // tufts per open cell. a tuft is two crossed alpha-tested quads (4 tris), merged per chunk, so a
  // chunk is one draw call whatever it holds
  public static inline var TUFTS_PER_CELL = 2;
  public static inline var TUFT_H = 1.1;         // world height of a tuft
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
  // heights are held DOWN on purpose. an actor billboard is 3 world units and there is no occlusion
  // fade out here, so a tree tall enough to be impressive is a tree that hides the player behind it.
  //
  // AND `h` IS NOT A FREE NUMBER: render.Models.instanced scales a prop by HEIGHT ALONE, so a row's
  // world WIDTH is `h * (widest / height)` of the glb's own bbox. measured, in that order:
  // conifer 0.64, broadleaf 0.84, boulder 3.67, cluster 1.31, bush 1.75. the boulder is the reason
  // this is written down — at the 1.5 it went in with, a 3.67 aspect made it 5.5 units across, well
  // over a cell, and the bush's first mesh came back at 25 (see its models.json note)
  public static var PROPS:Array<WildProp> = [
    {
      path: RenderConfig.MODELS.wildTreeConifer,
      h: 6.0,
      r: 0.30,
      jitter: 0.20,
    },
    {
      path: RenderConfig.MODELS.wildTreeBroadleaf,
      h: 5.2,
      r: 0.38,
      jitter: 0.22,
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
  ];
  // indices into PROPS, named where the model builder picks them
  public static inline var TREE_CONIFER = 0;
  public static inline var TREE_BROADLEAF = 1;
  public static inline var ROCK_BOULDER = 2;
  public static inline var ROCK_CLUSTER = 3;
  public static inline var BUSH_LOW = 4;
  // instance cull radius, in world units: a margin around a prop's centre so nothing pops at the
  // frame edge. sized to the tallest prop, since render.Models.cull tests one sphere for all of them
  public static inline var PROP_CULL_R = 7.0;

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
}

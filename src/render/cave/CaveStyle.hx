package render.cave;

// which spots a cave prop may be dealt to (render.cave.CaveProps). the spot PARTITIONS the table, so
// each of the three must keep at least one entry
enum CavePropSpot
{
  FLAT;   // a straight run of wall foot
  CORNER; // the angle of two walls
  HANG;   // hung down a NORTH face (the one the camera looks at) from the rock top's lip
}

// one entry of CaveStyle.PROP_MODELS: a dressing glb and the numbers that are its own (see
// render.sewer.SewerStyle's SewerProp for why the standoff is a ratio of h and not a distance)
typedef CaveProp = {
  path:String,        // RenderConfig.MODELS entry
  h:Float,            // world height Models.instanced scales the prop to
  r:Float,            // half its DEPTH (the axis it stands off the wall along, Blender y) over its
                      // native height, measured off the baked glb
  spot:CavePropSpot,  // which spots deal it
}

// art + dimensions for the 3D mountain cave habitat — the cave's own look. it borrows the tunnels'
// pipeline (vision mask, organ props, light pools) and none of their art: warm limestone where the
// sewer is rose-brown masonry and the wilderness cool grey scree
class CaveStyle
{
  public static inline var WALL = 'textures/cave/wall.png';       // the rock face, strata running along the wall
  public static inline var FLOOR = 'textures/cave/floor.png';     // damp silt and pebbles
  public static inline var ROCKTOP = 'textures/cave/rocktop.png'; // the rock mass seen from above

  // world units per texture repeat, both axes, so nothing stretches. none a multiple of CELL (4),
  // for the reason SewerStyle gives: a period of two cells puts every grid line on the same point of
  // the tile and the repeat reads as a pattern
  public static inline var WALL_TILE = 6.0;
  public static inline var FLOOR_TILE = 7.0;
  public static inline var TOP_TILE = 9.0;

  // the floor field the outline is cut from (sample density, blur, iso level, lumps) is
  // gen.cave.CaveField's, so the oracle can check it

  // --- the rock mass ---
  // top of the rock, world units. the camera-clearance number the sewer walls stand at, and nothing
  // rises above it — SAG and RIM only ever lower it
  public static inline var WALL_H = 3.0;
  // how far the top sags under WALL_H, smooth noise over the whole mass
  public static inline var SAG = 0.5;
  // the lip rounds down by this much at the outline and rises to the full top over RIM_W of field,
  // so the drop is a worn shoulder and not one dead-straight edge (the sewer's "it is the cap edge")
  public static inline var RIM = 0.55;
  public static inline var RIM_W = 0.12;
  // wall rows from foot to lip, as fractions of the wall's height at that point
  public static var WALL_ROWS = [ 0.0, 0.3, 0.6, 0.85, 1.0 ];
  // how far each row bulges, as a fraction of BULGE: zero at the foot and at the lip, so the wall
  // meets the floor and the rock top exactly on the outline
  public static var WALL_BULGE = [ 0.0, 0.7, 1.0, 0.6, 0.0 ];
  // world units a wall face bulges back into the rock at most (outward it takes OUT of that)
  public static inline var BULGE = 0.45;
  public static inline var BULGE_OUT = 0.25;

  // --- per-vertex value (no art, no draw calls) ---
  public static inline var TINT_AMP = 0.14;   // +/- swing of the smooth value noise on every surface
  public static inline var TINT_FOOT = 0.72;  // a wall's foot row, the floor crease
  public static inline var TINT_LOW = 0.88;   // the row above it
  // floor darkening along the walls, by field: SHADOW at the outline, back to 1 over SHADOW_W of field
  public static inline var SHADOW = 0.45;
  public static inline var SHADOW_W = 0.3;

  // --- floor decals (render.cave.CaveGeom.decals, laid by render.sewer.SewerGround.scatter) ---
  public static inline var FLOOR_GUANO = 'textures/cave/floor-guano.png';   // droppings under the roosts
  public static inline var FLOOR_CRUST = 'textures/cave/floor-crust.png';   // a calcite crust where water stood
  public static inline var FLOOR_FUNGUS = 'textures/cave/floor-fungus.png'; // pale spots and mycelium
  public static inline var FLOOR_MOSS = 'textures/cave/floor-moss.png';     // moss, where the mouths let light in
  public static inline var DECAL_PCT = 12;    // % of floor cells (the sewer floor's 8: a cave floor is the dressing)
  public static inline var MOSS_PCT = 22;     // % of the cells near a mouth
  public static inline var MOSS_REACH = 2;    // cells from a mouth, either axis, that moss grows within
  public static inline var DECAL_Y = 0.01;    // proud of the floor, under nothing

  // --- the light rig (render.cave.CaveScene) ---
  public static inline var DARK = 0x05060a;   // background + fog, a shade warmer-neutral than the tunnels'
  // moonlight down a cave mouth: cold, and pooled a little way into the cave from the mouth
  public static inline var MOUTH_COLOR = 0x8fa6c8;
  public static inline var MOUTH_REACH = 6.0;  // world units into the cave the beam aims at
  public static inline var MOUTH_BACK = 2.0;   // world units behind the mouth (over the rock) the beam starts
  public static inline var MOUTH_MUL = 0.9;
  public static inline var BLOOM_THRESHOLD = 0.9;
  // the cave-mouth exit's depth in world units as render.world.ObjModels draws it (h 2.9; the glb is
  // 1.552 deep at 2.919 tall): render.cave.CaveArea.objWall stands it off the wall foot by half of it
  public static inline var MOUTH_DEPTH = 1.54;

  // --- the dressing dealt against the wall foot (render.cave.CaveProps) ---
  // r is measured off the baked glbs (half the y extent over the z extent); re-measure it whenever a
  // piece is rebuilt
  public static var PROP_MODELS:Array<CaveProp> = [
    { path: render.RenderConfig.MODELS.caveStalagmites, h: 2.4, r: 0.396, spot: CORNER },
    { path: render.RenderConfig.MODELS.caveCrystals, h: 1.45, r: 0.387, spot: CORNER },
    { path: render.RenderConfig.MODELS.caveFlowstone, h: 2.9, r: 0.286, spot: FLAT },
    { path: render.RenderConfig.MODELS.caveRubble, h: 1.1, r: 0.644, spot: FLAT },
    { path: render.RenderConfig.MODELS.caveRimstone, h: 0.35, r: 2.76, spot: FLAT },
    { path: render.RenderConfig.MODELS.caveFungus, h: 0.8, r: 0.771, spot: FLAT },
    { path: render.RenderConfig.MODELS.caveRoots, h: 2.2, r: 0.109, spot: HANG },
  ];
  // one floor prop per 2x2 block, gated per eligible wall face (render.sewer.SewerStyle.PROP_PCT's
  // 18 is a tunnel's; a cave's dressing IS the room: at 14 a 24x18 cave dealt six, at 25 eight)
  public static inline var PROP_PCT = 40;
  // one root curtain per 2x2 block, gated per eligible north face
  public static inline var HANG_PCT = 35;
  // how far a prop sinks back past the wall foot, as a fraction of its standoff: the foot row of the
  // wall is exactly on the outline and the rows above bulge back, so a prop tucked a little past the
  // foot meets the rock instead of standing a sliver off it
  public static inline var PROP_TUCK = 0.2;
  // +/- slide along a flat run of wall, world units, so props on one wall do not line up on centres
  public static inline var PROP_SLIDE = 0.8;
  // +/- yaw wobble, radians, and the height scale band the props are dealt in
  public static inline var PROP_YAW_JITTER = 0.3;
  public static inline var PROP_SCALE_LO = 0.9;
  public static inline var PROP_SCALE_HI = 1.3;
  // how far under the rock top's lip a root curtain's top hangs, so it reads as coming out of the rock
  public static inline var HANG_TUCK = 0.08;

  // the fog-of-war mask: the tunnels' measured values, which are about the 2D visibility polygon and
  // the fog colour rather than about the masonry
  public static final MASK:render.world.VisionMaskOpts = render.sewer.SewerStyle.MASK;
}

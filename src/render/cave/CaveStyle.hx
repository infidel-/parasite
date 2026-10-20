package render.cave;

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

  // --- the light rig (render.cave.CaveScene) ---
  public static inline var DARK = 0x05060a;   // background + fog, a shade warmer-neutral than the tunnels'
  // moonlight down a cave mouth: cold, and pooled a little way into the cave from the mouth
  public static inline var MOUTH_COLOR = 0x8fa6c8;
  public static inline var MOUTH_REACH = 6.0;  // world units into the cave the beam aims at
  public static inline var MOUTH_BACK = 2.0;   // world units behind the mouth (over the rock) the beam starts
  public static inline var MOUTH_MUL = 0.9;
  public static inline var BLOOM_THRESHOLD = 0.9;

  // the fog-of-war mask: the tunnels' measured values, which are about the 2D visibility polygon and
  // the fog colour rather than about the masonry
  public static final MASK:render.world.VisionMaskOpts = render.sewer.SewerStyle.MASK;
}

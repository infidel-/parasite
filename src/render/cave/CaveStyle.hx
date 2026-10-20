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
  r:Float,            // half its DEPTH (the axis it stands off the wall along, Blender y, glTF z) over
                      // its native height, measured off the baked glb
  w:Float,            // half its WIDTH (glTF x) over its native height, measured the same way
  spot:CavePropSpot,  // which spots deal it
}

// one ground-patch layer of render.cave.CavePatches
typedef CavePatch = {
  tex:String,         // the layer's tiling art: ragged islands, alpha cut
  chance:Float,       // odds a floor cell seeds a clump
  mouths:Bool,        // also laid round both cave mouths
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
  // proud of the floor and over the ground patches (PATCH_Y * 3 is the top one): a stain lies on gravel
  public static inline var DECAL_Y = 0.08;

  // --- the ground patches (render.cave.CavePatches) ---
  public static inline var PATCH_CLAY = 'textures/cave/patch-clay.png';       // dark wet clay
  public static inline var PATCH_BEDROCK = 'textures/cave/patch-bedrock.png'; // pale bedrock showing through
  public static inline var PATCH_GRAVEL = 'textures/cave/patch-gravel.png';   // loose gravel and grit
  // bottom to top: clay in the hollows, the bedrock showing through, loose gravel lying over both.
  // gravel also rings each mouth, where the mouth's scree slope runs out onto the floor (asked for: the
  // slope "ends too abruptly on a different texture of the floor"). the art is ~19-46% opaque and
  // built at 0.75x / 1.8x / 1.5x the floor's linear value (the wilderness ladder, render.wild.WildStyle)
  public static var PATCHES:Array<CavePatch> = [
    { tex: PATCH_CLAY, chance: 0.04, mouths: false },
    { tex: PATCH_BEDROCK, chance: 0.035, mouths: false },
    { tex: PATCH_GRAVEL, chance: 0.04, mouths: true },
  ];
  public static inline var PATCH_TILE = 4.5;     // world units per repeat, never stretched (FLOOR_TILE's rule)
  public static inline var PATCH_ALPHA = 0.85;   // render.wild.WildStyle.PATCH_ALPHA's measured reason
  public static inline var PATCH_Y = 0.02;       // per-LAYER lift off the floor, times the layer index + 1
  // coverage kernel radius, world units: under the wilderness's 11, the cave being passages two and
  // three cells wide, and over render.world.CoverageMask's CELL * 0.5 floor
  public static inline var PATCH_KERN = 9.0;
  public static inline var PATCH_KERN_JIT = 0.35;
  public static inline var PATCH_MOUTH = 1;      // cells round a mouth, either axis, a mouths layer marks

  // --- the rimstone pools' water (render.cave.CaveWater) ---
  // the water is the bottom row of the pool's sheet: the deep pool left, the shallow band right
  public static inline var WATER_SCALE = 4.0;    // ripple units per world unit (render.sewer.SewerStyle's)
  public static inline var WATER_AMP = 0.14;     // ripple slope at full strength: enough tilt to reach the glint
  public static inline var WATER_RATE = 0.05;    // ripple phase, radians per BASE_MS
  // the virtual light off the mirror, view space: |off| 0.36 is ~20 degrees, so a facet must tilt ~10
  // degrees to catch it, which only a ripple's steep side does
  public static inline var WATER_OFF_X = 0.3;
  public static inline var WATER_OFF_Y = 0.2;
  public static inline var WATER_EDGE = 0.996;   // cos of the glint's half-width: a crisp sparkle, not a sheen
  public static inline var WATER_GLINT = 0x6f8fa8; // the glint's colour at full: a cold moonlit blue-white
  public static inline var WATER_GLINT_MUL = 0.9;
  public static inline var WATER_BAND = 0.5;     // the shallow band's share of the glint

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
    {
      path: render.RenderConfig.MODELS.caveStalagmites,
      h: 2.4,
      r: 0.322,
      w: 0.396,
      spot: CORNER,
    },
    {
      path: render.RenderConfig.MODELS.caveCrystals,
      h: 1.45,
      r: 0.306,
      w: 0.387,
      spot: CORNER,
    },
    {
      path: render.RenderConfig.MODELS.caveFlowstone,
      h: 2.9,
      r: 0.286,
      w: 0.291,
      spot: FLAT,
    },
    {
      path: render.RenderConfig.MODELS.caveRubble,
      h: 1.1,
      r: 0.644,
      w: 1.166,
      spot: FLAT,
    },
    {
      path: render.RenderConfig.MODELS.caveRimstone,
      h: 0.35,
      r: 2.761,
      w: 3.851,
      spot: FLAT,
    },
    {
      path: render.RenderConfig.MODELS.caveFungus,
      h: 0.8,
      r: 0.772,
      w: 0.863,
      spot: FLAT,
    },
    {
      path: render.RenderConfig.MODELS.caveRoots,
      h: 2.2,
      r: 0.109,
      w: 0.662,
      spot: HANG,
    },
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
  // the most the north wall's foot may wander across a root curtain's width, in cells: its back is set
  // at the foot nearest the floor, so this is the widest gap left behind it
  public static inline var HANG_FLUSH = 0.12;
  // cells a curtain keeps clear of either end of its run of north face, where the outline rounds into
  // the side wall (a curtain that ran past the end of its wall stuck out of the rock beside it)
  public static inline var HANG_END = 0.3;
  // a floor prop's footprint (an ellipse of its own half width and depth, turned with it) must clear
  // the outline by this much, world units, all round: the standoff only measures the wall straight
  // behind it, and a corner rounds off across a wide one (the crystals ran into the rock, asked for)
  public static inline var PROP_CLEAR = 0.1;
  public static inline var PROP_PUSH = 0.05;     // world units a blocked prop steps out per try
  public static inline var PROP_PUSH_MAX = 1.6;  // past this it is dropped: the far wall is in the way

  // the fog-of-war mask: the tunnels' measured values, which are about the 2D visibility polygon and
  // the fog colour rather than about the masonry
  public static final MASK:render.world.VisionMaskOpts = render.sewer.SewerStyle.MASK;
}

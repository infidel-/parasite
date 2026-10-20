package render.cave;

// which spots a cave prop may be dealt to (render.cave.CaveProps). the spot PARTITIONS the table, so
// each of the four must keep at least one entry
enum CavePropSpot
{
  FLAT;   // a straight run of wall foot
  CORNER; // the angle of two walls
  HANG;   // hung down a NORTH face (the one the camera looks at) from the rock top's lip
  POOL;   // a pool cell the generator blocked (tiles.Sewers.TILE_FLOOR_POOL): one each, never dealt
}

// the light a glowing dressing piece throws: one pooled spotlight in front of its crown
// (render.cave.CaveScene) and the same glow baked into the shell round it (render.cave.CaveGeom)
typedef CaveLight = {
  color:Int,          // PALE, the glow's hue washed toward white: a saturated light tints the rock
                      // instead of lighting it (docs/3d-render.md, the biomineral's 0x8fe3b0)
  mul:Float,          // the spotlight's share of a street lamp (RenderConfig.LAMP_LIGHT.intensity)
  glow:Float,         // the baked glow at the piece, a multiple of the shell's own value
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
  ?light:CaveLight,   // the glowing pieces' light; the rest throw none
  ?pile:Bool,         // dealt as one prop and drawn as a random heap of CaveStyle.STONES
                      // (render.cave.CaveProps.pile): `path` is then the pile's name, never loaded,
                      // and r/w its footprint
}

// what a stone does in a rubble pile (render.cave.CaveProps.pile)
enum CaveStoneKind
{
  BIG;    // a boulder or a block: one to three along the wall
  SLAB;   // laid across two big ones, or tipped flat in front of the pile
  CHUNK;  // a broken piece strewn round their feet
}

// one rockfall stone, a glb of its own (models-src/cave/kit/rubble.py)
typedef CaveStone = {
  path:String,          // RenderConfig.MODELS entry
  h:Float,              // its native height off the baked glb: Models.instanced scales to it, so a
                        // stone's scale is the pile's own
  kind:CaveStoneKind,   // its part in the heap
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

  // --- the dressing's own shading (render.cave.CaveShade), folded into its materials ---
  public static inline var SHADE_JIT = 0.18;        // +/- albedo per placement, hashed off its position
  public static inline var SHADE_NOISE = 0.14;      // +/- smooth world-space noise, so the stones of one pile part
  public static inline var SHADE_NOISE_SCALE = 1.1; // noise cells per world unit: about a stone
  public static inline var SHADE_FOOT = 0.55;       // albedo where a piece meets the floor
  public static inline var SHADE_RISE = 1.2;        // world units over which it climbs back to full,
  public static inline var SHADE_RISE_H = 0.4;      // or this share of the piece's height if less
  // the crystals: a band of light climbing through the cluster, a breath under it, and glints
  public static inline var CRYSTAL_BAND_RATE = 0.025;   // rises per BASE_MS: one every ~6 s
  public static inline var CRYSTAL_BAND_H = 2.0;        // world units the band climbs, foot to above the tips
  public static inline var CRYSTAL_BAND_W = 0.3;        // world units, the band's half width
  public static inline var CRYSTAL_BAND_AMP = 0.9;      // emissive boost at the band's middle
  public static inline var CRYSTAL_BREATHE = 0.15;      // +/- emissive, slow
  public static inline var CRYSTAL_BREATHE_RATE = 0.24; // radians per BASE_MS: ~4 s a breath
  // the glint's virtual light circles the eye in view space at 0.1-1.0 of a radian off it, so it
  // sweeps every facet within ~25 degrees of facing the camera, one at a time
  public static inline var GLINT_RATE = 0.19;   // radians per BASE_MS: ~5 s a turn
  public static inline var GLINT_EDGE = 0.985;  // cos of the glint's half-width: a wink, not a sheen
  public static inline var GLINT = 0xdfe8ff;    // the glint's colour at full, before the facet's own tint
  public static inline var GLINT_MUL = 1.6;     // over the bloom threshold: a wink blooms
  public static inline var CRYSTAL_DIFFUSE_CUT = 0.85; // share of the prisms' diffuse taken away (CaveShade)

  // --- the glowing dressing's light (render.cave.CaveScene posts, render.cave.CaveGeom bake) ---
  public static inline var LIGHT_Y = 1.8;       // the spotlight's height, a multiple of the piece's crown
  public static inline var LIGHT_OUT = 1.0;     // world units in front of the piece it hangs
  public static inline var LIGHT_AIM = 0.4;     // and in front of it the beam lands, on the floor
  public static inline var LIGHT_PENUMBRA = 0.6; // mostly soft edge: a glow, not a torch's disc (0.9 thinned
                                                 // the whole cone to nothing)
  public static inline var GLOW_Y = 0.6;        // the baked glow's source height, a share of the crown
  public static inline var GLOW_R = 5.0;        // world units the baked glow reaches
  public static inline var GLOW_WRAP = 0.3;     // the share of it a face turned away still takes

  // --- the moonlight in each mouth's opening (render.cave.CaveMouthGlow) ---
  // the opening as the cave-mouth glb draws it at ObjModels' h 2.9 (scale 0.993): the dark plate's
  // front lies MOUTH_PLATE behind the arch's centre, and the hole the boulders leave in front of it
  // is about +/- MOUTH_HOLE_W across, from MOUTH_HOLE_Y0 up to MOUTH_HOLE_Y1
  public static inline var MOUTH_PLATE = 0.32;
  public static inline var MOUTH_HOLE_W = 0.62;
  public static inline var MOUTH_HOLE_Y0 = 0.3;  // under the ramp, which hides the card's bottom edge
  public static inline var MOUTH_HOLE_Y1 = 2.1;
  // the glow card stands this far behind the arch's centre: negative, IN FRONT of the boulders, so
  // the halo lies over their faces round the hole. at 0.1 behind it, the card lit only the hole the
  // boulders cut it to, and read as a flat blue panel with a hard edge
  public static inline var GLOW_CARD_BACK = -0.25;
  public static inline var GLOW_EDGE = 0.3;     // world units in from the hole's edge the rim band runs
  public static inline var GLOW_HALO = 0.6;     // and out from it the halo fades to nothing over
  public static inline var GLOW_FILL = 0.3;     // the hole's middle, a share of the rim band
  public static inline var GLOW_ALPHA = 0.16;   // additive strength at the rim, times MOUTH_COLOR
  public static inline var MOTES = 18;          // dust specks drifting out of each opening
  public static inline var MOTE_SIZE = 0.1;     // world units
  public static inline var MOTE_RATE = 0.004;   // of its path a speck covers per BASE_MS
  public static inline var MOTE_MUL = 0.6;      // a speck's brightness at full, times MOUTH_COLOR
  public static inline var MOTE_REACH = 3.5;    // world units into the cave a speck drifts
  public static inline var MOTE_SPREAD = 2.2;   // how far it fans out sideways by then, a multiple of
                                                // where it left the hole
  public static inline var MOTE_FLOOR = 0.2;    // the height it has sunk to there

  // --- the light rig (render.cave.CaveScene) ---
  public static inline var DARK = 0x05060a;   // background + fog, a shade warmer-neutral than the tunnels'
  // the fill. swept live against the cave art's built values (floor 0.0445, wall 0.0929, rock top
  // 0.1286 linear) at 7.0 / 3.0, where the normal-blind ambient was 73% of a vertical face's light
  // and the same on all four sides; brought down so the mouths' and the glows' pooled lights read
  public static inline var AMBIENT = 0x4e4d4a;
  public static inline var AMBIENT_I = 3.5;
  public static inline var HEMI_SKY = 0x5c6272;
  public static inline var HEMI_GROUND = 0x1c1814;
  public static inline var HEMI_I = 6.0;
  // moonlight down a cave mouth: cold, and pooled a little way into the cave from the mouth
  public static inline var MOUTH_COLOR = 0x8fa6c8;
  public static inline var MOUTH_REACH = 6.0;  // world units into the cave the beam aims at
  public static inline var MOUTH_BACK = 2.0;   // world units behind the mouth (over the rock) the beam starts
  public static inline var MOUTH_MUL = 0.9;
  // world units down the mouth's light the actors' fake shadows reach (render.actors.LampShadows'
  // aimed beam): long, cast INTO the cave from the opening, and only inside the light's cone. off
  // the light, MOUTH_BACK behind the mouth: at 10 they faded out a cell in front of the arch
  public static inline var MOUTH_BEAM = 16.0;
  // under the street's 0.9 (asked for: crystal bloom): a blue or violet prism keeps its hue only below
  // ~0.6 of linear luminance, so at 0.9 only the cyan ones could ever halo
  public static inline var BLOOM_THRESHOLD = 0.6;
  // the cave-mouth exit's depth in world units as render.world.ObjModels draws it (h 2.9; the glb is
  // 1.552 deep at 2.919 tall): render.cave.CaveArea.objWall stands it off the wall foot by half of it
  public static inline var MOUTH_DEPTH = 1.54;

  // --- the dressing dealt against the wall foot (render.cave.CaveProps) ---
  // r is measured off the baked glbs (half the y extent over the z extent); re-measure it whenever a
  // piece is rebuilt. the rubble pile's r and w are the footprint of the one baked pile it replaced
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
      light: {
        color: 0xa9c4f2,
        mul: 0.6,
        glow: 2.5,
      },
    },
    {
      path: render.RenderConfig.MODELS.caveFlowstone,
      h: 2.9,
      r: 0.286,
      w: 0.291,
      spot: FLAT,
    },
    {
      path: RUBBLE,
      h: 1.1,
      r: 0.644,
      w: 1.166,
      spot: FLAT,
      pile: true,
    },
    {
      path: render.RenderConfig.MODELS.caveRimstone,
      h: 0.35,
      r: 2.761,
      w: 3.851,
      spot: POOL,
    },
    {
      path: render.RenderConfig.MODELS.caveFungus,
      h: 0.8,
      r: 0.772,
      w: 0.863,
      spot: FLAT,
      light: {
        color: 0x9fe6cf,
        mul: 0.45,
        glow: 1.8,
      },
    },
    {
      path: render.RenderConfig.MODELS.caveRoots,
      h: 2.2,
      r: 0.109,
      w: 0.662,
      spot: HANG,
    },
  ];
  // the rubble pile's name (PROP_MODELS, render.cave.CaveSounds' settle)
  public static inline var RUBBLE = 'rubble';
  // the stones a pile is heaped from, heights off the baked glbs
  public static var STONES:Array<CaveStone> = [
    {
      path: render.RenderConfig.MODELS.caveBoulder,
      h: 0.687,
      kind: BIG,
    },
    {
      path: render.RenderConfig.MODELS.caveBlock,
      h: 0.611,
      kind: BIG,
    },
    {
      path: render.RenderConfig.MODELS.caveSlab,
      h: 0.258,
      kind: SLAB,
    },
    {
      path: render.RenderConfig.MODELS.caveChunk,
      h: 0.202,
      kind: CHUNK,
    },
  ];
  // a pile's heap, in shares of its footprint's half width and half depth and of its scale
  public static inline var PILE_BIG_MAX = 3;       // big stones: one up to this many, along the wall
  public static inline var PILE_BIG_X = 0.7;       // spread along the wall
  public static inline var PILE_BIG_Z = -0.5;      // set back toward it, a little into its bulge
  public static inline var PILE_BIG_LO = 0.75;     // scale band
  public static inline var PILE_BIG_HI = 1.25;
  public static inline var PILE_SLAB_PCT = 65;     // % of piles that carry a slab
  public static inline var PILE_SLAB_LIFT = 0.85;  // across two big stones: its base at this share of the
                                                   // lower one's top (at 0.55 it lay buried in them)
  public static inline var PILE_SLAB_LO = 0.5;     // scale band (the slab is 2 units long at 1)
  public static inline var PILE_SLAB_HI = 0.75;
  public static inline var PILE_TIP = 0.15;        // +/- pitch, radians, of a slab
  public static inline var PILE_CHUNK_MIN = 2;     // chunks round the feet
  public static inline var PILE_CHUNK_MAX = 6;
  public static inline var PILE_CHUNK_LO = 0.6;    // scale band
  public static inline var PILE_CHUNK_HI = 1.6;
  public static inline var PILE_CHUNK_TIP = 0.5;   // +/- pitch, radians: a chunk lies however it fell
  public static inline var PILE_SINK = 0.03;       // world units a tipped chunk sinks, so no edge floats
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
  // a basin's own band: it owns the cell it blocks, so it fills most of it (at the dressing's band a
  // blocked cell showed a basin in one corner and read as an invisible wall)
  public static inline var POOL_SCALE_LO = 1.25;
  public static inline var POOL_SCALE_HI = 1.4;
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

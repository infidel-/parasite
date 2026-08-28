package render.facility;

import citygen.CityConfig;
import render.world.IndoorMaskOpts;
import render.world.VisionMaskOpts;

// every art and tuning constant for the facility area kind, in one file, the way
// render.wild.WildStyle and render.sewer.SewerStyle carry theirs. no instances and no per-area
// variants: there is exactly one facility look, so the swappable render.world.AreaStyle form the
// city needs would be a class with one implementation
class FacilityStyle
{
  // ---- the shell -------------------------------------------------------------------------------

  // wall height, world units. 1.5 CELLS, i.e. a single storey, which is what the area IS.
  //
  // it is HIGHER than the tunnels' 3.0 on purpose and that has a cost the tunnels never paid: at the
  // facility camera's shallow end a 6-unit wall hides 6 / tan(51 degrees) = 4.9 units of ground
  // behind it, 1.2 cells, and a corridor is only 3 cells wide. the whole reason SOUTH-facing faces
  // fade with the roof (see REVEAL_MS) is to buy this height back — outdoors the height is what
  // makes the thing read as a building rather than a kerb, and indoors it is not there
  public static inline var WALL_H = 6.0;
  // the roof surface, and the ceiling from underneath once the interior roof has faded off
  public static inline var ROOF_Y = WALL_H;

  // how thick a wall actually is, world units — HALF a cell, not the whole one it occupies on the
  // grid. the grid says a wall cell is impassable and that is a gameplay fact; how much of the cell
  // the masonry fills is a render one, and filling all 4 units made every doorway a tunnel and every
  // window a 4-deep slot you could see down. what the slab does not cover comes back as FLOOR, so
  // the cell is still fully painted (see FacilityGeom.strips)
  public static inline var WALL_T = CityConfig.CELL * 0.5;
  // and glazing at a QUARTER, because a glazed panel is not a concrete wall. it also buys the jamb
  // for nothing: a 1-unit slab sits strictly inside the 2-unit wall that bounds its run, so the
  // wall's own butt cap IS the reveal return and the run's ends close without a case of their own
  public static inline var GLASS_T = CityConfig.CELL * 0.25;

  // ---- textures --------------------------------------------------------------------------------

  public static inline var WALL_EXTERIOR = 'textures/facility/wall-exterior.png';
  // the two INSIDE faces, picked off the surface of the cell a face looks into (Surf.LINO is a
  // corridor, anything else indoors is a room). the corridor's file is still called wall-interior:
  // it was the one interior wall before the split, and its prompt already asked for a laboratory
  // CORRIDOR, so it is the art that did not have to be repainted
  public static inline var WALL_CORRIDOR = 'textures/facility/wall-interior.png';
  public static inline var WALL_ROOM = 'textures/facility/wall-room.png';
  public static inline var WALL_HANGAR = 'textures/facility/wall-hangar.png';
  public static inline var ROOF = 'textures/facility/roof.png';
  public static inline var FLOOR_TILE = 'textures/facility/floor-tile.png';
  public static inline var FLOOR_LINO = 'textures/facility/floor-lino.png';
  public static inline var FLOOR_CONCRETE = 'textures/facility/floor-concrete.png';
  // the lab benches: the black epoxy worktop (its top face AND its edge band) and the casework
  // cabinet fronts under it. two textures rather than a generated prop, because a bench IS a box —
  // see render.facility.FacilityTables for why the whole run is merged geometry
  public static inline var BENCH_TOP = 'textures/facility/bench-top.png';
  public static inline var BENCH_BODY = 'textures/facility/bench-body.png';
  public static inline var WINDOW_LIT = 'textures/facility/window-ribbon-lit.png';
  // the aluminium capping that tops a window run, and closes its reveal from above and below. its
  // own texture because the run used to cap in ROOF and read as a strip of bitumen and gravel lying
  // on the glass — and painted flat, with no lengthwise ribs, because it takes world-aligned UVs
  // like every other horizontal surface here and a run along +x and one along +z must sample alike
  public static inline var WINDOW_HEAD = 'textures/facility/window-head.png';
  // each of these holds the COMPLETE shut pair, left leaf in u 0..0.5 and right in 0.5..1 — see the
  // leaf geometry in render.facility.FacilityDoors for why one image serves both halves
  public static inline var DOOR_GLASS = 'textures/facility/door-glass.png';
  public static inline var DOOR_CABINET = 'textures/facility/door-cabinet.png';
  public static inline var DOOR_METAL = 'textures/facility/door-metal.png';
  // the hangar's roll-up shutter (Const.TILE_HANGAR_DOOR). a WALL texture, not a door prop: that
  // strip is not an objects.Door and never opens
  public static inline var DOOR_SHUTTER = 'textures/facility/door-hangar.png';
  // the outdoors reuses the city's ground art: a compound's asphalt, pavement and lawn read the same
  // as a street's, and nothing in this phase asks them to differ. the parking bay markings are the
  // one outdoor thing that IS specific, and they arrive with the lot pass
  public static inline var GROUND_ROAD = 'textures/city/ground-asphalt.png';
  public static inline var GROUND_WALKWAY = 'textures/city/ground-walkway.png';
  // the parking lot is ASPHALT and not the city's alley, which is what it started as because the
  // generator fills the whole area with TEMP_ALLEY. measured as built, linear: alley 0.0226 is the
  // DARKEST surface in the game — painted to be a slot between two buildings, where it is small and
  // wants to be a hole. Out here it is a 40-cell apron and the biggest thing in the frame, and at
  // 0.0226 against a roof of 0.0275 the building was only 1.22x its own ground and the whole compound
  // read black. asphalt is 0.0329, so the ladder becomes lot 0.0329 < grass 0.0414 < walkway 0.0680
  // and the building sits as a darker mass ON its tarmac instead of dissolving into it
  public static inline var GROUND_LOT = 'textures/city/ground-asphalt.png';
  // the park lawn, and NOT `city/grass`, which is what it started as. that one is a CUTOUT and not a
  // ground tile: 47.6% of it is fully transparent by design ("roughly 45 percent of the tile is left
  // as the untouched flat grey background", says its own prompt), ragged islands of weeds meant to be
  // laid OVER paving by render.world.Lawns with a CoverageMask. used as a standalone opaque surface
  // its transparent half renders as flat scrubbed grey between the clumps — the park read as holes.
  // a full-coverage lawn is a different painting, not a setting
  public static inline var GROUND_GRASS = 'textures/facility/grass.png';

  // world units per texture repeat. none of them is a multiple of CELL (4): a period that lands on
  // the cell grid puts the same point of the tile on every grid line and the lattice reads through
  // the art — the mistake render.sewer.SewerStyle records for FLOOR_TILE/LEDGE_TILE at exactly 8.0
  public static inline var WALL_TILE = 6.0;
  public static inline var FLOOR_TILE_SZ = 7.0;
  public static inline var ROOF_TILE = 9.0;
  public static inline var GROUND_TILE = 9.0;
  // the roll-up shutter TILES rather than mapping across its run: the slats are uniform, so
  // world-aligned UVs cost nothing and no run detection is needed. the art holds 24 slats per repeat,
  // so 7.0 puts the slat pitch at 0.29 world units and ~20 slats up a 6-unit wall — and 7.0 is not a
  // multiple of CELL, for the lattice reason the tile sizes above all carry
  public static inline var SHUTTER_TILE = 7.0;
  // the window capping. 3.0 rather than anything nearer the 1-unit band it paints, so the grain does
  // not repeat three times inside a single cell — and not a multiple of CELL, for the lattice reason
  // above
  public static inline var HEAD_TILE = 3.0;

  // ---- benches ---------------------------------------------------------------------------------

  // worktop height, world units. WALL_H 6.0 is one 3 m storey, so a unit is half a metre and this is
  // a 1 m bench — a shade over the 0.9 m a real one stands at, which is deliberate: at this camera's
  // 51 degrees a bench has to clear the floor enough to read as a solid before its own worktop hides
  // it, and the decorations that stand ON it (see FacilityTables.groundY) need somewhere to stand
  public static inline var BENCH_H = 2.0;
  // how thick the worktop slab is, i.e. the band of BENCH_TOP drawn down the outside of the run.
  // the top OVERHANGS the casework by BENCH_LIP, which is the whole silhouette: without it a bench
  // is one flat-sided box and reads as a low wall
  public static inline var BENCH_EDGE = 0.25;
  // and the overhang is applied by growing the WORKTOP outward, never by pulling the casework in.
  // that is a UV decision, not a modelling one: an inset body starts BENCH_LIP past the cell
  // boundary, so its world-aligned u starts mid-door and the first and last cabinet of every run are
  // cut. Growing the top instead leaves the body spanning exact cell boundaries, so the door rhythm
  // below is whole on every face of every block shape and no texture layout can break it
  public static inline var BENCH_LIP = 0.2;
  // the worktop's repeat. not a multiple of CELL, for the lattice reason the tile sizes above carry
  public static inline var BENCH_TOP_TILE = 5.0;
  // the casework's HORIZONTAL repeat, and it is deliberately HALF A CELL — the one texture period in
  // this file that IS on the grid, against the blanket rule above. That rule is about art whose
  // features are irregular, where a cell-aligned period puts the same stain on every grid line and
  // the lattice reads through. Cabinetry is the opposite case: the repeat IS a regular rhythm, the
  // art holds two doors, and landing them on the cell grid is exactly what stops a run ending on
  // half a drawer. 4.0 / 2.0 gives 4 doors a cell at 1.0 world unit (0.5 m) each.
  //
  // there is no matching V constant: the body spans y 0..(BENCH_H - BENCH_EDGE) and FacilityTables
  // maps v over that range directly, so v runs 0..1 up the cabinet by construction and the art's
  // bottom-up composition — toe kick, doors, the dark band under the overhang — lands whole and
  // never wraps. Two different periods on the two axes is why the body cannot use FacilityGeom.face
  public static inline var BENCH_TILE = CityConfig.CELL * 0.5;

  // ---- doors -----------------------------------------------------------------------------------

  // the opening's height, world units, out of a WALL_H of 6.0. the art is SQUARE and holds the whole
  // pair, so this also fixes the width: 4.0 tall over a 4-unit cell is 1:1 and nothing is stretched.
  // at the game's scale (WALL_H 6.0 is one storey) that is a 2 m x 2 m opening, which is what a
  // corridor pair of swing doors actually measures
  public static inline var DOOR_H = 4.0;
  // leaf thickness. it exists only so the top and outer edges have something to draw at this
  // camera's 51 degrees — a bare quad would vanish edge-on the moment a door swung
  public static inline var DOOR_T = 0.16;
  // how long a leaf takes to swing its 90 degrees, in BASE_MS multiples. well under one turn:
  // objects.Door.turn auto-closes after 2 of them, so a swing that outlasted a turn would still be
  // opening when the model had already shut it
  public static inline var DOOR_SWING_MULT = 0.6;
  // bounding-sphere radius render.Models.cull tests each leaf against. measured off the swing, not
  // guessed: the centre stored for the test is the SHUT centre and never moves, while the open leaf's
  // far tip reaches 2.83 units from it, so 3.0 is the smallest radius that cannot pack out a leaf
  // that is still on screen
  public static inline var DOOR_CULL_R = 3.0;

  // ---- wall-mounted objects --------------------------------------------------------------------

  // a vent grille hangs centred THIS high up the masonry, at THIS fraction of a sprite quad
  // (render.particles.Sprites.SIZE, 3.0 units), and stands THIS far proud of the wall face — the
  // same nudge a bullet hole takes, and for the same reason: the quad has to clear the opaque wall
  // behind it rather than z-fight it.
  //
  // the SCALE is of the quad and the art fills 38 of its 64 atlas pixels, so the grille itself comes
  // out 1.78 units wide. at the game's scale (WALL_H 6.0 is one 3 m storey, so a unit is half a
  // metre) that is a 0.9 m cover spanning 0.53-1.47 m up the wall — a duct low enough to slither
  // into, which is what the object does
  public static inline var MOUNT_Y = 2.0;
  public static inline var MOUNT_SCALE = 1.0;
  public static inline var MOUNT_PROUD = 0.12;

  // ---- windows ---------------------------------------------------------------------------------

  // the window art's own width:height over its OPAQUE CONTENT — measured off the source, not the
  // canvas, which is square and mostly cut away. the quad is sized FROM this and never stretched, so
  // the art's aspect is the only thing that decides how tall a run stands: a 3-cell run is 12 world
  // units wide and comes out 12 / 2.9 = 4.14 tall on a sill of 0.93, a 2-cell run is 8 wide and 2.76
  // tall on a sill of 1.62, and both leave real wall above the head.
  //
  // it was 2.02, which is what the first art measured, and at that aspect a 3-cell run stood 5.94 in
  // a 6.0 wall: glazing floor to ceiling, its head 0.03 under the roof deck with no sill ledge at all
  // (the sill cap skips under 0.05). 28 of the 49 runs a generated area deals are 3-cell, so that was
  // the common case, not the corner one. the fix is the ART's proportions — clamping the height in
  // code cannot work, because the hole through the wall is cut from this same arithmetic and a
  // shorter pane in a full-height opening is just a gap
  public static inline var WINDOW_ASPECT = 2.90;
  // emissive strength on the lit pane. every window is lit in this phase — the place is staffed at
  // night, and a dark facility gives the player nothing to aim the "see into the room" read at.
  //
  // it is also what makes the panes GLOW from outside, and that is arithmetic rather than taste: the
  // bloom pass runs on the composer's LINEAR target, before OutputPass tone-maps, so a pane blooms
  // when texel_linear * this clears BLOOM_THRESHOLD 0.9. the art's glass band is sRGB 144-207 (see
  // render.facility.FacilityGeom.addPane, which reads the same histogram for its alpha split) =
  // linear 0.26-0.62, so 0.55 put the brightest glass texel at 0.34 and NOTHING crossed. 2.2 lands
  // the band at 0.57-1.36 — the bright half of every pane blooms, the dark frame never does, and the
  // halo falls on the facade around the opening, which is the "the building is occupied" read the
  // ground spill alone could not give
  public static inline var WINDOW_EMISSIVE = 2.2;

  // ---- the reveal ------------------------------------------------------------------------------

  // how long the shell takes to fade once the player is inside a structure or looking into one, in
  // BASE_MS multiples. FAST on purpose: this is not an atmosphere beat, it is the view getting out
  // of the player's way, and anything slower reads as a lag between walking in and being able to see
  public static inline var REVEAL_MULT = 0.5;
  // what the interior roof fades TO. the ROOF ONLY — the south-facing wall faces used to fade with
  // it to 0.20 and no longer do, because a face cannot be judged an occluder by its NORMAL: see the
  // header of render.facility.FacilityArea.ease
  public static inline var ROOF_FADE = 0.0;
  // how far from a window the player can be and still have it count as looking in, in cells. this is
  // what makes item (a)'s "see into the room" work without a separate action: standing at a pane and
  // having line of sight to it reveals that structure, and the vision mask then governs how much of
  // the inside is actually drawn
  public static inline var PEEK_CELLS = 3;

  // bounding-sphere radius render.Models.cull tests each park plant against, world units. ONE radius
  // per batch, so the TALLEST prop sets it — the broadleaf in leaf at h 9.5, the same number the
  // wilderness arrived at for the same tree
  public static inline var PROP_CULL_R = 9.0;

  // ---- lamps and fixtures ----------------------------------------------------------------------

  // the compound's own lamp: a modern slim mast with a shrouded downlight head. world HEIGHT, which
  // through render.Models.instanced is also its width (the glb's bbox is 0.102 x 1 x 0.226, so the
  // head reaches 1.33 units across the mast). 5.9 is not a round number and is not meant to be — it
  // is what puts the HEAD at the city street bulb's own height, see LAMP_HEAD_Y
  public static inline var LAMP_H = 5.9;
  // where the head sits in the glb's own local frame, as a fraction of its height, with the model
  // recentred the way render.Models.normalize leaves it (footprint centred in X/Z, base at y = 0).
  // MEASURED off the built glb, not guessed: the mast stands at z -0.062 and the housing hangs off
  // it toward +z, so a bulb placed at the model's centre would hang in the air beside the fixture.
  // LAMP_H * LAMP_HEAD_Y = 5.60 = CityConfig.CELL * RenderConfig.LAMP_LIGHT.yMul, which is what the
  // whole scale is chosen for: render.actors.LampShadows scales an actor's fake ground shadow by
  // refY / post.y, so a facility mast lands on the street lamp's own 1.0 and needs no tuning of its own
  public static inline var LAMP_HEAD_Y = 0.95;
  public static inline var LAMP_HEAD_Z = 0.06;
  // one mast every this many cells along a lit line, gated on (col + row), which spaces a run without
  // needing to detect where the run starts or ends
  public static inline var LAMP_SPACING = 6;
  // cool white LED, deliberately OFF the moon's 0x8294c0 and off the street's sodium amber: this is a
  // maintained compound, not a residential street. shared by the masts, the ceiling fixtures and
  // every additive quad render.facility.FacilityGlow draws, so the whole facility reads as one
  // lighting installation
  public static inline var LAMP_COLOR = 0x9db4d4;
  // bounding-sphere radius render.Models.cull tests each mast against. the head reaches 0.67 units
  // off the mast and the thing is LAMP_H tall, so half the height plus that clears it
  public static inline var LAMP_CULL_R = 3.6;
  // where the light shaft starts along the bulb->ground axis (render.LightConeOpts.startFrac). the
  // street's own value is -0.1, which lifts the cone a tenth of the bulb height ABOVE the bulb —
  // right for a lamp whose glowing hood sits over its light position, wrong here, where LAMP_HEAD_Y
  // already puts bulbY exactly on the lens plane: it started the shaft at 6.17, a third of a unit
  // clear of the top of the whole post, and the cone read as hanging in the air over the lamp
  public static inline var LAMP_CONE_START = 0.0;

  // how far under the roof deck a ceiling fixture's bulb hangs
  public static inline var CEIL_DROP = 0.2;
  // intensity multiplier on the pooled spotlight for a CEILING fixture, and the one number in this
  // section that must not be read as arbitrary. INDOOR.direct scales EVERY direct light indoors —
  // the shader anchor cannot separate the moon from a spotlight (render.world.IndoorMask.patch) — so
  // a fixture at mul 1.0 arrives at 0.3 of a street lamp. 1 / INDOOR.direct is the compensation, and
  // reaching for RenderConfig.LAMP_LIGHT.intensity instead is chasing the wrong knob: that one is
  // shared with the city and the tunnels
  public static inline var CEIL_MUL = 3.3;

  // ---- the additive glow layer (render.facility.FacilityGlow) ----------------------------------

  // ONE merged mesh, ONE material, three kinds of quad, and they differ only in BRIGHTNESS — which
  // rides the per-vertex grey channel render.world.MeshBuf.quadC already carries. so the hue and the
  // HDR multiplier are set once here and each quad scales them.
  //
  // the two C_* below C_HEAD are SMALL, and the arithmetic that says why is worth keeping because a
  // first pass got it wrong by two orders of magnitude. predicting them from LAMP_COLOR's own
  // Y_linear 0.435 gave C_POOL 0.25, which MEASURED at Y 0.530 against a lit lab floor's 0.0168 —
  // THIRTY-ONE TIMES the surface it was supposed to be lying on, a white blob with no shape left in
  // it. the error is not in the blend, it is in the surfaces: this game's art is painted very dark
  // (floor albedo 0.0607 linear) and its interiors render around Y 0.017, so ANY additive quad
  // authored against a 0..1 intuition annihilates them.
  //
  // so these are fitted off the built frame, not derived: a quad's rendered luminance came out
  // ~2.1 * C, which makes C 0.43 the line where BLOOM_THRESHOLD 0.9 is crossed. the ceiling panel
  // sits at 1.0 and is MEANT to bloom — it is a fitting, the brightest thing in the room; the pool
  // and the spill sit far under it and are meant to read as lit ground. re-measure rather than
  // re-derive if the hue moves: blue weighs only 0.0722 linear, so a cooler LAMP_COLOR silently
  // stops the panel blooming.
  //
  // there is NO lamp-head quad here any more. it was one, and it was the wrong tool: a FRONTAL quad
  // is fixed-yaw by construction, so on a mast that yaws to face the surface it lights the card sat
  // across the housing at whatever angle the world happened to give it and read as a sticker. the
  // head glows off the glb's own EMISSIVE MAP now (models-src/facility-lamp-post-emissive.png), the
  // way a street lamp's lens does — real geometry, correct from every angle, and it blooms
  public static inline var GLOW = 2.6;
  public static inline var C_PANEL = 1.0;
  public static inline var C_POOL = 0.012;
  public static inline var C_SPILL = 0.02;
  // how far a ground-lying glow floats over the surface it lies on. under the tactical grid's own
  // 0.06 so an impassable hatch still reads on top of a lit floor
  public static inline var GLOW_Y = 0.04;
  // the room pair — the ceiling panel and the pool under it — off for now. the fittings themselves
  // (render.facility.FacilityLamps.ceilings) still claim their spotlight slots and still light the
  // room; this is only the two DRAWN quads. an inline false, so the block folds out of the build
  public static inline var CEIL_GLOW = false;
  // the ceiling panel: a light fitting seen from ABOVE, through the roof that faded when the player
  // walked in. its own quad in the merged mesh and NOT part of FacilityGeom.Shell.roof, so the fade
  // does not take it with the deck. from outside the solid roof depth-rejects it — additive with
  // depthWrite off still depth-TESTS — so it is only ever seen from inside
  public static inline var PANEL_W = 2.4;
  public static inline var PANEL_H = 1.0;
  public static inline var PANEL_DROP = 0.05;
  // and the pool it throws, laid over the room's own rect inset by this. the pooled spotlight only
  // reaches ~1 cell (a bulb at 5.8 through LAMP_LIGHT.angle) and only the 12 rooms nearest the player
  // ever claim a slot, so this quad is what makes EVERY lit room read as lit
  public static inline var POOL_INSET = 2.0;
  // how far out from a window or an exterior door the ground brightens. the quad starts at the wall
  // CELL CENTRE rather than at the outer face, so its own near fade is buried inside the masonry and
  // only the bright middle and the outward falloff are ever visible
  public static inline var SPILL_DEPTH = 8.0;

  // ---- the scene -------------------------------------------------------------------------------

  public static inline var SKY = 0x0a0e14;          // background + fog. a shade cooler than the wilderness
  public static inline var FOG_NEAR = 200.0;
  public static inline var FOG_FAR = 460.0;
  public static inline var BLOOM_THRESHOLD = 0.9;   // the street's own level; only lit panes glow here

  // ---- line of sight ---------------------------------------------------------------------------

  public static final MASK:VisionMaskOpts = {
    // between the tunnel's 0.18 and the wilderness's 0.10. a facility is BOTH cases at once — an
    // open lot where a hidden wedge is one shadow in a lit field, and a corridor where the hidden
    // part is most of the frame — so it takes the value in the middle rather than either extreme
    hidden: 0.14,
    // lit panes are the only additive-ish thing here and they are emissive, not additive; kept at
    // the tunnels' hard floor so a muzzle flash or a gas puff behind a wall is cut the same way
    hiddenAdd: 0.0,
    px: 8,
    blur: 0.5,
    wallFade: 0.5,
    // a facility area is ringed by road, lot and grass right out to the border, like the wilderness
    // and unlike a tunnel, so the outer rim has to dissolve into the background or it draws a hard
    // line with nothing past it
    edgeFade: 1.0,
    wobble: 0.3,
    step: 0.05,
    // DERIVED from CAMERA_FACILITY the way the other two presets are derived from theirs, and it has
    // to sit off screen: at the facility camera's far end the frame reaches ~13 cells at the corner,
    // so 18 puts the square range bound 5 cells past it. inside a building the sweep is cheap (walls
    // stop it almost immediately); out on the lot it is an open field like the wilderness
    r: 18,
  };

  // ---- indoor lighting -------------------------------------------------------------------------

  // the facility is the first area kind that is BOTH indoors and outdoors at once, so it is the first
  // to need render.world.IndoorMask. a tunnel is wholly interior and a wilderness wholly open; each
  // tunes one scene rig and is done
  public static final INDOOR:IndoorMaskOpts = {
    // the vision mask's own, and it is NOT the free knob it looks like: `grow` below is a QUARTER of
    // a cell, so anything under 4 texels per cell paints a sub-texel overhang, canvas antialiasing
    // resolves it as partial coverage, and the boundary is already halved before the blur runs.
    // measured at px 2: a lab floor cell next to its own wall came back 194 of 255 — 24% outdoors,
    // standing in the middle of a room. 8 keeps the overhang on a whole texel with room to spare
    px: 8,
    // the doorway crossfade, and the only transition this has: an actor walking through a door is
    // relit over roughly this world distance either side of the threshold, which at 1 unit = 0.5 m is
    // a metre end to end. there is no eased `t` anywhere in the feature.
    //
    // IT IS BOUNDED ABOVE BY THE WALL THICKNESS, which is what pins it this small. a wall slab is
    // WALL_T = 2 units through, and the two faces of it have to land on opposite ends of this ramp —
    // so a blur anywhere near the slab's own thickness cannot separate them at all. measured at 1.4:
    // the inner face came back 0.50 and the outer face 0.33, i.e. the whole wall lit halfway indoors
    blur: 0.5,
    // PAST the inner face of the wall slab by that blur, not merely to it. the emitter centres a slab
    // of WALL_T in its cell, so WALL_T / 2 is the distance from the cell edge to the inner face — and
    // stopping there puts the face on the ramp's MIDPOINT, which is exactly the 0.5 above. another
    // `blur` further out puts the inner face a sigma inside the region (~0.84 indoors) and leaves the
    // outer face three sigma outside it (~0)
    grow: WALL_T * 0.75,
    // "the lights are on": a cool fluorescent, brighter than the moonlit lot outside, against which
    // the phase-3b ceiling fixtures then read as local pools rather than as the only light in the
    // room. it REPLACES the scene's ambient (0x46536b at 1.35) and hemisphere (0x56668c at 1.1)
    // together, so it is tuned against the pair and is necessarily the larger number
    ambient: 0x9fb0b4,
    intensity: 2.4,
    // how much of the moon gets through a roof that casts no shadow (render.facility.FacilityGeom
    // .addRoof says why it cannot). not zero: a wall with no directional term at all loses its lit
    // side, and with it the one cue that a room is a box.
    //
    // IT SCALES EVERY DIRECT LIGHT, NOT JUST THE MOON — the shader anchor cannot separate them, see
    // render.world.IndoorMask.patch. so a ceiling fixture hung in phase 3b is scaled by exactly this
    // number and has to be tuned WITH it in view; reading its light as too dim and reaching for the
    // fixture's own intensity is chasing the wrong knob
    direct: 0.3,
  };
}

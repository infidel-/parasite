package render.facility;

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

  // ---- textures --------------------------------------------------------------------------------

  public static inline var WALL_EXTERIOR = 'textures/facility/wall-exterior.png';
  public static inline var WALL_INTERIOR = 'textures/facility/wall-interior.png';
  public static inline var WALL_HANGAR = 'textures/facility/wall-hangar.png';
  public static inline var ROOF = 'textures/facility/roof.png';
  public static inline var FLOOR_TILE = 'textures/facility/floor-tile.png';
  public static inline var FLOOR_LINO = 'textures/facility/floor-lino.png';
  public static inline var FLOOR_CONCRETE = 'textures/facility/floor-concrete.png';
  public static inline var FLOOR_GRATE = 'textures/facility/floor-grate.png';
  public static inline var WINDOW = 'textures/facility/window-large.png';
  public static inline var WINDOW_LIT = 'textures/facility/window-large-lit.png';
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
  // the drain grate is ONE cell of art and replaces the floor on that cell, so it maps 0..1 across
  // the cell rather than tiling by world position
  public static inline var GRATE_TILE = 4.0;

  // ---- windows ---------------------------------------------------------------------------------

  // the window art's own width:height over its opaque content. the quad is sized FROM this and never
  // stretched: a 3-cell run is 12 world units wide, so it stands 12 / 2.02 = 5.94 tall against a
  // WALL_H of 6.0 and reads floor to ceiling, while a 2-cell run is 8 wide and 3.96 tall and sits on
  // a real sill. the two sizes come free out of one image because the generator deals both runs
  public static inline var WINDOW_ASPECT = 2.02;
  // how far the pane stands off the wall plane, world units. a real gap and not polygonOffset:
  // render.RenderConfig.OVERLAY_EPS records three separate failures of the latter
  public static inline var WINDOW_EPS = 0.02;
  // emissive strength on the lit pane. every window is lit in this phase — the place is staffed at
  // night, and a dark facility gives the player nothing to aim the "see into the room" read at
  public static inline var WINDOW_EMISSIVE = 0.55;

  // ---- the reveal ------------------------------------------------------------------------------

  // how long the shell takes to fade once the player is inside a structure or looking into one, in
  // BASE_MS multiples. FAST on purpose: this is not an atmosphere beat, it is the view getting out
  // of the player's way, and anything slower reads as a lag between walking in and being able to see
  public static inline var REVEAL_MULT = 0.5;
  // what the interior roof and the south-facing wall faces fade TO. the roof goes all the way; the
  // walls stop short of it so the floor plan still has edges — the same call render.Occlusion makes
  // for a faded city building at 0.22
  public static inline var ROOF_FADE = 0.0;
  public static inline var WALL_FADE = 0.20;
  // how far from a window the player can be and still have it count as looking in, in cells. this is
  // what makes item (a)'s "see into the room" work without a separate action: standing at a pane and
  // having line of sight to it reveals that structure, and the vision mask then governs how much of
  // the inside is actually drawn
  public static inline var PEEK_CELLS = 3;

  // bounding-sphere radius render.Models.cull tests each park plant against, world units. ONE radius
  // per batch, so the TALLEST prop sets it — the broadleaf in leaf at h 9.5, the same number the
  // wilderness arrived at for the same tree
  public static inline var PROP_CULL_R = 9.0;

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
}

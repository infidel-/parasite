package render.facility;

import citygen.CityConfig;
import render.world.IndoorMaskOpts;
import render.world.PropEnvOpts;
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
  // how far the window capping sinks below that plane. a window run's wall top is capped in
  // WINDOW_HEAD rather than roof (see FacilityGeom.capTop) and that is right ONLY once the deck has
  // faded — from outside it is a strip of aluminium lying IN the bitumen, 0.78 units of it left
  // uncovered by the coping at every glazed cell. so the deck's own art is laid over the capping in
  // the FADING buffer and the capping drops out of its plane to let it: the aluminium sinks and not
  // the deck, because the deck has to stay dead flat with the rest of itself while the capping's
  // neighbour is a rim band it may sit 0.02 under unseen. a physical gap and not polygonOffset —
  // docs/3d-render.md records that failing three times on coplanar overlays
  public static inline var HEAD_DROP = 0.02;
  // where the masonry STARTS, world units — below zero, and below every surface in the compound.
  //
  // an indoor floor is y = 0 and so is the pavement, but KERB_DROP puts the road, the park and the
  // LOT a fifth of a unit under them. that is invisible against a lab building, which the generator
  // rings with a 2-cell pavement apron; the HANGAR is the one structure with no apron at all
  // (game.FacilityAreaGenerator.generateHangar leaves that write commented out), so every cell
  // touching it is asphalt at -KERB_DROP while its wall face started at 0 — a 0.2 slot of daylight
  // round the whole building, reported as the walls hanging in the air.
  //
  // THE MASONRY GOES DOWN TO MEET THE ASPHALT AND THE GROUND DOES NOT STEP UP TO MEET THE MASONRY.
  // that is how a building beside a lower road is actually built, it is what render.facility
  // .FacilityEntry already did to the guard booth standing on the same lot, and it is one constant
  // rather than a per-face test of what surface each side happens to be. everywhere else the skirt
  // is simply buried: it hangs UNDER an opaque pavement or floor plane whose top edge is its own
  // top edge, and a camera pitched 51 degrees down cannot see under a step
  public static inline var WALL_BASE = -KERB_DROP;

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

  // ---- the parapet ring ------------------------------------------------------------------------
  //
  // the exterior cladding continuing above the roof deck, capped by a coping band. it is what gives
  // the compound a ROOFLINE: without it the wall stops dead at ROOF_Y and every building reads as a
  // flat lid from a camera pitched 51 degrees down.
  //
  // the whole design turns on PARAPET_INSET being a CONSTANT and not the cell's own
  // (CELL - thick) / 2. following the slab would jog the ring half a unit in and out at every window
  // run — GLASS_T is half WALL_T — and the generator deals ~45 runs, i.e. ~90 jogs, each needing a
  // step cap or becoming a hole. a sawtooth in the building's silhouette line does not read as a
  // recessed window bay, it reads as the roof sagging at every window. holding it constant also
  // takes the plane-mismatch case out of the joint test: two bands meeting at a cell boundary are
  // ALWAYS collinear, so a window run's ends need nothing at all
  public static inline var PARAPET_INSET = (CityConfig.CELL - WALL_T) / 2;
  // how thick the ring is, inward from that plane. bounded at BOTH ends and neither is taste:
  // at least (WALL_T - GLASS_T) / 2 = 0.5 or a band over a glazed cell has no masonry under its
  // inner half, and strictly under PARAPET_INSET or a corner cell's x-band, trimmed at both ends,
  // comes back inside out
  public static inline var PARAPET_T = 0.6;
  // how far the cladding rises above the deck, and the coping band on top of it. together they put
  // the roofline at 7.35, which is 1.35 over ROOF_Y — read WALL_H's own header before raising it,
  // because every unit here is another 1/tan(51 degrees) = 0.81 units of lot the wall hides
  public static inline var PARAPET_H = 1.10;
  public static inline var COPING_H = 0.25;
  // and how far the coping oversails the cladding, each face. it is what makes the cap read as a
  // separate capping rather than as the top of the wall
  public static inline var COPING_OUT = 0.12;

  // ---- the hangar's barrel vault ---------------------------------------------------------------
  //
  // the hangar takes no parapet and never did: a shed is not a parapeted box, and its roofline is
  // the arched sheet-metal vault render.facility.FacilityRoof.vault springs between its two long
  // walls. THE SECTION IS A CIRCULAR SEGMENT, derived from the two numbers below and nothing else —
  // for a chord S and a segment height H the tangent-chord angle gives tan(theta / 2) = H / (S / 2),
  // so theta = 2 * atan(2H / S) is HALF the subtended angle and R = (S / 2) / sin(theta). the arc is
  // then a small piece of a big circle rather than anything near a semicircle: on the generated
  // hangar, MEASURED (11 cells across the short axis, so S = 38), these give H 3.42, R 54.5 and
  // 40.8 degrees of arc, less than a quarter of the 180 a half-round barrel would take. the rise
  // FRACTION is what fixes that angle and the span only scales it, so every hangar arches alike
  public static inline var HANGAR_RISE_FRAC = 0.09;
  // and a ceiling on it, world units, because the rise is what the compound PAYS for: every unit of
  // height hides another 1 / tan(51 degrees) = 0.81 units of lot behind the building — read WALL_H's
  // own header — and the hangar is the tallest thing on the site with a car park behind it
  public static inline var HANGAR_RISE_MAX = 7.5;
  // how many strips the arc is cut into. the vault is emitted as a SHARED-VERTEX grid so
  // computeVertexNormals averages each seam into the radial normal, which is what makes a curve read
  // as a curve; the count is only about the silhouette, and 16 puts the facet step at 2.6 degrees
  public static inline var HANGAR_ARC_SEG = 16;
  // world units per repeat on the vault. the deck's own period, so the sheeting keeps the ribbed
  // roof's density level with the ground tiling's 512 / GROUND_TILE = 57 texels per world unit
  public static inline var HANGAR_ROOF_TILE = ROOF_TILE;

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
  // and the hangar's, which is not that roof at all: a shed is sheeted, not membraned. it SHARES its
  // source png with city/roof-metal and carries a lift of its own — that entry's note says why — and
  // the art needed none of the usual argument, because ribs one way and lap seams the other IS a
  // curved roof's fall line and its sheet laps
  public static inline var ROOF_HANGAR = 'textures/facility/roof-hangar.png';
  public static inline var FLOOR_TILE = 'textures/facility/floor-tile.png';
  public static inline var FLOOR_LINO = 'textures/facility/floor-lino.png';
  public static inline var FLOOR_CONCRETE = 'textures/facility/floor-concrete.png';
  // the lab benches: the black epoxy worktop (its top face AND its edge band) and the casework
  // cabinet fronts under it. two textures rather than a generated prop, because a bench IS a box —
  // see render.facility.FacilityTables for why the whole run is merged geometry
  public static inline var BENCH_TOP = 'textures/facility/bench-top.png';
  public static inline var BENCH_BODY = 'textures/facility/bench-body.png';
  // the three pieces of room furniture that used to be upright 2D sprites (render.facility
  // .FacilityDeco). ONE TEXTURE PER FACE, not per family: the first build dressed a whole unit in
  // one sheet and every face it was wrong on was wrong in the same way — book spines lying across
  // a bookcase's top and running down its sides, cardboard boxes wearing the shelving's steel.
  //
  // two of them map 0..1 over their face rather than tiling, and both HAVE to: the shelving's end
  // is one authored frame with holes in it, and the bookcase front is one authored composition
  // with three different rows in it. That locks each one's face aspect to its image's — see
  // DECO_SHELF_D and DECO_BOOKCASE_W, which are DERIVED and not chosen
  public static inline var DECO_SHELF_SIDE = 'textures/facility/deco-shelf-side.png';
  public static inline var DECO_SHELF_TOP = 'textures/facility/deco-shelf-top.png';
  public static inline var DECO_BOX = 'textures/facility/deco-box.png';
  public static inline var DECO_BOOKCASE_FRONT = 'textures/facility/deco-bookcase-front.png';
  public static inline var DECO_BOOKCASE_SIDE = 'textures/facility/deco-bookcase-side.png';
  public static inline var DECO_BOOKCASE_TOP = 'textures/facility/deco-bookcase-top.png';
  // and the rack takes THREE of its own. The sides and the lid rode the shelving's perforated shelf
  // plate until a cabinet wearing shelf holes read as exactly that — a server made out of shelves.
  // All three are quadrants of one 2x2 sheet, so the cabinet's faces agree with each other
  public static inline var DECO_RACK = 'textures/facility/deco-rack.png';
  public static inline var DECO_RACK_SIDE = 'textures/facility/deco-rack-side.png';
  public static inline var DECO_RACK_TOP = 'textures/facility/deco-rack-top.png';
  // the lit glazing, ONE ART PER RUN LENGTH — three panes and two. a run maps one unit of u across
  // its whole length, so how many panes it shows is a property of the image (see WINDOW_ASPECT_2,
  // which carries the argument and the measurements)
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
  // the kerb edging that runs wherever the pavement's edge drops, and the worn traffic paint the
  // road's lane lines and the parking bays are drawn in. both the city's own files, like the three
  // grounds above
  public static inline var GROUND_BORDER = 'textures/city/ground-walkway-border.png';
  public static inline var GROUND_PAINT = 'textures/city/ground-road-paint.png';

  // --- the park lawn's two dressing layers (render.facility.FacilityLawn) ---
  // a ragged overlay of tall unmown grass laid OVER the mown lawn, and a few standing tufts inside
  // the same blobs. one flat map across a whole park reads as felt; the overlay is the
  // render.world.Lawns / render.wild.WildPatches idiom sharing their render.world.CoverageMask, and
  // the tufts are render.wild.WildGrass' own emitter and material, called rather than copied.
  // a CUTOUT like `city/grass`, not a ground tile — see its own note in textures.json
  public static inline var PATCH_LUSH = 'textures/facility/grass-lush.png';
  // world units per repeat, both axes, world-aligned, never stretched. under CELL (4) for the reason
  // Lawns' TILE carries: the art is only ~41% opaque, so a repeat WIDER than a cell leaves whole
  // cells landing on its gaps and reading as bare lawn
  public static inline var PATCH_TILE = 3.0;
  // base opacity — the wilderness's PATCH_ALPHA verbatim and NOT Lawns' 0.5, which was measured over
  // there to collapse a real value ladder into nothing a night frame can show. built, this art is
  // 0.0390 linear against the lawn's 0.0499, which composites at 0.85 to 0.0406 = 0.81x
  public static inline var PATCH_ALPHA = 0.85;
  public static inline var PATCH_Y = 0.02;       // how far the overlay floats over the lawn it covers
  // one seed per PATCH_STEP x PATCH_STEP block of lawn, placed inside its block by the hash — a
  // STRATIFIED roll, not an independent per-cell one, and the difference is the whole reason this is
  // a step and not a chance.
  //
  // an independent roll tuned to the coverage this wants (2% a cell) deals about nine seeds over a
  // park, and nine independent samples over 14 columns clump: measured over 3,600 synthetic parks at
  // the live one's size, **20% of them come back with a bare band of 5+ columns** and the worst is 10
  // of 14 — and the live park drew exactly that, all seven seeds inside three columns with the whole
  // west half left as flat felt. The lattice takes the same failure to **7%** and its worst to 8, and
  // on the live park spreads the seeds over 7 columns instead of 3. Precisely the finding
  // game.FacilityAreaGenerator already records one layer down, where uniform clump centres could not
  // cover this same park and became PARK_CLUMP_STEP.
  //
  // 7 lands 8 seeds / 21 cells / 24.3% of the lawn at the kernel below. Bigger steps thin out fast
  // (9 gives 5 seeds over 3 columns); smaller ones stop being a lattice — 5 puts 15 seeds in and
  // takes the lawn to 44%, which reads as abandoned rather than as variety.
  public static inline var PATCH_STEP = 7;
  // the coverage kernel's radius in world units, and the per-cell jitter of that radius and of its
  // centre. FEWER, BIGGER blobs — the opposite end of the same curve the wilderness sits at, and the
  // ~24% one layer changes here is roughly what its TWO layers at ~10% each change between them. it
  // must in any case stay well over CELL * 0.5, under which neighbouring kernels pinch at the waist
  // and a run of marked cells beads into a string of pearls (render.world.CoverageMask's own note),
  // and the wilderness measured 7.0 as grain from a camera 18-55 units up
  public static inline var PATCH_KERN = 11.0;
  public static inline var PATCH_KERN_JIT = 0.35;
  // the standing tufts, per cell and by what that cell is: denser inside an overgrown patch than out
  // on the mown lawn between the trees. both counts sit under the wilderness bands' 1-3, and so does
  // the height under their 0.8-1.3 — a compound park is mown, and these are what got away.
  //
  // the SPLIT is the point rather than either number. tufts only in the patches left the bare lawn
  // as flat felt, which is the thing this whole layer exists to fix; the same count everywhere would
  // stop the patches reading as patches, since the overlay art would be the only thing marking them.
  //
  // and the COUNTS had to go up to be seen at all. a compound park is planted far denser than the
  // open ground the wilderness tuned its 1-3 against — the live one measures **72.5% under trees and
  // bushes**, leaving 99 plain cells of 360 — so one tuft a cell put 108 blades in a lawn that big
  // and read as nothing. 3 and 5 put 315 in, which is where the ground stops being felt
  public static inline var TUFT_LAWN = 3;
  public static inline var TUFT_PATCH = 5;
  public static inline var TUFT_H = 0.9;
  // how fast the park's blades lean against the wilderness's own wind rate. HALF: a compound park is
  // a sheltered box with buildings and a perimeter wall round it, where the wilderness's grassland is
  // open ground, and at the shared rate a walled lawn read as breezier than the moor. the AMPLITUDE
  // is untouched — the blades travel as far, they just take twice as long about it. free, because
  // render.wild.WildGrass.material takes the rate as a UNIFORM and not a program define
  public static inline var TUFT_WIND_MUL = 0.5;

  // per-instance size spread on the park's PLANTS, as a fraction either side of 1.0. a batch is one
  // glb drawn many times, so at 0 a park of 163 bushes is one bush repeated 163 times — which is what
  // it was. deliberately half the wilderness's own spread for these same three models (conifer 0.20,
  // broadleaf 0.22, bush 0.28): those are wild growth, these are planted stock in a maintained
  // compound, where a lawn of visibly mismatched shrubs reads as neglect rather than as nature.
  // the BENCH takes 0 and is not covered by this — see its row in FacilityGround.GREEN
  public static inline var PLANT_SCALE_JIT = 0.10;

  // how far the road, the park and the lot lie BELOW the pavement, world units. the street's own
  // kerb step verbatim (render.RenderConfig.CURB_H), and render.world.Kerb draws the edging off that
  // file's WALKWAY_BORDER_W / _TILE too, so a compound's kerb and a street's are the same object.
  //
  // THE SIGN IS THE DESIGN. a city raises its walkway and leaves the road at 0; a compound cannot,
  // because game.FacilityAreaGenerator.generateBuilding writes a 2-cell pavement apron around every
  // structure and an indoor floor is y = 0 — raise the pavement and every exterior threshold becomes
  // a step down into the building and every wall base floats. so the PAVEMENT holds 0, with the
  // floors, the walls, the doors, the benches and every glow quad, and the three surfaces a building
  // does not open onto drop under it instead.
  //
  // the LOT is one of the three, and it is the one that reads: it is a driving surface, so it meets
  // the road flush at the sidewalk's parking entry (that generator's 4x2 gap) instead of stepping up
  // out of it, and dropping it is what gives the pavement a kerb along its whole lot edge rather
  // than a seam. the one structure that opens straight onto asphalt is the hangar, whose door then
  // has the same shallow lip a real loading apron has
  public static inline var KERB_DROP = render.RenderConfig.CURB_H;
  // how far the painted lines float over the asphalt they lie on — the street's PAINT_Y, and like it
  // measured off the ROAD's own surface and not off y = 0
  public static inline var PAINT_Y = render.RenderConfig.PAINT_Y;
  // a parking bay is this deep, in cells, and one is struck every this many cells along the apron
  // edge it is drawn against. AISLE_CELLS is the driving lane left between one row of bays and the
  // next as the rows march on inward to fill the middle of the lot
  public static inline var BAY_CELLS = 2;
  public static inline var BAY_SPACING = 2;
  public static inline var AISLE_CELLS = 2;
  // and this many cells of bare asphalt are left round every structure. a lab building already has
  // its 2-wide pavement apron and so clears this on its own; the hangar is the one that opens
  // straight onto the lot, and a bay struck against its wall is a spot with a blank six-metre face
  // where the car's nose goes
  public static inline var BUILD_GAP = 2;

  // ---- what the lot is littered with (render.facility.FacilityDebris) ---------------------------

  // how often a lot cell rolls a piece of ground litter, and how much likelier it is against an
  // EDGE. two tiers rather than a distance field, because litter does not fall off smoothly with
  // distance the way the wilderness's roadside scatter does — it collects where something stops it
  // blowing, i.e. against a kerb, a wall or the park railing, and the middle of a lot is swept by
  // the cars driving over it.
  //
  // HALVED off the first fitted pair (0.06 / 0.26), which dealt 41 fragments over the lot and read
  // as a dump rather than as a working compound — this is a maintained site with a guard on the
  // gate, not the wilderness roadside those two were ported from. the RATIO between them is what
  // does the work and it is untouched at 4.3x, so litter still collects against the edges
  public static inline var LITTER_PCT = 0.03;
  public static inline var LITTER_EDGE_PCT = 0.13;
  // the tunnels' own two, verbatim, for the reasons render.sewer.SewerDebris.dress spells out: a
  // cluster fragment can roll a scale too small to see from a camera 18-55 units up, and a STATIC
  // fragment comes back with NO offset and NO rotation at all, which reads as a grid
  public static inline var LITTER_MIN_SCALE = 0.5;
  public static inline var LITTER_JITTER = 0.25;
  // and the standing junk: one candidate cell in this many, then the list is STRIDED down to this
  // many props. the stride is not a cap — FacilityRoof.fill records what a running counter does to a
  // row-major scan, which is spend the whole allowance on the first two rows
  public static inline var LOT_PROP_STEP = 3;
  public static inline var LOT_PROP_MAX = 14;
  // world heights, and with them the widths: render.Models.instanced scales by HEIGHT alone. at the
  // half-metre unit WALL_H 6.0 fixes, these are a 0.75 m road cone, a 0.6 m stack of three tyres
  // (1.36 units across, a 0.68 m tyre) and a 1.2 m cable drum
  public static inline var LOT_CONE_H = 1.5;
  public static inline var LOT_TYRES_H = 1.2;
  public static inline var LOT_REEL_H = 2.4;

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
  // A BENCH GETS NO WALL HALO and there is no constant here for one, which is the point worth
  // recording: it does not TOUCH its wall. FacilityGeom.slab insets a solid room face
  // (CELL - WALL_T) / 2 = 1.0 into the wall cell and a bench sits on its own cells, so the nearest a
  // worktop comes is 0.8 and its body 1.0 — 25 px of bare floor at the game camera between the
  // shadow and its caster, which reads as a stain and not as contact. Sliding the block onto the
  // masonry to earn one was built, measured and reverted; the corridor casework below is the family
  // that DOES touch, and it keeps its halo

  // ---- corridor casework -----------------------------------------------------------------------

  // the storage runs standing against a corridor wall. they are the SAME two meshes the benches are
  // merged into and wear the same two textures, so the whole family costs no draw call and no art —
  // what makes them a corridor fitting rather than a bench is the depth alone.
  //
  // and the depth is a GAMEPLAY number before it is an art one. the wall face a run stands on is
  // FacilityGeom.slab's, which is inset one unit INTO the wall cell, so a cabinet 1.4 deep reaches
  // only 0.4 past the corridor cell's own boundary and leaves 1.6 units of clearance to the line of
  // cell centres an actor walks down. nothing here is stamped into the tiles, so that clearance is
  // the whole of what keeps a run from being walked through
  public static inline var CASE_D = 1.4;
  // how much of the wall a run may take, in cells, and the shortest that is worth standing: one
  // cabinet alone reads as a dropped box, three in a row read as fitted casework
  public static inline var CASE_RUN_MIN = 3;
  public static inline var CASE_RUN_MAX = 4;
  // and how many of the eligible runs actually get one. gated on the RUN and never on the cell: a
  // per-cell gate breaks a run into a dotted line of single cabinets, which is the one thing
  // CASE_RUN_MIN exists to prevent
  public static inline var CASE_PCT = 0.4;

  // ---- the lab kit standing in the rooms (render.facility.FacilityKit) ---------------------------

  // world HEIGHTS, and through render.Models.instanced the widths with them. at the half-metre unit
  // WALL_H 6.0 fixes these are a 1.5 m cylinder rack and a 1 m trolley, which is what both objects
  // really stand at — a rare case where the honest number is also the readable one, because both are
  // wide for their height (the rack draws 2.63 across, the trolley 1.98) and width is what an
  // overhead camera sees
  public static inline var KIT_GAS_H = 3.0;
  public static inline var KIT_TROLLEY_H = 2.0;
  // and their DEPTHS across the wall they stand against, off each glb's own measured z extent
  // (0.317 and 0.451 of its height). the placer works off the wall FACE, so this is what turns a
  // face into a centre — half of it, plus the gap
  public static inline var KIT_GAS_D = KIT_GAS_H * 0.317;
  public static inline var KIT_TROLLEY_D = KIT_TROLLEY_H * 0.451;
  // and the WIDTHS along that wall, off the same glbs' x extents (0.875 and 0.990). render.Models
  // .instanced scales by height alone, so these are what the props already draw at — nothing here
  // sets a size. they exist because render.world.ContactMask needs a FOOTPRINT to darken the floor
  // under, and the placer only ever had to know the depth
  public static inline var KIT_GAS_W = KIT_GAS_H * 0.875;
  public static inline var KIT_TROLLEY_W = KIT_TROLLEY_H * 0.990;
  // and how far the prop's back stands off that face. the corridor casework is bolted to the wall
  // and takes none; these two are STOOD there, and a hair of daylight behind them is what says so.
  //
  // it is also what has to ABSORB THE YAW JITTER, which is where the number comes from rather than
  // from taste: turning a box about its own centre swings its far corner back, and the trolley's
  // half-length 0.99 over its half-depth 0.45 makes that 0.45 * cos(J) + 0.99 * sin(J) - 0.45 =
  // 0.177 at KIT_YAW_JIT. measured live at 0.15, a jittered trolley stood 0.04 off the wall face and
  // the worst case was 0.02 THROUGH it
  public static inline var KIT_GAP = 0.2;
  // a free turn either side of square, radians. a trolley is pushed and parked, never squared to the
  // grid, so it takes ~10 degrees hashed off its cell — the same discipline every other prop in the
  // compound turns on, and never Math.random()
  public static inline var KIT_YAW_JIT = 0.18;
  // one candidate cell in this many, then the list is STRIDED down to this many props, exactly as
  // the lot's junk is thinned (LOT_PROP_STEP / LOT_PROP_MAX and the reason there). rooms are the one
  // interior surface with nothing on it, so the temptation is to fill them — but a lab with kit
  // against every wall reads as a store room
  public static inline var KIT_STEP = 3;
  public static inline var KIT_MAX = 10;

  // ---- room furniture (render.facility.FacilityDeco) ---------------------------------------------

  // the three fittings that replaced an upright 2D sprite. every W and H is the SPRITE's own alpha
  // bbox carried into world units — the quad was Sprites.SIZE 3.0 across 64 px, so a 45 x 61 px
  // bookcase is 2.11 x 2.86 and these are those numbers rounded.
  //
  // TWO OF THE DEPTHS/WIDTHS ARE NOT FREE. A face carrying a 0..1-mapped image has to match that
  // image's aspect or the art is STRETCHED, so DECO_SHELF_D is its end frame's 656 x 1024 and
  // DECO_BOOKCASE_W is its front's 616 x 1024, each written as the product that produced it.
  // DECO_SHELF_D's 0.640625 is also the narrowest a STANDALONE gpt-image-2 gen will emit at 1k — a
  // source has to clear 655,360 pixels with no edge over 1024. A CROP off a packed sheet has no such
  // floor, which is how the bookcase front reaches 0.6016: it is a sub-rect of one 1024 square.
  //
  // depth is otherwise a LOOK decision and not a gameplay one, unlike the corridor casework's
  // CASE_D: a fitting stands on a cell the generator already wrote unwalkable, so nothing can walk
  // into it however far it reaches — and off the wall FACE, a unit inside the wall cell, even the
  // deepest of these takes under a fifth of its own cell.
  //
  // THE BOOKCASE ALONE DEPARTS FROM THE SPRITE BBOX, by a flat 1.2 on all three axes, called on the
  // game. The scale is written as the product so the departure stays visible and the SPRITE numbers
  // stay readable behind it. It costs nothing anywhere: 3.36 is well under WALL_H 6.0 and the
  // generator never deals a HIGH fitting beside glazing, so there is no sill to clear; the 2.02 width
  // still slides inside the 3.0 a run-end wall cell offers, so `fit` never has to squeeze it; and the
  // aspect lock rides along untouched because W is DERIVED from H
  public static inline var DECO_SHELF_W = 2.6;
  public static inline var DECO_SHELF_H = 2.6;
  public static inline var DECO_SHELF_D = DECO_SHELF_H * 0.640625;
  public static inline var DECO_BOOKCASE_H = 2.8 * 1.2;
  public static inline var DECO_BOOKCASE_W = DECO_BOOKCASE_H * 0.6015625;
  public static inline var DECO_BOOKCASE_D = 1.05 * 1.2;
  public static inline var DECO_RACK_W = 1.6;
  // DERIVED, and by the same kind of lock as DECO_SHELF_D and DECO_BOOKCASE_W above — only this one
  // is fixed by what the art CONTAINS rather than by its aspect. The front tiles at the unit's own
  // width (see DECO_RACK_TILE) and the image holds THREE chassis, so one chassis is 1.6 / 3 and a
  // height that is not a whole number of those cuts the top one in half at the lid. It stood at 2.9
  // = 5.44 chassis and the half unit up there was reported from the game. 2 x W is 6 whole chassis
  // and v lands on exactly 2.0
  public static inline var DECO_RACK_H = DECO_RACK_W * 2;
  public static inline var DECO_RACK_D = 1.2;
  // the TILING faces' periods, in world units. these are material scales and nothing else — a
  // perforation pitch, a wood grain, a rack's unit height — so they are chosen against the thing
  // they draw and never against the unit's own size the way the first build's were
  public static inline var DECO_SHELF_TILE = 0.55;
  public static inline var DECO_BOOKCASE_TILE = 1.4;
  // and the rack's is the ONE exception to the line above, because its three faces are not material
  // swatches: the front is an authored composition with an end rail down each side and the lid has
  // its grommets in a fixed place. Those faces are laid from the unit's OWN corner
  // (FacilityDeco.localFace) rather than off the world, so the period IS the unit's width — u runs
  // exactly 0..1 across the front and across the lid, which is what puts the rails on the corners
  public static inline var DECO_RACK_TILE = DECO_RACK_W;
  // how far a fitting's back stands off the wall FACE is NOT a deco number and no longer lives here —
  // it is STAND_GAP, in the halo block below, because the halo plane is what fixes it
  //
  // where the alpha-cut end frame stops being frame and starts being air. an OPAQUE alphaTest and
  // not a transparent material: an alpha-tested opaque draws DoubleSide in ONE pass and still
  // writes depth, which is what render.wild.WildGrass' own header records
  public static inline var DECO_CUT = 0.5;

  // the shelving's composite: two alpha-cut end frames, a bare quad per shelf and the boxes on
  // them. NO BACK and NO TOP — an open steel unit has neither, and a lid is the one thing that
  // could hide the top shelf's boxes from a camera pitched 51 degrees down.
  //
  // the shelf heights are the frame's OWN CROSS RAILS, MEASURED off the built alpha channel by
  // binning opaque coverage per row of facility/deco-shelf-side (rails at 0.052, 0.287, 0.695 and
  // 0.974 of the height, the last being the top rail, which carries no shelf). Read the other way
  // round — three evenly spaced shelves against whatever the art happened to draw — a shelf floats
  // between two rails and the unit reads as a wire cage with slabs inside it, which is how the
  // first build shipped. The art is the source of truth here and the code follows it.
  //
  // the bottom shelf being OFF THE FLOOR is not cosmetic either: at 0 it is coplanar with the room
  // floor and z-fights across its whole footprint
  public static final DECO_SHELF_Y = [ 0.063, 0.381, 0.699 ];
  // and where the frame stops, so the top bay knows how much room it has
  public static inline var DECO_SHELF_TOP_Y = 0.954;
  // boxes per shelf, and the size band each is rolled in — in WORLD UNITS and not as a fraction of
  // the bay it lands in, which is what the first build did and what produced a single 1.6-wide
  // monster whenever the roll came back with one box on a 2.6 shelf. A packing box is a packing
  // box whatever it is standing on: at the half-metre unit WALL_H fixes, this is a 27-50 cm carton.
  // the bay still CAPS it, so three on one shelf are three small ones and never three overlapping
  public static inline var DECO_BOX_MAX = 3;
  public static inline var DECO_BOX_W = 0.55;
  public static inline var DECO_BOX_W_VAR = 0.45;
  public static inline var DECO_BOX_H = 0.45;
  public static inline var DECO_BOX_H_VAR = 0.30;
  // and its depth, as a fraction of the shelf's. it is a CEILING and not the value: `boxes` shrinks
  // it further so that the turned box's own swung corner still clears the shelf front, the same
  // arithmetic KIT_GAP carries for the lab trolley
  public static inline var DECO_BOX_D = 0.8;
  // a free turn either side of square, radians, hashed off the box. ~14 degrees: boxes are PUT on a
  // shelf, never squared to it, and a rank of axis-aligned cuboids is what made the first build
  // read as one machined object rather than as stuff someone left there. the cardboard is tiled at
  // WORLD scale along each turned face rather than mapped 0..1 across it, so nothing is stretched
  // by the turn and no two boxes show the same patch
  public static inline var DECO_BOX_YAW = 0.25;
  public static inline var DECO_BOX_TILE = 0.5;
  // THE ONLY SHADING A BOX ON A SHELF CAN GET, and it is baked into the vertex channel because the
  // room cannot supply it. Every shelf plate is a FacilityGeom.cap with a +Y normal and the indoor
  // fill is normal-blind (see IndoorMask), so three plates 0.83 units apart in one unit rendered
  // 53.6 / 52.8 / 53.0 — identical to within 0.8/255 — and a box met its plate at 69.7-on-53.0 with
  // nothing between. No light in the compound can separate them: it is not a tuning gap, it is what
  // an AmbientLight-shaped term IS.
  //
  // _LOW is the LOWEST shelf's weight against the top one's 1.0, interpolated over the bays: an open
  // frame is closed above every shelf but its last, so the bay's own lid is the occluder and the top
  // shelf takes none of it. _FOOT is how far each box darkens toward the plate it stands on, which is
  // its own contact shadow — the wall halo cannot reach this one (at 51 degrees down you look INTO
  // the unit and a box is read against its SHELF, not against the masonry)
  public static inline var DECO_BOX_AO_LOW = 0.78;
  public static inline var DECO_BOX_AO_FOOT = 0.70;

  // the server rack's LIGHTS. one additive mesh for every rack in the compound, blinking off a
  // shared clock with a per-light phase — see render.facility.FacilityDeco.lamps
  // THE FIELD IS READ OFF THE ART AND NOT CHOSEN. It shipped as an even 6 x 3 grid over a band of
  // the face, which is a lattice of specks floating across three server chassis and their recessed
  // gaps; a rack's ports are ON a unit, in the narrow blank strip beside its vent panel. The front
  // image holds _PER_TILE chassis per repeat, so a face h/DECO_RACK_TILE repeats tall carries that
  // many times as many rows, each on its own unit. Measured on the built 512: the recessed gaps sit
  // at v 0.34-0.37 and 0.66-0.69 of the tile, so a row at (k + 0.5) / rows lands inside a chassis
  // every time, within 0.05 world of its true centre
  public static inline var DECO_LED_PER_TILE = 3;
  public static inline var DECO_LED_COLS = 2;
  // one light's quad edge, world units. small enough to be a speck at this camera, which is what
  // makes the bloom do the reading rather than the geometry (the watcher's eyes' own finding)
  public static inline var DECO_LED_SIZE = 0.09;
  // the strip of the face they sit in, ACROSS it, as a fraction from the texture's own u origin.
  // measured off the same drop: the vent mesh's per-column deviation falls off a cliff past u 0.66
  // (18.5 -> 10.1) and the screw column stands at 0.91, so 0.72-0.90 is the blank panel between them
  public static inline var DECO_LED_U0 = 0.72;
  public static inline var DECO_LED_U1 = 0.90;
  // and how far proud of that face they sit, so the additive quad is never coplanar with it
  public static inline var DECO_LED_EPS = 0.03;
  // blink speed as a BASE_MS multiplier, and the depth of the dip. a UNIFORM and not a literal in
  // the patched shader, so retuning either compiles nothing (the PropShine pulse's own note)
  public static inline var DECO_LED_RATE = 0.35;
  // 1.0 would switch a light fully OFF, which reads as a dead port rather than as traffic
  public static inline var DECO_LED_DEPTH = 0.75;
  // the two hues, mixed per light off its own vertex channel — so one mesh carries both. AMBER and
  // GREEN because the compound is lit blue throughout (FacilityScene's ambient 0x46536b, moon
  // 0x8294c0) and blue is the one accent that cannot read against it
  public static inline var DECO_LED_AMBER = 0xffb066;
  public static inline var DECO_LED_GREEN = 0x86ffa8;
  // the HDR multiplier that carries a light over BLOOM_THRESHOLD, the same job GLOW does for the
  // ceiling panels
  public static inline var DECO_LED_GLOW = 2.6;

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

  // ---- the lobby notice board ------------------------------------------------------------------

  // a SQUARE 1.1 m corkboard hung centred 1.5 m up the entrance wall, at the half-metre unit WALL_H
  // 6.0 fixes. square because the ART is square and a texture is never stretched — a landscape board
  // would have to be sized off its own drop's aspect, which is machinery the window runs genuinely
  // need (WINDOW_ASPECT) and one quad on a pier does not.
  //
  // 2.2 across the 4-unit mullion leaves 0.9 of masonry either side, and 1.9..4.1 up a 6-unit wall
  // stands clear of the floor and well under the roof deck. it stands MOUNT_PROUD off the face, the
  // vent grille's own nudge — see render.facility.FacilityBoard.quad
  public static inline var BOARD_W = 2.2;
  public static inline var BOARD_Y = 3.0;
  public static inline var BOARD_TEX = 'textures/facility/notice-board.png';

  // ---- the exit signage (render.facility.FacilityExit) -------------------------------------------

  // a 0.75 m by 0.5 m sign box, at the half-metre unit WALL_H 6.0 fixes. LANDSCAPE where the notice
  // board is square, and for the same reason it is square: the art decides, a texture is never
  // stretched, and a running man beside an arrow is a 3:2 cell (1008x672).
  //
  // EXIT_Y is the quad's CENTRE. DOOR_H is 4.0 and a lintel runs from there to WALL_H 6.0, so 4.75
  // puts a terminal sign in the lower half of that band — over the opening the way a real one is,
  // and not adrift halfway up the masonry — and puts a directional sign on the corridor wall at the
  // same height, which is what makes the two read as one installation. it stands MOUNT_PROUD off the
  // face, the same nudge the vent grille and the notice board take, because this repo has lost three
  // times to polygonOffset
  public static inline var EXIT_W = 1.5;
  public static inline var EXIT_H = 1.0;
  public static inline var EXIT_Y = 4.75;
  public static inline var EXIT_TEX = 'textures/facility/exit-sign.png';
  // the two cells of the atlas, as the v of each one's BOTTOM edge; each is half the image tall.
  // the source stacks TOP terminal, BOTTOM directional and three flips y, so the terminal is the
  // UPPER v range. one texture and not two because two would be two materials, two meshes and two
  // draw calls to change a pictogram
  public static inline var EXIT_V_TERM = 0.5;
  public static inline var EXIT_V_DIR = 0.0;
  // how many cells of corridor have to RUN INTO a wall before a directional sign goes on it. it is
  // what separates a wall you walk at from a wall you walk past, and a corridor here is 2 cells wide,
  // so anything under 3 starts calling the long side wall of a straight corridor an approach.
  //
  // MEASURED over the compound's 280 flooded corridor cells: 2 -> 24 signs, 3 -> 14, 4 -> 9. This is
  // the ONLY density knob, because the sign now has to face the traveller to carry an arrow at all,
  // and there is no such wall on a straight run. The pass that shipped for one build placed one
  // every N cells along the route as well, on the corridor's own SIDE wall — 45 signs, edge-on to
  // anyone walking that corridor, and a green ribbon down every wall from anywhere else
  public static inline var EXIT_APPROACH = 3;
  // and how hard it glows. the art is its OWN emissiveMap, so this multiplies bytes that already
  // measure 0.1616 linear — 2.4x facility/wall-interior before anything is dialled, which is why it
  // is under WINDOW_EMISSIVE 2.2 rather than at it. dial the sign HERE and never with a `lift` on
  // the source: a lift moves the lit green face and the dark housing together, and only one of them
  // is supposed to be a light
  public static inline var EXIT_EMISSIVE = 1.6;

  // ---- interior wall grime (render.facility.FacilityGrime) ---------------------------------------

  // the damp band at the foot of an interior wall. `decals/grime-1..3` are BAND art and not marks —
  // measured on the drop, the opaque part of each is the bottom 31-37% of the image at full width,
  // which is the alpha ramp render.world.Buildings and render.sewer.SewerDetail both tile a strip
  // with. Emitted as a square decal it draws a wide flat dash and nothing else, which is how the
  // first build of this pass shipped.
  //
  // GRIME_H is therefore the FADE height and not the mark: at 3.0 the art's own ramp leaves about a
  // unit of visible muck at the floor, half a metre at the half-metre unit WALL_H 6.0 fixes — which
  // is what a mopped corridor wall has. It is also the city's own value, on a wall of the same 6.0.
  //
  // OPACITY is well under both parents (city 0.6, tunnels 0.7) and was HALVED again after the first
  // build: at 0.45 it read as a dilapidated building rather than a used one, and this is a working
  // research facility. The same call cut the crack layer that shipped beside it
  public static inline var GRIME = 'textures/decals/grime-2.png';
  public static inline var GRIME_H = 3.0;
  public static inline var GRIME_TILE = 3.0;
  public static inline var GRIME_OPACITY = 0.225;
  // proud of the wall face. a PHYSICAL gap and never polygonOffset — three losses to the depth-bias
  // route are on record — and the tunnels' own value, a band being the same thing on a 2-unit slab
  // as on a cell wall
  public static inline var GRIME_EPS = 0.05;

  // ---- the vertical darkening down a reentrant corner (render.facility.FacilityDetail) -----------

  // NOTHING IN THE INDOOR RIG CAN DARKEN A VERTICAL CORNER, and that is structural rather than a
  // tuning gap — the tunnels' own finding, and it applies here harder. render.world.IndoorMask
  // replaces the fill with an AmbientLight-shaped term, which is normal-blind; the hemisphere it
  // replaces keyed on normal.y and BOTH faces of a vertical corner are vertical; a ceiling fixture
  // over the passage sees both walls at once. And measured while chasing "zero shadows indoors": the
  // whole direct term indoors is 18% of an interior floor, so a REAL shadow tops out at 10/255 —
  // GTAO is the only engine answer and it ships off at +140 calls.
  //
  // render.world.ContactMask cannot reach this either, and that one is not a budget problem: the
  // field is TOP-DOWN, so every fragment of a 6-unit wall face samples the same xz and the whole
  // column would darken by one flat amount. Its own header says so. The floor crease is a field; the
  // wall corner has to be geometry.
  //
  // THE REACH IS NOT A KNOB. It is the notch — FacilityGeom.notches leaves exactly (CELL - WALL_T)/2
  // = 1.0 unit of masonry facing the room on each side of a corner, which is the piece the wall line
  // turning leaves behind, and the strip is that face and no more. The tunnels' WALL_SHADOW_W 1.1 is
  // the same number arrived at by hand on a 4-unit cell
  public static inline var CORNER_ALPHA = 0.5;
  // proud of the wall face, and it must CLEAR GRIME_EPS 0.05 or the damp band in the same corner
  // draws over the strip instead of under it. a PHYSICAL gap and never polygonOffset — the tunnels'
  // own value and the same reasoning
  public static inline var CORNER_EPS = 0.07;

  // ---- the shadow a thing STANDING against a wall lays on it (render.facility.FacilityDetail) -----

  // THE REACH IS NOT A KNOB HERE EITHER, and this time it is the ART that fixes it.
  // Textures.makeRectGlowGradient draws a rounded-box field that is opaque over the middle HALO_CORE
  // of the canvas and fades out over HALO_FADE beyond it, so FacilityDetail.halo sizes its quad as
  // the object divided by HALO_CORE and the falloff lands OUTSIDE the object by
  // HALO_FADE / HALO_CORE = 0.2667 of the object's own size on each axis. What that gives, against
  // CONTACT.blur 0.7 and the sweep that found no depth cost below about 1.0:
  //   shelving 2.6 x 2.6 -> 0.69 / 0.69     bookcase 2.02 x 3.36 -> 0.54 / 1.10 (CAPPED)
  //   rack 1.6 x 3.2     -> 0.43 / 0.85     gas rack 2.63 x 3.0  -> 0.70 / 0.80
  //   trolley 1.98 x 2.0 -> 0.53 / 0.53
  // every one of them in range, which is why these are the generator's own defaults and not a fitted
  // pair. a BIGGER object throwing a WIDER halo is also the right way round, and it is free here.
  // the tallest quad tops out at the bookcase's 3.36 + 1.1 = 4.46, well under WALL_H 6.0
  public static inline var HALO_CORE = 0.60;
  public static inline var HALO_FADE = 0.16;
  // and the CAP on that, in world units, which is what lets a RUN take the same quad as a fitting.
  // the reach above is a FRACTION of the object, which is right for a bookcase and absurd for a
  // 16-unit casework run — 4.3 units of wash up a 6-unit wall. Capping the grown margin holds a long
  // thing to a contact-scale fade and costs nothing at the ends: past the cap the object's own edge
  // maps outside the art's opaque core, so the halo simply thins out along the run instead of ending
  // on a line. 1.1 was set ABOVE the largest margin anything then emitting asked for (the gas rack's
  // 3.0 height wants exactly 1.0), so no fitting and no kit prop was touched by it — the BOOKCASE now
  // is, by 0.02: scaled 1.2 it stands 3.36 and wants 1.12. Left alone deliberately, because the cap
  // is doing exactly its job there and 0.02 of 1.12 is nothing; it holds a run's fade to 0.88 —
  // inside the same band CONTACT.blur 0.7 was swept in
  public static inline var HALO_GROW_MAX = 1.1;
  // how dark it goes where the object meets the masonry. it BUILT at the corner strip's own 0.5 —
  // the only other thing in the compound doing this job, and the two are read side by side in a room
  // corner — and that was rejected on looks as too heavy. measured on one pinned pose against the
  // mesh hidden: 0.5 puts max 27.7/255 on the wall and takes the touch line down 44%, which reads as
  // a painted shadow rather than as contact; 0.32 is max 16.7 and 27%. A CORNER AND A FITTING ARE NOT
  // THE SAME WEIGHT — the corner is masonry meeting masonry over a whole 6-unit column, this is a
  // cabinet resting against a wall, and matching them was an assumption and not a measurement
  public static inline var HALO_ALPHA = 0.32;
  // proud of the wall face. it must clear GRIME_EPS 0.05 AND CORNER_EPS 0.07, because a fitting can
  // stand in a corner and the damp band runs behind every one of them: this quad is the outermost of
  // the three and draws last. a PHYSICAL gap and never polygonOffset, the same reasoning as above
  public static inline var HALO_EPS = 0.09;
  // and how far ANYTHING STANDING AGAINST A WALL keeps its own back off that face.
  //
  // IT MUST CLEAR HALO_EPS, and that is the whole of the number. The halo lies on a plane HALO_EPS
  // proud of the masonry, so a back any closer than that puts the quad INSIDE the object: the plane
  // cuts both side faces and the top cap along a line, and every fragment deeper than HALO_EPS along
  // a view ray draws over them. It shipped at 0.05 — the plane 0.04 inside every fitting in the
  // compound — which is a sliver from straight above and opens up as the hold-RMB orbit drops the
  // pitch. The margin over HALO_EPS is small on purpose: this is a depth-ordering number and not a
  // look one, and the shadow is meant to be darkest exactly where the object meets the wall.
  //
  // read by the fittings (render.facility.FacilityDeco.unit), whose back is the wall face plus this.
  // the benches do NOT read it and get no halo either: they sit on their CELLS, a whole unit off the
  // masonry, and a shadow that far from its caster is a stain — see FacilityTables' header
  public static inline var STAND_GAP = HALO_EPS + 0.03;
  // and the same quad laid FLAT, under a box on a shelf plate — see FacilityDetail.pool. it stands
  // off by a tenth of the wall halo's gap and not by the same number, because the ladder that fixes
  // that one is a WALL ladder: GRIME_EPS and CORNER_EPS are other things drawn on the same masonry,
  // and there is nothing else on a shelf plate to get above. 0.09 in a 0.83 bay is a ninth of the
  // bay, and at the camera's 51 degrees it slides the shadow 0.07 out from under its box
  public static inline var POOL_EPS = 0.01;
  // and its REACH, which is the one number here the wall halo does not share. Up there the quad is
  // the object divided by HALO_CORE, so the art's opaque core lands exactly on the object's edge and
  // the ring outside it is a fixed 0.533 of the object's half-extent — locked by the art. Down here
  // that ring is too wide for a 0.55-wide box on a 1.67-deep plate, and the ONLY way to narrow it
  // with this ramp is to let the core shrink INSIDE the footprint, which costs nothing because the
  // box is standing on it: the quad is the box plus POOL_GROW of its own half-extent with the art
  // mapped 0..1 over that, so the falloff starts under the box and the visible ring comes out
  // 0.92 * (1 + POOL_GROW) - 1 = 0.29 of the half-extent. A second ramp with its own halfFrac would
  // hold the core on the edge AND narrow the ring, and it would also be a second alphaMap, a second
  // material and the draw call this whole family exists to avoid
  public static inline var POOL_GROW = 0.4;

  // ---- windows ---------------------------------------------------------------------------------

  // the window art's own width:height over its OPAQUE CONTENT — measured off the source, not the
  // canvas, which is square and mostly cut away. the quad is sized FROM this and never stretched, so
  // the art's aspect is the only thing that decides how tall a run stands: a 3-cell run is 12 world
  // units wide and comes out 12 / 2.9 = 4.14 tall on a sill of 0.93. THIS ONE IS THE THREE-PANE
  // UNIT's and answers for a 3-cell run alone — see WINDOW_ASPECT_2 below and
  // render.facility.FacilityGeom.paneTall, which is where both lengths are sized.
  //
  // it was 2.02, which is what the first art measured, and at that aspect a 3-cell run stood 5.94 in
  // a 6.0 wall: glazing floor to ceiling, its head 0.03 under the roof deck with no sill ledge at all
  // (the sill cap skips under 0.05). 28 of the 49 runs a generated area deals are 3-cell, so that was
  // the common case, not the corner one. the fix is the ART's proportions — clamping the height in
  // code cannot work, because the hole through the wall is cut from this same arithmetic and a
  // shorter pane in a full-height opening is just a gap
  public static inline var WINDOW_ASPECT = 2.90;
  // and the TWO-PANE unit, for the 2-cell runs, with the aspect of its own opaque content.
  //
  // ONE ART PER RUN LENGTH, because render.facility.FacilityGeom.pane maps one unit of u across a
  // whole run: drawing the three-pane art on a 2-cell opening squeezed three panes into two cells'
  // width and read as the same window at two thirds scale beside its full-size neighbour on the same
  // facade. 27 of the 45 runs a generated area deals are 2-cell, so that is the common length rather
  // than the corner one.
  //
  // it is NOT the three-pane art cropped, which is what this was for one build. Cropping is possible
  // — the members are regular enough to cut at a mullion, and it drew correctly — but it can only
  // ever hand back a strip of an image authored for a different pane count, and its arithmetic has to
  // be re-measured against the art every time either changes. A second file states the same thing
  // once, in the place that owns it, and costs nothing at runtime that the crop did not already cost:
  // either way a run's panes go in the buffer for their own length.
  //
  // MEASURED off the BUILT texture and against the loader's OWN threshold, which is the only bbox
  // that matters: Textures.loadAlphaCropped skips alpha <= 8, and read back off the live material it
  // crops this art to 316x161 = 1.963 where it crops the three-pane one to 464x160 = 2.900. (The
  // source measures 1.972 at a stricter threshold — a third of a percent out, which is a 0.01-unit
  // stretch, but there is no reason to carry the wrong one.) Its three dark members are 16/17/16px
  // with the mullion dead centre, so its panes come out the same width as the other's — the same
  // pane, one fewer of them. That is what puts a 2-cell run at 4.08 tall on a 0.96 sill against a
  // 3-cell run's 4.14 on 0.93: the two lengths course together on one facade instead of the shorter
  // standing a third of a storey lower
  public static inline var WINDOW_LIT_2 = 'textures/facility/window-ribbon-2tile-lit.png';
  public static inline var WINDOW_ASPECT_2 = 1.963;
  // how much BIGGER than its opening a pane is drawn, as a fraction of its own size, half of it at
  // each edge. IN BOTH AXES, so the art keeps its aspect and nothing is stretched — the extra is
  // buried in the masonry either way, because the glazing slab is GLASS_T thick inside a WALL_T wall
  // and so sits half a unit behind the wall face on both sides.
  //
  // it exists because the OUTERMOST TEXEL ROW OF AN ART IS NOT RELIABLY OPAQUE, and alphaTest then
  // deletes it. Reported as a thin slit along the top of the 2-cell windows with the interior visible
  // through it: measured, that art's top row comes back at alpha 4.4 against the addPane alphaTest's
  // own 0.02 * 255 = 5.1, so the row is discarded and the opening is short by one texel. It is a
  // property of the CUT and not of this drop — the three-pane art's top row happens to land opaque,
  // which is the only reason it never showed. Textures.loadAlphaCropped crops to alpha > 8, so a row
  // between 9 and 5.1... is impossible, but one between 9 and 128 is not, and every partly-covered
  // edge row is a candidate.
  //
  // 0.025 puts 1.25% at each edge, which is 0.051 world units = TWO texel rows at either art's
  // density (the 2-pane art is 161 rows over 4.08 units, the 3-pane one 160 over 4.14). One would do;
  // two also covers the bilinear tap that reads the discarded row's neighbour
  public static inline var WINDOW_OVERLAP = 0.025;
  // and how far the pane then stands PROUD of the glazing slab's own face, on each side.
  //
  // WINDOW_OVERLAP is what makes this necessary, and the two arrived one build apart. The wall above
  // and below an opening is emitted on the WINDOW CELL's slab (FacilityGeom.structure's sill/head
  // pair), which is the glazing plane, and `pane` is flush with it — so the moment the pane grew past
  // the opening it was overlapping a coplanar surface, and the head and the sill z-fought. That is
  // the exact case docs/3d-render.md's standing note is about: give a coplanar overlay a PHYSICAL
  // gap, not polygonOffset, which three passes have already lost — here it would be dropped outright,
  // since the pane casts through a swapped depth material.
  //
  // it does NOT re-open the seam that deleted the old WINDOW_EPS, and for a reason that only holds
  // now: back then the pane matched the opening exactly, so standing it proud left open air where the
  // reveal caps stopped at the masonry. With the overlap the pane already runs past the head cap,
  // past the sill cap and into the flanking cells' butt caps, so a hair of standoff moves it within
  // geometry that covers it. 0.02 is render.world.Buildings.OVERLAY_EPS, tuned there against exactly
  // this question (0.06 read as a visible gap, 0.01 as flush), and it is 4% of the half unit the pane
  // is recessed behind the wall face, so the glass stays plainly inside its reveal
  public static inline var WINDOW_EPS = 0.02;
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

  // the park bench's world HEIGHT, which through render.Models.instanced is also its LENGTH: the
  // regenerated glb measures 0.477 x 0.655 x 0.998, an aspect of 1.52, so this puts a 3.56-unit
  // bench in a 4-unit cell — the same length the first bench drew, because length is what reads from
  // an overhead camera and it is sized for that. it is NOT the old 1.8: that model's own aspect was
  // 1.98, near a real bench's 1.8 m over 0.9 m, and this one is proportionally taller in the back,
  // so holding the length costs a bench that stands 1.17 m rather than 0.9 m at WALL_H's half-metre
  // unit. the alternative was a stubby 2.74-unit bench, which is worse from above
  public static inline var PARK_BENCH_H = 2.34;


  // the park railing's world HEIGHT — and here that is a DERIVED number, not a taste one. through
  // render.Models.instanced a prop's height sets its width too, and this segment has to draw exactly
  // one cell wide or a run of them leaves gaps between neighbours, so the height is the cell divided
  // by the glb's own measured aspect (bbox 1.002 x 0.354, so 2.83). the same trick and the same
  // reason as the wilderness's guard rail. it lands at ~0.85 m against a real park railing's 1.1,
  // which is the right way to be wrong: it has to read from a camera 18-55 units up
  public static inline var FENCE_ASPECT = 2.83;
  public static inline var FENCE_H = citygen.CityConfig.CELL / FENCE_ASPECT;
  // how far INSIDE the lawn the railing stands, off the boundary it edges, in world units. it is not
  // zero because the kerb band protrudes RenderConfig.WALKWAY_BORDER_W over the grass at the higher
  // level: centred on the boundary the railing would stand half inside that band
  public static inline var FENCE_INSET = 0.3;

  // how high an actor's billboard rises swinging over the railing (render.anim.Climb, reached through
  // render.world.WorldCtx.climbArc). the railing is render-only — nothing is stamped on the tiles for
  // it, so the park is walked into straight through the fence — and this is the whole of what says
  // otherwise. a shade under the wilderness guard rail's 0.9 because this bar is the shorter of the
  // two: FENCE_H 1.41 against the rail's 1.6
  public static inline var CLIMB_ARC = 0.8;

  // the park litter bin's world HEIGHT, and through render.Models.instanced its width too: the glb's
  // bbox is 0.540 x 1.001 x 0.540, an aspect of 0.54, so this puts a 0.97-unit drum beside a bench.
  // ~1.1 m at the bench's own unit, which is a municipal bin
  public static inline var BIN_H = 1.8;
  // where it stands, in world units off the BENCH's centre, along the bench's own two local axes —
  // sideways along the seat, and backwards away from the path it faces. both numbers are geometry and
  // not taste. the bench is 3.57 long and 1.70 deep, so its own half-extents are 1.79 and 0.85; the
  // bin's radius is 0.49. SIDE is inside the seat's length, so BACK is what has to clear it, and it
  // does with 0.08 to spare (1.42 - 0.85 = 0.57 against the radius); both offsets plus the radius stay
  // inside the cell's half-width of 2.0 (1.94 and 1.91). so the bin sits off the bench's back corner,
  // touching neither the seat nor the neighbouring cell. `facing` only ever returns a quarter turn, so
  // those two bounds are the whole test — there is no diagonal case to check
  public static inline var BIN_SIDE = 1.45;
  public static inline var BIN_BACK = 1.42;

  // the same bin standing INDOORS, at a corridor's dead end. it is the same glb at the same BIN_H, so
  // it rides the park's own batch and costs nothing — see FacilityGround.bins.
  //
  // GAP is measured off the WALL FACE (FacilityGeom.slab's, one unit inside the wall cell) to the
  // bin's centre: the drum's radius is 0.49, so 0.55 tucks it into the angle with 0.06 to spare and
  // still leaves 1.45 units of clearance to the line of cell centres an actor walks down
  public static inline var BIN_IN_GAP = 0.55;
  // and how many of the eligible corners get one. a dead end is 2 cells wide, so its two cells are
  // both candidates and an ungated pass stands a matched pair in every one of them
  public static inline var BIN_IN_PCT = 0.5;

  // ---- the parked cars ---------------------------------------------------------------------------

  // a car's world HEIGHT, and through render.Models.instanced its length and width too: the built
  // glb's bbox is 0.456 x 0.374 x 1.000, so this draws a car 7.48 long and 3.41 wide. at the
  // half-metre unit WALL_H 6.0 fixes that is 3.7 m by 1.71 m by 1.4 m — a compact hatchback, and it
  // is sized for the BAY rather than for realism: a bay is BAY_SPACING x BAY_CELLS cells, i.e. 8
  // units square, so this leaves 0.26 units at each end and 2.3 each side. a full 4.3 m car would
  // overhang the spot at both ends and read as badly parked in every bay at once
  public static inline var CAR_H = 2.8;
  // how many are parked, and one bay in this many is left EMPTY. both are about the same thing:
  // there is one car model, so a lot parked solid is one car repeated the length of the kerb. the
  // gaps are what make a run of them read as a car park (see render.facility.FacilityCars.fill)
  public static inline var CAR_COUNT = 5;
  public static inline var CAR_EMPTY = 3;

  // ---- what stands on the roof (render.facility.FacilityRoof) -------------------------------------

  // a rooftop condenser unit's world HEIGHT, and through render.Models.instanced its footprint too:
  // the glb's bbox is 0.586 x 0.691 x 0.994, so this draws it 3.16 long, 1.86 wide and 1.1 m tall at
  // the half-metre unit WALL_H 6.0 fixes. it has to fit INSIDE one cell with room to spare — a
  // candidate is a whole cell and the prop stands at its centre — and 3.16 in a 4.0 cell does
  public static inline var ROOF_AC_H = 2.2;
  // and a comms dish's, drawing it 2.66 across on a 1.8 m pedestal. it is the tallest thing on the
  // roof deliberately: one per building, so it is the silhouette that says which building this is
  public static inline var ROOF_DISH_H = 3.6;
  // the access hatch housing, in world units. MERGED GEOMETRY and not a prop, because it is a box —
  // the guard booth's own finding (see the header of render.facility.FacilityEntry), and here it is
  // free: it wears the coping's painted steel at full tiling density and costs ten quads
  public static inline var HATCH_W = 2.4;
  public static inline var HATCH_D = 2.0;
  public static inline var HATCH_H = 1.2;
  // one candidate cell in this rhythm carries something. the same device
  // render.facility.FacilityLamps uses on its lit lines: a phase over (col, row) spreads the picks
  // without a list and without a per-cell roll, so re-entering an area lays them out identically
  public static inline var ROOF_PROP_STEP = 5;
  // and at most this many condensers per building. it is not a cap on a running count — the
  // candidate list is STRIDED down to this plus the dish and the hatch, so what a big roof loses is
  // density and not its far half (see render.facility.FacilityRoof.fill)
  public static inline var ROOF_PROP_MAX = 8;

  // ---- the parking entry's checkpoint ------------------------------------------------------------

  // the boom barrier, in world units, and MERGED GEOMETRY like the booth below it — so like the
  // booth's these are read straight rather than through render.Models.instanced's uniform height
  // scale. that scale is the whole reason the prop needed a reference regenerated three times: a
  // glb's height fixes its width, so its proportion was an art problem with a $0.03 feedback loop.
  //
  // the ARM'S LENGTH IS NOT HERE, and that is the one thing the prop could not do at all: it is
  // derived from the gate hole itself, so a mouth of any width is crossed exactly, where the prop
  // had a single 14.7-unit span whatever the generator cut (see FacilityEntry.barrier).
  //
  // sized off the half-metre unit WALL_H 6.0 fixes: a 0.6 m cabinet standing 1 m tall, and a boom
  // 0.17 m deep hinged 0.75 m up — just under the cabinet's own top, which is what reads as a hinge
  public static inline var BARRIER_CAB_W = 1.2;   // the cabinet's footprint, square in plan
  public static inline var BARRIER_CAB_H = 2.0;   // and its height, the tallest part of the assembly
  public static inline var BARRIER_ARM_W = 0.34;  // the boom's cross-section, across and through
  public static inline var BARRIER_ARM_T = 0.30;
  public static inline var BARRIER_ARM_Y = 1.5;   // the UNDERSIDE of the boom, off the asphalt
  public static inline var BARRIER_TIP = 0.6;     // and how far short of the far kerb its tip stops
  // how far INSIDE the mouth the cabinet stands, off the hole's own boundary. TWO kerb widths, which
  // is the one number here that is measured off something else rather than chosen: the kerb edging
  // protrudes RenderConfig.WALKWAY_BORDER_W over the lower surface at every curbed edge (the same
  // reason FENCE_INSET exists), so flush with the boundary the cabinet stood IN the edging. one width
  // clears it and the second is the gap
  public static inline var BARRIER_INSET = render.RenderConfig.WALKWAY_BORDER_W * 2;
  // the hazard bands, and the cabinet's own louvred steel. the cabinet wore BOOTH_ROOF for one build
  // — a machine housing beside a kiosk taking the kiosk's material — and a lid material read as a lid
  // material stood on end. 4.8 puts 4 of the art's 16 louvres across a 1.2-unit face, a 0.3-unit
  // pitch: deliberately coarse, because from 18-55 units up a realistic 7.5 cm slot is one pixel and
  // reads as noise. it is DERIVED FROM THE SLOT COUNT, so a repaint that deals a different one moves
  // this with it or the pitch changes under it
  public static inline var BARRIER_ARM_TEX = 'textures/facility/barrier-arm.png';
  public static inline var BARRIER_CAB_TEX = 'textures/facility/barrier-post.png';
  public static inline var BARRIER_CAB_TILE = 4.8;
  // world units per band repeat. the art holds SIX bands, so 6.0 puts each at 1.0 unit — 0.5 m, a
  // real boom's pitch — and about 13 of them along the arm. it is also 512/6.0 = 85 texels per world
  // unit against the ground's 57, so the bands are sharper than the asphalt under them
  public static inline var BARRIER_ARM_TILE = 6.0;
  // a NEUTRAL multiplier on the arm's albedo, and the one number here fitted live rather than
  // derived. the art is high-vis paint and gpt painted it as such: 0.311 mean linear, 9.5x the
  // asphalt and 1.6x the booth roof that was itself called a white card before it was lifted down.
  //
  // it is a material `color` and NOT textures.json's `lift` because lift is a GAMMA, and on this art
  // a gamma moves the two bands the wrong way round — it darkens the already-dark red far harder
  // than the white, taking the red UNDER the asphalt it stands over and blowing the 6.8x ratio to
  // 13.8x, which reads as white dashes floating with the red gone. A scalar is LINEAR, so it holds
  // both the ratio and the hue and only moves the level, which is the one thing that is wrong.
  //
  // A/B'd live at the game camera against 0.40 and 0.55, and the RED is what fails first every time:
  // at 0.40 it lands under the asphalt and the bar reads as white dashes with gaps between them, at
  // 0.55 it is a muddy brick that answers "red" only from close up. 0.75 is where the bands read as
  // signal red from 22 units up, which is what a hazard boom is for, and the arm is still plainly
  // dimmer than the booth's own lit windows two cells away
  public static inline var BARRIER_TINT = 0.75;
  // the guard booth, in world units. it is MERGED GEOMETRY and not a prop (see the header of
  // render.facility.FacilityEntry), so unlike every other number in this section these are read
  // straight rather than through render.Models.instanced's uniform height scale — a box wants its
  // three dimensions named, not one dimension and an aspect ratio.
  //
  // sized off the half-metre unit WALL_H 6.0 fixes: a 1.7 m square kiosk standing 2.2 m to the eave,
  // with a 0.85-1.9 m glazing band, on a 4-unit (2 m) parking bay
  public static inline var BOOTH_W = 3.4;        // footprint, square
  public static inline var BOOTH_H = 4.4;        // wall height, to the underside of the roof slab
  public static inline var BOOTH_SILL = 1.7;     // the glazing band's bottom and top, off the asphalt
  public static inline var BOOTH_HEAD = 3.8;
  public static inline var BOOTH_EAVE = 0.45;    // how far the roof slab overhangs the walls, each side
  public static inline var BOOTH_FASCIA = 0.3;   // and how thick it is, i.e. the band that reads as its edge
  // and how hard that band glows. it is NOT WINDOW_EMISSIVE, and the gap is not a taste difference:
  // a window run's panes are half-transparent, sunk in a reveal and read from one side, while these
  // are opaque and wrap a free-standing box, so four of them face the camera at once with no masonry
  // taking any of it. At 2.2 the booth was a white lantern with its mullions blown out. 1.4 puts it
  // level with the lab windows across the lot — a bloom halo, and the frames still legible under it.
  // fitted live at the game camera against those windows, not derived
  public static inline var BOOTH_EMISSIVE = 1.4;
  // and its own roofing, which is NOT the buildings' ROOF. that one is bitumen membrane under gravel
  // ballast, which is what a flat industrial roof over a whole storey is made of and what a kiosk cap
  // is not; on a 4.3-unit slab beside the same aggregate the lot is paved in, it read as one more
  // piece of concrete. Painted steel decking instead — as generated it is 0.1886 linear, 6.9x the
  // bitumen roof and a white card at night, so textures.json lifts it DOWN to 0.0849, a deliberate
  // 3.1x that roof, fitted live at the game camera. It TILES ON ROOF_TILE all the same:
  // 13 seams in the art over 9.0 units is a 0.35 m pan at the half-metre unit, about six of them
  // across the slab, at the ground's own 57 texels per world unit
  public static inline var BOOTH_ROOF = 'textures/facility/booth-roof.png';
  // the parapet's coping cap: precast concrete coping stones, its own art.
  //
  // it wore BOOTH_ROOF for one build, and that was the barrier cabinet's mistake made a second time —
  // a kiosk's painted steel decking is a LID art stood on end, and it was reached for because it
  // MEASURED right (0.0849 linear, 2.6x the cladding) rather than because a coping is made of it. The
  // value was the only part worth keeping, and the new art is lifted onto the same 0.0851.
  //
  // the level is not taste: the coping has to read as a line along the roofline or the parapet is
  // just a taller wall, and both obvious hand-me-downs fail that outright — the street's own
  // city/coping is 0.0320 linear against facility/wall-exterior's 0.0323, and facility/window-head is
  // 0.0462, tried, built and photographed at the game camera, where it was indistinguishable from the
  // cladding under it. UNIFORM TOP TO BOTTOM with VERTICAL joints is the other half, and it is the
  // barrier arm's rule for the same reason: `band` emits the cap and both fascias through face/cap on
  // ONE period, so each is a thin horizontal slice of the image at its own arbitrary offset
  public static inline var COPING = 'textures/facility/coping.png';
  public static inline var COPING_TILE = ROOF_TILE;

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
  // and a hard cap on the PARK's own masts. the lit-line rules key on bordering a walkway, so once
  // the park has a path through it every cell down both its sides qualifies and the lawn ends up
  // lined with lamps — right for a kerb along a road, wrong for one lawn
  public static inline var PARK_LAMPS = 4;
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
  // the longest a ROOM axis may run before the fixture pass splits it again, in cells — the count is
  // ceil(axis / this), so it is a CEILING on the gap and not the gap itself. the pass used to hang
  // exactly ONE fitting over every room whatever its size, which is a fixture per building and not
  // per room: on a generated compound that left the two big labs (9x10 and 10x8 cells) and the
  // hangar (11x8) on a single bulb each. at 6 a room under that size is unchanged at one bulb, those
  // three come back with four, and 12 rooms yield 30 fittings
  public static inline var ROOM_SPACING = 6;

  // and how far apart the CORRIDOR pass stands two of them. corridors had no light source of any
  // kind until it: the room pass reads area.generatorInfo's room rects and a corridor is never in
  // one, so 37% of the interior floor (279 lino cells against 384 of room tile and 88 of hangar
  // concrete) sat at the flat IndoorMask ambient and nothing else. 6 puts about four down
  // a 24-cell corridor — the pools just touch, so there is no dark stretch, and half the 12-slot
  // pool is still free for the rooms seen through the doorways as the player walks
  public static inline var CORR_SPACING = 6;
  // how bright one reads against a room's. a corridor is circulation and a room is where the work
  // happens, so it sits under it
  public static inline var CORR_DIM = 0.7;
  // DERIVED, deliberately. CEIL_MUL above is 1 / INDOOR.direct and not a taste value, so writing the
  // corridor as a FRACTION of it means this follows any future move of INDOOR.direct instead of
  // quietly going stale at an absolute number fitted against the old one
  public static inline var CORR_MUL = CEIL_MUL * CORR_DIM;

  // ---- fake contact shadow where a wall meets an interior floor (render.world.ContactMask) ------

  // the tunnels and the streets do this with one gradient QUAD per wall face (SewerDetail,
  // RoofShadows) and the facility cannot: that shape needs the wall face to BE the cell boundary,
  // which it is underground and is not here, because a facility wall is a slab that insets wherever
  // the wall line does not carry. Built that way first and measured, the strips gapped at every
  // inset and stacked at every notch — see ContactMask's header for the coverage census. So this one
  // is a blurred field instead, and these three replace the quad version's SHADOW_W / SHADOW_ALPHA /
  // SHADOW_Y plus the gradient texture it needed
  public static final CONTACT:render.world.ContactMaskOpts = {
    // the indoor mask runs at 8, but that one only has to land a step in the right place while this
    // is a ramp the eye reads directly as shading on the floor — at 8 it quantises into bands
    px: 24,
    // the entire reach of the shadow, in world units. the tunnels' quad reaches 1.1 with a gradient
    // painted across it; a gaussian's visible ramp runs to roughly twice its sigma either way, so
    // this is that reach expressed as the one number a field needs.
    //
    // SWEPT once the field carried the furniture as well as the masonry, live on one pinned pose
    // against the mask switched off: 0.7 covers 4.16% of the frame at max 34/255, 0.9 covers 5.78%
    // at 35, 1.2 covers 7.98% but the peak falls to 32. so up to about 1.0 a wider ramp costs no
    // depth at all — the pools are small enough that the blur is still spreading them rather than
    // flattening them — and only 1.2 starts trading the peak away. 0.9 was tried and rejected on
    // looks: the extra 39% of reach reads as a wash under the furniture rather than as contact, and
    // the tighter ramp is what says a bench is SITTING on the floor
    blur: 0.7,
    // how dark the floor goes where the mask reads solid. the blurred step sits at HALF strength on
    // the masonry boundary, so the darkest floor fragment there is one touching the wall face at
    // about strength/2 — this is fitted against that and not against anything that renders at 0.9
    strength: 0.9,
  };

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
  // how far out from a WINDOW the ground brightens. a window only — an exterior door threw one of
  // these too and no longer does: a doorway has a real fitting over it now (see the bulkhead block
  // below), so a flat trapezoid under the same lamp is a second light in the same place, drawn from
  // a different height and with an unrelated shape. what makes a window different is that a window
  // has no fitting at all; it lights the ground by BEING A HOLE, which is what this quad draws.
  //
  // the quad starts at the wall CELL CENTRE rather than at the outer face, so its own near fade is
  // buried inside the masonry and only the bright middle and the outward falloff are ever visible
  public static inline var SPILL_DEPTH = 8.0;
  // and how much WIDER the far edge is than the opening, per side. a rectangle reads as a projected
  // slide, not as light: what falls out of a hole in a wall fans, because the opening is a finite
  // aperture and every point of it lights every point of the ground. one cell per side over two cells
  // of depth is a ~27 degree fan, which is enough to be read as a fan and not so much that two
  // neighbouring runs merge into one lit band
  public static inline var SPILL_SPREAD = 4.0;
  // the height the spill is treated as coming FROM, for the fake actor shadows only (nothing is drawn
  // at it). a run's glazing is vertically centred in the wall whatever its length — the pane is sized
  // off WINDOW_ASPECT and the sill takes up the slack — so this is that centre, and it is what makes
  // render.actors.LampShadows scale the shadow: at half the reference bulb's height a window rakes
  // light sideways and throws LONG shadows over a tight pool, which is exactly what a window does
  public static inline var SPILL_Y = WALL_H / 2;

  // ---- the bulkhead lamp over an exterior door -------------------------------------------------
  //
  // NOT A GLB, and the rule that says so is the guard booth's: a hood on a wall is axis-aligned
  // slabs, so it is emitted (see render.facility.FacilityGeom.doorLamp) and gets exact proportions,
  // a tiling texture at full texel density and no unwrap lottery, for FOUR QUADS. generated it would
  // be ~5k tris for something 1.4 units wide. the stronger silhouette-vs-surface test lands the same
  // way: a box hood has neither an outline worth generating nor a pattern worth painting, and what
  // actually reads is the glow on it.
  //
  // it hangs over EVERY exterior door and not only the hangar's, because the read it is there for —
  // "that dark rectangle is a way in" — only works if a door is the thing that is always lit this
  // way. one predicate either way: FacilityGlow.outward says whether a doorway faces outdoors
  public static inline var DOOR_LAMP_W = 1.4;    // across the doorway
  public static inline var DOOR_LAMP_H = 0.5;    // and the hood's own height
  public static inline var DOOR_LAMP_D = 0.6;    // how far it stands off the wall face
  // the hood's own art, and its ONE draw call. it wore WALL_EXTERIOR for a build — merged into the
  // cladding buffer for nothing at all — and a fitting painted in the wall's own art is not a
  // fitting, it is a lump of wall. the file is FEATURELESS on purpose and that is what makes the
  // single period below enough: the hood is 1.4 x 0.6 x 0.5, so `face` samples a 20%-tall slice of
  // the image up the sides and `cap` a different one across the lid, which is the thin-bar slice
  // problem BARRIER_ARM_TILE and BARRIER_CAB_TILE both record. art with no feature in it has no
  // slice to misalign. 2.5 is not a divisor of CELL, for the lattice reason the tile block carries,
  // and puts 256 / 2.5 = 102 texels per world unit on it against the ground's 57
  public static inline var DOOR_LAMP_TEX = 'textures/facility/door-lamp.png';
  public static inline var DOOR_LAMP_TILE = 2.5;
  // the hood's UNDERSIDE, off the floor. clear of DOOR_H 4.0 so it sits on masonry over the lintel
  // and not across the opening, and well under WALL_H 6.0 so it is not confused for a roofline
  public static inline var DOOR_LAMP_Y = 4.5;
  // there is NO cone radius here, and that is worth stating because there was one for a build. the
  // shaft under a hood takes the mast's own geometric radius (see render.facility.FacilityLamps),
  // because a shaft is drawn to outline the circle the SpotLight throws and the SpotLight's angle is
  // shared. what makes it fit a WALL-MOUNTED fitting is that it is half a cone, cut vertically —
  // not that it is a narrower whole one, which was tried and read as a pencil standing in the middle
  // of its own lit circle.
  //
  // how much of the hood's front face the lens is, each axis. the rest of it stays dark housing —
  // a face lit corner to corner is the white-card failure render.facility.FacilityEntry's booth
  // glazing and tools/emissive.py's --modulate both record
  public static inline var DOOR_LENS_W = 0.75;
  public static inline var DOOR_LENS_H = 0.55;
  // and how far the lens stands proud of that face, so it cannot z-fight it. a PHYSICAL gap, which
  // docs/3d-render.md's standing note says three passes of polygonOffset have already lost
  public static inline var DOOR_LENS_EPS = 0.02;
  // WARM, and that is the whole point of it: LAMP_COLOR is a cool 0x9db4d4 LED shared by every mast,
  // fixture and glow quad in the compound, so a doorway lit in the same white is one more lit
  // surface. this is the one light out here that is not that installation, and it marks a door as a
  // door from across the lot. it is a TINT on the shared additive mesh and not a second material —
  // that mesh already multiplies a per-vertex colour, so the hue costs no draw call (see
  // FacilityGlow.WARM) — and a per-post `color` on the spotlight, which LampPost already carries
  public static inline var DOOR_LAMP_COLOR = 0xffb347;
  // the lens's own brightness. read C_PANEL's header before touching it: a quad's rendered
  // luminance is ~2.1 * C at LAMP_COLOR, so 0.43 is where BLOOM_THRESHOLD 0.9 is crossed — and this
  // hue is 1.24x that luminance for the same C (Y_linear 0.540 against 0.435), so the line is 0.35
  // here. a lens is a FITTING and is meant to bloom, like the ceiling panel and unlike the pool.
  //
  // there is NO ground quad under it, and that is the same finding the lamp-head quad in this
  // file's own header records: what lights the asphalt is the CONE and the pooled spotlight, which
  // is all a mast has ever had out here. tried as one, it read as a flat amber card lying on the
  // lot with the cone's shaft landing inside it
  public static inline var C_DOOR_LENS = 0.8;

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
    // DERIVED, not tuned, and read as "out to the masonry face, then half way THROUGH the slab": the
    // emitter centres a slab of WALL_T in its cell, so the first term is FacilityGeom.slab's own inset
    // and the second lands the boundary on the wall's centre-line. it is the one field the tunnels and
    // the wilderness leave at 0 — a facility wall is the first blocker in the game thinner than the
    // cell the mask grids it on.
    //
    // THE SECOND TERM IS WHAT MAKES IT HOLD STILL, and it cost a round to learn. stopping at the face
    // put the wall's outer face on the ramp's 50% point, and `wobble` 0.3 then swung it between 0.278
    // and 0.722 along a single run — measured, and reported from the game as a patchy-black wall. the
    // slab is WALL_T = 2 units through against a `blur` sigma of 0.5, i.e. the two faces are 4 SIGMA
    // apart, so a boundary on the centre-line is the unique placement leaving both of them 2 sigma
    // clear: the inner face lands at ~0.98 and the outer at ~0.02, and the wobble's 0.6 sigma of
    // throw cannot reach either
    blockerInset: ((CityConfig.CELL - WALL_T) / 2 + WALL_T / 2) / CityConfig.CELL,
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
    // and the fill leans this far toward a hemisphere. an up-facing surface takes 1.5x the value
    // above, a down-facing one 0.5x, and a WALL is untouched — which is what lets this land without
    // moving the interior value ladder off its anchor (the ladder is
    // wall 0.1595 / 0.1394, floor 0.1367 / 0.12, bench top 0.0401, all of them TEXTURE values).
    //
    // the floor is the surface that moves most, and it moving is the point: the fixtures are on the
    // CEILING, so a lit room's up-facing surfaces do get more. see IndoorMaskOpts.bounce for the
    // measurement that says a flat fill was ~93% of a prop's pixel
    bounce: 0.5,
  };

  // what a METAL prop indoors reflects — see render.world.PropEnv for why it has to exist before the
  // two lab props can go back on MeshStandard at all.
  //
  // the three stops are the room read off its own value ladder rather than picked: the ceiling
  // carries the fixtures and is the only thing in here emitting, the walls are what a vertical face
  // spends most of its reflection on, and the floor is the darkest of the three. all three sit near
  // INDOOR.ambient's own hue (0x9fb0b4) because everything in a lab is lit by the same cool tubes
  public static final PROP_ENV:PropEnvOpts = {
    sky: 0xc8d4d8,
    horizon: 0x8a969c,
    ground: 0x4e565c,
    // OFF-VERTICAL ON PURPOSE. A lab's lamp banks are overhead, so this leans that way — but aimed
    // dead-up it lands the glint on the shelf tops alone, which are the faces a top-down camera
    // already reads, and the tube frame gets nothing. Tilted, the lobe crosses the round stock as
    // the camera orbits, which is the whole point of it
    keyDir: [ 0.35, 1.0, 0.25 ],
    // one step above `sky`: the fixture itself is brighter than the ceiling it hangs off
    key: 0xd8e2e6,
    // DELIBERATELY SMALL, because this is the WEAKER of the two levers and finding that out is worth
    // recording. Swept against prop-minus-background — the number the whole exercise exists to move,
    // since the trolley shipped 0.9 of 255 different from the floor behind it — it reads
    // 0 -> +8.0, 0.12 -> +14.2, 0.18 -> +17.2, 0.25 -> +20.6, 0.55 -> +34.0. But compare what each
    // lever does to the prop's own INTERNAL spread, which is what actually reads as metal:
    //   PROP_ENV 0.18 -> 0.55 buys +16 of contrast for +1.8 of sd
    //   baseColor 0.60 -> 0.85 (models.json) buys +11 of contrast for +1.6 of sd
    // per point of brightness the albedo factor buys nearly twice the structure, because it scales
    // the bake's own frame-vs-shelf separation while this adds a flat wash over everything. So the
    // albedo carries the metal and this only puts the edge on it. 0.55 was built and rejected on
    // looks for exactly that — past ~0.25 the frame stops reading as steel and starts reading as a
    // light source, the failure render.Models.toLambert's header records from the other direction
    //
    // CORRECTION, measured since: on THIS prop there is no frame-vs-shelf separation for the albedo
    // factor to scale. The trolley's baked 2048 atlas puts 88.2% of its texels in a single 16-count
    // luma band (96-111), so the reference's bright-tubes-against-dark-slabs is not in the bake at
    // all and baseColor moves the LEVEL and nothing else. gas-cylinders IS bimodal (52% at 128-143
    // amber against 29% at 32-47 steel) and that is why it reads and the trolley does not
    intensity: 0.06,
    // the lobe's tightness, fitted live over the trolley's own 54k pixels from a cam pinned at the
    // rig's OWN 65.6-degree pitch — which is not optional, and a shallower pose says the opposite.
    // The whole sweep read as noise from a 17-degree cam because a horizontal face reflects a low
    // view back out at 73 degrees off vertical, and cos(73)^48 is zero: at a shallow angle the lobe
    // CANNOT land whatever it is set to. Measured at the real pitch, against sheen 0's mean 76.19 /
    // p99 83.5:  gloss 8 is a wash (mean 104.1), 20 -> mean 81.2 p99 167, 48 -> mean 78.0 p99 153,
    // 120 -> mean 76.6 p99 105. 48 is where the MEDIAN stops moving (79.1 -> 79.3) while the tail
    // triples — which is the definition of a highlight rather than a brightening
    gloss: 48.0,
    // and its strength. `intensity` above fills the shape in flat; this is the only term in the game
    // that puts a MOVING highlight on a prop, which is what a viewer's env map was doing to the
    // source glb and what nothing in this build could do until it existed. Orbiting the pinned cam
    // through 0 / 0.5 / 1.0 / 1.5 rad, the pixels it lifts by more than 40/255 are 1191 / 136 / 6366
    // / 6277 — a different set of facets at every yaw, which is the deliverable
    sheen: 1.0,
  };
}

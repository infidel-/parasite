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
  // the lift doorway's door pocket — how wide the near-black track strip down each jamb is, and how
  // far proud of the reveal it stands so it draws over it instead of z-fighting with it. 0.3 is
  // 15 cm of slot, which is what a real two-leaf lift entrance shows, and it is CENTRED on the leaf
  // plane so the 0.16 of DOOR_T sits inside it. ONE strip per jamb: a strip at each edge of a
  // 1.2-deep corp reveal showed the corridor's own board between them
  public static inline var LIFT_POCKET_W = 0.3;
  public static inline var LIFT_POCKET_EPS = 0.02;
  // and how deep the SADDLE PLATE lying in the opening is, across the walking direction. 0.6 is
  // 30 cm, half of the corp reveal's own 1.2, centred on the leaf plane — see FacilityGeom.liftSill
  public static inline var LIFT_SILL_D = 0.6;
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
  // and one wall + one floor per ROOM TEMPLATE. picked off the cell a face looks into exactly as the
  // room/corridor pair is (render.facility.FacilityGeom.look), so a themed room costs no generatorInfo
  // and works on the saved grid alone
  public static inline var WALL_OFFICE = 'textures/facility/wall-office.png';
  public static inline var WALL_WASH = 'textures/facility/wall-wash.png';
  public static inline var FLOOR_OFFICE = 'textures/facility/floor-office.png';
  public static inline var FLOOR_WASH = 'textures/facility/floor-wash.png';
  // the office desk, which is the LAB BENCH one texture family apart: same runs, same lip, same
  // casework, so it costs two textures and no geometry (render.facility.FacilityTables picks the pair
  // off the cell's own Surf). And the washroom's cubicle partition, which tiles for the same reason
  // the bench body does — a door rhythm at a fixed pitch, not an authored composition
  public static inline var DESK_TOP = 'textures/facility/desk-top.png';
  public static inline var DESK_BODY = 'textures/facility/desk-body.png';
  public static inline var STALL_PANEL = 'textures/facility/stall-panel.png';
  // and the three surfaces that USED TO BE that one panel, off a 2x2 sheet of their own
  // (art/textures.json facility/wash-pack). ONE LAMINATE IS NOT ONE SURFACE, which is the lesson:
  // stall-panel's art is a cubicle DOOR — a leaf between two pilasters with a latch plate and a pull
  // handle on it — and worn by the whole family it put a door on the cubicle's blank side panels, a
  // door on the basin counter's apron and a door on the wall dividing the men's from the women's.
  // Three more textures and three more draw calls in the one room that has any of them, which is the
  // rack's own trade (see DECO_RACK): the call is what the read costs
  public static inline var STALL_SIDE = 'textures/facility/stall-side.png';
  public static inline var WASH_PARTITION = 'textures/facility/wash-partition.png';
  public static inline var WASH_COUNTER = 'textures/facility/wash-counter.png';
  // and the counter's LID, which was the office desk's laminate — the one piece of cross-ROOM reuse
  // in the washroom. A bottom-up elevation laid flat reads as an elevation lying down, so this is
  // drawn top-down like every other horizontal surface in the compound
  public static inline var WASH_COUNTER_TOP = 'textures/facility/wash-counter-top.png';
  // the mirror over the basin run: the one 0..1 face of the set, so its aspect is locked to the art's
  public static inline var MIRROR = 'textures/facility/mirror.png';
  // the lab benches: the black epoxy worktop (its top face AND its edge band) and the casework
  // cabinet fronts under it. two textures rather than a generated prop, because a bench IS a box —
  // see render.facility.FacilityTables for why the whole run is merged geometry
  public static inline var BENCH_TOP = 'textures/facility/bench-top.png';
  public static inline var BENCH_BODY = 'textures/facility/bench-body.png';
  // and the sink that terminates a bench run (render.facility.FacilitySink): ONE sheet holding BOTH
  // of its quads — the basin seen from above on the left, the tap in elevation on the right — for
  // PLACARD_TEX's reason. Two images would be two materials, two meshes and two draw calls to draw
  // one fixture, where a u/v sub-rect is four numbers. See the SINK_ block down in the bench section
  // for the rects, which are the drop's own measured alpha bboxes and not a designed grid
  public static inline var SINK_TEX = 'textures/facility/sink.png';
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
  // and the twin-door lab case takes three more, off a sheet of its own. Its front is the second
  // 0..1 composition in the family (after the bookcase's) and locks DECO_CABINET_W; its side and top
  // tile, so the depth stays free
  public static inline var DECO_CABINET_FRONT = 'textures/facility/deco-cabinet-front.png';
  public static inline var DECO_CABINET_SIDE = 'textures/facility/deco-cabinet-side.png';
  public static inline var DECO_CABINET_TOP = 'textures/facility/deco-cabinet-top.png';
  // and the machine casing takes the last three, off a 2x2 sheet of its own. NONE OF THEM TILE
  // despite being drawn as swatches — every one carries discrete features that only read whole, so
  // all three map 0..1 and the unit is a cube. See DECO_MACHINE_SZ, where the report is
  public static inline var DECO_MACHINE_FRONT = 'textures/facility/deco-machine-front.png';
  public static inline var DECO_MACHINE_SIDE = 'textures/facility/deco-machine-side.png';
  public static inline var DECO_MACHINE_TOP = 'textures/facility/deco-machine-top.png';
  // and the floor drain, which is a FITTING IN THE FLOOR and reaches the 3D view the same way the
  // rest of this family did: as geometry, not as its atlas icon laid flat. See DECO_DRAIN_SZ
  public static inline var DECO_DRAIN = 'textures/facility/floor-grate.png';
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
  // and the PRIVATE leaf a washroom or an office takes. the one door in the compound with NO vision
  // panel, and that is the art saying what the code does — objects.Door.canSeeThrough is false while
  // this one is shut, where facility/door-cabinet's own note records that no other facility door
  // blocks sight and that its panel exists to say so
  public static inline var DOOR_PRIVATE = 'textures/facility/door-private.png';
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
  // and the diagonal hazard hatch struck inside every exterior door. the one indoor mark that does
  // NOT come off GROUND_PAINT, and it cannot — see ZONE_D
  public static inline var ZONE_TEX = 'textures/facility/floor-hazard.png';

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
  // next as the rows march on inward to fill the middle of the lot.
  //
  // BOTH ARE READ FROM THE GENERATOR and are not numbers here any more: gen.facility.FacilityBays
  // deals which bays hold a car and stamps their footprint on the grid, so the bay rect is now a fact
  // about the SAVE and the paint has to agree with it rather than the other way round. The dependency
  // runs render -> gen, which is the direction everything else here runs in
  public static inline var BAY_CELLS = gen.facility.FacilityBays.DEPTH;
  public static inline var BAY_SPACING = gen.facility.FacilityBays.SPACING;
  public static inline var AISLE_CELLS = 2;
  // and this many cells of bare asphalt are left round every structure. a lab building already has
  // its 2-wide pavement apron and so clears this on its own; the hangar is the one that opens
  // straight onto the lot, and a bay struck against its wall is a spot with a blank six-metre face
  // where the car's nose goes
  public static inline var BUILD_GAP = 2;

  // ---- the aisle marking on the INDOOR floors (render.facility.FacilityPaint.indoor) ------------

  // an aisle is marked at its EDGES and never down its middle, which is the one thing a first build
  // got backwards: a centre line is ROAD logic, a lane divider for two streams passing in opposite
  // directions, and indoors nothing divides. what a building marks is a strip that has to stay
  // clear, i.e. a zone, so it takes a PAIR of lines bounding the walkway.
  //
  // the tint the pair is drawn in. YELLOW is not decoration: ANSI Z535.1 fixes yellow as caution and
  // the floor-marking convention every warehouse and lab runs on assigns it to aisles, traffic lanes
  // and work cells, where WHITE means equipment and fixtures and RED means fire equipment. the lot's
  // own bays and the road's lane lines stay white, which is what they should have been all along
  public static inline var MARK_COLOR = 0xffc61a;
  public static inline var PAINT_COLOR = 0xffffff;
  // a room's long axis must run at least this many cells for it to have an aisle at all, and a line
  // stops this far short of whatever ends its run
  public static inline var MARK_AISLE_MIN = 5;
  public static inline var MARK_AISLE_INSET = 1.2;
  // how far a line is set in from the thing that stopped the walk, and the two are different numbers
  // because the two things are different. THE QUESTION IS "DID FURNITURE STOP ME", NOT "IS THAT A
  // WALL", and the first build asked the wrong one: a DOORWAY is not masonry, so every cell beside an
  // opening took the furniture number and its lane edge stepped 0.5 toward the door — reported from
  // the game as a line moved at every door, and measured at col 14.30 against 14.425 everywhere else.
  // A doorway, a window cell and the grid edge all END the floor exactly as a wall does.
  //
  // A BOUNDARY has to clear what stands against it: CASEWORK is CASE_D 1.4 off a wall face
  // (render.facility.FacilityTables) and a corridor bin stands in the corner. That number is also
  // what keeps the paint out of the contact crease — the paint mesh carries render.world.VisionMask
  // but NOT render.world.ContactMask (only the three interior floors do), so a line laid against
  // masonry draws at full value over floor the field has darkened and reads as lying ON TOP of the
  // shading rather than under it.
  //
  // FURNITURE has to clear what it HIDES, which is a camera number and was fitted as one. The first
  // build set 0.3 on the reasoning that nothing stands off the front of a bench, and the near line
  // came out INVISIBLE for the length of every bench run: measured in the frame, the far line read
  // over its whole run and the near one only in the gaps between the benches. A worktop is
  // `WorldCtx.ground` **2.0** units tall and overhangs its cell by BENCH_LIP 0.2, and
  // CAMERA_FACILITY pitches between atan(20/16) = 51.3 and atan(48/16) = 71.6 degrees, so a bench
  // hides `2.0 / tan(pitch)` = 1.60 / 0.91 / 0.67 units of the floor behind it. 0.2 + 0.91 at the
  // measured gameplay 65.6 is the line this has to clear
  public static inline var MARK_WALL_CLEAR = 1.7;
  public static inline var MARK_FURN_CLEAR = 1.2;
  // the narrowest lane worth marking, applied to a room and a corridor alike, and it is ONE WHOLE
  // CELL of clear floor between the pair rather than a token gap. FLOOR MARKING IS FOR TRAFFIC, and
  // the gap between two bench runs is a work aisle and not a traffic lane: the first build set 1.5,
  // which let a 3-cell room benched down both long walls through on 1.6 units — measured at rows
  // 14.30 and 14.70 — and a pair 1.6 apart reads as one thick line, which is the figure the guard
  // exists to stop drawing. a ONE-cell corridor is 4 units and loses 3.4 to its two boundary
  // clearances, so it stays unmarked at either setting
  public static inline var MARK_LANE_MIN = 4.0;
  // and the widest a ROOM's pair may be before it stops being a lane and becomes a room OUTLINE. a
  // corridor's width is decided by its walls and needs no cap, but a room's is decided by how far the
  // benches stand apart, so a big open lab threw its pair against both walls: measured 25.6 units
  // apart in a 9x10 room, which reads as the room's own edge and not as a route across it. over this,
  // both edges are pulled in equally and the lane stays centred where the clear floor put it
  public static inline var MARK_ROOM_MAX = 8.0;
  // how far a line's OUTER EDGE must stay from the boundary of its own cell, and it exists because
  // MARK_ROOM_MAX above moves a line AFTER the two clearances have been applied and re-checks
  // nothing. A bench worktop OVERHANGS its cell by BENCH_LIP 0.2 on every open side
  // (render.facility.FacilityTables.unit) and stands at BENCH_H 2.0, so a line closer than
  // BENCH_LIP + RenderConfig.LINE_W / 2 to a boundary a bench cell is on the far side of is drawn
  // UNDER the worktop. Measured on a 6x8 lab where the cap's arithmetic landed both lines exactly ON
  // a cell boundary: 6 of its 13 quads touched a top and TWO WERE 100% HIDDEN, both of them the
  // one-cell walkway gap the generator cuts through a bench run at each end of the room.
  //
  // NOT a per-cell test where it moves the LINE, because a line has ONE position for its whole run
  // and the cell on its outward hand changes along it — so it is paid everywhere, and it costs at
  // most 0.29 of lane width on each side. The cell test in `strikes` cannot see this and is not the
  // place to fix it: it bins the line to `int(mid + 0.5 + s * off / CELL)`, which on a boundary
  // rounds to the free side while half the paint lies in the bench's.
  //
  // THE SAME FIGURE INSETS A SEGMENT'S END, and there it IS per cell: a bench in the next cell ALONG
  // the run lips back over this one, so a segment ending flush on the cell boundary runs its last
  // 0.29 under the top and reads as the line going INTO the table rather than up to it. Side and end
  // are the same overhang seen on the two axes and they take the same clearance
  public static inline var MARK_LIP_CLEAR = BENCH_LIP + RenderConfig.LINE_W / 2;

  // ---- the keep-clear zones (render.facility.FacilityPaint.keepClear) ---------------------------

  // A ZONE BELONGS TO FIRE EQUIPMENT, AN ELECTRICAL PANEL OR AN EXIT — never to a doorway as such,
  // which is what a first pass at the aisle above was going to strike and what it correctly dropped.
  // Every interior door boxed off says nothing; the floor is marked where obstructing it is the
  // thing that kills someone. So the input here is FacilityExit's own terminal-door test —
  // FacilityGlow.outward plus circulation behind it — and no placement rule of its own.
  //
  // AND IT IS HATCHED, NOT OUTLINED. An outline is a FOOTPRINT: it says a thing stands here. The
  // hatch is what says do not obstruct, and it is the whole reason this needs art at all.
  //
  // AND IT IS A CUTOUT, because an OPAQUE hatch has to paint a floor it cannot match. It shipped
  // opaque for one build, with the gap painted as floor, and that is the version this block exists
  // to warn off. VALUE it can match: the drop's gap measured 0.1575 linear against the corridor
  // lino's 0.1353, 1.16x and close. HUE it cannot — `facility/floor-lino` is deliberately a pale
  // blue-cyan and a neutral grey band on it reads as a different material however well the value
  // lands. Nor can ONE bake serve TWO floors: every zone here is on lino at 0.1353 and the storage
  // hatch that comes later goes under drums standing in ROOMS, on floor-tile at 0.1185.
  //
  // the cut costs an `alphaTest`, which IS a program key — but not a new program here: the compound
  // already draws alpha-cut Lambert indoors (FacilityDeco's DECO_CUT end frames, FacilityGeom
  // .addPane's glazing), so the permutation exists. Opaque and alpha-tested, never `transparent`:
  // an alpha-tested opaque draws in one pass and still writes depth, which is the argument
  // render.wild.WildGrass' header makes.
  //
  // the tint then stays WHITE, and that is a choice rather than a constraint. A tint multiplies only
  // what survives the cut, so neutral stripes plus one `color` per mesh would serve red and yellow
  // off one map — the trick the aisle runs on, which an opaque gap had made impossible. This art's
  // stripes are painted red, so a yellow panel hatch is still a second drop; the trade is recorded
  // here, not taken
  public static inline var ZONE_COLOR = 0xffffff;
  // where the hatch stops being paint and starts being floor. mid-scale rather than the 0.02 the
  // glazing takes: that one only has a transparent MARGIN to throw away, where this is a real
  // stencil edge and the cut is what gives a chipped band its shape
  public static inline var ZONE_CUT = 0.5;
  // how deep the zone runs into the building from the door's SLAB face — not from the cell boundary,
  // which is a unit further out and under the lintel (see FacilityGeom.slab). 3.0 is 1.5 m at the
  // half-metre unit WALL_H fixes: one unit of it finishes the door cell and two reach into the
  // corridor cell behind, which is the cell the aisle then has to break for
  public static inline var ZONE_D = 3.0;
  // world units per hatch repeat, world-aligned on both axes like every other floor mark, so the
  // stripe pitch is the same at every door however the door is turned. NOT RenderConfig.PAINT_TILE:
  // the art holds four bands per repeat, so 3.0 puts a band at 0.75 units (~37 cm) and a 4x3 zone
  // shows about one whole repeat — which is also why the drop's approximate tiling never shows
  public static inline var ZONE_TILE = 3.0;

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

  // ---- bench sinks -----------------------------------------------------------------------------

  // the sink standing on the end cell of a bench block (render.facility.FacilitySink). TWO QUADS off
  // ONE SHEET: a flat basin lying on the worktop and an upright tap at its back edge.
  //
  // EVERY RECT HERE IS MEASURED OFF THE DROP AND NOT DESIGNED. The sheet was generated with
  // background:"transparent", so there is no seam to find — the two objects' own alpha bboxes ARE
  // the cells, and each is padded outward 2px at the 1024 source so the edge ramp falls inside the
  // rect and alphaTest trims it instead of clipping the silhouette. Basin 618x449, tap 344x493; the
  // numbers below are those pixel rects turned into u/v, with y flipped the way three samples it
  public static inline var SINK_BASIN_U0 = 0.030273;
  public static inline var SINK_BASIN_U1 = 0.633789;
  public static inline var SINK_BASIN_V0 = 0.280273;
  public static inline var SINK_BASIN_V1 = 0.718750;
  public static inline var SINK_FAUCET_U0 = 0.654297;
  public static inline var SINK_FAUCET_U1 = 0.990234;
  public static inline var SINK_FAUCET_V0 = 0.281250;
  public static inline var SINK_FAUCET_V1 = 0.762695;
  // the basin's width across the bench, world units — the ONE free number of the pair. 62.5% of a
  // 4-unit cell, which still leaves 0.74 of worktop clear on each side after the depth lock below,
  // so the rim never reaches a cell boundary even where the lip was suppressed for a doorway
  public static inline var SINK_BASIN_W = 2.5;
  // and its depth, DERIVED: the face maps its crop 0..1, so its aspect is the crop's or the art is
  // stretched. 449 / 618 of the measured rect, written as the product that produced it so the
  // coupling cannot be edited away by accident — the lock DECO_SHELF_D and DECO_BOOKCASE_W carry
  public static inline var SINK_BASIN_D = SINK_BASIN_W * 0.726537;
  // the tap's drawn height. the second free number, and it is NOT the real-world proportion: this
  // quad is VERTICAL and unleaned, so at the camera's 51 degrees it foreshortens to cos 51 = 0.63 of
  // whatever is written here. 1.6 draws as ~1.0 on screen, which sits under the 2.43 a bench sprite
  // draws (Sprites.SIZE * DECO_TABLE_SCALE) — a tap is shorter than a retort stand.
  //
  // AND IT IS INDEPENDENT OF THE BASIN ON PURPOSE. The sheet's own ratio is 0.557 (the tap rect is
  // 344 of the basin's 618), which the pair matched exactly while SINK_BASIN_W was 2.0; the basin was
  // then taken up to 2.5 alone, so the tap is now drawn at 0.45 of it rather than 0.56. That is a
  // bigger BOWL under the same tap, which is what a deeper sink actually is — the two numbers are
  // free of each other and only their own crop's aspect is locked
  public static inline var SINK_FAUCET_H = 1.6;
  // and its width, DERIVED off the same 0..1 lock: 344 / 493 of the measured rect
  public static inline var SINK_FAUCET_W = SINK_FAUCET_H * 0.697769;
  // how far the tap's own COLUMN sits left of the centre of its rect, as a fraction of that rect's
  // width. it is not centred and cannot be: the bbox is the whole silhouette, and the handle sticks
  // out to the left while the spout arches to the right. Measured off the foot alone (the mounting
  // base spans x 739..909, centre 824, against a rect centre of 841.5), and the quad slides by this
  // so the tap STANDS on the cell centre rather than being hung by its bounding box
  public static inline var SINK_FAUCET_AXIS = 0.05087;
  // how far the basin floats over the worktop it lies on. it MUST clear zero — the worktop cap sits
  // at exactly BENCH_H (FacilityTables.build) and a coplanar quad z-fights across its whole
  // footprint — and it must clear POOL_EPS 0.01 as well, so that where a neighbouring cell's deck
  // pool reaches this one the opaque basin wins the depth test and the transparent pool is hidden
  // under it rather than painted over it
  public static inline var SINK_Y = 0.02;
  // where the sheet's alpha stops being metal and starts being air. DECO_CUT's own value and for its
  // reason: an OPAQUE alphaTest draws DoubleSide in one pass and still writes depth, where a
  // transparent twin would sort against every other see-through thing in the compound for nothing
  public static inline var SINK_CUT = DECO_CUT;

  // ---- worktop clutter -------------------------------------------------------------------------

  // the small FLAT things scattered over the bench tops — a clipboard, a petri dish, a coiled cable.
  // one 1024 sheet, an 8x8 grid of 128 px cells, every cell a top-down cut-out. see
  // render.facility.FacilityClutter and docs/3d-textures.md's PACK-N section for why 8x8 is the right
  // grid HERE and the wrong one for a billboard: density is art px over the world size a thing is
  // DRAWN at, and at CLUTTER_SZ these get 111 texels per unit against facility/floor-tile's 73
  public static inline var CLUTTER_TEX = 'textures/facility/worktop-clutter.png';
  public static inline var CLUTTER_COLS = 8;
  public static inline var CLUTTER_CELLS = CLUTTER_COLS * CLUTTER_COLS;
  // DECO_CUT again, and for SINK_CUT's reason: an opaque alphaTest draws DoubleSide in one pass and
  // still writes depth, so nothing has to sort against the worktop under it
  public static inline var CLUTTER_CUT = DECO_CUT;
  // how far a decal floats over the worktop. UNDER SINK_Y 0.02 on purpose — a clutter cell and a sink
  // cell are mutually exclusive (see FacilityClutter.build), so these two never meet, and staying
  // below the basin means a future pass that did overlap would be hidden by it rather than fighting
  // it. still well clear of zero, which is where the worktop cap itself sits, and of POOL_EPS 0.01
  public static inline var CLUTTER_Y = 0.015;
  // how big one decal draws, world units, before its own variance. the bench scale is ~2.08 units to
  // the metre (DECO_TABLE_SCALE's own measurement: a 1.08 m microscope at 2.25 units), so 0.8 is a
  // ~38 cm object — a clipboard, a keyboard, a folded pair of gloves
  public static inline var CLUTTER_SZ = 0.8;
  public static inline var CLUTTER_SZ_VAR = 0.3;
  // most cells get one or two, some none, some three. THE EMPTY CELLS ARE THE POINT: floor this at 1
  // and 139 bench cells read as a grid again, which is the rhythm this family exists to break
  public static inline var CLUTTER_MAX = 3;
  // how many offsets a decal tries before it gives up and simply is not placed. a cell is 4 units and
  // a decal is under one, so a rejection is rare and an exhausted item rarer still
  public static inline var CLUTTER_TRIES = 8;
  // the half extent to keep clear around a decoration that LIES DOWN. those leave no pool in
  // FacilityModel.tableDeco (nothing flat casts the shadow that grid exists to place) but they are
  // still art on the worktop, so they get a nominal footprint rather than being treated as empty
  public static inline var CLUTTER_FLAT_R = 0.9;
  // and how much clear worktop to leave BETWEEN two of them — without it two items merely touching
  // read as one broken object. ONCE PER PAIR and not inside each box: carried in both it is counted
  // twice, which is 0.24 of a 2.6-deep desk spent on nothing. See ClutterSlotTools.hits
  public static inline var CLUTTER_GAP = 0.12;
  // how big the item an office DESK is given draws, against CLUTTER_SZ on an open bench. Smaller
  // because the slot is: it takes the front row of the desk's far end, which is 1.13 of worktop
  // between the keyboard's edge and the cell's, and a 0.8 decal turned 45 degrees does not clear the
  // keyboard there. See FacilityClutter.cell
  public static inline var CLUTTER_DESK_SZ = 0.7;
  // ---- the CLUTTER SLOTS: the same decals, on the LID of a piece of standing furniture -----------
  //
  // a worktop is not the only flat surface at hand height in this compound. A bookcase's top and the
  // lounge table are both reachable, both empty, and both read as a moulded block without something
  // left on them. The slot is the fitting's own rect (render.facility.FacilityDeco.rectOf) at its own
  // height, so nothing here has to know the shape of either object.
  //
  // FEWER THAN A BENCH GETS, and that is the surface and not the taste: a bookcase lid is
  // DECO_BOOKCASE_W x _D against a bench's whole 4 x 4 cell, so the same count would cover it
  public static inline var CLUTTER_SLOT_MAX = 2;
  // how far in from the lid's edge an item's CENTRE may go, on top of its own half size — a decal
  // half over the edge reads as a broken object where one half over a worktop's edge never could,
  // because a worktop's edge is the cell and this one is the thing itself
  public static inline var CLUTTER_SLOT_INSET = 0.10;
  // and the largest an item may be as a fraction of the lid's SHORTER side. A bench decal is sized
  // for a 4 x 4 cell and a lounge table is DECO_TABLE_LOW_D 1.2 deep: at CLUTTER_SZ 0.8 plus its
  // variance plus the inset there was no wander left at all on that axis, so the sampler rejected
  // every roll and the table shipped bare. Sizing the item to the surface is what a small surface
  // asks for, and it is the same rule CLUTTER_SZ itself was fitted by — art px over the size a thing
  // is DRAWN at
  public static inline var CLUTTER_SLOT_FILL = 0.62;
  // and the STORAGE lid's own count, against CLUTTER_SLOT_MAX 2 on a bookcase's top. A shelving
  // plate is 2.32 x 1.38 where a cabinet's lid is 1.2 deep, and it is the surface things are MEANT
  // to be on rather than the top of something else
  public static inline var CLUTTER_STORE_MAX = 4;
  // how many of a storage lid's rolls come up a CARDBOARD BOX rather than a decal off the sheet.
  // The shelving used to place 1..3 boxes per plate and nothing else, ever, so a unit was the same
  // object every time; this is what "mixed with room clutter" means as a number. Over half, because
  // a storage shelf IS boxes and the jars and paperwork are what says somebody uses it
  public static inline var CLUTTER_BOX_PCT = 55;
  // the sheet cells that are never dealt, 0-based, because they read as a HOLE PUNCHED IN THE BENCH
  // rather than as a thing lying on it.
  //
  // AND THE TEST IS NOT DARKNESS ALONE, which is what makes this a list and not a lift. Twelve of the
  // 64 cells come in under facility/bench-top's own 0.0401 linear, but in game the tweezers at 0.0198
  // and the coiled cable at 0.0195 read perfectly as dark objects while the tablet at 0.0266 read as
  // a gap in the worktop. What separates them is SOLIDITY — opaque px over bounding-box area, i.e.
  // whether the silhouette is a filled slab or an outline with worktop showing through it. Every cell
  // here is dark AND over 0.62 solid; every dark cell under that threshold was left in and looks
  // right. Measured: 15 tablet 1.00, 14 calculator 0.98, 64 screwdriver pouch 0.94, 17 mouse mat 0.94,
  // 56 hole punch 0.87, 16 keyboard 0.70, 48 radio 0.67 — against 54 stoppers 0.56, 21 cable 0.50,
  // 59 glasses 0.49, 49 torch 0.40, 62 soldering iron 0.30.
  //
  // A LIFT CANNOT DO THIS JOB and that was checked before reaching for a list: the gamma needed to
  // bring 0.0177 over the worktop is 0.78, which drags the sheet's median from 0.1202 to 0.191 and
  // washes out the 52 cells that were already right
  public static var CLUTTER_SKIP:Array<Int> = [ 13, 14, 15, 16, 47, 55, 63 ];
  // and the office desks' sheet, cut the same way: paper, folders, a keyboard, a mug. its own skip
  // list, MEASURED against facility/desk-top the same way the one above was measured against the
  // bench — dark AND solid is the test, and an empty list means the measurement says nothing reads as
  // a hole in the desk
  public static inline var CLUTTER_OFFICE_TEX = 'textures/facility/office-clutter.png';
  public static var CLUTTER_OFFICE_SKIP:Array<Int> = [];

  // ---- the washroom (render.facility.FacilityDeco's two themed fittings) -------------------------

  // all of these are written at the compound's own scale, where WALL_H 6.0 is one 3 m storey and a
  // world unit is half a metre.
  //
  // a cubicle is exactly ONE CELL wide (4.0) and that is not a taste number: the partition between two
  // of them stands on the shared cell boundary, so a run of them only reads as a rank of cubicles if
  // every plane lands on the same grid the cells do. Emitted ONCE per boundary — see FacilityDeco
  // .stall, which takes its `head` side always and its `head + 1` side only at the end of a run
  public static inline var STALL_W = CityConfig.CELL;
  // 1.4 m deep and 1.9 m to the top of the partition: a real WC cubicle, and low enough under WALL_H
  // that the room reads OVER the rank rather than as a set of closed boxes
  public static inline var STALL_D = 2.8;
  public static inline var STALL_H = 3.8;
  // the leaf's own clearance over the floor, 12 cm — the gap under every public stall door there is,
  // and what stops the rank reading as a row of lockers
  public static inline var STALL_DOOR_GAP = 0.5;
  // the laminate's period. the HEIGHT, so one panel is one image top to bottom and the art's rails
  // and its door line land where they were drawn; u then tiles by the panel's own length
  public static inline var STALL_TILE = STALL_H;
  // the basin counter: one per cell, 1.1 m deep so the 1.82-deep basin art lies on it with a margin
  // fore and aft, and 0.9 m to the rim. the counter wears the cubicle's laminate — one buffer, one
  // draw call for the whole washroom's casework
  public static inline var BASIN_W = CityConfig.CELL;
  public static inline var BASIN_D = 2.2;
  public static inline var BASIN_H = 1.8;
  // the mirror over it. SQUARE because the art is square, the notice board's own rule — a texture is
  // never stretched, so a 0..1 face is sized off its image and not off the wall it hangs on. centred
  // 1.7 m up, MOUNT_PROUD off the masonry face like every other wall-mounted quad in the compound
  public static inline var MIRROR_W = 2.0;
  public static inline var MIRROR_H = 2.0;
  public static inline var MIRROR_Y = 3.4;
  // the dividing wall between the washroom's two halves (render.facility.FacilityDeco.partition).
  // HEAD-HEIGHT AND OVER, unlike the cubicle partitions beside it, and that is the read: a cubicle is
  // a box inside a room and this is what makes two rooms of one. 0.6 thick = 30 cm, which is a stud
  // wall with a skin either side
  public static inline var PART_T = 0.6;
  // 2.5 m of it, and it WAS WALL_H for one build, which is two faults in one number. It was too tall
  // to read as a divider — a washroom came out as two sealed cells rather than one room split — and
  // its LID landed exactly on ROOF_Y, which IS WALL_H, so the cope and the roof deck z-fought along
  // the whole run at the one height the camera looks straight down on. A metre under the deck fixes
  // both: still a head over anything standing in either half (STALL_H is 3.8), still opaque from this
  // camera, and nowhere near a coplanar pair
  public static inline var PART_H = WALL_H - 1.0;
  // and its texture period, which is its OWN HEIGHT and was STALL_TILE 3.8 for one build. The art is
  // composed bottom-up — a skirting shadow at the floor and nothing repeating above it — and
  // FacilityGeom.face maps v as y / period, so a 3.8 period on a 6.0 wall wrapped the composition at
  // 63% of the height and drew a second skirting band straight across the middle of the divider.
  // Every caller in this family passes the thing's own height for exactly this reason (STALL_H 3.8,
  // BASIN_H 1.8), and this is the one that was not
  public static inline var PART_TILE = PART_H;
  // ---- the researcher's office ------------------------------------------------------------------

  // the office desk is the lab bench MADE THINNER, and this is the only geometry difference between
  // them. a bench is a full cell deep (4.0) because a laboratory worktop is a working surface with
  // services behind it; a writing desk is 80 cm, and at this camera the difference is the whole read —
  // a full-cell desk is a counter. Applied to the OPEN side alone (the side away from the wall the
  // run hugs), so the worktop still meets the masonry and no gap opens behind it
  public static inline var DESK_D = 2.6;
  // and the desk's END panels, which take art of their own: a run's short faces are a plain carcass
  // side, where the long face into the room is the drawer front. It is facility/desk-body with the
  // drawers painted out — one edit, not a second family
  public static inline var DESK_SIDE = 'textures/facility/desk-side.png';

  // ---- the workstation (render.facility.FacilityWork) --------------------------------------------
  //
  // EVERY NUMBER BELOW IS ALSO THE MODEL'S, and that is the point of the route it takes now. The set
  // was a generated glb (blocky, 1,200 tris on three slabs), then 22 emitted quads off the
  // facility/workstation sheet (right proportions, no silhouette at all), and is now three glbs
  // HAND-MODELLED IN BLENDER against these constants — models-src/facility/computer_build.py reads
  // them off this block, so a dimension changed here is a re-run of that script and `make models`,
  // not a re-fit. See the header of render.facility.FacilityWork for the three verdicts.
  //
  // THE SHEET IS STILL THE ART and is no longer sampled at runtime: facility/workstation's four
  // authored cells (screen, case, tower front, keyboard) are UV'd onto those meshes at BAKE time and
  // packed into each glb, so the cell indices live in the build script rather than here. What the
  // script does NOT take from the art is a cell's full quadrant — two of the four draw an object on
  // a plate, see that file's SUB table
  //
  // the monitor: 0.9 m to the top of the screen, 0.6 m across, a hand's depth front to back. HALF AS
  // BIG AGAIN as the glb it replaces (COMPUTER_H was 1.2), because that one was reported as not
  // reading at all — the facility camera is 18-55 units up and a 1.2-unit object on a 2.0-unit worktop
  // is 24 device px
  public static inline var WORK_SCREEN_W = 1.7;
  public static inline var WORK_SCREEN_H = 1.25;
  public static inline var WORK_SCREEN_D = 0.18;
  // its stand: the post under it and the foot the post stands on
  public static inline var WORK_STAND_W = 0.30;
  public static inline var WORK_STAND_H = 0.45;
  public static inline var WORK_FOOT_W = 0.75;
  public static inline var WORK_FOOT_D = 0.5;
  public static inline var WORK_FOOT_H = 0.07;
  // the tower standing beside it, ON the worktop: 1.1 m tall, 0.4 wide, 0.85 deep at the half-metre
  // unit. a desktop case stood on end, which is where one lives on a desk with no pedestal under it
  public static inline var WORK_TOWER_W = 0.8;
  public static inline var WORK_TOWER_H = 1.75;
  public static inline var WORK_TOWER_D = 1.5;
  // and the keyboard lying in front of the screen
  public static inline var WORK_KEY_W = 1.5;
  public static inline var WORK_KEY_D = 0.6;
  public static inline var WORK_KEY_H = 0.1;
  // where the set sits on the cell: the screen's centre back from the desk's open edge, the tower's
  // own centre to one side of it, and the keyboard forward of the screen. all measured from the
  // WALL edge of the cell, the hand the desk backs onto
  public static inline var WORK_BACK = 1.0;
  // 1.5 AND NOT THE 1.25 IT SHIPPED AT, which was exactly WORK_SCREEN_W / 2 + WORK_TOWER_W / 2 — the
  // two slabs touched along their whole height and read as one object with a step in it. A gap is what
  // says they are two things, so the offset carries 0.25 of clear worktop between them; the tower's
  // outer face lands 1.9 from the screen's centre, still inside the cell's own 2.0 half-width
  public static inline var WORK_TOWER_OFF = 1.5;
  public static inline var WORK_KEY_FWD = 1.05;
  // and the TRINKETS, which take the END of the desk the TOWER is not on: the RUN is how far along the
  // wall that end is from the screen's centre, and BACK and FWD are the two rows of it — one behind
  // the screen's own line and one in front, the two slots render.facility.FacilityWork.spots deals.
  //
  // TWO ROWS AND NOT TWO POINTS ON ONE. They used to be 0.95 and 1.55 along the BACK row, 0.6 apart,
  // where a 0.40 mug and a 1.00 document tray overlap by construction however either is rolled —
  // reported from the game as a trinket on the other decoration. A 4.0 x 2.6 desk has 1.13 of clear
  // worktop down its far end and 1.7 of depth to spread over, so the free room is on the OTHER axis.
  //
  // RUN 1.40 is the widest of the four clearing the screen's own 0.375 on one side and the cell's 2.0
  // half-width on the other; FWD 1.10 puts the front row clear of the 1.5-wide keyboard beside it
  public static inline var WORK_TRINKET_RUN = 1.40;
  public static inline var WORK_TRINKET_BACK = 0.50;
  public static inline var WORK_TRINKET_FWD = 1.10;
  // HOW OFTEN EACH OF THE TWO IS THERE AT ALL, and a mug on every desk was the first build's rule.
  // It reads as stock: the whole point of a desk being somebody's is that the next one along is not
  // the same, and two placed objects at two fixed offsets on every desk in the compound is the grid
  // this family exists to break. Percent, rolled off the cell.
  //
  // 30 AND NOT THE 70 IT SHIPPED AT, reported twice from the game as a cup on nearly every desk. 70
  // was chosen when the front slot had no other claimant; it has one now — FacilityClutter offers the
  // same slot to the office sheet's own paperwork the moment no mug takes it, so the slot is FILLED
  // either way and the only thing the number decides is how often the thing in it is the SAME object.
  // At 70 the compound deals one mug model 12 times and reads as issue kit; at 30 the rest of the
  // slots come back off a 64-cell sheet, which is the random clutter that was asked for
  public static inline var WORK_MUG_PCT = 30;
  public static inline var WORK_TRINKET_PCT = 55;
  // and how far one may wander off its nominal spot, world units each way. Small on purpose — the
  // spot is already the only free strip of a 4 x 2.6 desk (see WORK_TRINKET_RUN), so this is a hand
  // putting a mug down rather than a second placement rule. 0.12 AND NOT THE 0.22 IT SHIPPED AT: the
  // wander is now tested against the desk's claim list rather than against one circle, so a big jitter
  // no longer reads as variety, it reads as a trinket that was dropped
  public static inline var WORK_TRINKET_JIT = 0.12;
  public static inline var WORK_MUG_H = 0.34;
  public static inline var WORK_MUG_W = 0.40;
  public static inline var WORK_PLANT_H = 0.72;
  // 0.53 AND NOT THE 0.64 IT SHIPPED AT, and it follows the mesh as it always has: the skirt tier's
  // pitch went 22 -> 44 degrees to stop the lower leaves passing through the pot rim
  // (models-src/facility/desk_build.py), which stands the whole crown up and takes the plant from
  // 0.6164 x 0.7159 across to 0.5146 x 0.5265. A claim box wider than the thing it claims for is only
  // a waste of worktop, and this one is the widest of the four trinkets' boxes on a 1.13 strip
  public static inline var WORK_PLANT_W = 0.53;
  public static inline var WORK_LAMP_H = 1.12;
  public static inline var WORK_LAMP_W = 0.70;
  public static inline var WORK_TRAY_H = 0.19;
  public static inline var WORK_TRAY_W = 1.00;
  public static inline var WORK_TRAY_D = 0.75;
  // the stack of logbooks, measured off its own mesh (0.802 x 0.629 x 0.32) rather than rounded: the
  // top book is turned 15 degrees, so the claim box is the TURNED stack's footprint and not one book's
  public static inline var WORK_BOOKS_H = 0.32;
  public static inline var WORK_BOOKS_W = 0.80;
  public static inline var WORK_BOOKS_D = 0.63;
  // one desk cell in this many carries a set, and it is ONE — every desk in a researcher's office has
  // a machine on it.
  //
  // IT WAS 3 AND THAT WAS THE LAB'S ARGUMENT IN THE WRONG ROOM. The reasoning was that a workstation
  // on every cell reads as a computer lab, which is true of a laboratory BENCH run — a bench is a work
  // surface and a screen on every metre of it is a server room. A desk is not a work surface, it is
  // somebody's PLACE: the compound's offices deal 4-9 desk cells, so at 3 a room came back with two
  // machines and four bare desks, reported as exactly that. Every cell that carries a set carries the
  // whole set — screen, tower, keyboard, leads, lights, a chair behind it (FacilityWork.chairs) and one
  // item of the occupant's on the worktop (FacilityClutter.cell's floor) — which is the consistency
  // the thinning was costing.
  //
  // the gate STAYS rather than becoming a constant 1: it is the one knob between here and a computer
  // lab, and the roll is off FacilityModel.mix so it comes back identical on every rebuild
  public static inline var WORK_EVERY = 1;
  // THE KEEP-CLEAR ROUND THE SET IS GONE, and both of the radii that preceded it with it. WORK_R 1.6
  // was a single ROUND contact pool under the whole set and read as a mat (FacilityWork.pools lays one
  // square quad per object now); WORK_CLEAR 1.05 was the circle the clutter sheet kept off it, one
  // number for a screen, a tower and a keyboard together. On a 4.0 x 2.6 desk that circle sat on the
  // SCREEN and the tower stands 1.5 away and is 1.5 deep, so 0.85 of its length was outside the circle
  // — reported from the game as a decal lying under the tower. Each machine carries its own box in
  // render.facility.FacilityWork.base now; see ClutterSlot for why the radius could not be widened
  // into being right instead
  // the tower's status LEDs: how many, how big, and how far proud of its front face they float. they
  // go into render.facility.FacilityDeco's OWN led buffer through its extra-buffer hook, so they cost
  // no mesh, no material, no program and no per-frame work — the rack's blink branch and the rack's
  // shared uTime already do all of it. DECO_LED_RATE 0.35 is one blink per ~3 turn-durations, which
  // is the slow pulse a machine at rest has
  public static inline var WORK_LED_N = 2;
  public static inline var WORK_LED_SIZE = 0.12;
  public static inline var WORK_LED_EPS = 0.03;
  // how far the screen leans BACK, degrees. THE ONE MODEL NUMBER THAT WAS NOT A CONSTANT: the tilt
  // lived only in models-src/facility/computer_build.py, and the moment anything in the game had to
  // know where the screen's FACE is — the glow below does — it needed the same angle the mesh was
  // built with. That file copies this block verbatim, so the two cannot drift
  public static inline var WORK_SCREEN_TILT = 8.0;
  // the glow ON that face, and it is the SCREEN'S OWN art that picks its colour, not taste. The glass
  // cell of facility/workstation.png measures rgb 45/59/65 with 88% of its texels in hue 180-210
  // (tools/pix.py --box glass,9,9,247,233 --hue), so the accent here is that ratio taken up to
  // something a lit panel would be. FacilityStyle's own warning that BLUE is the accent which cannot
  // read against this compound's blue lighting is about a DIFFUSE accent; this one is ADDITIVE, so it
  // arrives as brightness and the hue only tints it
  public static inline var WORK_SCREEN_GLOW = 0xb6e4f4;
  // and its level. FITTED DOWN FROM 0.35, and it stays where it was fitted: the glow is EVEN now
  // (FacilityWork.screen collapses the quad's uv onto the ramp's flat centre) rather than an oval
  // with a hot core, so the peak is unchanged and the read is not. Well under the ~0.43 that crosses
  // BLOOM_THRESHOLD, which is what keeps a lit panel from haloing like a light fitting — the bright
  // spot reported on it was never the bloom, it was the speck's falloff stretched over a monitor
  public static inline var WORK_SCREEN_LEVEL = 0.10;
  // the lit part of that face as a fraction of the screen's own W and H, and it is now the art's
  // MEASURED CONTENT exactly: computer_build.py's SUB table crops the UVs to rows/cols 9..247 and
  // 9..233 of the cell's 256, i.e. 0.93 and 0.875. They used to be pulled inside that for the round
  // ramp's sake — an ellipse drawn on the full glass touches the bezel at the centre of each edge and
  // leaves the corners black — and with the ellipse gone there is nothing to pull in from. A screen
  // that is on is lit to its own bezel
  public static inline var WORK_SCREEN_GLOW_W = 0.93;
  public static inline var WORK_SCREEN_GLOW_H = 0.875;
  // and the leads: keyboard to screen and keyboard to tower, drawn with render.facility.FacilityCable
  // .strip into that family's OWN ribbon buffer, so they ride its texture, its mesh and its draw call.
  // a flatter bow than a wall drop's — a lead lying on a desk sags across the surface, it does not
  // hang — and the wave is what stops two runs on neighbouring desks reading as one ruled line
  public static inline var WORK_CABLE_BOW = 0.22;
  public static inline var WORK_CABLE_WAVE = 0.09;
  // how far the lead floats over the worktop it lies on. between CLUTTER_Y and SINK_Y for their
  // reason: the cap itself is at zero and a coplanar ribbon z-fights the whole length of its run
  public static inline var WORK_CABLE_Y = 0.018;

  // the office chair, the one glb of the researcher's set — a real irregular silhouette (a shaped
  // back, arms, a five-star base on castors) and so the case FOR a mesh generator, where the
  // workstation above is the case against one.
  //
  // 1.365 m to the top of the back, up 30% from 1.05 on the report that it was too small. The glb's
  // own box is 1.231 x 2.099 x 1.294 and render.Models.instanced scales by HEIGHT alone, so this
  // number sets the FOOTPRINT too: 1.601 x 1.683, up from 1.231 x 1.294. That is what drags
  // CHAIR_OUT below with it — a scale applied here alone drives the chair straight back into the
  // casework, which is the fault the DESK_D note beneath it was written about
  public static inline var CHAIR_H = 2.73;
  // how far its CENTRE stands off the desk's own open FACE — not off the cell edge, which is what
  // it used to mean and is where a 1.35 gap came from: an office desk is DESK_D 2.6 deep in a 4.0
  // cell, thinned on the OPEN side alone so the run hugs the wall, so its face sits
  // DESK_D + BENCH_LIP - CELL/2 = 0.8 from the cell centre and a full 1.2 INSIDE the cell edge.
  // FacilityWork.chairs derives that rather than carrying the number, so it cannot drift from DESK_D.
  //
  // AND THE FLOOR ON THIS IS THE JITTER, NOT THE CHAIR. The plan footprint is 1.601 by 1.683 at
  // CHAIR_H above, so a yaw of CHAIR_YAW_JIT swings the reach along the desk axis to
  // 0.841*cos(0.35) + 0.800*sin(0.35) = 1.065 — at 1.131 the front wheels just touch the desk at
  // full jitter and clear it by 0.29 when square. Anything smaller drives the chair through the
  // casework, which is solid to BENCH_H 2.0 with no knee-hole to tuck into.
  //
  // IT IS CHAIR_H's OWN SCALE AND NOT A SECOND TASTE NUMBER: 0.87 * (2.73 / 2.1) = 1.131, so the
  // two fitted clearances scale with the chair rather than being refitted — 0.223 square and 0.051
  // at full jitter become 0.290 and 0.066, the same fractions of a chair 30% larger. The cost is
  // where the chair now STANDS: its far edge sits 0.77 past its cell's boundary at an office desk
  // (was 0.32) and 2.17 past at a full-depth worktop, both inside the cell `seat` already demands
  // be clear floor.
  //
  // A chair pushed dead square under every desk reads as a showroom, which is what the jitter buys
  // and what it costs: every centimetre of yaw play is a centimetre the chair has to stand back
  public static inline var CHAIR_OUT = 1.131;
  public static inline var CHAIR_YAW_JIT = 0.35;

  // the WC pan itself, the other glb of the set: 0.75 m to the cistern top and 0.7 m front to back.
  // render.Models.instanced scales by HEIGHT alone, so TOILET_D is only used to stand it off the wall
  public static inline var TOILET_H = 1.5;
  public static inline var TOILET_D = 1.4;

  // ---- the room signs (render.facility.FacilityPlacard.rooms) -------------------------------------
  //
  // the plate beside a THEMED room's door, on the CORRIDOR side — which is the side that needs it, and
  // the side the lab placards never reach (those are gated on Surf.TILE and hang inside the room).
  // ONE 2x2 sheet for all four: men, women, and two office nameplates whose text is deliberately
  // illegible, because a legible one would have to say a name and the compound has no names
  public static inline var SIGN_TEX = 'textures/facility/room-signs.png';
  public static inline var SIGN_COLS = 2;
  public static inline var SIGN_MEN = 0;
  public static inline var SIGN_WOMEN = 1;
  public static inline var SIGN_OFFICE_A = 2;
  public static inline var SIGN_OFFICE_B = 3;
  // the cells are square and the art is square, so W == H and nothing is stretched — the notice
  // board's rule. smaller than a PLACARD_W 1.8 hazard plate: a door sign is read from a metre away
  public static inline var SIGN_W = 1.3;
  public static inline var SIGN_H = 1.3;
  // how high its centre hangs. over head height and under the lab placards' 4.75, so a corridor with
  // both in it reads as two registers of signage rather than one ragged line
  public static inline var SIGN_Y = 4.0;

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
  // its two trays, as fractions of that height — what render.facility.FacilityClutter stands things
  // on. The glb's own TR_LV, and the trolley is the one prop in the compound whose lids are dressed
  // without a grid cell behind them
  public static final KIT_TROLLEY_SHELF_Y = [ 0.275, 0.650 ];
  // and their DEPTHS across the wall they stand against, off each glb's own measured z extent
  // (0.317 and 0.453 of its height). the placer works off the wall FACE, so this is what turns a
  // face into a centre — half of it, plus the gap
  public static inline var KIT_GAS_D = KIT_GAS_H * 0.317;
  public static inline var KIT_TROLLEY_D = KIT_TROLLEY_H * 0.453;
  // and the WIDTHS along that wall, off the same glbs' x extents (0.875 and 0.988). render.Models
  // .instanced scales by height alone, so these are what the props already draw at — nothing here
  // sets a size. they exist because render.world.ContactMask needs a FOOTPRINT to darken the floor
  // under, and the placer only ever had to know the depth
  public static inline var KIT_GAS_W = KIT_GAS_H * 0.875;
  public static inline var KIT_TROLLEY_W = KIT_TROLLEY_H * 0.988;
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

  // ---- the janitor's two, in corridors and washrooms ------------------------------------------
  //
  // WORLD HEIGHTS AGAIN, and both meshes are built AT them (models-src/facility/janitor_build.py), so
  // render.Models.instanced's height scale is 1 and these are measurements rather than settings: a
  // 1.35 m broom and a 0.3 m bucket at the half-metre unit, the bucket's number taken over its BAIL
  // because that is the extent the scale reads
  public static inline var JAN_BROOM_H = 2.67;
  public static inline var JAN_BUCKET_H = 0.84;
  // and their plan extents off the same meshes (0.62 x 0.64 and 0.60 x 0.60), for the contact pool
  // and the wall halo — the placer itself only needs the depth. the bucket is SQUARE IN PLAN and the
  // bail does not widen it: the arc's own radius is the rim's 0.300 MINUS the rod's, so the rod's
  // outer skin lands flush with the widest point of the roll. It went out to 0.322 for one pass —
  // 0.300 plus the rod — which cleared the wall and made the handle the widest thing in the prop
  public static inline var JAN_BROOM_W = 0.62;
  public static inline var JAN_BROOM_D = 0.64;
  public static inline var JAN_BUCKET_W = 0.60;
  public static inline var JAN_BUCKET_D = 0.60;
  // how far the pair stands off the wall face. SMALLER THAN KIT_GAP because neither is jittered and
  // a broom LEANS — its head has to sit under the shaft's own top, which is against the masonry
  public static inline var JAN_GAP = 0.12;
  // one candidate cell in this many, strided down to this many props over the whole compound. a
  // corridor with a broom every ten metres is a broom cupboard, and the pair reads as somebody's
  // work left standing — one or two of each is the whole effect
  public static inline var JAN_STEP = 5;
  public static inline var JAN_MAX = 6;

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
  // the twin-door lab case, and the THIRD aspect lock in the family: its front is one authored
  // composition mapped 0..1, so the width follows the crop and is not chosen. The sheet drew that
  // front 584 x 1022, which is exactly 4/7 — narrower than the four sprites it replaces read
  // (2.25 / 1.64 / 2.53 / 2.86 units over their alpha bboxes), so the HEIGHT carries the same flat
  // 1.2 emphasis the bookcase beside it took rather than the width being squeezed to fit. 3.43 is
  // then the tallest fitting in the compound, under WALL_H 6.0 and dealt on the HIGH list only, so
  // there is never a sill to clear
  public static inline var DECO_CABINET_H = 2.86 * 1.2;
  public static inline var DECO_CABINET_W = DECO_CABINET_H * 0.5714285714;
  public static inline var DECO_CABINET_D = 1.2;
  // the machine casing, and the one fitting that is a CUBE — ONE number per kind for all three axes.
  //
  // it was built to TILE, on the argument that a machine's read is a rhythm rather than a
  // composition, and that is what would have let one image serve two heights with no aspect lock at
  // all. It came back from the game as "both top and front are misaligned", and the report is right:
  // the sheet drew DISCRETE features — a control strip of buttons and dials, bolt columns down the
  // two edges, two grille patches and a cable gland on the lid — so it only reads WHOLE. A tiled face
  // takes an arbitrary sub-rect of it at an arbitrary world phase, which cuts a dial in half and
  // loses the lid's corner bolts. So every face maps 0..1, and THAT is what fixes the size: a 0..1
  // face must match its image's aspect, all three images are square, so the unit is square on every
  // axis. It costs nothing to say so — four of the seven sprites this replaces measure square
  // themselves (61x61, 60x60, 60x60, 48x48), and 2.8 is their own 2.81
  public static inline var DECO_MACHINE_SZ = 2.8;
  // and the LOW list's two, on the sprite bbox alone (12/0 at 1.59 x 2.06, 12/6 at 2.25 x 2.25). The
  // SECOND height is still free off one image, which was the point of the kind — a square image
  // fits a square face at any size, so only the tiling mechanism was wrong, not the plan
  public static inline var DECO_MACHINE_LOW_SZ = 2.2;

  // THE HANGAR'S SECOND MACHINE, and all three of these are the MESH'S OWN measured dims rather than
  // a brief it was built to (models-src/facility/analyser_build.py, 2.060 x 1.680 x 3.3134). The
  // basin's rule and for its reason: render.Models.instanced scales a glb by HEIGHT alone, so a
  // DECO_ANALYSER_H that is not the mesh's height rescales the footprint out of step with the rect
  // render.facility.FacilityDeco.rectOf claims for it — and this one has an overhanging plinth, an
  // overhanging cap and a proud port plate, so its bbox is not its nominal 2.0 x 1.6 body.
  //
  // 3.31 AND NOT THE 4.0 IT WAS DRAWN AS: PLACARD_W's note below fixes DECO_CABINET_H 3.43 as the
  // tallest thing that can share a room cell, because the placard band runs 3.85 to 5.65 and is
  // meant to need no check against any other builder's placements. It is still the tallest thing in
  // the shed after the podium's PODIUM_H 3.07, which is the whole point of the shape
  public static inline var DECO_ANALYSER_W = 2.06;
  public static inline var DECO_ANALYSER_D = 1.68;
  public static inline var DECO_ANALYSER_H = 3.3134;
  // ITS BLINK LAMPS ARE THE PAINTED LENSES OF ITS PORT PLATE, which is what makes these numbers
  // measurements and not choices: the lens row of models-src/facility/analyser-sheet.png's port
  // cell sits at u 0.0898 / 0.2324 / 0.3818 / 0.5273 / 0.6670 / 0.7939 / 0.9131 and v 0.4766 down
  // from that cell's top, each lens 0.082 of the cell wide (tools/pix.py over the built sheet's
  // darkest 8%). The plate maps that cell 0..1 and is DECO_ANALYSER_PLATE of the unit's own width,
  // so every fraction below is the cell's own carried onto the FACE: 0.5 + (u - 0.5) * PLATE.
  //
  // render.facility.FacilityDeco.machLights takes them through DecoLedOpts, because the machine's
  // run and this one differ in exactly these four values and in nothing else
  static inline var DECO_ANALYSER_PLATE = 1.40 / DECO_ANALYSER_W;
  public static final DECO_ANAL_LED_U = [
    0.5 + (0.0898 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.2324 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.3818 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.5273 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.6670 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.7939 - 0.5) * DECO_ANALYSER_PLATE,
    0.5 + (0.9131 - 0.5) * DECO_ANALYSER_PLATE,
  ];
  // the plate stands 0.55 off the floor and is 1.05 tall, so the row is 0.55 + 1.05 * (1 - 0.4766)
  // up the unit — as a fraction of its height, which is what the emitter wants
  public static inline var DECO_ANAL_LED_V = (0.55 + 1.05 * 0.5234) / DECO_ANALYSER_H;
  public static inline var DECO_ANAL_LED_SIZE = 0.082 * DECO_ANALYSER_PLATE;
  // SEVEN LENSES AND THE LAST THREE GREEN, against the machine's five and two: the run is longer,
  // so the amber-to-green split is kept at roughly the same fraction rather than the same count
  public static inline var DECO_ANAL_LED_GREEN_FROM = 4;
  public static inline var DECO_RACK_W = 1.6;
  // DERIVED, and by the same kind of lock as DECO_SHELF_D and DECO_BOOKCASE_W above — only this one
  // is fixed by what the art CONTAINS rather than by its aspect. The front tiles at the unit's own
  // width (see DECO_RACK_TILE) and the image holds THREE chassis, so one chassis is 1.6 / 3 and a
  // height that is not a whole number of those cuts the top one in half at the lid. It stood at 2.9
  // = 5.44 chassis and the half unit up there was reported from the game. 2 x W is 6 whole chassis
  // and v lands on exactly 2.0
  public static inline var DECO_RACK_H = DECO_RACK_W * 2;
  public static inline var DECO_RACK_D = 1.2;
  // and the LOW list's stacked server units, which are that same cabinet ONE tile tall instead of
  // two. Everything about it is the rack's — width, depth, all three textures, the LED band — so it
  // costs no art and no draw call; only the height differs, and by the same whole-chassis rule the
  // line above records: one tile is exactly 3 chassis and v lands on 1.0, so there is no wrap seam
  // at all. The sprite it replaces measures 1.83-2.25 units tall over its alpha bbox
  public static inline var DECO_RACK_LOW_H = DECO_RACK_TILE;
  // WHICH RACK SHIPS, and both do. false emits the four quads render.facility.FacilityDeco.unit has
  // always emitted; true stands an instanced glb there instead — hand-modelled in Blender off the
  // constants above (models-src/facility/rack_build.py), six chassis set back behind their own
  // bezels on a skirted foot under an overhanging lid, 156 tris against the quads' 8.
  //
  // A FLAG AND NOT A DELETION because the two answers disagree on principle: docs/3d-models.md's
  // triage says an axis-aligned slab against a wall gets EMITTED, and a rack is one; what the quads
  // cannot say is that it holds six things. The lights are outside the switch and unchanged — they
  // key off the same chassis count either way, which is why the glb's skirt and lid take no height
  public static inline var DECO_RACK_GLB = true;
  // and the same switch for the storage cabinet, where the argument is only the CALL: a cabinet is
  // the slab the triage describes, and what buys the glb its place is that the quads spend THREE
  // labels on it — front, flank and lid — while the packed sheet spends one. Its own shape claim is
  // the two door leaves standing proud (models-src/facility/cabinet_build.py, 36 tris against 8)
  public static inline var DECO_CABINET_GLB = true;
  // and the lab machine, three labels again and two batches back (one per height, off ONE mesh).
  // Its shape claim is the louvre band set back between its two neighbours, which the art draws and
  // the flat plane contradicted — and the control strip does NOT move, because `machLights` stands
  // five specks 0.03 proud of the front face inside it (models-src/facility/machine_build.py)
  public static inline var DECO_MACHINE_GLB = true;
  // and the bookcase, three labels again. Its shape claim is the one this family most obviously
  // wanted: four boards standing PROUD of the spines, which a flat plane can only paint
  // (models-src/facility/bookcase_build.py)
  public static inline var DECO_BOOKCASE_GLB = true;
  // and the OPEN SHELVING, which is the strongest claim of the lot and was the last to be made: the
  // emitted version is two alpha-cut PANES standing in for end frames with zero-thickness quads
  // between them, i.e. a cut-out drawing of a frame rather than a frame. models-src/facility/
  // store_build.py builds it out of what the art already draws — four uprights, four cross rails
  // and a brace to each end, three perforated plates — at 204 tris, and the daylight through the
  // middle of it is real. It also gives the clutter pass three lids where the quads gave it none
  public static inline var DECO_SHELF_GLB = true;
  // and the washroom basin — everything but its MIRROR, which hangs on the wall and not on the unit.
  // The strongest shape claim in the set: a basin is a HOLE, and the quads laid it on the counter as
  // a flat alpha-cut quad with a second one standing up for the tap
  // (models-src/facility/basin_build.py)
  public static inline var DECO_BASIN_GLB = true;
  // the lounge's two-seater. A LOW fitting in every sense the code uses the word — it is dealt off
  // the zone rather than the floor roll, and at 2.0 it passes under a cable run a 3.43 cabinet would
  // be drawn straight through. The width is the only number here with an argument behind it: 1.5x
  // the height is what a two-seater measures, and 3.0 in a 4-unit cell leaves the 0.5 either side
  // that every fitting's wall slide wants
  public static inline var DECO_SOFA_H = 2.0;
  public static inline var DECO_SOFA_W = DECO_SOFA_H * 1.5;
  public static inline var DECO_SOFA_D = 1.6;
  // and the low table in front of it, at seat height. It is NOT against a wall — the lounge zone
  // stands it one cell into the room — so its depth is free and its width is what fits beside the
  // sofa's own 3.0 without the two reading as one block
  public static inline var DECO_TABLE_LOW_H = 1.0;
  public static inline var DECO_TABLE_LOW_W = 1.8;
  public static inline var DECO_TABLE_LOW_D = 1.2;
  // both ship as glbs ONLY, which is the first time in this family that is true: every flag above
  // switches between an emitted version and a hand-modelled one because the emitted one came first,
  // and these two never had one. There is nothing to A/B, so `unit` emits nothing for them and the
  // flags exist to keep the table below reading the same way as its neighbours
  public static inline var DECO_SOFA_GLB = true;
  public static inline var DECO_TABLE_LOW_GLB = true;

  // the STORE ROOM's three, in world units and built AT these heights
  // (models-src/facility/storerack_build.py), so render.Models.instanced's height scale is 1 and the
  // plans below are the plans that draw. Glbs only, like the lounge pair above and for the same
  // reason: none of the three ever had an emitted version, so `unit` emits nothing for them.
  //
  // THE RACKING IS THE TALLEST FITTING IN THE COMPOUND, over the cabinet's 3.43, and that is what
  // gen.blocks.RoomZones' AISLE zone exists for: at 4.2 it blocks sight as well as movement, so a
  // store with racking on every wall and no bay held back is a room you cannot see across.
  //
  // AND IT IS 3.9 WIDE AND NOT 4.0: a run is one instance per CELL and a cell is CityConfig.CELL
  // 4.0, so a cell-wide rack would abut the next one EXACTLY — two coincident faces, i.e. a z-fight
  // between instances rather than a continuous bay. The 0.1 left over reads as the joint
  public static inline var DECO_PALLET_RACK_W = 3.9;
  public static inline var DECO_PALLET_RACK_D = 1.8;
  public static inline var DECO_PALLET_RACK_H = 4.2;
  // and what stands on the floor in front of it: a wrapped stack of cartons, and a pallet of drums.
  // Both are `floor-low` mounts (Const.FACILITY_DECO), so they may stand under glazing where the
  // racking may not
  public static inline var DECO_PALLET_STACK_W = 1.8;
  public static inline var DECO_PALLET_STACK_D = 1.8;
  public static inline var DECO_PALLET_STACK_H = 1.5;
  public static inline var DECO_DRUM_PALLET_W = 1.8;
  public static inline var DECO_DRUM_PALLET_D = 1.8;
  public static inline var DECO_DRUM_PALLET_H = 1.4;
  // the hangar's power generator, models-src/facility/generator_build.py as MEASURED off the evaluated
  // mesh: the skid's plan and the height to the stack's rain cap. H is what Models.instanced scales
  // by, so it has to BE the mesh's height or the footprint stops matching rectOf
  public static inline var DECO_GENERATOR_W = 3.04;
  public static inline var DECO_GENERATOR_D = 1.58;
  public static inline var DECO_GENERATOR_H = 2.36;
  // the racking's three DECK levels as a fraction of its height, which is models-src/facility/
  // storerack_build.py's own BEAM_Z + DECK_T over RACK_H and must stay it: this is what
  // render.facility.FacilityClutter stands a crate on, and a stale copy floats every one of them.
  // ALL THREE ARE REAL DECKS — the glb used to plank only the bottom pair
  public static final DECO_PALLET_RACK_Y = [ 0.2976, 0.6310, 0.9643 ];
  // and the headroom over each: the gap to the next deck. The TOP level takes 0 — nothing is over
  // it, and a crate standing proud of the frame is what the top beam of a working bay looks like
  public static inline var DECO_PALLET_RACK_BAY = 0.3333;
  // A CRATE ON STORE FURNITURE IS A PALLET LOAD AND NOT A SHELF CARTON. DECO_BOX_W 0.55 is a 27 cm
  // box at the half-metre unit WALL_H fixes, and three of those on a 3.9 x 1.8 rack bay read as a
  // bookcase someone moved into a warehouse. Same emitter, one size band up; the lid's own
  // CLUTTER_SLOT_FILL still caps it, which on a 1.8-deep bay lands at 1.12
  public static inline var DECO_CRATE_BIG_W = 1.3;
  public static inline var DECO_CRATE_BIG_W_VAR = 0.5;
  public static inline var DECO_CRATE_BIG_H = 0.95;
  public static inline var DECO_CRATE_BIG_H_VAR = 0.35;

  // the STORE's floor pack64 (art/textures.json facility/store-clutter), consumed by
  // render.facility.FacilityStore through the same 8x8 emit/UV arithmetic as the hangar floor one
  // storey down. The store is the one INDOOR room floored in concrete, which is also how the
  // renderer finds it: Surf.CONCRETE inside a structure that is not the shed
  public static inline var STORE_CLUTTER_TEX = 'textures/facility/store-clutter.png';
  public static inline var STORE_CLUTTER_COLS = 8;
  public static inline var STORE_CLUTTER_CELLS = STORE_CLUTTER_COLS * STORE_CLUTTER_COLS;
  // smaller than the shed floor's 2.6: a store is a ROOM, the camera is closer to it, and a 2.6
  // carton lid in a 4.0 cell would run under the racking standing on the next cell
  public static inline var STORE_CLUTTER_SZ = 2.0;
  public static inline var STORE_CLUTTER_SZ_VAR = 0.6;
  // and a higher roll than the roof's 12: this is a working room and the litter is the point of it
  public static inline var STORE_CLUTTER_PCT = 22;
  // how far it floats over the floor. the same clearance every flat family in the compound takes
  public static inline var STORE_CLUTTER_Y = 0.02;
  // the basin glb's OWN height, tap included, and the number the batch is sized by: Models.instanced
  // scales a mesh to the height it is given, so passing BASIN_H would squash the counter by the
  // tap's share. BASIN_H stays the counter's height and this is only ever the scale
  public static inline var BASIN_MESH_H = BASIN_H + 1.1;
  // and the ROUND props — three drums and the gas rack — hand-modelled instead of generated. NO DRAW
  // CALL IS AT STAKE, unlike every flag above it: both routes are one instanced batch per livery.
  // What is on trial is 1,200 and 5,710 generated triangles against 44 and 284 authored ones, and a
  // palette that is a CELL OF A SHEET rather than whatever a bake came back as — the generated rack
  // took a baseColor fit, a sat fit and two rounds of reported-from-the-game correction to settle
  public static inline var DECO_DRUM_BLENDER = true;
  // and the LITTER BIN, the same argument one prop over and the widest-reaching of the set: this one
  // batch serves the park, the corridor dead ends and every FIT_BIN fitting, so it is three
  // populations off one mesh. 504 authored triangles against 4,765 generated ones, and the generated
  // bin is the prop docs/3d-render.md's colour-deletion row names by number — a 20.1-chroma
  // bottle-green body shipped at 0.1 — so the palette is the point here as much as the count
  public static inline var BIN_BLENDER = true;
  // and the LOT's standing junk — the cone and the cable reel, 360 and 676 authored triangles
  // against 4,798 and 4,960 generated ones. The TYRE STACK is not switched by this and has no hand
  // model: it is the only glb in the compound that passes its own propstat gate (1 component at
  // 100%), and three touching toroids with real holes is a silhouette a lathe would have to fake
  public static inline var LOT_BLENDER = true;
  // and the PARK RAILING, 564 authored triangles against 5,056 generated ones. The mesh is built at
  // CELL by CELL / FENCE_ASPECT, so FENCE_H below and the CLIMB_ARC fitted against it do not move —
  // which is the whole risk on this one: the height IS the width here, and a segment that is not
  // exactly a cell long gaps or overlaps at every cell boundary in the park
  public static inline var FENCE_BLENDER = true;
  // and the PARK BENCH, 1,660 authored triangles against 3,650 generated ones. Its aspect 1.52 and
  // its 3.557 x 1.70 footprint are both held: PARK_BENCH_H is fitted to the first and BIN_SIDE /
  // BIN_BACK to the second, so the litter bin beside it does not move. The nine slats sit on ONE
  // lumbar curve — the first cut stood the back dead vertical and lost to the bake it replaced
  public static inline var BENCH_BLENDER = true;
  // the WC PAN, 692 authored triangles against 4,068 generated ones — and the one prop in the set
  // whose rebuild fixes a PLACEMENT bug rather than a triangle count. TOILET_D 1.4 is what
  // FacilityDeco.toilets stands the pan off the cubicle wall by; the generated mesh is 0.954 deep at
  // TOILET_H, and Models.instanced scales by HEIGHT alone, so the shipped pan floats 0.22 off the
  // masonry it is bolted to. The hand model is 1.400 deep and lands on the wall
  public static inline var TOILET_BLENDER = true;
  // and the OFFICE CHAIR, 1,072 against 2,930 — the closest call of the eleven, and CHAIR_H's own
  // comment below argues the other side of it. That comment is right about the shaped back and wrong
  // about the five-star base it names first: five arms at 72 degrees is a loop index, not a
  // silhouette a generator has to find, and the bake was a REJECT at 9 components / 61.8% regardless
  public static inline var CHAIR_BLENDER = true;
  // the two ROUND low fittings — the hazard drum and the waste bin — which are instanced glbs and
  // not geometry (render.facility.FacilityDeco.placeRound). ONE height and ONE footprint for both:
  // 1.8 is already what the tunnels give the same drum glb (render.sewer.SewerStyle) and what BIN_H
  // gives the compound's own bin, so the two really are one size, and their diameters are within a
  // few centimetres of each other against a contact field blurred over 0.7. The footprint sizes that
  // pool and nothing else — render.Models.instanced scales a batch by HEIGHT alone
  public static inline var DECO_ROUND_H = 1.8;
  public static inline var DECO_ROUND_D = 1.2;
  // the floor drain's side, world units, and it is a MEASUREMENT and not a choice: the atlas icon it
  // replaces drew on a render.particles.Sprites quad of SIZE 3.0 with its art occupying the middle
  // 32 px of a 64 px cell, i.e. 1.5 units. Kept to the pixel so the swap changes the RESOLUTION and
  // nothing else — 32 texels over 1.5 units is 21 per unit against the floor tile's own 73, which is
  // the blur that was reported; a 256 source over the same 1.5 units is 170.
  //
  // the art fills its image edge to edge (unlike the atlas cell, which centres it in an alpha
  // margin), so mapping the source 0..1 over this square reproduces the icon's on-screen size
  public static inline var DECO_DRAIN_SZ = 1.5;
  // and how far it floats over the floor it is set into. a FLOOR eps and nothing to do with the wall
  // ladder (GRIME/CORNER/HALO) — the neighbour here is one opaque floor quad, so this only has to
  // beat depth precision. the atlas sprite it replaces sat at 0.05, which is five times what that
  // needs and reads as a plate lying ON the floor rather than a grate set INTO it
  public static inline var DECO_DRAIN_EPS = 0.01;
  // the TILING faces' periods, in world units. these are material scales and nothing else — a
  // perforation pitch, a wood grain, a rack's unit height — so they are chosen against the thing
  // they draw and never against the unit's own size the way the first build's were
  public static inline var DECO_SHELF_TILE = 0.55;
  public static inline var DECO_BOOKCASE_TILE = 1.4;
  // the cabinet's side and top are plain painted sheet with nothing in them to count, so the period
  // is set to the unit's own DEPTH: an end face then shows exactly one repeat and no wrap line is
  // ever drawn across it — the same protection FacilityDeco.localCap buys the rack's lid, bought
  // here with a number instead of a mapping
  public static inline var DECO_CABINET_TILE = DECO_CABINET_D;
  // the machine has NO period at all — every one of its faces maps 0..1, which is what its own size
  // block above records. A tiling entry here would be the bug that was reported
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

  // how big a TABLE decoration's sprite draws, as a fraction of the full billboard.
  //
  // A DELIBERATE REVERSAL, ASKED FOR IN GAME, and the number it reverses is worth keeping because
  // it was a measurement. Those 43 icons keep their sprite — flasks, retort stands and microscopes
  // are exactly what a mesh generator is for and exactly what an emitted box cannot state — and they
  // first shipped at FULL size, which is Sprites.SIZE 3.0 over the icon's own alpha bbox: 1.03 to
  // 2.25 world units on a BENCH_H 2.0 worktop, a 1.08 m microscope on a 1 m bench reaching two
  // thirds of the 3 m wall. That was cut to 0.54 — 1.5x true size, the emphasis every icon in this
  // game carries — and reported back as too small.
  //
  // so this is 1.5x again, i.e. 2.25x true size, and it costs what the first cut bought:
  //   the tallest icon goes 1.215 -> 1.82 units, a 0.91 m microscope on a 1 m bench — 80% of the
  //     way back to the 1.08 m that was the reported bug, which is the trade being made knowingly
  //   texel density goes 39.5 -> 26.3 per world unit against the floor tile's 73. The floor drain's
  //     header records 21.3 as the blur that was reported, so this lands between the two
  // one thing IMPROVES: 64 px over a 2.43-unit quad is ~54 device px at the resting camera, 1.19
  // texels per pixel, so these stop leaning on mip 1 — which is where render.particles.Sprites
  // .unpremul measured the black outline coming from
  public static inline var DECO_TABLE_SCALE = 0.81;

  // and how much of its own chroma one keeps. the art is flat-design vector work — measured over the
  // 43 cells, saturation 0.06 to 0.54 and value 0.56 to 0.92 — which is a cheerful icon sheet in a
  // dark laboratory, and it was reported as exactly that.
  //
  // A SHADER UNIFORM AND NOT A SECOND CACHED CROP. render.particles.Sprites already opens the texel
  // to undo its premultiply, so the desaturation is two more instructions there against a second
  // entry in every sprite cache — see Sprites.unpremul. Half is the point of the number: a blue
  // flask still reads blue, it just stops being the loudest thing in the room.
  //
  // it applies to EVERY bench frame, hi-res pack cell included — that gate was tried and reverted,
  // see FacilityDeco.spriteSat — and the flat clutter lying on the same worktops carries the same 0.5
  // baked into its sheet, because a merged lambert has no uniform to hand it to (art/textures.json
  // facility/worktop-clutter's `sat`, mixed in linear light so the two mean the same thing)
  public static inline var DECO_TABLE_SAT = 0.5;

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
  // how far a plate's LID stands over its rail's centre line, as a fraction of the unit's height.
  // The glb's own PLATE_UP (RAIL_T / 2 + PLATE - 0.02) over its 2.6, and it is what the clutter pass
  // stands things on — DECO_SHELF_Y alone is the RAIL and would sink a box a plate's thickness in.
  // 0.0398 while the plate was 0.06 thick; it was reported as too thick and halved, and this number
  // is DERIVED from that one, so a stale copy of it floats every box on the unit
  public static inline var DECO_SHELF_PLATE_Y = 0.0283;
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

  // AN OPEN BOX, which is a closed one with its lid off and its contents showing — see
  // render.facility.FacilityDeco.openBox. Three numbers and each is about being READ as a hole.
  //
  // _WALL is the board's own thickness, in world units, and it is the rim quads' whole width: at
  // this camera the rim is most of what separates an open carton from a bottomless one, and a
  // 5 mm board at the half-metre unit is 0.01. It is drawn at 0.04 instead — four times life — for
  // the reason every deliberate over-thickness in this file carries: one quad 0.01 across is under
  // a pixel at the pitch this camera looks down from and disappears into its own neighbours.
  //
  // _FILL is how far up the box the contents stand, as a fraction of its height. Full to the rim
  // and the interior walls have no height to be seen against, so it reads as a closed lid in a
  // different material; empty and the box is a well with nothing in it.
  //
  // _AO is what the interior is multiplied by against the outside. THE DARKENING IS THE HOLE: the
  // indoor fill is normal-blind (IndoorMask), so four inward-facing walls and a horizontal cap
  // render at the same value as the outward faces beside them and the box reads as a painted
  // square on a slab. Same finding as DECO_BOX_AO_LOW above and the same fix
  // THE BOARD IS 0.02 and was 0.04, reported as too thick: at 0.04 the rim read as a picture frame
  // round the fill rather than as the cut edge of a carton
  public static inline var DECO_OPEN_WALL = 0.02;
  public static inline var DECO_OPEN_FILL = 0.62;
  public static inline var DECO_OPEN_AO = 0.55;

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
  // and a THIRD, a CCTV camera's recording light (render.corp.CorpSecurity.cams): its own mode on
  // the same mesh, 8 on the blue channel, so it blinks for no draw call
  public static inline var DECO_LED_RED = 0xff3a2a;
  // the HDR multiplier that carries a light over BLOOM_THRESHOLD, the same job GLOW does for the
  // ceiling panels
  public static inline var DECO_LED_GLOW = 2.6;

  // and the MACHINE's control strip, which rides the very same mesh, material and clock as the rack
  // lights above — so it costs no draw call and no program — but runs a DIFFERENT pattern off them.
  // A rack's ports are independent traffic and a square wave is exactly right for that; a machine
  // panel is a SEQUENCER, so this one is a single lit dot running the row with a decaying tail. The
  // two are told apart in the patched shader by the vertex channel that carries the hue (see
  // FacilityDeco.blink): 0..1 is a rack, 2..3 a machine.
  //
  // THE SLOTS ARE READ OFF THE ART, like the rack's band was, and here they can be read exactly:
  // the machine front maps 0..1 over its face, so one measurement serves every unit at every size.
  // Per-column means over the built 500 in the button band (py 438-474, background 72.2) give five
  // dark runs 19-24 px wide at these centres — the three-button bank on the left and the two-button
  // bank on the right. The 5-9 px runs between them at u 0.43-0.66 are the two DIALS and are
  // deliberately skipped: a dial is not a lamp
  public static final DECO_MACH_LED_U = [ 0.132, 0.218, 0.304, 0.767, 0.853 ];
  // WHICH PATTERN A LIGHT BURNS, as the base of the hue channel `blink` reads the mode off. FOUR of
  // them share one mesh, one material and one clock, because a second mesh is a second draw call and
  // the mode therefore has to travel per VERTEX with only three channels to travel in: 0..1 is a
  // RACK's independent square wave, 2..3 a MACHINE's one-way chase, 4..5 a SCREEN's wobble, 6..7 an
  // ANALYSER's bouncing scan. Named here rather than written as literals at the four emitters,
  // which is how the screen's 4.0 sat in render.facility.FacilityWork while this band was added
  public static inline var DECO_LED_CHASE = 2.0;
  public static inline var DECO_LED_SCREEN = 4.0;
  public static inline var DECO_LED_SCAN = 6.0;
  // and the band's own centre, v from the foot of the face (py 438-474 of 500)
  public static inline var DECO_MACH_LED_V = 0.088;
  // one light's quad edge as a fraction of the face WIDTH, not a world size: this kind comes in two
  // sizes off one image, so a world constant would cover its slot on the 2.8 unit and overflow it on
  // the 2.2. The slots themselves are 0.038-0.048 of the face and the quad is a little wider, because
  // the alpha gradient's soft round core is smaller than the quad it is drawn on
  public static inline var DECO_MACH_LED_SIZE = 0.05;
  // how fast the dot runs the row, as a BASE_MS multiplier — faster than the rack's blink, because a
  // sequencer that steps slower than the traffic beside it reads as the broken one
  public static inline var DECO_MACH_LED_RATE = 0.55;
  // and the tail's falloff exponent: on = (1 - phase distance)^TAIL, so 6 leaves the slot behind the
  // dot at 0.26 and the one before that at 0.12 — a comet over two slots of the five
  public static inline var DECO_MACH_LED_TAIL = 6.0;
  // which slot the hue changes at: the left bank runs amber and the right bank green, so the run
  // crosses two banks the way a real panel's does rather than being one undifferentiated row
  public static inline var DECO_MACH_LED_GREEN_FROM = 3;
  // AND THE FOURTH PATTERN, the analyser's SCAN, which exists because the analyser and the machine
  // stand a few units apart in the same shed and ran the SAME sequencer off the same clock — reported
  // from the game as the two objects blinking alike. Here the lit head BOUNCES along the lens row
  // instead of running it one way, which is what a sample being swept reads as, and 0.20 against the
  // machine's 0.55 is slow enough that the two never beat together. The tail is the machine's
  // DECO_MACH_LED_TAIL: one exponent serves both shapes and a second uniform would buy nothing
  public static inline var DECO_ANAL_LED_RATE = 0.20;

  // and the THIRD pattern on that one mesh, material and clock: a lit SCREEN. Told apart the same way
  // the machine is — the vertex channel carrying the hue is 0..1 for a rack, 2..3 for a machine and
  // 4..5 for a screen — because a third mesh is a third draw call and there are only three channels.
  //
  // NEITHER OF THE OTHER TWO PATTERNS FITS. A square wave is a port blinking and a chase is a
  // sequencer; a monitor showing something does neither. What it does is wobble slightly and never
  // repeat, so this is two sines at rates with no common period, summed 60/40 — the cheapest thing
  // that has no visible loop, three instructions, and no noise texture. Both rates are BASE_MS
  // multipliers and both are uniforms, so retuning them compiles nothing
  public static inline var DECO_SCREEN_RATE = 0.21;
  public static inline var DECO_SCREEN_RATE2 = 0.0873;
  // the depth of the wobble. SHALLOW ON PURPOSE: at 0.75, the depth a rack port takes, a screen reads
  // as a fault light. 0.12 is a panel refreshing
  public static inline var DECO_SCREEN_DEPTH = 0.12;

  // ---- doors -----------------------------------------------------------------------------------

  // the opening's height, world units, out of a WALL_H of 6.0. the art is SQUARE and holds the whole
  // pair, so this also fixes the width: 4.0 tall over a 4-unit cell is 1:1 and nothing is stretched.
  // at the game's scale (WALL_H 6.0 is one storey) that is a 2 m x 2 m opening, which is what a
  // corridor pair of swing doors actually measures
  public static inline var DOOR_H = 4.0;
  // leaf thickness. it exists only so the top and outer edges have something to draw at this
  // camera's 51 degrees — a bare quad would vanish edge-on the moment a door swung
  public static inline var DOOR_T = 0.16;
  // HOW FAR PAST ITS OWN WIDTH A SLIDING LEAF TRAVELS, world units.
  //
  // a lift pair runs one LEAF_W along the wall line and vanishes into the masonry beside the
  // opening — and at exactly LEAF_W its HINGE EDGE lands in the cell boundary plane, which is the
  // plane the doorway's own reveal is emitted in. Both run WALL_BASE to DOOR_H, so the open leaf
  // put a 0.16 x 4.2 coplanar strip against the reveal at each jamb: reported from the game as
  // z-fighting whenever the lift is open, and the probe came back holding the REVEAL (uv v
  // -0.033..0.667 against WALL_TILE 6.0 is y -0.2..4.0 exactly, du 0.2 is the corp `wallIn` 1.2).
  //
  // Sending the leaf a little FURTHER into the pocket is what separates the two planes, and it
  // costs nothing to see: the leaf is 0.16 thick inside masonry at least 1.0 thick, so the extra
  // travel is buried either way and the opening was already fully clear at LEAF_W
  public static inline var DOOR_SLIDE_CLEAR = 0.2;
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
  // the SCALE is of the quad, and the 3D vent is the 256 px facility/vent drawn edge to edge
  // (render.particles.Sprites.atlasFor), so 38/64 — the fraction of its cell the old 64 px icon
  // filled — keeps the grille 1.78 units wide. at the game's scale (WALL_H 6.0 is one 3 m storey, so
  // a unit is half a metre) that is a 0.9 m cover spanning 0.55-1.45 m up the wall — a duct low
  // enough to slither into, which is what the object does
  public static inline var MOUNT_Y = 2.0;
  public static inline var MOUNT_SCALE = 38 / 64;
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

  // ---- the corridor wall fittings (render.facility.FacilityPoint) --------------------------------

  // the FIRE POINT and the ELECTRICAL PANEL: the two things a keep-clear zone on the floor is
  // actually FOR, and the reason ZONE_D's block can say a zone belongs to fire equipment and a panel
  // rather than to a doorway. a zone with nothing standing over it is a stain.
  //
  // BOTH ARE WALL QUADS AND NEITHER IS A PROP, which the silhouette-vs-surface guard answers
  // outright: a distribution panel is a flat door with a label and has no silhouette at all, and a
  // fire point reads from this camera as its red backboard — at the measured 65.6 degree gameplay
  // pitch an extinguisher on a bracket is a few pixels of edge. So they are two cells of ONE atlas
  // on ONE mesh, which is FacilityExit's shape verbatim and costs the family a single draw call
  public static inline var POINT_TEX = 'textures/facility/wall-points.png';
  // the two cells of that atlas, as the u of each one's LEFT edge; each is half the image wide. the
  // source draws them SIDE BY SIDE where the exit signs are stacked, because both fittings are
  // PORTRAIT and the exit signs are landscape — the art decides, here as there
  public static inline var POINT_U_FIRE = 0.0;
  public static inline var POINT_U_PANEL = 0.5;
  // the quad, world units. THE ASPECT IS THE ART'S AND ONLY THE SCALE IS FREE: each atlas cell is
  // 512x1024 and a 0..1-mapped face must match its image or the fitting is stretched — the same lock
  // DECO_SHELF_D and DECO_BOOKCASE_W carry, and it is why the number below is the ONLY lever this
  // family has on how big it reads.
  //
  // it shipped at 1.6 (a 0.8 m by 1.6 m backboard at the half-metre unit WALL_H 6.0 fixes, which is
  // about a real fire point's) and came back from the game as "i see no panel, no fire point". They
  // were drawing: the miss is that a wall fitting is pitched AWAY at the 65.6 degree gameplay camera
  // while its own floor hatch lies flat and facing it, so the mark reads at 4x3 units and the thing
  // it belongs to is a ~50x55 px patch at 0.11x its wall. 2.0 is +56% area for +0 art, and it is the
  // most the height ceiling below allows
  public static inline var POINT_W = 2.0;
  public static inline var POINT_H = POINT_W * 2;
  // and the quad's CENTRE, so it spans 0.1 to 4.1 up a 6-unit wall. LOW, unlike everything else
  // mounted in this compound — BOARD_Y is 3.0 and EXIT_Y is 4.75 — because a fire point's whole
  // point is that the extinguisher is within reach, and a panel is opened by hand. Standing it
  // nearly ON the floor is also what glues it to its own hatch, which is the pair the whole family
  // exists to make.
  //
  // THE TOP IS WHAT CAPS POINT_W, and by 0.15: a terminal exit sign's bottom edge is
  // EXIT_Y - EXIT_H / 2 = 4.25 and the two hang on the SAME corridor walls at the same MOUNT_PROUD,
  // so anything over 2.05 here puts a fire point through the sign above it.
  //
  // it CLEARS BENCH_H 2.0 nowhere and does not need to — `FacilityPoint.places` takes the casework's
  // own run list out of the candidates before it places anything, so a fitting and a cabinet never
  // share a face to begin with
  public static inline var POINT_Y = 2.1;
  // how many cells apart two fittings stand, measured between their CELLS and not along one wall —
  // so a corridor cannot take one on each hand of the same two-wide stretch. the only density knob
  // here, the way EXIT_APPROACH is the signage's, and it is applied greedily over candidates sorted
  // by distance to their own structure's entrance
  public static inline var POINT_SPACING = 8;

  // ---- the room wall placards (render.facility.FacilityPlacard) -----------------------------------

  // the safety signage on a lab ROOM's walls, and the one family in the compound that is not hung in
  // the circulation. measured on a pinned pose, a room wall is 10.25% of the frame and carried the
  // damp band and nothing else — EXIT_TEX is Surf.LINO-gated, POINT_TEX is Surf.LINO-gated and
  // BOARD_TEX is one per front entrance, so every fitting above this line is a corridor fitting.
  //
  // A TEXTURE AND NOT A PROP, the same reading of the silhouette-vs-surface guard BOARD_TEX takes: a
  // sign plate's outline is a rectangle, and everything that says "hazard placard" rather than "grey
  // square" is a pictogram on its face
  // TWO SHEETS AND NOT ONE, which costs the second mesh a draw call and is what eight pictograms are
  // worth: the signs are picked off what stands under them (see FacilityPlacard.classOf) and four
  // cells cannot name a bench, a server rack, a drum and a shelf of boxes between them. A 2x2 is also
  // the largest cell a 1k drop can hold at the 256 the built sheet keeps, so the eighth sign is a
  // second sheet or it is a smaller plate. Sheet B carries the rarer half and a compound with no
  // racks and no drums simply emits an empty buffer, which FacilityGeom.add drops
  public static inline var PLACARD_TEX = 'textures/facility/placards.png';
  public static inline var PLACARD_TEX2 = 'textures/facility/placards2.png';
  // how many cells ONE sheet holds. each is a 2x2 and both of its divisions landed dead on 512, so a
  // cell is an exact quarter and its u/v are DERIVED from the index in FacilityPlacard.pane rather
  // than named one by one the way POINT_U and EXIT_V are — a regular grid does not need eight
  // constants, and eight would be eight chances to name a corner twice.
  //
  // a sign index runs 0..7 across BOTH sheets, so the sheet is index / PLACARD_CELLS and the cell in
  // it is index % PLACARD_CELLS
  public static inline var PLACARD_CELLS = 4;
  // the quad, world units. THE ASPECT IS THE ART'S and only the scale is free, the lock POINT_W and
  // DECO_BOOKCASE_W both carry — but here the cells are SQUARE, so the height simply follows. at the
  // half-metre unit WALL_H 6.0 fixes this is a 0.9 m sign, which is large for a real placard and is
  // the scale POINT_W had to be pushed to before the fittings were seen at all
  public static inline var PLACARD_W = 1.8;
  public static inline var PLACARD_H = PLACARD_W;
  // and the quad's CENTRE, so it spans 3.85 to 5.65 up a 6-unit wall. HIGH, and that height is what
  // buys the family its whole collision story: it clears DECO_CABINET_H 3.43, the tallest thing that
  // can share a room cell, by 0.42 — so unlike the fire points this needs no check against any other
  // builder's placements, and unlike the aisle it needs no claimed-cell grid. it is 0.35 under
  // WALL_H 6.0 at the top.
  //
  // it never meets EXIT_Y 4.75 despite reading as the same band: those are Surf.LINO and these are
  // Surf.TILE, so the two families cannot share a wall face.
  //
  // AND IT LEAVES 0.35 OF WALL ABOVE IT, which is the number a high-level SERVICE RUN has to be
  // written against: anything hung over a room wall from here on either shares this band, gates off
  // a different surface the way the corridor families do, or comes in under 0.35 tall. Not pulled
  // down in advance to make room for one — this height is measured against the fittings that exist
  public static inline var PLACARD_Y = 4.75;
  // the shortest run of unbroken masonry that takes a sign, in cells. a run is ended by a DOORWAY —
  // a door cell is not isSolidWall — so this is what stops a 2-cell stub between two openings from
  // carrying one, and it is the whole density rule: ONE sign per run, on whichever of the run's cells
  // has something worth naming under it and falling back to the middle when none has
  public static inline var PLACARD_RUN_MIN = 3;

  // ---- the electrical service: sockets, fittings, floor units and cable (FacilityCable) ----------

  // ONE PACK64 FOR FOUR FAMILIES, and the only sheet in the tree drawn in two projections: its first
  // four rows are FRONT ELEVATION and hang on walls, its last four are TOP-DOWN and lie flat on
  // floors. That is what makes the whole electrical service one draw call — see
  // art/textures.json facility/electrical-pack, which also carries why the wall half alone is capped
  public static inline var ELEC_TEX = 'textures/facility/electrical-pack.png';
  public static inline var ELEC_COLS = 8;
  // the four sixteens, as the first cell of each band
  public static inline var ELEC_SOCKET = 0;
  public static inline var ELEC_FITTING = 16;
  public static inline var ELEC_UNIT = 32;
  public static inline var ELEC_SCATTER = 48;
  public static inline var ELEC_BAND = 16;
  // the cut-out threshold, the worktop clutter's own — the same kind of alpha-boxed pack art
  public static inline var ELEC_CUT = DECO_CUT;
  // the three socket cells that DRAW THEIR OWN CABLE, never dealt. sheet cell 6 is a plug with a stub
  // hanging down, 7 a pair of plugs with a tangle, 15 a box with armoured cable entering its side.
  //
  // BOTH WAYS ROUND ARE WRONG, which is why this is a skip and not a pairing. Reported from one room:
  // the socket that HAD one of our leads had it arrive on the plate's left while the drawn stub left
  // downward, so the plate grew two cables going two ways; the socket that had none showed a plug
  // whose stub simply stopped in mid-air. Matching an emitted run to each cell's own drawn exit would
  // need a per-cell table of a point AND a direction, measured off the art, for three cells out of
  // sixteen — and the run would still have to be the only cable on a plate that draws two. A bare
  // faceplate says nothing our own geometry then has to agree with
  public static var SOCK_SKIP:Array<Int> = [ 6, 7, 15 ];
  // and the corridor-fitting cells a lead may actually LEAVE, which is an ALLOWLIST and was a
  // blocklist for one pass. The blocklist named the two cells that were obviously wrong — cell 20 is a
  // red emergency-stop mushroom button, 26 a bank of light switches — and shipped the other fourteen
  // as sources, so the game went on reporting leads growing out of a sealed breaker board, an
  // electricity meter and a battery box. The question is not "is this one absurd" but "does this one
  // draw somewhere a cable can come out of", and five of the sixteen do: 16 a junction box with four
  // cable glands, 23 a cable tray with cables already lying in it, 27 a bracket holding a coiled
  // reel, 29 a bundle leaving the wall through a grommet plate, 31 a socket outlet box with an
  // isolator lever. Everything else is a sealed enclosure and stays unattached —
  // the compound supplies the emptiness, the same argument `links` runs on.
  //
  // A ROOM SOCKET NEEDS NO SUCH LIST: every cell of its own band is an outlet by construction, less
  // the three SOCK_SKIP deals out for drawing their own cable
  // CELL 22 CAME BACK OFF THE LIST. It is a run of steel conduit held by two saddle clips, i.e.
  // CONTAINMENT and not a termination: a cable inside conduit does not come out of the middle of it,
  // and reported from the game the lead read as plugged into a pipe. A tray (23) keeps its place —
  // a cable lying loose in a tray can leave it anywhere along its length, which is what a tray is
  public static var FIT_FEED:Array<Int> = [ 16, 23, 27, 29, 31 ];
  // and the two STANDING cells that may not be the end of a lead either, for a third reason again:
  // sheet cell 35 is a distribution board up on four long spindly legs and 43 an extension block on a
  // splayed stand. UNIT_FOOT lands a run a tenth of the way up the quad, which on those two is the
  // OPEN AIR BETWEEN THE LEGS — reported from the game as a cable ending in nothing under the object.
  //
  // A PER-CELL FOOT HEIGHT IS THE THING NOT WORTH BUILDING, which is the judgement here. It would be
  // sixteen numbers measured off the art to spare two cells, and the band has fourteen others that
  // stand on a base, feet or castors and take the lead at a tenth with nothing to say about it. So
  // these two come out of the deal entirely — a standing unit exists only because a run stood it, so
  // "cannot be wired" and "is never dealt" are the same sentence here. SOCK_SKIP's own shape
  public static var UNIT_SKIP:Array<Int> = [ 35, 43 ];
  // and the cell that REFILLED one of the three, a bare plug head with a gland collar at its foot and
  // no cable on it. It is what a run arriving at a socket ends in, drawn over the ribbon's cut end.
  //
  // IT COST NOTHING BUT THE IMAGE: `SOCK_SKIP` left cells 6, 7 and 15 drawn by nothing, and
  // tools/pastecell.py drops a freshly generated object into one cell of an already-packed sheet, so
  // the plug rides the same texture, the same mesh and the same draw call as everything else here.
  // NO CABLE ON IT, which is the whole lesson those three skipped cells taught: art that draws its own
  // lead cannot be placed by a family that emits one
  public static inline var ELEC_PLUG = 6;
  // the plug quad, world units — square, and about half the socket plate it plugs into. only a
  // SOCKET gets one: a lead leaving a corridor junction box leaves through a GLAND, which is what
  // those cells already draw
  public static inline var PLUG_W = 0.75;
  // WHERE ON ITS PLATE each socket cell's outlet is, x then y as fractions of the cell from its top
  // left, read off the art at 2x. A plug on the plate's CENTRE landed between the two outlets of a
  // double socket, or over the switch beside a single one — reported from the lab as a plug "not
  // aligned to socket". A double takes its left outlet; the three SOCK_SKIP cells are never dealt
  public static var SOCK_OUTLET:Array<Array<Float>> = [
    [0.36, 0.51], [0.5, 0.5], [0.31, 0.56], [0.5, 0.52], [0.5, 0.5], [0.5, 0.48], [0.5, 0.5], [0.5, 0.5],
    [0.5, 0.52], [0.36, 0.52], [0.49, 0.53], [0.5, 0.48], [0.5, 0.52], [0.38, 0.52], [0.34, 0.51],
    [0.5, 0.5],
  ];
  // how far a floor decal floats over the surface it lies on. THE STACK IS THREE DEEP AND THE ORDER
  // IS THE WHOLE OF IT: render.RenderConfig.PAINT_Y 0.03 is the aisle marking, CABLE_FLOOR_Y 0.05 the
  // lead lying over it, and this the loose kit lying over that. The first cut put the cable at 0.02
  // and this at exactly 0.03, so a lead ran UNDER the yellow lines and the scatter z-fought them —
  // reported from the game, and a decal family that lands on painted floor has to be written against
  // the paint's own height rather than against y = 0
  public static inline var ELEC_FLOOR_Y = 0.07;

  // the socket quad, world units — SQUARE, because the art is an alpha cut-out in a square cell and
  // its own silhouette is the shape. 1.0 is half a metre at the half-metre unit WALL_H 6.0 fixes,
  // which is a surface-mounted industrial socket box with its isolator rather than a faceplate.
  //
  // AND IT IS SCALE AND NOT VALUE THAT DECIDES WHETHER A SMALL WALL FITTING IS SEEN, which POINT_W
  // already records ("the scale POINT_W had to be pushed to before the fittings were seen at all")
  // and this family re-learned from the bottom. Measured in frame off the rack beside it: one world
  // unit is about 4.2 device px from the resting camera, and the art fills 0.7 of its own cell — so
  // 1.0 drew a SEVEN-PIXEL smudge with a cable arriving at it. 1.4 draws about 1 unit of art, still
  // comfortably under the 1.8-wide panel this replaced
  public static inline var SOCK_W = 1.4;
  // and its CENTRE, so the quad spans 0.15 to 1.55 and the art inside it about 0.36 to 1.34 — a
  // socket a foot or two off the floor, where one is. IT CANNOT GO UNDER SOCK_W / 2: the quad is
  // square and a centre lower than its own half-width puts its bottom edge through the floor.
  //
  // THE BAND NEEDS NO COLLISION TEST for the reason the placards' 4.75 needs none from the other end:
  // nothing else in the compound is hung on a room wall under BENCH_H 2.0, and a bench stands on its
  // own CELL a clear unit off the slab face rather than against it. GRIME_H's damp band is on the
  // wall and this is MOUNT_PROUD of the wall, so it draws over it
  public static inline var SOCK_Y = 0.85;
  // where a run LEAVES a corridor FITTING, as a fraction of FIT_W out from its centre. it is measured
  // against the ART and not against the quad, which is the whole point of the constant: the pack's
  // cells fill 0.49 to 0.87 of their own square, so a run inset by the quad's half-width less its own
  // thickness — the obvious number, and the first one tried — ends in the transparent margin BESIDE
  // the box with a visible gap. A quarter of the quad is inside the drawn art of every cell.
  //
  // A SOCKET NO LONGER TAKES IT (render.facility.FacilityCable.anchor): a fitting has only its own art
  // to hide the lead's cut end with, while a socket has a PLUG drawn over its plate centre, and the
  // slide put the end 0.35 out — against the plug's own half-width of PLUG_W / 2 = 0.375, i.e. at its
  // rim, which reads as a cable stopping beside its plug rather than going into it
  public static inline var SOCK_LEAD = 0.25;
  // how far apart two sockets must be, in cells. the panel family this replaced settled here for a
  // measured reason that still holds: a lab room is 6 to 10 cells across, so POINT_SPACING 8 would
  // allow one per room, 3 hung 52 of them and read as wallpaper, and 5 left the compound one link
  public static inline var SOCK_SPACING = 4;

  // the corridor wall fitting — a junction box, a breaker board, an isolator. bigger than a socket
  // because it is a thing on a wall rather than a plate in it, 65 cm at the same unit
  public static inline var FIT_W = 1.3;
  // and its centre, so it spans 1.95 to 3.25.
  //
  // THREE FAMILIES ALREADY OWN THE CORRIDOR WALL and this one is fitted between them rather than
  // against them: POINT_Y's fittings span 0.1 to 4.1 but only on the cells FacilityPoint.places
  // takes, which this excludes outright; the casework's own run list is excluded the same way; and
  // EXIT_Y 4.75 puts the signage band's floor at 4.25, a unit clear of the top of this one
  public static inline var FIT_Y = 2.6;
  // and how far apart two of them go, in cells. between POINT_SPACING 8 and the socket's 4: a
  // corridor is long, but a fitting every 8 cells on top of a fire point every 8 is a bare wall
  public static inline var FIT_SPACING = 6;

  // the floor unit a floor cable leads to — a cable drum, a welding set, a distribution board. it
  // STANDS, which is the whole of cells 32-47 of the pack: drawn overhead and laid flat they read as
  // equipment PAINTED ON THE FLOOR, so those two rows were re-drawn in elevation and this is a
  // frontal quad leaned back by render.particles.Sprites.TILT, like every actor and bench decoration.
  //
  // SQUARE, because the pack's cells are square and nothing is ever stretched. 2.6 is 1.3 m at the
  // half-metre unit WALL_H 6.0 fixes, just under DECO_MACHINE_SZ 2.8 — the biggest thing that should
  // be parked against a laboratory wall is smaller than the machinery bolted to it
  public static inline var UNIT_SZ = 2.6;
  // how far the quad is sunk into the floor, as a fraction of UNIT_SZ, so the ART's feet land on it
  // rather than the quad's own bottom edge. tools/pack16.py CENTRES each cell's content (the right
  // call for the other two bands on this sheet, and see art/textures.json facility/electrical-pack
  // for why one --valign has to serve all three), which leaves a standing unit's feet a margin up
  // inside its own cell — measured over the sheet's own vertical fills, 0.065 to 0.18, mean 0.12. In
  // frame the untuned version put a lead's end visibly under a unit that was floating over it
  public static inline var UNIT_SINK = 0.12;
  // how far a standing unit leans BACK, radians, and it is the one sprite family here that stands
  // UPRIGHT. render.particles.Sprites.TILT 0.6 is what every actor and bench decoration leans by, and
  // a unit is the only one of them parked ON a wall rather than out in the room: at 2.6 tall the lean
  // carries its top sin(0.6) * 2.6 = 1.47 backwards, against the UNIT_OFF 0.9 it has to give, so the
  // top third of the art is inside the masonry and CUT OFF — reported from the game. Vertical is the
  // trade, and what it costs is the coplanarity the tilt buys: a unit no longer leans with the
  // sprites beside it. It is the cheaper of the two, because nothing is cut
  public static inline var UNIT_TILT = 0.0;
  // and how far up the unit a lead ARRIVES, as a fraction of UNIT_SZ. not the floor: half this band
  // stands on LEGS, castors or a pallet, so a cable ending at the base ends under the object rather
  // than at it
  public static inline var UNIT_FOOT = 0.10;
  // and how far BEHIND it, as a fraction of UNIT_SZ — toward the wall, which is the body depth a flat
  // sprite does not have and where a lead plugs in anyway. THE QUAD IS ITS OWN PLANE now that
  // UNIT_TILT is 0: a lead ending at the base point ended exactly coplanar with the art and drew over
  // it, reported as the cable being in front of the object. 0.15 of 2.6 is 0.39 back, against the
  // UNIT_OFF 0.9 the unit stands clear of, so the end is behind the sprite and still well off the wall
  public static inline var UNIT_BACK = 0.15;
  // what fraction of its own quad the ART actually fills, across and up. MEASURED off the built sheet
  // over all sixteen standing cells (opaque bbox, alpha > pack16's own CUT 24): width mean 0.637
  // median 0.637, height mean 0.767 median 0.754.
  //
  // IT IS THE SHADOW THAT NEEDS IT AND NOTHING ELSE. Both contacts a standing unit lays — the wall
  // halo behind it and the floor field under it — take an EXTENT, and handing them UNIT_SZ hands them
  // the QUAD, which is a third wider and a quarter taller than anything drawn in it. Reported from the
  // game as a wall shadow far too large for the thing casting it, and it was: 2.6 grown by
  // FacilityDetail.grow is 4.33 of gradient for 1.66 of art. A sprite's quad is not its silhouette,
  // which is the same fact CABLE_LID_H is a third rather than a lid for
  public static inline var UNIT_FILL_W = 0.64;
  public static inline var UNIT_FILL_H = 0.77;
  // and how far up the wall the halo behind one reaches, against the art's height: half of it. The
  // unit stands UNIT_OFF 0.9 clear of the face, so a halo the art's full 2.0 tall stood over the
  // top of a squat fan heater from the camera's pitch and read as a slab of shade on the wall
  // ("make the wall contact shadow shorter")
  public static inline var UNIT_HALO_H = 0.5;
  // how far its base stands off the wall's slab FACE, world units. it is parked against the wall and
  // not stood in the middle of its cell: the cell is 4.0 and its own face is a unit in from the cell
  // edge, so this leaves the lane down the middle of the room clear
  public static inline var UNIT_OFF = 0.9;
  // how far ALONG its wall from its mount one stands, in cells, and how far apart two of them must
  // be. ALONG and never out: a lead run straight out into the room crosses the aisle markings and, in
  // a corridor, the corridor itself. the reach is a RANGE because the run needs free floor and
  // unbroken masonry the whole way, and the nearest clear distance is taken
  public static inline var UNIT_REACH_MIN = 2;
  public static inline var UNIT_REACH_MAX = 4;
  public static inline var UNIT_SPACING = 5;
  // and the loose electrical scatter lying about on the floors — an offcut coil, a taped-down run, a
  // dropped plug. one cell in SCAT_ODDS carries one
  public static inline var SCAT_SZ = 1.6;
  public static inline var SCAT_SZ_VAR = 0.5;
  public static inline var SCAT_ODDS = 11;

  // the cable itself. u maps 0..1 ACROSS the ribbon (the art is one cable edge to edge, and its
  // cross-section shading is what makes a flat strip read as round) and v tiles along the run
  public static inline var CABLE_TEX = 'textures/facility/cable.png';
  // the ribbon's width, world units. 0.18 went to 0.126 — reported from the game as too thick, and
  // 30% off it is a 6 cm cable at the half-metre unit WALL_H 6.0 fixes: still building service and
  // not a flex, but no longer a hose
  public static inline var CABLE_W = 0.126;
  // and the world length one repeat of the art covers. it does NOT hold the source's own aspect and
  // does not need to: the sheath is prompted featureless, so the only thing a stretch could distort
  // is grain
  public static inline var CABLE_TILE = 1.0;
  // how far a run droops below the straight line between its two ends, WORLD UNITS at mid-span. the
  // whole point of the family — a cable that leaves a fitting on a straight line reads as a pipe. IT
  // IS A CAP AND NOT THE DROOP: `FacilityCable.droop` takes the smaller of this and the headroom the
  // run's own lowest anchor leaves over the floor, because everything this family is bolted to came
  // down the wall and a fixed 0.45 now puts a mid-span UNDER it — measured at min y **0.0203** on the
  // emitted ribbon against `render.RenderConfig.PAINT_Y` 0.03, so the cable was inside the floor.
  //
  // ABSOLUTE AND NOT A FRACTION OF THE SPAN, which is the trap this was built with and had to be
  // taken back out of. A droop of 0.14 of length is a fine number on the 2-unit drop off a machine
  // lid and 1.68 units on a 3-cell link — a cable hanging to knee height across a laboratory — and
  // every time CABLE_RUN_MAX went up it got worse. The physics agrees with the fix: a strung cable's
  // sag is set by how much SLACK was left in it, not by how far apart its ends are. 0.45 is a
  // quarter-metre at the half-metre unit WALL_H 6.0 fixes. `strip` still tapers it away on a run
  // shorter than one cell, so the machine drop does not swing like a skipping rope
  public static inline var CABLE_SAG = 0.45;
  // and a slow lateral wander on top of the droop, same units, so two runs on one wall are not
  // parallel curves. render.PathLine does this per frame off a scrolling phase; here it is rolled once
  // off FacilityModel.mix and baked, because a cable does not move
  public static inline var CABLE_WAVE = 0.12;
  // and the same thing for a run lying ON THE FLOOR, where there is no gravity term at all: the
  // whole offset is the wander, and it is bigger than the wall's because a cable dropped across a
  // floor is not under tension. it is what "less straight movement" means for the floor runs — a
  // cable that crosses a lab in a straight line reads as a painted stripe
  public static inline var CABLE_SNAKE = 0.55;
  // how far a floor run floats over the surface: OVER render.RenderConfig.PAINT_Y 0.03, so a lead
  // crossing an aisle line is drawn on top of it, and under ELEC_FLOOR_Y so the scatter still covers
  // a run's cut end. see that constant for the stack
  public static inline var CABLE_FLOOR_Y = 0.05;
  // where a lead leaves a MACHINE, as a fraction of the unit's own height. NOT the lid, which is what
  // it was first and what the game reported: a fitting's sprite does not fill its quad's top corners,
  // so a cable anchored at q.h left from a point OUTSIDE the drawn object. Down at a third of its
  // height the anchor is inside the art of every fitting in the family
  public static inline var CABLE_LID_H = 0.35;
  // segments per run. the sag is a parabola and the wander a single sine, so this is only about how
  // straight the polyline looks — 10 puts a vertex every 1.2 units on a 3-cell run
  public static inline var CABLE_STEPS = 10;
  // and how many times that a MESSY run takes (StripOpts.mess): its two fast harmonics kink up to
  // eight times along a span, and at ten segments a kink is a corner
  public static inline var CABLE_MESS_STEPS = 4;
  // the longest run between two panels, in cells. a run is rejected outright if it crosses a cell
  // carrying any fitting, so this is the cap and not the rule.
  //
  // IT HAS TO BE MORE THAN FIX_SPACING AND BY MORE THAN ONE. The thinning above puts the nearest two
  // panels on a wall line exactly FIX_SPACING apart, so a cap equal to it links only pairs at exactly
  // that distance — which the greedy deal almost never produces, and the first build came back with
  // 52 panels and ZERO runs partly on this. At 5 against a spacing of 3 the window was 3, 4 or 5 and
  // the whole compound offered 19 candidate PAIRS; 8 took that to 30 and produced no extra runs at
  // all, because what actually refuses a link is the masonry in between and not the distance. It is
  // kept at 8 anyway — the reach costs nothing and a long run is the one that reads — and it only
  // became safe at all once CABLE_SAG stopped being a fraction of the span: at the old knob an
  // 8-cell run drooped 4.5 units
  public static inline var CABLE_RUN_MAX = 8;
  // and how far along the wall off the unit's centre it leaves, as a fraction of the unit's span —
  // toward the socket, so the drop is a diagonal with something to sag across rather than the
  // straight vertical a centred gland would give. 0.35 and not the old 0.22 for CABLE_LID_H's reason:
  // measured from the unit's own edge, the corners are where the art is not
  public static inline var CABLE_LID_D = 0.35;
  // and how far PAST the panels the ribbon sits. it is not a coplanarity fix for the wall — the
  // panels are already MOUNT_PROUD of that — it is one for the PANELS: a run's ends are drawn over
  // the plate they leave, and the standing note says give an overlay a physical gap rather than a
  // polygonOffset. small, because the two surfaces are parallel and this is only a depth order
  public static inline var CABLE_EPS = 0.03;

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
  //
  // CORE 0.60 -> 0.75, reported as too wide, and the CAP is not the knob for it: reach is
  // `extent/2 * (1/HALO_CORE - 1)` capped at HALO_GROW_MAX, and on everything smaller than a
  // casework run the cap never engages at all — the broom's 0.62 gives 0.207 against a cap of 1.1.
  // The fraction is the whole reach for a fitting, and 0.75 takes it to 0.333 of the half-extent
  // from 0.667, so the broom's fade is 0.103 and the numbers in the table above all halve.
  // Textures.makeRectGlowGradient is handed HALO_CORE and HALO_FADE directly, so the ramp art
  // re-bakes to match and there is nothing to author
  public static inline var HALO_CORE = 0.75;
  // THE FADE HAS TO FIT THE CANVAS: core half HALO_CORE / 2 plus the fade must stay within the 0.5
  // half-extent, or the ramp is CUT at the texture edge and every halo ends on a hard line. 0.16 fit
  // the old 0.30 core and was never retuned when the core went to 0.375: 0.535 of 0.5, so each edge
  // stopped at 12% of full weight — reported as "a very straight vertical edge, no gradient" on an
  // archive shelf's halo. It is DERIVED now, so the next core retune cannot re-open it
  public static inline var HALO_FADE = (1 - HALO_CORE) / 2;
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
  // how close a footprint's edge has to come to a wall face for FacilityDetail.ground to stand a
  // halo on it. the builders stand things PROP_GAP 0.1 off the masonry; a unit and more is a thing
  // standing in the room near a wall, and a halo there reads as a stain
  public static inline var GROUND_TOUCH = 0.3;
  // the widest footprint FacilityDetail.ground lays a round floor pool under. the contact field's
  // 0.7 blur spreads anything this small to nothing visible — a 0.62 bin read as "nothing under"
  public static inline var GROUND_POOL_MAX = 1.0;
  // and how much wider than the footprint that pool is taken. POOL_GROW's visible ring is 0.29 of the
  // half-extent — right for a box on a shelf plate, 0.09 round a bin, all of it under the bin.
  // 1.6 was asked 20% smaller off the corner bin's pool
  public static inline var GROUND_POOL_SCALE = 1.28;
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
  // and the same quad again under a decoration standing on a WORKTOP, which is the one member of
  // this family whose footprint nothing can look up from the geometry — a bench decoration is a 2D
  // sprite painted by render.Actors, not something a builder emitted.
  //
  // IT IS READ OFF THE ICON'S OWN ALPHA BOX, per frame, and the numbers below are only what a pool
  // falls back to when that box is not available (the atlas still decoding). The lookup goes
  // FacilityModel.fromArea -> FacilityDeco.poolOf; see FacilityModel.TableDeco.
  //
  // THIS SHIPPED AS A SINGLE CONSTANT 0.55 AND WAS REPORTED BACK, which is the note worth keeping:
  // over the 43 frames the content width spans 0.76 to 1.82 world units, a 2.4x range, so one
  // radius put the same puddle under a bare retort stand and under a distillation rig — and at 0.55
  // it reached 0.71, against a median icon half-width of 0.72. It was as wide as the object it was
  // meant to sit under, so it showed at both flanks whatever else was wrong.
  //
  // the fallback is the MEDIAN icon's own answer rather than a round number: 1.44 / 2 * FOOT
  public static inline var TABLE_POOL_R = 0.475;
  // how much of an icon's opaque WIDTH actually touches the resin. a silhouette is wider than a
  // footprint — a microscope's base is narrower than its arm, a retort stand is mostly air — so this
  // is a fraction of the width and never the whole of it. With POOL_GROW and the ramp's own
  // 0.30 + 0.16, the visible falloff comes out at FOOT * 1.288 of the icon's content width.
  //
  // 0.55 shipped first and read as too small once the pool was finally under the object rather than
  // beside it: 0.71 of the icon is a puddle the object stands over, not one it stands in
  public static inline var TABLE_POOL_FOOT = 0.66;
  // and where the pool sits, when the icon's box is not there to say. world +z from the cell centre.
  //
  // IT IS NOT ZERO, AND THAT IS THE BUG THIS NUMBER EXISTS FOR. render.particles.Sprites leans every
  // upright quad back by TILT about world X, about the quad's CENTRE, so an icon's drawn base ends
  // up in FRONT of the cell it stands on — measured in game at 0.69 for a quad's bottom edge and
  // 0.150 to 0.514 for the 43 icons' actual content bottoms. The pool was at the cell centre and the
  // object was drawn ahead of it, which is how it was reported. This is the mean of those 43
  public static inline var TABLE_POOL_DZ = 0.37;
  // and its weight. LIGHTER than the wall halo's HALO_ALPHA 0.32, which is a cabinet resting against
  // masonry over its whole back; this is a flask standing on a worktop, and the same weight read as
  // a painted blob rather than as contact
  public static inline var TABLE_POOL_ALPHA = 0.26;

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
  // ---- the washroom's LIGHT WELLS (Wall.WINDOW_HIGH) --------------------------------------------
  //
  // the opposite design to the two ribbons above and every number says so. A ribbon is sized FROM its
  // art and the sill takes up the slack, because a run is 2 or 3 cells and one image spans the whole
  // of it. A light well is ONE CELL and the generator writes them every other cell, so there is no run
  // to span: one image maps 0..1 across each opening, the aspect is fixed here rather than measured off
  // the drop, and the art is painted to THIS shape instead of the shape being read back off the art.
  //
  // the art's own width:height, MEASURED off the built crop (512 x 158) exactly as the two ribbons'
  // aspects are measured off theirs — the art is never stretched, so the height is DERIVED and not
  // chosen. One cell wide gives 4.0 / 3.2405 = 1.234 tall: 0.62 m of glass at the half-metre unit
  // WALL_H fixes, which is a real WC light well
  public static inline var WINDOW_HIGH_ASPECT = 3.2405;
  public static inline var WINDOW_HIGH_H = CityConfig.CELL / WINDOW_HIGH_ASPECT;
  // and how far its HEAD sits under the roof deck, which is the number that actually matters: a slot
  // is placed off the ceiling and not off the floor. 0.9 = 45 cm of masonry over it, so the sill lands
  // at 3.87 — chest-high plus a metre, and nothing in the room is seen through it from outside
  public static inline var WINDOW_HIGH_DROP = 0.9;
  public static inline var WINDOW_HIGH_SILL = WALL_H - WINDOW_HIGH_DROP - WINDOW_HIGH_H;
  // it spans its cell's FULL WIDTH, and that is a geometry decision rather than a taste one: the hole
  // a wall face leaves is recorded per cell as one sill/head pair (render.facility.FacilityGeom.build),
  // so a slot narrower than its cell would need the masonry on each hand emitted as a special case for
  // the one family that wants it. The generator writes a well every OTHER cell instead, which buys the
  // same punched rhythm out of the grid and costs nothing — a 4-unit slot with 4 units of wall between
  // it and the next
  // its own art, which is a single sash and not a run of panes. it maps 0..1 over the opening, so this
  // file's aspect above is the whole contract with it
  public static inline var WINDOW_HIGH_TEX = 'textures/facility/window-high.png';
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
  // and how far the pane sits BEHIND the glazing slab's own face, on each side.
  //
  // IT USED TO STAND 0.02 PROUD AND THAT IS THE BUG THIS REPLACES. WINDOW_OVERLAP is what forced a
  // standoff at all: the wall above and below an opening is emitted on the WINDOW CELL's slab
  // (FacilityGeom.structure's sill/head pair), which is the glazing plane, and `pane` was flush with
  // it — so the moment the pane grew past the opening it overlapped a coplanar surface and the head
  // and the sill z-fought. docs/3d-render.md's standing note says give a coplanar overlay a PHYSICAL
  // gap and never a polygonOffset, and a hair outward answered it. What it also did was put the glass
  // in the same plane as the masonry it is set into, so from inside the room a window read as painted
  // ON the wall — reported from the game as needing to be inset a little.
  //
  // The gap works in either direction and INWARD is the one that costs nothing else: the head and
  // sill caps (FacilityGeom.structure) span the slab's full 1.0 cross-section and keep the opening's
  // true size, so pulling the glass back turns them into a visible soffit and a visible sill with no
  // new geometry at all. The glazing slab is GLASS_T 1.0 against a solid wall's WALL_T 2.0, so the
  // pane already sat 0.5 behind the neighbouring wall FACE and this adds to the reveal rather than
  // creating it. 0.12 is a tenth of the slab and well inside the 0.5 the flanking cells' butt caps
  // close at a run's ends, so nothing new is exposed there. A WINDOW_HIGH cell is not in `thick`'s
  // test and keeps the full WALL_T, so its light well takes the same inset into a 2.0 slab
  public static inline var WINDOW_INSET = 0.12;
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
  // what the pane's GLASS is multiplied by once the player is INSIDE the structure it stands in,
  // eased over REVEAL_MULT beside the roof (render.facility.FacilityGeom.glaze folds it into the
  // pane's own shader; FacilityArea drives the amount).
  //
  // THE GLASS AND NOT THE WHOLE PANE, and that is the one thing to hold here. This was a plain
  // `material.color` for a build, which multiplies the entire map — and the art's frame members are
  // already sRGB 16-127, so tinting them crushed the mullions into the glass and every opening read
  // as one flat black rectangle. Reported from the game as exactly that. What separates the two is
  // the ALPHA the art already carries (tools/textures.py's `glass_alpha`: bright half to 128, frame
  // left at 255), which only a fragment can read — hence the shader.
  //
  // it is also what darkens the LOT SEEN THROUGH the opening, and that comes free from the same
  // alpha: the glass half is half see-through, so the pane composites as 0.5 * tint + 0.5 * outside.
  // 0x39424a fitted live against the interior value ladder — dark enough to read as glazing, light
  // enough that the frame still stands off it.
  //
  // the EMISSIVE goes to zero with it and takes the WHOLE pane, frame included: from a lit room a
  // night window is not a light source, and that term is also what carries the glass over
  // BLOOM_THRESHOLD. 0.9 / 0.62 = 1.45 is where the brightest glass texel stops crossing, so a
  // "dimmed" 1.4 would kill the halo and still read as a lit panel — it is 0 or it is nothing.
  //
  // BOTH FACES OF A RUN TAKE ALL OF IT, and that is why this is one material rather than two meshes.
  // The interior face cannot be seen while a structure is solid — its own roof is over it — and the
  // face the camera reads at the NEAR wall of a room the player is standing in is the EXTERIOR one.
  // So "dark from inside" and "no bloom on the outer part indoors" are the same switch, and
  // splitting the buffer would buy nothing and cost 4 draw calls, a program and the pane's shadow
  // caster (see FacilityGeom.addPane on which of the two faces actually casts)
  public static inline var WINDOW_TINT_IN = 0x39424a;
  // how far the tinted region is GROWN into the frame, in texels of the art's own level 0.
  //
  // the alpha split is exact in the source and fuzzy on screen: the texture is minified through
  // mipmaps and sampled bilinearly, so every glass/member boundary comes back as a RAMP from 0.5 up
  // to 1.0 across a texel or two. `paneGlass`'s threshold sits at 0.90-0.70, so the outermost row of
  // each pane reads as frame and stays undimmed — a bright hairline round every light, reported from
  // the game as "small issues on the tex".
  //
  // so the mask is DILATED before it is thresholded: a fragment counts as glass if anything within
  // this many texels of it is. 2 covers the bilinear tap and the row it reads from. It is a
  // morphological grow (min of a plus-shaped tap) and NOT a wider smoothstep band — widening the
  // band would have to reach past the frame's own 253/255 = 0.992 to catch that row, which dims the
  // whole frame instead of the hairline
  public static inline var WINDOW_TINT_GROW = 2.0;

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
  // and how many rows north of a TALL shed (Facility.hangarH over WALL_H, a base's) open it from
  // outside, the camera looking north. A face hides about 0.48 of its height behind it at the live
  // pitch (camera forward y -0.90 over a horizontal 0.44), so the 12-high wall head hides 5.8 units,
  // a cell and a half, and a player sprite standing up out of the second row is still half under the
  // vault's fall. Three rows opens it for anyone the shed could hide
  public static inline var HANGAR_BEHIND = 3;

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
  // HOW MANY ARE PARKED IS NOT DECIDED HERE ANY MORE. It is gen.facility.FacilityBays.CARS and
  // EMPTY, because a parked car is impassable now and so its footprint is stamped on the grid; this
  // pass stands a model on each mark it finds. The reasoning did not change with the move — there is
  // one car model, so a lot parked solid is one car repeated the length of the kerb
  // and the half-turn render.facility.FacilityCars gives half of them is the only variety one glb
  // has left

  // ---- what stands on the roof (render.facility.FacilityRoof) -------------------------------------

  // === the hangar's study podium and its floor (render.facility.FacilityHangar)

  // the podium's HEIGHT, and the only dimension the game states: render.Models.instanced scales a
  // glb by height alone, so this plus the mesh's own 17.2 x 17.2 x 3.07 fixes its footprint at
  // 17.2 / 3.07 = 5.60 times whatever is set here. Measured on the evaluated mesh — do not round it
  // without re-measuring, the dais has to stay inside the pad
  public static inline var PODIUM_H = 3.07;

  // and the height of the DECK, which is what anything standing on the podium stands on: the upper
  // step's tread (models-src/facility/podium_build.py H1), 6.2 units of radius at 1.15 up. PODIUM_H
  // is the POSTS — the eight emitters round the rim — and a ship lifted by that number floats
  // nearly two units over the dais it is supposed to be resting on
  public static inline var PODIUM_DECK_H = 1.15;

  // how many cells on a side the pad is, which is gen.blocks.HangarBlock.PAD_SZ. read here by
  // FacilityModel.findPads as the SQUARE that tells a study pad from a rack bay, and the two are
  // separately stated on purpose: the generator's copy sizes the carve and this one only recognises
  // the result, so a save made at a different pad size still resolves
  public static inline var PODIUM_PAD = 5;

  // the cable fan. ONE run per machine bank, from the machine's own cell to the podium's rim, and
  // these are the floor-run numbers from the electrical service with the bow opened up: a lead to a
  // standing unit crosses a metre of lab floor and these cross four of open shed
  public static inline var PODIUM_CABLE_BOW = 0.9;
  public static inline var PODIUM_CABLE_WAVE = 0.22;
  // where a run ends, as a fraction of the dais radius — just inside the lower step's rim, so the
  // last span arrives at the port band rather than stopping short in bare concrete
  public static inline var PODIUM_CABLE_R = 0.94;
  // and how high off the floor the ribbon lies. above CABLE_FLOOR_Y's 0.05 because the hangar floor
  // carries its own decal family and a run crossing one has to read as lying OVER it
  public static inline var PODIUM_CABLE_Y = 0.08;

  // the hangar's corner server racks to the nearest power generator (render.facility.FacilityHangar
  // .power): a BUNDLE per rack unit, thrown across the floor rather than dressed. Each strand rolls
  // its own count, splay, bow side and mess off its seed, so no two bundles tangle alike
  public static inline var GEN_CABLE_STRANDS = 2;      // strands per rack unit, plus a rolled third
  public static inline var GEN_CABLE_THIRD_PCT = 50;
  public static inline var GEN_CABLE_MESS = 0.32;      // StripOpts.mess, world units
  public static inline var GEN_CABLE_BOW = 0.7;
  public static inline var GEN_CABLE_WAVE = 0.3;
  // how far each strand's two ends are thrown off the unit's own centre, world units — the bundle
  // SPLAYS at both ends instead of leaving and arriving as one thick cord
  public static inline var GEN_CABLE_SPLAY = 0.35;
  // each strand into one generator lies this much higher than the one before, so two that cross
  // never share a plane. not under ~0.01: the camera's near plane is 0.1 and the far zoom stops
  // resolving a smaller step
  public static inline var GEN_CABLE_LIFT = 0.012;

  // === the study rig's own leads (render.facility.FacilityRig)
  //
  // the scenario's console and its three slots are patched INTO the ship, and a lead from each to
  // the dais is what says so — the same ribbon the machine fan lays, run at the same height, in the
  // alien violet nothing else in a compound wears. They pulse, slowly and together: these are one
  // circuit, unlike the ship's own three lamp families, whose whole point is disagreeing
  public static inline var RIG_CABLE_COL = 0xa855ff;
  // HDR, so the composer's bloom catches the peak. the dim run sits under BLOOM_THRESHOLD 0.9 at
  // the bottom of its breath and over it at the top, which is the difference between a pulse and a
  // shade; a lead whose slot is FILLED runs at more than twice that and never drops under it
  public static inline var RIG_CABLE_GLOW = 1.05;
  public static inline var RIG_CABLE_GLOW_LIT = 2.6;
  public static inline var RIG_CABLE_PULSE = 0.40;
  // in render.RenderConfig.BASE_MS units, so it scales with the global animation speed like every
  // other timed thing. SLOW: 0.11 is a breath every nine turns
  public static inline var RIG_CABLE_RATE = 0.11;
  public static inline var RIG_CABLE_BOW = 0.55;
  public static inline var RIG_CABLE_WAVE = 0.14;

  // the hangar floor's pack64. the same 8x8 arithmetic as CLUTTER_TEX and consumed by the same
  // emit, against its own sheet: a shed floor is pallets and survey chalk, a worktop is glassware
  public static inline var HANGAR_CLUTTER_TEX = 'textures/facility/hangar-clutter.png';
  public static inline var HANGAR_CLUTTER_COLS = 8;
  public static inline var HANGAR_CLUTTER_CELLS = HANGAR_CLUTTER_COLS * HANGAR_CLUTTER_COLS;
  // a shed floor object is a PALLET, not a pipette: drawn at most of a 4.0 cell rather than the
  // worktop family's 0.8
  public static inline var HANGAR_CLUTTER_SZ = 2.6;
  public static inline var HANGAR_CLUTTER_SZ_VAR = 0.7;
  // ONE per cell and a low roll, because the brief for this shed is "some empty space" and a floor
  // dressed like a worktop is a junkyard
  public static inline var HANGAR_CLUTTER_PCT = 15;
  // and it floats the same hair over the concrete that the worktop family floats over a bench
  public static inline var HANGAR_CLUTTER_Y = 0.02;
  // how far from the pad's edge the clutter keeps off, in cells. the podium is the thing in the
  // room and a pallet lying half under its rim is the read it costs
  public static inline var HANGAR_CLUTTER_CLEAR = 1;
  // the two cells never dealt, and the test here is GEOMETRY and not value — the other two skip
  // lists in this file condemn a cell for reading as a hole in its worktop; these two reach their
  // own cell's EDGE, so the quad next door draws a slice of them.
  //
  // tools/textures.py's `regrid` pass moved 56 of this sheet's 64 objects onto the nominal 8x8
  // split and copied the eight it could not separate through unchanged. Measured on the built sheet
  // afterwards, four cells still carry opaque texels in their own 3-px border ring — 7 at 0.421, 23
  // at 0.510, 57 at 0.031 and 58 at 0.033 — and only the first two are a read: the chain pile and
  // the taped plate both fill their cell corner to corner. 57 and 58 are a scuff's soft tail at 3%
  // and are left in, the same judgement CLUTTER_SKIP's own comment records against condemning a
  // cell by one number alone
  public static var HANGAR_CLUTTER_SKIP:Array<Int> = [ 7, 23 ];
  // the cells that are BUILT INTO or PAINTED ON the floor rather than dropped on it, and so only ever
  // turn by a quarter: a grating at 37 degrees to the shed's own tile grid reads as a sticker, where a
  // dropped chain or a rag at any angle reads as dropped. The two drain gratings (24, 25), the bolted
  // plates (38, 49, 50, 59, 60), the painted tape marks (32-35), the hazard stripes (45, 46) and the
  // radiation and biohazard stencils (57, 58)
  public static var HANGAR_CLUTTER_GRID:Array<Int> = [
    24, 25,
    38, 49, 50, 59, 60,
    32, 33, 34, 35,
    45, 46,
    57, 58,
  ];

  // a rooftop condenser unit's world HEIGHT, and through render.Models.instanced its footprint too.
  // the hand-modelled glb ROOF_BLENDER draws is built AT this height (bbox 2.778 x 2.200 x 1.770),
  // so it draws 2.78 long, 1.77 wide and 1.1 m tall at the half-metre unit WALL_H 6.0 fixes. it has
  // to fit INSIDE one cell with room to spare — a candidate is a whole cell and the prop stands at
  // its centre — and 2.78 in a 4.0 cell does. the TRELLIS bake behind the flag is 0.586 x 0.691 x
  // 0.994 and was scaled to 3.16 long by the same rule
  public static inline var ROOF_AC_H = 2.2;
  // and a comms dish's, drawing it 2.66 across on a 1.8 m pedestal. it is the tallest thing on the
  // roof deliberately: one per building, so it is the silhouette that says which building this is
  public static inline var ROOF_DISH_H = 3.6;
  // the access hatch housing, in world units — the size the generator's cells are measured against,
  // and the size models-src/facility/roofhatch_build.py is built to.
  //
  // IT WAS MERGED GEOMETRY AND IT IS A PROP NOW, which reverses the box-vs-silhouette call twice
  // over, so here is why. A hatch IS a box and as ten quads it cost no draw call at all — but a
  // merged mesh takes a TILING texture on a world-aligned UV, and this one wore BOOTH_ROOF at
  // ROOF_TILE 9.0: a ninth of a kiosk roof's standing seam on each face. The game reported that
  // twice, as a box of coping and then as a reused texture, and both reports were about the ART.
  // A 1.2 x 1.0 m lid's whole read is the tread plate ON it, seen by a camera pitching 51 to 86
  // degrees down, and a plate pattern is a PICTURE of a lid: it maps 0..1 onto that one face, which
  // is what a glb's own unwrap does and what a tiling emitter cannot. The draw call comes back out
  // of the mesh it left — the hatch and the isolator boxes were the only two things in
  // FacilityRoof's kit buffer, so both leaving deletes one merged mesh per deck
  public static inline var HATCH_W = 2.4;
  public static inline var HATCH_D = 2.0;
  // A CURB AND A LID, and it used to be a 1.2-tall box of COPING. Both halves of that were wrong
  // and the game reported the pair of them at once ("what is that box out of coping supposed to
  // be"): 2.4 x 2.0 is 1.2 x 1.0 m at the half-metre unit WALL_H 6.0 fixes, which is a real roof
  // access hatch and not a stair bulkhead — so 1.2 units of height is 60 cm of it, four times what
  // a hatch curb measures and half what a doorway needs. And precast concrete coping tiled at
  // ROOF_TILE 9.0 put a ninth of one coping stone on each face, i.e. a fragment of a texture whose
  // whole read is the LINE it makes along a parapet.
  //
  // a curb with a lipped lid instead, in BOOTH_ROOF's painted steel decking — the one art in the
  // compound that already IS a lid (see its own header), tiling at 0.69 units a pan, so a 2.4 lid
  // shows three and a half of them. Zero new art, one texture for the whole housing, and the lip
  // is what makes it read as something that opens rather than as a stub
  public static inline var HATCH_CURB = 0.3;
  public static inline var HATCH_LID = 0.1;
  public static inline var HATCH_LIP = 0.09;
  // and what the batch scales the glb by. render.Models.instanced scales by HEIGHT alone and the
  // mesh is built at exactly this, so the scale is 1 and the 2.4 x 2.0 plan above is the plan that
  // draws — the same discipline the condenser and the dish are built to
  public static inline var ROOF_HATCH_H = HATCH_CURB + HATCH_LID;
  // one candidate cell in this rhythm carries something. the same device
  // render.facility.FacilityLamps uses on its lit lines: a phase over (col, row) spreads the picks
  // without a list and without a per-cell roll, so re-entering an area lays them out identically
  public static inline var ROOF_PROP_STEP = 5;
  // and at most this many condensers per building. it is not a cap on a running count — the
  // candidate list is STRIDED down to this plus the dish and the hatch, so what a big roof loses is
  // density and not its far half (see render.facility.FacilityRoof.fill)
  public static inline var ROOF_PROP_MAX = 8;
  // how many cells in from the parapet anything may stand. a deck deeper than this is BARE, so a
  // big roof reads as a serviced perimeter around an empty middle rather than as an evenly
  // scattered field of condensers.
  //
  // CHOSEN AGAINST THE MEASUREMENT AND THAT IS ON PURPOSE: the compound camera runs 51 to 86
  // degrees of pitch and the parapet hides only ~1.1 units inside the near edge, so the bare centre
  // IS visible from a high orbit. If it reads as a donut this is the single knob. 2 is the floor —
  // render.facility.FacilityRoof.candidates already refuses the cell against the wall, so anything
  // under 2 empties the roof
  public static inline var ROOF_RING_INSET = 3;
  // and how many of that band's bays carry plant. the rest stay bare deck: condensers GROUPED in
  // two or three bays is the whole reason the deck is cut up at all, a bay per bay being what the
  // strided scatter already did
  public static inline var ROOF_PLANT_BAYS = 3;
  // the roof's service run, and it is the ONE cable family in the compound that is not a cable
  // hanging off something. Every other run in here is render.facility.FacilityCable.strip — a
  // bowed, wandering, sagging ribbon, which is what a flex leaving a fitting looks like and is
  // what this used to be. A roof is building service: the trunking between a condenser and its
  // isolator is a BUNDLE, it is CLIPPED DOWN, and it turns square corners. Reported from the game
  // as wanting serious cables at 90 degrees in straight lines, and the shape was the whole of it —
  // a bowed run across a deck reads as something the wind dropped there.
  //
  // so the emitter is FacilityRoof.leg and not `strip`: one flat quad per straight leg, the cable
  // art's u across it exactly as `strip` lays it, and an L of two legs per run. A ribbon that
  // never bends needs no steps, so the whole run is two quads per way instead of `strip`'s ten.
  //
  // how high the bundle lies over the deck. there is no PAINT_Y up here and nothing else on the
  // roof is flat, so this is only clear of the deck itself
  public static inline var ROOF_CABLE_Y = 0.05;
  // how many ways the bundle carries, and how far apart they are clipped. THREE AND NOT ONE is the
  // "more serious" half of the report: a single 6 cm ribbon at this camera is a hairline, and
  // three of them side by side read as trunking at no extra draw call — they share the buffer.
  // the pitch is 1.5x CABLE_W, so there is a gap of half a cable between each and the deck shows
  // through it; laid edge to edge they merge into one wide grey band
  public static inline var ROOF_CABLE_WAYS = 3;
  public static inline var ROOF_CABLE_PITCH = CABLE_W * 1.5;
  // and how far apart they are in HEIGHT, which is not decoration. TWO FLAT QUADS AT ONE Y THAT
  // OVERLAP AT ALL ARE THE SAME PLANE, and a bundle turning a corner overlaps by a cable's width
  // every single time. Measured on this compound before the clip: 88 roof cable quads made 84
  // exactly-coplanar overlapping pairs over 1.67 square units, and the game reported the z-fight on
  // all three ways. One lay apart puts every crossing one clip's thickness over the one it crosses,
  // which is also what a real bundle does where two runs meet
  public static inline var ROOF_CABLE_LAY = 0.02;
  // the isolator box a group of condensers is wired back to, world units. it stands on the deck at
  // its group's centroid and it is what stops the runs being long: before it, every condenser was
  // chained to the nearest already-fed one and the tree walked the whole ring band — reported as
  // the cables going all the way around. A box per few units turns that into two legs each
  public static inline var ROOF_JBOX_W = 0.75;
  public static inline var ROOF_JBOX_D = 0.55;
  public static inline var ROOF_JBOX_H = 0.9;
  // and how far, in CELLS of manhattan distance, a condenser may be from its own box. IT IS PACED
  // OFF ROOF_PROP_STEP AND NOT OFF A BAY: the candidates are taken on a 5-cell phase and then
  // strided again, so two units in one bay measure 3 to 5 apart and never less. Measured on the
  // 15 condensers of this compound — reach 3 grouped them into 11 boxes, i.e. a box each, which is
  // what __facility().roof's cables-over-boxes ratio exists to catch; reach 5 gives 7 boxes at 2.1
  // units apiece and no group spanning more than a bay and its lane
  public static inline var ROOF_JBOX_REACH = 5;

  // the SERVICE KIT: the three families that stand on a deck beside the condensers, in world units
  // and built AT these heights (models-src/facility/roofsvc_build.py), so render.Models.instanced's
  // height scale is 1 and the plans below are the plans that draw.
  //
  // an extract vent: a mushroom cowl 40 cm across on its own curb, the smallest thing up here. It
  // goes in the SERVICE bay with the hatch, because that is where the shafts it caps come up
  public static inline var ROOF_VENT_H = 1.1;
  public static inline var ROOF_VENT_PLAN = 0.8;
  // and an expansion tank, which is a share of the PLANT bay's own cells rather than a family of
  // its own: a plant bay with one vessel among its condensers is a plant bay, and a bay of tanks is
  // a tank farm. ROOF_TANK_PCT of the units dealt a plant cell come out as one
  public static inline var ROOF_TANK_H = 1.6;
  public static inline var ROOF_TANK_PLAN = 0.92;
  public static inline var ROOF_TANK_PCT = 22;
  // and the duct run. IT IS BUILT ONE CELL LONG, which is the whole reason it can be a prop: a
  // segment built at its stated height draws its stated length, so segments dropped on neighbouring
  // cell centres abut with no seam, no per-instance scale and no swept mesh — a run is N placements
  // in one batch. ROOF_DUCT_H is measured to the FLANGE rings, the widest thing on the segment
  public static inline var ROOF_DUCT_H = 1.0;
  public static inline var ROOF_DUCT_PLAN_D = 0.72;
  // and how many segments one run may take. it walks out of the service bay along the ring band, so
  // the cap is what stops a duct following the band the whole way round the building — the fault
  // the cable trunking was reported for (see ROOF_JBOX_REACH)
  public static inline var ROOF_DUCT_MAX = 3;

  // the CONTACT SHADOW under everything that stands on a deck, and the footprints it is laid to.
  //
  // IT IS NOT A SUBSTITUTE FOR A CAST SHADOW AND THE PROPS DO CAST ONE. Reported from the game as
  // the condenser throwing none, and measured rather than assumed: the deck's light is 66% moon
  // (turning the directional off took a pinned deck window from rgb 2.2/6.9/17.8 to 0.1/3.0/6.0),
  // so a shadow up here reads — but the moon stands 48 degrees up and a condenser is 2.78 x 1.77 on
  // the plan under 2.2 of height, so its whole shadow falls UNDER ITSELF. Turning the batch's own
  // castShadow off changed 7,632 pixels of that frame by a mean of 1.1 of 255. A 3.6-tall dish on a
  // 1.5 pedestal clears itself and does throw one; nothing else on a roof has that aspect.
  //
  // so this is the planted read and not the light: FacilityDetail.pooled's rounded-box field, the
  // one it lays under a box standing on a shelf plate, laid on the deck instead. It rides the
  // FADING buffer, so the weight is baked into the ramp (see Textures.makeRectGlowGradient's `peak`)
  // rather than left on the material, which FacilityArea.apply overwrites every frame
  public static inline var ROOF_POOL_ALPHA = 0.5;
  // and how high it floats. UNDER ROOF_CLUTTER_Y 0.02, so where a tar patch and a condenser share a
  // cell the patch draws over the shadow and not into it
  public static inline var ROOF_POOL_Y = 0.012;
  // the two props' PLAN size, read off the built glbs (tools/propstat.py: 2.778 x 2.200 x 1.770 and
  // 2.660 x 3.600 x 2.011) — render.Models.instanced scales by height alone, and both are built AT
  // their stated height, so the bbox's other two axes are the world footprint with no arithmetic.
  //
  // THE DISH'S IS ITS PEDESTAL AND NOT ITS BBOX. 2.66 of that is the reflector, three metres up in
  // the air and tilted 40 degrees; what stands on the deck is a 0.46 base plate on three feet
  public static inline var ROOF_AC_PLAN_W = 2.778;
  public static inline var ROOF_AC_PLAN_D = 1.77;
  public static inline var ROOF_DISH_PLAN = 1.5;

  // which roof props the compound draws: the hand-modelled pair (models-src/facility/roofac_build.py
  // and roofdish_build.py) or the TRELLIS bakes they replace. Same switch as FENCE_BLENDER,
  // BENCH_BLENDER and ENTRY_BLENDER above and for the same reason — both paths ship, and one boolean
  // puts the bakes back if the authored meshes turn out to buy nothing on screen.
  //
  // THE TRADE HERE IS NOT THE ONE THE CHECKPOINT MADE. There the argument was silhouette against
  // merged quads and the hand-modelled pair cost 1,380 triangles to win it; here both objects are
  // already props and the authored versions are simply CHEAPER — 660 and 948 against 5,619 and 5,800
  // — because every number in them is stated (the condenser is built at ROOF_AC_H, the dish's horn
  // stands at a focus derived from a stated f/D) where a bake approximates all of them
  public static inline var ROOF_BLENDER = true;

  // the roof deck's own pack64 (art/textures.json facility/roof-clutter), consumed by the same
  // emit/UV arithmetic as HANGAR_CLUTTER one storey down. IT IS THE ONE FAMILY THE BARE MIDDLE CAN
  // TAKE: every cell of that sheet is genuinely flat — tar patches, ponded water, chalk, anchor
  // plates — which is the line this file's roof header draws when it refuses a decal for a
  // condenser. So it dresses the WHOLE deck and not just the ring band
  public static inline var ROOF_CLUTTER_TEX = 'textures/facility/roof-clutter.png';
  public static inline var ROOF_CLUTTER_COLS = 8;
  public static inline var ROOF_CLUTTER_CELLS = ROOF_CLUTTER_COLS * ROOF_CLUTTER_COLS;
  // bigger than the shed floor's 2.6 because the camera is a storey further off it and a roof has no
  // furniture to read scale against, and a lower roll than the hangar's 15 for the reason the bare
  // middle exists at all: this is weathering, not litter
  public static inline var ROOF_CLUTTER_SZ = 2.8;
  public static inline var ROOF_CLUTTER_SZ_VAR = 0.8;
  public static inline var ROOF_CLUTTER_PCT = 12;
  // and how far it floats over the deck. UNDER ROOF_CABLE_Y 0.05, so a service run crossing a tar
  // patch is drawn over it — the same stack the floor families keep (see CABLE_FLOOR_Y)
  public static inline var ROOF_CLUTTER_Y = 0.02;

  // the smallest bay a comms dish will stand in, on a side. it is the roof's silhouette and needs
  // clear deck around it, so a small building simply has none — which is also what keeps the dish
  // from being on every roof in the compound
  public static inline var ROOF_DISH_BAY = 4;

  // ---- the parking entry's checkpoint ------------------------------------------------------------

  // which checkpoint the compound draws: the hand-modelled pair (models-src/facility/entry_build.py)
  // or the merged quads that replaced the generated props. Same switch as FENCE_BLENDER and
  // BENCH_BLENDER above and for the same reason — both paths ship, and one boolean puts the
  // 56-triangle version back if 1,380 turns out to buy nothing on screen.
  //
  // READ THE HEADER OF render.facility.FacilityEntry BEFORE MOVING THIS. That file argues at length
  // that a box is not a prop and it is right about GENERATED props; what is on trial here is a mesh
  // authored to the constants below, which is the one route it never tested
  public static inline var ENTRY_BLENDER = true;

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
  // and how thick the slab is, i.e. the band that reads as its edge. 0.12 AND NOT 0.3: at 0.3 the
  // eave was a parapet, and the reports that followed the checkpoint's UV pass were mostly about
  // faces of it -- the fascia flanks, their arrises and the drip lip under them are all this one
  // dimension, and a slab a third as thick is a roofline rather than a lid
  public static inline var BOOTH_FASCIA = 0.12;
  // and how far the aerial stands over that slab. IT IS ONLY IN THE GLB — the emitted booth has no
  // mast — and it is a constant here because the batch's target height is BOOTH_H + BOOTH_FASCIA +
  // BOOTH_MAST: render.Models.instanced scales by HEIGHT alone, so the mesh's own total height is
  // what has to be passed or every other dimension of it moves
  public static inline var BOOTH_MAST = 1.0;
  // and WHERE ON THAT AERIAL the cable collar sits, which the checkpoint's service drop has to land
  // on. the mast stands BOOTH_MAST_IN in from the roof slab's own corner — so BOOTH_W / 2 minus
  // this off the booth's centre, on +x and -z, because the glb's local +y exports as world -z — and
  // the collar is BOOTH_MAST_FRAC up the mast. models-src/facility/entry_build.py, verbatim
  public static inline var BOOTH_MAST_IN = 0.35;
  public static inline var BOOTH_MAST_FRAC = 0.62;
  // and the drop itself: where up the pole it is clamped as a fraction of LAMP_H, how far it FALLS
  // between the two as a fraction of the span, and how much it wanders sideways on the way.
  //
  // IT SAGS AND THE RIBBON STAYS LEVEL, which needed the two axes separated in
  // render.facility.FacilityCable.strip — a ribbon is widened along the same vector it is BOWED
  // along, so this span shipped swinging sideways instead of hanging. The fall is StripOpts.sag,
  // perpendicular to the chord out of world down, and the ribbon's width stays in the horizontal
  // plane where a camera pitched 51 degrees down can see it. 0.06 of the span is a real service
  // drop's own slack; the sideways wave is kept, small, so two compounds do not draw one curve
  public static inline var ENTRY_CABLE_Y = 0.9;
  public static inline var ENTRY_CABLE_BOW = 0.0;
  public static inline var ENTRY_CABLE_SAG = 0.06;
  public static inline var ENTRY_CABLE_WAVE = 0.25;
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
  // and where the POLE stands in that same model, as the same fraction — NEGATIVE, because it stands
  // behind the plan centre by as much as the housing hangs in front of it. Measured off the built
  // glb the same way: over the bottom 90% of a model normalised to height 1.002 the mast's own verts
  // centre on z -0.0634 and span 0.102 across, so the pole is 0.37 world units behind the point the
  // batch places and 0.30 wide. Anything that has to MEET the post rather than the fixture — the
  // checkpoint's service drop is the first — takes FacilityLamps.Mast's `ax`/`az`, not its `x`/`z`
  public static inline var LAMP_POLE_Z = -0.0634;
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
  // the moon's shadow box moves in steps of this many cells and its map is frozen between them. the
  // box has >= 8.5 cells of slack around the follow view and >= 6 around the tactical one, so a
  // 4-cell step never lets the view reach its edge
  public static inline var MOON_SNAP = 4;
  // the merged meshes' range-cull block, in cells. 8 measured best in the prototype; a block test
  // is ~nothing, and smaller blocks only fragment the one range a mesh draws
  public static inline var RANGE_BLOCK = 8;
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

// the compound's own ShellOpts: how render.facility.FacilityModel reads a saved facility grid, and
// the art render.facility.FacilityGeom dresses the result in.
//
// EVERY PATH IN HERE WAS A CONSTANT AT THE FLUSH until the corp tower needed the same emitter with
// a different art set. Moving them onto the model is the whole of that change — see ShellTex
  public static function shell(): ShellOpts
    {
      var floor = [for (_ in 0...SURF_SLOTS) (null : String)];
      floor[FacilityModel.Surf.TILE] = FLOOR_TILE;
      floor[FacilityModel.Surf.LINO] = FLOOR_LINO;
      floor[FacilityModel.Surf.CONCRETE] = FLOOR_CONCRETE;
      floor[FacilityModel.Surf.OFFICE] = FLOOR_OFFICE;
      floor[FacilityModel.Surf.WASH] = FLOOR_WASH;
      // the interior face is picked off the surface it LOOKS INTO, so a corridor is painted board
      // and the room the other side of the same slab is tiled. A surface with no entry falls back
      // to WALL_ROOM, which is what the emitter's old `case _` did
      var into = [for (_ in 0...SURF_SLOTS) WALL_ROOM];
      into[FacilityModel.Surf.LINO] = WALL_CORRIDOR;
      into[FacilityModel.Surf.OFFICE] = WALL_OFFICE;
      into[FacilityModel.Surf.WASH] = WALL_WASH;
      return {
        kind: 'facility',
        tex: {
          floor: floor,
          wallOut: WALL_EXTERIOR,
          wallInto: into,
          pane: WINDOW_LIT,
          pane2: WINDOW_LIT_2,
          aspect: WINDOW_ASPECT,
          aspect2: WINDOW_ASPECT_2,
          paneHigh: WINDOW_HIGH_TEX,
          head: WINDOW_HEAD,
          roof: ROOF,
          coping: COPING,
          shutter: DOOR_SHUTTER,
          // the compound has no lift car, so its doorways keep the plain circulation reveal
          pocket: null,
          sill: null,
          // the fifth slot is Look.LIFT, which no compound door is ever dealt — it takes the
          // metal leaf so the array is the length the emitter indexes and nothing here changes
          door: [DOOR_GLASS, DOOR_CABINET, DOOR_METAL, DOOR_PRIVATE, DOOR_METAL],
          circ: FacilityModel.Surf.LINO,
          hood: DOOR_LAMP_TEX,
          hangarWall: WALL_HANGAR,
          vault: ROOF_HANGAR,
          road: GROUND_ROAD,
          walkway: GROUND_WALKWAY,
          lot: GROUND_LOT,
          kerb: GROUND_BORDER,
          paint: GROUND_PAINT,
          zone: ZONE_TEX,
          grime: GRIME,
          cable: CABLE_TEX,
          elec: ELEC_TEX,
          exitSign: EXIT_TEX,
          wallPoints: POINT_TEX,
          roofClutter: ROOF_CLUTTER_TEX,
          mastColor: LAMP_COLOR,
          lampColor: LAMP_COLOR,
          doorLampColor: DOOR_LAMP_COLOR,
        },
        surfOf: FacilityModel.surfOf,
        // a compound's furniture is all either a worktop (`table`) or a decoration with a fitting
        // kind (`deco`), and both are already grids — nothing here needs a third
        fitOf: function(t) return 0,
        tableOf: Const.isTableTile,
        wallOf: FacilityModel.wallOf,
        // a compound's partitions ARE blockwork, so the interior is the same WALL_T as the shell
        wallIn: WALL_T,
        hangars: true,
        hangarH: WALL_H,
        deck: true,
        parapet: true,
      };
    }

  // how many slots a per-Surf array holds. one more than the highest Surf value, which is LAB_PAD (31)
  public static inline var SURF_SLOTS = 32;

// the compound's night rig (render.facility.FacilityScene.build): its sky and fog, and the fill.
// the facility runs DARKER than the wilderness because its art is brighter: the lab floor measures
// 0.0607 linear and the corridor lino 0.0750, against the wilderness turf's 0.0503, and the
// interior is what fills the frame the moment the roof fades
  public static function rig():FacilityRigOpts
    {
      return {
        sky: SKY,
        near: FOG_NEAR,
        far: FOG_FAR,
        ambient: 0x46536b,
        hemiSky: 0x56668c,
        hemiGround: 0x18211c,
        moon: 0x8294c0,
      };
    }
}

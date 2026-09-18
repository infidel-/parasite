package render.facility;

import three.Three;
import citygen.CityConfig;
import gen.Quota;
import gen.Rng;
import gen.Subdivide;
import gen._GenDemand;
import gen._GenNode;
import gen._SplitProfile;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBufTools;

// one thing standing on a roof: where it is, what it is, and which structure's deck it stands on.
// the structure is what drives its visibility — see `mask` — and it is in __facility().roof because
// an instanced batch carries no userData.cls, so render.Debug.find cannot reach a condenser
typedef RoofProp = {
  col:Int,
  row:Int,
  kind:String,      // 'ac' | 'dish' | 'tank' | 'vent' | 'duct'
  structure:Int,
};

// one hangar's barrel vault, as the numbers it was DERIVED from rather than as geometry. every
// question an arch raises is numeric and a screenshot cannot answer any of them: is the section
// really a circle segment (radius against span and rise), how much of a circle is it actually
// taking, did the ridge pick the long axis, did both gable crescents emit
typedef Vault = {
  structure:Int,
  span:Float,        // the chord, outer wall plane to outer wall plane across the SHORT axis
  rise:Float,        // the segment height over that chord
  radius:Float,
  arcDeg:Float,      // the whole subtended angle — a half-round barrel would read 180
  seg:Int,
  quads:Int,         // the arch itself, in the FADING deck
  gables:Int,        // and the two crescents closing its ends, in the structure's own WALL buffer
  ridgeAlongX:Bool,
  // how long the ridge is. `span` alone cannot catch a box fitted to the wrong rect — see `ring`,
  // where a door in the wall ring stretched exactly this and left the span correct
  ridge:Float,
};

// the vault's section, derived once and read by both halves of it — the arch, which fades with the
// deck, and the gable crescents, which are cladding and stay with the walls
typedef Arc = {
  alongX:Bool,          // does the ridge run along x
  a0:Float,             // the ridge's two ends, on the outer masonry planes
  a1:Float,
  cs:Array<Float>,      // the arc, per node: its coordinate on the CROSS axis
  ys:Array<Float>,      // and its height
  span:Float,
  rise:Float,
  r:Float,
  theta:Float,          // HALF the subtended angle
};

// one bay of a roof deck: the rect gen.Subdivide cut and the kind gen.Quota dealt it. in
// __facility().roof because "is the centre actually bare" and "did the plant group up" are numbers,
// and the only thing on screen is a condenser that is either there or not
typedef RoofZone = {
  structure:Int,
  kind:String,
  x1:Int,
  y1:Int,
  x2:Int,
  y2:Int,
  band:Int,          // how many of the ring band's cells fell in it — 0 means it is the middle
};

// one straight run of trunking in the plane of the deck: which axis it lies along, where its centre
// line sits on the other one, the interval it covers, and how high it lies. `runs` builds these
// INSTEAD of emitting as it goes, because the fault it fixes is two quads covering one patch of deck
// and that cannot be seen one quad at a time
typedef Seg = {
  ax:Int,            // 0 = along x, 1 = along z
  line:Float,
  a0:Float,          // always the LOW end, so `leg` needs no ordering of its own
  a1:Float,
  y:Float,
};

// the four things ONE structure's roof pass fills: two batch placement lists and two merged buffers.
//
// IT IS A RECORD AND NOT FOUR MORE ARGUMENTS. `fill` was already at the five the style guide says to
// stop appending at, and the cable ribbon was the sixth — and unlike an options bag there is nothing
// optional here and nothing a caller could order wrongly, so it stays in this file rather than
// becoming a `<Thing>Opts.hx` next door
typedef RoofDeck = {
  ac:Array<Models.PropPlace>,
  dish:Array<Models.PropPlace>,
  // and the SERVICE KIT, which is two more of the same: the access hatch and the isolator boxes
  // were one merged painted-steel mesh until the art they wore was reported twice (see
  // FacilityStyle.HATCH_CURB), and they are batches now. The mesh they left is why that costs
  // nothing: they were the ONLY two things in it
  hatch:Array<Models.PropPlace>,
  jbox:Array<Models.PropPlace>,
  // and the SERVICE KIT: an extract vent, a lagged duct segment and an expansion tank. Three more
  // placement lists and not three more meshes, for the reason the hatch became one — each is a
  // picture on its own faces, and the duct is only a prop at all because a segment built one cell
  // long abuts the next one (see FacilityStyle.ROOF_DUCT_H)
  vent:Array<Models.PropPlace>,
  duct:Array<Models.PropPlace>,
  tank:Array<Models.PropPlace>,
  // the cable runs, in the cable art. they ride the structure's own Shell.roof so they fade with
  // the deck they stand on: a ribbon that stayed when the deck went would be a cable hanging over
  // the room the player walked into
  cab:render.world.MeshBuf.MeshBuf,
  // and the deck's flat dressing, in its own pack64. a THIRD mesh and not a share of either: the
  // kit is opaque steel, the runs are opaque cable art, and this one is alpha-cut DoubleSide
  pack:render.world.MeshBuf.MeshBuf,
  // and the contact shadow under everything that stands up here, in the rounded-box ramp
  // FacilityDetail lays under a box on a shelf plate. a FOURTH mesh for the same reason as the
  // third: it is the only thing on a roof drawn in a generated gradient rather than in an art sheet
  shade:render.world.MeshBuf.MeshBuf,
};

// the two instanced batches, what they stand on, and how many hatches were built
typedef Roof = {
  ac:Models.InstancedProp,
  dish:Models.InstancedProp,
  // and the two service boxes, which are batches for the art's sake and not the silhouette's
  hatchB:Models.InstancedProp,
  jboxB:Models.InstancedProp,
  // and the service kit's three
  ventB:Models.InstancedProp,
  ductB:Models.InstancedProp,
  tankB:Models.InstancedProp,
  // index-aligned with each batch's own placements: which structure that instance stands on
  acOf:Array<Int>,
  dishOf:Array<Int>,
  hatchOf:Array<Int>,
  jboxOf:Array<Int>,
  ventOf:Array<Int>,
  ductOf:Array<Int>,
  tankOf:Array<Int>,
  props:Array<RoofProp>,
  hatches:Int,
  vaults:Array<Vault>,
  zones:Array<RoofZone>,
  cables:Int,
  // and how many isolator boxes they run back to. cables / boxes is the number the shape of this
  // family lives or dies on: near 1 and every condenser got its own box, over about 4 and one box
  // is serving the whole deck again, which is the long runs this replaced
  boxes:Int,
  clutter:Int,
  // the service kit's three counts. `ducts` is SEGMENTS and not runs, which is the number that says
  // whether the walk out of the service bay found band to lay on: a run is 1 to ROOF_DUCT_MAX of
  // them and a deck reporting 0 ducts with a hatch on it means the walk broke, not that the bay
  // was small
  vents:Int,
  ducts:Int,
  tanks:Int,
  // and how many contact shadows were laid. one per thing standing on a deck — condenser, dish,
  // hatch, box, vent, duct segment and tank — so it is the sum of the seven and a mismatch means a
  // family was placed without being planted
  pools:Int,
};

// what stands on a facility building's roof: condenser units, one comms dish and one access hatch
// per building, inside the parapet.
//
// the CITY answers this question with top-down sprite decals (render.world.roofs.RoofDetails) and
// this deliberately does not: a decal is flat, and the facility's roofs are the one place in the
// game the camera looks down ONTO rather than past, so a condenser lying flat on the deck reads as a
// stain. two of these are real props and the third is merged geometry, which is the same
// silhouette-vs-surface split every other object in this compound was decided on (see the header of
// render.facility.FacilityEntry).
//
// RENDER-ONLY and derived, like the cars and the gate: nothing is stamped on the tiles, so every
// compound already saved grows its plant the moment it is drawn again.
//
// NO VISION MASK on any of it, and that is the roof's own rule rather than an oversight. the roof is
// the one surface whose visibility is decided by where the player STANDS and not by what they can
// see (FacilityGeom.structure's call to addDeck says why); a masked condenser over cells the LOS
// sweep never reached would sink to the fog colour while the deck under it stayed solid
class FacilityRoof
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every roof in the compound, and the two kinds are not variations of one thing. a LAB BUILDING is a
// parapeted box with a flat deck and objects standing on it; a HANGAR is a shed, so it takes no
// parapet, carries nothing, and its roofline IS its roof — the arched vault `vault` springs between
// its long walls, which is the job FacilityGeom.structure's parapet skip has been deferring
  public static function build(scene:Scene, m:Facility, shells:Array<Shell>):Roof
    {
      var deck:RoofDeck = {
        ac: [],
        dish: [],
        hatch: [],
        jbox: [],
        vent: [],
        duct: [],
        tank: [],
        cab: null,
        pack: null,
        shade: null,
      };
      var out:Roof = {
        ac: null,
        dish: null,
        hatchB: null,
        jboxB: null,
        ventB: null,
        ductB: null,
        tankB: null,
        acOf: [],
        dishOf: [],
        hatchOf: [],
        jboxOf: [],
        ventOf: [],
        ductOf: [],
        tankOf: [],
        props: [],
        hatches: 0,
        vaults: [],
        zones: [],
        cables: 0,
        boxes: 0,
        clutter: 0,
        vents: 0,
        ducts: 0,
        tanks: 0,
        pools: 0,
      };
      for (si in 0...m.structures.length)
        {
          if (m.structures[si].hangar)
            {
              out.vaults.push(vault(scene, m, si, shells[si]));
              continue;
            }
          // the two merged buffers are per STRUCTURE and the two placement lists are not: a batch is
          // one compound-wide InstancedMesh with a per-instance mask (see `mask`), a fading mesh
          // belongs to the deck it fades with
          deck.cab = MeshBufTools.make();
          deck.pack = MeshBufTools.make();
          deck.shade = MeshBufTools.make();
          fill(m, si, deck, out);
          FacilityGeom.addDeck(scene, deck.cab, FacilityStyle.CABLE_TEX, true, shells[si]);
          pack(scene, deck.pack, shells[si]);
          shade(scene, deck.shade, shells[si]);
        }
      out.ac = Models.instanced(scene, acPath(), deck.ac, FacilityStyle.ROOF_AC_H, SOLID);
      out.dish = Models.instanced(scene, dishPath(), deck.dish, FacilityStyle.ROOF_DISH_H, SOLID);
      out.hatchB = Models.instanced(scene, RenderConfig.MODELS.facilityRoofHatchHand, deck.hatch,
        FacilityStyle.ROOF_HATCH_H, SOLID);
      out.jboxB = Models.instanced(scene, RenderConfig.MODELS.facilityRoofJboxHand, deck.jbox,
        FacilityStyle.ROOF_JBOX_H, SOLID);
      out.ventB = Models.instanced(scene, RenderConfig.MODELS.facilityRoofVentHand, deck.vent,
        FacilityStyle.ROOF_VENT_H, SOLID);
      out.ductB = Models.instanced(scene, RenderConfig.MODELS.facilityRoofDuctHand, deck.duct,
        FacilityStyle.ROOF_DUCT_H, SOLID);
      out.tankB = Models.instanced(scene, RenderConfig.MODELS.facilityRoofTankHand, deck.tank,
        FacilityStyle.ROOF_TANK_H, SOLID);
      return out;
    }

// what a roof deck is cut into. BARE is gen.Quota's filler and writes nothing, so the middle of a
// big roof and every bay no demand wanted are the same thing to this
  public static inline var PLANT_BAY = 'plant';
  public static inline var DISH_PAD = 'dish';
  public static inline var SERVICE = 'service';
  public static inline var BARE = 'bare';

// the knobs the deck is cut with. a bay is three cells minimum with a one-cell lane between two of
// them, and two cuts deep, so a 14 x 12 roof comes out in a handful of bays rather than in a grid
  static var SPLIT:_SplitProfile = {
    minSide: 3,
    splitOver: 7,
    maxSide: 11,
    gap: 1,
    depth: 2,
    earlyLeafChance: 0.25,
    maxAspect: 3.0,
  };

// which glb each batch draws, behind FacilityStyle.ROOF_BLENDER. PUBLIC because the warm pass has to
// ask the same question — a warm that compiles the bake's material and then meets the authored mesh
// on first entry has warmed nothing
  public static inline function acPath():String
    return (FacilityStyle.ROOF_BLENDER
      ? RenderConfig.MODELS.facilityRoofAcHand : RenderConfig.MODELS.facilityRoofAc);

  public static inline function dishPath():String
    return (FacilityStyle.ROOF_BLENDER
      ? RenderConfig.MODELS.facilityRoofDishHand : RenderConfig.MODELS.facilityRoofDish);

// one building's roof: the deck is cut into bays, gen.Quota deals each bay what it carries, and the
// ring band's cells are then handed out inside whichever bay they fell in.
//
// THE BAND IS THE UNIT OF PLACEMENT AND THE BAY IS THE UNIT OF INTENT. the band (see `candidates`)
// is every cell something may stand on at all; the bays say which stretch of it is plant, which one
// has the stair core coming up under it, and which is left as deck. what this replaces is a STRIDE
// over the whole band — it spread the props evenly and so said nothing about the building, and a
// condenser every fifth cell all the way round is a texture and not a plant room
  static function fill(m:Facility, si:Int, deck:RoofDeck, out:Roof):Void
    {
      var band = candidates(m, si);
      if (band.length == 0)
        return;
      var zs = zones(m, si, band, out);
      var plant = [];
      var svc = [];
      var pad = [];
      for (c in band)
        {
          var z = zoneAt(zs, c.col, c.row);
          // the gap gen.Subdivide leaves between two bays belongs to no bay, and on a roof that is
          // a service lane: nothing stands in it
          if (z == null)
            continue;
          if (z.kind == PLANT_BAY)
            plant.push(c);
          else if (z.kind == SERVICE)
            svc.push(c);
          else if (z.kind == DISH_PAD)
            pad.push(c);
        }
      // thin the plant to what one roof should carry, by a STRIDE over the whole of it and not by
      // taking the first N. the scan is row-major, so a cap alone spends a big roof's entire
      // allowance on its first two rows: measured on the 31x24 building, all seven objects came
      // back at rows 8 and 9 and the rest of the deck was bare
      var step = Std.int(Math.ceil(plant.length / FacilityStyle.ROOF_PROP_MAX));
      if (step > 1)
        plant = [for (i in 0...plant.length) if (i % step == 0) plant[i]];
      // the hatch goes nearest the middle of the roof, where a stair core comes up — of the SERVICE
      // bay's own cells, since the middle itself is bare deck now
      var st = m.structures[si];
      var core = nearest(svc, (st.x1 + st.x2) / 2.0, (st.y1 + st.y2) / 2.0);
      if (core != null)
        {
          var c = CityConfig.cellToWorld(core.col, core.row);
          var h = FacilityModel.mix((core.col * 70001) ^ (core.row * 30011));
          // a QUARTER TURN and not a free one, exactly as the condensers take: it is a manufactured
          // housing and it stands square to the building. The turn used to be a swap of the box's
          // two plan dimensions, which is all a yaw can be for an axis-aligned emitter
          var yaw = (h % 2) * (Math.PI / 2);
          deck.hatch.push({
            x: c.x,
            z: c.z,
            yaw: yaw,
            y: FacilityStyle.ROOF_Y,
          });
          out.hatchOf.push(si);
          // the lid's own plan, lip included, and turned with the housing
          pool(deck.shade, c.x, c.z,
            FacilityStyle.HATCH_W / 2 + FacilityStyle.HATCH_LIP,
            FacilityStyle.HATCH_D / 2 + FacilityStyle.HATCH_LIP, yaw);
          out.hatches++;
          out.pools++;
        }
      // and the duct run leaving it. THE SERVICE BAY IS WHERE THE SHAFTS COME UP, so a lagged run
      // starts at the stair core and walks the ring band — which is also the one direction on a
      // roof that always has deck in it. Whichever of the four has the most band wins, capped at
      // ROOF_DUCT_MAX so a run cannot follow the band the whole way round the building, the fault
      // the cable trunking was reported for
      var duct:Array<{ col:Int, row:Int }> = [];
      var ddir = 0;
      if (core != null)
        {
          for (dir in 0...4)
            {
              var w = walk(m, si, core.col, core.row, dir, FacilityStyle.ROOF_DUCT_MAX);
              if (w.length > duct.length)
                {
                  duct = w;
                  ddir = dir;
                }
            }
          // DC is the COLUMN delta, so dirs 2 and 3 run along x — which is the axis the segment is
          // built along — and dirs 0 and 1 run along z and take the quarter turn
          var yaw = (DC[ddir] != 0 ? 0.0 : Math.PI / 2);
          for (cell in duct)
            {
              var c = CityConfig.cellToWorld(cell.col, cell.row);
              deck.duct.push({
                x: c.x,
                z: c.z,
                yaw: yaw,
                y: FacilityStyle.ROOF_Y,
              });
              out.ductOf.push(si);
              out.props.push({ col: cell.col, row: cell.row, kind: 'duct', structure: si });
              // a segment IS a cell long, so its shadow is too — the one pool up here that is not
              // square, and the only one that has to be turned with its prop
              pool(deck.shade, c.x, c.z, CELL / 2, FacilityStyle.ROOF_DUCT_PLAN_D / 2, yaw);
              out.ducts++;
              out.pools++;
            }
        }
      // the extract vents: every other cell the service bay holds. A vent caps a shaft and a shaft
      // comes up where the stair core does, so they cluster round the hatch rather than being dealt
      // over the deck — which is the difference between a service bay and a scatter
      for (cell in svc)
        {
          if (core != null &&
              cell.col == core.col &&
              cell.row == core.row)
            continue;
          var used = false;
          for (d in duct)
            if (d.col == cell.col &&
                d.row == cell.row)
              {
                used = true;
                break;
              }
          if (used)
            continue;
          var c = CityConfig.cellToWorld(cell.col, cell.row);
          var h = FacilityModel.mix((cell.col * 70001) ^ (cell.row * 30011));
          deck.vent.push({
            x: c.x,
            z: c.z,
            // a cowl IS round, so this is the one thing on a deck that takes a free turn: there is
            // no face on it a quarter turn could square up to
            yaw: (h >> 8) % 6283 / 1000.0,
            y: FacilityStyle.ROOF_Y,
          });
          out.ventOf.push(si);
          out.props.push({ col: cell.col, row: cell.row, kind: 'vent', structure: si });
          pool(deck.shade, c.x, c.z, FacilityStyle.ROOF_VENT_PLAN / 2,
            FacilityStyle.ROOF_VENT_PLAN / 2, 0.0);
          out.vents++;
          out.pools++;
        }
      // ONE dish per building, in the middle of its own bay. it is the roof's silhouette, and two of
      // them read as a repeated prop rather than as the thing this building has on it — which is
      // what `max: 1` on the demand says and what this loop no longer has to
      var dish = nearest(pad, centre(pad, true), centre(pad, false));
      if (dish != null)
        {
          var c = CityConfig.cellToWorld(dish.col, dish.row);
          var h = FacilityModel.mix((dish.col * 70001) ^ (dish.row * 30011));
          deck.dish.push({
            x: c.x,
            z: c.z,
            yaw: (h >> 8) % 6283 / 1000.0,
            y: FacilityStyle.ROOF_Y,
          });
          out.dishOf.push(si);
          out.props.push({ col: dish.col, row: dish.row, kind: 'dish', structure: si });
          pool(deck.shade, c.x, c.z, FacilityStyle.ROOF_DISH_PLAN / 2,
            FacilityStyle.ROOF_DISH_PLAN / 2, 0.0);
          out.pools++;
        }
      for (cell in plant)
        {
          var c = CityConfig.cellToWorld(cell.col, cell.row);
          var h = FacilityModel.mix((cell.col * 70001) ^ (cell.row * 30011));
          // ONE IN ROOF_TANK_PCT OF THE PLANT CELLS IS A VESSEL, and it is dealt here rather than
          // given a bay of its own on purpose: a plant bay with one expansion tank standing among
          // its condensers is a plant bay, and a bay full of tanks is a tank farm. It stays in
          // `plant` afterwards, so the trunking runs back to the same isolator box — which is what
          // a vessel with a trace-heating circuit on it actually has
          if (h % 100 < FacilityStyle.ROOF_TANK_PCT)
            {
              deck.tank.push({
                x: c.x,
                z: c.z,
                yaw: ((h >> 8) % 4) * (Math.PI / 2),
                y: FacilityStyle.ROOF_Y,
              });
              out.tankOf.push(si);
              out.props.push({ col: cell.col, row: cell.row, kind: 'tank', structure: si });
              pool(deck.shade, c.x, c.z, FacilityStyle.ROOF_TANK_PLAN / 2,
                FacilityStyle.ROOF_TANK_PLAN / 2, 0.0);
              out.tanks++;
              out.pools++;
              continue;
            }
          deck.ac.push({
            x: c.x,
            z: c.z,
            // a quarter turn and not a free one: a condenser is a manufactured box and stands
            // square to the building, exactly as the parked cars do
            yaw: ((h >> 8) % 4) * (Math.PI / 2),
            y: FacilityStyle.ROOF_Y,
          });
          out.acOf.push(si);
          out.props.push({ col: cell.col, row: cell.row, kind: 'ac', structure: si });
          pool(deck.shade, c.x, c.z, FacilityStyle.ROOF_AC_PLAN_W / 2,
            FacilityStyle.ROOF_AC_PLAN_D / 2, ((h >> 8) % 4) * (Math.PI / 2));
          out.pools++;
        }
      // and the service runs. THEY GO TO A BOX AND NOT TO EACH OTHER, which is the second half of
      // FacilityStyle.ROOF_CABLE_WAYS' own note. The tree that used to be here chained every
      // condenser to the nearest thing already fed and started at the hatch, so on the 21 x 30
      // building measured here the chain walked the ring band end to end — reported from the game
      // as the cables going all the way around, and they did.
      //
      // grouped by MANHATTAN distance and greedily, seed by seed: the first ungrouped unit claims
      // every ungrouped unit within ROOF_JBOX_REACH of ITSELF and not of the growing group, so a
      // group cannot creep across the deck one member at a time. `runs` then lays the group's whole
      // network as a shared trunk and a spur each, whatever the deck measures
      var left = plant.copy();
      while (left.length > 0)
        {
          var seed = left.shift();
          var grp = [ seed ];
          var i = 0;
          while (i < left.length)
            {
              if (Math.abs(left[i].col - seed.col) + Math.abs(left[i].row - seed.row) <=
                  FacilityStyle.ROOF_JBOX_REACH)
                grp.push(left.splice(i, 1)[0]);
              else
                i++;
            }
          var bx = 0.0, bz = 0.0;
          for (cell in grp)
            {
              var c = CityConfig.cellToWorld(cell.col, cell.row);
              bx += c.x / grp.length;
              bz += c.z / grp.length;
            }
          // a group of TWO OR MORE has its centroid between cells and so already stands clear of
          // every unit in it. A group of ONE has it dead inside its own condenser, so that box
          // steps most of a cell towards the middle of the deck — which is also the direction the
          // riser it is wired back to is in
          var mid = CityConfig.cellToWorld(Std.int((st.x1 + st.x2) / 2),
            Std.int((st.y1 + st.y2) / 2));
          if (grp.length == 1)
            {
              var dx = mid.x - bx, dz = mid.z - bz;
              var l = Math.sqrt(dx * dx + dz * dz);
              if (l > 0.01)
                {
                  bx += dx / l * CELL * 0.45;
                  bz += dz / l * CELL * 0.45;
                }
            }
          deck.jbox.push({
            x: bx,
            z: bz,
            // square to the building like the condensers it serves, and its DOOR turned toward the
            // middle of the deck, where the runs come from. the glb's door is its +y face, which
            // the yup export sends to -z, so yaw 0 faces -z and a half turn faces +z
            yaw: (mid.z > bz ? Math.PI : 0.0),
            y: FacilityStyle.ROOF_Y,
          });
          out.jboxOf.push(si);
          pool(deck.shade, bx, bz, FacilityStyle.ROOF_JBOX_W / 2, FacilityStyle.ROOF_JBOX_D / 2,
            0.0);
          out.boxes++;
          out.pools++;
          runs(deck.cab, grp, bx, bz);
          out.cables += grp.length;
        }
      // every cell something STANDS on, which is the clutter's only exclusion
      var taken = plant.copy();
      if (core != null)
        taken.push(core);
      if (dish != null)
        taken.push(dish);
      // the service kit stands on cells too: the duct's own, and the vents', which are every other
      // cell of the service bay
      for (c in duct)
        taken.push(c);
      for (c in svc)
        taken.push(c);
      out.clutter += clut(deck.pack, m, si, taken);
    }

// the deck's flat dressing: one pack64 cell per roof cell that nothing stands on.
//
// THE WHOLE DECK AND NOT THE RING BAND, which is the one thing up here that does not respect it. A
// tar patch in the middle of a bare roof is what a bare roof HAS; the band exists to keep OBJECTS
// off the middle, and every cell of this sheet is flat by construction (FacilityStyle
// .ROOF_CLUTTER_TEX). It is also the answer if the empty centre reads as a donut.
//
// `taken` is the hatch and the condensers — the cable tree's own list, which already holds both —
// and the test is the CELL and not a radius: a decal is 2.8 across in a 4.0 cell, so a neighbouring
// cell cannot reach under a prop. FacilityClutter's keep-clear machinery is for items sharing one
// worktop and there is nothing to share here
  static function clut(b:render.world.MeshBuf.MeshBuf, m:Facility, si:Int,
      taken:Array<{ col:Int, row:Int }>):Int
    {
      var st = m.structures[si];
      var n = 0;
      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            // depth 2 for the props' own reason: a 2.8 decal centred on a wall-ring cell would run
            // out over the coping, and the parapet stands on that ring
            if (depth(m, si, col, row) < 2)
              continue;
            var free = true;
            for (t in taken)
              if (t.col == col &&
                  t.row == row)
                {
                  free = false;
                  break;
                }
            if (!free)
              continue;
            var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            if (h % 100 >= FacilityStyle.ROOF_CLUTTER_PCT)
              continue;
            var c = CityConfig.cellToWorld(col, row);
            var sz = FacilityStyle.ROOF_CLUTTER_SZ +
              ((h >> 7) % 1000 / 1000.0 - 0.5) * 2 * FacilityStyle.ROOF_CLUTTER_SZ_VAR;
            flat(b, c.x, c.z, sz, (h >> 17) % 6283 / 1000.0,
              (h >> 3) % FacilityStyle.ROOF_CLUTTER_CELLS);
            n++;
          }
      return n;
    }

// one pack64 cell as a yawed quad lying on the deck. FacilityHangar.emit's arithmetic against this
// family's own sheet and at ROOF_Y — the fourth copy of those six lines, and copied for the reason
// that file's header gives: each differs only in the axis it lays the quad on
  static function flat(b:render.world.MeshBuf.MeshBuf, x:Float, z:Float, sz:Float, yaw:Float,
      idx:Int):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var t = FacilityStyle.ROOF_CLUTTER_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      var y = FacilityStyle.ROOF_Y + FacilityStyle.ROOF_CLUTTER_Y;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the dressing as one mesh per deck. FacilityHangar.add's material MINUS THE VISION MASK, which is
// this file's own standing rule (see the class header): the roof's visibility is decided by where
// the player stands and not by what the LOS sweep reached.
//
// IT POPS RATHER THAN FADING and that is deliberate. Pushed into Shell.roof it takes the deck's
// opacity, three tests `alphaTest` against map.a * OPACITY, and every fragment goes at once when the
// product crosses the cut — the trap render.facility.FacilityArea.ease records against the window
// panes. A cut at half the ease is exactly where `mask` already drops the condensers, so the whole
// of what stands on a roof leaves together instead of one family lingering
  static function pack(scene:Scene, b:render.world.MeshBuf.MeshBuf, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: render.Textures.loadTexture(FacilityStyle.ROOF_CLUTTER_TEX, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      });
      mat.transparent = true;
      mat.opacity = 1.0;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      shell.roof.push(mesh);
    }

// cut this roof up and deal the bays.
//
// IT REACHES INTO gen/ AND IT IS THE FIRST RENDER PASS THAT DOES, so here is why that is safe:
// gen.Subdivide and gen.Quota are pure arithmetic over an INJECTED rng — no GenCtx, no cell grid,
// no side effects — and the alternative was a second copy of the splitter that would drift from the
// one every city block in the game is laid with. Nothing goes the other way: gen/ still never sees
// render/.
//
// the seed is the structure's own corner and not `si`, because `si` is 0 and 1 in every compound
// ever generated and would lay the same two roofs everywhere. Nothing is persisted — the same
// compound re-entered cuts the same bays
  static function zones(m:Facility, si:Int, band:Array<{ col:Int, row:Int }>,
      out:Roof):Array<_GenNode>
    {
      var st = m.structures[si];
      // the DECK's rect and not the structure's: st.x1..x2 takes in the wall ring, and a bay dealt
      // over masonry is a bay whose band cells all belong to somebody else
      var x1 = st.x2, x2 = st.x1, y1 = st.y2, y2 = st.y1;
      for (row in st.y1...st.y2 + 1)
        for (col in st.x1...st.x2 + 1)
          {
            if (!owns(m, si, col, row))
              continue;
            if (col < x1)
              x1 = col;
            if (col > x2)
              x2 = col;
            if (row < y1)
              y1 = row;
            if (row > y2)
              y2 = row;
          }
      var rng = Rng.mulberry32(FacilityModel.mix((x1 * 70001) ^ (y1 * 30011) ^ si));
      // how much of the ring band a bay actually holds. EVERY demand hangs off this: a bay in the
      // middle of the deck holds none of it, so it can take no kind and falls through to BARE
      var held = function(b:_GenNode):Int
        {
          var n = 0;
          for (c in band)
            if (c.col >= b.x1 &&
                c.col <= b.x2 &&
                c.row >= b.y1 &&
                c.row <= b.y2)
              n++;
          return n;
        };
      var ds:Array<_GenDemand> = [
        {
          kind: SERVICE,
          min: 1,
          max: 1,
          minW: 1,
          minH: 1,
          must: function(b:_GenNode) return held(b) > 0,
        },
        {
          kind: DISH_PAD,
          // MIN 0, so a building whose bays are all small simply has no dish. it is the tallest
          // thing up here and wants deck around it, and a compound where both buildings carry one
          // is two of the same silhouette
          min: 0,
          max: 1,
          minW: FacilityStyle.ROOF_DISH_BAY,
          minH: FacilityStyle.ROOF_DISH_BAY,
          must: function(b:_GenNode) return held(b) > 0,
          fit: function(b:_GenNode) return held(b),
        },
        {
          kind: PLANT_BAY,
          min: 1,
          max: FacilityStyle.ROOF_PLANT_BAYS,
          minW: 1,
          minH: 1,
          must: function(b:_GenNode) return held(b) > 0,
        },
      ];
      var zs = Quota.deal(Subdivide.split(x1, y1, x2, y2, SPLIT, rng), ds, BARE, rng);
      for (z in zs)
        out.zones.push({
          structure: si,
          kind: z.kind,
          x1: z.x1,
          y1: z.y1,
          x2: z.x2,
          y2: z.y2,
          band: held(z),
        });
      return zs;
    }

// which bay this cell fell in, or null for the lane between two of them
  static function zoneAt(zs:Array<_GenNode>, col:Int, row:Int):_GenNode
    {
      for (z in zs)
        if (col >= z.x1 &&
            col <= z.x2 &&
            row >= z.y1 &&
            row <= z.y2)
          return z;
      return null;
    }

// the cell of a list nearest a point, or null when the list is empty
  static function nearest(cells:Array<{ col:Int, row:Int }>, cx:Float,
      cy:Float):{ col:Int, row:Int }
    {
      var out = null;
      var best = 1e9;
      for (c in cells)
        {
          var dx = c.col - cx;
          var dy = c.row - cy;
          if (dx * dx + dy * dy < best)
            {
              best = dx * dx + dy * dy;
              out = c;
            }
        }
      return out;
    }

// a cell list's mean column or row. what `nearest` is aimed at when the target is the list's OWN
// middle rather than the roof's — a dish stands in the middle of its bay
  static function centre(cells:Array<{ col:Int, row:Int }>, col:Bool):Float
    {
      if (cells.length == 0)
        return 0.0;
      var t = 0.0;
      for (c in cells)
        t += (col ? c.col : c.row);
      return t / cells.length;
    }

// the cells of this structure's roof something may stand on: interior floor lying in the RING BAND —
// between 2 and ROOF_RING_INSET cells in from the wall ring — thinned to one cell in
// ROOF_PROP_STEP.
//
// the floor of 2 is what keeps everything clear of the parapet, so nothing can foul it standing on
// the ring, and it means a prop is always over solid deck rather than over the rim. the ceiling is
// what empties the middle: see FacilityStyle.ROOF_RING_INSET, which is a decision against the
// measurement and says so
  static function candidates(m:Facility, si:Int):Array<{ col:Int, row:Int }>
    {
      var st = m.structures[si];
      var out = [];
      for (row in st.y1...st.y2 + 1)
        for (col in st.x1...st.x2 + 1)
          {
            if (!owns(m, si, col, row) ||
                (col * 3 + row) % FacilityStyle.ROOF_PROP_STEP != 0)
              continue;
            var d = depth(m, si, col, row);
            if (d >= 2 &&
                d <= FacilityStyle.ROOF_RING_INSET)
              out.push({ col: col, row: row });
          }
      return out;
    }

// a straight run of deck out of one cell: up to `n` further cells that are still this structure's
// own deck and still inside the ring band, stopping at the first that is not.
//
// it is what a DUCT is laid on and nothing else uses it, because nothing else up here is longer
// than a cell. The band test is the same one `candidates` makes and deliberately so — a segment
// hanging over the coping is the fault the floor of 2 exists to prevent
  static function walk(m:Facility, si:Int, col:Int, row:Int, dir:Int,
      n:Int):Array<{ col:Int, row:Int }>
    {
      var out = [];
      for (k in 1...n + 1)
        {
          var c = col + DC[dir] * k;
          var r = row + DR[dir] * k;
          if (!owns(m, si, c, r))
            break;
          var d = depth(m, si, c, r);
          if (d < 2 ||
              d > FacilityStyle.ROOF_RING_INSET)
            break;
          out.push({ col: c, row: r });
        }
      return out;
    }

// how far in from the wall ring this cell lies: the steps to the first cell that is NOT this
// structure's own deck, over the four axis directions, smallest wins. 1 is a cell against the wall.
//
// the scan stops one past the band, so this is O(ROOF_RING_INSET) and not O(the roof) — the answer
// past the band is only ever "deeper than the band", and the caller has no other question
  static function depth(m:Facility, si:Int, col:Int, row:Int):Int
    {
      var best = FacilityStyle.ROOF_RING_INSET + 1;
      for (dir in 0...4)
        {
          var n = 1;
          while (n < best &&
                 owns(m, si, col + DC[dir] * n, row + DR[dir] * n))
            n++;
          if (n < best)
            best = n;
        }
      return best;
    }

// is this cell part of this structure's DECK — its floor, its interior partitions and its wall ring
// alike? FacilityModel.findStructures claims all three for the component it encloses.
//
// IT USED TO ASK FOR INDOOR FLOOR AND THAT WAS THE WRONG QUESTION, because `depth` then measured to
// the nearest PARTITION and not to the parapet: a lab building's rooms are 4 to 6 cells across, so
// every cell of it came out 1 or 2 from a wall and the ring band was the whole roof. Measured with
// the band lifted: 49 candidate cells against 47 inside a 3-cell band, i.e. the test excluded two.
// The deck is one continuous slab over the whole footprint and nothing up here stands on a floor
  static inline function owns(m:Facility, si:Int, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.owner[row][col] == si;
    }

// one straight run of trunking: an up-facing quad at the deck's cable height, the art's u ACROSS
// the ribbon and v along it, which is FacilityCable.strip's own convention and the reason a flat
// strip reads as round at all (see FacilityStyle.CABLE_TEX).
//
// the quads are wound like FacilityGeom.cap's, off the LOW end, so neither axis can come out facing
// down — the failure a whole axis of faces disappearing hides
  static function leg(b:render.world.MeshBuf.MeshBuf, s:Seg):Void
    {
      var hw = FacilityStyle.CABLE_W / 2;
      var v = (s.a1 - s.a0) / FacilityStyle.CABLE_TILE;
      if (s.ax == 0)
        MeshBufTools.quad(b, [ s.a0, s.y, s.line + hw ], [ s.a1, s.y, s.line + hw ],
          [ s.a1, s.y, s.line - hw ], [ s.a0, s.y, s.line - hw ],
          [ 0.0, 0.0, 0.0, v, 1.0, v, 1.0, 0.0 ]);
      else
        MeshBufTools.quad(b, [ s.line - hw, s.y, s.a1 ], [ s.line + hw, s.y, s.a1 ],
          [ s.line + hw, s.y, s.a0 ], [ s.line - hw, s.y, s.a0 ],
          [ 0.0, v, 1.0, v, 1.0, 0.0, 0.0, 0.0 ]);
    }

// one segment into the list, MERGED with everything already on its line.
//
// a UNION and not a push: two condensers in one group can share a row, and then both of their spurs
// run along it to the same trunk and the shorter one lies entirely inside the longer. Merged, the
// nearer unit simply taps the run passing it, which is what it would really be wired to.
//
// IT ABSORBS EVERY MATCH AND NOT THE FIRST, because three spurs on one row can arrive as two
// disjoint runs and then a third that bridges them — merged into the first alone, the bridge would
// be left lying over the second
  static function seg(segs:Array<Seg>, s:Seg):Void
    {
      if (s.a1 - s.a0 < 0.01)
        return;
      var i = segs.length;
      while (i-- > 0)
        {
          var t = segs[i];
          if (t.ax != s.ax ||
              Math.abs(t.line - s.line) > 0.001 ||
              Math.abs(t.y - s.y) > 0.001 ||
              s.a0 > t.a1 + 0.001 ||
              s.a1 < t.a0 - 0.001)
            continue;
          if (t.a0 < s.a0)
            s.a0 = t.a0;
          if (t.a1 > s.a1)
            s.a1 = t.a1;
          segs.splice(i, 1);
        }
      segs.push(s);
    }

// one group of condensers wired back to its isolator box: a TRUNK per way and a spur per unit into
// it, and nothing drawn twice.
//
// WHAT THIS REPLACES WAS AN L PER UNIT, and two L-routes to one box share their second leg exactly:
// every condenser in a group laid the same quad along x = bx + o, and each L also covered its own
// corner square twice. Measured on this compound's 88 roof cable quads before the change, 84
// overlapping pairs over 1.67 square units — reported from the game as a z-fight on all three ways,
// and two coplanar quads at one y is not a near miss, it is the same plane.
//
// three things together make it exact. the trunk is emitted ONCE per way; a spur STOPS half a cable
// short of the trunk's centre line, so the joint closes on the trunk's own width instead of
// overlapping it; and any two spurs that do land on one line are merged into their union. What is
// left is a spur crossing ANOTHER way's trunk, which no clipping can remove because the ways are
// parallel — so each way lies one ROOF_CABLE_LAY higher than the last and a crossing is a crossing
  static function runs(b:render.world.MeshBuf.MeshBuf, grp:Array<{ col:Int, row:Int }>,
      bx:Float, bz:Float):Void
    {
      var hw = FacilityStyle.CABLE_W / 2;
      var segs:Array<Seg> = [];
      for (k in 0...FacilityStyle.ROOF_CABLE_WAYS)
        {
          var o = (k - (FacilityStyle.ROOF_CABLE_WAYS - 1) / 2.0) *
            FacilityStyle.ROOF_CABLE_PITCH;
          var y = FacilityStyle.ROOF_Y + FacilityStyle.ROOF_CABLE_Y +
            k * FacilityStyle.ROOF_CABLE_LAY;
          var tx = bx + o;
          // the trunk spans the box and every unit's own row, so a group straddling the box in z
          // takes ONE run through it rather than one out of each side
          var z0 = bz, z1 = bz;
          for (cell in grp)
            {
              var c = CityConfig.cellToWorld(cell.col, cell.row);
              var cz = c.z + o;
              if (cz < z0)
                z0 = cz;
              if (cz > z1)
                z1 = cz;
              // the spur, from inside the condenser to the trunk's near edge. both ends land INSIDE
              // what they serve — a 0.19 offset against a 1.77-deep unit and a 0.75-wide box — so
              // no way stops in the air
              seg(segs, {
                ax: 0,
                line: cz,
                a0: (c.x < tx ? c.x : tx + hw),
                a1: (c.x < tx ? tx - hw : c.x),
                y: y,
              });
            }
          seg(segs, {
            ax: 1,
            line: tx,
            a0: z0,
            a1: z1,
            y: y,
          });
        }
      for (s in segs)
        leg(b, s);
    }

// one thing standing on the deck, planted with a contact shadow: FacilityDetail.pooled's quad, laid
// on the roof instead of on a shelf plate.
//
// SIMPLER THAN THAT ONE BY EXACTLY ITS CLAMP. A pool on a plate has to be cut where the plate ends,
// because a gradient hanging off a shelf draws on air; a roof deck is one continuous slab and every
// candidate cell is two cells inside the parapet (see `clut`), so a quad grown by POOL_GROW of a
// 2.78 footprint cannot reach the edge of it. Nothing here needs the rect the other one takes.
//
// the yaw is the prop's own, so a quarter-turned condenser's shadow turns with it
  static function pool(b:render.world.MeshBuf.MeshBuf, x:Float, z:Float, hw:Float, hd:Float,
      yaw:Float):Void
    {
      var rw = hw * (1 + FacilityStyle.POOL_GROW);
      var rd = hd * (1 + FacilityStyle.POOL_GROW);
      var c = Math.cos(yaw), sn = Math.sin(yaw);
      var y = FacilityStyle.ROOF_Y + FacilityStyle.ROOF_POOL_Y;
      var lx = [ -rw, rw, rw, -rw ];
      var lz = [ rd, rd, -rd, -rd ];
      var uv = [ 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0 ];
      var pt = [];
      for (i in 0...4)
        pt.push([ x + lx[i] * c + lz[i] * sn, y, z - lx[i] * sn + lz[i] * c ]);
      MeshBufTools.quad(b, pt[0], pt[1], pt[2], pt[3], uv);
    }

// every contact shadow on one deck as ONE mesh, in the ramp FacilityDetail draws its own with.
//
// THE WEIGHT IS IN THE RAMP AND NOT ON THE MATERIAL, which is the one thing this cannot share with
// that file: the mesh goes into Shell.roof so a shadow leaves with the deck it lies on, and
// FacilityArea.apply SETS material.opacity from the deck's ease every frame — a 0.5 left on the
// material would be overwritten with 1.0 the first frame the player is outside
  static function shade(scene:Scene, b:render.world.MeshBuf.MeshBuf, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var mat:Dynamic = new MeshBasicMaterial({
        color: 0x000000,
        alphaMap: render.Textures.makeRectGlowGradient(0.0, FacilityStyle.HALO_CORE / 2,
          FacilityStyle.HALO_FADE, FacilityStyle.ROOF_POOL_ALPHA),
        depthWrite: false,
        side: THREE.FrontSide,
      });
      mat.transparent = true;
      mat.opacity = 1.0;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.castShadow = false;
      mesh.receiveShadow = false;
      scene.add(mesh);
      shell.roof.push(mesh);
    }

// the hangar's roof: a barrel vault of ribbed sheet metal arching between its two long walls. its
// section is `section` below, and the crescent closing each end is `crescents`, which is CLADDING
// and belongs to the walls rather than to this.
//
// it goes in the FADING buffer, so walking in opens the shed exactly as walking into a lab building
// opens its deck. nothing in FacilityArea.ease has to be told: it eases whatever Shell.roof holds
  static function vault(scene:Scene, m:Facility, si:Int, shell:Shell):Vault
    {
      var s = section(m, si);
      var n = FacilityStyle.HANGAR_ARC_SEG;
      var t = FacilityStyle.HANGAR_ROOF_TILE;
      var b = MeshBufTools.make();
      // the one place that knows which world axis is the ridge and which is the arc
      var put = function(along:Float, y:Float, cross:Float, u:Float, v:Float):Void
        {
          MeshBufTools.vtx(b, (s.alongX ? along : cross), y, (s.alongX ? cross : along), u, v);
        };
      // the vault as a SHARED-VERTEX grid rather than as n loose quads. MeshBufTools.quad pushes
      // four fresh vertices every call and FacilityGeom.geom derives normals with
      // computeVertexNormals, so loose quads shade FLAT — and a faceted barrel is the one failure a
      // curve cannot survive, its whole read being that it is smooth. sharing the columns makes
      // each seam average to the radial normal for free
      for (i in 0...n + 1)
        {
          // v runs on ARC LENGTH and not on the chord projection, which is the whole of "never
          // stretch" on a curve: projected, the ribs would crowd together toward both springings
          var v = (2 * s.theta * i / n) * s.r / t;
          put(s.a0, s.ys[i], s.cs[i], s.a0 / t, v);
          put(s.a1, s.ys[i], s.cs[i], s.a1 / t, v);
        }
      for (i in 0...n)
        {
          var k = 2 * i;
          tri(b, k, k + 1, k + 3);
          tri(b, k, k + 3, k + 2);
        }
      FacilityGeom.addDeck(scene, b, FacilityStyle.ROOF_HANGAR, true, shell);
      return {
        structure: si,
        span: s.span,
        rise: s.rise,
        radius: s.r,
        arcDeg: 2 * s.theta * 180 / Math.PI,
        seg: n,
        quads: n,
        gables: 2 * n,
        ridgeAlongX: s.alongX,
        ridge: Math.abs(s.a1 - s.a0),
      };
    }

// the crescent of masonry closing each end of the vault, between the wall head and the arch.
//
// IT IS NOT ROOFING AND IT IS NOT IN THE ROOF BUFFER. a gable end is the wall carrying on upward, so
// it goes into the structure's OWN wOut buffer at the caller's hand — same cladding, same mesh, same
// world-aligned WALL_TILE course as the masonry it stands on, so it continues the wall's texture
// exactly rather than butting a second material against it, and it costs no draw call. it also then
// STAYS when the player walks in, which is what the parapet ring one building over already does:
// walls do not fade, only the lid over your head does.
//
// loose quads on purpose, unlike the arch: a crescent is PLANAR, so there is no curvature for a
// shared-vertex grid to smooth
  public static function crescents(m:Facility, si:Int, b:render.world.MeshBuf.MeshBuf):Void
    {
      var s = section(m, si);
      var n = FacilityStyle.HANGAR_ARC_SEG;
      var t = FacilityStyle.WALL_TILE;
      var pt = function(along:Float, y:Float, cross:Float):Array<Float>
        {
          return (s.alongX ? [along, y, cross] : [cross, y, along]);
        };
      for (end in 0...2)
        {
          var a = (end == 0 ? s.a0 : s.a1);
          for (i in 0...n)
            {
              var q0 = pt(a, FacilityStyle.ROOF_Y, s.cs[i]);
              var q1 = pt(a, s.ys[i], s.cs[i]);
              var q2 = pt(a, s.ys[i + 1], s.cs[i + 1]);
              var q3 = pt(a, FacilityStyle.ROOF_Y, s.cs[i + 1]);
              // u on the CROSS axis and v on y, both over WALL_TILE — FacilityGeom.face's own
              // mapping for a wall running this way, which is what makes the join invisible
              var u0 = s.cs[i] / t, u1 = s.cs[i + 1] / t;
              var w = FacilityStyle.ROOF_Y / t;
              // wound to look OUT along the ridge, so the far end takes the cycle backwards
              if (end == 0)
                MeshBufTools.quad(b, q0, q1, q2, q3,
                  [u0, w, u0, s.ys[i] / t, u1, s.ys[i + 1] / t, u1, w]);
              else
                MeshBufTools.quad(b, q3, q2, q1, q0,
                  [u1, w, u1, s.ys[i + 1] / t, u0, s.ys[i] / t, u0, w]);
            }
        }
    }

// the arch's section, from the structure's own wall ring and the two constants and nothing else.
//
// THE SECTION IS A CIRCULAR SEGMENT: for a chord S and a segment height H the tangent-chord angle
// gives tan(theta / 2) = H / (S / 2), so theta = 2 * atan(2H / S) is HALF the subtended angle,
// R = (S / 2) / sin(theta), and the centre sits at ROOF_Y + H - R, well below the springing
  public static function section(m:Facility, si:Int):Arc
    {
      var r0 = ring(m, si);
      // the ridge takes the LONGER span and the arc crosses the shorter one, which is
      // render.world.roofs.Gables' rule for a pitched roof. it is also what puts the arch over the
      // DOORS: game.FacilityAreaGenerator.generateHangar draws its shutter row across the short wall
      var alongX = (r0.x1 - r0.x0) >= (r0.z1 - r0.z0);
      var a0 = (alongX ? r0.x0 : r0.z0), a1 = (alongX ? r0.x1 : r0.z1);
      var c0 = (alongX ? r0.z0 : r0.x0), c1 = (alongX ? r0.z1 : r0.x1);
      var span = c1 - c0;
      var cc = (c0 + c1) / 2;
      var rise = Math.min(span * FacilityStyle.HANGAR_RISE_FRAC, FacilityStyle.HANGAR_RISE_MAX);
      var theta = 2 * Math.atan(2 * rise / span);
      var r = (span / 2) / Math.sin(theta);
      var cy = FacilityStyle.ROOF_Y + rise - r;
      var n = FacilityStyle.HANGAR_ARC_SEG;
      // WHICH WAY THE ARC IS WALKED IS NOT COSMETIC. the two orientations map (along, cross) onto
      // (x, z) with opposite handedness, so one winding rule would emit an upward-facing vault for
      // one and a downward-facing — i.e. INVISIBLE, `addDeck` being FrontSide — one for the other.
      // walking the arc backwards when the ridge runs along x cancels that, so the winding at both
      // call sites is written once. cos is even, so the heights are untouched by the sign
      var sgn = (alongX ? -1.0 : 1.0);
      var cs = [], ys = [];
      for (i in 0...n + 1)
        {
          var phi = sgn * (2 * theta * i / n - theta);
          cs.push(cc + r * Math.sin(phi));
          ys.push(cy + r * Math.cos(phi));
        }
      return {
        alongX: alongX,
        a0: a0,
        a1: a1,
        cs: cs,
        ys: ys,
        span: span,
        rise: rise,
        r: r,
        theta: theta,
      };
    }

// the structure's WALL RING as a world rect, pulled in to the OUTER MASONRY PLANE — the same plane
// the lab buildings' parapets stand on, so the compound has one roofline rule and the vault springs
// exactly where a coping would have sat.
//
// it is measured off the cells this structure OWNS and NOT off st.ox1..ox2, which is the flood
// fill's own bbox grown by one cell and is wrong the moment a doorway sits in the ring. a door cell
// finalises to plain corridor lino, so isIndoor calls it indoors and the fill's bbox ALREADY reaches
// into the masonry there; growing that by another cell puts the box a whole cell outside the wall on
// that side alone. measured on the generated compound: the hangar's own side door at col 44 took
// ox1 to 43 and the vault overhung its west gable by exactly one cell, 4 world units, with the other
// three sides landing correctly — which is what an asymmetric error looks like from the game camera
  static function ring(m:Facility, si:Int):{ x0:Float, x1:Float, z0:Float, z1:Float }
    {
      var st = m.structures[si];
      var c0 = st.ox2, c1 = st.ox1, r0 = st.oy2, r1 = st.oy1;
      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            if (col < c0)
              c0 = col;
            if (col > c1)
              c1 = col;
            if (row < r0)
              r0 = row;
            if (row > r1)
              r1 = row;
          }
      var half = (CityConfig.GRID * CELL) / 2;
      var e = FacilityStyle.PARAPET_INSET;
      return {
        x0: c0 * CELL - half + e,
        x1: (c1 + 1) * CELL - half - e,
        z0: r0 * CELL - half + e,
        z1: (r1 + 1) * CELL - half - e,
      };
    }

// three indices straight into a buffer's own vertex list, for geometry built as a shared grid rather
// than as loose quads — MeshBufTools has no emitter for that, every other surface in the game being
// flat enough not to want one
  static inline function tri(b:render.world.MeshBuf.MeshBuf, i0:Int, i1:Int, i2:Int):Void
    {
      b.idx.push(i0);
      b.idx.push(i1);
      b.idx.push(i2);
    }

// which instances may draw this frame: an instance goes when the deck it stands on has faded far
// enough that it would be left hanging in the air.
//
// a hard cut and not a fade — the roof takes REVEAL_MULT * BASE_MS to go, so a prop pops partway
// through it. cross-fading an InstancedMesh needs a per-instance alpha attribute and its own shader
// patch, which is a lot of machinery for a prop the player is walking under at the time
// (ponytail: add it if the pop reads badly)
  public static function mask(of:Array<Int>, reveal:Array<Float>):Array<Bool>
    {
      return [for (si in of) reveal[si] < 0.5];
    }
}

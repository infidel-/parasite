package render.corp;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.facility.FacilityDetail;
import render.facility.FacilityDoors;
import render.facility.FacilityDoors.DoorBatch;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.facility.FacilityScene;
import render.facility.FacilityStyle;
import render.world.ContactMask;
import render.world.IndoorMask;
import render.world.VisionMask;
import render.world.WorldCtx;

// the corp tower area kind (AREA_CORP): one floor plate, twenty storeys up. it is the facility's
// INDOOR half with the outdoor half deleted — no lot, no lawn, no gate, no roof deck — so it owns
// almost no geometry of its own and instead drives render.facility's emitters off a ShellTex that
// names corp art (render.corp.CorpStyle.shell).
//
// what differs from a compound, and why each one follows from "the player is always inside":
//   - NO ROOF. FacilityGeom's flat deck is gated off for kind 'corp' — a ceiling over a plate the
//     player never leaves is permanently faded, i.e. dead geometry in the sorted pass.
//   - NO REVEAL EASE. there is one structure and the player is in it, so `inside` is pinned at 1
//     at build and the glazing tint never moves. nothing to ease, so no per-frame ease pass.
//   - NO OCCLUSION and no buildings list, exactly as the compound.
//
// phase 2 of the 2D -> 3D port: shell, doors, object props, masks. the furniture, the props, the
// lighting rig and the street below come in later phases and are each one more line in `build`
class CorpArea implements Area3D
{
  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var lampLights:LampLights;
  var coneGroup:Object3D;
  var lampCorners:Map<Int,Int>;
  var shells:Array<Shell>;
  var doors:Array<DoorBatch>;
  var fit:CorpFurniture.CorpFit;                // what the furniture pass emitted, for __corp()
  var glb:Array<render.Models.InstancedProp>;   // the seven prop batches, culled on one radius
  var glbN:CorpProps.CorpPropSet;               // and what went into them, for __corp()
  var lamps:CorpLamps.CorpLampSet;              // the fixtures and everything additive they throw
  var clutter = 0;                              // flat decals on the worktops, one mesh per sheet
  var signs = 0;                                // wall signage, one mesh
  var facade:{ clad:Int, soffit:Int, lit:Int }; // the nineteen storeys under the plate
  var street:CorpStreet.CorpStreetSet;          // and the city at the bottom of them
  var crowd:CorpCrowd;                          // and the fake traffic and people on it
  var props:Array<render.world.ObjModels.PropBatch>;
  var built:Scene;
  var tactical = false;

  public function new(game:Game, model:Facility)
    {
      this.game = game;
      this.model = model;
    }

// the compound's rig with the tower's sky and its much tighter fog — see CorpStyle.FOG_NEAR
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = FacilityScene.build(renderer, lampPool,
        CorpStyle.SKY, CorpStyle.FOG_NEAR, CorpStyle.FOG_FAR);
      lampLights = bundle.lampLights;
      coneGroup = bundle.coneGroup;
      lampCorners = bundle.lampCorners;
      return bundle;
    }

// the floor plate's shell, its doors and its object props
  public function build(scene:Scene):Void
    {
      // a plate is flat, so the relief hook answers the FURNITURE and nothing else, and climbArc is
      // CLEARED rather than left:
      // the kind that sets one owns clearing it, or the next area inherits the wilderness's height
      // field and its guard rails (WorldCtx). the two that are set are the two a tower shares with
      // a compound — masonry that carries objects, and masonry that does not fill its cell
      WorldCtx.tiles = null;
      // and the ONE hook a tower does need: a decoration is written onto the same cell as the
      // worktop tile it belongs to, so without this every monitor and mug on the plate sits at
      // y = 0 with three quarters of a metre of carcass in front of it
      WorldCtx.ground = function(x, z) return CorpFurniture.groundY(model, x, z);
      WorldCtx.climbArc = null;
      WorldCtx.wallMounts = function(col, row) return FacilityGeom.wallMounts(model, col, row);
      // masonry is a slab CENTRED in its cell and not the cell itself, so a decal laid on the cell
      // boundary hangs a whole unit off the wall
      WorldCtx.wallFace = function(col, row, dir) return FacilityGeom.wallFace(model, col, row, dir);
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // both masks go BEFORE the builders and not after: each reads `on` at MATERIAL-CREATION time
      // to decide whether to compile its swap into a surface at all, and every material this kind
      // owns is created by FacilityGeom.build three lines down
      IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
        function(col, row) return FacilityModel.isInterior(model, col, row));
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      render.world.PropEnv.attach(FacilityStyle.PROP_ENV);
      var pre = scene.children.copy();
      built = scene;
      shells = FacilityGeom.build(scene, model);
      // the fittings, after the shell they stand in and BEFORE the contact repaint below — a
      // prop's footprint is not known until its builder has run, and the attach above had to come
      // first because ContactMask.patch reads `on` when a floor material is created
      fit = CorpFurniture.build(scene, model, game.area);
      // and the glb props ON that furniture and against the walls round it. AFTER the fittings
      // because a chair's seat cell and a printer's wall are both read off the same grid the
      // fittings were emitted from, and BEFORE the contact repaint below because every one of
      // them lays its own footprint into the field
      var gp = CorpProps.build(scene, model, game.area);
      glb = gp.batches;
      glbN = gp.n;
      // the flat dressing: what lies ON the worktops, and what hangs on the walls. both AFTER the
      // props, because the clutter scatters around the workstation's own footprint and asks
      // CorpProps for it
      clutter = CorpClutter.build(scene, model);
      signs = CorpSigns.build(scene, model);
      // the rig, after every family that could stand under a lattice point — the nudge in
      // CorpLamps.free reads m.fit, so it has to know what is standing there
      lamps = CorpLamps.build(scene, model);
      // and the tower the plate is the twentieth floor OF. it is outside every mask on purpose —
      // see CorpFacade's header — so it goes in after them and takes none of their patches
      facade = CorpFacade.build(scene, model);
      // and the city at the bottom of it. LAST of the builders and OUTSIDE the chunk set below,
      // which is deliberate both ways: it is the one thing here that must take no mask (see
      // CorpStreet's header), and it is one Group of four area-spanning meshes, which is exactly
      // what render.Chunks' own size guard would leave parented to the scene anyway
      var pb = plateBox();
      street = CorpStreet.build(scene, game.area.id, pb);
      // into the street's OWN group, so the crowd rides the same transform down to STREET_Y
      crowd = new CorpCrowd(street.group, street.city, pb);
      // the inside-corner strips, which are the one piece of FacilityDetail a bare shell wants:
      // without them every reentrant corner of the plate shows the seam between two wall slabs
      FacilityDetail.corners(scene, model);
      // the glazing is pinned OPEN rather than eased. see the class header: one structure, and the
      // player is standing in it from the first frame
      for (s in shells)
        s.glaze.value = 1.0;
      // one canvas, one upload, no material touched — the whole reason the contact field is a
      // field and not a quad per fitting
      ContactMask.repaint();
      doors = FacilityDoors.build(scene, model, game.area);
      props = render.world.ObjModels.build(scene, game, objYaw, objLift);
      chunks.build(scene, pre);
      // the same pair of predicates the compound passes: a blocker is masonry that is not glazed,
      // and `carries` is what slab() insets against, so the reveal pulls back off exactly the floor
      // the masonry left open
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return FacilityModel.isWall(model, col, row) &&
          model.wall[row][col] != Wall.WINDOW,
        function(col, row) return FacilityGeom.carries(model, col, row));
      attachDbg();
    }

// the floor plate's own footprint in world, and how far past it the street reaches.
//
// NOT THE WORLD ORIGIN, which is the one thing about this that is not obvious: a corp area is
// 65-75 by 50-60 cells and CityConfig.cellToWorld is written against a GRID of 100, so the plate
// sits off in the -x/-z quadrant. Everything below it has to be placed against THIS.
//
// the box is the structure's OUTER rect (ox1..oy2, the interior grown by the wall ring), because
// what the street has to keep clear of is the masonry and not the carpet. The reach is half the
// AREA on each hand — the eight half-areas the street is built over
  function plateBox():render.corp.CorpStreet.PlateBox
    {
      var c0 = CityConfig.cellToWorld(0, 0);
      var x1 = model.w - 1;
      var z1 = model.h - 1;
      if (model.structures.length > 0)
        {
          var st = model.structures[0];
          c0 = CityConfig.cellToWorld(st.ox1, st.oy1);
          x1 = st.ox2;
          z1 = st.oy2;
        }
      var c1 = CityConfig.cellToWorld(x1, z1);
      var cell = CityConfig.CELL;
      return {
        // cellToWorld hands back a cell CENTRE, and the footprint is its two outer boundaries
        x0: c0.x - cell / 2,
        x1: c1.x + cell / 2,
        z0: c0.z - cell / 2,
        z1: c1.z + cell / 2,
        reachX: model.w * cell * CorpStyle.STREET_REACH_FRAC,
        reachZ: model.h * cell * CorpStyle.STREET_REACH_FRAC,
      };
    }

// console debug helper (permanent) — what this corp tower actually built.
//   __corp() -> { plate, rooms, windows, doors, objProps, parapet, shadows }
//
// the same reasoning render.facility.FacilityArea's __facility carries, and it applies harder here
// because a tower owns FEWER instanced batches and more merged geometry: an instanced batch has no
// userData.cls so render.Debug.find cannot reach a door leaf, parasiteHx is statics-only so the
// Facility record is unreachable from JS, and every question this kind raises — did the plate come
// back as ONE structure, did the lift core resolve, did every window run come back whole, is a
// room's role the one its floor tile says — has a numeric answer a screenshot cannot give
  function attachDbg():Void
    {
      untyped js.Browser.window.__corp = function()
        {
          // the plate, which should always be exactly one. TWO means the flood fill found the lift
          // core as a structure of its own, i.e. the wall ring round it closed
          var plate = [];
          for (i in 0...model.structures.length)
            {
              var st = model.structures[i];
              plate.push({
                x1: st.x1,
                y1: st.y1,
                x2: st.x2,
                y2: st.y2,
                cells: st.cells,
                // a tower plate is never a hangar (CorpStyle.shell passes hangars false), so a true
                // here is that gate having come undone rather than a shed on the 20th floor
                hangar: st.hangar,
                paraCells: shells[i].paraCells,
                paraQuads: shells[i].paraQuads,
              });
            }
          // every opening with its LIVE state beside its geometry, exactly as the compound's: a
          // screenshot cannot tell a leaf hinged on the wrong jamb from one swinging the wrong way
          var leaves = [];
          for (b in doors)
            for (c in 0...b.open.length)
              leaves.push({
                col: b.cells[c].col,
                row: b.cells[c].row,
                look: b.cells[c].look,
                alongX: b.cells[c].alongX,
                inDir: b.cells[c].inDir,
                live: (b.doors[c] != null),
                isOpen: (b.doors[c] != null && b.doors[c].isOpen),
                t: b.open[c],
              });
          var objProps = [];
          for (b in props)
            objProps.push({
              path: b.model.path,
              count: b.solid.matrices.length,
              cells: b.cells,
            });
          // and how many cells of each interior SURFACE the model read out of the grid. it is the
          // one readout that checks CorpModel.surfOf against the generator rather than against the
          // art: a role dealt by gen.blocks.CorpBlocks that never reaches a Surf here is a floor id
          // the map does not know, and it renders as bare carpet with nothing to say it went wrong
          var surfs = new Map<Int,Int>();
          for (row in 0...model.h)
            for (col in 0...model.w)
              {
                var s = (model.surf[row][col] : Int);
                surfs.set(s, (surfs.exists(s) ? surfs.get(s) : 0) + 1);
              }
          var bySurf = [for (k in surfs.keys()) { surf: k, cells: surfs.get(k) }];
          return {
            plate: plate,
            rooms: model.rooms,
            windows: model.windows,
            doors: leaves,
            objProps: objProps,
            // the glb families. `monitors` counts WORKSTATIONS and not screens, so keyboards
            // should match it exactly; `chairs` is every manned desk cell and is therefore always
            // the larger of the two (CorpStyle.WORK_EVERY thins the workstation, never the seat)
            glb: glbN,
            // the two flat families, which are merged meshes and so have no instance count
            // anywhere — these two numbers are the only handle on either
            clutter: clutter,
            signs: signs,
            // the rig. `posts` is how many fixtures COMPETE for the shared 12 spotlight slots and
            // never how many are lit — LampLights hands the bulbs to the nearest twelve every
            // frame, so a plate with 40 posts is correct and a plate with 0 is the phase-2 bug
            facade: facade,
            // the street. `blocks` is buildings BUILT and not generated — the radius filter is
            // most of the LOD, so the gap between this and city.buildings.length is the saving
            street: {
              road: street.road,
              walk: street.walk,
              blocks: street.blocks,
              walls: street.walls,
              lit: street.lit,
              generated: street.city.buildings.length,
            },
            // and what is moving on it. `walkLanes`/`roadLanes` is what the agents are dealt over,
            // so a zero there means the radius filter cut every straight run and the street is
            // dead rather than merely empty
            crowd: crowd.n,
            lamps: {
              posts: lamps.posts.length,
              rooms: lamps.rooms,
              panels: lamps.panels,
              pools: lamps.pools,
              calls: lamps.calls,
            },
            glbBatches: [for (b in glb) (b.mesh == null ? 0 : b.matrices.length)],
            surfs: bySurf,
            // and the FURNITURE, which is eight families over nine merged meshes and therefore has
            // no instance count anywhere — the same blindness __facility() records for every one of
            // its emitted families. `desks` is worktop CELLS and not desks; `partitions` should
            // track three per pod row; `basins` + `stalls` is the washroom's whole fixture run, and
            // a washroom reporting 0 stalls means the contiguity test that separates the two broke
            fit: fit,
            deco: CorpFurniture.deco,
            // how many masonry rects the contact field was painted from. it is a FIELD and draws
            // nothing, so there is no instance count to read it off and this is its only handle
            shadows: render.world.ContactMask.count,
          };
        }
    }

// nothing in a tower stands on anything but the floor
  function objLift(col:Int, row:Int):Float
    {
      return 0.0;
    }

// which way an object prop faces from its cell — the compound's three branches unchanged
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL:
            return 0;
          case HASHED:
            return (FacilityModel.mix((col * 40503151) ^ (row * 57885161)) % 3600) / 3600.0 * 2 * Math.PI;
          case WALL:
            if (FacilityModel.isWall(model, col, row - 1))
              return 0;
            if (FacilityModel.isWall(model, col, row + 1))
              return Math.PI;
            if (FacilityModel.isWall(model, col - 1, row))
              return Math.PI / 2;
            if (FacilityModel.isWall(model, col + 1, row))
              return -Math.PI / 2;
            return 0;
        }
    }

// the per-frame world tick. no occlusion, no reveal ease and, in this phase, no lamps to pool —
// what is left is the vision sweep and the chunk cull
  public function tick(opts:Area3DTickOpts):Void
    {
      if (opts.outro)
        return;
      // off the SMOOTHED position and not opts.playerCol/Row — see VisionMask's own note on why
      // the logical cell is the wrong origin
      VisionMask.update(game, opts.player.x, opts.player.z);
      lampLights.update(lamps.posts, opts.playerCol, opts.playerRow, opts.dtMs);
      // THE ONE THING IN THIS KIND ON A WALL CLOCK: raw dtMs, no ANIM_SPEED and no BASE_MS. see
      // CorpCrowd's header — ambient city life is RenderConfig's own documented exception, and a
      // street that stops when the player stops thinking is the whole feature missing
      crowd.tick(opts.dtMs);
      // AND THE DOOR LEAVES, which is not only their swing: FacilityDoors.pose writes into the
      // prop's own matrix array and render.Models.cull is what uploads it, so a tower that never
      // ticked them drew every leaf at the world origin and had a hole at every doorway — which
      // is what "what's up with doors" was looking at
      FacilityDoors.tick(doors, opts);
      // the server room's blink clock, which is the compound's own shared uniform — see
      // render.facility.FacilityDeco.lights, emitted from CorpFurniture.rack
      render.facility.FacilityDeco.tick(opts.dtMs);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      for (p in glb)
        render.Models.cull(p, opts.camera, CorpStyle.PROP_CULL_R);
    }

  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

  public function bloomThreshold():Float
    {
      return CorpStyle.BLOOM_THRESHOLD;
    }

// the compound's preset: a corp floor is the same kind of thing to look at — interior rooms seen
// over a wall head, not a street and not a tunnel
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_FACILITY;
    }

// nothing lies on a maintained corporate floor
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return [];
    }

  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// the city 114 units DOWN, which is a real citygen model and not a stand-in — see CorpStreet.
// handed over so anything that reads an area's city (the crowd's lane picking, the debug
// inspector) gets the same one that was drawn, rather than re-generating it off the seed
  public function city():citygen.CityModel.City
    {
      return street == null ? null : street.city;
    }

  public function shadowLamps():Array<LampPost>
    return [];

  public function flyLamps():Array<LampPost>
    return [];

// the leaves and the glb props are both placed ONCE at build off the live object list, so an object
// added to or removed from the area leaves them stale. rebuilt whole rather than patched, on the
// compound's own reasoning: the geometry is shared and cached, and this fires on an object edit
  public function refreshObjects():Void
    {
      if (doors == null)
        return;
      FacilityDoors.dispose(built, doors);
      model.doors = CorpModel.fromArea(game.area).doors;
      doors = FacilityDoors.build(built, model, game.area);
      render.world.ObjModels.dispose(built, props);
      props = render.world.ObjModels.build(built, game, objYaw, objLift);
    }
}

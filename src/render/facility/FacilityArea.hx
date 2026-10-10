package render.facility;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.facility.FacilityModel.Facility;
import render.world.ContactMask;
import render.world.IndoorMask;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;
import render.world.WorldCtx;

// the facility area kind (AREA_FACILITY): the first one with an OUTDOORS and an INDOORS at once.
// the city has buildings and no interiors; the tunnels and the wilderness have interiors and no
// shell. everything specific to this kind follows from that one fact.
//
// no render.Occlusion. a city fades a building while it blocks the camera-to-player sightline, which
// is the right question when the player is always outside it. here the player walks IN, so the shell
// fades on being INSIDE instead — the roof all the way, the south-facing wall faces to a ghost — and
// the vision mask governs how much of the inside is then drawn
class FacilityArea implements Area3D
{
  // what `build` appends to `green` after the GREEN table, IN THIS ORDER — the park railing, the
  // litter bins, the parked cars, the lot's standing junk and the indoor lab kit. they are batches
  // with no GreenProp row,
  // because none of them is planted on a tile of its own, and this is the only place that can name
  // them. THE GATE'S TWO ARE LAST, and they are rows whatever FacilityStyle.ENTRY_BLENDER says: the
  // emitted checkpoint hands back two EMPTY batches rather than none, because this list and `green`
  // are index-aligned and an absent row shifts every batch after it
  static final EXTRA = [
    FacilityGround.FENCE_PATH,
    FacilityGround.BIN_PATH,
    RenderConfig.MODELS.facilityCar,
  ].concat([for (p in FacilityDebris.PROPS) p.path])
    .concat([for (p in FacilityKit.PROPS) p.path])
    // and the cleaner's pair, which divide the interior with the lab kit by SURFACE rather than by a
    // shared list: corridors and washrooms against rooms (render.facility.FacilityJanitor)
    .concat([for (p in FacilityJanitor.PROPS) p.path])
    // and the hazard barrels standing on the LOW decoration cells, one batch per LIVERY, appended
    // off their own table so a fourth needs no edit here (render.facility.FacilityDeco.drums).
    // their sibling the BIN is deliberately absent: it rides the compound's existing bin batch,
    // four rows up, rather than opening a call of its own
    .concat([for (p in FacilityDeco.PROPS) p.path])
    // and the ROOM TEMPLATE batches, last because `green` pushes them last: the cubicles' WC pans,
    // the chairs at the office desks and the three objects standing on those desks. the workstation
    // is three batches and not one because the tower stands on a hand rolled per desk — see the
    // header of render.facility.FacilityWork
    .concat([
      RenderConfig.MODELS.facilityToilet,
      RenderConfig.MODELS.facilityChair,
      RenderConfig.MODELS.facilityMonitor,
      RenderConfig.MODELS.facilityTower,
      RenderConfig.MODELS.facilityKeyboard,
      // and the desk trinkets, in FacilityWork.TRINKETS' own order — the three cup glazes last, so
      // adding a fourth is an append at both ends rather than an insert
      RenderConfig.MODELS.facilityDeskMug,
      RenderConfig.MODELS.facilityDeskPlant,
      RenderConfig.MODELS.facilityDeskLamp,
      RenderConfig.MODELS.facilityDeskTray,
      RenderConfig.MODELS.facilityDeskMugB,
      RenderConfig.MODELS.facilityDeskMugC,
      RenderConfig.MODELS.facilityDeskJournals,
      // and the FITTINGS that ship as glbs (render.facility.FacilityDeco.fittings): the two server
      // racks, which are two MESHES and not one at two scales, then the storage cabinet. Every row
      // stays even when its family's ..._GLB flag is off — an empty batch is a row with a count of
      // 0, and this list has to stay index-aligned with `green`
      RenderConfig.MODELS.facilityRack,
      RenderConfig.MODELS.facilityRackLow,
      RenderConfig.MODELS.facilityCabinet,
      // the machine twice, because two HEIGHTS off one path are still two batches
      RenderConfig.MODELS.facilityMachine,
      RenderConfig.MODELS.facilityMachine,
      RenderConfig.MODELS.facilityBookcase,
      RenderConfig.MODELS.facilityShelving,
      RenderConfig.MODELS.facilityBasin,
      RenderConfig.MODELS.facilitySofa,
      RenderConfig.MODELS.facilityTableLow,
      // and the hangar's second machine, appended with its row in FacilityDeco.fittings
      RenderConfig.MODELS.facilityAnalyser,
      // and the store room's three, in that same table's order
      RenderConfig.MODELS.facilityPalletRack,
      RenderConfig.MODELS.facilityPalletStack,
      RenderConfig.MODELS.facilityDrumPallet,
      // and the hangar's power generator, appended with its row in FacilityDeco.fittings
      RenderConfig.MODELS.facilityGenerator,
      // and the hangar's study podium, last because `green` pushes it last. ONE instance per shed
      // and usually one shed, so it is the smallest batch in the list — and the only one standing
      // on Surf.CONCRETE (render.facility.FacilityHangar)
      RenderConfig.MODELS.facilityHangarPodium,
      // and the checkpoint at the gate: the boom assembly then the kiosk, in the order
      // render.facility.FacilityEntry.build returns them
      FacilityEntry.BARRIER_PATH,
      FacilityEntry.BOOTH_PATH,
    ]);

  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var moon:DirectionalLight;                    // shadow-casting moon, its map frozen between moonTick's renders
  var lampLights:LampLights;                    // the shared live spotlight pool, ticked each frame
  var lamps:FacilityLamps.LampSet;              // the outdoor masts and the ceiling fixtures
  var lampPosts:Array<LampPost>;                // both families as one candidate list for the pool
  var spillPosts:Array<LampPost> = [];          // the openings, as fake-shadow sources only (no pool slot)
  var coneGroup:Object3D;                       // the scene rig's cone parent, held for the mast shafts
  var lampCorners:Map<Int,Int>;                 // filled at build: grid vertex -> lamp dir, so a slide bends
  var shells:Array<FacilityGeom.Shell>;         // per structure: what the reveal fades
  var green:Array<render.Models.InstancedProp>; // the park's plants, then EXTRA (railing, bins)
  var margin:Array<render.Models.InstancedProp> = []; // a military base's wild margin, culled like green
  var hangar:FacilityHangar.Hangar; // the shed's podium, its cable fan and its floor decals
  // what stands on the roofs. NOT in `green`, and that is the one thing separating it: `green` is
  // culled by the frustum alone, while these two also have to go when the deck they stand on fades
  var roof:FacilityRoof.Roof;
  var doors:Array<FacilityDoors.DoorBatch>;     // the swinging leaves, one batch per look
  var sounds:FacilitySounds;                    // the machines, drips and beds, by path distance
  // objects that draw as a real glb instead of their sprite (the alien ship set piece). NOT in
  // `green`: that array is index-aligned with GREEN plus EXTRA and culled on one radius, while a
  // PropBatch is a solid/ghost/hull triple with its own masks and its own ghost ease
  var props:Array<render.world.ObjModels.PropBatch>;
  var rig:FacilityRig.Rig;                      // the study rig's glowing leads, or null
  var tactical = false;                         // tactical view up: the props draw their outline shells
  var cabinets = 0;                             // corridor casework cells merged into the bench meshes
  var boards = 0;                               // lobby notice boards emitted: one per front entrance
  var grime = 0;                                // interior wall faces carrying a damp band
  var exits = 0;                                // lit exit signs: one per lintel face onto a corridor
  var points = 0;                               // corridor wall fittings: fire points and panels
  var placards = 0;                             // room wall safety signage: one per run of masonry
  var signs = 0;                                // room signs on the corridor side of a themed door
  var work = 0;                                 // workstations emitted on the office desks
  var elec:render.facility.FacilityCable.ElecCounts =
    {
      mounts: [],
      runs: 0,
      units: 0,
      scatter: 0,
    };                                          // the whole electrical service, four ways
  var sinks = 0;                                // bench sinks: one per block with a free edge cell
  var clutter = 0;                              // flat decals scattered over the worktops
  var store = 0;                                // and over a store room's concrete floor
  var clues = 0;                                // clue spots dropped for carrying a basin or a screen
  var built:Scene;                              // held for refreshObjects, which rebuilds the doors
  var reveal:Array<Float>;                      // per structure, 0 solid .. 1 fully revealed
  var target:Array<Float>;                      // what each is easing toward
  // and the same pair for the GLAZING, which is a different question from the reveal and must not
  // ride it: `reveal` also opens a structure the player is merely peeking INTO from the lot
  // (FacilityStyle.PEEK_CELLS), and dimming a facade the player is standing outside and looking at
  // is the one thing this must not do. `inside` is the cell's own owner and nothing else
  var inside:Array<Float>;                      // per structure, 0 seen from the lot .. 1 stood in
  var inTarget:Array<Float>;
  var lastCol = -1;                             // the cell the targets were last recomputed for
  var lastRow = -1;
  var lastVis = -1;                             // and the visibility revision, so an opened door counts
  var moonX = Math.NaN;                         // the moon box's snapped focus, world x/z (NaN = not yet placed)
  var moonZ = Math.NaN;
  var moonFocus = new Vector3();                // ^ as the point fitMoon aims at
  var moonLanded = -1;                          // glb batches landed at the moon's last render
  var casters:Array<render.Models.InstancedProp>; // every glb batch moonTick counts landings over, built on first use
  var ranges:Array<render.RangeCull.RangeMesh>; // the merged meshes, range-culled per frame; null until merge() lands

  public function new(game:Game, model:Facility)
    {
      this.game = game;
      this.model = model;
    }

// night sky, fog closing the far edge, fill + a moon, and the empty live lamp pool
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = FacilityScene.build(renderer, lampPool);
      moon = bundle.moon;
      // frozen: moonTick re-renders it only when something it holds has changed
      moon.shadow.autoUpdate = false;
      moon.shadow.needsUpdate = true;
      lampLights = bundle.lampLights;
      coneGroup = bundle.coneGroup;
      // held BY REFERENCE and filled later, in build(). render.View.buildFrom hands this same map to
      // the camera rig and the actor layer before it calls build(), and both keep the reference and
      // query it per frame — so a map that is empty at handover and populated a line later is read
      // exactly as a city's fully-built one is
      lampCorners = bundle.lampCorners;
      return bundle;
    }

// the outdoors, then every structure's shell, then the chunk buckets and the vision mask
  public function build(scene:Scene):Void
    {
      // a facility floor is FLAT and stepped by nothing — no relief field and, in this phase, no
      // kerb — but it is not all at y = 0: a lab bench is a metre of solid worktop and the generator
      // writes its decorations onto the bench's own cell, so `ground` answers the bench height there
      // and 0 everywhere else. setting these is not optional either way — the kind that sets one owns
      // it, or the next area inherits the previous one's ground height and climb arc (WorldCtx)
      WorldCtx.tiles = null;
      WorldCtx.ground = function(x, z) return FacilityTables.groundY(model, x, z);
      // and the compound HAS something to climb: the park railing is render-only, so an actor walks
      // straight through it into the lawn and this arc is the whole of what says the bar is there —
      // the same contract the wilderness's guard rail runs on
      WorldCtx.climbArc = function(fc, fr, tc, tr) return FacilityGround.climbArc(model, fc, fr, tc, tr);
      // and the one area kind with walls of its own that carry objects: the generator writes a vent
      // as a WALL cell and stands an objects.Vent on it, so the grille has to hang on the masonry
      WorldCtx.wallMounts = function(col, row) return FacilityGeom.wallMounts(model, col, row);
      // a compound's masonry is a slab CENTRED in its cell and not the cell itself, so a decal that
      // stood on the cell boundary — where a drop or a shot stops — hung a whole unit off the wall
      WorldCtx.wallFace = function(col, row, dir) return FacilityGeom.wallFace(model, col, row, dir);
      // and the one area kind that does not stand its props on the cell centre: a fitting is pushed
      // off the WALL FACE, so the actor pose behind it has to be pushed with it
      WorldCtx.standOff = function(col, row) return FacilityDeco.standOff(model, col, row);
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // the indoor lighting mask, and it goes BEFORE the builders where the vision mask goes after.
      // both hold their uniforms in statics shared by identity, so either could be filled at any
      // time — but render.world.IndoorMask.patch reads `on` at MATERIAL-CREATION time to decide
      // whether to compile the swap into a surface at all, and every material below is created in the
      // next five lines.
      //
      // isInterior, which is neither isIndoor nor `owner >= 0`: an EXTERIOR wall belongs to a
      // structure and has an outdoor face, so the mask reaches only its inner face and does that by
      // growing from the floor side (INDOOR.grow). a room divider and an exterior door cell are the
      // two cases the obvious predicates get wrong — see the predicate's own header
      IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
        function(col, row) return FacilityModel.isInterior(model, col, row));
      // and the fake ambient occlusion on the floor, which has to be attached here for exactly the
      // same reason: ContactMask.patch reads `on` at MATERIAL-CREATION time, and the floors are
      // created three lines into FacilityGeom.build below
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      // and what a METAL prop reflects, which is the third of the same family and attaches here for
      // the third time for the same reason: render.world.PropEnv.apply reads `on` before it will
      // inject, and the lab kit's materials arrive from a glb promise that may resolve at any point
      // after this line
      render.world.PropEnv.attach(FacilityStyle.PROP_ENV);
      // snapshot what the scene rig parented (lights, the empty cone group) so the chunk pass only
      // ever touches the static geometry the builders below add
      var pre = scene.children.copy();
      built = scene;
      FacilityGround.build(scene, model);
      // the park's overlay patches and the tufts standing in them, straight after the lawn they lie
      // on so the two are built from one pass over the same grid
      FacilityLawn.build(scene, model, game.area);
      shells = FacilityGeom.build(scene, model);
      // the condensers, the dish and the access hatch, straight after the shell they stand on: the
      // hatches are merged into the structures' OWN fading roof meshes, so `shells` has to exist
      roof = FacilityRoof.build(scene, model, shells);
      cabinets = FacilityTables.build(scene, model);
      // and the sinks standing on those worktops, straight after them: the pass reads the same
      // `table` grid and stands on the BENCH_H the run above just emitted
      sinks = FacilitySink.build(scene, model);
      // then the clutter scattered over what is left of those worktops. AFTER the sinks and not
      // before: the pass above is what fills `tableSink`, and a decal laid across a basin is exactly
      // the failure that grid exists to stop
      clutter = FacilityClutter.build(scene, model);
      // the workstations on the office desks, between the two families whose buffers they BORROW: the
      // status lights on their towers go into FacilityDeco's additive LED mesh and their desk leads
      // into FacilityCable's ribbon, so the whole set costs exactly one draw call of its own. those
      // two buffers are the only ordering constraint in this whole block, and they are a real one —
      // the borrower has to fill before the owner merges
      var workLeds = MeshBufTools.make();
      var workCable = MeshBufTools.make();
      work = FacilityWork.build(model, workLeds, workCable);
      // and with both worktop families now standing, the clue spots they have covered come out of the
      // area's own list. AFTER the sinks and the workstations because it reads what those two placed,
      // and a prune rather than a check at spawn time because a document arrives in the turn loop
      // long after this — see FacilityClues
      clues = FacilityClues.prune(model, game.area);
      // and the room furniture that used to be an upright sprite, straight after the casework it is
      // the same kind of thing as: merged geometry standing against a wall, one mesh per family
      FacilityDeco.build(scene, model, workLeds);
      // the lobby notice board and the interior wall grime, both after the shell because both hang
      // on FacilityGeom.slab's own faces
      boards = FacilityBoard.build(scene, model);
      grime = FacilityGrime.build(scene, model);
      // and the corner strips AFTER the band, which is a draw-order fact and not a preference: both
      // are transparent with depthWrite off and both are one compound-wide merge sitting at the
      // origin, so three compares an identical sort z and falls through to `a.id - b.id`, i.e.
      // CONSTRUCTION order. Built first, the band would draw over the strip in the one corner they
      // share — the tunnels' own `grime, decals, shadows` finding
      FacilityDetail.corners(scene, model);
      exits = FacilityExit.build(scene, model);
      // and the fire points and electrical panels on the same corridor walls, beside the signage
      // they are the same kind of thing as. it needs no ordering against the hatch already struck
      // under it — FacilityPoint.places is a pure function of the grid and FacilityPaint called it
      // for exactly that reason (see that file's header)
      points = FacilityPoint.build(scene, model);
      // and the safety signage on the ROOM walls, which is every other wall in the building: the
      // three families above are all Surf.LINO-gated and none of them ever reached a room. it needs
      // no ordering against anything either — PLACARD_Y hangs it clear of the tallest fitting that
      // can share a cell, so the collision the fire points had to answer does not arise up there
      placards = FacilityPlacard.build(scene, model);
      // and the room signs on the CORRIDOR side of every themed room's door, which is the opposite
      // wall and the opposite question — see that pass's own header
      signs = FacilityPlacard.rooms(scene, model);
      // and the electrical service LAST of the wall families, because it is the only one that reads
      // three of the others: the room sockets share FacilityPlacard.hangs (and sit at 0.25 to 0.95, a
      // whole storey under the signage), and the corridor fittings exclude FacilityTables.runs and
      // FacilityPoint.places outright. None of that is an ordering — all three are pure functions of
      // the saved grid, which is why FacilityPoint can be asked for its own placements here without
      // having run, and why this can equally go before FacilityDeco while asking it for machine rects
      // the hangar's contents, BEFORE the line below and not after: it borrows `workCable` exactly
      // as FacilityWork's desk leads do, and a borrower has to fill before the owner merges. That is
      // the one ordering constraint in this block and it is the same one recorded above it
      hangar = FacilityHangar.build(scene, model, workCable);
      // and the store room's floor, which is the same family one floor up and needs nothing from
      // the generator: a store is the only INDOOR room floored in concrete
      store = FacilityStore.build(scene, model);
      // and the checkpoint's service drop, the third borrower of that same buffer and the last
      // thing into it — the pole it runs from is FacilityLamps.gateMast, which is pure arithmetic
      // over the grid and needs no mast to have been built yet
      FacilityEntry.cable(model, workCable);
      elec = FacilityCable.build(scene, model, workCable);
      green = FacilityGround.green(scene, model, game.area);
      // the park railing and the litter bins ride the same array as the plants, which is not
      // laziness: everything the array is FOR applies to them unchanged — one per-frame Models.cull,
      // one row in __facility()'s batches. they are only ever APPENDED, in the order EXTRA names
      // them, so the plants stay index-aligned with GREEN
      green.push(FacilityGround.fence(scene, model));
      green.push(FacilityGround.bins(scene, model, game.area));
      // and the cars, which ride it for the same two reasons and are the one batch out on the
      // ASPHALT rather than in the park — the array is a cull list and a batch listing, and neither
      // cares which surface a prop stands on
      green.push(FacilityCars.build(scene, model));
      // and the junk lying about the same asphalt, which rides the array for the same two reasons.
      // its OTHER half — the flat litter decals — appears nowhere here: that one goes out through
      // `debris()` onto the shared decal batch and owns no mesh of its own
      for (p in FacilityDebris.props(scene, model))
        green.push(p);
      // and the lab kit standing INDOORS, which rides the array for the third and fourth time. it is
      // the one family in here the vision mask really matters to — everything else on this list
      // stands outdoors, where the mask reads 1
      for (p in FacilityKit.props(scene, model))
        green.push(p);
      // and the cleaner's broom and bucket, which take the corridors and the washrooms the lab kit's
      // Surf.TILE gate leaves to them
      for (p in FacilityJanitor.props(scene, model))
        green.push(p);
      // and the hazard barrels standing on the room floor's own LOW decoration cells, one batch per
      // livery and last because EXTRA names them last. the other half of that family, the bins,
      // appended nothing here: they went into FacilityGround.bins' places above and share its batch
      for (p in FacilityDeco.drums(scene, model))
        green.push(p);
      // and the two ROOM TEMPLATE batches, in EXTRA's own order: the WC pans standing in the
      // washroom's cubicles, and the chairs pushed up to the offices' workstations
      green.push(FacilityDeco.toilets(scene, model));
      green.push(FacilityWork.chairs(scene, model));
      // and the monitor, the tower and the keyboard standing on the desks those chairs are pushed up
      // to. their leads and status lights went out through `build` above, into the two buffers this
      // family borrows — only the three objects themselves are batches
      for (p in FacilityWork.props(scene, model))
        green.push(p);
      // and the hand-modelled fittings, last because EXTRA names them last — one batch per mesh,
      // each empty when its family's quads are the ones shipping (FacilityDeco.fittings)
      for (p in FacilityDeco.fittings(scene, model))
        green.push(p);
      // and the hangar's podium, last because EXTRA names it last. an empty batch when the compound
      // has no shed with a study pad in it, which is a row with a count of 0 and keeps the array
      // index-aligned with EXTRA either way
      green.push(hangar.podium);
      // a military base's margin, and its own furniture: before the halos and the repaint, which
      // every unit of it registers a contact shadow with
      if (game.area.typeID == AREA_MILITARY_BASE)
        {
          margin = render.military.MilitaryMargin.build(scene, game.area, model);
          render.military.MilitaryGeom.build(scene, model, game.area);
        }
      // and now that every family that stands something against a WALL has placed, the halos those
      // things lay on the masonry behind them. after the damp band and the corner strips, which is
      // the same construction-order fact recorded above and what this quad's larger eps says it
      // should be: it stands proud of both and so has to draw over both
      FacilityDetail.halos(scene, model);
      // and now that every family that stands something on an interior floor has placed, the contact
      // field is repainted with their footprints in it. it CANNOT be done in the attach above: a
      // prop's position is not known until its builder runs, and attach has to come first because
      // ContactMask.patch reads `on` when a floor material is created. one canvas, one upload, no
      // material touched — the whole reason to reach for the field rather than lay a quad per prop
      ContactMask.repaint();
      // the checkpoint at the gate. TWO BATCHES when FacilityStyle.ENTRY_BLENDER is on and two EMPTY
      // ones when it is off — either way the pair is pushed, because `green` is index-aligned with
      // GREEN plus EXTRA and the glazing band is merged geometry in both branches
      for (p in FacilityEntry.build(scene, model))
        green.push(p);
      doors = FacilityDoors.build(scene, model, game.area);
      // the compound's sounds: after the sinks, which they read their drips off
      sounds = new FacilitySounds(game, model);
      // and the objects that draw as real geometry rather than as their atlas sprite: the alien
      // ship on the hangar's study podium, its console and its slots. AFTER the doors and before the
      // lights, which is where it belongs rather than being load-bearing — the batches read nothing
      // any other builder writes
      props = render.world.ObjModels.build(scene, game, objYaw, objLift);
      // and the leads that tie that set piece together. after the props, which is where its own
      // ends come from — it is laid off the same object list
      rig = FacilityRig.build(scene, game.area);
      // KEPT OUT OF THE CHUNK TREE. its ribbons are world-coordinate geometry on a mesh standing at
      // the origin, so render.Chunks would bucket it by a position that says nothing about where the
      // cords actually are — and the same run rebuilt after an install is added straight to the
      // scene, so this is also what keeps the two paths drawing the same way
      if (rig != null)
        {
          if (rig.dim != null)
            pre.push(rig.dim);
          if (rig.lit != null)
            pre.push(rig.lit);
        }
      // the light SOURCES, then everything additive they and the windows put on a surface. both are
      // area-spanning, so render.Chunks.build's size guard leaves them parented to the scene — the
      // same treatment the city's own lamp batch gets
      lamps = FacilityLamps.build(scene, coneGroup, model, game.area, lampCorners);
      lampPosts = lamps.masts.concat(lamps.ceilings).concat(lamps.corridors).concat(lamps.doors);
      spillPosts = FacilityGlow.build(scene, model);
      chunks.build(scene, pre);
      reveal = [for (_ in shells) 0.0];
      target = [for (_ in shells) 0.0];
      inside = [for (_ in shells) 0.0];
      inTarget = [for (_ in shells) 0.0];
      // the blocker predicate is the TILE grid and not canSeeThrough, because the mask's green
      // channel is painted once and has to be static: a facility door is an object that opens, and
      // canSeeThrough is object-aware. it is also the right answer here for a second reason — a
      // facility door never blocks sight at all (objects.Door.canSeeThrough), and the door leaves
      // are glazed, so the only real blockers are walls and the hangar's shutter
      // and the second predicate the other three kinds do not pass: FacilityGeom.carries, which is
      // what slab() insets against, so the mask pulls its reveal back off exactly the floor the
      // masonry left open and off nothing else. a door and a window are see-through and so are not
      // blockers, but the wall line runs on through both — asking the blocker test instead would cut
      // a dark notch into a lit wall at every doorway and window jamb
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return FacilityModel.isWall(model, col, row) &&
          model.wall[row][col] != FacilityModel.Wall.WINDOW,
        function(col, row) return FacilityGeom.carries(model, col, row));
      attachDbg();
    }

// how high the FLOOR is under an object prop's cell, which in a compound is never the slab it is
// standing on but once: the hangar's study podium. The deck is 6.2 units of radius (its lathe's
// upper step, FacilityStyle.PODIUM_DECK_H up) and a cell centre one cell out on the diagonal is
// 5.66 from the middle, so the 3x3 core IS the deck and the ring beyond it is bare pad — which is
// where the console and the slots stand
  function objLift(col:Int, row:Int):Float
    {
      for (p in model.pads)
        if (Std.int(Math.abs(p.col - col)) <= 1 &&
            Std.int(Math.abs(p.row - row)) <= 1)
          return FacilityStyle.PODIUM_DECK_H;
      return 0.0;
    }

// which way an object prop faces from its cell, one branch per render.world.ObjModels.PropYaw
//
// FRONTAL is a plain 0: this camera rests with no yaw of its own, so unturned IS facing it — and a
// glb whose authored front points elsewhere is corrected once in render.Models.yawFix, which is a
// fact about the model rather than about how a prop is posed. WALL turns its back on the adjacent
// masonry, asked of the same isWall the vision mask is attached on. HASHED takes a full-circle turn
// off the CELL, so several of a prop in one compound are not clones and a re-entry gives the same
// compound rather than re-rolling
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

// console debug helper (persistent) — what this facility actually built.
//   __facility() -> { structures:[{hangar,x1,y1,x2,y2,cells}], rooms, windows, reveal, batches, roof }
//
// the same reasoning render.wild.WildArea's __wild carries: an instanced batch has no
// userData.cls so render.Debug.find cannot reach a tree out here, parasiteHx is statics-only so the
// Facility model is unreachable from JS, and every question this kind raises — did the flood fill
// find three structures, is the hangar the one it thinks, did every window run come back 2 or 3
// cells, is the roof actually revealing — has a numeric answer that a screenshot cannot give
  function attachDbg():Void
    {
      untyped js.Browser.window.__facility = function()
        {
          var batches = [];
          for (i in 0...green.length)
            batches.push({
              // `green` is the GREEN table plus EXTRA appended after it (see `build`), so the tail
              // rows are the ones GREEN cannot name
              path: (i < FacilityGround.GREEN.length
                ? FacilityGround.GREEN[i].path : EXTRA[i - FacilityGround.GREEN.length]),
              count: green[i].matrices.length,
            });
          var structures = [];
          for (i in 0...model.structures.length)
            {
              var st = model.structures[i];
              structures.push({
                hangar: st.hangar,
                x1: st.x1,
                y1: st.y1,
                x2: st.x2,
                y2: st.y2,
                cells: st.cells,
                reveal: reveal[i],
              });
            }
          // every opening with its LIVE state beside its geometry: what the model says, where the
          // eased swing has got to, and the yaw each of its two leaves is actually holding. that
          // triple is the whole door pass in one row — a screenshot cannot tell a leaf hinged on the
          // wrong jamb from one swinging the wrong way, and both just look like "the door is inside
          // the wall". `live` false means the cell found no objects.Door and can never open
          var leaves = [];
          for (b in doors)
            for (c in 0...b.open.length)
              leaves.push({
                col: b.cells[c].col,
                row: b.cells[c].row,
                look: b.cells[c].look,
                alongX: b.cells[c].alongX,
                inDir: b.cells[c].inDir,
                front: b.cells[c].front,
                isOpen: (b.doors[c] != null && b.doors[c].isOpen),
                live: (b.doors[c] != null),
                t: b.open[c],
                yaw0: b.shut[c * 2] + b.swing[c * 2] * b.open[c],
                yaw1: b.shut[c * 2 + 1] + b.swing[c * 2 + 1] * b.open[c],
              });
          // the lighting rig, as the questions it raises that a screenshot cannot answer: did the
          // lit-line rules place a mast on every kerb, lot edge and park path (and none in a tree),
          // did every room get its lattice, and did the corridor scan reach the passages the room
          // rects cannot describe — `corridors` is 0 only in a compound that has none. `bulbs` is
          // what the pool actually sees, all four families in one array
          var bulbs = [];
          for (p in lampPosts)
            bulbs.push({
              col: p.col,
              row: p.row,
              y: p.y,
              mul: p.mul,
            });
          // the object props, as their own list rather than a row in `batches` above: that array is
          // index-aligned with GREEN plus EXTRA, so an entry here would shift every batch label
          // after it. one row per model path, with the cells it placed on — which is the only way
          // to tell "the ship has no batch" from "the batch is there and placed nothing"
          var objProps = [];
          for (b in props)
            objProps.push({
              path: b.model.path,
              keys: b.model.keys.join(','),
              count: b.solid.matrices.length,
              cells: b.cells,
            });
          var parapets = [];
          for (i in 0...shells.length)
            parapets.push({
              structure: i,
              skipped: model.structures[i].hangar,
              cells: shells[i].paraCells,
              quads: shells[i].paraQuads,
            });
          return {
            structures: structures,
            rooms: model.rooms,
            windows: model.windows,
            doors: leaves,
            batches: batches,
            objProps: objProps,
            masts: lamps.masts.length,
            ceilings: lamps.ceilings.length,
            corridors: lamps.corridors.length,
            bulbs: bulbs,
            // how many masonry rects the contact mask was painted from, read off the array the
            // painter actually consumed. it is a FIELD and not geometry, so it draws nothing and
            // there is no instance count to compare it against — this is the only handle on it
            shadows: render.world.ContactMask.count,
            // and how many segments are struck on the INDOOR floors — one per cell of one line of
            // an aisle PAIR, so a marked room contributes about twice its long axis and a corridor
            // cell contributes one per lane boundary it TOUCHES. the same merged-mesh blindness
            // again: the aisle is one mesh with no instance count, and this static is the only count
            // of it. most rooms correctly take none, marking being for TRAFFIC and not for the gap
            // between two bench runs, so a 0 EVERYWHERE is the gate breaking and a 0 in a room is not
            marks: FacilityPaint.marks,
            // and how many KEEP-CLEAR zones are struck. TWO sources feed it and it is only readable
            // as their sum: one per exterior door leaf with circulation behind it, which should
            // track `exits`' terminal half exactly (both being that same list, so the two disagreeing
            // means one has grown a placement rule of its own), plus one per wall fitting below.
            // `zones` under `points` means a fitting landed on a cell a door zone already claimed
            zones: FacilityPaint.zones,
            // and how many wall FITTINGS stand — fire points plus electrical panels, the things a
            // zone belongs to. merged mesh with no instance count, the same blindness as `exits`
            // above, and the number is read against two rules: exactly ONE PANEL PER STRUCTURE with
            // a free corridor wall (so `points` minus the panel count is the fire points), and no
            // two inside POINT_SPACING cells of each other. It cannot exceed the free corridor wall
            // faces left after FacilityTables.runs takes the casework's, which is the collision this
            // family exists to respect — a `points` that jumps when CASE_PCT moves means that
            // exclusion broke
            points: points,
            // and how many ROOM wall placards stand, which is the same merged-mesh blindness once
            // more and the one counter here that reads a surface rather than a family: every other
            // wall fitting in the compound is Surf.LINO-gated, so this is the only number that says
            // anything at all about what a room's walls carry. one per run of unbroken solid masonry
            // hugged by room tile, over PLACARD_RUN_MIN cells, on the run's middle cell — so a wall
            // with a doorway in it is two runs and contributes 2, and a 0 in a compound with rooms
            // means the Surf.TILE gate or the carries-both-ways test broke rather than that the
            // rooms are bare
            placards: placards,
            // and the two ROOM TEMPLATE families, both merged and so both invisible to `batches`
            // below. `signs` counts one per office door and TWO per washroom door (the men's and the
            // women's flank the same opening), so an odd number against a compound with a washroom in
            // it means one side of that doorway is not corridor. `work` is one per office desk cell
            // the WORK_EVERY roll dealt AND that has a wall hand to face away from — a 0 in a compound
            // whose rooms list an office means either the hash gate or the hand search broke
            signs: signs,
            work: work,
            // and the ELECTRICAL SERVICE off two merged meshes: the wall mounts AS A LIST and three
            // counts. FOUR readouts and not one because every part of this family fails
            // INDEPENDENTLY and merged geometry has no instance count to read them off — its first
            // build shipped 52 wall mounts and 0 runs with BOTH halves broken at once behind a single
            // counter, which is the whole argument for the split. The mounts are a LIST rather than a
            // number for a reason the counts do not have: `cell` is the sheet cell each one draws,
            // and a room picking ONE socket for all of its walls cannot be checked any other way.
            // `fit` false reads against `placards` — both run on FacilityPlacard.hangs, so placards
            // with no sockets is the bare-cell gate eating every candidate and a number near
            // `placards` means SOCK_SPACING stopped thinning; `fit` true reads against `points`,
            // whose faces it excludes. `runs` sits far under mounts + `units` and that is the
            // compound's geometry rather than a roll: a link is refused wherever the masonry between
            // two sockets is glazing or a doorway or the floor between them carries a fitting.
            // `units` is bounded by how much clear floor stands within UNIT_REACH_MAX of a wall, and
            // `scatter` is a flat one-in-SCAT_ODDS over every free floor cell, so it is the one of
            // the four that should track the compound's SIZE and nothing else
            elec: elec,
            // and how many bench SINKS stand. merged-mesh blindness for the third time, and the
            // number is read against the bench blocks rather than against the bench CELLS: one per
            // connected block of table tiles that had a free edge cell, so it is bounded above by the
            // block count and below by nothing. A 0 in a compound with benches is the block walk or
            // the edge predicate broken; a number far under the block count is the occupancy gate
            // eating them, which is a real outcome and not a bug — the generator decorates about 70%
            // of bench cells and forces one on every room corner
            sinks: sinks,
            // and how many flat DECALS landed on those worktops. merged-mesh blindness for the
            // fourth time, and the only readout that can catch the two ways this family fails
            // silently: a 0 in a compound with benches is the `table`/`tableSink` gate broken, and a
            // number near 3x the bench cell count means the rejection sampling in
            // FacilityClutter.cell stopped rejecting — the count is rolled 0..3 per cell, so it
            // should land near 1.5x the cells that are neither sink nor fully blocked
            clutter: clutter,
            // and the STORE's own floor decals, on the same terms and with the same blindness: one
            // merged mesh, no instance count. A compound reporting a `room-storage` node and 0 here
            // is the Surf.CONCRETE test broken, not an empty room
            store: store,
            // and how many clue spots came OUT of game.AreaGame.clueSpawnPoints because a basin or a
            // workstation is standing on them. it is the only handle on FacilityClues, and the number
            // to read it against is `sinks` plus `work`: a prune far under that sum means the
            // generator had already decorated those cells (so they were never clue spots), and a 0 in
            // a compound that reports either means the list was empty or the indexing is transposed
            clues: clues,
            // notice boards emitted. it is one MERGED mesh with no instance count to read, and the
            // whole question it answers is whether the front-entrance detection found anything at
            // all: `boards` short of the number of `doors` rows with front true means a structure's
            // entrance wall had nowhere to hang one
            boards: boards,
            // and how many interior wall faces carry a damp band. same problem as `boards` and as
            // `shadows` — one merged mesh with no instance count, over a face set nothing else
            // enumerates. every eligible face takes one, so this IS the interior-face count, and a
            // 0 means the face predicate broke rather than that the building is clean.
            //
            // it counts REENTRANT CORNER faces too, and that is what it is worth reading for: an
            // inside corner shows the room the two sides of the notch the wall's L leaves in its
            // angle, and neither is in the cell's own face loop. 400 cell faces + 2 per indoor
            // notch = **528** on a generated compound, against 64 notches over 42 corner cells
            grime: grime,
            // and how many corridor cells stand a run of storage casework. the same merged-mesh
            // blindness a third time: it goes into the SAME two buffers the generator's own benches
            // do, so nothing in the scene separates the two and this is the only count of the half
            // that is render-only. 0 in a compound with corridors means the run predicate broke
            cabinets: cabinets,
            // and how many exit signs are lit — TERMINAL over an exit door plus DIRECTIONAL on the
            // walls the route runs into. merged mesh again, and the two halves are separable
            // nowhere else, so the number is read against the two things that generate it: the
            // terminals are one per exterior door with circulation behind it, and the
            // directionals are one per approach wall that survives `EXIT_APPROACH` and does not
            // already carry a terminal sign along it. Measured on a generated compound:
            // **16 = 6 + 10** against 18 doors, 6 of the 10 mirrored. A
            // terminal count under the exterior-door count means the lino test broke; a
            // directional count in the dozens means `EXIT_APPROACH` stopped separating a wall you
            // walk AT from a wall you walk PAST, which at 2 costs 24 and at 0 would cost 127
            exits: exits,
            lit: lampLights.active().length,
            // the roofline and what stands on it, which is two questions a screenshot cannot
            // answer. the parapet: did it close on every structure and is the HANGAR really left
            // alone (skipped reads off the flag, quads off the buffers the emitter actually wrote,
            // so it cannot drift from the geometry). the props: an instanced batch carries no
            // userData.cls, so render.Debug.find cannot reach a condenser, and `structure` is what
            // drives whether it draws at all — a prop keyed to the wrong deck vanishes when the
            // player enters the building NEXT DOOR
            roof: {
              parapets: parapets,
              props: roof.props,
              hatches: roof.hatches,
              // and the hangar's vault, as the numbers it was derived from. an arch is the one
              // roof here a screenshot cannot check at all: whether the section is really a circle
              // segment is `radius` against `span` and `rise`, whether it is the shallow arc it is
              // meant to be is `arcDeg` against the 180 a half-round barrel would read, and whether
              // the ridge took the long axis (which is what puts the arch over the shutter row) is
              // `ridgeAlongX`. `quads` is read off the emitter, so it cannot drift from the geometry
              hangar: roof.vaults,
              // and the bays the deck was cut into. THE BARE MIDDLE IS THE ONLY WAY TO CHECK THIS:
              // a zone writes no geometry, so what says the ring band worked is `band` being 0 on
              // every bay in the middle of a big roof and non-zero on the ones against the parapet
              zones: roof.zones,
              // and the service runs struck between the condensers and their isolator boxes.
              // merged-mesh blindness again: the runs are one fading mesh per structure with no
              // instance count, so a 0 here in a compound reporting condensers means every group
              // came out empty. `cables` over `boxes` is the shape: near 1 and every unit got its
              // own box, over about 4 and one box is serving the whole deck as the old tree did
              cables: roof.cables,
              boxes: roof.boxes,
              // and the deck's flat dressing. it is the ONE family that ignores the ring band, so a
              // count near 12% of the decks' cells is right and a 0 means the depth test broke
              clutter: roof.clutter,
              // the service kit. `ducts` counts SEGMENTS: a run is 1 to ROOF_DUCT_MAX of them laid
              // on neighbouring cells, so a deck with a hatch on it reporting 0 is the walk out of
              // the service bay failing and not a small bay
              vents: roof.vents,
              ducts: roof.ducts,
              tanks: roof.tanks,
              // and the contact shadows. it must equal the sum of everything standing on a deck —
              // ac + dish + hatches + boxes + vents + ducts + tanks — a family that placed without
              // planting reads as floating, and that is the only way to see it without a screenshot
              pools: roof.pools,
            },
            // the park's overgrown patches. `strong` is the number the layer is TUNED on and the one
            // no screenshot gives: what shows through a near-uniform coverage field is just the
            // art's own opacity, i.e. grain, so the mask has to be judged and not the seed count
            patches: FacilityLawn.stats(),
          };
        };
    }

// per-frame world tick: the moon's shadow box, the reveal ease, the vision mask, the chunk cull and
// the per-instance plant cull
  public function tick(opts:Area3DTickOpts):Void
    {
      // the reveal runs through the outro as well: the camera is still looking at the area during
      // the pull-out, and a roof snapping back on mid-fade is exactly when it would show. a roof
      // fading or a leaf turning both change what the frozen moon map holds
      var changed = ease(opts.dtMs);
      // the leaves turn through the outro too, for the reason the reveal does: the camera is still
      // on the area during the pull-out, and a door snapping shut mid-swing is exactly when it shows
      if (FacilityDoors.swing(doors, opts))
        changed = true;
      // and the park's grass keeps moving through it for the same reason. this is the whole per-frame
      // cost of the tuft layer — one shared uniform, advanced once, read by every blade in the mesh
      render.wild.WildGrass.tick(opts.dtMs);
      // and the server racks' lights, which are the same one shared uniform advanced once — and
      // through the outro for the third time, because the camera is still on the compound
      FacilityDeco.tick(opts.dtMs);
      // whether a shadow map renders this frame, which every cull below then feeds the full set
      var all = !opts.outro &&
        moonTick(opts, changed);
      FacilityDoors.cull(doors, opts, all);
      // the object props, and the whole block is ABOVE the outro gate for the reason everything
      // else above it is: the camera is still looking at the compound through the pull-out. a
      // player who left standing ON one would otherwise stay behind a see-through hull for the
      // length of the shot, and a shared idle clock freezing mid-shot is exactly when it shows.
      // cull() reads opts.outro itself; the outline shells are a tactical READOUT, so a hidden HUD
      // takes them with it
      render.world.ObjModels.cull(props, opts, tactical && opts.ui, all);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
      // their glbs arrive over a loader callback, so there is no build-time moment to catch them.
      // the chain is shared with this kind's warm scene — see ObjModels.patchRow on why the order is
      // the contract and not a preference
      for (b in props)
        render.world.ObjModels.patchRow(b.model, b.solid.mesh, b.ghost.mesh, b.hull.mesh);
      FacilityRig.tick(rig, opts.dtMs);
      if (opts.outro)
        return;
      sounds.tick(opts.playerCol, opts.playerRow, opts.dtMs);
      // recompute what should be revealed only when the player's CELL moves or a sightline changes.
      // area.visRev is what makes the second half work: opening a door does not move the player but
      // it does open a view into a room
      if (opts.playerCol != lastCol ||
          opts.playerRow != lastRow ||
          game.area.visRev != lastVis)
        {
          lastCol = opts.playerCol;
          lastRow = opts.playerRow;
          lastVis = game.area.visRev;
          retarget(opts.playerCol, opts.playerRow);
        }
      // what the player cannot see, off the SMOOTHED position and not opts.playerCol/Row — see
      // VisionMask's own note on why the logical cell is the wrong origin
      VisionMask.update(game, opts.player.x, opts.player.z);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      render.Models.cull(lamps.prop, opts.camera, FacilityStyle.LAMP_CULL_R, null, all);
      // the shafts too: their mesh-wide cull is off (frustumCulled false), so a batch spanning the
      // compound drew every cone from everywhere — 0 px indoors and at the lot, at full cost
      for (c in lamps.cones)
        render.LightCone.cull(c, opts.camera);
      if (ranges == null)
        merge();
      else
        render.RangeCull.cull(ranges, opts.camera, all);
      for (p in green)
        render.Models.cull(p, opts.camera, FacilityStyle.PROP_CULL_R, null, all);
      for (p in margin)
        render.Models.cull(p, opts.camera, FacilityStyle.PROP_CULL_R, null, all);
      // and the roof's four batches, which take the frustum test with a MASK on top of it: a
      // condenser standing on a deck that has faded off would be left hanging over an open room
      render.Models.cull(roof.ac, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.acOf, reveal), all);
      render.Models.cull(roof.dish, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.dishOf, reveal), all);
      render.Models.cull(roof.hatchB, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.hatchOf, reveal), all);
      render.Models.cull(roof.jboxB, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.jboxOf, reveal), all);
      render.Models.cull(roof.ventB, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.ventOf, reveal), all);
      render.Models.cull(roof.ductB, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.ductOf, reveal), all);
      render.Models.cull(roof.tankB, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.tankOf, reveal), all);
    }

// which structures should be open. INSIDE is the obvious half; the other is looking in through a
// window, which is what makes item (a)'s large windows do their job without a separate action —
// stand at a pane with line of sight to it and that building opens up, and the vision mask then
// shows exactly the wedge the opening admits
  function retarget(col:Int, row:Int):Void
    {
      var here = FacilityModel.inside(model, col, row) ? model.owner[row][col] : -1;
      for (i in 0...target.length)
        {
          target[i] = (i == here ? 1.0 : 0.0);
          // the glazing's target is THIS line and never the peek pass below, which is the whole of
          // the difference between the two — see the field declarations
          inTarget[i] = target[i];
        }
      if (here >= 0)
        return;
      var reach = FacilityStyle.PEEK_CELLS;
      for (w in model.windows)
        {
          if (target[w.structure] > 0)
            continue;
          // the whole run, so a wide opening is not judged from one end of itself
          for (k in 0...w.len)
            {
              var wc = w.col + (w.alongX ? k : 0);
              var wr = w.row + (w.alongX ? 0 : k);
              if (Std.int(Math.abs(wc - col)) > reach ||
                  Std.int(Math.abs(wr - row)) > reach)
                continue;
              if (!game.playerArea.sees(wc, wr))
                continue;
              target[w.structure] = 1.0;
              break;
            }
        }
    }

// ease every structure toward its target and publish the result. FAST (see FacilityStyle.REVEAL_MULT)
// — this is the view getting out of the player's way, not an atmosphere beat.
//
// the ROOF and nothing else. the south-facing wall faces used to fade with it to 0.20, on the theory
// that the camera heading is fixed so a +z normal is the only thing that can stand between it and
// the player. the normal cannot answer that: a +z INNER face is, by construction, the south face of
// a wall whose south neighbour is indoor floor — i.e. the NORTH wall of some room — so whenever the
// player was in that room the fade dissolved the far wall, which occludes nothing, and the room
// opened onto the void past the area border. it took the window panes with it, and not gently: they
// carry alphaTest, three tests it against map.a * OPACITY, and at 0.20 every fragment was discarded,
// so a run snapped out whole the instant the ease crossed t = 0.625. whether a wall occludes is a
// question about where it is, which a build-time split by normal cannot see. the height it was
// buying back is paid for instead by FacilityStyle.WALL_T: an occluder's reach drops from 4 + 4.9
// units of z to 2 + 4.9
  function ease(dtMs:Float):Bool
    {
      if (shells == null)
        return false;
      var moved = false;
      var step = dtMs / (RenderConfig.BASE_MS * FacilityStyle.REVEAL_MULT);
      for (i in 0...shells.length)
        {
          var t = toward(reveal[i], target[i], step);
          if (t != reveal[i])
            {
              reveal[i] = t;
              apply(shells[i].roof, 1.0 - t * (1.0 - FacilityStyle.ROOF_FADE));
              moved = true;
            }
          // the glazing on the SAME clock as the roof: they are two halves of one transition, and a
          // pane still glowing after the ceiling has gone reads as a lag rather than as a fade
          var d = toward(inside[i], inTarget[i], step);
          if (d != inside[i])
            {
              inside[i] = d;
              shells[i].glaze.value = d;
            }
        }
      return moved;
    }

// the compound's per-texture meshes onto texture arrays, one mesh per material (render.corp.CorpMerge),
// then each cut into FacilityStyle.RANGE_BLOCK-cell blocks for the range cull. waits until every
// candidate's map has loaded. the roofs stay out: they fade and hide on their own, per structure
  function merge():Void
    {
      for (s in shells)
        for (m in s.roof)
          m.userData.noMerge = true;
      if (render.corp.CorpMerge.merge(built, false) < 0)
        return;
      ranges = [];
      built.traverse(function(o:Object3D)
        {
          if (o.userData.layerMaps != null)
            ranges.push(render.RangeCull.build(cast o, FacilityStyle.RANGE_BLOCK * citygen.CityConfig.CELL));
        });
      // the merged casters replace their members in the frozen map
      moon.shadow.needsUpdate = true;
    }

// the moon's box follows the player on a FacilityStyle.MOON_SNAP-cell grid and its map stays frozen
// between renders: tracking the smoothed position exactly re-rendered a 2048 map every frame, 7-22
// calls of it. it renders again when the box moves, a glb batch lands or `changed` says a roof faded
// or a leaf turned. NOT on area.visRev: that bumps on every player step, and keyed on it the map
// re-rendered on 68 of 450 walk frames for nothing.
// ponytail: an opened container's shut/open batch swap waits for the next snap to show in the map;
// key it off ObjModels' masks if that ever reads. also ticks the lamp pool, whose maps
// are frozen the same way. returns whether ANY shadow map renders this frame — the culls then pack
// every placement, because a frozen map drawn off the camera's subset keeps that hole until it next
// renders (measured: 5.5% of the park's pixels wrong viewed 4 cells off the render point)
  function moonTick(opts:Area3DTickOpts, changed:Bool):Bool
    {
      var snap = FacilityStyle.MOON_SNAP * citygen.CityConfig.CELL;
      var sx = Math.round(opts.player.x / snap) * snap;
      var sz = Math.round(opts.player.z / snap) * snap;
      if (sx != moonX ||
          sz != moonZ)
        {
          moonX = sx;
          moonZ = sz;
          moonFocus.set(sx, opts.player.y, sz);
          SceneSetup.fitMoon(moon, moonFocus);
          changed = true;
        }
      if (casters == null)
        casters = green.concat([ roof.ac, roof.dish, roof.hatchB, roof.jboxB, roof.ventB, roof.ductB,
          roof.tankB, lamps.prop ]);
      var landed = 0;
      for (p in casters)
        if (p.mesh != null)
          landed++;
      for (b in props)
        if (b.solid.mesh != null)
          landed++;
      if (landed != moonLanded)
        {
          moonLanded = landed;
          changed = true;
        }
      if (changed)
        moon.shadow.needsUpdate = true;
      // the pool: the nearest bulbs claim the 12 live spotlights, masts and ceiling fixtures
      // competing in one list. nothing here flickers, so this is the whole per-frame cost of the
      // lighting pass — no cone repack (render.LightCone.pulse) and no glow rebuild
      lampLights.update(lampPosts, opts.playerCol, opts.playerRow, opts.dtMs);
      return moon.shadow.needsUpdate ||
        LampLights.lastShadowRenders > 0;
    }

// one value's move toward its target, clamped so it lands on it exactly. two things ease on this
// clock now and neither may overshoot: an unclamped step leaves a pane's tint a hair off white
  static inline function toward(cur:Float, tgt:Float, step:Float):Float
    {
      if (cur < tgt)
        return (cur + step > tgt ? tgt : cur + step);
      if (cur > tgt)
        return (cur - step < tgt ? tgt : cur - step);
      return cur;
    }


// set one group's opacity. depthWrite follows it rather than staying on: a faded surface that still
// wrote depth would reject everything behind it however faint it drew, which is the trap
// render.Occlusion records for the actor billboard under a prop — fading alone changes nothing
  static function apply(meshes:Array<Mesh>, opacity:Float):Void
    {
      for (mesh in meshes)
        {
          var mat:Dynamic = mesh.material;
          mat.opacity = opacity;
          mat.depthWrite = (opacity > 0.5);
          mesh.visible = (opacity > 0.02);
        }
    }

// the walls and tables the tactical view marks are handled by render.TacticalGrid's blocked-cell
// pass, so the only thing this changes here is the OBJECT PROPS: a modelled object drops its sprite
// icon, and the backface shell is what replaces the green ring it would have carried
  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

// only the lit window panes glow, so this is the street's own level
  public function bloomThreshold():Float
    {
      return FacilityStyle.BLOOM_THRESHOLD;
    }

// steeper than the street's and shallower than the tunnels' — see RenderConfig.CAMERA_FACILITY
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_FACILITY;
    }

// the lot's ground litter. render-only and derived from the cell grid, so it costs no save space and
// is retroactive to every compound already saved — and it owns no mesh: these go onto the shared
// decal batch, which is why the pass appears here and not beside the props in `build`
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return FacilityDebris.build(model);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City here; the debug tools' city readers all handle null
  public function city():citygen.CityModel.City
    {
      return null;
    }

// the leaves are placed ONCE at build, off the live objects.Door objects, so an object added to or
// removed from the area leaves them stale. rebuilt whole rather than patched: a facility holds a few
// dozen doors, the leaf geometry is shared and cached, and this fires on an object edit and not per
// frame. what does NOT come back is the LINTEL over the opening — that is merged into the static
// shell, and no facility door is created or destroyed after generation, so rebuilding the whole
// shell to cover a case that does not arise would be the wrong trade
  public function refreshObjects():Void
    {
      if (doors == null)
        return;
      FacilityDoors.dispose(built, doors);
      model.doors = FacilityModel.fromArea(game.area).doors;
      doors = FacilityDoors.build(built, model, game.area);
      // and the object props on the same trigger and for the same reason: they are placed once at
      // build, so a ship spawned into the compound the player is already standing in would draw
      // NOTHING until re-entry — render.Actors drops an object's sprite the moment it has a model.
      // cheap: the glb templates are cached, so only the instance buffers are remade
      render.world.ObjModels.dispose(built, props);
      props = render.world.ObjModels.build(built, game, objYaw, objLift);
      // the leads with them: a slot that has just been filled changes its infoID, and this is what
      // moves its run into the bright half
      FacilityRig.dispose(built, rig);
      rig = FacilityRig.build(built, game.area);
    }

// the lit windows and glazed doors, as fake actor-shadow casters. they own no spotlight slot — what
// they put on the ground is a static quad in render.facility.FacilityGlow, not a light — so this is
// the only way they reach render.actors.LampShadows. built once, never repacked
  public function shadowLamps():Array<LampPost>
    return spillPosts;

// the compound's PARK masts, the ones the lit-line scan took off the park path. the only lamps in
// the game a swarm of gnats gathers over — see render.Area3D.flyLamps
  public function flyLamps():Array<LampPost>
    return (lamps == null ? [] : lamps.park);
}

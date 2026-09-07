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
  // them. NOTHING from the gate is here and nothing from it appears in __facility()'s batches: the
  // booth and the barrier are both merged geometry rather than props (see the header of
  // render.facility.FacilityEntry)
  static final EXTRA = [
    RenderConfig.MODELS.facilityFence,
    RenderConfig.MODELS.facilityBin,
    RenderConfig.MODELS.facilityCar,
  ].concat([for (p in FacilityDebris.PROPS) p.path])
    .concat([for (p in FacilityKit.PROPS) p.path])
    // and the hazard barrels standing on the LOW decoration cells, one batch per LIVERY, appended
    // off their own table so a fourth needs no edit here (render.facility.FacilityDeco.drums).
    // their sibling the BIN is deliberately absent: it rides the compound's existing bin batch,
    // four rows up, rather than opening a call of its own
    .concat([for (p in FacilityDeco.PROPS) p.path]);

  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var moon:DirectionalLight;                    // shadow-casting moon, repositioned each frame
  var lampLights:LampLights;                    // the shared live spotlight pool, ticked each frame
  var lamps:FacilityLamps.LampSet;              // the outdoor masts and the ceiling fixtures
  var lampPosts:Array<LampPost>;                // both families as one candidate list for the pool
  var spillPosts:Array<LampPost> = [];          // the openings, as fake-shadow sources only (no pool slot)
  var coneGroup:Object3D;                       // the scene rig's cone parent, held for the mast shafts
  var lampCorners:Map<Int,Int>;                 // filled at build: grid vertex -> lamp dir, so a slide bends
  var shells:Array<FacilityGeom.Shell>;         // per structure: what the reveal fades
  var green:Array<render.Models.InstancedProp>; // the park's plants, then EXTRA (railing, bins)
  // what stands on the roofs. NOT in `green`, and that is the one thing separating it: `green` is
  // culled by the frustum alone, while these two also have to go when the deck they stand on fades
  var roof:FacilityRoof.Roof;
  var doors:Array<FacilityDoors.DoorBatch>;     // the swinging leaves, one batch per look
  var cabinets = 0;                             // corridor casework cells merged into the bench meshes
  var boards = 0;                               // lobby notice boards emitted: one per front entrance
  var grime = 0;                                // interior wall faces carrying a damp band
  var exits = 0;                                // lit exit signs: one per lintel face onto a corridor
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
      // and the room furniture that used to be an upright sprite, straight after the casework it is
      // the same kind of thing as: merged geometry standing against a wall, one mesh per family
      FacilityDeco.build(scene, model);
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
      // and the hazard barrels standing on the room floor's own LOW decoration cells, one batch per
      // livery and last because EXTRA names them last. the other half of that family, the bins,
      // appended nothing here: they went into FacilityGround.bins' places above and share its batch
      for (p in FacilityDeco.drums(scene, model))
        green.push(p);
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
      // the checkpoint at the gate, which rides nothing: the booth and the barrier are both merged
      // straight into the scene, so this appends no batch and `green` stays index-aligned with
      // GREEN plus EXTRA
      FacilityEntry.build(scene, model);
      doors = FacilityDoors.build(scene, model, game.area);
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
      // the pull-out, and a roof snapping back on mid-fade is exactly when it would show
      ease(opts.dtMs);
      // the leaves turn through the outro too, for the reason the reveal does: the camera is still
      // on the area during the pull-out, and a door snapping shut mid-swing is exactly when it shows
      FacilityDoors.tick(doors, opts);
      // and the park's grass keeps moving through it for the same reason. this is the whole per-frame
      // cost of the tuft layer — one shared uniform, advanced once, read by every blade in the mesh
      render.wild.WildGrass.tick(opts.dtMs);
      // and the server racks' lights, which are the same one shared uniform advanced once — and
      // through the outro for the third time, because the camera is still on the compound
      FacilityDeco.tick(opts.dtMs);
      if (opts.outro)
        return;
      SceneSetup.fitMoon(moon, opts.player);
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
      // the pool: the nearest bulbs claim the 12 live spotlights, masts and ceiling fixtures
      // competing in one list. nothing here flickers, so this is the whole per-frame cost of the
      // lighting pass — no cone repack (render.LightCone.pulse) and no glow rebuild
      lampLights.update(lampPosts, opts.playerCol, opts.playerRow, opts.dtMs);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      render.Models.cull(lamps.prop, opts.camera, FacilityStyle.LAMP_CULL_R);
      for (p in green)
        render.Models.cull(p, opts.camera, FacilityStyle.PROP_CULL_R);
      // and the roof's two batches, which take the frustum test with a MASK on top of it: a
      // condenser standing on a deck that has faded off would be left hanging over an open room
      render.Models.cull(roof.ac, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.acOf, reveal));
      render.Models.cull(roof.dish, opts.camera, FacilityStyle.PROP_CULL_R,
        FacilityRoof.mask(roof.dishOf, reveal));
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
  function ease(dtMs:Float):Void
    {
      if (shells == null)
        return;
      var step = dtMs / (RenderConfig.BASE_MS * FacilityStyle.REVEAL_MULT);
      for (i in 0...shells.length)
        {
          var t = toward(reveal[i], target[i], step);
          if (t != reveal[i])
            {
              reveal[i] = t;
              apply(shells[i].roof, 1.0 - t * (1.0 - FacilityStyle.ROOF_FADE));
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

// nothing outlines here yet: no facility object draws as a glb prop, and the walls and tables the
// tactical view marks are already handled by render.TacticalGrid's blocked-cell pass
  public function setTactical(v:Bool):Void
    {
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
    }

// the lit windows and glazed doors, as fake actor-shadow casters. they own no spotlight slot — what
// they put on the ground is a static quad in render.facility.FacilityGlow, not a light — so this is
// the only way they reach render.actors.LampShadows. built once, never repacked
  public function shadowLamps():Array<LampPost>
    return spillPosts;
}

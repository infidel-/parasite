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
  var green:Array<render.Models.InstancedProp>; // the park's trees and bushes
  var doors:Array<FacilityDoors.DoorBatch>;     // the swinging leaves, one batch per look
  var built:Scene;                              // held for refreshObjects, which rebuilds the doors
  var reveal:Array<Float>;                      // per structure, 0 solid .. 1 fully revealed
  var target:Array<Float>;                      // what each is easing toward
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
      WorldCtx.climbArc = null;
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
      // snapshot what the scene rig parented (lights, the empty cone group) so the chunk pass only
      // ever touches the static geometry the builders below add
      var pre = scene.children.copy();
      built = scene;
      FacilityGround.build(scene, model);
      shells = FacilityGeom.build(scene, model);
      FacilityTables.build(scene, model);
      green = FacilityGround.green(scene, model, game.area);
      doors = FacilityDoors.build(scene, model, game.area);
      // the light SOURCES, then everything additive they and the windows put on a surface. both are
      // area-spanning, so render.Chunks.build's size guard leaves them parented to the scene — the
      // same treatment the city's own lamp batch gets
      lamps = FacilityLamps.build(scene, coneGroup, model, game.area, lampCorners);
      lampPosts = lamps.masts.concat(lamps.ceilings);
      spillPosts = FacilityGlow.build(scene, model);
      chunks.build(scene, pre);
      reveal = [for (_ in shells) 0.0];
      target = [for (_ in shells) 0.0];
      // the blocker predicate is the TILE grid and not canSeeThrough, because the mask's green
      // channel is painted once and has to be static: a facility door is an object that opens, and
      // canSeeThrough is object-aware. it is also the right answer here for a second reason — a
      // facility door never blocks sight at all (objects.Door.canSeeThrough), and the door leaves
      // are glazed, so the only real blockers are walls and the hangar's shutter
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return FacilityModel.isWall(model, col, row) &&
          model.wall[row][col] != FacilityModel.Wall.WINDOW);
      attachDbg();
    }

// console debug helper (persistent) — what this facility actually built.
//   __facility() -> { structures:[{hangar,x1,y1,x2,y2,cells}], rooms, windows, reveal, batches }
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
              path: FacilityGround.GREEN[i].path,
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
                isOpen: (b.doors[c] != null && b.doors[c].isOpen),
                live: (b.doors[c] != null),
                t: b.open[c],
                yaw0: b.shut[c * 2] + b.swing[c * 2] * b.open[c],
                yaw1: b.shut[c * 2 + 1] + b.swing[c * 2 + 1] * b.open[c],
              });
          // the lighting rig, as the two questions it raises that a screenshot cannot answer: did
          // the lit-line rules place a mast on every kerb, lot edge and park path (and none in a
          // tree), and did every room get a fixture. `bulbs` is what the pool actually sees
          var bulbs = [];
          for (p in lampPosts)
            bulbs.push({
              col: p.col,
              row: p.row,
              y: p.y,
              mul: p.mul,
            });
          return {
            structures: structures,
            rooms: model.rooms,
            windows: model.windows,
            doors: leaves,
            batches: batches,
            masts: lamps.masts.length,
            ceilings: lamps.ceilings.length,
            bulbs: bulbs,
            lit: lampLights.active().length,
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
    }

// which structures should be open. INSIDE is the obvious half; the other is looking in through a
// window, which is what makes item (a)'s large windows do their job without a separate action —
// stand at a pane with line of sight to it and that building opens up, and the vision mask then
// shows exactly the wedge the opening admits
  function retarget(col:Int, row:Int):Void
    {
      var here = FacilityModel.inside(model, col, row) ? model.owner[row][col] : -1;
      for (i in 0...target.length)
        target[i] = (i == here ? 1.0 : 0.0);
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
          var t = reveal[i];
          if (t < target[i])
            t = (t + step > target[i] ? target[i] : t + step);
          else if (t > target[i])
            t = (t - step < target[i] ? target[i] : t - step);
          else continue;
          reveal[i] = t;
          apply(shells[i].roof, 1.0 - t * (1.0 - FacilityStyle.ROOF_FADE));
        }
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

// no render-only ground litter here yet: the lot pass is what will scatter it
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return null;
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

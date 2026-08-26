package render.facility;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.facility.FacilityModel.Facility;
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
  var lampLights:LampLights;                    // the pool exists for program-key parity, with no bulbs yet
  var shells:Array<FacilityGeom.Shell>;         // per structure: what the reveal fades
  var green:Array<render.Models.InstancedProp>; // the park's trees and bushes
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
      return bundle;
    }

// the outdoors, then every structure's shell, then the chunk buckets and the vision mask
  public function build(scene:Scene):Void
    {
      // a facility floor is FLAT and stepped by nothing: no relief field and, in this phase, no kerb.
      // clearing these is not optional — the kind that sets one owns clearing it, or the next area
      // inherits the previous one's ground height and climb arc (see render.world.WorldCtx)
      WorldCtx.tiles = null;
      WorldCtx.ground = null;
      WorldCtx.climbArc = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // snapshot what the scene rig parented (lights, the empty cone group) so the chunk pass only
      // ever touches the static geometry the builders below add
      var pre = scene.children.copy();
      FacilityGround.build(scene, model);
      shells = FacilityGeom.build(scene, model);
      green = FacilityGround.green(scene, model, game.area);
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
          return {
            structures: structures,
            rooms: model.rooms,
            windows: model.windows,
            batches: batches,
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
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
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
// — this is the view getting out of the player's way, not an atmosphere beat
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
          apply(shells[i].wall, 1.0 - t * (1.0 - FacilityStyle.WALL_FADE));
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

// no facility object is drawn as a glb prop yet, so nothing placed once at build goes stale when one
// is added or removed — every object here is still an actor-layer sprite. the door pass changes that
  public function refreshObjects():Void
    {
    }
}

package render.sewer;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.sewer.SewerModel.Sewer;
import render.world.WorldCtx;

// the underground tunnel area kind (AREA_SEWERS + AREA_HABITAT). deliberately much smaller than
// render.CityArea: there is no ceiling and the camera looks near straight down, so a wall never
// gets between it and the player — which means no occlusion fade, and with nothing to fade the
// whole level welds into five merged meshes (see render.sewer.SewerGeom)
class SewerArea implements Area3D
{
  var game:Game;
  var model:Sewer;
  var lampLights:LampLights;    // live spotlight pool over the corridor nodes
  var lampPosts:Array<LampPost>; // node, exit and wall lamps (for the pool)
  var wallGlow:render.LightCone.ConeSet; // wall-lamp emissive quads, repacked per frame with their bulbs
  var props:Array<render.world.ObjModels.PropBatch>; // the exit ladders: solid / ghost / outline batches
  var tactical = false;                  // tactical view up: the props draw their outline shells

  public function new(game:Game, model:Sewer)
    {
      this.game = game;
      this.model = model;
    }

// the tunnel scene: near-black background, fog that closes in within a few cells, no moon, and the
// same live spotlight pool the streets use hung over the corridor nodes
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = SewerScene.build(renderer, model, lampPool);
      lampLights = bundle.lampLights;
      lampPosts = bundle.lampPosts;
      wallGlow = bundle.wallGlow;
      return bundle;
    }

// the whole static shell + its dressing, welded into a handful of merged meshes
  public function build(scene:Scene):Void
    {
      // the whole render layer reads ground height through WorldCtx.floorY, and it returns a flat
      // 0 when there is no city tile grid — which is what lets actors, choreo, particles and decals
      // run down here untouched. buildings stays a live empty array: the shot pass iterates it
      WorldCtx.tiles = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      SewerGeom.build(scene, model);
      // clutter heaped against the walls. pure decoration — no AreaObject behind it, so no ghost
      // twin, no outline hull and nothing per-frame; see SewerPiles for why it is not culled
      SewerPiles.build(scene, model);
      // the exit ladders, as real geometry instead of their sprite. only tunnel areas ever hold one:
      // WorldConst declares `exit: 'sewer_exit'` on AREA_SEWERS alone and game.AreaGame picks
      // sewer_exit / habitat_exit by area type, so a city never spawns either
      props = render.world.ObjModels.build(scene, game, SewerStyle.EXIT_MODEL_H, exitYaw);
    }

// which way an exit ladder faces: away from the wall it is bracketed to, or unturned if it stands in
// the open. dir order matches SewerGeom.side (0 north, 1 south, 2 west, 3 east)
  function exitYaw(col:Int, row:Int):Float
    {
      if (!SewerModel.isFloor(model, col, row - 1))
        return 0;
      if (!SewerModel.isFloor(model, col, row + 1))
        return Math.PI;
      if (!SewerModel.isFloor(model, col - 1, row))
        return Math.PI / 2;
      if (!SewerModel.isFloor(model, col + 1, row))
        return -Math.PI / 2;
      return 0;
    }

// per-frame world tick — down here that is only the live lamp pool: nothing fades, no windows
// switch, and there are no chunks to cull (the whole level is a handful of merged meshes)
  public function tick(opts:Area3DTickOpts):Void
    {
      // ABOVE the outro gate on purpose: a player who left standing ON a ladder would otherwise stay
      // behind a see-through one for the whole camera pull-out. cull() reads opts.outro itself
      render.world.ObjModels.cull(props, opts, tactical);
      // nothing else to fade and no window switches underground; the outro needs no world tick at all
      if (opts.outro)
        return;
      lampLights.update(lampPosts, opts.playerCol, opts.playerRow, opts.dtMs);
      // a wall fixture's glow quad is its ONLY brightness source (no emissive glb head down here), so
      // this is what stops a sputtering lamp from glowing and blooming right through its own outage
      render.LightCone.pulse(wallGlow, lampLights.flickT);
    }

// a tunnel has no occlusion pass, so the only thing tactical changes down here is the prop outlines:
// a modelled object drops its sprite icon, and this backface shell is what replaces the green ring
  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

// lower than the street's so the few lamps actually bloom against near-black surroundings
  public function bloomThreshold():Float
    {
      return SewerStyle.BLOOM_THRESHOLD;
    }

// near straight down: the walls are low and there is no ceiling, so the shallow street angle
// would stare into a wall face
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_SEWER;
    }

// per-cell-hash litter (no seed underground — the saved cell grid is the layout)
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return SewerDebris.build(model);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City underground; the debug tools' city readers all handle null
  public function city():citygen.CityModel.City
    {
      return null;
    }
}

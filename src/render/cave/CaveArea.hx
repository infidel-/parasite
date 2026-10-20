package render.cave;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;
import render.world.WorldCtx;

// the mountain cave habitat. the tunnels' shape of area kind (render.sewer.SewerArea): no ceiling, a
// camera looking near straight down, the whole shell welded into a few merged meshes, the vision mask,
// the organ props and their light pool. its own shell (render.cave.CaveGeom), light and art
class CaveArea implements Area3D
{
  var game:Game;
  var model:Sewer;
  var lampLights:LampLights;    // live spotlight pool over the cave mouths
  var lampPosts:Array<LampPost>; // one moonlight per mouth
  var propLights:render.particles.PropLights; // point-light pool for the glowing object props (organs)
  var sceneRef:Scene;                    // held for refreshObjects, which rebuilds the prop batches
  var props:Array<render.world.ObjModels.PropBatch>; // object props: solid / ghost / outline batches
  var tactical = false;                  // tactical view up: the props draw their outline shells

  public function new(game:Game, model:Sewer)
    {
      this.game = game;
      this.model = model;
    }

// the cave scene: near-black, fog close in, the mouths' moonlight in the shared spotlight pool
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = CaveScene.build(renderer, model, lampPool);
      lampLights = bundle.lampLights;
      lampPosts = bundle.lampPosts;
      propLights = bundle.propLights;
      return bundle;
    }

// the static shell and the object props
  public function build(scene:Scene):Void
    {
      // every WorldCtx hook reset, for the reasons render.sewer.SewerArea.build gives: a stale one from
      // the area before would point the floor at a height field or hang things on walls that are not here
      WorldCtx.tiles = null;
      WorldCtx.ground = null;
      WorldCtx.climbArc = null;
      WorldCtx.wallMounts = null;
      WorldCtx.wallFace = null;
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      sceneRef = scene;
      CaveGeom.build(scene, model);
      props = render.world.ObjModels.build(scene, game, objYaw, null, objWall);
      // the blocker predicate is the floor grid, not area.canSeeThrough (see SewerArea)
      VisionMask.attach(CaveStyle.MASK, model.w, model.h,
        function(col, row) return !SewerModel.isFloor(model, col, row));
    }

// which way a prop faces from its cell (render.world.ObjModels.PropYaw). WALL turns a cave mouth's back
// on the rock it opens from: north, then west, then east, never south — the order gen.cave.CaveGen picks
// a mouth's backing in
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL:
            return 0;
          case HASHED:
            return (SewerModel.mix((col * 40503151) ^ (row * 57885161)) % 3600) / 3600.0 * 2 * Math.PI;
          case WALL:
            if (!SewerModel.isFloor(model, col, row - 1))
              return 0;
            if (!SewerModel.isFloor(model, col - 1, row))
              return Math.PI / 2;
            if (!SewerModel.isFloor(model, col + 1, row))
              return -Math.PI / 2;
            return 0;
        }
    }

// how far a WALL-yawed prop steps back from its cell centre toward the rock: to the cell edge, where
// the outline starts (it only ever lies further into the rock than that)
  function objWall(col:Int, row:Int):Float
    {
      if (!SewerModel.exitWalled(model, col, row))
        return 0.0;
      return -(CityConfig.CELL / 2 - render.sewer.SewerStyle.EXIT_DEPTH / 2);
    }

// rebuild the prop batches after an object was added to or removed from the cave being shown (an
// organ grown where the player stands), see render.sewer.SewerArea.refreshObjects
  public function refreshObjects():Void
    {
      if (props == null)
        return;
      render.world.ObjModels.dispose(sceneRef, props);
      props = render.world.ObjModels.build(sceneRef, game, objYaw, null, objWall);
    }

// every light is a pooled one, so the fake shadows come from LampLights.active()
  public function shadowLamps():Array<render.particles.LampPost>
    return [];

// no swarm underground
  public function flyLamps():Array<render.particles.LampPost>
    return [];

// per-frame world tick: the props' clocks above the outro gate (they stay on screen through the
// pull-out), then the vision mask and the two light pools
  public function tick(opts:Area3DTickOpts):Void
    {
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
      for (b in props)
        render.world.ObjModels.patchRow(b.model, b.solid.mesh, b.ghost.mesh, b.hull.mesh);
      if (opts.outro)
        return;
      VisionMask.update(game, opts.player.x, opts.player.z);
      lampLights.update(lampPosts, opts.lightCol, opts.lightRow, opts.dtMs);
      propLights.update(game, opts.lightCol, opts.lightRow, opts.dtMs);
    }

// the prop outlines are the only thing tactical changes down here
  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

  public function bloomThreshold():Float
    {
      return CaveStyle.BLOOM_THRESHOLD;
    }

// the tunnels' preset: low rock, no ceiling, near straight down (AreaGame.getSpawnRect sizes the AI
// region off the same one for 'habitat')
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_SEWER;
    }

// no street litter in a cave
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return [];
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

  public function city():citygen.CityModel.City
    {
      return null;
    }
}

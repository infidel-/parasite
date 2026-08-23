package render.wild;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.wild.WildModel.Wild;
import render.world.WorldCtx;

// the open wilderness area kind (AREA_GROUND). the smallest of the three: no buildings, so no
// occlusion pass and no window switches; no lamps, so no live pool to park and no flicker to repack.
// what it does have that a tunnel does not is a MOON — so the shadow box has to follow the player,
// and the chunk cull has to keep an offscreen block alive while it is still inside that box
class WildArea implements Area3D
{
  var game:Game;
  var model:Wild;
  var chunks = new render.Chunks();
  var moon:DirectionalLight;                 // shadow-casting moon, repositioned each frame
  var lampLights:LampLights;                 // the pool exists for program-key parity, with no bulbs
  var props:Array<render.Models.InstancedProp>; // one instanced batch per WildStyle.PROPS entry

  public function new(game:Game, model:Wild)
    {
      this.game = game;
      this.model = model;
    }

// the wilderness scene: night sky, fog closing the far edge, fill + a moon, and no lamps
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = WildScene.build(renderer, lampPool);
      moon = bundle.moon;
      lampLights = bundle.lampLights;
      return bundle;
    }

// the ground, the grass and the scatter, then the chunk buckets over the result
  public function build(scene:Scene):Void
    {
      // the whole render layer reads ground height through WorldCtx.floorY, and it returns a flat 0
      // when there is no city tile grid — which is what lets actors, choreo, particles and decals run
      // out here untouched. buildings stays a live empty array: the shot pass iterates it
      WorldCtx.tiles = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // snapshot what the scene rig parented (lights, the empty cone group) so the chunk pass only
      // ever touches the static geometry the builders below add
      var pre = scene.children.copy();
      WildGround.build(scene, model);
      WildPatches.build(scene, model);
      WildGrass.build(scene, model);
      props = WildProps.build(scene, model);
      // the ground and grass blocks bucket; the prop batches span the whole area and so are left at
      // the scene root by Chunks' own size guard, which is right — they are frustum-culled per
      // INSTANCE in tick() instead
      chunks.build(scene, pre);
    }

// per-frame world tick: the moon's shadow box, the wind clock, the chunk cull and the per-instance
// prop cull. no occlusion, no window switches, no lamp pool to park
  public function tick(opts:Area3DTickOpts):Void
    {
      // the wind runs through the outro as well: the camera is still looking at the area during the
      // pull-out, and a field that freezes mid-lean is exactly when it would show
      WildGrass.tick(opts.dtMs);
      if (opts.outro)
        return;
      SceneSetup.fitMoon(moon, opts.player);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      for (p in props)
        render.Models.cull(p, opts.camera, WildStyle.PROP_CULL_R);
    }

// nothing fades or outlines out here: there is no building to occlude and no object drawn as a prop
  public function setTactical(v:Bool):Void
    {
    }

// nothing out here glows, so this is the street's own level
  public function bloomThreshold():Float
    {
      return WildStyle.BLOOM_THRESHOLD;
    }

// steeper than the street's, for want of an occlusion fade — see RenderConfig.CAMERA_WILD
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_WILD;
    }

// no street litter in open country; the grass layer is what dresses the ground here
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return null;
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City out here; the debug tools' city readers all handle null
  public function city():citygen.CityModel.City
    {
      return null;
    }

// no object is drawn as a glb prop in the wilderness, so nothing is placed once at build that an
// added or removed object would leave stale — every object out here is an actor-layer sprite
  public function refreshObjects():Void
    {
    }
}

package render.wild;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.wild.WildModel.Wild;
import render.world.VisionMask;
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
      // the relief FIRST: every builder below samples it, and so does the whole actor layer, which
      // reads ground height through WorldCtx.floorY. that returns a flat 0 with no city tile grid,
      // which is what lets actors, choreo, particles and decals run untouched in a tunnel — out here
      // WorldCtx.ground redirects it at the height field instead, and nothing else has to know.
      // buildings stays a live empty array: the shot pass iterates it.
      //
      // the field's AMPLITUDE is not set here — WildBand.use does it, from render.View.showWild,
      // because the Wild model is built before this object exists and already needs the band
      WildHeight.use(game.area.id);
      WorldCtx.tiles = null;
      WorldCtx.ground = WildHeight.at;
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
      // the vision mask's texture and world->uv transform. the builders above patched their own
      // materials as they made them; this only has to exist before the first sample.
      //
      // the blocker predicate is canSeeThrough, where a tunnel deliberately does NOT use it — down
      // there it is object-aware and would call a closed door a wall, and the green channel it paints
      // has to be static. out here there is no door and no destructible: the only cells that fail this
      // test are the two large obstacles the generator stamped (Const.TILE_ROCK_LARGE /
      // TILE_TREE_CLUSTER), so it IS static, and reading the tiles beats carrying a copy of them
      VisionMask.attach(WildStyle.MASK, model.w, model.h,
        function(col, row) return !game.area.canSeeThrough(col, row));
      attachDbg();
    }

// console debug helper (persistent) — what this wilderness area actually built.
//   __wild() -> { ground, reliefAmp, rocks:[{col,row}], thicket:[{col,row}], batches:[{path,count}] }
//
// the two lists come back whole rather than as counts, because the first question after "how many"
// is always "where is one" — an instanced batch carries no userData.cls, so render.Debug.find cannot
// locate a prop out here and there is nothing else to point a camera or a `go xy` at
//
// there is no other way to ask: parasiteHx is the class registry and holds STATICS only, so
// WildBand.cur reads out fine but the Wild model does not — WildModel.fromArea needs an AreaGame and
// nothing reaches one from JS. "did eight boulders actually get placed, and did the thicket cells get
// their understorey" cannot be answered by counting things on screen, and every change out here since
// the bands has needed that class of question settled numerically rather than off a screenshot
  function attachDbg():Void
    {
      untyped js.Browser.window.__wild = function()
        {
          var batches = [];
          for (i in 0...props.length)
            batches.push({
              path: WildStyle.PROPS[i].path,
              count: props[i].matrices.length,
            });
          return {
            ground: WildBand.cur.ground,
            reliefAmp: WildBand.reliefAmp,
            rocks: model.rocks,
            thicket: model.thicket,
            batches: batches,
          };
        };
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
      // what the player cannot see, off the SMOOTHED position and not opts.playerCol/Row — see
      // VisionMask's own note on why the logical cell is the wrong origin. out here the sweep is
      // cheap: an open area holds ~15 blocker rects against a tunnel's hundreds of wall cells, so it
      // casts ~7.5k ray/segment tests where a tunnel casts ~250k
      VisionMask.update(game, opts.player.x, opts.player.z);
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

package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import render.particles.LampLights;
import render.particles.LampPost;

// the city street area kind: procedural blocks from a citygen City, a moon whose shadow box
// follows the player, instanced lamp posts with a live spotlight pool, window light switches and
// the building occlusion fade. lifted out of render.View unchanged when render.Area3D landed —
// this is the whole of what used to be View's city-specific half
class CityArea implements Area3D
{
  var game:Game;
  var cityModel:City;                                     // read through city(), which the Area3D contract names
  var seed:Int;                                           // citygen seed (-1 = seedless reconstruction)
  var style:render.world.AreaStyle;                       // per-area textures + facade behaviour
  var chunks = new Chunks();
  var occlusion:Occlusion;                                // fades buildings blocking the player
  var moon:DirectionalLight;                              // shadow-casting moon, repositioned each frame
  var lampLights:LampLights;                              // live spotlight pool, ticked each frame
  var lampPosts:Array<LampPost>;                          // every placed lamp (for the pool)
  var lampProp:render.Models.InstancedProp;               // instanced lamp meshes, frustum-culled per frame
  var lampPropDead:render.Models.InstancedProp;           // dead lamps' posts (unlit bulb), culled alongside
  var coneFlick:render.LightCone.ConeSet;                 // flickering lamps' cones, repacked per frame
  var lampMask:Array<Bool>;                               // draw mask for lampProp — first entries are the flickering lamps
  var lampMaskDead:Array<Bool>;                           // its complement for lampPropDead (same posts, dark material)

  public function new(game:Game, city:City, seed:Int)
    {
      this.game = game;
      this.cityModel = city;
      this.seed = seed;
    }

// the city scene: night sky, city-span fog, fill lights + the moon, and the instanced lamp posts
// with their live spotlight pool
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      style = render.world.AreaStyle.forArea(game.area.typeID);
      var bundle = SceneSetup.buildScene(renderer, cityModel, lampPool, style);
      moon = bundle.moon;
      lampLights = bundle.lampLights;
      lampPosts = bundle.lampPosts;
      lampProp = bundle.lampProp;
      lampPropDead = bundle.lampPropDead;
      coneFlick = bundle.coneFlick;
      lampMask = bundle.lampMask;
      lampMaskDead = bundle.lampMaskDead;
      return bundle;
    }

// all lit world geometry, then the chunk buckets, then the occlusion fader over the result
  public function build(scene:Scene):Void
    {
      // snapshot what SceneSetup parented (lights, lamp cones, the city-wide lamp prop) so the
      // chunk pass only ever touches static geometry the world builder adds below
      var pre = scene.children.copy();
      World.build(scene, cityModel, seed, style);
      chunks.build(scene, pre);
      occlusion = new Occlusion(scene, cityModel.buildings, cityModel.tiles);
    }

// per-frame world tick: moon shadow box, window switches, occlusion fade, chunk cull and the
// live lamp pool (plus the flicker repack the posts and cones share)
  public function tick(opts:Area3DTickOpts):Void
    {
      // leaving: keep fading buildings that slide between the zooming-in camera and the (frozen)
      // player, so the marker stays visible through the outro. occlusion reads no game state
      if (opts.outro)
        {
          occlusion.update(opts.camPos, opts.player, null, false, opts.dtMs);
          return;
        }
      // keep the moon's shadow box centered on the player so building/lamp shadows track the view
      SceneSetup.fitMoon(moon, opts.player);
      // someone in the city flips a light: run the window switch countdowns BEFORE the occlusion
      // pass, so a building that is mid-fade re-copies its ghost on the same frame the window changed
      render.world.Windows.pulse(opts.dtMs);
      if (!opts.freeCam)
        occlusion.update(opts.camPos, opts.player, opts.target, opts.aiming, opts.dtMs);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      // park the live-spotlight pool on the nearest lamps to the player
      lampLights.update(lampPosts, opts.playerCol, opts.playerRow, opts.dtMs);
      // pull the cones of any flickering lamp that is mid-outage out of the draw (no-op most
      // frames), then hand the same on/off state to the post batches: a lamp that is out draws from
      // the DEAD batch instead, so its emissive head stops glowing and blooming for the outage
      render.LightCone.pulse(coneFlick, lampLights.flickT);
      for (i in 0...coneFlick.on.length)
        {
          lampMask[i] = coneFlick.on[i];
          lampMaskDead[i] = !coneFlick.on[i];
        }
      // drop offscreen lamp meshes: one InstancedMesh otherwise draws all ~280 whenever any is
      // visible. radius CELL*2 covers a lamp's full height as an edge margin so none pop at the edges
      render.Models.cull(lampProp, opts.camera, CityConfig.CELL * 2, lampMask);
      render.Models.cull(lampPropDead, opts.camera, CityConfig.CELL * 2, lampMaskDead);
    }

// tactical view toggle — the occlusion pass fades on a different rule when zoomed out
  public function setTactical(v:Bool):Void
    {
      occlusion.setTactical(v);
    }

// where the glow starts, per area style (a downtown of lit glass blooms at a different level)
  public function bloomThreshold():Float
    {
      return style.bloomThreshold;
    }

// the shallow street camera (~30 degrees at its closest)
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA;
    }

// seed-derived street debris (render-only, deterministic from the seed — no save cost); old
// seedless saves (seed -1) get none
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      if (seed == -1)
        return null;
      return render.world.Debris.build(seed, cityModel.tiles, game.area.typeID, game.area.highCrime);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// nothing to do: no city object draws as a glb prop, so ObjModels is never built up here and every
// object on the street is an atlas sprite the actor layer re-reads every frame anyway
  public function refreshObjects():Void
    {
    }

// the city this area was built from (the debug tools report against it)
  public function city():City
    {
      return cityModel;
    }
}

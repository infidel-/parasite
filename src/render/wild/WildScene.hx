package render.wild;

import three.Three;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;

// the scene + light rig for open wilderness. the city's rig minus everything the city put in it: a
// moon with the same shadow box, ambient and hemisphere fill, fog that closes the far edge — and no
// lamps at all, so no cones, no flicker and no bulbs for the pool to claim.
//
// CRITICAL: the live spotlight pool is still built, at the SAME size the city and the tunnels use.
// NUM_SPOT_LIGHTS is baked into every lit material's program key, and the actor billboards, particles
// and ground decals are shared across every area kind — so a wilderness that skipped the pool would
// recompile all of them on entry and again on the way back into a city. an empty pool costs a light
// evaluation per lit fragment, which is what the city already pays
class WildScene
{
// build the wilderness scene bundle (same contract render.SceneSetup.buildScene returns for a city)
  public static function build(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(WildStyle.SKY);
      // fog closes in nearer than the city's (220..480 over the same 400-unit area): a street ends at
      // a building face, open ground ends at nothing, so the far edge has to dissolve or the player
      // sees the area border as a hard line with black past it
      scene.fog = new Fog(WildStyle.SKY, WildStyle.FOG_NEAR, WildStyle.FOG_FAR);

      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      // fill, slightly UNDER the city's, and the split of labour is the point: the ART carries the
      // brightness out here and the moon carries the form. MEASURED in linear luminance, the ground
      // is 0.0503 (its own 0.75 lift, see textures.json) against the city road's 0.0329, so at
      // 1.5/1.2/1.7 it renders at 0.0334 — about 1.6x a city street, which is what open moonlit
      // grass should be beside a shadowed road. that leaves the MOON at 57% of flat-ground light, so
      // a tree's or a rock's shadow more than halves the ground under it.
      //
      // getting here needed both halves. an earlier pass ran 2.1/1.7 over the placeholder art and
      // was still too dark, because that art measured 0.0297 — below the road — while the fill was
      // being asked to make up the whole difference. lifting the ground instead let the fill come
      // back DOWN, which is what keeps the moon's share high enough to read.
      //
      // whatever this is retuned to, COMPUTE THE RATIO IN LINEAR SPACE and not on the sRGB byte
      // mean: three decodes an sRGB-tagged map before the lambert multiply, and the two are far
      // enough apart to send a retune the wrong way (render.sewer.SewerScene carries the obituary)
      var ambient = add(new AmbientLight(0x46536b, 1.5));
      var hemi = add(new HemisphereLight(0x56668c, 0x18211c, 1.2));
      // the moon carries more here than in the city, which is the one thing this rig has that a
      // tunnel does not: it is the ONLY directional term, so it is what gives a tree, a rock and the
      // relief Phase 2 adds a lit side and a shadow — i.e. the only cue that the ground is not paper
      var moon = cast(add(new DirectionalLight(0x8294c0, 1.7)), DirectionalLight);
      moon.position.set(-1, 2, 1.5);
      // the real moon shadow, verbatim from the city rig: one ortho box repositioned onto the player
      // each frame by SceneSetup.fitMoon. this is the whole of what makes a tree or a rock read as
      // standing ON the ground rather than pasted over it
      var MS = RenderConfig.MOON_SHADOW;
      moon.castShadow = true;
      untyped moon.shadow.mapSize.set(MS.mapSize, MS.mapSize);
      moon.shadow.bias = MS.bias;
      untyped moon.shadow.normalBias = MS.normalBias;
      var sc:Dynamic = moon.shadow.camera;
      sc.near = MS.near;
      sc.far = MS.far;
      sc.left = -MS.halfExtent;
      sc.right = MS.halfExtent;
      sc.top = MS.halfExtent;
      sc.bottom = -MS.halfExtent;
      sc.updateProjectionMatrix();
      scene.add(moon.target); // target must live in the scene graph so its world matrix updates each frame

      // the fixed live-spotlight pool (see the class header on why it exists with nothing to light).
      // the cone group stays empty and is still handed out, so debug 5/0 has the same handle here
      var coneGroup = new Group();
      scene.add(coneGroup);
      var lampLights = new LampLights(scene, lampPool);
      var pts:Array<Object3D> = [];
      for (l in lampLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      pts.push(coneGroup);

      // debug full-bright WYSIWYG + the light toggles, shared with the city rig
      var tail = SceneSetup.lightingTail(scene, renderer, lights);

      return {
        scene: scene,
        toggleLighting: tail.toggleLighting,
        setLightsOff: tail.setLightsOff,
        fill: [ ambient, hemi, moon ],
        lights: lights,
        moon: moon,
        pointLights: pts,
        coneGroup: coneGroup,
        lampLights: lampLights,
        lampPosts: [],           // no lamps out here, so the pool never claims a bulb
        lampCorners: new Map(),  // and no posts for the actor/camera slide to bend around
        lampProp: null,
        lampPropDead: null,
        coneFlick: null,         // nothing flickers: render.LightCone.pulse is never called
        lampMask: [],
        lampMaskDead: [],
        wallGlow: null,          // tunnels only
        // no glowing object props out here, and an unused slot is not free: three unrolls the
        // point-light loop into every lit material (see render.RenderConfig.PROP_LIGHT)
        propLights: null,
      };
    }
}

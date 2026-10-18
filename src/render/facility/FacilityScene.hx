package render.facility;

import three.Three;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;

// the scene + light rig for a facility. the wilderness rig's shape — moon, ambient and hemisphere
// fill, fog closing the far edge — because a facility is an open compound with buildings standing on
// it, not an enclosed level.
//
// CRITICAL, and the same note render.wild.WildScene carries: the live spotlight pool is built at the
// SAME size every other kind uses. NUM_SPOT_LIGHTS is baked into every lit material's program key,
// and the actor billboards, particles and ground decals are shared across every area kind, so a
// facility that sized its pool to its own needs would recompile all of them on entry and again on
// the way out. it was built here and left EMPTY for three phases for exactly that reason, which is
// why render.facility.FacilityLamps now costs nothing to add: the 12 spotlights were already in
// every program key and already running their per-fragment loop with no bulbs to show for it
class FacilityScene
{
// build the facility scene bundle (the contract render.SceneSetup.buildScene returns for a city),
// lit by one area kind's rig: the compound's FacilityStyle.rig(), the corp tower's sky and fog over
// that same fill, the military base's own
  public static function build(renderer:WebGLRenderer, lampPool:Int,
      rig:FacilityRigOpts):SceneSetup.SceneBundle
    {
      var sky = rig.sky;
      var near = rig.near;
      var far = rig.far;
      var scene = new Scene();
      scene.background = new Color(sky);
      // background and fog are the SAME colour, which render.world.VisionMask depends on: its blue
      // rim channel takes visibility to a true zero at the area border, and zero only stops being a
      // silhouette if the surface it fades toward is what is behind it
      scene.fog = new Fog(sky, near, far);

      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      // fill, in the rig's colours (FacilityStyle.rig says why the compound's runs dark)
      var ambient = add(new AmbientLight(rig.ambient, 1.35));
      var hemi = add(new HemisphereLight(rig.hemiSky, rig.hemiGround, 1.1));
      // the moon is the only directional term, so it is the whole of what gives a wall a lit side
      // and a shadow — the one cue that a building is standing on the lot rather than printed on it
      var moon = cast(add(new DirectionalLight(rig.moon, 1.6)), DirectionalLight);
      moon.position.set(-1, 2, 1.5);
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

      // the fixed live-spotlight pool (see the class header), and the empty cone group beside it so
      // the debug 5/0 keys have the same handle here as everywhere else
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
        // the bulbs are NOT placed here. every other kind's scene() knows its own lamps, but a
        // facility's come off the tile grid and out of the room list, which is the model the
        // BUILDERS hold — so render.facility.FacilityArea keeps its own post list and hands it to
        // the pool per frame, and this map is filled by render.facility.FacilityLamps during
        // build(). handing it over empty is safe: render.View passes the reference to the camera rig
        // and the actor layer, and both re-query it every frame
        lampPosts: [],
        lampCorners: new Map(),
        lampProp: null,
        lampPropDead: null,
        coneFlick: null,         // nothing flickers: render.LightCone.pulse is never called
        lampMask: [],
        lampMaskDead: [],
        wallGlow: null,          // tunnels only
        propLights: null,        // no glowing object props here
      };
    }
}

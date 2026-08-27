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
// SAME size every other kind uses even though nothing claims a bulb yet. NUM_SPOT_LIGHTS is baked
// into every lit material's program key, and the actor billboards, particles and ground decals are
// shared across every area kind, so a facility that skipped the pool would recompile all of them on
// entry and again on the way out. the ceiling fixtures that will claim those slots arrive with the
// lighting pass; the pool has to exist before them or that pass changes the key
class FacilityScene
{
// build the facility scene bundle (the contract render.SceneSetup.buildScene returns for a city)
  public static function build(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(FacilityStyle.SKY);
      // background and fog are the SAME colour, which render.world.VisionMask depends on: its blue
      // rim channel takes visibility to a true zero at the area border, and zero only stops being a
      // silhouette if the surface it fades toward is what is behind it
      scene.fog = new Fog(FacilityStyle.SKY, FacilityStyle.FOG_NEAR, FacilityStyle.FOG_FAR);

      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      // fill. the facility runs DARKER than the wilderness because its art is brighter: the lab
      // floor measures 0.0607 linear and the corridor lino 0.0750, against the wilderness turf's
      // 0.0503, and the interior is what fills the frame the moment the roof fades. the outdoor
      // surfaces are the city's own asphalt and pavement, which were painted for the city's fill
      var ambient = add(new AmbientLight(0x46536b, 1.35));
      var hemi = add(new HemisphereLight(0x56668c, 0x18211c, 1.1));
      // the moon is the only directional term, so it is the whole of what gives a wall a lit side
      // and a shadow — the one cue that a building is standing on the lot rather than printed on it
      var moon = cast(add(new DirectionalLight(0x8294c0, 1.6)), DirectionalLight);
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
        lampPosts: [],           // no lamps yet, so the pool never claims a bulb
        lampCorners: new Map(),  // and no posts for the actor/camera slide to bend around
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

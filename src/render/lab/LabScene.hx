package render.lab;

import three.Three;
import render.SceneSetup;
import render.particles.LampLights;

// the scene + light rig for the underground lab. the TUNNELS' shape and not the compound's: no sky,
// no moon and no shadow box — the bedrock is the ceiling — a near-black background, fog closing the
// far end of the corridor, a cold low fill, the shared live spotlight pool and the glowing object
// props' point-light pool.
//
// CRITICAL, the same note render.sewer.SewerScene carries: every light pool here matches the counts
// every other kind builds, because NUM_SPOT_LIGHTS / NUM_POINT_LIGHTS / NUM_DIR_LIGHTS are baked into
// every lit material's program key and the actors, particles and decals are shared across kinds. A
// moonless rig with both pools is exactly the sewer's light set, so a lab entry reuses the tunnels'
// programs rather than compiling its own copy of every shared material
class LabScene
{
// build the lab's scene bundle (the contract render.SceneSetup.buildScene returns for a city)
  public static function build(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(LabStyle.DARK);
      scene.fog = new Fog(LabStyle.DARK, LabStyle.FOG_NEAR, LabStyle.FOG_FAR);
      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      var ambient = add(new AmbientLight(LabStyle.AMBIENT, LabStyle.AMBIENT_I));
      var hemi = add(new HemisphereLight(LabStyle.HEMI_SKY, LabStyle.HEMI_GROUND, LabStyle.HEMI_I));
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
      var propLights = new render.particles.PropLights(scene);
      for (l in propLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      var tail = SceneSetup.lightingTail(scene, renderer, lights);
      return {
        scene: scene,
        toggleLighting: tail.toggleLighting,
        setLightsOff: tail.setLightsOff,
        fill: [ ambient, hemi ],
        lights: lights,
        moon: null,
        pointLights: pts,
        coneGroup: coneGroup,
        lampLights: lampLights,
        // the posts are LabArea's own, handed to the pool per frame (see FacilityScene's note)
        lampPosts: [],
        lampCorners: new Map(),
        lampProp: null,
        lampPropDead: null,
        coneFlick: null,
        lampMask: [],
        lampMaskDead: [],
        wallGlow: null,
        propLights: propLights,
      };
    }
}

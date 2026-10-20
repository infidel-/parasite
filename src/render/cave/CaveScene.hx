package render.cave;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;

// the scene + light rig for the mountain cave. like the tunnels, no sky, no moon and no shadow box:
// a near-black background, fog that closes in within a few cells and fill that IS the frame. unlike
// them there are no manholes and no wall brackets — the only shaped light is the night coming in at
// each cave mouth, plus whatever the habitat's grown organs give off.
//
// CRITICAL, as in render.sewer.SewerScene: the spotlight pool and the point-light pools must match
// the city's counts exactly, because NUM_SPOT_LIGHTS / NUM_POINT_LIGHTS are in every lit material's
// program key and a different count recompiles every shared material on the first cave entry
class CaveScene
{
// build the cave scene bundle (same contract render.SceneSetup.buildScene returns for a city)
  public static function build(renderer:WebGLRenderer, m:Sewer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(CaveStyle.DARK);
      // the tunnels' fog distances: the near plane clears the camera's own distance to the player
      scene.fog = new Fog(CaveStyle.DARK, CityConfig.CELL * 11, CityConfig.CELL * 30);

      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      // the fill carries the frame down here, normal-blind ambient first so the walls stay legible
      // against the floor. swept live in a generated cave against the cave art's built values (floor
      // 0.0445, wall 0.0929, rock top 0.1286 linear): the tunnels' 3.95 / 1.89 left the floor near
      // black, and their blue pair turned the warm silt purple — a neutral ambient and a barely cool
      // sky keep it earth-coloured
      var ambient = add(new AmbientLight(0x4e4d4a, 7.0));
      var hemi = add(new HemisphereLight(0x5c6272, 0x1c1814, 3.0));

      // one light per cave mouth: moonlight from behind the mouth, over the rock, aimed a few metres
      // into the cave so it pools on the floor in front of the opening
      var coneGroup = new Group();
      scene.add(coneGroup);
      var lampPosts:Array<LampPost> = [];
      for (l in m.lamps)
        {
          var w = CityConfig.cellToWorld(l.col, l.row);
          var dir = into(m, l.col, l.row);
          lampPosts.push({
            x: w.x - dir.x * CaveStyle.MOUTH_BACK,
            z: w.z - dir.z * CaveStyle.MOUTH_BACK,
            y: CityConfig.CELL * RenderConfig.LAMP_LIGHT.yMul,
            tx: w.x + dir.x * CaveStyle.MOUTH_REACH,
            tz: w.z + dir.z * CaveStyle.MOUTH_REACH,
            color: CaveStyle.MOUTH_COLOR,
            col: l.col,
            row: l.row,
            phase: 0.0,
            flick: 1.0,
            mul: CaveStyle.MOUTH_MUL,
          });
        }
      // no visible light cones down here (nothing hangs overhead), but the bundle carries a steady
      // and a flickering set either way; empty sets build no mesh
      var L = RenderConfig.LAMP_LIGHT;
      var bulbY = CityConfig.CELL * L.yMul;
      var coneFlick = render.LightCone.instanced({
        group: coneGroup,
        bulbs: [],
        bulbY: bulbY,
        radius: 1.0,
        topR: 0.2,
        phases: [],
      });
      var lampLights = new LampLights(scene, lampPool);
      var pts:Array<Object3D> = [];
      for (l in lampLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      pts.push(coneGroup);
      // the organs' own point-light pool, built HERE so the warm scene (render.cave.CaveWarm, which
      // calls this function) carries it too and NUM_POINT_LIGHTS matches the real cave
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
        lampPosts: lampPosts,
        lampCorners: new Map(),
        lampProp: null,
        lampPropDead: null,
        coneFlick: coneFlick,
        lampMask: [],
        lampMaskDead: [],
        wallGlow: coneFlick,
        propLights: propLights,
      };
    }

// the way into the cave from a mouth: away from the rock it backs onto (north, then west, then east,
// as gen.cave.CaveGen picks them), straight south for a mouth in the open
  public static function into(m:Sewer, col:Int, row:Int):{ x:Float, z:Float }
    {
      if (!SewerModel.isFloor(m, col, row - 1))
        return {
          x: 0.0,
          z: 1.0,
        };
      if (!SewerModel.isFloor(m, col - 1, row))
        return {
          x: 1.0,
          z: 0.0,
        };
      if (!SewerModel.isFloor(m, col + 1, row))
        return {
          x: -1.0,
          z: 0.0,
        };
      return {
        x: 0.0,
        z: 1.0,
      };
    }
}

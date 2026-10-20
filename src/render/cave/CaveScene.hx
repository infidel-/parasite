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
// them there are no manholes and no wall brackets — the shaped light is the night coming in at each
// cave mouth, the glowing crystals and fungus, and whatever the habitat's grown organs give off.
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
      // the fill, normal-blind ambient first so the walls stay legible against the floor. the tunnels'
      // 3.95 / 1.89 left the floor near black and their blue pair turned the warm silt purple — a
      // neutral ambient and a barely cool sky keep it earth-coloured. the levels are CaveStyle's
      var ambient = add(new AmbientLight(CaveStyle.AMBIENT, CaveStyle.AMBIENT_I));
      var hemi = add(new HemisphereLight(CaveStyle.HEMI_SKY, CaveStyle.HEMI_GROUND, CaveStyle.HEMI_I));

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
            // the actors' fake shadows down the light, long and into the cave (asked for: the mouth
            // as the source); null threw a short round smudge from over the rock behind it
            beam: CaveStyle.MOUTH_BEAM,
          });
        }
      // and one per glowing piece, hung over and in front of it and aimed back down at its foot, so
      // its light pools round it, climbs the rock behind and throws the piece's own shadow up that
      // rock (asked for: "we lack any interesting lighting"). aimed OUT from the crown, the first
      // cut, it landed as a disc of light two units off the piece, a torch beam and not a glow. the
      // pool's idle slots: no new light, nothing recompiles
      for (g in CaveProps.glows(m))
        {
          var x = g.x + g.dx * CaveStyle.LIGHT_OUT;
          var z = g.z + g.dz * CaveStyle.LIGHT_OUT;
          var c = CityConfig.worldToCell(x, z);
          lampPosts.push({
            x: x,
            z: z,
            y: g.top * CaveStyle.LIGHT_Y,
            tx: g.x + g.dx * CaveStyle.LIGHT_AIM,
            tz: g.z + g.dz * CaveStyle.LIGHT_AIM,
            color: g.light.color,
            col: c.col,
            row: c.row,
            phase: 0.0,
            flick: 1.0,
            mul: g.light.mul,
            penumbra: CaveStyle.LIGHT_PENUMBRA,
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

package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import citygen.CityModel.City;
import render.particles.LampLights;
import render.particles.LampPost;

// persistent renderer + camera (created once; the WebGL context is expensive and
// browsers cap the number, so it is reused across area entries)
typedef Core = {
  renderer:WebGLRenderer,
  camera:PerspectiveCamera,
};

// per-city scene (rebuilt on each city entry — lamps/lights depend on the city)
typedef SceneBundle = {
  scene:Scene,
  toggleLighting:Void->Bool,
  setLightsOff:Void->Void,
  fill:Array<Object3D>, // [ambient, hemisphere, moon] — the global fill lights (debug 2/3/4 toggles)
  pointLights:Array<Object3D>, // lamp spotlight pool + cone group (debug 5 toggle)
  lampLights:LampLights, // fixed live-spotlight pool, ticked per frame to follow the player
  lampPosts:Array<LampPost>, // every placed lamp (bulb world x/z + cell) for the pool
  lampCorners:Map<Int,Int>, // grid vertex (ActorAnim.lampVertexKey) -> lamp dir, so the slide bends past a post
  lampProp:render.Models.InstancedProp, // instanced lamp meshes, frustum-culled per frame
};

class SceneSetup {
// create the renderer + camera once, bound to the given canvas. The resize
// listener is registered here (once) so it does not pile up per city entry.
  public static function createCore(canvas:Dynamic):Core {
    var renderer = new WebGLRenderer({ canvas: canvas, antialias: true });
    renderer.setPixelRatio(Math.min(Browser.window.devicePixelRatio, 1.25));
    renderer.setSize(Browser.window.innerWidth, Browser.window.innerHeight);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.5;
    renderer.shadowMap.enabled = false;

    // far plane clipped to just past the fog wall (fog is opaque at span*1.2): beyond it every
    // building is solid fog yet still drawn, so a shallow/parallel camera would render the whole
    // far half of the city for nothing. clipping there lets three.js frustum-cull the invisible half
    var far = CityConfig.CELL * CityConfig.GRID * 1.25;
    var camera = new PerspectiveCamera(
      RenderConfig.CAMERA.fov,
      Browser.window.innerWidth / Browser.window.innerHeight,
      0.1, far);

    Browser.window.addEventListener('resize', function(_) {
      camera.aspect = Browser.window.innerWidth / Browser.window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(Browser.window.innerWidth, Browser.window.innerHeight);
    });

    return { renderer: renderer, camera: camera };
  }

// build a fresh scene (background, fog, fill lights, per-lamp point lights) for a city
  public static function buildScene(renderer:WebGLRenderer, city:City):SceneBundle {
    var scene = new Scene();
    scene.background = new Color(0x0a0d15);
    var span = CityConfig.CELL * CityConfig.GRID;
    scene.fog = new Fog(0x0a0d15, span * 0.55, span * 1.2);

    // all toggleable fill lights
    var lights:Array<Object3D> = [];
    function add(l:Object3D):Object3D { lights.push(l); scene.add(l); return l; }

    var pts:Array<Object3D> = []; // lamp point lights, kept as refs for the debug 5 toggle
    // the global fill lights, kept as refs so debug hotkeys (2/3/4) can toggle them individually
    var ambient = add(new AmbientLight(0x4a5874, 1.6));
    var hemi = add(new HemisphereLight(0x5a6a92, 0x1a2030, 1.3));
    var moon = add(new DirectionalLight(0x8294c0, 0.8));
    moon.position.set(-1, 2, 1.5);

    // street lamps: MANY cheap posts + cones (instanced) decoupled from a small FIXED pool of live
    // spotlights that follow the player (render.particles.LampLights), so the city can place hundreds
    // of lamps while NUM_SPOT_LIGHTS stays constant. yaw faces the post toward its road (Lamp.dir);
    // the bulb is pushed out over the road edge (local dz rotated by yaw) so the light lands on the road
    var L = RenderConfig.LAMP_LIGHT;
    var coneGroup = new Group();
    scene.add(coneGroup);
    var lampPosts:Array<LampPost> = [];
    var lampCorners:Map<Int,Int> = new Map(); // grid vertex -> lamp dir, so the actor/camera slide bends past a post
    var placements:Array<{ x:Float, z:Float, yaw:Float }> = [];
    var bulbs:Array<{ x:Float, z:Float }> = [];
    for (lamp in city.lamps) {
      var w = CityConfig.cellToWorld(lamp.col, lamp.row);
      // dir -> yaw so local +z points toward the road (0:+z, 1:-z, 2:+x, 3:-x)
      var yaw = switch (lamp.dir) { case 0: 0.0; case 1: Math.PI; case 2: Math.PI / 2; default: -Math.PI / 2; };
      var cos = Math.cos(yaw), sin = Math.sin(yaw);
      var px = w.x + L.pdx * cos + L.pdz * sin; // post nudged within its cell (edge / toward wall)
      var pz = w.z - L.pdx * sin + L.pdz * cos;
      var bx = px + L.dx * cos + L.dz * sin;    // bulb offset FROM the post, over the road edge
      var bz = pz - L.dx * sin + L.dz * cos;
      placements.push({ x: px, z: pz, yaw: yaw });
      bulbs.push({ x: bx, z: bz });
      lampPosts.push({ x: bx, z: bz, col: lamp.col, row: lamp.row });
      // the cell corner (grid vertex) the post stands on, keyed for cornerBend to query
      var a = (lamp.dir == 1 || lamp.dir == 3) ? lamp.col - 1 : lamp.col;
      var b = (lamp.dir == 1 || lamp.dir == 2) ? lamp.row - 1 : lamp.row;
      lampCorners.set(ActorAnim.lampVertexKey(a, b), lamp.dir);
    }
    // posts + cones: one instanced draw call each, regardless of lamp count
    var lampProp = Models.instanced(scene, RenderConfig.MODELS.streetLamp, placements, CityConfig.CELL * 1.6);
    var bulbY = CityConfig.CELL * L.yMul;
    LightCone.instanced(coneGroup, bulbs, bulbY, bulbY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul);
    // the fixed live-spotlight pool (added to the scene by its ctor); registered for the debug toggles
    var lampLights = new LampLights(scene);
    for (l in lampLights.debugList()) { lights.push(l); pts.push(l); } // WYSIWYG (1) + setLightsOff + 5/0
    pts.push(coneGroup); // debug 5/0 hides the cones alongside the lamp lights

    // debug full-bright WYSIWYG: ambient intensity = π so albedo×1 = raw texel
    var debugAmbient = new AmbientLight(0xffffff, Math.PI);
    debugAmbient.visible = false;
    scene.add(debugAmbient);
    var debug = false;
    var toggleLighting = function():Bool {
      debug = !debug;
      for (l in lights) l.visible = !debug;
      debugAmbient.visible = debug;
      renderer.toneMapping = debug ? THREE.NoToneMapping : THREE.ACESFilmicToneMapping;
      return debug;
    };
    var setLightsOff = function():Void { for (l in lights) l.visible = false; };

    return {
      scene: scene,
      toggleLighting: toggleLighting,
      setLightsOff: setLightsOff,
      fill: [ ambient, hemi, moon ],
      pointLights: pts,
      lampLights: lampLights,
      lampPosts: lampPosts,
      lampCorners: lampCorners,
      lampProp: lampProp
    };
  }
}

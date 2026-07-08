package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import citygen.CityModel.City;

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
  pointLights:Array<Object3D>, // per-lamp point lights (debug 5 toggle)
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

    for (lamp in city.lamps) {
      var w = CityConfig.cellToWorld(lamp.col, lamp.row);
      var yaw = 0.0; // TODO: per-lamp facing (rotate model + light offset together)
      // physical lamp post model, sized so its head sits near the light height
      Models.place(scene, RenderConfig.MODELS.streetLamp, w.x, w.z, CityConfig.CELL * 1.6, yaw);
      // conical spotlight at the bulb, aimed at a ground target so the cone is a downward street
      // pool (not an omni glow on the post). bulb pos + ground target both use the local dx/dz|tdx/tdz
      // knobs rotated by the lamp yaw
      var L = RenderConfig.LAMP_LIGHT; // pairs with MODELS.streetLamp2 placed above
      var cos = Math.cos(yaw), sin = Math.sin(yaw);
      var light = new SpotLight(0xffb866, 45, CityConfig.CELL * 12, L.angle, L.penumbra, 1.6);
      light.position.set(w.x + L.dx * cos + L.dz * sin, CityConfig.CELL * L.yMul, w.z - L.dx * sin + L.dz * cos);
      // aim target on the ground; must be in the scene graph for its world matrix to update
      var tgt = new Group();
      tgt.position.set(w.x + L.tdx * cos + L.tdz * sin, 0, w.z - L.tdx * sin + L.tdz * cos);
      scene.add(tgt);
      light.target = tgt;
      add(light);
      pts.push(light);
      // volumetric shaft: hollow additive cone aimed down the same bulb->target axis as the light,
      // so its base matches the lit circle. parented to the light, so it toggles with it
      var lh = CityConfig.CELL * L.yMul;
      LightCone.add(light, tgt.position.x, tgt.position.z, lh * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul);
      // tuning marker: small bright sphere at the light position to gauge it vs the model
      if (L.markerVisible) {
        var marker = new Mesh(new SphereGeometry(0.15, 8, 8), new MeshBasicMaterial({ color: 0xff2020 }));
        marker.position.copy(light.position);
        scene.add(marker);
      }
    }

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

    return { scene: scene, toggleLighting: toggleLighting, setLightsOff: setLightsOff, fill: [ambient, hemi, moon], pointLights: pts };
  }
}

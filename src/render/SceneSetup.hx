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

    var camera = new PerspectiveCamera(
      RenderConfig.CAMERA.fov,
      Browser.window.innerWidth / Browser.window.innerHeight,
      0.1, 1000);

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

    add(new AmbientLight(0x4a5874, 1.6));
    add(new HemisphereLight(0x5a6a92, 0x1a2030, 1.3));
    var moon = add(new DirectionalLight(0x8294c0, 0.8));
    moon.position.set(-1, 2, 1.5);

    for (lamp in city.lamps) {
      var w = CityConfig.cellToWorld(lamp.col, lamp.row);
      var light = add(new PointLight(0xffb866, 45, CityConfig.CELL * 12, 1.6));
      light.position.set(w.x, CityConfig.CELL * 1.6, w.z);
      var bulb = new Mesh(new SphereGeometry(0.25, 8, 8), new MeshBasicMaterial({ color: 0xffd9a0 }));
      bulb.position.copy(light.position);
      scene.add(bulb);
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

    return { scene: scene, toggleLighting: toggleLighting, setLightsOff: setLightsOff };
  }
}

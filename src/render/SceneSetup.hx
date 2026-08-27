package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import citygen.CityModel.City;
import render.Models.ModelVariant;
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
  lights:Array<Object3D>, // every toggleable light, as toggleLighting/setLightsOff see it. handed out so a
                          // live lamp-pool swap (View.setLampLights) can keep those closures correct

  moon:DirectionalLight, // the shadow-casting moon, ticked per frame by fitMoon to follow the player
  pointLights:Array<Object3D>, // lamp spotlight pool + cone group (debug 5 toggle)
  coneGroup:Object3D, // just the light cones, so debug Shift+5 can price the additive overdraw alone
  lampLights:LampLights, // fixed live-spotlight pool, ticked per frame to follow the player
  lampPosts:Array<LampPost>, // every placed lamp (bulb world x/z + cell) for the pool
  lampCorners:Map<Int,Int>, // grid vertex (ActorAnim.lampVertexKey) -> lamp dir, so the slide bends past a post
  lampProp:render.Models.InstancedProp, // instanced lamp meshes, frustum-culled per frame
  lampPropDead:render.Models.InstancedProp, // dead lamps' posts — same model, emissive stripped so the bulb neither glows nor blooms
  coneFlick:render.LightCone.ConeSet, // the flickering lamps' cone batch, repacked per frame so a cone goes dark with its bulb
  lampMask:Array<Bool>,     // per-instance draw mask for lampProp — entries 0..n-1 are the flickering lamps, cleared while one is out
  lampMaskDead:Array<Bool>, // the complement for lampPropDead, which holds the same n posts at the same indices
  wallGlow:render.LightCone.ConeSet, // sewer only (null in a city): the wall lamps' emissive quads, repacked
                                     // like coneFlick so a fixture stops glowing AND blooming while its bulb is out
  propLights:render.particles.PropLights, // sewer only (null in a city): fixed point-light pool for the
                                          // glowing object props, ticked per frame to follow the player
};

class SceneSetup {
// create the renderer + camera once, bound to the given canvas. The resize
// listener is registered here (once) so it does not pile up per city entry.
// scale = backbuffer pixels per CSS pixel (config vidRenderScale / 100).
  public static function createCore(canvas:Dynamic, scale:Float):Core {
    // no default-framebuffer MSAA: every city frame goes through the EffectComposer, whose
    // final OutputPass blits a fullscreen quad (no geometry edges to smooth). real AA lives on
    // the composer's offscreen render targets instead (View.setAA, config vidAntialias)
    var renderer = new WebGLRenderer({ canvas: canvas, antialias: false });
    // NOT devicePixelRatio: the street frame is fill-bound long before it is call-bound, and a
    // 125%-scaled desktop was silently costing 1.56x the pixels for it. measured GPU ~= 2.0ms +
    // 8.3ms per megapixel, i.e. ~80% of the frame scales with this one number (docs/3d-render.md)
    renderer.setPixelRatio(scale);
    renderer.setSize(Browser.window.innerWidth, Browser.window.innerHeight);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    // the authored default; View.setExposure scales it by the config brightness right after this
    renderer.toneMappingExposure = RenderConfig.EXPOSURE;
    // real shadows: one ortho pass for the moon (follows the player, see fitMoon) + a few fixed lamp
    // spotlight casters (LampLights). PCFSoft = cheap soft edges. casters/receivers are flagged
    // explicitly at each mesh creation site — never a blanket scene.traverse (would drag sprites/
    // transparent quads into the depth pass and cast square blobs)
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;

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

// the debug-lighting tail every scene ends with: a hidden full-bright WYSIWYG ambient (intensity π,
// so albedo x 1 = the raw texel) plus the two closures that flip it — debug key 1 and setLightsOff.
// shared by the city and the sewer rigs so the contract cannot drift between them: this used to be
// copied into render.sewer.SewerScene, which is exactly where a new fill slot would be forgotten
  public static function lightingTail(scene:Scene, renderer:WebGLRenderer, lights:Array<Object3D>):
    { toggleLighting:Void->Bool, setLightsOff:Void->Void }
    {
      var debugAmbient = new AmbientLight(0xffffff, Math.PI);
      debugAmbient.visible = false;
      scene.add(debugAmbient);
      var debug = false;
      return {
        toggleLighting: function():Bool
          {
            debug = !debug;
            for (l in lights) l.visible = !debug;
            debugAmbient.visible = debug;
            renderer.toneMapping = debug ? THREE.NoToneMapping : THREE.ACESFilmicToneMapping;
            return debug;
          },
        setLightsOff: function():Void
          {
            for (l in lights) l.visible = false;
          },
      };
    }

// moon direction (light comes FROM here toward the focus) — fixed, matches moon.position hint
  static var MOON_DIR = new Vector3(-1, 2, 1.5).normalize();

// park the moon's shadow box on the player each frame: sit the light up-direction from the focus and
// aim its target at the focus, so the fixed-size ortho shadow map covers the on-screen area (not just
// world origin). the box size/bias are static (RenderConfig.MOON_SHADOW) — only position/target move,
// which three folds into the shadow camera during render. call once per frame with the player world pos
  public static function fitMoon(moon:DirectionalLight, focus:Vector3):Void
    {
      var d = RenderConfig.MOON_SHADOW.distance;
      moon.position.set(focus.x + MOON_DIR.x * d, focus.y + MOON_DIR.y * d, focus.z + MOON_DIR.z * d);
      moon.target.position.copy(focus);
      moon.target.updateMatrixWorld();
    }

// build a fresh scene (background, fog, fill lights, per-lamp point lights) for a city.
// lampPool = how many live lamp spotlights to run (config vidLampLights)
  public static function buildScene(renderer:WebGLRenderer, city:City, lampPool:Int, ?style:render.world.AreaStyle):SceneBundle {
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
    // moon intensity bumped (was 0.8) so its removal in shadow actually reads against the ambient/hemi
    // fill — tune alongside ambient/hemi if the night mood shifts too far
    var moon = cast(add(new DirectionalLight(0x8294c0, 1.3)), DirectionalLight);
    moon.position.set(-1, 2, 1.5);
    // real moon shadow: one ortho shadow camera, box + bias from config. the box is repositioned each
    // frame by fitMoon so shadows track the player instead of sitting at world origin
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

    // street lamps: MANY cheap posts + cones (instanced) decoupled from a small FIXED pool of live
    // spotlights that follow the player (render.particles.LampLights), so the city can place hundreds
    // of lamps while NUM_SPOT_LIGHTS stays constant. yaw faces the post toward its road (Lamp.dir);
    // the bulb is pushed out over the road edge (local dz rotated by yaw) so the light lands on the road
    var L = RenderConfig.LAMP_LIGHT;
    // per-area lamp model + bulb/post offsets (null style or null lamp = residential defaults). only
    // the placement geometry is per-area; height/cone/pool stay on L, shared, so no shader recompile
    var lp = style != null ? style.lamp : null;
    var lampModel = lp != null ? lp.model : RenderConfig.MODELS.streetLamp;
    var ldx = lp != null ? lp.dx : L.dx;
    var ldz = lp != null ? lp.dz : L.dz;
    var lpdx = lp != null ? lp.pdx : L.pdx;
    var lpdz = lp != null ? lp.pdz : L.pdz;
    var coneGroup = new Group();
    scene.add(coneGroup);
    var lampPosts:Array<LampPost> = [];
    var lampCorners:Map<Int,Int> = new Map(); // grid vertex -> lamp dir, so the actor/camera slide bends past a post
    // broken/flickering lamps (slums): decided from the lamp CELL with the footprint-hash idiom, so the
    // same city always breaks the same lamps with no rng draw and nothing to persist. a dead lamp is
    // dropped from `bulbs` (no light cone) AND from `lampPosts`, so it never even enters the pool's
    // candidate list — the survivors near the player get MORE coverage, not less. its POST still stands,
    // but in its own instanced mesh with the emissive stripped, or the bulb keeps glowing and blooming
    var brokenPct = style != null ? style.lampBrokenRatio * 1000 : 0;
    var flickerPct = style != null ? style.lampFlickerRatio * 1000 : 0;
    var placements:Array<Models.PropPlace> = [];
    var dead:Array<Models.PropPlace> = [];
    var flickPlace:Array<Models.PropPlace> = []; // posts of the flickering lamps — in BOTH batches, see below
    // cones are split by fate: the steady ones are built once and never touched, the flickering ones
    // keep their phases so LightCone.pulse can drop a cone whose bulb is in its dark stretch
    var bulbs:Array<{ x:Float, z:Float }> = [];
    var bulbsFlick:Array<{ x:Float, z:Float }> = [];
    var phasesFlick:Array<Float> = [];
    for (lamp in city.lamps) {
      var w = CityConfig.cellToWorld(lamp.col, lamp.row);
      // dir -> yaw so local +z points toward the road (0:+z, 1:-z, 2:+x, 3:-x)
      var yaw = switch (lamp.dir) { case 0: 0.0; case 1: Math.PI; case 2: Math.PI / 2; default: -Math.PI / 2; };
      var cos = Math.cos(yaw), sin = Math.sin(yaw);
      var px = w.x + lpdx * cos + lpdz * sin; // post nudged within its cell (edge / toward wall)
      var pz = w.z - lpdx * sin + lpdz * cos;
      var bx = px + ldx * cos + ldz * sin;    // bulb offset FROM the post, over the road edge
      var bz = pz - ldx * sin + ldz * cos;
      var h = ((lamp.col * 73856093) ^ (lamp.row * 19349663)) & 0x7fffffff;
      if (h % 1000 < brokenPct)
        dead.push({ x: px, z: pz, yaw: yaw }); // post still stands, but its bulb is drawn unlit
      else
        {
          // a separate slice of the same hash, so breaking a lamp doesn't correlate with sputtering
          var flick = (h >>> 11) % 1000 < flickerPct;
          var phase = flick ? ((h >>> 17) % 628) / 100 : 0.0;
          if (flick)
            {
              flickPlace.push({ x: px, z: pz, yaw: yaw });
              bulbsFlick.push({ x: bx, z: bz });
              phasesFlick.push(phase);
            }
          else
            {
              placements.push({ x: px, z: pz, yaw: yaw });
              bulbs.push({ x: bx, z: bz });
            }
          lampPosts.push({
            x: bx,
            z: bz,
            y: CityConfig.CELL * L.yMul,
            tx: bx, // a street lamp pools straight down: the aim point is the ground under the bulb
            tz: bz,
            color: RenderConfig.LAMP_CONE.color, // sodium amber, matching the shaft hung under it
            col: lamp.col,
            row: lamp.row,
            phase: phase,
            flick: 1.0,
            mul: 1.0,
          });
        }
      // the cell corner (grid vertex) the post stands on, keyed for cornerBend to query
      var a = (lamp.dir == 1 || lamp.dir == 3) ? lamp.col - 1 : lamp.col;
      var b = (lamp.dir == 1 || lamp.dir == 2) ? lamp.row - 1 : lamp.row;
      lampCorners.set(ActorAnim.lampVertexKey(a, b), lamp.dir);
    }
    // posts: one instanced draw call each, regardless of lamp count. an area with broken lamps pays
    // one more for the dead posts (their material differs, so they cannot share the batch).
    // a FLICKERING lamp's post sits in BOTH batches, at index 0..n-1 of each, and the per-frame mask
    // picks which one draws it: its head is emissive, so an outage that only killed the spotlight and
    // the cone would leave the bulb glowing and blooming. both batches already repack every frame for
    // the frustum cull, so swapping a lamp between them costs nothing — no third draw call
    var lampProp = Models.instanced(scene, lampModel, flickPlace.concat(placements), CityConfig.CELL * 1.6, SOLID);
    var lampPropDead = Models.instanced(scene, lampModel, flickPlace.concat(dead), CityConfig.CELL * 1.6, DEAD);
    // prebuilt so the per-frame pass only rewrites the first n entries (the flickering lamps)
    var lampMask = [for (i in 0...(flickPlace.length + placements.length)) true];
    var lampMaskDead = [for (i in 0...(flickPlace.length + dead.length)) i >= flickPlace.length];
    var bulbY = CityConfig.CELL * L.yMul;
    // two cone batches, both in coneGroup so debug 5/0 still hides them together: the steady lamps'
    // (built once, never touched) and the flickering lamps' (repacked by LightCone.pulse so a cone
    // goes out with its bulb). an area with no flickering lamps builds no second mesh at all
    var coneR = bulbY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul;
    LightCone.instanced({
      group: coneGroup,
      bulbs: bulbs,
      bulbY: bulbY,
      radius: coneR,
      topR: RenderConfig.LAMP_CONE.topR,
    });
    var coneFlick = LightCone.instanced({
      group: coneGroup,
      bulbs: bulbsFlick,
      bulbY: bulbY,
      radius: coneR,
      topR: RenderConfig.LAMP_CONE.topR,
      phases: phasesFlick,
    });
    // the fixed live-spotlight pool (added to the scene by its ctor); registered for the debug toggles
    var lampLights = new LampLights(scene, lampPool);
    for (l in lampLights.debugList()) { lights.push(l); pts.push(l); } // WYSIWYG (1) + setLightsOff + 5/0
    pts.push(coneGroup); // debug 5/0 hides the cones alongside the lamp lights

    var tail = lightingTail(scene, renderer, lights);

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
      lampPosts: lampPosts,
      lampCorners: lampCorners,
      lampProp: lampProp,
      lampPropDead: lampPropDead,
      coneFlick: coneFlick,
      lampMask: lampMask,
      lampMaskDead: lampMaskDead,
      wallGlow: null, // no wall-mounted fixtures on a street
      // no object prop in a city lights, and an unused slot is not free: three unrolls the point-light
      // loop into every lit material, so a pool here would cost the street frame a full light
      // evaluation per fragment for nothing
      propLights: null
    };
  }
}

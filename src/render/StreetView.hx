package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import render.ActorAnim;
import game.Game;

// controller for the 3D street view. Owns a persistent renderer/camera on its own
// WebGL canvas and a per-city scene + bloom composer; runs its own rAF loop while a
// city area is shown. The game drives it directly (show/hide/resize) — no bridge.
// Movement stays in the game (PlayerArea); this view mirrors positions and billboards
// the player/AI/objects from the game's sprite atlas. Backtick toggles street-debug
// mode (fly cam F, poly UV editor E, building inspector B, lighting 1).
class StreetView {
  var game:Game;
  var canvas:Dynamic;
  var core:SceneSetup.Core;
  var renderer:WebGLRenderer;
  var camera:PerspectiveCamera;

  var scene:Scene;
  var composer:EffectComposer;
  var bloomPass:UnrealBloomPass;
  var toggleLighting:Void->Bool;
  var city:City;

  var actorGroup:Group;
  var ring:Mesh;
  var actors:Actors;                                      // the billboard actor layer
  var camSlide:PosSlide;                                  // camera target (player cell) slide

  var freeCam:FreeCam;
  var toolsAttached = false;
  var debugOn = false;
  var debugEl:js.html.Element;

  public var running(default, null):Bool = false;
  var shownSeed:Int = -2; // seed of the currently-built city (-2 = nothing built)
  var last = 0.0;

  var offset = new Vector3();
  var desired = new Vector3();
  var lookAt = new Vector3();
  var pWorld = new Vector3(); // current player world position (camera target)

  static inline var FPS = 30;

  public function new(game:Game) {
    this.game = game;
    ensureCanvas();
    injectDebugHud();
    // global debug hotkeys: ` toggles street-debug mode, 1 toggles WYSIWYG lighting
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!running) return;
      if (e.code == 'Backquote') setDebug(!debugOn);
      else if (debugOn && e.code == 'Digit1' && toggleLighting != null)
        bloomPass.enabled = !toggleLighting();
    });
  }

// is street-debug mode active? (the game suppresses movement input while it is)
  public inline function debugActive():Bool return debugOn;

// create the overlay WebGL canvas if absent (above the 2D #canvas, below the DOM HUD)
  function ensureCanvas():Void {
    canvas = Browser.document.getElementById('streetview');
    if (canvas != null) return;
    canvas = Browser.document.createElement('canvas');
    canvas.id = 'streetview';
    var s = canvas.style;
    s.position = 'absolute';
    s.left = '0';
    s.top = '0';
    s.width = '100%';
    s.height = '100%';
    s.zIndex = '1';
    s.display = 'none';
    Browser.document.body.appendChild(canvas);
  }

// inject the debug HUD elements the ported tools reference (hidden until debug on)
  function injectDebugHud():Void {
    if (Browser.document.getElementById('streetview-debug') != null) {
      debugEl = Browser.document.getElementById('streetview-debug');
      return;
    }
    var d = Browser.document.createElement('div');
    d.id = 'streetview-debug';
    d.style.display = 'none';
    // inline styling so it reads without the prototype's stylesheet
    d.innerHTML =
      '<div style="position:fixed;inset:0;z-index:300;pointer-events:none;font-family:monospace;color:#fff">' +
      '<div style="position:absolute;top:4px;left:8px;font-size:12px"><span id="mode"></span> <span id="editind"></span></div>' +
      '<div id="binfo" style="position:absolute;top:26px;left:8px;white-space:pre;font-size:11px;color:#9f9;max-width:44vw"></div>' +
      '<div id="poly" style="position:absolute;top:26px;right:8px;background:#000c;padding:6px;font-size:12px;pointer-events:auto;display:none"></div>' +
      '<div id="polybar" style="position:absolute;bottom:6px;right:8px;font-size:12px">' +
      '<span id="poly-dirty" style="display:none;color:#fc6">CLASSES UPDATED — Ctrl+C to copy</span> ' +
      '<span id="poly-check" style="display:none;color:#6f6">✓ copied</span></div>' +
      '</div>';
    Browser.document.body.appendChild(d);
    debugEl = d;
  }

// lazily create the persistent renderer/camera (one WebGL context, reused)
  function ensureCore():Void {
    if (core != null) return;
    core = SceneSetup.createCore(canvas);
    renderer = core.renderer;
    camera = core.camera;
  }

// attach the debug tools once (camera is persistent; scene/city read via getters)
  function attachTools():Void {
    if (toolsAttached) return;
    freeCam = new FreeCam(camera, canvas);
    Editor.attach(function() return scene, camera, canvas);
    Inspector.attach(function() return scene, camera, canvas, function() return city, function() return shownSeed);
    toolsAttached = true;
  }

// enter/leave street-debug mode (fly/editor/inspector + HUD)
  public function setDebug(on:Bool):Void {
    debugOn = on;
    if (on) attachTools();
    Tools.enabled = on;
    if (!on) {
      if (freeCam != null) freeCam.deactivate();
      Tools.setMode('none');
    }
    if (debugEl != null) debugEl.style.display = on ? 'block' : 'none';
  }

// show a city generated from a seed (new areas)
  public function show(seed:Int):Void {
    if (running && shownSeed == seed) return;
    buildFrom(CityGen.generate(seed), seed);
  }

// show a pre-reconstructed city (old saves with no seed)
  public function showCity(c:City):Void {
    buildFrom(c, -1);
  }

// (re)build the scene for a city and start the render loop
  function buildFrom(c:City, seed:Int):Void {
    ensureCore();
    city = c;
    shownSeed = seed;

    var bundle = SceneSetup.buildScene(renderer, city);
    scene = bundle.scene;
    toggleLighting = bundle.toggleLighting;
    World.build(scene, city);

    // player marker ring + the group holding all actor billboards
    ring = new Mesh(
      new RingGeometry(CityConfig.CELL * 0.42, CityConfig.CELL * 0.52, 40),
      new MeshBasicMaterial({
        color: 0xb46bff,
        transparent: true,
        opacity: 0.9,
        side: THREE.DoubleSide,
        depthWrite: false,
      }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    scene.add(ring);
    actorGroup = new Group();
    scene.add(actorGroup);
    // fresh area: new actor layer so billboards/slides/effects start clean
    actors = new Actors(game, actorGroup, camera);
    camSlide = null;

    // bloom: lit windows/lamps emit HDR (>1); bloom gives them a soft glow
    composer = new EffectComposer(renderer);
    composer.addPass(new RenderPass(scene, camera));
    bloomPass = new UnrealBloomPass(
      new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
      RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD);
    composer.addPass(bloomPass);
    composer.addPass(new OutputPass());

    offset.set(RenderConfig.CAMERA.offset.x, RenderConfig.CAMERA.offset.y, RenderConfig.CAMERA.offset.z);
    updatePlayerWorld(0);
    camera.position.copy(pWorld).add(offset);
    camera.lookAt(pWorld);

    canvas.style.display = 'block';
    if (!running) {
      running = true;
      last = 0;
      Browser.window.requestAnimationFrame(loop);
    }
  }

// stop rendering and hide the overlay (scene left for GC; renderer kept for reuse)
  public function hide():Void {
    running = false;
    shownSeed = -2;
    if (debugOn) setDebug(false);
    scene = null;
    composer = null;
    actorGroup = null;
    ring = null;
    actors = null;
    if (canvas != null) canvas.style.display = 'none';
  }

// forward a resize to the renderer/camera
  public function resize(w:Float, h:Float):Void {
    if (renderer == null) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
    if (composer != null) composer.setSize(w, h);
  }

// advance the camera target toward the player's grid cell (smoothed slide)
  function updatePlayerWorld(dtMs:Float):Void {
    var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    camSlide = ActorAnim.slideTo(camSlide, game.playerArea.x, game.playerArea.y, step);
    pWorld.set(camSlide.x, 0, camSlide.z);
  }

// rAF loop: mirror actors, follow the player (or fly), render the bloom frame
  function loop(t:Float):Void {
    if (!running) return;
    Browser.window.requestAnimationFrame(loop);
    var frameMs = 1000 / FPS;
    if (t - last < frameMs) return;
    var dtMs = last == 0 ? frameMs : t - last;
    last = t;

    updatePlayerWorld(dtMs);
    ring.position.set(pWorld.x, 0.06, pWorld.z);
    actors.update(dtMs);

    // free cam owns the camera while active; otherwise follow the player
    if (freeCam != null && freeCam.active)
      freeCam.update(dtMs);
    else {
      desired.copy(pWorld).add(offset);
      camera.position.lerp(desired, RenderConfig.CAMERA.follow);
      lookAt.copy(pWorld);
      lookAt.y += 1.5;
      camera.lookAt(lookAt);
    }

    composer.render();
  }
}

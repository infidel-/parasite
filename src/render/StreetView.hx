package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;
import render.anim.Shake;

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
  var rig:CameraRig;                                      // the follow camera + zoom
  var occlusion:Occlusion;                                // fades buildings blocking the player

  var freeCam:FreeCam;
  var toolsAttached = false;
  var debugOn = false;
  var debugEl:js.html.Element;

  public var running(default, null):Bool = false;
  var shownSeed:Int = -2; // seed of the currently-built city (-2 = nothing built)
  var last = 0.0;


  public function new(game:Game) {
    this.game = game;
    filterTextureWarning();
    ensureCanvas();
    injectDebugHud();
    // global debug hotkeys: ` toggles street-debug mode, 1 toggles WYSIWYG lighting
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!running) return;
      if (e.code == 'Backquote') setDebug(!debugOn);
      else if (debugOn && e.code == 'Digit1' && toggleLighting != null)
        bloomPass.enabled = !toggleLighting();
    });
    // wheel zooms the follow camera (up = in, down = out); debug keeps its own UV-scroll wheel
    Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!running || debugOn || rig == null) return;
      rig.zoomBy(e.deltaY > 0 ? 1 : -1);
    });
  }

// drop one benign three.js warning: world tile textures load async, so their per-building
// clones briefly render before the source image decodes (version>0, image==null) each area
// build — three warns every such frame. filter just that exact line, once, keep the rest
  function filterTextureWarning():Void {
    js.Syntax.code("(function(){ if (window.__texWarnFiltered) return; window.__texWarnFiltered = true; var w = console.warn.bind(console); console.warn = function(m){ if (typeof m === 'string' && m.indexOf('Texture marked for update but no image data') >= 0) return; return w.apply(console, arguments); }; })()");
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
    rig = new CameraRig(game, camera);
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
    occlusion = new Occlusion(scene, city.buildings);

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

    // bloom: lit windows/lamps emit HDR (>1); bloom gives them a soft glow
    composer = new EffectComposer(renderer);
    composer.addPass(new RenderPass(scene, camera));
    bloomPass = new UnrealBloomPass(
      new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
      RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD);
    composer.addPass(bloomPass);
    composer.addPass(new OutputPass());

    rig.reset();

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
    occlusion = null;
    if (canvas != null) canvas.style.display = 'none';
  }

// grip-struggle shake: jitter the parasite and its host out of phase (different amplitude,
// duration and wave phase) so they read as wrestling. no-op unless a city view is live
  public function playGripStruggle(parasite:Entity, host:Entity):Void
    {
      if (!running ||
          actors == null)
        return;
      var amp = CityConfig.CELL * 0.09;
      actors.playFx(parasite, new Shake(RenderConfig.BASE_MS, amp, 0));
      actors.playFx(host, new Shake(RenderConfig.BASE_MS * 1.3, amp * 0.7, Math.PI));
    }

// resist shake: jitter an actor as it lurches off in a direction the parasite didn't
// command (host resisting control mid-move). no-op unless a city view is live
  public function playResistShake(e:Entity):Void
    {
      if (!running ||
          actors == null)
        return;
      actors.playFx(e, new Shake(RenderConfig.BASE_MS, CityConfig.CELL * 0.07, 0));
    }

// forward a resize to the renderer/camera
  public function resize(w:Float, h:Float):Void {
    if (renderer == null) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
    if (composer != null) composer.setSize(w, h);
  }

// rAF loop: follow the player (or fly), mirror actors, render the bloom frame
  function loop(t:Float):Void {
    if (!running) return;
    Browser.window.requestAnimationFrame(loop);
    var frameMs = 1000 / game.config.vidFpsCap; // render cap (options: Video > FPS cap)
    // render up to the cap; small slack so a near-miss vsync frame (16.6ms vs a 16.67 budget)
    // isn't dropped to half-rate
    if (t - last < frameMs - 2) return;
    var dtMs = last == 0 ? frameMs : t - last;
    last = t;

    // free cam owns the camera while active; the rig still tracks the player so the ring follows
    var freeing = freeCam != null && freeCam.active;
    rig.update(dtMs, !freeing);
    if (freeing) freeCam.update(dtMs);
    var p = rig.playerWorld();
    // rest the ring on the player cell's ground surface (raised on walkways) so it doesn't sink
    var pe = game.playerArea.entity;
    ring.position.set(p.x, render.world.WorldCtx.floorY(pe.mx, pe.my) + 0.06, p.z);
    if (!freeing) occlusion.update(camera.position, p, dtMs);
    actors.update(dtMs);

    composer.render();
  }
}

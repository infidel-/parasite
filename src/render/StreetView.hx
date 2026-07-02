package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;

// smoothed grid->world position for one moving actor (and the camera target): last
// target cell, slide origin, live interpolated x/z, and tween progress (1 = settled)
typedef Slide = {
  col:Int, row:Int,          // last target grid cell
  fromX:Float, fromZ:Float,  // slide origin (world)
  x:Float, z:Float,          // current interpolated world pos
  t:Float                    // tween progress 0..1
};

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
  var pool:Array<Mesh> = [];                              // reused billboard meshes
  var texCache:Map<String, CanvasTexture> = new Map();    // atlas-crop -> texture
  // per-actor slide state, keyed by entity identity. ponytail: dead AI entities linger
  // here until the area rebuild clears the map — bounded per area, not worth pruning
  var slides:haxe.ds.ObjectMap<Entity, Slide> = new haxe.ds.ObjectMap();
  var camSlide:Slide;                                     // camera target (player cell) slide

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
  static inline var BILLBOARD = CityConfig.CELL * 0.85; // actor sprite world size

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
      new MeshBasicMaterial({ color: 0xb46bff, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    scene.add(ring);
    actorGroup = new Group();
    scene.add(actorGroup);
    pool = [];
    // fresh area: drop stale slides so actors snap to their start cells
    slides = new haxe.ds.ObjectMap();
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
    pool = [];
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
    camSlide = slideTo(camSlide, game.playerArea.x, game.playerArea.y, dtMs);
    pWorld.set(camSlide.x, 0, camSlide.z);
  }

// per-cell smoothstep slide toward grid (col,row): teleports (>~2 cells) snap, else the
// sprite slides from where it is now over MOVE_MS. mutates+returns s (null => settled at
// the cell). advances by dtMs each call; restarting mid-slide keeps motion continuous
  function slideTo(s:Slide, col:Int, row:Int, dtMs:Float):Slide {
    var w = CityConfig.cellToWorld(col, row);
    if (s == null)
      return { col: col, row: row, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1 };
    // cell changed: snap on a big jump (area entry, stairs), else start a fresh slide
    if (col != s.col || row != s.row)
      {
        var dx = w.x - s.x, dz = w.z - s.z;
        var lim = CityConfig.CELL * 1.9;
        if (dx * dx + dz * dz > lim * lim)
          { s.x = w.x; s.z = w.z; s.t = 1; }
        else
          { s.fromX = s.x; s.fromZ = s.z; s.t = 0; }
        s.col = col; s.row = row;
      }
    if (s.t < 1)
      {
        s.t = Math.min(1, s.t + dtMs / RenderConfig.MOVE_MS);
        var e = s.t * s.t * (3 - 2 * s.t); // smoothstep
        s.x = s.fromX + (w.x - s.fromX) * e;
        s.z = s.fromZ + (w.z - s.fromZ) * e;
      }
    return s;
  }

// fetch/advance the slide for an actor entity, keyed by identity
  function actorSlide(e:Entity, dtMs:Float):Slide {
    var s = slideTo(slides.get(e), @:privateAccess e.mx, @:privateAccess e.my, dtMs);
    slides.set(e, s);
    return s;
  }

// crop one atlas cell (imageName, ix, iy) into a cached texture
  function texFor(e:Entity):CanvasTexture {
    var name = @:privateAccess e.imageName;
    var ix = @:privateAccess e.ix;
    var iy = @:privateAccess e.iy;
    var key = name + ':' + ix + ':' + iy + ':' + e.isMaleAtlas;
    if (texCache.exists(key)) return texCache.get(key);
    var img:Dynamic = game.scene.images.getImage(name, e.isMaleAtlas);
    if (img == null || !img.complete || img.naturalWidth <= 0) return null; // retry next frame
    var t = Const.TILE_SIZE_CLEAN;
    var cv:Dynamic = Browser.document.createElement('canvas');
    cv.width = t; cv.height = t;
    // mirror Entity.drawImage crop (the +1/-1 kludge avoids atlas bleed)
    cv.getContext('2d').drawImage(img, ix * t, iy * t + 1, t, t - 1, 0, 0, t, t);
    var tex = new CanvasTexture(cv);
    tex.colorSpace = THREE.SRGBColorSpace;
    texCache.set(key, tex);
    return tex;
  }

// place/reuse a billboard mesh at world (wx,wz) with texture tex; returns next index
  function billboard(idx:Int, wx:Float, wz:Float, tex:CanvasTexture):Int {
    if (tex == null) return idx;
    var m = pool[idx];
    if (m == null) {
      m = new Mesh(new PlaneGeometry(BILLBOARD, BILLBOARD),
        new MeshBasicMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide }));
      pool[idx] = m;
      actorGroup.add(m);
    }
    var mat:Dynamic = m.material;
    mat.map = tex;
    mat.needsUpdate = true;
    m.position.set(wx, BILLBOARD * 0.5, wz);
    // Y-billboard: stand upright, yaw to face the camera
    m.rotation.y = Math.atan2(camera.position.x - wx, camera.position.z - wz);
    m.visible = true;
    return idx + 1;
  }

// rebuild all actor billboards (player + AI + objects) from live game state; moving
// actors slide between cells, static objects snap to their cell
  function updateActors(dtMs:Float):Void {
    var n = 0;
    // objects (sewer hatches etc.) — static, no slide
    for (o in game.area.getObjects())
      if (o.entity != null)
        {
          var w = CityConfig.cellToWorld(@:privateAccess o.entity.mx, @:privateAccess o.entity.my);
          n = billboard(n, w.x, w.z, texFor(o.entity));
        }
    // AI
    for (ai in @:privateAccess game.area._ai)
      if (ai.entity != null)
        {
          var s = actorSlide(ai.entity, dtMs);
          n = billboard(n, s.x, s.z, texFor(ai.entity));
        }
    // player (only drawn as parasite; in a host the host AI carries the sprite)
    if (game.player.state == _PlayerState.PLR_STATE_PARASITE) {
      var s = actorSlide(game.playerArea.entity, dtMs);
      n = billboard(n, s.x, s.z, texFor(game.playerArea.entity));
    }
    // hide leftover pooled meshes
    for (i in n...pool.length)
      if (pool[i] != null) pool[i].visible = false;
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
    updateActors(dtMs);

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

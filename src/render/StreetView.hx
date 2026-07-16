package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;
import render.choreo.Choreo;

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
  var shockwave:Shockwave;                                // screen-space ripple pass + pulse driver (silent scream)
  var toggleLighting:Void->Bool;
  var fill:Array<Object3D>; // [ambient, hemi, moon] fill lights (debug 2/3/4 toggles)
  var moon:DirectionalLight; // shadow-casting moon, repositioned each frame to follow the player
  var perf:StreetPerf; // perf instrumentation + debug keys 7/8/9 (see render.StreetPerf)
  // static-city spatial chunks: the world builder adds ~5.4k flat children to the scene, and three
  // walks + frustum-tests every one of them each frame to find the ~400 it draws. bucketing them under
  // chunk groups lets projectObject early-out on a whole block at once (an invisible parent is O(1))
  var chunks:Array<{ g:Group, sphere:Sphere }> = [];
  var chunkFrustum = new Frustum();
  var chunkMat = new Matrix4();
  var pointLights:Array<Object3D>; // lamp spotlight pool + cone group (debug 5 toggle)
  var lightsOff = false; // debug 0: master off-state for all fill + point lights
  var emissiveOff = false; // debug 6: kill all emissive (isolate lit/albedo from self-glow)
  var lampLights:render.particles.LampLights; // fixed live-spotlight pool, ticked each frame
  var lampPosts:Array<render.particles.LampPost>; // every placed lamp (for the pool)
  var lampProp:render.Models.InstancedProp; // instanced lamp meshes, frustum-culled per frame
  var city:City;

  var actorGroup:Group;
  var ring:Mesh;
  var ringY:Float = 0;                                    // eased ring floor height (curb step)
  var exiting = false;                                    // playing the leave zoom-in outro over the frozen last frame
  var exitDone:Void->Void = null;                         // runs when the outro completes (fade orchestration hook), else teardown
  var firstFrame:Void->Void = null;                       // one-shot, fires after the next presented frame (enter-fade reveal hook)
  var actors:Actors;                                      // the billboard actor layer
  var choreo:Choreo;                                      // combat/particle choreography context (render.choreo modules)
  var rig:CameraRig;                                      // the follow camera + zoom
  var occlusion:Occlusion;                                // fades buildings blocking the player
  var tacticalGrid:TacticalGrid;
  var tactical = false;

  var debug:Debug;                                        // street-debug mode (backquote): HUD + tools

  public var running(default, null):Bool = false;
  var svMouseX:Float = 0;                                 // last cursor client px over #streetview (AI-hover tooltip anchor)
  var svMouseY:Float = 0;
  var shownSeed:Int = -2; // seed of the currently-built city (-2 = nothing built)
  var last = 0.0;
  static inline var CHUNK_CELLS = 16; // spatial chunk edge, in city cells (16 * CELL 4 = 64 world units)
  var _warmed = false;    // did the full shader pre-warm run for this GL context? only the first city build pays it; later builds reuse the warm program cache (reset on page reload = fresh instance)
  var warming = false;    // that warm is in flight: the scene is built but `running` waits on it, so show() must not treat this build as absent and rebuild over it


  public function new(game:Game) {
    this.game = game;
    filterTextureWarning();
    ensureCanvas();
    debug = new Debug(game, canvas, function() return camera,
      function() return scene, function() return city, function() return shownSeed);
    // global debug hotkeys: ` toggles street-debug mode, 1 toggles WYSIWYG lighting,
    // 2/3/4 toggle the ambient / hemisphere / moon fill lights individually (isolate the point lights)
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!running) return;
      if (e.code == 'Backquote') setDebug(!debug.on);
      else if (debug.on && e.code == 'Digit1' && toggleLighting != null)
        bloomPass.enabled = !toggleLighting();
      else if (debug.on && fill != null && (e.code == 'Digit2' || e.code == 'Digit3' || e.code == 'Digit4')) {
        var i = e.code == 'Digit2' ? 0 : (e.code == 'Digit3' ? 1 : 2);
        fill[i].visible = !fill[i].visible;
      }
      else if (debug.on && e.code == 'Digit5' && pointLights != null)
        for (p in pointLights) p.visible = !p.visible;
      // 0: master toggle — flip every fill + point light to one shared on/off state
      else if (debug.on && e.code == 'Digit0' && fill != null && pointLights != null) {
        lightsOff = !lightsOff;
        for (f in fill) f.visible = !lightsOff;
        for (p in pointLights) p.visible = !lightsOff;
      }
      // 6: kill all emissive (self-glow) so only lit/albedo remains — stash each material's
      // original intensity in userData so the restore is exact regardless of per-material value
      else if (debug.on && e.code == 'Digit6' && scene != null) {
        emissiveOff = !emissiveOff;
        scene.traverse(function(o) {
          var m:Dynamic = o.material;
          if (m == null)
            return;
          var mats:Array<Dynamic> = Std.isOfType(m, Array) ? m : [m];
          for (mm in mats) {
            if (mm.emissive == null)
              continue; // only emissive-capable materials (MeshStandard/Phong; skips MeshBasic)
            if (emissiveOff) {
              if (mm.userData.emiI0 == null)
                mm.userData.emiI0 = mm.emissiveIntensity;
              mm.emissiveIntensity = 0;
            }
            else if (mm.userData.emiI0 != null) {
              mm.emissiveIntensity = mm.userData.emiI0;
              mm.userData.emiI0 = null;
            }
          }
        });
      }
      // 7/8/9: perf A/B + readouts (shadow-sampling toggle, peak reset, scene dump) — see render.StreetPerf
      else if (debug.on && perf != null)
        perf.onKey(e.code);
    });
    // wheel zooms the follow camera (up = in, down = out); debug keeps its own UV-scroll wheel
    Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!running || debug.on || rig == null) return;
      rig.zoomBy(e.deltaY > 0 ? 1 : -1);
    });
    // track the cursor over #streetview in raw client px for the AI-hover tooltip (the shared 2D
    // game.scene.mouseX/Y is device-px and stale here — #streetview sits over #canvas)
    canvas.addEventListener('mousemove', function(e:js.html.MouseEvent) {
      svMouseX = e.clientX;
      svMouseY = e.clientY;
    });
    // hold RMB (button 2) and drag to orbit the follow camera around the player (yaw + pitch);
    // release eases it back to the resting view. suppress the context menu so RMB is free
    canvas.addEventListener('contextmenu', function(e:js.html.MouseEvent) e.preventDefault());
    canvas.addEventListener('mousedown', function(e:js.html.MouseEvent) {
      if (!running || debug.on || tactical || exiting || e.button != 2 || rig == null) return;
      rig.orbitStart();
      canvas.style.cursor = 'none'; // hide the cursor while orbiting so it doesn't drift off-screen
    });
    // mouseup + orbit-drag on window so a release or fast drag that leaves the canvas still counts;
    // orbitDrag no-ops unless an orbit is live, so the window mousemove is cheap otherwise
    Browser.window.addEventListener('mouseup', function(e:js.html.MouseEvent) {
      if (e.button != 2 || rig == null) return;
      rig.orbitEnd();
      canvas.style.cursor = ''; // restore the cursor on release
    });
    Browser.window.addEventListener('mousemove', function(e:js.html.MouseEvent) {
      if (running && rig != null) rig.orbitDrag(e.movementX, e.movementY);
    });
  }

// drop one benign three.js warning: world tile textures load async, so their per-building
// clones briefly render before the source image decodes (version>0, image==null) each area
// build — three warns every such frame. filter just that exact line, once, keep the rest
  function filterTextureWarning():Void {
    js.Syntax.code("(function(){ if (window.__texWarnFiltered) return; window.__texWarnFiltered = true; var w = console.warn.bind(console); console.warn = function(m){ if (typeof m === 'string' && m.indexOf('Texture marked for update but no image data') >= 0) return; return w.apply(console, arguments); }; })()");
  }

// register a one-shot callback fired right after the next rendered frame (see the loop)
  public function onFirstFrame(cb:Void->Void):Void
    {
      firstFrame = cb;
    }

// is street-debug mode active? (the game suppresses movement input while it is)
  public inline function debugActive():Bool return debug.on;

// enter/leave street-debug mode (fly/editor/inspector + HUD — see render.Debug)
  public inline function setDebug(on:Bool):Void debug.set(on);

// enter/leave the tactical city view (no-op while idle or during the exit outro, which owns
// the zoom tween that setTactical would cancel)
  public function setTactical(v:Bool):Void
    {
      if (!running ||
          exiting ||
          tactical == v)
        return;
      tactical = v;
      rig.setTactical(tactical);
      occlusion.setTactical(tactical);
      if (tactical)
        tacticalGrid.show(game.playerArea.x, game.playerArea.y);
      else tacticalGrid.hide();
    }

// toggle the tactical city view and restore the normal follow view on exit
  public function toggleTactical():Void
    {
      setTactical(!tactical);
    }

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

// lazily create the persistent renderer/camera (one WebGL context, reused)
  function ensureCore():Void {
    if (core != null) return;
    core = SceneSetup.createCore(canvas);
    renderer = core.renderer;
    camera = core.camera;
    rig = new CameraRig(game, camera);
    perf = new StreetPerf(renderer, function() return scene);
  }

// show a city generated from a seed (new areas)
  public function show(seed:Int):Void {
    // a build whose shader warm is still in flight counts as shown: the warm holds `running` false for
    // ~2s after the build, and a repeat show() in that window would rebuild — disposing the very
    // materials the warm is still polling (three then throws from its poll timer, see buildFrom)
    if ((running || warming) && shownSeed == seed) return;
    buildFrom(CityGen.generate(seed), seed);
  }

// show a pre-reconstructed city (old saves with no seed)
  public function showCity(c:City):Void {
    buildFrom(c, -1);
  }

// (re)build the scene for a city and start the render loop
  function buildFrom(c:City, seed:Int):Void {
    ensureCore();
    // a load/rebuild replaces the scene without going through the menu-exit outro, so free the
    // previous build's GPU resources here too — otherwise every load orphans a whole city's
    // geometry in the (persistent) renderer's cache and geom climbs ~one city per load
    disposeBuild();
    city = c;
    shownSeed = seed;

    var bundle = SceneSetup.buildScene(renderer, city);
    scene = bundle.scene;
    toggleLighting = bundle.toggleLighting;
    fill = bundle.fill;
    moon = bundle.moon;
    pointLights = bundle.pointLights;
    lampLights = bundle.lampLights;
    lampPosts = bundle.lampPosts;
    lampProp = bundle.lampProp;
    rig.setLampCorners(bundle.lampCorners); // so the follow slide bends past lamp posts too
    // snapshot what SceneSetup parented (lights, lamp cones, the city-wide lamp prop) so the chunk
    // pass only ever touches static geometry the world builder adds below
    var preBuild = scene.children.copy();
    World.build(scene, city, seed);
    chunkStatics(preBuild);
    debug.onRebuild(); // fresh city: reset cycler indices + counts
    occlusion = new Occlusion(scene, city.buildings, city.tiles);
    tacticalGrid = new TacticalGrid(scene, game.area);

    // player marker ring + the group holding all actor billboards
    ring = new Mesh(
      new RingGeometry(CityConfig.CELL * 0.398, CityConfig.CELL * 0.448, 40),
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
    actors.setLampCorners(bundle.lampCorners); // route the actor slide around lamp posts
    // seed-derived street debris (render-only, deterministic from the seed — no save cost); old
    // seedless saves (seed -1) skip it
    if (seed != -1)
      actors.setDebris(render.world.Debris.build(seed, city.tiles, game.area.typeID, game.area.highCrime));

    // bloom: lit windows/lamps emit HDR (>1); bloom gives them a soft glow
    composer = new EffectComposer(renderer);
    setAA(game.config.vidAntialias); // MSAA sample count onto the fresh composer targets
    composer.addPass(new RenderPass(scene, camera));
    // silent-scream shockwave: warps the scene under the wave front; before bloom so the window
    // glow ripples with it. disabled (zero post cost) unless a pulse is live
    shockwave = new Shockwave(camera);
    composer.addPass(shockwave.pass);
    // combat/particle choreography context: bundles the game + this build's actor/camera/shockwave
    // layers for the render.choreo modules the game drives through (playShot/playMelee/…)
    choreo = new Choreo(game, actors, rig, shockwave);
    bloomPass = new UnrealBloomPass(
      new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
      RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD);
    composer.addPass(bloomPass);
    composer.addPass(new OutputPass());
    // let renderer.info accumulate across all composer passes: its OutputPass would otherwise
    // reset the per-frame draw stats to its own single quad, so we reset() manually each frame
    renderer.info.autoReset = false;

    // present: cancel any in-flight outro, reset the rig and start the enter intro + render loop.
    // deferred behind the cold-context warm below so the first real frame never stalls on an
    // on-demand shader compile (see below); runs immediately on warm entries
    var present = function()
      {
        exiting = false;   // cancel any in-flight outro from a prior area
        tactical = false;
        rig.reset();
        rig.startIntro();  // enter effect: start closest, zoom out to the resting target
        canvas.style.display = 'block';
        if (!running)
          {
            running = true;
            last = 0;
            Browser.window.requestAnimationFrame(loop);
          }
      };

    // pre-warm shader programs: on a cold GL context (fresh page/app launch) the first presented
    // frame otherwise stalls multiple seconds compiling every program at once. compileAsync hands
    // all scene programs to the driver in PARALLEL (KHR_parallel_shader_compile) without blocking
    // the JS thread — the window/HUD/audio stay live during the warm, and total time drops to the
    // slowest single program instead of the serial sum. we present only once it resolves (then one
    // throwaway composer pass warms the post-FX bloom/output programs compile can't reach). only the
    // first city build per GL context pays this — the program CACHE is keyed by shader source and
    // survives a rebuild, so later builds reuse it, skip the warm, and present() runs right away.
    // the warm does NOT survive its scene: compileAsync polls each material every 10ms from a timer,
    // so disposing them mid-warm (a rebuild) makes three throw out of that timer — the promise then
    // never settles and no catch can see it. `warming` keeps show() from rebuilding over this build
    if (!_warmed)
      {
        _warmed = true;
        warming = true;
        var tWarm = haxe.Timer.stamp();
        var progWarm0 = renderer.info.programs != null ? renderer.info.programs.length : 0;
        renderer.compileAsync(scene, camera).then(function(_)
          {
            warming = false;
            composer.render();
            var progWarm1 = renderer.info.programs != null ? renderer.info.programs.length : 0;
            trace('[street-warmup] compileAsync+postfx ' + StreetPerf.r2((haxe.Timer.stamp() - tWarm) * 1000) + 'ms' +
              ' programs ' + progWarm0 + '->' + progWarm1);
            present();
          });
      }
    else
      present();
  }

// begin leaving: play the zoom-in outro over the frozen last frame, then hand off. the game
// area is already despawned by the time this fires (so the outro reads no game state). called
// every frame while the region shows — a no-op once the outro is already running. onExitDone
// (if given) runs when the outro completes INSTEAD of teardown, so the caller can cover to
// black first and tear the view down under it (see GameScene.onCityExitDone)
  public function hide(?onExitDone:Void->Void):Void {
    if (!running || exiting) return;
    setTactical(false);
    // kill any live scream: nothing ticks pulses during the outro, a live one would freeze
    // as a static dome + stuck ripple over the whole exit
    shockwave.clear();
    exiting = true;
    exitDone = onExitDone;
    rig.zoomTweenTo(0, RenderConfig.CAMERA.exitMult, false, onOutroDone); // ungated: outro runs regardless of any window
  }

// outro tween finished: hand off to the exit-fade orchestrator if one was provided (it covers
// to black then calls teardown() under black), else tear down immediately
  function onOutroDone():Void {
    if (exitDone != null)
      {
        var cb = exitDone;
        exitDone = null;
        cb();
      }
    else teardown();
  }

// stop rendering and release the scene (fires when the outro completes, or under the exit fade)
  public function teardown():Void {
    running = false;
    exiting = false;
    shownSeed = -2;
    if (debug.on) setDebug(false);
    disposeBuild();
    scene = null;
    composer = null;
    shockwave = null;
    actorGroup = null;
    ring = null;
    actors = null;
    choreo = null;
    occlusion = null;
    tacticalGrid = null;
    tactical = false;
    if (canvas != null) canvas.style.display = 'none';
  }

// free the current build's GPU resources: actor pools, then the scene graph geometry/materials,
// then the composer's render targets. run on both teardown (menu exit) AND at the top of a
// rebuild (load) — the renderer persists across builds, so anything not disposed here stays in
// three's cache and geom climbs one whole city per load. does not null the fields (teardown
// handles that; a rebuild reassigns them immediately)
  function disposeBuild():Void
    {
      // actors own their pooled Sprites/DecalBatch buffers, so let them free first
      if (actors != null)
        actors.dispose();
      disposeScene();
      if (composer != null)
        composer.dispose(); // bloom + other post-FX render targets
    }

// dispose every geometry + material in the current scene graph. textures are shared and cached
// (Textures.hx, reused by the next build), so they're deliberately left alone — material.dispose()
// does not touch them. dispose() is idempotent, so actor meshes already freed above are harmless
  function disposeScene():Void
    {
      if (scene == null)
        return;
      scene.traverse(function(o:Object3D)
        {
          var g:Dynamic = untyped o.geometry;
          if (g != null)
            g.dispose();
          var m:Dynamic = untyped o.material;
          if (m == null)
            return;
          // material may be a single material or an array (multi-material meshes)
          if (Std.isOfType(m, Array))
            {
              var arr:Array<Dynamic> = m;
              for (mm in arr)
                mm.dispose();
            }
          else m.dispose();
        });
    }

// grip-struggle shake (parasite + host wrestle) — see render.choreo.Reactions
  public function playGripStruggle(parasite:Entity, host:Entity):Void
    {
      if (running)
        render.choreo.Reactions.gripStruggle(choreo, parasite, host);
    }

// resist shake (host lurches off in a direction the parasite didn't command) — see render.choreo.Reactions
  public function playResistShake(e:Entity):Void
    {
      if (running)
        render.choreo.Reactions.resistShake(choreo, e);
    }

// melee choreography (attacker lunge -> impact beat: sound + shake + blood) — see render.choreo.Melee
  public function playMelee(atkE:Entity, tgtE:Entity,
      atkCol:Int, atkRow:Int, tgtCol:Int, tgtRow:Int,
      soundFile:String, attackEffect:String, spawnBlood:Bool, bloodRow:Int, bloodFirstCol:Int):Bool
    {
      return running &&
        render.choreo.Melee.play(choreo, atkE, tgtE, atkCol, atkRow, tgtCol, tgtRow,
          soundFile, attackEffect, spawnBlood, bloodRow, bloodFirstCol);
    }

// gun-shot choreography (tracer + muzzle flash -> impact beat: blood/spark/sound, wall holes,
// player recoil) — see render.choreo.Shot
  public function playShot(atkE:Entity, sx:Int, sy:Int, tx:Int, ty:Int,
      hit:Bool, spawnBlood:Bool, bloodRow:Int, bloodCol:Int, soundKind:String, byPlayer:Bool):Bool
    {
      return running &&
        render.choreo.Shot.play(choreo, atkE, sx, sy, tx, ty,
          hit, spawnBlood, bloodRow, bloodCol, soundKind, byPlayer);
    }

// non-combat splat (bleeding drips / black noise, no attack beat) — see render.choreo.Splat
  public function playSplat(type:String, x:Int, y:Int, ?source:_Point):Bool
    {
      return running && render.choreo.Splat.play(choreo, type, x, y, source);
    }

// silent-scream choreography (ghostly dome + screen shockwave ripple) — see render.choreo.Scream
  public function playScream(x:Int, y:Int):Bool
    {
      return running && render.choreo.Scream.play(choreo, x, y);
    }

// thrown-projectile choreography (spit clot / spine needle -> impact splat beat) — see render.choreo.Projectile
  public function playProjectile(type:String, sx:Int, sy:Int, tx:Int, ty:Int,
      hit:Bool, bloodType:String):Bool
    {
      return running && render.choreo.Projectile.play(choreo, type, sx, sy, tx, ty, hit, bloodType);
    }

// thrown-money choreography (tumbling-bill fountain + lingering ground stains) — see render.choreo.Money
  public function playMoney(x:Int, y:Int, range:Int):Bool
    {
      return running && render.choreo.Money.play(choreo, x, y, range);
    }

// organ gas-cloud choreography (wide low additive shader dome: activation burst then lingering
// fade) — see render.choreo.Gas
  public function playGas(kind:String, x:Int, y:Int, range:Int):Bool
    {
      return running && render.choreo.Gas.play(choreo, kind, x, y, range);
    }

// snapshot a dying actor into a fade-out ghost (before its entity is nulled) — see render.choreo.Reactions
  public function playDeathFade(e:Entity):Void
    {
      if (running)
        render.choreo.Reactions.deathFade(choreo, e);
    }

// fade a freshly-spawned corpse body in, bound to the death ghost's landing — see render.choreo.Reactions
  public function bindBodyFadeIn(e:Entity, id:Int, ground:Bool):Void
    {
      if (running)
        render.choreo.Reactions.bindBodyFadeIn(choreo, e, id, ground);
    }

// drive the AI-hover tooltip while inspecting (Ctrl held): pick the AI nearest the cursor and
// anchor the DOM panel at its projected head px. runs every frame so the beam tracks the
// follow-camera. the 2D AITooltip stands down while this view runs (see AITooltip.update)
  function updateHoverTooltip():Void {
    var tip = game.ui.hud.aiTooltip;
    // not inspecting (no Ctrl / window open / mouse off): make sure it's hidden
    if (!game.ui.hud.isAIInspectMode()) {
      tip.hide();
      return;
    }
    var rect:Dynamic = canvas.getBoundingClientRect();
    var hit = actors.pickAI(svMouseX, svMouseY, rect);
    if (hit == null) {
      tip.hide();
      return;
    }
    tip.showBeamAt(hit.px, hit.py, hit.ai.id, tip.getTooltipText(hit.ai));
  }

// apply MSAA sample count to the running composer's render targets. n=0 disables.
// samples survive resize (composer.setSize clones renderTarget1, which copies samples);
// dispose() forces a realloc so a live change takes effect on the next composer.render()
  public function setAA(n:Int):Void
    {
      if (composer == null)
        return;
      var rt1:Dynamic = composer.renderTarget1;
      var rt2:Dynamic = composer.renderTarget2;
      rt1.samples = n;
      rt2.samples = n;
      rt1.dispose();
      rt2.dispose();
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
    // clamp a hitch: a build/texture-decode stall spikes dt, and dt-proportional tweens (zoom
    // intro/outro, slide) would fast-forward = a visible skip. cap it so one bad frame steps at
    // most ~2 frames of anim; the anim runs a hair behind real time instead of jumping
    if (dtMs > frameMs * 2)
      dtMs = frameMs * 2;
    var tFrame = haxe.Timer.stamp(); // frame-start: update-CPU = tR - tFrame (all pre-render work), idle = the rest

    // leaving: play the frozen zoom-in outro (no game reads) until its tween tears the view
    // down. teardown may fire mid-drift (nulls composer) — guard the render on it
    if (exiting) {
      rig.driftZoom(dtMs);
      // keep fading buildings that slide between the zooming-in camera and the (frozen) player,
      // so the marker stays visible through the outro (occlusion reads no game state)
      occlusion.update(camera.position, rig.playerWorld(), null, false, dtMs);
      if (running && composer != null) {
        renderer.info.reset();
        composer.render();
      }
      return;
    }

    // free cam owns the camera while active; the rig still tracks the player so the ring follows
    var freeing = debug.flying();
    rig.update(dtMs, !freeing);
    if (freeing) debug.freeCam.update(dtMs);
    var p = rig.playerWorld();
    // keep the moon's shadow box centered on the player so building/lamp shadows track the view
    SceneSetup.fitMoon(moon, p);
    // rest the ring on the ground under its *smooth* position, at the HIGHEST floor its whole
    // disc overhangs (sample the 4 footprint corners): a single-Y disc that dips below a curb it
    // straddles gets its overhanging arc buried and blinks. floating over the lower side reads
    // fine; sinking under the higher side does not. ease Y to soften the step.
    var rr = CityConfig.CELL * 0.448;                       // ring outer radius
    function fY(ox:Float, oz:Float):Float
      {
        var c = CityConfig.worldToCell(p.x + ox, p.z + oz);
        return render.world.WorldCtx.floorY(c.col, c.row);
      }
    var tgtY = Math.max(Math.max(fY(-rr, -rr), fY(rr, -rr)),
                        Math.max(fY(rr, rr), fY(-rr, rr))) + 0.06;
    // ease *down* (soft curb step) but snap *up* instantly: a lagging rise would leave the ring
    // buried under the walkway it just climbed onto
    if (tgtY > ringY)
      ringY = tgtY;
    else
      ringY += (tgtY - ringY) * (1 - Math.pow(1 - 0.4, dtMs / (1000 / 30)));
    ring.position.set(p.x, ringY, p.z);
    // fade buildings in front of the target: the live pick while aiming (wide corridor), else the
    // confirmed target so its occluders stay clear out of targeting mode too
    var aiming = game.ui.hud.state == HUD_TARGETING;
    var tt = aiming ? game.ui.hud.targeting.targetingTarget : game.ui.hud.targeting.target;
    var tgtPos:Vector3 = null;
    if (tt != null)
      {
        var w = CityConfig.cellToWorld(tt.x, tt.y);
        tgtPos = new Vector3(w.x, p.y, w.z);
      }
    if (!freeing) occlusion.update(camera.position, p, tgtPos, aiming, dtMs);
    cullChunks(p); // hide whole offscreen blocks so three skips their subtrees entirely
    // keep the tactical grid centered on the player (rebuilds only when the cell changes)
    if (tactical)
      tacticalGrid.show(game.playerArea.x, game.playerArea.y);
    // park the live-spotlight pool on the nearest lamps to the player, then hand the lit ones to the
    // actor layer so it casts fake shadows only from lamps that are actually lit this frame
    lampLights.update(lampPosts, game.playerArea.x, game.playerArea.y, dtMs);
    // drop offscreen lamp meshes: one InstancedMesh otherwise draws all ~280 whenever any is
    // visible. radius CELL*2 covers a lamp's full height as an edge margin so none pop at screen edges
    render.Models.cull(lampProp, camera, CityConfig.CELL * 2);
    actors.setLamps(lampLights.active());
    actors.update(dtMs);
    shockwave.update();
    updateHoverTooltip();

    // render pass timing: the composer stall (incl. any shader (re)compile) is invisible to the
    // turn/street-actor profilers — catch it here. frame = true rAF frame delta (dtMs), vsync-capped
    // at ~16.7ms @60fps = the real fps signal; submit = the cpu cost of queueing the render. the
    // breakdown, the real GPU timer and the on-screen readout all live in render.StreetPerf
    renderer.info.reset(); // manual per-frame reset (autoReset off); total accumulates over the passes
    var tR = haxe.Timer.stamp();
    perf.beginRender(debug.on);
    composer.render();
    perf.endRender();
    var submit = (haxe.Timer.stamp() - tR) * 1000;
    // first presented frame after (re)build: the enter fade reveals here, so the first-render
    // shader-compile stall (multi-second on a cold driver cache) stays hidden under black
    if (firstFrame != null)
      {
        var cb = firstFrame;
        firstFrame = null;
        cb();
      }
    perf.report(dtMs, submit, (tR - tFrame) * 1000); // upd = all pre-render work (occlusion/lamps/actors/tooltip)
    if (debug.on)
      Gizmo.draw(renderer, camera); // corner XYZ gizmo (after the stat capture)
  }

// a mesh's local bounding radius — used to spot city-spanning geometry that must NOT be chunked
  static function objRadius(d:Dynamic):Float
    {
      var g:Dynamic = d.geometry;
      if (g == null)
        return 1e9;
      var r:Float;
      if (d.isInstancedMesh == true)
        {
          d.computeBoundingSphere(); // instance-aware: a per-building window mesh is small, the city-wide lamp prop is not
          r = d.boundingSphere != null ? d.boundingSphere.radius : 1e9;
        }
      else
        {
          if (g.boundingSphere == null)
            g.computeBoundingSphere();
          r = g.boundingSphere != null ? g.boundingSphere.radius : 1e9;
        }
      var s:Dynamic = d.scale;
      return r * Math.max(s.x, Math.max(s.y, s.z));
    }

// bucket the static city into spatial chunk groups. the groups sit at identity, so every child keeps its
// local position and world matrix — pixel-identical output, only the traversal changes. world matrices
// are baked once here and the subtree then opts out of the per-frame matrix walk (nothing moves)
  function chunkStatics(pre:Array<Object3D>):Void
    {
      var CH = CityConfig.CELL * CHUNK_CELLS;
      var skip = new Map<String,Bool>();
      for (o in pre)
        skip.set(untyped o.uuid, true);
      var groups = new Map<String, Group>();
      for (o in scene.children.copy())
        {
          var d:Dynamic = o;
          if (skip.exists(d.uuid) ||
              (d.isMesh != true && d.isInstancedMesh != true))
            continue;
          // city-spanning meshes (ground, roads) keep their scene parent: bucketed by their single
          // origin they would pop out entirely the moment that one chunk culls
          if (objRadius(d) > CH)
            continue;
          var key = Math.floor(o.position.x / CH) + ':' + Math.floor(o.position.z / CH);
          var g = groups.get(key);
          if (g == null)
            {
              g = new Group();
              groups.set(key, g);
              scene.add(g);
            }
          g.add(o); // reparent — group is at identity, so the child's world transform is unchanged
        }
      scene.updateMatrixWorld(true); // bake every world matrix once, before the subtrees freeze
      chunks = [];
      for (g in groups)
        {
          var b = new Box3().setFromObject(g);
          var size = b.getSize(new Vector3());
          var sph = new Sphere();
          sph.center = b.getCenter(new Vector3());
          sph.radius = Math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z) / 2;
          untyped g.matrixWorldAutoUpdate = false; // static: skip this subtree in updateMatrixWorld forever
          chunks.push({ g: g, sphere: sph });
        }
      trace('[chunks] ' + chunks.length + ' groups (' + CHUNK_CELLS + ' cells each)');
    }

// per frame: frustum-test each CHUNK instead of each mesh. a chunk inside the moon's shadow box stays
// visible even when offscreen, else its buildings would stop casting shadows into view
  function cullChunks(p:Vector3):Void
    {
      if (chunks.length == 0)
        return;
      chunkMat.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      chunkFrustum.setFromProjectionMatrix(chunkMat);
      var R = RenderConfig.MOON_SHADOW.halfExtent;
      for (c in chunks)
        {
          var dx = c.sphere.center.x - p.x;
          var dz = c.sphere.center.z - p.z;
          var reach = R + c.sphere.radius;
          c.g.visible = (dx * dx + dz * dz) <= reach * reach || chunkFrustum.intersectsSphere(c.sphere);
        }
    }

}

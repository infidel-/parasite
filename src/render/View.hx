package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;
import render.Models.ModelVariant;
import render.choreo.Choreo;

// controller for the 3D area view. Owns a persistent renderer/camera on its own
// WebGL canvas and a per-area scene + bloom composer; runs its own rAF loop while a
// 3D area is shown (city streets and the underground tunnels — see render.Area3D for the
// per-kind half). The game drives it directly (show/hide/resize)
// — no bridge. Movement stays in the game (PlayerArea); this view mirrors positions and
// billboards the player/AI/objects from the game's sprite atlas. Backtick toggles
// street-debug mode (fly cam F, poly UV editor E, building inspector B, lighting 1).
class View {
  var game:Game;
  var canvas:Dynamic;
  var core:SceneSetup.Core;
  var renderer:WebGLRenderer;
  var camera:PerspectiveCamera;

  var scene:Scene;
  var composer:EffectComposer;
  var bloomPass:UnrealBloomPass;
  var gtaoPass:GTAOPass;                                  // ambient occlusion; skipped whole unless config vidAO
  var shockwave:Shockwave;                                // screen-space ripple pass + pulse driver (silent scream)
  var toggleLighting:Void->Bool;
  var fill:Array<Object3D>; // [ambient, hemi, moon] fill lights (debug 2/3/4 toggles)
  var lightList:Array<Object3D>; // the array toggleLighting/setLightsOff close over — kept in sync by setLampLights
  var perf:StreetPerf; // perf instrumentation + debug keys 7/8/9 (see render.StreetPerf)
  var pointLights:Array<Object3D>; // lamp spotlight pool + cone group (debug 5 toggle)
  var coneGroup:Object3D; // just the light cones (debug Shift+5), so cone overdraw prices apart from the spotlights
  var lightsOff = false; // debug 0: master off-state for all fill + point lights
  var emissiveOff = false; // debug 6: kill all emissive (isolate lit/albedo from self-glow)
  // debug V: live render scale, cycled through RENDER_SCALES. the frame is fill-bound on weak GPUs, so
  // pixel count is a first-class A/B knob — one that no other debug key can reach
  static final RENDER_SCALES = [ 1.25, 1.0, 0.75, 0.5 ];
  var scaleIdx = 0;
  var lampLights:render.particles.LampLights; // fixed live-spotlight pool, ticked each frame
  var area3d:Area3D; // the area KIND: scene/lights, static geometry and the per-frame world tick

  var actorGroup:Group;
  var ring:Mesh;
  var ringY:Float = 0;                                    // eased ring floor height (curb step)
  var exiting = false;                                    // playing the leave zoom-in outro over the frozen last frame
  var exitDone:Void->Void = null;                         // runs when the outro completes (fade orchestration hook), else teardown
  var firstFrame:Void->Void = null;                       // one-shot, fires after the next presented frame (enter-fade reveal hook)
  var actors:Actors;                                      // the billboard actor layer
  var choreo:Choreo;                                      // combat/particle choreography context (render.choreo modules)
  var rig:CameraRig;                                      // the follow camera + zoom
  var tacticalGrid:TacticalGrid;
  var pathLine:PathLine;                                  // mouse-hover move-path preview (wavy glowing ribbon + target dot)
  var tactical = false;

  var debug:Debug;                                        // street-debug mode (backquote): HUD + tools

  public var running(default, null):Bool = false;
  var svMouseX:Float = 0;                                 // last cursor client px over #view (AI-hover tooltip anchor)
  var svMouseY:Float = 0;
  var shownKey:Int = -2; // identity of the currently-built area: the city seed, or -(area id + 3) for a sewer (-2 = nothing built)
  var last = 0.0;
  var _warmed = false;    // did the full shader pre-warm run for this GL context? only the first city build pays it; later builds reuse the warm program cache (reset on page reload = fresh instance)
  var warming = false;    // that warm is in flight: the scene is built but `running` waits on it, so show() must not treat this build as absent and rebuild over it


  public function new(game:Game) {
    this.game = game;
    filterTextureWarning();
    ensureCanvas();
    // the city the debug tools report against comes from the built AREA, not a second field kept in
    // sync by hand — an underground area answers null and every reader already handles that
    debug = new Debug(game, canvas, function() return camera,
      function() return scene, function() return area3d == null ? null : area3d.city(),
      function() return shownKey);
    // global debug hotkeys: ` toggles street-debug mode, 1 toggles WYSIWYG lighting,
    // 2/3/4 toggle the ambient / hemisphere / moon fill lights individually (isolate the point lights),
    // V cycles the render scale, and Shift+1 / Shift+5 narrow 1 and 5 to bloom / cones alone
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!running) return;
      if (e.code == 'Backquote') setDebug(!debug.on);
      // Shift+1: bloom ALONE (plain 1 flips lighting and bloom together, so bloom's own cost was only
      // ever reachable by subtraction). the two share bloomPass.enabled — press one at a time
      else if (debug.on && e.shiftKey && e.code == 'Digit1' && bloomPass != null)
        bloomPass.enabled = !bloomPass.enabled;
      // Shift+5: the light cones ALONE. plain 5 hides the spotlight pool AND the cones (pointLights
      // bundles both), which cannot separate the 12-light fragment loop from the additive overdraw.
      // independent flips: 5 also touches the cone group, so return to baseline between measurements
      else if (debug.on && e.shiftKey && e.code == 'Digit5' && coneGroup != null)
        coneGroup.visible = !coneGroup.visible;
      else if (debug.on && e.code == 'Digit1' && toggleLighting != null)
        bloomPass.enabled = !toggleLighting();
      else if (debug.on && fill != null && (e.code == 'Digit2' || e.code == 'Digit3' || e.code == 'Digit4')) {
        var i = e.code == 'Digit2' ? 0 : (e.code == 'Digit3' ? 1 : 2);
        if (i < fill.length) // underground has no moon, so slot 2 is absent there
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
      // V: cycle the render scale. the frame goes fill-bound long before it goes call-bound on a weak
      // GPU, so pixel count is the one A/B knob no other debug key reaches (and the only way to price
      // a render-scale setting without a rebuild)
      else if (debug.on && e.code == 'KeyV' && composer != null) {
        scaleIdx = (scaleIdx + 1) % RENDER_SCALES.length;
        setRenderScale(RENDER_SCALES[scaleIdx]);
      }
      // 7/8/9: perf A/B + readouts (shadow-sampling toggle, peak reset, scene dump) — see render.StreetPerf
      else if (debug.on && perf != null)
        perf.onKey(e.code);
    });
    // wheel zooms the follow camera (up = in, down = out); debug keeps its own UV-scroll wheel.
    // a GUI window open (inventory/body/etc) overlays the view — let it scroll, don't zoom
    Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!running || debug.on || rig == null || game.ui.state != UISTATE_DEFAULT) return;
      rig.zoomBy(e.deltaY > 0 ? 1 : -1);
    });
    // track the cursor over #view in raw client px for the AI-hover tooltip (the shared 2D
    // game.scene.mouseX/Y is device-px and stale here — #view sits over #canvas). also feed
    // game.scene.mouseX/Y (device px, like UI.hx does for #canvas) + drive the mouse cursor/path so
    // the 3D view gets the old 2D hover behaviour (#view covers #canvas, so #canvas never sees it)
    canvas.addEventListener('mousemove', function(e:js.html.MouseEvent) {
      svMouseX = e.clientX;
      svMouseY = e.clientY;
      game.scene.mouseX = e.clientX * Browser.window.devicePixelRatio;
      game.scene.mouseY = e.clientY * Browser.window.devicePixelRatio;
      if (running && !debug.on && game.location == LOCATION_AREA)
        game.scene.mouse.onMove();
    });
    // click moves the player to / attacks the hovered tile (old 2D rules, via ui.Mouse.onClick).
    // LMB only; RMB owns camera orbit (handled below) and is left to onClick's own button gating
    canvas.addEventListener('click', function(e:js.html.MouseEvent) {
      if (!running || debug.on || exiting)
        return;
      game.scene.mouse.onClick(e);
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
      // restore the game move/attack cursor on release (force re-apply), not the OS arrow
      if (running && !debug.on && game.location == LOCATION_AREA)
        game.scene.mouse.update(true);
      else canvas.style.cursor = '';
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
      area3d.setTactical(tactical);
      actors.setTactical(tactical);
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
    canvas = Browser.document.getElementById('view');
    if (canvas != null) return;
    canvas = Browser.document.createElement('canvas');
    canvas.id = 'view';
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
    core = SceneSetup.createCore(canvas, game.config.vidRenderScale / 100);
    renderer = core.renderer;
    setExposure(game.config.vidBrightness); // the renderer is persistent, so this is the only place it needs applying
    camera = core.camera;
    rig = new CameraRig(game, camera);
    perf = new StreetPerf(renderer, function() return scene);
    // perf debug hook: live shader-program cache as cacheKeys. diff __progs() before/after an action
    // (e.g. first gas burst) to see which MeshStandardMaterial permutations the driver compiles on
    // first use — those first-use compiles are the frame hitches. count is the array length
    untyped js.Browser.window.__progs = function()
      {
        var ps:Array<Dynamic> = renderer.info.programs;
        return [for (p in ps) p.cacheKey];
      };
  }

// boot shader pre-warm: compile every street shader program on a THROWAWAY city (built by the real
// builders, so the material / instancing / light-count set matches the game exactly) BEFORE the player
// ever enters one, so the first real city entry reuses the cached programs and presents instantly
// instead of stalling ~2s under black compiling MeshStandard permutations on demand. runs once per GL
// context, off the menu idle (Main). the throwaway scene is retained (warmHold) so its materials keep
// their programs in three's refcounted, cacheKey-shared cache; a matching-key material in the real
// build then reuses them. covers the full static city + post-FX + gas + actor sprites + beams/sparks
// (ring/tactical share those programs — blending is render state, not a shader define). NOT covered, on
// purpose: silent-scream (its ctor needs live area state) and occlusion ghosts (compile on first fade) —
// both cheap one-off first-use hitches, warmed later via their own warmupMeshes if ever noticed
  static var warmHold:Dynamic = null;   // retains the warm scene so its materials' programs stay cached
  public function warmup():Void
    {
      if (_warmed || warmHold != null)
        return;
      _warmed = true;
      ensureCore();
      // real builders on a throwaway city -> exact programs, complete by construction, zero enumeration
      var seed = 1;
      var city = CityGen.generate(seed);
      // same lamp pool as the real scene: NUM_SPOT_LIGHTS is part of the program key, so warming at a
      // different pool size would compile programs the game then never uses
      var bundle = SceneSetup.buildScene(renderer, city, game.config.vidLampLights); // base scene + fixed light pools + lamp cones
      var s = bundle.scene;
      World.build(s, city, seed, null, false);             // all lit world geometry (instanced MeshStandard); audit off — throwaway city
      // also warm the downtown style's materials (glass facade/back, curtain windows, mechanical
      // penthouse, downtown ground) on a throwaway downtown city, parked in the same warm scene, so
      // the first high-density (AREA_CITY_HIGH) entry reuses the cached programs instead of recompiling
      var dtCity = CityGen.generate(seed, citygen.CityProfile.Profiles.forArea(AREA_CITY_HIGH));
      World.build(s, dtCity, seed, render.world.AreaStyle.forArea(AREA_CITY_HIGH), false);
      // and the slums style (house walls/windows/doors, shingle gable, slums ground, the dead-lawn
      // cutout) on a throwaway low-density city — a NEW GAME starts in AREA_CITY_LOW, so this is the
      // first city most sessions ever build
      var slCity = CityGen.generate(seed, citygen.CityProfile.Profiles.forArea(AREA_CITY_LOW));
      World.build(s, slCity, seed, render.world.AreaStyle.forArea(AREA_CITY_LOW), false);
      // the tunnels get their OWN warm scene, NOT a corner of the city's. a sewer has no
      // directional light at all, and NUM_DIR_LIGHTS / NUM_DIR_LIGHT_SHADOWS are part of every lit
      // material's program key — so wall/floor/ledge warmed under the city's moon compile
      // the wrong variant and recompile on the first real entry anyway (measured: 4 programs).
      // real builders again, so the match is by construction rather than by bookkeeping
      var sewerModel = render.sewer.SewerModel.demo();
      var sewerScene = render.sewer.SewerScene.build(renderer, sewerModel, game.config.vidLampLights).scene;
      render.sewer.SewerGeom.build(sewerScene, sewerModel);
      // and the muzzle-flash point-light pool, for the SAME reason the city warm scene parks one
      // below: Actors adds it to every real scene, tunnels included, and NUM_POINT_LIGHTS is in
      // every lit material's program key. without it the whole shell warms at 0 point lights and
      // recompiles at 5 on the first entry — measured by diffing __progs() around a sewer entry,
      // where every added lambert/basic key differed from its warmed twin in that one field
      var sewerFx = new Group();
      sewerScene.add(sewerFx);
      new render.particles.MuzzleLights(sewerFx);
      // the exit ladder prop warms in the SEWER scene (the city's moon would compile the wrong
      // light-count variant), but it has to wait for its glb — see the compile chain below
      // the downtown lamp (street-lamp2) is a distinct PBR material program from the residential lamp
      // buildScene already compiled — instance one into the warm scene so the first downtown entry
      // reuses it instead of recompiling on the first frame
      render.Models.instanced(s, render.RenderConfig.MODELS.streetLamp2, [{ x: 0.0, z: 0.0, yaw: 0.0 }], CityConfig.CELL * 1.6, SOLID);
      // on-demand effects never present at static-build time: park throwaway instances so they warm too
      var g = new Group();
      s.add(g);
      // the muzzle-flash point-light pool the real build adds via Actors: it sits in the scene forever at
      // intensity 0 so NUM_POINT_LIGHTS is constant, and that count is baked into EVERY lit material's
      // program — so the warm scene must carry it or every MeshStandard program compiles at the wrong
      // light count and recompiles on entry. this is the 5-light count (every non-barrel city); the
      // 10-light AREA_CITY_LOW variant is warmed by the second compile pass below (FlameLights added)
      new render.particles.MuzzleLights(g);
      for (m in render.particles.GasCloud3D.warmupMeshes()) // gas puffs (explicit front/back MeshStandard)
        g.add(m);
      for (m in render.particles.Sprites.warmupMeshes())    // actor billboards (MeshStandard + map/emissiveMap)
        g.add(m);
      // beams + hit sparks: spawn once via the REAL code so the exact materials get built (no config to
      // drift). streak (no map) + glow (map) cover both MeshBasic variants; beams share streak's program
      var beams = new render.particles.Beams(g);
      beams.quad(0, 0, 0, 1, 0, 0, 0xffffff, 1);
      var sparks = new render.particles.Sparks(g, camera);
      sparks.streak(0, 0, 0, 1, 0, 0, 1, 0.2, 0xffffff, 1);
      sparks.glowQuad(0, 0, 0, 1, 0xffffff, 1);
      // three renders a transparent DoubleSide (non-forceSinglePass) material as TWO single-side passes
      // (side FrontSide then BackSide), each its own program; compileAsync on the DoubleSide material
      // compiles a doubleSided program the runtime never uses (see the gas entry in docs/3d-render.md).
      // so for every such material in the scene, add explicit FrontSide + BackSide clone meshes so BOTH
      // real programs get cached instead of recompiling on the first render
      var quad = new PlaneGeometry(1, 1);
      var seen = new haxe.ds.ObjectMap<Dynamic, Bool>();
      var clones:Array<Mesh> = [];
      s.traverse(function(o:Object3D)
        {
          var mat:Dynamic = untyped o.material;
          if (mat == null)
            return;
          var mats:Array<Dynamic> = Std.isOfType(mat, Array) ? mat : [ mat ];
          for (mm in mats)
            {
              if (mm == null
                || seen.exists(mm))
                continue;
              seen.set(mm, true);
              if (mm.transparent == true
                && mm.side == THREE.DoubleSide
                && mm.forceSinglePass != true)
                for (side in [ THREE.FrontSide, THREE.BackSide ])
                  {
                    var c = mm.clone();
                    c.side = side;
                    clones.push(new Mesh(quad, c));
                  }
            }
        });
      for (c in clones)
        s.add(c);
      // park the moon's shadow box over the city so the composer pass below actually runs the shadow
      // depth pass — otherwise the box sits at world origin, the city-wide shadow caster falls outside it,
      // no depth material renders, and the position-only shadow programs compile on the first real frame
      var span = CityConfig.CELL * CityConfig.GRID;
      SceneSetup.fitMoon(bundle.moon, new Vector3(span / 2, 0, span / 2));
      // minimal composer (RenderPass + bloom + output) to warm the always-on post-FX programs; GTAO and
      // the shockwave pass are disabled/on-demand and compile on toggle regardless, so they're left out
      var comp = new EffectComposer(renderer);
      comp.addPass(new RenderPass(s, camera));
      comp.addPass(new UnrealBloomPass(
        new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
        RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD));
      comp.addPass(new OutputPass());
      // CRITICAL: the game renders scene -> the composer's LINEAR intermediate target (srgb-linear),
      // then OutputPass converts to sRGB. a program's cacheKey bakes in the bound target's color space,
      // so compileAsync against the default framebuffer (srgb) compiles the WRONG variant and the real
      // srgb-linear programs still compile on entry. bind the composer's linear target first so compile
      // produces exactly the programs the real render uses. compile walks the whole scene (not frustum-
      // culled), so this warms every material's real program in parallel, view-independent
      renderer.setRenderTarget(comp.renderTarget1);
      // compileAsync hands all scene programs to the driver in parallel (KHR_parallel_shader_compile)
      // without blocking; one composer pass then warms the post-FX programs compile can't reach.
      // TWO passes: NUM_POINT_LIGHTS is baked into every lit material's program, and low-tier cities
      // (AREA_CITY_LOW, where a NEW GAME starts) carry the barrel FlameLights pool -> 10 point lights
      // vs 5 everywhere else. warm the 5-count first, then add FlameLights and warm the 10-count, so
      // both variants are cached and neither the new-game start nor any later city recompiles on entry
      renderer.compileAsync(s, camera).then(function(_)
        {
          new render.particles.FlameLights(g);
          return renderer.compileAsync(s, camera);
        }).then(function(_)
        {
          // the exit prop's glb arrives over an async load, so it is instanced HERE rather than beside
          // the rest of the sewer warm scene: added after compileAsync had already walked that scene it
          // would miss the warm entirely and compile its PBR program on the first real tunnel entry.
          // all THREE variants go in — `transparent` and BackSide are both folded into three's program
          // cache key, so the ghost and the outline hull each compile a program of their own, and
          // without this they would compile on the first step onto a ladder / the first tactical toggle
          return new js.lib.Promise(function(res, _)
            {
              render.Models.get(render.RenderConfig.MODELS.sewerExit, function(_)
                {
                  var place = [{ x: 0.0, z: 0.0, yaw: 0.0 }];
                  var C = render.RenderConfig.OBJMARK;
                  var h = render.sewer.SewerStyle.EXIT_MODEL_H;
                  // patched exactly as the tunnel builders patch their own: the vision mask carries a
                  // customProgramCacheKey, so a prop warmed UNPATCHED warms a program the game never
                  // uses and recompiles on the first tunnel entry. it bites the SOLID variant hardest,
                  // which reuses the glb template's own shared material — the very object the real
                  // build then patches (render.sewer.SewerProps)
                  var M = render.sewer.SewerMask;
                  M.patchMesh(render.Models.instanced(sewerScene, render.RenderConfig.MODELS.sewerExit, place, h, SOLID).mesh);
                  M.patchMesh(render.Models.instanced(sewerScene, render.RenderConfig.MODELS.sewerExit, place, h, GHOST).mesh);
                  M.patchMesh(render.Models.instanced(sewerScene, render.RenderConfig.MODELS.sewerExit, place, h,
                    HULL(C.color, C.hullW)).mesh);
                  // the wall props have the same async-load trap, but only ONE variant each: they are
                  // decoration, so no ghost and no hull, and the whole set has to land before the
                  // compileAsync below walks this scene
                  var models = render.sewer.SewerStyle.PROP_MODELS;
                  var left = models.length;
                  for (i in 0...models.length)
                    {
                      var p = models[i];
                      render.Models.get(p.path, function(_)
                        {
                          M.patchMesh(render.Models.instanced(sewerScene, p.path, place, p.h, SOLID).mesh);
                          left--;
                          if (left == 0)
                            res(null);
                        });
                    }
                });
            });
        }).then(function(_)
        {
          return renderer.compileAsync(sewerScene, camera); // still bound to the linear target
        }).then(function(_)
        {
          renderer.setRenderTarget(null);
          comp.render();
          comp.dispose();
          // retain the whole warm scene: three releases a program only on material.dispose(), so holding
          // the materials keeps their programs cached. geometry is deliberately NOT disposed — several
          // geometries here are shared static models / particle quads, and disposing them would break the
          // real build. ponytail: one throwaway city's geometry stays resident; if boot RAM matters,
          // selectively dispose only the per-build World.build geometries (the safe ones) later.
          // both scenes are held — the tunnels' materials are the sewer half of the cache
          warmHold = [ s, sewerScene ];
          if (renderer.info.programs != null)
            js.Browser.console.log('[street-warmup] boot pre-warm: ' + renderer.info.programs.length + ' programs cached');
        });
    }

// show a city generated from a seed (new areas)
  public function show(seed:Int):Void {
    // a build whose shader warm is still in flight counts as shown: the warm holds `running` false for
    // ~2s after the build, and a repeat show() in that window would rebuild — disposing the very
    // materials the warm is still polling (three then throws from its poll timer, see buildFrom)
    if ((running || warming) && shownKey == seed) return;
    var c = CityGen.generate(seed, citygen.CityProfile.Profiles.forArea(game.area.typeID));
    buildFrom(new CityArea(game, c, seed), seed);
  }

// show a pre-reconstructed city (old saves with no seed)
  public function showCity(c:City):Void {
    buildFrom(new CityArea(game, c, -1), -1);
  }

// show the 3D sewer/habitat tunnels for an area, built from its saved tile grid (no seed — the
// grid IS the persisted layout, so this works on every existing save)
  public function showSewer(area:game.AreaGame):Void
    {
      var key = -(area.id + 3); // outside the seed range (seeds are >= 0, -1 = seedless city)
      if ((running || warming) && shownKey == key)
        return;
      buildFrom(new render.sewer.SewerArea(game, render.sewer.SewerModel.fromArea(area)), key);
    }

// (re)build the scene for an area kind and start the render loop
  function buildFrom(a:Area3D, key:Int):Void {
    ensureCore();
    // a load/rebuild replaces the scene without going through the menu-exit outro, so free the
    // previous build's GPU resources here too — otherwise every load orphans a whole city's
    // geometry in the (persistent) renderer's cache and geom climbs ~one city per load
    disposeBuild();
    area3d = a;
    shownKey = key;

    var bundle = a.scene(renderer, game.config.vidLampLights);
    scene = bundle.scene;
    toggleLighting = bundle.toggleLighting;
    fill = bundle.fill;
    lightList = bundle.lights;
    pointLights = bundle.pointLights;
    coneGroup = bundle.coneGroup;
    lampLights = bundle.lampLights;
    rig.setLampCorners(bundle.lampCorners); // so the follow slide bends past lamp posts too
    rig.setOffsets(a.cameraOffsets());      // the rig outlives the scene, so re-assert it per build
    a.build(scene);
    debug.onRebuild(); // fresh area: reset cycler indices + counts
    tacticalGrid = new TacticalGrid(scene, game.area);
    pathLine = new PathLine(game, scene);

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
    // ground debris: render-only and deterministic (from the city seed, or the sewer's own cell
    // hash) — no save cost. null where the area kind has none (a seedless old city save)
    var deb = a.debris();
    if (deb != null)
      actors.setDebris(deb);

    // bloom: lit windows/lamps emit HDR (>1); bloom gives them a soft glow
    composer = new EffectComposer(renderer);
    setAA(game.config.vidAntialias); // MSAA sample count onto the fresh composer targets
    composer.addPass(new RenderPass(scene, camera));
    // ambient occlusion: darkens where geometry meets (wall/ground, lamp bases, corners). before
    // bloom so the darkened crevices don't feed the glow. it renders its own depth + normal prepass
    // of the whole scene, so it stays enabled-gated — a disabled pass is skipped by the composer
    // and costs nothing (see setAO)
    gtaoPass = new GTAOPass(scene, camera, Browser.window.innerWidth, Browser.window.innerHeight);
    gtaoPass.blendIntensity = RenderConfig.GTAO.blendIntensity;
    gtaoPass.updateGtaoMaterial(RenderConfig.GTAO);
    gtaoPass.enabled = game.config.vidAO;
    sizeGtao(); // constructed in CSS px above; put its targets on the backbuffer scale
    composer.addPass(gtaoPass);
    // silent-scream shockwave: warps the scene under the wave front; before bloom so the window
    // glow ripples with it. disabled (zero post cost) unless a pulse is live
    shockwave = new Shockwave(camera);
    composer.addPass(shockwave.pass);
    // combat/particle choreography context: bundles the game + this build's actor/camera/shockwave
    // layers for the render.choreo modules the game drives through (playShot/playMelee/…)
    choreo = new Choreo(game, actors, rig, shockwave);
    bloomPass = new UnrealBloomPass(
      new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
      RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, a.bloomThreshold()); // per-area: WHEN the glow starts
    bloomPass.enabled = game.config.vidBloom; // re-assert per area — a fresh pass defaults to enabled
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
        // a warm re-show of the same seed skips the rebuild above and reuses the actor layer, which
        // would otherwise keep the previous visit's tactical flag (and its object outline rings)
        actors.setTactical(false);
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
        // gas clouds spawn on demand, so their 4 puff programs (2 material variants x front/back side of
        // the transparent DoubleSide material) are not otherwise in the scene at warm time and the first
        // burst compiles them mid-game (a visible hitch). park throwaway puff meshes in the scene for
        // this warm only, then remove once compileAsync resolves
        var gasWarm = render.particles.GasCloud3D.warmupMeshes();
        for (m in gasWarm)
          scene.add(m);
        renderer.compileAsync(scene, camera).then(function(_)
          {
            warming = false;
            composer.render();
            // remove the meshes (no per-frame draw cost) but DON'T dispose the materials — they are
            // retained in GasCloud3D.warmMats so their compiled programs stay cached for real bursts
            for (m in gasWarm)
              scene.remove(m);
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
// black first and tear the view down under it (see GameScene.on3DExitDone)
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
    shownKey = -2;
    if (debug.on) setDebug(false);
    disposeBuild();
    scene = null;
    composer = null;
    gtaoPass = null;
    shockwave = null;
    actorGroup = null;
    ring = null;
    actors = null;
    choreo = null;
    area3d = null;
    tacticalGrid = null;
    pathLine = null;
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
      // composer.dispose() only frees its OWN targets, never its passes: without this the AO pass
      // orphans 3 render targets + 2 noise textures in three's cache on every rebuild
      if (gtaoPass != null)
        gtaoPass.dispose();
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

// thrown-projectile choreography (a blob races source->target, then the impact splat beat) — see
// render.choreo.Projectile. type: 'acidSpit' | 'slimeSpit' | 'paralysisSpit' | 'needle' | 'blood'.
// 'blood' lobs a blood clot over a sine arc and bursts bloodType on landing; it has NO 2D
// counterpart in Particle.createProjectile, so a mod that wants the effect outside a 3D area
// ships its own 2D particle for that case (see examples/chainsaw)
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

// pick the city cell under a client-px cursor: unproject the cursor to a world ray, intersect the
// ground plane at the player's floor height, take that cell, then refine once at that cell's own
// floor height (curb cells sit a step up). returns {x:-1,y:-1} for the horizon / off-grid, which
// ui.Mouse treats as out-of-bounds. no Raycaster — the ground is a plane, not geometry
  public function pickCell(clientX:Float, clientY:Float):{ x:Int, y:Int }
    {
      var miss = { x: -1, y: -1 };
      if (camera == null)
        return miss;
      var rect:Dynamic = canvas.getBoundingClientRect();
      var ndcX = (clientX - rect.left) / rect.width * 2 - 1;
      var ndcY = -((clientY - rect.top) / rect.height * 2 - 1);
      // unproject a near-plane point to world, then the ray dir is (world - camera pos)
      var world = new Vector3(ndcX, ndcY, 0.5).unproject(camera);
      var ox = camera.position.x, oy = camera.position.y, oz = camera.position.z;
      var dx = world.x - ox, dy = world.y - oy, dz = world.z - oz;
      if (dy >= 0) // pointing at or above the horizon: no ground hit
        return miss;
      // intersect the plane y = planeY, twice: first at the player's floor, then at the hit cell's own
      // floor so a curb-height tile picks correctly
      var planeY = rig.playerWorld().y;
      var cell = miss;
      for (_ in 0...2)
        {
          var t = (planeY - oy) / dy;
          var hx = ox + dx * t;
          var hz = oz + dz * t;
          var c = CityConfig.worldToCell(hx, hz);
          // bound against the AREA, not the city grid: a sewer is smaller than GRID x GRID, and
          // cells past its edge are not walkable ground
          if (c.col < 0 ||
              c.row < 0 ||
              c.col >= game.area.width ||
              c.row >= game.area.height)
            return miss;
          cell = { x: c.col, y: c.row };
          var fy = render.world.WorldCtx.floorY(c.col, c.row);
          if (fy == planeY)
            break;
          planeY = fy; // refine at the cell's true height
        }
      return cell;
    }

// set the CSS cursor on the 3D view canvas (ui.Mouse routes cursor art here in the 3D view)
  public function setCursorCSS(css:String):Void
    {
      if (canvas != null)
        canvas.style.cursor = css;
    }

// show the move-path preview (wavy glowing ribbon + target dot) for a pathfinder cell list; no-op
// when the view isn't running (ui.Mouse funnels every hover path through AreaView.updatePath)
  public function setPathPreview(path:Array<aPath.Node>):Void
    {
      if (running && pathLine != null)
        pathLine.set(path);
    }

// has the player's move animation finished? false while its actor is still sliding into its cell,
// so ui.Mouse can hold the path preview frozen until the last step has visibly landed
  public function playerSettled():Bool
    {
      return (actors == null ||
        actors.playerSettled());
    }

// hide the move-path preview
  public function clearPathPreview():Void
    {
      if (pathLine != null)
        pathLine.clear();
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

// toggle the ambient-occlusion pass live. a disabled pass is skipped whole by the composer, so
// off means its depth/normal prepass never runs (no cost) — hence a plain enabled flip is enough
  public function setAO(on:Bool):Void
    {
      if (gtaoPass != null)
        gtaoPass.enabled = on;
    }

// toggle the bloom pass live (config vidBloom). skipped whole by the composer when off, and it is the
// LARGEST single removable pass on a fill-bound GPU — measured 3.7ms of a 14.7ms frame at lamp pool 12,
// and 3.4ms of a 9.0ms frame at pool 0, i.e. it matters most to whoever already gave up their lamps
// (docs/3d-render.md). the pass is always constructed and only gated here: never skip building it, or
// the plain `1` debug key below dereferences a null bloomPass. off is a real visual loss, not just a
// dimmer one — everything authored to glow (lit windows, tracers, the move-path line, the tactical
// grid) is HDR-multiplied with toneMapped:false and CLAMPS to flat saturated colour without the halo.
// NOTE debug keys 1 and Shift+1 write this same flag, so they desync the options switch until the next
// area build re-asserts the config value
  public function setBloom(on:Bool):Void
    {
      if (bloomPass != null)
        bloomPass.enabled = on;
    }

// set the 3D view brightness as a percentage of the authored exposure (config vidBrightness). the whole
// street frame renders into the composer's targets, where three forces every material to NoToneMapping,
// so ACES runs exactly once — in OutputPass, which re-reads renderer.toneMappingExposure EVERY frame.
// that makes this a pure uniform: no recompile, no pass rebuild, and (unlike vidBloom) no per-area
// re-assert, since the renderer outlives every scene. it multiplies BEFORE the tone curve, so it lifts
// the shadows and compresses the highlights rather than washing flat. two things it deliberately does
// NOT do: bloom is computed upstream of it, so the halos scale but never spread; and the fog/sky colour
// tone-maps with everything else, which is what greys out first and why the slider stops at 150%
  public function setExposure(pct:Int):Void
    {
      if (renderer == null)
        return;
      renderer.toneMappingExposure = RenderConfig.EXPOSURE * pct / 100;
    }

// resize the live lamp-spotlight pool (config vidLampLights). measured at ~0.32ms of GPU per light —
// three UNROLLS the spot loop into every lit material, so each slot is a real per-fragment cost. that
// same unrolling is why this cannot be free: NUM_SPOT_LIGHTS is part of the material program key, so
// swapping the pool recompiles every lit material on the next frame (a visible one-off stall, which is
// why this is a settings-screen action and never something gameplay does). n = 0 is legal and removes
// the spot block from the shaders entirely; the posts and cones are instanced and keep drawing
  public function setLampLights(n:Int):Void
    {
      if (lampLights == null ||
          scene == null)
        return;
      // drop the old pool out of the scene, stand up a new one, and re-register it everywhere the old
      // lights were held: pointLights (debug 5/0, also holds the cone group) and lightList (the array
      // buildScene's toggleLighting/setLightsOff closures read, so debug 1 keeps hiding lamps)
      for (l in lampLights.debugList())
        {
          pointLights.remove(l);
          lightList.remove(l);
        }
      lampLights.dispose();
      lampLights = new render.particles.LampLights(scene, n);
      for (l in lampLights.debugList())
        {
          pointLights.unshift(l);
          lightList.push(l);
        }
      area3d.setLampLights(lampLights); // the world tick drives the pool — re-bind it to the new one
      trace('[lamp-lights] pool -> ' + n);
    }

// set the render scale (backbuffer pixels per CSS pixel). the scene renders at w*s and the final
// OutputPass blit scales it back up, so below 1 this trades sharpness for fill — the dominant cost
// once the frame is GPU-bound. composer.setPixelRatio resizes rt1/rt2 AND every pass (incl. bloom's
// mip chain), so the renderer and the composer must be kept in step or the post targets stay stale.
  public function setRenderScale(s:Float):Void
    {
      if (composer == null)
        return;
      renderer.setPixelRatio(s);
      composer.setPixelRatio(s);
      sizeGtao();
      trace('[render-scale] ' + s + 'x -> ' + Math.round(Browser.window.innerWidth * s)
        + 'x' + Math.round(Browser.window.innerHeight * s));
    }

// size the AO pass to the BACKBUFFER, not the window. gtaoPass owns its depth/normal prepass and
// denoise targets, and composer.setPixelRatio does not reach them — so it is the one pass that has to
// be re-sized by hand on every resize AND every render-scale change, or AO samples a depth buffer at
// a different resolution than the frame it shades
  function sizeGtao():Void
    {
      if (gtaoPass == null)
        return;
      var s = renderer.getPixelRatio();
      gtaoPass.setSize(Browser.window.innerWidth * s, Browser.window.innerHeight * s);
    }

// forward a resize to the renderer/camera
  public function resize(w:Float, h:Float):Void {
    if (renderer == null) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
    if (composer != null) composer.setSize(w, h);
    sizeGtao();
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
      // keep fading whatever slides between the zooming-in camera and the (frozen) player, so the
      // marker stays visible through the outro. an outro tick reads no game state
      area3d.tick({
        camPos: camera.position,
        player: rig.playerWorld(),
        target: null,
        aiming: false,
        playerCol: 0,
        playerRow: 0,
        dtMs: dtMs,
        outro: true,
        freeCam: false,
        camera: camera,
      });
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
    // keep the tactical grid centered on the player (rebuilds only when the cell changes)
    if (tactical)
      tacticalGrid.show(game.playerArea.x, game.playerArea.y);
    // the world tick for this area kind: occlusion fades, window switches, chunk culling and the
    // live lamp pool (see render.CityArea / render.SewerArea)
    area3d.tick({
      camPos: camera.position,
      player: p,
      target: tgtPos,
      aiming: aiming,
      playerCol: game.playerArea.x,
      playerRow: game.playerArea.y,
      dtMs: dtMs,
      outro: false,
      freeCam: freeing,
      camera: camera,
    });
    // hand the lit lamps to the actor layer so it casts fake shadows only from lamps lit this frame
    actors.setLamps(lampLights.active());
    actors.update(dtMs);
    // the batched ground decals — street debris and plain blood — belong to the ACTOR layer, not to
    // the area, and their instanced groups are built lazily by the paint pass just above, so there is
    // no build-time moment for the tunnel mask to catch them the way every other surface is caught.
    // without this the debris underfoot stayed at full brightness in a corridor nobody can see.
    // gated because Actors is rebuilt per area but the mask uniforms are not: a patched material left
    // over above ground would sample the last tunnel's canvas. patch() marks its own hook and
    // early-outs, so a landed group is a couple of reads
    if (Std.isOfType(area3d, render.sewer.SewerArea))
      for (m in actors.decalMaterials())
        render.sewer.SewerMask.patch(m);
    shockwave.update();
    updateHoverTooltip();
    // re-evaluate the hovered cell + cursor each frame: the camera (and the player) move under a
    // still cursor, so the picked tile changes with no mousemove. ui.Mouse's own stale-check keeps
    // this to one plane-pick when nothing moved. then scroll/rebuild the path-preview wobble.
    // gated on the area still being the live location so a load/exit transition (running still true,
    // area despawned + entity links dropped) can't fault the render loop
    if (!debug.on &&
        game.location == LOCATION_AREA)
      game.scene.mouse.update();
    if (pathLine != null)
      pathLine.update(dtMs);

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

}

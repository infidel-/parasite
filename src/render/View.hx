package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;
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
  // the canvas's client rect, cached: reading it every frame forced a style recalc over the whole HUD
  // (~0.12-0.15 ms). dropped on resize and whenever the canvas is shown or hidden
  var canvasRect:Dynamic = null;
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
  var streetBlur:StreetBlur; // the corp street's distance blur (render.StreetBlur), off elsewhere

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

// an area object was added or removed in the area on screen — see Area3D.refreshObjects
  public function refreshObjects():Void
    {
      if (area3d != null)
        area3d.refreshObjects();
      // an object can block its own cell (a grown organ, a burning barrel), so this moved the
      // walkability the tactical grid was built from — and the grid otherwise only rebuilds when
      // the player's cell changes, which a player standing still growing an organ never does
      if (tacticalGrid != null)
        tacticalGrid.invalidate();
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

// boot shader pre-warm: compile every CITY shader program on a THROWAWAY city (built by the real
// builders, so the material / instancing / light-count set matches the game exactly) BEFORE the player
// ever enters one, so the first real city entry reuses the cached programs and presents instantly
// instead of stalling ~2s under black compiling MeshStandard permutations on demand. runs once per GL
// context, from Main, with the boot screen (#warmup in app.html) held up on `onDone`. WHAT it builds
// is render.CityWarm — a warm scene is a copy of a real build, so it lives next to the builders it
// copies; this end owns only the guard, the timing and the reporting.
// the TUNNELS and the FACILITY used to warm here too and no longer do: their props are ~20 glbs
// between them, and waiting for those loads put 7.6s on the boot screen (measured: 0.6s of blocked
// thread, 7s of glb reads and embedded-texture decodes) for art most sessions never reach. each is
// warmed on the FIRST ENTRY to its kind instead — see warmKind, which runs under the fader
// GameScene.draw3D has already brought to black.
// `onDone` fires exactly once, whichever way this ends — resolved, already warmed, or failed. the
// boot screen is held up by it, so a path that never calls it leaves a black screen the player cannot
// get past, which is why the chain below carries a catch
  static var warmedKinds:Map<String, Bool> = new Map(); // which per-kind warms have already run, keyed as warmKind keys them
  public function warmup(?onDone:Void->Void):Void
    {
      if (_warmed)
        {
          if (onDone != null)
            onDone();
          return;
        }
      _warmed = true;
      // the synchronous head of the build below is a second or more of blocked main thread. the boot
      // screen sits there for exactly that long plus the async tail, so both halves are reported on
      // the line at the end — CityWarm hands back the stamp it latched between them
      var t0 = haxe.Timer.stamp();
      ensureCore();
      var warm = CityWarm.build(renderer, camera, game.config.vidLampLights);
      // the chain is held in a TYPED local only so the catch below compiles to `.catch`: three's
      // compileAsync extern returns Dynamic, and `catchError` on a Dynamic is emitted verbatim, which
      // is not a method any promise has
      var chain:js.lib.Promise<Dynamic> = warm.p;
      chain.then(function(_)
        {
          js.Browser.console.log('[street-warmup] boot pre-warm: ' +
            (renderer.info.programs != null ? renderer.info.programs.length : -1) + ' programs cached, sync ' +
            StreetPerf.r2((warm.tSync - t0) * 1000) + 'ms, total ' +
            StreetPerf.r2((haxe.Timer.stamp() - t0) * 1000) + 'ms');
          if (onDone != null)
            onDone();
        });
      chain.catchError(function(e:Dynamic)
        {
          // a warm that throws used to just stop: the scene was never retained, the composer never
          // disposed and the renderer left bound to the warm target, which is a dead renderer. now it
          // also strands the boot screen, so unbind, say so, and let the game start unwarmed
          renderer.setRenderTarget(null);
          js.Browser.console.warn('[street-warmup] boot pre-warm failed, starting unwarmed: ' + e);
          if (onDone != null)
            onDone();
        });
    }

// per-kind shader warm, run once per area KIND on the FIRST entry to it, from GameScene.draw3D with
// the fader already black. the boot warm covers the city only; a tunnel's and a facility's props are
// ~20 glbs between them and waiting for those at boot put 7.6s on the warmup screen for art most
// sessions never reach. `kind` is game.area.info.type, and everything that is not a city, a
// wilderness or a facility renders through the tunnel view, so it warms as one. WHAT each kind
// builds is its own render.*Warm, next to the builders it copies; this end owns only the once-per-
// kind guard and the reporting.
// `done` fires exactly once, whichever way this ends — the fader stays black until it does, so a
// path that never calls it is a black screen the player cannot get past. that is what the catch and
// the timer are for; the timer is deliberately long, because cutting a warm short only moves the
// stall into the frame the player is about to see
// which per-kind warm this area kind belongs to. the city is the boot warm's own scene and the
// wilderness has never had one, so everything that is not a city, a wilderness, a facility or a
// corp tower renders through the tunnel view and warms as one
  static inline function warmKey(kind:String):String
    return (kind == 'facility' || kind == 'corp' ? kind : 'sewer');

// would `warmKind` actually have work to do for this area kind? asked by GameScene.draw3D BEFORE it
// commits to putting the warmup screen back up — a kind already warmed is a call-through and a
// screen for it would be a flash.
//
// `!_warmed` means the boot warm never ran, in which case buildFrom's own inline warm is still live
// and warmKind must not get in front of it
  public function needsWarm(kind:String):Bool
    {
      return kind != 'city' &&
        kind != 'wilderness' &&
        _warmed &&
        !warmedKinds.exists(warmKey(kind));
    }

  public function warmKind(kind:String, done:Void->Void):Void
    {
      var fired = false;
      var fire = function()
        {
          if (fired)
            return;
          fired = true;
          done();
        };
      // the guard is `needsWarm`'s, so the screen GameScene raises and the work done here cannot
      // disagree about whether there is any
      var key = warmKey(kind);
      if (!needsWarm(kind))
        {
          fire();
          return;
        }
      warmedKinds.set(key, true);
      var t0 = haxe.Timer.stamp();
      var chain:js.lib.Promise<Dynamic> = switch (key)
        {
          case 'facility': render.facility.FacilityWarm.build(renderer, camera, game.config.vidLampLights);
          case 'corp': render.corp.CorpWarm.build(renderer, camera, game.config.vidLampLights);
          default: render.sewer.SewerWarm.build(renderer, camera, game.config.vidLampLights);
        };
      chain.then(function(_)
        {
          js.Browser.console.log('[street-warmup] ' + key + ' warm: ' +
            (renderer.info.programs != null ? renderer.info.programs.length : -1) + ' programs cached, ' +
            StreetPerf.r2((haxe.Timer.stamp() - t0) * 1000) + 'ms');
          fire();
        });
      chain.catchError(function(e:Dynamic)
        {
          renderer.setRenderTarget(null);
          js.Browser.console.warn('[street-warmup] ' + key + ' warm failed, entering unwarmed: ' + e);
          fire();
        });
      Browser.window.setTimeout(fire, 20000);
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

// the build key for one of the grid-built area kinds. an id is one area and one area is one kind,
// but a key that COLLIDED would let a rebuild of another kind read as a warm re-show of this one —
// so each kind takes its own residue class rather than a parity. it was 2 residues while there were
// two such kinds and both were spent; a third needed the stride, not another offset. the corp tower
// took the fourth, so a FIFTH grid kind needs the stride widening again
  static inline function gridKey(id:Int, kind:Int):Int
    {
      return -(id * 4 + kind + 3); // outside the seed range (seeds are >= 0, -1 = seedless city)
    }

// show the 3D sewer/habitat tunnels for an area, built from its saved tile grid (no seed — the
// grid IS the persisted layout, so this works on every existing save)
  public function showSewer(area:game.AreaGame):Void
    {
      var key = gridKey(area.id, 0);
      if ((running || warming) && shownKey == key)
        return;
      buildFrom(new render.sewer.SewerArea(game, render.sewer.SewerModel.fromArea(area)), key);
    }

// show the 3D facility compound for an area, built from its saved tile grid for the same reason the
// tunnels are: game.FacilityAreaGenerator already wrote every wall, window, floor and door, and
// that grid is what the pathfinder walks around
  public function showFacility(area:game.AreaGame):Void
    {
      var key = gridKey(area.id, 2);
      if ((running || warming) && shownKey == key)
        return;
      buildFrom(new render.facility.FacilityArea(game,
        render.facility.FacilityModel.fromArea(area, iconBox)), key);
    }

// show the 3D corp tower floor for an area, on the same terms as the two above: the grid is the
// persisted layout, so this works on every corp save already written
  public function showCorp(area:game.AreaGame):Void
    {
      var key = gridKey(area.id, 3);
      if ((running || warming) && shownKey == key)
        return;
      var model = render.corp.CorpModel.fromArea(area, iconBox);
      // and the one thing the model cannot do on its own: a pane it demoted to masonry has to stop
      // being see-through in the TILE grid too — see CorpModel.sealWindows
      render.corp.CorpModel.sealWindows(area, model);
      buildFrom(new render.corp.CorpArea(game, model), key);
    }

// the opaque box of one bench decoration's art, which the facility model places its contact pool
// off (see render.facility.FacilityModel.fromArea). null until the atlas decodes, and then those
// pools take their fallbacks.
//
// IT ASKS THE SAME SHEET THE SPRITE WILL BE DRAWN FROM, which for a frame with hi-res art is a
// pack cell at Const.DECO_PACK_CELL and not the entities64 frame at all — a pool measured on one
// and a quad drawn from the other are two different silhouettes. The box carries its own cell size
// (AtlasBox.t) so the fractions downstream cannot be taken against the wrong one.
//
// OFF THE IMAGE AND NOT OFF THE SPRITE POOL, which is the whole reason it lives here rather than on
// render.Actors beside the other atlas lookups: `actors` is created inside `buildFrom`, from the
// very model this feeds, so it is null on every call. Asking it there was a null dereference that
// killed every facility entry — the area built, then never presented a frame
  function iconBox(row:Int, col:Int):render.particles.AtlasBox
    {
      var hd = Const.decoHD(row, col);
      if (hd >= 0)
        return render.particles.Sprites.cellBox(
          game.scene.images.getDecoPack(Const.decoHDPack(hd)),
          Const.DECO_PACK_CELL, Const.decoHDCol(hd), Const.decoHDRow(hd));
      return render.particles.Sprites.cellBox(game.scene.images.getImage('entities'),
        Const.TILE_SIZE_CLEAN, col, row);
    }

// show the 3D open wilderness for an area, built from its saved tile grid for the same reason the
// tunnels are: game.AreaGenerator.generateWilderness already wrote where every tree and rock stands,
// and that grid is what the pathfinder walks around
  public function showWild(area:game.AreaGame):Void
    {
      var key = gridKey(area.id, 1);
      if ((running || warming) && shownKey == key)
        return;
      // the terrain band FIRST: WildModel.fromArea reads it to turn tile IDs into models, and it is
      // evaluated as the constructor's argument, so WildArea.build would be one area too late
      render.wild.WildBand.use(game);
      buildFrom(new render.wild.WildArea(game, render.wild.WildModel.fromArea(area)), key);
    }

// (re)build the scene for an area kind and start the render loop
  function buildFrom(a:Area3D, key:Int):Void {
    ensureCore();
    // a load/rebuild replaces the scene without going through the menu-exit outro, so free the
    // previous build's GPU resources here too — otherwise every load orphans a whole city's
    // geometry in the (persistent) renderer's cache and geom climbs ~one city per load
    disposeBuild();
    // drop the previous area's indoor lighting mask. the kind that wants one attaches it in its own
    // build() (only the facility so far), so this is the single point that guarantees every OTHER
    // kind starts without one — otherwise a tunnel entered straight after a facility would compile
    // the indoor swap into its walls and sample the compound's floor plan for it
    render.world.IndoorMask.detach();
    render.world.ContactMask.detach();
    render.world.PropEnv.detach();
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
        forceSinglePass: true, // one flat ring: the back-then-front split is a second call
        depthWrite: false,
      }));
    ring.name = 'ui player ring';
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
    // the far city softens: a full-screen blur masked by the alpha the corp street writes. BEFORE
    // GTAO, which composites its own quad and would overwrite that alpha. Zero cost anywhere else
    // — a disabled pass is skipped whole by the composer
    streetBlur = new StreetBlur();
    streetBlur.pass.enabled = Std.isOfType(a, render.corp.CorpArea);
    streetBlur.resize(Std.int(Browser.window.innerWidth), Std.int(Browser.window.innerHeight));
    composer.addPass(streetBlur.pass);
    // ambient occlusion: darkens where geometry meets (wall/ground, lamp bases, corners). before
    // bloom so the darkened crevices don't feed the glow. it renders its own depth + normal prepass
    // of the whole scene, so it stays enabled-gated — a disabled pass is skipped by the composer
    // and costs nothing (see setAO)
    gtaoPass = new GTAOPass(scene, camera, Browser.window.innerWidth, Browser.window.innerHeight);
    gtaoPass.blendIntensity = RenderConfig.GTAO.blendIntensity;
    gtaoPass.updateGtaoMaterial(RenderConfig.GTAO);
    gtaoPass.enabled = game.config.vidAO;
    sizeGtao(); // constructed in CSS px above; put its targets on the backbuffer scale
    // A BILLBOARD IS A SOLID SLAB TO THIS PASS. Its depth+normal prepass draws the whole scene
    // through ONE opaque override material — no map, so no alpha cut — which puts every sprite
    // quad in as a full rectangle standing on the ground. A thin upright plane occludes the floor
    // along both its edges, so every actor, floor object and bench decoration in the game wore a
    // bracket of shade: a band under it and a stub at each side, out at the quad's corners where
    // there is no art at all. Measured by hiding the layer for the prepass only — the difference
    // is that bracket and nothing else.
    //
    // the prepass is the only thing in here that reads the scene (the composite is a full-screen
    // quad), so hiding the sprite layer around the whole call is the whole fix. Sprites still
    // RECEIVE the world's AO; they stop casting it. Restores whatever it found, since the group's
    // visibility is not this pass's to own
    //
    // AND SO IS EVERY MESH THAT WRITES NO DEPTH, for the same reason: the override material
    // draws it opaque whatever its own says. The corp lamps' additive floor POOL lies at GLOW_Y
    // over each lit room's whole rect and under each corridor lamp, so the prepass saw a slab
    // hovering over the floor and shaded the floor under it — reported as a large dark rectangle
    // over almost every room and a small square under every corridor lamp. The rule is the beauty
    // pass's own: a mesh that does not write depth there does not occlude anything, so it is left
    // out here too — every additive glow, light cone and faded roof in the game at once, with no
    // list to keep. Collected per frame off traverseVisible, so what is already hidden stays so
    var fx = actorGroup;
    var glows:Array<Object3D> = [];
    var gtaoRender = gtaoPass.render;
    gtaoPass.render = function(renderer, writeBuffer, readBuffer, deltaTime, maskActive)
      {
        var was = fx.visible;
        fx.visible = false;
        scene.traverseVisible(function(o)
          {
            if (o.material != null &&
                o.material.depthWrite == false)
              glows.push(o);
          });
        for (o in glows)
          o.visible = false;
        gtaoRender.call(gtaoPass, renderer, writeBuffer, readBuffer, deltaTime, maskActive);
        for (o in glows)
          o.visible = true;
        glows.resize(0);
        fx.visible = was;
      };
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
        canvasRect = null;
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

// forget which area is on screen, WITHOUT tearing the view down, so the next draw rebuilds it.
//
// for a LOAD, which is the one event that replaces every AreaGame while their ids stay the same —
// ids are persisted, so the save's facility comes back as a NEW object under the OLD id. both of
// the guards that skip a rebuild key on that id (GameScene._view3dArea and shownKey here), so
// without this the view keeps a scene built from the grid the PREVIOUS save had for that id. an
// area is generated on first visit, so loading an older save while standing in a lab regenerates it
// to a different layout and the two disagree completely — walls you walk straight through, and
// invisible ones that stop you. measured on a live 75x60 facility: the shown model matched the
// area's own grid on 0 of 4500 cells until the view was forgotten, and 4500 of 4500 after
  public function forget():Void
    {
      shownKey = -2;
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
    canvasRect = null;
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

// drive the hover tooltip while inspecting (Ctrl held): pick the AI or object nearest the cursor
// and anchor the DOM panel at its projected px. runs every frame so the beam tracks the
// follow-camera. the 2D AreaTooltip stands down while this view runs (see AreaTooltip.update)
  function updateHoverTooltip():Void {
    var tip = game.ui.hud.areaTooltip;
    // not inspecting (no Ctrl / window open / mouse off): make sure it's hidden
    if (!game.ui.hud.isInspectMode()) {
      tip.hide();
      return;
    }
    var hit = actors.pickTarget(svMouseX, svMouseY, clientRect());
    if (hit == null) {
      tip.hide();
      return;
    }
    // the beam id keys BeamTooltip's re-animation and nothing else, so an object's is negated —
    // AI and object ids come from separate counters and would otherwise collide (AreaTooltip.beamID)
    var id = (hit.ai != null ? hit.ai.id : ui.AreaTooltip.beamID(hit.obj));
    // still the same target: just move the anchor. the content build is NOT free (see trackAnchor)
    // and showBeamAt would discard it, so it must not happen before this test
    if (tip.trackAnchor(hit.px, hit.py, id))
      return;
    if (hit.ai != null)
      tip.showBeamAt(hit.px, hit.py, id, tip.getTooltipText(hit.ai));
    else tip.showBeamAt(hit.px, hit.py, id, tip.getObjectText(hit.obj));
  }

// the canvas's client rect, read once and kept until a resize or a show/hide drops it
  function clientRect():Dynamic
    {
      if (canvasRect == null)
        canvasRect = canvas.getBoundingClientRect();
      return canvasRect;
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
      var rect = clientRect();
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
    canvasRect = null;
    if (renderer == null) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
    if (composer != null) composer.setSize(w, h);
    if (streetBlur != null) streetBlur.resize(Std.int(w), Std.int(h));
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
        ui: game.ui.hud.isVisible(),
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
    //
    // the corners are sampled by WORLD position, not by their grid cell. on the city's stepped floor
    // those are the same answer, but on continuous relief a cell-snapped sample is worthless here:
    // the ring's radius is 0.448 of a cell, so with the player anywhere near a cell centre all four
    // corners land back in that same cell and the ring reads ONE flat height while the ground uphill
    // of it has already risen by rr * slope. sampled at the corners themselves the max comes out at
    // h + rr * (|dh/dx| + |dh/dz|), which is >= the disc's true peak of h + rr * |grad| — so it errs
    // by floating, which is the side this is allowed to fail on
    var rr = CityConfig.CELL * 0.448;                       // ring outer radius
    function fY(ox:Float, oz:Float):Float
      {
        return render.world.WorldCtx.floorYAt(p.x + ox, p.z + oz);
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
    // Shift+Space hides the HUD, and the world-anchored UI goes with it: the player marker, the
    // move-path preview and the tactical grid are readouts drawn in the scene, not scenery. all
    // three are re-asserted below from live state, so unhiding needs no restore path
    var uiOn = game.ui.hud.isVisible();
    ring.visible = uiOn;
    if (!uiOn)
      {
        pathLine.clear();
        tacticalGrid.hide();
      }
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
    if (tactical &&
        uiOn)
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
      ui: uiOn,
    });
    // the corp street's blur goes off with the street (CorpArea.overPlate): ~0.5 ms of fullscreen
    // pass over a view that has no street in it
    if (streetBlur != null)
      streetBlur.pass.enabled = Std.isOfType(area3d, render.corp.CorpArea) &&
        (cast area3d:render.corp.CorpArea).streetShown;
    // hand the lit lamps to the actor layer so it casts fake shadows only from lamps lit this frame,
    // plus whatever the area lights with no pool slot behind it (a facility's windows) — empty
    // everywhere else, so the concat only ever costs the one kind that has any
    var extra = area3d.shadowLamps();
    actors.setLamps(extra.length == 0 ? lampLights.active() : lampLights.active().concat(extra));
    // and the park's own masts, which carry a swarm of gnats rather than a shadow (RenderConfig
    // .LAMP_FLY). a separate list because it is a different question: these are the lamps standing
    // over a LAWN, not the lamps lit this frame
    actors.setFlyLamps(area3d.flyLamps());
    actors.update(dtMs);
    // the batched ground decals — street debris and plain blood — belong to the ACTOR layer, not to
    // the area, and their instanced groups are built lazily by the paint pass just above, so there is
    // no build-time moment for the tunnel mask to catch them the way every other surface is caught.
    // without this the debris underfoot stayed at full brightness in a corridor nobody can see.
    // gated because Actors is rebuilt per area but the mask uniforms are not: a patched material left
    // over in a CITY would sample the last masked area's canvas. patch() marks its own hook and
    // early-outs, so a landed group is a couple of reads.
    // both kinds that carry a mask are listed: the tunnels, and the wilderness since its large
    // obstacles became the first open-area tiles that block sight
    if (Std.isOfType(area3d, render.sewer.SewerArea) ||
        Std.isOfType(area3d, render.wild.WildArea))
      for (m in actors.decalMaterials())
        render.world.VisionMask.patch(m);
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

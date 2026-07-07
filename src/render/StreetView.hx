package render;

import three.Three;
import js.Browser;
import citygen.CityGen;
import citygen.CityConfig;
import citygen.CityModel.City;
import game.Game;
import entities.Entity;
import render.anim.Shake;
import render.anim.MeleeLunge;

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
  var fill:Array<Object3D>; // [ambient, hemi, moon] fill lights (debug 2/3/4 toggles)
  var pointLights:Array<Object3D>; // per-lamp point lights (debug 5 toggle)
  var city:City;

  var actorGroup:Group;
  var ring:Mesh;
  var ringY:Float = 0;                                    // eased ring floor height (curb step)
  var exiting = false;                                    // playing the leave zoom-in outro over the frozen last frame
  var exitDone:Void->Void = null;                         // runs when the outro completes (fade orchestration hook), else teardown
  var actors:Actors;                                      // the billboard actor layer
  var rig:CameraRig;                                      // the follow camera + zoom
  var occlusion:Occlusion;                                // fades buildings blocking the player

  var debug:Debug;                                        // street-debug mode (backquote): HUD + tools
  public static var DEBUG_HOLES = false; // [wallhole] trace each wall tracer impact + hole decision (toggle: `perf hole`)

  public var running(default, null):Bool = false;
  var shownSeed:Int = -2; // seed of the currently-built city (-2 = nothing built)
  var last = 0.0;
  var _lastProgs = 0;     // shader program count last frame; a jump == a (re)compile stall (perf street)
  public static var lastCalls = 0; // draw calls last frame (HUD counter, when vidShowFps)
  public static var lastTris = 0;  // triangles drawn last frame (HUD counter, when vidShowFps)


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
    });
    // wheel zooms the follow camera (up = in, down = out); debug keeps its own UV-scroll wheel
    Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!running || debug.on || rig == null) return;
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
  public inline function debugActive():Bool return debug.on;

// enter/leave street-debug mode (fly/editor/inspector + HUD — see render.Debug)
  public inline function setDebug(on:Bool):Void debug.set(on);

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
    fill = bundle.fill;
    pointLights = bundle.pointLights;
    World.build(scene, city, seed);
    debug.onRebuild(); // fresh city: reset cycler indices + counts
    occlusion = new Occlusion(scene, city.buildings);

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
    // seed-derived street debris (render-only, deterministic from the seed — no save cost); old
    // seedless saves (seed -1) skip it
    if (seed != -1)
      actors.setDebris(render.world.Debris.build(seed, city.tiles, game.area.typeID, game.area.highCrime));

    // bloom: lit windows/lamps emit HDR (>1); bloom gives them a soft glow
    composer = new EffectComposer(renderer);
    composer.addPass(new RenderPass(scene, camera));
    bloomPass = new UnrealBloomPass(
      new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
      RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD);
    composer.addPass(bloomPass);
    composer.addPass(new OutputPass());
    // let renderer.info accumulate across all composer passes: its OutputPass would otherwise
    // reset the per-frame draw stats to its own single quad, so we reset() manually each frame
    renderer.info.autoReset = false;

    exiting = false;   // cancel any in-flight outro from a prior area
    rig.reset();
    rig.startIntro();  // enter effect: start closest, zoom out to the resting target

    canvas.style.display = 'block';
    if (!running) {
      running = true;
      last = 0;
      Browser.window.requestAnimationFrame(loop);
    }
  }

// begin leaving: play the zoom-in outro over the frozen last frame, then hand off. the game
// area is already despawned by the time this fires (so the outro reads no game state). called
// every frame while the region shows — a no-op once the outro is already running. onExitDone
// (if given) runs when the outro completes INSTEAD of teardown, so the caller can cover to
// black first and tear the view down under it (see GameScene.onCityExitDone)
  public function hide(?onExitDone:Void->Void):Void {
    if (!running || exiting) return;
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

// melee choreography: attacker lunges toward the target and, on the lunge landing, fires the
// impact beat — plays the attack sound, shakes the target, and throws blood (bloody weapons).
// returns true if it took over the sound (caller then stays silent to avoid a double play);
// false when no city view / no attacker actor, so the caller plays the sound itself
  public function playMelee(atkE:Entity, tgtE:Entity,
      atkCol:Int, atkRow:Int, tgtCol:Int, tgtRow:Int,
      soundFile:String, spawnBlood:Bool, bloodRow:Int, bloodFirstCol:Int):Bool
    {
      if (!running ||
          actors == null ||
          atkE == null)
        return false;
      // lunge reach: unit vector attacker->target, scaled to a fraction of a cell
      var a = CityConfig.cellToWorld(atkCol, atkRow);
      var b = CityConfig.cellToWorld(tgtCol, tgtRow);
      var dx = b.x - a.x, dz = b.z - a.z;
      var len = Math.sqrt(dx * dx + dz * dz);
      if (len < 0.001)
        {
          dx = 0;
          dz = 1;
          len = 1;
        }
      var reach = RenderConfig.MELEE.lungeReach * CityConfig.CELL;
      // the impact beat, fired when the lunge lands
      var onDone = function() {
        if (soundFile != null)
          game.scene.sounds.play(soundFile, { x: tgtCol, y: tgtRow });
        if (tgtE != null)
          actors.playFx(tgtE, new Shake(RenderConfig.MELEE.shakeMs,
            RenderConfig.MELEE.shakeAmp * CityConfig.CELL, 0));
        if (spawnBlood)
          actors.burst(tgtCol, tgtRow, dx, dz, bloodRow, bloodFirstCol);
      };
      var lunge = new MeleeLunge(RenderConfig.MELEE.lungeMs,
        dx / len * reach, dz / len * reach, onDone);
      // if the attacker has no live billboard (off-screen), fire the beat now so nothing is lost
      if (!actors.playFx(atkE, lunge))
        onDone();
      return true;
    }

// gun-shot choreography: a blooming tracer races muzzle->impact with a muzzle flash + light,
// and on landing fires the impact beat (blood + hit/miss sound). fires per-weapon pellets
// (pistol 1, rifle 3 staggered, shotgun 5 spread); only the first pellet carries the beat so
// blood/sound happen once. player shots kick the camera. returns true if the view took over
// (caller then skips the 2D tracer); false when no city view / no shooter actor
  public function playShot(atkE:Entity, sx:Int, sy:Int, tx:Int, ty:Int,
      hit:Bool, spawnBlood:Bool, bloodRow:Int, bloodCol:Int, soundKind:String, byPlayer:Bool):Bool
    {
      if (!running ||
          actors == null ||
          atkE == null)
        return false;
      var S = RenderConfig.SHOT;
      var C = CityConfig.CELL;
      // muzzle + impact at chest height (the blood-burst convention)
      var mw = CityConfig.cellToWorld(sx, sy);
      var iw = CityConfig.cellToWorld(tx, ty);
      var muzzleY = render.world.WorldCtx.floorY(sx, sy) + render.particles.Sprites.SIZE * 0.4;
      var impactY = render.world.WorldCtx.floorY(tx, ty) + render.particles.Sprites.SIZE * 0.4;
      // small random offset applied to both tracer ends (full on x/z, half on y) so pellets/shots
      // don't all share one exact muzzle->impact line
      var jit = function() return S.tracerJitter * C * (Math.random() - 0.5);
      // muzzle light only for near-camera shots (pooled, constant count); distant shots in a
      // 50-NPC firefight get just the emissive flash quad, no light
      if (Math.abs(sx - game.playerArea.x) <= S.lightRangeCells &&
          Math.abs(sy - game.playerArea.y) <= S.lightRangeCells)
        actors.muzzleFlash(mw.x, muzzleY, mw.z);
      // the impact beat: on a hit, blood away from the shooter (guns always draw blood, like the
      // old 2D shot) + the hit sound; on a miss, just the miss sound (spark handled per-pellet)
      var onImpact = function() {
        if (hit)
          {
            actors.burst(tx, ty, tx - sx, ty - sy, bloodRow, bloodCol);
            game.scene.sounds.play('attack-bullet-hit', { always: true, x: tx, y: ty });
          }
        else game.scene.sounds.play('attack-bullet-miss', { always: true, x: tx, y: ty });
      };
      // per-weapon pellet pattern
      var kind = (soundKind == 'attack-shotgun' ? S.kinds.shotgun :
        (soundKind == 'attack-assault-rifle' ? S.kinds.rifle : S.kinds.pistol));
      // base impact: a hit stops at the target cell (flesh, no spark); a miss flies on to the
      // first wall along its path (spark there) or fades at max range (off-camera, no spark)
      var baseX = iw.x, baseY = impactY, baseZ = iw.z;
      var sparkAtEnd = false;
      var wallCol = -1, wallRow = -1; // struck wall cell (for the bullet-hole decal), -1 = none
      var wallFromCol = -1, wallFromRow = -1; // last open cell before the hit = the exposed face
      if (!hit)
        {
          var e = game.area.rayToWall(sx, sy, tx, ty, kind.range);
          var ew = CityConfig.cellToWorld(e.col, e.row);
          baseX = ew.x; baseZ = ew.z;
          baseY = render.world.WorldCtx.floorY(e.col, e.row) + render.particles.Sprites.SIZE * 0.4;
          sparkAtEnd = e.wall;
          if (holeDebug() && !e.wall)
            trace('[wallhole] miss FADED at cell(' + e.col + ',' + e.row + ') range=' + kind.range + ' — no wall in range, no spark/hole');
          // a wall tile's center sits inside the opaque wall (occludes the spark) -> pull the
          // endpoint back half a cell along the ray so the tracer/spark land on the near face
          if (e.wall)
            {
              var dxm = baseX - mw.x, dzm = baseZ - mw.z;
              var dl = Math.sqrt(dxm * dxm + dzm * dzm);
              if (dl > 0.001)
                {
                  baseX -= dxm / dl * C * 0.5;
                  baseZ -= dzm / dl * C * 0.5;
                }
              wallCol = e.col; wallRow = e.row;
              wallFromCol = e.fromCol; wallFromRow = e.fromRow;
              // wall-hit sound at impact time: corrugated steel (facade 3) rings metal, all
              // masonry (concrete/brick/stone) reads as one stone thud
              var metal = wallFacade(e.col, e.row) == 3;
              if (holeDebug())
                trace('[wallhit] cell(' + e.col + ',' + e.row + ') facade=' + wallFacade(e.col, e.row) + ' sound=' + (metal ? 'fx-wall-metal' : 'fx-wall-stone'));
              game.scene.sounds.play(metal ? 'fx-wall-metal' : 'fx-wall-stone',
                { always: true, delay: Std.int(S.travelMs), x: e.col, y: e.row });
            }
        }
      for (i in 0...kind.pellets)
        {
          // spread jitters each pellet's visual impact (blood still lands on the true tile)
          var jx = kind.spread * C * (Math.random() - 0.5);
          var jz = kind.spread * C * (Math.random() - 0.5);
          var jy = 0.0;
          // wall miss: extra shared scatter so successive tracers/sparks/holes at one wall
          // spread out (and stay aligned with each other) instead of piling on one point
          if (sparkAtEnd)
            {
              var ws = RenderConfig.WALLHOLE.spread * C;
              jx += ws * (Math.random() - 0.5);
              jz += ws * (Math.random() - 0.5);
              jy = RenderConfig.WALLHOLE.vspread * C * (Math.random() - 0.5); // smaller vertical spread
            }
          var muz = new Vector3(mw.x + jit(), muzzleY + jit() * 0.5, mw.z + jit());
          var ex = baseX + jx + jit(), ez = baseZ + jz + jit();
          var impact = new Vector3(ex, baseY + jy + jit() * 0.5, ez);
          actors.shot(muz, impact, i * kind.stagger, i == 0 ? onImpact : null);
          // wall strike: spray sparks back off the wall once the tracer arrives
          if (sparkAtEnd)
            actors.sparkBurst(ex, baseY, ez, mw.x - ex, mw.z - ez, i * kind.stagger + S.travelMs);
          // and leave a persisted hole at the PRIMARY pellet's exact impact so hole and tracer
          // line up (bare walls only; scatters shot-to-shot via the same jitter as the tracer)
          if (sparkAtEnd && i == 0)
            spawnBulletHole(wallFromCol, wallFromRow, wallCol, wallRow, muz, impact);
        }
      // recoil: kick the camera back along the shot (player's own shots only)
      if (byPlayer)
        rig.kick(sx - tx, sy - ty);
      return true;
    }

// facade material (0 concrete,1 brick,2 stone,3 metal) of the building owning wall cell (col,row);
// -1 if no building owns it. used to pick the wall-hit sound
  function wallFacade(col:Int, row:Int):Int
    {
      for (b in render.world.WorldCtx.buildings)
        if (col >= b.col &&
            col < b.col + b.w &&
            row >= b.row &&
            row < b.row + b.d)
          return b.facade;
      return -1;
    }

// leave a persisted bullet-hole decal on the wall cell (wcol,wrow) struck by a shot. (muz,impact)
// are the pellet-0 tracer endpoints; the hole lands where that segment actually crosses the struck
// face plane (true entry point — correct for angled shots, not just head-on). (fromCol,fromRow) is
// the last OPEN cell before the hit — the exposed face the ray entered through. gated off glass:
// skips shops + the ground-floor storefront band; skipped if not a building
  function spawnBulletHole(fromCol:Int, fromRow:Int, wcol:Int, wrow:Int, muz:Vector3, impact:Vector3):Void
    {
      // struck face: pick the side of the wall cell whose NEIGHBOUR is actually open (exposed),
      // toward the cell the ray came from. a diagonal entry (delta (1,1)) has two candidate axes —
      // faceToward would tie-break to an axis whose neighbour is still solid (interior boundary);
      // choosing the axis with an open neighbour lands the hole on the real outer surface
      var ddx = fromCol - wcol, ddy = fromRow - wrow;
      var xOpen = ddx != 0 && game.area.canSeeThrough(wcol + (ddx > 0 ? 1 : -1), wrow);
      var zOpen = ddy != 0 && game.area.canSeeThrough(wcol, wrow + (ddy > 0 ? 1 : -1));
      var dir = (xOpen && zOpen) ? render.world.Geom.faceToward(ddx, ddy) // convex corner: dominant axis
        : xOpen ? (ddx > 0 ? 2 : 3)
        : zOpen ? (ddy > 0 ? 0 : 1)
        : render.world.Geom.faceToward(ddx, ddy);                         // fallback (shouldn't hit)
      // which building owns this wall cell
      var b = null;
      for (bb in render.world.WorldCtx.buildings)
        if (wcol >= bb.col &&
            wcol < bb.col + bb.w &&
            wrow >= bb.row &&
            wrow < bb.row + bb.d)
          {
            b = bb;
            break;
          }
      var dbg = holeDebug();
      var where = 'cell(' + wcol + ',' + wrow + ') dir=' + dir + ' [0=+z 1=-z 2=+x 3=-x]';
      // holes land on any masonry wall that isn't glass: skip single-story shops and the
      // ground-floor storefront band (the glass facade). plain street fronts + alley/back walls
      // both qualify — holes sit at chest height, below the upper-floor windows
      if (b == null)
        {
          if (dbg)
            trace('[wallhole] ' + where + ' -> SKIP: no building owns this cell (opaque tile/object, not a building)');
          return;
        }
      var bc = CityConfig.cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var hw = b.w * CityConfig.CELL / 2, hd = b.d * CityConfig.CELL / 2;
      var info = ' bldg(col=' + b.col + ' row=' + b.row + ' w=' + b.w + ' d=' + b.d + ' facade=' + b.facade
        + ' shop=' + b.shop + ' worn=' + render.world.Geom.isWornFace(b, dir)
        + ' storefront=' + render.world.Geom.storefrontFace(b, dir) + ') box x['
        + fnum(bc.x - hw) + '..' + fnum(bc.x + hw) + '] z[' + fnum(bc.z - hd) + '..' + fnum(bc.z + hd) + ']';
      if (b.shop >= 0)
        {
          if (dbg)
            trace('[wallhole] ' + where + info + ' -> SKIP: single-story shop');
          return;
        }
      if (render.world.Geom.storefrontFace(b, dir))
        {
          if (dbg)
            trace('[wallhole] ' + where + info + ' -> SKIP: storefront (glass) face');
          return;
        }
      // intersect the pellet-0 tracer segment (muz -> impact) with the struck cell's OUTER face
      // plane: this is where the trail visually enters the wall — correct for angled shots, unlike
      // snapping the normal axis while keeping the impact's (ray-pulled-back) tangential coord
      var dv = render.world.Geom.DIRV[dir];
      var half = CityConfig.CELL / 2;
      var cc = CityConfig.cellToWorld(wcol, wrow);
      var normalPos = (dir >= 2) ? cc.x + dv[0] * half : cc.z + dv[1] * half; // face plane on the normal axis
      var n0 = (dir >= 2) ? muz.x : muz.z;       // tracer normal-axis coord at muzzle
      var n1 = (dir >= 2) ? impact.x : impact.z; // and at impact
      var t = (Math.abs(n1 - n0) > 0.001) ? (normalPos - n0) / (n1 - n0) : 1.0;
      t = Math.max(0.0, Math.min(1.0, t));       // clamp to the segment
      var hy = muz.y + t * (impact.y - muz.y);   // entry height along the trail
      var hx = (dir >= 2) ? normalPos : muz.x + t * (impact.x - muz.x);
      var hz = (dir >= 2) ? muz.z + t * (impact.z - muz.z) : normalPos;
      // clamp the along-face (tangential) coord to the building box so a grazing/near-corner trail
      // can't put the hole past the wall edge into the air
      var m = 0.35;
      if (dir >= 2) hz = Math.max(bc.z - hd + m, Math.min(bc.z + hd - m, hz));
      else hx = Math.max(bc.x - hw + m, Math.min(bc.x + hw - m, hx));
      // store as a sub-cell dx/dy offset (invert cellToWorld) so the draw reproduces this point
      var T = Const.TILE_SIZE;
      var dx = Std.int((hx / CityConfig.CELL + CityConfig.GRID / 2 - 0.5 - wcol) * T);
      var dy = Std.int((hz / CityConfig.CELL + CityConfig.GRID / 2 - 0.5 - wrow) * T);
      var W = RenderConfig.WALLHOLE;
      game.area.addTileDecoration(wcol, wrow,
        {
          layerID: -1,
          tag: 'WALLHOLE',
          face: dir,
          height: hy,
          metal: b.facade == 3, // metal warehouse -> steel-dent hole set
          angle: Math.random() * Math.PI * 2,
          scale: W.scale + (Math.random() - 0.5) * 2 * W.scaleVar,
          dx: dx,
          dy: dy,
        });
      if (dbg) trace('[wallhole] ' + where + info + ' -> HOLE on face at world(' + fnum(hx) + ',' + fnum(hy) + ',' + fnum(hz)
        + ') | ray muz(' + fnum(muz.x) + ',' + fnum(muz.y) + ',' + fnum(muz.z) + ') -> impact(' + fnum(impact.x) + ',' + fnum(impact.y) + ',' + fnum(impact.z)
        + ') facePlane=' + fnum(normalPos) + ' t=' + fnum(t));
    }

// [wallhole] debug on? toggled by the `perf hole` console command
  inline function holeDebug():Bool
    return DEBUG_HOLES;

// one-decimal number for compact traces
  inline function fnum(v:Float):String
    return '' + Std.int(v * 10) / 10;

// snapshot a dying actor into a fade-out ghost (before its entity is nulled)
  public function playDeathFade(e:Entity):Void
    {
      if (running &&
          actors != null)
        actors.startDeathFade(e);
    }

// fade a freshly-spawned entity (the body) in from transparent instead of popping
  public function fadeInEntity(e:Entity):Void
    {
      if (running &&
          actors != null &&
          e != null)
        actors.seedFadeIn(e);
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
    actors.update(dtMs);

    // render pass timing: the composer stall (incl. any shader (re)compile) is invisible to the
    // turn/street-actor profilers — catch it here. a jump in the program count == a compile.
    // while profiling, first do a standalone base-scene render to expose per-frame draw-call /
    // triangle counts (composer's OutputPass resets renderer.info, so it can't show scene stats)
    // and to split base-scene cost from post-FX (bloom+output) cost — this doubles the scene
    // render, so it's gated behind the toggle and its cost is excluded from the reported numbers
    var baseMs = 0.0, calls = 0, tris = 0;
    if (render.Actors.DEBUG_PERF)
      {
        // standalone base-scene render for the split; reset first so the counts are scene-only
        renderer.info.reset();
        var tB = haxe.Timer.stamp();
        renderer.render(scene, camera);
        baseMs = (haxe.Timer.stamp() - tB) * 1000;
        calls = renderer.info.render.calls;
        tris = renderer.info.render.triangles;
      }
    renderer.info.reset(); // manual per-frame reset (autoReset off); total accumulates over the passes
    var tR = haxe.Timer.stamp();
    composer.render();
    lastCalls = renderer.info.render.calls; // scene + a few post-FX quads — HUD draw-call readout
    lastTris = renderer.info.render.triangles;
    if (debug.on) Gizmo.draw(renderer, camera); // corner XYZ gizmo (after the stat capture)
    if (render.Actors.DEBUG_PERF)
      {
        var ms = (haxe.Timer.stamp() - tR) * 1000;
        var progs = (renderer.info.programs != null ? renderer.info.programs.length : 0);
        var compiled = progs - _lastProgs;
        if (ms > 8 ||
            compiled != 0)
          // full=composer total, base=scene-only, post=bloom+output, calls/tris=scene draw load
          trace('[street-render] full=' + r2(ms) + 'ms base=' + r2(baseMs) +
            ' post=' + r2(ms - baseMs) + ' calls=' + calls + ' tris=' + tris +
            ' programs=' + progs +
            (compiled != 0 ? ' (COMPILE ' + (compiled > 0 ? '+' : '') + compiled + ')' : ''));
        _lastProgs = progs;
      }
  }

// round a float to 2 decimals for perf logging
  static inline function r2(v: Float): Float
    {
      return Std.int(v * 100) / 100;
    }
}

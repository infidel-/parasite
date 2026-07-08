package render;

import three.Three;
import citygen.CityConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.anim.*;
import render.particles.*;
import render.particles.FlameLights.FlameBarrel;
import game.Game;
import entities.Entity;
import ai.AI;
import objects.AreaObject;

// per-AI badge anim: last badge-set signature (change detection) + the active change-pop (null idle)
typedef BadgeAnim = { sig:String, pop:render.anim.Effect };

// the 3D actor billboard layer: mirrors the game's objects/AI/player as sprites, each with a
// position slide + opacity fade + optional transient effect. owns the per-actor anim state and
// paints through a shared Billboards surface; transient FX (blood, death crossfade) live in a
// Particles3D. StreetView builds one per city and drives it each frame via update(); game logic
// triggers effects via playFx() and the melee/death bridges
class Actors {
  var game:Game;
  var camera:PerspectiveCamera;                           // read live for billboard yaw (future)
  var actorGroup:Group;                                   // scene group; shots attach their own meshes to it

  var sprites:Sprites;                                    // lit billboard/decal paint surface (quad pool + atlas cache)
  var beams:Beams;                                        // unlit additive bright-FX pool (gun tracers, muzzle flash)
  var sparks:Sparks;                                      // camera-facing soft-ember pool (impact sprays)
  var muzzleLights:MuzzleLights;                          // fixed muzzle-light pool (constant scene light count)
  var paint:Paint3D;                                      // the two surfaces handed to each particle each frame
  var particles:Particles3D;                              // transient 3D FX (blood, death crossfade, gun shots)
  // per-actor anim state, keyed by entity identity. ponytail: dead entities linger here
  // until the area rebuild drops this whole object — bounded per area, not worth pruning
  var actors:haxe.ds.ObjectMap<Entity, Actor> = new haxe.ds.ObjectMap();

  var lastState:_PlayerState;                            // prev-frame player state (attach transition)
  var holeTex:Array<Texture> = null;                     // masonry bullet-hole wall textures (lazy-loaded once)
  var holeTexMetal:Array<Texture> = null;                // metal-wall bullet-hole textures (lazy-loaded once)
  var debris:Array<render.world.Debris.DebrisSpot> = null; // seed-derived street debris (render-only, not persisted)
  var flameLights:FlameLights = null;                   // pooled warm barrel lights (low-tier only; null elsewhere)
  var flameT:Float = 0.0;                               // shared flame clock (ms, raw dt) — flicker/embers/shadows sync to it
  var badgeT:Float = 0.0;                               // badge anim clock (turn units, anim-speed scaled) — looping pulses
  // per-AI badge change-pop state (last signature + active pop). ponytail: dead AI linger like the
  // actors map, dropped whole on area rebuild
  var badgeAnims:haxe.ds.ObjectMap<Entity, BadgeAnim> = new haxe.ds.ObjectMap();
  var flameTex:Texture = null;                          // barrel flame sprite (lazy-loaded once)
  var curBarrels:Array<FlameBarrel> = [];               // this frame's visible barrels (gathered once, reused by lit/body/shadow)
  var lampSrc:Array<LampPost> = null;                   // lamps lit this frame (from the pool) — cast fake shadows too

  // --- frame profiler (toggle from devtools or `perf street`) ---
  public static var DEBUG_PERF = false;                 // render per-pass timings (toggle: `perf street`)
  var _pf = 0;                                          // frames since last summary
  var _pObj = 0.0; var _pAI = 0.0; var _pPass = 0.0;   // accumulated ms: objects, AI, my passes
  var _decalScan = 0; var _decalDraw = 0;              // last decal pass: cells visited / quads drawn

  static inline var FADE_SPEED = 0.5;                  // LOS opacity fade runs at this * base speed (slower)
  static inline var TARGET_SCALE = 1.15;               // targeting frame/reticle ground-quad scale (~one cell)
  static inline var ATTACH_HEAD_Y = Sprites.SIZE * 0.1;  // attached parasite rides this far above the host's ground center (its head)
  static inline var ATTACH_SCALE = 1.0;                // attached parasite is drawn this much smaller (sits on the head)

  public function new(game:Game, actorGroup:Group, camera:PerspectiveCamera)
    {
      this.game = game;
      this.camera = camera;
      this.actorGroup = actorGroup;
      sprites = new Sprites(game, actorGroup);
      beams = new Beams(actorGroup);
      sparks = new Sparks(actorGroup, camera);
      // created here (before the first render) so the muzzle lights are in NUM_POINT_LIGHTS from
      // frame one — the scene compiles once at the full count, never recompiles on a shot
      muzzleLights = new MuzzleLights(actorGroup);
      // burning-barrel flame lights: only low-tier cities spawn barrels, so only there do we add to
      // NUM_POINT_LIGHTS (built here so the scene compiles once at the full count, never recompiles).
      // ponytail: no barrels elsewhere -> no flame pool, no per-fragment light cost elsewhere
      if (game.area.typeID == AREA_CITY_LOW)
        flameLights = new FlameLights(actorGroup);
      paint = { sprites: sprites, beams: beams, sparks: sparks };
      particles = new Particles3D();
      lastState = game.player.state;
    }

// receive the lamps lit this frame (the pool's active set) so actors cast fake shadows from them
// (mirrors barrels). called each frame; only currently-lit lamps are passed, so no visibility gate
  public function setLamps(lamps:Array<LampPost>):Void
    {
      lampSrc = lamps;
    }

// attach a transient effect to an actor's billboard (build it from render.anim.*, e.g.
// new Shake(BASE_MS, amp) on damage, new Lunge(...) on melee); no-op if the actor has no
// live billboard state yet
  public function playFx(e:Entity, fx:Effect):Bool
    {
      var a = actors.get(e);
      if (a == null) return false;
      a.fx = fx;
      return true;
    }

// rebuild all actor sprites from live game state; actors slide + fade, effects layer
// on top. objects/AI gated on player fog/LOS to match the 2D view
  public function update(dtMs:Float):Void
    {
      sprites.begin();
      beams.begin();
      sparks.begin();
      muzzleLights.update(dtMs);
      // gather visible barrels once up front (before the actor loops) so drawActor can flicker their
      // warm light onto nearby actors, and the flame/shadow pass below reuses the same list
      gatherBarrels();
      if (curBarrels.length > 0)
        flameT += dtMs;
      badgeT += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS; // turn-unit clock for badge pulses
      // player state transitions: leap onto the host on attach, leap back off on leaving it
      var st = game.player.state;
      if (st == _PlayerState.PLR_STATE_ATTACHED &&
          lastState == _PlayerState.PLR_STATE_PARASITE)
        startJumpOnFace();
      else if (st == _PlayerState.PLR_STATE_PARASITE &&
               (lastState == _PlayerState.PLR_STATE_ATTACHED ||
                lastState == _PlayerState.PLR_STATE_HOST))
        startLeaveHost();
      lastState = st;

      var tp = haxe.Timer.stamp();
      // objects (sewer hatches etc.): static, but still fade. parasite keeps seeing
      // sensable objects outside LOS
      for (o in game.area.getObjects())
        if (o.entity != null)
          {
            var vis =
              !game.player.vars.losEnabled ||
              game.playerArea.sees(o.x, o.y) ||
              (game.player.state != _PlayerState.PLR_STATE_HOST && o.sensable());
            drawActor(o.entity, vis, dtMs, 0.0, 1.0, o.isGroundDecal());
            if (vis)
              drawObjTarget(o);
          }
      var tObj = haxe.Timer.stamp();
      // AI: gated on player fog/LOS so the 3D view can't reveal enemies 2D hides
      for (ai in game.area.getAllAI())
        if (ai.entity != null)
          {
            var vis =
              !game.player.vars.losEnabled ||
              game.playerArea.sees(ai.x, ai.y);
            drawActor(ai.entity, vis, dtMs);
            if (vis)
              {
                var badges = ai.getBadges();
                drawAITarget(ai);
                drawXray(ai, badges);
                drawBadges(ai, badges, dtMs);
              }
          }
      var tAI = haxe.Timer.stamp();
      // player billboard: free parasite draws its own sprite; while attached it rides on
      // the host's head (the host itself is still drawn by the AI loop above); once in a
      // host the parasite is hidden inside it and only the ring marks the player
      if (st == _PlayerState.PLR_STATE_PARASITE)
        drawActor(game.playerArea.entity, true, dtMs);
      else if (st == _PlayerState.PLR_STATE_ATTACHED)
        drawActor(game.playerArea.entity, true, dtMs, ATTACH_HEAD_Y, ATTACH_SCALE);
      // just invaded (now inside the host): keep drawing the parasite on the host's head with
      // vis=false so it fades out smoothly instead of popping; once faded drawActor drops it
      else if (st == _PlayerState.PLR_STATE_HOST)
        drawActor(game.playerArea.entity, false, dtMs, ATTACH_HEAD_Y, ATTACH_SCALE);
      // seed-derived street debris (render-only), then persisted decals (ground blood + wall
      // bullet holes), then transient FX (blood, death ghosts, gun shots)
      drawDebris();
      drawDecals();
      // burning barrels: flame lights + soft flame body/embers. then fake cast shadows from both
      // barrels AND lamps. shadows draw AFTER the decals above so they darken blood/debris, and below
      // the actor/marker layers (renderOrder) so the icon + selection ring stay on top
      flameBodyAndShadows(dtMs);
      castShadows();
      driveFireLoop();
      particles.update(dtMs, paint);
      // hide leftover pooled meshes
      sprites.end();
      beams.end();
      sparks.end();
      if (DEBUG_PERF)
        perfLog(tp, tObj, tAI);
    }

// frame profiler: accumulate per-pass ms, warn on a spike, log a summary each ~second.
// objects/AI passes vs my added passes (decals + particles), plus live counts
  function perfLog(t0:Float, tObj:Float, tAI:Float):Void
    {
      var tEnd = haxe.Timer.stamp();
      var msObj = (tObj - t0) * 1000;
      var msAI = (tAI - tObj) * 1000;
      var msPass = (tEnd - tAI) * 1000; // decals + particles (+ pool hide)
      _pObj += msObj; _pAI += msAI; _pPass += msPass;
      // count the live actor-anim entries (leak check)
      var na = 0;
      for (_ in actors.keys()) na++;
      // spike: a single update pass over ~half a 60fps frame budget
      if ((tEnd - t0) * 1000 > 8.0)
        trace('[street-perf] SPIKE ' + Std.int((tEnd - t0) * 1000) + 'ms' +
          ' obj=' + Std.int(msObj) + ' ai=' + Std.int(msAI) + ' pass=' + Std.int(msPass) +
          ' | decalScan=' + _decalScan + ' decalDraw=' + _decalDraw +
          ' particles=' + particles.count() + ' quads=' + sprites.count() + ' actors=' + na);
      _pf++;
      if (_pf >= 60)
        {
          trace('[street-perf] avg/frame obj=' + fix(_pObj / _pf) + 'ms ai=' + fix(_pAI / _pf) +
            'ms pass=' + fix(_pPass / _pf) + 'ms' +
            ' | decalScan=' + _decalScan + ' decalDraw=' + _decalDraw +
            ' particles=' + particles.count() + ' quads=' + sprites.count() + ' actors=' + na);
          _pf = 0; _pObj = 0; _pAI = 0; _pPass = 0;
        }
    }

// two-decimal ms for logs
  inline function fix(v:Float):String
    return '' + Std.int(v * 100) / 100;

// set the seed-derived debris scatter for the current city (render-only, rebuilt per show)
  public function setDebris(list:Array<render.world.Debris.DebrisSpot>):Void
    {
      debris = list;
    }

// draw the seed-derived street debris as content-cropped flat ground quads, fog-gated per cell
// like the blood decals. render-only — these are not game-area decorations, so they never persist
  function drawDebris():Void
    {
      if (debris == null)
        return;
      var los = game.player.vars.losEnabled;
      for (s in debris)
        {
          if (los &&
              !game.playerArea.sees(s.col, s.row))
            continue;
          var gs = sprites.texContent('entities', s.ix, s.iy, false, RenderConfig.DECAL.debrisMul);
          if (gs == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          sprites.paintGround(w.x, WorldCtx.floorY(s.col, s.row) + 0.04, w.z, gs, 1.0, s.scale, s.angle);
        }
    }

// gather this frame's visible burning barrels into curBarrels (world rim pos + flicker phase). one
// getObjects scan, reused by the actor-glow (drawActor), the flame body, and the shadow pass
  function gatherBarrels():Void
    {
      curBarrels = [];
      var los = game.player.vars.losEnabled;
      for (o in game.area.getObjects())
        if (o.type == 'burning_barrel' &&
            (!los || game.playerArea.sees(o.x, o.y)))
          {
            var w = CityConfig.cellToWorld(o.x, o.y);
            curBarrels.push({ x: w.x, z: w.z, floor: WorldCtx.floorY(o.x, o.y),
              col: o.x, row: o.y, phase: o.x * 12.9898 + o.y * 78.233 });
          }
    }

// drive the looping fire sound off the nearest visible barrel: world distance from the player's
// smooth pose to the closest barrel, mapped to 0 (>= soundRangeCells away) .. 1 (on top of it).
// called every frame so it silences on walk-away; lazy no-op when no barrel has ever been near
  function driveFireLoop():Void
    {
      var range = RenderConfig.FLAME.soundRangeCells * CityConfig.CELL;
      var pa = actors.get(game.playerArea.entity);
      var frac = 0.0;
      if (pa != null)
        for (b in curBarrels)
          {
            var dx = pa.x - b.x;
            var dz = pa.z - b.z;
            var d = Math.sqrt(dx * dx + dz * dz);
            if (d < range)
              {
                var f = 1 - d / range;
                if (f > frac)
                  frac = f;
              }
          }
      game.scene.sounds.updateFireLoop(frac);
    }

// warm emissive intensity a nearby barrel throws onto an actor at pose a: strongest barrel within
// light range, pulsing with the flicker, fading to 0 at the range edge. 0 when none in range
  function flameLit(a:Actor):Float
    {
      if (curBarrels.length == 0)
        return 0.0;
      var F = RenderConfig.FLAME;
      var range = F.litRangeCells * CityConfig.CELL;
      var best = 0.0;
      for (b in curBarrels)
        {
          var dx = a.x - b.x;
          var dz = a.z - b.z;
          var d = Math.sqrt(dx * dx + dz * dz);
          if (d >= range)
            continue;
          var v = F.litStrength * FlameLights.flicker(flameT, b.phase) * (1 - d / range);
          if (v > best)
            best = v;
        }
      return best;
    }

// drive the flame-light pool + draw the flame body/embers + cast fake shadows, all off the
// pre-gathered curBarrels. no-op when no barrel is in view, so non-low-tier cities pay nothing
  function flameBodyAndShadows(dtMs:Float):Void
    {
      if (curBarrels.length == 0)
        return;
      var F = RenderConfig.FLAME;
      // pooled warm lights follow the nearest barrels to the player
      var pe = game.playerArea.entity;
      if (flameLights != null)
        flameLights.update(flameT, curBarrels, pe.mx, pe.my);
      // flame body + the odd ember, per visible barrel
      for (b in curBarrels)
        {
          drawFlameBody(b);
          if (Math.random() < dtMs / F.emberMs)
            particles.add(new FlameEmber3D(b.x, b.floor + F.rimY, b.z, b.phase));
        }
    }

// draw one barrel's flame: a short column of warm camera-facing soft dots rising off the rim,
// tapering + swaying, breathing with the shared flicker (hot core at the base, cooler tip)
  function drawFlameBody(b:FlameBarrel):Void
    {
      var F = RenderConfig.FLAME;
      // lazy-load the flame sprite (clamp-wrapped alpha PNG) once
      if (flameTex == null)
        {
          flameTex = render.Textures.loadTexture(RenderConfig.TEXTURES.flame, 'wall');
          flameTex.wrapS = flameTex.wrapT = THREE.ClampToEdgeWrapping;
        }
      var fl = FlameLights.flicker(flameT, b.phase);
      var fl2 = FlameLights.flicker(flameT, b.phase + 2.3);   // inner layer flickers on its own beat
      var baseY = b.floor + F.rimY;
      // soft glow halo at the rim (low additive alpha, centered — no sway)
      sparks.streak(b.x, baseY + F.bodyRise * 0.2, b.z, 0, 1, 0,
        F.glowW, F.glowW, F.colorHot, F.glowAlpha * (0.6 + 0.4 * fl), Sprites.ORD_ACTOR);
      // outer flame layer: cooler + bigger, gentle vertical bob, base pinned at the rim
      var hO = F.bodyRise * 1.1 * (0.8 + 0.35 * fl);
      var wO = F.bodyW * 1.15 * (0.75 + 0.4 * fl);
      var bobO = Math.sin(flameT * 0.012 + b.phase) * 0.05 * F.bodyRise;
      sparks.flameQuad(b.x, baseY + hO * 0.5 + bobO, b.z, wO, hO, flameTex, F.colorTip,
        F.bodyAlpha * (0.5 + 0.4 * fl) * 0.8, Sprites.ORD_ACTOR);
      // inner flame layer: hotter + smaller + shorter, faster bob
      var hI = F.bodyRise * 0.72 * (0.85 + 0.4 * fl2);
      var wI = F.bodyW * 0.7 * (0.7 + 0.5 * fl2);
      var bobI = Math.sin(flameT * 0.02 + b.phase * 1.7) * 0.06 * F.bodyRise;
      sparks.flameQuad(b.x, baseY + hI * 0.5 + bobI, b.z, wI, hI, flameTex, F.colorHot,
        F.bodyAlpha * (0.6 + 0.4 * fl2), Sprites.ORD_ACTOR);
    }

// fake cast shadows: for every visible upright actor, lay a black soft-edged copy of its sprite on
// the ground, stretched away from each nearby barrel AND street lamp. drawn after the ground decals
// so a shadow darkens the blood/debris it crosses. runs every frame — barrels may be absent, lamps
// aren't. builds this frame's light lists once (shared by all casters), then projects per actor
  function castShadows():Void
    {
      var F = RenderConfig.FLAME;
      // barrels: breathe with the flame, gated by shadowRangeCells
      var barrelLights:Array<CastShadows.ShadowLight> = [];
      var brange = F.shadowRangeCells * CityConfig.CELL;
      for (b in curBarrels)
        barrelLights.push({
          x: b.x, z: b.z, range: brange, lenMul: F.shadowLenMul,
          op: F.shadowOp, fade: F.shadowFade, flicker: FlameLights.flicker(flameT, b.phase),
        });
      // lamps: steady; only the lamps lit this frame are in lampSrc, so no visibility gate needed
      var lampLights:Array<CastShadows.ShadowLight> = [];
      if (lampSrc != null)
        {
          var L = RenderConfig.LAMP_SHADOW;
          var lrange = L.rangeCells * CityConfig.CELL;
          for (lp in lampSrc)
            lampLights.push({
              x: lp.x, z: lp.z, range: lrange, lenMul: L.lenMul,
              op: L.op, fade: L.fade, flicker: 1.0,
            });
        }
      if (barrelLights.length == 0 &&
          lampLights.length == 0)
        return;
      // AI + non-flat objects (skip the barrels themselves) + a free parasite are the casters
      for (ai in game.area.getAllAI())
        if (ai.entity != null)
          actorShadow(ai.entity, barrelLights, lampLights);
      for (o in game.area.getObjects())
        if (o.entity != null &&
            !o.isGroundDecal() &&
            o.type != 'burning_barrel')
          actorShadow(o.entity, barrelLights, lampLights);
      if (game.player.state == _PlayerState.PLR_STATE_PARASITE)
        actorShadow(game.playerArea.entity, barrelLights, lampLights);
    }

// cast one actor's shadows: fetch its black silhouette once, then project it away from the barrels
// and the lamps (each capped by its own max). all direction/length/opacity math lives in CastShadows
  function actorShadow(e:Entity, barrelLights:Array<CastShadows.ShadowLight>, lampLights:Array<CastShadows.ShadowLight>):Void
    {
      var a = actors.get(e);
      if (a == null ||
          a.op < 0.05)
        return;
      var gs = sprites.shadowContent(e.imageName, e.ix, e.iy, e.isMaleAtlas);
      if (gs == null)
        return;
      var floor = WorldCtx.floorY(a.col, a.row) + 0.06;   // just above the splat/debris plane (+0.04)
      CastShadows.project(sprites, gs, a.x, a.z, floor, a.op, barrelLights, RenderConfig.FLAME.shadowMax);
      CastShadows.project(sprites, gs, a.x, a.z, floor, a.op, lampLights, RenderConfig.LAMP_SHADOW.max);
    }

// draw persisted tile decorations: SPLAT blood as flat ground quads, WALLHOLE bullet holes as
// upright quads on their wall face. scans the tile grid (sparse + capped); non-3D floor
// decorations stay 2D-only
  function drawDecals():Void
    {
      var tiles = game.area.tiles;
      if (tiles == null)
        return;
      var los = game.player.vars.losEnabled;
      var t = Const.TILE_SIZE; // dx/dy are pixel offsets in +/-tile/2 (matches 2D splats)
      var scan = 0, draw = 0;
      for (x in 0...game.area.width)
        {
          if (tiles[x] == null)
            continue;
          for (y in 0...game.area.height)
            {
              scan++;
              var tile = tiles[x][y];
              if (tile == null ||
                  tile.decoration == null ||
                  tile.decoration.length == 0)
                continue;
              for (d in tile.decoration)
                if (drawDecal(d, x, y, los, t))
                  draw++;
            }
        }
      _decalScan = scan; _decalDraw = draw;
    }

// paint one tile decoration; returns true if a quad was drawn. SPLAT blood lays flat on the
// ground; WALLHOLE bullet holes stand upright on their wall face. both fog-gate on LOS
  function drawDecal(d:tiles.Decoration, x:Int, y:Int, los:Bool, t:Float):Bool
    {
      // ground blood: fog-gate on this cell, lay flat
      if (d.tag == 'SPLAT')
        {
          if (d.icon == null ||
              (los && !game.playerArea.sees(x, y)))
            return false;
          var dx = (d.dx != null ? d.dx : 0) / t;
          var dy = (d.dy != null ? d.dy : 0) / t;
          var w = CityConfig.cellToWorld(x + dx, y + dy);
          var tex = sprites.tex('entities', d.icon.col, d.icon.row, false, RenderConfig.DECAL.bloodMul);
          if (tex == null)
            return false;
          var sc = (d.scale != null ? d.scale : 1.0);
          sprites.paint(w.x, WorldCtx.floorY(x, y) + 0.04, w.z, tex, 1.0, sc, true,
            (d.angle != null ? d.angle : 0.0));
          return true;
        }
      // bullet hole: stand it on its wall face, fog-gate on the open cell in front
      else if (d.tag == 'WALLHOLE' &&
               d.face != null)
        {
          var hts = holeTextures(d.metal == true);
          if (hts.length == 0)
            return false;
          var fdir:Int = d.face;
          var dv = render.world.Geom.DIRV[fdir];
          if (los && !game.playerArea.sees(x + dv[0], y + dv[1]))
            return false;
          var w = CityConfig.cellToWorld(x + (d.dx != null ? d.dx : 0) / t,
            y + (d.dy != null ? d.dy : 0) / t);
          var roll = (d.angle != null ? d.angle : 0.0);
          // fold the stored roll into the variant so co-cell holes differ (reload-stable)
          var variant = ((x * 31 + y * 17 + Std.int(roll * 10)) % hts.length + hts.length) % hts.length;
          var sc = (d.scale != null ? d.scale : RenderConfig.WALLHOLE.scale);
          var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
          // nudge proud of the wall face along the outward normal (clears the opaque
          // face so the hole isn't depth-culled; no z-fight since depthWrite is off)
          sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12,
            hts[variant], 1.0, sc, render.world.Geom.faceRotY(fdir), roll);
          return true;
        }
      return false;
    }

// lazily load the bullet-hole wall textures once, per material (masonry vs metal-warehouse)
  function holeTextures(metal:Bool):Array<Texture>
    {
      if (metal)
        {
          if (holeTexMetal == null)
            holeTexMetal = loadHoleTex(RenderConfig.TEXTURES.bulletHolesMetal);
          return holeTexMetal;
        }
      if (holeTex == null)
        holeTex = loadHoleTex(RenderConfig.TEXTURES.bulletHoles);
      return holeTex;
    }

// load a set of clamp-wrapped alpha hole PNGs
  function loadHoleTex(paths:Array<String>):Array<Texture>
    {
      return [for (p in paths)
        {
          var tx = render.Textures.loadTexture(p, 'wall');
          tx.wrapS = tx.wrapT = THREE.ClampToEdgeWrapping;
          tx;
        }];
    }

// paint the targeting markers under a visible AI: the stored-target frame and/or the
// currently-cycled reticle (mirrors the 2D FRAME/RETICLE sprites, laid flat on the ground)
  function drawAITarget(ai:AI):Void
    {
      var tg = game.ui.hud.targeting;
      paintTargetMarker(ai.entity,
        tg.isTargetedAI(ai),
        game.ui.hud.state == HUD_TARGETING && tg.isTargetingAI(ai));
    }

// same for a visible attackable object
  function drawObjTarget(obj:AreaObject):Void
    {
      var tg = game.ui.hud.targeting;
      paintTargetMarker(obj.entity,
        tg.isTargetedObject(obj),
        game.ui.hud.state == HUD_TARGETING && tg.isTargetingObject(obj));
    }

// lay the target frame (framed) and/or targeting reticle (cursor) as flat ground quads under
// an entity's slide pos; reticle a hair higher so it wins the ground z-order over the frame
  function paintTargetMarker(e:Entity, framed:Bool, cursor:Bool):Void
    {
      if (!framed && !cursor)
        return;
      var a = actors.get(e);
      if (a == null)
        return;
      var floor = WorldCtx.floorY(a.col, a.row);
      if (framed)
        sprites.paint(a.x, floor + 0.05, a.z,
          sprites.tex('entities', Const.FRAME_TARGET_FRAME, Const.ROW_REGION_ICON, false),
          1.0, TARGET_SCALE, true, 0.0, Sprites.ORD_MARK);
      if (cursor)
        sprites.paint(a.x, floor + 0.06, a.z,
          sprites.tex('entities', Const.FRAME_TARGET_RETICLE, Const.ROW_REGION_ICON, false),
          1.0, TARGET_SCALE, true, 0.0, Sprites.ORD_MARK);
    }

// through-wall x-ray outline: a colored, patterned silhouette of the AI's own sprite, drawn ONLY
// where the AI is occluded from the camera. depthTest stays on but depthFunc = GreaterDepth, so a
// fragment passes only where the depth buffer holds something NEARER (a wall in front) — meaning a
// clear-view AI draws nothing, while one hidden behind a wall (but still in the player's LOS) glows
// through so it stays spottable. color = current alert status (followers cult-pink)
  function drawXray(ai:AI, badges:Array<_Badge>):Void
    {
      // never x-ray the player's own host: buildings in front of it get made transparent instead
      if (game.player.host == ai)
        return;
      var a = actors.get(ai.entity);
      if (a == null ||
          a.op < 0.05)
        return;
      var e = ai.entity;
      var tex = sprites.silTex(e.imageName, e.ix, e.iy, e.isMaleAtlas,
        RenderConfig.XRAY.fill, RenderConfig.XRAY.hatchSpacing, RenderConfig.XRAY.hatchThick);
      if (tex == null)
        return;
      var col = outlineColor(ai, badges);
      var wy = WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5;
      // emissive = the state color so the pattern reads at night; GreaterDepth = occluded-only
      sprites.paint(a.x, wy, a.z,
        tex, a.op, RenderConfig.XRAY.grow, false, 0.0, Sprites.ORD_ACTOR, col, RenderConfig.XRAY.emissive, true, THREE.GreaterDepth);
    }

// outline color for an AI: followers read cult-pink; otherwise the current alert status (matching
// the alert badge color), or a dim slate when calm/idle. colors mirror the app.css HUD tokens
  function outlineColor(ai:AI, badges:Array<_Badge>):Int
    {
      if (ai.isPlayerCultist())
        return 0xfd97ff;                                 // cult pink (--text-color-cultist)
      for (b in badges)
        {
          if (b.svg == 'alert1') return 0xeaebed;        // first suspicion
          if (b.svg == 'alert2') return 0xe0b34a;        // amber
          if (b.svg == 'alert3') return 0xec894e;        // orange
          if (b.svg == 'alerted' ||
              b.svg == 'search' ||
              b.svg == 'calling') return 0xf26a6a;       // danger-red
        }
      return 0x6b7078;                                   // calm/idle — dim slate
    }

// paint the AI's status badges (alert / npc / cultist / effect) as a small row of upright quads
// just above its head. alert + npc render from scalable SVG (color-coded by state), effect +
// cultist from the PNG atlas. mirrors the 2D AIEntity.draw badge stack. see ai.AI.getBadges
  function drawBadges(ai:AI, badges:Array<_Badge>, dtMs:Float):Void
    {
      var a = actors.get(ai.entity);
      if (a == null ||
          a.op < 0.05)
        return;
      // per-AI change-pop: pop the row whenever the badge set changes (alert level up/down, a new
      // marker) — but not on first sight (settled silently) or when it clears to nothing
      var ba = badgeAnims.get(ai.entity);
      var sig = badgeSig(badges);
      if (ba == null)
        {
          ba = { sig: sig, pop: null };
          badgeAnims.set(ai.entity, ba);
        }
      else if (ba.sig != sig)
        {
          ba.sig = sig;
          if (sig != '')
            ba.pop = new Pop(RenderConfig.BASE_MS * 1.0);
        }
      if (badges.length == 0)
        {
          ba.pop = null;
          return;
        }
      // advance the change-pop (row-wide scale bounce), clear when done
      var popScale = 1.0;
      if (ba.pop != null)
        {
          if (ba.pop.advance(dtMs))
            ba.pop = null;
          else popScale = ba.pop.scale;
        }
      var scale = 0.32;
      // anchor the row along the camera's up/right axes (screen-space), not a fixed world +Y: the
      // camera pitch flattens as it zooms in (CameraRig), which foreshortens a world-Y offset and
      // drops the badges onto the forehead. a screen-up lift stays above the head at any pitch/zoom
      var up = new Vector3(0, 1, 0).applyQuaternion(camera.quaternion);   // world dir = up on screen
      var right = new Vector3(1, 0, 0).applyQuaternion(camera.quaternion); // world dir = right on screen
      var lift = Sprites.SIZE * RenderConfig.BADGE_LIFT;                  // clears the head at any pitch
      var spread = Sprites.SIZE * scale * 0.95;                           // per-badge screen-horizontal step
      var bx = a.x + up.x * lift;                                         // head centre + screen-up lift
      var by = WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5 + up.y * lift;
      var bz = a.z + up.z * lift;
      var s0 = -(badges.length - 1) / 2;                                 // centre the row
      // looping pulse phase for the calling badge (period ~6.4 turn, anim-speed scaled via badgeT)
      var wave = Math.sin(badgeT / 6.4 * 2 * Math.PI);
      // search badge sweep phase (period ~5.6 turn): the magnifier rocks side to side like scanning
      var swing = Math.sin(badgeT / 5.6 * 2 * Math.PI);
      // alerted badge phase (period ~6.4 turn): slow scale breath on the red "!" so it reads as a live threat
      var breath = Math.sin(badgeT / 6.4 * 2 * Math.PI);
      for (i in 0...badges.length)
        {
          var b = badges[i];
          var tex = (b.svg != null)
            ? badgeSvgTex(b.svg)
            : sprites.tex('entities', b.col, b.row, false);
          if (tex == null) // svg still decoding / atlas not ready — hole stays stable (index-placed)
            continue;
          var sc = scale * popScale;
          var em = 1.0;
          var roll = 0.0;
          var pvx = 0.0; // pivot-compensation world offset so search rocks about the handle tip
          var pvy = 0.0;
          var pvz = 0.0;
          // calling: pulsating waves — breathe the glyph + glow so it reads as an active broadcast
          if (b.svg == 'calling')
            {
              sc *= 1 + 0.16 * wave;
              em = 0.8 + 0.5 * (0.5 + 0.5 * wave);
            }
          // alerted: slow scale breath on the red "!" — a live, sustained threat
          else if (b.svg == 'alerted')
            sc *= 1 + 0.10 * breath;
          // search: rock the magnifier ±~15° about its handle tip so the lens swings in an arc, like an
          // AI sweeping for the player. three rotates the quad about its centre, so translate by
          // (h - rot(h)) to hold the handle fixed. h = handle tip offset from the glyph centre:
          // ≈(+8.5,+8.5) of 24 viewBox units (image +y = screen-down = -up)
          else if (b.svg == 'search')
            {
              roll = 0.26 * swing;
              var u = Sprites.SIZE * sc / 24;
              var hx = 8.5 * u;    // along screen-right
              var hy = -8.5 * u;   // along screen-up
              var c = Math.cos(roll);
              var s = Math.sin(roll);
              var dx = hx - (hx * c - hy * s);
              var dy = hy - (hx * s + hy * c);
              pvx = right.x * dx + up.x * dy;
              pvy = right.y * dx + up.y * dy;
              pvz = right.z * dx + up.z * dy;
            }
          // self-lit (emissive white, shaped by the badge's own texture) so UI badges stay legible
          // at night; depthTest off so a wall in front never occludes the marker (always-on-top UI)
          var off = (s0 + i) * spread;
          sprites.paint(bx + right.x * off + pvx, by + right.y * off + pvy, bz + right.z * off + pvz,
            tex, a.op, sc, false, roll, Sprites.ORD_ACTOR, 0xffffff, em, false);
        }
    }

// signature of a badge set (glyph keys / atlas cells) to detect changes for the status-change pop
  inline function badgeSig(badges:Array<_Badge>):String
    {
      var s = '';
      for (b in badges)
        s += (b.svg != null ? b.svg : b.col + '_' + b.row) + ',';
      return s;
    }

// rasterize a badge glyph (UISvg.badge) recolored to its state color, cached at a fixed px edge.
// inject xmlns (a standalone data: <img> is parsed as bare XML — the UISvg glyphs omit it since
// inline DOM infers it) + explicit width/height (a viewBox-only SVG can decode to naturalWidth 0)
  inline function badgeSvgTex(key:String):CanvasTexture
    {
      var svg = StringTools.replace(ui.UISvg.badge(key), 'currentColor', badgeColor(key));
      svg = StringTools.replace(svg, '<svg ', '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" ');
      return sprites.svgTex('svg:' + key, svg, 128);
    }

// state color for an SVG badge glyph — matches the 2D atlas art: "?" ramps white->yellow->orange
// as alertness rises, "!"/search/calling are red. npc is self-colored (ignored here)
  inline function badgeColor(key:String):String
    {
      // muted HUD tokens (app.css) not pure primaries, so badges read native to the moody palette
      if (key == 'alert1') return '#eaebed';   // body-white — first suspicion (--text)
      if (key == 'alert2') return '#e0b34a';   // amber (--text-color-time)
      if (key == 'alert3') return '#ec894e';   // muted orange, between amber and alert-red
      if (key == 'alerted') return '#f26a6a';  // danger-red — fully alerted (--text-color-alert)
      if (key == 'search') return '#f26a6a';   // danger-red — hunting last-seen
      if (key == 'calling') return '#f26a6a';  // danger-red — calling backup
      return '#eaebed';
    }

// find the visible AI whose head projects nearest the given client point (within a px radius);
// returns the AI + its projected client px (the tooltip beam anchor), or null. project-nearest
// rather than raycasting the transparent, entity-less billboard quads
  public function pickAI(clientX:Float, clientY:Float, rect:Dynamic):{ ai:AI, px:Float, py:Float }
    {
      var best:AI = null;
      var bestPx = 0.0, bestPy = 0.0, bestD = 1e30;
      var rad = 46.0;                                            // px hit radius around a head
      var los = game.player.vars.losEnabled;
      var v = new Vector3();
      for (ai in game.area.getAllAI())
        {
          if (ai.entity == null ||
              (los && !game.playerArea.sees(ai.x, ai.y)))
            continue;
          var a = actors.get(ai.entity);
          if (a == null ||
              a.op < 0.3)
            continue;
          v.set(a.x, WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5, a.z);
          v.project(camera);
          if (v.z > 1)                                          // behind the camera
            continue;
          var sx = rect.left + (v.x * 0.5 + 0.5) * rect.width;
          var sy = rect.top + (-v.y * 0.5 + 0.5) * rect.height;
          var dx = sx - clientX, dy = sy - clientY;
          var d = dx * dx + dy * dy;
          if (d < bestD &&
              d <= rad * rad)
            {
              bestD = d;
              best = ai;
              bestPx = sx;
              bestPy = sy;
            }
        }
      if (best == null)
        return null;
      return { ai: best, px: bestPx, py: bestPy };
    }

// throw a burst of blood from a target cell, biased away from the attacker; drops arc and
// land as SPLAT ground decals. bloodRow/bloodFirstCol pick the blood variant by type
  public function burst(tgtCol:Int, tgtRow:Int, awayX:Float, awayZ:Float, bloodRow:Int, bloodFirstCol:Int):Void
    {
      BloodDrop3D.burst(particles, game, tgtCol, tgtRow, awayX, awayZ, bloodRow, bloodFirstCol);
    }

// spawn one 3D gun-shot pellet (tracer + muzzle flash); blood + impact sound fire via the
// onImpact closure when the tracer lands (null for extra pellets so it fires once)
  public function shot(muzzle:Vector3, impact:Vector3, startDelay:Float, onImpact:Void->Void):Void
    {
      particles.add(new Shot3D(muzzle, impact, startDelay, onImpact));
    }

// spawn a spark spray at a wall strike (x,y,z), embers flung back off the wall (backX,backZ) + up;
// startDelay defers it until the tracer arrives
  public function sparkBurst(x:Float, y:Float, z:Float, backX:Float, backZ:Float, startDelay:Float):Void
    {
      particles.add(new SparkBurst3D(x, y, z, backX, backZ, startDelay));
    }

// pulse a pooled muzzle light at the shooter (constant scene light count, no recompile)
  public function muzzleFlash(x:Float, y:Float, z:Float):Void
    {
      muzzleLights.flash(x, y, z);
    }

// snapshot a dying actor's sprite into a fade-out ghost (called before the AI entity is
// nulled), so the billboard eases out instead of hard-cutting to the corpse
  public function startDeathFade(e:Entity):Void
    {
      var a = actors.get(e);
      if (a == null)
        return;
      var tex = texFor(e);
      if (tex == null)
        return;
      particles.add(new DeathFade3D(tex,
        a.x, WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5, a.z,
        1.0, a.op));
    }

// seed a new entity's actor at zero opacity so it fades in (the body appearing on death)
  public function seedFadeIn(e:Entity):Void
    {
      if (actors.get(e) != null)
        return;
      var w = CityConfig.cellToWorld(e.mx, e.my);
      actors.set(e, { col: e.mx, row: e.my, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1,
                      op: 0.0, opTarget: 1.0, fx: null });
    }

// advance one actor's anim state and paint its billboard (no-op if fully faded with no effect
// running). baseY/baseScale set the resting pose (nonzero for the attached parasite riding a
// host's head). flat lays the sprite on the ground as a decal instead of standing it up
  function drawActor(e:Entity, vis:Bool, dtMs:Float, baseY:Float = 0.0, baseScale:Float = 1.0, flat:Bool = false):Void
    {
      var a = actor(e, vis, dtMs);
      if (a.op <= 0.001 &&
          a.fx == null)
        return;
      // rest on the cell's ground surface (walkway tops sit a curb above the road)
      var floor = WorldCtx.floorY(a.col, a.row);
      // decals hug the ground; upright sprites centre at half their height
      var wy = flat ? floor + 0.05 : floor + Sprites.SIZE * 0.5 + baseY;
      // flat objects sit in the ground-decal layer; upright icons ride above their own shadow + the
      // target ring. an upright actor within a barrel's light gets a warm flicker glow on its sprite
      var order = flat ? Sprites.ORD_DECAL : Sprites.ORD_ACTOR;
      var emInt = flat ? 0.0 : flameLit(a);
      if (a.fx != null)
        sprites.paint(a.x + a.fx.offx, wy + a.fx.offy, a.z + a.fx.offz, texFor(e), a.op, baseScale * a.fx.scale, flat, 0.0, order, RenderConfig.FLAME.litColor, emInt);
      else
        sprites.paint(a.x, wy, a.z, texFor(e), a.op, baseScale, flat, 0.0, order, RenderConfig.FLAME.litColor, emInt);
    }

// launch the parasite's leap onto the host's head: snap its slide onto the host cell so
// the effect owns the whole visible travel, then arc it in from where it stood on the
// ground. called once on the parasite->attached transition
  function startJumpOnFace():Void
    {
      var pe = game.playerArea.entity;
      var a = actors.get(pe);
      if (a == null) return;
      // where the free parasite currently stands (approach cell, ground)
      var startX = a.x, startZ = a.z;
      // snap the base slide onto the host cell (the effect renders the leap)
      var w = CityConfig.cellToWorld(pe.mx, pe.my);
      a.col = pe.mx; a.row = pe.my;
      a.fromX = w.x; a.fromZ = w.z; a.x = w.x; a.z = w.z; a.t = 1;
      // offsets are relative to the resting head pose (decay to 0 on landing); the effect
      // owns its launch/landing sounds
      a.fx = new JumpOnFace(game, RenderConfig.BASE_MS, startX - w.x, -ATTACH_HEAD_Y, startZ - w.z, Sprites.SIZE * 0.5);
    }

// launch the parasite's leap off the host back to the ground: arc down from the head to the
// resting ground pose. called on the leave->parasite transition (detach, leave host, death)
  function startLeaveHost():Void
    {
      var pe = game.playerArea.entity;
      var a = actors.get(pe);
      if (a == null) return;
      var w = CityConfig.cellToWorld(pe.mx, pe.my);
      // coming from ATTACHED the parasite tracked the host, so leap horizontally from where
      // it sat to the destination cell (no teleport); from HOST it wasn't drawn, so its slide
      // is stale — just drop straight down in place
      var px = 0.0, pz = 0.0;
      if (lastState == _PlayerState.PLR_STATE_ATTACHED)
        {
          px = a.x - w.x;
          pz = a.z - w.z;
        }
      a.col = pe.mx; a.row = pe.my;
      a.fromX = w.x; a.fromZ = w.z; a.x = w.x; a.z = w.z; a.t = 1;
      // starts at the head (offset up + horizontal) and lands on the resting ground pose
      a.fx = new LeaveHost(game, RenderConfig.BASE_MS, px, ATTACH_HEAD_Y, pz, Sprites.SIZE * 0.5);
    }

// get/create an actor's anim state and advance it one frame (position slide, opacity
// fade toward want-visible, transient effect). first sight inits settled (no anim)
  function actor(e:Entity, vis:Bool, dtMs:Float):Actor
    {
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var a = actors.get(e);
      if (a == null)
        {
          var w = CityConfig.cellToWorld(e.mx, e.my);
          a = { col: e.mx, row: e.my, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1,
                op: vis ? 1.0 : 0.0, opTarget: vis ? 1.0 : 0.0, fx: null };
          actors.set(e, a);
          return a;
        }
      // position channel. a one-step diagonal move sharing a corner with a building clips
      // that corner; route it through the open shoulder as an L-path (double orthogonal move)
      var bend = ActorAnim.cornerBend(game.area, a.col, a.row, e.mx, e.my);
      ActorAnim.slideTo(a, e.mx, e.my, step,
        bend != null ? bend.col : -1,
        bend != null ? bend.row : -1);
      // opacity channel: ease toward the visibility target (LOS fade, slower than moves)
      a.opTarget = vis ? 1.0 : 0.0;
      var opStep = step * FADE_SPEED;
      if (a.op < a.opTarget) a.op = Math.min(a.opTarget, a.op + opStep);
      else if (a.op > a.opTarget) a.op = Math.max(a.opTarget, a.op - opStep);
      // transient effect: advance it (computes its offsets, fires onFinish), clear when done
      if (a.fx != null &&
          a.fx.advance(dtMs))
        a.fx = null;
      return a;
    }

// texture for an entity's current atlas cell
  function texFor(e:Entity):CanvasTexture
    return sprites.tex(e.imageName, e.ix, e.iy, e.isMaleAtlas, RenderConfig.DECAL.actorMul);
}

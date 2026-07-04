package render;

import three.Three;
import citygen.CityConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.anim.Effect;
import render.anim.JumpOnFace;
import render.anim.LeaveHost;
import render.particles.Sprites;
import render.particles.Beams;
import render.particles.MuzzleLights;
import render.particles.Paint3D;
import render.particles.Particles3D;
import render.particles.BloodDrop3D;
import render.particles.DeathFade3D;
import render.particles.Shot3D;
import game.Game;
import entities.Entity;
import ai.AI;
import objects.AreaObject;

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
  var beams:Beams;                                        // unlit additive bright-FX pool (gun tracers, sparks)
  var muzzleLights:MuzzleLights;                          // fixed muzzle-light pool (constant scene light count)
  var paint:Paint3D;                                      // the two surfaces handed to each particle each frame
  var particles:Particles3D;                              // transient 3D FX (blood, death crossfade, gun shots)
  // per-actor anim state, keyed by entity identity. ponytail: dead entities linger here
  // until the area rebuild drops this whole object — bounded per area, not worth pruning
  var actors:haxe.ds.ObjectMap<Entity, Actor> = new haxe.ds.ObjectMap();

  var lastState:_PlayerState;                            // prev-frame player state (attach transition)

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
      // created here (before the first render) so the muzzle lights are in NUM_POINT_LIGHTS from
      // frame one — the scene compiles once at the full count, never recompiles on a shot
      muzzleLights = new MuzzleLights(actorGroup);
      paint = { sprites: sprites, beams: beams };
      particles = new Particles3D();
      lastState = game.player.state;
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
      muzzleLights.update(dtMs);
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
              drawAITarget(ai);
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
      // persisted blood decals on the ground, then transient FX (blood, death ghosts, gun shots)
      drawSplatDecals();
      particles.update(dtMs, paint);
      // hide leftover pooled meshes
      sprites.end();
      beams.end();
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

// draw persisted SPLAT tile decorations as flat ground quads (blood). scans the tile grid
// (sparse + capped), skipping non-blood floor decorations which stay 2D-only
  function drawSplatDecals():Void
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
              // fog: don't reveal blood through walls
              if (los &&
                  !game.playerArea.sees(x, y))
                continue;
              for (d in tile.decoration)
                {
                  if (d.tag != 'SPLAT' ||
                      d.icon == null)
                    continue;
                  var dx = (d.dx != null ? d.dx : 0) / t;
                  var dy = (d.dy != null ? d.dy : 0) / t;
                  var w = CityConfig.cellToWorld(x + dx, y + dy);
                  var tex = sprites.tex('entities', d.icon.col, d.icon.row, false);
                  if (tex == null)
                    continue;
                  var sc = (d.scale != null ? d.scale : 1.0);
                  sprites.paint(w.x, WorldCtx.floorY(x, y) + 0.04, w.z, tex, 1.0, sc, true,
                    (d.angle != null ? d.angle : 0.0));
                  draw++;
                }
            }
        }
      _decalScan = scan; _decalDraw = draw;
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
          1.0, TARGET_SCALE, true);
      if (cursor)
        sprites.paint(a.x, floor + 0.06, a.z,
          sprites.tex('entities', Const.FRAME_TARGET_RETICLE, Const.ROW_REGION_ICON, false),
          1.0, TARGET_SCALE, true);
    }

// throw a burst of blood from a target cell, biased away from the attacker; drops arc and
// land as SPLAT ground decals. bloodRow/bloodFirstCol pick the blood variant by type
  public function burst(tgtCol:Int, tgtRow:Int, awayX:Float, awayZ:Float, bloodRow:Int, bloodFirstCol:Int):Void
    {
      BloodDrop3D.burst(particles, game, tgtCol, tgtRow, awayX, awayZ, bloodRow, bloodFirstCol);
    }

// spawn one 3D gun-shot pellet (tracer + flash + sparks); blood + impact sound fire via the
// onImpact closure when the tracer lands (null for extra pellets so it fires once)
  public function shot(muzzle:Vector3, impact:Vector3, startDelay:Float, hit:Bool, onImpact:Void->Void):Void
    {
      particles.add(new Shot3D(muzzle, impact, startDelay, hit, onImpact));
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
      if (a.fx != null)
        sprites.paint(a.x + a.fx.offx, wy + a.fx.offy, a.z + a.fx.offz, texFor(e), a.op, baseScale * a.fx.scale, flat);
      else
        sprites.paint(a.x, wy, a.z, texFor(e), a.op, baseScale, flat);
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
    return sprites.tex(e.imageName, e.ix, e.iy, e.isMaleAtlas);
}

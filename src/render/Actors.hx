package render;

import three.Three;
import citygen.CityConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.anim.*;
import render.particles.*;
import render.actors.*;
import render.decals.Decals;
import game.Game;
import entities.Entity;
import ai.AI;

// the 3D actor billboard layer: mirrors the game's objects/AI/player as sprites, each with a
// position slide + opacity fade + optional transient effect. owns the per-actor anim state and
// paints through a shared Sprites surface; transient FX (blood, death crossfade) live in a
// Particles3D. the ground/wall decals, barrel flame + fake shadows, and AI badge/x-ray/targeting
// markers are split into per-frame sub-passes (render.actors.*), driven in order by update().
// StreetView builds one per city and drives it each frame; game logic triggers effects via
// playFx() and the melee/death bridges
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
  // per-frame sub-passes: each reads the actor-pose map (read-only), paints through the surfaces
  var decals:Decals;                                     // ground/wall decoration + street debris
  var flames:FlameShadows;                               // barrel flame body/glow + fake cast shadows
  var badges:Badges;                                     // AI badges + x-ray outline + targeting markers
  var offscreen:ui.hud.OffscreenHud;                     // screen-edge indicators for seen-but-cropped AI (HUD-owned)
  var bubbles:ui.hud.ChatBubbles;                        // speech bubbles over speaking AI (HUD-owned)
  var convo:ChatConvo;                                   // chat-mode "talking" bubbles over the two conversers
  var _ov = new Vector3();                               // scratch projection vector (off-screen test)
  var _up = new Vector3();                               // scratch: world dir that reads as "up" on screen

  var lastState:_PlayerState;                            // prev-frame player state (attach transition)
  var _deathGhost:DeathFade3D = null;                    // most recent death ghost; the corpse body binds its fade-in to its landing
  var _heldBodies:haxe.ds.ObjectMap<Entity, Bool> = new haxe.ds.ObjectMap(); // corpse bodies kept invisible until their death ghost lands
  // corpse -> the count of ground decals in its cell when it first landed = its appearance slot.
  // snapshotted on first sighting (render-only, no save field): blood present then paints under it,
  // blood sprayed later paints over it. ponytail: on a reload mid-fight the exact pre-existing order
  // is lost (the body re-snapshots above all its current blood) — cosmetic
  var _bodyStackSlot:haxe.ds.ObjectMap<Entity, Int> = new haxe.ds.ObjectMap();
  // cellKey (col*height+row) -> resting-corpse landing slot, rebuilt each frame in the object loop
  // and handed to decals.paint so blood past the slot in that cell paints over the body
  var _corpseCells:Map<Int,Int> = new Map();
  var lampCorners:Map<Int,Int> = null;                  // grid vertex -> lamp dir; slides bend past a post on the cut corner

  // --- frame profiler (toggle from devtools or `perf street`) ---
  public static var DEBUG_PERF = false;                 // render per-pass timings (toggle: `perf street`)
  var _pf = 0;                                          // frames since last summary
  var _pObj = 0.0; var _pAI = 0.0; var _pPass = 0.0;   // accumulated ms: objects, AI, my passes

  static inline var FADE_SPEED = 0.5;                  // LOS opacity fade runs at this * base speed (slower)
  static inline var TURN_SPEED = 2.0;                  // facing flip eases at this * base speed (full turn ~1 BASE_MS)
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
      paint = { sprites: sprites, beams: beams, sparks: sparks };
      particles = new Particles3D();
      // per-frame sub-passes of the actor layer; each is handed the shared actor-pose map so it can
      // read poses (FlameShadows/Badges) — Actors stays its sole writer
      decals = new Decals(game, sprites, actorGroup);
      flames = new FlameShadows(game, actorGroup, sprites, sparks, particles, actors);
      badges = new Badges(game, camera, sprites, actors);
      offscreen = game.ui.hud.offscreen;
      bubbles = game.ui.hud.bubbles;
      convo = new ChatConvo(game, camera, actors, bubbles);
      lastState = game.player.state;
    }

// receive the lamps lit this frame (the pool's active set) so actors cast fake shadows from them
  public function setLamps(lamps:Array<LampPost>):Void
    {
      flames.setLamps(lamps);
    }

// receive the lamp-corner map (built once per scene) so the position slide bends past posts
  public function setLampCorners(corners:Map<Int,Int>):Void
    {
      lampCorners = corners;
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
      _corpseCells.clear();                               // rebuilt below by the object loop, before decals.paint reads it
      muzzleLights.update(dtMs);
      // gather visible barrels once up front (before the actor loops) so drawActor can flicker their
      // warm light onto nearby actors, and the flame/shadow pass below reuses the same list
      flames.gather(dtMs);
      badges.tick(dtMs);                                 // advance the looping badge-pulse clock
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
              (!game.player.vars.losEnabled ||
               game.playerArea.sees(o.x, o.y) ||
               (game.player.state != _PlayerState.PLR_STATE_HOST && o.sensable())) &&
              // a corpse body is held invisible until its death ghost has fallen flat
              !_heldBodies.exists(o.entity);
            // a fallen corpse rests at a small stable yaw/offset (id-derived) so bodies read as
            // having fallen where they died, not stamped on the grid
            var yaw = 0.0, ox = 0.0, oz = 0.0;
            var b = Std.downcast(o, objects.BodyObject);
            if (b != null &&
                o.isGroundDecal())
              {
                var p = bodyPose(o.id);
                yaw = p.yaw;
                ox = p.ox;
                oz = p.oz;
              }
            drawActor(o.entity, vis, dtMs, 0.0, 1.0, o.isGroundDecal(), yaw, ox, oz, true);
            if (vis)
              badges.drawObjTarget(o);
          }
      var tObj = haxe.Timer.stamp();
      // AI: gated on player fog/LOS so the 3D view can't reveal enemies 2D hides
      offscreen.begin();
      bubbles.begin();
      for (ai in game.area.getAllAI())
        if (ai.entity != null)
          {
            var vis =
              !game.player.vars.losEnabled ||
              game.playerArea.sees(ai.x, ai.y);
            drawActor(ai.entity, vis, dtMs);
            if (vis)
              {
                var bs = ai.getBadges();
                badges.drawAITarget(ai);
                badges.drawXray(ai, bs);
                badges.drawBadges(ai, bs, dtMs);
                markOffscreen(ai, bs);
                drawBubble(ai);
              }
          }
      offscreen.end();
      // chat-mode talking bubbles over the two conversers (queued after the barks, before end())
      convo.drive(dtMs);
      bubbles.end();
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
      // seed-derived street debris + persisted decals (ground blood + wall bullet holes), then the
      // barrel flame body/embers + fake cast shadows (barrels + lamps drawn after the decals so they
      // darken them), then the fire loop + transient FX (blood, death ghosts, gun shots)
      // decals fade in/out by radius around the player's smoothed billboard pos (falls back to the
      // logical cell only while the parasite sprite is dropped mid-host-invade)
      var pp = actors.get(game.playerArea.entity);
      var pw = CityConfig.cellToWorld(game.playerArea.x, game.playerArea.y);
      decals.paint(pp != null ? pp.x : pw.x, pp != null ? pp.z : pw.z, dtMs, _corpseCells);
      flames.bodyAndShadows(dtMs);
      flames.driveFireLoop();
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
          ' | decalScan=' + decals.decalScan + ' decalDraw=' + decals.decalDraw +
          ' particles=' + particles.count() + ' quads=' + sprites.count() + ' actors=' + na);
      _pf++;
      if (_pf >= 60)
        {
          trace('[street-perf] avg/frame obj=' + fix(_pObj / _pf) + 'ms ai=' + fix(_pAI / _pf) +
            'ms pass=' + fix(_pPass / _pf) + 'ms' +
            ' | decalScan=' + decals.decalScan + ' decalDraw=' + decals.decalDraw +
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
      decals.setDebris(list);
    }

// the world point at an actor's head — the anchor every screen overlay projects from (edge
// indicators, the hover tooltip, chat bubbles)
  inline function headPoint(a:Actor, out:Vector3):Void
    {
      out.set(a.x, WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5, a.z);
    }

// queue this AI's live bark as a chat bubble above its head. the text/font/variant are set by
// PawnEntity.setText and expire on its turn timer, so nothing here tracks lifetime — the bubble
// layer retires whatever stops being queued
  function drawBubble(ai:AI):Void
    {
      var e = ai.entity;
      if (e.text == null)
        return;
      // mid-chat the two participants talk through the convo bubbles (ChatConvo); mute their barks
      // so a stray line can't fight the talking bubble over the same head
      if (game.ui.hud.state == HUD_CHAT &&
          game.player.chat.target != null &&
          (ai == game.player.host ||
           ai == game.player.chat.target))
        return;
      var a = actors.get(e);
      if (a == null ||
          a.op < 0.3)
        return;
      // lift along the camera's screen-up axis rather than world +Y: the pitch flattens as the rig
      // zooms in, which would foreshorten a world-Y offset and drop the bubble onto the head (same
      // reasoning as the badge row, see Badges.drawBadges)
      _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
      var lift = Sprites.SIZE * RenderConfig.BUBBLE_LIFT;
      headPoint(a, _ov);
      _ov.set(_ov.x + _up.x * lift, _ov.y + _up.y * lift, _ov.z + _up.z * lift);
      _ov.project(camera);
      // behind or off the sides: the AI already has a screen-edge indicator (markOffscreen), a
      // bubble pinned next to it would just fight it for space
      if (_ov.z > 1 ||
          _ov.x < -1 || _ov.x > 1 ||
          _ov.y < -1 || _ov.y > 1)
        return;
      // cult-speak (a lang-rendered bark) gets its own class: bold + full-size, not the shrunk default
      var kind = e.textFont != null ? e.textKind + ' cultspeak' : e.textKind;
      bubbles.show('ai:' + ai.id, e.textID, e.text, e.textFontFamily, kind,
        (_ov.x * 0.5 + 0.5) * js.Browser.document.body.clientWidth,
        (-_ov.y * 0.5 + 0.5) * js.Browser.document.body.clientHeight);
    }

// queue a screen-edge indicator for a seen AI whose head projects outside the viewport: the
// alert badge glyph (dot when calm) tinted by the same ramp as the 3D outlines
  function markOffscreen(ai:AI, bs:Array<_Badge>):Void
    {
      var a = actors.get(ai.entity);
      if (a == null ||
          a.op < 0.3)
        return;
      headPoint(a, _ov);
      _ov.project(camera);
      var behind = _ov.z > 1;
      if (!behind &&
          _ov.x >= -1 && _ov.x <= 1 &&
          _ov.y >= -1 && _ov.y <= 1)
        return;
      // behind-camera projections come out point-mirrored — flip back to the correct side
      var ndcX = behind ? -_ov.x : _ov.x;
      var ndcY = behind ? -_ov.y : _ov.y;
      // glyph: the current alert-ish badge if any (npc is two-tone, not tintable — skip it)
      var key = '';
      for (b in bs)
        if (b.svg != null &&
            b.svg != 'npc')
          {
            key = b.svg;
            break;
          }
      // edge icons breathe between 0.9 and 0.95 on the badge clock; calm dots sit at the middle
      var scale = (key == '' ? 0.925 : 0.9 + 0.05 * badges.pulse01(key));
      offscreen.show(key, '#' + StringTools.hex(badges.outlineColor(ai, bs), 6), ndcX, ndcY,
        scale);
    }

// street view teardown: drop the HUD-owned edge indicators + bubbles (nothing drives them anymore)
  public function dispose():Void
    {
      offscreen.clear();
      bubbles.clear();
      decals.dispose();
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
          headPoint(a, v);
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
  public function burst(tgtCol:Int, tgtRow:Int, awayX:Float, awayZ:Float, bloodRow:Int, bloodFirstCol:Int, drops:Int = 0):Void
    {
      BloodDrop3D.burst(particles, game, tgtCol, tgtRow, awayX, awayZ, bloodRow, bloodFirstCol, drops);
    }

// spawn one 3D gun-shot pellet (tracer + muzzle flash); blood + impact sound fire via the
// onImpact closure when the tracer lands (null for extra pellets so it fires once)
  public function shot(muzzle:Vector3, impact:Vector3, startDelay:Float,
      kind:RenderConfig.ShotKind, onImpact:Void->Void):Void
    {
      particles.add(new Shot3D(muzzle, impact, startDelay, kind, onImpact));
    }

// spawn one thrown 3D projectile (spit clot / needle) racing src->dst at chest height; the
// impact beat (splat burst + sound) fires via the onImpact closure on arrival
  public function projectile(src:Vector3, dst:Vector3, col:Int, row:Int, glow:Int,
      scale:Float, drips:Int, travelMs:Float, onImpact:Void->Void):Void
    {
      particles.add(new Projectile3D(src, dst, col, row, glow, scale, drips, travelMs, onImpact));
    }

// the standard hit shake on a struck entity (melee/shot/projectile impact, scream front)
  public function hitShake(e:Entity):Void
    {
      playFx(e, new render.anim.Shake(RenderConfig.MELEE.shakeMs,
        RenderConfig.MELEE.shakeAmp * CityConfig.CELL, 0));
    }

// spawn a silent-scream pulse dome at cell (x,y); returns the pulse so the street view can
// drive its screen-space shockwave ripple pass from the same wave front
  public function scream(x:Int, y:Int):render.particles.ScreamPulse3D
    {
      var w = CityConfig.cellToWorld(x, y);
      var s = new render.particles.ScreamPulse3D(actorGroup,
        w.x, render.world.WorldCtx.floorY(x, y) + 0.05, w.z, game, hitShake);
      particles.add(s);
      return s;
    }

// spawn a lingering gas cloud at cell (x,y): a cluster of lit alpha puff sprites that billows in
// then settles + fades. kind picks the tint (panic reddish / paralysis blue) + which 2D gas frame
// blends in
  public function gasCloud(x:Int, y:Int, kind:String, range:Int):Void
    {
      var G = RenderConfig.GAS;
      var w = CityConfig.cellToWorld(x, y);
      var color = (kind == 'paralysis' ? G.paralysisColor : G.panicColor);
      // pull the game's own 2D gas sprite from the entities atlas to blend into the cluster (kept at
      // its default smooth filtering). null until the atlas decodes -> that cast is baked-blob only
      var frame = (kind == 'paralysis' ? Const.FRAME_PARALYSIS_GAS : Const.FRAME_PANIC_GAS);
      var atlas = sprites.tex('entities', frame, Const.ROW_EFFECT, false);
      // tile passability probe: keeps puffs out of wall/building tiles (visible in tactical view,
      // where building meshes are hidden and only the floor grid shows the footprint)
      var area = game.area;
      var walkable = function(wx:Float, wz:Float):Bool
        {
          var c = CityConfig.worldToCell(wx, wz);
          return area.isWalkable(c.col, c.row);
        };
      particles.add(new render.particles.GasCloud3D(actorGroup,
        w.x, render.world.WorldCtx.floorY(x, y) + 0.05, w.z,
        color, range, G.lifeMult * RenderConfig.BASE_MS, atlas, walkable));
    }

// throw a fountain of money bills from cell (x,y): each bill picks a random walkable landing
// spot in the throw radius (a few tries, else at the thrower's feet) and flies there tumbling
  public function money(x:Int, y:Int, range:Int):Void
    {
      var M = RenderConfig.MONEY;
      var w = CityConfig.cellToWorld(x, y);
      var sy = render.world.WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4;
      for (_ in 0...M.bills)
        {
          // random landing cell in the radius, kept on walkable ground
          var lc = x, lr = y;
          for (_ in 0...4)
            {
              var ang = Math.random() * Math.PI * 2;
              var d = M.minDist + Math.random() * (range - M.minDist);
              var cx = Math.round(x + Math.cos(ang) * d);
              var cy = Math.round(y + Math.sin(ang) * d);
              if (game.area.isWalkable(cx, cy))
                {
                  lc = cx;
                  lr = cy;
                  break;
                }
            }
          // sub-cell scatter + a tiny per-bill height offset so resting bills don't z-fight
          var lw = CityConfig.cellToWorld(lc, lr);
          particles.add(new MoneyBill3D(w.x, sy, w.z,
            lw.x + (Math.random() - 0.5) * 0.8 * CityConfig.CELL,
            render.world.WorldCtx.floorY(lc, lr) + 0.02 + Math.random() * 0.02,
            lw.z + (Math.random() - 0.5) * 0.8 * CityConfig.CELL));
        }
    }

// lay the lingering money ground stains over the throw radius: one flat decal per walkable cell
// within range. ~MONEY.permFrac stay permanent (persisted tile-decorations in the shared dynamic-
// decal FIFO, like blood splats); the rest are view-side stains that fade out
  public function moneyGround(x:Int, y:Int, range:Int):Void
    {
      decals.throwMoney(x, y, range);
    }

// spawn a spark spray at a wall strike (x,y,z), embers flung back off the wall (backX,backZ) + up;
// startDelay defers it until the tracer arrives
  public function sparkBurst(x:Float, y:Float, z:Float, backX:Float, backZ:Float, startDelay:Float,
      ?color:Int):Void
    {
      particles.add(new SparkBurst3D(x, y, z, backX, backZ, startDelay, color));
    }

// spawn a glowing attack-FX sprite from (ax,ay,az) to (bx,by,bz): a melee swing arc keyed by the
// weapon's _AttackEffect, or an IMPACT mark stamped on a struck target
  public function attackFX(effect:String, ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float):Void
    {
      particles.add(new AttackFX3D(effect, ax, ay, az, bx, by, bz));
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
      _deathGhost = null;
      var a = actors.get(e);
      if (a == null)
        return;
      var tex = texFor(e);
      if (tex == null)
        return;
      // snapshot the feet-planted pose; the ghost topples from here and plays the item-drop
      // sound (positional at the actor's cell) when it lands flat
      var col = a.col;
      var row = a.row;
      var ghost = new DeathFade3D(tex,
        a.x, WorldCtx.floorY(a.col, a.row), a.z,
        1.0, a.op,
        function()
          game.scene.sounds.play('item-drop',
            {
              x: col,
              y: row,
            }));
      particles.add(ghost);
      _deathGhost = ghost; // so the corpse body can bind its fade-in to this ghost's landing
    }

// keep a freshly-spawned corpse body invisible until the last death ghost lands, so it only
// appears once the dying sprite has fallen flat (not during the spin); the object loop skips a
// held body, so when released it seeds at op 0 and eases in. no ghost (view off) = reveal now
  public function bindBodyFadeIn(e:Entity, id:Int, ground:Bool):Void
    {
      if (_deathGhost == null)
        return;
      _heldBodies.set(e, true);
      _deathGhost.onLandExtra = function() _heldBodies.remove(e);
      // land the topple at the corpse's own resting pose (one full turn, then settle facing the
      // body's yaw + offset) so it doesn't always fall to the front. upright bodies (choir) keep
      // the default front-facing topple
      if (ground)
        {
          var p = bodyPose(id);
          _deathGhost.targetSpin = Math.PI * 2 + p.yaw;
          _deathGhost.offx = p.ox;
          _deathGhost.offz = p.oz;
        }
    }

// seed a new entity's actor at zero opacity so it fades in (the body appearing on death)
  public function seedFadeIn(e:Entity):Void
    {
      if (actors.get(e) != null)
        return;
      var w = CityConfig.cellToWorld(e.mx, e.my);
      actors.set(e, { col: e.mx, row: e.my, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1,
                      op: 0.0, opTarget: 1.0, fx: null, face: 1.0 });
    }

// stable pseudo-random in [-1,1) from an int key+salt (so a corpse keeps its fallen pose
// across save/load without persisting the jitter)
  static function jitter(id:Int, salt:Int):Float
    {
      var h = id * 374761393 + salt * 668265263;
      h = (h ^ (h >> 13)) * 1274126177;
      h = h ^ (h >> 16);
      return (h & 0xffff) / 32768.0 - 1.0;
    }

// deterministic resting pose (full-360 yaw + small offset) for a corpse body from its id — the
// single source shared by the object-loop decal and the death-topple landing, so the fall ends
// where the body lies
  function bodyPose(id:Int): { yaw:Float, ox:Float, oz:Float }
    {
      return {
        yaw: jitter(id, 1) * Math.PI,                     // full 360 deg
        ox: jitter(id, 2) * 0.12 * CityConfig.CELL,
        oz: jitter(id, 3) * 0.12 * CityConfig.CELL,
      };
    }

// advance one actor's anim state and paint its billboard (no-op if fully faded with no effect
// running). baseY/baseScale set the resting pose (nonzero for the attached parasite riding a
// host's head). flat lays the sprite on the ground as a decal instead of standing it up
  function drawActor(e:Entity, vis:Bool, dtMs:Float, baseY:Float = 0.0, baseScale:Float = 1.0, flat:Bool = false, yaw:Float = 0.0, offx:Float = 0.0, offz:Float = 0.0, groundAnchor:Bool = false):Void
    {
      var a = actor(e, vis, dtMs);
      if (a.op <= 0.001 &&
          a.fx == null)
        return;
      // rest on the cell's ground surface (walkway tops sit a curb above the road)
      var floor = WorldCtx.floorY(a.col, a.row);
      // decals hug the ground; upright sprites centre at half their height
      var wy = flat ? floor + 0.05 : floor + Sprites.SIZE * 0.5 + baseY;
      // a flat corpse records its landing slot (the count of ground decals in its cell when it first
      // appeared) into _corpseCells, so blood sprayed here afterwards paints over it (Blood.draw). the
      // body renders at ORD_CORPSE, above the blood already present when it fell
      if (flat)
        {
          var slot = _bodyStackSlot.get(e);
          if (slot == null)
            {
              var tl = game.area.tiles[a.col] != null ? game.area.tiles[a.col][a.row] : null;
              slot = (tl != null && tl.decoration != null) ? tl.decoration.length : 0;
              _bodyStackSlot.set(e, slot);
            }
          _corpseCells.set(a.col * game.area.height + a.row, slot);
        }
      // upright ground item (e.g. a generic pickup box): actor art fills the frame feet-at-bottom,
      // but a small item icon sits mid-cell and would hang in the air — drop it by the sprite's
      // empty bottom margin so its opaque content rests on the floor
      if (groundAnchor &&
          !flat)
        {
          var gs = sprites.texContent(e.imageName, e.ix, e.iy, e.isMaleAtlas);
          if (gs != null)
            wy -= Sprites.SIZE * gs.by;
        }
      // flat objects sit in the ground-decal layer; upright icons ride above their own shadow + the
      // target ring. an upright actor within a barrel's light gets a warm flicker glow on its sprite
      var order = flat ? Sprites.ORD_CORPSE : Sprites.ORD_ACTOR;
      var emInt = flat ? 0.0 : flames.litAt(a);
      // side-view actors (dogs) mirror toward their facing; a.face eases the turn (see actor())
      if (a.fx != null)
        sprites.paint({
          x: a.x + a.fx.offx + offx,
          y: wy + a.fx.offy,
          z: a.z + a.fx.offz + offz,
          tex: texFor(e),
          op: a.op,
          scale: baseScale * a.fx.scale,
          flat: flat,
          order: order,
          emissive: RenderConfig.FLAME.litColor,
          emissiveInt: emInt,
          faceX: a.face,
          yaw: yaw,
        });
      else
        sprites.paint({
          x: a.x + offx,
          y: wy,
          z: a.z + offz,
          tex: texFor(e),
          op: a.op,
          scale: baseScale,
          flat: flat,
          order: order,
          emissive: RenderConfig.FLAME.litColor,
          emissiveInt: emInt,
          faceX: a.face,
          yaw: yaw,
        });
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
      // facing target: side-view actors (dogs) mirror toward their move/attack direction; others +1
      var aie = Std.downcast(e, entities.AIEntity);
      var tf = (aie != null && aie.ai != null && aie.ai.flipsOnMove() && aie.ai.faceRight) ? -1.0 : 1.0;
      if (a == null)
        {
          var w = CityConfig.cellToWorld(e.mx, e.my);
          a = { col: e.mx, row: e.my, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1,
                op: vis ? 1.0 : 0.0, opTarget: vis ? 1.0 : 0.0, fx: null, face: tf };
          actors.set(e, a);
          return a;
        }
      // position channel. a one-step diagonal move sharing a corner with a building (or a lamp
      // post) clips it; route it through the open shoulder as an L-path (double orthogonal move)
      var bend = ActorAnim.cornerBend(game.area, a.col, a.row, e.mx, e.my, lampCorners);
      ActorAnim.slideTo(a, e.mx, e.my, step,
        bend != null ? bend.col : -1,
        bend != null ? bend.row : -1,
        e.slideNoSnap);
      e.slideNoSnap = false; // consume the push-past hint (one slide only)
      // opacity channel: ease toward the visibility target (LOS fade, slower than moves)
      a.opTarget = vis ? 1.0 : 0.0;
      var opStep = step * FADE_SPEED;
      if (a.op < a.opTarget) a.op = Math.min(a.opTarget, a.op + opStep);
      else if (a.op > a.opTarget) a.op = Math.max(a.opTarget, a.op - opStep);
      // facing channel: ease the mirror toward the target, linear through 0 (a horizontal turn)
      var fStep = step * TURN_SPEED;
      a.face += Math.max(-fStep, Math.min(fStep, tf - a.face));
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

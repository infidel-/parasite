package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import render.ActorAnim;
import render.anim.Effect;
import render.anim.JumpOnFace;
import render.anim.LeaveHost;
import game.Game;
import entities.Entity;

// the 3D actor billboard layer: mirrors the game's objects/AI/player as pooled billboard
// meshes, each with a position slide + opacity fade + optional transient effect. owns the
// mesh pool + atlas texture cache + per-actor anim state. StreetView builds one per city
// and drives it each frame via update(); game logic triggers effects via playFx().
class Actors {
  var game:Game;
  var actorGroup:Group;                                   // scene group holding all billboards
  var camera:PerspectiveCamera;                           // read live for billboard yaw

  var pool:Array<Mesh> = [];                              // reused billboard meshes
  var texCache:Map<String, CanvasTexture> = new Map();    // atlas-crop -> texture
  // per-actor anim state, keyed by entity identity. ponytail: dead entities linger here
  // until the area rebuild drops this whole object — bounded per area, not worth pruning
  var actors:haxe.ds.ObjectMap<Entity, Actor> = new haxe.ds.ObjectMap();

  var lastState:_PlayerState;                            // prev-frame player state (attach transition)

  static inline var BILLBOARD = CityConfig.CELL * 0.85; // actor sprite world size
  static inline var FADE_SPEED = 0.5;                  // LOS opacity fade runs at this * base speed (slower)
  static inline var TILT = 0.6;                        // radians the billboard leans back toward the overhead camera (0 = upright)
  static inline var ATTACH_HEAD_Y = BILLBOARD * 0.1;  // attached parasite rides this far above the host's ground center (its head)
  static inline var ATTACH_SCALE = 1.0;                // attached parasite is drawn this much smaller (sits on the head)

  public function new(game:Game, actorGroup:Group, camera:PerspectiveCamera)
    {
      this.game = game;
      this.actorGroup = actorGroup;
      this.camera = camera;
      lastState = game.player.state;
    }

// attach a transient effect to an actor's billboard (build it from render.anim.*, e.g.
// new Shake(BASE_MS, amp) on damage, new Lunge(...) on melee); no-op if the actor has no
// live billboard state yet
  public function playFx(e:Entity, fx:Effect):Void
    {
      var a = actors.get(e);
      if (a == null) return;
      a.fx = fx;
    }

// rebuild all actor billboards from live game state; actors slide + fade, effects layer
// on top. objects/AI gated on player fog/LOS to match the 2D view
  public function update(dtMs:Float):Void
    {
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

      var n = 0;
      // objects (sewer hatches etc.): static, but still fade. parasite keeps seeing
      // sensable objects outside LOS
      for (o in game.area.getObjects())
        if (o.entity != null)
          {
            var vis =
              !game.player.vars.losEnabled ||
              game.playerArea.sees(o.x, o.y) ||
              (game.player.state != _PlayerState.PLR_STATE_HOST && o.sensable());
            n = drawActor(n, o.entity, vis, dtMs);
          }
      // AI: gated on player fog/LOS so the 3D view can't reveal enemies 2D hides
      for (ai in game.area.getAllAI())
        if (ai.entity != null)
          {
            var vis =
              !game.player.vars.losEnabled ||
              game.playerArea.sees(ai.x, ai.y);
            n = drawActor(n, ai.entity, vis, dtMs);
          }
      // player billboard: free parasite draws its own sprite; while attached it rides on
      // the host's head (the host itself is still drawn by the AI loop above); once in a
      // host the parasite is hidden inside it and only the ring marks the player
      if (st == _PlayerState.PLR_STATE_PARASITE)
        n = drawActor(n, game.playerArea.entity, true, dtMs);
      else if (st == _PlayerState.PLR_STATE_ATTACHED)
        n = drawActor(n, game.playerArea.entity, true, dtMs, ATTACH_HEAD_Y, ATTACH_SCALE);
      // hide leftover pooled meshes
      for (i in n...pool.length)
        if (pool[i] != null) pool[i].visible = false;
    }

// advance one actor's anim state and place its billboard; returns the next pool index
// (unchanged if the actor is fully faded out with no effect running). baseY/baseScale set
// the resting pose (nonzero for the attached parasite riding a host's head)
  function drawActor(n:Int, e:Entity, vis:Bool, dtMs:Float, baseY:Float = 0.0, baseScale:Float = 1.0):Int
    {
      var a = actor(e, vis, dtMs);
      if (a.op <= 0.001 &&
          a.fx == null)
        return n;
      var wy = BILLBOARD * 0.5 + baseY;
      if (a.fx != null)
        return billboard(n, a.x + a.fx.offx, wy + a.fx.offy, a.z + a.fx.offz, texFor(e), a.op, baseScale * a.fx.scale);
      return billboard(n, a.x, wy, a.z, texFor(e), a.op, baseScale);
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
      a.fx = new JumpOnFace(game, RenderConfig.BASE_MS, startX - w.x, -ATTACH_HEAD_Y, startZ - w.z, BILLBOARD * 0.5);
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
      a.fx = new LeaveHost(game, RenderConfig.BASE_MS, px, ATTACH_HEAD_Y, pz, BILLBOARD * 0.5);
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
      // position channel
      ActorAnim.slideTo(a, e.mx, e.my, step);
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

// crop one atlas cell (imageName, ix, iy) into a cached texture; null until decoded
  function texFor(e:Entity):CanvasTexture
    {
      var key = e.imageName + ':' + e.ix + ':' + e.iy + ':' + e.isMaleAtlas;
      if (texCache.exists(key)) return texCache.get(key);
      var img:Dynamic = game.scene.images.getImage(e.imageName, e.isMaleAtlas);
      // retry next frame if the atlas image isn't decoded yet
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return null;
      var t = Const.TILE_SIZE_CLEAN;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = t; cv.height = t;
      // mirror Entity.drawImage crop (the +1/-1 kludge avoids atlas bleed)
      cv.getContext('2d').drawImage(img, e.ix * t, e.iy * t + 1, t, t - 1, 0, 0, t, t);
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      texCache.set(key, tex);
      return tex;
    }

// place/reuse a billboard mesh at world (wx,wy,wz) with texture tex, opacity op, uniform
// scale; returns the next pool index (unchanged if the atlas isn't ready yet)
  function billboard(idx:Int, wx:Float, wy:Float, wz:Float, tex:CanvasTexture, op:Float, scale:Float):Int
    {
      if (tex == null) return idx;
      var m = pool[idx];
      if (m == null)
        {
          m = new Mesh(new PlaneGeometry(BILLBOARD, BILLBOARD),
            new MeshBasicMaterial({
              transparent: true,
              depthWrite: false,
              side: THREE.DoubleSide,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      mat.map = tex;
      mat.opacity = op;
      mat.needsUpdate = true;
      m.position.set(wx, wy, wz);
      m.scale.set(scale, scale, scale);
      // yaw to face the camera, then lean the top back toward the overhead camera (world-X
      // tilt applied first in XYZ order = a uniform lean) so the sprite reads flatter to it.
      // rotation.set resets x/z each frame so the lean never accumulates
      m.rotation.set(-TILT, Math.atan2(camera.position.x - wx, camera.position.z - wz), 0);
      m.visible = true;
      return idx + 1;
    }
}

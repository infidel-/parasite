package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import render.ActorAnim;
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

  // scratch written by applyAnim (single-threaded, one actor at a time — no alloc)
  var fxOffX:Float = 0;
  var fxOffY:Float = 0;
  var fxOffZ:Float = 0;
  var fxScale:Float = 1.0;

  static inline var BILLBOARD = CityConfig.CELL * 0.85; // actor sprite world size
  static inline var FADE_SPEED = 0.5;                  // LOS opacity fade runs at this * base speed (slower)

  public function new(game:Game, actorGroup:Group, camera:PerspectiveCamera)
    {
      this.game = game;
      this.actorGroup = actorGroup;
      this.camera = camera;
    }

// trigger a transient effect on an actor's billboard. called by game logic when the
// triggering feature fires (JUMP_ON_FACE on infect, SHAKE on damage, ATTACK_LUNGE on
// melee); no-op if the actor has no live billboard state yet
  public function playFx(e:Entity, kind:AnimKind, ms:Float, px:Float, py:Float, pz:Float):Void
    {
      var a = actors.get(e);
      if (a == null) return;
      a.fx = { kind: kind, t: 0, ms: ms, px: px, py: py, pz: pz };
    }

// rebuild all actor billboards from live game state; actors slide + fade, effects layer
// on top. objects/AI gated on player fog/LOS to match the 2D view
  public function update(dtMs:Float):Void
    {
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
      // player (only drawn as parasite; in a host the host AI carries the sprite)
      if (game.player.state == _PlayerState.PLR_STATE_PARASITE)
        n = drawActor(n, game.playerArea.entity, true, dtMs);
      // hide leftover pooled meshes
      for (i in n...pool.length)
        if (pool[i] != null) pool[i].visible = false;
    }

// advance one actor's anim state and place its billboard; returns the next pool index
// (unchanged if the actor is fully faded out with no effect running)
  function drawActor(n:Int, e:Entity, vis:Bool, dtMs:Float):Int
    {
      var a = actor(e, vis, dtMs);
      if (a.op <= 0.001 &&
          a.fx == null)
        return n;
      var wy = BILLBOARD * 0.5;
      if (a.fx != null)
        {
          applyAnim(a.fx);
          return billboard(n, a.x + fxOffX, wy + fxOffY, a.z + fxOffZ, texFor(e), a.op, fxScale);
        }
      return billboard(n, a.x, wy, a.z, texFor(e), a.op, 1.0);
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
      // transient effect: advance over its own duration, clear when done
      if (a.fx != null)
        {
          a.fx.t += dtMs * RenderConfig.ANIM_SPEED / a.fx.ms;
          if (a.fx.t >= 1) a.fx = null;
        }
      return a;
    }

// write the current-frame offset/scale of a transient effect into the fx* scratch, from
// its progress k (0..1). add a kind = add a case (see ActorAnim.AnimKind)
  function applyAnim(fx:Anim):Void
    {
      var k = fx.t;
      fxOffX = 0; fxOffY = 0; fxOffZ = 0; fxScale = 1.0;
      switch (fx.kind)
        {
          case POP:
            // scale small -> overshoot -> 1 (settles at 1 when k=1)
            fxScale = 0.4 + 0.6 * (k * k * (3 - 2 * k)) + 0.15 * Math.sin(Math.PI * k);
          case JUMP_ON_FACE:
            // horizontal lerp to the (px,pz) delta + parabolic arc up (py = peak height)
            fxOffX = fx.px * k;
            fxOffZ = fx.pz * k;
            fxOffY = 4 * fx.py * k * (1 - k);
          case SHAKE:
            // decaying positional jitter, amplitude py (zero at k=1)
            var d = (1 - k) * fx.py;
            fxOffX = d * Math.sin(k * 40);
            fxOffZ = d * Math.cos(k * 37);
          case ATTACK_LUNGE:
            // there-and-back toward (px,pz): zero at k=0 and k=1, peak mid
            var m = Math.sin(Math.PI * k);
            fxOffX = fx.px * m;
            fxOffZ = fx.pz * m;
        }
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
      // Y-billboard: stand upright, yaw to face the camera
      m.rotation.y = Math.atan2(camera.position.x - wx, camera.position.z - wz);
      m.visible = true;
      return idx + 1;
    }
}

package render.actors;

import three.Three;
import render.RenderConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.particles.Sprites;
import render.anim.Pop;
import game.Game;
import entities.Entity;
import ai.AI;
import objects.AreaObject;

// per-AI badge anim: last badge-set signature (change detection) + the active change-pop (null idle)
typedef BadgeAnim = { sig:String, pop:render.anim.Effect };

// the AI-marker pass of the actor layer: status badges (alert/npc/cultist/effect) above the head,
// the through-wall x-ray outline, and the targeting frame/reticle under a targeted entity. all UI
// overlays on top of the billboards. reads actor poses from the shared Actors map (read-only) and
// owns only the per-AI badge change-pop state + the looping badge-pulse clock
class Badges {
  static inline var TARGET_SCALE = 1.15;               // targeting frame/reticle ground-quad scale (~one cell)

  var game:Game;
  var camera:PerspectiveCamera;                          // read live for the screen-space badge anchor
  var sprites:Sprites;                                   // lit paint surface (shared)
  var actors:haxe.ds.ObjectMap<Entity, Actor>;           // shared actor-pose map (read-only here)
  var badgeT:Float = 0.0;                               // badge anim clock (turn units, anim-speed scaled) — looping pulses
  // per-AI badge change-pop state (last signature + active pop). ponytail: dead AI linger like the
  // actors map, dropped whole on area rebuild
  var badgeAnims:haxe.ds.ObjectMap<Entity, BadgeAnim> = new haxe.ds.ObjectMap();

  public function new(game:Game, camera:PerspectiveCamera, sprites:Sprites,
      actors:haxe.ds.ObjectMap<Entity, Actor>)
    {
      this.game = game;
      this.camera = camera;
      this.sprites = sprites;
      this.actors = actors;
    }

// advance the looping badge-pulse clock once per frame (turn-unit, anim-speed scaled)
  public function tick(dtMs:Float):Void
    {
      badgeT += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// paint the targeting markers under a visible AI: the stored-target frame and/or the
// currently-cycled reticle (mirrors the 2D FRAME/RETICLE sprites, laid flat on the ground)
  public function drawAITarget(ai:AI):Void
    {
      var tg = game.ui.hud.targeting;
      paintTargetMarker(ai.entity,
        tg.isTargetedAI(ai),
        game.ui.hud.state == HUD_TARGETING && tg.isTargetingAI(ai));
    }

// same for a visible attackable object
  public function drawObjTarget(obj:AreaObject):Void
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
  public function drawXray(ai:AI, badges:Array<_Badge>):Void
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
  public function drawBadges(ai:AI, badges:Array<_Badge>, dtMs:Float):Void
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
      // question badge phase (period ~8.0 turn): slower/subtler breath on the "?" — rising suspicion, not yet a threat
      var think = Math.sin(badgeT / 8.0 * 2 * Math.PI);
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
          // question: slower, subtler breath on the "?" — amplitude grows with suspicion (alert1<2<3),
          // staying under the fully-alerted "!" (0.10)
          else if (b.svg == 'alert1')
            sc *= 1 + 0.04 * think;
          else if (b.svg == 'alert2')
            sc *= 1 + 0.06 * think;
          else if (b.svg == 'alert3')
            sc *= 1 + 0.08 * think;
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
}

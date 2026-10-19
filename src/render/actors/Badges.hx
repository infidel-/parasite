package render.actors;

import three.Three;
import citygen.CityConfig;
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
  static inline var PADLOCK_SCALE = 0.4;               // locked-door padlock quad scale (of Sprites.SIZE)
  // broken base organ: a red X, round-capped, over the whole square
  static inline var BROKEN_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" ' +
    'viewBox="0 0 128 128"><path d="M16 16 L112 112 M112 16 L16 112" stroke="#d21414" ' +
    'stroke-opacity="0.9" stroke-width="10" stroke-linecap="round" fill="none"/></svg>';

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

// normalized looping pulse phase (0..1) for a badge glyph key, on the same clock/periods as the
// drawBadges breaths; used by the HUD edge indicators so they breathe in sync with the badges
  public function pulse01(key:String):Float
    {
      var period =
        (key == 'alert1' ||
         key == 'alert2' ||
         key == 'alert3') ? 8.0 :
        (key == 'search') ? 5.6 : 6.4;
      return 0.5 + 0.5 * Math.sin(badgeT / period * 2 * Math.PI);
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

// object readouts nothing else in 3D carries: a padlock on a locked door, and a damaged base
// organ's health bar (with a red X once it breaks). re-read every frame, like the AI badges
  public function drawObjBadges(o:AreaObject):Void
    {
      if (o.type == 'door')
        {
          var d:objects.Door = cast o;
          if (d.isLocked &&
              !d.isOpen)
            drawPadlock(o);
        }
      else if (o.type == 'base_organ')
        drawOrganHealth(cast o);
    }

// the padlock badge glyph (UISvg.badgePadlock) at the doorway's mid-height, self-lit and always on top.
// ponytail: a linked lab pair would wear two; only a single corp door is ever locked
// (scenario.AlienMissionCommon), add a midpoint if the lab ever locks one
  function drawPadlock(o:AreaObject):Void
    {
      var a = actors.get(o.entity);
      if (a == null ||
          a.op < 0.05)
        return;
      var tex = badgeSvgTex('padlock', null);
      if (tex == null)
        return;
      sprites.paint({
        x: a.x + a.offx,
        y: WorldCtx.floorY(a.col, a.row) + render.facility.FacilityStyle.DOOR_H * 0.5,
        z: a.z + a.offz,
        tex: tex,
        op: a.op,
        scale: PADLOCK_SCALE,
        order: Sprites.ORD_ACTOR,
        emissive: 0xffffff,
        emissiveInt: 1.0,
        depthTest: false,
        shadow: false,
      });
    }

// a damaged organ's health bar spanning its footprint, lifted screen-up above the sprite tops like
// the AI badge row, and a red X across the footprint once it breaks. drawn off the organ's first
// part only; the bar texture is bucketed to 5% so at most 21 are ever cached
  function drawOrganHealth(obj:objects.base.BaseOrganObject):Void
    {
      if (obj.basePartIndex != 0)
        return;
      var organ = obj.getOrgan();
      if (organ == null ||
          (organ.health >= organ.maxHealth() &&
           !organ.broken))
        return;
      var a = actors.get(obj.entity);
      if (a == null ||
          a.op < 0.05)
        return;
      var minX = organ.x;
      var maxX = organ.x;
      var minY = organ.y;
      var maxY = organ.y;
      for (pt in organ.footprint())
        {
          minX = Std.int(Math.min(minX, pt.x));
          maxX = Std.int(Math.max(maxX, pt.x));
          minY = Std.int(Math.min(minY, pt.y));
          maxY = Std.int(Math.max(maxY, pt.y));
        }
      var w = CityConfig.cellToWorld((minX + maxX) / 2, (minY + maxY) / 2);
      var mid = WorldCtx.floorY(organ.x, organ.y) + Sprites.SIZE * 0.5;
      var scale = (maxX - minX + 1) * CityConfig.CELL * 0.8 / Sprites.SIZE;
      var ratio = (organ.maxHealth() > 0 ? organ.health / organ.maxHealth() : 0.0);
      var bucket = Std.int(Math.max(0, Math.min(20, Math.round(ratio * 20))));
      var bar = sprites.svgTex('svg:organbar:' + bucket, organBarSvg(bucket / 20), 128);
      var up = new Vector3(0, 1, 0).applyQuaternion(camera.quaternion);
      var lift = Sprites.SIZE * RenderConfig.BADGE_LIFT;
      if (bar != null)
        sprites.paint({
          x: w.x + up.x * lift,
          y: mid + up.y * lift,
          z: w.z + up.z * lift,
          tex: bar,
          op: a.op,
          scale: scale,
          order: Sprites.ORD_ACTOR,
          emissive: 0xffffff,
          emissiveInt: 1.0,
          depthTest: false,
          shadow: false,
        });
      if (!organ.broken)
        return;
      var cross = sprites.svgTex('svg:organbroken', BROKEN_SVG, 128);
      if (cross != null)
        sprites.paint({
          x: w.x,
          y: mid,
          z: w.z,
          tex: cross,
          op: a.op,
          scale: scale,
          order: Sprites.ORD_ACTOR,
          emissive: 0xffffff,
          emissiveInt: 1.0,
          depthTest: false,
          shadow: false,
        });
    }

// a thin health strip inside a transparent square: dark backing, light border, green fill to ratio
  static function organBarSvg(ratio:Float):String
    {
      return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">' +
        '<rect x="2" y="57" width="124" height="14" fill="#000" fill-opacity="0.75" ' +
        'stroke="#dcdcdc" stroke-opacity="0.9" stroke-width="2"/>' +
        '<rect x="4" y="59" width="' + Std.int(120 * ratio) + '" height="10" fill="#28d246"/></svg>';
    }

// the forma cursor: the targeting reticle laid flat on the base-building cursor's cell, self-lit
// and always on top so a grown organ or a wall never hides it
  public function drawFormaCursor():Void
    {
      if (game.ui.hud.state != HUD_BASE_BUILDING ||
          game.cults.length == 0 ||
          game.cults[0].base == null ||
          game.cults[0].base.areaID != game.area.id)
        return;
      var tex = sprites.tex('entities', Const.FRAME_TARGET_RETICLE, Const.ROW_REGION_ICON, false);
      if (tex == null)
        return;
      var base = game.cults[0].base;
      var w = CityConfig.cellToWorld(base.cursorX, base.cursorY);
      sprites.paint({
        x: w.x,
        y: WorldCtx.floorY(base.cursorX, base.cursorY) + 0.06,
        z: w.z,
        tex: tex,
        op: 1.0,
        scale: TARGET_SCALE,
        flat: true,
        order: Sprites.ORD_MARK,
        emissive: 0xffffff,
        emissiveInt: 1.0,
        depthTest: false,
        shadow: false,
      });
    }

// lay the target frame (framed) and/or targeting reticle (cursor) as flat ground quads under
// an entity's slide pos; reticle a hair higher so it wins the ground z-order over the frame.
// shadow off on both: they are UI, and a target standing in a building's shadow would otherwise
// have its own marker halved in brightness exactly when it matters most
  function paintTargetMarker(e:Entity, framed:Bool, cursor:Bool):Void
    {
      if (!framed && !cursor)
        return;
      var a = actors.get(e);
      if (a == null)
        return;
      var floor = WorldCtx.floorY(a.col, a.row);
      if (framed)
        sprites.paint({
          x: a.x,
          y: floor + 0.05,
          z: a.z,
          tex: sprites.tex('entities', Const.FRAME_TARGET_FRAME, Const.ROW_REGION_ICON, false),
          op: 1.0,
          scale: TARGET_SCALE,
          flat: true,
          order: Sprites.ORD_MARK,
          shadow: false,
        });
      if (cursor)
        sprites.paint({
          x: a.x,
          y: floor + 0.06,
          z: a.z,
          tex: sprites.tex('entities', Const.FRAME_TARGET_RETICLE, Const.ROW_REGION_ICON, false),
          op: 1.0,
          scale: TARGET_SCALE,
          flat: true,
          order: Sprites.ORD_MARK,
          shadow: false,
        });
    }

// through-wall x-ray outline: a colored, patterned silhouette of the AI's own sprite, drawn ONLY
// where the AI is occluded from the camera. depthTest stays on but depthFunc = GreaterDepth, so a
// fragment passes only where the depth buffer holds something NEARER (a wall in front) — meaning a
// clear-view AI draws nothing, while one hidden behind a wall (but still in the player's LOS) glows
// through so it stays spottable. color = current alert status (followers cult-pink)
  public function drawXray(ai:AI, badges:Array<_Badge>):Void
    {
      // never x-ray the player's own host here: drawPlayerXray owns it
      if (game.player.host == ai)
        return;
      xray(ai.entity, outlineColor(ai, badges));
    }

// the player's own x-ray, in its ring's purple: the free parasite or its host. not in the city,
// which fades the buildings in front of the player instead (render.Occlusion); nothing fades an
// underground or compound wall, so a player stood under the south wall of a corridor was gone
  public function drawPlayerXray():Void
    {
      if (game.scene.view3d.fadesOccluders())
        return;
      xray(game.player.state == _PlayerState.PLR_STATE_HOST ? game.player.host.entity : game.playerArea.entity,
        RenderConfig.XRAY.player);
    }

// paint one entity's patterned silhouette in `col` where a wall hides it from the camera
  function xray(e:Entity, col:Int):Void
    {
      var a = actors.get(e);
      if (a == null ||
          a.op < 0.05)
        return;
      var tex = sprites.silTex(e.imageName, e.ix, e.iy, e.isMaleAtlas,
        RenderConfig.XRAY.fill, RenderConfig.XRAY.hatchSpacing, RenderConfig.XRAY.hatchThick, e.skinColor);
      if (tex == null)
        return;
      var wy = WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5;
      // emissive = the state color so the pattern reads at night; GreaterDepth = occluded-only
      sprites.paint({
        x: a.x,
        y: wy,
        z: a.z,
        tex: tex,
        op: a.op,
        scale: RenderConfig.XRAY.grow,
        order: Sprites.ORD_ACTOR,
        emissive: col,
        emissiveInt: RenderConfig.XRAY.emissive,
        depthFunc: THREE.GreaterDepth,
        shadow: false, // occluded-only UI outline: must glow through at full strength
      });
    }

// outline color for an AI: followers read cult-pink; otherwise the current alert status (matching
// the alert badge color), or a dim slate when calm/idle. colors mirror the app.css HUD tokens
  public function outlineColor(ai:AI, badges:Array<_Badge>):Int
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
// just above its head. every badge with an svg key renders from scalable SVG (UISvg.badge, tinted by
// badgeColor), the rest from the PNG atlas. mirrors the 2D AIEntity.draw badge stack. see
// ai.AI.getBadges
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
            ? badgeSvgTex(b.svg, b.count)
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
          // breaking: the "!" breath plus a glow swell, like the HUD's pulsing cracked heart
          else if (b.svg == 'breaking')
            {
              sc *= 1 + 0.10 * breath;
              em = 0.8 + 0.5 * (0.5 + 0.5 * breath);
            }
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
          sprites.paint({
            x: bx + right.x * off + pvx,
            y: by + right.y * off + pvy,
            z: bz + right.z * off + pvz,
            tex: tex,
            op: a.op,
            scale: sc,
            yaw: roll,
            order: Sprites.ORD_ACTOR,
            emissive: 0xffffff,
            emissiveInt: em,
            depthTest: false,
            shadow: false,
          });
        }
    }

// signature of a badge set (glyph keys / atlas cells) to detect changes for the status-change pop
  inline function badgeSig(badges:Array<_Badge>):String
    {
      var s = '';
      for (b in badges)
        s += (b.svg != null ? b.svg : b.col + '_' + b.row) +
          (b.count != null ? ':' + b.count : '') + ',';
      return s;
    }

// rasterize a badge glyph (UISvg.badge) recolored to its state color, cached at a fixed px edge.
// inject xmlns (a standalone data: <img> is parsed as bare XML — the UISvg glyphs omit it since
// inline DOM infers it) + explicit width/height (a viewBox-only SVG can decode to naturalWidth 0)
  inline function badgeSvgTex(key:String, count:Null<Int>):CanvasTexture
    {
      // multieffect bakes the live count into its triangle → its own markup + per-count cache key;
      // every other glyph resolves through the shared UISvg.badge() dispatch
      var markup = (key == 'multieffect')
        ? ui.UISvg.effectMultiple(count)
        : ui.UISvg.badge(key);
      var cacheKey = (key == 'multieffect') ? 'multieffect:' + count : key;
      var svg = StringTools.replace(markup, 'currentColor', badgeColor(key));
      svg = StringTools.replace(svg, '<svg ', '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" ');
      return sprites.svgTex('svg:' + cacheKey, svg, 128);
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
      // effect glyphs — thematic tints so the effect reads at a glance
      if (key == 'paralysis') return '#e0d24a';   // yellow — lightning jolt
      if (key == 'panic') return '#ec894e';       // orange — fear
      if (key == 'slime') return '#6fca6f';       // green — slime / slow
      if (key == 'bleeding') return '#f26a6a';    // red — blood
      if (key == 'blacknoise') return '#a45fe0';  // parasite purple — black noise
      if (key == 'breaking') return '#f26a6a';    // danger-red — host close to collapsing (--text-color-alert)
      // cult pink — the player's own cult. pushed past --text-color-cultist (#fd97ff): lit + full glow +
      // tone mapping washed that to (252,183,240) on screen, this lands on the info hud's (254,154,250)
      if (key == 'cultist') return '#ff58ff';
      if (key == 'cultistx') return '#c0c0c0';    // neutral gray — an enemy cult
      if (key == 'padlock') return '#e0b34a';     // amber — locked door (--text-color-time)
      if (key == 'multieffect') return '#eaebed'; // white — generic multiple
      return '#eaebed';
    }
}

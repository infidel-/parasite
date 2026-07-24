package render.actors;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.particles.*;
import render.particles.FlameLights.FlameBarrel;
import game.Game;
import entities.Entity;

// the burning-barrel + fake-shadow pass of the actor layer: gathers this frame's visible barrels
// once, throws a warm flicker glow onto nearby actors, draws the flame body/embers + the pooled
// warm lights, and lays fake cast shadows from BOTH barrels and street lamps. reads actor poses
// from the shared Actors map (read-only) but never mutates it. only low-tier cities spawn barrels,
// so the flame-light pool is built only there; the shadow pass runs everywhere (lamps always cast)
class FlameShadows {
  var game:Game;
  var sprites:Sprites;                                   // lit paint surface (shadows)
  var sparks:Sparks;                                     // camera-facing soft-ember pool (flame body)
  var particles:Particles3D;                             // transient FX (flame embers)
  var actors:haxe.ds.ObjectMap<Entity, Actor>;           // shared actor-pose map (read-only here)
  var flameLights:FlameLights = null;                   // pooled warm barrel lights (low-tier only; null elsewhere)
  var flameT:Float = 0.0;                               // shared flame clock (ms, raw dt) — flicker/embers/shadows sync to it
  var flameTex:Texture = null;                          // barrel flame sprite (lazy-loaded once)
  var curBarrels:Array<FlameBarrel> = [];               // this frame's visible barrels (gathered once, reused by lit/body/shadow)
  var lampSrc:Array<LampPost> = null;                   // lamps lit this frame (from the pool) — cast fake shadows too

  public function new(game:Game, actorGroup:Group, sprites:Sprites, sparks:Sparks,
      particles:Particles3D, actors:haxe.ds.ObjectMap<Entity, Actor>)
    {
      this.game = game;
      this.sprites = sprites;
      this.sparks = sparks;
      this.particles = particles;
      this.actors = actors;
      // burning-barrel flame lights: only low-tier cities spawn barrels, so only there do we add to
      // NUM_POINT_LIGHTS (built here so the scene compiles once at the full count, never recompiles).
      // ponytail: no barrels elsewhere -> no flame pool, no per-fragment light cost elsewhere
      if (game.area.typeID == AREA_CITY_LOW)
        flameLights = new FlameLights(actorGroup);
    }

// receive the lamps lit this frame (the pool's active set) so actors cast fake shadows from them
// (mirrors barrels). called each frame; only currently-lit lamps are passed, so no visibility gate
  public function setLamps(lamps:Array<LampPost>):Void
    {
      lampSrc = lamps;
    }

// gather this frame's visible barrels + advance the flame clock (only while a barrel is in view).
// called up front (before the actor loops) so litAt can flicker their glow onto nearby actors, and
// the body/shadow pass reuses the same list. one getObjects scan, reused everywhere
  public function gather(dtMs:Float):Void
    {
      gatherBarrels();
      if (curBarrels.length > 0)
        flameT += dtMs;
    }

// gather this frame's visible burning barrels into curBarrels (world rim pos + flicker phase). one
// getObjects scan, reused by the actor-glow (litAt), the flame body, and the shadow pass
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
  public function driveFireLoop():Void
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
  public function litAt(a:Actor):Float
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

// drive the flame-light pool + draw the flame body/embers, then cast fake shadows from barrels AND
// lamps — all off the pre-gathered curBarrels. the flame passes no-op when no barrel is in view;
// the shadow pass still runs (lamps always cast). called after the ground decals so shadows darken
// blood/debris, and below the actor/marker layers (renderOrder) so icons/rings stay on top
  public function bodyAndShadows(dtMs:Float):Void
    {
      flameBodyAndShadows(dtMs);
      castShadows();
    }

// drive the flame-light pool + draw the flame body/embers, all off the pre-gathered curBarrels.
// no-op when no barrel is in view, so non-low-tier cities pay nothing
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
            {
              var an = rimAnchor(b);
              particles.add(new FlameEmber3D(b.x, an.y, an.z, b.phase));
            }
        }
    }

// world anchor of a barrel's flame: the drum rim, leaned back exactly like the barrel sprite
// (Sprites.paint tilts the upright quad -TILT about its centre). without this the flame/glow/embers
// sit at the un-leaned cell centre and float ~0.45u toward the camera off the tilted rim — invisible
// from the near-overhead default view, a clear gap under a free/fly camera. rimY is the un-leaned
// rim height above the floor; project it through the same centre-pivot lean the barrel uses
  function rimAnchor(b:FlameBarrel):{ y:Float, z:Float }
    {
      var u = RenderConfig.FLAME.rimY - Sprites.SIZE * 0.5;   // rim height above the barrel quad's centre
      return {
        y: b.floor + Sprites.SIZE * 0.5 + u * Math.cos(Sprites.TILT),
        z: b.z - u * Math.sin(Sprites.TILT),
      };
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
      // base pinned to the barrel's leaned rim (matches the tilted drum in depth, not the cell centre)
      var an = rimAnchor(b);
      var baseY = an.y;
      var az = an.z;
      // soft glow halo at the rim (low additive alpha, centered — no sway). front-facing like the
      // flame body so it stays coplanar with the barrel instead of spinning to camera
      sparks.glowQuad(b.x, baseY + F.bodyRise * 0.2, az,
        F.glowW, F.colorHot, F.glowAlpha * (0.6 + 0.4 * fl), Sprites.ORD_ACTOR);
      // outer flame layer: cooler + bigger, gentle vertical bob, base pinned at the rim
      var hO = F.bodyRise * 1.1 * (0.8 + 0.35 * fl);
      var wO = F.bodyW * 1.15 * (0.75 + 0.4 * fl);
      var bobO = Math.sin(flameT * 0.012 + b.phase) * 0.05 * F.bodyRise;
      sparks.flameQuad(b.x, baseY + hO * 0.5 + bobO, az, wO, hO, flameTex, F.colorTip,
        F.bodyAlpha * (0.5 + 0.4 * fl) * 0.8, Sprites.ORD_ACTOR);
      // inner flame layer: hotter + smaller + shorter, faster bob
      var hI = F.bodyRise * 0.72 * (0.85 + 0.4 * fl2);
      var wI = F.bodyW * 0.7 * (0.7 + 0.5 * fl2);
      var bobI = Math.sin(flameT * 0.02 + b.phase * 1.7) * 0.06 * F.bodyRise;
      sparks.flameQuad(b.x, baseY + hI * 0.5 + bobI, az, wI, hI, flameTex, F.colorHot,
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
      var gs = sprites.shadowContent(e.imageName, e.ix, e.iy, e.isMaleAtlas, e.skinColor);
      if (gs == null)
        return;
      var floor = WorldCtx.floorY(a.col, a.row) + 0.06;   // just above the splat/debris plane (+0.04)
      CastShadows.project(sprites, gs, a.x, a.z, floor, a.op, barrelLights, RenderConfig.FLAME.shadowMax);
      CastShadows.project(sprites, gs, a.x, a.z, floor, a.op, lampLights, RenderConfig.LAMP_SHADOW.max);
    }
}

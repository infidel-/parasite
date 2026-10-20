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

// the fake cast-shadow pass of the actor layer: lays a black stretched copy of every visible actor's
// sprite on the ground, one per nearby light source. "lamp" here means ANY pooled LampPost — a street
// post, a sewer manhole shaft, a sewer wall bracket — plus burning barrels, which are gathered and
// lit here too because their flicker is what a barrel's shadow breathes with. reads actor poses from
// the shared Actors map (read-only) but never mutates it.
//
// the SHADOW pass runs everywhere: an area always has lamps. the BARREL half is low-tier city only —
// nothing else spawns them, so the flame-light pool is built only there and every flame path
// early-outs on the empty barrel list elsewhere.
//
// these are painted silhouettes, NOT shadow maps. real per-light shadow maps are the spotlight pool's
// job (render.particles.LampLights); this class has no notion of light height at all, which is why
// castShadows has to scale a low fixture's numbers by hand
//
// (was FlameShadows — docs entries older than the rename use that name)
class LampShadows {
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

// receive the lamps lit this frame (the pool's active set, whatever KIND of fixture owns each slot)
// so actors cast fake shadows from them. called each frame; only lit lamps are passed, no vis gate
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
      // pooled warm lights follow the nearest barrels to the player (to the camera in the fly mode)
      var v = game.scene.view3d;
      if (flameLights != null)
        flameLights.update(flameT, curBarrels, v.lightCol, v.lightRow);
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
// the ground, stretched away from each nearby barrel AND lamp. drawn after the ground decals so a
// shadow darkens the blood/debris it crosses. runs every frame — barrels may be absent, lamps aren't.
// builds this frame's light lists once (shared by all casters), then projects per actor
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
      // lamps: only the lamps lit this frame are in lampSrc, so no visibility gate needed. a healthy
      // bulb publishes flick 1 (steady); a sputtering one breathes its shadow with the light. a bulb
      // mid-OUTAGE is dropped outright — CastShadows weights by (0.7 + 0.3 * flicker), so a fully
      // dark lamp would otherwise still lay a 70%-strength shadow
      // SPLIT BY WHICH SIDE OF A WALL THE FIXTURE IS ON, because this pass has no occlusion test of
      // any kind: it projects away from a light within range and nothing asks whether there is a
      // building between the two. Outdoors that is invisible; in a facility, which is the one area
      // kind that is indoors and outdoors at once, it puts a shadow on the floor INSIDE a room from
      // the mast on the kerb outside it — and the bulkhead lamp over an exterior door made it
      // impossible to miss, being by construction the closest outdoor light there can be to an
      // indoor actor. reported from the game as exactly that.
      //
      // one list per side, built once for the whole frame, and an actor takes the one its own cell
      // is on. render.world.IndoorMask.indoorAt is false everywhere no mask is attached, so every
      // other area kind puts every lamp in `lampOut`, every actor reads `lampOut`, and nothing about
      // a street or a tunnel changes
      var lampOut:Array<CastShadows.ShadowLight> = [];
      var lampIn:Array<CastShadows.ShadowLight> = [];
      if (lampSrc != null)
        {
          var L = RenderConfig.LAMP_SHADOW;
          var lrange = L.rangeCells * CityConfig.CELL;
          // the config is tuned for a street bulb hanging at refY, and CastShadows has no notion of
          // light HEIGHT at all — its length is (sprite height * lenMul * distance falloff). so a
          // sewer wall bracket at 0.6 would rake the walkway with real shadow-map shadows while its
          // fake actor shadow stayed a short overhead smudge. scale both the length and the reach by
          // how far BELOW the reference bulb the fixture sits; a street lamp lands on exactly 1.0.
          // the REACH is then clamped to lowRangeCells — long shadows, but only in a tight pool,
          // otherwise every actor in the tunnel drags a smear off a bulb three rooms away.
          //
          // a HIGH fixture scales the other way and it does not matter here: a facility ceiling light
          // hangs at ROOF_Y - CEIL_DROP = 5.8 against refY 5.6, so `low` is 0.966 and its pool is the
          // street lamp's to within 4%. NOTHING NEEDS A FLOOR ON THIS — checked while chasing "no
          // shadows indoors", which turned out to be about the lighting rig and not about this pass
          var refY = CityConfig.CELL * RenderConfig.LAMP_LIGHT.yMul;
          var lmax = L.lowRangeCells * CityConfig.CELL;
          for (lp in lampSrc)
            {
              if (lp.flick < RenderConfig.LAMP_LIGHT.flickOff)
                continue;
              var low = Math.min(L.lowMax, refY / lp.y);
              var side = (render.world.IndoorMask.indoorAt(lp.col, lp.row) ? lampIn : lampOut);
              if (lp.beam == null)
                {
                  side.push({
                    x: lp.x, z: lp.z, range: Math.min(lrange * low, lmax), lenMul: L.lenMul * low,
                    op: L.op, fade: L.fade, flicker: lp.flick,
                  });
                  continue;
                }
              // an aimed beam: cast down its cone out to its reach, and long — the light is high on a
              // wall and rakes, so the length runs with reach over height (the beacon's 16 over 7.55).
              // Faded with the beam itself under a full lamp's strength: the beacon goes dark for the
              // part of its turn it faces the wall, and its shadows with it
              if (lp.mul <= 0)
                continue;
              var ax = lp.tx - lp.x, az = lp.tz - lp.z;
              var ad = Math.sqrt(ax * ax + az * az);
              side.push({
                x: lp.x,
                z: lp.z,
                range: lp.beam,
                lenMul: L.lenMul * Math.min(L.lowMax, lp.beam / lp.y),
                op: L.op * (lp.shade != null ? lp.shade : Math.min(1.0, lp.mul)),
                fade: L.fade,
                flicker: lp.flick,
                aimX: ax / ad,
                aimZ: az / ad,
                cos: Math.cos(RenderConfig.LAMP_LIGHT.angle),
              });
            }
        }
      if (barrelLights.length == 0 &&
          lampOut.length == 0 &&
          lampIn.length == 0)
        return;
      // AI + non-flat objects (skip the barrels themselves) + a free parasite are the casters
      for (ai in game.area.getAllAI())
        if (ai.entity != null)
          actorShadow(ai.entity, barrelLights, lampOut, lampIn);
      for (o in game.area.getObjects())
        // a prop-backed object casts here TOO, and the guard that used to skip it was wrong. it does
        // own a real shadow-map shadow (Models.instanced flags SOLID castShadow), but underground the
        // only casting lights are the pooled spotlights and LAMP_LIGHT.angle is a 36-degree cone from
        // CELL*yMul up — a pool about two cells across. An organ standing anywhere else is lit by
        // ambient + hemisphere alone, neither of which casts, so it had NO shadow at all. the
        // silhouette comes from the atlas cell (Sprites.shadowContent), which iconOff never touched,
        // so this works unchanged for an object whose icon is suppressed
        // a facility BENCH decoration is the one caster skipped, and the reason is arithmetic:
        // it draws at render.facility.FacilityDeco.spriteScale of a billboard while CastShadows
        // .project sizes its silhouette off the full Sprites.SIZE, so a 20 cm flask would lay a
        // blob three times its own width on the worktop. Skipped rather than plumbing a scale
        // through project's call sites — at that size there is no silhouette to read.
        //
        // AND A CORP ONE IS THE SECOND, which is the opposite case to the tunnels' above and not a
        // walking back of it. Reported as "dark round shadows of nothing on the floor" and it was
        // literal: render.corp.CorpDeco.draws suppresses the sprite for every frame in rows 23-39,
        // and CorpDeco.kindOf answers K_NONE — "something else already draws this" — for a good
        // half of them, CORP_CHAIR (row 30) among them. So the blob was a blurred copy of an icon
        // nothing on the plate draws, laid at the OBJECT's cell while the chair glb stands at
        // CHAIR_OUT off it. What is left is doubly covered now: every corp fitting and glb batch
        // casts a real shadow off the ceiling spotlights, and a workstation carries a
        // FacilityDetail contact pool as well — which is why the monitor had three
        //
        // AND A FACILITY FITTING IS THE THIRD, the corp case over again. render.facility
        // .FacilityDeco.draws suppresses the icon of every frame Const.FACILITY_DECO lists, and the
        // glb standing there draws nothing into this pass — so the analyser and the hangar
        // generator each laid a blurred blob of an atlas cell nothing draws (8/5 and 18/3, the
        // latter a stale 2D-era row), picked in the game as "sprite pool N" beside the prop
        //
        // AND A ROW FLAGGED `noCast` IS THE FOURTH: the sewer/habitat exit ladder and the corp
        // stairwell. each has a real shadow of its own (the ladder's shaft lamp stays over its cell)
        // or stands off its cell, so the atlas copy was the 2D ladder / stairs lying flat at the
        // cell centre — picked in the game as "sprite pool 3" on a habitat exit
        if (o.entity != null &&
            !o.isGroundDecal() &&
            o.type != 'burning_barrel' &&
            !render.corp.CorpDeco.draws(game.area, o) &&
            !render.facility.FacilityDeco.draws(game.area, o) &&
            render.facility.FacilityDeco.spriteScale(game.area, o) >= 1.0 &&
            !noCast(o))
          actorShadow(o.entity, barrelLights, lampOut, lampIn);
      if (game.player.state == _PlayerState.PLR_STATE_PARASITE &&
          !game.playerArea.isHidden())
        actorShadow(game.playerArea.entity, barrelLights, lampOut, lampIn);
    }

// is this object drawn as a prop whose row opts out of the fake atlas shadow?
  static inline function noCast(o:objects.AreaObject):Bool
    {
      var p = render.world.ObjModels.propFor(o.getModelKey());
      return p != null &&
        p.noCast == true;
    }

// cast one actor's shadows: fetch its black silhouette once, then project it away from the barrels
// and the lamps (each capped by its own max). all direction/length/opacity math lives in CastShadows.
//
// the lamps come in as the two lists castShadows split them into and the actor's OWN cell picks one
// — see there. the barrels are not split: they burn in the street and there is no facility that
// spawns one
  function actorShadow(e:Entity, barrelLights:Array<CastShadows.ShadowLight>,
      lampOut:Array<CastShadows.ShadowLight>, lampIn:Array<CastShadows.ShadowLight>):Void
    {
      var a = actors.get(e);
      if (a == null ||
          a.op < 0.05)
        return;
      var gs = sprites.shadowContent(e.imageName, e.ix, e.iy, e.isMaleAtlas, e.skinColor);
      if (gs == null)
        return;
      var floor = WorldCtx.floorY(a.col, a.row) + 0.06;   // just above the splat/debris plane (+0.04)
      // THE RESTING OFFSET IS PART OF THE POSE, and taking a.x/a.z bare was the bug: a facility
      // fitting is drawn pushed off its wall FACE — up to 2.28 of a 4-unit cell — while its object
      // sits on the cell centre, so the shadow landed in the middle of the tile with the drum against
      // the wall. a fallen corpse carries the same offset for its own reason. see ActorAnim.Actor
      var ax = a.x + a.offx;
      var az = a.z + a.offz;
      // AND THE ANIMATION OFFSET IS PART OF THE POSE TOO. render.anim.Effect writes a world offset
      // that render.Actors.drawActor lays over the billboard, and it was read there and nowhere
      // else — so through a lunge, a melee swing, a shake or a leap the sprite slid across the tile
      // while its shadow stood still on the cell it started from. offy is DELIBERATELY not taken:
      // a leaping actor's shadow belongs on the ground it left, not in the air with it.
      // ponytail: fx.scale is skipped with it — CastShadows.project has no scale channel and a Pop
      // lasts 200ms; give it one if a sustained swell ever needs it
      if (a.fx != null)
        {
          ax += a.fx.offx;
          az += a.fx.offz;
        }
      // GLUE THE ROOT TO THE DRAWN FEET. Sprites.paint leans every upright quad back by Sprites.TILT
      // about its own CENTRE, so the content's bottom — the part that reads as standing on the floor
      // — swings toward the camera by its drop below that centre times sin(TILT), up to 0.85 units
      // for a full-size actor. the shadow was rooted on the cell and the actor was drawn in front of
      // it. render.facility.FacilityDeco.poolOf is this same expression for a bench decoration's
      // contact pool, and FacilityStyle.TABLE_POOL_DZ's note records it being reported once already.
      // off the silhouette's OWN alpha box (gs.by) and not a constant: a sprite whose art stops
      // short of the cell's bottom edge hangs less far forward than one that fills it
      az += Sprites.SIZE * (0.5 - gs.by) * Math.sin(Sprites.TILT);
      CastShadows.project(sprites, gs, ax, az, floor, a.op, barrelLights, RenderConfig.FLAME.shadowMax);
      CastShadows.project(sprites, gs, ax, az, floor, a.op,
        render.world.IndoorMask.indoorAt(a.col, a.row) ? lampIn : lampOut,
        RenderConfig.LAMP_SHADOW.max);
    }
}

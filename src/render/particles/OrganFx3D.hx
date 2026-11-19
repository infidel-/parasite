package render.particles;

import three.Three;
import citygen.CityConfig;
import game.Game;
import cult.base.CultBaseOrgan;
import cult.base.OrganFxKind;
import render.RenderConfig;
import render.world.ObjModels;
import render.world.WorldCtx;

// a cult base organ's destroy/repair/upgrade/birth animation. it poses the organ's own prop instance (every
// batch standing on its anchor cell, solid, ghost and hull alike) each frame by scaling it about its
// base, and paints its sparks round it. a DESTROY holds the intact model until the slump lands and
// only then rebuilds the props, so the ruin swaps in at its own height (ObjModels.RUIN_SQUASH)
class OrganFx3D extends Particle3D {
  // durations and beats, all in BASE_MS units
  static inline var DESTROY_T = 8.0;    // shudder, slump, settle
  static inline var SHUDDER_T = 3.0;    // the shudder before it gives way
  static inline var SLUMP_T = 3.0;      // the fall to the ruin's height
  static inline var REPAIR_T = 7.0;     // the rise back to full height
  static inline var KNIT_T = 4.0;       // the sinews reach the organ by
  static inline var UPGRADE_T = 6.0;    // the heartbeat swell
  static inline var BIRTH_T = 9.0;      // the heart's rise out of the floor
  // shapes, as fractions of the prop or of a cell
  static inline var SHUDDER_AMP = 0.03; // shudder jitter, of a cell
  static inline var SPREAD = 0.08;      // how much wider a slumping organ spreads
  static inline var SWELL = 0.15;       // upgrade swell, of the prop's size
  static inline var RING_SPREAD = 1.5;  // cells the upgrade ring's radius grows past the footprint
  static inline var RING_Y = 0.15;     // the upgrade ring's lift off the floor: over the raised flesh and vessels
  static inline var RING_EMBERS = 20;   // embers drawing it, each a tangent dash
  static inline var SINEWS = 8;         // streaks knitting into a mended organ
  static inline var BLOOD_DROPS = 14;   // the burst a destroyed organ bleeds
  static inline var BIRTH_WIDTH = 0.3;  // a newborn heart's width as it breaks the floor, of its own
  // colours
  static inline var BLOOD_COL = 0x8c1c1c;
  static inline var SINEW_COL = 0xd04a78;
  static inline var CULT_COL = 0xe0609a;

  var game:Game;
  var particles:Particles3D;            // where the destroy's blood burst goes
  var kind:OrganFxKind;
  var areaID:Int;
  var col:Int;                          // the anchor cell its prop stands on
  var row:Int;
  var cx:Float;                         // its footprint's centre, world
  var cz:Float;
  var floor:Float;
  var big:Float;                        // its footprint's width, cells
  var h:Float;                          // its prop's height, read off the posed row
  var t:Float = 0.0;
  var dur:Float;
  var bled:Bool = false;
  var held:Array<{ p:Models.InstancedProp, i:Int, base:Matrix4 }> = [];
  var onDone:Void -> Void;              // runs when it ends, or null

  public function new(game:Game, particles:Particles3D, organ:CultBaseOrgan, kind:OrganFxKind,
      onDone:Void -> Void)
    {
      super();
      this.onDone = onDone;
      this.game = game;
      this.particles = particles;
      this.kind = kind;
      areaID = game.area.id;
      col = organ.x;
      row = organ.y;
      var maxX = organ.x;
      var maxY = organ.y;
      for (pt in organ.footprint())
        {
          maxX = Std.int(Math.max(maxX, pt.x));
          maxY = Std.int(Math.max(maxY, pt.y));
        }
      var w = CityConfig.cellToWorld((organ.x + maxX) / 2, (organ.y + maxY) / 2);
      cx = w.x;
      cz = w.z;
      floor = WorldCtx.floorY(col, row);
      big = maxX - organ.x + 1;
      h = CityConfig.CELL;
      dur = switch (kind)
        {
          case DESTROY: DESTROY_T;
          case REPAIR | MEND: REPAIR_T;
          case UPGRADE: UPGRADE_T;
          case BIRTH: BIRTH_T;
        };
      if (kind == BIRTH)
        game.scene.view3d.playQuake();
    }

  override public function tick(dtMs:Float):Bool
    {
      t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (t >= dur ||
          game.area.id != areaID)
        return false;
      var sx = 1.0;
      var sy = 1.0;
      var jx = 0.0;
      var jz = 0.0;
      switch (kind)
        {
          // shudder harder and harder, give way, sink a touch below the ruin's height and settle on it
          case DESTROY:
            var rs = ObjModels.RUIN_SQUASH;
            if (t < SHUDDER_T)
              {
                var a = SHUDDER_AMP * CityConfig.CELL * t / SHUDDER_T;
                jx = a * Math.sin(t * 20.0);
                jz = a * Math.sin(t * 15.0 + 1.3);
              }
            else if (t < SHUDDER_T + SLUMP_T)
              {
                var u = (t - SHUDDER_T) / SLUMP_T;
                sy = 1 - (1 - rs) * u * u;
                sx = 1 + SPREAD * u * u;
              }
            else
              {
                var u = (t - SHUDDER_T - SLUMP_T) / (DESTROY_T - SHUDDER_T - SLUMP_T);
                sy = rs - 0.06 * Math.sin(Math.PI * u) * (1 - u);
                sx = 1 + SPREAD * (1 - u);
              }
            if (!bled &&
                t >= SHUDDER_T)
              {
                bled = true;
                var ic = Const.bloodIcon('red');
                BloodDrop3D.burst(particles, game, col, row, 0, 0, ic.row, ic.col, BLOOD_DROPS);
              }
          // rise from the ruin's height past full and back (an ease-out-back)
          case REPAIR:
            var u = t / REPAIR_T - 1;
            var c = 1.70158;
            var rs = ObjModels.RUIN_SQUASH;
            sy = rs + (1 - rs) * (1 + (c + 1) * u * u * u + c * u * u);
          case MEND:
          // one heartbeat
          case UPGRADE:
            sx = sy = 1 + SWELL * Math.sin(Math.PI * t / UPGRADE_T);
          // tear up from nothing past full height and back (an ease-out-back), swelling out from a stalk
          case BIRTH:
            var u = t / BIRTH_T - 1;
            var c = 1.70158;
            sy = 1 + (c + 1) * u * u * u + c * u * u;
            sx = 1 - (1 - BIRTH_WIDTH) * u * u;
        }
      pose(sx, sy, jx, jz);
      return true;
    }

// scale every placement on the anchor cell about its base, from the transform it had when first seen
  function pose(sx:Float, sy:Float, jx:Float, jz:Float):Void
    {
      for (pl in ObjModels.placedAt(col, row))
        {
          // the ruin a rebuild put there early is already down: a destroy slumps the intact model only
          if (kind == DESTROY &&
              pl.b.model.ruin == true)
            continue;
          h = pl.b.model.h;
          var by = floor - pl.b.model.sink * h;
          for (p in [ pl.b.solid, pl.b.ghost, pl.b.hull ])
            {
              if (pl.i >= p.matrices.length)
                continue;
              var base = baseOf(p, pl.i);
              var e = p.matrices[pl.i].copy(base).elements;
              var bx = p.centres[pl.i].x;
              var bz = p.centres[pl.i].z;
              // world = T(b) · S · T(-b) · M, S axis-aligned: the yaw is about y, so it commutes
              for (c in 0...3)
                {
                  e[c * 4] *= sx;
                  e[c * 4 + 1] *= sy;
                  e[c * 4 + 2] *= sx;
                }
              e[12] = bx + (e[12] - bx) * sx + jx;
              e[13] = by + (e[13] - by) * sy;
              e[14] = bz + (e[14] - bz) * sx + jz;
            }
        }
    }

// the transform a placement had before this fx touched it, kept the first time it is posed (a
// rebuild mid-fx hands over fresh batches, which are captured fresh)
  function baseOf(p:Models.InstancedProp, i:Int):Matrix4
    {
      for (hd in held)
        if (hd.p == p &&
            hd.i == i)
          return hd.base;
      var base = p.matrices[i].clone();
      held.push({
        p: p,
        i: i,
        base: base,
      });
      return base;
    }

  override public function draw(paint:Paint3D):Void
    {
      var cell = CityConfig.CELL;
      switch (kind)
        {
          // a dark red flash as it gives way
          case DESTROY:
            var u = (t - SHUDDER_T + 1.0) / 3.0;
            if (u > 0 &&
                u < 1)
              paint.sparks.glowQuad(cx, floor + h * 0.4, cz, big * cell * 1.3, BLOOD_COL,
                0.6 * Math.sin(Math.PI * u));
          // flesh-pink sinews spiralling in, then one soft glow where they met
          case REPAIR | MEND | BIRTH:
            var p = Math.min(1.0, t / KNIT_T);
            if (p < 1)
              for (i in 0...SINEWS)
                {
                  var a = i / SINEWS * Math.PI * 2 + p * 1.6;
                  var r = big * cell * 0.9 * (1 - p);
                  var y = floor + h * (0.15 + 0.5 * ((i * 37) % SINEWS) / SINEWS);
                  paint.sparks.streak(cx + Math.cos(a) * r, y, cz + Math.sin(a) * r,
                    -Math.cos(a), 0, -Math.sin(a), cell * (0.1 + 0.4 * (1 - p)), cell * 0.06,
                    SINEW_COL, 0.8 * (1 - p * p));
                }
            var u = (t - KNIT_T * 0.8) / (dur - KNIT_T * 0.8);
            if (u > 0)
              paint.sparks.glowQuad(cx, floor + h * 0.5, cz, big * cell * 1.1, SINEW_COL,
                0.5 * Math.sin(Math.PI * Math.min(1.0, u)));
          // a glow at the crown and a ring spreading across the floor
          case UPGRADE:
            var u = t / UPGRADE_T;
            paint.sparks.glowQuad(cx, floor + h * 0.8, cz, big * cell * 1.2, CULT_COL,
              0.6 * Math.sin(Math.PI * u));
            // a ring of embers and not a flat ring sprite: a lit floor quad drowned in the raised flesh
            var r = (big * 0.4 + RING_SPREAD * u) * cell;
            for (i in 0...RING_EMBERS)
              {
                var a = i / RING_EMBERS * Math.PI * 2;
                paint.sparks.streak(cx + Math.cos(a) * r, floor + RING_Y, cz + Math.sin(a) * r,
                  -Math.sin(a), 0, Math.cos(a), cell * 0.3, cell * 0.07, CULT_COL, 0.9 * (1 - u * u));
              }
        }
    }

// put every posed placement back, and land a destroy: the props rebuild with the ruin
  override public function onDeath():Void
    {
      for (hd in held)
        hd.p.matrices[hd.i].copy(hd.base);
      if (kind == DESTROY &&
          game.area.id == areaID)
        game.scene.updateObjects3D();
      if (onDone != null)
        onDone();
    }
}

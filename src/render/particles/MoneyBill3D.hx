package render.particles;

import citygen.CityConfig;
import render.RenderConfig;

// one thrown money bill in the 3D view: launched from the thrower's chest in a chaotic fountain,
// it arcs out tumbling (in-plane roll + horizontal-mirror spin) with a growing lateral flutter,
// lands flat on the ground and fades away after a rest. paints onto the shared Sprites pool
// (no owned meshes). 3D port of ParticleMoney (real flying bills instead of per-tile pops)
class MoneyBill3D extends Particle3D {
  var sx:Float; var sy:Float; var sz:Float;             // launch world pos (chest height)
  var lx:Float; var ly:Float; var lz:Float;             // landing world pos (on the ground)
  var delay:Float;                                      // launch delay (BASE_MS units)
  var fly:Float;                                        // flight duration (BASE_MS units)
  var spin:Float;                                       // horizontal-mirror tumble speed (rad per BASE_MS)
  var roll:Float;                                       // in-plane roll speed (rad per BASE_MS)
  var phase:Float;                                      // random per-bill phase for spin/flutter
  var landYaw:Float;                                    // resting ground rotation
  var side:Float;                                       // flutter side bias (-1..1)
  var age:Float = 0.0;                                  // lifetime clock (BASE_MS units)

  public function new(sx:Float, sy:Float, sz:Float, lx:Float, ly:Float, lz:Float)
    {
      super();
      this.sx = sx; this.sy = sy; this.sz = sz;
      this.lx = lx; this.ly = ly; this.lz = lz;
      var M = RenderConfig.MONEY;
      delay = Math.random() * M.staggerMult;
      fly = M.flyMult + (Math.random() * 2 - 1) * M.flyVar;
      spin = (0.5 + Math.random() * 0.5) * M.spinMax;
      roll = (Math.random() * 2 - 1) * M.rollMax;
      phase = Math.random() * Math.PI * 2;
      landYaw = Math.random() * Math.PI * 2;
      side = (Math.random() * 2 - 1);
    }

// advance the lifetime clock (BASE_MS units, global anim speed applied)
  override public function tick(dtMs:Float):Bool
    {
      var M = RenderConfig.MONEY;
      age += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      return age < delay + fly + M.restMult + M.fadeMult;
    }

// draw the bill: a tumbling eased arc in flight, then a flat ground decal resting and fading
  override public function draw(p:Paint3D):Void
    {
      var M = RenderConfig.MONEY;
      var a = age - delay;
      if (a < 0)
        return;
      var g = p.sprites;
      var tex = g.tex('entities', Const.FRAME_PARTICLE_MONEY, Const.ROW_EFFECT, false);
      // in flight: fast launch easing out toward the landing spot, arcing over the straight
      // line, fluttering sideways more and more as the bill slows down, tumbling all along
      if (a < fly)
        {
          var t = a / fly;
          var ease = 1 - (1 - t) * (1 - t);
          var x = sx + (lx - sx) * ease;
          var z = sz + (lz - sz) * ease;
          var y = sy + (ly - sy) * t + M.arcHeight * CityConfig.CELL * 4 * t * (1 - t);
          // lateral flutter perpendicular to the flight line
          var dx = lx - sx, dz = lz - sz;
          var len = Math.sqrt(dx * dx + dz * dz);
          if (len < 0.001)
            len = 1;
          var sw = Math.sin(a * 6 + phase) * M.flutter * CityConfig.CELL * side * t;
          g.paint({
            x: x - dz / len * sw,
            y: y,
            z: z + dx / len * sw,
            tex: tex,
            op: 1.0,
            scale: M.scale,
            yaw: phase + roll * a,
            faceX: Math.cos(spin * a + phase),
            // airborne: actor tier so a flying bill isn't hidden behind an AI (default 0 = ground
            // decal tier -> drew under every actor). the landed bill below stays ground-tier
            order: Sprites.ORD_ACTOR,
          });
          return;
        }
      // landed: flat on the ground, resting then fading out
      var rest = a - fly;
      var op = 1.0;
      if (rest > M.restMult)
        op = 1 - (rest - M.restMult) / M.fadeMult;
      g.paint({
        x: lx,
        y: ly,
        z: lz,
        tex: tex,
        op: op,
        scale: M.scale,
        flat: true,
        yaw: landYaw,
      });
    }
}

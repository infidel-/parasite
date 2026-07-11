package render.particles;

import citygen.CityConfig;
import render.RenderConfig;

// a burst of impact sparks thrown from a wall strike: N embers spray back off the wall + up, arc
// under gravity, and draw as camera-facing soft streaks (via the Sparks pool). pure transient FX.
// startDelay defers the spray until the tracer actually reaches the wall
class SparkBurst3D extends Particle3D {
  var startDelay:Float;                                 // wait before the spray fires (ms)
  var started:Bool = false;
  var life:Float = 0.0;                                 // ms since the spray started
  var maxLife:Float;
  var n:Int;                                            // ember count
  // per-ember world position + velocity (units, units/sec)
  var px:Array<Float> = []; var py:Array<Float> = []; var pz:Array<Float> = [];
  var vx:Array<Float> = []; var vy:Array<Float> = []; var vz:Array<Float> = [];

  // ox,oy,oz = impact point; backX,backZ = direction back off the wall (toward the shooter)
  public function new(ox:Float, oy:Float, oz:Float, backX:Float, backZ:Float, startDelay:Float)
    {
      super();
      this.startDelay = startDelay;
      var S = RenderConfig.SHOT;
      maxLife = S.sparkMs;
      n = S.sparkCount;
      var base = S.sparkSpeed * CityConfig.CELL;         // world units/sec
      // normalize the back-off-wall direction (fallback: no horizontal bias, pure up)
      var bl = Math.sqrt(backX * backX + backZ * backZ);
      if (bl < 1e-4) { backX = 0; backZ = 0; }
      else { backX /= bl; backZ /= bl; }
      for (_ in 0...n)
        {
          // spray in a cone around the back direction, biased upward, with random speed
          var a = (Math.random() - 0.5) * S.sparkCone;
          var ca = Math.cos(a), sa = Math.sin(a);
          var hx = backX * ca - backZ * sa;
          var hz = backX * sa + backZ * ca;
          var hs = base * (0.35 + 0.9 * Math.random());  // horizontal speed spread
          var up = base * (0.4 + 1.0 * Math.random());   // upward kick
          px.push(ox); py.push(oy); pz.push(oz);
          vx.push(hx * hs); vy.push(up); vz.push(hz * hs);
        }
    }

// integrate one frame: wait out startDelay, then arc every ember under gravity; die at maxLife
  override public function tick(dtMs:Float):Bool
    {
      if (!started)
        {
          startDelay -= dtMs;
          if (startDelay > 0)
            return true;
          started = true;
        }
      var dt = dtMs / 1000.0;
      var g = RenderConfig.SHOT.sparkGravity * CityConfig.CELL;
      for (i in 0...n)
        {
          vy[i] -= g * dt;
          px[i] += vx[i] * dt;
          py[i] += vy[i] * dt;
          pz[i] += vz[i] * dt;
        }
      life += dtMs;
      return life < maxLife;
    }

// draw each ember as a camera-facing soft streak, stretched by its speed, fading over life
  override public function draw(p:Paint3D):Void
    {
      if (!started)
        return;
      var S = RenderConfig.SHOT;
      var C = CityConfig.CELL;
      var op = 1 - life / maxLife;
      if (op < 0) op = 0;
      var width = S.sparkWidth * C;
      for (i in 0...n)
        {
          var sp = Math.sqrt(vx[i] * vx[i] + vy[i] * vy[i] + vz[i] * vz[i]);
          var len = sp * S.sparkStreak;                  // motion-blur length (seconds of travel)
          if (len < width) len = width;                  // slow embers read as round dots
          p.sparks.streak(px[i], py[i], pz[i], vx[i], vy[i], vz[i], len, width, S.sparkColor, op);
        }
    }
}

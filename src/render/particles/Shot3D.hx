package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// one gun-shot pellet in the 3D view: a blooming tracer streak that races muzzle->impact plus a
// muzzle flash, and (when it ends on a wall) a burst of impact shards. pure state — all visuals are painted
// each frame onto the shared Beams pool (no owned meshes, nothing to allocate/dispose per shot).
// the muzzle *light* is a separate pooled resource (MuzzleLights), pulsed once per shot by the
// caller. blood + impact sound fire via the onImpact closure (only the primary pellet carries it)
class Shot3D extends Particle3D {
  var mx:Float; var my:Float; var mz:Float;             // muzzle world pos (my = bullet height)
  var ix:Float; var iz:Float;                           // impact world pos (same height as muzzle)
  var len:Float;                                        // full muzzle->impact ground length
  var yaw:Float;                                        // ground yaw of the tracer, muzzle->impact
  var spark:Bool;                                       // impact shards at the end? (true only on a wall strike)
  var onImpact:Void->Void;                              // impact beat (blood + sound); nullable
  var sparkDx:Array<Float> = [];                        // per-shard outward direction
  var sparkDz:Array<Float> = [];

  var startDelay:Float;                                 // stagger before this pellet fires (ms)
  var started:Bool = false;                             // stagger elapsed?
  var elapsed:Float = 0.0;                              // ms since this pellet started
  var impacted:Bool = false;                            // onImpact fired yet?

  public function new(muzzle:Vector3, impact:Vector3, startDelay:Float, spark:Bool, onImpact:Void->Void)
    {
      super();
      this.startDelay = startDelay;
      this.spark = spark;
      this.onImpact = onImpact;
      mx = muzzle.x; my = muzzle.y; mz = muzzle.z;
      ix = impact.x; iz = impact.z;
      var dx = ix - mx, dz = iz - mz;
      len = Math.sqrt(dx * dx + dz * dz);
      // flat-quad yaw so the tracer's local +X points along world (dx,dz) (see Beams.quad /
      // the -PI/2 X-tilt convention): local +X ends up at (cos yaw, -sin yaw)
      yaw = Math.atan2(-dz, dx);
      if (spark)
        for (i in 0...RenderConfig.SHOT.sparkCount)
          {
            var a = Math.PI * 2 * Math.random();
            sparkDx.push(Math.cos(a));
            sparkDz.push(Math.sin(a));
          }
    }

// advance one frame; wait out the stagger, race the tracer, latch-fire the impact beat
  override public function tick(dtMs:Float):Bool
    {
      if (!started)
        {
          startDelay -= dtMs;
          if (startDelay > 0)
            return true;
          started = true;
        }
      elapsed += dtMs;
      var S = RenderConfig.SHOT;
      if (!impacted &&
          elapsed >= S.travelMs)
        {
          impacted = true;
          if (onImpact != null) onImpact();
        }
      return elapsed < S.travelMs + S.sparkMs;
    }

// paint the shot's visuals onto the bright-FX pool
  override public function draw(p:Paint3D):Void
    {
      if (!started)
        return;
      var g = p.beams;
      var S = RenderConfig.SHOT;
      var C = CityConfig.CELL;
      // muzzle flash: grows + fades over flashMs
      var fe = elapsed / S.flashMs;
      if (fe < 1)
        {
          var fs = S.flashSize * C * (0.6 + 0.8 * fe);
          g.quad(mx, my, mz, fs, fs, 0, S.flashColor, 1 - fe);
        }
      // tracer: a short streak racing to the target, then the full run fading out
      var width = S.tracerWidth * C;
      var p0 = elapsed / S.travelMs;
      if (p0 < 1)
        {
          var tailP = p0 - S.tailFrac;
          if (tailP < 0) tailP = 0;
          var ax = lerpX(tailP), az = lerpZ(tailP);
          var bx = lerpX(p0), bz = lerpZ(p0);
          var seg = Math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az));
          if (seg < 0.01) seg = 0.01;
          g.quad((ax + bx) / 2, my, (az + bz) / 2, seg, width, yaw, S.tracerColor, 1.0);
        }
      else
        {
          var q = (elapsed - S.travelMs) / S.sparkMs;
          g.quad((mx + ix) / 2, my, (mz + iz) / 2, len, width, yaw, S.tracerColor, Math.max(0, 1 - q));
          // impact shards drift outward from the impact point and fade
          if (spark)
            {
              var dt2 = (elapsed - S.travelMs) / 1000.0;
              var op = Math.max(0, 1 - q);
              var sz = S.sparkSize * C;
              for (i in 0...sparkDx.length)
                g.quad(
                  ix + sparkDx[i] * S.sparkSpeed * C * dt2, my,
                  iz + sparkDz[i] * S.sparkSpeed * C * dt2,
                  sz, sz, 0, S.sparkColor, op);
            }
        }
    }

// on the muzzle->impact line at fraction t
  inline function lerpX(t:Float):Float
    return mx + (ix - mx) * t;
  inline function lerpZ(t:Float):Float
    return mz + (iz - mz) * t;
}

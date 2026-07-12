package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.RenderConfig.ShotKind;

// one gun-shot pellet in the 3D view: a blooming tracer streak that races muzzle->impact plus a
// muzzle flash. pure state — all visuals are painted each frame onto the shared Beams pool (no
// owned meshes, nothing to allocate/dispose per shot). the muzzle *light* is a separate pooled
// resource (MuzzleLights), pulsed once per shot by the caller. impact sparks are their own
// particle (SparkBurst3D). blood + impact sound fire via the onImpact closure (primary pellet only)
class Shot3D extends Particle3D {
  var mx:Float; var my:Float; var mz:Float;             // muzzle world pos (my = bullet height)
  var ix:Float; var iz:Float;                           // impact world pos (same height as muzzle)
  var len:Float;                                        // full muzzle->impact ground length
  var yaw:Float;                                        // ground yaw of the tracer, muzzle->impact
  var kind:ShotKind;                                    // per-weapon tracer style (color/width/wave)
  var onImpact:Void->Void;                              // impact beat (blood + sound); nullable

  var startDelay:Float;                                 // stagger before this pellet fires (ms)
  var started:Bool = false;                             // stagger elapsed?
  var elapsed:Float = 0.0;                              // ms since this pellet started
  var impacted:Bool = false;                            // onImpact fired yet?

  public function new(muzzle:Vector3, impact:Vector3, startDelay:Float,
      kind:ShotKind, onImpact:Void->Void)
    {
      super();
      this.startDelay = startDelay;
      this.kind = kind;
      this.onImpact = onImpact;
      mx = muzzle.x; my = muzzle.y; mz = muzzle.z;
      ix = impact.x; iz = impact.z;
      var dx = ix - mx, dz = iz - mz;
      len = Math.sqrt(dx * dx + dz * dz);
      // flat-quad yaw so the tracer's local +X points along world (dx,dz) (see Beams.quad /
      // the -PI/2 X-tilt convention): local +X ends up at (cos yaw, -sin yaw)
      yaw = Math.atan2(-dz, dx);
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
      var travel = S.travelMs * kind.travelMult;
      if (!impacted &&
          elapsed >= travel)
        {
          impacted = true;
          if (onImpact != null) onImpact();
        }
      return elapsed < travel + S.sparkMs;
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
      var width = kind.width * C;
      var travel = S.travelMs * kind.travelMult;
      var p0 = elapsed / travel;
      if (p0 < 1)
        {
          var tailP = p0 - S.tailFrac;
          if (tailP < 0) tailP = 0;
          span(g, tailP, p0, width, 1.0);
        }
      else
        {
          var q = (elapsed - travel) / S.sparkMs;
          span(g, 0, 1, width, Math.max(0, 1 - q));
        }
    }

// paint the [a..b] fraction of the muzzle->impact run: one quad when straight, a chain of
// short quads tracing an animated sine (perpendicular, in the ground plane) when wavy
  function span(g:Beams, a:Float, b:Float, width:Float, op:Float):Void
    {
      var S = RenderConfig.SHOT;
      var C = CityConfig.CELL;
      if (kind.waveAmp == 0)
        {
          var ax = lerpX(a), az = lerpZ(a);
          var bx = lerpX(b), bz = lerpZ(b);
          var seg = Math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az));
          if (seg < 0.01) seg = 0.01;
          g.quad((ax + bx) / 2, my, (az + bz) / 2, seg, width, yaw, kind.color, op);
          return;
        }
      // ground-plane unit perpendicular to the run + the drifting wave phase
      var px = -(iz - mz) / (len < 0.001 ? 1 : len);
      var pz = (ix - mx) / (len < 0.001 ? 1 : len);
      var phase = elapsed / S.waveMs * Math.PI * 2;
      var n = Std.int((b - a) * len / C * 4);
      if (n < 4) n = 4;
      var x0 = 0.0, z0 = 0.0;
      for (i in 0...n + 1)
        {
          var t = a + (b - a) * i / n;
          // sine offset, pinched to zero at both ends so the bolt stays anchored
          var pinch = Math.min(1, Math.min(t * 4, (1 - t) * 4));
          var off = kind.waveAmp * C * pinch * Math.sin(t * len / (kind.waveLen * C) * Math.PI * 2 - phase);
          var x1 = lerpX(t) + px * off;
          var z1 = lerpZ(t) + pz * off;
          if (i > 0)
            {
              var dx = x1 - x0, dz = z1 - z0;
              var seg = Math.sqrt(dx * dx + dz * dz);
              if (seg < 0.001) seg = 0.001;
              g.quad((x0 + x1) / 2, my, (z0 + z1) / 2, seg * 1.05, width,
                Math.atan2(-dz, dx), kind.color, op);
            }
          x0 = x1;
          z0 = z1;
        }
    }

// on the muzzle->impact line at fraction t
  inline function lerpX(t:Float):Float
    return mx + (ix - mx) * t;
  inline function lerpZ(t:Float):Float
    return mz + (iz - mz) * t;
}

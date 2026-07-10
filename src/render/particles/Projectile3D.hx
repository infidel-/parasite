package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// one thrown organic projectile (spit clot / spine needle) in the 3D view: an entities-atlas
// blob with a few trailing drips racing source->target at chest height. all visuals paint onto
// the shared Sprites pool each frame (no owned meshes); the impact beat (splat burst + sound)
// fires via the onImpact closure on arrival. 3D port of ParticleSpit/ParticleNeedle
class Projectile3D extends Particle3D {
  var mx:Float; var my:Float; var mz:Float;             // source world pos (my = flight height)
  var ix:Float; var iz:Float;                           // impact world pos (same height)
  var dxn:Float; var dzn:Float;                         // unit flight direction on the ground plane
  var len:Float;                                        // full source->impact ground length
  var col:Int; var row:Int;                             // entities-atlas cell of the blob sprite
  var glow:Int;                                         // emissive tint on the blob (0 = none; acid/slime goop)
  var scale:Float;                                      // main blob scale (of a billboard)
  var drips:Int;                                        // trailing drip blobs
  var dripSide:Array<Float>;                            // per-drip lateral bias (-1..1)
  var travelMs:Float;                                   // full flight time
  var onImpact:Void->Void;                              // impact beat (splat + sound); nullable

  var elapsed:Float = 0.0;
  var impacted:Bool = false;

  public function new(src:Vector3, dst:Vector3, col:Int, row:Int, glow:Int,
      scale:Float, drips:Int, travelMs:Float, onImpact:Void->Void)
    {
      super();
      mx = src.x; my = src.y; mz = src.z;
      ix = dst.x; iz = dst.z;
      this.col = col;
      this.row = row;
      this.glow = glow;
      this.scale = scale;
      this.drips = drips;
      this.travelMs = travelMs;
      this.onImpact = onImpact;
      var dx = ix - mx, dz = iz - mz;
      len = Math.sqrt(dx * dx + dz * dz);
      if (len < 0.001)
        {
          dxn = 0;
          dzn = 1;
          len = 1;
        }
      else
        {
          dxn = dx / len;
          dzn = dz / len;
        }
      dripSide = [];
      for (_ in 0...drips)
        dripSide.push(Math.random() * 2 - 1);
    }

// advance the flight; latch-fire the impact beat on arrival
  override public function tick(dtMs:Float):Bool
    {
      elapsed += dtMs;
      if (!impacted &&
          elapsed >= travelMs)
        {
          impacted = true;
          if (onImpact != null)
            onImpact();
        }
      return elapsed < travelMs;
    }

// draw the main blob + trailing drips swaying off the flight line, fading over the last stretch
  override public function draw(p:Paint3D):Void
    {
      var P = RenderConfig.PROJECTILE;
      var C = CityConfig.CELL;
      var t = elapsed / travelMs;
      if (t > 1)
        t = 1;
      var alpha = 1.0;
      if (t > 1 - P.fadeFrac)
        alpha = (1 - t) / P.fadeFrac;
      var g = p.sprites;
      var tex = g.tex('entities', col, row, false);
      var headDist = t * len;
      // acid/slime goop glows faintly in flight (alpha-shaped emissive, like the landed splat)
      var glowInt = (glow != 0 ? RenderConfig.BLOOD.glowIntFlight : 0.0);
      // trailing drips behind the head, each with its own lateral bias + a light sine wobble
      for (i in 0...drips)
        {
          var d = headDist - P.dripGap * (i + 1) * C;
          if (d < 0)
            d = 0;
          var sway = dripSide[i] * P.dripSway * C +
            Math.sin(t * 10 + i * 1.5) * P.wobbleAmp * C;
          g.paint({
            x: mx + dxn * d - dzn * sway,
            y: my,
            z: mz + dzn * d + dxn * sway,
            tex: tex,
            op: alpha * (0.9 - 0.15 * i),
            scale: scale * (0.92 - 0.12 * i),
            emissive: glow,
            emissiveInt: glowInt,
          });
        }
      // main blob on top of the trail
      g.paint({
        x: mx + dxn * headDist,
        y: my,
        z: mz + dzn * headDist,
        tex: tex,
        op: alpha,
        scale: scale,
        emissive: glow,
        emissiveInt: glowInt,
      });
    }
}

package render.particles;

import citygen.CityConfig;
import render.RenderConfig;

// one rising ember off a burning barrel: launches up from the rim with a little outward drift,
// floats up (buoyant, no gravity), wobbles sideways, and fades over its life. drawn as a warm
// camera-facing soft dot via the Sparks pool. pure transient FX (template: SparkBurst3D, one ember)
class FlameEmber3D extends Particle3D {
  var x:Float; var y:Float; var z:Float;                 // world pos
  var vx:Float; var vy:Float; var vz:Float;              // world velocity (units/sec)
  var wob:Float;                                         // sideways wobble phase
  var life:Float = 0.0;                                  // ms lived
  var maxLife:Float;

  public function new(ox:Float, oy:Float, oz:Float, phase:Float)
    {
      super();
      var F = RenderConfig.FLAME;
      var C = CityConfig.CELL;
      x = ox; y = oy; z = oz;
      // small outward drift + a buoyant upward rise (spread so embers stagger)
      vx = (Math.random() - 0.5) * 0.6 * C;
      vz = (Math.random() - 0.5) * 0.6 * C;
      vy = F.emberRise * C * (0.7 + 0.6 * Math.random());
      wob = phase + Math.random() * 6.28;
      maxLife = F.emberLife * (0.7 + 0.6 * Math.random());
    }

// integrate one frame: float up, wobble sideways, die at maxLife
  override public function tick(dtMs:Float):Bool
    {
      var dt = dtMs / 1000.0;
      life += dtMs;
      wob += dt * 6.0;
      x += (vx + Math.sin(wob) * 0.4 * CityConfig.CELL) * dt;
      y += vy * dt;
      z += (vz + Math.cos(wob) * 0.4 * CityConfig.CELL) * dt;
      return life < maxLife;
    }

// draw as a warm soft dot, fading + shrinking over life
  override public function draw(p:Paint3D):Void
    {
      var F = RenderConfig.FLAME;
      var k = 1 - life / maxLife;
      if (k < 0) k = 0;
      var w = F.emberW * CityConfig.CELL * (0.5 + 0.5 * k);
      p.sparks.streak(x, y, z, vx, vy, vz, w, w, F.emberColor, k);
    }
}

package render.particles;

import three.Three;
import render.RenderConfig;

// a fixed pool of muzzle point lights, all created up front and kept in the scene forever at
// intensity 0. a shot grabs a free one, moves it to the muzzle and pulses it, then it decays
// back to 0 — it is never added, removed, or hidden. that keeps NUM_POINT_LIGHTS constant, so
// three never recompiles the scene's (hundreds of) lit materials mid-firefight. cost scales
// with the pool SIZE (every light loops per-pixel even at intensity 0), so the pool is small
// and only near-camera shots claim one; distant shots just get the emissive flash quad
class MuzzleLights {
  var lights:Array<PointLight> = [];
  var timers:Array<Float> = [];                         // ms of decay left; <=0 = idle
  var next:Int = 0;                                     // round-robin eviction cursor

  public function new(group:Group)
    {
      var S = RenderConfig.SHOT;
      // NOTE: never toggle .visible — an invisible light drops out of NUM_POINT_LIGHTS and
      // forces the very recompile this pool exists to avoid. idle == visible + intensity 0
      for (i in 0...S.lightPool)
        {
          var l = new PointLight(S.lightColor, 0, S.lightDistance, 1.6);
          group.add(l);
          lights.push(l);
          timers.push(0);
        }
    }

// pulse a light at the muzzle: reuse an idle one, else evict the oldest (round-robin)
  public function flash(x:Float, y:Float, z:Float):Void
    {
      if (lights.length == 0)
        return;
      var idx = -1;
      for (i in 0...timers.length)
        if (timers[i] <= 0)
          { idx = i; break; }
      if (idx < 0)
        { idx = next; next = (next + 1) % lights.length; }
      lights[idx].position.set(x, y, z);
      untyped lights[idx].intensity = RenderConfig.SHOT.lightIntensity;
      timers[idx] = RenderConfig.SHOT.lightMs;
    }

// decay every active light toward intensity 0
  public function update(dtMs:Float):Void
    {
      var S = RenderConfig.SHOT;
      for (i in 0...lights.length)
        {
          if (timers[i] <= 0)
            continue;
          timers[i] -= dtMs;
          var f = timers[i] / S.lightMs;
          untyped lights[i].intensity = f > 0 ? S.lightIntensity * f : 0;
        }
    }
}

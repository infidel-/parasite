package render.particles;

import three.Three;
import render.RenderConfig;

// one visible burning barrel handed to the flame passes: world rim position + a per-barrel flicker
// phase (so barrels flicker out of sync) + its grid cell (for player-distance gating)
typedef FlameBarrel = { x:Float, z:Float, floor:Float, col:Int, row:Int, phase:Float };

// a fixed pool of warm point lights for burning barrels — same discipline as MuzzleLights: created
// once, kept in the scene forever at intensity 0, never added/removed/hidden, so NUM_POINT_LIGHTS
// stays constant and three never recompiles the lit materials. each frame the nearest barrels to
// the player claim a light; the rest idle at 0. only built for low-tier cities (the only place
// barrels spawn), so no cost is added anywhere else
class FlameLights {
  var lights:Array<PointLight> = [];

  public function new(group:Group)
    {
      var F = RenderConfig.FLAME;
      // NOTE: never toggle .visible — an invisible light drops out of NUM_POINT_LIGHTS and forces
      // the very recompile this pool exists to avoid. idle == visible + intensity 0
      for (i in 0...F.lightPool)
        {
          var l = new PointLight(F.lightColor, 0, F.lightDistance, 1.6);
          group.add(l);
          lights.push(l);
        }
    }

// uneven flame flicker at time t (ms) with a per-barrel phase: two summed sines mapped to
// [flickMin, 1]. shared by the light, the flame body, and the embers so they pulse together
  public static inline function flicker(t:Float, phase:Float):Float
    {
      var F = RenderConfig.FLAME;
      var n = 0.5 * (Math.sin(t * F.flickFreqA + phase) + Math.sin(t * F.flickFreqB + phase * 1.7));
      return (1 + F.flickMin) * 0.5 + (1 - F.flickMin) * 0.5 * n;
    }

// park a pool light on each of the nearest barrels to the player (within lightRangeCells) and set
// its flickering intensity; every other pool light idles at 0. t is the shared flame clock (ms)
  public function update(t:Float, barrels:Array<FlameBarrel>, playerCol:Int, playerRow:Int):Void
    {
      var F = RenderConfig.FLAME;
      // reset the whole pool; the chosen barrels below light theirs back up this frame
      for (l in lights)
        untyped l.intensity = 0;
      if (barrels.length == 0)
        return;
      // pick the barrels within range, nearest the player first, capped to the pool size
      var range2 = F.lightRangeCells * F.lightRangeCells;
      var near:Array<FlameBarrel> = [];
      for (b in barrels)
        {
          var dc = b.col - playerCol;
          var dr = b.row - playerRow;
          if (dc * dc + dr * dr <= range2)
            near.push(b);
        }
      near.sort(function(a, b)
        {
          var da = (a.col - playerCol) * (a.col - playerCol) + (a.row - playerRow) * (a.row - playerRow);
          var db = (b.col - playerCol) * (b.col - playerCol) + (b.row - playerRow) * (b.row - playerRow);
          return da - db;
        });
      var n = near.length < lights.length ? near.length : lights.length;
      for (i in 0...n)
        {
          var b = near[i];
          lights[i].position.set(b.x, b.floor + F.rimY, b.z);
          untyped lights[i].intensity = F.lightIntensity * flicker(t, b.phase);
        }
    }
}

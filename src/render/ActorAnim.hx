package render;

import citygen.CityConfig;
import render.anim.Effect;

// per-actor 3D animation data + the shared position-slide helper. behavior lives in
// render.Actors; transient effects live in render.anim.*; StreetView reuses PosSlide +
// slideTo for the camera target.

// position channel: smoothstep slide toward a grid cell (also used for the camera)
typedef PosSlide = {
  col:Int, row:Int,          // last target grid cell
  fromX:Float, fromZ:Float,  // slide origin (world)
  x:Float, z:Float,          // current interpolated world pos
  t:Float                    // tween progress 0..1 (1 = settled)
};

// one animated billboard: position channel + opacity channel + optional transient effect
typedef Actor = {
  > PosSlide,
  op:Float, opTarget:Float,  // opacity channel: eased toward want-visible (1/0)
  fx:Effect                  // one-shot transient effect (render.anim.*), null = none
};

class ActorAnim {
// advance a position slide toward grid cell (col,row) by tween-progress `step`: a big
// jump (area entry, stairs) snaps, else it slides from where it is now. mutates+returns s
// (null => fresh settled slide at the cell). restarting mid-slide keeps motion continuous
  public static function slideTo(s:PosSlide, col:Int, row:Int, step:Float):PosSlide
    {
      var w = CityConfig.cellToWorld(col, row);
      if (s == null)
        return { col: col, row: row, fromX: w.x, fromZ: w.z, x: w.x, z: w.z, t: 1 };
      // cell changed: snap on a big jump, else start a fresh slide from the current pos
      if (col != s.col ||
          row != s.row)
        {
          var dx = w.x - s.x, dz = w.z - s.z;
          var lim = CityConfig.CELL * 1.9;
          if (dx * dx + dz * dz > lim * lim)
            { s.x = w.x; s.z = w.z; s.t = 1; }
          else
            { s.fromX = s.x; s.fromZ = s.z; s.t = 0; }
          s.col = col; s.row = row;
        }
      if (s.t < 1)
        {
          s.t = Math.min(1, s.t + step);
          var e = s.t * s.t * (3 - 2 * s.t); // smoothstep
          s.x = s.fromX + (w.x - s.fromX) * e;
          s.z = s.fromZ + (w.z - s.fromZ) * e;
        }
      return s;
    }
}

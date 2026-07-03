package render;

import citygen.CityConfig;

// per-actor 3D animation data + the shared position-slide helper. behavior lives in
// render.Actors; StreetView reuses PosSlide + slideTo for the camera target.

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
  fx:Anim                    // one-shot transient effect, null = none
};

// a transient one-shot effect layered on a billboard; advances t 0..1 then auto-clears.
// px,py,pz are a generic param (delta-to-target / direction / amplitude), meaning per kind
typedef Anim = {
  kind:AnimKind,
  t:Float, ms:Float,
  px:Float, py:Float, pz:Float
};

// effect kinds. add a case here + a branch in Actors.applyAnim to add an animation
enum AnimKind {
  POP;           // spawn bounce: scale small->overshoot->1 (no offset)
  JUMP_ON_FACE;  // parasite leap: horizontal lerp to (px,pz) + parabolic arc up (py = peak height)
  SHAKE;         // decaying positional jitter, amplitude py
  ATTACK_LUNGE;  // there-and-back toward (px,pz), zero at k=0 and k=1
}

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

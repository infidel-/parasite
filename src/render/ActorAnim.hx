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
  t:Float,                   // tween progress 0..1 (1 = settled)
  ?bx:Float, ?bz:Float       // optional L-path bend waypoint (world): set for a diagonal
                             // step past a building corner, null = straight slide
};

// one animated billboard: position channel + opacity channel + optional transient effect
typedef Actor = {
  > PosSlide,
  op:Float, opTarget:Float,  // opacity channel: eased toward want-visible (1/0)
  fx:Effect,                 // one-shot transient effect (render.anim.*), null = none
  face:Float                 // horizontal facing: +1 art default, -1 mirrored; eased on a turn
};

class ActorAnim {
// key a grid vertex V(a,b) (the +x/+z corner shared by cells (a,b)..(a+1,b+1)) into a Map
// int. offset by 1 because a lamp corner can land on a=-1/b=-1; shared by SceneSetup (build)
// and cornerBend (query) so both agree
  public static inline function lampVertexKey(a:Int, b:Int):Int
    return (a + 1) * (CityConfig.GRID + 2) + (b + 1);

// L-path bend for a one-step diagonal move from (fc,fr) to (tc,tr): if exactly one shoulder
// cell is a wall, returns the open shoulder to route the slide through; null = go straight.
// keeps the camera follow and the actor slide bending the same way past a building corner.
// lampCorners (vertex key -> lamp dir) additionally bends past a lamp post standing on the
// cut corner even when both shoulders are open — routing on the pavement side, away from the road
  public static function cornerBend(area:game.AreaGame, fc:Int, fr:Int, tc:Int, tr:Int, lampCorners:Map<Int,Int> = null):{ col:Int, row:Int }
    {
      var dc = tc - fc, dr = tr - fr;
      if (dc < -1 || dc > 1 ||
          dr < -1 || dr > 1 ||
          dc == 0 || dr == 0)
        return null;
      var hOpen = area.isWalkable(tc, fr); // move-col-first shoulder
      var vOpen = area.isWalkable(fc, tr); // move-row-first shoulder
      if (hOpen && !vOpen)
        return { col: tc, row: fr };
      if (vOpen && !hOpen)
        return { col: fc, row: tr };
      // both shoulders open: bend only if a lamp post sits on the corner this diagonal cuts
      if (hOpen && vOpen && lampCorners != null)
        {
          var dir = lampCorners.get(lampVertexKey(fc < tc ? fc : tc, fr < tr ? fr : tr));
          if (dir != null)
            // pick the shoulder stepping AWAY from the post's road (dir), so it rounds the
            // post on the sidewalk; both are walkable, so the choice is purely cosmetic
            return switch (dir)
              {
                case 0: fr < tr ? { col: tc, row: fr } : { col: fc, row: tr }; // road +row: lower row
                case 1: fr > tr ? { col: tc, row: fr } : { col: fc, row: tr }; // road -row: higher row
                case 2: tc < fc ? { col: tc, row: fr } : { col: fc, row: tr }; // road +col: lower col
                default: tc > fc ? { col: tc, row: fr } : { col: fc, row: tr }; // road -col: higher col
              };
        }
      return null;
    }

// advance a position slide toward grid cell (col,row) by tween-progress `step`: a big
// jump (area entry, stairs) snaps, else it slides from where it is now. mutates+returns s
// (null => fresh settled slide at the cell). restarting mid-slide keeps motion continuous.
// bendCol/bendRow (>=0) route a diagonal step through an intermediate cell as an L-path so
// the sprite doesn't cut across a building corner
  public static function slideTo(s:PosSlide, col:Int, row:Int, step:Float, bendCol:Int = -1, bendRow:Int = -1):PosSlide
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
            { s.x = w.x; s.z = w.z; s.t = 1; s.bx = null; }
          else
            {
              s.fromX = s.x; s.fromZ = s.z; s.t = 0;
              // arm the L-path bend for this slide (cleared for a straight move)
              if (bendCol >= 0)
                { var b = CityConfig.cellToWorld(bendCol, bendRow); s.bx = b.x; s.bz = b.z; }
              else s.bx = null;
            }
          s.col = col; s.row = row;
        }
      if (s.t < 1)
        {
          s.t = Math.min(1, s.t + step);
          var e = s.t * s.t * (3 - 2 * s.t); // smoothstep
          // bent slide: first half origin->bend, second half bend->target (two orthogonal legs)
          if (s.bx != null)
            {
              if (e < 0.5)
                {
                  var u = e / 0.5;
                  s.x = s.fromX + (s.bx - s.fromX) * u;
                  s.z = s.fromZ + (s.bz - s.fromZ) * u;
                }
              else
                {
                  var u = (e - 0.5) / 0.5;
                  s.x = s.bx + (w.x - s.bx) * u;
                  s.z = s.bz + (w.z - s.bz) * u;
                }
            }
          else
            {
              s.x = s.fromX + (w.x - s.fromX) * e;
              s.z = s.fromZ + (w.z - s.fromZ) * e;
            }
        }
      return s;
    }
}

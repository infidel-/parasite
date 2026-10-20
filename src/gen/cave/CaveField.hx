// the floor field the mountain cave's 3D outline is cut from
//
// render.cave.CaveGeom blurs the floor grid into this field and draws the rock where it falls under
// ISO. it lives under gen/ and not with the renderer for one reason: the oracle (gen.GenCheck.caveSane)
// asserts the invariant the whole cave shell rests on — the field stays above ISO on every walkable
// cell, so the player is never drawn standing under rock — and that check has to run headless

package gen.cave;

class CaveField
{
  // field samples per cell: the outline, the rock tops and the floor are all built on this lattice,
  // so it is also the polygon density of the whole shell (a sample every CELL / 4 = 1 world unit)
  public static inline var SAMPLES = 4;
  // half-width of the box the floor coverage is averaged over, in cells. the outline sits where that
  // average falls to ISO, which is ~0.23 cells into the rock along a straight wall, rounds every rock
  // corner off and keeps clear of the walkable floor everywhere: a floor cell's own quarter of the box
  // alone already reads 0.25
  public static inline var BLUR = 0.35;
  public static inline var ISO = 0.17;
  // lumpiness of the outline: smooth noise added to the field. pushing INTO the rock is free, so it is
  // the big term; pulling toward the floor is capped so the field on a floor cell (>= 0.25) never
  // drops under ISO (0.25 - 0.06 = 0.19)
  public static inline var LUMP_IN = 0.18;
  public static inline var LUMP_OUT = 0.06;
  // noise period, in cells
  public static inline var LUMP_PERIOD = 1.3;

// the floor coverage of the BLUR box round (u, v) in cells, plus the lumps. the push into the rock
// fades out where the coverage does, so an isolated pillar keeps its core
  public static function field(isFloor:(Int, Int) -> Bool, u:Float, v:Float):Float
    {
      var b = BLUR;
      var sum = 0.0;
      for (r in Math.floor(v - b)...Math.floor(v + b) + 1)
        for (c in Math.floor(u - b)...Math.floor(u + b) + 1)
          {
            if (!isFloor(c, r))
              continue;
            var ox = Math.min(u + b, c + 1) - Math.max(u - b, c);
            var oy = Math.min(v + b, r + 1) - Math.max(v - b, r);
            if (ox > 0 &&
                oy > 0)
              sum += ox * oy;
          }
      var f = sum / (4 * b * b);
      var n = noise(u / LUMP_PERIOD, v / LUMP_PERIOD, 0);
      return f + (n > 0 ?
        LUMP_IN * n * smooth(0, 0.3, f) :
        LUMP_OUT * n);
    }

// smooth value noise at (u, v), about -1..1, in the given slot k (each k its own pattern)
  public static function noise(u:Float, v:Float, k:Int):Float
    {
      var i = Math.floor(u);
      var j = Math.floor(v);
      var fu = u - i;
      var fv = v - j;
      var su = fu * fu * (3 - 2 * fu);
      var sv = fv * fv * (3 - 2 * fv);
      var a = hash(i, j, k);
      var b = hash(i + 1, j, k);
      var c = hash(i, j + 1, k);
      var e = hash(i + 1, j + 1, k);
      return (a + (b - a) * su) * (1 - sv) + (c + (e - c) * su) * sv;
    }

// a lattice value, -1..1. xorshift-mixed like render.sewer.SewerModel.mix, so it does not comb on row
// or column 0 where one term of the raw hash is zero
  static function hash(i:Int, j:Int, k:Int):Float
    {
      var x = ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) ^ 0x9E3779B9;
      x ^= x << 13;
      x ^= x >>> 17;
      x ^= x << 5;
      return ((x & 0x7fffffff) % 10000) / 5000.0 - 1.0;
    }

// smoothstep
  public static inline function smooth(a:Float, b:Float, x:Float):Float
    {
      var t = (x - a) / (b - a);
      t = (t < 0 ? 0 : t > 1 ? 1 : t);
      return t * t * (3 - 2 * t);
    }
}

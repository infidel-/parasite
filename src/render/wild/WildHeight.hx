package render.wild;

// the wilderness relief: ONE analytic height field, sampled by every builder out here and by the
// whole actor layer through render.world.WorldCtx.ground.
//
// two out-of-phase sine octaves — the same shape render.wild.WildGround.tint uses for its mottle,
// and continuous for the same reason: a chunk boundary cannot crack the way a lattice hash would.
// what matters more HERE is that it is closed-form differentiable, because the ground NORMAL comes
// out of the derivative rather than out of computeVertexNormals. that is not an optimisation, it is
// the only correct answer: the ground is emitted one mesh per render.Chunks.CELLS block, and
// computeVertexNormals on a block averages only the triangles THAT block holds — so every vertex on
// a block edge, missing its neighbours' faces, gets a normal that turns, and a lit seam runs down
// every chunk boundary in the area. an analytic normal is derived from the world position alone and
// cannot know a block exists.
//
// the FREQUENCIES: wavelengths of 72.8 and 29.0 world units, i.e. 18 and 7 cells. the ground lattice
// samples every CELL / WildStyle.SUB = 2 units, so the tighter octave still gets 14 samples per
// period — SUB does not have to rise for this, which is what the deferred SUB sweep was waiting on.
//
// the AMPLITUDES are a slope budget rather than a look, because slope is what every consumer pays
// for: a prop's downhill edge hangs by footprint * slope, and WorldCtx.floorY answers per CELL, so an
// actor's height is exact at its cell centre and steps as it crosses into the next one. measured over
// a 400x400 sample at RELIEF_AMP 1 — slope p50 0.110 / max 0.164 (9.3 degrees), per-cell step p50
// 0.272 / p95 0.545 against the curb step of 0.2 the city already takes, and 3.80 world units peak to
// trough, half a conifer. per-octave peak slope is amp * |k| (0.129 and 0.087); the two never fully
// agree, which is why the measured max is 0.164 and not their sum
class WildHeight
{
  // octave A — the landform: 72.8 units per period, peak slope 0.129
  static inline var A_AMP = 1.5;
  static inline var A_X = 0.071;
  static inline var A_Z = 0.049;
  // octave B — the roll on top of it: 29.0 units per period, peak slope 0.087. the two wavevectors
  // are deliberately not parallel, so neither the crests nor the troughs line up into ridges
  static inline var B_AMP = 0.4;
  static inline var B_X = 0.101;
  static inline var B_Z = -0.192;

  // world-space phase offset, so two wilderness areas are not the same landform. seeded off the area
  // ID, which is persisted, so an area keeps its own hills across every save and re-entry
  static var ox = 0.0;
  static var oz = 0.0;

// point the field at one area. called FIRST in WildArea.build, before anything samples it
  public static function use(areaID:Int):Void
    {
      var h = WildModel.mix(areaID * 374761393);
      ox = (h % 9973) * 0.1;
      oz = ((h >> 11) % 9973) * 0.1;
    }

// ground height at a world point
  public static function at(x:Float, z:Float):Float
    {
      return (Math.sin((x + ox) * A_X + (z + oz) * A_Z) * A_AMP +
        Math.sin((x + ox) * B_X + (z + oz) * B_Z) * B_AMP) * WildStyle.RELIEF_AMP;
    }

// d(height)/dx at a world point
  public static function gradX(x:Float, z:Float):Float
    {
      return (Math.cos((x + ox) * A_X + (z + oz) * A_Z) * A_AMP * A_X +
        Math.cos((x + ox) * B_X + (z + oz) * B_Z) * B_AMP * B_X) * WildStyle.RELIEF_AMP;
    }

// d(height)/dz at a world point
  public static function gradZ(x:Float, z:Float):Float
    {
      return (Math.cos((x + ox) * A_X + (z + oz) * A_Z) * A_AMP * A_Z +
        Math.cos((x + ox) * B_X + (z + oz) * B_Z) * B_AMP * B_Z) * WildStyle.RELIEF_AMP;
    }

// steepest slope at a world point, as a rise over run. this is what a prop's footprint is multiplied
// by to find how far its downhill edge hangs below its centre
  public static function slope(x:Float, z:Float):Float
    {
      var gx = gradX(x, z);
      var gz = gradZ(x, z);
      return Math.sqrt(gx * gx + gz * gz);
    }

// push the surface normal at a world point onto a normal buffer. the surface is y = h(x,z), so the
// normal is normalize(-dh/dx, 1, -dh/dz) — see the class header on why this is analytic and not
// computeVertexNormals
  public static function pushNormal(nor:Array<Float>, x:Float, z:Float):Void
    {
      var gx = gradX(x, z);
      var gz = gradZ(x, z);
      var inv = 1.0 / Math.sqrt(gx * gx + gz * gz + 1.0);
      nor.push(-gx * inv);
      nor.push(inv);
      nor.push(-gz * inv);
    }
}

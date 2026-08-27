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
// actor's height is exact at its cell centre and steps as it crosses into the next one. the master
// scale on all of it is render.wild.WildBand.reliefAmp, set per area off the terrain band the region
// map paints, so plains run at 0.30-0.60 and a mountainside at 1.00-1.80. measured over
// a 400x400 sample at amplitude 1 — slope p50 0.110 / max 0.164 (9.3 degrees), per-cell step p50
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

  // the graded highway corridor, in WORLD units, or off. see the grade() header
  static var roadOn = false;
  static var roadAlongX = false;  // the road runs east-west, so its centreline is a constant z
  static var roadC = 0.0;         // that centreline, on the PERPENDICULAR axis
  static var roadHalf = 0.0;      // half the road width: the field is fully replaced inside this
  static var roadRamp = 0.0;      // how far past it the grade blends back into the land

// point the field at one area. called FIRST in WildArea.build, before anything samples it.
//
// this CLEARS the corridor, and that is load-bearing rather than tidy: these statics are not reset by
// World or SewerArea (only WorldCtx.ground is), so an area with no highway would otherwise inherit the
// last one's, and grade a ribbon across ground that has no road on it
  public static function use(areaID:Int):Void
    {
      var h = WildModel.mix(areaID * 374761393);
      ox = (h % 9973) * 0.1;
      oz = ((h >> 11) % 9973) * 0.1;
      roadOn = false;
    }

// grade a highway corridor into the field. called from WildArea.build straight after use(), off the
// rect render.wild.WildModel recovered from the TILE_ROAD cells.
//
// a real road is level across its width and follows the land along its length, and that is exactly
// what removes the seam problem too: a flat ribbon meets flat ground at its shoulder, so nothing
// downstream needs a special case. the blend is
//
//   h = f + w * (g - f),  f = the field here, g = the field ON THE CENTRELINE, w = 1 inside the road
//
// and it has to be ANALYTIC in the derivatives as well, because the ground normal out here comes out
// of gradX/gradZ and never out of computeVertexNormals (see the class header). every consumer follows
// for free: the ground mesh, the patch overlays, the grass, WildProps.sit — whose `slope` drops to
// zero on the ribbon, so a shoulder prop seats itself with no new code — and the whole actor layer
// through WorldCtx.ground
  public static function grade(alongX:Bool, centre:Float, half:Float, ramp:Float):Void
    {
      roadOn = true;
      roadAlongX = alongX;
      roadC = centre;
      roadHalf = half;
      roadRamp = ramp;
    }

// ground height at a world point
  public static function at(x:Float, z:Float):Float
    {
      var f = field(x, z);
      if (!roadOn)
        return f;
      var w = blend(x, z);
      if (w <= 0.0)
        return f;
      return f + w * (centreline(x, z) - f);
    }

// d(height)/dx at a world point
  public static function gradX(x:Float, z:Float):Float
    {
      var g = fieldGradX(x, z);
      if (!roadOn)
        return g;
      var w = blend(x, z);
      if (w <= 0.0)
        return g;
      // an east-west road runs ALONG x, so the centreline sample still varies with x and the two
      // gradients simply blend. a north-south one has x as its perpendicular axis, which is where the
      // ramp's own derivative lands
      if (roadAlongX)
        return (1.0 - w) * g + w * fieldGradX(x, roadC);
      return (1.0 - w) * g + slopeOfBlend(x, z) * (centreline(x, z) - field(x, z));
    }

// d(height)/dz at a world point
  public static function gradZ(x:Float, z:Float):Float
    {
      var g = fieldGradZ(x, z);
      if (!roadOn)
        return g;
      var w = blend(x, z);
      if (w <= 0.0)
        return g;
      if (!roadAlongX)
        return (1.0 - w) * g + w * fieldGradZ(roadC, z);
      return (1.0 - w) * g + slopeOfBlend(x, z) * (centreline(x, z) - field(x, z));
    }

// the field sampled on the corridor's centreline: level across the road, following the land along it
  static inline function centreline(x:Float, z:Float):Float
    {
      return (roadAlongX ? field(x, roadC) : field(roadC, z));
    }

// how much the corridor owns this point: 1 on the asphalt, 0 past the ramp, smoothstepped between
  static inline function blend(x:Float, z:Float):Float
    {
      var d = Math.abs((roadAlongX ? z : x) - roadC);
      if (d <= roadHalf)
        return 1.0;
      if (d >= roadHalf + roadRamp)
        return 0.0;
      var t = (d - roadHalf) / roadRamp;
      return 1.0 - t * t * (3.0 - 2.0 * t);
    }

// d(blend)/d(perpendicular axis). the smoothstep's own derivative, 6t(1-t) over the ramp width, signed
// by which side of the centreline the point is on. zero on the road and zero past the ramp, which is
// what keeps the ribbon flat and the far field untouched
  static inline function slopeOfBlend(x:Float, z:Float):Float
    {
      var p = (roadAlongX ? z : x) - roadC;
      var d = Math.abs(p);
      if (d <= roadHalf ||
          d >= roadHalf + roadRamp)
        return 0.0;
      var t = (d - roadHalf) / roadRamp;
      return -6.0 * t * (1.0 - t) / roadRamp * (p < 0 ? -1.0 : 1.0);
    }

// the raw two-octave field, before any corridor
  static inline function field(x:Float, z:Float):Float
    {
      return (Math.sin((x + ox) * A_X + (z + oz) * A_Z) * A_AMP +
        Math.sin((x + ox) * B_X + (z + oz) * B_Z) * B_AMP) * WildBand.reliefAmp;
    }

// d(field)/dx
  static inline function fieldGradX(x:Float, z:Float):Float
    {
      return (Math.cos((x + ox) * A_X + (z + oz) * A_Z) * A_AMP * A_X +
        Math.cos((x + ox) * B_X + (z + oz) * B_Z) * B_AMP * B_X) * WildBand.reliefAmp;
    }

// d(field)/dz
  static inline function fieldGradZ(x:Float, z:Float):Float
    {
      return (Math.cos((x + ox) * A_X + (z + oz) * A_Z) * A_AMP * A_Z +
        Math.cos((x + ox) * B_X + (z + oz) * B_Z) * B_AMP * B_Z) * WildBand.reliefAmp;
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

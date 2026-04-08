// seeded terrain perlin helpers

package map;

class TerrainNoise
{
  static var GRADIENT_X = [1.0, -1.0, 0.0, 0.0, 0.70710678, -0.70710678, 0.70710678, -0.70710678];
  static var GRADIENT_Y = [0.0, 0.0, 1.0, -1.0, 0.70710678, 0.70710678, -0.70710678, -0.70710678];

// sample one seeded multi-octave perlin field in the range [-1, 1]
  public static function sampleFractal(seed: Int, x: Float, y: Float, octaves: Int,
      lacunarity: Float, gain: Float): Float
    {
      var value = 0.0;
      var amplitude = 1.0;
      var amplitudeSum = 0.0;
      var frequency = 1.0;

// accumulate a few normalized perlin octaves into one terrain field
      for (octave in 0...octaves)
        {
          value += samplePerlin(seed + octave * 1013, x * frequency, y * frequency) * amplitude;
          amplitudeSum += amplitude;
          frequency *= lacunarity;
          amplitude *= gain;
        }

      if (amplitudeSum <= 0.0)
        return 0.0;
      return clampFloat(value / amplitudeSum, -1.0, 1.0);
    }

// sample one seeded 2d perlin octave in the range [-1, 1]
  public static function samplePerlin(seed: Int, x: Float, y: Float): Float
    {
      var x0 = Std.int(Math.floor(x));
      var y0 = Std.int(Math.floor(y));
      var x1 = x0 + 1;
      var y1 = y0 + 1;
      var tx = x - x0;
      var ty = y - y0;
      var fx = getFade(tx);
      var fy = getFade(ty);
      var n00 = getGradientDot(seed, x0, y0, tx, ty);
      var n10 = getGradientDot(seed, x1, y0, tx - 1.0, ty);
      var n01 = getGradientDot(seed, x0, y1, tx, ty - 1.0);
      var n11 = getGradientDot(seed, x1, y1, tx - 1.0, ty - 1.0);
      var top = lerp(n00, n10, fx);
      var bottom = lerp(n01, n11, fx);
      return clampFloat(lerp(top, bottom, fy), -1.0, 1.0);
    }

// return one hashed gradient dot product for a lattice point
  static function getGradientDot(seed: Int, gridX: Int, gridY: Int, dx: Float, dy: Float): Float
    {
      var index = getHash(seed, gridX, gridY) & 7;
      return GRADIENT_X[index] * dx + GRADIENT_Y[index] * dy;
    }

// hash one 2d lattice coordinate into a stable 32-bit int
  static function getHash(seed: Int, x: Int, y: Int): Int
    {
      var h = seed;
      h ^= x * 374761393;
      h ^= y * 668265263;
      h = (h ^ (h >> 13)) * 1274126177;
      return h ^ (h >> 16);
    }

// return one eased interpolation factor for perlin noise
  static function getFade(t: Float): Float
    {
      var tt = clampFloat(t, 0.0, 1.0);
      return tt * tt * tt * (tt * (tt * 6.0 - 15.0) + 10.0);
    }

// linearly interpolate one float value
  static function lerp(a: Float, b: Float, t: Float): Float
    {
      return a + (b - a) * t;
    }

// clamp one float to the requested range
  static function clampFloat(v: Float, min: Float, max: Float): Float
    {
      return v < min ? min : (v > max ? max : v);
    }
}

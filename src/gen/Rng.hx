// seeded randomness for area generation
//
// the generator stream. `Std.random` is fine for a one-off roll but it cannot be replayed, and a
// generator you cannot replay is one you cannot test: tools/genrun.mjs exists to run the same seed
// twice and diff the two grids, which is only meaningful if every roll comes from here.
//
// mulberry32 IS citygen.CityGen's own generator, moved here verbatim rather than reimplemented —
// that class has shipped city layouts against this exact stream since it landed, so a second
// implementation with the same name and different arithmetic would be the worst possible outcome.
// CityGen.mulberry32 now delegates to this one and its layouts do not move.

package gen;

class Rng
{
  static inline function imul(a: Int, b: Int): Int
    return js.Syntax.code("Math.imul({0}, {1})", a, b);

// build a seeded 0..1 generator. the returned closure carries its own state, so two of them made
// from the same seed produce the same sequence and never interfere
  public static function mulberry32(seed: Int): Void -> Float
    {
      var a = seed;
      return function(): Float
        {
          a = a | 0;
          a = (a + 0x6D2B79F5) | 0;
          var t = imul(a ^ (a >>> 15), 1 | a);
          t = (t + imul(t ^ (t >>> 7), 61 | t)) ^ t;
          return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

// a fresh seed, for a generate() that was not handed one. traced by the caller so a bad layout can
// be reproduced from the log alone
  public static function seed(): Int
    return Std.random(0x7FFFFFFF);

// 0...n-1, the seeded replacement for Std.random(n)
  public static inline function int(rng: Void -> Float, n: Int): Int
    return Std.int(rng() * n);

// min...max inclusive
  public static inline function range(rng: Void -> Float, min: Int, max: Int): Int
    return min + Std.int(rng() * (max - min + 1));

// does a percentage roll pass? the seeded replacement for Std.random(100) < pct
  public static inline function chance(rng: Void -> Float, pct: Int): Bool
    return Std.int(rng() * 100) < pct;

// one element of a list, or null when it is empty. the empty case is real: several callers hand it
// a filtered candidate list that a small room can legitimately reduce to nothing
  public static function pick<T>(rng: Void -> Float, list: Array<T>): T
    {
      if (list.length == 0)
        return null;
      return list[Std.int(rng() * list.length)];
    }

// one element by integer weight, or null on an empty/zero-weight list. used by gen.Deco, where a
// decoration's weight is how often it should turn up against its siblings in the same slot
  public static function weighted<T>(rng: Void -> Float, list: Array<T>,
      weightOf: T -> Int): T
    {
      var total = 0;
      for (e in list)
        total += weightOf(e);
      if (total <= 0)
        return null;
      var roll = Std.int(rng() * total);
      for (e in list)
        {
          roll -= weightOf(e);
          if (roll < 0)
            return e;
        }
      return list[list.length - 1];
    }
}

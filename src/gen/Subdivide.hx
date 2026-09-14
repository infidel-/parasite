// recursive rect subdivision
//
// the arithmetic is citygen.CityGen.subdivide's ([:290-313]) with the city's leaf shapes taken out:
// an over-cap axis is forced to split, a big rect usually splits, the cut lands somewhere in the
// middle third-ish with a gap left between the two children, and the recursion stops on depth, on
// size, or on an early-leaf roll. That function has laid every city block the game ships, so this is
// a proven splitter rather than a new one — what is new is that it returns plain rects and so can
// divide a compound, a building or a room just as well as a city block.
//
// CityGen ITSELF IS NOT MIGRATED ONTO THIS, on purpose. Its leaf() draws floors, roof and facade
// from the same rng, so the split and the dressing are interleaved in one stream; pulling the split
// out would reorder those draws and move every city layout in every existing save. The duplication
// is deliberate and this comment is the reason.

package gen;

class Subdivide
{
// divide a rect into leaf rects. the returned nodes carry an empty kind — gen.Quota is what decides
// what each one becomes, because "how do I cut this space up" and "what goes in the pieces" are
// different questions and answering them together is what makes a generator unreadable
  public static function split(x1: Int, y1: Int, x2: Int, y2: Int,
      p: _SplitProfile, rng: Void -> Float): Array<_GenNode>
    {
      var out = [];
      cut(x1, y1, x2, y2, p.depth, true, p, rng, out);
      return out;
    }

// one step of the recursion: leaf, or cut along one axis and recurse into both halves
  static function cut(x1: Int, y1: Int, x2: Int, y2: Int, depth: Int, whole: Bool,
      p: _SplitProfile, rng: Void -> Float, out: Array<_GenNode>)
    {
      var w = x2 - x1 + 1;
      var h = y2 - y1 + 1;
      // the smallest rect that can be cut at all: two children of minSide with the gap between them
      var splittable = p.minSide * 2 + p.gap;
      var capW = (w > p.maxSide);
      var capH = (h > p.maxSide);
      var big = (w > p.splitOver || h > p.splitOver);
      // a rect far longer than it is wide is a sliver, and a sliver is not a plot. keep cutting its
      // LONG axis even when every other rule says stop — the split branch below always shortens the
      // long side, so this terminates
      var long = (w > h ? w : h);
      var short = (w < h ? w : h);
      var thin = (short > 0 && long > short * p.maxAspect);

      // stop, unless an axis is over cap or the rect is a sliver: those two override every reason
      // to stop, which is what keeps a leaf inside the caller's size contract
      if (!capW &&
          !capH &&
          !thin &&
          (depth <= 0 ||
           (w < splittable && h < splittable) ||
           (!whole && !big && rng() < p.earlyLeafChance)))
        {
          leaf(x1, y1, x2, y2, out);
          return;
        }

      // cut the wider axis first, unless the other one is the one over cap
      // `at` is the LAST cell of the near child, so that child is minSide + r wide and the far one
      // is w - minSide - gap - r. Both hit exactly minSide at their end of the range, which is why
      // the -1 is there: without it the near child starts at minSide + 1 and the far one bottoms out
      // at minSide - 1, and an undersized leaf is a plot nothing will fit in.
      // (citygen.CityGen has this same off-by-one and lives with it — its own comment notes a 10x15
      // block can leave a 2x15 sliver — because its `thin` guard cleans up after it downtown)
      if (capW ||
          (!capH && w >= h && w >= splittable))
        {
          var at = x1 + p.minSide - 1 + Std.int(rng() * (w - splittable + 1));
          cut(x1, y1, at, y2, depth - 1, false, p, rng, out);
          cut(at + 1 + p.gap, y1, x2, y2, depth - 1, false, p, rng, out);
        }
      else if (capH ||
          h >= splittable)
        {
          var at = y1 + p.minSide - 1 + Std.int(rng() * (h - splittable + 1));
          cut(x1, y1, x2, at, depth - 1, false, p, rng, out);
          cut(x1, at + 1 + p.gap, x2, y2, depth - 1, false, p, rng, out);
        }
      else leaf(x1, y1, x2, y2, out);
    }

// emit one finished rect. a degenerate one is dropped rather than emitted: the cut arithmetic cannot
// produce one from a legal profile, but a caller passing a rect smaller than minSide can, and a
// zero-width block downstream is a crash a long way from its cause
  static inline function leaf(x1: Int, y1: Int, x2: Int, y2: Int, out: Array<_GenNode>)
    {
      if (x2 >= x1 &&
          y2 >= y1)
        out.push(GenTree.root('', x1, y1, x2, y2));
    }
}

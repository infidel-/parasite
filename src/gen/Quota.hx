// deal block kinds onto the rects a split produced
//
// the rule is REQUIRED FIRST. Every demand's `min` is satisfied before any demand's `max` gets a
// look in, and within that, the demand with the fewest legal homes picks first — a hangar that fits
// in exactly one of six rects must not lose that rect to a park that would have been happy anywhere.
// That ordering is the whole algorithm; it is most-constrained-first, and on the handful of blocks
// an area splits into it finds an assignment whenever one exists.
//
// what it is NOT is a solver. There is no backtracking: if a greedy pass cannot satisfy a min it
// says so and returns what it has, rather than searching. The caller's answer to that is to re-split
// with a different seed, which is how gen.lab.LabPlan handles an unsatisfiable layout (it draws up
// to 30 candidates) and costs nothing at this size.

package gen;

class Quota
{
// assign a kind to each rect. returns the rects that were dealt something, with their `kind` set;
// anything left over is given `filler` and returned too, so the caller always gets every cell of the
// area accounted for and never has to work out what was not used
  public static function deal(blocks: Array<_GenNode>, demands: Array<_GenDemand>,
      filler: String, rng: Void -> Float): Array<_GenNode>
    {
      var free = blocks.copy();
      var dealt = new Map<String, Int>();
      for (d in demands)
        dealt.set(d.kind, 0);

      // pass 1: every min, most-constrained demand first
      var pending = [for (d in demands) if (d.min > 0) d];
      while (pending.length > 0)
        {
          // re-sorted every round, because dealing one block changes how constrained the rest are
          pending.sort(function(a, b)
            return homes(free, a).length - homes(free, b).length);
          var d = pending[0];
          var block = best(free, d, rng);
          // no rect left that this demand fits in. SILENT, because the caller's answer is to
          // re-split with another seed and it would otherwise log once per discarded attempt —
          // ask `satisfied` afterwards to find out
          if (block == null)
            {
              pending.remove(d);
              continue;
            }
          block.kind = d.kind;
          free.remove(block);
          dealt.set(d.kind, dealt.get(d.kind) + 1);
          if (dealt.get(d.kind) >= d.min)
            pending.remove(d);
        }

      // pass 2: spend what is left up to each max, best fit first, so a leftover rect that really
      // suits a second building becomes one instead of becoming yard
      for (d in demands)
        {
          while (dealt.get(d.kind) < d.max)
            {
              var block = best(free, d, rng);
              if (block == null)
                break;
              block.kind = d.kind;
              free.remove(block);
              dealt.set(d.kind, dealt.get(d.kind) + 1);
            }
        }

      // and everything still unclaimed is the filler kind. the facility's yard is exactly this: the
      // space between the structures, which used to be whatever the grid happened to be left at
      for (block in free)
        block.kind = filler;
      return blocks;
    }

// the blocks this demand could legally take: big enough, and accepted by its `must` if it has one
  static function homes(free: Array<_GenNode>, d: _GenDemand): Array<_GenNode>
    {
      return [for (b in free)
        if (GenTree.width(b) >= d.minW &&
            GenTree.height(b) >= d.minH &&
            (d.must == null || d.must(b))) b];
    }

// the block that suits this demand best, or null if none fits. ties on `fit` break on area, so the
// runner-up rule is "take the roomiest", and a demand with no fit function is pure roomiest-first
  static function best(free: Array<_GenNode>, d: _GenDemand, rng: Void -> Float): _GenNode
    {
      var cand = homes(free, d);
      if (cand.length == 0)
        return null;
      var bestBlock = null;
      var bestScore = 0;
      var bestArea = 0;
      for (b in cand)
        {
          var score = (d.fit != null ? d.fit(b) : 0);
          var area = GenTree.width(b) * GenTree.height(b);
          if (bestBlock == null ||
              score > bestScore ||
              (score == bestScore && area > bestArea))
            {
              bestBlock = b;
              bestScore = score;
              bestArea = area;
            }
        }
      return bestBlock;
    }

// did this deal meet every min? the question a caller asks between attempts — a split that cannot
// house everything is thrown away and re-rolled rather than repaired
  public static function satisfied(blocks: Array<_GenNode>, demands: Array<_GenDemand>): Bool
    {
      for (d in demands)
        if (count(blocks, d.kind) < d.min)
          return false;
      return true;
    }

// how many blocks of each kind a deal produced. what tools/genrun.mjs asserts the quota against,
// and what a filler asks when it wants to know whether it is the only one of its kind
  public static function count(blocks: Array<_GenNode>, kind: String): Int
    {
      var n = 0;
      for (b in blocks)
        if (b.kind == kind)
          n++;
      return n;
    }
}

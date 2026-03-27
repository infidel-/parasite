// simple deterministic random generator used by the map pipeline

package map;

class SeededRandom
{
  var seed: Int;

  public function new(seed: Int)
    {
      this.seed = seed;
    }

// return the next deterministic int
  public function next(): Int
    {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return seed >> 8;
    }

// return the next deterministic float
  public function nextFloat(): Float
    {
      return next() / 8388607.0;
    }
}

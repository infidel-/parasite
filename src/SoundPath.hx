import game.AreaGame;
import objects.Door;

// how far a sound travels to the listener: the PATH distance through cells that pass sound, searched
// in a window around the listener — so a wall or a closed door between them is no way at all, and an
// open doorway round a corner lets it through at the length of the way round. render.corp.CorpSounds
// drives its loops off it every frame; Sounds.playNow asks it once per positional one-shot
class SoundPath
{
  static inline var FAR = 1e9;
  // what a sound with no way round keeps of its straight-line level: -18 dB, through the wall
  public static inline var MUFFLE = 0.126;

  // the window's half-size in cells: the longest distance anything is heard at
  public var r(default, null):Int;
  var area:AreaGame;
  // the area's doors by cell (row * area width + col)
  var doors:Map<Int, Door>;
  // path distance per window cell, the listener at the centre
  var dist:Array<Float>;
  // the listener's cell, from the last search
  var pc:Int;
  var pr:Int;

  public function new(r:Int)
    {
      this.r = r;
      dist = [for (_ in 0...(2 * r + 1) * (2 * r + 1)) FAR];
    }

// an area's doors by cell: a door object never moves, only opens, so a caller that searches every
// frame builds this once per area
  public static function doorsOf(area:AreaGame):Map<Int, Door>
    {
      var out = new Map();
      for (o in area.getObjects())
        if (o.type == 'door')
          out[o.y * area.width + o.x] = cast(o, Door);
      return out;
    }

// does sound pass this cell: see-through masonry (glass included) with no CLOSED door in it.
// a glass door is see-through shut, which is why the door is asked on its own
  public function passes(col:Int, row:Int):Bool
    {
      if (!area.canSeeThrough(col, row))
        return false;
      var d = doors[row * area.width + col];
      return (d == null || d.isOpen);
    }

// fill the window with the path distance from the listener's cell (pc,pr): 8-way, a diagonal 1.41
// and never cut past a blocked corner, pruned at r
  public function search(area:AreaGame, doors:Map<Int, Door>, pc:Int, pr:Int):Void
    {
      this.area = area;
      this.doors = doors;
      this.pc = pc;
      this.pr = pr;
      var n = 2 * r + 1;
      for (i in 0...dist.length)
        dist[i] = FAR;
      dist[r * n + r] = 0;
      var queue = [r * n + r];
      var qi = 0;
      while (qi < queue.length)
        {
          var i = queue[qi];
          qi++;
          var lc = i % n;
          var lr = Std.int(i / n);
          for (dr in -1...2)
            for (dc in -1...2)
              {
                var c = lc + dc;
                var rr = lr + dr;
                if ((dc == 0 && dr == 0) ||
                    c < 0 ||
                    rr < 0 ||
                    c >= n ||
                    rr >= n ||
                    !passes(pc - r + c, pr - r + rr))
                  continue;
                // a diagonal needs both of its orthogonal cells open, or it slips through a wall corner
                if (dc != 0 &&
                    dr != 0 &&
                    (!passes(pc - r + lc + dc, pr - r + lr) ||
                    !passes(pc - r + lc, pr - r + lr + dr)))
                  continue;
                var d = dist[i] + (dc != 0 && dr != 0 ? 1.4142 : 1.0);
                if (d > r ||
                    d >= dist[rr * n + c])
                  continue;
                dist[rr * n + c] = d;
                queue.push(rr * n + c);
              }
        }
    }

// path distance, after a search, to a source's FACE: its own cell when sound passes it (a cooler,
// a doorway with the door open — the listener can stand there), else the passable cells around it
// (a rack, a vent in a wall, a shut door: the floor in front of it is as close as anyone gets).
// either way the nearest point is 0; FAR when there is no way within r
  public function reach(col:Int, row:Int):Float
    {
      var n = 2 * r + 1;
      var own = passes(col, row);
      var best = FAR;
      for (dr in -1...2)
        for (dc in -1...2)
          {
            var c = col + dc - pc + r;
            var rr = row + dr - pr + r;
            if ((own && (dc != 0 || dr != 0)) ||
                c < 0 ||
                rr < 0 ||
                c >= n ||
                rr >= n)
              continue;
            if (dist[rr * n + c] < best)
              best = dist[rr * n + c];
          }
      return best;
    }

// a one-shot's level at (col,row), 0..1, after a search: linear over the way round when there is
// one, else the straight line through the wall at MUFFLE, and nothing past r either way
  public function level(col:Int, row:Int):Float
    {
      var d = reach(col, row);
      if (d < r)
        return 1 - d / r;
      var e = Math.sqrt((col - pc) * (col - pc) + (row - pr) * (row - pr));
      return (e < r ? (1 - e / r) * MUFFLE : 0);
    }
}

// mountain cave habitat generation
//
// a cellular-automata cave on the habitat grid: random rock smoothed into rounded chambers and
// winding passages, every pocket joined to the main cave, then the two shapes the 3D shell cannot
// draw cut away — a dead-end nub, and two floor cells touching only at a corner. Runs on a GenCtx
// with no Game, so `make gen args="--type cave"` checks it headless; every roll comes off ctx.
//
// the cave keeps the sewer tileset ids (gen.SewerShell), so walkability, sight and everything else
// that reads a habitat grid work unchanged. what makes it a cave is the shape and the renderer

package gen.cave;

import gen.GenCtx;
import gen.SewerShell;

class CaveGen
{
  // the cave grid. a habitat is created at the sewer habitat's 21x14 (game.AreaGame.setType) and
  // resized to this the first time it is generated, once it is known to stand on a mountain
  public static inline var WIDTH = 24;
  public static inline var HEIGHT = 18;
  // starting rock fill, percent
  static inline var ROCK_PCT = 46;
  // the floor share of the interior a cave is accepted at, percent
  public static inline var FLOOR_MIN = 38;
  public static inline var FLOOR_MAX = 58;
  // floor pockets smaller than this are filled instead of joined
  static inline var MIN_REGION = 6;
  // chambers: all-floor rects at least CHAMBER_MIN a side, grown to at most CHAMBER_MAX
  public static inline var CHAMBER_MIN = 3;
  static inline var CHAMBER_MAX = 7;
  public static inline var MAX_CHAMBERS = 4;
  // the two mouths are at least this far apart by walking
  public static inline var MOUTH_APART = 6;
  // a mouth this close to the grid edge behind it reads as leading out, and is preferred
  static inline var MOUTH_DEPTH = 3;
  // re-rolls before the last attempt is kept as it is
  public static inline var MAX_TRIES = 40;

// build one cave into ctx: the floor, the sewer shell over it, two cave mouths and the chambers
  public static function build(ctx: GenCtx): _CaveState
    {
      var w = ctx.width;
      var h = ctx.height;
      var floor: Array<Array<Bool>> = null;
      var rooms: Array<_Room> = null;
      var exits: Array<{ x: Int, y: Int }> = null;
      var tries = 0;
      // ponytail: the last roll is kept even when it fails; the oracle measures how often that is
      while (tries < MAX_TRIES)
        {
          tries++;
          floor = roll(ctx, w, h);
          smooth(floor, w, h, 4, true);
          smooth(floor, w, h, 2, false);
          connect(ctx, floor, w, h);
          clean(floor, w, h);
          rooms = chambers(ctx, floor, w, h);
          exits = mouths(ctx, floor, w, h);
          var pct = floorPct(floor, w, h);
          if (pct >= FLOOR_MIN &&
              pct <= FLOOR_MAX &&
              rooms.length > 0 &&
              exits.length == 2)
            break;
        }

      // carve the floor as walkway markers and lay the shell over it
      for (x in 0...w)
        for (y in 0...h)
          ctx.cells[x][y] = (floor[x][y] ? Const.TILE_WALKWAY : Const.TILE_WALL);
      SewerShell.finalize(ctx.cells, w, h);
      for (e in exits)
        ctx.add('caveMouth', e.x, e.y);
      return {
        rooms: rooms,
        exits: exits,
        tries: tries,
      };
    }

// random fill: the border is always rock, the interior rock at ROCK_PCT
  static function roll(ctx: GenCtx, w: Int, h: Int): Array<Array<Bool>>
    {
      return [for (x in 0...w) [for (y in 0...h)
        (x > 0 &&
         y > 0 &&
         x < w - 1 &&
         y < h - 1 &&
         !ctx.chance(ROCK_PCT))]];
    }

// cellular-automata passes: rock where 5+ of the 3x3 is rock, and (wide) also where the 5x5 is
// nearly empty, which breaks up the big open floors the first rule alone leaves
  static function smooth(floor: Array<Array<Bool>>, w: Int, h: Int, passes: Int, wide: Bool)
    {
      for (_ in 0...passes)
        {
          var next = [for (x in 0...w) [for (y in 0...h) false]];
          for (x in 1...w - 1)
            for (y in 1...h - 1)
              {
                var rock = (rockAround(floor, w, h, x, y, 1) >= 5 ||
                  (wide &&
                   rockAround(floor, w, h, x, y, 2) <= 2));
                next[x][y] = !rock;
              }
          for (x in 0...w)
            for (y in 0...h)
              floor[x][y] = next[x][y];
        }
    }

// rock cells in the square of radius r round x,y, the cell itself included; outside counts as rock
  static function rockAround(floor: Array<Array<Bool>>, w: Int, h: Int, x: Int, y: Int, r: Int): Int
    {
      var n = 0;
      for (dx in -r...r + 1)
        for (dy in -r...r + 1)
          {
            var xx = x + dx;
            var yy = y + dy;
            if (xx < 0 ||
                yy < 0 ||
                xx >= w ||
                yy >= h ||
                !floor[xx][yy])
              n++;
          }
      return n;
    }

// 4-connected floor regions, largest first. a cell is keyed y * w + x
  public static function regions(floor: Array<Array<Bool>>, w: Int, h: Int): Array<Array<Int>>
    {
      var seen = [for (x in 0...w) [for (y in 0...h) false]];
      var list = [];
      for (y in 0...h)
        for (x in 0...w)
          {
            if (!floor[x][y] ||
                seen[x][y])
              continue;
            var cells = [];
            var stack = [ y * w + x ];
            seen[x][y] = true;
            while (stack.length > 0)
              {
                var k = stack.pop();
                cells.push(k);
                var cx = k % w;
                var cy = Std.int(k / w);
                for (i in 0...4)
                  {
                    var nx = cx + DX[i];
                    var ny = cy + DY[i];
                    if (nx < 0 ||
                        ny < 0 ||
                        nx >= w ||
                        ny >= h ||
                        !floor[nx][ny] ||
                        seen[nx][ny])
                      continue;
                    seen[nx][ny] = true;
                    stack.push(ny * w + nx);
                  }
              }
            list.push(cells);
          }
      list.sort(function(a, b) return b.length - a.length);
      return list;
    }

// fill the small pockets and join every other region to the main cave with a 2-wide L passage
// from its nearest cell
  static function connect(ctx: GenCtx, floor: Array<Array<Bool>>, w: Int, h: Int)
    {
      while (true)
        {
          var list = regions(floor, w, h);
          // the smallest regions sit at the end
          while (list.length > 1 &&
              list[list.length - 1].length < MIN_REGION)
            {
              for (k in list.pop())
                floor[k % w][Std.int(k / w)] = false;
            }
          if (list.length <= 1)
            return;

          // the nearest pair between the main cave and the second-largest region
          var main = list[0];
          var other = list[1];
          var best = -1;
          var ax = 0;
          var ay = 0;
          var bx = 0;
          var by = 0;
          for (a in other)
            for (b in main)
              {
                var d = Std.int(Math.abs(a % w - b % w) + Math.abs(Std.int(a / w) - Std.int(b / w)));
                if (best >= 0 &&
                    d >= best)
                  continue;
                best = d;
                ax = a % w;
                ay = Std.int(a / w);
                bx = b % w;
                by = Std.int(b / w);
              }
          carveL(ctx, floor, w, h, ax, ay, bx, by);
        }
    }

// carve a 2-wide L from a to b, the bend taken either way
  static function carveL(ctx: GenCtx, floor: Array<Array<Bool>>, w: Int, h: Int,
      ax: Int, ay: Int, bx: Int, by: Int)
    {
      var horizontalFirst = ctx.chance(50);
      var mx = (horizontalFirst ? bx : ax);
      var my = (horizontalFirst ? ay : by);
      carveLine(floor, w, h, ax, ay, mx, my);
      carveLine(floor, w, h, mx, my, bx, by);
    }

// carve a straight 2-wide run between two cells on one row or column, kept off the border
  static function carveLine(floor: Array<Array<Bool>>, w: Int, h: Int,
      x1: Int, y1: Int, x2: Int, y2: Int)
    {
      var sx = (x2 > x1 ? 1 : x2 < x1 ? -1 : 0);
      var sy = (y2 > y1 ? 1 : y2 < y1 ? -1 : 0);
      var x = x1;
      var y = y1;
      while (true)
        {
          carveCell(floor, w, h, x, y);
          // the second lane runs beside the first, across the direction of travel
          if (sx != 0)
            carveCell(floor, w, h, x, y + 1);
          else carveCell(floor, w, h, x + 1, y);
          if (x == x2 &&
              y == y2)
            break;
          x += sx;
          y += sy;
        }
    }

// make one interior cell floor (the border stays rock)
  static inline function carveCell(floor: Array<Array<Bool>>, w: Int, h: Int, x: Int, y: Int)
    {
      if (x > 0 &&
          y > 0 &&
          x < w - 1 &&
          y < h - 1)
        floor[x][y] = true;
    }

// cut away what the 3D shell cannot draw, until nothing changes: a floor nub with rock on three
// sides is filled, and two floor cells touching only at a corner get one of the rock cells between
// them opened. filling a nub never disconnects anything (it has one floor neighbour) and opening a
// corner only joins, so a connected cave stays connected
  static function clean(floor: Array<Array<Bool>>, w: Int, h: Int)
    {
      var changed = true;
      var guard = 0;
      while (changed &&
          guard < 100)
        {
          changed = false;
          guard++;
          for (x in 1...w - 1)
            for (y in 1...h - 1)
              if (floor[x][y] &&
                  rockSides(floor, x, y) >= 3)
                {
                  floor[x][y] = false;
                  changed = true;
                }
          for (x in 1...w - 2)
            for (y in 1...h - 2)
              {
                var a = floor[x][y];
                var b = floor[x + 1][y];
                var c = floor[x][y + 1];
                var d = floor[x + 1][y + 1];
                if (a &&
                    d &&
                    !b &&
                    !c)
                  {
                    floor[x + 1][y] = true;
                    changed = true;
                  }
                else if (b &&
                    c &&
                    !a &&
                    !d)
                  {
                    floor[x][y] = true;
                    changed = true;
                  }
              }
        }
    }

// rock cells among the four sides of x,y
  public static inline function rockSides(floor: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      return (floor[x - 1][y] ? 0 : 1) +
        (floor[x + 1][y] ? 0 : 1) +
        (floor[x][y - 1] ? 0 : 1) +
        (floor[x][y + 1] ? 0 : 1);
    }

// the floor share of the interior, percent
  public static function floorPct(floor: Array<Array<Bool>>, w: Int, h: Int): Int
    {
      var n = 0;
      for (x in 1...w - 1)
        for (y in 1...h - 1)
          if (floor[x][y])
            n++;
      return Std.int(100 * n / ((w - 2) * (h - 2)));
    }

// the chambers: from the most open floor cells outward, each the 3x3 round a cell with floor on all
// eight sides, grown a side at a time while the new row or column is all floor and clear of the
// chambers already taken
  static function chambers(ctx: GenCtx, floor: Array<Array<Bool>>, w: Int, h: Int): Array<_Room>
    {
      // seeds scored by the floor in their 5x5, ties broken off the stream so equal ones vary
      var seeds = [];
      for (x in 2...w - 2)
        for (y in 2...h - 2)
          if (rockAround(floor, w, h, x, y, 1) == 0)
            seeds.push({
              x: x,
              y: y,
              score: (25 - rockAround(floor, w, h, x, y, 2)) * 1000 + ctx.random(1000),
            });
      seeds.sort(function(a, b) return b.score - a.score);

      var rooms: Array<_Room> = [];
      for (s in seeds)
        {
          if (rooms.length >= MAX_CHAMBERS)
            break;
          var r = {
            x1: s.x - 1,
            y1: s.y - 1,
            x2: s.x + 1,
            y2: s.y + 1,
          };
          if (overlapsAny(rooms, r.x1, r.y1, r.x2, r.y2))
            continue;
          var grew = true;
          while (grew)
            {
              grew = false;
              if (r.y2 - r.y1 + 1 < CHAMBER_MAX &&
                  rowClear(floor, rooms, r.x1, r.x2, r.y1 - 1))
                {
                  r.y1--;
                  grew = true;
                }
              if (r.y2 - r.y1 + 1 < CHAMBER_MAX &&
                  rowClear(floor, rooms, r.x1, r.x2, r.y2 + 1))
                {
                  r.y2++;
                  grew = true;
                }
              if (r.x2 - r.x1 + 1 < CHAMBER_MAX &&
                  colClear(floor, rooms, r.x1 - 1, r.y1, r.y2))
                {
                  r.x1--;
                  grew = true;
                }
              if (r.x2 - r.x1 + 1 < CHAMBER_MAX &&
                  colClear(floor, rooms, r.x2 + 1, r.y1, r.y2))
                {
                  r.x2++;
                  grew = true;
                }
            }
          rooms.push({
            id: rooms.length,
            x1: r.x1,
            y1: r.y1,
            x2: r.x2,
            y2: r.y2,
            w: r.x2 - r.x1 + 1,
            h: r.y2 - r.y1 + 1,
            role: 'chamber',
          });
        }
      return rooms;
    }

// is this row segment all floor and clear of every chamber (floor is false on the rock border, so
// a chamber can never grow onto it)
  static function rowClear(floor: Array<Array<Bool>>, rooms: Array<_Room>,
      x1: Int, x2: Int, y: Int): Bool
    {
      for (x in x1...x2 + 1)
        if (!floor[x][y])
          return false;
      return !overlapsAny(rooms, x1, y, x2, y);
    }

// is this column segment all floor and clear of every chamber
  static function colClear(floor: Array<Array<Bool>>, rooms: Array<_Room>,
      x: Int, y1: Int, y2: Int): Bool
    {
      for (y in y1...y2 + 1)
        if (!floor[x][y])
          return false;
      return !overlapsAny(rooms, x, y1, x, y2);
    }

// does the rect touch any chamber
  static function overlapsAny(rooms: Array<_Room>, x1: Int, y1: Int, x2: Int, y2: Int): Bool
    {
      for (r in rooms)
        if (x1 <= r.x2 &&
            x2 >= r.x1 &&
            y1 <= r.y2 &&
            y2 >= r.y1)
          return true;
      return false;
    }

// the two cave mouths: floor cells backed by a straight run of three rock north, west or east (never
// south: the camera looks north, so a south mouth would face away behind its own rock) with floor
// on both sides along that wall. a mouth leads OUT, so spots whose rock is a thin skin to the grid
// edge are taken when there are any. the first is any of them, the second the one farthest from it
// on foot, and only if that is at least MOUTH_APART away
  static function mouths(ctx: GenCtx, floor: Array<Array<Bool>>, w: Int, h: Int): Array<{ x: Int, y: Int }>
    {
      var spots = [];
      var outer = [];
      for (x in 1...w - 1)
        for (y in 1...h - 1)
          {
            var side = mouthSide(floor, x, y);
            if (side < 0)
              continue;
            var spot = {
              x: x,
              y: y,
            };
            spots.push(spot);
            // cells from the mouth to the grid edge behind it
            var depth = (side == 0 ? y : side == 1 ? x : w - 1 - x);
            if (depth <= MOUTH_DEPTH)
              outer.push(spot);
          }
      if (outer.length >= 2)
        spots = outer;
      if (spots.length == 0)
        return [];
      var first = spots[ctx.random(spots.length)];
      var dist = walkDistances(floor, w, h, first.x, first.y);
      var second = null;
      var far = MOUTH_APART - 1;
      for (s in spots)
        if (dist[s.x][s.y] > far)
          {
            far = dist[s.x][s.y];
            second = s;
          }
      return (second == null ? [ first ] : [ first, second ]);
    }

// which side a cave mouth on x,y backs onto: 0 north, 1 west, 2 east, -1 when it can stand there at
// all. shared with the oracle, which re-checks every mouth against the finished grid
  public static function mouthSide(floor: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      if (!floor[x][y])
        return -1;
      if (!floor[x - 1][y - 1] &&
          !floor[x][y - 1] &&
          !floor[x + 1][y - 1] &&
          floor[x - 1][y] &&
          floor[x + 1][y])
        return 0;
      if (!floor[x - 1][y - 1] &&
          !floor[x - 1][y] &&
          !floor[x - 1][y + 1] &&
          floor[x][y - 1] &&
          floor[x][y + 1])
        return 1;
      if (!floor[x + 1][y - 1] &&
          !floor[x + 1][y] &&
          !floor[x + 1][y + 1] &&
          floor[x][y - 1] &&
          floor[x][y + 1])
        return 2;
      return -1;
    }

// steps from x,y to every floor cell on foot (4-connected), -1 where it cannot be reached
  public static function walkDistances(floor: Array<Array<Bool>>, w: Int, h: Int,
      x: Int, y: Int): Array<Array<Int>>
    {
      var dist = [for (xx in 0...w) [for (yy in 0...h) -1]];
      dist[x][y] = 0;
      var queue = [ y * w + x ];
      var head = 0;
      while (head < queue.length)
        {
          var k = queue[head++];
          var cx = k % w;
          var cy = Std.int(k / w);
          for (i in 0...4)
            {
              var nx = cx + DX[i];
              var ny = cy + DY[i];
              if (nx < 0 ||
                  ny < 0 ||
                  nx >= w ||
                  ny >= h ||
                  !floor[nx][ny] ||
                  dist[nx][ny] >= 0)
                continue;
              dist[nx][ny] = dist[cx][cy] + 1;
              queue.push(ny * w + nx);
            }
        }
      return dist;
    }

  static var DX = [ 0, 0, -1, 1 ];
  static var DY = [ -1, 1, 0, 0 ];
}

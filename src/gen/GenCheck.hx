// structural assertions over a generated area
//
// THE ORACLE. Every one of these is a property the game reads back out of a generated area and
// crashes, or silently loses a feature, when it does not hold — and every one of them is cheap to
// check here and expensive to notice in the running game, where it means launching Electron,
// loading a save, walking to the far side of a compound and looking.
//
// run from tools/genrun.mjs over hundreds of seeds. A check names the invariant and the seed that
// broke it; it never repairs anything.

package gen;

class GenCheck
{
  // how wide a walkway run the park-path test will still cross. render.facility.FacilityModel
  // .PATH_MAX, and it has to stay the same number — this asserts the thing that file will find
  public static inline var PATH_MAX = 4;

  public var failures: Array<String>;
  var seed: Int;

  public function new(vseed: Int)
    {
      seed = vseed;
      failures = [];
    }

// record one failed invariant
  public function fail(what: String)
    failures.push('seed ' + seed + ': ' + what);

// assert, with the message only built when it actually failed
  public inline function ok(cond: Bool, what: String)
    {
      if (!cond)
        fail(what);
    }

// --- block-level checks: the tree a split and a deal produced ---

// no two blocks may share a cell. a filler writes its whole rect, so two overlapping blocks means
// whichever ran second silently ate part of the first
  public function noOverlap(blocks: Array<_GenNode>)
    {
      for (i in 0...blocks.length)
        for (j in i + 1...blocks.length)
          if (GenTree.overlaps(blocks[i], blocks[j]))
            fail('blocks overlap: ' + rect(blocks[i]) + ' (' + blocks[i].kind + ') and ' +
              rect(blocks[j]) + ' (' + blocks[j].kind + ')');
    }

// every block stays inside the area, and none of them is degenerate
  public function inBounds(blocks: Array<_GenNode>, w: Int, h: Int)
    {
      for (b in blocks)
        {
          ok(b.x1 >= 0 && b.y1 >= 0 && b.x2 < w && b.y2 < h,
            'block out of bounds: ' + rect(b));
          ok(b.x2 >= b.x1 && b.y2 >= b.y1, 'degenerate block: ' + rect(b));
        }
    }

// every demand's min is met and no demand's max is exceeded. the check the whole quota exists for
  public function quotaMet(blocks: Array<_GenNode>, demands: Array<_GenDemand>)
    {
      for (d in demands)
        {
          var n = Quota.count(blocks, d.kind);
          ok(n >= d.min, 'quota short: "' + d.kind + '" got ' + n + ', needs ' + d.min);
          ok(n <= d.max, 'quota over: "' + d.kind + '" got ' + n + ', max ' + d.max);
        }
    }

// a dealt block is big enough for what it was dealt. gen.Quota promises this, so a failure here is
// the dealer being wrong rather than the split being unlucky
  public function blocksFit(blocks: Array<_GenNode>, demands: Array<_GenDemand>)
    {
      for (d in demands)
        for (b in blocks)
          {
            if (b.kind != d.kind)
              continue;
            ok(GenTree.width(b) >= d.minW && GenTree.height(b) >= d.minH,
              '"' + d.kind + '" dealt an undersized block: ' + rect(b) +
              ' needs ' + d.minW + 'x' + d.minH);
            ok(d.must == null || d.must(b),
              '"' + d.kind + '" dealt a block its own `must` rejects: ' + rect(b));
          }
    }

// every leaf of a split clears the profile's own floor, and none exceeds its cap
  public function splitSane(blocks: Array<_GenNode>, p: _SplitProfile)
    {
      for (b in blocks)
        {
          var w = GenTree.width(b);
          var h = GenTree.height(b);
          ok(w >= p.minSide && h >= p.minSide,
            'split leaf under minSide ' + p.minSide + ': ' + rect(b));
          ok(w <= p.maxSide && h <= p.maxSide,
            'split leaf over maxSide ' + p.maxSide + ': ' + rect(b));
        }
    }

  // --- grid-level checks: a whole generated area ---

// every cell holds a tile the tileset actually has.
//
// THIS CANNOT BE A "NO TEMP IDS LEFT" CHECK, which is what it was first written as and why that
// version reported 790 bad cells on a perfectly good compound: the temp alphabet runs 0..28 and the
// real ids OVERLAP it — TILE_BUILDING is 2, TILE_WALL 4, TILE_BUSH 9, TILE_GRASS 10. A finalized
// facility is full of legitimate single-digit tiles and there is no numeric test that separates
// them from a missed temp id. What can be tested is the range: an id past the end of the
// walkability table indexes nothing, and tiles.Tileset hands the renderer whatever that returns
  public function tilesKnown(ctx: GenCtx)
    {
      var max = tiles.Default.TILE_WALKABLE.length;
      var bad = 0;
      var worst = -1;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            var t = ctx.cells[x][y];
            if (t >= 0 &&
                t < max)
              continue;
            bad++;
            if (t > worst)
              worst = t;
          }
      ok(bad == 0, bad + ' cells hold a tile id outside the tileset (highest ' + worst +
        ', table holds ' + max + ')');
    }

// rooms are inside the area, non-degenerate, uniquely numbered, and their w/h agree with their
// corners. `x2` is the LAST cell, which is the convention every consumer indexes with — an
// off-by-one here reaches the renderer as a ceiling light hanging through a wall
  public function roomsSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      var seen = new Map<Int, Bool>();
      for (r in rooms)
        {
          ok(r.x1 >= 0 && r.y1 >= 0 && r.x2 < ctx.width && r.y2 < ctx.height,
            'room ' + r.id + ' out of bounds: ' + r.x1 + ',' + r.y1 + '..' + r.x2 + ',' + r.y2);
          ok(r.x2 >= r.x1 && r.y2 >= r.y1, 'room ' + r.id + ' degenerate');
          ok(r.w == r.x2 - r.x1 + 1 && r.h == r.y2 - r.y1 + 1,
            'room ' + r.id + ' w/h disagrees with its corners: ' + r.w + 'x' + r.h);
          // ids are keyed on by _Door.roomID1/2, by _GeneratorInfo.getRoom and by three cult
          // missions, and they are stamped into the cell grid as marks — a duplicate silently
          // merges two rooms for every one of those readers
          ok(!seen.exists(r.id), 'duplicate room id ' + r.id);
          seen.set(r.id, true);
        }
    }

// every door resolves to rooms that exist. scenario.AlienMissionCommon locks a room by walking
// generatorInfo.doors for `roomID1 == room.id`, so a door naming a room that was never recorded is
// a mission that silently locks nothing
  public function doorsSane(ctx: GenCtx, rooms: Array<_Room>, doors: Array<_Door>)
    {
      var ids = new Map<Int, Bool>();
      for (r in rooms)
        ids.set(r.id, true);
      var pairs = new Map<String, Bool>();
      for (d in doors)
        {
          ok(d.x >= 0 && d.y >= 0 && d.x < ctx.width && d.y < ctx.height,
            'door out of bounds: ' + d.x + ',' + d.y);
          // roomID 0 is the sentinel for "a corridor, or outdoors", not a room id
          ok(d.roomID1 == 0 || ids.exists(d.roomID1),
            'door at ' + d.x + ',' + d.y + ' names unknown room ' + d.roomID1);
          ok(d.roomID2 == 0 || ids.exists(d.roomID2),
            'door at ' + d.x + ',' + d.y + ' names unknown room ' + d.roomID2);
          if (d.skip)
            continue;
          // two live doors between the same pair of ROOMS is what fixDoors exists to remove — but
          // only between two rooms. A room with several doors onto corridors is intended and
          // common: fixDoors skips roomID2 == 0 explicitly, and makeDoorToCorridor adds a second
          // one on purpose when a room cluster has no way out
          if (d.roomID1 == 0 ||
              d.roomID2 == 0)
            continue;
          var lo = (d.roomID1 < d.roomID2 ? d.roomID1 : d.roomID2);
          var hi = (d.roomID1 < d.roomID2 ? d.roomID2 : d.roomID1);
          var key = lo + ':' + hi;
          ok(!pairs.exists(key), 'two doors between rooms ' + lo + ' and ' + hi);
          pairs.set(key, true);
        }
    }

// no two objects on one cell, and every spawn inside the area. two on a cell is the failure mode
// every placement pass guards against with hasObjectAt, so one getting through means a pass forgot
  public function spawnsSane(ctx: GenCtx)
    {
      var at = new Map<Int, Bool>();
      for (s in ctx.spawns)
        {
          ok(s.x >= 0 && s.y >= 0 && s.x < ctx.width && s.y < ctx.height,
            'spawn "' + s.type + '" out of bounds: ' + s.x + ',' + s.y);
          var key = s.y * ctx.width + s.x;
          ok(!at.exists(key), 'two spawns on cell ' + s.x + ',' + s.y + ' (' + s.type + ')');
          at.set(key, true);
        }
    }

// every room can actually be walked into.
//
// THE ONE CHECK THAT CATCHES A ROOM WITH NO DOOR. game.FacilityAreaGenerator already traces "bug,
// no door spots in room" when makeDoors cannot find a wall midpoint to open, and "no
// corridor-adjacent walls in cluster" when fixDoors cannot connect a cluster — but a trace in a
// browser console during generation is not something anyone reads, and the result is a room that
// renders perfectly and simply cannot be entered. Clues, guards and mission anchors can all land
// in it.
//
// flood fills the WALKABLE tiles from the area's outdoor edge. Doors are walkable floor by this
// point (a door cell finalizes to TILE_FLOOR_LINO and the Door object is what blocks it), so this
// is reachability for a player who opens what is in the way, which is the right question
  public var lastSeen: Array<Array<Bool>>;

  public function reachable(ctx: GenCtx, rooms: Array<_Room>): Array<_Room>
    {
      var walk = tiles.Default.TILE_WALKABLE;
      var seen = [for (x in 0...ctx.width) [for (y in 0...ctx.height) false]];
      lastSeen = seen;
      var stack = [];
      // start from every walkable cell on the area's rim: the road and its pavement run the full
      // width, so whichever edge they landed on is in there
      for (x in 0...ctx.width)
        {
          push(ctx, walk, seen, stack, x, 0);
          push(ctx, walk, seen, stack, x, ctx.height - 1);
        }
      for (y in 0...ctx.height)
        {
          push(ctx, walk, seen, stack, 0, y);
          push(ctx, walk, seen, stack, ctx.width - 1, y);
        }
      while (stack.length > 0)
        {
          var p = stack.pop();
          for (i in 0...Const.dir4x.length)
            push(ctx, walk, seen, stack, p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
        }

      // a room counts as reached if ANY of its cells was: its floor is one connected rect, and the
      // furniture standing in it is unwalkable without cutting it in two
      var cut = [];
      for (r in rooms)
        {
          var hit = false;
          for (y in r.y1...r.y2 + 1)
            for (x in r.x1...r.x2 + 1)
              if (seen[x][y])
                hit = true;
          if (!hit)
            cut.push(r);
        }
      return cut;
    }

  static function push(ctx: GenCtx, walk: Array<Int>, seen: Array<Array<Bool>>,
      stack: Array<{ x: Int, y: Int }>, x: Int, y: Int)
    {
      if (x < 0 ||
          y < 0 ||
          x >= ctx.width ||
          y >= ctx.height ||
          seen[x][y])
        return;
      var t = ctx.cells[x][y];
      if (t < 0 ||
          t >= walk.length ||
          walk[t] == 0)
        return;
      seen[x][y] = true;
      stack.push({ x: x, y: y });
    }

// every room with benches keeps some of them bare.
//
// A CLUE SPOT IS A BENCH TILE WITH NO OBJECT ON IT (game.AreaGame.initSpawnPoints), and
// clearTableSpots exists solely to guarantee one. A facility with no legal spot does not crash or
// look wrong — it just silently stops handing out clues, which is the kind of bug that survives a
// hundred playtests
  public function clueSpots(ctx: GenCtx, rooms: Array<_Room>)
    {
      var free = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            var t = ctx.cells[x][y];
            if (t < Const.TILE_LABS_TABLE_3X3_7 ||
                t > Const.TILE_LABS_TABLE2_1X1)
              continue;
            if (!ctx.hasObjectAt(x, y))
              free++;
          }
      ok(free > 0, 'no bare bench cell in the whole area: nothing can spawn a clue');
    }

// the checkpoint, re-derived exactly the way game.AreaGame.gate() does it on every load.
//
// A REIMPLEMENTATION ON PURPOSE, and the one place in this file that is. gate() reads nothing the
// generator recorded — no block tree, no generatorInfo — only the SHAPE left in the cell grid: the
// bounding box of every open-lot cell lying within the pavement's depth of the carriageway. That
// makes it the invariant most easily broken by a layout change and the one least likely to be
// noticed, because a compound with no checkpoint still loads and still plays
  public function gate(ctx: GenCtx)
    {
      var x0 = ctx.width, x1 = -1, y0 = ctx.height, y1 = -1, dir = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (ctx.cells[x][y] != Const.TILE_ALLEY)
              continue;
            var d = roadSide(ctx, x, y);
            if (d == 0)
              continue;
            dir = d;
            if (x < x0)
              x0 = x;
            if (x > x1)
              x1 = x;
            if (y < y0)
              y0 = y;
            if (y > y1)
              y1 = y;
          }
      if (dir == 0)
        {
          fail('no gate: no open-lot cell lies within the pavement band, so the compound has no ' +
            'checkpoint at all');
          return;
        }
      // ONE mouth and not several. the box is taken over every qualifying cell in the area, so a
      // second hole anywhere along the frontage does not add a gate — it stretches this one across
      // the whole compound and gate() then tests two cells that are nowhere near each other
      ok(x1 - x0 + 1 == gen.blocks.RoadBlock.ENTRY_W,
        'the gate mouth is ' + (x1 - x0 + 1) + ' cells wide, not ' +
        gen.blocks.RoadBlock.ENTRY_W + ': something else broke the pavement band');
      ok(y1 - y0 + 1 == gen.blocks.FacilityBlocks.SIDEWALK_W,
        'the gate mouth is ' + (y1 - y0 + 1) + ' cells deep, not the pavement band');
      // the row of lot just past the mouth: the booth takes the bay before it and the barrier post
      // the bay after, and gate() draws nothing at all unless both are open lot
      var y = (dir < 0 ? y1 + 1 : y0 - 1);
      ok(ctx.getCellType(x0 - 1, y) == Const.TILE_ALLEY &&
         ctx.getCellType(x1 + 1, y) == Const.TILE_ALLEY,
        'the gate mouth at ' + x0 + ',' + y0 + ' is not flanked by open lot on the row inside it, ' +
        'so no booth is drawn and no checkpoint exists');
    }

// which way the carriageway lies from this cell, or 0 if it is further off than the pavement is
// deep. game.AreaGame.roadSide, verbatim
  static function roadSide(ctx: GenCtx, x: Int, y: Int): Int
    {
      for (i in 1...gen.blocks.FacilityBlocks.SIDEWALK_W + 1)
        {
          if (ctx.getCellType(x, y - i) == Const.TILE_ROAD)
            return -1;
          if (ctx.getCellType(x, y + i) == Const.TILE_ROAD)
            return 1;
        }
      return 0;
    }

// the park's path, re-derived the way render.facility.FacilityModel.isParkPath does it: a pavement
// cell with lawn on both sides of the run it stands in. The park block writes it as plain WALKWAY
// and nothing records that it is a path, so a park laid without one loses its kerbs and its lamps
// with no error anywhere
  public function parkPath(ctx: GenCtx)
    {
      var n = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          if (ctx.cells[x][y] == Const.TILE_WALKWAY &&
              ((grassAcross(ctx, x, y, -1, 0) && grassAcross(ctx, x, y, 1, 0)) ||
               (grassAcross(ctx, x, y, 0, -1) && grassAcross(ctx, x, y, 0, 1))))
            n++;
      ok(n > 0, 'no cell in the area reads as a park path: the park has no walkway with lawn ' +
        'either side of it');
    }

// step off a cell one way over the walkway run it stands in: is the first cell past that run grass?
// FacilityModel.grassAcross, with its own PATH_MAX cap
  static function grassAcross(ctx: GenCtx, x: Int, y: Int, dx: Int, dy: Int): Bool
    {
      var cx = x + dx;
      var cy = y + dy;
      for (_ in 0...PATH_MAX)
        {
          var t = ctx.getCellType(cx, cy);
          if (t != Const.TILE_WALKWAY)
            // Surf.GRASS, spelled the way render.facility.FacilityModel.surfOf spells it
            return t == Const.TILE_GRASS ||
              t == Const.TILE_GRASS_UNWALKABLE ||
              (t >= Const.TILE_TREE1 && t <= Const.TILE_BUSH);
          cx += dx;
          cy += dy;
        }
      return false;
    }

  static function rect(b: _GenNode): String
    return b.x1 + ',' + b.y1 + '..' + b.x2 + ',' + b.y2;
}
